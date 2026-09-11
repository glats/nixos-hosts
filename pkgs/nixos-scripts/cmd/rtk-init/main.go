package main

import (
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"

	"github.com/glats/nixos-scripts/internal/reporoot"
	"github.com/glats/nixos-scripts/internal/rtkinit"
)

func main() {
	flags := flag.NewFlagSet("rtk-init", flag.ContinueOnError)
	flags.SetOutput(io.Discard)
	check := flags.Bool("check", false, "check the managed RTK block")
	remove := flags.Bool("remove", false, "remove the managed RTK block")
	dryRun := flags.Bool("dry-run", false, "preview changes without writing")
	if err := flags.Parse(os.Args[1:]); err != nil {
		fail(err.Error())
	}
	if *check && *remove {
		fail("--check and --remove are mutually exclusive")
	}
	if flags.NArg() > 1 {
		fail("expected at most one target path")
	}
	path := ""
	if flags.NArg() == 1 {
		path = flags.Arg(0)
	} else {
		root, err := reporoot.Resolve()
		if err != nil {
			fail(err.Error())
		}
		path = filepath.Join(root, "AGENTS.md")
	}
	if *check {
		if err := rtkinit.Check(path); err != nil {
			fail(err.Error())
		}
		fmt.Println("ok")
		return
	}
	if *remove {
		result, err := rtkinit.Remove(path, *dryRun)
		if err != nil {
			fail(err.Error())
		}
		if *dryRun {
			fmt.Println("dry-run: would " + string(result))
		} else {
			fmt.Println(string(result))
		}
		return
	}
	result, err := rtkinit.Upsert(path, *dryRun)
	if err != nil {
		fail(err.Error())
	}
	if *dryRun {
		fmt.Println("dry-run: would " + string(result))
	} else {
		fmt.Println(string(result))
	}
}

func fail(message string) { fmt.Fprintln(os.Stderr, message); os.Exit(1) }
