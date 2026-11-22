-- ControllerCam HUD: chat that is easier to read and quieter.
--   * Who is talking: a player's class icon and level in brackets in front of their name,
--         [icon 42] Name: what they say
--     when the game lets us know them (people in your group, guild and friends, players you have seen around
--     or looked up with /who). Names in their class colour are the game's own chat setting (Options: "Class
--     colours for names in chat").
--     The game builds "[Name]: text" itself and an addon cannot change that part, so the finished line is
--     dressed on its way into the chat window: the brackets move from the name to the badge. Nothing else of
--     the line is touched, and the name stays the link it was (right-click, whisper).
--   * Short channel names: [P] party, [PL] party leader, [G] guild, [O] officer, [R] raid, [RL] raid leader,
--     [RW] raid warning, [I] instance, [IL] instance leader, and a numbered channel by its number alone
--     ("[1. General - Stranglethorn Vale]" is "[1]"). The channel stays the link it was (click it to talk there).
--   * First names only (an option, off to begin with): "Jory Spleeneater" says it as "Jory". Only the name shown
--     is shortened (and a realm after it kept); the link under it is the whole name, so a whisper or a right-click
--     still finds them.
--   * Text you can read from the couch: the chat windows' text at a share of the game's own size (150% to
--     begin with). Only the windows' font is set, while the HUD runs; the game's own chat setting is left
--     as it is and is what you get back when this is off.
--   * Spam: gold sellers and adverts with a web address are hidden, and so is the same message repeated by
--     the same player within a couple of minutes. Your group, guild and friends are never filtered.
--     /cchud spam lists what was hidden lately, so nothing disappears without a trace.
--   * Guild recruitment: in public channels a guild's recruiting message is shown once; the same player's
--     again, or one nearly the same from anyone, within 15 minutes is hidden. Counted in /cchud spam.
--   * The HUD's own short lines (CH.Line): "[Q] Bloody Bone Necklaces: 4/25", "[F] Booty Bay: about 2:10", in
--     the look of the short channel names. Printed like any addon's line.
-- Uses the game's message filters for addons; the chat itself is the game's.

local ADDON, ns = ...
local L = ns.L

local CH = { active = false, hidden = 0, recent = {}, levels = {}, byName = {}, lines = {}, authors = {}, said = {},
             dressed = 0 }
ns.Chat = CH

ns.RegisterSetting({
    key = "chatInfo", kind = "boolean", default = true, command = "chatinfo", section = "Quests, chat and map",
    label = "Class icon and level in chat",
    tip = "a player's class icon and level in brackets in front of their name, when the game lets us know them",
})
ns.RegisterSetting({
    key = "chatShort", kind = "boolean", default = true, command = "chatshort", section = "Quests, chat and map",
    label = "Short channel names in chat",
    tip = "the channel in front of a line, shortened: [P] party, [PL] party leader, [G] guild, [O] officer, [R] raid, [RL] raid leader, [I] instance, and a numbered channel by its number, [1]",
})
ns.RegisterSetting({
    key = "chatFirstName", kind = "boolean", default = false, command = "chatfirstname", section = "Quests, chat and map",
    label = "First names only in chat",
    tip = "a name with a surname shows as the first name alone (Jory Spleeneater says it as Jory); a whisper or a right-click on it still reaches the whole name",
})
ns.RegisterSetting({
    key = "chatScale", kind = "number", default = 1.5, min = 1, max = 2, percent = true, command = "chatsize",
    section = "Quests, chat and map", label = "Chat text size",
    tip = "the size of the text in the chat windows, as a share of the game's own size (the game's own setting is left as it is)",
})
ns.RegisterSetting({
    key = "chatSpam", kind = "boolean", default = true, command = "chatspam", section = "Quests, chat and map",
    label = "Hide gold sellers and repeated adverts",
    tip = "messages selling gold or services with a web address, and the same message repeated by one player, are hidden (never from your group, guild or friends)",
})
ns.RegisterSetting({
    key = "chatRecruit", kind = "boolean", default = true, command = "chatrecruit", section = "Quests, chat and map",
    label = "Hide repeated guild recruitment",
    tip = "in public channels a guild's recruiting message is shown once; the same player's again, or one nearly the same, within 15 minutes is hidden (never from your group, guild or friends)",
})

local REPEAT = 120              -- seconds within which the same message from the same player is a repeat
local EVENTS = { "CHAT_MSG_CHANNEL", "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_WHISPER", "CHAT_MSG_EMOTE",
                 "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID",
                 "CHAT_MSG_RAID_LEADER", "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER" }
local PUBLIC = { CHAT_MSG_CHANNEL = true, CHAT_MSG_SAY = true, CHAT_MSG_YELL = true, CHAT_MSG_WHISPER = true,
                 CHAT_MSG_EMOTE = true }          -- where spam comes from

---------------------------------------------------------------------------
-- Levels we know: your group, and players you see (target, mouseover, nameplates)
---------------------------------------------------------------------------
local function Note(unit)
    local ok, isPlayer = pcall(UnitIsPlayer, unit)
    if not ok or not isPlayer or ns.IsSecret(isPlayer) then return end
    local guid, level = ns.GUID(unit), UnitLevel(unit)
    if guid and not ns.IsSecret(guid) and type(level) == "number" and not ns.IsSecret(level) and level > 0 then
        CH.levels[guid] = level
    end
end

local function NoteGroup()
    for i = 1, 4 do Note("party" .. i) end
    for i = 1, 40 do Note("raid" .. i) end
    Note("player")
end

-- ... and the lists that name people without a unit to look at: friends, your guild, a /who result
local function Short(name)
    return (type(name) == "string" and not ns.IsSecret(name)) and name:match("^([^-]+)") or nil
end

local function NoteName(name, level)
    name = Short(name)
    if name and type(level) == "number" and not ns.IsSecret(level) and level > 0 then CH.byName[name] = level end
end

local listsAt = -100
local function NoteLists()
    local now = GetTime()
    if now - listsAt < 10 then return end
    listsAt = now
    local FL = C_FriendList
    if FL and FL.GetNumFriends and FL.GetFriendInfoByIndex then
        local ok, n = pcall(FL.GetNumFriends)
        for i = 1, (ok and type(n) == "number") and math.min(n, 200) or 0 do
            local okI, info = pcall(FL.GetFriendInfoByIndex, i)
            if okI and type(info) == "table" then NoteName(info.name, info.level) end
        end
    end
    if FL and FL.GetNumWhoResults and FL.GetWhoInfo then
        local ok, n = pcall(FL.GetNumWhoResults)
        for i = 1, (ok and type(n) == "number") and math.min(n, 100) or 0 do
            local okI, info = pcall(FL.GetWhoInfo, i)
            if okI and type(info) == "table" then NoteName(info.fullName, info.level) end
        end
    end
    if GetNumGuildMembers and GetGuildRosterInfo then
        local ok, n = pcall(GetNumGuildMembers)
        for i = 1, (ok and type(n) == "number") and math.min(n, 1000) or 0 do
            local okI, name, _, _, level = pcall(GetGuildRosterInfo, i)
            if okI then NoteName(name, level) end
        end
    end
end

---------------------------------------------------------------------------
-- Spam
---------------------------------------------------------------------------
local SELLING = { "gold", "wts", "cheap", "deliver", "price", "discount", "usd", "eur", "boost", "carry",
                  "powerlevel", "account", "coupon", "%$", "€" }
local ADDRESS = { "www", "%.com", "%.net", "%.org", "%.cc", "%.xyz", "%.ru", "c0m", "dotcom", "http" }

-- the message without colours, links' brackets, spaces and the usual disguises, in lower case
local function Squash(msg)
    local s = msg:lower():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|h", "")
    s = s:gsub("%s*[%(%[]?%s*dot%s*[%)%]]?%s*", "."):gsub("[%s%*_%-~|]", "")
    return s
end
CH.Squash = Squash

function CH.IsAdvert(msg)
    local s = Squash(msg)
    local address = false
    for _, p in ipairs(ADDRESS) do if s:find(p) then address = true; break end end
    if not address then return false end
    for _, p in ipairs(SELLING) do if s:find(p) then return true end end
    return false
end

-- Someone you know: never filtered
local function Known(author, guid)
    local name = author and author:match("^([^-]+)")
    if not name then return false end
    local me = UnitName("player")
    if not ns.IsSecret(me) and name == me then return true end
    local ok, inGroup = pcall(function() return UnitInParty(name) or UnitInRaid(name) end)
    if ok and inGroup then return true end
    if guid and C_FriendList and C_FriendList.IsFriend then
        local okF, friend = pcall(C_FriendList.IsFriend, guid)
        if okF and friend then return true end
    end
    if C_GuildInfo and C_GuildInfo.MemberExistsByName then
        local okG, guild = pcall(C_GuildInfo.MemberExistsByName, name)
        if okG and guild then return true end
    end
    return false
end

local function Hide(author, msg, why)
    CH.hidden = CH.hidden + 1
    table.insert(CH.recent, 1, { author = author, text = msg, why = why })
    if #CH.recent > 10 then table.remove(CH.recent) end
end

---------------------------------------------------------------------------
-- Guild recruitment: shown once, its repeats hidden for a while
---------------------------------------------------------------------------
CH.RECRUIT_WINDOW = 900         -- seconds within which a recruiting message again is a repeat
CH.recruitHidden = 0
local RECRUIT_EVENTS = { CHAT_MSG_CHANNEL = true, CHAT_MSG_SAY = true, CHAT_MSG_YELL = true }
-- Words that say "recruiting" by themselves, a guild, and what a guild that recruits asks for (a few languages)
local RECRUITING = { "recruit", "recrut", "rekrut", "reclut", "набор", "招募", "招人", "모집" }
local GUILD = { "guild", "gilde", "hermandad", "gilda", "гильди", "公会", "公會", "길드", "<[^>]+>" }
local ASKING = { "member", "join", "inv", "apply", "raiders", "all levels", "/w", "whisper", "social", "new players",
                 "mitglied", "membre", "miembro", "membri", "membro", "игрок", "成员", "成員", "길드원" }

-- The message in lower case, without colours and links' codes, its spaces run together
local function Words(msg)
    local s = msg:lower():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H[^|]*|h", ""):gsub("|h", "")
    return (s:gsub("%s+", " "))
end

local function AnyOf(s, list)
    for _, p in ipairs(list) do if s:find(p) then return true end end
    return false
end

function CH.IsRecruit(msg)
    local s = Words(msg)
    if AnyOf(s, RECRUITING) then return true end
    return AnyOf(s, GUILD) and AnyOf(s, ASKING)
end

-- The words of a message as a set (letters only: numbers, symbols and spacing do not make it new)
local function WordSet(msg)
    local set, n = {}, 0
    for w in Words(msg):gmatch("[^%s%p%d]+") do
        if not set[w] then set[w], n = true, n + 1 end
    end
    return set, n
end

-- Nearly the same: most of their words shared (or the very same words, for a short one)
local function Alike(a, an, b, bn)
    local both = 0
    for w in pairs(a) do if b[w] then both = both + 1 end end
    local either = an + bn - both
    if either == 0 then return true end
    if an < 4 or bn < 4 then return both == either end
    return both / either >= 0.75
end
CH.Alike = function(x, y)
    local a, an = WordSet(x)
    local b, bn = WordSet(y)
    return Alike(a, an, b, bn)
end

CH.recruiters, CH.recruitTexts = {}, {}
-- Was this recruiting message (or one nearly the same) said within the window? It counts as said now.
local function RecruitAgain(author, msg)
    local now, window = GetTime(), CH.RECRUIT_WINDOW
    local name = Short(author) or ""
    local again = false
    local last = CH.recruiters[name]
    if last and now - last < window then again = true end
    local set, n = WordSet(msg)
    for i = #CH.recruitTexts, 1, -1 do
        local t = CH.recruitTexts[i]
        if now - t.at >= window then
            table.remove(CH.recruitTexts, i)
        elseif not again and Alike(set, n, t.set, t.n) then
            again = true
            t.at = now
        end
    end
    CH.recruiters[name] = now
    if not again then
        table.insert(CH.recruitTexts, { set = set, n = n, at = now })
        if #CH.recruitTexts > 40 then table.remove(CH.recruitTexts, 1) end
    end
    return again
end

-- A message is shown in every chat window that has its channel: decide once per message (by its line id)
local decided = {}
local function Spam(event, msg, author, guid, lineID)
    if lineID and decided[lineID] ~= nil then return decided[lineID] end
    local verdict = false
    if PUBLIC[event] and not Known(author, guid) then
        if ns.db.chatSpam and CH.IsAdvert(msg) then
            verdict = true
            Hide(author, msg, "advert")
        elseif ns.db.chatRecruit and RECRUIT_EVENTS[event] and CH.IsRecruit(msg) then
            if RecruitAgain(author, msg) then
                verdict = true
                CH.recruitHidden = CH.recruitHidden + 1
                Hide(author, msg, "recruit")
            end
        elseif ns.db.chatSpam then
            local key = (author or "") .. "\1" .. Squash(msg)
            local now = GetTime()
            local last = CH.said[key]
            CH.said[key] = now
            if last and now - last < REPEAT then
                verdict = true
                Hide(author, msg, "repeat")
            end
        end
    end
    if lineID then decided[lineID] = verdict end
    return verdict
end

---------------------------------------------------------------------------
-- The class icon and level in front of a message
---------------------------------------------------------------------------
local ICONS = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
-- guid: the player's (may be nil); author: their name as the chat line gives it (for levels known by name only)
function CH.Badge(guid, author)
    if ns.IsSecret(guid) or type(guid) ~= "string" or not guid:find("^Player%-") then guid = nil end
    local class
    if guid then
        local ok, _, c = pcall(GetPlayerInfoByGUID, guid)
        if ok then class = c end
    end
    local parts = {}
    local c = class and not ns.IsSecret(class) and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
    if c then
        parts[#parts + 1] = ("|T%s:0:0:0:0:256:256:%d:%d:%d:%d|t"):format(ICONS, c[1] * 256, c[2] * 256, c[3] * 256, c[4] * 256)
    end
    local level = (guid and CH.levels[guid]) or CH.byName[Short(author) or ""]
    if level then
        local r, g, b = ns.LevelColor(level)
        parts[#parts + 1] = ("|cff%02x%02x%02x%d|r"):format(r * 255, g * 255, b * 255, level)
    end
    if #parts == 0 then return nil end
    return table.concat(parts)                           -- the icon right against the level: "[icon42]"
end

-- A finished chat line, on its way into a chat window: "[Name]: text" becomes "[icon 42] Name: text". Only
-- the lines of people talking (the kinds we filter), told by the line number the game puts in the name's
-- link; anything else, and anything we cannot read, goes through as it is.
function CH.Dress(text)
    if not (CH.active and ns.db.chatInfo) or type(text) ~= "string" or ns.IsSecret(text) then return text end
    local head, link, target, rest = text:match("^(.-)(|Hplayer:([^|]*)|h)%[(.*)$")
    if not link then return text end
    local name, tail = rest:match("^(.-)%]|h(.*)$")
    if not name then return text end
    local who, lineID = target:match("^([^:]*):?(%d*)")
    local line = CH.lines[tonumber(lineID) or 0]
    local guid = line and line.guid
    if not line then
        if lineID ~= "" then return text end                -- a line of another kind (an achievement, a roll)
        guid = CH.authors[who]                              -- (a client whose links carry no line number)
        if not guid then return text end
    end
    local badge = CH.Badge(guid, who)
    if not badge then return text end
    CH.dressed = CH.dressed + 1
    return head .. "[" .. badge .. "] " .. link .. name .. "|h" .. tail
end

-- The channel's name in front of a line, shortened. The game's own words for its channels (in your language) are
-- matched, the English ones too; a numbered channel goes by its number. Anything else stays as it was.
CH.SHORT = { { "CHAT_MSG_PARTY_LEADER", "Party Leader", "PL" }, { "CHAT_MSG_PARTY", "Party", "P" },
             { "CHAT_MSG_GUILD", "Guild", "G" }, { "CHAT_MSG_OFFICER", "Officer", "O" },
             { "CHAT_MSG_RAID_LEADER", "Raid Leader", "RL" }, { "CHAT_MSG_RAID_WARNING", "Raid Warning", "RW" },
             { "CHAT_MSG_RAID", "Raid", "R" }, { "CHAT_MSG_INSTANCE_CHAT_LEADER", "Instance Leader", "IL" },
             { "CHAT_MSG_INSTANCE_CHAT", "Instance", "I" } }
local shortOf
function CH.Shorten(text)
    if not (CH.running and ns.db.chatShort) or type(text) ~= "string" or ns.IsSecret(text) then return text end
    if not shortOf then
        shortOf = {}
        for _, s in ipairs(CH.SHORT) do
            shortOf[s[2]] = s[3]
            local own = _G[s[1]]
            if type(own) == "string" and own ~= "" then shortOf[own] = s[3] end
        end
    end
    return (text:gsub("(|Hchannel:[^|]*|h)%[(.-)%](|h)", function(open, name, close)
        local short = name:match("^(%d+)%.") or shortOf[name]
        if short then return open .. "[" .. short .. "]" .. close end
    end))
end

-- A name as it is shown, cut to its first name: "Jory Spleeneater" is "Jory", "Jory Spleeneater-Forever" is
-- "Jory-Forever"; its class colour, if any, kept round it
function CH.FirstName(name)
    if type(name) ~= "string" or ns.IsSecret(name) then return name end
    local pre, core, post = name:match("^(|c%x%x%x%x%x%x%x%x)(.-)(|r)$")
    if not pre then pre, core, post = "", name, "" end
    local first, rest = core:match("^(%S+)%s+(.+)$")
    if not first then return name end
    local realm = rest:match("(%-[^%s%-]+)$") or ""
    return pre .. first .. realm .. post
end

-- Every player's name shown in a line, cut to the first name (the link itself untouched)
function CH.Firsts(text)
    if not (CH.running and ns.db.chatFirstName) or type(text) ~= "string" or ns.IsSecret(text) then return text end
    return (text:gsub("(|Hplayer:[^|]*|h)%[(.-)%](|h)", function(open, name, close)
        return open .. "[" .. CH.FirstName(name) .. "]" .. close
    end))
end

-- Every chat window's way in is wrapped once (and given back when this is switched off)
local hooked = {}
local function Hook(on)
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local frame = _G["ChatFrame" .. i]
        if type(frame) == "table" and type(frame.AddMessage) == "function" then
            local h = hooked[frame]
            if on and not h then
                local orig = frame.AddMessage
                local mine = function(self, text, ...)
                    local okS, short = pcall(CH.Shorten, text)
                    if okS and short ~= nil then text = short end
                    local okF, first = pcall(CH.Firsts, text)
                    if okF and first ~= nil then text = first end
                    local ok, dressed = pcall(CH.Dress, text)
                    return orig(self, (ok and dressed ~= nil) and dressed or text, ...)
                end
                hooked[frame] = { mine = mine, own = rawget(frame, "AddMessage") }
                frame.AddMessage = mine
            elseif not on and h and rawget(frame, "AddMessage") == h.mine then
                frame.AddMessage = h.own                     -- (wrapped again by someone since: ours stays, and passes lines on)
                hooked[frame] = nil
            end
        end
    end
end
CH.hooked = hooked

-- The chat windows' text, bigger. What each window had is remembered (and noticed again when the game sets
-- it anew), so "off" gives back exactly that.
local sized = {}
local function Size(on)
    local scale = on and (ns.db.chatScale or 1) or 1
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local frame = _G["ChatFrame" .. i]
        if type(frame) == "table" and type(frame.GetFont) == "function" and type(frame.SetFont) == "function" then
            local ok, file, size, flags = pcall(frame.GetFont, frame)
            if ok and type(file) == "string" and type(size) == "number" then
                local rec = sized[frame]
                local own = (rec and math.abs(size - rec.set) < 0.5) and rec.own or size   -- (else the game set it anew)
                local ownFile = (rec and rec.file) or file                                 -- the window's own typeface
                local want = math.floor(own * scale + 0.5)
                local useFile = (on and ns.ChosenFont()) or ownFile                        -- (your font, if you chose one)
                if math.abs(want - size) >= 0.5 or useFile ~= file then pcall(frame.SetFont, frame, useFile, want, flags) end
                sized[frame] = (want ~= own or useFile ~= ownFile) and { own = own, set = want, file = ownFile } or nil
            end
        end
    end
end
CH.sized = sized

-- The tables of what was decided and said stay small
local function Trim()
    local n = 0
    for _ in pairs(decided) do n = n + 1 end
    if n > 400 then decided = {} end
    n = 0
    for _ in pairs(CH.lines) do n = n + 1 end
    if n > 300 then CH.lines = {} end
    n = 0
    for _ in pairs(CH.authors) do n = n + 1 end
    if n > 300 then CH.authors = {} end
    n = 0
    local now = GetTime()
    for key, at in pairs(CH.said) do
        if now - at > REPEAT then CH.said[key] = nil else n = n + 1 end
    end
    for name, at in pairs(CH.recruiters) do
        if now - at > CH.RECRUIT_WINDOW then CH.recruiters[name] = nil end
    end
end

-- The game's filter call: true hides the message; false, then the message's arguments, changes it. Every
-- argument after the message is passed on untouched.
local function Filter(_, event, msg, author, ...)
    if not CH.active or type(msg) ~= "string" or ns.IsSecret(msg) or ns.IsSecret(author) then return false end
    local guid, lineID = select(10, ...), select(9, ...)
    if ns.IsSecret(guid) then guid = nil end
    if ns.IsSecret(lineID) then lineID = nil end
    if ns.db.chatSpam or ns.db.chatRecruit then
        local ok, spam = pcall(Spam, event, msg, author, guid, lineID)
        if not ok then ns.Error(spam) elseif spam then return true end
    end
    if ns.db.chatInfo and type(author) == "string" then      -- who said this line, for when it reaches the window
        if lineID then CH.lines[lineID] = { guid = guid, author = author } end
        if guid then CH.authors[author] = guid end
    end
    return false
end

ns.RegisterCommand("spam", function()
    ns.Say(L["%d messages hidden as spam since you logged in."]:format(CH.hidden))
    if CH.recruitHidden > 0 or ns.db.chatRecruit then
        ns.Say(L["%d of them were repeated guild recruitment."]:format(CH.recruitHidden))
    end
    for _, r in ipairs(CH.recent) do
        print(("  [%s] %s: %s"):format(r.why, tostring(r.author), tostring(r.text):sub(1, 80)))
    end
end, "/cchud spam", "list the chat messages hidden as spam lately")

---------------------------------------------------------------------------
-- Listening
---------------------------------------------------------------------------
local seen = CreateFrame("Frame")
seen:SetScript("OnEvent", ns.Protect(function(_, event, unit)
    if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then NoteGroup(); Trim()
    elseif event == "PLAYER_TARGET_CHANGED" then Note("target")
    elseif event == "UPDATE_MOUSEOVER_UNIT" then Note("mouseover"); if math.random(50) == 1 then Trim() end
    elseif event == "FRIENDLIST_UPDATE" or event == "GUILD_ROSTER_UPDATE" or event == "WHO_LIST_UPDATE" then NoteLists()
    elseif event == "UPDATE_CHAT_WINDOWS" or event == "UPDATE_FLOATING_CHAT_WINDOWS" then Size(CH.sizing)
    elseif unit then Note(unit) end
end))

local filtering = false
function CH:Apply(run)
    CH.sizing = run and true or false
    CH.running = run and true or false
    Size(CH.sizing)
    if run then
        for _, e in ipairs({ "UPDATE_CHAT_WINDOWS", "UPDATE_FLOATING_CHAT_WINDOWS" }) do pcall(seen.RegisterEvent, seen, e) end
    end
    local want = run and (ns.db.chatInfo or ns.db.chatSpam or ns.db.chatRecruit) and true or false
    local add = ChatFrame_AddMessageEventFilter or (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter)
    if want and not filtering and add then
        filtering = true                     -- added once: they check whether we are on
        for _, e in ipairs(EVENTS) do pcall(add, e, Filter) end
    end
    if want ~= self.active then
        self.active = want
        if want then
            for _, e in ipairs({ "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED",
                                 "UPDATE_MOUSEOVER_UNIT", "NAME_PLATE_UNIT_ADDED", "FRIENDLIST_UPDATE",
                                 "GUILD_ROSTER_UPDATE", "WHO_LIST_UPDATE" }) do
                pcall(seen.RegisterEvent, seen, e)
            end
            NoteGroup()
            NoteLists()
        else
            seen:UnregisterAllEvents()
            if run then                                 -- (still wanted for the text size)
                for _, e in ipairs({ "UPDATE_CHAT_WINDOWS", "UPDATE_FLOATING_CHAT_WINDOWS" }) do pcall(seen.RegisterEvent, seen, e) end
            end
        end
    end
    Hook(run and (ns.db.chatInfo or ns.db.chatShort or ns.db.chatFirstName) and true or false)
end

function CH.Describe()
    local windows, names = 0, 0
    for _ in pairs(hooked) do windows = windows + 1 end
    for _ in pairs(CH.byName) do names = names + 1 end
    return ("on %s, windows dressed %d, lines dressed %d, levels known by name %d, hidden %d (guild recruitment %d), HUD lines %d"):format(
        tostring(CH.active), windows, CH.dressed, names, CH.hidden, CH.recruitHidden, CH.printed or 0)
end

---------------------------------------------------------------------------
-- The HUD's own short lines in chat, in the look of the short channel names
---------------------------------------------------------------------------
CH.TAGS = { quest = { "Q", "ffd24a" }, flight = { "F", "8fd3ff" }, water = { "W", "7fc8ff" } }
function CH.Line(kind, text)
    if type(text) ~= "string" or ns.IsSecret(text) or text == "" then return false end
    local tag = CH.TAGS[kind] or { "HUD", "66ccff" }
    print(("|cff%s[%s]|r %s"):format(tag[2], tag[1], text))
    CH.printed = (CH.printed or 0) + 1
    return true
end

ns.RegisterModule("chat", CH)
