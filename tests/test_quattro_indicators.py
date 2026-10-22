import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


parser = argparse.ArgumentParser()
parser.add_argument("--indicators", type=Path, default=Path("hosts/t14/home/quattro-indicators"))
args, remaining = parser.parse_known_args()


class IndicatorsTest(unittest.TestCase):
    def run_indicators(self, temperature="6000", idle=False, toggle=False, native=False):
        with tempfile.TemporaryDirectory(prefix="quattro-indicators-") as directory:
            root = Path(directory)
            for name in ("NightLight", "StayAwake"):
                shutil.copyfile(args.indicators / f"{name}.qml", root / f"{name}.qml")
            (root / "Ui").mkdir()
            (root / "Ui/BarIndicator.qml").write_text("""
import QtQuick
Item {
    property var bar
    property var indicatorHost: null
    property bool active: false
    property string activeText
    property string inactiveText
    property string activeTooltipText
    property string inactiveTooltipText
    signal pressed()
}
""")
            (root / "bin").mkdir()
            legacy = root / ".local/share/omarchy/bin"
            legacy.mkdir(parents=True)
            flag = root / ".local/state/omarchy/toggles/idle-off"
            flag.parent.mkdir(parents=True)
            if idle:
                flag.touch()
            (root / "temperature").write_text(temperature)
            commands = {
                root / "bin/hyprctl": 'test "$*" = "hyprsunset temperature" || exit 2\ncat "$HOME/temperature"\n',
                legacy / "omarchy-toggle-nightlight": 'printf 4000 > "$HOME/temperature"\n',
                legacy / "omarchy-toggle-idle": 'flag="$HOME/.local/state/omarchy/toggles/idle-off"\nif test -f "$flag"; then rm "$flag"; else touch "$flag"; fi\nexit 1\n',
            }
            for path, content in commands.items():
                path.write_text("#!/usr/bin/env bash\n" + content)
                path.chmod(0o755)
            expect_night = temperature.isdecimal() and 0 < int(temperature) < 6000
            initial = "true" if native else "false"
            (root / "shell.qml").write_text(f"""
import QtQuick
import Quickshell
ShellRoot {{
    id: test
    property int phase: 0
    QtObject {{
        id: nightService
        property bool enabled: false
        function setNightlight(value) {{ enabled = value }}
    }}
    QtObject {{
        id: idleService
        property bool stayAwake: false
        function setIdleEnabled(value) {{ stayAwake = !value }}
    }}
    QtObject {{
        id: serviceShell
        function firstPartyServiceFor(name) {{
            if (!{initial}) return null
            return name === "omarchy.idle" ? idleService : nightService
        }}
    }}
    QtObject {{ id: hostBar; property var shell: serviceShell }}
    NightLight {{ id: night; bar: hostBar }}
    StayAwake {{ id: awake; bar: hostBar }}
    Timer {{
        interval: 700
        running: true
        repeat: true
        onTriggered: {{
            if (test.phase === 0) {{
                if (night.active !== {str(expect_night if not native else False).lower()}
                    || awake.active !== {str(idle if not native else False).lower()}) {{
                    console.error("INITIAL_STATE_FAILED", night.active, awake.active)
                    Qt.quit()
                    return
                }}
                if ({str(toggle).lower()}) {{
                    night.pressed()
                    awake.pressed()
                    test.phase = 1
                    return
                }}
            }} else if (!night.active || awake.active !== {str(not idle).lower()}) {{
                console.error("TOGGLE_FAILED", night.active, awake.active)
                Qt.quit()
                return
            }}
            console.log("QML_TEST_PASS")
            Qt.quit()
        }}
    }}
}}
""")
            environment = dict(
                os.environ, HOME=str(root), QT_QPA_PLATFORM="offscreen",
                QT_QPA_PLATFORMTHEME="", QT_STYLE_OVERRIDE="Fusion",
            )
            environment["PATH"] = f"{root / 'bin'}:{environment['PATH']}"
            environment["XDG_CONFIG_HOME"] = str(root / "config")
            environment["XDG_CACHE_HOME"] = str(root / "cache")
            environment["XDG_STATE_HOME"] = str(root / "state")
            environment["XDG_RUNTIME_DIR"] = str(root / "run")
            (root / "run").mkdir(mode=0o700)
            result = subprocess.run(
                ["qs", "--no-color", "-p", str(root / "shell.qml")],
                env=environment, capture_output=True, text=True, timeout=10,
            )
            self.assertIn("QML_TEST_PASS", result.stdout + result.stderr)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            if toggle and not native:
                self.assertEqual(flag.exists(), not idle)
                self.assertEqual((root / "temperature").read_text(), "4000")

    def test_legacy_clicks_and_nonzero_idle_exit(self):
        self.run_indicators(toggle=True)

    def test_legacy_idle_can_be_reenabled(self):
        self.run_indicators(idle=True, toggle=True)

    def test_scheduled_nightlight_state(self):
        self.run_indicators(temperature="4500")

    def test_malformed_temperature_is_not_active(self):
        self.run_indicators(temperature="invalid command")

    def test_native_controls_unchanged(self):
        self.run_indicators(native=True, toggle=True)


if __name__ == "__main__":
    unittest.main(argv=[__file__, *remaining])
