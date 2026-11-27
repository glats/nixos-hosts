package main

import (
	"errors"
	"reflect"
	"strings"
	"testing"
	"time"

	"github.com/glats/nixos-scripts/internal/nixbuild"
	"github.com/glats/nixos-scripts/internal/nixcache"
)

type recordingRunner struct {
	argvs [][]string
	err   error
}

func (r *recordingRunner) Run(argv []string) error {
	r.argvs = append(r.argvs, argv)
	return r.err
}

type fakeRelay struct {
	upNow       bool
	ensureOK    bool
	ensureCalls int
	stops       int
}

func (f *fakeRelay) Up() bool { return f.upNow }

func (f *fakeRelay) EnsureUp() bool {
	f.ensureCalls++
	return f.ensureOK
}

func (f *fakeRelay) Stop() { f.stops++ }

func probeAlways(ok bool) func(string, time.Duration) bool {
	return func(string, time.Duration) bool { return ok }
}

var pushArgv = []string{"nix", "copy", "--no-check-sigs", "--to", "ssh-ng://glats@thinkcentre", "/run/current-system"}

var relayPushArgv = []string{"nix", "copy", "--no-check-sigs", "--to", nixcache.RelayPushTo, "/run/current-system"}

func TestMaybePush(t *testing.T) {
	cases := []struct {
		name     string
		env      nixbuild.Env
		command  string
		code     int
		pushEnv  string
		want     [][]string
		wantWarn int
	}{
		{
			name:    "darwin switch push",
			env:     nixbuild.Env{Darwin: true},
			command: "switch",
			code:    0,
			want:    [][]string{pushArgv},
		},
		{
			name:    "darwin upgrade does not push",
			env:     nixbuild.Env{Darwin: true},
			command: "upgrade",
			code:    0,
		},
		{
			name:    "darwin safe push",
			env:     nixbuild.Env{Darwin: true},
			command: "safe",
			code:    0,
			want:    [][]string{pushArgv},
		},
		{
			name:    "linux switch skip",
			env:     nixbuild.Env{Darwin: false},
			command: "switch",
			code:    0,
		},
		{
			name:    "darwin dry skip",
			env:     nixbuild.Env{Darwin: true},
			command: "dry",
			code:    0,
		},
		{
			name:    "darwin check skip",
			env:     nixbuild.Env{Darwin: true},
			command: "check",
			code:    0,
		},
		{
			name:    "darwin build skip",
			env:     nixbuild.Env{Darwin: true},
			command: "build",
			code:    0,
		},
		{
			name:    "failed darwin switch skip",
			env:     nixbuild.Env{Darwin: true},
			command: "switch",
			code:    1,
		},
		{
			name:    "opted-out darwin switch skip",
			env:     nixbuild.Env{Darwin: true},
			command: "switch",
			code:    0,
			pushEnv: "0",
		},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			runner := &recordingRunner{}
			var warns []string
			getenv := func(key string) string {
				if key == nixcache.PushOptOutEnv {
					return tc.pushEnv
				}
				return ""
			}
			maybePush(tc.env, tc.command, tc.code, getenv, runner,
				func(msg string) { warns = append(warns, msg) },
				probeAlways(true), &fakeRelay{ensureOK: true})
			if !reflect.DeepEqual(runner.argvs, tc.want) {
				t.Fatalf("push argvs = %v, want %v", runner.argvs, tc.want)
			}
			if len(warns) != tc.wantWarn {
				t.Errorf("warnings = %v, want %d", warns, tc.wantWarn)
			}
		})
	}
}

func TestMaybePushFailureWarnsAndKeepsExitCode(t *testing.T) {
	runner := &recordingRunner{err: errors.New("nix copy failed")}
	var warns []string
	getenv := func(string) string { return "" }

	maybePush(nixbuild.Env{Darwin: true}, "switch", 0, getenv, runner,
		func(msg string) { warns = append(warns, msg) },
		probeAlways(true), &fakeRelay{ensureOK: true})

	if len(runner.argvs) != 1 || !reflect.DeepEqual(runner.argvs[0], pushArgv) {
		t.Fatalf("push argvs = %v, want exactly one %v", runner.argvs, pushArgv)
	}
	if len(warns) != 1 {
		t.Fatalf("warnings = %v, want exactly one warning about the failed copy", warns)
	}
	if !strings.Contains(warns[0], "push failed (best-effort") {
		t.Errorf("warning %q should report the failure as best-effort", warns[0])
	}
}

func TestMaybePushOffLanUsesRelayAndStopsIt(t *testing.T) {
	runner := &recordingRunner{}
	relay := &fakeRelay{ensureOK: true}

	maybePush(nixbuild.Env{Darwin: true}, "switch", 0, func(string) string { return "" }, runner,
		func(string) {}, probeAlways(false), relay)

	if !reflect.DeepEqual(runner.argvs, [][]string{relayPushArgv}) {
		t.Fatalf("push argvs = %v, want %v", runner.argvs, relayPushArgv)
	}
	if relay.ensureCalls != 1 {
		t.Fatalf("relay ensureUp calls = %d, want 1", relay.ensureCalls)
	}
	if relay.stops != 1 {
		t.Fatalf("relay stops = %d, want 1: a tunnel the hook started must not stay running", relay.stops)
	}
}

func TestMaybePushOffLanKeepsAlreadyRunningRelay(t *testing.T) {
	runner := &recordingRunner{}
	relay := &fakeRelay{upNow: true, ensureOK: true}

	maybePush(nixbuild.Env{Darwin: true}, "switch", 0, func(string) string { return "" }, runner,
		func(string) {}, probeAlways(false), relay)

	if !reflect.DeepEqual(runner.argvs, [][]string{relayPushArgv}) {
		t.Fatalf("push argvs = %v, want %v", runner.argvs, relayPushArgv)
	}
	if relay.ensureCalls != 0 {
		t.Fatalf("relay ensureUp calls = %d, want 0: tunnel was already running", relay.ensureCalls)
	}
	if relay.stops != 0 {
		t.Fatalf("relay stops = %d, want 0: never stop a tunnel the user started", relay.stops)
	}
}

func TestMaybePushOffLanRelayFailsSkipsPushWithWarning(t *testing.T) {
	runner := &recordingRunner{}
	var warns []string
	relay := &fakeRelay{ensureOK: false}

	maybePush(nixbuild.Env{Darwin: true}, "switch", 0, func(string) string { return "" }, runner,
		func(msg string) { warns = append(warns, msg) }, probeAlways(false), relay)

	if len(runner.argvs) != 0 {
		t.Fatalf("push argvs = %v, want none", runner.argvs)
	}
	if len(warns) != 1 || !strings.Contains(warns[0], "relay") {
		t.Fatalf("warnings = %v, want one relay failure warning", warns)
	}
}

func TestMaybePushDestinationOverrideWins(t *testing.T) {
	runner := &recordingRunner{}
	relay := &fakeRelay{ensureOK: true}
	getenv := func(key string) string {
		if key == nixcache.PushToEnv {
			return nixcache.RelayPushTo
		}
		return ""
	}

	maybePush(nixbuild.Env{Darwin: true}, "switch", 0, getenv, runner,
		func(string) {}, probeAlways(false), relay)

	if !reflect.DeepEqual(runner.argvs, [][]string{relayPushArgv}) {
		t.Fatalf("push argvs = %v, want %v", runner.argvs, relayPushArgv)
	}
	if relay.ensureCalls != 0 || relay.stops != 0 {
		t.Fatalf("relay touched with an explicit override: ensure=%d stops=%d", relay.ensureCalls, relay.stops)
	}
}

func TestLinuxCheckStepsUnchanged(t *testing.T) {
	env := nixbuild.Env{Darwin: false, Raw: true, FlakePath: "/etc/nixos"}
	got := nixbuild.Steps(env, "check")
	want := []nixbuild.Step{
		{Kind: nixbuild.KindEcho, Echo: "> Validating flake..."},
		{Kind: nixbuild.KindExec, Args: []string{"nix", "flake", "check"}},
	}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("linux check steps = %+v, want %+v", got, want)
	}
}

func TestUpgradeIsNotApplyingCommand(t *testing.T) {
	if applyingCommand("upgrade") {
		t.Fatal("upgrade must not trigger activation side effects")
	}
	if !applyingCommand("switch") {
		t.Fatal("switch must remain an applying command")
	}
}
