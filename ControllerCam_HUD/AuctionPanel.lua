-- ControllerCam HUD: the Market, a tab of the auction house.
-- The auction house gets one more tab, "Market". It answers one question:
-- what in my bags should I sell here, and for how much?
--   * the list: what you carry that the house takes. First what is worth selling here (it brings more than a
--     vendor pays, after the house's cut), each with the price we would ask and why; then the rest.
--   * beside the house, a pane that only shows (nothing in it to press): the chosen item's price chart for the
--     last 30 days, its usual price, how many are up, what a vendor pays, and the reasoning in full.
--   * one press posts every one you carry of the chosen item at the asking price. Patient (the default) or
--     quick sale, and how long (12, 24 or 48 hours).
--   * by default only what you would sell is listed: what you keep for your professions (a recipe of yours
--     still learns from it, or it is worth more made into something) and what you marked to keep are left
--     out until you ask for them (RB, or the switch in the options).
--   * the Broker: a goblin auctioneer's counter (the auctioneer you talk to as its portrait), who greets you
--     with one of the game's own goblin lines when the Market opens (a switch turns it off).
-- From the controller: up and down choose (the pane follows), A posts, X switches patient and quick, Y how
-- long, RB shows or hides what you keep, B goes back to the house. With a mouse: point at a row to choose
-- it, click it to post.
-- Posting needs your press (the game requires it); nothing is ever posted by itself.

local ADDON, ns = ...
local L, C = ns.L, ns.colors

local AP = { rows = {}, index = 1, perPage = 8 }
ns.AuctionPanel = AP

ns.RegisterSetting({
    key = "ahPanel", kind = "boolean", default = true, command = "ahpanel", section = "Bags, bank and vendor",
    label = "Market tab at the auction house",
    tip = "a Market tab on the auction house: what in your bags is worth selling there and why, a price chart beside it, and posting in one press",
})
ns.RegisterSetting({
    key = "ahVoice", kind = "boolean", default = true, command = "ahvoice", section = "Bags, bank and vendor",
    label = "Auctioneer's greeting on the Market",
    tip = "a goblin auctioneer says one short line, from the game's own sounds, when the Market opens; off: it opens in silence",
})
ns.RegisterSetting({
    key = "ahShowKept", kind = "boolean", default = false, command = "ahkept", section = "Bags, bank and vendor",
    label = "Market: show what you keep",
    tip = "the Market lists what you keep too: what your professions still learn from or make into something worth more, and what you marked to keep; off: only what you would sell",
})
ns.RegisterSaved("ahDuration", function(old) local d = tonumber(old); return (d == 1 or d == 2 or d == 3) and d or 2 end)
ns.RegisterSaved("auctionReadAt", function(old) return tonumber(old) or 0 end)
-- What you posted here and what of it sold: [itemID] = { posted = items, sold = auctions, name = its name }
local MAX_LEDGER = 2000
ns.RegisterSaved("ahLedger", function(old)
    local out, n = {}, 0
    if type(old) ~= "table" then return out end
    for id, rec in pairs(old) do
        if n >= MAX_LEDGER then break end
        if type(id) == "number" and type(rec) == "table" then
            out[id] = { posted = tonumber(rec.posted) or 0, sold = tonumber(rec.sold) or 0,
                        name = type(rec.name) == "string" and rec.name or nil, t = tonumber(rec.t) or 0 }
            n = n + 1
        end
    end
    return out
end)

local PANE_W, PANE_H = 320, 360
local ROW, FOOT, MAX_ROWS = 38, 56, 10
local TOP = 70                                          -- where the rows begin (Layout makes it fit the header)
local GREY, GREEN, GOLD = "|cff9aa3b5", "|cff6fe06a", "|cffffd25a"
local DURATIONS = { "12h", "24h", "48h" }
-- the Broker's colours: a goblin's counter, dark green felt under brass
local FELT, BRASS = { 0.035, 0.06, 0.04 }, { 0.86, 0.69, 0.28 }
AP.KEYS = { "PADDUP", "PADDDOWN", "PADDLEFT", "PADDRIGHT", "PAD1", "PAD2", "PAD3", "PAD4", "PADRSHOULDER" }   -- while up
-- The greeting: the game's own goblin NPC greetings (sound kits, each a few short lines the game picks from):
-- GoblinMaleGruffNPCGreetings, then GoblinMaleZanyNPCGreetings for a client without the first
AP.VOICE = { 5958, 5964 }
AP.GREET_AGAIN = 60                                -- seconds before it greets you again
local view, pane

---------------------------------------------------------------------------
-- What you carry that the auction house takes: one entry per item, with every stack of it. What is worth
-- selling here comes first (the most gained over a vendor for each one first), then what has a price, then the
-- rest. The order goes by each one, never by how many you carry, so posting some of an item leaves it in its
-- place. What you keep is left out unless you asked for it: the second result is how many were left out.
---------------------------------------------------------------------------
local KEPT = { keep = true, equip = true, skill = true, craft = true, quest = true }

function AP.Sellable(showKept)
    if showKept == nil then showKept = ns.db.ahShowKept end
    local byId, list = {}, {}
    for bag = 0, (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) do
        local ok, slots = pcall(C_Container.GetContainerNumSlots, bag)
        for slot = 1, (ok and slots) or 0 do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local id = info and info.itemID
            if id and not ns.IsSecret(id) and not info.isBound and not info.isLocked then
                local n = info.stackCount
                if ns.IsSecret(n) or type(n) ~= "number" then n = 1 end
                local e = byId[id]
                if not e then
                    e = { id = id, count = 0, bag = bag, slot = slot, stack = n, link = info.hyperlink,
                          icon = info.iconFileID, stacks = {} }
                    byId[id] = e
                    list[#list + 1] = e
                end
                e.count = e.count + n
                e.stacks[#e.stacks + 1] = { bag = bag, slot = slot, n = n }
                if n > e.stack then e.bag, e.slot, e.stack = bag, slot, n end      -- the one put in the house's slot
            end
        end
    end
    local M = ns.Market
    local shown, hidden = {}, 0
    for _, e in ipairs(list) do
        e.price, e.why = M.Suggest(e.id)
        e.value = (e.price or 0) * e.count
        e.trend = M.Trend(e.id)
        local verdict, more, want = M.Verdict(e.id)
        e.verdict, e.more, e.want = verdict, more, want
        e.worth = verdict == "auction" and e.price ~= nil
        e.each = e.worth and (more or 0) or 0                 -- gained over a vendor, for each one
        e.gain = e.each * e.count                             -- and for all you carry
        e.kept = KEPT[verdict] or false
        if showKept or not e.kept then shown[#shown + 1] = e else hidden = hidden + 1 end
    end
    table.sort(shown, function(a, b)
        if a.worth ~= b.worth then return a.worth end
        if a.each ~= b.each then return a.each > b.each end
        if (a.price ~= nil) ~= (b.price ~= nil) then return a.price ~= nil end
        if (a.price or 0) ~= (b.price or 0) then return (a.price or 0) > (b.price or 0) end
        return a.id < b.id
    end)
    return shown, hidden
end

-- The most one auction of it may hold (its stack size), or nil
local function MaxStack(id)
    local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if not get then return nil end
    local ok, _, _, _, _, _, _, _, stack = pcall(get, id)
    if not ok or ns.IsSecret(stack) or type(stack) ~= "number" or stack < 1 then return nil end
    return stack
end

-- How the older auction house posts all of it in one press: auctions of `size`, `stacks` of them. An even
-- split when one exists of at least a quarter stack (25 of a 20-stack: 5 auctions of 5); otherwise full
-- stacks now and `rest` left for the next press (23 of a 20-stack: one of 20, then 3), rather than 23
-- auctions of one.
function AP.Plan(e)
    local max = MaxStack(e.id) or e.stack or 1
    local count = e.count or 1
    if count <= max then return count, 1, 0 end
    for size = max, 1, -1 do
        if count % size == 0 then
            if size * 4 >= max then return size, count / size, 0 end
            break
        end
    end
    local stacks = math.floor(count / max)
    return max, stacks, count - max * stacks
end

-- What one press posts of it: how many, and how many are left for another press
local function Newer() return C_AuctionHouse and C_AuctionHouse.PostCommodity and ItemLocation
                              and ItemLocation.CreateFromBagAndSlot end
function AP.WillPost(e)
    if Newer() then return e.count, 0 end
    local size, stacks, rest = AP.Plan(e)
    return size * stacks, rest
end

local function TrendText(t)
    if not t then return GREY .. "-|r" end
    local pct = math.floor(math.abs(t) * 100 + 0.5)
    if pct < 3 then return GREY .. "= " .. pct .. "%|r" end
    if t > 0 then return GREEN .. "^ " .. pct .. "%|r" end                -- above its usual: a good time to sell
    return "|cffff6060v " .. pct .. "%|r"
end
AP.TrendText = TrendText

-- One line on why (or why not) to sell it here
function AP.Reason(e)
    if e.worth then
        return GREEN .. L["+%s over a vendor"]:format(ns.MoneyColored(e.more or 0)) .. "|r" .. GREY .. "  " .. (e.why or "") .. "|r"
    end
    if not e.price then return GREY .. L["no price known yet"] .. "|r" end
    if e.verdict == "keep" then return GREY .. ns.Market.WORDS.keep .. "|r" end
    if e.verdict == "equip" then return GREY .. ns.Market.WORDS.equip .. "|r" end
    if e.verdict == "quest" then return GREY .. L["Quest: %s"]:format(ns.Quests.WantText(e.want)) .. "|r" end
    if e.verdict == "skill" then return GREY .. L["Skill-up: %s"]:format(ns.Professions.Words(e.want)) .. "|r" end
    if e.verdict == "craft" then return GREY .. ns.Professions.Words(e.want) .. "|r" end
    return GREY .. L["a vendor pays as much"] .. "|r"
end

local function KeyName(key)
    local text = GetBindingText and GetBindingText(key) or key
    return (type(text) == "string" and text ~= "") and text or key
end

---------------------------------------------------------------------------
-- Building
---------------------------------------------------------------------------
local function HouseFrame() return _G.AuctionHouseFrame or _G.AuctionFrame end

local function Button(parent, text, w, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, 22)
    b:SetText(text)
    b:SetScript("OnClick", ns.Protect(onClick))
    return b
end

-- A brass rule along the top and the bottom, and a fainter one below the top (a counter's edge)
local function Edge(frame)
    for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT", 0, 0.85 }, { "BOTTOMLEFT", "BOTTOMRIGHT", 0, 0.85 },
                            { "TOPLEFT", "TOPRIGHT", -3, 0.3 } }) do
        local t = frame:CreateTexture(nil, "BORDER")
        t:SetPoint(side[1], frame, side[1], 0, side[3])
        t:SetPoint(side[2], frame, side[2], 0, side[3])
        t:SetHeight(1)
        t:SetColorTexture(BRASS[1], BRASS[2], BRASS[3], side[4])
    end
end

-- A line of text's height, from its font (the HUD's text size included), and a text's height when the game
-- can tell it (`lines` lines otherwise)
local function LineH(fs)
    local _, size = fs:GetFont()
    return (tonumber(size) or 10) * 1.25
end
local function TextH(fs, lines)
    local h = fs.GetStringHeight and fs:GetStringHeight()
    if type(h) == "number" and h > 0 then return h end
    return LineH(fs) * (lines or 1)
end
local function Lines(text) return select(2, tostring(text or ""):gsub("\n", "\n")) + 1 end
local function OneLine(fs) if fs.SetWordWrap then fs:SetWordWrap(false) end end

-- The header's lines as wide as the Market (cut short rather than running out of it), and the rows under
-- them, wherever the HUD's text size puts their last line
local function Layout(width)
    local w = math.max(200, (width or 720) - 64 - 14)
    view.status:SetWidth(w - 60)                             -- (the page number sits at its right)
    view.order:SetWidth(w)
    view.keptNote:SetWidth(w)
    TOP = math.max(60, math.floor(10 + LineH(view.title) + 3 + LineH(view.status) + 2 + LineH(view.order) + 2
        + LineH(view.keptNote) + 6 + 0.5))
    for i, r in ipairs(AP.rows) do
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", view, "TOPLEFT", 10, -TOP - (i - 1) * ROW)
        r:SetPoint("TOPRIGHT", view, "TOPRIGHT", -10, -TOP - (i - 1) * ROW)
    end
end

local function Felt(frame, alpha)
    frame.back = frame:CreateTexture(nil, "BACKGROUND")
    frame.back:SetAllPoints(frame)
    frame.back:SetColorTexture(FELT[1], FELT[2], FELT[3], alpha)
    Edge(frame)
end

-- The Broker's portrait: the auctioneer you are talking to, drawn by the game (round, in a brass ring); the
-- auctioneer's own map icon away from one
local PORTRAIT_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local AUCTIONEER_ICON = "Interface\\Minimap\\Tracking\\Auctioneer"
local function BuildPortrait(parent)
    local ring = parent:CreateTexture(nil, "BORDER")
    ring:SetSize(46, 46)
    ring:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -7)
    ring:SetTexture(PORTRAIT_MASK)
    ring:SetVertexColor(BRASS[1], BRASS[2], BRASS[3], 0.95)
    local p = parent:CreateTexture(nil, "ARTWORK")
    p:SetSize(42, 42)
    p:SetPoint("CENTER", ring, "CENTER", 0, 0)
    if parent.CreateMaskTexture then
        local ok, mask = pcall(parent.CreateMaskTexture, parent)
        if ok and type(mask) == "table" and mask ~= parent and mask.SetTexture then
            mask:SetTexture(PORTRAIT_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            mask:SetAllPoints(p)
            pcall(p.AddMaskTexture, p, mask)
        end
    end
    p.ring = ring
    return p
end

function AP.Portrait()
    local p = view and view.portrait
    if not p then return nil end
    if SetPortraitTexture and UnitExists and UnitExists("npc") and pcall(SetPortraitTexture, p, "npc") then
        p:SetTexCoord(0, 1, 0, 1)
        p.from = "npc"
    else
        p:SetTexture(AUCTIONEER_ICON)
        p:SetTexCoord(0, 1, 0, 1)
        p.from = "icon"
    end
    return p.from
end

-- The list, inside the auction house
local function BuildView()
    view = CreateFrame("Frame", "ControllerCamHUD_MarketView", UIParent)
    view:SetFrameStrata("DIALOG")
    view:EnableMouse(true)
    Felt(view, 1)
    view.portrait = BuildPortrait(view)
    view.title = ns.FontString(view, 14, "LEFT")
    view.title:SetPoint("TOPLEFT", view, "TOPLEFT", 64, -10)
    view.title:SetText(L["The Broker"])
    view.title:SetTextColor(1, 0.82, 0.32)
    view.motto = ns.FontString(view, 9, "LEFT")
    view.motto:SetPoint("LEFT", view.title, "RIGHT", 8, -1)
    view.motto:SetTextColor(BRASS[1], BRASS[2], BRASS[3])
    view.motto:SetText(L["Market"] .. "  -  " .. L["every coin counted, friend"])
    view.status = ns.FontString(view, 9, "LEFT")
    view.status:SetPoint("TOPLEFT", view.title, "BOTTOMLEFT", 0, -3)
    view.status:SetTextColor(unpack(C.muted))
    OneLine(view.status)
    view.order = ns.FontString(view, 8, "LEFT")              -- what the order is, said once under the status
    view.order:SetPoint("TOPLEFT", view.status, "BOTTOMLEFT", 0, -2)
    view.order:SetTextColor(BRASS[1], BRASS[2], BRASS[3])
    OneLine(view.order)
    view.keptNote = ns.FontString(view, 8, "LEFT")           -- what is left out of the list, on a line of its own
    view.keptNote:SetPoint("TOPLEFT", view.order, "BOTTOMLEFT", 0, -2)
    view.keptNote:SetTextColor(unpack(C.muted))
    OneLine(view.keptNote)
    view.pageText = ns.FontString(view, 9, "RIGHT")
    view.pageText:SetPoint("TOPRIGHT", view, "TOPRIGHT", -14, -14)
    view.pageText:SetTextColor(unpack(C.muted))

    for i = 1, MAX_ROWS do
        local r = CreateFrame("Button", nil, view)
        r:SetHeight(ROW - 2)
        r.hl = r:CreateTexture(nil, "BACKGROUND")
        r.hl:SetAllPoints(r)
        r.hl:SetColorTexture(BRASS[1], BRASS[2], BRASS[3], 0.14)
        r.hl:Hide()
        r.mark = r:CreateTexture(nil, "ARTWORK")                -- worth selling here: a green bar down its left
        r.mark:SetPoint("TOPLEFT", r, "TOPLEFT", 0, 0)
        r.mark:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 0, 0)
        r.mark:SetWidth(3)
        r.mark:SetColorTexture(0.44, 0.88, 0.42, 0.95)
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(28, 28)
        r.icon:SetPoint("LEFT", r, "LEFT", 8, 0)
        r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        r.name = ns.FontString(r, 10, "LEFT")
        r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 8, 0)
        r.why = ns.FontString(r, 8, "LEFT")
        r.why:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 8, 0)
        r.why:SetPoint("RIGHT", r, "RIGHT", -150, 0)
        if r.why.SetWordWrap then r.why:SetWordWrap(false) end
        r.price = ns.FontString(r, 10, "RIGHT")
        r.price:SetPoint("TOPRIGHT", r, "TOPRIGHT", -8, -3)
        r.trend = ns.FontString(r, 8, "RIGHT")
        r.trend:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", -8, 3)
        -- point at a row to choose it (the pane follows); press it to post it
        r:SetScript("OnEnter", ns.Protect(function(self) if self.at then AP:Choose(self.at) end end))
        r:SetScript("OnClick", ns.Protect(function(self)
            if not self.at then return end
            if AP.index ~= self.at then AP:Choose(self.at) else AP:Post() end
        end))
        AP.rows[i] = r
    end

    view.post = Button(view, L["Post"], 250, function() AP:Post() end)
    view.post:SetPoint("BOTTOMLEFT", view, "BOTTOMLEFT", 12, 26)
    view.strategy = Button(view, L["Patient"], 110, function() AP:Strategy() end)
    view.strategy:SetPoint("LEFT", view.post, "RIGHT", 6, 0)
    view.duration = Button(view, "24h", 56, function() AP:Duration() end)
    view.duration:SetPoint("LEFT", view.strategy, "RIGHT", 6, 0)
    view.scan = Button(view, L["Read all prices"], 130, function() ns.Market:Scan() end)
    view.scan:SetPoint("LEFT", view.duration, "RIGHT", 6, 0)
    view.kept = Button(view, L["Show kept"], 110, function() AP:ShowKept() end)
    view.kept:SetPoint("LEFT", view.scan, "RIGHT", 6, 0)
    view.hint = ns.FontString(view, 9, "LEFT")
    view.hint:SetPoint("BOTTOMLEFT", view, "BOTTOMLEFT", 14, 8)
    view.hint:SetTextColor(unpack(C.muted))
    view.empty = ns.FontString(view, 10, "CENTER")
    view.empty:SetPoint("CENTER", view, "CENTER", 0, 10)
    view.empty:SetTextColor(unpack(C.muted))
    view.empty:SetText(L["Nothing in your bags can be sold here."])
    view.empty:Hide()

    -- the controller: its buttons are bound to the Market while it is up (ns.PadKeys); the rest stay the game's
    AP.keys = ns.PadKeys("Market", AP.KEYS, function(key) AP:Pad(key) end, function() AP:HideView() end)
    view:SetScript("OnHide", ns.Protect(function() AP.keys:Set(false) end))
    view:Hide()
    AP.view = view
end

-- The pane beside the house: the chosen item's prices. It only shows; nothing in it takes a press.
local function BuildPane()
    pane = CreateFrame("Frame", "ControllerCamHUD_MarketPane", UIParent)
    pane:SetSize(PANE_W, PANE_H)
    pane:SetFrameStrata("DIALOG")
    pane:EnableMouse(false)
    Felt(pane, 1)
    pane.icon = pane:CreateTexture(nil, "ARTWORK")
    pane.icon:SetSize(30, 30)
    pane.icon:SetPoint("TOPLEFT", pane, "TOPLEFT", 12, -12)
    pane.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    pane.title = ns.FontString(pane, 12, "LEFT")
    pane.title:SetPoint("TOPLEFT", pane.icon, "TOPRIGHT", 8, -1)
    pane.title:SetWidth(PANE_W - 62)
    if pane.title.SetWordWrap then pane.title:SetWordWrap(false) end
    pane.best = ns.FontString(pane, 9, "LEFT")               -- under the name, two lines at most
    pane.best:SetPoint("TOPLEFT", pane.title, "BOTTOMLEFT", 0, -2)
    pane.best:SetWidth(PANE_W - 62)
    pane.best:SetJustifyH("LEFT")
    local cw, ch = PANE_W - 24, 96
    pane.chart = CreateFrame("Frame", nil, pane)
    pane.chart:SetSize(cw, ch)
    pane.chart.back = pane.chart:CreateTexture(nil, "BACKGROUND")
    pane.chart.back:SetAllPoints(pane.chart)
    pane.chart.back:SetColorTexture(1, 1, 1, 0.03)
    pane.chart.height = ch - 4
    pane.chart.bars = {}
    for i = 1, 30 do
        local b = pane.chart:CreateTexture(nil, "ARTWORK")
        b:SetWidth(cw / 30 - 2)
        b:SetPoint("BOTTOMLEFT", pane.chart, "BOTTOMLEFT", (i - 1) * (cw / 30) + 1, 0)
        b:Hide()
        pane.chart.bars[i] = b
    end
    pane.chart.usual = pane.chart:CreateTexture(nil, "OVERLAY")
    pane.chart.usual:SetHeight(1)
    pane.chart.usual:SetColorTexture(0.55, 0.85, 1, 0.8)
    pane.chart.usual:Hide()
    pane.chart.empty = ns.FontString(pane.chart, 8, "CENTER")
    pane.chart.empty:SetPoint("TOP", pane.chart, "TOP", 0, -4)
    pane.chart.empty:SetWidth(cw - 20)
    pane.chart.empty:SetTextColor(unpack(C.muted))
    pane.facts = ns.FontString(pane, 9, "LEFT")
    pane.facts:SetPoint("TOPLEFT", pane.chart, "BOTTOMLEFT", 0, -8)
    pane.facts:SetWidth(cw)
    pane.facts:SetJustifyH("LEFT")
    pane.why = ns.FontString(pane, 9, "LEFT")
    pane.why:SetPoint("TOPLEFT", pane.facts, "BOTTOMLEFT", 0, -8)
    pane.why:SetWidth(cw)
    pane.why:SetJustifyH("LEFT")
    pane.why:SetTextColor(unpack(C.text))
    pane:Hide()
    AP.panel = pane
end

-- Our tab on the house, after its own
local function LastTab(house)
    local tabs = rawget(house, "Tabs")
    if type(tabs) == "table" and type(tabs[#tabs]) == "table" then return tabs[#tabs] end
    local name, last = house.GetName and house:GetName() or nil, nil
    for i = 1, 10 do
        local t = name and _G[name .. "Tab" .. i]
        if type(t) == "table" and t.IsShown and t:IsShown() then last = t end
    end
    return last
end

local function BuildTab(house)
    local tab = CreateFrame("Button", "ControllerCamHUD_MarketTab", house)
    tab:SetSize(96, 28)
    tab.back = tab:CreateTexture(nil, "BACKGROUND")
    tab.back:SetAllPoints(tab)
    tab.back:SetColorTexture(FELT[1], FELT[2], FELT[3], 0.94)
    tab.edge = tab:CreateTexture(nil, "BORDER")
    tab.edge:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 0, 0)
    tab.edge:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", 0, 0)
    tab.edge:SetHeight(2)
    tab.label = ns.FontString(tab, 10, "CENTER")
    tab.label:SetPoint("CENTER", tab, "CENTER", 0, 0)
    tab:SetScript("OnClick", ns.Protect(function() AP:Toggle() end))
    local last = LastTab(house)
    if last then
        tab:SetPoint("LEFT", last, "RIGHT", 6, 0)
        -- the house's own tabs put the house back in front
        local name = house.GetName and house:GetName()
        local seen = {}
        for _, t in ipairs(type(rawget(house, "Tabs")) == "table" and house.Tabs or {}) do seen[#seen + 1] = t end
        for i = 1, 10 do seen[#seen + 1] = name and _G[name .. "Tab" .. i] or nil end
        for _, t in ipairs(seen) do
            if type(t) == "table" and t.HookScript then pcall(t.HookScript, t, "OnClick", ns.Protect(function() AP:HideView() end)) end
        end
    else
        tab:SetPoint("TOPLEFT", house, "BOTTOMLEFT", 16, 0)
    end
    AP.tab, AP.tabHouse = tab, house
    return tab
end

local function TabLook()
    local tab = AP.tab
    if not tab then return end
    local on = view and view:IsShown()
    tab.label:SetText(L["Market"])
    if on then
        tab.label:SetTextColor(1, 0.86, 0.4)
        tab.edge:SetColorTexture(1, 0.82, 0.3, 0.95)
    else
        tab.label:SetTextColor(unpack(C.text))
        tab.edge:SetColorTexture(BRASS[1], BRASS[2], BRASS[3], 0.45)
    end
end

---------------------------------------------------------------------------
-- Showing
---------------------------------------------------------------------------
-- The price over the last 30 days as a line: the day's lowest price, joined day to day, today's point in gold,
-- the usual price as a pale level line across. With one day of prices so far it is a point, and it says so.
local function LinePiece(chart, i)
    chart.lines = chart.lines or {}
    local l = chart.lines[i]
    if l == nil then
        local ok, x = pcall(chart.CreateLine, chart, nil, "ARTWORK")
        l = (ok and type(x) == "table" and x ~= chart and x.SetStartPoint) and x or false
        if l then
            l:SetThickness(2)
            l:SetColorTexture(0.55, 0.9, 0.6, 0.9)
        end
        chart.lines[i] = l
    end
    return l or nil
end

local function Dot(chart, i)
    chart.dots = chart.dots or {}
    local d = chart.dots[i]
    if not d then
        d = chart:CreateTexture(nil, "OVERLAY")
        d:SetTexture(ns.media.soft)
        d:SetSize(7, 7)
        chart.dots[i] = d
    end
    return d
end

local function Chart(id)
    local chart = pane.chart
    local h = ns.Market.History(id)
    local today = ns.Market.Today()
    local top = 0
    for _, e in ipairs(h) do if e.p > top then top = e.p end end
    for i = 1, 30 do chart.bars[i]:Hide() end
    for _, l in pairs(chart.lines or {}) do if l then l:Hide() end end
    for _, d in pairs(chart.dots or {}) do d:Hide() end
    chart.usual:Hide()
    if top == 0 then chart.empty:SetText(L["No price history yet: read the auction house on a few days."]); chart.empty:Show(); return end
    chart.empty:Hide()
    local usual = ns.Market.Usual(id, 7)
    if LinePiece(chart, 1) then                               -- a line, where this game draws lines
        local w = chart:GetWidth() or 300
        local span = math.max(top, usual or 0) * 1.15
        local points = {}
        for _, e in ipairs(h) do
            local back = today - e.d
            if back >= 0 and back < 30 then
                points[#points + 1] = { x = w * (29 - back) / 29, y = chart.height * e.p / span, today = back == 0,
                                        low = usual and e.p < usual }
            end
        end
        table.sort(points, function(a, b) return a.x < b.x end)
        for i, p in ipairs(points) do
            local d = Dot(chart, i)
            d:ClearAllPoints()
            d:SetPoint("CENTER", chart, "BOTTOMLEFT", p.x, p.y)
            if p.today then d:SetVertexColor(1, 0.85, 0.3, 1) elseif p.low then d:SetVertexColor(0.55, 0.62, 0.75, 1)
            else d:SetVertexColor(0.55, 0.9, 0.6, 1) end
            d:Show()
            if i > 1 then
                local l = LinePiece(chart, i - 1)
                if l then
                    local q = points[i - 1]
                    l:SetStartPoint("BOTTOMLEFT", chart, q.x, q.y)
                    l:SetEndPoint("BOTTOMLEFT", chart, p.x, p.y)
                    l:Show()
                end
            end
        end
        if #points == 1 then
            chart.empty:SetText(L["One day of prices so far: the line grows each day you visit the auction house."])
            chart.empty:Show()
        end
        if usual then
            chart.usual:ClearAllPoints()
            chart.usual:SetPoint("BOTTOMLEFT", chart, "BOTTOMLEFT", 0, chart.height * usual / span)
            chart.usual:SetPoint("BOTTOMRIGHT", chart, "BOTTOMRIGHT", 0, chart.height * usual / span)
            chart.usual:Show()
        end
        return
    end
    for _, e in ipairs(h) do
        local slot = 30 - (today - e.d)
        if slot >= 1 and slot <= 30 then
            local b = chart.bars[slot]
            b:SetHeight(math.max(2, chart.height * e.p / top))
            local below = usual and e.p < usual
            if e.d == today then b:SetColorTexture(1, 0.85, 0.3, 0.95)             -- today
            elseif below then b:SetColorTexture(0.55, 0.62, 0.75, 0.55)
            else b:SetColorTexture(0.42, 0.85, 0.45, 0.7) end
            b:Show()
        end
    end
    if usual then
        chart.usual:ClearAllPoints()
        chart.usual:SetPoint("BOTTOMLEFT", chart, "BOTTOMLEFT", 0, chart.height * usual / top)
        chart.usual:SetPoint("BOTTOMRIGHT", chart, "BOTTOMRIGHT", 0, chart.height * usual / top)
        chart.usual:Show()
    end
end

local function ItemName(e)
    local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local ok, name, _, quality = pcall(get, e.id)
    return (ok and name) or ("item " .. e.id), ok and quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality] or nil
end

local function Icon(e)
    return e.icon or (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(e.id)) or 134400
end

-- The lowest and highest of the days' lowest prices in the last `days` days (today among them), or nil
function AP.Range(id, days)
    local today, lo, hi = ns.Market.Today(), nil, nil
    for _, d in ipairs(ns.Market.History(id)) do
        if d.d > today - (days or 7) and d.d <= today then
            if not lo or d.p < lo then lo = d.p end
            if not hi or d.p > hi then hi = d.p end
        end
    end
    return lo, hi
end

-- The chosen item's numbers, a line each: what we ask (each and for all you carry), the lowest up now and how
-- long ago it was read, the usual price and the week's low and high, how many are up, what a vendor pays,
-- and what you posted of it here and how much of that sold
function AP.Facts(e)
    local M, money, dash = ns.Market, ns.MoneyColored, GREY .. "-|r"
    local lines = {}
    if e.price then
        lines[#lines + 1] = L["Asking %s each, %s for all %d"]:format(money(e.price), money(e.price * e.count), e.count)
    end
    local low, at = M.Auction(e.id)
    lines[#lines + 1] = L["Lowest"] .. " " .. (low and money(low) or dash) .. "   " .. TrendText(e.trend)
        .. (at and (GREY .. "   " .. L["read %s"]:format(M.Ago(at)) .. "|r") or "")
    local usual = M.Usual(e.id, 7)
    local lo, hi = AP.Range(e.id, 7)
    lines[#lines + 1] = L["Usual"] .. " " .. (usual and money(usual) or dash)
        .. (lo and (GREY .. "   " .. L["7 days: %s to %s"]:format(money(lo) .. GREY, money(hi) .. GREY) .. "|r") or "")
    local listings, quantity = M.Supply(e.id)
    if listings then lines[#lines + 1] = L["Up: %d auctions, %d items"]:format(listings, quantity or listings) end
    local vendor = M.Vendor(e.id)
    lines[#lines + 1] = L["Vendor"] .. " " .. (vendor and L["%s each, %s for all %d"]:format(money(vendor),
        money(vendor * e.count), e.count) or dash)
    local rec = ns.db.ahLedger and ns.db.ahLedger[e.id]
    if rec and (rec.posted or 0) > 0 then
        lines[#lines + 1] = GOLD .. L["You posted %d here, %d auctions sold"]:format(rec.posted, rec.sold or 0) .. "|r"
    end
    return lines
end

-- The pane: the chosen item's chart and numbers, and the reasoning in full
local function ShowPane(e)
    if not pane then BuildPane() end
    if not (e and view and view:IsShown()) then pane:Hide(); return end
    local M = ns.Market
    pane:ClearAllPoints()
    pane:SetPoint("TOPLEFT", view, "TOPRIGHT", 6, 0)
    local name, q = ItemName(e)
    pane.icon:SetTexture(Icon(e))
    pane.title:SetText(name)
    if q then pane.title:SetTextColor(q.r, q.g, q.b) else pane.title:SetTextColor(unpack(C.text)) end
    -- the gain over a vendor is said once, for each one (as the list is ordered)
    local best = e.verdict and (L["Best"] .. ": " .. M.BestText(e.verdict, e.more, e.want)) or ""
    pane.best:SetText(best)
    local head = 12 + math.max(30, TextH(pane.title) + 2 + TextH(pane.best, 1))
    pane.chart:ClearAllPoints()
    pane.chart:SetPoint("TOPLEFT", pane, "TOPLEFT", 12, -(head + 8))
    Chart(e.id)
    local facts = AP.Facts(e)
    pane.facts:SetText(table.concat(facts, "\n"))
    local why = e.why or L["No price known: read the auction house first."]
    if e.verdict == "skill" then                                     -- the recipes it still gives a point for
        local recipes = ns.Professions.Recipes(e.want, e.id)
        if #recipes > 0 then
            local list = {}
            for i, r in ipairs(recipes) do list[i] = ns.Professions.RecipeText(r) end
            why = L["Recipes"] .. ":\n" .. table.concat(list, "\n")
        end
        if e.want and e.want.via then                                -- the point is in what it is made into
            why = L["made into %s"]:format(ns.Professions.ItemName(e.want.via)) .. "\n" .. why
        end
    end
    pane.why:SetText(why)
    pane:SetHeight(math.floor(head + 8 + pane.chart:GetHeight() + 8 + TextH(pane.facts, #facts) + 8
        + TextH(pane.why, Lines(why)) + 14 + 0.5))
    pane:Show()
end

function AP:Refresh()
    if not view or not view:IsShown() then return end
    local M = ns.Market
    local list, hidden = AP.Sellable()
    AP.list, AP.hidden = list, hidden
    -- keep the item you had chosen under the cursor when the list changes around it
    if AP.selected then
        for i, e in ipairs(list) do if e.id == AP.selected then AP.index = i end end
    end
    AP.index = math.max(1, math.min(AP.index, math.max(1, #list)))
    local chosen = list[AP.index]
    AP.chosen, AP.selected = chosen, chosen and chosen.id or nil
    local per = AP.perPage
    local pages = math.max(1, math.ceil(#list / per))
    AP.page = math.ceil(AP.index / per)
    local worth, seen = 0, 0
    for _, e in ipairs(list) do if e.worth then worth = worth + 1 end end
    for _ in pairs(ns.db.auction or {}) do seen = seen + 1 end
    local read = ns.db.auctionReadAt or 0
    view.status:SetText(L["%d worth selling here, %d more you could"]:format(worth, #list - worth) .. "   " .. GREY
        .. L["%d prices known, all read %s"]:format(seen, read > 0 and M.Ago(read) or L["never"]) .. "|r")
    view.order:SetText(L["Best first: the most gained over a vendor for each one"])
    if ns.db.ahShowKept then
        view.keptNote:SetText(L["what you keep is listed too (%s hides it)"]:format(KeyName("PADRSHOULDER")))
    elseif hidden > 0 then
        view.keptNote:SetText(L["%d kept (for your professions, to wear, or marked), not listed (%s shows them)"]:format(
            hidden, KeyName("PADRSHOULDER")))
    else
        view.keptNote:SetText("")
    end
    view.kept:SetText(ns.db.ahShowKept and L["Hide kept"] or L["Show kept"])
    view.pageText:SetText(pages > 1 and ("%d / %d"):format(AP.page, pages) or "")
    for i, r in ipairs(AP.rows) do
        local at = (AP.page - 1) * per + i
        local e = i <= per and list[at] or nil
        r.entry, r.at = e, e and at or nil
        if e then
            local name, q = ItemName(e)
            r.icon:SetTexture(Icon(e))
            r.name:SetText(name .. GREY .. " x" .. e.count .. "|r")
            if q then r.name:SetTextColor(q.r, q.g, q.b) else r.name:SetTextColor(unpack(C.text)) end
            r.why:SetText(AP.Reason(e))
            r.price:SetText(e.price and (ns.MoneyColored(e.price) .. GREY .. " " .. L["each"] .. "|r")
                or (GREY .. L["no data"] .. "|r"))
            r.trend:SetText(TrendText(e.trend))
            if e.worth then r.mark:Show() else r.mark:Hide() end
            r.icon:SetAlpha(e.worth and 1 or 0.6)
            if at == AP.index then r.hl:Show() else r.hl:Hide() end
            r:Show()
        else
            r:Hide()
        end
    end
    local quick = ns.db.ahStrategy
    view.strategy:SetText(quick and L["Quick sale"] or L["Patient"])
    view.duration:SetText(DURATIONS[ns.db.ahDuration or 2])
    view.hint:SetText(("%s %s    %s %s    %s %s    %s %s    %s %s"):format(KeyName("PAD1"), L["Post"], KeyName("PAD3"),
        quick and L["Quick sale"] or L["Patient"], KeyName("PAD4"), DURATIONS[ns.db.ahDuration or 2],
        KeyName("PADRSHOULDER"), ns.db.ahShowKept and L["Hide kept"] or L["Show kept"], KeyName("PAD2"), L["Back"]))
    if not chosen then
        view.empty:Show()
        view.post:SetText(L["Post"])
        view.post:Disable()
        ShowPane(nil)
        return
    end
    view.empty:Hide()
    if chosen.price then
        local n, rest = AP.WillPost(chosen)
        if rest > 0 or n == 1 then                           -- one, or the older house in uneven stacks (the rest next)
            view.post:SetText(L["Post %d for %s"]:format(n, ns.MoneyColored(chosen.price * n)))
        else
            view.post:SetText(L["Post all %d for %s"]:format(n, ns.MoneyColored(chosen.price * n)))
        end
        view.post:Enable()
    else
        view.post:SetText(L["Post"])
        view.post:Disable()
    end
    ShowPane(chosen)
end

---------------------------------------------------------------------------
-- Choosing
---------------------------------------------------------------------------
function AP:Choose(at)
    local n = #(self.list or {})
    if n == 0 then return end
    self.index = math.max(1, math.min(n, at))
    self.selected = self.list[self.index].id
    self:Refresh()
end

function AP:Strategy()
    ns.db.ahStrategy = not ns.db.ahStrategy
    self:Refresh()
end

function AP:Duration()
    ns.db.ahDuration = (ns.db.ahDuration or 2) % 3 + 1
    self:Refresh()
end

-- What you keep: listed too, or left out (the default). The item you had chosen stays chosen when it is still
-- listed; otherwise the cursor stays where it was.
function AP:ShowKept()
    ns.db.ahShowKept = not ns.db.ahShowKept
    self:Refresh()
end

-- A controller button while the Market is up: true when it was ours
function AP:Pad(button)
    if not (view and view:IsShown()) then return false end
    ns.Note("market: button %s", tostring(button))
    if button == "PADDUP" then self:Choose(self.index - 1)
    elseif button == "PADDDOWN" then self:Choose(self.index + 1)
    elseif button == "PADDLEFT" then self:Choose(self.index - self.perPage)
    elseif button == "PADDRIGHT" then self:Choose(self.index + self.perPage)
    elseif button == "PAD1" then self:Post()
    elseif button == "PAD3" then self:Strategy()
    elseif button == "PAD4" then self:Duration()
    elseif button == "PADRSHOULDER" then self:ShowKept()
    elseif button == "PAD2" then self:HideView()
    else return false end
    return true
end

---------------------------------------------------------------------------
-- Posting (your press; the game requires one): every one you carry of the chosen item.
--   newer auction house: a commodity is one post of the whole quantity at a price each (the game gathers it
--   from all your stacks); any other item, one post of the quantity, priced each, the game making an auction
--   of each.
--   older one: one press posts `stacks` auctions of `size` (AP.Plan), the buyout per auction; the item in the
--   sell slot is its biggest stack, the game takes the rest from your bags.
---------------------------------------------------------------------------
local function Ledger(e, n)
    local db = ns.db
    db.ahLedger = db.ahLedger or {}
    local rec = db.ahLedger[e.id]
    if not rec then
        local known = 0
        for _ in pairs(db.ahLedger) do known = known + 1 end
        if known >= MAX_LEDGER then return end
        rec = { posted = 0, sold = 0 }
        db.ahLedger[e.id] = rec
    end
    rec.posted = (rec.posted or 0) + n
    rec.name = ItemName(e)
    rec.t = time and time() or 0
end

function AP:Post()
    local e = self.chosen
    if not (e and e.price) then return false end
    local dur = ns.db.ahDuration or 2
    local AH = C_AuctionHouse
    local ok, err, n
    if Newer() then
        local loc = ItemLocation:CreateFromBagAndSlot(e.bag, e.slot)
        local okS, status = pcall(AH.GetItemCommodityStatus, loc)
        local commodity = okS and Enum and Enum.ItemCommodityStatus and status == Enum.ItemCommodityStatus.Commodity
        n = e.count
        if commodity then
            ok, err = pcall(AH.PostCommodity, loc, dur, n, e.price)
        else
            ok, err = pcall(AH.PostItem, loc, dur, n, nil, e.price)
        end
    elseif PostAuction and ClickAuctionSellItemButton then
        local size, stacks = AP.Plan(e)
        n = size * stacks
        ClearCursor()
        local pickup = (C_Container and C_Container.PickupContainerItem) or PickupContainerItem
        pickup(e.bag, e.slot)
        ClickAuctionSellItemButton()
        ClearCursor()
        local buyout = e.price * size
        ok, err = pcall(PostAuction, math.floor(buyout * 0.9), buyout, dur, size, stacks)
    else
        ns.Say(L["This client's auction house cannot be posted to from here."])
        return false
    end
    if ok then
        ns.Say(L["Posted %d for %s."]:format(n, ns.MoneyColored(e.price * n)))
        self.posted = (self.posted or 0) + 1
        Ledger(e, n)
        C_Timer.After(0.5, function() AP:Refresh() end)
    else
        ns.Error(err)
    end
    return ok
end

-- A sale of yours (the game says so in the chat: "A buyer has been found for your auction of %s."): counted
-- for the item of that name you posted here
local soldPattern
function AP.Sold(msg)
    if type(msg) ~= "string" or ns.IsSecret(msg) or type(ERR_AUCTION_SOLD_S) ~= "string" then return nil end
    if not soldPattern then
        soldPattern = "^" .. ERR_AUCTION_SOLD_S:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1"):gsub("%%s", "(.+)") .. "$"
    end
    local name = msg:match(soldPattern)
    if not name then return nil end
    for id, rec in pairs(ns.db.ahLedger or {}) do
        if rec.name == name then
            rec.sold = (rec.sold or 0) + 1
            return id
        end
    end
    return nil
end

---------------------------------------------------------------------------
-- The Broker's greeting: one short line of the game's own goblin voices when the Market opens (not again
-- within a minute). Nothing is shipped: the sound kits are the game's.
---------------------------------------------------------------------------
function AP:Greet()
    if not ns.db.ahVoice or not PlaySound then return nil end
    local now = (GetTime and GetTime()) or (time and time()) or 0
    if self.greetedAt and now - self.greetedAt < AP.GREET_AGAIN then return nil end
    for _, kit in ipairs(AP.VOICE) do
        local ok, willPlay = pcall(PlaySound, kit, "Dialog")
        if ok and willPlay ~= false then                     -- (a client without that kit says false)
            self.greetedAt = now
            return kit
        end
    end
    return nil
end

---------------------------------------------------------------------------
-- With the auction house
---------------------------------------------------------------------------
-- The Market over the house (or by itself in the middle of the screen, away from one)
function AP:ShowView()
    if not ns.db.ahPanel then return end
    if not view then BuildView() end
    local house = HouseFrame()
    view:ClearAllPoints()
    local height, width
    if house and house.IsShown and house:IsShown() then
        view:SetParent(house)
        view:SetFrameStrata("DIALOG")
        view:SetPoint("TOPLEFT", house, "TOPLEFT", 4, -24)
        view:SetPoint("BOTTOMRIGHT", house, "BOTTOMRIGHT", -4, 4)
        height = (house:GetHeight() or 480) - 28
        width = (house:GetWidth() or 728) - 8
    else
        view:SetParent(UIParent)
        view:SetSize(720, 480)
        view:SetPoint("CENTER", UIParent, "CENTER", -PANE_W / 2, 0)
        height, width = 480, 720
    end
    Layout(width)
    self.perPage = math.max(3, math.min(MAX_ROWS, math.floor((height - TOP - FOOT) / ROW)))
    local opening = not view:IsShown()
    view:Show()
    self.keys:Set(true)
    TabLook()
    AP.Portrait()
    if opening then self:Greet() end
    self:Refresh()
    ns.Note("market: shown, %d rows a page, %d items", self.perPage, #(self.list or {}))
end

function AP:HideView()
    if view then view:Hide() end
    if self.keys then self.keys:Set(false) end
    if pane then pane:Hide() end
    TabLook()
end

function AP:Toggle()
    if view and view:IsShown() then self:HideView() else self:ShowView() end
end

-- The house opened: our tab on it (point at it and press, or bind "Market" to a key of your own)
function AP:Open()
    if not ns.db.ahPanel then return end
    local house = HouseFrame()
    if house and house.CreateTexture and self.tabHouse ~= house then pcall(BuildTab, house) end
    if self.tab then self.tab:Show() end
    TabLook()
end

function AP:Close()
    self:HideView()
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", ns.Protect(function(_, event, arg)
    if event == "AUCTION_HOUSE_SHOW" then AP:Open()
    elseif event == "AUCTION_HOUSE_CLOSED" then AP:Close()
    elseif event == "BAG_UPDATE_DELAYED" then AP:Refresh()
    elseif event == "CHAT_MSG_SYSTEM" then AP.Sold(arg) end
end))

function AP:Apply(run)
    if run and ns.db.ahPanel and not self.active then
        self.active = true
        for _, e in ipairs({ "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "BAG_UPDATE_DELAYED", "CHAT_MSG_SYSTEM" }) do
            pcall(events.RegisterEvent, events, e)
        end
        local house = HouseFrame()
        if house and house.IsShown and house:IsShown() then self:Open() end
    elseif not (run and ns.db.ahPanel) and self.active then
        self.active = false
        events:UnregisterAllEvents()
        self:Close()
        if self.tab then self.tab:Hide() end
    end
end

-- What we found of the auction house (for /cchud ahinfo and the debug reports)
function AP.Describe()
    local AH = C_AuctionHouse
    local house = HouseFrame()
    local rows = {}
    rows[#rows + 1] = ("newer auction house: %s, older: %s"):format(tostring(AH and AH.PostCommodity ~= nil),
        tostring(PostAuction ~= nil))
    if not house then
        rows[#rows + 1] = "frame: not loaded"
        return rows
    end
    local name = house.GetName and house:GetName() or "?"
    local w, h = 0, 0
    if house.GetSize then w, h = house:GetSize() end
    rows[#rows + 1] = ("frame %s, shown %s, size %sx%s, strata %s"):format(tostring(name),
        tostring(house.IsShown and house:IsShown() and true or false), tostring(w), tostring(h),
        tostring(house.GetFrameStrata and house:GetFrameStrata()))
    local tabs = {}
    for _, t in ipairs(type(rawget(house, "Tabs")) == "table" and house.Tabs or {}) do
        tabs[#tabs + 1] = tostring(type(t) == "table" and t.GetName and t:GetName() or "?")
    end
    for i = 1, 10 do
        if _G[tostring(name) .. "Tab" .. i] then tabs[#tabs + 1] = tostring(name) .. "Tab" .. i end
    end
    rows[#rows + 1] = "its tabs: " .. (#tabs > 0 and table.concat(tabs, " ") or "none found")
    rows[#rows + 1] = ("our tab: %s, its buttons bound: %s, view shown: %s, rows per page: %s"):format(tostring(AP.tab ~= nil),
        tostring(AP.keys and AP.keys.on or false), tostring(view ~= nil and view:IsShown() and true or false), tostring(AP.perPage))
    rows[#rows + 1] = ("portrait: %s, greeting: %s (kits %s), kept left out: %s"):format(
        tostring(view and view.portrait and view.portrait.from or "none"), tostring(ns.db.ahVoice),
        table.concat(AP.VOICE, " "), tostring(AP.hidden or 0))
    return rows
end

function ControllerCamHUD_Market() ns.Protect(function() AP:Toggle() end)() end
BINDING_NAME_CCHUD_MARKET = L["Market at the auction house: open / close"]
ns.RegisterCommand("market", function() AP:Toggle() end, "/cchud market",
    "open or close the Market (a tab of the auction house)")
ns.RegisterCommand("ahinfo", function()
    for _, row in ipairs(AP.Describe()) do print("  " .. row) end
end, "/cchud ahinfo", "which auction house this client has (for troubleshooting)")

ns.RegisterModule("auctionpanel", AP)
