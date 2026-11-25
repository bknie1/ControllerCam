-- ControllerCam HUD: your bags in one window, made for the controller.
-- In place of the game's bag windows (the Gamepad UI's "Combined Backpack", or a window for each bag), while the
-- HUD runs and the setting is on:
--   * one grid of everything you carry, in the order of your bags (the game's own sorting decides it); the empty
--     slots gathered at the end as one slot that counts them (one for each kind of bag: a quiver's, a herb
--     bag's); your bags in a row of their own under the grid, never in among the items.
--   * quick filters along the top, LB and RB: All, Equipment, Consumables, Trade goods, Quest, Junk, New, and the
--     HUD's own advice (Market.lua): Sell (what a vendor or the auction house should have) and Keep.
--   * the d-pad moves; X uses the item (at a vendor it sells, at the bank it moves, at the mailbox it attaches);
--     A picks it up and puts it down again (onto another slot, an empty one, or a bag in the bag row); Y for more
--     (split a stack, mark it, its details, sorting, the bank); B closes. On the bag row, X shows that bag alone
--     (again: all of them), A puts what you hold into it, or picks the bag up to swap it. While the bank is open,
--     the back button (or Y) shows the bank in the same window. With another window open beside it (a vendor, the
--     bank, the mailbox), LT or RT hands the controller to that window and back.
--   * the mouse: right click uses, left click or a drag picks up and puts down, Shift + left click links.
--
-- How, and why this way rather than dressing up the game's combined window:
--   * Every slot shows one of the game's own item buttons (ContainerFrameItemButtonTemplate: icon, count,
--     quality, cooldown, the game's tooltip), made once for its bag and slot. Its own click never runs: it was set
--     up by our code, so it would act in the HUD's name, and the game refuses a use made that way.
--   * Using an item is protected. It goes through the game's secure item button (SecureActionButtonTemplate,
--     item "<bag> <slot>", set out of combat): X's binding presses it, and the mouse presses a secure cover put
--     over the slot it points at. Nothing of ours ever uses an item; picking up is the game's plain call.
--   * The game's bag windows still open and close as ever, under a hidden parent (as the HUD puts the player
--     frame aside): open, they are never on screen, so the game never lays them out and the Gamepad UI's cursor
--     never goes to them. Ours opens and closes with them. B is the game's own "open all bags" binding while its
--     combined window is open: the game closes it, and ours goes with it.
--   * The game's combined window lays its slots out again on every change, with the bags among them, and steers
--     the Gamepad UI's cursor over them by that layout. Moving its slots, hiding the empty ones and filtering
--     would mean writing over the game's frames while its code works on them, which can get what the game does
--     next refused. A window of our own over the game's buttons does none of that.
--   * In a fight the window stays open, as the game's does, but takes no buttons: your controller is yours. Its
--     buttons come back when the fight ends.

local ADDON = ...
local ns = ControllerCamHUD.ns            -- the HUD's own namespace: this file is one of its modules (Modules.lua)
local L, C = ns.L, ns.colors

local B = { active = false, open = false, view = "bags", filter = 1, index = 1, scroll = 0, zone = "grid",
            bagIndex = 1, hasPad = true, buttons = {}, holders = {}, slotOf = {}, at = {}, bagList = {},
            verdicts = {}, bound = {}, list = {}, counts = {}, triggerWas = true,
            extra = setmetatable({}, { __mode = "k" }), kind = setmetatable({}, { __mode = "k" }) }
ns.Bags = B

-- Where you dragged the window: its bottom right corner from the screen's
ns.RegisterSaved("bagPos", function(old)
    if type(old) == "table" and tonumber(old.x) and tonumber(old.y) then return { x = tonumber(old.x), y = tonumber(old.y) } end
    return nil
end)

B.COLS, B.SIZE, B.GAP, B.PAD = 10, 37, 4, 12
B.STEP = B.SIZE + B.GAP
B.TOP = 72                                     -- where the grid begins (under the title and the filters)
B.BAG = B.SIZE                                 -- a bag in the bag row: a slot's size, in the grid's columns
B.RULE = 9                                     -- grid, rule, bags: the space either side of the rule
B.KEYS = { "PADDUP", "PADDDOWN", "PADDLEFT", "PADDRIGHT", "PAD1", "PAD2", "PAD3", "PAD4", "PADLSHOULDER",
           "PADRSHOULDER", "PADRSTICK", "PADBACK" }   -- (R3: a quick sort)        -- (the back button only while the bank is open)
B.SWITCH = { "PADLTRIGGER", "PADRTRIGGER" }    -- read, never bound: they are the Gamepad UI's Shift and Ctrl
-- Windows the controller can be handed to and back (LT / RT)
B.OTHER = { "MerchantFrame", "BankFrame", "MailFrame", "TradeFrame", "AuctionHouseFrame", "AuctionFrame",
            "GuildBankFrame", "CharacterFrame", "LootFrame" }

B.FILTERS = {
    { key = "all", text = L["All"] },
    { key = "equipment", text = L["Equipment"] },
    { key = "consumable", text = L["Consumables"] },
    { key = "trade", text = L["Trade goods"] },
    { key = "quest", text = L["Quest"] },
    { key = "junk", text = L["Junk"] },
    { key = "new", text = L["New"] },
    { key = "sell", text = L["Sell"] },
    { key = "keep", text = L["Keep"] },
}
-- The Market's verdicts (M.Verdict) under Sell and Keep
B.SOLD = { vendor = true, auction = true }
B.KEPT = { keep = true, equip = true, skill = true, craft = true, quest = true }

local GREY, GOLD = "|cff9aa3b5", "|cffffd25a"

local function Pass(ok, ...) if ok then return ... end end
local function Try(fn, ...)
    if type(fn) ~= "function" then return nil end
    return Pass(pcall(fn, ...))
end
local function Num(v) v = ns.Plain(v); return type(v) == "number" and v or nil end
local function Str(v) v = ns.Plain(v); return (type(v) == "string" and v ~= "") and v or nil end
local function Shown(f) return type(f) == "table" and type(f.IsShown) == "function" and Try(f.IsShown, f) == true end
local function Showing(r, on) if on then r:Show() else r:Hide() end end

---------------------------------------------------------------------------
-- What you carry
---------------------------------------------------------------------------
-- What you carry
---------------------------------------------------------------------------
-- How the window orders what you carry (each filter keeps the order)
ns.RegisterSetting({
    key = "bagOrder", kind = "number", default = 1, min = 1, max = 3, command = "bagorder",
    section = "Bags, bank and vendor",
    choices = { "Smart", "By type", "As in your bags" },
    label = "Bag window: order",
    tip = "Smart: what you use first (consumables, items with a use), then the rest by kind, junk last and faded. By type: in sections under their own headings. As in your bags: the game's own order",
    onChange = function() if B.open then B.verdicts = {}; B:Update() end end,
})
B.ORDER_NAMES = { L["Smart"], L["By type"], L["As in your bags"] }
B.ORDERS = { "smart", "type", "bags" }
function B.OrderMode() return B.ORDERS[ns.db and tonumber(ns.db.bagOrder) or 1] or "smart" end

-- What an item is, for the filters, by its class (Enum.ItemClass): weapons and armor are equipment; potions,
-- food, scrolls, ammunition and enchantments consumables; cloth, ore, herbs, gems, reagents and recipes trade
-- goods; quest items are the quest's.
function B.Kind(classID)
    if classID == 2 or classID == 4 then return "equipment" end
    if classID == 0 or classID == 6 or classID == 8 then return "consumable" end
    if classID == 3 or classID == 5 or classID == 7 or classID == 9 then return "trade" end
    if classID == 12 then return "quest" end
    return "other"
end

local function Slots(bag) return Num(Try(C_Container.GetContainerNumSlots, bag)) or 0 end
local function Family(bag)
    local _, family = Try(C_Container.GetContainerNumFreeSlots, bag)
    return Num(family) or 0
end

-- The keyring of the older clients: in the bag row, its keys only shown while it is chosen there
function B.Keyring()
    local id = rawget(_G, "KEYRING_CONTAINER")
    if type(id) == "number" and Slots(id) > 0 then return id end
end

-- The containers of a view: your bags (the backpack first), or the bank's
function B.Containers(view)
    if view == "bank" then
        local I = ns.Inventory
        return I and I.BankBags and I.BankBags() or { rawget(_G, "BANK_CONTAINER") or -1 }
    end
    local list = {}
    for bag = 0, (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) do list[#list + 1] = bag end
    return list
end

local function Instant(id)
    local get = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    local _, _, _, equipLoc, _, classID, subclassID = Try(get, id)
    return Num(classID), Str(equipLoc), Num(subclassID)
end

-- Does it have a "Use:" (a potion, food, a scroll, an on-use trinket, the hearthstone, a quest item you click)?
local function HasUse(id)
    local get = (C_Item and C_Item.GetItemSpell) or rawget(_G, "GetItemSpell")
    return Try(get, id) ~= nil
end

-- One slot: what is in it ({ bag, slot, id, count, quality, link, icon, locked, bound, kind, quest, questStart,
-- use, new, name }), or nil
function B.Slot(bag, slot)
    local info = Try(C_Container.GetContainerItemInfo, bag, slot)
    local id = type(info) == "table" and Num(info.itemID)
    if not id then return nil end
    local e = { bag = bag, slot = slot, id = id, count = Num(info.stackCount) or 1, quality = Num(info.quality),
                link = Str(info.hyperlink), icon = ns.Plain(info.iconFileID), locked = ns.Yes(info.isLocked),
                bound = ns.Yes(info.isBound) }
    e.classID, e.equipLoc, e.subclassID = Instant(id)
    e.kind = B.Kind(e.classID)
    e.use = HasUse(id)
    local q = C_Container.GetContainerItemQuestInfo and Try(C_Container.GetContainerItemQuestInfo, bag, slot)
    local questID = type(q) == "table" and Num(q.questID) or nil
    e.quest = e.kind == "quest" or (type(q) == "table" and (ns.Yes(q.isQuestItem) or questID ~= nil)) or false
    e.questStart = questID ~= nil and not ns.Yes(q.isActive)          -- (a quest it starts, not yet taken)
    if C_NewItems and Try(C_NewItems.IsNewItem, bag, slot) == true then e.new = true end
    if e.icon == nil and C_Item and C_Item.GetItemIconByID then e.icon = Try(C_Item.GetItemIconByID, id) end
    local name = e.link and e.link:match("%[(.-)%]")
    e.name = (name or ""):lower()
    return e
end

-- Everything in a view: { items = { slot entries in bag order }, empty = { { bag, slot, family, empty } } (the
-- general bags' first), free = { { bag, slot (the first empty one), free = how many, family } }, bags = { { bag,
-- size, used } }, total, used }. only: one bag's alone.
function B.Read(view, only)
    local out = { items = {}, free = {}, empty = {}, bags = {}, total = 0, used = 0 }
    local byFamily, special = {}, {}
    local bags = B.Containers(view)
    local keyring = view ~= "bank" and B.Keyring()
    if keyring then bags[#bags + 1] = keyring end
    do  -- ordinary bags first, then the specialised ones (ammo, herbs, a profession's), the keyring last
        local ranked = {}
        for i, bag in ipairs(bags) do
            ranked[i] = { bag = bag, i = i, rank = (bag == keyring) and 3 or (Family(bag) ~= 0 and 2 or 1) }
        end
        table.sort(ranked, function(a, b) if a.rank ~= b.rank then return a.rank < b.rank end return a.i < b.i end)
        bags = {}
        for i, r in ipairs(ranked) do bags[i] = r.bag end
    end
    for _, bag in ipairs(bags) do
        local size = Slots(bag)
        if size > 0 then
            local rec = { bag = bag, size = size, used = 0, keyring = bag == keyring or nil }
            out.bags[#out.bags + 1] = rec
            local take = (only == nil and not rec.keyring) or only == bag
            local family = Family(bag)
            for slot = 1, size do
                local e = B.Slot(bag, slot)
                if e then
                    rec.used = rec.used + 1
                    if take then out.items[#out.items + 1] = e end
                elseif take then
                    local spot = { bag = bag, slot = slot, family = family, empty = true }
                    if family == 0 then out.empty[#out.empty + 1] = spot else special[#special + 1] = spot end
                    local tile = byFamily[family]
                    if not tile then
                        tile = { bag = bag, slot = slot, free = 0, family = family }
                        byFamily[family] = tile
                        out.free[#out.free + 1] = tile
                    end
                    tile.free = tile.free + 1
                end
            end
            if not rec.keyring then out.total, out.used = out.total + size, out.used + rec.used end
        end
    end
    for _, spot in ipairs(special) do out.empty[#out.empty + 1] = spot end   -- (a quiver's, a herb bag's: after)
    return out
end

---------------------------------------------------------------------------
-- The filters, the order, the sections
---------------------------------------------------------------------------
-- The Market's verdict on an item (cached while the bags stay as they are)
function B.Verdict(e)
    local key = e.id .. (e.bound and ":b" or "")
    local v = B.verdicts[key]
    if v == nil then
        local M = ns.Market
        v = (M and M.Verdict and Try(M.Verdict, e.id, e.bound)) or false
        B.verdicts[key] = v
    end
    return v or nil
end

-- Junk: what you marked as junk; grey (unless you marked it to keep); and what the HUD's advice sends to a
-- vendor, but only once the auction house has had its say (its prices known): before that the advice is a
-- vendor for want of a price, and cloth or a green the house would pay for is never faded for that. Never a quest
-- item, or anything you marked to keep.
function B.IsJunk(e)
    local sell = ns.db and ns.db.sell
    if sell and sell.junk[e.id] then return true end
    if sell and sell.keep[e.id] then return false end
    if e.quest then return false end
    if e.quality == 0 then return true end
    local M = ns.Market
    if M and M.HasData and Try(M.HasData) == true then return B.Verdict(e) == "vendor" end
    return false
end
-- (worked out once an item while the bags stay as they are)
function B.Junk(e)
    if e.junk == nil then e.junk = B.IsJunk(e) and true or false end
    return e.junk
end

function B.Matches(e, key)
    if key == "all" then return true end
    if key == "junk" then return B.Junk(e) end
    if key == "new" then return e.new == true end
    if key == "quest" then return e.quest == true end
    if key == "sell" then return B.SOLD[B.Verdict(e) or ""] == true end
    if key == "keep" then return B.KEPT[B.Verdict(e) or ""] == true end
    return e.kind == key
end

-- The smart order: what you use first (consumables, anything with a use), then the rest, junk last; each by
-- kind, then name, then where it is (so nothing moves about while the bags stay as they are)
B.FIRST = { [6948] = true }    -- the Hearthstone: always the first of all
local function Group(e)
    if B.FIRST[e.id] then return 0 end
    if B.Junk(e) then return 3 end
    if e.kind == "consumable" or e.use then return 1 end
    return 2
end
local function Before(a, b)
    if a.group ~= b.group then return a.group < b.group end
    local ca, cb = a.classID or 99, b.classID or 99
    if ca ~= cb then return ca < cb end
    local sa, sb = a.subclassID or 0, b.subclassID or 0
    if sa ~= sb then return sa < sb end
    if a.name ~= b.name then return a.name < b.name end
    if a.bag ~= b.bag then return a.bag < b.bag end
    return a.slot < b.slot
end
function B.Order(items)
    for _, e in ipairs(items) do e.group = Group(e) end
    table.sort(items, Before)
    return items
end

-- By type: the sections, in this order, each under its heading
B.SECTIONS = {
    { key = "consumable", text = L["Consumables"] }, { key = "equipment", text = L["Equipment"] },
    { key = "trade", text = L["Trade goods"] }, { key = "quest", text = L["Quest"] },
    { key = "reagent", text = L["Reagents"] }, { key = "other", text = L["Other"] },
    { key = "junk", text = L["Junk"] },
}
function B.SectionOf(e)
    if B.Junk(e) then return "junk" end
    if e.quest then return "quest" end
    if e.classID == 5 then return "reagent" end
    if e.kind == "consumable" or e.kind == "equipment" or e.kind == "trade" then return e.kind end
    return "other"
end

-- What the grid shows under a filter, in the order chosen: the list, and its sections ({ text = heading or
-- nil, first, last, count }). The empty slots come last: after the items, or under their own heading by type.
function B.List(read, key, mode)
    local list, sections, matched = {}, {}, {}
    for _, e in ipairs(read.items) do
        if B.Matches(e, key) then matched[#matched + 1] = e end
    end
    local function section(text, entries)
        if #entries == 0 then return end
        local s = { text = text, first = #list + 1, count = #entries }
        for _, e in ipairs(entries) do list[#list + 1] = e end
        s.last = #list
        sections[#sections + 1] = s
        return s
    end
    if #matched == 0 then
        sections[1] = { text = L["Nothing here."], first = 1, last = 0, count = 0, muted = true }
    elseif mode == "type" then
        local by = {}
        for _, e in ipairs(matched) do
            local k = B.SectionOf(e)
            by[k] = by[k] or {}
            by[k][#by[k] + 1] = e
        end
        for _, s in ipairs(B.SECTIONS) do section(s.text, by[s.key] or {}) end
    else
        section(nil, matched)
    end
    local empty = read.empty or {}
    if #empty > 0 then
        local last = sections[#sections]
        if mode ~= "type" and last and not last.text and last.count > 0 then
            for _, e in ipairs(empty) do list[#list + 1] = e end      -- (on along the same rows)
            last.last = #list
        else
            section(mode == "type" and L["Empty slots"] or nil, empty)
        end
    end
    return list, sections
end

-- How many items each filter has: { [key] = n }
function B.Counts(read)
    local out = {}
    for _, f in ipairs(B.FILTERS) do
        local n = 0
        for _, e in ipairs(read.items) do if B.Matches(e, f.key) then n = n + 1 end end
        out[f.key] = n
    end
    return out
end

---------------------------------------------------------------------------
-- Moving about
---------------------------------------------------------------------------
B.HEAD = 22                                    -- a section's heading: its line's height

-- Where everything sits: lines from the top ({ kind = "head", sec } or { kind = "row", first, count }, each with
-- its y and height), and for each slot its line and column
function B.Model(list, sections, cols)
    local lines, pos, y = {}, {}, 0
    for _, s in ipairs(sections) do
        local head
        if s.text then
            head = { kind = "head", sec = s, y = y, h = B.HEAD }
            lines[#lines + 1] = head
            y = y + B.HEAD
        end
        local i = s.first
        while i <= s.last do
            local count = math.min(cols, s.last - i + 1)
            lines[#lines + 1] = { kind = "row", first = i, count = count, y = y, h = B.STEP,
                                  head = (i == s.first) and head or nil }
            for k = 0, count - 1 do pos[i + k] = { line = #lines, col = k } end
            i = i + count
            y = y + B.STEP
        end
    end
    local last = lines[#lines]
    return { lines = lines, pos = pos, height = last and (last.kind == "row" and y - B.GAP or y) or 0 }
end

-- Where the d-pad goes from slot i: the new slot, or "bags" (down from the last row, to the bag row). Up and down
-- go row by row, across the sections' headings, to the same column (or the row's last slot); left and right run on
-- into the row (and the section) before or after.
function B.StepModel(model, i, way, n)
    if n <= 0 then return way == "down" and "bags" or 1 end
    if way == "left" then return math.max(1, i - 1) end
    if way == "right" then return math.min(n, i + 1) end
    local p = model.pos[i]
    if not p then return 1 end
    local dir = way == "up" and -1 or 1
    local li = p.line + dir
    while model.lines[li] and model.lines[li].kind ~= "row" do li = li + dir end
    local line = model.lines[li]
    if not line then return way == "down" and "bags" or i end
    return line.first + math.min(p.col, line.count - 1)
end

-- The same for one plain grid of n slots
function B.Step(i, way, n, cols)
    local list = {}
    for k = 1, n do list[k] = k end
    return B.StepModel(B.Model(list, { { first = 1, last = n } }, cols), i, way, n)
end

-- How many rows of slots fit on the screen
function B.Rows()
    local h = Num(Try(UIParent.GetHeight, UIParent)) or 768
    return ns.Clamp(math.floor((h * 0.7 - 190) / B.STEP), 3, 12)
end

---------------------------------------------------------------------------
-- The game's bag windows
---------------------------------------------------------------------------
function B.GameFrames()
    local list = { "ContainerFrameCombinedBags" }
    for i = 1, (NUM_CONTAINER_FRAMES or 13) do list[#list + 1] = "ContainerFrame" .. i end
    return list
end

-- Is one of the game's bag windows open? (open under our hidden parent: shown, never on screen)
function B.GameOpen()
    for _, name in ipairs(B.GameFrames()) do
        if Shown(rawget(_G, name)) then return true end
    end
    return false
end

-- Another window open beside the bags, the one LT / RT hands the controller to. The Gamepad UI's own list of
-- the windows it steers is read too, never changed.
function B.OtherWindow()
    for _, name in ipairs(B.OTHER) do
        local f = rawget(_G, name)
        if Shown(f) then return f end
    end
    local mode = rawget(_G, "GamepadMode")
    local manager = type(mode) == "table" and rawget(mode, "FrameControlsManager")
    local list = type(manager) == "table" and rawget(manager, "shownFrames")
    if type(list) == "table" then
        local bags = {}
        for _, name in ipairs(B.GameFrames()) do bags[rawget(_G, name) or bags] = true end
        for _, f in ipairs(list) do
            if not bags[f] and Shown(f) then return f end
        end
    end
end

-- The Gamepad UI's window manager (read, never changed or called: calling it from addon code taints the game's
-- own window closing), and where its focus is: the frame, and whether there is a manager to ask at all
local function Manager()
    local mode = rawget(_G, "GamepadMode")
    local m = type(mode) == "table" and rawget(mode, "FrameControlsManager")
    return type(m) == "table" and m or nil
end
function B.GameFocus()
    local m = Manager()
    if not m then return nil, false end
    local f = rawget(m, "focusedFrame")
    return type(f) == "table" and f or nil, true
end
function B.IsGameBag(f)
    if type(f) ~= "table" then return false end
    for _, name in ipairs(B.GameFrames()) do
        if f == rawget(_G, name) then return true end
    end
    return false
end
-- Is this a window the controller can be handed to: one of B.OTHER, or one in the manager's row (not the bags)
function B.IsWindow(f)
    if type(f) ~= "table" or B.IsGameBag(f) or not Shown(f) then return false end
    for _, name in ipairs(B.OTHER) do
        if f == rawget(_G, name) then return true end
    end
    local m = Manager()
    local list = m and rawget(m, "shownFrames")
    for _, g in ipairs(type(list) == "table" and list or {}) do
        if g == f then return true end
    end
    return false
end

-- The bank in this window (with "One bag window" on): while the bank is open the game's bank window is put out of
-- sight (into a hidden holder, so the Gamepad UI's cursor can't rest there and take every button for itself), and
-- this window is the bank: its items with X, Y and A as your bags have them, LT for the bank, RT for your bags.
-- The bank stays open (the game's window only closes it when it really hides), and closes with this window. Put
-- back as the bank closes. Never begun in a fight (the game's own bank window then, as ever).
B.holder = CreateFrame("Frame")
B.holder:Hide()
function B.HostBank(on)
    local bank = rawget(_G, "BankFrame")
    if type(bank) ~= "table" then return false end
    if on then
        if B.hosting or InCombatLockdown() or not (B.active and ns.db.bagWindow) then return false end
        if not B.hideGuard then
            local was = Try(bank.GetScript, bank, "OnHide")
            B.hideGuard = true
            Try(bank.SetScript, bank, "OnHide", function(self, ...)
                if B.hosting then return end                 -- (out of sight by us: the bank stays open)
                if was then return was(self, ...) end
            end)
        end
        B.bankParent = Try(bank.GetParent, bank) or UIParent
        B.hosting = true
        Try(bank.SetParent, bank, B.holder)
        -- out of sight is not enough: shown, the Gamepad UI's cursor still starts on it and keeps every button.
        -- Put away as B would (the bank stays open: its hiding closes nothing while it's ours), now and once
        -- the game is done showing it
        B.PutBankAway()
        C_Timer.After(0, B.PutBankAway)
        C_Timer.After(0.2, B.PutBankAway)
        ns.Note("bags: the bank is in the bag window")
        return true
    elseif B.hosting then
        B.hosting = false
        Try(bank.SetParent, bank, B.bankParent or UIParent)
        B.bankParent = nil
        ns.Note("bags: the game's bank window back")
    end
    return false
end

function B.PutBankAway()
    local bank = rawget(_G, "BankFrame")
    if not (B.hosting and B.bankOpen) or InCombatLockdown() or type(bank) ~= "table" or not Shown(bank) then return end
    local hide = rawget(_G, "HideUIPanel")
    if hide then Try(hide, bank) end                         -- (the game's own way: its window list kept right)
    if Shown(bank) then Try(bank.Hide, bank) end
    ns.Note("bags: the game's bank window put away (its cursor with it)")
end

-- The bank slot the game's own cursor is on, while its bank window has the controller: { bag, slot } or nil.
-- (The game shows that slot's tooltip: its owner is the slot's button, inside the game's bank window.)
function B.GameBankPick()
    local bank = rawget(_G, "BankFrame")
    if not Shown(bank) then return nil end
    local owner = Try(GameTooltip.GetOwner, GameTooltip)
    if type(owner) ~= "table" or not Shown(GameTooltip) then return nil end
    local f, inside = owner, false
    for _ = 1, 8 do
        if f == bank then inside = true; break end
        f = type(f) == "table" and Try(f.GetParent, f) or nil
        if not f then break end
    end
    if not inside then return nil end
    local bag = Num(Try(owner.GetBagID, owner))
    if not bag then
        local parent = Try(owner.GetParent, owner)
        bag = parent and Num(Try(parent.GetID, parent))
    end
    local slot = Num(Try(owner.GetID, owner))
    if not (bag and slot and slot > 0) then return nil end
    if not Try(C_Container.GetContainerItemID, bag, slot) then return nil end
    return { bag = bag, slot = slot }
end

-- Where the controller is, with another window open beside the bags. LT and RT are the Gamepad UI's own: they
-- move its focus along its row of open windows, and our window stands in for the game's bags in that row. So
-- ours follows the game's focus: it has the controller while the game's focus is on its (unseen) bags, and lets
-- it go while the focus is on the other window, whose own buttons then work as the game made them. A trigger
-- press that leaves the game's focus where it was (the game has no window that way, or no manager to ask) hands
-- the controller over between the two windows itself, after B.SETTLE seconds. Nothing else open: ours.
B.SETTLE = 0.15
function B:FollowFocus(now)
    local down = false
    for _, key in ipairs(B.SWITCH) do
        if IsKeyDown and IsKeyDown(key) then down = true end
    end
    local pressed = down and not self.triggerWas
    self.triggerWas = down
    local was = self.hasPad
    local focus, known = B.GameFocus()
    local bankFrame = rawget(_G, "BankFrame")
    if self.bankOpen and B.hosting then
        -- the bank in this window: the controller stays here; LT shows the bank, RT your bags
        self.hasPad, self.pressAt = true, nil
        if pressed and not InCombatLockdown() then
            local lt = IsKeyDown and IsKeyDown("PADLTRIGGER")
            local to = lt and "bank" or "bags"
            if self.view ~= to then self:SwitchView(to) end
        end
    elseif self.bankOpen and Shown(bankFrame) and known and not InCombatLockdown() then
        -- at the bank, with the Gamepad UI's window manager there: LT / RT are the game's, moving its focus
        -- between its bank window and its (unseen) bags, and a window with the game's focus takes the d-pad and
        -- A for itself, so ours could not move there. Ours follows the game's focus: the bank window's own
        -- buttons while it has it, ours (your bags) while its bags have it. The back button still shows the bank
        -- in this window.
        if focus ~= self.focusWas then
            local key = IsKeyDown and ((IsKeyDown("PADLTRIGGER") and "LT") or (IsKeyDown("PADRTRIGGER") and "RT")) or nil
            ns.Note("bags: at the bank, %s: the game's focus to %s", key or "no trigger",
                focus == bankFrame and "its bank window" or (B.IsGameBag(focus) and "its bags") or tostring(focus))
            self.focusWas = focus
            if focus == bankFrame then
                self.hasPad = false
                if self.view == "bank" then self:SwitchView("bags") end
            elseif B.IsGameBag(focus) or focus == nil then
                self.hasPad = true
            end
        end
        self.pressAt = nil
        B.BankSide(true)
        if not self.hasPad then
            self:Bind()                                      -- (X follows the game's cursor in its bank window)
            local f = rawget(B, "frame")
            if f and f.legend then f.legend:SetText(self:Legend()) end
        end
    elseif self.bankOpen and Shown(bankFrame) then
        B.BankSide(false)
        -- at the bank with no window manager to ask: LT / RT go between your bags and the bank in this window,
        -- as the back button does, and the controller stays with the window
        self.hasPad, self.pressAt = true, nil
        if pressed and not InCombatLockdown() then self:SwitchView() end
    elseif not B.OtherWindow() then
        B.BankSide(false)
        self.hasPad, self.pressAt = true, nil
    elseif not InCombatLockdown() then
        local f = focus
        local before = self.focusWas                         -- (the focus before this frame: a press may move it now)
        if known and f ~= self.focusWas then                 -- the game moved its focus: ours goes with it
            self.focusWas = f
            if B.IsGameBag(f) then self.hasPad = true
            elseif B.IsWindow(f) then self.hasPad = false end
        end
        if pressed then self.pressAt, self.pressFocus = now, before end
        if self.pressAt and now - self.pressAt >= B.SETTLE then
            if f == self.pressFocus then self.hasPad = not self.hasPad end   -- (the game moved nowhere)
            self.pressAt = nil
        end
    end
    if self.hasPad ~= was then
        self:Layout()
        if self.hasPad then self:Tip()
        elseif B.tipMine then GameTooltip:Hide(); B.tipMine = false end   -- (ours goes with it)
    end
end

-- Ours follows the game's: opened as one of the game's opens (or is asked to open: a vendor, the bank),
-- closed as they all close. kind: "toggle" (your bag key), "open", or nil (looked at each frame).
-- A bag key that closes the game's windows while ours was already closed (B, in a fight) means to open it.
function B.Follow(kind)
    if not B.active then return end
    local open = B.GameOpen()
    if open and (not B.gameWas or (kind == "open" and not B.open)) then
        B:Show()
    elseif not open and B.gameWas then
        if B.open then B:Hide() elseif kind == "toggle" then B:Show() end
    end
    B.gameWas = open
end

local hooked = false
local function Hook()
    if hooked or type(hooksecurefunc) ~= "function" then return end
    hooked = true
    local toggle = ns.Protect(function() B.Follow("toggle") end)
    local open = ns.Protect(function() B.Follow("open") end)
    -- (after the game's own: its code runs as ever, ours only looks at what it did)
    for _, name in ipairs({ "ToggleAllBags", "ToggleBackpack", "ToggleBag" }) do
        if type(rawget(_G, name)) == "function" then hooksecurefunc(name, toggle) end
    end
    for _, name in ipairs({ "OpenAllBags", "OpenBackpack", "OpenBag" }) do
        if type(rawget(_G, name)) == "function" then hooksecurefunc(name, open) end
    end
end

---------------------------------------------------------------------------
-- The slots: the game's own item buttons
---------------------------------------------------------------------------
local frame

-- The frame a bag's buttons hang from: its id is the bag's, as the game's own bag windows have it
local function Holder(bag)
    local h = B.holders[bag]
    if not h then
        h = CreateFrame("Frame", nil, frame.grid)
        h:SetID(bag)
        h:SetAllPoints(frame.grid)
        B.holders[bag] = h
    end
    return h
end

-- Using an item is protected: only the game's own secure code may do it. So a use goes through the game's
-- secure button (SecureActionButtonTemplate) with the macro "/use <bag> <slot>", its attributes set out of
-- combat, and pressed by the game itself: by X's binding, or by your mouse on the cover over the slot you point
-- at. Neither is ever clicked by code of ours. Both hang from the screen, never from our window, so the window
-- stays an ordinary one that can open and change in a fight (when the two are put away and do nothing).
local function SecureButton(name)
    local b = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
    -- (both registered, acting on the release: a press by an override binding arrives on the side of the game's
    -- key-down setting, and only one of the two acts)
    b:RegisterForClicks("AnyDown", "AnyUp")
    b:SetAttribute("useOnKeyDown", false)
    return b
end

-- X: the chosen slot's use. Shown (a binding clicks it) but never seen or pointed at.
B.SecureUse = SecureButton("ControllerCamHUD_BagUse")
-- (a macro, not the template's "item" action: that one equips anything that can be worn, by its name, before it
-- would use the slot, so at a vendor gear was put on instead of sold. "/use <bag> <slot>" uses that very slot, as
-- the game's own right click does: sold at a vendor, moved at the bank, attached at the mailbox, else used or
-- put on.)
B.SecureUse:SetAttribute("type", "macro")
B.SecureUse:SetSize(1, 1)
B.SecureUse:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -10, 10)
B.SecureUse:SetAlpha(0)
B.SecureUse:EnableMouse(false)

-- Aim X at a macro of our own (a menu row's: Equip by name where X would deposit): true when aimed
function B.AimMacro(macro)
    if InCombatLockdown() then return false end
    if B.aimed ~= macro then
        B.SecureUse:SetAttribute("macrotext", macro)
        B.aimed = macro
    end
    return macro ~= nil
end

-- Aim X at a slot (out of combat only): true when it is aimed there
function B.Aim(bag, slot)
    if InCombatLockdown() then return false end
    local value = bag and (bag .. " " .. slot) or nil
    if B.aimed ~= value then
        B.SecureUse:SetAttribute("macrotext", value and ("/use " .. value) or nil)
        B.aimed = value
    end
    return value ~= nil
end


---------------------------------------------------------------------------
-- In a fight. Bindings and attributes can't change from our code in combat, so everything the window does in a
-- fight runs in the game's restricted environment:
--   * B.Secure (SecureHandlerShowHideTemplate) owns every binding of the window. It sits on the game's combined
--     bag window (kept open in an invisible holder, B.Holder, so it truly shows and hides): when the game opens
--     its bags in a fight, its _onshow snippet binds the fight's set (d-pad, X, A, B); when they close, _onhide
--     clears them. Out of combat our own code binds and clears them, as before.
--   * The d-pad is bound to secure buttons (B.navButtons): in a fight their snippet moves the choice through the
--     table of slots we leave on B.Secure out of combat ("slot<k>" = "<bag> <slot>", "up<k>" ... = the slot that
--     way), and aims X's secure use there. Out of combat they only call the window's own code.
--   * The grid stays as it was in a fight (each slot's contents drawn afresh); it is put in order again after.
--   * Armour can't be changed in a fight: its slots aim at nothing then, and X says so. Weapons, shields and
--     off hands are equipped, potions and food used, all by the game's secure use, at once.
---------------------------------------------------------------------------
B.Secure = CreateFrame("Frame", "ControllerCamHUD_BagSecure", UIParent, "SecureHandlerShowHideTemplate")
Try(rawget(_G, "SecureHandlerSetFrameRef"), B.Secure, "use", B.SecureUse)

B.Holder = CreateFrame("Frame", "ControllerCamHUD_BagHolder", UIParent)
B.Holder:SetSize(1, 1)
B.Holder:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
B.Holder:SetAlpha(0)                        -- (the game's bag windows open in it, never seen)
B.Holder:SetScale(0.01)

-- What can't be put on in a fight: armour (weapons, shields, off hands and relics can)
B.FIGHT_WEAR = { INVTYPE_SHIELD = true, INVTYPE_HOLDABLE = true, INVTYPE_RELIC = true }
function B.NoFightEquip(e)
    return e ~= nil and e.classID == 4 and not B.FIGHT_WEAR[e.equipLoc or ""] or false
end

B.NAV = { PADDUP = "up", PADDDOWN = "down", PADDLEFT = "left", PADDRIGHT = "right" }
B.NAV_SNIPPET = [[
    if down or not PlayerInCombat() then return end
    local i = owner:GetAttribute("i") or 1
    local to = owner:GetAttribute(self:GetAttribute("dir") .. i)
    if to then
        owner:SetAttribute("i", to)
        local use = owner:GetFrameRef("use")
        if use then use:SetAttribute("macrotext", owner:GetAttribute("slot" .. to)) end
    end
]]
B.navButtons = {}
local function Unseen(b)
    b:SetSize(1, 1)
    b:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -10, 10)
    b:SetAlpha(0)
    b:EnableMouse(false)
end
for key, dir in pairs(B.NAV) do
    local nb = SecureButton("ControllerCamHUD_BagNav_" .. key)
    nb:SetAttribute("dir", dir)
    Unseen(nb)
    Try(rawget(_G, "SecureHandlerWrapScript"), nb, "OnClick", B.Secure, B.NAV_SNIPPET)
    nb:SetScript("PostClick", ns.Protect(function(_, _, down)
        if down then return end
        if InCombatLockdown() then B:FromSecure() else B:Pad(key) end
    end))
    B.navButtons[key] = nb
end

-- B where the game's combined bags aren't open (a window for each bag): our close, its bindings cleared securely
B.SecureClose = SecureButton("ControllerCamHUD_BagClose")
Unseen(B.SecureClose)
Try(rawget(_G, "SecureHandlerWrapScript"), B.SecureClose, "OnClick", B.Secure, [[
    if down then return end
    owner:ClearBindings()
    owner:SetAttribute("combatbound", nil)
]])
B.SecureClose:SetScript("PostClick", ns.Protect(function(_, _, down) if not down then B:Close() end end))

-- X in a fight on armour: said, not tried. At a vendor, a sale of something of an equipment set, or worth a gold
-- or more, is said in chat (the vendor's buyback has it); nothing is asked first: X there is a sale, as the game's
B.SOLD_SAY = 10000
function B.SaySold(e)
    if not (e and e.id and B.merchantOpen) then return false end
    local inSet = Try(C_Container.GetContainerItemEquipmentSetInfo, e.bag, e.slot) == true
    local M = ns.Market
    local each = M and M.Vendor and Num(Try(M.Vendor, e.id)) or 0
    local worth = each * (e.count or 1)
    if not (inSet or worth >= B.SOLD_SAY) then return false end
    ns.Say(L["Sold %s: the vendor can sell it back to you."]:format(B.DestroyName(e)))
    return true
end
B.SecureUse:SetScript("PostClick", ns.Protect(function(_, _, down)
    if down then return end
    if B.menu then C_Timer.After(0, function() if B.menu and B.open then B:CloseMenu() end end) end   -- (a row done)
    local e = B.list and B.list[B.index]
    if InCombatLockdown() then
        if e and e.id and B.NoFightEquip(e) then ns.Say(L["Armour can't be changed in a fight."]) end
        return
    end
    B.SaySold(e)
end))

-- The fight's bindings: key -> "CLICK button:LeftButton" or a binding of the game's
function B.FightSet()
    local set = {}
    for key in pairs(B.NAV) do set[key] = "CLICK ControllerCamHUD_BagNav_" .. key .. ":LeftButton" end
    set.PAD3 = "CLICK ControllerCamHUD_BagUse:LeftButton"
    set.PAD1 = "CLICK ControllerCamHUD_BagKey_PAD1:LeftButton"                 -- (picking up: not protected)
    set.PAD2 = Shown(rawget(_G, "ContainerFrameCombinedBags")) and "OPENALLBAGS"
               or "CLICK ControllerCamHUD_BagClose:LeftButton"
    return set
end

-- The game's bags opened in a fight: the same set, bound by the secure snippet (it only ever runs on the combined
-- bags, so B is the game's own close); the choice on the first slot (Smart order: your potions)
local function ShowSnippet()
    local lines = { "if not PlayerInCombat() then return end", 'self:SetAttribute("i", 1)',
                    'local use = self:GetFrameRef("use")',
                    'if use then use:SetAttribute("macrotext", self:GetAttribute("slot1")) end',
                    'self:SetAttribute("combatbound", true)' }
    local keys = {}
    for key in pairs(B.NAV) do keys[#keys + 1] = key end
    table.sort(keys)
    for _, key in ipairs(keys) do
        lines[#lines + 1] = ('self:SetBindingClick(true, "%s", "ControllerCamHUD_BagNav_%s", "LeftButton")'):format(key, key)
    end
    lines[#lines + 1] = 'self:SetBindingClick(true, "PAD3", "ControllerCamHUD_BagUse", "LeftButton")'
    lines[#lines + 1] = 'self:SetBindingClick(true, "PAD1", "ControllerCamHUD_BagKey_PAD1", "LeftButton")'
    lines[#lines + 1] = 'self:SetBinding(true, "PAD2", "OPENALLBAGS")'
    return table.concat(lines, "\n")
end
B.Secure:SetAttribute("_onshow", ShowSnippet())
B.Secure:SetAttribute("_onhide", [[
    self:ClearBindings()
    self:SetAttribute("combatbound", nil)
]])

-- The table the snippets move through, from a list and its model (out of combat only)
function B.SecureSync(list, model, index)
    if InCombatLockdown() then return false end
    local S, n = B.Secure, #list
    for k = 1, math.max(n, B.syncedN or 0) do
        local e = list[k]
        S:SetAttribute("slot" .. k, (e and e.id and not B.NoFightEquip(e)) and ("/use " .. e.bag .. " " .. e.slot) or nil)
        for _, way in ipairs({ "up", "down", "left", "right" }) do
            local to = e and model and B.StepModel(model, k, way, n)
            S:SetAttribute(way .. k, (type(to) == "number" and to ~= k) and to or nil)
        end
    end
    B.syncedN = n
    S:SetAttribute("i", index or 1)
    return true
end

-- The mouse's cover: over the slot you point at (placed by where the slot is, never anchored to it, so the slot
-- stays an ordinary frame). Right click: the use (secure). Left click, or a drag: picks up and puts down.
-- Shift + left click: links it in chat.
B.Cover = SecureButton("ControllerCamHUD_BagCover")
B.Cover:SetAttribute("type2", "macro")
B.Cover:RegisterForDrag("LeftButton")
B.Cover:SetFrameStrata("HIGH")
B.Cover:Hide()
local function CoverSlot() return B.coverSlot end
B.Cover:SetScript("PreClick", ns.Protect(function(_, mouse, down)
    local s = CoverSlot()
    if down or not s or mouse ~= "LeftButton" then return end
    local link = Str(Try(C_Container.GetContainerItemLink, s.bag, s.slot))
    if link and Try(rawget(_G, "IsModifiedClick"), "CHATLINK") == true then
        Try(rawget(_G, "HandleModifiedItemClick"), link)
    else
        Try(C_Container.PickupContainerItem, s.bag, s.slot)
    end
end))
B.Cover:SetScript("OnDragStart", ns.Protect(function()
    local s = CoverSlot()
    if s then Try(C_Container.PickupContainerItem, s.bag, s.slot) end
end))
B.Cover:SetScript("OnReceiveDrag", ns.Protect(function()
    local s = CoverSlot()
    if s then Try(C_Container.PickupContainerItem, s.bag, s.slot) end
end))
B.Cover:SetScript("OnEnter", ns.Protect(function() B:Tip() end))
B.Cover:SetScript("OnLeave", ns.Protect(function()
    GameTooltip:Hide()
    B.Uncover()
end))

-- Over a slot (out of combat): put there, aimed at it
function B.CoverOver(button)
    local s = B.slotOf[button]
    if not s or InCombatLockdown() then return false end
    local c = B.Cover
    local x, y = Try(button.GetCenter, button)
    local k = (Num(Try(button.GetEffectiveScale, button)) or 1) / (Num(Try(UIParent.GetEffectiveScale, UIParent)) or 1)
    if not (Num(x) and Num(y)) then return false end
    c:ClearAllPoints()
    c:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x * k, y * k)
    c:SetSize(B.SIZE * k, B.SIZE * k)
    c:SetFrameLevel((Num(Try(button.GetFrameLevel, button)) or 1) + 30)
    c:SetAttribute("macrotext", "/use " .. s.bag .. " " .. s.slot)
    B.coverSlot = s                                        -- (ours: nothing written on the button)
    c:Show()
    return true
end

-- Put away (out of combat; at a fight's start, while that is still allowed)
function B.Uncover()
    if InCombatLockdown() and not B.fightStarting then return end
    local c = B.Cover
    B.coverSlot = nil
    c:SetAttribute("macrotext", nil)
    c:Hide()
end

-- Without the game's template (a client that has none): a plain button that only shows the slot (its clicks
-- are the secure cover's, as with the template)
local function PlainButton(name, holder)
    local b = CreateFrame("Button", name, holder)
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(b)
    local count = ns.FontString(b, 10, "RIGHT")
    count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
    return b, icon, count
end

local function ButtonName(bag, slot)
    return ("ControllerCamHUD_Bag%s_%d"):format(bag < 0 and ("m" .. -bag) or tostring(bag), slot)
end

-- The button of one bag slot, made the first time it is shown
function B.Button(bag, slot)
    local key = bag .. ":" .. slot
    local b = B.buttons[key]
    if b then return b end
    local name, holder = ButtonName(bag, slot), Holder(bag)
    local ok, made = pcall(CreateFrame, "ItemButton", name, holder, "ContainerFrameItemButtonTemplate")
    local kind = "item button"
    if not (ok and made) then
        ok, made = pcall(CreateFrame, "Button", name, holder, "ContainerFrameItemButtonTemplate")
        kind = "button"
    end
    local ex = {}
    if ok and made then
        made:SetID(slot)
        -- the game asks the button for its bag: by its parent's id where the template does so (ours: Holder);
        -- a template that keeps the bag on the button itself is told it, once
        local got = Try(made.GetBagID, made)
        if got ~= bag and type(made.SetBagID) == "function" then Try(made.SetBagID, made, bag) end
        B.fromParent = (got == bag)
        -- it only shows the slot (icon, count, quality, cooldown, the game's tooltip): its own click is never
        -- let run. The template was set up by our code, so its click would act in the HUD's name, and using an
        -- item that way is refused ("blocked from an action only available to the Blizzard UI"). A use is the
        -- secure buttons' (B.SecureUse, B.Cover); picking up is ours, and is not protected.
        made:SetScript("OnClick", nil)
        made:SetScript("OnDragStart", nil)
        made:SetScript("OnReceiveDrag", nil)
    else
        made, ex.icon, ex.count = PlainButton(name, holder)
        kind = "plain"
    end
    B.template = kind
    made:SetSize(B.SIZE, B.SIZE)
    -- our own pieces, on our own button: the slot's backing (the same for every slot, full or empty), a quest
    -- item's gold edge (the game's own, as its bags draw it; its "!" for one that starts a quest), a dot on a new
    -- item, junk's coin
    ex.back = B.SlotBack(made)
    ex.quest = made:CreateTexture(nil, "OVERLAY", nil, 1)
    ex.quest:SetAllPoints(made)
    ex.new = made:CreateTexture(nil, "OVERLAY", nil, 4)
    ex.new:SetSize(7, 7)
    ex.new:SetPoint("TOPRIGHT", made, "TOPRIGHT", -3, -3)
    ex.new:SetColorTexture(1, 0.82, 0.3, 1)
    ex.junk = made:CreateTexture(nil, "OVERLAY", nil, 3)
    ex.junk:SetSize(12, 12)
    ex.junk:SetPoint("TOPLEFT", made, "TOPLEFT", 2, -2)
    ex.junk:SetTexture("Interface\\Buttons\\UI-GroupLoot-Coin-Up")
    -- the mouse over a slot chooses it (after the game's own: its tooltip is the game's)
    if made.HookScript then made:HookScript("OnEnter", ns.Protect(function(self) B:Pointed(self) end)) end
    B.extra[made], B.kind[made] = ex, kind
    B.buttons[key] = made
    B.slotOf[made] = { bag = bag, slot = slot }
    made:Hide()
    return made
end

-- A slot's backing: a dark square with a faint edge, behind the icon, so full and empty slots line up as one grid
function B.SlotBack(button)
    local back = button:CreateTexture(nil, "BACKGROUND", nil, -8)
    back:SetPoint("TOPLEFT", button, "TOPLEFT", -1, 1)
    back:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, -1)
    back:SetColorTexture(0.55, 0.62, 0.75, 0.22)
    local inner = button:CreateTexture(nil, "BACKGROUND", nil, -7)
    inner:SetAllPoints(button)
    inner:SetColorTexture(0, 0, 0, 0.55)
    return back
end

-- The template's own layers that the game's bag windows switch on and off as they go: a new item's glow and
-- flash, the shop's glow, the overlays of an item context (the auction house's, a search), the upgrade arrow,
-- its junk coin. Nothing of the game's runs them on our buttons, so whatever was left on would stay on: they are
-- put out every time a slot is drawn (ours say what they mean). B.layersSeen names any found on, for the report.
B.LAYERS = { "NewItemTexture", "BattlepayItemTexture", "flash", "IconOverlay", "IconOverlay2", "ItemContextOverlay",
             "searchOverlay", "UpgradeIcon", "JunkIcon", "IconQuestTexture", "ExtendedSlot", "ExtendedOverlay",
             "ExtendedOverlay2", "BagStaticTop", "BagStaticBottom" }
B.ANIMS = { "newitemglowAnim", "flashAnim" }
B.layersSeen = {}
function B.Quiet(b)
    local name = b.GetName and b:GetName() or ""
    for _, key in ipairs(B.LAYERS) do
        local r = rawget(b, key) or rawget(_G, name .. key)
        if type(r) == "table" and r.Hide then
            if Shown(r) then B.layersSeen[key] = true end
            r:Hide()
        end
    end
    for _, key in ipairs(B.ANIMS) do
        local a = rawget(b, key)
        if type(a) == "table" and a.Stop then Try(a.Stop, a) end
    end
end

local function Call(b, method, ...)
    local fn = b[method]
    if type(fn) == "function" then return Try(fn, b, ...) end
    fn = rawget(_G, method)
    if type(fn) == "function" then return Try(fn, b, ...) end
end

B.QUEST_EDGE = "Interface\\ContainerFrame\\UI-Icon-QuestBorder"
B.QUEST_BANG = "Interface\\ContainerFrame\\UI-Icon-QuestBang"
B.FADED = 0.45                                  -- junk's alpha (and greyed)

-- Draw a slot: its item, or nothing (an empty slot: plain). Junk is greyed and faded; a quest item has the
-- game's gold edge, or its "!" when it starts a quest you haven't taken.
local function Paint(b, e)
    local ex = B.extra[b] or {}
    local item = e.id ~= nil
    local junk = item and B.Junk(e) or false
    if B.kind[b] == "plain" then
        ex.icon:SetTexture(item and e.icon or "Interface\\PaperDoll\\UI-Backpack-EmptySlot")
        ex.count:SetText(item and e.count > 1 and tostring(e.count) or "")
    else
        Call(b, "SetItemButtonTexture", item and e.icon or nil)
        Call(b, "SetItemButtonCount", item and e.count or 0)
        Call(b, "SetItemButtonQuality", item and e.quality or nil, item and e.link or nil)
        local desat = rawget(_G, "SetItemButtonDesaturated")
        if type(desat) == "function" then Try(desat, b, item and (e.locked or junk) or false) end
        B.Quiet(b)
    end
    local cd = rawget(b, "Cooldown") or rawget(_G, (b:GetName() or "") .. "Cooldown")
    if item and type(cd) == "table" and C_Container.GetContainerItemCooldown then
        local start, duration, enable = Try(C_Container.GetContainerItemCooldown, e.bag, e.slot)
        local set = rawget(_G, "CooldownFrame_Set")
        if type(set) == "function" and Num(start) and Num(duration) then Try(set, cd, start, duration, enable) end
    elseif type(cd) == "table" and cd.Hide then
        cd:Hide()
    end
    b:SetAlpha(junk and B.FADED or 1)
    if ex.quest then
        ex.quest:SetTexture(item and e.questStart and B.QUEST_BANG or B.QUEST_EDGE)
        Showing(ex.quest, item and e.quest == true)
    end
    if ex.new then Showing(ex.new, item and e.new == true) end
    if ex.junk then Showing(ex.junk, junk) end
end

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------
local function Key(key) return ns.KeyText and ns.KeyText(key, 0) or key end

local function Edge(parent, layer, r, g, b, a)
    local t = parent:CreateTexture(nil, layer or "BORDER")
    t:SetColorTexture(r, g, b, a)
    return t
end

-- A ring of four thin lines round whatever it is put on (the chosen slot)
local function Ring(parent)
    local f = CreateFrame("Frame", nil, parent)
    f.lines = {}
    for i = 1, 4 do f.lines[i] = Edge(f, "OVERLAY", 1, 0.82, 0.3, 1) end
    f.lines[1]:SetPoint("TOPLEFT", f, "TOPLEFT"); f.lines[1]:SetPoint("TOPRIGHT", f, "TOPRIGHT"); f.lines[1]:SetHeight(2)
    f.lines[2]:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT"); f.lines[2]:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT"); f.lines[2]:SetHeight(2)
    f.lines[3]:SetPoint("TOPLEFT", f, "TOPLEFT"); f.lines[3]:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT"); f.lines[3]:SetWidth(2)
    f.lines[4]:SetPoint("TOPRIGHT", f, "TOPRIGHT"); f.lines[4]:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT"); f.lines[4]:SetWidth(2)
    return f
end

local function Width() return B.PAD * 2 + B.COLS * B.STEP - B.GAP end

-- Where the window sits: its top right corner (so it fills top to bottom, never growing upward), where you
-- dragged it or by default. With the bank in it, two spots side by side: the bank on the left, your bags on the
-- right (where the window always is); the window takes the spot of what it shows, the other's shown beside it.
B.spot = CreateFrame("Frame", nil, UIParent)
B.spot:SetSize(1, 1)
local function Place()
    if B.sided then return end                               -- (side by side with the game's bank: BankSide's)
    local db = ns.db
    if db and not db.bagTop and db.bagPos then               -- (a place kept by its bottom, before: by its top now)
        local h = Num(Try(frame.GetHeight, frame)) or 500
        db.bagTop = { x = db.bagPos.x, y = db.bagPos.y + h }
    end
    local pos = db and db.bagTop
    B.spot:ClearAllPoints()
    B.spot:SetWidth(Num(Try(frame.GetWidth, frame)) or 400)
    if pos then B.spot:SetPoint("TOPRIGHT", UIParent, "BOTTOMRIGHT", pos.x, pos.y)
    else B.spot:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -60, -100) end
    frame:ClearAllPoints()
    if B.hosting and B.bankOpen and B.view == "bank" then
        frame:SetPoint("TOPRIGHT", B.spot, "TOPLEFT", -B.BANK_GAP, 0)
    else
        frame:SetPoint("TOPRIGHT", B.spot, "TOPRIGHT", 0, 0)
    end
end
B.Place = function() if frame then Place() end end

-- At the bank, the windows in the game's own order for LT and RT: its bags come before its bank window (LT to
-- the bags, RT to the bank), so ours (standing in for its bags) takes the bank window's place on the left and
-- the bank window sits to its right. Put back as the bank closes. Never in a fight.
B.BANK_GAP = 12
function B.BankSide(on)
    if not frame or InCombatLockdown() then return end
    local bank = rawget(_G, "BankFrame")
    if on then
        if type(bank) ~= "table" or not Shown(bank) then return end
        local _, rel = Try(bank.GetPoint, bank, 1)
        if B.sided and rel == frame then return end         -- (as we left it)
        if not B.sided then
            local p = { Try(bank.GetPoint, bank, 1) }
            B.bankWas = #p > 0 and p or nil
        end
        local left, top = Num(Try(bank.GetLeft, bank)), Num(Try(bank.GetTop, bank))
        local kBank = Num(Try(bank.GetEffectiveScale, bank)) or 1
        local kOurs = Num(Try(frame.GetEffectiveScale, frame)) or 1
        frame:ClearAllPoints()
        if left and top then
            frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left * kBank / kOurs, top * kBank / kOurs)
        else
            frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -100)
        end
        Try(bank.ClearAllPoints, bank)
        Try(bank.SetPoint, bank, "TOPLEFT", frame, "TOPRIGHT", B.BANK_GAP, 0)
        B.sided = true
    elseif B.sided then
        B.sided = nil
        if type(bank) == "table" then
            local _, rel = Try(bank.GetPoint, bank, 1)
            if rel == frame then
                Try(bank.ClearAllPoints, bank)
                if B.bankWas then Try(bank.SetPoint, bank, unpack(B.bankWas)) end
            end
        end
        B.bankWas = nil
        Place()
    end
end

-- The window's shell: its back, title, money, close button, filters, grid, rule and bag row. The window has one,
-- and at the bank (the bank in the window) so has the side beside it, drawn the same way (B.DrawFace).
local function Shell(f, main)
    f.back = Edge(f, "BACKGROUND", 0.03, 0.04, 0.07, 0.92)
    f.back:SetAllPoints(f)
    for _, side in ipairs({ "TOP", "BOTTOM" }) do
        local t = Edge(f, "BORDER", 0.55, 0.62, 0.75, 0.6)
        t:SetPoint(side .. "LEFT", f, side .. "LEFT")
        t:SetPoint(side .. "RIGHT", f, side .. "RIGHT")
        t:SetHeight(1)
    end
    f.title = ns.FontString(f, 13, "LEFT")
    f.title:SetPoint("LEFT", f, "TOPLEFT", B.PAD, -15)          -- (level with the close button)
    f.title:SetTextColor(0.98, 0.82, 0.3)
    -- the game's own close button (its look), for the mouse; it does what B does
    local ok, close = pcall(CreateFrame, "Button", nil, f, "UIPanelCloseButtonNoScripts")
    if not (ok and close) then
        close = CreateFrame("Button", nil, f)
        close.text = ns.FontString(close, 11, "CENTER")
        close.text:SetPoint("CENTER", close, "CENTER", 0, 0)
        close.text:SetText("x")
    end
    close:SetSize(22, 22)
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    close:SetScript("OnClick", ns.Protect(function() B:Close() end))
    f.close = close
    f.money = ns.FontString(f, 10, "RIGHT")
    f.money:SetPoint("RIGHT", close, "LEFT", -6, 0)
    f.title:SetPoint("RIGHT", f.money, "LEFT", -8, 0)
    if f.title.SetWordWrap then f.title:SetWordWrap(false) end
    -- the filters: the chosen one in the middle, its neighbours either side, LB and RB at the ends
    local row = CreateFrame("Frame", nil, f)
    row:SetPoint("TOPLEFT", f, "TOPLEFT", B.PAD, -32)
    row:SetPoint("TOPRIGHT", f, "TOPRIGHT", -B.PAD, -32)
    row:SetHeight(30)
    row.back = Edge(row, "BACKGROUND", 1, 1, 1, 0.05)
    row.back:SetAllPoints(row)
    row.lb = ns.FontString(row, 11, "LEFT")
    row.lb:SetPoint("LEFT", row, "LEFT", 6, 2)
    row.rb = ns.FontString(row, 11, "RIGHT")
    row.rb:SetPoint("RIGHT", row, "RIGHT", -6, 2)
    row.cur = ns.FontString(row, 13, "CENTER")              -- (the chosen one alone; the dots say where it is)
    row.cur:SetPoint("CENTER", row, "CENTER", 0, 3)
    row.dots = {}
    for i = 1, #B.FILTERS do
        local d = Edge(row, "ARTWORK", 1, 1, 1, 0.3)
        d:SetSize(5, 3)
        d:SetPoint("BOTTOM", row, "BOTTOM", (i - (#B.FILTERS + 1) / 2) * 9, 3)
        row.dots[i] = d
    end
    for way, anchor in pairs(main and { [-1] = "LEFT", [1] = "RIGHT" } or {}) do   -- (the mouse: either half)
        local hit = CreateFrame("Button", nil, row)
        hit:SetPoint("TOP" .. anchor, row, "TOP" .. anchor, 0, 0)
        hit:SetSize((B.COLS * B.STEP - B.GAP) / 2, 30)
        hit:SetScript("OnClick", ns.Protect(function() B:Filter(way) end))
    end
    f.filters = row
    f.grid = CreateFrame("Frame", nil, f)
    f.grid:SetPoint("TOPLEFT", f, "TOPLEFT", B.PAD, -B.TOP)
    f.grid:SetSize(B.COLS * B.STEP - B.GAP, B.STEP)
    f.heads = {}                                        -- (the sections' headings, made as needed)
    -- more rows than fit: a slim bar in the margin right of the grid, its bright part the rows in sight
    f.track = Edge(f, "ARTWORK", 1, 1, 1, 0.1)
    f.track:SetWidth(2)
    f.track:SetPoint("TOPLEFT", f.grid, "TOPRIGHT", 5, 0)
    f.track:SetPoint("BOTTOMLEFT", f.grid, "BOTTOMRIGHT", 5, 0)
    f.thumb = Edge(f, "OVERLAY", 1, 0.82, 0.3, 0.8)
    f.thumb:SetWidth(2)
    f.bags = CreateFrame("Frame", nil, f)
    f.bags:SetSize(B.COLS * B.STEP - B.GAP, B.BAG)
    f.bagButtons = {}
    f.space = ns.FontString(f.bags, 10, "RIGHT")
    f.space:SetPoint("RIGHT", f.bags, "RIGHT", 0, 0)
    f.space:SetTextColor(unpack(C.muted))
    f.rule = Edge(f, "BORDER", 0.55, 0.62, 0.75, 0.25)          -- between the grid and the bags
    f.rule:SetHeight(1)
    f.rule:SetPoint("BOTTOMLEFT", f.bags, "TOPLEFT", 0, B.RULE)
    f.rule:SetPoint("BOTTOMRIGHT", f.bags, "TOPRIGHT", 0, B.RULE)
end

local function Build()
    frame = CreateFrame("Frame", "ControllerCamHUD_Bags", UIParent)
    frame:SetSize(Width(), 300)
    frame:SetFrameStrata("HIGH")
    frame:EnableMouse(true)
    frame:SetMovable(true)
    if frame.SetClampedToScreen then frame:SetClampedToScreen(true) end
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", ns.Protect(function(self)
        self:StopMovingOrSizing()
        local right, top, edge = self:GetRight(), self:GetTop(), UIParent:GetRight()
        if not (B.hosting and B.bankOpen and B.view == "bank") and Num(right) and Num(top) and Num(edge) then
            ns.db.bagTop = { x = right - edge, y = top }     -- (by its top: it fills downward)
        end
        Place()
    end))
    Shell(frame, true)
    -- the buttons' line: a tab of its own under the window (the window keeps its height whatever it says)
    frame.tab = CreateFrame("Frame", nil, frame)
    frame.tab:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -4)
    frame.tab:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -4)
    frame.tab:SetHeight(30)
    frame.tab.back = Edge(frame.tab, "BACKGROUND", 0.03, 0.04, 0.07, 0.92)
    frame.tab.back:SetAllPoints(frame.tab)
    local tabEdge = Edge(frame.tab, "BORDER", 0.55, 0.62, 0.75, 0.6)
    tabEdge:SetPoint("BOTTOMLEFT", frame.tab, "BOTTOMLEFT")
    tabEdge:SetPoint("BOTTOMRIGHT", frame.tab, "BOTTOMRIGHT")
    tabEdge:SetHeight(1)
    frame.legend = ns.FontString(frame.tab, 10, "LEFT")
    frame.legend:SetPoint("TOPLEFT", frame.tab, "TOPLEFT", B.PAD, -8)
    frame.legend:SetPoint("TOPRIGHT", frame.tab, "TOPRIGHT", -B.PAD, -8)
    if frame.legend.SetWordWrap then frame.legend:SetWordWrap(true) end
    frame.sel = Ring(frame)
    frame.sel:SetFrameLevel((frame:GetFrameLevel() or 1) + 20)
    frame.sel:Hide()
    -- Y: more, beside the window
    local menu = CreateFrame("Frame", nil, frame)
    menu:SetPoint("TOPRIGHT", frame, "TOPLEFT", -6, 0)      -- (or to its right: B.MenuSide)
    menu:SetSize(250, 40)
    menu:SetFrameStrata("DIALOG")                            -- (over a window beside ours, the bank's)
    menu:EnableMouse(true)
    menu.back = Edge(menu, "BACKGROUND", 0.03, 0.04, 0.07, 0.94)
    menu.back:SetAllPoints(menu)
    menu.rows = {}
    menu:Hide()
    frame.menu = menu
    frame:Hide()
    B.frame = frame
    Place()
    B.keyButtons = {}
    for _, key in ipairs(B.KEYS) do
        local kb = CreateFrame("Button", "ControllerCamHUD_BagKey_" .. key, UIParent)
        -- (told of the press as well as the release: Destroy is a hold; everything acts as it is let go)
        kb:RegisterForClicks("AnyDown", "AnyUp")
        kb:SetScript("OnClick", ns.Protect(function(_, _, down)
            if down then B:PadDown(key) else B:Pad(key) end
        end))
        B.keyButtons[key] = kb
    end
end

-- A bag of the bag row: its icon; X (or a right click) shows it alone, A (or a left click) puts into it, or
-- picks the bag up
local function BagButton(i, f)
    f = f or frame
    local b = f.bagButtons[i]
    if b then return b end
    b = CreateFrame("Button", nil, f.bags)
    b:SetSize(B.BAG, B.BAG)
    b:SetPoint("LEFT", f.bags, "LEFT", (i - 1) * B.STEP, 0)
    B.SlotBack(b)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints(b)
    b.chosen = Edge(b, "OVERLAY", 1, 0.82, 0.3, 0.3)          -- (shown alone)
    b.chosen:SetAllPoints(b)
    -- its slots, in the corner like a stack's count: "12/16" where that fits in the icon, else "16"
    b.size = ns.FontString(b, 9, "RIGHT")
    b.size:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
    if b.size.SetWordWrap then b.size:SetWordWrap(false) end
    if f ~= frame then                                       -- (beside the window: only to be seen)
        b:EnableMouse(false)
        f.bagButtons[i] = b
        return b
    end
    b:SetScript("OnClick", ns.Protect(function(_, mouse) B:BagPress(mouse == "RightButton" and "only" or "put", i) end))
    b:SetScript("OnDragStart", ns.Protect(function() B:BagPress("put", i) end))
    b:SetScript("OnReceiveDrag", ns.Protect(function() B:BagPress("put", i) end))
    b:SetScript("OnEnter", ns.Protect(function(self) B:BagTip(self, i) end))
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.bagButtons[i] = b
    return b
end

-- The inventory slot a bag sits in (nil for the backpack and the bank itself)
local function InvSlot(bag)
    if bag == 0 or bag == (rawget(_G, "BANK_CONTAINER") or -1) or bag == B.Keyring() then return nil end
    local id = Try(C_Container.ContainerIDToInventoryID, bag) or Try(rawget(_G, "ContainerIDToInventoryID"), bag)
    return Num(id)
end

function B.BagName(rec)
    if not rec then return "" end
    if rec.keyring then return L["Keyring"] end
    if rec.bag == 0 then return L["Backpack"] end
    if rec.bag == (rawget(_G, "BANK_CONTAINER") or -1) then return L["Bank"] end
    local inv = InvSlot(rec.bag)
    local link = inv and Str(Try(GetInventoryItemLink, "player", inv))
    local name = link and link:match("%[(.-)%]")
    return name or L["Bag"]
end

local function BagIcon(rec)
    if rec.keyring then return "Interface\\Icons\\INV_Misc_Key_14" end
    if rec.bag == 0 then return "Interface\\Buttons\\Button-Backpack-Up" end
    if rec.bag == (rawget(_G, "BANK_CONTAINER") or -1) then return "Interface\\Icons\\INV_Misc_Bag_10_Blue" end
    local inv = InvSlot(rec.bag)
    return (inv and ns.Plain(Try(GetInventoryItemTexture, "player", inv))) or "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag"
end

-- The tooltip beside the window, never over its slots: to its left where the window sits on the right of the
-- screen (where it opens), else to its right; level with its top
-- (outside both windows at the bank: beside the outer one, on the side of the screen with more room; the
-- comparisons with what you wear go further out from it, or under it where the screen runs out: B.PlaceCompare)
function B.TipBeside()
    GameTooltip:SetOwner(frame, "ANCHOR_NONE")
    B.tipMine = true                                    -- (ours: put away with the window, or by R3)
    GameTooltip:ClearAllPoints()
    local w = Num(Try(UIParent.GetWidth, UIParent))
    local leftF, rightF = frame, frame
    local besideF = rawget(B, "beside")
    if besideF and Shown(besideF) then
        local bl, fl = Num(Try(besideF.GetLeft, besideF)), Num(Try(frame.GetLeft, frame))
        if bl and fl then
            if bl < fl then leftF = besideF else rightF = besideF end
        end
    end
    local left, right = Num(Try(leftF.GetLeft, leftF)), Num(Try(rightF.GetRight, rightF))
    local toRight
    if left and right and w then
        toRight = (w - right) > left                    -- (the side with more room)
    else
        local x = Num(Try(frame.GetCenter, frame))
        toRight = x and w and x < w / 2 or false
    end
    if toRight then
        GameTooltip:SetPoint("TOPLEFT", rightF, "TOPRIGHT", 8, 0)
        B.tipSide = "right"
    else
        GameTooltip:SetPoint("TOPRIGHT", leftF, "TOPLEFT", -8, 0)
        B.tipSide = "left"
    end
end

-- The game's comparison tooltips (what you wear in that slot), for our tooltip: further out from it, side by
-- side, never back over the window; under it, stacked, where the screen has no room that way
B.COMPARE = { "ShoppingTooltip1", "ShoppingTooltip2" }
function B.PlaceCompare()
    if not (B.tipMine and frame and Try(GameTooltip.GetOwner, GameTooltip) == frame) then return end
    local tips = {}
    for _, name in ipairs(B.COMPARE) do
        local t = rawget(_G, name)
        if type(t) == "table" and Shown(t) then tips[#tips + 1] = t end
    end
    if #tips == 0 then return end
    local need = 0
    for _, t in ipairs(tips) do need = need + (Num(Try(t.GetWidth, t)) or 0) + 4 end
    local w = Num(Try(UIParent.GetWidth, UIParent))
    local out
    if B.tipSide == "right" then
        local r = Num(Try(GameTooltip.GetRight, GameTooltip))
        out = not (r and w) or (r + need <= w)
    else
        local l = Num(Try(GameTooltip.GetLeft, GameTooltip))
        out = not l or (l - need >= 0)
    end
    local prev = GameTooltip
    for _, t in ipairs(tips) do
        Try(t.ClearAllPoints, t)
        if out and B.tipSide == "right" then Try(t.SetPoint, t, "TOPLEFT", prev, "TOPRIGHT", 4, 0)
        elseif out then Try(t.SetPoint, t, "TOPRIGHT", prev, "TOPLEFT", -4, 0)
        elseif B.tipSide == "right" then Try(t.SetPoint, t, "TOPLEFT", prev, "BOTTOMLEFT", 0, -4)
        else Try(t.SetPoint, t, "TOPRIGHT", prev, "BOTTOMRIGHT", 0, -4) end
        prev = t
    end
end
do  -- after the game places them (its own placing runs first; ours only moves them)
    local hooked = false
    function B.HookCompare()
        if hooked or type(hooksecurefunc) ~= "function" then return end
        hooked = true
        local place = ns.Protect(B.PlaceCompare)
        local M = rawget(_G, "TooltipComparisonManager")
        if type(M) == "table" and type(M.AnchorShoppingTooltips) == "function" then
            hooksecurefunc(M, "AnchorShoppingTooltips", place)
        end
        for _, name in ipairs({ "GameTooltip_ShowCompareItem", "GameTooltip_AnchorComparisonTooltips" }) do
            if type(rawget(_G, name)) == "function" then hooksecurefunc(name, place) end
        end
    end
end

function B:BagTip(owner, i)
    local rec = self.bagList[i]
    if not rec then return end
    B.TipBeside()
    local inv = InvSlot(rec.bag)
    if not (inv and Try(GameTooltip.SetInventoryItem, GameTooltip, "player", inv)) then
        GameTooltip:SetText(B.BagName(rec))
    end
    GameTooltip:AddLine(L["%d of %d slots used"]:format(rec.used, rec.size), 0.72, 0.76, 0.86)
    GameTooltip:Show()
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------
-- What X (use) and A (pick up, put down) do on the chosen slot, in words (nil: nothing)
function B:Words()
    local e = self.list[self.index]
    local holding = Try(rawget(_G, "CursorHasItem")) == true
    local pick = holding and L["Put down"] or (e and e.id and L["Pick up"]) or nil
    if not (e and e.id) then return nil, pick end                        -- (an empty slot: only to put down)
    local use = L["Use"]
    if self.merchantOpen then use = L["Sell"]
    elseif self.bankOpen then use = self.view == "bank" and L["To bags"] or L["To bank"]
    elseif self.mailOpen then use = L["Attach"]
    elseif self.tradeOpen then use = L["Trade"] end
    return use, pick
end

-- Where LT / RT take the controller from the bags, in words: the window by its name
B.TO = {
    MailFrame = L["%s or %s: to the mail"], MerchantFrame = L["%s or %s: to the vendor"],
    BankFrame = L["%s or %s: to the bank"], TradeFrame = L["%s or %s: to the trade"],
    AuctionHouseFrame = L["%s or %s: to the auction house"], AuctionFrame = L["%s or %s: to the auction house"],
    GuildBankFrame = L["%s or %s: to the guild bank"], CharacterFrame = L["%s or %s: to your character"],
    LootFrame = L["%s or %s: to the loot"],
}
function B.ToOther()
    local f = B.GameFocus()
    if not B.IsWindow(f) then f = B.OtherWindow() end
    for name, words in pairs(B.TO) do
        if f and f == rawget(_G, name) then return words end
    end
    return L["%s or %s: other window"]
end

-- The buttons' line under the window: only what the buttons do here, each with its own button's icon, in the
-- same order everywhere: X, A, Y, B
function B:Legend()
    local parts = {}
    local function add(key, text) parts[#parts + 1] = Key(key) .. " " .. text end
    if InCombatLockdown() then
        if not B.Secure:GetAttribute("combatbound") then
            return GREY .. L["Controller buttons return after the fight."] .. "|r"
        end
        local e = self.list[self.index]
        if e and e.id and not B.NoFightEquip(e) then add("PAD3", (e.classID == 2 or e.classID == 4) and L["Equip"] or L["Use"]) end
        if e and (e.id or Try(rawget(_G, "CursorHasItem")) == true) then add("PAD1", L["Pick up"]) end
        add("PAD2", L["Close"])
        return table.concat(parts, "   ")
    end
    if not self.hasPad then
        local back = GOLD .. L["%s or %s: back to bags"]:format(Key("PADLTRIGGER"), Key("PADRTRIGGER")) .. "|r"
        if self.bankOpen and B.aimed and self.bound and self.bound.PAD3 then
            return Key("PAD3") .. " " .. L["To bags"] .. "\n" .. back
        end
        return back
    end
    if self.confirm then
        add("PAD1", L["Hold to destroy"]); add("PAD2", L["Keep"])
        return table.concat(parts, "   ")
    end
    if self.menu then
        add("PAD1", L["Choose"]); add("PAD2", L["Back"])
        return table.concat(parts, "   ")
    end
    if self.zone == "bags" then
        local rec = self.bagList[self.bagIndex]
        add("PAD3", self.only and L["All bags"] or L["Only this bag"])
        if Try(rawget(_G, "CursorHasItem")) == true then add("PAD1", L["Put in"])
        elseif rec and InvSlot(rec.bag) then add("PAD1", L["Pick up bag"]) end
    else
        local use, pick = self:Words()
        if use then add("PAD3", use) end
        if pick then add("PAD1", pick) end
    end
    add("PAD4", L["More"]); add("PAD2", L["Close"])
    add("PADRSTICK", L["Sort"])                                       -- (R3: a quick sort, as it always was)
    if self.bankOpen then add("PADBACK", self.view == "bank" and L["Bags"] or L["Bank"]) end
    local text = table.concat(parts, "   ")
    if self.bankOpen and B.hosting then
        text = text .. "\n" .. GREY .. Key("PADLTRIGGER") .. " " .. L["Bank"] .. "   " .. Key("PADRTRIGGER") .. " "
            .. L["Bags"] .. "|r"
    elseif self.bankOpen and Shown(rawget(_G, "BankFrame")) then
        local _, known = B.GameFocus()
        local words = (self.view == "bank" and not known) and L["%s or %s: back to bags"] or L["%s or %s: to the bank"]
        text = text .. "\n" .. GREY .. words:format(Key("PADLTRIGGER"), Key("PADRTRIGGER")) .. "|r"
    elseif B.OtherWindow() then
        text = text .. "\n" .. GREY .. B.ToOther():format(Key("PADLTRIGGER"), Key("PADRTRIGGER")) .. "|r"
    end
    return text
end

function B:Selected()
    if self.zone ~= "grid" then return nil end
    return self.at[self.index]
end

-- A side's grid: the slots and headings of a model in sight from scroll, into f's grid; marks the buttons used
-- (they are shared: one per bag slot) and returns { index -> button }
local function DrawGrid(f, list, model, scroll, viewH, used)
    local from, to = scroll, scroll + viewH
    local at, heads = {}, 0
    for _, l in ipairs(model.lines) do
        local inSight = l.y >= from - 0.5 and l.y + (l.kind == "row" and B.SIZE or l.h) <= to + 0.5
        if inSight and l.kind == "head" then
            heads = heads + 1
            local fs = f.heads[heads]
            if not fs then
                fs = ns.FontString(f.grid, 10, "LEFT")
                f.heads[heads] = fs
            end
            fs:ClearAllPoints()
            fs:SetPoint("BOTTOMLEFT", f.grid, "TOPLEFT", 1, -(l.y - from) - l.h + 6)
            fs:SetPoint("RIGHT", f.grid, "RIGHT", 0, 0)
            local sec = l.sec
            if sec.muted then fs:SetText(GREY .. sec.text .. "|r")
            else fs:SetText(GOLD .. sec.text .. "|r  " .. GREY .. sec.count .. "|r") end
            fs:Show()
        elseif inSight then
            for k = l.first, l.first + l.count - 1 do
                local e = list[k]
                local b = B.Button(e.bag, e.slot)
                used[b] = true
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", f.grid, "TOPLEFT", (k - l.first) * B.STEP, -(l.y - from))
                Paint(b, e)
                b:Show()
                at[k] = b
            end
        end
    end
    for k = heads + 1, #f.heads do f.heads[k]:Hide() end
    return at
end

-- A side's grid height, scroll bar, bag row, title, money and filters. st: the side's state (view, only, read,
-- counts, filter, scroll); the same for the window and the side beside it, so both look alike
local function DrawFace(f, st, gridH, total, viewH)
    f.grid:SetHeight(gridH)
    local scrolls = total > viewH + 0.5
    Showing(f.track, scrolls)
    Showing(f.thumb, scrolls)
    if scrolls then
        f.thumb:ClearAllPoints()
        f.thumb:SetPoint("TOPLEFT", f.track, "TOPLEFT", 0, -gridH * (st.scroll or 0) / total)
        f.thumb:SetHeight(math.max(6, gridH * viewH / total))
    end
    f.bags:ClearAllPoints()
    f.bags:SetPoint("TOPLEFT", f.grid, "BOTTOMLEFT", 0, -(B.RULE * 2 + 1))
    local bagList = st.read and st.read.bags or {}
    for k, rec in ipairs(bagList) do
        local bb = BagButton(k, f)
        bb.icon:SetTexture(BagIcon(rec))
        if rec.bag == 0 then bb.icon:SetTexCoord(0, 1, 0, 1) else bb.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
        Showing(bb.chosen, st.only == rec.bag)
        bb.size:SetText(("%d/%d"):format(rec.used, rec.size))
        local w = Num(Try(bb.size.GetStringWidth, bb.size))
        if not (w and w <= B.BAG - 4) then bb.size:SetText(tostring(rec.size)) end   -- (too wide: the size alone)
        bb:Show()
    end
    for k = #bagList + 1, #f.bagButtons do f.bagButtons[k]:Hide() end
    local read = st.read or { total = 0, used = 0 }
    f.space:SetText(L["%d free"]:format(math.max(0, (read.total or 0) - (read.used or 0))))
    local title = st.view == "bank" and L["Bank"] or L["Bags"]
    if st.only then
        for _, rec in ipairs(bagList) do
            if rec.bag == st.only then title = title .. GREY .. "  " .. B.BagName(rec) .. "|r" end
        end
    end
    f.title:SetText(title)
    local money = Num(Try(GetMoney))
    f.money:SetText(money and ns.MoneyColored and ns.MoneyColored(money) or "")
    local F, nf = B.FILTERS, #B.FILTERS
    local cur = F[((st.filter or 1) - 1) % nf + 1]
    f.filters.cur:SetText(GOLD .. cur.text .. "|r  " .. GREY .. ((st.counts or {})[cur.key] or 0) .. "|r")
    f.filters.lb:SetText(Key("PADLSHOULDER"))
    f.filters.rb:SetText(Key("PADRSHOULDER"))
    for k, d in ipairs(f.filters.dots) do
        if k == st.filter then d:SetColorTexture(1, 0.82, 0.3, 1) else d:SetColorTexture(1, 1, 1, 0.3) end
    end
    f:SetHeight(B.TOP + gridH + B.RULE * 2 + 1 + B.BAG + 12)
end

-- At the bank (in the window): the side the controller isn't on, beside the window, drawn as the window is:
-- the bank on the left, your bags on the right
local beside
local function Beside()
    if beside then return beside end
    beside = CreateFrame("Frame", "ControllerCamHUD_BagsBeside", UIParent)
    beside:SetFrameStrata("HIGH")
    beside:SetSize(Width(), 300)
    beside:EnableMouse(true)
    Shell(beside, false)
    B.beside = beside
    return beside
end
function B.DrawBeside(on)
    if not on and beside then beside:Hide() end
end

function B:Layout()
    if not (frame and self.open) then return end
    B.Uncover()                         -- (the slots may move: the mouse's next slot puts the cover back)
    local list, cols = self.list or {}, B.COLS
    local n = #list
    local model = self.model or B.Model(list, self.sections or {}, cols)
    self.model = model
    self.index = ns.Clamp(self.index, 1, math.max(1, n))
    -- what is in sight: a window as tall as the screen allows, moved so the chosen row (with its section's
    -- heading, on its first row) is in it
    local viewH = B.Rows() * B.STEP - B.GAP
    local total = model.height
    local p = model.pos[self.index]
    local line = p and model.lines[p.line]
    if line then
        local top = line.head and line.head.y or line.y
        local bottom = line.y + B.SIZE
        if top < self.scroll then self.scroll = top end
        if bottom > self.scroll + viewH then self.scroll = bottom - viewH end
    end
    self.scroll = ns.Clamp(self.scroll, 0, math.max(0, total - viewH))
    local first = model.lines[1]                -- (never moved by a heading's height alone: it stays in sight)
    if self.scroll > 0 and first and first.kind == "head" and self.scroll <= first.h then self.scroll = 0 end
    local used = {}
    self.at = DrawGrid(frame, list, model, self.scroll, viewH, used)
    -- the other side, beside (at the bank, in the window)
    local other = B.hosting and self.bankOpen and self.besideState or nil
    if other then
        DrawGrid(Beside(), other.list, other.model, 0, viewH, used)
    end
    for _, b in pairs(self.buttons) do
        if not used[b] then b:Hide() end
    end
    -- one height for every filter, and for both sides: as tall as the taller holds, up to what fits
    local tall = math.max(total, self.fullH or 0, other and other.fullH or 0)
    local gridH = math.max(B.HEAD, math.min(tall, viewH))
    self.scrolls = total > viewH + 0.5
    self.bagList = self.read and self.read.bags or {}
    self.bagIndex = ns.Clamp(self.bagIndex, 1, math.max(1, #self.bagList))
    DrawFace(frame, self, gridH, total, viewH)
    frame.legend:SetText(self:Legend())
    local legendH = Num(Try(frame.legend.GetStringHeight, frame.legend)) or 14
    frame.tab:SetHeight(legendH + 16)
    Place()
    if other then
        local f = Beside()
        DrawFace(f, other, gridH, other.model.height, viewH)
        f:SetFrameLevel(math.max(1, (Num(Try(frame.GetFrameLevel, frame)) or 2) - 1))
        f:ClearAllPoints()
        if other.view == "bank" then
            f:SetPoint("TOPRIGHT", frame, "TOPLEFT", -B.BANK_GAP, 0)    -- (the bank on the left)
        else
            f:SetPoint("TOPLEFT", frame, "TOPRIGHT", B.BANK_GAP, 0)     -- (your bags on the right)
        end
        f:Show()
    elseif beside then
        beside:Hide()
    end
    self:Mark()
    self:Bind()
end

-- The ring round the chosen slot (or bag), dim while the controller is with the other window
function B:Mark()
    local sel = frame.sel
    local target = self.zone == "bags" and frame.bagButtons[self.bagIndex] or self:Selected()
    if not target or self.menu then sel:Hide(); return end
    sel:ClearAllPoints()
    sel:SetPoint("TOPLEFT", target, "TOPLEFT", -2, 2)
    sel:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 2, -2)
    sel:SetAlpha(self.hasPad and 1 or 0.35)
    sel:Show()
end

-- The chosen slot's tooltip always shows (the user's call: no switching it off, R3 sorts instead)
function B.TipsOff() return false end

-- The tooltip of the chosen slot, beside the window (mouse: true when the mouse chose it)
function B:Tip(mouse)
    if self.confirm then                                     -- (asking: the question names the item, nothing over it)
        if B.tipMine then GameTooltip:Hide(); B.tipMine = false end
        return
    end
    if not (self.open and self.padTip) then return end
    if not mouse and B.TipsOff() then return end
    -- the controller on the other window (a vendor's, the mailbox, the bank's): the game's tooltip is that
    -- window's, for what its own cursor is on; the bags redrawing (as they do with every sale) never takes it
    if not mouse and not self.hasPad then return end
    local target = self.zone == "bags" and frame.bagButtons[self.bagIndex] or self:Selected()
    if not target then
        if B.tipMine then GameTooltip:Hide(); B.tipMine = false end
        return
    end
    if self.zone == "bags" then return self:BagTip(target, self.bagIndex) end
    local e = self.list[self.index]
    B.TipBeside()
    if e and e.id then
        Try(GameTooltip.SetBagItem, GameTooltip, e.bag, e.slot)
    elseif e then
        GameTooltip:SetText(L["Empty slot"])
    end
    GameTooltip:Show()
    B.HookCompare()
    B.PlaceCompare()
    C_Timer.After(0, B.PlaceCompare)
end

-- Read the bags again (keepRead: only the filter or the view changed) and draw
function B:Update(keepRead)
    if not (frame and self.open) then return end
    if InCombatLockdown() and self.list and #self.list > 0 then return self:Freshen() end
    local mode = B.OrderMode()
    if not keepRead or not self.read then
        local V = ns.Vendor
        if V and V.BeginBatch then V.BeginBatch() end
        local ok, err = pcall(function()
            self.read = B.Read(self.view, self.only)
            if mode ~= "bags" then B.Order(self.read.items) end      -- (once, as the bags change)
            self.counts = B.Counts(self.read)
        end)
        if V and V.EndBatch then V.EndBatch() end
        if not ok then ns.Error(err) end
    end
    self.list, self.sections = B.List(self.read, B.FILTERS[self.filter].key, mode)
    self.model = B.Model(self.list, self.sections, B.COLS)
    if not keepRead or not self.fullH then                   -- the window's height: everything in this view
        local all, secs = B.List(self.read, "all", mode)
        self.fullH = B.Model(all, secs, B.COLS).height
    end
    if B.hosting and self.bankOpen then                      -- the other side, shown beside, as it was left
        local other = self.view == "bank" and "bags" or "bank"
        local okR, read = pcall(B.Read, other, nil)
        if okR and read then
            if mode ~= "bags" then B.Order(read.items) end
            local filter = (self.filterAt and self.filterAt[other]) or 1
            local olist, osecs = B.List(read, B.FILTERS[filter].key, mode)
            local all, asecs = B.List(read, "all", mode)
            self.besideState = { view = other, read = read, counts = B.Counts(read), filter = filter, scroll = 0,
                                 list = olist, model = B.Model(olist, osecs, B.COLS),
                                 fullH = B.Model(all, asecs, B.COLS).height }
        else
            self.besideState = nil
        end
    else
        self.besideState = nil
    end
    self:Remember()
    self:Layout()
    self:Tip()
    if ns.Narrative then ns.Narrative.Bags() end                  -- (you, muttering over them)
end

-- What a fight would open on, and what its snippets move through: the list as it is now
function B:Remember()
    if InCombatLockdown() then return end
    B.synced = { list = self.list, sections = self.sections, model = self.model, filter = self.filter,
                 view = self.view, only = self.only }
    B.SecureSync(self.list, self.model, self.index)
end

-- With the window closed (out of combat): what it would open on, your bags as a fight would find them
function B.RememberDefault()
    if InCombatLockdown() or not B.active then return end
    local V = ns.Vendor
    if V and V.BeginBatch then V.BeginBatch() end
    local ok, err = pcall(function()
        local mode = B.OrderMode()
        local read = B.Read("bags", nil)
        if mode ~= "bags" then B.Order(read.items) end
        local list, sections = B.List(read, "all", mode)
        local model = B.Model(list, sections, B.COLS)
        B.synced = { list = list, sections = sections, model = model, filter = 1, view = "bags" }
        B.SecureSync(list, model, 1)
    end)
    if V and V.EndBatch then V.EndBatch() end
    if not ok then ns.Error(err) end
end

-- In a fight: every slot drawn afresh where it is (the order stays: the secure table goes by it)
function B:Freshen()
    self.read = B.Read(self.view, self.only)
    for k, e in ipairs(self.list) do
        self.list[k] = B.Slot(e.bag, e.slot) or { bag = e.bag, slot = e.slot, empty = true, family = e.family }
    end
    self:Layout()
    self:Tip()
end

-- A secure move in a fight: our choice follows the snippet's
function B:FromSecure()
    local i = Num(B.Secure:GetAttribute("i"))
    if i then self.index, self.zone, self.padTip = i, "grid", true end
    if self.open then
        self:Layout()
        self:Tip()
    end
end

---------------------------------------------------------------------------
-- Opening and closing
---------------------------------------------------------------------------
function B:Show()
    if not self.active then return end
    if not frame then Build() end
    if self.open then self:Update(); return end
    if not self.bankOpen then self.view = "bags" end
    self.open, self.hasPad, self.zone, self.menu, self.only = true, true, "grid", nil, nil
    self.index, self.scroll, self.filter, self.bagIndex = 1, 0, 1, 1
    self.verdicts, self.read = {}, nil
    self.padTip = true
    self.triggerWas = true                 -- (a trigger resting a little in is no press)
    self.focusWas, self.pressAt = nil, nil     -- (where the game's focus is: looked at next frame)
    frame:Show()
    local s = B.synced
    if InCombatLockdown() and s and s.list and #s.list > 0 then
        self.filter, self.view, self.only = s.filter or 1, s.view or "bags", s.only
        self.list, self.sections, self.model = s.list, s.sections, s.model
        self.counts = self.counts or {}
        return self:Freshen()
    end
    self:Update()
end

-- What is no longer new once you have looked (the game's own windows do this as they close)
function B:ClearNew()
    if not (C_NewItems and C_NewItems.RemoveNewItem and self.read) then return end
    for _, e in ipairs(self.read.items) do
        if e.new then Try(C_NewItems.RemoveNewItem, e.bag, e.slot) end
    end
end

function B:Hide()
    if not self.open then return end
    self:CancelDestroy()
    self.open, self.menu = false, nil
    if ns.Narrative then ns.Narrative.Hush("bags") end
    self:ClearNew()
    if frame then
        frame:Hide()
        frame.menu:Hide()
    end
    B.DrawBeside(false)
    local owner = Try(GameTooltip.GetOwner, GameTooltip)
    if owner and (owner == frame or B.slotOf[owner] or (frame and owner ~= GameTooltip and Try(owner.GetParent, owner) == frame.bags)) then
        GameTooltip:Hide()
    end
    B.Uncover()
    self:Bind()
    if B.hosting and self.bankOpen and not InCombatLockdown() then
        local close = (C_Bank and C_Bank.CloseBankFrame) or rawget(_G, "CloseBankFrame")
        Try(close)                                          -- (the bank lived in this window: it closes with it)
    end
    if not InCombatLockdown() then C_Timer.After(0, function() B.RememberDefault() end) end
end

-- B (where it is not the game's own binding), or the window's close button: ours closes, and the game's with
-- it where it is open
function B:Close()
    if self.menu then return self:CloseMenu() end
    if InCombatLockdown() and B.Secure:GetAttribute("combatbound") then     -- (only B's secure close frees them)
        ns.Say(L["In a fight, close your bags with B."])
        return
    end
    local was = B.GameOpen()
    self:Hide()
    if was and not InCombatLockdown() then Try(rawget(_G, "CloseAllBags")) end
    self.gameWas = B.GameOpen()
end

---------------------------------------------------------------------------
-- The controller
---------------------------------------------------------------------------
local owner = B.Secure                    -- (every binding of the window: its snippets can clear them in a fight)

local function Same(a, b)
    for k, v in pairs(a) do if b[k] ~= v then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

-- The bindings wanted now: key -> "CLICK button:mouse button" or the name of one of the game's bindings.
-- X clicks the secure use button, aimed at the chosen slot here (out of combat, as this only ever is); the rest
-- tell the window, A included (picking up is not protected).
-- A window of the HUD's that takes the controller over ours while it is up: one of its questions ("Sell 12
-- items?"), an item's details. Ours steps aside and takes its buttons back as it goes.
function B.Yield()
    if ns.Dialog and ns.Dialog.visible then return true end
    local info = ns.ItemInfo and ns.ItemInfo.frame
    return Shown(info)
end

function B:Wanted()
    local want = {}
    if self.active and self.open and not self.hasPad and self.bankOpen and not InCombatLockdown() and not B.Yield() then
        -- the game's bank window has the controller: X still moves the item its cursor is on into your bags (the
        -- game's own move, a use with the bank open), so X goes both ways; every other button is the window's
        local pick = B.GameBankPick()
        if B.Aim(pick and pick.bag, pick and pick.slot) then want.PAD3 = "CLICK ControllerCamHUD_BagUse:LeftButton" end
        return want
    end
    if not (self.active and self.open and self.hasPad) or InCombatLockdown() or B.Yield() then return want end
    for _, key in ipairs(B.KEYS) do
        if B.NAV[key] then want[key] = "CLICK ControllerCamHUD_BagNav_" .. key .. ":LeftButton"
        elseif key ~= "PADBACK" or self.bankOpen then want[key] = "CLICK ControllerCamHUD_BagKey_" .. key .. ":LeftButton" end
    end
    local row = self.menu and self.menu[self.menuIndex or 1]
    if row and row.macro and not self.confirm then
        -- a row that uses, equips or moves the item: A clicks the secure button (never from our own code)
        if B.AimMacro(row.macro) then want.PAD1 = "CLICK ControllerCamHUD_BagUse:LeftButton" end
        return want
    end
    local e = not (self.menu or self.confirm) and self.zone == "grid" and self:Selected() and self.list[self.index]
    if B.Aim(e and e.id and e.bag, e and e.id and e.slot) then
        want.PAD3 = "CLICK ControllerCamHUD_BagUse:LeftButton"
    end
    -- B is the game's own: the game closes its combined window, ours goes with it
    if not (self.menu or self.confirm) and Shown(rawget(_G, "ContainerFrameCombinedBags")) then want.PAD2 = "OPENALLBAGS" end
    return want
end

function B:Bind()
    if InCombatLockdown() then return end
    if self.open and B.Secure:GetAttribute("i") ~= self.index then B.Secure:SetAttribute("i", self.index) end
    local want = self:Wanted()
    if Same(want, self.bound) then return end
    if (want.PADRSTICK ~= (self.bound or {}).PADRSTICK) and ns.KeyHeld("PADRSTICK") then
        B.bindLater = true                                   -- (R3 held: its binding changes once it is let go)
        return
    end
    B.bindLater = nil
    ClearOverrideBindings(owner)
    for key, what in pairs(want) do
        local button, mouse = what:match("^CLICK ([^:]+):(.+)$")
        if button then SetOverrideBindingClick(owner, true, key, button, mouse)
        else SetOverrideBinding(owner, true, key, what) end
    end
    self.bound = want
end

do  -- a change held back while R3 was held: made as soon as it is let go
    local later = CreateFrame("Frame")
    later:SetScript("OnUpdate", ns.Protect(function()
        if B.bindLater and not ns.KeyHeld("PADRSTICK") and not InCombatLockdown() then B:Bind() end
    end))
end

-- The fight's set, bound as the fight starts (the window open, the controller its)
function B:FightBind()
    if self.zone ~= "grid" then self.zone = "grid" end
    local S = B.Secure
    S:SetAttribute("i", self.index)
    B.SecureUse:SetAttribute("macrotext", S:GetAttribute("slot" .. self.index))
    B.aimed = nil
    ClearOverrideBindings(owner)
    local set = B.FightSet()
    for key, what in pairs(set) do
        local button, mouse = what:match("^CLICK ([^:]+):(.+)$")
        if button then SetOverrideBindingClick(owner, true, key, button, mouse)
        else SetOverrideBinding(owner, true, key, what) end
    end
    S:SetAttribute("combatbound", true)
    self.bound = set
end

-- A key of the window's (the rest of the time they are all yours)
function B:Pad(key)
    if not self.open then return false end
    ns.Note("bags: button %s", tostring(key))
    if self.confirm then return self:ConfirmPad(key) end
    if self.menu then return self:MenuPad(key) end
    if InCombatLockdown() then                                -- (the d-pad and X: the secure buttons')
        if key == "PAD1" then self:PickUp() elseif key == "PAD2" then self:Close() end
        return true
    end
    local ways = { PADDUP = "up", PADDDOWN = "down", PADDLEFT = "left", PADDRIGHT = "right" }
    if ways[key] then self:Move(ways[key])
    elseif key == "PADLSHOULDER" then self:Filter(-1)
    elseif key == "PADRSHOULDER" then self:Filter(1)
    elseif key == "PAD1" then if self.zone == "bags" then self:BagPress("put") else self:PickUp() end
    elseif key == "PAD3" then if self.zone == "bags" then self:BagPress("only") end    -- (an item's X: the secure use)
    elseif key == "PAD4" then self:OpenMenu()
    elseif key == "PAD2" then self:Close()
    elseif key == "PADBACK" then self:SwitchView()
    elseif key == "PADRSTICK" then self:Sort()
    else return false end
    return true
end

function B:Move(way)
    self.padTip = true
    if self.zone == "bags" then
        local n = #self.bagList
        if way == "left" then self.bagIndex = math.max(1, self.bagIndex - 1)
        elseif way == "right" then self.bagIndex = math.min(n, self.bagIndex + 1)
        elseif way == "up" then                          -- (to the last row, in this bag's column)
            self.zone = "grid"
            local lines = self.model and self.model.lines or {}
            for li = #lines, 1, -1 do
                local l = lines[li]
                if l.kind == "row" then
                    self.index = l.first + math.min(self.bagIndex - 1, l.count - 1)
                    break
                end
            end
        end
    else
        local model = self.model or B.Model(self.list, self.sections or {}, B.COLS)
        local to = B.StepModel(model, self.index, way, #self.list)
        if to == "bags" then
            if #self.bagList > 0 then
                local p = model.pos[self.index]
                self.zone = "bags"
                self.bagIndex = ns.Clamp((p and p.col or 0) + 1, 1, #self.bagList)
            end
        else
            self.index = to
        end
    end
    self:Layout()
    self:Tip()
end

-- LB / RB: the filter before or after (going round)
function B:Filter(way)
    local n = #B.FILTERS
    self.filter = (self.filter - 1 + way) % n + 1
    self.index, self.scroll, self.zone, self.padTip = 1, 0, "grid", true
    self:Update(true)
end

-- The bank in the window, or your bags again (only while the bank is open)
function B:SwitchView(to)
    if not self.bankOpen then self.view = "bags"; return end
    self.viewAt = self.viewAt or {}
    self.viewAt[self.view] = self.index                      -- (where you were, kept for coming back)
    self.filterAt = self.filterAt or {}
    self.filterAt[self.view] = self.filter                   -- (and its filter: each side keeps its own)
    self.view = to or (self.view == "bank" and "bags" or "bank")
    self.filter = self.filterAt[self.view] or 1
    self.only, self.scroll, self.zone, self.bagIndex = nil, 0, "grid", 1
    self.index = self.viewAt[self.view] or 1                 -- (the bank: its first slot the first time)
    self.padTip = true
    self:Update()
end

-- The mouse over a slot: chosen (A and X follow it)
function B:Pointed(button)
    if not self.open then return end
    for i, b in pairs(self.at) do
        if b == button then
            self.index, self.zone, self.padTip = i, "grid", true
            self:Mark()
            self:Bind()
            frame.legend:SetText(self:Legend())
            self:Tip(true)                               -- (the game's tooltip, put beside the window)
            B.CoverOver(button)                          -- (the mouse's clicks: the secure cover's)
            return
        end
    end
end

-- A: pick the chosen item up, or put down what you hold there (not protected: the game's own call, from your
-- press)
function B:PickUp()
    local e = self.zone == "grid" and self.list[self.index]
    if not e then return false end
    Try(C_Container.PickupContainerItem, e.bag, e.slot)
    return true
end

-- A bag of the bag row: "only" (X, or a right click) shows it alone (again: all of them); "put" (A, or a left
-- click) puts what you hold into it, or picks the bag up (to swap it for another)
function B:BagPress(how, i)
    local rec = self.bagList[i or self.bagIndex]
    if not rec then return end
    if i then self.bagIndex, self.zone = i, "bags" end
    if how == "only" then
        self.only = (self.only ~= rec.bag) and rec.bag or nil
        self.index, self.scroll = 1, 0
        self:Update()
        return
    end
    if InCombatLockdown() then return end
    local inv = InvSlot(rec.bag)
    if Try(rawget(_G, "CursorHasItem")) == true then
        if rec.bag == 0 then Try(rawget(_G, "PutItemInBackpack"))
        elseif inv then Try(rawget(_G, "PutItemInBag"), inv) end
    elseif inv then
        Try(rawget(_G, "PickupBagFromSlot"), inv)
    end
end

---------------------------------------------------------------------------
-- Y: more
---------------------------------------------------------------------------
local function MarkOf(id)
    local sell = ns.db.sell
    if sell.junk[id] then return L["junk"] end
    if sell.keep[id] then return L["kept"] end
    if sell.bank[id] then return L["for the bank"] end
    return L["no mark"]
end

-- An empty slot of a general bag in this view (for half a stack)
function B:FreeSlot()
    for _, t in ipairs(self.read and self.read.free or {}) do
        if t.family == 0 then return t end
    end
end

-- Half the stack into the first empty slot
function B:Split(e)
    if not (e and e.id and e.count > 1) or InCombatLockdown() then return false end
    local free = self:FreeSlot()
    if not free then ns.Say(L["No empty slot."]); return false end
    Try(C_Container.SplitContainerItem, e.bag, e.slot, math.floor(e.count / 2))
    Try(C_Container.PickupContainerItem, free.bag, free.slot)
    return true
end

function B:Sort()
    if self.view == "bank" then
        if ns.Inventory and ns.Inventory.SortBank() then ns.Say(L["Bank sorted."]) end
    elseif C_Container.SortBags then
        Try(C_Container.SortBags)
        ns.Say(L["Bags sorted."])
    end
end

-- Gear (or a cosmetic) you could see on yourself: the game's dressing room shows it on you, as a click with Ctrl
-- does with a mouse
function B.Dressable(e)
    if not (e and e.id and e.link) then return false end
    local byId = C_Item and C_Item.IsDressableItemByID
    if byId then return Try(byId, e.id) == true end
    return Try(rawget(_G, "IsDressableItem"), e.link) == true
end

function B.TryOn(link)
    local dress = rawget(_G, "DressUpItemLink") or rawget(_G, "DressUpLink")
    if link and dress then Try(dress, link) end
end

-- A bank bag slot for sale: what the next costs (nil: none, or this client has no way to buy one)
function B.BankSlotCost()
    local get, price = rawget(_G, "GetNumBankSlots"), rawget(_G, "GetBankSlotCost")
    if not (type(get) == "function" and type(price) == "function" and type(rawget(_G, "PurchaseSlot")) == "function") then
        return nil
    end
    local ok, n, full = pcall(get)
    n = Num(n)
    if not ok or n == nil or ns.Yes(full) then return nil end
    return Num(Try(price, n))
end

function B.AskBuySlot(cost)
    if InCombatLockdown() then return end
    ns.Dialog.Show("CCHUD_BUY_BANK_SLOT", ns.Money(cost))
end
ns.Dialog.Define("CCHUD_BUY_BANK_SLOT", {
    text = L["Buy a bank bag slot for %s?"], button1 = L["Buy"], button2 = CANCEL or "Cancel",
    OnAccept = function()                                    -- (the dialog closes first: then the game's own purchase)
        C_Timer.After(0, function()
            local buy = rawget(_G, "PurchaseSlot")
            if type(buy) == "function" and not InCombatLockdown() then pcall(buy) end
        end)
    end,
})

-- The choices for the chosen slot (or bag) and the place you are at: { { text, fn, stay = keep the menu up } }
function B:Choices()
    local out = {}
    local function add(text, fn, stay, macro) out[#out + 1] = { text = text, fn = fn, stay = stay, macro = macro } end
    local e = self.zone == "grid" and self.list[self.index] or nil
    local holding = Try(rawget(_G, "CursorHasItem")) == true
    if e and e.id and not InCombatLockdown() then
        -- what X does, and Equip by name where X would move it (at the bank, a vendor, the mailbox, a trade)
        local use = self:Words()
        local gear = e.classID == 2 or e.classID == 4
        local plain = not (self.merchantOpen or self.bankOpen or self.mailOpen or self.tradeOpen)
        if use then add((plain and gear) and L["Equip"] or use, function() end, nil, "/use " .. e.bag .. " " .. e.slot) end
        local name = e.link and e.link:match("%[(.-)%]")
        if gear and not plain and name then add(L["Equip"], function() end, nil, "/equip " .. name) end
    end
    if e and (e.id or holding) and not InCombatLockdown() then
        add(holding and L["Put down here"] or L["Pick up"], function() Try(C_Container.PickupContainerItem, e.bag, e.slot) end)
    end
    if e and e.id then
        if e.count > 1 then add(L["Split stack"], function() self:Split(e) end) end
        add(L["Mark: %s"]:format(MarkOf(e.id)), function()
            local V = ns.Vendor
            if V and V.MarkItem then V:MarkItem(e.id) end
            self.verdicts = {}
        end, true)
        if ns.ItemInfo and ns.ItemInfo.Show then add(L["Item details"], function() ns.ItemInfo:Show(e.id) end) end
        if B.Dressable(e) then add(L["Try on"], function() B.TryOn(e.link) end) end
        if B.CanDestroy(e) and not InCombatLockdown() then                 -- (in red: it can't be undone)
            add("|cffeb5461" .. L["Destroy"] .. "|r", function() self:AskDestroy(e) end)
        end
    end
    add(self.view == "bank" and L["Sort bank"] or L["Sort bags"], function() self:Sort() end)
    if self.bankOpen then
        add(self.view == "bank" and L["Show bags"] or L["Show bank"], function() self:SwitchView() end)
        local V = ns.Vendor
        local cost = B.BankSlotCost()
        if cost then add(L["Buy a bank bag slot (%s)"]:format(ns.Money(cost)), function() B.AskBuySlot(cost) end) end
        if V and V.Deposit then add(L["Quick Deposit"], function() V:Deposit() end) end
        if V and V.Withdraw then add(L["Quick Withdraw"], function() V:Withdraw() end) end
        if V and V.MaterialChoices then
            for _, to in ipairs({ "bank", "bags" }) do
                local list = V.MaterialChoices(to)
                if #list > 0 then
                    out[#out + 1] = { text = (to == "bank" and L["Deposit materials"] or L["Withdraw materials"]) .. "  >",
                                      sub = list }
                end
            end
        end
    end
    if self.merchantOpen and ns.Vendor and ns.Vendor.SmartSell then
        add(L["Sell advised items"], function() ns.Vendor:SmartSell() end)
    end
    return out
end

---------------------------------------------------------------------------
-- Destroy (Y, then a hold). It can't be undone, so: the item goes onto the cursor (as the game's own deleting has
-- it), a panel beside the window names it and its stack ("Destroy Iron Ore x13?"), and only a full hold of A (a
-- bar fills, B.HOLD seconds), then letting go, destroys it: the game's DeleteCursorItem from that release, your
-- own press (never in a fight). Let go early, B, the window closing, a fight: nothing destroyed, the item put
-- back. Not the game's DELETE popup: shown from our code it would carry the HUD into the game's dialog, and
-- typing DELETE is no work for a controller. Never offered for bound gear of an equipment set, or a quest item
-- a quest of yours still needs.
---------------------------------------------------------------------------
B.HOLD = 1.0

function B.CanDestroy(e)
    if not (e and e.id) then return false end
    local inSet = Try(C_Container.GetContainerItemEquipmentSetInfo, e.bag, e.slot)
    if inSet == true and e.bound then return false end
    -- a quest of yours still needs it: never (one it only starts is offered, with the game's red warning)
    local Q = ns.Quests
    local want = Q and Q.ItemWant and Try(Q.ItemWant, e.id)
    if want and not (type(want) == "table" and want.starts) then return false end
    return true
end

-- Is it the item on the cursor?
local function Holding(id)
    local kind, held = Try(rawget(_G, "GetCursorInfo"))
    return kind == "item" and held == id
end

-- Its name in its quality's colour, and how many: "Iron Ore x13"
function B.DestroyName(c)
    local name = c.link and c.link:match("%[(.-)%]") or ("item " .. tostring(c.id))
    local color = c.link and c.link:match("|c(%x%x%x%x%x%x%x%x)")
    local text = color and ("|c" .. color .. name .. "|r") or name
    if (c.count or 1) > 1 then text = text .. " x" .. c.count end
    return text
end

B.CONFIRM_W = 260

-- The question's panel: the item (icon, name, stack), a red warning where the game would give one, the bar that
-- fills while A is held, and two buttons: the hold (its words are the one instruction: "A Hold to destroy", then
-- "Let go to destroy" once the bar is full) and Keep. Each placed under the one before by its measured height.
local function ConfirmFrame()
    if frame.confirm then return frame.confirm end
    local f = CreateFrame("Frame", nil, frame)
    f:SetPoint("TOPRIGHT", frame, "TOPLEFT", -6, 0)
    f:SetSize(B.CONFIRM_W, 140)
    f:EnableMouse(true)
    f.back = Edge(f, "BACKGROUND", 0.03, 0.04, 0.07, 0.94)
    f.back:SetAllPoints(f)
    f.edge = Edge(f, "BORDER", 0.92, 0.33, 0.38, 0.7)               -- (a red rule: it can't be undone)
    f.edge:SetPoint("TOPLEFT", f, "TOPLEFT")
    f.edge:SetPoint("TOPRIGHT", f, "TOPRIGHT")
    f.edge:SetHeight(2)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(30, 30)
    f.icon:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -14)
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.text = ns.FontString(f, 11, "LEFT")
    f.text:SetWidth(B.CONFIRM_W - 12 - 30 - 10 - 12)
    if f.text.SetWordWrap then f.text:SetWordWrap(true) end
    f.warn = ns.FontString(f, 10, "LEFT")
    f.warn:SetWidth(B.CONFIRM_W - 24)
    f.warn:SetTextColor(0.92, 0.33, 0.38)
    if f.warn.SetWordWrap then f.warn:SetWordWrap(true) end
    f.track = Edge(f, "ARTWORK", 1, 1, 1, 0.12)
    f.track:SetSize(B.CONFIRM_W - 24, 4)
    f.fill = Edge(f, "OVERLAY", 0.92, 0.33, 0.38, 1)
    f.fill:SetPoint("TOPLEFT", f.track, "TOPLEFT", 0, 0)
    f.fill:SetHeight(4)
    f.fill:SetWidth(1)
    f.fill:Hide()
    local function Button(r, g, b, a)
        local x = CreateFrame("Button", nil, f)
        x:SetSize(B.CONFIRM_W - 24, 26)
        x.back = Edge(x, "BACKGROUND", r, g, b, a)
        x.back:SetAllPoints(x)
        x.text = ns.FontString(x, 10, "CENTER")
        x.text:SetPoint("LEFT", x, "LEFT", 6, 0)
        x.text:SetPoint("RIGHT", x, "RIGHT", -6, 0)
        if x.text.SetWordWrap then x.text:SetWordWrap(false) end
        return x
    end
    local hold = Button(0.92, 0.33, 0.38, 0.25)
    hold:RegisterForClicks("LeftButtonDown", "LeftButtonUp")
    hold:SetScript("OnClick", ns.Protect(function(_, _, down)
        if down then B:PadDown("PAD1") else B:ConfirmPad("PAD1") end
    end))
    f.hold = hold
    local keep = Button(1, 1, 1, 0.08)
    keep:SetScript("OnClick", ns.Protect(function() B:ConfirmPad("PAD2") end))
    f.keep = keep
    -- the bar fills while A (or the button) is held; full, the instruction becomes "let go"
    f:SetScript("OnUpdate", ns.Protect(function(self)
        local at = B.holdAt
        local k = at and math.min(1, ((GetTime and GetTime() or 0) - at) / B.HOLD) or 0
        if at then
            local w = Num(Try(self.track.GetWidth, self.track)) or (B.CONFIRM_W - 24)
            self.fill:SetWidth(math.max(1, w * k))
            self.fill:Show()
        else
            self.fill:Hide()
        end
        local full = k >= 1
        if full ~= self.full then
            self.full = full
            self.hold.text:SetText(B:HoldWords(full))
        end
    end))
    f:Hide()
    frame.confirm = f
    return f
end

-- The hold button's words: the one instruction at a time
function B:HoldWords(full)
    if full then return GOLD .. L["Let go to destroy"] .. "|r" end
    return Key("PAD1") .. " " .. L["Hold to destroy"]
end

-- Where the game's own deleting warns, so does this (in red): an item that starts a quest, a quest's item
function B.DestroyWarning(c)
    if c.questStart then return L["This item begins a quest."] end
    if c.quest then return L["This is a quest item."] end
    return nil
end

local function Height(fs, lines)
    local h = Num(Try(fs.GetStringHeight, fs))
    if h and h > 0 then return h end
    local _, size = Try(fs.GetFont, fs)
    return (Num(size) or 12) * 1.25 * (lines or 1)
end

function B:DrawConfirm()
    local c = self.confirm
    if not (c and frame) then return end
    local f = ConfirmFrame()
    f.icon:SetTexture(c.icon)
    f.text:SetText(L["Destroy %s?"]:format(B.DestroyName(c)))
    local warn = B.DestroyWarning(c)
    f.warn:SetText(warn or "")
    Showing(f.warn, warn ~= nil)
    f.full = false
    f.hold.text:SetText(self:HoldWords(false))
    f.keep.text:SetText(Key("PAD2") .. " " .. L["Keep"])
    f.fill:Hide()
    -- top to bottom, each under the one before, by what it measures (nothing laid over anything)
    local y = 14
    local titleH = Height(f.text, 2)
    f.text:ClearAllPoints()
    f.text:SetPoint("TOPLEFT", f, "TOPLEFT", 12 + 30 + 10, -(y + math.max(0, (30 - titleH) / 2)))
    y = y + math.max(30, titleH) + 8
    if warn then
        f.warn:ClearAllPoints()
        f.warn:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -y)
        y = y + Height(f.warn) + 8
    end
    f.track:ClearAllPoints()
    f.track:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -y)
    y = y + 4 + 12
    f.hold:ClearAllPoints()
    f.hold:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -y)
    y = y + 26 + 6
    f.keep:ClearAllPoints()
    f.keep:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -y)
    y = y + 26 + 12
    f:SetHeight(y)
    f:Show()
end

-- Y's Destroy: the item onto the cursor, and the question
function B:AskDestroy(e)
    if InCombatLockdown() or not B.CanDestroy(e) then return false end
    Try(rawget(_G, "ClearCursor"))
    Try(C_Container.PickupContainerItem, e.bag, e.slot)
    local Q = ns.Quests
    local want = Q and Q.ItemWant and Try(Q.ItemWant, e.id)
    self.confirm = { bag = e.bag, slot = e.slot, id = e.id, count = e.count, link = e.link, icon = e.icon,
                     quest = e.quest, questStart = e.questStart or (type(want) == "table" and want.starts) or nil }
    self.holdAt = nil
    GameTooltip:Hide()                                       -- (no tooltip over the question: it names the item)
    B.tipMine = false
    self:DrawConfirm()
    return true
end

-- Not destroyed: the item back where it was
function B:CancelDestroy()
    local c = self.confirm
    if not c then return end
    self.confirm, self.holdAt = nil, nil
    if Holding(c.id) then Try(rawget(_G, "ClearCursor")) end
    if frame and frame.confirm then frame.confirm:Hide() end
    if self.open then self:Tip() end                         -- (the item's tooltip back)
end

-- From the release of a full hold (your own press): the item on the cursor destroyed, by the game
function B:Destroy()
    local c = self.confirm
    if not c or InCombatLockdown() then self:CancelDestroy(); return false end
    local info = Try(C_Container.GetContainerItemInfo, c.bag, c.slot)
    if not (type(info) == "table" and Num(info.itemID) == c.id) then self:CancelDestroy(); return false end
    if not Holding(c.id) then
        Try(rawget(_G, "ClearCursor"))
        Try(C_Container.PickupContainerItem, c.bag, c.slot)
    end
    if not Holding(c.id) then self:CancelDestroy(); return false end
    local what = B.DestroyName(c)
    B.refused = false
    Try(rawget(_G, "DeleteCursorItem"))
    self.confirm, self.holdAt = nil, nil
    if frame and frame.confirm then frame.confirm:Hide() end
    if B.refused or Holding(c.id) then
        if Holding(c.id) then Try(rawget(_G, "ClearCursor")) end
        ns.Say(L["The game kept %s: destroy it from its own bags."]:format(what))
        self:Layout()
        return false
    end
    ns.Say(L["Destroyed %s."]:format(what))
    self:Update()
    return true
end

-- A pressed (the hold begins) and let go (a full hold destroys; early, nothing); B keeps it
function B:PadDown(key)
    if self.confirm and key == "PAD1" then self.holdAt = GetTime and GetTime() or 0 end
end

function B:ConfirmPad(key)
    if key == "PAD1" then
        local held = self.holdAt and ((GetTime and GetTime() or 0) - self.holdAt) or 0
        self.holdAt = nil
        if held >= B.HOLD then return self:Destroy() or true end
        self:DrawConfirm()                                   -- (let go early: kept, ask again)
    elseif key == "PAD2" then
        self:CancelDestroy()
        self:Layout()
    end
    return true
end

local function MenuRow(i)
    local menu = frame.menu
    local r = menu.rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, menu)
    r:SetSize(238, 22)
    r:SetPoint("TOPLEFT", menu, "TOPLEFT", 6, -6 - (i - 1) * 24)
    r.hl = Edge(r, "BACKGROUND", 1, 1, 1, 0.12)
    r.hl:SetAllPoints(r)
    r.text = ns.FontString(r, 11, "LEFT")
    r.text:SetPoint("LEFT", r, "LEFT", 6, 0)
    r:SetScript("OnClick", ns.Protect(function() B:MenuChoose(i) end))
    r:SetScript("OnEnter", ns.Protect(function() B.menuIndex = i; B:DrawMenu() end))
    menu.rows[i] = r
    return r
end

function B:DrawMenu()
    local menu = frame.menu
    local list = self.menu or {}
    self.menuIndex = ns.Clamp(self.menuIndex or 1, 1, math.max(1, #list))
    for i, c in ipairs(list) do
        local r = MenuRow(i)
        r.text:SetText(c.text)
        Showing(r.hl, i == self.menuIndex)
        r:Show()
    end
    for i = #list + 1, #menu.rows do menu.rows[i]:Hide() end
    menu:SetHeight(#list * 24 + 10)
    menu:Show()
    self:Bind()                                              -- (A does what the chosen row does)
end

-- Y's menu beside the window, on the side with room: its left, or its right where the window sits at the
-- screen's left edge (at the bank it takes the bank window's place there)
function B.MenuSide()
    local menu = frame.menu
    local left = Num(Try(frame.GetLeft, frame))
    local k = Num(Try(frame.GetEffectiveScale, frame)) or 1
    local uk = Num(Try(UIParent.GetEffectiveScale, UIParent)) or 1
    local room = left and left * k / uk or 1000
    menu:ClearAllPoints()
    if room < (Num(Try(menu.GetWidth, menu)) or 250) + 12 then
        menu:SetPoint("TOPLEFT", frame, "TOPRIGHT", 6, 0)
        return "right"
    end
    menu:SetPoint("TOPRIGHT", frame, "TOPLEFT", -6, 0)
    return "left"
end

function B:OpenMenu()
    if not frame then return end
    B.MenuSide()
    self.menu = self:Choices()
    self.menuIndex = 1
    GameTooltip:Hide()
    self:DrawMenu()
    self:Layout()
end

function B:CloseMenu()
    self.menu = nil
    if frame then frame.menu:Hide() end
    self:Update()
end

function B:MenuChoose(i)
    local c = self.menu and self.menu[i or self.menuIndex]
    if not c then return end
    if c.macro then return end                               -- (done by A, through the secure button)
    if c.sub then                                            -- a list of its own (by kind): in the same menu
        self.menu, self.menuIndex = c.sub, 1
        self:DrawMenu()
        return
    end
    c.fn()
    if c.stay and self.open then
        self.menu = self:Choices()
        self:DrawMenu()
    elseif self.open then
        self:CloseMenu()
    end
end

function B:MenuPad(key)
    if key == "PADDUP" then self.menuIndex = math.max(1, self.menuIndex - 1); self:DrawMenu()
    elseif key == "PADDDOWN" then self.menuIndex = math.min(#self.menu, self.menuIndex + 1); self:DrawMenu()
    elseif key == "PAD1" then self:MenuChoose()
    elseif key == "PAD2" or key == "PAD4" then self:CloseMenu()
    end
    return true
end

---------------------------------------------------------------------------
-- Listening
---------------------------------------------------------------------------
local pending = false
local function Soon(fresh)
    if fresh then B.verdicts = {} end
    if pending or not B.open then return end
    pending = true
    C_Timer.After(0.05, function()
        pending = false
        local ok, err = pcall(function() B:Update() end)
        if not ok then ns.Error(err) end
    end)
end

local FLAGS = { MERCHANT_SHOW = { "merchantOpen", true }, MERCHANT_CLOSED = { "merchantOpen", false },
                BANKFRAME_OPENED = { "bankOpen", true }, BANKFRAME_CLOSED = { "bankOpen", false },
                MAIL_SHOW = { "mailOpen", true }, MAIL_CLOSED = { "mailOpen", false },
                TRADE_SHOW = { "tradeOpen", true }, TRADE_CLOSED = { "tradeOpen", false } }

local events = CreateFrame("Frame")
events:SetScript("OnEvent", ns.Protect(function(_, event, who, what)
    if event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
        if who == ADDON and tostring(what):find("DeleteCursorItem", 1, true) then B.refused = true end
        return
    end
    local flag = FLAGS[event]
    if flag then
        B[flag[1]] = flag[2]
        if event == "BANKFRAME_OPENED" then
            local function Host()
                if B.bankOpen and B.HostBank(true) then
                    B.BankSide(false)
                    if B.open then B:SwitchView("bank") else B.view = "bank"; B:Show() end
                end
            end
            Host()                                           -- (at once: the game's window shows out of sight)
            C_Timer.After(0, Host)                           -- (and after the game's own showing, if it came first)
        end
        if event == "BANKFRAME_CLOSED" then
            B.HostBank(false)
            B.BankSide(false)
            B.viewAt = nil
            if B.view == "bank" then B.view, B.only, B.index = "bags", nil, 1 end
        end
        Soon(false)
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- (bindings can still be changed at this moment): with the window open and the controller its, the
        -- fight's set; else nothing of ours is bound
        ClearOverrideBindings(owner)
        B.bound = {}
        B.Secure:SetAttribute("combatbound", nil)
        -- (only with the game's combined bags open: their closing, in the fight, is what clears them again)
        if B.open and B.hasPad and not B.Yield() and Shown(rawget(_G, "ContainerFrameCombinedBags")) then
            B:FightBind()
        end
        B.fightStarting = true                                   -- (the cover too: it can't move in a fight)
        B.Uncover()
        B.fightStarting = nil
        if B.menu then B.menu = nil; if frame then frame.menu:Hide() end end
        B:CancelDestroy()
        if B.open and frame then frame.legend:SetText(B:Legend()) end
    elseif event == "PLAYER_REGEN_ENABLED" then
        B.Secure:SetAttribute("combatbound", nil)
        if B.open then
            B.bound = { fight = "over" }                         -- (ours again: bound afresh)
            B:Update()                                           -- (in order again, the secure table with it)
        else
            B.RememberDefault()
        end
    else
        Soon(event == "BAG_UPDATE_DELAYED" or event == "PLAYERBANKSLOTS_CHANGED")
        if event == "BAG_UPDATE_DELAYED" and not B.open and not B.remembering then   -- (what a fight would open on)
            B.remembering = true
            C_Timer.After(1, function()
                B.remembering = nil
                if not B.open then B.RememberDefault() end
            end)
        end
    end
end))
for _, e in ipairs({ "BAG_UPDATE_DELAYED", "ITEM_LOCK_CHANGED", "BAG_UPDATE_COOLDOWN", "PLAYERBANKSLOTS_CHANGED",
                     "PLAYERREAGENTBANKSLOTS_CHANGED", "PLAYER_MONEY", "CURSOR_CHANGED", "CURSOR_UPDATE",
                     "BAG_NEW_ITEMS_UPDATED", "MERCHANT_SHOW", "MERCHANT_CLOSED", "BANKFRAME_OPENED",
                     "BANKFRAME_CLOSED", "MAIL_SHOW", "MAIL_CLOSED", "TRADE_SHOW", "TRADE_CLOSED",
                     "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "ADDON_ACTION_BLOCKED",
                     "ADDON_ACTION_FORBIDDEN" }) do
    pcall(events.RegisterEvent, events, e)
end

-- Each frame: the game's bag windows (ours follows them), and LT / RT with another window beside; a few times a
-- second, whether a question of the HUD's has the controller (B:Bind changes nothing while all stays the same)
local since = 0
events:SetScript("OnUpdate", ns.Protect(function(_, dt)
    if not B.active then return end
    B.Follow(nil)
    if not B.open then return end
    since = since + (dt or 0)
    if since >= 0.1 then
        since = 0
        B:Bind()
    end
    B:FollowFocus(GetTime and GetTime() or 0)
end))

---------------------------------------------------------------------------
-- Turning on and off
---------------------------------------------------------------------------
function B:Apply(run)
    local want = (run and ns.db.bagWindow) and true or false
    if want then Hook() end
    if want == self.active then return end
    self.active = want
    for _, name in ipairs(B.GameFrames()) do B.Park(name, want) end
    local combined = rawget(_G, "ContainerFrameCombinedBags")
    if want and type(combined) == "table" then B.Secure:SetParent(combined) else B.Secure:SetParent(UIParent) end
    if want then
        self.gameWas = B.GameOpen()
        if self.gameWas then self:Show() end
        B.RememberDefault()
    else
        self:Hide()
        ClearOverrideBindings(owner)
        self.bound = {}
    end
end

-- The game's bag windows into our holder (and back): open there, they truly show, so the secure owner on them
-- follows them, but small and invisible, never in sight or under the mouse
B.parked = {}
function B.Park(name, on)
    local f = rawget(_G, name)
    if type(f) ~= "table" or not f.SetParent then return end
    if on and not B.parked[name] then
        B.parked[name] = f:GetParent() or UIParent
        f:SetParent(B.Holder)
    elseif not on and B.parked[name] then
        f:SetParent(B.parked[name])
        B.parked[name] = nil
    end
end

-- The game's own bag window's button line, as it shows (read only, never changed): what each of its buttons
-- says, gathered as it changes (for keeping ours in line with it; the debug report lists it)
B.nativeSeen, B.nativeLines = {}, {}
local function NativeLegend(bag)
    local legend = rawget(bag, "ContainerFrameCombinedBagsFooterinputLegend")
    if type(legend) ~= "table" then
        local footer = rawget(bag, "gamepadFooter") or rawget(bag, "footer")
        legend = type(footer) == "table" and rawget(footer, "inputLegend") or nil
    end
    return type(legend) == "table" and legend or nil
end
local function Bits(frame, text, art, depth)
    for _, r in ipairs({ Try(frame.GetRegions, frame) }) do
        if type(r) == "table" and Shown(r) then
            local kind = Try(r.GetObjectType, r)
            if kind == "FontString" then
                local s = Str(Try(r.GetText, r))
                if s then text[#text + 1] = s end
            elseif kind == "Texture" then
                local a = Str(Try(r.GetAtlas, r)) or ns.Plain(Try(r.GetTexture, r))
                if a then art[#art + 1] = tostring(a) end
            end
        end
    end
    if depth < 2 then
        for _, c in ipairs({ Try(frame.GetChildren, frame) }) do
            if type(c) == "table" and Shown(c) then Bits(c, text, art, depth + 1) end
        end
    end
end
function B.ReadNative()
    local bag = rawget(_G, "ContainerFrameCombinedBags")
    if not Shown(bag) then return end
    local legend = NativeLegend(bag)
    if not legend then return end
    for _, prompt in ipairs({ Try(legend.GetChildren, legend) }) do
        if type(prompt) == "table" and Shown(prompt) then
            local text, art = {}, {}
            Bits(prompt, text, art, 0)
            if #text > 0 then
                local line = table.concat(art, "+") .. " = " .. table.concat(text, " ")
                if not B.nativeSeen[line] and #B.nativeLines < 40 then
                    B.nativeSeen[line] = true
                    B.nativeLines[#B.nativeLines + 1] = line
                end
            end
        end
    end
end
local looker, lookedAt = CreateFrame("Frame"), 0
looker:SetScript("OnUpdate", ns.Protect(function(_, dt)
    lookedAt = lookedAt + (dt or 0)
    if lookedAt < 1 then return end
    lookedAt = 0
    B.ReadNative()
end))

-- For the debug report: what this client's slots are made of, and who has the controller
function B.Describe()
    local out = {}
    out[#out + 1] = ("on %s, open %s, view %s, filter %s, zone %s, slot %d, controller %s"):format(
        tostring(B.active), tostring(B.open), B.view, B.FILTERS[B.filter].key, B.zone, B.index,
        B.hasPad and "ours" or "the other window's")
    out[#out + 1] = ("slots: %s, the bag from the parent: %s"):format(tostring(B.template or "none made yet"),
        tostring(B.fromParent))
    do  -- the bank's containers, as the bag row lists them (to check them against the game's own bank window)
        local parts = {}
        for _, bag in ipairs(B.Containers("bank")) do
            parts[#parts + 1] = ("%s:%d"):format(tostring(bag), Slots(bag))
        end
        out[#out + 1] = ("bank containers (id:slots): %s; slots bought %s; constants: bags %s, equipped %s, bank bags %s"):format(
            table.concat(parts, " "), tostring((rawget(_G, "GetNumBankSlots") and Try(rawget(_G, "GetNumBankSlots"))) or "?"),
            tostring(rawget(_G, "NUM_BAG_SLOTS")), tostring(rawget(_G, "NUM_TOTAL_EQUIPPED_BAG_SLOTS")),
            tostring(rawget(_G, "NUM_BANKBAGSLOTS")))
    end
    local combined = rawget(_G, "ContainerFrameCombinedBags")
    out[#out + 1] = ("the game's combined bags: %s, %s"):format(combined and "here" or "none",
        combined and (Shown(combined) and "open" or "closed") or "-")
    local mode = rawget(_G, "GamepadMode")
    local m = type(mode) == "table" and rawget(mode, "FrameControlsManager")
    if type(m) == "table" then
        local f = rawget(m, "focusedFrame")
        out[#out + 1] = ("gamepad focus: %s, UI focused %s"):format(
            type(f) == "table" and tostring(Try(f.GetName, f) or "(unnamed)") or "none", tostring(rawget(m, "isUIFocused")))
    end
    local seen = {}
    for key in pairs(B.layersSeen) do seen[#seen + 1] = key end
    table.sort(seen)
    out[#out + 1] = "template layers found on and put out: " .. (#seen > 0 and table.concat(seen, ", ") or "none")
    -- what a slot with an item shows, layer by layer (the art of each), to tell what draws on it
    for _, b in pairs(B.at) do
        local s = B.slotOf[b]
        if s and Try(C_Container.GetContainerItemID, s.bag, s.slot) and Shown(b) then
            local regions = { Try(b.GetRegions, b) }
            for _, r in ipairs(regions) do
                if type(r) == "table" and Shown(r) then
                    local art = Try(r.GetAtlas, r) or Try(r.GetTexture, r)
                    local layer, sub = Try(r.GetDrawLayer, r)
                    out[#out + 1] = ("  shown on %s: %s %s %s/%s alpha %.2f"):format(tostring(Try(b.GetName, b)),
                        tostring(Try(r.GetObjectType, r)), tostring(art), tostring(layer), tostring(sub),
                        Num(Try(r.GetAlpha, r)) or 1)
                end
            end
            break
        end
    end
    out[#out + 1] = ("the game's own bags' buttons seen: %d"):format(#B.nativeLines)
    for _, line in ipairs(B.nativeLines) do out[#out + 1] = "  native: " .. line end
    local keys = {}
    for key, what in pairs(B.bound) do keys[#keys + 1] = key .. " = " .. what end
    table.sort(keys)
    for _, k in ipairs(keys) do out[#out + 1] = k end
    return out
end
if ns.Debug and ns.Debug.SECTIONS then
    table.insert(ns.Debug.SECTIONS, { "bags", function() return B.Describe() end })
end

ns.RegisterCheck(function(row, run, db)
    local want = (run and db.bagWindow) and true or false
    row(want and "your bags open in the HUD's bag window" or "your bags open in the game's own windows", B.active == want)
end)

ns.RegisterModule("bags", B)
