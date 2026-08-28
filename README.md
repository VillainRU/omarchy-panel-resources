# Panel Resources

Omarchy QuickShell bar widget with individually selectable system and GPU metrics.

![Panel Resources preview](preview.png)

## Installation

```bash
omarchy plugin add https://github.com/VillainRU/omarchy-panel-resources.git --enable
```

If the plugin was added without `--enable`, place it on the right side of the bar:

```bash
omarchy plugin enable io.github.villainru.panel-resources right
```

## Removal

```bash
omarchy plugin remove io.github.villainru.panel-resources
```

## Metrics

- System: CPU load, CPU temperature, average CPU frequency, RAM, swap and root disk usage.
- AMD: GPU load, edge temperature, hotspot (`junction`), memory temperature, VRAM, power, fan and clock.
- NVIDIA: GPU load, temperature, VRAM, power, fan and clock.

Only metrics exposed by the current hardware are listed. Switches in the popup persist directly in Omarchy's `shell.json` entry for the widget.

The popup follows the system message locale: Russian is used for `ru_*`, while English is the fallback for every other locale. Technical sensor and module names such as `CPU`, `GPU`, `edge` and `junction` are not translated.

Bar metrics use fixed value slots sized for their data type, so the widget does not shift when a reading changes between one, two or three digits. Module padding is kept compact while values remain right-aligned.

## Data and click behavior

The collector reads the same kernel interfaces used by system monitors instead of scraping their terminal UI:

- system metrics: `/proc`, `cpufreq`, `hwmon` and `df`;
- AMD metrics: `amdgpu` DRM/sysfs and labeled `hwmon` sensors;
- NVIDIA metrics: NVML values exposed through `nvidia-smi` (the same backend family used by `nvtop`).

Left-clicking a system metric on the bar opens `btop`. Left-clicking a GPU metric opens `amdgpu_top` for AMD or `nvtop` for NVIDIA through `omarchy-launch-tui`.

The Panel Resources icon opens the metric selector. Right-clicking it refreshes immediately.

## Dependencies

- Omarchy with the QuickShell plugin system.
- Standard system tools: Bash, `awk`, `df`, `realpath` and access to Linux `/proc` and `/sys` metrics.
- `btop` for the detailed system monitor opened from CPU, memory and disk metrics.
- AMD: `amdgpu_top` for the detailed GPU monitor. Metrics are read from the `amdgpu` DRM and hwmon interfaces.
- NVIDIA: `nvidia-smi` for metrics and `nvtop` for the detailed GPU monitor.

The plugin does not require `sudo`, network access, a background service or an installer, and it does not overwrite user configuration. Enabling or changing metric switches updates only the widget's own entry in Omarchy `shell.json` through the shell plugin API.

## Validation

```bash
make check
```
