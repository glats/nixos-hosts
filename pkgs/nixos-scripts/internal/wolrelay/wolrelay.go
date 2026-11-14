package wolrelay

import (
	"bufio"
	"bytes"
	"fmt"
	"net"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"
)

const Burst = 3

type Config struct {
	Allow    string
	MAC      net.HardwareAddr
	MinDelay time.Duration
	MaxDelay time.Duration
}

type Decision struct {
	Reply  string
	WakeAt time.Time
}

type Net interface {
	Send(packet []byte) error
	Sleep(d time.Duration)
	Schedule(d time.Duration, fn func()) (cancel func())
}

func MagicPacket(mac net.HardwareAddr) []byte {
	p := bytes.Repeat([]byte{0xff}, 6)
	for i := 0; i < 16; i++ {
		p = append(p, mac...)
	}
	return p
}

func ParseARM(msg string) (string, time.Duration, error) {
	f := strings.Fields(msg)
	if len(f) != 3 || f[0] != "ARM" {
		return "", 0, fmt.Errorf("malformed message %q", msg)
	}
	secs, err := strconv.Atoi(f[2])
	if err != nil || secs <= 0 {
		return "", 0, fmt.Errorf("invalid delay %q", f[2])
	}
	return f[1], time.Duration(secs) * time.Second, nil
}

func Handle(cfg Config, src, msg string, now time.Time) (Decision, error) {
	if src != cfg.Allow {
		return Decision{}, fmt.Errorf("source %s not allowed", src)
	}
	id, delay, err := ParseARM(msg)
	if err != nil {
		return Decision{}, err
	}
	if delay < cfg.MinDelay || delay > cfg.MaxDelay {
		return Decision{}, fmt.Errorf("delay %v outside [%v, %v]", delay, cfg.MinDelay, cfg.MaxDelay)
	}
	at := now.Add(delay)
	return Decision{Reply: fmt.Sprintf("ACK %s %d", id, at.Unix()), WakeAt: at}, nil
}

type Relay struct {
	Config    Config
	Net       Net
	StatePath string

	mu        sync.Mutex
	cancel    func()
	pending   chan struct{}
	pendingID string
	pendingAt time.Time
	sent      map[string]int64
	loaded    bool
}

func ParseStatus(msg string) (string, bool) {
	f := strings.Fields(msg)
	if len(f) != 2 || f[0] != "STATUS" {
		return "", false
	}
	return f[1], true
}

func (r *Relay) load() {
	if r.loaded {
		return
	}
	r.loaded = true
	r.sent = map[string]int64{}
	if r.StatePath == "" {
		return
	}
	f, err := os.Open(r.StatePath)
	if err != nil {
		return
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		if p := strings.Fields(sc.Text()); len(p) == 2 {
			if at, err := strconv.ParseInt(p[1], 10, 64); err == nil {
				r.sent[p[0]] = at
			}
		}
	}
}

func (r *Relay) remember(id string, at int64) {
	r.load()
	r.sent[id] = at
	if r.StatePath == "" {
		return
	}
	if f, err := os.OpenFile(r.StatePath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0o644); err == nil {
		fmt.Fprintf(f, "%s %d\n", id, at)
		f.Close()
	}
}

func (r *Relay) status(id string) string {
	r.load()
	if at, ok := r.sent[id]; ok {
		return fmt.Sprintf("SENT %s %d", id, at)
	}
	if r.pending != nil && r.pendingID == id {
		return fmt.Sprintf("PENDING %s %d", id, r.pendingAt.Unix())
	}
	return "UNKNOWN " + id
}

func (r *Relay) OnPacket(src, msg string, now time.Time) string {
	if id, ok := ParseStatus(msg); ok {
		if src != r.Config.Allow {
			return ""
		}
		r.mu.Lock()
		defer r.mu.Unlock()
		return r.status(id)
	}
	d, err := Handle(r.Config, src, msg, now)
	if err != nil {
		return ""
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	if r.cancel != nil {
		r.cancel()
		close(r.pending)
	}
	id, _, _ := ParseARM(msg)
	done := make(chan struct{})
	r.pending, r.pendingID, r.pendingAt = done, id, d.WakeAt
	r.cancel = r.Net.Schedule(d.WakeAt.Sub(now), func() { r.wake(done, id, d.WakeAt) })
	return d.Reply
}

func (r *Relay) Wait() {
	r.mu.Lock()
	done := r.pending
	r.mu.Unlock()
	if done != nil {
		<-done
	}
}

func (r *Relay) wake(done chan struct{}, id string, at time.Time) {
	defer close(done)
	packet := MagicPacket(r.Config.MAC)
	for i := 0; i < Burst; i++ {
		if i > 0 {
			r.Net.Sleep(time.Second)
		}
		_ = r.Net.Send(packet)
	}
	r.mu.Lock()
	r.remember(id, at.Unix())
	if r.pending == done {
		r.pendingID = ""
	}
	r.mu.Unlock()
}
