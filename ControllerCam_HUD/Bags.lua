-- ControllerCam HUD: your bags in one window, made for the controller.
-- In place of the game's bag windows (the Gamepad UI's "Combined Backpack", or a window for each bag), while the
-- HUD runs and the setting is on:
--   * one grid of everything you carry, in the order of your bags (the game's own sorting decides it); the empty
--     slots gathered at the end as one slot that counts them (one for each kind of bag: a quiver's, a herb
--     bag's); your bags in a row of their own under the grid, never in among the items.
--   * quick filters along the top, LB and RB: All, Equipment, Consumables, Trade goods, Quest, Junk, New, and the
--     HUD's own advice (Market.lua): Sell (what a vendor or the auction house should have) and Keep.
--   * the d-pad moves; A uses the item (the game's right click: at a vendor it sells, at the bank it moves, at the
--     mailbox it attaches); X sells at a vendor, and elsewhere picks the item up and puts it down again (onto
--     another slot, the free slot, or a bag in the bag row); Y for more (split a stack, mark it, its details,
--     sorting, the bank); B closes. On the bag row, A shows that bag alone (again: all of them), X puts what you
--     hold into it, or picks the bag up to swap it. While the bank is open, the back button (or Y) shows the
--     bank in the same window. With another window open beside it (a vendor, the bank, the mailbox), LT or RT
--     hands the controller to that window and back.
--   * the mouse works as ever: every slot is the game's own item button (click, drag, Shift to split).
--
-- How, and why this way rather than dressing up the game's combined window:
--   * Every slot is one of the game's own item buttons (ContainerFrameItemButtonTemplate), made once for its bag
--     and slot and never handed another: its id is the slot, its parent's id the bag, as the game's own bag
--     windows have it. A and X are key bindings that click that button, so what happens is the game's own click
--     from your own press: nothing that could be refused ever runs in the HUD's name.
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

local ADDON, ns = ...
local L, C = ns.L, ns.colors

local B = { active = false, open = false, view = "bags", filter = 1, index = 1, top = 0, zone = "grid",
            bagIndex = 1, hasPad = true, buttons = {}, holders = {}, slotOf = {}, at = {}, bagList = {},
            verdicts = {}, bound = {}, list = {}, counts = {}, triggerWas = true,
            extra = setmetatable({}, { __mode = "k" }), kind = setmetatable({}, { __mode = "k" }) }
ns.Bags = B

ns.RegisterSetting({
    key = "bagWindow", kind = "boolean", default = true, command = "bagwindow", section = "Bags, bank and vendor",
    label = "One bag window with quick filters",
    tip = "your bags in one window of the HUD's own, in place of the game's: every item together, the empty slots gathered at the end, your bags in a row of their own, and quick filters along the top (LB and RB). The bank too, while it is open. Off: the game's own bags",
})
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
           "PADRSHOULDER", "PADBACK" }        -- (the back button only while the bank is open)
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
    local _, _, _, equipLoc, _, classID = Try(get, id)
    return Num(classID), Str(equipLoc)
end

-- One slot: what is in it ({ bag, slot, id, count, quality, link, icon, locked, bound, kind, quest, new }), or nil
function B.Slot(bag, slot)
    local info = Try(C_Container.GetContainerItemInfo, bag, slot)
    local id = type(info) == "table" and Num(info.itemID)
    if not id then return nil end
    local e = { bag = bag, slot = slot, id = id, count = Num(info.stackCount) or 1, quality = Num(info.quality),
                link = Str(info.hyperlink), icon = ns.Plain(info.iconFileID), locked = ns.Yes(info.isLocked),
                bound = ns.Yes(info.isBound) }
    e.classID, e.equipLoc = Instant(id)
    e.kind = B.Kind(e.classID)
    local q = C_Container.GetContainerItemQuestInfo and Try(C_Container.GetContainerItemQuestInfo, bag, slot)
    e.quest = e.kind == "quest" or (type(q) == "table" and (ns.Yes(q.isQuestItem) or Num(q.questID) ~= nil)) or false
    if C_NewItems and Try(C_NewItems.IsNewItem, bag, slot) == true then e.new = true end
    if e.icon == nil and C_Item and C_Item.GetItemIconByID then e.icon = Try(C_Item.GetItemIconByID, id) end
    return e
end

-- Everything in a view: { items = { slot entries in bag order }, free = { { bag, slot (the first empty one),
-- free = how many, family } }, bags = { { bag, size, used } }, total, used }. only: one bag's alone.
function B.Read(view, only)
    local out = { items = {}, free = {}, bags = {}, total = 0, used = 0 }
    local byFamily = {}
    local bags = B.Containers(view)
    local keyring = view ~= "bank" and B.Keyring()
    if keyring then bags[#bags + 1] = keyring end
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
    local general = byFamily[0]                       -- the general bags' free slot first
    if general and out.free[1] ~= general then
        for i, t in ipairs(out.free) do if t == general then table.remove(out.free, i) end end
        table.insert(out.free, 1, general)
    end
    return out
end

---------------------------------------------------------------------------
-- The filters
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

-- Junk: grey, unless you marked it to keep; anything you marked as junk
function B.IsJunk(e)
    local sell = ns.db and ns.db.sell
    if sell and sell.junk[e.id] then return true end
    if sell and sell.keep[e.id] then return false end
    return e.quality == 0
end

function B.Matches(e, key)
    if key == "all" then return true end
    if key == "junk" then return B.IsJunk(e) end
    if key == "new" then return e.new == true end
    if key == "quest" then return e.quest == true end
    if key == "sell" then return B.SOLD[B.Verdict(e) or ""] == true end
    if key == "keep" then return B.KEPT[B.Verdict(e) or ""] == true end
    return e.kind == key
end

-- What the grid shows under a filter: the items that match, then the free slots (where things are put)
function B.List(read, key)
    local list = {}
    for _, e in ipairs(read.items) do
        if B.Matches(e, key) then list[#list + 1] = e end
    end
    for _, t in ipairs(read.free) do list[#list + 1] = t end
    return list
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
-- Where the d-pad goes from slot i of n, cols to a row: the new slot, or "bags" (down from the last row, to
-- the bag row). Left and right run on into the row before or after.
function B.Step(i, way, n, cols)
    if n <= 0 then return way == "down" and "bags" or 1 end
    if way == "left" then return math.max(1, i - 1) end
    if way == "right" then return math.min(n, i + 1) end
    if way == "up" then return (i - cols >= 1) and (i - cols) or i end
    if way == "down" then
        if i + cols <= n then return i + cols end
        local lastRow = math.floor((n - 1) / cols) * cols + 1
        if i < lastRow then return n end               -- a shorter last row under it: its last slot
        return "bags"
    end
    return i
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

-- Without the game's template (a client that has none): a plain button doing the same with the game's calls
local function PlainButton(name, holder, bag, slot)
    local b = CreateFrame("Button", name, holder)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(b)
    local count = ns.FontString(b, 10, "RIGHT")
    count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
    local function Pick() Try(C_Container.PickupContainerItem, bag, slot) end
    b:SetScript("OnClick", ns.Protect(function(_, mouse)
        if mouse == "RightButton" then Try(C_Container.UseContainerItem, bag, slot) else Pick() end
    end))
    b:SetScript("OnDragStart", ns.Protect(Pick))
    b:SetScript("OnReceiveDrag", ns.Protect(Pick))
    b:SetScript("OnEnter", ns.Protect(function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        Try(GameTooltip.SetBagItem, GameTooltip, bag, slot)
        GameTooltip:Show()
    end))
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
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
    else
        made, ex.icon, ex.count = PlainButton(name, holder, bag, slot)
        kind = "plain"
    end
    B.template = kind
    made:SetSize(B.SIZE, B.SIZE)
    -- our own pieces, on our own button: the slot's backing (the same for every slot, full or empty), how many
    -- free slots, a dot on a new item, junk's coin
    ex.back = B.SlotBack(made)
    ex.free = ns.FontString(made, 11, "CENTER")
    ex.free:SetPoint("CENTER", made, "CENTER", 0, 0)
    ex.free:SetTextColor(unpack(C.muted))
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

-- Draw a slot: its item (or nothing, for the free slots, with how many there are)
local function Paint(b, e)
    local ex = B.extra[b] or {}
    local item = e.id ~= nil
    if B.kind[b] == "plain" then
        ex.icon:SetTexture(item and e.icon or "Interface\\PaperDoll\\UI-Backpack-EmptySlot")
        ex.count:SetText(item and e.count > 1 and tostring(e.count) or "")
    else
        Call(b, "SetItemButtonTexture", item and e.icon or nil)
        Call(b, "SetItemButtonCount", item and e.count or 0)
        Call(b, "SetItemButtonQuality", item and e.quality or nil, item and e.link or nil)
        local desat = rawget(_G, "SetItemButtonDesaturated")
        if type(desat) == "function" then Try(desat, b, item and e.locked or false) end
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
    if ex.free then ex.free:SetText(item and "" or tostring(e.free or "")) end
    if ex.new then Showing(ex.new, item and e.new == true) end
    if ex.junk then Showing(ex.junk, item and B.IsJunk(e)) end
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

local function Place()
    frame:ClearAllPoints()
    local pos = ns.db and ns.db.bagPos
    if pos then frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", pos.x, pos.y)
    else frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -60, 170) end
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
        local right, bottom, edge = self:GetRight(), self:GetBottom(), UIParent:GetRight()
        if Num(right) and Num(bottom) and Num(edge) then ns.db.bagPos = { x = right - edge, y = bottom } end
        Place()
    end))
    frame.back = Edge(frame, "BACKGROUND", 0.03, 0.04, 0.07, 0.92)
    frame.back:SetAllPoints(frame)
    for _, side in ipairs({ "TOP", "BOTTOM" }) do
        local t = Edge(frame, "BORDER", 0.55, 0.62, 0.75, 0.6)
        t:SetPoint(side .. "LEFT", frame, side .. "LEFT")
        t:SetPoint(side .. "RIGHT", frame, side .. "RIGHT")
        t:SetHeight(1)
    end
    frame.title = ns.FontString(frame, 13, "LEFT")
    frame.title:SetPoint("LEFT", frame, "TOPLEFT", B.PAD, -15)          -- (level with the close button)
    frame.title:SetTextColor(0.98, 0.82, 0.3)
    -- the game's own close button (its look), for the mouse; it does what B does
    local ok, close = pcall(CreateFrame, "Button", nil, frame, "UIPanelCloseButtonNoScripts")
    if not (ok and close) then
        close = CreateFrame("Button", nil, frame)
        close.text = ns.FontString(close, 11, "CENTER")
        close.text:SetPoint("CENTER", close, "CENTER", 0, 0)
        close.text:SetText("x")
    end
    close:SetSize(22, 22)
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
    close:SetScript("OnClick", ns.Protect(function() B:Close() end))
    frame.close = close
    frame.money = ns.FontString(frame, 10, "RIGHT")
    frame.money:SetPoint("RIGHT", close, "LEFT", -6, 0)
    frame.title:SetPoint("RIGHT", frame.money, "LEFT", -8, 0)
    if frame.title.SetWordWrap then frame.title:SetWordWrap(false) end
    -- the filters: the chosen one in the middle, its neighbours either side, LB and RB at the ends
    local row = CreateFrame("Frame", nil, frame)
    row:SetPoint("TOPLEFT", frame, "TOPLEFT", B.PAD, -32)
    row:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -B.PAD, -32)
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
    for way, anchor in pairs({ [-1] = "LEFT", [1] = "RIGHT" }) do      -- (the mouse: either half of the row)
        local hit = CreateFrame("Button", nil, row)
        hit:SetPoint("TOP" .. anchor, row, "TOP" .. anchor, 0, 0)
        hit:SetSize((B.COLS * B.STEP - B.GAP) / 2, 30)
        hit:SetScript("OnClick", ns.Protect(function() B:Filter(way) end))
    end
    frame.filters = row
    frame.grid = CreateFrame("Frame", nil, frame)
    frame.grid:SetPoint("TOPLEFT", frame, "TOPLEFT", B.PAD, -B.TOP)
    frame.grid:SetSize(B.COLS * B.STEP - B.GAP, B.STEP)
    frame.empty = ns.FontString(frame.grid, 10, "LEFT")
    frame.empty:SetTextColor(unpack(C.muted))
    if frame.empty.SetWordWrap then frame.empty:SetWordWrap(false) end
    -- more rows than fit: a slim bar in the margin right of the grid, its bright part the rows in sight
    frame.track = Edge(frame, "ARTWORK", 1, 1, 1, 0.1)
    frame.track:SetWidth(2)
    frame.track:SetPoint("TOPLEFT", frame.grid, "TOPRIGHT", 5, 0)
    frame.track:SetPoint("BOTTOMLEFT", frame.grid, "BOTTOMRIGHT", 5, 0)
    frame.thumb = Edge(frame, "OVERLAY", 1, 0.82, 0.3, 0.8)
    frame.thumb:SetWidth(2)
    frame.bags = CreateFrame("Frame", nil, frame)
    frame.bags:SetSize(B.COLS * B.STEP - B.GAP, B.BAG)
    frame.bagButtons = {}
    frame.space = ns.FontString(frame.bags, 10, "RIGHT")
    frame.space:SetPoint("RIGHT", frame.bags, "RIGHT", 0, 0)
    frame.space:SetTextColor(unpack(C.muted))
    frame.rule = Edge(frame, "BORDER", 0.55, 0.62, 0.75, 0.25)          -- between the grid and the bags
    frame.rule:SetHeight(1)
    frame.rule:SetPoint("BOTTOMLEFT", frame.bags, "TOPLEFT", 0, B.RULE)
    frame.rule:SetPoint("BOTTOMRIGHT", frame.bags, "TOPRIGHT", 0, B.RULE)
    frame.legend = ns.FontString(frame, 10, "LEFT")
    frame.legend:SetPoint("TOPLEFT", frame.bags, "BOTTOMLEFT", 0, -10)
    frame.legend:SetPoint("TOPRIGHT", frame.bags, "BOTTOMRIGHT", 0, -10)
    if frame.legend.SetWordWrap then frame.legend:SetWordWrap(true) end
    frame.sel = Ring(frame)
    frame.sel:SetFrameLevel((frame:GetFrameLevel() or 1) + 20)
    frame.sel:Hide()
    -- Y: more, beside the window
    local menu = CreateFrame("Frame", nil, frame)
    menu:SetPoint("TOPRIGHT", frame, "TOPLEFT", -6, 0)
    menu:SetSize(250, 40)
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
        kb:SetScript("OnClick", ns.Protect(function() B:Pad(key) end))
        B.keyButtons[key] = kb
    end
end

-- A bag of the bag row: its icon, how full it is; A shows it alone, X puts into it (or picks the bag up)
local function BagButton(i)
    local b = frame.bagButtons[i]
    if b then return b end
    b = CreateFrame("Button", nil, frame.bags)
    b:SetSize(B.BAG, B.BAG)
    b:SetPoint("LEFT", frame.bags, "LEFT", (i - 1) * B.STEP, 0)
    B.SlotBack(b)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints(b)
    b.chosen = Edge(b, "OVERLAY", 1, 0.82, 0.3, 0.3)          -- (shown alone; how full it is: its tooltip)
    b.chosen:SetAllPoints(b)
    b:SetScript("OnClick", ns.Protect(function(_, mouse) B:BagPress(mouse == "RightButton" and "a" or "x", i) end))
    b:SetScript("OnDragStart", ns.Protect(function() B:BagPress("x", i) end))
    b:SetScript("OnReceiveDrag", ns.Protect(function() B:BagPress("x", i) end))
    b:SetScript("OnEnter", ns.Protect(function(self) B:BagTip(self, i) end))
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.bagButtons[i] = b
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
function B.TipBeside()
    GameTooltip:SetOwner(frame, "ANCHOR_NONE")
    GameTooltip:ClearAllPoints()
    local x = Num(Try(frame.GetCenter, frame))
    local w = Num(Try(UIParent.GetWidth, UIParent))
    if x and w and x < w / 2 then
        GameTooltip:SetPoint("TOPLEFT", frame, "TOPRIGHT", 8, 0)
        B.tipSide = "right"
    else
        GameTooltip:SetPoint("TOPRIGHT", frame, "TOPLEFT", -8, 0)
        B.tipSide = "left"
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
-- What A and X do on the chosen slot, in words (nil: nothing)
function B:Words()
    local e = self.list[self.index]
    local holding = Try(rawget(_G, "CursorHasItem")) == true
    if not (e and e.id) then return nil, holding and L["Put down"] or nil end    -- (the free slot)
    if self.merchantOpen then return L["Sell"], L["Sell"] end
    local a = L["Use"]
    if self.bankOpen then a = self.view == "bank" and L["To bags"] or L["To bank"]
    elseif self.mailOpen then a = L["Attach"]
    elseif self.tradeOpen then a = L["Trade"] end
    return a, holding and L["Put down"] or L["Pick up"]
end

-- The buttons' line under the window: only what the buttons do here, each with its own button's icon
function B:Legend()
    local parts = {}
    local function add(key, text) parts[#parts + 1] = Key(key) .. " " .. text end
    if InCombatLockdown() then return GREY .. L["Controller buttons return after the fight."] .. "|r" end
    if not self.hasPad then
        return GOLD .. L["%s or %s: back to bags"]:format(Key("PADLTRIGGER"), Key("PADRTRIGGER")) .. "|r"
    end
    if self.menu then
        add("PAD1", L["Choose"]); add("PAD2", L["Back"])
        return table.concat(parts, "   ")
    end
    if self.zone == "bags" then
        local rec = self.bagList[self.bagIndex]
        add("PAD1", self.only and L["All bags"] or L["Only this bag"])
        if Try(rawget(_G, "CursorHasItem")) == true then add("PAD3", L["Put in"])
        elseif rec and InvSlot(rec.bag) then add("PAD3", L["Pick up bag"]) end
    else
        local a, x = self:Words()
        if a and a == x then parts[#parts + 1] = Key("PAD1") .. " " .. Key("PAD3") .. " " .. a    -- (a vendor)
        else
            if a then add("PAD1", a) end
            if x then add("PAD3", x) end
        end
    end
    add("PAD4", L["More"]); add("PAD2", L["Close"])
    if self.bankOpen then add("PADBACK", self.view == "bank" and L["Bags"] or L["Bank"]) end
    local text = table.concat(parts, "   ")
    if B.OtherWindow() then
        text = text .. "\n" .. GREY .. L["%s or %s: other window"]:format(Key("PADLTRIGGER"), Key("PADRTRIGGER")) .. "|r"
    end
    return text
end

function B:Selected()
    if self.zone ~= "grid" then return nil end
    return self.at[self.index]
end

function B:Layout()
    if not (frame and self.open) then return end
    local list, cols, rows = self.list or {}, B.COLS, B.Rows()
    local n = #list
    self.index = ns.Clamp(self.index, 1, math.max(1, n))
    local row = math.floor((self.index - 1) / cols)
    if row < self.top then self.top = row elseif row >= self.top + rows then self.top = row - rows + 1 end
    self.top = ns.Clamp(self.top, 0, math.max(0, math.ceil(n / cols) - rows))
    local first = self.top * cols + 1
    local last = math.min(n, first + rows * cols - 1)
    self.at = {}
    local used = {}
    for i = first, last do
        local e = list[i]
        local b = B.Button(e.bag, e.slot)
        used[b] = true
        local k = i - first
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", frame.grid, "TOPLEFT", (k % cols) * B.STEP, -math.floor(k / cols) * B.STEP)
        Paint(b, e)
        b:Show()
        self.at[i] = b
    end
    for _, b in pairs(self.buttons) do
        if not used[b] then b:Hide() end
    end
    local shownRows = math.max(1, math.ceil((last - first + 1) / cols))
    local gridH = shownRows * B.STEP - B.GAP
    frame.grid:SetHeight(gridH)
    -- nothing of this kind: said beside the free slot
    local items = n - #(self.read and self.read.free or {})
    frame.empty:ClearAllPoints()
    frame.empty:SetPoint("LEFT", frame.grid, "TOPLEFT", math.min(n, cols - 1) * B.STEP + 6, -B.SIZE / 2)
    frame.empty:SetPoint("RIGHT", frame.grid, "TOPRIGHT", 0, -B.SIZE / 2)
    frame.empty:SetText(items == 0 and L["Nothing here."] or "")
    -- more rows than fit: the bar beside the grid, its bright part where you are
    local total = math.ceil(n / cols)
    local scrolls = total > rows
    Showing(frame.track, scrolls)
    Showing(frame.thumb, scrolls)
    if scrolls then
        frame.thumb:ClearAllPoints()
        frame.thumb:SetPoint("TOPLEFT", frame.track, "TOPLEFT", 0, -gridH * self.top / total)
        frame.thumb:SetHeight(math.max(6, gridH * rows / total))
    end
    self.scrolls = scrolls
    -- the bag row, under the grid
    frame.bags:ClearAllPoints()
    frame.bags:SetPoint("TOPLEFT", frame.grid, "BOTTOMLEFT", 0, -(B.RULE * 2 + 1))
    self.bagList = self.read and self.read.bags or {}
    self.bagIndex = ns.Clamp(self.bagIndex, 1, math.max(1, #self.bagList))
    for i, rec in ipairs(self.bagList) do
        local bb = BagButton(i)
        bb.icon:SetTexture(BagIcon(rec))
        if rec.bag == 0 then bb.icon:SetTexCoord(0, 1, 0, 1) else bb.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
        Showing(bb.chosen, self.only == rec.bag)
        bb:Show()
    end
    for i = #self.bagList + 1, #frame.bagButtons do frame.bagButtons[i]:Hide() end
    local read = self.read or { total = 0, used = 0 }
    frame.space:SetText(L["%d free"]:format(math.max(0, read.total - read.used)))
    -- the title, the money, the filters
    local title = self.view == "bank" and L["Bank"] or L["Bags"]
    if self.only then
        for _, rec in ipairs(self.bagList) do
            if rec.bag == self.only then title = title .. GREY .. "  " .. B.BagName(rec) .. "|r" end
        end
    end
    frame.title:SetText(title)
    local money = Num(Try(GetMoney))
    frame.money:SetText(money and ns.MoneyColored and ns.MoneyColored(money) or "")
    local F, nf = B.FILTERS, #B.FILTERS
    local function name(i)
        local f = F[(i - 1) % nf + 1]
        return f.text, self.counts[f.key] or 0
    end
    local cur, count = name(self.filter)
    frame.filters.cur:SetText(GOLD .. cur .. "|r  " .. GREY .. count .. "|r")
    frame.filters.lb:SetText(Key("PADLSHOULDER"))
    frame.filters.rb:SetText(Key("PADRSHOULDER"))
    for i, d in ipairs(frame.filters.dots) do
        if i == self.filter then d:SetColorTexture(1, 0.82, 0.3, 1) else d:SetColorTexture(1, 1, 1, 0.3) end
    end
    frame.legend:SetText(self:Legend())
    local legendH = Num(Try(frame.legend.GetStringHeight, frame.legend)) or 14
    frame:SetHeight(B.TOP + gridH + B.RULE * 2 + 1 + B.BAG + 10 + legendH + 12)
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

-- The tooltip of the chosen slot, when the d-pad chose it (the mouse has the game's own)
function B:Tip()
    if not (self.open and self.padTip) then return end
    local target = self.zone == "bags" and frame.bagButtons[self.bagIndex] or self:Selected()
    if not target then GameTooltip:Hide(); return end
    if self.zone == "bags" then return self:BagTip(target, self.bagIndex) end
    local e = self.list[self.index]
    B.TipBeside()
    if e and e.id then
        Try(GameTooltip.SetBagItem, GameTooltip, e.bag, e.slot)
    elseif e then
        GameTooltip:SetText(L["%d free slots"]:format(e.free or 0))
    end
    GameTooltip:Show()
end

-- Read the bags again (keepRead: only the filter or the view changed) and draw
function B:Update(keepRead)
    if not (frame and self.open) then return end
    if not keepRead or not self.read then
        local V = ns.Vendor
        if V and V.BeginBatch then V.BeginBatch() end
        local ok, err = pcall(function()
            self.read = B.Read(self.view, self.only)
            self.counts = B.Counts(self.read)
        end)
        if V and V.EndBatch then V.EndBatch() end
        if not ok then ns.Error(err) end
    end
    self.list = B.List(self.read, B.FILTERS[self.filter].key)
    self:Layout()
    self:Tip()
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
    self.index, self.top, self.filter, self.bagIndex = 1, 0, 1, 1
    self.verdicts, self.read = {}, nil
    self.padTip = true
    self.triggerWas = true                 -- (a trigger resting a little in is no press)
    frame:Show()
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
    self.open, self.menu = false, nil
    self:ClearNew()
    if frame then
        frame:Hide()
        frame.menu:Hide()
    end
    local owner = Try(GameTooltip.GetOwner, GameTooltip)
    if owner and (B.slotOf[owner] or (frame and owner ~= GameTooltip and Try(owner.GetParent, owner) == frame.bags)) then
        GameTooltip:Hide()
    end
    self:Bind()
end

-- B (where it is not the game's own binding), or the window's close button: ours closes, and the game's with
-- it where it is open
function B:Close()
    if self.menu then return self:CloseMenu() end
    local was = B.GameOpen()
    self:Hide()
    if was and not InCombatLockdown() then Try(rawget(_G, "CloseAllBags")) end
    self.gameWas = B.GameOpen()
end

---------------------------------------------------------------------------
-- The controller
---------------------------------------------------------------------------
local owner = CreateFrame("Frame")

local function Same(a, b)
    for k, v in pairs(a) do if b[k] ~= v then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

-- The bindings wanted now: key -> "CLICK button:mouse button" or the name of one of the game's bindings.
-- A and X click the chosen slot's own button (the game's click); the rest tell the window.
-- A window of the HUD's that takes the controller over ours while it is up: one of its questions ("Sell 12
-- items?"), an item's details. Ours steps aside and takes its buttons back as it goes.
function B.Yield()
    if ns.Dialog and ns.Dialog.visible then return true end
    local info = ns.ItemInfo and ns.ItemInfo.frame
    return Shown(info)
end

function B:Wanted()
    local want = {}
    if not (self.active and self.open and self.hasPad) or InCombatLockdown() or B.Yield() then return want end
    for _, key in ipairs(B.KEYS) do
        if key ~= "PADBACK" or self.bankOpen then want[key] = "CLICK ControllerCamHUD_BagKey_" .. key .. ":LeftButton" end
    end
    local b = not self.menu and self:Selected()
    local name = b and b:GetName()
    if name then
        want.PAD1 = "CLICK " .. name .. ":RightButton"
        want.PAD3 = "CLICK " .. name .. ":" .. (self.merchantOpen and "RightButton" or "LeftButton")
    end
    -- B is the game's own: the game closes its combined window, ours goes with it
    if not self.menu and Shown(rawget(_G, "ContainerFrameCombinedBags")) then want.PAD2 = "OPENALLBAGS" end
    return want
end

function B:Bind()
    if InCombatLockdown() then return end
    local want = self:Wanted()
    if Same(want, self.bound) then return end
    ClearOverrideBindings(owner)
    for key, what in pairs(want) do
        local button, mouse = what:match("^CLICK ([^:]+):(.+)$")
        if button then SetOverrideBindingClick(owner, true, key, button, mouse)
        else SetOverrideBinding(owner, true, key, what) end
    end
    self.bound = want
end

-- A key of the window's (the rest of the time they are all yours)
function B:Pad(key)
    if not self.open then return false end
    ns.Note("bags: button %s", tostring(key))
    if self.menu then return self:MenuPad(key) end
    local ways = { PADDUP = "up", PADDDOWN = "down", PADDLEFT = "left", PADDRIGHT = "right" }
    if ways[key] then self:Move(ways[key])
    elseif key == "PADLSHOULDER" then self:Filter(-1)
    elseif key == "PADRSHOULDER" then self:Filter(1)
    elseif key == "PAD1" then if self.zone == "bags" then self:BagPress("a") end   -- (a slot's A is its own button)
    elseif key == "PAD3" then if self.zone == "bags" then self:BagPress("x") end
    elseif key == "PAD4" then self:OpenMenu()
    elseif key == "PAD2" then self:Close()
    elseif key == "PADBACK" then self:SwitchView()
    else return false end
    return true
end

function B:Move(way)
    self.padTip = true
    if self.zone == "bags" then
        local n = #self.bagList
        if way == "left" then self.bagIndex = math.max(1, self.bagIndex - 1)
        elseif way == "right" then self.bagIndex = math.min(n, self.bagIndex + 1)
        elseif way == "up" then
            local count = #self.list
            self.zone = "grid"
            local lastRow = math.floor(math.max(0, count - 1) / B.COLS) * B.COLS + 1
            self.index = math.min(math.max(1, count), lastRow + self.bagIndex - 1)
        end
    else
        local to = B.Step(self.index, way, #self.list, B.COLS)
        if to == "bags" then
            if #self.bagList > 0 then
                self.zone = "bags"
                self.bagIndex = ns.Clamp(((self.index - 1) % B.COLS) + 1, 1, #self.bagList)
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
    self.index, self.top, self.zone, self.padTip = 1, 0, "grid", true
    self:Update(true)
end

-- The bank in the window, or your bags again (only while the bank is open)
function B:SwitchView(to)
    if not self.bankOpen then self.view = "bags"; return end
    self.view = to or (self.view == "bank" and "bags" or "bank")
    self.only, self.index, self.top, self.zone, self.bagIndex = nil, 1, 0, "grid", 1
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
            self:Tip()                                   -- (the game's tooltip, put beside the window)
            return
        end
    end
end

-- A bag of the bag row: "a" shows it alone (again: all of them); "x" puts what you hold into it, or picks the
-- bag up (to swap it for another)
function B:BagPress(how, i)
    local rec = self.bagList[i or self.bagIndex]
    if not rec then return end
    if i then self.bagIndex, self.zone = i, "bags" end
    if how == "a" then
        self.only = (self.only ~= rec.bag) and rec.bag or nil
        self.index, self.top = 1, 0
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

-- The choices for the chosen slot (or bag) and the place you are at: { { text, fn, stay = keep the menu up } }
function B:Choices()
    local out = {}
    local function add(text, fn, stay) out[#out + 1] = { text = text, fn = fn, stay = stay } end
    local e = self.zone == "grid" and self.list[self.index] or nil
    local holding = Try(rawget(_G, "CursorHasItem")) == true
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
    end
    add(self.view == "bank" and L["Sort bank"] or L["Sort bags"], function() self:Sort() end)
    if self.bankOpen then
        add(self.view == "bank" and L["Show bags"] or L["Show bank"], function() self:SwitchView() end)
        local V = ns.Vendor
        if V and V.Deposit then add(L["Deposit marked items"], function() V:Deposit() end) end
    end
    if self.merchantOpen and ns.Vendor and ns.Vendor.SmartSell then
        add(L["Sell advised items"], function() ns.Vendor:SmartSell() end)
    end
    return out
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
end

function B:OpenMenu()
    if not frame then return end
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
events:SetScript("OnEvent", ns.Protect(function(_, event)
    local flag = FLAGS[event]
    if flag then
        B[flag[1]] = flag[2]
        if event == "BANKFRAME_CLOSED" and B.view == "bank" then B.view, B.only = "bags", nil end
        Soon(false)
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- (bindings can still be cleared at this moment): the controller is yours in a fight
        ClearOverrideBindings(owner)
        B.bound = {}
        if B.menu then B.menu = nil; if frame then frame.menu:Hide() end end
        if B.open and frame then frame.legend:SetText(B:Legend()) end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if B.open then B:Layout() end
    else
        Soon(event == "BAG_UPDATE_DELAYED" or event == "PLAYERBANKSLOTS_CHANGED")
    end
end))
for _, e in ipairs({ "BAG_UPDATE_DELAYED", "ITEM_LOCK_CHANGED", "BAG_UPDATE_COOLDOWN", "PLAYERBANKSLOTS_CHANGED",
                     "PLAYERREAGENTBANKSLOTS_CHANGED", "PLAYER_MONEY", "CURSOR_CHANGED", "CURSOR_UPDATE",
                     "BAG_NEW_ITEMS_UPDATED", "MERCHANT_SHOW", "MERCHANT_CLOSED", "BANKFRAME_OPENED",
                     "BANKFRAME_CLOSED", "MAIL_SHOW", "MAIL_CLOSED", "TRADE_SHOW", "TRADE_CLOSED",
                     "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
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
    local other = B.OtherWindow()
    local down = false
    for _, key in ipairs(B.SWITCH) do
        if IsKeyDown and IsKeyDown(key) then down = true end
    end
    if down and not B.triggerWas and other and not InCombatLockdown() then
        B.hasPad = not B.hasPad
        B:Layout()
    elseif not other and not B.hasPad then
        B.hasPad = true                                      -- nothing else open: the controller is the bags'
        B:Layout()
    end
    B.triggerWas = down
end))

---------------------------------------------------------------------------
-- Turning on and off
---------------------------------------------------------------------------
function B:Apply(run)
    local want = (run and ns.db.bagWindow) and true or false
    if want then Hook() end
    if want == self.active then return end
    self.active = want
    for _, name in ipairs(B.GameFrames()) do ns.SetBlizzardHidden(name, want) end
    if want then
        self.gameWas = B.GameOpen()
        if self.gameWas then self:Show() end
    else
        self:Hide()
        ClearOverrideBindings(owner)
        self.bound = {}
    end
end

-- For the debug report: what this client's slots are made of, and who has the controller
function B.Describe()
    local out = {}
    out[#out + 1] = ("on %s, open %s, view %s, filter %s, zone %s, slot %d, controller %s"):format(
        tostring(B.active), tostring(B.open), B.view, B.FILTERS[B.filter].key, B.zone, B.index,
        B.hasPad and "ours" or "the other window's")
    out[#out + 1] = ("slots: %s, the bag from the parent: %s"):format(tostring(B.template or "none made yet"),
        tostring(B.fromParent))
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
