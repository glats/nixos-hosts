package nixbuild

import (
	"errors"
	"io"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
)

const (
	root     = "/repo"
	hostname = "t14"
)

var (
	flakeArg  = "/repo#t14"
	refTop    = "/repo#nixosConfigurations.t14.config.system.build.toplevel"
	refDarwin = "/repo#darwinConfigurations.t14.config.system.build.toplevel"
)

func mkEnv(darwin, nh, nom, raw, noNom bool) Env {
	return Env{
		Darwin: darwin, Raw: raw, NoNom: noNom,
		HasNH: nh, HasNom: nom, NomPath: "/usr/bin/nom",
		Hostname: hostname, FlakePath: root,
	}
}

func wantNames(steps []Step) []string {
	names := make([]string, len(steps))
	for i, st := range steps {
		switch st.Kind {
		case KindEcho:
			names[i] = "echo:" + st.Echo
		case KindExit:
			names[i] = "exit"
		case KindExec:
			n := "exec"
			if st.ThroughNom {
				n += "|nom"
			}
			names[i] = n + " " + joinArgs(st.Args)
		}
	}
	return names
}

func joinArgs(args []string) string {
	s := ""
	for i, a := range args {
		if i > 0 {
			s += " "
		}
		s += a
	}
	return s
}

type seqCase struct {
	name    string
	env     Env
	command string
	want    []Step
}

var linuxNH = mkEnv(false, true, false, false, false)

func linuxNHCases(prefix string) []seqCase {
	return []seqCase{
		{prefix + "switch", linuxNH, "switch", []Step{
			echo(""), echo("> Building NixOS configuration (switch)..."),
			ex("nh", "os", "switch"),
		}},
		{prefix + "boot", linuxNH, "boot", []Step{
			echo(""), echo("> Building NixOS configuration (boot)..."),
			ex("nh", "os", "boot"),
		}},
		{prefix + "test", linuxNH, "test", []Step{
			echo(""), echo("> Building NixOS configuration (test)..."),
			ex("nh", "os", "test"),
		}},
		{prefix + "upgrade", linuxNH, "upgrade", append([]Step{echo("")}, upgradeSteps(root, false)...)},
		{prefix + "dry", linuxNH, "dry", []Step{
			echo(""), echo("> Dry-activating (nh)..."),
			ex("nh", "os", "switch", "--dry"),
		}},
		{prefix + "check", linuxNH, "check", []Step{
			echo("> Validating flake..."),
			ex("nix", "flake", "check"),
		}},
		{prefix + "build", linuxNH, "build", []Step{
			echo("> Dry-building..."),
			ex("nh", "os", "build", "--hostname", hostname, root),
		}},
		{prefix + "safe", linuxNH, "safe", []Step{
			echo(""), echo("> Running safe build workflow..."), echo(""),
			echo("> [1/4] Checking flake..."),
			guard("nix", "flake", "check", "> ERROR: Flake check failed. Stopping."),
			echo(""),
			echo("> [2/4] Building..."),
			guard("nh", "os", "build", "--hostname", hostname, root, "> ERROR: Build failed. Stopping."),
			echo(""),
			echo("> [3/4] Dry-activating..."),
			guard("nh", "os", "switch", "--dry", "> ERROR: Dry-activate failed. Stopping."),
			echo(""),
			echo("> [4/4] Switching..."),
			guard("nh", "os", "switch", "> ERROR: Switch failed. Stopping."),
			echo(""), echo("> Safe build completed successfully!"),
		}},
	}
}

var linuxRaw = mkEnv(false, false, false, false, false)

func linuxRawCases(prefix string) []seqCase {
	return []seqCase{
		{prefix + "switch", linuxRaw, "switch", []Step{
			echo(""), echo("> Building NixOS configuration (switch)..."),
			ex("sudo", "nixos-rebuild", "switch", "--flake", flakeArg),
		}},
		{prefix + "boot", linuxRaw, "boot", []Step{
			echo(""), echo("> Building NixOS configuration (boot)..."),
			ex("sudo", "nixos-rebuild", "boot", "--flake", flakeArg),
		}},
		{prefix + "test", linuxRaw, "test", []Step{
			echo(""), echo("> Building NixOS configuration (test)..."),
			ex("sudo", "nixos-rebuild", "test", "--flake", flakeArg),
		}},
		{prefix + "upgrade", linuxRaw, "upgrade", append([]Step{echo("")}, upgradeSteps(root, false)...)},
		{prefix + "dry", linuxRaw, "dry", []Step{
			echo(""), echo("> Dry-activating..."),

			ex("sudo", "nixos-rebuild", "dry-activate", "--flake", flakeArg),
		}},
		{prefix + "check", linuxRaw, "check", []Step{
			echo("> Validating flake..."),
			ex("nix", "flake", "check"),
		}},
		{prefix + "build", linuxRaw, "build", []Step{
			echo("> Dry-building..."),
			ex("nix", "build", refTop),
		}},
		{prefix + "safe", linuxRaw, "safe", []Step{
			echo(""), echo("> Running safe build workflow..."), echo(""),
			echo("> [1/4] Checking flake..."),
			guard("nix", "flake", "check", "> ERROR: Flake check failed. Stopping."),
			echo(""),
			echo("> [2/4] Building..."),
			guard("nix", "build", refTop, "> ERROR: Build failed. Stopping."),
			echo(""),
			echo("> [3/4] Dry-activating..."),
			guard("sudo", "nixos-rebuild", "dry-activate", "--flake", flakeArg, "> ERROR: Dry-activate failed. Stopping."),
			echo(""),
			echo("> [4/4] Switching..."),
			guard("sudo", "nixos-rebuild", "switch", "--flake", flakeArg, "> ERROR: Switch failed. Stopping."),
			echo(""), echo("> Safe build completed successfully!"),
		}},
	}
}

func TestStepsLinuxNH(t *testing.T) {
	runSeqCases(t, linuxNHCases("LinuxNH/"))
}

func TestStepsLinuxNHBuildSelection(t *testing.T) {
	t.Setenv("NH_FLAKE", "/unrelated")
	for _, command := range []string{"build", "safe"} {
		for _, path := range []string{".", "/worktree with spaces"} {
			t.Run(command+"/"+path, func(t *testing.T) {
				env := mkEnv(false, true, true, false, true)
				env.Hostname, env.FlakePath = "rog", path
				index := 1
				if command == "safe" {
					index = 7
				}
				step := Steps(env, command)[index]
				want := ex("nh", "os", "build", "--hostname", "rog", path)
				assertSequence(t, []Step{step}, []Step{want})
				if command == "safe" && (len(step.FailLines) != 2 || step.FailLines[1] != "> ERROR: Build failed. Stopping.") {
					t.Fatalf("build guard = %q", step.FailLines)
				}
				for i, arg := range want.Args {
					if step.Args[i] != arg {
						t.Fatalf("argv[%d] = %q, want %q", i, step.Args[i], arg)
					}
				}
			})
		}
	}
}

func TestStepsLinuxRaw(t *testing.T) {
	runSeqCases(t, linuxRawCases("LinuxRaw/"))
}

func TestStepsLinuxRawFlagKillsNH(t *testing.T) {
	env := mkEnv(false, true, false, true, false)
	got := Steps(env, "switch")
	want := []Step{
		echo(""), echo("> Building NixOS configuration (switch)..."),
		ex("sudo", "nixos-rebuild", "switch", "--flake", flakeArg),
	}
	assertSequence(t, got, want)
}

func TestStepsLinuxNoNom(t *testing.T) {
	env := mkEnv(false, false, true, false, true)
	got := Steps(env, "switch")
	want := []Step{
		echo(""), echo("> Building NixOS configuration (switch)..."),
		ex("sudo", "nixos-rebuild", "switch", "--flake", flakeArg),
	}
	assertSequence(t, got, want)
}

func TestStepsLinuxNomPiping(t *testing.T) {
	env := mkEnv(false, false, true, false, false)
	cases := []struct {
		command string
		want    []Step
	}{
		{"switch", []Step{
			echo(""), echo("> Building NixOS configuration (switch)..."),
			exNom("sudo", "nixos-rebuild", "switch", "--flake", flakeArg),
		}},
		{"build", []Step{
			echo("> Dry-building..."),
			exNom("nix", "build", refTop),
		}},
		{"dry", []Step{
			echo(""), echo("> Dry-activating..."),

			ex("sudo", "nixos-rebuild", "dry-activate", "--flake", flakeArg),
		}},
		{"safe", []Step{
			echo(""), echo("> Running safe build workflow..."), echo(""),
			echo("> [1/4] Checking flake..."),
			guard("nix", "flake", "check", "> ERROR: Flake check failed. Stopping."),
			echo(""),
			echo("> [2/4] Building..."),
			guardNom("nix", "build", refTop, "> ERROR: Build failed. Stopping."),
			echo(""),
			echo("> [3/4] Dry-activating..."),
			guard("sudo", "nixos-rebuild", "dry-activate", "--flake", flakeArg, "> ERROR: Dry-activate failed. Stopping."),
			echo(""),
			echo("> [4/4] Switching..."),
			guardNom("sudo", "nixos-rebuild", "switch", "--flake", flakeArg, "> ERROR: Switch failed. Stopping."),
			echo(""), echo("> Safe build completed successfully!"),
		}},
	}
	for _, tc := range cases {
		assertSequence(t, Steps(env, tc.command), tc.want)
	}
}

func TestStepsLinuxNHNomAvailableBare(t *testing.T) {
	env := mkEnv(false, true, true, false, false)
	got := Steps(env, "build")
	want := []Step{
		echo("> Dry-building..."),
		ex("nh", "os", "build", "--hostname", hostname, root),
	}
	assertSequence(t, got, want)
}

func darwinCases() []seqCase {
	dflt := mkEnv(true, false, false, false, false)
	return []seqCase{
		{"Darwin/switch", dflt, "switch", []Step{
			echo(""), echo("> Building Darwin configuration (switch)..."),
			ex("sudo", "darwin-rebuild", "switch", "--flake", flakeArg),
		}},
		{"Darwin/boot", dflt, "boot", []Step{
			echo("> 'boot' not supported on Darwin. Use 'switch' instead."),
			{Kind: KindExit, ExitCode: 1},
		}},
		{"Darwin/test", dflt, "test", []Step{
			echo("> 'test' not supported on Darwin. Use 'switch' instead."),
			{Kind: KindExit, ExitCode: 1},
		}},
		{"Darwin/upgrade", dflt, "upgrade", append([]Step{echo("")}, upgradeSteps(root, true)...)},
		{"Darwin/dry", dflt, "dry", []Step{
			echo(""), echo("> Checking Darwin configuration (dry run)..."),
			ex("sudo", "darwin-rebuild", "check", "--flake", flakeArg),
		}},
		{"Darwin/check", dflt, "check", []Step{
			echo("> Validating flake..."),
			ex("nix", "flake", "check"),
		}},
		{"Darwin/build", dflt, "build", []Step{
			echo("> Dry-building..."),
			ex("nix", "build", refDarwin),
		}},
		{"Darwin/safe", dflt, "safe", []Step{
			echo(""), echo("> Running safe build workflow..."), echo(""),
			echo("> [1/4] Checking flake..."),
			guard("nix", "flake", "check", "> ERROR: Flake check failed. Stopping."),
			echo(""),
			echo("> [2/4] Building..."),
			guard("nix", "build", refDarwin, "> ERROR: Build failed. Stopping."),
			echo(""),
			echo("> [3/4] Dry-activating..."),
			guard("sudo", "darwin-rebuild", "check", "--flake", flakeArg, "> ERROR: Dry-activate failed. Stopping."),
			echo(""),
			echo("> [4/4] Switching..."),
			guard("sudo", "darwin-rebuild", "switch", "--flake", flakeArg, "> ERROR: Switch failed. Stopping."),
			echo(""), echo("> Safe build completed successfully!"),
		}},
	}
}

func TestStepsDarwin(t *testing.T) {
	runSeqCases(t, darwinCases())
}

func TestParseArgs(t *testing.T) {
	cases := []struct {
		name       string
		args       []string
		command    string
		raw, noNom bool
	}{
		{"empty defaults to switch", nil, "switch", false, false},
		{"single command", []string{"build"}, "build", false, false},
		{"flag before command", []string{"--no-nom", "switch"}, "switch", false, true},
		{"flag after command", []string{"switch", "--raw"}, "switch", true, false},
		{"both flags and command", []string{"--raw", "safe", "--no-nom"}, "safe", true, true},
		{"flags only", []string{"--raw", "--no-nom"}, "switch", true, true},
		{"extra args ignored like bash $1", []string{"switch", "bogus", "args"}, "switch", false, false},
	}
	for _, tc := range cases {
		command, raw, noNom := ParseArgs(tc.args)
		if command != tc.command || raw != tc.raw || noNom != tc.noNom {
			t.Errorf("%s: ParseArgs(%q) = (%q,%v,%v), want (%q,%v,%v)",
				tc.name, tc.args, command, raw, noNom, tc.command, tc.raw, tc.noNom)
		}
	}
}

func TestResolveHost(t *testing.T) {
	physical := func() (string, error) { return "CLFTCLGV2FHWW0W", nil }
	noOverride := func(string) string { return "" }

	if got := ResolveHost(true, noOverride, physical); got != "macm5" {
		t.Fatalf("Darwin default = %q, want macm5", got)
	}
	if got := ResolveHost(true, func(key string) string {
		if key == "NIXOS_DARWIN_HOST" {
			return "mact2"
		}
		return ""
	}, physical); got != "mact2" {
		t.Fatalf("Darwin override = %q, want mact2", got)
	}
	if got := ResolveHost(false, noOverride, physical); got != "CLFTCLGV2FHWW0W" {
		t.Fatalf("Linux hostname = %q, want physical hostname", got)
	}
}

func TestIsHelpAndKnown(t *testing.T) {
	for _, c := range []string{"help", "-h", "--help"} {
		if !IsHelp(c) {
			t.Errorf("IsHelp(%q) = false", c)
		}
	}
	for _, c := range []string{"switch", "boot", "test", "upgrade", "dry", "check", "build", "safe"} {
		if !IsKnown(c) {
			t.Errorf("IsKnown(%q) = false", c)
		}
	}
	if IsKnown("nonsense") {
		t.Error("IsKnown(nonsense) = true")
	}
	if IsHelp("switch") {
		t.Error("IsHelp(switch) = true")
	}
}

func TestDetectToolsDarwinNeverProbes(t *testing.T) {
	nh, nom := DetectTools(true)
	if nh != "" || nom != "" {
		t.Errorf("DetectTools(darwin) = (%q,%q), want (\"\",\"\")", nh, nom)
	}
	if !IsDarwin() {

		if runtime.GOOS != "linux" && IsDarwin() {
			t.Fatal("unreachable")
		}
	}
}

func TestRunExitPropagation(t *testing.T) {
	if runtime.GOOS != "linux" && runtime.GOOS != "darwin" {
		t.Skip("POSIX-only test")
	}
	cases := []struct {
		name  string
		steps []Step
		want  int
	}{
		{"success zero", []Step{execStep([]string{"true"}, false)}, 0},
		{"silent set -e death", []Step{execStep([]string{"false"}, false)}, 1},
		{"child exit code propagated", []Step{execStep([]string{"sh", "-c", "exit 7"}, false)}, 7},
		{"failure with guard prints and exits 1", []Step{
			execStep([]string{"false"}, false),
			{Kind: KindExec, Args: []string{"false"},
				FailLines: []string{"", "> ERROR: Build failed. Stopping."}},
		}, 1},
		{"exit step returns its code", []Step{{Kind: KindExit, ExitCode: 1}}, 1},
		{"npm capture failure propagates", []Step{
			execStep([]string{"false"}, false),
			execStep([]string{"true"}, false),
		}, 1},
		{"exec start failure is 127", []Step{
			execStep([]string{"definitely-not-a-command-xyz"}, false),
		}, 127},
	}
	for _, tc := range cases {
		if got := Run(tc.steps, ""); got != tc.want {
			t.Errorf("%s: Run = %d, want %d", tc.name, got, tc.want)
		}
	}
}

func nixUpdate(dir, attr string, flags ...string) Step {
	args := append([]string{"nix", "run", "nixpkgs#nix-update", "--", "--flake"}, flags...)
	args = append(args, attr)
	return Step{Kind: KindExec, Args: args, Dir: dir}
}

func upgradeSteps(root string, darwin bool) []Step {
	steps := []Step{
		echo("> Updating OpenCode executable and plugin closure..."),
		{Kind: KindOpenCodeRelease, Args: []string{root}},
		ex("npm", "install", "--prefix", root+"/pkgs/opencode-npm-packages-v2", "--package-lock-only", "--save-exact", "--no-audit", "--no-fund"),
		echo("> Updating BrowserMCP npm dependencies..."),
		ex("npm", "install", "--prefix", root+"/pkgs/browsermcp-v2", "--package-lock-only", "--save-exact", "--no-audit", "--no-fund", "@browsermcp/mcp@latest"),
		echo("> Updating GitHub release binaries..."),
		{Kind: KindReleasePins, Args: []string{root}},
		echo("> Pinning Gentle AI and Engram to their latest releases..."),
		{Kind: KindFlakePins, Args: []string{root}},
		echo("> Updating flake inputs..."),
		ex("nix", "flake", "update", "--flake", root),
		echo("> Updating source packages and vendor hashes..."),
		nixUpdate(root, "archify-skill"),
		nixUpdate(root, "herdr"),
	}
	if !darwin {
		steps = append(steps, nixUpdate(root, "openfang"), nixUpdate(root, "mcp-supermercados-cl"))
	}
	return append(steps,
		nixUpdate(root, "gentle-ai", "--version=skip"),
		nixUpdate(root, "engram", "--version=skip"),
		echo("Nothing was built or activated. Validate with 'check' and activate with 'switch'."))
}

func stubOpenCodeRelease(t *testing.T, err error) *[]string {
	t.Helper()
	var roots []string
	old, oldRelease, oldFlake := UpdateOpenCodeRelease, UpdateReleasePins, UpdateFlakePins
	UpdateOpenCodeRelease = func(root string) error {
		roots = append(roots, root)
		return err
	}
	UpdateReleasePins = func(string) error { return nil }
	UpdateFlakePins = func(string) error { return nil }
	t.Cleanup(func() { UpdateOpenCodeRelease, UpdateReleasePins, UpdateFlakePins = old, oldRelease, oldFlake })
	return &roots
}

func TestUpgradeStopsWhenOpenCodeUpdateFails(t *testing.T) {
	dir := t.TempDir()
	log := filepath.Join(dir, "calls")
	for _, name := range []string{"npm", "nix"} {
		if err := os.WriteFile(filepath.Join(dir, name), []byte("#!/bin/sh\necho "+name+" >> \"$CALL_LOG\"\n"), 0755); err != nil {
			t.Fatal(err)
		}
	}
	t.Setenv("PATH", dir)
	t.Setenv("CALL_LOG", log)
	roots := stubOpenCodeRelease(t, errors.New("registry unavailable"))
	if got := Run(Steps(Env{FlakePath: "/repo"}, "upgrade"), ""); got != 1 {
		t.Fatalf("Run = %d, want 1", got)
	}
	if len(*roots) != 1 || (*roots)[0] != "/repo" {
		t.Fatalf("OpenCode update roots = %v", *roots)
	}
	if _, err := os.Stat(log); !os.IsNotExist(err) {
		t.Fatalf("commands ran after OpenCode failure: %v", err)
	}
}

func TestUpgradeStopsOnNpmFailure(t *testing.T) {
	dir := t.TempDir()
	log := filepath.Join(dir, "calls")
	for name, script := range map[string]string{
		"npm": "echo npm-failed >&2\necho npm >> \"$CALL_LOG\"\nexit 9\n",
		"nix": "echo nix >> \"$CALL_LOG\"\nexit 0\n",
	} {
		path := filepath.Join(dir, name)
		if err := os.WriteFile(path, []byte("#!/bin/sh\n"+script), 0755); err != nil {
			t.Fatal(err)
		}
	}
	t.Setenv("PATH", dir)
	t.Setenv("CALL_LOG", log)
	roots := stubOpenCodeRelease(t, nil)
	steps := Steps(Env{FlakePath: "/repo with spaces"}, "upgrade")
	if got := steps[3].Args[3]; got != "/repo with spaces/pkgs/opencode-npm-packages-v2" {
		t.Fatalf("npm prefix = %q", got)
	}
	oldStderr := os.Stderr
	r, w, err := os.Pipe()
	if err != nil {
		t.Fatal(err)
	}
	os.Stderr = w
	code := Run(steps, "")
	w.Close()
	os.Stderr = oldStderr
	stderr, err := io.ReadAll(r)
	r.Close()
	if err != nil {
		t.Fatal(err)
	}
	if code != 9 {
		t.Fatalf("Run = %d, want npm exit 9", code)
	}
	if !strings.Contains(string(stderr), "npm-failed") {
		t.Fatalf("stderr = %q, want npm error", stderr)
	}
	calls, err := os.ReadFile(log)
	if err != nil {
		t.Fatal(err)
	}
	if string(calls) != "npm\n" {
		t.Fatalf("commands run = %q, want npm only", calls)
	}
	if len(*roots) != 1 {
		t.Fatalf("OpenCode update ran %d times, want once before npm", len(*roots))
	}
}

func TestUpgradeFlakeFailurePropagatesWithoutActivation(t *testing.T) {
	dir := t.TempDir()
	log := filepath.Join(dir, "calls")
	for name, script := range map[string]string{
		"npm": "echo npm >> \"$CALL_LOG\"\nexit 0\n",
		"nix": "echo nix >> \"$CALL_LOG\"\nexit 7\n",
	} {
		if err := os.WriteFile(filepath.Join(dir, name), []byte("#!/bin/sh\n"+script), 0755); err != nil {
			t.Fatal(err)
		}
	}
	t.Setenv("PATH", dir)
	t.Setenv("CALL_LOG", log)
	stubOpenCodeRelease(t, nil)
	if got := Run(Steps(Env{FlakePath: "/repo"}, "upgrade"), ""); got != 7 {
		t.Fatalf("Run = %d, want flake update exit 7", got)
	}
	calls, err := os.ReadFile(log)
	if err != nil {
		t.Fatal(err)
	}
	if string(calls) != "npm\nnpm\nnix\n" {
		t.Fatalf("commands run = %q, want only lock and flake updates", calls)
	}
}

func runSeqCases(t *testing.T, cases []seqCase) {
	t.Helper()
	for _, tc := range cases {
		assertSequence(t, Steps(tc.env, tc.command), tc.want)
	}
}

func assertSequence(t *testing.T, got, want []Step) {
	t.Helper()
	gotN := wantNames(got)
	wantN := wantNames(want)
	if len(got) != len(want) {
		t.Fatalf("step count %d != %d\ngot:\n  %s\nwant:\n  %s",
			len(got), len(want), indent(gotN), indent(wantN))
	}
	for i := range want {
		g, w := got[i], want[i]
		if g.Kind != w.Kind || g.Echo != w.Echo || g.ExitCode != w.ExitCode ||
			joinArgs(g.Args) != joinArgs(w.Args) || g.ThroughNom != w.ThroughNom || g.Dir != w.Dir {
			t.Fatalf("step %d differs\ngot:  %s\nwant: %s", i, gotN[i], wantN[i])
		}
	}
}

func indent(names []string) string {
	s := ""
	for _, n := range names {
		s += "\n  " + n
	}
	return s
}

func echo(s string) Step     { return Step{Kind: KindEcho, Echo: s} }
func ex(args ...string) Step { return execStep(args, false) }
func exNom(args ...string) Step {
	return execStep(args, true)
}
func guard(args ...string) Step {
	fail := args[len(args)-1]
	return Step{Kind: KindExec, Args: args[:len(args)-1],
		FailLines: []string{"", fail}}
}
func guardNom(args ...string) Step {
	fail := args[len(args)-1]
	return Step{Kind: KindExec, Args: args[:len(args)-1], ThroughNom: true,
		FailLines: []string{"", fail}}
}
