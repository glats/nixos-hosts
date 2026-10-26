"""Check shared AI tool availability without an enabled OpenCode client."""

import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
expression = r'''
let
  flake = builtins.getFlake ("path:" + ROOT);
  lib = flake.inputs.nixpkgs.lib;
  home = flake.homeConfigurations.rog;
  claudeOnly = home.extendModules {
    modules = [{ home.opencode.enable = lib.mkForce false; }];
  };
  packages = config: map (p: p.pname or p.name) config.home.packages;
in {
  both = packages home.config;
  claude = packages claudeOnly.config;
  telemetry = claudeOnly.config.home.sessionVariables.RTK_TELEMETRY_DISABLED or null;
}
'''.replace("ROOT", json.dumps(str(ROOT)))
result = json.loads(subprocess.check_output(
    ["nix", "eval", "--offline", "--impure", "--json", "--expr", expression],
    cwd=ROOT, text=True,
))
for client in ("both", "claude"):
    for package in ("engram", "rtk", "poppler-utils"):
        assert package in result[client], (client, package)
assert "gentle-ai-managed" in result["both"]
assert "opencode-managed" in result["both"]
assert "gentle-ai" in result["claude"]
assert "opencode-managed" not in result["claude"]
assert result["telemetry"] == "1"
print("PASS: shared tools survive disabling OpenCode; client wrappers remain scoped")
