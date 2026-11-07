# AGENTS.md

How Batteries is put together, for anyone (or any agent) changing it. The user-facing story is in [README.md](README.md).

## Layout

- `BarWidget.qml`: the bar entry, once per monitor. The first instance (the leader) loads `BatteryClient.qml`; the others read the leader's. Hosts `Panel.qml` and the IPC target.
- `BatteryClient.qml`: polls `bin/batteries probe`, listens to udev and librepods, keeps last-seen levels, the laptop's charge history and low-battery notifications.
- `Panel.qml`: the panel, on the measures of Omarchy's own (see below). The hero, then one `BatteryRow` per battery: icon, name over state, level with its mark, and a bar. The laptop adds its readings, AirPods their left, right and case cells. Bars that charge pulse together from one value, only while the panel is open.
- The panel kit (below) and the shared updater (`Updater.qml`, `Update.js`, `bin/plugin-update`).
- `WidgetSettings.qml`: this widget's `shell.json` entry, read from the file (see below).
- `Model.js`: parsing, the bar items, the history and alert rules. Tested by `tests/model.test.js`.
- `bin/batteries`: the reader (Python, stdlib only): sysfs, UPower, librepods, HID for Glorious and HyperX, JBL's GATT service, openrazer, HeadsetControl, libimobiledevice, KDE Connect. Tested by `tests/test_batteries.py`.
- `Glyph.qml`, `Model.GLYPHS`, `Model.kindGlyph`: the panel's icons, Nerd Font glyphs as in Omarchy's panels, written as escapes because the characters are invisible in most editors. Add a kind to `KIND_GLYPHS`.
- `Icon.qml`, `Icons.js`, `AirPodsIcon.qml`: drawn icons. `BarIcon.qml` is a bar item's icon, with a dark band rising through it while it is on a charger, full or not. Every step repaints the whole bar on every monitor, so keep the steps few (`Model.chargeStep`); `scripts/fetch-icons.py` regenerates `Icons.js` from Tabler, for the bar only. `Marks.js` is not generated: the JBL lettering as a filled mark on the same grid, drawn in the theme's colour. The panel uses `AirPodsIcon` and the JBL mark because no font has them.
- `udev/70-omarchy-batteries.rules`: HID access for the logged-in user.

## Test

```bash
node tests/model.test.js
node tests/update.test.js
python3 -B -m unittest discover tests
omarchy-shell io.github.t3lluz.batteries status | jq
```

## Panel kit

`SectionHeader`, `StatTile`, `ToggleTile`, `SwitchRow`, `Seg`, `Notice`, `LevelBar`, `OptionRow`, `Caption` and `UpdateSection` in the plugin folder are the panel kit: the same files, byte for byte, in ROG Deck, Batteries, Sonus and Server Dashboard, so the four look like one family. Change a kit file in all four or not at all. `Glyph.qml` is the one part each plugin owns; here it types Nerd Font glyphs like the others', so kit icons are characters from `Model.GLYPHS`.

`Updater.qml`, `Update.js` and `bin/plugin-update` are the shared updater (ROG Deck, Batteries and Server Dashboard; Sonus's engine updates itself the same way). It stashes local edits, untracked files too, before fast-forwarding, and drops the stash when the edits already are the update. `tests/update.test.js` and `tests/test_plugin_update.py` cover it.

Panels never cut text: a `Notice` shows all of its message, a `Caption` breaks long words and paths, and a `ToggleTile` label that does not fit shows in full in its tooltip.

## Panel measures

Taken from `shell/plugins/panels/` (Power, Bluetooth, Network) in Omarchy, so use these instead of new numbers. Scaled through `Style`.

- Panel `Style.space(380)`, column gap 14, section gap 10, tiles and buttons 6.
- Hero: `font.display` icon (24), gap 14, `font.title` bold title (14), `font.caption` bold uppercase caption with 1.2 letter spacing, `Qt.darker(foreground, 1.4)`.
- Row: `font.heading` icon (16), `font.body` name (12), `font.caption` state (10) one pixel under it, `Qt.darker(foreground, 1.5)`.
- Readings: `font.bodySmall` (11), label at 0.6 opacity, 4 between lines. Bar track at 0.12 alpha.
- Motion: fill pulse 1 to 0.55 over 950 ms each way, stopped while closed.

The caption is the panel's explanation, in place of help text. Power, Bluetooth, Network, Tailscale and Dropbox swap it every 2800 ms with a 150 ms fade out and a 200 ms fade in; `Model.heroPhrases` feeds it here. What needs attention holds still. What a control does goes in its tooltip.

Low must not depend on colour: a theme's red can be a dark grey (Solitude's is), so a low battery gets a mark, and `lowTone` falls back to the foreground when the theme's urgent colour has too little contrast.

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
