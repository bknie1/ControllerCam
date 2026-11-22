-- ControllerCam HUD: everything we know about an item, in one window.
-- Point at an item (in your bags, the bank, a vendor) and use the "Item details" action (a key binding), or
-- type /cchud item, or /cchud item <item link or id>. The window shows: what it is (level, kind, stack), what
-- it sells for at a vendor, the last auction price you saw, how many you and your other characters hold, and
-- your mark on it (junk, kept, bank). B (or Escape) closes it.

local ADDON, ns = ...
local L, C = ns.L, ns.colors

local IN = {}
ns.ItemInfo = IN

local W, ROW = 360, 22
local frame

local function Build()
    frame = CreateFrame("Frame", "ControllerCamHUD_ItemInfoWindow", UIParent)
    frame:SetSize(W, 120)
    frame:SetPoint("CENTER", UIParent, "CENTER", 260, 60)
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)
    frame.back = frame:CreateTexture(nil, "BACKGROUND")
    frame.back:SetAllPoints(frame)
    frame.back:SetColorTexture(0.03, 0.04, 0.07, 0.92)
    frame.edges = {}
    for i, side in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" } }) do
        local t = frame:CreateTexture(nil, "BORDER")
        t:SetPoint(side[1], frame, side[1])
        t:SetPoint(side[2], frame, side[2])
        t:SetHeight(1)
        t:SetColorTexture(0.55, 0.62, 0.75, 0.6)
        frame.edges[i] = t
    end
    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetSize(36, 36)
    frame.icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -12)
    frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    frame.title = ns.FontString(frame, 13, "LEFT")
    frame.title:SetPoint("TOPLEFT", frame.icon, "TOPRIGHT", 10, -2)
    frame.title:SetPoint("RIGHT", frame, "RIGHT", -12, 0)
    frame.sub = ns.FontString(frame, 9, "LEFT")
    frame.sub:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -3)
    frame.sub:SetTextColor(unpack(C.muted))
    frame.rows = {}
    frame:Hide()
    -- B or Escape closes it: keys of its own while it is open (never the game's list of windows, Core.lua)
    IN.keys = ns.PadKeys("ItemInfo", { "PAD2", "ESCAPE" }, function() frame:Hide() end, function() frame:Hide() end)
    frame:SetScript("OnHide", ns.Protect(function() IN.keys:Set(false) end))
    IN.frame = frame
end

local function Row(i)
    local r = frame.rows[i]
    if not r then
        r = { left = ns.FontString(frame, 10, "LEFT"), right = ns.FontString(frame, 10, "RIGHT") }
        r.left:SetTextColor(unpack(C.muted))
        frame.rows[i] = r
    end
    local y = -60 - (i - 1) * ROW
    r.left:ClearAllPoints()
    r.left:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, y)
    r.right:ClearAllPoints()
    r.right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -14, y)
    r.left:Show()
    r.right:Show()
    return r
end

-- An item id from a link, an id, or nothing (then: the item you are pointing at, or in the tooltip)
function IN.Resolve(arg)
    if type(arg) == "number" then return arg end
    if type(arg) == "string" and arg ~= "" then
        return tonumber(arg) or tonumber(arg:match("item:(%d+)"))
    end
    local V = ns.Vendor
    local bag, slot
    if V and V.PointedSlot then bag, slot = V.PointedSlot() end
    if bag then
        local id = C_Container.GetContainerItemID(bag, slot)
        if id and not ns.IsSecret(id) then return id end
    end
    if GameTooltip and GameTooltip.GetItem and GameTooltip:IsShown() then
        local ok, _, link = pcall(GameTooltip.GetItem, GameTooltip)
        if ok and type(link) == "string" and not ns.IsSecret(link) then return tonumber(link:match("item:(%d+)")) end
    end
end

-- The rows for an item: { { left, right }, ... }
function IN.Rows(id)
    local rows = {}
    local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local ok, _, _, _, ilvl, req, kind, subkind, stack = pcall(get, id)
    if ok then
        if type(ilvl) == "number" and ilvl > 0 then rows[#rows + 1] = { L["Item level"], tostring(ilvl) } end
        if type(req) == "number" and req > 1 then rows[#rows + 1] = { L["Requires level"], tostring(req) } end
        if type(stack) == "number" and stack > 1 then rows[#rows + 1] = { L["Stacks to"], tostring(stack) } end
    end
    rows[#rows + 1] = { L["Item ID"], tostring(id) }
    if ns.Market then
        local saved = { ns.db.vendorPrice, ns.db.auctionPrice }
        ns.db.vendorPrice, ns.db.auctionPrice = true, true          -- the window shows both, always
        for _, l in ipairs(ns.Market.Lines(id)) do rows[#rows + 1] = l end
        ns.db.vendorPrice, ns.db.auctionPrice = saved[1], saved[2]
        if not ns.Market.Auction(id) then rows[#rows + 1] = { L["Auction"], L["not seen yet"] } end
    end
    if ns.Inventory then
        local held = ns.Inventory.Lines(id)
        if #held == 0 then rows[#rows + 1] = { L["You"], L["none"] } end
        for _, l in ipairs(held) do rows[#rows + 1] = l end
    end
    local sell = ns.db.sell
    local mark = sell and ((sell.junk[id] and L["junk"]) or (sell.keep[id] and L["kept"]) or (sell.bank[id] and L["bank"]))
    rows[#rows + 1] = { L["Your mark"], mark or L["none"] }
    return rows, ok and kind or nil, ok and subkind or nil
end

function IN:Show(arg)
    local id = IN.Resolve(arg)
    if not id then ns.Say(L["Point at an item first."]); return false end
    if not frame then Build() end
    local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local ok, name, _, quality, _, _, _, _, _, _, icon = pcall(get, id)
    local rows, kind, subkind = IN.Rows(id)
    frame.icon:SetTexture((ok and icon) or (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)) or 134400)
    local q = ok and quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    frame.title:SetText(ok and name or ("item " .. id))
    if q then frame.title:SetTextColor(q.r, q.g, q.b) else frame.title:SetTextColor(unpack(C.text)) end
    frame.sub:SetText((kind and subkind and kind ~= subkind) and (kind .. " - " .. subkind) or (kind or ""))
    for i, row in ipairs(rows) do
        local r = Row(i)
        r.left:SetText(row[1])
        r.right:SetText(row[2])
    end
    for i = #rows + 1, #frame.rows do frame.rows[i].left:Hide(); frame.rows[i].right:Hide() end
    frame:SetHeight(72 + #rows * ROW)
    frame:Show()
    IN.keys:Set(true)
    IN.shown = id
    return true
end

function ControllerCamHUD_ItemInfo() ns.Protect(function()
    if frame and frame:IsShown() then frame:Hide() else IN:Show() end
end)() end
BINDING_NAME_CCHUD_ITEMINFO = L["Item details: everything about the item you point at"]

ns.RegisterCommand("item", function(arg) IN:Show(arg) end, "/cchud item [link or id]",
    "show everything about the item you point at (or the one given): prices, who holds it, your mark")
