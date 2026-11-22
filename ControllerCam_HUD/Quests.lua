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
-- The order is kept by tracking the quests again in that order, which is how the game lists them (the game's
-- own "sort" is not used: it did not give nearest first). The game adds a newly tracked quest at
-- one end of its list, and which end differs between clients: after putting the list in order we look at what
-- the game made of it, and if it came out upside down we do it the other way round from then on. If the game
-- keeps putting the list back its own way, we stop asking (three tries) instead of shuffling it for ever.
-- /cchud questplan says the recommended order for your whole quest log in chat, whatever the list shows.
--
-- Short objectives: an objective says only what is needed, with an icon for its kind in front: a skull and
-- "0/1 Captain Dreadrise" for "0/1 Captain Dreadrise slain". It is the game's own line; its text is looked at
-- a few times a second by our own timer and put in the short form (never by code of ours inside the game's).

local ADDON, ns = ...
local L = ns.L

local Q = { active = false, ordering = false }
ns.Quests = Q

Q.STEP = 40                   -- distances are compared in steps of this many yards, so the list does not flicker
Q.ABOVE = 3                   -- a quest more than this many levels above you waits
Q.EVERY = 4                   -- seconds between looks at the distances while you travel
Q.EVERY_SLOW = 60             -- ... when putting the list in order once took long (Q.SLOW_PUT ms or more)
Q.SLOW_PUT = 150

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

-- How far a quest is, in steps. A quest right on the edge of a step keeps the step it had: walking along that
-- edge does not swap it back and forth.
Q.steps = {}
local function Step(q)
    if not q.far then return 1e6 end
    local step, last = math.floor(q.far / Q.STEP), Q.steps[q.id]
    if last and last ~= step and math.abs(q.far - (last + 0.5) * Q.STEP) <= Q.STEP * 0.8 then step = last end
    Q.steps[q.id] = step
    return step
end

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
        q.step = Step(q)
    end
    table.sort(quests, function(a, b)
        if a.tier ~= b.tier then return a.tier < b.tier end
        if a.step ~= b.step then return a.step < b.step end
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

local function Same(a, b)
    if #a ~= #b then return false end
    for i = 1, #a do
        if a[i] ~= b[i] then return false end
    end
    return true
end

-- The quests of `ids` in the order the game lists them now
local function ListedOf(ids)
    local set, out = {}, {}
    for _, id in ipairs(ids) do set[id] = true end
    for _, id in ipairs(Listed() or {}) do
        if set[id] then out[#out + 1] = id end
    end
    return out
end

-- Tracks these quests again so that the game lists them in this order (the first on top). Each quest tracked
-- again makes the game redraw what shows the quests (with the map open, all of its quest panel: seconds for a
-- long list), so only the ones out of place are: what is already in place at the end where the game does not
-- add stays. (now: the order the game lists them in; the first time, all of them, to learn which end it adds at.)
Q.moved = 0
local function Put(ids, now)
    local from, to = 1, #ids
    if Q.endKnown and type(now) == "table" and #now == #ids then
        if Q.addsOnTop then
            while to >= 1 and ids[to] == now[to] do to = to - 1 end
        else
            while from <= #ids and ids[from] == now[from] do from = from + 1 end
        end
    end
    local part = {}
    for i = from, to do part[#part + 1] = ids[i] end
    for _, id in ipairs(part) do C_QuestLog.RemoveQuestWatch(id) end
    if Q.addsOnTop then
        for i = #part, 1, -1 do C_QuestLog.AddQuestWatch(part[i]) end
    else
        for _, id in ipairs(part) do C_QuestLog.AddQuestWatch(id) end
    end
    Q.moved = Q.moved + #part
    return #part
end

function Q:Order(quests)
    local db = ns.db
    local listed = Listed()
    if not listed or #listed < 2 then return false end
    local byId = {}
    for _, q in ipairs(quests) do byId[q.id] = q end
    -- the quests of the log among what is listed (anything else the game lists is left where it is)
    local known, now = {}, {}
    for _, id in ipairs(listed) do
        if byId[id] then
            known[#known + 1] = Q.Look(byId[id])
            now[#now + 1] = id
        end
    end
    if #known < 2 then return false end
    Q.Sort(known, db.questPlan)
    local want = {}
    for i, q in ipairs(known) do want[i] = q.id end
    if Same(want, now) then
        self.tries = 0
        return false
    end
    local key = table.concat(want, ",")
    -- (the game has a sort of its own, but what it calls sorted is not nearest first on every client: asked for
    -- again and again it kept putting the list its own way. So the order is always put by us.)
    if self.asked == key then                           -- we put it so, and it is not so again: the game's doing
        self.tries = (self.tries or 0) + 1
        if self.tries >= 3 then
            if self.stuck ~= key then
                self.stuck = key
                ns.Note("quests: the game keeps putting the list in its own order; left as it is")
            end
            return false
        end
    else
        self.tries = 0
    end
    self.asked = key
    local clock = debugprofilestop
    local t0 = type(clock) == "function" and clock() or nil
    local moved = Put(want, now)
    local got = ListedOf(want)
    if not Same(got, want) and #got == #want then
        local upside = true
        for i = 1, #want do
            if got[i] ~= want[#want + 1 - i] then upside = false; break end
        end
        if upside then                                  -- upside down: this game adds at the other end
            self.addsOnTop = not self.addsOnTop
            ns.Note("quests: the game adds a tracked quest at the %s of its list", self.addsOnTop and "top" or "bottom")
            moved = Put(want)
            got = ListedOf(want)
        end
    end
    if Same(got, want) then Q.endKnown = true end
    local took = t0 and clock() - t0
    if took and took >= Q.SLOW_PUT and not Q.slowPut then             -- the game is slow to redraw: seldom, then
        Q.slowPut = true
        ns.Note("quests: putting the list in order took %.0f ms: from now on looked at every %d s", took, Q.EVERY_SLOW)
    end
    ns.Note("quests: the list was put in order (%d quests, %d moved): %s; the game now lists %s", #want, moved, key,
        table.concat(got, ","))
    return true
end

---------------------------------------------------------------------------
-- The focused quest (the one the game points you to). Tracking a quest again drops the game's focus, so it is
-- put back after every change we make to the list: yours stays yours. With "Focus the nearest quest", the
-- nearest one in the list is focused as you travel; but a quest you focus yourself is left alone for a while
-- (Q.FOCUS_HOLD), and only then does the nearest take over again.
---------------------------------------------------------------------------
ns.RegisterSetting({
    key = "questFocusNear", kind = "boolean", default = false, command = "questfocus", section = "Quests",
    label = "Focus the nearest quest",
    tip = "the quest the game points you to is always the nearest one in your list, as you travel; one you focus yourself is left alone for ten minutes",
})
Q.FOCUS_HOLD = 600

function Q.Focused()
    local id
    if C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID then
        local ok, v = pcall(C_SuperTrack.GetSuperTrackedQuestID)
        id = ok and v or nil
    elseif GetSuperTrackedQuestID then
        local ok, v = pcall(GetSuperTrackedQuestID)
        id = ok and v or nil
    end
    if ns.IsSecret(id) or type(id) ~= "number" or id <= 0 then return nil end
    return id
end

function Q.SetFocus(id)
    if not id then return false end
    local set = (C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID) or SetSuperTrackedQuestID
    if not set then return false end
    Q.focusMine = id
    return pcall(set, id) and true or false
end

-- Runs fn (a change to what is tracked) and puts the focused quest back if the change dropped it
local function KeepFocus(fn, ...)
    local had = Q.Focused()
    fn(...)
    if had and Q.Focused() ~= had then
        Q.SetFocus(had)
        Q.focusKept = (Q.focusKept or 0) + 1
    end
end

-- The nearest quest of the list, focused (unless you chose one yourself a little while ago)
function Q:FocusNearest(quests)
    local now, cur = GetTime(), Q.Focused()
    if cur and cur ~= Q.focusMine then                 -- you focused this one yourself: yours for a while
        Q.userFocusUntil = now + Q.FOCUS_HOLD
        Q.focusMine = cur
        ns.Note("quests: you focused %d yourself; left alone for %d s", cur, Q.FOCUS_HOLD)
    end
    if Q.userFocusUntil and now < Q.userFocusUntil then return false end
    local best
    for _, q in ipairs(quests) do
        if Watched(q.id) then
            Q.Look(q)
            if q.far and (not best or q.far < best.far) then best = q end
        end
    end
    if not best or best.id == cur then return false end
    Q.SetFocus(best.id)
    Q.focusedNear = (Q.focusedNear or 0) + 1
    return true
end

function Q:Sync()
    local quests = Log()
    if #quests == 0 then return false end              -- the log is not loaded yet
    if self.active then KeepFocus(TrackOnly, quests, self:Choose(quests)) end
    if self.ordering then KeepFocus(self.Order, self, quests) end
    if self.focusing then self:FocusNearest(quests) end
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
-- Short objectives
---------------------------------------------------------------------------
ns.RegisterSetting({
    key = "questShort", kind = "boolean", default = true, command = "questshort", section = "Quests",
    label = "Quest list: short objectives",
    tip = "objectives in the quest list say only what is needed, with an icon for the kind in front: a skull and 0/1 Captain Dreadrise, not 0/1 Captain Dreadrise slain",
})

-- An icon for each kind of objective (the game's own art): something to kill, to collect, to use
Q.KIND_ICON = { monster = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull", item = "Interface\\ICONS\\INV_Misc_Bag_08",
                object = "Interface\\ICONS\\INV_Misc_Gear_01" }
Q.TRACKERS = { "ObjectiveTrackerFrame", "QuestWatchFrame", "WatchFrame" }

-- The game's own wording for a kill, in your language ("%s slain: %d/%d"), as a pattern that finds the name
local killPattern
local function KillName(label)
    if killPattern == nil then
        local words = type(QUEST_MONSTERS_KILLED) == "string" and QUEST_MONSTERS_KILLED or "%s slain: %d/%d"
        words = words:gsub("%%%d+%$", "%%")              -- ("%1$s": the same thing, numbered)
        words = words:gsub("%s*[:：]?%s*%%d%s*/%s*%%d%s*", " ")   -- without the count, wherever it stands
        words = words:gsub("^%s+", ""):gsub("%s+$", "")
        local before, after = words:match("^(.-)%%s(.-)$")
        if before and (before ~= "" or after ~= "") then
            local function plain(text) return (text:gsub("%p", "%%%0")) end
            killPattern = "^" .. plain(before) .. "(.-)" .. plain(after) .. "$"
        else
            killPattern = false
        end
    end
    local name = killPattern and label:match(killPattern)
    -- (a game that words it another way than it says: the English ending, at least)
    if not name or name == "" then name = label:match("^(.-) slain$") end
    return (name and name ~= "") and name or label
end

-- An objective's words without its count: "Captain Dreadrise slain: 0/1" and "0/1 Captain Dreadrise slain" alike
local function Label(text)
    return text:match("^(.-)%s*[:：]%s*%d+/%d+$") or text:match("^%d+/%d+%s+(.+)$") or text
end

-- What the listed quests want done: the words of each objective -> { its kind, its short form }
function Q.Objectives()
    local map = {}
    if not C_QuestLog.GetQuestObjectives then return map end
    for _, q in ipairs(Log()) do
        if Watched(q.id) then
            local ok, list = pcall(C_QuestLog.GetQuestObjectives, q.id)
            for _, o in ipairs((ok and type(list) == "table") and list or {}) do
                local text = type(o) == "table" and o.text
                if type(text) == "string" and not ns.IsSecret(text) then
                    local label = Label(text)
                    map[label] = { kind = o.type, short = (o.type == "monster") and KillName(label) or label }
                end
            end
        end
    end
    return map
end

-- The short form of a line of the quest list, or nil when it is not an objective we know (or is short already)
function Q.ShortLine(text, map)
    local count, label = text:match("^(%d+/%d+)%s+(.+)$")
    if not count then label, count = text:match("^(.-)%s*[:：]%s*(%d+/%d+)$") end
    local o = label and map[label]
    if not o then return nil end
    local icon = Q.KIND_ICON[o.kind]
    if not icon and o.short == label then return nil end
    return (icon and ("|T%s:0|t "):format(icon) or "") .. count .. " " .. o.short
end

-- Every text of the game's quest list (looked for again now and then: the list makes and reuses its lines)
local texts, textsAt = {}, -10
local function Collect(frame, depth, into)
    if type(frame) ~= "table" or depth > 7 then return end
    if frame.GetRegions then
        for _, r in ipairs({ frame:GetRegions() }) do
            if type(r) == "table" and r.GetObjectType and r:GetObjectType() == "FontString" and r.GetText and r.SetText then
                into[#into + 1] = r
            end
        end
    end
    if frame.GetChildren then
        for _, child in ipairs({ frame:GetChildren() }) do Collect(child, depth + 1, into) end
    end
end

local changed = setmetatable({}, { __mode = "k" })      -- line -> { ours, the game's }
function Q:Shorten()
    local now = GetTime()
    if now - textsAt > 2 then
        textsAt, texts = now, {}
        for _, name in ipairs(Q.TRACKERS) do
            if type(_G[name]) == "table" then pcall(Collect, _G[name], 0, texts) end
        end
    end
    local map
    for _, fs in ipairs(texts) do
        local ok, text = pcall(fs.GetText, fs)
        if ok and type(text) == "string" and not ns.IsSecret(text) and text:find("%d/%d") and text:sub(1, 2) ~= "|T" then
            map = map or Q.Objectives()
            local short = Q.ShortLine(text, map)
            if short then
                changed[fs] = { ours = short, game = text }
                pcall(fs.SetText, fs, short)
                self.shortened = (self.shortened or 0) + 1
            end
        end
    end
end

-- Back to the game's own words (switched off)
function Q:Lengthen()
    for fs, rec in pairs(changed) do
        local ok, text = pcall(fs.GetText, fs)
        if ok and text == rec.ours then pcall(fs.SetText, fs, rec.game) end
        changed[fs] = nil
    end
end

local shortDriver = CreateFrame("Frame")
local shortSince = 0
shortDriver:SetScript("OnUpdate", ns.Protect(function(_, dt)
    if not Q.shortOn then return end
    shortSince = shortSince + dt
    if shortSince < 0.3 then return end
    shortSince = 0
    Q:Shorten()
end))

---------------------------------------------------------------------------
-- Progress in chat: a short line as a quest moves on ("[Q] Bloody Bone Necklaces: 4/25", an objective done, a
-- quest ready to hand in). What the log says is looked at after it changes and compared with the last look;
-- a quest seen for the first time (just taken, or the log just loaded) says nothing.
---------------------------------------------------------------------------
ns.RegisterSetting({
    key = "questProgress", kind = "boolean", default = true, command = "questchat", section = "Quests",
    label = "Quest progress in chat",
    tip = "a short line in chat as a quest moves on: Bloody Bone Necklaces: 4/25, an objective done, a quest ready to hand in",
})

ns.RegisterSetting({
    key = "questParty", kind = "boolean", default = true, command = "questparty", section = "Quests",
    label = "Quest progress to your party",
    tip = "in a party (not a raid) a quest ready to hand in goes to party chat, marked CCHUD, and Finishing up when the others are done before you; the steps stay in your own chat",
})

Q.progress, Q.told = {}, 0

-- In a party, the lines go to party chat instead (a raid is left alone: too many people for it). Without the
-- colours and icons the game would refuse, one each second, and never more than a few waiting.
Q.partyQueue, Q.partySent = {}, 0
Q.PARTY_GAP, Q.PARTY_MAX = 1, 6
function Q.InParty()
    return IsInGroup ~= nil and ns.Yes(IsInGroup()) and not (IsInRaid and ns.Yes(IsInRaid())) and true or false
end
function Q.PartyText(line)
    if type(line) ~= "string" or ns.IsSecret(line) then return nil end
    local text = line:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    text = text:gsub("|T.-|t", "")
    text = text:gsub("%s+", " ")
    text = text:gsub("^ ", ""):gsub(" $", "")
    return text ~= "" and text or nil
end
local sending = false
local function SendNext()
    local text = table.remove(Q.partyQueue, 1)
    if not text then sending = false; return end            -- (a gap has gone by with nothing new: idle)
    if Q.InParty() and SendChatMessage then
        local ok = pcall(SendChatMessage, text, "PARTY")
        if ok then Q.partySent = Q.partySent + 1 end
    end
    C_Timer.After(Q.PARTY_GAP, SendNext)
end
function Q.ToParty(line)
    local text = Q.PartyText(line)
    if not text then return end
    if #Q.partyQueue >= Q.PARTY_MAX then table.remove(Q.partyQueue, 1) end   -- (the oldest news goes first)
    Q.partyQueue[#Q.partyQueue + 1] = text
    if not sending then
        sending = true
        SendNext()
    end
end

-- The log as it stands: quest id -> { title, done, objs = { { label, have, need, finished } } }, and their order
local function Progress()
    local now, order = {}, {}
    for _, q in ipairs(Log()) do
        local ok, list = pcall(C_QuestLog.GetQuestObjectives, q.id)
        local objs = {}
        for i, o in ipairs((ok and type(list) == "table") and list or {}) do
            local text = type(o) == "table" and ns.Plain(o.text)
            if type(text) == "string" and text ~= "" then
                local have, need = ns.Plain(o.numFulfilled), ns.Plain(o.numRequired)
                if type(have) ~= "number" or type(need) ~= "number" then         -- (or read off the words)
                    local a, b = text:match("(%d+)%s*/%s*(%d+)")
                    have, need = tonumber(a), tonumber(b)
                end
                objs[i] = { label = Label(text), have = have, need = need, finished = ns.Plain(o.finished) == true }
            end
        end
        now[q.id] = { title = ns.Plain(q.title), objs = objs,
                      done = (Ask("ReadyForTurnIn", q.id) == true or Ask("IsComplete", q.id) == true) }
        order[#order + 1] = q.id
    end
    return now, order
end

-- What changed since the last look, as lines for chat (Q.doneLines: which of them finish a quest, and its id)
function Q.Changes()
    local now, order = Progress()
    local lines = {}
    Q.doneLines = {}
    for _, id in ipairs(order) do
        local cur, old = now[id], Q.progress[id]
        if old then
            for i, o in pairs(cur.objs) do
                local was = old.objs[i]
                local full = o.finished or (o.have and o.need and o.have >= o.need)
                if was and o.have and o.need and o.need > 1 and was.have and o.have > was.have then
                    local line = ("%s: %d/%d"):format(o.label, o.have, o.need)
                    if full then line = line .. "  |cff7fe07f" .. L["done"] .. "|r" end
                    lines[#lines + 1] = line
                elseif was and full and not was.finished and not (was.have and was.need and was.have >= was.need) then
                    lines[#lines + 1] = ("%s: |cff7fe07f%s|r"):format(o.label, L["done"])
                end
            end
            if cur.done and not old.done and cur.title then
                lines[#lines + 1] = "|cffffd24a" .. L["%s: ready to hand in"]:format(cur.title) .. "|r"
                Q.doneLines[lines[#lines]] = id                   -- (what goes to the party by default)
            end
        end
    end
    for id, cur in pairs(now) do Q.progress[id] = cur end      -- (a quest under a folded heading keeps its last look)
    return lines
end

local progressEvents = CreateFrame("Frame")
local progressDirty = false
---------------------------------------------------------------------------
-- To the party: by default only a quest finished ("CCHUD: Bloody Bone Necklaces: ready to hand in"), every
-- step only with Q's "every step" option; each line marked as ours. The steps stay in your own chat. And when
-- someone in the party has finished a quest you are still on (their HUD tells yours, quietly, by an addon
-- message), you say so once: "CCHUD: Finishing up [Bloody Bone Necklaces]."
---------------------------------------------------------------------------
ns.RegisterSetting({
    key = "questPartyAll", kind = "boolean", default = false, command = "questpartyall", section = "Quests",
    label = "Party: every step, not only the finished quest",
    tip = "every step of your quests goes to party chat (Bloody Bone Necklaces: 4/25), not only a quest ready to hand in",
})
Q.PREFIX = "CCHUD"                       -- the addon's short name: before every party line, and its addon messages
Q.doneLines, Q.finishing = {}, {}
function Q.PartyLine(text) return Q.PREFIX .. ": " .. text end

-- A quest of yours is finished: the party's HUDs are told (nothing shows in chat for that)
function Q.TellDone(id)
    local send = C_ChatInfo and C_ChatInfo.SendAddonMessage
    if send and Q.InParty() then pcall(send, Q.PREFIX, "done:" .. tostring(id), "PARTY") end
end

-- Someone in the party finished a quest: if you are still on it, "Finishing up" (once a quest)
function Q.TheyFinished(id, sender)
    id = tonumber(id)
    if not (id and ns.db.questParty and Q.InParty()) or Q.finishing[id] then return false end
    local mine = Q.progress[id]
    if not mine or mine.done or not mine.title then return false end
    Q.finishing[id] = true
    Q.ToParty(Q.PartyLine(L["Finishing up [%s]."]:format(mine.title)))
    ns.Note("quests: %s finished %d before you: finishing up", tostring(sender), id)
    return true
end

local function Tell()
    progressDirty = false
    if not Q.chatOn then return end
    local party = ns.db.questParty and Q.InParty()
    for _, line in ipairs(Q.Changes()) do
        Q.told = Q.told + 1
        local done = Q.doneLines[line]
        if done then Q.TellDone(done) end
        if party and (done or ns.db.questPartyAll) then
            Q.ToParty(Q.PartyLine(line))
        elseif ns.db.questProgress then
            if not (ns.Chat and ns.Chat.Line and ns.Chat.Line("quest", line)) then ns.Say(line) end
        end
    end
end
Tell = ns.Protect(Tell)
progressEvents:SetScript("OnEvent", ns.Protect(function(_, event, a, b, c, d)
    if event == "CHAT_MSG_ADDON" then
        if a ~= Q.PREFIX or c ~= "PARTY" or ns.IsSecret(b) or type(b) ~= "string" then return end
        local me = UnitName and UnitName("player")
        local who = type(d) == "string" and not ns.IsSecret(d) and d:match("^[^%-]+") or nil
        if who and who == me then return end                       -- (our own message comes back too)
        local id = b:match("^done:(%d+)$")
        if id then Q.TheyFinished(id, who) end
        return
    end
    if event == "QUEST_REMOVED" or event == "QUEST_TURNED_IN" then
        if type(a) == "number" then Q.finishing[a] = nil end
        if type(a) == "number" then Q.progress[a] = nil end
        return
    end
    if progressDirty then return end
    progressDirty = true
    C_Timer.After(0.2, Tell)                -- several of these come together
end))

function Q:ProgressOn(on)
    if on == (self.chatOn or false) then return end
    self.chatOn = on
    if on then
        self.progress = {}
        self.Changes()                      -- the log as it is now is the start: nothing of it is news
        for _, e in ipairs({ "QUEST_LOG_UPDATE", "QUEST_WATCH_UPDATE", "UNIT_QUEST_LOG_CHANGED", "QUEST_REMOVED",
                             "QUEST_TURNED_IN", "CHAT_MSG_ADDON" }) do
            pcall(progressEvents.RegisterEvent, progressEvents, e)
        end
        if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
            pcall(C_ChatInfo.RegisterAddonMessagePrefix, Q.PREFIX)
        end
    else
        progressEvents:UnregisterAllEvents()
        self.progress = {}
    end
end

---------------------------------------------------------------------------
-- Items your quests want: the "Quest" verdict of an item (Market.lua), so it is never sold or put up for auction
-- while a quest of yours needs it. What counts:
--   * an item an objective of a quest in your log asks for ("Linen Cloth: 3/10"), matched by its name, as long as
--     the quest is not grey for you (one ready to hand in counts however grey: the items go with it);
--   * an item the game marks as wanted by a quest you have (its own quest items);
--   * an item that starts a quest you have not done, unless that quest is grey for you (its level is the item's).
-- The game has no list of the quests you have not taken, so the log (where you have been questing) is what
-- counts. Looked at again when the log, your bags or your level change.
---------------------------------------------------------------------------
ns.RegisterSetting({
    key = "questItems", kind = "boolean", default = true, command = "questitems", section = "Bags, bank and vendor",
    label = "Keep what your quests need",
    tip = "an item a quest in your log still asks for, or one that starts a quest you can still do, is marked Quest: never sold or put up for auction for you",
})

-- How many levels under yours a quest turns grey (the game's own number when it says it)
function Q.GreenRange(level)
    local fn = GetQuestGreenRange
    if fn then
        local ok, n = pcall(fn, "player")
        n = ok and ns.Plain(n)
        if type(n) == "number" and n > 0 then return n end
    end
    if level <= 5 then return level end                  -- nothing is grey this early
    if level < 40 then return math.floor(level / 10) + 5 end
    if level < 60 then return math.floor(level / 5) + 1 end
    return 9
end

-- Is a quest of this level grey for you (too easy to be worth it)?
function Q.Grey(level)
    local me = UnitLevel and tonumber(ns.Plain(UnitLevel("player"))) or 0
    if type(level) ~= "number" or level <= 0 or me <= 0 then return false end
    return me - level > Q.GreenRange(me)
end

local function ItemName(id)
    local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if not get then return nil end
    local ok, name, _, _, ilvl = pcall(get, id)
    name, ilvl = ok and ns.Plain(name), ok and ns.Plain(ilvl)
    return type(name) == "string" and name ~= "" and name or nil, type(ilvl) == "number" and ilvl or nil
end

-- What the game says of an item in your bags and quests: wanted by a quest (its id), and is that quest yours
local function BagQuestInfo(bag, slot)
    local fn = (C_Container and C_Container.GetContainerItemQuestInfo) or GetContainerItemQuestInfo
    if not fn then return nil end
    local ok, a, b, c = pcall(fn, bag, slot)
    if not ok then return nil end
    if type(a) == "table" then a, b, c = a.isQuestItem, a.questID, a.isActive end
    a, b, c = ns.Plain(a), ns.Plain(b), ns.Plain(c)
    return a == true, type(b) == "number" and b > 0 and b or nil, c == true
end

local function Done(questID)
    local fn = (C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted) or IsQuestFlaggedCompleted
    if not fn then return false end
    local ok, done = pcall(fn, questID)
    return ok and ns.Plain(done) == true
end

-- The look: byName[lower-case item name] and byId[item id] -> { title, zone, have, need, done, starts, level }
Q.items = { dirty = true, at = -100, byName = {}, byId = {} }
Q.ITEMS_EVERY = 10            -- (looked at again after this many seconds anyway)

local function LookAtItems()
    local byName, byId, titles = {}, {}, {}
    for _, q in ipairs(Log()) do
        titles[q.id] = q
        local done = (Ask("ReadyForTurnIn", q.id) == true or Ask("IsComplete", q.id) == true)
        local grey = Ask("IsQuestTrivial", q.id) == true or Q.Grey(q.level)
        q.done = done
        if done or not grey then
            local ok, list = pcall(C_QuestLog.GetQuestObjectives, q.id)
            for _, o in ipairs((ok and type(list) == "table") and list or {}) do
                local text = type(o) == "table" and ns.Plain(o.text)
                if type(text) == "string" and text ~= "" and o.type == "item" then
                    local have, need = ns.Plain(o.numFulfilled), ns.Plain(o.numRequired)
                    if type(have) ~= "number" or type(need) ~= "number" then
                        local x, y = text:match("(%d+)%s*/%s*(%d+)")
                        have, need = tonumber(x), tonumber(y)
                    end
                    local key = Label(text):lower()
                    byName[key] = byName[key] or { title = ns.Plain(q.title), zone = ns.Plain(q.header), have = have,
                                                   need = need, done = done, level = q.level, questID = q.id }
                end
            end
        end
    end
    -- what the game itself marks in your bags: quest items, and items that start a quest
    local bags = type(C_Container) == "table" and C_Container.GetContainerNumSlots and C_Container.GetContainerItemID
    local last = bags and (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) or -1
    for bag = 0, last do
        local okN, slots = pcall(C_Container.GetContainerNumSlots, bag)
        for slot = 1, (okN and tonumber(slots)) or 0 do
            local okI, id = pcall(C_Container.GetContainerItemID, bag, slot)
            id = okI and ns.Plain(id)
            if type(id) == "number" and not byId[id] then
                local isQuest, questID, active = BagQuestInfo(bag, slot)
                if questID and not active then
                    local _, ilvl = ItemName(id)
                    if not Done(questID) and not (ilvl and ilvl > 1 and Q.Grey(ilvl)) then
                        byId[id] = { starts = true, questID = questID, level = ilvl }
                    end
                elseif questID and active then
                    local q = titles[questID]
                    byId[id] = { title = q and ns.Plain(q.title), zone = q and ns.Plain(q.header),
                                 done = q and q.done, level = q and q.level, questID = questID }
                elseif isQuest then
                    byId[id] = false                             -- (a quest item: its name may still match below)
                end
            end
        end
    end
    for id, w in pairs(byId) do if w == false then byId[id] = nil end end
    Q.items = { dirty = false, at = GetTime and GetTime() or 0, byName = byName, byId = byId, names = {} }
end
LookAtItems = ns.Protect(LookAtItems)

-- What a quest of yours wants this item for, or nil
function Q.ItemWant(id)
    if not (Q.itemsOn and ns.db and ns.db.questItems) or type(id) ~= "number" or ns.IsSecret(id) then return nil end
    local now = GetTime and GetTime() or 0
    if Q.items.dirty or now - Q.items.at > Q.ITEMS_EVERY then LookAtItems() end
    local items = Q.items
    if items.byId[id] then return items.byId[id] end
    if not next(items.byName) then return nil end
    local name = items.names and items.names[id]
    if name == nil then
        name = ItemName(id)
        name = name and name:lower() or false
        if items.names then items.names[id] = name end
    end
    return name and items.byName[name] or nil
end

-- The want in a few words: "Bloody Bones 3/25 (Duskwood)", "starts a quest"
function Q.WantText(w)
    if type(w) ~= "table" then return "" end
    if w.starts then return L["starts a quest"] end
    local text = w.title or L["a quest of yours"]
    if w.done then
        text = text .. ", " .. L["ready to hand in"]
    elseif w.have and w.need and w.need > 1 then
        text = text .. (" %d/%d"):format(w.have, w.need)
    end
    if w.zone then text = text .. " (" .. w.zone .. ")" end
    return text
end

local itemEvents = CreateFrame("Frame")
itemEvents:SetScript("OnEvent", function() Q.items.dirty = true end)
function Q:ItemsOn(on)
    if on == (self.itemsOn or false) then return end
    self.itemsOn = on
    Q.items.dirty = true
    if on then
        for _, e in ipairs({ "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN", "BAG_UPDATE_DELAYED",
                             "PLAYER_LEVEL_UP", "UNIT_QUEST_LOG_CHANGED" }) do
            pcall(itemEvents.RegisterEvent, itemEvents, e)
        end
    else
        itemEvents:UnregisterAllEvents()
    end
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
-- Never while the world map, the quest log or a quest window is open: each quest tracked again makes the game
-- redraw what it shows of your quests there (the map's quest markers too), which held the game up for seconds.
-- The order only matters in the quest list at the side of the screen; it is put once they are all closed.
Q.WINDOWS = { "WorldMapFrame", "QuestMapFrame", "QuestLogFrame", "QuestFrame", "QuestLogPopupDetailFrame" }
function Q.Busy()
    if ns.MapOpen() then return "WorldMapFrame" end
    for _, name in ipairs(Q.WINDOWS) do
        local f = _G[name]
        if type(f) == "table" and f.IsVisible then
            local ok, on = pcall(f.IsVisible, f)
            if ok and on == true then return name end
        end
    end
end
local function Work()
    dirty = false
    local busy = Q.Busy()
    if busy then
        if not Q.held then ns.Note("quests: the list waits while %s is open", busy) end
        Q.held = true
        return
    end
    Q.held = nil
    if Q.active or Q.ordering or Q.focusing then
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
    if Q.held and not Q.Busy() then Later() end                  -- (held while the map was open)
    if not (Q.ordering or Q.focusing or (Q.active and (ns.db.questNear or 0) > 0)) then return end
    since = since + dt
    if since < (Q.slowPut and Q.EVERY_SLOW or Q.EVERY) then return end
    since = 0
    if not InCombatLockdown() then Later() end
end))

local EVENTS = { "ZONE_CHANGED_NEW_AREA", "QUEST_ACCEPTED", "QUEST_REMOVED", "PLAYER_ENTERING_WORLD", "QUEST_LOG_UPDATE",
                 "GROUP_ROSTER_UPDATE" }

function Q:Apply(run)
    local db = ns.db
    self.asked, self.tries, self.stuck = nil, 0, nil     -- (a switch changed: whatever was given up on is tried again)
    local can = run and self:Supported() and true or false
    local api = C_QuestLog
    self:ProgressOn(run and (db.questProgress or db.questParty) and type(api) == "table" and api.GetNumQuestLogEntries and api.GetInfo
        and api.GetQuestObjectives and true or false)
    self:ItemsOn(run and db.questItems and type(api) == "table" and api.GetNumQuestLogEntries and api.GetInfo and true or false)
    local short =can and db.questShort and C_QuestLog.GetQuestObjectives ~= nil and true or false
    if self.shortOn and not short then self:Lengthen() end
    self.shortOn = short
    local manage, order = can and Managing(db), can and Ordering(db)
    local focus = can and db.questFocusNear and true or false
    self.focusing = focus
    if manage or order or focus then
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
    if not (order or focus) and self.listening then
        self.listening = false
        events:UnregisterAllEvents()
    end
    if db.questSaved and self:Supported() and not self:Restore() then
        -- the quest log is not loaded yet: put the tracking back as soon as it is
        pcall(events.RegisterEvent, events, "QUEST_LOG_UPDATE")
        pcall(events.RegisterEvent, events, "PLAYER_ENTERING_WORLD")
    end
    if order or focus then self:Sync() end
end

function Q.Describe()
    local api = type(C_QuestLog) == "table" and C_QuestLog or {}
    local listed = Q:Supported() and Listed()
    local wanted = 0
    for _ in pairs(Q.items.byName) do wanted = wanted + 1 end
    for _ in pairs(Q.items.byId) do wanted = wanted + 1 end
    return ("to party %s (%d sent, in a party now %s), "):format(tostring(ns.db and ns.db.questParty or false), Q.partySent,
        tostring(Q.InParty())) .. ("items for quests %s (%d wanted; the game marks quest items in bags: %s), "):format(tostring(Q.itemsOn or false),
        wanted, tostring(type(C_Container) == "table" and C_Container.GetContainerItemQuestInfo ~= nil)) ..
        ("progress in chat %s (%d lines), deciding the list %s, ordering it %s (quests tracked again %d, held for the map %s, slow to redraw %s, the game adds on top: %s, given up on: %s), short objectives %s (%s lines changed), zone quests %s, listed in the game's order: %s; the game has: distance %s, its own sort %s, tags %s, group size %s"):format(
        tostring(Q.chatOn or false), Q.told, tostring(Q.active), tostring(Q.ordering), Q.moved or 0, tostring(Q.held or false), tostring(Q.slowPut or false), tostring(Q.addsOnTop or false), tostring(Q.stuck or "nothing"),
        tostring(Q.shortOn or false), tostring(Q.shortened or 0), tostring(Q.zoneCount),
        listed and table.concat(listed, " ") or "not told",
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
