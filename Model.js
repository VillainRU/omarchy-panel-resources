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
    dependencies: "Dependencies",
    systemMetrics: "System metrics",
    refreshSensors: "Refresh sensors",
    removeFromBar: "Remove from bar",
    showOnBar: "Show on bar",
    selectorHint: "The switch adds a metric to the bar. Left-click a bar metric to open its detailed monitor.",
    chooseMetrics: "choose metrics",
    leftClickOpen: "Left click: open",
    installed: "Installed",
    notInstalled: "Not installed",
    openGithub: "GitHub",
    dependencyHint: "Statuses are detected locally. GitHub opens the official project page; nothing is installed automatically.",
    dependencyLinux: "Kernel interfaces used for system sensor data",
    dependencyBtop: "Detailed system monitor opened from CPU metrics",
    dependencyZenpower: "AMD CPU temperature and power driver",
    dependencyK10temp: "AMD CPU temperature driver",
    dependencyCoretemp: "Intel CPU temperature driver",
    dependencyAmdgpu: "AMD GPU sensor driver",
    dependencyAmdgpuTop: "Detailed AMD GPU monitor",
    dependencyNvidia: "NVIDIA driver and nvidia-smi sensor utility",
    dependencyNvtop: "Detailed NVIDIA GPU monitor"
  },
  ru: {
    sensorsNotFound: "Датчики не обнаружены",
    collectionError: "Ошибка сбора датчиков",
    gpuMonitor: "Монитор GPU",
    graphicsCard: "Видеокарта",
    system: "Система",
    dependencies: "Зависимости",
    systemMetrics: "Системные показатели",
    refreshSensors: "Обновить датчики",
    removeFromBar: "Убрать с панели",
    showOnBar: "Показать на панели",
    selectorHint: "Тумблер добавляет показатель на панель. ЛКМ по показателю на панели открывает подробный монитор.",
    chooseMetrics: "выбрать показатели",
    leftClickOpen: "ЛКМ: открыть",
    installed: "Установлено",
    notInstalled: "Не установлено",
    openGithub: "GitHub",
    dependencyHint: "Статусы определяются локально. GitHub открывает официальную страницу проекта; автоматическая установка не выполняется.",
    dependencyLinux: "Интерфейсы ядра для системных датчиков",
    dependencyBtop: "Подробный монитор системы, открываемый из показателей CPU",
    dependencyZenpower: "Драйвер температуры и потребления процессоров AMD",
    dependencyK10temp: "Драйвер температуры процессоров AMD",
    dependencyCoretemp: "Драйвер температуры процессоров Intel",
    dependencyAmdgpu: "Драйвер датчиков видеокарт AMD",
    dependencyAmdgpuTop: "Подробный монитор видеокарт AMD",
    dependencyNvidia: "Драйвер NVIDIA и утилита датчиков nvidia-smi",
    dependencyNvtop: "Подробный монитор видеокарт NVIDIA"
  }
}

function textFor(language, key) {
  var normalized = normalizeLanguage(language)
  var dictionary = translations[normalized] || translations.en
  return Object.prototype.hasOwnProperty.call(dictionary, key) ? dictionary[key] : key
}

var MAX_SNAPSHOT_CHARS = 8192
var MAX_METRICS = 16
var MAX_DEPENDENCIES = 8
var metricKinds = {
  "cpu.load": "system",
  "cpu.temp": "system",
  "cpu.power": "system",
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

var dependencyCatalog = {
  "linux.hwmon": {
    name: "Linux hwmon / sysfs",
    descriptionKey: "dependencyLinux",
    url: "https://github.com/torvalds/linux"
  },
  "btop": {
    name: "btop",
    descriptionKey: "dependencyBtop",
    url: "https://github.com/aristocratos/btop"
  },
  "zenpower": {
    name: "zenpower",
    descriptionKey: "dependencyZenpower",
    url: "https://github.com/AliEmreSenel/zenpower3"
  },
  "k10temp": {
    name: "k10temp",
    descriptionKey: "dependencyK10temp",
    url: "https://github.com/torvalds/linux/blob/master/drivers/hwmon/k10temp.c"
  },
  "coretemp": {
    name: "coretemp",
    descriptionKey: "dependencyCoretemp",
    url: "https://github.com/torvalds/linux/blob/master/drivers/hwmon/coretemp.c"
  },
  "amdgpu": {
    name: "amdgpu",
    descriptionKey: "dependencyAmdgpu",
    url: "https://github.com/torvalds/linux/tree/master/drivers/gpu/drm/amd"
  },
  "amdgpu_top": {
    name: "amdgpu_top",
    descriptionKey: "dependencyAmdgpuTop",
    url: "https://github.com/Umio-Yasuno/amdgpu_top"
  },
  "nvidia": {
    name: "NVIDIA / nvidia-smi",
    descriptionKey: "dependencyNvidia",
    url: "https://github.com/NVIDIA/open-gpu-kernel-modules"
  },
  "nvtop": {
    name: "nvtop",
    descriptionKey: "dependencyNvtop",
    url: "https://github.com/Syllo/nvtop"
  }
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

function dependencyInfo(id) {
  var key = sanitizeText(id, 32)
  return Object.prototype.hasOwnProperty.call(dependencyCatalog, key) ? dependencyCatalog[key] : null
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
    case "cpu.power":
      return "999W"
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

function normalizeRefreshIntervalMs(value) {
  var seconds = Number(value)
  if (!isFinite(seconds) || seconds < 1) seconds = 2
  return Math.round(Math.min(30, seconds)) * 1000
}

function safeSnapshot(raw, previous) {
  var fallback = {
    valid: false,
    version: 1,
    complete: true,
    language: "en",
    gpuVendor: "none",
    gpuTool: "",
    gpuName: "",
    metrics: [],
    dependencies: []
  }

  try {
    var rawText = String(raw || "")
    if (rawText.length === 0 || rawText.length > MAX_SNAPSHOT_CHARS) return fallback
    var parsed = JSON.parse(rawText)
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)
        || !Array.isArray(parsed.metrics)
        || (parsed.version !== undefined && parsed.version !== 1)) return fallback
    var vendor = sanitizeText(parsed.gpuVendor, 8).toLowerCase()
    if (vendor !== "amd" && vendor !== "nvidia") vendor = "none"

    var result = {
      valid: true,
      sampled: typeof parsed.sampled === "string" ? parsed.sampled.split(",").filter(function(id) {
        return expectedMetricKind(id) !== ""
      }) : [],
      version: 1,
      complete: parsed.complete !== false,
      language: normalizeLanguage(parsed.language),
      gpuVendor: vendor,
      gpuTool: vendor === "amd" ? "amdgpu_top" : (vendor === "nvidia" ? "nvtop" : ""),
      gpuName: sanitizeText(parsed.gpuName, 64),
      metrics: [],
      dependencies: parsed.dependencies === undefined ? null : []
    }
    if (Array.isArray(parsed.dependencies)) {
      var seenDependencies = {}
      for (var dependencyIndex = 0;
           dependencyIndex < parsed.dependencies.length && result.dependencies.length < MAX_DEPENDENCIES;
           dependencyIndex++) {
        var dependency = parsed.dependencies[dependencyIndex]
        if (!dependency || typeof dependency !== "object" || Array.isArray(dependency)) continue
        var dependencyId = sanitizeText(dependency.id, 32)
        if (!dependencyInfo(dependencyId) || seenDependencies[dependencyId]) continue
        seenDependencies[dependencyId] = true
        result.dependencies.push({
          id: dependencyId,
          installed: dependency.installed === true
        })
      }
    }
    if (!Array.isArray(parsed.metrics)) return result

    var seen = {}
    for (var i = 0; i < parsed.metrics.length && result.metrics.length < MAX_METRICS; i++) {
      var metric = parsed.metrics[i]
      if (!metric || typeof metric !== "object" || Array.isArray(metric)) continue
      var id = sanitizeText(metric.id, 48)
      var kind = expectedMetricKind(id)
      if (kind === "" || seen[id]) continue
      var cached = parsed.complete === false && previous ? metricById(previous.metrics, id) : null
      var label = sanitizeText(metric.label === undefined && cached ? cached.label : metric.label, 64)
      var shortLabel = sanitizeText(metric.shortLabel === undefined && cached ? cached.shortLabel : metric.shortLabel, 12)
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

function enabledMetricCsv(value) {
  var enabled = normalizeEnabled(value)
  var result = []
  for (var id in metricKinds) {
    if (isEnabled(enabled, id)) result.push(id)
  }
  return result.join(",")
}

function mergeSnapshot(previous, update) {
  if (!update || update.valid === false) return previous
  if (!update || update.complete !== false || !previous || !Array.isArray(previous.metrics)) return update
  var merged = {
    version: 1,
    complete: false,
    language: update.language,
    gpuVendor: update.gpuVendor,
    gpuTool: update.gpuTool,
    gpuName: update.gpuName,
    metrics: [],
    dependencies: update.dependencies === null ? previous.dependencies : update.dependencies
  }
  var replacements = {}
  var index
  for (index = 0; index < update.metrics.length; index++) replacements[update.metrics[index].id] = update.metrics[index]
  for (index = 0; index < previous.metrics.length; index++) {
    var oldMetric = previous.metrics[index]
    var replacement = replacements[oldMetric.id]
    if (!replacement && update.sampled && update.sampled.indexOf(oldMetric.id) !== -1)
      replacement = Object.assign({}, oldMetric, { value: "—", detail: "" })
    merged.metrics.push(replacement || oldMetric)
    delete replacements[oldMetric.id]
  }
  for (index = 0; index < update.metrics.length; index++) {
    var newMetric = update.metrics[index]
    if (Object.prototype.hasOwnProperty.call(replacements, newMetric.id)) merged.metrics.push(newMetric)
  }
  return merged
}

// Keep QML delegates alive: insert/remove only for inventory changes, update a
// row only when its displayed fields differ. Also usable with a test model.
function syncMetricModel(target, metrics) {
  for (var i = 0; i < metrics.length; i++) {
    var next = metrics[i]
    var found = i
    while (found < target.count && target.get(found).metric.id !== next.id) found++
    if (found === target.count) target.insert(i, { metric: next })
    else {
      if (found !== i) target.move(found, i, 1)
      var old = target.get(i).metric
      if (old.value !== next.value || old.detail !== next.detail || old.label !== next.label
          || old.shortLabel !== next.shortLabel || old.kind !== next.kind)
        target.setProperty(i, "metric", next)
    }
  }
  if (target.count > metrics.length) target.remove(metrics.length, target.count - metrics.length)
}

function retryDelay(failures) {
  return [1000, 2000, 5000, 15000][Math.min(3, Math.max(0, failures - 1))]
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
    dependencyInfo: dependencyInfo,
    metricValueTemplate: metricValueTemplate,
    normalizeRefreshIntervalMs: normalizeRefreshIntervalMs,
    safeSnapshot: safeSnapshot,
    normalizeEnabled: normalizeEnabled,
    enabledMetricCsv: enabledMetricCsv,
    mergeSnapshot: mergeSnapshot,
    syncMetricModel: syncMetricModel,
    retryDelay: retryDelay,
    defaultEnabled: defaultEnabled,
    isEnabled: isEnabled,
    metricsForKind: metricsForKind,
    visibleMetrics: visibleMetrics,
    metricById: metricById
  }
}
