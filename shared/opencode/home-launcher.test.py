"""Offline regression for the macm5 scoped V2 launcher and MCP hygiene."""

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
  fileV2 = config: builtins.fromJSON (builtins.readFile (builtins.getAttr {json.dumps(".config/opencode-v2/opencode.json")} config.home.file).source);
in {{
  inherit (home.programs.zsh) initContent;
  v2 = fileV2 home;
  activation = home.home.activationPackage.drvPath;
  hasAutomaticRestart = home.home.activation ? restartOpencodeV2;
  openfangAfter = home.home.activation."syncOpencodeSkillsToOpenfang-v2".after;
  openfangData = home.home.activation."syncOpencodeSkillsToOpenfang-v2".data;
  setupData = home.home.activation."setupOpencodePluginRuntime-v2".data;
  profileDirectory = home.home.profileDirectory;
  gentleWrapper = (builtins.head (builtins.filter (p: p.name == "gentle-ai-v2-managed") home.home.packages)).outPath;
  runtimeEnvironment = home.home.file.".local/share/opencode-v2/environment".text;
  nativeBinary = (toString flake.nixosConfigurations.rog.pkgs.opencode-v2) + "/bin/.opencode2-unwrapped";
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
assert not result["hasAutomaticRestart"], "activation must not restart active V2 sessions"
assert "agents" in result["v2"] and "permissions" in result["v2"]
assert result["v2"]["plugins"] == ["opencode-claude-subscription@0.1.4"]
assert result["v2"]["providers"]["openai"]["settings"]["transport"] == "http"
assert result["v2"]["providers"]["nvidia"]["name"] == "NVIDIA NIM", "NVIDIA requires a native V2 declaration"
assert "sdd-task-result.ts" not in result["setupData"], "Candidate still installs the SDD task adapter"
for plugin in ("host-config.ts", "rtk.ts", "engram.ts", "opencode-review-transport.ts"):
    assert plugin in result["setupData"], f"Candidate lost managed plugin: {plugin}"
assert "ai-assets-reconcile" in result["setupData"] and "rm -rf" not in result["setupData"]
assert not any(name.startswith("sdd-") for name in result["v2"]["agents"])
profiles = {profile["name"]: profile["phases"] for profile in result["profiles"]}
selected = profiles[result["selectedProfiles"]["rog"]]
for role in ("gentle-orchestrator", "gentle-ai-worker", "gentle-ai-verify"):
    assert result["v2"]["agents"][role]["model"] == selected[role], role
medium = profiles["openai-anthropic-medium"]
for tier in ("light", "medium", "full"):
    phases = profiles[f"openai-anthropic-{tier}"]
    assert phases.keys() == medium.keys(), f"{tier}: missing phase assignment"
    assert set(model.split("/")[0] for model in phases.values()) == {"anthropic", "openai"}
    for phase in ("gentle-orchestrator", "gentle-ai-verify"):
        assert phases[phase] == "anthropic/claude-opus-5-5", (tier, phase)
assert profiles["openai-anthropic-light"]["gentle-ai-worker"] == "openai/gpt-6-luna"
assert medium["gentle-ai-worker"] == "openai/gpt-6.1-sol"
assert profiles["openai-anthropic-full"]["gentle-ai-worker"] == "anthropic/claude-opus-5-5"
triple = profiles["openai-anthropic-go"]
assert triple.keys() == medium.keys()
assert set(model.split("/")[0] for model in triple.values()) == {"anthropic", "openai"}
for phase, model in medium.items():
    expected = model
    assert triple[phase] == expected, phase
    if result["selectedProfiles"]["rog"] == "openai-anthropic-go":
        assert result["v2"]["agents"][phase]["model"] == expected, phase
assert set(result["selectedProfiles"].values()) <= profiles.keys()
assert "setupOpencodePluginRuntime-v2" in result["openfangAfter"]
assert ".config/opencode-v2/skills" in result["openfangData"]
assert ".config/opencode/skills" not in result["openfangData"]
assert "opencode-v2-owned-assets" in result["setupData"]
assert "optionalString (pkgs.stdenv.isDarwin && config.home.opencode.v2.enable)" in source
assert "opencode2-project()" in source and "opencode2()" in source
match = re.search(r"opencode2-home\(\) \(\n(.*?)\n      \)", source, re.S)
assert match, "missing scoped V2 shell function"

with tempfile.TemporaryDirectory() as tmp:
    root = Path(tmp)
    home = root / "home"
    environment = home / ".local/share/opencode-v2/environment"
    environment.parent.mkdir(parents=True)
    environment.write_text(":\n")
    launcher = root / "opencode-home"
    launcher.write_text('#!/bin/sh\nprintf "%s\\0" "$OPENCODE_HOME_BINARY" "$@" > "$CAPTURE"\n')
    launcher.chmod(0o755)
    body = match.group(1).replace(
        '${config.home.homeDirectory}', str(home)
    ).replace('${pkgs.opencode-v2}/bin/opencode2', '/packaged/opencode2').replace(
        '${pkgs.nixos-scripts}/bin/opencode-home', str(launcher)
    ).replace("''${@:2}", "${@:2}")
    assert '[[ ! -r "$environment" ]]' in body and 'source "$environment" ||' in body
    function_script = root / "function.zsh"
    function_script.write_text("opencode2-home() (\n" + body + "\n)\nopencode2-home \"$@\"\n")

    def invoke(args):
        capture = root / "capture"
        subprocess.run(["zsh", str(function_script), *args], check=True,
                       env={**os.environ, "CAPTURE": str(capture)})
        return capture.read_bytes().split(b"\0")[:-1]

    expected_prefix = b"/packaged/opencode2"
    assert invoke([]) == [expected_prefix, b"--standalone"]
    assert invoke(["run", "--model", "provider/model", "", "prompt with spaces"]) == [
        expected_prefix, b"run", b"--standalone", b"--model", b"provider/model", b"", b"prompt with spaces"
    ]
    assert invoke(["mini", "--continue"]) == [expected_prefix, b"mini", b"--standalone", b"--continue"]
    assert invoke(["auth", "login"]) == [expected_prefix, b"auth", b"login"]
    assert invoke(["run", "--server", "http://localhost:4096", "prompt"]) == [
        expected_prefix, b"run", b"--server", b"http://localhost:4096", b"prompt"
    ]

for name, mcp in result["v2"]["mcp"]["servers"].items():
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
        assert "environment" not in mcp, f"V2 remote MCP changed: {name}"
print("PASS: V2 activation preserves sessions; local MCP PATH and proxy hygiene; scoped launcher")

# Build the actual compiled HM wrapper, not a shell-function/fake-runtime proxy.
subprocess.run(["nix", "build", "--impure", "--no-link", "--expr", f'''
let f = builtins.getFlake {json.dumps("path:" + str(ROOT))};
in builtins.head (builtins.filter (p: p.name == "gentle-ai-v2-managed") f.homeConfigurations.rog.config.home.packages)
'''], cwd=ROOT, check=True)
wrapper = Path(result["gentleWrapper"]) / "bin/gentle-ai"
binary = wrapper.read_bytes()
assert binary[:4] == b"\x7fELF", "Linux wrapper must be native, not a shell script"
for name, value in {
    "XDG_CONFIG_HOME": "/home/glats/.config/opencode-v2",
    "XDG_DATA_HOME": "/home/glats/.local/opencode-v2/data",
    "XDG_CACHE_HOME": "/home/glats/.local/opencode-v2/cache",
    "XDG_STATE_HOME": "/home/glats/.local/opencode-v2/state",
    "OPENCODE_CONFIG_DIR": "/home/glats/.config/opencode-v2",
    "OPENCODE_DB": "/home/glats/.local/opencode-v2/data/opencode.db",
    "TMPDIR": "/home/glats/.local/opencode-v2/tmp",
    "OPENCODE_DISABLE_PROJECT_CONFIG": "1",
    "GENTLE_AI_OPENCODE_RELAY_CONTRACT": "gentle-ai.opencode-relay/v2-staged",
}.items():
    assert name.encode() in binary and value.encode() in binary, name
private = re.search(rb"/nix/store/[a-z0-9]+-gentle-ai-native-v2-discovery/bin", binary)
assert private, "missing truthful private discovery directory"
native = Path(os.fsdecode(private.group())) / "opencode"
assert native.is_symlink() and native.resolve() == Path(result["nativeBinary"]).resolve()
assert os.fsdecode(private.group()) not in result["runtimeEnvironment"], "private bare runtime leaked into host shell"
assert subprocess.check_output([str(wrapper), "version"], text=True,
                              env={**os.environ, "XDG_CONFIG_HOME": "/scrubbed/host-config"}).strip() == "gentle-ai 4.0.0"
print("PASS: native HM Gentle wrapper, complete restored V2 roots and private truthful 2.0.14 discovery")

with tempfile.TemporaryDirectory(prefix="odd-registry-") as tmp:
    root = Path(tmp); home = root / "home"; project = root / "project"
    def skill(path, name, description):
        path.mkdir(parents=True, exist_ok=True)
        (path / "SKILL.md").write_text(f"---\nname: {name}\ndescription: {description}\n---\n")
    skill(home / ".config/opencode-v2/skills/v2-canary", "v2-canary", "isolated V2")
    skill(home / ".config/opencode/skills/v1-canary", "v1-canary", "retired root")
    skill(home / ".config/opencode-v2/skills/collision", "collision", "global copy")
    skill(project / "skills/collision", "collision", "project first")
    probe = os.environ.get("GENTLE_AI_REGISTRY_PROBE", str(wrapper))
    rows = json.loads(subprocess.check_output([probe, "skill-registry", "list", "--json", "--cwd", str(project)],
                                             text=True, env={**os.environ,"HOME":str(home)}))
    skills = {row["name"]:row for row in rows}
    assert "v2-canary" in skills and "v1-canary" not in skills, "Registry still scans the retired global root"
    assert skills["collision"]["description"] == "project first"
    assert skills["collision"]["path"] == str(project / "skills/collision/SKILL.md")
    assert not (project / ".atl").exists(), "read-only list wrote a registry"
print("PASS: actual Go registry isolates V2 global root, preserves project-first precedence and read-only listing")

# Exercise the actual module-generated compiled wrapper with a quoted/spaced
# configuration root, without activating HM or fabricating native discovery.
with tempfile.TemporaryDirectory(prefix="odd wrapper 'quoted'-") as tmp:
    quoted_home = str(Path(tmp) / "home with 'single quote'")
    expression = f'''
let f = builtins.getFlake {json.dumps("path:" + str(ROOT))};
  h = f.homeConfigurations.rog.extendModules {{
    modules = [ ({{ lib, ... }}: {{ home.homeDirectory = lib.mkForce {json.dumps(quoted_home)}; }}) ];
  }};
in builtins.head (builtins.filter (p: p.name == "gentle-ai-v2-managed") h.config.home.packages)
'''
    out = subprocess.check_output(["nix", "build", "--impure", "--no-link", "--print-out-paths", "--expr", expression], text=True, cwd=ROOT).strip()
    quoted_wrapper = Path(out) / "bin/gentle-ai"
    compiled = quoted_wrapper.read_bytes()
    for suffix in ("/.config/opencode-v2", "/.local/opencode-v2/data/opencode.db", "/.local/opencode-v2/tmp"):
        assert (quoted_home + suffix).encode() in compiled, "configured path was split or lost its quote"
    assert subprocess.check_output([str(quoted_wrapper), "version"], text=True,
                                  env={**os.environ, "XDG_CONFIG_HOME":"/wrong-host-root"}).strip() == "gentle-ai 4.0.0"
print("PASS: actual compiled HM wrapper handles spaces/single quotes in configured roots without activation")
