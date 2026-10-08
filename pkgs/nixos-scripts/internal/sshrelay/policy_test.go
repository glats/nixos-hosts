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

func TestPolicyLivePolicySurvivesVolatileStateRemoval(t *testing.T) {
	if PolicyLivePath != "/var/lib/ssh-relay/restrictions.yaml" {
		t.Fatalf("live policy must survive server reboot, got %s", PolicyLivePath)
	}
	if !strings.HasPrefix(PolicyStagePath, "/run/") || !strings.HasPrefix(PolicyStateDir, "/run/") {
		t.Fatal("credential staging and transaction locks must remain volatile")
	}
	command := &fakePolicyCommand{state: "enabled"}
	tx, stage, live := testPolicyTransaction(t, command)
	if err := tx.Apply(context.Background()); err != nil {
		t.Fatal(err)
	}
	before, err := os.ReadFile(live)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.RemoveAll(tx.runtimeDir); err != nil {
		t.Fatal(err)
	}
	if err := os.Remove(stage); err != nil {
		t.Fatal(err)
	}
	after, err := os.ReadFile(live)
	if err != nil || string(after) != string(before) || contentsMode(t, live) != 0o600 {
		t.Fatal("live policy changed or disappeared with volatile stage/lock state")
	}
}

func TestPolicyDurableInhibition(t *testing.T) {
	for _, failure := range []string{"stop", "invalid-token", "unmask", "start", "revoke"} {
		t.Run(failure, func(t *testing.T) {
			command := &fakePolicyCommand{state: "enabled"}
			tx, stage, live := testPolicyTransaction(t, command)
			marker := filepath.Join(filepath.Dir(live), "promotion-pending")
			tx.command = reviewCommand{run: func(ctx context.Context, args ...string) (string, error) {
				if args[0] == "mask" {
					if _, err := os.Stat(marker); err != nil {
						t.Fatal("durable inhibition must precede stop, including cleanup")
					}
					if failure == "stop" {
						return "", context.Canceled
					}
				}
				if args[0] == "unmask" {
					if _, err := os.Stat(marker); !errors.Is(err, os.ErrNotExist) {
						t.Fatal("successful policy commit must clear inhibition before unmask")
					}
					if failure == "unmask" {
						return "", errors.New("synthetic unmask failure")
					}
				}
				return command.Run(ctx, args...)
			}}
			if err := tx.Apply(context.Background()); err != nil && failure != "unmask" && failure != "stop" {
				t.Fatal(err)
			}
			if failure == "invalid-token" {
				if err := os.WriteFile(stage, []byte("invalid\n"), 0o600); err != nil {
					t.Fatal(err)
				}
			}
			if failure == "start" {
				command.startErr = errors.New("synthetic start failure")
			}
			var err error
			if failure == "revoke" {
				err = tx.Revoke(context.Background())
			} else {
				err = tx.Apply(context.Background())
				if err == nil {
					t.Fatal("expected transaction failure")
				}
			}
			if failure == "revoke" && err != nil {
				t.Fatal(err)
			}
			if err := os.RemoveAll(tx.runtimeDir); err != nil {
				t.Fatal(err)
			}
			if _, err := os.Stat(marker); err != nil || contentsMode(t, marker) != 0o600 {
				t.Fatal("boot inhibition disappeared with runtime mask/lock state")
			}
		})
	}
}

func TestPolicyRejectsUnsafeInhibition(t *testing.T) {
	for _, link := range []string{"symlink", "hardlink"} {
		t.Run(link, func(t *testing.T) {
			command := &fakePolicyCommand{state: "enabled"}
			tx, _, live := testPolicyTransaction(t, command)
			if err := os.Mkdir(filepath.Dir(live), 0o755); err != nil {
				t.Fatal(err)
			}
			victim := filepath.Join(filepath.Dir(live), "unrelated")
			if err := os.WriteFile(victim, []byte("preserve"), 0o600); err != nil {
				t.Fatal(err)
			}
			marker := filepath.Join(filepath.Dir(live), PolicyInhibitName)
			linkFile := os.Symlink
			if link == "hardlink" {
				linkFile = os.Link
			}
			if err := linkFile(victim, marker); err != nil {
				t.Fatal(err)
			}
			if err := tx.Apply(context.Background()); err == nil {
				t.Fatal("accepted unsafe inhibition")
			}
			if len(command.commands) != 0 {
				t.Fatal("unsafe inhibition allowed service operations")
			}
			contents, err := os.ReadFile(victim)
			if err != nil || string(contents) != "preserve" {
				t.Fatal("unsafe marker changed unrelated file")
			}
		})
	}
}

func TestPolicyReportsInhibitionRestorationFailure(t *testing.T) {
	command := &fakePolicyCommand{state: "enabled"}
	tx, _, live := testPolicyTransaction(t, command)
	tx.command = reviewCommand{run: func(ctx context.Context, args ...string) (string, error) {
		if args[0] == "unmask" {
			if err := os.Symlink(live, filepath.Join(filepath.Dir(live), PolicyInhibitName)); err != nil {
				t.Fatal(err)
			}
			return "", errors.New("synthetic unmask failure")
		}
		return command.Run(ctx, args...)
	}}
	err := tx.Apply(context.Background())
	if err == nil || !strings.Contains(err.Error(), "unmask") || !strings.Contains(err.Error(), "restore durable inhibition") {
		t.Fatalf("missing joined restoration error: %v", err)
	}
	if countCommand(command.commands, "mask --runtime --now ") != 2 {
		t.Fatal("restoration failure bypassed compensating stop")
	}
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

func TestPolicyLoadedUnitRequiresEffectiveDurableInhibition(t *testing.T) {
	for _, scenario := range []string{"apply", "revoke", "start-failure", "missing-condition", "missing-marker", "unsafe-marker", "hardlinked-marker", "symlinked-marker", "reload", "cat-error", "reload-error", "active", "nonzero-pid", "empty-pid", "show-error", "extra-line", "unknown-load"} {
		t.Run(scenario, func(t *testing.T) {
			command := &fakePolicyCommand{state: "enabled"}
			if scenario == "start-failure" {
				command.startErr = errors.New("synthetic start failure")
			}
			tx, stage, live := testPolicyTransaction(t, command)
			tx.stopWaitLimit = time.Millisecond
			marker := filepath.Join(filepath.Dir(live), PolicyInhibitName)
			// An invalid staged token must not be read before cessation is proven.
			if scenario != "apply" && scenario != "revoke" && scenario != "start-failure" {
				if err := os.WriteFile(stage, []byte("invalid\n"), 0o600); err != nil {
					t.Fatal(err)
				}
			}
			tx.command = reviewCommand{run: func(ctx context.Context, args ...string) (string, error) {
				switch args[0] {
				case "mask":
					if scenario == "missing-marker" {
						if err := os.Remove(marker); err != nil {
							t.Fatal(err)
						}
					}
					if scenario == "unsafe-marker" {
						if err := os.Chmod(marker, 0o644); err != nil {
							t.Fatal(err)
						}
					}
					if scenario == "hardlinked-marker" {
						if err := os.Link(marker, marker+".link"); err != nil {
							t.Fatal(err)
						}
					}
					if scenario == "symlinked-marker" {
						if err := os.Remove(marker); err != nil {
							t.Fatal(err)
						}
						if err := os.Symlink(stage, marker); err != nil {
							t.Fatal(err)
						}
					}
				case "cat":
					if strings.Join(args, " ") != "cat --no-pager "+PolicyService {
						t.Fatalf("unexpected cat argv: %v", args)
					}
					if scenario == "cat-error" {
						return "", errors.New("synthetic cat failure")
					}
					if scenario == "missing-condition" {
						return "[Unit]\nDescription=unprotected\n", nil
					}
					return "[Unit]\nConditionPathExists=!" + marker + "\n", nil
				case "show":
					if strings.Contains(strings.Join(args, " "), "NeedDaemonReload") {
						if scenario == "reload-error" {
							return "no\n", errors.New("synthetic reload query failure")
						}
						if scenario == "reload" {
							return "yes\n", nil
						}
						return "no\n", nil
					}
					status := "loaded\ninactive\n0\n"
					switch scenario {
					case "active":
						status = "loaded\nactive\n0\n"
					case "nonzero-pid":
						status = "loaded\ninactive\n123\n"
					case "empty-pid":
						status = "loaded\ninactive\n\n"
					case "show-error":
						return status, errors.New("synthetic show failure")
					case "extra-line":
						status += "unexpected\n"
					case "unknown-load":
						status = "not-found\ninactive\n0\n"
					}
					return status, nil
				}
				return command.Run(ctx, args...)
			}}
			var err error
			if scenario == "revoke" {
				err = tx.Revoke(context.Background())
			} else {
				err = tx.Apply(context.Background())
			}
			if scenario == "apply" || scenario == "revoke" {
				if err != nil {
					t.Fatal(err)
				}
				if _, err := os.Stat(live); err != nil {
					t.Fatal("verified cessation did not permit promotion")
				}
				if scenario == "apply" && countCommand(command.commands, "start ") != 1 {
					t.Fatal("enabled service was not restarted after promotion")
				}
				return
			}
			if scenario == "start-failure" {
				if err == nil || !strings.Contains(err.Error(), "start service") || strings.Contains(err.Error(), "fail-stop verification") {
					t.Fatalf("loaded-unit cleanup failed: %v", err)
				}
				if _, err := os.Stat(marker); err != nil || countCommand(command.commands, "mask --runtime --now ") != 2 {
					t.Fatal("start failure did not restore inhibition and verify compensating stop")
				}
				return
			}
			if err == nil || strings.Contains(err.Error(), "invalid length") {
				t.Fatalf("unsafe cessation reached token validation: %v", err)
			}
			if _, err := os.Stat(live); !errors.Is(err, os.ErrNotExist) {
				t.Fatal("unsafe cessation promoted policy")
			}
			if countCommand(command.commands, "unmask ")+countCommand(command.commands, "start ") != 0 {
				t.Fatal("unsafe cessation resumed service")
			}
		})
	}
}

func TestUnitInhibitsPromotion(t *testing.T) {
	marker := "/var/lib/ssh-relay/promotion-pending"
	condition := "ConditionPathExists=!" + marker + "\n"
	for _, tc := range []struct {
		name string
		unit string
		want bool
	}{
		{"native-unit", "# /etc/systemd/system/ssh-relay.service -> /nix/store/unit\n[Unit]\nAfter=network-online.target\n" + condition + "[Service]\nRestart=on-failure\n", true},
		{"additional-and-condition", "[Unit]\n" + condition + "ConditionPathExists=/other\n", true},
		{"additional-trigger", "[Unit]\n" + condition + "ConditionPathExists=|/other\n", true},
		{"absent", "[Unit]\nDescription=relay\n", false},
		{"comment", "[Unit]\n# " + condition, false},
		{"service-section", "[Service]\n" + condition, false},
		{"wrong-path", "[Unit]\nConditionPathExists=!/other\n", false},
		{"positive-path", "[Unit]\nConditionPathExists=" + marker + "\n", false},
		{"trigger-or", "[Unit]\nConditionPathExists=|!" + marker + "\nConditionPathExists=|/other\n", false},
		{"reset-path", "[Unit]\n" + condition + "ConditionPathExists=\n", false},
		{"reset-other-condition", "[Unit]\n" + condition + "ConditionArchitecture=\n", false},
		{"dropin-reset", "[Unit]\n" + condition + "# /etc/systemd/system/ssh-relay.service.d/reset.conf\n[Unit]\nConditionPathExists=\n", false},
		{"dropin-restores", "[Unit]\nConditionPathExists=\n# /etc/systemd/system/ssh-relay.service.d/inhibit.conf\n[Unit]\n" + condition, true},
		{"dropin-without-section", "[Unit]\n# /etc/systemd/system/ssh-relay.service.d/invalid.conf\n" + condition, false},
		{"continuation", "[Unit]\nDescription=continued\\\n" + condition, false},
	} {
		t.Run(tc.name, func(t *testing.T) {
			if got := unitInhibitsPromotion(tc.unit, marker); got != tc.want {
				t.Fatalf("inhibition=%v, want %v", got, tc.want)
			}
		})
	}
}

func TestPolicyNativeUnitConditionReadOnly(t *testing.T) {
	if testing.Short() || os.Getenv("SSHRELAY_NATIVE_UNIT_CHECK") != "1" {
		t.Skip("opt-in read-only check of the installed ROG unit")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	command := systemctlCommand{path: PolicySystemctlPath}
	unit, err := command.Run(ctx, "cat", "--no-pager", PolicyService)
	if err != nil || !unitInhibitsPromotion(unit, filepath.Join(filepath.Dir(PolicyLivePath), PolicyInhibitName)) {
		t.Fatalf("installed unit lacks startup inhibition (cat error: %v)", err)
	}
	reload, err := command.Run(ctx, "show", "-p", "NeedDaemonReload", "--value", PolicyService)
	if err != nil || strings.TrimSpace(reload) != "no" {
		t.Fatalf("installed configuration is not effective: reload=%q error=%v", reload, err)
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
