// Command format-nix formats all .nix files under /etc/nixos using the
// repo's flake formatter (nix fmt).
//
// Port of bin/format-nix: help text, messages, flag surface and exit codes
// preserved byte-for-byte.
package main

import (
	"bytes"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

const target = "/etc/nixos"

const helpText = `Usage: format-nix [--check]

Formats all .nix files under /etc/nixos using this repo's flake formatter.
Run with sufficient privileges to modify files in /etc/nixos.

Formatter workflow in this repo:
  Full repo:    format-nix
  Single file:  nix fmt -- <path>

Avoid this anti-pattern:
  nixpkgs-fmt <path>
The flake formatter should be invoked through ` + "`nix fmt`" + `.

Options:
  --check    Report files that would change instead of modifying them
  -h, --help Show this help message`

func main() {
	checkMode := false
	for _, arg := range os.Args[1:] {
		switch arg {
		case "--check":
			checkMode = true
		case "-h", "--help":
			fmt.Println(helpText)
			return
		default:
			fmt.Fprintf(os.Stderr, "Unknown argument: %s\n", arg)
			fmt.Fprintln(os.Stderr, "TIP: format-nix only supports full-repo formatting. Use 'nix fmt -- <path>' for a single file.")
			os.Exit(2)
		}
	}

	if fi, err := os.Stat(target); err != nil || !fi.IsDir() {
		fmt.Fprintf(os.Stderr, "Target directory %s does not exist.\n", target)
		os.Exit(1)
	}
	if err := os.Chdir(target); err != nil {
		fmt.Fprintf(os.Stderr, "Target directory %s does not exist.\n", target)
		os.Exit(1)
	}

	files, err := nixFiles(".")
	if err != nil {
		fmt.Fprintln(os.Stderr, "ERROR:", err)
		os.Exit(1)
	}
	if len(files) == 0 {
		fmt.Printf("No .nix files found in %s\n", target)
		return
	}

	fmt.Printf("Found %d .nix files. Using formatter: nix fmt --\n", len(files))

	rc := 0
	for _, f := range files {
		if fh, err := os.Open(f); err != nil {
			fmt.Printf("Skipping unreadable file: %s\n", f)
		} else {
			fh.Close()
		}

		if checkMode {
			checkFile(f, &rc)
		} else {
			fmt.Printf("Formatting %s\n", f)
			// bash merges stderr into stdout: 2>&1
			cmd := exec.Command("nix", "fmt", "--", f)
			cmd.Stdout = os.Stdout
			cmd.Stderr = os.Stdout
			if err := cmd.Run(); err != nil {
				fmt.Printf("Formatter failed on %s\n", f)
				rc = 1
			}
		}
	}

	if rc == 0 {
		fmt.Println("Formatting complete.")
	} else {
		fmt.Println("Formatting finished with errors (see above).")
	}
	os.Exit(rc)
}

// checkFile formats a temp copy of f and sets *rc = 1 if the file would
// change or the formatter fails (parity with the bash original).
func checkFile(f string, rc *int) {
	src, err := os.ReadFile(f)
	if err != nil {
		fmt.Printf("Skipping unreadable file: %s\n", f)
		return
	}
	tmp, err := os.CreateTemp("", "format-nix-")
	if err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: %v\n", err)
		os.Exit(1)
	}
	tmpName := tmp.Name()
	tmp.Write(src)
	tmp.Close()
	defer os.Remove(tmpName)

	// Parity with bash: quiet formatter run, compare original vs formatted.
	cmd := exec.Command("nix", "fmt", "--", tmpName)
	cmd.Stdout = io.Discard
	cmd.Stderr = io.Discard
	if err := cmd.Run(); err != nil {
		fmt.Printf("Formatter (check) failed on %s\n", f)
		*rc = 1
		return
	}
	got, err := os.ReadFile(tmpName)
	if err != nil {
		fmt.Printf("Formatter (check) failed on %s\n", f)
		*rc = 1
		return
	}
	if !bytes.Equal(src, got) {
		fmt.Printf("Would reformat %s\n", f)
		*rc = 1
	}
}

// nixFiles walks root and returns .nix file paths, skipping .git, in
// deterministic (lexical) order.
func nixFiles(root string) ([]string, error) {
	var files []string
	err := filepath.WalkDir(root, func(path string, d os.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() {
			if d.Name() == ".git" && path != "." {
				return filepath.SkipDir
			}
			return nil
		}
		if strings.HasSuffix(d.Name(), ".nix") {
			files = append(files, path)
		}
		return nil
	})
	return files, err
}
