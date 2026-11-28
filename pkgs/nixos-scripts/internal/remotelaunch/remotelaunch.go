package remotelaunch

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/glats/nixos-scripts/internal/sshforward"
)

const (
	Placeholder  = "{addr}"
	RelayAlias   = "rog-relay"
	ProbeTimeout = 2 * time.Second
	loopback     = "127.0.0.1"
)

type Relay interface {
	Up() bool
	EnsureUp() bool
	Stop()
}

type Process interface {
	Kill() error
	Done() <-chan struct{}
	Err() error
}

type Target struct {
	Host string
	Port int
}

type Deps struct {
	Probe        func(addr string, timeout time.Duration) bool
	Relay        Relay
	FreePort     func() (int, error)
	StartForward func(argv []string) (Process, error)
	RunViewer    func(ctx context.Context, argv []string) (int, error)
	ReadyTimeout time.Duration
	PollInterval time.Duration
}

func (t Target) addr() string {
	return fmt.Sprintf("%s:%d", t.Host, t.Port)
}

func substitute(viewer []string, addr string) []string {
	out := make([]string, len(viewer))
	for i, arg := range viewer {
		out[i] = strings.ReplaceAll(arg, Placeholder, addr)
	}
	return out
}

func Run(ctx context.Context, target Target, viewer []string, d Deps) (int, error) {
	if len(viewer) == 0 {
		return 1, errors.New("viewer command is required")
	}
	if d.Probe(target.addr(), ProbeTimeout) {
		return d.RunViewer(ctx, substitute(viewer, target.addr()))
	}
	if d.Relay == nil {
		return 1, fmt.Errorf("%s unreachable and no relay link available", target.addr())
	}
	if !d.Relay.Up() {
		if !d.Relay.EnsureUp() {
			return 1, errors.New("relay link did not come up")
		}
		defer d.Relay.Stop()
	}
	port, err := d.FreePort()
	if err != nil {
		return 1, fmt.Errorf("no free local port: %w", err)
	}
	argv, err := sshforward.BuildLocalForwardSSHArgs(RelayAlias, port, target.Host, target.Port)
	if err != nil {
		return 1, err
	}
	proc, err := d.StartForward(argv)
	if err != nil {
		return 1, fmt.Errorf("start ssh forward: %w", err)
	}
	defer func() {
		_ = proc.Kill()
		<-proc.Done()
	}()
	local := fmt.Sprintf("%s:%d", loopback, port)
	if err := waitReady(ctx, local, proc, d); err != nil {
		return 1, err
	}
	return d.RunViewer(ctx, substitute(viewer, local))
}

func waitReady(ctx context.Context, local string, proc Process, d Deps) error {
	deadline := time.After(d.ReadyTimeout)
	for {
		if d.Probe(local, time.Second) {
			return nil
		}
		select {
		case <-proc.Done():
			err := proc.Err()
			if err == nil {
				err = errors.New("exited before the forward was ready")
			}
			return fmt.Errorf("ssh forward failed: %w", err)
		case <-deadline:
			return fmt.Errorf("ssh forward on %s not ready in %s", local, d.ReadyTimeout)
		case <-ctx.Done():
			return ctx.Err()
		case <-time.After(d.PollInterval):
		}
	}
}
