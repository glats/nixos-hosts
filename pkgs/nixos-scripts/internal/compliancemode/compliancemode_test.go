package compliancemode

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"
)

func loaderText(entry string) string {
	return "timeout 3\ndefault " + entry + "\nconsole-mode max\n"
}

type fakeRunner struct {
	f           *fixture
	calls       []string
	failures    map[string]error
	beforeRun   func(action string)
	skipRuntime bool
}

func (r *fakeRunner) Run(name string, args ...string) error {
	r.calls = append(r.calls, strings.TrimSpace(name+" "+strings.Join(args, " ")))
	if len(args) != 1 {
		return fmt.Errorf("unexpected arguments %q", args)
	}
	action := args[0]
	if r.beforeRun != nil {
		r.beforeRun(action)
	}
	if err := r.failures[action]; err != nil {
		return err
	}
	if action == "switch" && !r.skipRuntime {
		r.f.setRuntime(filepath.Dir(filepath.Dir(name)))
	}
	return nil
}

type fixture struct {
	t      *testing.T
	paths  Paths
	env    Env
	runner *fakeRunner
}

type result struct {
	code   int
	stdout string
	stderr string
}

func newFixture(t *testing.T) *fixture {
	t.Helper()
	root := t.TempDir()
	paths := Paths{
		StoreDir:    filepath.Join(root, "nix", "store"),
		ProfilesDir: filepath.Join(root, "nix", "var", "nix", "profiles"),
		RuntimeLink: filepath.Join(root, "run", "current-system"),
		LoaderDir:   filepath.Join(root, "boot", "loader"),
		EFIVarsDir:  filepath.Join(root, "sys", "firmware", "efi", "efivars"),
		LockFile:    filepath.Join(root, "run", "lock", "compliance-mode.lock"),
	}
	for _, dir := range []string{
		paths.StoreDir,
		paths.ProfilesDir,
		filepath.Join(paths.LoaderDir, "entries"),
		paths.EFIVarsDir,
		filepath.Dir(paths.LockFile),
		filepath.Dir(paths.RuntimeLink),
	} {
		mustMkdir(t, dir)
	}
	f := &fixture{t: t, paths: paths, runner: &fakeRunner{}}
	f.runner.f = f
	f.env = Env{GOOS: "linux", Euid: 0, Paths: paths, Runner: f.runner}
	return f
}

func mustMkdir(t *testing.T, dir string) {
	t.Helper()
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}
}

func mustWrite(t *testing.T, path, content string, mode os.FileMode) {
	t.Helper()
	mustMkdir(t, filepath.Dir(path))
	if err := os.WriteFile(path, []byte(content), mode); err != nil {
		t.Fatal(err)
	}
}

func mustLink(t *testing.T, target, link string) {
	t.Helper()
	_ = os.Remove(link)
	if err := os.Symlink(target, link); err != nil {
		t.Fatal(err)
	}
}

func (f *fixture) resolve(path string) string {
	f.t.Helper()
	resolved, err := filepath.EvalSymlinks(path)
	if err != nil {
		f.t.Fatal(err)
	}
	return resolved
}

func (f *fixture) closure(rel, marker string) string {
	f.t.Helper()
	dir := filepath.Join(f.paths.StoreDir, rel)
	mustWrite(f.t, filepath.Join(dir, "bin", "switch-to-configuration"), "#!/bin/sh\n", 0o755)
	mustWrite(f.t, filepath.Join(dir, "boot.json"), `{"org.nixos.specialisation.v1":{}}`, 0o644)
	mustWrite(f.t, filepath.Join(dir, "etc", "corporate-compliance", "mode"), marker+"\n", 0o644)
	return dir
}

func (f *fixture) generationClosure(rel string) (parent, child string) {
	f.t.Helper()
	parent = f.closure(rel, "on")
	mustWrite(f.t, filepath.Join(parent, "boot.json"), `{"org.nixos.specialisation.v1":{"compliance-off":{}}}`, 0o644)
	child = f.closure(filepath.Join(rel, "specialisation", offSpecialisation), "off")
	return f.resolve(parent), f.resolve(child)
}

func (f *fixture) setGeneration(n int, closure string) {
	f.t.Helper()
	mustLink(f.t, closure, filepath.Join(f.paths.ProfilesDir, fmt.Sprintf("system-%d-link", n)))
}

func (f *fixture) selectGeneration(n int) {
	f.t.Helper()
	mustLink(f.t, fmt.Sprintf("system-%d-link", n), filepath.Join(f.paths.ProfilesDir, "system"))
}

func (f *fixture) setRuntime(closure string) {
	f.t.Helper()
	mustLink(f.t, closure, f.paths.RuntimeLink)
}

func (f *fixture) loaderPath() string {
	return filepath.Join(f.paths.LoaderDir, "loader.conf")
}

func (f *fixture) writeLoader(entry string) {
	f.t.Helper()
	mustWrite(f.t, f.loaderPath(), loaderText(entry), 0o644)
}

func (f *fixture) writeEntries(names ...string) {
	f.t.Helper()
	for _, name := range names {
		mustWrite(f.t, filepath.Join(f.paths.LoaderDir, "entries", name), "title test\n", 0o644)
	}
}

func (f *fixture) baseline(runtimeOff bool) (parent, child string) {
	f.t.Helper()
	parent, child = f.generationClosure("aaaa-nixos-gen1")
	f.setGeneration(1, parent)
	f.selectGeneration(1)
	f.writeEntries(onEntryName(1), offEntryName(1))
	if runtimeOff {
		f.setRuntime(child)
		f.writeLoader(offEntryName(1))
	} else {
		f.setRuntime(parent)
		f.writeLoader(onEntryName(1))
	}
	return parent, child
}

func (f *fixture) run(args ...string) result {
	var stdout, stderr bytes.Buffer
	code := Run(args, &stdout, &stderr, f.env)
	return result{code: code, stdout: stdout.String(), stderr: stderr.String()}
}

func (f *fixture) assertState(parent, runtime, entry string) {
	f.t.Helper()
	if got := f.resolve(filepath.Join(f.paths.ProfilesDir, "system")); got != parent {
		f.t.Errorf("selected profile = %q, want %q", got, parent)
	}
	if got := f.resolve(f.paths.RuntimeLink); got != runtime {
		f.t.Errorf("runtime = %q, want %q", got, runtime)
	}
	if got := mustRead(f.t, f.loaderPath()); got != loaderText(entry) {
		f.t.Errorf("loader.conf = %q, want %q", got, loaderText(entry))
	}
}

func mustRead(t *testing.T, path string) string {
	t.Helper()
	raw, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	return string(raw)
}

func assertResult(t *testing.T, got, want result) {
	t.Helper()
	if got.code != want.code {
		t.Errorf("exit code = %d, want %d", got.code, want.code)
	}
	if got.stdout != want.stdout {
		t.Errorf("stdout = %q, want %q", got.stdout, want.stdout)
	}
	if got.stderr != want.stderr {
		t.Errorf("stderr = %q, want %q", got.stderr, want.stderr)
	}
}

func assertCalls(t *testing.T, got, want []string) {
	t.Helper()
	if strings.Join(got, "\n") != strings.Join(want, "\n") {
		t.Errorf("runner calls = %q, want %q", got, want)
	}
}

func TestHelpWorksWithoutRootOrLinux(t *testing.T) {
	for _, args := range [][]string{{"help"}, {"-h"}, {"--help"}} {
		f := newFixture(t)
		f.env.GOOS, f.env.Euid = "darwin", 501
		assertResult(t, f.run(args...), result{code: 0, stdout: usageText})
		assertCalls(t, f.runner.calls, nil)
	}
}

func TestUnknownCommandIsUsageError(t *testing.T) {
	f := newFixture(t)
	assertResult(t, f.run("bogus"), result{code: 2, stderr: "compliance-mode: unknown command \"bogus\"\n" + usageText})
	assertCalls(t, f.runner.calls, nil)
}

func TestMutationRequiresLinuxAndRoot(t *testing.T) {
	tests := []struct {
		name   string
		goos   string
		euid   int
		stderr string
	}{
		{name: "darwin", goos: "darwin", euid: 0, stderr: "compliance-mode: off requires Linux\n"},
		{name: "non-root", goos: "linux", euid: 1000, stderr: "compliance-mode: off requires root\n"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			f := newFixture(t)
			parent, _ := f.baseline(false)
			f.env.GOOS, f.env.Euid = tt.goos, tt.euid
			assertResult(t, f.run("off"), result{code: 1, stderr: tt.stderr})
			assertCalls(t, f.runner.calls, nil)
			f.assertState(parent, parent, onEntryName(1))
		})
	}
}

func TestOffSelectsComplianceSpecialisationAndBootDefault(t *testing.T) {
	f := newFixture(t)
	parent, child := f.baseline(false)
	assertResult(t, f.run("off"), result{
		code:   0,
		stdout: "compliance-mode: off applied; runtime " + child + "; boot selection " + offEntryName(1) + "\n",
	})
	assertCalls(t, f.runner.calls, []string{child + "/bin/switch-to-configuration switch"})
	f.assertState(parent, child, offEntryName(1))
}

func TestOnRestoresOnlyThePairedParentGeneration(t *testing.T) {
	f := newFixture(t)
	parent, _ := f.baseline(true)
	unrelated, _ := f.generationClosure("bbbb-nixos-gen0")
	f.setGeneration(0, unrelated)
	assertResult(t, f.run("on"), result{
		code:   0,
		stdout: "compliance-mode: on applied; runtime " + parent + "; boot selection " + onEntryName(1) + "\n",
	})
	assertCalls(t, f.runner.calls, []string{parent + "/bin/switch-to-configuration switch"})
	f.assertState(parent, parent, onEntryName(1))
	if got := f.resolve(filepath.Join(f.paths.ProfilesDir, "system-0-link")); got != unrelated {
		t.Errorf("unrelated generation changed to %q", got)
	}
}

func TestOnRefusesRuntimeNotPairedWithSelectedGeneration(t *testing.T) {
	f := newFixture(t)
	f.baseline(true)
	_, otherChild := f.generationClosure("cccc-nixos-other")
	f.setRuntime(otherChild)
	assertResult(t, f.run("on"), result{
		code: 1,
		stderr: "compliance-mode: refused: state is not consistent\n" +
			"problem: runtime " + otherChild + " is neither generation 1 nor its compliance-off specialisation\n",
	})
	assertCalls(t, f.runner.calls, nil)
}

func TestIdempotentRequestsStillValidateConsistency(t *testing.T) {
	t.Run("already off", func(t *testing.T) {
		f := newFixture(t)
		parent, child := f.baseline(true)
		assertResult(t, f.run("off"), result{
			code:   0,
			stdout: "compliance-mode: already off; runtime, selected generation and boot selection agree\n",
		})
		assertCalls(t, f.runner.calls, nil)
		f.assertState(parent, child, offEntryName(1))
	})
	t.Run("already on", func(t *testing.T) {
		f := newFixture(t)
		parent, _ := f.baseline(false)
		assertResult(t, f.run("on"), result{
			code:   0,
			stdout: "compliance-mode: already on; runtime, selected generation and boot selection agree\n",
		})
		assertCalls(t, f.runner.calls, nil)
		f.assertState(parent, parent, onEntryName(1))
	})
	t.Run("off runtime with ON boot default is refused", func(t *testing.T) {
		f := newFixture(t)
		parent, child := f.baseline(true)
		f.writeLoader(onEntryName(1))
		assertResult(t, f.run("off"), result{
			code: 1,
			stderr: "compliance-mode: refused: state is not consistent\n" +
				"problem: boot default " + onEntryName(1) + " does not select OFF entry " + offEntryName(1) + "\n",
		})
		assertCalls(t, f.runner.calls, nil)
		f.assertState(parent, child, onEntryName(1))
	})
}

func TestStatusReportsOnlyConsistentSelections(t *testing.T) {
	t.Run("on", func(t *testing.T) {
		f := newFixture(t)
		parent, _ := f.baseline(false)
		f.env.GOOS, f.env.Euid = "linux", 1000
		assertResult(t, f.run("status"), result{
			code: 0,
			stdout: "compliance-mode: on\nruntime: " + parent + "\nselected generation: 1 (" + parent + ")\n" +
				"boot selection: " + onEntryName(1) + "\npersistence: ok\n",
		})
		assertCalls(t, f.runner.calls, nil)
	})
	t.Run("off", func(t *testing.T) {
		f := newFixture(t)
		parent, child := f.baseline(true)
		assertResult(t, f.run("status"), result{
			code: 0,
			stdout: "compliance-mode: off\nruntime: " + child + "\nselected generation: 1 (" + parent + ")\n" +
				"boot selection: " + offEntryName(1) + "\npersistence: ok\n",
		})
	})
	t.Run("missing boot default is unknown", func(t *testing.T) {
		f := newFixture(t)
		parent, _ := f.baseline(false)
		if err := os.Remove(f.loaderPath()); err != nil {
			t.Fatal(err)
		}
		_, readErr := os.ReadFile(f.loaderPath())
		assertResult(t, f.run("status"), result{
			code: 1,
			stdout: "compliance-mode: unknown\nruntime: " + parent + "\nselected generation: 1 (" + parent + ")\n" +
				"boot selection: unknown\npersistence: ok\nproblem: boot default unreadable: " + readErr.Error() + "\n",
		})
	})
	t.Run("missing marker is unknown", func(t *testing.T) {
		f := newFixture(t)
		parent, _ := f.baseline(false)
		markerPath := filepath.Join(parent, "etc", "corporate-compliance", "mode")
		if err := os.Remove(markerPath); err != nil {
			t.Fatal(err)
		}
		_, readErr := os.ReadFile(markerPath)
		assertResult(t, f.run("status"), result{
			code: 1,
			stdout: "compliance-mode: unknown\nruntime: " + parent + "\nselected generation: 1 (" + parent + ")\n" +
				"boot selection: " + onEntryName(1) + "\npersistence: ok\n" +
				"problem: selected generation marker unreadable: " + readErr.Error() + "\n",
		})
	})
	t.Run("boot default mismatch is unknown", func(t *testing.T) {
		f := newFixture(t)
		parent, _ := f.baseline(false)
		f.writeLoader(offEntryName(1))
		assertResult(t, f.run("status"), result{
			code: 1,
			stdout: "compliance-mode: unknown\nruntime: " + parent + "\nselected generation: 1 (" + parent + ")\n" +
				"boot selection: " + offEntryName(1) + "\npersistence: ok\n" +
				"problem: boot default " + offEntryName(1) + " does not select ON entry " + onEntryName(1) + "\n",
		})
	})
	t.Run("EFI override blocks persistence", func(t *testing.T) {
		f := newFixture(t)
		parent, _ := f.baseline(false)
		mustWrite(t, filepath.Join(f.paths.EFIVarsDir, "LoaderEntryDefault-4a67b082-0a4c-41cf-b6c7-440b29bb8c4f"), "", 0o644)
		assertResult(t, f.run("status"), result{
			code: 1,
			stdout: "compliance-mode: unknown\nruntime: " + parent + "\nselected generation: 1 (" + parent + ")\n" +
				"boot selection: " + onEntryName(1) + "\npersistence: blocked\n" +
				"problem: persistence: EFI override LoaderEntryDefault is present\n",
		})
	})
}

func TestPersistenceBlockersRefuseBeforeMutation(t *testing.T) {
	t.Run("EFI override", func(t *testing.T) {
		f := newFixture(t)
		parent, _ := f.baseline(false)
		mustWrite(t, filepath.Join(f.paths.EFIVarsDir, "LoaderEntryDefault-4a67b082-0a4c-41cf-b6c7-440b29bb8c4f"), "", 0o644)
		assertResult(t, f.run("off"), result{
			code: 1,
			stderr: "compliance-mode: refused: state is not consistent\n" +
				"problem: persistence: EFI override LoaderEntryDefault is present\n",
		})
		assertCalls(t, f.runner.calls, nil)
		f.assertState(parent, parent, onEntryName(1))
	})
	t.Run("EFI variables unavailable", func(t *testing.T) {
		f := newFixture(t)
		parent, _ := f.baseline(false)
		if err := os.RemoveAll(f.paths.EFIVarsDir); err != nil {
			t.Fatal(err)
		}
		assertResult(t, f.run("off"), result{
			code: 1,
			stderr: "compliance-mode: refused: state is not consistent\n" +
				"problem: persistence: EFI variables unavailable at " + f.paths.EFIVarsDir + "\n",
		})
		assertCalls(t, f.runner.calls, nil)
		f.assertState(parent, parent, onEntryName(1))
	})
}

func TestOffRequiresPairedChildAndBootEntry(t *testing.T) {
	t.Run("specialisation missing", func(t *testing.T) {
		f := newFixture(t)
		parent, _ := f.baseline(false)
		if err := os.RemoveAll(filepath.Join(parent, "specialisation")); err != nil {
			t.Fatal(err)
		}
		assertResult(t, f.run("off"), result{
			code:   1,
			stderr: "compliance-mode: refused: compliance-off specialisation is missing from generation 1\n",
		})
		assertCalls(t, f.runner.calls, nil)
		f.assertState(parent, parent, onEntryName(1))
	})
	t.Run("boot entry missing", func(t *testing.T) {
		f := newFixture(t)
		parent, _ := f.baseline(false)
		if err := os.Remove(filepath.Join(f.paths.LoaderDir, "entries", offEntryName(1))); err != nil {
			t.Fatal(err)
		}
		assertResult(t, f.run("off"), result{
			code:   1,
			stderr: "compliance-mode: refused: boot entry " + offEntryName(1) + " is missing\n",
		})
		assertCalls(t, f.runner.calls, nil)
		f.assertState(parent, parent, onEntryName(1))
	})
}

func TestOnRefusesMissingBootEntry(t *testing.T) {
	f := newFixture(t)
	f.baseline(true)
	if err := os.Remove(filepath.Join(f.paths.LoaderDir, "entries", onEntryName(1))); err != nil {
		t.Fatal(err)
	}
	assertResult(t, f.run("on"), result{
		code:   1,
		stderr: "compliance-mode: refused: boot entry " + onEntryName(1) + " is missing\n",
	})
	assertCalls(t, f.runner.calls, nil)
}

func TestBootDefaultWriteFailureRefusesBeforeSwitch(t *testing.T) {
	if os.Geteuid() == 0 {
		t.Skip("directory permissions do not block writes for root")
	}
	f := newFixture(t)
	parent, _ := f.baseline(false)
	if err := os.Chmod(f.paths.LoaderDir, 0o555); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = os.Chmod(f.paths.LoaderDir, 0o755) })
	got := f.run("off")
	if got.code != 1 || !strings.HasPrefix(got.stderr, "compliance-mode: refused: cannot write boot default: ") {
		t.Fatalf("result = %+v, want refusal before switch", got)
	}
	assertCalls(t, f.runner.calls, nil)
	f.assertState(parent, parent, onEntryName(1))
}

func TestSwitchFailureRestoresBootDefaultAndReportsRuntimeUncertainty(t *testing.T) {
	f := newFixture(t)
	parent, child := f.baseline(false)
	f.runner.failures = map[string]error{"switch": fmt.Errorf("injected switch failure")}
	assertResult(t, f.run("off"), result{
		code: 1,
		stderr: "compliance-mode: switch failed: injected switch failure\n" +
			"compliance-mode: boot default restored to " + onEntryName(1) + "\n" + runtimeUncertain,
	})
	assertCalls(t, f.runner.calls, []string{child + "/bin/switch-to-configuration switch"})
	f.assertState(parent, parent, onEntryName(1))
}

func TestRollbackFailureIsReportedAsUncertain(t *testing.T) {
	if os.Geteuid() == 0 {
		t.Skip("directory permissions do not block writes for root")
	}
	f := newFixture(t)
	parent, child := f.baseline(false)
	f.runner.failures = map[string]error{"switch": fmt.Errorf("injected switch failure")}
	f.runner.beforeRun = func(action string) {
		if action == "switch" {
			if err := os.Chmod(f.paths.LoaderDir, 0o555); err != nil {
				t.Fatal(err)
			}
		}
	}
	t.Cleanup(func() { _ = os.Chmod(f.paths.LoaderDir, 0o755) })
	got := f.run("off")
	wantPrefix := "compliance-mode: switch failed: injected switch failure\ncompliance-mode: rollback failed: "
	if got.code != 1 || !strings.HasPrefix(got.stderr, wantPrefix) || !strings.HasSuffix(got.stderr, runtimeUncertain) {
		t.Fatalf("result = %+v, want rollback failure with uncertainty", got)
	}
	assertCalls(t, f.runner.calls, []string{child + "/bin/switch-to-configuration switch"})
	f.assertState(parent, parent, offEntryName(1))
}

func TestExternalProfileMoveIsNotRolledBack(t *testing.T) {
	f := newFixture(t)
	parent, child := f.baseline(false)
	f.runner.failures = map[string]error{"switch": fmt.Errorf("injected switch failure")}
	f.runner.beforeRun = func(action string) {
		if action == "switch" {
			f.setGeneration(2, parent)
			f.selectGeneration(2)
		}
	}
	assertResult(t, f.run("off"), result{
		code: 1,
		stderr: "compliance-mode: switch failed: injected switch failure\n" +
			"compliance-mode: selected profile moved to generation 2; boot default not restored\n" + runtimeUncertain,
	})
	assertCalls(t, f.runner.calls, []string{child + "/bin/switch-to-configuration switch"})
	if got := f.resolve(filepath.Join(f.paths.ProfilesDir, "system")); got != parent {
		t.Errorf("profile = %q, want external move kept at %q", got, parent)
	}
	if got := mustRead(t, f.loaderPath()); got != loaderText(offEntryName(1)) {
		t.Errorf("loader.conf = %q, want unchanged OFF selection", got)
	}
}

func TestExternalBootDefaultEditIsNotOverwritten(t *testing.T) {
	f := newFixture(t)
	_, child := f.baseline(false)
	f.runner.failures = map[string]error{"switch": fmt.Errorf("injected switch failure")}
	f.runner.beforeRun = func(action string) {
		if action == "switch" {
			f.writeLoader("external.conf")
		}
	}
	assertResult(t, f.run("off"), result{
		code: 1,
		stderr: "compliance-mode: switch failed: injected switch failure\n" +
			"compliance-mode: boot default changed during the operation; not restored\n" + runtimeUncertain,
	})
	assertCalls(t, f.runner.calls, []string{child + "/bin/switch-to-configuration switch"})
	if got := mustRead(t, f.loaderPath()); got != loaderText("external.conf") {
		t.Errorf("loader.conf = %q, want external edit kept", got)
	}
}

func TestPostconditionMismatchExitsNonzeroWithoutRevert(t *testing.T) {
	f := newFixture(t)
	_, child := f.baseline(false)
	f.runner.skipRuntime = true
	assertResult(t, f.run("off"), result{
		code: 1,
		stderr: "compliance-mode: postcondition failed: state is not as requested\n" +
			"problem: boot default " + offEntryName(1) + " does not select ON entry " + onEntryName(1) + "\n",
	})
	assertCalls(t, f.runner.calls, []string{child + "/bin/switch-to-configuration switch"})
	if got := mustRead(t, f.loaderPath()); got != loaderText(offEntryName(1)) {
		t.Errorf("loader.conf = %q, want uncorrected OFF selection", got)
	}
}

func treeHash(t *testing.T, root string) string {
	t.Helper()
	h := sha256.New()
	err := filepath.WalkDir(root, func(p string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		rel, err := filepath.Rel(root, p)
		if err != nil {
			return err
		}
		if filepath.Base(rel) == "compliance-mode.lock" {
			return nil
		}
		h.Write([]byte(rel))
		switch {
		case d.Type()&fs.ModeSymlink != 0:
			target, err := os.Readlink(p)
			if err != nil {
				return err
			}
			h.Write([]byte(target))
		case !d.IsDir():
			raw, err := os.ReadFile(p)
			if err != nil {
				return err
			}
			h.Write(raw)
		}
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
	return hex.EncodeToString(h.Sum(nil))
}

func TestConcurrentOffIsSerializedAndIdempotent(t *testing.T) {
	f := newFixture(t)
	_, child := f.baseline(false)
	f.runner.beforeRun = func(string) { time.Sleep(150 * time.Millisecond) }
	var wg sync.WaitGroup
	results := make([]result, 2)
	for i := range results {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			var stdout, stderr bytes.Buffer
			code := Run([]string{"off"}, &stdout, &stderr, f.env)
			results[i] = result{code: code, stdout: stdout.String(), stderr: stderr.String()}
		}(i)
	}
	wg.Wait()
	assertCalls(t, f.runner.calls, []string{child + "/bin/switch-to-configuration switch"})
	applied, already := 0, 0
	for _, r := range results {
		if r.code != 0 || r.stderr != "" {
			t.Fatalf("concurrent off result = %+v, want success", r)
		}
		switch {
		case strings.Contains(r.stdout, "compliance-mode: off applied;"):
			applied++
		case r.stdout == "compliance-mode: already off; runtime, selected generation and boot selection agree\n":
			already++
		default:
			t.Fatalf("unexpected stdout %q", r.stdout)
		}
	}
	if applied != 1 || already != 1 {
		t.Fatalf("applied=%d already=%d, want exactly one of each", applied, already)
	}
}

func TestConcurrentOppositeTransitionsEndConsistent(t *testing.T) {
	f := newFixture(t)
	f.baseline(false)
	f.runner.beforeRun = func(string) { time.Sleep(100 * time.Millisecond) }
	var wg sync.WaitGroup
	for _, target := range []string{"off", "on"} {
		wg.Add(1)
		go func(target string) {
			defer wg.Done()
			var stdout, stderr bytes.Buffer
			Run([]string{target}, &stdout, &stderr, f.env)
		}(target)
	}
	wg.Wait()
	status := f.run("status")
	if status.code != 0 {
		t.Fatalf("final status = %+v, want a consistent on or off state", status)
	}
	if !strings.HasPrefix(status.stdout, "compliance-mode: on\n") && !strings.HasPrefix(status.stdout, "compliance-mode: off\n") {
		t.Fatalf("final status = %q, want on or off", status.stdout)
	}
}

func TestRejectedCommandsLeavePersistedDataUnchanged(t *testing.T) {
	f := newFixture(t)
	f.baseline(false)
	mustWrite(t, filepath.Join(f.paths.EFIVarsDir, "LoaderEntryOneShot-"+efiVendorGUID), "x", 0o644)
	root := filepath.Dir(filepath.Dir(f.paths.LoaderDir))
	before := treeHash(t, root)
	for _, args := range [][]string{{"off"}, {"on"}, {"ON"}, {"off", "x"}, {"bogus"}, {}} {
		f.run(args...)
	}
	if after := treeHash(t, root); after != before {
		t.Fatal("persisted data changed after rejected commands")
	}
	assertCalls(t, f.runner.calls, nil)
}

func TestLoaderTransitionPreservesUnrelatedLinesAndLeavesNoTemp(t *testing.T) {
	f := newFixture(t)
	f.baseline(false)
	mustWrite(t, f.loaderPath(), "# c\ntimeout 7\ndefault "+onEntryName(1)+"\neditor 0\nconsole-mode max", 0o644)
	if r := f.run("off"); r.code != 0 {
		t.Fatalf("off result = %+v", r)
	}
	want := "# c\ntimeout 7\ndefault " + offEntryName(1) + "\neditor 0\nconsole-mode max"
	if got := mustRead(t, f.loaderPath()); got != want {
		t.Fatalf("loader.conf = %q, want %q", got, want)
	}
	entries, err := os.ReadDir(f.paths.LoaderDir)
	if err != nil {
		t.Fatal(err)
	}
	for _, entry := range entries {
		if strings.HasSuffix(entry.Name(), ".tmp") {
			t.Fatalf("temporary file %s left behind", entry.Name())
		}
	}
}

func TestSwitchUsesPairedClosureExecutables(t *testing.T) {
	f := newFixture(t)
	parent, child := f.baseline(false)
	if r := f.run("off"); r.code != 0 {
		t.Fatalf("off result = %+v", r)
	}
	if r := f.run("on"); r.code != 0 {
		t.Fatalf("on result = %+v", r)
	}
	assertCalls(t, f.runner.calls, []string{
		child + "/bin/switch-to-configuration switch",
		parent + "/bin/switch-to-configuration switch",
	})
}

func TestNewerProfileRefusesOlderRuntime(t *testing.T) {
	f := newFixture(t)
	_, olderChild := f.baseline(true)
	newer, _ := f.generationClosure("bbbb-nixos-gen2")
	f.setGeneration(2, newer)
	f.selectGeneration(2)
	f.writeEntries(onEntryName(2), offEntryName(2))
	root := filepath.Dir(filepath.Dir(f.paths.LoaderDir))
	before := treeHash(t, root)
	assertResult(t, f.run("on"), result{
		code: 1,
		stderr: "compliance-mode: refused: state is not consistent\n" +
			"problem: runtime " + olderChild + " is neither generation 2 nor its compliance-off specialisation\n",
	})
	assertCalls(t, f.runner.calls, nil)
	if after := treeHash(t, root); after != before {
		t.Fatal("persisted data changed after refused transition")
	}
}
