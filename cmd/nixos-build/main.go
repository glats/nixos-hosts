// Command nixos-build is the deployment helper for the NixOS/Darwin
// configuration: it builds and switches the current host's toplevel.
//
// Port of bin/nixos-build: the 8 subcommands (switch, boot, test, upgrade,
// dry, check, build, safe), platform detection (Linux vs Darwin), the
// worktree-aware flake path (via internal/reporoot), nh/nom tool detection
// with the exact command assembly, --raw / --no-nom, usage text, exit
// codes and all messages are preserved byte-for-byte. The dispatch,
// platform, flag and tool-detection logic lives in internal/nixbuild;
// this entry stays thin (flag parsing + resolution + dispatch).
//
// The bash original runs under `set -euo pipefail`: unguarded command
// failures exit silently with the child's status, and `safe` stages print
// "> ERROR: <stage> failed. Stopping." before exiting 1. Those semantics
// are reproduced exactly (see internal/nixbuild).
package main

import (
	"fmt"
	"os"

	"github.com/glats/nixos-scripts/internal/nixbuild"
	"github.com/glats/nixos-scripts/internal/reporoot"
)

// Byte-identical to the bash help block (lines 104-121 of bin/nixos-build).
const usageText = `Usage: nixos-build [command] [--raw] [--no-nom]

Commands:
  switch     Build and activate (default)
  boot       Build and activate on next boot (NixOS only)
  test       Build and activate in test environment (NixOS only)
  upgrade    Update npm packages + flake inputs + rebuild
  dry        Dry-activate (show changes only)
  check      Validate flake
  build      Dry-build only
  safe       Sequential: check -> build -> dry -> switch

Options:
  --raw      Use nixos-rebuild instead of nh (Linux only)
  --no-nom   Disable nix-output-monitor
`

func main() {
	command, raw, noNom := nixbuild.ParseArgs(os.Args[1:])

	// bash: repo root resolved before dispatch (NIXOS_REPO → git toplevel →
	// ~/.nixos); the flake path is worktree-aware via reporoot.FlakePath.
	root, err := reporoot.Resolve()
	if err != nil {
		fmt.Fprintln(os.Stderr, "ERROR:", err)
		os.Exit(1)
	}

	if nixbuild.IsHelp(command) {
		fmt.Print(usageText)
		os.Exit(0)
	}

	darwin := nixbuild.IsDarwin()
	nhPath, nomPath := nixbuild.DetectTools(darwin)
	hostname, _ := os.Hostname() // bash `hostname` always yields a name

	env := nixbuild.Env{
		Darwin:    darwin,
		Raw:       raw,
		NoNom:     noNom,
		HasNH:     nhPath != "",
		HasNom:    nomPath != "",
		NomPath:   nomPath,
		Hostname:  hostname,
		FlakePath: reporoot.FlakePath(root),
	}

	if !nixbuild.IsKnown(command) {
		// bash echoes both lines to stdout.
		fmt.Println("Unknown command: " + command)
		fmt.Println("Run 'nixos-build help' for usage")
		os.Exit(1)
	}

	os.Exit(nixbuild.Run(nixbuild.Steps(env, command), env.NomPath))
}
