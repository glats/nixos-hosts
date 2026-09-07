// Package netconsole implements the shared netconsole UDP receiver logic
// used by the netconsole-log command: datagram line framing, nonce marker
// detection, ACK construction and durable, timestamped log appends.
//
// Receiver contract (rog -> thinkcentre):
//
//   - rog binds UDP :6665 as its netconsole source port and forwards kernel
//     messages to thinkcentre:6666 (configfs netconsole, DHCP-safe source).
//
//   - Readiness probe: rog writes a nonce marker line to /dev/kmsg, which
//     netconsole forwards. The marker format is
//
//     netconsole-verify: nonce=<token>
//
//     where <token> is one or more alphanumeric characters. A printk syslog
//     prefix such as "<12>" may precede the marker; the receiver therefore
//     matches the marker anywhere inside a line.
//
//   - The receiver replies "netconsole-ack: nonce=<token>" to the datagram's
//     source address:port — i.e. from its :6666 socket back to rog's :6665
//     socket. rog must observe the matching ACK within 2s or its setup
//     oneshot fails visibly.
//
//   - Every received line is durably recorded (fsync) under
//     /var/log/netconsole/ prefixed with its RFC3339 receive timestamp.
//
// UDP 6666 must be reachable inbound on thinkcentre; the NixOS firewall is
// disabled there (linux/system/networking/firewall.nix), so no port rule is
// required and the ACK return path to 6665 needs none either.
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
	// NonceMarker is the prefix rog's readiness probe writes to /dev/kmsg;
	// netconsole forwards it as a regular kernel line on UDP 6666.
	NonceMarker = "netconsole-verify: nonce="

	// ACKPrefix starts the receiver's ACK payload; rog matches its probe
	// nonce against what follows.
	ACKPrefix = "netconsole-ack: nonce="
)

// nonceRe captures the alphanumeric token of a nonce marker line. The
// marker may be preceded by a printk prefix ("<N>") or other kmsg text,
// so it is matched anywhere in the line.
var nonceRe = regexp.MustCompile(`netconsole-verify: nonce=([A-Za-z0-9]+)`)

// ExtractNonce returns the nonce token carried by line, if any.
func ExtractNonce(line string) (string, bool) {
	m := nonceRe.FindStringSubmatch(line)
	if m == nil {
		return "", false
	}
	return m[1], true
}

// ACKFor returns the ACK payload acknowledging the given nonce.
func ACKFor(nonce string) string {
	return ACKPrefix + nonce
}

// SplitLines frames one UDP datagram into its lines: datagrams are split
// on '\n', a single trailing newline is framing (not a blank line), and
// blank lines are dropped since they carry no kernel content.
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

// LogLine renders one line with its receive timestamp prefix (RFC3339).
func LogLine(ts time.Time, line string) string {
	return ts.Format(time.RFC3339) + " " + line
}

// Appender durably appends timestamped lines to a log file. Every batch is
// opened with O_APPEND, written, fsynced and closed, so logrotate's
// rename-and-recreate rotation is picked up by the next batch without any
// signal to the receiver.
type Appender struct {
	// Path of the log file (e.g. /var/log/netconsole/netconsole.log).
	Path string
}

// AppendAll writes one fsynced batch: each line gets the ts prefix. An
// empty batch is a no-op.
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

// PacketConn is the UDP socket surface Serve needs; it is satisfied by
// *net.UDPConn and by the fakes used in tests.
type PacketConn interface {
	ReadFromUDP(p []byte) (n int, addr *net.UDPAddr, err error)
	WriteToUDP(p []byte, addr *net.UDPAddr) (n int, err error)
	Close() error
}

// Handle processes one datagram: it appends the framed lines with their
// receive timestamp and replies an ACK to addr for every nonce marker line.
// A failed append returns an error and suppresses the ACK, so rog's probe
// never sees a readiness ACK for lines that were not durably recorded.
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

// Serve reads datagrams from conn until the context is done or the
// connection is closed. Read errors other than shutdown return an error
// so the systemd unit restarts the receiver. Append failures are reported
// via report and do not stop serving.
func Serve(ctx context.Context, conn PacketConn, app *Appender, report func(error)) error {
	buf := make([]byte, 65536)
	for {
		if ctx.Err() != nil {
			return nil
		}
		n, addr, err := conn.ReadFromUDP(buf)
		if err != nil {
			if ctx.Err() != nil {
				return nil // closed during shutdown
			}
			return fmt.Errorf("netconsole: read udp: %w", err)
		}
		if err := Handle(conn, app, time.Now(), buf[:n], addr); err != nil {
			report(err)
		}
	}
}
