package sshrelay

import (
	"os"
	"path/filepath"
	"time"

	"github.com/glats/nixos-scripts/internal/nixcache"
)

const (
	readyAttempts = 40
	readyInterval = 500 * time.Millisecond
)

// Ctl drives the user-level launchd relay agent through the sibling
// relayctl binary. Readiness is the local relay forward listener, not a
// status parse.
type Ctl struct {
	ctlPath string
	run     nixcache.Runner
	dial    func(string, time.Duration) bool
	sleep   func(time.Duration)
}

// NewCtl returns a Ctl using the relayctl binary next to the running
// executable, or nil when that binary is absent.
func NewCtl(run nixcache.Runner) *Ctl {
	exe, err := os.Executable()
	if err != nil {
		return nil
	}
	ctlPath := filepath.Join(filepath.Dir(exe), "relayctl")
	if info, err := os.Stat(ctlPath); err != nil || info.IsDir() {
		return nil
	}
	return NewCtlWith(ctlPath, run, nixcache.Reachable, time.Sleep)
}

// NewCtlWith builds a Ctl from explicit collaborators.
func NewCtlWith(ctlPath string, run nixcache.Runner, dial func(string, time.Duration) bool, sleep func(time.Duration)) *Ctl {
	return &Ctl{ctlPath: ctlPath, run: run, dial: dial, sleep: sleep}
}

// Up reports whether the local relay forward listener accepts connections.
func (t *Ctl) Up() bool {
	return t.dial(nixcache.RelayListenerAddr, time.Second)
}

// EnsureUp starts the relay and waits up to 20 s for the listener.
func (t *Ctl) EnsureUp() bool {
	if err := t.run.Run([]string{t.ctlPath, "on"}); err != nil {
		return false
	}
	for i := 0; i < readyAttempts; i++ {
		if t.Up() {
			return true
		}
		t.sleep(readyInterval)
	}
	return false
}

// Stop turns the relay off.
func (t *Ctl) Stop() {
	_ = t.run.Run([]string{t.ctlPath, "off"})
}
