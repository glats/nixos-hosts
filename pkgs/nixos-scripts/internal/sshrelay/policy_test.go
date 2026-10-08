package sshrelay

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"
)

type fakePolicyCommand struct {
	mu       sync.Mutex
	state    string
	commands []string
	startErr error
}

type reviewCommand struct {
	run func(context.Context, ...string) (string, error)
}

func (c reviewCommand) Run(ctx context.Context, args ...string) (string, error) {
	return c.run(ctx, args...)
}

func (f *fakePolicyCommand) Run(_ context.Context, args ...string) (string, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.commands = append(f.commands, strings.Join(args, " "))
	switch args[0] {
	case "is-enabled":
		return f.state, nil
	case "is-active":
		return "inactive", nil
	case "show":
		return "masked\ninactive\n0\n", nil
	case "start":
		return "", f.startErr
	default:
		return "", nil
	}
}

func testPolicyTransaction(t *testing.T, command *fakePolicyCommand) (*policyTransaction, string, string) {
	t.Helper()
	root := t.TempDir()
	stage := filepath.Join(root, "stage")
	live := filepath.Join(root, "live", "restrictions.yaml")
	runtime := filepath.Join(root, "runtime")
	state := filepath.Join(runtime, "state")
	if err := os.MkdirAll(filepath.Dir(stage), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(stage, []byte("A-token_0123456789abcdefghijklmnop\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.Chmod(stage, 0o600); err != nil {
		t.Fatal(err)
	}
	uid := uint32(os.Getuid())
	gid := uint32(os.Getgid())
	return &policyTransaction{
		command:        command,
		service:        PolicyService,
		stagePath:      stage,
		livePath:       live,
		runtimeDir:     runtime,
		stateDir:       state,
		runtimeOwner:   uid,
		stageOwner:     uid,
		stateOwner:     uid,
		directoryOwner: uid,
		policyOwner:    uid,
		policyGroup:    gid,
		commandLimit:   time.Second,
		stopWaitLimit:  time.Second,
		cleanupLimit:   time.Second,
	}, stage, live
}

func TestPolicyApplyStopsBeforePromotionAndRestartsOnlyEnabledService(t *testing.T) {
	command := &fakePolicyCommand{state: "enabled"}
	tx, _, live := testPolicyTransaction(t, command)
	if err := tx.Apply(context.Background()); err != nil {
		t.Fatal(err)
	}
	contents, err := os.ReadFile(live)
	if err != nil {
		t.Fatal(err)
	}
	text := string(contents)
	if !strings.Contains(text, "!Authorization \"^Bearer A-token_0123456789abcdefghijklmnop$\"") {
		t.Fatalf("policy does not contain the fixed authorization matcher: %q", text)
	}
	if !strings.Contains(text, "!ReverseTunnel") || !strings.Contains(text, "127.0.0.1/32") {
		t.Fatalf("policy does not contain the fixed reverse-tunnel allowance: %q", text)
	}
	if mode := contentsMode(t, live); mode != 0o600 {
		t.Fatalf("live policy mode = %o, want 600", mode)
	}
	joined := strings.Join(command.commands, "\n")
	if strings.Index(joined, "mask --runtime --now") > strings.Index(joined, "unmask --runtime") {
		t.Fatalf("service was unmasked before it was masked: %v", command.commands)
	}
	if strings.Index(joined, "start "+PolicyService) < strings.Index(joined, "unmask --runtime") {
		t.Fatalf("service started before policy promotion: %v", command.commands)
	}
}

func TestPolicyApplyInvalidStagedTokenFailsStoppedWithoutPromotion(t *testing.T) {
	command := &fakePolicyCommand{state: "enabled"}
	tx, stage, live := testPolicyTransaction(t, command)
	if err := os.WriteFile(stage, []byte("bad token\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	err := tx.Apply(context.Background())
	if err == nil || (!strings.Contains(err.Error(), "invalid characters") && !strings.Contains(err.Error(), "invalid length")) {
		t.Fatalf("Apply error = %v, want invalid token", err)
	}
	if _, err := os.Stat(live); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("live policy exists after failed validation: %v", err)
	}
	for _, invocation := range command.commands {
		if strings.HasPrefix(invocation, "unmask ") || strings.HasPrefix(invocation, "start ") {
			t.Fatalf("failed transaction changed service state: %v", command.commands)
		}
	}
}

func TestPolicyApplyStartFailureRemainsMasked(t *testing.T) {
	command := &fakePolicyCommand{state: "enabled", startErr: errors.New("start failed")}
	tx, _, live := testPolicyTransaction(t, command)
	if err := tx.Apply(context.Background()); err == nil {
		t.Fatal("Apply succeeded despite start failure")
	}
	if _, err := os.Stat(live); err != nil {
		t.Fatalf("policy was not promoted before start: %v", err)
	}
	if countCommand(command.commands, "mask --runtime --now ") < 2 {
		t.Fatalf("commands = %v, want a compensating fail-stop mask", command.commands)
	}
}

func TestPolicyRevokeInstallsDenyAllAndLeavesServiceMasked(t *testing.T) {
	command := &fakePolicyCommand{state: "enabled"}
	tx, _, live := testPolicyTransaction(t, command)
	if err := tx.Revoke(context.Background()); err != nil {
		t.Fatal(err)
	}
	contents, err := os.ReadFile(live)
	if err != nil {
		t.Fatal(err)
	}
	if string(contents) != "restrictions: []\n" {
		t.Fatalf("revocation policy = %q", contents)
	}
	for _, invocation := range command.commands {
		if strings.HasPrefix(invocation, "unmask ") || strings.HasPrefix(invocation, "start ") {
			t.Fatalf("revocation restarted service: %v", command.commands)
		}
	}
}

func contentsMode(t *testing.T, path string) os.FileMode {
	t.Helper()
	info, err := os.Stat(path)
	if err != nil {
		t.Fatal(err)
	}
	return info.Mode().Perm()
}

func countCommand(commands []string, prefix string) int {
	count := 0
	for _, command := range commands {
		if strings.HasPrefix(command, prefix) {
			count++
		}
	}
	return count
}

func TestPolicyApplyRemasksWhenUnmaskFails(t *testing.T) {
	tx, _, _ := testPolicyTransaction(t, &fakePolicyCommand{state: "enabled"})
	masked, maskCalls := false, 0
	tx.command = reviewCommand{run: func(_ context.Context, args ...string) (string, error) {
		switch args[0] {
		case "is-enabled":
			return "enabled", nil
		case "is-active":
			return "inactive", nil
		case "show":
			return "masked\ninactive\n0\n", nil
		case "mask":
			masked, maskCalls = true, maskCalls+1
		case "unmask":
			masked = false
			return "", errors.New("partial unmask failure")
		}
		return "", nil
	}}
	if err := tx.Apply(context.Background()); err == nil {
		t.Fatal("Apply succeeded despite unmask failure")
	}
	if !masked || maskCalls != 2 {
		t.Fatalf("masked=%v maskCalls=%d, want a verified compensating remask", masked, maskCalls)
	}
}

func TestPolicyApplyUsesIndependentCleanupContextAfterCancellation(t *testing.T) {
	tx, _, _ := testPolicyTransaction(t, &fakePolicyCommand{state: "enabled"})
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	masked, cleanupBlocked := false, false
	tx.command = reviewCommand{run: func(ctx context.Context, args ...string) (string, error) {
		if ctx.Err() != nil {
			if args[0] == "mask" {
				cleanupBlocked = true
			}
			return "", ctx.Err()
		}
		switch args[0] {
		case "is-enabled":
			return "enabled", nil
		case "is-active", "show":
			return map[string]string{"is-active": "inactive", "show": "masked\ninactive\n0\n"}[args[0]], nil
		case "mask":
			masked = true
		case "unmask":
			masked = false
		case "start":
			cancel()
			return "", errors.New("start failed")
		}
		return "", nil
	}}
	if err := tx.Apply(ctx); err == nil {
		t.Fatal("Apply succeeded despite canceled start")
	}
	if !masked || cleanupBlocked {
		t.Fatalf("masked=%v cleanupBlocked=%v, want independent fail-stop cleanup", masked, cleanupBlocked)
	}
}

func TestPolicyRejectsWritableAndSymlinkAncestors(t *testing.T) {
	tx, stage, _ := testPolicyTransaction(t, &fakePolicyCommand{state: "disabled"})
	root := t.TempDir()
	writable := filepath.Join(root, "writable")
	trusted := filepath.Join(writable, "trusted")
	if err := os.MkdirAll(trusted, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.Chmod(writable, 0o777); err != nil {
		t.Fatal(err)
	}
	token, err := os.ReadFile(stage)
	if err != nil {
		t.Fatal(err)
	}
	path := filepath.Join(trusted, "token")
	if err := os.WriteFile(path, token, 0o600); err != nil {
		t.Fatal(err)
	}
	if _, err := tx.readToken(); err != nil {
		t.Fatal(err)
	}
	tx.stagePath = path
	if _, err := tx.readToken(); err == nil {
		t.Fatal("accepted token below writable ancestor")
	}
	alias := filepath.Join(root, "alias")
	if err := os.Symlink(trusted, alias); err != nil {
		t.Fatal(err)
	}
	tx.stagePath = filepath.Join(alias, "token")
	if _, err := tx.readToken(); err == nil {
		t.Fatal("accepted token through symlink ancestor")
	}
}

func TestPolicyDoesNotMutateExistingSymlinkedRuntimeDirectory(t *testing.T) {
	tx, _, _ := testPolicyTransaction(t, &fakePolicyCommand{state: "disabled"})
	target := filepath.Join(t.TempDir(), "target")
	if err := os.Mkdir(target, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(target, tx.runtimeDir); err != nil {
		t.Fatal(err)
	}
	tx.command = reviewCommand{run: func(_ context.Context, _ ...string) (string, error) {
		return "", errors.New("system command must not run")
	}}
	if err := tx.Apply(context.Background()); err == nil || !strings.Contains(err.Error(), "runtime") {
		t.Fatalf("Apply error = %v, want runtime-path rejection", err)
	}
	info, err := os.Stat(target)
	if err != nil {
		t.Fatal(err)
	}
	if info.Mode().Perm() != 0o700 {
		t.Fatalf("symlink target mode changed to %o", info.Mode().Perm())
	}
}

func TestPolicyRequiresMaskedInactiveUnitAndExplicitZeroPID(t *testing.T) {
	tx, _, _ := testPolicyTransaction(t, &fakePolicyCommand{state: "disabled"})
	tx.stopWaitLimit = 20 * time.Millisecond
	tx.command = reviewCommand{run: func(_ context.Context, args ...string) (string, error) {
		switch args[0] {
		case "is-enabled":
			return "disabled", errors.New("exit 1")
		case "is-active":
			return "unknown", errors.New("exit 4")
		case "mask":
			return "", nil
		case "show":
			return "", nil
		}
		return "", nil
	}}
	if err := tx.Apply(context.Background()); err == nil {
		t.Fatal("accepted unknown unit state or empty MainPID")
	}
}

func TestPolicyRejectsSymlinkedTransactionLock(t *testing.T) {
	tx, _, _ := testPolicyTransaction(t, &fakePolicyCommand{state: "disabled"})
	if err := os.MkdirAll(tx.stateDir, 0o700); err != nil {
		t.Fatal(err)
	}
	target := filepath.Join(t.TempDir(), "lock-target")
	if err := os.WriteFile(target, nil, 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(target, filepath.Join(tx.stateDir, "transaction.lock")); err != nil {
		t.Fatal(err)
	}
	if err := tx.Apply(context.Background()); err == nil {
		t.Fatal("accepted symlinked transaction lock")
	}
}

func TestPolicyRejectsHardLinkedTransactionLock(t *testing.T) {
	tx, _, _ := testPolicyTransaction(t, &fakePolicyCommand{state: "disabled"})
	if err := os.MkdirAll(tx.stateDir, 0o700); err != nil {
		t.Fatal(err)
	}
	target := filepath.Join(t.TempDir(), "lock-target")
	if err := os.WriteFile(target, nil, 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.Link(target, filepath.Join(tx.stateDir, "transaction.lock")); err != nil {
		t.Fatal(err)
	}
	if err := tx.Apply(context.Background()); err == nil {
		t.Fatal("accepted hard-linked transaction lock")
	}
}

func TestPolicyStageCopiesValidatedSourceWithoutServiceCalls(t *testing.T) {
	root := t.TempDir()
	dir := filepath.Join(root, "stage")
	if err := os.Mkdir(dir, 0o700); err != nil {
		t.Fatal(err)
	}
	source := filepath.Join(root, "sops-source")
	destination := filepath.Join(dir, "authorization")
	if err := os.WriteFile(source, []byte("A-token_0123456789abcdefghijklmnop\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := stagePolicyAuthorization(source, destination, uint32(os.Getuid())); err != nil {
		t.Fatal(err)
	}
	got, err := os.ReadFile(destination)
	if err != nil || string(got) != "A-token_0123456789abcdefghijklmnop\n" {
		t.Fatalf("staged policy token = %q, err = %v", got, err)
	}
	if err := os.WriteFile(source, []byte("invalid\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := stagePolicyAuthorization(source, destination, uint32(os.Getuid())); err == nil {
		t.Fatal("accepted invalid policy source")
	}
	got, err = os.ReadFile(destination)
	if err != nil || string(got) != "A-token_0123456789abcdefghijklmnop\n" {
		t.Fatalf("invalid source changed staged policy: %q, err = %v", got, err)
	}
}

func TestPolicyStageSyntheticRootSopsLink(t *testing.T) {
	if os.Getuid() != 0 {
		t.Skip("requires an unprivileged root-mapped user namespace")
	}
	root, err := os.MkdirTemp("/tmp", "sshrelay-policy-")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(root)
	target := filepath.Join(root, "raw-secret")
	parent := filepath.Join(root, "source-parent")
	destinationDir := filepath.Join(root, "destination")
	if err := os.Mkdir(parent, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.Mkdir(destinationDir, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(target, []byte("A-token_0123456789abcdefghijklmnop\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	source := filepath.Join(parent, "authorization")
	if err := os.Symlink(target, source); err != nil {
		t.Fatal(err)
	}
	if err := stagePolicyAuthorization(source, filepath.Join(destinationDir, "authorization"), 0); err != nil {
		t.Fatal(err)
	}
	if err := os.Chmod(parent, 0o777); err != nil {
		t.Fatal(err)
	}
	if err := stagePolicyAuthorization(source, filepath.Join(destinationDir, "authorization"), 0); err == nil {
		t.Fatal("accepted root-owned source link below writable original parent")
	}
}
