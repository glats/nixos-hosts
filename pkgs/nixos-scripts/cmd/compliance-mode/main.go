package main

import (
	"os"

	"github.com/glats/nixos-scripts/internal/compliancemode"
)

func main() {
	os.Exit(compliancemode.Run(os.Args[1:], os.Stdout, os.Stderr, compliancemode.DefaultEnv()))
}
