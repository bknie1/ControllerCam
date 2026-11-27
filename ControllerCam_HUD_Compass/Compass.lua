-- ControllerCam HUD: a compass for questing.
-- A thin strip along the top of the screen (or along the bottom, in the experience bar's place: that bar then
-- goes to the top) shows the way you face, N E S W and the points between, and your quests where they lie:
-- the HUD's gold quest mark for a quest still to do, the game's question mark for one to hand in, and your own
-- map pin, each with how far it is in yards. Marks come in as you turn towards them and fade out at the strip's
-- ends; nearer ones are larger and clearer, and the quest the game points you to (the focused one) has a soft
-- glow and its distance in gold. A focused quest in another zone shows the way the game leads you there.
--
-- Which quests: those in your quest list (the tracked ones) with a place on this map, the nearest C.MAX of them;
-- when none of the quests here is tracked, every quest of yours on this map.
-- The way you face is the game's GetPlayerFacing: your character's facing. This game gives addons no way to read
-- where the camera looks, so the two differ when the camera is turned on its own (the camera addon's "Turn
-- character with camera" keeps them together). Should a build have such a function, it is used (C.Camera), and
-- only then is there a switch for it. Where the game does not say where you are or which way you face
-- (inside a dungeon, or kept secret), on a flight, and while Edit Mode is open, the compass steps away.
--
-- Cost: the quests are looked up every C.LOOK seconds and soon after the game says they changed; in between only
-- your facing (30 times a second) and your place (10 times a second) are read, and the strip is drawn again only
-- when one of them changed or something on it is still fading.
--
-- At the bottom: the game's experience bar (StatusTrackingBarManager, not a protected frame) is moved to the top
-- of the screen while the HUD runs, and only out of combat. The move is never saved: Edit Mode gets the bar back
-- while it is open, and it goes back where the game had it when the compass is off or at the top, or the HUD
-- stops. Nothing is written into the game's frames.

local ADDON = ...
local ns = ControllerCamHUD.ns            -- the HUD's own namespace: this file is one of its modules (Modules.lua)
local L = ns.L

local C = { running = false, want = false, marks = {}, byKey = {}, pool = {}, alpha = 0, width = nil,
            xp = { moved = false } }
ns.Compass = C

ns.RegisterSetting({
    key = "compassPlace", kind = "number", default = 1, min = 1, max = 2, command = "compassplace", section = "Quests",
    choices = { "Top", "Bottom" },
    label = "Quest compass: place",
    tip = "at the top of the screen, or at the bottom in the experience bar's place (the bar then goes to the top)",
})
C.PLACES = { L["Top"], L["Bottom"] }

C.W, C.MIN_W = 360, 220         -- the strip's width; narrower only to stay clear of your buffs
C.SPAN = math.pi                -- the strip covers half the horizon: what is straight beside you is at its end
C.EDGE = 0.25                   -- marks and ticks fade out over this share of each half
C.MAX = 6                       -- quests at most (the focused one always among them)
C.NEAR, C.FAR = 80, 700         -- yards: full strength nearer than NEAR, at its faintest from FAR on
C.FAINT = 0.45
C.ICON, C.ICON_FAR, C.ICON_FOCUS = 15, 11, 17
C.HERE = 12                     -- nearer than this you are there: no number
C.TOP_Y, C.BOTTOM_Y = -8, 1     -- from the top of the screen; from the bottom, in the experience bar's place
C.FIGHT = 0.35                  -- in a fight the strip steps back to this
C.LOOK, C.SOON = 2, 0.25        -- seconds between looks at the quests; after the game says they changed
C.TURN, C.MOVE = 1 / 30, 0.1    -- seconds between reads of your facing; of your place
C.AWAY = 1                      -- while the compass is away: a look this often to see whether it can come back
C.FADE = 0.3                    -- seconds for a mark, or the whole strip, to fade in or out
C.DEMO = 20

-- The points of the compass: degrees anticlockwise from north (the way the game counts your facing)
C.LETTERS = {
    { 0, L["N"], true }, { 45, L["NW"] }, { 90, L["W"], true }, { 135, L["SW"] },
    { 180, L["S"], true }, { 225, L["SE"] }, { 270, L["E"], true }, { 315, L["NE"] },
}

local TAU = 2 * math.pi
local function Clamp01(v) if v < 0 then return 0 elseif v > 1 then return 1 end return v end
local function Wrap(a)                     -- an angle between -pi and pi
    a = a % TAU
    if a > math.pi then a = a - TAU end
    return a
end
local function Num(v)                      -- a number the game says plainly, or nil
    if ns.IsSecret(v) or type(v) ~= "number" or v ~= v then return nil end
    return v
end
local function Calm() return ns.Calm and ns.Calm() or false end

---------------------------------------------------------------------------
-- What the game says: where you are, which way you face, where a place on a map is in the world
---------------------------------------------------------------------------
-- The way the camera looks, where the game says (radians anticlockwise from north, as the character's facing
-- is): the first of these names the game has, as a function of its own or of C_Camera. Looked for once.
C.CAMERA_NAMES = { "GetCameraYaw", "GetCameraFacing", "GetCameraHeading", "GetCameraAngle" }
function C.Camera()
    if C.cam ~= nil then return C.cam or nil end
    C.cam = false
    local lib = rawget(_G, "C_Camera")
    for _, name in ipairs(C.CAMERA_NAMES) do
        local fn = rawget(_G, name)
        if type(fn) ~= "function" and type(lib) == "table" then fn = rawget(lib, name) end
        if type(fn) == "function" then C.cam = { name = name, fn = fn }; break end
    end
    return C.cam or nil
end

if C.Camera() then              -- a switch only where it can do something
    ns.RegisterSetting({
        key = "compassCamera", kind = "boolean", default = true, command = "compasscamera", section = "Quests",
        label = "Quest compass: follows the camera",
        tip = "the compass shows the way the camera looks, not the way your character faces (they differ when the stick turns your character without the camera); off: the way your character faces",
    })
end

-- What the game has with "Camera" in its name (for the debug report: to find the right one where none matched)
function C.CameraNames()
    local found = {}
    local function Scan(t, prefix)
        if type(t) ~= "table" then return end
        for k, v in pairs(t) do
            if type(k) == "string" and type(v) == "function" and k:find("Camera") and not k:find("^Camera[A-Z]") then
                found[#found + 1] = prefix .. k
            end
        end
    end
    Scan(_G, "")
    Scan(rawget(_G, "C_Camera"), "C_Camera.")
    table.sort(found)
    while #found > 24 do table.remove(found) end
    return found
end

function C.Facing()
    if ns.db and ns.db.compassCamera ~= false then
        local cam = C.Camera()
        if cam then
            local okC, v = pcall(cam.fn)
            v = okC and Num(v) or nil
            if v then return v end
        end
    end
    if type(GetPlayerFacing) ~= "function" then return nil end
    local ok, f = pcall(GetPlayerFacing)
    return ok and Num(f) or nil
end

local function XY(pos)
    if type(pos) ~= "table" then return nil end
    local ok, x, y
    if pos.GetXY then ok, x, y = pcall(pos.GetXY, pos) else ok, x, y = true, pos.x, pos.y end
    if not ok then return nil end
    return Num(x), Num(y)
end

-- A place on a map in yards: its continent (or the map, when only the map's size is known), north, west
function C.World(map, x, y)
    if not (map and x and y) then return nil end
    local get, vec = C_Map and C_Map.GetWorldPosFromMapPos, CreateVector2D
    if get and vec then
        local ok, cont, pos = pcall(get, map, vec(x, y))
        if ok and Num(cont) then
            local n, w = XY(pos)
            if n and w then return cont, n, w end
        end
    end
    local size = C_Map and C_Map.GetMapWorldSize
    if size then
        local ok, w, h = pcall(size, map)
        w, h = ok and Num(w), ok and Num(h)
        if w and h and w > 0 and h > 0 then return "map" .. tostring(map), -y * h, -x * w end
    end
    return nil
end

-- Where you are: { map =, cont =, n =, w = }, or nil when the game does not say
function C.Where()
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return nil end
    local ok, map = pcall(C_Map.GetBestMapForUnit, "player")
    map = ok and Num(map) or nil
    if not map then return nil end
    local okP, pos = pcall(C_Map.GetPlayerMapPosition, map, "player")      -- nil in instances that hide it
    if not okP then return nil end
    local x, y = XY(pos)
    if not x or (x == 0 and y == 0) then return nil end
    local cont, n, w = C.World(map, x, y)
    if not cont then return nil end
    return { map = map, cont = cont, n = n, w = w }
end

local function Ask(name, ...)
    local fn = C_QuestLog and C_QuestLog[name]
    if not fn then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if not ok or ns.IsSecret(a) then return nil end
    return a, b, c
end

local function Taxi()
    if not UnitOnTaxi then return false end
    local ok, v = pcall(UnitOnTaxi, "player")
    return ok and ns.Yes(v)
end

---------------------------------------------------------------------------
-- The marks: what goes on the strip
---------------------------------------------------------------------------
local function Far(here, m) return math.sqrt((m.n - here.n) ^ 2 + (m.w - here.w) ^ 2) end

-- The quests of this map (and the focused one, wherever it is), your map pin, and the demo's marks
function C.Gather(here)
    local found = {}
    local map = here.map
    local focus = ns.Quests and ns.Quests.Focused and ns.Quests.Focused() or nil
    local rows, had, tracked = {}, {}, false
    local list = Ask("GetQuestsOnMap", map)
    for _, q in ipairs(type(list) == "table" and list or {}) do
        local id, x, y = Num(q.questID), Num(q.x), Num(q.y)
        if id and x and y and Ask("IsOnQuest", id) ~= false and not had[id] then
            local watched = Ask("GetQuestWatchType", id) ~= nil
            tracked = tracked or watched
            had[id] = true
            rows[#rows + 1] = { id = id, x = x, y = y, watched = watched }
        end
    end
    local seen = {}
    for _, r in ipairs(rows) do
        if r.watched or not tracked or r.id == focus then
            local cont, n, w = C.World(map, r.x, r.y)
            if cont then
                local done = Ask("ReadyForTurnIn", r.id) == true or Ask("IsComplete", r.id) == true
                found[#found + 1] = { key = "q" .. r.id, id = r.id, kind = done and "turnin" or "quest",
                                      focus = r.id == focus, cont = cont, n = n, w = w }
                seen[r.id] = true
            end
        end
    end
    -- the focused quest is not here: the way the game leads you to it (to the edge of the zone, a boat, a flight)
    if focus and not seen[focus] then
        local x, y = Ask("GetNextWaypointForMap", focus, map)
        local cont, n, w
        if Num(x) and Num(y) then cont, n, w = C.World(map, x, y) end
        if not cont then
            local wmap, wx, wy = Ask("GetNextWaypoint", focus)
            if Num(wmap) and Num(wx) and Num(wy) then cont, n, w = C.World(wmap, wx, wy) end
        end
        if cont then
            local done = Ask("ReadyForTurnIn", focus) == true
            found[#found + 1] = { key = "q" .. focus, id = focus, kind = done and "turnin" or "quest", focus = true,
                                  way = true, cont = cont, n = n, w = w }
        end
    end
    -- the quests: the focused one first, then the nearest, no more than C.MAX
    for _, m in ipairs(found) do m.far = m.cont == here.cont and Far(here, m) or 1e9 end
    table.sort(found, function(a, b)
        if a.focus ~= b.focus then return a.focus end
        return a.far < b.far
    end)
    for i = #found, C.MAX + 1, -1 do found[i] = nil end
    -- your own pin on the map
    local hasPin = C_Map and C_Map.HasUserWaypoint
    local okH, has = false, false
    if hasPin then okH, has = pcall(hasPin) end
    if okH and ns.Yes(has) and C_Map.GetUserWaypoint then
        local ok, point = pcall(C_Map.GetUserWaypoint)
        if ok and type(point) == "table" then
            local x, y = XY(point.position)
            local cont, n, w = C.World(Num(point.uiMapID), x, y)
            if cont then
                local tracked = C_SuperTrack and C_SuperTrack.IsSuperTrackingUserWaypoint
                local okT, on = false, false
                if tracked then okT, on = pcall(tracked) end
                found[#found + 1] = { key = "pin", kind = "pin", focus = okT and ns.Yes(on), cont = cont, n = n, w = w }
            end
        end
    end
    if C.demo and GetTime() < C.demo.ends then
        for _, m in ipairs(C.demo.marks) do found[#found + 1] = m end
    elseif C.demo then
        C.demo = nil
    end
    return found
end

-- What was found becomes the marks drawn: new ones fade in, gone ones fade out
function C.Take(found)
    local fresh, changed = {}, false
    for _, f in ipairs(found) do
        local m = C.byKey[f.key]
        if not m then
            m = { vis = 0 }
            C.byKey[f.key] = m
            C.marks[#C.marks + 1] = m
            changed = true
        end
        f.focus, f.way = f.focus and true or false, f.way and true or false
        if m.kind ~= f.kind or m.focus ~= f.focus or m.n ~= f.n or m.w ~= f.w or not m.want then changed = true end
        for k, v in pairs(f) do m[k] = v end
        m.want = true
        fresh[f.key] = true
    end
    for _, m in ipairs(C.marks) do
        if not fresh[m.key] and m.want then m.want, changed = false, true end
    end
    if changed then C.lastFacing = nil end              -- (drawn again)
    return changed
end

---------------------------------------------------------------------------
-- The strip
---------------------------------------------------------------------------
local frame
local driver = CreateFrame("Frame")       -- (always shown: the strip itself may be hidden)

local function HasAtlas(name)
    local get = C_Texture and C_Texture.GetAtlasInfo
    if not get then return false end
    local ok, info = pcall(get, name)
    return ok and type(info) == "table"
end

-- How each kind of mark looks: the game's own art where this client has it, the HUD's otherwise
function C.Art(kind)
    C.art = C.art or {}
    if C.art[kind] then return C.art[kind] end
    local a
    if kind == "turnin" then
        a = HasAtlas("QuestTurnin") and { atlas = "QuestTurnin" } or { file = ns.media.quest, tint = { 0.6, 1, 0.55 } }
    elseif kind == "pin" then
        a = HasAtlas("Waypoint-MapPin-Tracked") and { atlas = "Waypoint-MapPin-Tracked" }
            or { file = ns.media.mark, tint = { 0.55, 0.8, 1 } }
    else
        a = { file = ns.media.quest }
    end
    C.art[kind] = a
    return a
end

local function Build()
    frame = CreateFrame("Frame", "ControllerCamHUD_Compass", UIParent)
    frame:SetFrameStrata("LOW")
    frame:Hide()
    frame:SetAlpha(0)
    frame.back = frame:CreateTexture(nil, "BACKGROUND")
    frame.back:SetTexture(ns.media.soft)
    frame.back:SetVertexColor(0, 0, 0, 0.42)
    frame.notch = frame:CreateTexture(nil, "ARTWORK")       -- where you face
    frame.notch:SetColorTexture(1, 0.82, 0.3, 0.9)
    C.ticks = {}
    for deg = 15, 345, 15 do
        if deg % 45 ~= 0 then
            local t = frame:CreateTexture(nil, "ARTWORK")
            t:SetColorTexture(0.86, 0.89, 0.96, 1)
            C.ticks[#C.ticks + 1] = { angle = math.rad(deg), tex = t }
        end
    end
    C.letters = {}
    for _, l in ipairs(C.LETTERS) do
        local fs = ns.FontString(frame, l[3] and 10 or 8, "CENTER")
        if fs.SetDrawLayer then pcall(fs.SetDrawLayer, fs, "ARTWORK") end     -- (under the marks)
        fs:SetText(l[2])
        if l[1] == 0 then fs:SetTextColor(unpack(ns.colors.caution))
        elseif not l[3] then fs:SetTextColor(unpack(ns.colors.muted)) end
        C.letters[#C.letters + 1] = { angle = math.rad(l[1]), fs = fs, main = l[3] and true or false }
    end
    C.frame = frame
end

local function Widget(i)
    local w = C.pool[i]
    if w then return w end
    w = {}
    w.glow = frame:CreateTexture(nil, "OVERLAY")
    w.glow:SetTexture(ns.media.halo)
    w.glow:SetVertexColor(1, 0.8, 0.3, 1)
    w.icon = frame:CreateTexture(nil, "OVERLAY")
    w.label = ns.FontString(frame, 8, "CENTER")
    C.pool[i] = w
    return w
end

local function HideWidget(w)
    w.icon:Hide(); w.glow:Hide(); w.label:Hide()
end

-- The heights of the strip at the text size in use: the band (letters, ticks, marks) and the line of distances
function C.Metrics()
    local ts = ns.db and ns.db.textScale or 1
    return math.floor(math.max(C.ICON_FOCUS + 1, 10 * ts + 3) + 0.5), math.floor(8 * ts + 2 + 0.5)
end

-- At the top: under the game's widgets of the top middle (a battleground's score, an event's bar) when they show
function C.TopY()
    local wf = _G.UIWidgetTopCenterContainerFrame
    if type(wf) == "table" and wf.IsShown and wf.GetHeight then
        local okS, shown = pcall(wf.IsShown, wf)
        local okH, h = pcall(wf.GetHeight, wf)
        h = okH and Num(h)
        if okS and ns.Yes(shown) and h and h > 4 then
            local okP, _, _, _, _, y = pcall(wf.GetPoint, wf, 1)
            y = okP and Num(y) or -15
            return math.min(C.TOP_Y, y - h - 4)
        end
    end
    return C.TOP_Y
end

-- As wide as it can be while staying clear of your buffs (they grow leftwards from the top right)
function C.Clear()
    if not C.top then return C.W end
    local box = _G.BuffFrame
    box = type(box) == "table" and (rawget(box, "AuraContainer") or box) or nil
    if not (box and box.GetChildren and UIParent.GetWidth and UIParent.GetEffectiveScale) then return C.W end
    local okW, sw = pcall(UIParent.GetWidth, UIParent)
    local okU, ui = pcall(UIParent.GetEffectiveScale, UIParent)
    sw, ui = okW and Num(sw), okU and Num(ui)
    if not (sw and ui and sw > 0 and ui > 0) then return C.W end
    local okK, kids = pcall(function() return { box:GetChildren() } end)
    local left
    for _, k in ipairs(okK and kids or {}) do
        local ok, l, shown, sc = pcall(function() return k:GetLeft(), k:IsShown(), k:GetEffectiveScale() end)
        l, sc = ok and Num(l), ok and Num(sc)
        if l and sc and ns.Yes(shown) then
            l = l * sc / ui
            if not left or l < left then left = l end
        end
    end
    if not left then return C.W end
    return math.max(C.MIN_W, math.min(C.W, 2 * (left - sw / 2 - 16)))
end

-- The strip's size for its width
local function Size(w)
    frame:SetSize(w, C.bandH + C.labelH + 2)
    frame.back:SetSize(w + 70, C.bandH + 12)
end

-- Where the strip sits, and where its band runs
function C.Place()
    if not frame then return end
    C.bandH, C.labelH = C.Metrics()
    -- (a change of place in a fight waits for it to end, with the experience bar)
    if C.placeAt == nil or not InCombatLockdown() then C.placeAt = ns.db.compassPlace or 1 end
    C.top = C.placeAt ~= 2
    local shape = ("%s %d %d"):format(tostring(C.top), C.bandH, C.labelH)
    if shape ~= C.shape then C.shape, C.lastFacing = shape, nil end        -- (drawn again in its new shape)
    C.width = C.width or C.W
    C.edge, C.sign = C.top and "TOP" or "BOTTOM", C.top and -1 or 1
    C.mid = C.sign * C.bandH / 2                       -- the band's middle, from the strip's outer edge
    Size(C.width)
    frame:ClearAllPoints()
    if C.top then frame:SetPoint("TOP", UIParent, "TOP", 0, C.TopY())
    else frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, C.BOTTOM_Y) end
    frame.back:ClearAllPoints()
    frame.back:SetPoint("CENTER", frame, C.edge, 0, C.mid)
    frame.notch:ClearAllPoints()
    frame.notch:SetSize(2, 5)
    frame.notch:SetPoint("CENTER", frame, C.edge, 0, C.sign * 2.5)
    for _, t in ipairs(C.ticks) do t.tex:SetSize(1, 5) end
end

-- Where an angle (from where you face, anticlockwise) lands on the strip, or nil when it is behind you
local function X(rel, half)
    rel = Wrap(rel)
    if math.abs(rel) > C.SPAN / 2 then return nil end
    return -rel / (C.SPAN / 2) * half
end
local function EdgeAlpha(x, half) return Clamp01((half - math.abs(x)) / (half * C.EDGE)) end

local function At(region, x, y)
    region:ClearAllPoints()
    region:SetPoint("CENTER", frame, C.edge, x, y)
end

-- A distance as it is said: to the yard when near, to ten yards further off
function C.Yards(d)
    if d < C.HERE then return "" end
    local n = d < 100 and math.floor(d + 0.5) or math.floor(d / 10 + 0.5) * 10
    return L["%d yd"]:format(n)
end

local function TextWidth(fs, text)
    if fs.GetStringWidth then
        local ok, w = pcall(fs.GetStringWidth, fs)
        if ok and Num(w) and w > 0 then return w end
    end
    return #text * 5.5 * (ns.db and ns.db.textScale or 1)
end

-- Draws the strip for the way you face
function C.Draw(facing, dt)
    local half = C.width / 2
    local here = C.here
    local step = Calm() and 1 or Clamp01(dt / C.FADE)
    C.busy = false
    for _, t in ipairs(C.ticks) do
        local x = X(t.angle - facing, half)
        if x then
            At(t.tex, x, C.mid)
            t.tex:SetAlpha(0.4 * EdgeAlpha(x, half))
            t.tex:Show()
        else
            t.tex:Hide()
        end
    end
    -- the marks
    local shown, n = {}, 0
    local i = 1
    while i <= #C.marks do
        local m = C.marks[i]
        local target = m.want and 1 or 0
        if m.vis ~= target then
            m.vis = m.vis + (target > m.vis and step or -step)
            m.vis = Clamp01(m.vis)
            if math.abs(m.vis - target) < 1e-3 then m.vis = target end
            if m.vis ~= target then C.busy = true end
        end
        if m.vis <= 0 and not m.want then
            C.byKey[m.key] = nil
            table.remove(C.marks, i)
        else
            n = n + 1
            local w = Widget(n)
            local x = here and m.cont == here.cont and X(math.atan2(m.w - here.w, m.n - here.n) - facing, half)
            if x then
                local d = Far(here, m)
                m.far = d
                local t = Clamp01((d - C.NEAR) / (C.FAR - C.NEAR))
                local a = 1 - t * (1 - C.FAINT)
                local size = C.ICON - t * (C.ICON - C.ICON_FAR)
                if m.focus then a, size = math.max(a, 0.9), C.ICON_FOCUS end
                a = a * EdgeAlpha(x, half) * m.vis
                if w.kind ~= m.kind then
                    local art = C.Art(m.kind)
                    if art.atlas and w.icon.SetAtlas then w.icon:SetAtlas(art.atlas) else w.icon:SetTexture(art.file) end
                    local c = art.tint or { 1, 1, 1 }
                    w.icon:SetVertexColor(c[1], c[2], c[3], 1)
                    w.kind = m.kind
                end
                w.icon:SetSize(size, size)
                At(w.icon, x, C.mid)
                w.icon:SetAlpha(a)
                w.icon:Show()
                if m.focus then
                    w.glow:SetSize(size * 2.4, size * 2.4)
                    At(w.glow, x, C.mid)
                    w.glow:SetAlpha(0.5 * a)
                    w.glow:Show()
                else
                    w.glow:Hide()
                end
                local text = C.Yards(d)
                if w.text ~= text then w.label:SetText(text); w.text = text end
                if m.focus then w.label:SetTextColor(unpack(ns.colors.caution))
                else w.label:SetTextColor(unpack(ns.colors.text)) end
                w.label:ClearAllPoints()
                w.label:SetPoint(C.top and "TOP" or "BOTTOM", frame, C.edge, x, C.sign * (C.bandH + 1))
                w.label:SetAlpha(a)
                shown[#shown + 1] = { w = w, m = m, x = x, a = a, text = text }
            else
                HideWidget(w)
            end
            i = i + 1
        end
    end
    for j = n + 1, #C.pool do HideWidget(C.pool[j]) end
    -- one distance where two would overlap: the focused quest's, then the nearest
    table.sort(shown, function(a, b)
        if a.m.focus ~= b.m.focus then return a.m.focus end
        return a.m.far < b.m.far
    end)
    local spans = {}
    for _, s in ipairs(shown) do
        local free = s.text ~= ""
        if free then
            local half_w = TextWidth(s.w.label, s.text) / 2 + 4
            for _, sp in ipairs(spans) do
                if math.abs(s.x - sp[1]) < half_w + sp[2] then free = false; break end
            end
            if free then spans[#spans + 1] = { s.x, half_w } end
        end
        if free then s.w.label:Show() else s.w.label:Hide() end
    end
    -- the letters, stepping back where a mark sits on one
    for _, l in ipairs(C.letters) do
        local x = X(l.angle - facing, half)
        if x then
            local a = EdgeAlpha(x, half) * (l.main and 1 or 0.85)
            for _, s in ipairs(shown) do
                if s.a > 0.3 and math.abs(s.x - x) < 11 then a = a * 0.25; break end
            end
            At(l.fs, x, C.mid)
            l.fs:SetAlpha(a)
            l.fs:Show()
        else
            l.fs:Hide()
        end
    end
    C.drawn = (C.drawn or 0) + 1
    C.shownMarks = shown
end

---------------------------------------------------------------------------
-- The experience bar, at the top while the compass has its place
---------------------------------------------------------------------------
local function Manager()
    local m = _G.StatusTrackingBarManager
    if type(m) == "table" and m.ClearAllPoints and m.SetPoint and m.GetPoint then return m end
    return nil
end

-- How far the bars stand out above the manager (a second bar, reputation say, sits on top of the first)
function C.XPLift(m)
    local s = rawget(m, "SecondaryStatusTrackingBarContainer") or _G.SecondaryStatusTrackingBarContainer
    if type(s) ~= "table" or not (s.IsShown and s.GetTop and m.GetTop) then return 0 end
    local ok, shown, top, mtop = pcall(function() return s:IsShown(), s:GetTop(), m:GetTop() end)
    top, mtop = ok and Num(top), ok and Num(mtop)
    if not (ns.Yes(shown) and top and mtop and top > mtop) then return 0 end
    return math.floor(top - mtop + 0.5)
end

function C.MoveXP()
    local m = Manager()
    if not m or InCombatLockdown() then return false end
    local y = -C.XPLift(m)
    if C.xp.moved and C.xp.y == y then
        local ok, point, _, _, _, py = pcall(m.GetPoint, m, 1)
        if ok and point == "TOP" and Num(py) == y then return true end        -- (still where we put it)
    end
    if not C.xp.saved then
        C.xp.saved = {}
        for i = 1, (m.GetNumPoints and m:GetNumPoints() or 0) do C.xp.saved[i] = { m:GetPoint(i) } end
    end
    m:ClearAllPoints()                                 -- (not an Edit Mode frame: its plain methods)
    m:SetPoint("TOP", UIParent, "TOP", 0, y)
    C.xp.moved, C.xp.y = true, y
    ns.Note("compass: the experience bar at the top (%d)", y)
    return true
end

function C.RestoreXP()
    local m = Manager()
    if not (m and C.xp.moved) or InCombatLockdown() then return false end
    m:ClearAllPoints()
    for _, pt in ipairs(C.xp.saved or {}) do m:SetPoint(unpack(pt)) end
    C.xp.moved, C.xp.saved, C.xp.y = false, nil, nil
    ns.Note("compass: the experience bar given back")
    return true
end

function C.XPWanted()
    return C.running and ns.db.compass and ns.db.compassPlace == 2 and not ns.arranging or false
end

function C.KeepXP()
    if C.XPWanted() then C.MoveXP() elseif C.xp.moved then C.RestoreXP() end
end

---------------------------------------------------------------------------
-- When it shows, and the clock
---------------------------------------------------------------------------
-- Why the compass is away (nil when it shows)
function C.Away()
    if ns.arranging then return "edit mode" end
    if Taxi() then return "flight" end
    if not C.here then return "no place" end
    if not C.Facing() then return "no facing" end
    return nil
end

-- A look at everything that changes slowly: the quests, where the strip sits, the experience bar
function C.Look()
    C.dirty, C.sinceLook = false, 0
    C.here = C.Where()
    C.why = C.Away()
    C.want = C.why == nil
    if C.want then
        if not frame:IsShown() then
            frame:Show()
            C.lastFacing = nil
        end
        C.Take(C.Gather(C.here))
        C.Place()
        C.target = C.Clear()
    elseif C.alpha <= 0 then
        frame:Hide()
    end
    C.KeepXP()
end

local since, sinceMove = 0, 0
local function Tick(_, dt)
    since, sinceMove = since + dt, sinceMove + dt
    C.sinceLook = (C.sinceLook or 0) + dt
    if C.sinceLook >= (C.want and C.LOOK or C.AWAY) or (C.dirty and C.sinceLook >= C.SOON) then C.Look() end
    if since < C.TURN then return end
    local step = since
    since = 0
    if C.buffs and C.want then                         -- (your buffs changed: the strip stays clear of them)
        C.buffs = false
        C.target = C.Clear()
    end
    -- the whole strip: in, out, and back a little in a fight
    local aim = C.want and (C.fight and C.FIGHT or 1) or 0
    if C.alpha ~= aim then
        local k = Calm() and 1 or Clamp01(step / C.FADE)
        C.alpha = C.alpha + (aim > C.alpha and math.min(k, aim - C.alpha) or -math.min(k, C.alpha - aim))
        frame:SetAlpha(C.alpha)
        if C.alpha <= 0 and not C.want then frame:Hide() end
    end
    if not C.want then return end
    local facing = C.Facing()
    if not facing then C.Look(); return end
    local redraw = C.busy or not C.lastFacing or math.abs(Wrap(facing - C.lastFacing)) > 0.002
    if sinceMove >= C.MOVE then
        sinceMove = 0
        local here = C.Where()
        if not here then C.Look(); return end
        if not C.here or here.cont ~= C.here.cont or math.abs(here.n - C.here.n) + math.abs(here.w - C.here.w) > 0.05 then
            redraw = true
        end
        C.here = here
    end
    if C.target and C.width ~= C.target then           -- (narrower or wider for your buffs, smoothly)
        local k = Calm() and 1e9 or step * 400
        C.width = C.width < C.target and math.min(C.target, C.width + k) or math.max(C.target, C.width - k)
        Size(C.width)
        redraw = true
    end
    if redraw then
        C.lastFacing = facing
        C.Draw(facing, step)
    end
end

local events = CreateFrame("Frame")
local EVENTS = { "QUEST_LOG_UPDATE", "QUEST_WATCH_LIST_CHANGED", "SUPER_TRACKING_CHANGED", "ZONE_CHANGED",
                 "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED_INDOORS", "PLAYER_ENTERING_WORLD", "USER_WAYPOINT_UPDATED",
                 "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }
events:SetScript("OnEvent", ns.Protect(function(_, event, unit)
    if event == "PLAYER_REGEN_DISABLED" then
        C.fight = true
    elseif event == "PLAYER_REGEN_ENABLED" then
        C.fight = false
        C.KeepXP()                                      -- (a change of the bars waited for the fight to end)
        C.dirty = true
    elseif event == "UNIT_AURA" then
        if unit == "player" then C.buffs = true end
    else
        C.dirty = true
    end
end))

function C:Apply(run)
    local want = run and ns.db.compass and true or false
    if want then
        if not frame then Build() end
        if not self.running then
            for _, e in ipairs(EVENTS) do pcall(events.RegisterEvent, events, e) end
            if events.RegisterUnitEvent then pcall(events.RegisterUnitEvent, events, "UNIT_AURA", "player") end
            driver:SetScript("OnUpdate", ns.Protect(Tick))
        end
        self.running = true
        self.fight = InCombatLockdown() and true or false
        self.width = nil
        self:Look()
        if C.want then C.width = C.target or C.W; Size(C.width) end
    elseif self.running then
        self.running, self.want = false, false
        events:UnregisterAllEvents()
        driver:SetScript("OnUpdate", nil)
        if frame then frame:Hide(); frame:SetAlpha(0) end
        self.alpha = 0
        self.marks, self.byKey, self.demo = {}, {}, nil
        for _, w in ipairs(self.pool) do HideWidget(w) end
    end
    self.KeepXP()
    if not self.listed and ns.Debug and type(ns.Debug.SECTIONS) == "table" then      -- (in the debug reports)
        self.listed = true
        table.insert(ns.Debug.SECTIONS, { "compass", function() return { C.Describe() } end })
    end
end

---------------------------------------------------------------------------
-- A look at it, the self-check and the debug report
---------------------------------------------------------------------------
-- A few marks around you for a while: one ahead to the left (the focused quest), one to hand in to the right,
-- one far off to the left
function C.Demo()
    if not C.running then ns.Say(L["The quest compass is off: /cchud compass on"]); return false end
    local here, facing = C.Where(), C.Facing()
    if not (here and facing) then ns.Say(L["The compass needs to know where you are, and the game does not say it here."]); return false end
    local function Mark(key, kind, rel, d, focus)
        local a = facing + math.rad(rel)
        return { key = "demo" .. key, kind = kind, focus = focus, cont = here.cont,
                 n = here.n + d * math.cos(a), w = here.w + d * math.sin(a) }
    end
    C.demo = { ends = GetTime() + C.DEMO, marks = {
        Mark(1, "quest", 25, 140, true), Mark(2, "turnin", -55, 380, false), Mark(3, "quest", 70, 650, false),
        Mark(4, "pin", -15, 60, false),
    } }
    C.Look()
    return true
end
ns.RegisterCommand("compassdemo", function() C.Demo() end, "/cchud compassdemo",
    "a few marks on the quest compass, around you, for twenty seconds")

function C.Describe()
    local q, done, pins = 0, 0, 0
    for _, m in ipairs(C.marks) do
        if m.want then
            if m.kind == "pin" then pins = pins + 1 elseif m.kind == "turnin" then done = done + 1 else q = q + 1 end
        end
    end
    local focus = ns.Quests and ns.Quests.Focused and ns.Quests.Focused()
    local cam = C.Camera()
    local okP, player = pcall(GetPlayerFacing or function() end)
    local names = table.concat(C.CameraNames(), " ")
    local source = "none to read in this game, so the character's facing"
    if cam then source = cam.name .. ((ns.db and ns.db.compassCamera ~= false) and " (followed)" or " (not followed)") end
    return ("camera: %s, the character %s; names with Camera: %s\n"):format(
        source,
        tostring(okP and Num(player) and ("%.2f"):format(Num(player)) or "-"), names ~= "" and names or "-")
        .. ("compass on %s, at the %s, shown %s%s, width %d, marks: %d quests, %d to hand in, %d pins, focus %s, facing %s, drawn %d, experience bar moved %s"):format(
        tostring(C.running), (ns.db and ns.db.compassPlace == 2) and "bottom" or "top", tostring(C.want),
        C.why and (" (away: " .. C.why .. ")") or "", math.floor(C.width or 0), q, done, pins, tostring(focus),
        tostring(C.Facing() and ("%.2f"):format(C.Facing()) or "-"), C.drawn or 0, tostring(C.xp.moved))
end

ns.RegisterCheck(function(row, run, db)
    if run and db.compass then
        row("the quest compass runs", C.running)
        row("the quest compass shows exactly when it can", (frame and frame:IsShown() and true or false) == (C.want or C.alpha > 0))
        if Manager() and not InCombatLockdown() then
            row("the experience bar is where the compass leaves it", C.xp.moved == C.XPWanted())
        end
    else
        row("the quest compass is off", not C.running and not (frame and frame:IsShown()))
        row("the experience bar is where the game put it", not C.xp.moved)
    end
end)

ns.RegisterModule("compass", C)
