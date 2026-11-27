-- ControllerCam HUD: what you put on your target, and your combo points.
--   * A row of your own effects under the target bar (your debuffs on an enemy, your buffs on a friend).
--   * Combo points as a row of pips above the target's name.

local ADDON, ns = ...
local L, C, U = ns.L, ns.colors, ns.Unit

local A = { active = false, icons = {}, pips = {} }
ns.Auras = A

ns.RegisterSetting({
    key = "auras", kind = "boolean", default = true, command = "auras", section = "Frames",
    label = "Your effects on the target", tip = "a row under the target bar: your debuffs on an enemy, a friend's buffs (all of them, whoever cast them)",
})
ns.RegisterSetting({
    key = "targetBuffs", kind = "boolean", default = true, command = "targetbuffs", section = "Frames",
    label = "Enemy buffs on the target", tip = "an enemy target's buffs, on the right under its bar: the ones that matter, or all of them when Only the effects that matter is off",
})
ns.RegisterSetting({
    key = "smartAuras", kind = "boolean", default = true, command = "smartauras", section = "Frames",
    label = "Only the effects that matter",
    tip = "on the target and nameplates: an enemy's buffs only when the game marks them important, it is enraged, or you can dispel or steal them; on a friend, the debuffs you can dispel and the dangerous ones. Off: every buff",
})
ns.RegisterSetting({
    key = "friendDebuffs", kind = "boolean", default = true, command = "frienddebuffs", section = "Frames",
    label = "Debuffs on a friendly target",
    tip = "on the right under a friend's bar: the debuffs you can dispel (edged in their kind's colour), boss mechanics and crowd control",
})
ns.RegisterSetting({
    key = "combo", kind = "boolean", default = true, command = "combo", section = "Frames",
    label = "Combo points", tip = "combo points as pips above the target's name",
})

local MAX_ICONS, ICON, GAP = 8, 22, 10        -- room between icons for each one's time ("12m") under it
local MAX_BUFFS = 4
local MAX_PIPS = 5

-- One effect: { icon, applications, duration, expirationTime, auraInstanceID } or nil
-- Reading effects. This client lets addons take a unit's whole list of effects (C_UnitAuras.GetUnitAuras) and
-- lets the game itself pick the ones a filter means (GetUnitAuraInstanceIDs: "yours", "crowd control"...),
-- while reading them one by one is refused when their details are secret. So: the list, and the game's filter.
local function Modern()
    return C_UnitAuras and C_UnitAuras.GetUnitAuras and C_UnitAuras.GetUnitAuraInstanceIDs and true or false
end
U.ModernAuras = Modern

-- Every effect of a kind on a unit ("HARMFUL" / "HELPFUL"), by auraInstanceID, or nil
local function AllByID(unit, kind)
    local ok, all = pcall(C_UnitAuras.GetUnitAuras, unit, kind)
    if not ok or type(all) ~= "table" then return nil end
    local byID, hidden = {}, false
    for _, a in ipairs(all) do
        local id = a.auraInstanceID
        if id ~= nil and not ns.IsSecret(id) then byID[id] = a else hidden = true end
    end
    return byID, hidden
end

-- The effects the game puts under a filter (it may hold "PLAYER", "CROWD_CONTROL"...), in its order, at most max
function U.Filtered(unit, kind, filter, max)
    local fake = ns.UnitFrames.fake and ns.UnitFrames.fake[unit]
    if fake then                  -- the demo: its debuffs, its buffs, its crowd control
        local from = fake.auras
        if filter and filter:find("CROWD_CONTROL") and not filter:find("!CROWD_CONTROL") then from = fake.cc
        elseif kind == "HELPFUL" and fake.attackable then from = fake.buffs end
        local list = {}
        for i, a in ipairs(from or {}) do if i <= (max or 40) then list[#list + 1] = a end end
        return list
    end
    if ns.UnitFrames.fake or not Modern() then return nil end
    local byID, missed = AllByID(unit, kind)
    local ok, ids = pcall(C_UnitAuras.GetUnitAuraInstanceIDs, unit, filter)
    if not byID or not ok or type(ids) ~= "table" then return nil end
    local list = {}
    for _, id in ipairs(ids) do
        local a = nil
        if not ns.IsSecret(id) then a = byID[id] end
        if a then
            list[#list + 1] = a
            if max and #list >= max then break end
        else
            missed = true
        end
    end
    return list, missed                -- missed: an effect there was no telling apart, so the list may be short
end

-- One effect by its place in the list: for clients without the calls above (never when they exist)
function U.Aura(unit, index, filter)
    local fake = ns.UnitFrames.fake and ns.UnitFrames.fake[unit]
    if fake then return fake.auras and fake.auras[index] end
    if ns.UnitFrames.fake then return nil end
    local get = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
    if not get then return nil end
    local ok, a = pcall(get, unit, index, filter)
    if ok then return a end
end

-- Your own effects on a unit, at most max. Asks the game for "yours" first; when that gives nothing (a client
-- that does not know the filter), every effect is read and yours are picked out by who cast them.
-- Is this effect yours? true, false, or nil when the game does not say (or keeps it secret)
-- Spells you cast lately (by id and by name), for effects the game does not say are yours
local castIds, castNames = {}, {}
local RECENT = 120            -- seconds an effect of yours can still be matched to your cast
local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then
        local ok, n = pcall(C_Spell.GetSpellName, id)
        if ok and type(n) == "string" and not ns.IsSecret(n) then return n end
    end
    if GetSpellInfo then
        local ok, n = pcall(GetSpellInfo, id)
        if ok and type(n) == "string" and not ns.IsSecret(n) then return n end
    end
end
function U.NoteCast(spellID)
    if ns.IsSecret(spellID) or type(spellID) ~= "number" then return end
    local now = GetTime()
    castIds[spellID] = now
    local name = SpellName(spellID)
    if name then castNames[name] = now end
end

-- Did you cast this effect lately? Its spell, or a spell whose name starts its name (Judgement leaves
-- "Judgement of the Crusader")
local function CastByYou(a)
    local now = GetTime()
    local id, name = a.spellId, a.name
    if not ns.IsSecret(id) and castIds[id] and now - castIds[id] < RECENT then return true end
    if type(name) ~= "string" or ns.IsSecret(name) then return false end
    for cast, at in pairs(castNames) do
        if now - at < RECENT and (name == cast or name:sub(1, #cast + 1) == cast .. " ") then return true end
    end
    return false
end

local function Mine(a)
    local mine, source = a.isFromPlayerOrPlayerPet, a.sourceUnit
    if ns.IsSecret(mine) then mine = nil end
    if ns.IsSecret(source) then source = nil end
    if mine == true or source == "player" or source == "pet" or source == "vehicle" then return true end
    if mine == false or (type(source) == "string" and source ~= "") then return false end
    if CastByYou(a) then return true end
    return nil
end
U.Mine = Mine

-- The effects a nameplate shows, picked by the game: debuffs it marks for nameplates (only yours, when
-- wanted), the unit's buffs it marks for nameplates, and crowd control. Each list, or nil when this client
-- cannot pick them (then the older reading is used).
function U.PlateAuras(unit, max, onlyMine)
    local debuffs = U.Filtered(unit, "HARMFUL", "HARMFUL|INCLUDE_NAME_PLATE_ONLY" .. (onlyMine and "|PLAYER" or ""), max)
    if debuffs and #debuffs == 0 then
        debuffs = U.Filtered(unit, "HARMFUL", onlyMine and "HARMFUL|PLAYER" or "HARMFUL", max)   -- the game marked none
    end
    local buffs = U.Filtered(unit, "HELPFUL", "HELPFUL|INCLUDE_NAME_PLATE_ONLY", 3)
    local cc = U.Filtered(unit, "HARMFUL", "HARMFUL|CROWD_CONTROL", 1)
    return debuffs, buffs, cc
end

function U.MyAuras(unit, harmful, max)
    local kind = harmful and "HARMFUL" or "HELPFUL"
    -- the game says which are yours
    local mine = U.Filtered(unit, kind, kind .. "|PLAYER", max)
    if mine then return mine end
    local list = {}
    -- what the game calls yours, checked again (a client may ignore the filter and give everyone's)
    for i = 1, 40 do
        local a = U.Aura(unit, i, kind .. "|PLAYER")
        if not a then break end
        if Mine(a) ~= false then
            list[#list + 1] = a
            if #list >= max then return list end
        end
    end
    if #list > 0 then return list end
    -- or every effect, keeping the ones that are certainly yours
    for i = 1, 40 do
        local a = U.Aura(unit, i, kind)
        if not a then break end
        if Mine(a) then
            list[#list + 1] = a
            if #list >= max then break end
        end
    end
    return list
end

---------------------------------------------------------------------------
-- Countdowns: seconds left on an effect, drawn by us when the game gives the time; otherwise the game's own
-- cooldown widget shows its numbers.
---------------------------------------------------------------------------
local timed = {}
local ticker = CreateFrame("Frame")
local function TickTimers()
    local now, any = GetTime(), false
    for b in pairs(timed) do
        local left = b.expires and (b.expires - now)
        if not b:IsShown() or not left or left <= 0 then
            timed[b] = nil
            b.time:SetText("")
        else
            any = true
            if left >= 60 then
                b.time:SetText(("%dm"):format(math.ceil(left / 60)))
                b.time:SetTextColor(unpack(C.text))
            elseif left >= 5 then
                b.time:SetText(("%d"):format(math.ceil(left)))
                b.time:SetTextColor(unpack(C.text))
            elseif left >= 3 then                                   -- running out: red
                b.time:SetText(("%d"):format(math.ceil(left)))
                b.time:SetTextColor(unpack(C.danger))
            else
                b.time:SetText(("%.1f"):format(left))
                b.time:SetTextColor(unpack(C.danger))
            end
        end
    end
    if not any then ticker:SetScript("OnUpdate", nil) end
end
local since = 0
local TickOnUpdate = ns.Protect(function(_, dt)
    since = since + dt
    if since < 0.1 then return end
    since = 0
    TickTimers()
end)

-- An icon button for an effect: b.icon, b.count, b.cooldown, b.time
-- The game's countdown numbers on a sweep, in our font and small enough to stay on their own icon
local countdownFont
local function CountdownFont(size)
    if not CreateFont then return nil end
    countdownFont = countdownFont or {}
    local name = "ControllerCamHUDCountdown" .. size
    if not countdownFont[size] then
        local f = CreateFont(name)
        f:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size, "OUTLINE")
        countdownFont[size] = f
    end
    return name
end
ns.CountdownFont = CountdownFont

-- below: the time goes under the icon (a row where icons sit side by side with nothing under them), instead of
-- on its top edge
function ns.AuraButton(parent, size, textSize, below)
    local b = CreateFrame("Frame", nil, parent)
    b:SetSize(size, size)
    b.back = b:CreateTexture(nil, "BACKGROUND")
    b.back:SetPoint("TOPLEFT", b, "TOPLEFT", -1, 1)
    b.back:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 1, -1)
    b.back:SetColorTexture(0.02, 0.03, 0.06, 0.9)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints(b)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local ok, cd = pcall(CreateFrame, "Cooldown", nil, b, "CooldownFrameTemplate")
    if ok and cd then
        cd:SetAllPoints(b)
        if cd.SetReverse then cd:SetReverse(true) end
        if cd.SetDrawEdge then cd:SetDrawEdge(false) end
        local font = CountdownFont(math.max(8, math.floor(size * 0.42 + 0.5)))
        if font and cd.SetCountdownFont then pcall(cd.SetCountdownFont, cd, font) end
        b.cooldown = cd
    end
    local top = CreateFrame("Frame", nil, b)                -- text above the sweep
    top:SetAllPoints(b)
    top:SetFrameLevel((cd and cd:GetFrameLevel() or b:GetFrameLevel()) + 1)
    b.count = ns.FontString(top, textSize - 2, "RIGHT")
    b.count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 1, -1)
    b.time = ns.FontString(top, textSize, "CENTER")
    if below then
        b.time:SetPoint("TOP", b, "BOTTOM", 0, -1)
    else
        b.time:SetPoint("CENTER", b, "TOP", 0, 0)
    end
    b:Hide()
    return b
end

-- Show one effect on a button
function ns.ShowAura(b, unit, aura)
    b.icon:SetTexture(aura.icon)
    local n = aura.applications
    if not ns.IsSecret(n) and type(n) == "number" and n > 1 then b.count:SetText(n) else b.count:SetText("") end
    local dur, exp = aura.duration, aura.expirationTime
    b.expires = nil
    if not ns.IsSecret(dur) and not ns.IsSecret(exp) and type(dur) == "number" and dur > 0 then
        b.expires = exp
        if b.cooldown then
            b.cooldown:SetCooldown(exp - dur, dur)
            if b.cooldown.SetHideCountdownNumbers then b.cooldown:SetHideCountdownNumbers(true) end
            b.cooldown:Show()
        end
        timed[b] = true
        ticker:SetScript("OnUpdate", TickOnUpdate)
    elseif b.cooldown and C_UnitAuras and C_UnitAuras.GetAuraDuration and b.cooldown.SetCooldownFromDurationObject
        and aura.auraInstanceID then
        -- the game keeps the time to itself: its own widget draws the sweep and the numbers
        local ok = pcall(function()
            b.cooldown:SetCooldownFromDurationObject(C_UnitAuras.GetAuraDuration(unit, aura.auraInstanceID))
            if b.cooldown.SetHideCountdownNumbers then b.cooldown:SetHideCountdownNumbers(false) end
        end)
        if ok then b.cooldown:Show() else b.cooldown:Hide() end
        b.time:SetText("")
    else
        if b.cooldown then b.cooldown:Hide() end
        b.time:SetText("")
    end
    b:Show()
    TickTimers()
end

function U.ComboPoints()
    local fake = ns.UnitFrames.fake
    if fake then return fake.combo or 0 end
    if not GetComboPoints then return 0 end
    local n = GetComboPoints("player", "target")
    if ns.IsSecret(n) or type(n) ~= "number" then return 0 end
    return n
end

local function Build(target)
    local visual = target.visual
    A.row = CreateFrame("Frame", nil, visual)
    A.row:SetSize(MAX_ICONS * (ICON + GAP), ICON)
    A.row:SetPoint("TOPLEFT", target.health, "BOTTOMLEFT", 8, -26)
    for i = 1, MAX_ICONS do
        local b = ns.AuraButton(A.row, ICON, 10, true)
        b:SetPoint("LEFT", A.row, "LEFT", (i - 1) * (ICON + GAP), 0)
        A.icons[i] = b
    end
    A.ccIcon = ns.AuraButton(visual, ICON + 6, 12)            -- crowd control on it, at the end of the bar
    A.ccIcon:SetPoint("LEFT", target.health, "RIGHT", 8, 0)
    A.ccIcon.back:SetColorTexture(0.35, 0.6, 1, 0.95)
    A.ccIcon:Hide()
    A.buffIcons = {}
    for i = 1, MAX_BUFFS do
        local b = ns.AuraButton(visual, ICON - 2, 10, true)
        b:SetPoint("TOPRIGHT", target.health, "BOTTOMRIGHT", -8 - (i - 1) * (ICON + GAP - 2), -26)
        b.back:SetColorTexture(0.25, 0.05, 0.05, 0.95)          -- an enemy's buff: a red edge
        A.buffIcons[i] = b
    end
    -- the game's own rows, where this client has them (AuraWidgets.lua): your effects, the enemy's buffs, and
    -- crowd control on it from anyone, large, at the end of the bar
    local W = ns.AuraWidgets
    -- (rows under the bar start at their top: anything more goes below, never over the bar)
    -- (a little further apart than our own icons: "60m" under each one needs the room)
    A.wMine = W.Row(A.row, { filter = W.ENEMY_DEBUFFS, max = MAX_ICONS, size = ICON, text = 10,
                             spacing = GAP + 8, below = true, down = true })
    if A.wMine then
        A.wMine:SetPoint(A.wMine.point, A.row, "TOPLEFT", 0, 0)
        A.wBuffs = W.Row(visual, { filter = W.ENEMY_BUFFS, max = MAX_BUFFS, size = ICON - 2, text = 10,
                                   edge = { 0.25, 0.05, 0.05, 0.95 }, grow = "LEFT", spacing = GAP + 6,
                                   below = true, typed = true, down = true })
        A.wBuffs:SetPoint(A.wBuffs.point, target.health, "BOTTOMRIGHT", -8, -26)
        -- a friend's debuffs worth acting on, in the same place
        A.wHelp = W.Row(visual, { filter = W.FRIEND_DEBUFFS, max = MAX_BUFFS, size = ICON, text = 10,
                                  grow = "LEFT", spacing = GAP + 8, below = true, typed = true, down = true })
        A.wHelp:SetPoint(A.wHelp.point, target.health, "BOTTOMRIGHT", -8, -26)
        A.wCC = ns.AuraWidgets.Row(visual, { filter = "HARMFUL|CROWD_CONTROL", max = 1, size = ICON + 6, text = 12,
                                            edge = { 0.35, 0.6, 1, 0.95 }, down = true })
        A.wCC:SetPoint(A.wCC.point, target.health, "RIGHT", 8, (ICON + 6) / 2)
    end
    A.pipRow = CreateFrame("Frame", nil, visual)
    A.pipRow:SetSize(MAX_PIPS * 14, 10)
    A.pipRow:SetPoint("BOTTOM", target.name, "TOP", 0, 4)
    for i = 1, MAX_PIPS do
        local pip = A.pipRow:CreateTexture(nil, "OVERLAY")
        pip:SetTexture(ns.media.mark)
        pip:SetSize(11, 11)
        pip:SetPoint("LEFT", A.pipRow, "LEFT", (i - 1) * 14, 0)
        A.pips[i] = pip
    end
    A.pipRow:Hide()
end

-- The game draws them (a real target, on a client that can): our rows stay hidden
local function GameRows(self, unit)
    for i = 1, MAX_ICONS do self.icons[i]:Hide() end
    for i = 1, MAX_BUFFS do self.buffIcons[i]:Hide() end
    local fresh = self.fresh
    self.fresh = nil
    local exists = self.aurasOn and U.Exists(unit)
    local _, _, _, attackable = U.Standing(unit)
    local W = ns.AuraWidgets
    local smart = ns.db.smartAuras
    -- an enemy: your debuffs on it. A friend (a party member you tab to): the buffs they have, whoever cast them
    W.Show(self.wMine, unit, attackable and (smart and W.ENEMY_DEBUFFS or "HARMFUL|!CROWD_CONTROL|PLAYER")
                             or "HELPFUL", exists, fresh)
    W.Show(self.wBuffs, unit, smart and W.ENEMY_BUFFS or "HELPFUL|!PLAYER", exists and ns.db.targetBuffs and attackable, fresh)
    W.Show(self.wHelp, unit, smart and W.FRIEND_DEBUFFS or "HARMFUL",
           exists and ns.db.friendDebuffs and not attackable, fresh)
    W.Show(self.wCC, unit, nil, exists and attackable, fresh)
    self.shownAuras, self.shownBuffs = 0, 0
end

local function DemoCC(self, unit)
    local b = self.ccIcon
    local cc = (self.aurasOn and ns.UnitFrames.fake and U.Filtered(unit, "HARMFUL", "HARMFUL|CROWD_CONTROL", 1)) or {}
    if b and cc[1] then ns.ShowAura(b, unit, cc[1]) elseif b then b:Hide() end
end

function A:UpdateAuras()
    if not self.row then return end
    local unit = "target"
    local W = ns.AuraWidgets
    if self.wMine and not ns.UnitFrames.fake then GameRows(self, unit); if self.ccIcon then self.ccIcon:Hide() end; return end
    if self.wMine then W.Show(self.wMine); W.Show(self.wBuffs); W.Show(self.wHelp); W.Show(self.wCC) end
    DemoCC(self, unit)
    local shown = 0
    if self.aurasOn and U.Exists(unit) then
        local _, _, _, attackable = U.Standing(unit)
        local list = attackable and U.MyAuras(unit, true, MAX_ICONS)
            or U.Filtered(unit, "HELPFUL", "HELPFUL", MAX_ICONS) or U.MyAuras(unit, false, MAX_ICONS)
        for i, aura in ipairs(list) do
            shown = i
            ns.ShowAura(self.icons[i], unit, aura)
        end
    end
    for i = shown + 1, MAX_ICONS do self.icons[i]:Hide() end
    self.shownAuras = shown
    -- an enemy's own buffs (the ones the game marks as worth seeing), on the right
    local buffs = 0
    local _, _, _, attackable = U.Standing(unit)
    if self.aurasOn and ns.db.targetBuffs and attackable and U.Exists(unit) then
        for i, aura in ipairs(U.Filtered(unit, "HELPFUL", "HELPFUL|INCLUDE_NAME_PLATE_ONLY", MAX_BUFFS)
            or U.Filtered(unit, "HELPFUL", "HELPFUL", MAX_BUFFS) or {}) do
            buffs = i
            ns.ShowAura(self.buffIcons[i], unit, aura)
        end
    end
    for i = buffs + 1, MAX_BUFFS do self.buffIcons[i]:Hide() end
    self.shownBuffs = buffs
end

function A:UpdateCombo()
    if not self.pipRow then return end
    local n = (self.comboOn and U.Exists("target")) and U.ComboPoints() or 0
    if n <= 0 then self.pipRow:Hide(); self.points = 0; return end
    for i = 1, MAX_PIPS do
        local lit = i <= n
        local color = (n >= MAX_PIPS) and C.danger or C.caution
        if lit then
            self.pips[i]:SetVertexColor(color[1], color[2], color[3], 1)
        else
            self.pips[i]:SetVertexColor(1, 1, 1, 0.18)
        end
    end
    self.points = n
    self.pipRow:Show()
end

function A:Refresh()
    self:UpdateAuras()
    self:UpdateCombo()
end

local events = CreateFrame("Frame")
local OnEvent = ns.Protect(function(_, event, unit)
    if ns.UnitFrames.fake then return end
    if event == "UNIT_AURA" then
        if unit == "target" then A:UpdateAuras() end
    elseif event == "PLAYER_TARGET_CHANGED" then
        A.fresh = true                                   -- "target" is another unit now: the game's rows look again
        A:Refresh()
    elseif event == "UNIT_POWER_UPDATE" or event == "UNIT_POWER_FREQUENT" then
        if unit == "player" then A:UpdateCombo() end
    else
        A:Refresh()
    end
end)

-- your casts are noted all the time (cheap), so effects can be matched to them later
local casts = CreateFrame("Frame")
pcall(casts.RegisterEvent, casts, "UNIT_SPELLCAST_SUCCEEDED")
casts:SetScript("OnEvent", ns.Protect(function(_, _, unit, _, spellID)
    if unit == "player" or unit == "pet" then
        U.NoteCast(spellID)
        if unit == "player" and ns.Impact then ns.Impact.NoteCast(spellID) end
    end
end))

-- /cchud aurareport: what the game says about your target's effects, kept in the saved settings for a look later
function A.Report(unit)
    local rows = {}
    local function show(v)
        if ns.IsSecret(v) then return "(secret)" end
        return tostring(v)
    end
    rows[#rows + 1] = "reading: " .. (Modern() and "the list and the game's filter" or "one by one")
    for _, f in ipairs({ { "HARMFUL", "HARMFUL|PLAYER" }, { "HARMFUL", "HARMFUL" }, { "HARMFUL", "HARMFUL|CROWD_CONTROL" },
                         { "HELPFUL", "HELPFUL" }, { "HELPFUL", "HELPFUL|IMPORTANT" }, { "HARMFUL", "HARMFUL|IMPORTANT" },
                         { "HARMFUL", "HARMFUL|RAID" } }) do
        local list = U.Filtered(unit, f[1], f[2], 20)
        if not list then
            list = {}
            for i = 1, 20 do
                local a = U.Aura(unit, i, f[2])
                if not a then break end
                list[#list + 1] = a
            end
        end
        for i, a in ipairs(list) do
            rows[#rows + 1] = ("%s #%d: %s id=%s source=%s fromPlayer=%s"):format(f[2], i, show(a.name),
                show(a.spellId), show(a.sourceUnit), show(a.isFromPlayerOrPlayerPet))
        end
    end
    return rows
end

ns.RegisterCommand("aurareport", function()
    local unit = UnitExists("target") and "target" or nil
    if not unit then ns.Say(L["Target something first."]); return end
    local rows = A.Report(unit)
    ns.db.auraReport = rows
    for _, r in ipairs(rows) do print("  " .. r) end
    ns.Say(L["%d effects listed and saved. Type /reload so the game writes them to disk."]:format(#rows))
end, "/cchud aurareport", "list what the game says about your target's effects (for troubleshooting)")

function A:Apply(run)
    local db = ns.db
    local target = ns.UnitFrames.frames.target
    local base = run and target and target.on and true or false
    self.aurasOn, self.comboOn = base and db.auras, base and db.combo
    local want = (self.aurasOn or self.comboOn) and true or false
    if want and not self.row then Build(target) end
    if want ~= self.active then
        self.active = want
        if want then
            for _, e in ipairs({ "UNIT_AURA", "UNIT_POWER_UPDATE", "UNIT_POWER_FREQUENT", "PLAYER_TARGET_CHANGED",
                                 "PLAYER_ENTERING_WORLD" }) do
                pcall(events.RegisterEvent, events, e)
            end
            events:SetScript("OnEvent", OnEvent)
        else
            events:UnregisterAllEvents()
            events:SetScript("OnEvent", nil)
        end
    end
    self:Refresh()
end

ns.RegisterModule("auras", A)
