// This test is copied inside the tagged upstream module by render.nix. It is a
// build-only exporter, not an operational CLI or a second rendering authority.
package nixexport

import (
	"context"
	"encoding/json"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"

	"github.com/gentleman-programming/gentle-ai/v4/internal/agents"
	"github.com/gentleman-programming/gentle-ai/v4/internal/assets"
	"github.com/gentleman-programming/gentle-ai/v4/internal/components/agentguidance"
	"github.com/gentleman-programming/gentle-ai/v4/internal/components/filemerge"
	"github.com/gentleman-programming/gentle-ai/v4/internal/components/opencodeagents"
	"github.com/gentleman-programming/gentle-ai/v4/internal/components/reviewassets"
	"github.com/gentleman-programming/gentle-ai/v4/internal/model"
	"github.com/gentleman-programming/gentle-ai/v4/internal/opencode"
)

func exportText(t *testing.T, root, path, text string) {
	t.Helper()
	if strings.Contains(text, "{{GENTLE_AI_") || (strings.HasPrefix(path, "claude/") && strings.Contains(text, "{{")) {
		t.Fatalf("unrendered managed placeholder in %s", path)
	}
	destination := filepath.Join(root, filepath.FromSlash(path))
	if err := os.MkdirAll(filepath.Dir(destination), 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(destination, []byte(text), 0644); err != nil {
		t.Fatal(err)
	}
}

func requireNativeV2() error {
	major, err := opencode.DetectRuntimeMajor(context.Background())
	if err != nil || major != opencode.RuntimeV2 {
		return fmt.Errorf("truthful native OpenCode V2 discovery required: major=%v error=%v", major, err)
	}
	return nil
}

func TestNativeV2DiscoveryRefusesMissingExecutable(t *testing.T) {
	t.Setenv("PATH", t.TempDir())
	if err := requireNativeV2(); err == nil {
		t.Fatal("an absent native runtime must not render a V2 review contract")
	}
}

func TestExportManagedPrompts(t *testing.T) {
	root := os.Getenv("GENTLE_AI_RENDER_OUTPUT")
	if root == "" {
		t.Fatal("GENTLE_AI_RENDER_OUTPUT must name the disposable build output")
	}
	// ReviewExecutionContractFor probes the runtime to choose native V2 tool
	// names. Never render against an absent runtime or a fabricated version.
	if err := requireNativeV2(); err != nil {
		t.Fatal(err)
	}
	graph := map[string]any{}
	for _, spec := range opencodeagents.Parity(model.AgentOpenCode) {
		entry, err := opencodeagents.Entry(spec)
		if err != nil {
			t.Fatal(err)
		}
		prompt, _ := reviewassets.RenderReviewerAsset("opencode/agents/"+spec.Name+".md", entry["prompt"].(string))
		entry["prompt"] = prompt
		exportText(t, root, "opencode/agents/"+spec.Name+".md", prompt)
		graph[spec.Name] = entry
	}
	graph["review-refuter"] = opencodeagents.Refuter()
	graph["review-validator"] = opencodeagents.Validator()
	for _, runtime := range []struct {
		id   model.AgentID
		path string
	}{{model.AgentOpenCode, "opencode"}, {model.AgentClaudeCode, "claude"}} {
		orchestrator, err := agentguidance.RenderOrchestratorWithSource(runtime.id, reviewassets.ReviewExecutionContractFor, "")
		if err != nil {
			t.Fatal(err)
		}
		routing, err := agentguidance.RenderRouting(runtime.id)
		if err != nil {
			t.Fatal(err)
		}
		prompt := orchestrator + "\n\n" + routing
		for _, required := range []string{"Organic Driven Development", "odd/tasks/<feature-name>.md", "odd/<feature-name>/tasks", "Review Execution Contract"} {
			if !strings.Contains(prompt, required) {
				t.Fatalf("%s missing canonical %q", runtime.path, required)
			}
		}
		if runtime.id == model.AgentOpenCode {
			if !strings.Contains(prompt, "`subagent`") || strings.Contains(prompt, "`subagent_type`") {
				t.Fatal("OpenCode contract was not rendered for native V2")
			}
			graph["gentle-orchestrator"] = map[string]any{
				"mode": "primary", "description": "Organic Driven Development coordinator", "prompt": prompt,
			}
		}
		exportText(t, root, runtime.path+"/orchestrator.md", prompt)
	}
	// Match reviewassets.renderNativeAgent for the fixed Claude assignments.
	adapter, err := agents.NewAdapter(model.AgentClaudeCode)
	if err != nil {
		t.Fatal(err)
	}
	claudeModels := map[string]model.ClaudeModelAlias{"review-refuter": model.ClaudeModelOpus, "jd-judge-a": model.ClaudeModelSonnet, "jd-judge-b": model.ClaudeModelSonnet, "jd-fix-agent": model.ClaudeModelSonnet, "review-risk": model.ClaudeModelSonnet, "review-readability": model.ClaudeModelSonnet, "review-reliability": model.ClaudeModelSonnet, "review-resilience": model.ClaudeModelSonnet}
	err = fs.WalkDir(assets.FS, "claude/agents", func(path string, entry fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if entry.IsDir() || !strings.HasSuffix(path, ".md") {
			return nil
		}
		text, err := assets.Read(path)
		if err != nil {
			return err
		}
		if prompt, reviewer := reviewassets.RenderReviewerAsset(path, text); reviewer {
			text = prompt
		}
		name := strings.TrimSuffix(filepath.Base(path), ".md")
		if strings.HasPrefix(name, "jd-judge-") {
			text = replaceJudgmentSection(text, reviewassets.JudgmentDayReviewerContract())
		}
		if cmr, ok := adapter.(interface {
			ClaudeModelID(model.ClaudeModelAlias) string
		}); ok {
			text = strings.ReplaceAll(text, "{{CLAUDE_MODEL}}", cmr.ClaudeModelID(claudeModels[name]))
			text = strings.ReplaceAll(text, "{{CLAUDE_EFFORT_FRONTMATTER}}\r\n", "")
			text = strings.ReplaceAll(text, "{{CLAUDE_EFFORT_FRONTMATTER}}\n", "")
		}
		// Upstream (install.go:268) expands {{ENGRAM_TOOL_PREFIX}} to both prefixes; the
		// shipped agents hardcode the plugin prefix, so grant the MCP-server prefix too.
		text = regexp.MustCompile(`\{\{ENGRAM_TOOL_PREFIX\}\}([A-Za-z0-9_]+)`).ReplaceAllString(text, "mcp__engram__$1, mcp__plugin_engram_engram__$1")
		text = regexp.MustCompile(`(^|[ ,\[])mcp__plugin_engram_engram__([A-Za-z0-9_]+)`).ReplaceAllString(text, "${1}mcp__engram__$2, mcp__plugin_engram_engram__$2")
		text = reviewassets.InjectCodeGraphToolGrant(text, model.AgentClaudeCode, "")
		text = filemerge.InjectMarkdownSection(text, "agent-language-contract", strings.TrimSpace(assets.MustRead("generic/agent-language-contract.md")))
		text = agentguidance.InjectRemoteAuthorization(text)
		exportText(t, root, path, text)
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
	protocol := filemerge.ExtractHTMLCommentSection(assets.MustRead("engram/protocol.md"), "full")
	exportText(t, root, "claude/engram-protocol.md", protocol)
	for _, style := range []struct{ source, output string }{{"claude/output-style-neutral.md", "claude/output-styles/neutral.md"}, {"claude/output-style-gentleman.md", "claude/output-styles/gentleman.md"}} {
		text, err := assets.Read(style.source)
		if err != nil {
			t.Fatal(err)
		}
		exportText(t, root, style.output, text)
	}
	if len(graph) != 13 {
		t.Fatalf("unexpected tagged managed graph: %d agents", len(graph))
	}
	for name, raw := range graph {
		if strings.HasPrefix(name, "sdd-") {
			t.Fatalf("retired SDD agent in canonical graph: %s", name)
		}
		entry := raw.(map[string]any)
		if _, exists := entry["tools"]; exists {
			t.Fatalf("deprecated tools grants in %s", name)
		}
	}
	encoded, err := json.MarshalIndent(map[string]any{"agent": graph}, "", "  ")
	if err != nil {
		t.Fatal(err)
	}
	exportText(t, root, "opencode/odd-overlay.json", string(encoded)+"\n")
}

// replaceJudgmentSection mirrors reviewassets.replaceJudgmentSection (install.go:339-346).
func replaceJudgmentSection(content, body string) string {
	const heading = "## Review ledger contract"
	start := strings.Index(content, heading)
	if start < 0 {
		return content
	}
	return strings.TrimRight(content[:start], "\n") + "\n\n" + heading + "\n\n" + body + "\n\n"
}
