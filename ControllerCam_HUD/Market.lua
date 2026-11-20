-- ControllerCam HUD: what things are worth.
--   * Vendor: what an item sells for, each and for a full stack, in its tooltip.
--   * Auction house: the lowest buyout per item you have seen while browsing, remembered with when you saw it,
--     in the tooltip too ("Auction: 1g 20s each, 3 days ago"). Nothing is searched for you: only what the
--     auction house shows you is noted.
-- The prices of both go into the item details window as well (ItemInfo.lua).

local ADDON, ns = ...
local L = ns.L

local M = { active = false }
ns.Market = M

ns.RegisterSetting({
    key = "vendorPrice", kind = "boolean", default = true, command = "vendorprice", section = "Bags, bank and vendor",
    label = "Vendor prices in tooltips", tip = "what an item sells for at a vendor, each and for a full stack",
})
ns.RegisterSetting({
    key = "auctionPrice", kind = "boolean", default = true, command = "auctionprice", section = "Bags, bank and vendor",
    label = "Auction prices in tooltips",
    tip = "the lowest buyout you have seen for an item at the auction house, and how long ago",
})

ns.RegisterSetting({
    key = "auctionScan", kind = "boolean", default = true, command = "auctionscan", section = "Bags, bank and vendor",
    label = "Read the auction house when you visit",
    tip = "the first visit in a while reads every price at once (the game allows it every 15 minutes); /cchud scan asks for it",
})
ns.RegisterSetting({
    key = "auctionVerdict", kind = "boolean", default = true, command = "auctionverdict", section = "Bags, bank and vendor",
    label = "Best use of an item", tip = "an item's tooltip says what to do with it: sell it at the auction house (and how much more that brings), sell it to a vendor, or keep it",
})
ns.RegisterSaved("auctionScanAt", function(old) return tonumber(old) or 0 end)

-- [itemID] = { p = lowest buyout each (copper), t = when (time()) }
local MAX = 6000
ns.RegisterSaved("auction", function(old)
    local out, n = {}, 0
    if type(old) ~= "table" then return out end
    for id, rec in pairs(old) do
        if n >= MAX then break end
        if type(id) == "number" and type(rec) == "table" and tonumber(rec.p) and tonumber(rec.t) then
            out[id] = { p = tonumber(rec.p), t = tonumber(rec.t), n = tonumber(rec.n), q = tonumber(rec.q) }
            n = n + 1
        end
    end
    return out
end)

local function Plain(v) if ns.IsSecret(v) then return nil end return v end

-- The lowest price of each day, for the last 30 days: [itemID] = { { d = day number, p = copper }, ... }
local DAYS, MAX_HISTORY = 30, 5000
ns.RegisterSaved("auctionHistory", function(old)
    local out, n = {}, 0
    if type(old) ~= "table" then return out end
    for id, list in pairs(old) do
        if n >= MAX_HISTORY then break end
        if type(id) == "number" and type(list) == "table" then
            local clean = {}
            for _, e in ipairs(list) do
                if type(e) == "table" and tonumber(e.d) and tonumber(e.p) then clean[#clean + 1] = { d = tonumber(e.d), p = tonumber(e.p) } end
            end
            if #clean > 0 then out[id] = clean; n = n + 1 end
        end
    end
    return out
end)
local function Today() return math.floor((time and time() or 0) / 86400) end
M.Today = Today

function M.History(id)
    local h = ns.db and ns.db.auctionHistory and ns.db.auctionHistory[id]
    return h or {}
end

local function Remember(id, each)
    local db = ns.db
    db.auctionHistory = db.auctionHistory or {}
    local h = db.auctionHistory[id]
    if not h then h = {}; db.auctionHistory[id] = h end
    local day = Today()
    local last = h[#h]
    if last and last.d == day then
        if each < last.p then last.p = each end
    else
        h[#h + 1] = { d = day, p = each }
        while #h > DAYS do table.remove(h, 1) end
    end
end

-- The usual price: the middle of the last days before today (nil without them)
function M.Usual(id, days)
    local h, today, list = M.History(id), Today(), {}
    for i = #h, 1, -1 do
        local e = h[i]
        if e.d < today and e.d >= today - (days or 7) then list[#list + 1] = e.p end
    end
    if #list == 0 then return nil end
    table.sort(list)
    return list[math.ceil(#list / 2)], #list
end

-- Where today's price stands against the usual: a share (+0.12 = 12% above), or nil
function M.Trend(id)
    local now = M.Auction(id)
    local usual = M.Usual(id, 7)
    if not (now and usual and usual > 0) then return nil end
    return (now - usual) / usual
end

---------------------------------------------------------------------------
-- Reading
---------------------------------------------------------------------------
-- Sell price each, and how many make a stack
function M.Vendor(id)
    local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if not get then return nil end
    local ok, _, _, _, _, _, _, _, stack, _, _, price = pcall(get, id)
    price, stack = ok and Plain(price), ok and Plain(stack)
    if type(price) ~= "number" or price <= 0 then return nil end
    return price, (type(stack) == "number" and stack > 1) and stack or 1
end

function M.Auction(id)
    local rec = ns.db and ns.db.auction and ns.db.auction[id]
    if not rec then return nil end
    return rec.p, rec.t
end

local function Ago(t)
    local s = math.max(0, (time and time() or 0) - t)
    if s < 3600 then return L["just now"] end
    if s < 86400 then return L["%d hours ago"]:format(math.floor(s / 3600)) end
    return L["%d days ago"]:format(math.floor(s / 86400))
end
M.Ago = Ago

-- The price lines for an item: { { left, right }, ... }, short and in the coins' colours: "13c  2s 60c x20"
local GREY = "|cff9aa3b5"
local function Price(each, stack)
    local M_ = ns.MoneyColored
    if stack and stack > 1 then return M_(each) .. "   " .. M_(each * stack) .. GREY .. " x" .. stack .. "|r" end
    return M_(each)
end

function M.Lines(id)
    local lines = {}
    if ns.db.vendorPrice then
        local each, stack = M.Vendor(id)
        if each then lines[#lines + 1] = { L["Vendor"], Price(each, stack) } end
    end
    if ns.db.auctionVerdict then
        local verdict, more = M.Verdict(id)
        if verdict then
            local right = M.ICON[verdict] .. " " .. M.WORDS[verdict]
            if more then right = right .. "  |cff6fe06a+|r" .. ns.MoneyColored(more) end
            lines[#lines + 1] = { L["Best"], right }
        end
    end
    if ns.db.auctionPrice then
        local each, t = M.Auction(id)
        if each then
            local _, stack = M.Vendor(id)
            lines[#lines + 1] = { L["Auction"], Price(each, stack) .. "  " .. GREY .. Ago(t) .. "|r" }
        end
    end
    return lines
end

---------------------------------------------------------------------------
-- The best use of an item: keep it, sell it to a vendor, or put it up at the auction house
---------------------------------------------------------------------------
local CUT = 0.95                                     -- what the auction house leaves you of a sale
M.ICON = {
    auction = "|TInterface\\Minimap\\Tracking\\Auctioneer:14:14|t",
    vendor = "|TInterface\\Icons\\INV_Misc_Coin_01:14:14:0:0:64:64:5:59:5:59|t",
    keep = "|TInterface\\Icons\\INV_Misc_Bag_08:14:14:0:0:64:64:5:59:5:59|t",
}
M.WORDS = { auction = L["Auction house"], vendor = L["Vendor"], keep = L["Keep"] }

-- "auction" (with how much more it brings than a vendor), "vendor", "keep", or nil when there is nothing to say
function M.Verdict(id)
    local sell = ns.db.sell
    if sell and sell.keep[id] then return "keep" end
    if sell and sell.junk[id] then return "vendor" end
    local get = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if get then
        local ok, _, _, _, equipLoc, _, classID = pcall(get, id)
        if ok and classID == 12 then return "keep" end                    -- a quest item
        local V = ns.Vendor
        if ok and V and V.MaybeUpgrade and (classID == 2 or classID == 4) and V.MaybeUpgrade(id, equipLoc) then
            return "keep"                                                  -- it could be an upgrade for you
        end
    end
    local vendor = M.Vendor(id)
    local auction = M.Auction(id)
    if auction then
        local net = auction * CUT
        if net > (vendor or 0) * 1.25 and net - (vendor or 0) >= 50 then
            return "auction", math.floor(net - (vendor or 0) + 0.5)
        end
    end
    if vendor then return "vendor" end
    return nil
end

---------------------------------------------------------------------------
-- What to ask: a price each, and why. "patient" (the default): just under the lowest when few are up, a touch
-- under when many are, and never chasing a market that is unusually low today (it waits for buyers instead).
-- "quick": 5% under the lowest, for a sale now. Never below what a vendor would pay (after the house's cut).
---------------------------------------------------------------------------
ns.RegisterSetting({
    key = "ahStrategy", kind = "boolean", default = false, command = "ahquick", section = "Bags, bank and vendor",
    label = "Quick sales at the auction house",
    tip = "price 5% under the lowest for a sale now; off: patient prices, just under the lowest, that sell when buyers come",
})

local FRESH = 6 * 3600
local function Round(p)
    if p >= 10000 then return math.floor(p / 100) * 100 end         -- over a gold: whole silver
    return math.max(1, math.floor(p))
end

function M.Suggest(id, quick)
    if quick == nil then quick = ns.db.ahStrategy end
    local now = time and time() or 0
    local rec = ns.db.auction and ns.db.auction[id]
    local low = rec and now - rec.t < FRESH and rec.p or nil
    local usual = M.Usual(id, 7)
    local base = low or usual or (rec and rec.p)
    if not base then return nil end
    local price, why
    if quick then
        price, why = base * 0.95, L["5% under the lowest, for a quick sale"]
    elseif usual and low and low < usual * 0.75 then
        price, why = usual * 0.9, L["the market is unusually low today: priced near its usual, to wait for buyers"]
    elseif (rec and rec.n or 0) <= 5 then
        price, why = base - 1, L["just under the lowest: few are up, it should sell"]
    else
        price, why = base * 0.99, L["a touch under the lowest: many are up"]
    end
    if not low then why = L["no fresh prices: from the usual price (read the house for today's)"] end
    local vendor = M.Vendor(id)
    if vendor and price * 0.95 < vendor * 1.05 then
        price, why = vendor * 1.05 / 0.95, L["held above what a vendor pays"]
    end
    return Round(price), why
end

---------------------------------------------------------------------------
-- Reading the whole auction house at once (when the game allows it), a slice at a time so nothing stutters
---------------------------------------------------------------------------
local SLICE, WAIT = 400, 15 * 60
local reader = CreateFrame("Frame")

local function ReadAll(count, info)
    local i, low, n, listings, quantity = 1, {}, 0, {}, {}
    reader:SetScript("OnUpdate", ns.Protect(function()
        local stop = math.min(count, i + SLICE - 1)
        for k = i, stop do
            local ok, _, _, c, _, _, _, _, _, _, buyout, _, _, _, _, _, _, id = pcall(info, k)
            c, buyout, id = ok and Plain(c), ok and Plain(buyout), ok and Plain(id)
            if type(id) == "number" and type(buyout) == "number" and buyout > 0 and type(c) == "number" and c > 0 then
                local each = buyout / c
                if not low[id] or each < low[id] then low[id] = each end
                listings[id] = (listings[id] or 0) + 1
                quantity[id] = (quantity[id] or 0) + c
            end
        end
        i = stop + 1
        if i > count then
            reader:SetScript("OnUpdate", nil)
            for id, each in pairs(low) do M.Note(id, each, listings[id], quantity[id]); n = n + 1 end
            ns.db.auctionReadAt = time and time() or 0
            M.scanning = nil
            ns.Say(L["Auction house read: %d prices noted."]:format(n))
        end
    end))
end
M.ReadAll = ReadAll

function M:Scan(quiet)
    if self.scanning then return false end
    local now = time and time() or 0
    if now - (ns.db.auctionScanAt or 0) < WAIT then
        if not quiet then
            ns.Say(L["The auction house can be read again in %d minutes."]:format(
                math.ceil((WAIT - (now - ns.db.auctionScanAt)) / 60)))
        end
        return false
    end
    local AH = C_AuctionHouse
    if AH and AH.ReplicateItems then                           -- the newer auction house
        if not pcall(AH.ReplicateItems) then return false end
        self.scanning = "replicate"
    elseif QueryAuctionItems and CanSendAuctionQuery then      -- the older one
        local ok, _, all = pcall(CanSendAuctionQuery)
        if not (ok and all) then
            if not quiet then ns.Say(L["The auction house cannot be read all at once right now."]) end
            return false
        end
        if not pcall(QueryAuctionItems, "", nil, nil, 0, false, -1, true) then return false end
        self.scanning = "all"
    else
        if not quiet then ns.Say(L["This client cannot read the whole auction house."]) end
        return false
    end
    ns.db.auctionScanAt = now
    ns.Say(L["Reading the auction house..."])
    return true
end

ns.RegisterCommand("scan", function() M:Scan() end, "/cchud scan",
    "read every price at the auction house at once (open it first; every 15 minutes)")

---------------------------------------------------------------------------
-- Noting what the auction house shows (the newer and the older auction house alike)
---------------------------------------------------------------------------
-- listings, quantity: how many auctions and items were up (when the whole house was read)
function M.Note(id, each, listings, quantity)
    id, each = Plain(id), Plain(each)
    if type(id) ~= "number" or type(each) ~= "number" or each <= 0 then return end
    local db = ns.db
    db.auction = db.auction or {}
    local now = time and time() or 0
    local rec = db.auction[id]
    each = math.floor(each + 0.5)
    Remember(id, each)
    -- a scan replaces an old price; within the hour the lowest seen counts
    if rec and now - rec.t < 3600 and rec.p <= each and not listings then return end
    db.auction[id] = { p = (rec and now - rec.t < 3600 and rec.p < each) and rec.p or each, t = now,
                       n = listings or (rec and rec.n), q = quantity or (rec and rec.q) }
    M.noted = (M.noted or 0) + 1
end

function M.Supply(id)
    local rec = ns.db and ns.db.auction and ns.db.auction[id]
    if rec then return rec.n, rec.q end
end

local function FromOldList()
    if not (GetNumAuctionItems and GetAuctionItemInfo) then return end
    local n = GetNumAuctionItems("list") or 0
    if M.scanning == "all" then                                   -- the whole house: a slice at a time
        M.scanning = "reading"
        ReadAll(n, function(i) return GetAuctionItemInfo("list", i) end)
        return
    end
    local low = {}
    for i = 1, n do
        local ok, _, _, count, _, _, _, _, _, _, buyout, _, _, _, _, _, _, id = pcall(GetAuctionItemInfo, "list", i)
        count, buyout, id = ok and Plain(count), ok and Plain(buyout), ok and Plain(id)
        if type(id) == "number" and type(buyout) == "number" and buyout > 0 and type(count) == "number" and count > 0 then
            local each = buyout / count
            if not low[id] or each < low[id] then low[id] = each end
        end
    end
    for id, each in pairs(low) do M.Note(id, each) end
end

local function FromBrowse()
    local AH = C_AuctionHouse
    if not (AH and AH.GetBrowseResults) then return end
    local ok, results = pcall(AH.GetBrowseResults)
    if not ok or type(results) ~= "table" then return end
    for _, r in ipairs(results) do
        local key = r.itemKey
        if key then M.Note(key.itemID, r.minPrice) end
    end
end

local function FromCommodity(id)
    local AH = C_AuctionHouse
    if not (AH and AH.GetCommoditySearchResultInfo) then return end
    local ok, r = pcall(AH.GetCommoditySearchResultInfo, id, 1)
    if ok and type(r) == "table" then M.Note(id, r.unitPrice) end
end

local function FromItem(key)
    local AH = C_AuctionHouse
    if not (AH and AH.GetItemSearchResultInfo and type(key) == "table") then return end
    local ok, r = pcall(AH.GetItemSearchResultInfo, key, 1)
    if ok and type(r) == "table" then M.Note(key.itemID, r.buyoutAmount) end
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", ns.Protect(function(_, event, arg)
    if event == "AUCTION_HOUSE_SHOW" then
        if M.active and ns.db.auctionScan then C_Timer.After(1, function() M:Scan(true) end) end
    elseif event == "REPLICATE_ITEM_LIST_UPDATE" then
        if M.scanning == "replicate" and C_AuctionHouse.GetNumReplicateItems then
            M.scanning = "reading"
            ReadAll(C_AuctionHouse.GetNumReplicateItems() or 0, C_AuctionHouse.GetReplicateItemInfo)
        end
    elseif event == "AUCTION_HOUSE_CLOSED" then
        if M.scanning == "replicate" or M.scanning == "all" then M.scanning = nil end
    elseif event == "AUCTION_ITEM_LIST_UPDATE" then FromOldList()
    elseif event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" or event == "AUCTION_HOUSE_BROWSE_RESULTS_ADDED" then FromBrowse()
    elseif event == "COMMODITY_SEARCH_RESULTS_UPDATED" then FromCommodity(arg)
    elseif event == "ITEM_SEARCH_RESULTS_UPDATED" then FromItem(arg) end
end))

function M:Apply(run)
    -- prices are noted whenever the auction house is open, also in the mouse UI (they stay right for later)
    if not self.watching then
        self.watching = true
        for _, e in ipairs({ "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "REPLICATE_ITEM_LIST_UPDATE",
                             "AUCTION_ITEM_LIST_UPDATE", "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED",
                             "AUCTION_HOUSE_BROWSE_RESULTS_ADDED", "COMMODITY_SEARCH_RESULTS_UPDATED",
                             "ITEM_SEARCH_RESULTS_UPDATED" }) do
            pcall(events.RegisterEvent, events, e)
        end
    end
    self.active = run and true or false
end

ns.RegisterModule("market", M)
