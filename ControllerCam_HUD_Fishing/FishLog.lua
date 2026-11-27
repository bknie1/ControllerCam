-- ControllerCam HUD: the fish journal's book.
-- Every catch is written down: what it was, how many, where and when first, and a weight. The game has no
-- weights for fish, so the weight is made up for fun: each kind has its own usual size, a catch falls
-- somewhere around it, and a big one is rare. A fish that names its own weight ("22 Pound Catfish") weighs
-- from that to just under the next pound, to the tenth (22.0 to 22.9). Also counted: the fish that got away (the game said so, or the line ran out with nothing landed).
-- Kept with the HUD's settings, for the account; nothing is read from or sent anywhere else.

local ADDON = ...
local ns = ControllerCamHUD.ns            -- the HUD's own namespace: this file is one of its modules (Modules.lua)
local L = ns.L

local J = { active = false, session = { caught = 0, away = 0 }, feed = {}, tally = {} }
ns.FishLog = J

J.FEED = 4                    -- recent catches kept for the fishing interface
J.JUST = 3                    -- seconds after the line came in: what the game says then is about that line
J.SLOTS = 18                  -- places for a water's fish: three rows of them


local function Text(v) return (type(v) == "string" and not ns.IsSecret(v)) and v or nil end

-- Things that come up on a line and are of a kind the game files with food or trade goods, but are no fish:
-- Stranglekelp (a herb) and the Rumsey Rums (drinks)
J.NOT_FISH = { [3820] = true, [20709] = true, [21114] = true, [21151] = true }
local HERB = 9                -- the trade goods' sort for herbs: none of them is a fish

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
            if J.NOT_FISH[id] then                  -- written down as a fish once: no weight to its name
                log.fish[id].fish, log.fish[id].best, log.fish[id].bestAt = false, nil, nil
            end
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
    if J.NOT_FISH[id] then return false end
    local get = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if get then
        local ok, _, _, _, _, _, classID, subID = pcall(get, id)
        if ok and type(classID) == "number" then
            return classID == 0 or (classID == 7 and subID ~= HERB)
        end
    end
    return type(quality) == "number" and quality >= 1
end

-- The usual weight of a kind, in pounds; true when the fish says its own weight
function J.Base(id, name)
    local said = type(name) == "string"
        and tonumber(name:match("(%d+)[ %-]?[Pp]ound") or name:match("(%d+) ?[Ll][Bb][Ss]?%f[%A]"))
    if said then return said, true end
    return 0.4 + ((id * 7919) % 97) / 97 * 5.2
end

-- The weight of one catch: around the usual weight of its kind, and now and then a big one. A fish made
-- curious in the game beside the fishing interface (FishGame.lua; 0-1) is the heavier for it.
function J.Weigh(id, name, curious)
    local base, said = J.Base(id, name)
    local r = (J.random or math.random)()
    curious = ns.Clamp(tonumber(curious) or 0, 0, 1)
    if said then                                         -- ten weights it can be: its own pounds and 0 to 9 tenths
        local tenths = math.floor(ns.Clamp(r + 0.3 * curious, 0, 0.999) * 10)
        return (base * 10 + tenths) / 10
    end
    local more = 1 + (ns.FishGame and ns.FishGame.BONUS or 0) * curious
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
    if ns.Commentary then                                  -- (you may have something to say about it)
        local ok, err = pcall(ns.Commentary.Catch, { id = id, name = shown, weight = weight, fish = e.fish, new = new,
            best = best, was = was, entry = e, where = where, map = map, count = self.tally[id],
            away = self.session.away, total = log.total })
        if not ok then ns.Error(err) end
    end
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
-- Which fish swim where (by the game's map number): our own short list
---------------------------------------------------------------------------
-- Put together zone by zone from what two public Classic fishing references agree on (2026-11). It leaves out
-- on purpose whatever could leave a "?" nobody can fill: fish tied to pools, fish only one reference had (or
-- barely had), and fish of one corner of a zone. So it is not the whole water: a zone can give more than this.
-- Coast and inland are one zone here. Not checked against this game beyond the catches seen so far.
local SMALL, SNAPPER, CATFISH, TROUT, FRENZY = 6291, 6289, 6308, 8365, 6317
local MACKEREL, ALBACORE, COD, YELLOWTAIL = 6303, 6361, 6362, 4603
local REDGILL, NIGHTFIN, SUNSCALE, WHITESCALE, MIGHTFISH = 13758, 13759, 13760, 13889, 13754
local SQUID, BASS = 13755, 13756

-- In season only: { from (month * 100 + day), to }; one that runs over the new year has from after to
J.SEASON = { [SQUID] = { 923, 319 }, [BASS] = { 320, 922 } }

local function Zone(...)
    local out = {}
    for _, part in ipairs({ ... }) do
        if type(part) == "table" then
            for _, id in ipairs(part) do out[#out + 1] = id end
        else
            out[#out + 1] = part
        end
    end
    return out
end
local INLAND = { REDGILL, NIGHTFIN, SUNSCALE }
local WARM_SEA = { COD, YELLOWTAIL }
local DEEP_SEA = { COD, YELLOWTAIL, MIGHTFISH, SQUID, BASS }
local HOME = { SMALL, SNAPPER, CATFISH }

J.ZONES = {
    -- Kalimdor
    [1411] = Zone(SMALL, SNAPPER, MACKEREL),                         -- Durotar
    [1412] = Zone(SMALL, SNAPPER),                                   -- Mulgore
    [1413] = Zone(SMALL, SNAPPER, MACKEREL, ALBACORE),               -- The Barrens
    [1438] = Zone(SMALL, SNAPPER, MACKEREL),                         -- Teldrassil
    [1439] = Zone(HOME, MACKEREL, ALBACORE),                         -- Darkshore
    [1440] = Zone(SNAPPER, CATFISH, ALBACORE),                       -- Ashenvale
    [1441] = Zone(TROUT),                                            -- Thousand Needles
    [1442] = Zone(SNAPPER),                                          -- Stonetalon Mountains
    [1443] = Zone(CATFISH, TROUT, WARM_SEA),                         -- Desolace
    [1444] = Zone(TROUT, INLAND, DEEP_SEA),                          -- Feralas
    [1445] = Zone(CATFISH, TROUT, WARM_SEA),                         -- Dustwallow Marsh
    [1446] = Zone(DEEP_SEA),                                         -- Tanaris
    [1447] = Zone(TROUT, INLAND, DEEP_SEA),                          -- Azshara
    [1448] = Zone(TROUT, INLAND),                                    -- Felwood
    [1449] = Zone(TROUT, INLAND),                                    -- Un'Goro Crater
    [1450] = Zone(TROUT, INLAND),                                    -- Moonglade
    [1452] = Zone(INLAND, WHITESCALE),                               -- Winterspring
    [1454] = Zone(HOME),                                             -- Orgrimmar
    [1456] = Zone(SMALL, SNAPPER),                                   -- Thunder Bluff
    [1457] = Zone(HOME),                                             -- Darnassus
    -- Eastern Kingdoms
    [1416] = Zone(CATFISH, TROUT),                                   -- Alterac Mountains
    [1417] = Zone(CATFISH, TROUT, WARM_SEA),                         -- Arathi Highlands
    [1420] = Zone(SMALL, SNAPPER, MACKEREL),                         -- Tirisfal Glades
    [1421] = Zone(HOME, MACKEREL, ALBACORE),                         -- Silverpine Forest
    [1422] = Zone(TROUT, INLAND),                                    -- Western Plaguelands
    [1423] = Zone(INLAND, WHITESCALE),                               -- Eastern Plaguelands
    [1424] = Zone(SNAPPER, CATFISH, ALBACORE),                       -- Hillsbrad Foothills
    [1425] = Zone(TROUT, INLAND, DEEP_SEA),                          -- The Hinterlands
    [1426] = Zone(SMALL, SNAPPER),                                   -- Dun Morogh
    [1429] = Zone(SMALL, SNAPPER),                                   -- Elwynn Forest
    [1430] = Zone(INLAND, WHITESCALE),                               -- Deadwind Pass
    [1431] = Zone(HOME),                                             -- Duskwood
    [1432] = Zone(SMALL, SNAPPER, FRENZY),                           -- Loch Modan
    [1433] = Zone(SNAPPER, CATFISH),                                 -- Redridge Mountains
    [1434] = Zone(CATFISH, TROUT, WARM_SEA),                         -- Stranglethorn Vale
    [1435] = Zone(TROUT, WARM_SEA),                                  -- Swamp of Sorrows
    [1436] = Zone(HOME, MACKEREL, ALBACORE),                         -- Westfall
    [1437] = Zone(SNAPPER, CATFISH, ALBACORE),                       -- Wetlands
    [1453] = Zone(HOME),                                             -- Stormwind City
    [1458] = Zone(SMALL, SNAPPER),                                   -- Undercity
}

function J.InSeason(id, today)
    local s = J.SEASON[id]
    if not s then return true end
    if not today then
        if not date then return false end
        today = (tonumber(date("%m")) or 0) * 100 + (tonumber(date("%d")) or 0)
    end
    if s[1] <= s[2] then return today >= s[1] and today <= s[2] end
    return today >= s[1] or today <= s[2]
end

-- The fish our list has for a map, today
function J.Listed(map)
    local out = {}
    for _, id in ipairs(map and J.ZONES[map] or {}) do
        if J.InSeason(id) then out[#out + 1] = id end
    end
    return out
end

---------------------------------------------------------------------------
-- This water's fish
---------------------------------------------------------------------------
-- What can be caught where you stand, as far as it is known: a list of { id, name, icon, known }, and whether
-- that is the whole water. With Improved Forever's fishing data loaded it is. Without it our own list says
-- which fish are sure to be in this zone, and what else you have landed here joins them. Either way each fish
-- has one place, a "?" until you land it: no "?" stands for nothing.
function J.Waters(max)
    max = max or J.SLOTS
    local log = J.Log()
    local where, map = J.Where()
    local zone = log.zones[where]
    local caught = zone and zone.fish or {}
    local out, have = {}, {}
    local likely = ns.CastBar and ns.CastBar.LikelyCatch and ns.CastBar.LikelyCatch(max)
    for _, f in ipairs(likely or {}) do
        if f.id and not have[f.id] then
            have[f.id] = true
            out[#out + 1] = { id = f.id, name = f.name, icon = f.icon, known = caught[f.id] ~= nil }
        end
    end
    if not likely then
        for _, id in ipairs(J.Listed(map)) do
            if #out >= max then break end
            local e = log.fish[id] or {}
            have[id] = true
            out[#out + 1] = { id = id, name = e.name, icon = e.icon, known = caught[id] ~= nil }
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
    return out, likely ~= nil
end

---------------------------------------------------------------------------
-- What the game says as a line comes in with nothing
---------------------------------------------------------------------------
-- "Your fish got away!" and "No fish are hooked.", as an error, as a notice or as a line of chat: which of them
-- a game uses differs. The words are the first or the second thing the event hands over.
local function Lost(first, second)
    for _, name in ipairs({ "ERR_FISH_ESCAPED", "ERR_FISH_NOT_HOOKED" }) do
        local said = _G[name]
        if type(said) == "string" and (first == said or second == said) then return true end
    end
    return false
end

function J:Said(event, a, b)
    local first, second = Text(a), Text(b)
    local now = GetTime()
    local just = J.lineAt and now - J.lineAt < J.JUST
    -- (in the debug report: what this game says at the water, should a lost fish go uncounted again)
    if event ~= "CHAT_MSG_SYSTEM" and (J.cast or just) then
        ns.Note("fishing: with the line, the game said (%s): %s", event, tostring(second or first))
    end
    if not Lost(first, second) then return end
    local cast = J.cast or (just and J.last) or nil
    if cast then
        if cast.away then return end                     -- this line's fish is counted already
        cast.away = true
    elseif J.saidAt and now - J.saidAt < 1 then          -- a line we did not see: the same words twice
        return
    end
    J.saidAt = now
    J:Away()
end

---------------------------------------------------------------------------
-- Watching the line and the catch
---------------------------------------------------------------------------
local events = CreateFrame("Frame")
events:SetScript("OnEvent", ns.Protect(function(_, event, a, b, spell)
    if event == "LOOT_READY" or event == "LOOT_OPENED" then
        J:Read()
    elseif event == "LOOT_CLOSED" then
        seen = false
    elseif event == "UI_ERROR_MESSAGE" or event == "UI_INFO_MESSAGE" or event == "CHAT_MSG_SYSTEM" then
        J:Said(event, a, b)
    elseif a == "player" then
        if event == "UNIT_SPELLCAST_CHANNEL_START" then
            if not (ns.Fishing and ns.Fishing.LineOut()) then
                if ns.Fishing and ns.Fishing.HasPole() then
                    ns.Note("fishing: a channel began that is not taken for your line (spell %s)", tostring(ns.IsSecret(spell) and "kept secret" or spell))
                end
                return
            end
            local ok, _, _, _, _, stop = pcall(UnitChannelInfo, "player")
            J.cast = { ends = (ok and type(stop) == "number" and not ns.IsSecret(stop)) and stop / 1000 or nil }
            J.lineAt, seen = GetTime(), false
        elseif J.cast then                              -- the line came in
            local cast = J.cast
            J.cast, J.last, J.lineAt = nil, cast, GetTime()
            ns.Note("fishing: the line came in %s", (not cast.ends and "(its length not said)")
                or (GetTime() >= cast.ends - 0.5 and "at its full time") or "early")
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

local EVENTS = { "LOOT_READY", "LOOT_OPENED", "LOOT_CLOSED", "UI_ERROR_MESSAGE", "UI_INFO_MESSAGE",
                 "CHAT_MSG_SYSTEM", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP" }

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
