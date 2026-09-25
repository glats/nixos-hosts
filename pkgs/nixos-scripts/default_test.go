package nixosscripts

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestDefaultNixDoesNotBuildStaleOpenCode2Launcher(t *testing.T) {
	defaultNix, err := os.ReadFile(filepath.Join("default.nix"))
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(string(defaultNix), `"cmd/opencode2"`) {
		t.Fatal("default.nix still builds the stale cmd/opencode2 Docker launcher")
	}
}
