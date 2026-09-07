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

// Target is one configfs netconsole target's parameters (the rog sender
// side). RemoteIP/RemoteMAC identify the receiver on thinkcentre; LocalPort
// is the UDP source port rog binds and the receiver ACKs back to.
type Target struct {
	Iface      string
	LocalPort  int
	RemoteIP   string
	RemoteMAC  string
	RemotePort int
}

// ConfigFS is the configfs surface target configuration needs. *OsConfigFS
// implements it against the real /sys/kernel/config tree; tests inject a
// map-backed fake so no kernel tree is touched.
type ConfigFS interface {
	// Mkdir creates the target directory (like mkdir in configfs).
	Mkdir(path string) error
	// WriteFile writes one attribute value (like echo value > attr).
	WriteFile(path string, data []byte) error
	// Remove deletes the target directory (like rmdir in configfs).
	Remove(path string) error
}

// OsConfigFS talks to the real configfs netconsole tree rooted at root
// ("/sys/kernel/config/netconsole" in production).
type OsConfigFS struct {
	Root string
}

// Mkdir creates dir under the configfs netconsole root.
func (c *OsConfigFS) Mkdir(dir string) error {
	return os.Mkdir(c.Root+"/"+dir, 0o755)
}

// WriteFile writes an attribute under the configfs netconsole root.
func (c *OsConfigFS) WriteFile(name string, data []byte) error {
	return os.WriteFile(c.Root+"/"+name, data, 0o644)
}

// Remove deletes a target directory under the configfs netconsole root.
func (c *OsConfigFS) Remove(dir string) error {
	return os.Remove(c.Root + "/" + dir)
}

// NewNonce returns 16 hex characters from crypto/rand — one or more
// alphanumeric characters, as the marker/ACK contract requires.
func NewNonce() (string, error) {
	buf := make([]byte, 8)
	if _, err := rand.Read(buf); err != nil {
		return "", fmt.Errorf("netconsole: nonce: %w", err)
	}
	return hex.EncodeToString(buf), nil
}

// IPv4Of returns the first global (non-loopback, non-link-local) IPv4
// address of the named interface, using list to fetch the address set.
// list is injectable so tests never touch real interfaces; production
// passes net.InterfaceByName(name).Addrs, which reads the LIVE lease — the
// setup is DHCP-safe by construction, never a hardcoded source IP.
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

// ConfigureTarget writes all target1 attributes for t with source address
// src and enables the target. The enabled attribute MUST be written last
// (kernel refuses enabling a target with unset parameters), so it is
// emitted after every other field. An existing target directory is reset
// first (disable + rmdir), making repeated unit runs idempotent: an
// enabled target's attributes cannot be rewritten in place.
func ConfigureTarget(fs ConfigFS, t Target, src net.IP) error {
	// Reset path: ignore "no such file" style failures, they just mean the
	// target does not exist yet. A real EBUSY (target enabled and in use
	// and un-removable) surfaces at the Mkdir below as EEXIST and fails
	// the setup visibly.
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

// ackConn is the UDP socket surface Verify needs; *net.UDPConn satisfies
// it and tests inject fakes.
type ackConn interface {
	ReadFromUDP(p []byte) (n int, addr *net.UDPAddr, err error)
	SetReadDeadline(t time.Time) error
}

// Verify emits the nonce probe marker to kmsg (which netconsole forwards to
// the receiver over UDP 6666), then waits up to timeout on conn for the
// receiver's matching ACK (replied to rog's source socket :localPort).
// Lines whose ACK nonce does not match are ignored as foreign/spoofed
// traffic; on timeout the returned error names the nonce so the oneshot
// unit fails visibly.
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
		// Non-matching datagram: foreign or spoofed traffic, keep waiting.
	}
}

// SetupStatus renders the ready breadcrumb naming every party, so the
// receiver log and journal carry the same readiness evidence.
func SetupStatus(t Target, src net.IP, nonce string) string {
	return fmt.Sprintf("netconsole-setup: target1 ready iface=%s src=%s:%d -> %s:%d nonce=%s",
		t.Iface, src, t.LocalPort, t.RemoteIP, t.RemotePort, nonce)
}

// TrimParam normalizes a kernel sysfs parameter value: strip whitespace and
// lowercase (kernel bool params render as "Y"/"N").
func TrimParam(v []byte) string {
	return strings.ToLower(strings.TrimSpace(string(v)))
}
