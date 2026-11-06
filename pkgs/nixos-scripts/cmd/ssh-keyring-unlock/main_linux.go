package main

import (
	"os"

	"github.com/glats/nixos-scripts/internal/keyringunlock"
)

func main() {
	backend := keyringunlock.SystemBackend{Input: os.Stdin, Output: os.Stderr}
	os.Exit(keyringunlock.Run(os.Args[1:], keyringunlock.CurrentSession(), backend, os.Stderr))
}
