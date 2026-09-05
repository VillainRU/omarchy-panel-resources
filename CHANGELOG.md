# Changelog

## 0.5.0

- Update collector settings over stdin without restarting hardware discovery.
- Poll all sensors while any popup is open; otherwise poll selected metrics.
- Keep shared QML model rows and delegates stable, and load popups on first use.
- Cache metric labels, send compact samples, and refresh disk usage every 30 seconds.
- Skip disabled NVIDIA polling; bound automatic rescans and drain old NVIDIA samples.
- Reject malformed snapshots, mark unavailable values, and back off failed restarts.
- Suppress the host indicator when drawing the plugin's full-width underline.
- Test control messages, disabled NVIDIA, sensor failures, EOF shutdown, QML model
  stability across two views, unchanged collector PID, and recovery from invalid JSON.
