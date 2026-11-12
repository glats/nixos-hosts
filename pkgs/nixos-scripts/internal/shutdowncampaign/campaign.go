package shutdowncampaign

import (
	"fmt"
	"math"
	"strconv"
	"strings"
	"time"

	"github.com/glats/nixos-scripts/internal/shutdowntrial"
)

const (
	ArmNormal  = "normal"
	ArmUnload  = "unload"
	ArmNone    = "none"
	ArmInvalid = "unload-failed"

	AlarmPath    = "/sys/class/rtc/rtc0/wakealarm"
	PausePath    = "/var/lib/test-shutdown/campaign-paused"
	SessionsGlob = "/run/systemd/sessions/*"
	ModulesPath  = "/proc/modules"
	UptimePath   = "/proc/uptime"

	AlarmDelay = 5 * time.Minute
	WakeEarly  = 30 * time.Second
	WakeLate   = 100 * time.Second
	CycleGrace = 120 * time.Second
	CyclePoll  = 10 * time.Second
	MaxChain   = 2
	MinSamples = 5

	unloadSettle = 2 * time.Second
	gpuPCI       = "/sys/bus/pci/devices/0000:01:00.0"
)

type Env interface {
	shutdowntrial.System
	Output(name string, args ...string) (string, error)
	Sleep(d time.Duration)
}

type Ctx struct {
	BootID string
	Kernel string
	Now    time.Time
	Rand   func(n int) int
}

func exists(env Env, path string) bool {
	_, err := env.ReadFile(path)
	return err == nil
}

func IsPowerOff(jobs string) bool {
	return strings.Contains(jobs, "poweroff.target")
}

func ChooseArm(entries []shutdowntrial.Entry, rnd func(int) int) string {
	var normal, unload int
	for _, e := range entries {
		if e.Kind != "boot" || e.Resolves == "" {
			continue
		}
		switch e.Arm {
		case ArmNormal:
			normal++
		case ArmUnload:
			unload++
		}
	}
	switch {
	case normal < unload:
		return ArmNormal
	case unload < normal:
		return ArmUnload
	case rnd(2) == 0:
		return ArmNormal
	default:
		return ArmUnload
	}
}

func chainLength(entries []shutdowntrial.Entry) int {
	n := 0
	for i := len(entries) - 1; i >= 0; i-- {
		e := entries[i]
		if e.Kind != "boot" {
			continue
		}
		if e.Reason != "alarm" {
			break
		}
		n++
	}
	return n
}

func Sessions(env Env) int {
	paths, err := env.Glob(SessionsGlob)
	if err != nil {
		return 0
	}
	n := 0
	for _, p := range paths {
		if strings.HasSuffix(p, ".ref") {
			continue
		}
		if data, err := env.ReadFile(p); err == nil && !countsAsLogin(string(data)) {
			continue
		}
		n++
	}
	return n
}

func countsAsLogin(session string) bool {
	for _, line := range strings.Split(session, "\n") {
		if class, ok := strings.CutPrefix(line, "CLASS="); ok {
			return !strings.HasPrefix(class, "manager") && !strings.HasPrefix(class, "background")
		}
	}
	return true
}

func nvidiaLoaded(modules string) string {
	for _, line := range strings.Split(modules, "\n") {
		if strings.HasPrefix(line, "nvidia") {
			return strings.Fields(line)[0]
		}
	}
	return ""
}

func unload(env Env) error {
	if err := env.Run("modprobe", "-r", "nvidia_drm", "nvidia_uvm", "nvidia_modeset", "nvidia"); err != nil {
		return fmt.Errorf("modprobe -r: %w", err)
	}
	env.Sleep(unloadSettle)
	data, err := env.ReadFile(ModulesPath)
	if err != nil {
		return err
	}
	if m := nvidiaLoaded(string(data)); m != "" {
		return fmt.Errorf("%s loaded again after unload", m)
	}
	return nil
}

func armAlarm(env Env, at time.Time) (int64, error) {
	unix := at.Unix()
	if err := env.WriteFile(AlarmPath, []byte("0")); err != nil {
		return 0, err
	}
	want := strconv.FormatInt(unix, 10)
	if err := env.WriteFile(AlarmPath, []byte(want)); err != nil {
		return 0, err
	}
	data, err := env.ReadFile(AlarmPath)
	if err != nil {
		return 0, err
	}
	if strings.TrimSpace(string(data)) != want {
		return 0, fmt.Errorf("alarm reads %q, want %s", strings.TrimSpace(string(data)), want)
	}
	return unix, nil
}

func Snapshot(env Env) map[string]string {
	m := map[string]string{}
	put := func(key, path string) {
		if b, err := env.ReadFile(path); err == nil {
			m[key] = strings.TrimSpace(string(b))
		}
	}
	if b, err := env.ReadFile(UptimePath); err == nil {
		if f := strings.Fields(string(b)); len(f) > 0 {
			m["uptime_s"] = f[0]
		}
	}
	put("gpu_power_state", gpuPCI+"/power_state")
	put("gpu_runtime_status", gpuPCI+"/power/runtime_status")
	put("loadavg", "/proc/loadavg")
	if paths, _ := env.Glob("/sys/class/power_supply/A*/online"); len(paths) > 0 {
		put("ac_online", paths[0])
	}
	var hottest int
	zones, _ := env.Glob("/sys/class/thermal/thermal_zone*/temp")
	for _, z := range zones {
		if b, err := env.ReadFile(z); err == nil {
			if v, err := strconv.Atoi(strings.TrimSpace(string(b))); err == nil && v > hottest {
				hottest = v
			}
		}
	}
	if hottest > 0 {
		m["temp_max_mc"] = strconv.Itoa(hottest)
	}
	if b, err := env.ReadFile(ModulesPath); err == nil {
		m["nvidia_loaded"] = strconv.FormatBool(nvidiaLoaded(string(b)) != "")
	}
	m["sessions"] = strconv.Itoa(Sessions(env))
	return m
}

func Begin(env Env, log *shutdowntrial.Log, c Ctx, breadcrumb func(string)) error {
	if exists(env, PausePath) {
		return nil
	}
	jobs, err := env.Output("systemctl", "list-jobs", "--no-legend")
	if err != nil || !IsPowerOff(jobs) {
		return nil
	}
	e := shutdowntrial.Entry{Kind: "begin", Time: c.Now, BootID: c.BootID, Kernel: c.Kernel, Trial: "campaign", State: Snapshot(env)}
	if err := log.Append(e); err != nil {
		return fmt.Errorf("record begin: %w", err)
	}
	breadcrumb(fmt.Sprintf("test-shutdown: campaign begin boot=%s", c.BootID))
	return nil
}

func Shutdown(env Env, log *shutdowntrial.Log, c Ctx, breadcrumb func(string)) error {
	if exists(env, PausePath) {
		return nil
	}
	jobs, err := env.Output("systemctl", "list-jobs", "--no-legend")
	if err != nil || !IsPowerOff(jobs) {
		return nil
	}
	entries, err := log.Read()
	if err != nil {
		return fmt.Errorf("read history: %w", err)
	}
	entry := shutdowntrial.Entry{Kind: "arm", Time: c.Now, BootID: c.BootID, Kernel: c.Kernel, Trial: "campaign", Arm: ArmNone}
	var errs []string
	withAlarm := chainLength(entries) < MaxChain
	if withAlarm {
		entry.Arm = ChooseArm(entries, c.Rand)
		if entry.Arm == ArmUnload {
			if err := unload(env); err != nil {
				entry.Arm = ArmInvalid
				errs = append(errs, err.Error())
			}
		}
	}
	entry.State = Snapshot(env)
	if withAlarm {
		unix, err := armAlarm(env, c.Now.Add(AlarmDelay))
		if err != nil {
			errs = append(errs, "alarm: "+err.Error())
		}
		entry.AlarmUnix = unix
	}
	entry.Error = strings.Join(errs, "; ")
	if err := log.Append(entry); err != nil {
		return fmt.Errorf("record arm: %w", err)
	}
	breadcrumb(fmt.Sprintf("test-shutdown: campaign arm=%s alarm=%d boot=%s", entry.Arm, entry.AlarmUnix, c.BootID))
	return nil
}

func lastUnresolvedArm(entries []shutdowntrial.Entry) *shutdowntrial.Entry {
	for i := len(entries) - 1; i >= 0; i-- {
		if entries[i].Kind != "arm" && entries[i].Kind != "begin" {
			continue
		}
		for _, later := range entries[i+1:] {
			if later.Kind == "boot" && later.Resolves == entries[i].BootID {
				return nil
			}
		}
		return &entries[i]
	}
	return nil
}

func Boot(env Env, log *shutdowntrial.Log, c Ctx) (shutdowntrial.Entry, error) {
	if exists(env, PausePath) {
		return shutdowntrial.Entry{}, nil
	}
	entries, err := log.Read()
	if err != nil {
		return shutdowntrial.Entry{}, fmt.Errorf("read history: %w", err)
	}
	e := shutdowntrial.Entry{Kind: "boot", Time: c.Now, BootID: c.BootID, Kernel: c.Kernel, Trial: "campaign", Reason: "cold"}
	if p := lastUnresolvedArm(entries); p != nil {
		e.Resolves, e.Arm = p.BootID, p.Arm
		switch {
		case p.Kind == "begin":
			e.Outcome = "hung_early"
		case p.AlarmUnix == 0:
			e.Outcome = "unmeasured"
		case inWindow(env, c.Now, p.AlarmUnix):
			e.Reason, e.Outcome = "alarm", "off"
		default:
			e.Outcome = "hung_or_unwoken"
		}
	}
	return e, log.Append(e)
}

func inWindow(env Env, now time.Time, alarmUnix int64) bool {
	b, err := env.ReadFile(UptimePath)
	if err != nil {
		return false
	}
	f := strings.Fields(string(b))
	if len(f) == 0 {
		return false
	}
	up, err := strconv.ParseFloat(f[0], 64)
	if err != nil {
		return false
	}
	kernelStart := now.Add(-time.Duration(up * float64(time.Second)))
	alarm := time.Unix(alarmUnix, 0)
	return !kernelStart.Before(alarm.Add(-WakeEarly)) && !kernelStart.After(alarm.Add(WakeLate))
}

func AutoCycle(env Env, log *shutdowntrial.Log, c Ctx, breadcrumb func(string)) error {
	if exists(env, PausePath) {
		return nil
	}
	entries, err := log.Read()
	if err != nil {
		return err
	}
	if len(entries) == 0 {
		return nil
	}
	last := entries[len(entries)-1]
	if last.Kind != "boot" || last.BootID != c.BootID || last.Reason != "alarm" {
		return nil
	}
	for waited := time.Duration(0); waited < CycleGrace; waited += CyclePoll {
		if Sessions(env) > 0 || exists(env, PausePath) {
			return nil
		}
		env.Sleep(CyclePoll)
	}
	if Sessions(env) > 0 || exists(env, PausePath) {
		return nil
	}
	breadcrumb(fmt.Sprintf("test-shutdown: campaign auto-cycle boot=%s", c.BootID))
	return env.Run("systemctl", "poweroff")
}

type ArmStats struct {
	N   int
	Off int
}

type Result struct {
	Normal     ArmStats
	Unload     ArmStats
	AlarmWakes int
	Invalid    int
	Unmeasured int
	Early      int
	P          float64
	Verdict    string
}

func Summarize(entries []shutdowntrial.Entry) Result {
	var r Result
	for _, e := range entries {
		if e.Kind != "boot" {
			continue
		}
		if e.Reason == "alarm" {
			r.AlarmWakes++
		}
		if e.Resolves == "" {
			continue
		}
		if e.Outcome == "hung_early" {
			r.Early++
			continue
		}
		var st *ArmStats
		switch e.Arm {
		case ArmNormal:
			st = &r.Normal
		case ArmUnload:
			st = &r.Unload
		case ArmInvalid:
			r.Invalid++
			continue
		default:
			r.Unmeasured++
			continue
		}
		st.N++
		if e.Outcome == "off" {
			st.Off++
		}
	}
	r.P = fisher(r.Normal.Off, r.Normal.N-r.Normal.Off, r.Unload.Off, r.Unload.N-r.Unload.Off)
	switch {
	case r.Normal.N < MinSamples || r.Unload.N < MinSamples:
		r.Verdict = fmt.Sprintf("need at least %d measured shutdowns per arm (normal %d, unload %d)", MinSamples, r.Normal.N, r.Unload.N)
	case r.AlarmWakes == 0:
		r.Verdict = "the RTC alarm never woke the machine: a cold boot may also mean it powered off, so these results are unreliable"
	case r.P < 0.05:
		r.Verdict = fmt.Sprintf("unload differs from normal (p=%.3f)", r.P)
	default:
		r.Verdict = fmt.Sprintf("no significant difference yet (p=%.3f)", r.P)
	}
	return r
}

func logChoose(n, k int) float64 {
	a, _ := math.Lgamma(float64(n + 1))
	b, _ := math.Lgamma(float64(k + 1))
	c, _ := math.Lgamma(float64(n - k + 1))
	return a - b - c
}

func fisher(a, b, c, d int) float64 {
	n1, n2, k := a+b, c+d, a+c
	total := n1 + n2
	if total == 0 {
		return 1
	}
	prob := func(x int) float64 {
		return math.Exp(logChoose(k, x) + logChoose(total-k, n1-x) - logChoose(total, n1))
	}
	observed := prob(a)
	var p float64
	for x := max(0, k-n2); x <= min(k, n1); x++ {
		if v := prob(x); v <= observed*(1+1e-9) {
			p += v
		}
	}
	return math.Min(p, 1)
}
