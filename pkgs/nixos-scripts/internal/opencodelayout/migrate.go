package opencodelayout

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"
)

// Migrate moves legacy user data into native XDG locations and archives every
// unrelated file. It is safe to repeat after any completed rename.
func Migrate(home string, retireOpenfang bool) (string, error) {
	home, err := filepath.Abs(home)
	if err != nil {
		return "", err
	}
	legacyName := "opencode-" + "v2"
	configOld, runtimeOld, envOld := filepath.Join(home, ".config", legacyName), filepath.Join(home, ".local", legacyName), filepath.Join(home, ".local", "share", legacyName)
	openfang := filepath.Join(home, ".openfang", "skills")
	retire := false
	if retireOpenfang && exists(openfang) && !exists(filepath.Join(home, ".openfang", ".gentle-ai-owned.json")) {
		retire = true
	}
	old := exists(configOld) || exists(runtimeOld) || exists(envOld)
	archive, err := activeArchive(home)
	if err != nil {
		return "", err
	}
	if archive == "" && !old && !retire {
		return "nothing to migrate", nil
	}
	if err := refuseRunningServer(runtimeOld); err != nil {
		return "", err
	}
	if archive == "" {
		stamp := time.Now().UTC().Truncate(time.Second)
		archive = filepath.Join(home, ".local", "share", "opencode-migration-archive", stamp.Format("20060102T150405Z"))
		for exists(archive) {
			stamp = stamp.Add(time.Second)
			archive = filepath.Join(home, ".local", "share", "opencode-migration-archive", stamp.Format("20060102T150405Z"))
		}
		if err := os.MkdirAll(archive, 0700); err != nil {
			return "", err
		}
		if err := os.WriteFile(filepath.Join(archive, ".incomplete"), nil, 0600); err != nil {
			return "", err
		}
	}
	var moved []string
	move := func(source, target string) error {
		did, err := moveStep(archive, source, target)
		if did {
			moved = append(moved, source+" -> "+target)
		}
		return err
	}
	for _, rel := range []string{".config/opencode", ".local/share/opencode", ".local/state/opencode", ".cache/opencode", ".config/opencode-back"} {
		if err := move(filepath.Join(home, rel), filepath.Join(archive, "previous", rel)); err != nil {
			return "", err
		}
	}
	if retire {
		if err := move(openfang, filepath.Join(archive, "previous", ".openfang", "skills")); err != nil {
			return "", err
		}
	}
	for _, pair := range [][2]string{
		{filepath.Join(runtimeOld, "data", "opencode"), filepath.Join(home, ".local", "share", "opencode")},
		{filepath.Join(runtimeOld, "data", "opencode.db"), filepath.Join(home, ".local", "share", "opencode", "opencode.db")},
		{filepath.Join(runtimeOld, "data", "opencode.db-wal"), filepath.Join(home, ".local", "share", "opencode", "opencode.db-wal")},
		{filepath.Join(runtimeOld, "data", "opencode.db-shm"), filepath.Join(home, ".local", "share", "opencode", "opencode.db-shm")},
		{filepath.Join(runtimeOld, "state", "opencode"), filepath.Join(home, ".local", "state", "opencode")},
		{filepath.Join(configOld, "opencode.jsonc"), filepath.Join(home, ".config", "opencode", "opencode.jsonc")},
		{filepath.Join(configOld, "service.json"), filepath.Join(home, ".config", "opencode", "service.json")},
	} {
		if err := move(pair[0], pair[1]); err != nil {
			return "", err
		}
	}
	for _, root := range []string{configOld, runtimeOld, envOld} {
		if err := archiveRemainder(archive, home, root, &moved); err != nil {
			return "", err
		}
	}
	if err := os.Remove(filepath.Join(archive, ".incomplete")); err != nil && !os.IsNotExist(err) {
		return "", err
	}
	if len(moved) == 0 {
		return "nothing to migrate", nil
	}
	return fmt.Sprintf("migrated %d item(s) into native OpenCode paths; archived remaining legacy data under %s", len(moved), archive), nil
}

func refuseRunningServer(runtime string) error {
	path := filepath.Join(runtime, "state", "opencode", "service.json")
	b, err := os.ReadFile(path)
	if os.IsNotExist(err) {
		return nil
	}
	if err != nil {
		return err
	}
	var service struct {
		PID int `json:"pid"`
	}
	if err = json.Unmarshal(b, &service); err != nil {
		return fmt.Errorf("read old-layout service pid: %w", err)
	}
	if service.PID <= 0 {
		return nil
	}
	err = syscall.Kill(service.PID, 0)
	if err == nil || err == syscall.EPERM {
		return fmt.Errorf("OpenCode server pid %d from the old layout is running; stop it (kill %d) and re-run activation", service.PID, service.PID)
	}
	return nil
}

func activeArchive(home string) (string, error) {
	root := filepath.Join(home, ".local", "share", "opencode-migration-archive")
	entries, err := os.ReadDir(root)
	if os.IsNotExist(err) {
		return "", nil
	}
	if err != nil {
		return "", err
	}
	for i := len(entries) - 1; i >= 0; i-- {
		p := filepath.Join(root, entries[i].Name())
		if entries[i].IsDir() && exists(filepath.Join(p, ".incomplete")) {
			return p, nil
		}
	}
	return "", nil
}
func exists(path string) bool { _, err := os.Lstat(path); return err == nil }

func moveStep(archive, source, target string) (bool, error) {
	key := filepath.Join(archive, ".steps", strconv.Itoa(len(strings.Split(filepath.Clean(source), string(filepath.Separator))))+"-"+strings.NewReplacer("/", "_", "\\", "_").Replace(strings.TrimPrefix(filepath.Clean(source), string(filepath.Separator))))
	intent := exists(key)
	if !exists(source) {
		if intent && exists(target) {
			return false, nil
		}
		return false, nil
	}
	if exists(target) {
		return false, fmt.Errorf("refusing to overwrite migration destination %s", target)
	}
	if err := os.MkdirAll(filepath.Dir(target), 0700); err != nil {
		return false, err
	}
	if err := os.MkdirAll(filepath.Dir(key), 0700); err != nil {
		return false, err
	}
	if !intent {
		if err := os.WriteFile(key, []byte(source+"\n"+target), 0600); err != nil {
			return false, err
		}
	}
	if err := os.Rename(source, target); err != nil {
		return false, fmt.Errorf("rename %s to %s (no copy fallback): %w", source, target, err)
	}
	return true, nil
}

func archiveRemainder(archive, home, root string, moved *[]string) error {
	entries, err := os.ReadDir(root)
	if os.IsNotExist(err) {
		return nil
	}
	if err != nil {
		return err
	}
	for _, entry := range entries {
		source := filepath.Join(root, entry.Name())
		rel, err := filepath.Rel(home, source)
		if err != nil {
			return err
		}
		target := filepath.Join(archive, "old", rel)
		did, err := moveStep(archive, source, target)
		if err != nil {
			return err
		}
		if did {
			*moved = append(*moved, source+" -> "+target)
		}
	}
	if err := os.Remove(root); err != nil && !os.IsNotExist(err) {
		return err
	}
	return nil
}
