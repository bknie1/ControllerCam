-- ControllerCam HUD: the quest list follows you.
-- Nothing is drawn by us: it is the game's own list, driven through the game's own tracking.
--
-- Which quests are listed (each a switch of its own; with all of them off the list is yours alone):
--   current zone only   only the quests of the zone you are in; it changes as you travel. In a zone with no
--                       quests of its own, your own tracking is shown.
--   no group quests     while you are on your own, quests meant for a group (elite, dungeon, raid) are left out;
--                       one that is ready to hand in stays.
--   only the nearest    no more than so many quests, the nearest ones.
-- What you were tracking before is remembered and comes back when these are turned off.
--
-- In which order (these never change which quests are listed):
--   nearest first       by how far away each quest is.
--   recommended order   ready to hand in first; then what you can do on your own, nearest first; then quests
--                       above your level; then group quests while you are alone; grey quests last.
-- The order is kept by tracking the quests in that order, which is how the game lists them; where the game has
-- its own "sort by distance" that is used for nearest first. /cchud questplan says the recommended order for
-- your whole quest log in chat, whatever the list shows.

local ADDON, ns = ...
local L = ns.L

local Q = { active = false, ordering = false }
ns.Quests = Q

Q.STEP = 40                   -- distances are compared in steps of this many yards, so the list does not flicker
Q.ABOVE = 3                   -- a quest more than this many levels above you waits
Q.EVERY = 4                   -- seconds between looks at the distances while you travel

ns.RegisterSetting({
    key = "questzone", kind = "boolean", default = false, command = "questzone", section = "Quests",
    label = "Quest list: current zone only",
    tip = "track only the quests of the zone you are in (your own tracking comes back when this is off)",
})
ns.RegisterSetting({
    key = "questSolo", kind = "boolean", default = false, command = "questsolo", section = "Quests",
    label = "Quest list: no group quests while alone",
    tip = "while you are on your own, quests meant for a group (elite, dungeon, raid) are left out of the list; in a group they are back",
})
ns.RegisterSetting({
    key = "questNear", kind = "number", default = 0, min = 0, max = 10, command = "questnear", section = "Quests",
    label = "Quest list: only the nearest",
    tip = "list no more than this many quests, the nearest ones (0 lists them all)",
})
ns.RegisterSetting({
    key = "questNearest", kind = "boolean", default = false, command = "questnearest", section = "Quests",
    label = "Quest list: nearest first",
    tip = "keep the quest list in order of distance, the nearest quest at the top",
})
ns.RegisterSetting({
    key = "questPlan", kind = "boolean", default = false, command = "questorder", section = "Quests",
    label = "Quest list: recommended order",
    tip = "keep the quest list in a recommended order: ready to hand in first, then what you can do on your own nearest first, then quests above your level, group quests while you are alone, and grey quests last",
})

-- The quest ids that were tracked before we took over (nil while we are not in charge)
ns.RegisterSaved("questSaved", function(old)
    if type(old) ~= "table" then return nil end
    local list = {}
    for _, id in ipairs(old) do
        if type(id) == "number" then list[#list + 1] = id end
    end
    return list
end)

function Q:Supported()
    local api = C_QuestLog
    return type(api) == "table" and api.GetNumQuestLogEntries and api.GetInfo and api.AddQuestWatch
        and api.RemoveQuestWatch and api.GetQuestWatchType and true or false
end

-- Do we decide which quests are listed? (any of the switches that leave quests out)
local function Managing(db)
    return (db.questzone or db.questSolo or (db.questNear or 0) > 0) and true or false
end
-- Do we keep the list in an order?
local function Ordering(db) return (db.questNearest or db.questPlan) and true or false end

-- Every quest in the log with the heading (zone) it is listed under, and what the log says about it
local function Log()
    local quests, header = {}, nil
    for i = 1, C_QuestLog.GetNumQuestLogEntries() or 0 do
        local info = C_QuestLog.GetInfo(i)
        if info then
            if info.isHeader then
                header = info.title
            elseif info.questID and not info.isHidden then
                quests[#quests + 1] = { id = info.questID, header = header, title = info.title,
                                        level = tonumber(info.difficultyLevel) or tonumber(info.level),
                                        party = tonumber(info.suggestedGroup) or 0 }
            end
        end
    end
    return quests
end

local function Watched(id) return C_QuestLog.GetQuestWatchType(id) ~= nil end

local function SetWatched(id, want)
    if want == Watched(id) then return end
    if want then C_QuestLog.AddQuestWatch(id) else C_QuestLog.RemoveQuestWatch(id) end
end

local function OnThisMap()
    local set = {}
    if not (C_Map and C_Map.GetBestMapForUnit and C_QuestLog.GetQuestsOnMap) then return set end
    pcall(function()
        local map = C_Map.GetBestMapForUnit("player")
        for _, q in ipairs(C_QuestLog.GetQuestsOnMap(map) or {}) do
            if q.questID then set[q.questID] = true end
        end
    end)
    return set
end

---------------------------------------------------------------------------
-- What the game knows about a quest
---------------------------------------------------------------------------
-- Asks the game one thing about a quest; nil when it has no such word or will not say
local function Ask(name, id)
    local fn = C_QuestLog[name]
    if not fn then return nil end
    local ok, a, b = pcall(fn, id)
    if not ok or ns.IsSecret(a) then return nil end
    return a, b
end

-- The game's tags for quests that want company: group (elite), raid, dungeon, heroic, raids of 10 and 25
local GROUP_TAGS = { [1] = true, [62] = true, [81] = true, [85] = true, [88] = true, [89] = true }

-- Fills in: far (yards, or nil when the game has no place for it), group, done, grey
function Q.Look(q)
    local sq = Ask("GetDistanceSqToQuest", q.id)
    q.far = (type(sq) == "number" and sq > 0) and math.sqrt(sq) or nil
    local tag = Ask("GetQuestTagInfo", q.id)
    local size = tonumber((Ask("GetSuggestedGroupSize", q.id))) or q.party or 0
    q.group = (size > 1 or Ask("IsEliteQuest", q.id) == true
        or (type(tag) == "table" and (GROUP_TAGS[tag.tagID or 0] or tag.isElite == true))) and true or false
    q.done = (Ask("ReadyForTurnIn", q.id) == true or Ask("IsComplete", q.id) == true) and true or false
    q.grey = Ask("IsQuestTrivial", q.id) == true
    return q
end

local function Alone()
    return not (IsInGroup and ns.Yes(IsInGroup()))
end

local function Step(q) return q.far and math.floor(q.far / Q.STEP) or 1e6 end

-- Where a quest stands in the recommended order: 0 hand it in, 1 do it, 2 above your level, 3 wants a group,
-- 4 grey
function Q.Tier(q, level, alone)
    if q.done then return 0 end
    if q.grey then return 4 end
    if q.group and alone then return 3 end
    if q.level and level and level > 0 and q.level > level + Q.ABOVE then return 2 end
    return 1
end

-- Sorts looked-at quests: by the recommended order, or simply nearest first
function Q.Sort(quests, plan)
    local level = UnitLevel and tonumber(UnitLevel("player")) or 0
    local alone = Alone()
    for i, q in ipairs(quests) do
        q.at = i
        q.tier = plan and Q.Tier(q, level, alone) or 1
    end
    table.sort(quests, function(a, b)
        if a.tier ~= b.tier then return a.tier < b.tier end
        local sa, sb = Step(a), Step(b)
        if sa ~= sb then return sa < sb end
        return a.at < b.at                              -- as close as each other: as they were
    end)
    return quests
end

---------------------------------------------------------------------------
-- Which quests are listed
---------------------------------------------------------------------------
-- Track exactly the quests in `set`
local function TrackOnly(quests, set)
    for _, q in ipairs(quests) do SetWatched(q.id, set[q.id] and true or false) end
end

function Q:Choose(quests)
    local db = ns.db
    local here, count = {}, 0
    if db.questzone then
        local zone, subzone = GetRealZoneText and GetRealZoneText(), GetZoneText and GetZoneText()
        local onMap = OnThisMap()
        for _, q in ipairs(quests) do
            if (q.header and (q.header == zone or q.header == subzone)) or onMap[q.id] then
                here[q.id] = true
                count = count + 1
            end
        end
    end
    self.zoneCount = count
    if count == 0 then                                 -- nothing to do here (or no zone rule): your own list
        here = {}
        for _, id in ipairs(db.questSaved or {}) do here[id] = true end
    end
    local near = db.questNear or 0
    if not (db.questSolo or near > 0) then return here end
    local list = {}
    for _, q in ipairs(quests) do
        if here[q.id] then list[#list + 1] = Q.Look(q) end
    end
    if db.questSolo and Alone() then
        for i = #list, 1, -1 do
            if list[i].group and not list[i].done then
                here[list[i].id] = nil
                table.remove(list, i)
            end
        end
    end
    if near > 0 and #list > near then
        Q.Sort(list, false)
        for i = near + 1, #list do here[list[i].id] = nil end
    end
    return here
end

---------------------------------------------------------------------------
-- In which order
---------------------------------------------------------------------------
-- The listed quests in the order the game lists them (nil when the game does not say)
local function Listed()
    local api = C_QuestLog
    if not (api.GetNumQuestWatches and api.GetQuestIDForQuestWatchIndex) then return nil end
    local ok, n = pcall(api.GetNumQuestWatches)
    if not ok or type(n) ~= "number" then return nil end
    local list = {}
    for i = 1, n do
        local ok2, id = pcall(api.GetQuestIDForQuestWatchIndex, i)
        if ok2 and type(id) == "number" then list[#list + 1] = id end
    end
    return list
end

function Q:Order(quests)
    local db = ns.db
    local listed = Listed()
    if not listed or #listed < 2 then return false end
    local byId = {}
    for _, q in ipairs(quests) do byId[q.id] = q end
    local want = {}
    for _, id in ipairs(listed) do
        if byId[id] then want[#want + 1] = Q.Look(byId[id]) end
    end
    if #want ~= #listed then return false end          -- something listed that is not a quest of the log: left be
    Q.Sort(want, db.questPlan)
    local same = true
    for i, q in ipairs(want) do
        if q.id ~= listed[i] then same = false; break end
    end
    if same then return false end
    if not db.questPlan and C_QuestLog.SortQuestWatches then
        pcall(C_QuestLog.SortQuestWatches)             -- nearest first is something the game does itself
        ns.Note("quests: the game sorted the list by distance")
        return true
    end
    for _, q in ipairs(want) do C_QuestLog.RemoveQuestWatch(q.id) end
    for _, q in ipairs(want) do C_QuestLog.AddQuestWatch(q.id) end
    ns.Note("quests: the list was put in order (%d quests)", #want)
    return true
end

function Q:Sync()
    local quests = Log()
    if #quests == 0 then return false end              -- the log is not loaded yet
    if self.active then TrackOnly(quests, self:Choose(quests)) end
    if self.ordering then self:Order(quests) end
    return true
end

function Q:Restore()
    local saved = ns.db.questSaved
    if not saved then return true end
    local quests = Log()
    if #quests == 0 then return false end
    local set = {}
    for _, id in ipairs(saved) do set[id] = true end
    TrackOnly(quests, set)
    ns.db.questSaved = nil
    return true
end

---------------------------------------------------------------------------
-- /cchud questplan: the recommended order for the whole log, said in chat
---------------------------------------------------------------------------
function Q:Plan(max)
    if not self:Supported() then return nil end
    local quests = Log()
    for _, q in ipairs(quests) do Q.Look(q) end
    Q.Sort(quests, true)
    while #quests > (max or 8) do table.remove(quests) end
    return quests
end

local WHY = { [0] = L["ready to hand in"], [2] = L["above your level"], [3] = L["wants a group"], [4] = L["low level"] }

ns.RegisterCommand("questplan", function()
    local plan = Q:Plan(8)
    if not plan or #plan == 0 then ns.Say(L["Your quest log is empty."]); return end
    ns.Say(L["Recommended next:"])
    for i, q in ipairs(plan) do
        local parts = { ("%d. %s"):format(i, tostring(q.title or q.id)) }
        if q.level and q.level > 0 then parts[1] = parts[1] .. (" [%d]"):format(q.level) end
        if q.far then parts[#parts + 1] = L["%d yd"]:format(math.floor(q.far + 0.5)) end
        if WHY[q.tier] then parts[#parts + 1] = WHY[q.tier] end
        ns.Say(table.concat(parts, ", "))
    end
end, "/cchud questplan", "say a recommended order for your quests: hand in what is ready, then the nearest you can do alone, then the rest")

---------------------------------------------------------------------------
-- Watching
---------------------------------------------------------------------------
local events = CreateFrame("Frame")
local dirty = false
local function Work()
    dirty = false
    if Q.active or Q.ordering then
        Q:Sync()
    elseif ns.db.questSaved then
        if Q:Restore() then events:UnregisterAllEvents() end
    end
end
Work = ns.Protect(Work)

local function Later()
    if dirty then return end
    dirty = true
    C_Timer.After(0.3, Work)            -- several of these events arrive together
end

events:SetScript("OnEvent", ns.Protect(function(_, event, a, b)
    if event == "QUEST_ACCEPTED" and Q.active and ns.db.questSaved then
        -- a quest you just took is one of yours: the game tracks it, and so do we from now on
        local id = (type(b) == "number" and b) or (type(a) == "number" and a) or nil
        if id then
            local known = false
            for _, old in ipairs(ns.db.questSaved) do if old == id then known = true end end
            if not known then table.insert(ns.db.questSaved, id) end
        end
    end
    Later()
end))

-- (distances change as you travel, and the game does not say so: looked at now and then, never in a fight)
local since = 0
events:SetScript("OnUpdate", ns.Protect(function(_, dt)
    if not (Q.ordering or (Q.active and (ns.db.questNear or 0) > 0)) then return end
    since = since + dt
    if since < Q.EVERY then return end
    since = 0
    if not InCombatLockdown() then Later() end
end))

local EVENTS = { "ZONE_CHANGED_NEW_AREA", "QUEST_ACCEPTED", "QUEST_REMOVED", "PLAYER_ENTERING_WORLD", "QUEST_LOG_UPDATE",
                 "GROUP_ROSTER_UPDATE" }

function Q:Apply(run)
    local db = ns.db
    local can = run and self:Supported() and true or false
    local manage, order = can and Managing(db), can and Ordering(db)
    if manage or order then
        if not self.listening then
            self.listening = true
            for _, e in ipairs(EVENTS) do pcall(events.RegisterEvent, events, e) end
        end
        self.ordering = order
        if manage then
            self.active = true
            if not db.questSaved then                  -- remember the player's own tracking, once
                local saved = {}
                for _, q in ipairs(Log()) do
                    if Watched(q.id) then saved[#saved + 1] = q.id end
                end
                if #Log() > 0 then db.questSaved = saved end
            end
            if db.questSaved then self:Sync() end
            return
        end
    end
    self.active, self.ordering = false, order
    if not order and self.listening then
        self.listening = false
        events:UnregisterAllEvents()
    end
    if db.questSaved and self:Supported() and not self:Restore() then
        -- the quest log is not loaded yet: put the tracking back as soon as it is
        pcall(events.RegisterEvent, events, "QUEST_LOG_UPDATE")
        pcall(events.RegisterEvent, events, "PLAYER_ENTERING_WORLD")
    end
    if order then self:Sync() end
end

function Q.Describe()
    local api = type(C_QuestLog) == "table" and C_QuestLog or {}
    local listed = Q:Supported() and Listed()
    return ("deciding the list %s, ordering it %s, zone quests %s, listed in the game's order: %s; the game has: distance %s, its own sort %s, tags %s, group size %s"):format(
        tostring(Q.active), tostring(Q.ordering), tostring(Q.zoneCount), listed and table.concat(listed, " ") or "not told",
        tostring(api.GetDistanceSqToQuest ~= nil), tostring(api.SortQuestWatches ~= nil), tostring(api.GetQuestTagInfo ~= nil),
        tostring(api.GetSuggestedGroupSize ~= nil))
end

ns.RegisterCheck(function(row, run, db)
    if run and Managing(db) then
        row("the game can track quests for us", Q:Supported())
        row("the quest list is decided by its switches", Q.active == Q:Supported())
    else
        row("quest tracking is the player's own", not Q.active)
    end
end)

ns.RegisterModule("quests", Q)
