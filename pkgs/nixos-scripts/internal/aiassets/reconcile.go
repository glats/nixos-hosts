package aiassets

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"syscall"
)

const manifestName = ".gentle-ai-owned.json"
const lockName = ".gentle-ai-owned.lock"

type owned struct {
	Digest   string    `json:"digest"`
	Revision string    `json:"revision"`
	Before   []byte    `json:"before"`
	Pending  bool      `json:"pending,omitempty"`
	Prior    *snapshot `json:"prior,omitempty"`
}

type snapshot struct {
	Exists bool   `json:"exists"`
	Digest string `json:"digest,omitempty"`
}

func observed(b []byte, err error) snapshot {
	if os.IsNotExist(err) {
		return snapshot{}
	}
	return snapshot{Exists: true, Digest: digest(b)}
}
func unchanged(path string, expected snapshot) error {
	b, err := read(path)
	if err != nil && !os.IsNotExist(err) {
		return err
	}
	if observed(b, err) != expected {
		return fmt.Errorf("asset changed after preflight: %s", path)
	}
	return nil
}

type manifest struct {
	Schema int              `json:"schema"`
	Files  map[string]owned `json:"files"`
}

func digest(b []byte) string { h := sha256.Sum256(b); return hex.EncodeToString(h[:]) }

func safePath(path string) error {
	abs, err := filepath.Abs(path)
	if err != nil {
		return err
	}
	for p := abs; ; p = filepath.Dir(p) {
		info, err := os.Lstat(p)
		if err != nil && !os.IsNotExist(err) {
			return err
		}
		if err == nil && info.Mode()&os.ModeSymlink != 0 {
			return fmt.Errorf("refusing symlink: %s", p)
		}
		if p == filepath.Dir(p) {
			return nil
		}
	}
}
func tree(root string) (map[string][]byte, error) {
	files := map[string][]byte{}
	if err := safePath(root); err != nil {
		return nil, err
	}
	err := filepath.WalkDir(root, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() {
			return nil
		}
		if !d.Type().IsRegular() {
			return fmt.Errorf("nonregular source: %s", path)
		}
		rel, err := filepath.Rel(root, path)
		if err != nil {
			return err
		}
		if rel == manifestName || rel == lockName {
			return fmt.Errorf("source contains reserved manifest")
		}
		b, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		files[rel] = b
		return nil
	})
	return files, err
}
func read(path string) ([]byte, error) {
	if err := safePath(path); err != nil {
		return nil, err
	}
	info, err := os.Lstat(path)
	if err != nil {
		return nil, err
	}
	if !info.Mode().IsRegular() {
		return nil, fmt.Errorf("nonregular target: %s", path)
	}
	return os.ReadFile(path)
}
func write(path string, b []byte, expected snapshot) error {
	if err := safePath(path); err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
		return err
	}
	f, err := os.CreateTemp(filepath.Dir(path), ".gentle-ai-write-")
	if err != nil {
		return err
	}
	name := f.Name()
	defer os.Remove(name)
	if _, err = f.Write(b); err == nil {
		err = f.Sync()
	}
	closeErr := f.Close()
	if err != nil {
		return err
	}
	if closeErr != nil {
		return closeErr
	}
	if err := os.Chmod(name, 0644); err != nil {
		return err
	}

	if err := unchanged(path, expected); err != nil {
		return err
	}
	if !expected.Exists {

		return os.Link(name, path)
	}
	return os.Rename(name, path)
}

func Reconcile(target, desired, legacy, revision string) error {
	return reconcile(target, desired, legacy, revision, nil)
}

func reconcile(target, desired, legacy, revision string, afterJournal func() error) error {
	if revision == "" {
		return fmt.Errorf("source revision required")
	}
	if err := safePath(target); err != nil {
		return err
	}
	if err := os.MkdirAll(target, 0755); err != nil {
		return err
	}
	lockPath := filepath.Join(target, lockName)
	if err := safePath(lockPath); err != nil {
		return err
	}
	lock, err := os.OpenFile(lockPath, os.O_CREATE|os.O_RDWR|syscall.O_NOFOLLOW|syscall.O_NONBLOCK, 0600)
	if err != nil {
		return err
	}
	defer lock.Close()
	info, err := lock.Stat()
	if err != nil {
		return err
	}
	if !info.Mode().IsRegular() {
		return fmt.Errorf("nonregular ownership lock")
	}
	if err := syscall.Flock(int(lock.Fd()), syscall.LOCK_EX); err != nil {
		return err
	}
	defer syscall.Flock(int(lock.Fd()), syscall.LOCK_UN)

	if err := safePath(lockPath); err != nil {
		return err
	}
	pathInfo, err := os.Lstat(lockPath)
	if err != nil {
		return err
	}
	if !os.SameFile(info, pathInfo) {
		return fmt.Errorf("ownership lock replaced")
	}
	want, err := tree(desired)
	if err != nil {
		return err
	}
	old, err := tree(legacy)
	if err != nil {
		return err
	}
	m := manifest{Schema: 2, Files: map[string]owned{}}
	state := filepath.Join(target, manifestName)
	b, err := read(state)
	stateExpected := observed(b, err)
	if err == nil {
		if err := json.Unmarshal(b, &m); err != nil {
			return fmt.Errorf("ownership manifest: %w", err)
		}
		if (m.Schema != 1 && m.Schema != 2) || m.Files == nil {
			return fmt.Errorf("unknown ownership manifest")
		}
	} else if !os.IsNotExist(err) {
		return err
	}
	for rel, body := range old {
		if _, known := m.Files[rel]; known {
			continue
		}
		current, err := read(filepath.Join(target, rel))
		if os.IsNotExist(err) {
			continue
		}
		if err != nil {
			return err
		}
		if _, keep := want[rel]; !keep && digest(current) != digest(body) {
			return fmt.Errorf("modified legacy retirement requires explicit reconciliation: %s", rel)
		}
		if digest(current) == digest(body) {
			m.Files[rel] = owned{Digest: digest(body), Revision: "f5dd1a6cf1823371374c7b2bef5b71e4790a146a/consumer-4750736c", Before: body}
		}
	}
	for rel := range m.Files {
		if !filepath.IsLocal(rel) || filepath.Clean(rel) != rel || rel == manifestName || rel == lockName {
			return fmt.Errorf("invalid owned path: %s", rel)
		}
	}
	removals := []string{}
	next := manifest{Schema: 2, Files: map[string]owned{}}
	expected := map[string]snapshot{}
	for rel, entry := range m.Files {
		if _, keep := want[rel]; keep {
			continue
		}
		current, err := read(filepath.Join(target, rel))
		if os.IsNotExist(err) {
			continue
		}
		if err != nil {
			return err
		}
		if digest(current) != entry.Digest {
			return fmt.Errorf("modified managed retirement requires explicit reconciliation: %s", rel)
		}
		removals = append(removals, rel)
		next.Files[rel] = entry
	}
	for rel, body := range want {
		path := filepath.Join(target, rel)
		current, err := read(path)
		if err != nil && !os.IsNotExist(err) {
			return err
		}
		entry, known := m.Files[rel]
		currentState := observed(current, err)
		if entry.Pending && (entry.Prior == nil || entry.Digest != digest(body) || entry.Revision != revision) {
			return fmt.Errorf("finish pending asset generation before changing it: %s", path)
		}
		if entry.Pending && currentState != *entry.Prior && (!currentState.Exists || currentState.Digest != entry.Digest) {
			return fmt.Errorf("pending asset changed: %s", path)
		}

		if err == nil && (!known || (digest(current) != entry.Digest && !(entry.Pending && currentState == *entry.Prior))) {
			return fmt.Errorf("unowned or modified asset collision: %s", path)
		}
		before := entry.Before
		if !known && err == nil {
			before = current
		}
		expected[rel] = currentState
		next.Files[rel] = owned{Digest: digest(body), Revision: revision, Before: before, Pending: true, Prior: &currentState}
	}

	encoded, err := json.MarshalIndent(next, "", "  ")
	if err != nil {
		return err
	}
	if err := write(state, encoded, stateExpected); err != nil {
		return err
	}
	if afterJournal != nil {
		if err := afterJournal(); err != nil {
			return err
		}
	}
	for rel, body := range want {
		if err := write(filepath.Join(target, rel), body, expected[rel]); err != nil {
			return err
		}
	}
	for _, rel := range removals {
		path := filepath.Join(target, rel)
		current, err := read(path)
		if os.IsNotExist(err) {
			continue
		}
		if err != nil {
			return err
		}
		if digest(current) != m.Files[rel].Digest {
			return fmt.Errorf("asset changed after preflight: %s", path)
		}
		if err := os.Remove(path); err != nil {
			return err
		}
		for dir := filepath.Dir(path); dir != target; dir = filepath.Dir(dir) {
			if err := os.Remove(dir); err != nil {
				if errors.Is(err, os.ErrNotExist) || errors.Is(err, syscall.ENOTEMPTY) || errors.Is(err, syscall.EEXIST) {
					break
				}
				return err
			}
		}
	}

	for _, rel := range removals {
		delete(next.Files, rel)
	}
	for rel, entry := range next.Files {
		entry.Pending = false
		entry.Prior = nil
		next.Files[rel] = entry
	}
	complete, err := json.MarshalIndent(next, "", "  ")
	if err != nil {
		return err
	}
	return write(state, complete, snapshot{Exists: true, Digest: digest(encoded)})
}
