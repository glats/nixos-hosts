// Command opencode-harness-init initializes a directory for Engram and OpenSpec.
package main

import (
	"flag"
	"fmt"
	"io"
	"os"
	"os/exec"

	"github.com/glats/nixos-scripts/internal/projectinit"
)

func main() {
	flags := flag.NewFlagSet("opencode-harness-init", flag.ContinueOnError)
	flags.SetOutput(io.Discard)
	name := flags.String("name", "", "Engram project name")
	dryRun := flags.Bool("dry-run", false, "preview without writing")
	force := flags.Bool("force", false, "replace a conflicting Engram project name")
	noOpenSpec := flags.Bool("no-openspec", false, "skip OpenSpec initialization")
	if err := flags.Parse(os.Args[1:]); err != nil || flags.NArg() > 1 {
		fail("usage: opencode-harness-init [--name NAME] [--dry-run] [--force] [--no-openspec] [DIRECTORY]")
	}
	path := "."
	if flags.NArg() == 1 {
		path = flags.Arg(0)
	}
	result, err := projectinit.Init(path, projectinit.Options{
		Name:       *name,
		DryRun:     *dryRun,
		Force:      *force,
		NoOpenSpec: *noOpenSpec,
		OpenSpec: func(path string) error {
			command := exec.Command("openspec", "init", "--tools", "opencode", "--force")
			command.Dir = path
			command.Stdout = os.Stdout
			command.Stderr = os.Stderr
			return command.Run()
		},
	})
	if err != nil {
		fail(err.Error())
	}
	git := "no Git repository detected"
	if result.Git {
		git = "Git repository detected"
	}
	if *dryRun {
		fmt.Printf("dry-run: %s at %s\nEngram: %s\nOpenSpec: %s\n", git, result.Path, dryRunAction(result.Engram), dryRunAction(result.OpenSpec))
		return
	}
	fmt.Printf("%s at %s\nEngram: %s\nOpenSpec: %s\n", git, result.Path, result.Engram, result.OpenSpec)
}

func fail(message string) { fmt.Fprintln(os.Stderr, "error:", message); os.Exit(1) }

func dryRunAction(state string) string {
	if state == "created" {
		return "would create"
	}
	return state
}
