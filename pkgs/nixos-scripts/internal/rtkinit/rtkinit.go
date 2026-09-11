// Package rtkinit manages the repository's versioned RTK contract block.
package rtkinit

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

const (
	openMarker  = "<!-- rtk-init-managed v1 -->"
	closeMarker = "<!-- /rtk-init-managed -->"
)

// Block returns the canonical managed RTK contract.
func Block() string {
	return `<!-- rtk-init-managed v1 -->
## RTK (command output filter)

RTK 0.41.0 is installed on all hosts. An OpenCode plugin and a Claude Code Bash hook rewrite supported commands **automatically** (fail-open) — run plain commands (` + "`git status`" + `) and let them rewrite; do NOT prefix ` + "`rtk`" + ` by hand.

- Manual rtk forms are only the top-level ones from ` + "`rtk --help`" + ` (` + "`rtk ls`" + `, ` + "`rtk git <sub>`" + `, ` + "`rtk test <cmd>`" + `, ` + "`rtk err <cmd>`" + `, ...). There is no ` + "`rtk rev-parse`" + ` — git builtins go through ` + "`rtk git rev-parse`" + ` or plain ` + "`git rev-parse`" + `.
- ` + "`rtk git status`" + ` hides ahead/behind divergence — use plain ` + "`git status -sb`" + ` when sync state matters.
- Savings data: ` + "`rtk gain --project`" + ` (local SQLite, shell-output only, not total spend). Telemetry is off via ` + "`RTK_TELEMETRY_DISABLED=1`" + `; bypass one command with ` + "`RTK_DISABLED=1 <cmd>`" + `. Full runbook: ` + "`docs/rtk-pilot.md`" + `.
- Never run ` + "`rtk init`" + ` in this repo — it writes a generated assistant-instructions file; ` + "`rtk-init`" + ` is the regen tool and this section is the contract instead.

<!-- /rtk-init-managed -->`
}

type Result string

const (
	Added     Result = "added"
	Updated   Result = "updated"
	Unchanged Result = "already up to date"
	Removed   Result = "removed"
)

func Upsert(path string, dryRun bool) (Result, error) {
	data, mode, err := read(path)
	if err != nil {
		return "", err
	}
	start, end, found, err := locate(string(data))
	if err != nil {
		return "", err
	}
	block := Block()
	if !found {
		if !dryRun {
			err = atomicWrite(path, []byte(appendBlock(string(data), block)), mode)
		}
		return Added, err
	}
	if string(data[start:end]) == block {
		return Unchanged, nil
	}
	if !dryRun {
		err = atomicWrite(path, []byte(string(data[:start])+block+string(data[end:])), mode)
	}
	return Updated, err
}

func Remove(path string, dryRun bool) (Result, error) {
	data, mode, err := read(path)
	if err != nil {
		return "", err
	}
	start, end, found, err := locate(string(data))
	if err != nil {
		return "", err
	}
	if !found {
		return "", errors.New("managed RTK block not found")
	}
	if !dryRun {
		err = atomicWrite(path, []byte(removeBlock(string(data), start, end)), mode)
	}
	return Removed, err
}

func Check(path string) error {
	data, _, err := read(path)
	if err != nil {
		return err
	}
	start, end, found, err := locate(string(data))
	if err != nil {
		return err
	}
	if !found {
		return errors.New("managed RTK block missing")
	}
	if string(data[start:end]) != Block() {
		return errors.New("managed RTK block is stale")
	}
	return nil
}

func read(path string) ([]byte, os.FileMode, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, 0, err
	}
	info, err := os.Stat(path)
	if err != nil {
		return nil, 0, err
	}
	return data, info.Mode().Perm(), nil
}

func locate(text string) (int, int, bool, error) {
	if strings.Count(text, openMarker) == 0 && strings.Count(text, closeMarker) == 0 {
		return 0, 0, false, nil
	}
	if strings.Count(text, openMarker) != 1 || strings.Count(text, closeMarker) != 1 {
		return 0, 0, false, errors.New("malformed managed RTK markers")
	}
	start := strings.Index(text, openMarker)
	close := strings.Index(text, closeMarker)
	if start < 0 || close < start {
		return 0, 0, false, errors.New("malformed managed RTK markers")
	}
	return start, close + len(closeMarker), true, nil
}

func appendBlock(existing, block string) string {
	if existing == "" {
		return block + "\n"
	}
	if strings.HasSuffix(existing, "\n") {
		return existing + block + "\n"
	}
	return existing + "\n\n" + block + "\n"
}

func removeBlock(text string, start, end int) string {
	if end < len(text) && text[end] == '\n' {
		end++
	}
	return text[:start] + text[end:]
}

func atomicWrite(path string, data []byte, mode os.FileMode) error {
	tmp, err := os.CreateTemp(filepath.Dir(path), ".rtk-init-*")
	if err != nil {
		return err
	}
	tmpName := tmp.Name()
	defer os.Remove(tmpName)
	if err = tmp.Chmod(mode); err == nil {
		_, err = tmp.Write(data)
	}
	if closeErr := tmp.Close(); err == nil {
		err = closeErr
	}
	if err != nil {
		return fmt.Errorf("write managed RTK block: %w", err)
	}
	return os.Rename(tmpName, path)
}
