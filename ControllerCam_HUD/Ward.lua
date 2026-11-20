-- ControllerCam HUD: shields you can see.
-- A shield is cast in an instant, so there is nothing of it on a cast bar. Instead it shows where it sits: a
-- ward round the health bar of whoever is shielded (your target, your focus, you). It flares when the shield
-- lands, glows quietly while the shield holds, and fades when it breaks or runs out. Its colour is its
-- school's: gold for the holy shields (Power Word: Shield, Divine Shield, Blessing of Protection...), pale
-- blue for Ice Barrier, violet for Mana Shield, and so on.
-- What is known: an effect the game lets us read, the combat log, and the shield casts we see (yours and your
-- group's), each with the usual length of that spell.

local ADDON, ns = ...

local W = { active = false, shields = {}, frames = {} }
ns.Ward = W

ns.RegisterSetting({
    key = "wards", kind = "boolean", default = true, command = "wards", section = "Effects",
    label = "Shields show as a ward",
    tip = "a shield on your target, your focus or you (Power Word: Shield, Divine Shield, Ice Barrier...) flares round the health bar in its school's colour, glows while the shield holds, and fades when it breaks",
})

-- Shields, by one rank each: school, usual length (seconds), and whether it only ever sits on its caster
W.SHIELDS = {
    [17]    = { "holy", 30 },             -- Power Word: Shield
    [47753] = { "holy", 12 },             -- Divine Aegis
    [1022]  = { "holy", 10 },             -- Blessing (Hand) of Protection
    [642]   = { "holy", 12, true },       -- Divine Shield
    [498]   = { "holy", 12, true },       -- Divine Protection
    [11426] = { "frost", 60, true },      -- Ice Barrier
    [45438] = { "frost", 10, true },      -- Ice Block
    [6143]  = { "frost", 30, true },      -- Frost Ward
    [543]   = { "fire", 30, true },       -- Fire Ward
    [1463]  = { "arcane", 60, true },     -- Mana Shield
    [6229]  = { "shadow", 30, true },     -- Shadow Ward
    [7812]  = { "shadow", 30 },           -- Sacrifice (a voidwalker's, on its master)
}
W.COLOR = { holy = { 1, 0.84, 0.42 }, frost = { 0.6, 0.86, 1 }, fire = { 1, 0.55, 0.25 }, arcane = { 0.78, 0.6, 1 },
            shadow = { 0.66, 0.5, 0.9 } }

local byName
local function ShieldOf(spellID, name)
    if spellID and not ns.IsSecret(spellID) and W.SHIELDS[spellID] then return W.SHIELDS[spellID] end
    local get = (C_Spell and C_Spell.GetSpellName) or GetSpellInfo
    if type(name) ~= "string" or ns.IsSecret(name) then
        if not (get and spellID) or ns.IsSecret(spellID) then return nil end
        local ok, n = pcall(get, spellID)
        name = ok and n or nil
        if type(name) ~= "string" or ns.IsSecret(name) then return nil end
    end
    if not byName then                                  -- other ranks share the name
        byName = {}
        for id, shield in pairs(W.SHIELDS) do
            local ok, n = pcall(get, id)
            if ok and type(n) == "string" and not ns.IsSecret(n) then byName[n] = shield end
        end
    end
    return byName[name]
end
W.ShieldOf = ShieldOf

---------------------------------------------------------------------------
-- Who is shielded, by which school, until when
---------------------------------------------------------------------------
local function Note(guid, shield, ends, fromAura)
    if not guid or ns.IsSecret(guid) then return end
    local old = W.shields[guid]
    W.shields[guid] = { school = shield[1], ends = ends or (GetTime() + shield[2]), fromAura = fromAura,
                        at = (old and fromAura and old.at) or GetTime() }
    W:Wake()
end

local function Drop(guid)
    if W.shields[guid] then
        W.shields[guid] = nil
        W:Wake()
    end
end

-- A cast that put one on someone (we only see casts: its target is the caster's target, or the caster)
local function FromCast(caster, spellID)
    local shield = ShieldOf(spellID)
    if not shield then return end
    local dest = caster
    if not shield[3] then
        local t = caster == "player" and "target" or (caster .. "target")
        local okA, hostile = pcall(UnitCanAttack, caster, t)
        if UnitExists(t) and not (okA and hostile and not ns.IsSecret(hostile)) then dest = t end
        if caster == "player" and W.sentTo and UnitExists(W.sentTo) then dest = W.sentTo end
    end
    Note(ns.GUID(dest), shield)
end

-- What the game lets us read on a unit: its effects, when they are not secret
local function FromAuras(unit)
    if not (C_UnitAuras and C_UnitAuras.GetUnitAuras) then return end
    local ok, list = pcall(C_UnitAuras.GetUnitAuras, unit, "HELPFUL")
    if not ok or type(list) ~= "table" then return end
    local guid = ns.GUID(unit)
    if not guid or ns.IsSecret(guid) then return end
    local found, ends
    for _, a in ipairs(list) do
        local id = a.spellId
        if ns.IsSecret(id) then return end              -- secret: what we saw cast stands
        local shield = ShieldOf(id, a.name)
        if shield then
            local left = a.expirationTime
            found = shield
            ends = (not ns.IsSecret(left) and type(left) == "number" and left > 0) and left or nil
            break
        end
    end
    if found then
        Note(guid, found, ends, true)
    elseif W.shields[guid] and W.shields[guid].fromAura then    -- it was read before and is gone now
        Drop(guid)
    end
end

-- The combat log, where addons may read it: exactly when one lands and when it is gone
function W.FromLog(sub, destGUID, spellID)
    if not W.active or destGUID == nil or ns.IsSecret(destGUID) then return end
    local shield = ShieldOf(spellID)
    if not shield then return end
    if sub == "SPELL_AURA_APPLIED" or sub == "SPELL_AURA_REFRESH" then Note(destGUID, shield)
    elseif sub == "SPELL_AURA_REMOVED" then Drop(destGUID) end
end

function W.On(unit)
    local guid = ns.GUID(unit)
    if not guid or ns.IsSecret(guid) then return nil end
    local s = W.shields[guid]
    if s and GetTime() < s.ends then return s end
    if s then W.shields[guid] = nil end
end

---------------------------------------------------------------------------
-- The ward round a bar
---------------------------------------------------------------------------
local RISE, FADE, FLARE = 0.25, 0.4, 0.55

local function Parts(f)
    local v = W.frames[f]
    if v then return v end
    v = { a = 0, flare = 0 }
    v.glow = f.visual:CreateTexture(nil, "OVERLAY", nil, 1)
    v.glow:SetTexture(ns.media.soft)
    v.glow:SetBlendMode("ADD")
    v.top = f.visual:CreateTexture(nil, "OVERLAY", nil, 3)
    v.bottom = f.visual:CreateTexture(nil, "OVERLAY", nil, 3)
    for _, edge in ipairs({ v.top, v.bottom }) do
        edge:SetColorTexture(1, 1, 1, 1)
        edge:SetBlendMode("ADD")
        edge:SetHeight(1.5)
    end
    v.top:SetPoint("BOTTOMLEFT", f.health, "TOPLEFT", -2, 1)
    v.top:SetPoint("BOTTOMRIGHT", f.health, "TOPRIGHT", 2, 1)
    v.bottom:SetPoint("TOPLEFT", f.health, "BOTTOMLEFT", -2, -1)
    v.bottom:SetPoint("TOPRIGHT", f.health, "BOTTOMRIGHT", 2, -1)
    v.glow:Hide(); v.top:Hide(); v.bottom:Hide()
    W.frames[f] = v
    return v
end

local function Draw(f, v, now)
    if v.a <= 0.001 and v.flare <= 0.001 then
        v.glow:Hide(); v.top:Hide(); v.bottom:Hide()
        return
    end
    local c = W.COLOR[v.school or "holy"] or W.COLOR.holy
    local breath = math.sin(now * 3)
    local out = 10 + 14 * v.flare                       -- the flare reaches out, then settles on the bar
    v.glow:ClearAllPoints()
    v.glow:SetPoint("TOPLEFT", f.health, "TOPLEFT", -out, out * 0.8)
    v.glow:SetPoint("BOTTOMRIGHT", f.health, "BOTTOMRIGHT", out, -out * 0.8)
    v.glow:SetVertexColor(c[1], c[2], c[3], 1)
    v.glow:SetAlpha(ns.Clamp((0.3 + 0.1 * breath) * v.a + 0.6 * v.flare, 0, 1))
    v.glow:Show()
    for _, edge in ipairs({ v.top, v.bottom }) do
        edge:SetVertexColor(c[1], c[2], c[3], 1)
        edge:SetAlpha(ns.Clamp((0.6 + 0.15 * breath) * v.a + 0.4 * v.flare, 0, 1))
        edge:Show()
    end
end

local KEYS = { "target", "focus", "player" }
local driver = CreateFrame("Frame")
local function Tick(_, dt)
    local any, now = false, GetTime()
    local UF = ns.UnitFrames
    for _, key in ipairs(KEYS) do
        local f = UF and UF.frames[key]
        if f and f.on and f.health then
            local shield = ns.db.wards and W.active and W.On(f.unit)
            local v = W.frames[f] or (shield and Parts(f))
            if v then
                if shield then
                    if v.at ~= shield.at then           -- a shield just landed here (or another unit's is shown now)
                        v.at, v.flare = shield.at, (now - shield.at < 0.3) and 1 or 0
                    end
                    v.school = shield.school
                    v.a = math.min(1, v.a + dt / RISE)
                else
                    v.at = nil
                    v.a = math.max(0, v.a - dt / FADE)
                end
                v.flare = math.max(0, v.flare - dt / FLARE)
                Draw(f, v, now)
                if shield or v.a > 0 or v.flare > 0 then any = true end
            end
        end
    end
    if not any then driver:SetScript("OnUpdate", nil) end
end
Tick = ns.Protect(Tick)

function W:Wake() driver:SetScript("OnUpdate", Tick) end

---------------------------------------------------------------------------
-- Listening
---------------------------------------------------------------------------
local events = CreateFrame("Frame")
events:SetScript("OnEvent", ns.Protect(function(_, event, unit, a2, a3)
    if event == "UNIT_SPELLCAST_SENT" then                 -- yours: the game says who it is for
        if unit == "player" then
            W.sentTo = nil
            if type(a2) == "string" and not ns.IsSecret(a2) and a2 ~= "" then
                for _, u in ipairs({ "target", "focus", "player", "mouseover" }) do
                    if UnitExists(u) and ns.Plain(UnitName(u)) == a2 then W.sentTo = u; break end
                end
            end
        end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if unit == "player" or unit:find("^party") or unit:find("^raid") then FromCast(unit, a3) end
    elseif event == "UNIT_AURA" then
        if unit == "target" or unit == "focus" or unit == "player" then FromAuras(unit); W:Wake() end
    elseif event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED" then
        FromAuras(event == "PLAYER_TARGET_CHANGED" and "target" or "focus")
        W:Wake()
    end
end))

function W:Apply(run)
    local want = run and ns.db.wards and true or false
    if want == self.active then return end
    self.active = want
    if want then
        for _, e in ipairs({ "UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_AURA", "PLAYER_TARGET_CHANGED",
                             "PLAYER_FOCUS_CHANGED" }) do
            pcall(events.RegisterEvent, events, e)
        end
    else
        events:UnregisterAllEvents()
        for _, v in pairs(self.frames) do
            v.a, v.flare, v.at = 0, 0, nil
            v.glow:Hide(); v.top:Hide(); v.bottom:Hide()
        end
        self.shields = {}
    end
end

ns.RegisterModule("ward", W)
