.pragma library

// How each pixel icon acts out what it is. An act is a flipbook: frames of
// [ms, pose], where a pose moves an icon's parts (Pixels.js `parts`) in
// whole cells of the 12-cell grid (two units on the 24 one), so nothing
// smears. A part is [dx, dy], 0 for hidden, or 1 to show an extra part where
// it was drawn. "turn" turns the whole icon in quarters, which pixel art
// survives. A part a frame leaves out is at rest, and after the last frame
// the icon rests, so every act ends exactly where it began.
//
// Acts play once: when the panel opens, when what the icon stands for
// changes, on a click or the pointer coming in. What needs attention or is
// live loops instead, off one clock of LOOP_MS that each loop's period
// divides, so every loop meets its start when the clock comes round.

var LOOP_MS = 4800

var ACTS = {
  // A prompt wakes on the screen and its cursor blinks twice.
  "laptop": [
    [90, { prompt: 1 }], [170, { prompt: 1, cursor: 1 }], [140, { prompt: 1 }],
    [170, { prompt: 1, cursor: 1 }], [140, { prompt: 1 }]
  ],
  // Two clicks of the scroll wheel.
  "mouse": [[110, { wheel: [0, 1] }], [110, {}], [110, { wheel: [0, 1] }]],
  // Keys go down one after another as if typed, then the space bar.
  "keyboard": [
    [80, { k2: 0 }], [50, {}], [80, { k5: 0 }], [50, {}], [80, { k3: 0 }], [50, {}],
    [80, { k7: 0 }], [50, {}], [130, { space: [0, 1] }]
  ],
  // The cups thump outwards on two beats.
  "headphone": [
    [100, { cupL: [-1, 0], cupR: [1, 0] }], [150, {}], [100, { cupL: [-1, 0], cupR: [1, 0] }]
  ],
  // The sound goes out from the speaker, wave by wave, twice.
  "volume-2": [
    [110, { inner: 0, outer: 0 }], [110, { outer: 0 }], [150, {}],
    [110, { inner: 0, outer: 0 }], [110, { outer: 0 }]
  ],
  // Both buttons, then the pad left and right.
  "gamepad": [
    [90, { btnA: 0 }], [70, {}], [90, { btnB: 0 }], [70, {}],
    [100, { dpad: [-1, 0] }], [100, { dpad: [1, 0] }]
  ],
  // A double tap.
  "hand": [[90, { hand: [0, 1] }], [100, {}], [90, { hand: [0, 1] }]],
  // The home button, then a swipe across the screen.
  "tablet": [
    [90, { home: 0 }], [50, {}],
    [55, { swipe: 1 }], [55, { swipe: [1, 0] }], [55, { swipe: [2, 0] }], [55, { swipe: [3, 0] }],
    [55, { swipe: [4, 0] }], [55, { swipe: [5, 0] }], [55, { swipe: [6, 0] }]
  ],
  // It writes a short line and lifts off.
  "pencil": [
    [110, { ink1: 1 }], [130, { pencil: [1, 0], ink1: 1, ink2: 1 }], [180, { ink1: 1, ink2: 1 }]
  ],
  // Two bursts of buzzing.
  "smartphone": [
    [45, { phone: [1, 0] }], [45, { phone: [-1, 0] }], [45, { phone: [1, 0] }], [45, { phone: [-1, 0] }],
    [170, {}],
    [45, { phone: [1, 0] }], [45, { phone: [-1, 0] }], [45, { phone: [1, 0] }], [45, { phone: [-1, 0] }]
  ],
  // The notes bob to two beats.
  "music": [[110, { notes: [0, -1] }], [150, {}], [110, { notes: [0, -1] }]],
  // A line rolls down the picture.
  "tv": [
    [65, { scan: 1 }], [65, { scan: [0, 1] }], [65, { scan: [0, 2] }], [65, { scan: [0, 3] }]
  ],
  // The switch goes in, and the light inside blinks once.
  "power": [[100, { stem: [0, 1] }], [110, {}], [90, { stem: 0 }]],
  // No reading: the nub flickers as it looks for one.
  "battery": [[110, { nub: 0 }], [110, {}], [110, { nub: 0 }]],
  // The cells fill one at a time.
  "battery-medium": [[110, { c1: 0, c2: 0 }], [110, { c2: 0 }]],
  "battery-full": [[100, { c1: 0, c2: 0, c3: 0 }], [100, { c2: 0, c3: 0 }], [100, { c3: 0 }]],
  // The last cell blinks. Looped while the battery is low.
  "battery-low": [[220, { c1: 0 }], [220, {}], [220, { c1: 0 }]],
  // The bolt strikes top to bottom, then flashes. Looped while charging.
  "zap": [[70, { mid: 0, bot: 0 }], [70, { bot: 0 }], [110, {}], [70, { top: 0, mid: 0, bot: 0 }]],
  // Pushed in, and it seats.
  "plug": [[110, { head: [0, -1] }], [120, {}], [110, { head: [0, -1] }]],
  // A full turn in quarters.
  "reload": [[80, { turn: 1 }], [80, { turn: 2 }], [100, { turn: 3 }]],
  // Something under way (a notice that is busy): the arrows go round in
  // quarters, a step every 200 ms, for as long as it lasts. Looped.
  "reload-busy": [[200, { turn: 1 }], [200, { turn: 2 }], [200, { turn: 3 }]],
  // The hub presses in, twice.
  "settings-cog": [[100, { hub: 0, pressed: 1 }], [90, {}], [100, { hub: 0, pressed: 1 }]],
  "arrow-left": [[90, { arrow: [-1, 0] }], [90, {}], [90, { arrow: [-1, 0] }]],
  // In, a turn (the teeth go edge on), and out.
  "key": [
    [100, { bow: [1, 0], teeth: [1, 0] }], [140, { bow: [1, 0], teeth: 0 }], [100, { bow: [1, 0], teeth: [1, 0] }]
  ],
  // The mark blinks. Looped while it is shown.
  "warning-diamond": [[200, { mark: 0 }], [200, {}], [200, { mark: 0 }]],
  // The bar along the top blinks on.
  "layout": [[110, { bar: 0 }], [110, {}], [110, { bar: 0 }]],
  // The skirt swings, the clapper a beat behind.
  "bell": [
    [70, { skirt: [1, 0] }], [70, { skirt: [1, 0], clapper: [-1, 0] }], [70, { skirt: [-1, 0], clapper: [-1, 0] }],
    [70, { skirt: [-1, 0], clapper: [1, 0] }], [70, { skirt: [1, 0], clapper: [1, 0] }], [70, { clapper: [-1, 0] }]
  ],
  // The top up a step, then the bottom down: a level moving.
  "percent": [[100, { o1: [0, -1] }], [90, {}], [100, { o2: [0, 1] }]],
  // The long hand goes round once.
  "clock": [[90, { hand: 0, right: 1 }], [90, { hand: 0, down: 1 }], [90, { hand: 0, left: 1 }]],
  // The arrow comes down into the tray.
  "download": [[80, { arrow: 0 }], [80, { arrow: [0, -1] }], [90, {}], [120, { arrow: [0, 1] }]],
  // It draws itself: the short stroke, then the long.
  "check": [[80, { short: 0, long: 0 }], [100, { long: 0 }]],
  // The buds wave, one after the other, twice.
  "airpods": [
    [100, { budL: [0, -1] }], [80, {}], [100, { budR: [0, -1] }], [80, {}],
    [100, { budL: [0, -1] }], [80, {}], [100, { budR: [0, -1] }]
  ],
  // One bud alone, for its own cell.
  "airpods-left": [[100, { budL: [0, -1] }], [80, {}], [100, { budL: [0, -1] }]],
  "airpods-right": [[100, { budR: [0, -1] }], [80, {}], [100, { budR: [0, -1] }]],
  // The lid lifts and shuts, and the light blinks.
  "airpods-case": [[240, { lid: [0, -1] }], [90, {}], [110, { light: 0 }], [110, {}], [110, { light: 0 }]]
}

// The icon an act moves, where it is not the act's own name.
var ACT_ICONS = {
  "reload-busy": "reload",
  "airpods-left": "airpods",
  "airpods-right": "airpods"
}

// The period of each looped act, in ms. Each divides LOOP_MS.
var LOOPS = {
  "reload-busy": 800,
  "zap": 2400,
  "battery-low": 2400,
  "warning-diamond": 4800
}

function iconOf(act) {
  return ACT_ICONS[act] || act
}

function has(act) {
  return !!ACTS[act]
}

// How long `act` runs, in ms; 0 when there is none.
function length(act) {
  var frames = ACTS[act]
  if (!frames) return 0
  var total = 0
  for (var i = 0; i < frames.length; i++) total += frames[i][0]
  return total
}

// The frame `ms` into `act`, -1 at rest (before it, after it, or no act).
function frameAt(act, ms) {
  var frames = ACTS[act]
  if (!frames || !(ms >= 0)) return -1
  var at = 0
  for (var i = 0; i < frames.length; i++) {
    at += frames[i][0]
    if (ms < at) return i
  }
  return -1
}

// The pose of frame `i` of `act`: { part: [dx, dy] | 0 | 1, turn: quarters }.
// At rest, an empty pose.
function pose(act, i) {
  var frames = ACTS[act]
  if (!frames || i < 0 || i >= frames.length) return {}
  return frames[i][1]
}

// Where a looped act is at `nowMs` on the shared clock: ms into the act,
// which plays at the start of each of its periods and rests the rest.
function loopTime(act, nowMs) {
  var period = LOOPS[act]
  if (!period) return -1
  var t = nowMs % LOOP_MS
  if (t < 0) t += LOOP_MS
  return t % period
}

// How long from `nowMs` until a looped act's frame next changes, so one
// timer can sleep until then instead of drawing every frame. -1 for an act
// that does not loop.
function loopWait(act, nowMs) {
  var period = LOOPS[act]
  var frames = ACTS[act]
  if (!period || !frames) return -1
  var t = loopTime(act, nowMs)
  var at = 0
  for (var i = 0; i < frames.length; i++) {
    at += frames[i][0]
    if (t < at) return at - t
  }
  return period - t
}

// Where a part is drawn in a pose: { x, y, on }, x and y in 12-grid cells.
// An extra part is hidden unless the pose names it.
function partAt(p, id, extra) {
  var v = p ? p[id] : undefined
  if (v === undefined) return { x: 0, y: 0, on: !extra }
  if (v === 0) return { x: 0, y: 0, on: false }
  if (v === 1) return { x: 0, y: 0, on: true }
  return { x: v[0], y: v[1], on: true }
}
