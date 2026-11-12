import os
import pathlib
import re
import subprocess
import tempfile


root = pathlib.Path(__file__).resolve().parents[2]
source = (root / "linux/home/link-grabber.nix").read_text()
script = source.split(" ] ''", 1)[1].rsplit("'';", 1)[0]

# The preferred scratch directory is not present in every environment, for
# example inside a Nix build sandbox, so fall back to the temporary directory.
scratch_root = "/tmp/opencode" if os.path.isdir("/tmp/opencode") else None

with tempfile.TemporaryDirectory(prefix="link-grabber-", dir=scratch_root) as tmp:
    home = pathlib.Path(tmp)
    env_file = home / ".config/link-grabber/env"
    env_file.parent.mkdir(parents=True)
    secrets = home / "secrets"
    secrets.mkdir()
    groq = secrets / "opencode/groq_api_key"
    telegram = secrets / "link_grabber/telegram_token"
    for path in (groq, telegram):
        path.parent.mkdir(parents=True)
    groq.write_text("dummy-groq\n")
    telegram.write_text("dummy-telegram\n")
    script = re.sub(
        r'\$\{config\.sops\.secrets\."([^"]+)"\.path\}',
        lambda match: str(secrets / match[1]),
        script,
    )
    binary = home / "bin"
    binary.mkdir()
    calls = home / "calls"
    systemctl = binary / "systemctl"
    systemctl.write_text('#!/bin/sh\nprintf "%s\\n" "$*" >> "$HOME/calls"\n')
    systemctl.chmod(0o700)
    environment = dict(os.environ, HOME=str(home), PATH=f"{binary}:{os.environ['PATH']}")

    def run(expected_calls):
        calls.write_text("")
        result = subprocess.run(
            ["bash", "-e", "-c", script], env=environment, capture_output=True, text=True
        )
        assert result.returncode == 0, "activation failed"
        assert calls.read_text().splitlines() == [
            "--user try-restart link-grabber-bot.service"
        ] * expected_calls, "incorrect restart count"
        assert "dummy-" not in result.stdout + result.stderr, "value leaked to output"
        assert sorted(env_file.parent.iterdir()) == [env_file], "temporary file left"

    env_file.write_text("KEEP=yes\nGROQ_API_KEY=dummy-groq\nTELEGRAM_TOKEN=dummy-old\n")
    run(1)
    assert env_file.read_text() == (
        "KEEP=yes\nGROQ_API_KEY=dummy-groq\nTELEGRAM_TOKEN=dummy-telegram\n"
    ), "Telegram token was not synchronized"
    assert env_file.stat().st_mode & 0o777 == 0o600
    assert env_file.parent.stat().st_mode & 0o777 == 0o700
    run(0)
    groq.write_text("dummy-groq-next\n")
    run(1)
    assert "GROQ_API_KEY=dummy-groq-next\n" in env_file.read_text()
    groq.write_text("dummy-groq-both\n")
    telegram.write_text("dummy-telegram-both\n")
    run(1)
    assert env_file.read_text() == (
        "KEEP=yes\nGROQ_API_KEY=dummy-groq-both\nTELEGRAM_TOKEN=dummy-telegram-both\n"
    )
    run(0)
    previous = env_file.read_bytes()
    telegram.unlink()
    run(0)
    assert env_file.read_bytes() == previous
    telegram.write_text("dummy-telegram\n")
    groq.unlink()
    run(0)
    assert env_file.read_bytes() == previous
    env_file.unlink()
    calls.write_text("")
    result = subprocess.run(
        ["bash", "-e", "-c", script], env=environment, capture_output=True, text=True
    )
    assert result.returncode == 0
    assert not env_file.exists() and not calls.read_text()

print("link-grabber: synchronization, permissions, no-op and restart checks passed")
