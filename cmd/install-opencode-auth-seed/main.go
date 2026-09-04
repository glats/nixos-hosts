// Command install-opencode-auth-seed fetches an age-encrypted OpenCode
// auth seed from rog's public uploads/ tree, decrypts it with the local
// sops age identity, backs up the existing auth.json and merges only the
// seed payload into it.
//
// Port of bin/install-opencode-auth-seed: usage text, messages, flags,
// env overrides and exit codes preserved byte-for-byte.
//
//	0 success · 1 args/config · 2 fetch · 3 decrypt · 4 json · 5 backup
//	· 6 merge
//
// The seed artifact is age ciphertext; plaintext auth material is
// refused (first-line header check) before anything touches auth.json.
// The Go command never inspects plaintext beyond handing the files to
// the external tools: curl (fetch), age (decrypt) and jq (validate and
// merge) are exec'd exactly where the bash original did — the preflight
// requires them in PATH with the same error vocabulary, and the merge
// runs the same jq program verbatim.
//
// Deviations from the bash original:
//   - a flag missing its value (`--seed-url` as the last argument) dies
//     in bash via set -u ("unbound variable", exit 1, script-specific
//     message); the port prints "ERROR: --seed-url requires a value"
//     and exits 1 — same code, self-contained message.
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

// --- Configuration (override via flags or env) ---
var (
	seedURL  = envOr("SEED_URL", "https://glats.org/uploads/opencode/mact2-auth-seed.age")
	authFile = envOr("AUTH_FILE", os.Getenv("HOME")+"/.local/share/opencode/auth.json")
	keyFile  = envOr("KEY_FILE", os.Getenv("HOME")+"/.config/sops/age/keys.txt")
	dryRun   bool
)

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

const ageHeader = "-----BEGIN AGE ENCRYPTED FILE-----"

// exitCode maps a subprocess failure to the shell's exit-code semantics:
// propagate the child's code, or 127 when the command could not run at
// all (bash "command not found").
func exitCode(err error) int {
	if exitErr, ok := err.(*exec.ExitError); ok {
		return exitErr.ExitCode()
	}
	return 127
}

// jqMergeProgram is the bash merge jq program verbatim (the
// single-quoted argument): existing keys win on conflict EXCEPT keys
// whose value is null/empty, in which case the seed value is promoted.
const jqMergeProgram = `
      .[0] as $existing | .[1] as $seed
      | reduce ($seed | keys[]) as $k ({}; .[$k] = (if ($existing[$k] // null) != null and ($existing[$k] | type) != "null" then $existing[$k] else $seed[$k] end))
      | $existing + .
    `

func usage(w *os.File) {
	fmt.Fprintf(w, `Usage: %s [OPTIONS]

Fetch an age-encrypted OpenCode auth seed from rog's uploads/ tree,
decrypt it with the local age identity, back up the existing auth.json,
and merge the seed payload into ~/.local/share/opencode/auth.json.

Options:
  --seed-url URL     Override the seed URL (default: %s)
  --auth-file PATH   Override the auth.json path (default: %s)
  --key-file PATH    Override the age identity path (default: %s)
  --dry-run          Fetch + decrypt only; do not touch auth.json
  -h, --help         Show this help message

Environment variables (override defaults):
  SEED_URL    Seed URL
  AUTH_FILE   Local auth.json path
  KEY_FILE    Local age identity path

Exit codes:
  0 success  1 args  2 fetch  3 decrypt  4 json  5 backup  6 merge
`, filepath.Base(os.Args[0]), seedURL, authFile, keyFile)
}

// firstLine returns the first line of data (head -1).
func firstLine(data []byte) string {
	if i := bytes.IndexByte(data, '\n'); i >= 0 {
		return string(data[:i])
	}
	return string(data)
}

// isAgeCiphertext ports `head -1 | grep -q '^-----BEGIN AGE ENCRYPTED
// FILE-----'`: anything without the armored header is treated as
// plaintext and refused.
func isAgeCiphertext(first string) bool {
	return strings.HasPrefix(first, ageHeader)
}

// jqCheck ports `jq -e . FILE >/dev/null 2>&1`.
func jqCheck(path string) bool {
	return exec.Command("jq", "-e", ".", path).Run() == nil
}

// jqRun ports `jq . FILE >&2 || cat FILE >&2`: best-effort pretty print
// of an invalid JSON file to stderr.
func jqDumpToStderr(path string) {
	cmd := exec.Command("jq", ".", path)
	cmd.Stdout = os.Stderr
	cmd.Stderr = os.Stderr
	if cmd.Run() != nil {
		data, _ := os.ReadFile(path)
		os.Stderr.Write(data)
	}
}

// jqCapture runs a jq program against one file and returns stdout with
// trailing newlines stripped (bash $(...) semantics).
func jqCapture(program, file string) string {
	out, err := exec.Command("jq", program, file).Output()
	if err != nil {
		return ""
	}
	return strings.TrimRight(string(out), "\n")
}

// --- Pre-flight checks ---

func preflight() {
	failed := false

	for _, tool := range []string{"curl", "age", "jq"} {
		if _, err := exec.LookPath(tool); err != nil {
			fmt.Fprintf(os.Stderr, "ERROR: required tool '%s' not found in PATH.\n", tool)
			failed = true
		}
	}

	if fi, err := os.Stat(keyFile); err != nil || !fi.Mode().IsRegular() {
		fmt.Fprintf(os.Stderr, "ERROR: age identity not found at %s.\n", keyFile)
		fmt.Fprintf(os.Stderr, "       Generate one with: age-keygen -o %s (mode 0600).\n", keyFile)
		failed = true
	}

	if failed {
		os.Exit(1)
	}
}

// --- Fetch the ciphertext ---

func fetchSeed(tmp string) {
	fmt.Printf("[1/5] Fetching seed from %s ...\n", seedURL)

	cmd := exec.Command("curl", "--silent", "--show-error", "--fail-with-body",
		"--max-time", "60",
		"--output", tmp,
		seedURL)
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: fetch failed for %s.\n", seedURL)
		os.Exit(2)
	}

	// Reject anything that does not look like age ciphertext. age output
	// is always armored with these headers; an openssl/PEM/base64 blob
	// without them is treated as plaintext and refused.
	data, err := os.ReadFile(tmp)
	if err != nil {
		data = nil
	}
	if !isAgeCiphertext(firstLine(data)) {
		fmt.Fprintln(os.Stderr, "ERROR: fetched payload is NOT age ciphertext.")
		fmt.Fprintln(os.Stderr, "       This script refuses to handle plaintext auth material.")
		fmt.Fprintf(os.Stderr, "       First line: %s\n", firstLine(data))
		os.Exit(2)
	}

	size := int64(0)
	if fi, err := os.Stat(tmp); err == nil {
		size = fi.Size()
	}
	fmt.Printf("      OK (%d bytes, age ciphertext).\n", size)
}

// --- Decrypt ---

func decryptSeed(ciphertext, plaintext string) {
	fmt.Printf("[2/5] Decrypting with %s ...\n", keyFile)

	errFile, err := os.Create(plaintext + ".err")
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	cmd := exec.Command("age", "--decrypt", "--identity", keyFile,
		"--output", plaintext,
		ciphertext)
	cmd.Stderr = errFile
	ageErr := cmd.Run()
	errFile.Close()
	if ageErr != nil {
		fmt.Fprintln(os.Stderr, "ERROR: age decryption failed.")
		if e, rerr := os.ReadFile(plaintext + ".err"); rerr == nil {
			fmt.Fprintf(os.Stderr, "       %s\n", strings.TrimRight(string(e), "\n"))
		}
		os.Remove(plaintext + ".err")
		os.Exit(3)
	}
	os.Remove(plaintext + ".err")

	// Validate JSON
	if !jqCheck(plaintext) {
		fmt.Fprintln(os.Stderr, "ERROR: decrypted payload is not valid JSON.")
		jqDumpToStderr(plaintext)
		os.Exit(4)
	}

	fmt.Printf("      OK (%s top-level keys).\n", jqCapture("keys | length", plaintext))
}

// --- Backup existing auth.json ---

func backupExisting(auth string) {
	if _, err := os.Lstat(auth); err != nil {
		fmt.Printf("[3/5] No existing %s — nothing to back up.\n", auth)
		return
	}

	// Verify the existing file is valid JSON before we touch it.
	if !jqCheck(auth) {
		fmt.Fprintf(os.Stderr, "ERROR: existing %s is not valid JSON.\n", auth)
		fmt.Fprintln(os.Stderr, "       Refusing to merge until it is repaired manually.")
		os.Exit(6)
	}

	timestamp := time.Now().Format("20060102-150405")
	bak := auth + ".bak." + timestamp

	fmt.Printf("[3/5] Backing up existing %s to %s ...\n", auth, filepath.Base(bak))
	cmd := exec.Command("cp", "-p", auth, bak)
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		fmt.Fprintln(os.Stderr, "ERROR: backup failed.")
		os.Exit(5)
	}
	os.Chmod(bak, 0o600)
	fmt.Println("      OK.")
}

// --- Merge seed into auth.json ---

func mergeSeed(auth, seed string) {
	if dryRun {
		fmt.Printf("[4/5] DRY RUN: would merge seed into %s.\n", auth)
		fmt.Println("[5/5] DRY RUN: completed. No changes written.")
		return
	}

	fmt.Printf("[4/5] Merging seed into %s ...\n", auth)

	if err := os.MkdirAll(filepath.Dir(auth), 0o755); err != nil {
		fmt.Fprintln(os.Stderr, err) // bash: mkdir -p failure under set -e
		os.Exit(1)
	}

	if _, err := os.Lstat(auth); err != nil {
		// No existing auth — write the seed verbatim with locked-down perms.
		cmd := exec.Command("cp", seed, auth)
		cmd.Stderr = os.Stderr
		if err := cmd.Run(); err != nil {
			os.Exit(exitCode(err)) // bash: bare cp under set -e
		}
	} else {
		// Merge: existing keys win on conflict EXCEPT keys whose value is
		// null/empty, in which case the seed value is promoted. This keeps
		// other providers' tokens intact while letting the seed fill the
		// openai-proxy entry.
		tmp := auth + ".tmp"
		f, err := os.Create(tmp)
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		cmd := exec.Command("jq", "-s", jqMergeProgram, auth, seed)
		cmd.Stdout = f
		cmd.Stderr = os.Stderr
		jqErr := cmd.Run()
		f.Close()
		if jqErr != nil {
			os.Exit(exitCode(jqErr)) // bash: bare jq under set -e
		}

		if !jqCheck(tmp) {
			fmt.Fprintln(os.Stderr, "ERROR: merge produced invalid JSON; aborting.")
			os.Remove(tmp)
			os.Exit(6)
		}

		if err := os.Rename(tmp, auth); err != nil {
			fmt.Fprintln(os.Stderr, err) // bash: mv failure under set -e
			os.Exit(1)
		}
	}

	os.Chmod(auth, 0o600)
	fmt.Println("      OK.")

	fmt.Printf("[5/5] Done. auth.json now has %s top-level keys.\n", jqCapture("keys | length", auth))
	fmt.Printf("      Backups (if any): %s/%s.bak.*\n", filepath.Dir(auth), strings.TrimSuffix(filepath.Base(auth), ".json"))
}

func main() {
	args := os.Args[1:]
	for len(args) > 0 {
		switch args[0] {
		case "--seed-url", "--auth-file", "--key-file":
			if len(args) < 2 {
				// bash dies via set -u (unbound variable, exit 1); see
				// the package doc for the message deviation.
				fmt.Fprintf(os.Stderr, "ERROR: %s requires a value\n", args[0])
				os.Exit(1)
			}
			switch args[0] {
			case "--seed-url":
				seedURL = args[1]
			case "--auth-file":
				authFile = args[1]
			case "--key-file":
				keyFile = args[1]
			}
			args = args[2:]
		case "--dry-run":
			dryRun = true
			args = args[1:]
		case "-h", "--help":
			usage(os.Stdout)
			os.Exit(0)
		default:
			fmt.Fprintf(os.Stderr, "ERROR: Unknown argument: %s\n", args[0])
			usage(os.Stderr)
			os.Exit(1)
		}
	}

	// --- Main ---
	fmt.Println("install-opencode-auth-seed")
	fmt.Printf("  seed-url : %s\n", seedURL)
	fmt.Printf("  auth-file: %s\n", authFile)
	fmt.Printf("  key-file : %s\n", keyFile)
	if dryRun {
		fmt.Println("  mode     : DRY RUN")
	}
	fmt.Println()

	preflight()

	work, err := os.MkdirTemp("", "tmp.")
	if err != nil {
		fmt.Fprintln(os.Stderr, err) // bash: mktemp -d failure under set -e
		os.Exit(1)
	}
	defer os.RemoveAll(work)

	fetchSeed(filepath.Join(work, "seed.age"))
	decryptSeed(filepath.Join(work, "seed.age"), filepath.Join(work, "seed.json"))
	backupExisting(authFile)
	mergeSeed(authFile, filepath.Join(work, "seed.json"))
}
