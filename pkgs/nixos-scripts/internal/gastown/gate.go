package gastown

import (
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

var (
	alwaysInfrastructure  = []string{".beads/", ".runtime/", ".logs/"}
	newOnlyInfrastructure = []string{".claude/", ".opencode/", "__pycache__/", "state.json", "CLAUDE.md", "CLAUDE.local.md", "GEMINI.md"}
)

// IsInfrastructure reports whether a changed path is Gas Town's own file. Task
// metadata is always infrastructure; agent instruction files and plugin
// directories are infrastructure only when the project did not already own them.
func IsInfrastructure(path string, existedInBase bool) bool {
	for _, prefix := range alwaysInfrastructure {
		if strings.HasPrefix(path, prefix) {
			return true
		}
	}
	if existedInBase {
		return false
	}
	for _, entry := range newOnlyInfrastructure {
		if path == entry || (strings.HasSuffix(entry, "/") && strings.HasPrefix(path, entry)) {
			return true
		}
	}
	return false
}

func projectOwnedAgentFile(path string) bool {
	for _, entry := range newOnlyInfrastructure {
		if path == entry || (strings.HasSuffix(entry, "/") && strings.HasPrefix(path, entry)) {
			return true
		}
	}
	return false
}

type GateInput struct {
	RigRepo, Branch, Base, Bead, Staging, WorkDir string
	Protect                                       []string
}

type GateResult struct {
	Status    string        `json:"status"`
	Branch    string        `json:"branch"`
	Tip       string        `json:"tip,omitempty"`
	Files     []string      `json:"files,omitempty"`
	Dropped   []string      `json:"dropped,omitempty"`
	Notes     []string      `json:"notes,omitempty"`
	Checks    []CheckResult `json:"checks,omitempty"`
	Published string        `json:"published,omitempty"`
	Detail    string        `json:"detail,omitempty"`
	At        time.Time     `json:"at"`
}

func runGit(dir string, args ...string) (string, error) {
	full := append([]string{"-c", "core.hooksPath=/dev/null", "-c", "user.name=gastown-gate", "-c", "user.email=gate@localhost", "-c", "commit.gpgsign=false"}, args...)
	cmd := exec.Command("git", full...)
	cmd.Dir = dir
	cmd.Env = append(os.Environ(), "GIT_TERMINAL_PROMPT=0")
	out, err := cmd.CombinedOutput()
	if err != nil {
		return string(out), fmt.Errorf("git %s: %w: %s", strings.Join(args, " "), err, strings.TrimSpace(string(out)))
	}
	return string(out), nil
}

type change struct{ status, path string }

func parseNameStatus(raw string) []change {
	parts := strings.Split(strings.TrimRight(raw, "\x00"), "\x00")
	var out []change
	for i := 0; i+1 < len(parts); i += 2 {
		out = append(out, change{status: parts[i], path: parts[i+1]})
	}
	return out
}

// Gate turns an agent branch into a reviewable one: Gas Town files are dropped,
// the remaining change is rebuilt on the base, the trusted checks run, and only
// a passing result is published to the staging repository.
func (r *Runner) Gate(in GateInput, runChecks func(dir string, checks []string) []CheckResult) GateResult {
	res := GateResult{Branch: in.Branch, Status: "error"}
	fail := func(err error) GateResult { res.Detail = err.Error(); return res }
	if !ValidBeadID(in.Bead) {
		return fail(errors.New("unexpected bead id"))
	}
	if err := os.RemoveAll(in.WorkDir); err != nil {
		return fail(err)
	}
	if err := os.MkdirAll(filepath.Dir(in.WorkDir), 0o700); err != nil {
		return fail(err)
	}
	if _, err := runGit("", "clone", "-q", "--no-checkout", in.RigRepo, in.WorkDir); err != nil {
		return fail(err)
	}
	if _, err := runGit(in.WorkDir, "fetch", "-q", in.RigRepo, "+"+in.Branch+":refs/heads/gate-src"); err != nil {
		return fail(err)
	}
	baseOut, err := runGit(in.WorkDir, "merge-base", in.Base, "gate-src")
	if err != nil {
		return fail(err)
	}
	base := strings.TrimSpace(baseOut)
	tip, _ := runGit(in.WorkDir, "rev-parse", "gate-src")
	res.Tip = strings.TrimSpace(tip)
	raw, err := runGit(in.WorkDir, "diff", "--name-status", "-z", "--no-renames", base, "gate-src")
	if err != nil {
		return fail(err)
	}
	binaries := binaryPaths(in.WorkDir, base)
	var kept []change
	for _, c := range parseNameStatus(raw) {
		_, inBaseErr := runGit(in.WorkDir, "cat-file", "-e", base+":"+c.path)
		existed := inBaseErr == nil
		if IsInfrastructure(c.path, existed) {
			res.Dropped = append(res.Dropped, c.path)
			continue
		}
		if !existed && binaries[c.path] {
			res.Dropped = append(res.Dropped, c.path)
			res.Notes = append(res.Notes, "removed new binary file "+c.path)
			continue
		}
		switch {
		case existed && projectOwnedAgentFile(c.path):
			res.Notes = append(res.Notes, "changed project-owned agent file "+c.path+"; review it")
		case existed:
			res.Notes = append(res.Notes, "changed existing file "+c.path)
		}
		kept = append(kept, c)
	}
	if len(kept) == 0 {
		res.Status = "empty"
		return res
	}
	for _, c := range kept {
		if IsProtected(c.path, in.Protect) {
			res.Status, res.Detail = "fail", "protected path changed: "+c.path
			return res
		}
	}
	if _, err := runGit(in.WorkDir, "checkout", "-q", "-B", "gate", base); err != nil {
		return fail(err)
	}
	for _, c := range kept {
		if c.status == "D" {
			_, err = runGit(in.WorkDir, "rm", "-q", "--ignore-unmatch", "--", c.path)
		} else {
			_, err = runGit(in.WorkDir, "checkout", "gate-src", "--", c.path)
		}
		if err != nil {
			return fail(err)
		}
		res.Files = append(res.Files, c.path)
	}
	if err := cleanGitignore(in.WorkDir, base, &res); err != nil {
		return fail(err)
	}
	if len(res.Files) == 0 {
		res.Status = "empty"
		return res
	}
	sort.Strings(res.Files)
	subjects, _ := runGit(in.WorkDir, "log", "--reverse", "--format=%s", base+"..gate-src")
	subject := "gastown: " + in.Bead
	for _, line := range strings.Split(strings.TrimSpace(subjects), "\n") {
		if line != "" && !strings.HasPrefix(line, "chore:") {
			subject = line
			break
		}
	}
	if _, err := runGit(in.WorkDir, "commit", "-q", "--no-verify", "-m", subject+"\n\nBead: "+in.Bead); err != nil {
		return fail(err)
	}
	names, err := runGit(in.WorkDir, "diff", "--name-only", "--no-renames", base, "HEAD")
	if err != nil {
		return fail(err)
	}
	got := strings.Fields(names)
	sort.Strings(got)
	if strings.Join(got, "\n") != strings.Join(res.Files, "\n") {
		return fail(fmt.Errorf("sanitized diff %v differs from the allowed files %v", got, res.Files))
	}
	res.Checks = runChecks(in.WorkDir, nil)
	for _, c := range res.Checks {
		if c.Exit != 0 {
			res.Status = "fail"
			return res
		}
	}
	target := "gastown/" + in.Bead
	if _, err := runGit(in.WorkDir, "push", "-q", "-f", in.Staging, "gate:refs/heads/"+target); err != nil {
		return fail(err)
	}
	res.Status, res.Published = "pass", target
	return res
}

// cleanGitignore removes the block Gas Town appends to .gitignore. A file left
// identical to the base disappears from the change; a project edit is kept.
func cleanGitignore(workDir, base string, res *GateResult) error {
	index := -1
	for i, f := range res.Files {
		if f == ".gitignore" {
			index = i
		}
	}
	if index < 0 {
		return nil
	}
	current, err := os.ReadFile(filepath.Join(workDir, ".gitignore"))
	if err != nil {
		return nil
	}
	committed, showErr := runGit(workDir, "show", base+":.gitignore")
	cleaned, blockChanged := stripGasTownIgnoreBlock(string(current), committed)
	cleaned, linesChanged := stripInfrastructureIgnoreLines(cleaned, committed)
	if !blockChanged && !linesChanged {
		return nil
	}
	drop := func() { res.Files = append(res.Files[:index], res.Files[index+1:]...) }
	switch {
	case showErr == nil && strings.TrimRight(cleaned, "\r\n") == strings.TrimRight(committed, "\r\n"):
		if _, err := runGit(workDir, "checkout", base, "--", ".gitignore"); err != nil {
			return err
		}
		drop()
	case showErr != nil && strings.TrimSpace(cleaned) == "":
		if _, err := runGit(workDir, "rm", "-q", "-f", "--", ".gitignore"); err != nil {
			return err
		}
		drop()
	default:
		if err := os.WriteFile(filepath.Join(workDir, ".gitignore"), []byte(cleaned), 0o644); err != nil {
			return err
		}
		if _, err := runGit(workDir, "add", ".gitignore"); err != nil {
			return err
		}
	}
	return nil
}

var infrastructureIgnoreLines = map[string]bool{".beads/": true, ".runtime/": true, ".logs/": true, ".claude/": true, ".opencode/": true,
	"__pycache__/": true, "state.json": true, "CLAUDE.md": true, "CLAUDE.local.md": true, "GEMINI.md": true}

// stripInfrastructureIgnoreLines removes ignore entries for Gas Town's own
// files that a worker added to hide them, keeping any the project already had.
func stripInfrastructureIgnoreLines(current, committed string) (string, bool) {
	owned := map[string]bool{}
	for _, line := range strings.Split(committed, "\n") {
		owned[strings.TrimSpace(line)] = true
	}
	lines := strings.Split(current, "\n")
	out := make([]string, 0, len(lines))
	changed := false
	for _, line := range lines {
		if name := strings.TrimSpace(line); infrastructureIgnoreLines[name] && !owned[name] {
			changed = true
			continue
		}
		out = append(out, line)
	}
	return strings.Join(out, "\n"), changed
}

// binaryPaths lists the paths git treats as binary in the change from base to gate-src.
func binaryPaths(workDir, base string) map[string]bool {
	out, err := runGit(workDir, "diff", "--numstat", "-z", "--no-renames", base, "gate-src")
	paths := map[string]bool{}
	if err != nil {
		return paths
	}
	for _, record := range strings.Split(out, "\x00") {
		if rest, ok := strings.CutPrefix(record, "-\t-\t"); ok {
			paths[rest] = true
		}
	}
	return paths
}

// IsProtected reports whether path is covered by a protected entry: an exact
// file, or a directory written with a trailing slash.
func IsProtected(path string, protect []string) bool {
	for _, entry := range protect {
		if path == entry || (strings.HasSuffix(entry, "/") && strings.HasPrefix(path, entry)) {
			return true
		}
	}
	return false
}

type IntegrateResult struct {
	Status    string        `json:"status"`
	Branches  []string      `json:"branches,omitempty"`
	Conflict  string        `json:"conflict,omitempty"`
	Checks    []CheckResult `json:"checks,omitempty"`
	Published string        `json:"published,omitempty"`
	Detail    string        `json:"detail,omitempty"`
}

// Integrate merges the accepted branches into one candidate on the base, runs
// the trusted checks on the combination and publishes it as gastown/integrated.
func Integrate(staging, workDir, base string, branches []string, runChecks func(dir string, checks []string) []CheckResult) IntegrateResult {
	res := IntegrateResult{Status: "error", Branches: branches}
	if len(branches) < 2 {
		res.Status = "none"
		return res
	}
	fail := func(err error) IntegrateResult { res.Detail = err.Error(); return res }
	if err := os.RemoveAll(workDir); err != nil {
		return fail(err)
	}
	if err := os.MkdirAll(filepath.Dir(workDir), 0o700); err != nil {
		return fail(err)
	}
	if _, err := runGit("", "clone", "-q", staging, workDir); err != nil {
		return fail(err)
	}
	if _, err := runGit(workDir, "checkout", "-q", "-B", "integrated", "origin/"+base); err != nil {
		return fail(err)
	}
	for _, branch := range branches {
		if _, err := runGit(workDir, "merge", "--no-ff", "--no-edit", "-q", "origin/"+branch); err != nil {
			_, _ = runGit(workDir, "merge", "--abort")
			res.Status, res.Conflict = "conflict", branch
			return res
		}
	}
	res.Checks = runChecks(workDir, nil)
	for _, c := range res.Checks {
		if c.Exit != 0 {
			res.Status = "fail"
			return res
		}
	}
	if _, err := runGit(workDir, "push", "-q", "-f", staging, "integrated:refs/heads/gastown/integrated"); err != nil {
		return fail(err)
	}
	res.Status, res.Published = "pass", "gastown/integrated"
	return res
}
