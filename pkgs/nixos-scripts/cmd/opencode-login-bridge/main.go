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
reaches the opencode CLI's local callback listeners here.

Default ports (OpenCode 2.0.14 + opencode-claude-subscription@0.1.4):
  1455   OpenAI / ChatGPT browser login   (/auth/callback)
  1457   OpenAI fallback port
  53692  Claude Pro/Max subscription     (/callback)
OpenCode Console login is a device flow — no bridge needed.

Flow:
  1. opencode-login-bridge            (this shell)
  2. opencode-home auth login openai      (another shell of this machine)
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
		die("unexpected arguments %q — open the login in a SECOND shell of this machine: opencode-home auth login <provider>", fs.Args())
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

	go func() {
		<-ctx.Done()
		cause <- "Ctrl+C"
		_ = cmd.Process.Kill()
	}()

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
		fmt.Printf("now run in another shell: opencode-home auth login <provider>, then complete the printed authorize URL in %s's browser\n", cfg.host)
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

func closeReason(cause chan string) (string, bool) {
	select {
	case reason := <-cause:
		return reason, true
	default:
		return "", false
	}
}

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

func parseTimeout(spec string) (time.Duration, error) {
	dur, err := time.ParseDuration(spec)
	if err != nil {
		return 0, fmt.Errorf("timeout %q is not a duration (e.g. 15m, 1h, 0s): %w", spec, err)
	}
	return dur, nil
}

func renderPorts(ports []int) string {
	parts := make([]string, len(ports))
	for i, port := range ports {
		parts[i] = fmt.Sprintf(":%d", port)
	}
	return strings.Join(parts, ",")
}
