# AGENTS.md

How Batteries is put together, for anyone (or any agent) changing it. The user-facing story is in [README.md](README.md).

## Layout

- `BarWidget.qml`: the bar entry, once per monitor. The first instance (the leader) loads `BatteryClient.qml`; the others read the leader's. Hosts `Panel.qml` and the IPC target.
- `BatteryClient.qml`: polls `bin/batteries probe`, listens to udev and librepods, keeps last-seen levels, the laptop's charge history and low-battery notifications. AirPods keep a last level per part (`Model.airpodsWithLastKnown`): a closed case takes itself and the bud inside off the air while the other bud is worn. Those levels are saved to `~/.local/state/omarchy-batteries/airpods.json`, but only when a level or what answers changes.
- `Panel.qml`: the panel (see "Panel look" below). A prompt line beside the hero battery, then one `Room` per battery: icon, name over state, the level in `BigFigure`'s block digits, and a `Battery`. The laptop adds its readings, AirPods their left, right and case cells. A click opens a room (`root.openRoom`, one at a time) to a `Drawer` with its other readings (`Model.deviceFacts`, `airpodsFacts`, the rest of `laptopFacts`) and its bar switches (`Model.roomPicks`). Everything that moves runs off one clock (`root.clock`) that ticks only while the panel is open and something charges or a ripple runs.
- `Battery.qml`: a level as a battery of cells, a tenth each, filled to the full height. The cell maths (fill, charge pulse, breathing, the pointer's dent, ripples) is `Model.batteryCells`.
- `BigFigure.qml`: a level in the block face from `Model.bigDigits`, laid out on the font's character grid but drawn as rectangles, since typed block characters leave hairline seams.
- The panel kit (below) and the shared updater (`Updater.qml`, `Update.js`, `bin/plugin-update`).
- `WidgetSettings.qml`: this widget's `shell.json` entry, read from the file (see below).
- `Model.js`: parsing, the bar items, the history and alert rules. Tested by `tests/model.test.js`.
- `bin/batteries`: the reader (Python, stdlib only): sysfs, UPower, librepods, HID for Glorious and HyperX, JBL's GATT service, openrazer, HeadsetControl, libimobiledevice, KDE Connect. Tested by `tests/test_batteries.py`.
- `PixelIcon.qml`, `Pixels.js`: every icon in the panel is pixel art, one set: Pixelarticons (MIT), plus AirPods and their case drawn in `scripts/fetch-pixel-icons.py` on the same grid. The script turns each SVG into an exact grid of cells (24, and 12 for small sizes) and `PixelIcon` draws them on whole device pixels, picking the grid by the screen's scale so nothing blurs. Rooms name them directly (`Model.kindPixel`, `Model.markIcon`). Add an icon to the script's list and rerun it. Pixel art never turns or scales smoothly: icon stories move in whole pixels (`Model.storyPose`), buttons turn in quarters.
- `Glyph.qml`, `Model.GLYPHS`, `Model.kindGlyph`: the icon the panel kit is handed, as Nerd Font glyphs (escapes, because the characters are invisible in most editors). `Glyph.qml` draws the pixel icon `Model.PIXEL_GLYPHS` gives a glyph, so the kit's icons match the rooms'. Map a new glyph there. The one typed glyph left is the "Check now" button in the shared `UpdateSection`.
- `BarIcon.qml` is a bar item's pixel icon, with a hard-edged dark band stepping up through it a cell at a time while it is on a charger, full or not. Every step repaints the whole bar on every monitor, so keep the steps few (`Model.chargeStep`); a step that lands on the same cell changes nothing.
- `PixelText.qml`: a line in the pixel type (`Model.PIXEL_FONT`, `Model.pixelText`): the panel's block digits a column wider, the %, and the letters the bar writes. The bar's figures and its icons share whole device pixels; nothing is ever scaled, which smears pixel art. On a 1.25 scale bar icons are 12 device pixels, the largest sharp size under the shell's own.
- `HoverCard.qml`: the card the bar item opens on hover in place of the shell's plain tooltip (kept only for the access message), placed and framed like that tooltip. A row per battery (`Model.hoverRows`) with the mark in a column of its own, there on every row, so every row's battery and figure stay in one column.
- `udev/70-omarchy-batteries.rules`: HID access for the logged-in user.

## Test

```bash
node tests/model.test.js
node tests/update.test.js
python3 -B -m unittest discover tests
omarchy-shell io.github.t3lluz.batteries status | jq
```

## Panel kit

`SectionHeader`, `StatTile`, `ToggleTile`, `SwitchRow`, `Seg`, `Notice`, `LevelBar`, `OptionRow`, `Caption` and `UpdateSection` in the plugin folder are the panel kit: the same files, byte for byte, in ROG Deck, Batteries, Sonus and Server Dashboard, so the four look like one family. Change a kit file in all four or not at all. `Glyph.qml` is the one part each plugin owns. The kit hands it Nerd Font glyphs from `Model.GLYPHS`; here it draws their pixel icons instead (`Model.PIXEL_GLYPHS`), so the kit matches the rooms without changing a kit file.

`Updater.qml`, `Update.js` and `bin/plugin-update` are the shared updater (ROG Deck, Batteries and Server Dashboard; Sonus's engine updates itself the same way). It stashes local edits, untracked files too, before fast-forwarding, and drops the stash when the edits already are the update. `tests/update.test.js` and `tests/test_plugin_update.py` cover it.

Panels never cut text: a `Notice` shows all of its message, a `Caption` breaks long words and paths, and a `ToggleTile` label that does not fit shows in full in its tooltip.

## Panel look

The battery panel has its own look, after the owner's Android apps (DailyDash and Weave) set in Omarchy's terminal type: rooms in a tone each, joined by small gaps, numbers in a block face, and motion that answers what happens. The settings page keeps the panel kit, so it matches the other plugins. Scaled through `Style`.

- Panel `Style.space(380)`, column gap 14. Rooms: padding 10, gap 3 between them, `Style.cornerRadius` (square on Omarchy's default), the tone at 0.065 alpha, 0.11 under the pointer.
- Tones: `Model.kindTone` picks a colour name per kind (power blue, audio magenta, input cyan, play green, phones yellow); `Model.roomToneHex` takes the theme's colour of that name from its `colors.toml` (read on each open) when it is a colour, else DailyDash's hue for it, and softens either a third of the way toward the text colour. A tone too faint on the background falls back to the foreground. Low uses `lowTone`. Only the panel and the hover card use tones; the bar stays in the bar's colours.
- Room header: pixel icon at `font.heading` × 1.25 (20) in the tone, `font.body` bold name (12) with a `font.caption` chevron that flips when the room is open, `font.caption` state (10) dimmed, the level as `BigFigure` at `font.bodySmall` on the right (`font.caption` in an AirPods cell).
- Batteries: ten cells (five in an AirPods cell, four in the hero mark), track at 0.12 alpha, a 1 px outline at 0.6. Only the small hero mark has a nub; across a room it read as a stray pixel.
- Readings: `font.bodySmall` (11), label at 0.6 opacity, 4 between lines.
- Prompt: `❯` and the caption from `Model.heroPhrases`, typed at 22 ms a character behind a block cursor blinking at 530 ms, a new line every 2800 ms. What needs attention holds still. What a control does goes in its tooltip.

Motion, all off with reduced motion:

- Opening: rooms rise 12 and fade in 70 ms apart; each battery fills from empty over 680 ms while its number counts up; states and readings decode out of scrambled glyphs (`Model.scramble`); then each icon plays its story once (`Model.storyOf`, `Model.storyPose`).
- Charging: a pulse runs up the filled cells every 1600 ms, the cell being filled breathes over 1100 ms, and so does the bolt.
- Pointer: cells under it give (`press`); a click ripples out from it (Weave's 760 ms), plays the icon again and opens or closes the room, its drawer sliding over 280 ms.
- Changes while open: a level slides to its new value. Text decodes only on opening; a reading that changes every few seconds just changes, so it stays readable. The refresh icon spins when you read by hand; switching to the settings slides the page in from its side and turns the gear.

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
