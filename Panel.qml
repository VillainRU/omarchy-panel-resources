import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "io.github.villainru.panel-resources"
  ipcTarget: moduleName
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  property var snapshot: ({
    version: 1,
    language: Model.languageFromLocale(Qt.locale().name),
    gpuVendor: "none",
    gpuTool: "",
    gpuName: "",
    metrics: []
  })
  property var enabledMetrics: ({})
  property int enabledRevision: 0
  property string errorText: ""
  property string collectorOutputText: ""
  property string collectorErrorText: ""
  property int collectorOutputLines: 0
  property bool collectorOutputRejected: false
  property bool collectorTimedOut: false

  readonly property var metrics: snapshot.metrics || []
  readonly property string language: Model.normalizeLanguage(snapshot.language)
  readonly property var systemMetrics: Model.metricsForKind(metrics, "system")
  readonly property var gpuMetrics: Model.metricsForKind(metrics, "gpu")
  readonly property var visibleBarMetrics: Model.visibleMetrics(metrics, enabledMetrics)
  readonly property string gpuToolDisplayName: snapshot.gpuTool === "amdgpu_top" ? "amdgpu_top"
    : snapshot.gpuTool === "nvtop" ? "nvtop" : textFor("gpuMonitor")
  readonly property int refreshIntervalMs: Math.max(1, Number(setting("refreshIntervalSec", 2)) || 2) * 1000
  readonly property string collectorPath: Quickshell.env("HOME")
    + "/.config/omarchy/plugins/" + moduleName + "/bin/panel-resources-collect"
  readonly property string monitorLauncherPath: Quickshell.env("HOME")
    + "/.config/omarchy/plugins/" + moduleName + "/bin/panel-resources-popup-tui"
  readonly property int collectorOutputLimit: 8192
  readonly property int collectorErrorLimit: 512

  function textFor(key) { return Model.textFor(language, key) }

  function open() {
    controller.show()
    refresh()
  }

  function close() { controller.hide() }
  function toggle() { opened ? close() : open() }

  function syncEnabledFromSettings() {
    enabledMetrics = Model.normalizeEnabled(setting("enabledMetrics", null))
    enabledRevision++
  }

  function isMetricEnabled(id) {
    enabledRevision
    return Model.isEnabled(enabledMetrics, id)
  }

  function persistSettings(values) {
    var entry = { id: root.moduleName }
    for (var existing in root.settings) if (existing !== "id") entry[existing] = root.settings[existing]
    for (var key in values) entry[key] = values[key]

    root.settings = entry
    if (root.hostWidget && "settings" in root.hostWidget) root.hostWidget.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function toggleMetric(id) {
    var next = {}
    for (var key in enabledMetrics) next[key] = enabledMetrics[key] === true
    next[id] = !isMetricEnabled(id)
    enabledMetrics = next
    enabledRevision++
    persistSettings({ enabledMetrics: next })
  }

  function applySnapshot(raw) {
    var parsed = Model.safeSnapshot(raw)
    if (!parsed.metrics || parsed.metrics.length === 0) {
      errorText = textFor("sensorsNotFound")
      return
    }
    snapshot = parsed
    errorText = ""
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

  function finishCollector(exitCode) {
    collectorDeadline.stop()
    if (collectorTimedOut || exitCode === 124 || exitCode === 137) {
      errorText = textFor("collectionError")
      return
    }
    if (exitCode === 0 && !collectorOutputRejected && collectorOutputText !== "") {
      applySnapshot(collectorOutputText)
      return
    }
    errorText = textFor("collectionError")
    if (collectorErrorText !== "") console.warn("panel-resources:", collectorErrorText)
  }

  function launchForMetric(id) {
    var metric = Model.metricById(metrics, id)
    if (!metric) return
    var command = metric.kind === "gpu" ? snapshot.gpuTool : "btop"
    if (!command) return
    Quickshell.execDetached([monitorLauncherPath, command])
  }

  function gpuSectionTitle() {
    var title = textFor("graphicsCard").toUpperCase()
    if (snapshot.gpuVendor === "amd") return title + " · AMD · AMDGPU_TOP"
    if (snapshot.gpuVendor === "nvidia") return title + " · NVIDIA · NVTOP"
    return title
  }

  onSettingsChanged: syncEnabledFromSettings()

  Component.onCompleted: {
    syncEnabledFromSettings()
    refresh()
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

  KeyboardPanel {
    id: popup
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: popup.fittedContentWidth(Style.space(430))
    contentHeight: popup.fittedContentHeight(contentColumn.implicitHeight, Style.space(680))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: contentColumn
          width: parent.width
          spacing: Style.space(10)

          Item {
            width: parent.width
            implicitHeight: Math.max(titleBlock.implicitHeight, refreshButton.implicitHeight)

            Column {
              id: titleBlock
              anchors.left: parent.left
              anchors.right: refreshButton.left
              anchors.rightMargin: Style.space(10)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Text {
                text: "Panel Resources"
                textFormat: Text.PlainText
                color: root.barForeground
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.subtitle
                font.bold: true
              }

              Text {
                text: root.snapshot.gpuVendor === "none"
                  ? root.textFor("systemMetrics") + " · btop"
                  : root.textFor("system") + " · btop  |  GPU · " + root.gpuToolDisplayName
                textFormat: Text.PlainText
                color: Qt.darker(root.barForeground, 1.35)
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption
              }
            }

            Button {
              id: refreshButton
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              iconText: "󰑐"
              tooltipText: root.textFor("refreshSensors")
              foreground: root.barForeground
              onClicked: root.refresh()
            }
          }

          Text {
            visible: root.errorText !== ""
            width: parent.width
            text: root.errorText
            textFormat: Text.PlainText
            color: Color.urgent
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.body
            wrapMode: Text.Wrap
          }

          PanelSeparator { visible: root.systemMetrics.length > 0 }
          PanelSectionHeader {
            visible: root.systemMetrics.length > 0
            text: root.textFor("system").toUpperCase() + " · BTOP"
            foreground: root.barForeground
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
          }

          Repeater {
            model: root.systemMetrics
            delegate: Item {
              id: systemMetricRow
              property var metric: modelData

              width: contentColumn.width
              implicitHeight: Math.max(systemLabels.implicitHeight, systemValue.implicitHeight, systemToggle.implicitHeight)

              Column {
                id: systemLabels
                anchors.left: parent.left
                anchors.right: systemValue.left
                anchors.rightMargin: Style.space(12)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(1)

                Text {
                  width: parent.width
                  text: systemMetricRow.metric.label
                  textFormat: Text.PlainText
                  color: root.barForeground
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.body
                  elide: Text.ElideRight
                }

                Text {
                  width: parent.width
                  visible: systemMetricRow.metric.detail !== ""
                  text: systemMetricRow.metric.detail
                  textFormat: Text.PlainText
                  color: Qt.darker(root.barForeground, 1.4)
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                }
              }

              Text {
                id: systemValue
                anchors.right: systemToggle.left
                anchors.rightMargin: Style.space(10)
                anchors.verticalCenter: parent.verticalCenter
                text: systemMetricRow.metric.value
                textFormat: Text.PlainText
                color: Color.accent
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.body
                font.bold: true
              }

              ToggleSwitch {
                id: systemToggle
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                checked: root.isMetricEnabled(systemMetricRow.metric.id)
                foreground: root.barForeground
                onToggled: root.toggleMetric(systemMetricRow.metric.id)

                PanelToolTip {
                  visible: systemToggle.containsMouse
                  text: systemToggle.checked
                    ? root.textFor("removeFromBar")
                    : root.textFor("showOnBar")
                  fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                }
              }
            }
          }

          PanelSeparator { visible: root.gpuMetrics.length > 0 }
          PanelSectionHeader {
            visible: root.gpuMetrics.length > 0
            text: root.gpuSectionTitle()
            foreground: root.barForeground
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
          }

          Repeater {
            model: root.gpuMetrics
            delegate: Item {
              id: gpuMetricRow
              property var metric: modelData

              width: contentColumn.width
              implicitHeight: Math.max(gpuLabels.implicitHeight, gpuValue.implicitHeight, gpuToggle.implicitHeight)

              Column {
                id: gpuLabels
                anchors.left: parent.left
                anchors.right: gpuValue.left
                anchors.rightMargin: Style.space(12)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(1)

                Text {
                  width: parent.width
                  text: gpuMetricRow.metric.label
                  textFormat: Text.PlainText
                  color: root.barForeground
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.body
                  elide: Text.ElideRight
                }

                Text {
                  width: parent.width
                  visible: gpuMetricRow.metric.detail !== ""
                  text: gpuMetricRow.metric.detail
                  textFormat: Text.PlainText
                  color: Qt.darker(root.barForeground, 1.4)
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                }
              }

              Text {
                id: gpuValue
                anchors.right: gpuToggle.left
                anchors.rightMargin: Style.space(10)
                anchors.verticalCenter: parent.verticalCenter
                text: gpuMetricRow.metric.value
                textFormat: Text.PlainText
                color: Color.accent
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.body
                font.bold: true
              }

              ToggleSwitch {
                id: gpuToggle
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                checked: root.isMetricEnabled(gpuMetricRow.metric.id)
                foreground: root.barForeground
                onToggled: root.toggleMetric(gpuMetricRow.metric.id)

                PanelToolTip {
                  visible: gpuToggle.containsMouse
                  text: gpuToggle.checked
                    ? root.textFor("removeFromBar")
                    : root.textFor("showOnBar")
                  fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                }
              }
            }
          }

          PanelSeparator { visible: root.metrics.length > 0 }

          Text {
            visible: root.metrics.length > 0
            width: parent.width
            text: root.textFor("selectorHint")
            textFormat: Text.PlainText
            color: Qt.darker(root.barForeground, 1.4)
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
            wrapMode: Text.Wrap
          }
        }
      }
    }
  }

}
