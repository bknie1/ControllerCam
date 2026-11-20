-- ControllerCam HUD: signature moments.
--   * Every class's key abilities have a feel of their own on the controller, so they never blur into one:
--     a Judgement splashes (hits hard, then ripples out), a Holy Strike snaps (abrupt, from the trigger, then
--     stops dead), a Windfury Attack knocks three times fast. Crits are felt stronger.
--   * The rare big moment (optional): when it is really special, the number is pinned big in the middle of the
--     screen, golden, in the game's own damage font, with the ability's name under it. It slams in, holds a
--     beat with a soft glow, then rises and fades. Kept rare on purpose: back-to-back crits of your key
--     abilities, a Windfury crit, or a key crit far above the fight's usual, at most twice a fight and never
--     within a few seconds of the last one.
-- What landed is read from the combat log where addons may read it, or else from the hit your target takes
-- right after one of these abilities goes off.

local ADDON, ns = ...
local L, C = ns.L, ns.colors

local M = { active = false, live = nil }
ns.Moments = M

local function Setting(key, label, tip, default)
    ns.RegisterSetting({ key = key, kind = "boolean", default = default, command = key:lower(), section = "Effects",
                         label = label, tip = tip })
end
Setting("abilityRumble", "Rumble: your key abilities", "each class's key abilities have a feel of their own on the controller (a Judgement splashes, a Holy Strike snaps, Windfury knocks three times)", true)
Setting("bigMoments", "Big moments", "rarely, a really special hit is pinned big and golden in the middle of the screen: back-to-back crits of your key abilities, a Windfury crit, or a crit far above the fight's usual (at most twice a fight)", true)

-- Key abilities, by one rank each (every rank shares the name): their feel. Names in English as well, for
-- abilities this client may not have under these numbers.
M.KEY = {
    PALADIN = { { 20271, "Judgement", "splash" }, { 679, "Holy Strike", "strike" }, { 35395, "Crusader Strike", "strike" },
                { 24275, "Hammer of Wrath", "splash" }, { 879, "Exorcism", "splash" }, { 20473, "Holy Shock", "splash" },
                { 20424, "Seal of Command", "strike" } },
    WARRIOR = { { 12294, "Mortal Strike", "strike" }, { 23881, "Bloodthirst", "strike" }, { 5308, "Execute", "splash" },
                { 7384, "Overpower", "strike" } },
    ROGUE = { { 2098, "Eviscerate", "splash" }, { 8676, "Ambush", "strike" }, { 53, "Backstab", "strike" } },
    MAGE = { { 11366, "Pyroblast", "splash" }, { 133, "Fireball", "splash" }, { 116, "Frostbolt", "strike" } },
    HUNTER = { { 19434, "Aimed Shot", "strike" }, { 2643, "Multi-Shot", "splash" } },
    WARLOCK = { { 686, "Shadow Bolt", "splash" }, { 6353, "Soul Fire", "splash" } },
    PRIEST = { { 8092, "Mind Blast", "splash" }, { 585, "Smite", "strike" } },
    SHAMAN = { { 17364, "Stormstrike", "strike" }, { 403, "Lightning Bolt", "splash" }, { 8042, "Earth Shock", "strike" } },
    DRUID = { { 22568, "Ferocious Bite", "splash" }, { 2912, "Starfire", "splash" }, { 5221, "Shred", "strike" } },
}
-- Weapon procs anyone may have
M.PROCS = { { 25504, "Windfury Attack", "windfury" }, { 33750, "Windfury Attack", "windfury" } }

local known                     -- [spell name] = { feel, key = true }
local function Known()
    if known then return known end
    known = {}
    local get = (C_Spell and C_Spell.GetSpellName) or GetSpellInfo
    local _, class = UnitClass("player")
    local list = {}
    for _, a in ipairs(M.KEY[class or ""] or {}) do list[#list + 1] = a end
    for _, a in ipairs(M.PROCS) do list[#list + 1] = a end
    for _, a in ipairs(list) do
        local entry = { feel = a[3], proc = a[3] == "windfury" }
        local ok, n = pcall(get, a[1])
        if ok and type(n) == "string" and not ns.IsSecret(n) then known[n] = entry end
        known[a[2]] = known[a[2]] or entry
    end
    return known
end

local function SpellName(id)
    if ns.IsSecret(id) or type(id) ~= "number" then return nil end
    local get = (C_Spell and C_Spell.GetSpellName) or GetSpellInfo
    local ok, n = pcall(get, id)
    if ok and type(n) == "string" and not ns.IsSecret(n) then return n end
end

-- What a spell is to us: { feel, proc } and its name, or nil
function M.Ability(spellID, name)
    name = name or SpellName(spellID)
    local k = name and Known()[name]
    if k then return k, name end
end

---------------------------------------------------------------------------
-- The rare big moment
---------------------------------------------------------------------------
local fight = { moments = 0, lastMoment = -100, lastKeyCrit = -100, sum = 0, n = 0 }
M.fight = fight
local GAP, PER_FIGHT, BACK_TO_BACK = 8, 2, 5

local frame
local function Build()
    frame = CreateFrame("Frame", nil, UIParent)
    frame:SetSize(10, 10)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 150)
    frame:SetFrameStrata("HIGH")
    frame.glow = frame:CreateTexture(nil, "BACKGROUND")
    frame.glow:SetTexture(ns.media.disc)
    frame.glow:SetBlendMode("ADD")
    frame.glow:SetSize(260, 130)
    frame.glow:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.number = frame:CreateFontString(nil, "OVERLAY")
    frame.number:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.number:SetShadowColor(0, 0, 0, 0.9)
    frame.number:SetShadowOffset(3, -3)
    frame.label = ns.FontString(frame, 12, "CENTER")
    frame.label:SetPoint("TOP", frame.number, "BOTTOM", 0, -2)
    frame:Hide()
    M.frame = frame
end

local SLAM, HOLD, FADE, SIZE = 0.14, 1.2, 0.6, 46
local function Font() return DAMAGE_TEXT_FONT or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF" end

local function Animate(_, dt)
    local m = M.live
    if not m then frame:SetScript("OnUpdate", nil); frame:Hide(); return end
    m.t = m.t + dt
    local t = m.t
    local scale
    if t < SLAM then scale = 2.6 - 1.4 * (t / SLAM)                                  -- slams in from big
    elseif t < SLAM + HOLD then scale = 1.2 + 0.05 * math.sin((t - SLAM) * 6)      -- holds, breathing
    else scale = 1.2 end
    local size = math.floor(SIZE * scale + 0.5)
    if size ~= m.drawn then m.drawn = size; frame.number:SetFont(Font(), size, "THICKOUTLINE") end
    local out = math.max(0, t - SLAM - HOLD)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 150 + 40 * out)
    local a = 1 - out / FADE
    frame:SetAlpha(math.max(0, a))
    frame.glow:SetAlpha(math.max(0, a) * (0.35 + 0.15 * math.sin(t * 5)))
    if out >= FADE then M.live = nil; frame:SetScript("OnUpdate", nil); frame:Hide() end
end
Animate = ns.Protect(Animate)

-- Pin it: amount (may be secret), the ability's name
function M:Show(amount, name, school)
    if not frame then Build() end
    local p = ns.Impact and ns.Impact.PROFILES[school or ""]
    local c = (p and school ~= "physical") and p.color or { 1, 0.82, 0.3 }
    frame.number:SetFont(Font(), SIZE * 2.6, "THICKOUTLINE")
    frame.number:SetTextColor(1, 0.86, 0.35)
    local ok = pcall(frame.number.SetFormattedText, frame.number, "%d", amount)
    if not ok then frame.number:SetText("!") end
    frame.label:SetText(name or "")
    frame.glow:SetVertexColor(c[1], c[2], c[3], 1)
    frame:SetAlpha(1)
    frame:Show()
    self.live = { t = 0 }
    self.shown = (self.shown or 0) + 1
    frame:SetScript("OnUpdate", Animate)
    if ns.Impact and ns.db.impactFx then                       -- a little light thrown off it
        local f = ns.UnitFrames and ns.UnitFrames.frames.target
        if f and f.on then ns.Impact:Burst(f.health, ns.Impact.PROFILES.holy, 1.4) end
    end
end

-- Is this one of the rare ones? Returns true when it is shown.
function M:Consider(amount, crit, ability, name, school)
    if not crit then return false end
    local now = GetTime()
    local plain = (not ns.IsSecret(amount)) and type(amount) == "number" and amount or nil
    local special = false
    if ability.proc then
        special = true                                             -- a Windfury crit
    elseif now - fight.lastKeyCrit <= BACK_TO_BACK then
        special = true                                             -- back to back
    elseif plain and fight.n >= 3 and plain >= 1.6 * (fight.sum / fight.n) then
        special = true                                             -- far above the fight's usual
    end
    if not ability.proc then fight.lastKeyCrit = now end
    if not (special and ns.db.bigMoments) then return false end
    if fight.moments >= PER_FIGHT or now - fight.lastMoment < GAP then return false end
    fight.moments, fight.lastMoment = fight.moments + 1, now
    self:Show(amount, name, school)
    if ns.Rumble then ns.Rumble.busyUntil = nil; ns.Rumble:Play("moment") end
    return true
end

---------------------------------------------------------------------------
-- A key ability landed
---------------------------------------------------------------------------
function M:Landed(spellID, name, amount, crit, school)
    local ability
    ability, name = M.Ability(spellID, name)
    if not ability then return false end
    local plain = (not ns.IsSecret(amount)) and type(amount) == "number" and amount or nil
    if plain and not ability.proc then fight.sum, fight.n = fight.sum + plain, fight.n + 1 end
    if self:Consider(amount, crit, ability, name, school) then return true end
    if ns.db.abilityRumble and ns.Rumble then ns.Rumble:Play(ability.feel, crit and 1.3 or 1) end
    return true
end

-- Without the combat log: the ability you just used, matched to the next hit your target takes
local pending
local events = CreateFrame("Frame")
events:SetScript("OnEvent", ns.Protect(function(_, event, unit, a2, a3, a4, a5)
    if event == "PLAYER_REGEN_DISABLED" then
        fight.moments, fight.sum, fight.n, fight.lastKeyCrit = 0, 0, 0, -100
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if unit == "player" and M.Ability(a3) then pending = { id = a3, at = GetTime() } end
    elseif event == "UNIT_COMBAT" then
        if unit ~= "target" or M.usesLog then return end
        if ns.IsSecret(a2) or a2 ~= "WOUND" then return end
        if pending and GetTime() - pending.at < 0.8 then
            local crit = not ns.IsSecret(a3) and a3 == "CRITICAL"
            local id = pending.id
            pending = nil
            M:Landed(id, nil, a4, crit, ns.Impact and ns.Impact.School(a5))
        end
    end
end))

-- The combat log (Impact.lua hands us your spell hits when it reads the log)
function M.FromLog(spellID, name, amount, crit, schoolMask)
    if not M.active then return end
    M.usesLog = true
    M:Landed(spellID, name, amount, crit, ns.Impact and ns.Impact.School(schoolMask))
end

-- Windfury and the like: the log says an extra attack is coming; the swing that follows carries it
local extra
function M.ExtraAttack(spellID, name)
    if not M.active then return end
    local ability = M.Ability(spellID, name)
    if ability then extra = { id = spellID, name = name, at = GetTime(), left = 1 } end
end
function M.Swing(amount, crit)
    if not (M.active and extra) then return end
    if GetTime() - extra.at > 0.5 then extra = nil; return end
    M.usesLog = true
    M:Landed(extra.id, extra.name, amount, crit, "physical")
    extra.left = extra.left - 1
    if extra.left <= 0 then extra = nil end
end

function M:Apply(run)
    local want = run and (ns.db.abilityRumble or ns.db.bigMoments) and true or false
    if want == self.active then return end
    self.active = want
    if want then
        for _, e in ipairs({ "PLAYER_REGEN_DISABLED", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_COMBAT" }) do
            pcall(events.RegisterEvent, events, e)
        end
    else
        events:UnregisterAllEvents()
        self.live = nil
        if frame then frame:Hide() end
    end
end

ns.RegisterCommand("momenttest", function()
    M:Show(1234, L["Judgement"], "holy")
    if ns.Rumble then ns.Rumble.busyUntil = nil; ns.Rumble:Play("moment") end
end, "/cchud momenttest", "show what a big moment looks and feels like")

ns.RegisterModule("moments", M)
