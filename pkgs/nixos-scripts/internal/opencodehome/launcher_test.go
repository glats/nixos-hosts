package opencodehome

import (
	"errors"
	"io"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestLaunchTargetAndProxyBehavior(t *testing.T) {
	tests := []struct {
		name       string
		target     string
		probeErr   error
		wantTarget string
		wantProxy  bool
	}{
		{name: "v1 default", wantTarget: "opencode", wantProxy: true},
		{name: "v2 listener up", target: "/nix/store/opencode2", wantTarget: "/nix/store/opencode2", wantProxy: true},
		{name: "v2 listener down", target: "/nix/store/opencode2", probeErr: errors.New("refused"), wantTarget: "/nix/store/opencode2"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			env := []string{"PATH=/bin", "NO_PROXY=example.test", "XDG_CONFIG_HOME=/isolated/config"}
			if tt.target != "" {
				env = append(env, "OPENCODE_HOME_BINARY="+tt.target)
			}
			var gotTarget string
			var gotArgs, gotEnv []string
			probe := func(network, address string, timeout time.Duration) (net.Conn, error) {
				if network != "tcp" || address != proxyAddress || timeout != time.Second {
					t.Fatalf("probe = %q %q %v", network, address, timeout)
				}
				if tt.probeErr != nil {
					return nil, tt.probeErr
				}
				a, b := net.Pipe()
				b.Close()
				return a, nil
			}
			exec := func(target string, args, childEnv []string) error {
				gotTarget, gotArgs, gotEnv = target, args, childEnv
				return nil
			}
			var notice strings.Builder
			if err := launch([]string{"", "space arg", "--option"}, env, probe, exec, &notice); err != nil {
				t.Fatal(err)
			}
			wantTarget := tt.wantTarget
			if tt.target == "" {
				wantTarget, _ = execLookPath("opencode")
			}
			if gotTarget != wantTarget {
				t.Fatalf("target = %q, want %q", gotTarget, wantTarget)
			}
			if strings.Join(gotArgs, "\x00") != strings.Join([]string{filepath.Base(wantTarget), "", "space arg", "--option"}, "\x00") {
				t.Fatalf("args = %#v", gotArgs)
			}
			if strings.Contains(strings.Join(gotEnv, "\n"), "OPENCODE_HOME_BINARY=") {
				t.Fatal("control variable leaked")
			}
			joined := strings.Join(gotEnv, "\n")
			if !strings.Contains(joined, "XDG_CONFIG_HOME=/isolated/config") {
				t.Fatal("isolation environment was not preserved")
			}
			if strings.Contains(joined, "HTTP_PROXY=http://127.0.0.1:2080") != tt.wantProxy {
				t.Fatalf("proxy state: %s", joined)
			}
			if tt.target != "" && tt.probeErr != nil && notice.Len() == 0 {
				t.Fatal("missing readiness notice")
			}
			if tt.wantProxy && tt.target != "" && !strings.Contains(joined, "NO_PROXY=example.test,localhost,127.0.0.1,::1") {
				t.Fatal("V2 loopback exclusions missing")
			}
			if !tt.wantProxy && strings.Contains(joined, "NO_PROXY=example.test,localhost,127.0.0.1,::1") {
				t.Fatal("V1/failure changed NO_PROXY")
			}
		})
	}
}

func execLookPath(name string) (string, error) { return exec.LookPath(name) }

func TestLaunchForwardsArgumentsToSelectedExecutable(t *testing.T) {
	dir := t.TempDir()
	target := filepath.Join(dir, "opencode2")
	capture := filepath.Join(dir, "args")
	script := "#!/bin/sh\nprintf '%s\\0' \"$@\" > \"$CAPTURE\"\nprintf '%s\\n' \"$XDG_CONFIG_HOME\" >> \"$CAPTURE\"\n"
	if err := os.WriteFile(target, []byte(script), 0755); err != nil {
		t.Fatal(err)
	}
	env := []string{"PATH=/bin", "CAPTURE=" + capture, "XDG_CONFIG_HOME=/isolated/config", targetEnv + "=" + target}
	run := func(path string, argv, childEnv []string) error {
		cmd := exec.Command(path, argv[1:]...)
		cmd.Env = childEnv
		return cmd.Run()
	}
	if err := launch([]string{"with spaces", "", "--literal"}, env,
		func(string, string, time.Duration) (net.Conn, error) { return nil, errors.New("listener down") }, run, io.Discard); err != nil {
		t.Fatal(err)
	}
	got, err := os.ReadFile(capture)
	if err != nil {
		t.Fatal(err)
	}
	want := "with spaces\x00\x00--literal\x00/isolated/config\n"
	if string(got) != want {
		t.Fatalf("recorder captured %q, want %q", got, want)
	}
}

func TestInvalidTargetDoesNotExecute(t *testing.T) {
	for _, target := range []string{"", "relative/opencode"} {
		env := os.Environ()
		env = append(env, "OPENCODE_HOME_BINARY="+target)
		called := false
		err := launch(nil, env, func(string, string, time.Duration) (net.Conn, error) { return nil, errors.New("unused") }, func(string, []string, []string) error { called = true; return nil }, io.Discard)
		if err == nil {
			t.Fatalf("invalid target %q accepted", target)
		}
		if called {
			t.Fatal("executed invalid target")
		}
	}
}
