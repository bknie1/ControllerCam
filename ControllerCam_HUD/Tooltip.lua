-- ControllerCam HUD: what the HUD adds to tooltips, beside them.
-- Tooltips are the game's: where it puts them and how they look (with the HUD's look on, the dark glass of
-- the rest of the HUD). Tooltips followed your cursor once, with a see-through background; that is gone.
--
-- The game's tooltips are only looked at here, never filled and never added to. A line an addon adds to one of
-- the game's tooltips is a piece of that tooltip made by the addon, and so is everything the tooltip's own
-- scripts write while an addon is the one showing or hiding it. The game stops trusting what it does after
-- reading such a piece, and it reads tooltips while the controller's cursor moves: seen here as the gamepad
-- bars refusing their own buttons after a visit to a vendor, until a reload. So: our lines for an item hang
-- under its tooltip on a panel of our own (T.Annex), and our own windows explain themselves in a tooltip of
-- our own (T.Own).

local ADDON, ns = ...

local T = {}
ns.Tooltip = T

---------------------------------------------------------------------------
-- Our lines for what a tooltip shows, on a panel of our own under it
---------------------------------------------------------------------------
T.annex = setmetatable({}, { __mode = "k" })
T.ROW = 14

local function Title(tooltip)
    local ok, text = pcall(function()
        local name = tooltip.GetName and tooltip:GetName()
        local fs = type(name) == "string" and _G[name .. "TextLeft1"]
        return fs and fs.GetText and fs:GetText() or nil
    end)
    if ok and type(text) == "string" and not ns.IsSecret(text) then return text end
end

-- Which way the panel grows when it is wider than the tooltip: away from what the tooltip is about. The game
-- puts an item's tooltip beside the item; grown toward it, the panel covered the item itself.
local function Away(tooltip)
    local ok, side = pcall(function()
        local owner = tooltip:GetOwner()
        local ox = owner and owner.GetCenter and owner:GetCenter()
        local tx = tooltip:GetCenter()
        if type(ox) == "number" and type(tx) == "number" and not ns.IsSecret(ox) and not ns.IsSecret(tx) then
            return ox > tx and "LEFT" or "RIGHT"                -- the owner on the right: grow to the left
        end
        local w = UIParent and UIParent:GetWidth()
        if type(tx) == "number" and type(w) == "number" and not ns.IsSecret(tx) then
            return tx > w / 2 and "LEFT" or "RIGHT"            -- else away from the edge it is near
        end
    end)
    return (ok and side) or "RIGHT"
end
T.Away = Away

-- Where it goes is looked at for a moment while the tooltip settles, then kept until the tooltip shows something
-- else: looked at all the time, a tooltip near the bottom of the screen (the game keeps those on the screen)
-- had it flip between under and over, over and over.
T.SETTLE = 0.3
T.MOVED_ON = 0.3               -- the tooltip about something else for this long: the panel goes
-- Under the tooltip. With no room under it (a tooltip in a corner): right of it, unless what it is about is on
-- that side or the screen ends there; then over it.
local function Spot(a, tooltip, side)
    local function Number(what, frame)
        local ok, v = pcall(function() return frame[what](frame) end)
        if ok and type(v) == "number" and not ns.IsSecret(v) then return v end
    end
    local bottom = Number("GetBottom", tooltip)
    if not bottom or bottom >= a.frame:GetHeight() + 6 then return "below" end
    local right, w = Number("GetRight", tooltip), UIParent and Number("GetWidth", UIParent)
    if side == "RIGHT" and right and w and w - right >= (a.wide or 0) + 4 then return "right" end
    return "over"
end

local function PlaceAnnex(a, tooltip)
    local f = a.frame
    if a.settled then return end
    if a.since and GetTime() - a.since > T.SETTLE and a.spot ~= nil then a.settled = true; return end
    local side = Away(tooltip)
    local spot = Spot(a, tooltip, side)
    if spot == a.spot and side == a.side then return end
    a.spot, a.side = spot, side
    -- the edge on the item's side stays with the tooltip's; the panel grows the other way
    local edge = side == "LEFT" and "RIGHT" or "LEFT"
    f:ClearAllPoints()
    if spot == "below" then
        f:SetPoint("TOP" .. edge, tooltip, "BOTTOM" .. edge, 0, -2)
    elseif spot == "right" then
        f:SetPoint("BOTTOMLEFT", tooltip, "BOTTOMRIGHT", 2, 0)
    else
        f:SetPoint("BOTTOM" .. edge, tooltip, "TOP" .. edge, 0, 2)
    end
end

local function BuildAnnex(a, tooltip)
    local f = CreateFrame("Frame", nil, tooltip)
    f:SetFrameStrata("TOOLTIP")                              -- over the bags and everything else, like the tooltip
    local okL, level = pcall(function() return tooltip:GetFrameLevel() end)
    if okL and type(level) == "number" and not ns.IsSecret(level) then f:SetFrameLevel(level + 2) end
    a.frame = f
    f.back = f:CreateTexture(nil, "BACKGROUND")
    f.back:SetAllPoints(f)
    f.edge = f:CreateTexture(nil, "BORDER")
    f.edge:SetHeight(1)
    f.edge:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    f.edge:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    local since = 0
    f:SetScript("OnUpdate", ns.Protect(function(self, dt)   -- the tooltip went on to something else: gone
        since = since + dt
        if since < 0.1 then return end
        since = 0
        -- (the game fills its tooltip again now and then, the same item: for a moment it has another title, or
        -- none. Only a title that stays other than ours for a while means the tooltip moved on; hidden at once
        -- for every blink, the panel flickered.)
        if a.title and Title(tooltip) ~= a.title then
            a.otherSince = a.otherSince or GetTime()
            if GetTime() - a.otherSince >= T.MOVED_ON then a.otherSince = nil; self:Hide(); return end
        else
            a.otherSince = nil
        end
        PlaceAnnex(a, tooltip)
    end))
end

-- lines: { { left, right }, ... }, or { text } for a line of its own; none: the panel is put away
function T.Annex(tooltip, lines)
    if type(tooltip) ~= "table" then return end
    local a = T.annex[tooltip]
    if not lines or #lines == 0 then
        if a then
            a.lines, a.key = {}, nil
            if a.frame then a.frame:Hide() end
        end
        return
    end
    if not a then
        a = { rows = {} }
        T.annex[tooltip] = a
    end
    -- the game shows a tooltip again and again while it compares (and as the item's details come in): the same
    -- lines for the same item leave the panel as it is, where it is (laid out and placed again, it flickered)
    local parts = {}
    for i, l in ipairs(lines) do parts[i] = tostring(l[1]) .. "|" .. tostring(l[2]) end
    local key, title = table.concat(parts, "||"), Title(tooltip)
    local okO, owner = pcall(function() return tooltip.GetOwner and tooltip:GetOwner() end)
    owner = okO and owner or nil
    local shown = a.frame and a.frame:IsShown() and owner == a.owner     -- (another slot: placed anew)
    if shown and key == a.key and title == a.title then return end
    local same = shown and title ~= nil and title == a.title          -- the same item, new lines: keep its place
    a.owner = owner
    a.key = key
    a.lines = lines
    if not a.frame and not pcall(BuildAnnex, a, tooltip) then a.frame = nil end
    local f = a.frame
    if not f then return end
    local S, C = ns.Skin, ns.colors
    local glass, edge = (S and S.GLASS) or { 0.03, 0.04, 0.07, 0.82 }, (S and S.EDGE) or { 0.55, 0.62, 0.75, 0.55 }
    f.back:SetColorTexture(glass[1], glass[2], glass[3], math.max(glass[4], 0.92))     -- solid: it is read
    f.edge:SetColorTexture(edge[1], edge[2], edge[3], edge[4])
    for i, l in ipairs(lines) do
        local r = a.rows[i]
        if not r then
            r = { left = ns.FontString(f, 10, "LEFT"), right = ns.FontString(f, 10, "RIGHT") }
            r.left:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -(5 + (i - 1) * T.ROW))
            r.right:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -(5 + (i - 1) * T.ROW))
            r.left:SetTextColor(unpack(C.muted))
            a.rows[i] = r
        end
        r.left:SetText(l[1] or "")
        r.right:SetText(l[2] or "")
        r.left:SetTextColor(unpack(l[2] == nil and C.text or C.muted))      -- a line of its own colours itself
        r.left:Show()
        r.right:Show()
    end
    for i = #lines + 1, #a.rows do
        a.rows[i].left:Hide()
        a.rows[i].right:Hide()
    end
    -- as wide as its longest line needs (each side apart from the other), and no wider: it hangs beside what the
    -- tooltip is about (a merchant's price, the item itself) and should cover as little of it as it can
    local function Width(fs)
        local ok, w = pcall(fs.GetStringWidth, fs)
        if ok and type(w) == "number" and not ns.IsSecret(w) then return w end
        local okT, text = pcall(fs.GetText, fs)
        return (okT and type(text) == "string") and #text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") * 6 or 60
    end
    local wide = 0
    for i, l in ipairs(lines) do
        if l[2] == nil then wide = math.max(wide, Width(a.rows[i].left) + 20)
        else wide = math.max(wide, Width(a.rows[i].left) + Width(a.rows[i].right) + 34) end
    end
    f:SetWidth(wide)
    a.wide = wide
    f:SetHeight(#lines * T.ROW + 10)
    if not same then
        a.title, a.spot, a.side, a.settled, a.since = title, nil, nil, false, GetTime()
        PlaceAnnex(a, tooltip)
    end
    f:Show()
end

-- What hangs under a tooltip right now (for the tests and the reports)
function T.AnnexLines(tooltip)
    local a = T.annex[tooltip]
    return a and a.lines or {}
end

---------------------------------------------------------------------------
-- A tooltip of our own, for what our own windows explain
---------------------------------------------------------------------------
function T.Own()
    if T.own == nil then
        local ok, tip = pcall(CreateFrame, "GameTooltip", "ControllerCamHUD_Tip", UIParent, "GameTooltipTemplate")
        T.own = (ok and tip) or false
    end
    return T.own or nil
end
