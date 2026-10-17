package main

import (
	"fmt"
	"os"

	"github.com/glats/nixos-scripts/internal/nixbuild"
	"github.com/glats/nixos-scripts/internal/nixcache"
	"github.com/glats/nixos-scripts/internal/reporoot"
)

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

Environment:
  NIX_CACHE_PUSH=0   Skip the best-effort push of /run/current-system to
                     thinkcentre that runs after a successful darwin
                     switch (macm5 only)
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

	code := nixbuild.Run(nixbuild.Steps(env, command), env.NomPath)
	maybePush(env, command, code, os.Getenv, nixcache.ExecRunner{}, warnHook)
	os.Exit(code)
}

func warnHook(msg string) {
	fmt.Fprintln(os.Stderr, "WARNING: "+msg)
}

func applyingCommand(command string) bool {
	switch command {
	case "switch", "boot", "test", "upgrade", "safe":
		return true
	}
	return false
}

func maybePush(env nixbuild.Env, command string, code int, getenv func(string) string, runner nixcache.Runner, warn func(string)) {
	if code != 0 || !env.Darwin || !applyingCommand(command) {
		return
	}
	if getenv(nixcache.PushOptOutEnv) == "0" {
		return
	}
	if err := nixcache.Push(nixcache.DefaultPushTo, nil, false, runner, warn); err != nil {
		warn(err.Error())
	}
}
