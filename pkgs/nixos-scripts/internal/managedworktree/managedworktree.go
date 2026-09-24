// Package managedworktree stores the portable lifecycle state for managed
// writing worktrees. State lives in the Git common directory, so linked
// worktrees share one lock and one view of each task.
package managedworktree

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"
)

type State string

const (
	Active     State = "active"
	Ready      State = "ready-for-integration"
	Integrated State = "integrated"
	Abandoned  State = "abandoned"
)

type Record struct {
	ID         string    `json:"id"`
	Branch     string    `json:"branch"`
	Path       string    `json:"path"`
	BaseBranch string    `json:"baseBranch"`
	BaseCommit string    `json:"baseCommit"`
	State      State     `json:"state"`
	CreatedAt  time.Time `json:"createdAt"`
	UpdatedAt  time.Time `json:"updatedAt"`
}

var taskIDRe = regexp.MustCompile(`^[a-z0-9][a-z0-9-]{0,62}$`)

func ValidTaskID(id string) bool     { return taskIDRe.MatchString(id) }
func BranchFor(id string) string     { return "managed/" + id }
func PathFor(repo, id string) string { return filepath.Join(repo, ".worktrees", "managed", id) }

func recordPath(stateDir, id string) string { return filepath.Join(stateDir, id+".json") }

func SaveRecord(stateDir string, record Record) error {
	if !ValidTaskID(record.ID) {
		return fmt.Errorf("invalid task id %q", record.ID)
	}
	if err := os.MkdirAll(stateDir, 0o755); err != nil {
		return err
	}
	data, err := json.MarshalIndent(record, "", "  ")
	if err != nil {
		return err
	}
	tmp, err := os.CreateTemp(stateDir, ".record-*")
	if err != nil {
		return err
	}
	tmpName := tmp.Name()
	defer os.Remove(tmpName)
	if err = tmp.Chmod(0o644); err == nil {
		_, err = tmp.Write(append(data, '\n'))
	}
	if closeErr := tmp.Close(); err == nil {
		err = closeErr
	}
	if err != nil {
		return err
	}
	return os.Rename(tmpName, recordPath(stateDir, record.ID))
}

func LoadRecord(stateDir, id string) (Record, error) {
	var record Record
	if !ValidTaskID(id) {
		return record, fmt.Errorf("invalid task id %q", id)
	}
	data, err := os.ReadFile(recordPath(stateDir, id))
	if err != nil {
		return record, err
	}
	err = json.Unmarshal(data, &record)
	return record, err
}

// ResolveTaskID returns the task whose recorded worktree path exactly matches
// cwd. It intentionally does not infer from a parent directory so legacy
// worktrees named managed or managed-* cannot be mistaken for managed tasks.
func ResolveTaskID(stateDir, cwd string) (string, error) {
	entries, err := os.ReadDir(stateDir)
	if errors.Is(err, os.ErrNotExist) {
		return "", fmt.Errorf("not inside a managed worktree")
	}
	if err != nil {
		return "", err
	}
	for _, entry := range entries {
		if entry.IsDir() || !strings.HasSuffix(entry.Name(), ".json") {
			continue
		}
		id := strings.TrimSuffix(entry.Name(), ".json")
		record, err := LoadRecord(stateDir, id)
		if err != nil {
			return "", fmt.Errorf("read managed task %q: %w", id, err)
		}
		if record.ID != id || !ValidTaskID(record.ID) || record.Path == "" {
			return "", fmt.Errorf("managed task record %q is invalid", id)
		}
		if filepath.Clean(record.Path) == filepath.Clean(cwd) {
			return record.ID, nil
		}
	}
	return "", fmt.Errorf("not inside a managed worktree")
}

func Transition(record *Record, next State) error {
	allowed := (record.State == Active && (next == Ready || next == Abandoned)) ||
		(record.State == Ready && (next == Integrated || next == Abandoned))
	if !allowed {
		return fmt.Errorf("invalid lifecycle transition %q -> %q", record.State, next)
	}
	record.State = next
	record.UpdatedAt = time.Now().UTC()
	return nil
}

type Lock struct{ path string }

func AcquireLock(stateDir string, timeout time.Duration) (*Lock, error) {
	if err := os.MkdirAll(stateDir, 0o755); err != nil {
		return nil, err
	}
	path := filepath.Join(stateDir, ".lock")
	deadline := time.Now().Add(timeout)
	for {
		if err := os.Mkdir(path, 0o755); err == nil {
			return &Lock{path: path}, nil
		} else if !errors.Is(err, os.ErrExist) {
			return nil, err
		}
		if timeout <= 0 || time.Now().After(deadline) {
			return nil, fmt.Errorf("managed lifecycle lock is busy")
		}
		time.Sleep(10 * time.Millisecond)
	}
}

func (l *Lock) Release() error {
	if l == nil {
		return nil
	}
	return os.Remove(l.path)
}
