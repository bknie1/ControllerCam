-- ControllerCam HUD: the Market, a tab of the auction house.
-- The auction house gets one more tab, "Market". It answers one question:
-- what in my bags should I sell here, and for how much?
--   * the list: what you carry that the house takes. First what is worth selling here (it brings more than a
--     vendor pays, after the house's cut), each with the price we would ask and why; then the rest.
--   * beside the house, a pane that only shows (nothing in it to press): the chosen item's price chart for the
--     last 30 days, its usual price, how many are up, what a vendor pays, and the reasoning in full.
--   * one press posts the chosen item at the asking price. Patient (the default) or quick sale, and how long
--     (12, 24 or 48 hours).
-- From the controller: up and down choose (the pane follows), A posts, X switches patient and quick, Y how
-- long, B goes back to the house. With a mouse: point at a row to choose it, click it to post.
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
ns.RegisterSaved("ahDuration", function(old) local d = tonumber(old); return (d == 1 or d == 2 or d == 3) and d or 2 end)
ns.RegisterSaved("auctionReadAt", function(old) return tonumber(old) or 0 end)

local PANE_W, PANE_H = 320, 300
local ROW, TOP, FOOT, MAX_ROWS = 38, 46, 56, 10
local GREY, GREEN = "|cff9aa3b5", "|cff6fe06a"
local DURATIONS = { "12h", "24h", "48h" }
AP.KEYS = { "PADDUP", "PADDDOWN", "PADDLEFT", "PADDRIGHT", "PAD1", "PAD2", "PAD3", "PAD4" }   -- while the Market is up
local view, pane

---------------------------------------------------------------------------
-- What you carry that the auction house takes: one entry per item, with a stack to post. What is worth
-- selling here comes first (the most gained over a vendor first), then what has a price, then the rest.
---------------------------------------------------------------------------
function AP.Sellable()
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
                    e = { id = id, count = 0, bag = bag, slot = slot, stack = n, link = info.hyperlink, icon = info.iconFileID }
                    byId[id] = e
                    list[#list + 1] = e
                end
                e.count = e.count + n
                if n > e.stack then e.bag, e.slot, e.stack = bag, slot, n end      -- post the biggest stack
            end
        end
    end
    local M = ns.Market
    for _, e in ipairs(list) do
        e.price, e.why = M.Suggest(e.id)
        e.value = (e.price or 0) * e.count
        e.trend = M.Trend(e.id)
        local verdict, more = M.Verdict(e.id)
        e.verdict, e.more = verdict, more
        e.worth = verdict == "auction" and e.price ~= nil
        e.gain = e.worth and (more or 0) * e.count or 0
    end
    table.sort(list, function(a, b)
        if a.worth ~= b.worth then return a.worth end
        if a.gain ~= b.gain then return a.gain > b.gain end
        if (a.price ~= nil) ~= (b.price ~= nil) then return a.price ~= nil end
        if a.value ~= b.value then return a.value > b.value end
        return a.id < b.id
    end)
    return list
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

local function Edge(frame)
    for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" } }) do
        local t = frame:CreateTexture(nil, "BORDER")
        t:SetPoint(side[1], frame, side[1])
        t:SetPoint(side[2], frame, side[2])
        t:SetHeight(1)
        t:SetColorTexture(0.55, 0.62, 0.75, 0.6)
    end
end

-- The list, inside the auction house
local function BuildView()
    view = CreateFrame("Frame", "ControllerCamHUD_MarketView", UIParent)
    view:SetFrameStrata("DIALOG")
    view:EnableMouse(true)
    view.back = view:CreateTexture(nil, "BACKGROUND")
    view.back:SetAllPoints(view)
    view.back:SetColorTexture(0.03, 0.04, 0.07, 0.97)
    Edge(view)
    view.title = ns.FontString(view, 13, "LEFT")
    view.title:SetPoint("TOPLEFT", view, "TOPLEFT", 14, -10)
    view.title:SetText(L["Market"])
    view.status = ns.FontString(view, 9, "LEFT")
    view.status:SetPoint("TOPLEFT", view.title, "BOTTOMLEFT", 0, -3)
    view.status:SetTextColor(unpack(C.muted))
    view.pageText = ns.FontString(view, 9, "RIGHT")
    view.pageText:SetPoint("TOPRIGHT", view, "TOPRIGHT", -14, -14)
    view.pageText:SetTextColor(unpack(C.muted))

    for i = 1, MAX_ROWS do
        local r = CreateFrame("Button", nil, view)
        r:SetHeight(ROW - 2)
        r:SetPoint("TOPLEFT", view, "TOPLEFT", 10, -TOP - (i - 1) * ROW)
        r:SetPoint("TOPRIGHT", view, "TOPRIGHT", -10, -TOP - (i - 1) * ROW)
        r.hl = r:CreateTexture(nil, "BACKGROUND")
        r.hl:SetAllPoints(r)
        r.hl:SetColorTexture(1, 1, 1, 0.09)
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
    pane.back = pane:CreateTexture(nil, "BACKGROUND")
    pane.back:SetAllPoints(pane)
    pane.back:SetColorTexture(0.03, 0.04, 0.07, 0.94)
    Edge(pane)
    pane.icon = pane:CreateTexture(nil, "ARTWORK")
    pane.icon:SetSize(30, 30)
    pane.icon:SetPoint("TOPLEFT", pane, "TOPLEFT", 12, -12)
    pane.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    pane.title = ns.FontString(pane, 12, "LEFT")
    pane.title:SetPoint("TOPLEFT", pane.icon, "TOPRIGHT", 8, -1)
    pane.title:SetWidth(PANE_W - 62)
    if pane.title.SetWordWrap then pane.title:SetWordWrap(false) end
    pane.best = ns.FontString(pane, 9, "LEFT")
    pane.best:SetPoint("BOTTOMLEFT", pane.icon, "BOTTOMRIGHT", 8, 1)
    local cw, ch = PANE_W - 24, 96
    pane.chart = CreateFrame("Frame", nil, pane)
    pane.chart:SetSize(cw, ch)
    pane.chart:SetPoint("TOPLEFT", pane, "TOPLEFT", 12, -56)
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
    pane.chart.empty:SetPoint("CENTER", pane.chart, "CENTER", 0, 0)
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
    tab.back:SetColorTexture(0.03, 0.04, 0.07, 0.94)
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
        tab.edge:SetColorTexture(0.55, 0.62, 0.75, 0.6)
    end
end

---------------------------------------------------------------------------
-- Showing
---------------------------------------------------------------------------
local function Chart(id)
    local chart = pane.chart
    local h = ns.Market.History(id)
    local today = ns.Market.Today()
    local top = 0
    for _, e in ipairs(h) do if e.p > top then top = e.p end end
    for i = 1, 30 do chart.bars[i]:Hide() end
    chart.usual:Hide()
    if top == 0 then chart.empty:SetText(L["No price history yet: read the auction house on a few days."]); chart.empty:Show(); return end
    chart.empty:Hide()
    local usual = ns.Market.Usual(id, 7)
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
    local best = e.verdict and (L["Best"] .. ": " .. M.ICON[e.verdict] .. " " .. M.WORDS[e.verdict]) or ""
    if e.worth then best = best .. "  " .. GREEN .. "+|r" .. ns.MoneyColored(e.gain) end
    pane.best:SetText(best)
    Chart(e.id)
    local low, usual = M.Auction(e.id), M.Usual(e.id, 7)
    local listings, vendor = M.Supply(e.id), M.Vendor(e.id)
    local dash = GREY .. "-|r"
    pane.facts:SetText(table.concat({
        L["Lowest"] .. " " .. (low and ns.MoneyColored(low) or dash) .. "   " .. TrendText(e.trend),
        L["Usual"] .. " " .. (usual and ns.MoneyColored(usual) or dash)
            .. "   " .. L["Up"] .. " " .. (listings and tostring(listings) or "-"),
        L["Vendor"] .. " " .. (vendor and ns.MoneyColored(vendor) or dash),
    }, "\n"))
    pane.why:SetText(e.why or L["No price known: read the auction house first."])
    pane:Show()
end

function AP:Refresh()
    if not view or not view:IsShown() then return end
    local M = ns.Market
    local list = AP.Sellable()
    AP.list = list
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
            r.price:SetText(e.price and ns.MoneyColored(e.price) or (GREY .. L["no data"] .. "|r"))
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
    view.hint:SetText(("%s %s    %s %s    %s %s    %s %s"):format(KeyName("PAD1"), L["Post"], KeyName("PAD3"),
        quick and L["Quick sale"] or L["Patient"], KeyName("PAD4"), DURATIONS[ns.db.ahDuration or 2],
        KeyName("PAD2"), L["Back"]))
    if not chosen then
        view.empty:Show()
        view.post:SetText(L["Post"])
        view.post:Disable()
        ShowPane(nil)
        return
    end
    view.empty:Hide()
    if chosen.price then
        view.post:SetText(L["Post %d for %s"]:format(chosen.stack, ns.MoneyColored(chosen.price * chosen.stack)))
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
    elseif button == "PAD2" then self:HideView()
    else return false end
    return true
end

---------------------------------------------------------------------------
-- Posting (your press; the game requires one): the newer auction house, or the older one
---------------------------------------------------------------------------
function AP:Post()
    local e = self.chosen
    if not (e and e.price) then return false end
    local dur = ns.db.ahDuration or 2
    local AH = C_AuctionHouse
    local ok, err
    if AH and AH.PostCommodity and ItemLocation and ItemLocation.CreateFromBagAndSlot then
        local loc = ItemLocation:CreateFromBagAndSlot(e.bag, e.slot)
        local okS, status = pcall(AH.GetItemCommodityStatus, loc)
        local commodity = okS and Enum and Enum.ItemCommodityStatus and status == Enum.ItemCommodityStatus.Commodity
        if commodity then
            ok, err = pcall(AH.PostCommodity, loc, dur, e.stack, e.price)
        else
            ok, err = pcall(AH.PostItem, loc, dur, e.stack, nil, e.price * e.stack)
        end
    elseif PostAuction and ClickAuctionSellItemButton then
        ClearCursor()
        local pickup = (C_Container and C_Container.PickupContainerItem) or PickupContainerItem
        pickup(e.bag, e.slot)
        ClickAuctionSellItemButton()
        ClearCursor()
        local buyout = e.price * e.stack
        ok, err = pcall(PostAuction, math.floor(buyout * 0.9), buyout, dur, e.stack, 1)
    else
        ns.Say(L["This client's auction house cannot be posted to from here."])
        return false
    end
    if ok then
        ns.Say(L["Posted %d for %s."]:format(e.stack, ns.MoneyColored(e.price * e.stack)))
        self.posted = (self.posted or 0) + 1
        C_Timer.After(0.5, function() AP:Refresh() end)
    else
        ns.Error(err)
    end
    return ok
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
    local height
    if house and house.IsShown and house:IsShown() then
        view:SetParent(house)
        view:SetFrameStrata("DIALOG")
        view:SetPoint("TOPLEFT", house, "TOPLEFT", 4, -24)
        view:SetPoint("BOTTOMRIGHT", house, "BOTTOMRIGHT", -4, 4)
        height = (house:GetHeight() or 480) - 28
    else
        view:SetParent(UIParent)
        view:SetSize(720, 480)
        view:SetPoint("CENTER", UIParent, "CENTER", -PANE_W / 2, 0)
        height = 480
    end
    self.perPage = math.max(3, math.min(MAX_ROWS, math.floor((height - TOP - FOOT) / ROW)))
    view:Show()
    self.keys:Set(true)
    TabLook()
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
events:SetScript("OnEvent", ns.Protect(function(_, event)
    if event == "AUCTION_HOUSE_SHOW" then AP:Open()
    elseif event == "AUCTION_HOUSE_CLOSED" then AP:Close()
    elseif event == "BAG_UPDATE_DELAYED" then AP:Refresh() end
end))

function AP:Apply(run)
    if run and ns.db.ahPanel and not self.active then
        self.active = true
        for _, e in ipairs({ "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "BAG_UPDATE_DELAYED" }) do
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
