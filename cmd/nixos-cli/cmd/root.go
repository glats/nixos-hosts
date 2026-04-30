package cmd

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
)

var (
	repoRoot string
	version  = "dev"
)

// Execute runs the root command
func Execute() error {
	rootCmd := &cobra.Command{
		Use:   "nixos",
		Short: "NixOS CLI - Unified command line tool for NixOS management",
		Long: `nixos is a unified CLI for NixOS management, replacing multiple bash scripts
with a typed, testable Go implementation.

Supported subcommands:
  build     Build, switch, or check NixOS configurations
  format    Format Nix files
  worktree  Manage Git worktrees for NixOS development
  sops      SOPS key management

For help with a specific subcommand, run: nixos <subcommand> --help`,
		PersistentPreRun: func(cmd *cobra.Command, args []string) {
			// Ensure repo root is set (auto-detect if not provided)
			if repoRoot == "" {
				repoRoot = detectRepoRoot()
			}
		},
	}

	rootCmd.PersistentFlags().StringVar(&repoRoot, "repo-root", "", "Path to NixOS repository (default: auto-detect via git)")
	rootCmd.PersistentFlags().StringVar(&version, "version", version, "Print version information")

	rootCmd.SetHelpFunc(func(cmd *cobra.Command, args []string) {
		fmt.Printf("NixOS CLI v%s\n\n", version)
		fmt.Println(cmd.Long)
	})

	rootCmd.SetVersionTemplate("nixos version {{.Version}}\n")

	// Register subcommand packages
	rootCmd.AddCommand(buildCmd())
	rootCmd.AddCommand(formatCmd())
	rootCmd.AddCommand(worktreeCmd())
	rootCmd.AddCommand(sopsCmd())

	return rootCmd.Execute()
}

// detectRepoRoot attempts to find the repo root using git
func detectRepoRoot() string {
	// Check NIXOS_REPO environment variable first
	if envRoot := os.Getenv("NIXOS_REPO"); envRoot != "" {
		return envRoot
	}

	// Fall back to current directory
	cwd, err := os.Getwd()
	if err != nil {
		return ""
	}
	return cwd
}
