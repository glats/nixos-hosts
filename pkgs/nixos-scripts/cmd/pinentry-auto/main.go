package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"syscall"

	"github.com/glats/nixos-scripts/internal/pinentryauto"
)

func main() {
	exe, err := os.Executable()
	if err != nil {
		fmt.Fprintf(os.Stderr, "pinentry-auto: %v\n", err)
		os.Exit(1)
	}
	env := map[string]string{}
	for _, item := range os.Environ() {
		key, value, found := strings.Cut(item, "=")
		if found {
			env[key] = value
		}
	}

	flavor := pinentryauto.Decide(os.Args[1:], env)
	target := pinentryauto.TargetPath(filepath.Dir(exe), flavor)
	if target == "" {
		os.Exit(1)
	}
	argv := append([]string{target}, os.Args[1:]...)
	if err := syscall.Exec(target, argv, os.Environ()); err != nil {
		fmt.Fprintf(os.Stderr, "pinentry-auto: exec %s: %v\n", target, err)
		os.Exit(1)
	}
}
