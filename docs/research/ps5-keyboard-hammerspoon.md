# Design Document — PS5-Style AZERTY Virtual Keyboard & Hammerspoon Integration

Project: **DualSenseRemap** (macOS 13+, SwiftUI, SwiftPM). This document specifies (A) the `VirtualKeyboard/` module and (B) the `Output/HammerspoonBridge` + `Hammerspoon/DualSenseRemap.spoon` deliverables. It conforms to the public contracts in `/home/user/dualSenseRemap/docs/ARCHITECTURE.md` (`VirtualKeyboardController`, `EventSynthesizer.typeText`, `HammerspoonBridge.trigger`).

**Verification status legend** — ✅ verified against a primary source this session; ⚠️ UNVERIFIED: designed from convention/secondary evidence, flagged inline.

Verified facts used below: on the real PS5 OSK, **R2 = "Done"**, **△ = space**, **□ = backspace**, **✕ = select**, d-pad navigates, and **L3+R3 together toggles the motion/touchpad typing mode** (Sony support + seekingtech + tutorial sources). ⚠️ UNVERIFIED: L2 = Shift is stated in the task brief and consistent with PS4/PS5 convention, but I could not find a primary Sony citation; treat as convention. ⚠️ UNVERIFIED: I found no authoritative capture of Sony's **French** PS5 OSK rows (PS5 does offer a French input language; sources only confirm "the PS5 virtual keyboard is AZERTY when the console language is French"). The AZERTY rows below are therefore our **own adaptation**, designed to be one-swap-away from Sony's if a reference is later obtained.

---

# Part A — PS5-Style On-Screen Keyboard, AZERTY

## A.1 Visual identity

| Property | Spec |
|---|---|
| Panel | Non-activating `NSPanel`, dark rounded panel, corner radius **20 pt**, `NSVisualEffectView` material `.hudWindow` + overlay `Color.black.opacity(0.55)` → PS5's near-black `#1C1C1E` look |
| Size | **880 × 340 pt** default (min 720×280, resizable via Options), anchored bottom-center of the screen with the focused window, 24 pt above Dock edge |
| Text strip | Top: 44 pt high rounded field (`#2C2C2E`, radius 10) showing the **local echo buffer** (A.8) with a blinking caret glyph `|` |
| Keys | Flat, **borderless**, no key background at rest; label `SF Pro Text` 20 pt, `#E5E5EA`; secondary labels (shortcut glyphs) 11 pt `#8E8E93` |
| Focus ring | White rounded rect (radius 10, 2.5 pt stroke + 1.06× scale + faint white inner glow), exactly one focused key at all times |
| Focus motion | Ring **interpolates** between key frames (it slides, PS5-style, not blink): 120 ms ease-out spring (`response 0.18, damping 0.85`). Scale-up 90 ms. Layer switches cross-fade 140 ms |
| Key press | On activate: ring flashes to 100% white 60 ms, key label dips to 0.92 scale and back (total 130 ms). Optional `NSSound` tick (off by default) |
| Shortcut badges | Function/bottom keys show their controller shortcut as a small glyph in the corner (L2, △, □, L1, R1, R2, R3, L3+R3) exactly like the PS5 |

## A.2 Grid model

The keyboard is a fixed grid of **6 rows**: 4 character rows (11 columns each), 1 function row (6 slots), 1 bottom row (5 slots). Every layer replaces only the 4 character rows; function/bottom rows are invariant.

```
Row 0..3  : character rows (11 equal-width cells, 64×52 pt)
Row 4 (fn): [⇧ L2] [ABC] [@#:] [à R3] [────space △────] [⌫ □]
Row 5     : [◀ L1] [▶ R1] [•••] [🎮 L3+R3] [Done R2]
```

Space bar spans the width of ~5 character cells. `ABC`, `@#:`, `à` are **layer selector keys**; the active layer's selector renders with a persistent light-gray filled background (`#3A3A3C`) — the only "filled" keys at rest, matching PS5's layer indication.

## A.3 Layer 1 — AZERTY lowercase (default)

⚠️ UNVERIFIED against Sony's real French OSK; this is the designed adaptation of the given QWERTY reference. Design rationale: swap A↔Q, Z↔W per AZERTY; **M moves next to L** (row 3, replacing QWERTY's `"`); the freed row-4 slot gets **`'`** (apostrophe — highest-frequency French punctuation); `"` relocates to the symbols layer.

| Col → | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **Row 0** | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 0 | @ |
| **Row 1** | a | z | e | r | t | y | u | i | o | p | # |
| **Row 2** | q | s | d | f | g | h | j | k | l | m | / |
| **Row 3** | w | x | c | v | b | n | ' | - | _ | ? | ! |

**Long-press alternates** (hold ✕ ≥ 500 ms on a letter opens a PS5-style inline popover strip above the key; d-pad ←/→ selects, ✕ commits, ○ dismisses). This mirrors iOS/PS5 accent popovers and gives accents without leaving the layer:
`a → à â ä æ` · `e → é è ê ë €` · `i → î ï` · `o → ô ö œ` · `u → ù û ü` · `c → ç` · `y → ÿ` · `n → ñ` (courtesy) · `' → ’ " «  »`. Keys without alternates use hold for **key repeat** instead (A.7).

## A.4 Layer 2 — Uppercase (Shift / Caps)

Only letters change; digits and punctuation are unchanged (PS5 behavior: Shift does not re-layout the symbol columns).

| Col → | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **Row 0** | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 0 | @ |
| **Row 1** | A | Z | E | R | T | Y | U | I | O | P | # |
| **Row 2** | Q | S | D | F | G | H | J | K | L | M | / |
| **Row 3** | W | X | C | V | B | N | ' | - | _ | ? | ! |

**Shift state machine** (input: L2 or the ⇧ key; both identical):

| State | Trigger | Result |
|---|---|---|
| off → one-shot | single tap | Next character upper, then auto-revert to off |
| off → held | hold L2 | Upper while held (momentary, like hardware Shift) |
| one-shot → caps | second tap within **350 ms** (double-tap) | Caps lock; ⇧ key shows filled background + underline bar |
| caps → off | single tap | Revert |

⇧ glyph states: `⇧` outline (off) / `⇧` filled (one-shot) / `⇧̲` filled+bar (caps). One-shot also auto-reverts if layer changes.

## A.5 Layer 3 — Symbols `@#:` (2 pages)

⚠️ UNVERIFIED vs Sony's exact symbol inventory (not capturable from found sources); the set below is a superset of Sony's visible page-1 symbols and standard French typography. Page indicator key `1/2` ↔ `2/2` occupies row 3, col 11; pressing it (or pressing the `@#:` selector again) flips pages. R3 does **not** page here (reserved for accents layer).

**Page 1/2 — common:**

| Col → | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **Row 0** | € | $ | £ | ¥ | % | & | * | ( | ) | [ | ] |
| **Row 1** | @ | # | : | ; | " | ' | ` | ^ | ~ | \| | \\ |
| **Row 2** | + | - | × | ÷ | = | < | > | { | } | ° | § |
| **Row 3** | ! | ? | / | _ | , | . | … | « | » | ¡¿ | **2/2** |

(`¡¿` is a single key: tap = ¿, long-press popover offers ¡.)

**Page 2/2 — extended:**

| Col → | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **Row 0** | ¹ | ² | ³ | ¼ | ½ | ¾ | ± | µ | ‰ | ¢ | ¤ |
| **Row 1** | ‘ | ’ | “ | ” | ‚ | „ | ‹ | › | – | — | • |
| **Row 2** | © | ® | ™ | † | ‡ | ¶ | ≈ | ≠ | ≤ | ≥ | ∞ |
| **Row 3** | · | ¨ | ´ | ¸ | ª | º | ¦ | ¬ | ⁄ | ‾ | **1/2** |

Shift has no effect on the symbols layer (⇧ renders dimmed/disabled there).

## A.6 Layer 4 — Accents `à` (R3)

All required French accents **with uppercase variants directly visible** (no shift round-trip — faster than PS5's own flow, and it exactly fills the 4×11 grid). L2/⇧ on this layer jumps focus between the lowercase half (rows 0–1) and uppercase half (rows 2–3), same column.

| Col → | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **Row 0** | à | â | ä | é | è | ê | ë | î | ï | ô | ö |
| **Row 1** | ù | û | ü | ç | œ | æ | ÿ | « | » | ’ | € |
| **Row 2** | À | Â | Ä | É | È | Ê | Ë | Î | Ï | Ô | Ö |
| **Row 3** | Ù | Û | Ü | Ç | Œ | Æ | Ÿ | ‘ | ” | “ | ° |

R3 toggles: press once from any layer → accents; press again → return to previous layer (remembered). The `à` selector key shows the R3 badge, as on PS5.

## A.7 Controller navigation & interaction spec

All events arrive via `VirtualKeyboardController.handle(_ event: ControllerEvent) -> Bool` (MappingEngine forwards everything while `isVisible == true`; return `true` = consumed). **Every** controller event is consumed while visible except: PS button, mute, and the app's global toggle chord — those return `false`.

| Input | Action |
|---|---|
| D-pad ↑↓←→ | Move focus one cell (discrete edges). Held: repeat after **400 ms**, then every **120 ms** |
| Left stick | Same as d-pad. Dead zone 0.35 radial; direction = dominant axis with 60°/30° hysteresis; first move immediate, repeat 220 ms decreasing to **90 ms** after 3 consecutive repeats (acceleration) |
| ✕ (cross) | Activate focused key **on button-down** (PS5 commits on press). Held on a character key: popover if alternates exist (A.3), else key-repeat: initial delay **400 ms**, then **80 ms/char** |
| ○ (circle) | Close the panel (`hide()`). No "undo": characters were injected live, so ○ = dismiss, not cancel. If a popover/options sheet is open, ○ closes that first |
| △ (triangle) | Type space — regardless of focus ✅ (PS5 behavior) |
| □ (square) | Backspace (keycode 51) — regardless of focus ✅. Held: repeat 350 ms then **60 ms**; after 15 repeats escalates to word-delete (⌥⌫) — configurable off |
| L2 | Shift (A.4 state machine) ⚠️ convention |
| R2 | **Done** ✅: sends Return (keycode 36) then `hide()`. Preference `sendReturnOnDone` (default on) for fields where Return would submit undesirably |
| L1 / R1 | Move **text cursor** left/right in the target app: inject ← / → (keycodes 123/124). Held: 350 ms then 90 ms. With L2 held: injects ⇧←/⇧→ (selection) — bonus over PS5 |
| R3 | Toggle accents layer ✅ (badge on `à` key) |
| L3 + R3 chord (≤150 ms apart) | The 🎮 controller-icon key: opens the typing-method popover (on PS5 this chord relates to motion/touchpad typing ✅). Ours toggles **touchpad-pointer mode**: DualSense touchpad moves a dot cursor over the keys, touchpad-click activates |
| Touchpad swipe (1-finger flick, no click) | Fast row jump: vertical flick moves focus a full row per 80 px; horizontal flick 3 columns |
| Options button | Same as focusing `•••` and pressing ✕ |

**Focus wrap rules**
- Horizontal: wraps within the row (col 11 → col 1 and vice-versa), including function/bottom rows.
- Vertical: row 3 ↓ → function row; function ↓ → bottom row; bottom row ↓ → **row 0** (full vertical wrap); row 0 ↑ → bottom row.
- Cross-row column mapping (rows have different widths): target cell = the key whose **horizontal center is nearest** to the departing key's center (space bar therefore captures ↓ from cols 5–9 of row 3). The pre-jump column index is remembered so ↓↓ then ↑↑ returns to the original key ("column memory", like tvOS focus engine).
- Layer switches keep focus at the same (row, col) when the cell exists, else nearest cell.

**`•••` Options popover** (navigated with the same focus system): Paste clipboard as text · Clear echo buffer · Panel position (bottom/top/floating, per-screen) · Panel opacity 60–100% · Layout: AZERTY / QWERTY (task layout) · Key sound on/off · Help overlay (controller glyph cheat-sheet).

## A.8 Character delivery — Unicode injection (`EventSynthesizer.typeText`)

- **Mechanism**: `CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)` + `event.keyboardSetUnicodeString(stringLength:unicodeString:)` (Core Graphics `CGEventKeyboardSetUnicodeString`), then the matching `keyDown: false` event; post both to `.cghidEventTap`. This is **layout-independent** — `é`, `œ`, `€` arrive as literal UTF-16 regardless of the OS keyboard layout, which is the whole point (no need for the Mac to be in French AZERTY).
- **Chunking**: ≤ 20 UTF-16 code units per event (macOS truncates long unicode strings per event); paste-from-clipboard iterates chunks with a 1 ms gap. Surrogate pairs (e.g. future emoji page) must never be split across chunks.
- **Semantic keys use real virtual keycodes**, not unicode: Backspace 51, Return 36, ← 123, → 124, Tab 48, with modifier flags for ⇧← selection. (A unicode "\u{8}" does not reliably delete in AppKit/web views.)
- **Permission**: requires Accessibility (`AXIsProcessTrustedWithOptions`) — already mandated by `PermissionsManager`.
- **Secure input**: if `IsSecureEventInputEnabled()` returns true (password fields), injection may be swallowed; the text strip shows a lock glyph + explanatory tooltip instead of pretending to type.
- **Local echo buffer**: the panel cannot read the target field, so the top strip shows a session-local shadow of everything typed (chars appended; □ pops; L1/R1 move a local caret marker; it is best-effort and clearly styled as an echo, not the field). Optional enhancement (⚠️ best-effort): mirror the real field via `AXUIElementCopyAttributeValue(kAXFocusedUIElementAttribute → kAXValueAttribute)` when the target app supports AX, falling back to the echo buffer.

## A.9 Never stealing focus — window recipe

```swift
final class KeyboardPanel: NSPanel {
    override var canBecomeKey: Bool  { false }   // hard guarantee
    override var canBecomeMain: Bool { false }
}
// configuration:
styleMask = [.borderless, .nonactivatingPanel]
level = .statusBar                       // above normal windows, below screensaver
collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
isFloatingPanel = true
becomesKeyOnlyIfNeeded = true
hidesOnDeactivate = false
isMovableByWindowBackground = true
backgroundColor = .clear; isOpaque = false; hasShadow = true
contentView = NSHostingView(rootView: KeyboardView())   // SwiftUI content
```

Rules: show with `orderFrontRegardless()`; **never** call `NSApp.activate(ignoringOtherApps:)` or `makeKey…` while the panel is involved; the app runs as `LSUIElement`/`.accessory` when only the keyboard is up. Because *all* interaction comes from the controller through `handle(_:)` (never `NSEvent` keyboard input), the panel needs no key status — the frontmost app keeps first-responder status the entire time, so `CGEvent` output lands in its focused field. Mouse clicks on the panel (e.g. Options) are handled by the non-activating panel without activating our app.

---

# Part B — Hammerspoon Integration

## B.1 Verified platform facts ✅

| Fact | Source (verified this session) |
|---|---|
| `hammerspoon://eventName?p1=v1` — event name is the URL **host**, "No path should be specified in the URL"; query parsed to a string table | hammerspoon.org/docs/hs.urlevent.html |
| `hs.urlevent.bind(eventName, callback)`; callback receives `(eventName, params, senderPID, fullURL)`; pass `nil` to unbind | same |
| `hs` CLI "will not work unless the `hs.ipc` module is loaded first" → `require("hs.ipc")` in `init.lua`; `hs.ipc.cliInstall([path][,silent]) -> bool` (default prefix `/usr/local`, i.e. binary at `/usr/local/bin/hs`); `hs.ipc.cliStatus`, `hs.ipc.cliUninstall` | hammerspoon.org/docs/hs.ipc.html |
| Spoon = directory `Name.spoon` containing `init.lua`, installed in `~/.hammerspoon/Spoons/`; TitleCase names, camelCase members; metadata `obj.name`, `obj.version`, `obj.author`, `obj.license` (+ recommended `obj.homepage`); lifecycle `:init()` (auto-called by `hs.loadSpoon()`), `:start()`, `:stop()`, `:bindHotkeys(mapping)`; `hs.loadSpoon("NAME")` exposes `spoon.NAME`; helpers `hs.spoons.scriptPath()`, `hs.spoons.resourcePath()`, `hs.spoons.bindHotkeysToSpec()`; `docs.json` generated with `hs -c "hs.doc.builder.genJSON(...)"` | Hammerspoon SPOONS.md |
| `hs.spaces.toggleMissionControl()`, `hs.spaces.toggleLaunchPad()`, `hs.spaces.toggleShowDesktop()`, `hs.spaces.toggleAppExpose()` — all `-> None` | hammerspoon.org/docs/hs.spaces.html |
| `hs.eventtap.keyStroke(modifiers, character[, delay, application])` (delay in µs, default 200000) | hammerspoon.org/docs/hs.eventtap.html |
| `hs.eventtap.event.newSystemKeyEvent(key, isdown) -> event`, posted with `:post()`; **case-sensitive** keys incl. `PLAY NEXT PREVIOUS FAST REWIND MUTE SOUND_UP SOUND_DOWN BRIGHTNESS_UP BRIGHTNESS_DOWN EJECT POWER ILLUMINATION_UP ILLUMINATION_DOWN CAPS_LOCK` | hammerspoon.org/docs/hs.eventtap.event.html |
| `hs.window.focusedWindow() -> window`, `hs.window:moveToUnit(unitrect[, duration])`, `hs.window:maximize([duration])`, `hs.window:setFrame(rect[, duration])`, `hs.window:focus()`, `hs.window.animationDuration` (default 0.2; 0 disables) | hammerspoon.org/docs/hs.window.html |
| `hs.application.launchOrFocus(name) -> boolean` (name = on-disk app name), `hs.application.launchOrFocusByBundleID(bundleID) -> boolean`, `hs.application.frontmostApplication()` | hammerspoon.org/docs/hs.application.html |

⚠️ UNVERIFIED this session (exists per prior knowledge, re-check during implementation): `hs.window.switcher` (cmd-tab-style switcher object with `:next()`/`:previous()`), `hs.distributednotifications.post(name[, sender[, userInfo]])`, `hs.notify`.

## B.2 `DualSenseRemap.spoon` — packaging

```
Hammerspoon/DualSenseRemap.spoon/
├── init.lua          -- everything below
└── docs.json         -- generated: hs -c "hs.doc.builder.genJSON(\"$(pwd)\")" | grep -v "^--" > docs.json
```

Shipped inside the app bundle (`Resources/DualSenseRemap.spoon`), installable by the app into `~/.hammerspoon/Spoons/` (B.5). User config becomes:

```lua
-- ~/.hammerspoon/init.lua
require("hs.ipc")                 -- enables the `hs` CLI path
hs.loadSpoon("DualSenseRemap")
spoon.DualSenseRemap:start()
```

## B.3 `init.lua` — full contract

One URL event name (`dualSenseRemap`) with a `name` parameter, so the action registry lives in Lua and new actions need no re-binding. URL shape: `hammerspoon://dualSenseRemap?name=<action>&<extra args>`.

```lua
local obj = {}
obj.__index  = obj
obj.name     = "DualSenseRemap"
obj.version  = "1.0"
obj.author   = "DualSenseRemap <ossama.benjemaa@gmail.com>"
obj.homepage = "https://github.com/.../dualSenseRemap"
obj.license  = "MIT - https://opensource.org/licenses/MIT"

obj.userHooks = {}          -- user extension point: obj.userHooks["myAction"] = function(params) ... end
obj.snapDuration = 0        -- window animation seconds for snap actions

local function snap(unit)
  local w = hs.window.focusedWindow()
  if w then w:moveToUnit(unit, obj.snapDuration) end
end
local function media(key)                       -- key must match newSystemKeyEvent's case-sensitive names
  hs.eventtap.event.newSystemKeyEvent(key, true):post()
  hs.eventtap.event.newSystemKeyEvent(key, false):post()
end

obj.actions = {
  openLaunchpad  = function() hs.spaces.toggleLaunchPad() end,
  missionControl = function() hs.spaces.toggleMissionControl() end,
  showDesktop    = function() hs.spaces.toggleShowDesktop() end,
  appExpose      = function() hs.spaces.toggleAppExpose() end,
  appSwitcher    = function() hs.eventtap.keyStroke({"cmd"}, "tab") end,  -- see note below
  focusApp       = function(p)
                     if p.bundleID then hs.application.launchOrFocusByBundleID(p.bundleID)
                     elseif p.app  then hs.application.launchOrFocus(p.app) end
                   end,
  media          = function(p) if p.key then media(p.key) end end,        -- PLAY|NEXT|PREVIOUS|MUTE|SOUND_UP|SOUND_DOWN|...
  snapLeft       = function() snap({x=0,   y=0, w=0.5, h=1}) end,
  snapRight      = function() snap({x=0.5, y=0, w=0.5, h=1}) end,
  snapMax        = function() local w = hs.window.focusedWindow(); if w then w:maximize(obj.snapDuration) end end,
  snapTopLeft    = function() snap({x=0, y=0,   w=0.5, h=0.5}) end,
  snapTopRight   = function() snap({x=0.5, y=0, w=0.5, h=0.5}) end,
  snapBottomLeft = function() snap({x=0, y=0.5, w=0.5, h=0.5}) end,
  snapBottomRight= function() snap({x=0.5, y=0.5, w=0.5, h=0.5}) end,
  ping           = function() hs.distributednotifications.post("dsrPong", nil, {version = obj.version}) end, -- ⚠️ verify module
}

function obj:handle(name, params)
  local fn = self.actions[name] or self.userHooks[name]
  if fn then
    local ok, err = pcall(fn, params or {})
    if not ok then print("[DualSenseRemap] action '" .. name .. "' failed: " .. tostring(err)) end
    return true
  end
  print("[DualSenseRemap] unknown action: " .. tostring(name)); return false
end

function obj:init() return self end
function obj:start()
  hs.urlevent.bind("dualSenseRemap", function(eventName, params, senderPID, fullURL)
    self:handle(params.name, params)
  end)
  return self
end
function obj:stop() hs.urlevent.bind("dualSenseRemap", nil); return self end

function obj:bindHotkeys(mapping)               -- optional keyboard equivalents, per Spoon convention
  local spec = {}
  for action in pairs(self.actions) do spec[action] = function() self:handle(action, {}) end end
  hs.spoons.bindHotkeysToSpec(spec, mapping)
  return self
end

return obj
```

Notes: `appSwitcher` via `keyStroke({"cmd"},"tab")` only flips to the previous app; for a real visual switcher use `hs.window.switcher.new()` kept as a spoon field and drive `:next()` / `:previous()` from two actions (`appSwitcherNext`/`appSwitcherPrev`) — ⚠️ verify `hs.window.switcher` API at implementation time. `userHooks` is the custom-hook surface: users add functions in their `init.lua` after `hs.loadSpoon`, and the app exposes a free-text "Hammerspoon action name" field in the mapping UI so any hook is triggerable from a controller button.

## B.4 App-side invocation — `HammerspoonBridge`

**Detection** (`isInstalled`): `NSWorkspace.shared.urlForApplication(withBundleIdentifier: "org.hammerspoon.Hammerspoon") != nil`. Running: `NSRunningApplication.runningApplications(withBundleIdentifier:).isEmpty == false`. CLI present: `FileManager.default.isExecutableFile(atPath: "/usr/local/bin/hs")` (also probe `/opt/homebrew/bin/hs` — Apple-Silicon Homebrew users may have installed with a different prefix; `cliInstall` default is `/usr/local` ✅).

**Primary channel — URL scheme** (fire-and-forget, ~50–150 ms latency, works even though sandbox-free, no IPC setup needed):

```swift
var comps = URLComponents()
comps.scheme = "hammerspoon"
comps.host   = "dualSenseRemap"                       // event name = host; NO path (verified requirement)
comps.queryItems = [URLQueryItem(name: "name", value: event)] + params.map(URLQueryItem.init)
let cfg = NSWorkspace.OpenConfiguration()
cfg.activates = false                                  // CRITICAL: do not let Hammerspoon steal focus
NSWorkspace.shared.open(comps.url!, configuration: cfg) { _, error in ... }
```

`URLComponents` handles percent-encoding (bundle IDs, media key names). Debounce identical events within 50 ms (button-repeat storms).

**Secondary channel — `hs` CLI via `Process`** (synchronous, returns exit status; used for health checks and for actions needing a result):

```swift
let p = Process()
p.executableURL = URL(fileURLWithPath: hsPath)         // /usr/local/bin/hs
p.arguments = ["-c", "return spoon.DualSenseRemap and spoon.DualSenseRemap:handle('\(event)', \(luaTable)) or 'NOSPOON'"]
```

Requires `require("hs.ipc")` in the user's `init.lua` (verified requirement) — the installer snippet (B.5) adds it. Use CLI for: startup handshake ("is the Spoon loaded and started?"), and diagnostics in the app's Hammerspoon settings pane. Use URL for all hot-path triggers (no process-spawn cost, no shell quoting risk — never interpolate unsanitized user strings into the `-c` Lua; prefer the URL channel for user-defined hook names).

**Handshake**: on launch and on demand, `trigger("ping")`; the Spoon posts a `dsrPong` distributed notification which the app observes via `DistributedNotificationCenter.default()` (⚠️ `hs.distributednotifications` unverified — fallback handshake: CLI `hs -c "return spoon.DualSenseRemap.version"`).

## B.5 Fallbacks when Hammerspoon is absent (`trigger` returns `false` → native path)

Degradation ladder per event: **1)** URL → Spoon; **2)** `hs` CLI; **3)** native equivalent; **4)** user-visible toast "Requires Hammerspoon" + install guidance.

| Event | Native fallback (already-granted Accessibility permission assumed) |
|---|---|
| openLaunchpad | `NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: "/System/Applications/Launchpad.app"), ...)` |
| missionControl | Open `/System/Applications/Mission Control.app` (its sole purpose is toggling MC) |
| showDesktop | ⚠️ no clean public API: post the user's configured shortcut (default F11/fn-F11) via `CGEvent`, or `Mission Control.app` with argument `1` (private, avoid). Mark degraded in UI |
| appExpose | `CGEvent` ⌃↓ (default shortcut) — degraded, may fail if user rebound it |
| appSwitcher | `CGEvent` ⌘⇥ (post ⌘ down, ⇥ tap, ⌘ up with 150 ms hold to show the HUD) |
| focusApp | `NSWorkspace.shared.openApplication(at:configuration:)` resolved via `urlForApplication(withBundleIdentifier:)` |
| media keys | Already native: `EventSynthesizer.mediaKey` posting `NX_KEYTYPE_*` (PLAY/NEXT/PREVIOUS/SOUND_UP/…) via `NSEvent.otherEvent(with: .systemDefined, subtype: 8, ...)` — Hammerspoon not needed; the Spoon route exists only so users can intercept/customize |
| snapLeft/Right/Max/quarters | Native AX: `AXUIElementCopyAttributeValue(kAXFocusedWindowAttribute)` on the frontmost app, then `AXUIElementSetAttributeValue` for `kAXPositionAttribute`/`kAXSizeAttribute` computed from `NSScreen.visibleFrame` halves/quarters. Full parity with the Spoon |
| custom user hooks | No native equivalent by definition → toast + "Open Hammerspoon guide" button |

**Install guidance UI** (shown when `isInstalled == false` and a Hammerspoon-only action is mapped): sheet with (1) `brew install --cask hammerspoon` copy button + link to hammerspoon.org; (2) "Install Spoon" button → copies `Resources/DualSenseRemap.spoon` to `~/.hammerspoon/Spoons/` and, with explicit consent, appends the three config lines from B.2 to `~/.hammerspoon/init.lua` (creating it if missing), then opens Hammerspoon; (3) note that Hammerspoon needs its **own** Accessibility grant; (4) "Reload Hammerspoon config" action (URL `hammerspoon://dualSenseRemap?name=reload` after adding a `reload = hs.reload` action, or CLI `hs -c "hs.reload()"`).

**Security note**: `hammerspoon://` URLs are openable by any local process; the Spoon must treat params as untrusted strings (it only indexes a whitelisted action table — arbitrary Lua never comes from the URL). `userHooks` run arbitrary user Lua by design; document this in the settings pane.

---

## Open items / explicitly unverified

1. Sony's real French PS5 OSK row layout (A.3) — adaptation designed per task; revisit if a capture is found.
2. L2=Shift on the PS5 OSK — convention + task brief; R2=Done, △=space, □=backspace, L3+R3 typing-mode chord are sourced.
3. Sony's exact `@#:` symbol inventory and accent-page grid (A.5/A.6) — designed supersets.
4. `hs.window.switcher`, `hs.distributednotifications`, `hs.notify` exact signatures — re-verify at implementation.
5. `CGEventKeyboardSetUnicodeString` 20-code-unit practical limit — widely reported, confirm empirically in `EventSynthesizer` tests.

Sources: [hs.urlevent](https://www.hammerspoon.org/docs/hs.urlevent.html) · [hs.ipc](https://www.hammerspoon.org/docs/hs.ipc.html) · [hs.spaces](https://www.hammerspoon.org/docs/hs.spaces.html) · [hs.eventtap](https://www.hammerspoon.org/docs/hs.eventtap.html) · [hs.eventtap.event](https://www.hammerspoon.org/docs/hs.eventtap.event.html) · [hs.window](https://www.hammerspoon.org/docs/hs.window.html) · [hs.application](https://www.hammerspoon.org/docs/hs.application.html) · [Hammerspoon SPOONS.md](https://github.com/Hammerspoon/hammerspoon/blob/master/SPOONS.md) · [PlayStation support — keyboard/mouse on PS5](https://www.playstation.com/en-us/support/hardware/keyboard-mouse-ps5/) · [PS5 button functions](https://www.playstation.com/en-us/support/hardware/ps5-button-functions/) · [seekingtech — PS5 motion/touchpad typing (L3+R3)](https://seekingtech.com/how-to-enable-and-disable-ps5-motion-and-touchpad-typing/) · [GameFAQs — PS5 virtual keyboard Done/R2 thread](https://gamefaqs.gamespot.com/boards/264562-playstation-5/80374978) · [Typing fast on PS5 keyboard (△ space, □ backspace)](https://www.youtube.com/watch?v=atXSJ6VQ_Qc) · [jeuxvideo.com — clavier AZERTY PS5](https://www.jeuxvideo.com/forums/42-3009344-75064239-1-0-1-0-clavier-en-qwerty-sur-ps5.htm)