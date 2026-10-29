package main

import (
	"errors"
	"reflect"
	"strings"
	"testing"

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

var pushArgv = []string{"nix", "copy", "--no-check-sigs", "--to", "ssh-ng://glats@thinkcentre", "/run/current-system"}

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
				func(msg string) { warns = append(warns, msg) })
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
		func(msg string) { warns = append(warns, msg) })

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
