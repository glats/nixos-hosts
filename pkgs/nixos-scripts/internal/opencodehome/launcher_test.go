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
		{name: "isolated v2 default", wantTarget: "opencode2", wantProxy: true},
		{name: "v2 listener up", target: "/nix/store/opencode2", wantTarget: "/nix/store/opencode2", wantProxy: true},
		{name: "v2 listener down", target: "/nix/store/opencode2", probeErr: errors.New("refused"), wantTarget: "/nix/store/opencode2"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			target := filepath.Join(t.TempDir(), "opencode2")
			if err := os.WriteFile(target, []byte("#!/bin/sh\nexit 0\n"), 0755); err != nil {
				t.Fatal(err)
			}
			env := completeV2Environment(t, target)
			env = append(env, "NO_PROXY=example.test", "HTTP_PROXY=http://inherited.invalid", "https_proxy=http://inherited.invalid", "ALL_PROXY=socks5://inherited.invalid")
			if tt.target != "" {
				tt.target, tt.wantTarget = target, target
				env = append(env, targetEnv+"="+target)
			} else {
				env = append(env, "PATH="+filepath.Dir(target))
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
				wantTarget = target
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
			if envValue(gotEnv, "XDG_CONFIG_HOME") != envValue(env, "XDG_CONFIG_HOME") || envValue(gotEnv, "OPENCODE_DB") != envValue(env, "OPENCODE_DB") {
				t.Fatal("isolation environment was not preserved")
			}
			if strings.Contains(joined, "HTTP_PROXY=http://127.0.0.1:2080") != tt.wantProxy {
				t.Fatalf("proxy state: %s", joined)
			}
			if strings.Contains(joined, "inherited.invalid") {
				t.Fatalf("inherited proxy leaked: %s", joined)
			}
			if !tt.wantProxy && (strings.Contains(joined, "HTTP_PROXY=") || strings.Contains(joined, "HTTPS_PROXY=") || strings.Contains(joined, "ALL_PROXY=")) {
				t.Fatalf("proxy env not clean: %s", joined)
			}
			if tt.target != "" && tt.probeErr != nil && notice.Len() == 0 {
				t.Fatal("missing readiness notice")
			}
			if tt.wantProxy && !strings.Contains(joined, "NO_PROXY=example.test,localhost,127.0.0.1,::1") {
				t.Fatal("V2 loopback exclusions missing")
			}
			if !tt.wantProxy && strings.Contains(joined, "NO_PROXY=example.test,localhost,127.0.0.1,::1") {
				t.Fatal("listener-down launch changed NO_PROXY")
			}
		})
	}
}

func TestLaunchForwardsArgumentsToSelectedExecutable(t *testing.T) {
	dir := t.TempDir()
	target := filepath.Join(dir, "opencode2")
	capture := filepath.Join(dir, "args")
	script := "#!/bin/sh\nprintf '%s\\0' \"$@\" > \"$CAPTURE\"\nprintf '%s\\n' \"$XDG_CONFIG_HOME\" >> \"$CAPTURE\"\n"
	if err := os.WriteFile(target, []byte(script), 0755); err != nil {
		t.Fatal(err)
	}
	env := completeV2Environment(t, target)
	env = append(env, "PATH=/bin", "CAPTURE="+capture)
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
	want := "with spaces\x00\x00--literal\x00" + envValue(env, "XDG_CONFIG_HOME") + "\n"
	if string(got) != want {
		t.Fatalf("recorder captured %q, want %q", got, want)
	}
}

func TestInvalidTargetDoesNotExecute(t *testing.T) {
	for _, target := range []string{"", "relative/opencode", "/nix/store/opencode-home"} {
		env := []string{"PATH=/bin", "XDG_CONFIG_HOME=/isolated/opencode-v2", "OPENCODE_CONFIG_DIR=/isolated/opencode-v2", "OPENCODE_HOME_BINARY=" + target}
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

func TestUnavailableOrNonExecutableTargetDoesNotProbeOrExecute(t *testing.T) {
	for _, target := range []string{"/missing/opencode2", "/etc/hosts"} {
		t.Run(target, func(t *testing.T) {
			called := false
			env := completeV2Environment(t, target)
			env = append(env, targetEnv+"="+target)
			err := launch(nil, env, func(string, string, time.Duration) (net.Conn, error) {
				called = true
				return nil, errors.New("unexpected probe")
			}, func(string, []string, []string) error { t.Fatal("unexpected execution"); return nil }, io.Discard)
			if err == nil || called {
				t.Fatalf("err=%v probe=%v", err, called)
			}
		})
	}
}

func TestSelfTargetIsRejectedBeforeProbe(t *testing.T) {
	target, err := os.Executable()
	if err != nil {
		t.Fatal(err)
	}
	probed := false
	env := completeV2Environment(t, target)
	env = append(env, targetEnv+"="+target)
	err = launch(nil, env, func(string, string, time.Duration) (net.Conn, error) {
		probed = true
		return nil, errors.New("unexpected probe")
	}, func(string, []string, []string) error { t.Fatal("self target executed"); return nil }, io.Discard)
	if err == nil || probed {
		t.Fatalf("err=%v probed=%v", err, probed)
	}
}

func completeV2Environment(t *testing.T, target string) []string {
	t.Helper()
	home := t.TempDir()
	config := filepath.Join(home, ".config", "opencode-v2")
	runtime := filepath.Join(home, ".local", "opencode-v2")
	data := filepath.Join(runtime, "data")
	return []string{
		"HOME=" + home,
		"XDG_CONFIG_HOME=" + config,
		"XDG_DATA_HOME=" + data,
		"XDG_CACHE_HOME=" + filepath.Join(runtime, "cache"),
		"XDG_STATE_HOME=" + filepath.Join(runtime, "state"),
		"OPENCODE_CONFIG_DIR=" + config,
		"OPENCODE_DB=" + filepath.Join(data, "opencode.db"),
		"TMPDIR=" + filepath.Join(runtime, "tmp"),
		"OPENCODE_DISABLE_PROJECT_CONFIG=1",
		targetEnv + "=" + target,
	}
}

func TestIncompleteOrCollidingV2EnvironmentIsRejectedBeforeProbe(t *testing.T) {
	for _, missing := range []string{"XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_CACHE_HOME", "XDG_STATE_HOME", "OPENCODE_CONFIG_DIR", "OPENCODE_DB", "TMPDIR"} {
		t.Run("missing-"+missing, func(t *testing.T) {
			target := executableFixture(t)
			env := removeEnvironmentKey(completeV2Environment(t, target), missing)
			assertRejectedBeforeProbe(t, env)
		})
	}
	for _, key := range []string{"XDG_DATA_HOME", "XDG_CACHE_HOME", "XDG_STATE_HOME", "OPENCODE_DB", "TMPDIR", "OPENCODE_CONFIG_DIR"} {
		t.Run("mismatched-"+key, func(t *testing.T) {
			target := executableFixture(t)
			env := completeV2Environment(t, target)
			env = replaceEnvironmentKey(env, key, key+"=/legacy/opencode")
			assertRejectedBeforeProbe(t, env)
		})
	}
	t.Run("legacy-config-root", func(t *testing.T) {
		target := executableFixture(t)
		env := completeV2Environment(t, target)
		home := envValue(env, "HOME")
		env = replaceEnvironmentKey(env, "XDG_CONFIG_HOME", "XDG_CONFIG_HOME="+filepath.Join(home, ".config", "opencode"))
		env = replaceEnvironmentKey(env, "OPENCODE_CONFIG_DIR", "OPENCODE_CONFIG_DIR="+filepath.Join(home, ".config", "opencode"))
		assertRejectedBeforeProbe(t, env)
	})
	t.Run("legacy-runtime-root", func(t *testing.T) {
		target := executableFixture(t)
		env := completeV2Environment(t, target)
		home := envValue(env, "HOME")
		legacyData := filepath.Join(home, ".local", "share", "opencode")
		env = replaceEnvironmentKey(env, "XDG_DATA_HOME", "XDG_DATA_HOME="+filepath.Join(legacyData, "data"))
		env = replaceEnvironmentKey(env, "XDG_CACHE_HOME", "XDG_CACHE_HOME="+filepath.Join(legacyData, "cache"))
		env = replaceEnvironmentKey(env, "XDG_STATE_HOME", "XDG_STATE_HOME="+filepath.Join(legacyData, "state"))
		env = replaceEnvironmentKey(env, "OPENCODE_DB", "OPENCODE_DB="+filepath.Join(legacyData, "data", "opencode.db"))
		env = replaceEnvironmentKey(env, "TMPDIR", "TMPDIR="+filepath.Join(legacyData, "tmp"))
		assertRejectedBeforeProbe(t, env)
	})
}

func TestCustomV2RuntimeAndExplicitProjectConfigArePreserved(t *testing.T) {
	target := executableFixture(t)
	env := completeV2Environment(t, target)
	custom := filepath.Join(t.TempDir(), "custom-runtime")
	data := filepath.Join(custom, "data")
	env = replaceEnvironmentKey(env, "XDG_DATA_HOME", "XDG_DATA_HOME="+data)
	env = replaceEnvironmentKey(env, "XDG_CACHE_HOME", "XDG_CACHE_HOME="+filepath.Join(custom, "cache"))
	env = replaceEnvironmentKey(env, "XDG_STATE_HOME", "XDG_STATE_HOME="+filepath.Join(custom, "state"))
	env = replaceEnvironmentKey(env, "OPENCODE_DB", "OPENCODE_DB="+filepath.Join(data, "opencode.db"))
	env = replaceEnvironmentKey(env, "TMPDIR", "TMPDIR="+filepath.Join(custom, "tmp"))
	env = removeEnvironmentKey(env, "OPENCODE_DISABLE_PROJECT_CONFIG")
	called := false
	err := launch(nil, env, func(string, string, time.Duration) (net.Conn, error) { return nil, errors.New("listener down") }, func(_ string, _ []string, childEnv []string) error {
		called = true
		for _, key := range []string{"XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_CACHE_HOME", "XDG_STATE_HOME", "OPENCODE_CONFIG_DIR", "OPENCODE_DB", "TMPDIR"} {
			if envValue(childEnv, key) != envValue(env, key) {
				t.Fatalf("%s changed: %q", key, envValue(childEnv, key))
			}
		}
		if envValue(childEnv, "OPENCODE_DISABLE_PROJECT_CONFIG") != "" {
			t.Fatal("explicit project-config opt-in was disabled")
		}
		return nil
	}, io.Discard)
	if err != nil || !called {
		t.Fatalf("custom/project-config launch: called=%v err=%v", called, err)
	}
}

func executableFixture(t *testing.T) string {
	t.Helper()
	target := filepath.Join(t.TempDir(), "opencode2")
	if err := os.WriteFile(target, []byte("#!/bin/sh\nexit 0\n"), 0o755); err != nil {
		t.Fatal(err)
	}
	return target
}

func assertRejectedBeforeProbe(t *testing.T, env []string) {
	t.Helper()
	probed, executed := false, false
	err := launch(nil, env, func(string, string, time.Duration) (net.Conn, error) {
		probed = true
		return nil, errors.New("unexpected probe")
	}, func(string, []string, []string) error { executed = true; return nil }, io.Discard)
	if err == nil || probed || executed {
		t.Fatalf("err=%v probed=%v executed=%v", err, probed, executed)
	}
}

func replaceEnvironmentKey(env []string, key, replacement string) []string {
	result := removeEnvironmentKey(env, key)
	return append(result, replacement)
}

func removeEnvironmentKey(env []string, key string) []string {
	result := make([]string, 0, len(env))
	for _, entry := range env {
		name, _, ok := strings.Cut(entry, "=")
		if !ok || name != key {
			result = append(result, entry)
		}
	}
	return result
}
