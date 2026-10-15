package main

import (
	"flag"
	"fmt"
	"os"

	"github.com/glats/nixos-scripts/internal/opencodelayout"
)

func main() {
	home := flag.String("home", os.Getenv("HOME"), "home directory")
	retire := flag.Bool("retire-openfang-skills", false, "archive unowned OpenFang skills")
	flag.Parse()
	if flag.NArg() != 0 || *home == "" {
		fmt.Fprintln(os.Stderr, "usage: opencode-layout-migrate [--home DIR] [--retire-openfang-skills]")
		os.Exit(2)
	}
	message, err := opencodelayout.Migrate(*home, *retire)
	if err != nil {
		fmt.Fprintln(os.Stderr, "opencode-layout-migrate:", err)
		os.Exit(1)
	}
	fmt.Println("opencode-layout-migrate:", message)
}
