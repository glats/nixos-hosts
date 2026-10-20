// Package nixcache implements the nix-cache prewarm and push commands that
// fill the thinkcentre LAN Nix binary cache from any host.
package nixcache

import (
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
)

// EnvFlake is the environment variable prewarm reads when --flake is unset.
const EnvFlake = "NIX_CACHE_FLAKE"

const (
	DefaultStateDir = "/var/lib/nix-cache-prewarm"
	DefaultMaxLoad  = 1.0
	DefaultPushTo   = "ssh-ng://glats@thinkcentre"
	DefaultPath     = "/run/current-system"
	darwinHost      = "macm5"
)

var linuxHosts = []string{"rog", "t14", "thinkcentre"}

// UsageText is printed by nix-cache help and documents every flag.
const UsageText = `Usage: nix-cache [command] [flags]

Prepares the thinkcentre Nix binary cache: prewarm builds host closures into
it with GC roots, push copies store paths to it with nix copy.

Commands:
  prewarm   Build every host output when the machine is idle (see --max-load)
  push      Copy store paths to the cache (best-effort unless --strict)
  help      Print this usage (aliases: -h, --help)

prewarm flags:
  --flake <git-url>     Flake to prewarm (default: $NIX_CACHE_FLAKE; error if
                        neither is set). Builds the "current" variant at the
                        origin/master lock plus a "next" variant from a scratch
                        clone under --state-dir after nix flake update.
  --state-dir <dir>     State directory holding GC-root out-links under
                        roots/current/.. roots/next/.. and the next-variant
                        scratch clone (default: /var/lib/nix-cache-prewarm)
  --max-load <float>    Skip prewarm entirely when the 1-minute load average
                        exceeds this (default: 1.0)

push flags:
  --to <dest>           nix copy --to destination
                        (default: ssh-ng://glats@thinkcentre)
  --strict              Fail when the copy fails instead of warning and
                        exiting 0

Store paths to push default to /run/current-system.
Only ssh-ng://glats@thinkcentre uses --no-check-sigs to upload unsigned local
builds over authenticated SSH; other destinations retain signature checks.
`

// Runner executes one external command with the exact argv it is given.
type Runner interface {
	Run(argv []string) error
}

// ExecRunner runs argv as a child process with inherited stdio.
type ExecRunner struct{}

// Run implements Runner with a real child process.
func (ExecRunner) Run(argv []string) error {
	c := exec.Command(argv[0], argv[1:]...)
	c.Stdout = os.Stdout
	c.Stderr = os.Stderr
	return c.Run()
}

// Step is one external command of a prewarm variant.
type Step struct {
	Name  string
	Args  []string
	Fatal bool
}

// Options carries the prewarm configuration.
type Options struct {
	Flake    string
	StateDir string
	MaxLoad  float64
}

// ResolveFlake falls back to the NIX_CACHE_FLAKE environment variable.
func ResolveFlake(flagValue string, getenv func(string) string) string {
	if flagValue != "" {
		return flagValue
	}
	return getenv(EnvFlake)
}

// CloneTarget converts a Nix flake git ref into the URL and branch for
// git clone, so flake syntax like git+https://...?ref=master stays clonable.
func CloneTarget(ref string) (string, string) {
	if rest, ok := strings.CutPrefix(ref, "github:"); ok {
		if segments := strings.Split(rest, "/"); len(segments) > 2 {
			return "https://github.com/" + strings.Join(segments[:len(segments)-1], "/"),
				segments[len(segments)-1]
		}
		return "https://github.com/" + rest, ""
	}
	if rest, ok := strings.CutPrefix(ref, "git+"); ok {
		ref = rest
	}
	url, branch := ref, ""
	if before, query, has := strings.Cut(ref, "?"); has {
		url = before
		for _, kv := range strings.Split(query, "&") {
			if key, val, ok := strings.Cut(kv, "="); ok && key == "ref" {
				branch = val
			}
		}
	}
	return url, branch
}

// ParseLoadavg reads the 1-minute load as the first field of /proc/loadavg.
func ParseLoadavg(content string) (float64, error) {
	fields := strings.Fields(content)
	if len(fields) == 0 {
		return 0, errors.New("empty load average input")
	}
	load, err := strconv.ParseFloat(fields[0], 64)
	if err != nil {
		return 0, fmt.Errorf("parse load average %q: %w", fields[0], err)
	}
	return load, nil
}

// ReadLoadavg returns the 1-minute load average from /proc/loadavg.
func ReadLoadavg() (float64, error) {
	b, err := os.ReadFile("/proc/loadavg")
	if err != nil {
		return 0, err
	}
	return ParseLoadavg(string(b))
}

// CurrentSteps plans the Linux builds and macm5 substitutes of the current
// origin/master lock. Linux failures make prewarm fail; macm5 is substitute
// only because thinkcentre cannot build aarch64-darwin.
func CurrentSteps(opts Options) []Step {
	return variantSteps(opts, "current", opts.Flake, true)
}

// NextSteps plans the Linux builds of the scratch clone after nix flake
// update. They always stay best-effort: a broken upgrade is a warning.
func NextSteps(opts Options) []Step {
	return variantSteps(opts, "next", nextDir(opts), false)
}

func variantSteps(opts Options, variant, flakeRef string, fatalLinux bool) []Step {
	roots := filepath.Join(opts.StateDir, "roots", variant)
	build := func(name, link, attr string, fatal bool) Step {
		return Step{
			Name: name,
			Args: []string{
				"nix", "build",
				"--out-link", filepath.Join(roots, link),
				"--keep-going",
				flakeRef + "#" + attr,
			},
			Fatal: fatal,
		}
	}
	subst := func(name, link, attr string) Step {
		return Step{
			Name: name,
			Args: []string{
				"nix", "build",
				"--out-link", filepath.Join(roots, link),
				"--option", "max-jobs", "0",
				"--keep-going",
				flakeRef + "#" + attr,
			},
		}
	}
	var steps []Step
	for _, h := range linuxHosts {
		steps = append(steps, build(
			"nixos host "+h,
			"nixos-"+h,
			fmt.Sprintf("nixosConfigurations.%s.config.system.build.toplevel", h),
			fatalLinux,
		))
	}
	for _, h := range linuxHosts {
		steps = append(steps, build(
			"home host "+h,
			"home-"+h,
			fmt.Sprintf("homeConfigurations.%s.activationPackage", h),
			fatalLinux,
		))
	}
	steps = append(steps, subst(
		"darwin host "+darwinHost,
		"darwin-"+darwinHost,
		fmt.Sprintf("darwinConfigurations.%s.config.system.build.toplevel", darwinHost),
	))
	steps = append(steps, subst(
		"home host "+darwinHost,
		"home-"+darwinHost,
		fmt.Sprintf("homeConfigurations.%s.activationPackage", darwinHost),
	))
	return steps
}

func nextDir(opts Options) string {
	return filepath.Join(opts.StateDir, "next")
}

// Prewarm builds the current lock, then a flake-updated scratch clone. It
// fails only when a current Linux build fails; macm5 substitutes and next
// variant problems are warnings. A load average above max-load exits 0 and
// runs nothing.
func Prewarm(opts Options, load float64, run Runner, warn func(string)) error {
	if opts.Flake == "" {
		return errors.New("nix-cache prewarm: no flake set; pass --flake <git-url> or set " + EnvFlake)
	}
	if load > opts.MaxLoad {
		warn(fmt.Sprintf("prewarm skipped: load average %.2f > %.2f", load, opts.MaxLoad))
		return nil
	}
	if opts.StateDir == "" || filepath.Clean(opts.StateDir) == "/" {
		return errors.New("nix-cache prewarm: --state-dir must point at a real state directory")
	}
	if err := ensureRoots(opts, "current"); err != nil {
		return err
	}
	var fatal error
	for _, st := range CurrentSteps(opts) {
		if err := run.Run(st.Args); err != nil {
			warn(fmt.Sprintf("prewarm: %s failed (out-link %s): %v", st.Name, st.Args[3], err))
			if st.Fatal && fatal == nil {
				fatal = fmt.Errorf("nix-cache prewarm: %s failed: %w", st.Name, err)
			}
		}
	}
	if err := prepareNext(opts, run); err != nil {
		warn(fmt.Sprintf("prewarm: next variant skipped: %v", err))
		return fatal
	}
	if err := ensureRoots(opts, "next"); err != nil {
		warn(fmt.Sprintf("prewarm: next variant skipped: %v", err))
		return fatal
	}
	for _, st := range NextSteps(opts) {
		if err := run.Run(st.Args); err != nil {
			warn(fmt.Sprintf("prewarm: %s failed: %v", st.Name, err))
		}
	}
	return fatal
}

func ensureRoots(opts Options, variant string) error {
	dir := filepath.Join(opts.StateDir, "roots", variant)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return fmt.Errorf("nix-cache prewarm: GC root dir %s: %w", dir, err)
	}
	return nil
}

func prepareNext(opts Options, run Runner) error {
	next := nextDir(opts)
	if err := os.MkdirAll(opts.StateDir, 0o755); err != nil {
		return fmt.Errorf("state dir %s: %w", opts.StateDir, err)
	}
	if err := os.RemoveAll(next); err != nil {
		return fmt.Errorf("clearing %s: %w", next, err)
	}
	cloneURL, branch := CloneTarget(opts.Flake)
	cloneArgv := []string{"git", "clone"}
	if branch != "" {
		cloneArgv = append(cloneArgv, "--branch", branch)
	}
	cloneArgv = append(cloneArgv, cloneURL, next)
	if err := run.Run(cloneArgv); err != nil {
		return fmt.Errorf("git clone %s: %w", cloneURL, err)
	}
	if err := run.Run([]string{"nix", "flake", "update", "--flake", next}); err != nil {
		return fmt.Errorf("nix flake update in %s: %w", next, err)
	}
	return nil
}

// Push copies store paths to the cache. Without paths it pushes the running
// system. Failures warn and exit 0 unless strict.
func Push(dest string, paths []string, strict bool, run Runner, warn func(string)) error {
	if dest == "" {
		return errors.New("nix-cache push: empty --to destination")
	}
	if len(paths) == 0 {
		paths = []string{DefaultPath}
	}
	argv := []string{"nix", "copy"}
	if dest == DefaultPushTo {
		argv = append(argv, "--no-check-sigs")
	}
	argv = append(argv, "--to", dest)
	argv = append(argv, paths...)
	if err := run.Run(argv); err != nil {
		if strict {
			return fmt.Errorf("nix copy --to %s: %w", dest, err)
		}
		warn(fmt.Sprintf("push failed (best-effort, continuing): %v", err))
	}
	return nil
}

// PushOptOutEnv, when set to "0", disables the best-effort post-switch push
// that nixos-build runs on macm5 after a successful switch.
const PushOptOutEnv = "NIX_CACHE_PUSH"
