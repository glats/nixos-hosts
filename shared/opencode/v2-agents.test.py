"""Offline generated-system regression: python3 shared/opencode/v2-agents.test.py."""

import json
from pathlib import Path
import subprocess


ROOT = Path(__file__).resolve().parents[2]
PHASES = {
    "init", "explore", "research", "propose", "spec", "design", "tasks",
    "apply", "verify", "archive", "onboard",
}


# Evaluate the real managed graph and runtime assembly, with writeText returning
# its contents instead of building or activating anything. Pin the pre-fix
# generator for exact V1-output and non-system-field preservation checks.
BASELINE = "d2ebad2613ddbbaa8304c091c3892100970b3cb5"


def baseline_source(path):
    return json.dumps(subprocess.check_output(
        ["git", "show", f"{BASELINE}:{path}"], cwd=ROOT, text=True
    ), ensure_ascii=False).replace("${", r"\${")


expression = r'''
let
  flake = builtins.getFlake ROOT;
  config = flake.homeConfigurations.rog.config;
  pkgs = flake.nixosConfigurations.rog.pkgs;
  lib = pkgs.lib;
  cfg = config.home.opencode;
  permissions = import (ROOT + "/shared/opencode/v2-permissions.nix") {
    inherit lib cfg; disabledTools = cfg.disabledTools;
  };
  oldPermissions = import (builtins.toFile "baseline-v2-permissions.nix" OLD_PERMISSIONS) {
    inherit lib cfg; disabledTools = cfg.disabledTools;
  };
  oldAgents = import (builtins.toFile "baseline-v2-agents.nix" OLD_AGENTS) {
    inherit lib cfg; permissionRules = oldPermissions.rules;
  };
  generate = runtimeDir: import (ROOT + "/shared/opencode/v2-agents.nix") {
    inherit lib cfg runtimeDir; permissionRules = permissions.rules;
  };
  runtimeArgs = {
    inherit config lib cfg;
    pkgs = pkgs // { writeText = _: text: text; };
    providers = import (ROOT + "/shared/opencode/providers.nix") {
      inherit lib; activeProviderName = cfg.activeProviderName;
    };
    runtimeConfig = { version = "v1"; dir = "opencode"; label = "test"; };
  };
  runtime = source: (import source runtimeArgs).home.file;
  probeCfg = cfg // { agents.probe = {
    prompt = "~/.config/opencode/skills/probe/SKILL.md bash openspec/changes/probe/";
  }; agents.sdd-probe = {
    prompt = "~/.config/opencode/skills/sdd-probe/SKILL.md bash openspec/changes/probe/";
  }; };
in {
  inherit oldAgents;
  linux = generate "/home/glats/.config/opencode-v2";
  darwinRoot = generate "/Users/juan/.config/opencode-v2";
  v1Before = runtime (builtins.toFile "baseline-runtime.nix" OLD_RUNTIME);
  v1After = runtime (ROOT + "/shared/opencode/runtime-config.nix");
  assembledV2 = builtins.fromJSON ((import (ROOT + "/shared/opencode/runtime-config.nix")
    (runtimeArgs // {
      runtimeConfig = { version = "v2"; dir = "opencode-v2"; label = "test"; };
    })).home.file.".config/opencode-v2/opencode.json".source);
  globalPermissions = permissions.global;
  oldGlobalPermissions = oldPermissions.global;
  disabledTools = cfg.disabledTools;
  probe = import (ROOT + "/shared/opencode/v2-agents.nix") {
    inherit lib; cfg = probeCfg; permissionRules = permissions.rules;
    runtimeDir = "/custom/runtime";
  };
}
'''.replace("ROOT", json.dumps(str(ROOT))).replace(
    "OLD_AGENTS", baseline_source("shared/opencode/v2-agents.nix")
).replace("OLD_RUNTIME", baseline_source("shared/opencode/runtime-config.nix")).replace(
    "OLD_PERMISSIONS", baseline_source("shared/opencode/v2-permissions.nix")
)

result = json.loads(subprocess.check_output(
    ["nix", "eval", "--offline", "--impure", "--json", "--expr", expression],
    cwd=ROOT, text=True,
))
assert result["v1Before"] == result["v1After"], "V1 runtime output changed"
assert result["assembledV2"]["agents"] == result["linux"], "Runtime directory wiring changed"
assert result["assembledV2"]["permissions"] == result["globalPermissions"]
denies = [
    {"action": tool, "resource": "*", "effect": "deny"}
    for tool in result["disabledTools"]
]
assert result["globalPermissions"] == (
    denies + result["oldGlobalPermissions"][len(denies):]
), "MCP names changed or unrelated global rules changed"
assert any(rule["action"].startswith("github-personal_") for rule in denies)
expected = {f"sdd-{phase}" for phase in PHASES}
for target, root in (
    ("linux", "/home/glats/.config/opencode-v2/skills"),
    ("darwinRoot", "/Users/juan/.config/opencode-v2/skills"),
):
    agents = result[target]
    assert {name for name in agents if name.startswith("sdd-")} == expected
    for name, old in result["oldAgents"].items():
        new = agents[name]
        if name not in expected:
            assert new == old, name
            continue
        assert {k: v for k, v in new.items() if k != "system"} == {
            k: v for k, v in old.items() if k != "system"
        }, f"Non-system fields changed: {name}"
        system = new["system"]
        assert f"{root}/{name}/SKILL.md" in system, name
        assert "~/.config/opencode/skills/" not in system, name
        assert system.endswith(old["system"].replace("~/.config/opencode/skills/", root + "/"))
        for guidance in (
            "live direct tool names and input schemas",
            "read({path, offset?, limit?})",
            "shell({command, workdir?, timeout?, background?}) only when allowed",
            "bash-to-shell permission mapping is not a tool alias",
            "Direct shell and read are not Code Mode catalog tools",
            "execute({code})", "synchronous", "without await",
            "search({query?, namespace?, limit?, offset?})",
            "returned exact callable paths and signatures",
            f"under {root}/_shared/...",
            "Keep repository-relative openspec/... artifact paths relative to the repository",
        ):
            assert guidance in system, (name, guidance)
    assert any(rule == {"action": "shell", "resource": "*", "effect": "deny"}
               for rule in agents["sdd-research"]["permissions"])
    for action in ("context7_resolve-library-id", "context7_query-docs"):
        assert {"action": action, "resource": "*", "effect": "allow"} in (
            agents["sdd-research"]["permissions"]
        ), f"Missing effective MCP action: {action}"
    assert not any(rule["action"] in (
        "context7_resolve_library_id", "context7_query_docs"
    ) for rule in agents["sdd-research"]["permissions"])
assert result["probe"]["probe"]["system"] == (
    "~/.config/opencode/skills/probe/SKILL.md bash openspec/changes/probe/"
)
assert result["probe"]["sdd-probe"]["system"].endswith(
    "/custom/runtime/skills/sdd-probe/SKILL.md bash openspec/changes/probe/"
), "Broad bash replacement or artifact-path rewrite"
print("PASS: 11 SDD systems, runtime/shared roots, direct/Code Mode contract, V1 output, effective MCP permissions and research deny")
