package aiassets

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"syscall"
	"testing"
	"time"
)

func stampFixture(t *testing.T) (target, desired, legacy string) {
	t.Helper()
	root := tempRoot(t)
	target, desired, legacy = filepath.Join(root, "target"), filepath.Join(root, "desired"), filepath.Join(root, "legacy")
	for _, dir := range []string{target, desired, legacy} {
		if err := os.MkdirAll(dir, 0755); err != nil {
			t.Fatal(err)
		}
	}
	put(t, desired, "a/one", "one")
	put(t, desired, "b/two", "two")
	return target, desired, legacy
}

func inode(t *testing.T, path string) uint64 {
	t.Helper()
	info, err := os.Stat(path)
	if err != nil {
		t.Fatal(err)
	}
	return info.Sys().(*syscall.Stat_t).Ino
}

func noRacyWindow(t *testing.T) {
	t.Helper()
	previous := racyWindow
	racyWindow = 0
	t.Cleanup(func() { racyWindow = previous })
}

func TestReconcileSkipsUnchangedFiles(t *testing.T) {
	target, desired, legacy := stampFixture(t)
	if err := Reconcile(target, desired, legacy, "A"); err != nil {
		t.Fatal(err)
	}
	one, two := inode(t, filepath.Join(target, "a/one")), inode(t, filepath.Join(target, "b/two"))
	if err := Reconcile(target, desired, legacy, "B"); err != nil {
		t.Fatal(err)
	}
	if inode(t, filepath.Join(target, "a/one")) != one || inode(t, filepath.Join(target, "b/two")) != two {
		t.Fatal("unchanged asset was rewritten")
	}
	m := readManifest(t, target)
	if entry := m.Files["a/one"]; entry.Revision != "B" || entry.Pending || entry.Prior != nil {
		t.Fatalf("manifest not finalized for revision B: %+v", entry)
	}
}

func TestReconcileNoopLeavesManifestUntouched(t *testing.T) {
	target, desired, legacy := stampFixture(t)
	if err := Reconcile(target, desired, legacy, "A"); err != nil {
		t.Fatal(err)
	}
	state := filepath.Join(target, manifestName)
	before := inode(t, state)
	if err := Reconcile(target, desired, legacy, "A"); err != nil {
		t.Fatal(err)
	}
	if inode(t, state) != before {
		t.Fatal("manifest rewritten with identical content")
	}
}

func TestStampFastPathSkipsSourceReads(t *testing.T) {
	noRacyWindow(t)
	target, desired, legacy := stampFixture(t)
	if err := Reconcile(target, desired, legacy, "A"); err != nil {
		t.Fatal(err)
	}
	if readManifest(t, target).Applied == nil {
		t.Fatal("applied stamp missing after success")
	}
	previous := readSource
	readSource = func(string) ([]byte, error) { return nil, errors.New("source contents read") }
	t.Cleanup(func() { readSource = previous })
	if err := Reconcile(target, desired, legacy, "A"); err != nil {
		t.Fatalf("fast path read source contents: %v", err)
	}
}

func TestStampDetectsDrift(t *testing.T) {
	noRacyWindow(t)
	target, desired, legacy := stampFixture(t)
	if err := Reconcile(target, desired, legacy, "A"); err != nil {
		t.Fatal(err)
	}
	if err := os.Remove(filepath.Join(target, "a/one")); err != nil {
		t.Fatal(err)
	}
	if err := Reconcile(target, desired, legacy, "A"); err != nil {
		t.Fatal(err)
	}
	if b, _ := os.ReadFile(filepath.Join(target, "a/one")); string(b) != "one" {
		t.Fatalf("deleted asset not restored: %q", b)
	}
	if err := Reconcile(target, desired, legacy, "A"); err != nil {
		t.Fatal(err)
	}
	put(t, target, "b/two", "user edit")
	if err := Reconcile(target, desired, legacy, "A"); err == nil || !strings.Contains(err.Error(), "collision") {
		t.Fatalf("user edit not detected: %v", err)
	}
	if b, _ := os.ReadFile(filepath.Join(target, "b/two")); string(b) != "user edit" {
		t.Fatalf("user edit overwritten: %q", b)
	}
}

func TestStampInvalidatedBySourceChange(t *testing.T) {
	noRacyWindow(t)
	target, desired, legacy := stampFixture(t)
	if err := Reconcile(target, desired, legacy, "A"); err != nil {
		t.Fatal(err)
	}
	put(t, desired, "a/one", "one updated")
	put(t, desired, "c/three", "three")
	if err := os.Remove(filepath.Join(desired, "b/two")); err != nil {
		t.Fatal(err)
	}
	if err := Reconcile(target, desired, legacy, "A"); err != nil {
		t.Fatal(err)
	}
	if b, _ := os.ReadFile(filepath.Join(target, "a/one")); string(b) != "one updated" {
		t.Fatalf("changed source not applied: %q", b)
	}
	if b, _ := os.ReadFile(filepath.Join(target, "c/three")); string(b) != "three" {
		t.Fatalf("new source not applied: %q", b)
	}
	if _, err := os.Stat(filepath.Join(target, "b/two")); !os.IsNotExist(err) {
		t.Fatal("retired source file kept")
	}
}

func TestStampNotTrustedWhenFilesAreRacy(t *testing.T) {
	previous := racyWindow
	racyWindow = time.Second
	t.Cleanup(func() { racyWindow = previous })
	target, desired, legacy := stampFixture(t)
	if err := Reconcile(target, desired, legacy, "A"); err != nil {
		t.Fatal(err)
	}
	if readManifest(t, target).Applied != nil {
		t.Fatal("stamp written while files are inside the racy window")
	}
	time.Sleep(racyWindow + 100*time.Millisecond)
	if err := Reconcile(target, desired, legacy, "A"); err != nil {
		t.Fatal(err)
	}
	if readManifest(t, target).Applied == nil {
		t.Fatal("stamp missing once files left the racy window")
	}
}

func TestStampManifestStaysStableOnceApplied(t *testing.T) {
	noRacyWindow(t)
	target, desired, legacy := stampFixture(t)
	if err := Reconcile(target, desired, legacy, "A"); err != nil {
		t.Fatal(err)
	}
	state := filepath.Join(target, manifestName)
	before := inode(t, state)
	for i := 0; i < 2; i++ {
		if err := Reconcile(target, desired, legacy, "A"); err != nil {
			t.Fatal(err)
		}
	}
	if inode(t, state) != before {
		t.Fatal("manifest rewritten although the applied stamp is current")
	}
}

func TestUserFileNamedLikeAStampIsPreserved(t *testing.T) {
	noRacyWindow(t)
	target, desired, legacy := stampFixture(t)
	put(t, target, ".gentle-ai-owned.stamp", "user data")
	put(t, desired, "c/kept", "kept")
	if err := Reconcile(target, desired, legacy, "A"); err != nil {
		t.Fatal(err)
	}
	if err := Reconcile(target, desired, legacy, "A"); err != nil {
		t.Fatal(err)
	}
	if b, _ := os.ReadFile(filepath.Join(target, ".gentle-ai-owned.stamp")); string(b) != "user data" {
		t.Fatalf("user file replaced: %q", b)
	}
}

func readManifest(t *testing.T, target string) manifest {
	t.Helper()
	b, err := os.ReadFile(filepath.Join(target, manifestName))
	if err != nil {
		t.Fatal(err)
	}
	var m manifest
	if err := json.Unmarshal(b, &m); err != nil {
		t.Fatal(err)
	}
	return m
}

func agedFixture(t *testing.T) (target, desired, legacy string) {
	t.Helper()
	noRacyWindow(t)
	target, desired, legacy = stampFixture(t)
	if err := Reconcile(target, desired, legacy, "A"); err != nil {
		t.Fatal(err)
	}
	if err := Reconcile(target, desired, legacy, "A"); err != nil {
		t.Fatal(err)
	}
	if readManifest(t, target).Applied == nil {
		t.Fatal("fixture has no applied stamp")
	}
	return target, desired, legacy
}

func restoreMtime(t *testing.T, path string, info os.FileInfo) {
	t.Helper()
	if err := os.Chtimes(path, info.ModTime(), info.ModTime()); err != nil {
		t.Fatal(err)
	}
}

func TestStampDetectsSameSizeEditWithRestoredMtime(t *testing.T) {
	for _, inSource := range []bool{false, true} {
		name := "target"
		if inSource {
			name = "source"
		}
		t.Run(name, func(t *testing.T) {
			target, desired, legacy := agedFixture(t)
			root := target
			if inSource {
				root = desired
			}
			path := filepath.Join(root, "a/one")
			info, err := os.Stat(path)
			if err != nil {
				t.Fatal(err)
			}
			put(t, root, "a/one", "uno")
			restoreMtime(t, path, info)
			err = Reconcile(target, desired, legacy, "A")
			if inSource {
				if err != nil {
					t.Fatal(err)
				}
				if b, _ := os.ReadFile(filepath.Join(target, "a/one")); string(b) != "uno" {
					t.Fatalf("source edit ignored: %q", b)
				}
				return
			}
			if err == nil || !strings.Contains(err.Error(), "collision") {
				t.Fatalf("target edit not detected: %v", err)
			}
		})
	}
}

func TestStampRejectsSymlinkedAncestor(t *testing.T) {
	target, desired, legacy := agedFixture(t)
	moved := filepath.Join(filepath.Dir(target), "moved")
	if err := os.Rename(filepath.Join(target, "a"), moved); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(moved, filepath.Join(target, "a")); err != nil {
		t.Fatal(err)
	}
	if err := Reconcile(target, desired, legacy, "A"); err == nil || !strings.Contains(err.Error(), "refusing symlink") {
		t.Fatalf("symlinked ancestor accepted: %v", err)
	}
}

func TestStampInterruptedRetirementRecovers(t *testing.T) {
	target, desired, legacy := agedFixture(t)
	if err := os.Remove(filepath.Join(desired, "a/one")); err != nil {
		t.Fatal(err)
	}
	stop := errors.New("interrupted")
	if err := reconcile(target, desired, legacy, "B", func() error { return stop }); !errors.Is(err, stop) {
		t.Fatalf("interruption: %v", err)
	}
	if readManifest(t, target).Applied != nil {
		t.Fatal("journal kept a stale applied stamp")
	}
	if err := Reconcile(target, desired, legacy, "B"); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(target, "a/one")); !os.IsNotExist(err) {
		t.Fatalf("retired file remains: %v", err)
	}
}
