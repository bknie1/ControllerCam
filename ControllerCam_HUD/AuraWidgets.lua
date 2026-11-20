-- ControllerCam HUD: effects drawn by the game itself.
-- This client does not let addons read the effects on a unit when their details are secret. Instead it offers
-- a display element, an "AuraContainer": give it a unit and a filter ("harmful, yours, not crowd control"),
-- and the game draws the icons, their time and their stacks itself. We give each of its icons our look.
-- Where a client has no such element, the rows of our own (Auras.lua, PlateStates.lua) are used instead.

local ADDON, ns = ...

local W = {}
ns.AuraWidgets = W

-- Does this client have it? (Asked once, by trying to make one.)
function W.Available()
    if W.available == nil then
        local ok, frame = pcall(CreateFrame, "AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
        W.available = (ok and frame and type(frame.AddAuraGroup) == "function") and true or false
        if frame and frame.Hide then frame:Hide() end
    end
    return W.available
end

-- How the game writes an icon's time: whole seconds, red under five (running out), minutes from a minute on.
-- Built once with the game's own number formatter, where this client has it.
local formatter
local function Formatter()
    if formatter ~= nil then return formatter or nil end
    formatter = false
    local SU, round = C_StringUtil, Enum and Enum.NumericRuleFormatRounding
    if not (SU and SU.CreateNumericRuleFormatter and round) then return nil end
    local ok, f = pcall(SU.CreateNumericRuleFormatter)
    if not ok or not f then return nil end
    local danger = ns.colors.danger
    local red = ("|cff%02x%02x%02x%%d|r"):format(danger[1] * 255, danger[2] * 255, danger[3] * 255)
    ok = pcall(f.SetBreakpoints, f, {
        { threshold = 0, step = 1, format = red, rounding = round.Up },
        { threshold = 5, step = 1, format = "%d", rounding = round.Up },
        { threshold = 60, format = COOLDOWN_DURATION_MIN or "%dm",
          components = { { div = 60, step = 1, rounding = round.Up } } },
    })
    if ok then formatter = f end
    return formatter or nil
end
W.Formatter = Formatter

---------------------------------------------------------------------------
-- What is worth showing. A row can hold several groups, each a filter the game understands ("HELPFUL",
-- "IMPORTANT": marked by the game as worth watching, boss mechanics among them; "RAID" on a harmful effect: one
-- you can dispel; "!X": not X) and extra conditions on the effect (its dispel type, whether you can dispel or
-- steal it). The game draws each group in turn; no effect is in two of them.
---------------------------------------------------------------------------
local ENRAGE = { Enrage = true }
local DISPEL = (AuraUtil and AuraUtil.AuraFilters and AuraUtil.AuraFilters.RaidPlayerDispellable) or "RAID"

-- An enemy's buffs that matter: the ones the game marks as important, enrages, and the ones you can dispel
-- or steal. Never the ones that are just always there.
-- (fallback: the filter used when the game does not know the first one; max: at most this many from the group,
-- so all of a row's groups together stay one short line)
W.ENEMY_BUFFS = {
    { "HELPFUL|IMPORTANT|!PLAYER", max = 3 },
    { "HELPFUL|!IMPORTANT|!PLAYER", { includeDispelTypes = ENRAGE }, fallback = "HELPFUL|!PLAYER", max = 1 },
    { "HELPFUL|!IMPORTANT|!PLAYER", { isStealable = true, excludeDispelTypes = ENRAGE }, fallback = "HELPFUL|!PLAYER", max = 2 },
}
-- On an enemy: your own debuffs, then the ones the game marks as important (crowd control has its own icon)
W.ENEMY_DEBUFFS = {
    { "HARMFUL|!CROWD_CONTROL|PLAYER" },
    { "HARMFUL|!CROWD_CONTROL|IMPORTANT|!PLAYER", max = 2 },
}
-- On a friend: what you can dispel, then what the game marks as important (boss mechanics), then crowd control
W.FRIEND_DEBUFFS = {
    { "HARMFUL|" .. DISPEL },
    { "HARMFUL|IMPORTANT|!" .. DISPEL, max = 2 },
    { "HARMFUL|CROWD_CONTROL|!IMPORTANT|!" .. DISPEL, fallback = "HARMFUL|CROWD_CONTROL|!" .. DISPEL, max = 1 },
}

-- Our look on one of the game's icons. The game sizes these frames itself (at first to nothing), so every
-- piece has its own size around the frame's centre instead of filling the frame. typed: an edge in the colour
-- of the effect's kind (magic, curse, poison, disease, enrage), drawn by the game, where it has one.
local function Styler(size, textSize, edge, below, typed)
    local half = size / 2
    return function(f)
        if f.SetFlattensRenderLayers then f:SetFlattensRenderLayers(true) end
        if f.EnableMouseMotion then f:EnableMouseMotion(false) end
        f:SetSize(size, size)
        local back = f:CreateTexture(nil, "BACKGROUND", nil, -8)
        back:SetPoint("CENTER", f, "CENTER", 0, 0)
        back:SetSize(size + 2, size + 2)
        local c = edge or { 0.02, 0.03, 0.06, 0.9 }
        back:SetColorTexture(c[1], c[2], c[3], c[4] or 0.95)
        if typed and f.AddDispelTypeTexture then
            local kind = f:CreateTexture(nil, "BACKGROUND", nil, -7)
            kind:SetPoint("CENTER", f, "CENTER", 0, 0)
            kind:SetSize(size + 4, size + 4)
            kind:SetColorTexture(1, 1, 1, 1)
            local style = Enum and Enum.CustomAuraButtonDispelTypeTextureStyle
            local ok = pcall(f.AddDispelTypeTexture, f, kind, { showIcon = false, showWhenHarmful = true,
                showWhenHelpful = true, style = style and style.PreserveAsset })
            if not ok then kind:Hide() end
        end
        local icon = f:CreateTexture(nil, "BACKGROUND", nil, -6)
        icon:SetPoint("CENTER", f, "CENTER", 0, 0)
        icon:SetSize(size, size)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        f:SetIcon(icon)
        local cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
        cd:SetPoint("CENTER", f, "CENTER", 0, 0)
        cd:SetSize(size, size)
        if cd.SetFrameLevel and f.GetFrameLevel then cd:SetFrameLevel(f:GetFrameLevel()) end
        cd:SetReverse(true)
        if cd.SetDrawBling then cd:SetDrawBling(false) end
        if cd.SetDrawEdge then cd:SetDrawEdge(false) end
        if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(true) end
        f:SetDurationCooldown(cd)
        local time = ns.FontString(f, textSize, "CENTER")
        if time.SetDrawLayer then time:SetDrawLayer("OVERLAY", 6) end
        if below then time:SetPoint("TOP", f, "CENTER", 0, -half - 1) else time:SetPoint("CENTER", f, "CENTER", 0, half) end
        if f.SetDurationText then pcall(f.SetDurationText, f, time, { textFormatter = Formatter() }) end
        local count = ns.FontString(f, textSize - 2, "RIGHT")
        if count.SetDrawLayer then count:SetDrawLayer("OVERLAY", 7) end
        count:SetPoint("BOTTOMRIGHT", f, "CENTER", half + 2, -half - 1)
        if f.SetApplicationCount then pcall(f.SetApplicationCount, f, count, {}) end
    end
end

-- What a row shows: one filter ("HARMFUL|PLAYER"), or a list of groups { { filter, conditions }, ... }.
-- A group the game refuses (a filter or condition this client does not know) is switched off rather than
-- left showing everything.
local function Apply(row, what)
    local groups = type(what) == "table" and what or { { what } }
    for i, g in ipairs(groups) do
        local key = tostring(i)
        if i > row.count then
            row:AddAuraGroup(key, "", { initializeFrame = row.styler })
            -- each group's icons at our size, on the same line as the group before (the game lays every
            -- group of a row out together); a client without one of these settings gets the plain spacing
            if not pcall(row.SetAuraGroupLayout, row, key, row.layout) then
                pcall(row.SetAuraGroupLayout, row, key, { elementSpacing = row.layout.elementSpacing,
                                                          lineSpacing = row.layout.lineSpacing })
            end
            row.count = i
        end
        local ok = (pcall(row.SetAuraGroupFilterString, row, key, g[1])
                    or (g.fallback and pcall(row.SetAuraGroupFilterString, row, key, g.fallback)))
            and pcall(row.SetAuraGroupCandidateFilters, row, key, g[2] or {})
            and pcall(row.SetAuraGroupMaxFrameCount, row, key, math.min(g.max or row.max, row.max))
        row:SetAuraGroupEnabled(key, ok and true or false)
    end
    for i = #groups + 1, row.count do row:SetAuraGroupEnabled(tostring(i), false) end
    row.filter = what
end

-- A row of the game's icons: { filter = "HARMFUL|PLAYER" or groups (above), max = 4, size = 18, text = 9,
-- edge = {r,g,b,a}, grow = "RIGHT" | "LEFT", down = true (a row under something: it starts at its top and any
-- second line goes below; otherwise it starts at its bottom and goes up), spacing = 5, below = true (the time
-- under each icon), typed = true (an edge in the colour of the effect's kind) }. Returns the row, or nil when
-- this client cannot. Place it with row.point (the corner it starts from): row:SetPoint(row.point, ...).
function W.Row(parent, opts)
    if not W.Available() then return nil end
    local ok, row = pcall(CreateFrame, "AuraContainer", nil, parent, "CustomAuraContainerTemplate")
    if not ok or not row then return nil end
    local gap = opts.spacing or 5                       -- room for each icon's time beside the next one
    row.styler = Styler(opts.size, opts.text, opts.edge, opts.below, opts.typed)
    row.layout = { elementSpacing = gap, lineSpacing = 3, groupSpacing = gap, groupLineSpacing = 3,
                   forceNewLine = false, elementWidth = opts.size, elementHeight = opts.size }
    row.count, row.max = 0, opts.max
    row.point = (opts.down and "TOP" or "BOTTOM") .. (opts.grow == "LEFT" and "RIGHT" or "LEFT")
    local flow = AnchorUtil and AnchorUtil.FlowDirection
    if flow and row.SetFlowLayoutGrowthDirection then
        local across = (opts.grow == "LEFT") and flow.Left or flow.Right
        row:SetFlowLayoutGrowthDirection(across, opts.down and flow.Down or flow.Up)
    end
    if row.SetFlowLayoutAnchorPoint then row:SetFlowLayoutAnchorPoint(row.point) end
    -- one line, however many groups have something to show (the groups' own limits keep it short)
    if row.SetFlowLayoutMaximumLineSize then pcall(row.SetFlowLayoutMaximumLineSize, row, 4096) end
    row:SetSize(opts.max * (opts.size + gap) - gap, opts.size)
    Apply(row, opts.filter)
    row:SetEnabled(false)
    row:Hide()
    return row
end

-- Point a row at a unit, with a filter (or groups) when it changes. on = false switches it off. fresh: the
-- unit token stays the same but now means another unit (a new target, a plate reused), so the game should
-- look again.
function W.Show(row, unit, filter, on, fresh)
    if not row then return end
    if unit and on then
        if filter and row.filter ~= filter then
            Apply(row, filter)
            fresh = true
        end
        if fresh or row.unit ~= unit or not row.on then
            row.unit = unit
            row:SetUnit(unit)
        end
        if not row.on then
            row.on = true
            row:SetEnabled(true)
            row:Show()
        end
    elseif row.on ~= false then
        row.on, row.unit = false, nil
        row:SetEnabled(false)
        row:Hide()
    end
end

-- Is anything under this filter on the unit? (The game counts; we do not read the effects.)
function W.Has(unit, filter)
    if not (C_UnitAuras and C_UnitAuras.GetUnitAuraInstanceIDs) then return nil end
    local ok, ids = pcall(C_UnitAuras.GetUnitAuraInstanceIDs, unit, filter)
    if not ok or type(ids) ~= "table" then return nil end
    return #ids > 0
end
