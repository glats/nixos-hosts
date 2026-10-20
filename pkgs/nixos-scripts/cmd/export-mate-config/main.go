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

const header = `{ config, lib, pkgs, ... }:

{
  dconf.settings = {
`

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
	bracketRe    = regexp.MustCompile(`^\[(.*)\]$`)
	intRe        = regexp.MustCompile(`^[0-9]+$`)
	multiSpaceRe = regexp.MustCompile(`  +`)
)

func exitFromErr(err error) {
	if exitErr, ok := err.(*exec.ExitError); ok {
		os.Exit(exitErr.ExitCode())
	}
	fmt.Fprintln(os.Stderr, "Error:", err)
	os.Exit(127)
}

func runInherit(name string, args ...string) {
	cmd := exec.Command(name, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	if err := cmd.Run(); err != nil {
		exitFromErr(err)
	}
}

func xargsTrim(s string) string {
	return strings.Join(strings.Fields(s), " ")
}

func arrayBody(content string) string {
	s := strings.ReplaceAll(content, "'", "\"")
	parts := strings.Split(s, ",")
	for i, p := range parts {
		parts[i] = strings.TrimLeft(strings.TrimRight(p, " "), " ")
	}
	return multiSpaceRe.ReplaceAllString(strings.Join(parts, " ")+" ", " ")
}

func convertValue(value string) string {
	if m := bracketRe.FindStringSubmatch(value); m != nil {
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

func convertDump(out string) string {
	var b strings.Builder
	b.WriteString(header)
	currentPath := ""
	for _, line := range strings.Split(out, "\n") {

		if line == "" {
			continue
		}

		if m := bracketRe.FindStringSubmatch(line); m != nil {

			if currentPath != "" {
				b.WriteString("    };\n\n")
			}
			currentPath = m[1]
			fmt.Fprintf(&b, "    \"org/mate/%s\" = {\n", currentPath)
			continue
		}

		if parts := strings.SplitN(line, "=", 2); len(parts) == 2 && parts[0] != "" {
			b.WriteString("      " + xargsTrim(parts[0]) + " = " + convertValue(parts[1]) + ";\n")
		}
	}

	b.WriteString("    };\n")
	return b.String()
}

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
