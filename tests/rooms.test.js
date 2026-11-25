// Run with: node tests/rooms.test.js
// What the QML asks of the pixel art, and that the version is said once.
const fs = require("fs")
const path = require("path")
const assert = require("assert")

const root = path.join(__dirname, "..")
const load = (file, names) => new Function(
  fs.readFileSync(path.join(root, file), "utf8").replace(/^\.pragma library\s*/, "") + "\nreturn { " + names + " }")()
const Model = load("Model.js", "pixelFor")
const { icons } = load("Pixels.js", "icons")

// Every Nerd Font glyph handed to the panel kit has a pixel icon, so no typed
// glyph stands among the pixel art, whether written out or as an escape. The
// one the kit types itself, the "Check now" button inside UpdateSection, is
// the known exception. After ROG Deck's.
// The kit's files type their own (a notice's dismiss button, "Check now"),
// so only what this plugin hands the kit is checked.
const kit = new Set(["SectionHeader.qml", "StatTile.qml", "ToggleTile.qml", "SwitchRow.qml", "Seg.qml", "Notice.qml",
  "LevelBar.qml", "OptionRow.qml", "Caption.qml", "UpdateSection.qml"])
const pua = cp => (cp >= 0xE000 && cp <= 0xF8FF) || (cp >= 0xF0000 && cp <= 0xFFFFD)
const exempt = new Set([0xF0453])
const files = fs.readdirSync(root).filter(f => f.endsWith(".qml") && !kit.has(f)).concat(["Model.js", "Update.js"])
for (const file of files) {
  const text = fs.readFileSync(path.join(root, file), "utf8")
  const found = []
  for (const ch of text) found.push(ch.codePointAt(0))
  for (const m of text.matchAll(/\\u\{([0-9A-Fa-f]{4,6})\}|\\u([0-9A-Fa-f]{4})/g)) found.push(parseInt(m[1] || m[2], 16))
  for (const cp of found) {
    if (!pua(cp) || exempt.has(cp)) continue
    const pixel = Model.pixelFor(String.fromCodePoint(cp))
    assert.ok(pixel, "U+" + cp.toString(16).toUpperCase() + " in " + file + " has a pixel icon")
    assert.ok(icons[pixel], pixel + " (for U+" + cp.toString(16).toUpperCase() + ") is in Pixels.js")
  }
}

// Every pixel icon the QML names outright is in Pixels.js.
for (const file of fs.readdirSync(root).filter(f => f.endsWith(".qml"))) {
  const text = fs.readFileSync(path.join(root, file), "utf8")
  for (const m of text.matchAll(/\b(?:name|icon|mark):\s*"([a-z0-9-]+)"/g)) assert.ok(icons[m[1]], m[1] + " in " + file + " is in Pixels.js")
}

// The README's version badge says the manifest's version.
const version = JSON.parse(fs.readFileSync(path.join(root, "manifest.json"), "utf8")).version
const badge = fs.readFileSync(path.join(root, "README.md"), "utf8").match(/badge\/v([0-9.]+)-/)
assert.ok(badge, "the README has a version badge")
assert.strictEqual(badge[1], version, "the README badge matches manifest.json")

console.log("rooms tests passed")
