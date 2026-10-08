"""Offline regression for the macm5 scoped V2 launcher and MCP hygiene."""

import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[2]
expression = f'''
let
  flake = builtins.getFlake {json.dumps(str(ROOT))};
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
assert result["v2"]["agents"]["gentle-orchestrator"]["model"] == "anthropic/claude-opus-5-5"
assert result["v2"]["agents"]["sdd-apply"]["model"] == "openai/gpt-6.1-sol"
assert result["v2"]["agents"]["sdd-verify"]["model"] == "anthropic/claude-opus-5-5"
profiles = {profile["name"]: profile["phases"] for profile in result["profiles"]}
medium = profiles["openai-anthropic-medium"]
for tier in ("light", "medium", "full"):
    phases = profiles[f"openai-anthropic-{tier}"]
    assert phases.keys() == medium.keys(), f"{tier}: missing phase assignment"
    assert set(model.split("/")[0] for model in phases.values()) == {"anthropic", "openai"}
    for phase in ("gentle-orchestrator", "sdd-propose", "sdd-spec", "sdd-design", "sdd-verify"):
        assert phases[phase] == "anthropic/claude-opus-5-5", (tier, phase)
    assert phases["sdd-init"] == phases["sdd-archive"] == "openai/gpt-6-luna"
assert profiles["openai-anthropic-light"]["sdd-apply"] == "openai/gpt-6-luna"
assert medium["sdd-apply"] == "openai/gpt-6.1-sol"
assert profiles["openai-anthropic-full"]["sdd-apply"] == "anthropic/claude-opus-5-5"
triple = profiles["openai-anthropic-go"]
assert triple.keys() == medium.keys()
assert set(model.split("/")[0] for model in triple.values()) == {"anthropic", "openai", "opencode-go"}
for phase, model in medium.items():
    expected = "opencode-go/gpt-6-luna" if phase in ("sdd-init", "sdd-tasks", "sdd-archive") else model
    assert triple[phase] == expected, phase
    assert result["v2"]["agents"][phase]["model"] == expected, phase
assert set(result["selectedProfiles"].values()) == {"openai-anthropic-go"}
assert "setupOpencodePluginRuntime-v2" in result["openfangAfter"]
assert ".config/opencode-v2/skills" in result["openfangData"]
assert ".config/opencode/skills" not in result["openfangData"]
assert "opencode-v2/plugins" in result["setupData"]
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
