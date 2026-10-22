import QtQuick
import Quickshell.Io
import qs.Ui

BarIndicator {
  id: root

  readonly property var idleService: bar?.shell?.firstPartyServiceFor("omarchy.idle")
  property bool legacyStayAwake: false

  active: idleService ? idleService.stayAwake : legacyStayAwake
  activeText: "󰅶"
  inactiveText: "󰅶"
  activeTooltipText: "Allow Idle Lock & Screensaver"
  inactiveTooltipText: "Stay Awake"

  function refresh() {
    if (!root.bar || root.idleService || statusProc.running || toggleProc.running) return
    statusProc.running = true
  }

  function toggle() {
    if (root.idleService) root.idleService.setIdleEnabled(root.active)
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
    running: !!root.bar && !root.idleService
    repeat: true
    onTriggered: root.refresh()
  }

  Process {
    id: statusProc
    command: ["bash", "-c", 'test -f "$HOME/.local/state/omarchy/toggles/idle-off"']
    onExited: function(exitCode) { root.legacyStayAwake = exitCode === 0 }
  }

  Process {
    id: toggleProc
    command: ["bash", "-c", 'exec "$HOME/.local/share/omarchy/bin/omarchy-toggle-idle"']
    onExited: function() { root.refresh() }
  }
}
