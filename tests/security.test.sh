#!/usr/bin/env bash

set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
collector="$repo_dir/bin/panel-resources-collect"

snapshot=$(PANEL_RESOURCES_LANG=en "$collector")
snapshot_bytes=$(printf '%s' "$snapshot" | wc -c)
(( snapshot_bytes <= 8192 ))

jq -e '
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
rg -q 'command: \["/usr/bin/timeout", "--signal=TERM", "--kill-after=0.5s", "2s"' "$repo_dir/Service.qml"
rg -q 'stdout: SplitParser' "$repo_dir/Service.qml"
rg -q 'stderr: SplitParser' "$repo_dir/Service.qml"
! rg -q 'Process|collectorProc|collectorDeadline' "$repo_dir/Panel.qml"
rg -q 'serviceFor\(moduleName\)' "$repo_dir/BarWidget.qml"
jq -e '
  (.kinds | index("service")) != null
  and .entryPoints.service == "Service.qml"
' "$repo_dir/manifest.json" >/dev/null
rg -q 'textFormat: Text.PlainText' "$repo_dir/BarWidget.qml"
rg -q 'textFormat: Text.PlainText' "$repo_dir/Panel.qml"
rg -q 'omarchy-launch-browser' "$repo_dir/Panel.qml"
! rg -q 'dependency\.url|modelData\.url' "$repo_dir/Panel.qml"

printf 'Security boundary tests passed\n'
