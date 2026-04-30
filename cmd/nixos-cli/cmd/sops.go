package cmd

import (
	"github.com/spf13/cobra"
)

func sopsCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "sops",
		Short: "SOPS key management",
		Long:  `Manage SOPS encryption keys for NixOS secrets.`,
	}
	return cmd
}
