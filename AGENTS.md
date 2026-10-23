# AGENTS.md

How Batteries is put together, for anyone (or any agent) changing it. The user-facing story is in [README.md](README.md).

## Layout

- `BarWidget.qml`: the bar entry, once per monitor. The first instance (the leader) loads `BatteryClient.qml`; the others read the leader's. Hosts `Panel.qml` and the IPC target.
- `BatteryClient.qml`: polls `bin/batteries probe`, listens to udev and librepods, keeps last-seen levels, the laptop's charge history and low-battery notifications.
- `Panel.qml`, `HistoryGraph.qml`: the panel and its charge graph.
- `WidgetSettings.qml`: this widget's `shell.json` entry, read from the file (see below).
- `Model.js`: parsing, the bar items, the history and alert rules. Tested by `tests/model.test.js`.
- `bin/batteries`: the reader (Python, stdlib only): sysfs, UPower, librepods, HID for Glorious and HyperX, openrazer, HeadsetControl, libimobiledevice, KDE Connect. Tested by `tests/test_batteries.py`.
- `Icon.qml`, `Icons.js`, `BoltIcon.qml`, `AirPodsIcon.qml`: drawn icons; `scripts/fetch-icons.py` regenerates `Icons.js` from Tabler.
- `udev/70-omarchy-batteries.rules`: HID access for the logged-in user.

## Test

```bash
node tests/model.test.js
python3 -B -m unittest discover tests
omarchy-shell io.github.t3lluz.batteries status | jq
```

## Rules that are easy to break

- **Settings** are read with `setting(key, fallback)` and saved with `persistSettings({...})`. Both go through `WidgetSettings.qml`, which reads `~/.config/omarchy/shell.json` itself. Never read `settings.foo` directly: the bar's copy turns a list into a Qt sequence that fails `Array.isArray`, and after a plugin reload it can be older than the file. Either one makes a pick look unset, which is how choices "reset after a reboot" or differ between monitors.
- **One widget per monitor.** The bar draws the widget on every screen. Long-running work (a poller, a client, a process) lives in one place, a leader instance or the service, and the others read from it. Never start it per instance.
- **IPC** is answered by whichever monitor's widget registered first, so `open`, `close` and `toggle` go through the shell's `summon`, `hide` and `toggle`, which pick the focused monitor.
- **Nothing may write inside the plugin folder at runtime.** The shell watches it and reloads every plugin when a file appears there. Python sets `sys.dont_write_bytecode`; state goes to `~/.local/state` or `~/.config`.
- **QML changes need `omarchy restart shell`.** Hot reload can keep the old component cached.
- **Pure logic goes in `Model.js`** (a `.pragma library` with no QML) so `node tests/*.test.js` can run it. Change it with a test.
- Comments say why, in plain sentences. Match the surrounding code.

## Release

Bump `version` in `manifest.json` and the version badge in `README.md` together, run the tests, and describe the change for the person using it in the commit message.
