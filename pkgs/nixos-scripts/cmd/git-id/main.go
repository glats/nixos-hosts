// Command git-id sets the local git identity include for a repository.
//
// Port of bin/git-id: usage text, messages and exit codes preserved.
// The identity files are written by home-manager activation from sops secrets.
package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

func usage() {
	fmt.Fprintln(os.Stderr, "Usage: git-id <personal|work> [<directory>]")
	fmt.Fprintln(os.Stderr, "Sets git identity for the repository at the given directory (default: current dir).")
	os.Exit(1)
}

func main() {
	dir, err := os.Getwd()
	if err != nil {
		fmt.Fprintln(os.Stderr, "ERROR:", err)
		os.Exit(1)
	}

	mode := ""
	args := os.Args[1:]
	if len(args) >= 1 {
		mode = args[0]
	}
	if len(args) >= 2 {
		dir = args[1]
	}
	if mode != "personal" && mode != "work" {
		usage()
	}

	home, err := os.UserHomeDir()
	if err != nil {
		fmt.Fprintln(os.Stderr, "ERROR:", err)
		os.Exit(1)
	}
	identityFile := filepath.Join(home, ".config", "git", "identity-"+mode)

	if _, err := os.Stat(identityFile); err != nil {
		fmt.Fprintf(os.Stderr, "Error: identity file not found at %s\n", identityFile)
		fmt.Fprintln(os.Stderr, "Make sure home-manager has run successfully (nixos-build switch).")
		os.Exit(1)
	}

	if fi, err := os.Stat(dir); err != nil || !fi.IsDir() {
		fmt.Fprintf(os.Stderr, "Error: directory '%s' does not exist\n", dir)
		os.Exit(1)
	}

	git := func(args ...string) (string, int) {
		cmd := exec.Command("git", args...)
		cmd.Dir = dir
		var out, errOut strings.Builder
		cmd.Stdout = &out
		cmd.Stderr = &errOut
		err := cmd.Run()
		code := 0
		if exitErr, ok := err.(*exec.ExitError); ok {
			code = exitErr.ExitCode()
		} else if err != nil {
			fmt.Fprintln(os.Stderr, "ERROR:", err)
			os.Exit(1)
		}
		_ = errOut
		return out.String(), code
	}

	if _, code := git("rev-parse", "--git-dir"); code != 0 {
		fmt.Fprintf(os.Stderr, "Error: '%s' is not a git repository\n", dir)
		os.Exit(1)
	}

	current, _ := git("config", "--local", "--get", "include.path")
	if strings.TrimSpace(current) == identityFile {
		fmt.Printf("Already set: %s (%s)\n", mode, identityFile)
		return
	}

	git("config", "--local", "--unset-all", "include.path")

	if _, code := git("config", "--local", "include.path", identityFile); code != 0 {
		fmt.Fprintln(os.Stderr, "Error: git config include.path failed")
		os.Exit(1)
	}

	fmt.Printf("Set identity: %s (%s)\n", mode, identityFile)
	name, _ := git("config", "user.name")
	email, _ := git("config", "user.email")
	fmt.Printf("  name: %s\n", strings.TrimSpace(name))
	fmt.Printf("  email: %s\n", strings.TrimSpace(email))
}
