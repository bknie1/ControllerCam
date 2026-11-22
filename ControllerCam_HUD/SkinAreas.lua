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

---------------------------------------------------------------------------
-- Damage meter: the game's own meter keeps all it does (sessions, kinds, its settings, and the numbers, which
-- the game may keep secret in a fight: only its own code reads them); each row's bar is dressed as the HUD's
-- bars are: the slim bar texture, slanted ends, a dark back under it in place of the game's, and the text in our
-- outline. The game reuses rows as the list scrolls and may set a bar's look again: looked at again twice a
-- second. Nothing is written into the game's frames and none of its functions is called to change it (that would
-- run its code in our name and could break its secret numbers): what we changed is kept in tables of our own.
---------------------------------------------------------------------------
local meterBars = setmetatable({}, { __mode = "k" })     -- status bar -> { own = its texture, ours = ours as read back }
S.meterBars = meterBars
local function MeterBars(frame, depth, list)
    if type(frame) ~= "table" or depth > 6 or not frame.GetChildren then return list end
    for _, child in ipairs({ frame:GetChildren() }) do
        local ok, kind = pcall(child.GetObjectType, child)
        if ok and kind == "StatusBar" then list[#list + 1] = child end
        MeterBars(child, depth + 1, list)
    end
    return list
end

-- The HUD's bar look on one of the meter's bars: slanted ends (a mask on its fill), a dark back of ours under
-- it, and the game's own backing put out of sight (its icon and text stay as they are)
local function DressMeterBar(bar, rec)
    local fill = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
    if not rec.back and bar.CreateTexture then
        local back = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
        back:SetAllPoints(bar)
        local c = ns.colors.back
        back:SetColorTexture(c[1], c[2], c[3], 0.85)
        rec.back = back
        rec.hidden = {}
        for _, r in ipairs({ bar:GetRegions() }) do              -- the game's backing: a background texture
            local okK, kind = pcall(r.GetObjectType, r)
            local okL, layer = pcall(r.GetDrawLayer, r)
            if okK and kind == "Texture" and r ~= back and r ~= fill and okL and layer == "BACKGROUND" then
                rec.hidden[r] = r:GetAlpha()
                r:SetAlpha(0)
            end
        end
        if bar.CreateMaskTexture then
            pcall(function()
                local mask = bar:CreateMaskTexture()
                mask:SetAllPoints(bar)
                mask:SetTexture(ns.media.mask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
                back:AddMaskTexture(mask)
                rec.mask = mask
            end)
        end
        S.Undo(function()
            back:Hide()
            for r, a in pairs(rec.hidden or {}) do pcall(r.SetAlpha, r, a) end
            if rec.mask and rec.masked and rec.masked.RemoveMaskTexture then
                pcall(rec.masked.RemoveMaskTexture, rec.masked, rec.mask)
            end
            rec.back, rec.hidden, rec.mask, rec.masked = nil, nil, nil, nil
        end)
    end
    rec.back:Show()
    if rec.mask and fill and rec.masked ~= fill then             -- a new fill texture: slant it too
        if pcall(fill.AddMaskTexture, fill, rec.mask) then rec.masked = fill end
    end
end

-- What the meter shows, for the reports: its windows, which session and kind each shows (read only), its bars
function S.MeterDescribe()
    local out = {}
    for i = 1, 4 do
        local w = _G["DamageMeterSessionWindow" .. i]
        if type(w) == "table" then
            local function Ask(name)
                local fn = w[name]
                if type(fn) ~= "function" then return "-" end
                local ok, v = pcall(fn, w)
                return ok and tostring(ns.Plain(v)) or "error"
            end
            local bars = MeterBars(w, 1, {})
            local dressed = 0
            for _, b in ipairs(bars) do if meterBars[b] and meterBars[b].back then dressed = dressed + 1 end end
            out[#out + 1] = ("window %d: shown %s, session type %s, session %s, kind %s, style %s, bars %d (dressed %d)")
                :format(i, tostring(w:IsShown()), Ask("GetSessionType"), Ask("GetSessionID"), Ask("GetDamageMeterType"),
                        Ask("GetStyle"), #bars, dressed)
            local first = bars[1]
            if first then
                local parts = {}
                for _, r in ipairs({ first:GetRegions() }) do
                    local okK, kind = pcall(r.GetObjectType, r)
                    local okL, layer = pcall(r.GetDrawLayer, r)
                    parts[#parts + 1] = tostring(okK and kind) .. "/" .. tostring(okL and layer)
                end
                out[#out + 1] = "  first bar's regions: " .. table.concat(parts, ", ")
            end
        end
    end
    return out
end

local function DressMeter()
    local n = 0
    for i = 1, 4 do
        local w = _G["DamageMeterSessionWindow" .. i]
        if type(w) == "table" then
            for _, bar in ipairs(MeterBars(w, 1, {})) do
                local tex = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
                local now = tex and tex.GetTexture and tex:GetTexture()
                local rec = meterBars[bar]
                if not rec then
                    rec = { own = now }
                    meterBars[bar] = rec
                    S.Undo(function()
                        if rec.own then pcall(bar.SetStatusBarTexture, bar, rec.own) end
                        meterBars[bar] = nil
                    end)
                end
                if rec.ours == nil or now ~= rec.ours then          -- new, or the game set its own look again
                    bar:SetStatusBarTexture(ns.media.bar)
                    local t = bar:GetStatusBarTexture()
                    rec.ours = t and t.GetTexture and t:GetTexture()
                end
                DressMeterBar(bar, rec)
                n = n + 1
            end
            S.TextsIn(w, 0)
        end
    end
    return n
end

Area("damagemeter", "Damage meter", "the game's damage meter in the HUD's look: its bars, slanted on a dark back, and outlined text; it keeps all it does", function()
    if not _G.DamageMeter then return 0 end
    DressMeter()
    return 1
end)
S.Again("damagemeter", DressMeter)
