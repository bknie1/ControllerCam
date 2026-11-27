-- ControllerCam HUD: your character's commentary. Now and then you have something to say about what just
-- happened: a fish you landed, a chest you looted, a boss that fell, a place you walked into, a job you finished
-- (Remarks.lua).
--   * out loud: in quotes, in your race's voice, your portrait's lips moving;
--   * a thought: pale, in plain words, lips still.
-- On screen only: nothing is ever sent to chat, nobody else sees or hears it.
-- While the fishing interface is up a remark takes over your card there; otherwise a card of its own stands low
-- in the middle of the screen, fades, and takes no clicks. Never in a fight: what happens in one is said after.
-- Not to chatter: most catches pass without a word, thoughts on the road are minutes apart, a line does not
-- come round again until the others like it have had their turn, and lore is told once.
-- Under the narrative's switch, with a switch of its own besides (/cchud commentary).

local ADDON = ...
local ns = ControllerCamHUD.ns            -- the HUD's own namespace: this file is one of its modules (Modules.lua)
local L = ns.L

local N = ns.Narrative
local R = ns.Remarks
local M = {}
ns.Commentary = M

M.HOLD = 12            -- seconds a remark stays
M.FADE = 1.5           -- the last of them, fading (on its own card)
M.QUIET = 60           -- an ordinary catch is spoken of only this long after the last remark,
M.CHANCE = 0.25        -- and then this often
M.NEW_ALOUD = 0.5      -- how often a fish new to the journal gets a word out loud too
M.BETTER = 1.1         -- a record worth a cheer: this much over the old one
M.BIG, M.SMALL = 1.4, 0.7          -- a weight worth a word: this far from its kind's usual one
M.REPEAT = 0.3         -- how often a boss you have beaten before is worth a thought
M.TWICE = 30           -- the game may tell one kill two ways: once within this long
M.AMBIENT = 180        -- thoughts on the road (a place, a job done) at least this far apart
M.WAIT = 90            -- what happened in a fight is still said this long after
M.SETTLE = 3           -- after walking into a place, before a thought about it
M.EVERY = 10           -- every so many jobs done in a zone get a word
M.TREASURE = 60        -- finds at least this far apart, unless there is something rare in one
M.TREASURE_ALOUD = 0.5 -- how often a find gets a word out loud too (always, with something rare in it)
M.PRIZE = 3            -- the quality that is rare
M.OPENING = 10         -- a cast this long ago still says what the loot came from
M.Y = 260              -- how high above the bottom of the screen the card stands
M.THOUGHT = "ffaebfd6" -- a thought's pale colour

-- how much a remark matters: a lesser one does not push a greater one off the card
local LESSER, ROAD, GREAT, BOSS = 1, 2, 3, 4

local Num, Try = N.Num, N.Try
local function Str(v) v = ns.Plain(v); return (type(v) == "string" and v ~= "") and v or nil end
local function Roll() return (M.random or math.random)() end

function M.On() return M.running == true and N.On() and ns.db.commentary ~= false end

---------------------------------------------------------------------------
-- What is remembered: the lore you have heard (for the account), and for each character the places walked into,
-- the bosses beaten and the jobs done by zone, counted from when this began to count
---------------------------------------------------------------------------
local function Clean(old)
    old = type(old) == "table" and old or {}
    local out = { told = {}, chars = {}, events = {} }
    for k, v in pairs(type(old.told) == "table" and old.told or {}) do
        if type(k) == "string" and v then out.told[k] = true end
    end
    for k, c in pairs(type(old.chars) == "table" and old.chars or {}) do
        if type(k) == "string" and type(c) == "table" then
            out.chars[k] = { zones = type(c.zones) == "table" and c.zones or {},
                             bosses = type(c.bosses) == "table" and c.bosses or {},
                             quests = type(c.quests) == "table" and c.quests or {},
                             finds = tonumber(c.finds) }
        end
    end
    for k, v in pairs(type(old.events) == "table" and old.events or {}) do
        if type(k) == "string" and tonumber(v) then out.events[k] = tonumber(v) end
    end
    return out
end
ns.RegisterSaved("remarkMemory", Clean)

function M.Memory()
    if type(ns.db.remarkMemory) ~= "table" then ns.db.remarkMemory = Clean(nil) end
    return ns.db.remarkMemory
end

-- This character's part of it
function M.Mine()
    local name = Str(Try(UnitName, "player")) or "?"
    local realm = Str(Try(GetNormalizedRealmName)) or Str(Try(GetRealmName)) or ""
    local chars = M.Memory().chars
    local key = name .. "-" .. realm
    if not chars[key] then chars[key] = { zones = {}, bosses = {}, quests = {} } end
    return chars[key]
end

---------------------------------------------------------------------------
-- Choosing a line
---------------------------------------------------------------------------
-- One of a pool, none again until all of it has had a turn (and never the same one twice running)
M.bags = {}
function M.Pick(key, pool)
    local n = pool and #pool or 0
    if n == 0 then return nil end
    local bag = M.bags[key]
    if not bag then bag = {}; M.bags[key] = bag end
    if not bag.left or #bag.left == 0 then
        bag.left = {}
        for i = 1, n do if i ~= bag.last or n == 1 then bag.left[#bag.left + 1] = i end end
        bag.refill = n > 1 and bag.last or nil          -- (the one just said joins again after the first draw)
    end
    local at = math.min(#bag.left, math.floor(Roll() * #bag.left) + 1)
    local i = table.remove(bag.left, at)
    if bag.refill then
        bag.left[#bag.left + 1] = bag.refill
        bag.refill = nil
    end
    bag.last = i
    return pool[i]
end

-- Lore: told once, and remembered (nil when it has been told)
local function Untold(key, line)
    if not line or M.Memory().told[key] then return nil end
    return line, key
end

-- A line out loud, in your race's voice (nil for a race without one: then only the thought)
function M.Aloud(occasion)
    local race = N.Race()
    local pool = race and R.said[occasion] and R.said[occasion][race]
    return pool and M.Pick(occasion .. ":" .. race, pool) or nil
end

---------------------------------------------------------------------------
-- Saying it
---------------------------------------------------------------------------
-- A remark's words as the card shows them: what is said out loud in quotes, the thought pale under it
function M.Words(r)
    local parts = {}
    if r.said then parts[#parts + 1] = L["“%s”"]:format(r.said) end
    if r.thought then parts[#parts + 1] = "|c" .. M.THOUGHT .. r.thought .. "|r" end
    return table.concat(parts, "\n")
end

-- The remark on show now, or nil
function M.Current()
    local r = M.now
    if r and M.On() and GetTime() < r.till then return r end
    return nil
end

-- Who says it: you, lips still for a thought
function M.Speaker(r)
    local me = N.Me()
    me.still = not r.said
    return me
end

local function Fighting()
    return ns.Yes(Try(InCombatLockdown)) or ns.Yes(Try(UnitAffectingCombat, "player"))
end

local function FishCard()
    local host = rawget(_G, "ControllerCamHUD_FishPanel")
    return host and ns.ShownPlain(host) and host or nil
end

local function Spot()
    local spot = M.spot
    if not spot then
        spot = CreateFrame("Frame", "ControllerCamHUD_RemarkSpot", UIParent)
        spot:SetSize(380, 1)
        spot:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, M.Y)
        spot:SetFrameStrata("MEDIUM")
        M.spot = spot
    end
    spot:Show()
    return spot
end

local driver = CreateFrame("Frame")

function M.Clear()
    M.now, M.waiting = nil, nil
    driver:SetScript("OnUpdate", nil)
    N.Hush("remark")
    if M.spot then M.spot:Hide() end
end

-- Where it shows: your card at the water while the fishing interface is up, else a card of its own
function M.Show()
    local r = M.Current()
    if not r then return end
    if FishCard() then
        if M.spot then M.spot:Hide() end
        N.Hush("remark")
        M.at = "fish"
        N.Fishing()
    else
        M.at = "own"
        local card = N.Speak("remark", Spot(), M.Speaker(r), M.Words(r))
        if card then card:SetAlpha(ns.Clamp((r.till - GetTime()) / M.FADE, 0, 1)) end
    end
end

local since = 0
local Tick = ns.Protect(function(_, dt)
    local r = M.Current()
    if not r then
        local waiting = M.waiting
        M.Clear()
        M.waiting = waiting
        if N.Fishing then N.Fishing() end             -- (your card at the water goes back to what it said)
        return
    end
    since = since + (dt or 0)
    if M.at == "own" and r.till - GetTime() < M.FADE and N.cards.remark then
        N.cards.remark:SetAlpha(ns.Clamp((r.till - GetTime()) / M.FADE, 0, 1))
    end
    if since < 0.25 then return end
    since = 0
    if (FishCard() and "fish" or "own") ~= M.at then M.Show() end      -- (the fishing interface came or went)
end)

-- r = { said, thought, rank, lore = lore to remember as told once it is on show }. Held back in a fight; dropped
-- while something greater is on show.
function M.Say(r)
    if not (M.On() and r and (r.said or r.thought)) then return false end
    if Fighting() then
        if not M.waiting or r.rank >= M.waiting.rank then
            r.since = GetTime()
            M.waiting = r
        end
        return true
    end
    local now = M.Current()
    if now and now.rank > r.rank then return false end
    r.till = GetTime() + M.HOLD
    M.now, M.saidAt = r, GetTime()
    if r.lore then M.Memory().told[r.lore] = true end      -- (heard now: not before)
    since = 0
    driver:SetScript("OnUpdate", Tick)
    M.Show()
    return true
end

---------------------------------------------------------------------------
-- Fish
---------------------------------------------------------------------------
-- The water's own line, or a fish's: the journal's lore, told here once
local function FishLore(id) return Untold("fish:" .. id, ns.FishLore and ns.FishLore.fish[id]) end
local function WaterLore(map) return map and Untold("water:" .. map, ns.FishLore and ns.FishLore.waters[map]) end

-- What sort of fish it is, once for each sort while you play
M.sorts = {}
local function Sort(id)
    local kind = R.kind[id]
    if kind and not M.sorts[kind] then return R.kinds[kind], kind end
    return nil
end

local function Join(first, second)
    return second and (first .. " " .. second) or first
end

-- The things worth thinking about an ordinary catch, each { what = its sort of thought, line = the words, or
-- pool = lines to choose from, lore = what to remember as told, sort = the sort of fish spoken of }
-- c = { id, name, weight, entry (the journal's), where, map, count (this session's of this kind), away, total }
function M.CatchThoughts(c)
    local J, out = ns.FishLog, {}
    local e, w = c.entry or {}, c.weight
    local function Add(what, line, lore, sort)
        if line then out[#out + 1] = { what = what, line = line, lore = lore, sort = sort } end
    end
    local function From(what, pool) out[#out + 1] = { what = what, pool = pool } end
    local base, own = nil, false
    if J and w then base, own = J.Base(c.id, c.name) end
    if base and not own then
        if w >= base * M.BIG then From("big", R.big) end
        if w <= base * M.SMALL then From("small", R.small) end
    end
    if (e.n or 0) >= 5 then Add("count", L["That makes %d of these in my journal."]:format(e.n)) end
    if e.firstAt and e.firstAt ~= "" and e.firstAt ~= c.where then
        Add("first", L["My journal's first of these came from %s."]:format(e.firstAt))
    end
    if w and not own and e.best and e.bestAt and e.bestAt ~= "" and w < e.best * 0.75 then
        Add("heaviest", L["My heaviest of these is still %s, landed at %s."]:format(J.Pounds(e.best), e.bestAt))
    end
    if (c.count or 0) >= 3 then Add("session", L["That's %d of these since I got to this water."]:format(c.count)) end
    if (c.away or 0) >= 2 then Add("away", L["%d got away since I started here. This one didn't."]:format(c.away)) end
    if (c.total or 0) > 0 and c.total % 25 == 0 then Add("total", L["Catch number %d for the journal."]:format(c.total)) end
    local sortLine, sort = Sort(c.id)
    Add("sort", sortLine, nil, sort)
    local lore, key = FishLore(c.id)
    Add("lore", lore, key)
    local water, waterKey = WaterLore(c.map)
    Add("water", water, waterKey)
    From("musing", R.musing)
    return out
end

-- One of them: every sort of thought that fits gets its turn before one comes round again
M.had = {}
function M.Choose(thoughts)
    local fresh = {}
    for _, t in ipairs(thoughts) do
        if not M.had[t.what] then fresh[#fresh + 1] = t end
    end
    if #fresh == 0 then
        for _, t in ipairs(thoughts) do
            if t.what ~= M.lastWhat or #thoughts == 1 then fresh[#fresh + 1] = t end
            M.had[t.what] = nil
        end
    end
    local t = fresh[math.min(#fresh, math.floor(Roll() * #fresh) + 1)]
    if t then M.had[t.what], M.lastWhat = true, t.what end
    return t
end

-- A catch the journal has just written down. c as above, and fish = it is a fish, new = not in the journal
-- before, best = your heaviest of it, was = the old heaviest
function M.Catch(c)
    if not M.On() then return false end
    local J = ns.FishLog
    local name = c.name or ("item:" .. tostring(c.id))
    if c.id and R.boxes[c.id] then return M.Treasure({ hauled = name }) end
    local lead = c.weight and L["%s, %s."]:format(name, J.Pounds(c.weight)) or L["%s."]:format(name)
    if c.fish and c.new then
        local line, key = FishLore(c.id)
        local sortLine, sort
        if not line then sortLine, sort = Sort(c.id) end
        local thought = Join(lead .. " " .. L["A new one for my journal."], line or sortLine or M.Pick("new", R.new))
        local said = Roll() < M.NEW_ALOUD and M.Aloud("new") or nil
        if not M.Say({ said = said, thought = thought, rank = GREAT, lore = key }) then return false end
        if sort then M.sorts[sort] = true end
        return true
    end
    if c.fish and c.best and c.was and c.weight and c.weight >= c.was * M.BETTER then
        local thought = lead .. " " .. L["My best before was %s."]:format(J.Pounds(c.was))
        return M.Say({ said = M.Aloud("record"), thought = thought, rank = GREAT })
    end
    -- the ordinary catch: mostly without a word
    if M.saidAt and GetTime() - M.saidAt < M.QUIET then return false end
    if Roll() >= M.CHANCE then return false end
    local pick = c.fish and M.Choose(M.CatchThoughts(c)) or { what = "junk", pool = R.junk }
    local line = pick.line or M.Pick(pick.what, pick.pool)
    if not (line and M.Say({ thought = lead .. " " .. line, rank = LESSER, lore = pick.lore })) then return false end
    if pick.sort then M.sorts[pick.sort] = true end
    return true
end

---------------------------------------------------------------------------
-- Treasure: a chest in the world, a box you open, a box on the line
---------------------------------------------------------------------------
-- find = { hauled = the name of a box fished up, or best = the name of the finest thing in it (uncommon or
-- better), quality = that thing's }
function M.Treasure(find)
    if not M.On() then return false end
    local mine = M.Mine()
    mine.finds = (tonumber(mine.finds) or 0) + 1
    local prize = (find.quality or 0) >= M.PRIZE
    if not prize and M.treasureAt and GetTime() - M.treasureAt < M.TREASURE then return false end
    local thought
    if find.hauled then
        thought = L["%s."]:format(find.hauled) .. " " .. M.Pick("hauled", R.hauled)
    else
        local line
        if prize then
            line = M.Pick("prize", R.prize)
        elseif mine.finds % M.EVERY == 0 then
            line = L["%d finds like this since I started keeping count."]:format(mine.finds)
        else
            line = M.Pick("treasure", R.treasure)
        end
        thought = find.best and (L["%s."]:format(find.best) .. " " .. line) or line
    end
    local said = (prize or Roll() < M.TREASURE_ALOUD) and M.Aloud("treasure") or nil
    if not M.Say({ said = said, thought = thought, rank = prize and GREAT or ROAD }) then return false end
    M.treasureAt = GetTime()
    return true
end

-- Ore, herbs and a disenchanted item come out of a loot window too: told by the cast that opened it
local WORK = { 2366, 2368, 3570, 11993,            -- Herb Gathering, each rank
               2575, 2576, 3564, 10248,            -- Mining
               13262 }                             -- Disenchant
local function SpellName(id)
    return Str(Try(C_Spell and C_Spell.GetSpellName, id)) or Str(Try(GetSpellInfo, id))
end
local function Work(spell)
    local name = spell and SpellName(spell)
    for _, id in ipairs(WORK) do
        if spell == id or (name and name == SpellName(id)) then return true end
    end
    return false
end

function M.Cast(spell)
    M.cast = { spell = Num(spell), at = GetTime() }
end

-- Where the loot window's things come from: "GameObject" (a thing in the world), "Item" (one you opened),
-- "Creature"...; nil where the game does not say
local function Source(n)
    local kind, first
    for i = 1, n do
        local guid = Str(Try(GetLootSourceInfo, i))
        local this = guid and guid:match("^(%a+)%-")
        if this then
            if kind and this ~= kind then return nil end
            kind, first = this, first or guid
        end
    end
    return kind, first
end

local TRADE, QUEST = 7, 12                          -- the game's sorts of item
local MONEY = (Enum and Enum.LootSlotType and Enum.LootSlotType.Money) or 2
M.opened = {}                                       -- what has been counted this session (a chest left half full)

-- A loot window: is it treasure? A chest or crate in the world, or something you opened, with coin or something
-- uncommon in it (in the world, two things or more will do). Never a corpse, a catch, ore, herbs or what a quest
-- wants.
function M.Loot()
    if M.lootSeen or not M.On() then return end
    local n = Num(Try(GetNumLootItems)) or 0
    if n == 0 then return end
    M.lootSeen = true
    if ns.Yes(Try(IsFishingLoot)) or (not IsFishingLoot and ns.FishLog and ns.FishLog.Fishy()) then return end
    local kind, from = Source(n)
    if kind ~= "GameObject" and kind ~= "Item" then return end
    if from and M.opened[from] then return end
    local cast = M.cast
    if cast and GetTime() - cast.at < M.OPENING and Work(cast.spell) then return end
    local money, things, trade, best, quality = false, 0, 0, nil, 0
    local instant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    for i = 1, n do
        local link = Str(Try(GetLootSlotLink, i))
        local id = link and tonumber(link:match("item:(%d+)"))
        local ok, _, name, _, _, q = pcall(GetLootSlotInfo or function() end, i)
        name, q = ok and Str(name) or nil, ok and Num(q) or nil
        if Num(Try(GetLootSlotType, i)) == MONEY then
            money = true
        elseif id then
            things = things + 1
            local okI, _, _, _, _, _, class = pcall(instant or function() end, id)
            class = okI and Num(class) or nil
            if class == QUEST then return end
            if class == TRADE then trade = trade + 1 end
            if q and q >= 2 and q > quality then best, quality = name or link:match("%[(.-)%]"), q end
        elseif name then
            money = true                            -- (a game that does not say: coin has no item behind it)
        end
    end
    ns.Note("commentary: loot from a %s: %d things, coin %s, best quality %d", kind, things, tostring(money), quality)
    if things > 0 and trade == things and not money then return end     -- (gathered, the cast unseen)
    if not (money or quality >= 2 or (kind == "GameObject" and things >= 2)) then return end
    if from then M.opened[from] = true end
    M.Treasure({ best = best, quality = quality })
end

---------------------------------------------------------------------------
-- Bosses
---------------------------------------------------------------------------
-- The dungeon or raid you are in: its name and number, or nil
local function Instance()
    if not GetInstanceInfo then return nil end
    local ok, name, kind, _, _, _, _, _, id = pcall(GetInstanceInfo)
    if not ok then return nil end
    kind = Str(kind)
    if not kind or kind == "none" then return nil end
    return Str(name), Num(id), kind
end

-- A thought about the place, if one of its lines is still untold
local function PlaceLine(instance)
    local lines = instance and R.dungeons[instance]
    for i = 1, lines and #lines or 0 do
        local line, key = Untold("dungeon:" .. instance .. ":" .. i, lines[i])
        if line then return line, key end
    end
    return nil
end

local seen = {}
function M.Boss(id, name)
    if not M.On() then return false end
    id, name = ns.Plain(id), Str(name)
    local key = name or (id and ("#" .. tostring(id))) or nil
    local now = GetTime()
    local k = tostring(id or name or "?")
    for _, who in ipairs({ k, name }) do
        if seen[who] and now - seen[who] < M.TWICE then return false end
    end
    seen[k] = now
    if name then seen[name] = now end
    local _, instance = Instance()
    local times = 1
    if key then
        local bosses = M.Mine().bosses
        times = (tonumber(bosses[key]) or 0) + 1
        bosses[key] = times
    end
    if times == 1 then
        local line, lore = PlaceLine(instance)
        local thought = line or M.Pick("boss", R.boss)
        if name then thought = L["%s is down."]:format(name) .. " " .. thought end
        return M.Say({ said = M.Aloud("boss"), thought = thought, rank = BOSS, lore = lore })
    end
    if Roll() >= M.REPEAT then return false end
    local thought = name and L["%s again. That makes %d times."]:format(name, times)
        or L["I know this fight. That makes %d times."]:format(times)
    return M.Say({ thought = thought, rank = BOSS })
end

---------------------------------------------------------------------------
-- On the road: a place walked into, a job done
---------------------------------------------------------------------------
local function Ambient()
    return not M.roadAt or GetTime() - M.roadAt >= M.AMBIENT
end

local function Road(thought)
    if not M.Say({ thought = thought, rank = ROAD }) then return false end
    M.roadAt = GetTime()
    return true
end

local function Zone() return Str(Try(GetRealZoneText)) or Str(Try(GetZoneText)) end

-- Walked into a zone. quiet = you were simply there (logging in): noted, not thought about.
function M.Zone(quiet)
    if not M.On() then return false end
    local zone = Zone()
    if not zone or Instance() or ns.Yes(Try(UnitOnTaxi, "player")) then return false end
    local zones = M.Mine().zones
    if zones[zone] then return false end
    if quiet then zones[zone] = true; return false end
    if not Ambient() then return false end                       -- (left unnoted: another visit may get a word)
    local thought
    local log = ns.db.fishLog
    local fished = log and log.zones and log.zones[zone]
    if fished and (fished.n or 0) > 0 then
        thought = L["%s. My journal has %d catches from here."]:format(zone, fished.n)
    else
        thought = M.Pick("arrive", R.arrive):format(zone)
    end
    if not Road(thought) then return false end
    zones[zone] = true
    return true
end

-- A group, dungeon or raid quest (the game's tags: 1 group, 62 raid, 81 dungeon)
local HARD = { [1] = true, [62] = true, [81] = true }
local function IsHard(id)
    local get = C_QuestLog and C_QuestLog.GetQuestTagInfo
    local info = get and Try(get, id)
    local tag = type(info) == "table" and Num(info.tagID) or Num(info)
    return tag and HARD[tag] or false
end

local function QuestTitle(id)
    local get = C_QuestLog and C_QuestLog.GetTitleForQuestID
    return get and Str(Try(get, id)) or nil
end

-- The quest being handed in, read while the log still has it
function M.HandingIn()
    local id = Num(Try(GetQuestID))
    if not id or id == 0 then return end
    M.turning = { id = id, title = Str(Try(GetTitleText)) or QuestTitle(id), hard = IsHard(id) }
end

function M.Quest(id)
    if not M.On() then return false end
    id = Num(id)
    local zone = Zone()
    if not zone then return false end
    local quests = M.Mine().quests
    local done = (tonumber(quests[zone]) or 0) + 1
    quests[zone] = done
    local was = M.turning and M.turning.id == id and M.turning or nil
    local title = (was and was.title) or (id and QuestTitle(id))
    local hard = (was and was.hard) or (id and IsHard(id))
    M.turning = nil
    if not Ambient() then return false end
    if hard and title then return Road(M.Pick("hard", R.hard):format(title)) end
    if done % M.EVERY == 0 then
        return Road(L["%s: %d jobs done here since I started keeping count."]:format(zone, done))
    end
    if done == 1 and title then return Road(M.Pick("quest", R.quest):format(title)) end
    return false
end

---------------------------------------------------------------------------
-- When
---------------------------------------------------------------------------
-- After a fight: what happened in it, if it is not old news
function M.Calm()
    local r = M.waiting
    if not r then return end
    M.waiting = nil
    if GetTime() - (r.since or 0) <= M.WAIT then M.Say(r) end
end

local function Later(seconds, fn)
    if C_Timer and C_Timer.After then
        C_Timer.After(seconds, ns.Protect(fn))
    else
        fn()
    end
end

-- Which of the boss events this game really sends is not known yet: counted for the debug report
local function Count(event)
    local events = M.Memory().events
    events[event] = (events[event] or 0) + 1
end

local watch = CreateFrame("Frame")
M.watch = watch
watch:SetScript("OnEvent", ns.Protect(function(_, event, a, b, _, d, e)
    if event == "LOOT_READY" or event == "LOOT_OPENED" then
        M.Loot()
    elseif event == "LOOT_CLOSED" then
        M.lootSeen = false
    elseif event == "UNIT_SPELLCAST_SENT" then
        if a == "player" then M.Cast(d) end
    elseif event == "PLAYER_REGEN_DISABLED" then
        if M.now then                                   -- a fight: the card gets out of the way
            if M.now.rank >= GREAT then M.now.since = GetTime(); M.waiting = M.now end
            local waiting = M.waiting
            M.Clear()
            M.waiting = waiting
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        Later(1.5, M.Calm)
    elseif event == "BOSS_KILL" then
        Count(event)
        ns.Note("commentary: BOSS_KILL, id %s, name %s", tostring(ns.Plain(a)), tostring(ns.Plain(b)))
        M.Boss(a, b)
    elseif event == "ENCOUNTER_END" then
        Count(event)
        local won = ns.Plain(e)
        ns.Note("commentary: ENCOUNTER_END, id %s, name %s, success %s", tostring(ns.Plain(a)),
            tostring(ns.Plain(b)), tostring(won))
        if won == 1 or won == true then M.Boss(a, b) end
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        Later(M.SETTLE, function() M.Zone() end)
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- a loading screen into a new place (a boat, a hearthstone) is arriving; logging in or a reload is not
        local arrived = a == false and b == false
        Later(arrived and M.SETTLE or 1, function() M.Zone(not arrived) end)
    elseif event == "QUEST_COMPLETE" then
        M.HandingIn()
    elseif event == "QUEST_TURNED_IN" then
        M.Quest(a)
    end
end))

local EVENTS = { "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "BOSS_KILL", "ENCOUNTER_END",
                 "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD", "QUEST_COMPLETE", "QUEST_TURNED_IN",
                 "LOOT_READY", "LOOT_OPENED", "LOOT_CLOSED", "UNIT_SPELLCAST_SENT" }

function M:Apply(run)
    local want = run and ns.db.narrative ~= false and ns.db.commentary ~= false and true or false
    if want == (self.running == true) then return end
    self.running = want
    if want then
        for _, e in ipairs(EVENTS) do pcall(watch.RegisterEvent, watch, e) end
        M.Zone(true)                                    -- (where you stand now is no news)
    else
        watch:UnregisterAllEvents()
        M.Clear()
        if N.Fishing then N.Fishing() end
    end
end

function M.Describe()
    local events = ns.db and ns.db.remarkMemory and ns.db.remarkMemory.events or {}
    local r = M.Current()
    return ("commentary %s; boss events seen: ENCOUNTER_END %d, BOSS_KILL %d; %s"):format(tostring(M.On()),
        events.ENCOUNTER_END or 0, events.BOSS_KILL or 0,
        r and ("showing (" .. tostring(M.at) .. "): " .. M.Words(r)) or (M.waiting and "one waiting" or "quiet"))
end

ns.RegisterSetting({
    key = "commentary", kind = "boolean", default = true, command = "commentary", section = "General",
    label = "Character commentary",
    tip = "now and then your character has something to say about a catch, a chest, a dungeon boss, a new place or a quest done: out loud in your race's voice, or a quiet thought in plain words. On screen only, never in chat, and never in a fight. It needs the narrative switched on",
})

ns.RegisterModule("commentary", M)
