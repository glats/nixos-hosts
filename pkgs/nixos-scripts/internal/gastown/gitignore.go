package gastown

import (
	"errors"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

const gasTownIgnoreMarker = "# Gas Town (added by gt)"

var gasTownIgnorePatterns = map[string]bool{
	".runtime/": true, ".claude/": true, ".opencode/": true, ".logs/": true, "__pycache__/": true,
	"state.json": true, "CLAUDE.md": true, "CLAUDE.local.md": true, "GEMINI.md": true,
}

// CleanGasTownIgnore removes the block that `gt crew add` appends to a tracked
// .gitignore. Every other line is kept, and the committed file is restored when
// nothing else changed. An untracked .gitignore is hidden by ExcludeInfra instead.
func CleanGasTownIgnore(workspace string) error {
	committed, err := exec.Command("git", "-C", workspace, "show", "HEAD:.gitignore").Output()
	if err != nil {
		return nil
	}
	path := filepath.Join(workspace, ".gitignore")
	current, err := os.ReadFile(path)
	if errors.Is(err, fs.ErrNotExist) {
		return nil
	}
	if err != nil {
		return err
	}
	cleaned, changed := stripGasTownIgnoreBlock(string(current), string(committed))
	if !changed {
		return nil
	}
	if strings.TrimRight(cleaned, "\r\n") == strings.TrimRight(string(committed), "\r\n") {
		return exec.Command("git", "-C", workspace, "checkout", "-q", "HEAD", "--", ".gitignore").Run()
	}
	return os.WriteFile(path, []byte(cleaned), 0o600)
}

func stripGasTownIgnoreBlock(current, committed string) (string, bool) {
	if hasLine(committed, gasTownIgnoreMarker) {
		return current, false
	}
	lines := strings.Split(current, "\n")
	out := make([]string, 0, len(lines))
	changed := false
	for i := 0; i < len(lines); i++ {
		if lines[i] != gasTownIgnoreMarker {
			out = append(out, lines[i])
			continue
		}
		changed = true
		if n := len(out); n > 0 && out[n-1] == "" {
			out = out[:n-1]
		}
		for i+1 < len(lines) && gasTownIgnorePatterns[lines[i+1]] {
			i++
		}
	}
	return strings.Join(out, "\n"), changed
}

func hasLine(text, line string) bool {
	for _, l := range strings.Split(text, "\n") {
		if l == line {
			return true
		}
	}
	return false
}
