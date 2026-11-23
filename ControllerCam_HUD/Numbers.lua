-- ControllerCam HUD: the numbers for what happens to you, in the style of your own hits.
-- The game shows the damage you deal as big golden numbers that pop, and what you take as small plain text
-- that scrolls. While this is on, what you take gets the same treatment: in the game's damage font, popping in
-- and falling away beside your character, coloured by the damage school; heals rise in mint green; crits are
-- bigger and hold longer; a dodge, parry or miss says so. What a shield takes off a hit rises in silver-blue,
-- "120 absorbed" (how much, where the combat log can be read; a hit swallowed whole says "Absorb" otherwise).
-- Tightly coupled to the game's own option ("combat text for you"): when that is off, nothing shows here
-- either. When on, our numbers stand in for the game's scrolling text, which is made invisible meanwhile.

local ADDON, ns = ...
local L, C = ns.L, ns.colors

local N = { active = false, live = {}, free = {} }
ns.Numbers = N

ns.RegisterSetting({
    key = "numbers", kind = "boolean", default = true, command = "numbers", section = "Frames",
    label = "Stylized numbers on you",
    tip = "the damage and healing you take pop like your own hits, instead of the game's scrolling text (follows the game's option for combat text on you)",
})

local CVAR = "enableFloatingCombatText"
local POP, LIFE = 0.14, 1.1
-- crits and dodges are the big moments: they slam in, stick where they landed, then fade (like your own crits)
local SLAM, HOLD, FADE = 0.12, 0.85, 0.5
local SIZE = 26
local SCATTER = 1.4                -- how far apart a burst spreads
-- what missed you: the game's own words for it (DODGE, PARRY... are its texts in your language)
local AVOID = { DODGE = "Dodge", PARRY = "Parry", MISS = "Miss", BLOCK = "Block", RESIST = "Resist",
                IMMUNE = "Immune", EVADE = "Evade", ABSORB = "Absorb", DEFLECT = "Deflect", REFLECT = "Reflect" }
local function Word(action)
    local w = _G[action]
    if type(w) == "string" and w ~= "" then return w end
    return AVOID[action]
end

local holder = CreateFrame("Frame", nil, UIParent)
holder:SetSize(10, 10)
holder:SetFrameStrata("HIGH")
N.holder = holder

-- Where they appear: with the vertical bars on, just above the bars on your left, falling away outward (they
-- move with the bars, also when those follow the camera); otherwise just right of your character. Above the
-- bars and not on them, so a number never sits over your health and power while you need to read them.
N.RAISE = 14                       -- how far above the top of the bars they start
local side = 1
function N:Place()
    local UF = ns.UnitFrames
    local bars = UF and UF.frames and UF.frames.vertical
    holder:ClearAllPoints()
    if bars and bars.on then
        local h = UF.LAYOUT and UF.LAYOUT.vertical and UF.LAYOUT.vertical.h or 96      -- how tall the bars are
        holder:SetPoint("CENTER", bars.visual, "CENTER", -18, h / 2 + N.RAISE)
        side = -1
    else
        holder:SetPoint("CENTER", UIParent, "CENTER", 110, 30)
        side = 1
    end
    self.side = side
end

local function Font()
    return DAMAGE_TEXT_FONT or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end

local function Take()
    local fs = table.remove(N.free)
    if not fs then
        fs = holder:CreateFontString(nil, "OVERLAY")
        fs:SetShadowColor(0, 0, 0, 0.85)
        fs:SetShadowOffset(2, -2)
    end
    return fs
end

-- The game's option: may we show anything? (A client without it: yes.)
local function GameAllows()
    local v = GetCVar and GetCVar(CVAR)
    return v == nil or v == "1"
end

local driver = CreateFrame("Frame")
local function Tick(_, dt)
    for i = #N.live, 1, -1 do
        local n = N.live[i]
        n.t = n.t + dt
        local fs = n.fs
        if n.t >= n.life then
            fs:Hide()
            table.remove(N.live, i)
            N.free[#N.free + 1] = fs
        else
            if n.sticky then
                -- slam in huge, overshoot a little, then stay put and swell faintly; at the end rise and fade
                local scale
                if n.t < SLAM then
                    local k = n.t / SLAM
                    scale = n.big - (n.big - 0.92) * k
                elseif n.t < SLAM + 0.08 then
                    scale = 0.92 + 0.13 * (n.t - SLAM) / 0.08
                else
                    scale = 1.05 + 0.03 * math.min(1, (n.t - SLAM - 0.08) / HOLD)
                end
                local size = math.floor(n.size * scale + 0.5)
                if size ~= n.drawn then
                    n.drawn = size
                    fs:SetFont(Font(), size, "THICKOUTLINE")
                end
                local out = math.max(0, n.t - (n.life - FADE))
                fs:ClearAllPoints()
                fs:SetPoint("CENTER", holder, "CENTER", n.x, n.y + 30 * out)
                fs:SetAlpha(1 - out / FADE)
            else
                -- pop in big, settle, then drift away (hits fall to the side, heals rise) and fade
                local k = n.t / POP
                local scale = k < 1 and (n.big - (n.big - 1) * k) or 1
                local size = math.floor(n.size * scale + 0.5)
                if size ~= n.drawn then
                    n.drawn = size
                    fs:SetFont(Font(), size, "THICKOUTLINE")
                end
                local after = math.max(0, n.t - POP)
                local x = n.x + n.dx * after
                local y = n.y + n.dy * after - (n.fall and 60 * after * after or 0)
                fs:ClearAllPoints()
                fs:SetPoint("CENTER", holder, "CENTER", x, y)
                local fade = n.life - 0.35
                fs:SetAlpha(n.t > fade and math.max(0, 1 - (n.t - fade) / 0.35) or 1)
            end
        end
    end
    if #N.live == 0 then driver:SetScript("OnUpdate", nil) end
end
Tick = ns.Protect(Tick)

-- One number. kind: "hit" / "heal" / "word". value: a number (may be secret) or a word. color {r,g,b}.
function N:Show(kind, value, color, crit)
    local fs = Take()
    local n = { fs = fs, t = 0, kind = kind, crit = crit and true or false }
    n.sticky = crit or kind == "word"
    n.size = (crit and SIZE * 1.4 or SIZE) * ((kind == "word") and 0.9 or 1)
    n.big = n.sticky and 2.4 or 1.6
    n.life = n.sticky and (SLAM + 0.08 + HOLD + FADE) or LIFE
    -- each new one starts apart from the last (a lane, and a little chance), so a burst stays readable
    self.lane = ((self.lane or 0) % 3) + 1
    local lane = self.lane - 2
    local jx, jy = (math.random() - 0.5) * 16 * SCATTER, (math.random() - 0.5) * 10 * SCATTER
    if kind == "heal" or kind == "absorb" then                 -- (what helps you rises)
        n.x, n.y, n.dx, n.dy = -20 * SCATTER + lane * 14 * SCATTER + jx, lane * 10 * SCATTER + jy, 6 * SCATTER, 46
    elseif n.sticky then                                   -- where it lands, it stays: a little above the rest
        n.x, n.y = 10 + lane * 18 * SCATTER + jx, 44 + lane * 8 * SCATTER + jy
    else
        n.x, n.y, n.dx, n.dy, n.fall = 10 + lane * 14 * SCATTER + jx, 20 + lane * 12 * SCATTER + jy, 40 * SCATTER, 20, true
    end
    n.x, n.dx = n.x * side, (n.dx or 0) * side            -- on the left of you: mirrored, falling outward
    fs:SetFont(Font(), math.floor(n.size * n.big + 0.5), "THICKOUTLINE")
    n.drawn = math.floor(n.size * n.big + 0.5)
    fs:SetTextColor(color[1], color[2], color[3], 1)
    local ok = pcall(function()
        if kind == "word" then fs:SetText(value)
        elseif kind == "heal" then fs:SetFormattedText("+%d", value)
        elseif kind == "absorb" then fs:SetFormattedText(L["%d absorbed"], value)
        else fs:SetFormattedText(crit and "-%d!" or "-%d", value) end
    end)
    if not ok then N.free[#N.free + 1] = fs; return end
    fs:ClearAllPoints()
    fs:SetPoint("CENTER", holder, "CENTER", n.x, n.y)
    fs:SetAlpha(1)
    fs:Show()
    self.live[#self.live + 1] = n
    self.shown = (self.shown or 0) + 1
    driver:SetScript("OnUpdate", Tick)
end

-- Colours of what you take. Nature damage (poison) has its school's green everywhere else, but here it stands
-- next to the green of healing, and the two could not be told apart: on you, poison is an acid yellow-green
-- and a heal a cool mint, so one reads as harm and the other as help at a glance.
N.TAKEN = { nature = { 0.80, 0.84, 0.14 } }
local HEAL = { 0.42, 1, 0.66 }               -- a heal: green, a touch of mint
N.HEAL = HEAL

local function SchoolColor(mask)
    local IM = ns.Impact
    local school = IM and IM.School(mask) or "physical"
    if school == "physical" then return C.danger or { 1, 0.25, 0.2 } end
    return N.TAKEN[school] or IM.PROFILES[school].color
end

local WORD = { 0.85, 0.88, 0.95 }
N.SHIELD = { 0.72, 0.85, 1 }      -- what a shield took: silver-blue, apart from a heal's mint and holy's gold

-- From the combat log (Impact.lua): how much a shield took off a hit on you. Once the log has told one, the
-- game's plain "Absorb" of a hit swallowed whole is left to it (it says how much).
function N.FromLogAbsorb(amount, mask)
    if not N.active or not GameAllows() or ns.UnitFrames.fake then return end
    if ns.IsSecret(amount) or type(amount) ~= "number" or amount <= 0 then return end
    N.usesLog = true
    N:Show("absorb", amount, N.SHIELD)
end

local function Plain(v)
    if ns.IsSecret(v) then return nil end
    return v
end

-- UNIT_COMBAT for you: what happened, how hard, which school
local events = CreateFrame("Frame")
events:SetScript("OnEvent", ns.Protect(function(_, _, unit, action, flag, amount, mask)
    if unit ~= "player" or not N.active or not GameAllows() or ns.UnitFrames.fake then return end
    action = Plain(action)
    local crit = Plain(flag) == "CRITICAL"
    if action == "WOUND" then
        if not ns.IsSecret(amount) and type(amount) ~= "number" then return end
        local what = Plain(flag)
        if not ns.IsSecret(amount) and amount == 0 and what and AVOID[what] then
            -- nothing got through: a shield swallowed it (or a block, a resist). The log says how much, if it
            -- can be read; else the game's word for it
            if what == "ABSORB" then
                if not N.usesLog then N:Show("word", Word(what), N.SHIELD) end
            else
                N:Show("word", Word(what), WORD)
            end
            return
        end
        N:Show("hit", amount, SchoolColor(Plain(mask)), crit)
    elseif action == "HEAL" then
        if not ns.IsSecret(amount) and type(amount) ~= "number" then return end
        N:Show("heal", amount, HEAL, crit)
    elseif action and AVOID[action] then
        N:Show("word", Word(action), WORD)
    end
end))

-- The demo plays its hits through here too (only yours: the player's frame)
function N:Demo(unit, amount, school, crit)
    if unit ~= "player" or not self.active or not GameAllows() then return end
    if school == "heal" then
        self:Show("heal", amount, HEAL, crit)
    else
        local IM = ns.Impact
        local color = (school and N.TAKEN[school])
            or ((school and school ~= "physical" and IM and IM.PROFILES[school]) and IM.PROFILES[school].color)
            or C.danger or { 1, 0.25, 0.2 }
        self:Show("hit", math.abs(amount), color, crit)
    end
end

-- The game's scrolling text for you: invisible while ours stands in. It loads on demand, so we look again
-- whenever an addon of the game's loads.
local function FadeGame()
    ns.SetBlizzardFaded("CombatText", N.active and GameAllows())
    N:Place()
end

local loader = CreateFrame("Frame")
loader:SetScript("OnEvent", ns.Protect(function(_, event, name)
    if event == "ADDON_LOADED" and name ~= "Blizzard_CombatText" then return end
    FadeGame()
end))

function N:Apply(run)
    local want = run and ns.db.numbers and true or false
    if want ~= self.active then
        self.active = want
        if want then
            pcall(events.RegisterUnitEvent, events, "UNIT_COMBAT", "player")
            pcall(loader.RegisterEvent, loader, "ADDON_LOADED")
            pcall(loader.RegisterEvent, loader, "CVAR_UPDATE")
        else
            events:UnregisterAllEvents()
            loader:UnregisterAllEvents()
            for _, n in ipairs(self.live) do n.fs:Hide(); self.free[#self.free + 1] = n.fs end
            self.live = {}
        end
    end
    FadeGame()
end

ns.RegisterModule("numbers", N)

---------------------------------------------------------------------------
-- Abilities ready: when an ability that only a moment allows becomes usable (Mongoose Bite after a dodge or
-- from Expose Prey, Overpower after a dodge, Revenge after a block, Riposte after a parry, Counterattack...) or
-- when the game lights one up on the action bar, its name in bold red right where you look: just above the
-- aiming dot in the middle of the screen (the controller's cursor while the camera is yours), for about
-- a second and a half. Seen two ways, whichever the game gives first: the spell turning usable, or its glow on the bar. Only
-- what you know; nothing is pressed or bound.
---------------------------------------------------------------------------
local RA = { active = false, state = {} }
N.Ready = RA
ns.RegisterSetting({
    key = "readyAlerts", kind = "boolean", default = true, command = "ready", section = "Frames",
    label = "Abilities ready",
    tip = "when an ability only a moment allows becomes usable (Mongoose Bite, Overpower, Revenge, Riposte, Counterattack) or the game lights one up on your bar: its name in bold red in the middle of the screen for a moment",
})
-- The moment's abilities, by every rank (all ranks share the name): watched for turning usable
RA.REACTIVE = {
    { 1495, 14269, 14270, 14271, 36916, 53339, 259387 },     -- Mongoose Bite (a dodge, or Expose Prey)
    { 7384, 7887, 11584, 11585 },                            -- Overpower (the foe dodged)
    { 6572, 6574, 7379, 11600, 11601, 25288 },               -- Revenge (you blocked, dodged or parried)
    { 14251 },                                               -- Riposte (you parried)
    { 19306, 20909, 20910 },                                 -- Counterattack (you parried)
}
RA.LIFE, RA.POP, RA.FADE = 1.6, 0.12, 0.5      -- held a second and a half: a quick pop, a gentle fade
RA.RAISE = 0.1                     -- the aiming dot: this share of the screen's height above its middle
RA.ABOVE = 34                      -- and the name this far above the dot
RA.OVER = 26                       -- the name's middle this far above the top of the game's reticle, when it shows
RA.COLOR = { 1, 0.18, 0.14 }

local function SpellName(id)
    local get = (C_Spell and C_Spell.GetSpellName) or GetSpellInfo
    if not get or ns.IsSecret(id) then return nil end
    local ok, name = pcall(get, id)
    name = ok and ns.Plain(name)
    return (type(name) == "string" and name ~= "") and name or nil
end

local function Knows(id)
    for _, fn in ipairs({ IsPlayerSpell or false, IsSpellKnown or false }) do
        if fn then
            local ok, yes = pcall(fn, id)
            if ok and ns.Yes(yes) then return true end
        end
    end
    return false
end

-- The moment's abilities you know: { name, ... }
function RA.Known()
    local list = {}
    for _, ranks in ipairs(RA.REACTIVE) do
        for _, id in ipairs(ranks) do
            if Knows(id) then
                local name = SpellName(ranks[1]) or SpellName(id)
                if name then list[#list + 1] = name end
                break
            end
        end
    end
    return list
end

-- Can it be used right now? (its moment has come; mana and the cooldown aside)
function RA.Usable(name)
    local fn = (C_Spell and C_Spell.IsSpellUsable) or IsUsableSpell
    if not (fn and name) then return false end
    local ok, usable = pcall(fn, name)
    return ok and ns.Yes(usable) or false
end

local alert, since
local function Alert()
    if alert then return alert end
    alert = CreateFrame("Frame", nil, UIParent)
    alert:SetSize(10, 10)
    alert:SetFrameStrata("HIGH")
    alert.text = alert:CreateFontString(nil, "OVERLAY")
    alert.text:SetPoint("CENTER", alert, "CENTER", 0, 0)
    alert.text:SetShadowColor(0, 0, 0, 0.9)
    alert.text:SetShadowOffset(1, -1)
    alert:Hide()
    alert:SetScript("OnUpdate", ns.Protect(function(self, dt)
        since = since + dt
        if since >= RA.LIFE then self:Hide(); return end
        local calm = ns.Calm and ns.Calm()
        local k = (not calm and since < RA.POP) and (1.5 - 0.5 * since / RA.POP) or 1      -- a quick pop, then still
        self:SetScale(k)
        local out = since - (RA.LIFE - RA.FADE)
        self:SetAlpha(out > 0 and math.max(0, 1 - out / RA.FADE) or 1)
    end))
    RA.alert = alert
    return alert
end

function RA:Show(name)
    local a = Alert()
    local okH, h = pcall(UIParent.GetHeight, UIParent)
    h = (okH and type(h) == "number" and not ns.IsSecret(h)) and h or 768
    a:ClearAllPoints()
    local dot = ns.Reticle and ns.Reticle.Game()
    local okV, seen = pcall(function() return dot and dot:IsVisible() end)
    if okV and ns.Yes(seen) then
        a:SetPoint("CENTER", dot, "TOP", 0, RA.OVER)                          -- just above the game's aiming dot
    else
        a:SetPoint("CENTER", UIParent, "CENTER", 0, h * RA.RAISE + RA.ABOVE)  -- (where it usually sits)
    end
    if ns.Reticle then ns.Reticle:Pop() end
    a.text:SetFont(Font(), 24, "THICKOUTLINE")
    a.text:SetTextColor(RA.COLOR[1], RA.COLOR[2], RA.COLOR[3], 1)
    a.text:SetText(name)
    since = 0
    a:SetScale(1)
    a:SetAlpha(1)
    a:Show()
    self.shown = (self.shown or 0) + 1
    self.lastName = name
end

-- One piece of news per time an ability's moment comes, however the game tells it (turning usable, its glow)
local function Moment(name, now)
    local st = RA.state[name]
    if not st then st = {}; RA.state[name] = st end
    if not st.on then RA:Show(name) end
    st.on = true
end

local watch = CreateFrame("Frame")
watch:SetScript("OnEvent", ns.Protect(function(_, event, spellID)
    if event == "SPELLS_CHANGED" or event == "PLAYER_TALENT_UPDATE" then
        RA.known = RA.Known()
        return
    end
    if event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" then         -- the game lit one up: whatever it is
        local name = SpellName(spellID)
        if name then Moment(name) end
        return
    end
    if event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
        local name = SpellName(spellID)
        if name and RA.state[name] and not RA.Usable(name) then RA.state[name].on = false end
        return
    end
    for _, name in ipairs(RA.known or {}) do                     -- what can be used changed: the moment's abilities
        if RA.Usable(name) then Moment(name)
        elseif RA.state[name] then RA.state[name].on = false end
    end
end))

local WATCH = { "SPELL_UPDATE_USABLE", "ACTIONBAR_UPDATE_USABLE", "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW",
                "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", "SPELLS_CHANGED", "PLAYER_TALENT_UPDATE" }
function RA:Apply(run)
    local want = run and ns.db.readyAlerts and true or false
    if want and not self.active then
        self.active = true
        for _, e in ipairs(WATCH) do pcall(watch.RegisterEvent, watch, e) end
    elseif not want and self.active then
        self.active = false
        watch:UnregisterAllEvents()
        if alert then alert:Hide() end
    end
    self.known = want and RA.Known() or {}
    self.state = {}
    for _, name in ipairs(self.known) do                         -- usable already: not news
        if RA.Usable(name) then self.state[name] = { on = true } end
    end
end
ns.RegisterModule("ready", RA)

---------------------------------------------------------------------------
-- Cooldowns coming back: in place of a cooldown bar, your key abilities call out as they come off cooldown.
-- Two seconds before one is ready its icon and name appear on the right of your character (the mirror of the
-- vertical bars, a little nearer, moving with them; unlock the frames to drag them somewhere else: they still
-- move with the bars, by as much as you moved them), small and faint, and rise and grow as the time runs down; the moment it is
-- ready it pops, turns gold, holds a beat and fades. Several at once never overlap: the one nearest ready
-- is on top and the others shift below it, a little indented, sliding as the stack changes. The global
-- cooldown and anything shorter than a few seconds never call out; the abilities only a moment allows are
-- left to Abilities ready. Read from the game's cooldowns; where those are kept secret (in combat), from your
-- cast and the cooldown last seen (or the spell's own base cooldown, which knows nothing of your talents: cast
-- again sooner than that and the shorter time is learned). It pops as soon as pressing it works: the game takes
-- a press a moment before the cooldown is over (its spell queue window), so the pop comes that much early.
-- One callout per cooldown: when the time it is ready is put right (your cast's guess, then the game's own
-- reading), the callout on the screen moves with it rather than a second one starting.
---------------------------------------------------------------------------
local RC = { active = false, track = {}, live = {} }
N.Soon = RC
ns.RegisterSetting({
    key = "soonCallouts", kind = "boolean", default = true, command = "cdcallout", section = "Frames",
    label = "Cooldowns coming back",
    tip = "your key abilities rise and grow beside your character in the last two seconds of their cooldown, then pop gold the moment they are ready (in place of a cooldown bar)",
})

ns.RegisterSetting({
    key = "soonBuffs", kind = "boolean", default = true, command = "buffcallout", section = "Frames",
    label = "Buffs wearing off",
    tip = "a buff you cast on yourself (a Seal, Holy Shield, a shout or shield) calls out with your cooldowns as it runs out, and in red the moment it is gone, also when it is used up early",
})

-- Besides each class's key abilities (Moments.lua), the cooldowns worth hearing about, by one rank each
RC.EXTRA = {
    HUNTER = { { 2973, "Raptor Strike" }, { 3044, "Arcane Shot" }, { 13795, "Immolation Trap" }, { 3045, "Rapid Fire" },
               { 19574, "Bestial Wrath" }, { 34026, "Kill Command" } },
    WARRIOR = { { 23922, "Shield Slam" }, { 1680, "Whirlwind" }, { 6343, "Thunder Clap" } },
    ROGUE = { { 1766, "Kick" } },
    MAGE = { { 2136, "Fire Blast" }, { 120, "Cone of Cold" }, { 122, "Frost Nova" } },
    WARLOCK = { { 17877, "Shadowburn" } },
    DRUID = { { 16979, "Feral Charge" } },
    PALADIN = { { 853, "Hammer of Justice" }, { 26573, "Consecration" }, { 20925, "Holy Shield" } },
}
RC.LEAD = 2                        -- seconds of warning before it is ready
RC.GCD = 1.6                       -- a cooldown this short is the global cooldown: not news
RC.MIN = 4                         -- only cooldowns at least this long call out
RC.ROW, RC.RISE = 26, 40           -- how far apart (at full size); how far one rises while it counts down
RC.GAP = 4                         -- room between two, beyond their size
RC.STAGGER = 14                    -- each one lower in the stack sits this much further in
RC.SLIDE = 14                      -- how quickly one slides to its new place in the stack
RC.POP, RC.HOLD, RC.FADE = 0.15, 0.8, 0.4
RC.SIZE = 18
RC.GOLD = { 1, 0.82, 0.3 }
RC.QUEUE = 0.4                     -- at most this early (the game's spell queue window, when it says)
RC.FADED = { 1, 0.38, 0.28 }       -- a buff of yours that wore off: its name in red, its icon grey
RC.BUFF_MAX = 600                  -- buffs lasting longer than this are not watched (Righteous Fury, a mount...)
RC.SIDE = { 150, -40 }             -- with the vertical bars off: right of your character
RC.MIRROR = 0.6                    -- how far right, as a share of how far left the bars sit (nearer your character)
local READ = 0.1                   -- how often the cooldowns are read

-- What each one's cooldown turned out to be, kept across reloads: "CLASS:Name" -> seconds
ns.RegisterSaved("soonLearnt", function(old)
    local out = {}
    if type(old) ~= "table" then return out end
    for k, v in pairs(old) do
        if type(k) == "string" and tonumber(v) and tonumber(v) > 0 and tonumber(v) < 3600 then out[k] = tonumber(v) end
    end
    return out
end)
local function Keep(t)
    local _, class = UnitClass("player")
    if ns.db and ns.db.soonLearnt and t.dur then ns.db.soonLearnt[(class or "") .. ":" .. t.name] = t.dur end
end
local function Kept(name)
    local _, class = UnitClass("player")
    return ns.db and ns.db.soonLearnt and ns.db.soonLearnt[(class or "") .. ":" .. name]
end

local function Num(v)
    v = ns.Plain(v)
    return type(v) == "number" and v or nil
end

-- The abilities only a moment allows (Abilities ready covers them), by id and by name
local function Reactive()
    local ids, names = {}, {}
    for _, ranks in ipairs(RA.REACTIVE) do
        for _, id in ipairs(ranks) do ids[id] = true end
        local n = SpellName(ranks[1])
        if n then names[n] = true end
    end
    return ids, names
end

-- Do you have it? By the id, or by the name (any rank)
local function Have(id, name)
    if Knows(id) then return true end
    if not name then return false end
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, name)
        if ok and info ~= nil and not ns.IsSecret(info) then return true end
    elseif GetSpellInfo then
        local ok, n = pcall(GetSpellInfo, name)
        if ok and n ~= nil and not ns.IsSecret(n) then return true end
    end
    return false
end

local function Icon(id)
    local get = (C_Spell and C_Spell.GetSpellTexture) or GetSpellTexture
    if not get then return nil end
    local ok, tex = pcall(get, id)
    return ok and ns.Plain(tex) or nil
end

-- The spells you have that are watched: { { id, name, icon }, ... }
function RC.Known()
    local _, class = UnitClass("player")
    local list, seen = {}, {}
    local ids, names = Reactive()
    local key = ns.Moments and ns.Moments.KEY and ns.Moments.KEY[class or ""] or {}
    for _, group in ipairs({ key, RC.EXTRA[class or ""] or {} }) do
        for _, a in ipairs(group) do
            local name = SpellName(a[1]) or a[2]
            if not (ids[a[1]] or names[name] or names[a[2]] or seen[name]) and Have(a[1], name) then
                seen[name] = true
                list[#list + 1] = { id = a[1], name = name, icon = Icon(a[1]) }
            end
        end
    end
    return list
end

-- Its cooldown as the game gives it: start, duration (either may be secret or nil)
local function Cooldown(name)
    if C_Spell and C_Spell.GetSpellCooldown then
        local ok, info = pcall(C_Spell.GetSpellCooldown, name)
        if ok and type(info) == "table" and not ns.IsSecret(info) then return info.startTime, info.duration end
        if ok then return nil end
    end
    if GetSpellCooldown then
        local ok, s, d = pcall(GetSpellCooldown, name)
        if ok then return s, d end
    end
end

local function Base(id)
    if not GetSpellBaseCooldown then return nil end
    local ok, ms = pcall(GetSpellBaseCooldown, id)
    ms = ok and Num(ms)
    return (ms and ms > 0) and ms / 1000 or nil
end

-- Read every spell's cooldown: when it is ready (readyAt), how long it was (dur), plain or worked out
local function Read(now)
    for _, t in ipairs(RC.track) do
        local s, d = Cooldown(t.name)
        s, d = Num(s), Num(d)
        if s and d then
            t.src = "plain"
            if d > RC.GCD and s > 0 then
                if not t.readyAt or s >= t.readyAt - 0.5 then           -- begun after the last one was over:
                    if t.readyAt ~= s + d then t.gen = (t.gen or 0) + 1 end   -- a new cooldown
                end                                                     -- (else the same one, put right)
                local new = t.dur ~= d
                t.dur, t.readyAt, t.from = d, s + d, "plain"
                if new then t.learnt = "read"; Keep(t) end
            elseif t.from == "cast" and t.castAt and now - t.castAt > 0.3 then
                t.readyAt, t.from = nil, nil                            -- the cast never started one (a strike on
                t.gen = (t.gen or 0) + 1                                -- your next swing, the target died first)
                ns.Note("cooldown callouts: %s was cast but no cooldown started", t.name)
            elseif d == 0 and t.from == "plain" and t.readyAt and t.readyAt > now + READ then
                t.readyAt = now                                       -- it ended early: ready now
            end
        else
            t.src = "secret"
        end
    end
end

-- You cast one: where the game keeps its cooldown secret, it is ready after the cooldown last seen. Cast
-- before we thought it ready: it was ready sooner, so its cooldown is at most the time since the last cast.
function RC.Cast(spellID)
    local name = SpellName(spellID)
    local now = GetTime()
    for _, t in ipairs(RC.track) do
        local mine = t.id == spellID or (name and t.name == name)
        local s, d
        if mine then s, d = Cooldown(t.name) end
        if mine and Num(s) and Num(d) then
            t.castAt = now                                              -- the game says: its reading stands
        elseif mine then
            if t.castAt and t.readyAt and t.readyAt > now + READ then
                local seen = now - t.castAt
                if seen > RC.GCD and (not t.dur or seen < t.dur) then
                    ns.Note("cooldown callouts: %s was ready %.1f s sooner than thought: %.1f s now",
                            t.name, t.readyAt - now, seen)
                    t.dur, t.learnt = seen, "recast"
                    Keep(t)
                end
            end
            t.castAt = now
            t.gen = (t.gen or 0) + 1                                    -- cast: a new cooldown
            local dur = t.dur or Base(t.id)
            if dur and dur > RC.GCD then
                t.dur, t.readyAt, t.from = dur, now + dur, "cast"
            end
        end
    end
end

-- How early the pop comes: when a press is already taken (the spell queue window)
function RC.Early()
    local ok, ms = pcall(GetCVar or function() end, "SpellQueueWindow")
    ms = ok and tonumber(ns.Plain(ms))
    if not ms then return 0 end
    return math.max(0, math.min(RC.QUEUE, ms / 1000))
end

-- Where the rows stand: the mirror of the vertical bars, on the right of your character
local place = CreateFrame("Frame", nil, UIParent)
place:SetSize(10, 10)
place:SetFrameStrata("HIGH")
RC.holder = place

local function Scale(f)
    local ok, s = pcall(function() return f:GetEffectiveScale() end)
    s = ok and Num(s)
    return (s and s > 0) and s or 1
end

-- Where the stack starts (its top row's left end), from the centre of the screen: x, y, and where it would be
-- had it not been dragged. Also for others that sit beside it (the healer's party, Group.lua).
function RC.Spot()
    local UF = ns.UnitFrames
    local bars = UF and UF.frames and UF.frames.vertical
    local x, y = RC.SIDE[1], RC.SIDE[2]
    if bars and bars.on and bars.visual then
        local okB, bx, by = pcall(bars.visual.GetCenter, bars.visual)
        local okU, ux, uy = pcall(UIParent.GetCenter, UIParent)
        bx, by, ux, uy = okB and Num(bx), okB and Num(by), okU and Num(ux), okU and Num(uy)
        if bx and by and ux and uy then
            local k = Scale(bars.visual) / Scale(UIParent)
            local h = UF.LAYOUT and UF.LAYOUT.vertical and UF.LAYOUT.vertical.h or 96
            x, y = -(bx * k - ux) * RC.MIRROR, by * k - uy - h / 4      -- across from the bars, their lower half
        end
    end
    local baseX, baseY = x, y
    local moved = ns.db and ns.db.pos and ns.db.pos.soon                  -- where you dragged them: by that much
    if type(moved) == "table" and tonumber(moved.x) and tonumber(moved.y) then
        x, y = x + moved.x, y + moved.y
    end
    return x, y, baseX, baseY
end

function RC.Place()
    local x, y, baseX, baseY = RC.Spot()
    RC.baseX, RC.baseY = baseX, baseY
    place:ClearAllPoints()
    place:SetPoint("CENTER", UIParent, "CENTER", x, y)
    RC.x, RC.y = x, y
end

-- Moving them: while the frames are unlocked, a box where the rows rise, to drag
RC.GRIP = { w = 190, h = 80, x = -14, y = -16 }       -- its size, and its lower left corner from the rows' start
local grip
local function Grip()
    if grip then return grip end
    local G = RC.GRIP
    grip = CreateFrame("Frame", nil, UIParent)
    grip:SetSize(G.w, G.h)
    grip:SetFrameStrata("HIGH")
    grip.overlay = grip:CreateTexture(nil, "OVERLAY")
    grip.overlay:SetAllPoints(grip)
    grip.overlay:SetColorTexture(0.4, 0.8, 1, 0.35)
    grip.label = ns.FontString(grip, 11, "CENTER")
    grip.label:SetPoint("CENTER", grip, "CENTER", 0, 0)
    grip.label:SetText(L["Cooldowns coming back"])
    grip:Hide()
    RC.grip = grip
    return grip
end

local function Hold()
    grip:ClearAllPoints()
    grip:SetPoint("BOTTOMLEFT", place, "CENTER", RC.GRIP.x, RC.GRIP.y)
end

-- Dropped: how far from where they would be, kept (so they still follow the bars)
function RC.Dropped()
    local G = RC.GRIP
    local ok, cx, cy = pcall(grip.GetCenter, grip)
    local okU, ux, uy = pcall(UIParent.GetCenter, UIParent)
    cx, cy, ux, uy = ok and Num(cx), ok and Num(cy), okU and Num(ux), okU and Num(uy)
    if cx and cy and ux and uy and RC.baseX then
        local x = cx - ux - (G.w / 2 + G.x)
        local y = cy - uy - (G.h / 2 + G.y)
        ns.db.pos = ns.db.pos or {}
        ns.db.pos.soon = { x = math.floor(x - RC.baseX + 0.5), y = math.floor(y - RC.baseY + 0.5) }
    end
    RC.Place()
    Hold()
end

function RC:SetUnlocked(on)
    on = on and self.active and true or false
    if not on and not grip then return end
    local g = Grip()
    g:EnableMouse(on)
    g:SetMovable(on)
    if on then
        RC.Place()
        Hold()
        g:RegisterForDrag("LeftButton")
        g:SetScript("OnDragStart", function(m) if not InCombatLockdown() then m:StartMoving() end end)
        g:SetScript("OnDragStop", function(m) m:StopMovingOrSizing(); RC.Dropped() end)
        g:Show()
    else
        g:SetScript("OnDragStart", nil)
        g:SetScript("OnDragStop", nil)
        g:Hide()
    end
end

local spare = {}
local function Widget()
    local w = table.remove(spare)
    if w then return w end
    w = CreateFrame("Frame", nil, place)
    w:SetSize(10, 10)
    w.icon = w:CreateTexture(nil, "ARTWORK")
    w.icon:SetSize(RC.SIZE + 4, RC.SIZE + 4)
    w.icon:SetPoint("LEFT", w, "LEFT", 0, 0)
    w.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    w.text = w:CreateFontString(nil, "OVERLAY")
    w.text:SetPoint("LEFT", w.icon, "RIGHT", 5, 0)
    w.text:SetShadowColor(0, 0, 0, 0.9)
    w.text:SetShadowOffset(2, -2)
    return w
end

local function Start(t)
    local w = Widget()
    w.icon:SetTexture(t.icon or 134400)
    w.text:SetFont(Font(), RC.SIZE, "OUTLINE")
    w.text:SetText(t.name)
    local early = t.kind == "fade" and 0 or RC.Early()
    if w.icon.SetDesaturated then w.icon:SetDesaturated(false) end
    local c = { t = t, readyAt = t.readyAt - early, w = w, gen = t.gen, kind = t.kind }
    RC.live[#RC.live + 1] = c
    t.calledGen = t.gen
    ns.Note("cooldown callouts: %s in %.1f s (cooldown %.1f s from %s, %s; pops %.2f s early)", t.name,
            t.readyAt - GetTime(), t.dur or -1, tostring(t.from), tostring(t.learnt or "base"), early)
    RC.shown = (RC.shown or 0) + 1
    w:Show()
    return c
end

-- How one looks, now: rising and growing to its moment, then a pop of gold, a beat, a fade. false when done.
-- (want: how high it would be on its own; the stack decides where it is)
local function Look(c, now, calm)
    local left = c.readyAt - now
    local want, scale, alpha, color
    if left > 0 then
        local k = math.max(0, math.min(1, 1 - left / RC.LEAD))
        want, scale, alpha, color = RC.RISE * k, 0.6 + 0.4 * k, 0.35 + 0.65 * k, C.text
        c.ready = false
    else
        local since = -left
        if since >= RC.POP + RC.HOLD + RC.FADE then return false end
        want, color, alpha = RC.RISE, c.kind == "fade" and RC.FADED or RC.GOLD, 1
        if c.kind == "fade" and not c.ready and c.w.icon.SetDesaturated then c.w.icon:SetDesaturated(true) end
        scale = since < RC.POP and (1.15 + 0.2 * math.sin(math.pi * since / RC.POP)) or 1.15
        local out = since - RC.POP - RC.HOLD
        if out > 0 then alpha = 1 - out / RC.FADE end
        c.ready = true
    end
    if calm then want, scale = 0, 1 end
    c.want, c.scale, c.alpha, c.color = want, scale, alpha, color
    return true
end

local function Sooner(a, b)
    if a.readyAt ~= b.readyAt then return a.readyAt < b.readyAt end
    return a.t.name < b.t.name
end

-- The stack: the one nearest ready on top, each other one far enough below the one above it never to touch
-- it, a little further in; each slides to its place (put there at once the first time, and with calm on)
local function Stack(dt, calm)
    local order = {}
    for _, c in ipairs(RC.live) do order[#order + 1] = c end
    table.sort(order, Sooner)
    local above
    for i, c in ipairs(order) do
        local ty, tx = c.want, (i - 1) * RC.STAGGER
        local gap
        if above then
            gap = RC.ROW * (above.scale + c.scale) / 2 + RC.GAP
            ty = math.min(ty, above.ty - gap)
        end
        c.ty = ty
        if not c.y or calm then
            c.y, c.x = ty, tx
        else
            local k = math.min(1, dt * RC.SLIDE)
            c.y, c.x = c.y + (ty - c.y) * k, c.x + (tx - c.x) * k
        end
        if above then c.y = math.min(c.y, above.y - gap) end          -- (sliding or not, never touching)
        local w = c.w
        w:SetScale(c.scale)
        w:ClearAllPoints()
        w:SetPoint("LEFT", place, "CENTER", c.x / c.scale, c.y / c.scale)
        w:SetAlpha(c.alpha)
        w.text:SetTextColor(c.color[1], c.color[2], c.color[3], 1)
        above = c
    end
end

---------------------------------------------------------------------------
-- Buffs wearing off: a buff you cast on yourself (one of your spells, not a passive or a proc, lasting at most
-- ten minutes) calls out in the same stack as it runs out, and pops red the moment it is gone; used up early
-- (a Seal by Judgement) or taken away, it pops at once. Refreshed while it counts down: the callout goes.
-- Where the game keeps the time left secret, only the moment it is gone.
---------------------------------------------------------------------------
RC.buffs = {}                      -- [name] = { name, icon, gen, readyAt (when it runs out), present }
local castable = {}
local function Passive(id)
    local fn = (C_Spell and C_Spell.IsSpellPassive) or IsPassiveSpell
    if not fn then return false end
    local ok, yes = pcall(fn, id)
    return ok and ns.Yes(yes) or false
end
local function Castable(id, name)
    if castable[id] == nil then castable[id] = (Have(id, name) and not Passive(id)) and true or false end
    return castable[id]
end

local function OwnBuffs()
    local U = ns.Unit
    if not U then return {} end
    local list = U.Filtered and U.Filtered("player", "HELPFUL", "HELPFUL|PLAYER", 40)
    if not list then
        list = {}
        for i = 1, 40 do
            local a = U.Aura and U.Aura("player", i, "HELPFUL|PLAYER")
            if not a then break end
            list[#list + 1] = a
        end
    end
    return list
end

local function ReadBuffs(now)
    local here = {}
    for _, a in ipairs(OwnBuffs()) do
        local name, id = ns.Plain(a.name), Num(a.spellId)
        local dur, ends = Num(a.duration), Num(a.expirationTime)
        if type(name) == "string" and name ~= "" and id and Castable(id, name)
           and not (dur and (dur <= 0 or dur > RC.BUFF_MAX)) then
            here[name] = true
            local b = RC.buffs[name]
            if not b then
                b = { name = name, kind = "fade", gen = 0 }
                RC.buffs[name] = b
            end
            b.icon = Num(a.icon) or ns.Plain(a.icon) or b.icon
            if not b.present then                                      -- cast (again): a new one
                b.gen, b.present, b.readyAt = b.gen + 1, true, nil
            end
            if dur and ends and ends > 0 then
                if b.readyAt and ends > b.readyAt + 0.5 then b.gen = b.gen + 1 end    -- refreshed
                b.readyAt, b.dur = ends, dur
            end
        end
    end
    local dead = ns.Yes(UnitIsDeadOrGhost and UnitIsDeadOrGhost("player"))
    for name, b in pairs(RC.buffs) do
        if b.present and not here[name] then                           -- gone
            b.present = false
            if dead then b.calledGen = b.gen                           -- (not news when you died)
            elseif not b.readyAt or b.readyAt > now then b.readyAt = now end
        end
    end
end

local readIn = 0
place:SetScript("OnUpdate", ns.Protect(function(_, dt)
    if not RC.active then return end
    local now = GetTime()
    readIn = readIn - dt
    if readIn <= 0 then
        readIn = READ
        Read(now)
        if ns.db.soonBuffs then ReadBuffs(now) end
    end
    RC.Place()
    for _, t in ipairs(ns.db.soonCallouts and RC.track or {}) do
        local r = t.readyAt
        if r and t.dur and t.dur >= RC.MIN and r - RC.Early() - now <= RC.LEAD and r > now - READ * 2
           and t.calledGen ~= t.gen then
            Start(t)
        end
    end
    if ns.db.soonBuffs then
        for _, b in pairs(RC.buffs) do
            local r = b.readyAt
            if r and r - now <= RC.LEAD and r > now - READ * 2 and b.calledGen ~= b.gen then Start(b) end
        end
    end
    local calm = ns.Calm and ns.Calm()
    for i = #RC.live, 1, -1 do
        local c = RC.live[i]
        if c.gen == c.t.gen and not c.ready and c.t.readyAt then        -- its time put right: it moves with it
            c.readyAt = c.t.readyAt - (c.kind == "fade" and 0 or RC.Early())
        end
        local stale = c.gen ~= c.t.gen and not c.ready                 -- refreshed or cast again: not news
        if stale or not Look(c, now, calm) then
            c.w:Hide()
            spare[#spare + 1] = c.w
            table.remove(RC.live, i)
        end
    end
    Stack(dt, calm)
end))

local cast = CreateFrame("Frame")
cast:SetScript("OnEvent", ns.Protect(function(_, event, unit, _, spellID)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        if unit == "player" and not ns.IsSecret(spellID) then RC.Cast(spellID) end
    else
        RC.Learn()
    end
end))

-- What is watched (again, when your spells change), keeping what was learned of each
function RC.Learn()
    castable = {}
    local old = {}
    for _, t in ipairs(RC.track) do old[t.name] = t end
    RC.track = {}
    for _, s in ipairs(RC.Known()) do
        local t = old[s.name] or s
        t.icon = t.icon or s.icon
        if not t.dur and Kept(t.name) then t.dur, t.learnt = Kept(t.name), "kept" end
        RC.track[#RC.track + 1] = t
    end
end

function RC:Apply(run)
    local want = run and (ns.db.soonCallouts or ns.db.soonBuffs) and true or false
    if want and not self.active then
        self.active = true
        for _, e in ipairs({ "UNIT_SPELLCAST_SUCCEEDED", "SPELLS_CHANGED", "PLAYER_TALENT_UPDATE" }) do
            pcall(cast.RegisterEvent, cast, e)
        end
        RC.Learn()
        Read(GetTime())
        RC.buffs = {}
        ReadBuffs(GetTime())
        place:Show()
    elseif not want and self.active then
        self.active = false
        cast:UnregisterAllEvents()
        for _, c in ipairs(self.live) do c.w:Hide(); spare[#spare + 1] = c.w end
        self.live = {}
        place:Hide()
        self:SetUnlocked(false)
    elseif want then
        RC.Learn()
        for i = #self.live, 1, -1 do                                   -- what was switched off goes at once
            local c = self.live[i]
            if not (c.kind == "fade" and ns.db.soonBuffs or c.kind ~= "fade" and ns.db.soonCallouts) then
                c.w:Hide()
                spare[#spare + 1] = c.w
                table.remove(self.live, i)
            end
        end
    end
end

-- For the debug report
function RC.Describe()
    local out = { ("on: %s, at %s, %s"):format(tostring(RC.active), tostring(RC.x), tostring(RC.y)),
                  ("rows live: %d, called out: %d, pops %.2f s early"):format(#RC.live, RC.shown or 0, RC.Early()) }
    local now = GetTime()
    for _, t in ipairs(RC.track) do
        out[#out + 1] = ("%s (%s): cooldown %s (%s), ready %s, read %s, from %s"):format(t.name, tostring(t.id),
            t.dur and ("%.1f"):format(t.dur) or "?", tostring(t.learnt or "base"),
            t.readyAt and ("%+.1f s"):format(t.readyAt - now) or "now", tostring(t.src or "-"), tostring(t.from or "-"))
    end
    if #RC.track == 0 then out[#out + 1] = "none of your key abilities known" end
    for name, b in pairs(RC.buffs) do
        out[#out + 1] = ("buff %s: %s, runs out %s"):format(name, b.present and "on" or "gone",
            b.readyAt and ("%+.1f s"):format(b.readyAt - now) or "?")
    end
    return out
end
ns.RegisterModule("cooldowns callouts", RC)
