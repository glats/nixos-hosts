package main

import (
	"context"
	"flag"
	"log"
	"net"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/glats/nixos-scripts/internal/wolrelay"
)

type udpNet struct {
	dest *net.UDPAddr
}

func (u udpNet) Send(p []byte) error {
	conn, err := net.DialUDP("udp", nil, u.dest)
	if err != nil {
		return err
	}
	defer conn.Close()
	_, err = conn.Write(p)
	return err
}

func (udpNet) Sleep(d time.Duration) { time.Sleep(d) }

func (udpNet) Schedule(d time.Duration, fn func()) func() {
	t := time.AfterFunc(d, fn)
	return func() { t.Stop() }
}

func main() {
	listen := flag.String("listen", ":6667", "UDP address that receives ARM requests")
	allow := flag.String("allow", "", "only accept requests from this source IP")
	macStr := flag.String("mac", "", "MAC address to wake")
	broadcast := flag.String("broadcast", "172.16.0.255:9", "broadcast address for the magic packet")
	flag.Parse()

	mac, err := net.ParseMAC(*macStr)
	if err != nil || *allow == "" {
		log.Fatalf("wol-relay: -mac and -allow are required: %v", err)
	}
	dest, err := net.ResolveUDPAddr("udp", *broadcast)
	if err != nil {
		log.Fatalf("wol-relay: broadcast address: %v", err)
	}
	addr, err := net.ResolveUDPAddr("udp", *listen)
	if err != nil {
		log.Fatalf("wol-relay: listen address: %v", err)
	}
	conn, err := net.ListenUDP("udp", addr)
	if err != nil {
		log.Fatalf("wol-relay: bind %s: %v", *listen, err)
	}

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGTERM, os.Interrupt)
	defer stop()
	go func() {
		<-ctx.Done()
		conn.Close()
	}()

	relay := &wolrelay.Relay{
		Config: wolrelay.Config{Allow: *allow, MAC: mac, MinDelay: time.Minute, MaxDelay: 15 * time.Minute},
		Net:    udpNet{dest: dest},
	}
	log.Printf("wol-relay: listening on %s, waking %s via %s for requests from %s", *listen, mac, dest, *allow)

	buf := make([]byte, 512)
	for {
		n, src, err := conn.ReadFromUDP(buf)
		if err != nil {
			if ctx.Err() != nil {
				log.Printf("wol-relay: stopping, waiting for a pending wake before exiting")
				relay.Wait()
				log.Printf("wol-relay: shut down cleanly")
				return
			}
			log.Printf("wol-relay: read: %v", err)
			continue
		}
		reply := relay.OnPacket(src.IP.String(), string(buf[:n]), time.Now())
		if reply == "" {
			log.Printf("wol-relay: ignored %q from %s", string(buf[:n]), src)
			continue
		}
		log.Printf("wol-relay: %q from %s -> %s", string(buf[:n]), src, reply)
		_, _ = conn.WriteToUDP([]byte(reply), src)
	}
}
