const assert = require("node:assert/strict")
const Model = require("../Model.js")

const fallback = Model.safeSnapshot("not-json")
assert.deepEqual(fallback.metrics, [])
assert.equal(fallback.gpuVendor, "none")
assert.equal(fallback.language, "en")

assert.equal(Model.normalizeLanguage("ru_RU.UTF-8"), "ru")
assert.equal(Model.normalizeLanguage("en_US.UTF-8"), "en")
assert.equal(Model.normalizeLanguage("de_DE.UTF-8"), "en")
assert.equal(Model.textFor("ru", "showOnBar"), "Показать на панели")
assert.equal(Model.textFor("en", "showOnBar"), "Show on bar")
assert.equal(Model.metricValueTemplate("cpu.load"), "100%")
assert.equal(Model.metricValueTemplate("gpu.hotspot"), "100°C")
assert.equal(Model.metricValueTemplate("gpu.fan"), "9999RPM")

const snapshot = Model.safeSnapshot(JSON.stringify({
  language: "ru_RU",
  gpuVendor: "amd",
  gpuTool: "amdgpu_top",
  metrics: [
    { id: "cpu.load", kind: "system" },
    { id: "gpu.hotspot", kind: "gpu" },
    { id: "gpu.power", kind: "gpu" }
  ]
}))

assert.equal(snapshot.gpuVendor, "amd")
assert.equal(snapshot.language, "ru")
assert.equal(Model.metricsForKind(snapshot.metrics, "gpu").length, 2)
assert.equal(Model.isEnabled({}, "cpu.load"), true)
assert.equal(Model.isEnabled({}, "gpu.hotspot"), true)
assert.equal(Model.isEnabled({}, "gpu.power"), false)
assert.equal(Model.isEnabled({ "gpu.power": true }, "gpu.power"), true)
assert.equal(Model.isEnabled({ "cpu.load": false }, "cpu.load"), false)
assert.equal(Model.visibleMetrics(snapshot.metrics, {}).length, 2)
assert.equal(Model.metricById(snapshot.metrics, "gpu.hotspot").kind, "gpu")

console.log("Model tests passed")
