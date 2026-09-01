const assert = require("node:assert/strict")
const Model = require("../Model.js")

const fallback = Model.safeSnapshot("not-json")
assert.deepEqual(fallback.metrics, [])
assert.deepEqual(fallback.dependencies, [])
assert.equal(fallback.gpuVendor, "none")
assert.equal(fallback.language, "en")

assert.equal(Model.normalizeLanguage("ru_RU.UTF-8"), "ru")
assert.equal(Model.normalizeLanguage("en_US.UTF-8"), "en")
assert.equal(Model.normalizeLanguage("de_DE.UTF-8"), "en")
assert.equal(Model.textFor("ru", "showOnBar"), "Показать на панели")
assert.equal(Model.textFor("en", "showOnBar"), "Show on bar")
assert.equal(Model.textFor("ru", "dependencies"), "Зависимости")
assert.equal(Model.metricValueTemplate("cpu.load"), "100%")
assert.equal(Model.metricValueTemplate("gpu.hotspot"), "100°C")
assert.equal(Model.metricValueTemplate("gpu.fan"), "9999RPM")
assert.equal(Model.metricValueTemplate("cpu.power"), "999W")
assert.equal(Model.normalizeRefreshIntervalMs(undefined), 2000)
assert.equal(Model.normalizeRefreshIntervalMs(0), 2000)
assert.equal(Model.normalizeRefreshIntervalMs("10"), 10000)
assert.equal(Model.normalizeRefreshIntervalMs(60), 30000)
assert.equal(
  Model.enabledMetricCsv({}),
  "cpu.load,cpu.temp,gpu.load,gpu.temp,gpu.hotspot"
)
assert.equal(Model.enabledMetricCsv({ "cpu.load": false, "gpu.power": true }), "cpu.temp,gpu.load,gpu.temp,gpu.hotspot,gpu.power")

const snapshot = Model.safeSnapshot(JSON.stringify({
  language: "ru_RU",
  gpuVendor: "amd",
  gpuTool: "amdgpu_top",
  dependencies: [
    { id: "linux.hwmon", installed: true },
    { id: "btop", installed: false },
    { id: "amdgpu", installed: true },
    { id: "amdgpu_top", installed: true }
  ],
  metrics: [
    { id: "cpu.load", kind: "system", label: "CPU load", shortLabel: "CPU", value: "8%", detail: "All cores" },
    { id: "cpu.power", kind: "system", label: "CPU power", shortLabel: "CPU W", value: "40W", detail: "zenpower" },
    { id: "gpu.hotspot", kind: "gpu", label: "GPU Hotspot", shortLabel: "HOT", value: "36°C", detail: "junction" },
    { id: "gpu.power", kind: "gpu", label: "GPU power", shortLabel: "GPU W", value: "41W", detail: "PPT" }
  ]
}))

assert.equal(snapshot.gpuVendor, "amd")
assert.equal(snapshot.language, "ru")
assert.equal(snapshot.dependencies.length, 4)
assert.equal(snapshot.dependencies[1].id, "btop")
assert.equal(snapshot.dependencies[1].installed, false)
assert.equal(Model.dependencyInfo("btop").name, "btop")
assert.match(Model.dependencyInfo("btop").url, /^https:\/\/github\.com\//)
assert.equal(Model.dependencyInfo("unknown"), null)
assert.equal(Model.metricsForKind(snapshot.metrics, "gpu").length, 2)
assert.equal(Model.isEnabled({}, "cpu.load"), true)
assert.equal(Model.isEnabled({}, "gpu.hotspot"), true)
assert.equal(Model.isEnabled({}, "gpu.power"), false)
assert.equal(Model.isEnabled({ "gpu.power": true }, "gpu.power"), true)
assert.equal(Model.isEnabled({ "cpu.load": false }, "cpu.load"), false)
assert.equal(Model.visibleMetrics(snapshot.metrics, {}).length, 2)
assert.equal(Model.metricById(snapshot.metrics, "gpu.hotspot").kind, "gpu")
assert.equal(Model.metricById(snapshot.metrics, "cpu.power").kind, "system")

const partial = Model.safeSnapshot(JSON.stringify({
  complete: false,
  language: "ru",
  gpuVendor: "amd",
  dependencies: [{ id: "btop", installed: true }],
  metrics: [
    { id: "cpu.load", kind: "system", label: "CPU load", shortLabel: "CPU", value: "42%", detail: "All cores" }
  ]
}))
const merged = Model.mergeSnapshot(snapshot, partial)
assert.equal(merged.metrics.length, snapshot.metrics.length)
assert.equal(Model.metricById(merged.metrics, "cpu.load").value, "42%")
assert.equal(Model.metricById(merged.metrics, "gpu.hotspot").value, "36°C")
assert.equal(merged.complete, false)

const hostileMetrics = []
for (let i = 0; i < 4; i++) {
  hostileMetrics.push({
    id: i === 0 ? "cpu.load" : (i % 2 ? "gpu.load" : "unknown." + i),
    kind: "attacker",
    label: "<b>Load</b>\u0000" + "x".repeat(100),
    shortLabel: "<CPU>&" + "x".repeat(20),
    value: "<img src=x>99%\n",
    detail: "\u001b[31m<script>alert(1)</script>" + "d".repeat(200)
  })
}
const hostile = Model.safeSnapshot(JSON.stringify({
  language: "en",
  gpuVendor: "nvidia<script>",
  gpuTool: "sh",
  gpuName: "<b>GPU</b>\u0007",
  dependencies: [
    { id: "btop", installed: "yes", url: "file:///etc/passwd", name: "attacker" },
    { id: "unknown", installed: true, url: "https://evil.example" },
    { id: "btop", installed: true }
  ],
  metrics: hostileMetrics
}))
assert.equal(hostile.gpuVendor, "none")
assert.equal(hostile.gpuTool, "")
assert.equal(hostile.metrics.length, 2)
assert.deepEqual(hostile.dependencies, [{ id: "btop", installed: false }])
for (const metric of hostile.metrics) {
  assert.equal(Model.expectedMetricKind(metric.id), metric.kind)
  assert.ok(metric.label.length <= 64)
  assert.ok(metric.shortLabel.length <= 12)
  assert.ok(metric.value.length <= 16)
  assert.ok(metric.detail.length <= 96)
  assert.doesNotMatch(metric.label + metric.shortLabel + metric.value + metric.detail, /[<>&\u0000-\u001f\u007f-\u009f]/)
}
assert.deepEqual(Model.safeSnapshot("x".repeat(8193)).metrics, [])
assert.deepEqual(Model.normalizeEnabled({ "cpu.load": true, "evil.metric": true }), { "cpu.load": true })

console.log("Model tests passed")
