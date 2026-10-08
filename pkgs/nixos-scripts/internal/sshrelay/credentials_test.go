package sshrelay

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func newCredentialController(t *testing.T, launcher *fakeLauncher, enabled bool) (*Controller, string, string) {
	t.Helper()
	root := t.TempDir()
	credentialDir := filepath.Join(root, "credentials")
	if err := os.Mkdir(credentialDir, 0o700); err != nil {
		t.Fatal(err)
	}
	stage := filepath.Join(credentialDir, "authorization")
	headers := filepath.Join(credentialDir, "headers")
	stateDir := filepath.Join(root, "state")
	if err := os.Mkdir(stateDir, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(stage, []byte("A-token_0123456789abcdefghijklmnop\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	c, err := New(Config{StateDir: stateDir, PlistPath: filepath.Join(root, "relay.plist"), Label: DefaultLabel, OffTimeout: 200 * time.Millisecond, CredentialStagePath: stage, HeadersPath: headers}, launcher)
	if err != nil {
		t.Fatal(err)
	}
	if err := c.writeState(state{Enabled: enabled, Generation: 1}); err != nil {
		t.Fatal(err)
	}
	return c, stage, headers
}

func TestApplyCredentialsKeepsInitiallyOffRelayOff(t *testing.T) {
	c, _, headers := newCredentialController(t, &fakeLauncher{loaded: true}, false)
	if err := c.ApplyCredentials(context.Background()); err != nil {
		t.Fatal(err)
	}
	if err := ValidateHeaderFile(headers); err != nil {
		t.Fatal(err)
	}
	st, err := c.readState()
	if err != nil || st.Enabled {
		t.Fatalf("state = %+v, err = %v", st, err)
	}
}

func TestApplyCredentialsRestartsOnlyPriorEnabledIntent(t *testing.T) {
	launcher := &fakeLauncher{loaded: true}
	c, _, _ := newCredentialController(t, launcher, true)
	if err := c.ApplyCredentials(context.Background()); err != nil {
		t.Fatal(err)
	}
	calls := launcher.calls()
	if indexOf(calls, "bootout") < 0 || indexOf(calls, "bootstrap") < 0 || indexOf(calls, "kickstart") < 0 || indexOf(calls, "bootout") > indexOf(calls, "bootstrap") {
		t.Fatalf("launch order = %v", calls)
	}
	st, err := c.readState()
	if err != nil || !st.Enabled {
		t.Fatalf("state = %+v, err = %v", st, err)
	}
}

func TestApplyCredentialsFailureDisablesAndBootsOutRelay(t *testing.T) {
	launcher := &fakeLauncher{loaded: true}
	c, stage, _ := newCredentialController(t, launcher, true)
	if err := os.WriteFile(stage, []byte("invalid token\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := c.ApplyCredentials(context.Background()); err == nil {
		t.Fatal("invalid staged token was accepted")
	}
	st, err := c.readState()
	if err != nil || st.Enabled {
		t.Fatalf("failed promotion state = %+v, err = %v", st, err)
	}
	calls := launcher.calls()
	if strings.Contains(strings.Join(calls, " "), "bootstrap") || strings.Contains(strings.Join(calls, " "), "kickstart") {
		t.Fatalf("failed promotion restarted relay: %v", calls)
	}
}

func TestRevokeCredentialsClearsHeaderAndIntent(t *testing.T) {
	launcher := &fakeLauncher{}
	c, _, headers := newCredentialController(t, launcher, false)
	if err := installHeaders(headers, "A-token_0123456789abcdefghijklmnop"); err != nil {
		t.Fatal(err)
	}
	if err := c.RevokeCredentials(context.Background()); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(headers); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("headers still exist: %v", err)
	}
	st, err := c.readState()
	if err != nil || st.Enabled {
		t.Fatalf("revocation state = %+v, err = %v", st, err)
	}
}

func TestCredentialPromotionSerializesWithLaterOn(t *testing.T) {
	release := make(chan struct{})
	launcher := &fakeLauncher{loaded: true, blockBootout: release, bootStarted: make(chan struct{})}
	c, _, _ := newCredentialController(t, launcher, false)
	applyDone := make(chan error, 1)
	go func() { applyDone <- c.ApplyCredentials(context.Background()) }()
	select {
	case <-launcher.bootStarted:
	case <-time.After(time.Second):
		t.Fatal("credential promotion did not reach bootout")
	}
	onDone := make(chan error, 1)
	go func() { onDone <- c.On(context.Background()) }()
	select {
	case err := <-onDone:
		t.Fatalf("On bypassed credential transaction lock: %v", err)
	case <-time.After(30 * time.Millisecond):
	}
	close(release)
	if err := <-applyDone; err != nil {
		t.Fatal(err)
	}
	if err := <-onDone; err != nil {
		t.Fatal(err)
	}
	st, err := c.readState()
	if err != nil || !st.Enabled {
		t.Fatalf("final state = %+v, err = %v", st, err)
	}
}

func TestCredentialPromotionRejectsSopsSymlinkStage(t *testing.T) {
	c, stage, headers := newCredentialController(t, &fakeLauncher{loaded: true}, true)
	target := filepath.Join(filepath.Dir(stage), "materialized-secret")
	if err := os.Rename(stage, target); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(target, stage); err != nil {
		t.Fatal(err)
	}
	if err := c.ApplyCredentials(context.Background()); err == nil {
		t.Fatal("accepted symlinked sops stage")
	}
	if _, err := os.Stat(headers); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("header promoted after rejected stage: %v", err)
	}
}

func TestRevokePreservesFileBehindSymlinkedAncestor(t *testing.T) {
	c, _, _ := newCredentialController(t, &fakeLauncher{}, false)
	victimDir := t.TempDir()
	victim := filepath.Join(victimDir, "headers")
	if err := os.WriteFile(victim, []byte("unrelated\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	alias := filepath.Join(t.TempDir(), "alias")
	if err := os.Symlink(victimDir, alias); err != nil {
		t.Fatal(err)
	}
	c.config.HeadersPath = filepath.Join(alias, "headers")
	if err := c.RevokeCredentials(context.Background()); err == nil {
		t.Fatal("accepted symlinked header ancestor")
	}
	if _, err := os.Stat(victim); err != nil {
		t.Fatalf("victim changed after rejected ancestor: %v", err)
	}
}

func TestValidateHeaderRejectsWritableAncestorsAndHardlinks(t *testing.T) {
	t.Run("writable ancestor", func(t *testing.T) {
		root := t.TempDir()
		unsafe := filepath.Join(root, "unsafe")
		private := filepath.Join(unsafe, "private")
		if err := os.MkdirAll(private, 0o700); err != nil {
			t.Fatal(err)
		}
		if err := os.Chmod(unsafe, 0o777); err != nil {
			t.Fatal(err)
		}
		path := filepath.Join(private, "headers")
		if err := os.WriteFile(path, []byte("synthetic"), 0o600); err != nil {
			t.Fatal(err)
		}
		if err := ValidateHeaderFile(path); err == nil {
			t.Fatal("accepted writable ancestor")
		}
	})
	t.Run("hardlink", func(t *testing.T) {
		root := t.TempDir()
		original := filepath.Join(root, "original")
		path := filepath.Join(root, "headers")
		if err := os.WriteFile(original, []byte("synthetic"), 0o600); err != nil {
			t.Fatal(err)
		}
		if err := os.Link(original, path); err != nil {
			t.Fatal(err)
		}
		if err := ValidateHeaderFile(path); err == nil {
			t.Fatal("accepted hardlinked header")
		}
	})
}

func TestStageCredentialsCopiesOnlyValidatedSource(t *testing.T) {
	launcher := &fakeLauncher{}
	c, stage, headers := newCredentialController(t, launcher, false)
	source := filepath.Join(filepath.Dir(stage), "sops-source")
	if err := os.WriteFile(source, []byte("B-token_0123456789abcdefghijklmnop\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := c.StageCredentials(context.Background(), source); err != nil {
		t.Fatal(err)
	}
	got, err := os.ReadFile(stage)
	if err != nil || string(got) != "B-token_0123456789abcdefghijklmnop\n" {
		t.Fatalf("stage = %q, err = %v", got, err)
	}
	if _, err := os.Stat(headers); !errors.Is(err, os.ErrNotExist) {
		t.Fatalf("stage action changed live headers: %v", err)
	}
	if calls := launcher.calls(); len(calls) != 0 {
		t.Fatalf("stage action called launchctl: %v", calls)
	}
	if err := c.StageCredentials(context.Background(), source); err != nil {
		t.Fatal(err)
	}
}

func TestStageCredentialsRejectsInvalidOrUserSymlinkWithoutChangingStage(t *testing.T) {
	c, stage, _ := newCredentialController(t, &fakeLauncher{}, false)
	before, err := os.ReadFile(stage)
	if err != nil {
		t.Fatal(err)
	}
	invalid := filepath.Join(filepath.Dir(stage), "invalid")
	if err := os.WriteFile(invalid, []byte("not-a-token\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := c.StageCredentials(context.Background(), invalid); err == nil {
		t.Fatal("accepted invalid source")
	}
	after, err := os.ReadFile(stage)
	if err != nil || string(after) != string(before) {
		t.Fatalf("invalid source changed stage: %q", after)
	}
	link := filepath.Join(filepath.Dir(stage), "user-link")
	if err := os.Symlink(invalid, link); err != nil {
		t.Fatal(err)
	}
	if err := c.StageCredentials(context.Background(), link); err == nil {
		t.Fatal("accepted user-owned source symlink")
	}
	after, err = os.ReadFile(stage)
	if err != nil || string(after) != string(before) {
		t.Fatalf("symlink source changed stage: %q", after)
	}
}

func TestStageCredentialsSyntheticRootSopsLink(t *testing.T) {
	if os.Getuid() != 0 {
		t.Skip("requires an unprivileged root-mapped user namespace")
	}
	for _, unsafeParent := range []bool{false, true} {
		t.Run(map[bool]string{false: "trusted", true: "writable-original-parent"}[unsafeParent], func(t *testing.T) {
			c, stage, headers := newCredentialController(t, &fakeLauncher{}, false)
			root, err := os.MkdirTemp("/tmp", "sshrelay-sops-")
			if err != nil {
				t.Fatal(err)
			}
			defer os.RemoveAll(root)
			target := filepath.Join(root, "raw-secret")
			value := "B-token_0123456789abcdefghijklmnop\n"
			if err := os.WriteFile(target, []byte(value), 0o600); err != nil {
				t.Fatal(err)
			}
			parent := filepath.Join(root, "source-parent")
			if err := os.Mkdir(parent, 0o700); err != nil {
				t.Fatal(err)
			}
			if unsafeParent {
				if err := os.Chmod(parent, 0o777); err != nil {
					t.Fatal(err)
				}
			}
			source := filepath.Join(parent, "authorization")
			if err := os.Symlink(target, source); err != nil {
				t.Fatal(err)
			}
			if ownerUIDMust(t, source) != 0 {
				t.Fatal("synthetic sops link is not root-owned")
			}
			err = c.StageCredentials(context.Background(), source)
			if unsafeParent {
				if err == nil {
					t.Fatal("accepted root-owned link below writable original parent")
				}
				return
			}
			if err != nil {
				t.Fatal(err)
			}
			got, err := os.ReadFile(stage)
			if err != nil || string(got) != value {
				t.Fatalf("stage = %q, err = %v", got, err)
			}
			if _, err := os.Stat(headers); !errors.Is(err, os.ErrNotExist) {
				t.Fatal("staging changed live headers")
			}
		})
	}
}

func TestStageCredentialsChecksEveryIntermediateSourceAncestor(t *testing.T) {
	if os.Getuid() != 0 {
		t.Skip("requires an unprivileged root-mapped user namespace")
	}
	c, stage, _ := newCredentialController(t, &fakeLauncher{}, false)
	root := t.TempDir()
	unsafe := filepath.Join(root, "unsafe")
	trusted := filepath.Join(root, "trusted")
	if err := os.Mkdir(unsafe, 0o777); err != nil {
		t.Fatal(err)
	}
	if err := os.Chmod(unsafe, 0o777); err != nil {
		t.Fatal(err)
	}
	if err := os.Mkdir(trusted, 0o700); err != nil {
		t.Fatal(err)
	}
	target := filepath.Join(trusted, "authorization")
	if err := os.WriteFile(target, []byte("B-token_0123456789abcdefghijklmnop\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	link := filepath.Join(unsafe, "trusted")
	if err := os.Symlink(trusted, link); err != nil {
		t.Fatal(err)
	}
	source := filepath.Join(link, "authorization")
	if err := c.StageCredentials(context.Background(), source); err == nil {
		t.Fatal("accepted source through writable intermediate symlink target ancestor")
	}
	if _, err := os.Stat(stage); err != nil {
		t.Fatal(err)
	}
}

func TestStageCredentialsAcceptsTrustedMultiHopSource(t *testing.T) {
	if os.Getuid() != 0 {
		t.Skip("requires an unprivileged root-mapped user namespace")
	}
	c, stage, _ := newCredentialController(t, &fakeLauncher{}, false)
	root := t.TempDir()
	targetDir := filepath.Join(root, "target")
	if err := os.Mkdir(targetDir, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(targetDir, "authorization"), []byte("B-token_0123456789abcdefghijklmnop\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	first := filepath.Join(root, "first")
	second := filepath.Join(root, "second")
	if err := os.Symlink(second, first); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(targetDir, second); err != nil {
		t.Fatal(err)
	}
	if err := c.StageCredentials(context.Background(), filepath.Join(first, "authorization")); err != nil {
		t.Fatal(err)
	}
	got, err := os.ReadFile(stage)
	if err != nil || string(got) != "B-token_0123456789abcdefghijklmnop\n" {
		t.Fatalf("stage = %q, err = %v", got, err)
	}
}

func TestStageCredentialsRejectsSourceSymlinkCycle(t *testing.T) {
	c, stage, _ := newCredentialController(t, &fakeLauncher{}, false)
	root := t.TempDir()
	first := filepath.Join(root, "first")
	second := filepath.Join(root, "second")
	if err := os.Symlink(second, first); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(first, second); err != nil {
		t.Fatal(err)
	}
	before, err := os.ReadFile(stage)
	if err != nil {
		t.Fatal(err)
	}
	if err := c.StageCredentials(context.Background(), first); err == nil {
		t.Fatal("accepted source symlink cycle")
	}
	after, err := os.ReadFile(stage)
	if err != nil || string(after) != string(before) {
		t.Fatalf("cycle source changed stage: %q", after)
	}
}

func ownerUIDMust(t *testing.T, path string) uint32 {
	t.Helper()
	info, err := os.Lstat(path)
	if err != nil {
		t.Fatal(err)
	}
	return ownerUID(info)
}
