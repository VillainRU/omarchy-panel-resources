import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

Item {
  id: root

  property var shell: null
  property var manifest: null
  property var snapshot: ({
    version: 1,
    language: Model.languageFromLocale(Qt.locale().name),
    gpuVendor: "none",
    gpuTool: "",
    gpuName: "",
    metrics: [],
    dependencies: []
  })
  property string errorKey: ""
  property int refreshIntervalMs: 2000
  property string collectorOutputText: ""
  property string collectorErrorText: ""
  property int collectorOutputLines: 0
  property bool collectorOutputRejected: false
  property bool collectorTimedOut: false

  readonly property string sourceDir: manifest && manifest.__sourceDir
    ? String(manifest.__sourceDir)
    : Quickshell.env("HOME") + "/.config/omarchy/plugins/io.github.villainru.panel-resources"
  readonly property string collectorPath: sourceDir + "/bin/panel-resources-collect"
  readonly property int collectorOutputLimit: 8192
  readonly property int collectorErrorLimit: 512

  function configure(settings) {
    refreshIntervalMs = Model.normalizeRefreshIntervalMs(settings && settings.refreshIntervalSec)
  }

  function refresh() {
    if (!collectorProc.running) collectorProc.running = true
  }

  function resetCollectorCapture() {
    collectorOutputText = ""
    collectorErrorText = ""
    collectorOutputLines = 0
    collectorOutputRejected = false
    collectorTimedOut = false
  }

  function captureCollectorOutput(line) {
    collectorOutputLines++
    var value = String(line || "")
    if (collectorOutputLines !== 1 || value.length > collectorOutputLimit) {
      collectorOutputRejected = true
      collectorOutputText = ""
      return
    }
    collectorOutputText = value
  }

  function captureCollectorError(line) {
    if (collectorErrorText.length >= collectorErrorLimit) return
    var value = Model.sanitizeText(line, 256)
    if (value === "") return
    var separator = collectorErrorText === "" ? "" : " · "
    collectorErrorText = (collectorErrorText + separator + value).slice(0, collectorErrorLimit)
  }

  function applySnapshot(raw) {
    var parsed = Model.safeSnapshot(raw)
    snapshot = parsed
    errorKey = !parsed.metrics || parsed.metrics.length === 0 ? "sensorsNotFound" : ""
  }

  function finishCollector(exitCode) {
    collectorDeadline.stop()
    if (collectorTimedOut || exitCode === 124 || exitCode === 137) {
      errorKey = "collectionError"
      return
    }
    if (exitCode === 0 && !collectorOutputRejected && collectorOutputText !== "") {
      applySnapshot(collectorOutputText)
      return
    }
    errorKey = "collectionError"
    if (collectorErrorText !== "") console.warn("panel-resources:", collectorErrorText)
  }

  Timer {
    interval: root.refreshIntervalMs
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Timer {
    id: collectorDeadline
    interval: 3000
    repeat: false
    onTriggered: {
      root.collectorTimedOut = true
      if (collectorProc.running) collectorProc.running = false
    }
  }

  Process {
    id: collectorProc
    command: ["/usr/bin/timeout", "--signal=TERM", "--kill-after=0.5s", "2s", root.collectorPath]

    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function(line) { root.captureCollectorOutput(line) }
    }

    stderr: SplitParser {
      splitMarker: "\n"
      onRead: function(line) { root.captureCollectorError(line) }
    }

    onStarted: {
      root.resetCollectorCapture()
      collectorDeadline.restart()
    }
    onExited: function(exitCode) {
      Qt.callLater(function() { root.finishCollector(exitCode) })
    }
  }
}
