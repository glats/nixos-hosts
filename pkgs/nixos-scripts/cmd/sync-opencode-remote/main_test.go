package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

func TestBuildMcpList(t *testing.T) {
	cases := []struct {
		name string
		in   []string
		want string
	}{
		{"single", []string{"nixos"}, `"nixos"`},
		{"multiple", []string{"nixos", "github"}, `"nixos","github"`},
		{"empty", nil, ""},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := buildMcpList(tc.in); got != tc.want {
				t.Fatalf("buildMcpList(%q) = %q, want %q", tc.in, got, tc.want)
			}
		})
	}
}

func TestShellQuoteEscape(t *testing.T) {
	// bash ${script//\'/\'\\\'\'}: every single quote becomes '\''
	cases := []struct {
		in, want string
	}{
		{"", ""},
		{"no quotes", "no quotes"},
		{"cfg.get('mcp', {})", `cfg.get('\''mcp'\'', {})`},
	}
	for _, tc := range cases {
		if got := shellQuoteEscape(tc.in); got != tc.want {
			t.Errorf("shellQuoteEscape(%q) = %q, want %q", tc.in, got, tc.want)
		}
	}
}

func TestRemotePythonCmd(t *testing.T) {
	cmd := remotePythonCmd(`print('hi')`)
	if cmd != `python3 -c 'print('\''hi'\'')'` {
		t.Fatalf("remotePythonCmd = %q", cmd)
	}
}

func TestMcpDisableScript(t *testing.T) {
	got := mcpDisableScript("/home/u/.config/opencode", `"nixos"`)
	// Expansion points: path line and disabled list line; everything
	// else must be the bash heredoc verbatim.
	want := `import json, sys
path = "/home/u/.config/opencode/opencode.json"
try:
    with open(path) as f:
        cfg = json.load(f)
    mcps = cfg.get('mcp', {})
    disabled = ["nixos"]
    for name in disabled:
        if name in mcps:
            mcps[name]['enabled'] = False
            print(f'  Disabled MCP: {name}')
    with open(path, 'w') as f:
        json.dump(cfg, f, indent=2)
except Exception as e:
    print(f'WARNING: Failed to patch MCPs: {e}', file=sys.stderr)
    sys.exit(0)  # non-fatal
`
	if got != want {
		t.Fatalf("mcpDisableScript mismatch:\n got: %q\nwant: %q", got, want)
	}
}

func TestProviderRenameScript(t *testing.T) {
	got := providerRenameScript("/cfg")
	want := `import json, sys
path = "/cfg/opencode.json"
try:
    with open(path) as f:
        cfg = json.load(f)
    prov = cfg.get('provider', {})
    if 'opencode' in prov and 'opencode-go' not in prov:
        prov['opencode-go'] = prov.pop('opencode')
        print('  Renamed provider: opencode -> opencode-go')
        with open(path, 'w') as f:
            json.dump(cfg, f, indent=2)
except Exception as e:
    print(f'WARNING: Failed to fix provider name: {e}', file=sys.stderr)
`
	if got != want {
		t.Fatalf("providerRenameScript mismatch:\n got: %q\nwant: %q", got, want)
	}
}

func TestInstallCmdShape(t *testing.T) {
	// The remote install command mirrors the bash double-quoted string
	// after backslash-newline continuations were removed (the 6-space
	// indentation of the source lines stays) and \$ became a literal $.
	dl := "curl -sL https://example.com/x.tar.gz"
	got := "mkdir -p ~/bin &&       (" + dl + ") | tar -xzf - -C /tmp/ github-mcp-server &&" +
		"       cp /tmp/github-mcp-server ~/bin/ &&" +
		"       rm -f /tmp/github-mcp-server &&" +
		"       chmod +x ~/bin/github-mcp-server &&" +
		"       echo 'Installed: $(~/bin/github-mcp-server --version 2>&1)'"
	want := "mkdir -p ~/bin &&       (curl -sL https://example.com/x.tar.gz) | tar -xzf - -C /tmp/ github-mcp-server &&       cp /tmp/github-mcp-server ~/bin/ &&       rm -f /tmp/github-mcp-server &&       chmod +x ~/bin/github-mcp-server &&       echo 'Installed: $(~/bin/github-mcp-server --version 2>&1)'"
	if got != want {
		t.Fatalf("install command mismatch:\n got: %q\nwant: %q", got, want)
	}
	if !strings.Contains(got, `echo 'Installed: $(~/bin/github-mcp-server --version 2>&1)'`) {
		t.Fatalf("literal $(...) echo lost: %q", got)
	}
}

func TestCompatibilityPluginsOnlyNamedPaths(t *testing.T) {
	paths, actions := compatibilityPlugins()
	if strings.Join(paths, ",") != "plugins/rtk.ts,plugins/skill-registry.ts" {
		t.Fatalf("paths = %#v", paths)
	}
	if strings.Join(actions, ",") != "Remove remote asset: plugins/rtk.ts,Remove remote asset: plugins/skill-registry.ts" {
		t.Fatalf("actions = %#v", actions)
	}
}

func TestSnapshotTransferFailureSuppressesCompatibility(t *testing.T) {
	compatibilityCalled := false
	transferErr := fmt.Errorf("rsync failed")

	if err := runTransferAndCompatibility(func() error { return transferErr }, func() {
		compatibilityCalled = true
	}); err != transferErr {
		t.Fatalf("transfer error = %v, want %v", err, transferErr)
	}
	if compatibilityCalled {
		t.Fatal("compatibility stage ran after failed transfer")
	}
}

func TestAdaptOpencodeJSONPreservesAgentsAndDisablesBrowserMCP(t *testing.T) {
	input := []byte(`{"agent":{"alpha":{"model":"openai/gpt-5.6-terra"},"beta":{"prompt":"none"}},"mcp":{"browsermcp":{"enabled":true,"url":"keep"},"other":{"enabled":true}}}`)
	got, actions, err := adaptOpencodeJSON(input)
	if err != nil {
		t.Fatal(err)
	}
	var value map[string]json.RawMessage
	if err := json.Unmarshal(got, &value); err != nil {
		t.Fatal(err)
	}
	var agents map[string]json.RawMessage
	if err := json.Unmarshal(value["agent"], &agents); err != nil {
		t.Fatal(err)
	}
	var alpha, beta map[string]json.RawMessage
	if err := json.Unmarshal(agents["alpha"], &alpha); err != nil {
		t.Fatal(err)
	}
	if string(alpha["model"]) != `"openai/gpt-5.6-terra"` {
		t.Fatalf("OpenAI model changed: %s", alpha["model"])
	}
	if err := json.Unmarshal(agents["beta"], &beta); err != nil {
		t.Fatal(err)
	}
	if _, ok := beta["model"]; ok {
		t.Fatalf("model-less agent gained a model: %#v", beta)
	}
	if !strings.Contains(string(got), "openai/gpt-5.6-terra") || strings.Contains(string(got), "opencode-go/glm") {
		t.Fatalf("model graph was changed: %s", got)
	}
	if len(actions) != 1 || actions[0] != "Disable MCP: browsermcp" {
		t.Fatalf("actions = %#v", actions)
	}
	repeated, repeatedActions, err := adaptOpencodeJSON(got)
	if err != nil || !reflect.DeepEqual(repeatedActions, actions) || string(repeated) != string(got) {
		t.Fatalf("repeat changed compatible state: %q %#v", repeated, repeatedActions)
	}
}

func TestAdaptOpencodeJSONBrowserMCPValidation(t *testing.T) {
	for _, input := range []string{"{", `{"mcp":{"browsermcp":[]}}`} {
		if _, _, err := adaptOpencodeJSON([]byte(input)); err == nil {
			t.Fatalf("adaptOpencodeJSON(%s) unexpectedly succeeded", input)
		}
	}
	got, actions, err := adaptOpencodeJSON([]byte(`{"agent":{"x":{"model":"openai/x"}},"mcp":{"other":{"enabled":true}}}`))
	if err != nil || len(actions) != 0 || strings.Contains(string(got), "browsermcp") {
		t.Fatalf("absent BrowserMCP was not a no-op: %q %#v %v", got, actions, err)
	}
}

func TestApplyCompatibilityDryRunDoesNotUseSSH(t *testing.T) {
	root := t.TempDir()
	config := []byte(`{"agent":{"x":{"model":"openai/gpt-5.6-terra"}},"mcp":{"browsermcp":{"enabled":true}}}`)
	if err := os.WriteFile(filepath.Join(root, "opencode.json"), config, 0o644); err != nil {
		t.Fatal(err)
	}
	called := false
	actions, err := applyCompatibility(true, root, "/remote", "host", func(string, string) ([]byte, error) {
		called = true
		return nil, nil
	}, func(string, string, []byte) error {
		called = true
		return nil
	}, func(string, string) error {
		called = true
		return nil
	})
	if err != nil || called {
		t.Fatalf("dry run called SSH=%v actions=%#v err=%v", called, actions, err)
	}
	want := []string{"Disable MCP: browsermcp", "Remove remote asset: plugins/rtk.ts", "Remove remote asset: plugins/skill-registry.ts"}
	if !reflect.DeepEqual(actions, want) {
		t.Fatalf("dry-run actions = %#v, want %#v", actions, want)
	}
}

func TestApplyCompatibilityReadsTargetAndRemovesOnlyFixedAssets(t *testing.T) {
	root := t.TempDir()
	config := []byte(`{"agent":{"x":{"model":"openai/gpt-5.6-terra"}},"mcp":{"browsermcp":{"enabled":true}}}`)
	if err := os.WriteFile(filepath.Join(root, "opencode.json"), config, 0o644); err != nil {
		t.Fatal(err)
	}
	var state []byte
	var calls []string
	read := func(_, command string) ([]byte, error) { calls = append(calls, "read "+command); return config, nil }
	write := func(_ string, _ string, input []byte) error {
		state = append([]byte(nil), input...)
		calls = append(calls, "write")
		return nil
	}
	remove := func(_, command string) error {
		calls = append(calls, "remove "+command)
		return nil
	}
	if _, err := applyCompatibility(false, root, "/remote", "host", read, write, remove); err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(state), "openai/gpt-5.6-terra") || strings.Contains(string(state), "opencode-go/glm") {
		t.Fatalf("target model changed: %s", state)
	}
	want := []string{"read cat '/remote/opencode.json'", "write", "remove rm -f '/remote/plugins/rtk.ts' '/remote/plugins/skill-registry.ts'"}
	if !reflect.DeepEqual(calls, want) {
		t.Fatalf("calls = %#v, want %#v", calls, want)
	}
}

func TestApplyCompatibilityWritesThenRemoves(t *testing.T) {
	root := t.TempDir()
	plugin := filepath.Join(root, "plugins", "rtk.ts")
	if err := os.MkdirAll(filepath.Dir(plugin), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(root, "opencode.json"), []byte("{\"agent\":{\"x\":{\"model\":\"openai/x\"}}}"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(plugin, []byte("asset"), 0o644); err != nil {
		t.Fatal(err)
	}
	var calls []string
	_, err := applyCompatibility(false, root, "/remote", "host", func(string, string) ([]byte, error) {
		return []byte(`{"mcp":{"browsermcp":{"enabled":true}}}`), nil
	}, func(_, command string, input []byte) error {
		calls = append(calls, "write "+command+" "+string(input))
		return nil
	}, func(_, command string) error {
		calls = append(calls, "remove "+command)
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
	if len(calls) != 2 || !strings.HasPrefix(calls[0], "write cat > '/remote/.opencode.json.compat.tmp'") || calls[1] != "remove rm -f '/remote/plugins/rtk.ts' '/remote/plugins/skill-registry.ts'" {
		t.Fatalf("calls = %#v", calls)
	}
}
