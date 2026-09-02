import QtQuick
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
  readonly property var visibleMetrics: panelLoader.item ? panelLoader.item.visibleBarMetrics : []
  readonly property string language: panelLoader.item
    ? panelLoader.item.language
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
    var tool = metric.kind === "gpu" && panelLoader.item
      ? panelLoader.item.gpuToolDisplayName : "btop"
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

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }
  function refresh() { if (panelLoader.item) panelLoader.item.refresh() }

  implicitWidth: metricsRow.implicitWidth
  implicitHeight: metricsRow.implicitHeight
  readonly property real openPanelIndicatorWidth: root.implicitWidth

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
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
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
      model: root.visibleMetrics

      WidgetButton {
        id: metricButton
        required property var modelData
        bar: root.bar
        text: ""
        hasVisualContent: true
        labelVisible: false
        tooltipText: root.metricTooltip(modelData)
        fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
        fontSize: Style.font.body
        horizontalMargin: 5
        verticalPadding: 8.75
        fixedWidth: metricContent.implicitWidth + scaledHorizontalMargin * 2

        TextMetrics {
          id: metricNameMetrics
          font.family: metricButton.fontFamily
          font.pixelSize: Style.font.caption
          text: metricButton.modelData.shortLabel
        }

        TextMetrics {
          id: metricValueSlotMetrics
          font.family: metricButton.fontFamily
          font.pixelSize: metricButton.fontSize
          text: Model.metricValueTemplate(metricButton.modelData.id)
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
            text: metricButton.modelData.shortLabel
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
            text: metricButton.modelData.value
            textFormat: Text.PlainText
            color: metricButton.foreground
            font.family: metricButton.fontFamily
            font.pixelSize: metricButton.fontSize
            renderType: Text.NativeRendering
          }
        }

        onPressed: function(button) {
          if (button === Qt.LeftButton && panelLoader.item)
            panelLoader.item.launchForMetric(modelData.id)
        }
      }
    }
  }
}
