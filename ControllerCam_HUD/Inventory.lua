-- ControllerCam HUD: what you own, and keeping it tidy.
--   * Sort: one action (a key binding, /cchud sort, or the button in the options) tidies your bags, and the
--     bank too while it is open. It is the game's own sorting, so its options (which way to sort, bags left
--     out of sorting) are the ones that count.
--   * Counts: an item's tooltip says how many you have in your bags and bank, and how many your other
--     characters on this account hold. What each character carries is noted whenever their bags change, and
--     their bank when it is open.
--   * Gold: /cchud gold lists every character's gold and the total.

local ADDON, ns = ...
local L = ns.L

local I = { active = false }
ns.Inventory = I

ns.RegisterSetting({
    key = "invTotals", kind = "boolean", default = true, command = "invtotals", section = "Bags, bank and vendor",
    label = "Item counts in tooltips",
    tip = "an item's tooltip says how many you have in your bags and bank, and how many your other characters hold",
})

-- What each character holds: [name-realm] = { class, money, bags = { [itemID] = n }, bank = { ... }, seen,
-- prof = { [kind] = { name, rank, cap, at, recipes, via, uses = { [itemID] = level } } } (Professions.lua) }
ns.RegisterSaved("inventory", function(old)
    local out = {}
    if type(old) ~= "table" then return out end
    for who, rec in pairs(old) do
        if type(who) == "string" and type(rec) == "table" then
            local clean = { class = type(rec.class) == "string" and rec.class or nil,
                            money = tonumber(rec.money) or 0, bags = {}, bank = {}, seen = tonumber(rec.seen) or 0,
                            level = tonumber(rec.level),
                            faction = type(rec.faction) == "string" and rec.faction or nil }
            -- what they wear: [slot] = the item's string ("item:1234:0:..."), for upgrades for them (Vendor.lua)
            if type(rec.worn) == "table" then
                clean.worn = {}
                for slot, item in pairs(rec.worn) do
                    if type(slot) == "number" and type(item) == "string" and item:find("^item:%d+") then
                        clean.worn[slot] = item
                    end
                end
            end
            for _, place in ipairs({ "bags", "bank" }) do
                if type(rec[place]) == "table" then
                    for id, n in pairs(rec[place]) do
                        if type(id) == "number" and type(n) == "number" and n > 0 then clean[place][id] = n end
                    end
                end
            end
            if type(rec.prof) == "table" then
                clean.prof = {}
                for kind, p in pairs(rec.prof) do
                    if type(kind) == "string" and type(p) == "table" then
                        local c = { name = type(p.name) == "string" and p.name or nil, rank = tonumber(p.rank),
                                    cap = tonumber(p.cap), at = tonumber(p.at), recipes = tonumber(p.recipes),
                                    via = type(p.via) == "string" and p.via or nil }
                        if type(p.uses) == "table" then
                            c.uses = {}
                            for id, level in pairs(p.uses) do
                                if type(id) == "number" and tonumber(level) then c.uses[id] = tonumber(level) end
                            end
                        end
                        if type(p.why) == "table" then
                            c.why = {}
                            for id, list in pairs(p.why) do
                                if type(id) == "number" and type(list) == "table" then
                                    local keep = {}
                                    for _, r in ipairs(list) do
                                        if type(r) == "table" and type(r.n) == "string" and tonumber(r.l) and #keep < 5 then
                                            keep[#keep + 1] = { n = r.n, l = tonumber(r.l) }
                                        end
                                    end
                                    if #keep > 0 then c.why[id] = keep end
                                end
                            end
                        end
                        if type(p.crafts) == "table" then
                            c.crafts = {}
                            for id, list in pairs(p.crafts) do
                                if type(id) == "number" and type(list) == "table" then
                                    local keep = {}
                                    for _, k in ipairs(list) do
                                        if type(k) == "table" and tonumber(k.p) and #keep < 6 then
                                            keep[#keep + 1] = { p = tonumber(k.p), n = tonumber(k.n) or 1, m = tonumber(k.m) or 1 }
                                        end
                                    end
                                    if #keep > 0 then c.crafts[id] = keep end
                                end
                            end
                        end
                        clean.prof[kind] = c
                    end
                end
            end
            out[who] = clean
        end
    end
    return out
end)

local function Me()
    local name = UnitName("player")
    local realm = (GetNormalizedRealmName and GetNormalizedRealmName()) or (GetRealmName and GetRealmName()) or ""
    if ns.IsSecret(name) or not name then return nil end
    return name .. "-" .. (realm or "")
end
I.Me = Me

local function Record()
    local me = Me()
    if not me or not ns.db then return nil end
    ns.db.inventory = ns.db.inventory or {}
    local rec = ns.db.inventory[me]
    if not rec then
        rec = { bags = {}, bank = {}, money = 0 }
        ns.db.inventory[me] = rec
    end
    local _, class = UnitClass("player")
    rec.class = ns.Plain(class) or rec.class
    local level = ns.Plain(UnitLevel and UnitLevel("player"))
    if type(level) == "number" and level > 0 then rec.level = level end
    local faction = UnitFactionGroup and ns.Plain((UnitFactionGroup("player")))
    if type(faction) == "string" and faction ~= "" then rec.faction = faction end
    return rec
end

-- What you wear, slot by slot: the item's string out of its link (enchant and suffix kept: an "of the Bear"
-- is only known by them)
local function Worn()
    local out = {}
    for slot = 1, 19 do
        local ok, link = pcall(GetInventoryItemLink, "player", slot)
        link = ok and ns.Plain(link)
        local item = type(link) == "string" and link:match("(item:[%-%d:]+)")
        if item then out[slot] = item end
    end
    return out
end
I.Worn = Worn

---------------------------------------------------------------------------
-- Which bags are which
---------------------------------------------------------------------------
local function CarriedBags()
    local list = {}
    for bag = 0, (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) do list[#list + 1] = bag end
    return list
end

local function BankBags()
    local list = { BANK_CONTAINER or -1 }
    local first = (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) + 1
    for bag = first, first + (NUM_BANKBAGSLOTS or 7) - 1 do list[#list + 1] = bag end
    if REAGENTBANK_CONTAINER then list[#list + 1] = REAGENTBANK_CONTAINER end
    return list
end
I.BankBags = BankBags

local function Count(bags)
    local out = {}
    for _, bag in ipairs(bags) do
        local ok, slots = pcall(C_Container.GetContainerNumSlots, bag)
        for slot = 1, (ok and slots) or 0 do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local id = info and info.itemID
            if id and not ns.IsSecret(id) then
                local n = info.stackCount
                if ns.IsSecret(n) or type(n) ~= "number" then n = 1 end
                out[id] = (out[id] or 0) + n
            end
        end
    end
    return out
end

function I:ScanBags()
    local rec = Record()
    if not rec then return end
    rec.bags = Count(CarriedBags())
    if GetInventoryItemLink then rec.worn = Worn() end
    local money = GetMoney and GetMoney()
    if type(money) == "number" and not ns.IsSecret(money) then rec.money = money end
    rec.seen = time and time() or 0
end

function I:ScanBank()
    local rec = Record()
    if not rec or not self.bankOpen then return end
    rec.bank = Count(BankBags())
end

---------------------------------------------------------------------------
-- Counts in an item's tooltip
---------------------------------------------------------------------------
local function ClassName(who, class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    local short = who:match("^([^-]+)") or who
    if c then return ("|cff%02x%02x%02x%s|r"):format(c.r * 255, c.g * 255, c.b * 255, short) end
    return short
end

-- The lines for one item: { { left, right }, ... }, short: "Bag x26  Bank x40", and on the first line the total
-- across your characters when others hold some too: "(x80)"
local BAG, BANK, SUM = "|cffffffff", "|cff8fd0ff", "|cffffd24a"
local function Where(bags, bank)
    local parts = {}
    if bags > 0 then parts[#parts + 1] = L["Bag"] .. " " .. BAG .. "x" .. bags .. "|r" end
    if bank > 0 then parts[#parts + 1] = L["Bank"] .. " " .. BANK .. "x" .. bank .. "|r" end
    return table.concat(parts, "  ")
end

function I.Lines(id)
    local all = ns.db and ns.db.inventory
    if not all or not id then return {} end
    local me = Me()
    local lines, total = {}, 0
    local function add(who, rec, mine)
        local bags, bank = rec.bags[id] or 0, rec.bank[id] or 0
        if bags + bank == 0 then return end
        total = total + bags + bank
        lines[#lines + 1] = { mine and L["You"] or ClassName(who, rec.class), Where(bags, bank) }
    end
    if me and all[me] then add(me, all[me], true) end
    local others = {}
    for who in pairs(all) do if who ~= me then others[#others + 1] = who end end
    table.sort(others)
    for _, who in ipairs(others) do add(who, all[who], false) end
    if #lines > 1 then lines[1][2] = lines[1][2] .. "  " .. SUM .. "(x" .. total .. ")|r" end
    return lines
end

-- (they hang under the tooltip on a panel of ours, Tooltip.lua: nothing is added to the game's tooltip)
local function OnItem(tooltip, data)
    if not tooltip or not (ns.Tooltip and ns.Tooltip.Annex) then return end
    local id = data and data.id
    local lines = {}
    -- not under the comparison tooltips beside it (what you wear): one panel, under the item pointed at
    local okN, name = pcall(tooltip.GetName, tooltip)
    name = okN and ns.Plain(name)
    local comparing = type(name) == "string" and name:find("ShoppingTooltip", 1, true) ~= nil
    if I.active and id and not ns.IsSecret(id) and not comparing then
        local prices, advice = {}, {}
        if ns.Market then prices, advice = ns.Market.TipLines(id, tooltip) end      -- what it costs, what it is worth
        for _, l in ipairs(prices) do lines[#lines + 1] = l end
        if ns.db.invTotals then
            for _, l in ipairs(I.Lines(id)) do lines[#lines + 1] = l end           -- how many you have, and where
        end
        if ns.TransmogSets then                                                    -- its look: in your collection yet?
            for _, l in ipairs(ns.TransmogSets.TipLines(data)) do lines[#lines + 1] = l end
        end
        local stats = ns.Stats and ns.Stats.Lines(tooltip) or {}                   -- what its stats are worth to you
        if #stats > 0 then
            if #lines > 0 then lines[#lines + 1] = { "" } end
            for _, l in ipairs(stats) do lines[#lines + 1] = l end
        end
        if #advice > 0 then
            if #lines > 0 then lines[#lines + 1] = { "" } end                       -- the advice, apart
            for _, l in ipairs(advice) do lines[#lines + 1] = l end
        end
    end
    ns.Tooltip.Annex(tooltip, lines)
end

---------------------------------------------------------------------------
-- Sorting: the game's own
---------------------------------------------------------------------------
-- Where the cursor is: "bank" when it points into the bank's window, "bags" in your bags, nil elsewhere
local function InFrame(frame, names)
    for _ = 1, 12 do
        if type(frame) ~= "table" then return false end
        local ok, name = pcall(frame.GetName, frame)
        if ok and type(name) == "string" then
            for _, n in ipairs(names) do if name:find(n, 1, true) == 1 then return true end end
        end
        frame = frame.GetParent and frame:GetParent()
    end
    return false
end
local BANK_FRAMES = { "BankFrame", "BankPanel", "AccountBank", "ReagentBank", "BankSlotsFrame" }
local BAG_FRAMES = { "ContainerFrame", "CombinedBags" }
function I.Focus()
    local frame
    if GetMouseFoci then local f = GetMouseFoci(); frame = f and f[1]
    elseif GetMouseFocus then frame = GetMouseFocus() end
    if InFrame(frame, BANK_FRAMES) then return "bank" end
    if InFrame(frame, BAG_FRAMES) then return "bags" end
end

-- The bank: the game's current way (the bank tab you are on: your character's or your account's), else the
-- older calls. Says so when this client has neither.
function I.SortBank()
    local CC = C_Container
    if CC.SortBank and Enum and Enum.BankType then
        local kind = Enum.BankType.Character
        local panel = _G.BankPanel or (_G.BankFrame and rawget(_G.BankFrame, "BankPanel"))
        if panel and panel.GetActiveBankType then
            local ok, t = pcall(panel.GetActiveBankType, panel)
            if ok and t ~= nil then kind = t end
        end
        local ok = pcall(CC.SortBank, kind)
        if ok then return true end
    end
    local any = false
    for _, name in ipairs({ "SortBankBags", "SortReagentBankBags", "SortAccountBankBags" }) do
        if CC[name] and pcall(CC[name]) then any = true end
    end
    if not any then ns.Say(L["This client's bank cannot be sorted from here."]) end
    return any
end

-- The item IDs in your bank right now (while it is open, or live: the caller knows it is), else as last seen:
-- { [itemID] = count }
function I.BankIds(live)
    if live or I.bankOpen then return Count(BankBags()) end
    local rec = Record()
    return rec and rec.bank or {}
end

-- Sorts what the cursor points at. With the bank open: the bank, unless the cursor is in your bags (the
-- controller's cursor does not always tell us where it is, so the bank is the default there); pressing again
-- within a few seconds sorts your bags too. Says what it sorted.
local AGAIN = 3
function I:Sort()
    local sort = C_Container and C_Container.SortBags
    if not sort then ns.Say(L["This client has no bag sorting."]); return false end
    local now = GetTime and GetTime() or 0
    local focus = I.Focus()
    local again = self.bankSortedAt and now - self.bankSortedAt < AGAIN
    if self.bankOpen and focus ~= "bags" and not (again and focus == nil) then
        if not I.SortBank() then return false end
        self.bankSortedAt = now
        ns.Say(focus == "bank" and L["Bank sorted."] or L["Bank sorted. Press again to sort your bags."])
        return true
    end
    self.bankSortedAt = nil
    sort()
    ns.Say(L["Bags sorted."])
    return true
end
function ControllerCamHUD_Sort() ns.Protect(function() I:Sort() end)() end
BINDING_NAME_CCHUD_SORT = L["Sort your bags (and the bank while it is open)"]

ns.RegisterCommand("sort", function() I:Sort() end, "/cchud sort", "sort your bags, and the bank while it is open")

ns.RegisterCommand("gold", function()
    local all = ns.db.inventory or {}
    local names, total = {}, 0
    for who in pairs(all) do names[#names + 1] = who end
    table.sort(names, function(a, b) return (all[a].money or 0) > (all[b].money or 0) end)
    for _, who in ipairs(names) do
        local money = all[who].money or 0
        total = total + money
        print(("  %s: %s"):format(ClassName(who, all[who].class), ns.Money(money)))
    end
    ns.Say(L["Gold on this account: %s"]:format(ns.Money(total)))
end, "/cchud gold", "list the gold on each of your characters, and the total")

---------------------------------------------------------------------------
-- The right stick button, while a bag window is open: it moves the item you point at (at the bank, a vendor,
-- in a trade, at the mailbox), and sorts when you point at nothing. Only while those windows are open, and
-- never in a fight: the rest of the time R3 does what you have it do. L3 is never taken: it is your auto-run.
---------------------------------------------------------------------------
ns.RegisterSetting({
    key = "padSort", kind = "boolean", default = true, command = "padsort", section = "Bags, bank and vendor",
    label = "R3 sorts while your bags are open",
    tip = "while your bags or the bank are open, the right stick button sorts them (it does its usual job otherwise)",
})
ns.RegisterSetting({
    key = "padMove", kind = "boolean", default = true, command = "padmove", section = "Bags, bank and vendor",
    label = "R3 moves the item you point at (bank, vendor, trade, mailbox)",
    tip = "while one of those is open, the right stick button moves the item you point at: into or out of the bank, sold, into the trade, or onto the letter. Pointing at nothing, it sorts",
})
I.KEY = "PADRSTICK"

local owner = CreateFrame("Frame")
local function BagsOpen()
    local combined = _G.ContainerFrameCombinedBags
    if combined and combined:IsShown() then return true end
    for i = 1, (NUM_CONTAINER_FRAMES or 13) do
        local f = _G["ContainerFrame" .. i]
        if f and f:IsShown() then return true end
    end
    local bank = _G.BankFrame
    return bank and bank:IsShown() and true or false
end

function I:Keys()
    local V = ns.Vendor
    -- (the HUD's bag window with the controller: R3 is its own there, the game's tooltip switch as in the game's
    -- bags; sorting is in its Y, moving is its X)
    local B = ns.Bags
    local theirs = B and B.active and B.open and B.hasPad and true or false
    local sort = self.active and ns.db.padSort and BagsOpen() and not theirs or false
    local move = self.active and ns.db.padMove and V and V:MoveOpen() and not theirs or false
    if sort == self.sortKey and move == self.moveKey then return end
    if InCombatLockdown() then return end             -- bindings change only out of a fight: next look
    if ns.KeyHeld(I.KEY) then return end              -- (R3 held: once it is let go, the next look)
    self.sortKey, self.moveKey = sort, move
    ClearOverrideBindings(owner)
    if move then SetOverrideBindingClick(owner, true, I.KEY, "ControllerCamHUD_StickKey", "LeftButton")
    elseif sort then SetOverrideBinding(owner, true, I.KEY, "CCHUD_SORT") end
end

-- R3 where things can be moved: the item you point at moves; pointing at nothing, the bags are sorted
function I:Stick()
    local V = ns.Vendor
    if self.moveKey and V and V.Pointed() then return V:QuickMove() end
    if self.sortKey then return self:Sort() end
    if V then return V:QuickMove() end                -- (says to point at an item)
end
local stick = CreateFrame("Button", "ControllerCamHUD_StickKey", UIParent)
stick:SetScript("OnClick", ns.Protect(function() I:Stick() end))

local since = 0
owner:SetScript("OnUpdate", ns.Protect(function(_, dt)
    since = since + dt
    if since < 0.25 then return end
    since = 0
    I:Keys()
end))

---------------------------------------------------------------------------
-- Listening
---------------------------------------------------------------------------
local pending = false
local function Soon()
    if pending then return end
    pending = true
    C_Timer.After(0.3, function()
        pending = false
        local ok, err = pcall(function() I:ScanBags(); I:ScanBank() end)
        if not ok then ns.Error(err) end
    end)
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", ns.Protect(function(_, event)
    if event == "BANKFRAME_OPENED" then I.bankOpen = true
    elseif event == "BANKFRAME_CLOSED" then I:ScanBank(); I.bankOpen = false; I.bankSortedAt = nil; return end
    Soon()
end))

local listening = false
function I:Apply(run)
    -- what you carry is noted whenever the addon is loaded (the counts stay right for your other characters);
    -- the counts show in tooltips while the HUD runs
    if not self.watching then
        self.watching = true
        for _, e in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_MONEY", "BANKFRAME_OPENED", "BANKFRAME_CLOSED",
                             "PLAYERBANKSLOTS_CHANGED", "PLAYERREAGENTBANKSLOTS_CHANGED", "PLAYER_ENTERING_WORLD",
                             "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP" }) do
            pcall(events.RegisterEvent, events, e)
        end
        Soon()
    end
    self.active = run and true or false
    if self.active and not listening and TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
        and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
        listening = true
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, ns.Protect(OnItem))
    end
end

ns.RegisterModule("inventory", I)
