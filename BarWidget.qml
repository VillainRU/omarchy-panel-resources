import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "io.github.villainru.panel-resources"

  readonly property var collectorService: bar && bar.shell
    && typeof bar.shell.serviceFor === "function"
    ? bar.shell.serviceFor(moduleName) : null
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  property bool panelRequested: false
  readonly property string language: collectorService
    ? collectorService.snapshot.language
    : Model.languageFromLocale(Qt.locale().name)

  function textFor(key) { return Model.textFor(language, key) }

  function configureService() {
    if (collectorService && typeof collectorService.configure === "function")
      collectorService.configure(settings || ({}))
  }

  function metricTooltip(metric) {
    var label = Model.sanitizeText(metric.label, 64)
    var value = Model.sanitizeText(metric.value, 16)
    var detail = Model.sanitizeText(metric.detail, 96)
    var tool = metric.kind === "gpu" && collectorService
      ? collectorService.snapshot.gpuTool : "btop"
    return label + ": " + value
      + (detail !== "" ? "\n" + detail : "")
      + "\n" + textFor("leftClickOpen") + " " + tool
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = menuButton
    if ("hostWidget" in target) target.hostWidget = root
    if ("service" in target) target.service = root.collectorService
  }

  function open() {
    panelRequested = true
    if (panelLoader.item) panelLoader.item.open()
    else panelLoader.active = true
  }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel() { if (opened) close(); else open() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }
  function refresh() { if (collectorService) collectorService.refresh() }
  function launchForMetric(metric) {
    var command = metric.kind === "gpu" && collectorService ? collectorService.snapshot.gpuTool : "btop"
    if (command) Quickshell.execDetached(["omarchy-launch-tui", command])
  }
  onOpenedChanged: {
    if (collectorService) collectorService.setPanelOpen(root, opened)
  }
  Component.onDestruction: {
    if (collectorService) collectorService.setPanelOpen(root, false)
  }

  implicitWidth: metricsRow.implicitWidth
  implicitHeight: metricsRow.implicitHeight
  // Omarchy rounds positive hints to pixels. Suppress its mark because this
  // widget paints its own full-width indicator (including older host versions).
  readonly property real openPanelIndicatorWidth: 0.001
  readonly property real openPanelIndicatorHeight: 0.001

  Rectangle {
    id: activePanelIndicator

    readonly property int inset: Style.space(2)

    visible: root.opened
    opacity: 0.9
    color: Color.accent
    radius: Math.min(width, height) / 2
    width: root.vertical ? Style.space(2) : root.width
    height: root.vertical ? root.height : Style.space(2)
    x: root.vertical
      ? (root.bar && root.bar.position === "left" ? root.width - width - inset : inset)
      : 0
    y: root.vertical
      ? 0
      : (root.bar && root.bar.position === "top" ? root.height - height - inset : inset)
    z: 50
  }

  onBarChanged: {
    injectPanel()
    configureService()
  }
  onSettingsChanged: {
    injectPanel()
    configureService()
  }
  onCollectorServiceChanged: {
    injectPanel()
    configureService()
  }

  Component.onCompleted: configureService()

  Loader {
    id: panelLoader
    active: false
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      if (root.panelRequested) item.open()
    }
  }

  Row {
    id: metricsRow
    anchors.centerIn: parent
    spacing: Style.space(1)

    BarIconButton {
      id: menuButton
      bar: root.bar
      text: "󰍛"
      active: root.opened
      tooltipText: "Panel Resources — " + root.textFor("chooseMetrics")
      onPressed: function(button) {
        if (button === Qt.RightButton) root.refresh()
        else root.togglePanel()
      }
    }

    Repeater {
      model: root.collectorService ? root.collectorService.barModel : null

      WidgetButton {
        id: metricButton
        required property var metric
        bar: root.bar
        text: ""
        hasVisualContent: true
        labelVisible: false
        tooltipText: root.metricTooltip(metric)
        fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
        fontSize: Style.font.body
        horizontalMargin: 5
        verticalPadding: 8.75
        fixedWidth: metricContent.implicitWidth + scaledHorizontalMargin * 2

        TextMetrics {
          id: metricNameMetrics
          font.family: metricButton.fontFamily
          font.pixelSize: Style.font.caption
          text: metricButton.metric.shortLabel
        }

        TextMetrics {
          id: metricValueSlotMetrics
          font.family: metricButton.fontFamily
          font.pixelSize: metricButton.fontSize
          text: Model.metricValueTemplate(metricButton.metric.id)
        }

        Item {
          id: metricContent
          anchors.centerIn: parent
          implicitWidth: metricNameMetrics.advanceWidth
            + Style.space(3)
            + metricValueSlotMetrics.advanceWidth
          implicitHeight: metricValue.implicitHeight
          width: implicitWidth
          height: implicitHeight

          Text {
            id: metricName
            anchors.left: parent.left
            anchors.baseline: metricValue.baseline
            text: metricButton.metric.shortLabel
            textFormat: Text.PlainText
            color: metricButton.foreground
            font.family: metricButton.fontFamily
            font.pixelSize: Style.font.caption
            renderType: Text.NativeRendering
          }

          Text {
            id: metricValue
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: metricButton.metric.value
            textFormat: Text.PlainText
            color: metricButton.foreground
            font.family: metricButton.fontFamily
            font.pixelSize: metricButton.fontSize
            renderType: Text.NativeRendering
          }
        }

        onPressed: function(button) {
          if (button === Qt.LeftButton) root.launchForMetric(metric)
        }
      }
    }
  }
}
