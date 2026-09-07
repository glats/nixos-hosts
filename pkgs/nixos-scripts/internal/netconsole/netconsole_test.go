package netconsole

import (
	"bytes"
	"context"
	"errors"
	"net"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestSplitLines(t *testing.T) {
	cases := []struct {
		name     string
		datagram []byte
		want     []string
	}{
		{"empty", nil, nil},
		{"only newline", []byte("\n"), nil},
		{"single line with framing", []byte("hello\n"), []string{"hello"}},
		{"single line no newline", []byte("hello"), []string{"hello"}},
		{"multi line", []byte("<12>one\ntwo\n"), []string{"<12>one", "two"}},
		{"multi line no trailing", []byte("one\ntwo"), []string{"one", "two"}},
		{"blank lines dropped", []byte("one\n\ntwo\n\n"), []string{"one", "two"}},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got := SplitLines(tc.datagram)
			if len(got) != len(tc.want) {
				t.Fatalf("SplitLines(%q) = %q, want %q", tc.datagram, got, tc.want)
			}
			for i := range got {
				if got[i] != tc.want[i] {
					t.Fatalf("SplitLines(%q)[%d] = %q, want %q", tc.datagram, i, got[i], tc.want[i])
				}
			}
		})
	}
}

func TestExtractNonce(t *testing.T) {
	cases := []struct {
		name  string
		line  string
		want  string
		found bool
	}{
		{"plain marker", "netconsole-verify: nonce=abc123", "abc123", true},
		{"printk syslog prefix", "<12>netconsole-verify: nonce=0ff9", "0ff9", true},
		{"marker mid line", "kmsg noise netconsole-verify: nonce=xyz123 tail", "xyz123", true},
		{"empty token", "netconsole-verify: nonce=", "", false},
		{"token cut at space", "netconsole-verify: nonce=abc def", "abc", true},
		{"wrong prefix", "netconsole-verify: nonce2=abc", "", false},
		{"no marker", "<6>Power down", "", false},
		{"empty line", "", "", false},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got, ok := ExtractNonce(tc.line)
			if ok != tc.found || got != tc.want {
				t.Fatalf("ExtractNonce(%q) = %q, %v; want %q, %v", tc.line, got, ok, tc.want, tc.found)
			}
		})
	}
}

func TestACKFor(t *testing.T) {
	if got, want := ACKFor("abc123"), "netconsole-ack: nonce=abc123"; got != want {
		t.Fatalf("ACKFor = %q, want %q", got, want)
	}
}

func TestLogLine(t *testing.T) {
	ts := time.Date(2026, 9, 7, 14, 3, 5, 0, time.UTC)
	if got, want := LogLine(ts, "<6>Power down"), "2026-09-07T14:03:05Z <6>Power down"; got != want {
		t.Fatalf("LogLine = %q, want %q", got, want)
	}
}

func TestAppenderAppendAll(t *testing.T) {
	ts := time.Date(2026, 9, 7, 10, 0, 0, 0, time.UTC)
	path := filepath.Join(t.TempDir(), "nested", "netconsole.log")
	app := &Appender{Path: path}

	if err := app.AppendAll(ts, nil); err != nil {
		t.Fatalf("empty batch: %v", err)
	}
	if err := app.AppendAll(ts, []string{"one", "two"}); err != nil {
		t.Fatalf("first batch: %v", err)
	}
	if err := app.AppendAll(ts, []string{"three"}); err != nil {
		t.Fatalf("second batch: %v", err)
	}

	got, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read: %v", err)
	}
	want := "2026-09-07T10:00:00Z one\n2026-09-07T10:00:00Z two\n2026-09-07T10:00:00Z three\n"
	if string(got) != want {
		t.Fatalf("file = %q, want %q", got, want)
	}
}

// fakeConn records writes and replays queued reads, so Serve and Handle
// are exercised without any real network. Once the queue is drained it
// blocks on block (like a real socket read) until Close releases it.
type fakeConn struct {
	reads   []readResult
	writes  []writeRecord
	readErr error
	block   chan struct{}
	closed  bool
}

type readResult struct {
	data []byte
	addr *net.UDPAddr
	err  error
}

type writeRecord struct {
	data []byte
	addr *net.UDPAddr
}

func (f *fakeConn) ReadFromUDP(p []byte) (int, *net.UDPAddr, error) {
	if len(f.reads) > 0 {
		r := f.reads[0]
		f.reads = f.reads[1:]
		if r.err != nil {
			return 0, nil, r.err
		}
		n := copy(p, r.data)
		return n, r.addr, nil
	}
	if f.block != nil {
		<-f.block
	}
	if f.readErr != nil {
		return 0, nil, f.readErr
	}
	return 0, nil, errors.New("no queued reads")
}

func (f *fakeConn) WriteToUDP(p []byte, addr *net.UDPAddr) (int, error) {
	f.writes = append(f.writes, writeRecord{data: bytes.Clone(p), addr: addr})
	return len(p), nil
}

func (f *fakeConn) Close() error {
	f.closed = true
	if f.block != nil {
		close(f.block)
	}
	return nil
}

var testAddr = &net.UDPAddr{IP: net.IPv4(172, 16, 0, 9), Port: 6665}

func TestHandle(t *testing.T) {
	ts := time.Date(2026, 9, 7, 11, 0, 0, 0, time.UTC)
	cases := []struct {
		name     string
		data     []byte
		wantLog  string
		wantACKs []string
	}{
		{
			name:    "plain line logged, no ack",
			data:    []byte("<6>reboot: Power down\n"),
			wantLog: "2026-09-07T11:00:00Z <6>reboot: Power down\n",
		},
		{
			name:    "multi line one timestamp",
			data:    []byte("<4>rog-s5: hook-start\n<4>rog-s5: modules-state\n"),
			wantLog: "2026-09-07T11:00:00Z <4>rog-s5: hook-start\n2026-09-07T11:00:00Z <4>rog-s5: modules-state\n",
		},
		{
			name:     "nonce marker acked to source",
			data:     []byte("<12>netconsole-verify: nonce=dead01\n"),
			wantLog:  "2026-09-07T11:00:00Z <12>netconsole-verify: nonce=dead01\n",
			wantACKs: []string{"netconsole-ack: nonce=dead01"},
		},
		{
			name: "nonce and plain lines in one datagram",
			data: []byte("<12>netconsole-verify: nonce=beef7\n<6>ready\n"),
			wantLog: "2026-09-07T11:00:00Z <12>netconsole-verify: nonce=beef7\n" +
				"2026-09-07T11:00:00Z <6>ready\n",
			wantACKs: []string{"netconsole-ack: nonce=beef7"},
		},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			conn := &fakeConn{}
			path := filepath.Join(t.TempDir(), "netconsole.log")
			app := &Appender{Path: path}

			if err := Handle(conn, app, ts, tc.data, testAddr); err != nil {
				t.Fatalf("Handle: %v", err)
			}

			got, err := os.ReadFile(path)
			if err != nil {
				t.Fatalf("read log: %v", err)
			}
			if string(got) != tc.wantLog {
				t.Fatalf("log = %q, want %q", got, tc.wantLog)
			}
			if len(conn.writes) != len(tc.wantACKs) {
				t.Fatalf("got %d writes, want %d", len(conn.writes), len(tc.wantACKs))
			}
			for i, want := range tc.wantACKs {
				if string(conn.writes[i].data) != want {
					t.Fatalf("write[%d] = %q, want %q", i, conn.writes[i].data, want)
				}
				if conn.writes[i].addr != testAddr {
					t.Fatalf("write[%d] addr = %v, want %v", i, conn.writes[i].addr, testAddr)
				}
			}
		})
	}
}

func TestHandleAppendFailureSuppressesACK(t *testing.T) {
	conn := &fakeConn{}
	app := &Appender{Path: filepath.Join(t.TempDir(), "dir", "netconsole.log")}
	// Corrupt the appender so the write fails after MkdirAll: point Path at
	// a directory.
	app.Path = t.TempDir()
	err := Handle(conn, app, time.Now(), []byte("netconsole-verify: nonce=x\n"), testAddr)
	if err == nil {
		t.Fatal("expected append error")
	}
	if len(conn.writes) != 0 {
		t.Fatalf("ACK written despite failed append: %v", conn.writes)
	}
}

func TestServe(t *testing.T) {
	dir := t.TempDir()
	app := &Appender{Path: filepath.Join(dir, "netconsole.log")}

	rogAddr := &net.UDPAddr{IP: net.IPv4(172, 16, 0, 9), Port: 6665}
	conn := &fakeConn{
		reads: []readResult{
			{data: []byte("<12>netconsole-verify: nonce=aa11\n"), addr: rogAddr},
			{data: []byte("<6>line two\n"), addr: rogAddr},
		},
		block: make(chan struct{}),
	}
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	var reported []error
	done := make(chan error, 1)
	go func() { done <- Serve(ctx, conn, app, func(e error) { reported = append(reported, e) }) }()

	// Wait until both datagrams were consumed and the ACK was sent.
	deadline := time.Now().Add(5 * time.Second)
	for time.Now().Before(deadline) && (len(conn.reads) > 0 || len(conn.writes) == 0) {
		time.Sleep(5 * time.Millisecond)
	}
	if len(conn.reads) > 0 || len(conn.writes) == 0 {
		t.Fatal("timed out waiting for Serve to process datagrams")
	}

	// Shutdown path: cancel, then close the socket to unblock the read.
	cancel()
	conn.Close()
	if err := <-done; err != nil {
		t.Fatalf("Serve: %v", err)
	}

	if len(reported) != 0 {
		t.Fatalf("unexpected errors: %v", reported)
	}
	if len(conn.writes) != 1 || string(conn.writes[0].data) != "netconsole-ack: nonce=aa11" {
		t.Fatalf("writes = %v, want single nonce ack", conn.writes)
	}

	content, err := os.ReadFile(app.Path)
	if err != nil {
		t.Fatalf("read: %v", err)
	}
	if lines := strings.Split(strings.TrimSuffix(string(content), "\n"), "\n"); len(lines) != 2 {
		t.Fatalf("expected 2 logged lines, got %q", content)
	}
}

func TestServeReadErrorReturns(t *testing.T) {
	app := &Appender{Path: filepath.Join(t.TempDir(), "netconsole.log")}
	conn := &fakeConn{readErr: errors.New("boom")}
	ctx := context.Background()

	if err := Serve(ctx, conn, app, func(error) {}); err == nil {
		t.Fatal("expected read error to propagate")
	}
}

func TestServeContextDoneReturnsNil(t *testing.T) {
	app := &Appender{Path: filepath.Join(t.TempDir(), "netconsole.log")}
	conn := &fakeConn{readErr: errors.New("use of closed connection")}
	ctx, cancel := context.WithCancel(context.Background())
	cancel()

	if err := Serve(ctx, conn, app, func(error) {}); err != nil {
		t.Fatalf("Serve after cancel = %v, want nil", err)
	}
}
