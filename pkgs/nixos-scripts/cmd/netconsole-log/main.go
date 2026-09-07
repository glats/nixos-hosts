// Command netconsole-log is the netconsole UDP receiver on thinkcentre:
// it listens on UDP :6666, durably appends every received line (prefixed
// with its RFC3339 receive timestamp) to a log file under
// /var/log/netconsole/, and ACKs rog's nonce probe markers back to the
// sender so netconsole-setup can verify readiness (2s window on rog).
//
// All framing, nonce and append logic lives in internal/netconsole and is
// covered by unit tests; this entry only parses flags and dispatches.
package main

import (
	"context"
	"flag"
	"log"
	"net"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"

	"github.com/glats/nixos-scripts/internal/netconsole"
)

func main() {
	port := flag.Int("port", 6666, "UDP port to listen on")
	logDir := flag.String("log-dir", "/var/log/netconsole", "directory holding the log file")
	file := flag.String("file", "netconsole.log", "log file name inside -log-dir")
	flag.Parse()

	app := &netconsole.Appender{Path: filepath.Join(*logDir, *file)}

	conn, err := net.ListenUDP("udp", &net.UDPAddr{Port: *port})
	if err != nil {
		log.Fatalf("netconsole-log: bind udp :%d: %v", *port, err)
	}

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGTERM, os.Interrupt)
	defer stop()
	go func() {
		<-ctx.Done()
		conn.Close() // unblocks ReadFromUDP; Serve then returns nil
	}()

	log.Printf("netconsole-log: listening on udp :%d, logging to %s", *port, app.Path)
	if err := netconsole.Serve(ctx, conn, app, func(e error) {
		log.Printf("netconsole-log: %v", e)
	}); err != nil {
		log.Fatalf("netconsole-log: %v", err)
	}
	log.Printf("netconsole-log: shut down cleanly")
}
