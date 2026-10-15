package main

import (
	"fmt"
	"github.com/glats/nixos-scripts/internal/aiassets"
	"os"
)

func main() {
	if len(os.Args) != 5 {
		fmt.Fprintln(os.Stderr, "usage: ai-assets-reconcile TARGET DESIRED LEGACY REVISION")
		os.Exit(2)
	}
	if err := aiassets.Reconcile(os.Args[1], os.Args[2], os.Args[3], os.Args[4]); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
