package remotelaunch

import (
	"context"
	"errors"
	"reflect"
	"strings"
	"testing"
	"time"
)

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

type fakeProc struct {
	done   chan struct{}
	err    error
	killed int
}

func newFakeProc() *fakeProc { return &fakeProc{done: make(chan struct{})} }

func (p *fakeProc) Kill() error {
	p.killed++
	select {
	case <-p.done:
	default:
		close(p.done)
	}
	return nil
}
func (p *fakeProc) Done() <-chan struct{} { return p.done }
func (p *fakeProc) Err() error            { return p.err }

type harness struct {
	relay       *fakeRelay
	proc        *fakeProc
	lanUp       bool
	forwardUp   bool
	tunnelArgv  []string
	viewerArgvs [][]string
	viewerCode  int
	probes      []string
	startErr    error
}

func (h *harness) deps() Deps {
	d := Deps{
		Probe: func(addr string, _ time.Duration) bool {
			h.probes = append(h.probes, addr)
			if strings.HasPrefix(addr, "127.0.0.1:") {
				return h.forwardUp
			}
			return h.lanUp
		},
		FreePort: func() (int, error) { return 54321, nil },
		StartForward: func(argv []string) (Process, error) {
			h.tunnelArgv = argv
			if h.startErr != nil {
				return nil, h.startErr
			}
			return h.proc, nil
		},
		RunViewer: func(_ context.Context, argv []string) (int, error) {
			h.viewerArgvs = append(h.viewerArgvs, argv)
			return h.viewerCode, nil
		},
		ReadyTimeout: 50 * time.Millisecond,
		PollInterval: time.Millisecond,
	}
	if h.relay != nil {
		d.Relay = h.relay
	}
	return d
}

var rdpViewer = []string{"sdl-freerdp", "/v:{addr}", "/u:glats"}

func TestLanReachableLaunchesViewerDirectly(t *testing.T) {
	h := &harness{lanUp: true, relay: &fakeRelay{ensureOK: true}, proc: newFakeProc(), viewerCode: 3}
	code, err := Run(context.Background(), Target{"rog.lan", 3389}, rdpViewer, h.deps())
	if err != nil || code != 3 {
		t.Fatalf("code=%d err=%v, want 3 nil", code, err)
	}
	want := [][]string{{"sdl-freerdp", "/v:rog.lan:3389", "/u:glats"}}
	if !reflect.DeepEqual(h.viewerArgvs, want) {
		t.Fatalf("viewer argvs = %v, want %v", h.viewerArgvs, want)
	}
	if h.relay.ensureCalls != 0 || h.relay.stops != 0 || h.tunnelArgv != nil {
		t.Fatalf("relay/tunnel touched on LAN: ensure=%d stops=%d tunnel=%v", h.relay.ensureCalls, h.relay.stops, h.tunnelArgv)
	}
}

func TestOffLanStartsRelayForwardsAndCleansUp(t *testing.T) {
	h := &harness{forwardUp: true, relay: &fakeRelay{ensureOK: true}, proc: newFakeProc()}
	code, err := Run(context.Background(), Target{"thinkcentre.lan", 3389}, rdpViewer, h.deps())
	if err != nil || code != 0 {
		t.Fatalf("code=%d err=%v", code, err)
	}
	wantTunnel := []string{
		"-N", "-o", "ExitOnForwardFailure=yes", "-o", "BatchMode=yes", "-o", "ConnectTimeout=5",
		"-o", "ServerAliveInterval=15", "-o", "ServerAliveCountMax=4",
		"-L", "127.0.0.1:54321:thinkcentre.lan:3389", "rog-relay",
	}
	if !reflect.DeepEqual(h.tunnelArgv, wantTunnel) {
		t.Fatalf("tunnel argv = %v, want %v", h.tunnelArgv, wantTunnel)
	}
	wantViewer := [][]string{{"sdl-freerdp", "/v:127.0.0.1:54321", "/u:glats"}}
	if !reflect.DeepEqual(h.viewerArgvs, wantViewer) {
		t.Fatalf("viewer argvs = %v, want %v", h.viewerArgvs, wantViewer)
	}
	if h.relay.ensureCalls != 1 || h.relay.stops != 1 {
		t.Fatalf("relay ensure=%d stops=%d, want 1/1: a relay the launcher started must be stopped", h.relay.ensureCalls, h.relay.stops)
	}
	if h.proc.killed != 1 {
		t.Fatalf("ssh forward killed %d times, want 1", h.proc.killed)
	}
}

func TestOffLanKeepsRelayThatWasAlreadyUp(t *testing.T) {
	h := &harness{forwardUp: true, relay: &fakeRelay{upNow: true, ensureOK: true}, proc: newFakeProc()}
	if _, err := Run(context.Background(), Target{"rog.lan", 3389}, rdpViewer, h.deps()); err != nil {
		t.Fatal(err)
	}
	if h.relay.ensureCalls != 0 || h.relay.stops != 0 {
		t.Fatalf("relay ensure=%d stops=%d, want 0/0: never stop a relay the user started", h.relay.ensureCalls, h.relay.stops)
	}
	if h.proc.killed != 1 {
		t.Fatalf("ssh forward killed %d times, want 1", h.proc.killed)
	}
}

func TestOffLanFailsWhenRelayDoesNotComeUp(t *testing.T) {
	h := &harness{relay: &fakeRelay{ensureOK: false}, proc: newFakeProc()}
	code, err := Run(context.Background(), Target{"rog.lan", 3389}, rdpViewer, h.deps())
	if err == nil || code == 0 {
		t.Fatalf("code=%d err=%v, want failure", code, err)
	}
	if len(h.viewerArgvs) != 0 || h.tunnelArgv != nil {
		t.Fatal("viewer or tunnel started without a relay")
	}
	if h.relay.stops != 0 {
		t.Fatalf("stops = %d, want 0: relay never came up", h.relay.stops)
	}
}

func TestOffLanWithoutRelayBinaryFails(t *testing.T) {
	h := &harness{proc: newFakeProc()}
	if _, err := Run(context.Background(), Target{"rog.lan", 3389}, rdpViewer, h.deps()); err == nil {
		t.Fatal("want error when no relay is available")
	}
}

func TestForwardThatDiesEarlyStopsRelayAndSkipsViewer(t *testing.T) {
	h := &harness{relay: &fakeRelay{ensureOK: true}, proc: newFakeProc()}
	h.proc.err = errors.New("exit status 255")
	close(h.proc.done)
	code, err := Run(context.Background(), Target{"rog.lan", 3389}, rdpViewer, h.deps())
	if err == nil || code == 0 {
		t.Fatalf("code=%d err=%v, want failure", code, err)
	}
	if len(h.viewerArgvs) != 0 {
		t.Fatal("viewer started although the forward died")
	}
	if h.relay.stops != 1 {
		t.Fatalf("stops = %d, want 1", h.relay.stops)
	}
}

func TestForwardNeverReadyTimesOutAndCleansUp(t *testing.T) {
	h := &harness{relay: &fakeRelay{ensureOK: true}, proc: newFakeProc()}
	if _, err := Run(context.Background(), Target{"rog.lan", 3389}, rdpViewer, h.deps()); err == nil {
		t.Fatal("want timeout error")
	}
	if h.proc.killed != 1 || h.relay.stops != 1 {
		t.Fatalf("killed=%d stops=%d, want 1/1", h.proc.killed, h.relay.stops)
	}
}

func TestVncViewerPlaceholderOffLan(t *testing.T) {
	h := &harness{forwardUp: true, relay: &fakeRelay{ensureOK: true}, proc: newFakeProc()}
	viewer := []string{"vncviewer", "-RemoteResize", "{addr}"}
	if _, err := Run(context.Background(), Target{"t14.lan", 5900}, viewer, h.deps()); err != nil {
		t.Fatal(err)
	}
	want := [][]string{{"vncviewer", "-RemoteResize", "127.0.0.1:54321"}}
	if !reflect.DeepEqual(h.viewerArgvs, want) {
		t.Fatalf("viewer argvs = %v, want %v", h.viewerArgvs, want)
	}
}

func TestEmptyViewerIsRejected(t *testing.T) {
	h := &harness{lanUp: true, proc: newFakeProc()}
	if _, err := Run(context.Background(), Target{"rog.lan", 3389}, nil, h.deps()); err == nil {
		t.Fatal("want error for empty viewer")
	}
}
