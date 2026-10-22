import QtQuick
import Quickshell.Io
import qs.Ui

BarIndicator {
  id: root

  readonly property var nightlightService: bar?.shell?.firstPartyServiceFor("omarchy.nightlight")
  property bool legacyNightlight: false

  active: nightlightService ? nightlightService.enabled : legacyNightlight
  activeText: "󰔎"
  inactiveText: "󰔎"
  activeTooltipText: "Day Light"
  inactiveTooltipText: "Night Light"

  function refresh() {
    if (!root.bar || root.nightlightService || statusProc.running || toggleProc.running) return
    statusProc.running = true
  }

  function toggle() {
    if (root.nightlightService) root.nightlightService.setNightlight(!root.active)
    else if (root.bar && !toggleProc.running) toggleProc.running = true
  }

  onBarChanged: refresh()
  Component.onCompleted: refresh()
  onPressed: function() { root.toggle() }

  Connections {
    target: root.indicatorHost
    ignoreUnknownSignals: true
    function onRefreshRequested() { root.refresh() }
  }

  Timer {
    interval: 5000
    running: !!root.bar && !root.nightlightService
    repeat: true
    onTriggered: root.refresh()
  }

  Process {
    id: statusProc
    command: ["hyprctl", "hyprsunset", "temperature"]
    stdout: StdioCollector { id: temperatureOutput }
    onExited: function(exitCode) {
      const value = temperatureOutput.text.trim()
      root.legacyNightlight = exitCode === 0 && /^[0-9]+$/.test(value)
        && Number(value) > 0 && Number(value) < 6000
    }
  }

  Process {
    id: toggleProc
    command: ["bash", "-c", 'exec "$HOME/.local/share/omarchy/bin/omarchy-toggle-nightlight"']
    onExited: function() { root.refresh() }
  }
}
