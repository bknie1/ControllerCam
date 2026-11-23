-- ControllerCam HUD: a scene at the camp fire.
-- Sit still at a camp for a few seconds, out of a fight, and the screen turns to film for a minute: black bars
-- close in from the top and the bottom, the rest of the screen fades away and the camera circles slowly round
-- you. The place comes up first, with the time of day; then, one at a time, the big moments since your last camp
-- (a boss down, a level, a profession's new rank, a new mount, an achievement, a new flight path: the big ones
-- only, each told once, never the day's chores); and at the end the camp's gifts, the buffs you carry, by the
-- class that gave them. Any move, a button, a window, a fight or a spell ends it at once and gives everything
-- back as it was: the screen, the camera's distance and its offset (held by the camera addon meanwhile).
-- With Reduce animations on the camera stays still and the bars fade in where they stand.
-- A camp is seen two ways: sitting at its fire (Welcoming Campfire, or a fire's Cozy Fire warmth) or a buff the
-- world gave you there (from nobody in your group: a tent, a shrine), lately or for as long as you stay by it.
-- Buffs that only say camp (Camp Benefits, Campfire Nearby) do not start it; the camp benefits close it, each
-- by its own name, read from the buff's tooltip. A sleeping bag's rest (Resting) is a camp too, a quieter one.
-- Whoever of your group is close by is named under the place, in their class's colour: the company you keep.

local ADDON, ns = ...
local L, C = ns.L, ns.colors

local CF = { active = false, shown = 0, stillSince = 0 }
ns.Campfire = CF

ns.RegisterSetting({
    key = "campScene", kind = "boolean", default = true, command = "campscene", section = "Effects",
    label = "Campfire scene",
    tip = "sit still at a camp for a few seconds and the screen turns to film for a minute: the camera circles you, your big moments since the last camp are told (bosses, levels, professions, new mounts), and the camp's buffs close it, by class. Any move or button ends it",
})

CF.WAIT = 10                     -- seconds sitting still at a camp before it begins
CF.AGAIN = 1200                  -- and not again at the same camp for this long (or until you leave it)
CF.LENGTH = 60
CF.BAR = 0.11                    -- each black bar: this share of the screen's height
CF.TURN = 0.75                   -- how far round the camera goes over the scene (a whole turn is 1)
CF.OUT = 3                       -- the camera eases this much further out
CF.TITLE = { 2.5, 8 }            -- the place and the time of day
CF.TELL_AT, CF.EACH, CF.MAX_TOLD = 9, 6, 6    -- the big moments: from, each for, at most
CF.BUFFS_AT = 48                 -- the camp's gifts
CF.LONG = 60                     -- a buff of yours or your group's counts from this long
CF.ROWS, CF.PER_ROW = 4, 7
CF.KEEP = 20                     -- big moments kept until told
CF.FRESH = 300                   -- a buff from the world given this lately: you came to this camp
CF.AWAY = 300                    -- this long with no camp and the next camp plays again (a fire's welcome ends
                                 -- after a minute: getting up and sitting back down is not a new camp)
CF.FIRE = { [7353] = true }      -- Cozy Fire: the warmth of a camp fire
CF.CAMP_WORDS = { "camp" }       -- a buff whose name says camp is the camp's (in lower case)
CF.AT_CAMP = { ["welcoming campfire"] = true, -- on you while you sit at a camp fire: always a camp (in lower case)
               ["resting"] = true }            -- and lying in a sleeping bag
CF.SLEEP = { ["resting"] = true }                -- the sleeping bag's: a camp at rest, maybe with no fire
CF.COMPANY = 6                                    -- at most this many of your group named
CF.LOOKING = { mouse = true, cursor = true }     -- the HUD wakes for these, but the scene waits on neither: at
                                                 -- a camp you look at the fire's buff and its minute counting down
CF.CAMP_ICON = 135805
CF.WARM = { 1, 0.80, 0.48 }
CF.WINDOWS = { "GameMenuFrame", "ContainerFrameCombinedBags", "ContainerFrame1", "StaticPopup1", "WorldMapFrame",
               "SettingsPanel", "MailFrame", "MerchantFrame", "BankFrame", "TaxiFrame", "LootFrame", "GossipFrame",
               "QuestFrame", "CharacterFrame", "SpellBookFrame", "PlayerSpellsFrame" }

local Plain, Yes = ns.Plain, ns.Yes
local function Clamp01(k) return math.max(0, math.min(1, k)) end
local function Ease(k) k = Clamp01(k); return 1 - (1 - k) * (1 - k) * (1 - k) end
local function Window(t, a, b, f) return math.min(Clamp01((t - a) / f), Clamp01((b - t) / f)) end
local function Now() return time and time() or 0 end
local function Call(fn, ...)
    if type(fn) ~= "function" then return false end
    return pcall(fn, ...)
end
local function Asks(fn, ...)
    if type(fn) ~= "function" then return false end
    local ok, v = pcall(fn, ...)
    return ok and Yes(v)
end

local function Me()
    return ns.Inventory and ns.Inventory.Me and ns.Inventory.Me() or (UnitName and UnitName("player")) or "you"
end

local function SpellName(id)
    local get = (C_Spell and C_Spell.GetSpellName) or GetSpellInfo
    if not get then return nil end
    local ok, name = pcall(get, id)
    name = ok and Plain(name)
    return (type(name) == "string" and name ~= "") and name or nil
end

---------------------------------------------------------------------------
-- The big moments since your last camp, for each character: told once each, then gone
---------------------------------------------------------------------------
local FIELDS = { kind = "string", key = "string", name = "string", where = "string", last = "string",
                 tier = "number", reached = "number", from = "number", to = "number", n = "number", at = "number",
                 weight = "number", icon = "number" }
ns.RegisterSaved("milestones", function(old)
    local out = {}
    for who, list in pairs(type(old) == "table" and old or {}) do
        if type(who) == "string" and type(list) == "table" then
            local clean = {}
            for _, m in ipairs(list) do
                if type(m) == "table" and type(m.kind) == "string" and type(m.key) == "string" then
                    local c = {}
                    for k, kind in pairs(FIELDS) do
                        if type(m[k]) == kind then c[k] = m[k] end
                    end
                    clean[#clean + 1] = c
                end
            end
            out[who] = clean
        end
    end
    return out
end)

function CF.List()
    if not ns.db then return {} end
    ns.db.milestones = type(ns.db.milestones) == "table" and ns.db.milestones or {}
    local me = Me()
    ns.db.milestones[me] = ns.db.milestones[me] or {}
    return ns.db.milestones[me]
end

local function Find(key)
    for _, m in ipairs(CF.List()) do if m.key == key then return m end end
end

function CF.TierName(cap)
    if cap >= 450 then return L["Grand Master"] end
    if cap >= 375 then return L["Master"] end
    if cap >= 300 then return L["Artisan"] end
    if cap >= 225 then return L["Expert"] end
    if cap >= 150 then return L["Journeyman"] end
    return L["Apprentice"]
end

-- The moment in words
function CF.Text(m)
    local kind = m.kind
    if kind == "level" then
        if m.from and m.to and m.from < m.to - 1 then return L["Reached level %d (from %d)"]:format(m.to, m.from) end
        return L["Reached level %d"]:format(m.to or 0)
    elseif kind == "boss" then
        if (m.n or 1) > 1 and m.where then
            return L["Defeated %s and %d more in %s"]:format(m.last or "?", m.n - 1, m.where)
        end
        return L["Defeated %s"]:format(m.last or "?")
    elseif kind == "prof" then
        if m.tier then return L["%s: now %s, up to %d"]:format(m.name or "?", CF.TierName(m.tier), m.tier) end
        return L["%s reached %d"]:format(m.name or "?", m.reached or 0)
    elseif kind == "flight" then
        if (m.n or 1) > 1 then return L["%d new flight paths, the last %s"]:format(m.n, m.last or "?") end
        return L["New flight path: %s"]:format(m.last or "?")
    elseif kind == "mount" then return L["New mount: %s"]:format(m.name or "?")
    elseif kind == "pet" then return L["New companion: %s"]:format(m.name or "?")
    elseif kind == "toy" then return L["New toy: %s"]:format(m.name or "?")
    elseif kind == "achievement" then return L["Achievement: %s"]:format(m.name or "?")
    end
    return tostring(m.name or kind)
end

-- Keeps it (the least of them goes when there are too many: the smallest, then the oldest)
local function Add(m)
    local list = CF.List()
    m.at = Now()
    list[#list + 1] = m
    while #list > CF.KEEP do
        local worst = 1
        for i, x in ipairs(list) do
            local w = list[worst]
            if (x.weight or 0) < (w.weight or 0) or ((x.weight or 0) == (w.weight or 0) and (x.at or 0) < (w.at or 0)) then
                worst = i
            end
        end
        table.remove(list, worst)
    end
    return m
end

local function Mark(m)
    m.at = Now()
    ns.Note("campfire: a big moment: %s", CF.Text(m))
    return m
end

function CF.Level(level)
    level = tonumber(Plain(level))
    if not level then return end
    local m = Find("level")
    if m then m.to = level else m = Add({ kind = "level", key = "level", from = level - 1, to = level, weight = 3 }) end
    Mark(m)
end

local bossSeen = {}
function CF.Boss(id, name)
    name = Plain(name)
    if type(name) ~= "string" or name == "" then return end
    local k = tostring(Plain(id) or name)
    local t = GetTime()
    if bossSeen[k] and t - bossSeen[k] < 30 then return end      -- (the game tells a kill two ways)
    bossSeen[k] = t
    local where, kind
    if GetInstanceInfo then
        local ok, n, ty = pcall(GetInstanceInfo)
        if ok then where, kind = Plain(n), Plain(ty) end
    end
    if type(where) ~= "string" or where == "" or kind == "none" then where = nil end
    local key = "boss:" .. (where or name)
    local m = Find(key)
    if m and where then                                           -- one line for a whole dungeon
        m.n, m.last = (m.n or 1) + 1, name
    else
        m = Add({ kind = "boss", key = key, last = name, where = where, n = 1, weight = kind == "raid" and 5 or 4 })
    end
    Mark(m)
end

local skills                     -- [profession] = { rank, cap }, from the first look at them this session
function CF.ReadSkills()
    if not (GetNumSkillLines and GetSkillLineInfo) then return end
    local P = ns.Professions
    local ok, n = pcall(GetNumSkillLines)
    local first = skills == nil
    skills = skills or {}
    for i = 1, (ok and tonumber(n)) or 0 do
        local ok2, name, header, _, rank, _, _, cap = pcall(GetSkillLineInfo, i)
        name, rank, cap = ok2 and Plain(name), Plain(rank), Plain(cap)
        if type(name) == "string" and not Plain(header) and type(rank) == "number" and type(cap) == "number"
            and P and P.Kind and P.Kind(name) then
            local was = skills[name]
            if not first then
                local learnt = was == nil and rank <= 1            -- (just learnt: a first look at one is not news)
                local tierUp = learnt or (was and cap > was.cap)
                local crossed = was and math.floor(rank / 75) > math.floor(was.rank / 75) and math.floor(rank / 75) * 75
                if tierUp or crossed then
                    local m = Find("prof:" .. name) or Add({ kind = "prof", key = "prof:" .. name, name = name, weight = 2 })
                    if tierUp then m.tier, m.weight = cap, 3 end
                    if crossed then m.reached = crossed end
                    Mark(m)
                end
            end
            skills[name] = { rank = rank, cap = cap }
        end
    end
end

function CF.Unlock(kind, name, icon, weight)
    name = Plain(name)
    if type(name) ~= "string" or name == "" then return end
    local key = kind .. ":" .. name
    if Find(key) then return end
    icon = Plain(icon)
    Mark(Add({ kind = kind, key = key, name = name, icon = type(icon) == "number" and icon or nil, weight = weight }))
end

function CF.Flight()
    local place = GetSubZoneText and Plain(GetSubZoneText())
    if type(place) ~= "string" or place == "" then place = GetZoneText and Plain(GetZoneText()) end
    place = type(place) == "string" and place or "?"
    local m = Find("flight")
    if m then m.n, m.last = (m.n or 1) + 1, place
    else m = Add({ kind = "flight", key = "flight", n = 1, last = place, weight = 1 }) end
    Mark(m)
end

-- What the scene tells: the biggest few, in the order they happened
function CF.Pick()
    local list = {}
    for _, m in ipairs(CF.List()) do list[#list + 1] = m end
    table.sort(list, function(x, y)
        if (x.weight or 0) ~= (y.weight or 0) then return (x.weight or 0) > (y.weight or 0) end
        return (x.at or 0) > (y.at or 0)
    end)
    while #list > CF.MAX_TOLD do table.remove(list) end
    table.sort(list, function(x, y) return (x.at or 0) < (y.at or 0) end)
    return list
end

function CF.Told(m)
    local list = CF.List()
    for i = #list, 1, -1 do if list[i] == m then table.remove(list, i) end end
end

local function ProfIcon(name)
    local P = ns.Professions
    local kind = P and P.Kind and P.Kind(name)
    for _, p in ipairs(P and P.LIST or {}) do
        if p[1] == kind then
            local get = (C_Spell and C_Spell.GetSpellTexture) or GetSpellTexture
            local ok, icon = Call(get, p[2])
            return ok and Plain(icon) or nil
        end
    end
end

---------------------------------------------------------------------------
-- The camp, and what you carry from it
---------------------------------------------------------------------------
local function Buffs()
    local U = ns.Unit
    return U and U.Filtered and U.Filtered("player", "HELPFUL", "HELPFUL", 40) or {}
end
local function FromTheWorld(a)
    return ns.Readout and ns.Readout.FromTheWorld and ns.Readout.FromTheWorld(a) or false
end
-- A camp's own buff: a camp fire's warmth, or one named for the camp (the camp benefits)
local function IsFire(a)
    local id, name = Plain(a.spellId), Plain(a.name)
    if id and CF.FIRE[id] then return true end
    local fire = SpellName(7353)
    if fire ~= nil and name == fire then return true end
    if type(name) == "string" then
        local low = name:lower()
        if CF.AT_CAMP[low] then return true end
        for _, word in ipairs(CF.CAMP_WORDS) do
            if low:find(word, 1, true) then return true end
        end
    end
    return false
end

-- Sitting at the fire: its warmth (Cozy Fire) or the welcome of a camp's fire. A buff that only says camp
-- (the camp benefits you carry for an hour, a fire nearby) does not start the scene: you may have walked on.
local function AtTheFire(a)
    local id, name = Plain(a.spellId), Plain(a.name)
    if id and CF.FIRE[id] then return true end
    local fire = SpellName(7353)
    if fire ~= nil and name == fire then return true end
    return type(name) == "string" and CF.AT_CAMP[name:lower()] or false
end

-- The benefits a camp gave you, read from its buff's tooltip ("Sharpening Wheel: Strength increased by 11."):
-- { { name, text } }, or nil when the tooltip says nothing of them
function CF.Benefits(a)
    local get = C_TooltipInfo and C_TooltipInfo.GetUnitBuffByAuraInstanceID
    local id = Plain(a.auraInstanceID)
    if not (get and id) then return nil end
    local ok, data = pcall(get, "player", id)
    if not (ok and type(data) == "table" and type(data.lines) == "table") then return nil end
    local out = {}
    for i = 2, #data.lines do
        local text = data.lines[i] and data.lines[i].leftText
        if type(text) == "string" and not ns.IsSecret(text) then
            for part in text:gmatch("[^\n]+") do
                local name, what = part:match("^%s*(.-)%s*:%s*(.-)%s*$")
                if name and name ~= "" and what and what ~= "" and not name:find("|", 1, true)
                    and not name:find("^%d") then                    -- not "36 |4minute:minutes; remaining"
                    out[#out + 1] = { name = name, text = what }
                end
            end
        end
    end
    return #out > 0 and out or nil
end

-- At rest in a sleeping bag, with no fire's welcome: the scene's quieter words
function CF.AtRest()
    local rest = false
    for _, a in ipairs(Buffs()) do
        if AtTheFire(a) then
            local name = Plain(a.name)
            if type(name) == "string" and CF.SLEEP[name:lower()] then rest = true else return false end
        end
    end
    return rest
end

-- Your group close by, for the scene ({ { name, class } }): in sight and near, alive, not you
function CF.Company()
    local out = {}
    local raid = Asks(IsInRaid)
    local n = raid and 40 or 4
    for i = 1, n do
        local unit = (raid and "raid" or "party") .. i
        if Asks(UnitExists, unit) and not Asks(UnitIsUnit, unit, "player") and Asks(UnitIsConnected, unit)
            and not Asks(UnitIsDeadOrGhost, unit) then
            local near
            if type(UnitIsVisible) == "function" and not Asks(UnitIsVisible, unit) then near = false
            elseif type(CheckInteractDistance) == "function" then
                local ok, v = pcall(CheckInteractDistance, unit, 4)
                if ok and Plain(v) ~= nil then near = Yes(v) end
            end
            if near == nil then near = Asks(UnitInRange, unit) end
            local okN, name = pcall(UnitName, unit)
            local okC, _, class = pcall(UnitClass, unit)
            name, class = okN and Plain(name), okC and Plain(class)
            if near and type(name) == "string" then out[#out + 1] = { name = name, class = class } end
        end
        if #out >= CF.COMPANY then break end
    end
    return out
end

-- Why this is a camp (words for the report), or nil
function CF.CampReason()
    local list = Buffs()
    local now = GetTime()
    for _, a in ipairs(list) do
        if AtTheFire(a) then return "the camp's own: " .. tostring(Plain(a.name) or Plain(a.spellId)) end
    end
    for _, a in ipairs(list) do
        if FromTheWorld(a) and not IsFire(a) then
            local d, ex, name = Plain(a.duration), Plain(a.expirationTime), tostring(Plain(a.name) or "?")
            if type(d) ~= "number" or d <= 0 then return "from the world, while you stay: " .. name end
            if type(ex) == "number" and ex - d >= now - CF.FRESH then return "from the world, just now: " .. name end
        end
    end
    return nil
end

-- The buffs you carry: the camp's first, then yours, then each class of your group's ({ key, label, class, buffs })
function CF.Groups()
    local myName, myClass = UnitClass("player")
    myName, myClass = Plain(myName), Plain(myClass)
    local groups, byKey = {}, {}
    local function Group(key, label, class)
        local g = byKey[key]
        if not g then
            g = { key = key, label = label, class = class, buffs = {} }
            byKey[key] = g
            groups[#groups + 1] = g
        end
        return g
    end
    for _, a in ipairs(Buffs()) do
        local name, icon, d = Plain(a.name), Plain(a.icon), Plain(a.duration)
        if type(name) == "string" then
            local buff = { name = name, icon = icon }
            local benefits = IsFire(a) and CF.Benefits(a)
            if benefits then                           -- each benefit the camp gave, by its own name
                for _, b in ipairs(benefits) do
                    table.insert(Group("camp", L["The camp"]).buffs, { name = b.name, icon = icon, text = b.text })
                end
            elseif IsFire(a) or FromTheWorld(a) then
                table.insert(Group("camp", L["The camp"]).buffs, buff)
            elseif type(d) == "number" and d >= CF.LONG then
                local src = Plain(a.sourceUnit)
                local label, class
                if Plain(a.isFromPlayerOrPlayerPet) or type(src) ~= "string" or Asks(UnitIsUnit, src, "player")
                    or Asks(UnitIsUnit, src, "pet") then
                    label, class = myName, myClass
                else
                    local ok, l, c = pcall(UnitClass, src)
                    if ok then label, class = Plain(l), Plain(c) end
                end
                if type(class) == "string" then table.insert(Group(class, label or class, class).buffs, buff) end
            end
        end
    end
    local function Rank(g) return g.key == "camp" and 0 or (g.class == myClass and 1 or 2) end
    table.sort(groups, function(x, y)
        if Rank(x) ~= Rank(y) then return Rank(x) < Rank(y) end
        return tostring(x.label) < tostring(y.label)
    end)
    while #groups > CF.ROWS do table.remove(groups) end
    return groups
end

---------------------------------------------------------------------------
-- When it may begin, and what ends it
---------------------------------------------------------------------------
local function Shown(f)
    if type(f) ~= "table" or type(f.IsShown) ~= "function" then return false end
    local ok, v = pcall(f.IsShown, f)
    return ok and Yes(v)
end

local function Moving()
    if GetUnitSpeed then
        local ok, v = pcall(GetUnitSpeed, "player")
        v = ok and Plain(v)
        if type(v) == "number" and v > 0 then return true end
    end
    return Asks(IsFalling)
end

local function AnyPadButton()
    local G = C_GamePad
    if not (G and G.GetDeviceMappedState) then return false end
    local ok, state = pcall(G.GetDeviceMappedState)
    if not ok or type(state) ~= "table" or type(state.buttons) ~= "table" then return false end
    for _, down in pairs(state.buttons) do if down == true then return true end end
    return false
end

local function WindowOpen()
    if GetUIPanel then
        for _, where in ipairs({ "left", "center", "right", "doublewide", "fullscreen" }) do
            local ok, f = pcall(GetUIPanel, where)
            if ok and f then return true end
        end
    end
    for _, name in ipairs(CF.WINDOWS) do if Shown(_G[name]) then return true end end
    if ChatEdit_GetActiveWindow then
        local ok, box = pcall(ChatEdit_GetActiveWindow)
        if ok and box then return true end
    end
    return false
end

CF.WindowOpen, CF.AnyPadButton = WindowOpen, AnyPadButton   -- (the ride's film asks the same)

-- The minimap's own marks (your arrow, the quest arrows and dots it draws) do not fade with the screen: a scene
-- hides the whole minimap once the screen has faded, and shows again what was shown as it comes back (the ride's
-- film too). Never hidden in a fight; shown again when the fight ends if the game will not show it in one.
CF.MAPS = { "MinimapCluster", "Minimap" }
local mapLater = CreateFrame("Frame")
local function ShowMaps(list)
    local failed = {}
    for _, f in ipairs(list) do
        if not pcall(f.Show, f) then failed[#failed + 1] = f end
    end
    if ns.Rest and ns.Rest.RedrawMinimap then pcall(ns.Rest.RedrawMinimap) end   -- (its terrain drawn again)
    if #failed > 0 then
        mapLater.list = failed
        pcall(mapLater.RegisterEvent, mapLater, "PLAYER_REGEN_ENABLED")
    end
end
mapLater:SetScript("OnEvent", ns.Protect(function(self)
    self:UnregisterAllEvents()
    local list = self.list
    self.list = nil
    if list then ShowMaps(list) end
end))

function CF.Minimap(s, hide)
    if hide then
        if s.maps or Yes(InCombatLockdown()) then return end
        s.maps = {}
        for _, name in ipairs(CF.MAPS) do
            local f = _G[name]
            if type(f) == "table" and f.IsShown and f.Hide then
                local ok, shown = pcall(f.IsShown, f)
                if ok and shown and pcall(f.Hide, f) then s.maps[#s.maps + 1] = f end
            end
        end
    elseif s.maps then
        local list = s.maps
        s.maps = nil
        ShowMaps(list)
    end
end

-- What keeps you busy right now (a word), or nil
function CF.Busy()
    if Yes(UnitAffectingCombat("player")) or Yes(InCombatLockdown()) then return "combat" end
    if Moving() then return "moving" end
    if (UnitCastingInfo and Plain(UnitCastingInfo("player"))) or (UnitChannelInfo and Plain(UnitChannelInfo("player"))) then
        return "casting"
    end
    if Asks(IsMounted) or Asks(IsFlying) or Asks(IsSwimming) or Asks(UnitInVehicle, "player") then return "travelling" end
    if Asks(UnitIsDeadOrGhost, "player") then return "dead" end
    if AnyPadButton() then return "a button" end
    if WindowOpen() then return "a window" end
    local rest = ns.Rest and ns.Rest.Reason and ns.Rest.Reason()
    if rest and not CF.LOOKING[rest] then return rest end   -- (only looking: the cursor out, over a buff, is not busy)
    return nil
end

local function InInstance()
    if not IsInInstance then return false end
    local ok, inside, kind = pcall(IsInInstance)
    return ok and Yes(inside) and kind ~= "none" and kind ~= "neighborhood"
end

-- Why it may not begin now (a word), or nil
function CF.Why(now)
    if not (CF.active and ns.db and ns.db.campScene) then return "off" end
    if CF.scene then return "playing" end
    local busy = CF.Busy()
    if busy then return busy end
    if InInstance() then return "in an instance" end
    if now - CF.stillSince < CF.WAIT then return "not still for long enough" end
    CF.camp = CF.CampReason()
    if not CF.camp then return "no camp" end
    if CF.playedAt and now - CF.playedAt < CF.AGAIN then return "played at this camp" end
    return nil
end

---------------------------------------------------------------------------
-- The screen
---------------------------------------------------------------------------
local cine

local function Build()
    if cine then return end
    cine = CreateFrame("Frame", "ControllerCamHUD_Campfire", nil)      -- (not under the screen it fades away)
    cine:SetFrameStrata("FULLSCREEN_DIALOG")
    cine:SetAllPoints(WorldFrame or UIParent)
    cine.top = cine:CreateTexture(nil, "BACKGROUND")
    cine.top:SetColorTexture(0, 0, 0, 1)
    cine.top:SetPoint("TOPLEFT", cine, "TOPLEFT", 0, 0)
    cine.top:SetPoint("TOPRIGHT", cine, "TOPRIGHT", 0, 0)
    cine.bottom = cine:CreateTexture(nil, "BACKGROUND")
    cine.bottom:SetColorTexture(0, 0, 0, 1)
    cine.bottom:SetPoint("BOTTOMLEFT", cine, "BOTTOMLEFT", 0, 0)
    cine.bottom:SetPoint("BOTTOMRIGHT", cine, "BOTTOMRIGHT", 0, 0)
    cine.title = ns.FontString(cine, 26, "CENTER")
    cine.title:SetPoint("CENTER", cine.bottom, "CENTER", 0, 9)
    cine.title:SetTextColor(CF.WARM[1], CF.WARM[2], CF.WARM[3], 1)
    cine.sub = ns.FontString(cine, 13, "CENTER")
    cine.sub:SetPoint("TOP", cine.title, "BOTTOM", 0, -4)
    cine.sub:SetTextColor(0.85, 0.82, 0.74, 1)
    cine.with = ns.FontString(cine, 13, "CENTER")
    cine.with:SetPoint("TOP", cine.sub, "BOTTOM", 0, -3)
    cine.with:SetTextColor(0.85, 0.82, 0.74, 1)
    cine.line = ns.FontString(cine, 17, "CENTER")
    cine.line:SetPoint("CENTER", cine.bottom, "CENTER", 14, 0)
    cine.line:SetTextColor(1, 0.93, 0.8, 1)
    cine.lineIcon = cine:CreateTexture(nil, "ARTWORK")
    cine.lineIcon:SetSize(26, 26)
    cine.lineIcon:SetPoint("RIGHT", cine.line, "LEFT", -10, 0)
    -- the camp's gifts, above the lower bar
    local p = CreateFrame("Frame", nil, cine)
    p:SetSize(640, 60)
    p:SetPoint("BOTTOM", cine.bottom, "TOP", 0, 18)
    p.shade = p:CreateTexture(nil, "BACKGROUND")
    p.shade:SetTexture(ns.media.soft)
    p.shade:SetVertexColor(0, 0, 0, 1)
    p.shade:SetPoint("TOPLEFT", p, "TOPLEFT", -90, 24)
    p.shade:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", 90, -24)
    p.shade:SetAlpha(0.55)
    p.head = ns.FontString(p, 18, "CENTER")
    p.head:SetPoint("TOP", p, "TOP", 0, 0)
    p.head:SetTextColor(CF.WARM[1], CF.WARM[2], CF.WARM[3], 1)
    p.rows = {}
    cine.panel = p
    cine:Hide()
    CF.frame = cine
end

local function Row(i)
    local p = cine.panel
    local r = p.rows[i]
    if r then return r end
    r = CreateFrame("Frame", nil, p)
    r:SetSize(10, 44)
    r.head = r:CreateTexture(nil, "ARTWORK")
    r.head:SetSize(24, 24)
    r.head:SetPoint("LEFT", r, "LEFT", 0, 6)
    r.label = ns.FontString(r, 13, "LEFT")
    r.label:SetPoint("LEFT", r.head, "RIGHT", 8, 0)
    r.icons, r.names = {}, {}
    for j = 1, CF.PER_ROW do
        local icon = r:CreateTexture(nil, "ARTWORK")
        icon:SetSize(28, 28)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon:SetPoint("TOP", r, "TOPLEFT", 150 + (j - 0.5) * 72, 0)
        local name = ns.FontString(r, 10, "CENTER")
        name:SetPoint("TOP", icon, "BOTTOM", 0, -2)
        name:SetWidth(70)
        if name.SetWordWrap then name:SetWordWrap(false) end
        r.icons[j], r.names[j] = icon, name
    end
    p.rows[i] = r
    return r
end

local function ClassIcon(tex, class)
    tex:SetTexCoord(0, 1, 0, 1)
    local atlas = "classicon-" .. tostring(class):lower()
    if C_Texture and C_Texture.GetAtlasInfo then
        local ok, info = pcall(C_Texture.GetAtlasInfo, atlas)
        if ok and Plain(info) then tex:SetAtlas(atlas); return end
    end
    tex:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
    local c = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
    if c then tex:SetTexCoord(c[1], c[2], c[3], c[4]) end
end

local function ClassColor(class)
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return c.r, c.g, c.b end
    return 1, 1, 1
end

local function LayBuffs(s)
    local p = cine.panel
    s.groups = CF.Groups()
    p.head:SetText(s.rest and L["At rest"] or L["By the fire"])
    for i, r in ipairs(p.rows) do if not s.groups[i] then r:Hide() end end
    for i, g in ipairs(s.groups) do
        local r = Row(i)
        if g.key == "camp" then
            r.head:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            r.head:SetTexture(CF.CAMP_ICON)
            r.label:SetTextColor(CF.WARM[1], CF.WARM[2], CF.WARM[3], 1)
        else
            ClassIcon(r.head, g.class)
            r.label:SetTextColor(ClassColor(g.class))
        end
        r.label:SetText(g.label or "")
        local n = math.min(#g.buffs, CF.PER_ROW)
        for j = 1, CF.PER_ROW do
            local b = g.buffs[j]
            if b and j <= n then
                r.icons[j]:SetTexture(b.icon)
                r.icons[j]:Show()
                r.names[j]:SetText(b.name)
                r.names[j]:Show()
            else
                r.icons[j]:Hide()
                r.names[j]:Hide()
            end
        end
        r.width = 150 + n * 72
        r:SetWidth(r.width)
        r:Show()
    end
    p:SetHeight(28 + #s.groups * 50)
    s.buffsLaid = true
end

local function TimeOfDay()
    local ok, h = Call(GetGameTime)
    h = ok and tonumber(Plain(h))
    if not h then return nil end
    if h >= 5 and h < 7 then return L["Dawn"] end
    if h >= 7 and h < 12 then return L["Morning"] end
    if h >= 12 and h < 17 then return L["Afternoon"] end
    if h >= 17 and h < 21 then return L["Evening"] end
    return L["Night"]
end

local function LayTitle()
    local zone = GetZoneText and Plain(GetZoneText()) or nil
    local spot = GetSubZoneText and Plain(GetSubZoneText()) or nil
    if type(spot) ~= "string" or spot == "" or spot == zone then spot = nil end
    local when = TimeOfDay()
    cine.title:SetText(spot or zone or "")
    if when and spot and zone then cine.sub:SetText(L["%s in %s"]:format(when, zone))
    else cine.sub:SetText(when or (spot and zone) or "") end
    local names = {}
    for _, m in ipairs(CF.Company()) do
        local c = RAID_CLASS_COLORS and m.class and RAID_CLASS_COLORS[m.class]
        if c and c.r then
            names[#names + 1] = ("|cff%02x%02x%02x%s|r"):format(c.r * 255, c.g * 255, c.b * 255, m.name)
        else
            names[#names + 1] = m.name
        end
    end
    cine.with:SetText(#names > 0 and L["With %s"]:format(table.concat(names, ", ")) or "")
end

local function LayLine(m)
    cine.line:SetText(CF.Text(m))
    local icon = m.icon
    cine.lineIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    if m.kind == "boss" then
        cine.lineIcon:SetTexCoord(0, 1, 0, 1)
        icon = ns.media.skull
    elseif m.kind == "flight" then
        cine.lineIcon:SetTexCoord(0, 1, 0, 1)
        icon = ns.media.wing
    elseif m.kind == "prof" then
        icon = ProfIcon(m.name)
    elseif m.kind == "level" then
        local _, class = UnitClass("player")
        if Plain(class) then ClassIcon(cine.lineIcon, class); cine.lineIcon:Show(); return end
    end
    if icon then cine.lineIcon:SetTexture(icon); cine.lineIcon:Show() else cine.lineIcon:Hide() end
end

---------------------------------------------------------------------------
-- The scene
---------------------------------------------------------------------------
local function SetUIAlpha(a) pcall(UIParent.SetAlpha, UIParent, a) end

local function Hold(on)
    local cam = _G.ControllerCam
    if type(cam) == "table" and type(cam.Hold) == "function" then pcall(cam.Hold, on) end
end

local function YawSpeed()
    local v = GetCVar and tonumber(GetCVar("cameraYawMoveSpeed"))
    return (v and v > 0) and v or 180
end

local function Orbit(s, k)
    k = math.floor(k * 10 + 0.5) / 10
    if k == s.k then return end
    s.k = k
    if k > 0 then Call(MoveViewRightStart, s.speed * k) else Call(MoveViewRightStop) end
end

function CF.Start(asked)
    if CF.scene then return false end
    if Yes(InCombatLockdown()) or Yes(UnitAffectingCombat("player")) then return false end
    Build()
    local okA, alpha = pcall(UIParent.GetAlpha, UIParent)
    local s = {
        at = GetTime(), calm = ns.Calm() and true or false, asked = asked,
        alpha = (okA and type(Plain(alpha)) == "number") and alpha or 1,
        zoom = GetCameraZoom and tonumber(Plain(GetCameraZoom())) or nil,
        told = CF.Pick(), k = 0, rest = CF.AtRest(),
    }
    s.speed = (360 * CF.TURN / (CF.LENGTH - 3)) / YawSpeed()
    CF.scene = s
    local okS, scale = pcall(UIParent.GetEffectiveScale, UIParent)
    cine:SetScale((okS and type(scale) == "number" and scale > 0) and scale or 1)
    Hold(true)
    if not s.calm and s.zoom and CameraZoomOut then
        Call(CameraZoomOut, CF.OUT)
        s.out = true
    end
    LayTitle()
    cine.line:SetText("")
    cine.lineIcon:Hide()
    cine.panel:Hide()
    cine:Show()
    CF.shown = CF.shown + 1
    ns.Note("campfire: the scene begins (%s), %d big moments to tell", tostring(asked and "asked for" or CF.camp), #s.told)
    CF.Step()
    return true
end

function CF.Finish(why)
    local s = CF.scene
    if not s then return end
    CF.scene = nil
    Call(MoveViewRightStop)
    if s.out then                                      -- the distance it had
        local cur = GetCameraZoom and tonumber(Plain(GetCameraZoom()))
        local back = CF.OUT
        if cur and s.zoom and GetTime() - s.at > 1.5 then back = cur - s.zoom end   -- (settled by now: what it moved)
        if back > 0.05 then Call(CameraZoomIn, back) elseif back < -0.05 then Call(CameraZoomOut, -back) end
    end
    SetUIAlpha(s.alpha)
    CF.Minimap(s, false)
    if cine then cine:Hide() end
    Hold(false)
    CF.playedAt, CF.last, CF.stillSince = GetTime(), why, GetTime()
    ns.Note("campfire: the scene ends (%s) after %.0f s", tostring(why), GetTime() - s.at)
end

function CF.Step()
    local s = CF.scene
    if not s then return end
    local t = GetTime() - s.at
    if t >= CF.LENGTH then return CF.Finish("finished") end
    if t > 0.5 then                                    -- (a beat first: the press that asked for it)
        local busy = CF.Busy()
        if busy then return CF.Finish(busy) end
    end
    local okH, h = pcall(UIParent.GetHeight, UIParent)
    h = (okH and type(Plain(h)) == "number") and h or 768
    local bar = h * CF.BAR
    local fadeIn, fadeBack = Clamp01(t / 1.2), Clamp01((t - (CF.LENGTH - 1.5)) / 1.5)
    local screen = math.max(1 - fadeIn, fadeBack)
    SetUIAlpha(s.alpha * screen)
    CF.Minimap(s, screen < 0.5)
    if s.calm then                                     -- still: the bars fade in where they stand
        cine.top:SetHeight(bar)
        cine.bottom:SetHeight(bar)
        cine:SetAlpha(math.min(fadeIn, 1 - fadeBack))
    else
        local k = Ease(t / 1.6) * (1 - Clamp01((t - (CF.LENGTH - 1.6)) / 1.6))
        cine.top:SetHeight(math.max(1, bar * k))
        cine.bottom:SetHeight(math.max(1, bar * k))
        cine:SetAlpha(1)
        Orbit(s, math.min(Clamp01(t / 3), Clamp01((CF.LENGTH - 0.5 - t) / 3)))
    end
    -- the place
    local title = Window(t, CF.TITLE[1], CF.TITLE[2], 0.8)
    cine.title:SetAlpha(title)
    cine.sub:SetAlpha(title)
    cine.with:SetAlpha(title)
    -- the big moments, one at a time
    local i = t >= CF.TELL_AT and math.floor((t - CF.TELL_AT) / CF.EACH) + 1 or 0
    if i ~= s.i then
        if s.i and s.told[s.i] then CF.Told(s.told[s.i]) end        -- told: never again
        s.i = i
        if s.told[i] then LayLine(s.told[i]) end
    end
    local m = s.told[i]
    local a = m and Window(t, CF.TELL_AT + (i - 1) * CF.EACH, CF.TELL_AT + i * CF.EACH - 0.3, 0.6) or 0
    cine.line:SetAlpha(a)
    cine.lineIcon:SetAlpha(a)
    -- the camp's gifts
    if t >= CF.BUFFS_AT then
        if not s.buffsLaid or t - (s.laidAt or 0) >= 1 then        -- again each second: the camp's benefits
            LayBuffs(s)                                               -- come after a minute by its fire
            s.laidAt = t
        end
        local p = cine.panel
        if #s.groups > 0 then
            p:Show()
            p:SetAlpha(Window(t, CF.BUFFS_AT, CF.LENGTH - 1.8, 0.8))
            for j, g in ipairs(s.groups) do
                local r = p.rows[j]
                local k = s.calm and 1 or Ease((t - CF.BUFFS_AT - (j - 1) * 0.25) / 0.6)
                r:ClearAllPoints()
                r:SetPoint("TOP", p, "TOP", (s.calm and 0 or -30 * (1 - k)), -(28 + (j - 1) * 50))
                r:SetAlpha(k)
            end
        end
    end
end

---------------------------------------------------------------------------
-- Running
---------------------------------------------------------------------------
local watcher = CreateFrame("Frame")
local acc = 0
watcher:SetScript("OnUpdate", ns.Protect(function(_, dt)
    if not CF.active then return end
    if CF.scene then CF.Step(); return end
    acc = acc + (dt or 0)
    if acc < 0.5 then return end
    acc = 0
    local now = GetTime()
    local camp = CF.CampReason()
    if CF.Busy() or not camp then CF.stillSince = now end           -- undisturbed at a camp, for a while
    if camp then CF.awaySince = nil else CF.awaySince = CF.awaySince or now end
    if CF.playedAt and CF.awaySince and now - CF.awaySince >= CF.AWAY then
        CF.playedAt = nil                                            -- long gone from that camp: the next one plays
    end
    local why = CF.Why(now)
    if why ~= CF.why and (camp or CF.why == nil or why == nil) then  -- what it waits on at a camp, for the report
        ns.Note("campfire: %s", why and ("waits: " .. why) or "may begin")
    end
    CF.why = why
    if not why then CF.Start() end
end))

watcher:SetScript("OnEvent", ns.Protect(function(_, event, a, b, c, d, e)
    if event == "PLAYER_REGEN_DISABLED" then CF.Finish("combat")
    elseif event == "PLAYER_LEAVING_WORLD" then CF.Finish("a loading screen")
    elseif event == "PLAYER_LEVEL_UP" then CF.Level(a)
    elseif event == "BOSS_KILL" then CF.Boss(a, b)
    elseif event == "ENCOUNTER_END" then
        if Plain(e) == 1 or Plain(e) == true then CF.Boss(a, b) end
    elseif event == "SKILL_LINES_CHANGED" or event == "PLAYER_ENTERING_WORLD" then CF.ReadSkills()
    elseif event == "NEW_MOUNT_ADDED" then
        local get = C_MountJournal and C_MountJournal.GetMountInfoByID
        local ok, name, _, icon = Call(get, a)
        if ok then CF.Unlock("mount", name, icon, 3) end
    elseif event == "NEW_PET_ADDED" then
        local get = C_PetJournal and C_PetJournal.GetPetInfoByPetID
        local ok, _, custom, _, _, _, _, _, name, icon = Call(get, a)
        if ok then CF.Unlock("pet", Plain(custom) or name, icon, 1) end
    elseif event == "NEW_TOY_ADDED" then
        local get = C_ToyBox and C_ToyBox.GetToyInfo
        local ok, _, name, icon = Call(get, a)
        if ok then CF.Unlock("toy", name, icon, 1) end
    elseif event == "ACHIEVEMENT_EARNED" then
        local ok, _, name, _, _, _, _, _, _, _, icon, _, guild = Call(GetAchievementInfo, a)
        if ok and not Yes(guild) then CF.Unlock("achievement", name, icon, 2) end
    elseif event == "UI_INFO_MESSAGE" then
        if ERR_NEWTAXIPATH and Plain(b) == ERR_NEWTAXIPATH then CF.Flight() end
    end
end))

local EVENTS = { "PLAYER_REGEN_DISABLED", "PLAYER_LEAVING_WORLD", "PLAYER_LEVEL_UP", "BOSS_KILL", "ENCOUNTER_END",
                 "SKILL_LINES_CHANGED", "PLAYER_ENTERING_WORLD", "NEW_MOUNT_ADDED", "NEW_PET_ADDED", "NEW_TOY_ADDED",
                 "ACHIEVEMENT_EARNED", "UI_INFO_MESSAGE" }
function CF:Apply(run)
    local want = run and ns.db.campScene and true or false
    if want and not self.active then
        self.active = true
        for _, e in ipairs(EVENTS) do pcall(watcher.RegisterEvent, watcher, e) end
        CF.stillSince = GetTime()
        CF.ReadSkills()
    elseif not want and self.active then
        self.active = false
        watcher:UnregisterAllEvents()
        CF.Finish("off")
    end
end
ns.RegisterModule("campfire", CF)

ns.RegisterCommand("campfire", function()
    if not CF.active then ns.Say(L["The campfire scene is off."]); return end
    if not CF.Start(true) then ns.Say(L["The campfire scene waits until you are out of combat."]) end
end, "/cchud campfire", "play the campfire scene now")

-- For the report: why a camp is seen or not, and the buffs the world gave you
function CF.Describe()
    local out = {}
    out[#out + 1] = ("on %s, shown %d, %s; last ended: %s; big moments waiting: %d"):format(
        tostring(CF.active), CF.shown, CF.scene and "playing" or ("not playing: " .. tostring(CF.why or "-")),
        tostring(CF.last or "-"), #CF.List())
    out[#out + 1] = "camp: " .. tostring(CF.CampReason() or "none seen")
    local now = GetTime()
    for _, a in ipairs(Buffs()) do                     -- every buff on you, to learn what a camp gives
        local world, fire = FromTheWorld(a), IsFire(a)
        local d, ex = Plain(a.duration), Plain(a.expirationTime)
        out[#out + 1] = ("  %s (spell %s): %s, from %s, lasts %s, given %s ago"):format(tostring(Plain(a.name)),
            tostring(Plain(a.spellId)), fire and "the camp's own" or (world and "from the world" or "not the camp's"),
            tostring(Plain(a.sourceUnit) or "-"), tostring(d),
            (type(d) == "number" and type(ex) == "number" and d > 0) and ("%.0f s"):format(now - (ex - d)) or "-")
        for _, b in ipairs(fire and CF.Benefits(a) or {}) do
            out[#out + 1] = ("    benefit: %s: %s"):format(b.name, b.text)
        end
    end
    for _, m in ipairs(CF.List()) do out[#out + 1] = "  waiting: " .. CF.Text(m) end
    return out
end
