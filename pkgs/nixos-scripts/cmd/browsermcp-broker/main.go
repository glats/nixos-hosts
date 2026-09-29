package main

import (
	"context"
	"flag"
	"log"
	"os"
	"os/signal"
	"syscall"

	"github.com/glats/nixos-scripts/internal/browsermcp"
)

func main() {
	child := flag.String("child", "", "path to mcp-server-browsermcp")
	port := flag.Int("port", 9010, "loopback HTTP port")
	flag.Parse()
	if *child == "" {
		log.Fatal("browsermcp-broker: --child is required")
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	if err := browsermcp.Run(ctx, browsermcp.Config{Child: []string{*child}, Port: *port}); err != nil {
		if browsermcp.IsPortInUse(err) {
			log.Print(err)
			os.Exit(78)
		}
		log.Fatal(err)
	}
}
