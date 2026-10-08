// Command relay-policy applies or revokes the fixed rog SSH relay policy.
package main

import (
	"context"
	"errors"
	"fmt"
	"os"
	"runtime"
	"time"

	"github.com/glats/nixos-scripts/internal/sshrelay"
)

func main() {
	if err := run(os.Args[1:], sshrelay.StageAuthorization); err != nil {
		fmt.Fprintln(os.Stderr, "relay-policy:", err)
		if errors.Is(err, errUsage) {
			os.Exit(2)
		}
		os.Exit(1)
	}
}

var errUsage = errors.New("invalid arguments")

func run(args []string, stage func(string) error) error {
	if runtime.GOOS != "linux" || len(args) < 1 || len(args) > 2 || (args[0] != "apply" && args[0] != "revoke" && args[0] != "stage") || (args[0] == "stage" && len(args) != 2) || (args[0] != "stage" && len(args) != 1) {
		fmt.Fprintln(os.Stderr, "usage: relay-policy apply|revoke|stage <source-path> (Linux rog only)")
		return errUsage
	}
	var err error
	if args[0] == "stage" {
		return stage(args[1])
	} else {
		tx, constructorErr := sshrelay.NewPolicyTransaction()
		err = constructorErr
		if err == nil {
			ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
			defer cancel()
			if args[0] == "apply" {
				err = tx.Apply(ctx)
			} else {
				err = tx.Revoke(ctx)
			}
		}
	}
	return err
}
