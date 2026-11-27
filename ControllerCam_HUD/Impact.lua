-- ControllerCam HUD: hit effects.
-- Every hit you (or your pet) land makes the bar it lands on react: a flash in the colour of the damage school
-- and a shake with that school's character. Crits hit harder. Works on the target and focus frames and on
-- nameplates. Reads the combat log where the client allows it, and the game's per-unit hit events otherwise.

local ADDON, ns = ...
local L = ns.L

local IM = { active = false, shaking = {}, source = nil, heard = 0, landed = 0 }
ns.Impact = IM

ns.RegisterSetting({
    key = "impactFx", kind = "boolean", default = true, command = "impactfx", section = "Frames",
    label = "Hit particles",
    tip = "holy flashes, fire rises, frost crystals linger, shadow smokes, arcane runes twinkle on the bar you hit",
})
ns.RegisterSetting({
    key = "woundFx", kind = "boolean", default = true, command = "wounds", section = "Effects",
    label = "Wounds by the kind of foe",
    tip = "your hits wound an enemy's bar in its own way, more as its health runs low: beasts, humanoids and dragonkin bleed, demons spill fel ichor, elementals shatter, machines throw sparks, undead wither to ash",
})
ns.RegisterSetting({
    key = "playerShake", kind = "boolean", default = true, command = "playershake", section = "Frames",
    label = "Your bars shake when you are hit", tip = "your player frame and vertical bars give a small shake, in the hit's school, when you take damage",
})
ns.RegisterSetting({
    key = "impacts", kind = "boolean", default = true, command = "impacts", section = "Frames",
    label = "Hit effects by damage school",
    tip = "your hits make the bar they land on flash and shake: fire, frost, shadow and the rest each look different",
})

-- Each school's look: the flash colour, the shake (how far, how fast, which way, how long), how slowly the
-- flash fades, and its particles (fx: kind, texture, how many, size, life in seconds, speed).
--   sparks  physical: short white streaks thrown sideways
--   rays    holy: a bright burst that swells, with golden rays rising
--   flames  fire: embers that rise and flicker
--   motes   nature: green motes that float up slowly
--   frost   frost: ice crystals that appear and linger
--   smoke   shadow: dark wisps that spread
--   runes   arcane: violet runes that spin and twinkle
IM.PROFILES = {
    physical = { color = { 1, 1, 1 },        amp = 3,   freq = 70,  axis = "x",  time = 0.20, fade = 4,
                 fx = { kind = "sparks", tex = "spark", count = 4, size = 12, life = 0.25, speed = 140 } },
    holy     = { color = { 1, 0.95, 0.65 },  amp = 2,   freq = 35,  axis = "y",  time = 0.30, fade = 2.2,
                 fx = { kind = "rays",   tex = "spark", count = 6, size = 18, life = 0.5,  speed = 60 } },
    fire     = { color = { 1, 0.5, 0.12 },   amp = 2.5, freq = 120, axis = "y",  time = 0.30, fade = 3,
                 fx = { kind = "flames", tex = "spark", count = 7, size = 14, life = 0.55, speed = 55 } },
    nature   = { color = { 0.45, 1, 0.35 },  amp = 2.5, freq = 28,  axis = "y",  time = 0.35, fade = 2.5,
                 fx = { kind = "motes",  tex = "soft",  count = 6, size = 10, life = 0.8,  speed = 25 } },
    frost    = { color = { 0.55, 0.85, 1 },  amp = 1.2, freq = 130, axis = "xy", time = 0.16, fade = 1.1,
                 fx = { kind = "frost",  tex = "mark",  count = 5, size = 11, life = 0.9,  speed = 0 } },
    shadow   = { color = { 0.62, 0.32, 1 },  amp = 3.5, freq = 12,  axis = "x",  time = 0.45, fade = 2,
                 fx = { kind = "smoke",  tex = "soft",  count = 5, size = 22, life = 0.7,  speed = 20 } },
    arcane   = { color = { 0.85, 0.45, 1 },  amp = 2,   freq = 60,  axis = "xy", time = 0.30, fade = 3.5, twice = true,
                 fx = { kind = "runes",  tex = "mark",  count = 5, size = 12, life = 0.6,  speed = 15 } },
}
-- shadow smoke is drawn dark (normal blend), the rest add light
local DARK = { smoke = true }
-- School bits, the stronger look first when a spell has several
IM.ORDER = { { 4, "fire" }, { 16, "frost" }, { 32, "shadow" }, { 64, "arcane" }, { 8, "nature" }, { 2, "holy" },
             { 1, "physical" } }
local CRIT = 1.8

function IM.School(mask)
    if type(mask) ~= "number" or ns.IsSecret(mask) then return "physical" end
    for _, entry in ipairs(IM.ORDER) do
        if mask % (entry[1] * 2) >= entry[1] then return entry[2] end
    end
    return "physical"
end

---------------------------------------------------------------------------
-- Shaking: any frame, moved around the frame it is pinned to
---------------------------------------------------------------------------
-- (a frame of ours may rest away from its anchor: its baseX / baseY, e.g. bars following the camera)
--
-- In a fight the game does not let addons move a frame that something protected of its own hangs on (the
-- game's aura rows on our target frame and nameplates, in a dungeon for one). Such a frame is left where it
-- is until the fight is over: the game is asked once about it, not every frame. Returns whether it moved.
IM.held = {}
local lastPinned, lastAt
local function Pin(frame, anchor, dx, dy)
    if IM.held[frame] then return false end
    if InCombatLockdown() and frame.IsProtected and frame:IsProtected() == true then
        IM.held[frame] = true
        return false
    end
    lastPinned, lastAt = frame, GetTime()
    dx, dy = dx + (frame.baseX or 0), dy + (frame.baseY or 0)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", anchor, "TOPLEFT", dx, dy)
    frame:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", dx, dy)
    return not IM.held[frame]
end
IM.Pin = Pin

local refusals = CreateFrame("Frame")
pcall(refusals.RegisterEvent, refusals, "ADDON_ACTION_BLOCKED")
pcall(refusals.RegisterEvent, refusals, "PLAYER_REGEN_ENABLED")
refusals:SetScript("OnEvent", function(_, event, addon, what)
    if event == "PLAYER_REGEN_ENABLED" then
        IM.held = {}
    elseif ns.IsOurAddon(addon) and lastPinned and GetTime() - lastAt < 0.2
        and type(what) == "string" and what:find("Points?%(") then
        -- the game just refused the frame we were moving: no more of that in this fight
        if not IM.held[lastPinned] then ns.Note("a frame the game holds still in a fight: left where it is") end
        IM.held[lastPinned] = true
    end
end)

local driver = CreateFrame("Frame")
local function OnUpdate(_, dt)
    local any = false
    local now = GetTime()
    for frame, s in pairs(IM.shaking) do
        s.left = s.left - dt
        if s.left <= 0 then
            IM.shaking[frame] = nil
            Pin(frame, s.anchor, 0, 0)
        else
            any = true
            local k = s.amp * s.left / s.time
            local wave = math.sin((now - s.start) * s.freq)
            local dx = (s.axis ~= "y") and wave * k or 0
            local dy = (s.axis ~= "x") and math.cos((now - s.start) * s.freq * 1.3) * k * 0.7 or 0
            Pin(frame, s.anchor, dx, dy)
        end
    end
    if not any then driver:SetScript("OnUpdate", nil) end
end
OnUpdate = ns.Protect(OnUpdate)

function IM:Shake(frame, anchor, profile, mult)
    if ns.Calm() or ns.Effects() == "none" then return end       -- (Reduce animations: nothing shakes)
    local p = profile or IM.PROFILES.physical
    local s = self.shaking[frame]
    local amp = p.amp * (mult or 1)
    if s and s.amp * s.left / s.time > amp then return end     -- a bigger shake is still running
    self.shaking[frame] = { anchor = anchor, amp = amp, freq = p.freq, axis = p.axis, time = p.time, left = p.time,
                            start = GetTime() }
    driver:SetScript("OnUpdate", OnUpdate)
end

function IM:Stop(frame)
    local s = self.shaking[frame]
    if s then
        self.shaking[frame] = nil
        Pin(frame, s.anchor, 0, 0)
    end
end

function IM:IsShaking(frame) return self.shaking[frame] ~= nil end

---------------------------------------------------------------------------
-- Particles: small textures that live a moment over a bar, on a layer of their own so they can leave its edges
---------------------------------------------------------------------------
local pool, live = {}, {}
local fxDriver = CreateFrame("Frame")
IM.live = live

local function Layer(bar)
    if bar.fxLayer then return bar.fxLayer end
    local layer = CreateFrame("Frame", nil, bar:GetParent())
    layer:SetAllPoints(bar)
    layer:SetFrameLevel((bar.over and bar.over:GetFrameLevel() or bar:GetFrameLevel()) + 2)
    bar.fxLayer = layer
    return layer
end

local function Release(t)
    live[t] = nil
    t:Hide()
    pool[#pool + 1] = t
end

local function FxTick(_, dt)
    local any = false
    for t in pairs(live) do
        t.age = t.age + dt
        local k = t.age / t.life
        if k >= 1 or not t.layer:IsVisible() then
            Release(t)
        else
            any = true
            t.x = t.x + t.vx * dt
            if t.gravity then t.vy = t.vy - t.gravity * dt end
            t.y = math.max(-t.y0, math.min(t.yTop or t.y0, t.y + t.vy * dt))
            local a, size = 1 - k, t.size
            if t.kind == "rays" then size = t.size * (1 + k * 0.6) end
            if t.SetRotation and (t.kind == "rays" or t.kind == "sparks") then t:SetRotation(math.pi / 2) end
            if t.kind == "frost" then a = (k < 0.15) and (k / 0.15) or (1 - (k - 0.15) / 0.85) end
            if t.kind == "smoke" then size = t.size * (1 + k) ; a = 0.6 * (1 - k) end
            if t.kind == "runes" then
                a = (0.5 + 0.5 * math.sin(t.age * 25)) * (1 - k)
                if t.SetRotation then t:SetRotation(t.age * 4) end
            end
            if t.kind == "flames" then a = (1 - k) * (0.7 + 0.3 * math.sin(t.age * 40)) end
            if t.kind == "drip" then a = (k < 0.6) and 1 or (1 - (k - 0.6) / 0.4); size = t.size * (1 + 0.4 * k) end
            if t.kind == "shard" and t.SetRotation then t:SetRotation(t.age * t.spin) end
            if t.kind == "ash" then a = 0.8 * (1 - k); size = t.size * (1 + 0.8 * k) end
            t:SetSize(size, size)
            t:ClearAllPoints()
            t:SetPoint("CENTER", t.layer, "LEFT", t.x, t.y)
            t:SetAlpha(a)
        end
    end
    if not any then fxDriver:SetScript("OnUpdate", nil) end
end
FxTick = ns.Protect(FxTick)

-- from (Full and Subtle; see Origin below): where the particles start instead of the end of the health:
-- { x =, y =, dir = (which way they travel: 1 right, -1 left; nil both), both = (from the far end too),
--   color = (theirs, in place of the school's) }
function IM:Burst(bar, p, mult, from)
    if ns.Calm() or ns.Effects() == "none" then return end       -- (nor bursts)
    local fx = p.fx
    if not fx then return end
    local layer = Layer(bar)
    local w, h = bar:GetWidth() or 100, bar:GetHeight() or 8
    local fill = bar:GetFraction()
    local edge = fill and math.max(8, w * fill) or w * 0.5      -- where the hit landed: the end of the health
    for i = 1, math.floor(fx.count * (mult or 1) + 0.5) do
        local t = table.remove(pool) or layer:CreateTexture(nil, "OVERLAY")
        if t:GetParent() ~= layer and t.SetParent then t:SetParent(layer) end
        t.layer, t.kind, t.age = layer, fx.kind, 0
        t.gravity, t.yTop = nil, nil                             -- (a texture a wound used before)
        t.life = fx.life * (0.8 + math.random() * 0.4)
        t.size = fx.size * (0.7 + math.random() * 0.6)
        t:SetTexture(ns.media[fx.tex])
        t:SetBlendMode(DARK[fx.kind] and "BLEND" or "ADD")
        local c = from and from.color or p.color
        if DARK[fx.kind] then t:SetVertexColor(c[1] * 0.35, c[2] * 0.2, c[3] * 0.45, 1)
        else t:SetVertexColor(c[1], c[2], c[3], 1) end
        -- everything travels along the bar and rolls off its ends, staying level with it (never up into the
        -- name above): half go left, half right, from where the hit landed
        local dir = (math.random() < 0.5) and -1 or 1
        local jitter = math.random() * 2 - 1
        t.x = math.max(0, math.min(w, edge + jitter * 10))
        t.y = jitter * h * 0.35
        if from then                                              -- in from an end of the bar, or off a hit area
            local ox, way = from.x, from.dir
            if from.both and i % 2 == 0 then ox, way = w - ox, way and -way end
            dir = way or dir
            t.x = math.max(0, math.min(w, ox + jitter * 6))
            t.y = (from.y or 0) + jitter * h * 0.3
        end
        local s = math.max(fx.speed, 30) * (0.8 + math.random() * 0.5)
        if fx.kind == "frost" then t.vx, t.vy = dir * 12, 0                       -- crystals barely drift
        elseif fx.kind == "rays" then t.vx, t.vy = dir * s * 2.2, 0              -- streaks of light
        elseif fx.kind == "sparks" then t.vx, t.vy = dir * s * 1.6, jitter * h
        elseif fx.kind == "flames" then t.vx, t.vy = dir * s * 1.4, jitter * h * 0.6
        else t.vx, t.vy = dir * s, jitter * h * 0.5 end
        t.y0 = h * 0.9                                                           -- how far from the bar it may stray
        t:Show()
        live[t] = true
    end
    fxDriver:SetScript("OnUpdate", FxTick)
end

---------------------------------------------------------------------------
-- Hit areas (Full and Subtle): eight places round a bar where blows land and wounds open. 1-4 along its top
-- edge, 5-8 along the bottom, left to right. Returns x (from the bar's left end) and y (from its middle).
---------------------------------------------------------------------------
IM.AREAS = 8
IM.SUBTLE_AREAS = { 2, 7 }       -- Subtle strikes at these two in turn; Full anywhere
function IM.Area(bar, i)
    local w, h = bar:GetWidth() or 100, bar:GetHeight() or 8
    return w * (0.125 + 0.25 * ((i - 1) % 4)), (i <= 4 and 1 or -1) * h / 2
end

-- Marks: what a blow draws where it lands (a cut, a ring knocked out, a shot flying in), gone in a moment.
-- Kept apart from the particles above; reused the same way.
local marks, markPool = {}, {}
IM.marks = marks
local markDriver = CreateFrame("Frame")

local function MarkDraw(t, k)
    local w, h, a = t.len, t.thick, 1
    local x = t.x
    if t.mk == "cut" then                       -- drawn on quickly, then it fades
        local grow = math.min(1, k / 0.35)
        w, h = t.thick, t.len * grow
        a = k < 0.35 and 1 or 1 - (k - 0.35) / 0.65
    elseif t.mk == "ring" then                  -- knocked outward
        w = t.len * (0.3 + 0.9 * k)
        h, a = w, 1 - k
    elseif t.mk == "fly" then                   -- in along the bar to where it lands
        local f = math.min(1, k / 0.5)
        x = t.x0 + (t.x - t.x0) * f
        w, h = t.thick, t.len
        a = k < 0.5 and 1 or 1 - (k - 0.5) / 0.5
    else                                        -- a flash
        w = t.len * (0.6 + 0.6 * k)
        h, a = w, 0.8 * (1 - k)
    end
    t:SetSize(math.max(0.5, w), math.max(0.5, h))
    t:ClearAllPoints()
    t:SetPoint("CENTER", t.layer, "LEFT", x, t.y)
    t:SetAlpha(a)
end

local function MarkTick(_, dt)
    local any = false
    for t in pairs(marks) do
        t.age = t.age + dt
        local k = t.age / t.life
        if k >= 1 or not t.layer:IsVisible() then
            marks[t] = nil
            t:Hide()
            markPool[#markPool + 1] = t
        else
            any = true
            MarkDraw(t, k)
        end
    end
    if not any then markDriver:SetScript("OnUpdate", nil) end
end
MarkTick = ns.Protect(MarkTick)

local function Mark(layer, mk, tex, color, x, y, len, thick, turn, life, x0)
    local t = table.remove(markPool) or layer:CreateTexture(nil, "OVERLAY")
    if t:GetParent() ~= layer and t.SetParent then t:SetParent(layer) end
    t.layer, t.mk, t.age, t.life = layer, mk, 0, life
    t.x, t.y, t.len, t.thick, t.x0 = x, y, len, thick, x0 or x
    t:SetTexture(ns.media[tex])
    t:SetBlendMode("ADD")
    t:SetTexCoord(0, 1, 0, 1)
    t:SetVertexColor(color[1], color[2], color[3], 1)
    if t.SetRotation then t:SetRotation(turn or 0) end
    MarkDraw(t, 0)
    t:Show()
    marks[t] = true
    markDriver:SetScript("OnUpdate", MarkTick)
    return t
end

local LEAN = 0.7                 -- how far a cut leans from upright (radians)
-- A blow lands at hit area `area` of a bar. def: an entry of CastLook.STRIKES (or its SWING, SHOT).
function IM:Strike(bar, def, color, area, crit)
    if ns.Calm() then return end
    local layer = Layer(bar)
    local w, h = bar:GetWidth() or 100, bar:GetHeight() or 8
    local x, y = IM.Area(bar, area)
    local len = math.max(18, h * 2.6) * (crit and 1.3 or 1)
    local thick = math.max(4, h * 0.5)
    local lean = (area % 2 == 0) and LEAN or -LEAN
    local kind = def.kind
    if kind == "cross" then
        Mark(layer, "cut", "spark", color, x, y, len, thick, lean, 0.3)
        Mark(layer, "cut", "spark", color, x, y, len, thick, -lean, 0.36)
    elseif kind == "claw" then
        for j = -1, 1 do Mark(layer, "cut", "spark", color, x + j * thick * 1.4, y, len * 0.85, thick * 0.8, lean, 0.3 + (j + 1) * 0.03) end
    elseif kind == "stab" then                                    -- a thrust in from the nearer end
        Mark(layer, "fly", "spark", color, x, y * 0.4, len, thick, math.pi / 2, 0.26, x < w / 2 and -10 or w + 10)
        Mark(layer, "flash", "soft", color, x, y * 0.4, len * 0.7, 0, 0, 0.3)
    elseif kind == "bash" then
        Mark(layer, "ring", "ring", color, x, y * 0.4, len * 1.2, 0, 0, 0.32)
        Mark(layer, "flash", "soft", color, x, y * 0.4, len, 0, 0, 0.3)
    elseif kind == "arrow" then                                   -- a shot, from your side of the bar
        Mark(layer, "fly", "spark", color, x, y * 0.3, len * 1.3, thick * 0.7, math.pi / 2, 0.24, -20)
        Mark(layer, "flash", "soft", color, x, y * 0.3, len * 0.6, 0, 0, 0.3)
    else                                                          -- a slash
        Mark(layer, "cut", "spark", color, x, y, len, thick, lean, 0.3)
    end
    if crit and kind ~= "bash" then Mark(layer, "flash", "soft", color, x, y * 0.5, len, 0, 0, 0.35) end
    self.struck = { key = def.key, kind = kind, area = area }
    self.strikes = (self.strikes or 0) + 1
end

-- Where a hit's effects start on a bar (Full and Subtle), drawing the blow itself on the way. Returns what
-- Burst takes as `from`, with area and edge (the hit area struck and its y on the bar's edge) for a blow.
function IM:Origin(bar, school, crit, strike, level)
    if strike == false then return nil end                       -- a tick: where the health ends, as ever
    local w = bar:GetWidth() or 100
    local full = level == "full"
    bar.fxTurn = (bar.fxTurn or 0) + 1
    if strike == nil and school == "physical" then strike = ns.CastLook.SWING end
    if strike then
        local area = full and math.random(IM.AREAS) or IM.SUBTLE_AREAS[bar.fxTurn % 2 + 1]
        local x, y = IM.Area(bar, area)
        local color = strike.color or (self.PROFILES[school] or self.PROFILES.physical).color
        if ns.db.impactFx then self:Strike(bar, strike, color, area, crit) end
        bar.lastArea = area
        return { x = x, y = y * 0.6, area = area, edge = y, color = strike.color, heavy = strike.heavy }
    end
    -- a spell: in from an end of the bar (Full: either; Subtle: left, then right), a crit from both
    local left
    if full then left = math.random() < 0.5 else left = bar.fxTurn % 2 == 1 end
    return { x = left and 0 or w, y = 0, dir = left and 1 or -1, both = crit }
end

---------------------------------------------------------------------------
-- A hit on a bar: { frame = (what shakes), anchor = (what it is pinned to), bar = (what flashes) }
---------------------------------------------------------------------------
-- strike (Full and Subtle): how the blow lands, an entry of CastLook.STRIKES; nil when nobody said (a physical
-- hit is then a swing of your weapon, a spell comes in from an end of the bar); false for a tick, which stays
-- where the health ends
function IM:Hit(target, school, crit, shake, strike)
    local p = self.PROFILES[school] or self.PROFILES.physical
    local mult = crit and CRIT or 1
    local level = ns.Effects()
    target.frame.lastImpact = GetTime()
    target.bar:Flash(crit and 0.5 or 0.15, p.color, p.fade)
    self.last = { school = school, crit = crit and true or false }
    if level == "none" then return end                           -- colour only
    local from
    if level ~= "classic" then from = self:Origin(target.bar, school, crit, strike, level) end
    local less = level == "subtle" and 0.6 or 1                  -- (fewer pieces)
    if ns.db.impactFx then self:Burst(target.bar, p, mult * less, from) end
    if ns.db.woundFx and target.unit then
        self:Wound(target.bar, target.unit, crit, nil, nil, from and from.area and from.x, from and from.edge)
    end
    if p.twice then
        C_Timer.After(0.12, function() target.bar:Flash(0.2, p.color, p.fade) end)
    end
    if level ~= "subtle" then                                    -- (and nothing shakes)
        self:Shake(target.frame, target.anchor, p, mult * (shake or 1) * (from and from.heavy or 1))
    end
end

---------------------------------------------------------------------------
-- Wounds: what your hit does to the kind of thing it hits, from the end of its health. More as it runs low.
--   bleed    beasts, humanoids, giants: red drops that fall from the bar and fade
--   dragon   dragonkin: darker, heavier blood
--   ichor    demons: fel-green ichor, dripping
--   void     aberrations: violet ichor
--   shatter  elementals: chips of stone breaking off, thrown up and falling, spinning
--   sparks   machines: bright sparks spat out and falling
--   splinter totems: splinters of wood
--   ash      undead: grey ash and dust lifting off and drifting away, as they wither
-- Critters, gas clouds and what the game does not name have none.
---------------------------------------------------------------------------
IM.WOUNDS = {
    bleed    = { color = { 0.72, 0.04, 0.04 }, kind = "drip",  tex = "soft",  count = 3, size = 5,  life = 0.9 },
    dragon   = { color = { 0.5, 0.02, 0.06 },  kind = "drip",  tex = "soft",  count = 4, size = 6,  life = 1.0 },
    ichor    = { color = { 0.35, 0.9, 0.15 },  kind = "drip",  tex = "soft",  count = 3, size = 5,  life = 0.9 },
    void     = { color = { 0.55, 0.2, 0.75 },  kind = "drip",  tex = "soft",  count = 3, size = 5,  life = 0.9 },
    shatter  = { color = { 0.62, 0.56, 0.48 }, kind = "shard", tex = "crystal", count = 4, size = 7, life = 0.75 },
    sparks   = { color = { 1, 0.8, 0.35 },     kind = "shard", tex = "spark", count = 4, size = 6,  life = 0.5, add = true },
    splinter = { color = { 0.55, 0.38, 0.2 },  kind = "shard", tex = "mark",  count = 3, size = 6,  life = 0.6 },
    ash      = { color = { 0.62, 0.64, 0.6 },  kind = "ash",   tex = "soft",  count = 4, size = 7,  life = 1.1 },
    -- undead at Full and Subtle: sludge pours out of them, and every other piece is gas lifting off
    sludge   = { color = { 0.34, 0.4, 0.12 },  kind = "drip",  tex = "soft",  count = 4, size = 6,  life = 1.1,
                 gas = { 0.55, 0.8, 0.35 } },
}
IM.WOUND_NEW = { [6] = "sludge" }       -- by creature type, in place of WOUND_OF's at Full and Subtle
local function NewLook()
    local level = ns.Effects()
    return level == "full" or level == "subtle"
end
-- The game's creature types by number (the same in every language): 1 beast, 2 dragonkin, 3 demon, 4 elemental,
-- 5 giant, 6 undead, 7 humanoid, 9 mechanical, 11 totem, 15 aberration
IM.WOUND_OF = { [1] = "bleed", [2] = "dragon", [3] = "ichor", [4] = "shatter", [5] = "bleed", [6] = "ash",
                [7] = "bleed", [9] = "sparks", [11] = "splinter", [15] = "void" }
-- Their names, for clients without the game's list of them (English)
local TYPE_NAMES = { Beast = 1, Dragonkin = 2, Demon = 3, Elemental = 4, Giant = 5, Undead = 6, Humanoid = 7,
                     Critter = 8, Mechanical = 9, ["Not specified"] = 10, Totem = 11, ["Non-combat Pet"] = 12,
                     ["Gas Cloud"] = 13, ["Wild Pet"] = 14, Aberration = 15 }
local typeIDs
local function TypeIDs()
    if typeIDs then return typeIDs end
    typeIDs = {}
    for name, id in pairs(TYPE_NAMES) do typeIDs[name] = id end
    local C = C_CreatureInfo
    if C and C.GetCreatureTypeIDs and C.GetCreatureTypeInfo then           -- the names in this game's language
        local ok, ids = pcall(C.GetCreatureTypeIDs)
        for _, id in ipairs(ok and type(ids) == "table" and ids or {}) do
            local okI, info = pcall(C.GetCreatureTypeInfo, id)
            if okI and type(info) == "table" and type(info.name) == "string" then typeIDs[info.name] = id end
        end
    end
    return typeIDs
end

-- The wound of a unit, by its creature type, or nil
function IM.WoundOf(unit)
    local ok, ctype = pcall(UnitCreatureType, unit)
    if not ok or ns.IsSecret(ctype) or type(ctype) ~= "string" then return nil end
    local id = TypeIDs()[ctype]
    if id and IM.WOUND_NEW[id] and NewLook() then return IM.WOUND_NEW[id] end
    return id and IM.WOUND_OF[id] or nil
end

-- ax, ay (Full and Subtle): from a hit area (x along the bar, y on its edge) instead of the end of the health
function IM:Wound(bar, unit, crit, count, layer, ax, ay)
    if ns.Calm() or ns.Effects() == "none" then return end
    local name = IM.WoundOf(unit)
    local w = name and IM.WOUNDS[name]
    if not w then return end
    layer = layer or Layer(bar)
    local width, h = bar:GetWidth() or 100, bar:GetHeight() or 8
    local fill = bar:GetFraction()
    local edge = fill and math.max(4, width * fill) or width * 0.5
    -- more as its health runs low (when the game lets us know how low): up to three times at the end
    local low = fill and (1 - fill) or 0.3
    local n = count or math.floor(w.count * (1 + 2 * low) * (crit and 1.5 or 1) + 0.5)
    for i = 1, n do
        local t = table.remove(pool) or layer:CreateTexture(nil, "OVERLAY")
        if t:GetParent() ~= layer and t.SetParent then t:SetParent(layer) end
        local kind, color = w.kind, w.color
        if w.gas and i % 2 == 0 then kind, color = "ash", w.gas end   -- (sludge: every other piece is gas)
        t.layer, t.kind, t.age = layer, kind, 0
        t.life = w.life * (0.8 + math.random() * 0.4)
        t.size = w.size * (0.7 + math.random() * 0.6)
        t:SetTexture(ns.media[w.tex])
        t:SetBlendMode(w.add and "ADD" or "BLEND")
        local shade = 0.85 + math.random() * 0.3
        t:SetVertexColor(color[1] * shade, color[2] * shade, color[3] * shade, 1)
        local jitter = math.random() * 2 - 1
        t.x, t.y = math.max(0, math.min(width, edge + jitter * 4)), -h * 0.3
        if ax then t.x, t.y = math.max(0, math.min(width, ax + jitter * 3)), ay or 0 end
        t.gravity, t.spin, t.yTop = nil, 0, h
        if kind == "drip" then                                    -- falls from the bar
            t.vx, t.vy, t.gravity = jitter * 8, -6, 70
            t.y0 = h * 3.5
        elseif kind == "shard" then                               -- thrown off, up and out, then falling
            t.vx, t.vy, t.gravity = jitter * 55, 25 + math.random() * 25, 110
            t.spin = (math.random() < 0.5 and -1 or 1) * (6 + math.random() * 6)
            t.y0 = h * 3
        else                                                      -- ash: lifts off and drifts away, slowly
            t.vx, t.vy, t.gravity = jitter * 14 + 6, 6 + math.random() * 8, nil
            t.y, t.y0, t.yTop = 0, h, h * 1.4
        end
        t:Show()
        live[t] = true
    end
    fxDriver:SetScript("OnUpdate", FxTick)
    if not count then self.wounded = (self.wounded or 0) + 1 end
    self.lastWound = name
end

---------------------------------------------------------------------------
-- Bleeding out: a wounded foe keeps showing it between your hits, more the lower its health. From under 60% a
-- drop now and then from the end of its health; from a quarter, a steady stream (blood, ichor, falling chips of
-- stone, sparks, ash). Where the game keeps health to itself, its own answer to "a quarter or less?" (the same
-- as the execute glow's) shows the stream or hides it, unread.
---------------------------------------------------------------------------
IM.BLEED_FROM = 0.6             -- it starts below this share of health
IM.BLEED_RATE = 3               -- drops a second just under it ...
IM.BLEED_LOW = 9                -- ... and at a quarter or less
local bleeding = {}
IM.bleeding = bleeding
local bleedDriver = CreateFrame("Frame")

-- Open wounds (Full and Subtle): below half of its health a foe's bar has one gash at a hit area, at a quarter
-- or less three, and what it bleeds comes out of them. The first opens where your last blow fell (Full) or at
-- its fixed place; the others at theirs.
IM.WOUND_FROM = 0.5
IM.WOUND_AREAS = { 6, 3, 8 }
local function CloseWounds(bar)
    for _, g in ipairs(bar.gashes or {}) do g:Hide() end
    bar.lastArea = nil
end
local function OpenWounds(bar, b, n, layer)
    local w = IM.WOUNDS[IM.WoundOf(b.unit) or ""]
    bar.gashes, b.areas = bar.gashes or {}, b.areas or {}
    local h = bar:GetHeight() or 8
    for i = 1, #IM.WOUND_AREAS do
        local g = bar.gashes[i]
        if i > n or not w then
            b.areas[i] = nil
            if g then g:Hide() end
        else
            if not b.areas[i] then
                local area = (i == 1 and ns.Effects() == "full" and bar.lastArea) or IM.WOUND_AREAS[i]
                local taken = true
                while taken do                                        -- never two in one place
                    taken = false
                    for j = 1, #IM.WOUND_AREAS do
                        if j ~= i and b.areas[j] == area then taken = true end
                    end
                    if taken then area = area % IM.AREAS + 1 end
                end
                b.areas[i] = area
                IM.opened = (IM.opened or 0) + 1
            end
            if not g then
                g = layer:CreateTexture(nil, "OVERLAY")
                bar.gashes[i] = g
            end
            if g:GetParent() ~= layer and g.SetParent then g:SetParent(layer) end
            g:SetTexture(ns.media.bolt)                               -- a jagged tear, in the dark of what leaks from it
            g:SetBlendMode("BLEND")
            g:SetVertexColor(w.color[1] * 0.6, w.color[2] * 0.6, w.color[3] * 0.6, 1)
            local x, y = IM.Area(bar, b.areas[i])
            g:SetSize(math.max(10, h * 1.4), math.max(5, h * 0.6))
            g:ClearAllPoints()
            g:SetPoint("CENTER", layer, "LEFT", x, y * 0.5)
            g:SetAlpha(0.9)
            g:Show()
        end
    end
    b.open = n
end

local function BleedTick(_, dt)
    local any = false
    for bar, b in pairs(bleeding) do
        any = true
        if not (ns.db.woundFx and ns.db.impacts) then bleeding[bar] = nil; CloseWounds(bar)
        elseif bar:IsVisible() and not ns.Calm() then
            b.due = (b.due or 0) + dt * b.rate
            local n = math.floor(b.due)
            if n > 0 then
                b.due = b.due - n
                local open = b.areas and b.open or 0
                if open > 0 then                                      -- out of the open wounds, each in its turn
                    for _ = 1, n do
                        b.turn = (b.turn or 0) % open + 1
                        local x, y = IM.Area(bar, b.areas[b.turn])
                        IM:Wound(bar, b.unit, false, 1, b.layer, x, y * 0.5)
                    end
                else
                    IM:Wound(bar, b.unit, false, n, b.layer)
                end
                IM.bled = (IM.bled or 0) + n
            end
        end
    end
    if not any then bleedDriver:SetScript("OnUpdate", nil) end
end
BleedTick = ns.Protect(BleedTick)

-- The health of a foe's bar changed: how much it bleeds now (bar, its unit, its share of health or nil)
function IM:Bleed(bar, unit, frac)
    local on = ns.db.woundFx and ns.db.impacts and unit and IM.WoundOf(unit)
    if on then
        local ok, enemy = pcall(UnitCanAttack, "player", unit)
        local okD, dead = pcall(UnitIsDead, unit)
        on = ok and ns.Yes(enemy) and not (okD and ns.Yes(dead))
    end
    local level = ns.Effects()
    if level == "none" then on = false end
    local new = level ~= "classic"
    local rate, gate, open
    if on and type(frac) == "number" and not ns.IsSecret(frac) then
        if new then                                                           -- wounds: one from half, three from a quarter
            if frac > 0 and frac <= IM.WOUND_FROM then
                local k = (IM.WOUND_FROM - frac) / (IM.WOUND_FROM - ns.EXECUTE)
                rate = frac <= ns.EXECUTE and IM.BLEED_LOW or (0.5 + (IM.BLEED_RATE - 0.5) * math.min(1, k))
                open = frac <= ns.EXECUTE and #IM.WOUND_AREAS or 1
            end
        elseif frac > 0 and frac < IM.BLEED_FROM then
            local k = (IM.BLEED_FROM - frac) / (IM.BLEED_FROM - ns.EXECUTE)
            rate = frac <= ns.EXECUTE and IM.BLEED_LOW or (0.5 + (IM.BLEED_RATE - 0.5) * math.min(1, k))
        end
    elseif on then
        -- its health is kept from us: "below half?" cannot be known, so nothing opens there; "a quarter or
        -- less?" is the game's own answer, unread, and shows all three wounds or none
        gate = ns.ExecuteState and ns.ExecuteState(unit, nil)
        if gate ~= nil then rate = IM.BLEED_LOW; open = new and #IM.WOUND_AREAS or nil end
    end
    if not rate then bleeding[bar] = nil; CloseWounds(bar); return end
    local b = bleeding[bar] or {}
    local guid = ns.GUID(unit)
    if ns.IsSecret(guid) then guid = nil end
    if guid ~= b.guid then b.areas, b.guid = nil, guid end                    -- another foe on this bar: its own wounds
    b.unit, b.rate = unit, rate
    if gate ~= nil then
        if not bar.bleedLayer then                                         -- a layer of its own, shown or not by it
            local l = CreateFrame("Frame", nil, bar:GetParent())
            l:SetAllPoints(bar)
            l:SetFrameLevel((bar.over and bar.over:GetFrameLevel() or bar:GetFrameLevel()) + 2)
            bar.bleedLayer = l
        end
        pcall(bar.bleedLayer.SetAlpha, bar.bleedLayer, gate)
        b.layer = bar.bleedLayer
    else
        b.layer = nil
    end
    if open then OpenWounds(bar, b, open, b.layer or Layer(bar)) else CloseWounds(bar); b.areas, b.open = nil, nil end
    bleeding[bar] = b
    bleedDriver:SetScript("OnUpdate", BleedTick)
end

-- Every bar of ours showing this unit (by GUID)
local function Targets(guid)
    local list = {}
    if not guid or ns.IsSecret(guid) then return list end
    local UF = ns.UnitFrames
    for _, key in ipairs({ "target", "focus" }) do
        local f = UF.frames[key]
        if f and f.on and ns.GUID(f.unit) == guid then
            list[#list + 1] = { frame = f.visual, anchor = f.button, bar = f.health, unit = f.unit }
        end
    end
    local plate = ns.Nameplates and ns.Nameplates.byGuid[guid]
    if plate and plate:IsShown() then
        list[#list + 1] = { frame = plate, anchor = plate.plate, bar = plate.health, unit = plate.unit }
    end
    return list
end
IM.Targets = Targets

-- Every bar of ours showing this unit, by the unit the game named ("target", "focus", "nameplate3"): for a hit
-- whose unit's GUID the game keeps to itself in a fight (then Targets cannot match it)
function IM.DescribeUnits()
    local parts = {}
    for kind, n in pairs(IM.byUnit) do parts[#parts + 1] = kind .. " " .. n end
    table.sort(parts)
    return #parts > 0 and (" (by unit: " .. table.concat(parts, ", ") .. ")") or ""
end

local function TargetsOfUnit(unit)
    local list = {}
    if type(unit) ~= "string" or ns.IsSecret(unit) then return list end
    local UF = ns.UnitFrames
    for _, key in ipairs({ "target", "focus" }) do
        local f = UF.frames[key]
        if f and f.on and f.unit == unit then
            list[#list + 1] = { frame = f.visual, anchor = f.button, bar = f.health, unit = f.unit }
        end
    end
    for _, o in pairs(ns.Nameplates and ns.Nameplates.plates or {}) do
        if o.unit == unit and o:IsShown() then
            list[#list + 1] = { frame = o, anchor = o.plate, bar = o.health, unit = o.unit }
        end
    end
    return list
end
IM.TargetsOfUnit = TargetsOfUnit

local lastLanded = {}
IM.byUnit = {}                   -- hits heard from the game's unit event, by the kind of unit (for the reports)
local function Land(guid, school, crit, unit, strike)
    local key = (guid and not ns.IsSecret(guid)) and guid or nil
    local list = key and Targets(key) or {}
    if #list == 0 and unit then list = TargetsOfUnit(unit); key = key or unit end   -- (its GUID kept from us)
    if not key then return end
    local now = GetTime()
    if lastLanded[key] and now - lastLanded[key] < 0.05 then return end       -- heard twice (log and unit event)
    lastLanded[key] = now
    for _, t in ipairs(list) do
        IM:Hit(t, school, crit, nil, strike)
        IM.landed = IM.landed + 1
    end
    if crit and ns.Rumble then ns.Rumble:Crit() end              -- felt in the right trigger
end

---------------------------------------------------------------------------
-- Heals: the bar they land on lights up in the colour of the heal's school, and its effect rises off it
-- (holy light, nature's motes...). Your own vertical bars just glow.
---------------------------------------------------------------------------
local lastHealed = {}
function IM:Heal(t, school)
    local p = self.PROFILES[school] or self.PROFILES.holy
    local bar = t.bar
    if not bar then return end
    bar:Flash(0.35, p.color, 1.6)
    if ns.db.impactFx and not bar.vertical then self:Burst(bar, p, 0.6) end
    self.lastHeal = { bar = bar, school = school }
end

local function HealLand(guid, school, unit)
    local now = GetTime()
    if ns.IsSecret(guid) then guid = nil end
    local key = guid or unit
    if not key or (lastHealed[key] and now - lastHealed[key] < 0.05) then return end
    lastHealed[key] = now
    if unit == "player" or (guid and guid == ns.GUID("player")) then
        local UF = ns.UnitFrames
        for _, k in ipairs({ "player", "vertical" }) do
            local f = UF.frames[k]
            if f and f.on then IM:Heal({ frame = f.visual, anchor = f.button, bar = f.health }, school) end
        end
        return
    end
    for _, t in ipairs(Targets(guid)) do IM:Heal(t, school) end
end
IM.HealLand = HealLand

---------------------------------------------------------------------------
-- Where hits come from
---------------------------------------------------------------------------
local function LogInfo()
    if type(CombatLogGetCurrentEventInfo) == "function" then return CombatLogGetCurrentEventInfo end
    if C_CombatLog and type(C_CombatLog.GetCurrentEventInfo) == "function" then return C_CombatLog.GetCurrentEventInfo end
end

local function Restricted()
    return C_Secrets and type(C_Secrets.HasSecretRestrictions) == "function" and C_Secrets.HasSecretRestrictions()
end

local DAMAGE = { SWING_DAMAGE = 12, RANGE_DAMAGE = 15, SPELL_DAMAGE = 15, SPELL_PERIODIC_DAMAGE = 15,
                 DAMAGE_SHIELD = 15, DAMAGE_SPLIT = 15 }          -- where the amount sits; the school is always 14th
local CHAINED = { SWING_DAMAGE = true, RANGE_DAMAGE = true, SPELL_DAMAGE = true, SPELL_PERIODIC_DAMAGE = true }
IM.LOG_QUIET = 5                 -- the log has said nothing for this long: the game's hit event counts instead

-- Every spell's school, as the log tells it (a cast starting, a hit, a heal; yours or anyone's): cast bars
-- take their colour and their effects from it
IM.SCHOOL_OF = {}
IM.HEAL_OF = {}                  -- and which spells heal: their casts grow vines and flowers
IM.GUESSED = {}                  -- a school guessed from the hit that followed a cast: { [spellID] = { school = times } }
local learned = 0
local function Learn(sub, spellID, mask)
    if type(sub) ~= "string" or sub:sub(1, 6) ~= "SPELL_" then return end
    if ns.IsSecret(spellID) or ns.IsSecret(mask) or type(spellID) ~= "number" or type(mask) ~= "number" then return end
    if sub == "SPELL_HEAL" or sub == "SPELL_PERIODIC_HEAL" then IM.HEAL_OF[spellID] = true end
    if IM.SCHOOL_OF[spellID] then return end
    if learned > 2000 then IM.SCHOOL_OF, IM.HEAL_OF, IM.GUESSED, learned = {}, {}, {}, 0 end
    if mask >= 128 then ns.Note("school %d of spell %d is not one we know", mask, spellID) end
    IM.SCHOOL_OF[spellID] = IM.School(mask)
    learned = learned + 1
end

local function FromLog()
    IM.heard = IM.heard + 1
    local info = LogInfo()
    local e = { info() }
    local sub, sourceGUID, destGUID = e[2], e[4], e[8]
    if not ns.IsSecret(sourceGUID) and sourceGUID then IM.logAt = GetTime() end    -- the log names who did it
    Learn(sub, e[12], e[14])
    if sub == "SPELL_AURA_APPLIED" or sub == "SPELL_AURA_REFRESH" or sub == "SPELL_AURA_REMOVED" then
        if ns.Bloom then ns.Bloom.FromLog(sub, destGUID, e[12]) end      -- heals over time growing on a bar
        if ns.Ward then ns.Ward.FromLog(sub, destGUID, e[12]) end        -- shields round a bar
        return
    end
    if sub == "SPELL_HEAL" or sub == "SPELL_PERIODIC_HEAL" then
        HealLand(e[8], IM.School(e[14]))
        if sub == "SPELL_HEAL" and sourceGUID == ns.GUID("player") and ns.Moments then     -- your heals, for a moment
            ns.Moments.HealFromLog(e[12], e[13], e[15], e[16], e[18], e[14])
        end
        return
    end
    if sub == "SPELL_EXTRA_ATTACKS" and sourceGUID == ns.GUID("player") and ns.Moments then
        ns.Moments.ExtraAttack(e[12], e[13])                         -- Windfury and the like: the next swing is it
    end
    local at = DAMAGE[sub]
    if destGUID == ns.GUID("player") and ns.Numbers then                -- what a shield took off a hit on you
        if at then ns.Numbers.FromLogAbsorb(e[at + 5], e[14])
        elseif sub == "SWING_MISSED" and e[12] == "ABSORB" then ns.Numbers.FromLogAbsorb(e[14], 1)
        elseif (sub == "SPELL_MISSED" or sub == "RANGE_MISSED" or sub == "SPELL_PERIODIC_MISSED") and e[15] == "ABSORB" then
            ns.Numbers.FromLogAbsorb(e[17], e[14])
        end
    end
    if not at then return end
    if sourceGUID ~= ns.GUID("player") and sourceGUID ~= ns.GUID("pet") then return end
    local crit = e[at + 6]
    if ns.IsSecret(crit) then crit = false end
    -- your own damage (not your pet's, not Thorns) adds to a chain of casts' total
    if sourceGUID == ns.GUID("player") and CHAINED[sub] and ns.CastBar then ns.CastBar.Damage(e[at]) end
    if ns.Moments and sourceGUID == ns.GUID("player") then                -- your key abilities, felt
        if sub == "SWING_DAMAGE" then ns.Moments.Swing(e[12], crit)
        elseif sub == "SPELL_DAMAGE" then ns.Moments.FromLog(e[12], e[13], e[15], crit, e[14]) end
    end
    -- how the blow lands (Full and Subtle): a swing, a shot, one of your abilities by its name; a tick is none
    local strike = false
    if sub == "SWING_DAMAGE" then strike = ns.CastLook.SWING
    elseif sub == "RANGE_DAMAGE" then strike = ns.CastLook.SHOT
    elseif sub == "SPELL_DAMAGE" then strike = ns.CastLook.Strike(e[13], e[12]) end
    Land(destGUID, IM.School(e[14]), crit and true or false, nil, strike)
end

-- Without the combat log: the game's hit event for a unit (any attacker). The amount may be secret: a hit
-- is a hit.
-- Your last finished cast: the hit or heal that follows it within a moment tells its school, for clients
-- whose combat log addons cannot read. That is a guess (somebody else's hit may land in that moment: a
-- poison ticking on your target right after your Holy Light), so it is kept apart from what the log said, it
-- is only asked when nothing else knows the spell, and the school seen most often after the spell is the one.
local lastCast, lastOwn, lastAbility = nil, -10, nil
function IM.NoteCast(spellID)
    lastOwn = GetTime()                              -- (a cast of yours, whatever it was: see Mine below)
    lastAbility = nil
    if ns.IsSecret(spellID) or type(spellID) ~= "number" then return end
    lastCast = { id = spellID, at = GetTime() }
    lastAbility = { id = spellID, at = GetTime() }
end

-- The hit event does not say which of your abilities hit either. The one you used this moment is taken to be
-- it, once (Full and Subtle draw its blow); with none, or its ID kept from us, a physical hit is a plain swing.
local function StrikeOfLastCast()
    local a = lastAbility
    lastAbility = nil
    if not a or GetTime() - a.at > IM.OWN_WINDOW then return nil end
    return ns.CastLook.Strike(nil, a.id)
end

-- The game's hit event does not say who hit. Only your own hits shake and light the target frame and the
-- nameplates (a group's or a raid's all at once would be far too busy), so a hit it tells of counts when:
--   * you are not in a group (then it is yours or your pet's),
--   * it comes right after a cast of yours (a spell landing, a shot: Auto Shot is a cast too),
--   * or it is a tick in the school of an effect you put on that unit (your Serpent Sting, your Immolation Trap).
-- In a group your plain melee swings are not told apart from the others' there; the combat log, where it can
-- be read, names who hit and needs none of this.
IM.OWN_WINDOW = 0.8
-- Did you just do something (a cast of yours this moment)? A nameplate only shakes for that.
function IM.JustYou() return GetTime() - lastOwn <= IM.OWN_WINDOW end
IM.others = 0
local function YoursOn(unit, school)
    local U = ns.Unit
    local list = U and U.Filtered and U.Filtered(unit, "HARMFUL", "HARMFUL|PLAYER", 40)
    for _, a in ipairs(list or {}) do
        local id = ns.Plain(a.spellId)
        if type(id) == "number" then
            local s = IM.SCHOOL_OF[id] or IM.Guess(id)
            if not s and ns.CastLook and ns.CastLook.SchoolOf then
                local ok, k = pcall(ns.CastLook.SchoolOf, ns.Plain(a.name), id)
                s = ok and k or nil
            end
            if s == school then return true end
        end
    end
    return false
end
function IM.Mine(unit, school)
    if not (IsInGroup and ns.Yes(IsInGroup())) then return true, "alone" end
    if GetTime() - lastOwn <= IM.OWN_WINDOW then return true, "after your cast" end
    if YoursOn(unit, school) then return true, "your effect" end
    return false
end
local function LearnFromHit(mask)
    if not lastCast or GetTime() - lastCast.at > 1.0 then return end
    if ns.IsSecret(mask) or type(mask) ~= "number" or mask <= 1 then return end    -- physical says nothing
    local seen = IM.GUESSED[lastCast.id]
    if not seen then
        seen = {}
        IM.GUESSED[lastCast.id] = seen
        learned = learned + 1
    end
    local school = IM.School(mask)
    seen[school] = (seen[school] or 0) + 1
    lastCast = nil
end

-- The school guessed for a spell: the one seen most often right after it, or nil
function IM.Guess(spellID)
    local seen = IM.GUESSED[spellID]
    if not seen then return nil end
    local best, most = nil, 0
    for school, n in pairs(seen) do
        if n > most or (n == most and school < best) then best, most = school, n end
    end
    return best
end

local function FromUnit(unit, action, flag, amount, mask)
    IM.heard = IM.heard + 1
    local kind = type(unit) == "string" and not ns.IsSecret(unit) and (unit:match("^%a+") or unit) or "?"
    IM.byUnit[kind] = (IM.byUnit[kind] or 0) + 1
    if ns.IsSecret(action) or unit == "pet" then return end
    if action == "HEAL" then
        LearnFromHit(mask)
        HealLand(ns.GUID(unit), IM.School(mask), unit)
        return
    end
    if action ~= "WOUND" then return end
    if unit ~= "player" then LearnFromHit(mask) end
    if not ns.IsSecret(amount) and (not amount or amount == 0) then return end
    local crit = not ns.IsSecret(flag) and flag == "CRITICAL"
    local school = IM.School(mask)
    if unit == "player" then
        -- your own bar flashes here only when the game hides your health (otherwise it sees the drop itself)
        local UF = ns.UnitFrames
        local f = UF.frames.player
        if f and f.on and f.health.secret then
            IM:Hit({ frame = f.visual, anchor = f.button, bar = f.health }, school, crit)
        end
        -- and your bars give a small shake, a third of what your hits do to an enemy
        if ns.db.playerShake then
            local p = IM.PROFILES[school] or IM.PROFILES.physical
            for _, key in ipairs({ "player", "vertical" }) do
                local g = UF.frames[key]
                if g and g.on and not (key == "player" and g.health.secret) then
                    IM:Shake(g.visual, g.button, p, crit and 0.55 or 0.35)
                    IM.lastShake = key
                end
            end
        end
        return
    end
    if not IM.Mine(unit, school) then IM.others = IM.others + 1; return end    -- someone else's hit
    -- (a chain's total takes it only while the log is silent: where the log speaks, it has told this hit already)
    if ns.CastBar and not (IM.logAt and GetTime() - IM.logAt <= IM.LOG_QUIET) then ns.CastBar.Damage(amount) end
    Land(ns.GUID(unit), school, crit, unit, StrikeOfLastCast())   -- (a damage over time ticks here too, and shots: their school)
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", ns.Protect(function(_, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then FromLog() else FromUnit(...) end
end))

function IM:Apply(run)
    local want = run and ns.db.impacts and true or false
    if want == self.active then return end
    self.active = want
    events:UnregisterAllEvents()
    self.source = nil
    if not want then
        for frame in pairs(self.shaking) do self:Stop(frame) end
        return
    end
    local sources = {}
    if LogInfo() and pcall(events.RegisterEvent, events, "COMBAT_LOG_EVENT_UNFILTERED") then sources[#sources + 1] = "log" end
    if pcall(events.RegisterEvent, events, "UNIT_COMBAT") then sources[#sources + 1] = "unit" end
    sources[#sources + 1] = "health"        -- and a health drop on a bar of ours counts as a hit (UnitFrames, Nameplates)
    self.source = table.concat(sources, "+")
end

ns.RegisterCheck(function(row, run, db)
    if run and db.impacts then
        row("hit effects can hear hits", IM.source ~= nil,
            (IM.source or "neither the combat log nor UNIT_COMBAT") .. (", %d heard, %d shown, %d others' left out"):format(IM.heard, IM.landed, IM.others)
            .. IM.DescribeUnits())
    end
end)

-- /cchud hittest: every school once, on your target, focus and the nameplates on screen
local function DemoBars()
    local list = {}
    for _, unit in ipairs({ "target", "focus" }) do
        for _, t in ipairs(Targets(ns.GUID(unit))) do list[#list + 1] = t end
    end
    for _, o in pairs(ns.Nameplates and ns.Nameplates.plates or {}) do
        if o:IsShown() then list[#list + 1] = { frame = o, anchor = o.plate, bar = o.health } end
    end
    if #list == 0 then                        -- nothing targeted: your own frame (and the demo's target) instead
        local UF = ns.UnitFrames
        for _, key in ipairs({ "target", "player" }) do
            local f = UF.frames[key]
            if f and f.on and (key == "player" or UF.fake) then
                list[#list + 1] = { frame = f.visual, anchor = f.button, bar = f.health }
            end
        end
    end
    return list
end

ns.RegisterCommand("hittest", function()
    local list = DemoBars()
    if #list == 0 then ns.Say(L["Target something first."]); return end
    for i, entry in ipairs(IM.ORDER) do
        C_Timer.After((i - 1) * 0.6, function()
            for _, t in ipairs(list) do IM:Hit(t, entry[2], i == #IM.ORDER) end
        end)
    end
    ns.Say(L["Showing every damage school once (the last one as a crit)."])
end, "/cchud hittest", "show every damage school's hit effect once on your target and the nameplates")

-- /cchud striketest: every kind of blow once (Full and Subtle), on the same bars
IM.STRIKE_DEMO = { "slash", "cross", "claw", "stab", "bash", "arrow", "light", "storm", "rime" }
ns.RegisterCommand("striketest", function()
    local level = ns.Effects()
    if level ~= "full" and level ~= "subtle" then ns.Say(L["Blows are drawn at Full and Subtle effects only."]); return end
    local list = DemoBars()
    if #list == 0 then ns.Say(L["Target something first."]); return end
    for i, key in ipairs(IM.STRIKE_DEMO) do
        C_Timer.After((i - 1) * 0.6, function()
            for _, t in ipairs(list) do IM:Hit(t, "physical", i == #IM.STRIKE_DEMO, nil, ns.CastLook.STRIKES[key]) end
        end)
    end
    ns.Say(L["Showing every kind of blow once (the last one as a crit)."])
end, "/cchud striketest", "show every kind of melee blow and shot once on your target and the nameplates")

ns.RegisterModule("impact", IM)
