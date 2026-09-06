// Command nixos-build-all checks/evaluates/builds every host in the flake.
//
// Port of bin/nixos-build-all: subcommands, messages and exit codes
// preserved. Output goes through nom when available (parity with the
// bash `|& nom` piping).
package main

import (
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/glats/nixos-scripts/internal/nixbuild"
)

const usageText = `Usage: nixos-build-all [command]

Commands:
  check   Validate the whole flake without building (default)
  eval    Evaluate every NixOS, Darwin, and Home Manager host output
  build   Build every system host output with --no-link
  hm      Build every standalone Home Manager activation package with --no-link
  all     Run check, eval, build, and hm
`

// repoRoot mirrors the bash resolution: NIXOS_REPO → git toplevel →
// ~/.config/nix (note: this fallback differs from other scripts).
func repoRoot() (string, error) {
	if v := os.Getenv("NIXOS_REPO"); v != "" {
		return v, nil
	}
	if out, err := exec.Command("git", "rev-parse", "--show-toplevel").Output(); err == nil {
		if top := strings.TrimSpace(string(out)); top != "" {
			return top, nil
		}
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(home, ".config", "nix"), nil
}

func main() {
	command := "check"
	if len(os.Args) > 1 {
		command = os.Args[1]
	}

	root, err := repoRoot()
	if err != nil {
		fmt.Fprintln(os.Stderr, "ERROR:", err)
		os.Exit(1)
	}
	flake := root

	switch command {
	case "check":
		checkAll(flake)
	case "eval":
		evalAll(flake)
	case "build":
		buildSystems(flake)
	case "hm":
		buildHM(flake)
	case "all":
		checkAll(flake)
		evalAll(flake)
		buildSystems(flake)
		buildHM(flake)
	case "help", "-h", "--help":
		fmt.Print(usageText)
	default:
		fmt.Fprint(os.Stderr, usageText)
		os.Exit(1)
	}
}

// runBuild executes args with output through nom when available — the bash
// `|& nom` piping. Failures die silently with the child's (or nom's, per
// pipefail) status, matching the bash original's set -e semantics.
func runBuild(args ...string) {
	if nom, err := exec.LookPath("nom"); err == nil {
		if rc := nixbuild.RunThroughNom(args, nom); rc != 0 {
			os.Exit(rc)
		}
		return
	}
	c := exec.Command(args[0], args[1:]...)
	c.Stdout = os.Stdout
	c.Stderr = os.Stderr
	if err := c.Run(); err != nil {
		var ee *exec.ExitError
		if errors.As(err, &ee) {
			os.Exit(ee.ExitCode())
		}
		fmt.Fprintln(os.Stderr, "ERROR:", err)
		os.Exit(127)
	}
}

// loadHosts evals the attrset names of one flake output.
func loadHosts(flake, output string) []string {
	out, err := exec.Command("nix", "eval", "--raw", flake+"#"+output,
		"--apply", "attrs: builtins.concatStringsSep \"\\n\" (builtins.attrNames attrs)").Output()
	if err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: nix eval %s: %v\n", output, err)
		os.Exit(1)
	}
	var hosts []string
	for _, h := range strings.Split(strings.TrimSpace(string(out)), "\n") {
		if h = strings.TrimSpace(h); h != "" {
			hosts = append(hosts, h)
		}
	}
	return hosts
}

func checkAll(flake string) {
	fmt.Println("> Checking flake (no build)...")
	runBuild("nix", "flake", "check", flake, "--no-build")
}

func evalAll(flake string) {
	for _, h := range loadHosts(flake, "nixosConfigurations") {
		fmt.Printf("> Evaluating NixOS host: %s\n", h)
		runBuild("nix", "eval", "--raw",
			fmt.Sprintf("%s#nixosConfigurations.%s.config.system.build.toplevel.drvPath", flake, h))
	}
	for _, h := range loadHosts(flake, "darwinConfigurations") {
		fmt.Printf("> Evaluating Darwin host: %s\n", h)
		runBuild("nix", "eval", "--raw",
			fmt.Sprintf("%s#darwinConfigurations.%s.config.system.build.toplevel.drvPath", flake, h))
	}
	for _, h := range loadHosts(flake, "homeConfigurations") {
		fmt.Printf("> Evaluating Home Manager host: %s\n", h)
		runBuild("nix", "eval", "--raw",
			fmt.Sprintf("%s#homeConfigurations.%s.activationPackage.drvPath", flake, h))
	}
}

func buildSystems(flake string) {
	for _, h := range loadHosts(flake, "nixosConfigurations") {
		fmt.Printf("> Building NixOS host: %s\n", h)
		runBuild("nix", "build",
			fmt.Sprintf("%s#nixosConfigurations.%s.config.system.build.toplevel", flake, h), "--no-link")
	}
	for _, h := range loadHosts(flake, "darwinConfigurations") {
		fmt.Printf("> Building Darwin host: %s\n", h)
		runBuild("nix", "build",
			fmt.Sprintf("%s#darwinConfigurations.%s.config.system.build.toplevel", flake, h), "--no-link")
	}
}

func buildHM(flake string) {
	for _, h := range loadHosts(flake, "homeConfigurations") {
		fmt.Printf("> Building Home Manager host: %s\n", h)
		runBuild("nix", "build",
			fmt.Sprintf("%s#homeConfigurations.%s.activationPackage", flake, h), "--no-link")
	}
}
