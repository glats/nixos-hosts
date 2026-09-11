package rtkinit

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestUpsertAndCheck(t *testing.T) {
	cases := []struct {
		name, initial string
		want          Result
	}{
		{"fresh", "", Added},
		{"append", "# Existing\n", Added},
		{"identical", Block() + "\n", Unchanged},
		{"stale", "before\n" + openMarker + "\nold\n" + closeMarker + "\nafter\n", Updated},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			path := filepath.Join(t.TempDir(), "AGENTS.md")
			if err := os.WriteFile(path, []byte(tc.initial), 0o640); err != nil {
				t.Fatal(err)
			}
			got, err := Upsert(path, false)
			if err != nil || got != tc.want {
				t.Fatalf("Upsert = %q, %v; want %q", got, err, tc.want)
			}
			if err := Check(path); err != nil {
				t.Fatalf("Check: %v", err)
			}
			before, _ := os.ReadFile(path)
			got, err = Upsert(path, false)
			if err != nil || got != Unchanged {
				t.Fatalf("second Upsert = %q, %v", got, err)
			}
			after, _ := os.ReadFile(path)
			if string(before) != string(after) {
				t.Fatal("second upsert changed bytes")
			}
			if mode, _ := os.Stat(path); mode.Mode().Perm() != 0o640 {
				t.Fatalf("mode = %o", mode.Mode().Perm())
			}
		})
	}
}

func TestMalformedRefusesAndRemove(t *testing.T) {
	path := filepath.Join(t.TempDir(), "AGENTS.md")
	malformed := "keep\n" + openMarker + "\nno close\n"
	if err := os.WriteFile(path, []byte(malformed), 0o644); err != nil {
		t.Fatal(err)
	}
	if _, err := Upsert(path, false); err == nil {
		t.Fatal("malformed upsert succeeded")
	}
	got, _ := os.ReadFile(path)
	if string(got) != malformed {
		t.Fatal("malformed file changed")
	}
	if err := os.WriteFile(path, []byte("before\n"+Block()+"\nafter\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if _, err := Remove(path, false); err != nil {
		t.Fatal(err)
	}
	got, _ = os.ReadFile(path)
	if string(got) != "before\nafter\n" {
		t.Fatalf("remove = %q", got)
	}
}

func TestCheckReasons(t *testing.T) {
	path := filepath.Join(t.TempDir(), "AGENTS.md")
	if err := os.WriteFile(path, []byte("plain\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := Check(path); err == nil || !strings.Contains(err.Error(), "missing") {
		t.Fatalf("missing error = %v", err)
	}
	if err := os.WriteFile(path, []byte(openMarker+"\nold\n"+closeMarker), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := Check(path); err == nil || !strings.Contains(err.Error(), "stale") {
		t.Fatalf("stale error = %v", err)
	}
	if _, err := Upsert(path, true); err != nil {
		t.Fatal(err)
	}
	got, _ := os.ReadFile(path)
	if strings.Contains(string(got), Block()) {
		t.Fatal("dry-run modified file")
	}
}
