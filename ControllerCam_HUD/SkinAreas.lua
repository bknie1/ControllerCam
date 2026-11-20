-- ControllerCam HUD: the areas of the game's interface that Skin.lua dresses, one by one.
-- Each area finds the game's frames by name, dresses what exists, and says how many it found; an area this
-- client does not have is simply skipped. Every change goes through Skin.lua, which can undo it.

local ADDON, ns = ...
local S = ns.Skin

local function Area(key, label, tip, fn)
    local setting = "skin" .. key
    ns.RegisterSetting({ key = setting, kind = "boolean", default = true, command = setting, section = "Look",
                         label = label, tip = tip })
    S.Area(key, label, fn, setting)
end

-- Put a value back on undo: set(new) now, set(old) later
local function Swap(set, new, old)
    set(new)
    S.Undo(function() set(old) end)
end

---------------------------------------------------------------------------
-- Tooltips: dark glass with a thin edge in the colour of what they show (a player's class, an enemy, an
-- item's quality), outlined text, our slim bar for health
---------------------------------------------------------------------------
local TIPS = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "EmbeddedItemTooltip",
               "GameTooltipTooltip" }

local function EdgeFor(tooltip, data)
    local p = S.PanelOf(tooltip)
    if not p or not S.active then return end
    local c = S.EDGE
    local kinds = Enum and Enum.TooltipDataType
    if data and kinds and data.type == kinds.Unit then
        local _, unit = tooltip:GetUnit()
        if unit and not ns.IsSecret(unit) then
            local ok, r, g, b = pcall(ns.UnitFrames.TargetColor, unit)
            if ok and r and not ns.IsSecret(r) then c = { r, g, b, 0.9 } end
        end
    elseif data and kinds and data.type == kinds.Item and data.id and not ns.IsSecret(data.id) then
        local quality = C_Item and C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(data.id)
        local q = quality and not ns.IsSecret(quality) and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
        if q and quality >= 2 then c = { q.r, q.g, q.b, 0.9 } end
    end
    S.EdgeColor(p, c)
end

local listening = false
Area("tooltips", "Tooltips", "tooltips in dark glass, edged in the colour of a player's class or an item's quality", function()
    local n = 0
    for _, name in ipairs(TIPS) do
        local tip = _G[name]
        if tip and tip.CreateTexture then
            S.KeepHidden(rawget(tip, "NineSlice"))
            S.Panel(tip, 0)
            n = n + 1
        end
    end
    local bar = _G.GameTooltipStatusBar
    if bar and bar.SetStatusBarTexture and bar.GetStatusBarTexture then
        local tex = bar:GetStatusBarTexture()
        local old = tex and tex.GetTexture and tex:GetTexture()
        if old then Swap(function(v) bar:SetStatusBarTexture(v) end, ns.media.bar, old) end
    end
    for _, font in ipairs({ "GameTooltipHeaderText", "GameTooltipText", "GameTooltipTextSmall" }) do S.Font(font, 1) end
    -- the edge colour of each tooltip as it opens (the game's own callback for addons; it calls us after it
    -- has filled the tooltip, and we only change our own edge)
    if not listening and TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall then
        listening = true
        local all = TooltipDataProcessor.AllTypes or (Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit)
        if all then TooltipDataProcessor.AddTooltipPostCall(all, ns.Protect(EdgeFor)) end
    end
    return n
end)

---------------------------------------------------------------------------
-- Gamepad bars: the heavy art goes; each button gets a dark round backing and a slim ring, each cluster of
-- four a soft dark pool, and the text on the buttons our outline. The buttons, bindings, glyphs and the
-- equipped-item border stay the game's.
---------------------------------------------------------------------------
local PAGE = "GamepadMainActionBarFramePageUnit"
local CLUSTERS = { { -58, 0 }, { 55, 0 } }        -- the two diamonds of four buttons in every gamepad bar

local function Field(frame, key) return type(frame) == "table" and rawget(frame, key) or nil end

local function DressButton(b, name)
    local w = b:GetWidth() or 32
    if w <= 1 then w = 32 end
    local normal = Field(b, "NormalTexture") or (name and _G[name .. "NormalTexture"])
    S.KeepHidden(normal)
    S.KeepHidden(Field(b, "SlotArt"))
    S.KeepHidden(Field(b, "SlotBackground"))
    local back = S.Piece(b, "disc", "BACKGROUND", -8, ns.media.disc)
    back:ClearAllPoints()
    back:SetPoint("CENTER", b, "CENTER", 0, 0)
    back:SetSize(w + 10, w + 10)
    back:SetVertexColor(S.GLASS[1], S.GLASS[2], S.GLASS[3], 0.9)
    S.Ring(b, w + 6, S.EDGE)
    S.Text(Field(b, "Name") or (name and _G[name .. "Name"]))
    S.Text(Field(b, "Count") or (name and _G[name .. "Count"]))
    S.Text(Field(b, "HotKey") or (name and _G[name .. "HotKey"]))
end

Area("gamepad", "Gamepad bars", "the gamepad buttons with a slim ring on a dark backing instead of the heavy art", function()
    local n = 0
    for _, name in ipairs(ns.Bars and ns.Bars.BARS or {}) do
        local bar = _G[name]
        if bar and bar.CreateTexture then
            for _, key in ipairs({ "BackgroundWatermark", "LeftButtonFrame", "RightButtonFrame" }) do
                S.KeepHidden(Field(bar, key))
            end
            for i, at in ipairs(CLUSTERS) do                 -- a soft dark pool behind each diamond
                local pool = S.Piece(bar, "pool" .. i, "BACKGROUND", -8, ns.media.disc)
                pool:ClearAllPoints()
                pool:SetPoint("CENTER", bar, "CENTER", at[1], at[2])
                pool:SetSize(124, 124)
                pool:SetVertexColor(0, 0, 0, 0.45)
            end
            for i = 1, 8 do
                local b = _G[name .. "ActionButton" .. i]
                if b then DressButton(b, name .. "ActionButton" .. i); n = n + 1 end
            end
        end
    end
    local page = _G[PAGE]
    if page then
        for _, key in ipairs({ "LeftShoulderBackground", "RightShoulderBackground" }) do S.KeepHidden(Field(page, key)) end
        for _, key in ipairs({ "LeftClassAction", "RightClassAction" }) do
            local b = Field(page, key)
            if b then DressButton(b, b.GetName and b:GetName()); n = n + 1 end
        end
    end
    local legend = _G.GamepadPersistentInputLegend            -- the button hints in the corner
    if legend then n = n + S.TextsIn(legend) end
    return n
end)

---------------------------------------------------------------------------
-- Buffs: each icon cropped and edged thin and dark, its time and stacks in our outline. Buffs come and go,
-- so new ones are dressed as they appear.
---------------------------------------------------------------------------
local function DressBuffs()
    local box = Field(_G.BuffFrame, "AuraContainer")
    if not (box and box.GetChildren) then return 0 end
    local n = 0
    for _, b in ipairs({ box:GetChildren() }) do
        local icon = Field(b, "Icon") or Field(b, "icon")
        if icon and icon.SetTexCoord and not S.done[b] then
            S.done[b] = true
            local coords = { icon:GetTexCoord() }
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            S.Undo(function() if #coords >= 8 then icon:SetTexCoord(unpack(coords)) end end)
            S.Panel(b, 1, { 0, 0, 0, 0.95 }, icon)
            S.Text(Field(b, "Duration"))
            S.Text(Field(b, "Count"))
            n = n + 1
        end
    end
    return n
end

Area("buffs", "Buffs", "your buff and debuff icons cropped and edged, their times outlined", function()
    if not _G.BuffFrame then return 0 end
    DressBuffs()
    return 1
end)
S.Again("buffs", DressBuffs)

---------------------------------------------------------------------------
-- Quest tracker: the gold header bars become dark glass, the text outlined
---------------------------------------------------------------------------
local TRACKERS = { "ObjectiveTrackerFrame", "QuestObjectiveTracker", "CampaignQuestObjectiveTracker",
                   "AchievementObjectiveTracker", "BonusObjectiveTracker", "WorldQuestObjectiveTracker",
                   "ProfessionsRecipeTracker", "MonthlyActivitiesObjectiveTracker", "ScenarioObjectiveTracker",
                   "UIWidgetObjectiveTracker", "AdventureObjectiveTracker", "InitiativeTasksObjectiveTracker" }

Area("tracker", "Quest tracker", "the quest tracker's headers in dark glass, its lines outlined", function()
    local n = 0
    for _, name in ipairs(TRACKERS) do
        local header = Field(_G[name], "Header")
        if header and header.CreateTexture then
            S.KeepHidden(Field(header, "Background"))
            S.Panel(header, 0)
            S.Text(Field(header, "Text"))
            n = n + 1
        end
    end
    S.Font("ObjectiveTrackerHeaderFont", 1)
    S.Font("ObjectiveTrackerLineFont", 1)
    return n
end)

---------------------------------------------------------------------------
-- Minimap: the gold compass rim gives way to a slim ring on a soft dark halo
---------------------------------------------------------------------------
Area("minimap", "Minimap", "a slim ring and a soft halo around the minimap instead of the gold rim", function()
    local map = _G.Minimap
    if not (map and map.CreateTexture) then return 0 end
    S.KeepHidden(_G.MinimapCompassTexture)
    local w = map:GetWidth() or 198
    local halo = S.Piece(map, "halo", "BACKGROUND", -8, ns.media.halo)
    halo:ClearAllPoints()
    halo:SetPoint("CENTER", map, "CENTER", 0, 0)
    halo:SetSize(w * 1.3, w * 1.3)
    halo:SetVertexColor(0, 0, 0, 0.6)
    S.Ring(map, w + 6, { S.EDGE[1], S.EDGE[2], S.EDGE[3], 0.9 }, "OVERLAY", ns.media.mapring)
    S.Text(_G.MinimapZoneText)
    local cluster = _G.MinimapCluster
    if cluster then S.TextsIn(Field(cluster, "ZoneTextButton")) end
    return 1
end)

---------------------------------------------------------------------------
-- Experience and reputation bars: their own art and colours, drawn smaller and slimmer (a size of your choice)
---------------------------------------------------------------------------
ns.RegisterSetting({
    key = "xpScale", kind = "number", default = 0.8, min = 0.5, max = 1.2, percent = true, command = "xpscale",
    section = "Look", label = "Experience bar size",
    tip = "the size of the experience and reputation bars while they are restyled, in percent",
})

Area("xpbar", "Experience bar", "the experience and reputation bars a little smaller, in their own colours", function()
    local mgr = _G.StatusTrackingBarManager
    if not (mgr and mgr.GetScale) then return 0 end
    local set = rawget(mgr, "SetScaleBase") or mgr.SetScale       -- an Edit Mode frame keeps the plain method here
    local was = mgr:GetScale()
    set(mgr, ns.db.xpScale or 0.8)
    S.Undo(function() set(mgr, was) end)
    return 1
end)

---------------------------------------------------------------------------
-- Chat: tab names outlined; the box you type in becomes dark glass
---------------------------------------------------------------------------
Area("chat", "Chat", "chat tab names outlined and the box you type in as dark glass", function()
    local n = 0
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local tab = _G["ChatFrame" .. i .. "Tab"]
        if tab then
            S.Text(Field(tab, "Text") or _G["ChatFrame" .. i .. "TabText"])
            n = n + 1
        end
    end
    local box = _G.ChatFrame1EditBox
    if box and box.CreateTexture then
        for _, part in ipairs({ "Left", "Mid", "Right" }) do S.KeepHidden(_G["ChatFrame1EditBox" .. part]) end
        S.Panel(box, -3)
        n = n + 1
    end
    return n
end)

-- The box you type in stays on screen in some chat styles: its glass shows only while you are typing
local function ChatBoxGlass()
    local box = _G.ChatFrame1EditBox
    local p = box and S.PanelOf(box)
    if not p then return end
    local typing = box.HasFocus and box:HasFocus() and true or false
    for _, t in ipairs(p.all) do if typing then t:Show() else t:Hide() end end
end
S.Again("chat", ChatBoxGlass)

-- Tooltips' background and border, as solid as asked (Tooltip.lua): after the look above has been put on or
-- taken off, so it works on whichever background tooltips have now
ns.RegisterModule("tooltipglass", { Apply = function(_, run)
    ns.Tooltip.running = run and true or false
    ns.Tooltip.Glass()
end })
