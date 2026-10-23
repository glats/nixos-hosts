package shutdowntrial

import (
	"bufio"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"
)

const (
	WakeupPath      = "/proc/acpi/wakeup"
	XHCIControlGlob = "/sys/bus/pci/drivers/xhci_hcd/*:*/power/control"
	KmsgDumpParam   = "/sys/module/printk/parameters/always_kmsg_dump"
	WolInterface    = "enp3s0"
	DefaultLogPath  = "/var/lib/test-shutdown/trials.jsonl"
)

type System interface {
	ReadFile(path string) ([]byte, error)
	WriteFile(path string, data []byte) error
	Glob(pattern string) ([]string, error)
	Run(name string, args ...string) error
}

type Step struct {
	Desc string
	Do   func(System) error
}

type Trial struct {
	ID         string
	Hypothesis string
	Steps      []Step
	Manual     string
}

type StepResult struct {
	Desc  string `json:"desc"`
	Error string `json:"error,omitempty"`
}

var wolStep = Step{
	Desc: "disable Wake-on-LAN on " + WolInterface,
	Do:   func(s System) error { return s.Run("ethtool", "-s", WolInterface, "wol", "d") },
}

var acpiWakeStep = Step{
	Desc: "disarm every enabled entry in " + WakeupPath,
	Do: func(s System) error {
		data, err := s.ReadFile(WakeupPath)
		if err != nil {
			return err
		}
		var errs []error
		for _, dev := range EnabledWakeDevices(string(data)) {
			if err := s.WriteFile(WakeupPath, []byte(dev)); err != nil {
				errs = append(errs, fmt.Errorf("%s: %w", dev, err))
			}
		}
		return errors.Join(errs...)
	},
}

var xhciStep = Step{
	Desc: "force xHCI controllers to power/control=on",
	Do: func(s System) error {
		paths, err := s.Glob(XHCIControlGlob)
		if err != nil {
			return err
		}
		if len(paths) == 0 {
			return errors.New("no xhci_hcd devices found")
		}
		var errs []error
		for _, p := range paths {
			if err := s.WriteFile(p, []byte("on")); err != nil {
				errs = append(errs, err)
			}
		}
		return errors.Join(errs...)
	},
}

var displayStopStep = Step{
	Desc: "stop the display manager",
	Do:   func(s System) error { return s.Run("systemctl", "stop", "display-manager.service") },
}

var nvidiaUnloadStep = Step{
	Desc: "unload the NVIDIA modules",
	Do: func(s System) error {
		return s.Run("modprobe", "-r", "nvidia_drm", "nvidia_uvm", "nvidia_modeset", "nvidia")
	},
}

var pstoreStep = Step{
	Desc: "disable the shutdown kmsg dump to EFI pstore",
	Do:   func(s System) error { return s.WriteFile(KmsgDumpParam, []byte("N")) },
}

var Trials = []Trial{
	{
		ID:         "all",
		Hypothesis: "any OS-side state (wake, xHCI, NVIDIA, pstore) causes the hang; bisect if it powers off",
		Steps:      []Step{wolStep, acpiWakeStep, xhciStep, displayStopStep, nvidiaUnloadStep, pstoreStep},
	},
	{
		ID:         "wake",
		Hypothesis: "armed wake sources (WoL, ACPI PME) stall the firmware S5 path",
		Steps:      []Step{wolStep, acpiWakeStep},
	},
	{
		ID:         "xhci",
		Hypothesis: "xHCI runtime power management confuses the S5 entry",
		Steps:      []Step{xhciStep},
	},
	{
		ID:         "nvidia",
		Hypothesis: "the NVIDIA dGPU left in D0 blocks S5",
		Steps:      []Step{displayStopStep, nvidiaUnloadStep},
	},
	{
		ID:         "pstore",
		Hypothesis: "the EFI pstore write during power-off stalls the firmware",
		Steps:      []Step{pstoreStep},
	},
	{
		ID:         "baseline",
		Hypothesis: "control: plain poweroff with nothing changed",
	},
	{
		ID:         "outside",
		Hypothesis: "the firmware cannot power off regardless of NixOS",
		Manual: "Power off without NixOS: (1) press F2 at power-on and use the BIOS exit/power-off option; " +
			"(2) boot a NixOS live USB and run `sudo poweroff`. Then record each with `test-shutdown result off|hung <note>`.",
	},
	{
		ID:         "ec-reset",
		Hypothesis: "the embedded controller is stuck in a bad state",
		Manual: "RISKY, only after the other trials: shut down, unplug the charger, hold the power button for 60 seconds, " +
			"plug the charger back, boot, then run `sudo test-shutdown baseline`.",
	},
}

func Lookup(id string) (Trial, error) {
	for _, t := range Trials {
		if t.ID == id {
			return t, nil
		}
	}
	return Trial{}, fmt.Errorf("unknown trial %q", id)
}

func EnabledWakeDevices(wakeup string) []string {
	var devs []string
	for i, line := range strings.Split(wakeup, "\n") {
		fields := strings.Fields(line)
		if i == 0 || len(fields) < 3 {
			continue
		}
		if strings.TrimPrefix(fields[2], "*") == "enabled" {
			devs = append(devs, fields[0])
		}
	}
	return devs
}

func Apply(s System, t Trial) []StepResult {
	results := make([]StepResult, 0, len(t.Steps))
	for _, st := range t.Steps {
		r := StepResult{Desc: st.Desc}
		if err := st.Do(s); err != nil {
			r.Error = err.Error()
		}
		results = append(results, r)
	}
	return results
}

type Context struct {
	BootID string
	Kernel string
	Now    time.Time
	DryRun bool
}

type Entry struct {
	Kind        string       `json:"kind"`
	Time        time.Time    `json:"time"`
	BootID      string       `json:"boot_id,omitempty"`
	Kernel      string       `json:"kernel,omitempty"`
	Trial       string       `json:"trial"`
	Steps       []StepResult `json:"steps,omitempty"`
	TrialBootID string       `json:"trial_boot_id,omitempty"`
	Outcome     string       `json:"outcome,omitempty"`
	Note        string       `json:"note,omitempty"`
}

type Log struct {
	Path string
}

func (l *Log) Append(e Entry) error {
	if err := os.MkdirAll(filepath.Dir(l.Path), 0o755); err != nil {
		return err
	}
	f, err := os.OpenFile(l.Path, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0o644)
	if err != nil {
		return err
	}
	b, err := json.Marshal(e)
	if err != nil {
		f.Close()
		return err
	}
	if _, err := f.Write(append(b, '\n')); err != nil {
		f.Close()
		return err
	}
	if err := f.Sync(); err != nil {
		f.Close()
		return err
	}
	return f.Close()
}

func (l *Log) Read() ([]Entry, error) {
	f, err := os.Open(l.Path)
	if errors.Is(err, os.ErrNotExist) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	defer f.Close()
	var entries []Entry
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		if strings.TrimSpace(sc.Text()) == "" {
			continue
		}
		var e Entry
		if err := json.Unmarshal(sc.Bytes(), &e); err != nil {
			return nil, err
		}
		entries = append(entries, e)
	}
	return entries, sc.Err()
}

func Execute(s System, log *Log, id string, ctx Context, breadcrumb func(string)) error {
	t, err := Lookup(id)
	if err != nil {
		return err
	}
	if t.Manual != "" || ctx.DryRun {
		return nil
	}
	results := Apply(s, t)
	if err := log.Append(Entry{
		Kind:   "trial",
		Time:   ctx.Now,
		BootID: ctx.BootID,
		Kernel: ctx.Kernel,
		Trial:  t.ID,
		Steps:  results,
	}); err != nil {
		return fmt.Errorf("record trial: %w", err)
	}
	breadcrumb(fmt.Sprintf("test-shutdown: trial=%s boot=%s", t.ID, ctx.BootID))
	return s.Run("systemctl", "poweroff")
}

func RecordResult(log *Log, outcome, note string, ctx Context) error {
	if outcome != "off" && outcome != "hung" {
		return fmt.Errorf("outcome must be off or hung, got %q", outcome)
	}
	entries, err := log.Read()
	if err != nil {
		return err
	}
	var last *Entry
	for i := range entries {
		if entries[i].Kind == "trial" {
			last = &entries[i]
		}
	}
	if last == nil {
		return errors.New("no trial recorded yet")
	}
	return log.Append(Entry{
		Kind:        "result",
		Time:        ctx.Now,
		BootID:      ctx.BootID,
		Trial:       last.Trial,
		TrialBootID: last.BootID,
		Outcome:     outcome,
		Note:        note,
	})
}
