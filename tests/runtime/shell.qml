import QtQuick
import Quickshell
import "." as Plugin

ShellRoot {
  id: test
  property int phase: 0
  property int ticks: 0
  property int created: 0
  property int initialCreated: 0
  property double previousUpdate: 0
  property var initialPid: null

  function check(condition, message) {
    if (!condition) {
      console.error("RUNTIME FAIL: " + message)
      Qt.quit()
      return false
    }
    return true
  }

  Plugin.Service {
    id: service
    manifest: ({ __sourceDir: Quickshell.env("PANEL_RESOURCES_TEST_REPO") })
  }

  Item {
    Repeater {
      model: service.barModel
      Item {
        required property var metric
        Component.onCompleted: test.created++
      }
    }
    Repeater {
      model: service.barModel
      Item {
        required property var metric
        Component.onCompleted: test.created++
      }
    }
  }

  Timer {
    interval: 200
    running: true
    repeat: true
    onTriggered: {
      test.ticks++
      if (test.ticks > 100) { test.check(false, "deadline"); return }
      if (test.phase === 0 && service.lastUpdated > 0) {
        test.initialPid = service.collectorPid
        service.configure({ refreshIntervalSec: 1 })
        service.setPanelOpen(test, true)
        test.previousUpdate = service.lastUpdated
        test.phase = 1
      } else if (test.phase === 1 && service.lastUpdated > test.previousUpdate) {
        if (!test.check(service.systemModel.count > 0, "popup inventory")) return
        test.initialCreated = test.created
        test.previousUpdate = service.lastUpdated
        test.phase = 2
      } else if (test.phase === 2 && service.lastUpdated > test.previousUpdate) {
        if (!test.check(service.collectorPid === test.initialPid, "configuration restarted collector")) return
        if (!test.check(test.created === test.initialCreated, "delegates recreated on telemetry")) return
        service.setPanelOpen(test, false)
        service.captureCollectorOutput("not-json")
        if (!test.check(service.errorKey === "collectionError", "invalid JSON accepted")) return
        if (!test.check(service.barModel.get(0).metric.value === "—", "old value after error")) return
        test.previousUpdate = service.lastUpdated
        test.phase = 3
      } else if (test.phase === 3 && service.lastUpdated > test.previousUpdate) {
        if (!test.check(service.errorKey === "", "recovery failed")) return
        if (!test.check(service.collectorPid !== test.initialPid, "failed collector not replaced")) return
        console.log("RUNTIME PASS: shared models, stable delegates, popup, malformed input and recovery")
        Qt.quit()
      }
    }
  }
}
