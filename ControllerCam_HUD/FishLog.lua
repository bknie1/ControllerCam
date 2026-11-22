-- ControllerCam HUD: the fish journal's book.
-- Every catch is written down: what it was, how many, where and when first, and a weight. The game has no
-- weights for fish, so the weight is made up for fun: each kind has its own usual size, a catch falls
-- somewhere around it, and a big one is rare. A fish that names its own weight ("22 Pound Catfish") weighs
-- that. Also counted: the fish that got away (the game said so, or the line ran out with nothing landed).
-- Kept with the HUD's settings, for the account; nothing is read from or sent anywhere else.

local ADDON, ns = ...
local L = ns.L

local J = { active = false, session = { caught = 0, away = 0 }, feed = {}, tally = {} }
ns.FishLog = J

J.FEED = 4                    -- recent catches kept for the fishing interface
J.SLOTS, J.MIN = 6, 4         -- a water shows at most this many fish, and at least this many places for them

ns.RegisterSetting({
    key = "fishJournal", kind = "boolean", default = true, command = "fishjournal", section = "Fishing",
    label = "Fish journal",
    tip = "every catch is written into your fish journal: how many of each kind, where you first landed it, and a weight made up for fun with your best of each (/cchud journal opens it)",
})

local function Text(v) return (type(v) == "string" and not ns.IsSecret(v)) and v or nil end

ns.RegisterSaved("fishLog", function(old)
    local log = { fish = {}, zones = {}, total = 0, away = 0 }
    if type(old) ~= "table" then return log end
    log.total, log.away = math.max(0, tonumber(old.total) or 0), math.max(0, tonumber(old.away) or 0)
    log.streak = tonumber(old.streak)                   -- the most catches in a row (FishGame.lua)
    for id, e in pairs(type(old.fish) == "table" and old.fish or {}) do
        if type(id) == "number" and type(e) == "table" then
            log.fish[id] = { n = math.max(0, tonumber(e.n) or 0), best = tonumber(e.best), bestAt = Text(e.bestAt),
                             first = Text(e.first), firstAt = Text(e.firstAt), name = Text(e.name),
                             icon = (type(e.icon) == "number" or type(e.icon) == "string") and e.icon or nil,
                             fish = e.fish == true }
        end
    end
    for name, z in pairs(type(old.zones) == "table" and old.zones or {}) do
        if type(name) == "string" and type(z) == "table" then
            local zone = { n = math.max(0, tonumber(z.n) or 0), map = tonumber(z.map), fish = {} }
            for id, n in pairs(type(z.fish) == "table" and z.fish or {}) do
                if type(id) == "number" and tonumber(n) then zone.fish[id] = tonumber(n) end
            end
            log.zones[name] = zone
        end
    end
    return log
end)

function J.Log()
    local db = ns.db
    if type(db.fishLog) ~= "table" then db.fishLog = { fish = {}, zones = {}, total = 0, away = 0 } end
    return db.fishLog
end

---------------------------------------------------------------------------
-- Where, what, how heavy
---------------------------------------------------------------------------
-- The water you stand at: its name, and the game's map number for it (for the journal's lines about it)
function J.Where()
    local name = Text(GetRealZoneText and GetRealZoneText()) or Text(GetZoneText and GetZoneText()) or ""
    local map
    if C_Map and C_Map.GetBestMapForUnit then
        local ok, id = pcall(C_Map.GetBestMapForUnit, "player")
        if ok and type(id) == "number" and not ns.IsSecret(id) then map = id end
    end
    return name, map
end

-- Is it a fish (something to eat or to cook with), and not an old boot or a locked box?
function J.IsFish(id, quality)
    local get = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if get then
        local ok, _, _, _, _, _, classID = pcall(get, id)
        if ok and type(classID) == "number" then return classID == 0 or classID == 7 end
    end
    return type(quality) == "number" and quality >= 1
end

-- The usual weight of a kind, in pounds; true when the fish says its own weight
function J.Base(id, name)
    local said = type(name) == "string" and tonumber(name:match("(%d+) [Pp]ound"))
    if said then return said, true end
    return 0.4 + ((id * 7919) % 97) / 97 * 5.2
end

-- The weight of one catch: around the usual weight of its kind, and now and then a big one. A fish made
-- curious in the game beside the fishing interface (FishGame.lua; 0-1) is the heavier for it.
function J.Weigh(id, name, curious)
    local base, said = J.Base(id, name)
    if said then return base end
    local r = (J.random or math.random)()
    local more = 1 + (ns.FishGame and ns.FishGame.BONUS or 0) * ns.Clamp(tonumber(curious) or 0, 0, 1)
    return math.max(0.1, math.floor(base * (0.55 + 1.25 * r ^ 2.4) * more * 10 + 0.5) / 10)
end

function J.Pounds(w) return L["%.1f lb"]:format(w) end

---------------------------------------------------------------------------
-- Writing a catch down
---------------------------------------------------------------------------
local function Changed()
    if ns.FishPanel then ns.FishPanel:Refresh() end
    if ns.FishJournal then ns.FishJournal:Refresh() end
    if ns.FishGame then ns.FishGame:Refresh() end
end

-- A session is one stay at a water: its counts and its tally start again when you move on to another zone
function J:Water()
    local where = (J.Where())
    if where ~= self.water then
        self.water = where
        self.session, self.tally, self.feed = { caught = 0, away = 0 }, {}, {}
    end
    return where
end

-- What you have landed at this water this session, kind by kind: { id, n, name, icon }, the most first
function J.Tally()
    local out, log = {}, J.Log()
    for id, n in pairs(J.tally) do
        local e = log.fish[id] or {}
        out[#out + 1] = { id = id, n = n, name = e.name, icon = e.icon }
    end
    table.sort(out, function(a, b) if a.n ~= b.n then return a.n > b.n end return a.id < b.id end)
    return out
end

function J:Catch(id, name, icon, quality, count, curious)
    local log = J.Log()
    self:Water()
    local where, map = J.Where()
    count = math.max(1, tonumber(count) or 1)
    local e = log.fish[id]
    local new = not e
    if new then
        e = { n = 0, first = date and date("%Y-%m-%d") or nil, firstAt = where, fish = J.IsFish(id, quality) }
        log.fish[id] = e
    end
    e.n = e.n + count
    e.name, e.icon = Text(name) or e.name, icon or e.icon
    local weight, best, was
    if e.fish then
        weight = J.Weigh(id, e.name, curious)
        if not e.best or weight > e.best then
            best, was = not new, e.best
            e.best, e.bestAt = weight, where
        end
    end
    local zone = log.zones[where]
    if not zone then
        zone = { n = 0, fish = {} }
        log.zones[where] = zone
    end
    zone.map = map or zone.map
    zone.n = zone.n + count
    zone.fish[id] = (zone.fish[id] or 0) + count
    log.total = log.total + count
    self.session.caught = self.session.caught + count
    self.tally[id] = (self.tally[id] or 0) + count
    table.insert(self.feed, 1, { id = id, name = e.name, icon = e.icon, weight = weight, best = best, new = new,
                                 at = GetTime() })
    while #self.feed > J.FEED do table.remove(self.feed) end
    local shown = e.name or ("item:" .. id)
    if new then
        if weight then ns.Say(L["New in your fish journal: %s, %s."]:format(shown, J.Pounds(weight)))
        else ns.Say(L["New in your fish journal: %s."]:format(shown)) end
    elseif best and was then
        ns.Say(L["Your heaviest %s yet: %s (it was %s)."]:format(shown, J.Pounds(weight), J.Pounds(was)))
    end
    if ns.Readout then ns.Readout.Catch(shown, e.icon or icon, quality, count, weight, new, best) end   -- across the screen
    return e, weight, new, best
end

function J:Away()
    local log = J.Log()
    self:Water()
    log.away = log.away + 1
    self.session.away = self.session.away + 1
    ns.Note("fishing: one got away (%d this session)", self.session.away)
    if ns.FishGame then ns.FishGame:Away() end
    Changed()
end

-- Was this loot fished up? (the game says; without its word, by whether your line was just out)
function J.Fishy()
    if IsFishingLoot then
        local ok, yes = pcall(IsFishingLoot)
        if ok then return ns.Yes(yes) end
    end
    return (J.lineAt and GetTime() - J.lineAt < 3) and true or false
end

local seen = false            -- this loot has been read already

-- Read what is on the line (called when the loot is ready, and before the catch is taken for you)
function J:Read()
    if seen or not self.active or not ns.db.fishJournal then return end
    if not (GetNumLootItems and GetLootSlotLink) or not J.Fishy() then return end
    seen = true
    local cast = self.cast or self.last
    if cast then cast.caught = true end
    local any = false
    local curious = ns.FishGame and ns.FishGame:Take() or 0
    for i = 1, GetNumLootItems() do
        local okL, link = pcall(GetLootSlotLink, i)
        local id = okL and Text(link) and tonumber(link:match("item:(%d+)"))
        if id then
            local icon, name, count, quality
            if GetLootSlotInfo then
                local ok, a, b, c, _, q = pcall(GetLootSlotInfo, i)
                if ok then icon, name, count, quality = a, Text(b), tonumber(c), tonumber(q) end
            end
            name = name or link:match("%[(.-)%]")
            self:Catch(id, name, (type(icon) == "number" or type(icon) == "string") and icon or nil, quality, count,
                curious)
            any = true
        end
    end
    if any then
        if ns.FishGame then ns.FishGame:Landed() end
        Changed()
    end
end

---------------------------------------------------------------------------
-- This water's fish
---------------------------------------------------------------------------
-- What can be caught where you stand, as far as it is known: a list of { id, name, icon, known }. With
-- Improved Forever's fishing data loaded the whole list is known, and what you have not landed here stays
-- hidden; without it the list is what you have landed here, with places left for what you have not.
function J.Waters(max)
    max = max or J.SLOTS
    local log = J.Log()
    local zone = log.zones[(J.Where())]
    local caught = zone and zone.fish or {}
    local out, have = {}, {}
    local likely = ns.CastBar and ns.CastBar.LikelyCatch and ns.CastBar.LikelyCatch(max)
    for _, f in ipairs(likely or {}) do
        if f.id and not have[f.id] then
            have[f.id] = true
            out[#out + 1] = { id = f.id, name = f.name, icon = f.icon, known = caught[f.id] ~= nil }
        end
    end
    local mine = {}
    for id, n in pairs(caught) do
        local e = log.fish[id]
        if not have[id] and e and e.fish then mine[#mine + 1] = { id = id, n = n } end
    end
    table.sort(mine, function(a, b) if a.n ~= b.n then return a.n > b.n end return a.id < b.id end)
    for _, m in ipairs(mine) do
        if #out >= max then break end
        local e = log.fish[m.id]
        out[#out + 1] = { id = m.id, name = e.name, icon = e.icon, known = true }
    end
    if not likely then
        while #out < J.MIN do out[#out + 1] = { known = false } end
    end
    return out
end

---------------------------------------------------------------------------
-- Watching the line and the catch
---------------------------------------------------------------------------
local events = CreateFrame("Frame")
events:SetScript("OnEvent", ns.Protect(function(_, event, a, b)
    if event == "LOOT_READY" or event == "LOOT_OPENED" then
        J:Read()
    elseif event == "LOOT_CLOSED" then
        seen = false
    elseif event == "UI_ERROR_MESSAGE" then
        -- "Your fish got away!"
        local said = ERR_FISH_ESCAPED
        if type(said) == "string" and (a == said or b == said) then
            local cast = J.cast or J.last
            if cast and cast.away then return end
            if cast then cast.away = true end
            J:Away()
        end
    elseif a == "player" then
        if event == "UNIT_SPELLCAST_CHANNEL_START" then
            if not (ns.Fishing and ns.Fishing.LineOut()) then return end
            local ok, _, _, _, _, stop = pcall(UnitChannelInfo, "player")
            J.cast = { ends = (ok and type(stop) == "number" and not ns.IsSecret(stop)) and stop / 1000 or nil }
            J.lineAt, seen = GetTime(), false
        elseif J.cast then                              -- the line came in
            local cast = J.cast
            J.cast, J.last, J.lineAt = nil, cast, GetTime()
            if cast.ends and GetTime() >= cast.ends - 0.5 then
                -- it ran its whole time: if nothing is landed in the next moment, the fish is gone
                C_Timer.After(1, ns.Protect(function()
                    if cast.caught or cast.away then return end
                    cast.away = true
                    J:Away()
                end))
            end
        end
    end
end))

local EVENTS = { "LOOT_READY", "LOOT_OPENED", "LOOT_CLOSED", "UI_ERROR_MESSAGE", "UNIT_SPELLCAST_CHANNEL_START",
                 "UNIT_SPELLCAST_CHANNEL_STOP" }

function J:Apply(run)
    local want = run and true or false
    if want == self.active then return end
    self.active = want
    if want then
        for _, e in ipairs(EVENTS) do pcall(events.RegisterEvent, events, e) end
    else
        events:UnregisterAllEvents()
        self.cast = nil
    end
end

function J.Describe()
    local log = ns.db and ns.db.fishLog or {}
    local kinds, waters = 0, 0
    for _ in pairs(log.fish or {}) do kinds = kinds + 1 end
    for _ in pairs(log.zones or {}) do waters = waters + 1 end
    return ("watching %s, journal %s: landed %s (%d kinds, %d waters), got away %s; this session %d and %d; the game tells fished loot apart %s, has the got-away text %s"):format(
        tostring(J.active), tostring(ns.db and ns.db.fishJournal), tostring(log.total), kinds, waters, tostring(log.away),
        J.session.caught, J.session.away, tostring(IsFishingLoot ~= nil), tostring(type(ERR_FISH_ESCAPED) == "string"))
end

ns.RegisterModule("fishlog", J)
