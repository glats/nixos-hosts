package shutdowncampaign

import (
	"errors"
	"math"
	"path/filepath"
	"reflect"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/glats/nixos-scripts/internal/shutdowntrial"
)

var t0 = time.Date(2026, 11, 11, 23, 0, 0, 0, time.UTC)

type fakeEnv struct {
	files    map[string]string
	globs    map[string][]string
	globSeq  map[string][][]string
	globCall map[string]int
	outputs  map[string]string
	ops      []string
	failRun  map[string]error
	sleeps   []time.Duration
}

func newEnv() *fakeEnv {
	return &fakeEnv{
		files:    map[string]string{ModulesPath: "snd 1 0 - Live 0x0\n", UptimePath: "40.5 100.0\n"},
		globs:    map[string][]string{},
		globSeq:  map[string][][]string{},
		globCall: map[string]int{},
		outputs:  map[string]string{"systemctl list-jobs --no-legend": "1 poweroff.target start waiting\n"},
		failRun:  map[string]error{},
	}
}

func (f *fakeEnv) ReadFile(p string) ([]byte, error) {
	v, ok := f.files[p]
	if !ok {
		return nil, errors.New("missing " + p)
	}
	return []byte(v), nil
}

func (f *fakeEnv) WriteFile(p string, d []byte) error {
	f.ops = append(f.ops, "write "+p+"="+string(d))
	if p == AlarmPath && string(d) != "0" {
		f.files[AlarmPath] = string(d)
	}
	return nil
}

func (f *fakeEnv) Glob(pattern string) ([]string, error) {
	if seq, ok := f.globSeq[pattern]; ok {
		i := f.globCall[pattern]
		f.globCall[pattern]++
		if i >= len(seq) {
			i = len(seq) - 1
		}
		return seq[i], nil
	}
	return f.globs[pattern], nil
}

func (f *fakeEnv) Run(name string, args ...string) error {
	cmd := strings.Join(append([]string{name}, args...), " ")
	f.ops = append(f.ops, "run "+cmd)
	return f.failRun[cmd]
}

func (f *fakeEnv) Output(name string, args ...string) (string, error) {
	return f.outputs[strings.Join(append([]string{name}, args...), " ")], nil
}

func (f *fakeEnv) Sleep(d time.Duration) { f.sleeps = append(f.sleeps, d) }

const unloadCmd = "run modprobe -r nvidia_drm nvidia_uvm nvidia_modeset nvidia"

func ctx(boot string, rnd int) Ctx {
	return Ctx{BootID: boot, Kernel: "6.18.62", Now: t0, Rand: func(int) int { return rnd }}
}

func newLog(t *testing.T) *shutdowntrial.Log {
	return &shutdowntrial.Log{Path: filepath.Join(t.TempDir(), "trials.jsonl")}
}

func armEntry(boot, arm string, alarm int64) shutdowntrial.Entry {
	return shutdowntrial.Entry{Kind: "arm", BootID: boot, Arm: arm, AlarmUnix: alarm}
}

func bootEntry(boot, reason, resolves, arm, outcome string) shutdowntrial.Entry {
	return shutdowntrial.Entry{Kind: "boot", BootID: boot, Reason: reason, Resolves: resolves, Arm: arm, Outcome: outcome}
}

func TestChooseArmPicksTheLessSampledArm(t *testing.T) {
	entries := []shutdowntrial.Entry{
		bootEntry("b1", "alarm", "a1", ArmNormal, "off"),
		bootEntry("b2", "alarm", "a2", ArmNormal, "off"),
		bootEntry("b3", "alarm", "a3", ArmUnload, "off"),
	}
	if got := ChooseArm(entries, func(int) int { return 0 }); got != ArmUnload {
		t.Fatalf("got %s, want %s", got, ArmUnload)
	}
}

func TestChooseArmTieUsesRandomness(t *testing.T) {
	if got := ChooseArm(nil, func(int) int { return 0 }); got != ArmNormal {
		t.Fatalf("rand 0: %s", got)
	}
	if got := ChooseArm(nil, func(int) int { return 1 }); got != ArmUnload {
		t.Fatalf("rand 1: %s", got)
	}
}

func TestChooseArmIgnoresInvalidAndUnmeasured(t *testing.T) {
	entries := []shutdowntrial.Entry{
		bootEntry("b1", "cold", "a1", ArmInvalid, "hung_or_unwoken"),
		bootEntry("b2", "cold", "a2", ArmNone, "unmeasured"),
	}
	if got := ChooseArm(entries, func(int) int { return 1 }); got != ArmUnload {
		t.Fatalf("got %s", got)
	}
}

func TestShutdownIgnoresReboot(t *testing.T) {
	env := newEnv()
	env.outputs["systemctl list-jobs --no-legend"] = "1 reboot.target start waiting\n"
	log := newLog(t)
	if err := Shutdown(env, log, ctx("b1", 0), func(string) {}); err != nil {
		t.Fatal(err)
	}
	if len(env.ops) != 0 {
		t.Fatalf("reboot acted: %v", env.ops)
	}
	if e, _ := log.Read(); len(e) != 0 {
		t.Fatalf("reboot logged: %+v", e)
	}
}

func TestShutdownDoesNothingWhenPaused(t *testing.T) {
	env := newEnv()
	env.files[PausePath] = ""
	log := newLog(t)
	if err := Shutdown(env, log, ctx("b1", 0), func(string) {}); err != nil {
		t.Fatal(err)
	}
	if len(env.ops) != 0 {
		t.Fatalf("paused acted: %v", env.ops)
	}
}

func TestShutdownNormalArmOnlyArmsTheAlarm(t *testing.T) {
	env := newEnv()
	log := newLog(t)
	var crumbs []string
	if err := Shutdown(env, log, ctx("b1", 0), func(m string) { crumbs = append(crumbs, m) }); err != nil {
		t.Fatal(err)
	}
	alarm := strconv.FormatInt(t0.Add(AlarmDelay).Unix(), 10)
	want := []string{"write " + AlarmPath + "=0", "write " + AlarmPath + "=" + alarm}
	if !reflect.DeepEqual(env.ops, want) {
		t.Fatalf("ops %v, want %v", env.ops, want)
	}
	entries, _ := log.Read()
	if len(entries) != 1 || entries[0].Kind != "arm" || entries[0].Arm != ArmNormal || entries[0].BootID != "b1" || entries[0].AlarmUnix != t0.Add(AlarmDelay).Unix() {
		t.Fatalf("entries %+v", entries)
	}
	if len(crumbs) != 1 || !strings.Contains(crumbs[0], "arm=normal") {
		t.Fatalf("crumbs %v", crumbs)
	}
}

func TestShutdownUnloadArmUnloadsBeforeTheAlarm(t *testing.T) {
	env := newEnv()
	log := newLog(t)
	if err := Shutdown(env, log, ctx("b1", 1), func(string) {}); err != nil {
		t.Fatal(err)
	}
	if len(env.ops) != 3 || env.ops[0] != unloadCmd || !strings.HasPrefix(env.ops[1], "write "+AlarmPath) {
		t.Fatalf("ops %v", env.ops)
	}
	entries, _ := log.Read()
	if entries[0].Arm != ArmUnload || entries[0].Error != "" {
		t.Fatalf("entry %+v", entries[0])
	}
}

func TestShutdownUnloadFailureMarksArmInvalidButKeepsAlarm(t *testing.T) {
	env := newEnv()
	env.failRun[strings.TrimPrefix(unloadCmd, "run ")] = errors.New("in use")
	log := newLog(t)
	if err := Shutdown(env, log, ctx("b1", 1), func(string) {}); err != nil {
		t.Fatal(err)
	}
	entries, _ := log.Read()
	if entries[0].Arm != ArmInvalid || !strings.Contains(entries[0].Error, "in use") || entries[0].AlarmUnix == 0 {
		t.Fatalf("entry %+v", entries[0])
	}
}

func TestShutdownUnloadStillLoadedMarksArmInvalid(t *testing.T) {
	env := newEnv()
	env.files[ModulesPath] = "nvidia 111 1 nvidia_uvm, Live 0x0\n"
	log := newLog(t)
	if err := Shutdown(env, log, ctx("b1", 1), func(string) {}); err != nil {
		t.Fatal(err)
	}
	entries, _ := log.Read()
	if entries[0].Arm != ArmInvalid || !strings.Contains(entries[0].Error, "nvidia") {
		t.Fatalf("entry %+v", entries[0])
	}
}

func TestShutdownEndsTheChainWithoutAlarm(t *testing.T) {
	env := newEnv()
	log := newLog(t)
	for _, e := range []shutdowntrial.Entry{
		bootEntry("b0", "cold", "", "", ""),
		armEntry("b0", ArmNormal, 1),
		bootEntry("b1", "alarm", "b0", ArmNormal, "off"),
		armEntry("b1", ArmUnload, 2),
		bootEntry("b2", "alarm", "b1", ArmUnload, "off"),
	} {
		if err := log.Append(e); err != nil {
			t.Fatal(err)
		}
	}
	if err := Shutdown(env, log, ctx("b2", 0), func(string) {}); err != nil {
		t.Fatal(err)
	}
	if len(env.ops) != 0 {
		t.Fatalf("final shutdown acted: %v", env.ops)
	}
	entries, _ := log.Read()
	last := entries[len(entries)-1]
	if last.Kind != "arm" || last.Arm != ArmNone || last.AlarmUnix != 0 {
		t.Fatalf("last %+v", last)
	}
}

func TestShutdownKeepsAlarmAfterOneAutoCycle(t *testing.T) {
	env := newEnv()
	log := newLog(t)
	for _, e := range []shutdowntrial.Entry{
		bootEntry("b0", "cold", "", "", ""),
		armEntry("b0", ArmNormal, 1),
		bootEntry("b1", "alarm", "b0", ArmNormal, "off"),
	} {
		_ = log.Append(e)
	}
	if err := Shutdown(env, log, ctx("b1", 0), func(string) {}); err != nil {
		t.Fatal(err)
	}
	entries, _ := log.Read()
	if entries[len(entries)-1].AlarmUnix == 0 {
		t.Fatalf("alarm dropped too early: %+v", entries[len(entries)-1])
	}
}

func pending(alarm int64) []shutdowntrial.Entry {
	return []shutdowntrial.Entry{armEntry("b0", ArmUnload, alarm)}
}

func seed(t *testing.T, es []shutdowntrial.Entry) *shutdowntrial.Log {
	log := newLog(t)
	for _, e := range es {
		if err := log.Append(e); err != nil {
			t.Fatal(err)
		}
	}
	return log
}

func TestBootInsideTheAlarmWindowIsAnAlarmWakeAndOff(t *testing.T) {
	alarm := t0.Add(-70 * time.Second).Unix()
	log := seed(t, pending(alarm))
	env := newEnv()
	e, err := Boot(env, log, ctx("b1", 0))
	if err != nil {
		t.Fatal(err)
	}
	if e.Reason != "alarm" || e.Outcome != "off" || e.Resolves != "b0" || e.Arm != ArmUnload {
		t.Fatalf("entry %+v", e)
	}
	if got, _ := log.Read(); len(got) != 2 || got[1].Kind != "boot" {
		t.Fatalf("log %+v", got)
	}
}

func TestBootLongAfterTheAlarmIsHungOrUnwoken(t *testing.T) {
	alarm := t0.Add(-3 * time.Hour).Unix()
	log := seed(t, pending(alarm))
	e, err := Boot(newEnv(), log, ctx("b1", 0))
	if err != nil {
		t.Fatal(err)
	}
	if e.Reason != "cold" || e.Outcome != "hung_or_unwoken" {
		t.Fatalf("entry %+v", e)
	}
}

func TestBootAfterAnUnmeasuredArmIsUnmeasured(t *testing.T) {
	log := seed(t, pending(0))
	e, _ := Boot(newEnv(), log, ctx("b1", 0))
	if e.Outcome != "unmeasured" || e.Reason != "cold" {
		t.Fatalf("entry %+v", e)
	}
}

func TestBootWithoutPendingArmRecordsAColdBootOnly(t *testing.T) {
	log := newLog(t)
	e, _ := Boot(newEnv(), log, ctx("b1", 0))
	if e.Kind != "boot" || e.Reason != "cold" || e.Resolves != "" || e.Outcome != "" {
		t.Fatalf("entry %+v", e)
	}
}

func TestBootDoesNotResolveTheSameArmTwice(t *testing.T) {
	log := seed(t, []shutdowntrial.Entry{
		armEntry("b0", ArmNormal, 5),
		bootEntry("b1", "cold", "b0", ArmNormal, "hung_or_unwoken"),
	})
	e, _ := Boot(newEnv(), log, ctx("b2", 0))
	if e.Resolves != "" {
		t.Fatalf("resolved twice: %+v", e)
	}
}

func TestBootDoesNothingWhenPaused(t *testing.T) {
	env := newEnv()
	env.files[PausePath] = ""
	log := seed(t, pending(1))
	if _, err := Boot(env, log, ctx("b1", 0)); err != nil {
		t.Fatal(err)
	}
	if got, _ := log.Read(); len(got) != 1 {
		t.Fatalf("paused boot logged: %+v", got)
	}
}

func alarmBoot() []shutdowntrial.Entry {
	return []shutdowntrial.Entry{armEntry("b0", ArmNormal, 1), bootEntry("b1", "alarm", "b0", ArmNormal, "off")}
}

func TestAutoCyclePowersOffWhenNobodyLogsIn(t *testing.T) {
	env := newEnv()
	if err := AutoCycle(env, seed(t, alarmBoot()), ctx("b1", 0), func(string) {}); err != nil {
		t.Fatal(err)
	}
	if last := env.ops[len(env.ops)-1]; last != "run systemctl poweroff" {
		t.Fatalf("ops %v", env.ops)
	}
	var total time.Duration
	for _, s := range env.sleeps {
		total += s
	}
	if total < CycleGrace {
		t.Fatalf("waited %v, want >= %v", total, CycleGrace)
	}
}

func TestAutoCycleStopsWhenASessionAppears(t *testing.T) {
	env := newEnv()
	env.globSeq[SessionsGlob] = [][]string{{}, {}, {"/run/systemd/sessions/3"}}
	if err := AutoCycle(env, seed(t, alarmBoot()), ctx("b1", 0), func(string) {}); err != nil {
		t.Fatal(err)
	}
	for _, op := range env.ops {
		if op == "run systemctl poweroff" {
			t.Fatalf("powered off with a session: %v", env.ops)
		}
	}
}

func TestAutoCycleIgnoresSessionRefFiles(t *testing.T) {
	env := newEnv()
	env.globs[SessionsGlob] = []string{"/run/systemd/sessions/3.ref"}
	if err := AutoCycle(env, seed(t, alarmBoot()), ctx("b1", 0), func(string) {}); err != nil {
		t.Fatal(err)
	}
	if env.ops[len(env.ops)-1] != "run systemctl poweroff" {
		t.Fatalf("ref file counted as session: %v", env.ops)
	}
}

func TestAutoCycleSkipsAColdBoot(t *testing.T) {
	env := newEnv()
	log := seed(t, []shutdowntrial.Entry{bootEntry("b1", "cold", "", "", "")})
	if err := AutoCycle(env, log, ctx("b1", 0), func(string) {}); err != nil {
		t.Fatal(err)
	}
	if len(env.ops) != 0 {
		t.Fatalf("cold boot cycled: %v", env.ops)
	}
}

func TestAutoCycleSkipsWhenPaused(t *testing.T) {
	env := newEnv()
	env.files[PausePath] = ""
	if err := AutoCycle(env, seed(t, alarmBoot()), ctx("b1", 0), func(string) {}); err != nil {
		t.Fatal(err)
	}
	if len(env.ops) != 0 {
		t.Fatalf("paused cycled: %v", env.ops)
	}
}

func TestSessionCountSkipsRefFiles(t *testing.T) {
	env := newEnv()
	env.globs[SessionsGlob] = []string{"/run/systemd/sessions/1", "/run/systemd/sessions/1.ref", "/run/systemd/sessions/c2"}
	if got := Sessions(env); got != 2 {
		t.Fatalf("got %d", got)
	}
}

func TestSummarizeCountsMeasuredArmsAndAlarmWakes(t *testing.T) {
	var es []shutdowntrial.Entry
	for i := 0; i < 5; i++ {
		es = append(es, bootEntry("n"+strconv.Itoa(i), "cold", "x", ArmNormal, "hung_or_unwoken"))
		es = append(es, bootEntry("u"+strconv.Itoa(i), "alarm", "y", ArmUnload, "off"))
	}
	es = append(es, bootEntry("bad", "cold", "z", ArmInvalid, "hung_or_unwoken"))
	es = append(es, bootEntry("none", "cold", "w", ArmNone, "unmeasured"))
	s := Summarize(es)
	if s.Normal.N != 5 || s.Normal.Off != 0 || s.Unload.N != 5 || s.Unload.Off != 5 {
		t.Fatalf("summary %+v", s)
	}
	if s.AlarmWakes != 5 || s.Invalid != 1 || s.Unmeasured != 1 {
		t.Fatalf("summary %+v", s)
	}
	if math.Abs(s.P-2.0/252.0) > 1e-9 {
		t.Fatalf("p=%v want %v", s.P, 2.0/252.0)
	}
	if !strings.Contains(s.Verdict, "differs") {
		t.Fatalf("verdict %q", s.Verdict)
	}
}

func TestSummarizeWarnsWhenTheAlarmNeverWoke(t *testing.T) {
	var es []shutdowntrial.Entry
	for i := 0; i < 5; i++ {
		es = append(es, bootEntry("n"+strconv.Itoa(i), "cold", "x", ArmNormal, "hung_or_unwoken"))
		es = append(es, bootEntry("u"+strconv.Itoa(i), "cold", "y", ArmUnload, "hung_or_unwoken"))
	}
	if v := Summarize(es).Verdict; !strings.Contains(v, "alarm") {
		t.Fatalf("verdict %q", v)
	}
}

func TestSummarizeNeedsMoreSamples(t *testing.T) {
	es := []shutdowntrial.Entry{bootEntry("n", "alarm", "x", ArmNormal, "off")}
	if v := Summarize(es).Verdict; !strings.Contains(v, "need") {
		t.Fatalf("verdict %q", v)
	}
}
