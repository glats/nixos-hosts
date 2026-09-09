// Package sshtunnel — hermetic unit tests: localhost-only listener probing,
// pure string/argument assembly. No network beyond loopback, no ssh exec.
package sshtunnel

import (
	"fmt"
	"net"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestBuildSSHArgs(t *testing.T) {
	args := BuildSSHArgs("172.16.0.12", "glats", "/home/glats/.ssh/oneplus5", 3000, 3000)
	want := []string{
		"-i", "/home/glats/.ssh/oneplus5",
		"-N",
		"-L", "127.0.0.1:3000:172.16.0.12:3000",
		"glats@172.16.0.12",
	}
	if len(args) != len(want) {
		t.Fatalf("arg count = %d, want %d: %v", len(args), len(want), args)
	}
	for i, v := range want {
		if args[i] != v {
			t.Fatalf("args[%d] = %q, want %q (full: %v)", i, args[i], v, args)
		}
	}
}

func TestBuildSSHArgsPortsDiffer(t *testing.T) {
	// Forward target defaults to the same host string; ports are independent.
	args := BuildSSHArgs("10.0.0.5", "root", "k", 13001, 8443)
	wantForward := "127.0.0.1:13001:10.0.0.5:8443"
	found := false
	for _, a := range args {
		if a == wantForward {
			found = true
		}
	}
	if !found {
		t.Fatalf("forward arg %q missing from args: %v", wantForward, args)
	}
}

func TestPickFreePortRequestedFree(t *testing.T) {
	// A port just probed free must be returned unchanged with no fallback.
	l, err := net.Listen("tcp4", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("seed listener: %v", err)
	}
	free := l.Addr().(*net.TCPAddr).Port
	l.Close() // release so PickFreePort can claim it directly

	got, fellBack, err := PickFreePort(free)
	if err != nil {
		t.Fatalf("PickFreePort(%d): %v", free, err)
	}
	if fellBack {
		t.Fatalf("PickFreePort(%d) fell back to %d, wanted direct", free, got)
	}
	if got != free {
		t.Fatalf("PickFreePort(%d) = %d", free, got)
	}
}

func TestPickFreePortBusy(t *testing.T) {
	// Occupy an explicit genuine port, then the helper must fall back to
	// requested+FallbackPortStep and say so.
	l, err := net.Listen("tcp4", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("seed listener: %v", err)
	}
	defer l.Close()
	busy := l.Addr().(*net.TCPAddr).Port

	got, fellBack, err := PickFreePort(busy)
	if err != nil {
		t.Fatalf("PickFreePort(%d): %v", busy, err)
	}
	if !fellBack {
		t.Fatalf("PickFreePort(%d) did not fall back (got %d)", busy, got)
	}
	if got != busy+FallbackPortStep {
		t.Fatalf("fallback = %d, want %d", got, busy+FallbackPortStep)
	}
}

func TestPickFreePortBothBusy(t *testing.T) {
	// Occupy an explicit genuine port AND its fallback slot
	// (requested+FallbackPortStep), then the helper must refuse with a
	// clear error. The fallback slot is normally free; skip if not.
	l, err := net.Listen("tcp4", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("seed listener: %v", err)
	}
	busy := l.Addr().(*net.TCPAddr).Port
	fallback := busy + FallbackPortStep

	fb, err := net.Listen("tcp4", "127.0.0.1:"+fmt.Sprint(fallback))
	if err != nil {
		l.Close()
		t.Skipf("fallback slot %d unexpectedly busy: %v", fallback, err)
	}
	defer l.Close()
	defer fb.Close()

	_, _, err = PickFreePort(busy)
	if err == nil {
		t.Fatalf("PickFreePort(%d) with fallback also busy should error", busy)
	}
	if !strings.Contains(err.Error(), "unavailable") {
		t.Fatalf("error should mention unavailability, got: %v", err)
	}
}

func TestLocalURL(t *testing.T) {
	if got := LocalURL(13000); got != "http://127.0.0.1:13000/" {
		t.Fatalf("LocalURL(13000) = %q", got)
	}
}

func TestExpandHome(t *testing.T) {
	home, err := os.UserHomeDir()
	if err != nil {
		t.Fatalf("UserHomeDir: %v", err)
	}

	tilde, err := ExpandHome("~/.ssh/oneplus5")
	if err != nil {
		t.Fatalf("ExpandHome(~/.ssh/oneplus5): %v", err)
	}
	if want := filepath.Join(home, ".ssh/oneplus5"); tilde != want {
		t.Fatalf("ExpandHome tilde = %q, want %q", tilde, want)
	}

	bare, err := ExpandHome("~")
	if err != nil {
		t.Fatalf("ExpandHome(~): %v", err)
	}
	if bare != home {
		t.Fatalf("ExpandHome(~) = %q, want %q", bare, home)
	}

	abs := "/etc/ssh/host_key"
	passthrough, err := ExpandHome(abs)
	if err != nil {
		t.Fatalf("ExpandHome abs: %v", err)
	}
	if passthrough != abs {
		t.Fatalf("ExpandHome abs = %q, want %q", passthrough, abs)
	}

	rel := "keys/host_key"
	relOut, err := ExpandHome(rel)
	if err != nil {
		t.Fatalf("ExpandHome rel: %v", err)
	}
	if relOut != rel {
		t.Fatalf("ExpandHome rel = %q, want %q", relOut, rel)
	}
}
