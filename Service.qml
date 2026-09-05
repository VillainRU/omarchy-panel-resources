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
  property int failures: 0
  property int goodSnapshots: 0
  property double lastUpdated: 0
  property var panelOwners: []
  property var enabledSettings: ({})
  readonly property alias barModel: barMetrics
  readonly property alias systemModel: systemMetrics
  readonly property alias gpuModel: gpuMetrics
  readonly property var collectorPid: collectorProc.processId

  ListModel { id: barMetrics; dynamicRoles: true }
  ListModel { id: systemMetrics; dynamicRoles: true }
  ListModel { id: gpuMetrics; dynamicRoles: true }

  function updateModels() {
    Model.syncMetricModel(barMetrics, Model.visibleMetrics(snapshot.metrics, enabledSettings))
    if (panelOwners.length > 0) {
      Model.syncMetricModel(systemMetrics, Model.metricsForKind(snapshot.metrics, "system"))
      Model.syncMetricModel(gpuMetrics, Model.metricsForKind(snapshot.metrics, "gpu"))
    }
  }

  function setPanelOpen(owner, opened) {
    var next = panelOwners.filter(function(item) { return item !== owner })
    if (opened) next.push(owner)
    var changed = (next.length > 0) !== (panelOwners.length > 0)
    panelOwners = next
    updateModels()
    if (changed) controlTimer.restart()
  }

  function sendConfiguration() {
    if (!collectorProc.running) { ensureCollector(); return }
    collectorProc.write("CONFIG " + refreshIntervalMs + " "
      + (enabledMetricCsv || "-") + " " + (panelOwners.length > 0 ? "1" : "0") + "\n")
    heartbeat.restart()
  }

  Timer {
    id: controlTimer
    interval: 100
    onTriggered: root.sendConfiguration()
  }

  readonly property string sourceDir: manifest && manifest.__sourceDir
    ? String(manifest.__sourceDir)
    : Quickshell.env("HOME") + "/.config/omarchy/plugins/io.github.villainru.panel-resources"
  readonly property string collectorPath: sourceDir + "/bin/panel-resources-collect"
  readonly property int collectorOutputLimit: 8192
  readonly property int collectorErrorLimit: 512
  readonly property int heartbeatTimeoutMs: Math.max(5000, refreshIntervalMs * 3)

  function configure(settings) {
    enabledSettings = Model.normalizeEnabled(settings && settings.enabledMetrics)
    updateModels()
    var nextInterval = Model.normalizeRefreshIntervalMs(settings && settings.refreshIntervalSec)
    var nextEnabled = Model.enabledMetricCsv(settings && settings.enabledMetrics)
    if (nextInterval === refreshIntervalMs && nextEnabled === enabledMetricCsv) {
      ensureCollector()
      return
    }
    refreshIntervalMs = nextInterval
    enabledMetricCsv = nextEnabled
    controlTimer.restart()
  }

  function ensureCollector() {
    collectorWanted = true
    if (!collectorProc.running && !restartTimer.running) restartTimer.start()
  }

  function refresh() {
    if (collectorProc.running) collectorProc.write("RESCAN\n")
    else ensureCollector()
  }

  function restartCollector() {
    collectorWanted = true
    collectorRestarting = true
    heartbeat.stop()
    errorKey = "collectionError"
    goodSnapshots = 0
    failures++
    markUnavailable()
    if (collectorProc.running) collectorProc.running = false
    else restartTimer.restart()
  }

  function markUnavailable() {
    snapshot = Object.assign({}, snapshot, { metrics: snapshot.metrics.map(function(metric) {
      return Object.assign({}, metric, { value: "—", detail: "" })
    }) })
    updateModels()
  }

  function captureCollectorOutput(line) {
    var value = String(line || "")
    if (value.length === 0 || value.length > collectorOutputLimit) {
      errorKey = "collectionError"
      restartCollector()
      return
    }
    var parsed = Model.safeSnapshot(value, snapshot)
    if (!parsed.valid) { restartCollector(); return }
    var next = Model.mergeSnapshot(snapshot, parsed)
    if (JSON.stringify(next) !== JSON.stringify(snapshot)) snapshot = next
    lastUpdated = Date.now()
    goodSnapshots++
    if (goodSnapshots >= 3) failures = 0
    updateModels()
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
    interval: root.failures > 0 ? Model.retryDelay(root.failures) : 150
    repeat: false
    onTriggered: {
      if (root.collectorWanted && !collectorProc.running) {
        heartbeat.restart()
        collectorProc.running = true
      }
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
      "--control",
      "--interval-ms", String(root.refreshIntervalMs),
      "--enabled-metrics", root.enabledMetricCsv
    ]
    stdinEnabled: true

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
      root.goodSnapshots = 0
      root.sendConfiguration()
      heartbeat.restart()
    }

    onExited: function(exitCode) {
      heartbeat.stop()
      if (!root.collectorWanted) return
      root.errorKey = "collectionError"
      root.markUnavailable()
      if (!root.collectorRestarting) root.failures++
      if (!root.collectorRestarting && root.collectorErrorText !== "")
        console.warn("panel-resources:", root.collectorErrorText)
      restartTimer.restart()
    }
  }

  Component.onCompleted: ensureCollector()
}
