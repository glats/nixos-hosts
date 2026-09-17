// Command format-nix formats all .nix files under a selected flake using its
// formatter (nix fmt).
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

const helpText = `Usage: format-nix [directory] [--check]

Formats all .nix files under a Nix flake using that project's formatter.
Without a directory, discovers the nearest flake.nix from the current directory.

Formatter workflow in this repo:
  Full repo:    format-nix
  Single file:  nix fmt -- <path>

Avoid this anti-pattern:
  nixfmt-tree <path>
The flake formatter should be invoked through ` + "`nix fmt`" + `.

Options:
  --check    Report files that would change instead of modifying them
  -h, --help Show this help message`

func main() {
	args, err := parseArgs(os.Args[1:])
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(2)
	}
	if args.help {
		fmt.Println(helpText)
		return
	}

	cwd, err := os.Getwd()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Unable to determine current directory: %v\n", err)
		os.Exit(1)
	}
	target, err := resolveTarget(args.directory, cwd)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	if err := os.Chdir(target); err != nil {
		fmt.Fprintf(os.Stderr, "Unable to enter target directory %s: %v\n", target, err)
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

		if args.check {
			checkFile(f, &rc)
		} else {
			formatFile(f, &rc)
		}
	}

	if rc == 0 {
		fmt.Println("Formatting complete.")
	} else {
		fmt.Println("Formatting finished with errors (see above).")
	}
	os.Exit(rc)
}

type commandArgs struct {
	directory string
	check     bool
	help      bool
}

func parseArgs(argv []string) (commandArgs, error) {
	var args commandArgs
	for _, arg := range argv {
		switch arg {
		case "--check":
			args.check = true
		case "-h", "--help":
			args.help = true
		default:
			if arg == "" {
				return commandArgs{}, fmt.Errorf("Directory argument must not be empty")
			}
			if strings.HasPrefix(arg, "-") {
				return commandArgs{}, fmt.Errorf("Unknown argument: %s\nTIP: format-nix accepts an optional directory and --check. Use 'nix fmt -- <path>' for a single file.", arg)
			}
			if args.directory != "" {
				return commandArgs{}, fmt.Errorf("Unexpected extra directory: %s", arg)
			}
			args.directory = arg
		}
	}
	return args, nil
}

var runFormatter = func(file string, stdout, stderr io.Writer) error {
	cmd := exec.Command("nix", "fmt", "--", file)
	cmd.Stdout = stdout
	cmd.Stderr = stderr
	return cmd.Run()
}

func formatFile(file string, rc *int) {
	fmt.Printf("Formatting %s\n", file)
	// bash merges stderr into stdout: 2>&1
	if err := runFormatter(file, os.Stdout, os.Stdout); err != nil {
		fmt.Printf("Formatter failed on %s\n", file)
		*rc = 1
	}
}

func resolveTarget(explicit, cwd string) (string, error) {
	if explicit != "" {
		path, err := filepath.Abs(explicit)
		if err != nil {
			return "", fmt.Errorf("Invalid target directory %s: %v", explicit, err)
		}
		if err := validateFlakeDirectory(path); err != nil {
			return "", fmt.Errorf("Invalid target directory %s: %v", explicit, err)
		}
		return path, nil
	}

	path, err := filepath.Abs(cwd)
	if err != nil {
		return "", fmt.Errorf("Unable to resolve current directory %s: %v", cwd, err)
	}
	for {
		if err := validateFlakeDirectory(path); err == nil {
			return path, nil
		}
		parent := filepath.Dir(path)
		if parent == path {
			break
		}
		path = parent
	}
	return "", fmt.Errorf("No flake.nix found in %s or any parent directory", cwd)
}

func validateFlakeDirectory(path string) error {
	info, err := os.Stat(path)
	if err != nil {
		return err
	}
	if !info.IsDir() {
		return fmt.Errorf("target is not a directory")
	}
	flake, err := os.Stat(filepath.Join(path, "flake.nix"))
	if err != nil {
		return fmt.Errorf("flake.nix is missing")
	}
	if flake.IsDir() {
		return fmt.Errorf("flake.nix is not a file")
	}
	return nil
}

// createCheckCopy creates a repository-local temp copy for treefmt's root
// discovery and returns its path.
func createCheckCopy(f string) (string, error) {
	src, err := os.ReadFile(f)
	if err != nil {
		return "", err
	}
	tmp, err := os.CreateTemp(".", ".format-nix-*.nix")
	if err != nil {
		return "", err
	}
	tmpName := tmp.Name()
	if _, err := tmp.Write(src); err != nil {
		tmp.Close()
		os.Remove(tmpName)
		return "", err
	}
	if err := tmp.Close(); err != nil {
		os.Remove(tmpName)
		return "", err
	}
	return tmpName, nil
}

// checkFile formats a temp copy of f and sets *rc = 1 if the file would
// change or the formatter fails (parity with the bash original).
func checkFile(f string, rc *int) {
	src, err := os.ReadFile(f)
	if err != nil {
		fmt.Printf("Skipping unreadable file: %s\n", f)
		return
	}
	tmpName, err := createCheckCopy(f)
	if err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: %v\n", err)
		os.Exit(1)
	}
	defer os.Remove(tmpName)

	// Parity with bash: quiet formatter run, compare original vs formatted.
	if err := runFormatter(tmpName, io.Discard, io.Discard); err != nil {
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

// nixFiles walks root and returns .nix file paths, skipping .git and
// .worktrees (full repo copies that would triple the work), in
// deterministic (lexical) order.
func nixFiles(root string) ([]string, error) {
	var files []string
	err := filepath.WalkDir(root, func(path string, d os.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() {
			switch d.Name() {
			case ".git", ".worktrees":
				if path != "." {
					return filepath.SkipDir
				}
			}
			return nil
		}
		if strings.HasPrefix(d.Name(), ".format-nix-") {
			return nil
		}
		if strings.HasSuffix(d.Name(), ".nix") {
			files = append(files, path)
		}
		return nil
	})
	return files, err
}
