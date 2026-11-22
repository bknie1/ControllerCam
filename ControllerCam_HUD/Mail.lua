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
        if why ~= "closed" then say(L["Nothing to take from the mailbox."]) end
    else
        say(L["Mailbox: took %s."]:format(table.concat(parts, L[" and "])))
    end
    local cod = 0
    for _ in pairs(run.cod or {}) do cod = cod + 1 end
    if cod > 0 then say(L["Letters asking for payment on delivery, left for you to open: %d"]:format(cod)) end
    if run.full then say(L["Your bags are full: the other items wait in their letters."]) end
    if run.refused > 0 then say(L["Items the game would not hand over (one of a kind, or refused), left in their letters: %d"]:format(run.refused)) end
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
    if not self.open then say(L["Open a mailbox first."]); return false end
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
        local game = _G.OpenAllMail
        if type(game) == "table" and game.GetObjectType then
            b:SetPoint("LEFT", game, "RIGHT", 6, 0)
        else
            b:SetPoint("BOTTOM", inbox, "BOTTOM", 0, 100)
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

local events = CreateFrame("Frame")
events:SetScript("OnEvent", ns.Protect(function(_, event, a, b)
    if event == "MAIL_SHOW" then
        MB.open = true
        MB:Button(true)
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

local WATCH = { "MAIL_SHOW", "MAIL_CLOSED", "MAIL_INBOX_UPDATE", "MAIL_SUCCESS", "MAIL_FAILED", "UI_ERROR_MESSAGE" }
function MB:Apply(run)
    local want = run and ns.db.mailTakeAll and true or false
    if want and not self.active then
        self.active = true
        for _, e in ipairs(WATCH) do pcall(events.RegisterEvent, events, e) end
        if self.open then self:Button(true) end
    elseif not want and self.active then
        self.active = false
        events:UnregisterAllEvents()
        if self.run then Finish("off") end
        self:Button(false)
    end
end
ns.RegisterModule("mail", MB)
