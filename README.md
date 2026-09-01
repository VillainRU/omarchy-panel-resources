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

- System: CPU load, CPU temperature, CPU package power, average CPU frequency, RAM, swap and root disk usage.
- AMD: GPU load, edge temperature, hotspot (`junction`), memory temperature, VRAM, power, fan and clock.
- NVIDIA: GPU load, temperature, VRAM, power, fan and clock.

Only metrics exposed by the current hardware are listed. The **System** tab contains the metric switches, which persist directly in Omarchy's `shell.json` entry for the widget.

The popup follows the system message locale: Russian is used for `ru_*`, while English is the fallback for every other locale. Technical sensor and module names such as `CPU`, `GPU`, `edge` and `junction` are not translated.

Bar metrics use fixed value slots sized for their data type, so the widget does not shift when a reading changes between one, two or three digits. Module padding is kept compact while values remain right-aligned.

## Data and click behavior

The collector reads the same kernel interfaces used by system monitors instead of scraping their terminal UI:

- system metrics: `/proc`, `cpufreq`, `hwmon` and `df`;
- AMD metrics: `amdgpu` DRM/sysfs and labeled `hwmon` sensors;
- NVIDIA metrics: NVML values exposed through `nvidia-smi` (the same backend family used by `nvtop`).

One shared plugin service owns the refresh timer and collector process. Omarchy creates a bar-widget instance for each monitor, but every instance observes the same validated snapshot, so adding monitors does not multiply telemetry processes.

Left-clicking a system metric on the bar opens `btop`. Left-clicking a GPU metric opens `amdgpu_top` for AMD or `nvtop` for NVIDIA through `omarchy-launch-tui`.

The Panel Resources icon opens the popup. Right-clicking it refreshes immediately.

## Dependencies

The **Dependencies** tab reports the locally detected monitoring utilities and kernel drivers. Green means available and red means unavailable. Its GitHub buttons open only static, allowlisted official project pages through Omarchy's configured browser; the plugin never installs packages or runs instructions from a web page.

- Omarchy with the QuickShell plugin system.
- Standard system tools: Bash, `awk`, `df`, `realpath` and access to Linux `/proc` and `/sys` metrics.
- `btop` for the detailed system monitor opened from CPU, memory and disk metrics.
- CPU power uses unprivileged hwmon package-power data. On supported AMD systems, `zenpower` combines the SVI2 Core and SoC rails; other explicit CPU/package, socket or PPT hwmon channels are used as a fallback.
- AMD: `amdgpu_top` for the detailed GPU monitor. Metrics are read from the `amdgpu` DRM and hwmon interfaces.
- NVIDIA: `nvidia-smi` for metrics and `nvtop` for the detailed GPU monitor.

The plugin does not require elevated privileges, network access, a background service or an installer, and it does not overwrite user configuration. Enabling or changing metric switches updates only the widget's own entry in Omarchy `shell.json` through the shell plugin API.

Telemetry collection is bounded by a two-second process deadline and an 8 KiB producer/QML payload ceiling. Only 16 allowlisted metric IDs and eight allowlisted dependency IDs are accepted; dependency URLs and display metadata never come from collector output. All displayed telemetry fields have fixed length limits, control characters and rich-text delimiters are removed, and telemetry-backed QML text is rendered as `Text.PlainText`.

## Validation

```bash
make check
```
