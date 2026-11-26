-- ControllerCam HUD: what to do with the item you point at, in the game's own bags and bank.
-- Hold the right stick button on an item (a tap still sorts or moves, Inventory.lua), use its key binding, or
-- /cchud itemmenu: Try on (the game's dressing room), your mark (junk, kept, bank), the item's details, and
-- destroy. The bags and the bank stay the game's, and so does its item menu: nothing of ours is put into it
-- (entries added to a gamepad menu of the game's were found to leave the game refusing its own actions on this
-- client, and which menu its bags use is not known: /cchud bagprobe looks). Our question is asked in a window of
-- our own (ns.Dialog, Core.lua).
--
-- Destroying can't be undone, so: out of combat only, never gear of an equipment set that is bound to you, an
-- item you marked as kept, one a quest of yours still needs, or anything rare or better (for those the game asks
-- you to type DELETE: use its own way). It is asked apart, on a button of its own after two others ("More",
-- "Destroy"), with Keep on the button that closes: pressing the same button again and again never gets there.

local ADDON, ns = ...
local L = ns.L

local A = { active = false }
ns.ItemActions = A

ns.RegisterSetting({
    key = "padActions", kind = "boolean", default = true, command = "padactions", section = "Bags, bank and vendor",
    label = "Hold R3 on an item for its actions",
    tip = "while your bags or the bank are open, holding the right stick button on an item asks what to do with it: try it on, mark it, see its details or destroy it. A tap still sorts or moves, and the game's own bags and item menu stay as they are",
})

A.KEEP_QUALITY = 3                  -- rare and better: the game's own destroying asks you to type DELETE

local function Fn(t, name)
    if type(t) ~= "table" then return nil end
    local f = t[name]
    return type(f) == "function" and f or nil
end
local function Global(name)
    local f = rawget(_G, name)
    return type(f) == "function" and f or nil
end
local function Try(fn, ...)
    if not fn then return nil end
    local ok, a, b = pcall(fn, ...)
    if ok then return a, b end
end
local function Num(v) v = ns.Plain(v); return type(v) == "number" and v or nil end

---------------------------------------------------------------------------
-- The item you point at: the frame under the mouse (the controller's cursor moves it), or, where that names no
-- item, the button the game's controller cursor is on (read only)
---------------------------------------------------------------------------
-- The bag and slot a button of the game's stands for: its own methods say (a bag's item button, or the newer
-- bank's), asked of the button and a few frames up
local function SlotOf(frame)
    for _ = 1, 4 do
        if type(frame) ~= "table" then return nil end
        local bag, slot
        if Fn(frame, "GetBagID") and Fn(frame, "GetID") then
            bag, slot = Num(Try(frame.GetBagID, frame)), Num(Try(frame.GetID, frame))
        end
        if not (bag and slot) and Fn(frame, "GetBankTabID") and Fn(frame, "GetContainerSlotID") then
            bag, slot = Num(Try(frame.GetBankTabID, frame)), Num(Try(frame.GetContainerSlotID, frame))
        end
        if bag and slot and slot > 0 then return bag, slot end
        frame = Fn(frame, "GetParent") and Try(frame.GetParent, frame) or nil
    end
end
A.SlotOf = SlotOf

local function CursorButton()
    local nav = rawget(_G, "SmartNavigation")
    local current = Fn(nav, "GetCurrentButton")
    if not current then return nil end
    if Fn(nav, "IsCursorHidden") then
        local ok, hidden = pcall(nav.IsCursorHidden, nav)
        if not ok or ns.IsSecret(hidden) or hidden then return nil end      -- (not in use: nothing is pointed at)
    end
    local button = Try(current, nav)
    if type(button) == "table" and ns.ShownPlain(button) then return button end
end

function A:Target()
    local frame
    if Global("GetMouseFoci") then
        local foci = Try(GetMouseFoci)
        frame = type(foci) == "table" and foci[1] or nil
    elseif Global("GetMouseFocus") then
        frame = Try(GetMouseFocus)
    end
    local bag, slot = SlotOf(frame)
    if bag then return bag, slot, "the pointer" end
    bag, slot = SlotOf(CursorButton())
    if bag then return bag, slot, "the game's cursor" end
end

-- What is in that slot, as far as the game says plainly (nil: nothing, or a secret)
function A.Entry(bag, slot)
    local info = Try(Fn(C_Container, "GetContainerItemInfo"), bag, slot)
    if type(info) ~= "table" then return nil end
    local id = Num(info.itemID)
    if not id then return nil end
    local link = ns.Plain(info.hyperlink)
    local quest = Try(Fn(C_Container, "GetContainerItemQuestInfo"), bag, slot)
    local isQuest, starts
    if type(quest) == "table" then
        isQuest = ns.Yes(quest.isQuestItem)
        starts = quest.questID ~= nil and not ns.IsSecret(quest.isActive) and not quest.isActive and not isQuest
    end
    return { bag = bag, slot = slot, id = id, link = type(link) == "string" and link or nil,
             count = Num(info.stackCount) or 1, quality = Num(info.quality), bound = ns.Yes(info.isBound),
             locked = ns.Yes(info.isLocked), quest = isQuest, questStart = starts or nil }
end

-- Its name in its quality's colour, and how many: "Iron Ore x13"
function A.Name(e)
    local name = e.link and e.link:match("%[(.-)%]")
    if not name then
        name = Try(Fn(C_Item, "GetItemNameByID"), e.id)
        if type(name) ~= "string" or ns.IsSecret(name) then name = "item " .. e.id end
    end
    local q = e.quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[e.quality]
    if q then name = ("|cff%02x%02x%02x%s|r"):format(q.r * 255, q.g * 255, q.b * 255, name) end
    if e.count > 1 then name = name .. " x" .. e.count end
    return name
end

function A.MarkWord(id)
    local sell = ns.db.sell
    if sell.junk[id] then return L["junk"] end
    if sell.keep[id] then return L["kept"] end
    if sell.bank[id] then return L["bank"] end
    return L["no mark"]
end

---------------------------------------------------------------------------
-- Try on: the game's dressing room, as a click with Ctrl does with a mouse
---------------------------------------------------------------------------
local function DressUp() return Global("DressUpItemLink") or Global("DressUpLink") end

function A.Dressable(e)
    if not (e and e.link and DressUp()) then return false end
    local byId = Fn(C_Item, "IsDressableItemByID")
    if byId then return ns.Yes(Try(byId, e.id)) end
    return ns.Yes(Try(Global("IsDressableItem"), e.link))
end

---------------------------------------------------------------------------
-- Destroy
---------------------------------------------------------------------------
function A.CanDestroy(e)
    if not e or InCombatLockdown() or e.locked then return false end
    if not (Global("DeleteCursorItem") and Global("GetCursorInfo") and Global("ClearCursor")
            and Fn(C_Container, "PickupContainerItem")) then return false end
    if not e.quality or e.quality >= A.KEEP_QUALITY then return false end
    if ns.db.sell.keep[e.id] then return false end
    local inSet = Try(Fn(C_Container, "GetContainerItemEquipmentSetInfo"), e.bag, e.slot)
    if ns.Yes(inSet) and e.bound then return false end
    -- a quest of yours still needs it: never (one it only starts is offered, with a warning)
    local want = ns.Quests and ns.Quests.ItemWant and Try(ns.Quests.ItemWant, e.id)
    if want and not (type(want) == "table" and want.starts) then return false end
    return true
end

-- Is that item on the cursor?
local function Holding(id)
    local kind, held = Try(Global("GetCursorInfo"))
    return not ns.IsSecret(kind) and not ns.IsSecret(held) and kind == "item" and held == id
end

-- The slot still holds what was asked about
local function Same(e)
    local now = A.Entry(e.bag, e.slot)
    return now and now.id == e.id and now.count == e.count and now or nil
end

-- From your own press on the question's button: the item onto the cursor, and the game deletes it
function A.Destroy(e)
    if InCombatLockdown() then return false end
    local now = Same(e)
    if not (now and A.CanDestroy(now)) then
        ns.Say(L["That item has changed: point at it again."])
        return false
    end
    local what = A.Name(now)
    Try(Global("ClearCursor"))                               -- (nothing else may be on the cursor)
    Try(C_Container.PickupContainerItem, e.bag, e.slot)
    if not Holding(e.id) then
        Try(Global("ClearCursor"))
        ns.Say(L["The game kept %s: destroy it from its own bags."]:format(what))
        return false
    end
    Try(Global("DeleteCursorItem"))
    if Holding(e.id) then
        Try(Global("ClearCursor"))
        ns.Note("item actions: the game would not delete item %d", e.id)
        ns.Say(L["The game kept %s: destroy it from its own bags."]:format(what))
        return false
    end
    ns.Note("item actions: destroyed item %d", e.id)
    ns.Say(L["Destroyed %s."]:format(what))
    return true
end

---------------------------------------------------------------------------
-- The question (A, X, Y; B closes)
---------------------------------------------------------------------------
local function Details(e)
    if ns.ItemInfo and ns.ItemInfo.Show then ns.ItemInfo:Show(e.id) end
end

function A:AskDestroy(e)
    if not A.CanDestroy(e) then return false end
    ns.Dialog.Define("CCHUD_ITEM_DESTROY", {
        text = "%s\n\n%s",
        button2 = L["Keep"], button4 = L["Destroy"],       -- (A has no button here: it only closes)
        Footer = function()
            if e.questStart then return "|cffeb5461" .. L["This item begins a quest."] .. "|r" end
            if e.quest then return "|cffeb5461" .. L["This is a quest item."] .. "|r" end
        end,
        OnExtra = function() A.Destroy(e) end,
    })
    return ns.Dialog.Show("CCHUD_ITEM_DESTROY", L["Destroy %s?"]:format(A.Name(e)), L["It can't be undone."])
end

-- The second page: what did not fit the first
function A:More(e)
    local details = A.Dressable(e)                           -- (otherwise Item details is on the first page)
    local destroy = A.CanDestroy(e)
    ns.Dialog.Define("CCHUD_ITEM_MORE", {
        text = "%s",
        button1 = details and L["Item details"] or nil,
        button3 = destroy and L["Destroy"] or nil,
        button2 = L["Back"],
        OnAccept = details and function() Details(e) end or nil,
        OnAlt = destroy and function() A:AskDestroy(e) end or nil,
        OnCancel = function(_, _, reason)                    -- (B: back to the first page)
            if reason == "clicked" then C_Timer.After(0, function() A:Show(Same(e)) end) end
        end,
    })
    return ns.Dialog.Show("CCHUD_ITEM_MORE", A.Name(e))
end

function A:Show(e)
    if not e then return false end
    local dress = A.Dressable(e)
    local more = dress or A.CanDestroy(e)
    ns.Dialog.Define("CCHUD_ITEM", {
        text = "%s\n%s",
        button1 = dress and L["Try on"] or L["Item details"],
        button3 = L["Change mark"],
        button4 = more and L["More"] or nil,
        button2 = L["Close"],
        OnAccept = function()
            if dress then
                if InCombatLockdown() or not e.link then return end
                local ok, err = pcall(DressUp(), e.link)
                if not ok then ns.Note("item actions: the dressing room would not open: %s", tostring(err)) end
            else
                Details(e)
            end
        end,
        OnAlt = function()
            local V = ns.Vendor
            if V and V.MarkItem then V:MarkItem(e.id) end
            A:Show(e)                                        -- (asked again: the next mark is one press away)
        end,
        OnExtra = more and function() A:More(e) end or nil,
    })
    self.shown = e
    return ns.Dialog.Show("CCHUD_ITEM", A.Name(e), L["Your mark"] .. ": " .. A.MarkWord(e.id))
end

-- Asks about the item you point at. false: nothing pointed at (or not now), nothing happened
function A:Open()
    if not self.active or InCombatLockdown() or not ns.Dialog then return false end
    local bag, slot, how = self:Target()
    local e = bag and A.Entry(bag, slot) or nil
    if not e then
        ns.Note("item actions: nothing pointed at")
        return false
    end
    self.last = ("item %d in bag %d slot %d, by %s"):format(e.id, bag, slot, how)
    ns.Note("item actions: %s", self.last)
    return self:Show(e)
end

local function ByHand()
    if not A:Open() then
        ns.Say(InCombatLockdown() and L["Not in a fight."] or L["Point at an item first."])
    end
end
function ControllerCamHUD_ItemActions() ns.Protect(ByHand)() end
BINDING_NAME_CCHUD_ITEMACTIONS = L["Item actions: try on, mark, details or destroy the item you point at"]

ns.RegisterCommand("itemmenu", ByHand, "/cchud itemmenu",
    "ask what to do with the item you point at: try on, mark, details, destroy")

function A.Describe()
    return {
        ("hold R3 %s; try on: %s %s; destroy: DeleteCursorItem %s, PickupContainerItem %s; the game's cursor: %s")
            :format(tostring(ns.db and ns.db.padActions), tostring(Global("DressUpItemLink") ~= nil),
                tostring(Global("DressUpLink") ~= nil), tostring(Global("DeleteCursorItem") ~= nil),
                tostring(Fn(C_Container, "PickupContainerItem") ~= nil),
                tostring(Fn(rawget(_G, "SmartNavigation"), "GetCurrentButton") ~= nil)),
        "last asked about: " .. tostring(A.last or "nothing yet"),
    }
end

function A:Apply(run)
    self.active = run and true or false
    local d = ns.Dialog
    if not self.active and d and d.visible and d.visible.which:find("^CCHUD_ITEM") then d.Close("override") end
end

ns.RegisterModule("itemactions", A)
