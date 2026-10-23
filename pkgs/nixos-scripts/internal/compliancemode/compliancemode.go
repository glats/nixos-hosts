package compliancemode

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"strconv"
	"strings"
	"syscall"
)

const (
	offSpecialisation = "compliance-off"
	markerPath        = "etc/corporate-compliance/mode"
	efiVendorGUID     = "4a67b082-0a4c-41cf-b6c7-440b29bb8c4f"
	usageText         = `usage: compliance-mode on|off|status
  on      restore the ON generation and boot selection (root, Linux)
  off     select the compliance-off specialisation and boot selection (root, Linux)
  status  report runtime, selected generation and boot selection (read-only)
`
	runtimeUncertain = "compliance-mode: runtime state is uncertain: a boot default restore does not restore services; run compliance-mode status\n"
)

var (
	generationLink = regexp.MustCompile(`^system-([0-9]+)-link$`)
	efiOverrides   = []string{"LoaderEntryDefault", "LoaderEntryPreferred", "LoaderEntryOneShot"}
)

type Paths struct {
	StoreDir    string
	ProfilesDir string
	RuntimeLink string
	LoaderDir   string
	EFIVarsDir  string
	LockFile    string
}

type Runner interface {
	Run(name string, args ...string) error
}

type Env struct {
	GOOS   string
	Euid   int
	Paths  Paths
	Runner Runner
}

type execRunner struct{}

func (execRunner) Run(name string, args ...string) error {
	cmd := exec.Command(name, args...)
	cmd.Stdout = os.Stderr
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func DefaultEnv() Env {
	return Env{
		GOOS: runtime.GOOS,
		Euid: os.Geteuid(),
		Paths: Paths{
			StoreDir:    "/nix/store",
			ProfilesDir: "/nix/var/nix/profiles",
			RuntimeLink: "/run/current-system",
			LoaderDir:   "/boot/loader",
			EFIVarsDir:  "/sys/firmware/efi/efivars",
			LockFile:    "/run/lock/compliance-mode.lock",
		},
		Runner: execRunner{},
	}
}

func Run(args []string, stdout, stderr io.Writer, env Env) int {
	if len(args) == 0 {
		fmt.Fprint(stderr, usageText)
		return 2
	}
	switch args[0] {
	case "help", "-h", "--help":
		fmt.Fprint(stdout, usageText)
		return 0
	case "status":
		if len(args) != 1 {
			return usageError(stderr, "status takes no arguments")
		}
		return env.status(stdout)
	case "on", "off":
		if len(args) != 1 {
			return usageError(stderr, args[0]+" takes no arguments")
		}
		return env.apply(args[0], stdout, stderr)
	default:
		fmt.Fprintf(stderr, "compliance-mode: unknown command %q\n", args[0])
		fmt.Fprint(stderr, usageText)
		return 2
	}
}

func usageError(stderr io.Writer, message string) int {
	fmt.Fprintf(stderr, "compliance-mode: %s\n", message)
	fmt.Fprint(stderr, usageText)
	return 2
}

type marker struct {
	value string
	err   error
}

func readMarker(closure string) marker {
	raw, err := os.ReadFile(filepath.Join(closure, markerPath))
	if err != nil {
		return marker{err: err}
	}
	value := strings.TrimSpace(string(raw))
	if value != "on" && value != "off" {
		return marker{err: fmt.Errorf("invalid value %q", value)}
	}
	return marker{value: value}
}

func (m marker) is(value string) bool {
	return m.err == nil && m.value == value
}

func (m marker) problem(name, expected string) string {
	if m.err != nil {
		return fmt.Sprintf("%s marker unreadable: %v", name, m.err)
	}
	return fmt.Sprintf("%s marker is %s, expected %s", name, m.value, expected)
}

type snapshot struct {
	number          int
	profile         string
	runtime         string
	child           string
	childErr        error
	profileMarker   marker
	childMarker     marker
	loaderRaw       []byte
	loaderDefault   string
	loaderErr       error
	onEntryPresent  bool
	offEntryPresent bool
	persistErr      error
}

func (e Env) loaderConf() string {
	return filepath.Join(e.Paths.LoaderDir, "loader.conf")
}

func (e Env) entry(name string) string {
	return filepath.Join(e.Paths.LoaderDir, "entries", name)
}

func onEntryName(n int) string {
	return fmt.Sprintf("nixos-generation-%d.conf", n)
}

func offEntryName(n int) string {
	return fmt.Sprintf("nixos-generation-%d-specialisation-compliance-off.conf", n)
}

func (e Env) resolveClosure(link string) (string, error) {
	resolved, err := filepath.EvalSymlinks(link)
	if err != nil {
		return "", err
	}
	store, err := filepath.EvalSymlinks(e.Paths.StoreDir)
	if err != nil {
		return "", err
	}
	if !strings.HasPrefix(resolved, store+string(filepath.Separator)) {
		return "", fmt.Errorf("%s is outside %s", resolved, store)
	}
	info, err := os.Stat(resolved)
	if err != nil {
		return "", err
	}
	if !info.IsDir() {
		return "", fmt.Errorf("%s is not a closure directory", resolved)
	}
	return resolved, nil
}

func (e Env) persistence() error {
	if _, err := os.Stat(e.Paths.EFIVarsDir); err != nil {
		return fmt.Errorf("persistence: EFI variables unavailable at %s", e.Paths.EFIVarsDir)
	}
	for _, name := range efiOverrides {
		_, err := os.Stat(filepath.Join(e.Paths.EFIVarsDir, name+"-"+efiVendorGUID))
		if err == nil {
			return fmt.Errorf("persistence: EFI override %s is present", name)
		}
		if !errors.Is(err, fs.ErrNotExist) {
			return fmt.Errorf("persistence: EFI override %s is unreadable: %v", name, err)
		}
	}
	return nil
}

func (e Env) observe() (snapshot, error) {
	var s snapshot
	link, err := os.Readlink(filepath.Join(e.Paths.ProfilesDir, "system"))
	if err != nil {
		return s, fmt.Errorf("selected profile unreadable: %w", err)
	}
	name := filepath.Base(link)
	match := generationLink.FindStringSubmatch(name)
	if match == nil {
		return s, fmt.Errorf("selected profile %s is not a generation link", name)
	}
	s.number, _ = strconv.Atoi(match[1])
	s.profile, err = e.resolveClosure(filepath.Join(e.Paths.ProfilesDir, name))
	if err != nil {
		return s, fmt.Errorf("selected generation %d: %w", s.number, err)
	}
	s.runtime, err = e.resolveClosure(e.Paths.RuntimeLink)
	if err != nil {
		return s, fmt.Errorf("runtime: %w", err)
	}
	s.profileMarker = readMarker(s.profile)
	s.child, s.childErr = e.resolveClosure(filepath.Join(s.profile, "specialisation", offSpecialisation))
	if s.childErr == nil {
		s.childMarker = readMarker(s.child)
	} else {
		s.childMarker = marker{err: s.childErr}
	}
	s.loaderRaw, s.loaderErr = os.ReadFile(e.loaderConf())
	if s.loaderErr == nil {
		s.loaderDefault, s.loaderErr = loaderDefault(s.loaderRaw)
	}
	s.onEntryPresent = exists(e.entry(onEntryName(s.number)))
	s.offEntryPresent = exists(e.entry(offEntryName(s.number)))
	s.persistErr = e.persistence()
	return s, nil
}

func exists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

func loaderDefault(raw []byte) (string, error) {
	for _, line := range strings.Split(string(raw), "\n") {
		fields := strings.Fields(line)
		if len(fields) == 2 && fields[0] == "default" {
			return fields[1], nil
		}
	}
	return "", errors.New("no default entry in loader.conf")
}

func setLoaderDefault(raw []byte, entry string) []byte {
	lines := strings.SplitAfter(string(raw), "\n")
	replaced := false
	for i, line := range lines {
		fields := strings.Fields(line)
		if len(fields) == 2 && fields[0] == "default" {
			lines[i] = "default " + entry + "\n"
			replaced = true
			break
		}
	}
	text := strings.Join(lines, "")
	if !replaced {
		text = "default " + entry + "\n" + text
	}
	return []byte(text)
}

func (s snapshot) bootSelection() string {
	if s.loaderErr != nil {
		return "unknown"
	}
	return s.loaderDefault
}

func (s snapshot) bootProblems(label, want string, present bool) []string {
	var problems []string
	switch {
	case s.loaderErr != nil:
		problems = append(problems, "boot default unreadable: "+s.loaderErr.Error())
	case s.loaderDefault != want:
		problems = append(problems, fmt.Sprintf("boot default %s does not select %s entry %s", s.loaderDefault, label, want))
	}
	if !present {
		problems = append(problems, "boot entry "+want+" is missing")
	}
	return problems
}

func (s snapshot) selection() (string, []string) {
	var problems []string
	if s.persistErr != nil {
		problems = append(problems, s.persistErr.Error())
	}
	if !s.profileMarker.is("on") {
		problems = append(problems, s.profileMarker.problem("selected generation", "on"))
	}
	switch {
	case s.runtime == s.profile:
		problems = append(problems, s.bootProblems("ON", onEntryName(s.number), s.onEntryPresent)...)
		if len(problems) == 0 {
			return "on", nil
		}
	case s.childErr == nil && s.runtime == s.child:
		if !s.childMarker.is("off") {
			problems = append(problems, s.childMarker.problem("compliance-off", "off"))
		}
		problems = append(problems, s.bootProblems("OFF", offEntryName(s.number), s.offEntryPresent)...)
		if len(problems) == 0 {
			return "off", nil
		}
	default:
		problems = append(problems, fmt.Sprintf("runtime %s is neither generation %d nor its compliance-off specialisation", s.runtime, s.number))
	}
	return "unknown", problems
}

func (e Env) status(out io.Writer) int {
	s, err := e.observe()
	if err != nil {
		fmt.Fprintf(out, "compliance-mode: unknown\nproblem: %v\n", err)
		return 1
	}
	mode, problems := s.selection()
	persistence := "ok"
	if s.persistErr != nil {
		persistence = "blocked"
	}
	fmt.Fprintf(out, "compliance-mode: %s\n", mode)
	fmt.Fprintf(out, "runtime: %s\n", s.runtime)
	fmt.Fprintf(out, "selected generation: %d (%s)\n", s.number, s.profile)
	fmt.Fprintf(out, "boot selection: %s\n", s.bootSelection())
	fmt.Fprintf(out, "persistence: %s\n", persistence)
	for _, problem := range problems {
		fmt.Fprintf(out, "problem: %s\n", problem)
	}
	if mode == "unknown" {
		return 1
	}
	return 0
}

type plan struct {
	entry     string
	switchBin string
}

func offListedInBootspec(closure string) bool {
	raw, err := os.ReadFile(filepath.Join(closure, "boot.json"))
	if err != nil {
		return false
	}
	var doc struct {
		Specialisations map[string]json.RawMessage `json:"org.nixos.specialisation.v1"`
	}
	if err := json.Unmarshal(raw, &doc); err != nil {
		return false
	}
	_, ok := doc.Specialisations[offSpecialisation]
	return ok
}

func (s snapshot) plan(target string) (plan, error) {
	if target == "off" {
		switch {
		case s.childErr != nil:
			return plan{}, fmt.Errorf("compliance-off specialisation is missing from generation %d", s.number)
		case !s.childMarker.is("off"):
			return plan{}, errors.New(s.childMarker.problem("compliance-off", "off"))
		case !offListedInBootspec(s.profile):
			return plan{}, fmt.Errorf("bootspec of generation %d does not list compliance-off", s.number)
		case !s.offEntryPresent:
			return plan{}, fmt.Errorf("boot entry %s is missing", offEntryName(s.number))
		}
		return plan{entry: offEntryName(s.number), switchBin: filepath.Join(s.child, "bin", "switch-to-configuration")}, nil
	}
	if !s.onEntryPresent {
		return plan{}, fmt.Errorf("boot entry %s is missing", onEntryName(s.number))
	}
	return plan{entry: onEntryName(s.number), switchBin: filepath.Join(s.profile, "bin", "switch-to-configuration")}, nil
}

func (e Env) lock() (func(), error) {
	file, err := os.OpenFile(e.Paths.LockFile, os.O_CREATE|os.O_RDWR, 0o600)
	if err != nil {
		return nil, err
	}
	if err := syscall.Flock(int(file.Fd()), syscall.LOCK_EX); err != nil {
		_ = file.Close()
		return nil, err
	}
	return func() {
		_ = syscall.Flock(int(file.Fd()), syscall.LOCK_UN)
		_ = file.Close()
	}, nil
}

func writeAtomic(path string, data []byte) error {
	tmp, err := os.CreateTemp(filepath.Dir(path), filepath.Base(path)+".*.tmp")
	if err != nil {
		return err
	}
	tmpName := tmp.Name()
	_, werr := tmp.Write(data)
	if werr == nil {
		werr = tmp.Sync()
	}
	if cerr := tmp.Close(); werr == nil {
		werr = cerr
	}
	if werr == nil {
		werr = os.Chmod(tmpName, 0o644)
	}
	if werr == nil {
		werr = os.Rename(tmpName, path)
	}
	if werr != nil {
		_ = os.Remove(tmpName)
	}
	return werr
}

func refuse(errw io.Writer, format string, args ...any) int {
	fmt.Fprintf(errw, "compliance-mode: refused: "+format+"\n", args...)
	return 1
}

func refuseProblems(errw io.Writer, problems []string) int {
	fmt.Fprintln(errw, "compliance-mode: refused: state is not consistent")
	for _, problem := range problems {
		fmt.Fprintf(errw, "problem: %s\n", problem)
	}
	return 1
}

func (e Env) apply(target string, out, errw io.Writer) int {
	if e.GOOS != "linux" {
		fmt.Fprintf(errw, "compliance-mode: %s requires Linux\n", target)
		return 1
	}
	if e.Euid != 0 {
		fmt.Fprintf(errw, "compliance-mode: %s requires root\n", target)
		return 1
	}
	unlock, err := e.lock()
	if err != nil {
		return refuse(errw, "cannot lock %s: %v", e.Paths.LockFile, err)
	}
	defer unlock()

	before, err := e.observe()
	if err != nil {
		return refuse(errw, "state is unreadable: %v", err)
	}
	mode, problems := before.selection()
	if len(problems) > 0 {
		return refuseProblems(errw, problems)
	}
	if mode == target {
		fmt.Fprintf(out, "compliance-mode: already %s; runtime, selected generation and boot selection agree\n", target)
		return 0
	}
	next, err := before.plan(target)
	if err != nil {
		return refuse(errw, "%v", err)
	}

	now, err := e.observe()
	if err != nil || now.number != before.number || now.profile != before.profile || now.runtime != before.runtime || !bytes.Equal(now.loaderRaw, before.loaderRaw) {
		return refuse(errw, "state changed before effects; nothing was changed")
	}
	written := setLoaderDefault(before.loaderRaw, next.entry)
	if err := writeAtomic(e.loaderConf(), written); err != nil {
		return refuse(errw, "cannot write boot default: %v", err)
	}
	if err := e.Runner.Run(next.switchBin, "switch"); err != nil {
		return e.rollback(before, written, err, errw)
	}

	after, err := e.observe()
	if err != nil {
		fmt.Fprintf(errw, "compliance-mode: postcondition failed: state unreadable: %v\n", err)
		return 1
	}
	mode, problems = after.selection()
	if mode != target || len(problems) > 0 {
		fmt.Fprintln(errw, "compliance-mode: postcondition failed: state is not as requested")
		for _, problem := range problems {
			fmt.Fprintf(errw, "problem: %s\n", problem)
		}
		return 1
	}
	fmt.Fprintf(out, "compliance-mode: %s applied; runtime %s; boot selection %s\n", target, after.runtime, next.entry)
	return 0
}

func (e Env) rollback(before snapshot, written []byte, cause error, errw io.Writer) int {
	fmt.Fprintf(errw, "compliance-mode: switch failed: %v\n", cause)
	now, err := e.observe()
	if err != nil {
		fmt.Fprintf(errw, "compliance-mode: state unreadable during rollback; boot default not restored: %v\n", err)
		fmt.Fprint(errw, runtimeUncertain)
		return 1
	}
	if now.number != before.number || now.profile != before.profile {
		fmt.Fprintf(errw, "compliance-mode: selected profile moved to generation %d; boot default not restored\n", now.number)
		fmt.Fprint(errw, runtimeUncertain)
		return 1
	}
	current, err := os.ReadFile(e.loaderConf())
	if err != nil || !bytes.Equal(current, written) {
		fmt.Fprintln(errw, "compliance-mode: boot default changed during the operation; not restored")
		fmt.Fprint(errw, runtimeUncertain)
		return 1
	}
	if err := writeAtomic(e.loaderConf(), before.loaderRaw); err != nil {
		fmt.Fprintf(errw, "compliance-mode: rollback failed: %v\n", err)
		fmt.Fprint(errw, runtimeUncertain)
		return 1
	}
	fmt.Fprintf(errw, "compliance-mode: boot default restored to %s\n", before.bootSelection())
	fmt.Fprint(errw, runtimeUncertain)
	return 1
}
