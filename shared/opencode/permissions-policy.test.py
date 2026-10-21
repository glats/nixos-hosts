"""Offline regression for the factory-mirrored OpenCode and Claude Code permission policy."""

import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
expression = f'''
let
  h = (builtins.getFlake {json.dumps("path:" + str(ROOT))}).homeConfigurations.rog.config;
  read = name: builtins.unsafeDiscardStringContext (builtins.readFile (builtins.getAttr name h.home.file).source);
in {{
  opencode = builtins.fromJSON (read ".config/opencode/opencode.json");
  claude = builtins.fromJSON (read ".claude/settings.json");
}}
'''
result = json.loads(subprocess.check_output(
    ["nix", "eval", "--impure", "--json", "--expr", expression], cwd=ROOT, text=True,
))


def pattern(glob):
    return re.compile("^" + "".join(
        ".*" if c == "*" else "." if c == "?" else re.escape(c) for c in glob
    ) + "$", re.S)


def resolve(rules, action, subject):
    effect = None
    for rule in rules:
        if rule["action"] == action and pattern(rule["resource"]).match(subject):
            effect = rule["effect"]
    return effect


rules = result["opencode"]["permissions"]
for command, effect in [
    ("rm -rf /", "deny"), ("rm -rf build", "ask"), ("sudo rm -rf x", "ask"),
    ("git push", "ask"), ("git push --force", "deny"), ("git push --follow-tags", "ask"),
    ("git clean -n -- fixtures/", "allow"), ("git clean -fd", "deny"), ("git clean -df", "deny"),
    ("git reset --hard HEAD", "deny"), ("chmod -R 777 /srv", "deny"), ("git status", "allow"),
    ("sops -d x", "deny"), ("git commit -m x", "ask"), ("ssh host", "ask"),
    ("psql -c 'DROP TABLE t'", "ask"),
]:
    assert resolve(rules, "shell", command) == effect, (command, effect)
for action, path, effect in [
    ("read", "/etc/hostname", "allow"), ("read", "/home/u/.env", "deny"),
    ("read", "/home/u/prod.env", "deny"), ("edit", "/home/u/.ssh/id_ed25519", "deny"),
    ("read", "/run/secrets/token", "deny"), ("external_directory", "/etc/nixos", "allow"),
]:
    assert resolve(rules, action, path) == effect, (action, path, effect)
shell = [rule["resource"] for rule in rules if rule["action"] == "shell"]
assert shell[0] == "*" and shell == sorted(shell), "shell rules must stay in byte order with * first"

permissions = result["claude"]["permissions"]
assert permissions["additionalDirectories"] == ["/"]
for rule in ("Bash(rm -rf /)", "Bash(git push --force*)", "Bash(git reset --hard *)",
             "Bash(git clean -df*)", "Bash(git clean -xdf*)", "Read(**/*.env)",
             "Read(**/.ssh/**)", "Edit(**/.ssh/**)", "Read(//run/secrets/**)"):
    assert rule in permissions["deny"], rule
for rule in ("Bash(git push)", "Bash(git commit *)", "Bash(ssh *)", "Bash(npm publish *)"):
    assert rule in permissions["ask"], rule
print("PASS: factory destructive and secret policy for OpenCode and Claude Code")
