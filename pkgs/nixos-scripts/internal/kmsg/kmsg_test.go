package kmsg

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// touchKmsg creates an empty file standing in for the always-present
// /dev/kmsg device (Write intentionally requires the device to exist).
func touchKmsg(t *testing.T) string {
	t.Helper()
	path := filepath.Join(t.TempDir(), "kmsg")
	if err := os.WriteFile(path, nil, 0o644); err != nil {
		t.Fatalf("touch kmsg: %v", err)
	}
	return path
}

func TestWritePrefixesPriorityAndTerminatesLine(t *testing.T) {
	path := touchKmsg(t)
	w := &Writer{Path: path}

	if err := w.Write(UserNotice, "netconsole-verify: nonce=abc123"); err != nil {
		t.Fatalf("Write: %v", err)
	}
	got, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read: %v", err)
	}
	want := "<13>netconsole-verify: nonce=abc123\n"
	if string(got) != want {
		t.Errorf("got %q, want %q", got, want)
	}
}

func TestWriteAppendsIndependentRecords(t *testing.T) {
	path := touchKmsg(t)
	w := &Writer{Path: path}

	if err := w.Write(UserWarning, "first"); err != nil {
		t.Fatalf("first write: %v", err)
	}
	if err := w.Write(UserWarning, "second"); err != nil {
		t.Fatalf("second write: %v", err)
	}
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read: %v", err)
	}
	lines := strings.Split(strings.TrimSuffix(string(data), "\n"), "\n")
	if len(lines) != 2 || lines[0] != "<12>first" || lines[1] != "<12>second" {
		t.Errorf("unexpected records: %q", data)
	}
}

func TestWriteOpenError(t *testing.T) {
	w := &Writer{Path: filepath.Join(t.TempDir(), "missing", "kmsg")}
	if err := w.Write(UserNotice, "x"); err == nil {
		t.Fatal("expected error for unwritable device path")
	}
}

func TestEmptyPathFallsBackToKmsgDevice(t *testing.T) {
	w := New()
	if w.Path != Path {
		t.Errorf("New().Path = %q, want %q", w.Path, Path)
	}
	w2 := &Writer{}
	if got := w2.device(); got != Path {
		t.Errorf("device() = %q, want %q", got, Path)
	}
}
