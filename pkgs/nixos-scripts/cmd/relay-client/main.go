// Command relay-client starts the fixed wstunnel client with a runtime header file.
package main

import (
	"fmt"
	"os"
	"syscall"

	"github.com/glats/nixos-scripts/internal/sshrelay"
)

func main() {
	if len(os.Args) != 3 {
		fmt.Fprintln(os.Stderr, "usage: relay-client HEADERS_FILE WSTUNNEL")
		os.Exit(2)
	}
	if err := sshrelay.ValidateHeaderFile(os.Args[1]); err != nil {
		fmt.Fprintln(os.Stderr, "relay-client:", err)
		os.Exit(1)
	}
	args, err := sshrelay.ClientArgs(os.Args[2], os.Args[1], 22220)
	if err != nil {
		fmt.Fprintln(os.Stderr, "relay-client:", err)
		os.Exit(1)
	}
	if err := syscall.Exec(args[0], args, sshrelay.SanitizedEnvironment(os.Environ())); err != nil {
		fmt.Fprintln(os.Stderr, "relay-client:", err)
		os.Exit(1)
	}
}
