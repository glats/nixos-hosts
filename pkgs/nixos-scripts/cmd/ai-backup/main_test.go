package main

import (
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func TestResolveTarget(t *testing.T) {
	cases := []struct {
		in, want string
	}{
		{"local", "local"},
		{"macm5", "juan@macm5"},
		{"t14", "glats@t14.local"},
		{"thinkcentre", "glats@thinkcentre.local"},
		{"jcuzmar@mact2.local", "jcuzmar@mact2.local"},
		{"weird@host.example", "weird@host.example"},
	}
	for _, tc := range cases {
		if got := resolveTarget(tc.in); got != tc.want {
			t.Errorf("resolveTarget(%q) = %q, want %q", tc.in, got, tc.want)
		}
	}
}

func TestTargetLabel(t *testing.T) {
	cases := []struct {
		in, want string
	}{

		{"macm5", "macm5"},
		{"t14", "t14"},
		{"thinkcentre", "thinkcentre"},
		{"jcuzmar@mact2.local", "jcuzmar-mact2-local"},
		{"a/b@c.d", "a-b-c-d"},
		{"plain", "plain"},
	}
	for _, tc := range cases {
		if got := targetLabel(tc.in); got != tc.want {
			t.Errorf("targetLabel(%q) = %q, want %q", tc.in, got, tc.want)
		}
	}

	if _, err := exec.LookPath("hostname"); err == nil {
		if got := targetLabel("local"); got == "" || strings.ContainsAny(got, "\n") {
			t.Errorf("targetLabel(local) = %q, want a hostname", got)
		}
	}
}

func TestUsageTextDescribesManifest(t *testing.T) {

	for _, want := range []string{
		"~/.claude",
		".claude.json",
		".local/share/opencode",
		"storage/",
		"auth.json",
		"opencode-multimodal.json",
		".engram",
		"home-snap/",
		"AI_BACKUP_DEST",
		"AI_BACKUP_ZSTD_LEVEL",
		"AI_BACKUP_SSH_OPTS",
		"AI_BACKUP_EXTRA",
		"0 success  1 usage/config  2 ssh/connectivity  3 snapshot/backup failure",
		"4 restore failure",
	} {
		if !strings.Contains(usageText, want) {
			t.Errorf("usageText missing manifest/env/exit fragment %q", want)
		}
	}

	for _, line := range strings.Split(usageText, "\n") {
		if strings.Contains(line, ".config/opencode") && !strings.HasPrefix(strings.TrimSpace(line), ".config/opencode, opencode bin/log") {
			t.Errorf("usageText line presents .config/opencode as backed up: %q", line)
		}
	}
}

const fakeSQLite = `#!/bin/sh
case "$2" in
  "PRAGMA integrity_check;")
    printf '%s\n' "$FAKE_SQLITE_INTEGRITY"
    case "$FAKE_SQLITE_INTEGRITY" in
      ok) ;;
      *) exit 1 ;;
    esac ;;
  .backup*)
    dest="${2#.backup }"
    dest="${dest#\'}"
    dest="${dest%\'}"
    if [ "${FAKE_SQLITE_EMPTY:-0}" = 1 ]; then
      : > "$dest"
    else
      printf 'fake-snapshot-content-for-%s\n' "${dest##*/}" > "$dest"
    fi ;;
esac
exit 0
`

func fallbackPath() string {
	if p := os.Getenv("PATH"); p != "" {
		return p
	}
	return "/run/current-system/sw/bin:/bin:/usr/bin"
}

func runShellPayload(t *testing.T, payload string, home string, extraEnv ...string) (int, *bytes.Buffer, *bytes.Buffer) {
	t.Helper()
	if _, err := os.Stat("/bin/sh"); err != nil {
		t.Skip("/bin/sh not available")
	}
	shimDir := t.TempDir()
	if err := os.WriteFile(filepath.Join(shimDir, "sqlite3"), []byte(fakeSQLite), 0o755); err != nil {
		t.Fatal(err)
	}
	var stdout, stderr bytes.Buffer
	cmd := exec.Command("/bin/sh", "-s")
	cmd.Stdin = strings.NewReader(payload)
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	cmd.Env = append([]string{
		"HOME=" + home,
		"TMPDIR=" + t.TempDir(),
		"PATH=" + shimDir + ":" + fallbackPath(),
		"FAKE_SQLITE_INTEGRITY=ok",
	}, extraEnv...)
	rc := 0
	if err := cmd.Run(); err != nil {
		exitErr, ok := err.(*exec.ExitError)
		if !ok {
			t.Fatalf("payload run: %v\nstderr:\n%s", err, stderr.String())
		}
		rc = exitErr.ExitCode()
	}
	return rc, &stdout, &stderr
}

func tarMembers(t *testing.T, tarout *os.File) []string {
	t.Helper()
	if _, err := tarout.Seek(0, 0); err != nil {
		t.Fatal(err)
	}
	cmd := exec.Command("tar", "-tf", "-")
	cmd.Stdin = tarout
	out, err := cmd.Output()
	if err != nil {
		t.Fatalf("tar -tf: %v", err)
	}
	var members []string
	for _, line := range strings.Split(strings.TrimRight(string(out), "\n"), "\n") {
		if line != "" {
			members = append(members, line)
		}
	}
	return members
}

func writeTree(t *testing.T, home string, rels ...string) {
	t.Helper()
	for _, rel := range rels {
		p := filepath.Join(home, rel)
		if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(p, []byte("content:"+rel), 0o644); err != nil {
			t.Fatal(err)
		}
	}
}

func buildClaudeHome(t *testing.T) string {
	t.Helper()
	home := t.TempDir()
	writeTree(t, home,

		".claude/projects/host-dir/session.jsonl",
		".claude/history.jsonl",
		".claude/plans/plan.md",
		".claude/todos/todo.md",
		".claude/keybindings.json",

		".claude/.claude/triage/note.md",
		".claude.json",

		".claude/settings.json",
		".claude/settings.local.json",
		".claude/CLAUDE.md",
		".claude/skills/skill.md",
		".claude/commands/cmd.md",
		".claude/plugins/cache/p.cache",
		".claude/.credentials.json",
		".claude/cache/c.bin",

		".local/share/opencode/opencode-main-stable.db",
		".local/share/opencode/storage/db/main.db",
		".local/share/opencode/auth.json",
		".local/share/opencode/opencode-multimodal.json",

		".local/share/opencode/opencode.db-wal",
		".local/share/opencode/opencode.db-shm",
		".local/share/opencode/bin/tool",
		".local/share/opencode/log/x.log",
		".local/share/opencode/snapshot/s.gz",
		".local/share/opencode/tool-output/o.txt",
		".local/share/opencode/node_modules/pkg/index.js",
		".config/opencode/config.json",

		".engram/engram.db",
		".engram/engram.db.before-20240101",
		".engram/engram.db.pre-cleanup.old",
		".engram/engram.db-wal",
		".engram/engram.db-shm",
		".engram/chunks/c.bin",
	)
	if err := os.Symlink(
		filepath.Join(home, ".local/share/opencode/opencode-main-stable.db"),
		filepath.Join(home, ".local/share/opencode/opencode.db"),
	); err != nil {
		t.Fatal(err)
	}
	return home
}

func TestBackupPayloadMemberList(t *testing.T) {
	home := buildClaudeHome(t)
	if _, err := os.Stat("/bin/sh"); err != nil {
		t.Skip("/bin/sh not available")
	}
	shimDir := t.TempDir()
	if err := os.WriteFile(filepath.Join(shimDir, "sqlite3"), []byte(fakeSQLite), 0o755); err != nil {
		t.Fatal(err)
	}
	tarout, err := os.Create(filepath.Join(t.TempDir(), "members.tar"))
	if err != nil {
		t.Fatal(err)
	}
	var stderr bytes.Buffer
	cmd := exec.Command("/bin/sh", "-s")
	cmd.Stdin = strings.NewReader(remoteBackupScript)
	cmd.Stdout = tarout
	cmd.Stderr = &stderr
	cmd.Env = []string{
		"HOME=" + home,
		"TMPDIR=" + t.TempDir(),
		"PATH=" + shimDir + ":" + fallbackPath(),
		"AI_BACKUP_EXTRA=",
	}
	if err := cmd.Run(); err != nil {
		t.Fatalf("backup payload failed: %v\nstderr:\n%s", err, stderr.String())
	}
	snap := tarMembers(t, tarout)

	has := func(s string) bool {
		for _, m := range snap {
			if m == s {
				return true
			}
		}
		return false
	}

	for _, want := range []string{
		".claude/projects/host-dir/session.jsonl",
		".claude/history.jsonl",
		".claude/plans/plan.md",
		".claude/todos/todo.md",
		".claude/keybindings.json",
		".claude/.claude/triage/note.md",
		".claude.json",
		".local/share/opencode/storage/db/main.db",
		".local/share/opencode/auth.json",
		".local/share/opencode/opencode-multimodal.json",
		"home-snap/.local/share/opencode/opencode-main-stable.db.snapshot",
		"home-snap/.engram/engram.db.snapshot",
	} {
		if !has(want) {
			t.Errorf("archive missing required member %q", want)
		}
	}

	forbidden := func(m string) bool {
		return m == ".config/opencode/config.json" ||
			strings.Contains(m, "node_modules") ||
			strings.Contains(m, "/bin/") ||
			strings.Contains(m, "/log/") ||
			strings.Contains(m, "/snapshot/") ||
			m == ".local/share/opencode/opencode-main-stable.db" ||
			strings.Contains(m, ".db-wal") ||
			strings.Contains(m, ".db-shm") ||
			m == "engram.db.before-20240101" ||
			m == "engram.db.pre-cleanup.old" ||
			m == ".claude/settings.json" ||
			m == ".claude/settings.local.json" ||
			m == ".claude/CLAUDE.md" ||
			m == ".claude/skills/skill.md" ||
			m == ".claude/commands/cmd.md" ||
			m == ".claude/plugins/cache/p.cache" ||
			m == ".claude/.credentials.json" ||
			m == ".claude/cache/c.bin" ||
			strings.HasPrefix(m, ".engram/")
	}
	for _, m := range snap {
		if forbidden(m) && !strings.HasSuffix(m, ".snapshot") {
			t.Errorf("forbidden member entered the archive: %q", m)
		}
	}

	if !has("home-snap/.local/share/opencode/opencode-main-stable.db.snapshot") {
		t.Error("snapshot must be realpath-named (<real-basename>.db.snapshot)")
	}
}

func TestBackupPayloadExtraDirs(t *testing.T) {
	home := t.TempDir()
	writeTree(t, home,
		".local/share/opencode/opencode-main.db",
		"projects/alpha/.engram/chunks/c.bin",
		"projects/alpha/.engram/manifest.json",
		"projects/alpha/.engram/config.json",

		"projects/alpha/.engram/engram.db",
	)
	if _, err := os.Stat("/bin/sh"); err != nil {
		t.Skip("/bin/sh not available")
	}
	shimDir := t.TempDir()
	if err := os.WriteFile(filepath.Join(shimDir, "sqlite3"), []byte(fakeSQLite), 0o755); err != nil {
		t.Fatal(err)
	}
	tarout, err := os.Create(filepath.Join(t.TempDir(), "extra.tar"))
	if err != nil {
		t.Fatal(err)
	}
	var stderr bytes.Buffer
	cmd := exec.Command("/bin/sh", "-s")
	cmd.Stdin = strings.NewReader(remoteBackupScript)
	cmd.Stdout = tarout
	cmd.Stderr = &stderr
	cmd.Env = []string{
		"HOME=" + home,
		"TMPDIR=" + t.TempDir(),
		"PATH=" + shimDir + ":" + fallbackPath(),

		"AI_BACKUP_EXTRA=" + filepath.Join(home, "projects/alpha/.engram"),
	}
	if err := cmd.Run(); err != nil {
		t.Fatalf("backup payload failed: %v\nstderr:\n%s", err, stderr.String())
	}
	snap := tarMembers(t, tarout)
	has := func(s string) bool {
		for _, m := range snap {
			if m == s {
				return true
			}
		}
		return false
	}
	for _, want := range []string{

		"extras/alpha/.engram/chunks/c.bin",
		"extras/alpha/.engram/manifest.json",
		"extras/alpha/.engram/config.json",
	} {
		if !has(want) {
			t.Errorf("AI_BACKUP_EXTRA member missing: %q", want)
		}
	}
	if has("extras/alpha/.engram/engram.db") {
		t.Error("live project engram.db must never enter the archive")
	}
}

func TestBackupPayloadExit3NoSnapshots(t *testing.T) {

	home := t.TempDir()
	writeTree(t, home, ".claude/history.jsonl", ".claude.json", ".engram/engram.db")
	rc, _, stderr := runShellPayload(t, remoteBackupScript, home)
	if rc != 3 {
		t.Fatalf("snapcount=0 payload exit = %d (stderr: %s)", rc, stderr.String())
	}
	if !strings.Contains(stderr.String(), "no OpenCode database snapshots") {
		t.Errorf("missing snapcount=0 diagnostic, stderr: %s", stderr.String())
	}
}

func TestBackupPayloadExit3EmptySnapshot(t *testing.T) {

	home := t.TempDir()
	writeTree(t, home, ".local/share/opencode/opencode-main.db")
	rc, _, stderr := runShellPayload(t, remoteBackupScript, home, "FAKE_SQLITE_EMPTY=1")
	if rc != 3 {
		t.Fatalf("empty-snapshot payload exit = %d (stderr: %s)", rc, stderr.String())
	}
	if !strings.Contains(stderr.String(), "empty snapshot") {
		t.Errorf("missing empty-snapshot diagnostic, stderr: %s", stderr.String())
	}
}

func TestRestorePayloadSymlinkSnapshotRelocation(t *testing.T) {

	home := t.TempDir()
	opencode := filepath.Join(home, ".local/share/opencode")
	if err := os.MkdirAll(filepath.Join(home, "home-snap/.local/share/opencode"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(opencode, 0o755); err != nil {
		t.Fatal(err)
	}

	if err := os.WriteFile(filepath.Join(opencode, "opencode-stable-real.db"), []byte("old-live-db"), 0o644); err != nil {
		t.Fatal(err)
	}
	link := filepath.Join(opencode, "opencode-stable.db")
	if err := os.Symlink(filepath.Join(opencode, "opencode-stable-real.db"), link); err != nil {
		t.Fatal(err)
	}
	staged := filepath.Join(home, "home-snap/.local/share/opencode/opencode-stable.db.snapshot")
	if err := os.WriteFile(staged, []byte("restored-db-content"), 0o644); err != nil {
		t.Fatal(err)
	}
	rc, stdout, stderr := runShellPayload(t, remoteRestoreScript, home)
	if rc != 0 {
		t.Fatalf("restore payload exit = %d (stdout: %s stderr: %s)", rc, stdout.String(), stderr.String())
	}
	t.Logf("restore messages:\n%s", stdout.String())

	fi, err := os.Lstat(link)
	if err != nil || fi.Mode()&os.ModeSymlink == 0 {
		t.Fatalf("live symlink must be preserved: Lstat err=%v", err)
	}

	if got, err := os.ReadFile(filepath.Join(opencode, "opencode-stable-real.db")); err != nil || string(got) != "restored-db-content" {
		t.Fatalf("relocated db at resolved path: got %q err=%v", got, err)
	}

	resolved, err := filepath.EvalSymlinks(link)
	if err != nil {
		t.Fatal(err)
	}
	want, err := filepath.EvalSymlinks(filepath.Join(opencode, "opencode-stable-real.db"))
	if err != nil || resolved != want {
		t.Fatalf("symlink resolution changed: resolved=%q err=%v", resolved, err)
	}

	kept2, err := filepath.Glob(filepath.Join(opencode, "opencode-stable-real.db.pre-restore-*"))
	if err != nil || len(kept2) != 1 {
		t.Fatalf("pre-restore copy missing (glob hit %v err %v)", kept2, err)
	}
	if old, err := os.ReadFile(kept2[0]); err != nil || string(old) != "old-live-db" {
		t.Fatalf("pre-restore copy must hold the old db: got %q err=%v", old, err)
	}

	if _, err := os.Stat(filepath.Join(home, "home-snap")); !os.IsNotExist(err) {
		t.Fatalf("home-snap must be removed after restore (err=%v)", err)
	}
}

func TestRestorePayloadIntegrityFailureExitsNonzero(t *testing.T) {

	home := t.TempDir()
	if err := os.MkdirAll(filepath.Join(home, ".local/share/opencode"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(home, ".local/share/opencode/opencode-main.db"), []byte("corrupt"), 0o644); err != nil {
		t.Fatal(err)
	}
	rc, stdout, _ := runShellPayload(t, remoteRestoreScript, home, "FAKE_SQLITE_INTEGRITY=corrupt")
	if rc == 0 {
		t.Fatal("integrity failure must exit nonzero")
	}

	if !strings.Contains(stdout.String(), "corrupt") || !strings.Contains(stdout.String(), "integrity check") {
		t.Errorf("restore must report the failed integrity check, stdout: %s", stdout.String())
	}
}

func TestRestoreOKPathExitsZero(t *testing.T) {
	home := t.TempDir()
	if err := os.MkdirAll(filepath.Join(home, ".local/share/opencode"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(home, ".local/share/opencode/opencode-main.db"), []byte("ok-db"), 0o644); err != nil {
		t.Fatal(err)
	}
	if rc, _, _ := runShellPayload(t, remoteRestoreScript, home); rc != 0 {
		t.Fatal("healthy restore must exit 0")
	}
}

func TestPreRestoreScriptKeepsClaudeJSON(t *testing.T) {

	home := t.TempDir()
	if err := os.WriteFile(filepath.Join(home, ".claude.json"), []byte("previous-oauth"), 0o600); err != nil {
		t.Fatal(err)
	}
	rc, _, stderr := runShellPayload(t, preRestoreScript, home)
	if rc != 0 {
		t.Fatalf("pre-restore payload exit = %d (stderr: %s)", rc, stderr.String())
	}
	kept, err := filepath.Glob(filepath.Join(home, ".claude.json.pre-restore-*"))
	if err != nil || len(kept) != 1 {
		t.Fatalf("pre-restore copy missing (glob %v err %v)", kept, err)
	}
	if old, err := os.ReadFile(kept[0]); err != nil || string(old) != "previous-oauth" {
		t.Fatalf("pre-restore copy content: got %q err=%v", old, err)
	}

	if rc, _, _ := runShellPayload(t, preRestoreScript, t.TempDir()); rc != 0 {
		t.Fatal("pre-restore without .claude.json must still succeed")
	}
}

func TestBackupPayloadInjectsAIExtraWithShQuoting(t *testing.T) {
	t.Setenv("AI_BACKUP_EXTRA", `/a'b "dir"`)
	pw := backupPayload()
	if !strings.HasPrefix(pw, `AI_BACKUP_EXTRA='/a'\''b "dir"'`+"\n") {
		t.Fatalf("backupPayload must forward AI_BACKUP_EXTRA as a sh assignment: %q", pw)
	}
	if !strings.Contains(pw, remoteBackupScript) {
		t.Fatal("backupPayload must ship remoteBackupScript verbatim after the assignment")
	}
}

func TestPayloadSyntaxShN(t *testing.T) {

	if _, err := os.Stat("/bin/sh"); err != nil {
		t.Skip("/bin/sh not available")
	}
	for name, payload := range map[string]string{
		"remoteBackupScript":     remoteBackupScript,
		"remoteRestoreScript":    remoteRestoreScript,
		"preRestoreScript":       preRestoreScript,
		"restorePreflightScript": restorePreflightScript,
	} {
		t.Run(name, func(t *testing.T) {
			cmd := exec.Command("/bin/sh", "-n")
			cmd.Stdin = strings.NewReader(payload)
			out, err := cmd.CombinedOutput()
			if err != nil {
				t.Fatalf("/bin/sh -n rejected %s: %v\n%s", name, err, out)
			}
		})
	}
}

func runPreflightPayload(t *testing.T, payload string, home string, pgrepExit int, extraEnv ...string) (int, *bytes.Buffer, *bytes.Buffer) {
	t.Helper()
	if _, err := os.Stat("/bin/sh"); err != nil {
		t.Skip("/bin/sh not available")
	}
	shimDir := t.TempDir()
	if err := os.WriteFile(filepath.Join(shimDir, "sqlite3"), []byte(fakeSQLite), 0o755); err != nil {
		t.Fatal(err)
	}
	pgrep := fmt.Sprintf("#!/bin/sh\nexit %d\n", pgrepExit)
	if err := os.WriteFile(filepath.Join(shimDir, "pgrep"), []byte(pgrep), 0o755); err != nil {
		t.Fatal(err)
	}
	var stdout, stderr bytes.Buffer
	cmd := exec.Command("/bin/sh", "-s")
	cmd.Stdin = strings.NewReader(payload)
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	cmd.Env = append([]string{
		"HOME=" + home,
		"TMPDIR=" + t.TempDir(),
		"PATH=" + shimDir + ":" + fallbackPath(),
		"FAKE_SQLITE_INTEGRITY=ok",
	}, extraEnv...)
	rc := 0
	if err := cmd.Run(); err != nil {
		exitErr, ok := err.(*exec.ExitError)
		if !ok {
			t.Fatalf("preflight payload run: %v\nstderr:\n%s", err, stderr.String())
		}
		rc = exitErr.ExitCode()
	}
	return rc, &stdout, &stderr
}

func TestRestorePreflightRefusesRunningProcess(t *testing.T) {

	home := t.TempDir()
	rc, _, stderr := runPreflightPayload(t, restorePreflightScript, home, 0)
	if rc != 4 {
		t.Fatalf("running process must refuse with 4, got %d", rc)
	}
	if !strings.Contains(stderr.String(), "REFUSING") || !strings.Contains(stderr.String(), "--force") {
		t.Errorf("refusal must name the override, stderr: %s", stderr.String())
	}
}

func TestRestorePreflightRefusesExistingState(t *testing.T) {

	home := t.TempDir()
	if err := os.WriteFile(filepath.Join(home, ".claude.json"), []byte("cfg"), 0o600); err != nil {
		t.Fatal(err)
	}
	opencode := filepath.Join(home, ".local/share/opencode")
	if err := os.MkdirAll(opencode, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(opencode, "opencode-stable.db"), []byte("db"), 0o644); err != nil {
		t.Fatal(err)
	}
	rc, _, stderr := runPreflightPayload(t, restorePreflightScript, home, 1)
	if rc != 4 {
		t.Fatalf("existing state must refuse with 4, got %d", rc)
	}
	for _, want := range []string{"REFUSING", ".claude.json", "opencode-stable.db", "--force"} {
		if !strings.Contains(stderr.String(), want) {
			t.Errorf("refusal must mention %q, stderr: %s", want, stderr.String())
		}
	}

	if old, err := os.ReadFile(filepath.Join(home, ".claude.json")); err != nil || string(old) != "cfg" {
		t.Fatalf("refused restore must not touch the target: got %q err=%v", old, err)
	}
}

func TestRestorePreflightCleanTargetPasses(t *testing.T) {

	home := t.TempDir()
	rc, stdout, stderr := runPreflightPayload(t, restorePreflightScript, home, 1)
	if rc != 0 {
		t.Fatalf("clean target must pass, got %d (stderr: %s)", rc, stderr.String())
	}
	if !strings.Contains(stdout.String(), "pre-flight clean") {
		t.Errorf("clean pass must be reported, stdout: %s", stdout.String())
	}
}

func TestRestorePreflightForceSkipsEverything(t *testing.T) {

	home := t.TempDir()
	if err := os.WriteFile(filepath.Join(home, ".claude.json"), []byte("cfg"), 0o600); err != nil {
		t.Fatal(err)
	}
	rc, stdout, stderr := runPreflightPayload(t, restorePreflightScript, home, 0, "AI_BACKUP_RESTORE_FORCE=1")
	if rc != 0 {
		t.Fatalf("--force must proceed, got %d (stderr: %s)", rc, stderr.String())
	}
	if !strings.Contains(stdout.String(), "skipped (--force)") {
		t.Errorf("--force must be reported, stdout: %s", stdout.String())
	}
}

func TestRestorePreflightPayloadForceForwarding(t *testing.T) {

	if got := restorePreflightPayload(false); !strings.HasPrefix(got, "AI_BACKUP_RESTORE_FORCE=0\n") || !strings.Contains(got, restorePreflightScript) {
		t.Fatalf("restorePreflightPayload(false) = %q", got)
	}
	if got := restorePreflightPayload(true); !strings.HasPrefix(got, "AI_BACKUP_RESTORE_FORCE=1\n") {
		t.Fatalf("restorePreflightPayload(true) = %q", got)
	}
}

func TestPreRestoreMovesAsideStateDirs(t *testing.T) {

	home := t.TempDir()
	projects := filepath.Join(home, ".claude/projects")
	if err := os.MkdirAll(projects, 0o755); err != nil {
		t.Fatal(err)
	}
	transcript := filepath.Join(projects, "-Users-jcuzmar-proj/session.jsonl")
	if err := os.MkdirAll(filepath.Dir(transcript), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(transcript, []byte("old-transcript"), 0o644); err != nil {
		t.Fatal(err)
	}
	storage := filepath.Join(home, ".local/share/opencode/storage")
	if err := os.MkdirAll(filepath.Join(storage, "session"), 0o755); err != nil {
		t.Fatal(err)
	}
	auth := filepath.Join(home, ".local/share/opencode/auth.json")
	if err := os.WriteFile(auth, []byte("old-auth"), 0o600); err != nil {
		t.Fatal(err)
	}
	rc, stdout, stderr := runShellPayload(t, preRestoreScript, home)
	if rc != 0 {
		t.Fatalf("pre-restore payload exit = %d (stderr: %s)", rc, stderr.String())
	}
	if !strings.Contains(stdout.String(), ".claude/projects") {
		t.Errorf("pre-restore must report the moved-aside dirs, stdout: %s", stdout.String())
	}

	if _, err := os.Stat(projects); !os.IsNotExist(err) {
		t.Fatalf("live projects dir must be moved aside (err=%v)", err)
	}
	kept, err := filepath.Glob(filepath.Join(home, ".claude/projects.pre-restore-*"))
	if err != nil || len(kept) != 1 {
		t.Fatalf("moved-aside projects missing (glob %v err %v)", kept, err)
	}
	if old, err := os.ReadFile(filepath.Join(kept[0], "-Users-jcuzmar-proj/session.jsonl")); err != nil || string(old) != "old-transcript" {
		t.Fatalf("moved-aside tree content: got %q err=%v", old, err)
	}
	if _, err := os.Stat(storage); !os.IsNotExist(err) {
		t.Fatalf("live storage dir must be moved aside (err=%v)", err)
	}
	if old, err := os.ReadFile(globFirstOrDie(t, filepath.Join(home, ".local/share/opencode/auth.json.pre-restore-*"))); err != nil || string(old) != "old-auth" {
		t.Fatalf("kept auth.json: got %q err=%v", old, err)
	}
}

func globFirstOrDie(t *testing.T, pattern string) string {
	t.Helper()
	hits, err := filepath.Glob(pattern)
	if err != nil || len(hits) != 1 {
		t.Fatalf("expected exactly one match for %s: %v err=%v", pattern, hits, err)
	}
	return hits[0]
}
