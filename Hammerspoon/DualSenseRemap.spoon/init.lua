--- === DualSenseRemap ===
---
--- Companion Spoon for the DualSenseRemap macOS app.
---
--- The app fires URL events of the form:
---
---     hammerspoon://dsr?event=NAME&key=value
---
--- (the URL host `dsr` is the Hammerspoon URL-event name — no path is
--- allowed in `hammerspoon://` URLs). This Spoon binds that event and
--- dispatches `params.event` to a whitelisted action table, so a DualSense
--- button can drive window snapping, Spaces, media keys and any custom Lua
--- the user registers in `DualSenseRemap.userHooks`.
---
--- Install:
---
--- ```lua
--- -- ~/.hammerspoon/init.lua
--- require("hs.ipc")                 -- optional: enables the `hs` CLI
--- hs.loadSpoon("DualSenseRemap")
--- spoon.DualSenseRemap:start()
--- ```
---
--- Security note: `hammerspoon://` URLs can be opened by any local process.
--- Parameters are treated as untrusted strings — they only index the action
--- table below; arbitrary Lua never comes from the URL.
---
--- Download: shipped with the DualSenseRemap app (the app installs it into
--- `~/.hammerspoon/Spoons/` for you).

local obj = {}
obj.__index = obj

-- Metadata ------------------------------------------------------------------

obj.name = "DualSenseRemap"
obj.version = "1.0.0"
obj.author = "DualSenseRemap <ossama.benjemaa@gmail.com>"
obj.homepage = "https://github.com/dualsenseremap/dualSenseRemap"
obj.license = "MIT - https://opensource.org/licenses/MIT"

--- DualSenseRemap.snapDuration
--- Variable
--- Window animation duration (seconds) used by the window snapping actions.
--- Defaults to 0 (instant, controller-friendly). Set to e.g. 0.2 to animate.
obj.snapDuration = 0

--- DualSenseRemap.userHooks
--- Variable
--- Table of user-defined extension actions: `obj.userHooks["myAction"] =
--- function(params) ... end`. Trigger from the app with a Hammerspoon action
--- named `myAction` — unknown names fall through to this table, so custom
--- hooks need no changes to the Spoon itself.
obj.userHooks = {}

--- DualSenseRemap.logger
--- Variable
--- hs.logger instance for this Spoon. Set its level with
--- `spoon.DualSenseRemap.logger.setLogLevel("debug")`.
obj.logger = hs.logger.new("DualSenseRemap", "info")

-- Internal helpers ----------------------------------------------------------

-- Taps a media/system key (case-sensitive names from
-- hs.eventtap.event.newSystemKeyEvent: PLAY, NEXT, PREVIOUS, MUTE,
-- SOUND_UP, SOUND_DOWN, BRIGHTNESS_UP, BRIGHTNESS_DOWN, ...).
local function tapSystemKey(key)
  hs.eventtap.event.newSystemKeyEvent(key, true):post()
  hs.eventtap.event.newSystemKeyEvent(key, false):post()
end

-- Moves the focused window to a unit rect {x, y, w, h} of its screen.
local function snapFocusedWindow(unit, duration)
  local win = hs.window.focusedWindow()
  if win then
    win:moveToUnit(unit, duration)
  end
end

-- Toggles Launchpad. hs.spaces.toggleLaunchPad() is the documented API;
-- fall back to launching the Launchpad app if hs.spaces is unavailable.
local function toggleLaunchpad()
  local ok = pcall(function() hs.spaces.toggleLaunchPad() end)
  if not ok then
    hs.application.launchOrFocus("Launchpad")
  end
end

-- Action registry ------------------------------------------------------------

--- DualSenseRemap.actions
--- Variable
--- Whitelisted action table dispatched from the `dsr` URL event. Every
--- function receives the URL query parameters as a string table. The app's
--- mapping UI exposes these names in the « Hammerspoon » action category.
obj.actions = {
  -- System overlays -------------------------------------------------------

  -- Toggle Launchpad.
  launchpad = function() toggleLaunchpad() end,

  -- Toggle Mission Control.
  missionControl = function() hs.spaces.toggleMissionControl() end,

  -- Toggle Show Desktop.
  showDesktop = function() hs.spaces.toggleShowDesktop() end,

  -- Flip to the previous application (single synthesized Cmd+Tab).
  appSwitcher = function() hs.eventtap.keyStroke({"cmd"}, "tab") end,

  -- Launch or focus an app: params.bundle = bundle identifier
  -- (fallback params.app = application name on disk).
  focusApp = function(params)
    if params.bundle then
      hs.application.launchOrFocusByBundleID(params.bundle)
    elseif params.app then
      hs.application.launchOrFocus(params.app)
    end
  end,

  -- Window management -----------------------------------------------------

  -- Snap the focused window to the left half of its screen.
  windowLeft = function()
    snapFocusedWindow({ x = 0, y = 0, w = 0.5, h = 1 }, obj.snapDuration)
  end,

  -- Snap the focused window to the right half of its screen.
  windowRight = function()
    snapFocusedWindow({ x = 0.5, y = 0, w = 0.5, h = 1 }, obj.snapDuration)
  end,

  -- Maximize the focused window (not native full screen).
  windowMax = function()
    local win = hs.window.focusedWindow()
    if win then win:maximize(obj.snapDuration) end
  end,

  -- Center the focused window at half width/height of its screen.
  windowCenter = function()
    snapFocusedWindow({ x = 0.25, y = 0.25, w = 0.5, h = 0.5 }, obj.snapDuration)
  end,

  -- Media ------------------------------------------------------------------

  -- Play / pause the current media.
  mediaPlayPause = function() tapSystemKey("PLAY") end,

  -- Next track.
  mediaNext = function() tapSystemKey("NEXT") end,

  -- Previous track.
  mediaPrevious = function() tapSystemKey("PREVIOUS") end,

  -- Spaces -----------------------------------------------------------------

  -- Switch one Space to the left (default macOS shortcut Ctrl+Left).
  spaceLeft = function() hs.eventtap.keyStroke({"ctrl"}, "left") end,

  -- Switch one Space to the right (default macOS shortcut Ctrl+Right).
  spaceRight = function() hs.eventtap.keyStroke({"ctrl"}, "right") end,

  -- Text -------------------------------------------------------------------

  -- Type the clipboard contents as literal keystrokes (useful in apps or
  -- fields that block Cmd+V).
  typeClipboard = function()
    local contents = hs.pasteboard.getContents()
    if contents and #contents > 0 then
      hs.eventtap.keyStrokes(contents)
    end
  end,

  -- Maintenance ------------------------------------------------------------

  -- Reload the Hammerspoon configuration.
  reload = function() hs.reload() end,
}

-- Dispatch -------------------------------------------------------------------

--- DualSenseRemap:handle(eventName, params) -> boolean
--- Method
--- Dispatches an action by name — first through `DualSenseRemap.actions`,
--- then through `DualSenseRemap.userHooks`.
---
--- Parameters:
---  * eventName - The action name (string), i.e. the `event` URL parameter.
---  * params - Table of URL query parameters (strings), may be empty.
---
--- Returns:
---  * true when a handler existed (even if it raised — errors are logged),
---    false for unknown action names.
function obj:handle(eventName, params)
  if type(eventName) ~= "string" or eventName == "" then
    self.logger.w("received URL event without an 'event' parameter")
    return false
  end
  local fn = self.actions[eventName] or self.userHooks[eventName]
  if not fn then
    self.logger.w("unknown action: " .. eventName)
    return false
  end
  local ok, err = pcall(fn, params or {})
  if not ok then
    self.logger.e("action '" .. eventName .. "' failed: " .. tostring(err))
  end
  return true
end

-- Lifecycle ------------------------------------------------------------------

--- DualSenseRemap:init() -> self
--- Method
--- Spoon initializer (called automatically by `hs.loadSpoon`). No-op —
--- binding happens in `start()`.
---
--- Returns:
---  * The DualSenseRemap object
function obj:init()
  return self
end

--- DualSenseRemap:start() -> self
--- Method
--- Binds the `dsr` URL event so `hammerspoon://dsr?event=NAME` triggers
--- actions.
---
--- Returns:
---  * The DualSenseRemap object
function obj:start()
  hs.urlevent.bind("dsr", function(_, params)
    obj:handle(params and params.event, params)
  end)
  self.logger.i("DualSenseRemap started — listening on hammerspoon://dsr")
  return self
end

--- DualSenseRemap:stop() -> self
--- Method
--- Unbinds the `dsr` URL event.
---
--- Returns:
---  * The DualSenseRemap object
function obj:stop()
  hs.urlevent.bind("dsr", nil)
  self.logger.i("DualSenseRemap stopped")
  return self
end

-- Hotkeys --------------------------------------------------------------------

--- DualSenseRemap:bindHotkeys(mapping) -> self
--- Method
--- Binds keyboard hotkeys for this Spoon's actions.
---
--- Parameters:
---  * mapping - A table with keys from the list below mapped to hotkey
---    specs (`{mods, key}`), e.g.:
---    `spoon.DualSenseRemap:bindHotkeys({ toggleKeyboard = {{"cmd","alt"}, "k"} })`
---
--- Supported keys:
---  * toggleKeyboard - Show/hide the app's PS5-style virtual keyboard
---    (opens `dualsenseremap://keyboard/toggle` back into the app)
---  * every action name from `DualSenseRemap.actions` (launchpad,
---    missionControl, showDesktop, appSwitcher, windowLeft, windowRight,
---    windowMax, windowCenter, mediaPlayPause, mediaNext, mediaPrevious,
---    spaceLeft, spaceRight, typeClipboard, reload)
---
--- Returns:
---  * The DualSenseRemap object
function obj:bindHotkeys(mapping)
  local spec = {
    -- Round-trip into the DualSenseRemap app: toggle the virtual keyboard.
    toggleKeyboard = function()
      hs.urlevent.openURL("dualsenseremap://keyboard/toggle")
    end,
  }
  for actionName in pairs(self.actions) do
    spec[actionName] = function() obj:handle(actionName, {}) end
  end
  hs.spoons.bindHotkeysToSpec(spec, mapping)
  return self
end

return obj
