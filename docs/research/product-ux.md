# DualSense Remap — Product & UX Specification

**Version:** 1.0 (v1 scope definition)
**Date:** 2026-07-27
**Author:** Product / UX Research
**Platform:** macOS 14+ (Apple Silicon & Intel), PS5 DualSense & DualSense Edge (USB-C / Bluetooth)

---

## 1. Product Vision & Positioning

**One-liner:** *Logi Options+ for your DualSense.* A native macOS app that turns the PS5 controller into a first-class Mac input device — remap every button, stick, trigger, the touchpad, gyro, lightbar and haptics — with per-app profiles that switch automatically, wrapped in a polished, animated, card-based UI that feels like it shipped from Cupertino.

**Why now / why us:**
- The DualSense is the most sensor-rich mainstream controller ever made (dual analog sticks, analog triggers, gyro+accelerometer, capacitive multitouch pad, RGB lightbar, voice-coil haptics, speaker, mic), yet on macOS it is treated as a dumb gamepad.
- Existing macOS mappers (Enjoyable, Joystick Mapper, ReControl, JoyMapper) are functional but utilitarian: list-based UIs, no per-app auto-switching (mostly), no DualSense-specific features (gyro, touchpad, lightbar, haptics), minimal onboarding for macOS's notoriously confusing permission flow.
- Windows tools (DS4Windows, DSX) prove demand for deep DualSense exploitation — game-specific profiles, gyro aiming, lightbar-as-battery-meter, adaptive-trigger tuning — but nothing on macOS matches them, and none of them have consumer-grade UX.
- Logi Options+ proves that a hardware-render-with-hotspots UI makes remapping discoverable and delightful for non-technical users. We adopt that interaction grammar for a controller.

**North-star experience:** A user plugs in a DualSense, is walked through macOS permissions in under 90 seconds, sees a beautiful 3D render of *their* controller (correct color) with callout lines to every control, clicks the △ button, picks "Media → Play/Pause," and it just works — in every app, or only in Spotify, their choice. Physical button presses light up on screen in real time.

**Non-goals for v1:** virtual gamepad emulation (Xbox 360/DS4 emulation for games), Windows/Linux, non-PlayStation controllers, cloud sync.

---

## 2. Research Summary

### 2.1 Logi Options+ UX Teardown (what we adopt)

From reviews and documentation of Logi Options+ (notably the MX Master 4 deep-dive on DataHolic and Logitech's own support docs):

| Logi Options+ pattern | Description | DualSense Remap adaptation |
|---|---|---|
| **Home / device carousel** | Start screen with time-of-day greeting, "Add Device," central carousel of device tiles showing photo, name, battery %, connection type; inactive devices grayed out | Home shows controller tiles (each paired DualSense, correct body color), battery ring, USB/BT badge, active profile chip |
| **Left-side section nav** | Buttons · Point/Scroll/Press · Haptic Feedback · Easy-Switch · Flow · Settings | Sidebar: Controller · Profiles · Virtual Keyboard · Hammerspoon · Settings |
| **Hardware render + hotspots** | Realistic 3D render; every mappable element gets a labeled hotspot with a callout line; clicking a hotspot opens the assignment menu. "Users learn what's mappable by exploring the visual" | ¾-view DualSense render with ~24 hotspots covering *every* control incl. gyro, lightbar, haptics, battery |
| **Assignment menu (popover)** | Context-sensitive menu per control: categories of actions, global vs per-app scope | Two-pane popover: category list → action list → inline option controls (thresholds, sensitivity) |
| **"Add Application" side panel** | Panel titled "Select Applications": Global settings toggle, predefined customizations (Chrome, Teams…), other applications; per-app settings silently override global on focus | Profiles tab + in-context app switcher pill above the render; curated presets for Safari, Spotify, Keynote, DaVinci Resolve, Photoshop, Steam |
| **Fine-tuning pages** | Sliders/toggles for pointer speed, SmartShift force, scroll direction, press sensitivity; haptics intensity slider | Sticks & Gyro tuning drawer: deadzone, curves, sensitivity; Feedback drawer: lightbar, rumble intensity |
| **Onboarding & permissions** | Explicit macOS walkthrough for Input Monitoring, Accessibility, Bluetooth permissions with "Quit & Reopen" handling; "Launch Feature Tour" re-runnable from Settings | Full permission wizard with live status detection, deep links into System Settings, and re-runnable tour |
| **Backup/restore settings** | Auto-backup toggle, restore, reset-to-default | Local profile export/import (JSON), reset per control / per profile |

Key takeaway: Options+'s genius is that **the product render *is* the interface** — documentation, discovery, and configuration collapse into one surface. We replicate the grammar (render → hotspot → popover → scope), not the assets.

### 2.2 Competitive Feature Matrix

| Capability | Enjoyable (free, macOS) | Joystick Mapper / JoyMapper (macOS) | ReControl (macOS) | DS4Windows (Win) | DSX / DualSenseX (Win) | **DualSense Remap v1 (target)** |
|---|---|---|---|---|---|---|
| Button → key | ✓ | ✓ | ✓ (incl. modifier combos, right-side modifiers) | ✓ | ✓ | ✓ Must |
| Key combos / chords | – | partial | ✓ | ✓ | ✓ | ✓ Must |
| Mouse buttons / pointer via stick | ✓ basic | ✓ | ✓ smooth, eased, 4 directions independent | ✓ | ✓ | ✓ Must |
| Scrolling via stick | – | ✓ | ✓ eased | ✓ | ✓ | ✓ Must |
| Stick modes (smooth vs 8-way) | – | – | ✓ | ✓ | ✓ | ✓ Must |
| Deadzone / drift calibration / response curves | – | – | ✓ (linear/exponential, drift detection) | ✓ | ✓ | ✓ Must |
| Trigger analog threshold as button | – | – | partial | ✓ | ✓ | ✓ Must |
| Per-app auto-switching profiles | profiles, manual | manual | ✗ | ✓ auto by process | ✓ per-game | ✓ Must (auto) |
| Macros (recorded sequences) | – | – | – | ✓ | ✓ | ✓ Should |
| App launch / shell command | – | – | – | partial | – | ✓ Should |
| Gyro → mouse aiming | – | – | ✗ | ✓ (tilt, motion aim, gestures) | ✓ | ✓ Should |
| Touchpad as trackpad (multitouch) | – | – | ✗ | ✓ (L/R click zones) | ✓ | ✓ Should |
| Lightbar config (color, battery display, profile status) | – | – | – | ✓ | ✓ | ✓ Must (basic) |
| Haptics / rumble feedback config | – | – | – | ✓ | ✓ (full haptics via audio) | ✓ Should |
| Adaptive trigger effects (resistance modes, start point, force) | – | – | – | ✓ per-profile, L2/R2 linked or split | ✓ (signature feature) | Could |
| Battery display | – | – | – | ✓ | ✓ | ✓ Must |
| Mute button / mic LED control | – | – | – | – | ✓ | ✓ Should |
| Import/export config | – | – | ✓ JSON | ✓ | ✓ | ✓ Must |
| Polished consumer UX | ✗ | ✗ | ✗ | ✗ | partial | **✓ differentiator** |

Also noted: community tools (e.g., NSEvent/xbox-controller-mapper on GitHub) demonstrate demand for touchpad **swipe typing**, gyro, and scripting/OBS integration on macOS — validation for our Virtual Keyboard and Hammerspoon pillars.

**Whitespace we own:** (1) only macOS-native app exploiting the *full* DualSense sensor suite; (2) per-app auto-switching on macOS; (3) Options+-grade visual UX; (4) power-user escape hatch via Hammerspoon instead of building a fragile in-house scripting engine.

---

## 3. Personas & Top Use Cases

### P1 — "Couch Commander" · Maya, 29, media enthusiast
Mac mini connected to the living-room TV. Wants to browse, control YouTube/Netflix/Spotify/Plex, and adjust volume without a keyboard on her lap.
- **JTBD:** "When I'm on the couch, I want to drive my whole Mac with the controller already in my hands, so I never dig for the trackpad."
- **Key features:** stick→pointer with easing, ✕=click, ○=Esc, touchpad-as-trackpad, media keys on d-pad, Virtual Keyboard for search fields, battery on lightbar, menu-bar profile "Couch."
- **Success:** completes a full "open Safari → search → play video → adjust volume → sleep display" loop controller-only.

### P2 — "Adaptive Achiever" · Tomás, 41, limited fine-motor control in hands
Uses a game controller as his primary pointing device because sticks and large face buttons are easier than a mouse. Needs *reliability* and deep tunability.
- **JTBD:** "When my hands are having a bad day, I want to lower sensitivity and use big buttons for clicks/modifiers, so the Mac stays fully usable."
- **Key features:** per-control sensitivity curves, large deadzones, toggle-mode (press once = hold Shift), sticky modifiers, dwell-click option, trigger threshold tuning (light pulls register), haptic confirmation on action fire, high-contrast UI, full VoiceOver support in the app itself.
- **Success:** all daily computing tasks doable; zero missed/phantom inputs in a week of use.
- **Note:** this persona raises the accessibility bar for the whole product — every feature must be operable without precise pointing.

### P3 — "Creative Operator" · Jae, 34, video editor & photographer
Runs DaVinci Resolve, Lightroom, Photoshop. Wants a left-hand "console": jog/shuttle on a stick, tool shortcuts on face buttons, macro on △ ("flatten, export, close").
- **JTBD:** "When I'm editing, I want repetitive shortcut chains on physical buttons with analog control for scrubbing, so I stay in flow."
- **Key features:** per-app profiles auto-switching (Resolve vs Lightroom), macros with timing, key-combo bindings, trigger analog → parameter scrub (arrow-key repeat rate proportional to pull), gyro nudge for fine brush moves, R2 pressure → brush-size chords.
- **Success:** measurable — one hand stays on controller during a full edit session; ≥10 bindings created in first week.

### P4 — "The Presenter" · Amara, 38, sales lead
Keynote/PowerPoint/Google Slides. Controller as a premium presenter remote with a pointer.
- **JTBD:** "When presenting, I want next/previous slide, a laser pointer, and blackout on a device that never drops Bluetooth mid-pitch."
- **Key features:** "Presentation" starter profile (R1=next, L1=previous, R2 hold=gyro laser pointer via mouse move, △=blackout 'B', ✕=play video), per-app profile bound to Keynote, lightbar dimmed/off during presentation, battery warning before she starts.
- **Success:** runs a 30-min deck without touching the Mac.

### P5 — "The Tinkerer" · Dev, 26, gamer & automation nerd
Plays emulators/cloud gaming and unsupported ports; runs Hammerspoon; wants gyro aiming in games without native support and shell commands on button chords.
- **JTBD:** "When a game or workflow doesn't support my controller, I want to build the glue myself, so nothing is off-limits."
- **Key features:** gyro→mouse with tunable sensitivity/activation button, per-game profiles, shell command & Hammerspoon function bindings, shift-layers (hold Create = layer 2), JSON export, low input latency (<8 ms added).
- **Success:** ships his config to a friend as a JSON file; posts about it.

**Top 8 use cases (ranked):** 1) couch media & browsing · 2) full pointer replacement (accessibility) · 3) creative-app shortcut deck · 4) presentations · 5) playing keyboard/mouse-only games with the controller (incl. gyro aim) · 6) system control (volume, brightness, Mission Control, window snapping) · 7) text entry via Virtual Keyboard · 8) automation triggers (Hammerspoon/shell/Shortcuts).

---

## 4. Feature List — MoSCoW for v1

### MUST (v1 ships with all of these)
**Connectivity & engine**
- M1. Detect & connect DualSense / DualSense Edge over USB-C and Bluetooth; reconnect automatically; multiple paired controllers (one active at a time).
- M2. Low-latency input engine (<8 ms added latency target, 250 Hz+ polling); global pause/resume ("engine off" = controller passthrough/inert).
- M3. Battery level read-out (app header, home tile, menu bar) with low-battery notification (20%/10%).
- M4. Live input echo: physical presses highlight the corresponding on-screen hotspot in real time.

**Remapping (all controls bindable)**
- M5. Bindable inputs: ✕ ○ □ △, d-pad ×4, L1 R1, L2 R2 (digital *and* analog threshold), L3 R3, Create, Options, PS, Mute, touchpad click (whole / left-zone / right-zone), touchpad surface (as pointer or gesture pad — basic), stick directions (×8), stick modes.
- M6. Output actions: single key; key + any modifier combo (incl. right-side modifiers); text snippet; mouse buttons (left/right/middle/4/5); mouse click-and-hold (drag mode); scroll (line/page, both axes); media & system keys (play/pause, next/prev, volume, brightness, Mission Control, Launchpad, Spotlight, screenshot, lock, sleep); "Do nothing / disable."
- M7. Behavior modifiers per binding: tap vs hold (long-press = second action), toggle (press = hold down until pressed again), repeat while held (with rate), sticky modifier.
- M8. Stick modes: **Pointer** (eased mouse), **Scroll**, **Arrows/WASD (8-way digital)**, **Media dial**, **Off** — per stick.
- M9. Stick tuning: deadzone (inner/outer), sensitivity, response curve (linear / eased / aggressive / custom bezier), invert axes, drift auto-calibration.
- M10. Trigger analog: threshold slider with live pull preview; soft-pull and full-pull as two distinct bindable events.
- M11. Profiles: create/rename/duplicate/delete; **per-app auto-switching** (frontmost app detection); Default (global) profile with per-app overrides; manual override from menu bar; import/export JSON.
- M12. Lightbar basics: solid color per profile, brightness, **battery-meter mode**, off.

**Experience**
- M13. Onboarding wizard incl. full macOS permission walkthrough (Input Monitoring, Accessibility, Bluetooth) with live grant detection and deep links.
- M14. Menu-bar item: battery, active profile, profile switcher, pause engine, open app.
- M15. Light & dark mode, full keyboard navigability + VoiceOver labels in-app.
- M16. Starter profile gallery (Couch & Media, Trackpad+, Presentation, Creative Deck, Blank).
- M17. Conflict & sanity warnings ("no binding for click — you may not be able to click", duplicate binding notice).

### SHOULD (target v1, may slip to v1.1)
- S1. Macros: recorded or hand-built sequences of keys/clicks/delays; assign to any control; loop option.
- S2. Launch app / open file or URL / run shell command / run Apple Shortcut.
- S3. **Gyro → pointer** ("air mouse"): activation modes (always / while held / touchpad-touch activation), sensitivity, axis choice (yaw vs roll), smoothing.
- S4. **Touchpad as trackpad**: two-finger scroll, tap-to-click, click zones L/R, swipe gestures ←→↑↓ bindable.
- S5. Haptic feedback config: rumble intensity master slider; optional "confirm tick" on action fire; per-profile on/off.
- S6. Shift-layer: hold a designated control to activate an alternate binding layer (doubles capacity).
- S7. Hammerspoon integration (see §5.10): bind any control to a Hammerspoon Lua function/URL event.
- S8. Virtual Keyboard v1 (see §5.9): controller-navigable on-screen keyboard overlay.
- S9. Mute-button mic LED control; lightbar pulse on profile switch.
- S10. Per-profile stick/gyro tuning (not just global).

### COULD (explicitly v1.2+ backlog, designed-for but not built)
- C1. Adaptive trigger resistance effects (rigid/trigger/vibration modes, start point, force — DSX-style) as *feedback themes* per profile.
- C2. Touchpad swipe-typing on the Virtual Keyboard.
- C3. Controller speaker cues (audio feedback for profile switch / low battery).
- C4. Multiple simultaneous active controllers (co-pilot mode; merge inputs).
- C5. DualSense Edge extras: back paddles, Fn buttons, profile hardware slots.
- C6. Community profile sharing / gallery in-app.
- C7. MIDI output mode for music apps.
- C8. OBS/streaming integrations.

### WON'T (v1 — stated to protect scope)
- W1. Virtual gamepad emulation (presenting as Xbox/DS4 to games).
- W2. Windows/Linux versions; iOS companion.
- W3. Non-PlayStation controllers.
- W4. Cloud sync / accounts (local-first; JSON export is the portability story).
- W5. Firmware updates for the controller.

---

## 5. UX Blueprint

### 5.1 App Structure & Window Layout

Single main window, min 1024×720, resizable; content is card-based on a quiet background, Options+-style. Structure:

```
┌────────────────────────────────────────────────────────────────────────┐
│ ●●●  DualSense Remap                                (toolbar-less; title │
│                                                      in sidebar header) │
├──────────────┬─────────────────────────────────────────────────────────┤
│  SIDEBAR      │  CONTENT AREA                                          │
│               │ ┌─────────────────────────────────────────────────────┐│
│  🎮 Controller │ │  Context header: [Controller name ▾]  ⬤ 82% 🔋 BT   ││
│  🗂 Profiles   │ │  [Profile scope pill: "Default ▾"]  [+ Add App]     ││
│  ⌨️ Virtual    │ ├─────────────────────────────────────────────────────┤│
│     Keyboard  │ │                                                     ││
│  🔨 Hammer-    │ │   (page content — e.g., controller render with      ││
│     spoon     │ │    hotspot callouts, cards, editors)                ││
│  ⚙️ Settings   │ │                                                     ││
│               │ └─────────────────────────────────────────────────────┘│
│  ── footer ── │                                                        │
│  Engine ● On  │                                                        │
└──────────────┴─────────────────────────────────────────────────────────┘
```

- **Sidebar** (fixed, 220 pt, translucent material): five items — **Controller, Profiles, Virtual Keyboard, Hammerspoon, Settings** — with SF Symbols, selected state = filled tint pill. Footer shows engine status with an instant on/off toggle (the "big red switch" — always one click away).
- **Context header** (Controller & Profiles pages): controller picker (if >1 paired) with battery ring + connection badge; profile-scope pill showing which profile you're editing; "+ Add App" button (Options+ pattern).
- **First launch / no controller:** Controller page shows the **connect state** — greeting ("Good evening"), an illustrated "Connect your DualSense" card with USB and Bluetooth pairing instructions (hold Create + PS until lightbar pulses), animated search radar. When ≥2 controllers are paired, a **device carousel** of controller tiles (rendered in their real body color, name, battery, connection) appears here, Options+-style; clicking a tile enters its detail page.

### 5.2 Sidebar Sections (summary)

| Section | Purpose |
|---|---|
| **Controller** | The hero page: render + hotspots + all mapping/tuning (§5.3–5.5) |
| **Profiles** | Manage profiles & per-app assignments, starter gallery, import/export (§5.6) |
| **Virtual Keyboard** | Configure & preview the controller-driven on-screen keyboard (§5.9) |
| **Hammerspoon** | Detect install, manage function bindings, snippets, test console (§5.10) |
| **Settings** | Permissions status, engine, notifications, appearance, backup, tour (§5.11) |

### 5.3 Controller Detail Page — Hotspot Map for EVERY Control

**Layout:** large ¾ front-top render of the DualSense centered in the content area (so face buttons, sticks, touchpad, *and* the top edge with L1/L2/R1/R2 are all visible). Thin callout lines connect each control to a **label chip** arranged in two columns left/right of the render plus a row beneath. Chips show the control glyph + current binding summary (e.g., `△ — Play/Pause`); unmapped chips read "Default". A segmented **view switcher** above the render:

`[ Buttons ]  [ Sticks & Triggers ]  [ Motion & Touch ]  [ Light & Feedback ]`

Each view shows the same render (camera subtly rotates/zooms between views — see Motion §6.6) but reveals only that view's callouts to avoid 24 simultaneous lines.

**Complete hotspot inventory (24 hotspots):**

| # | View | Hotspot | Callout position | Popover opens to |
|---|---|---|---|---|
| 1 | Buttons | ✕ Cross | right col | Action mapping popover |
| 2 | Buttons | ○ Circle | right col | Action mapping popover |
| 3 | Buttons | □ Square | right col | Action mapping popover |
| 4 | Buttons | △ Triangle | right col | Action mapping popover |
| 5 | Buttons | D-pad Up | left col | Action mapping popover |
| 6 | Buttons | D-pad Down | left col | Action mapping popover |
| 7 | Buttons | D-pad Left | left col | Action mapping popover |
| 8 | Buttons | D-pad Right | left col | Action mapping popover |
| 9 | Buttons | Create | left col (upper) | Action mapping popover (suggests "shift-layer" here) |
| 10 | Buttons | Options | right col (upper) | Action mapping popover |
| 11 | Buttons | PS button | bottom row | Action mapping popover (default: open menu-bar switcher) |
| 12 | Buttons | Mute button | bottom row | Action mapping popover + mic-LED toggle |
| 13 | Sticks & Triggers | L1 | left col (top) | Action mapping popover |
| 14 | Sticks & Triggers | R1 | right col (top) | Action mapping popover |
| 15 | Sticks & Triggers | **L2 (analog)** | left col (top) | Trigger popover: threshold slider w/ live pull gauge; soft-pull & full-pull bindings |
| 16 | Sticks & Triggers | **R2 (analog)** | right col (top) | Same as L2 |
| 17 | Sticks & Triggers | **Left stick** (surface) | left col | Stick popover: mode picker (Pointer/Scroll/8-way/Media dial/Off) + "Tune…" |
| 18 | Sticks & Triggers | **Right stick** (surface) | right col | Stick popover (same) |
| 19 | Sticks & Triggers | L3 (stick click) | left col | Action mapping popover |
| 20 | Sticks & Triggers | R3 (stick click) | right col | Action mapping popover |
| 21 | Motion & Touch | **Touchpad — click** | top center | Click popover: whole-pad / split L-R zones → action mapping each |
| 22 | Motion & Touch | **Touchpad — surface** | top center (second chip) | Surface popover: mode (Trackpad / Gesture pad / Off); gestures ←→↑↓ + two-finger scroll config |
| 23 | Motion & Touch | **Gyro** (chip anchored to controller body w/ motion glyph) | center-left | Gyro popover: mode (Off / Pointer always / While-button-held / While-touchpad-touched), sensitivity, axis, smoothing, "Recenter" binding |
| 24 | Light & Feedback | **Lightbar** | top center | Lightbar popover: color swatch per profile, brightness, Battery-meter mode, Off, "pulse on profile switch" |
| 25 | Light & Feedback | **Haptics** (chip on grips) | bottom row | Haptics popover: master intensity, confirm-tick on action, per-profile toggle |
| 26 | Light & Feedback | **Battery** (chip near USB port glyph) | bottom row | Battery popover: current %, charging state, low-battery alerts config, "show on lightbar" shortcut |

**Interaction rules:**
- Hover on chip or on render region → both highlight (magnetic pairing), callout line brightens.
- Click → render zooms ~15% toward the control; **popover** anchors to the chip.
- **Physical input echo:** pressing a physical control flashes its hotspot (accent glow) even mid-edit — pressing △ while the popover is open for ✕ switches the popover to △ if the "follow controller" toggle (default on during editing session) is active. This makes "press the button you want to edit" the fastest nav path.
- Every chip and popover is keyboard/VoiceOver accessible (chips are buttons in a logical order).
- Search field (⌘F) filters chips ("play" → highlights any control bound to Play/Pause).
- Scope pill above render controls whether you're editing **Default** or a per-app profile; editing while an app profile is selected shows overridden chips with a small dot badge (Options+'s silent-override model, made visible).

### 5.4 Mapping Editor Popover Flow

The core loop. Popover ~380×460 pt, two stages with slide transition:

**Stage 1 — Category list** (with icons, current binding shown at top with "× Remove"):
1. **Keyboard** — single key or combo (capture field: "press keys now", supports modifiers-only)
2. **Text Snippet** — type a string to emit
3. **Mouse** — left/right/middle/4/5 click, double-click, click-and-hold (drag), scroll up/down/left/right
4. **Media & System** — play/pause, next/prev, vol ±, mute, brightness ±, Mission Control, App Exposé, Launchpad, Spotlight, Notification Center, screenshot, lock screen, sleep displays, dictation
5. **Navigation** — Esc, Enter, Tab/Shift-Tab, arrows, Home/End, Page ↑↓, back/forward (⌘[ ⌘])
6. **Apps & Automation** — launch app, open file/folder/URL, run Apple Shortcut, run shell command *(Should)*, Hammerspoon function *(Should)*
7. **Macros** — pick existing or "Record new…" *(Should)*
8. **Remap Controls** — this app's own functions: switch profile, cycle profiles, toggle engine, show Virtual Keyboard, gyro recenter, shift-layer while held
9. **Disabled** — do nothing

**Stage 2 — Action config:** action-specific fields plus universal **Behavior** section:
- Trigger style: `On press` / `On release` / `Tap vs Hold` (two actions, hold delay slider 200–800 ms) / `Toggle` / `Turbo (repeat while held)` + rate slider.
- Scope reminder footer: "Applies to: Default profile" or "Only in: Keynote" with a scope switcher link.
- Footer buttons: `Cancel` · `Save` (primary). Saving animates the chip label updating + a subtle haptic tick on the controller itself (delightful confirmation, Should).

**Specialized popovers:**
- **Trigger (L2/R2):** live vertical gauge mirrors the physical pull; draggable threshold handle on the gauge ("fires here"); optional second threshold to define soft-pull vs full-pull bands; each band gets its own Stage-1/2 flow via tabs.
- **Stick:** mode segmented control; below it a mode-specific panel — Pointer: sensitivity slider + "Tune curve…" opens the curve editor sheet (deadzone rings drawn over a live stick-position dot, curve graph with draggable points, invert toggles, "Fix drift" auto-calibrate button); 8-way: per-direction key capture grid (8 capture fields around a compass); Scroll: speed + natural-scrolling toggle; Media dial: choose volume or brightness.
- **Gyro:** activation mode; sensitivity X/Y; smoothing; live preview canvas (a dot that moves as you tilt the physical controller — makes tuning tangible).
- **Touchpad surface:** mode; in Trackpad mode: tracking speed, tap-to-click, two-finger scroll; in Gesture mode: four capture fields (swipe ←→↑↓).

### 5.5 Tuning Drawers
"Sticks & Triggers" and "Motion & Touch" views include a **"Fine-tune" card row** beneath the render (Options+'s Point/Scroll/Press analog): sliders for global pointer speed, scroll speed, press-hold delay, and a "test area" card (a sandbox rectangle to move the pointer/scroll inside without affecting the system).

### 5.6 Per-App Profile Management

**Model (mirrors Options+, made explicit):**
- One **Default** profile is always active as the base.
- **App profiles** override Default *only for the controls they redefine* (chips show override badges). When the frontmost app matches, overrides apply within 100 ms; on app switch away, they revert. Optional lightbar pulse + menu-bar flash on switch.
- **Manual profiles** (not app-bound, e.g., "Couch") can be pinned from the menu bar and suppress auto-switching until unpinned.

**Flows:**
1. **In-context (primary):** on the Controller page, click **"+ Add App"** → side panel "Select Applications" slides in: search field; *Suggested* (running + curated: Safari, Chrome, Spotify, Keynote, PowerPoint, Photoshop, DaVinci Resolve, Steam — curated ones offer a prefilled preset with a "Preview bindings" link); *All Applications* (from /Applications). Ticking an app creates its profile and switches the scope pill to it. Now every mapping edit applies to that app only.
2. **Profiles tab (management):** left list of profiles (Default pinned top; app profiles with app icons; manual profiles with custom glyph/color) + right detail: bound app(s) (a profile can bind to multiple apps), binding summary table (control → action, override badges), actions: rename, duplicate, export, delete, "Open in Controller view." Top of page: **Starter gallery** carousel (Couch & Media, Trackpad+, Presentation, Creative Deck, Blank) with preview cards → "Use this" clones it as a manual or app profile.
3. **Conflict handling:** two profiles bound to the same app → inline warning with radio choice of winner. Deleting a profile in use → confirm dialog states what reverts to Default.

### 5.7 Onboarding & macOS Permission Walkthrough

Runs on first launch (re-runnable via Settings → "Launch Feature Tour"). Full-window, 5 steps, progress dots, `Back / Continue`, skippable except permissions required for core function.

1. **Welcome** — hero render animates in (controller rotates to ¾ pose, lightbar sweep), one-line value prop, "Get started."
2. **Connect your controller** — two cards: *USB-C* ("just plug in — recommended for setup") and *Bluetooth* (illustrated: hold **Create + PS** until the lightbar pulses blue → macOS Bluetooth Settings deep-link button). Live detection: the moment the controller connects, the card flips to a success state showing the controller's actual body color and battery; a physical haptic double-tick fires on the controller ("it's alive" moment). Can't connect → "Troubleshoot" popover.
3. **Permissions** (the critical step — modeled on Logi's documented pain points, but automated):
   - Three permission rows, each with icon, plain-language *why*, status pill (Waiting / ✓ Granted), and a button:
     - **Input Monitoring** — "so we can read the controller." → `Open System Settings` (deep link `x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent`).
     - **Accessibility** — "so buttons can type keys, click, and scroll for you." → deep link to Accessibility pane.
     - **Bluetooth** — "so we can see your controller's battery when connected wirelessly." (auto-prompted; row confirms.)
   - The app polls grant status; each row flips to ✓ with a spring checkmark the instant the user toggles it in System Settings — no manual "check again."
   - Handles the macOS "Quit & Reopen" requirement gracefully: if macOS requires relaunch, show "Relaunching…" toast, auto-relaunch, and **resume the wizard at step 4** (state persisted).
   - Denied/stuck path: inline expandable "It's not working" with the uncheck-recheck fix and a link to a help page.
4. **Pick a starting point** — starter profile gallery (cards with mini-render previews); selecting one shows a 3-second animated preview of its key bindings (callouts flash in sequence). Default selection: "Couch & Media."
5. **Try it** — a sandbox screen: "Move the left stick — that's your pointer. Press ✕ — that's click." Live echo confirms each. Ends with pointers to the menu bar icon ("your quick switcher lives here" — arrow animates toward the actual menu bar location) and "Explore your controller" CTA → lands on the Controller page with a one-time coach-mark: "Click any label — or just press the button you want to change."

### 5.8 Menu-Bar Quick Switcher

Always-running lightweight presence (app window can be closed; engine lives in a login item/agent).
- **Icon:** controller glyph; subtle badge states — filled = engine on, hollow = paused, red dot = permission problem, lightning = charging.
- **Menu (custom view, not plain NSMenu):**
  - Header: controller name, battery ring + %, connection badge.
  - **Profile switcher:** radio list of profiles (active one checked, app-bound ones show app icon); "Pinned" toggle beside manual profiles.
  - `Pause DualSense Remap` (⌥-click icon = instant toggle).
  - `Show Virtual Keyboard`.
  - `Open DualSense Remap…` / `Quit`.
- Holding the **PS button** (default binding) opens this same switcher as a centered on-screen overlay (HUD) navigable with the d-pad — profile switching without touching the Mac.

### 5.9 Virtual Keyboard (sidebar section)

**Purpose:** text entry from the couch; also the config surface for it.
- **Overlay behavior (the actual keyboard):** summoned by a binding (default: hold touchpad click 600 ms) or menu bar; appears as a floating panel bottom-center above all windows; QWERTY layout + row of context keys (Esc, Tab, ⌘, arrows, emoji). Navigation modes: **Pointer mode** (right stick/gyro points, ✕ types), **Grid mode** (d-pad steps key-to-key, ✕ types, R1 space, L1 delete, △ shift). Typing echoes into the focused app via the Accessibility engine.
- **Sidebar page contents:** live preview of the keyboard; mode picker; size & opacity sliders; theme (follow system / dark); key-repeat settings; toggle "haptic tick per keypress"; *(Could)* swipe-typing toggle (trace with touchpad). A "Test here" text field lets users practice without leaving the app.

### 5.10 Hammerspoon (sidebar section)

**Purpose:** power-user escape hatch — instead of building a scripting engine, integrate with the de-facto macOS Lua automation tool.
- **Detection states:** Not installed → explainer card ("Automate anything…"), link to hammerspoon.org, `brew install --cask hammerspoon` copy-chip. Installed but IPC disabled → instructions card with the `hs.ipc` snippet to paste, "Verify" button. Connected → green status card.
- **Bindings list:** table of control → Hammerspoon target. Targets: call a named global Lua function (`spoonRemap.nextDesktop()`), or fire a URL event (`hammerspoon://event?name=…`). Adding a binding here is the same popover flow (§5.4) surfaced from the "Apps & Automation → Hammerspoon" category — this page is the roster + docs view.
- **Snippet library:** copyable starter recipes (window snapping, "type today's date", toggle dark mode, OBS scene switch) with one-click "Bind to…" that opens the control picker (mini render → click a hotspot).
- **Test console:** run the bound function now; show returned value/error inline.
- Trust & safety: first Hammerspoon/shell binding shows a one-time warning sheet ("runs code with your user privileges"); shell/Lua bindings display a ⚡ badge on their chips.

### 5.11 Settings
Cards, single scroll: **Permissions health** (three rows w/ status, re-request buttons — mirrors onboarding step 3); **Engine** (launch at login, pause shortcut, polling rate Auto/250 Hz/1 kHz, added-latency read-out); **Notifications** (low battery thresholds, profile-switch toasts); **Appearance** (system/light/dark, reduce motion, high-contrast callouts); **Backup** (auto-backup profiles locally, restore, export all as JSON, reset to defaults); **About** (version, acknowledgments, "Launch Feature Tour", diagnostics export).

### 5.12 States & Edge Cases
- **Controller disconnected:** render desaturates to wireframe + "Reconnect" card; bindings remain editable (staged).
- **Two controllers:** carousel on Controller page; engine follows "active" controller (last input wins, or manually pinned).
- **Permission revoked at runtime:** menu-bar red dot; in-app banner with one-click fix path; engine pauses key/mouse synthesis but keeps reading (whatever is still permitted).
- **Game/full-screen capture apps:** optional per-profile "standby in this app" toggle (so native game support isn't double-driven).
- **Drift detected** (stick reports off-center at rest for >5 s repeatedly): passive suggestion toast → opens calibration.
- **Nothing mapped to click while stick=Pointer:** warning chip on save (M17).

---

## 6. Design-Language Brief

### 6.1 Principles
1. **The controller is the hero.** One large, beautiful render per page; UI chrome recedes (quiet background, thin lines, generous whitespace).
2. **Direct manipulation over lists.** You configure the *thing*, on the thing. Lists exist only as secondary summaries.
3. **The hardware talks back.** Live echo, lightbar and haptic confirmations — the physical device is part of the UI.
4. **Calm confidence.** Motion is fluid but restrained; nothing bounces twice. Feels like a system utility, not a gamer app — no aggressive RGB aesthetics, even though we control an RGB lightbar.
5. **Native first.** SF Pro, SF Symbols, vibrancy materials, standard popover/sheet physics. It should feel like Apple could have shipped it — the way Options+ feels native on each platform without copying it.

### 6.2 Typography (SF Pro / system stack)
| Token | Face / size / weight | Usage |
|---|---|---|
| `type.hero` | SF Pro Display 28/34 Semibold | Greeting, onboarding headlines |
| `type.title` | SF Pro Display 20/25 Semibold | Page titles, popover titles |
| `type.heading` | SF Pro Text 15/20 Semibold | Card headers, category names |
| `type.body` | SF Pro Text 13/18 Regular | Default UI text |
| `type.label` | SF Pro Text 12/16 Medium | Hotspot chips, sidebar items |
| `type.caption` | SF Pro Text 11/14 Regular | Helper text, scope footers, badges |
| `type.mono` | SF Mono 12/16 Regular | Key captures, shell/Lua snippets, JSON |
Numerals: tabular in battery %, thresholds, sliders.

### 6.3 Spacing, Radius, Elevation
- 4-pt base grid. Tokens: `space.1=4 · 2=8 · 3=12 · 4=16 · 5=24 · 6=32 · 7=48`.
- Content max-width 960 pt, centered; card padding `space.5`; card gap `space.4`.
- Radius: `radius.s=6` (chips, capture fields), `radius.m=10` (cards, popovers), `radius.l=16` (hero cards, onboarding), `radius.full` (pills, battery ring).
- Elevation: `elev.0` flat card (1 px hairline border, no shadow); `elev.1` hover (y2 blur8 @8%); `elev.2` popover (y8 blur24 @18%); `elev.3` overlay/HUD (y16 blur48 @24%). Dark mode swaps shadow for brighter border + deeper backdrop.

### 6.4 Color Tokens (Light / Dark)
Brand accent is our own "Pulse Blue" — energetic but desk-appropriate; deliberately not Sony blue, not Logitech teal.

| Token | Light | Dark | Usage |
|---|---|---|---|
| `bg.canvas` | #F5F5F7 | #1C1C1E | Window background |
| `bg.card` | #FFFFFF | #2A2A2D | Cards, popovers |
| `bg.sidebar` | vibrancy material (light) | vibrancy material (dark) | Sidebar |
| `bg.inset` | #EFEFF1 | #232326 | Capture fields, test areas |
| `stroke.hairline` | #00000014 | #FFFFFF1A | Card borders, dividers |
| `text.primary` | #1D1D1F | #F5F5F7 | Primary text |
| `text.secondary` | #6E6E73 | #98989D | Secondary/helper |
| `text.tertiary` | #AEAEB2 | #636366 | Disabled, placeholders |
| `accent.primary` | #3D7BFF | #5C8DFF | Selection, primary buttons, active hotspot |
| `accent.tint` | #3D7BFF14 | #5C8DFF22 | Selected pills, hover fills |
| `accent.glow` | #3D7BFF66 | #5C8DFF80 | Live input echo glow, callout highlight |
| `callout.line` | #C8C8CC | #48484C | Idle callout lines |
| `state.success` | #2FA34F | #4CC168 | Granted permissions, connected |
| `state.warning` | #C77D0A | #E8A23D | Conflicts, low battery 20% |
| `state.danger` | #D64545 | #E4685F | Destructive, battery 10%, revoked permission |
| `badge.script` | #8E5BD9 | #A57CE8 | ⚡ shell/Lua binding badges |
| `render.plate` | radial #FAFAFC→#EDEDF0 | radial #2E2E31→#1C1C1E | Backdrop plate behind controller render |
Rules: accent reserved for interaction & selection only (never decorative); AA contrast minimum for all text tokens on their backgrounds; high-contrast setting swaps `callout.line` → `text.secondary` and thickens lines 1→1.5 pt.

### 6.5 Iconography & Render
- SF Symbols throughout (medium weight, hierarchical rendering).
- Custom glyph set for PlayStation controls (✕ ○ □ △, d-pad, sticks) drawn on the SF grid at 2 weights — *original artwork*, geometrically distinct from Sony's marketing assets; used in chips, lists, menu bar.
- Controller render: original 3D model, physically-based neutral studio lighting, rendered per body colorway; exported as a sprite sequence for the rotation between views (no heavyweight 3D runtime needed for v1).

### 6.6 Motion Principles
- **Durations:** micro (hover, echo) 120 ms · standard (popover, chip updates) 200 ms · view transitions (render rotate/zoom, panel slide) 320 ms · onboarding hero 600 ms. All obey Reduce Motion (crossfade fallback).
- **Easing:** standard `cubic-bezier(0.2, 0, 0, 1)`; springs (checkmarks, chip save) damping 0.8; never more than one overshoot.
- **Signature moments:**
  1. *Callout choreography:* on view switch, lines draw outward from the controller (140 ms each, 25 ms stagger), chips fade+rise 8 px — the page "presents" the hardware.
  2. *Hotspot zoom:* clicking a chip eases the render 15% toward that control while the popover scales from 0.96 at its anchor — clear spatial causality.
  3. *Live echo:* physical press → hotspot glow within one frame (this one is latency-critical: no easing on the way in, 250 ms fade out).
  4. *Permission ✓:* status pill flips with a spring checkmark the instant macOS grants — the payoff moment of onboarding.
  5. *Profile auto-switch:* menu-bar icon does a single subtle pulse; optional matching lightbar pulse on the physical controller — software and hardware animate together.
- **Never animate:** slider values, latency-sensitive test areas, text while typing.

---

## 7. Technical Notes & Non-Functional Requirements (for feasibility grounding)
- **Input:** IOKit/`IOHIDManager` (GameController.framework where sufficient; raw HID reports needed for touchpad multitouch, gyro at full rate, battery, and output reports for lightbar/haptics/mic-LED — DualSense HID report layout is well documented by the community).
- **Output synthesis:** `CGEvent` taps for keys/mouse/scroll (requires Accessibility); Input Monitoring for HID reads; Bluetooth permission for wireless battery/detection — exactly the three permissions in onboarding §5.7.
- **Architecture:** menu-bar agent (engine, login item) + main app UI (SwiftUI); XPC between them; profiles as versioned JSON on disk (export = same format).
- **Performance budgets:** added input latency <8 ms p95; idle CPU <1%; memory <150 MB with window open; engine RAM <40 MB window-closed.
- **Privacy:** local-first, zero telemetry by default (opt-in diagnostics); we read input *from the controller only* — never keyboard/mouse logging; state this plainly in onboarding.

## 8. Success Metrics (v1)
- Activation: ≥80% of installs complete permission grant (funnel per permission step); ≥70% fire their first custom binding within 10 min.
- Engagement: median ≥5 custom bindings by day 7; ≥40% of WAU using ≥1 per-app profile by day 30.
- Quality: crash-free sessions ≥99.5%; permission-related support tickets <5% of installs; input-latency p95 within budget on M1 baseline.
- Sentiment: App Store ≥4.6; qualitative target — reviews that mention "feels like Logi Options+ / feels native."

## 9. Open Questions & Risks
1. **macOS API drift:** each macOS release historically breaks permission flows (as Logitech's own support history shows) — budget a compatibility pass per release; keep the permission-health card accurate.
2. **Sony trademarks:** button glyphs/render must be original; legal review of naming ("DualSense Remap" describes compatibility — confirm nominative fair use; App Store vs direct+notarized distribution decision affects this).
3. **Haptics fidelity:** full voice-coil haptics over Bluetooth require audio-channel tricks (as on Windows); v1 ships rumble-compatible fallback only — validate that "confirm tick" works reliably over BT.
4. **Games double-input:** apps with native controller support receive both native input and our synthesized events — is per-profile "standby" (M-adjacent, currently §5.12) enough, or do we need automatic game detection for v1?
5. **Pricing:** freemium (free: remap + 1 profile; paid: per-app profiles, gyro, touchpad, macros — $19.99 one-time) vs paid-upfront. Recommend freemium to maximize the permission-funnel learning; validate willingness-to-pay against DSX (~$5–10) and Mac utility norms (~$20).

---

## Appendix — Research Sources
- [Logitech MX Master 4 Software Review: Deep Dive into Logi Options+ and the Actions Ring — DataHolic](https://dataholic.de/logitech-mx-master-4-software-review-a-deep-dive-into-logi-options-and-the-new-actions-ring/) (carousel, left-nav, 3D render hotspots, Add Application panel, settings/backup, Actions Ring)
- [Logi Options+ permissions on macOS — Logitech Support](https://support.logi.com/hc/en-us/articles/1500005514962-Logi-Options-permissions-on-macOS) and [How to enable Accessibility and Input Monitoring permissions — Logitech Support](https://support.logi.com/hc/en-us/articles/7248828454807-How-to-enable-Accessibility-and-Input-monitoring-permissions-for-Logitech-Options) (Input Monitoring / Accessibility / Bluetooth rationale, Quit & Reopen behavior)
- [What is Logi Options+? — UC Today](https://www.uctoday.com/devices-workspace-tech/what-is-logi-options-complete-device-customization/) (card-based layout, device tiles, per-app workflow)
- [OpenLogi — local-first Options+ alternative](https://github.com/AprilNEA/OpenLogi) and [OpenLogi quick tour](https://openlogi.org/en/docs/getting-started/quick-tour) (device carousel behavior)
- [ReControl — gamepad to mouse/keyboard remapper for macOS](https://recontrol.danneu.com/) (independent 4-direction stick mapping, eased mouse/scroll, smooth vs 8-way modes, deadzone/drift/curves, JSON import-export, current limitations)
- [Enjoyable — joystick and gamepad mapping for macOS](https://yukkurigames.com/enjoyable/) and [JoyMapperSilicon](https://github.com/qibinc/JoyMapperSilicon) (baseline macOS mapper capabilities)
- [DS4Windows official site](https://ds4windows.dev/) and [hbashton/DS4Windows](https://github.com/hbashton/DS4Windows) (gyro tilt/aim, lightbar battery display, adaptive-trigger config with start point/force, L2/R2 linked-vs-split, touchpad L/R clicks, macros, auto profile switching)
- [DSX on Steam](https://store.steampowered.com/app/1812620/DSX/) and [KitGuru: DSX — unlocking the full power of DualSense on PC](https://www.kitguru.net/desktop-pc/mustafa-mahmoud/kitguru-games-dsx-unlocking-the-full-power-of-dualsense-on-pc/) (LED, gyroscope, speaker, mic, touchpad customization, deadzones, per-game profiles, Edge/PSVR2 support)
- [NSEvent/xbox-controller-mapper](https://github.com/NSEvent/xbox-controller-mapper) (macOS community demand: touchpad, gyro, swipe typing, scripting/OBS integration)
- [Controller: DualSense — PCGamingWiki](https://www.pcgamingwiki.com/wiki/Controller:DualSense) (DualSense capability inventory)