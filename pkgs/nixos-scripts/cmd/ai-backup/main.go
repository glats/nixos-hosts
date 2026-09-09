// Command ai-backup performs one-shot compressed backup/restore of AI
// assistant state (Claude Code, OpenCode, Engram) as a single .tar.zst
// archive, with consistent sqlite snapshots taken on the source host.
//
// Go port of the retired bin/ai-backup bash script: messages, flags,
// env overrides, pipeline shapes and the 0/1/2/3/4 exit-code categories
// are preserved. The embedded POSIX-sh payloads are NOT a verbatim
// port: SDD change ai-backup-manifest-scope redesigned them around an
// explicit tar member list (no --exclude patterns), .db.snapshot
// staging and a symlink-safe restore — each payload's comment block
// carries the rationale.
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
// AI_BACKUP_EXTRA (space-separated project .engram/ directory paths,
// archived as chunks/, manifest.json and config.json only) is read on
// the orchestrating host and forwarded into the backup payload as an
// sh assignment: ssh does not forward environment variables, so
// injecting the value into the payload keeps local and ssh targets
// identical.
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

// usageText is the CLI help header: printed to stdout for -h/--help/
// help (exit 0) AND for the restore missing-archive case (exit 1).
// The member-list summary below is the documented backup manifest; it
// must stay in sync with remoteBackupScript (asserted by
// TestUsageTextDescribesManifest).
const usageText = `ai-backup - One-shot compressed backup/restore of AI assistant state.

Backs up Claude Code, OpenCode and Engram state from a source host
(default: mact2) into rog's samba share as a single .tar.zst archive.
The archive is an explicit member list — no --exclude patterns — so
only the following ever enters it:

  ~/.claude                      (projects/, history.jsonl, plans/,
                                  todos/, keybindings.json, nested
                                  .claude/ tree)
  ~/.claude.json                 (Claude config; may hold OAuth tokens)
  ~/.local/share/opencode        (storage/, auth.json,
                                  opencode-multimodal.json)
  ~/.engram                      (engram.db snapshot only; the live
                                  tree is never archived)
  home-snap/                     (staged sqlite snapshots, see below)
  $AI_BACKUP_EXTRA dirs          (project .engram/{chunks,manifest.json,
                                  config.json})

Live SQLite databases (channel-dependent opencode-<channel>.db and
engram.db) are snapshotted with ` + "`sqlite3 .backup`" + ` first — consistent even
with WAL — staged under home-snap/ as <real-basename>.db.snapshot
(symlinks resolved first). Backup fails with exit 3 unless at least
one non-empty OpenCode snapshot exists; restore relocates snapshots to
their live paths, keeps timestamped pre-restore copies and preserves
existing symlinks.

Regenerable or live state is excluded by not being listed:
.config/opencode, opencode bin/log/snapshot dirs, live *.db and their
-wal/-shm sidecars, node_modules, Claude caches/settings/skills/
credentials — Claude Code re-authenticates after a restore.

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
  AI_BACKUP_EXTRA       space-separated project .engram/ dirs to include

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
// All three payloads run under /bin/sh -s with the script on stdin
// (locally or via ssh), emit their own messages, and own their exit
// codes. They must stay POSIX-compatible: restore targets include
// macOS, so no bashisms.

// remoteBackupScript is the backup payload: stage consistent sqlite
// snapshots, validate them, then stream an archive built from an
// EXPLICIT member list. The member list below IS the backup manifest —
// the only auditable artifact of what is archived.
//
// The first line of the shipped payload is the AI_BACKUP_EXTRA
// assignment injected by backupPayload() (see its comment).
const remoteBackupScript = `set -eu
HOME_DIR="$(cd ~ && pwd)"
SQLITE="$(command -v sqlite3 || echo /usr/bin/sqlite3)"
STAGING="$(mktemp -d "${TMPDIR:-/tmp}/ai-backup.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT INT TERM
mkdir -p "$STAGING/home-snap/.local/share/opencode" "$STAGING/home-snap/.engram"

# Snapshot one live sqlite database into home-snap/.
#   $1 = live db path   $2 = destination dir under home-snap/
# The live path is resolved with readlink -f first (opencode.db is a
# symlink to opencode-stable.db on some hosts, and Home Manager
# re-creates that symlink on every rebuild) and the staged copy is
# named after the REAL basename plus a .snapshot suffix. The suffix
# keeps staged copies distinct from live *.db so the explicit tar
# member list below (which includes the home-snap/ tree wholesale) can
# never pick up a live database, and so a snapshot moved back by a
# restore is never mistaken for a live db by this payload's *.db
# globs. Two live symlink names resolving to the same real db stage
# one file (the second .backup overwrites the first, same content).
snap() { # $1=live db path  $2=relative dest dir under home-snap/
  [ -f "$1" ] || return 0
  real="$(readlink -f "$1")"
  "$SQLITE" "$1" ".backup '$STAGING/home-snap/$2/$(basename "$real").snapshot'" || {
    echo "ai-backup: sqlite snapshot FAILED: $1" >&2
    exit 3
  }
}

# OpenCode: database names are channel-dependent (opencode-<channel>.db,
# e.g. opencode-main.db) and the live db is typically a symlink, so
# snapshot every *.db the data dir exposes; realpath naming in snap()
# collapses duplicates.
for db in "$HOME_DIR"/.local/share/opencode/*.db; do
  [ -e "$db" ] || continue
  snap "$db" ".local/share/opencode"
done
# Engram: only the global db rides, as its snapshot. The live tree is
# never archived, so stale engram.db.before-* / engram.db.pre-cleanup.*
# copies and the -wal/-shm sidecars cannot enter (they are not staged).
snap "$HOME_DIR/.engram/engram.db" ".engram"

# Fail closed BEFORE anything is published: at least one non-empty
# OpenCode snapshot must exist, and every staged snapshot must be
# non-empty. A backup carrying zero OpenCode state would be silent
# data loss pretending to succeed.
snapcount=0
for s in "$STAGING"/home-snap/.local/share/opencode/*.db.snapshot; do
  [ -e "$s" ] || continue
  [ -s "$s" ] || { echo "ai-backup: empty snapshot: $s" >&2; exit 3; }
  snapcount=$((snapcount + 1))
done
[ "$snapcount" -ge 1 ] || {
  echo "ai-backup: no OpenCode database snapshots staged (expected opencode-<channel>.db under $HOME_DIR/.local/share/opencode)" >&2
  exit 3
}
for s in "$STAGING"/home-snap/.engram/*.db.snapshot; do
  [ -e "$s" ] || continue
  [ -s "$s" ] || { echo "ai-backup: empty snapshot: $s" >&2; exit 3; }
done

# Home members: the manifest. Members absent on this host (fresh
# installs may lack some) are skipped silently; everything listed is
# archived, and nothing else is — .config/opencode, opencode bin/log/
# snapshot dirs, live *.db and sidecars, node_modules, Claude caches,
# settings and credentials are excluded by NOT BEING NAMED. There are
# deliberately zero --exclude patterns: no portable pattern syntax
# exists (bsdtar suffix-matches unanchored patterns; GNU tar reads a
# leading ^ as a literal), so an enumerated list is the only thing
# auditable on both tar flavors.
set --
for m in \
  .claude/projects \
  .claude/history.jsonl \
  .claude/plans \
  .claude/todos \
  .claude/keybindings.json \
  .claude/.claude \
  .claude.json \
  .local/share/opencode/storage \
  .local/share/opencode/auth.json \
  .local/share/opencode/opencode-multimodal.json
do
  [ -e "$HOME_DIR/$m" ] || continue
  set -- "$@" "$m"
done

# Project engram dirs, opt-in via AI_BACKUP_EXTRA: a space-separated
# list of project .engram/ directory paths on the source host (the Go
# wrapper forwards the value from the orchestrating host as an
# assignment at the top of this payload). For each existing dir, only
# the required members — chunks/, manifest.json, config.json — are
# copied VERBATIM into STAGING/extras/<project>/.engram/ (where
# <project> is the dir's own parent basename), then tar'd from
# $STAGING. Copying is what preserves the <project>/.engram/...
# member layout: tar -C cannot add path prefixes (a plain -C
# "<parent>" would archive members as .engram/... and clobber the
# global ~/.engram on restore). Copying (instead of archiving in
# place) also guarantees the live project engram.db and its rotate/
# sidecar siblings never enter. On restore these land untouched
# under ~/extras/<project>/.engram/. Absent dirs and members are
# skipped silently.
for extra in ${AI_BACKUP_EXTRA:-}; do
  [ -d "$extra" ] || continue
  proj="$(basename "$(dirname "$extra")")"
  for m in chunks manifest.json config.json; do
    [ -e "$extra/$m" ] || continue
    mkdir -p "$STAGING/extras/$proj/.engram"
    cp -pR "$extra/$m" "$STAGING/extras/$proj/.engram/$m"
  done
done

# NOTE: do not exec — the EXIT trap must survive to clean STAGING.
# COPYFILE_DISABLE=1 stops macOS bsdtar from injecting copyfile xattr
# headers and AppleDouble members; it is a no-op under GNU tar. The
# extras/ branch only fires when AI_BACKUP_EXTRA staged anything, so
# the archetype (single tar invocation, explicit member list) stays.
if [ -d "$STAGING/extras" ]; then
  COPYFILE_DISABLE=1 tar -cf - \
    -C "$HOME_DIR" "$@" \
    -C "$STAGING" home-snap extras
else
  COPYFILE_DISABLE=1 tar -cf - \
    -C "$HOME_DIR" "$@" \
    -C "$STAGING" home-snap
fi
`

// preRestoreScript runs BEFORE tar extraction on the restore target:
// the archive's .claude.json member overwrites the live file during
// the plain-file extraction, so the current one must be kept first.
const preRestoreScript = `set -eu
stamp="$(date +%Y%m%d-%H%M%S)"
if [ -f "$HOME/.claude.json" ]; then
  cp -p "$HOME/.claude.json" "$HOME/.claude.json.pre-restore-$stamp"
  echo "  kept old .claude.json as .claude.json.pre-restore-$stamp"
fi
`

// remoteRestoreScript relocates the staged snapshots to their live
// paths and verifies every database it can find.
const remoteRestoreScript = `set -eu
SQLITE="$(command -v sqlite3 || echo /usr/bin/sqlite3)"
SNAP="$HOME/home-snap"
stamp="$(date +%Y%m%d-%H%M%S)"
# Place a staged snapshot at its live destination.
#   $1 = staged .db.snapshot   $2 = live destination path
# The .snapshot suffix is stripped on relocation: the staged name is
# <real-basename>.db.snapshot, the live name is the realpath basename.
# An existing destination SYMLINK is resolved first — moving onto a
# symlink would follow it and clobber the real target (rog keeps
# opencode.db as a symlink to opencode-stable.db, and Home Manager
# re-creates that symlink on rebuild), so the snapshot is placed at
# the resolved path and the symlink itself survives untouched.
place() { # $1=snapshot file  $2=live destination
  dest="$2"
  if [ -L "$dest" ]; then
    dest="$(readlink -f "$dest")"
  fi
  mkdir -p "$(dirname "$dest")"
  if [ -f "$dest" ]; then
    echo "  replacing $(basename "$dest") (old kept as $(basename "$dest").pre-restore-$stamp)"
    mv "$dest" "$dest.pre-restore-$stamp"
  fi
  mv "$1" "$dest"
}
if [ -d "$SNAP" ]; then
  for f in "$SNAP"/.local/share/opencode/*.db.snapshot; do
    [ -e "$f" ] || continue
    name="$(basename "$f")"
    place "$f" "$HOME/.local/share/opencode/${name%.snapshot}"
  done
  for f in "$SNAP"/.engram/*.db.snapshot; do
    [ -e "$f" ] || continue
    name="$(basename "$f")"
    place "$f" "$HOME/.engram/${name%.snapshot}"
  done
  rm -rf "$SNAP"
fi
# Every database under the restored paths must pass
# PRAGMA integrity_check and its output must say ok: the pipeline's
# exit status is head's (the payload does not set pipefail), so the
# output text is the authoritative failure signal. Pre-existing dbs
# are checked too — corruption is not allowed to hide behind a
# successful relocation.
echo "  integrity check:"
rc=0
for db in "$HOME"/.local/share/opencode/*.db "$HOME"/.engram/*.db; do
  [ -f "$db" ] || continue
  out="$("$SQLITE" "$db" 'PRAGMA integrity_check;' 2>&1 | head -1)"
  echo "    $(basename "$db"): $out"
  case "$out" in
    ok) ;;
    *) rc=1 ;;
  esac
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

// shQuote renders s as a single POSIX-sh word: single quotes around it,
// with embedded single quotes replaced by the '\'' escape sequence.
func shQuote(s string) string {
	return "'" + strings.ReplaceAll(s, "'", `'\''`) + "'"
}

// backupPayload returns the payload shipped to the source host for a
// backup: the AI_BACKUP_EXTRA value captured on THIS host is prepended
// as an sh assignment. The injection exists because ssh does not
// forward environment variables — without it, extras would work only
// for local targets.
func backupPayload() string {
	return "AI_BACKUP_EXTRA=" + shQuote(os.Getenv("AI_BACKUP_EXTRA")) + "\n" + remoteBackupScript
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
	src := runOnCmd(target, backupPayload())
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
	// Restore-phase failures (pre-restore copy, extraction, snapshot
	// relocation, integrity check) map to exit 4 — the documented
	// "restore failure" category (design decision; the retired bash
	// returned 1 here, its own header already claimed 4).
	rc := 0
	runPayload := func(payload string) {
		sh := runOnCmd(target, payload)
		sh.Stdout = os.Stdout
		sh.Stderr = os.Stderr
		if err := sh.Run(); err != nil && rc == 0 {
			rc = 4
		}
	}
	// Keep the current .claude.json before the archive's plain-file
	// member overwrites it during extraction.
	runPayload(preRestoreScript)
	if rc == 0 {
		if target == "local" {
			// No --warning=no-unknown-keyword is added on the extract
			// side: the source-side COPYFILE_DISABLE=1 suppression is
			// authoritative, and that keyword is GNU-tar-only — bsdtar
			// on macOS targets rejects unknown warnings, so passing it
			// would disturb remote portability (design: apply only if
			// it keeps that portability).
			z := exec.Command("zstd", "-dc", archive)
			t := exec.Command("tar", "-xf", "-", "-C", os.Getenv("HOME"))
			t.Stdout = os.Stdout
			if _, err := pipeTwo(z, t); err != nil {
				rc = 4
			}
		} else {
			// zstd -dc ARCHIVE | ssh $SSH_OPTS TARGET "tar -xf - -C \$HOME"
			z := exec.Command("zstd", "-dc", archive)
			s := exec.Command("ssh", append(strings.Fields(sshOpts), target, "tar -xf - -C $HOME")...)
			s.Stdout = os.Stdout
			if _, err := pipeTwo(z, s); err != nil {
				rc = 4
			}
		}
	}
	if rc == 0 {
		// Relocate snapshots, preserve symlinks, integrity-check.
		runPayload(remoteRestoreScript)
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
