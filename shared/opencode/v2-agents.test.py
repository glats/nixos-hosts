"""Offline ODD graph/provider regression: python3 shared/opencode/v2-agents.test.py."""
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
expression = r'''
let
  flake = builtins.getFlake ("path:" + ROOT);
  config = flake.homeConfigurations.rog.config;
  pkgs = flake.nixosConfigurations.rog.pkgs;
  lib = pkgs.lib;
  cfg = config.home.opencode;
  permissions = import (ROOT + "/shared/opencode/v2-permissions.nix") {
    inherit lib cfg; disabledTools = cfg.disabledTools;
  };
  generate = runtimeDir: import (ROOT + "/shared/opencode/v2-agents.nix") {
    inherit lib cfg runtimeDir; permissionRules = permissions.rules;
  };
  profiles = import (ROOT + "/shared/opencode/providers-base.nix") { inherit lib; };
  overrideConfig = config // { home = config.home // { opencode = cfg // {
    agentOverrides.gentle-ai-worker = { model = "openai/user-override"; variant = "high"; prompt = "user prompt"; };
  }; }; };
in {
  linux = generate "/home/glats/.config/opencode";
  darwinRoot = generate "/Users/juan/.config/opencode";
  afterProfiles = profiles.providers;
  nvidiaAfter = profiles.nvidiaProvider;
  globalPermissions = permissions.global;
  overrides = (import (ROOT + "/shared/opencode/agents.nix") {
    inherit lib pkgs; config = overrideConfig;
  }).config.home.opencode.agents.gentle-ai-worker;
}
'''.replace("ROOT", json.dumps(str(ROOT)))
result = json.loads(subprocess.check_output(
    ["nix", "eval", "--offline", "--impure", "--json", "--expr", expression], cwd=ROOT, text=True
))
expected = {
    "gentle-orchestrator", "gentle-ai-explore", "gentle-ai-verify", "gentle-ai-worker",
    "jd-judge-a", "jd-judge-b", "jd-fix-agent", "review-risk", "review-readability",
    "review-reliability", "review-resilience", "review-refuter", "review-validator",
}
for target, root in (("linux", "/home/glats/.config/opencode"),
                     ("darwinRoot", "/Users/juan/.config/opencode")):
    agents = result[target]
    assert not any(name.startswith("sdd-") for name in agents), "Candidate still carries SDD graph"
    assert expected <= agents.keys(), "Missing tagged ODD/review roles"
    for name in expected:
        system = agents[name]["system"]
        assert "{{GENTLE_AI_" not in system, name
        assert "tools" not in agents[name], name
        assert "live direct tool names and input schemas" in system, name
        assert f"{root}/skills" in system, name
        assert "Explicit user instructions and repository policy override" in system, name
        if name != "gentle-orchestrator":
            assert {"action":"subagent", "resource":"*", "effect":"deny"} in agents[name]["permissions"], name
    system = agents["gentle-orchestrator"]["system"]
    assert "Organic Driven Development" in system
    assert "odd/tasks/<feature-name>.md" in system and "odd/<feature-name>/tasks" in system
    # These are rendered model instructions, not executable storage guarantees.
    for contract in (
        "stable task IDs", "Reuse the same feature identity; never overwrite another feature",
        "Mirror the full current document and repository-relative file locator",
        "Read back both writes; they are not atomic",
        "If Engram is unavailable, preserve local progress and explicitly mark the mirror pending",
        "Preserve both versions on irreconcilable edits",
        "mem_context", "mem_search", "mem_get_observation",
        "read the actual task file", "preserve pending mirrors and conflicting edits",
        "before the first source write", "Never bulk-convert",
    ):
        assert contract in system, f"{target}: missing rendered recovery/selection contract {contract!r}"
    for name in ("gentle-ai-explore", "gentle-ai-verify", "review-refuter", "review-validator"):
        assert {"action":"edit", "resource":"*", "effect":"deny"} in agents[name]["permissions"], name
    assert {"action":"shell", "resource":"*", "effect":"deny"} in agents["gentle-ai-explore"]["permissions"]
    # Only Gentle AI roles: built-in explore/general would inherit the orchestrator model.
    assert "general" not in agents and "explore" not in agents
    granted = {p["resource"] for p in agents["gentle-orchestrator"]["permissions"]
               if p["action"] == "subagent" and p["effect"] == "allow"}
    assert granted == {"gentle-ai-*", "jd-*", "review-*"}, granted
after = {p["name"]:p for p in result["afterProfiles"]}
for name, profile in after.items():
    assert "phases" not in profile and not any(k.startswith("sdd-") for k in profile["roles"]), name
approved_addition = "anthropic-openai-opencode"
approved = after[approved_addition]
assert approved["roles"] == {
    "gentle-orchestrator": "anthropic/claude-opus-5-5",
    "gentle-ai-explore": "opencode-go/glm-5.3-flash",
    "gentle-ai-worker": "openai/gpt-6-luna",
    "gentle-ai-verify": "openai/gpt-6.1-sol",
    "jd-judge-a": "anthropic/claude-sonnet-5-5",
    "jd-judge-b": "anthropic/claude-sonnet-5-5",
    "jd-fix-agent": "opencode-go/glm-5.3-flash",
    "review-readability": "opencode-go/deepseek-v4-pro",
    "review-refuter": "opencode-go/deepseek-v4-pro",
    "review-reliability": "opencode-go/deepseek-v4-pro",
    "review-resilience": "opencode-go/deepseek-v4-pro",
    "review-risk": "opencode-go/deepseek-v4-pro",
    "review-validator": "opencode-go/deepseek-v4-pro",
    "neutral": "anthropic/claude-opus-5-5",
}, "Approved profile's provider/role shape changed"
assert result["nvidiaAfter"]["nvidia"]["models"]["nemotron-3-ultra-550b-a55b"] == {
    "name": "Nemotron 3 Ultra",
    "modelID": "nvidia/nemotron-3-ultra-550b-a55b",
}
assert result["overrides"]["model"] == "openai/user-override"
assert result["overrides"]["variant"] == "high" and result["overrides"]["prompt"] == "user prompt"
assert any(p["action"].startswith("github-personal_") and p["effect"] == "deny"
           for p in result["globalPermissions"])
print("PASS: ODD graph, executor grants, role-keyed profiles, NVIDIA alias and last-wins overrides")
print("PASS: complete rendered recovery guidance; LIMIT: contract presence does not prove LLM readback/outage/conflict compliance")
