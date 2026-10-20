package opencodelayout

import (
	"crypto/sha256"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
)

func TestMovePreservesPayloadsAndRetries(t *testing.T) {
	for _, intent := range []bool{false, true} {
		for _, targetExists := range []bool{false, true} {
			d := t.TempDir()
			archive := filepath.Join(d, "archive")
			source := filepath.Join(d, "source")
			target := filepath.Join(d, "target")
			key := filepath.Join(archive, ".steps", strconv.Itoa(len(strings.Split(filepath.Clean(source), string(filepath.Separator))))+"-"+strings.NewReplacer("/", "_", "\\", "_").Replace(strings.TrimPrefix(filepath.Clean(source), string(filepath.Separator))))
			write := func(p, s string) {
				t.Helper()
				if err := os.MkdirAll(filepath.Dir(p), 0700); err != nil {
					t.Fatal(err)
				}
				if err := os.WriteFile(p, []byte(s), 0600); err != nil {
					t.Fatal(err)
				}
			}
			hash := func(p string) [32]byte {
				t.Helper()
				b, err := os.ReadFile(p)
				if err != nil {
					t.Fatal(err)
				}
				return sha256.Sum256(b)
			}
			if intent {
				write(key, source+"\n"+target)
			}
			if targetExists {
				write(target, "destination")
			}
			if moved, err := moveStep(archive, source, target); moved || err != nil {
				t.Fatalf("absent: %v %v", moved, err)
			}
			write(source, "source payload")
			before := hash(source)
			if targetExists {
				dest := hash(target)
				moved, err := moveStep(archive, source, target)
				if moved || err == nil || err.Error() != "refusing to overwrite migration destination "+target {
					t.Fatalf("collision: %v %v", moved, err)
				}
				if before != hash(source) || dest != hash(target) {
					t.Fatal("rejection mutated data")
				}
			} else {
				if moved, err := moveStep(archive, source, target); !moved || err != nil {
					t.Fatalf("move: %v %v", moved, err)
				}
				if hash(target) != before {
					t.Fatal("changed payload")
				}
				if moved, err := moveStep(archive, source, target); moved || err != nil {
					t.Fatalf("retry: %v %v", moved, err)
				}
			}
		}
	}
}
