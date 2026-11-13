import json
import os
import re
import shutil
import subprocess
import tempfile
import threading
import time
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]

PERSONAL_KEY = "0123456789ABCDEF0123456789ABCDEF01234567"
WORK_KEY = "89ABCDEF0123456789ABCDEF0123456789ABCDEF"

FINGERPRINT_PATTERN = re.compile(r"[0-9A-F]{16,}")

RUNTIME_SOURCE_FILES = [
    "shared/git-identity.nix",
    "shared/sops.nix",
    "linux/home/git.nix",
    "darwin/home/git.nix",
    "pkgs/nixos-scripts/default.nix",
    "pkgs/nixos-scripts/cmd/gpg-unlock/main.go",
    "pkgs/nixos-scripts/internal/gpgunlock/gpgunlock.go",
]

EVAL_EXPRESSION = """
let
  root = builtins.getEnv "REPO_ROOT";
  flake = builtins.getFlake "path:${root}";
  lib = flake.inputs.nixpkgs.lib;
  pkgs = flake.inputs.nixpkgs.legacyPackages.x86_64-linux // {
    writeText = name: text: builtins.toFile name text;
  };
  hm = import (flake.inputs.home-manager.outPath + "/modules");
  sopsHm = import (flake.inputs.sops-nix.outPath + "/modules/home-manager/sops.nix");
  platform = builtins.getEnv "SYNTHETIC_PLATFORM";
  syntheticHome = builtins.getEnv "SYNTHETIC_HOME";
  gitModule = import (root + "/${platform}/home/git.nix");
  sopsModule = import (root + "/shared/sops.nix");
  configuration = { ... }: {
    imports = [ sopsHm gitModule sopsModule ];
    home.username = "tester";
    home.homeDirectory = syntheticHome;
    home.stateVersion = "24.05";
    xdg.configHome = syntheticHome + "/.config";
  };
  cfg = (hm {
    inherit configuration pkgs;
    extraSpecialArgs = { githubUser = null; };
  }).config;
in
{
  config = cfg.xdg.configFile."git/config".text;
  activation = cfg.home.activation.writeGitIdentity.data;
  includes = cfg.programs.git.includes;
  includeFiles = map (entry: {
    inherit (entry) condition path;
    ini = if entry.contents == { } then null
      else lib.generators.toGitINI entry.contents;
  }) cfg.programs.git.includes;
  settings = cfg.programs.git.settings;
  signingKey = cfg.programs.git.signing.key;
  signByDefault = cfg.programs.git.signing.signByDefault;
  templates = builtins.mapAttrs (_: value: {
    inherit (value) content path;
  }) cfg.sops.templates;
  placeholders = {
    personal = cfg.sops.placeholder."github/personal_gpg_fingerprint";
    work = cfg.sops.placeholder."github/work_gpg_fingerprint";
  };
}
"""


def evaluate(platform, home):
    payload_path = os.environ.get("GIT_SIGNING_PAYLOAD")
    if payload_path:
        # The check evaluated the configuration with a placeholder home before
        # the test ran, because a build cannot evaluate Nix itself. Rewrite
        # the placeholder to the home this test uses.
        payload = json.loads(Path(payload_path).read_text())
        rendered = json.dumps(payload[platform]).replace(
            payload["syntheticHome"], str(home)
        )
        return json.loads(rendered)
    env = os.environ | {
        "REPO_ROOT": str(ROOT),
        "SYNTHETIC_PLATFORM": platform,
        "SYNTHETIC_HOME": str(home),
    }
    result = subprocess.run(
        ["nix", "eval", "--impure", "--json", "--expr", EVAL_EXPRESSION],
        check=False, capture_output=True, text=True, env=env,
    )
    if result.returncode != 0:
        raise RuntimeError(f"nix eval failed: {result.stderr.strip()}")
    return json.loads(result.stdout)


class GitSigningTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.scratch = tempfile.TemporaryDirectory()
        cls.home = Path(cls.scratch.name) / "home"
        cls.home.mkdir(parents=True)
        cls.linux = evaluate("linux", cls.home)
        cls.darwin = evaluate("darwin", cls.home)

    @classmethod
    def tearDownClass(cls):
        cls.scratch.cleanup()

    def write_runtime_files(self, home, personal=PERSONAL_KEY, work=WORK_KEY):
        git_dir = home / ".config" / "git"
        git_dir.mkdir(parents=True, exist_ok=True)
        (git_dir / "identity-personal").write_text("[user]\n    name = Personal\n    email = personal@example.com\n")
        (git_dir / "identity-work").write_text("[user]\n    name = Work\n    email = work@example.com\n")
        if personal is not None:
            (git_dir / "signing-personal").write_text(f"[user]\n    signingKey = {personal}\n")
        if work is not None:
            (git_dir / "signing-work").write_text(f"[user]\n    signingKey = {work}\n")
        return git_dir

    def install_config(self, home, evaluated, gpg_program=None):
        config = home / ".config" / "git" / "config"
        config.parent.mkdir(parents=True, exist_ok=True)
        text = evaluated["config"]
        if gpg_program is not None:
            text = text.replace(evaluated["settings"]["gpg"]["program"], str(gpg_program))
        for entry in evaluated["includeFiles"]:
            if entry["ini"] is None:
                continue
            target = home / ".config" / "git" / (Path(entry["path"]).name + ".inc")
            target.write_text(entry["ini"])
            text = text.replace(entry["path"], str(target))
        config.write_text(text)
        return config

    def fake_gpg(self, directory):
        bin_dir = directory / "bin"
        bin_dir.mkdir(parents=True, exist_ok=True)
        log = directory / "gpg-calls"
        script = bin_dir / "gpg"
        script.write_text(
            "#!/bin/sh\n"
            f'printf "%s\\n" "$@" >> "{log}"\n'
            'printf "[GNUPG:] SIG_CREATED 0123456789ABCDEF0123456789ABCDEF01234567 2026-01-01\\n" >&2\n'
            'printf "synthetic-signature\\n"\n'
            "exit 0\n"
        )
        script.chmod(0o755)
        return script, log

    def run_activation(self, home, activation=None):
        env = os.environ | {"HOME": str(home)}
        return subprocess.run(
            ["bash", "-e", "-c", activation or self.linux["activation"]],
            env=env, capture_output=True, text=True,
        )

    def activation_with_fake_gpg(self, evaluated, fake):
        return evaluated["activation"].replace(
            evaluated["settings"]["gpg"]["program"], str(fake)
        )

    def write_secrets(self, home, fingerprints, folder="github"):
        secrets = home / ".config" / "sops-nix" / "secrets" / folder
        secrets.mkdir(parents=True, exist_ok=True)
        for name, value in fingerprints.items():
            (secrets / name).write_text(value)

    def remove_secrets(self, home, names, folder="github"):
        secrets = home / ".config" / "sops-nix" / "secrets" / folder
        for name in names:
            path = secrets / name
            if path.exists():
                path.unlink()

    def commit_probe(self, home, repo, log):
        env = os.environ | {
            "HOME": str(home),
            "XDG_CONFIG_HOME": str(home / ".config"),
            "GIT_CONFIG_NOSYSTEM": "1",
            "PATH": f"{log.parent}:{os.environ['PATH']}",
        }
        if log.exists():
            log.unlink()
        (repo / "file.txt").write_text("content\n")
        subprocess.run(["git", "add", "file.txt"], cwd=repo, check=True, capture_output=True)
        result = subprocess.run(
            ["git", "commit", "-m", "probe"], cwd=repo, env=env, capture_output=True, text=True,
        )
        return result, log.exists()

    def git_config(self, home, directory, name):
        env = os.environ | {
            "HOME": str(home),
            "XDG_CONFIG_HOME": str(home / ".config"),
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_TERMINAL_PROMPT": "0",
        }
        result = subprocess.run(
            ["git", "config", "--get", name], cwd=directory,
            env=env, capture_output=True, text=True,
        )
        return result.returncode, result.stdout.strip()

    def make_repo(self, path):
        path.mkdir(parents=True, exist_ok=True)
        subprocess.run(["git", "init", "-q", "."], cwd=path, check=True, capture_output=True)
        return path

    def test_runtime_source_has_no_fingerprint_literal(self):
        for relative in RUNTIME_SOURCE_FILES:
            content = (ROOT / relative).read_text()
            match = FINGERPRINT_PATTERN.search(content)
            self.assertIsNone(
                match,
                f"{relative} hardcodes a signing fingerprint: {match.group(0) if match else ''}",
            )

    def test_linux_signing_key_comes_from_runtime_file(self):
        evaluated = self.linux
        self.assertIsNotNone(evaluated["signByDefault"])
        self.assertFalse(FINGERPRINT_PATTERN.fullmatch(evaluated["signingKey"] or ""))
        paths = [entry["path"] for entry in evaluated["includes"]]
        self.assertIn("~/.config/git/signing-personal", paths)
        self.assertIn("~/.config/git/signing-work", paths)
        work_entries = [
            entry for entry in evaluated["includes"]
            if entry["condition"] == "gitdir:~/Work/**" and "user" in entry["contents"]
        ]
        self.assertEqual(len(work_entries), 1)
        signing_key = work_entries[0]["contents"]["user"]["signingKey"]
        self.assertFalse(FINGERPRINT_PATTERN.fullmatch(signing_key))
        self.assertEqual(signing_key, evaluated["signingKey"])

    def test_darwin_signing_key_comes_from_runtime_file(self):
        evaluated = self.darwin
        self.assertIsNotNone(evaluated["signByDefault"])
        self.assertFalse(FINGERPRINT_PATTERN.fullmatch(evaluated["signingKey"] or ""))
        entries = evaluated["includes"]
        paths = [(entry["condition"], entry["path"]) for entry in entries]
        self.assertIn((None, "~/.config/git/signing-work"), paths)
        self.assertIn(("gitdir:~/Projects/**", "~/.config/git/signing-personal"), paths)
        projects_entries = [
            entry for entry in entries
            if entry["condition"] == "gitdir:~/Projects/**" and "user" in entry["contents"]
        ]
        self.assertEqual(len(projects_entries), 1)
        signing_key = projects_entries[0]["contents"]["user"]["signingKey"]
        self.assertFalse(FINGERPRINT_PATTERN.fullmatch(signing_key))
        nix_entries = [
            entry for entry in entries
            if entry["condition"] == "gitdir:~/.config/nix/**"
        ]
        self.assertNotIn(
            "~/.config/git/signing-personal",
            [entry["path"] for entry in nix_entries],
        )

    def test_git_resolves_personal_and_work_signing_keys(self):
        home = Path(tempfile.mkdtemp(dir=self.scratch.name))
        self.addCleanup(shutil.rmtree, home, ignore_errors=True)
        self.install_config(home, self.linux)
        self.write_runtime_files(home)
        plain = self.make_repo(home / "plain")
        work = self.make_repo(home / "Work" / "project")

        self.assertEqual(self.git_config(home, plain, "user.signingkey"), (0, PERSONAL_KEY))
        self.assertEqual(self.git_config(home, work, "user.signingkey"), (0, WORK_KEY))
        self.assertEqual(self.git_config(home, plain, "commit.gpgsign"), (0, "true"))
        self.assertEqual(self.git_config(home, work, "commit.gpgsign"), (0, "true"))

    def test_darwin_git_resolves_projects_and_nix_signing_keys(self):
        home = Path(tempfile.mkdtemp(dir=self.scratch.name))
        self.addCleanup(shutil.rmtree, home, ignore_errors=True)
        self.install_config(home, self.darwin)
        self.write_runtime_files(home)
        projects = self.make_repo(home / "Projects" / "app")
        nix_config = self.make_repo(home / ".config" / "nix")
        other = self.make_repo(home / "other")

        self.assertEqual(self.git_config(home, projects, "user.signingkey"), (0, PERSONAL_KEY))
        self.assertEqual(self.git_config(home, nix_config, "user.signingkey"), (0, WORK_KEY))
        self.assertEqual(self.git_config(home, other, "user.signingkey"), (0, WORK_KEY))

    def test_missing_runtime_signing_key_fails_closed(self):
        home = Path(tempfile.mkdtemp(dir=self.scratch.name))
        self.addCleanup(shutil.rmtree, home, ignore_errors=True)
        self.install_config(home, self.linux)
        self.write_runtime_files(home, work=None)
        plain = self.make_repo(home / "plain")
        work = self.make_repo(home / "Work" / "project")

        code, value = self.git_config(home, work, "user.signingkey")
        self.assertEqual(code, 0)
        self.assertNotEqual(value, PERSONAL_KEY)
        self.assertNotEqual(value, "")
        self.assertEqual(self.git_config(home, plain, "user.signingkey"), (0, PERSONAL_KEY))

    def test_activation_writes_runtime_signing_files(self):
        home = self.home
        secrets = home / ".config" / "sops-nix" / "secrets" / "github"
        secrets.mkdir(parents=True, exist_ok=True)
        (secrets / "personal_gpg_fingerprint").write_text(PERSONAL_KEY + "\n")
        (secrets / "work_gpg_fingerprint").write_text(WORK_KEY + "\n")
        for name, value in (("personal_name", "Personal"), ("personal_email", "p@example.com"),
                            ("work_name", "Work"), ("work_email", "w@example.com")):
            (secrets / name).write_text(value + "\n")
        env = os.environ | {"HOME": str(home)}

        result = self.run_activation(home)
        self.assertEqual(result.returncode, 0, result.stderr)
        gpg_program = self.linux["settings"]["gpg"]["program"]
        self.assertEqual(
            (home / ".config" / "git" / "signing-personal").read_text(),
            f"[user]\n    signingKey = {PERSONAL_KEY}\n[gpg]\n    program = {gpg_program}\n"
            f'[gpg "openpgp"]\n    program = {gpg_program}\n',
        )
        self.assertEqual(
            (home / ".config" / "git" / "signing-work").read_text(),
            f"[user]\n    signingKey = {WORK_KEY}\n[gpg]\n    program = {gpg_program}\n"
            f'[gpg "openpgp"]\n    program = {gpg_program}\n',
        )

        (secrets / "work_gpg_fingerprint").unlink()
        result = subprocess.run(
            ["bash", "-e", "-c", self.linux["activation"]],
            env=env, capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        work_content = (home / ".config" / "git" / "signing-work").read_text()
        self.assertNotIn(WORK_KEY, work_content)
        self.assertIn("=unavailable-signing-key", work_content)
        self.assertIn("[gpg", work_content)

    def test_signing_selector_uses_exact_match_form(self):
        for evaluated in (self.linux, self.darwin):
            selector = evaluated["signingKey"]
            self.assertTrue(
                selector.startswith("="),
                f"selector {selector!r} is not an exact match OpenPGP user ID",
            )
            self.assertEqual(selector.count(" "), 0)

    def test_fail_closed_scope_never_invokes_gpg(self):
        home = self.home
        self.write_secrets(home, {
            "personal_gpg_fingerprint": PERSONAL_KEY + "\n",
            "work_gpg_fingerprint": WORK_KEY + "\n",
            "personal_name": "Personal\n",
            "personal_email": "p@example.com\n",
            "work_name": "Work\n",
            "work_email": "w@example.com\n",
        })
        fake, log = self.fake_gpg(Path(self.scratch.name))
        self.install_config(home, self.linux, gpg_program=fake)
        activation = self.activation_with_fake_gpg(self.linux, fake)
        result = self.run_activation(home, activation)
        self.assertEqual(result.returncode, 0, result.stderr)
        repo = self.make_repo(home / "repo")
        (repo / "file.txt").write_text("content\n")
        subprocess.run(["git", "add", "file.txt"], cwd=repo, check=True, capture_output=True)
        env = os.environ | {
            "HOME": str(home),
            "XDG_CONFIG_HOME": str(home / ".config"),
            "GIT_CONFIG_NOSYSTEM": "1",
            "PATH": f"{fake.parent}:{os.environ['PATH']}",
        }
        subprocess.run(["git", "config", "user.email", "probe@example.com"], cwd=repo, check=True)
        subprocess.run(["git", "config", "user.name", "Probe"], cwd=repo, check=True)
        subprocess.run(["git", "commit", "-m", "probe"], cwd=repo, env=env, capture_output=True, text=True)
        self.assertTrue(log.exists(), "the runtime key must reach gpg")

        (home / ".config" / "sops-nix" / "secrets" / "github" / "personal_gpg_fingerprint").unlink()
        log.unlink()
        result = self.run_activation(home, activation)
        self.assertEqual(result.returncode, 0, result.stderr)
        commit = subprocess.run(
            ["git", "commit", "-m", "probe"], cwd=repo, env=env, capture_output=True, text=True,
        )
        self.assertNotEqual(commit.returncode, 0)
        self.assertFalse(log.exists(), "gpg must not run when the runtime key is unavailable")
        code, program = self.git_config(home, repo, "gpg.openpgp.program")
        self.assertEqual(code, 0)
        self.assertNotIn("gnupg", program)

    def test_malformed_fingerprint_cannot_inject_config(self):
        home = self.home
        self.write_secrets(home, {
            "personal_gpg_fingerprint": (
                PERSONAL_KEY + "\n[user]\n    signingKey = " + WORK_KEY + "\n"
            ),
            "work_gpg_fingerprint": WORK_KEY + "\n",
            "personal_name": "Personal\n",
            "personal_email": "p@example.com\n",
            "work_name": "Work\n",
            "work_email": "w@example.com\n",
        })
        result = self.run_activation(home)
        self.assertEqual(result.returncode, 0, result.stderr)
        content = (home / ".config" / "git" / "signing-personal").read_text()
        self.assertNotIn(WORK_KEY, content)
        self.assertEqual(content.count("[user]"), 1)
        self.assertIn("=unavailable-signing-key", content)

    def test_missing_global_scope_keeps_valid_conditional_scope(self):
        scenarios = [
            ("linux", self.linux, "personal_gpg_fingerprint", "Work/project", WORK_KEY),
            ("darwin", self.darwin, "work_gpg_fingerprint", "Projects/app", PERSONAL_KEY),
        ]
        for platform, evaluated, missing, valid_scope, valid_key in scenarios:
            home = self.home
            self.write_secrets(home, {
                "personal_gpg_fingerprint": PERSONAL_KEY + "\n",
                "work_gpg_fingerprint": WORK_KEY + "\n",
                "personal_name": "Personal\n",
                "personal_email": "p@example.com\n",
                "work_name": "Work\n",
                "work_email": "w@example.com\n",
            })
            self.remove_secrets(home, [missing])
            fake, log = self.fake_gpg(Path(self.scratch.name) / ("scope-" + platform))
            self.install_config(home, evaluated, gpg_program=fake)
            result = self.run_activation(
                home, self.activation_with_fake_gpg(evaluated, fake)
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            valid = self.make_repo(home / valid_scope)
            self.assertEqual(self.git_config(home, valid, "user.signingkey"), (0, valid_key))
            self.assertEqual(self.git_config(home, valid, "commit.gpgsign"), (0, "true"))
            code, program = self.git_config(home, valid, "gpg.openpgp.program")
            self.assertEqual(code, 0)
            self.assertEqual(program, str(fake))
            commit, invoked = self.commit_probe(home, valid, log)
            self.assertEqual(commit.returncode, 0, commit.stderr)
            self.assertTrue(invoked, "the valid scope must reach gpg")
            self.assertIn(valid_key, log.read_text())

            unavailable = self.make_repo(home / "unavailable")
            commit, invoked = self.commit_probe(home, unavailable, log)
            self.assertNotEqual(commit.returncode, 0)
            self.assertFalse(invoked, "the unavailable scope must not reach gpg")
            code, selector = self.git_config(home, unavailable, "user.signingkey")
            self.assertEqual(code, 0)
            self.assertEqual(selector, "=unavailable-signing-key")

    def test_signing_activation_waits_for_late_fingerprints(self):
        home = self.home
        secrets = home / ".config" / "sops-nix" / "secrets"
        if secrets.exists():
            for path in secrets.rglob("*"):
                if path.is_file():
                    path.unlink()

        def writer():
            time.sleep(1)
            self.write_secrets(home, {
                "personal_name": "Personal\n",
                "personal_email": "p@example.com\n",
                "work_name": "Work\n",
                "work_email": "w@example.com\n",
            }, folder="identities")
            time.sleep(1)
            self.write_secrets(home, {
                "personal_gpg_fingerprint": PERSONAL_KEY + "\n",
                "work_gpg_fingerprint": WORK_KEY + "\n",
            })

        thread = threading.Thread(target=writer)
        thread.start()
        result = self.run_activation(home)
        thread.join()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(
            PERSONAL_KEY, (home / ".config" / "git" / "signing-personal").read_text()
        )
        self.assertIn(
            WORK_KEY, (home / ".config" / "git" / "signing-work").read_text()
        )

    def test_gpg_unlock_key_list_comes_from_sops_template(self):
        templates = self.linux["templates"]
        self.assertIn("gpg-unlock-keys", templates)
        template = templates["gpg-unlock-keys"]
        self.assertFalse(FINGERPRINT_PATTERN.search(template["content"]))
        placeholders = self.linux["placeholders"]
        self.assertIn(placeholders["personal"], template["content"])
        self.assertIn(placeholders["work"], template["content"])
        self.assertEqual(
            [line for line in template["content"].splitlines() if line],
            [placeholders["personal"], placeholders["work"]],
        )
        self.assertTrue(template["path"].endswith("/sops-nix/secrets/rendered/gpg-unlock-keys"))

    def test_packaged_gpg_unlock_does_not_bake_key_list(self):
        package = (ROOT / "pkgs/nixos-scripts/default.nix").read_text()
        self.assertNotIn("gpg-unlock-keys", package)
        self.assertNotIn("NIXOS_SCRIPTS_GPG_KEYS_FILE", package)
        cli = (ROOT / "pkgs/nixos-scripts/cmd/gpg-unlock/main.go").read_text()
        self.assertIn("gpg-unlock-keys", cli)


if __name__ == "__main__":
    unittest.main()
