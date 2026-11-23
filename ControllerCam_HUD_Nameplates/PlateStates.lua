-- ControllerCam HUD: what nameplates show about the fight, and their animations.
--   * Health text: a short number (12.3k), the percent, or both.
--   * Your debuffs above the name, with their time running out.
--   * Aggro: a glow that pulses red while the unit is attacking you, orange when you are about to pull it.
--   * Low health: the bar breathes red under 20%.
--   * Crowd control: a cool shimmer while the unit is stunned, rooted, feared, polymorphed...
--   * A short fade and rise when a plate appears.
-- Works on the plates of Nameplates.lua; secret values are left to the game's own widgets.

local ADDON = ...
local ns = ControllerCamHUD.ns            -- the HUD's own namespace: this file is one of its modules (Modules.lua)
local L, C, U, W = ns.L, ns.colors, ns.Unit, ns.AuraWidgets

local PS = {}
ns.PlateStates = PS

local function Setting(key, label, tip, default)
    ns.RegisterSetting({ key = key, kind = "boolean", default = default, command = key:lower(), section = "Nameplates",
                         label = label, tip = tip })
end
Setting("plateValue", "Health number", "the health left, shortened (12.3k), on the bar (not on compact plates: the percent says enough there)", false)
Setting("plateDebuffs", "Your debuffs", "your debuffs on the unit, above its name, with their time", true)
Setting("plateAllDebuffs", "Everyone's debuffs", "the debuffs the game marks for nameplates from everyone, not only yours", false)
Setting("plateBuffs", "Enemy buffs", "an enemy's buffs beside its debuffs: the ones that matter (important, enraged, or ones you can dispel or steal), or all of them when Only the effects that matter is off", true)
Setting("plateCC", "Crowd control icon", "a large icon with its time when the unit is stunned, rooted, feared...", true)
Setting("plateThreat", "Aggro glow", "a shield icon and a glow behind the name: red while it attacks you, red and yellow when you are about to pull it, yellow and blue when you are losing it, blue when it is not on you", true)
ns.RegisterSetting({
    key = "threatPercent", kind = "boolean", default = false, command = "threatpercent", section = "Frames",
    label = "Threat percent", tip = "your share of the threat as a number beside the threat icon, on the target frame and nameplates",
})
Setting("plateQuest", "Quest marker", "a gold marker on units your quests still need", true)
Setting("plateMotion", "Nameplate animations", "plates fade in, low health breathes, crowd control shimmers", true)
function PS.Motion() return ns.db.plateMotion and not ns.Calm() end      -- (and not with Reduce animations)

local MAX_DEBUFFS, ICON = 4, 18
local LOW = 0.2
local SPAWN = 0.25
-- Classic crowd control by spell id, for clients where the aura filter below is not known
PS.CC = {}
for _, id in ipairs({ 118, 12824, 12825, 12826, 28271, 28272, 6770, 2070, 11297, 1776, 1777, 8629, 11285, 11286,
                      2094, 5782, 6213, 6215, 5484, 17928, 6358, 710, 18647, 9484, 9485, 10955, 605, 10911, 10912,
                      8122, 8124, 10888, 10890, 5246, 853, 5588, 5589, 10308, 408, 8643, 1833, 2637, 18657, 18658,
                      3355, 14308, 14309, 19503, 339, 1062, 5195, 5196, 9852, 9853, 122, 865, 6131, 10230, 5211,
                      6798, 8983, 20549, 7922, 12809, 20066, 19386, 24131, 24132, 24133 }) do
    PS.CC[id] = true
end

---------------------------------------------------------------------------
-- Building, on each plate
---------------------------------------------------------------------------
function PS:Build(o)
    if o.states then return end
    o.states = true
    o.glow = o:CreateTexture(nil, "BACKGROUND")
    o.glow:SetTexture(ns.media.soft)
    o.glow:SetPoint("TOPLEFT", o.health, "TOPLEFT", -16, 13)
    o.glow:SetPoint("BOTTOMRIGHT", o.health, "BOTTOMRIGHT", 16, -13)
    o.glow:SetAlpha(0)
    o.shimmer = o.health.over:CreateTexture(nil, "OVERLAY")
    o.shimmer:SetTexture(ns.media.spark)
    o.shimmer:SetBlendMode("ADD")
    o.shimmer:SetVertexColor(0.6, 0.85, 1, 1)
    o.shimmer:SetSize(26, 26)
    o.shimmer:Hide()
    o.icons = {}
    for i = 1, MAX_DEBUFFS do o.icons[i] = ns.AuraButton(o, ICON, 9) end
    o.buffIcons = {}
    for i = 1, 3 do
        local b = ns.AuraButton(o, ICON - 4, 8)
        b.back:SetColorTexture(0.25, 0.05, 0.05, 0.95)           -- an enemy's buff: a red edge
        o.buffIcons[i] = b
    end
    o.ccIcon = ns.AuraButton(o, ICON + 8, 11)                    -- crowd control, large, beside the bar
    o.ccIcon.back:SetColorTexture(0.35, 0.6, 1, 0.95)
    o.threatIcon = o:CreateTexture(nil, "OVERLAY")              -- the shield: max, gaining, losing, calm
    o.threatIcon:SetSize(14, 14)
    o.threatIcon:SetPoint("LEFT", o.health, "RIGHT", 4, 0)            -- on the bar's line, like the quest marker
    o.threatIcon:Hide()
    o.threatPct = ns.FontString(o, 8, "LEFT")
    o.threatPct:SetPoint("LEFT", o.threatIcon, "RIGHT", 2, 0)
    o.threatPct:Hide()
    o.questIcon = o:CreateTexture(nil, "OVERLAY")
    o.questIcon:SetTexture(ns.media.quest)
    o.questIcon:SetSize(14, 14)
    o.questIcon:Hide()
    o.questText = ns.FontString(o, 8, "LEFT")
    o.questText:SetTextColor(unpack(C.caution))
    o.questText:Hide()
end

---------------------------------------------------------------------------
-- Health text
---------------------------------------------------------------------------
local function Short(n) return ns.ShortNumber(n) end
PS.Short = Short

-- The percent, and with "Health number" on the health left as well (12.3k; not on compact plates). At full
-- health there is nothing to say: no text until the unit is hurt (where the game lets us know that it is full).
function PS:HealthText(o, frac)
    local db = ns.db
    local fs = o.percent
    if not o.bars or o.mini then fs:Hide(); return end
    if type(frac) == "number" and not ns.IsSecret(frac) and frac >= 0.999 then fs:Hide(); return end
    ns.HealthLine(fs, o.unit, frac, db.plateValue and ns.Nameplates.Size() > 1, db.platePercent)
end

---------------------------------------------------------------------------
-- Your debuffs, and whether the unit is under crowd control
---------------------------------------------------------------------------
local function Aura(unit, i, filter) return U.Aura(unit, i, filter) end

local function IsCC(unit)
    local cc = U.Filtered(unit, "HARMFUL", "HARMFUL|CROWD_CONTROL", 1)
    if cc then return #cc > 0 end                   -- the game says it
    local ok, found = pcall(function()
        if Aura(unit, 1, "HARMFUL|CROWD_CONTROL") then return true end
        for i = 1, 16 do
            local a = Aura(unit, i, "HARMFUL")
            if not a then return false end
            local id = a.spellId
            if not ns.IsSecret(id) and PS.CC[id] then return true end
        end
        return false
    end)
    return ok and found or false
end

-- The game's own rows (AuraWidgets.lua), made once per plate. Your debuffs left of the name's centre, the
-- enemy's buffs right of it (red edged), crowd control large beside the bar.
local DEBUFFS_MINE, DEBUFFS_ALL = "HARMFUL|!CROWD_CONTROL|PLAYER", "HARMFUL|!CROWD_CONTROL"
local function GameRows(o)
    if o.wDebuffs == nil then
        o.wDebuffs = W.Row(o, { filter = DEBUFFS_MINE, max = MAX_DEBUFFS, size = ICON, text = 9, grow = "LEFT" }) or false
        if o.wDebuffs then
            o.wDebuffs:SetPoint("BOTTOMRIGHT", o.name, "TOP", -2, 4)
            o.wBuffs = W.Row(o, { filter = W.ENEMY_BUFFS, max = 3, size = ICON - 4, text = 8,
                                  edge = { 0.25, 0.05, 0.05, 0.95 }, typed = true })
            o.wBuffs:SetPoint("BOTTOMLEFT", o.name, "TOP", 2, 4)
            o.wCC = W.Row(o, { filter = "HARMFUL|CROWD_CONTROL", max = 1, size = ICON + 8, text = 11,
                               edge = { 0.35, 0.6, 1, 0.95 } })
            PS:PlaceRight(o)                                     -- at the bar's right end (not over the level)
        end
    end
    return o.wDebuffs
end

-- For the reports (only while they are on): what the game counts on your target's plate and what our rows
-- there are doing, noted whenever it changes. The effects themselves are not read, only counted.
local function Count(unit, filter)
    if not (C_UnitAuras and C_UnitAuras.GetUnitAuraInstanceIDs) then return "?" end
    local ok, ids = pcall(C_UnitAuras.GetUnitAuraInstanceIDs, unit, filter)
    return (ok and type(ids) == "table") and tostring(#ids) or "?"
end
local function RowSays(row)
    if not row then return "none" end
    local icons = 0
    if row.GetChildren then
        for _, child in ipairs({ row:GetChildren() }) do
            if type(child) == "table" and child.IsShown then
                local okS, on = pcall(child.IsShown, child)            -- (a state kept secret is not compared)
                if okS and not ns.IsSecret(on) and on == true then icons = icons + 1 end
            end
        end
    end
    local alpha = row.GetEffectiveAlpha and row:GetEffectiveAlpha()
    return ("%s, %s, %d icons, alpha %s"):format(row.on and "on" or "off", ns.ShownPlain(row) and "shown" or "hidden",
        icons, type(alpha) == "number" and ("%.1f"):format(alpha) or "?")
end
function PS.Trace(o, again)
    if not (ns.db and ns.db.debug and o and o.unit) then return end
    local ok, target = pcall(UnitIsUnit, o.unit, "target")
    if not (ok and ns.Yes(target)) then return end
    local unit = o.unit
    local line = ("harmful %s, yours %s, crowd control %s, important %s; hostile %s, minor %s, bars %s; debuffs: %s; crowd control: %s"):format(
        Count(unit, "HARMFUL"), Count(unit, "HARMFUL|PLAYER"), Count(unit, "HARMFUL|CROWD_CONTROL"),
        Count(unit, "HARMFUL|IMPORTANT"), tostring(o.hostile), tostring(o.mini), tostring(o.bars),
        RowSays(o.wDebuffs), RowSays(o.wCC))
    if line == PS.traced then return end
    PS.traced = line
    ns.Note("plates: your target's plate: %s", line)
    -- (the game fills its rows a moment after the effect lands: looked at once more)
    if not again and C_Timer and C_Timer.After then
        C_Timer.After(0.4, function() pcall(PS.Trace, o, true) end)
    end
end

function PS:Auras(o)
    local unit = o.unit
    local db = ns.db
    if GameRows(o) then
        for i = 1, MAX_DEBUFFS do o.icons[i]:Hide() end
        for i = 1, 3 do o.buffIcons[i]:Hide() end
        o.ccIcon:Hide()
        local fresh = o.auraFresh
        o.auraFresh = nil
        local enemy = o.hostile and not o.mini
        -- only what matters (the setting): your debuffs and the important ones; buffs you can act on or must watch.
        -- A mini plate keeps the debuffs and what holds it (your sting, your trap), and leaves out its buffs.
        local smart = db.smartAuras
        W.Show(o.wDebuffs, unit, db.plateAllDebuffs and DEBUFFS_ALL or (smart and W.ENEMY_DEBUFFS or DEBUFFS_MINE),
               o.hostile and db.plateDebuffs, fresh)
        W.Show(o.wBuffs, unit, smart and W.ENEMY_BUFFS or "HELPFUL|!PLAYER", enemy and db.plateBuffs, fresh)
        W.Show(o.wCC, unit, nil, o.hostile and db.plateCC and o.bars, fresh)
        o.cc = o.bars and (W.Has(unit, "HARMFUL|CROWD_CONTROL") or IsCC(unit)) or false
        pcall(PS.Trace, o)
        return
    end
    local shown, buffShown = 0, 0
    local debuffs, buffs, cc
    if o.hostile then
        debuffs, buffs, cc = U.PlateAuras(unit, MAX_DEBUFFS, not db.plateAllDebuffs)
        if not debuffs then debuffs = U.MyAuras(unit, true, MAX_DEBUFFS) end        -- an older client
        if o.mini then buffs = nil end                                              -- a mini plate: no buffs
    end
    -- debuffs above the name, centred; the enemy's buffs after them, smaller and edged red
    local list = (db.plateDebuffs and debuffs) or {}
    local blist = (db.plateBuffs and buffs) or {}
    local width = #list * (ICON + 5) + #blist * (ICON + 1) - 5
    local x = -width / 2
    for i, a in ipairs(list) do
        shown = i
        local b = o.icons[i]
        b:ClearAllPoints()
        b:SetPoint("BOTTOMLEFT", o.name, "TOP", x, 4)
        ns.ShowAura(b, unit, a)
        x = x + ICON + 5
    end
    for i, a in ipairs(blist) do
        buffShown = i
        local b = o.buffIcons[i]
        b:ClearAllPoints()
        b:SetPoint("BOTTOMLEFT", o.name, "TOP", x, 4)
        ns.ShowAura(b, unit, a)
        x = x + ICON + 1
    end
    for i = shown + 1, MAX_DEBUFFS do o.icons[i]:Hide() end
    for i = buffShown + 1, 3 do o.buffIcons[i]:Hide() end
    -- crowd control: large, left of the bar, with its time
    local control = cc and cc[1]
    if control and db.plateCC and o.bars then
        ns.ShowAura(o.ccIcon, unit, control)
        self:PlaceRight(o)
    else
        o.ccIcon:Hide()
    end
    if cc then o.cc = o.bars and #cc > 0 or false else o.cc = o.bars and IsCC(unit) or false end
end

---------------------------------------------------------------------------
-- Aggro
---------------------------------------------------------------------------
-- Aggro on one plate: "tank" (it is on you), "pulling" (you are about to take it), "losing" (you have it but
-- someone is catching up), or nil. When the game gives no threat numbers, the unit's own target says it.
local OLD_NAMES = { max = "tank", losing = "losing", gaining = "pulling" }
function PS:Threat(o)
    local was = o.threat
    o.threat, o.threatState = nil, nil
    local pct
    if ns.db.plateThreat and o.hostile and o.bars and ns.Yes(UnitAffectingCombat(o.unit)) then
        o.threatState, pct = ns.ThreatOn(o.unit)
        o.threat = OLD_NAMES[o.threatState or ""]
    end
    if o.threatState then
        ns.SetThreatIcon(o.threatIcon, o.threatState)
        local r, g, b = ns.ThreatLook(o.threatState, GetTime())
        o.threatIcon:SetVertexColor(r, g, b, 1)
        o.threatIcon:Show()
    else
        o.threatIcon:Hide()
    end
    self:PlaceRight(o)
    if o.threatState and pct and ns.db.threatPercent then
        o.threatPct:SetText(("%d%%"):format(pct + 0.5))
        o.threatPct:Show()
    else
        o.threatPct:Hide()
    end
    -- a change of hands: the name pops when you take aggro, and shrinks back when you lose it
    if o.threat ~= was then
        if o.threat == "tank" and was ~= "losing" then o.threatPop, o.threatPopKind = 0.35, "gain"
        elseif was == "tank" and o.threat ~= "losing" then o.threatPop, o.threatPopKind = 0.35, "lose" end
    end
end

-- The name at rest: its usual size and white (the threat lives in the glow, not the colour of the text)
local function CalmName(o)
    ns.SetFontScale(o.name, 1, "OUTLINE")
    o.nameGlow:SetAlpha(0)
end
local function TextScale(fs, k, bold)
    ns.SetFontScale(fs, k, bold and "THICKOUTLINE" or "OUTLINE")
end

---------------------------------------------------------------------------
-- Animation: one driver for every plate, running only while something moves
---------------------------------------------------------------------------
local moving = {}
local driver = CreateFrame("Frame")

local function Busy(o)
    return o.spawn or o.threatState or o.threatPop or o.cc or (o.low and PS.Motion())
end

local function Tick(_, dt)
    local now = GetTime()
    local any = false
    for o in pairs(moving) do
        if not o:IsShown() or not Busy(o) then
            moving[o] = nil
            o.glow:SetAlpha(0)
            o.shimmer:Hide()
            o.health.fill:SetAlpha(1)
            o.spawn = nil
            o.name:SetAlpha(ns.Nameplates.NameAlpha(o))
            o.health:SetAlpha(1)
            CalmName(o)
        else
            any = true
            if o.spawn then                                   -- fade and rise in
                o.spawn = o.spawn - dt
                local k = math.max(0, o.spawn / SPAWN)
                o.name:SetAlpha(1 - k)
                o.health:SetAlpha(1 - k)
                if o.spawn <= 0 then
                    o.spawn = nil
                    o.name:SetAlpha(ns.Nameplates.NameAlpha(o))
                    o.health:SetAlpha(1)
                end
            end
            -- threat lives in the coloured glow behind the name and in the shield; the name itself stays white,
            -- at its usual size, bolder while the unit is on you. Taking aggro flares the glow.
            local flare = 0
            if o.threatPop then
                o.threatPop = o.threatPop - dt
                flare = math.max(0, o.threatPop / 0.35)
                if o.threatPop <= 0 then o.threatPop = nil end
            end
            TextScale(o.name, 1, o.threat == "tank")
            local state = o.threatState or (o.threatPop and "calm")
            if state then                                        -- the glow behind the name says whose it is
                local r, g, b, a = ns.ThreatLook(state, now)
                local pad = 26 + 10 * flare
                o.nameGlow:ClearAllPoints()
                o.nameGlow:SetPoint("TOPLEFT", o.name, "TOPLEFT", -pad, 14)
                o.nameGlow:SetPoint("BOTTOMRIGHT", o.name, "BOTTOMRIGHT", pad, -14)
                o.nameGlow:SetVertexColor(r, g, b, 1)
                -- hidden name: no glow either. (Its alpha as we set it: the game may keep the one it reads back to
                -- itself in a battleground, and multiplying that was refused on every frame, an addon error each.)
                local nameAlpha = ns.AlphaOf(o.name) or ns.Nameplates.NameAlpha(o)
                o.nameGlow:SetAlpha(nameAlpha * math.min(1, a + 0.3 * flare))
                o.threatIcon:SetVertexColor(r, g, b, 1)
            else
                o.nameGlow:SetAlpha(0)
            end
            if o.threat then                                     -- around the bar too, while it matters
                local r, g, b = ns.ThreatLook(o.threatState, now)
                o.glow:SetVertexColor(r, g, b, 1)
                o.glow:SetAlpha(0.55 + 0.35 * math.sin(now * (o.threat == "tank" and 5 or 12)))
            elseif o.low and PS.Motion() then
                o.glow:SetVertexColor(C.danger[1], C.danger[2], C.danger[3], 1)
                o.glow:SetAlpha(0.25 + 0.25 * math.sin(now * 6))
            else
                o.glow:SetAlpha(0)
            end
            if o.low and PS.Motion() then
                o.health.fill:SetAlpha(0.75 + 0.25 * math.sin(now * 6))
            else
                o.health.fill:SetAlpha(1)
            end
            if o.cc then                                      -- a glint that runs along the bar
                local w = o.health:GetWidth()
                local x = (now * 90) % (w + 30) - 15
                o.shimmer:ClearAllPoints()
                o.shimmer:SetPoint("CENTER", o.health, "LEFT", x, 0)
                o.shimmer:Show()
            else
                o.shimmer:Hide()
            end
        end
    end
    if not any then driver:SetScript("OnUpdate", nil) end
end
Tick = ns.Protect(Tick)

function PS:Animate(o)
    if Busy(o) then
        moving[o] = true
        driver:SetScript("OnUpdate", Tick)
    end
end

---------------------------------------------------------------------------
-- Quests: is this unit needed for one of yours, and how far along are you ("2/10")? Read from the unit's
-- tooltip, the same lines the game shows under its name there.
---------------------------------------------------------------------------
function PS.QuestProgress(unit)
    if not (C_TooltipInfo and C_TooltipInfo.GetUnit) then return nil end
    local ok, result = pcall(function()
        local data = C_TooltipInfo.GetUnit(unit)
        if not (data and data.lines) then return nil end
        local types = Enum and Enum.TooltipDataLineType
        local objective = types and types.QuestObjective
        local title = types and types.QuestTitle
        local inQuest = false
        for i = 2, #data.lines do
            local line = data.lines[i]
            local text = line.leftText
            if type(text) == "string" and not ns.IsSecret(text) then
                if title and line.type == title then inQuest = true end
                local have, need = text:match("(%d+)%s*/%s*(%d+)")
                local isObjective = (objective and line.type == objective) or (not objective and inQuest)
                if have and isObjective and tonumber(have) < tonumber(need) then
                    return ("%s/%s"):format(have, need)
                end
                local pct = text:match("(%d+)%%")
                if pct and isObjective and tonumber(pct) < 100 then return pct .. "%" end
            end
        end
        return nil
    end)
    return ok and result or nil
end

-- The bar's right end, in a row: the threat shield (and its number), the quest marker, crowd control. Each one
-- moves up when the one before it is not showing; nothing sits on the left, where the level and name are.
function PS:PlaceRight(o)
    local prev = o.health
    local function put(region, shown, gap)
        if not region then return end
        region:ClearAllPoints()
        region:SetPoint("LEFT", prev, "RIGHT", gap, 0)
        if shown then prev = region end
    end
    if o.threatIcon then
        put(o.threatIcon, o.threatIcon:IsShown(), 4)
        if o.threatPct and o.threatPct:IsShown() then prev = o.threatPct end    -- (it hangs on the shield)
    end
    put(o.questIcon, o.questIcon and o.questIcon:IsShown(), 3)
    put(o.ccIcon, o.ccIcon and o.ccIcon:IsShown(), 5)
    if o.wCC then put(o.wCC, true, 5) end                              -- the game shows it when there is one
end

function PS:Quest(o)
    local progress = ns.db.plateQuest and PS.QuestProgress(o.unit) or nil
    o.quest = progress
    if progress then
        o.questIcon:Show()
        o.questText:Hide()                  -- the icon is enough: a count reads as "kill this many", which it may not be
    else
        o.questIcon:Hide()
        o.questText:Hide()
    end
    self:PlaceRight(o)
end

-- Everything this file adds, for one plate. frac: health share (nil when secret).
function PS:Update(o, frac)
    self:Build(o)
    o.nameGlow = o.nameGlow or o:CreateTexture(nil, "BACKGROUND")
    self:HealthText(o, frac)
    self:Auras(o)
    self:Threat(o)
    o.low = o.bars and o.hostile and frac ~= nil and frac > 0 and frac < LOW or false
    if not o.bars then o.threat, o.threatState, o.cc = nil, nil, false end
    if not o.threatState and not o.threatPop and not o.spawn then CalmName(o) end
    self:Animate(o)
end

-- A plate just appeared
function PS:Spawn(o)
    self:Build(o)
    if PS.Motion() then
        o.spawn = SPAWN
        o.name:SetAlpha(0)
        o.health:SetAlpha(0)
        self:Animate(o)
    end
end

function PS:Stop(o)
    moving[o] = nil
    if o.wDebuffs then W.Show(o.wDebuffs); W.Show(o.wBuffs); W.Show(o.wCC) end
    if o.states then
        o.glow:SetAlpha(0)
        o.shimmer:Hide()
        o.health.fill:SetAlpha(1)
        o.name:SetAlpha(1)
        o.health:SetAlpha(1)
        o.spawn = nil
        o.threatWas = nil
        o.threatIcon:Hide()
        o.threatPct:Hide()
    end
end
