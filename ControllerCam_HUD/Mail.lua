-- ControllerCam HUD: the mailbox, emptied in one go.
-- A button of our own beside the game's "Open All" (which stays the game's): it takes the money and every item
-- out of every letter, auction sales first among them, one at a time as the game allows. Where the game's own
-- button stops (an item you can hold only one of, a letter it skips, the first page of letters done), this one
-- goes on: what cannot be taken is left in its letter and the rest still comes. When the mailbox holds more
-- letters than it shows (it shows 50 at a time), it waits for the next ones and keeps going. Letters that ask
-- for payment on delivery (C.O.D.) are never opened: paying is yours to decide. With your bags full, the money
-- still comes and the items wait. Also a key binding and /cchud mail; pressing it again stops.

local ADDON, ns = ...
local L = ns.L
local say = ns.Say

local MB = { active = false, open = false }
ns.Mail = MB

ns.RegisterSetting({
    key = "mailTakeAll", kind = "boolean", default = true, command = "mailtakeall", section = "Bags, bank and vendor",
    label = "Take everything from the mailbox",
    tip = "a button beside the mailbox's Open All: takes the money and items from every letter, auction sales included, on every page; letters asking for payment on delivery are left alone",
})

MB.STEP = 0.3                -- the least time between two takes (the game refuses them faster)
MB.WAIT = 2                  -- how long a take may go unanswered before the next is tried
MB.MORE = 65                 -- how long to wait for the letters the mailbox does not show yet
MB.ASK = 15                  -- and how often to ask the game for them meanwhile
MB.MAX_ATTACH = ATTACHMENTS_MAX_RECEIVE or 16

local function Num(v) v = ns.Plain and ns.Plain(v) or v; return type(v) == "number" and v or 0 end

-- How many letters the mailbox shows, and how many it holds
function MB.Count()
    if not GetInboxNumItems then return 0, 0 end
    local ok, shown, total = pcall(GetInboxNumItems)
    if not ok then return 0, 0 end
    shown = Num(shown)
    return shown, math.max(shown, Num(total))
end

-- One letter: { money, cod, items = { attachment index, ... }, key } or nil
function MB.Letter(i)
    local ok, _, _, sender, subject, money, cod, days, hasItem = pcall(GetInboxHeaderInfo, i)
    if not ok then return nil end
    local l = { money = Num(money), cod = Num(cod), items = {} }
    l.key = ("%s|%s|%s"):format(tostring(sender), tostring(subject), tostring(days))
    if hasItem then
        for a = 1, MB.MAX_ATTACH do
            local okI, name = pcall(GetInboxItem, i, a)
            if okI and name then l.items[#l.items + 1] = a end
        end
    end
    return l
end

local function FreeSlots()
    local get = (C_Container and C_Container.GetContainerNumFreeSlots) or GetContainerNumFreeSlots
    if not get then return 1 end
    local free = 0
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        local ok, n = pcall(get, bag)
        if ok then free = free + Num(n) end
    end
    return free
end
MB.FreeSlots = FreeSlots

-- The next thing to take: index, "money" or an attachment index, or nil. From the last letter to the first, so
-- a letter the game throws away once empty never moves the ones still to come.
function MB.Next(run)
    local shown = MB.Count()
    local bagsFull = FreeSlots() <= 0
    run.full = false
    for i = shown, 1, -1 do
        local l = MB.Letter(i)
        if l and l.cod <= 0 then
            if l.money > 0 and not run.skip[l.key .. "|money"] then return i, "money", l end
            for _, a in ipairs(l.items) do
                if not run.skip[l.key .. "|" .. a] then
                    if bagsFull then run.full = true else return i, a, l end
                end
            end
        elseif l then
            run.cod = run.cod or {}
            run.cod[l.key] = true
        end
    end
    return nil
end

---------------------------------------------------------------------------
-- The Postmaster says how it went, in chat under his own name, in his own words (a few ways of putting each)
---------------------------------------------------------------------------
MB.SAY = {
    took = { L["There you are: %s, out of the sacks and into your bags. Mind the string."],
             L["All yours: %s. That's the last of the sacks, near enough."],
             L["Signed, sealed and handed over: %s."] },
    nothing = { L["Not a scrap for you today. I checked twice."],
                L["Empty box, friend. Even the moths have moved out."] },
    cod = { L["Letters wanting coin on delivery: %d. Those you open yourself; I don't pay other folks' bills."] },
    full = { L["Your bags are bursting. The rest waits in the letters till you make room."] },
    refused = { L["%d I couldn't pass you: one of a kind, or the box wouldn't let go. Still in their letters."] },
}
function MB.Words(kind)
    local list = MB.SAY[kind]
    return list[math.random(#list)]
end
local function Post(text)
    local chat = ns.Chat
    if chat and chat.Line and type(chat.TAGS) == "table" then
        chat.TAGS.mail = chat.TAGS.mail or { L["Postmaster"], "e6b86a" }
        if chat.Line("mail", text) then return end
    end
    say(text)
end
MB.Post = Post

local function Finish(why)
    local run = MB.run
    if not run then return end
    MB.run = nil
    MB:Label()
    local got = math.max(0, Num(GetMoney and GetMoney()) - run.money0)
    local parts = {}
    if got > 0 then parts[#parts + 1] = ns.Money(got) end
    if run.items == 1 then parts[#parts + 1] = L["1 item"]
    elseif run.items > 1 then parts[#parts + 1] = L["%d items"]:format(run.items) end
    if #parts == 0 then
        if why ~= "closed" then Post(MB.Words("nothing")) end
    else
        Post(MB.Words("took"):format(table.concat(parts, L[" and "])))
    end
    local cod = 0
    for _ in pairs(run.cod or {}) do cod = cod + 1 end
    if cod > 0 then Post(MB.Words("cod"):format(cod)) end
    if run.full then Post(MB.Words("full")) end
    if run.refused > 0 then Post(MB.Words("refused"):format(run.refused)) end
    ns.Note("mail: took %s copper, %d items, %d refused, %d takes (%s)", got, run.items, run.refused, run.takes, tostring(why))
end
MB.Finish = Finish

local function Take(run, i, what, letter)
    run.at, run.busy = GetTime(), { key = letter.key .. "|" .. what, what = what }
    run.takes = run.takes + 1
    if what == "money" then pcall(TakeInboxMoney, i) else pcall(TakeInboxItem, i, what) end
end

local driver = CreateFrame("Frame")
local function Tick()
    local run = MB.run
    if not run then return end
    local now = GetTime()
    if not MB.open then Finish("closed"); return end
    if run.busy then
        if now - run.at < MB.WAIT then return end
        local key = run.busy.key                          -- no answer: tried once more, then left in its letter
        run.timeouts[key] = (run.timeouts[key] or 0) + 1
        if run.timeouts[key] >= 2 then
            run.skip[key] = true
            if run.busy.what ~= "money" then run.refused = run.refused + 1 end
        end
        run.busy = nil
    end
    if now - run.at < MB.STEP then return end
    local i, what, letter = MB.Next(run)
    if i then
        run.waiting = nil
        Take(run, i, what, letter)
        return
    end
    local shown, total = MB.Count()
    if total > shown then                                 -- more letters than it shows: they come in a while
        run.waiting = run.waiting or now
        if now - run.waiting > MB.MORE then Finish("waited"); return end
        if not run.asked or now - run.asked > MB.ASK then
            run.asked = now
            if CheckInbox then pcall(CheckInbox) end
        end
        MB:Label(L["Waiting for more..."])
        return
    end
    Finish("done")
end
driver:SetScript("OnUpdate", ns.Protect(Tick))

-- The game answered the last take
local function Answered(refused)
    local run = MB.run
    if not (run and run.busy) then return end
    if refused then
        run.skip[run.busy.key] = true
        if run.busy.what ~= "money" then run.refused = run.refused + 1 end
    elseif run.busy.what ~= "money" then
        run.items = run.items + 1
    end
    run.busy = nil
end
MB.Answered = Answered

function MB:Start()
    if not self.open then Post(L["Find a mailbox first, then we'll talk."]); return false end
    if self.run then Finish("stopped"); return false end           -- pressed again: stops
    self.run = { skip = {}, timeouts = {}, items = 0, refused = 0, takes = 0, at = -10, money0 = Num(GetMoney and GetMoney()) }
    self:Label(L["Taking..."])
    Tick()
    return true
end

---------------------------------------------------------------------------
-- The button, beside the game's own Open All
---------------------------------------------------------------------------
function MB:Label(text)
    if self.button then self.button:SetText(text or L["Take everything"]) end
end

function MB:Button(show)
    if not show then
        if self.button then self.button:Hide() end
        return
    end
    local inbox = _G.InboxFrame or _G.MailFrame
    if type(inbox) ~= "table" or not inbox.CreateTexture then return end
    if not self.button then
        local b = CreateFrame("Button", nil, inbox, "UIPanelButtonTemplate")
        b:SetSize(120, 22)
        b:SetScript("OnClick", ns.Protect(function() MB:Start() end))
        b:SetScript("OnEnter", function(btn)
            local t = ns.Tooltip and ns.Tooltip.Own()
            if not t then return end
            t:SetOwner(btn, "ANCHOR_TOP")
            t:SetText(L["take the money and items from every letter, auction sales included, on every page (press again to stop); letters asking for payment on delivery are left alone"], 1, 1, 1, 1, true)
            t:Show()
        end)
        b:SetScript("OnLeave", function()
            local t = ns.Tooltip and ns.Tooltip.Own()
            if t then t:Hide() end
        end)
        -- under the window, in the row of the mailbox's tabs (Inbox, Send Mail), past the shoulder button's
        -- prompt beside them, like Smart sell at the vendor: inside the window there is no room to spare
        local last
        for i = 1, 4 do
            local tab = _G["MailFrameTab" .. i]
            if type(tab) == "table" and tab.GetObjectType then last = tab end
        end
        if last then
            b:SetPoint("LEFT", last, "RIGHT", 30, 0)
        else
            b:SetPoint("TOPRIGHT", _G.MailFrame or inbox, "BOTTOMRIGHT", -8, -4)
        end
        self.button = b
        self:Label(self.run and L["Taking..."] or nil)
    end
    self.button:Show()
end

-- Key binding (Bindings.xml)
BINDING_NAME_CCHUD_TAKEMAIL = L["Take everything from the mailbox (press again to stop)"]
function ControllerCamHUD_TakeMail() ns.Protect(function() MB:Start() end)() end
ns.RegisterCommand("mail", function() MB:Start() end, "/cchud mail",
    "take the money and items from every letter in the open mailbox (again to stop)")

---------------------------------------------------------------------------
-- Turning on and off
---------------------------------------------------------------------------
-- What the game says when it will not hand an item over (one of a kind, bags full, and the like)
local REFUSALS = { "ERR_ITEM_MAX_COUNT", "ERR_INV_FULL", "ERR_BAG_FULL", "ERR_MAIL_DATABASE_ERROR",
                   "ERR_ITEM_UNIQUE_EQUIPPABLE", "ERR_TOO_MUCH_GOLD", "ERR_NOT_ENOUGH_GOLD" }
local function Refusal(msg)
    if type(msg) ~= "string" or ns.IsSecret(msg) then return false end
    for _, name in ipairs(REFUSALS) do
        if _G[name] and msg == _G[name] then return true end
    end
    return false
end
MB.Refusal = Refusal

---------------------------------------------------------------------------
-- Sending: what you attach names the letter. While its subject is empty (or still the one we wrote), it says
-- what goes in it: "Linen Cloth x20", "Linen Cloth x20, Wool Cloth x5", "Linen Cloth x20 and 3 more". A subject
-- you typed yourself is never touched. Typing on a controller is slow; this spares it.
---------------------------------------------------------------------------
ns.RegisterSetting({
    key = "mailSubject", kind = "boolean", default = true, command = "mailsubject", section = "Bags, bank and vendor",
    label = "Mail: subject from what you attach",
    tip = "attaching items to a letter fills in its subject with what they are (Linen Cloth x20, or the first and how many more); a subject you typed yourself is left alone",
})
MB.SUBJECT_MAX = 64

function MB.SubjectFor()
    if not GetSendMailItem then return nil end
    local order, counts = {}, {}
    for i = 1, (ATTACHMENTS_MAX_SEND or 12) do
        local ok, name, _, _, count = pcall(GetSendMailItem, i)
        if ok and type(name) == "string" and name ~= "" and not ns.IsSecret(name) then
            count = (type(count) == "number" and not ns.IsSecret(count) and count > 0) and count or 1
            if not counts[name] then order[#order + 1] = name; counts[name] = 0 end
            counts[name] = counts[name] + count
        end
    end
    if #order == 0 then return nil end
    local function One(name) return counts[name] > 1 and ("%s x%d"):format(name, counts[name]) or name end
    if #order == 2 then
        local both = One(order[1]) .. ", " .. One(order[2])
        if #both <= MB.SUBJECT_MAX then return both end
    end
    if #order >= 2 then return L["%s and %d more"]:format(One(order[1]), #order - 1):sub(1, MB.SUBJECT_MAX) end
    return One(order[1]):sub(1, MB.SUBJECT_MAX)
end

function MB.FillSubject()
    if not ns.db.mailSubject then return end
    local box = _G.SendMailSubjectEditBox
    if type(box) ~= "table" or not (box.GetText and box.SetText) then return end
    local ok, now = pcall(box.GetText, box)
    if not ok or ns.IsSecret(now) then return end
    now = now or ""
    if now ~= "" and now ~= MB.filled then return end                  -- yours: left alone
    local want = MB.SubjectFor() or ""
    if want == now then return end
    pcall(box.SetText, box, want)
    MB.filled = want ~= "" and want or nil
    MB.subjects = (MB.subjects or 0) + 1
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", ns.Protect(function(_, event, a, b)
    if event == "MAIL_SEND_INFO_UPDATE" then
        MB.FillSubject()
    elseif event == "MAIL_SEND_SUCCESS" then
        MB.filled = nil
    elseif event == "MAIL_SHOW" then
        MB.open = true
        MB:Button(ns.db.mailTakeAll and true or false)
    elseif event == "MAIL_CLOSED" then
        MB.open = false
        if MB.run then Finish("closed") end
    elseif event == "MAIL_INBOX_UPDATE" or event == "MAIL_SUCCESS" then
        Answered(false)
    elseif event == "MAIL_FAILED" then
        Answered(true)
    elseif event == "UI_ERROR_MESSAGE" then
        if Refusal(type(b) == "string" and b or a) then Answered(true) end
    end
end))

local WATCH = { "MAIL_SHOW", "MAIL_CLOSED", "MAIL_INBOX_UPDATE", "MAIL_SUCCESS", "MAIL_FAILED", "UI_ERROR_MESSAGE",
                "MAIL_SEND_INFO_UPDATE", "MAIL_SEND_SUCCESS" }
function MB:Apply(run)
    local want = run and (ns.db.mailTakeAll or ns.db.mailSubject) and true or false
    if self.active and want then self:Button(ns.db.mailTakeAll and self.open) end
    if want and not self.active then
        self.active = true
        for _, e in ipairs(WATCH) do pcall(events.RegisterEvent, events, e) end
        if self.open then self:Button(ns.db.mailTakeAll and true or false) end
    elseif not want and self.active then
        self.active = false
        events:UnregisterAllEvents()
        if self.run then Finish("off") end
        self:Button(false)
    end
end
ns.RegisterModule("mail", MB)
