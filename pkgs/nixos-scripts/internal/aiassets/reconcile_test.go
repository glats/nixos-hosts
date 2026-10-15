package aiassets

import (
	"bufio"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"syscall"
	"testing"
)

func put(t *testing.T, root, name, body string) {
	t.Helper()
	path := filepath.Join(root, name)
	if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(body), 0644); err != nil {
		t.Fatal(err)
	}
}

func TestReconcileRemovesEmptyParentsOfRetiredFiles(t *testing.T) {
	root := t.TempDir()
	target, desired, legacy := filepath.Join(root, "target"), filepath.Join(root, "desired"), filepath.Join(root, "legacy")
	for _, dir := range []string{target, desired, legacy} {
		if err := os.MkdirAll(dir, 0755); err != nil {
			t.Fatal(err)
		}
	}
	put(t, legacy, "skills/sdd-explore/SKILL.md", "retired")
	put(t, target, "skills/sdd-explore/SKILL.md", "retired")
	put(t, target, "skills/user/SKILL.md", "keep")
	if err := Reconcile(target, desired, legacy, "v4-tag"); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(target, "skills/sdd-explore")); !os.IsNotExist(err) {
		t.Fatalf("retired empty parent remains: %v", err)
	}
	if _, err := os.Stat(filepath.Join(target, "skills")); err != nil {
		t.Fatalf("non-empty ancestor removed: %v", err)
	}
}

func TestReconcileOwnership(t *testing.T) {
	for _, name := range []string{"bootstrap", "foreign collision", "modified collision", "retired modified", "symlink escape", "interrupted update", "empty before-image"} {
		t.Run(name, func(t *testing.T) {
			root := t.TempDir()
			target, desired, legacy := filepath.Join(root, "target"), filepath.Join(root, "desired"), filepath.Join(root, "legacy")
			for _, dir := range []string{target, desired, legacy} {
				if err := os.MkdirAll(dir, 0755); err != nil {
					t.Fatal(err)
				}
			}
			put(t, legacy, "skills/sdd/SKILL.md", "old managed")
			put(t, legacy, "plugins/relay.ts", "old relay")
			put(t, target, "skills/sdd/SKILL.md", "old managed")
			put(t, target, "plugins/relay.ts", "old relay")
			put(t, target, "archive/history.md", "user history")
			put(t, desired, "plugins/relay.ts", "new relay")
			put(t, desired, "skills/odd/SKILL.md", "new skill")
			wantError := false
			switch name {
			case "foreign collision":
				put(t, target, "skills/odd/SKILL.md", "user skill")
				wantError = true
			case "modified collision":
				put(t, target, "plugins/relay.ts", "user relay")
				wantError = true
			case "retired modified":
				put(t, target, "skills/sdd/SKILL.md", "user-modified old skill")
				wantError = true
			case "symlink escape":
				if err := os.Symlink(root, filepath.Join(target, "skills/odd")); err != nil {
					t.Fatal(err)
				}
				wantError = true
			case "interrupted update":
				_ = reconcile(target, desired, legacy, "v4-tag", func() error { return errors.New("interrupted") })
			case "empty before-image":
				put(t, legacy, "plugins/relay.ts", "")
				put(t, target, "plugins/relay.ts", "")
				_ = reconcile(target, desired, legacy, "v4-tag", func() error { return errors.New("interrupted") })
			}
			err := Reconcile(target, desired, legacy, "v4-tag")
			if (err != nil) != wantError {
				t.Fatalf("error=%v wantError=%v", err, wantError)
			}
			if wantError {
				b, _ := os.ReadFile(filepath.Join(target, "skills/sdd/SKILL.md"))
				expected := "old managed"
				if name == "retired modified" {
					expected = "user-modified old skill"
				}
				if string(b) != expected {
					t.Fatal("failed preflight retired a file")
				}
			} else {
				if err := Reconcile(target, desired, legacy, "v4-tag"); err != nil {
					t.Fatalf("retry: %v", err)
				}
				b, _ := os.ReadFile(filepath.Join(target, "plugins/relay.ts"))
				if string(b) != "new relay" {
					t.Fatal("relay not updated")
				}
				_, err := os.Stat(filepath.Join(target, "skills/sdd/SKILL.md"))
				if name == "retired modified" {
					if err != nil {
						t.Fatal("modified retirement lost user data")
					}
				} else if !os.IsNotExist(err) {
					t.Fatal("proven old skill not retired")
				}
			}
			b, _ := os.ReadFile(filepath.Join(target, "archive/history.md"))
			if string(b) != "user history" {
				t.Fatal("history changed")
			}
		})
	}
}

func TestPostJournalConflict(t *testing.T) {
	for _, kind := range []string{"edit", "appeared", "symlink", "parent symlink"} {
		t.Run(kind, func(t *testing.T) {
			r := t.TempDir()
			target, desired, legacy := filepath.Join(r, "target"), filepath.Join(r, "desired"), filepath.Join(r, "legacy")
			for _, p := range []string{target, desired, legacy} {
				if err := os.MkdirAll(p, 0755); err != nil {
					t.Fatal(err)
				}
			}
			put(t, desired, "dir/asset", "new")
			if kind != "appeared" {
				put(t, legacy, "dir/asset", "old")
				put(t, target, "dir/asset", "old")
			}
			err := reconcile(target, desired, legacy, "A", func() error {
				switch kind {
				case "edit", "appeared":
					put(t, target, "dir/asset", "user edit")
				case "symlink":
					os.Remove(filepath.Join(target, "dir/asset"))
					put(t, r, "outside", "user edit")
					if err := os.Symlink(filepath.Join(r, "outside"), filepath.Join(target, "dir/asset")); err != nil {
						t.Fatal(err)
					}
				case "parent symlink":
					os.Rename(filepath.Join(target, "dir"), filepath.Join(r, "outside-dir"))
					if err := os.Symlink(filepath.Join(r, "outside-dir"), filepath.Join(target, "dir")); err != nil {
						t.Fatal(err)
					}
				}
				return nil
			})
			if err == nil {
				t.Fatal("post-journal change was overwritten")
			}
			b, _ := os.ReadFile(filepath.Join(target, "dir/asset"))
			if string(b) == "new" {
				t.Fatal("changed bytes replaced")
			}
		})
	}
}

func TestSecondUpgradeInterruption(t *testing.T) {
	for _, prior := range []string{"A", ""} {
		t.Run("prior="+prior, func(t *testing.T) {
			r := t.TempDir()
			target, desired, legacy := filepath.Join(r, "target"), filepath.Join(r, "desired"), filepath.Join(r, "legacy")
			put(t, legacy, "asset", "2.5")
			put(t, target, "asset", "2.5")
			put(t, desired, "asset", prior)
			if err := Reconcile(target, desired, legacy, "A"); err != nil {
				t.Fatal(err)
			}
			put(t, desired, "asset", "B")
			stop := errors.New("interrupt after journal")
			if err := reconcile(target, desired, legacy, "B", func() error { return stop }); !errors.Is(err, stop) {
				t.Fatal(err)
			}
			b, _ := os.ReadFile(filepath.Join(target, manifestName))
			var m manifest
			if err := json.Unmarshal(b, &m); err != nil {
				t.Fatal(err)
			}
			if m.Files["asset"].Digest != digest([]byte("B")) {
				t.Fatal("missing desired B")
			}
			entry := m.Files["asset"]
			if !entry.Pending || entry.Prior == nil || *entry.Prior != (snapshot{Exists: true, Digest: digest([]byte(prior))}) {
				t.Fatal("journal lost immediate predecessor")
			}
			if string(entry.Before) != "2.5" {
				t.Fatal("original rollback bytes lost")
			}
			put(t, target, "asset", "user edit")
			if err := Reconcile(target, desired, legacy, "B"); err == nil {
				t.Fatal("pending plan accepted user edit")
			}
			put(t, target, "asset", prior)
			// The immediate predecessor, not original 2.5, must be retryable.
			if err := Reconcile(target, desired, legacy, "B"); err != nil {
				t.Fatal(err)
			}
			for _, changed := range []string{"2.5", prior, "user edit"} {
				put(t, target, "asset", changed)
				if err := Reconcile(target, desired, legacy, "B"); err == nil {
					t.Fatalf("accepted historical/user version %q", changed)
				}
			}
		})
	}
}

// A subprocess handshake proves the production lock is held across journaling
// and that another real process sees contention before entering Reconcile.
func TestReconcileProcessLock(t *testing.T) {
	if mode := os.Getenv("AIASSETS_TEST_CHILD"); mode != "" {
		r := os.Getenv("AIASSETS_TEST_ROOT")
		target, legacy := filepath.Join(r, "target"), filepath.Join(r, "legacy")
		if mode == "holder" {
			err := reconcile(target, filepath.Join(r, "A"), legacy, "A", func() error {
				fmt.Println("journal locked")
				_, err := bufio.NewReader(os.Stdin).ReadString('\n')
				return err
			})
			if err != nil {
				t.Fatal(err)
			}
		} else {
			lock, err := os.OpenFile(filepath.Join(target, lockName), os.O_RDWR, 0)
			if err != nil {
				t.Fatal(err)
			}
			err = syscall.Flock(int(lock.Fd()), syscall.LOCK_EX|syscall.LOCK_NB)
			lock.Close()
			if !errors.Is(err, syscall.EWOULDBLOCK) {
				t.Fatalf("missing interprocess lock: %v", err)
			}
			fmt.Println("contention proved")
			if err := Reconcile(target, filepath.Join(r, "B"), legacy, "B"); err != nil {
				t.Fatal(err)
			}
		}
		return
	}
	r := t.TempDir()
	put(t, r, "target/asset", "2.5")
	put(t, r, "legacy/asset", "2.5")
	put(t, r, "A/asset", "A")
	put(t, r, "B/asset", "B")
	child := func(mode string) (*exec.Cmd, *bufio.Reader) {
		cmd := exec.Command(os.Args[0], "-test.run=^TestReconcileProcessLock$")
		cmd.Env = append(os.Environ(), "AIASSETS_TEST_CHILD="+mode, "AIASSETS_TEST_ROOT="+r)
		out, err := cmd.StdoutPipe()
		if err != nil {
			t.Fatal(err)
		}
		cmd.Stderr = os.Stderr
		return cmd, bufio.NewReader(out)
	}
	holder, holderOut := child("holder")
	in, err := holder.StdinPipe()
	if err != nil {
		t.Fatal(err)
	}
	if err := holder.Start(); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { holder.Process.Kill() })
	if line, err := holderOut.ReadString('\n'); err != nil || line != "journal locked\n" {
		t.Fatalf("holder handshake %q %v", line, err)
	}
	contender, contenderOut := child("contender")
	if err := contender.Start(); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { contender.Process.Kill() })
	if line, err := contenderOut.ReadString('\n'); err != nil || line != "contention proved\n" {
		t.Fatalf("contender handshake %q %v", line, err)
	}
	if _, err := fmt.Fprintln(in, "release"); err != nil {
		t.Fatal(err)
	}
	in.Close()
	if err := holder.Wait(); err != nil {
		t.Fatal(err)
	}
	if err := contender.Wait(); err != nil {
		t.Fatal(err)
	}
	b, err := os.ReadFile(filepath.Join(r, "target/asset"))
	if err != nil || string(b) != "B" {
		t.Fatalf("serialized upgrade: %q %v", b, err)
	}
}

func TestLockAndSchemaOneSafety(t *testing.T) {
	for _, kind := range []string{"symlink lock", "directory lock", "schema1 history"} {
		t.Run(kind, func(t *testing.T) {
			r := t.TempDir()
			target, desired, legacy := filepath.Join(r, "target"), filepath.Join(r, "desired"), filepath.Join(r, "legacy")
			put(t, target, "asset", "user")
			put(t, desired, "asset", "B")
			os.MkdirAll(legacy, 0755)
			switch kind {
			case "symlink lock":
				if err := os.Symlink(filepath.Join(r, "outside"), filepath.Join(target, lockName)); err != nil {
					t.Fatal(err)
				}
			case "directory lock":
				os.Mkdir(filepath.Join(target, lockName), 0755)
			case "schema1 history":
				b, _ := json.Marshal(manifest{Schema: 1, Files: map[string]owned{"asset": {Digest: digest([]byte("A")), Before: []byte("user")}}})
				os.WriteFile(filepath.Join(target, manifestName), b, 0644)
			}
			if err := Reconcile(target, desired, legacy, "B"); err == nil {
				t.Fatal("accepted unsafe lock/historical authority")
			}
			b, _ := os.ReadFile(filepath.Join(target, "asset"))
			if string(b) != "user" {
				t.Fatal("user bytes lost")
			}
		})
	}
}

func TestRejectSymlinkManifestAndSource(t *testing.T) {
	for _, where := range []string{"target", "desired"} {
		t.Run(where, func(t *testing.T) {
			r := t.TempDir()
			d := filepath.Join(r, "desired")
			target := filepath.Join(r, "target")
			legacy := filepath.Join(r, "legacy")
			for _, p := range []string{d, target, legacy} {
				os.MkdirAll(p, 0755)
			}
			name := filepath.Join(target, ".gentle-ai-owned.json")
			if where == "desired" {
				name = filepath.Join(d, "escape")
			}
			if err := os.Symlink(r, name); err != nil {
				t.Fatal(err)
			}
			if err := Reconcile(target, d, legacy, "tag"); err == nil {
				t.Fatal("accepted symlink")
			}
		})
	}
}
