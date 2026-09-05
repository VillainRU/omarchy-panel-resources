#!/usr/bin/env bash
# Exercise the real loop with an in-memory NVIDIA backend; no system changes.
source <(sed -e '/^previous_cpu_total=""; previous_cpu_idle=""/,$d' \
  -e 's/^apply_control()/production_control()/' bin/panel-resources-collect)
fixture_fault=false
discover_cpu() { cpu_temp_path=fixture; cpu_temp_detail=fixture; }
read_number_into() {
  [[ $fixture_fault == false ]] || return 1
  printf -v "$1" '%s' 45000
}
# Preserve the production CONFIG parser; add fault injection only in the fixture.
apply_control() {
  case "$1" in
    FAULT) fixture_fault=true ;;
    RECOVER) fixture_fault=false ;;
    *) production_control "$1" ;;
  esac
}
discover_gpu() {
  gpu_vendor=nvidia; gpu_tool=nvtop; nvidia_smi_available=true
}
start_nvidia_stream() { nvidia_stream_fd=fixture; nvidia_stream_pid=fixture; }
stop_nvidia_stream() { nvidia_stream_fd=""; nvidia_stream_pid=""; }
read_nvidia_line() {
  [[ -n $nvidia_stream_fd ]] || { printf 'unexpected disabled NVIDIA read\n' >&2; return 1; }
  printf -v "$1" '%s' '10, 45, 100, 1000, 30, 20, 1200'
}
source <(sed -n '/^previous_cpu_total=""; previous_cpu_idle=""/,$p' bin/panel-resources-collect)
