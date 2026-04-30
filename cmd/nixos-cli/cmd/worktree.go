package cmd

import (
	"github.com/spf13/cobra"
)

func worktreeCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "worktree",
		Short: "Manage Git worktrees",
		Long:  `Manage Git worktrees for NixOS development.`,
	}
	return cmd
}
