package sshrelay

import (
	"errors"
	"reflect"
	"testing"
	"time"

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

func TestUpDialsRelayListener(t *testing.T) {
	var dialed string
	ctl := NewCtlWith("/bin/relayctl", &recordingRunner{}, func(addr string, _ time.Duration) bool {
		dialed = addr
		return true
	}, func(time.Duration) {})
	if !ctl.Up() {
		t.Fatal("Up() = false, want true")
	}
	if dialed != nixcache.RelayListenerAddr {
		t.Fatalf("dialed %q, want %q", dialed, nixcache.RelayListenerAddr)
	}
}

func TestEnsureUpStartsRelayAndWaitsForListener(t *testing.T) {
	run := &recordingRunner{}
	dials := 0
	sleeps := 0
	ctl := NewCtlWith("/bin/relayctl", run, func(string, time.Duration) bool {
		dials++
		return dials >= 3
	}, func(time.Duration) { sleeps++ })
	if !ctl.EnsureUp() {
		t.Fatal("EnsureUp() = false, want true")
	}
	if want := [][]string{{"/bin/relayctl", "on"}}; !reflect.DeepEqual(run.argvs, want) {
		t.Fatalf("argvs = %v, want %v", run.argvs, want)
	}
	if sleeps != 2 {
		t.Fatalf("sleeps = %d, want 2", sleeps)
	}
}

func TestEnsureUpFailsWhenRelayctlFails(t *testing.T) {
	run := &recordingRunner{err: errors.New("boom")}
	ctl := NewCtlWith("/bin/relayctl", run, func(string, time.Duration) bool {
		t.Fatal("must not dial when relayctl on failed")
		return false
	}, func(time.Duration) {})
	if ctl.EnsureUp() {
		t.Fatal("EnsureUp() = true, want false")
	}
}

func TestEnsureUpGivesUpWhenListenerNeverAppears(t *testing.T) {
	sleeps := 0
	ctl := NewCtlWith("/bin/relayctl", &recordingRunner{}, func(string, time.Duration) bool { return false },
		func(time.Duration) { sleeps++ })
	if ctl.EnsureUp() {
		t.Fatal("EnsureUp() = true, want false")
	}
	if sleeps != readyAttempts {
		t.Fatalf("sleeps = %d, want %d", sleeps, readyAttempts)
	}
}

func TestStopRunsRelayctlOff(t *testing.T) {
	run := &recordingRunner{}
	ctl := NewCtlWith("/bin/relayctl", run, nil, nil)
	ctl.Stop()
	if want := [][]string{{"/bin/relayctl", "off"}}; !reflect.DeepEqual(run.argvs, want) {
		t.Fatalf("argvs = %v, want %v", run.argvs, want)
	}
}
