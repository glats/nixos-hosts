package main

import (
	"fmt"
	"os"
	"time"

	"github.com/glats/nixos-scripts/internal/nixbuild"
	"github.com/glats/nixos-scripts/internal/nixcache"
	"github.com/glats/nixos-scripts/internal/reporoot"
	"github.com/glats/nixos-scripts/internal/sshrelay"
)

const usageText = `Usage: nixos-build [command] [--raw] [--no-nom]

Commands:
  switch     Build and activate (default)
  boot       Build and activate on next boot (NixOS only)
  test       Build and activate in test environment (NixOS only)
  upgrade    Update all managed software sources (no build or activation)
  dry        Dry-activate (show changes only)
  check      Validate flake
  build      Dry-build only
  safe       Sequential: check -> build -> dry -> switch

Options:
  --raw      Use nixos-rebuild instead of nh (Linux only)
  --no-nom   Disable nix-output-monitor

Environment:
  NIX_CACHE_PUSH=0     Skip the best-effort push of /run/current-system to
                       thinkcentre that runs after a successful darwin
                       switch (macm5 only)
  NIX_CACHE_PUSH_TO=X  Push to X verbatim, skipping LAN detection and relay
                       orchestration (macm5 only). Without an override the
                       push probes thinkcentre.lan:22 and uses the direct
                       destination on LAN, or brings the SSH relay tunnel
                       up, pushes through it, and stops it afterwards.

Flake: NIXOS_REPO, or the current git worktree when it belongs to the
same repository (for example a herdr worktree).

upgrade updates OpenCode (executable and npm closure), BrowserMCP, the quota
plugin (within its major), GitHub release binaries, Gentle AI, Engram, other
source packages and all flake inputs to their latest releases. It never builds
or activates; run check to validate and switch to build and activate. A new
quota major, tinkertool and the nixpkgs overrides in overlays/ are updated by
hand (see docs/software-updates.md).
upgrade uses GITHUB_TOKEN, GH_TOKEN or a logged-in gh to avoid GitHub's
unauthenticated rate limit; the token is passed only to the child processes.
`

func main() {
	command, raw, noNom := nixbuild.ParseArgs(os.Args[1:])

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
	hostname := nixbuild.ResolveHost(darwin, os.Getenv, os.Hostname)

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

		fmt.Println("Unknown command: " + command)
		fmt.Println("Run 'nixos-build help' for usage")
		os.Exit(1)
	}

	if command == "upgrade" {
		nixbuild.ApplyGitHubAuth()
	}

	code := nixbuild.Run(nixbuild.Steps(env, command), env.NomPath)
	maybePush(env, command, code, os.Getenv, nixcache.ExecRunner{}, warnHook,
		nixcache.Reachable, newRelayCtl(nixcache.ExecRunner{}))
	os.Exit(code)
}

func warnHook(msg string) {
	fmt.Fprintln(os.Stderr, "WARNING: "+msg)
}

// relayController manages the macm5 SSH relay tunnel used for off-LAN pushes.
type relayController interface {
	Up() bool
	EnsureUp() bool
	Stop()
}

func newRelayCtl(run nixcache.Runner) relayController {
	t := sshrelay.NewCtl(run)
	if t == nil {
		return nil
	}
	return t
}

func applyingCommand(command string) bool {
	switch command {
	case "switch", "boot", "test", "safe":
		return true
	}
	return false
}

func maybePush(env nixbuild.Env, command string, code int, getenv func(string) string, runner nixcache.Runner, warn func(string), probe func(string, time.Duration) bool, relay relayController) {
	if code != 0 || !env.Darwin || !applyingCommand(command) {
		return
	}
	if getenv(nixcache.PushOptOutEnv) == "0" {
		return
	}
	dest := nixcache.DefaultPushTo
	if override := getenv(nixcache.PushToEnv); override != "" {
		dest = override
	} else if !probe(nixcache.LanProbeAddr, nixcache.LanProbeTimeout) {
		if relay == nil {
			warn("push skipped: thinkcentre unreachable and no relay tunnel available")
			return
		}
		wasUp := relay.Up()
		if !wasUp {
			if !relay.EnsureUp() {
				warn("push skipped: relay tunnel did not come up")
				return
			}
			defer relay.Stop()
		}
		dest = nixcache.RelayPushTo
	}
	if err := nixcache.Push(dest, nil, false, runner, warn); err != nil {
		warn(err.Error())
	}
}
