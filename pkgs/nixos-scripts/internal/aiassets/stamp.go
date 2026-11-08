package aiassets

import (
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"time"
)

const stampTool = 1

type fileStat struct {
	Size    int64 `json:"size"`
	MtimeNs int64 `json:"mtime_ns"`
}

type stamp struct {
	Tool     int                 `json:"tool"`
	Source   string              `json:"source"`
	Manifest string              `json:"manifest"`
	Files    map[string]fileStat `json:"files"`
}

func fingerprint(desired, legacy, revision string) (string, time.Time, error) {
	h := sha256.New()
	fmt.Fprintf(h, "tool=%d\nrevision=%s\n", stampTool, revision)
	var newest time.Time
	for _, root := range []string{desired, legacy} {
		abs, err := filepath.Abs(root)
		if err != nil {
			return "", newest, err
		}
		fmt.Fprintf(h, "root=%s\n", abs)
		err = filepath.WalkDir(root, func(path string, d fs.DirEntry, err error) error {
			if err != nil {
				return err
			}
			if d.IsDir() {
				return nil
			}
			info, err := d.Info()
			if err != nil {
				return err
			}
			rel, err := filepath.Rel(root, path)
			if err != nil {
				return err
			}
			if info.ModTime().After(newest) {
				newest = info.ModTime()
			}
			fmt.Fprintf(h, "%s\x00%d\x00%d\x00%d\n", rel, info.Mode().Type(), info.Size(), info.ModTime().UnixNano())
			return nil
		})
		if err != nil {
			return "", newest, err
		}
	}
	return fmt.Sprintf("%x", h.Sum(nil)), newest, nil
}

func upToDate(target, stampPath, state, source string) bool {
	raw, err := read(stampPath)
	if err != nil {
		return false
	}
	var s stamp
	if json.Unmarshal(raw, &s) != nil || s.Tool != stampTool || s.Source != source {
		return false
	}
	manifestBytes, err := read(state)
	if err != nil || digest(manifestBytes) != s.Manifest {
		return false
	}
	var m manifest
	if json.Unmarshal(manifestBytes, &m) != nil || m.Files == nil || len(m.Files) != len(s.Files) {
		return false
	}
	for rel, entry := range m.Files {
		if entry.Pending {
			return false
		}
		recorded, ok := s.Files[rel]
		if !ok || !filepath.IsLocal(rel) || filepath.Clean(rel) != rel || reserved(rel) {
			return false
		}
		info, err := os.Lstat(filepath.Join(target, rel))
		if err != nil || !info.Mode().IsRegular() || info.Size() != recorded.Size || info.ModTime().UnixNano() != recorded.MtimeNs {
			return false
		}
	}
	return true
}

func saveStamp(target, stampPath, source string, sourceNewest time.Time, manifestBytes []byte, final manifest) error {
	cutoff := time.Now().Add(-racyWindow)
	if sourceNewest.After(cutoff) {
		return nil
	}
	s := stamp{Tool: stampTool, Source: source, Manifest: digest(manifestBytes), Files: map[string]fileStat{}}
	for rel := range final.Files {
		info, err := os.Lstat(filepath.Join(target, rel))
		if err != nil || !info.Mode().IsRegular() || info.ModTime().After(cutoff) {
			return nil
		}
		s.Files[rel] = fileStat{Size: info.Size(), MtimeNs: info.ModTime().UnixNano()}
	}
	encoded, err := json.Marshal(s)
	if err != nil || safePath(stampPath) != nil {
		return nil
	}
	f, err := os.CreateTemp(target, ".gentle-ai-stamp-")
	if err != nil {
		return nil
	}
	name := f.Name()
	defer os.Remove(name)
	_, err = f.Write(encoded)
	if closeErr := f.Close(); err != nil || closeErr != nil {
		return nil
	}
	if os.Chmod(name, 0644) != nil {
		return nil
	}
	os.Rename(name, stampPath)
	return nil
}
