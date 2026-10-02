"""Offline regression for the macm5 scoped V2 launcher and MCP hygiene."""

import json
import os
from pathlib import Path
import re
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[2]
expression = f'''
let
  flake = builtins.getFlake {json.dumps(str(ROOT))};
  home = flake.homeConfigurations.rog.config;
  file = config: builtins.fromJSON (builtins.readFile (builtins.getAttr {json.dumps(".config/opencode/opencode.json")} config.home.file).source);
  fileV2 = config: builtins.fromJSON (builtins.readFile (builtins.getAttr {json.dumps(".config/opencode-v2/opencode.json")} config.home.file).source);
in {{
  inherit (home.programs.zsh) initContent;
  v1 = file home;
  v2 = fileV2 home;
}}
'''
result = json.loads(subprocess.check_output(
    ["nix", "eval", "--offline", "--impure", "--json", "--expr", expression],
    cwd=ROOT, text=True,
))
source = (ROOT / "shared/shell-aliases.nix").read_text()
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

for version, mcps in (("v1", result["v1"]["mcp"]), ("v2", result["v2"]["mcp"]["servers"])):
    for name, mcp in mcps.items():
        if mcp.get("type", "local") == "local":
            env = mcp.get("environment", {})
            assert env["HTTP_PROXY"] == env["HTTPS_PROXY"] == env["ALL_PROXY"] == "", name
            assert env["NO_PROXY"] == "*", name
        else:
            assert "environment" not in mcp, f"{version} remote MCP changed: {name}"
print("PASS: macOS-only V2 launcher wiring and generated V1/V2 local MCP scrub")
