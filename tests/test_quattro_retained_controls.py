import argparse
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument("--indicators", type=Path, required=True)
parser.add_argument("--legacy", type=Path, required=True)
args = parser.parse_args()


def probe(temperature, mode="normal", cross=False):
    with tempfile.TemporaryDirectory(prefix="quattro-retained-") as directory:
        root = Path(directory)
        for name in ("Ui", "bin", ".local/share/omarchy/bin", ".config/waybar", "run"):
            (root / name).mkdir(parents=True)
        (root / "run").chmod(0o700)
        for name in ("NightLight", "StayAwake"):
            shutil.copyfile(args.indicators / (name + ".qml"), root / (name + ".qml"))
        for name in ("omarchy-toggle-nightlight", "omarchy-toggle-idle"):
            target = root / ".local/share/omarchy/bin" / name
            shutil.copyfile(args.legacy / name, target)
            target.chmod(0o755)
        (root / ".config/waybar/config.jsonc").write_text("{}")
        (root / "temperature").write_text(temperature)
        before = hashlib.sha256((root / "temperature").read_bytes()).hexdigest()
        scripts = {
            "pgrep": "exit 0", "pkill": "exit 1", "notify-send": "exit 0",
            "hyprctl": 'test "$1 $2" = "hyprsunset temperature" || exit 2\n'
                       'if test "$#" = 3; then printf %s "$3" > "$HOME/temperature"; '
                       'else cat "$HOME/temperature"; test "$MODE" != failed; fi',
            "uwsm-app": "exit 99", "setsid": "exit 99", "omarchy-restart-waybar": "exit 99",
        }
        for name, script in scripts.items():
            path = root / "bin" / name
            path.write_text("#!/usr/bin/env bash\n" + script + "\n")
            path.chmod(0o755)
        (root / "Ui/BarIndicator.qml").write_text("""import QtQuick
Item {
property var bar
property var indicatorHost: null
property bool active: false
property string activeText
property string inactiveText
property string activeTooltipText
property string inactiveTooltipText
signal pressed()
}""")
        initial = mode != "failed" and temperature.isdecimal() and 0 < int(temperature) < 6000
        second = temperature == "6000"
        steps = [f'check(n.active === {str(initial).lower()} && !i.active, "initial");']
        if mode == "normal":
            steps[0] += " n.pressed(); i.pressed();"
            steps += [f'check(n.active === {str(second).lower()} && i.active, "first click");' +
                      (f' check(n2.active === {str(second).lower()} && i2.active, "peer refresh");' if cross else "") +
                      " n.pressed(); i.pressed();",
                      f'check(n.active === {str(not second).lower()} && !i.active, "second click");']
        cases = "\n".join(f"case {index}: {step} break;" for index, step in enumerate(steps))
        (root / "shell.qml").write_text("""import QtQuick
import Quickshell
ShellRoot {
id: root
property int phase: 0
property bool failed: false
function check(ok, message) { if (!ok) { failed = true; console.error("PROBE_FAIL", message) } }
QtObject { id: svc; function firstPartyServiceFor(name) { return null } }
QtObject { id: host; property var shell: svc }
NightLight { id: n; bar: host }
StayAwake { id: i; bar: host }
NightLight { id: n2; bar: host }
StayAwake { id: i2; bar: host }
Timer {
interval: INTERVAL; running: true; repeat: true
onTriggered: {
switch(root.phase++) { CASES }
if (root.phase === STEPS) { if (!root.failed) console.log("PROBE_PASS"); Qt.quit() }
}
}
}""".replace("INTERVAL", "6100" if cross else "700").replace("CASES", cases).replace("STEPS", str(len(steps))))
        environment = dict(
            os.environ, HOME=str(root), TMPDIR=str(root),
            PATH=str(root / "bin") + ":" + os.environ["PATH"], MODE=mode,
            QT_QPA_PLATFORM="offscreen", QT_QPA_PLATFORMTHEME="", QT_STYLE_OVERRIDE="Fusion",
            XDG_RUNTIME_DIR=str(root / "run"), XDG_CONFIG_HOME=str(root / ".config"),
            XDG_CACHE_HOME=str(root / "cache"), XDG_STATE_HOME=str(root / "state"),
            XDG_DATA_HOME=str(root / ".local/share"),
        )
        result = subprocess.run(
            ["qs", "--no-color", "-p", str(root / "shell.qml")],
            env=environment, text=True, capture_output=True, timeout=25,
        )
        assert result.returncode == 0 and "PROBE_PASS" in result.stdout + result.stderr, result.stdout + result.stderr
        if mode != "normal":
            assert before == hashlib.sha256((root / "temperature").read_bytes()).hexdigest()
        else:
            assert (root / "temperature").read_text() == ("6000" if second else "4000")
            assert not (root / ".local/state/omarchy/toggles/idle-off").exists()
        print("PASS", repr(temperature), mode, "cross=" + str(cross), flush=True)


for temperature in ("6000", "4500", "4000", "3500", "3000"):
    probe(temperature, cross=temperature == "6000")
for temperature in ("invalid command", "", "0"):
    probe(temperature, mode="malformed")
probe("4500", mode="failed")
