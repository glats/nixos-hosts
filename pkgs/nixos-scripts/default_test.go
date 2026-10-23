package nixosscripts

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestDefaultNixDoesNotBuildStaleLauncherCommand(t *testing.T) {
	defaultNix, err := os.ReadFile(filepath.Join("default.nix"))
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(string(defaultNix), `"cmd/opencode-`+`v2"`) {
		t.Fatal("default.nix still builds the stale versioned launcher command")
	}
}

func TestDefaultNixBuildsComplianceModeCommand(t *testing.T) {
	defaultNix, err := os.ReadFile(filepath.Join("default.nix"))
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(defaultNix), `"cmd/compliance-mode"`) {
		t.Fatal("default.nix does not build the cmd/compliance-mode subPackage")
	}
}
