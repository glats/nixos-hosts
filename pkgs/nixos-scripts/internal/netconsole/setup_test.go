package netconsole

import (
	"fmt"
	"net"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"
	"time"

	"github.com/glats/nixos-scripts/internal/kmsg"
)

// fakeConfigFS records attribute writes in order and can fail selected
// operations, standing in for the configfs netconsole tree.
type fakeConfigFS struct {
	files    map[string]string
	order    []string
	mkdirErr map[string]error
	rmErr    map[string]error
}

func newFakeConfigFS() *fakeConfigFS {
	return &fakeConfigFS{
		files:    map[string]string{},
		mkdirErr: map[string]error{},
		rmErr:    map[string]error{},
	}
}

func (f *fakeConfigFS) Mkdir(dir string) error {
	if err := f.mkdirErr[dir]; err != nil {
		return err
	}
	f.files[dir] = ""
	return nil
}

func (f *fakeConfigFS) WriteFile(path string, data []byte) error {
	f.files[path] = string(data)
	f.order = append(f.order, path)
	return nil
}

func (f *fakeConfigFS) Remove(dir string) error {
	if err := f.rmErr[dir]; err != nil {
		return err
	}
	delete(f.files, dir)
	return nil
}

func testTarget() Target {
	return Target{
		Iface:      "enp3s0",
		LocalPort:  6665,
		RemoteIP:   "172.16.0.11",
		RemoteMAC:  "6c:4b:90:2d:97:42",
		RemotePort: 6666,
	}
}

func TestNewNonceIsHexAndUnique(t *testing.T) {
	seen := map[string]bool{}
	for i := 0; i < 4; i++ {
		n, err := NewNonce()
		if err != nil {
			t.Fatalf("NewNonce: %v", err)
		}
		if len(n) != 16 {
			t.Errorf("nonce %q has %d chars, want 16", n, len(n))
		}
		if !regexp.MustCompile(`^[0-9a-f]+$`).MatchString(n) {
			t.Errorf("nonce %q is not lowercase hex", n)
		}
		if seen[n] {
			t.Errorf("nonce %q repeated", n)
		}
		seen[n] = true
	}
}

func addrList(addrs ...net.Addr) func(string) ([]net.Addr, error) {
	return func(string) ([]net.Addr, error) { return addrs, nil }
}

func v4Addr(s string) net.Addr {
	return &net.IPNet{IP: net.ParseIP(s).To4(), Mask: net.CIDRMask(24, 32)}
}

func TestIPv4OfPicksGlobalV4(t *testing.T) {
	got, err := IPv4Of(addrList(
		&net.IPNet{IP: net.ParseIP("fe80::1"), Mask: net.CIDRMask(64, 128)},
		v4Addr("169.254.3.4"), // link-local v4 must be skipped
		v4Addr("172.16.0.5"),
	), "enp3s0")
	if err != nil {
		t.Fatalf("IPv4Of: %v", err)
	}
	if got.String() != "172.16.0.5" {
		t.Errorf("got %s, want 172.16.0.5", got)
	}
}

func TestIPv4OfSkipsLoopbackAndErrorsWithoutGlobal(t *testing.T) {
	if ip, err := IPv4Of(addrList(
		&net.IPNet{IP: net.ParseIP("127.0.0.1").To4(), Mask: net.CIDRMask(8, 32)},
	), "lo"); err == nil {
		t.Errorf("expected error, got %s", ip)
	}
	_, err := IPv4Of(func(string) ([]net.Addr, error) {
		return nil, fmt.Errorf("no such interface")
	}, "enp3s0")
	if err == nil || !strings.Contains(err.Error(), "no such interface") {
		t.Errorf("provider error not propagated: %v", err)
	}
}

func TestConfigureTargetWritesAllFieldsEnabledLast(t *testing.T) {
	fs := newFakeConfigFS()
	src := net.ParseIP("172.16.0.5").To4()
	if err := ConfigureTarget(fs, testTarget(), src); err != nil {
		t.Fatalf("ConfigureTarget: %v", err)
	}
	want := map[string]string{
		"target1/dev_name":    "enp3s0\n",
		"target1/local_ip":    "172.16.0.5\n",
		"target1/local_port":  "6665\n",
		"target1/remote_ip":   "172.16.0.11\n",
		"target1/remote_mac":  "6c:4b:90:2d:97:42\n",
		"target1/remote_port": "6666\n",
		"target1/enabled":     "1\n",
	}
	for path, val := range want {
		if got := fs.files[path]; got != val {
			t.Errorf("%s = %q, want %q", path, got, val)
		}
	}
	if last := fs.order[len(fs.order)-1]; last != "target1/enabled" {
		t.Errorf("last write was %q, want target1/enabled", last)
	}
}

func TestConfigureTargetResetsExistingEnabledTarget(t *testing.T) {
	fs := newFakeConfigFS()
	// A leftover target from an earlier run: enabled with stale values.
	fs.files["target1"] = ""
	fs.files["target1/enabled"] = "1\n"
	if err := ConfigureTarget(fs, testTarget(), net.IPv4(172, 16, 0, 9)); err != nil {
		t.Fatalf("ConfigureTarget: %v", err)
	}
	if fs.files["target1/local_ip"] != "172.16.0.9\n" {
		t.Errorf("stale local_ip survived reset: %q", fs.files["target1/local_ip"])
	}
	if fs.files["target1/enabled"] != "1\n" {
		t.Errorf("target not re-enabled: %q", fs.files["target1/enabled"])
	}
}

func TestConfigureTargetPropagatesErrors(t *testing.T) {
	fs := newFakeConfigFS()
	fs.mkdirErr["target1"] = fmt.Errorf("EBUSY")
	if err := ConfigureTarget(fs, testTarget(), net.IPv4(10, 0, 0, 1)); err == nil {
		t.Fatal("expected mkdir error to propagate")
	}

	fs2 := newFakeConfigFS()
	// Simulate a missing attribute (e.g. netconsole without dynamic
	// config support): every write after mkdir fails for that path.
	fs2.mkdirErr["target1"] = nil
	failing := &failingWriteFS{inner: fs2, failPath: "target1/dev_name"}
	if err := ConfigureTarget(failing, testTarget(), net.IPv4(10, 0, 0, 1)); err == nil {
		t.Fatal("expected attribute write error to propagate")
	}
}

type failingWriteFS struct {
	inner    ConfigFS
	failPath string
}

func (f *failingWriteFS) Mkdir(dir string) error  { return f.inner.Mkdir(dir) }
func (f *failingWriteFS) Remove(dir string) error { return f.inner.Remove(dir) }
func (f *failingWriteFS) WriteFile(p string, d []byte) error {
	if p == f.failPath {
		return fmt.Errorf("no such attribute")
	}
	return f.inner.WriteFile(p, d)
}

// probeConn delivers scripted datagrams in order, then times out like a
// deadline-expired ReadFromUDP.
type probeConn struct {
	dgrams []probeDgram
}

type probeDgram struct {
	data string
	err  error
}

var errFakeTimeout = fmt.Errorf("i/o timeout")

func (c *probeConn) ReadFromUDP(p []byte) (int, *net.UDPAddr, error) {
	if len(c.dgrams) == 0 {
		return 0, nil, errFakeTimeout
	}
	d := c.dgrams[0]
	c.dgrams = c.dgrams[1:]
	if d.err != nil {
		return 0, nil, d.err
	}
	return copy(p, d.data), nil, nil
}

func (c *probeConn) SetReadDeadline(time.Time) error { return nil }

func newTestKmsg(t *testing.T) *kmsg.Writer {
	t.Helper()
	path := filepath.Join(t.TempDir(), "kmsg")
	if err := os.WriteFile(path, nil, 0o644); err != nil {
		t.Fatalf("touch kmsg: %v", err)
	}
	return &kmsg.Writer{Path: path}
}

func TestVerifyMatchesACK(t *testing.T) {
	conn := &probeConn{dgrams: []probeDgram{
		{data: "<6>kernel noise\n"},
		{data: ACKPrefix + "deadbeef12345678\n"},
	}}
	if err := Verify(newTestKmsg(t), conn, "deadbeef12345678", 2*time.Second); err != nil {
		t.Fatalf("Verify: %v", err)
	}
}

func TestVerifyIgnoresSpoofedNonceThenMatches(t *testing.T) {
	conn := &probeConn{dgrams: []probeDgram{
		{data: "netconsole-ack: nonce=ffffffffffffffff\n"}, // spoofed
		{data: "prefix netconsole-ack: nonce=abcd1234abcd1234 suffix\n"},
		{data: ACKPrefix + "abcd1234abcd1234\n"},
	}}
	if err := Verify(newTestKmsg(t), conn, "abcd1234abcd1234", 2*time.Second); err != nil {
		t.Fatalf("Verify: %v", err)
	}
}

func TestVerifyTimeoutFailsNamingNonce(t *testing.T) {
	conn := &probeConn{} // nothing ever arrives
	err := Verify(newTestKmsg(t), conn, "cafe0123cafe0123", 2*time.Second)
	if err == nil {
		t.Fatal("expected timeout error")
	}
	if !strings.Contains(err.Error(), "cafe0123cafe0123") || !strings.Contains(err.Error(), "ACK") {
		t.Errorf("timeout error must name nonce and ACK: %v", err)
	}
}

func TestVerifyProbeWriteError(t *testing.T) {
	km := &kmsg.Writer{Path: filepath.Join(t.TempDir(), "missing", "kmsg")}
	conn := &probeConn{}
	if err := Verify(km, conn, "abcd", 2*time.Second); err == nil {
		t.Fatal("expected probe write error to propagate")
	}
}

func TestVerifyKmsgProbeRecordsMarker(t *testing.T) {
	path := filepath.Join(t.TempDir(), "kmsg")
	if err := os.WriteFile(path, nil, 0o644); err != nil {
		t.Fatalf("touch kmsg: %v", err)
	}
	conn := &probeConn{dgrams: []probeDgram{{data: ACKPrefix + "beefbeefbeefbeef\n"}}}
	if err := Verify(&kmsg.Writer{Path: path}, conn, "beefbeefbeefbeef", time.Second); err != nil {
		t.Fatalf("Verify: %v", err)
	}
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read: %v", err)
	}
	if !strings.Contains(string(data), NonceMarker+"beefbeefbeefbeef") {
		t.Errorf("probe marker missing from kmsg output: %q", data)
	}
}

func TestSetupStatusBreadcrumb(t *testing.T) {
	got := SetupStatus(testTarget(), net.ParseIP("172.16.0.5"), "abc123")
	for _, want := range []string{"target1 ready", "enp3s0", "172.16.0.5:6665", "172.16.0.11:6666", "nonce=abc123"} {
		if !strings.Contains(got, want) {
			t.Errorf("status %q missing %q", got, want)
		}
	}
}
