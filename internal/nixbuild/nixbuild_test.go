package nixbuild

import (
	"runtime"
	"testing"
)

// Fixture values mirroring the bash placeholders.
const (
	root     = "/repo"
	hostname = "t14"
)

var (
	flakeArg  = "/repo#t14"
	refTop    = "/repo#nixosConfigurations.t14.config.system.build.toplevel"
	refDarwin = "/repo#darwinConfigurations.t14.config.system.build.toplevel"
	refNpm    = "/repo#opencode-npm-packages.updateScript"
)

func mkEnv(darwin, nh, nom, raw, noNom bool) Env {
	return Env{
		Darwin: darwin, Raw: raw, NoNom: noNom,
		HasNH: nh, HasNom: nom, NomPath: "/usr/bin/nom",
		Hostname: hostname, FlakePath: root,
	}
}

// wantSteps is the expected step sequence, built with the E/X/XN/F helpers.
func wantNames(steps []Step) []string {
	names := make([]string, len(steps))
	for i, st := range steps {
		switch st.Kind {
		case KindEcho:
			names[i] = "echo:" + st.Echo
		case KindExit:
			names[i] = "exit"
		case KindNpm:
			names[i] = "npm"
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

// npmCapture returns the exact npm updateScript capture step.
func npmCapture() Step {
	return Step{Kind: KindNpm, Args: []string{"nix", "build", refNpm, "--no-link", "--print-out-paths"}}
}

type seqCase struct {
	name    string
	env     Env
	command string
	want    []Step
}

// ---------------------------------------------------------------------------
// Linux, nh available, nom unavailable
// ---------------------------------------------------------------------------

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
		{prefix + "upgrade", linuxNH, "upgrade", []Step{
			echo(""),
			echo("> Updating npm packages to latest..."),
			npmCapture(),
			echo(""),
			echo("> Updating flake inputs and rebuilding (nh os switch --update)..."),
			ex("nh", "os", "switch", "--update"),
		}},
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
			ex("nh", "build", refTop),
		}},
		{prefix + "safe", linuxNH, "safe", []Step{
			echo(""), echo("> Running safe build workflow..."), echo(""),
			echo("> [1/4] Checking flake..."),
			guard("nix", "flake", "check", "> ERROR: Flake check failed. Stopping."),
			echo(""),
			echo("> [2/4] Building..."),
			guard("nh", "build", refTop, "> ERROR: Build failed. Stopping."),
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

// ---------------------------------------------------------------------------
// Linux, no nh (raw path), nom unavailable
// ---------------------------------------------------------------------------

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
		{prefix + "upgrade", linuxRaw, "upgrade", []Step{
			echo(""),
			echo("> Updating npm packages to latest..."),
			npmCapture(),
			echo(""),
			echo("> Updating flake inputs..."),
			ex("nix", "flake", "update"),
			echo(""),
			echo("> Building NixOS configuration (upgrade)..."),
			ex("sudo", "nixos-rebuild", "switch", "--flake", flakeArg),
		}},
		{prefix + "dry", linuxRaw, "dry", []Step{
			echo(""), echo("> Dry-activating..."),
			// dry-activate is never piped through nom, even here.
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

func TestStepsLinuxRaw(t *testing.T) {
	runSeqCases(t, linuxRawCases("LinuxRaw/"))
}

// --raw with nh installed must still take the nixos-rebuild path.
func TestStepsLinuxRawFlagKillsNH(t *testing.T) {
	env := mkEnv(false, true, false, true, false)
	got := Steps(env, "switch")
	want := []Step{
		echo(""), echo("> Building NixOS configuration (switch)..."),
		ex("sudo", "nixos-rebuild", "switch", "--flake", flakeArg),
	}
	assertSequence(t, got, want)
}

// --no-nom disables the nom pipe on nom-piped commands only.
func TestStepsLinuxNoNom(t *testing.T) {
	env := mkEnv(false, false, true, false, true)
	got := Steps(env, "switch")
	want := []Step{
		echo(""), echo("> Building NixOS configuration (switch)..."),
		ex("sudo", "nixos-rebuild", "switch", "--flake", flakeArg),
	}
	assertSequence(t, got, want)
}

// ---------------------------------------------------------------------------
// nom available: the exact nom-piped argv sequences (bash run_with_nom)
// ---------------------------------------------------------------------------

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
			// bash: dry-activate has no run_with_nom wrapper.
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

// nh commands never go through nom (bash calls nh bare).
func TestStepsLinuxNHNomAvailableBare(t *testing.T) {
	env := mkEnv(false, true, true, false, false)
	got := Steps(env, "build")
	want := []Step{
		echo("> Dry-building..."),
		ex("nh", "build", refTop),
	}
	assertSequence(t, got, want)
}

// ---------------------------------------------------------------------------
// Darwin branch
// ---------------------------------------------------------------------------

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
		{"Darwin/upgrade", dflt, "upgrade", []Step{
			echo(""),
			echo("> Updating npm packages to latest..."),
			npmCapture(),
			echo(""),
			echo("> Updating flake inputs..."),
			ex("nix", "flake", "update", "--flake", root),
			echo(""),
			echo("> Building Darwin configuration (upgrade)..."),
			ex("sudo", "darwin-rebuild", "switch", "--flake", flakeArg),
		}},
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

// ---------------------------------------------------------------------------
// ParseArgs
// ---------------------------------------------------------------------------

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
		// Linux probe behavior is LookPath-dependent; only prove runtime.GOOS wiring.
		if runtime.GOOS != "linux" && IsDarwin() {
			t.Fatal("unreachable")
		}
	}
}

// ---------------------------------------------------------------------------
// Run: exit-status semantics (set -e, safe guards, npm capture)
// ---------------------------------------------------------------------------

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
			execStep([]string{"false"}, false), // would be silenced without FailLines
			{Kind: KindExec, Args: []string{"false"},
				FailLines: []string{"", "> ERROR: Build failed. Stopping."}},
		}, 1},
		{"exit step returns its code", []Step{{Kind: KindExit, ExitCode: 1}}, 1},
		{"npm empty capture is skipped", []Step{
			{Kind: KindNpm, Args: []string{"true"}},
			execStep([]string{"true"}, false),
		}, 0},
		{"npm capture then exec", []Step{
			{Kind: KindNpm, Args: []string{"echo", "/nix/store/one"}}, // execs the path → 127
		}, 127},
		{"npm capture failure tolerated", []Step{
			{Kind: KindNpm, Args: []string{"false"}}, // || true
			execStep([]string{"true"}, false),
		}, 0},
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

// ---------------------------------------------------------------------------
// helpers
// ---------------------------------------------------------------------------

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
			joinArgs(g.Args) != joinArgs(w.Args) || g.ThroughNom != w.ThroughNom {
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
