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

const stampTool = 2

type fileStat struct {
	Digest  string `json:"digest"`
	Size    int64  `json:"size"`
	MtimeNs int64  `json:"mtime_ns"`
	CtimeNs int64  `json:"ctime_ns"`
	Ino     uint64 `json:"ino"`
}

type stamp struct {
	Tool   int                 `json:"tool"`
	Source string              `json:"source"`
	Files  map[string]fileStat `json:"files"`
}

func newest(info fs.FileInfo, ctimeNs int64) time.Time {
	t := info.ModTime()
	if c := time.Unix(0, ctimeNs); c.After(t) {
		return c
	}
	return t
}

func fingerprint(desired, legacy, revision string) (string, time.Time, error) {
	h := sha256.New()
	fmt.Fprintf(h, "tool=%d\nrevision=%s\n", stampTool, revision)
	var latest time.Time
	for _, root := range []string{desired, legacy} {
		abs, err := filepath.Abs(root)
		if err != nil {
			return "", latest, err
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
			ctime, ino, ok := inodeStat(info)
			if !ok {
				return fmt.Errorf("inode metadata unavailable")
			}
			rel, err := filepath.Rel(root, path)
			if err != nil {
				return err
			}
			if t := newest(info, ctime); t.After(latest) {
				latest = t
			}
			fmt.Fprintf(h, "%s\x00%d\x00%d\x00%d\x00%d\x00%d\n", rel, info.Mode().Type(), info.Size(), info.ModTime().UnixNano(), ctime, ino)
			return nil
		})
		if err != nil {
			return "", latest, err
		}
	}
	return fmt.Sprintf("%x", h.Sum(nil)), latest, nil
}

func upToDate(target, state, source string) bool {
	raw, err := read(state)
	if err != nil {
		return false
	}
	var m manifest
	if json.Unmarshal(raw, &m) != nil || m.Applied == nil || m.Files == nil {
		return false
	}
	s := m.Applied
	if s.Tool != stampTool || s.Source != source || len(m.Files) != len(s.Files) {
		return false
	}
	checked := map[string]bool{}
	for rel, entry := range m.Files {
		recorded, ok := s.Files[rel]
		if !ok || entry.Pending || entry.Digest != recorded.Digest {
			return false
		}
		if !filepath.IsLocal(rel) || filepath.Clean(rel) != rel || reserved(rel) {
			return false
		}
		path := filepath.Join(target, rel)
		if dir := filepath.Dir(path); !checked[dir] {
			if safePath(dir) != nil {
				return false
			}
			checked[dir] = true
			for d := filepath.Dir(dir); d != target && len(d) > len(target) && !checked[d]; d = filepath.Dir(d) {
				checked[d] = true
			}
		}
		info, err := os.Lstat(path)
		if err != nil || !info.Mode().IsRegular() {
			return false
		}
		ctime, ino, ok := inodeStat(info)
		if !ok || info.Size() != recorded.Size || info.ModTime().UnixNano() != recorded.MtimeNs || ctime != recorded.CtimeNs || ino != recorded.Ino {
			return false
		}
	}
	return true
}

func applied(target, source string, sourceLatest time.Time, sourceErr error, final manifest) *stamp {
	cutoff := time.Now().Add(-racyWindow)
	if sourceErr != nil || sourceLatest.After(cutoff) {
		return nil
	}
	s := stamp{Tool: stampTool, Source: source, Files: map[string]fileStat{}}
	for rel, entry := range final.Files {
		info, err := os.Lstat(filepath.Join(target, rel))
		if err != nil || !info.Mode().IsRegular() {
			return nil
		}
		ctime, ino, ok := inodeStat(info)
		if !ok || newest(info, ctime).After(cutoff) {
			return nil
		}
		s.Files[rel] = fileStat{Digest: entry.Digest, Size: info.Size(), MtimeNs: info.ModTime().UnixNano(), CtimeNs: ctime, Ino: ino}
	}
	return &s
}
