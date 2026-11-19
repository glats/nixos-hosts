package gastown

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

const chainsSwarmJSON = `{
  "project": "p",
  "repo": "/repo",
  "checks": ["go test ./..."],
  "chains": {"mayor": ["claude:sonnet"], "polecat": ["claude:sonnet"]},
  "max_polecats": 2,
  "dolt_port": 45901,
  "protect": ["main.go"],
  "base": "main"
}
`

func chainsFixture(t *testing.T, chains string) (Config, string, string) {
	t.Helper()
	state := t.TempDir()
	dir := filepath.Join(state, "swarm", "p")
	if err := os.MkdirAll(dir, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "swarm.json"), []byte(chainsSwarmJSON), 0o600); err != nil {
		t.Fatal(err)
	}
	file := filepath.Join(state, "chains.json")
	if err := os.WriteFile(file, []byte(chains), 0o600); err != nil {
		t.Fatal(err)
	}
	return Config{State: state}, dir, file
}

func runChains(c Config, file string) (int, string, string) {
	var out, errOut bytes.Buffer
	code := SwarmMain(c, []string{"chains", "p", file}, &out, &errOut)
	return code, out.String(), errOut.String()
}

func TestSwarmChainsReplacesChainsKeepsSettingsAndBacksUp(t *testing.T) {
	c, dir, file := chainsFixture(t, `{"mayor":["claude:opus"],"polecat":["claude:sonnet","claude:haiku"]}`)
	code, out, errOut := runChains(c, file)
	if code != 0 {
		t.Fatalf("exit %d: %s", code, errOut)
	}
	if !strings.Contains(out, "chains updated") {
		t.Fatalf("missing update report: %q", out)
	}
	var got SwarmConfig
	if err := json.Unmarshal([]byte(readFile(t, filepath.Join(dir, "swarm.json"))), &got); err != nil {
		t.Fatal(err)
	}
	if strings.Join(got.Chains["mayor"], ",") != "claude:opus" || strings.Join(got.Chains["polecat"], ",") != "claude:sonnet,claude:haiku" {
		t.Fatalf("chains not applied: %v", got.Chains)
	}
	if got.Repo != "/repo" || got.DoltPort != 45901 || got.MaxPolecats != 2 || got.Base != "main" ||
		strings.Join(got.Checks, ",") != "go test ./..." || strings.Join(got.Protect, ",") != "main.go" {
		t.Fatalf("other settings changed: %+v", got)
	}
	if backup := readFile(t, filepath.Join(dir, "swarm.json.before-profile")); backup != chainsSwarmJSON {
		t.Fatalf("backup must hold the previous file, got %q", backup)
	}
}

func TestSwarmChainsLeavesAnUnchangedSwarmUntouched(t *testing.T) {
	c, dir, file := chainsFixture(t, `{"mayor":["claude:sonnet"],"polecat":["claude:sonnet"]}`)
	code, out, errOut := runChains(c, file)
	if code != 0 {
		t.Fatalf("exit %d: %s", code, errOut)
	}
	if !strings.Contains(out, "chains unchanged") {
		t.Fatalf("missing unchanged report: %q", out)
	}
	if readFile(t, filepath.Join(dir, "swarm.json")) != chainsSwarmJSON {
		t.Fatal("an unchanged swarm must keep its exact bytes")
	}
	if _, err := os.Stat(filepath.Join(dir, "swarm.json.before-profile")); !os.IsNotExist(err) {
		t.Fatalf("no backup expected, stat err %v", err)
	}
}

func TestSwarmChainsRejectsInvalidChainsWithoutWriting(t *testing.T) {
	for name, chains := range map[string]string{
		"bad spec":       `{"mayor":["claude:opus"],"polecat":["codex:gpt-6.1-sol"]}`,
		"unknown kind":   `{"mayor":["gemini:pro"],"polecat":["claude:haiku"]}`,
		"missing mayor":  `{"polecat":["claude:haiku"]}`,
		"empty polecats": `{"mayor":["claude:opus"],"polecat":[]}`,
		"not json":       `mayor=claude:opus`,
	} {
		t.Run(name, func(t *testing.T) {
			c, dir, file := chainsFixture(t, chains)
			if code, _, errOut := runChains(c, file); code == 0 || errOut == "" {
				t.Fatalf("expected a failure with a message, got exit %d %q", code, errOut)
			}
			if readFile(t, filepath.Join(dir, "swarm.json")) != chainsSwarmJSON {
				t.Fatal("a rejected chains file must not modify swarm.json")
			}
		})
	}
}

func TestSwarmChainsIgnoresRoleKeyOrder(t *testing.T) {
	c, dir, file := chainsFixture(t, `{"polecat":["claude:sonnet"],"mayor":["claude:sonnet"]}`)
	code, out, errOut := runChains(c, file)
	if code != 0 || !strings.Contains(out, "chains unchanged") {
		t.Fatalf("exit %d out %q err %q", code, out, errOut)
	}
	if readFile(t, filepath.Join(dir, "swarm.json")) != chainsSwarmJSON {
		t.Fatal("equal chains in another key order must not rewrite swarm.json")
	}
}

func TestSwarmChainsTreatsPolecatOrderAsAChange(t *testing.T) {
	c, dir, file := chainsFixture(t, `{"mayor":["claude:sonnet"],"polecat":["claude:haiku","claude:sonnet"]}`)
	if err := os.WriteFile(filepath.Join(dir, "swarm.json"), []byte(strings.Replace(chainsSwarmJSON, `"polecat": ["claude:sonnet"]`, `"polecat": ["claude:sonnet", "claude:haiku"]`, 1)), 0o600); err != nil {
		t.Fatal(err)
	}
	code, out, errOut := runChains(c, file)
	if code != 0 || !strings.Contains(out, "chains updated") {
		t.Fatalf("polecat order is the fallback order and must count as a change: exit %d out %q err %q", code, out, errOut)
	}
}

func TestSwarmChainsAcceptsTheThreeProviderTiersThroughOpenCode(t *testing.T) {
	c, dir, file := chainsFixture(t, `{"mayor":["opencode:anthropic/claude-sonnet-5-5","opencode:openai/gpt-6.1-sol:medium","opencode:ollama-cloud/deepseek-v4-pro"],"polecat":["opencode:anthropic/claude-haiku-5-5","opencode:openai/gpt-6.1-terra:low","opencode:ollama-cloud/minimax-m3.1-flash"]}`)
	if code, _, errOut := runChains(c, file); code != 0 {
		t.Fatalf("exit %d: %s", code, errOut)
	}
	var got SwarmConfig
	if err := json.Unmarshal([]byte(readFile(t, filepath.Join(dir, "swarm.json"))), &got); err != nil {
		t.Fatal(err)
	}
	if len(got.Chains["mayor"]) != 3 || len(got.Chains["polecat"]) != 3 {
		t.Fatalf("every provider must stay in its chain: %v", got.Chains)
	}
}
