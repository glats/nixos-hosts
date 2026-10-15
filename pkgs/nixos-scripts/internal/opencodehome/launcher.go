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
	target, selected := "opencode", false
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
		return fmt.Errorf("opencode-home: resolved executable must be an absolute path: %s", target)
	}
	info, err := os.Stat(target)
	if err != nil || !info.Mode().IsRegular() || info.Mode().Perm()&0111 == 0 {
		return fmt.Errorf("opencode-home: executable is unavailable or not executable: %s", target)
	}
	if current, err := os.Executable(); err == nil {
		if resolvedTarget, targetErr := filepath.EvalSymlinks(target); targetErr == nil {
			if resolvedCurrent, currentErr := filepath.EvalSymlinks(current); currentErr == nil && resolvedTarget == resolvedCurrent {
				return fmt.Errorf("opencode-home: refusing recursive self target: %s", target)
			}
		}
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
