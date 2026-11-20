-- ControllerCam HUD: bags, bank and vendor.
--   * The vendor's own "Sell junk" button asks what to sell: junk by your rules, or weapons and armor up to a
--     quality. Anything beyond grey items is listed and confirmed first.
--   * Auto-sell: the same rules, applied as soon as a vendor opens (off unless you turn it on).
--   * Quick move: one bindable action on the item you are pointing at. Sells it at a vendor, moves it into
--     or out of the bank at a banker.
--   * Mark item: tag the item you are pointing at as junk (always sold), kept (never sold) or bank
--     (deposited with one command, or by itself when the bank opens).
-- Bags the game is told to leave out of junk selling are left out here too.

local ADDON, ns = ...
local L = ns.L
local say = ns.Say

local V = { active = false, merchantOpen = false, bankOpen = false }
ns.Vendor = V

local SELL_GAP = 0.15                       -- seconds between sales (the game refuses a faster pace)
local GEAR = { [2] = true, [4] = true }     -- item classes: weapon, armor
V.QUALITY = { [0] = "Poor (grey)", [1] = "Common (white)", [2] = "Uncommon (green)", [3] = "Rare (blue)" }
local QUALITY_WORD = { grey = 0, gray = 0, poor = 0, white = 1, common = 1, green = 2, uncommon = 2, blue = 3, rare = 3 }

---------------------------------------------------------------------------
-- Items
---------------------------------------------------------------------------
function ns.Money(copper)
    copper = math.floor(copper or 0)
    local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    local parts = {}
    if g > 0 then parts[#parts + 1] = g .. "g" end
    if s > 0 then parts[#parts + 1] = s .. "s" end
    if c > 0 or #parts == 0 then parts[#parts + 1] = c .. "c" end
    return table.concat(parts, " ")
end

-- The same, in the coins' colours (gold, silver, copper), for tooltips
function ns.MoneyColored(copper)
    copper = math.floor(copper or 0)
    local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    local parts = {}
    if g > 0 then parts[#parts + 1] = "|cffffd700" .. g .. "g|r" end
    if s > 0 then parts[#parts + 1] = "|cffc7c7cf" .. s .. "s|r" end
    if c > 0 or #parts == 0 then parts[#parts + 1] = "|cffeda55f" .. c .. "c|r" end
    return table.concat(parts, " ")
end

local function SellPrice(link, id)
    local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if not get then return nil end
    local name, _, _, _, _, _, _, _, _, _, price = get(link or id)
    return price, name
end

-- class, subclass and where it is worn (INVTYPE_...)
local function ItemKind(id)
    local get = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not get then return nil end
    local _, _, _, equipLoc, _, classID, subclassID = get(id)
    return classID, subclassID, equipLoc
end

---------------------------------------------------------------------------
-- What is never junk, whatever the rules say (unless you mark the item as junk yourself)
---------------------------------------------------------------------------
-- Tools of the trade look like white weapons: a mining pick is a main-hand axe, a blacksmith hammer a mace.
V.TOOLS = {}
for _, id in ipairs({ 2901, 20723, 40772, 40892, 40893,          -- mining picks, the army knives
                      5956, 7005, 12709, 19901,                   -- blacksmith hammer, skinning knives
                      6219, 10498, 9149, 4471, 5060,              -- spanner, micro-adjustor, philosopher's stone,
                                                                  -- flint and tinder, thieves' tools
                      6218, 6339, 11130, 11145, 16207,            -- enchanting rods
                      6256, 12225, 6365, 6366, 6367, 19022, 19970 }) do  -- fishing poles
    V.TOOLS[id] = true
end
local TOOL_SUBCLASS = { [14] = true, [20] = true }   -- weapons: miscellaneous (tools), fishing poles

-- Where an item is worn: the slots to compare it with
local SLOTS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_BODY = { 4 },
    INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 },
    INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 },
    INVTYPE_CLOAK = { 15 }, INVTYPE_WEAPON = { 16, 17 }, INVTYPE_SHIELD = { 17 }, INVTYPE_2HWEAPON = { 16 },
    INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_HOLDABLE = { 17 },
    INVTYPE_RANGED = { 18 }, INVTYPE_THROWN = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_RELIC = { 18 },
}

local function ItemLevel(item)
    if not item then return nil end
    if C_Item and C_Item.GetDetailedItemLevelInfo then
        local ok, lvl = pcall(C_Item.GetDetailedItemLevelInfo, item)
        if ok and type(lvl) == "number" and not ns.IsSecret(lvl) then return lvl end
    end
    local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if get then
        local ok, _, _, _, lvl = pcall(get, item)
        if ok and type(lvl) == "number" and not ns.IsSecret(lvl) then return lvl end
    end
    return nil
end

-- Could this be better than what you wear there? (an empty slot, a higher item level, or we cannot tell)
function V.MaybeUpgrade(item, equipLoc)
    local slots = SLOTS[equipLoc or ""]
    if not slots then return false end
    local mine = ItemLevel(item)
    if not mine then return true end
    for _, slot in ipairs(slots) do
        local worn = GetInventoryItemLink and GetInventoryItemLink("player", slot)
        if not worn then return true end
        local lvl = ItemLevel(worn)
        if not lvl or mine > lvl then return true end
    end
    return false
end

local function HasUse(id)
    local get = (C_Item and C_Item.GetItemSpell) or GetItemSpell
    if not get then return false end
    local ok, name = pcall(get, id)
    return ok and name ~= nil
end

-- Never sold by a rule: tools, fishing poles, and gear with a use of its own
function V.Protected(id, quality, classID, subclassID)
    if V.TOOLS[id] then return true end
    if classID == 2 and TOOL_SUBCLASS[subclassID or -1] then return true end
    if GEAR[classID or -1] and (quality or 0) >= 1 and HasUse(id) then return true end
    return false
end

local function BagLeftOut(bag)
    local ok, out = pcall(function()
        if bag == 0 then return C_Container.GetBackpackSellJunkDisabled() end
        return C_Container.GetBagSlotFlag(bag, Enum.BagSlotFlags.ExcludeJunkSell)
    end)
    return ok and out and true or false
end

local function InSet(bag, slot)
    local ok, inSet = pcall(C_Container.GetContainerItemEquipmentSetInfo, bag, slot)
    return ok and inSet and true or false
end

-- Should this item go? mode "rules": your junk rules. mode "quality": weapons and armor up to `quality`.
-- Your own marks come first; then tools and the like are never junk; grey is; other weapons and armor only
-- when they cannot be an upgrade for you.
function V:Decide(id, quality, classID, mode, upTo, subclassID, equipLoc, link)
    local sell = ns.db.sell
    if sell.keep[id] or sell.bank[id] then return false end
    if sell.junk[id] then return true end
    if V.Protected(id, quality, classID, subclassID) then return false end
    if quality == 0 then return true end
    if not GEAR[classID or -1] then return false end
    if V.MaybeUpgrade(link or id, equipLoc) then return false end
    if mode == "quality" then return quality <= upTo end
    return sell.gear and quality == 1
end

-- The items to sell, biggest first, and what they are worth together.
function V:Collect(mode, upTo)
    local list, total = {}, 0
    local last = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
    for bag = 0, last do
        if not BagLeftOut(bag) then
            for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if info and info.itemID and not info.isLocked and not info.hasNoValue and type(info.quality) == "number" then
                    local price, name = SellPrice(info.hyperlink, info.itemID)
                    local classID, subclassID, equipLoc = ItemKind(info.itemID)
                    if price and price > 0 and not InSet(bag, slot)
                        and self:Decide(info.itemID, info.quality, classID, mode, upTo, subclassID, equipLoc,
                                        info.hyperlink) then
                        local worth = price * (info.stackCount or 1)
                        list[#list + 1] = { bag = bag, slot = slot, id = info.itemID, worth = worth,
                                            quality = info.quality, name = name or info.hyperlink or ("item " .. info.itemID) }
                        total = total + worth
                    end
                end
            end
        end
    end
    table.sort(list, function(a, b)
        if a.worth ~= b.worth then return a.worth > b.worth end
        if a.bag ~= b.bag then return a.bag < b.bag end
        return a.slot < b.slot
    end)
    return list, total
end

---------------------------------------------------------------------------
-- Selling, one item at a time
---------------------------------------------------------------------------
V.log = {}                       -- what we sold this session, newest first (the vendor can buy it back)
local function Finish()
    local sold, gold, kind = V.sold or 0, V.gold or 0, V.kind
    V.queue, V.sold, V.gold, V.kind = nil, nil, nil, nil
    local after = V.after
    V.after = nil
    if sold > 0 then
        if kind == "bank" then
            say(L["deposited %d items"]:format(sold))
        else
            say(L["sold %d items for %s (/cchud sold lists them)"]:format(sold, ns.Money(gold)))
        end
    end
    if after then after() end
end

local Step
Step = ns.Protect(function()
    local queue = V.queue
    if not queue then return end
    local open = (V.kind == "bank") and V.bankOpen or (V.kind ~= "bank" and V.merchantOpen)
    if not open or #queue == 0 then return Finish() end
    local item = table.remove(queue, 1)
    local info = C_Container.GetContainerItemInfo(item.bag, item.slot)
    if info and info.itemID == item.id and not info.isLocked then      -- still the item we decided on
        C_Container.UseContainerItem(item.bag, item.slot)
        V.sold, V.gold = V.sold + 1, V.gold + item.worth
        if V.kind ~= "bank" then
            table.insert(V.log, 1, { name = item.name, worth = item.worth })
            if #V.log > 30 then table.remove(V.log) end
        end
    end
    C_Timer.After(SELL_GAP, Step)
end)

function V:Sell(list)
    if self.queue then return false end
    if #list == 0 then say(L["Nothing to sell."]); return false end
    self.queue, self.sold, self.gold, self.kind = list, 0, 0, "sell"
    Step()
    return true
end

ns.RegisterSetting({
    key = "depositMatching", kind = "boolean", default = true, command = "depositmatch", section = "Bags, bank and vendor",
    label = "Deposit also puts away what the bank already holds",
    tip = "a deposit moves every item your bank already has some of (materials, potions...), on top of the items you marked for the bank; never grey items, tools or items you marked as junk or kept",
})

-- Would a deposit take this item because the bank already holds some? Not grey items, tools, gear you could
-- use, or items you marked yourself (junk, kept)
function V.Matches(id, quality, held)
    if not (held and held[id]) then return false end
    local sell = ns.db.sell
    if sell.junk[id] or sell.keep[id] or (quality or 1) == 0 then return false end
    local classID, subclassID = ItemKind(id)
    return not V.Protected(id, quality, classID, subclassID)
end

-- Everything in the bags that is marked for the bank, and (when turned on) what the bank already holds
function V:CollectBank()
    local list = {}
    local held = ns.db.depositMatching and ns.Inventory and ns.Inventory.BankIds(true) or nil
    local last = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
    for bag = 0, last do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local id = info and info.itemID
            if id and not ns.IsSecret(id) and not info.isLocked
                and (ns.db.sell.bank[id] or V.Matches(id, info.quality, held)) then
                list[#list + 1] = { bag = bag, slot = slot, id = id, worth = 0 }
            end
        end
    end
    return list
end

function V:Deposit(quiet)
    if not (self.bankOpen or (ns.Inventory and ns.Inventory.bankOpen)) then say(L["Open the bank first."]); return false end
    if self.queue then return false end
    local list = self:CollectBank()
    if #list == 0 then
        if not quiet then
            say(ns.db.depositMatching and L["Nothing to deposit: your bank holds none of what you carry, and nothing is marked for it."]
                or L["Nothing is marked for the bank. Point at an item and use Mark item."])
        end
        return false
    end
    self.queue, self.sold, self.gold, self.kind = list, 0, 0, "bank"
    Step()
    return true
end

---------------------------------------------------------------------------
-- Asking what to sell (the game's own dialog boxes, which a controller can already answer)
---------------------------------------------------------------------------
local function Names(list, max)
    local names = {}
    for i = 1, math.min(#list, max) do names[i] = list[i].name end
    local text = table.concat(names, ", ")
    if #list > max then text = text .. ", ..." end
    return text
end

local function OnlyGrey(list)
    for _, item in ipairs(list) do
        if item.quality ~= 0 then return false end
    end
    return true
end

local function Later(fn) C_Timer.After(0, fn) end       -- let the dialog that was answered close first

function V:Confirm(list, total)
    if #list == 0 then say(L["Nothing to sell."]); return end
    self.pending = list
    StaticPopup_Show("CCHUD_SELL_CONFIRM", #list, ns.Money(total) .. ": " .. Names(list, 6))
end

function V:AskQuality()
    local common, commonGold = self:Collect("quality", 1)
    local uncommon, uncommonGold = self:Collect("quality", 2)
    self.choice = { { common, commonGold }, { uncommon, uncommonGold } }
    StaticPopup_Show("CCHUD_SELL_QUALITY", ("%d, %s"):format(#common, ns.Money(commonGold)),
        ("%d, %s"):format(#uncommon, ns.Money(uncommonGold)))
end

function V:Prompt()
    if not self.merchantOpen then say(L["Open a vendor first."]); return end
    if self.queue then return end
    local junk, total = self:Collect("rules")
    self.junk, self.junkTotal = junk, total
    StaticPopup_Show("CCHUD_SELL", #junk, ns.Money(total))
end

-- Junk by the rules. Grey items go straight away, like the game's own button; anything else is confirmed.
function V:SellJunk()
    local junk, total = self:Collect("rules")
    if OnlyGrey(junk) then return self:Sell(junk) end
    self:Confirm(junk, total)
end

local function DefinePopups()
    if V.popups or type(StaticPopupDialogs) ~= "table" then return end
    V.popups = true
    local base = { timeout = 0, whileDead = false, hideOnEscape = true, preferredIndex = 3 }
    local function dialog(extra)
        local d = {}
        for k, v in pairs(base) do d[k] = v end
        for k, v in pairs(extra) do d[k] = v end
        return d
    end
    StaticPopupDialogs["CCHUD_SELL"] = dialog({
        text = L["Sell junk: %d items for %s.\n\nOr sell weapons and armor by quality."],
        button1 = L["Sell junk"], button2 = CANCEL or "Cancel", button3 = L["By quality"],
        OnAccept = function() Later(function() V:SellJunk() end) end,
        OnAlt = function() Later(function() V:AskQuality() end) end,
    })
    StaticPopupDialogs["CCHUD_SELL_QUALITY"] = dialog({
        text = L["Sell weapons and armor up to which quality?\n\nCommon (white): %s\nUncommon (green): %s"],
        button1 = L["Common"], button2 = CANCEL or "Cancel", button3 = L["Uncommon"],
        OnAccept = function() local c = V.choice[1]; Later(function() V:Confirm(c[1], c[2]) end) end,
        OnAlt = function() local c = V.choice[2]; Later(function() V:Confirm(c[1], c[2]) end) end,
    })
    StaticPopupDialogs["CCHUD_SELL_CONFIRM"] = dialog({
        text = L["Sell %d items?\n\n%s"],
        button1 = L["Sell"], button2 = CANCEL or "Cancel",
        OnAccept = function() local list = V.pending; V.pending = nil; if list then V:Sell(list) end end,
        OnCancel = function() V.pending = nil end,
    })
end

---------------------------------------------------------------------------
-- The item you are pointing at
---------------------------------------------------------------------------
local function PointedSlot()
    local frame
    if GetMouseFoci then
        local foci = GetMouseFoci()
        frame = foci and foci[1]
    elseif GetMouseFocus then
        frame = GetMouseFocus()
    end
    for _ = 1, 4 do
        if type(frame) ~= "table" then return nil end
        if frame.GetBagID and frame.GetID then
            local ok, bag = pcall(frame.GetBagID, frame)
            local ok2, slot = pcall(frame.GetID, frame)
            if ok and ok2 and type(bag) == "number" and type(slot) == "number" and slot > 0 then return bag, slot end
        end
        frame = frame.GetParent and frame:GetParent()
    end
end
V.PointedSlot = PointedSlot

-- Sell at a vendor, deposit or withdraw at a banker, hand over in a trade, attach to a letter. Does nothing
-- elsewhere (so it can never use an item).
V.Pointed = PointedSlot

function V:QuickMove()
    if not self.active then return end
    if InCombatLockdown() then return end
    if not self:MoveOpen() then
        say(L["Quick move works at a vendor (sell), a banker (deposit, withdraw), in a trade or at the mailbox."])
        return
    end
    local bag, slot = PointedSlot()
    if not bag then say(L["Point at an item first."]); return end
    C_Container.UseContainerItem(bag, slot)
end

-- Is a window open where quick move moves things?
function V:MoveOpen()
    return (self.merchantOpen or self.bankOpen or self.tradeOpen or self.mailOpen) and true or false
end

-- Cycle the item you are pointing at: no mark -> junk (always sold) -> kept (never sold) -> bank -> no mark.
function V:MarkItem(id)
    if not self.active and not id then return end
    if not id then
        local bag, slot = PointedSlot()
        if not bag then say(L["Point at an item first."]); return end
        id = C_Container.GetContainerItemID(bag, slot)
        if not id then return end
    end
    local sell = ns.db.sell
    local _, name = SellPrice(nil, id)
    name = name or ("item " .. id)
    if sell.junk[id] then
        sell.junk[id], sell.keep[id] = nil, true
        say(L["%s: kept, never sold"]:format(name))
    elseif sell.keep[id] then
        sell.keep[id], sell.bank[id] = nil, true
        say(L["%s: bank, deposited when you ask (never sold)"]:format(name))
    elseif sell.bank[id] then
        sell.bank[id] = nil
        say(L["%s: no mark"]:format(name))
    else
        sell.junk[id] = true
        say(L["%s: junk, sold with the rest"]:format(name))
    end
end

-- Key bindings (Bindings.xml)
BINDING_HEADER_CCHUD = "ControllerCam"
BINDING_NAME_CCHUD_QUICKMOVE = L["Quick move: sell, bank, trade or mail the item you point at"]
BINDING_NAME_CCHUD_MARKITEM = L["Mark the item: junk / kept / bank / no mark"]
function ControllerCamHUD_QuickMove() ns.Protect(function() V:QuickMove() end)() end
function ControllerCamHUD_MarkItem() ns.Protect(function() V:MarkItem() end)() end
BINDING_NAME_CCHUD_DEPOSIT = L["Deposit: put in the bank what it already holds, and what you marked for it"]
function ControllerCamHUD_Deposit() ns.Protect(function() V:Deposit() end)() end

---------------------------------------------------------------------------
-- Turning on and off
---------------------------------------------------------------------------
-- When a vendor opens: grey items and the ones you marked as junk go by themselves; anything else your rules
-- count as junk (white weapons and armor) is listed and asked about first, never sold silently
function V:AutoSell()
    local junk = self:Collect("rules")
    local sure, ask, askTotal = {}, {}, 0
    for _, item in ipairs(junk) do
        if item.quality == 0 or ns.db.sell.junk[item.id] then
            sure[#sure + 1] = item
        else
            ask[#ask + 1] = item
            askTotal = askTotal + item.worth
        end
    end
    local function Ask() if #ask > 0 then self:Confirm(ask, askTotal) end end
    if #sure > 0 then
        self.after = Ask
        self:Sell(sure)
    else
        Ask()
    end
end

ns.RegisterCommand("sold", function()
    if #V.log == 0 then ns.Say(L["Nothing sold yet this session."]); return end
    for _, item in ipairs(V.log) do print(("  %s  %s"):format(tostring(item.name), ns.Money(item.worth))) end
    ns.Say(L["A vendor's Buyback tab buys these back until you log out."])
end, "/cchud sold", "list what was sold for you this session, to buy something back")

---------------------------------------------------------------------------
-- Repairs: everything, as soon as a vendor who repairs opens (from the guild bank first when allowed)
---------------------------------------------------------------------------
ns.RegisterSetting({
    key = "autoRepair", kind = "boolean", default = true, command = "autorepair", section = "Bags, bank and vendor",
    label = "Repair at vendors", tip = "repair everything as soon as a vendor who repairs opens",
})
ns.RegisterSetting({
    key = "repairGuild", kind = "boolean", default = false, command = "repairguild", section = "Bags, bank and vendor",
    label = "Repair from the guild bank", tip = "pay for repairs from the guild bank when your guild allows it, your own gold otherwise",
})

function V:Repair()
    if not (CanMerchantRepair and CanMerchantRepair() and GetRepairAllCost and RepairAllItems) then return false end
    local cost, can = GetRepairAllCost()
    if ns.IsSecret(cost) or type(cost) ~= "number" or cost <= 0 or can == false then return false end
    if ns.db.repairGuild and CanGuildBankRepair and CanGuildBankRepair() then
        local limit = GetGuildBankWithdrawMoney and GetGuildBankWithdrawMoney()
        if type(limit) == "number" and (limit < 0 or limit >= cost) then
            RepairAllItems(true)
            say(L["Repaired for %s from the guild bank"]:format(ns.Money(cost)))
            return true
        end
    end
    if (GetMoney() or 0) < cost then
        say(L["Not enough gold to repair everything (%s)."]:format(ns.Money(cost)))
        return false
    end
    RepairAllItems(false)
    say(L["Repaired for %s"]:format(ns.Money(cost)))
    return true
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", ns.Protect(function(_, event)
    if event == "MERCHANT_SHOW" then
        V.merchantOpen = true
        if ns.db.autoRepair then V:Repair() end
        if ns.db.sell.auto then V:AutoSell() end
    elseif event == "MERCHANT_CLOSED" then
        V.merchantOpen = false
    elseif event == "BANKFRAME_OPENED" then
        V.bankOpen = true
        if ns.db.sell.deposit then V:Deposit(true) end
    elseif event == "BANKFRAME_CLOSED" then
        V.bankOpen = false
    elseif event == "TRADE_SHOW" then V.tradeOpen = true
    elseif event == "TRADE_CLOSED" then V.tradeOpen = false
    elseif event == "MAIL_SHOW" then V.mailOpen = true
    elseif event == "MAIL_CLOSED" then V.mailOpen = false
    end
end))

local OurClick = ns.Protect(function() V:Prompt() end)

function V:Apply(run)
    local want = run and ns.db.vendor and true or false
    local button = _G.MerchantSellAllJunkButton
    if want and not self.active then
        self.active = true
        DefinePopups()
        for _, event in ipairs({ "MERCHANT_SHOW", "MERCHANT_CLOSED", "BANKFRAME_OPENED", "BANKFRAME_CLOSED",
                                 "TRADE_SHOW", "TRADE_CLOSED", "MAIL_SHOW", "MAIL_CLOSED" }) do
            pcall(events.RegisterEvent, events, event)
        end
        if button and button.SetScript then
            self.originalClick = button:GetScript("OnClick")
            button:SetScript("OnClick", OurClick)
            self.hooked = true
        end
    elseif not want and self.active then
        self.active = false
        events:UnregisterAllEvents()
        self.queue, self.pending = nil, nil
        if self.hooked and button then
            button:SetScript("OnClick", self.originalClick)
            self.hooked, self.originalClick = false, nil
        end
    end
end

function V.ParseQuality(text)
    local n = tonumber(text)
    if n == nil then n = QUALITY_WORD[text or ""] end
    if n and V.QUALITY[n] then return n end
end

ns.RegisterModule("vendor", V)
