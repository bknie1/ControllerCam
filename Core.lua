-- ControllerCam core: saved data, situations, applying profiles to the camera.
--
-- Everything that has to survive a UI reload lives in ControllerCamDB (switching the Gamepad UI on or off
-- reloads the UI, which wipes anything kept only in memory): the profiles, which profile each situation uses,
-- the camera settings you had before ControllerCam touched them, and the motion-sickness settings it had to
-- switch off. Timers (the delay before leaving a situation) are memory only on purpose: after a reload the
-- situation is simply worked out again.

local ADDON, ns = ...
local L = ns.L

local SITUATIONS = { "vehicle", "flying", "swimming", "mounted", "combat", "raid", "dungeon", "city", "default" }
ns.SITUATIONS = SITUATIONS    -- highest priority first

ns.SITUATION_LABEL = {
    vehicle  = L["In a vehicle"],
    flying   = L["Flying"],
    swimming = L["Swimming"],
    mounted  = L["Mounted"],
    combat   = L["In combat"],
    raid     = L["In a raid"],
    dungeon  = L["In a dungeon"],
    city     = L["In a city or inn"],
    default  = L["Everywhere else (default)"],
}

local DEFAULT_EXIT_DELAY = 1.5
local TICK = 0.5
local BASE_ZOOM = 15          -- yards at cameraDistanceMaxZoomFactor 1
local CONFLICTS = { "DynamicCam" }

local db
local active = {}             -- { sit = situation id, id = profile id } currently applied
local lastMatch = {}          -- situation -> GetTime() it last matched (for the exit delay)
local retryAfterCombat = false
local curve                   -- the shoulder curve of the active profile, if any
local curveFlip, lastCurveValue = false, nil
local debugOn = false
local fresh = false           -- first run ever (no saved data)
local firstApply = true       -- the first apply after a load keeps your zoom, unless this is a fresh install

local PREFIX = "|cff66ccffControllerCam:|r "
function ns.Say(msg) print(PREFIX .. msg) end
local function dbg(msg) if debugOn then print("|cff999999ControllerCam debug:|r " .. msg) end end
function ns.SetDebug(v) debugOn = v and true or false end
function ns.IsDebug() return debugOn end

local function G(name, ...)   -- call a global API function if this client has it
    local f = _G[name]
    if type(f) == "function" then return f(...) end
end

local function copy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = copy(x) end
    return t
end
ns.Copy = copy

---------------------------------------------------------------------------
-- Profiles
---------------------------------------------------------------------------
function ns.GetProfile(id)
    if type(id) ~= "string" then return nil end
    return (db and db.profiles[id]) or ns.BUILTIN[id]
end

function ns.IsBuiltin(id) return ns.BUILTIN[id] ~= nil end

function ns.ProfileName(id)
    local b = ns.BUILTIN[id]
    if b then return L[b.name] end
    local p = db and db.profiles[id]
    return p and p.name or tostring(id)
end

function ns.ProfileDescription(id)
    local b = ns.BUILTIN[id]
    if b then return L[b.desc] end
    return L["Custom profile. Duplicate or edit it in the profile editor."]
end

-- All profile ids: built-in ones in their menu order, then custom ones by name.
function ns.ProfileIds()
    local ids = {}
    for _, b in ipairs(ns.BUILTIN_LIST) do ids[#ids + 1] = b.id end
    local custom = {}
    for id in pairs(db.profiles) do custom[#custom + 1] = id end
    table.sort(custom, function(a, b) return db.profiles[a].name:lower() < db.profiles[b].name:lower() end)
    for _, id in ipairs(custom) do ids[#ids + 1] = id end
    return ids
end

local function NameTaken(name)
    local low = name:lower()
    for _, b in ipairs(ns.BUILTIN_LIST) do
        if L[b.name]:lower() == low or b.name:lower() == low then return true end
    end
    for _, p in pairs(db.profiles) do
        if p.name:lower() == low then return true end
    end
    return false
end

local function UniqueName(name)
    name = ns.CleanName(name) or L["My profile"]
    if not NameTaken(name) then return name end
    local base = name:sub(1, ns.MAX_NAME_LENGTH - 4)
    for i = 2, 99 do
        local try = ("%s (%d)"):format(base, i)
        if not NameTaken(try) then return try end
    end
    return name
end

local function NewId(name)
    local slug = name:lower():gsub("[^%w]+", "_"):gsub("^_", ""):gsub("_$", "")
    if slug == "" then slug = "profile" end
    local id = "u_" .. slug
    local n = 1
    while db.profiles[id] or ns.BUILTIN[id] do
        n = n + 1
        id = ("u_%s_%d"):format(slug, n)
    end
    return id
end

-- Find a profile from what the user typed: id, exact name, or unambiguous start of a name.
function ns.FindProfile(token)
    if type(token) ~= "string" or token == "" then return nil end
    local low = token:lower()
    local ids = ns.ProfileIds()
    for _, id in ipairs(ids) do
        if id:lower() == low or ns.ProfileName(id):lower() == low then return id end
    end
    local found
    for _, id in ipairs(ids) do
        if ns.ProfileName(id):lower():sub(1, #low) == low or id:lower():sub(1, #low) == low then
            if found then return nil, "ambiguous" end
            found = id
        end
    end
    return found
end

-- Create a custom profile from already valid values. Returns the new id.
function ns.CreateProfile(name, values)
    local clean, why = ns.ValidateProfile({ name = UniqueName(name), values = copy(values or {}) })
    if not clean then return nil, why end
    local id = NewId(clean.name)
    db.profiles[id] = clean
    return id
end

function ns.DuplicateProfile(srcId, newName)
    local src = ns.GetProfile(srcId)
    if not src then return nil end
    return ns.CreateProfile(newName or (ns.ProfileName(srcId) .. " " .. L["copy"]), src.values)
end

function ns.DeleteProfile(id)
    if not db.profiles[id] then return false end
    db.profiles[id] = nil
    for sit, pid in pairs(db.assign) do
        if pid == id then db.assign[sit] = nil end
    end
    if db.force == id then db.force = nil end
    ns.Evaluate(true)
    return true
end

-- Set (or with nil, remove = back to the game default) one value of a custom profile.
function ns.SetValue(id, key, value)
    local p = db.profiles[id]
    if not p then return false, "builtin" end
    local s = ns.SETTING_BY_KEY[key]
    if not s then return false, "unknown" end
    if value == nil then
        p.values[key] = nil
    else
        local clean, why = ns.ValidateValue(s, value)
        if clean == nil then return false, why end
        p.values[key] = clean
        if key == "shoulder" then p.values.shoulderCurve = nil end       -- a fixed offset replaces the curve
        if key == "shoulderCurve" then p.values.shoulder = nil end
    end
    if active.id == id then ns.Evaluate(true) end
    return true
end

-- Import a profile string. Returns the new profile id, or nil and a localized message.
function ns.ImportString(str)
    local parsed, err = ns.ParseProfile(str)
    if not parsed then return nil, err end
    return ns.CreateProfile(parsed.name, parsed.values)
end

function ns.ExportById(id)
    local p = ns.GetProfile(id)
    if not p then return nil end
    return ns.ExportProfile({ name = ns.ProfileName(id), values = p.values })
end

-- Make a custom profile from the camera settings you have right now.
function ns.CaptureCurrent(name)
    local values = {}
    for _, s in ipairs(ns.SETTINGS) do
        if s.api then
            local z = tonumber(G("GetCameraZoom"))
            if z then values[s.key] = ns.Round(math.min(math.max(z, s.min), s.max), 1) end
        elseif s.kind ~= "curve" then
            local cur = tonumber(GetCVar(s.cvars[1]))
            if cur then
                if s.kind == "mul" then
                    local d = tonumber(GetCVarDefault(s.cvars[1]))
                    if d and d ~= 0 then
                        local ratio = ns.Round(cur / d, 2)
                        if ratio >= s.min and ratio <= s.max then values[s.key] = "x" .. ns.FormatNumber(ratio) end
                    end
                else
                    local clean = ns.ValidateValue(s, cur)
                    if clean ~= nil then values[s.key] = clean end
                end
            end
        end
    end
    return ns.CreateProfile(name, values)
end

---------------------------------------------------------------------------
-- Situations
---------------------------------------------------------------------------
local function InstanceType()
    local inInstance, t = G("IsInInstance")
    if inInstance then return t end
end

local MATCH = {
    vehicle  = function() return G("UnitInVehicle", "player") or G("UnitHasVehicleUI", "player") end,
    flying   = function() return G("IsFlying") end,
    swimming = function() return G("IsSwimming") end,
    mounted  = function() return G("IsMounted") end,
    combat   = function() return G("UnitAffectingCombat", "player") or G("InCombatLockdown") end,
    raid     = function() return InstanceType() == "raid" end,
    dungeon  = function() local t = InstanceType(); return t == "party" or t == "scenario" end,
    city     = function() return G("IsResting") and not InstanceType() end,
    default  = function() return true end,
}

local function Matches(sit)
    local ok, res = pcall(MATCH[sit])
    return ok and res and true or false
end

local function Profile(id) return id and ns.GetProfile(id) end

-- Returns the situation and profile id that should be in effect now, or nil if nothing is assigned.
function ns.ResolveSituation()
    if db.force and Profile(db.force) then return "force", db.force end
    local now = GetTime()
    local delay = db.exitDelay
    for _, sit in ipairs(SITUATIONS) do
        local id = db.assign[sit]
        if id and Profile(id) then
            local hit = Matches(sit)
            if hit then
                lastMatch[sit] = now
            elseif sit ~= "default" and active.sit == sit and delay > 0
                and lastMatch[sit] and now - lastMatch[sit] < delay then
                hit = true                        -- keep the old situation for a moment (no flicker)
            end
            if hit then return sit, id end
        end
    end
end

---------------------------------------------------------------------------
-- Applying a profile
---------------------------------------------------------------------------
local function SameValue(a, b)
    local x, y = tonumber(a), tonumber(b)
    if x and y then return math.abs(x - y) < 0.0001 end
    return tostring(a) == tostring(b)
end

local function SetOne(cvar, value)
    local cur = GetCVar(cvar)
    if cur == nil then return end                 -- this client does not have that CVar
    if SameValue(cur, value) then return true end
    if db.originals[cvar] == nil then db.originals[cvar] = tostring(cur) end
    local ok, res = pcall(SetCVar, cvar, value)
    if not ok or res == false then
        retryAfterCombat = true                   -- the game refuses some CVars during combat
        dbg(("could not set %s = %s now, will retry after combat"):format(cvar, tostring(value)))
        return false
    end
    dbg(("%s = %s"):format(cvar, tostring(value)))
    return true
end

local function MaxZoom(desired)
    local f = tonumber(desired.cameraDistanceMaxZoomFactor) or tonumber(GetCVar("cameraDistanceMaxZoomFactor"))
    if f then return f * BASE_ZOOM end
end

local function SetZoom(target, desired)
    local max = MaxZoom(desired)
    if max and target > max then target = max end
    local cur = tonumber(G("GetCameraZoom"))
    if not cur then return end
    local diff = target - cur
    if math.abs(diff) < 0.1 then return end
    if diff > 0 then G("CameraZoomOut", diff) else G("CameraZoomIn", -diff) end
end

-- Compute what a profile wants: { cvar = "value" }, zoom, curve, whether it uses ActionCam features.
local function Resolve(profile, withZoom)
    local values = profile.values
    local flip = db.flipShoulder
    local desired = {}
    local zoom = tonumber(values.zoom)
    local theCurve = values.shoulderCurve
    local needsMotion = false

    for _, s in ipairs(ns.SETTINGS) do
        if s.api then
            -- applied separately
        elseif s.kind == "curve" then
            if theCurve then
                local z = (withZoom and zoom) or tonumber(G("GetCameraZoom")) or zoom or 0
                local n = ns.EvalCurve(theCurve, z)
                desired.test_cameraOverShoulder = ns.FormatNumber(flip and -n or n)
                for _, p in ipairs(theCurve) do if p[2] ~= 0 then needsMotion = true end end
            end
        elseif not (s.key == "shoulder" and theCurve) then
            for _, cvar in ipairs(s.cvars) do
                local v = ns.ResolveCVar(s, values[s.key], cvar, flip)
                if v ~= nil then
                    desired[cvar] = v
                    if s.actionCam then
                        local n = tonumber(v)
                        if n and n ~= 0 then needsMotion = true end
                    end
                end
            end
        end
    end
    return desired, zoom, theCurve, needsMotion
end

---------------------------------------------------------------------------
-- Motion-sickness settings
-- The shoulder offset, dynamic pitch, target focus and head tracking only work while the game's two
-- motion-sickness CVars are off. In the Gamepad UI the game forces its own temporary values for them, so
-- there we override the temporary value instead of the stored one.
---------------------------------------------------------------------------
local tempSaved = {}          -- cvar -> the game's temporary value, while we override it (memory only: the game resets it on reload)
local settingTemp = false

function ns.IsGamepadUI()
    if C_InputInterfaceStyle and C_InputInterfaceStyle.GetCurrentStyle and Enum and Enum.InputDeviceInterfaceType then
        return C_InputInterfaceStyle.GetCurrentStyle() == Enum.InputDeviceInterfaceType.Gamepad
    end
    return GetCVar("InputDeviceInterfaceStyle") == "1"
end

local function EnforceMotion(need)
    local useTemp = ns.IsGamepadUI() and C_CVar and C_CVar.SetTempCVar
    for _, cvar in ipairs(ns.MOTION_CVARS) do
        local cur = GetCVar(cvar)
        if cur ~= nil then
            if need then
                if cur ~= "0" then
                    if useTemp then
                        if tempSaved[cvar] == nil then tempSaved[cvar] = cur end
                        settingTemp = true
                        pcall(C_CVar.SetTempCVar, cvar, "0")
                        settingTemp = false
                    else
                        if db.motion[cvar] == nil then db.motion[cvar] = tostring(cur) end   -- saved: survives a reload
                        pcall(SetCVar, cvar, "0")
                    end
                    dbg(cvar .. " switched off for the camera features")
                end
            else
                if tempSaved[cvar] ~= nil and useTemp then
                    settingTemp = true
                    pcall(C_CVar.SetTempCVar, cvar, tempSaved[cvar])
                    settingTemp = false
                end
                tempSaved[cvar] = nil
                if db.motion[cvar] ~= nil then
                    pcall(SetCVar, cvar, db.motion[cvar])
                    db.motion[cvar] = nil
                end
            end
        end
    end
end

local function Apply(id, withZoom)
    local profile = Profile(id)
    if not profile then return end
    local desired, zoom, theCurve, needsMotion = Resolve(profile, withZoom)

    EnforceMotion(needsMotion)            -- first: the offset and friends are ignored while these are on
    for cvar, value in pairs(desired) do SetOne(cvar, value) end
    if withZoom and zoom then SetZoom(zoom, desired) end

    curve, curveFlip, lastCurveValue = theCurve, db.flipShoulder, tonumber(desired.test_cameraOverShoulder)
    dbg(("profile '%s' applied"):format(ns.ProfileName(id)))
end

-- Called often: only does something when the situation or the profile changes (or force is set).
function ns.Evaluate(force)
    if not db or not db.enabled then return end
    local sit, id = ns.ResolveSituation()
    if not id then return end
    local changed = (active.id ~= id) or (active.sit ~= sit)
    if not changed and not force then return end
    active.sit, active.id = sit, id
    -- The camera distance only moves when the profile in effect changes (not on edits, and not when the UI
    -- reloads, which would otherwise reset your zoom every time the Gamepad UI is switched).
    local zoomIt = changed and not (firstApply and not fresh)
    firstApply = false
    Apply(id, zoomIt)
    if retryAfterCombat and not (G("InCombatLockdown")) then
        retryAfterCombat = false
        Apply(id, false)
    end
end

-- Follows the zoom level to move the shoulder offset along the profile's curve.
function ns.CurveTick()
    if not (db and db.enabled and curve) then return end
    local z = tonumber(G("GetCameraZoom"))
    if not z then return end
    local v = ns.EvalCurve(curve, z)
    if curveFlip then v = -v end
    if lastCurveValue and math.abs(v - lastCurveValue) < 0.02 then return end
    local ok, res = pcall(SetCVar, "test_cameraOverShoulder", ns.FormatNumber(v))
    if ok and res ~= false then lastCurveValue = v end
end

---------------------------------------------------------------------------
-- Settings changes made by the options panel and the slash commands
---------------------------------------------------------------------------
function ns.Assign(sit, id)
    if not ns.SITUATION_LABEL[sit] then return false end
    if id ~= nil and not ns.GetProfile(id) then return false end
    db.assign[sit] = id
    ns.Evaluate(true)
    return true
end

function ns.Force(id)
    if id ~= nil and not ns.GetProfile(id) then return false end
    db.force = id
    ns.Evaluate(true)
    return true
end

-- Use one profile everywhere (clears the per-situation choices).
function ns.UseEverywhere(id)
    if not ns.GetProfile(id) then return false end
    db.assign = { default = id }
    db.force = nil
    ns.Evaluate(true)
    return true
end

function ns.ApplyStarter()
    db.assign = copy(ns.STARTER)
    db.force = nil
    ns.Evaluate(true)
end

function ns.SetEnabled(v)
    db.enabled = v and true or false
    if db.enabled then
        ns.Evaluate(true)
    else
        ns.Restore()
    end
end

function ns.SetExitDelay(n)
    db.exitDelay = math.min(math.max(tonumber(n) or DEFAULT_EXIT_DELAY, 0), 10)
end

function ns.SetFlipShoulder(v)
    db.flipShoulder = v and true or false
    ns.Evaluate(true)
end

-- Put back the camera settings you had before ControllerCam changed them.
function ns.Restore()
    for cvar, value in pairs(db.originals) do pcall(SetCVar, cvar, value) end
    db.originals = {}
    EnforceMotion(false)
    curve, active = nil, {}
end

function ns.Status()
    return {
        enabled = db.enabled, sit = active.sit, id = active.id,
        profile = active.id and ns.ProfileName(active.id) or nil,
        force = db.force,
    }
end

function ns.GetDB() return db end

---------------------------------------------------------------------------
-- Saved data
---------------------------------------------------------------------------
local function KnownCVars()
    local set = {}
    for _, s in ipairs(ns.SETTINGS) do
        for _, c in ipairs(s.cvars or {}) do set[c] = true end
    end
    return set
end

local function InitDB()
    local old = ControllerCamDB
    local fresh = type(old) ~= "table" or old.v == nil
    if type(old) ~= "table" then old = {} end

    local d = {
        v = 1,
        enabled = old.enabled ~= false,
        exitDelay = math.min(math.max(tonumber(old.exitDelay) or DEFAULT_EXIT_DELAY, 0), 10),
        flipShoulder = old.flipShoulder == true,
        welcomed = old.welcomed == true,
        profiles = {}, assign = {}, originals = {}, motion = {},
    }
    -- Anything in the saved file is checked the same way as an imported string.
    if type(old.profiles) == "table" then
        for id, p in pairs(old.profiles) do
            if type(id) == "string" and not ns.BUILTIN[id] then
                local clean = ns.ValidateProfile(p)
                if clean then d.profiles[id] = clean end
            end
        end
    end
    db = d
    if fresh then
        d.assign = copy(ns.STARTER)               -- out of the box: the Action camera
    elseif type(old.assign) == "table" then
        for _, sit in ipairs(SITUATIONS) do
            local id = old.assign[sit]
            if id and ns.GetProfile(id) then d.assign[sit] = id end
        end
    end
    if type(old.force) == "string" and ns.GetProfile(old.force) then d.force = old.force end
    local known = KnownCVars()
    if type(old.originals) == "table" then
        for cvar, val in pairs(old.originals) do
            if known[cvar] and type(val) == "string" then d.originals[cvar] = val end
        end
    end
    if type(old.motion) == "table" then
        for _, cvar in ipairs(ns.MOTION_CVARS) do
            if type(old.motion[cvar]) == "string" then d.motion[cvar] = old.motion[cvar] end
        end
    end
    ControllerCamDB = d
    ns.db = d
    return fresh
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local f = CreateFrame("Frame", "ControllerCamFrame", UIParent)
ns.frame = f

local EVENTS = {
    "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    "PLAYER_MOUNT_DISPLAY_CHANGED", "PLAYER_UPDATE_RESTING", "ZONE_CHANGED_NEW_AREA",
    "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE", "UPDATE_SHAPESHIFT_FORM",
}
for _, e in ipairs(EVENTS) do pcall(f.RegisterEvent, f, e) end    -- a missing event must not break the addon

local function ScheduleTick()
    C_Timer.After(TICK, function()
        ns.Evaluate()
        ScheduleTick()
    end)
end

local function IsAddOnLoaded_(name)
    local fn = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    return fn and fn(name)
end

local function Welcome(fresh)
    for _, name in ipairs(CONFLICTS) do
        if IsAddOnLoaded_(name) then
            ns.Say((L["%s is also loaded. Both change the camera and will fight each other. Disable one of them."]):format(name))
        end
    end
    if fresh and not db.welcomed then
        db.welcomed = true
        ns.Say(L["Installed. The Action camera is on. Try /ccam use hybrid or /ccam use classic, /ccam help lists everything."])
    end
end

f:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end
        fresh = InitDB()
        if ns.OnDBReady then ns.OnDBReady() end
    elseif not db then
        return
    elseif event == "PLAYER_LOGIN" then
        ScheduleTick()
        C_Timer.After(3, function() Welcome(fresh) end)
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- The game sets up its own camera values while loading; apply ours a moment later.
        C_Timer.After(1, function() ns.Evaluate(true) end)
    elseif event == "PLAYER_REGEN_ENABLED" then
        ns.Evaluate(retryAfterCombat)
    elseif event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE" then
        if arg1 == "player" then ns.Evaluate() end
    else
        ns.Evaluate()
    end
end)

local acc = 0
f:SetScript("OnUpdate", function(_, elapsed)
    if not curve then return end
    acc = acc + elapsed
    if acc < 0.1 then return end
    acc = 0
    ns.CurveTick()
end)

-- The game may set its own temporary motion-sickness values later (the Gamepad UI does when it starts).
if C_CVar and C_CVar.SetTempCVar and hooksecurefunc then
    hooksecurefunc(C_CVar, "SetTempCVar", function(cvar)
        if settingTemp or not db or not db.enabled then return end
        for _, c in ipairs(ns.MOTION_CVARS) do
            if c == cvar then
                tempSaved[cvar] = nil
                C_Timer.After(0, function() ns.Evaluate(true) end)
            end
        end
    end)
end
