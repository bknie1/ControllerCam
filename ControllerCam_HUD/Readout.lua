-- ControllerCam HUD: the moment, spelled out across the screen.
--   * Buffs the world gives you (a camp you rested at, a shrine, an innkeeper: buffs from nobody in your group
--     and not from yourself): their icons and names sweep in across the upper middle of the screen one after
--     another, warm, with embers rising off them; they hold a beat and drift on out.
--   * A catch: the fish washes in like a wave, with its weight and "new!" or "best!" under it. Rings spread on
--     the water from its icon, drops leap and fall back, and the whole line rocks gently before it ebbs away.
-- With Reduce animations on (your switch, or the game's own motion settings asking for it) the same words fade in
-- and out where they stand, with nothing moving.

local ADDON, ns = ...
local L, C = ns.L, ns.colors

local R = { queue = {}, shown = 0 }
ns.Readout = R

ns.RegisterSetting({
    key = "readouts", kind = "boolean", default = true, command = "readouts", section = "Effects",
    label = "Catches and camp buffs across the screen",
    tip = "the fish you land, and the buffs a camp or a shrine gives you, are announced across the upper middle of the screen: a catch washes in like a wave, buffs sweep in with embers",
})
ns.RegisterSetting({
    key = "reduceMotion", kind = "boolean", default = false, command = "reducemotion", section = "Accessibility",
    label = "Reduce animations",
    tip = "nothing on the screen shakes, sweeps, flies or bursts: cast bar animations, hit effects, nameplate motion, big moments and the readouts of catches and buffs are calm or still. The game's own settings for screen shake and unexpected camera movement count too",
})

---------------------------------------------------------------------------
-- Fewer animations: your switch, or the game's own motion settings where this game has them
---------------------------------------------------------------------------
-- { the game's setting, the value that asks for calm }
ns.CALM_CVARS = { { "cameraReduceUnexpectedMovement", 1 }, { "ShakeStrengthUI", 0 }, { "reduceMotion", 1 },
                  { "ReduceMotion", 1 } }
local calmAt, calm, calmWhy = -10, false, nil
function ns.Calm()
    if ns.db and ns.db.reduceMotion then return true, "Reduce animations" end
    local now = GetTime and GetTime() or 0
    if now - calmAt < 2 then return calm, calmWhy end
    calmAt, calm, calmWhy = now, false, nil
    if GetCVar then
        for _, c in ipairs(ns.CALM_CVARS) do
            local ok, v = pcall(GetCVar, c[1])
            if ok and v ~= nil and not ns.IsSecret(v) and tonumber(v) == c[2] then
                calm, calmWhy = true, c[1]
                break
            end
        end
    end
    return calm, calmWhy
end
function ns.CalmAgain() calmAt = -10 end          -- (settings changed: looked at again at once)

---------------------------------------------------------------------------
-- The frame
---------------------------------------------------------------------------
R.ROWS, R.Y = 5, 190
R.IN, R.HOLD, R.OUT, R.ROW_HOLD = 0.6, 2.6, 0.7, 0.35
R.TRAVEL = 260                    -- how far it sweeps in from, and on out to
R.STYLES = {
    fish = { color = { 0.62, 0.88, 1 }, sub = { 0.80, 0.94, 1 } },
    camp = { color = { 1, 0.80, 0.48 }, sub = { 1, 0.90, 0.72 } },
}
local DROPS, EMBERS, RINGS = 8, 9, 3
local frame

local function Piece(tex, blend, layer)
    local t = frame:CreateTexture(nil, layer or "ARTWORK")
    t:SetTexture(ns.media[tex])
    t:SetBlendMode(blend or "BLEND")
    t:SetAlpha(0)
    return t
end

local function Build()
    frame = CreateFrame("Frame", "ControllerCamHUD_Readout", UIParent)
    frame:SetSize(420, 60)
    frame:SetFrameStrata("HIGH")
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, R.Y)
    frame.band = Piece("soft", "BLEND", "BACKGROUND")            -- a soft shade the words sit on
    frame.band:SetVertexColor(0, 0, 0, 1)
    frame.glow = Piece("soft", "ADD", "BACKGROUND")               -- the water's light, or the fire's
    frame.icon = frame:CreateTexture(nil, "ARTWORK", nil, 2)
    frame.icon:SetSize(40, 40)
    frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    frame.title = ns.FontString(frame, 20, "LEFT")
    frame.sub = ns.FontString(frame, 12, "LEFT")
    frame.rows = {}
    for i = 1, R.ROWS do
        local r = { icon = frame:CreateTexture(nil, "ARTWORK", nil, 2), text = ns.FontString(frame, 13, "LEFT") }
        r.icon:SetSize(22, 22)
        r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        frame.rows[i] = r
    end
    frame.rings, frame.drops, frame.embers = {}, {}, {}
    for i = 1, RINGS do frame.rings[i] = Piece("ring", "ADD") end
    for i = 1, DROPS do frame.drops[i] = Piece("soft", "ADD", "OVERLAY") end
    for i = 1, EMBERS do frame.embers[i] = Piece("spark", "ADD", "OVERLAY") end
    frame:Hide()
    R.frame = frame
end

local function Ease(k) k = math.max(0, math.min(1, k)); return 1 - (1 - k) * (1 - k) * (1 - k) end
local function Clamp01(k) return math.max(0, math.min(1, k)) end
-- The same "chance" every time for piece i, so pieces scatter without a dice roll per frame
local function Scatter(i, salt)
    local v = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453
    return v - math.floor(v)
end

-- Lays the words out for one readout (the frame's size follows them)
local function Lay(m)
    local s = R.STYLES[m.kind]
    local hasIcon = m.icon ~= nil
    if hasIcon then frame.icon:SetTexture(m.icon); frame.icon:Show() else frame.icon:Hide() end
    frame.title:ClearAllPoints()
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", hasIcon and 52 or 12, -6)
    frame.title:SetText(m.title or "")
    frame.title:SetTextColor(unpack(m.titleColor or s.color))
    frame.sub:ClearAllPoints()
    frame.sub:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -3)
    frame.sub:SetText(m.sub or "")
    frame.sub:SetTextColor(unpack(s.sub))
    if hasIcon then
        frame.icon:ClearAllPoints()
        frame.icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -4)
    end
    local rows = m.rows or {}
    for i, r in ipairs(frame.rows) do
        local row = rows[i]
        if row then
            r.icon:SetTexture(row.icon)
            r.icon:Show()
            r.text:SetText(row.text)
            r.text:SetTextColor(unpack(s.sub))
            r.text:Show()
        else
            r.icon:Hide()
            r.text:Hide()
        end
    end
    m.nrows = math.min(#rows, R.ROWS)
    local top = (m.sub and m.sub ~= "") and 52 or 34
    frame:SetHeight(top + m.nrows * 26 + 6)
    frame.band:ClearAllPoints()
    frame.band:SetPoint("TOPLEFT", frame, "TOPLEFT", -80, 18)
    frame.band:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 80, -18)
    frame.glow:ClearAllPoints()
    frame.glow:SetPoint("CENTER", frame, hasIcon and "TOPLEFT" or "CENTER", hasIcon and 26 or 0, hasIcon and -24 or 0)
    frame.glow:SetSize(hasIcon and 120 or 360, hasIcon and 90 or 120)
    frame.glow:SetVertexColor(s.color[1], s.color[2], s.color[3], 1)
    m.top = top
end

local function PlaceRow(m, i, dx, alpha)
    local r = frame.rows[i]
    r.icon:ClearAllPoints()
    r.icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 18 + dx, -(m.top + (i - 1) * 26))
    r.text:ClearAllPoints()
    r.text:SetPoint("LEFT", r.icon, "RIGHT", 8, 0)
    r.icon:SetAlpha(alpha)
    r.text:SetAlpha(alpha)
end

---------------------------------------------------------------------------
-- Running
---------------------------------------------------------------------------
local Next

local function Draw(m, now)
    local t = now - m.at
    local total = R.IN + m.hold + R.OUT
    if t >= total then frame:Hide(); R.live = nil; Next(); return end
    local x, alpha = 0, 1
    local inK, outK = Clamp01(t / R.IN), Clamp01((t - R.IN - m.hold) / R.OUT)
    if m.calm then
        alpha = math.min(Clamp01(t / 0.3), 1 - Clamp01((t - R.IN - m.hold) / 0.5))
    else
        x = -R.TRAVEL * (1 - Ease(inK)) + R.TRAVEL * outK * outK
        alpha = Clamp01(t / (R.IN * 0.6)) * (1 - outK)
    end
    local y = R.Y
    if m.kind == "fish" and not m.calm then y = y + math.sin(t * 2.4) * 3 end       -- it rocks on the water
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", x, y)
    frame:SetAlpha(alpha)
    frame.band:SetAlpha(ns.db.textShade ~= false and 0.45 or 0)
    -- the rows come in one after another, each sliding in behind the last
    for i = 1, m.nrows do
        local k = m.calm and 1 or Ease((t - 0.15 - (i - 1) * 0.15) / 0.45)
        PlaceRow(m, i, m.calm and 0 or -40 * (1 - k), k)
    end
    local glow = 0
    for _, p in ipairs(frame.rings) do p:SetAlpha(0) end
    for _, p in ipairs(frame.drops) do p:SetAlpha(0) end
    for _, p in ipairs(frame.embers) do p:SetAlpha(0) end
    if m.calm then frame.glow:SetAlpha(0); return end
    if m.kind == "fish" then
        glow = 0.35 + 0.15 * math.sin(t * 3)
        local ix, iy = 26, -24                                   -- the middle of the fish's icon
        for i, ring in ipairs(frame.rings) do                   -- rings spreading on the water
            local phase = ((t - (i - 1) * 0.45) % 1.35) / 1.35
            if t >= (i - 1) * 0.45 then
                local size = 30 + 110 * phase
                ring:ClearAllPoints()
                ring:SetPoint("CENTER", frame, "TOPLEFT", ix, iy - 4)
                ring:SetSize(size, size * 0.42)
                ring:SetVertexColor(0.7, 0.9, 1, 1)
                ring:SetAlpha((1 - phase) * 0.8)
            end
        end
        for i, drop in ipairs(frame.drops) do                   -- drops leap off it and fall back
            local life = 0.9 + 0.4 * Scatter(i, 1)
            local start = 0.05 + (i - 1) * 0.07
            local u = (t - start) / life
            if u > 0 and u < 1 then
                local vx = (Scatter(i, 2) - 0.5) * 90
                local vy = 70 + 60 * Scatter(i, 3)
                local dt = u * life
                drop:ClearAllPoints()
                drop:SetPoint("CENTER", frame, "TOPLEFT", ix + vx * dt, iy + vy * dt - 160 * dt * dt)
                local size = 5 + 4 * Scatter(i, 4)
                drop:SetSize(size, size)
                drop:SetVertexColor(0.75, 0.93, 1, 1)
                drop:SetAlpha(1 - u)
            end
        end
    else
        glow = 0.25 + 0.12 * math.sin(t * 5) + 0.06 * math.sin(t * 13)     -- a fire's flicker
        local w = frame:GetWidth() or 300
        for i, ember in ipairs(frame.embers) do                 -- embers rise off the words and drift
            local life = 1.4 + 0.8 * Scatter(i, 5)
            local u = ((t + Scatter(i, 6) * life) % life) / life
            ember:ClearAllPoints()
            ember:SetPoint("CENTER", frame, "BOTTOMLEFT", w * Scatter(i, 7) + math.sin(t * 2 + i) * 6, u * 70)
            local size = 6 + 5 * Scatter(i, 8)
            ember:SetSize(size, size)
            ember:SetVertexColor(1, 0.62 + 0.25 * Scatter(i, 9), 0.25, 1)
            ember:SetAlpha(math.sin(u * math.pi) * 0.9)
        end
    end
    frame.glow:SetAlpha(glow * (1 - outK))
end

local driver = CreateFrame("Frame")
driver:SetScript("OnUpdate", ns.Protect(function()
    local m = R.live
    if not (m and frame) then return end
    Draw(m, GetTime())
end))

function Next()
    local m = table.remove(R.queue, 1)
    if not m then return end
    if not frame then Build() end
    m.at = GetTime()
    m.calm = ns.Calm() and true or false
    m.hold = R.HOLD + R.ROW_HOLD * math.min(#(m.rows or {}), R.ROWS)
    R.live = m
    R.shown = R.shown + 1
    Lay(m)
    frame:Show()
    Draw(m, m.at)
end

-- A readout: { kind = "fish" | "camp", title, titleColor, sub, icon, rows = { { icon, text } } }
function R.Show(m)
    if not (ns.db and ns.db.readouts and R.running) then return false end
    if #R.queue >= 3 then return false end
    R.queue[#R.queue + 1] = m
    if not R.live then Next() end
    return true
end

---------------------------------------------------------------------------
-- A catch (FishLog.lua tells it)
---------------------------------------------------------------------------
function R.Catch(name, icon, quality, count, weight, new, best)
    local q = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    local title = tostring(name or "")
    if count and count > 1 then title = ("%s  x%d"):format(title, count) end
    local sub = weight and ns.FishLog.Pounds(weight) or ""
    if new then sub = sub .. "   |cffffd24a" .. L["new!"] .. "|r"
    elseif best then sub = sub .. "   |cffffd24a" .. L["best!"] .. "|r" end
    return R.Show({ kind = "fish", title = title, sub = sub, icon = icon,
                    titleColor = q and { q.r, q.g, q.b } or nil })
end

---------------------------------------------------------------------------
-- Buffs the world gives you
---------------------------------------------------------------------------
R.WINDOW = 1.5                   -- buffs that come within this long of each other are one readout
local known, pending, gathering = {}, {}, false

local function Plain(v) if ns.IsSecret(v) then return nil end return v end

-- From the world: not from you, your pet, or anyone in your group (sourceUnit is the game's own word for it)
local function FromTheWorld(a)
    if Plain(a.isFromPlayerOrPlayerPet) then return false end
    local src = Plain(a.sourceUnit)
    if type(src) ~= "string" or src == "" then return true end
    local function yes(fn, ...) local ok, v = pcall(fn, ...); return ok and ns.Yes(v) end
    if yes(UnitIsUnit, src, "player") or yes(UnitIsUnit, src, "pet") then return false end
    if UnitIsPlayer and yes(UnitIsPlayer, src) then return false end
    if UnitInParty and yes(UnitInParty, src) then return false end
    if UnitInRaid and yes(UnitInRaid, src) then return false end
    return true
end
R.FromTheWorld = FromTheWorld

local function Duration(a)
    local d = Plain(a.duration)
    if type(d) ~= "number" or d <= 0 then return nil end
    if d >= 3600 then return L["%d h"]:format(math.floor(d / 3600 + 0.5)) end
    return L["%d min"]:format(math.max(1, math.floor(d / 60 + 0.5)))
end

local function Helpful()
    local U = ns.Unit
    return U and U.Filtered and U.Filtered("player", "HELPFUL", "HELPFUL", 40) or nil
end

-- What you have now, without a readout (at login, after a loading screen, in a fight)
function R.Remember()
    known = {}
    for _, a in ipairs(Helpful() or {}) do
        local id = Plain(a.auraInstanceID)
        if id then known[id] = true end
    end
end

local function Flush()
    gathering = false
    local list = pending
    pending = {}
    if #list == 0 then return end
    local rows, names = {}, {}
    for _, a in ipairs(list) do
        local text = tostring(Plain(a.name) or "?")
        names[#names + 1] = text
        local d = Duration(a)
        if d then text = ("%s  |cffb8c2db%s|r"):format(text, d) end
        rows[#rows + 1] = { icon = Plain(a.icon), text = text }
    end
    ns.Note("readout: buffs from the world: %s", table.concat(names, ", "))
    R.Show({ kind = "camp", title = L["Buffs received"], rows = rows })
end

function R.Look()
    local now = Helpful()
    if not now then return end
    local fighting = InCombatLockdown() or ns.Yes(UnitAffectingCombat("player"))
    local seen = {}
    for _, a in ipairs(now) do
        local id = Plain(a.auraInstanceID)
        if id then
            seen[id] = true
            if not known[id] and not fighting and FromTheWorld(a) and Duration(a) then
                pending[#pending + 1] = a
                if not gathering then
                    gathering = true
                    C_Timer.After(R.WINDOW, ns.Protect(Flush))
                end
            end
        end
    end
    known = seen
end

local events = CreateFrame("Frame")
local looking = false
events:SetScript("OnEvent", ns.Protect(function(_, event, unit)
    if event == "UNIT_AURA" then
        if unit ~= "player" or looking then return end
        looking = true
        C_Timer.After(0.2, ns.Protect(function() looking = false; R.Look() end))
    else
        R.Remember()                              -- a loading screen: what you have is not news
    end
end))

function R:Apply(run)
    self.running = run and true or false
    ns.CalmAgain()
    if self.running and not self.listening then
        self.listening = true
        for _, e in ipairs({ "UNIT_AURA", "PLAYER_ENTERING_WORLD" }) do pcall(events.RegisterEvent, events, e) end
        R.Remember()
    elseif not self.running and self.listening then
        self.listening = false
        events:UnregisterAllEvents()
        R.queue, R.live = {}, nil
        if frame then frame:Hide() end
    end
    if self.running and not ns.db.readouts then
        R.queue, R.live = {}, nil
        if frame then frame:Hide() end
    end
end

function R.Describe()
    local calmNow, why = ns.Calm()
    local cvars = {}
    for _, c in ipairs(ns.CALM_CVARS) do
        local ok, v = pcall(GetCVar, c[1])
        cvars[#cvars + 1] = ("%s = %s"):format(c[1], ok and tostring(v) or "?")
    end
    return { ("readouts on %s, shown %d; reduce animations %s (%s); the game's motion settings: %s"):format(
        tostring(ns.db and ns.db.readouts), R.shown, tostring(calmNow), tostring(why or "-"), table.concat(cvars, ", ")) }
end

ns.RegisterCommand("readouttest", function()
    R.Catch("Raw Brilliant Smallfish", 133890, 1, 1, 2.4, true)
    R.Show({ kind = "camp", title = L["Buffs received"], rows = {
        { icon = 135805, text = "Campfire Warmth  |cffb8c2db30 min|r" },
        { icon = 136064, text = "Well Rested  |cffb8c2db1 h|r" } } })
end, "/cchud readouttest", "show what the readouts of a catch and of buffs look like")

ns.RegisterModule("readout", R)
