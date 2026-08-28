function normalizeLanguage(value) {
  var language = String(value || "en").toLowerCase().split(/[_@.-]/)[0]
  return language === "ru" ? "ru" : "en"
}

function languageFromLocale(localeName) {
  return normalizeLanguage(localeName)
}

var translations = {
  en: {
    sensorsNotFound: "No sensors detected",
    collectionError: "Failed to collect sensor data",
    gpuMonitor: "GPU monitor",
    graphicsCard: "Graphics card",
    system: "System",
    systemMetrics: "System metrics",
    refreshSensors: "Refresh sensors",
    removeFromBar: "Remove from bar",
    showOnBar: "Show on bar",
    selectorHint: "The switch adds a metric to the bar. Left-click a bar metric to open its detailed monitor.",
    chooseMetrics: "choose metrics",
    leftClickOpen: "Left click: open"
  },
  ru: {
    sensorsNotFound: "Датчики не обнаружены",
    collectionError: "Ошибка сбора датчиков",
    gpuMonitor: "Монитор GPU",
    graphicsCard: "Видеокарта",
    system: "Система",
    systemMetrics: "Системные показатели",
    refreshSensors: "Обновить датчики",
    removeFromBar: "Убрать с панели",
    showOnBar: "Показать на панели",
    selectorHint: "Тумблер добавляет показатель на панель. ЛКМ по показателю на панели открывает подробный монитор.",
    chooseMetrics: "выбрать показатели",
    leftClickOpen: "ЛКМ: открыть"
  }
}

function textFor(language, key) {
  var normalized = normalizeLanguage(language)
  var dictionary = translations[normalized] || translations.en
  return Object.prototype.hasOwnProperty.call(dictionary, key) ? dictionary[key] : key
}

var MAX_SNAPSHOT_CHARS = 8192
var MAX_METRICS = 16
var metricKinds = {
  "cpu.load": "system",
  "cpu.temp": "system",
  "cpu.frequency": "system",
  "memory.ram": "system",
  "memory.swap": "system",
  "disk.root": "system",
  "gpu.load": "gpu",
  "gpu.temp": "gpu",
  "gpu.edge": "gpu",
  "gpu.hotspot": "gpu",
  "gpu.memory_temp": "gpu",
  "gpu.power": "gpu",
  "gpu.fan": "gpu",
  "gpu.frequency": "gpu",
  "gpu.vram": "gpu"
}

function sanitizeText(value, maxLength) {
  var limit = Math.max(0, Math.min(256, Number(maxLength) || 0))
  if (limit === 0) return ""
  return String(value === undefined || value === null ? "" : value)
    .replace(/[\u0000-\u001f\u007f-\u009f]/g, " ")
    .replace(/[<>&]/g, "")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, limit)
}

function expectedMetricKind(id) {
  return Object.prototype.hasOwnProperty.call(metricKinds, id) ? metricKinds[id] : ""
}

function metricValueTemplate(id) {
  switch (String(id || "")) {
    case "cpu.load":
    case "memory.ram":
    case "memory.swap":
    case "disk.root":
    case "gpu.load":
    case "gpu.vram":
      return "100%"
    case "cpu.temp":
    case "gpu.temp":
    case "gpu.edge":
    case "gpu.hotspot":
    case "gpu.memory_temp":
      return "100°C"
    case "cpu.frequency":
      return "10.0GHz"
    case "gpu.power":
      return "9999W"
    case "gpu.fan":
      return "9999RPM"
    case "gpu.frequency":
      return "9999MHz"
    default:
      return "9999"
  }
}

function safeSnapshot(raw) {
  var fallback = {
    version: 1,
    language: "en",
    gpuVendor: "none",
    gpuTool: "",
    gpuName: "",
    metrics: []
  }

  try {
    var rawText = String(raw || "")
    if (rawText.length === 0 || rawText.length > MAX_SNAPSHOT_CHARS) return fallback
    var parsed = JSON.parse(rawText)
    if (!parsed || typeof parsed !== "object") return fallback
    var vendor = sanitizeText(parsed.gpuVendor, 8).toLowerCase()
    if (vendor !== "amd" && vendor !== "nvidia") vendor = "none"

    var result = {
      version: 1,
      language: normalizeLanguage(parsed.language),
      gpuVendor: vendor,
      gpuTool: vendor === "amd" ? "amdgpu_top" : (vendor === "nvidia" ? "nvtop" : ""),
      gpuName: sanitizeText(parsed.gpuName, 64),
      metrics: []
    }
    if (!Array.isArray(parsed.metrics)) return result

    var seen = {}
    for (var i = 0; i < parsed.metrics.length && result.metrics.length < MAX_METRICS; i++) {
      var metric = parsed.metrics[i]
      if (!metric || typeof metric !== "object" || Array.isArray(metric)) continue
      var id = sanitizeText(metric.id, 48)
      var kind = expectedMetricKind(id)
      if (kind === "" || seen[id]) continue

      var label = sanitizeText(metric.label, 64)
      var shortLabel = sanitizeText(metric.shortLabel, 12)
      var value = sanitizeText(metric.value, 16)
      var detail = sanitizeText(metric.detail, 96)
      if (label === "" || shortLabel === "" || value === "") continue

      seen[id] = true
      result.metrics.push({
        id: id,
        kind: kind,
        label: label,
        shortLabel: shortLabel,
        value: value,
        detail: detail
      })
    }
    return result
  } catch (e) {
    return fallback
  }
}

function normalizeEnabled(value) {
  var result = {}
  if (!value || typeof value !== "object" || Array.isArray(value)) return result
  for (var key in value) {
    if (expectedMetricKind(key) !== "") result[key] = value[key] === true
  }
  return result
}

function defaultEnabled(id) {
  return id === "cpu.load"
    || id === "cpu.temp"
    || id === "gpu.load"
    || id === "gpu.hotspot"
    || id === "gpu.temp"
}

function isEnabled(enabled, id) {
  if (enabled && Object.prototype.hasOwnProperty.call(enabled, id)) return enabled[id] === true
  return defaultEnabled(id)
}

function metricsForKind(metrics, kind) {
  var result = []
  if (!Array.isArray(metrics)) return result
  for (var i = 0; i < metrics.length; i++) {
    if (metrics[i] && metrics[i].kind === kind) result.push(metrics[i])
  }
  return result
}

function visibleMetrics(metrics, enabled) {
  var result = []
  if (!Array.isArray(metrics)) return result
  for (var i = 0; i < metrics.length; i++) {
    var metric = metrics[i]
    if (metric && isEnabled(enabled, metric.id)) result.push(metric)
  }
  return result
}

function metricById(metrics, id) {
  if (!Array.isArray(metrics)) return null
  for (var i = 0; i < metrics.length; i++) {
    if (metrics[i] && metrics[i].id === id) return metrics[i]
  }
  return null
}

if (typeof module !== "undefined") {
  module.exports = {
    normalizeLanguage: normalizeLanguage,
    languageFromLocale: languageFromLocale,
    textFor: textFor,
    sanitizeText: sanitizeText,
    expectedMetricKind: expectedMetricKind,
    metricValueTemplate: metricValueTemplate,
    safeSnapshot: safeSnapshot,
    normalizeEnabled: normalizeEnabled,
    defaultEnabled: defaultEnabled,
    isEnabled: isEnabled,
    metricsForKind: metricsForKind,
    visibleMetrics: visibleMetrics,
    metricById: metricById
  }
}
