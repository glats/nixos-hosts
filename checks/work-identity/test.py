import json
import os
from pathlib import Path
import subprocess
import shutil
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]


def evaluate(expression):
    result = subprocess.run(
        ["nix", "eval", "--impure", "--json", "--expr", expression],
        check=True, capture_output=True, text=True,
    )
    return json.loads(result.stdout)


class WorkIdentityTests(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory()
        self.addCleanup(self.scratch.cleanup)
        self.home = Path(self.scratch.name)
        self.account = self.home / "work-account"
        self.account.write_text("work-login\n")
        self.log = self.home / "calls"
        self.env = os.environ | {
            "HOME": str(self.home), "GH_TEST_LOG": str(self.log),
            "GIT_CONFIG_NOSYSTEM": "1", "GIT_CONFIG_GLOBAL": "/dev/null",
            "GIT_TERMINAL_PROMPT": "0",
            "GIT_ASKPASS": "/bin/false", "SSH_ASKPASS": "/bin/false",
        }
        self.gh = self.home / "gh-package"
        (self.gh / "bin").mkdir(parents=True)
        executable = self.gh / "bin/gh"
        executable.write_text(
            '#!/bin/sh\nprintf "%s\\n" "$@" > "$GH_TEST_LOG"\n'
            'if [ "${GH_TEST_FAIL:-}" = 1 ]; then exit 1; fi\n'
            'printf "synthetic-token\\n"\n'
        )
        executable.chmod(0o755)

    def helper(self, runtime=True):
        name = "mkCredentialFromFile" if runtime else "mkCredential"
        account = str(self.account) if runtime else "personal-login"
        result = evaluate(
            f'(import {ROOT}/shared/git-identity.nix).{name} '
            f'{json.dumps(str(self.gh))} {json.dumps(account)}'
        )
        return result["https://github.com"]["helper"][1]

    def credential(self, helper):
        return subprocess.run(
            ["git", "-c", f"credential.helper={helper}", "credential", "fill"],
            input="protocol=https\nhost=github.com\n\n",
            env=self.env, capture_output=True, text=True,
        )

    def test_work_helper_reads_account_each_time(self):
        helper = self.helper()
        for account in ("work-login", "other-work-login"):
            self.account.write_text(account + "\n")
            result = self.credential(helper)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn(f"username={account}\n", result.stdout)
            self.assertIn("password=synthetic-token\n", result.stdout)
            self.assertEqual(self.log.read_text().splitlines()[-1], account)

    def test_personal_helper_unchanged(self):
        result = self.credential(self.helper(runtime=False))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("username=personal-login\n", result.stdout)
        self.assertEqual(self.log.read_text().splitlines()[-1], "personal-login")

    def test_missing_work_account_never_falls_back(self):
        helper = self.helper()
        self.account.unlink()
        result = self.credential(helper)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("password=", result.stdout)
        self.assertFalse(self.log.exists())

    def test_failed_work_auth_never_returns_credentials(self):
        self.env["GH_TEST_FAIL"] = "1"
        result = self.credential(self.helper())
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("password=", result.stdout)

    def test_empty_work_account_rejects_credentials(self):
        self.account.write_text("")
        result = self.credential(self.helper())
        self.assertEqual(result.returncode, 128)
        self.assertEqual(result.stdout, "")
        self.assertFalse(self.log.exists())

    def wrapper(self):
        server = self.home / "mcp-package"
        (server / "bin").mkdir(parents=True)
        executable = server / "bin/github-mcp-server"
        executable.write_text(
            '#!/bin/sh\ntest "$GITHUB_PERSONAL_ACCESS_TOKEN" = synthetic-token || exit 1\n'
            'printf "%s\\n" "$@"\n'
        )
        executable.chmod(0o755)
        packages = evaluate(
            f'(import {ROOT}/shared/github-mcp-wrapper.nix {{ '
            f'config.sops.secrets."github/work_account".path = {json.dumps(str(self.account))}; '
            'pkgs = { runtimeShell = "/bin/sh"; writeShellScriptBin = name: text: { inherit name text; }; '
            f'gh = {json.dumps(str(self.gh))}; github-mcp-server = {json.dumps(str(server))}; '
            '}; }).home.packages'
        )
        wrapper = self.home / "work-mcp"
        wrapper.write_text(next(p["text"] for p in packages if p["name"].endswith("-work")))
        return wrapper

    def test_work_mcp_uses_runtime_account_and_forwards_arguments(self):
        result = subprocess.run(
            ["bash", str(self.wrapper()), "stdio", "--read-only"],
            env=self.env, capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "stdio\n--read-only\n")
        self.assertEqual(self.log.read_text().splitlines()[-1], "work-login")

    def test_work_mcp_missing_account_fails_without_auth(self):
        wrapper = self.wrapper()
        self.account.unlink()
        result = subprocess.run(
            ["bash", str(wrapper)], env=self.env, capture_output=True, text=True,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.log.exists())
        self.assertNotIn("synthetic-token", result.stdout + result.stderr)

    def test_work_mcp_defaults_to_stdio(self):
        result = subprocess.run(
            ["bash", str(self.wrapper())],
            env=self.env, capture_output=True, text=True,
        )
        self.assertEqual((result.returncode, result.stdout, result.stderr), (0, "stdio\n", ""))

    def test_empty_work_mcp_account_has_exact_error(self):
        self.account.write_text("")
        result = subprocess.run(
            ["bash", str(self.wrapper())],
            env=self.env, capture_output=True, text=True,
        )
        self.assertEqual(
            (result.returncode, result.stdout, result.stderr),
            (1, "", "Error (github-mcp-server-work): work account secret is unavailable; check sops-nix.\n"),
        )
        self.assertFalse(self.log.exists())

    def test_ssh_work_alias_keeps_legacy_settings(self):
        settings = evaluate(
            f'(import {ROOT}/darwin/home/ssh.nix {{ '
            'config.home.homeDirectory = "/Users/developer"; '
            'lib.optionalAttrs = condition: attrs: if condition then attrs else {}; '
            '}).programs.ssh.settings'
        )
        self.assertEqual(settings["github-work"], settings["github-enterprise"])
        self.assertEqual(settings["github-work"]["IdentityFile"], "~/.ssh/id_ed25519_github")

    def test_default_account_file_and_missing_secret_retry(self):
        coreutils = Path(shutil.which("cat")).resolve().parents[1]
        configuration = evaluate(
            f'(import {ROOT}/shared/gh-default-account.nix {{ '
            'config.home.github = { defaultAccount = "personal-login"; '
            f'defaultAccountFile = {json.dumps(str(self.account))}; }}; '
            'lib = { mkOption = x: x; types = { str = null; nullOr = x: x; }; '
            'escapeShellArg = builtins.toJSON; hm.dag.entryAfter = _: text: text; '
            'mkIf = condition: attrs: if condition then attrs else {}; }; '
            'pkgs = { stdenv.hostPlatform = { isLinux = true; isDarwin = false; }; '
            f'gh = {json.dumps(str(self.gh))}; coreutils = {json.dumps(str(coreutils))}; '
            'writeShellScript = _: text: text; }; }).config'
        )
        runtime = self.home / "runtime"
        runtime.mkdir()
        (runtime / "bus").touch()
        self.env["XDG_RUNTIME_DIR"] = str(runtime)
        hosts = self.home / ".config/gh/hosts.yml"
        hosts.parent.mkdir(parents=True)
        hosts.write_text("github.com:\n    work-login:\n    personal-login:\n")
        activation = configuration["home"]["activation"]["ghDefaultAccount"]
        result = subprocess.run(
            ["bash", "-e", "-c", activation], env=self.env, capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout + result.stderr, "")
        self.assertEqual(self.log.read_text().splitlines()[-1], "work-login")
        self.account.unlink()
        self.log.unlink()
        result = subprocess.run(
            ["bash", "-e", "-c", activation], env=self.env, capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0)
        self.assertIn("continuing activation", result.stderr)
        self.assertFalse(self.log.exists())
        service = configuration["systemd"]["user"]["services"]["gh-default-account"]["Service"]
        self.assertEqual(service["Restart"], "on-failure")
        result = subprocess.run(
            ["bash", "-e", "-c", service["ExecStart"]],
            env=self.env, capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 1)
        self.assertFalse(self.log.exists())


if __name__ == "__main__":
    unittest.main()
