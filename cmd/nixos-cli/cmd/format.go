package cmd

import (
	"github.com/spf13/cobra"
)

func formatCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "format",
		Short: "Format Nix files",
		Long:  `Format Nix files using nixfmt or nixpkgs-fmt.`,
	}
	return cmd
}
