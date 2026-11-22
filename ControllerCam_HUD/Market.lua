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
    label = "Best use of an item", tip = "an item's tooltip says what to do with it: sell it at the auction house (and how much more that brings), sell it to a vendor, keep it, or keep it for a quest",
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
                if type(e) == "table" and tonumber(e.d) and tonumber(e.p) then
                    clean[#clean + 1] = { d = tonumber(e.d), p = tonumber(e.p), o = tonumber(e.o), x = tonumber(e.x),
                                          c = tonumber(e.c) }
                end
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
        last.o = last.o or last.p                                  -- (a day kept before candles: its lowest)
        if each < last.p then last.p = each end
        if not last.x or each > last.x then last.x = each end
        last.c = each
    else
        -- p the day's lowest; for its candle: o where it opened (the first read), x the highest, c the last read
        h[#h + 1] = { d = day, p = each, o = each, x = each, c = each }
        while #h > DAYS do table.remove(h, 1) end
    end
end

-- A candle for each day of the last `days` (7) with a price, oldest first: { d, o = opened, h = highest,
-- l = lowest, c = closed }. A day kept before candles were (its lowest price alone) opens where the day before
-- closed and closes at its lowest.
function M.Candles(id, days)
    local today, out, prev = Today(), {}, nil
    for _, e in ipairs(M.History(id)) do
        local o = e.o or (prev and prev.c) or e.p
        local c = e.c or e.p
        local candle = { d = e.d, o = o, c = c, l = math.min(e.p, o, c), h = math.max(e.x or e.p, o, c) }
        if e.d > today - (days or 7) and e.d <= today then out[#out + 1] = candle end
        prev = candle
    end
    return out
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

-- How many make a stack (1 when not known): also for an item no vendor buys (most quest items), which M.Vendor
-- leaves out altogether
function M.Stack(id)
    local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if not get then return 1 end
    local ok, _, _, _, _, _, _, _, stack = pcall(get, id)
    stack = ok and Plain(stack)
    return (type(stack) == "number" and stack > 1) and stack or 1
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
        local verdict, more, want = M.Verdict(id)
        if verdict then
            lines[#lines + 1] = { L["Best"], M.BestText(verdict, more, want) }
            -- a skill-up: the recipes it is for, as the profession's window showed them (orange, yellow)
            if verdict == "skill" then
                for i, r in ipairs(ns.Professions.Recipes(want, id)) do
                    lines[#lines + 1] = { i == 1 and L["Recipes"] or "", ns.Professions.RecipeText(r) }
                end
            end
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

-- The panel under an item's tooltip: narrow, one line each, read top to bottom; the prices first (what a merchant
-- asks for it, when it is one of theirs), the advice apart, its keyword and its gain picked out:
--   Cost: 45s
--   Vendor: 12s 50c
--   Auction: 75s (2 hours ago)
--
--   Recommendation:
--   Auction for +46s 25c
--   80% chance of sale
local GOLD, GAIN = "|cffffd100", "|cff6fe06a"
local function Labelled(label, value) return { GREY .. label .. ":|r " .. value } end

-- What the merchant asks for it, when the tooltip is over one of the merchant's items (or one to buy back):
-- price, how many for it
function M.MerchantCost(tooltip)
    if type(tooltip) ~= "table" or not tooltip.GetOwner then return nil end
    local ok, owner = pcall(tooltip.GetOwner, tooltip)
    if not ok or type(owner) ~= "table" or not owner.GetName then return nil end
    local okN, name = pcall(owner.GetName, owner)
    name = okN and Plain(name)
    if type(name) ~= "string" or not name:find("^MerchantItem%d+ItemButton$") then return nil end
    local okI, index = pcall(owner.GetID, owner)
    index = okI and Plain(index)
    if type(index) ~= "number" or index < 1 then return nil end
    local merchant = _G.MerchantFrame
    local tab = type(merchant) == "table" and rawget(merchant, "selectedTab")
    local price, count
    if tab == 2 then                                             -- the buyback tab
        if GetBuybackItemInfo then
            local okB, _, _, p, q = pcall(GetBuybackItemInfo, index)
            if okB then price, count = p, q end
        end
    else
        if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
            local okM, info = pcall(C_MerchantFrame.GetItemInfo, index)
            if okM and type(info) == "table" then price, count = info.price, info.stackCount end
        end
        if price == nil and GetMerchantItemInfo then
            local okM, _, _, p, q = pcall(GetMerchantItemInfo, index)
            if okM then price, count = p, q end
        end
    end
    price, count = Plain(price), Plain(count)
    if type(price) ~= "number" or price <= 0 then return nil end           -- paid in tokens or items: not ours to say
    return price, (type(count) == "number" and count > 1) and count or 1
end

-- The advice, in lines of its own: { { text }, ... }
function M.Advice(verdict, more, want, id)
    local lines = { { GREY .. L["Recommendation"] .. ":|r" } }
    local function add(text) lines[#lines + 1] = { text } end
    local word = GOLD .. ((verdict == "auction" and L["Auction"]) or (verdict == "vendor" and L["Vendor"])
        or (verdict == "equip" and L["Equip"]) or (verdict == "quest" and L["Quest"]) or L["Keep"]) .. "|r"
    if verdict == "quest" then
        add(word)
        add(GREY .. ns.Quests.WantText(want) .. "|r")
        return lines
    end
    if verdict == "equip" then
        add(word)
        add(GREY .. L["better than what you wear"] .. "|r")
        return lines
    end
    if verdict == "skill" then
        -- Keep for Cooking 221/225, and under it the recipes that still give a point, with the window's arrows
        add(L["%s for %s"]:format(word, ns.Professions.Words(want)))
        if want.via then add(GREY .. L["made into %s"]:format(ns.Professions.ItemName(want.via)) .. "|r") end
        for _, r in ipairs(ns.Professions.Recipes(want, id)) do add("   " .. ns.Professions.RecipeText(r)) end
    elseif verdict == "craft" then
        add(word)
        add(ns.Professions.Words(want))
    else
        if more and more > 0 then add(L["%s for %s"]:format(word, GAIN .. "+" .. ns.Money(more) .. "|r")) else add(word) end
        local chance = verdict == "auction" and type(want) == "table" and want.chance
        if chance then add(GREY .. L["%d%% chance of sale"]:format(math.floor(chance * 100 + 0.5)) .. "|r") end
    end
    return lines
end

-- The tooltip panel's two parts: the prices, and the advice
function M.TipLines(id, tooltip)
    local prices, advice = {}, {}
    local cost, count = M.MerchantCost(tooltip)
    if cost then
        prices[#prices + 1] = Labelled(L["Cost"], ns.MoneyColored(cost) .. (count > 1 and (GREY .. " x" .. count .. "|r") or ""))
    end
    if ns.db.vendorPrice then
        local each = M.Vendor(id)
        if each then prices[#prices + 1] = Labelled(L["Vendor"], ns.MoneyColored(each)) end
    end
    if ns.db.auctionPrice then
        local each, t = M.Auction(id)
        if each then prices[#prices + 1] = Labelled(L["Auction"], ns.MoneyColored(each) .. GREY .. " (" .. Ago(t) .. ")|r") end
    end
    if ns.db.auctionVerdict then
        local verdict, more, want = M.Verdict(id)
        if verdict then advice = M.Advice(verdict, more, want, id) end
    end
    return prices, advice
end

---------------------------------------------------------------------------
-- The best use of an item: keep it, sell it to a vendor, or put it up at the auction house
---------------------------------------------------------------------------
local CUT = 0.95                                     -- what the auction house leaves you of a sale
M.BETTER, M.WORTH = 1.1, 100                         -- a tenth more than a vendor (after all the below), a silver a stack
-- and never for pennies: at least 10 copper more for each one, and something that sells for at least 25 copper
-- (Smooth Pebble at 8c against a vendor's 4c is not worth a trip to the auction house, however big a stack)
M.MIN_EACH, M.MIN_PRICE = 10, 25
-- The deposit: lost when an auction does not sell (given back when it does). The game works it out from the
-- item's vendor price and the auction's length; a share of the vendor price for a 24-hour auction stands in
-- for it here, as the real one can only be asked for an item put in the auction house's sell slot.
M.DEPOSIT = 0.30
M.CHANCE = 0.7                                       -- the chance of a sale when nothing says otherwise

function M.Deposit(id)
    local each = M.Vendor(id)
    return (each or 0) * M.DEPOSIT
end

-- How likely an auction of it is to sell at `ask` each (the suggested price when not given). The house shows
-- listings, not sales, so this is a judgement, rounded to 5% (it is no more exact than that). A fresh price
-- just under the lowest starts at 70%; from there, up or down by:
--   the asking price against the lowest up and against the usual price (under sells, over waits);
--   how many auctions are up (plenty is a busy market, where things sell; next to none, few buyers look);
--   where the price went this week (rising, falling, jumping about) and on how many days it was seen;
--   how your own auctions of it did here (sold, or came back);
--   a price held up by the vendor floor, and a price read days ago.
-- Returns the chance (0.05 to 0.95) and what moved it, biggest first: { { text =, d = +/- share }, ... }.
M.ODDS = 0.60
function M.SellChance(id, ask)
    local rec = ns.db and ns.db.auction and ns.db.auction[id]
    if not rec then return nil end
    ask = ask or M.Suggest(id)
    local now = time and time() or 0
    local p, why = M.ODDS, {}
    local function By(d, text) p = p + d; why[#why + 1] = { text = text, d = d } end
    local age = now - (rec.t or 0)
    if age > 3 * 86400 then By(-0.15, L["old prices"]) elseif age > 86400 then By(-0.05, L["old prices"]) end
    local low = rec.p
    if ask and low and low > 0 then
        local r = ask / low
        if r <= 0.96 then By(0.15, L["under the lowest"]) elseif r < 1 then By(0.10, L["under the lowest"])
        elseif r > 1.15 then By(-0.20, L["over the lowest"]) elseif r > 1.02 then By(-0.10, L["over the lowest"]) end
    end
    local usual, days = M.Usual(id, 7)
    if ask and usual and usual > 0 then
        local u = ask / usual
        if u <= 0.85 then By(0.10, L["under the usual"]) elseif u <= 1 then By(0.05, L["under the usual"])
        elseif u > 1.3 then By(-0.15, L["over the usual"]) elseif u > 1.15 then By(-0.05, L["over the usual"]) end
    end
    if (days or 0) >= 3 then By(0.05, L["seen on several days"]) end
    if rec.n then
        if rec.n >= 30 then By(0.05, L["a busy market"]) elseif rec.n <= 2 then By(-0.10, L["hardly any up"]) end
    end
    local trend = M.Trend(id)
    if trend and trend > 0.10 then By(0.05, L["prices rising"])
    elseif trend and trend < -0.15 then By(-0.10, L["prices falling"]) end
    local lo, hi, today = nil, nil, Today()
    for _, e in ipairs(M.History(id)) do
        if e.d > today - 7 and e.d <= today then
            lo, hi = math.min(lo or e.p, e.p), math.max(hi or e.p, e.p)
        end
    end
    if (days or 0) >= 3 and lo and hi > lo * 1.6 then By(-0.05, L["prices jump about"]) end
    local mine = ns.db.ahLedger and ns.db.ahLedger[id]               -- (a day after your last post of it)
    if mine and (mine.lots or 0) >= 2 and now - (mine.t or 0) > 86400 then
        local rate = math.min(1, (mine.sold or 0) / mine.lots)
        if rate >= 0.6 then By(0.10, L["yours sold here before"])
        elseif rate <= 0.25 then By(-0.15, L["yours went unsold before"]) end
    end
    local vendor = M.Vendor(id)
    if ask and vendor and ask * CUT <= vendor * 1.06 then By(-0.05, L["held up by the vendor floor"]) end
    p = math.floor(math.max(0.05, math.min(0.95, p)) * 20 + 0.5) / 20
    table.sort(why, function(a, b) return math.abs(a.d) > math.abs(b.d) end)
    return p, why
end
M.ICON = {
    auction = "|TInterface\\Minimap\\Tracking\\Auctioneer:14:14|t",
    vendor = "|TInterface\\Icons\\INV_Misc_Coin_01:14:14:0:0:64:64:5:59:5:59|t",
    keep = "|TInterface\\Icons\\INV_Misc_Bag_08:14:14:0:0:64:64:5:59:5:59|t",
    quest = "|TInterface\\GossipFrame\\ActiveQuestIcon:14:14|t",
    starts = "|TInterface\\GossipFrame\\AvailableQuestIcon:14:14|t",
}
M.WORDS = { auction = L["Auction house"], vendor = L["Vendor"], keep = L["Keep"], equip = L["Equip"], quest = L["Quest"] }

-- The best use in words, with its icon: "Auction house +22c  80% likely to sell", "Skill-up: Alchemy 50/150"
function M.BestText(verdict, more, want)
    local right
    if verdict == "skill" then
        right = M.ICON.keep .. " " .. L["Skill-up: %s"]:format(ns.Professions.Words(want))
    elseif verdict == "craft" then
        return M.ICON.keep .. " " .. ns.Professions.Words(want)
    elseif verdict == "quest" then
        local icon = (type(want) == "table" and want.starts) and M.ICON.starts or M.ICON.quest
        return icon .. " " .. L["Quest: %s"]:format(ns.Quests.WantText(want))
    else
        right = (M.ICON[verdict] or "") .. " " .. (M.WORDS[verdict] or tostring(verdict))
    end
    if more and verdict ~= "skill" then right = right .. "  |cff6fe06a+|r" .. ns.MoneyColored(more) end
    local chance = verdict == "auction" and type(want) == "table" and want.chance
    if chance then right = right .. GREY .. "  " .. L["%d%% likely to sell"]:format(math.floor(chance * 100 + 0.5)) .. "|r" end
    return right
end

-- The whole auction house read lately (in the last three days): an item it had none of is not sold there
M.LATELY = 3 * 86400
function M.ReadLately()
    local read = ns.db and ns.db.auctionReadAt or 0
    return read > 0 and (time and time() or 0) - read < M.LATELY
end

-- An item's quality (0 grey ... ), or nil
function M.Quality(id)
    local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if not get then return nil end
    local ok, _, _, quality = pcall(get, id)
    quality = ok and Plain(quality)
    return type(quality) == "number" and quality or nil
end

-- Enough prices to go by: the whole house read in the last two weeks, or 20 prices noted in that time
M.FRESH_DATA = 14 * 86400
function M.HasData()
    local db = ns.db
    if not db then return false end
    local now = time and time() or 0
    if (db.auctionReadAt or 0) > 0 and now - db.auctionReadAt < M.FRESH_DATA then return true end
    local n = 0
    for _, rec in pairs(db.auction or {}) do
        if now - (rec.t or 0) < M.FRESH_DATA then
            n = n + 1
            if n >= 20 then return true end
        end
    end
    return false
end

-- "auction" (with how much more it brings than a vendor), "vendor", "keep", "quest" (with what a quest of yours
-- wants it for: Quests.lua), "skill" (with who can still learn from it: Professions.lua), or nil when there is
-- nothing to say. bound: it cannot go to the auction house.
function M.Verdict(id, bound)
    local sell = ns.db.sell
    if sell and sell.keep[id] then return "keep" end
    if sell and sell.junk[id] then return "vendor" end
    local quest = ns.Quests and ns.Quests.ItemWant and ns.Quests.ItemWant(id)
    if quest then return "quest", nil, quest end                         -- a quest of yours still needs it
    -- Kept unless the auction house pays clearly more: a quest item no quest of yours still needs (Green Hills of
    -- Stranglethorn pages once the quest is done) that can still be traded, and the best consumable of its kind
    -- you carry (a potion, Rumsey Rum). Without a price worth the trip they stay "keep".
    local soft
    local get = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if get then
        local ok, _, _, _, equipLoc, _, classID, subclassID = pcall(get, id)
        if ok and classID == 12 then                                       -- a quest item
            if bound then return "keep" end
            soft = true
        end
        local Vn = ns.Vendor
        if ok and Vn and Vn.IsTool and Vn.IsTool(id, classID, subclassID) and Vn.LastTool(id) then
            return "keep"                                                  -- your last tool of its kind
        end
        local V = ns.Vendor
        if ok and V and V.Upgrade and (classID == 2 or classID == 4) and V.Upgrade(id, equipLoc) then
            return "equip"                                                 -- better than what you wear
        end
        if ok and V and V.KeepConsumable and classID == 0 and V.KeepConsumable(id, nil, classID) then
            soft = true                                                    -- the best of its kind you carry
        end
        if ok and V and V.MaybeUpgrade and (classID == 2 or classID == 4) and V.MaybeUpgrade(id, equipLoc) then
            return "keep"                                                  -- it could be an upgrade for you
        end
    end
    if soft and not M.Fetches(id, bound) then return "keep" end
    -- grey: to a vendor. It may be up at the auction house for more, but grey things there seldom sell
    if M.Quality(id) == 0 then
        if M.Vendor(id) then return "vendor" end
        return nil
    end
    local want = ns.Professions and ns.Professions.Wants(id)
    if want then return "skill", nil, want end                             -- one of yours still learns from it
    local vendor = M.Vendor(id)
    local auction = not bound and M.Auction(id)
    local own = math.max((auction or 0) * CUT, vendor or 0)
    local craft = ns.Professions and ns.Professions.Crafts(id, own)
    if craft then return "craft", math.floor(craft.each - own + 0.5), craft end   -- worth more made into something
    local more, how = M.Fetches(id, bound)
    if more then return "auction", more, how end
    if vendor then return "vendor" end
    return nil
end

-- The auction house when what it can be expected to bring is clearly more than a vendor pays, and the
-- difference over a full stack is worth the trip (a silver). Expected: it sells (its chance, M.SellChance) for
-- the price after the house's cut; or it does not, the deposit is lost and it goes to a vendor after all.
-- How much more it brings, and { chance, deposit }; or nil.
function M.Fetches(id, bound)
    local auction = not bound and M.Auction(id)
    if not auction then return nil end
    local v = M.Vendor(id) or 0
    local p = M.SellChance(id) or M.CHANCE
    local expect = p * auction * CUT + (1 - p) * (v - M.Deposit(id))
    local stack = M.Stack(id)                 -- (not M.Vendor's: with no vendor price, that said a stack of one)
    if expect > v * M.BETTER and (expect - v) * stack >= M.WORTH and expect - v >= M.MIN_EACH
        and auction >= M.MIN_PRICE then
        return math.floor(expect - v + 0.5), { chance = p, deposit = M.Deposit(id) }
    end
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
