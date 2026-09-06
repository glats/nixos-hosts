// Package ui ports the shared helpers from bin/lib/common.sh (die,
// require_root, confirm_action) for the nixos-scripts Go binaries.
//
// Output helpers (Info) mirror the plain echo style of the bash scripts;
// scripts that must stay byte-identical to their bash originals print their
// own exact strings and use Die/Errorf only where the bash original used
// common.sh's die().
package ui

import (
	"bufio"
	"fmt"
	"os"
	"strings"
)

// Die prints "ERROR: <msg>" to stderr and exits 1 — port of common.sh die().
func Die(format string, args ...any) {
	Errorf(format, args...)
	os.Exit(1)
}

// Errorf prints "ERROR: <msg>" to stderr without exiting.
func Errorf(format string, args ...any) {
	fmt.Fprintf(os.Stderr, "ERROR: "+format+"\n", args...)
}

// Info prints a line to stdout.
func Info(format string, args ...any) {
	fmt.Printf(format+"\n", args...)
}

// RequireRoot exits via Die when euid != 0 — port of common.sh require_root().
func RequireRoot() {
	if os.Geteuid() != 0 {
		Die("This command must be run as root (sudo)")
	}
}

// Confirm prints "<prompt> [y/N] " and reads one line from stdin; it returns
// true only for y/Y. Unlike common.sh confirm_action it does not exit —
// callers print their own "Aborted." so behavior stays per-script.
func Confirm(prompt string) bool {
	fmt.Printf("%s [y/N] ", prompt)
	sc := bufio.NewScanner(os.Stdin)
	if !sc.Scan() {
		return false
	}
	resp := strings.TrimSpace(sc.Text())
	return resp == "y" || resp == "Y"
}
