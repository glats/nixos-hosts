package nixcache

import (
	"errors"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

type fakeRunner struct {
	argvs [][]string
	fail  func(argv []string) error
}

func (f *fakeRunner) Run(argv []string) error {
	f.argvs = append(f.argvs, argv)
	if f.fail != nil {
		return f.fail(argv)
	}
	return nil
}

func TestUsageTextDocumentsSubcommandsAndFlags(t *testing.T) {
	for _, want := range []string{
		"prewarm",
		"push",
		"help",
		"--flake",
		"--state-dir",
		"--max-load",
		"--to",
		"--strict",
		"NIX_CACHE_FLAKE",
		DefaultStateDir,
		DefaultPushTo,
		"/run/current-system",
	} {
		if !strings.Contains(UsageText, want) {
			t.Errorf("UsageText missing fragment %q", want)
		}
	}
}

func TestParseLoadavg(t *testing.T) {
	cases := []struct {
		name    string
		in      string
		want    float64
		wantErr bool
	}{
		{"typical proc content", "0.85 0.42 0.31 1/389 12345\n", 0.85, false},
		{"single field", "1.20", 1.20, false},
		{"missing", "  \n", 0, true},
		{"garbage", "abc 0.1", 0, true},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got, err := ParseLoadavg(tc.in)
			if tc.wantErr {
				if err == nil {
					t.Fatalf("ParseLoadavg(%q) = %v, want error", tc.in, got)
				}
				return
			}
			if err != nil {
				t.Fatalf("ParseLoadavg(%q): %v", tc.in, err)
			}
			if got != tc.want {
				t.Errorf("ParseLoadavg(%q) = %v, want %v", tc.in, got, tc.want)
			}
		})
	}
}

func TestResolveFlake(t *testing.T) {
	getenv := func(k string) string {
		if k == EnvFlake {
			return "github:glats/nixos"
		}
		return ""
	}
	if got := ResolveFlake("path:/repo", getenv); got != "path:/repo" {
		t.Errorf("flag value must win, got %q", got)
	}
	if got := ResolveFlake("", getenv); got != "github:glats/nixos" {
		t.Errorf("env default = %q", got)
	}
	if got := ResolveFlake("", func(string) string { return "" }); got != "" {
		t.Errorf("no flag and no env must be empty, got %q", got)
	}
}

func TestCloneTarget(t *testing.T) {
	cases := []struct {
		in         string
		wantURL    string
		wantBranch string
	}{
		{"github:glats/nixos", "https://github.com/glats/nixos", ""},
		{"github:glats/nixos-hosts/master", "https://github.com/glats/nixos-hosts", "master"},
		{"/etc/nixos", "/etc/nixos", ""},
		{"https://github.com/glats/nixos", "https://github.com/glats/nixos", ""},
		{"git+https://github.com/glats/nixos-hosts", "https://github.com/glats/nixos-hosts", ""},
		{"git+https://github.com/glats/nixos-hosts?ref=master", "https://github.com/glats/nixos-hosts", "master"},
		{"git+https://github.com/glats/nixos-hosts?ref=master&foo=bar", "https://github.com/glats/nixos-hosts", "master"},
	}
	for _, tc := range cases {
		gotURL, gotBranch := CloneTarget(tc.in)
		if gotURL != tc.wantURL || gotBranch != tc.wantBranch {
			t.Errorf("CloneTarget(%q) = (%q, %q), want (%q, %q)",
				tc.in, gotURL, gotBranch, tc.wantURL, tc.wantBranch)
		}
	}
}

func TestPrewarmGitFlakeRefCloneArgv(t *testing.T) {
	stateDir := filepath.Join(t.TempDir(), "state")
	nextDir := filepath.Join(stateDir, "next")
	opts := Options{
		Flake:    "git+https://github.com/glats/nixos-hosts?ref=master",
		StateDir: stateDir,
		MaxLoad:  1.0,
	}
	run := &fakeRunner{}
	if err := Prewarm(opts, 0.4, run, func(string) {}); err != nil {
		t.Fatalf("prewarm git+https flake: %v", err)
	}
	want := [][]string{
		{"git", "clone", "--branch", "master", "https://github.com/glats/nixos-hosts", nextDir},
		{"nix", "flake", "update", "--flake", nextDir},
	}
	got := run.argvs[len(CurrentSteps(opts)) : len(CurrentSteps(opts))+len(want)]
	if !reflect.DeepEqual(got, want) {
		t.Errorf("git flake ref clone argv mismatch:\n got %v\nwant %v", got, want)
	}
}

func TestCurrentSteps(t *testing.T) {
	opts := Options{Flake: "github:glats/nixos", StateDir: "/srv/nix-cache"}
	got := CurrentSteps(opts)
	ref := "github:glats/nixos"
	want := []Step{
		{
			Name: "nixos host rog",
			Args: []string{
				"nix", "build",
				"--out-link", "/srv/nix-cache/roots/current/nixos-rog",
				"--keep-going",
				ref + "#nixosConfigurations.rog.config.system.build.toplevel",
			},
			Fatal: true,
		},
		{
			Name: "nixos host t14",
			Args: []string{
				"nix", "build",
				"--out-link", "/srv/nix-cache/roots/current/nixos-t14",
				"--keep-going",
				ref + "#nixosConfigurations.t14.config.system.build.toplevel",
			},
			Fatal: true,
		},
		{
			Name: "nixos host thinkcentre",
			Args: []string{
				"nix", "build",
				"--out-link", "/srv/nix-cache/roots/current/nixos-thinkcentre",
				"--keep-going",
				ref + "#nixosConfigurations.thinkcentre.config.system.build.toplevel",
			},
			Fatal: true,
		},
		{
			Name: "home host rog",
			Args: []string{
				"nix", "build",
				"--out-link", "/srv/nix-cache/roots/current/home-rog",
				"--keep-going",
				ref + "#homeConfigurations.rog.activationPackage",
			},
			Fatal: true,
		},
		{
			Name: "home host t14",
			Args: []string{
				"nix", "build",
				"--out-link", "/srv/nix-cache/roots/current/home-t14",
				"--keep-going",
				ref + "#homeConfigurations.t14.activationPackage",
			},
			Fatal: true,
		},
		{
			Name: "home host thinkcentre",
			Args: []string{
				"nix", "build",
				"--out-link", "/srv/nix-cache/roots/current/home-thinkcentre",
				"--keep-going",
				ref + "#homeConfigurations.thinkcentre.activationPackage",
			},
			Fatal: true,
		},
		{
			Name: "darwin host macm5",
			Args: []string{
				"nix", "build",
				"--out-link", "/srv/nix-cache/roots/current/darwin-macm5",
				"--option", "max-jobs", "0",
				"--keep-going",
				ref + "#darwinConfigurations.macm5.config.system.build.toplevel",
			},
		},
		{
			Name: "home host macm5",
			Args: []string{
				"nix", "build",
				"--out-link", "/srv/nix-cache/roots/current/home-macm5",
				"--option", "max-jobs", "0",
				"--keep-going",
				ref + "#homeConfigurations.macm5.activationPackage",
			},
		},
	}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("CurrentSteps mismatch:\n got %v\nwant %v", got, want)
	}
	for _, st := range got {
		if st.Fatal && !strings.Contains(st.Args[3], "/current/") {
			t.Errorf("fatal step out-link outside current variant: %v", st.Args)
		}
	}
}

func TestNextSteps(t *testing.T) {
	opts := Options{Flake: "/etc/nixos", StateDir: "/srv/nix-cache"}
	got := NextSteps(opts)
	if len(got) != len(CurrentSteps(opts)) {
		t.Fatalf("NextSteps len = %d, want %d (current Linux outputs plus macm5 substitutes)", len(got), len(CurrentSteps(opts)))
	}
	for _, st := range got {
		if st.Fatal {
			t.Errorf("next step %q must not be fatal", st.Name)
		}
		if !strings.Contains(st.Args[3], filepath.Join("/srv/nix-cache", "roots", "next")+"/") {
			t.Errorf("next out-link wrong: %v", st.Args[3])
		}
	}
	wantRog := []string{
		"nix", "build",
		"--out-link", "/srv/nix-cache/roots/next/nixos-rog",
		"--keep-going",
		"/srv/nix-cache/next#nixosConfigurations.rog.config.system.build.toplevel",
	}
	if !reflect.DeepEqual(got[0].Args, wantRog) {
		t.Errorf("next rog argv mismatch:\n got %v\nwant %v", got[0].Args, wantRog)
	}
	for _, st := range got[len(got)-2:] {
		if len(st.Args) < 5 || st.Args[4] != "--option" || st.Args[6] != "0" {
			t.Errorf("macm5 next substitution must set max-jobs 0: %v", st.Args)
		}
	}
}

func TestPrewarmMissingFlake(t *testing.T) {
	run := &fakeRunner{}
	var warnings []string
	err := Prewarm(Options{StateDir: "/srv/x", MaxLoad: 1}, 0.5, run, func(m string) {
		warnings = append(warnings, m)
	})
	if err == nil {
		t.Fatal("missing flake must fail Prewarm")
	}
	if len(run.argvs) != 0 {
		t.Errorf("missing flake must not run commands, ran %v", run.argvs)
	}
	for _, want := range []string{"--flake", EnvFlake} {
		if !strings.Contains(err.Error(), want) {
			t.Errorf("error %q must mention %q", err.Error(), want)
		}
	}
}

func TestPrewarmLoadGuardSkips(t *testing.T) {
	run := &fakeRunner{}
	var warnings []string
	warn := func(m string) { warnings = append(warnings, m) }
	err := Prewarm(Options{Flake: "github:glats/nixos", StateDir: "/srv/x", MaxLoad: 1.0}, 1.5, run, warn)
	if err != nil {
		t.Fatalf("load guard must exit 0, got %v", err)
	}
	if len(run.argvs) != 0 {
		t.Errorf("skipped prewarm must not run commands, ran %v", run.argvs)
	}
	if len(warnings) != 1 || !strings.Contains(warnings[0], "skipped") {
		t.Errorf("skip must be logged, got %v", warnings)
	}

	same := &fakeRunner{}
	if err := Prewarm(Options{Flake: "github:glats/nixos", StateDir: "/srv/x", MaxLoad: 1.0}, 1.0, same, warn); err != nil {
		t.Fatalf("load equal to max must not skip: %v", err)
	}
	if len(same.argvs) == 0 {
		t.Error("load equal to max must build")
	}
}

func TestPrewarmRunsStepsAndResetsNextDir(t *testing.T) {
	stateDir := filepath.Join(t.TempDir(), "state")
	nextDir := filepath.Join(stateDir, "next")
	if err := os.MkdirAll(nextDir, 0o755); err != nil {
		t.Fatal(err)
	}
	stale := filepath.Join(nextDir, "stale.lock")
	if err := os.WriteFile(stale, []byte("old"), 0o644); err != nil {
		t.Fatal(err)
	}

	run := &fakeRunner{}
	opts := Options{Flake: "github:glats/nixos", StateDir: stateDir, MaxLoad: 1.0}
	var warnings []string
	if err := Prewarm(opts, 0.4, run, func(m string) { warnings = append(warnings, m) }); err != nil {
		t.Fatalf("prewarm happy path: %v", err)
	}
	if len(warnings) != 0 {
		t.Errorf("happy path must not warn, got %v", warnings)
	}

	var want [][]string
	for _, st := range CurrentSteps(opts) {
		want = append(want, st.Args)
	}
	want = append(want,
		[]string{"git", "clone", "https://github.com/glats/nixos", nextDir},
		[]string{"nix", "flake", "update", "--flake", nextDir},
	)
	for _, st := range NextSteps(opts) {
		want = append(want, st.Args)
	}
	if !reflect.DeepEqual(run.argvs, want) {
		t.Errorf("prewarm argv mismatch:\n got %v\nwant %v", run.argvs, want)
	}

	if _, err := os.Stat(stale); !os.IsNotExist(err) {
		t.Fatalf("stale next dir must be reset before clone (err=%v)", err)
	}
}

func TestPrewarmCurrentLinuxFailureFailsButKeepsGoing(t *testing.T) {
	stateDir := filepath.Join(t.TempDir(), "state")
	run := &fakeRunner{}
	run.fail = func(argv []string) error {
		if len(argv) > 5 && strings.Contains(argv[5], "nixosConfigurations.rog.") {
			return errors.New("rog build boom")
		}
		return nil
	}
	var warnings []string
	err := Prewarm(Options{Flake: "github:glats/nixos", StateDir: stateDir, MaxLoad: 1.0}, 0.4, run,
		func(m string) { warnings = append(warnings, m) })
	if err == nil {
		t.Fatal("failed current Linux output must make Prewarm fail")
	}
	if !strings.Contains(err.Error(), "rog") {
		t.Errorf("error must name the failed host, got %q", err.Error())
	}
	runCount := len(run.argvs)
	if got := len(CurrentSteps(Options{Flake: "github:glats/nixos", StateDir: stateDir})); runCount <= got {
		t.Errorf("keep-going expected more than %d rest-steps, ran %d", got, runCount)
	}
	if !warned(t, warnings, "/roots/current/nixos-rog") && !warned(t, warnings, "nixos host rog") {
		t.Errorf("failure must be warned, got %v", warnings)
	}
}

func TestPrewarmDarwinFailureIsBestEffort(t *testing.T) {
	stateDir := filepath.Join(t.TempDir(), "state")
	run := &fakeRunner{}
	run.fail = func(argv []string) error {
		if len(argv) > 3 && strings.Contains(argv[3], "darwin-macm5") {
			return errors.New("no mac substitute")
		}
		return nil
	}
	var warnings []string
	err := Prewarm(Options{Flake: "github:glats/nixos", StateDir: stateDir, MaxLoad: 1.0}, 0.4, run,
		func(m string) { warnings = append(warnings, m) })
	if err != nil {
		t.Fatalf("darwin failure must not fail Prewarm, got %v", err)
	}
	if len(warnings) == 0 {
		t.Error("darwin failure must be warned")
	}
	if len(run.argvs) != len(CurrentSteps(Options{Flake: "x", StateDir: stateDir}))+
		2+len(NextSteps(Options{Flake: "x", StateDir: stateDir})) {
		t.Errorf("all steps must still run after darwin failure, ran %v", run.argvs)
	}
}

func TestPrewarmNextVariantFailuresWarnOnly(t *testing.T) {
	stateDir := filepath.Join(t.TempDir(), "state")
	t.Run("clone fails", func(t *testing.T) {
		run := &fakeRunner{}
		run.fail = func(argv []string) error {
			if argv[0] == "git" {
				return errors.New("clone boom")
			}
			return nil
		}
		var warnings []string
		err := Prewarm(Options{Flake: "github:glats/nixos", StateDir: stateDir, MaxLoad: 1.0}, 0.4, run,
			func(m string) { warnings = append(warnings, m) })
		if err != nil {
			t.Fatalf("next clone failure must not fail Prewarm, got %v", err)
		}
		if !warned(t, warnings, "next variant skipped") {
			t.Errorf("skip must be warned, got %v", warnings)
		}
	})
	t.Run("update fails", func(t *testing.T) {
		run := &fakeRunner{}
		run.fail = func(argv []string) error {
			if argv[0] == "nix" && argv[1] == "flake" {
				return errors.New("update boom")
			}
			return nil
		}
		var warnings []string
		if err := Prewarm(Options{Flake: "github:glats/nixos", StateDir: stateDir, MaxLoad: 1.0}, 0.4, run,
			func(m string) { warnings = append(warnings, m) }); err != nil {
			t.Fatalf("next update failure must not fail Prewarm, got %v", err)
		}
		if !warned(t, warnings, "next variant skipped") {
			t.Errorf("skip must be warned, got %v", warnings)
		}
	})
	t.Run("next build fails", func(t *testing.T) {
		run := &fakeRunner{}
		run.fail = func(argv []string) error {
			if len(argv) > 4 && strings.Contains(argv[3], "/roots/next/") {
				return errors.New("next boom")
			}
			return nil
		}
		var warnings []string
		err := Prewarm(Options{Flake: "github:glats/nixos", StateDir: "/srv/x", MaxLoad: 1.0}, 0.4, run,
			func(m string) { warnings = append(warnings, m) })
		if err != nil {
			t.Fatalf("next build failures must not fail Prewarm, got %v", err)
		}
		if len(warnings) == 0 {
			t.Error("next build failures must be warned")
		}
	})
}

func TestPush(t *testing.T) {
	dest := "ssh-ng://glats@thinkcentre"

	t.Run("default path", func(t *testing.T) {
		run := &fakeRunner{}
		if err := Push(dest, nil, false, run, func(string) {}); err != nil {
			t.Fatalf("push: %v", err)
		}
		want := []string{"nix", "copy", "--to", dest, "/run/current-system"}
		if !reflect.DeepEqual(run.argvs[0], want) {
			t.Errorf("push argv mismatch:\n got %v\nwant %v", run.argvs[0], want)
		}
	})
	t.Run("given paths", func(t *testing.T) {
		run := &fakeRunner{}
		if err := Push(dest, []string{"/nix/store/a", "/nix/store/b"}, false, run, func(string) {}); err != nil {
			t.Fatalf("push: %v", err)
		}
		want := []string{"nix", "copy", "--to", dest, "/nix/store/a", "/nix/store/b"}
		if !reflect.DeepEqual(run.argvs[0], want) {
			t.Errorf("push argv mismatch:\n got %v\nwant %v", run.argvs[0], want)
		}
	})
	t.Run("best effort failure", func(t *testing.T) {
		run := &fakeRunner{fail: func([]string) error { return errors.New("copy boom") }}
		var warnings []string
		if err := Push(dest, nil, false, run, func(m string) { warnings = append(warnings, m) }); err != nil {
			t.Fatalf("best-effort push failure must exit 0, got %v", err)
		}
		if len(warnings) == 0 {
			t.Error("failed push must warn")
		}
	})
	t.Run("strict failure", func(t *testing.T) {
		run := &fakeRunner{fail: func([]string) error { return errors.New("copy boom") }}
		if err := Push(dest, nil, true, run, func(string) {}); err == nil {
			t.Fatal("strict push failure must fail")
		}
	})
	t.Run("empty destination", func(t *testing.T) {
		if err := Push("", nil, false, &fakeRunner{}, func(string) {}); err == nil {
			t.Fatal("empty --to must fail push")
		}
	})
}

func TestPrewarmUnsafeStateDir(t *testing.T) {
	for _, bad := range []string{"", "/"} {
		run := &fakeRunner{}
		err := Prewarm(Options{Flake: "github:glats/nixos", StateDir: bad, MaxLoad: 1.0}, 0.4, run,
			func(string) {})
		if err == nil {
			t.Errorf("state-dir %q must be rejected", bad)
		}
		if len(run.argvs) != 0 {
			t.Errorf("rejected state-dir must run nothing, ran %v", run.argvs)
		}
	}
}

func warned(t *testing.T, warnings []string, want string) bool {
	t.Helper()
	for _, w := range warnings {
		if strings.Contains(w, want) {
			return true
		}
	}
	return false
}
