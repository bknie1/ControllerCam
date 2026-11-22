-- ControllerCam HUD: signature moments.
--   * Every class's key abilities have a feel of their own on the controller, so they never blur into one:
--     a Judgement splashes (hits hard, then ripples out), a Holy Strike snaps (abrupt, from the trigger, then
--     stops dead), a Windfury Attack knocks three times fast. Crits are felt stronger.
--   * The burst (optional): crits landing back to back, each within a second of the last (a
--     double swing, Windfury, Judgement and Holy Strike pressed together), are pinned big in the middle of the
--     screen, golden, in the game's own damage font: what they did together, big, with each crit's ability in a
--     small column at its left ("+ Judgement", "+ Holy Strike"), the total about four times their size. It
--     comes half a second after the burst's last crit, so the numbers fly
--     first and the total lands once the burst is over: it slams in, holds with a soft glow (a second and a bit,
--     and a second more for each crit; a crit that joins while it shows holds it longer again), then rises and
--     fades. Any crit of yours counts (your key
--     abilities, any other spell the combat log names, your weapon's swings); a hit that does not crit leaves
--     the burst alone, only the half second ends it. A crit on its own is never pinned. Kept rare: at most
--     twice a fight, and never within a few seconds of the last one.
--     Your heals the same way: crit heals landing together (any heal of yours, on anyone) are pinned with what
--     they healed together, "+2450", in the green of a heal.
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
Setting("bigMoments", "Big moments", "a burst is pinned big and golden in the middle of the screen: crits landing back to back, each within a second of the last (a double swing, Judgement and Holy Strike together), with what they did together (at most twice a fight)", true)

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
local fight = { moments = 0, lastMoment = -100 }
M.fight = fight
local GAP, PER_FIGHT = 8, 2
M.BURST = 1.0                   -- crits this close to the one before are one burst
M.seen = { plain = 0, secret = 0, none = 0 }   -- the amounts crits came with (for the debug report)
M.LIST_MAX = 4                  -- hits the game keeps secret are shown side by side, at most this many
M.DELAY = 0.5                   -- the total comes this long after the burst's last crit (the numbers fly first)

-- What a burst shows: its total, or (when the game keeps some amounts to itself: those cannot be added up)
-- each of its hits side by side, "450 + 512", the game writing out the ones it keeps secret
function M.Number(run, amount)
    if run.total then return run.total end
    if run.amounts and #run.amounts > 0 then return { list = run.amounts } end
    return amount
end

-- The run of crits: how many, what they did together (nil when the game keeps an amount to itself: those
-- cannot be added up), and whose they were
-- (key: "chain" for hits, "healChain" for heals)
local function Join(amount, name, now, key)
    key = key or "chain"
    local c = fight[key]
    if not c or now - c.at > M.BURST then
        c = { n = 0, total = 0, names = {}, order = {} }
        fight[key] = c
    end
    c.n, c.at = c.n + 1, now
    local plain = (not ns.IsSecret(amount)) and type(amount) == "number" and amount or nil
    if plain and c.total then c.total = c.total + plain else c.total = nil end
    c.amounts = c.amounts or {}
    if amount ~= nil then c.amounts[#c.amounts + 1] = amount end     -- (each one, kept even when secret)
    local seen = M.seen
    if ns.IsSecret(amount) then seen.secret = seen.secret + 1
    elseif plain then seen.plain = seen.plain + 1
    else seen.none = seen.none + 1 end
    M.lastRun = c
    c.seq = c.seq or {}
    if type(name) == "string" and not ns.IsSecret(name) and name ~= "" then
        if not c.names[name] then c.order[#c.order + 1] = name end
        c.names[name] = (c.names[name] or 0) + 1
        c.seq[#c.seq + 1] = name
    else
        c.seq[#c.seq + 1] = type(MELEE) == "string" and MELEE or "?"   -- (a swing: the game's own word)
    end
    return c
end

-- "Judgement + Holy Strike", "Judgement x2 + Holy Strike"
local function RunLabel(c)
    local parts = {}
    for _, name in ipairs(c.order) do
        parts[#parts + 1] = c.names[name] > 1 and ("%s x%d"):format(name, c.names[name]) or name
    end
    return table.concat(parts, " + ")
end
M.RunLabel = RunLabel

-- The column at the total's left: one line for each crit, in the order they landed (the last few)
M.LINES = 5
local function RunLines(c)
    local seq, out = c.seq or {}, {}
    local from = math.max(1, #seq - M.LINES + 1)
    if from > 1 then out[1] = "..." end
    for i = from, #seq do out[#out + 1] = "+ " .. seq[i] end
    return table.concat(out, "\n")
end
M.RunLines = RunLines

local frame
M.LINE_SIZE = 14               -- the abilities' lines; the total, held, is about four times as tall
M.SHADE = 0.55                 -- how dark the shade behind it

-- The shade as tall as what it is behind (the total, or the column when that is taller)
local function FitShade(size)
    local h = size or 0
    local ok, lines = pcall(frame.label.GetStringHeight, frame.label)
    if ok and type(lines) == "number" and lines > h then h = lines end
    frame.shade:SetHeight(h + 26)
end
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
    frame.label = ns.FontString(frame, M.LINE_SIZE, "RIGHT")             -- the abilities, small, at its left
    frame.label:SetPoint("RIGHT", frame.number, "LEFT", -14, 0)
    if frame.label.SetSpacing then frame.label:SetSpacing(2) end
    frame.label:SetTextColor(1, 0.9, 0.62)
    -- a soft dark shade behind all of it, like the one under the target's health text: easier to read
    frame.shade = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    frame.shade:SetTexture(ns.media.soft)
    frame.shade:SetVertexColor(0, 0, 0, M.SHADE)
    frame.shade:SetPoint("LEFT", frame.label, "LEFT", -22, 0)
    frame.shade:SetPoint("RIGHT", frame.number, "RIGHT", 22, 0)
    frame.shade:SetHeight(80)
    frame:Hide()
    M.frame = frame
end

local SLAM, HOLD, FADE, SIZE = 0.14, 1.2, 0.6, 46
M.PER_CRIT = 1                 -- it stays a second longer for each crit of the burst
local function Font() return DAMAGE_TEXT_FONT or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF" end

local function Animate(_, dt)
    local m = M.live
    if not m then frame:SetScript("OnUpdate", nil); frame:Hide(); return end
    m.t = m.t + dt
    local t = m.t
    local scale
    if m.calm then scale = 1.2                                                     -- (Reduce animations: still)
    elseif t < SLAM then scale = 2.6 - 1.4 * (t / SLAM)                              -- slams in from big
    elseif t < SLAM + m.hold then scale = 1.2 + 0.05 * math.sin((t - SLAM) * 6)    -- holds, breathing
    else scale = 1.2 end
    local size = math.floor((m.base or SIZE) * scale + 0.5)
    if size ~= m.drawn then
        m.drawn = size
        frame.number:SetFont(Font(), size, "THICKOUTLINE")
        FitShade(size)
    end
    local out = math.max(0, t - SLAM - m.hold)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 150 + (m.calm and 0 or 40 * out))
    local a = 1 - out / FADE
    frame:SetAlpha(math.max(0, a))
    frame.glow:SetAlpha(math.max(0, a) * (0.35 + 0.15 * math.sin(t * 5)))
    if out >= FADE then M.live = nil; frame:SetScript("OnUpdate", nil); frame:Hide() end
end
Animate = ns.Protect(Animate)

-- Pin it: amount (may be secret), the ability's name; heal: it is what your heals did ("+2450", green)
M.HEAL_COLOR = { 0.42, 1, 0.66 }
function M:Show(amount, name, school, heal, count)
    if not frame then Build() end
    local p = ns.Impact and ns.Impact.PROFILES[school or ""]
    local c = (p and school ~= "physical") and p.color or { 1, 0.82, 0.3 }
    if heal then c = M.HEAL_COLOR end
    local calm = ns.Calm() and true or false
    local one = heal and "+%d" or "%d"
    local fmt, args, base = one, { amount }, SIZE
    if type(amount) == "table" and not ns.IsSecret(amount) and amount.list then   -- hits that cannot be added
        local list, parts = amount.list, {}
        args = {}
        local from = math.max(1, #list - M.LIST_MAX + 1)
        for i = from, #list do parts[#parts + 1] = one; args[#args + 1] = list[i] end
        fmt = (from > 1 and "... " or "") .. table.concat(parts, " + ")
        base = math.floor(SIZE * (#args > 2 and 0.5 or 0.65))      -- smaller, to fit them all
    end
    frame.number:SetFont(Font(), base * (calm and 1.2 or 2.6), "THICKOUTLINE")
    if heal then frame.number:SetTextColor(c[1], c[2], c[3]) else frame.number:SetTextColor(1, 0.86, 0.35) end
    local ok = pcall(frame.number.SetFormattedText, frame.number, fmt, unpack(args))
    if not ok then frame.number:SetText("!") end
    frame.label:SetText(name or "")
    frame.glow:SetVertexColor(c[1], c[2], c[3], 1)
    frame:SetAlpha(1)
    frame:Show()
    -- held a second longer for each crit; a burst that grows while shown is not slammed in again, only held
    -- longer from now
    local again = self.live and frame:IsShown() and self.live.t < SLAM + self.live.hold
    self.live = { t = again and SLAM or 0, calm = calm, base = base, hold = HOLD + M.PER_CRIT * (count or 1) }
    self.shown = (self.shown or 0) + 1
    frame:SetScript("OnUpdate", Animate)
    if ns.Impact and ns.db.impactFx then                       -- a little light thrown off it
        local f = ns.UnitFrames and ns.UnitFrames.frames.target
        if f and f.on then ns.Impact:Burst(f.health, ns.Impact.PROFILES.holy, 1.4) end
    end
end

-- Is this one of the rare ones? Returns true when it is shown.
-- Pins the burst's total once it is over: half a second after its last crit, each further crit putting it off
-- again with the new total (heal: in the green of a heal)
function M:Pin(number, label, school, heal, count)
    local p = { number = number, label = label, school = school, heal = heal, count = count }
    self.pending = p
    C_Timer.After(M.DELAY, ns.Protect(function()
        if self.pending ~= p then return end                       -- a later crit took its place
        self.pending = nil
        self:Show(p.number, p.label, p.school, p.heal, p.count)
        if ns.Rumble then ns.Rumble.busyUntil = nil; ns.Rumble:Play("moment") end
    end))
end

function M:Consider(amount, crit, ability, name, school)
    if not crit then return false end                              -- (a plain hit leaves the burst alone)
    local now = GetTime()
    local run = Join(amount, name, now)
    if run.n < 2 or not ns.db.bigMoments then return false end     -- a crit on its own: no burst yet
    local number, label = M.Number(run, amount), RunLines(run)
    if not run.shown then                                          -- a new moment: kept rare
        if fight.moments >= PER_FIGHT or now - fight.lastMoment < GAP then return false end
        fight.moments = fight.moments + 1
        run.shown = true
    end
    fight.lastMoment = now                                         -- (a run that goes on is the same moment, grown)
    self:Pin(number, label, school, nil, run.n)
    return true
end

-- A heal of yours landed: crit heals back to back are a moment, with what they healed together. amount is
-- what it healed (overheal taken off where the log says it); a heal that does not crit ends the run.
function M:Healed(spellID, name, amount, crit, school)
    if not ns.db.bigMoments then return false end
    name = name or SpellName(spellID)
    if not crit then return false end
    local now = GetTime()
    local run = Join(amount, name, now, "healChain")
    if run.n < 2 then return false end
    if not run.shown then
        if fight.moments >= PER_FIGHT or now - fight.lastMoment < GAP then return false end
        fight.moments = fight.moments + 1
        run.shown = true
    end
    fight.lastMoment = now
    self:Pin(M.Number(run, amount), RunLines(run), school or "holy", true, run.n)
    return true
end

-- From the combat log (Impact.lua hands us your direct heals when it reads the log)
function M.HealFromLog(spellID, name, amount, overheal, crit, schoolMask)
    if not M.active then return end
    M.usesLog = true
    local plain = (not ns.IsSecret(amount)) and type(amount) == "number" and amount or nil
    local over = (not ns.IsSecret(overheal)) and type(overheal) == "number" and overheal or 0
    if plain then amount = math.max(0, plain - over) end
    if ns.IsSecret(crit) then crit = false end
    M:Healed(spellID, name, amount, crit and true or false, ns.Impact and ns.Impact.School(schoolMask))
end

---------------------------------------------------------------------------
-- A key ability landed
---------------------------------------------------------------------------
local ANY = {}                   -- a spell that is not one of your key abilities: its crit still joins a burst
function M:Landed(spellID, name, amount, crit, school)
    local ability, key = M.Ability(spellID, name)
    if not ability then
        if crit then self:Consider(amount, true, ANY, name or SpellName(spellID), school) end
        return false
    end
    name = key
    if self:Consider(amount, crit, ability, name, school) then return true end
    if ns.db.abilityRumble and ns.Rumble then ns.Rumble:Play(ability.feel, crit and 1.3 or 1) end
    return true
end

-- Without the combat log: the ability you just used, matched to the next hit your target takes; a heal you
-- just cast, to the next heal that lands (on you, your target or your group: the game says which unit)
local pending, pendingHeal
local SWING_ANY = { swing = true }
local events = CreateFrame("Frame")
events:SetScript("OnEvent", ns.Protect(function(_, event, unit, a2, a3, a4, a5)
    if event == "PLAYER_REGEN_DISABLED" then
        fight.moments, fight.chain, fight.healChain = 0, nil, nil
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if unit == "player" then M.lastCast = { id = a3, at = GetTime() } end        -- (any spell: its name)
        if unit == "player" and M.Ability(a3) then pending = { id = a3, at = GetTime() } end
        if unit == "player" and ns.CastLook and ns.CastLook.IsHeal(nil, a3) then pendingHeal = { id = a3, at = GetTime() } end
    elseif event == "UNIT_COMBAT" then
        if M.usesLog or ns.IsSecret(a2) then return end
        if a2 == "HEAL" then
            if pendingHeal and GetTime() - pendingHeal.at < 1.0 then
                local crit = not ns.IsSecret(a3) and a3 == "CRITICAL"
                local id = pendingHeal.id
                pendingHeal = nil                                    -- (the same heal on two of the unit's names)
                M:Healed(id, nil, a4, crit, ns.Impact and ns.Impact.School(a5))
            end
            return
        end
        if unit ~= "target" then return end
        if a2 ~= "WOUND" then return end
        local crit = not ns.IsSecret(a3) and a3 == "CRITICAL"
        if pending and GetTime() - pending.at < 0.8 then
            local id = pending.id
            pending = nil
            if M.lastCast and M.lastCast.id == id then M.lastCast.used = true end   -- (one cast, one hit)
            M:Landed(id, nil, a4, crit, ns.Impact and ns.Impact.School(a5))
            return
        end
        -- any other crit of yours on your target joins a burst too: a white swing, a spell that is not one of
        -- your key abilities (where the combat log is closed to addons, the game's hit event is all there is;
        -- whose hit it is, Impact.lua judges as it does for the hit effects)
        if crit then
            local school = ns.Impact and ns.Impact.School(a5) or "physical"
            if ns.Impact and ns.Impact.Mine and not ns.Impact.Mine("target", school) then return end
            local last = M.lastCast
            -- named after what you just cast only if no hit was that cast yet: a swing right behind a Holy
            -- Strike is a swing, not a second Holy Strike
            local name = last and not last.used and GetTime() - last.at < 0.8 and SpellName(last.id)
            if name then last.used = true end
            if not name then name = school == "physical" and (_G.MELEE or "Melee") or nil end
            M:Consider(a4, true, SWING_ANY, name, school)
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
local SWING = { swing = true }
function M.Swing(amount, crit)
    if not M.active then return end
    if extra and GetTime() - extra.at > 0.5 then extra = nil end
    if not extra then
        -- your weapon's own swing: a crit joins the run of crits (a plain swing does not end one)
        if crit then
            M.usesLog = true
            M:Consider(amount, true, SWING, _G.MELEE or _G.ACTION_SWING or "Melee", "physical")
        end
        return
    end
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

-- For the debug report: how the amounts came, and the last burst
function M.Describe()
    local s = M.seen
    local out = { ("crit amounts: %d plain, %d secret, %d none; combat log read: %s"):format(s.plain, s.secret,
                  s.none, tostring(M.usesLog or false)) }
    local c = M.lastRun
    if c then
        local kinds = {}
        for _, a in ipairs(c.amounts or {}) do
            kinds[#kinds + 1] = ns.IsSecret(a) and "secret" or tostring(a)
        end
        out[#out + 1] = ("last burst: %d crits (%s), total %s: %s"):format(c.n, table.concat(kinds, ", "),
            tostring(c.total), RunLabel(c))
    end
    return out
end

ns.RegisterModule("moments", M)
