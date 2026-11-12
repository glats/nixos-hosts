package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"os/signal"
	"syscall"

	"github.com/glats/nixos-scripts/internal/sshtunnel"
)

const usageText = `adguard-tunnel — Operator UI access to AdGuard Home on Samsung over SSH

Opens an SSH local port-forward from this machine to the AdGuard Home web UI
(127.0.0.1:3000 on Samsung) and prints the local URL to open.

Why a tunnel: the panel listens only on remote loopback. SSH authentication
controls access. By default, SSH uses your normal configuration and agent;
use -key to override the identity (see docs/samsung-adguard-dns.md).

Flags:
  -host string   destination SSH host                  (default "samsung.lan")
  -port int      remote port of the AdGuard Home UI   (default 3000)
  -local int     preferred local listen port          (default 3000)
                 busy → auto-fallback to +10000 (3000 → 13000), announced on stdout
  -user string   SSH user                             (default "glats")
  -key string    optional SSH identity (~ expanded)   (default: SSH configuration)
  -open          open the printed URL with xdg-open once the tunnel is up

Press Ctrl+C to stop; the forward is torn down cleanly.
`

type config struct {
	host       string
	remotePort int
	localPort  int
	user       string
	key        string
	open       bool
}

func die(format string, args ...any) {
	fmt.Fprintf(os.Stderr, "error: "+format+"\n", args...)
	os.Exit(1)
}

func main() {
	cfg := new(config)
	fs := flag.NewFlagSet("adguard-tunnel", flag.ExitOnError)
	fs.Usage = func() { fmt.Fprint(flag.CommandLine.Output(), usageText) }
	fs.StringVar(&cfg.host, "host", "samsung.lan", "destination SSH host")
	fs.IntVar(&cfg.remotePort, "port", 3000, "remote port of the AdGuard Home UI")
	fs.IntVar(&cfg.localPort, "local", 3000, "preferred local listen port")
	fs.StringVar(&cfg.user, "user", "glats", "SSH user")
	fs.StringVar(&cfg.key, "key", "", "optional SSH identity key path (~ expanded)")
	fs.BoolVar(&cfg.open, "open", false, "open the printed URL with xdg-open")

	if err := fs.Parse(os.Args[1:]); err != nil {
		die("%v", err)
	}
	if err := run(cfg); err != nil {
		die("%v", err)
	}
}

func run(cfg *config) error {
	sshPath, err := exec.LookPath("ssh")
	if err != nil {
		return fmt.Errorf("'ssh' binary not found in PATH — install openssh")
	}

	var keyPath string
	if cfg.key != "" {
		keyPath, err = sshtunnel.ExpandHome(cfg.key)
		if err != nil {
			return err
		}
		if _, err := os.Stat(keyPath); err != nil {
			return fmt.Errorf("SSH key %s not found — see docs/samsung-adguard-dns.md", cfg.key)
		}
	}

	chosen, fellBack, err := sshtunnel.PickFreePort(cfg.localPort)
	if err != nil {
		return err
	}
	if fellBack {
		fmt.Printf("note: local port %d busy — using fallback port %d instead\n", cfg.localPort, chosen)
	}

	args := sshtunnel.BuildSSHArgs(cfg.host, cfg.user, keyPath, chosen, cfg.remotePort)
	cmd := exec.CommandContext(context.Background(), sshPath, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Start(); err != nil {
		return fmt.Errorf("starting ssh: %w", err)
	}

	url := sshtunnel.LocalURL(chosen)
	identity := ""
	if keyPath != "" {
		identity = fmt.Sprintf("-i %s ", keyPath)
	}
	fmt.Printf("tunnel up: %s -> 127.0.0.1:%d (ssh %s%s@%s)\n", url, cfg.remotePort, identity, cfg.user, cfg.host)
	fmt.Printf("Press Ctrl+C to stop.\n")
	if cfg.open {
		if xdg, lookErr := exec.LookPath("xdg-open"); lookErr == nil {
			_ = exec.Command(xdg, url).Start()
		}
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	go func() {
		<-ctx.Done()
		stop()
		_ = cmd.Process.Kill()
	}()

	if err := cmd.Wait(); err != nil {
		select {
		case <-ctx.Done():

			return nil
		default:
			return fmt.Errorf("ssh exited with error — host unreachable or key not authorized? see docs/samsung-adguard-dns.md")
		}
	}
	fmt.Println("tunnel stopped.")
	return nil
}
