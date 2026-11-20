-- ControllerCam HUD: feel what happens.
-- The controller rumbles for the moments worth feeling, each with its own pattern:
--   getting hit    a thud (a heavy one for a big hit or a crit)
--   your crits     a sharp tick in the right trigger
--   interrupts     a double knock when your target's cast is cut off
--   low health     a heartbeat while you are in a fight
--   aggro          a pulse when an enemy turns on you
--   alerts         a ready check or a dungeon invitation (urgent); a whisper (light)
--   level up       a swell; death a long low rumble
-- The game's own vibration setting comes first: at zero, nothing rumbles. A stronger pattern is never cut off by
-- a weaker one. The light bar of a controller that has one (DualSense) can show your health: green when full,
-- through yellow to red, pulsing red when you are low in a fight. /cchud rumbletest plays every pattern once.

local ADDON, ns = ...
local L = ns.L

local R = { active = false, last = nil }
ns.Rumble = R

local function Setting(key, label, tip, default)
    ns.RegisterSetting({ key = key, kind = "boolean", default = default, command = key:lower(), section = "Effects",
                         label = label, tip = tip })
end
Setting("rumble", "Controller vibration", "the controller rumbles for the moments worth feeling (the game's own vibration strength comes first)", true)
ns.RegisterSetting({
    key = "rumbleStrength", kind = "number", default = 1, min = 0.2, max = 1.5, percent = true,
    command = "rumblestrength", section = "Effects", label = "Vibration strength",
    tip = "how strong our patterns are, on top of the game's own vibration setting",
})
Setting("rumbleHits", "Rumble: hits you take", "a thud when you are hit, heavier for a big hit or a crit", true)
Setting("rumbleCrits", "Rumble: your crits", "a sharp tick in the right trigger when you land a crit", true)
Setting("rumbleInterrupts", "Rumble: interrupts", "a double knock when your target's cast is cut off", true)
Setting("rumbleLowHealth", "Rumble: low health", "a heartbeat while you are low on health in a fight", true)
Setting("rumbleAggro", "Rumble: aggro", "a pulse when your target turns on you", true)
Setting("rumbleAlerts", "Rumble: alerts", "a ready check, a dungeon invitation or a whisper", true)
Setting("rumbleSeals", "Rumble: seals charge up", "a quick rising rumble that snaps in the right trigger when you put on a seal", true)
Setting("rumbleCasts", "Rumble: casts build up", "while you cast a spell with a cast time, the rumble builds with the cast bar and snaps when it lands", false)
Setting("rumbleLevel", "Rumble: level up and death", "a swell when you level up, a long low rumble when you die", true)
Setting("lightBar", "Light bar shows your health", "a controller with a light bar (DualSense) shows your health in it: green to red, pulsing when low in a fight", true)

---------------------------------------------------------------------------
-- Patterns: steps of { motor, intensity, seconds } or { gap = seconds }. priority: who may cut in.
---------------------------------------------------------------------------
local function Pulse(motor, intensity, seconds) return { motor, intensity, seconds } end
R.PATTERNS = {
    hit       = { priority = 2, Pulse("Low", 0.45, 0.10) },
    bighit    = { priority = 4, Pulse("High", 0.85, 0.12), Pulse("Low", 0.7, 0.16) },
    crit      = { priority = 1, Pulse("RTrigger", 0.7, 0.07) },
    interrupt = { priority = 3, Pulse("High", 0.7, 0.06), { gap = 0.07 }, Pulse("High", 0.7, 0.06) },
    heartbeat = { priority = 3, Pulse("Low", 0.6, 0.08), { gap = 0.12 }, Pulse("Low", 0.35, 0.08) },
    aggro     = { priority = 2, Pulse("LTrigger", 0.5, 0.08), Pulse("Low", 0.4, 0.12) },
    alert     = { priority = 5, Pulse("High", 0.6, 0.1), { gap = 0.1 }, Pulse("High", 0.6, 0.1), { gap = 0.1 },
                  Pulse("High", 0.6, 0.1) },
    whisper   = { priority = 1, Pulse("High", 0.3, 0.06) },
    charge    = { priority = 2, Pulse("Low", 0.15, 0.06), Pulse("Low", 0.3, 0.06), Pulse("Low", 0.5, 0.07),
                  Pulse("High", 0.75, 0.07), Pulse("RTrigger", 0.95, 0.07) },
    snap      = { priority = 2, Pulse("RTrigger", 0.85, 0.06), Pulse("High", 0.5, 0.05) },
    -- key abilities (Moments.lua): a splash hits hard then ripples out; a strike snaps and stops dead;
    -- Windfury knocks three times fast; a big moment lands like a bell
    splash    = { priority = 3, Pulse("High", 1, 0.07), Pulse("Low", 0.85, 0.12), Pulse("Low", 0.5, 0.1),
                  Pulse("Low", 0.25, 0.1) },
    strike    = { priority = 3, Pulse("RTrigger", 1, 0.045), Pulse("High", 0.95, 0.05) },
    windfury  = { priority = 3, Pulse("High", 0.65, 0.04), { gap = 0.035 }, Pulse("High", 0.75, 0.04), { gap = 0.035 },
                  Pulse("High", 0.9, 0.05) },
    moment    = { priority = 5, Pulse("RTrigger", 1, 0.05), Pulse("High", 1, 0.09), Pulse("Low", 1, 0.18),
                  Pulse("Low", 0.6, 0.15), Pulse("Low", 0.3, 0.15) },
    level     = { priority = 5, Pulse("Low", 0.4, 0.15), Pulse("Low", 0.7, 0.2), Pulse("High", 0.9, 0.25) },
    death     = { priority = 6, Pulse("Low", 1, 0.7) },
}
R.ORDER = { "hit", "bighit", "crit", "interrupt", "heartbeat", "aggro", "charge", "snap", "splash", "strike",
            "windfury", "moment", "alert", "whisper", "level", "death" }

-- Seals, by one rank each (every rank shares the name, in your language too)
R.SEALS = { 20154, 21084, 21082, 20165, 20166, 20375, 20164, 31801, 31892, 53736, 20925 }
local sealNames
local function IsSeal(spellID)
    if ns.IsSecret(spellID) or type(spellID) ~= "number" then return false end
    local get = (C_Spell and C_Spell.GetSpellName) or GetSpellInfo
    if not get then return false end
    if not sealNames then
        sealNames = {}
        for _, id in ipairs(R.SEALS) do
            local ok, n = pcall(get, id)
            if ok and type(n) == "string" and not ns.IsSecret(n) then sealNames[n] = true end
        end
    end
    local ok, name = pcall(get, spellID)
    return ok and type(name) == "string" and not ns.IsSecret(name) and sealNames[name] or false
end
R.IsSeal = IsSeal


-- The game's own vibration strength: nothing when it is off
local function GameAllows()
    if not (C_GamePad and C_GamePad.SetVibration) then return false end
    local v = GetCVar and GetCVar("GamePadVibrationStrength")
    return v == nil or (tonumber(v) or 1) > 0
end

local function Motor(motor, intensity)
    local ok = pcall(C_GamePad.SetVibration, motor, intensity)
    if not ok and (motor == "LTrigger" or motor == "RTrigger") then      -- no trigger motors here: the body
        pcall(C_GamePad.SetVibration, "High", intensity)
    end
end

local function Stop() if C_GamePad and C_GamePad.StopVibration then pcall(C_GamePad.StopVibration) end end

function R:Play(name, scale)
    if not (self.active and ns.db.rumble and GameAllows()) then return false end
    local p = self.PATTERNS[name]
    if not p then return false end
    local now = GetTime()
    if self.busyUntil and now < self.busyUntil and (self.busyPriority or 0) > p.priority then return false end
    self.gen = (self.gen or 0) + 1
    local gen, t = self.gen, 0
    local k = (scale or 1) * (ns.db.rumbleStrength or 1)
    for _, step in ipairs(p) do
        if step.gap then
            C_Timer.After(t, function() if gen == R.gen then Stop() end end)
            t = t + step.gap
        else
            local motor, intensity = step[1], math.min(1, step[2] * k)
            C_Timer.After(t, function() if gen == R.gen then Motor(motor, intensity) end end)
            t = t + step[3]
        end
    end
    C_Timer.After(t, function() if gen == R.gen then Stop() end end)
    self.busyUntil, self.busyPriority, self.last = now + t, p.priority, name
    self.played = (self.played or 0) + 1
    return true
end

---------------------------------------------------------------------------
-- A cast building up (CastBar.lua tells us how far along it is): the rumble grows with it, in a few steps, and
-- gives way to anything stronger
---------------------------------------------------------------------------
function R:Build(p)
    if not (self.active and ns.db.rumble and ns.db.rumbleCasts and GameAllows()) then return end
    if self.busyUntil and GetTime() < self.busyUntil then return end          -- a pattern is playing
    local level = math.floor(p * 5) / 5                                          -- five steps, not every frame
    if level == self.building then return end
    self.building = level
    if level <= 0 then return end
    Motor("Low", math.min(1, (0.08 + 0.45 * level * level) * (ns.db.rumbleStrength or 1)))
end

function R:BuildEnd(landed)
    if self.building == nil then return end
    self.building = nil
    Stop()
    if landed and ns.db.rumbleCasts then self:Play("snap") end
end

---------------------------------------------------------------------------
-- What sets it off
---------------------------------------------------------------------------
local function Plain(v) if ns.IsSecret(v) then return nil end return v end
local lastHit = 0

local function OnHit(amount, flag)
    if not ns.db.rumbleHits then return end
    local now = GetTime()
    if now - lastHit < 0.15 then return end
    lastHit = now
    local crit = Plain(flag) == "CRITICAL"
    local share
    amount = Plain(amount)
    local max = Plain(UnitHealthMax("player"))
    if type(amount) == "number" and type(max) == "number" and max > 0 then share = amount / max end
    if crit or (share and share >= 0.15) then
        R:Play("bighit")
    else
        R:Play("hit", share and math.max(0.6, math.min(1.3, 0.6 + share * 6)) or 1)
    end
end

-- Your crits (Impact.lua tells us when a hit of yours lands as a crit)
function R:Crit()
    if ns.db.rumbleCrits then self:Play("crit") end
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", ns.Protect(function(_, event, unit, action, flag, amount)
    local db = ns.db
    if event == "UNIT_COMBAT" then
        if unit == "player" and Plain(action) == "WOUND" then OnHit(amount, flag) end
    elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
        if unit == "target" and db.rumbleInterrupts then R:Play("interrupt") end
    elseif event == "READY_CHECK" or event == "LFG_PROPOSAL_SHOW" or event == "PVPQUEUE_ANYWHERE_SHOW" then
        if db.rumbleAlerts then R:Play("alert") end
    elseif event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_BN_WHISPER" then
        if db.rumbleAlerts then R:Play("whisper") end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if unit == "player" and db.rumbleSeals and IsSeal(flag) then R:Play("charge") end
    elseif event == "PLAYER_LEVEL_UP" then
        if db.rumbleLevel then R:Play("level") end
    elseif event == "PLAYER_DEAD" then
        if db.rumbleLevel then R:Play("death") end
    end
end))

-- A few times a second: the heartbeat, aggro turning on you, and the light bar
local since, beatAt, wasMax = 0, 0, false
local function Health()
    local cur, max = Plain(UnitHealth("player")), Plain(UnitHealthMax("player"))
    if type(cur) == "number" and type(max) == "number" and max > 0 then return cur / max end
end

local function Light(frac, combat)
    if not (ns.db.lightBar and C_GamePad and C_GamePad.SetLedColor and CreateColor) then
        if R.lit then R:ClearLight() end
        return
    end
    if not frac then return end
    local r, g, b
    if frac > 0.5 then r, g, b = (1 - frac) * 2, 1, 0.1 else r, g, b = 1, frac * 2, 0.1 end
    if combat and frac < 0.3 then                                         -- low in a fight: pulse
        local k = 0.45 + 0.55 * math.abs(math.sin(GetTime() * 4))
        r, g, b = r * k, g * k, b * k
    end
    local key = ("%.2f%.2f%.2f"):format(r, g, b)
    if key == R.lit then return end
    R.lit = key
    pcall(C_GamePad.SetLedColor, CreateColor(r, g, b))
end

function R:ClearLight()
    self.lit = nil
    if C_GamePad and C_GamePad.ClearLedColor then pcall(C_GamePad.ClearLedColor) end
end

local ticker = CreateFrame("Frame")
ticker:Hide()                                      -- runs only while the HUD does
ticker:SetScript("OnUpdate", ns.Protect(function(_, dt)
    since = since + dt
    if since < 0.1 then return end
    since = 0
    local db = ns.db
    local combat = UnitAffectingCombat("player") and true or false
    local frac = Health()
    Light(frac, combat)
    local now = GetTime()
    if db.rumbleLowHealth and combat and frac and frac > 0 and frac < 0.3 and now >= beatAt then
        beatAt = now + 1.1 - (0.3 - frac) * 1.5                          -- faster as it gets worse
        R:Play("heartbeat", 0.8 + (0.3 - frac) * 1.5)
    end
    local max = ns.UnitFrames and ns.UnitFrames.threatState == "max"
    if max and not wasMax and db.rumbleAggro then R:Play("aggro") end
    wasMax = max and true or false
end))

function R:Apply(run)
    local want = run and true or false
    if want == self.active then return end
    self.active = want
    if want then
        for _, e in ipairs({ "UNIT_COMBAT", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_SUCCEEDED", "READY_CHECK", "LFG_PROPOSAL_SHOW",
                             "PVPQUEUE_ANYWHERE_SHOW", "CHAT_MSG_WHISPER", "CHAT_MSG_BN_WHISPER", "PLAYER_LEVEL_UP",
                             "PLAYER_DEAD" }) do
            pcall(events.RegisterEvent, events, e)
        end
        ticker:Show()
    else
        events:UnregisterAllEvents()
        ticker:Hide()
        Stop()
        if self.lit then self:ClearLight() end
    end
end

ns.RegisterCommand("rumbletest", function()
    if not GameAllows() then ns.Say(L["The game's vibration is off (or this controller cannot rumble)."]); return end
    local saved = R.busyUntil
    for i, name in ipairs(R.ORDER) do
        C_Timer.After((i - 1) * 0.9, function() R.busyUntil = nil; R:Play(name) end)
    end
    R.busyUntil = saved
    ns.Say(L["Playing every vibration pattern once."])
end, "/cchud rumbletest", "play every vibration pattern once")

ns.RegisterCheck(function(row, run, db)
    if run and db.rumble then
        row("the controller can rumble", C_GamePad ~= nil and C_GamePad.SetVibration ~= nil,
            GameAllows() and "on" or "the game's vibration is off")
    end
end)

ns.RegisterModule("rumble", R)
