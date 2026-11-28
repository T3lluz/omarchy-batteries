// Motion.js against the art it moves (Pixels.js): node tests/motion.test.js
const fs = require("fs")
const path = require("path")
const assert = require("assert")

const load = (file, names) => new Function(
  fs.readFileSync(path.join(__dirname, "..", file), "utf8").replace(/^\.pragma library\s*/, "") + "\nreturn { " + names + " }")()
const Motion = load("Motion.js", "LOOP_MS, ACTS, LOOPS, iconOf, has, length, frameAt, pose, loopTime, loopWait, partAt")
const { icons } = load("Pixels.js", "icons")

const cells = rects => {
  const out = []
  for (const [x, y, w, h] of rects) for (let i = x; i < x + w; i++) for (let j = y; j < y + h; j++) out.push([i, j])
  return out
}

for (const act of Object.keys(Motion.ACTS)) {
  const name = Motion.iconOf(act)
  const art = icons[name]
  assert.ok(art, act + " moves an icon that exists")
  const parts = Object.fromEntries((art.parts || []).map(p => [p.id, p]))
  const frames = Motion.ACTS[act]
  assert.ok(frames.length > 0, act)
  // Short enough to read as a gesture, not a show.
  assert.ok(Motion.length(act) > 0 && Motion.length(act) <= 900, act + " takes " + Motion.length(act))
  for (const [ms, p] of frames) {
    assert.ok(Number.isInteger(ms) && ms >= 40, act + ": a frame shows long enough to see")
    for (const id of Object.keys(p)) {
      if (id === "turn") {
        assert.ok([1, 2, 3].includes(p.turn), act + ": turns in quarters")
        continue
      }
      assert.ok(parts[id], act + " moves a part the art has: " + id)
      const v = p[id]
      assert.ok(v === 0 || v === 1 || (Array.isArray(v) && v.length === 2 && v.every(Number.isInteger)), act + "." + id + " moves in whole cells")
      // A moved part stays on the icon's grid.
      if (Array.isArray(v)) {
        for (const [x, y] of cells(parts[id].g12)) {
          assert.ok(x + v[0] >= 0 && x + v[0] < 12 && y + v[1] >= 0 && y + v[1] < 12, act + "." + id + " leaves the grid")
        }
      }
    }
  }
  // Before and after, it rests.
  assert.strictEqual(Motion.frameAt(act, -1), -1)
  assert.strictEqual(Motion.frameAt(act, Motion.length(act)), -1)
  assert.deepStrictEqual(Motion.pose(act, -1), {})
  assert.strictEqual(Motion.frameAt(act, 0), 0)
  // Something moves.
  assert.ok(frames.some(([, p]) => Object.keys(p).length > 0), act + " moves")
}

// Every part an icon draws apart is moved by its act.
for (const [name, art] of Object.entries(icons)) {
  for (const part of art.parts || []) {
    const moved = Object.entries(Motion.ACTS).some(([act, frames]) => Motion.iconOf(act) === name && frames.some(([, p]) => part.id in p))
    assert.ok(moved, name + "." + part.id + " is drawn apart but never moves")
  }
}

// Loops: each period divides the clock, and the act rests before the next.
for (const [act, period] of Object.entries(Motion.LOOPS)) {
  assert.ok(Motion.has(act), act)
  assert.strictEqual(Motion.LOOP_MS % period, 0, act + " divides the clock")
  assert.ok(Motion.length(act) < period, act + " rests between loops")
  assert.strictEqual(Motion.loopTime(act, 0), 0)
  assert.strictEqual(Motion.loopTime(act, period + 5), 5)
  assert.strictEqual(Motion.loopTime(act, Motion.LOOP_MS * 1000 + 7), 7)
  assert.ok(Motion.loopTime(act, -3) >= 0)
}
assert.strictEqual(Motion.loopTime("laptop", 100), -1)

// A looped icon sleeps until its frame next changes: walking the waits visits
// every frame of each round once, then the rest, and never stalls.
for (const act of Object.keys(Motion.LOOPS)) {
  const frames = Motion.ACTS[act]
  let now = 0, seen = []
  while (now < Motion.LOOP_MS) {
    const wait = Motion.loopWait(act, now)
    assert.ok(wait >= 1, act + " waits")
    seen.push(Motion.frameAt(act, Motion.loopTime(act, now)))
    now += wait
  }
  const rounds = Motion.LOOP_MS / Motion.LOOPS[act]
  assert.strictEqual(seen.length, rounds * (frames.length + 1), act + " visits each frame once a round")
  assert.strictEqual(now, Motion.LOOP_MS, act + " ends on the clock's round")
}
assert.strictEqual(Motion.loopWait("laptop", 100), -1)

// Parts at rest, hidden, shown and moved.
assert.deepStrictEqual(Motion.partAt({}, "wheel", false), { x: 0, y: 0, on: true })
assert.deepStrictEqual(Motion.partAt({}, "cursor", true), { x: 0, y: 0, on: false })
assert.deepStrictEqual(Motion.partAt({ cursor: 1 }, "cursor", true), { x: 0, y: 0, on: true })
assert.deepStrictEqual(Motion.partAt({ wheel: 0 }, "wheel", false), { x: 0, y: 0, on: false })
assert.deepStrictEqual(Motion.partAt({ wheel: [0, 1] }, "wheel", false), { x: 0, y: 1, on: true })
assert.strictEqual(Motion.has("nothing"), false)
assert.strictEqual(Motion.length("nothing"), 0)
assert.strictEqual(Motion.frameAt("nothing", 10), -1)

// The icons the panel draws all act.
for (const name of ["laptop", "mouse", "keyboard", "headphone", "volume-2", "gamepad", "hand", "tablet", "pencil",
  "smartphone", "music", "tv", "power", "battery", "battery-low", "battery-medium", "battery-full", "zap", "plug",
  "reload", "settings-cog", "arrow-left", "key", "warning-diamond", "layout", "bell", "percent", "clock", "download",
  "check", "airpods", "airpods-case", "airpod-left", "airpod-right"]) assert.ok(Motion.has(name), name + " acts")

console.log("motion tests passed")
