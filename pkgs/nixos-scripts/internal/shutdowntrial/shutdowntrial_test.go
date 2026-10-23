package shutdowntrial

import (
	"errors"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
	"time"
)

const wakeupSample = `Device	S-state	  Status   Sysfs node
PEG0	  S4	*enabled   pci:0000:00:01.0
PEGP	  S4	*disabled
RP04	  S4	*enabled   pci:0000:00:1c.3
PXSX	  S4	*enabled   pci:0000:03:00.0
LID0	  S4	*disabled  platform:PNP0C0D:00
XHC	  S3	*enabled   pci:0000:00:14.0
`

type fakeSystem struct {
	files   map[string]string
	globs   map[string][]string
	ops     []string
	failRun map[string]error
}

func newFake() *fakeSystem {
	return &fakeSystem{
		files: map[string]string{WakeupPath: wakeupSample},
		globs: map[string][]string{
			XHCIControlGlob: {
				"/sys/bus/pci/drivers/xhci_hcd/0000:00:14.0/power/control",
			},
		},
		failRun: map[string]error{},
	}
}

func (f *fakeSystem) ReadFile(path string) ([]byte, error) {
	v, ok := f.files[path]
	if !ok {
		return nil, errors.New("missing " + path)
	}
	return []byte(v), nil
}

func (f *fakeSystem) WriteFile(path string, data []byte) error {
	f.ops = append(f.ops, "write "+path+"="+string(data))
	return nil
}

func (f *fakeSystem) Glob(pattern string) ([]string, error) {
	return f.globs[pattern], nil
}

func (f *fakeSystem) Run(name string, args ...string) error {
	cmd := strings.Join(append([]string{name}, args...), " ")
	f.ops = append(f.ops, "run "+cmd)
	return f.failRun[cmd]
}

func TestEnabledWakeDevicesListsOnlyEnabled(t *testing.T) {
	got := EnabledWakeDevices(wakeupSample)
	want := []string{"PEG0", "RP04", "PXSX", "XHC"}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("got %v, want %v", got, want)
	}
}

func TestWakeTrialDisablesWolAndTogglesEnabledDevices(t *testing.T) {
	sys := newFake()
	tr, _ := Lookup("wake")
	res := Apply(sys, tr)
	want := []string{
		"run ethtool -s enp3s0 wol d",
		"write /proc/acpi/wakeup=PEG0",
		"write /proc/acpi/wakeup=RP04",
		"write /proc/acpi/wakeup=PXSX",
		"write /proc/acpi/wakeup=XHC",
	}
	if !reflect.DeepEqual(sys.ops, want) {
		t.Fatalf("ops %v, want %v", sys.ops, want)
	}
	for _, r := range res {
		if r.Error != "" {
			t.Fatalf("unexpected step error %+v", r)
		}
	}
}

func TestXHCITrialForcesPowerControlOn(t *testing.T) {
	sys := newFake()
	tr, _ := Lookup("xhci")
	Apply(sys, tr)
	want := []string{"write /sys/bus/pci/drivers/xhci_hcd/0000:00:14.0/power/control=on"}
	if !reflect.DeepEqual(sys.ops, want) {
		t.Fatalf("ops %v, want %v", sys.ops, want)
	}
}

func TestNvidiaTrialStopsDisplayThenUnloads(t *testing.T) {
	sys := newFake()
	tr, _ := Lookup("nvidia")
	Apply(sys, tr)
	want := []string{
		"run systemctl stop display-manager.service",
		"run modprobe -r nvidia_drm nvidia_uvm nvidia_modeset nvidia",
	}
	if !reflect.DeepEqual(sys.ops, want) {
		t.Fatalf("ops %v, want %v", sys.ops, want)
	}
}

func TestPstoreTrialDisablesShutdownDump(t *testing.T) {
	sys := newFake()
	tr, _ := Lookup("pstore")
	Apply(sys, tr)
	want := []string{"write " + KmsgDumpParam + "=N"}
	if !reflect.DeepEqual(sys.ops, want) {
		t.Fatalf("ops %v, want %v", sys.ops, want)
	}
}

func TestAllTrialStacksEveryAutomaticTrial(t *testing.T) {
	sys := newFake()
	tr, _ := Lookup("all")
	Apply(sys, tr)
	if len(sys.ops) != 5+1+2+1 {
		t.Fatalf("ops %v", sys.ops)
	}
}

func TestStepFailureIsRecordedAndLaterStepsStillRun(t *testing.T) {
	sys := newFake()
	sys.failRun["ethtool -s enp3s0 wol d"] = errors.New("no device")
	tr, _ := Lookup("wake")
	res := Apply(sys, tr)
	if res[0].Error == "" {
		t.Fatalf("first step error not recorded: %+v", res[0])
	}
	if len(sys.ops) != 5 {
		t.Fatalf("later steps skipped: %v", sys.ops)
	}
}

func TestLookupUnknownTrial(t *testing.T) {
	if _, err := Lookup("nope"); err == nil {
		t.Fatal("expected error for unknown trial")
	}
}

func TestManualTrialsHaveInstructionsAndNoSteps(t *testing.T) {
	for _, id := range []string{"outside", "ec-reset"} {
		tr, err := Lookup(id)
		if err != nil {
			t.Fatal(err)
		}
		if tr.Manual == "" || len(tr.Steps) != 0 {
			t.Fatalf("%s: manual=%q steps=%d", id, tr.Manual, len(tr.Steps))
		}
	}
}

func TestExecuteLogsBreadcrumbsAndPowersOffLast(t *testing.T) {
	sys := newFake()
	log := &Log{Path: filepath.Join(t.TempDir(), "trials.jsonl")}
	var crumbs []string
	now := time.Date(2026, 10, 22, 12, 0, 0, 0, time.UTC)
	err := Execute(sys, log, "xhci", Context{BootID: "b1", Kernel: "7.1.9", Now: now}, func(m string) { crumbs = append(crumbs, m) })
	if err != nil {
		t.Fatal(err)
	}
	if last := sys.ops[len(sys.ops)-1]; last != "run systemctl poweroff" {
		t.Fatalf("poweroff not last: %v", sys.ops)
	}
	if len(crumbs) != 1 || !strings.Contains(crumbs[0], "trial=xhci") {
		t.Fatalf("crumbs %v", crumbs)
	}
	entries, err := log.Read()
	if err != nil {
		t.Fatal(err)
	}
	if len(entries) != 1 || entries[0].Kind != "trial" || entries[0].Trial != "xhci" || entries[0].BootID != "b1" || entries[0].Kernel != "7.1.9" {
		t.Fatalf("entries %+v", entries)
	}
}

func TestExecuteDryRunChangesNothing(t *testing.T) {
	sys := newFake()
	log := &Log{Path: filepath.Join(t.TempDir(), "trials.jsonl")}
	err := Execute(sys, log, "all", Context{DryRun: true}, func(string) {})
	if err != nil {
		t.Fatal(err)
	}
	if len(sys.ops) != 0 {
		t.Fatalf("dry run mutated: %v", sys.ops)
	}
	if entries, _ := log.Read(); len(entries) != 0 {
		t.Fatalf("dry run logged: %+v", entries)
	}
}

func TestExecuteManualTrialDoesNotPowerOff(t *testing.T) {
	sys := newFake()
	log := &Log{Path: filepath.Join(t.TempDir(), "trials.jsonl")}
	if err := Execute(sys, log, "outside", Context{}, func(string) {}); err != nil {
		t.Fatal(err)
	}
	if len(sys.ops) != 0 {
		t.Fatalf("manual trial acted: %v", sys.ops)
	}
}

func TestRecordResultAttachesToLastTrial(t *testing.T) {
	log := &Log{Path: filepath.Join(t.TempDir(), "trials.jsonl")}
	if err := log.Append(Entry{Kind: "trial", Trial: "wake", BootID: "b1"}); err != nil {
		t.Fatal(err)
	}
	if err := RecordResult(log, "off", "fans stopped", Context{BootID: "b2"}); err != nil {
		t.Fatal(err)
	}
	entries, _ := log.Read()
	r := entries[1]
	if r.Kind != "result" || r.Trial != "wake" || r.Outcome != "off" || r.Note != "fans stopped" || r.TrialBootID != "b1" {
		t.Fatalf("result %+v", r)
	}
}

func TestRecordResultRejectsBadOutcomeAndMissingTrial(t *testing.T) {
	log := &Log{Path: filepath.Join(t.TempDir(), "trials.jsonl")}
	if err := RecordResult(log, "off", "", Context{}); err == nil {
		t.Fatal("expected error without a prior trial")
	}
	_ = log.Append(Entry{Kind: "trial", Trial: "wake"})
	if err := RecordResult(log, "maybe", "", Context{}); err == nil {
		t.Fatal("expected error for invalid outcome")
	}
}
