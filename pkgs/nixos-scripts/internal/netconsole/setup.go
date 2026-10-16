package netconsole

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"net"
	"os"
	"strings"
	"time"

	"github.com/glats/nixos-scripts/internal/kmsg"
)

type Target struct {
	Iface      string
	LocalPort  int
	RemoteIP   string
	RemoteMAC  string
	RemotePort int
}

type ConfigFS interface {
	Mkdir(path string) error

	WriteFile(path string, data []byte) error

	Remove(path string) error
}

type OsConfigFS struct {
	Root string
}

func (c *OsConfigFS) Mkdir(dir string) error {
	return os.Mkdir(c.Root+"/"+dir, 0o755)
}

func (c *OsConfigFS) WriteFile(name string, data []byte) error {
	return os.WriteFile(c.Root+"/"+name, data, 0o644)
}

func (c *OsConfigFS) Remove(dir string) error {
	return os.Remove(c.Root + "/" + dir)
}

func NewNonce() (string, error) {
	buf := make([]byte, 8)
	if _, err := rand.Read(buf); err != nil {
		return "", fmt.Errorf("netconsole: nonce: %w", err)
	}
	return hex.EncodeToString(buf), nil
}

func IPv4Of(list func(name string) ([]net.Addr, error), name string) (net.IP, error) {
	addrs, err := list(name)
	if err != nil {
		return nil, fmt.Errorf("netconsole: addresses of %s: %w", name, err)
	}
	for _, addr := range addrs {
		ipnet, ok := addr.(*net.IPNet)
		if !ok || ipnet.IP.To4() == nil {
			continue
		}
		ip := ipnet.IP
		if ip.IsLoopback() || ip.IsLinkLocalUnicast() {
			continue
		}
		return ip, nil
	}
	return nil, fmt.Errorf("netconsole: no global IPv4 address on %s", name)
}

func ConfigureTarget(fs ConfigFS, t Target, src net.IP) error {

	_ = fs.WriteFile("target1/enabled", []byte("0\n"))
	_ = fs.Remove("target1")
	if err := fs.Mkdir("target1"); err != nil {
		return fmt.Errorf("netconsole: mkdir target1: %w", err)
	}
	fields := [][2]string{
		{"target1/dev_name", t.Iface},
		{"target1/local_ip", src.String()},
		{"target1/local_port", fmt.Sprint(t.LocalPort)},
		{"target1/remote_ip", t.RemoteIP},
		{"target1/remote_mac", t.RemoteMAC},
		{"target1/remote_port", fmt.Sprint(t.RemotePort)},
	}
	for _, f := range fields {
		if err := fs.WriteFile(f[0], []byte(f[1]+"\n")); err != nil {
			return fmt.Errorf("netconsole: write %s: %w", f[0], err)
		}
	}
	if err := fs.WriteFile("target1/enabled", []byte("1\n")); err != nil {
		return fmt.Errorf("netconsole: enable target1: %w", err)
	}
	return nil
}

type ackConn interface {
	ReadFromUDP(p []byte) (n int, addr *net.UDPAddr, err error)
	SetReadDeadline(t time.Time) error
}

func Verify(km *kmsg.Writer, conn ackConn, nonce string, timeout time.Duration) error {
	probe := NonceMarker + nonce
	if err := km.Write(kmsg.UserNotice, probe); err != nil {
		return fmt.Errorf("netconsole: probe %q: %w", probe, err)
	}
	if err := conn.SetReadDeadline(time.Now().Add(timeout)); err != nil {
		return fmt.Errorf("netconsole: read deadline: %w", err)
	}
	buf := make([]byte, 4096)
	for {
		n, _, err := conn.ReadFromUDP(buf)
		if err != nil {
			return fmt.Errorf("netconsole: no ACK within %s for nonce %s: %w", timeout, nonce, err)
		}
		for _, line := range SplitLines(buf[:n]) {
			if acked, ok := ExtractACKNonce(line); ok && acked == nonce {
				return nil
			}
		}

	}
}

func SetupStatus(t Target, src net.IP, nonce string) string {
	return fmt.Sprintf("netconsole-setup: target1 ready iface=%s src=%s:%d -> %s:%d nonce=%s",
		t.Iface, src, t.LocalPort, t.RemoteIP, t.RemotePort, nonce)
}

func TrimParam(v []byte) string {
	return strings.ToLower(strings.TrimSpace(string(v)))
}
