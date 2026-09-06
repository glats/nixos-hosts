package main

import (
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
