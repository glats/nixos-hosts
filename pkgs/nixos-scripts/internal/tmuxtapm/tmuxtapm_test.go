package tmuxtapm

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"strings"
	"testing"
)

var plugins = []string{
	"tmux-plugins/tpm",
	"tmux-plugins/tmux-resurrect",
	"tmux-plugins/tmux-continuum",
	"tmux-plugins/tmux-sessionist",
	"tmux-plugins/tmux-yank",
	"tmux-plugins/tmux-open",
	"christoomey/vim-tmux-navigator",
}

func repoRoot(t *testing.T) string {
	t.Helper()
	_, file, _, ok := runtime.Caller(1)
	if !ok {
		t.Fatal("runtime caller unavailable")
	}
	return filepath.Clean(filepath.Join(filepath.Dir(file), "../../../../"))
}

func readFile(t *testing.T, path string) string {
	t.Helper()
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read %s: %v", path, err)
	}
	return string(data)
}

func TestCanonicalTPMDeclarations(t *testing.T) {
	root := repoRoot(t)
	shared := readFile(t, filepath.Join(root, "shared/tmux.nix"))
	for _, leaf := range []string{"linux/home/tmux.nix", "darwin/home/tmux.nix"} {
		content := readFile(t, filepath.Join(root, leaf))
		if strings.Contains(content, "@plugin") || strings.Contains(content, "programs.tmux.plugins") {
			t.Errorf("%s contains competing TPM ownership", leaf)
		}
	}

	previous := 0
	for _, plugin := range plugins {
		needle := "set -g @plugin '" + plugin + "'"
		if got := strings.Count(shared, needle); got != 1 {
			t.Errorf("%q occurs %d times in shared tmux config, want once", plugin, got)
		}
		position := strings.Index(shared, needle)
		if position <= previous {
			t.Errorf("plugin %q is out of declaration order", plugin)
		}
		previous = position
	}
	loader := strings.LastIndex(shared, `run -b "$HOME/.config/tmux/plugins/tpm/tpm"`)
	if loader < previous {
		t.Fatal("TPM loader is not after every declaration")
	}
	if !strings.Contains(shared, `home.activation.installTpm = lib.hm.dag.entryAfter [ "linkGeneration" ]`) {
		t.Fatal("TPM activation does not follow linkGeneration")
	}
	if !strings.Contains(shared, `TPM_DIR="$HOME/.config/tmux/plugins/tpm"`) || strings.Contains(shared, "TPM_DIR=\"$1\"") {
		t.Fatal("TPM activation accepts a caller-selected path")
	}
	if strings.Contains(shared, "activation.install-tpm") {
		t.Fatal("invalid activation attribute remains")
	}
}

func activationScript(t *testing.T, gitRoot string) string {
	t.Helper()
	shared := readFile(t, filepath.Join(repoRoot(t), "shared/tmux.nix"))
	match := regexp.MustCompile(`(?s)home\.activation\.installTpm = .*?''(.*?)'';`).FindStringSubmatch(shared)
	if len(match) != 2 {
		t.Fatal("activation body not found")
	}
	body := strings.TrimSpace(match[1])
	body = strings.ReplaceAll(body, "${pkgs.git}", filepath.Dir(gitRoot))
	body = strings.ReplaceAll(body, "${pkgs.tmux}/bin", "/bin")
	return "run() { if [ \"$1\" = \"--quiet\" ]; then shift; fi; \"$@\"; };\n" + body
}

func writeExecutable(t *testing.T, path, content string) {
	t.Helper()
	if err := os.WriteFile(path, []byte(content), 0o755); err != nil {
		t.Fatal(err)
	}
}

func runActivation(t *testing.T, home, gitRoot string, env ...string) error {
	t.Helper()
	cmd := exec.Command("bash", "-c", activationScript(t, gitRoot))
	cmd.Env = append(os.Environ(), append([]string{"HOME=" + home, "FAIL_CLONE=0", "FAIL_INSTALL=0"}, env...)...)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("%w: %s", err, output)
	}
	return nil
}

func TestRealTPMRuntime(t *testing.T) {
	root := t.TempDir()
	gitRoot := filepath.Join(root, "bin")
	if err := os.Mkdir(gitRoot, 0o755); err != nil {
		t.Fatal(err)
	}
	writeExecutable(t, filepath.Join(gitRoot, "git"), `#!/bin/sh
if [ "$FAIL_CLONE" = 1 ]; then exit 23; fi
for arg do destination="$arg"; done
mkdir -p "$destination/.git" "$destination/bin"
cat > "$destination/bin/install_plugins" <<'EOF'
#!/bin/sh
[ "$FAIL_INSTALL" = 1 ] && exit 24
touch "$HOME/plugin-installed"
EOF
chmod +x "$destination/bin/install_plugins"
`)
	home := filepath.Join(root, "home")
	if err := os.Mkdir(home, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := runActivation(t, home, gitRoot); err != nil {
		t.Fatalf("first activation failed: %v", err)
	}
	tpm := filepath.Join(home, ".config/tmux/plugins/tpm")
	if _, err := os.Stat(filepath.Join(tpm, ".git")); err != nil {
		t.Fatalf("first activation did not clone TPM: %v", err)
	}
	if err := runActivation(t, home, gitRoot); err != nil {
		t.Fatalf("repeat activation failed: %v", err)
	}
	cloneHome := filepath.Join(root, "clone-failure-home")
	if err := os.Mkdir(cloneHome, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := runActivation(t, cloneHome, gitRoot, "FAIL_CLONE=1"); err == nil {
		t.Fatal("clone failure was masked")
	}
	if _, err := os.Stat(filepath.Join(cloneHome, ".config/tmux/plugins/tpm")); !os.IsNotExist(err) {
		t.Fatalf("clone failure left unexpected TPM state: %v", err)
	}
	if err := runActivation(t, home, gitRoot, "FAIL_INSTALL=1"); err == nil {
		t.Fatal("installer failure was masked")
	}
	if _, err := os.Stat(filepath.Join(tpm, ".git")); err != nil {
		t.Fatalf("installer failure removed TPM state: %v", err)
	}

	nonGit := filepath.Join(home, ".config/tmux/plugins/tpm")
	if err := os.RemoveAll(nonGit); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(nonGit, 0o755); err != nil {
		t.Fatal(err)
	}
	sentinel := filepath.Join(nonGit, "keep")
	if err := os.WriteFile(sentinel, []byte("state"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := runActivation(t, home, gitRoot); err == nil {
		t.Fatal("non-Git TPM target was accepted")
	}
	if _, err := os.Stat(sentinel); err != nil {
		t.Fatalf("non-Git target was deleted: %v", err)
	}
}
