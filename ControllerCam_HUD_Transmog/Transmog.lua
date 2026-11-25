-- ControllerCam HUD: a Sets tab in the game's Transmogrify window.
-- The window has a Sets tab of its own, between Items and Custom Sets, that this client keeps hidden: the game
-- knows no sets you could wear here. We show that tab (the game's own button, so it sits where it belongs and LB
-- and RB reach it like the others) and fill its page with sets from your collection:
--   * gear that shares a name, read from the game's item names: Green Iron Helm, Green Iron Gauntlets... make
--     "Green Iron"; Boots of the Bear, Gloves of the Bear... make "... of the Bear". Three slots or more.
--   * any set the game itself knows (C_TransmogSets) that you can wear.
-- Each set says how many of its pieces you have, and which are missing. Picking one (A, or a click) puts every
-- piece you have collected on your outfit's slots in one go, as changes the window shows but has not kept; the
-- slots of missing pieces stay as they were. X (or the Undo button) puts back what those slots had before.
-- Nothing is kept or paid for until you press the game's own Apply.
--
-- How it stays out of the game's way:
--   * the tab is only shown (Show), after the game's own UpdateTabs hid it; the game lays it out and its gamepad
--     tab row finds it. Nothing of the game's is written to.
--   * the list is ours, inside the tab's page. The controller's cursor is the game's: it reaches our rows like any
--     button and clicks them through its own taint barrier. It is put on the first set with the game's
--     SmartNavigation:SetTargetButtonForFrame (made for addons), and the tab's own empty page is left out of its
--     reach with SmartNavigation_MarkFrameIgnored (the same).
--   * a client whose game does have sets of its own keeps its tab: we stay away from it.
-- Switched off (or the HUD stops), the tab is hidden again and the page given back as it was.

local ADDON = ...
local ns = ControllerCamHUD.ns            -- the HUD's own namespace: this file is one of its modules (Modules.lua)
local L = ns.L

local TS = { rows = {}, MIN_PIECES = 3, BATCH = 60, focus = 1 }
ns.TransmogSets = TS



local APPEARANCE = 0                                     -- Enum.TransmogType.Appearance
local NO_OPTION = 0                                      -- Enum.TransmogOutfitSlotOption.None
local ROW, PANE_H, ICON = 44, 132, 34
-- The armour slots a set can fill, in the order the game lists them: its collection type, its outfit slot, the
-- game's own name for it. The outfit slots are read from the game when it says (GetSlotGroupInfo).
TS.SLOTS = {
    { cat = 1, slot = 0, name = "HEADSLOT" }, { cat = 2, slot = 1, name = "SHOULDERSLOT" },
    { cat = 3, slot = 3, name = "BACKSLOT" }, { cat = 4, slot = 4, name = "CHESTSLOT" },
    { cat = 5, slot = 6, name = "SHIRTSLOT" }, { cat = 6, slot = 5, name = "TABARDSLOT" },
    { cat = 7, slot = 7, name = "WRISTSLOT" }, { cat = 8, slot = 8, name = "HANDSSLOT" },
    { cat = 9, slot = 9, name = "WAISTSLOT" }, { cat = 10, slot = 10, name = "LEGSSLOT" },
    { cat = 11, slot = 11, name = "FEETSLOT" },
}

local function Assigned()
    local E = Enum and Enum.TransmogOutfitDisplayType
    return E and E.Assigned or 1
end

local function Text(v) return type(v) == "string" and not ns.IsSecret(v) and v ~= "" and v or nil end
local function Num(v) v = ns.Plain(v); return type(v) == "number" and v or nil end

---------------------------------------------------------------------------
-- Slots: the game's outfit slot for each kind of gear
---------------------------------------------------------------------------
function TS.SlotMap()
    if TS.slotMap then return TS.slotMap end
    local map = {}
    for i, s in ipairs(TS.SLOTS) do
        local name = rawget(_G, s.name)
        if not Text(name) and C_TransmogCollection and C_TransmogCollection.GetCategoryInfo then
            local ok, n = pcall(C_TransmogCollection.GetCategoryInfo, s.cat)
            name = ok and n or nil
        end
        map[s.cat] = { cat = s.cat, slot = s.slot, name = Text(name) or s.name, order = i }
    end
    local O = C_TransmogOutfitInfo
    local ok, groups = false, nil
    if O and O.GetSlotGroupInfo then ok, groups = pcall(O.GetSlotGroupInfo) end
    if ok and type(groups) == "table" then
        for _, g in ipairs(groups) do
            for _, info in ipairs(type(g) == "table" and type(g.appearanceSlotInfo) == "table" and g.appearanceSlotInfo or {}) do
                local cat, slot = Num(info.collectionType), Num(info.slot)
                if cat and slot and map[cat] and not ns.Yes(info.isSecondary) and Num(info.type) == APPEARANCE then
                    map[cat].slot = slot
                end
            end
        end
    end
    TS.slotMap = map
    return map
end

---------------------------------------------------------------------------
-- Sets by name: the part of a name the pieces share
---------------------------------------------------------------------------
local function Words(name)
    local w = {}
    for word in name:gmatch("%S+") do w[#w + 1] = word end
    return w
end

local function Chars(name)
    local c = {}
    for ch in name:gmatch("[%z\1-\127\194-\244][\128-\191]*") do c[#c + 1] = ch end
    return c
end

-- What a set could be called, by one piece's name: { key =, show = }. With words: all but the last (Green Iron
-- Helm: "Green Iron"), or all but the first (Boots of the Bear: "... of the Bear"). A name written without spaces
-- (Chinese) loses one to three characters from its end.
function TS.Keys(name)
    local out = {}
    local w = Words(name)
    if #w >= 2 then
        local head, tail = table.concat(w, " ", 1, #w - 1), table.concat(w, " ", 2)
        out[#out + 1] = { key = "P:" .. head:lower(), show = head }
        out[#out + 1] = { key = "S:" .. tail:lower(), show = "... " .. tail }
    elseif #w == 1 and name:find("[\128-\255]") then
        local c = Chars(name)
        for cut = 1, 3 do
            if #c - cut >= 2 then
                local s = table.concat(c, "", 1, #c - cut)
                out[#out + 1] = { key = "P:" .. s, show = s }
            end
        end
    end
    return out
end

-- items: { name =, slot =, have = (collected and usable) ... }. Each item joins the name it shares with the most
-- slots (at least MIN_PIECES); a set keeps one piece a slot, one you have before one you lack.
function TS.GroupByName(items)
    local reach = {}
    for _, it in ipairs(items) do
        it.keys = TS.Keys(it.name)
        for _, k in ipairs(it.keys) do
            local r = reach[k.key]
            if not r then r = { slots = {}, n = 0, show = k.show }; reach[k.key] = r end
            if not r.slots[it.slot] then r.slots[it.slot] = true; r.n = r.n + 1 end
        end
    end
    local sets, order = {}, {}
    for _, it in ipairs(items) do
        local best
        for _, k in ipairs(it.keys) do
            local n = reach[k.key].n
            if n >= TS.MIN_PIECES and (not best or n > reach[best].n) then best = k.key end
        end
        if best then
            local s = sets[best]
            if not s then
                s = { key = best, name = reach[best].show, pieces = {} }
                sets[best] = s
                order[#order + 1] = s
            end
            local had = s.pieces[it.slot]
            if not had or (it.have and not had.have) then s.pieces[it.slot] = it end
        end
    end
    local out = {}
    for _, s in ipairs(order) do
        local n = 0
        for _ in pairs(s.pieces) do n = n + 1 end
        if n >= TS.MIN_PIECES then out[#out + 1] = s end
    end
    return out
end

---------------------------------------------------------------------------
-- Reading the collection (a few appearances a frame, while the tab is open)
---------------------------------------------------------------------------
local function SourceIcon(id, itemID)
    local C = C_TransmogCollection
    if C and C.GetSourceIcon and id then
        local ok, icon = pcall(C.GetSourceIcon, id)
        if ok and ns.Plain(icon) then return icon end
    end
    if itemID and GetItemIcon then
        local ok, icon = pcall(GetItemIcon, itemID)
        if ok and ns.Plain(icon) then return icon end
    end
end

-- One appearance of a kind of gear: an item for each named source. A piece is yours when its look is collected
-- (through this item or another with the same look) and you can wear it; then `use` is the source to put on.
function TS:Read(scan, cat, a)
    if type(a) ~= "table" or ns.Yes(a.isHideVisual) then return end
    local visual = Num(a.visualID)
    local slot = TS.SlotMap()[cat]
    if not (visual and slot) then return end
    local ok, sources = pcall(C_TransmogCollection.GetAppearanceSources, visual, cat)
    if not ok or type(sources) ~= "table" then return end
    local owned
    for _, s in ipairs(sources) do
        if type(s) == "table" and ns.Yes(s.isCollected) and Num(s.sourceID) then owned = Num(s.sourceID); break end
    end
    local look = ns.Yes(a.isCollected) or owned ~= nil
    local usable = a.isUsable == nil or ns.Yes(a.isUsable)
    for _, s in ipairs(sources) do
        local name, id = type(s) == "table" and Text(s.name), type(s) == "table" and Num(s.sourceID)
        if name and id then
            local use = ns.Yes(s.isCollected) and id or owned or (look and id) or nil
            local item = { name = name, slot = slot.slot, cat = cat, source = id, itemID = Num(s.itemID),
                           quality = Num(s.quality), have = use ~= nil and usable, cant = use ~= nil and not usable,
                           use = usable and use or nil }
            local key = slot.slot .. ":" .. name
            local had = scan.byKey[key]
            if not had then
                scan.byKey[key] = item
                scan.items[#scan.items + 1] = item
            elseif item.have and not had.have then
                for k, v in pairs(item) do had[k] = v end
            end
        end
    end
end

-- The sets the game knows, that you could wear: { name =, pieces = { [slot] = item }, game = true }
function TS.GameSets()
    local S, C = C_TransmogSets, C_TransmogCollection
    if not (S and S.GetAllSets and S.GetAllSourceIDs and C and C.GetSourceInfo) then return {} end
    local ok, all = pcall(S.GetAllSets)
    if not ok or type(all) ~= "table" then return {} end
    local map, out = TS.SlotMap(), {}
    for _, info in ipairs(all) do
        local id = type(info) == "table" and Num(info.setID)
        if id and info.validForCharacter ~= false and not ns.Yes(info.hiddenUntilCollected) then
            local okIDs, ids = pcall(S.GetAllSourceIDs, id)
            local set = { key = "G:" .. id, name = Text(info.name) or ("#" .. id), pieces = {}, game = true }
            local extra = Text(info.description) or Text(info.label)
            if extra then set.name = set.name .. " (" .. extra .. ")" end
            for _, src in ipairs(okIDs and type(ids) == "table" and ids or {}) do
                local okS, s = pcall(C.GetSourceInfo, src)
                local slot = okS and type(s) == "table" and map[Num(s.categoryID) or -1]
                if slot then
                    local mine = ns.Yes(s.isCollected)
                    if not mine and C.GetAppearanceInfoBySource then
                        local okA, a = pcall(C.GetAppearanceInfoBySource, src)
                        mine = okA and type(a) == "table" and ns.Yes(a.appearanceIsCollected) or false
                    end
                    local item = { name = Text(s.name) or "?", slot = slot.slot, cat = slot.cat, source = src,
                                   itemID = Num(s.itemID), quality = Num(s.quality), have = mine, use = mine and src or nil }
                    local had = set.pieces[slot.slot]
                    if not had or (item.have and not had.have) then set.pieces[slot.slot] = item end
                end
            end
            if next(set.pieces) then out[#out + 1] = set end
        end
    end
    return out
end

-- A set as the list shows it: its pieces in slot order, how many you have, which are missing
function TS.Summary(set)
    local bySlot = {}
    for _, s in pairs(TS.SlotMap()) do bySlot[s.slot] = s end
    local list = {}
    for slot, it in pairs(set.pieces) do
        local s = bySlot[slot]
        list[#list + 1] = { slot = slot, slotName = s and s.name or tostring(slot), order = s and s.order or 99,
                            name = it.name, use = it.use, have = it.have, cant = it.cant, quality = it.quality,
                            source = it.source, itemID = it.itemID }
    end
    table.sort(list, function(a, b) return a.order < b.order end)
    local have, missing = 0, {}
    for _, p in ipairs(list) do
        if p.have then have = have + 1 else missing[#missing + 1] = p.slotName end
    end
    set.list, set.have, set.total, set.missing = list, have, #list, missing
    for _, p in ipairs(list) do
        if p.have then set.icon = SourceIcon(p.source, p.itemID); if set.icon then break end end
    end
    return set
end

-- Every set you have a piece of: whole sets first, then by how much of each you have, then by name
function TS.Collect(items)
    local seen, out = {}, {}
    local function add(set)
        TS.Summary(set)
        local id = set.name:lower()
        if set.have > 0 and not seen[id] then seen[id] = true; out[#out + 1] = set end
    end
    for _, set in ipairs(TS.GameSets()) do add(set) end
    for _, set in ipairs(TS.GroupByName(items)) do add(set) end
    table.sort(out, function(a, b)
        local wa, wb = a.have == a.total, b.have == b.total
        if wa ~= wb then return wa end
        local ra, rb = a.have / a.total, b.have / b.total
        if ra ~= rb then return ra > rb end
        return a.name:lower() < b.name:lower()
    end)
    return out
end

function TS:StartScan()
    self.slotMap = nil
    self.scan = { cat = 0, at = 0, list = nil, items = {}, byKey = {}, reads = 0,
                  t0 = debugprofilestop and debugprofilestop() or 0 }
end

-- Read up to `budget` appearances; true when the whole collection has been read
function TS:Step(budget)
    local s = self.scan
    if not s then return true end
    local C = C_TransmogCollection
    if not (C and C.GetCategoryAppearances and C.GetAppearanceSources) then
        s.cat = #TS.SLOTS + 1
    end
    while budget > 0 do
        if not s.list or s.at >= #s.list then
            s.cat = s.cat + 1
            local def = TS.SLOTS[s.cat]
            if not def then self:Finish(); return true end
            local ok, list = pcall(C.GetCategoryAppearances, def.cat)
            s.list, s.at = (ok and type(list) == "table") and list or {}, 0
        else
            s.at = s.at + 1
            s.reads = s.reads + 1
            self:Read(s, TS.SLOTS[s.cat].cat, s.list[s.at])
            budget = budget - 1
        end
    end
    return false
end

function TS:Finish()
    local s = self.scan
    self.scan = nil
    self.items = s.items
    self.sets = TS.Collect(s.items)
    self.read = { appearances = s.reads, items = #s.items,
                  ms = debugprofilestop and (debugprofilestop() - s.t0) or 0 }
    ns.Note("transmog: %d appearances read, %d named pieces, %d sets", s.reads, #s.items, #self.sets)
    self:Refresh()
    self:Aim()
    if self.stale and panel and ns.ShownPlain(panel) then self.stale = false; self:StartScan() end
end

-- The whole collection at once (for /cchud check and the tests)
function TS:ScanAll()
    self:StartScan()
    while not self:Step(1000) do end
end

---------------------------------------------------------------------------
-- An item's tooltip: is its look yours yet?
---------------------------------------------------------------------------
-- "mine" (this item's look is collected), "look" (the look is yours, through another item), "new" (not yet), or
-- nil for an item with no look to collect (not gear, not a cosmetic). item: its link or its id.
function TS.Appearance(item)
    local C = C_TransmogCollection
    if not (item and C and C.GetItemInfo and C.GetSourceInfo) then return nil end
    local ok, look, source = pcall(C.GetItemInfo, item)
    look, source = ok and Num(look), ok and Num(source)
    if not (look and source) then return nil end
    local okS, info = pcall(C.GetSourceInfo, source)
    if okS and type(info) == "table" and ns.Yes(info.isCollected) then return "mine" end
    if C.GetAppearanceInfoBySource then
        local okA, a = pcall(C.GetAppearanceInfoBySource, source)
        if okA and type(a) == "table" then
            if ns.Yes(a.sourceIsCollected) then return "mine" end
            if ns.Yes(a.appearanceIsCollected) then return "look" end
        end
    end
    if C.GetAllAppearanceSources then
        local okAll, others = pcall(C.GetAllAppearanceSources, look)
        for _, id in ipairs(okAll and type(others) == "table" and others or {}) do
            local okO, o = pcall(C.GetSourceInfo, id)
            if Num(id) ~= source and okO and type(o) == "table" and ns.Yes(o.isCollected) then return "look" end
        end
    end
    return "new"
end

-- The line under an item's tooltip (Inventory.lua hangs it on the HUD's own panel there): { { left, right } }
function TS.TipLines(data)
    if not (ns.db and ns.db.tipAppearance and type(data) == "table") then return {} end
    local state = TS.Appearance(Text(data.hyperlink) or Num(data.id))
    if not state then return {} end
    local said = state == "mine" and ("|cff6fe06a" .. L["collected"])
        or state == "look" and ("|cff8fd0ff" .. L["collected from another item"])
        or ("|cffffd25a" .. L["not collected yet"])
    return { { L["Appearance"], said .. "|r" } }
end

---------------------------------------------------------------------------
-- The outfit's slots: putting a set on, and back
---------------------------------------------------------------------------
local function Window() local f = rawget(_G, "TransmogFrame"); return type(f) == "table" and f or nil end

-- The option the window is showing for a slot (weapon slots have several; armour has one)
local function OptionFor(slot)
    local win = Window()
    local preview = win and win.CharacterPreview
    if type(preview) == "table" and preview.GetSlotFrame then
        local ok, f = pcall(preview.GetSlotFrame, preview, slot, APPEARANCE)
        local data = ok and type(f) == "table" and f.slotData
        local info = type(data) == "table" and data.currentOptionInfo
        if type(info) == "table" and Num(info.type) then return Num(info.type) end
    end
    local O = C_TransmogOutfitInfo
    if O and O.GetEquippedSlotOptionFromTransmogSlot then
        local ok, o = pcall(O.GetEquippedSlotOptionFromTransmogSlot, slot)
        if ok and Num(o) then return Num(o) end
    end
    return NO_OPTION
end

local function SlotInfo(slot, option)
    local O = C_TransmogOutfitInfo
    if not (O and O.GetViewedOutfitSlotInfo) then return nil end
    local ok, info = pcall(O.GetViewedOutfitSlotInfo, slot, APPEARANCE, option)
    if ok and type(info) == "table" then return info end
end

local function Outfit()
    local O = C_TransmogOutfitInfo
    if O and O.GetCurrentlyViewedOutfitID then
        local ok, id = pcall(O.GetCurrentlyViewedOutfitID)
        if ok then return Num(id) end
    end
end

local function CanChange(slot)
    local O = C_TransmogOutfitInfo
    if not (O and O.CanPlayerTransmogSlot) then return true end
    local ok, yes = pcall(O.CanPlayerTransmogSlot, slot)
    return not ok or yes == nil or ns.Yes(yes)
end

local function ApplyLabel()
    return Text(rawget(_G, "TRANSMOG_SAVE_OUTFIT")) or Text(rawget(_G, "APPLY")) or "Apply"
end

-- Every piece of the set you have, on the outfit's slots as changes still to keep. The slots' looks from before
-- the first set you picked are remembered, for Undo.
function TS:Put(set)
    local O = C_TransmogOutfitInfo
    if not (set and set.list and O and O.SetPendingTransmog) then return 0, 0 end
    local outfit = Outfit()
    if self.before and self.before.outfit ~= outfit then self.before = nil end
    self.before = self.before or { outfit = outfit, slots = {}, order = {} }
    local put, refused, tried = 0, 0, {}
    for _, p in ipairs(set.list) do
        if p.use then
            local option = OptionFor(p.slot)
            if CanChange(p.slot) then
                local now = SlotInfo(p.slot, option)
                if now and not self.before.slots[p.slot] then
                    self.before.slots[p.slot] = { option = option, id = Num(now.transmogID), shown = Num(now.displayType),
                                                  pending = ns.Yes(now.hasPending) }
                    self.before.order[#self.before.order + 1] = p.slot
                end
                if pcall(O.SetPendingTransmog, p.slot, APPEARANCE, option, p.use, Assigned()) then
                    put = put + 1
                    tried[#tried + 1] = { slot = p.slot, option = option, id = p.use }
                else
                    refused = refused + 1
                end
            else
                refused = refused + 1
            end
        end
    end
    if put > 0 and PlaySound and SOUNDKIT and SOUNDKIT.UI_TRANSMOG_ITEM_CLICK then
        pcall(PlaySound, SOUNDKIT.UI_TRANSMOG_ITEM_CLICK)
    end
    self.last = { name = set.name, put = put, refused = refused, total = set.total }
    self:Say()
    ns.Note("transmog: %s put on, %d pieces, %d refused", set.name, put, refused)
    -- the window takes them at once; a slot that still shows something else a moment later did not take it
    C_Timer.After(0.2, ns.Protect(function()
        if not (self.last and self.last.name == set.name) then return end
        local wrong = 0
        for _, t in ipairs(tried) do
            local info = SlotInfo(t.slot, t.option)
            if info and Num(info.transmogID) ~= t.id then wrong = wrong + 1 end
        end
        if wrong > 0 then
            self.last.put, self.last.refused = self.last.put - wrong, self.last.refused + wrong
            self:Say()
        end
    end))
    self:Refresh()
    return put, refused
end

-- Something to undo: slots changed by a set that still hold a change not yet kept, on the same outfit
function TS:CanUndo()
    local b = self.before
    if not b or b.outfit ~= Outfit() then return false end
    for _, slot in ipairs(b.order) do
        local info = SlotInfo(slot, b.slots[slot].option)
        if info and ns.Yes(info.hasPending) then return true end
    end
    return false
end

-- The slots a set changed, back as they were before it. A change already kept (Apply) stays: taking it back
-- would cost again.
function TS:Undo()
    local O = C_TransmogOutfitInfo
    if not (O and self:CanUndo()) then return false end
    local b = self.before
    self.before = nil
    for _, slot in ipairs(b.order) do
        local was = b.slots[slot]
        local info = SlotInfo(slot, was.option)
        if info and ns.Yes(info.hasPending) then
            if was.pending and was.id and was.shown then
                pcall(O.SetPendingTransmog, slot, APPEARANCE, was.option, was.id, was.shown)
            elseif O.RevertPendingTransmog then
                pcall(O.RevertPendingTransmog, slot, APPEARANCE, was.option)
            end
        end
    end
    self.last = { undone = true }
    self:Say()
    ns.Note("transmog: undone, %d slots", #b.order)
    self:Refresh()
    return true
end

---------------------------------------------------------------------------
-- The page
---------------------------------------------------------------------------
local panel

local function Shown(f, on) if on then f:Show() else f:Hide() end end

local function FontString(parent, font, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", font)
    fs:SetJustifyH(justify or "LEFT")
    return fs
end

local function QualityColor(q)
    local c = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    if type(c) == "table" and c.r then return c.r, c.g, c.b end
    return 1, 1, 1
end

local function BuildRow(i)
    local r = CreateFrame("Button", nil, panel.content)
    r:SetHeight(ROW - 4)
    r:SetPoint("TOPLEFT", panel.content, "TOPLEFT", 0, -(i - 1) * ROW)
    r:SetPoint("TOPRIGHT", panel.content, "TOPRIGHT", 0, -(i - 1) * ROW)
    r.back = r:CreateTexture(nil, "BACKGROUND")
    r.back:SetAllPoints(r)
    r.back:SetColorTexture(0, 0, 0, 0.35)
    r.lit = r:CreateTexture(nil, "BORDER")                   -- the cursor or the pointer on it
    r.lit:SetAllPoints(r)
    r.lit:SetColorTexture(1, 0.82, 0.3, 0.16)
    r.lit:Hide()
    r.worn = r:CreateTexture(nil, "ARTWORK")                 -- the set last put on: a gold bar down its left
    r.worn:SetPoint("TOPLEFT", r, "TOPLEFT", 0, 0)
    r.worn:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 0, 0)
    r.worn:SetWidth(3)
    r.worn:SetColorTexture(1, 0.82, 0.3, 0.95)
    r.worn:Hide()
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(ICON, ICON)
    r.icon:SetPoint("LEFT", r, "LEFT", 8, 0)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.name = FontString(r, "GameFontNormal")
    r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 10, -2)
    r.name:SetPoint("RIGHT", r, "RIGHT", -10, 0)
    r.name:SetWordWrap(false)
    r.count = FontString(r, "GameFontHighlightSmall")
    r.count:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 10, 2)
    r.missing = FontString(r, "GameFontDisableSmall")
    r.missing:SetPoint("LEFT", r.count, "RIGHT", 10, 0)
    r.missing:SetPoint("RIGHT", r, "RIGHT", -10, 0)
    r.missing:SetWordWrap(false)
    r:SetScript("OnEnter", ns.Protect(function(self)
        self.lit:Show()
        if self.at then TS.focus = self.at; TS:ShowPieces() end
    end))
    r:SetScript("OnLeave", ns.Protect(function(self) self.lit:Hide() end))
    r:SetScript("OnClick", ns.Protect(function(self)
        if self.at and TS.sets and TS.sets[self.at] then
            TS.focus = self.at
            TS:Put(TS.sets[self.at])
        end
    end))
    TS.rows[i] = r
    return r
end

local function Build(page)
    panel = CreateFrame("Frame", "ControllerCamHUD_TransmogSets", page)
    panel:SetAllPoints(page)
    if page.GetFrameLevel and panel.SetFrameLevel then
        local level = tonumber(page:GetFrameLevel())
        if level then panel:SetFrameLevel(level + 20) end
    end
    panel.status = FontString(panel, "GameFontHighlight")
    panel.status:SetPoint("TOPLEFT", panel, "TOPLEFT", 28, -24)
    panel.hint = FontString(panel, "GameFontHighlightSmall")
    panel.hint:SetPoint("TOPLEFT", panel.status, "BOTTOMLEFT", 0, -6)
    panel.hint:SetTextColor(0.72, 0.76, 0.86)
    panel.status:SetMaxLines(2)                              -- two lines each at most: the list starts below both
    panel.hint:SetMaxLines(2)

    local ok, undo = pcall(CreateFrame, "Button", "ControllerCamHUD_TransmogUndo", panel, "SharedButtonTemplate")
    if not ok then ok, undo = pcall(CreateFrame, "Button", "ControllerCamHUD_TransmogUndo", panel, "UIPanelButtonTemplate") end
    if not ok then undo = CreateFrame("Button", "ControllerCamHUD_TransmogUndo", panel) end
    undo:SetSize(128, 28)
    undo:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -28, -20)
    undo:SetScript("OnClick", ns.Protect(function() TS:Undo() end))
    panel.undo = undo
    panel.status:SetPoint("RIGHT", undo, "LEFT", -12, 0)
    panel.hint:SetPoint("RIGHT", undo, "LEFT", -12, 0)

    -- the list: a scroll frame the game's cursor scrolls by itself (it keeps the chosen row in view)
    local scroll = CreateFrame("ScrollFrame", nil, panel)
    scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 26, -92)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -26, 18 + PANE_H)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(560, ROW)
    scroll:SetScrollChild(content)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", ns.Protect(function(self, delta)
        local now, range = tonumber(self:GetVerticalScroll()) or 0, tonumber(self:GetVerticalScrollRange()) or 0
        self:SetVerticalScroll(math.max(0, math.min(range, now - (tonumber(delta) or 0) * ROW * 2)))
    end))
    scroll:SetScript("OnSizeChanged", ns.Protect(function(self, w) if tonumber(w) then content:SetWidth(w) end end))
    panel.scroll, panel.content = scroll, content
    panel.empty = FontString(panel, "GameFontNormalMed2", "CENTER")
    panel.empty:SetPoint("TOPLEFT", scroll, "TOPLEFT", 40, -60)
    panel.empty:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", -40, -60)
    panel.empty:Hide()

    -- the chosen set's pieces, under the list: each slot, what goes there, and what is missing
    local pane = CreateFrame("Frame", nil, panel)
    pane:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 26, 12)
    pane:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -26, 12)
    pane:SetHeight(PANE_H)
    pane.back = pane:CreateTexture(nil, "BACKGROUND")
    pane.back:SetAllPoints(pane)
    pane.back:SetColorTexture(0, 0, 0, 0.45)
    pane.title = FontString(pane, "GameFontNormal")
    pane.title:SetPoint("TOPLEFT", pane, "TOPLEFT", 12, -10)
    pane.title:SetPoint("TOPRIGHT", pane, "TOPRIGHT", -12, -10)
    pane.title:SetWordWrap(false)
    pane.lines = {}
    for i = 1, #TS.SLOTS do
        local fs = FontString(pane, "GameFontHighlightSmall")
        fs:SetWordWrap(false)
        fs.col, fs.line = (i - 1) % 2, math.floor((i - 1) / 2)
        pane.lines[i] = fs
    end
    -- two columns, each half the pane (placed again when the window's size changes)
    local function Place(self, w)
        local half = (tonumber(w) or 560) / 2
        for _, fs in ipairs(self.lines) do
            fs:ClearAllPoints()
            fs:SetPoint("TOPLEFT", self, "TOPLEFT", 12 + fs.col * half, -32 - fs.line * 16)
            fs:SetWidth(half - 18)
        end
    end
    Place(pane, 560)
    pane:SetScript("OnSizeChanged", ns.Protect(Place))
    panel.pane = pane

    panel:SetScript("OnShow", ns.Protect(function() TS:Opened() end))
    panel:SetScript("OnHide", ns.Protect(function() TS:Closed() end))
    panel:SetScript("OnUpdate", ns.Protect(function()
        if TS.scan then TS:Step(TS.BATCH) end
    end))
    TS.keys = ns.PadKeys("TransmogSets", { "PAD3" }, function(key) if key == "PAD3" then TS:Undo() end end)
    TS.panel = panel
end

-- What the top of the page says: the last thing done, or how many sets there are
function TS:Say()
    if not panel then return end
    local last, hint = self.last, L["Pick a set to put its pieces on your outfit. %s keeps it; nothing is paid before that."]
    if self.scan and not self.sets then
        panel.status:SetText(L["Looking through your collection..."])
    elseif last and last.undone then
        panel.status:SetText(L["Your outfit is back as it was."])
    elseif last and last.name then
        local text = L["%s: %d of %d pieces put on."]:format(last.name, last.put, last.total)
        if last.refused > 0 then text = text .. " " .. L["%d would not go on this outfit."]:format(last.refused) end
        panel.status:SetText(text)
    elseif self.sets and #self.sets == 1 then
        panel.status:SetText(L["One set you have pieces of"])
    else
        panel.status:SetText(L["%d sets you have pieces of"]:format(self.sets and #self.sets or 0))
    end
    panel.hint:SetText(hint:format(ApplyLabel()))
end

function TS:ShowPieces()
    if not panel then return end
    local pane, set = panel.pane, self.sets and self.sets[self.focus]
    if not set then pane:Hide(); return end
    pane:Show()
    pane.title:SetText(set.name)
    for i, fs in ipairs(pane.lines) do
        local p = set.list[i]
        if p then
            if p.have then
                fs:SetText(p.slotName .. ":  " .. p.name)
                fs:SetTextColor(QualityColor(p.quality))
            else
                local why = p.cant and L["you can't wear this"] or L["missing"]
                fs:SetText(p.slotName .. ":  " .. p.name .. "  (" .. why .. ")")
                fs:SetTextColor(0.5, 0.5, 0.5)
            end
            fs:Show()
        else
            fs:SetText("")
            fs:Hide()
        end
    end
end

function TS:Refresh()
    if not panel then return end
    self:Say()
    local sets = self.sets or {}                             -- (while it reads again, the sets from before)
    local can = self:CanUndo()
    panel.content:SetHeight(math.max(ROW, #sets * ROW))
    local width = tonumber(panel.scroll:GetWidth())
    if width and width > 0 then panel.content:SetWidth(width) end
    for i, set in ipairs(sets) do
        local r = self.rows[i] or BuildRow(i)
        r.at = i
        r.icon:SetTexture(set.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        r.name:SetText(set.name)
        if set.have == set.total then
            r.count:SetText(L["All %d pieces"]:format(set.total))
            r.count:SetTextColor(0.42, 0.88, 0.42)
            r.missing:SetText("")
        else
            r.count:SetText(L["%d of %d pieces"]:format(set.have, set.total))
            r.count:SetTextColor(1, 1, 1)
            r.missing:SetText(L["Missing: %s"]:format(table.concat(set.missing, ", ")))
        end
        Shown(r.worn, can and self.last ~= nil and self.last.name == set.name)
        r:Show()
    end
    for i = #sets + 1, #self.rows do self.rows[i].at = nil; self.rows[i]:Hide() end
    panel.empty:SetText(L["No sets yet. Items that share a name, like Green Iron Helm and Green Iron Gauntlets, show here once you have one of them."])
    Shown(panel.empty, not self.scan and #sets == 0)
    if self.focus > #sets then self.focus = 1 end
    self:ShowPieces()
    panel.undo:SetText(ns.KeyText("PAD3", 16) .. " " .. L["Undo"])
    panel.undo:SetEnabled(can)
    panel.undo:SetAlpha(can and 1 or 0.5)
end

-- The game's cursor onto the first set (the game's own tabs do the same with their first entry)
function TS:Aim()
    local nav, win, first = rawget(_G, "SmartNavigation"), Window(), self.rows[1]
    if not (panel and ns.ShownPlain(panel) and first and first.at and win) then return end
    if InCombatLockdown() or type(nav) ~= "table" or type(nav.SetTargetButtonForFrame) ~= "function" then return end
    pcall(nav.SetTargetButtonForFrame, nav, win, first)
end

function TS:Opened()
    if self.last and not self.last.undone and not self:CanUndo() then self.last = nil end
    if self.last and self.last.undone then self.last = nil end
    if (not self.sets or self.stale) and not self.scan then self.stale = false; self:StartScan() end
    if self.keys then self.keys:Set(true) end
    self:Refresh()
    C_Timer.After(0, ns.Protect(function() TS:Aim() end))
end

function TS:Closed()
    if self.keys then self.keys:Set(false) end
end

---------------------------------------------------------------------------
-- The game's tab
---------------------------------------------------------------------------
local function Wardrobe()
    local win = Window()
    local w = win and win.WardrobeCollection
    return type(w) == "table" and w or nil
end

local function GameHasSets()
    local S = C_TransmogSets
    if not (S and S.HasAnyValidSets) then return false end
    local ok, yes = pcall(S.HasAnyValidSets)
    return ok and ns.Yes(yes)
end

local function SetsTab(w)
    local id, headers = Num(w.setsTabID), w.TabHeaders
    local tabs = type(headers) == "table" and rawget(headers, "tabs")
    if id and type(tabs) == "table" and type(tabs[id]) == "table" then return tabs[id] end
end

local function SetsPage(w)
    local content = type(w.TabContent) == "table" and w.TabContent
    local page = content and content.SetsFrame
    return type(page) == "table" and page or nil
end

-- The page's own (empty) list, out of sight and out of the cursor's reach while ours is there
local function Cover(page, on)
    local paged = type(page.PagedContent) == "table" and page.PagedContent or nil
    if not paged then return end
    if on == TS.covered then return end
    TS.covered = on
    pcall(paged.SetAlpha, paged, on and 0 or 1)
    local mark = on and rawget(_G, "SmartNavigation_MarkFrameIgnored") or rawget(_G, "SmartNavigation_ClearIgnoreStatus")
    if type(mark) == "function" and not InCombatLockdown() then pcall(mark, paged) end
end

-- After the game's UpdateTabs (each time the window opens): our Sets tab, where the game keeps its own
function TS:AfterTabs()
    local w = Wardrobe()
    if not (self.on and w) then return end
    if GameHasSets() then self.aside = true; return end
    self.aside = false
    local tab, page = SetsTab(w), SetsPage(w)
    if not (tab and page) then return end
    if not panel then Build(page) end
    Cover(page, true)
    panel:Show()
    if not ns.ShownPlain(tab) then
        tab:Show()
        self.tab = tab
    end
end

function TS:Hook()
    local w = Wardrobe()
    if self.hooked or not w or type(w.UpdateTabs) ~= "function" then return end
    self.hooked = true
    hooksecurefunc(w, "UpdateTabs", ns.Protect(function()
        TS:AfterTabs()
        C_Timer.After(0.1, ns.Protect(function() TS:CustomHint() end))     -- (each time the window opens)
    end))
    -- the window closing throws away what it had not kept: so does our Undo
    local watch = CreateFrame("Frame", nil, Window())
    watch:SetScript("OnHide", ns.Protect(function()
        TS.before, TS.last = nil, nil
        if TS.custom then TS.custom:Set(false) end
    end))
    watch:SetScript("OnShow", ns.Protect(function() C_Timer.After(0.2, ns.Protect(function() TS:CustomHint() end)) end))
    self.custom = ns.PadKeys("TransmogCustom", { "PAD4" }, function() TS:AskDelete() end)
    self.watch = watch
end

---------------------------------------------------------------------------
-- Custom Sets: Y deletes the set the cursor is on. The game's own way (a menu on a right-click) is out of a
-- controller's reach. The set is found by its name as the game lists it, on what the cursor is over (or a frame
-- above it), and asked about in a window of ours first; nothing of the game's is called but its own delete.
---------------------------------------------------------------------------
local function CustomSetNames()
    local C = C_TransmogCollection
    if not (C and C.GetCustomSets and C.GetCustomSetInfo and C.DeleteCustomSet) then return nil end
    local ok, ids = pcall(C.GetCustomSets)
    if not (ok and type(ids) == "table") then return nil end
    local names, count = {}, 0
    for _, id in ipairs(ids) do
        local okI, name = pcall(C.GetCustomSetInfo, id)
        if okI and type(name) == "string" and not ns.IsSecret(name) and names[name] == nil then
            names[name] = id
            count = count + 1
        end
    end
    return names, count
end

local function MouseFoci()
    local many = rawget(_G, "GetMouseFoci")
    if type(many) == "function" then
        local ok, list = pcall(many)
        if ok and type(list) == "table" then return list end
    end
    local one = rawget(_G, "GetMouseFocus")
    if type(one) == "function" then
        local ok, f = pcall(one)
        if ok and f then return { f } end
    end
    return {}
end

-- The custom set a frame shows (or sits in): the name on it (or on a text it holds), up to five levels
local function SetOf(frame, names)
    local f = frame
    for _ = 1, 5 do
        if type(f) ~= "table" then return nil end
        local okR, regions = pcall(function() return { f:GetRegions() } end)
        for _, r in ipairs(okR and regions or {}) do
            if type(r) == "table" and r.GetText then
                local okT, text = pcall(r.GetText, r)
                if okT and type(text) == "string" and not ns.IsSecret(text) and names[text] then return names[text], text end
            end
        end
        for _, key in ipairs({ "Name", "name", "Text", "text", "Label", "label", "Title" }) do
            local held = rawget(f, key)
            if type(held) == "table" and held.GetText then
                local okT, text = pcall(held.GetText, held)
                if okT and type(text) == "string" and not ns.IsSecret(text) and names[text] then return names[text], text end
            end
        end
        local okP, parent = pcall(f.GetParent, f)
        f = okP and parent or nil
    end
end

-- Is our Sets page the one in sight (its tab chosen)? Its own flag stays on while the tab is not chosen: its page's counts
local function SetsPageUp()
    local w = Wardrobe()
    local page = w and SetsPage(w)
    return (panel and ns.ShownPlain(panel) and page and ns.ShownPlain(page)) and true or false
end

function TS:CustomPoint()
    local names = CustomSetNames()
    if not names then return nil end
    for _, f in ipairs(MouseFoci()) do
        local id, name = SetOf(f, names)
        if id then return id, name end
    end
end

ns.Dialog.Define("CCHUD_DELETE_CUSTOM_SET", {
    text = L["Delete the custom set %s? It can't be brought back."], button1 = L["Delete"], button2 = CANCEL or "Cancel",
    OnAccept = function()
        C_Timer.After(0, function()
            local id = TS.deleting
            TS.deleting = nil
            local C = C_TransmogCollection
            if id and C and C.DeleteCustomSet then pcall(C.DeleteCustomSet, id) end
            TS:CustomHint()
        end)
    end,
    OnCancel = function() TS.deleting = nil end,
})

function TS:AskDelete()
    if SetsPageUp() then return end                                -- (our own Sets page: nothing of Y's)
    local id, name = self:CustomPoint()
    if not id then ns.Say(L["Point at a custom set first."]); return end
    self.deleting = id
    ns.Dialog.Show("CCHUD_DELETE_CUSTOM_SET", name)
end

-- Y while the window is up, with the hint under it (only when there are custom sets)
function TS:CustomHint()
    local win = Window()
    if not (self.custom and win) then return end
    local _, count = CustomSetNames()
    local show = (count or 0) > 0 and not SetsPageUp()
    if not self.hint then
        local f = CreateFrame("Frame", nil, win)
        f:SetSize(300, 22)
        f.text = ns.FontString(f, 11, "LEFT")
        f.text:SetPoint("LEFT", f, "LEFT", 0, 0)
        self.hint = f
    end
    self.hint:ClearAllPoints()
    self.hint:SetPoint("TOPLEFT", win, "BOTTOMLEFT", 4, -4)
    self.hint.text:SetText(L["%s  Delete custom set"]:format(ns.KeyText("PAD4", 14)))
    self.hint:SetShown(show)
    self.custom:Set(show)
end

-- Switched off: the tab hidden again (as the game keeps it) and its page given back
function TS:StepBack()
    if self.custom then self.custom:Set(false) end
    if self.hint then self.hint:Hide() end
    if panel then panel:Hide() end
    if self.keys then self.keys:Set(false) end
    local w = Wardrobe()
    local page = w and SetsPage(w)
    if page then Cover(page, false) end
    if self.tab and not GameHasSets() then self.tab:Hide() end
    self.tab = nil
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", ns.Protect(function(_, event, name)
    if event == "ADDON_LOADED" then
        if name == "Blizzard_Transmog" then TS:Hook() end
    elseif event == "TRANSMOG_COLLECTION_UPDATED" then
        -- read again (now if the page is open, else when it next opens); the sets from before stay until then
        TS.stale = true
        if panel and ns.ShownPlain(panel) and not TS.scan then TS.stale = false; TS:StartScan() end
    end
end))

function TS:Apply(run)
    local on = (run and ns.db.transmogSets) and true or false
    if on == self.on then return end
    self.on = on
    if on then
        pcall(events.RegisterEvent, events, "ADDON_LOADED")
        pcall(events.RegisterEvent, events, "TRANSMOG_COLLECTION_UPDATED")
        self:Hook()
    else
        events:UnregisterAllEvents()
        self:StepBack()
    end
end

-- What we found of the transmogrifier (for the debug reports)
function TS.Describe()
    local O, C, S = C_TransmogOutfitInfo, C_TransmogCollection, C_TransmogSets
    local rows = {}
    rows[#rows + 1] = ("on %s, api: outfit %s, collection %s, sets %s; window loaded %s, hooked %s"):format(
        tostring(TS.on), tostring(O ~= nil and O.SetPendingTransmog ~= nil), tostring(C ~= nil and C.GetAppearanceSources ~= nil),
        tostring(S ~= nil), tostring(Window() ~= nil), tostring(TS.hooked or false))
    local w = Wardrobe()
    local tab = w and SetsTab(w)
    rows[#rows + 1] = ("game has sets of its own %s; its Sets tab found %s, shown %s (by us %s); page covered %s"):format(
        tostring(GameHasSets()), tostring(tab ~= nil), tostring(tab ~= nil and ns.ShownPlain(tab)),
        tostring(TS.tab ~= nil), tostring(TS.covered or false))
    local r = TS.read
    rows[#rows + 1] = ("read: %s appearances, %s named pieces, %s sets, %s ms; reading now %s"):format(
        tostring(r and r.appearances), tostring(r and r.items), tostring(TS.sets and #TS.sets),
        r and ("%.0f"):format(r.ms) or "-", tostring(TS.scan ~= nil))
    if C and C.GetCollectedShown and C.GetUncollectedShown then
        local okA, a = pcall(C.GetCollectedShown)
        local okB, b = pcall(C.GetUncollectedShown)
        rows[#rows + 1] = ("the window's filters: collected %s, not collected %s (missing pieces are read from what it lists)"):format(
            tostring(okA and a), tostring(okB and b))
    end
    local last = TS.last
    rows[#rows + 1] = ("last: %s; undo held for %d slots, can undo %s; X bound %s"):format(
        last and (last.undone and "undone" or ("%s %d put, %d refused"):format(last.name, last.put, last.refused)) or "none",
        TS.before and #TS.before.order or 0, tostring(TS:CanUndo()), tostring(TS.keys and TS.keys.on or false))
    for i = 1, math.min(5, TS.sets and #TS.sets or 0) do
        local s = TS.sets[i]
        rows[#rows + 1] = ("  %s: %d of %d%s"):format(s.name, s.have, s.total, s.game and " (the game's)" or "")
    end
    return rows
end

ns.RegisterModule("transmog", TS)
