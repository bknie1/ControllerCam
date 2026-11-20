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
    elseif addon == ADDON and lastPinned and GetTime() - lastAt < 0.2
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
            t.y = math.max(-t.y0, math.min(t.y0, t.y + t.vy * dt))
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
            t:SetSize(size, size)
            t:ClearAllPoints()
            t:SetPoint("CENTER", t.layer, "LEFT", t.x, t.y)
            t:SetAlpha(a)
        end
    end
    if not any then fxDriver:SetScript("OnUpdate", nil) end
end
FxTick = ns.Protect(FxTick)

function IM:Burst(bar, p, mult)
    local fx = p.fx
    if not fx then return end
    local layer = Layer(bar)
    local w, h = bar:GetWidth() or 100, bar:GetHeight() or 8
    local fill = bar:GetFraction()
    local edge = fill and math.max(8, w * fill) or w * 0.5      -- where the hit landed: the end of the health
    for _ = 1, math.floor(fx.count * (mult or 1) + 0.5) do
        local t = table.remove(pool) or layer:CreateTexture(nil, "OVERLAY")
        if t:GetParent() ~= layer and t.SetParent then t:SetParent(layer) end
        t.layer, t.kind, t.age = layer, fx.kind, 0
        t.life = fx.life * (0.8 + math.random() * 0.4)
        t.size = fx.size * (0.7 + math.random() * 0.6)
        t:SetTexture(ns.media[fx.tex])
        t:SetBlendMode(DARK[fx.kind] and "BLEND" or "ADD")
        local c = p.color
        if DARK[fx.kind] then t:SetVertexColor(c[1] * 0.35, c[2] * 0.2, c[3] * 0.45, 1)
        else t:SetVertexColor(c[1], c[2], c[3], 1) end
        -- everything travels along the bar and rolls off its ends, staying level with it (never up into the
        -- name above): half go left, half right, from where the hit landed
        local dir = (math.random() < 0.5) and -1 or 1
        local jitter = math.random() * 2 - 1
        t.x = math.max(0, math.min(w, edge + jitter * 10))
        t.y = jitter * h * 0.35
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
-- A hit on a bar: { frame = (what shakes), anchor = (what it is pinned to), bar = (what flashes) }
---------------------------------------------------------------------------
function IM:Hit(target, school, crit)
    local p = self.PROFILES[school] or self.PROFILES.physical
    local mult = crit and CRIT or 1
    target.frame.lastImpact = GetTime()
    target.bar:Flash(crit and 0.5 or 0.15, p.color, p.fade)
    if ns.db.impactFx then self:Burst(target.bar, p, mult) end
    if p.twice then
        C_Timer.After(0.12, function() target.bar:Flash(0.2, p.color, p.fade) end)
    end
    self:Shake(target.frame, target.anchor, p, mult)
    self.last = { school = school, crit = crit and true or false }
end

-- Every bar of ours showing this unit (by GUID)
local function Targets(guid)
    local list = {}
    if not guid or ns.IsSecret(guid) then return list end
    local UF = ns.UnitFrames
    for _, key in ipairs({ "target", "focus" }) do
        local f = UF.frames[key]
        if f and f.on and ns.GUID(f.unit) == guid then
            list[#list + 1] = { frame = f.visual, anchor = f.button, bar = f.health }
        end
    end
    local plate = ns.Nameplates and ns.Nameplates.byGuid[guid]
    if plate and plate:IsShown() then
        list[#list + 1] = { frame = plate, anchor = plate.plate, bar = plate.health }
    end
    return list
end
IM.Targets = Targets

local lastLanded = {}
local function Land(guid, school, crit)
    if not guid or ns.IsSecret(guid) then return end
    local now = GetTime()
    if lastLanded[guid] and now - lastLanded[guid] < 0.05 then return end     -- heard twice (log and unit event)
    lastLanded[guid] = now
    for _, t in ipairs(Targets(guid)) do
        IM:Hit(t, school, crit)
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

-- Every spell's school, as the log tells it (a cast starting, a hit, a heal; yours or anyone's): cast bars
-- take their colour and their effects from it
IM.SCHOOL_OF = {}
IM.HEAL_OF = {}                  -- and which spells heal: their casts grow vines and flowers
local learned = 0
local function Learn(sub, spellID, mask)
    if type(sub) ~= "string" or sub:sub(1, 6) ~= "SPELL_" then return end
    if ns.IsSecret(spellID) or ns.IsSecret(mask) or type(spellID) ~= "number" or type(mask) ~= "number" then return end
    if sub == "SPELL_HEAL" or sub == "SPELL_PERIODIC_HEAL" then IM.HEAL_OF[spellID] = true end
    if IM.SCHOOL_OF[spellID] then return end
    if learned > 2000 then IM.SCHOOL_OF, IM.HEAL_OF, learned = {}, {}, 0 end
    if mask >= 128 then ns.Note("school %d of spell %d is not one we know", mask, spellID) end
    IM.SCHOOL_OF[spellID] = IM.School(mask)
    learned = learned + 1
end

local function FromLog()
    IM.heard = IM.heard + 1
    local info = LogInfo()
    local e = { info() }
    local sub, sourceGUID, destGUID = e[2], e[4], e[8]
    Learn(sub, e[12], e[14])
    if sub == "SPELL_AURA_APPLIED" or sub == "SPELL_AURA_REFRESH" or sub == "SPELL_AURA_REMOVED" then
        if ns.Bloom then ns.Bloom.FromLog(sub, destGUID, e[12]) end      -- heals over time growing on a bar
        if ns.Ward then ns.Ward.FromLog(sub, destGUID, e[12]) end        -- shields round a bar
        return
    end
    if sub == "SPELL_HEAL" or sub == "SPELL_PERIODIC_HEAL" then
        HealLand(e[8], IM.School(e[14]))
        return
    end
    if sub == "SPELL_EXTRA_ATTACKS" and sourceGUID == ns.GUID("player") and ns.Moments then
        ns.Moments.ExtraAttack(e[12], e[13])                         -- Windfury and the like: the next swing is it
    end
    local at = DAMAGE[sub]
    if not at then return end
    if sourceGUID ~= ns.GUID("player") and sourceGUID ~= ns.GUID("pet") then return end
    local crit = e[at + 6]
    if ns.IsSecret(crit) then crit = false end
    if ns.Moments and sourceGUID == ns.GUID("player") then                -- your key abilities, felt
        if sub == "SWING_DAMAGE" then ns.Moments.Swing(e[12], crit)
        elseif sub == "SPELL_DAMAGE" then ns.Moments.FromLog(e[12], e[13], e[15], crit, e[14]) end
    end
    Land(destGUID, IM.School(e[14]), crit and true or false)
end

-- Without the combat log: the game's hit event for a unit (any attacker). The amount may be secret: a hit
-- is a hit.
-- Your last finished cast: the hit or heal that follows it within a moment tells its school, for clients
-- whose combat log addons cannot read
local lastCast
function IM.NoteCast(spellID)
    if ns.IsSecret(spellID) or type(spellID) ~= "number" then return end
    lastCast = { id = spellID, at = GetTime() }
end
local function LearnFromHit(mask)
    if not lastCast or GetTime() - lastCast.at > 1.0 then return end
    if ns.IsSecret(mask) or type(mask) ~= "number" or mask <= 1 then return end    -- physical says nothing
    if not IM.SCHOOL_OF[lastCast.id] then IM.SCHOOL_OF[lastCast.id] = IM.School(mask) end
    lastCast = nil
end

local function FromUnit(unit, action, flag, amount, mask)
    IM.heard = IM.heard + 1
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
    Land(ns.GUID(unit), school, crit)
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
            (IM.source or "neither the combat log nor UNIT_COMBAT") .. (", %d heard, %d shown"):format(IM.heard, IM.landed))
    end
end)

-- /cchud hittest: every school once, on your target, focus and the nameplates on screen
ns.RegisterCommand("hittest", function()
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
    if #list == 0 then ns.Say(L["Target something first."]); return end
    for i, entry in ipairs(IM.ORDER) do
        C_Timer.After((i - 1) * 0.6, function()
            for _, t in ipairs(list) do IM:Hit(t, entry[2], i == #IM.ORDER) end
        end)
    end
    ns.Say(L["Showing every damage school once (the last one as a crit)."])
end, "/cchud hittest", "show every damage school's hit effect once on your target and the nameplates")

ns.RegisterModule("impact", IM)
