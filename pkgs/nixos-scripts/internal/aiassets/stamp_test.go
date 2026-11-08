package aiassets

import (
	"encoding/json"
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
	if os.Geteuid() == 0 {
		t.Skip("permission bits do not apply to root")
	}
	noRacyWindow(t)
	target, desired, legacy := stampFixture(t)
	if err := Reconcile(target, desired, legacy, "A"); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(target, stampName)); err != nil {
		t.Fatalf("stamp missing after success: %v", err)
	}
	unreadable := filepath.Join(desired, "a/one")
	if err := os.Chmod(unreadable, 0); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { os.Chmod(unreadable, 0644) })
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
	target, desired, legacy := stampFixture(t)
	if err := Reconcile(target, desired, legacy, "A"); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(target, stampName)); !os.IsNotExist(err) {
		t.Fatalf("stamp written while files are inside the racy window: %v", err)
	}
	old := time.Now().Add(-time.Hour)
	for _, dir := range []string{target, desired} {
		filepath.WalkDir(dir, func(path string, d os.DirEntry, err error) error {
			if err == nil && !d.IsDir() {
				os.Chtimes(path, old, old)
			}
			return nil
		})
	}
	if err := Reconcile(target, desired, legacy, "A"); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(target, stampName)); err != nil {
		t.Fatalf("stamp missing once files left the racy window: %v", err)
	}
}

func TestSourceMayNotContainStamp(t *testing.T) {
	target, desired, legacy := stampFixture(t)
	put(t, desired, stampName, "{}")
	if err := Reconcile(target, desired, legacy, "A"); err == nil {
		t.Fatal("source with reserved stamp accepted")
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
