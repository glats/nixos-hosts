// Command opencode-login-bridge raises a transient SSH reverse-forward
// bridge so OpenCode V2 OAuth logins can complete in the account host's
// browser (default rog) while the OpenCode CLI runs on this machine.
//
// Why: OpenCode's browser OAuth flows bind a loopback callback listener on
// the machine running the CLI, but the browser executing the authorize flow
// lives on another LAN host — rog, where the Claude / ChatGPT / OpenCode
// Console sessions are already signed in. Without a bridge the provider
// redirect (http://localhost:<port>/...) is followed by rog's browser, hits
// rog's own loopback and dies: nothing is listening there. The bridge binds
// the same loopback ports on rog and forwards every connection back through
// the LAN-mesh SSH session to this host, where the opencode2 CLI's callback
// listeners capture the redirect; the token exchange runs from this machine
// directly against the provider endpoints.
//
// Port table (verified against the installed opencode-v2 2.0.14 binary and
// the pinned opencode-claude-subscription@0.1.4 plugin constants):
//
//	1455   OpenAI / ChatGPT browser login  (/auth/callback)
//	1457   OpenAI fallback port tried when 1455 is busy locally
//	53692  Claude Pro/Max subscription browser login (/callback via
//	       opencode-claude-subscription CALLBACK_PARENT 127.0.0.1)
//
// OpenCode Console login is a device flow (verification URL only) and the
// Claude plugin's "paste code" method needs no local port either — both
// work with the bridge up but do not depend on it. Mirror future provider
// changes with -ports instead of an edit.
//
// The CLI binds its local callback listeners BEFORE this bridge matters;
// the bridge binds only on the remote side, so the two never contend for
// the same loopback sockets.
//
// Usage:
//
//	opencode-login-bridge                                      # defaults
//	opencode-login-bridge -host rog -ports 1455,1457,53692 -timeout 15m
//
// With the bridge up, run the login from another shell of the SAME machine:
//
//	opencode2 auth login openai        # zsh wrapper sets the V2 environment
//
// copy the printed authorize URL into the account host's browser, complete
// the login there, and the callback lands on the local listener.
//
// SSH transport rides the LAN mesh: -host must be an ssh_config alias
// (programs.ssh declares rog/thinkcentre/t14/macm5 peers with the dedicated
// id_ed25519_lan identity). BatchMode keeps a failed identity from turning
// into an interactive prompt. Exit semantics match adguard-tunnel:
// SIGINT/SIGTERM or the -timeout deadline (default 15m, 0 = none) tear the
// bridge down — the ssh child dies, the remote forwards unbind — and exit 0;
// an ssh death mid-bridge exits non-zero with a hint.
package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"os/signal"
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/glats/nixos-scripts/internal/sshtunnel"
)

const usageText = `opencode-login-bridge — SSH reverse-forward bridge for OpenCode OAuth logins

Binds the OAuth callback loopback ports on the account host's ssh alias
(default rog) and forwards every connection back to the same loopback ports
on THIS machine, so an authorize URL completed in the account host's browser
reaches the opencode2 CLI's local callback listeners here.

Default ports (opencode-v2 2.0.14 + opencode-claude-subscription@0.1.4):
  1455   OpenAI / ChatGPT browser login   (/auth/callback)
  1457   OpenAI fallback port
  53692  Claude Pro/Max subscription     (/callback)
OpenCode Console login is a device flow — no bridge needed.

Flow:
  1. opencode-login-bridge            (this shell)
  2. opencode2 auth login openai      (another shell of this machine)
  3. complete the printed authorize URL in the account host's browser

Flags:
  -host string    ssh_config alias of the account host   (default "rog")
  -ports string   callback ports to bridge               (default "1455,1457,53692")
  -timeout dur    bridge lifetime deadline; 0 = no deadline (default 15m)

SIGINT/SIGTERM close the bridge cleanly (exit 0).
`

type config struct {
	host    string
	ports   string
	timeout string
}

func die(format string, args ...any) {
	fmt.Fprintf(os.Stderr, "error: "+format+"\n", args...)
	os.Exit(1)
}

func main() {
	cfg := new(config)
	fs := flag.NewFlagSet("opencode-login-bridge", flag.ExitOnError)
	fs.Usage = func() { fmt.Fprint(flag.CommandLine.Output(), usageText) }
	fs.StringVar(&cfg.host, "host", "rog", "ssh_config alias of the account host")
	fs.StringVar(&cfg.ports, "ports", "1455,1457,53692", "OAuth callback ports to bridge")
	fs.StringVar(&cfg.timeout, "timeout", "15m", "bridge lifetime deadline; 0 = no deadline")

	if err := fs.Parse(os.Args[1:]); err != nil {
		die("%v", err)
	}
	if fs.NArg() > 0 {
		die("unexpected arguments %q — open the login in a SECOND shell of this machine: opencode2 auth login <provider>", fs.Args())
	}
	if err := run(cfg); err != nil {
		die("%v", err)
	}
}

// run executes the bridge lifecycle: ssh exec, startup verification, then a
// block until signal, timeout or ssh death.
func run(cfg *config) error {
	sshPath, err := exec.LookPath("ssh")
	if err != nil {
		return fmt.Errorf("'ssh' binary not found in PATH — install openssh")
	}

	ports, err := parsePorts(cfg.ports)
	if err != nil {
		return err
	}
	deadline, err := parseTimeout(cfg.timeout)
	if err != nil {
		return err
	}

	args, err := sshtunnel.BuildBridgeSSHArgs(cfg.host, ports)
	if err != nil {
		return err
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	cause := make(chan string, 2)

	cmd := exec.Command(sshPath, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Start(); err != nil {
		return fmt.Errorf("starting ssh: %w", err)
	}

	done := make(chan error, 1)
	go func() { done <- cmd.Wait() }()

	// Signal watcher records the cause BEFORE killing, so every close path
	// can distinguish a clean teardown (recorded cause) from an unplanned
	// ssh death. exec.Command (not CommandContext) keeps the kill under our
	// sole control; a second Ctrl+C falls back to default handling, matching
	// adguard-tunnel's accepted trade-off.
	go func() {
		<-ctx.Done()
		cause <- "Ctrl+C"
		_ = cmd.Process.Kill()
	}()

	// Startup verification window: a busy remote port (stale twin bridge or
	// a host-local listener) or a rejected identity exits ssh during the
	// handshake thanks to ExitOnForwardFailure — surface it instead of
	// announcing a bridge that never bound.
	select {
	case doneErr := <-done:
		if reason, ok := closeReason(cause); ok {
			fmt.Printf("bridge closed (%s).\n", reason)
			return nil
		}
		if doneErr != nil {
			return fmt.Errorf("bridge start failed — a callback port is already bound on %s (stale bridge? check 'ss -tlnp' there) or the mesh identity was rejected: %v", cfg.host, doneErr)
		}
		fmt.Println("bridge closed.")
		return nil
	case <-time.After(2 * time.Second):
		portList := renderPorts(ports)
		fmt.Printf("bridge up: %s%s (loopback) -> this host\n", cfg.host, portList)
		fmt.Printf("now run in another shell: opencode2 auth login <provider>, then complete the printed authorize URL in %s's browser\n", cfg.host)
		fmt.Printf("Ctrl+C")
		if deadline > 0 {
			fmt.Printf(" or %s deadline", cfg.timeout)
		}
		fmt.Printf(" closes the bridge.\n")
	}

	if deadline > 0 {
		timer := time.NewTimer(deadline)
		defer timer.Stop()
		go func() {
			select {
			case <-timer.C:
				cause <- cfg.timeout + " deadline"
				_ = cmd.Process.Kill()
			case <-ctx.Done():
				// Ctrl+C cause already recorded by its own watcher.
			}
		}()
	}

	if err := <-done; err != nil {
		if reason, ok := closeReason(cause); ok {
			fmt.Printf("bridge closed (%s).\n", reason)
			return nil
		}
		return fmt.Errorf("ssh exited mid-bridge — connection to %s lost or remote listener died; rerun the bridge and the pending login: %v", cfg.host, err)
	}
	fmt.Println("bridge closed.")
	return nil
}

// closeReason reports the recorded teardown cause, if any. Unplanned ssh
// deaths never record one.
func closeReason(cause chan string) (string, bool) {
	select {
	case reason := <-cause:
		return reason, true
	default:
		return "", false
	}
}

// parsePorts turns the comma-separated port list into a validated, de-duped
// port slice preserving order.
func parsePorts(spec string) ([]int, error) {
	fields := strings.FieldsFunc(spec, func(r rune) bool { return r == ',' || r == ' ' })
	if len(fields) == 0 {
		return nil, fmt.Errorf("no callback ports to bridge (ports=%q)", spec)
	}
	ports := make([]int, 0, len(fields))
	for _, field := range fields {
		port, err := strconv.Atoi(field)
		if err != nil {
			return nil, fmt.Errorf("callback port %q is not a number", field)
		}
		if port < 1 || port > 65535 {
			return nil, fmt.Errorf("callback port %d out of range 1..65535", port)
		}
		duplicate := false
		for _, seen := range ports {
			if seen == port {
				duplicate = true
			}
		}
		if !duplicate {
			ports = append(ports, port)
		}
	}
	return ports, nil
}

// parseTimeout resolves the lifetime deadline; 0 means no deadline.
func parseTimeout(spec string) (time.Duration, error) {
	dur, err := time.ParseDuration(spec)
	if err != nil {
		return 0, fmt.Errorf("timeout %q is not a duration (e.g. 15m, 1h, 0s): %w", spec, err)
	}
	return dur, nil
}

// renderPorts prefixes each port with a host:port marker for the summary line.
func renderPorts(ports []int) string {
	parts := make([]string, len(ports))
	for i, port := range ports {
		parts[i] = fmt.Sprintf(":%d", port)
	}
	return strings.Join(parts, ",")
}
