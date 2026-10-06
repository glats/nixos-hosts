package opencodehome

import (
	"fmt"
	"io"
	"net"
	"os"
	"path/filepath"
	"strings"
	"syscall"
	"time"
)

const (
	proxyAddress = "127.0.0.1:2080"
	targetEnv    = "OPENCODE_HOME_BINARY"
)

type dialFunc func(string, string, time.Duration) (net.Conn, error)
type execFunc func(string, []string, []string) error

func launch(args, env []string, dial dialFunc, run execFunc, stderr io.Writer) error {
	target, selected := "opencode2", false
	for _, entry := range env {
		if key, value, ok := strings.Cut(entry, "="); ok && key == targetEnv {
			if value == "" || !filepath.IsAbs(value) {
				return fmt.Errorf("opencode-home: %s must be a nonempty absolute path", targetEnv)
			}
			target, selected = value, true
		}
	}
	if !selected {
		var err error
		target, err = lookPath(envValue(env, "PATH"), target)
		if err != nil {
			return err
		}
	}
	if !filepath.IsAbs(target) {
		return fmt.Errorf("opencode-home: resolved V2 executable must be an absolute path: %s", target)
	}
	info, err := os.Stat(target)
	if err != nil || !info.Mode().IsRegular() || info.Mode().Perm()&0111 == 0 {
		return fmt.Errorf("opencode-home: V2 executable is unavailable or not executable: %s", target)
	}
	if current, err := os.Executable(); err == nil {
		if resolvedTarget, targetErr := filepath.EvalSymlinks(target); targetErr == nil {
			if resolvedCurrent, currentErr := filepath.EvalSymlinks(current); currentErr == nil && resolvedTarget == resolvedCurrent {
				return fmt.Errorf("opencode-home: refusing recursive self target: %s", target)
			}
		}
	}
	if err := validateV2Environment(env); err != nil {
		return err
	}

	childEnv := make([]string, 0, len(env)+3)
	for _, entry := range env {
		if key, _, ok := strings.Cut(entry, "="); ok && key != targetEnv && !isProxyVariable(key) {
			childEnv = append(childEnv, entry)
		}
	}
	conn, err := dial("tcp", proxyAddress, time.Second)
	if err == nil {
		_ = conn.Close()
		childEnv = setEnv(childEnv, "HTTP_PROXY", "http://"+proxyAddress)
		childEnv = setEnv(childEnv, "HTTPS_PROXY", "http://"+proxyAddress)
		childEnv = setEnv(childEnv, "NO_PROXY", appendLoopback(envValue(env, "NO_PROXY")))
	} else {
		fmt.Fprintf(stderr, "opencode-home: %s not listening — launching without adding proxy env\n", proxyAddress)
	}

	argv := append([]string{filepath.Base(target)}, args...)
	if err := run(target, argv, childEnv); err != nil {
		return fmt.Errorf("opencode-home: %w", err)
	}
	return nil
}

func validateV2Environment(env []string) error {
	values := make(map[string]string, 9)
	for _, entry := range env {
		key, value, ok := strings.Cut(entry, "=")
		if !ok {
			continue
		}
		switch key {
		case "HOME", "XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_CACHE_HOME", "XDG_STATE_HOME", "OPENCODE_CONFIG_DIR", "OPENCODE_DB", "TMPDIR":
			if _, exists := values[key]; exists {
				return fmt.Errorf("opencode-home: duplicate %s in isolated V2 environment", key)
			}
			values[key] = value
		}
	}
	for _, key := range []string{"HOME", "XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_CACHE_HOME", "XDG_STATE_HOME", "OPENCODE_CONFIG_DIR", "OPENCODE_DB", "TMPDIR"} {
		if values[key] == "" || !filepath.IsAbs(values[key]) {
			return fmt.Errorf("opencode-home: isolated V2 environment requires absolute %s", key)
		}
		values[key] = filepath.Clean(values[key])
	}
	config := filepath.Join(values["HOME"], ".config", "opencode-v2")
	if values["XDG_CONFIG_HOME"] != config || values["OPENCODE_CONFIG_DIR"] != config {
		return fmt.Errorf("opencode-home: XDG_CONFIG_HOME and OPENCODE_CONFIG_DIR must share the isolated V2 config root")
	}
	if filepath.Base(values["XDG_DATA_HOME"]) != "data" {
		return fmt.Errorf("opencode-home: XDG_DATA_HOME must identify the V2 data directory")
	}
	runtimeRoot := filepath.Dir(values["XDG_DATA_HOME"])
	if values["XDG_CACHE_HOME"] != filepath.Join(runtimeRoot, "cache") ||
		values["XDG_STATE_HOME"] != filepath.Join(runtimeRoot, "state") ||
		values["TMPDIR"] != filepath.Join(runtimeRoot, "tmp") ||
		values["OPENCODE_DB"] != filepath.Join(runtimeRoot, "data", "opencode.db") {
		return fmt.Errorf("opencode-home: V2 data, cache, state, database, and temporary paths must share one runtime root")
	}
	legacyRoot := filepath.Join(values["HOME"], ".local", "share", "opencode")
	if runtimeRoot == legacyRoot || strings.HasPrefix(runtimeRoot, legacyRoot+string(filepath.Separator)) {
		return fmt.Errorf("opencode-home: V2 runtime paths collide with the legacy OpenCode data namespace")
	}
	return nil
}

func isProxyVariable(name string) bool {
	switch strings.ToUpper(name) {
	case "HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY":
		return true
	default:
		return false
	}
}

func lookPath(path, name string) (string, error) {
	for _, dir := range filepath.SplitList(path) {
		candidate := filepath.Join(dir, name)
		if info, err := os.Stat(candidate); err == nil && info.Mode().IsRegular() && info.Mode().Perm()&0111 != 0 {
			return candidate, nil
		}
	}
	return "", fmt.Errorf("opencode-home: %s not found in PATH", name)
}

func envValue(env []string, name string) string {
	for _, entry := range env {
		key, value, ok := strings.Cut(entry, "=")
		if ok && key == name {
			return value
		}
	}
	return ""
}

func setEnv(env []string, name, value string) []string {
	result := env[:0]
	for _, entry := range env {
		key, _, ok := strings.Cut(entry, "=")
		if !ok || key != name {
			result = append(result, entry)
		}
	}
	return append(result, name+"="+value)
}

func appendLoopback(existing string) string {
	if existing == "" {
		return "localhost,127.0.0.1,::1"
	}
	return existing + ",localhost,127.0.0.1,::1"
}

func Run() {
	err := launch(os.Args[1:], os.Environ(), net.DialTimeout, syscall.Exec, os.Stderr)
	if err != nil {
		fmt.Fprintln(os.Stderr, "ERROR:", err)
		os.Exit(127)
	}
}
