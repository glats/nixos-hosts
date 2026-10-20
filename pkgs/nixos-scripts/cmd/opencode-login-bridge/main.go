package main

import (
	"context"
	"flag"
	"fmt"
	"net/url"
	"os"
	"os/exec"
	"os/signal"
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/glats/nixos-scripts/internal/sshtunnel"
)

const defaultPorts = "1455,1457,53692"

const usageText = `opencode-login-bridge — SSH reverse-forward bridge for OpenCode OAuth logins

Binds the OAuth callback loopback ports on the account host's ssh alias
(default rog) and forwards every connection back to the same loopback ports
on THIS machine, so an authorize URL completed in the account host's browser
reaches the opencode CLI's local callback listeners here.

Callback ports by login:
  opencode-home auth login openai    OpenCode >= 2.0.32 uses the auth.openai.com
    /api/accounts/authorize flow (client_id=dynamic_agent_client) and picks a
    random 127.0.0.1 callback port per attempt, path /auth/callback (e.g.
    http://127.0.0.1:35929/auth/callback). Copy the printed authorize URL and
    pass it with -url; the bridge forwards exactly that port.
  legacy OpenAI / ChatGPT login      1455, fallback 1457 (/auth/callback)
                                     — covered by default -ports.
  Claude Pro/Max subscription        53692 (/callback) — covered by default -ports.
OpenCode Console login is a device flow — no bridge needed.

Flow (OpenAI, current):
  1. opencode-home auth login openai     (another shell of this machine; it
     prints the https://auth.openai.com/api/accounts/authorize URL with its
     random callback port)
  2. opencode-login-bridge -url '<authorize URL from step 1>'
  3. complete the authorize URL in the account host's browser AFTER the bridge
     is up — the callback only reaches opencode through the bridge.

Flow (Claude or legacy OpenAI):
  1. opencode-login-bridge               (bridges the default ports)
  2. opencode-home auth login <provider>   (another shell of this machine)
  3. complete the printed authorize URL in the account host's browser

Flags:
  -host string    ssh_config alias of the account host   (default "rog")
  -url string     authorize URL printed by the login; the callback port of its
                  redirect_uri parameter is added to the bridge. Repeatable —
                  one -url per login, from any provider whose authorize URL
                  carries redirect_uri (OpenAI today, Claude too, future
                  billing-random-port flows included). Given without -ports it
                  replaces the default port list (the current OpenAI flow picks
                  a new port every attempt). The "bridge up" line names the
                  authorize host of each -url port, so the provider stays
                  visible without per-provider flags.
  -ports string   fixed callback ports to bridge, comma-separated
                  (default "1455,1457,53692")
  -timeout dur    bridge lifetime deadline; 0 = no deadline (default 15m)

SIGINT/SIGTERM close the bridge cleanly (exit 0).
`

type callbackPort struct {
	port          int
	authorizeHost string
}

type config struct {
	host    string
	ports   string
	timeout string
	urls    []string
}

type urlFlag struct {
	urls *[]string
}

func (f urlFlag) String() string {
	if f.urls == nil {
		return ""
	}
	return strings.Join(*f.urls, " ")
}

func (f urlFlag) Set(value string) error {
	if strings.TrimSpace(value) == "" {
		return fmt.Errorf("-url values cannot be empty")
	}
	*f.urls = append(*f.urls, value)
	return nil
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
	fs.StringVar(&cfg.ports, "ports", defaultPorts, "fixed OAuth callback ports to bridge")
	fs.StringVar(&cfg.timeout, "timeout", "15m", "bridge lifetime deadline; 0 = no deadline")
	fs.Var(&urlFlag{urls: &cfg.urls}, "url", "authorize URL printed by the login; its redirect_uri callback port is bridged (repeatable)")

	if err := fs.Parse(os.Args[1:]); err != nil {
		die("%v", err)
	}
	portsExplicit := false
	fs.Visit(func(f *flag.Flag) {
		if f.Name == "ports" {
			portsExplicit = true
		}
	})
	if fs.NArg() > 0 {
		die("unexpected arguments %q — open the login in a SECOND shell of this machine: opencode-home auth login <provider>", fs.Args())
	}
	if err := run(cfg, portsExplicit); err != nil {
		die("%v", err)
	}
}

func run(cfg *config, portsExplicit bool) error {
	sshPath, err := exec.LookPath("ssh")
	if err != nil {
		return fmt.Errorf("'ssh' binary not found in PATH — install openssh")
	}

	ports, err := resolvePorts(portsExplicit, cfg.ports, cfg.urls)
	if err != nil {
		return err
	}
	urlsBridged := len(cfg.urls) > 0
	deadline, err := parseTimeout(cfg.timeout)
	if err != nil {
		return err
	}

	portNumbers := make([]int, 0, len(ports))
	for _, cb := range ports {
		portNumbers = append(portNumbers, cb.port)
	}

	args, err := sshtunnel.BuildBridgeSSHArgs(cfg.host, portNumbers)
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
		if urlsBridged {
			fmt.Printf("now open the authorize URL(s) printed by the login in %s's browser — the callback only reaches opencode through this bridge\n", cfg.host)
		} else {
			fmt.Printf("now run in another shell: opencode-home auth login <provider>, then complete the printed authorize URL in %s's browser\n", cfg.host)
		}
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

func resolvePorts(portsExplicit bool, spec string, urls []string) ([]callbackPort, error) {
	ports := []callbackPort{}
	if portsExplicit || (len(urls) == 0 && spec != "") {
		parsed, err := parsePorts(spec)
		if err != nil {
			return nil, err
		}
		for _, port := range parsed {
			ports = append(ports, callbackPort{port: port})
		}
	}
	for _, raw := range urls {
		port, authorizeHost, err := extractCallbackPort(raw)
		if err != nil {
			return nil, err
		}
		duplicate := false
		for _, seen := range ports {
			if seen.port == port {
				duplicate = true
			}
		}
		if !duplicate {
			ports = append(ports, callbackPort{port: port, authorizeHost: authorizeHost})
		}
	}
	if len(ports) == 0 {
		return nil, fmt.Errorf("no callback ports to bridge — pass -url with the authorize URL printed by the login, or -ports")
	}
	return ports, nil
}

func extractCallbackPort(rawURL string) (int, string, error) {
	parsed, err := url.Parse(strings.TrimSpace(rawURL))
	if err != nil {
		return 0, "", fmt.Errorf("authorize URL %q is not a valid URL: %w", rawURL, err)
	}
	callback := parsed.Query().Get("redirect_uri")
	if callback == "" {
		return 0, "", fmt.Errorf("authorize URL has no redirect_uri parameter to extract a callback port from: %s", parsed)
	}
	callbackURL, err := url.Parse(callback)
	if err != nil {
		return 0, "", fmt.Errorf("authorize URL redirect_uri %q is not a valid callback URL: %w", callback, err)
	}
	port := callbackURL.Port()
	if port == "" {
		return 0, "", fmt.Errorf("authorize URL redirect_uri %q has no port to bridge", callback)
	}
	number, err := strconv.Atoi(port)
	if err != nil || number < 1 || number > 65535 {
		return 0, "", fmt.Errorf("authorize URL redirect_uri %q has an invalid callback port %q", callback, port)
	}
	return number, parsed.Host, nil
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

func renderPorts(ports []callbackPort) string {
	parts := make([]string, len(ports))
	for i, cb := range ports {
		if cb.authorizeHost != "" {
			parts[i] = fmt.Sprintf(":%d (%s)", cb.port, cb.authorizeHost)
		} else {
			parts[i] = fmt.Sprintf(":%d", cb.port)
		}
	}
	return strings.Join(parts, ",")
}
