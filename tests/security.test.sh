#!/usr/bin/env bash

set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
collector="$repo_dir/bin/panel-resources-collect"

snapshot=$(PANEL_RESOURCES_LANG=en "$collector")
snapshot_bytes=$(printf '%s' "$snapshot" | wc -c)
(( snapshot_bytes <= 8192 ))

jq -e '
  .complete == true
  and
  (.metrics | length) <= 16
  and (.dependencies | length) <= 8
  and all(.dependencies[];
    (.id | IN(
      "linux.hwmon", "btop", "zenpower", "k10temp", "coretemp",
      "amdgpu", "amdgpu_top", "nvidia", "nvtop"
    ))
    and (.installed | type) == "boolean"
    and (keys | sort) == (["id", "installed"] | sort)
  )
  and all(.metrics[];
    (.id | IN(
      "cpu.load", "cpu.temp", "cpu.power", "cpu.frequency", "memory.ram", "memory.swap", "disk.root",
      "gpu.load", "gpu.temp", "gpu.edge", "gpu.hotspot", "gpu.memory_temp",
      "gpu.power", "gpu.fan", "gpu.frequency", "gpu.vram"
    ))
    and (.label | length) <= 64
    and (.shortLabel | length) <= 12
    and (.value | length) <= 16
    and (.detail | length) <= 96
    and ([.label, .shortLabel, .value, .detail] | all(test("[<>&[:cntrl:]]") | not))
  )
' >/dev/null <<< "$snapshot"

start_ns=$(date +%s%N)
set +e
/usr/bin/timeout --signal=TERM --kill-after=0.1s 0.2s bash -c 'sleep 10' >/dev/null 2>&1
timeout_status=$?
set -e
elapsed_ms=$(( ($(date +%s%N) - start_ns) / 1000000 ))
[[ $timeout_status == 124 || $timeout_status == 137 ]]
(( elapsed_ms < 2000 ))

! rg -q 'StdioCollector' "$repo_dir/Service.qml"
rg -q '"--watch"' "$repo_dir/Service.qml"
rg -q 'heartbeatTimeoutMs' "$repo_dir/Service.qml"
rg -q 'stdout: SplitParser' "$repo_dir/Service.qml"
rg -q 'stderr: SplitParser' "$repo_dir/Service.qml"
! rg -q 'sleep 0\.12' "$collector"
rg -q -- '--loop-ms=' "$collector"
! rg -q 'Process|collectorProc|collectorDeadline' "$repo_dir/Panel.qml"
rg -q 'serviceFor\(moduleName\)' "$repo_dir/BarWidget.qml"
rg -q 'openPanelIndicatorWidth: root\.implicitWidth' "$repo_dir/BarWidget.qml"
rg -Fq 'width: root.vertical ? Style.space(2) : root.width' "$repo_dir/BarWidget.qml"
rg -Fq 'height: root.vertical ? root.height : Style.space(2)' "$repo_dir/BarWidget.qml"
jq -e '
  (.kinds | index("service")) != null
  and .entryPoints.service == "Service.qml"
' "$repo_dir/manifest.json" >/dev/null
rg -q 'textFormat: Text.PlainText' "$repo_dir/BarWidget.qml"
rg -q 'textFormat: Text.PlainText' "$repo_dir/Panel.qml"
rg -q 'omarchy-launch-browser' "$repo_dir/Panel.qml"
! rg -q 'dependency\.url|modelData\.url' "$repo_dir/Panel.qml"

set +e
watch_output=$(/usr/bin/timeout --signal=TERM --kill-after=0.5s 2.5s \
  "$collector" --watch --interval-ms 1000 --enabled-metrics cpu.load,cpu.temp 2>/dev/null)
watch_status=$?
set -e
[[ $watch_status == 124 || $watch_status == 137 ]]
(( $(wc -l <<< "$watch_output") >= 2 ))
jq -s -e '
  .[0].complete == true
  and .[1].complete == false
  and all(.[1].metrics[]; .id == "cpu.load" or .id == "cpu.temp")
' >/dev/null <<< "$watch_output"

printf 'Security boundary tests passed\n'
