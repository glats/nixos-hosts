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
	"strings"
	"testing"

	"github.com/gentleman-programming/gentle-ai/v4/internal/assets"
	"github.com/gentleman-programming/gentle-ai/v4/internal/components/agentguidance"
	"github.com/gentleman-programming/gentle-ai/v4/internal/components/opencodeagents"
	"github.com/gentleman-programming/gentle-ai/v4/internal/components/reviewassets"
	"github.com/gentleman-programming/gentle-ai/v4/internal/model"
	"github.com/gentleman-programming/gentle-ai/v4/internal/opencode"
)

func exportText(t *testing.T, root, path, text string) {
	t.Helper()
	if strings.Contains(text, "{{GENTLE_AI_") {
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
	// Claude consumes file assets, not the OpenCode JSON graph. Preserve its
	// frontmatter and let the upstream runtime-specific reviewer renderer own
	// the prompt. Other Claude agent bodies are already complete source assets.
	err := fs.WalkDir(assets.FS, "claude/agents", func(path string, entry fs.DirEntry, err error) error {
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
		text, _ = reviewassets.RenderReviewerAsset(path, text)
		exportText(t, root, path, text)
		return nil
	})
	if err != nil {
		t.Fatal(err)
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
