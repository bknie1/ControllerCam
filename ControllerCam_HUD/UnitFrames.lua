-- ControllerCam HUD: unit frames.
--   player  top left, where WoW has always had it: health, resource, and a small pet bar below
--   target  top centre: name, level, health, cast bar
--   target of target and focus: their own small frames, each movable on its own
-- They can be dragged in the game's Edit Mode, like its own frames (or with /cchud unlock).
-- Each is a secure unit button (click to target, right-click for the menu) that fills a plain "mover" frame;
-- the mover is what gets placed and dragged. Everything drawn lives in a "visual" child, which is free to
-- fade, flash and shake in combat.

local ADDON, ns = ...
local L = ns.L
local C = ns.colors

local UF = { frames = {}, unlocked = false, alpha = 1, valpha = 1 }
ns.UnitFrames = UF

local LAYOUT = {
    player = { unit = "player", w = 240, h = 18, point = { "TOPLEFT", 44, -44 } },
    target = { unit = "target", w = 300, h = 34, point = { "TOP", 0, -78 }, bar = 10, text = 13, barY = -18 },
    pet    = { unit = "pet",    w = 90,  h = 4 },
    tot    = { unit = "targettarget", w = 120, h = 20, bar = 5, text = 10 },   -- next to the target bar unless moved
    focus  = { unit = "focus",  w = 200, h = 30, point = { "TOP", -280, -82 }, bar = 8, text = 11, barY = -15 },   -- left of the target
    vertical = { unit = "player", w = 16, h = 96, point = { "CENTER", -280, -30 } },    -- beside your character
                                                     -- (who stands left of centre with the shoulder view)
    vpet   = { unit = "pet",    w = 6,   h = 48 },   -- your pet, left of the vertical bars: half their height,
                                                     -- level with their feet
}
UF.LAYOUT = LAYOUT
local ORDER = { "player", "target", "pet", "tot", "focus", "vertical", "vpet" }
local WATCHED = { "target", "pet", "tot", "focus", "vpet" }     -- shown by the game while their unit exists
local MOVERS = { "player", "target", "tot", "focus", "vertical" }   -- each placed and dragged on its own
local ALWAYS = { player = true, vertical = true }       -- always shown while on (your own bars)
local TARGETLIKE = { target = true, tot = true, focus = true }     -- coloured by what the unit is to you
local LABEL = { player = "Player", target = "Target", pet = "Pet", tot = "Target of target", focus = "Focus",
                vertical = "Vertical bars", vpet = "Pet" }

local FADE_DELAY = 1.5          -- seconds of calm before the player bar dims
local FADE_SPEED = 4            -- opacity change per second
local SHAKE_FROM = 0.10         -- a hit that takes at least this share of the bar shakes it
local POP_TIME = 0.2            -- the bar swells for a moment when combat starts

---------------------------------------------------------------------------
-- Reading units. The demo (/cchud demo) swaps in made-up units through UF.fake.
---------------------------------------------------------------------------
local function Fake(unit) return UF.fake and UF.fake[unit] end

local U = {}
ns.Unit = U
function U.Exists(unit)
    if UF.fake then return UF.fake[unit] ~= nil end
    return UnitExists(unit) and true or false
end
function U.Health(unit)
    local k = Fake(unit)
    if k then return k.health, k.healthMax end
    return UnitHealth(unit), UnitHealthMax(unit)
end
function U.Power(unit)
    local k = Fake(unit)
    if k then return k.power or 0, k.powerMax or 0, k.powerToken or "MANA" end
    local _, token = UnitPowerType(unit)
    return UnitPower(unit), UnitPowerMax(unit), token
end
function U.Combat()
    if UF.fake then return UF.fake.combat and true or false end
    return UnitAffectingCombat("player") and true or false
end
function U.Class(unit)
    local k = Fake(unit)
    if k then return k.class end
    local _, class = UnitClass(unit)
    return ns.Plain(class)
end
function U.Info(unit)          -- name, level, classification
    local k = Fake(unit)
    if k then return k.name, k.level, k.classification end
    -- in a fight the game may keep the rank secret: then it is unknown (comparing a secret would fail)
    local kind = UnitClassification and UnitClassification(unit)
    if ns.IsSecret(kind) then kind = nil end
    local name, realm = UnitName(unit)
    if ns.IsSecret(name) then
        local n, r = ns.NameByGUID(unit)
        if n then name, realm = n, r end
    end
    return ns.FullName(name, realm), UnitLevel(unit), kind
end
function U.Standing(unit)      -- dead, tapped, isPlayer, attackable, reaction
    local k = Fake(unit)
    if k then return k.dead, k.tapped, k.isPlayer, k.attackable, k.reaction end
    -- what the game keeps secret (in a dungeon) counts as not known: no
    local P, Y = ns.Plain, ns.Yes
    return Y(UnitIsDead(unit)) or (UnitIsGhost and Y(UnitIsGhost(unit))) or false,
        UnitIsTapDenied and Y(UnitIsTapDenied(unit)) or false,
        Y(UnitIsPlayer(unit)), Y(UnitCanAttack("player", unit)), P(UnitReaction(unit, "player"))
end
function U.Cast(unit)          -- name, startMS, endMS, channel, shielded
    local k = Fake(unit)
    if k then
        local c = k.cast
        if c then return c.name, c.start, c.stop, c.channel, c.shielded end
        return nil
    end
    local name, _, _, startMS, endMS, _, _, shielded = UnitCastingInfo(unit)
    if name then return name, startMS, endMS, false, shielded end
    name, _, _, startMS, endMS, _, shielded = UnitChannelInfo(unit)
    if name then return name, startMS, endMS, true, shielded end
end

---------------------------------------------------------------------------
-- Building
---------------------------------------------------------------------------
local function AddFlash(bar)
    local flash = bar.over:CreateTexture(nil, "OVERLAY")
    flash:SetAllPoints(bar)
    flash:SetColorTexture(1, 1, 1, 1)
    flash:SetBlendMode("ADD")
    flash:SetAlpha(0)
    if bar.mask then pcall(flash.AddMaskTexture, flash, bar.mask) end
    return flash
end

local function AddGlow(visual, bar, color, spread)
    local glow = visual:CreateTexture(nil, "BACKGROUND")
    glow:SetTexture(ns.media.soft)
    glow:SetVertexColor(color[1], color[2], color[3], 1)
    glow:SetPoint("TOPLEFT", bar, "TOPLEFT", -spread, spread)
    glow:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", spread, -spread)
    return glow
end

local function Create(key)
    local lay = LAYOUT[key]
    local mover = CreateFrame("Frame", "ControllerCamHUD_" .. key .. "Mover", UIParent)
    mover:SetSize(lay.w, lay.h)

    local button = CreateFrame("Button", "ControllerCamHUD_" .. key, UIParent, "SecureUnitButtonTemplate")
    button:SetAllPoints(mover)
    button:SetFrameStrata("LOW")
    button:SetAttribute("unit", lay.unit)
    button:SetAttribute("type1", "target")
    button:SetAttribute("type2", "togglemenu")
    button:RegisterForClicks("AnyUp")
    button:Hide()

    local visual = CreateFrame("Frame", nil, button)
    visual:SetAllPoints(button)

    local f = { key = key, unit = lay.unit, mover = mover, button = button, visual = visual, on = false,
                flashA = 0, pop = 0, combatA = 0 }

    if key == "vertical" then
        -- a quick read: two slim bars and two quiet figures beside them
        f.health = ns.CreateBar(visual, 8, lay.h, { vertical = true, segments = 4 })
        f.health:SetPoint("TOPLEFT", visual, "TOPLEFT", 0, 0)
        f.power = ns.CreateBar(visual, 4, lay.h, { vertical = true })
        f.power:SetPoint("TOPLEFT", f.health, "TOPRIGHT", 3, 0)
        f.health.shadow:SetAlpha(0.35)
        f.power.shadow:SetAlpha(0.35)
        f.text = ns.FontString(visual, 7, "RIGHT")
        f.text:SetPoint("BOTTOMRIGHT", f.health, "BOTTOMLEFT", -4, 9)
        f.text:SetTextColor(unpack(C.muted))
        f.ptext = ns.FontString(visual, 6, "RIGHT")
        f.ptext:SetPoint("TOPRIGHT", f.text, "BOTTOMRIGHT", 0, -1)
        -- your cast, upright on the right of the power bar (an option: CastBar.lua runs it), a small timer on top
        f.upCast = ns.CreateBar(visual, 3, lay.h, { vertical = true })
        f.upCast:SetPoint("TOPLEFT", f.power, "TOPRIGHT", 3, 0)
        f.upCast.shadow:SetAlpha(0.35)
        f.upCast:Hide()
        f.upCastTime = ns.FontString(visual, 6, "CENTER")
        f.upCastTime:SetPoint("BOTTOM", f.upCast, "TOP", 0, 2)
        f.upCastTime:SetTextColor(unpack(C.muted))
        f.upCastTime:Hide()
    elseif key == "player" then
        f.health = ns.CreateBar(visual, lay.w, 10, { segments = 4 })
        f.health:SetPoint("TOPLEFT", visual, "TOPLEFT", 0, 0)
        f.power = ns.CreateBar(visual, lay.w, 4)
        f.power:SetPoint("BOTTOMLEFT", visual, "BOTTOMLEFT", 0, 0)
        f.text = ns.FontString(visual, 11, "LEFT")
        f.text:SetPoint("LEFT", f.health, "RIGHT", 10, 0)
        f.combatGlow = AddGlow(visual, f.health, C.combat, 12)      -- a warm edge while in combat
        f.combatGlow:SetAlpha(0)
        f.glow = AddGlow(visual, f.health, C.danger, 16)            -- pulses when health is low
        f.glow:Hide()
    elseif key == "pet" then
        f.health = ns.CreateBar(visual, lay.w, lay.h)
        f.health:SetPoint("TOPLEFT", visual, "TOPLEFT", 0, 0)
        -- its mood: a thin band under the bar, and food beside it when it needs feeding (UpdateMood)
        f.mood = visual:CreateTexture(nil, "ARTWORK")
        f.mood:SetSize(lay.w, 2)
        f.mood:SetPoint("TOPLEFT", f.health, "BOTTOMLEFT", 0, -2)
        f.moodIcon = visual:CreateTexture(nil, "OVERLAY")
        f.moodIcon:SetSize(12, 12)
        f.moodIcon:SetPoint("LEFT", f.health, "RIGHT", 4, 0)
    elseif key == "vpet" then                           -- upright like the vertical bars, half their height
        f.health = ns.CreateBar(visual, lay.w, lay.h, { vertical = true })
        f.health:SetPoint("TOPLEFT", visual, "TOPLEFT", 0, 0)
        f.health.shadow:SetAlpha(0.35)
        f.mood = visual:CreateTexture(nil, "ARTWORK")   -- its mood: a thin band on the far side of it
        f.mood:SetSize(2, lay.h)
        f.mood:SetPoint("TOPRIGHT", f.health, "TOPLEFT", -2, 0)
        f.moodIcon = visual:CreateTexture(nil, "OVERLAY")
        f.moodIcon:SetSize(12, 12)
        f.moodIcon:SetPoint("BOTTOM", f.health, "TOP", 0, 3)
    elseif key == "tot" then
        f.name = ns.FontString(visual, lay.text, "LEFT")
        f.name:SetPoint("TOPLEFT", visual, "TOPLEFT", 2, 0)
        f.health = ns.CreateBar(visual, lay.w, lay.bar)
        f.health:SetPoint("TOPLEFT", visual, "TOPLEFT", 0, -16)        -- moved below the name by ApplyLook
    else
        f.name = ns.FontString(visual, lay.text, "CENTER")
        f.name:SetPoint("TOP", visual, "TOP", 0, 0)
        f.health = ns.CreateBar(visual, lay.w, lay.bar, { segments = 4 })
        f.health:SetPoint("TOPLEFT", visual, "TOPLEFT", 0, lay.barY)
        -- its mana (or rage, energy...): a slim bar right under the health, when it has any (UpdatePower)
        f.power = ns.CreateBar(visual, lay.w, 3)
        f.power:SetPoint("TOPLEFT", f.health, "BOTTOMLEFT", 0, -2)
        f.power.shadow:SetAlpha(0.35)
        f.power:Hide()
        -- a soft dark band behind the text, so it reads against a bright sky
        f.shade = visual:CreateTexture(nil, "BACKGROUND")
        f.shade:SetTexture(ns.media.soft)
        f.shade:SetVertexColor(0, 0, 0, 0.6)
        f.shade:SetPoint("TOPLEFT", visual, "TOPLEFT", -24, 14)
        f.shade:SetPoint("BOTTOMRIGHT", f.health, "TOPRIGHT", 24, -10)
        -- the health text: hanging from the bar's lower edge at its right end, on a soft shade of its own. It
        -- has a layer to itself above the bars (drawn inside the health bar it was cut off at the bar's edge)
        f.textHolder = CreateFrame("Frame", nil, visual)
        f.textHolder:SetAllPoints(f.health)
        f.textHolder:SetFrameLevel((tonumber(visual:GetFrameLevel()) or 1) + 8)
        f.text = ns.FontString(f.textHolder, 9, "RIGHT")
        f.text:SetPoint("TOPRIGHT", f.power, "BOTTOMRIGHT", -6, -3)          -- (under the power bar)
        f.textShade = f.textHolder:CreateTexture(nil, "BACKGROUND")
        f.textShade:SetTexture(ns.media.soft)
        f.textShade:SetVertexColor(0, 0, 0, 0.55)
        f.textShade:SetPoint("TOPLEFT", f.text, "TOPLEFT", -12, 5)
        f.textShade:SetPoint("BOTTOMRIGHT", f.text, "BOTTOMRIGHT", 10, -5)
        f.textShade:Hide()
        f.mark = visual:CreateTexture(nil, "OVERLAY")
        f.mark:SetTexture(ns.media.mark)
        f.mark:SetSize(12, 12)
        f.mark:SetPoint("BOTTOMLEFT", f.health, "TOPLEFT", 8, 4)
        f.mark:Hide()

        f.cast = ns.CreateBar(visual, lay.w - 16, 4)
        f.cast:SetPoint("TOP", f.power, "BOTTOM", 0, -4)
        f.cast:SetColor(unpack(C.cast))
        f.cast.spark = f.cast.over:CreateTexture(nil, "OVERLAY")
        f.cast.spark:SetTexture(ns.media.spark)
        f.cast.spark:SetBlendMode("ADD")
        f.cast.spark:SetSize(14, 14)
        f.cast.spark:SetPoint("CENTER", f.cast.fill:GetStatusBarTexture(), "RIGHT", 0, 0)
        f.cast.label = ns.FontString(visual, 10, "CENTER")
        f.cast.label:SetPoint("TOP", f.cast, "BOTTOM", 0, -3)
        f.cast.label:SetTextColor(unpack(C.muted))
        f.cast:Hide()
        f.cast.label:Hide()
    end
    f.flash = AddFlash(f.health)

    -- shown only while the frames are unlocked for dragging
    mover.overlay = mover:CreateTexture(nil, "OVERLAY")
    mover.overlay:SetAllPoints(mover)
    mover.overlay:SetColorTexture(0.4, 0.8, 1, 0.35)
    mover.overlay:Hide()
    mover.label = ns.FontString(mover, 11, "CENTER")
    mover.label:SetPoint("CENTER", mover, "CENTER", 0, 0)
    mover.label:SetText(L[LABEL[key]])
    mover.label:Hide()

    UF.frames[key] = f
    return f
end

local TOT_GAP = 56            -- between the target's bar and the target of target beside it
local NAME_MIN = 260          -- the target's name always has at least this much room, even over a compact bar
UF.TOT_GAP, UF.NAME_MIN = TOT_GAP, NAME_MIN
UF.totGap = TOT_GAP           -- (wider when the name reaches past a compact bar)

local function Place(f)
    local mover = f.mover
    mover:ClearAllPoints()
    if f.key == "pet" then
        mover:SetPoint("TOPLEFT", UF.frames.player.mover, "BOTTOMLEFT", 0, -7)
        return
    end
    if f.key == "vpet" then                             -- on the other side of the vertical bars, level with their feet
        mover:SetPoint("BOTTOMRIGHT", UF.frames.vertical.mover, "BOTTOMLEFT", -5, 0)
        return
    end
    local pos = ns.db.pos[f.key]
    if f.key == "tot" and not pos then
        -- well clear of the target's bar end, where its threat shield and the end of a long name sit
        mover:SetPoint("BOTTOMLEFT", UF.frames.target.health, "BOTTOMRIGHT", UF.totGap, 0)
        return
    end
    if pos then
        mover:SetPoint("CENTER", UIParent, "CENTER", pos.x, pos.y)
    else
        local p = LAYOUT[f.key].point
        mover:SetPoint(p[1], UIParent, p[1], p[2], p[3])
    end
end

---------------------------------------------------------------------------
-- Colours
---------------------------------------------------------------------------
local function ClassColor(unit)
    local class = U.Class(unit)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return c.r, c.g, c.b end
end

-- A friendly NPC by your standing with its faction (the game's reaction, 1 hated to 8 exalted): the HUD's own
-- tones, warm to cool as the standing grows
ns.RegisterSetting({
    key = "repColors", kind = "boolean", default = true, command = "repcolors", section = "Frames",
    label = "Friendly NPCs by reputation",
    tip = "a friendly NPC's name and bar are coloured by your standing with its faction: yellow neutral, green friendly, then sea green, teal and blue for honored, revered and exalted",
})
ns.RegisterSetting({
    key = "factionMarks", kind = "boolean", default = true, command = "factionmarks", section = "Frames",
    label = "The other faction, plainly",
    tip = "a player of the other faction wears the faction's badge before the name and an outline round the health bar, Alliance blue or Horde red, on nameplates and the target frame",
})
ns.RegisterSetting({
    key = "classNames", kind = "boolean", default = true, command = "classnames", section = "Frames",
    label = "Players' names in their class colour",
    tip = "a player's name in their class's colour on nameplates and the target frame, also in a battleground where the game keeps the class to itself (the game colours it for us)",
})
ns.RegisterSetting({
    key = "factionStyle", kind = "number", default = 1, min = 1, max = 2, section = "Frames",
    choices = { "Faction colours", "Ally or enemy" }, command = "factionstyle", label = "The other faction: colours",
    tip = "the colour of the outline and the highlight on the other faction's bars: the faction's own (Alliance blue, Horde red), or the red of an enemy whichever faction it is",
})
UF.FACTION_NAMES = { L["Faction colours"], L["Ally or enemy"] }   -- (in your language: the options show them so)
UF.STANDING = {
    [1] = C.hostile, [2] = C.hostile, [3] = { 0.98, 0.55, 0.25 },       -- hated, hostile, unfriendly
    [4] = C.neutral, [5] = C.friendly,                                  -- neutral, friendly
    [6] = { 0.36, 0.86, 0.66 }, [7] = { 0.32, 0.82, 0.88 }, [8] = { 0.45, 0.72, 1.00 },   -- honored, revered, exalted
}
function UF.StandingColor(reaction)
    local c = type(reaction) == "number" and UF.STANDING[reaction]
    if c then return c[1], c[2], c[3] end
end

local function TargetColor(unit)
    local dead, tapped, isPlayer, attackable, reaction = U.Standing(unit)
    if dead or tapped then return unpack(C.tapped) end
    if isPlayer and ns.db.classColors then
        local r, g, b = ClassColor(unit)
        if r then return r, g, b end
    end
    if attackable then
        if reaction and reaction >= 4 then return unpack(C.neutral) end
        return unpack(C.hostile)
    end
    if not isPlayer and ns.db.repColors then                            -- a friendly NPC: by your standing
        local r, g, b = UF.StandingColor(reaction)
        if r then return r, g, b end
    end
    return unpack(C.friendly)
end

-- In a fight (and when wanted) health is coloured by how much is left: green, yellow, red.
local function CombatColor(unit, frac)
    if not ns.db.combatColors or not ns.Yes(UnitAffectingCombat(unit)) then return nil end
    if frac then return ns.HealthGradient(frac) end
    return ns.HealthGradientFor(unit)
end

local function TargetHealthColor(unit, frac)
    local dead, tapped, isPlayer = U.Standing(unit)
    -- a player keeps their class colour in a fight too: in a battleground everyone is in one, and the health
    -- gradient left no telling a priest from a warrior (how much is left: the percent says)
    if isPlayer and not dead and ns.db.classColors then
        local r, g, b = ClassColor(unit)
        if r then return r, g, b end
    end
    if not (dead or tapped) then
        local r, g, b = CombatColor(unit, frac)
        if r then return r, g, b end
    end
    return TargetColor(unit)
end

local function OwnColor(unit, frac)
    local r, g, b = CombatColor(unit, frac)
    if r then return r, g, b end
    if frac and frac <= 0.25 then return unpack(C.danger) end
    if frac and frac <= 0.5 then return unpack(C.caution) end
    if ns.db.classColors and unit == "player" then
        local r, g, b = ClassColor(unit)
        if r then return r, g, b end
    end
    return unpack(C.health)
end

UF.ClassColor, UF.TargetColor, UF.TargetHealthColor = ClassColor, TargetColor, TargetHealthColor

-- The game's own countdowns (a battleground's start, an arena's: its timer bars at the top of the screen) sat
-- under the target frame, over its buffs: moved down below them. Out of a fight only (they come before one).
UF.TIMER_GAP, UF.TIMER_STEP = 56, 30
function UF.PlaceTimers()
    if InCombatLockdown() then return end
    local target = UF.frames and UF.frames.target
    if type(target) ~= "table" then return end
    local n = 0
    for i = 1, 8 do
        local t = rawget(_G, "TimerTrackerTimer" .. i)
        if type(t) == "table" and t.IsShown and ns.ShownPlain(t) then
            pcall(t.ClearAllPoints, t)
            pcall(t.SetPoint, t, "TOP", target, "BOTTOM", 0, -UF.TIMER_GAP - n * UF.TIMER_STEP)
            n = n + 1
        end
    end
end
do
    local timers = CreateFrame("Frame")
    for _, e in ipairs({ "START_TIMER", "PLAYER_ENTERING_WORLD" }) do pcall(timers.RegisterEvent, timers, e) end
    timers:SetScript("OnEvent", ns.Protect(function()
        C_Timer.After(0, ns.Protect(UF.PlaceTimers))                -- (after the game has placed its own)
        C_Timer.After(0.5, ns.Protect(UF.PlaceTimers))
    end))
end

---------------------------------------------------------------------------
-- Updating
---------------------------------------------------------------------------
local function PercentText(fs, frac, always, unit)
    if not fs then return end
    if frac and (always or frac < 0.999) then
        fs:SetText(("%d%%"):format(math.floor(frac * 100 + 0.5)))
        fs:Show()
    elseif not frac and unit and ns.SecretPercent(fs, unit) then
        fs:Show()
    else
        fs:Hide()
    end
end

-- The health on a bar: "12.3k  85%" (value and percent), or either alone. When the game keeps health secret it
-- formats the numbers itself. Returns whether anything is shown.
local function Short(n)
    if AbbreviateNumbers then
        local ok, s = pcall(AbbreviateNumbers, n)
        if ok then return s end
    end
    if ns.IsSecret(n) or type(n) ~= "number" then return nil end
    if n >= 1e6 then return ("%.1fm"):format(n / 1e6) end
    if n >= 1e4 then return ("%.1fk"):format(n / 1e3) end
    return tostring(math.floor(n))
end
ns.ShortNumber = Short

-- A unit's health as 0-100, for the game to write out. Where the game keeps health secret no sum may be done
-- with it: then the game is asked for it on that scale itself (where it can), and nil means it cannot be had.
local function Percent100(unit)
    local scale = CurveConstants and CurveConstants.ScaleTo100
    if scale then
        local ok, p = pcall(UnitHealthPercent, unit, true, scale)
        if ok and p ~= nil then return p end
    end
    local p = UnitHealthPercent(unit, true)
    if p == nil or ns.IsSecret(p) then return nil end
    return p * 100
end

function ns.HealthLine(fs, unit, frac, value, percent)
    if not (value or percent) then fs:Hide(); return false end
    local cur = U.Health(unit)
    if value and percent and Short(cur) == nil then value = false end    -- no number to show: the percent alone
    local ok = pcall(function()
        if value and percent then
            local p = (not frac) and Percent100(unit)
            if frac then fs:SetFormattedText("%s  %d%%", Short(cur), math.floor(frac * 100 + 0.5))
            elseif p ~= nil then fs:SetFormattedText("%s  %d%%", Short(cur), p)
            else fs:SetText(Short(cur)) end              -- no percent to be had: the number alone
        elseif value then
            fs:SetText(Short(cur))
        elseif frac then
            fs:SetText(("%d%%"):format(math.floor(frac * 100 + 0.5)))
        else
            local p = Percent100(unit)
            if p == nil then error("no percent") end
            fs:SetFormattedText("%d%%", p)
        end
    end)
    if ok then fs:Show() else fs:Hide() end
    return ok
end

-- "73%" when the game keeps health secret: the game scales it (Percent100) and formats it itself. Nothing is
-- ever worked out on a secret here: a blocked attempt counts as an addon error even inside a pcall, and in a
-- battleground they piled up to the game's "large number of errors" warning.
function ns.SecretPercent(fs, unit)
    if not (UnitHealthPercent and fs.SetFormattedText) then return false end
    local okP, p = pcall(Percent100, unit)
    if not okP or p == nil then return false end
    return pcall(fs.SetFormattedText, fs, "%d%%", p) and true or false
end

-- A hit lights the bar up; a heavy one shakes it. When a hit effect of yours just landed on this frame
-- (Impact.lua), that one already said it all.
local function Hit(f, share)
    if f.visual.lastImpact and GetTime() - f.visual.lastImpact < 0.3 then return end
    if TARGETLIKE[f.key] and f.key ~= "tot" and ns.Impact.active then
        -- the game told us nothing about this hit (no combat log here): it still lands, as a plain one
        -- (nobody's blow in particular: no cut is drawn for it, it stays where the health ends)
        ns.Impact:Hit({ frame = f.visual, anchor = f.button, bar = f.health }, "physical", share >= SHAKE_FROM, nil, false)
        return
    end
    f.flashA = math.min(1, 0.45 + share * 2)
    f.flash:SetAlpha(f.flashA)
    if share >= SHAKE_FROM then ns.Impact:Shake(f.visual, f.button, HEAVY, 1 + share * 2) end
end

ns.RegisterSetting({
    key = "executeGlow", kind = "boolean", default = true, command = "execute", section = "Frames",
    label = "Execute range on enemy bars",
    tip = "an enemy at a quarter of its health or less: its health bar throbs red, with a glow round it beating like a pulse, on the target and focus frames and on nameplates",
})

-- In execute range, and an enemy: what the bar shows (see ns.ExecuteState), or nil
function UF.Execute(unit, frac)
    if not ns.db.executeGlow then return nil end
    local ok, enemy = pcall(UnitCanAttack, "player", unit)
    if not (ok and ns.Yes(enemy)) then return nil end
    local okD, dead = pcall(UnitIsDead, unit)
    if okD and ns.Yes(dead) then return nil end
    return ns.ExecuteState(unit, frac)
end

ns.RegisterSetting({
    key = "shieldBars", kind = "boolean", default = true, command = "shieldbars", section = "Frames",
    label = "Shields on health bars",
    tip = "how much a shield on a unit will soak, as a silver-blue band from the far end of its health bar: on your frames, your target's, your party's and nameplates",
})

ns.RegisterSetting({
    key = "healerNames", kind = "boolean", default = true, command = "healernames", section = "Frames",
    label = "Names of incoming healers",
    tip = "who else is healing a unit, by name on its health bar while the heal is on its way: on your frames, your target's, your party and raid; where the game keeps that to itself, no name is shown",
})

-- How much shielding a unit has (the game's own total; may be a value it keeps to itself), or nil
function UF.Absorb(unit)
    if UF.fake then
        local k = UF.fake[unit]
        return k and k.absorb
    end
    if not UnitGetTotalAbsorbs then return nil end
    local ok, amount = pcall(UnitGetTotalAbsorbs, unit)
    return ok and amount or nil
end

local function UpdateHealth(f, instant)
    local unit = f.unit
    local cur, max = U.Health(unit)
    f.health:SetValues(cur, max, instant)
    local frac = f.health:GetFraction()
    if not instant and frac and f.lastFrac and frac < f.lastFrac - 0.001 then Hit(f, f.lastFrac - frac) end
    f.lastFrac = frac
    if UnitGetIncomingHeals then
        if ns.Bloom then f.health:SetIncomingColor(ns.Bloom.IncomingColor(unit)) end
        -- yours, then everyone else's, with their names (not on the pet's slivers, nor in the demo)
        ns.ShowIncoming(f.health, unit, f.key ~= "pet" and f.key ~= "vpet" and not UF.fake)
    end
    f.health:SetAbsorb(UF.Absorb(unit))                            -- a shield on it, and how much it soaks
    if f.key == "target" or f.key == "focus" then
        f.health:SetExecute(UF.Execute(unit, frac))
        if ns.Impact and ns.Impact.Bleed then ns.Impact:Bleed(f.health, unit, frac) end    -- it bleeds out
    end
    if TARGETLIKE[f.key] then
        f.health:SetColor(TargetHealthColor(unit, frac))
        ns.ClassBarColor(f.health, unit)                            -- (a class kept secret: its colour all the same)
        if f.key == "tot" then
            PercentText(f.text, frac, true, unit)
        elseif f.text then
            -- full size: the health left, shortened, and the percent; compact: the percent alone
            local compact = f.key == "target" and ns.db.targetCompact
            -- (at full health there is nothing to say: no text until the unit is hurt, where the game lets us know)
            local full = type(frac) == "number" and not ns.IsSecret(frac) and frac >= 0.999
            local said = false
            if ns.db.targetHealthText and not full then said = ns.HealthLine(f.text, unit, frac, not compact, true) else f.text:Hide() end
            if f.textShade then
                if said and ns.db.textShade then f.textShade:Show() else f.textShade:Hide() end
            end
        end
    else
        f.health:SetColor(OwnColor(unit, frac))
        PercentText(f.text, frac, f.key == "vertical", f.key == "vertical" and unit or nil)
        if f.glow then
            if frac and frac <= 0.25 and frac > 0 then f.glow:Show() else f.glow:Hide() end
        end
    end
end

local function UpdatePower(f, instant)
    if not f.power then return end
    local cur, max, token = U.Power(f.unit)
    if ns.IsSecret(token) then token = nil end
    if f.key == "target" or f.key == "focus" then
        -- only a unit that really has a resource: mana when it has any at all; rage, energy and the rest while
        -- there is some (a monster that never builds it would show an empty track). Amounts the game keeps to
        -- itself in a fight: shown all the same, the game's own bar draws them.
        local known = not ns.IsSecret(max) and not ns.IsSecret(cur)
        local has = not known or (type(max) == "number" and max > 0
            and (token == "MANA" or token == nil or (type(cur) == "number" and cur > 0)))
        if not has then f.power:Hide(); f.powerToken = token; return end
        f.power:Show()
    end
    f.powerToken = token
    local color = C.power[token or ""] or C.power.MANA
    f.power:SetColor(unpack(color))
    f.power:SetValues(cur, max, instant)
    if f.ptext then                                    -- the vertical bars: power as a quiet figure too
        local frac = f.power:GetFraction()
        if frac then
            f.ptext:SetText(("%d"):format(math.floor(frac * 100 + 0.5)))
            f.ptext:SetTextColor(color[1], color[2], color[3], 0.8)
            f.ptext:Show()
        else
            f.ptext:Hide()
        end
    end
end

-- A player's class as an icon, in the line itself, right against the level: icon, level, name, as in chat
-- (target and target of target). "" when there is none to show.
local CLASS_ICONS = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
local function ClassMark(f)
    local class = ns.db.classIcons and U.Class(f.unit)
    local _, _, isPlayer = U.Standing(f.unit)
    local c = class and isPlayer and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
    if not c then return "" end
    return ("|T%s:0:0:0:0:256:256:%d:%d:%d:%d|t"):format(CLASS_ICONS, c[1] * 256, c[2] * 256, c[3] * 256, c[4] * 256)
end
UF.ClassMark = ClassMark

-- Its raid mark, just before its name (the target, its target, the focus, your pet...)
function UF.Mark(f)
    if not (f and f.name and f.visual) then return end
    local size = f.key == "tot" and 12 or 16
    ns.ShowRaidMark(f, f.visual, f.unit, size, "RIGHT", f.name, "LEFT", -4, 0)
end

local function UpdateInfo(f)
    if not f.name then return end
    local name, level, kind = U.Info(f.unit)
    local mark = (f.key == "tot" or f.key == "target") and ClassMark(f) or ""
    local fcolor                                                         -- the other faction, plainly: its badge
    if f.health then fcolor = ns.FactionBadge(f.health, f.unit, f.name)  -- big beside the bar
    else
        local badge
        badge, fcolor = ns.FactionMark(f.unit)
        mark = badge .. mark
    end
    local ok = pcall(function() f.name:SetFormattedText("%s%s  %s", mark, ns.LevelText(level), name or "") end)
    if not ok then pcall(f.name.SetText, f.name, name) end
    if f.health and ns.FactionEdge then ns.FactionEdge(f.health, fcolor) end   -- (the name keeps its colours)
    f.otherFaction = fcolor and true or false
    -- a player's name in their class's colour (or as ever), and a class kept secret still with its icon
    local _, _, isPlayer = U.Standing(f.unit)
    if not (ns.db.classNames and isPlayer and ns.ClassNameColor(f.name, f.unit)) then f.name:SetTextColor(unpack(C.text)) end
    local secretIcon = ns.SecretClassIcon(f.visual or f, f.name, f.unit,
        ns.db.classIcons and isPlayer and (f.key == "tot" or f.key == "target"), f.health)
    f.classMark = mark ~= "" or secretIcon
    UF.Mark(f)
    if f.key == "tot" then return end
    if not f.rankGlow then
        f.rankGlow = f.visual:CreateTexture(nil, "BACKGROUND")
        f.rankGlow:SetTexture(ns.media.soft)
        f.rankGlow:SetPoint("TOPLEFT", f.health, "TOPLEFT", -14, 10)
        f.rankGlow:SetPoint("BOTTOMRIGHT", f.health, "BOTTOMRIGHT", 14, -10)
        f.rankGlow:SetAlpha(0.55)
    end
    local rank = ns.ShowRank(f.mark, f.rankGlow, kind, level)
    f.mark:SetSize(rank and rank.mark == "skull" and 16 or 12, rank and rank.mark == "skull" and 16 or 12)
end

-- Cast bar: runs on the times the game gives. When it keeps them secret the bar shows full with the name.
local function CastOnUpdate(bar)
    local now = GetTime()
    if now >= bar.stop and bar.estimated then            -- our own guess of its length ran out: full, until it ends
        bar.fill:SetValue(1)
        return
    end
    if now >= bar.stop then
        bar:SetScript("OnUpdate", nil)
        bar:Hide()
        bar.label:Hide()
        return
    end
    local p = (now - bar.start) / (bar.stop - bar.start)
    if bar.channel then p = 1 - p end
    bar.fill:SetValue(p)
end

local function UpdateCast(f)
    local bar = f.cast
    if not bar then return end
    local name, startMS, endMS, channel, shielded = U.Cast(f.unit)
    if not name then
        bar:SetScript("OnUpdate", nil)
        bar:Hide()
        bar.label:Hide()
        bar.seen, bar.estimated, bar.duration = nil, nil, nil
        return
    end
    bar.label:SetText(name)
    bar.label:Show()
    bar:Show()
    bar:SetColor(unpack((not ns.IsSecret(shielded) and shielded) and C.shielded or C.cast))
    bar.fill:SetMinMaxValues(0, 1)
    bar.fill:SetAlpha(1)
    bar.trail:SetValue(0)
    if ns.IsSecret(startMS) or ns.IsSecret(endMS) or not startMS or not endMS or endMS <= startMS then
        -- the game keeps the times to itself: the cast's own duration fills the bar (Theme.lua); failing that,
        -- the spell's length or what this unit took last time, from the moment we saw it begin; failing all of
        -- it, a dim full bar that only says "casting"
        bar:SetScript("OnUpdate", nil)
        bar.estimated = nil
        bar.seen = bar.seen or GetTime()
        if ns.GameCastTimer(bar, f.unit, channel) then
            if bar.duration then bar:SetScript("OnUpdate", ns.CastTick) end
            return
        end
        local length = (not channel) and ns.CastLength(f.unit)
        if length then
            bar.start, bar.stop, bar.channel, bar.estimated = bar.seen, bar.seen + length, false, true
            bar:SetScript("OnUpdate", CastOnUpdate)
            CastOnUpdate(bar)
        else
            bar.fill:SetValue(1)
            bar.fill:SetAlpha(0.35)
        end
        return
    end
    bar.seen, bar.estimated, bar.duration = nil, nil, nil
    bar.start, bar.stop, bar.channel = startMS / 1000, endMS / 1000, channel and true or false
    bar:SetScript("OnUpdate", CastOnUpdate)
    CastOnUpdate(bar)
end

---------------------------------------------------------------------------
-- Your pet's mood (a hunter's pet: happy, content, unhappy), as the game tells it: a thin band beside the pet
-- bar in its colour, and food beside it when it needs feeding. A pet without one (a warlock's, a guardian), or a
-- game that does not say: nothing is shown.
---------------------------------------------------------------------------
ns.RegisterSetting({
    key = "petMood", kind = "boolean", default = true, command = "petmood", section = "Frames",
    label = "Pet happiness",
    tip = "beside the pet bar, a thin band in the colour of your pet's mood: green happy, yellow content, red unhappy, with food beside it when it needs feeding. Nothing for a pet without a mood",
})
UF.MOOD = { [1] = "danger", [2] = "caution", [3] = "health" }      -- unhappy, content, happy: ns.colors
UF.FOOD = "Interface\\Icons\\INV_Misc_Food_14"

-- 1 unhappy, 2 content, 3 happy; nil when there is nothing to say
function UF.PetMood()
    if UF.fake then return UF.fake.mood end
    if not GetPetHappiness then return nil end
    local ok, mood = pcall(GetPetHappiness)
    mood = ok and ns.Plain(mood)
    if type(mood) ~= "number" or not UF.MOOD[mood] then return nil end
    return mood
end

local function UpdateMood(f)
    if not f.mood then return end
    local mood = ns.db.petMood and UF.PetMood()
    f.moodKey = mood and UF.MOOD[mood] or nil
    if not mood then
        f.mood:Hide()
        f.moodIcon:Hide()
        return
    end
    local c = C[UF.MOOD[mood]]
    f.mood:SetColorTexture(c[1], c[2], c[3], mood == 3 and 0.55 or 0.95)    -- happy: there, but quiet
    f.mood:Show()
    if mood == 1 then
        f.moodIcon:SetTexture(UF.FOOD)
        f.moodIcon:Show()
    else
        f.moodIcon:Hide()
    end
end
UF.UpdateMood = UpdateMood

local function UpdateAll(f, instant)
    if not f.on then return end
    if f.key ~= "player" and not U.Exists(f.unit) then return end
    UpdateHealth(f, instant)
    UpdatePower(f, instant)
    UpdateInfo(f)
    UpdateCast(f)
    UpdateMood(f)
end

-- The vertical bars' figures sit at their foot, on the side the pet bar takes: beside it they move out past it
local function PlaceVerticalText()
    local v, p = UF.frames.vertical, UF.frames.vpet
    if not (v and v.text) then return end
    v.text:ClearAllPoints()
    if p and p.on and p.button:IsShown() then
        v.text:SetPoint("BOTTOMRIGHT", p.health, "BOTTOMLEFT", -8, 9)
    else
        v.text:SetPoint("BOTTOMRIGHT", v.health, "BOTTOMLEFT", -4, 9)
    end
end
UF.PlaceVerticalText = PlaceVerticalText

---------------------------------------------------------------------------
-- Life: the player bar dims when nothing is happening, and every bar reacts to what happens to it
---------------------------------------------------------------------------
-- Your bars step back unless they matter: they fade at full health, and out of combat, and only stay while you
-- are hurt in a fight. Health the game keeps secret counts as hurt in a fight (nothing to judge by).
-- A call to action: your health below its threshold, or your mana below its own (the bars come back in full).
-- Health the game keeps secret counts as one (nothing to judge by).
local function CallToAction(combat)
    local f = UF.frames.player.on and UF.frames.player or UF.frames.vertical
    local hp = f.health:GetFraction()
    if hp == nil then return combat end             -- secret health: nothing to judge by (in a fight, show)
    if hp < ns.db.alertHealth then return true end
    local pp = f.power:GetFraction()
    if pp and f.powerToken == "MANA" and pp < ns.db.alertPower then return true end
    return false
end

-- Out of combat your bars rest at their idle level; in a fight at the combat level, and in full at a call to
-- action. (calm: out of combat, or in a fight with nothing calling)
local function PlayerIsCalm(combat)
    if UnitExists("target") and ns.Yes(UnitIsUnit("target", "player")) then return false end   -- you look at yourself
    return not CallToAction(combat)                 -- low health or mana is never hidden, in a fight or not
end

local HEAVY = { amp = 4, freq = 95, axis = "xy", time = 0.25 }

-- (moved the way every frame of ours is: not at all while the game holds it still in a fight; Impact.lua)
local function Offset(f, dx, dy)
    return ns.Impact.Pin(f.visual, f.button, dx, dy)
end

local function Animate(f, dt, now, combat)
    if f.flashA > 0 then
        f.flashA = math.max(0, f.flashA - dt * 3.5)
        f.flash:SetAlpha(f.flashA)
    end
    if f.pop > 0 then
        f.pop = math.max(0, f.pop - dt)
        f.visual:SetScale(1 + 0.06 * f.pop / POP_TIME)
    end
    if f.glow and f.glow:IsShown() then
        f.glow:SetAlpha(0.6 + 0.35 * math.sin(now * 7))
    end
    if f.combatGlow then
        local want = combat and (0.5 + 0.15 * math.sin(now * 3)) or 0
        local a = f.combatA
        if a ~= want then
            a = a + (want - a) * math.min(1, dt * 6)
            if math.abs(a - want) < 0.01 then a = want end
            f.combatA = a
            f.combatGlow:SetAlpha(a)
        end
    end
end

---------------------------------------------------------------------------
-- The vertical bars follow the camera (an option): your character looks bigger when the camera comes closer,
-- so the bars ease out from the middle of the screen, and back in as it pulls away, to stay just beside you.
-- Where you put them (Edit Mode) is where they sit at the distance you put them at. Only their drawing moves,
-- so this works in a fight too; the frame you click stays put.
--
-- Gently, and within bounds whatever range your camera has:
--   * they move by how much you grow on screen, not by their whole distance from the middle (FOLLOW.gain);
--   * pulling the camera away brings them in only so far (FOLLOW.inward), never onto your character;
--   * coming closer than FOLLOW.near, or into first person, holds them where they were at that distance;
--   * they never leave the screen: their drawing keeps FOLLOW.margin to every edge;
--   * and they glide there (FOLLOW.rate), they do not jump.
---------------------------------------------------------------------------
ns.RegisterSetting({
    key = "followZoom", kind = "boolean", default = true, command = "followzoom", section = "Frames",
    label = "Vertical bars follow the camera",
    tip = "the vertical bars keep their place beside your character as the camera zooms in and out (place them in Edit Mode at a distance you like)",
})
ns.RegisterSaved("followRef", function(old)              -- the camera distance the bars were placed at
    local z = tonumber(old)
    return (z and z > 0.5) and z or nil
end)
ns.RegisterSetting({
    key = "lastNames", kind = "boolean", default = true, command = "lastnames", section = "Frames",
    label = "Last names", tip = "a player's full name on the unit frames and nameplates, last name included: Faith Ashborne",
})
ns.RegisterSetting({
    key = "targetHealthText", kind = "boolean", default = true, command = "targethealthtext", section = "Frames",
    label = "Health on the target bar", tip = "the health left (12.3k) and the percent on the target and focus bars; a compact target shows the percent alone",
})
local FOLLOW = { gain = 0.35, inward = -0.25, near = 3, margin = 24, rate = 2.5, nudge = 60 }
-- nudge: a little further out still as the camera comes in, up to this much (about four of the bars' widths) by
-- the time you look half again as big; your character, over the camera's shoulder, sits further out at those
-- distances than its size alone says
UF.FOLLOW = FOLLOW
local function CameraDistance()
    if not GetCameraZoom then return nil end
    local ok, z = pcall(GetCameraZoom)
    if ok and type(z) == "number" and not ns.IsSecret(z) and z > 0.5 then return z end
end
UF.CameraDistance = CameraDistance

-- The distance the bars go by: the camera's, with first person and anything closer than FOLLOW.near held at near
local function FollowDistance()
    if not GetCameraZoom then return nil end
    local ok, z = pcall(GetCameraZoom)
    if not ok or type(z) ~= "number" or ns.IsSecret(z) then return nil end
    return math.max(z, FOLLOW.near)
end

local function Within(v, lo, hi)
    if lo > hi then return v end                                     -- (wider than the screen: nothing to hold)
    return v < lo and lo or (v > hi and hi or v)
end

function UF:Follow(dt)
    local f = self.frames.vertical
    if not (f and f.on) then return end
    local tx, ty = 0, 0
    local z = ns.db.followZoom and not ns.arranging and FollowDistance()
    if z then
        if not ns.db.followRef then ns.db.followRef = z end
        local grow = math.max(FOLLOW.inward, (math.max(ns.db.followRef, FOLLOW.near) / z - 1) * FOLLOW.gain)
        local cx, cy = f.mover:GetCenter()
        local ux, uy = UIParent:GetCenter()
        if type(cx) == "number" and type(ux) == "number" then
            tx, ty = (cx - ux) * grow, (cy - uy) * grow
            if grow > 0 and cx ~= ux then                            -- outward: away from the middle
                local away = cx < ux and -1 or 1
                tx = tx + away * FOLLOW.nudge * math.min(1, grow / FOLLOW.gain)
            end
            local okS, w, h = pcall(f.mover.GetSize, f.mover)
            if not okS or type(w) ~= "number" or type(h) ~= "number" then w, h = 0, 0 end
            local m = FOLLOW.margin
            tx = Within(tx, m + w / 2 - cx, ux * 2 - m - w / 2 - cx)
            ty = Within(ty, m + h / 2 - cy, uy * 2 - m - h / 2 - cy)
        end
    end
    local v = f.visual
    local bx, by = v.baseX or 0, v.baseY or 0
    if math.abs(tx - bx) < 0.3 and math.abs(ty - by) < 0.3 then return end
    local rate = math.min(1, (dt or 0.05) * FOLLOW.rate)             -- glide, do not jump
    v.baseX, v.baseY = bx + (tx - bx) * rate, by + (ty - by) * rate
    if not ns.Impact.shaking[v] and not Offset(f, 0, 0) then
        v.baseX, v.baseY = bx, by                                    -- held still in a fight: from here afterwards
    end
    local pet = self.frames.vpet                                     -- the pet beside them goes along
    if pet and pet.on then
        pet.visual.baseX, pet.visual.baseY = v.baseX, v.baseY
        if not ns.Impact.shaking[pet.visual] then Offset(pet, 0, 0) end
    end
end

local driver = CreateFrame("Frame")
local calmFor, sinceCheck, calm, inCombat = 0, 0, false, false

local function OnUpdate(_, dt)
    local player = UF.frames.player
    if not player then return end
    local now = GetTime()
    UF:AnimateThreat(now)
    UF:Follow(dt)
    sinceCheck = sinceCheck + dt
    if sinceCheck >= 0.2 then
        sinceCheck = 0
        local combat = U.Combat()
        if combat and not inCombat and player.on then player.pop = POP_TIME end
        inCombat = combat
        calm = (player.on or UF.frames.vertical.on) and PlayerIsCalm(combat)
        if not calm then calmFor = 0 end
        -- the game sends no events for a target's target: look at it a few times a second
        UF:UpdateTargetThreat()
        local tot = UF.frames.tot
        if tot.on and not UF.fake and U.Exists("targettarget") then
            -- who it is: by GUID or name, unless the game keeps both secret (then look again each time)
            local guid, name = ns.GUID("targettarget"), ns.Plain(UnitName("targettarget"))
            local who = (guid or name) and ((guid or "") .. "|" .. (name or "")) or nil
            local changed = who == nil or who ~= tot.lastName
            tot.lastName = who
            UpdateAll(tot, changed)
        end
    end
    if calm then calmFor = calmFor + dt end
    for _, key in ipairs(ORDER) do
        local f = UF.frames[key]
        if f.on then Animate(f, dt, now, inCombat) end
    end
    local quiet = calm and calmFor >= FADE_DELAY and not UF.unlocked
    -- how visible your bars are when quiet: the idle level out of combat, the combat level in a fight
    local function Rest(idle) if inCombat then return ns.db.combatAlpha end return idle end
    local vertical = UF.frames.vertical
    if vertical.on then                                   -- the vertical bars fade on their own setting
        local vwant = quiet and Rest(ns.db.verticalIdle) or 1
        local va = UF.valpha
        if va ~= vwant then
            local step = FADE_SPEED * dt
            if vwant > va then va = math.min(vwant, va + step * 3) else va = math.max(vwant, va - step) end
            UF.valpha = va
            vertical.visual:SetAlpha(va)
            UF.frames.vpet.visual:SetAlpha(va)                -- (the pet beside them with them)
        end
    end
    -- the focus frame steps back out of combat (it does not depend on your health)
    local focus = UF.frames.focus
    if focus.on then
        local fwant = (UF.unlocked or UF.fake) and 1 or (inCombat and ns.db.combatAlpha or ns.db.idle)
        local fa = UF.falpha or 1
        if fa ~= fwant then
            local step = FADE_SPEED * dt
            if fwant > fa then fa = math.min(fwant, fa + step * 3) else fa = math.max(fwant, fa - step) end
            UF.falpha = fa
            focus.visual:SetAlpha(fa)
        end
    end
    if not player.on then return end
    local want = quiet and Rest(ns.db.idle) or 1
    local a = UF.alpha
    if a ~= want then
        local step = FADE_SPEED * dt
        if want > a then a = math.min(want, a + step * 3) else a = math.max(want, a - step) end
        UF.alpha = a
        player.visual:SetAlpha(a)
        UF.frames.pet.visual:SetAlpha(a)
    end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local events = CreateFrame("Frame")
local UNIT_EVENTS = {
    UNIT_HEALTH = UpdateHealth, UNIT_MAXHEALTH = UpdateHealth,
    UNIT_POWER_UPDATE = UpdatePower, UNIT_MAXPOWER = UpdatePower, UNIT_DISPLAYPOWER = UpdatePower,
    UNIT_NAME_UPDATE = UpdateInfo, UNIT_LEVEL = UpdateInfo, UNIT_CLASSIFICATION_CHANGED = UpdateInfo,
    UNIT_FACTION = UpdateHealth, UNIT_FLAGS = UpdateHealth,
    UNIT_HEAL_PREDICTION = UpdateHealth, UNIT_ABSORB_AMOUNT_CHANGED = UpdateHealth,
    UNIT_SPELLCAST_START = UpdateCast, UNIT_SPELLCAST_STOP = UpdateCast, UNIT_SPELLCAST_FAILED = UpdateCast,
    UNIT_SPELLCAST_INTERRUPTED = UpdateCast, UNIT_SPELLCAST_DELAYED = UpdateCast,
    UNIT_SPELLCAST_CHANNEL_START = UpdateCast, UNIT_SPELLCAST_CHANNEL_STOP = UpdateCast,
    UNIT_SPELLCAST_CHANNEL_UPDATE = UpdateCast,
}
local WORLD_EVENTS = { "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "UNIT_PET",
                       "PLAYER_REGEN_DISABLED", "UNIT_HAPPINESS", "PET_UI_UPDATE", "RAID_TARGET_UPDATE" }

local OnEvent = ns.Protect(function(_, event, unit)
    if event == "PLAYER_REGEN_DISABLED" then
        -- last moment before the game locks secure frames: hand them back in working order
        if UF.fake then UF:SetDemo(false) end
        if UF.unlocked then UF:SetUnlocked(false) end
        local player = UF.frames.player
        if player and player.on and not inCombat then player.pop = POP_TIME end
        inCombat = true
        return
    end
    if UF.fake then return end                 -- the demo is drawing; real events wait
    local handler = UNIT_EVENTS[event]
    if handler then
        for _, key in ipairs(ORDER) do
            local f = UF.frames[key]
            if f and f.on and f.unit == unit and (key == "player" or U.Exists(unit)) then handler(f) end
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        if UF.frames.target then UpdateAll(UF.frames.target, true) end
        if UF.frames.tot then UF.frames.tot.lastName = nil; UpdateAll(UF.frames.tot, true) end
    elseif event == "PLAYER_FOCUS_CHANGED" then
        if UF.frames.focus then UpdateAll(UF.frames.focus, true) end
    elseif event == "UNIT_PET" then
        if UF.frames.pet then UpdateAll(UF.frames.pet, true) end
        if UF.frames.vpet then UpdateAll(UF.frames.vpet, true) end
        PlaceVerticalText()                    -- (the game shows its button a moment later: OnShow does it again)
    elseif event == "RAID_TARGET_UPDATE" then          -- someone marked or unmarked: every mark looked at again
        for _, key in ipairs(ORDER) do
            local f = UF.frames[key]
            if f and f.on then UF.Mark(f) end
        end
    elseif event == "UNIT_HAPPINESS" or event == "PET_UI_UPDATE" then   -- the pet's mood
        if UF.frames.pet then UpdateMood(UF.frames.pet) end
        if UF.frames.vpet then UpdateMood(UF.frames.vpet) end
    else
        for _, key in ipairs(ORDER) do
            if UF.frames[key] then UpdateAll(UF.frames[key], true) end
        end
    end
end)

local function SetEvents(on)
    if on == UF.listening then return end
    UF.listening = on
    if on then
        for event in pairs(UNIT_EVENTS) do pcall(events.RegisterEvent, events, event) end
        for _, event in ipairs(WORLD_EVENTS) do pcall(events.RegisterEvent, events, event) end
        events:SetScript("OnEvent", OnEvent)
        driver:SetScript("OnUpdate", ns.Protect(OnUpdate))
    else
        events:UnregisterAllEvents()
        events:SetScript("OnEvent", nil)
        driver:SetScript("OnUpdate", nil)
    end
end

---------------------------------------------------------------------------
-- Turning on and off (never called in combat: see ns.Apply)
---------------------------------------------------------------------------
-- The game's Edit Mode: while it is open our frames can be dragged too.
local function HookEditMode()
    local manager = _G.EditModeManagerFrame
    if UF.editHooked or type(manager) ~= "table" or not manager.HookScript then return end
    UF.editHooked = true
    manager:HookScript("OnShow", ns.Protect(function()
        if ns.ShouldRun() and not UF.unlocked and UF:SetUnlocked(true) then UF.byEditMode = true end
    end))
    manager:HookScript("OnHide", ns.Protect(function()
        if UF.byEditMode then UF:SetUnlocked(false) end
    end))
end

-- Should this frame be on? Target of target follows the game's own option for it.
function UF:Wanted(key, run)
    local db = ns.db
    if not run then return false end
    if key == "tot" then return (db.units.target and ns.GetNative("tot") ~= false) and true or false end
    if key == "player" and db.units.vertical then return false end        -- the vertical bars take its place
    if key == "pet" and (not db.units.player or db.units.vertical) then return false end   -- it hangs under the player bar
    if key == "vpet" then return (db.units.vertical and db.units.pet) and true or false end   -- beside the vertical bars
    return db.units[key] and true or false
end

function UF:Apply(run)
    local db = ns.db
    if self.fake then self:SetDemo(false) end
    if run then HookEditMode() end
    if run and not self.frames.player then
        for _, key in ipairs(ORDER) do Create(key) end
        local vpet = self.frames.vpet
        vpet.button:HookScript("OnShow", ns.Protect(PlaceVerticalText))
        vpet.button:HookScript("OnHide", ns.Protect(PlaceVerticalText))
    end
    local any = false
    for _, key in ipairs(ORDER) do
        local f = self.frames[key]
        if f then
            local want = self:Wanted(key, run)
            if want then
                f.mover:SetScale(db.scale)
                f.button:SetScale(db.scale)
                Place(f)
            end
            if want ~= f.on then
                f.on = want
                if ALWAYS[key] then
                    if want then f.button:Show() else f.button:Hide() end
                elseif want then
                    RegisterUnitWatch(f.button)
                else
                    UnregisterUnitWatch(f.button)
                    f.button:Hide()
                end
            end
            any = any or want
        end
    end
    local aside = run and db.hideBlizzard
    -- the game's frames are made invisible, never moved: the controller opens the unit menu (leave party,
    -- inspect...) from them, so they have to stay where the game keeps them
    ns.SetBlizzardFaded("PlayerFrame", aside and (db.units.player or db.units.vertical) or false)
    ns.SetBlizzardFaded("TargetFrame", aside and db.units.target or false)
    ns.SetBlizzardFaded("FocusFrame", aside and db.units.focus or false)
    SetEvents(any)
    PlaceVerticalText()
    if not any and self.unlocked then self:SetUnlocked(false) end
    self:ApplyLook()
    for _, key in ipairs(ORDER) do
        if self.frames[key] then UpdateAll(self.frames[key], true) end
    end
end

-- Text size and the shade behind the target's text. The bars move down as the name grows.
function UF:ApplyLook()
    ns.ApplyFonts()
    local scale = ns.db.textScale
    local target = self.frames.target
    if target then                                         -- the compact target frame: a little over half as wide
        local w = ns.db.targetCompact and math.floor(LAYOUT.target.w * 0.6) or LAYOUT.target.w
        target.mover:SetWidth(w)
        target.health:SetBarWidth(w)
        target.power:SetBarWidth(w)
        target.cast:SetBarWidth(w - 16)
        -- the name has the bar's width, and room even over a compact bar (it may reach past the bar's end); a
        -- longer one ends with "...". The threat shield sits beside the bar, so nothing competes with the name;
        -- the target of target moves out past both.
        local nameW = math.max(w, NAME_MIN)
        if target.name then
            target.name:SetWidth(nameW)
            if target.name.SetWordWrap then target.name:SetWordWrap(false) end
        end
        local shield = 30 + (ns.db.threatPercent and 44 or 0)          -- the shield, and its number when shown
        UF.totGap = math.max(TOT_GAP, nameW - w + 24, shield + 12)
        self:PlaceThreat()
        local tot = self.frames.tot
        if tot and tot.mover and not ns.db.pos.tot then Place(tot) end
    end
    for key, lay in pairs(LAYOUT) do
        local f = self.frames[key]
        if f and lay.text then
            local nameH = math.ceil(lay.text * scale + 4)
            f.health:ClearAllPoints()
            f.health:SetPoint("TOPLEFT", f.visual, "TOPLEFT", 0, -nameH)
            f.mover:SetHeight(nameH + lay.bar + 8)
        end
    end
    for _, key in ipairs(ORDER) do
        local f = self.frames[key]
        if f and f.shade then
            if ns.db.textShade then f.shade:Show() else f.shade:Hide() end
        end
    end
end

-- The target frame's threat: the shield icon at the right end of the bar (max, gaining, losing, calm), a glow
-- behind the name in its colour, and your share as a number when wanted (ns.ThreatLook in Theme.lua)
function UF:UpdateTargetThreat()
    local f = self.frames.target
    if not (f and f.on and f.name) then return end
    if not f.threatIcon then
        f.threatIcon = f.visual:CreateTexture(nil, "OVERLAY")
        f.threatIcon:SetSize(16, 16)
        f.threatText = ns.FontString(f.visual, 10, "RIGHT")
        self:PlaceThreat()
        f.threatGlow = f.visual:CreateTexture(nil, "BACKGROUND")
        f.threatGlow:SetTexture(ns.media.soft)
        f.threatGlow:SetBlendMode("ADD")
        f.threatGlow:SetPoint("TOPLEFT", f.health, "TOPLEFT", -16, 12)
        f.threatGlow:SetPoint("BOTTOMRIGHT", f.health, "BOTTOMRIGHT", 16, -12)
        f.threatGlow:SetAlpha(0)
    end
    local state, pct
    if self.fake then
        local k = self.fake.target
        if ns.db.targetThreat and self.fake.combat and k and k.attackable and k.threat then
            state, pct = ns.THREAT_STATE[k.threat], k.threatPct
        end
    elseif ns.db.targetThreat and UnitExists("target") and ns.Yes(UnitCanAttack("player", "target"))
        and ns.Yes(UnitAffectingCombat("target")) then
        state, pct = ns.ThreatOn("target")
    end
    self.threatState = state
    if state then
        ns.SetThreatIcon(f.threatIcon, state)
        f.threatIcon:Show()
    else
        f.threatIcon:Hide()
        f.threatGlow:SetAlpha(0)
    end
    if state and pct and ns.db.threatPercent then
        local c = state == "max" and C.angry or C.text
        f.threatText:SetTextColor(c[1], c[2], c[3])
        f.threatText:SetText(("%d%%"):format(pct + 0.5))
        f.threatText:Show()
    else
        f.threatText:Hide()
    end
end

-- Where the shield sits: on the bar's line, just past its right end (the name above has the room)
function UF:PlaceThreat()
    local f = self.frames.target
    if not (f and f.threatIcon) then return end
    f.threatIcon:ClearAllPoints()
    f.threatText:ClearAllPoints()
    f.threatIcon:SetPoint("LEFT", f.health, "RIGHT", 6, 0)
    f.threatText:SetPoint("LEFT", f.threatIcon, "RIGHT", 3, 0)
    if f.threatText.SetJustifyH then f.threatText:SetJustifyH("LEFT") end
end

-- Every frame: the threat colour turning (gaining and losing mix two colours)
function UF:AnimateThreat(now)
    local f = self.frames.target
    if not (self.threatState and f and f.threatIcon) then return end
    local r, g, b, a = ns.ThreatLook(self.threatState, now)
    f.threatIcon:SetVertexColor(r, g, b, 1)
    f.threatGlow:SetVertexColor(r, g, b, 1)
    f.threatGlow:SetAlpha(a * 0.75)
end


function UF:Refresh()
    for _, key in ipairs(ORDER) do
        if self.frames[key] then UpdateAll(self.frames[key], true) end
    end
end

---------------------------------------------------------------------------
-- Moving the frames
---------------------------------------------------------------------------
local function SavePosition(f)
    local mover = f.mover
    local cx, cy = mover:GetCenter()
    local ux, uy = UIParent:GetCenter()
    local scale = mover:GetScale()
    if not (cx and ux and scale and scale > 0) then return end
    ns.db.pos[f.key] = { x = cx - ux / scale, y = cy - uy / scale }
    if f.key == "vertical" then ns.db.followRef = CameraDistance() end    -- placed for the distance you are at
    Place(f)
end

function UF:SetUnlocked(unlock)
    if unlock and (InCombatLockdown() or not self.frames.player) then return false end
    self.unlocked = unlock and true or false
    if not self.unlocked then self.byEditMode = false end
    for _, key in ipairs(MOVERS) do
        local f = self.frames[key]
        if f then
            local mover = f.mover
            mover:SetFrameStrata(self.unlocked and "HIGH" or "LOW")
            mover:EnableMouse(self.unlocked)
            mover:SetMovable(self.unlocked)
            if self.unlocked then
                mover:RegisterForDrag("LeftButton")
                mover:SetScript("OnDragStart", function(m) if not InCombatLockdown() then m:StartMoving() end end)
                mover:SetScript("OnDragStop", function(m) m:StopMovingOrSizing(); SavePosition(f) end)
                mover.overlay:Show()
                mover.label:Show()
            else
                mover:SetScript("OnDragStart", nil)
                mover:SetScript("OnDragStop", nil)
                mover.overlay:Hide()
                mover.label:Hide()
            end
        end
    end
    local soon = ns.Numbers and ns.Numbers.Soon                 -- the cooldown callouts move with the frames
    if soon then soon:SetUnlocked(self.unlocked) end
    return true
end

function UF:ResetPositions()
    ns.db.pos = {}
    return ns.Apply()
end

---------------------------------------------------------------------------
-- Demo: a short made-up fight, to see every state of the frames without having to go and find one.
---------------------------------------------------------------------------
-- school: the hit effect it shows on that frame (each school takes a turn in the demo)
local function DemoHit(unit, share, school, crit)
    local k = UF.fake[unit]
    k.health = math.max(0, k.health - k.healthMax * share)
    local f = UF.frames[unit]
    UpdateHealth(f)
    if school and f.on and ns.Impact and ns.db.impacts then
        ns.Impact:Hit({ frame = f.visual, anchor = f.button, bar = f.health }, school, crit)
    end
    if ns.Numbers then ns.Numbers:Demo(unit, -math.floor(k.healthMax * share), school, crit) end
end

local function DemoTarget(data)
    UF.fake.target = data
    UF.frames.target.lastFrac = nil
    UpdateAll(UF.frames.target, true)
end

local DEMO = {
    { 1.0, function(k) k.combat = true; k.target.threat = 1; DemoHit("player", 0.12, "physical") end },
    { 1.8, function(k) DemoHit("target", 0.20, "holy"); k.combo = 2; k.target.threat = 3 end },
    { 2.5, function(k)
        local now = GetTime() * 1000
        k.target.cast = { name = L["Fireball"], start = now, stop = now + 2000 }
        UpdateCast(UF.frames.target)
    end },
    { 3.0, function(k) DemoHit("player", 0.25, "fire"); k.player.power = k.player.powerMax * 0.6; UpdatePower(UF.frames.player) end },
    { 3.6, function(k) DemoHit("target", 0.10, "frost") end },
    { 4.2, function(k) DemoHit("target", 0.30, "holy", true); DemoHit("pet", 0.4, "shadow"); k.combo = 4; k.target.threat = 2 end },
    { 4.6, function(k) k.target.cast = nil; UpdateCast(UF.frames.target) end },
    { 5.0, function(k) DemoHit("player", 0.30, "shadow"); k.target.cc = {} end },
    { 6.0, function() DemoHit("player", 0.15, "nature") end },
    { 6.8, function(k)
        if ns.Numbers then ns.Numbers:Demo("player", math.floor(k.player.healthMax * 0.2), "heal") end
    end },
    { 7.5, function(k) DemoHit("target", 0.40, "arcane", true); k.combo = 5; k.target.threat = 3 end },
    { 8.5, function()
        DemoTarget({ name = L["Friendly mage"], level = 60, health = 4200, healthMax = 4200, isPlayer = true,
                     class = "MAGE", reaction = 5 })
    end },
    { 9.5, function(k)
        local now = GetTime() * 1000
        k.combo = 0
        k.player.cast = { name = L["Healing"], start = now, stop = now + 1400 }
        k.player.health, k.player.power = k.player.healthMax, k.player.powerMax
        UpdateHealth(UF.frames.player); UpdatePower(UF.frames.player)
    end },
    { 11.0, function(k) k.combat = false; k.player.cast = nil end },
    { 13.0, function() UF:StartDemoLoop() end },
}

local demoFrame = CreateFrame("Frame")

-- The modules that draw around the unit frames follow the demo too
function UF:DemoOthers()
    if ns.Auras then ns.Auras:Refresh() end
    if ns.CastBar then ns.CastBar:Refresh() end
end

function UF:StartDemoLoop()
    local hp, hpMax = UnitHealthMax("player"), UnitHealthMax("player")
    if ns.IsSecret(hpMax) or type(hpMax) ~= "number" or hpMax <= 0 then hp, hpMax = 1000, 1000 end
    local _, token = UnitPowerType("player")
    local _, class = UnitClass("player")
    self.fake = {
        combat = false,
        player = { health = hp, healthMax = hpMax, power = 100, powerMax = 100, powerToken = token or "MANA",
                   class = class, isPlayer = true },
        pet = { health = 600, healthMax = 600, name = L["Pet"] },
        target = { name = L["Training dummy"], level = 35, classification = "elite", health = 5000,
                   healthMax = 5000, attackable = true, reaction = 2, threatPct = 100,
                   -- your debuffs (a judgement, a stacking one), its buffs, and crowd control on it
                   auras = { { icon = 135959, applications = 1, duration = 20, expirationTime = GetTime() + 20 },
                             { icon = 135926, applications = 1, duration = 8, expirationTime = GetTime() + 8 },
                             { icon = 132212, applications = 3, duration = 12, expirationTime = GetTime() + 9 } },
                   buffs = { { icon = 136224, applications = 1, duration = 10, expirationTime = GetTime() + 10 },
                             { icon = 135940, applications = 1, duration = 30, expirationTime = GetTime() + 30 } },
                   cc = { { icon = 135963, applications = 1, duration = 6, expirationTime = GetTime() + 6 } } },
        combo = 0,
        focus = { name = L["Friendly healer"], level = 60, health = 3100, healthMax = 3800, isPlayer = true,
                  class = "PRIEST", reaction = 5 },
        targettarget = { name = UnitName("player") or L["Player"], health = hp, healthMax = hpMax, isPlayer = true,
                         class = class, reaction = 5 },
    }
    self.demoT, self.demoStep = 0, 1
    for _, key in ipairs(ORDER) do
        local f = self.frames[key]
        f.lastFrac = nil
        UpdateAll(f, true)
    end
    self:DemoOthers()
end

function UF:SetDemo(on)
    if on then
        if InCombatLockdown() or not self.frames.player or not ns.ShouldRun() then return false end
        if self.fake then return true end
        for _, key in ipairs(WATCHED) do
            local f = self.frames[key]
            if f.on then UnregisterUnitWatch(f.button); f.button:Show() end
        end
        self:StartDemoLoop()
        demoFrame:SetScript("OnUpdate", ns.Protect(function(_, dt)
            if not UF.fake then return end
            UF.demoT = UF.demoT + dt
            local step = DEMO[UF.demoStep]
            while step and UF.fake and UF.demoT >= step[1] do
                UF.demoStep = UF.demoStep + 1
                step[2](UF.fake)
                UF:DemoOthers()
                step = DEMO[UF.demoStep]
            end
        end))
        return true
    end
    if not self.fake then return true end
    self.fake = nil
    demoFrame:SetScript("OnUpdate", nil)
    for _, key in ipairs(WATCHED) do
        local f = self.frames[key]
        if f.on then RegisterUnitWatch(f.button) end
    end
    for _, key in ipairs(ORDER) do
        local f = self.frames[key]
        f.lastFrac, f.flashA = nil, 0
        ns.Impact:Stop(f.visual)
        f.flash:SetAlpha(0)
        Offset(f, 0, 0)
        if f.cast then f.cast:SetScript("OnUpdate", nil); f.cast:Hide(); f.cast.label:Hide() end
    end
    self:Refresh()
    self:DemoOthers()
    return true
end

---------------------------------------------------------------------------
-- At rest (an inn, a city): your frame dozes. Little z's drift up from the top of your health one after
-- another, growing as they rise and fading away, and a soft moonlit glow breathes slowly round your bar. The
-- z's keep their own light, so they show even while the frame itself has faded out of combat. Never in a
-- fight; with Reduce animations the z's stand still.
---------------------------------------------------------------------------
ns.RegisterSetting({
    key = "sleepy", kind = "boolean", default = true, command = "sleepy", section = "Frames",
    label = "Sleepy while resting",
    tip = "in an inn or a city your frame dozes: little z's drift up from it and a soft moonlit glow breathes round it (never in a fight)",
})
UF.MOON = { 0.70, 0.74, 1.00 }  -- moonlight
UF.Z_LIFE = 3.3                  -- seconds for a z to rise and fade
UF.Z_FROM, UF.Z_TO = 9, 18       -- its size as it starts and as it fades
UF.BREATH = 5                    -- seconds for the glow to breathe in and out
UF.dozes = 0

local sleep = CreateFrame("Frame", "ControllerCamHUD_Sleep", UIParent)
sleep:SetSize(1, 1)
sleep:SetFrameStrata("MEDIUM")
sleep:Hide()
sleep.z = {}
for i = 1, 3 do
    local z = ns.FontString(sleep, UF.Z_FROM, "CENTER")
    z:SetText(i == 3 and "Z" or "z")
    z:SetTextColor(UF.MOON[1], UF.MOON[2], UF.MOON[3])
    z:SetAlpha(0)
    sleep.z[i] = z
end
UF.sleep = sleep

-- The frame that dozes now (the vertical bars, else the player frame), or nil
function UF.Dozing()
    if not (ns.db and ns.db.sleepy) then return nil end
    local f = UF.frames.vertical
    if not (f and f.on) then f = UF.frames.player end
    if not (f and f.on and f.health and f.visual) then return nil end
    if ns.Yes(UnitAffectingCombat("player")) then return nil end
    if not (IsResting and ns.Yes(IsResting())) then return nil end
    return f
end

function UF.Doze(f)
    local was = sleep.f
    if was and was ~= f and was.sleepGlow then was.sleepGlow:Hide() end
    sleep.f = f
    if not f then sleep:Hide(); return end
    if not f.sleepGlow then f.sleepGlow = AddGlow(f.visual, f.health, UF.MOON, 12) end
    f.sleepGlow:SetAlpha(0.2)
    f.sleepGlow:Show()
    sleep:Show()
    UF.dozes = UF.dozes + 1
    ns.Note("unit frames: resting, %s dozes", f.key)
end

local function Drift(z, f, p, calm)
    local size = math.floor(UF.Z_FROM + (UF.Z_TO - UF.Z_FROM) * p + 0.5)
    if z.drawn ~= size then
        z.drawn = size
        local file, _, flags = z:GetFont()
        if file then z:SetFont(file, size, flags) end
    end
    z:ClearAllPoints()
    z:SetPoint("BOTTOMLEFT", f.health, "TOPRIGHT", 2 + p * 16 + (calm and 0 or math.sin(p * 6) * 2), 2 + p * 30)
    local a
    if calm then a = 0.8
    elseif p < 0.15 then a = p / 0.15 * 0.9
    else a = (1 - (p - 0.15) / 0.85) * 0.9 end
    z:SetAlpha(math.max(0, a))
end

local doze = CreateFrame("Frame")
local dozeLook = 1
doze:SetScript("OnUpdate", ns.Protect(function(_, dt)
    dozeLook = dozeLook + dt
    if dozeLook >= 0.5 then                                  -- (a look at the world twice a second)
        dozeLook = 0
        local f = UF.Dozing()
        if f ~= sleep.f then UF.Doze(f) end
    end
    local f = sleep.f
    if not f then return end
    local now = GetTime()
    local calm = ns.Calm() and true or false
    for i, z in ipairs(sleep.z) do
        local p = calm and (0.2 + (i - 1) * 0.3) or ((now / UF.Z_LIFE + (i - 1) / 3) % 1)   -- one after another
        Drift(z, f, p, calm)
    end
    if f.sleepGlow then
        f.sleepGlow:SetAlpha(calm and 0.25 or (0.15 + 0.2 * (0.5 + 0.5 * math.sin(now * 2 * math.pi / UF.BREATH))))
    end
end))

ns.RegisterModule("unitframes", UF)
