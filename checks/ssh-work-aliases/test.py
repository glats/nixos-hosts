import pathlib
import subprocess
import sys


sources = ("rog", "t14", "thinkcentre", "macm5")
members = (*sources, "oneplus5")


def effective(config, alias):
    result = subprocess.run(
        ["ssh", "-G", "-F", str(config), "-o", "IgnoreUnknown=UseKeychain", alias],
        capture_output=True,
        text=True,
        check=True,
    )
    values = {}
    for line in result.stdout.splitlines():
        key, value = line.split(" ", 1)
        values.setdefault(key, []).append(value)
    return values


for source, config in zip(sources, sys.argv[1:], strict=True):
    text = pathlib.Path(config).read_text()
    blocks = {
        line.split(" ", 1)[1]
        for line in text.splitlines()
        if line.startswith("Host ")
    }
    expected = {f"{target}-auth" for target in sources if target != source}
    assert {name for name in blocks if name.endswith("-auth")} == expected, source
    assert not any(name.endswith("-work") for name in blocks), source
    home = "/Users/juan" if source == "macm5" else "/home/glats"
    for target in members:
        if target == source:
            continue
        user = "juan" if target == "macm5" else "glats"
        for alias in (target, f"{target}.local", f"{target}.lan"):
            regular = effective(config, alias)
            assert regular["hostname"] == [f"{target}.lan"], (source, alias)
            assert regular["user"] == [user], (source, alias)
            assert regular["identityfile"] == [f"{home}/.ssh/id_ed25519_lan"], (source, alias)
            assert regular["preferredauthentications"] == ["publickey"], (source, alias)
            assert regular["batchmode"] == ["yes"], (source, alias)
            assert regular["passwordauthentication"] == ["no"], (source, alias)
            assert regular["controlpath"] == ["/nonexistent/shared-ssh-control"], (source, alias)
        if target in sources:
            work = effective(config, f"{target}-auth")
            assert work["hostname"] == [f"{target}.lan"], (source, target)
            assert work["user"] == [user], (source, target)
            assert work["identityfile"] == [f"{home}/.ssh/id_ed25519_lan"], (source, target)
            assert work["preferredauthentications"] == ["password"], (source, target)
            assert work["passwordauthentication"] == ["yes"], (source, target)
            assert work["pubkeyauthentication"] == ["false"], (source, target)
            assert work["batchmode"] == ["no"], (source, target)
            assert work.get("controlpath", ["none"]) == ["none"], (source, target)
            assert work["controlmaster"] == ["false"], (source, target)
    if source == "rog":
        relay = effective(config, "macm5-relay")
        assert relay["hostname"] == ["127.0.0.1"]
        assert relay["port"] == ["22220"]
        assert relay["preferredauthentications"] == ["publickey"]
        assert relay["passwordauthentication"] == ["no"]
        assert relay["kbdinteractiveauthentication"] == ["no"]
        assert relay["batchmode"] == ["yes"]
    print(f"{source}: work aliases, ordinary aliases and relay policy passed")
