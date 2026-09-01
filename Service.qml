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
    complete: true,
    language: Model.languageFromLocale(Qt.locale().name),
    gpuVendor: "none",
    gpuTool: "",
    gpuName: "",
    metrics: [],
    dependencies: []
  })
  property string errorKey: ""
  property int refreshIntervalMs: 2000
  property string enabledMetricCsv: Model.enabledMetricCsv(null)
  property string collectorErrorText: ""
  property bool collectorWanted: true
  property bool collectorReceivedSnapshot: false
  property bool collectorRestarting: false

  readonly property string sourceDir: manifest && manifest.__sourceDir
    ? String(manifest.__sourceDir)
    : Quickshell.env("HOME") + "/.config/omarchy/plugins/io.github.villainru.panel-resources"
  readonly property string collectorPath: sourceDir + "/bin/panel-resources-collect"
  readonly property int collectorOutputLimit: 8192
  readonly property int collectorErrorLimit: 512
  readonly property int heartbeatTimeoutMs: Math.max(5000, refreshIntervalMs * 3)

  function configure(settings) {
    var nextInterval = Model.normalizeRefreshIntervalMs(settings && settings.refreshIntervalSec)
    var nextEnabled = Model.enabledMetricCsv(settings && settings.enabledMetrics)
    if (nextInterval === refreshIntervalMs && nextEnabled === enabledMetricCsv) {
      ensureCollector()
      return
    }
    refreshIntervalMs = nextInterval
    enabledMetricCsv = nextEnabled
    restartCollector()
  }

  function ensureCollector() {
    collectorWanted = true
    if (!collectorProc.running && !restartTimer.running) restartTimer.start()
  }

  function refresh() {
    restartCollector()
  }

  function restartCollector() {
    collectorWanted = true
    collectorRestarting = true
    heartbeat.stop()
    restartTimer.restart()
    if (collectorProc.running) collectorProc.running = false
  }

  function captureCollectorOutput(line) {
    var value = String(line || "")
    if (value.length === 0 || value.length > collectorOutputLimit) {
      errorKey = "collectionError"
      restartCollector()
      return
    }
    var parsed = Model.safeSnapshot(value)
    snapshot = Model.mergeSnapshot(snapshot, parsed)
    collectorReceivedSnapshot = true
    errorKey = !snapshot.metrics || snapshot.metrics.length === 0 ? "sensorsNotFound" : ""
    heartbeat.restart()
  }

  function captureCollectorError(line) {
    if (collectorErrorText.length >= collectorErrorLimit) return
    var value = Model.sanitizeText(line, 256)
    if (value === "") return
    var separator = collectorErrorText === "" ? "" : " · "
    collectorErrorText = (collectorErrorText + separator + value).slice(0, collectorErrorLimit)
  }

  Timer {
    id: restartTimer
    interval: 150
    repeat: false
    onTriggered: {
      if (root.collectorWanted && !collectorProc.running) collectorProc.running = true
    }
  }

  Timer {
    id: heartbeat
    interval: root.heartbeatTimeoutMs
    repeat: false
    onTriggered: {
      root.errorKey = "collectionError"
      root.restartCollector()
    }
  }

  Process {
    id: collectorProc
    command: [
      root.collectorPath,
      "--watch",
      "--interval-ms", String(root.refreshIntervalMs),
      "--enabled-metrics", root.enabledMetricCsv
    ]

    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function(line) { root.captureCollectorOutput(line) }
    }

    stderr: SplitParser {
      splitMarker: "\n"
      onRead: function(line) { root.captureCollectorError(line) }
    }

    onStarted: {
      root.collectorRestarting = false
      root.collectorErrorText = ""
      root.collectorReceivedSnapshot = false
      heartbeat.restart()
    }

    onExited: function(exitCode) {
      heartbeat.stop()
      if (!root.collectorWanted) return
      if (!root.collectorReceivedSnapshot) root.errorKey = "collectionError"
      if (!root.collectorRestarting && root.collectorErrorText !== "")
        console.warn("panel-resources:", root.collectorErrorText)
      restartTimer.restart()
    }
  }

  Component.onCompleted: ensureCollector()
}
