-- ControllerCam HUD: a farm list beside the quest list.
-- Things you mean to gather or buy (reagents a levelling plan needs, Levelling.lua, or any item), each with how
-- many you have against how many you want: yours in your bags and bank, and your other characters' on this
-- realm (they can mail them over). It is a frame of our own, set beside the game's quest list: to its left
-- (the default), to its right, or under its quests (an option); it fades with the quest list when the screen
-- rests. Nothing of the game's quest list is changed.
-- With the controller: its key binding (or /cchud farm) takes the d-pad to choose, A to want a stack more,
-- X to take one off, Y to clear the list (asked first), B to finish. Those buttons are bound to the list while
-- it is chosen (ns.PadKeys); everything else stays the game's, and a fight gives them back at once.
--   /cchud farm add <item link or id> [how many]   /cchud farm remove <item>   /cchud farm clear

local ADDON, ns = ...
local L = ns.L
local C = ns.colors

local F = { index = 1, rows = {} }
ns.Farm = F

F.MAX = 30                 -- things on the list at most
F.ROWS = 10                -- shown at once
F.KEYS = { "PADDUP", "PADDDOWN", "PAD1", "PAD3", "PAD4", "PAD2", "ESCAPE" }
F.SIDES = { "left", "right", "bottom" }
F.SIDE_NAMES = { L["Left of the quests"], L["Right of the quests"], L["Under the quests"] }

ns.RegisterSetting({
    key = "farmList", kind = "boolean", default = true, command = "farmlist", section = "Quests",
    label = "Farm list beside the quest list",
    tip = "things you mean to gather, with how many you have and how many you want: your bags and bank and your other characters' on this realm. Add the reagents of a levelling plan with one button, or any item",
})
ns.RegisterSetting({
    key = "farmSide", kind = "number", default = 1, min = 1, max = 3, section = "Quests",
    choices = { "Left of the quests", "Right of the quests", "Under the quests" },
    label = "Farm list: where it sits",
    tip = "the farm list to the left of the quest list, to its right, or under its quests",
    onChange = function() F:Place(true) end,
})

-- The list: { { id = item, need = how many you want } }, in the order added
ns.RegisterSaved("farm", function(old)
    local out = {}
    if type(old) ~= "table" then return out end
    local seen = {}
    for _, e in ipairs(old) do
        local id, need = type(e) == "table" and tonumber(e.id), type(e) == "table" and tonumber(e.need)
        if id and need and need >= 1 and not seen[id] and #out < F.MAX then
            seen[id] = true
            out[#out + 1] = { id = math.floor(id), need = math.floor(need) }
        end
    end
    return out
end)

local function List()
    ns.db.farm = ns.db.farm or {}
    return ns.db.farm
end
F.List = List

-- How many of an item you have: yours and your other characters' on this realm
function F.Have(id)
    if ns.Levelling then return ns.Levelling.Have(id) end
    local ok, n = pcall(GetItemCount, id, true)
    return (ok and type(n) == "number") and n or 0
end

local function Find(id)
    for i, e in ipairs(List()) do if e.id == id then return i, e end end
end

local function Stack(id)
    local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local ok, _, _, _, _, _, _, _, stack = pcall(get, id)
    stack = ok and ns.Plain(stack)
    return (type(stack) == "number" and stack > 1) and stack or 20
end

-- Wants this many of an item (a stack, without a number); one already on the list is set to this many.
-- False when the list is full.
function F.Add(id, need, quiet)
    id = tonumber(id)
    if not (id and ns.db) then return false end
    need = math.max(1, math.floor(tonumber(need) or Stack(id)))
    local _, e = Find(id)
    if e then
        e.need = need
    else
        local list = List()
        if #list >= F.MAX then
            if not quiet then ns.Say(L["The farm list is full."]) end
            return false
        end
        list[#list + 1] = { id = id, need = need }
    end
    if not quiet then ns.Say(L["Farm list: %s, %d wanted."]:format(F.Name(id), need)) end
    F:Refresh()
    return true
end

function F.Remove(id)
    local i = Find(tonumber(id) or -1)
    if not i then return false end
    table.remove(List(), i)
    F:Refresh()
    return true
end

function F.Clear()
    ns.db.farm = {}
    F.index = 1
    F:Refresh()
end

function F.Name(id)
    return ns.Professions and ns.Professions.ItemName(id) or ("item " .. tostring(id))
end

-- What the list shows: the things still short first (in the order added), then the ones you have enough of
function F.Rows()
    local short, done = {}, {}
    for _, e in ipairs(List()) do
        local have = F.Have(e.id)
        local row = { id = e.id, need = e.need, have = have, done = have >= e.need }
        if row.done then done[#done + 1] = row else short[#short + 1] = row end
    end
    for _, r in ipairs(done) do short[#short + 1] = r end
    return short
end

---------------------------------------------------------------------------
-- The frame
---------------------------------------------------------------------------
local frame
local WIDTH, ROW = 210, 18

local function KeyName(key)
    if ns.KeyText then return ns.KeyText(key) end                  -- (your controller's own icons: PadIcons.lua)
    local text = GetBindingText and GetBindingText(key) or key
    return (type(text) == "string" and text ~= "") and text or key
end

local function Icon(id)
    if C_Item and C_Item.GetItemIconByID then
        local ok, found = pcall(C_Item.GetItemIconByID, id)
        if ok and (type(found) == "number" or type(found) == "string") then return found end
    end
    return 134400
end

local function Build()
    frame = CreateFrame("Frame", "ControllerCamHUD_FarmList", UIParent)
    frame:SetSize(WIDTH, 60)
    frame:SetFrameStrata("LOW")
    frame.back = frame:CreateTexture(nil, "BACKGROUND")
    frame.back:SetAllPoints(frame)
    frame.back:SetColorTexture(0.03, 0.05, 0.09, 0.55)
    frame.title = ns.FontString(frame, 11, "LEFT")
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -6)
    frame.title:SetTextColor(0.98, 0.82, 0.3)
    frame.count = ns.FontString(frame, 9, "RIGHT")
    frame.count:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -7)
    frame.count:SetTextColor(unpack(C.muted))
    for i = 1, F.ROWS do
        local r = CreateFrame("Frame", nil, frame)
        r:SetSize(WIDTH - 8, ROW - 1)
        r:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -24 - (i - 1) * ROW)
        r.hl = r:CreateTexture(nil, "BACKGROUND")
        r.hl:SetAllPoints(r)
        r.hl:SetColorTexture(1, 1, 1, 0.12)
        r.hl:Hide()
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(14, 14)
        r.icon:SetPoint("LEFT", r, "LEFT", 3, 0)
        r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        r.name = ns.FontString(r, 9, "LEFT")
        r.name:SetPoint("LEFT", r.icon, "RIGHT", 5, 0)
        r.name:SetPoint("RIGHT", r, "RIGHT", -52, 0)
        r.have = ns.FontString(r, 9, "RIGHT")
        r.have:SetPoint("RIGHT", r, "RIGHT", -3, 0)
        F.rows[i] = r
    end
    frame.more = ns.FontString(frame, 8, "LEFT")
    frame.more:SetTextColor(unpack(C.muted))
    frame.hint = ns.FontString(frame, 8, "LEFT")
    frame.hint:SetTextColor(unpack(C.muted))
    if frame.hint.SetWordWrap then frame.hint:SetWordWrap(true) end
    F.keys = ns.PadKeys("Farm", F.KEYS, function(key) F:Pad(key) end, function() F:Manage(false) end)
    frame:Hide()
    F.frame = frame
end

-- The game's quest list
function F.Tracker()
    for _, name in ipairs((ns.Quests and ns.Quests.TRACKERS) or { "ObjectiveTrackerFrame", "QuestWatchFrame", "WatchFrame" }) do
        local t = _G[name]
        if type(t) == "table" and t.GetObjectType then return t end
    end
end

local function Number(v) return (type(v) == "number" and not ns.IsSecret(v)) and v or nil end

-- Where the quest list's lines end: the lowest of what it shows (nil when it cannot be told)
local function ContentBottom(t)
    local top = Number(select(2, pcall(t.GetTop, t)))
    if not top then return nil end
    local low
    local ok, kids = pcall(function() return { t:GetChildren() } end)
    for _, child in ipairs(ok and kids or {}) do
        local okS, shown = pcall(child.IsShown, child)
        local okB, bottom = pcall(child.GetBottom, child)
        bottom = okB and Number(bottom)
        if okS and shown == true and bottom and (not low or bottom < low) then low = bottom end
    end
    if not low then return nil end
    return top - low
end

-- Beside the quest list, on the side chosen
function F:Place(force)
    if not frame then return end
    local t = F.Tracker()
    local side = F.SIDES[ns.db.farmSide or 1] or "left"
    local key, depth = side, nil
    if t and side == "bottom" then
        depth = ContentBottom(t)
        key = side .. ":" .. tostring(depth and math.floor(depth / 4) or "end")
    end
    if not force and key == self.placed and t == self.placedOn then return end
    self.placed, self.placedOn = key, t
    frame:ClearAllPoints()
    if not t then
        frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -40, -300)
    elseif side == "right" then
        frame:SetPoint("TOPLEFT", t, "TOPRIGHT", 10, 0)
    elseif side == "bottom" then
        if depth then frame:SetPoint("TOPLEFT", t, "TOPLEFT", 0, -depth - 10)
        else frame:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -10) end
    else
        frame:SetPoint("TOPRIGHT", t, "TOPLEFT", -10, 0)
    end
    self.side = side
end

function F:Refresh()
    if not frame then
        if not (self.active and #List() > 0) then return end
        Build()
    end
    local rows = F.Rows()
    local want = (self.active and (#rows > 0 or self.managing)) and true or false
    if not want then
        frame:Hide()
        return
    end
    local short = 0
    for _, r in ipairs(rows) do if not r.done then short = short + 1 end end
    frame.title:SetText(L["Farm"])
    frame.count:SetText(#rows > 0 and ("%d / %d"):format(#rows - short, #rows) or "")
    self.index = ns.Clamp(self.index, 1, math.max(1, #rows))
    local top = 1
    if self.index > F.ROWS then top = self.index - F.ROWS + 1 end
    self.list, self.top = rows, top
    local shown = 0
    for i, r in ipairs(self.rows) do
        local e = rows[top + i - 1]
        if e then
            shown = i
            r.icon:SetTexture(Icon(e.id))
            r.name:SetText(F.Name(e.id))
            r.name:SetTextColor(unpack(e.done and C.muted or C.text))
            r.have:SetText(("%d/%d"):format(math.min(e.have, 9999), e.need))
            if e.done then r.have:SetTextColor(0.49, 0.84, 0.56) else r.have:SetTextColor(unpack(C.text)) end
            if self.managing and top + i - 1 == self.index then r.hl:Show() else r.hl:Hide() end
            r:Show()
        else
            r:Hide()
        end
    end
    local y = -24 - shown * ROW
    frame.more:ClearAllPoints()
    frame.more:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, y - 2)
    local extra = #rows - (top - 1) - shown
    frame.more:SetText(extra > 0 and L["%d more"]:format(extra) or (#rows == 0 and L["Nothing to farm yet."] or ""))
    if extra > 0 or #rows == 0 then y = y - 14 end
    frame.hint:ClearAllPoints()
    frame.hint:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, y - 4)
    frame.hint:SetWidth(WIDTH - 16)
    if self.managing then
        frame.hint:SetText(("%s %s  %s %s  %s %s  %s %s"):format(KeyName("PAD1"), L["A stack more"], KeyName("PAD3"),
            L["Take off"], KeyName("PAD4"), L["Clear"], KeyName("PAD2"), L["Done"]))
        frame.hint:Show()
        y = y - 30
    else
        frame.hint:Hide()
    end
    frame:SetHeight(-y + 6)
    self:Place()
    frame:Show()
end

---------------------------------------------------------------------------
-- With the controller
---------------------------------------------------------------------------
function F:Manage(on)
    if on and not self.active then return false end
    self.managing = on and true or false
    if not frame and on then Build() end
    if F.keys then F.keys:Set(self.managing) end
    self:Refresh()
    return self.managing
end

function F:Chosen() return self.list and self.list[self.index] end

-- (the question takes A and B while it is up: the list's buttons step aside, and come back after)
ns.Dialog.Define("CCHUD_FARM_CLEAR", {
    text = L["Take everything off the farm list?"], button1 = L["Clear"], button2 = L["Keep"],
    OnAccept = function() F.Clear(); if F.managing and F.keys then F.keys:Set(true) end end,
    OnCancel = function() if F.managing and F.keys then F.keys:Set(true) end end,
})

function F:Pad(key)
    if not self.managing then return false end
    local e = self:Chosen()
    if key == "PADDUP" then self.index = math.max(1, self.index - 1); self:Refresh()
    elseif key == "PADDDOWN" then self.index = self.index + 1; self:Refresh()
    elseif key == "PAD1" then if e then F.Add(e.id, e.need + Stack(e.id), true) end
    elseif key == "PAD3" then if e then F.Remove(e.id) end
    elseif key == "PAD4" then
        if #List() > 0 then
            F.keys:Set(false)
            ns.Dialog.Show("CCHUD_FARM_CLEAR")
        end
    elseif key == "PAD2" or key == "ESCAPE" then self:Manage(false)
    else return false end
    return true
end

---------------------------------------------------------------------------
-- Listening
---------------------------------------------------------------------------
local events = CreateFrame("Frame")
local pending = false
events:SetScript("OnEvent", ns.Protect(function()
    if pending then return end
    pending = true
    C_Timer.After(0.4, function()             -- (after Inventory.lua has counted what you carry)
        pending = false
        local ok, err = pcall(function() F:Refresh() end)
        if not ok then ns.Error(err) end
    end)
end))
-- the quest list grows and moves, and fades when the screen rests: looked at now and then
local since = 0
events:SetScript("OnUpdate", ns.Protect(function(_, dt)
    if not (frame and frame:IsShown()) then return end
    since = since + dt
    if since < 0.5 then return end
    since = 0
    F:Place()
    local t = F.Tracker()
    local okA, a = false, nil
    if t and not F.managing then okA, a = pcall(t.GetAlpha, t) end
    local okS, shown = false, nil
    if t then okS, shown = pcall(t.IsShown, t) end
    a = (okA and Number(a)) or 1
    if okS and shown == false and not F.managing then a = 1 end      -- no quest list: the farm list on its own
    if frame:GetAlpha() ~= a then frame:SetAlpha(a) end
end))

function F:Apply(run)
    local on = run and ns.db.farmList and true or false
    if on ~= self.active then
        self.active = on
        if on then
            for _, e in ipairs({ "BAG_UPDATE_DELAYED", "BANKFRAME_CLOSED", "PLAYER_ENTERING_WORLD" }) do
                pcall(events.RegisterEvent, events, e)
            end
        else
            events:UnregisterAllEvents()
            if self.managing then self:Manage(false) end
        end
    end
    self.placed = nil
    self:Refresh()
end

function ControllerCamHUD_Farm() ns.Protect(function() F:Manage(not F.managing) end)() end
BINDING_NAME_CCHUD_FARM = L["Farm list: choose / done"]
function ControllerCamHUD_FarmAdd() ns.Protect(function()
    local id = ns.ItemInfo and ns.ItemInfo.Resolve()
    if id then F.Add(id) else ns.Say(L["Point at an item first."]) end
end)() end
BINDING_NAME_CCHUD_FARMADD = L["Farm list: add the item you point at"]

ns.RegisterCommand("farm", function(arg)
    arg = arg or ""
    local word, rest = arg:match("^(%S*)%s*(.-)$")
    if word == "add" then
        local count = tonumber(rest:match("%s(%d+)%s*$") or "")
        local what = count and rest:gsub("%s%d+%s*$", "") or rest
        local id = ns.ItemInfo and ns.ItemInfo.Resolve(what ~= "" and what or nil)
        if id then F.Add(id, count) else ns.Say(L["Point at an item first."]) end
    elseif word == "remove" then
        local id = ns.ItemInfo and ns.ItemInfo.Resolve(rest ~= "" and rest or nil)
        if not (id and F.Remove(id)) then ns.Say(L["That is not on the farm list."]) end
    elseif word == "clear" then
        F.Clear()
        ns.Say(L["The farm list is empty."])
    elseif word == "left" or word == "right" or word == "bottom" then
        for i, s in ipairs(F.SIDES) do
            if s == word then
                ns.db.farmSide = i
                ns.Say(("%s: %s"):format(L["Farm list: where it sits"], F.SIDE_NAMES[i]))
            end
        end
        F:Place(true)
    else
        F:Manage(not F.managing)
    end
end, "/cchud farm", "the farm list beside the quest list: choose with the controller; add <item> [how many], remove <item>, clear, or left / right / bottom for where it sits")

function F.Describe()
    local t = F.Tracker()
    return ("on %s, %d things, side %s, placed %s on %s, shown %s, chosen %s"):format(tostring(ns.db and ns.db.farmList),
        #(ns.db and ns.db.farm or {}), tostring(F.side), tostring(F.placed),
        tostring(t and t.GetName and t:GetName() or "nothing"), tostring(frame ~= nil and frame:IsShown()),
        tostring(F.managing or false))
end

ns.RegisterCheck(function(row, run, db)
    local shown = frame ~= nil and frame:IsShown() and true or false
    if run and db.farmList then
        row("the farm list shows exactly when it has something on it", shown == (#(db.farm or {}) > 0 or F.managing == true))
    else
        row("the farm list is off", not shown)
    end
end)

ns.RegisterModule("farm", F)
