import QtQuick
import Quickshell
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
  property var service: null
  readonly property var barIdentity: hostWidget || root
  readonly property var emptySnapshot: ({
    version: 1,
    language: Model.languageFromLocale(Qt.locale().name),
    gpuVendor: "none",
    gpuTool: "",
    gpuName: "",
    metrics: [],
    dependencies: []
  })
  readonly property var snapshot: service && service.snapshot ? service.snapshot : emptySnapshot
  property string activeTab: "system"
  property var enabledMetrics: ({})
  property int enabledRevision: 0

  readonly property var metrics: snapshot.metrics || []
  readonly property var dependencies: snapshot.dependencies || []
  readonly property string language: Model.normalizeLanguage(snapshot.language)
  readonly property string errorText: service && service.errorKey
    ? textFor(service.errorKey) : ""
  readonly property var systemMetrics: service ? service.systemModel : null
  readonly property var gpuMetrics: service ? service.gpuModel : null
  readonly property var visibleBarMetrics: Model.visibleMetrics(metrics, enabledMetrics)
  readonly property string gpuToolDisplayName: snapshot.gpuTool === "amdgpu_top" ? "amdgpu_top"
    : snapshot.gpuTool === "nvtop" ? "nvtop" : textFor("gpuMonitor")

  function textFor(key) { return Model.textFor(language, key) }

  function open() {
    controller.show()
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

  function refresh() {
    if (service && typeof service.refresh === "function") service.refresh()
  }

  function launchForMetric(id) {
    var metric = Model.metricById(metrics, id)
    if (!metric) return
    var command = metric.kind === "gpu" ? snapshot.gpuTool : "btop"
    if (!command) return
    Quickshell.execDetached(["omarchy-launch-tui", command])
  }

  function openDependencyPage(id) {
    var info = Model.dependencyInfo(id)
    if (!info || !/^https:\/\/github\.com\//.test(String(info.url || ""))) return
    Quickshell.execDetached(["omarchy-launch-browser", info.url])
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

              Row {
                spacing: Style.space(4)

                Button {
                  text: root.textFor("system")
                  selected: root.activeTab === "system"
                  foreground: root.barForeground
                  fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                  fontSize: Style.font.caption
                  horizontalPadding: Style.space(6)
                  verticalPadding: Style.space(2)
                  onClicked: root.activeTab = "system"
                }

                Button {
                  text: root.textFor("dependencies")
                  selected: root.activeTab === "dependencies"
                  foreground: root.barForeground
                  fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                  fontSize: Style.font.caption
                  horizontalPadding: Style.space(6)
                  verticalPadding: Style.space(2)
                  onClicked: root.activeTab = "dependencies"
                }
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

          Column {
            id: systemTabContent
            visible: root.activeTab === "system"
            width: parent.width
            spacing: Style.space(10)

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

          PanelSeparator { visible: root.systemMetrics && root.systemMetrics.count > 0 }
          PanelSectionHeader {
            visible: root.systemMetrics && root.systemMetrics.count > 0
            text: root.textFor("system").toUpperCase() + " · BTOP"
            foreground: root.barForeground
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
          }

          Repeater {
            model: root.systemMetrics
            delegate: Item {
              id: systemMetricRow
              required property var metric

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

          PanelSeparator { visible: root.gpuMetrics && root.gpuMetrics.count > 0 }
          PanelSectionHeader {
            visible: root.gpuMetrics && root.gpuMetrics.count > 0
            text: root.gpuSectionTitle()
            foreground: root.barForeground
            fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
          }

          Repeater {
            model: root.gpuMetrics
            delegate: Item {
              id: gpuMetricRow
              required property var metric

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

          Column {
            id: dependenciesTabContent
            visible: root.activeTab === "dependencies"
            width: parent.width
            spacing: Style.space(10)

            PanelSeparator { visible: root.dependencies.length > 0 }

            Repeater {
              model: root.dependencies
              delegate: Item {
                id: dependencyRow
                property var dependency: modelData
                property var info: Model.dependencyInfo(dependency.id) || ({
                  name: dependency.id,
                  descriptionKey: "",
                  url: ""
                })

                width: dependenciesTabContent.width
                implicitHeight: Math.max(dependencyLabels.implicitHeight, dependencyStatus.implicitHeight, dependencyPageButton.implicitHeight)

                Column {
                  id: dependencyLabels
                  anchors.left: parent.left
                  anchors.right: dependencyStatus.left
                  anchors.rightMargin: Style.space(12)
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(1)

                  Text {
                    width: parent.width
                    text: dependencyRow.info.name
                    textFormat: Text.PlainText
                    color: root.barForeground
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.body
                    font.bold: true
                    elide: Text.ElideRight
                  }

                  Text {
                    width: parent.width
                    text: root.textFor(dependencyRow.info.descriptionKey)
                    textFormat: Text.PlainText
                    color: Qt.darker(root.barForeground, 1.4)
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                  }
                }

                Text {
                  id: dependencyStatus
                  anchors.right: dependencyPageButton.left
                  anchors.rightMargin: Style.space(8)
                  anchors.verticalCenter: parent.verticalCenter
                  text: dependencyRow.dependency.installed
                    ? root.textFor("installed")
                    : root.textFor("notInstalled")
                  textFormat: Text.PlainText
                  color: dependencyRow.dependency.installed ? "#55c878" : Color.urgent
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }

                Button {
                  id: dependencyPageButton
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.textFor("openGithub")
                  tooltipText: root.textFor("dependencyHint")
                  foreground: root.barForeground
                  fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                  fontSize: Style.font.caption
                  horizontalPadding: Style.space(7)
                  verticalPadding: Style.space(3)
                  bordered: true
                  onClicked: root.openDependencyPage(dependencyRow.dependency.id)
                }
              }
            }

            PanelSeparator { visible: root.dependencies.length > 0 }

            Text {
              width: parent.width
              text: root.textFor("dependencyHint")
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

}
