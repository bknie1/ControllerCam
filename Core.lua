-- ControllerCam core: saved data, situations, applying profiles to the camera.
--
-- Everything that has to survive a UI reload lives in ControllerCamDB (switching the Gamepad UI on or off
-- reloads the UI, which wipes anything kept only in memory): the profiles, which profile each situation uses,
-- the camera settings you had before ControllerCam touched them, and the motion-sickness settings it had to
-- switch off. Timers (the delay before leaving a situation) are memory only on purpose: after a reload the
-- situation is simply worked out again.

local ADDON, ns = ...
local L = ns.L

local SITUATIONS = { "vehicle", "flying", "swimming", "mounted", "combat", "fishing", "raid", "dungeon", "indoors",
                     "city", "default" }
ns.SITUATIONS = SITUATIONS    -- highest priority first

ns.SITUATION_LABEL = {
    vehicle  = L["In a vehicle"],
    flying   = L["Flying"],
    swimming = L["Swimming"],
    mounted  = L["Mounted"],
    combat   = L["In combat"],
    fishing  = L["Fishing"],
    raid     = L["In a raid"],
    dungeon  = L["In a dungeon"],
    indoors  = L["Indoors"],
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
local follow = {}             -- the active profile's "by zoom" values: { cvar, at = function(zoom), last }
local held = false            -- a scene of the HUD's has the camera (ControllerCam.Hold)
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
-- A built-in profile you edited (advanced editing) comes back with your values; the originals in ns.BUILTIN
-- are never changed, so "reset to original" always has something to go back to.
function ns.GetProfile(id)
    if type(id) ~= "string" then return nil end
    local custom = db and db.profiles[id]
    if custom then return custom end
    local b = ns.BUILTIN[id]
    if b and db and db.overrides[id] then
        return { id = b.id, name = b.name, desc = b.desc, values = db.overrides[id] }
    end
    return b
end

function ns.IsBuiltin(id) return ns.BUILTIN[id] ~= nil end
function ns.IsEdited(id) return db ~= nil and db.overrides[id] ~= nil end
-- Custom profiles can always be edited; built-in ones only while advanced editing is on.
function ns.IsEditable(id) return db ~= nil and (db.profiles[id] ~= nil or (ns.BUILTIN[id] ~= nil and db.advanced)) end

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

-- What a profile is and what it changes: name, description and one { label, value } row per setting it lists.
function ns.DescribeProfile(id)
    local p = ns.GetProfile(id)
    if not p then return nil end
    local rows = {}
    for _, s in ipairs(ns.SETTINGS) do
        local v = p.values[s.key]
        if v ~= nil then rows[#rows + 1] = { L[s.label], ns.FormatSettingValue(s, v) } end
    end
    return ns.ProfileName(id), ns.ProfileDescription(id), rows
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

-- The values table to edit for a profile: a custom profile's own, or (advanced editing) a copy of a built-in
-- one that is made the first time it is edited. Returns nil and a reason when it cannot be edited.
local function EditableValues(id)
    if db.profiles[id] then return db.profiles[id].values end
    if ns.BUILTIN[id] then
        if not db.advanced then return nil, "builtin" end
        if not db.overrides[id] then db.overrides[id] = copy(ns.BUILTIN[id].values) end
        return db.overrides[id]
    end
    return nil, "unknown"
end

-- Set (or with nil, remove = back to the game default) one value of an editable profile.
function ns.SetValue(id, key, value)
    local s = ns.SETTING_BY_KEY[key]
    if not s then return false, "unknown" end
    local clean
    if value ~= nil then
        local why
        clean, why = ns.ValidateValue(s, value)
        if clean == nil then return false, why end
    end
    local values, why = EditableValues(id)
    if not values then return false, why end
    values[key] = clean
    if clean ~= nil then
        if key == "shoulder" then values.shoulderCurve = nil end         -- a fixed offset replaces the curve
        if key == "shoulderCurve" then values.shoulder = nil end
    end
    if active.id == id then ns.Evaluate(true) end
    return true
end

function ns.SetAdvanced(v)
    db.advanced = v and true or false
end

---------------------------------------------------------------------------
-- "By zoom" settings (shoulderCurve, focusCurve, fovCurve): the editor's switch and its table by zoom view
---------------------------------------------------------------------------
local putAway = {}            -- the points a switch took away this session, given back when it goes on again

function ns.SetByZoom(id, key, on)
    local p = ns.GetProfile(id)
    if not (p and ns.VIEW_DEFAULTS[key]) then return false, "unknown" end
    local cur = p.values[key]
    if on then
        if cur then return true end
        local points = putAway[id .. key] or (ns.BUILTIN[id] and ns.BUILTIN[id].values[key])
            or ns.CurveFromViews(ns.VIEW_DEFAULTS[key])
        return ns.SetValue(id, key, copy(points))
    end
    if not cur then return true end
    local kept, ok, why = copy(cur), nil, nil
    if key == "shoulderCurve" then                  -- the offset you see now becomes the one offset
        local z = tonumber(G("GetCameraZoom")) or tonumber(p.values.zoom) or 0
        ok, why = ns.SetValue(id, "shoulder", ns.Round(ns.EvalCurve(cur, z), 1))
    else
        ok, why = ns.SetValue(id, key, nil)
    end
    if ok then putAway[id .. key] = kept end
    return ok, why
end

-- One view's value. The curve is rebuilt from the six views, so points set by hand give way to them.
function ns.SetViewValue(id, key, view, value)
    local p = ns.GetProfile(id)
    local cur = p and p.values[key]
    if not (cur and ns.ZOOM_VIEWS[view]) then return false, "off" end
    local values = ns.ViewValues(cur)
    if math.abs(values[view] - value) < 0.001 then return true end
    values[view] = value
    return ns.SetValue(id, key, ns.CurveFromViews(values))
end

-- Back to the original of a built-in profile you edited.
function ns.ResetBuiltin(id)
    if not (ns.BUILTIN[id] and db.overrides[id]) then return false end
    db.overrides[id] = nil
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

-- The whole setup as one string (the format is in Share.lua), and back. Importing replaces which profile each
-- situation uses; an own profile whose name you already have is replaced, the others are added.
function ns.ExportSetup()
    local setup = { assign = {}, exitDelay = db.exitDelay, flipShoulder = db.flipShoulder, advanced = db.advanced,
                    offsetScale = db.offsetScale, formOffset = db.formOffset, profiles = {}, overrides = db.overrides }
    local ids, index = {}, {}
    for id in pairs(db.profiles) do ids[#ids + 1] = id end
    table.sort(ids)
    for i, id in ipairs(ids) do
        setup.profiles[i] = db.profiles[id]
        index[id] = i
    end
    local function ref(id) return id and (index[id] or (ns.BUILTIN[id] and id)) or nil end
    for sit, id in pairs(db.assign) do setup.assign[sit] = ref(id) end
    setup.force = ref(db.force)
    return ns.FormatSetup(setup)
end

function ns.ImportSetup(str)
    local setup, err = ns.ParseSetup(str)
    if not setup then return nil, err end
    local ids = {}
    for i, p in ipairs(setup.profiles) do
        local low, found = p.name:lower(), nil
        for id, mine in pairs(db.profiles) do
            if mine.name:lower() == low then found = id end
        end
        if found then
            local clean = ns.ValidateProfile({ name = db.profiles[found].name, values = copy(p.values) })
            if clean then db.profiles[found] = clean end
        else
            found = ns.CreateProfile(p.name, p.values)
        end
        ids[i] = found
    end
    local function id(r)
        if type(r) == "number" then return ids[r] end
        return r
    end
    db.assign = {}
    for sit, r in pairs(setup.assign) do db.assign[sit] = id(r) end
    db.force = id(setup.force)
    if setup.exitDelay then db.exitDelay = setup.exitDelay end
    if setup.flipShoulder ~= nil then db.flipShoulder = setup.flipShoulder end
    if setup.advanced ~= nil then db.advanced = setup.advanced end
    db.offsetScale = setup.offsetScale or 1
    db.formOffset = copy(setup.formOffset)
    db.overrides = copy(setup.overrides)
    ns.Evaluate(true)
    return true
end

-- For the HUD (a second, optional addon), whose one line of settings carries the camera's setup too
ControllerCam = ControllerCam or {}
function ControllerCam.ExportSetup() return ns.ExportSetup() end
function ControllerCam.ImportSetup(str) return ns.ImportSetup(str) end

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

-- Fishing: your line is out, and the moments between casts while the pole stays in your hands, so the view
-- holds through a spell of fishing instead of swinging back after every catch. Only carrying a pole changes
-- nothing; putting it away ends it.
local FISHING_LINGER = 12
local fishedAt
local FISHING_SPELLS = { [7620] = true, [7731] = true, [7732] = true, [18248] = true, [33095] = true, [51294] = true,
                         [88868] = true, [110410] = true, [131474] = true, [158743] = true }

local function HasPole()
    local id = G("GetInventoryItemID", "player", 16)
    local instant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if id and instant then
        local _, _, _, _, _, classID, subClassID = instant(id)
        if classID == 2 and subClassID == 20 then return true end
    end
    return false
end

local function IsFishing()
    local _, _, _, _, _, _, _, spellID = G("UnitChannelInfo", "player")
    local now = GetTime()
    if type(spellID) == "number" and FISHING_SPELLS[spellID] then
        fishedAt = now
        return true
    end
    if fishedAt and now - fishedAt < FISHING_LINGER and HasPole() then return true end
    fishedAt = nil
    return false
end

local MATCH = {
    vehicle  = function() return G("UnitInVehicle", "player") or G("UnitHasVehicleUI", "player") end,
    flying   = function() return G("IsFlying") end,
    swimming = function() return G("IsSwimming") end,
    mounted  = function() return G("IsMounted") end,
    combat   = function() return G("UnitAffectingCombat", "player") or G("InCombatLockdown") end,
    fishing  = IsFishing,
    raid     = function() return InstanceType() == "raid" end,
    dungeon  = function() local t = InstanceType(); return t == "party" or t == "scenario" end,
    indoors  = function() return G("IsIndoors") end,
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

---------------------------------------------------------------------------
-- Field of view
-- None of the camera CVars confirmed in the client is a field of view, so the game is asked: only if it answers
-- to the name (with a value and a default, and does not mark it read-only) is anything done with it. A profile's
-- values are shares of your own field of view, so no unit has to be guessed. Yours is what it was before a
-- profile scaled it; change it in the game's settings meanwhile and that is yours from then on.
---------------------------------------------------------------------------
ns.FOV_CVARS = { "cameraFov" }
local fovRefused = false      -- it took no change: left alone from then on
local fovWrote                -- what it read right after we last changed it

local function ReadOnly(name)
    if not (C_CVar and C_CVar.GetCVarInfo) then return false end
    local ok, _, _, _, _, locked, _, readOnly = pcall(C_CVar.GetCVarInfo, name)
    return ok and (locked == true or readOnly == true)
end

local function FovName()      -- the game's name for it, if it has one (whether or not it takes changes)
    for _, name in ipairs(ns.FOV_CVARS) do
        local okV, v = pcall(GetCVar, name)
        local okD, d = pcall(GetCVarDefault, name)
        v, d = okV and tonumber(v), okD and tonumber(d)
        if v and d and v > 0 and d > 0 then return name end
    end
end

function ns.FovCVar()         -- the name to use, or nil when the game has no field of view for add-ons
    if fovRefused then return nil end
    local name = FovName()
    if name and not ReadOnly(name) then return name end
end

local function OwnFov(cvar)
    local cur = tonumber(GetCVar(cvar))
    if db.originals[cvar] ~= nil and fovWrote and cur and math.abs(cur - fovWrote) > 0.001 then
        db.originals[cvar] = tostring(cur)           -- you changed it since: that is your own now
        fovWrote = cur
    end
    return tonumber(db.originals[cvar]) or cur
end

local lastSet = {}            -- cvar -> GetTime() we last set it (the trace tells ours from the game's)
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
    lastSet[cvar] = GetTime()
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

-- Shapeshift forms: the game scales the shoulder offset with the size of the model you are in, so a form
-- (cat, bear, ghost wolf...) moves the camera further to the side. In a form the offset is scaled back by a
-- share; /ccam formoffset sets it for the form you are in. (Starting values, by the game's form id.)
local FORM_SCALE = { [1] = 0.6, [2] = 0.5, [3] = 0.6, [4] = 0.6, [5] = 0.5, [8] = 0.5, [16] = 0.7, [27] = 0.6,
                     [29] = 0.6, [31] = 0.5 }
ns.FORM_SCALE = FORM_SCALE

function ns.CurrentForm()
    local id = G("GetShapeshiftFormID")
    if type(id) ~= "number" or id == 0 then return nil end
    return id
end

function ns.ShoulderScale()
    local id = ns.CurrentForm()
    if not id then return 1 end
    return (db and db.formOffset[id]) or FORM_SCALE[id] or 1
end

-- Everything the shoulder offset is multiplied by: your own overall strength, and the form you are in
local function OffsetFactor()
    return ns.ShoulderScale() * ((db and db.offsetScale) or 1)
end

-- How you move and the stick's speeds (the game's own Controller settings: facing, turning with the camera, the
-- stick's turn and look speeds, the camera following the stick) are yours: the profiles only set them once you
-- said they may (asked once, at the first login: ns.AskMovement), and not at all before you answered.
ns.MOVEMENT_GROUPS = { Facing = true, Controller = true }
local function MayManage(s)
    return not ns.MOVEMENT_GROUPS[s.group] or (db and db.movement == true)
end
ns.MayManage = MayManage

-- Compute what a profile wants: { cvar = "value" }, zoom, the values that follow the zoom, whether it uses
-- ActionCam features.
local function Resolve(profile, withZoom)
    local values = profile.values
    local flip = db.flipShoulder
    local desired = {}
    local zoom = tonumber(values.zoom)
    local theCurve = values.shoulderCurve
    local needsMotion = false
    local follows = {}
    local at = (withZoom and zoom) or tonumber(G("GetCameraZoom")) or zoom or 0
    local function Follow(cvar, fn)
        follows[#follows + 1] = { cvar = cvar, at = fn }
        desired[cvar] = ns.FormatNumber(fn(at))
    end

    for _, s in ipairs(ns.SETTINGS) do
        if s.api then
            -- applied separately
        elseif not MayManage(s) then
            -- (yours: left as you have it)
        elseif s.key == "shoulderCurve" then
            if theCurve then
                local sign = flip and -1 or 1
                Follow("test_cameraOverShoulder", function(z) return sign * ns.EvalCurve(theCurve, z) * OffsetFactor() end)
                for _, p in ipairs(theCurve) do if p[2] ~= 0 then needsMotion = true end end
            end
        elseif s.key == "focusCurve" then
            local share = values.focusCurve
            if share and values.focusEnemy == 1 then
                for _, cvar in ipairs(s.cvars) do
                    local full = tonumber(desired[cvar])
                    if full then Follow(cvar, function(z) return full * ns.EvalCurve(share, z) end) end
                end
            end
        elseif s.key == "fovCurve" then
            local share, cvar = values.fovCurve, ns.FovCVar()
            local own = share and cvar and OwnFov(cvar)
            if own then Follow(cvar, function(z) return own * ns.EvalCurve(share, z) end) end
        elseif not (s.key == "shoulder" and theCurve) then
            for _, cvar in ipairs(s.cvars) do
                local v
                if s.keepUser and values[s.key] == nil then
                    v = db.originals[cvar]          -- your own value (only known once a profile has changed it)
                else
                    v = ns.ResolveCVar(s, values[s.key], cvar, flip)
                    if cvar == "test_cameraOverShoulder" and tonumber(v) then
                        v = ns.FormatNumber(tonumber(v) * OffsetFactor())
                    end
                end
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
    return desired, zoom, follows, needsMotion
end

local function Following(follows, cvar)
    for _, one in ipairs(follows) do
        if one.cvar == cvar then return true end
    end
    return false
end

-- Set a value that follows the zoom (or any other); the field of view remembers what it read afterwards
local function SetFollowed(cvar, value)
    local before = GetCVar(cvar)
    local done = SetOne(cvar, value)
    if cvar == FovName() then
        fovWrote = tonumber(GetCVar(cvar))
        if not G("InCombatLockdown") and not SameValue(before, value) and SameValue(before, GetCVar(cvar)) then
            fovRefused = true                         -- the game keeps its own: not asked again
            db.originals[cvar], fovWrote = nil, nil
            dbg(cvar .. " takes no change in this game")
        end
    end
    return done
end

-- A profile without a field of view by zoom: yours back, and forgotten (yours to change again)
local function GiveBackFov()
    local cvar = FovName()
    if not (cvar and db.originals[cvar] ~= nil) then return end
    local own = OwnFov(cvar)
    if own and SetOne(cvar, tostring(db.originals[cvar])) then db.originals[cvar], fovWrote = nil, nil end
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

---------------------------------------------------------------------------
-- In the water
-- The swimming stroke moves your character's head a long way, and head tracking pulls the camera after it: the
-- camera swung aside as you went in. While you swim, head tracking rests; the profile's own value is back the
-- moment you leave the water. What happens as you go in and come out is noted in ControllerCamDB.trace, to be
-- read after a reload: the camera's values, any the game changes by itself, and whether your character turned.
---------------------------------------------------------------------------
-- The camera that tilts with the ground under you (dynamic pitch, terrain tilt) tilts with the sea bed too: it
-- swung up and down as you swam over it. Both rest in the water as well.
ns.WATER = { test_cameraHeadMovementStrength = "0", test_cameraDynamicPitch = "0", cameraTerrainTilt = "0" }
ns.WATCHED = { "test_cameraOverShoulder", "test_cameraHeadMovementStrength", "GamePadFaceMovementSwimming",
               "GamePadFaceMovementMaxAngle", "GamePadTurnWithCamera", "test_cameraDynamicPitch",
               "CameraFollowOnStick", "GamepadCameraFollowOnStick" }
local swimming, traceUntil = false, 0

local function Trace(msg)
    if not db then return end
    db.trace = db.trace or {}
    db.trace[#db.trace + 1] = ("%s %s"):format(date and date("%H:%M:%S") or "", msg)
    while #db.trace > 40 do table.remove(db.trace, 1) end
end
ns.Trace = Trace

local function Snapshot()
    local parts = {}
    for _, cvar in ipairs(ns.WATCHED) do
        local v = GetCVar(cvar)
        if v ~= nil then parts[#parts + 1] = cvar .. "=" .. tostring(v) end
    end
    local z, facing = G("GetCameraZoom"), G("GetPlayerFacing")
    parts[#parts + 1] = "zoom=" .. (type(z) == "number" and ("%.1f"):format(z) or tostring(z))
    parts[#parts + 1] = "facing=" .. (type(facing) == "number" and ("%.2f"):format(facing) or tostring(facing))
    parts[#parts + 1] = "profile=" .. tostring(active.id) .. " (" .. tostring(active.sit) .. ")"
    return table.concat(parts, " ")
end

function ns.Water()
    if not (db and db.enabled) then return end
    local now = G("IsSwimming") and true or false
    if now == swimming then return end
    swimming = now
    Trace((now and "into the water: " or "out of the water: ") .. Snapshot())
    traceUntil = GetTime() + 3
    ns.Evaluate(true)
    C_Timer.After(1, function() Trace("a second later: " .. Snapshot()) end)
end

function ns.Swimming() return swimming end

local function Apply(id, withZoom)
    local profile = Profile(id)
    if not profile then return end
    local desired, zoom, follows, needsMotion = Resolve(profile, withZoom)
    if swimming then                          -- in the water: head tracking rests (see above)
        for cvar, value in pairs(ns.WATER) do
            if desired[cvar] ~= nil then desired[cvar] = value end
        end
    end

    if held then                              -- (a scene has the camera: the middle, no auto-follow, for now)
        for cvar in pairs(ns.HELD) do desired[cvar] = nil end
    end
    EnforceMotion(needsMotion)            -- first: the offset and friends are ignored while these are on
    for cvar, value in pairs(desired) do SetFollowed(cvar, value) end
    local fov = FovName()
    if fov and not Following(follows, fov) then GiveBackFov() end
    if withZoom and zoom and not held then SetZoom(zoom, desired) end

    follow = follows
    for _, one in ipairs(follow) do one.last = tonumber(desired[one.cvar]) end
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

-- Follows the zoom level to move the "by zoom" values (shoulder offset, target focus, field of view) along the
-- profile's curves. Within a view they hold still, so nothing is written.
function ns.CurveTick()
    if held or not (db and db.enabled and follow[1]) then return end
    local z = tonumber(G("GetCameraZoom"))
    if not z then return end
    local fov = FovName()
    for _, one in ipairs(follow) do
        local v = one.at(z)
        if one.cvar == fov and fovWrote then         -- changed in the game's settings: start afresh from that
            local cur = tonumber(GetCVar(fov))
            if cur and math.abs(cur - fovWrote) > 0.001 then ns.Evaluate(true); return end
        end
        if not (one.last and math.abs(v - one.last) < 0.005) then
            if SetFollowed(one.cvar, ns.FormatNumber(v)) then one.last = v end
        end
    end
end

-- A scene of the HUD's (the camp fire) has the camera for a while: the shoulder offset rests at the middle, so
-- the camera turns round your character, and the profile keeps its hands off the distance. Let go, the profile in
-- effect comes back as it was.
-- While a scene of the HUD's has the camera: the offset at the middle, and the game's auto-follow resting (on a
-- flight you are moving, and auto-follow pulled the camera back behind you as the scene turned it round). What
-- these were is kept (with the saved settings too, in case the game closes mid-scene) and put back on letting go.
ns.HELD = { test_cameraOverShoulder = "0", cameraSmoothStyle = "0" }
function ControllerCam.Hold(on)
    on = on and true or false
    if on == held then return end
    held = on
    if not (db and db.enabled) then return end
    if held then
        db.heldWas = {}
        for cvar, value in pairs(ns.HELD) do
            local cur = GetCVar(cvar)
            if cur ~= nil then
                db.heldWas[cvar] = tostring(cur)
                SetOne(cvar, value)
            end
        end
    else
        local was = db.heldWas
        db.heldWas = nil
        for cvar, value in pairs(was or {}) do SetOne(cvar, value) end
        ns.Evaluate(true)
        ns.CurveTick()
    end
end

-- A scene cut off (the game closed while it held the camera): what it held, put back as the addon loads
function ns.Unhold()
    if not (db and db.heldWas) or held then return end
    for cvar, value in pairs(db.heldWas) do pcall(SetCVar, cvar, value) end
    db.heldWas = nil
end
function ControllerCam.IsHeld() return held end

---------------------------------------------------------------------------
-- Settings changes made by the options panel and the slash commands
---------------------------------------------------------------------------
-- Your share of the shoulder offset for the form you are in (nil puts the starting value back)
function ns.SetFormOffset(share)
    local id = ns.CurrentForm()
    if not id then return nil end
    db.formOffset[id] = share
    ns.Evaluate(true)
    return id
end

-- Your overall strength of the shoulder offset (1: as the profiles have it), for every profile and form
function ns.SetOffsetScale(n)
    db.offsetScale = math.min(math.max(tonumber(n) or 1, 0), 2)
    ns.Evaluate(true)
end

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
-- The HUD (a second, optional addon) may follow: a preset chosen here picks its matching HUD preset
local function TellHUD(id)
    local hud = _G.ControllerCamHUD
    if type(hud) == "table" and type(hud.CameraPreset) == "function" then pcall(hud.CameraPreset, id) end
end

function ns.UseEverywhere(id)
    if not ns.GetProfile(id) then return false end
    db.assign = { default = id }
    db.force = nil
    ns.Evaluate(true)
    TellHUD(id)
    return true
end

function ns.ApplyStarter()
    db.assign = copy(ns.STARTER)
    db.force = nil
    ns.Evaluate(true)
    TellHUD("action")
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

---------------------------------------------------------------------------
-- Closer on an enemy: target an enemy and the camera comes in to this distance (yards), the profile in effect
-- otherwise as it is (its offset, its angle); let the target go (dead, or none for a moment) and it goes back to
-- where you had it, unless you zoomed yourself meanwhile. Roaming far out, fighting up close. 0: off. Not while
-- mounted, flying or in a vehicle, and not while a scene of the HUD has the camera.
---------------------------------------------------------------------------
local TARGET_LET_GO = 2.0     -- seconds without an enemy target before the camera goes back out
local closer, lostAt          -- { from = the distance you had, to = ours }
local function Yes(fn, ...)   -- a yes from the game (one it keeps to itself counts as no)
    local ok, v = pcall(fn, ...)
    if not ok then return false end
    local okT, yes = pcall(function() return v == true or (v ~= nil and v ~= false and v ~= 0) end)
    return okT and yes or false
end
local function EnemyTarget()
    if not (UnitExists and UnitCanAttack and UnitIsDead) then return false end
    return Yes(UnitExists, "target") and Yes(UnitCanAttack, "player", "target") and not Yes(UnitIsDead, "target")
end
ns.EnemyTarget = EnemyTarget

function ns.TargetZoom()
    if not db or held then return end
    local want = tonumber(db.targetZoom) or 0
    local blocked = not db.enabled or want <= 0 or Yes(G, "IsMounted") or Yes(G, "IsFlying")
        or Yes(G, "UnitInVehicle", "player")
    local cur = tonumber(G("GetCameraZoom"))
    if not blocked and EnemyTarget() then
        lostAt = nil
        if not closer and cur and cur > want + 0.5 then
            closer = { from = cur, to = want }
            SetZoom(want, {})
            ns.closerCount = (ns.closerCount or 0) + 1
        end
        return
    end
    if not closer then return end
    lostAt = lostAt or GetTime()
    if blocked or GetTime() - lostAt >= TARGET_LET_GO then
        if cur and math.abs(cur - closer.to) < 1.0 then SetZoom(closer.from, {}) end   -- (zoomed yourself: stays)
        closer, lostAt = nil, nil
    end
end
function ns.TargetZoomState() return closer and { from = closer.from, to = closer.to } or nil end

function ns.SetTargetZoom(n)
    db.targetZoom = math.min(math.max(tonumber(n) or 0, 0), 15)
    ns.TargetZoom()
end

function ns.SetFlipShoulder(v)
    db.flipShoulder = v and true or false
    ns.Evaluate(true)
end

-- Profiles may set how you move and the stick's speeds (true), or they're yours (false): yours are put back as
-- you had them before a profile changed them
function ns.SetMovement(v)
    db.movement = v and true or false
    if not db.movement then
        for _, s in ipairs(ns.SETTINGS) do
            if ns.MOVEMENT_GROUPS[s.group] and s.cvars then
                for _, cvar in ipairs(s.cvars) do
                    local was = db.originals[cvar]
                    if was ~= nil then
                        pcall(SetCVar, cvar, was)
                        db.originals[cvar] = nil
                    end
                end
            end
        end
    end
    ns.Evaluate(true)
end

-- Asked once: a small window of our own (A: let them, B: keep mine; or the mouse), never in a fight
local ask, askOwner, askLater
function ns.AskMovement()
    if not db or db.movement ~= nil then return end
    if InCombatLockdown() then askLater = true; return end
    askLater = nil
    if not ask then
        ask = CreateFrame("Frame", "ControllerCamMovementAsk", UIParent)
        ask:SetSize(420, 150)
        ask:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
        ask:SetFrameStrata("DIALOG")
        ask:EnableMouse(true)
        ask.back = ask:CreateTexture(nil, "BACKGROUND")
        ask.back:SetColorTexture(0.03, 0.04, 0.07, 0.94)
        ask.back:SetAllPoints(ask)
        ask.title = ask:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        ask.title:SetPoint("TOP", ask, "TOP", 0, -14)
        ask.title:SetText(L["ControllerCam: how you move"])
        ask.text = ask:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        ask.text:SetPoint("TOPLEFT", ask, "TOPLEFT", 18, -42)
        ask.text:SetPoint("TOPRIGHT", ask, "TOPRIGHT", -18, -42)
        ask.text:SetJustifyH("LEFT")
        ask.text:SetText(L["The camera profiles can also set how your character faces and turns as you move, and how fast the stick turns the camera. Let them, or keep your own settings?"])
        local function Answer(v)
            if askOwner then ClearOverrideBindings(askOwner) end
            ask:Hide()
            ns.SetMovement(v)
            ns.Say(v and L["The profiles now set how you move and the stick's speeds (/ccam movement to change it)."]
                or L["Your own movement and stick settings are kept (/ccam movement to change it)."])
        end
        ask.yes = CreateFrame("Button", "ControllerCamMovementYes", ask, "UIPanelButtonTemplate")
        ask.yes:SetSize(180, 26)
        ask.yes:SetPoint("BOTTOMLEFT", ask, "BOTTOMLEFT", 18, 14)
        ask.yes:SetText(L["Let the profiles set them"])
        ask.yes:SetScript("OnClick", function() Answer(true) end)
        ask.no = CreateFrame("Button", "ControllerCamMovementNo", ask, "UIPanelButtonTemplate")
        ask.no:SetSize(180, 26)
        ask.no:SetPoint("BOTTOMRIGHT", ask, "BOTTOMRIGHT", -18, 14)
        ask.no:SetText(L["Keep mine"])
        ask.no:SetScript("OnClick", function() Answer(false) end)
        askOwner = CreateFrame("Frame")
    end
    ask:Show()
    -- the controller's A and B answer it (the game's own buttons again as soon as it is answered)
    SetOverrideBindingClick(askOwner, true, "PAD1", "ControllerCamMovementYes", "LeftButton")
    SetOverrideBindingClick(askOwner, true, "PAD2", "ControllerCamMovementNo", "LeftButton")
end
function ns.AskLater() return askLater end

-- Put back the camera settings you had before ControllerCam changed them.
function ns.Restore()
    for cvar, value in pairs(db.originals) do pcall(SetCVar, cvar, value) end
    db.originals = {}
    EnforceMotion(false)
    follow, active, fovWrote = {}, {}, nil
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
    local fov = FovName()
    if fov then set[fov] = true end
    return set
end

local function InitDB()
    local old = ControllerCamDB
    local fresh = type(old) ~= "table" or old.v == nil
    if type(old) ~= "table" then old = {} end

    local d = {
        v = 3,
        enabled = old.enabled ~= false,
        exitDelay = math.min(math.max(tonumber(old.exitDelay) or DEFAULT_EXIT_DELAY, 0), 10),
        targetZoom = math.min(math.max(tonumber(old.targetZoom) or 0, 0), 15),   -- closer on an enemy (0: off)
        flipShoulder = old.flipShoulder == true,
        offsetScale = math.min(math.max(tonumber(old.offsetScale) or 1, 0), 2),  -- your share of the shoulder offset
        welcomed = old.welcomed == true,
        noticeAccepted = old.noticeAccepted == true,      -- the game's experimental camera notice, accepted once
        advanced = old.advanced == true,
        profiles = {}, overrides = {}, assign = {}, originals = {}, motion = {}, formOffset = {},
    }
    if type(old.movement) == "boolean" then d.movement = old.movement end   -- (your answer; nil: not asked yet)
    if type(old.formOffset) == "table" then                      -- your own share per shapeshift form
        for id, share in pairs(old.formOffset) do
            if type(id) == "number" and type(share) == "number" and share >= 0 and share <= 2 then
                d.formOffset[id] = share
            end
        end
    end
    -- Anything in the saved file is checked the same way as an imported string.
    if type(old.profiles) == "table" then
        for id, p in pairs(old.profiles) do
            if type(id) == "string" and not ns.BUILTIN[id] then
                local clean = ns.ValidateProfile(p)
                if clean then d.profiles[id] = clean end
            end
        end
    end
    if type(old.overrides) == "table" then                       -- edited built-in profiles
        for id, values in pairs(old.overrides) do
            local b = type(id) == "string" and ns.BUILTIN[id]
            if b and type(values) == "table" then
                local clean = ns.ValidateProfile({ name = b.name, values = values })
                if clean then d.overrides[id] = clean.values end
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
    -- before version 2 fishing had no camera of its own until you picked one: it takes the starter's once
    -- (/ccam set fishing none puts it back to nothing)
    if not fresh and (tonumber(old.v) or 0) < 2 and d.assign.fishing == nil then d.assign.fishing = ns.STARTER.fishing end
    -- before version 3 the starter swapped to Hybrid in the water, which turned you as you went in: that one
    -- goes (Hybrid chosen for swimming again since is kept)
    if not fresh and (tonumber(old.v) or 0) < 3 and d.assign.swimming == "hybrid" then d.assign.swimming = nil end
    if type(old.force) == "string" and ns.GetProfile(old.force) then d.force = old.force end
    local known = KnownCVars()
    if type(old.originals) == "table" then
        for cvar, val in pairs(old.originals) do
            if known[cvar] and type(val) == "string" then d.originals[cvar] = val end
        end
    end
    if type(old.heldWas) == "table" then                          -- a scene's hold, cut off: put back on load
        d.heldWas = {}
        for cvar, val in pairs(old.heldWas) do
            if ns.HELD[cvar] and type(val) == "string" then d.heldWas[cvar] = val end
        end
    end
    if type(old.trace) == "table" then                            -- what was noted going into the water
        d.trace = {}
        for _, line in ipairs(old.trace) do
            if type(line) == "string" and #d.trace < 40 then d.trace[#d.trace + 1] = line end
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
---------------------------------------------------------------------------
-- The game's notice about experimental camera settings
-- The shoulder offset and head tracking are settings the game calls experimental (its "test_camera..."
-- settings). While one is on, the game asks at every login whether you accept them. You answer it yourself,
-- once: after you have pressed Accept, the game is no longer told to ask (its UIParent stops listening for
-- that one request, the way an addon stops listening for any event), so the notice does not come back at
-- every login. The dialog itself stays the game's: we never show it, press it or hook it. Pressing Disable is
-- respected (the game turns the settings off, nothing is remembered). /ccam notice brings the question back.
---------------------------------------------------------------------------
ns.NOTICE_EVENT = "EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED"
ns.NOTICE_POPUP = "EXPERIMENTAL_CVAR_WARNING"
local notice = { asking = false, quieted = false }
ns.notice = notice

-- Is one of the game's experimental camera settings away from the game's own value?
local function TestCvarsOn()
    for cvar in pairs(KnownCVars()) do
        if cvar:find("^test_") then
            local v, d = tonumber(GetCVar(cvar)), tonumber(GetCVarDefault and GetCVarDefault(cvar))
            if v and d and math.abs(v - d) > 0.0001 then return true end
        end
    end
    return false
end
ns.TestCvarsOn = TestCvarsOn

local function PopupShown()
    if not StaticPopup_Visible then return false end
    local ok, v = pcall(StaticPopup_Visible, ns.NOTICE_POPUP)
    return ok and v and true or false
end

-- After you accepted once: the game is not told to ask again
-- (every frame of the game's that listens for the request, not only UIParent: more than one may ask, and
-- some only start listening later, so this is done again at login, after loading screens and when it is heard)
local noticeFrame
function ns.QuietNotice()
    if not (db and db.noticeAccepted) then return end
    notice.from = notice.from or {}                       -- (every listener quieted so far, for the trace)
    local names = notice.from
    local function Add(name) for _, n in ipairs(names) do if n == name then return end end names[#names + 1] = name end
    local ok = pcall(UIParent.UnregisterEvent, UIParent, ns.NOTICE_EVENT)
    if ok then Add("UIParent") end
    if GetFramesRegisteredForEvent then
        local okL, list = pcall(function() return { GetFramesRegisteredForEvent(ns.NOTICE_EVENT) } end)
        for _, frame in ipairs(okL and list or {}) do
            if frame ~= noticeFrame and frame ~= UIParent then
                local okU = pcall(frame.UnregisterEvent, frame, ns.NOTICE_EVENT)
                if okU then
                    local okN, name = pcall(frame.GetName, frame)
                    Add((okN and type(name) == "string") and name or (frame.__name or "a frame without a name"))
                end
            end
        end
    end
    notice.quieted = ok
    notice.quietedFrom = table.concat(names, ", ")
end

-- /ccam notice: the game asks again next time
function ns.AskNoticeAgain()
    db.noticeAccepted = false
    pcall(UIParent.RegisterEvent, UIParent, ns.NOTICE_EVENT)
    notice.quieted = false
end

-- The game asked: once you have answered (the dialog gone), Accept leaves the settings on, Disable turns them off
local function Watch()
    if not notice.asking then return end
    local now = GetTime()
    if PopupShown() then
        notice.seen = true
    elseif notice.seen then
        notice.asking = false
        if TestCvarsOn() then
            db.noticeAccepted = true
            ns.QuietNotice()
            Trace("experimental camera notice accepted: not asked again")
            ns.Say(L["The game will not ask about the experimental camera settings again (you accepted them). /ccam notice brings the question back."])
        else
            Trace("experimental camera notice: disabled")
        end
        return
    elseif now - notice.since > 5 then
        notice.asking = false                    -- the game did not show it after all
        return
    end
    if now - notice.since > 600 then notice.asking = false; return end
    C_Timer.After(0.5, Watch)
end

noticeFrame = CreateFrame("Frame")
pcall(noticeFrame.RegisterEvent, noticeFrame, ns.NOTICE_EVENT)
for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD" }) do pcall(noticeFrame.RegisterEvent, noticeFrame, e) end
noticeFrame:SetScript("OnEvent", function(_, event)
    if event ~= ns.NOTICE_EVENT then ns.QuietNotice(); return end         -- (late listeners: quieted too)
    if db and db.noticeAccepted then                                     -- asked again although you accepted
        ns.QuietNotice()
        Trace("experimental camera notice asked again although accepted; listeners quieted: " .. tostring(notice.quietedFrom))
        return
    end
    if not db or notice.asking then return end
    notice.asking, notice.seen, notice.since = true, false, GetTime()
    C_Timer.After(0.5, Watch)
end)

local f = CreateFrame("Frame", "ControllerCamFrame", UIParent)
ns.frame = f

local EVENTS = {
    "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    "PLAYER_MOUNT_DISPLAY_CHANGED", "PLAYER_UPDATE_RESTING", "ZONE_CHANGED_NEW_AREA",
    "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE", "UPDATE_SHAPESHIFT_FORM",
    "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "PLAYER_EQUIPMENT_CHANGED", "CVAR_UPDATE", "PLAYER_TARGET_CHANGED",
}
for _, e in ipairs(EVENTS) do pcall(f.RegisterEvent, f, e) end    -- a missing event must not break the addon

local function ScheduleTick()
    C_Timer.After(TICK, function()
        ns.Water()
        ns.Evaluate()
        pcall(ns.TargetZoom)                     -- (never in the way of the next tick)
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
    ns.AskMovement()
end

f:SetScript("OnEvent", function(_, event, arg1, arg2)
    if event == "CVAR_UPDATE" then
        -- noted for a moment after you go into or out of the water: which of the camera's values changed, and
        -- whether it was us or the game
        if db and GetTime() < traceUntil and type(arg1) == "string" then
            for _, cvar in ipairs(ns.WATCHED) do
                if cvar:lower() == arg1:lower() then
                    local ours = lastSet[cvar] and GetTime() - lastSet[cvar] < 0.1
                    Trace(("%s %s = %s"):format(ours and "we set" or "the game set", cvar, tostring(arg2 or GetCVar(cvar))))
                end
            end
        end
        return
    end
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end
        fresh = InitDB()
        ns.Unhold()
        ns.QuietNotice()
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
        if askLater then ns.AskMovement() end
    elseif event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE" then
        if arg1 == "player" then ns.Evaluate() end
    elseif event == "PLAYER_TARGET_CHANGED" then
        ns.TargetZoom()                          -- (closer on an enemy, out again when it is gone)
    elseif event == "UPDATE_SHAPESHIFT_FORM" then
        ns.Evaluate(true)                        -- the shoulder offset follows the new form at once
    else
        ns.Evaluate()
    end
end)

local acc = 0
f:SetScript("OnUpdate", function(_, elapsed)
    if not follow[1] then return end
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
