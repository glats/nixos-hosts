"""Evaluate neutral skill deployment without importing an OpenCode module."""

import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
expression = r'''
let
  f = builtins.getFlake ("path:" + ROOT);
  pkgs = f.nixosConfigurations.rog.pkgs;
  make = modules: (f.inputs.home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    extraSpecialArgs = { inherit (f) inputs; };
    modules = [
      (ROOT + "/shared/codex.nix")
      {
        home.username = "test";
        home.homeDirectory = "/home/test";
        home.stateVersion = "26.05";
      }
    ] ++ modules;
  }).config;
  codex = make [{ home.codex.enable = true; }];
  shared = make [{ home.ai-assets.enable = true; }];
  disabled = make [];
  inspect = c: {
    enabled = c.home.ai-assets.enable;
    deployment = c.home.activation.deploySharedAgentSkills or null;
    packages = map (p: p.pname or p.name) c.home.packages;
  };
in {
  codex = inspect codex;
  shared = inspect shared;
  disabled = inspect disabled;
  revision = f.inputs.gentle-ai-src.rev;
  prompt = codex.home.file.".codex/AGENTS.md".text;
}
'''.replace("ROOT", json.dumps(str(ROOT)))
result = json.loads(subprocess.check_output(
    ["nix", "eval", "--offline", "--impure", "--json", "--expr", expression],
    cwd=ROOT, text=True,
))
for name in ("codex", "shared"):
    client = result[name]
    assert client["enabled"], name
    assert client["deployment"] is not None, name
    deployment = client["deployment"]
    assert "linkGeneration" in deployment["after"], name
    assert '"/home/test/.agents"' in deployment["data"], name
    assert deployment["data"].count("/bin/ai-assets-reconcile ") == 1, name
    assert result["revision"] in deployment["data"], name
    assert "opencode" not in deployment["data"], name
    assert {"engram", "rtk", "gentle-ai"} <= set(client["packages"]), name
assert not result["disabled"]["enabled"]
assert result["disabled"]["deployment"] is None
assert "## Repository authorization boundary" in result["prompt"]
print("PASS: neutral skills and tools deploy for Codex-only and shared-only configurations")
