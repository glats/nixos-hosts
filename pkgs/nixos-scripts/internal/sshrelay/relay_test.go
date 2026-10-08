package sshrelay

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"
)

type fakeLauncher struct {
	mu           sync.Mutex
	loaded       bool
	commands     []string
	block        <-chan struct{}
	blockPrint   <-chan struct{}
	blockBootout <-chan struct{}
	printStarted chan struct{}
	bootStarted  chan struct{}
	printErr     error
	bootErr      error
}

func (f *fakeLauncher) Bootstrap(context.Context, string, string) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.commands = append(f.commands, "bootstrap")
	f.loaded = true
	return nil
}
func (f *fakeLauncher) Kickstart(ctx context.Context, _ string) error {
	f.mu.Lock()
	f.commands = append(f.commands, "kickstart")
	f.mu.Unlock()
	if f.block != nil {
		select {
		case <-f.block:
		case <-ctx.Done():
			return ctx.Err()
		}
	}
	return nil
}
func (f *fakeLauncher) Bootout(ctx context.Context, _ string) error {
	f.mu.Lock()
	f.commands = append(f.commands, "bootout")
	if f.bootStarted != nil {
		close(f.bootStarted)
	}
	f.mu.Unlock()
	if f.blockBootout != nil {
		select {
		case <-f.blockBootout:
		case <-ctx.Done():
			return ctx.Err()
		}
	}
	f.mu.Lock()
	defer f.mu.Unlock()
	f.loaded = false
	return f.bootErr
}
func (f *fakeLauncher) Print(ctx context.Context, _ string) (string, error) {
	// The real launcher is context-bound; use a separate channel to exercise
	// bounded status without making every fake operation block.
	if f.blockPrint != nil {
		if f.printStarted != nil {
			close(f.printStarted)
			f.printStarted = nil
		}
		select {
		case <-f.blockPrint:
		case <-ctx.Done():
			return "", ctx.Err()
		}
	}
	f.mu.Lock()
	defer f.mu.Unlock()
	f.commands = append(f.commands, "print")
	if f.printErr != nil {
		return "", f.printErr
	}
	if !f.loaded {
		return "", ErrNotLoaded
	}
	return "pid = 42\n", nil
}
func (f *fakeLauncher) calls() []string {
	f.mu.Lock()
	defer f.mu.Unlock()
	return append([]string(nil), f.commands...)
}

func newTestController(t *testing.T, f *fakeLauncher) *Controller {
	t.Helper()
	c, err := New(Config{StateDir: t.TempDir(), PlistPath: "/tmp/relay.plist", Label: DefaultLabel, OnTimeout: 100 * time.Millisecond, OffTimeout: 100 * time.Millisecond, StatusTimeout: 50 * time.Millisecond}, f)
	if err != nil {
		t.Fatal(err)
	}
	return c
}

func TestOnUsesLaunchdOnceAndPersistsIntent(t *testing.T) {
	f := &fakeLauncher{}
	c := newTestController(t, f)
	if err := c.On(context.Background()); err != nil {
		t.Fatal(err)
	}
	if err := c.On(context.Background()); err != nil {
		t.Fatal(err)
	}
	want := []string{"print", "bootstrap", "kickstart", "print", "kickstart"}
	if got := f.calls(); !equalStrings(got, want) {
		t.Fatalf("calls = %v, want %v", got, want)
	}
	b, err := os.ReadFile(filepath.Join(c.config.StateDir, "state.json"))
	if err != nil {
		t.Fatal(err)
	}
	if string(b) == "" || !contains(string(b), `"enabled":true`) {
		t.Fatalf("state does not persist enabled intent: %s", b)
	}
	st, err := c.readState()
	if err != nil {
		t.Fatal(err)
	}
	if st.Generation != 2 {
		t.Fatalf("generation = %d, want 2", st.Generation)
	}
}

func TestOffSerializesBootoutBeforeNewOn(t *testing.T) {
	release := make(chan struct{})
	f := &fakeLauncher{
		loaded:       true,
		blockBootout: release,
		bootStarted:  make(chan struct{}),
	}
	cfg := Config{
		StateDir:      t.TempDir(),
		PlistPath:     "/tmp/relay.plist",
		Label:         DefaultLabel,
		OnTimeout:     time.Second,
		OffTimeout:    time.Second,
		StatusTimeout: time.Second,
	}
	c, err := New(cfg, f)
	if err != nil {
		t.Fatal(err)
	}
	if err := c.writeState(state{Enabled: true, Generation: 1}); err != nil {
		t.Fatal(err)
	}
	offDone := make(chan error, 1)
	go func() { offDone <- c.Off(context.Background()) }()
	select {
	case <-f.bootStarted:
	case <-time.After(time.Second):
		t.Fatal("off did not reach bootout")
	}

	onDone := make(chan error, 1)
	go func() { onDone <- c.On(context.Background()) }()
	select {
	case err := <-onDone:
		t.Fatalf("on completed before off bootout: %v", err)
	case <-time.After(50 * time.Millisecond):
	}
	close(release)
	if err := <-offDone; err != nil {
		t.Fatalf("off: %v", err)
	}
	if err := <-onDone; err != nil {
		t.Fatalf("on: %v", err)
	}

	calls := f.calls()
	bootout := indexOf(calls, "bootout")
	kickstart := lastIndexOf(calls, "kickstart")
	if bootout < 0 || kickstart < 0 || bootout > kickstart {
		t.Fatalf("launch order = %v, want bootout before new kickstart", calls)
	}
}

func TestOffDisablesIntentBeforeStoppingAndIsIdempotent(t *testing.T) {
	f := &fakeLauncher{loaded: true}
	c := newTestController(t, f)
	if err := c.On(context.Background()); err != nil {
		t.Fatal(err)
	}
	if err := c.Off(context.Background()); err != nil {
		t.Fatal(err)
	}
	f.bootErr = ErrNotLoaded
	if err := c.Off(context.Background()); err != nil {
		t.Fatal(err)
	}
	st, err := c.readState()
	if err != nil {
		t.Fatal(err)
	}
	if st.Enabled {
		t.Fatal("off left enabled intent")
	}
}

func TestOffCancelsAStuckLaunchOperationWithinBound(t *testing.T) {
	block := make(chan struct{})
	f := &fakeLauncher{block: block}
	c := newTestController(t, f)
	started := make(chan error, 1)
	go func() { started <- c.On(context.Background()) }()
	select {
	case err := <-started:
		if !errors.Is(err, context.DeadlineExceeded) {
			t.Fatalf("on error = %v", err)
		}
	case <-time.After(time.Second):
		t.Fatal("on exceeded test bound")
	}
	if err := c.Off(context.Background()); err != nil {
		t.Fatal(err)
	}
	st, err := c.readState()
	if err != nil {
		t.Fatal(err)
	}
	if st.Enabled {
		t.Fatal("off did not clear intent after stuck child operation")
	}
}

func TestStatusIsBoundedAndDoesNotClaimRelayOrSSH(t *testing.T) {
	block := make(chan struct{})
	f := &fakeLauncher{loaded: true, blockPrint: block}
	c := newTestController(t, f)
	if err := c.writeState(state{Enabled: true, Generation: 1}); err != nil {
		t.Fatal(err)
	}
	start := time.Now()
	status, err := c.Status(context.Background())
	if !errors.Is(err, context.DeadlineExceeded) {
		t.Fatalf("status error = %v", err)
	}
	if time.Since(start) > 500*time.Millisecond {
		t.Fatal("status exceeded bounded test deadline")
	}
	if status.Relay != "unknown" || status.SSH != "unknown" {
		t.Fatalf("status overclaimed evidence: %+v", status)
	}
}

func TestLaunchdPIDParsing(t *testing.T) {
	if got := launchdPID("state = running\npid = 123\n"); got != "123" {
		t.Fatalf("pid = %q", got)
	}
	if got := launchdPID("state = running\n"); got != "unknown" {
		t.Fatalf("missing pid = %q", got)
	}
}

func TestClientArgsFixDestinationAndKeepCredentialOutOfArgv(t *testing.T) {
	args, err := ClientArgs("/nix/store/wstunnel/bin/wstunnel", "/run/secrets/ssh-relay-headers", 22220)
	if err != nil {
		t.Fatal(err)
	}
	joined := strings.Join(args, " ")
	if !contains(joined, "tcp://127.0.0.1:22220:127.0.0.1:22") {
		t.Fatalf("args do not fix the trusted Mac destination: %v", args)
	}
	for _, want := range []string{
		"--tls-verify-certificate",
		"--http-headers-file /run/secrets/ssh-relay-headers",
		"--reverse-tunnel-connection-retry-max-backoff 60s",
		"--connection-retry-max-backoff 20s",
		"--log-lvl off",
		"wss://relay.glats.org:443",
	} {
		if !contains(joined, want) {
			t.Fatalf("missing fixed argument %q: %v", want, args)
		}
	}
	if contains(joined, "AUTH") || contains(joined, "password") {
		t.Fatalf("credential-like value leaked into argv: %v", args)
	}
	if _, err := ClientArgs("wstunnel", "/run/secrets/headers", 22220); err == nil {
		t.Fatal("relative wstunnel path accepted")
	}
}

func TestSanitizedEnvironmentUsesOnlyManagedPlatformValues(t *testing.T) {
	got := SanitizedEnvironment([]string{
		"HOME=/Users/juan",
		"PATH=/usr/bin",
		"TMPDIR=/private/var/folders/tmp",
		"SSLKEYLOGFILE=/tmp/tls.keys",
		"SSL_CERT_FILE=/tmp/ca.pem",
		"HTTP_PROXY=http://attacker.invalid",
		"HTTPS_PROXY=http://attacker.invalid",
		"ALL_PROXY=http://attacker.invalid",
		"WSTUNNEL_LOG_LVL=debug",
		"RUST_LOG=debug",
		"AUTH=credential",
		"HOME=/duplicate",
	})
	want := []string{"HOME=/Users/juan", "TMPDIR=/private/var/folders/tmp"}
	if strings.Join(got, "\x00") != strings.Join(want, "\x00") {
		t.Fatalf("sanitized environment = %q, want %q", got, want)
	}
}

func TestValidateHeaderFileRequiresOwned0600RegularFile(t *testing.T) {
	path := filepath.Join(t.TempDir(), "headers")
	if err := os.WriteFile(path, []byte("Authorization: Basic synthetic\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := ValidateHeaderFile(path); err != nil {
		t.Fatalf("valid header file rejected: %v", err)
	}
	if err := os.Chmod(path, 0o644); err != nil {
		t.Fatal(err)
	}
	if err := ValidateHeaderFile(path); err == nil {
		t.Fatal("world-readable header file accepted")
	}
	if err := os.Symlink(path, path+"-link"); err != nil {
		t.Fatal(err)
	}
	if err := ValidateHeaderFile(path + "-link"); err == nil {
		t.Fatal("symlink header file accepted")
	}

	storeLink := filepath.Join(t.TempDir(), "store-link")
	if err := os.Symlink("/nix/store", storeLink); err != nil {
		t.Fatal(err)
	}
	if err := ValidateHeaderFile(filepath.Join(storeLink, "missing-headers")); err == nil {
		t.Fatal("header path resolving into the Nix store accepted")
	}
}

func TestCommandLauncherTreatsLaunchctlExitThreeAsNotLoaded(t *testing.T) {
	path := filepath.Join(t.TempDir(), "launchctl")
	if err := os.WriteFile(path, []byte("#!/bin/sh\nexit 3\n"), 0o700); err != nil {
		t.Fatal(err)
	}
	_, err := (CommandLauncher{Path: path}).Print(context.Background(), "gui/1/org.nixos.ssh-relay")
	if !errors.Is(err, ErrNotLoaded) {
		t.Fatalf("error = %v, want ErrNotLoaded", err)
	}
}

func TestSeparateProcessesCannotRestartSupersededOn(t *testing.T) {
	stateDir := t.TempDir()
	ready := filepath.Join(stateDir, "print-ready")
	release := filepath.Join(stateDir, "print-release")
	calls := filepath.Join(stateDir, "launchctl-calls")
	launchctl := writeLaunchctlFixture(t, ready, release, calls)

	on := startRelayHelper(t, "on", stateDir, launchctl)
	if err := on.Start(); err != nil {
		t.Fatal(err)
	}
	waitForFile(t, ready)
	off := startRelayHelper(t, "off", stateDir, launchctl)
	if err := off.Run(); err != nil {
		t.Fatalf("off helper: %v", err)
	}
	if err := os.WriteFile(release, []byte("release\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := on.Wait(); err != nil {
		t.Fatalf("superseded on helper: %v", err)
	}
	data, err := os.ReadFile(calls)
	if err != nil {
		t.Fatal(err)
	}
	log := string(data)
	if !strings.Contains(log, "bootout") || strings.Contains(log, "bootstrap") || strings.Contains(log, "kickstart") {
		t.Fatalf("stale on launched after off: %q", log)
	}
	st := readTestState(t, stateDir)
	if st.Enabled {
		t.Fatal("superseded on restored enabled intent")
	}
	if err := startRelayHelper(t, "on", stateDir, launchctl).Run(); err != nil {
		t.Fatalf("later on helper: %v", err)
	}
	data, err = os.ReadFile(calls)
	if err != nil {
		t.Fatal(err)
	}
	log = string(data)
	if !strings.Contains(log, "bootstrap") || !strings.Contains(log, "kickstart") {
		t.Fatalf("later on was incorrectly suppressed: %q", log)
	}
	if st = readTestState(t, stateDir); !st.Enabled {
		t.Fatal("later on did not restore enabled intent")
	}
}

func TestOffBootsOutWhenStateIsMalformed(t *testing.T) {
	f := &fakeLauncher{}
	c := newTestController(t, f)
	if err := os.WriteFile(c.statePath(), []byte("{"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := c.Off(context.Background()); err == nil {
		t.Fatal("malformed state unexpectedly returned success")
	}
	if !contains(strings.Join(f.calls(), " "), "bootout") {
		t.Fatalf("malformed state skipped bootout: %v", f.calls())
	}
}

func TestOffBootsOutWhenStateReplacementFails(t *testing.T) {
	f := &fakeLauncher{loaded: true}
	c := newTestController(t, f)
	if err := c.On(context.Background()); err != nil {
		t.Fatal(err)
	}
	if err := os.Chmod(c.config.StateDir, 0o500); err != nil {
		t.Fatal(err)
	}
	defer os.Chmod(c.config.StateDir, 0o700)
	if err := c.Off(context.Background()); err == nil {
		t.Fatal("state replacement failure unexpectedly returned success")
	}
	if !contains(strings.Join(f.calls(), " "), "bootout") {
		t.Fatalf("state replacement failure skipped bootout: %v", f.calls())
	}
}

func TestCanceledMutationsDoNotTouchIntentOrLaunch(t *testing.T) {
	f := &fakeLauncher{}
	c := newTestController(t, f)
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	if err := c.On(ctx); !errors.Is(err, context.Canceled) {
		t.Fatalf("canceled on error = %v", err)
	}
	if err := c.Off(ctx); !errors.Is(err, context.Canceled) {
		t.Fatalf("canceled off error = %v", err)
	}
	if _, err := os.Stat(c.statePath()); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("canceled mutation changed state: %v", err)
	}
	if calls := f.calls(); len(calls) != 0 {
		t.Fatalf("canceled mutation launched commands: %v", calls)
	}
}

func TestRelayHelperProcess(t *testing.T) {
	if os.Getenv("SSHRELAY_HELPER") != "1" {
		return
	}
	c, err := New(Config{StateDir: os.Getenv("SSHRELAY_STATE_DIR"), PlistPath: "/tmp/relay.plist", Label: DefaultLabel, OnTimeout: 2 * time.Second, OffTimeout: 2 * time.Second}, CommandLauncher{Path: os.Getenv("SSHRELAY_LAUNCHCTL")})
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(2)
	}
	var runErr error
	if os.Getenv("SSHRELAY_HELPER_ACTION") == "on" {
		runErr = c.On(context.Background())
		if errors.Is(runErr, ErrSuperseded) {
			runErr = nil
		}
	} else {
		runErr = c.Off(context.Background())
	}
	if runErr != nil {
		fmt.Fprintln(os.Stderr, runErr)
		os.Exit(1)
	}
	os.Exit(0)
}

func startRelayHelper(t *testing.T, action, stateDir, launchctl string) *exec.Cmd {
	t.Helper()
	cmd := exec.Command(os.Args[0], "-test.run=TestRelayHelperProcess", "--")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Env = append(os.Environ(), "SSHRELAY_HELPER=1", "SSHRELAY_HELPER_ACTION="+action, "SSHRELAY_STATE_DIR="+stateDir, "SSHRELAY_LAUNCHCTL="+launchctl)
	return cmd
}

func writeLaunchctlFixture(t *testing.T, ready, release, calls string) string {
	t.Helper()
	path := filepath.Join(t.TempDir(), "launchctl")
	script := fmt.Sprintf("#!/bin/sh\nprintf '%%s\\n' \"$1\" >> %q\ncase \"$1\" in\nprint) touch %q; while [ ! -f %q ]; do sleep 0.01; done; exit 3;;\nbootout) exit 0;;\n*) exit 0;;\nesac\n", calls, ready, release)
	if err := os.WriteFile(path, []byte(script), 0o700); err != nil {
		t.Fatal(err)
	}
	return path
}

func waitForFile(t *testing.T, path string) {
	t.Helper()
	deadline := time.Now().Add(2 * time.Second)
	for time.Now().Before(deadline) {
		if _, err := os.Stat(path); err == nil {
			return
		}
		time.Sleep(10 * time.Millisecond)
	}
	t.Fatalf("timed out waiting for %s", path)
}

func readTestState(t *testing.T, dir string) state {
	t.Helper()
	b, err := os.ReadFile(filepath.Join(dir, "state.json"))
	if err != nil {
		t.Fatal(err)
	}
	var st state
	if err := json.Unmarshal(b, &st); err != nil {
		t.Fatal(err)
	}
	return st
}

func indexOf(values []string, want string) int {
	for i, value := range values {
		if value == want {
			return i
		}
	}
	return -1
}

func lastIndexOf(values []string, want string) int {
	for i := len(values) - 1; i >= 0; i-- {
		if values[i] == want {
			return i
		}
	}
	return -1
}

func equalStrings(a, b []string) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}
func contains(s, sub string) bool { return len(s) >= len(sub) && strings.Contains(s, sub) }
