-- ControllerCam settings schema.
--
-- Every camera setting a profile can hold is described here: which CVar(s) it drives, its type and its legal
-- range. Profiles, the options panel and the import/export strings all go through this table, so a profile (or a
-- pasted string) can never set a CVar that is not listed here, nor a value outside its range.
--
-- Value types stored in a profile:
--   range / enum / bool : a number (bool is 0 or 1)
--   mul                 : "x1.25" = the game's default value times 1.25 (so presets do not depend on a guessed default)
--   any CVar setting    : "d" = the game's default value
--   zoom                : a number of yards (not a CVar; applied with the camera zoom functions)
--   curve               : a list of {zoom, value} points, the value is interpolated from the current camera zoom
--                         (the shoulder offset itself; for target focus and field of view, a share of the value)
-- A setting a profile does not mention is reset to the game default (zoom and curves: left alone / off;
-- settings marked keepUser: left to you).

local ADDON, ns = ...

-- CVar names below were checked against the strings inside the Forever client executable.
local SETTINGS = {
    -- key, label (English text = localization key), kind, cvars, min, max, step, group
    { key = "zoom",            label = "Camera distance (yards)",          kind = "range", api = "zoom", min = 1, max = 39, step = 0.5, group = "Zoom" },
    { key = "zoomMax",         label = "Maximum zoom-out factor",           kind = "range", cvars = { "cameraDistanceMaxZoomFactor" }, min = 1, max = 2.6, step = 0.1, group = "Zoom" },
    -- No field of view CVar is among the names confirmed in the client, so this one lists none: Core.lua asks the
    -- game for it at runtime (ns.FovCVar) and does nothing without an answer. Its values are shares of your own.
    { key = "fovCurve",        label = "Field of view by zoom",             kind = "curve", probe = "fov", min = 0.5, max = 1.5, zoomMax = 39, group = "Zoom" },

    { key = "yawSpeed",        label = "Stick turn speed (left/right)",     kind = "mul",   cvars = { "GamePadCameraYawSpeed" },   min = 0.25, max = 4, step = 0.05, group = "Controller" },
    { key = "pitchSpeed",      label = "Stick look speed (up/down)",        kind = "mul",   cvars = { "GamePadCameraPitchSpeed" }, min = 0.25, max = 4, step = 0.05, group = "Controller" },
    { key = "followOnStick",   label = "Camera follows the way you move",   kind = "bool",  cvars = { "GamepadCameraFollowOnStick", "CameraFollowOnStick" }, group = "Controller" },
    { key = "followYawSpeed",  label = "Follow speed (left/right)",         kind = "mul",   cvars = { "CameraFollowYawSpeed" },    min = 0.25, max = 4, step = 0.05, group = "Controller" },
    { key = "followPitchSpeed",label = "Follow speed (up/down)",            kind = "mul",   cvars = { "CameraFollowPitchSpeed" },  min = 0.25, max = 4, step = 0.05, group = "Controller" },
    { key = "followDelay",     label = "Delay before follow resumes",       kind = "mul",   cvars = { "CameraFollowGamepadAdjustDelay" }, min = 0.25, max = 4, step = 0.05, group = "Controller" },

    { key = "faceAngle",       label = "Face movement direction (max angle)",        kind = "range", cvars = { "GamePadFaceMovementMaxAngle" },       min = 0, max = 180, step = 5, group = "Facing" },
    { key = "faceAngleCombat", label = "Face movement direction in combat (max angle)", kind = "range", cvars = { "GamePadFaceMovementMaxAngleCombat" }, min = 0, max = 180, step = 5, group = "Facing" },
    { key = "turnWithCamera",  label = "Turn character with camera",        kind = "enum",  cvars = { "GamePadTurnWithCamera" }, min = 0, max = 3, group = "Facing",
      values = { "never", "in combat", "always", "in combat or casting" } },
    { key = "faceMount",       label = "Face movement direction on a mount", kind = "bool",  cvars = { "GamePadFaceMovementMount" },      group = "Facing" },
    { key = "faceSwim",        label = "Face movement direction when swimming", kind = "bool", cvars = { "GamePadFaceMovementSwimming" }, group = "Facing" },
    { key = "faceFly",         label = "Face movement direction when flying", kind = "bool",  cvars = { "GamePadFaceMovementFreeFlying" }, group = "Facing" },

    { key = "shoulder",        label = "Over-the-shoulder offset",          kind = "range", cvars = { "test_cameraOverShoulder" }, min = -5, max = 5, step = 0.1, group = "Shoulder", actionCam = true },
    { key = "shoulderCurve",   label = "Over-the-shoulder offset by zoom",  kind = "curve", cvars = { "test_cameraOverShoulder" }, min = -5, max = 5, zoomMax = 39, group = "Shoulder", actionCam = true },
    { key = "dynamicPitch",    label = "Dynamic pitch (cinematic tilt)",    kind = "bool",  cvars = { "test_cameraDynamicPitch" }, group = "Shoulder", actionCam = true },

    { key = "headStrength",    label = "Head tracking strength",            kind = "range", cvars = { "test_cameraHeadMovementStrength" },         min = 0, max = 1, step = 0.05, group = "Head tracking", actionCam = true },
    { key = "headStanding",    label = "Head tracking while standing",      kind = "range", cvars = { "test_cameraHeadMovementStandingStrength" }, min = 0, max = 2, step = 0.05, group = "Head tracking" },
    { key = "headMoving",      label = "Head tracking while moving",        kind = "range", cvars = { "test_cameraHeadMovementMovingStrength" },   min = 0, max = 2, step = 0.05, group = "Head tracking" },
    { key = "headRange",       label = "Head tracking range",               kind = "range", cvars = { "test_cameraHeadMovementRangeScale" },       min = 1, max = 10, step = 0.5, group = "Head tracking" },

    { key = "focusEnemy",      label = "Look toward your target",           kind = "bool",  cvars = { "test_cameraTargetFocusEnemyEnable" }, group = "Targets", actionCam = true },
    { key = "focusEnemyYaw",   label = "Target focus strength (left/right)", kind = "range", cvars = { "test_cameraTargetFocusEnemyStrengthYaw" },   min = 0, max = 1, step = 0.05, group = "Targets" },
    { key = "focusEnemyPitch", label = "Target focus strength (up/down)",   kind = "range", cvars = { "test_cameraTargetFocusEnemyStrengthPitch" }, min = 0, max = 1, step = 0.05, group = "Targets" },
    -- (after the two strengths: it takes a share of each as the zoom changes)
    { key = "focusCurve",      label = "Target focus by zoom",              kind = "curve", cvars = { "test_cameraTargetFocusEnemyStrengthYaw", "test_cameraTargetFocusEnemyStrengthPitch" }, min = 0, max = 1, zoomMax = 39, group = "Targets" },
    { key = "focusInteract",   label = "Look toward NPCs you talk to",      kind = "bool",  cvars = { "test_cameraTargetFocusInteractEnable" }, group = "Targets", actionCam = true },
    { key = "focusInteractYaw",   label = "Interaction focus strength (left/right)", kind = "range", cvars = { "test_cameraTargetFocusInteractStrengthYaw" },   min = 0, max = 1, step = 0.05, group = "Targets" },
    { key = "focusInteractPitch", label = "Interaction focus strength (up/down)",   kind = "range", cvars = { "test_cameraTargetFocusInteractStrengthPitch" }, min = 0, max = 1, step = 0.05, group = "Targets" },

    { key = "smoothStyle",     label = "Camera auto-follow (mouse and keyboard)", kind = "enum", cvars = { "cameraSmoothStyle" }, min = 0, max = 2, group = "Smoothing",
      values = { "never", "only when moving", "always" } },
    -- keepUser: a profile that does not mention it leaves your own setting alone (and puts it back if a
    -- profile changed it), instead of resetting it to the game default.
    { key = "followTerrain",   label = "Camera follows terrain",            kind = "bool",  cvars = { "cameraTerrainTilt" }, group = "Smoothing", keepUser = true },
}

-- One plain line about each setting, shown under it in the editor (English text = localization key)
local HELP = {
    zoom = { help = "How far away the camera sits when this profile takes over." },
    zoomMax = { help = "How far out you can pull the camera. Higher is farther." },
    fovCurve = { help = "Exact points behind the table above, as distance:share. 1 is your own." },
    yawSpeed = { help = "How fast the right stick turns the camera." },
    pitchSpeed = { help = "How fast the right stick looks up and down." },
    followOnStick = { help = "The camera swings round behind you as you run." },
    followYawSpeed = { help = "How quickly the camera swings round behind you." },
    followPitchSpeed = { help = "How quickly the camera levels out again." },
    followDelay = { help = "How long the camera waits after you move it yourself." },
    faceAngle = { help = "0: your character faces wherever it runs. 180: it keeps facing forward and strafes." },
    faceAngleCombat = { help = "The same choice, while you are in a fight." },
    turnWithCamera = { help = "When your character turns as you turn the camera." },
    faceMount = { help = "Your mount turns to face the way you push the stick." },
    faceSwim = { help = "While swimming, your character turns to face the way you push the stick." },
    faceFly = { help = "While flying, you turn to face the way you push the stick." },
    shoulder = { help = "One offset at every distance. 0 keeps your character in the middle." },
    shoulderCurve = { help = "Exact points behind the table above, as distance:offset." },
    dynamicPitch = { help = "Tilts the view as you zoom, for a lower, cinematic angle." },
    headStrength = { help = "How much the camera moves with your character's head. 0 is off." },
    headStanding = { help = "How much of that movement while you stand still." },
    headMoving = { help = "How much of that movement while you run." },
    headRange = { help = "How far out the camera can be and still move with your character's head." },
    focusEnemy = { help = "The camera turns toward the enemy you have targeted." },
    focusEnemyYaw = { help = "How hard it turns left and right. 1 is the strongest." },
    focusEnemyPitch = { help = "How hard it tilts up and down. 1 is the strongest." },
    focusCurve = { help = "Exact points behind the table above, as distance:share. 1 is full strength." },
    focusInteract = { help = "The camera turns toward the person you are talking to." },
    focusInteractYaw = { help = "How hard it turns left and right toward them." },
    focusInteractPitch = { help = "How hard it tilts up and down toward them." },
    smoothStyle = { help = "With mouse and keyboard: when the camera swings back behind you." },
    followTerrain = { help = "Tilts the camera with hills and slopes. Yours is kept unless set here." },
}

-- The editor's areas, in the order of its menu: the group's id (its English name) and what it is for
ns.GROUPS = {
    { id = "Zoom",          help = "How far away the camera sits, and how far out you can pull it." },
    { id = "Shoulder",      help = "How far to the side the camera sits, so your character is not in the middle of the screen." },
    { id = "Targets",       help = "How much the camera turns to look at your target, or at the person you talk to." },
    { id = "Head tracking", help = "How much the camera moves along with your character's head." },
    { id = "Smoothing",     help = "Small movements the camera makes on its own." },
    { id = "Controller",    help = "How fast the stick moves the camera, and whether the camera follows where you run." },
    { id = "Facing",        help = "Which way your character faces as you move." },
}

local BY_KEY = {}
for i, s in ipairs(SETTINGS) do
    s.order = i
    s.help = HELP[s.key] and HELP[s.key].help
    BY_KEY[s.key] = s
end

ns.SETTINGS = SETTINGS
ns.SETTING_BY_KEY = BY_KEY
ns.MAX_CURVE_POINTS = 12      -- two for each zoom view
ns.MAX_NAME_LENGTH = 32

---------------------------------------------------------------------------
-- Zoom views: the few distances the camera is really used at. A "by zoom" setting has one value for each; the
-- value holds across the view and eases into the next one in the gap between them, so nothing snaps. It is
-- stored as an ordinary curve (shared and edited like any other).
---------------------------------------------------------------------------
ns.ZOOM_VIEWS = {
    { key = "first",    name = "First person",      from = 0,   to = 1 },
    { key = "shoulder", name = "Over the shoulder", from = 2,   to = 3.5 },
    { key = "torso",    name = "Upper body",        from = 4.5, to = 6 },
    { key = "body",     name = "Whole body",        from = 7,   to = 10 },
    { key = "mid",      name = "Mid range",         from = 13,  to = 20 },
    { key = "far",      name = "Zoomed out",        from = 24,  to = 39 },
}

-- One value per view -> curve points (points a straight line already passes through are left out)
function ns.CurveFromViews(values)
    local all = {}
    for i, view in ipairs(ns.ZOOM_VIEWS) do
        all[#all + 1] = { view.from, values[i] }
        all[#all + 1] = { view.to, values[i] }
    end
    local out = {}
    for i, p in ipairs(all) do
        local before, after = all[i - 1], all[i + 1]
        if not (before and after and before[2] == p[2] and after[2] == p[2]) then out[#out + 1] = p end
    end
    while #out > 1 and out[#out][2] == out[#out - 1][2] do table.remove(out) end   -- flat past the last point
    while #out > 1 and out[1][2] == out[2][2] do table.remove(out, 1) end          -- ... and before the first
    return out
end

-- The view a camera distance belongs to (a gap between two is split down the middle)
function ns.ViewAt(zoom)
    local views = ns.ZOOM_VIEWS
    for i = 1, #views - 1 do
        if zoom <= (views[i].to + views[i + 1].from) / 2 then return i end
    end
    return #views
end

-- CVars the game switches off or overrides to avoid motion sickness; the ActionCam features need them at 0.
ns.MOTION_CVARS = { "CameraKeepCharacterCentered", "CameraReduceUnexpectedMovement" }

---------------------------------------------------------------------------
-- Number helpers
---------------------------------------------------------------------------
local function isFinite(n)
    return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end
ns.IsFinite = isFinite

local function round(n, places)
    local m = 10 ^ (places or 3)
    return math.floor(n * m + 0.5) / m
end
ns.Round = round

-- 1.5 -> "1.5", 2 -> "2", 0.3333333 -> "0.333"
function ns.FormatNumber(n)
    local s = string.format("%.3f", n)
    s = s:gsub("0+$", ""):gsub("%.$", "")
    if s == "-0" or s == "" then s = "0" end
    return s
end

---------------------------------------------------------------------------
-- Curves
---------------------------------------------------------------------------
-- Returns a clean, sorted copy of a curve, or nil and a reason.
local function ValidateCurve(s, v)
    if type(v) ~= "table" then return nil, "curve" end
    local out = {}
    for _, p in ipairs(v) do
        if type(p) ~= "table" then return nil, "curve" end
        local z, val = tonumber(p[1]), tonumber(p[2])
        if not isFinite(z) or not isFinite(val) then return nil, "curve" end
        if z < 0 or z > s.zoomMax or val < s.min or val > s.max then return nil, "range" end
        out[#out + 1] = { round(z, 2), round(val, 2) }
    end
    if #out == 0 or #out > ns.MAX_CURVE_POINTS then return nil, "curve" end
    table.sort(out, function(a, b) return a[1] < b[1] end)
    for i = 2, #out do
        if out[i][1] == out[i - 1][1] then return nil, "curve" end    -- two values for one zoom
    end
    return out
end

-- Value of a curve at a camera distance: straight lines between the points, flat beyond the first/last point.
function ns.EvalCurve(curve, zoom)
    local n = #curve
    if n == 0 then return 0 end
    if zoom <= curve[1][1] then return curve[1][2] end
    if zoom >= curve[n][1] then return curve[n][2] end
    for i = 2, n do
        local a, b = curve[i - 1], curve[i]
        if zoom <= b[1] then
            local t = (zoom - a[1]) / (b[1] - a[1])
            return a[2] + (b[2] - a[2]) * t
        end
    end
    return curve[n][2]
end

---------------------------------------------------------------------------
-- Validation
---------------------------------------------------------------------------
-- Returns the normalized value for a setting, or nil and a reason ("range", "type", "curve").
function ns.ValidateValue(s, v)
    if s.kind == "curve" then return ValidateCurve(s, v) end

    if v == "d" then
        if s.api then return nil, "type" end
        return "d"
    end

    if s.kind == "mul" then
        if type(v) ~= "string" then return nil, "type" end
        local m = v:match("^x(%d+%.?%d*)$")
        local n = m and tonumber(m)
        if not isFinite(n) then return nil, "type" end
        if n < s.min or n > s.max then return nil, "range" end
        return "x" .. ns.FormatNumber(n)
    end

    if type(v) ~= "number" and type(v) ~= "string" then return nil, "type" end
    local n = tonumber(v)
    if not isFinite(n) then return nil, "type" end

    if s.kind == "bool" then
        if n ~= 0 and n ~= 1 then return nil, "range" end
        return n
    elseif s.kind == "enum" then
        if n ~= math.floor(n) or n < s.min or n > s.max then return nil, "range" end
        return n
    else
        if n < s.min or n > s.max then return nil, "range" end
        return round(n, 3)
    end
end

-- Clean up a profile name: no control characters or |, collapsed spaces, limited length. Returns nil if empty.
function ns.CleanName(name)
    if type(name) ~= "string" then return nil end
    name = name:gsub("[%c|]", ""):gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
    if #name > ns.MAX_NAME_LENGTH then name = name:sub(1, ns.MAX_NAME_LENGTH):gsub(" $", "") end
    if name == "" then return nil end
    return name
end

-- Validate a whole profile table. Never modifies its input. Returns { name = ..., values = {...} } or nil, reason, key.
function ns.ValidateProfile(p)
    if type(p) ~= "table" or type(p.values) ~= "table" then return nil, "type" end
    local name = ns.CleanName(p.name)
    if not name then return nil, "name" end
    local values, count = {}, 0
    for key, v in pairs(p.values) do
        local s = BY_KEY[key]
        if not s then return nil, "unknown", tostring(key) end
        local clean, why = ns.ValidateValue(s, v)
        if clean == nil then return nil, why or "type", key end
        values[key] = clean
        count = count + 1
    end
    return { name = name, values = values }
end

-- A curve's value in the middle of each zoom view: what the editor's table shows
function ns.ViewValues(curve)
    local out = {}
    for i, view in ipairs(ns.ZOOM_VIEWS) do
        out[i] = round(ns.EvalCurve(curve, (view.from + view.to) / 2), 2)
    end
    return out
end

-- A value as text for the options panel and /ccam describe.
function ns.FormatSettingValue(s, v)
    local L = ns.L
    if v == nil then return s.keepUser and L["your setting"] or L["game default"] end
    if v == "d" then return L["game default"] end
    if s.kind == "bool" then return (v == 1) and L["on"] or L["off"] end
    if s.kind == "enum" then return L[s.values[v - s.min + 1]] or tostring(v) end
    if s.kind == "mul" then return "x" .. v:sub(2) end
    if s.kind == "curve" then
        local parts = {}
        for _, p in ipairs(v) do parts[#parts + 1] = ns.FormatNumber(p[1]) .. ":" .. ns.FormatNumber(p[2]) end
        return table.concat(parts, " ")
    end
    return ns.FormatNumber(v)
end

-- The CVar string a setting value resolves to for one CVar. Returns nil if the game has no default to use.
-- flip: negate the shoulder offset (for players who want the other shoulder).
function ns.ResolveCVar(s, v, cvar, flip)
    if v == nil or v == "d" then
        local d = GetCVarDefault and GetCVarDefault(cvar)
        return d
    end
    if s.kind == "mul" then
        local d = tonumber(GetCVarDefault and GetCVarDefault(cvar))
        if not d then return nil end
        return ns.FormatNumber(d * tonumber(v:sub(2)))
    end
    local n = tonumber(v)
    if flip and s.key == "shoulder" then n = -n end
    return ns.FormatNumber(n)
end
