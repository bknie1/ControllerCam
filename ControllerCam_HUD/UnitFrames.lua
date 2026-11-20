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
}
UF.LAYOUT = LAYOUT
local ORDER = { "player", "target", "pet", "tot", "focus", "vertical" }
local WATCHED = { "target", "pet", "tot", "focus" }     -- shown by the game while their unit exists
local MOVERS = { "player", "target", "tot", "focus", "vertical" }   -- each placed and dragged on its own
local ALWAYS = { player = true, vertical = true }       -- always shown while on (your own bars)
local TARGETLIKE = { target = true, tot = true, focus = true }     -- coloured by what the unit is to you
local LABEL = { player = "Player", target = "Target", pet = "Pet", tot = "Target of target", focus = "Focus",
                vertical = "Vertical bars" }

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
        -- a soft dark band behind the text, so it reads against a bright sky
        f.shade = visual:CreateTexture(nil, "BACKGROUND")
        f.shade:SetTexture(ns.media.soft)
        f.shade:SetVertexColor(0, 0, 0, 0.6)
        f.shade:SetPoint("TOPLEFT", visual, "TOPLEFT", -24, 14)
        f.shade:SetPoint("BOTTOMRIGHT", f.health, "TOPRIGHT", 24, -10)
        f.text = ns.FontString(f.health.over or visual, 9, "RIGHT")   -- on the bar: the name above has the room
        f.text:SetPoint("RIGHT", f.health, "RIGHT", -6, 0)
        f.mark = visual:CreateTexture(nil, "OVERLAY")
        f.mark:SetTexture(ns.media.mark)
        f.mark:SetSize(12, 12)
        f.mark:SetPoint("BOTTOMLEFT", f.health, "TOPLEFT", 8, 4)
        f.mark:Hide()

        f.cast = ns.CreateBar(visual, lay.w - 16, 4)
        f.cast:SetPoint("TOP", f.health, "BOTTOM", 0, -4)
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
    return unpack(C.friendly)
end

-- In a fight (and when wanted) health is coloured by how much is left: green, yellow, red.
local function CombatColor(unit, frac)
    if not ns.db.combatColors or not ns.Yes(UnitAffectingCombat(unit)) then return nil end
    if frac then return ns.HealthGradient(frac) end
    return ns.HealthGradientFor(unit)
end

local function TargetHealthColor(unit, frac)
    local dead, tapped = U.Standing(unit)
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

-- "73%" when the game keeps health secret: the game formats the number itself
function ns.SecretPercent(fs, unit)
    if not (UnitHealthPercent and fs.SetFormattedText) then return false end
    return pcall(function() fs:SetFormattedText("%d%%", UnitHealthPercent(unit, true) * 100) end) and true or false
end

-- A hit lights the bar up; a heavy one shakes it. When a hit effect of yours just landed on this frame
-- (Impact.lua), that one already said it all.
local function Hit(f, share)
    if f.visual.lastImpact and GetTime() - f.visual.lastImpact < 0.3 then return end
    if TARGETLIKE[f.key] and f.key ~= "tot" and ns.Impact.active then
        -- the game told us nothing about this hit (no combat log here): it still lands, as a plain one
        ns.Impact:Hit({ frame = f.visual, anchor = f.button, bar = f.health }, "physical", share >= SHAKE_FROM)
        return
    end
    f.flashA = math.min(1, 0.45 + share * 2)
    f.flash:SetAlpha(f.flashA)
    if share >= SHAKE_FROM then ns.Impact:Shake(f.visual, f.button, HEAVY, 1 + share * 2) end
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
        f.health:SetIncoming(UnitGetIncomingHeals(unit))
    end
    if TARGETLIKE[f.key] then
        f.health:SetColor(TargetHealthColor(unit, frac))
        if f.key == "tot" then
            PercentText(f.text, frac, true, unit)
        elseif f.text then
            -- full size: the health left, shortened, and the percent; compact: the percent alone
            local compact = f.key == "target" and ns.db.targetCompact
            if ns.db.targetHealthText then ns.HealthLine(f.text, unit, frac, not compact, true) else f.text:Hide() end
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

-- A player's class as an icon, in front of the name (target and target of target)
local CLASS_ICONS = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
local function ClassIcon(f)
    if f.classIcon then return f.classIcon end
    local icon = f.visual:CreateTexture(nil, "OVERLAY")
    icon:SetTexture(CLASS_ICONS)
    icon:Hide()
    f.classIcon = icon
    return icon
end

local function UpdateClassIcon(f)
    local icon = ClassIcon(f)
    local class = ns.db.classIcons and U.Class(f.unit)
    local _, _, isPlayer = U.Standing(f.unit)
    local coords = class and isPlayer and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
    if not coords then icon:Hide(); return end
    icon:SetTexCoord(unpack(coords))
    local size = math.ceil((LAYOUT[f.key].text or 12) * ns.db.textScale)
    icon:SetSize(size, size)
    icon:ClearAllPoints()
    if f.key == "tot" then
        icon:SetPoint("RIGHT", f.name, "LEFT", -3, 0)
    else
        icon:SetPoint("RIGHT", f.name, "LEFT", -4, 0)
    end
    icon:Show()
end
UF.UpdateClassIcon = UpdateClassIcon

local function UpdateInfo(f)
    if not f.name then return end
    local name, level, kind = U.Info(f.unit)
    local ok = pcall(function() f.name:SetFormattedText("%s  %s", ns.LevelText(level), name or "") end)
    if not ok then pcall(f.name.SetText, f.name, name) end
    if f.key == "tot" or f.key == "target" then UpdateClassIcon(f) end
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
        return
    end
    bar.label:SetText(name)
    bar.label:Show()
    bar:Show()
    bar:SetColor(unpack((not ns.IsSecret(shielded) and shielded) and C.shielded or C.cast))
    bar.fill:SetMinMaxValues(0, 1)
    bar.trail:SetValue(0)
    if ns.IsSecret(startMS) or ns.IsSecret(endMS) or not startMS or not endMS or endMS <= startMS then
        bar:SetScript("OnUpdate", nil)
        bar.fill:SetValue(1)
        return
    end
    bar.start, bar.stop, bar.channel = startMS / 1000, endMS / 1000, channel and true or false
    bar:SetScript("OnUpdate", CastOnUpdate)
    CastOnUpdate(bar)
end

local function UpdateAll(f, instant)
    if not f.on then return end
    if f.key ~= "player" and not U.Exists(f.unit) then return end
    UpdateHealth(f, instant)
    UpdatePower(f, instant)
    UpdateInfo(f)
    UpdateCast(f)
end

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
local FOLLOW = { gain = 0.35, inward = -0.25, near = 3, margin = 24, rate = 2.5 }
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
    UNIT_HEAL_PREDICTION = UpdateHealth,
    UNIT_SPELLCAST_START = UpdateCast, UNIT_SPELLCAST_STOP = UpdateCast, UNIT_SPELLCAST_FAILED = UpdateCast,
    UNIT_SPELLCAST_INTERRUPTED = UpdateCast, UNIT_SPELLCAST_DELAYED = UpdateCast,
    UNIT_SPELLCAST_CHANNEL_START = UpdateCast, UNIT_SPELLCAST_CHANNEL_STOP = UpdateCast,
    UNIT_SPELLCAST_CHANNEL_UPDATE = UpdateCast,
}
local WORLD_EVENTS = { "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "UNIT_PET",
                       "PLAYER_REGEN_DISABLED" }

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
    return db.units[key] and true or false
end

function UF:Apply(run)
    local db = ns.db
    if self.fake then self:SetDemo(false) end
    if run then HookEditMode() end
    if run and not self.frames.player then
        for _, key in ipairs(ORDER) do Create(key) end
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

ns.RegisterModule("unitframes", UF)
