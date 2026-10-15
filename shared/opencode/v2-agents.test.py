"""Offline ODD graph/provider regression: python3 shared/opencode/v2-agents.test.py."""
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
BASELINE = "4750736cd68f517a871ac7448639c94546472390"
old_profiles = json.dumps(subprocess.check_output(
    ["git", "show", f"{BASELINE}:shared/opencode/providers-base.nix"], cwd=ROOT, text=True
)).replace("${", r"\${")
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
  before = import (builtins.toFile "before-odd-profiles.nix" OLD_PROFILES) { inherit lib; };
  overrideConfig = config // { home = config.home // { opencode = cfg // {
    agentOverrides.gentle-ai-worker = { model = "openai/user-override"; variant = "high"; prompt = "user prompt"; };
  }; }; };
in {
  linux = generate "/home/glats/.config/opencode-v2";
  darwinRoot = generate "/Users/juan/.config/opencode-v2";
  beforeProfiles = before.providers;
  afterProfiles = profiles.providers;
  beforePolicy = before.providerAllowlist;
  afterPolicy = profiles.providerAllowlist;
  nvidiaBefore = before.nvidiaProvider;
  nvidiaAfter = profiles.nvidiaProvider;
  globalPermissions = permissions.global;
  overrides = (import (ROOT + "/shared/opencode/agents.nix") {
    inherit lib pkgs; config = overrideConfig;
  }).config.home.opencode.agents.gentle-ai-worker;
}
'''.replace("ROOT", json.dumps(str(ROOT))).replace("OLD_PROFILES", old_profiles)
result = json.loads(subprocess.check_output(
    ["nix", "eval", "--offline", "--impure", "--json", "--expr", expression], cwd=ROOT, text=True
))
expected = {
    "gentle-orchestrator", "gentle-ai-explore", "gentle-ai-verify", "gentle-ai-worker",
    "jd-judge-a", "jd-judge-b", "jd-fix-agent", "review-risk", "review-readability",
    "review-reliability", "review-resilience", "review-refuter", "review-validator",
}
for target, root in (("linux", "/home/glats/.config/opencode-v2"),
                     ("darwinRoot", "/Users/juan/.config/opencode-v2")):
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
    assert {"action":"subagent", "resource":"*", "effect":"deny"} in agents["general"]["permissions"]
before = {p["name"]:p for p in result["beforeProfiles"]}
after = {p["name"]:p for p in result["afterProfiles"]}
retired = {"opencode-free", "anthropic-opencode-free", "anthropic-opencode-go"}
assert len(before) == 35 and len(after) == 32
assert after.keys() == before.keys() - retired
assert [p["name"] for p in result["afterProfiles"]] == [
    p["name"] for p in result["beforeProfiles"] if p["name"] not in retired
]
for name, profile in before.items():
    if name in retired:
        continue
    phases = profile["phases"]
    mapped = {k:v for k,v in phases.items() if not k.startswith("sdd-")}
    mapped.update({"gentle-ai-explore":phases["sdd-explore"],
                   "gentle-ai-worker":phases["sdd-apply"], "gentle-ai-verify":phases["sdd-verify"]})
    assert after[name] == {**profile,"phases":mapped}, f"Unapproved routing churn: {name}"
assert result["beforePolicy"] == result["afterPolicy"]
expected_nvidia = json.loads(json.dumps(result["nvidiaBefore"]))
expected_nvidia["nvidia"]["models"]["nemotron-3-ultra-550b-a55b"] = {
    "name": "Nemotron 3 Ultra",
    "modelID": "nvidia/nemotron-3-ultra-550b-a55b",
}
assert result["nvidiaAfter"] == expected_nvidia
assert result["overrides"]["model"] == "openai/user-override"
assert result["overrides"]["variant"] == "high" and result["overrides"]["prompt"] == "user prompt"
assert any(p["action"].startswith("github-personal_") and p["effect"] == "deny"
           for p in result["globalPermissions"])
print("PASS: ODD graph, executor grants, three approved retirements, remaining full-JSON parity, provider policy, same-backend NVIDIA alias and last-wins overrides")
print("PASS: complete rendered recovery guidance; LIMIT: contract presence does not prove LLM readback/outage/conflict compliance")
