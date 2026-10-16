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

const usageText = `ai-backup - One-shot compressed backup/restore of AI assistant state.

Backs up Claude Code, OpenCode and Engram state from a source host
(default: macm5) into rog's samba share as a single .tar.zst archive.
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
  ai-backup [TARGET]              backup TARGET (default macm5) -> rog
  ai-backup list                  list archives in the destination
  ai-backup restore ARCHIVE [--to TARGET] [--dry-run] [--force]
                                  restore archive into TARGET ($HOME)

TARGET: local | macm5 | t14 | thinkcentre | user@host

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

func resolveTarget(t string) string {
	switch t {
	case "local":
		return "local"
	case "macm5":
		return "juan@macm5"
	case "t14":
		return "glats@t14.local"
	case "thinkcentre":
		return "glats@thinkcentre.local"
	default:
		return t
	}
}

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

func exitCode(err error) int {
	if exitErr, ok := err.(*exec.ExitError); ok {
		return exitErr.ExitCode()
	}
	return 127
}

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
		pw.Close()
		src.Wait()
		pr.Close()
		return err
	}

	pr.Close()
	pw.Close()
	return nil
}

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

const preRestoreScript = `set -eu
# Runs after the pre-flight has passed (clean target or explicit
# --force) and before extraction: the archive's plain-file members
# overwrite whatever exists, so every irreplaceable live item is moved
# aside first as .pre-restore-<stamp> — restore REPLACES state, it
# never silently merges it. Databases are handled post-extract in
# remoteRestoreScript (which also resolves destination symlinks).
stamp="$(date +%Y%m%d-%H%M%S)"
if [ -f "$HOME/.claude.json" ]; then
  cp -p "$HOME/.claude.json" "$HOME/.claude.json.pre-restore-$stamp"
  echo "  kept old .claude.json as .claude.json.pre-restore-$stamp"
fi
for path in \
  .claude/projects \
  .claude/history.jsonl \
  .claude/.claude \
  .local/share/opencode/storage \
  .local/share/opencode/auth.json
do
  if [ -e "$HOME/$path" ]; then
    mv "$HOME/$path" "$HOME/$path.pre-restore-$stamp"
    echo "  kept old $path as $path.pre-restore-$stamp"
  fi
done
`

const restorePreflightScript = `set -eu
if [ "${AI_BACKUP_RESTORE_FORCE:-0}" = "1" ]; then
  echo "ai-backup: pre-flight skipped (--force)"
  exit 0
fi
for p in opencode claude; do
  if pgrep -x "$p" >/dev/null 2>&1; then
    echo "ai-backup: REFUSING — $p is running on this target; close it before restoring (or pass --force)" >&2
    exit 4
  fi
done
hits=""
for path in \
  "$HOME/.claude.json" \
  "$HOME/.claude/projects" \
  "$HOME/.claude/history.jsonl" \
  "$HOME/.claude/.claude" \
  "$HOME/.local/share/opencode/auth.json" \
  "$HOME/.local/share/opencode/storage" \
  "$HOME/.engram/engram.db"
do
  if [ -e "$path" ]; then
    hits="$hits $path"
  fi
done
for db in "$HOME"/.local/share/opencode/*.db; do
  if [ -e "$db" ]; then
    hits="$hits $(readlink -f "$db")"
  fi
done
if [ -n "$hits" ]; then
  echo "ai-backup: REFUSING — target already has state that this restore would overwrite:" >&2
  for h in $hits; do
    echo "  $h" >&2
  done
  echo "  re-run with --force to proceed; every replaced item is kept as a .pre-restore-<ts> copy" >&2
  exit 4
fi
echo "ai-backup: pre-flight clean — nothing to overwrite on target."
`

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

func runOnCmd(target, payload string) *exec.Cmd {
	var cmd *exec.Cmd
	if target == "local" {
		cmd = exec.Command("/bin/sh", "-s")
	} else {
		args := append(strings.Fields(sshOpts), target, "/bin/sh", "-s")
		cmd = exec.Command("ssh", args...)
	}
	cmd.Stdin = strings.NewReader(payload)

	cmd.Stderr = os.Stderr
	return cmd
}

func shQuote(s string) string {
	return "'" + strings.ReplaceAll(s, "'", `'\''`) + "'"
}

func backupPayload() string {
	return "AI_BACKUP_EXTRA=" + shQuote(os.Getenv("AI_BACKUP_EXTRA")) + "\n" + remoteBackupScript
}

func restorePreflightPayload(force bool) string {
	v := "0"
	if force {
		v = "1"
	}
	return "AI_BACKUP_RESTORE_FORCE=" + v + "\n" + restorePreflightScript
}

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
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	ts := time.Now().Format("20060102-150405")
	archive := filepath.Join(outDir, fmt.Sprintf("ai-backup-%s-%s.tar.zst", label, ts))
	part := archive + ".part"

	fmt.Printf("ai-backup: %s -> %s\n", target, archive)
	fmt.Printf("           snapshotting sqlite, tarring, compressing (zstd -%s) ...\n", zstdLevel)
	t0 := time.Now().Unix()

	src := runOnCmd(target, remoteBackupScript)
	z := exec.Command("zstd", "-T0", "-"+zstdLevel)
	z.Stderr = os.Stderr
	f, err := os.Create(part)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
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
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}

	shaFile, err := os.Create(archive + ".sha256")
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
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

func doList() {
	if fi, err := os.Stat(dest); err != nil || !fi.IsDir() {
		fmt.Printf("ai-backup: no destination yet at %s\n", dest)
		return
	}

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

func doRestore(args []string) {
	archive := ""
	to := "local"
	dry := false
	force := false
	for len(args) > 0 {
		switch {
		case args[0] == "--to":
			if len(args) < 2 {

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
		case args[0] == "--force":
			force = true
			args = args[1:]
		case args[0] == "-h", args[0] == "--help":
			usage(0)
		default:
			archive = args[0]
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
			total += len(line) + 3
		}
		for i, line := range lines {
			if i >= 60 {
				break
			}
			fmt.Println("  " + line)
		}

		if rc != 0 {
			os.Exit(rc)
		}

		if len(lines) > 60 && total > 6*1024 {
			os.Exit(141)
		}
		fmt.Println("  ... (full list: zstd -dc ARCHIVE | tar -tf -)")
		return
	}

	fmt.Printf("ai-backup: restoring %s -> %s:$HOME\n", filepath.Base(archive), target)
	fmt.Println("           (pre-flight refuses if opencode/claude run or state exists — override with --force)")

	rc := 0
	runPayload := func(payload string) {
		sh := runOnCmd(target, payload)
		sh.Stdout = os.Stdout
		sh.Stderr = os.Stderr
		if err := sh.Run(); err != nil && rc == 0 {
			rc = 4
		}
	}

	runPayload(restorePreflightPayload(force))
	if rc != 0 {
		os.Exit(rc)
	}

	runPayload(preRestoreScript)
	if rc == 0 {
		if target == "local" {

			z := exec.Command("zstd", "-dc", archive)
			t := exec.Command("tar", "-xf", "-", "-C", os.Getenv("HOME"))
			t.Stdout = os.Stdout
			if _, err := pipeTwo(z, t); err != nil {
				rc = 4
			}
		} else {

			z := exec.Command("zstd", "-dc", archive)
			s := exec.Command("ssh", append(strings.Fields(sshOpts), target, "tar -xf - -C $HOME")...)
			s.Stdout = os.Stdout
			if _, err := pipeTwo(z, s); err != nil {
				rc = 4
			}
		}
	}
	if rc == 0 {

		runPayload(remoteRestoreScript)
	}
	if rc == 0 {
		fmt.Println("ai-backup: restore complete.")
	}
	os.Exit(rc)
}

func tarListing(archive string) (string, int) {
	z := exec.Command("zstd", "-dc", archive)
	t := exec.Command("tar", "-tf", "-")
	var out bytes.Buffer
	t.Stdout = &out
	rc, _ := pipeTwo(z, t)
	return out.String(), rc
}

func main() {
	args := os.Args[1:]

	switch {
	case len(args) == 0:
		doBackup("macm5")
	case args[0] == "backup":
		target := "macm5"
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
