// Command adguard-tunnel opens an SSH local port-forward to the AdGuard Home
// web UI on the OnePlus 5 (default 172.16.0.12:3000) and prints the local
// URL to open in a browser.
//
// Why a tunnel: the phone's curated nftables firewall intentionally blocks
// :3000 from the LAN by design (its allowlist permits SSH and DNS only), so
// operator UI access goes through SSH itself — authenticated with the
// dedicated key (default ~/.ssh/oneplus5). SSH key auth IS the access
// control for the admin UI (AdGuard Home runs with authentication disabled).
//
// The forward never touches router or Tailscale port-forwarding: UI traffic
// re-enters only through the operator host's SSH socket pair.
//
// Local port behavior: the requested local port is probed first; if busy
// the helper automatically falls back to requested+10000 (3000 → 13000) and
// announces it on stdout; if both are busy it refuses with a clear error.
//
// Signal handling: SIGINT/SIGTERM tear the forward down (the ssh child is
// killed via CommandContext) and the helper exits 0 — no orphaned ssh
// process. An ssh failure (key rejected, host unreachable) exits non-zero
// with a hint. Deploy/runbook: docs/oneplus5-adguard-dns.md
// ("Operator UI access via SSH tunnel").
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

const usageText = `adguard-tunnel — Operator UI access to AdGuard Home on the OnePlus 5 over SSH

Opens an SSH local port-forward from this machine to the AdGuard Home web UI
(default 172.16.0.12:3000 on the phone) and prints the local URL to open.

Why a tunnel: the phone's nftables firewall intentionally blocks :3000 from
the LAN (SSH and DNS only are allowlisted). SSH key auth is the access
control for this UI — the dedicated key (default ~/.ssh/oneplus5) must have
passwordless access to the phone (see docs/oneplus5-adguard-dns.md).

Flags:
  -host string   destination host (the phone)          (default "172.16.0.12")
  -port int      remote port of the AdGuard Home UI   (default 3000)
  -local int     preferred local listen port          (default 3000)
                 busy → auto-fallback to +10000 (3000 → 13000), announced on stdout
  -user string   SSH user on the phone                (default "glats")
  -key string    SSH identity key path (~ expanded)   (default "~/.ssh/oneplus5")
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
	fs.StringVar(&cfg.host, "host", "172.16.0.12", "destination host (the phone)")
	fs.IntVar(&cfg.remotePort, "port", 3000, "remote port of the AdGuard Home UI")
	fs.IntVar(&cfg.localPort, "local", 3000, "preferred local listen port")
	fs.StringVar(&cfg.user, "user", "glats", "SSH user on the phone")
	fs.StringVar(&cfg.key, "key", "~/.ssh/oneplus5", "SSH identity key path (~ expanded)")
	fs.BoolVar(&cfg.open, "open", false, "open the printed URL with xdg-open")

	if err := fs.Parse(os.Args[1:]); err != nil {
		die("%v", err)
	}
	if err := run(cfg); err != nil {
		die("%v", err)
	}
}

// run executes the tunnel lifecycle: preflight checks, free local port,
// ssh exec, URL print, signal-driven teardown.
func run(cfg *config) error {
	sshPath, err := exec.LookPath("ssh")
	if err != nil {
		return fmt.Errorf("'ssh' binary not found in PATH — install openssh")
	}

	keyPath, err := sshtunnel.ExpandHome(cfg.key)
	if err != nil {
		return err
	}
	if _, err := os.Stat(keyPath); err != nil {
		return fmt.Errorf("SSH key %s not found — generate/distribute it per docs/oneplus5-adguard-dns.md (prerequisites)", cfg.key)
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
	fmt.Printf("tunnel up: %s -> %s:%d (ssh -i %s %s@%s)\n", url, cfg.host, cfg.remotePort, keyPath, cfg.user, cfg.host)
	fmt.Printf("Press Ctrl+C to stop.\n")
	if cfg.open {
		if xdg, lookErr := exec.LookPath("xdg-open"); lookErr == nil {
			_ = exec.Command(xdg, url).Start() // fire-and-forget; failures don't kill the tunnel
		}
	}

	// SIGINT/SIGTERM cancel the context; the watcher kills ssh, so the
	// forward is torn down and we exit 0 cleanly.
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	go func() {
		<-ctx.Done()
		stop() // restore default signal handling for a second Ctrl+C
		_ = cmd.Process.Kill()
	}()

	if err := cmd.Wait(); err != nil {
		select {
		case <-ctx.Done():
			// We caused the termination ourselves — exit cleanly.
			return nil
		default:
			return fmt.Errorf("ssh exited with error — phone unreachable or key not authorized? see docs/oneplus5-adguard-dns.md")
		}
	}
	fmt.Println("tunnel stopped.")
	return nil
}
