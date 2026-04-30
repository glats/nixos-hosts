package cmd

import (
	"github.com/spf13/cobra"
)

func buildCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "build",
		Short: "Build and switch NixOS configurations",
		Long:  `Build, switch, or check NixOS configurations. Default action is switch.`,
	}
	return cmd
}
