package wolrelay

import (
	"bytes"
	"net"
	"strings"
	"testing"
	"time"
)

var (
	mac = net.HardwareAddr{0x88, 0xd7, 0xf6, 0x22, 0x10, 0xfe}
	now = time.Date(2026, 11, 13, 22, 0, 0, 0, time.UTC)
)

func cfg() Config {
	return Config{Allow: "172.16.0.5", MAC: mac, MinDelay: time.Minute, MaxDelay: 15 * time.Minute}
}

func TestMagicPacketIsSixFFThenSixteenMACs(t *testing.T) {
	p := MagicPacket(mac)
	if len(p) != 102 {
		t.Fatalf("len %d", len(p))
	}
	if !bytes.Equal(p[:6], bytes.Repeat([]byte{0xff}, 6)) {
		t.Fatalf("header %x", p[:6])
	}
	for i := 0; i < 16; i++ {
		if !bytes.Equal(p[6+i*6:12+i*6], mac) {
			t.Fatalf("repeat %d: %x", i, p[6+i*6:12+i*6])
		}
	}
}

func TestParseARM(t *testing.T) {
	id, d, err := ParseARM("ARM boot-1 300")
	if err != nil || id != "boot-1" || d != 300*time.Second {
		t.Fatalf("got %q %v %v", id, d, err)
	}
	for _, bad := range []string{"", "ARM", "ARM x", "ARM x y", "WAKE x 300", "ARM x 300 extra", "ARM x -5"} {
		if _, _, err := ParseARM(bad); err == nil {
			t.Fatalf("accepted %q", bad)
		}
	}
}

func TestHandleAcksWithTheWakeTime(t *testing.T) {
	d, err := Handle(cfg(), "172.16.0.5", "ARM b1 300", now)
	if err != nil {
		t.Fatal(err)
	}
	want := now.Add(300 * time.Second)
	if !d.WakeAt.Equal(want) || d.Reply != "ACK b1 "+itoa(want.Unix()) {
		t.Fatalf("decision %+v", d)
	}
}

func itoa(n int64) string {
	b := []byte{}
	if n == 0 {
		return "0"
	}
	for n > 0 {
		b = append([]byte{byte('0' + n%10)}, b...)
		n /= 10
	}
	return string(b)
}

func TestHandleRejectsOtherSourcesAndOutOfRangeDelays(t *testing.T) {
	if _, err := Handle(cfg(), "172.16.0.99", "ARM b1 300", now); err == nil {
		t.Fatal("accepted a foreign source")
	}
	for _, msg := range []string{"ARM b1 10", "ARM b1 100000"} {
		if _, err := Handle(cfg(), "172.16.0.5", msg, now); err == nil {
			t.Fatalf("accepted %q", msg)
		}
	}
}

type fakeNet struct {
	sent      [][]byte
	scheduled []func()
	delays    []time.Duration
	canceled  int
	slept     int
}

func (f *fakeNet) Send(p []byte) error { f.sent = append(f.sent, p); return nil }
func (f *fakeNet) Sleep(time.Duration) { f.slept++ }
func (f *fakeNet) Schedule(d time.Duration, fn func()) (cancel func()) {
	f.scheduled = append(f.scheduled, fn)
	f.delays = append(f.delays, d)
	return func() { f.canceled++ }
}

func TestRelaySchedulesAndSendsABurstOfMagicPackets(t *testing.T) {
	n := &fakeNet{}
	r := &Relay{Config: cfg(), Net: n}
	reply := r.OnPacket("172.16.0.5", "ARM b1 300", now)
	if !strings.HasPrefix(reply, "ACK b1 ") {
		t.Fatalf("reply %q", reply)
	}
	if len(n.scheduled) != 1 || n.delays[0] != 300*time.Second || len(n.sent) != 0 {
		t.Fatalf("scheduled %d delays %v sent %d", len(n.scheduled), n.delays, len(n.sent))
	}
	n.scheduled[0]()
	if len(n.sent) != Burst || !bytes.Equal(n.sent[0], MagicPacket(mac)) {
		t.Fatalf("sent %d", len(n.sent))
	}
}

func TestRelayReplacesAPendingWake(t *testing.T) {
	n := &fakeNet{}
	r := &Relay{Config: cfg(), Net: n}
	r.OnPacket("172.16.0.5", "ARM b1 300", now)
	r.OnPacket("172.16.0.5", "ARM b2 300", now)
	if n.canceled != 1 {
		t.Fatalf("canceled %d", n.canceled)
	}
}

func TestRelayIgnoresInvalidPackets(t *testing.T) {
	n := &fakeNet{}
	r := &Relay{Config: cfg(), Net: n}
	if reply := r.OnPacket("172.16.0.99", "ARM b1 300", now); reply != "" {
		t.Fatalf("replied %q", reply)
	}
	if reply := r.OnPacket("172.16.0.5", "garbage", now); reply != "" {
		t.Fatalf("replied %q", reply)
	}
	if len(n.scheduled) != 0 {
		t.Fatal("scheduled from an invalid packet")
	}
}

func TestWaitReturnsImmediatelyWhenNothingIsPending(t *testing.T) {
	r := &Relay{Config: cfg(), Net: &fakeNet{}}
	done := make(chan struct{})
	go func() { r.Wait(); close(done) }()
	select {
	case <-done:
	case <-time.After(time.Second):
		t.Fatal("Wait blocked with nothing pending")
	}
}

func TestWaitBlocksUntilThePendingWakeIsSent(t *testing.T) {
	n := &fakeNet{}
	r := &Relay{Config: cfg(), Net: n}
	r.OnPacket("172.16.0.5", "ARM b1 300", now)
	done := make(chan struct{})
	go func() { r.Wait(); close(done) }()
	select {
	case <-done:
		t.Fatal("Wait returned before the wake was sent")
	case <-time.After(50 * time.Millisecond):
	}
	n.scheduled[0]()
	select {
	case <-done:
	case <-time.After(time.Second):
		t.Fatal("Wait did not return after the wake was sent")
	}
}

func TestWaitDoesNotHangOnAReplacedWake(t *testing.T) {
	n := &fakeNet{}
	r := &Relay{Config: cfg(), Net: n}
	r.OnPacket("172.16.0.5", "ARM b1 300", now)
	r.OnPacket("172.16.0.5", "ARM b2 300", now)
	done := make(chan struct{})
	go func() { r.Wait(); close(done) }()
	n.scheduled[1]()
	select {
	case <-done:
	case <-time.After(time.Second):
		t.Fatal("Wait hung after a replaced wake")
	}
}
