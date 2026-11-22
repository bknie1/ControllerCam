-- ControllerCam HUD: healing you can see coming, and healing that stays.
--   * The heal on its way to a unit (the lighter part ahead of its health) takes the colour of the heal being
--     cast at it: holy gold, nature green... (yours, or a group member's aimed at it).
--   * A heal over time on your target, focus or you grows over its bar: roots and branches for nature
--     (Rejuvenation, Regrowth, Lifebloom...), golden threads for holy (Renew). They sway while it lasts and
--     wither away when it ends.
-- What is known: an effect the game lets us read, the combat log, and the heal-over-time casts we see (yours
-- and your group's), each with the usual length of that spell.

local ADDON, ns = ...
local C = ns.colors

local B = { active = false, hots = {}, frames = {} }
ns.Bloom = B

ns.RegisterSetting({
    key = "healColors", kind = "boolean", default = true, command = "healcolors", section = "Effects",
    label = "Incoming heals in their school's colour",
    tip = "the heal on its way to a unit shows the colour of the heal being cast at it: holy gold, nature green",
})
ns.RegisterSetting({
    key = "hotVines", kind = "boolean", default = true, command = "hotvines", section = "Effects",
    label = "Heals over time grow on the bar",
    tip = "roots and branches (nature) or golden threads (holy) grow over the bar of your target, focus or you while a heal over time lasts, and wither when it ends",
})

-- Heals over time, by one rank each: school and usual length (seconds)
B.HOTS = {
    [139] = { "holy", 15 },       -- Renew
    [774] = { "nature", 12 },     -- Rejuvenation
    [8936] = { "nature", 21 },    -- Regrowth
    [33763] = { "nature", 7 },    -- Lifebloom
    [48438] = { "nature", 7 },    -- Wild Growth
    [61295] = { "nature", 18 },   -- Riptide
    [5420] = { "nature", 30 },    -- Tree of Life aura (some clients)
}
B.LOOK = {
    nature = { color = { 0.45, 0.82, 0.32 }, tex = "vines" },
    holy = { color = { 1, 0.84, 0.42 }, tex = "vines" },
}

local byName
local function HotOf(spellID, name)
    if spellID and not ns.IsSecret(spellID) and B.HOTS[spellID] then return B.HOTS[spellID] end
    if type(name) ~= "string" or ns.IsSecret(name) then
        local get = (C_Spell and C_Spell.GetSpellName) or GetSpellInfo
        if not (get and spellID) or ns.IsSecret(spellID) then return nil end
        local ok, n = pcall(get, spellID)
        name = ok and n or nil
        if type(name) ~= "string" or ns.IsSecret(name) then return nil end
    end
    if not byName then
        byName = {}
        local get = (C_Spell and C_Spell.GetSpellName) or GetSpellInfo
        for id, hot in pairs(B.HOTS) do
            local ok, n = pcall(get, id)
            if ok and type(n) == "string" and not ns.IsSecret(n) then byName[n] = hot end
        end
    end
    return byName[name]
end
B.HotOf = HotOf

---------------------------------------------------------------------------
-- The heal on its way: whose, and of which school
---------------------------------------------------------------------------
local GROUP = {}
for i = 1, 4 do GROUP[#GROUP + 1] = "party" .. i end
for i = 1, 40 do GROUP[#GROUP + 1] = "raid" .. i end

local function SchoolOfCast(caster)
    local name, spellID = ns.CastLook.Casting(caster)
    if not name then return nil end
    return ns.CastLook.SchoolOf(name, spellID)
end

local function TargetOf(caster) return caster == "player" and "target" or (caster .. "target") end

local function Aimed(caster, unit)
    local t = TargetOf(caster)
    local ok, same = pcall(UnitIsUnit, t, unit)
    if ok and ns.Yes(same) then
        local okA, hostile = pcall(UnitCanAttack, caster, t)
        if not (okA and ns.Yes(hostile)) then return true end
    end
    -- a heal cast with a hostile (or no) target lands on the caster
    if ns.Yes(UnitIsUnit(caster, unit)) then
        local okA, hostile = pcall(UnitCanAttack, caster, t)
        if not UnitExists(t) or (okA and ns.Yes(hostile)) then return true end
    end
    return false
end

function B.IncomingColor(unit)
    if not (B.active and ns.db.healColors) then return nil end
    local IM = ns.Impact
    local school
    for _, caster in ipairs({ "player", unpack(GROUP) }) do
        if UnitExists(caster) then
            local s = SchoolOfCast(caster)
            if s and s ~= "physical" and Aimed(caster, unit) then school = s; break end
        end
    end
    local p = school and IM and IM.PROFILES[school]
    return p and p.color or nil
end

---------------------------------------------------------------------------
-- Heals over time: who has one, of which school, until when
---------------------------------------------------------------------------
local function Note(guid, hot)
    if not guid or ns.IsSecret(guid) then return end
    B.hots[guid] = { school = hot[1], ends = GetTime() + hot[2] }
    B:Wake()
end

-- A cast that put one on someone (we only see casts: its target is the caster's target, or the caster)
local function FromCast(caster, spellID)
    local hot = HotOf(spellID)
    if not hot then return end
    local dest = TargetOf(caster)
    local okA, hostile = pcall(UnitCanAttack, caster, dest)
    if not UnitExists(dest) or (okA and ns.Yes(hostile)) then dest = caster end
    if caster == "player" and B.sentTo and UnitExists(B.sentTo) then dest = B.sentTo end
    Note(ns.GUID(dest), hot)
end

-- What the game lets us read on a unit: its effects, when they are not secret
local function FromAuras(unit)
    if not (C_UnitAuras and C_UnitAuras.GetUnitAuras) then return end
    local ok, list = pcall(C_UnitAuras.GetUnitAuras, unit, "HELPFUL")
    if not ok or type(list) ~= "table" then return end
    local guid = ns.GUID(unit)
    if not guid or ns.IsSecret(guid) then return end
    local found
    for _, a in ipairs(list) do
        local id = a.spellId
        if not ns.IsSecret(id) then
            local hot = HotOf(id, a.name)
            if hot then
                local left = a.expirationTime
                local ends = (not ns.IsSecret(left) and type(left) == "number" and left > 0) and left or (GetTime() + hot[2])
                found = { school = hot[1], ends = ends }
                break
            end
        elseif ns.IsSecret(id) then
            return                                -- secret: what we saw cast stands
        end
    end
    if found then
        found.fromAura = true
        B.hots[guid] = found
        B:Wake()
    elseif B.hots[guid] and B.hots[guid].fromAura then        -- it was read before and is gone now
        B.hots[guid] = nil
        B:Wake()
    end
end

-- The combat log, where addons may read it: exactly when one starts and ends
function B.FromLog(sub, destGUID, spellID)
    if not B.active or destGUID == nil or ns.IsSecret(destGUID) then return end
    local hot = HotOf(spellID)
    if not hot then return end
    if sub == "SPELL_AURA_APPLIED" or sub == "SPELL_AURA_REFRESH" then Note(destGUID, hot)
    elseif sub == "SPELL_AURA_REMOVED" then B.hots[destGUID] = nil; B:Wake() end
end

function B.HotOn(unit)
    local guid = ns.GUID(unit)
    if not guid or ns.IsSecret(guid) then return nil end
    local h = B.hots[guid]
    if h and GetTime() < h.ends then return h end
    if h then B.hots[guid] = nil end
end

---------------------------------------------------------------------------
-- The growth on a bar
---------------------------------------------------------------------------
local GROW, WITHER = 0.9, 0.6
local function Strip(f, flip)
    local t = f.visual:CreateTexture(nil, "OVERLAY", nil, 2)
    t:SetTexture(ns.media.vines)
    t:SetHeight(16)
    if flip then t:SetPoint("TOPLEFT", f.health, "BOTTOMLEFT", 0, 6) else t:SetPoint("BOTTOMLEFT", f.health, "TOPLEFT", 0, -6) end
    t:SetWidth(1)
    t:Hide()
    return t
end

local function Vines(f)
    local v = B.frames[f]
    if not v then
        v = { top = Strip(f, false), bottom = Strip(f, true), g = 0 }
        B.frames[f] = v
    end
    return v
end

local function Draw(f, v)
    local w = f.health:GetWidth() or 100
    local g = v.g
    if g <= 0.001 then v.top:Hide(); v.bottom:Hide(); return end
    local look = B.LOOK[v.school or "nature"] or B.LOOK.nature
    local c = look.color
    local sway = 0.8 + 0.12 * math.sin(GetTime() * 2.2)
    for i, t in ipairs({ v.top, v.bottom }) do
        t:SetWidth(math.max(1, w * g))
        if i == 1 then t:SetTexCoord(0, g, 0, 1) else t:SetTexCoord(0, g, 1, 0) end      -- the lower one mirrored
        t:SetVertexColor(c[1], c[2], c[3], 1)
        t:SetAlpha((v.withering and g or 1) * sway)
        t:Show()
    end
end

local KEYS = { "target", "focus", "player" }
local driver = CreateFrame("Frame")
local since = 0
local function Tick(_, dt)
    since = since + dt
    local any = false
    local UF = ns.UnitFrames
    for _, key in ipairs(KEYS) do
        local f = UF and UF.frames[key]
        if f and f.on and f.health then
            local hot = ns.db.hotVines and B.active and B.HotOn(f.unit)
            local v = B.frames[f] or (hot and Vines(f))
            if v then
                if hot then
                    v.school, v.withering = hot.school, false
                    v.g = math.min(1, v.g + dt / GROW)
                else
                    v.withering = true
                    v.g = math.max(0, v.g - dt / WITHER)
                end
                Draw(f, v)
                if hot or v.g > 0 then any = true end
            end
        end
    end
    if not any then driver:SetScript("OnUpdate", nil) end
end
Tick = ns.Protect(Tick)

function B:Wake() driver:SetScript("OnUpdate", Tick) end

---------------------------------------------------------------------------
-- Listening
---------------------------------------------------------------------------
local events = CreateFrame("Frame")
events:SetScript("OnEvent", ns.Protect(function(_, event, unit, a2, a3, a4)
    if event == "UNIT_SPELLCAST_SENT" then                 -- yours: the game says who it is for
        if unit == "player" then
            local target = a2
            B.sentTo = nil
            if type(target) == "string" and not ns.IsSecret(target) and target ~= "" then
                for _, u in ipairs({ "target", "focus", "player", "mouseover" }) do
                    if UnitExists(u) and ns.Plain(UnitName(u)) == target then B.sentTo = u; break end
                end
            end
        end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if unit == "player" or unit:find("^party") or unit:find("^raid") then FromCast(unit, a3) end
    elseif event == "UNIT_AURA" then
        if unit == "target" or unit == "focus" or unit == "player" then FromAuras(unit); B:Wake() end
    elseif event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED" then
        FromAuras(event == "PLAYER_TARGET_CHANGED" and "target" or "focus")
        B:Wake()
    end
end))

function B:Apply(run)
    local want = run and (ns.db.hotVines or ns.db.healColors) and true or false
    if want == self.active then return end
    self.active = want
    if want then
        for _, e in ipairs({ "UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_AURA", "PLAYER_TARGET_CHANGED",
                             "PLAYER_FOCUS_CHANGED" }) do
            pcall(events.RegisterEvent, events, e)
        end
    else
        events:UnregisterAllEvents()
        for f, v in pairs(self.frames) do v.g = 0; v.top:Hide(); v.bottom:Hide() end
        self.hots = {}
    end
end

ns.RegisterModule("bloom", B)
