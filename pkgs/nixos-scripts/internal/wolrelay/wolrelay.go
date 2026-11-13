package wolrelay

import (
	"bytes"
	"fmt"
	"net"
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
	Config Config
	Net    Net

	mu     sync.Mutex
	cancel func()
}

func (r *Relay) OnPacket(src, msg string, now time.Time) string {
	d, err := Handle(r.Config, src, msg, now)
	if err != nil {
		return ""
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	if r.cancel != nil {
		r.cancel()
	}
	r.cancel = r.Net.Schedule(d.WakeAt.Sub(now), r.wake)
	return d.Reply
}

func (r *Relay) wake() {
	packet := MagicPacket(r.Config.MAC)
	for i := 0; i < Burst; i++ {
		if i > 0 {
			r.Net.Sleep(time.Second)
		}
		_ = r.Net.Send(packet)
	}
}
