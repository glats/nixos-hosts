"""Offline regression for the OpenCode HM runtime, launchers and MCP hygiene."""

import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
expression = f'''
let
  flake = builtins.getFlake {json.dumps("path:" + str(ROOT))};
  home = flake.homeConfigurations.rog.config;
  pkg = name: (builtins.head (builtins.filter (p: p.name == name) home.home.packages)).outPath;
in {{
  inherit (home.programs.zsh) initContent;
  oc = builtins.fromJSON (builtins.unsafeDiscardStringContext (builtins.readFile (builtins.getAttr ".config/opencode/opencode.json" home.home.file).source));
  quotaConfig = (builtins.getAttr ".config/opencode/opencode-quota/quota-toast.jsonc" home.home.file).text;
  quotaPlugins = builtins.mapAttrs (_: h: h.home.opencode.quotaPlugin != null) {{
    thinkcentre = flake.homeConfigurations.thinkcentre.config;
    t14 = flake.homeConfigurations.t14.config;
    macm5Home = flake.homeConfigurations.macm5.config;
    macm5Darwin = flake.darwinConfigurations.macm5.config.home-manager.users.juan;
  }};
  activationNames = builtins.attrNames home.home.activation;
  migrateBefore = home.home.activation.migrateOpencodeLayout.before;
  migrateData = home.home.activation.migrateOpencodeLayout.data;
  openfangAfter = home.home.activation.syncOpencodeSkillsToOpenfang.after;
  openfangData = home.home.activation.syncOpencodeSkillsToOpenfang.data;
  setupData = home.home.activation.setupOpencodePluginRuntime.data;
  profileDirectory = home.home.profileDirectory;
  gentleWrapper = pkg "gentle-ai-managed";
  opencodeWrapper = pkg "opencode-managed";
  nativeBinary = (toString flake.nixosConfigurations.rog.pkgs.opencode) + "/bin/opencode";
  username = home.home.username;
  profiles = (import (flake.outPath + "/shared/opencode/providers-base.nix") {{
    lib = flake.inputs.nixpkgs.lib;
  }}).providers;
  selectedProfiles = {{
    rog = home.home.opencode.activeProviderName;
    thinkcentre = flake.homeConfigurations.thinkcentre.config.home.opencode.activeProviderName;
    t14 = flake.homeConfigurations.t14.config.home.opencode.activeProviderName;
    macm5Home = flake.homeConfigurations.macm5.config.home.opencode.activeProviderName;
    macm5Darwin = flake.darwinConfigurations.macm5.config.home-manager.users.juan.home.opencode.activeProviderName;
  }};
}}
'''
result = json.loads(subprocess.check_output(
    ["nix", "eval", "--offline", "--impure", "--json", "--expr", expression],
    cwd=ROOT, text=True,
))
source = (ROOT / "shared/shell-aliases.nix").read_text()
assert not any("restart" in name.lower() and "opencode" in name.lower() for name in result["activationNames"]), "activation must not restart active sessions"
assert "checkLinkTargets" in result["migrateBefore"], "layout migration must run before files are linked"
assert "/bin/opencode-layout-migrate" in result["migrateData"]
assert "--retire-openfang-skills" not in result["migrateData"], "rog runs OpenFang; its skills are managed"
assert "agents" in result["oc"] and "permissions" in result["oc"]
assert result["oc"]["plugins"] == ["opencode-claude-subscription@0.1.4", "@slkiser/opencode-quota@5.0.3"]
assert result["quotaPlugins"] == {"thinkcentre": False, "t14": False, "macm5Home": True, "macm5Darwin": True}, result["quotaPlugins"]
quota = json.loads(result["quotaConfig"])
assert quota["enabledProviders"] == "auto"
assert quota["tuiSidebarPanel"] == {"enabled": True}
assert quota["enableToast"] is False and quota["tuiCompactStatus"] == {"enabled": False}
assert result["oc"]["providers"]["openai"]["settings"]["transport"] == "http"
assert result["oc"]["providers"]["nvidia"]["name"] == "NVIDIA NIM", "NVIDIA requires a native declaration"
assert "sdd-task-result.ts" not in result["setupData"], "Candidate still installs the SDD task adapter"
for plugin in ("rtk.ts", "engram.ts", "opencode-review-transport.ts"):
    assert plugin in result["setupData"], f"Candidate lost managed plugin: {plugin}"
assert "ai-assets-reconcile" in result["setupData"] and "rm -rf" not in result["setupData"]
assert not any(name.startswith("sdd-") for name in result["oc"]["agents"])
profiles = {profile["name"]: profile["roles"] for profile in result["profiles"]}
selected = profiles[result["selectedProfiles"]["rog"]]
for role in ("gentle-orchestrator", "gentle-ai-worker", "gentle-ai-verify"):
    assert result["oc"]["agents"][role]["model"] == selected[role], role
title_providers = {"anthropic": "anthropic", "openai": "openai", "opencode": "opencode-go"}
owner_models = {"anthropic": "anthropic/claude-opus-5-5", "openai": "openai/gpt-6-astra", "opencode": "opencode-go/glm-5.3"}
core_roles = {"gentle-orchestrator", "gentle-ai-explore", "gentle-ai-worker", "gentle-ai-verify", "neutral"}
for name, roles in profiles.items():
    assert core_roles <= roles.keys(), f"{name}: missing core role assignment"
    tokens = name.split("-")
    if len(tokens) < 2 or not set(tokens) <= title_providers.keys():
        continue
    assert roles.keys() == selected.keys(), f"{name}: missing role assignment"
    allowed = {title_providers[token] for token in tokens}
    assert {model.split("/")[0] for model in roles.values()} <= allowed, f"{name}: model outside title providers"
    assert roles["gentle-orchestrator"] == roles["neutral"] == owner_models[tokens[0]], name
assert set(result["selectedProfiles"].values()) <= profiles.keys()
assert "setupOpencodePluginRuntime" in result["openfangAfter"]
assert "ai-assets-no-legacy" in result["openfangData"]
assert "opencode-owned-assets" in result["setupData"]
assert "ai-assets-no-legacy" in result["setupData"], "fresh ownership must not claim legacy bytes"
assert "opencode-project()" not in source, "project config loads by default; the opt-in alias is obsolete"
assert "optionalString (pkgs.stdenv.isDarwin && config.home.opencode.enable)" in source
match = re.search(r"opencode-home\(\) \(\n(.*?)\n      \)", source, re.S)
assert match, "missing scoped opencode-home shell function"

with tempfile.TemporaryDirectory() as tmp:
    root = Path(tmp)
    launcher = root / "opencode-home"
    launcher.write_text('#!/bin/sh\nprintf "%s\\0" "$OPENCODE_HOME_BINARY" "$@" > "$CAPTURE"\n')
    launcher.chmod(0o755)
    body = match.group(1).replace(
        '${config.home.profileDirectory}/bin/opencode', '/packaged/opencode'
    ).replace(
        '${pkgs.nixos-scripts}/bin/opencode-home', str(launcher)
    ).replace("''${@:2}", "${@:2}")
    function_script = root / "function.zsh"
    function_script.write_text("opencode-home() (\n" + body + "\n)\nopencode-home \"$@\"\n")

    def invoke(args):
        capture = root / "capture"
        subprocess.run(["zsh", str(function_script), *args], check=True,
                       env={**os.environ, "CAPTURE": str(capture)})
        return capture.read_bytes().split(b"\0")[:-1]

    expected_prefix = b"/packaged/opencode"
    assert invoke([]) == [expected_prefix, b"--standalone"]
    assert invoke(["run", "--model", "provider/model", "", "prompt with spaces"]) == [
        expected_prefix, b"run", b"--standalone", b"--model", b"provider/model", b"", b"prompt with spaces"
    ]
    assert invoke(["mini", "--continue"]) == [expected_prefix, b"mini", b"--standalone", b"--continue"]
    assert invoke(["auth", "login"]) == [expected_prefix, b"auth", b"login"]
    assert invoke(["run", "--server", "http://localhost:4096", "prompt"]) == [
        expected_prefix, b"run", b"--server", b"http://localhost:4096", b"prompt"
    ]

for name, mcp in result["oc"]["mcp"]["servers"].items():
    if mcp.get("type", "local") == "local":
        env = mcp.get("environment", {})
        assert env["HTTP_PROXY"] == env["HTTPS_PROXY"] == env["ALL_PROXY"] == "", name
        assert env["NO_PROXY"] == "*", name
        paths = env["PATH"].split(":")
        assert result["profileDirectory"] + "/bin" in paths, name
        assert f'/etc/profiles/per-user/{result["username"]}/bin' in paths, name
        assert "/run/current-system/sw/bin" in paths, name
        assert shutil.which(mcp["command"][0], path=env["PATH"]), (
            f"{name}: executable missing from the generated MCP PATH"
        )
    else:
        assert "environment" not in mcp, f"remote MCP changed: {name}"
print("PASS: migration precedes linking; local MCP PATH and proxy hygiene; scoped launcher")

for name in ("gentle-ai-managed", "opencode-managed"):
    subprocess.run(["nix", "build", "--impure", "--no-link", "--expr", f'''
let f = builtins.getFlake {json.dumps("path:" + str(ROOT))};
in builtins.head (builtins.filter (p: p.name == "{name}") f.homeConfigurations.rog.config.home.packages)
'''], cwd=ROOT, check=True)
wrapper = Path(result["gentleWrapper"]) / "bin/gentle-ai"
binary = wrapper.read_bytes()
assert binary[:4] == b"\x7fELF", "Linux wrapper must be native, not a shell script"
for name in (b"GENTLE_AI_OPENCODE_RELAY_CONTRACT", b"XDG_CONFIG_HOME", b"XDG_DATA_HOME", b"OPENCODE_DB", b"OPENCODE_CONFIG_DIR", b"TMPDIR"):
    assert name not in binary, f"native layout must not override {name!r}"
private = re.search(rb"/nix/store/[a-z0-9]+-gentle-ai-native-discovery/bin", binary)
assert private, "missing truthful private discovery directory"
native = Path(os.fsdecode(private.group())) / "opencode"
assert native.is_symlink() and native.resolve() == Path(result["nativeBinary"]).resolve()
assert subprocess.check_output([str(wrapper), "version"], text=True).strip() == "gentle-ai 4.1.1"
opencode = Path(result["opencodeWrapper"]) / "bin/opencode"
launcher_bytes = opencode.read_bytes()
assert launcher_bytes[:4] == b"\x7fELF" and b"OPENCODE_DISABLE_PROJECT_CONFIG" not in launcher_bytes
assert result["gentleWrapper"].encode() in launcher_bytes, "opencode must put the managed gentle-ai first on PATH"
assert subprocess.check_output([str(opencode), "--version"], text=True).strip().startswith("opencode v2.")
print("PASS: native HM wrappers; no layout overrides; truthful native discovery")

with tempfile.TemporaryDirectory(prefix="odd-registry-") as tmp:
    root = Path(tmp); home = root / "home"; project = root / "project"
    def skill(path, name, description):
        path.mkdir(parents=True, exist_ok=True)
        (path / "SKILL.md").write_text(f"---\nname: {name}\ndescription: {description}\n---\n")
    skill(home / ".config/opencode/skills/global-canary", "global-canary", "global root")
    skill(home / ".config/opencode/skills/collision", "collision", "global copy")
    skill(project / "skills/collision", "collision", "project first")
    probe = os.environ.get("GENTLE_AI_REGISTRY_PROBE", str(wrapper))
    rows = json.loads(subprocess.check_output([probe, "skill-registry", "list", "--json", "--cwd", str(project)],
                                             text=True, env={**os.environ,"HOME":str(home)}))
    skills = {row["name"]:row for row in rows}
    assert "global-canary" in skills, "Registry must scan the native global root"
    assert skills["collision"]["description"] == "project first"
    assert skills["collision"]["path"] == str(project / "skills/collision/SKILL.md")
    assert not (project / ".atl").exists(), "read-only list wrote a registry"
print("PASS: actual Go registry scans the native global root, keeps project-first precedence and read-only listing")
