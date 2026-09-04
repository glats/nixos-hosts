// Command ai-backup performs one-shot compressed backup/restore of AI
// assistant state (Claude Code, OpenCode, Engram) as a single .tar.zst
// archive, with consistent sqlite snapshots taken on the source host.
//
// Port of bin/ai-backup: usage text, messages, flags, env overrides and
// exit codes preserved byte-for-byte.
//
//	0 success · 1 usage/config · 2 ssh/connectivity · 3 snapshot/backup
//	failure · 4 restore failure
//
// External binaries stay external exactly where the bash original used
// them: sqlite3 runs only inside the POSIX sh payloads exec'd on the
// source host (shell-out, no cgo driver), alongside tar, readlink and
// mktemp; zstd, ssh, sha256sum, du, find and sort are exec'd by this
// command in the same pipeline shapes as bash.
//
// Faithfully-replicated pipefail quirks (the bash runs under
// `set -euo pipefail`):
//   - `restore --dry-run` pipes the listing through `sed | head -60`.
//     Once head exits, any later sed write dies of SIGPIPE, so an
//     archive whose listing is large enough kills the script silently
//     with exit 141 and the "... (full list: ...)" trailer is never
//     printed. Measured bash boundary: listings of ~300 members
//     (~4KB) survive, ~500 members (~7KB) die; the port uses 6KB of
//     listing bytes as the threshold (the exact boundary is
//     sed/head/pipe-buffer dependent, not part of the bash contract).
//   - a failed `du -h` inside a $(...) assignment kills the script
//     silently with the pipeline's exit code (reproduced).
package main

import (
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

// --- Configuration (override via environment) ---
var (
	dest      = envOr("AI_BACKUP_DEST", "/run/media/stuff/samba/backup/ai")
	zstdLevel = envOr("AI_BACKUP_ZSTD_LEVEL", "6")
	sshOpts   = envOr("AI_BACKUP_SSH_OPTS", "-o BatchMode=yes -o ConnectTimeout=8")
)

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

// usageText is the bash header block (lines 2-31) as extracted by the
// awk in the original usage(): every "# " prefix stripped, printed to
// stdout for -h/--help/help (exit 0) AND for the restore missing-archive
// case (exit 1).
const usageText = `ai-backup - One-shot compressed backup/restore of AI assistant state.

Backs up Claude Code, OpenCode and Engram data from a source host
(default: mact2) into rog's samba share as a single .tar.zst archive:

  ~/.claude                      (conversations, history, skills, settings)
  ~/.config/opencode             (config, skills, plugins; no node_modules)
  ~/.local/share/opencode        (auth.json, storage, snapshot, delegations)
  ~/.engram                      (global engram DB)

Live SQLite databases (opencode *.db, engram.db) are snapshotted with
` + "`sqlite3 .backup`" + ` first — consistent even with WAL — and stored inside the
archive under home-snap/, which restore relocates to their live paths.

Usage:
  ai-backup [TARGET]              backup TARGET (default mact2) -> rog
  ai-backup list                  list archives in the destination
  ai-backup restore ARCHIVE [--to TARGET] [--dry-run]
                                  restore archive into TARGET ($HOME)

TARGET: local | mact2 | t14 | thinkcentre | user@host

Environment overrides:
  AI_BACKUP_DEST        destination root (default samba share on rog)
  AI_BACKUP_ZSTD_LEVEL  zstd level, 1-19 (default 6)
  AI_BACKUP_SSH_OPTS    extra ssh options

Exit codes:
  0 success  1 usage/config  2 ssh/connectivity  3 snapshot/backup failure
  4 restore failure
`

func usage(code int) {
	fmt.Print(usageText)
	os.Exit(code)
}

// --- Target resolution -------------------------------------------------------

// resolveTarget ports resolve_target(): shorthand targets map to
// user@host; anything else passes through.
func resolveTarget(t string) string {
	switch t {
	case "local":
		return "local"
	case "mact2":
		return "jcuzmar@mact2.local"
	case "t14":
		return "glats@t14.local"
	case "thinkcentre":
		return "glats@thinkcentre.local"
	default:
		return t // user@host passthrough
	}
}

// targetLabel ports target_label(): short filesystem-safe archive name.
// `local` → hostname; user@host → user-host with '.' and '/' mapped to
// '-' (the bash `tr './' '--'`).
func targetLabel(t string) string {
	if t == "local" {
		out, err := exec.Command("hostname").Output()
		if err != nil {
			os.Exit(exitCode(err))
		}
		return strings.TrimRight(string(out), "\n")
	}
	if user, host, ok := strings.Cut(t, "@"); ok {
		s := user + "-" + host
		return strings.Map(func(r rune) rune {
			if r == '.' || r == '/' {
				return '-'
			}
			return r
		}, s)
	}
	return t
}

// --- Process plumbing --------------------------------------------------------

// exitCode maps a subprocess failure to the shell's exit-code semantics:
// propagate the child's code, or 127 when the command could not run at
// all (bash "command not found").
func exitCode(err error) int {
	if exitErr, ok := err.(*exec.ExitError); ok {
		return exitErr.ExitCode()
	}
	return 127
}

// pipeSource wires src's stdout into dst's stdin through a real kernel
// pipe (bash `src | dst`): if dst exits early, src dies of SIGPIPE
// exactly like in a shell pipeline. Both stderr sides stay inherited.
// Must be followed by src.Wait() and dst.Wait().
func pipeSource(src, dst *exec.Cmd) error {
	pr, pw, err := os.Pipe()
	if err != nil {
		return err
	}
	src.Stdout = pw
	dst.Stdin = pr
	if err := src.Start(); err != nil {
		pr.Close()
		pw.Close()
		return err
	}
	if err := dst.Start(); err != nil {
		pw.Close() // src gets EPIPE and dies, like the bash pipeline
		src.Wait()
		pr.Close()
		return err
	}
	// Drop the parent copies so dst sees EOF once src exits.
	pr.Close()
	pw.Close()
	return nil
}

// pipeTwo runs `src | dst` and returns the pipeline's exit status with
// pipefail semantics: the rightmost failing stage wins.
func pipeTwo(src, dst *exec.Cmd) (int, error) {
	if err := pipeSource(src, dst); err != nil {
		return 127, err
	}
	srcErr := src.Wait()
	dstErr := dst.Wait()
	if dstErr != nil {
		return exitCode(dstErr), dstErr
	}
	if srcErr != nil {
		return exitCode(srcErr), srcErr
	}
	return 0, nil
}

// --- Remote payloads (POSIX sh, run on the source host) ----------------------
//
// Both payloads are the bash quoted heredocs verbatim: they run under
// /bin/sh -s with the script on stdin (locally or via ssh), emit their
// own messages, and own their exit codes.

const remoteBackupScript = `set -eu
HOME_DIR="$(cd ~ && pwd)"
SQLITE="$(command -v sqlite3 || echo /usr/bin/sqlite3)"
STAGING="$(mktemp -d "${TMPDIR:-/tmp}/ai-backup.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT INT TERM
mkdir -p "$STAGING/home-snap/.local/share/opencode" "$STAGING/home-snap/.engram"

snap() { # $1=live db path  $2=relative dest under home-snap/
  [ -f "$1" ] || return 0
  real="$(readlink -f "$1")"
  "$SQLITE" "$1" ".backup '$STAGING/home-snap/$2/$(basename "$real")'" || {
    echo "ai-backup: sqlite snapshot FAILED: $1" >&2
    exit 3
  }
}

for db in "$HOME_DIR"/.local/share/opencode/*.db; do
  [ -e "$db" ] || continue
  real="$(readlink -f "$db")"
  snap "$db" ".local/share/opencode"
done
snap "$HOME_DIR/.engram/engram.db" ".engram"

# Bail out before shipping if any snapshot is empty/corrupt.
for s in "$STAGING"/home-snap/.local/share/opencode/*.db "$STAGING"/home-snap/.engram/*.db; do
  [ -e "$s" ] || continue
  [ -s "$s" ] || { echo "ai-backup: empty snapshot: $s" >&2; exit 3; }
done

# NOTE: do not ` + "`exec`" + ` — the EXIT trap must survive to clean STAGING.
tar -cf - \
  --exclude='node_modules' \
  --exclude='.local/share/opencode/bin' \
  --exclude='.local/share/opencode/log' \
  --exclude='.local/share/opencode/logs' \
  --exclude='.local/share/opencode/*.db' \
  --exclude='.local/share/opencode/*.db-wal' \
  --exclude='.local/share/opencode/*.db-shm' \
  --exclude='.local/share/opencode/*.backup' \
  --exclude='.local/share/opencode/*.backup-*' \
  --exclude='.engram/engram.db' \
  --exclude='.engram/engram.db-wal' \
  --exclude='.engram/engram.db-shm' \
  --exclude='.engram/engram.db.*' \
  --exclude='.claude/cache' \
  -C "$HOME_DIR" .claude .config/opencode .local/share/opencode .engram \
  -C "$STAGING" home-snap
`

const remoteRestoreScript = `set -eu
SQLITE="$(command -v sqlite3 || echo /usr/bin/sqlite3)"
SNAP="$HOME/home-snap"
stamp="$(date +%Y%m%d-%H%M%S)"
place() { # $1=snapshot file  $2=live destination
  if [ -f "$2" ]; then
    echo "  replacing $(basename "$2") (old kept as $(basename "$2").pre-restore-$stamp)"
    mv "$2" "$2.pre-restore-$stamp"
  fi
  mkdir -p "$(dirname "$2")"
  mv "$1" "$2"
}
if [ -d "$SNAP" ]; then
  for f in "$SNAP"/.local/share/opencode/*.db; do
    [ -e "$f" ] || continue
    place "$f" "$HOME/.local/share/opencode/$(basename "$f")"
  done
  [ -f "$SNAP/.engram/engram.db" ] && place "$SNAP/.engram/engram.db" "$HOME/.engram/engram.db"
  rm -rf "$SNAP"
fi
echo "  integrity check:"
rc=0
for db in "$HOME"/.local/share/opencode/*.db "$HOME"/.engram/engram.db; do
  [ -f "$db" ] || continue
  out="$("$SQLITE" "$db" 'PRAGMA integrity_check;' 2>&1 | head -1)" || rc=1
  echo "    $(basename "$db"): $out"
done
exit $rc
`

// --- Run a POSIX sh snippet on a target (local or over ssh) ------------------

// runOnCmd builds /bin/sh -s (stdin = payload) for local targets, or
// `ssh $SSH_OPTS TARGET /bin/sh -s` for remote ones (SSH_OPTS is word
// split exactly like the unquoted bash expansion).
func runOnCmd(target, payload string) *exec.Cmd {
	var cmd *exec.Cmd
	if target == "local" {
		cmd = exec.Command("/bin/sh", "-s")
	} else {
		args := append(strings.Fields(sshOpts), target, "/bin/sh", "-s")
		cmd = exec.Command("ssh", args...)
	}
	cmd.Stdin = strings.NewReader(payload)
	return cmd
}

// sshRC runs a remote command with inherited stdio and returns its exit
// code (127 if ssh could not be started, like bash).
func sshRC(target, remoteCmd string) int {
	cmd := exec.Command("ssh", append(strings.Fields(sshOpts), target, remoteCmd)...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	err := cmd.Run()
	if err == nil {
		return 0
	}
	return exitCode(err)
}

// --- Subcommand: backup ------------------------------------------------------

func doBackup(targetArg string) {
	target := resolveTarget(targetArg)
	label := targetLabel(targetArg)

	if target != "local" {
		fmt.Printf("ai-backup: checking %s ...\n", target)
		if sshRC(target, `command -v sqlite3 >/dev/null || echo "WARN: sqlite3 not in PATH, will use /usr/bin/sqlite3"`) != 0 {
			fmt.Fprintf(os.Stderr, "ERROR: cannot reach %s\n", target)
			os.Exit(2)
		}
	}

	outDir := filepath.Join(dest, label)
	if err := os.MkdirAll(outDir, 0o755); err != nil {
		fmt.Fprintln(os.Stderr, err) // bash: mkdir -p failure under set -e
		os.Exit(1)
	}
	ts := time.Now().Format("20060102-150405")
	archive := filepath.Join(outDir, fmt.Sprintf("ai-backup-%s-%s.tar.zst", label, ts))
	part := archive + ".part"

	fmt.Printf("ai-backup: %s -> %s\n", target, archive)
	fmt.Printf("           snapshotting sqlite, tarring, compressing (zstd -%s) ...\n", zstdLevel)
	t0 := time.Now().Unix()

	// run_on "$target" < payload | zstd -T0 -$LEVEL > "$part"
	src := runOnCmd(target, remoteBackupScript)
	z := exec.Command("zstd", "-T0", "-"+zstdLevel)
	f, err := os.Create(part)
	if err != nil {
		fmt.Fprintln(os.Stderr, err) // bash: redirection failure under set -e
		os.Exit(1)
	}
	z.Stdout = f
	if _, pipeErr := pipeTwo(src, z); pipeErr != nil {
		f.Close()
		os.Remove(part)
		fmt.Fprintln(os.Stderr, "ERROR: backup stream failed; partial file removed.")
		os.Exit(3)
	}
	f.Close()
	t1 := time.Now().Unix()

	if err := os.Rename(part, archive); err != nil {
		fmt.Fprintln(os.Stderr, err) // bash: mv failure under set -e
		os.Exit(1)
	}

	// ( cd "$out_dir" && sha256sum "$(basename ...)" > "$(basename ...).sha256" )
	shaFile, err := os.Create(archive + ".sha256")
	if err != nil {
		fmt.Fprintln(os.Stderr, err) // bash: redirection failure under set -e
		os.Exit(1)
	}
	sha := exec.Command("sha256sum", filepath.Base(archive))
	sha.Dir = outDir
	sha.Stdout = shaFile
	sha.Stderr = os.Stderr
	if err := sha.Run(); err != nil {
		os.Exit(exitCode(err))
	}
	shaFile.Close()

	size := duSize(archive)
	fmt.Printf("ai-backup: done in %ds — %s  %s\n", t1-t0, size, filepath.Base(archive))
	fmt.Printf("           sha256 recorded in %s.sha256\n", filepath.Base(archive))
}

// duSize ports `$(du -h FILE | cut -f1)`: first TAB-separated field of
// du's human-readable size. A du failure dies silently with its exit
// code (bash: failing $(...) assignment under set -e + pipefail).
func duSize(path string) string {
	out, err := exec.Command("du", "-h", path).Output()
	if err != nil {
		os.Exit(exitCode(err))
	}
	line := strings.TrimRight(string(out), "\n")
	if i := strings.Index(line, "\t"); i >= 0 {
		return line[:i]
	}
	return line
}

// --- Subcommand: list --------------------------------------------------------

func doList() {
	if fi, err := os.Stat(dest); err != nil || !fi.IsDir() {
		fmt.Printf("ai-backup: no destination yet at %s\n", dest)
		return
	}
	// find ... -print0 | sort -z -r — exec'd as in bash; a failed
	// process substitution just yields no input (→ "no archives yet").
	find := exec.Command("find", dest, "-name", "ai-backup-*.tar.zst", "-print0")
	sortCmd := exec.Command("sort", "-z", "-r")
	var buf bytes.Buffer
	sortCmd.Stdout = &buf
	if pipeSource(find, sortCmd) == nil {
		find.Wait()
		sortCmd.Wait()
	}
	found := false
	for _, archive := range strings.Split(buf.String(), "\x00") {
		if archive == "" {
			continue
		}
		found = true
		fmt.Printf("%s  %s\n", duSize(archive), strings.TrimPrefix(archive, dest+"/"))
	}
	if !found {
		fmt.Printf("ai-backup: no archives yet at %s\n", dest)
	}
}

// --- Subcommand: restore -----------------------------------------------------

func doRestore(args []string) {
	archive := ""
	to := "local"
	dry := false
	for len(args) > 0 {
		switch {
		case args[0] == "--to":
			if len(args) < 2 {
				// bash: `to="$2"` with $2 unset dies under set -u
				// ("unbound variable", exit 1); the closest equivalent
				// here is an explicit config error.
				fmt.Fprintln(os.Stderr, "ERROR: --to requires a value")
				os.Exit(1)
			}
			to = args[1]
			args = args[2:]
		case strings.HasPrefix(args[0], "--to="):
			to = strings.TrimPrefix(args[0], "--to=")
			args = args[1:]
		case args[0] == "--dry-run":
			dry = true
			args = args[1:]
		case args[0] == "-h", args[0] == "--help":
			usage(0)
		default:
			archive = args[0] // last positional wins
			args = args[1:]
		}
	}
	if archive == "" {
		usage(1)
	}
	if fi, err := os.Stat(archive); err != nil || !fi.Mode().IsRegular() {
		fmt.Fprintf(os.Stderr, "ERROR: archive not found: %s\n", archive)
		os.Exit(1)
	}
	if _, err := os.Stat(archive + ".sha256"); err == nil {
		fmt.Println("ai-backup: verifying sha256 ...")
		sha := exec.Command("sha256sum", "-c", filepath.Base(archive)+".sha256")
		sha.Dir = filepath.Dir(archive)
		sha.Stdout = os.Stdout
		sha.Stderr = os.Stderr
		if err := sha.Run(); err != nil {
			fmt.Fprintln(os.Stderr, "ERROR: sha256 mismatch")
			os.Exit(4)
		}
	}

	target := resolveTarget(to)

	if dry {
		fmt.Printf("ai-backup: DRY RUN — members of %s:\n", filepath.Base(archive))
		listing, rc := tarListing(archive)
		var lines []string
		if listing != "" {
			lines = strings.Split(strings.TrimRight(listing, "\n"), "\n")
		}
		total := 0
		for _, line := range lines {
			total += len(line) + 3 // "  " prefix + newline
		}
		for i, line := range lines {
			if i >= 60 {
				break
			}
			fmt.Println("  " + line)
		}
		// Pipeline failure (bad archive): the bash dies under set -e
		// with the pipeline's code, after whatever head printed.
		if rc != 0 {
			os.Exit(rc)
		}
		// pipefail+head SIGPIPE quirk (see package doc): listings big
		// enough kill the bash script silently with 141 — the trailer
		// is never printed.
		if len(lines) > 60 && total > 6*1024 {
			os.Exit(141)
		}
		fmt.Println("  ... (full list: zstd -dc ARCHIVE | tar -tf -)")
		return
	}

	fmt.Printf("ai-backup: restoring %s -> %s:$HOME\n", filepath.Base(archive), target)
	fmt.Println("           (close opencode/claude on the target first)")
	rc := 0
	if target == "local" {
		z := exec.Command("zstd", "-dc", archive)
		t := exec.Command("tar", "-xf", "-", "-C", os.Getenv("HOME"))
		t.Stdout = os.Stdout
		if _, err := pipeTwo(z, t); err != nil {
			rc = 1
		}
		if rc == 0 {
			sh := runOnCmd("local", remoteRestoreScript)
			sh.Stdout = os.Stdout
			sh.Stderr = os.Stderr
			if err := sh.Run(); err != nil {
				rc = 1
			}
		}
	} else {
		// zstd -dc ARCHIVE | ssh $SSH_OPTS TARGET "tar -xf - -C \$HOME"
		z := exec.Command("zstd", "-dc", archive)
		s := exec.Command("ssh", append(strings.Fields(sshOpts), target, "tar -xf - -C $HOME")...)
		s.Stdout = os.Stdout
		if _, err := pipeTwo(z, s); err != nil {
			rc = 1
		}
		if rc == 0 {
			sh := runOnCmd(target, remoteRestoreScript)
			sh.Stdout = os.Stdout
			sh.Stderr = os.Stderr
			if err := sh.Run(); err != nil {
				rc = 1
			}
		}
	}
	if rc == 0 {
		fmt.Println("ai-backup: restore complete.")
	}
	os.Exit(rc)
}

// tarListing ports `zstd -dc ARCHIVE | tar -tf -`: returns the raw
// member listing (stdout captured, stderr inherited) and the pipeline's
// pipefail exit status (rightmost failing stage, like bash's $?).
func tarListing(archive string) (string, int) {
	z := exec.Command("zstd", "-dc", archive)
	t := exec.Command("tar", "-tf", "-")
	var out bytes.Buffer
	t.Stdout = &out
	rc, _ := pipeTwo(z, t)
	return out.String(), rc
}

// --- Main --------------------------------------------------------------------

func main() {
	args := os.Args[1:]
	// No subcommand or a bare TARGET means: run a backup (default mact2).
	switch {
	case len(args) == 0:
		doBackup("mact2")
	case args[0] == "backup":
		target := "mact2"
		if len(args) > 1 {
			target = args[1]
		}
		doBackup(target)
	case args[0] == "list":
		doList()
	case args[0] == "restore":
		doRestore(args[1:])
	case args[0] == "-h", args[0] == "--help", args[0] == "help":
		usage(0)
	default:
		doBackup(args[0])
	}
}
