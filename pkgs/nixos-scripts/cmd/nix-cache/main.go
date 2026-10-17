package main

import (
	"flag"
	"fmt"
	"os"

	"github.com/glats/nixos-scripts/internal/nixcache"
)

func main() {
	command := ""
	args := []string{}
	if len(os.Args) > 1 {
		command = os.Args[1]
		args = os.Args[2:]
	}

	switch command {
	case "prewarm":
		prewarm(args)
	case "push":
		push(args)
	case "help", "-h", "--help", "":
		fmt.Print(nixcache.UsageText)
	default:
		fmt.Fprintf(os.Stderr, "nix-cache: unknown command %q\n\n", command)
		fmt.Fprint(os.Stderr, nixcache.UsageText)
		os.Exit(1)
	}
}

func warnf(msg string) {
	fmt.Fprintln(os.Stderr, "WARNING: "+msg)
}

func fatalCLI(err error) {
	fmt.Fprintln(os.Stderr, "ERROR:", err)
	os.Exit(1)
}

func prewarm(args []string) {
	fs := flag.NewFlagSet("nix-cache prewarm", flag.ExitOnError)
	flake := fs.String("flake", "", "git URL of the flake to prewarm (default: $NIX_CACHE_FLAKE)")
	stateDir := fs.String("state-dir", nixcache.DefaultStateDir,
		"state directory for the GC-root out-links and the next-variant scratch clone")
	maxLoad := fs.Float64("max-load", nixcache.DefaultMaxLoad,
		"skip prewarm when the 1-minute load average exceeds this")
	if err := fs.Parse(args); err != nil {
		fatalCLI(err)
	}

	load, err := nixcache.ReadLoadavg()
	if err != nil {
		fatalCLI(fmt.Errorf("read load average: %w", err))
	}
	opts := nixcache.Options{
		Flake:    nixcache.ResolveFlake(*flake, os.Getenv),
		StateDir: *stateDir,
		MaxLoad:  *maxLoad,
	}
	if err := nixcache.Prewarm(opts, load, nixcache.ExecRunner{}, warnf); err != nil {
		fatalCLI(err)
	}
}

func push(args []string) {
	fs := flag.NewFlagSet("nix-cache push", flag.ExitOnError)
	to := fs.String("to", nixcache.DefaultPushTo, "nix copy --to destination")
	strict := fs.Bool("strict", false, "make copy failures fatal instead of best-effort")
	if err := fs.Parse(args); err != nil {
		fatalCLI(err)
	}
	if err := nixcache.Push(*to, fs.Args(), *strict, nixcache.ExecRunner{}, warnf); err != nil {
		fatalCLI(err)
	}
}
