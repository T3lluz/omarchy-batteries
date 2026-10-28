# AGENTS.md

How Batteries is put together, for anyone (or any agent) changing it. The user-facing story is in [README.md](README.md).

## Layout

- `BarWidget.qml`: the bar entry, once per monitor. The first instance (the leader) loads `BatteryClient.qml`; the others read the leader's. Hosts `Panel.qml` and the IPC target.
- `BatteryClient.qml`: polls `bin/batteries probe`, listens to udev and librepods, keeps last-seen levels, the laptop's charge history and low-battery notifications.
- `Panel.qml`, `HistoryGraph.qml`: the panel and its charge graph.
- The panel kit (below) and the shared updater (`Updater.qml`, `Update.js`, `bin/plugin-update`).
- `WidgetSettings.qml`: this widget's `shell.json` entry, read from the file (see below).
- `Model.js`: parsing, the bar items, the history and alert rules. Tested by `tests/model.test.js`.
- `bin/batteries`: the reader (Python, stdlib only): sysfs, UPower, librepods, HID for Glorious and HyperX, openrazer, HeadsetControl, libimobiledevice, KDE Connect. Tested by `tests/test_batteries.py`.
- `Icon.qml`, `Icons.js`, `BoltIcon.qml`, `AirPodsIcon.qml`: drawn icons; `scripts/fetch-icons.py` regenerates `Icons.js` from Tabler.
- `udev/70-omarchy-batteries.rules`: HID access for the logged-in user.

## Test

```bash
node tests/model.test.js
node tests/update.test.js
python3 -B -m unittest discover tests
omarchy-shell io.github.t3lluz.batteries status | jq
```

## Panel kit

`SectionHeader`, `StatTile`, `ToggleTile`, `SwitchRow`, `Seg`, `Notice`, `LevelBar`, `OptionRow`, `Caption` and `UpdateSection` in the plugin folder are the panel kit: the same files, byte for byte, in ROG Deck, Batteries, Sonus and Server Dashboard, so the four look like one family. Change a kit file in all four or not at all. `Glyph.qml` is the one part each plugin owns: here it draws Tabler icons by name through `Icon.qml`, where the others type Nerd Font glyphs, so kit icons in Batteries are Tabler names.

`Updater.qml`, `Update.js` and `bin/plugin-update` are the shared updater (ROG Deck, Batteries and Server Dashboard; Sonus's engine updates itself the same way). It stashes local edits, untracked files too, before fast-forwarding, and drops the stash when the edits already are the update. `tests/update.test.js` and `tests/test_plugin_update.py` cover it.

Panels never cut text: a `Notice` shows all of its message, a `Caption` breaks long words and paths, and a `ToggleTile` label that does not fit shows in full in its tooltip.

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
