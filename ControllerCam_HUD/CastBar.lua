-- ControllerCam HUD: your cast bar.
-- Drawn where the game's own cast bar sits, so moving that one in Edit Mode moves ours. The game's bar is
-- put aside while ours runs.

local ADDON, ns = ...
local L, C, U = ns.L, ns.colors, ns.Unit

local CB = { active = false }
CB.TIME_ROOM = 44              -- what the time under the bar's right end takes
-- The name, the time and the chain's count (right of the time), all under the bar, keep this far from it: what plays on the bar as
-- it fills (leaves, roots; CastArt.lua) reaches 16 beyond it, and mostly upwards, which is why nothing of ours is
-- written over the bar (that space is kept free, for what may one day show there). While fishing nothing grows
-- there, and they stay close (the fishing game's words are further down).
CB.ROOM = 16
CB.CLOSE_OVER, CB.CLOSE_UNDER = 4, 5
-- The time grows as the cast nears its end (over its last second, or its last half if it is shorter), then
-- bursts and fades as the cast lands: this much larger at the end, this much more in the burst, this long
CB.GROW, CB.GROWTH, CB.BURST, CB.POP = 1, 0.7, 0.8, 0.3
-- A chain of casts: the next one counts if it starts this soon after the last one landed. A cast landed if it
-- ran to within CHAIN_SLACK of its end (a channel: at least half of it). The count jumps for BUMP seconds.
CB.CHAIN_GAP, CB.CHAIN_SLACK, CB.BUMP = 0.75, 0.35, 0.25
-- A long chain's count grows, a little with every cast: this much each, up to this many casts (x50: half as large again)
CB.CHAIN_GROW, CB.CHAIN_CAP = 0.01, 50
-- Behind the count the spell's own effect plays: a glow that beats and drops of it raining through the count,
-- more, larger and quicker with every cast of the chain, at their most from this many casts on
CB.RAIN_CAP = 25
CB.CHAIN_X = 4                 -- the count starts this far past the bar's right end: the eye runs along the bar to it
CB.TIME_MID = 5                -- half the time's height: the count is centred on the time's line, whatever its own size
CB.CHAIN_SIZE = 0.9            -- and starts out this much of its font's size, to grow from there
ns.CastBar = CB

ns.RegisterSetting({
    key = "castWindup", kind = "boolean", default = true, command = "windup", section = "Frames",
    label = "Cast wind-up", tip = "your cast bar glows brighter as the cast fills and bursts when it lands",
})
ns.RegisterSetting({
    key = "castChain", kind = "boolean", default = true, command = "chain", section = "Frames",
    label = "Chain cast count",
    tip = "when you cast one spell straight after another, a count of the chain shows under your cast bar, to the right of the cast time, with the damage you dealt during it in small numbers beside it; the spell's own effect plays behind the count, stronger as the chain grows; it ends when you stop, move or are interrupted",
})
ns.RegisterSetting({
    key = "castBoost", kind = "boolean", default = true, command = "castboost", section = "Frames",
    label = "Effects that help your cast",
    tip = "while you cast, up to three icons over the right end of your cast bar show the effects on you that make this cast faster, free or stronger, with how many are left (x3), so you see a proc being used without looking away to your buffs; only the ones the game lets an addon tell apart: it lights the spell up, the effect names the spell, or it is a well-known one",
})
ns.RegisterSetting({
    key = "fishing", kind = "boolean", default = true, command = "fishing", section = "Frames",
    label = "Fishing float", tip = "while fishing, a float bobs on your cast bar and it shows what is likely to bite here",
})
ns.RegisterSetting({
    key = "castbar", kind = "boolean", default = true, command = "castbar", section = "Frames",
    label = "Cast bar", tip = "our cast bar in place of the game's (it stays where Edit Mode puts the game's)",
})

ns.RegisterSetting({
    key = "castScale", kind = "number", default = 1.35, min = 0.8, max = 2, percent = true, command = "castsize",
    section = "Frames", label = "Cast bar size",
    tip = "how large your cast bar is drawn, with the fishing float and everything else that plays on it",
})

ns.RegisterSetting({
    key = "castUpright", kind = "boolean", default = false, command = "castupright", section = "Frames",
    label = "Cast bar beside the vertical bars",
    tip = "with the vertical bars on, your cast runs on a slim upright bar on the right of your mana, with a small timer and no text, in place of the cast bar under you (fishing keeps its own)",
})

ns.RegisterSetting({
    key = "fishBig", kind = "boolean", default = true, command = "fishbig", section = "Frames",
    label = "Fishing front and centre",
    tip = "while you fish, the cast bar moves to the middle of the screen and is drawn larger: the line, the float and what bites are the main event",
})

local NATIVE = "PlayerCastingBarFrame"
local FISH_SCALE, FISH_Y = 1.5, -100          -- while fishing: this much larger, this far under the middle of the screen
local W, H = 260, 12
local LINE = 2                -- while fishing the bar is the line: thin, with the float at its end
local LINGER = 0.45           -- how long the result (done, interrupted) stays on screen
local LINE_DOTS = 22          -- the fishing line is drawn as this many points along a curve
local TIP_X, TIP_Y = 0.1, 46  -- where it leads: this share along the bar, this far above it
local WATER = { kind = "fishing", color = { 0.6, 0.84, 1 } }

local frame, bar
local FISHING = { [7620] = true, [7731] = true, [7732] = true, [18248] = true, [33095] = true, [51294] = true,
                  [88868] = true, [110410] = true, [131474] = true, [158743] = true }
local LANDED = { color = C.cast, fx = { kind = "rays", tex = "spark", count = 5, size = 16, life = 0.45, speed = 50 } }

local function Build()
    frame = CreateFrame("Frame", "ControllerCamHUD_CastBar", UIParent)
    frame:SetSize(W, H + 16)
    frame:SetFrameStrata("MEDIUM")
    bar = ns.CreateBar(frame, W, H)
    bar:SetPoint("BOTTOM", frame, "BOTTOM", 0, 0)
    bar.spark = bar.over:CreateTexture(nil, "OVERLAY")
    bar.spark:SetTexture(ns.media.spark)
    bar.spark:SetBlendMode("ADD")
    bar.spark:SetSize(18, 18)
    bar.spark:SetPoint("CENTER", bar.fill:GetStatusBarTexture(), "RIGHT", 0, 0)
    -- the wind-up: a glow under the bar that builds as the cast fills
    bar.charge = frame:CreateTexture(nil, "BACKGROUND")
    bar.charge:SetTexture(ns.media.soft)
    bar.charge:SetPoint("TOPLEFT", bar, "TOPLEFT", -18, 14)
    bar.charge:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 18, -14)
    bar.charge:SetBlendMode("ADD")
    bar.charge:SetAlpha(0)
    -- fishing: a float riding the end of the bar, and what bites here
    bar.bobber = bar.over:CreateTexture(nil, "OVERLAY")
    bar.bobber:SetTexture(ns.media.bobber)
    bar.bobber:SetSize(22, 22)
    bar.bobber:Hide()
    -- and the line: loose, from the top of the float up to where a rod's tip would be, fading as it climbs
    bar.line = {}
    for i = 1, LINE_DOTS do
        local dot = bar.over:CreateTexture(nil, "ARTWORK")
        dot:SetColorTexture(0.88, 0.94, 1, 1)
        dot:SetSize(1.6, 1.6)
        dot:Hide()
        bar.line[i] = dot
    end
    frame.catch = ns.FontString(frame, 10, "LEFT")
    frame.catch:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 8, -5)
    frame.catch:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", -CB.TIME_ROOM, -5)    -- clear of the time beside it
    if frame.catch.SetWordWrap then frame.catch:SetWordWrap(false) end
    frame.catch:SetTextColor(unpack(C.muted))
    frame.catchIcon = frame:CreateTexture(nil, "ARTWORK")
    frame.catchIcon:SetSize(18, 18)
    frame.catchIcon:SetPoint("RIGHT", frame.catch, "LEFT", -4, 0)
    frame.catchIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    frame.catch:Hide()
    frame.catchIcon:Hide()
    -- the name under the bar, from its left end to the time at its right end (a longer one ends in "..." rather
    -- than run into the time)
    frame.label = ns.FontString(frame, 11, "LEFT")
    frame.label:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 8, -CB.ROOM)
    frame.label:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", -CB.TIME_ROOM, -CB.ROOM)
    if frame.label.SetWordWrap then frame.label:SetWordWrap(false) end
    -- (in a holder of its own, which is what grows: a frame scales smoothly, a font's size does not)
    frame.timeBox = CreateFrame("Frame", nil, frame)
    frame.timeBox:SetSize(1, 1)
    frame.timeBox:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", -8, -CB.ROOM)
    frame.time = ns.FontString(frame.timeBox, 10, "RIGHT")
    frame.time:SetPoint("TOPRIGHT", frame.timeBox, "TOPRIGHT", 0, 0)
    frame.time:SetTextColor(unpack(C.muted))
    -- how many casts in a row, to the right of the time: on its line, just past the bar's right end, where the
    -- eye ends up as it follows the bar (in a holder too: it jumps)
    frame.comboBox = CreateFrame("Frame", nil, frame)
    frame.comboBox:SetSize(1, 1)
    frame.comboBox:SetPoint("TOPLEFT", bar, "BOTTOMRIGHT", CB.CHAIN_X, -CB.ROOM - CB.TIME_MID)
    frame.combo = ns.FontString(frame.comboBox, 12, "LEFT")
    frame.combo:SetPoint("LEFT", frame.comboBox, "TOPLEFT", 0, 0)      -- (its middle on the holder's corner)
    frame.combo:Hide()
    -- behind it, the glow of the spell being chained (and its drops: Rain below)
    frame.comboGlow = frame.comboBox:CreateTexture(nil, "BACKGROUND")
    frame.comboGlow:SetTexture(ns.media.soft)
    frame.comboGlow:SetBlendMode("ADD")
    frame.comboGlow:SetPoint("CENTER", frame.combo, "CENTER", 0, 0)
    frame.comboGlow:SetAlpha(0)
    -- and beside the count, smaller: the damage you dealt while the chain ran, cut short ("1.2k")
    frame.comboSum = ns.FontString(frame.comboBox, 9, "LEFT")
    frame.comboSum:SetPoint("BOTTOMLEFT", frame.combo, "BOTTOMRIGHT", 5, 1)
    frame.comboSum:SetTextColor(unpack(C.muted))
    frame.comboSum:Hide()
    -- over the bar's right end: the effects on you that make this cast better (Boosts below)
    frame.boostRow = CreateFrame("Frame", nil, frame)
    frame.boostRow:SetSize(CB.BOOST_MAX * (CB.BOOST_ICON + CB.BOOST_GAP), CB.BOOST_ICON)
    frame.boostRow:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", 0, CB.ROOM)
    frame:Hide()
    CB.frame, CB.bar = frame, bar
    CB.art = ns.CastArt.Attach(bar, 1)                 -- what works on the bar while it fills (CastArt.lua)
end

-- The fishing line: a loose curve from the top of the float (x along the bar, y above it) up to where a rod's
-- tip would be. It hangs slack, sways a little, and fades out towards the top: it leads to nowhere on screen.
local function DrawLine(x, y, now)
    local tx, ty = W * TIP_X, TIP_Y
    local slack = 8 + 10 * (1 - math.min(1, math.abs(x - tx) / W))      -- looser as the float comes in
    local cx = (x + tx) / 2 + math.sin(now * 1.1) * 5
    local cy = (y + ty) / 2 - slack - math.sin(now * 1.7) * 3
    for i, dot in ipairs(bar.line) do
        local t = (i - 1) / (LINE_DOTS - 1)
        local a, b, c = (1 - t) * (1 - t), 2 * (1 - t) * t, t * t
        dot:ClearAllPoints()
        dot:SetPoint("CENTER", bar, "BOTTOMLEFT", a * x + b * cx + c * tx, a * y + b * cy + c * ty)
        dot:SetAlpha(0.8 * (1 - t) ^ 0.7)
        dot:Show()
    end
end

local function HideLine()
    for _, dot in ipairs(bar.line) do dot:Hide() end
end

-- The time at this size, its top right corner staying where it is (a scaled frame's offsets scale with it)
local function TimeScale(s)
    local box = frame.timeBox
    CB.timeScale = s
    box:SetScale(s)
    box:ClearAllPoints()
    box:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", -8 / s, -(CB.under or CB.ROOM) / s)
end

-- The time as it usually is: small and quiet
local function TimeRest()
    CB.grown, CB.pop = nil, nil
    TimeScale(1)
    frame.time:SetAlpha(1)
    frame.time:SetTextColor(unpack(C.muted))
end

-- It grows and takes the cast's colour as the end comes, trembling just before it (Full; half as much at
-- Subtle). Part of the wind-up, so not with that off, with Reduce animations, or while fishing.
local function TimeGrow(remain, now)
    local level = ns.Effects()
    local k = 0
    if ns.db.castWindup and not CB.fishing and not ns.Calm() and (level == "full" or level == "subtle") then
        k = ns.Clamp(1 - remain / math.min(CB.GROW, (CB.stop - CB.start) / 2), 0, 1)
    end
    if k <= 0 then
        if CB.grown then TimeRest() end
        return
    end
    local full = level == "full"
    local s = 1 + (full and CB.GROWTH or CB.GROWTH / 2) * k * k
    if full and k > 0.7 then s = s + 0.03 * math.sin(now * 40) end
    CB.grown = true
    TimeScale(s)
    local m, c = C.muted, CB.color or C.cast
    frame.time:SetTextColor(m[1] + (c[1] - m[1]) * k, m[2] + (c[2] - m[2]) * k, m[3] + (c[3] - m[3]) * k)
end

-- The cast landed: the time bursts outwards and fades (at Subtle it only fades)
local function Pop(now)
    local pop = CB.pop
    if not pop then return end
    local k = (now - pop.at) / CB.POP
    if k >= 1 or k < 0 then
        frame.time:SetText("")
        TimeRest()
        return
    end
    TimeScale(pop.from + (pop.burst and CB.BURST * (1 - (1 - k) * (1 - k)) or 0))
    frame.time:SetAlpha(1 - k)
end

-- The chain's count at this size, its left end staying where it is and its middle level with the time's
local function ComboScale(s)
    local box = frame.comboBox
    CB.comboScale = s
    box:SetScale(s)
    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", bar, "BOTTOMRIGHT", CB.CHAIN_X / s, -((CB.under or CB.ROOM) + CB.TIME_MID) / s)
end

-- The size a chain's count rests at: its own for a usual chain (x5 is 5% larger, which nobody sees), larger for a long one
local function ComboBase()
    local n = CB.combo or 0
    if n < 2 then return CB.CHAIN_SIZE end
    return CB.CHAIN_SIZE * (1 + CB.CHAIN_GROW * math.min(n, CB.CHAIN_CAP))
end

-- A chain's damage, cut short: 950, 1.2k, 15.3k, 120k, 1.2m
function CB.Short(n)
    if n < 1000 then return tostring(math.floor(n)) end
    if n < 99950 then return ("%.1fk"):format(n / 1e3) end
    if n < 999500 then return ("%dk"):format(math.floor(n / 1e3 + 0.5)) end
    return ("%.1fm"):format(n / 1e6)
end

-- "x3" from the second cast of a chain on, in the colour of the cast under way; beside it the chain's damage
local function ComboDraw()
    local n = CB.combo or 0
    if n < 2 or not ns.db.castChain or CB.fishing then
        frame.combo:Hide()
        frame.comboSum:Hide()
        CB.bump = nil
        return
    end
    local c = CB.color or C.cast
    frame.combo:SetText("x" .. n)
    frame.combo:SetTextColor(c[1], c[2], c[3])
    frame.combo:Show()
    if not CB.bump then ComboScale(ComboBase()) end
    local sum = CB.comboDamage or 0
    if sum > 0 and not CB.comboUnknown then
        frame.comboSum:SetText(CB.Short(sum))
        frame.comboSum:Show()
    else
        frame.comboSum:Hide()
    end
end

-- Damage of yours while a chain runs (Impact.lua hears it: the combat log, or the game's hit event where the
-- log says nothing). The first cast's counts too. An amount the game keeps to itself cannot be added, and a
-- total that leaves it out would be wrong: that chain shows no total.
function CB.Damage(amount)
    if (CB.combo or 0) < 1 or not CB.frame then return end
    if ns.IsSecret(amount) or type(amount) ~= "number" then
        CB.comboUnknown = true
    else
        CB.comboDamage = (CB.comboDamage or 0) + amount
    end
    ComboDraw()
end

-- It jumps as the chain grows, and settles
local function ComboTick(now)
    local at = CB.bump
    if not at then return end
    local k = (now - at) / CB.BUMP
    if k >= 1 or k < 0 then
        CB.bump = nil
        ComboScale(ComboBase())
    else
        ComboScale(ComboBase() * (1 + 0.5 * (1 - k) * (1 - k)))
    end
end

---------------------------------------------------------------------------
-- Behind the count: the spell being chained. A glow in its colour beats there, and drops of its effect (sparks,
-- motes, runes: its look's own particles) rain through the count; fire and smoke rise through it instead. All of
-- it grows with the chain, to its most at x25 (CB.RAIN_CAP). Full: glow and rain; Subtle: the glow only; not at
-- Classic or None, nor with Reduce animations. The pieces are the count's own, used again and again.
---------------------------------------------------------------------------
local RISES = { flames = true, smoke = true }
local rain = { live = {}, pool = {}, owe = 0 }
CB.rain = rain

-- How far the chain has come, 0-1 (nil: nothing plays), and whether drops fall too
function CB.Heat()
    local n = CB.combo or 0
    if n < 2 or not ns.db.castChain or CB.fishing or ns.Calm() then return nil end
    local level = ns.Effects()
    if level ~= "full" and level ~= "subtle" then return nil end
    return (math.min(n, CB.RAIN_CAP) - 1) / (CB.RAIN_CAP - 1), level == "full"
end

local function RainDrop(heat, c, wide)
    local t = table.remove(rain.pool)
    if not t then
        t = frame.comboBox:CreateTexture(nil, "BACKGROUND")           -- (behind the count's letters)
        t:SetBlendMode("ADD")
    end
    local fx = CB.look and CB.look.fx
    local up = fx and RISES[fx.kind] or false
    t:SetTexture(ns.media[fx and fx.tex or "soft"])
    t:SetVertexColor(c[1], c[2], c[3], 1)
    local size = (4 + 5 * heat) * (0.7 + 0.6 * math.random())
    t:SetSize(size, size)
    t.x, t.drift = -4 + math.random() * (wide + 8), (math.random() - 0.5) * 6
    local top, foot = 16 + 10 * heat, -1
    t.y0, t.y1 = up and foot or top, up and top or foot
    t.age, t.life, t.a = 0, 0.7 - 0.25 * heat, 0.5 + 0.4 * heat
    t:SetAlpha(0)
    t:Show()
    rain.live[#rain.live + 1] = t
end

local function RainClear()
    for i = #rain.live, 1, -1 do
        local t = rain.live[i]
        t:Hide()
        rain.pool[#rain.pool + 1] = t
        rain.live[i] = nil
    end
    rain.at, rain.owe = nil, 0
    frame.comboGlow:SetAlpha(0)
end

local function RainTick(now)
    local dt = math.max(0, math.min(0.1, now - (rain.at or now)))
    rain.at = now
    local heat, full = CB.Heat()
    if not heat or not frame.combo:IsShown() then
        frame.comboGlow:SetAlpha(0)
    else
        local c = CB.color or C.cast
        local wide = frame.combo.GetStringWidth and frame.combo:GetStringWidth() or 0
        if ns.IsSecret(wide) or type(wide) ~= "number" or wide < 12 then wide = 24 end
        frame.comboGlow:SetVertexColor(c[1], c[2], c[3], 1)
        frame.comboGlow:SetSize(wide + 26, 30)
        frame.comboGlow:SetAlpha((0.12 + 0.3 * heat) * (0.75 + 0.25 * math.sin(now * (3 + 9 * heat))))
        if full then
            rain.owe = rain.owe + dt * (2 + 26 * heat)                -- two a second at x2, twenty-eight at x25
            while rain.owe >= 1 do
                rain.owe = rain.owe - 1
                RainDrop(heat, c, wide)
            end
        end
    end
    for i = #rain.live, 1, -1 do
        local t = rain.live[i]
        t.age = t.age + dt
        local k = t.age / t.life
        if k >= 1 then
            t:Hide()
            table.remove(rain.live, i)
            rain.pool[#rain.pool + 1] = t
        else
            t:ClearAllPoints()
            t:SetPoint("CENTER", frame.combo, "BOTTOMLEFT", t.x + t.drift * k, t.y0 + (t.y1 - t.y0) * k)
            t:SetAlpha(t.a * (k < 0.2 and k / 0.2 or 1 - (k - 0.2) / 0.8))
        end
    end
end

---------------------------------------------------------------------------
-- Over the bar's right end: the effects on you that make this cast better (faster, free, stronger), as a small
-- row of icons with how many are left ("x3"). The game does not tell addons which effect changes which spell,
-- so an effect is only shown when one of these says so:
--   lit    the game lights the spell being cast (its glow on the action bar), and the effect is the one the game
--          showed its screen art for, or came on within BOOST_NEAR of the glow
--   known  it is one of the well-known ones below, and this cast is one of the spells it is for
--   says   the effect's own description names the spell being cast
-- What the game keeps secret is never compared: an effect whose id and name are both secret can only be "lit"
-- (by when it came on), and a cast whose id and name are secret shows nothing.
---------------------------------------------------------------------------
CB.BOOST_MAX, CB.BOOST_ICON, CB.BOOST_GAP = 3, 18, 4
CB.BOOST_NEAR = 0.5            -- an effect and a glow this close together belong together
CB.BOOST_IN = 0.2              -- an icon fades in this fast

-- The well-known ones, by the effect's spell ids (other ranks go by name), and the spells each is for (by name
-- too: every rank has an id of its own); any: whatever you cast
CB.BOOSTS = {
    { ids = { 12536, 16870, 16246, 263725 }, any = true },                              -- Clearcasting
    { ids = { 14751 }, any = true },                                                    -- Inner Focus
    { ids = { 16166 }, any = true },                                                    -- Elemental Mastery
    { ids = { 59887, 59888, 59889, 59890, 59891 }, any = true },                        -- Borrowed Time
    { ids = { 54274, 54276, 54277, 117828 }, any = true },                              -- Backdraft
    { ids = { 20216 }, spells = { 635, 19750, 82326 } },                                -- Divine Favor
    { ids = { 31834 }, spells = { 635 } },                                              -- Light's Grace
    { ids = { 53672, 54149 }, spells = { 635, 19750, 82326 } },                         -- Infusion of Light
    { ids = { 53489, 59578 }, spells = { 19750, 879 } },                                -- The Art of War
    { ids = { 17941 }, spells = { 686 } },                                              -- Shadow Trance
    { ids = { 34936 }, spells = { 686, 29722 } },                                       -- Backlash
    { ids = { 63167 }, spells = { 6353 } },                                             -- Decimation
    { ids = { 47383, 71162, 71165 }, spells = { 29722, 6353 } },                        -- Molten Core
    { ids = { 53817, 344179 }, spells = { 403, 421, 331, 8004, 1064, 51514, 188196, 188443 } },   -- Maelstrom Weapon
    { ids = { 53390 }, spells = { 331, 8004, 77472 } },                                 -- Tidal Waves
    { ids = { 77762 }, spells = { 51505 } },                                            -- Lava Surge
    { ids = { 33151, 114255 }, spells = { 585, 2061 } },                                -- Surge of Light
    { ids = { 63731, 63734, 63735 }, spells = { 2060, 596 } },                          -- Serendipity
    { ids = { 48108 }, spells = { 11366 } },                                            -- Hot Streak
    { ids = { 57761, 190446 }, spells = { 133, 44614 } },                               -- Brain Freeze
    { ids = { 44401 }, spells = { 5143 } },                                             -- Missile Barrage
    { ids = { 48517 }, spells = { 5176 } },                                             -- Eclipse (Solar): Wrath
    { ids = { 48518 }, spells = { 2912 } },                                             -- Eclipse (Lunar): Starfire
}

local boost = { icons = {}, seen = {}, lit = {}, litNames = {}, art = {}, desc = {} }
CB.boost = boost

local function BoostSpellName(id)
    local ok, n
    if C_Spell and C_Spell.GetSpellName then ok, n = pcall(C_Spell.GetSpellName, id) end
    if not (ok and type(n) == "string" and not ns.IsSecret(n)) and GetSpellInfo then ok, n = pcall(GetSpellInfo, id) end
    if ok and type(n) == "string" and not ns.IsSecret(n) and n ~= "" then return n end
end

-- The well-known ones as this client names them (asked once: a spell this client does not have has no name)
local function Known()
    if boost.known then return boost.known end
    local k = { ids = {}, names = {} }
    for _, entry in ipairs(CB.BOOSTS) do
        local e = { any = entry.any, spells = {}, spellNames = {} }
        for _, id in ipairs(entry.spells or {}) do
            e.spells[id] = true
            local n = BoostSpellName(id)
            if n then e.spellNames[n] = true end
        end
        for _, id in ipairs(entry.ids) do
            k.ids[id] = e
            local n = BoostSpellName(id)
            if n and not k.names[n] then k.names[n] = e end
        end
    end
    boost.known = k
    return k
end

-- Does this text name the spell? (the whole name: "Heal" is not named by "Healing")
local function Names(text, name)
    local from = 1
    while true do
        local a, b = text:find(name, from, true)
        if not a then return false end
        if not text:sub(a - 1, a - 1):find("^%a") and not text:sub(b + 1, b + 1):find("^%a") then return true end
        from = b + 1
    end
end

-- An effect's description, as the game words it (kept once it has one: it may not be loaded at first)
local function Describe(id)
    local d = boost.desc[id]
    if d then return d end
    local get = (C_Spell and C_Spell.GetSpellDescription) or GetSpellDescription
    if not get then return nil end
    local ok, text = pcall(get, id)
    if ok and type(text) == "string" and not ns.IsSecret(text) and text ~= "" then
        boost.desc[id] = text
        return text
    end
end

-- The effects on you (the game's list; one by one on a client without it)
local function Buffs()
    if ns.UnitFrames.fake then return {} end
    local get = C_UnitAuras and C_UnitAuras.GetUnitAuras
    if get then
        local ok, all = pcall(get, "player", "HELPFUL")
        if ok and type(all) == "table" then return all end
    end
    local list = {}
    for i = 1, 40 do
        local a = U.Aura("player", i, "HELPFUL")
        if type(a) ~= "table" then break end
        list[#list + 1] = a
    end
    return list
end

-- When each effect on you was first seen (first: they were there already, for who knows how long)
local function BoostScan(first)
    local now, here = GetTime(), {}
    for _, a in ipairs(Buffs()) do
        local inst
        if type(a) == "table" then inst = a.auraInstanceID end
        if not ns.IsSecret(inst) and inst ~= nil then
            here[inst] = boost.seen[inst] or (first and -1e9 or now)
        end
    end
    boost.seen = here
end

-- Does the game light this spell? And since when, where its glow was seen coming on
local function Lit(id, name)
    local at = (id and boost.lit[id]) or (name and boost.litNames[name])
    if at then return true, at end
    local ask = (C_SpellActivationOverlay and C_SpellActivationOverlay.IsSpellOverlayed) or IsSpellOverlayed
    if id and ask then
        local ok, on = pcall(ask, id)
        if ok and ns.Yes(on) then return true, nil end
    end
    return false
end

-- The effects that make this cast better, the surest first: { aura, why } each, at most BOOST_MAX
function CB.BoostPick(castName, castID)
    castName = (type(castName) == "string" and not ns.IsSecret(castName) and castName ~= "") and castName or nil
    castID = (type(castID) == "number" and not ns.IsSecret(castID)) and castID or nil
    if not castName and not castID then return {} end
    local lit, litAt = Lit(castID, castName)
    local known = Known()
    local found = { lit = {}, known = {}, says = {} }
    for _, a in ipairs(Buffs()) do
        if type(a) == "table" then
            local id, name, inst = a.spellId, a.name, a.auraInstanceID
            if ns.IsSecret(id) or type(id) ~= "number" then id = nil end
            if ns.IsSecret(name) or type(name) ~= "string" then name = nil end
            if ns.IsSecret(inst) then inst = nil end
            local why
            if lit then
                local seen = inst ~= nil and boost.seen[inst] or nil
                if id and boost.art[id] then why = "lit"
                elseif seen and litAt and math.abs(seen - litAt) <= CB.BOOST_NEAR then why = "lit" end
            end
            if not why then
                local e = (id and known.ids[id]) or (name and known.names[name])
                if e and (e.any or (castID and e.spells[castID]) or (castName and e.spellNames[castName])) then
                    why = "known"
                end
            end
            if not why and id and castName and #castName >= 3 and name ~= castName then
                local text = Describe(id)
                if text and Names(text, castName) then why = "says" end
            end
            if why then found[why][#found[why] + 1] = { aura = a, why = why, name = name } end
        end
    end
    local list = {}
    for _, why in ipairs({ "lit", "known", "says" }) do
        for _, hit in ipairs(found[why]) do
            if #list < CB.BOOST_MAX then list[#list + 1] = hit end
        end
    end
    return list
end

local function BoostButton(i)
    local b = boost.icons[i]
    if b then return b end
    b = CreateFrame("Frame", nil, frame.boostRow)
    b:SetSize(CB.BOOST_ICON, CB.BOOST_ICON)
    b:SetPoint("BOTTOMRIGHT", frame.boostRow, "BOTTOMRIGHT", -(i - 1) * (CB.BOOST_ICON + CB.BOOST_GAP), 0)
    b.back = b:CreateTexture(nil, "BACKGROUND")
    b.back:SetPoint("TOPLEFT", b, "TOPLEFT", -1, 1)
    b.back:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 1, -1)
    b.back:SetColorTexture(0.02, 0.03, 0.06, 0.9)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints(b)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.count = ns.FontString(b, 10, "RIGHT")
    b.count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 3, -3)
    b:Hide()
    boost.icons[i] = b
    return b
end

local function BoostHide()
    for _, b in ipairs(boost.icons) do b:Hide(); b.key, b.at = nil, nil end
    boost.shown = 0
end

-- How many of an effect are left: "x3" from two on. A number the game keeps secret is written by the game
-- itself, where this client has the call for it (then without the x: there is no telling whether it is one).
local function BoostCount(b, a)
    local n = a.applications
    if not ns.IsSecret(n) then
        b.count:SetText((type(n) == "number" and n > 1) and ("x" .. n) or "")
        return
    end
    local get, inst = C_UnitAuras and C_UnitAuras.GetAuraApplicationDisplayCount, a.auraInstanceID
    local ok = get and pcall(function() b.count:SetText(get("player", inst, 2, 99)) end)
    if not ok then b.count:SetText("") end
end

-- Draw the row for the cast under way. Never while fishing, with the upright bar, for the show of all casts,
-- or while making things.
function CB:Boosts()
    if not frame then return end
    local trade = not ns.IsSecret(self.castTrade) and self.castTrade
    if not (ns.db.castBoost and self.casting and not self.fishing and not self.up and not self.demo) or trade then
        BoostHide()
        return
    end
    local list = CB.BoostPick(self.castName, self.castID)
    local level = ns.Effects()
    local fade = (not ns.Calm() and (level == "full" or level == "subtle")) and GetTime() or nil
    frame.boostRow:ClearAllPoints()
    frame.boostRow:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", 0, self.over or CB.ROOM)   -- clear of what plays on the bar
    local said = {}
    for i, hit in ipairs(list) do
        local b, a = BoostButton(i), hit.aura
        local key = ns.Plain(a.auraInstanceID) or ns.Plain(a.spellId) or i
        pcall(b.icon.SetTexture, b.icon, a.icon)
        BoostCount(b, a)
        if b.key ~= key or not b:IsShown() then          -- a new one fades in; one that stays just stays
            b.key, b.at = key, fade
            b:SetAlpha(fade and 0 or 1)
        end
        b:Show()
        said[i] = ("%s (%s)"):format(tostring(hit.name or "?"), hit.why)
    end
    for i = #list + 1, #boost.icons do
        local b = boost.icons[i]
        b:Hide(); b.key, b.at = nil, nil
    end
    boost.shown = #list
    if ns.Debug and #said > 0 then
        local text = table.concat(said, ", ")
        if text ~= boost.said then boost.said = text; ns.Note("cast helped by: %s", text) end
    end
end

local function BoostTick(now)
    for i = 1, boost.shown or 0 do
        local b = boost.icons[i]
        if b.at then
            local k = (now - b.at) / CB.BOOST_IN
            if k >= 1 or k < 0 then b.at = nil; b:SetAlpha(1) else b:SetAlpha(k) end
        end
    end
end

-- What is listened for while the row is wanted: your effects coming and going, and what the game lights up
local boostEvents = CreateFrame("Frame")
local BoostEvent = ns.Protect(function(_, event, a1)
    local now = GetTime()
    if event == "UNIT_AURA" then
        if a1 ~= "player" then return end
        BoostScan()
    elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" or event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
        if ns.IsSecret(a1) or type(a1) ~= "number" then return end
        local at = event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" and now or nil
        boost.lit[a1] = at
        local name = BoostSpellName(a1)
        if name then boost.litNames[name] = at end
    elseif event == "SPELL_ACTIVATION_OVERLAY_SHOW" then
        if ns.IsSecret(a1) or type(a1) ~= "number" then return end
        boost.art[a1] = now
    elseif event == "SPELL_ACTIVATION_OVERLAY_HIDE" then
        if ns.IsSecret(a1) or type(a1) ~= "number" then boost.art = {} else boost.art[a1] = nil end
    end
    if CB.casting then CB:Boosts() end
end)

function CB.BoostApply(want)
    want = want and true or false
    if want == (boost.on or false) then return end
    boost.on = want
    if want then
        if not pcall(boostEvents.RegisterUnitEvent, boostEvents, "UNIT_AURA", "player") then
            pcall(boostEvents.RegisterEvent, boostEvents, "UNIT_AURA")
        end
        for _, e in ipairs({ "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE",
                             "SPELL_ACTIVATION_OVERLAY_SHOW", "SPELL_ACTIVATION_OVERLAY_HIDE" }) do
            pcall(boostEvents.RegisterEvent, boostEvents, e)
        end
        boostEvents:SetScript("OnEvent", BoostEvent)
        boost.seen = {}
        BoostScan(true)
    else
        boostEvents:UnregisterAllEvents()
        boostEvents:SetScript("OnEvent", nil)
        boost.seen, boost.lit, boost.litNames, boost.art = {}, {}, {}, {}
        if frame then BoostHide() end
    end
end

-- The name's, the time's and the count's distance under the bar (more: what a main ability's show reaches
-- beyond the usual)
local function Clearance(fishing, more)
    local room = CB.ROOM + (more or 0)
    local over, under = fishing and CB.CLOSE_OVER or room, fishing and CB.CLOSE_UNDER or room
    CB.room, CB.under, CB.over = room, under, over
    frame.label:ClearAllPoints()
    frame.label:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 8, -under)
    frame.label:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", -CB.TIME_ROOM, -under)
    TimeScale(CB.timeScale or 1)
    ComboScale(CB.comboScale or 1)
end

local function Place()
    local k = ns.db.castScale or 1
    frame:ClearAllPoints()
    if CB.fishing and ns.db.fishBig then             -- the main event: in the middle, where you look
        k = k * FISH_SCALE
        frame:SetScale(k)
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, FISH_Y / k)
        return
    end
    frame:SetScale(k)                                -- (it grows up and out from where the game's bar sits)
    local native = _G[NATIVE]
    if native then
        frame:SetPoint("BOTTOM", native, "BOTTOM", 0, 0)
    else
        frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 294)
    end
end

---------------------------------------------------------------------------
-- Upright, beside the vertical bars (an option): the same cast on a slim bar on the right of your mana, a small
-- timer on top and no text; the cast bar under you then stands aside (it still runs, unseen). Never for
-- fishing, whose float and line need the long bar.
---------------------------------------------------------------------------
local function UprightFrame()
    local UF = ns.UnitFrames
    local v = UF and UF.frames and UF.frames.vertical
    if not (ns.db.castUpright and v and v.on and v.upCast) or CB.fishing or CB.demo then return nil end
    return v
end

local function UpHide()
    local v = CB.up
    CB.up = nil
    if frame then frame:SetAlpha(1) end
    if v then v.upCast:Hide(); v.upCastTime:Hide() end
end

local function UpShow(color)
    local v = UprightFrame()
    if not v then UpHide(); return end
    CB.up = v
    frame:SetAlpha(0)
    v.upCast:SetColor(unpack(color))
    v.upCast.fill:SetMinMaxValues(0, 1)
    v.upCast.fill:SetAlpha(1)
    v.upCast:Show()
    v.upCastTime:SetText("")
    v.upCastTime:Show()
end
CB.UprightFrame = UprightFrame

-- The bar jolts as one of the main abilities fires (Full only), in the way of its school's hits
local KICK = 0.25
local function Jolt(now)
    local j = CB.kick
    if not j then return end
    local k = (now - j.at) / KICK
    local dx, dy = 0, 0
    if k >= 1 or k < 0 then
        CB.kick = nil
    else
        local amp, t = j.amp * (1 - k), (now - j.at) * j.freq
        dx = j.axis ~= "y" and math.sin(t) * amp or 0
        dy = j.axis ~= "x" and math.cos(t * 1.3) * amp * 0.7 or 0
    end
    bar:ClearAllPoints()
    bar:SetPoint("BOTTOM", frame, "BOTTOM", dx, dy)
    CB.jolt = dx ~= 0 or dy ~= 0
end

local function Stop()
    frame:SetScript("OnUpdate", nil)
    frame:Hide()
    UpHide()
    if CB.kick or CB.jolt then CB.kick = nil; Jolt(0) end
    TimeRest()
    CB.bump = nil
    ComboScale(ComboBase())                           -- (the count itself outlives the bar: a chain goes on)
    RainClear()
    BoostHide()
    CB.casting, CB.until_, CB.fishing, CB.look, CB.nextFx = false, nil, false, nil, nil
    bar.charge:SetAlpha(0)
    bar.bobber:Hide()
    HideLine()
    bar.spark:Show()
    bar:SetHeight(H)
    frame.catch:Hide()
    frame.catchIcon:Hide()
    Place()
    CB.art:Stop()
    if CB.demo then CB:DemoNext() end
end

-- How far along the cast is, 0-1 (nil without times)
local function Progress(now)
    if not CB.timed then return nil end
    return ns.Clamp((now - CB.start) / (CB.stop - CB.start), 0, 1)
end

local function OnUpdate()
    local now = GetTime()
    ComboTick(now)
    RainTick(now)
    BoostTick(now)
    if CB.until_ then                         -- showing a result for a moment
        if now >= CB.until_ then Stop() else CB.art:Update(nil, nil, now); Jolt(now); Pop(now) end
        return
    end
    if not CB.timed then return end
    if now >= CB.stop then
        CB:Result(false)
        return
    end
    local p = Progress(now)
    local fill = CB.channel and (1 - p) or p
    local share = fill
    bar.fill:SetValue(fill)
    if CB.up then
        CB.up.upCast.fill:SetValue(fill)
        CB.up.upCastTime:SetText(("%.1f"):format(CB.stop - now))
    end
    CB.art:Update(fill, p, now)
    if not CB.channel and not CB.fishing and not CB.demo and ns.Rumble then ns.Rumble:Build(p) end   -- felt as it builds
    frame.time:SetText(("%.1f"):format(CB.stop - now))
    TimeGrow(CB.stop - now, now)
    if CB.fishing then
        -- the float bobs on the water at the end of the line
        local fill = bar.fill:GetStatusBarTexture()
        bar.bobber:ClearAllPoints()
        local bob = 3 + math.sin(now * 5) * 3
        bar.bobber:SetPoint("CENTER", fill, "RIGHT", 0, bob)
        DrawLine(W * share, bob + 10, now)
        bar.charge:SetAlpha(0)
    end
    -- what kind of cast it is: a little burst now and then (stone chips while mining, leaves while picking
    -- herbs...), off the end of the bar
    local look = CB.look
    if look and look.every and not CB.fishing and not CB.art.bursts and ns.db.impactFx and ns.Impact then
        if not CB.nextFx or now >= CB.nextFx then
            CB.nextFx = now + look.every
            ns.Impact:Burst(bar, look, 0.7)
        end
    end
    if CB.fishing then
        return                                -- the float is the show
    end
    if ns.db.castWindup and not CB.channel and not ns.Calm() and ns.Effects() ~= "none" then
        -- the wind-up: the glow builds, the spark grows, and it pulses when the cast is about to land
        local k = p * p
        local pulse = p > 0.85 and (0.15 * math.sin(now * 30)) or 0
        bar.charge:SetAlpha(ns.Clamp(k * 0.8 + pulse, 0, 1))
        bar.spark:SetSize(14 + 14 * p, 14 + 14 * p)
    else
        bar.charge:SetAlpha(0)
    end
end

CB.OnUpdate = OnUpdate

-- A cast ended: flash it (done) or mark it (interrupted), then let it linger briefly.
function CB:Result(failed)
    if not self.casting then return end
    -- did it land? Then the next cast, started soon enough, goes on with the chain; otherwise the chain is over
    local landed = not failed and not self.demo
    if landed and self.timed then
        local now = GetTime()
        if self.channel then landed = (now - self.start) / (self.stop - self.start) >= 0.5
        else landed = now >= self.stop - CB.CHAIN_SLACK end
    end
    if landed and (self.combo or 0) >= 1 then
        self.comboAt = GetTime()
    else
        self.combo, self.comboAt = 0, nil
    end
    ComboDraw()
    self.casting, self.timed = false, false
    BoostHide()                                         -- (what helped the cast is spent, or the cast is off)
    self.art:Finish(not failed, GetTime())
    if ns.Rumble and not self.demo then ns.Rumble:BuildEnd(not failed) end
    if self.up then
        self.up.upCastTime:SetText("")
        if failed then self.up.upCast:SetColor(unpack(C.danger)); self.up.upCast.fill:SetValue(1)
        else self.up.upCast.fill:SetValue(self.channel and 0 or 1); self.up.upCast:Flash(0.2) end
    end
    if failed then
        bar:SetColor(unpack(C.danger))
        frame.label:SetText(L["Interrupted"])
    else
        bar.fill:SetValue(self.channel and 0 or 1)
        bar:Flash(0.2)
        if ns.db.castWindup and not self.fishing and ns.Impact and ns.db.impactFx then
            local land = self.look and self.look.land
            ns.Impact:Burst(bar, (land and land.fx) and land or LANDED, 1)   -- the cast lands, in its own way
        end
        local kick = self.art:Kick()                    -- a bolt going off jolts the bar
        if kick then
            local sig = self.art.sig
            local p = ns.Impact and ns.Impact.PROFILES[sig.school] or { freq = 70, axis = "x" }
            self.kick = { at = GetTime(), amp = 3 * kick, freq = p.freq, axis = p.axis }
        end
    end
    bar.charge:SetAlpha(0)
    bar.bobber:Hide()
    HideLine()
    if not failed and self.grown then                   -- it reached its end: the count bursts and fades
        frame.time:SetText(("%.1f"):format(0))
        self.pop = { at = GetTime(), from = self.timeScale or 1, burst = ns.Effects() == "full" }
    else
        frame.time:SetText("")
        TimeRest()
    end
    self.until_ = GetTime() + math.max(LINGER, self.art:Ending())    -- (a bar that crumbles takes a moment longer)
    frame:SetScript("OnUpdate", OnUpdate)
end

local NEW = { UNIT_SPELLCAST_START = true, UNIT_SPELLCAST_CHANNEL_START = true }

function CB:Refresh(event)
    if not self.active then return end
    local name, startMS, endMS, channel, shielded = U.Cast("player")
    if not name then
        if self.casting then self:Result(false) end
        return
    end
    self.demo = nil                                     -- a real cast ends the show of all of them
    self.casting, self.until_, self.channel = true, nil, channel and true or false
    if self.pop then TimeRest() end                     -- (the last cast's count was still fading)
    local cname, spellID, trade, icon = ns.CastLook.Casting("player")
    self.look = (not ns.UnitFrames.fake) and cname and ns.CastLook.Look(cname, spellID, trade) or nil
    ns.CastLook.Own(self.look, icon)                    -- which herb or ore it is, what is being made
    self.castName, self.castID, self.castTrade = cname, spellID, trade
    pcall(frame.label.SetText, frame.label, ns.CastLook.Label(name, self.look))
    self.nextFx = nil
    local color = (not ns.IsSecret(shielded) and shielded) and C.shielded or (self.look and self.look.color) or C.cast
    bar:SetColor(unpack(color))
    self.color = color
    bar.charge:SetVertexColor(color[1], color[2], color[3], 1)
    self:Fishing(channel)
    if NEW[event] then                                  -- a cast begins: one more of a chain, or the first of one
        local now = GetTime()
        -- (not fishing, and not making things: twenty bandages are not a chain of spells)
        local counts = ns.db.castChain and not self.fishing and not (not ns.IsSecret(trade) and trade)
        if counts and self.comboAt and now - self.comboAt <= CB.CHAIN_GAP then
            self.combo = (self.combo or 1) + 1
            self.bump = (not ns.Calm() and ns.Effects() ~= "none") and now or nil
        else
            self.combo = counts and 1 or 0
            self.comboDamage, self.comboUnknown = 0, nil     -- a new chain: its damage from nothing
        end
        self.comboAt = nil
    end
    ComboDraw()
    bar.fill:SetMinMaxValues(0, 1)
    bar.trail:SetValue(0)
    frame:Show()
    UpShow(color)
    self:Boosts()
    if ns.IsSecret(startMS) or ns.IsSecret(endMS) or not startMS or not endMS or endMS <= startMS then
        self.timed = false
        bar.fill:SetValue(1)
        if self.up then self.up.upCast.fill:SetValue(1); self.up.upCast.fill:SetAlpha(0.5) end
        frame.time:SetText("")
        self.art:Stop()                                 -- nothing to follow along the bar
    else
        self.timed, self.start, self.stop = true, startMS / 1000, endMS / 1000
        self.art:Start(self.fishing and WATER or self.look)
        self.art.began = self.start                     -- (a pick swings on the second, counted from here)
    end
    if ns.Debug then
        local said = ("%s, kind %s, animation %s"):format(tostring(ns.Plain(cname)), tostring(self.look and self.look.kind),
            tostring(self.art.kind))
        if said ~= ns.Debug.lastCast then ns.Debug.lastCast = said; ns.Note("cast: %s", said) end
    end
    frame:SetScript("OnUpdate", OnUpdate)
    OnUpdate()
end

---------------------------------------------------------------------------
-- Fishing: what is likely to bite here. Read from Improved Forever's fishing data when that addon is loaded
-- (its data is not ours to copy); otherwise the bar just says where you are fishing.
---------------------------------------------------------------------------
local byName

local function FishingData()
    local IF = _G.ImprovedForever
    return type(IF) == "table" and type(IF.FishingData) == "table" and IF.FishingData or nil
end

-- name -> list of { id, chance }, for zones and for the smaller areas inside them
local function Index(D)
    if byName then return byName end
    byName = {}
    local function add(row, list)
        local name, catches = row:match("^([^|]+)|"), row:match("([^|]*)$")
        if not name or not catches then return end
        local fish = {}
        for id, chance in catches:gmatch("(%d+):([%d.]+)") do
            fish[#fish + 1] = { id = tonumber(id), chance = tonumber(chance) }
        end
        byName[name] = fish
    end
    for _, row in pairs(D.areas or {}) do if type(row) == "string" then add(row) end end
    for _, row in pairs(D.zones or {}) do
        if type(row) == "string" then
            local name = row:match("^([^|]+)|")
            if name and not byName[name] then add(row) end
        end
    end
    return byName
end

-- The likeliest fish here: { name, icon, chance } list, best first (at most n), or nil
function CB.LikelyCatch(n)
    local D = FishingData()
    if not D then return nil end
    local index = Index(D)
    local list = index[GetSubZoneText and GetSubZoneText() or ""] or index[GetZoneText and GetZoneText() or ""]
    if not list then return nil end
    local out = {}
    for _, f in ipairs(list) do
        local row = D.items and D.items[f.id]
        if type(row) == "string" and row:match("|fish$") then
            local icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(f.id)
            out[#out + 1] = { id = f.id, name = row:match("^([^|]+)"), icon = icon, chance = f.chance }
        end
    end
    table.sort(out, function(a, b) return a.chance > b.chance end)
    while #out > (n or 2) do table.remove(out) end
    return #out > 0 and out or nil
end

function CB:Fishing(channel)
    local spellID = channel and select(8, UnitChannelInfo("player"))
    self.fishing = (not ns.IsSecret(spellID)) and FISHING[spellID or 0] and ns.db.fishing or false
    self:FishingLook(self.fishing)
    if not self.fishing then return end
    frame.label:SetText("")                           -- the float says what this is; the time stays
    local catch = CB.LikelyCatch(2)
    if catch then
        local parts = {}
        for _, f in ipairs(catch) do parts[#parts + 1] = ("%s %d%%"):format(f.name, math.floor(f.chance + 0.5)) end
        frame.catch:SetText(L["Likely:"] .. " " .. table.concat(parts, ", "))
        if catch[1].icon then
            frame.catchIcon:SetTexture(catch[1].icon)
            frame.catchIcon:Show()
        else
            frame.catchIcon:Hide()
        end
    else
        frame.catch:SetText((GetSubZoneText and GetSubZoneText() ~= "" and GetSubZoneText()) or (GetZoneText and GetZoneText()) or "")
        frame.catchIcon:Hide()
    end
    frame.catch:Show()
end

-- The fishing look: the bar thins to a line the colour of water, with the float at its end. The bright edge
-- that rides the front of other casts is put away: it stood right on the float and the rings round it.
function CB:FishingLook(on)
    Place()
    -- one of the main abilities: its show may reach further than leaves and roots do (CastLook.SIGS: room)
    local sig, level = self.look and self.look.sig, ns.Effects()
    local shown = sig and not on and ns.db.castArt and level ~= "classic" and level ~= "none"
    Clearance(on, shown and sig.room or 0)
    if on then
        bar:SetHeight(LINE)
        bar:SetColor(unpack(WATER.color))
        bar.charge:SetAlpha(0)
        bar.spark:Hide()
        bar.bobber:Show()
    else
        bar:SetHeight(H)
        bar.spark:Show()
        bar.bobber:Hide()
        HideLine()
        frame.catch:Hide()
        frame.catchIcon:Hide()
    end
end
CB.FISHING = FISHING

---------------------------------------------------------------------------
-- /cchud casttest: every kind of cast once, a short made-up cast each
---------------------------------------------------------------------------
CB.DEMO = { "mining", "crafting", "herbs", "skinning", "nature", "lightning", "roots", "heal", "arcane", "fire", "frost", "shadow",
            "holy", "physical", "fishing" }

function CB:DemoNext()
    local kind = self.demo and table.remove(self.demo, 1)
    if not kind then self.demo = nil; return end
    local fishing = kind == "fishing"
    local now = GetTime()
    local K = ns.CastLook
    local sig = K.SIGS[kind]                            -- (/cchud sigtest: one of the main abilities)
    local channel = sig and (sig.show == "missiles" or sig.show == "tether") or false
    self.casting, self.until_, self.channel, self.fishing = true, nil, fishing or channel, fishing
    self.look = (not fishing) and (sig and K.SigLook(kind) or K.LookOf(kind)) or nil
    self.timed, self.start, self.stop, self.nextFx = true, now, now + 2.4, nil
    frame.label:SetText(fishing and "" or kind)
    local color = self.look and self.look.color or C.cast
    bar:SetColor(unpack(color))
    self.color = color
    bar.charge:SetVertexColor(color[1], color[2], color[3], 1)
    self:FishingLook(fishing)
    bar.fill:SetMinMaxValues(0, 1)
    bar.trail:SetValue(0)
    frame:Show()
    self.art:Start(fishing and WATER or self.look)
    frame:SetScript("OnUpdate", self.OnUpdate)
end

function CB:Demo(kinds)
    if not self.active or self.casting or self.until_ then return false end
    self.demo = {}
    for i, kind in ipairs(kinds or self.DEMO) do self.demo[i] = kind end
    self:DemoNext()
    return true
end

local FAILED = { UNIT_SPELLCAST_INTERRUPTED = true, UNIT_SPELLCAST_FAILED = true }
local EVENTS = { "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
                 "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP",
                 "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_SENT", "PLAYER_ENTERING_WORLD" }

local events = CreateFrame("Frame")
local OnEvent = ns.Protect(function(_, event, unit, target)
    if unit and unit ~= "player" then return end
    if event == "UNIT_SPELLCAST_SENT" then              -- what the cast is aimed at: the herb, the vein
        ns.CastLook.Sent(target)
        return
    end
    if ns.UnitFrames.fake then return end
    if FAILED[event] then
        -- a failed instant while a real cast keeps going is not ours to show
        if CB.casting and not U.Cast("player") then CB:Result(true) end
        return
    end
    CB:Refresh(event)
end)

function CB:Apply(run)
    local want = run and ns.db.castbar and not ns.arranging and true or false
    ns.SetBlizzardHidden(NATIVE, want)
    if want and not frame then Build() end
    if frame then Place() end
    CB.BoostApply(want and ns.db.castBoost)
    if want == self.active then
        if frame and self.casting then self:Boosts() end
        return
    end
    self.active = want
    if want then
        for _, e in ipairs(EVENTS) do pcall(events.RegisterEvent, events, e) end
        events:SetScript("OnEvent", OnEvent)
        self:Refresh()
    else
        events:UnregisterAllEvents()
        events:SetScript("OnEvent", nil)
        self.demo = nil
        Stop()
    end
end

ns.RegisterCheck(function(row, run, db)
    local want = (run and db.castbar and not ns.arranging) and true or false
    row(want and "the cast bar is ours" or "the cast bar is the game's", CB.active == want)
    if _G[NATIVE] then
        row(("the game's cast bar is %s"):format(want and "put aside" or "left alone"), ns.IsBlizzardHidden(NATIVE) == want)
    end
end)

ns.RegisterModule("castbar", CB)
