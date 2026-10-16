package netconsole

import (
	"bytes"
	"context"
	"fmt"
	"net"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"
)

const (
	NonceMarker = "netconsole-verify: nonce="

	ACKPrefix = "netconsole-ack: nonce="
)

var nonceRe = regexp.MustCompile(`netconsole-verify: nonce=([A-Za-z0-9]+)`)

var ackNonceRe = regexp.MustCompile(`netconsole-ack: nonce=([A-Za-z0-9]+)`)

func ExtractACKNonce(line string) (string, bool) {
	m := ackNonceRe.FindStringSubmatch(line)
	if m == nil {
		return "", false
	}
	return m[1], true
}

func ExtractNonce(line string) (string, bool) {
	m := nonceRe.FindStringSubmatch(line)
	if m == nil {
		return "", false
	}
	return m[1], true
}

func ACKFor(nonce string) string {
	return ACKPrefix + nonce
}

func SplitLines(datagram []byte) []string {
	trimmed := bytes.TrimSuffix(datagram, []byte("\n"))
	if len(trimmed) == 0 {
		return nil
	}
	var lines []string
	for _, line := range strings.Split(string(trimmed), "\n") {
		if line != "" {
			lines = append(lines, line)
		}
	}
	return lines
}

func LogLine(ts time.Time, line string) string {
	return ts.Format(time.RFC3339) + " " + line
}

type Appender struct {
	Path string
}

func (a *Appender) AppendAll(ts time.Time, lines []string) error {
	if len(lines) == 0 {
		return nil
	}
	if err := os.MkdirAll(filepath.Dir(a.Path), 0o755); err != nil {
		return fmt.Errorf("netconsole: mkdir for %s: %w", a.Path, err)
	}
	var buf bytes.Buffer
	for _, line := range lines {
		buf.WriteString(LogLine(ts, line))
		buf.WriteByte('\n')
	}
	f, err := os.OpenFile(a.Path, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0o644)
	if err != nil {
		return fmt.Errorf("netconsole: open %s: %w", a.Path, err)
	}
	if _, err := f.Write(buf.Bytes()); err != nil {
		f.Close()
		return fmt.Errorf("netconsole: write %s: %w", a.Path, err)
	}
	if err := f.Sync(); err != nil {
		f.Close()
		return fmt.Errorf("netconsole: fsync %s: %w", a.Path, err)
	}
	return f.Close()
}

type PacketConn interface {
	ReadFromUDP(p []byte) (n int, addr *net.UDPAddr, err error)
	WriteToUDP(p []byte, addr *net.UDPAddr) (n int, err error)
	Close() error
}

func Handle(conn PacketConn, app *Appender, ts time.Time, data []byte, addr *net.UDPAddr) error {
	lines := SplitLines(data)
	if err := app.AppendAll(ts, lines); err != nil {
		return err
	}
	for _, line := range lines {
		if nonce, ok := ExtractNonce(line); ok {
			if _, err := conn.WriteToUDP([]byte(ACKFor(nonce)), addr); err != nil {
				return fmt.Errorf("netconsole: ack to %s: %w", addr, err)
			}
		}
	}
	return nil
}

func Serve(ctx context.Context, conn PacketConn, app *Appender, report func(error)) error {
	buf := make([]byte, 65536)
	for {
		if ctx.Err() != nil {
			return nil
		}
		n, addr, err := conn.ReadFromUDP(buf)
		if err != nil {
			if ctx.Err() != nil {
				return nil
			}
			return fmt.Errorf("netconsole: read udp: %w", err)
		}
		if err := Handle(conn, app, time.Now(), buf[:n], addr); err != nil {
			report(err)
		}
	}
}
