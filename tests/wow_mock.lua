-- A small stand-in for the World of Warcraft API, just enough to load ControllerCam and drive it from tests.
-- Run by tests/test_controllercam.py inside a Lua 5.1 interpreter (the game uses Lua 5.1).

local mock = {
    time = 1000,                 -- GetTime() / time() clock, moved by mock.advance()
    printed = {},                -- everything print() was called with
    timers = {},                 -- pending C_Timer.After callbacks
    frames = {},                 -- every frame created
    cvars = {},                  -- current CVar values (strings)
    defaults = {},               -- game default values
    protected = {},              -- CVars SetCVar refuses while in combat
    setLog = {},                 -- every successful SetCVar: { name, value }
    tempLog = {},                -- every SetTempCVar
    locale = "enUS",
    addons = {},                 -- loaded addons (for IsAddOnLoaded)
    state = {                    -- the player
        mounted = false, flying = false, swimming = false, combat = false, vehicle = false,
        resting = false, instance = nil, zoom = 10, gamepadUI = false,
    },
    opened = nil,                -- the settings category that was opened
    badEvents = {},              -- event names this "client" refuses to register
}

-- CVars that exist in the client, with their game defaults (the numbers are made up for the tests; the
-- addon must never depend on them being right).
local DEFAULTS = {
    cameraDistanceMaxZoomFactor = "1.9", GamePadCameraYawSpeed = "1", GamePadCameraPitchSpeed = "1",
    GamepadCameraFollowOnStick = "0", CameraFollowOnStick = "0",
    CameraFollowYawSpeed = "90", CameraFollowPitchSpeed = "90", CameraFollowGamepadAdjustDelay = "2",
    GamePadFaceMovementMaxAngle = "105", GamePadFaceMovementMaxAngleCombat = "180", GamePadTurnWithCamera = "0",
    GamePadFaceMovementMount = "0", GamePadFaceMovementSwimming = "0", GamePadFaceMovementFreeFlying = "0",
    test_cameraOverShoulder = "0", test_cameraDynamicPitch = "0",
    test_cameraHeadMovementStrength = "0", test_cameraHeadMovementStandingStrength = "0.3",
    test_cameraHeadMovementMovingStrength = "0.5", test_cameraHeadMovementRangeScale = "5",
    test_cameraTargetFocusEnemyEnable = "0", test_cameraTargetFocusEnemyStrengthYaw = "0.5",
    test_cameraTargetFocusEnemyStrengthPitch = "0.4", test_cameraTargetFocusInteractEnable = "0",
    test_cameraTargetFocusInteractStrengthYaw = "1", test_cameraTargetFocusInteractStrengthPitch = "0.75",
    cameraSmoothStyle = "0",
    CameraKeepCharacterCentered = "1", CameraReduceUnexpectedMovement = "1",
    InputDeviceInterfaceStyle = "0",
}
mock.knownCVars = {}
for k, v in pairs(DEFAULTS) do
    mock.defaults[k] = v
    mock.cvars[k] = v
    mock.knownCVars[k] = true
end

---------------------------------------------------------------------------
-- Frames: every method exists and does nothing, except the ones tests care about.
---------------------------------------------------------------------------
local function newFrame(name)
    local f = { __name = name, scripts = {}, events = {}, text = "", checked = false, value = 0, shown = true, enabled = true }
    local methods = {
        SetScript = function(self, k, fn) self.scripts[k] = fn end,
        GetScript = function(self, k) return self.scripts[k] end,
        RegisterEvent = function(self, e)
            if mock.badEvents[e] then error('Frame:RegisterEvent(): Unknown event: ' .. e) end
            self.events[e] = true
        end,
        UnregisterEvent = function(self, e) self.events[e] = nil end,
        SetText = function(self, t) self.text = t end,
        GetText = function(self) return self.text end,
        SetChecked = function(self, v) self.checked = v and true or false end,
        GetChecked = function(self) return self.checked end,
        SetValue = function(self, v) self.value = v end,
        GetValue = function(self) return self.value end,
        Show = function(self) self.shown = true end,
        Hide = function(self) self.shown = false end,
        IsShown = function(self) return self.shown end,
        SetEnabled = function(self, v) self.enabled = v end,
        GetStringWidth = function() return 80 end,
        GetFontString = function(self) return newFrame() end,
        CreateFontString = function() return newFrame() end,
        CreateTexture = function() return newFrame() end,
        SetWidth = function(self, w) self.width = w end,
        GetWidth = function(self) return self.width or 100 end,
    }
    local mt = {}
    mt.__index = function(t, k)
        if methods[k] then return methods[k] end
        if type(k) == "string" and k:match("^[A-Z]") and k ~= "Text" then
            return function(self) return self end
        end
    end
    setmetatable(f, mt)
    if name then _G[name] = f end
    mock.frames[#mock.frames + 1] = f
    return f
end

function CreateFrame(kind, name, parent, template)
    local f = newFrame(name)
    f.kind, f.template = kind, template
    if template == "UICheckButtonTemplate" then f.Text = newFrame() end
    if name and template == "OptionsSliderTemplate" then
        _G[name .. "Text"], _G[name .. "Low"], _G[name .. "High"] = newFrame(), newFrame(), newFrame()
    end
    return f
end

-- Send an event to every frame registered for it, like the game does.
function mock.fire(event, ...)
    for _, f in ipairs(mock.frames) do
        if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
    end
end

UIParent = newFrame("UIParent")
GameTooltip = newFrame("GameTooltip")

---------------------------------------------------------------------------
-- Time and timers
---------------------------------------------------------------------------
function GetTime() return mock.time end
function time() return math.floor(mock.time) end
function GetLocale() return mock.locale end

C_Timer = {}
function C_Timer.After(sec, fn)
    mock.timers[#mock.timers + 1] = { at = mock.time + sec, fn = fn }
end

-- Move the clock forward, running timers that come due (in order). Timers may schedule more timers.
function mock.advance(sec)
    local target = mock.time + sec
    while true do
        local best, idx
        for i, t in ipairs(mock.timers) do
            if t.at <= target and (not best or t.at < best.at) then best, idx = t, i end
        end
        if not best then break end
        table.remove(mock.timers, idx)
        if best.at > mock.time then mock.time = best.at end
        best.fn()
    end
    mock.time = target
end

---------------------------------------------------------------------------
-- CVars
---------------------------------------------------------------------------
function GetCVar(name) return mock.cvars[name] end
function GetCVarDefault(name) return mock.defaults[name] end
function SetCVar(name, value)
    if not mock.knownCVars[name] then return false end
    if mock.state.combat and mock.protected[name] then return false end
    mock.cvars[name] = tostring(value)
    mock.setLog[#mock.setLog + 1] = { name, tostring(value) }
    return true
end
C_CVar = {
    SetTempCVar = function(name, value)
        mock.tempLog[#mock.tempLog + 1] = { name, tostring(value) }
        mock.cvars[name] = tostring(value)     -- a temp value shadows the stored one: GetCVar returns it
    end,
}

function hooksecurefunc(a, b, c)
    local tbl, name, fn = _G, a, b
    if type(a) == "table" then tbl, name, fn = a, b, c end
    local orig = tbl[name]
    tbl[name] = function(...)
        local r = { orig(...) }
        fn(...)
        return unpack(r)
    end
end

---------------------------------------------------------------------------
-- The player
---------------------------------------------------------------------------
function IsMounted() return mock.state.mounted end
function IsFlying() return mock.state.flying end
function IsSwimming() return mock.state.swimming end
function UnitAffectingCombat() return mock.state.combat end
function InCombatLockdown() return mock.state.combat end
function UnitInVehicle() return mock.state.vehicle end
function UnitHasVehicleUI() return mock.state.vehicle end
function IsResting() return mock.state.resting end
function IsInInstance()
    if mock.state.instance then return true, mock.state.instance end
    return false, "none"
end
function GetCameraZoom() return mock.state.zoom end
function CameraZoomIn(d) mock.state.zoom = mock.state.zoom - d end
function CameraZoomOut(d) mock.state.zoom = mock.state.zoom + d end

Enum = { InputDeviceInterfaceType = { Mouse = 0, Gamepad = 1 } }
C_InputInterfaceStyle = {
    GetCurrentStyle = function()
        return mock.state.gamepadUI and Enum.InputDeviceInterfaceType.Gamepad or Enum.InputDeviceInterfaceType.Mouse
    end,
}

function IsAddOnLoaded(name) return mock.addons[name] and true or false end

---------------------------------------------------------------------------
-- Misc globals the addon touches
---------------------------------------------------------------------------
function print(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
    mock.printed[#mock.printed + 1] = table.concat(parts, " ")
end
SlashCmdList = {}
Settings = {
    RegisterCanvasLayoutCategory = function(panel, name)
        local c = { panel = panel, name = name, GetID = function() return 42 end }
        mock.category = c
        return c
    end,
    RegisterCanvasLayoutSubcategory = function(cat, panel, name)
        mock.subcategory = { panel = panel, name = name }
        return mock.subcategory
    end,
    RegisterAddOnCategory = function() end,
    OpenToCategory = function(id) mock.opened = id end,
}

-- Plain serializer so a test can "reload the UI": dump the saved variables, start a new interpreter, load them.
function mock.serialize(v)
    if type(v) == "table" then
        local keys = {}
        for k in pairs(v) do keys[#keys + 1] = k end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        local out = {}
        for _, k in ipairs(keys) do
            out[#out + 1] = "[" .. mock.serialize(k) .. "]=" .. mock.serialize(v[k])
        end
        return "{" .. table.concat(out, ",") .. "}"
    elseif type(v) == "string" then
        return string.format("%q", v)
    else
        return tostring(v)
    end
end

-- Run one addon file the way the game does: the chunk gets the addon name and the shared namespace table.
function mock.loadFile(path, ns)
    local fn, err = loadfile(path)
    if not fn then error(err) end
    return fn("ControllerCam", ns)
end

return mock
