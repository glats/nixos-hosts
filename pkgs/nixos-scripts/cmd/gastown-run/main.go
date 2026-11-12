package main

import (
	"os"

	"github.com/glats/nixos-scripts/internal/gastown"
)

func main() {
	os.Exit(gastown.Main(os.Args[1:], os.Stdout, os.Stderr))
}
