// Command relayctl controls the manual macOS SSH relay launch agent.
package main

import (
	"context"
	"fmt"
	"os"
	"path/filepath"

	"github.com/glats/nixos-scripts/internal/sshrelay"
)

func main() {
	if len(os.Args) < 2 || len(os.Args) > 4 {
		fmt.Fprintln(os.Stderr, "usage: relayctl on|off|status|credentials apply|revoke|stage <source-path>")
		os.Exit(2)
	}
	if os.Args[1] != "credentials" && len(os.Args) != 2 {
		fmt.Fprintln(os.Stderr, "usage: relayctl on|off|status|credentials apply|revoke|stage <source-path>")
		os.Exit(2)
	}
	home, err := os.UserHomeDir()
	if err != nil {
		fmt.Fprintln(os.Stderr, "relayctl:", err)
		os.Exit(1)
	}
	stateDir := filepath.Join(home, "Library", "Caches", "nixos", "ssh-relay")
	plist := filepath.Join(home, "Library", "LaunchAgents", sshrelay.DefaultLabel+".plist")
	credentialDir := filepath.Join(home, "Library", "Application Support", "nixos", "ssh-relay")
	c, err := sshrelay.New(sshrelay.Config{StateDir: stateDir, PlistPath: plist, Label: sshrelay.DefaultLabel, CredentialStagePath: filepath.Join(credentialDir, "authorization"), HeadersPath: filepath.Join(credentialDir, "headers")}, sshrelay.CommandLauncher{Path: sshrelay.DefaultCommandPath})
	if err != nil {
		fmt.Fprintln(os.Stderr, "relayctl:", err)
		os.Exit(1)
	}

	switch os.Args[1] {
	case "on":
		err = c.On(context.Background())
	case "off":
		err = c.Off(context.Background())
	case "status":
		var status sshrelay.Status
		status, err = c.Status(context.Background())
		if err == nil {
			fmt.Printf("intent=%s registered=%s pid=%s relay=%s ssh=%s\n", status.Intent, status.Registered, status.PID, status.Relay, status.SSH)
		}
	case "credentials":
		if len(os.Args) < 3 || len(os.Args) > 4 || (os.Args[2] != "apply" && os.Args[2] != "revoke" && os.Args[2] != "stage") || (os.Args[2] == "stage" && len(os.Args) != 4) || (os.Args[2] != "stage" && len(os.Args) != 3) {
			fmt.Fprintln(os.Stderr, "usage: relayctl credentials apply|revoke|stage <source-path>")
			os.Exit(2)
		}
		if os.Args[2] == "apply" {
			err = c.ApplyCredentials(context.Background())
		} else if os.Args[2] == "revoke" {
			err = c.RevokeCredentials(context.Background())
		} else {
			err = c.StageCredentials(context.Background(), os.Args[3])
		}
	default:
		fmt.Fprintln(os.Stderr, "usage: relayctl on|off|status|credentials apply|revoke|stage <source-path>")
		os.Exit(2)
	}
	if err != nil {
		fmt.Fprintln(os.Stderr, "relayctl:", err)
		os.Exit(1)
	}
}
