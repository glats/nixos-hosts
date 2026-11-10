package gastown

import (
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"syscall"
)

type ConfineSpec struct {
	Root, Cwd, Home, RealHome string
	Bwrap, Path               string
	RO, RW                    []string
	HomeBinds, AllowEnv       []string
	Command                   []string
}

var (
	envPrefixes   = []string{"GT_", "BD_", "BEADS_", "GIT_"}
	envNames      = map[string]bool{"TERM": true, "LANG": true, "TZ": true, "COLORTERM": true}
	etcEntries    = []string{"/etc/ssl", "/etc/static", "/etc/resolv.conf", "/etc/hosts", "/etc/nsswitch.conf", "/etc/passwd", "/etc/group", "/etc/localtime"}
	secretHomeDir = []string{".ssh", ".gnupg", ".aws", ".kube", ".docker", ".netrc", ".config/sops", ".config/gh", ".config/git", ".password-store", ".local/share/keyrings"}
	broadHomeDir  = map[string]bool{".": true, "": true, ".config": true, ".local": true, ".local/share": true, ".local/state": true, ".cache": true}
)

func within(root, path string) bool {
	rel, err := filepath.Rel(root, path)
	return err == nil && rel != ".." && !strings.HasPrefix(rel, ".."+string(filepath.Separator))
}

func safeHomeBind(name string) (string, error) {
	if name == "" || filepath.IsAbs(name) {
		return "", errors.New("home bind must be a relative path: " + name)
	}
	clean := filepath.Clean(name)
	if clean == ".." || strings.HasPrefix(clean, "../") || broadHomeDir[clean] {
		return "", errors.New("home bind is too broad or escapes the home directory: " + name)
	}
	for _, secret := range secretHomeDir {
		if clean == secret || strings.HasPrefix(clean, secret+"/") {
			return "", errors.New("refusing to expose a credential directory: " + name)
		}
	}
	return clean, nil
}

func passesEnv(name string, allow []string) bool {
	if envNames[name] {
		return true
	}
	for _, prefix := range envPrefixes {
		if strings.HasPrefix(name, prefix) {
			return true
		}
	}
	for _, a := range allow {
		if a == name {
			return true
		}
	}
	return false
}

// ConfineArgv builds the bubblewrap command that confines an autonomous agent
// to a Gas Town directory: the town is writable, the rest of the machine is
// not, and only allowlisted environment variables and home entries get in.
func ConfineArgv(s ConfineSpec, environ []string) ([]string, error) {
	if len(s.Command) == 0 {
		return nil, errors.New("no command to run")
	}
	root, cwd, home, realHome := filepath.Clean(s.Root), filepath.Clean(s.Cwd), filepath.Clean(s.Home), filepath.Clean(s.RealHome)
	if !filepath.IsAbs(root) || root == "/" || !filepath.IsAbs(realHome) {
		return nil, errors.New("root and real home must be absolute and root must not be /")
	}
	if within(root, realHome) {
		return nil, errors.New("root must not contain the real home directory")
	}
	if !within(root, cwd) || !within(root, home) {
		return nil, errors.New("working directory and agent home must be inside the town root")
	}
	argv := []string{s.Bwrap, "--unshare-all", "--share-net", "--die-with-parent", "--clearenv", "--cap-drop", "ALL",
		"--ro-bind", "/nix/store", "/nix/store",
		"--ro-bind-try", "/run/current-system/sw/bin", "/run/current-system/sw/bin",
		"--symlink", "/run/current-system/sw/bin", "/bin", "--dir", "/usr", "--symlink", "/run/current-system/sw/bin", "/usr/bin",
		"--dev", "/dev", "--proc", "/proc", "--tmpfs", "/tmp", "--ro-bind-try", "/run/systemd/resolve", "/run/systemd/resolve"}
	for _, entry := range etcEntries {
		argv = append(argv, "--ro-bind-try", entry, entry)
	}
	argv = append(argv, "--bind", root, root)
	for _, name := range s.HomeBinds {
		clean, err := safeHomeBind(name)
		if err != nil {
			return nil, err
		}
		argv = append(argv, "--bind", filepath.Join(realHome, clean), filepath.Join(home, clean))
	}
	for _, flagName := range []struct {
		flag  string
		paths []string
	}{{"--ro-bind", s.RO}, {"--bind", s.RW}} {
		for _, path := range flagName.paths {
			if !filepath.IsAbs(path) || filepath.Clean(path) == "/" || within(path, realHome) {
				return nil, errors.New("extra binds must be absolute, not /, and not contain the home directory: " + path)
			}
			argv = append(argv, flagName.flag, path, path)
		}
	}
	set := map[string]string{"HOME": home, "PATH": s.Path, "TMPDIR": "/tmp", "USER": "agent", "LOGNAME": "agent"}
	order := []string{"HOME", "PATH", "TMPDIR", "USER", "LOGNAME"}
	for _, entry := range environ {
		name, value, ok := strings.Cut(entry, "=")
		if !ok || set[name] != "" || !passesEnv(name, s.AllowEnv) {
			continue
		}
		set[name] = value
		order = append(order, name)
	}
	for _, name := range order {
		argv = append(argv, "--setenv", name, set[name])
	}
	argv = append(argv, "--chdir", cwd, "--")
	return append(argv, s.Command...), nil
}

type listFlag []string

func (l *listFlag) String() string     { return strings.Join(*l, ",") }
func (l *listFlag) Set(v string) error { *l = append(*l, v); return nil }

// Confine runs a command inside the confinement; it replaces this process on success.
func Confine(args []string, stderr io.Writer) int {
	fs := flag.NewFlagSet("confine", flag.ContinueOnError)
	fs.SetOutput(stderr)
	root := fs.String("root", "", "town directory the agent may write")
	home := fs.String("home", "", "agent home inside the town")
	bwrap := fs.String("bwrap", os.Getenv("GASTOWN_BWRAP"), "bubblewrap binary")
	path := fs.String("path", os.Getenv("GASTOWN_SYSTEM_PATH"), "PATH inside the sandbox")
	realHomeFlag := fs.String("real-home", "", "real home directory that home-bind entries come from (default: $HOME)")
	trustCodex := fs.Bool("trust-codex-project", false, "mark the working directory's git root as trusted in the agent's Codex config")
	prepareClaude := fs.Bool("prepare-claude", false, "pre-answer Claude Code's first-run dialogs for the working directory's git root")
	var ro, rw, homeBinds, allowEnv listFlag
	fs.Var(&ro, "ro", "extra read-only absolute path")
	fs.Var(&rw, "rw", "extra writable absolute path")
	fs.Var(&homeBinds, "home-bind", "entry of the real home to expose, relative")
	fs.Var(&allowEnv, "env", "extra environment variable to pass")
	if fs.Parse(args) != nil || fs.NArg() == 0 || *root == "" || *home == "" || *bwrap == "" || *path == "" {
		fmt.Fprintln(stderr, "usage: gastown-run confine --root DIR --home DIR --bwrap BIN --path PATH [--real-home DIR] [--home-bind NAME] [--env NAME] -- command args")
		return 2
	}
	realHome, err := *realHomeFlag, error(nil)
	if realHome == "" {
		realHome, err = os.UserHomeDir()
	}
	cwd, cwdErr := os.Getwd()
	if err != nil || cwdErr != nil {
		fmt.Fprintln(stderr, "gastown-run confine: cannot resolve home or working directory")
		return 1
	}
	spec := ConfineSpec{Root: *root, Cwd: cwd, Home: *home, RealHome: realHome, Bwrap: *bwrap, Path: *path,
		RO: ro, RW: rw, HomeBinds: homeBinds, AllowEnv: allowEnv, Command: fs.Args()}
	argv, err := ConfineArgv(spec, os.Environ())
	if err != nil {
		fmt.Fprintln(stderr, "gastown-run confine: refused:", err)
		return 1
	}
	for _, name := range homeBinds {
		if _, statErr := os.Stat(filepath.Join(realHome, filepath.Clean(name))); statErr != nil {
			fmt.Fprintln(stderr, "gastown-run confine: home entry not found:", name)
			return 1
		}
	}
	if err := os.MkdirAll(*home, 0o700); err != nil {
		fmt.Fprintln(stderr, "gastown-run confine:", err)
		return 1
	}
	if *trustCodex {
		if err := TrustProject(filepath.Join(*home, ".codex", "config.toml"), GitRoot(cwd)); err != nil {
			fmt.Fprintln(stderr, "gastown-run confine:", err)
			return 1
		}
	}
	if *prepareClaude {
		if err := PrepareClaude(*home, GitRoot(cwd)); err != nil {
			fmt.Fprintln(stderr, "gastown-run confine:", err)
			return 1
		}
	}
	gitconfig := filepath.Join(*home, ".gitconfig")
	if _, statErr := os.Stat(gitconfig); statErr != nil {
		_ = os.WriteFile(gitconfig, []byte("[user]\n\tname = gastown-agent\n\temail = agent@localhost\n[init]\n\tdefaultBranch = main\n[safe]\n\tdirectory = *\n"), 0o600)
	}
	if err := syscall.Exec(argv[0], argv, []string{}); err != nil {
		fmt.Fprintln(stderr, "gastown-run confine:", err)
		return 1
	}
	return 0
}

// GitRoot returns the nearest ancestor of dir that holds a .git entry, or dir itself.
func GitRoot(dir string) string {
	for current := filepath.Clean(dir); ; current = filepath.Dir(current) {
		if _, err := os.Stat(filepath.Join(current, ".git")); err == nil {
			return current
		}
		if current == filepath.Dir(current) {
			return filepath.Clean(dir)
		}
	}
}

// PrepareClaude answers Claude Code's first-run dialogs (onboarding, theme,
// workspace trust, bypass-permissions notice) in an agent home so a headless
// session never stops at them. Existing settings are preserved; it is idempotent.
func PrepareClaude(home, project string) error {
	if !filepath.IsAbs(project) {
		return errors.New("project path must be absolute: " + project)
	}
	state := filepath.Join(home, ".claude.json")
	doc := map[string]any{}
	if data, err := os.ReadFile(state); err == nil {
		_ = json.Unmarshal(data, &doc)
	}
	doc["hasCompletedOnboarding"] = true
	doc["theme"] = "dark"
	projects, _ := doc["projects"].(map[string]any)
	if projects == nil {
		projects = map[string]any{}
	}
	entry, _ := projects[project].(map[string]any)
	if entry == nil {
		entry = map[string]any{}
	}
	entry["hasTrustDialogAccepted"] = true
	projects[project] = entry
	doc["projects"] = projects
	if err := writeJSON(state, doc); err != nil {
		return err
	}
	settingsPath := filepath.Join(home, ".claude", "settings.json")
	settings := map[string]any{}
	if data, err := os.ReadFile(settingsPath); err == nil {
		_ = json.Unmarshal(data, &settings)
	}
	settings["theme"] = "dark"
	settings["skipDangerousModePermissionPrompt"] = true
	return writeJSON(settingsPath, settings)
}

func writeJSON(path string, doc map[string]any) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return err
	}
	data, err := json.MarshalIndent(doc, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, append(data, '\n'), 0o600)
}

// TrustProject marks a project root as trusted in a Codex config.toml so the
// agent never stops at the workspace trust dialog. It is idempotent.
func TrustProject(configPath, project string) error {
	if !filepath.IsAbs(project) || strings.ContainsAny(project, "\"\\\n\r") {
		return errors.New("project path cannot be written to a TOML table name: " + project)
	}
	header := `[projects."` + project + `"]`
	existing, err := os.ReadFile(configPath)
	if err != nil && !os.IsNotExist(err) {
		return err
	}
	if strings.Contains(string(existing), header+"\n") {
		return nil
	}
	if err := os.MkdirAll(filepath.Dir(configPath), 0o700); err != nil {
		return err
	}
	f, err := os.OpenFile(configPath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o600)
	if err != nil {
		return err
	}
	defer f.Close()
	_, err = f.WriteString(header + "\ntrust_level = \"trusted\"\n\n")
	return err
}
