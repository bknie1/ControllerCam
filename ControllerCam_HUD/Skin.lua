-- ControllerCam HUD: the game's own frames in the HUD's look.
-- The tooltips, buffs, quest tracker, minimap, experience bar, chat tabs and gamepad bars stay the game's: they
-- keep working, keep their options and positions, and the mouse UI keeps its look. While the HUD runs, they are
-- dressed like the HUD: dark glass panels with a thin edge, round buttons with a slim ring, outlined text.
--
-- How, so nothing of the game's is broken:
--   * We never hook the game's code and never write our own fields onto its frames (that could make a
--     protected action, like cancelling a buff or pressing an action button, fail). What we add is kept in
--     tables of our own.
--   * Every change is written down with how to undo it. Switching off, going back to the mouse UI, or
--     disabling the addon puts every frame back exactly as it was.
--   * Text is restyled through the game's shared fonts (one change reaches every line that uses them).
--   * Each area is dressed on its own, protected: an area this client does not have is skipped.

local ADDON, ns = ...

local S = { active = false, areas = {}, order = {}, done = {}, undo = {}, dressed = 0 }
ns.Skin = S

ns.RegisterSetting({
    key = "skin", kind = "boolean", default = true, command = "skin", section = "Look",
    label = "Restyle the game's own frames",
    tip = "tooltips, buffs, the quest tracker, the minimap, the experience bar, chat tabs and the gamepad bars in the HUD's look (the mouse UI keeps the game's)",
})

-- The palette of the dressing
S.GLASS = { 0.03, 0.04, 0.07, 0.82 }
S.EDGE = { 0.55, 0.62, 0.75, 0.55 }
S.SHINE = { 1, 1, 1, 0.06 }

---------------------------------------------------------------------------
-- Undo: every change says how to put it back
---------------------------------------------------------------------------
local function Undo(fn) S.undo[#S.undo + 1] = fn end
S.Undo = Undo

-- A region (texture, frame) of the game's made invisible while we dress it, shown again on undo
function S.HideArt(region)
    if type(region) ~= "table" or not (region.SetAlpha and region.GetAlpha) or S.done[region] then return end
    S.done[region] = true
    local was = region:GetAlpha()
    region:SetAlpha(0)
    Undo(function() region:SetAlpha(was); S.done[region] = nil end)
end

-- Same, for art the game sets visible again by itself now and then: kept invisible by our own timer. The
-- slim gamepad bars (Bars.lua) hide some of the same art: whoever lets go last puts it back.
S.orig = {}
function S.KeepHidden(region)
    if type(region) ~= "table" or not region.SetAlpha or S.done[region] then return end
    S.done[region] = true
    local was = S.orig[region] or region:GetAlpha()
    S.orig[region] = was
    ns.KeepAlpha(region, 0)
    Undo(function()
        ns.KeepAlpha(region, nil)
        S.done[region], S.orig[region] = nil, nil
        local bars = ns.Bars
        if not (bars and bars.hidden and bars.hidden[region] ~= nil) then region:SetAlpha(was) end
    end)
end
-- The alpha a region had before we hid it (for Bars.lua)
function S.Original(region) return S.orig[region] end

-- Every font string in a frame and its children (a few levels down): our outline
function S.TextsIn(frame, depth)
    if type(frame) ~= "table" or (depth or 0) > 3 then return 0 end
    local n = 0
    if frame.GetRegions then
        for _, r in ipairs({ frame:GetRegions() }) do
            if r.GetObjectType and r:GetObjectType() == "FontString" then S.Text(r); n = n + 1 end
        end
    end
    if frame.GetChildren then
        for _, c in ipairs({ frame:GetChildren() }) do n = n + S.TextsIn(c, (depth or 0) + 1) end
    end
    return n
end

-- One of the game's shared fonts (a Font object such as GameTooltipText): our outline, its size times k
function S.Font(name, k, flags)
    local font = type(name) == "string" and _G[name] or name
    if type(font) ~= "table" or not (font.GetFont and font.SetFont) or S.done[font] then return end
    local file, size, was = font:GetFont()
    if not file or not size then return end
    S.done[font] = true
    font:SetFont(file, math.floor(size * (k or 1) + 0.5), flags or "OUTLINE")
    local sx, sy = 0, 0
    if font.GetShadowOffset then sx, sy = font:GetShadowOffset() end
    if font.SetShadowOffset then font:SetShadowOffset(1, -1) end
    Undo(function()
        font:SetFont(file, size, was or "")
        if font.SetShadowOffset then font:SetShadowOffset(sx, sy) end
        S.done[font] = nil
    end)
end

-- A font string of the game's: our outline (its own font and size)
function S.Text(fs, k)
    if type(fs) ~= "table" or not (fs.GetFont and fs.SetFont) or S.done[fs] then return end
    local file, size, was = fs:GetFont()
    if not file or not size then return end
    S.done[fs] = true
    fs:SetFont(file, math.floor(size * (k or 1) + 0.5), "OUTLINE")
    Undo(function() fs:SetFont(file, size, was or ""); S.done[fs] = nil end)
end

---------------------------------------------------------------------------
-- What we add: glass panels and rings, made once per frame of the game's and kept in our own table
---------------------------------------------------------------------------
local added = setmetatable({}, { __mode = "k" })     -- game frame -> { panel =, ring = ... }
S.added = added

local function Bag(frame)
    local bag = added[frame]
    if not bag then bag = {}; added[frame] = bag end
    return bag
end
S.Bag = Bag

-- A texture of ours on a frame of the game's, made once and shown while dressed
function S.Piece(frame, key, layer, sub, texture)
    local bag = Bag(frame)
    local t = bag[key]
    if not t then
        t = frame:CreateTexture(nil, layer or "BACKGROUND", nil, sub or -8)
        if texture then t:SetTexture(texture) end
        bag[key] = t
    end
    t:Show()
    Undo(function() t:Hide() end)
    return t
end

-- A dark glass panel with a thin edge behind a frame of the game's (inset: how far it reaches out). Drawn on
-- the frame itself, in its lowest layer, so it is always under the frame's own text and icons.
local function PanelShow(p, on)
    for _, t in ipairs(p.all) do if on then t:Show() else t:Hide() end end
end

-- at: the region the panel wraps (the frame itself when nil), e.g. a buff's icon inside its button
function S.Panel(frame, inset, edge, at)
    if type(frame) ~= "table" or not frame.CreateTexture then return nil end
    at = at or frame
    local bag = Bag(frame)
    local p = bag.panel
    if not p then
        p = { edges = {} }
        p.back = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
        p.shine = frame:CreateTexture(nil, "BACKGROUND", nil, -7)    -- a faint light along the top
        for i = 1, 4 do p.edges[i] = frame:CreateTexture(nil, "BACKGROUND", nil, -6) end
        p.all = { p.back, p.shine, p.edges[1], p.edges[2], p.edges[3], p.edges[4] }
        bag.panel = p
    end
    inset = inset or 0
    local function Place(t, a1, a2, x1, y1, x2, y2)
        t:ClearAllPoints()
        t:SetPoint(a1, at, a1, x1, y1)
        t:SetPoint(a2, at, a2, x2, y2)
    end
    Place(p.back, "TOPLEFT", "BOTTOMRIGHT", -inset, inset, inset, -inset)
    Place(p.shine, "TOPLEFT", "TOPRIGHT", -inset + 1, inset - 1, inset - 1, inset - 1)
    p.shine:SetHeight(1)
    Place(p.edges[1], "TOPLEFT", "TOPRIGHT", -inset, inset, inset, inset)
    p.edges[1]:SetHeight(1)
    Place(p.edges[2], "BOTTOMLEFT", "BOTTOMRIGHT", -inset, -inset, inset, -inset)
    p.edges[2]:SetHeight(1)
    Place(p.edges[3], "TOPLEFT", "BOTTOMLEFT", -inset, inset, -inset, -inset)
    p.edges[3]:SetWidth(1)
    Place(p.edges[4], "TOPRIGHT", "BOTTOMRIGHT", inset, inset, inset, -inset)
    p.edges[4]:SetWidth(1)
    p.edge = edge or S.EDGE
    S.PanelAlpha(p, p.k or 1)
    PanelShow(p, true)
    Undo(function() PanelShow(p, false) end)
    return p
end

function S.EdgeColor(p, c)
    if not p then return end
    p.edge = c
    local k = p.k or 1
    for _, t in ipairs(p.edges) do t:SetColorTexture(c[1], c[2], c[3], (c[4] or 1) * k) end
end

-- How solid a panel is: 1 as it is made, 0 nothing left of it (its glass, its light and its edge alike)
function S.PanelAlpha(p, k)
    if not p then return end
    p.k = k
    p.back:SetColorTexture(S.GLASS[1], S.GLASS[2], S.GLASS[3], S.GLASS[4] * k)
    p.shine:SetColorTexture(S.SHINE[1], S.SHINE[2], S.SHINE[3], S.SHINE[4] * k)
    S.EdgeColor(p, p.edge or S.EDGE)
end

-- The panel already made for a frame, if any
function S.PanelOf(frame) return added[frame] and added[frame].panel end

-- A slim ring around a round thing of the game's (a gamepad button, the minimap); size: its diameter;
-- texture: a larger one for large things, so the line stays clean
function S.Ring(frame, size, color, layer, texture)
    if not frame then return nil end
    local bag = Bag(frame)
    local r = bag.ring
    if not r then
        r = frame:CreateTexture(nil, layer or "OVERLAY", nil, 6)
        bag.ring = r
    end
    r:SetTexture(texture or ns.media.ring)
    r:ClearAllPoints()
    r:SetPoint("CENTER", frame, "CENTER", 0, 0)
    r:SetSize(size, size)
    local c = color or S.EDGE
    r:SetVertexColor(c[1], c[2], c[3], 1)
    r:SetAlpha(c[4] or 1)
    r:Show()
    Undo(function() r:Hide() end)
    return r
end

---------------------------------------------------------------------------
-- Areas: each one dresses a part of the game's interface. fn returns how many frames it dressed (0: this
-- client has none of it).
---------------------------------------------------------------------------
function S.Area(key, label, fn, setting)
    S.areas[key] = { key = key, label = label, fn = fn, setting = setting }
    S.order[#S.order + 1] = key
end

local function Dress()
    S.dressed, S.found = 0, {}
    for _, key in ipairs(S.order) do
        local area = S.areas[key]
        if not area.setting or ns.db[area.setting] ~= false then
            local ok, n = pcall(area.fn)
            if ok then
                S.found[key] = n or 0
                S.dressed = S.dressed + (n or 0)
            else
                S.found[key] = -1
                ns.Error(("skin %s: %s"):format(key, tostring(n)))
            end
        end
    end
end

local function Undress()
    for i = #S.undo, 1, -1 do pcall(S.undo[i]) end
    S.undo = {}
    S.done = {}
    S.dressed = 0
end

-- Frames the game makes later (a buff appears, the tracker grows) are dressed by a slow look-around of our own
local since = 0
local watcher = CreateFrame("Frame")
local function Watch(_, dt)
    since = since + dt
    if since < 0.5 then return end
    since = 0
    for _, key in ipairs(S.order) do
        local area = S.areas[key]
        if area.again and (not area.setting or ns.db[area.setting] ~= false) then
            local ok, err = pcall(area.again)
            if not ok then ns.Error(("skin %s: %s"):format(key, tostring(err))) end
        end
    end
end
Watch = ns.Protect(Watch)

-- An area with frames that come and go: again() runs twice a second while the dressing is on
function S.Again(key, fn) S.areas[key].again = fn end

function S:Apply(run)
    local want = run and ns.db.skin and true or false
    if want == self.active then
        if want then Undress(); Dress() end              -- a switch changed: dress again from the start
        return
    end
    self.active = want
    if want then
        Dress()
        watcher:SetScript("OnUpdate", Watch)
    else
        watcher:SetScript("OnUpdate", nil)
        Undress()
    end
end

ns.RegisterCheck(function(row, run, db)
    local want = (run and db.skin) and true or false
    row(want and "the game's frames wear the HUD's look" or "the game's frames keep their own look", S.active == want)
    if want then
        for _, key in ipairs(S.order) do
            local n = S.found and S.found[key]
            if n == -1 then row("restyle: " .. key, false, "failed: the error was shown in chat") end
        end
        row("restyle found frames to dress", S.dressed > 0, S.dressed .. " dressed")
    end
end)

ns.RegisterModule("skin", S)
