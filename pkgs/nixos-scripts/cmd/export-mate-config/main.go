// Command export-mate-config exports MATE dconf settings (/org/mate/) to a
// Nix module and validates the configuration with nix flake check.
//
// Port of bin/export-mate-config: messages, conversion rules and exit codes
// preserved, including the exact spacing quirks of the dconf→Nix array
// conversion (verified against the bash pipeline). The header/autostart
// scaffolding is byte-identical.
//
// Deviations from the bash original:
//   - REPO_ROOT resolution uses the repo-wide reporoot chain (env → git
//     toplevel → ~/.nixos) instead of the script's parent directory; a
//     compiled binary has no script directory and the store-installed bash
//     original had the same limitation.
//   - The mktemp + cp staging is collapsed into a single write (the temp
//     file was invisible state; the final file content is identical).
//   - Post-migration modernizations (bash-to-go-migration follow-up):
//     output repointed from the dead <repo>/modules/home/mate.nix to
//     linux/home/suites/mate/mate-dconf-export.nix — an UNIMPORTED review
//     artifact, because the live mate-dconf.nix is a curated module
//     (colors.nix integration) that a raw dconf dump must not overwrite.
//     Formatting goes through the flake formatter (`nix fmt --`) instead
//     of calling nixfmt/nixpkgs-fmt directly, and validation runs
//     `nix flake check --no-build`.
package main

import (
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/glats/nixos-scripts/internal/reporoot"
)

// header is the leading module scaffold written before the dconf dump.
const header = `{ config, lib, pkgs, ... }:

{
  dconf.settings = {
`

// autostart is the fixed xdg.configFile block appended after the dconf
// settings (bash: quoted heredoc, fully literal).
const autostart = `  };

  xdg.configFile = {
    "autostart/gpaste.desktop".text = ''
      [Desktop Entry]
      Name=GPaste
      Comment=Clipboard Manager
      Icon=edit-paste
      Exec=${pkgs.gpaste}/bin/gpaste-client start
      Terminal=false
      Type=Application
      Categories=GTK;GNOME;Application;Utility;
      OnlyShowIn=MATE;
      X-MATE-Autostart-enabled=true
    '';

    "autostart/conky.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=conky
      Exec=${pkgs.conky}/bin/conky --daemonize --pause=1
      StartupNotify=false
      Terminal=false
      Icon=conky-logomark-violet
      Categories=System;Monitor;
      OnlyShowIn=MATE;
      X-MATE-Autostart-enabled=true
    '';

    "autostart/io.github.Hexchat.desktop".text = ''
      [Desktop Entry]
      Name=HexChat
      GenericName=IRC Client
      Comment=Chat with other people online
      Keywords=IM;Chat;
      Exec=${pkgs.hexchat}/bin/hexchat --existing %U
      Icon=io.github.Hexchat
      Terminal=false
      Type=Application
      Categories=GTK;Network;IRCClient;
      StartupNotify=true
      StartupWMClass=Hexchat
      MimeType=x-scheme-handler:irc;x-scheme-handler:ircs;
      OnlyShowIn=MATE;
      X-MATE-Autostart-enabled=true
    '';

    "autostart/ulauncher.desktop".text = ''
      [Desktop Entry]
      Name=Ulauncher
      Comment=Application launcher for Linux
      GenericName=Launcher
      Categories=GNOME;GTK;Utility;
      Exec=env GDK_BACKEND=x11 ${pkgs.ulauncher}/bin/ulauncher --hide-window
      Icon=ulauncher
      Terminal=false
      Type=Application
      OnlyShowIn=MATE;
      X-MATE-Autostart-enabled=true
    '';

    "autostart/org.flameshot.Flameshot.desktop".text = ''
      [Desktop Entry]
      Name=Flameshot
      GenericName=Screenshot tool
      Comment=Powerful yet simple to use screenshot software.
      Keywords=flameshot;screenshot;capture;shutter;
      Exec=${pkgs.flameshot}/bin/flameshot
      Icon=org.flameshot.Flameshot
      Terminal=false
      Type=Application
      Categories=Graphics;
      StartupNotify=false
      StartupWMClass=flameshot
      OnlyShowIn=MATE;
      X-MATE-Autostart-enabled=true
    '';
  };
}
`

var (
	sectionRe    = regexp.MustCompile(`^\[(.*)\]$`)
	arrayRe      = regexp.MustCompile(`^\[(.*)\]$`)
	intRe        = regexp.MustCompile(`^[0-9]+$`)
	multiSpaceRe = regexp.MustCompile(`  +`)
)

// exitFromErr maps a subprocess failure to the shell's exit-code semantics:
// propagate the child's exit code, or 127 when the command could not run at
// all (bash prints a shell-level "command not found" line; the closest
// portable equivalent is the exec error itself).
func exitFromErr(err error) {
	if exitErr, ok := err.(*exec.ExitError); ok {
		os.Exit(exitErr.ExitCode())
	}
	fmt.Fprintln(os.Stderr, "Error:", err)
	os.Exit(127)
}

// runInherit executes a command with fully inherited stdio; a failed
// subprocess terminates the script like a bare command under set -e.
func runInherit(name string, args ...string) {
	cmd := exec.Command(name, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	if err := cmd.Run(); err != nil {
		exitFromErr(err)
	}
}

// xargsTrim replicates `echo "$key" | xargs`: trims surrounding whitespace
// and collapses internal whitespace runs to single spaces.
func xargsTrim(s string) string {
	return strings.Join(strings.Fields(s), " ")
}

// arrayBody replicates the bash pipeline
//
//	sed "s/'/\"/g" | tr ',' '\n' | sed 's/^ *//' | sed 's/ *$//' |
//	tr '\n' ' ' | sed 's/  */ /g'
//
// including the trailing space the tr step leaves behind (echo's final
// newline becomes a space), which is why a rendered array ends with two
// spaces before the closing bracket.
func arrayBody(content string) string {
	s := strings.ReplaceAll(content, "'", "\"")
	parts := strings.Split(s, ",")
	for i, p := range parts {
		parts[i] = strings.TrimLeft(strings.TrimRight(p, " "), " ")
	}
	return multiSpaceRe.ReplaceAllString(strings.Join(parts, " ")+" ", " ")
}

// convertValue converts a dconf value to Nix syntax: arrays become
// [ "a" "b" ], booleans and integers pass through, everything else is
// treated as a single-quoted string and re-wrapped in double quotes after
// stripping one leading/trailing single quote.
func convertValue(value string) string {
	if m := arrayRe.FindStringSubmatch(value); m != nil {
		return "[ " + arrayBody(m[1]) + " ]"
	}
	if value == "true" || value == "false" {
		return value
	}
	if intRe.MatchString(value) {
		return value
	}
	inner := strings.TrimSuffix(strings.TrimPrefix(value, "'"), "'")
	return "\"" + inner + "\""
}

// convertDump converts full `dconf dump /org/mate/` output to the Nix
// settings block, byte-for-byte like the bash line loop.
func convertDump(out string) string {
	var b strings.Builder
	b.WriteString(header)
	currentPath := ""
	for _, line := range strings.Split(out, "\n") {
		// Skip empty lines between sections.
		if line == "" {
			continue
		}
		// Section header [path].
		if m := sectionRe.FindStringSubmatch(line); m != nil {
			// Close previous block if not first.
			if currentPath != "" {
				b.WriteString("    };\n\n")
			}
			currentPath = m[1]
			fmt.Fprintf(&b, "    \"org/mate/%s\" = {\n", currentPath)
			continue
		}
		// key=value pair (first '=' splits; empty keys do not match the
		// bash ^([^=]+)= anchor and are skipped).
		if parts := strings.SplitN(line, "=", 2); len(parts) == 2 && parts[0] != "" {
			b.WriteString("      " + xargsTrim(parts[0]) + " = " + convertValue(parts[1]) + ";\n")
		}
	}
	// Close last dconf block (unconditional, like the bash original).
	b.WriteString("    };\n")
	return b.String()
}

// printLastLines ports `| tail -10` for the flake-check output.
func printLastLines(out string, n int) {
	lines := strings.Split(out, "\n")
	if len(lines) > 0 && lines[len(lines)-1] == "" {
		lines = lines[:len(lines)-1]
	}
	if len(lines) > n {
		lines = lines[len(lines)-n:]
	}
	for _, l := range lines {
		fmt.Println(l)
	}
}

func main() {
	repoRoot, err := reporoot.Resolve()
	if err != nil {
		fmt.Fprintln(os.Stderr, "Error:", err)
		os.Exit(1)
	}
	// Unimported review artifact: the live mate-dconf.nix is curated
	// (colors.nix integration) — merge changes into it by hand.
	outputFile := filepath.Join(repoRoot, "linux", "home", "suites", "mate", "mate-dconf-export.nix")

	if _, err := exec.LookPath("dconf"); err != nil {
		fmt.Fprintln(os.Stderr, "Error: dconf command not found")
		os.Exit(1)
	}

	fmt.Println("> Exporting MATE dconf configuration...")

	dump := exec.Command("dconf", "dump", "/org/mate/")
	dump.Stderr = os.Stderr
	out, err := dump.Output()
	if err != nil {
		exitFromErr(err)
	}

	// Render the module: header + converted dump + autostart scaffolding.
	content := convertDump(string(out)) + autostart

	if err := os.WriteFile(outputFile, []byte(content), 0o600); err != nil {
		fmt.Fprintf(os.Stderr, "Error: cannot write %s: %v\n", outputFile, err)
		os.Exit(1)
	}

	fmt.Println("> Formatting with the flake formatter (nix fmt)...")
	runInherit("nix", "fmt", "--", outputFile)

	fmt.Println("> Validating configuration...")
	if err := os.Chdir(repoRoot); err != nil {
		fmt.Fprintln(os.Stderr, "Error:", err)
		os.Exit(1)
	}

	var combined bytes.Buffer
	flake := exec.Command("nix", "flake", "check", "--no-build")
	flake.Stdout = &combined
	flake.Stderr = &combined
	if err := flake.Run(); err != nil {
		printLastLines(combined.String(), 10)
		fmt.Println("Warning: Validation failed, please check the output above")
		os.Exit(1)
	}
	printLastLines(combined.String(), 10)
	fmt.Printf("> Success! Configuration exported to %s\n", outputFile)
	fmt.Println("> Review the dump and merge what you want into mate-dconf.nix by hand")
	fmt.Println(">   (this export file is NOT imported by the suite; discard with git checkout)")
	fmt.Println("> Apply with: nixos-build")
}
