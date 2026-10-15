package opencodelayout

import (
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
)

const legacyName = "opencode-" + "v2"

func TestMigrateNothingIsNoop(t *testing.T) {
	home := t.TempDir()
	got, err := Migrate(home, false)
	if err != nil || !strings.Contains(got, "nothing to migrate") {
		t.Fatalf("Migrate = %q, %v", got, err)
	}
}

func TestFullMigrationAndSecondRunNoop(t *testing.T) {
	home := t.TempDir()
	files := map[string]string{
		".config/" + legacyName + "/opencode.jsonc":       "config",
		".config/" + legacyName + "/service.json":         "service",
		".config/" + legacyName + "/junk":                 "junk",
		".config/opencode-back/old":                       "v1",
		".local/" + legacyName + "/data/opencode.db":      "db",
		".local/" + legacyName + "/data/opencode.db-wal":  "wal",
		".local/" + legacyName + "/data/opencode.db-shm":  "shm",
		".local/" + legacyName + "/data/opencode/session": "session",
		".local/" + legacyName + "/state/opencode/state":  "state",
		".local/" + legacyName + "/tmp/junk":              "tmp",
		".config/opencode/v1":                             "v1",
	}
	for name, value := range files {
		write(t, home, name, value)
	}
	if _, err := Migrate(home, false); err != nil {
		t.Fatal(err)
	}
	for src, value := range map[string]string{
		".config/opencode/opencode.jsonc": "config", ".config/opencode/service.json": "service",
		".local/share/opencode/opencode.db": "db", ".local/share/opencode/opencode.db-wal": "wal",
		".local/share/opencode/opencode.db-shm": "shm", ".local/share/opencode/session": "session",
		".local/state/opencode/state": "state",
	} {
		if got := read(t, home, src); got != value {
			t.Errorf("%s = %q", src, got)
		}
	}
	for _, root := range []string{".config/" + legacyName, ".local/" + legacyName, ".local/share/" + legacyName} {
		if _, err := os.Lstat(filepath.Join(home, root)); !os.IsNotExist(err) {
			t.Errorf("old root remains %s: %v", root, err)
		}
	}
	archive := filepath.Join(home, ".local/share/opencode-migration-archive")
	entries, err := os.ReadDir(archive)
	if err != nil || len(entries) != 1 {
		t.Fatalf("archive entries = %v, %v", entries, err)
	}
	for name, value := range map[string]string{"old/.config/" + legacyName + "/junk": "junk", "old/.local/" + legacyName + "/tmp/junk": "tmp", "previous/.config/opencode/v1": "v1", "previous/.config/opencode-back/old": "v1"} {
		if got := read(t, filepath.Join(archive, entries[0].Name()), name); got != value {
			t.Errorf("archive %s = %q", name, got)
		}
	}
	if got, err := Migrate(home, false); err != nil || !strings.Contains(got, "nothing to migrate") {
		t.Fatalf("second run = %q, %v", got, err)
	}
}

func TestLiveServerRefusesWithoutChanges(t *testing.T) {
	home := t.TempDir()
	write(t, home, ".local/"+legacyName+"/state/opencode/service.json", `{"pid":`+itoa(os.Getpid())+`}`)
	write(t, home, ".local/"+legacyName+"/data/opencode.db", "database")
	_, err := Migrate(home, false)
	if err == nil || !strings.Contains(err.Error(), "stop") {
		t.Fatalf("Migrate error = %v", err)
	}
	if got := read(t, home, ".local/"+legacyName+"/data/opencode.db"); got != "database" {
		t.Fatalf("data changed: %q", got)
	}
}

func TestUnexpectedDestinationIsNotOverwritten(t *testing.T) {
	archive := t.TempDir()
	source := filepath.Join(t.TempDir(), "source")
	target := filepath.Join(t.TempDir(), "target")
	if err := os.WriteFile(source, []byte("source"), 0600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(target, []byte("destination"), 0600); err != nil {
		t.Fatal(err)
	}
	if _, err := moveStep(archive, source, target); err == nil {
		t.Fatal("accepted unexpected destination")
	}
	if got, err := os.ReadFile(target); err != nil || string(got) != "destination" {
		t.Fatalf("destination changed: %q, %v", got, err)
	}
}

func TestMoveResumesAfterRenameBeforeJournalCompletion(t *testing.T) {
	archive := t.TempDir()
	base := t.TempDir()
	source, target := filepath.Join(base, "source"), filepath.Join(base, "target")
	if err := os.WriteFile(source, []byte("payload"), 0600); err != nil {
		t.Fatal(err)
	}
	clean := filepath.Clean(source)
	rel := strings.TrimPrefix(clean, string(filepath.Separator))
	key := filepath.Join(archive, ".steps", strconv.Itoa(len(strings.Split(clean, string(filepath.Separator))))+"-"+strings.NewReplacer("/", "_", "\\", "_").Replace(rel))
	if err := os.MkdirAll(filepath.Dir(key), 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(key, []byte("intent"), 0600); err != nil {
		t.Fatal(err)
	}
	if _, err := moveStep(archive, source, target); err != nil {
		t.Fatal(err)
	}
	if got := read(t, base, "target"); got != "payload" {
		t.Fatalf("resumed target=%q", got)
	}
}

func TestMigrateResumesExistingIncompleteArchive(t *testing.T) {
	home := t.TempDir()
	archive := filepath.Join(home, ".local", "share", "opencode-migration-archive", "20260101T000000Z")
	if err := os.MkdirAll(archive, 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(archive, ".incomplete"), nil, 0600); err != nil {
		t.Fatal(err)
	}
	write(t, home, ".config/"+legacyName+"/opencode.jsonc", "config")
	if _, err := Migrate(home, false); err != nil {
		t.Fatal(err)
	}
	entries, err := os.ReadDir(filepath.Join(home, ".local", "share", "opencode-migration-archive"))
	if err != nil || len(entries) != 1 || entries[0].Name() != "20260101T000000Z" {
		t.Fatalf("archives = %v, %v", entries, err)
	}
	if got := read(t, home, ".config/opencode/opencode.jsonc"); got != "config" {
		t.Fatalf("resumed config = %q", got)
	}
}

func TestRetireOpenfangSkills(t *testing.T) {
	for _, manifest := range []bool{false, true} {
		t.Run(map[bool]string{false: "without manifest", true: "with manifest"}[manifest], func(t *testing.T) {
			home := t.TempDir()
			write(t, home, ".openfang/skills/item", "skill")
			if manifest {
				write(t, home, ".openfang/.gentle-ai-owned.json", "{}")
			}
			_, err := Migrate(home, true)
			if err != nil {
				t.Fatal(err)
			}
			_, skillErr := os.Stat(filepath.Join(home, ".openfang/skills/item"))
			if manifest && skillErr != nil {
				t.Fatal("manifest-owned skills moved")
			}
			if !manifest && !os.IsNotExist(skillErr) {
				t.Fatal("unowned skills not retired")
			}
		})
	}
}

func write(t *testing.T, root, name, value string) {
	t.Helper()
	path := filepath.Join(root, name)
	if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(value), 0600); err != nil {
		t.Fatal(err)
	}
}
func read(t *testing.T, root, name string) string {
	t.Helper()
	b, err := os.ReadFile(filepath.Join(root, name))
	if err != nil {
		t.Fatal(err)
	}
	return string(b)
}
func itoa(n int) string { return strconv.Itoa(n) }

func TestResumeAfterPartialRunKeepsMigratedDataNative(t *testing.T) {
	for _, withV1 := range []bool{false, true} {
		t.Run(strconv.FormatBool(withV1), func(t *testing.T) {
			if os.Geteuid() == 0 {
				t.Skip("permission-based interruption needs a non-root user")
			}
			home := t.TempDir()
			write(t, home, ".local/"+legacyName+"/data/opencode.db", "db")
			write(t, home, ".local/"+legacyName+"/data/opencode/session", "session")
			write(t, home, ".local/"+legacyName+"/state/opencode/state", "state")
			if withV1 {
				write(t, home, ".local/share/opencode/v1", "v1")
			}
			state := filepath.Join(home, ".local/state")
			if err := os.MkdirAll(state, 0o755); err != nil {
				t.Fatal(err)
			}
			if err := os.Chmod(state, 0o555); err != nil {
				t.Fatal(err)
			}
			if _, err := Migrate(home, false); err == nil {
				t.Fatal("expected interrupted run to fail")
			}
			if err := os.Chmod(state, 0o755); err != nil {
				t.Fatal(err)
			}
			if _, err := Migrate(home, false); err != nil {
				t.Fatalf("resume failed: %v", err)
			}
			for path, want := range map[string]string{
				".local/share/opencode/opencode.db": "db",
				".local/share/opencode/session":     "session",
				".local/state/opencode/state":       "state",
			} {
				if got := read(t, home, path); got != want {
					t.Errorf("%s = %q, want %q", path, got, want)
				}
			}
			if _, err := Migrate(home, false); err != nil {
				t.Fatalf("third run: %v", err)
			}
		})
	}
}
