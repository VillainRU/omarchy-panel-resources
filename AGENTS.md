# Repository Guidelines

## Project Structure & Module Organization

This repository contains one Omarchy QuickShell bar plugin. `Service.qml` owns the single shared persistent collector and merged snapshot. `BarWidget.qml` renders compact bar metrics, while `Panel.qml` provides the popup and settings UI. Shared parsing, localization, allowlists, snapshot merging, and display helpers live in `Model.js`. Hardware collection is isolated in the executable `bin/panel-resources-collect`; its watch mode caches hardware discovery and samples only enabled metrics after the initial inventory. Plugin metadata belongs in `manifest.json`; user-facing behavior and dependencies are documented in `README.md`. `preview.png` is the marketplace image. Tests live under `tests/`: JavaScript model tests in `model.test.js` and shell/security boundary checks in `security.test.sh`.

## Build, Test, and Development Commands

- `make check` runs the complete validation suite: JSON and Bash syntax checks, Node tests, security tests, locale/output assertions, `qmllint`, and `omarchy plugin validate .`.
- `node tests/model.test.js` quickly exercises parsing, localization, defaults, and hostile-input handling.
- `node tests/collector.test.js` exercises live control messages, popup polling, a simulated NVIDIA backend, sensor failures, and EOF shutdown.
- `node tests/runtime.test.js` runs an isolated offscreen Quickshell service to check stable delegates, configuration without restarts, and error recovery.
- `bash tests/security.test.sh` verifies output limits, allowlists, timeouts, plain-text rendering, and safe URL handling.
- `PANEL_RESOURCES_LANG=en bin/panel-resources-collect | jq .` inspects a live collector snapshot; use `ru` to check Russian labels.
- `qmllint BarWidget.qml Panel.qml Service.qml` checks QML without launching the shell.

Run `make check` before every commit or pull request. The plugin has no compiled build artifact.

## Coding Style & Naming Conventions

Use two-space indentation in QML, JavaScript, and Bash. Follow existing semicolon-free JavaScript style. Name QML/JavaScript functions and properties in `camelCase`; use `snake_case` for Bash functions and local variables. Keep QML IDs descriptive (`metricButton`, `panelLoader`) and metric IDs namespaced (`cpu.load`, `gpu.power`). Add English and Russian strings together in `Model.js`. Format shell code for Bash and quote paths and expansions unless arithmetic or pattern matching requires otherwise.

## Testing Guidelines

Add model assertions for new parsing or UI-data behavior and extend security tests whenever collectors, commands, URLs, or rendering boundaries change. Preserve the 8 KiB payload ceiling, metric/dependency count limits, fixed field lengths, allowlisted IDs, and `Text.PlainText` rendering. There is no numeric coverage target; regressions must receive focused tests.

## Commit & Pull Request Guidelines

History uses short, imperative subjects such as `Add dependencies tab` and `Bound telemetry collection and rendering`. Keep each commit focused. Pull requests should explain user-visible behavior, list validation performed, note hardware-specific assumptions, and include an updated screenshot for UI changes. Update `manifest.json` version and `README.md` when release behavior or dependencies change; never commit credentials, generated telemetry, or machine-specific paths.
