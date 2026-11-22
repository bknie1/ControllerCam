-- ControllerCam HUD: the aiming dot, your way.
-- The game's Gamepad UI keeps a small reticle in the middle of the screen (its frame GamepadReticle): a dot,
-- the swing timer round it, and an icon in its place when what you face can be talked to, looted, mailed and
-- so on. With a style of ours chosen, our own reticle sits on the game's (following it wherever the game puts
-- it) and the game's plain dot is only made invisible; the swing timer and the action icons stay the game's and
-- keep working, and ours steps aside while one of those icons shows. Nothing of the game's is hooked or
-- rebuilt: "The game's own" (the default), turning the HUD off or this module off puts every alpha back.
-- Colour: white, your class colour, or by your target (hostile, neutral, friendly). It pops when an ability's
-- moment comes (Abilities ready), unless animations are reduced.

local ADDON, ns = ...
local L, C = ns.L, ns.colors

local RT = { active = false, saved = {}, seen = {}, pops = 0 }
ns.Reticle = RT

RT.STYLES = { "The game's own", "Dot", "Ring", "Ring and dot", "Crosshair", "Chevron" }
RT.COLORS = { "White", "Class colour", "By target" }
-- (in your language: the options show them as L[choice])
RT.NAMES = { L["The game's own"], L["Dot"], L["Ring"], L["Ring and dot"], L["Crosshair"], L["Chevron"],
             L["White"], L["Class colour"], L["By target"] }

local function Changed() if RT.active then RT:Build(); RT:Tick(true) end end
ns.RegisterSetting({
    key = "reticleStyle", kind = "number", default = 1, min = 1, max = #RT.STYLES, section = "Frames",
    choices = RT.STYLES, command = "reticle",
    label = "Aiming dot",
    tip = "the reticle in the middle of the screen: the game's own, or a dot, ring, ring and dot, crosshair or chevron of the HUD's in its place (the swing timer and the game's action icons stay as they are)",
    onChange = function() Changed() end,
})
ns.RegisterSetting({
    key = "reticleColor", kind = "number", default = 3, min = 1, max = #RT.COLORS, section = "Frames",
    choices = RT.COLORS, command = "reticlecolor",
    label = "Aiming dot: colour",
    tip = "white, your class colour, or the colour of your target: red for an enemy, yellow for a neutral one, green for a friend (white with no target)",
    onChange = function() Changed() end,
})
ns.RegisterSetting({
    key = "reticleSize", kind = "number", default = 1, min = 0.5, max = 2.5, percent = true, section = "Frames",
    command = "reticlesize", label = "Aiming dot: size", tip = "how big the HUD's aiming dot is",
    onChange = function() Changed() end,
})
ns.RegisterSetting({
    key = "reticleAlpha", kind = "number", default = 0.9, min = 0.2, max = 1, percent = true, section = "Frames",
    command = "reticlealpha", label = "Aiming dot: opacity", tip = "how solid the HUD's aiming dot is",
    onChange = function() Changed() end,
})

RT.BASE = { dot = 6, ring = 22, arm = 8, thick = 2, gap = 4, chevron = 10 }
RT.POP = 0.25                   -- how long the pop for an ability's moment lasts
RT.TICK = 0.1                   -- how often the game's reticle is looked at

---------------------------------------------------------------------------
-- The game's reticle: its plain dot, told from the icons it shows in its place
---------------------------------------------------------------------------
function RT.Game()
    local g = _G.GamepadReticle
    if type(g) == "table" and type(g.GetObjectType) == "function" then return g end
    return nil
end

-- A texture's name: its atlas, or its file
local function NameOf(t)
    local name
    if t.GetAtlas then
        local ok, a = pcall(t.GetAtlas, t)
        if ok and type(a) == "string" and a ~= "" and not ns.IsSecret(a) then name = a end
    end
    if not name and t.GetTexture then
        local ok, f = pcall(t.GetTexture, t)
        if ok and f ~= nil and not ns.IsSecret(f) then name = tostring(f) end
    end
    return name or "?"
end
RT.NameOf = NameOf

-- An action icon (talk, loot, mail, pick up, can't...): the game's "Crosshair_<what>" art. Anything else is the
-- plain dot (or a part of it).
function RT.IsAction(name)
    if type(name) ~= "string" then return false end
    if not name:find("^Crosshair_") then return false end
    local l = name:lower()
    return not (l:find("standard") or l:find("default") or l:find("dot") or l:find("reticle"))
end

local function Textures(frame, out)
    if not (frame and frame.GetRegions) then return out end
    for _, r in ipairs({ frame:GetRegions() }) do
        if type(r) == "table" and r.GetObjectType and r:GetObjectType() == "Texture" then out[#out + 1] = r end
    end
    return out
end

-- The game's textures that make up its dot and icons: its own, and its Icons'. (Never the swing timer's.)
function RT.Pieces(g)
    local list = Textures(g, {})
    local icons = rawget(g, "Icons")
    if type(icons) == "table" then Textures(icons, list) end
    return list
end

local function Shown(t)
    local ok, v = pcall(t.IsVisible, t)
    return ok and ns.Yes(v)
end

-- Hides the game's dot (its alpha only, and only while it is the dot); returns whether an action icon shows
local function HideDot(g)
    local action = false
    for _, t in ipairs(RT.Pieces(g)) do
        local name = NameOf(t)
        local isAction = RT.IsAction(name)
        RT.seen[name] = isAction and "icon" or "dot"
        if isAction then
            if RT.saved[t] then pcall(t.SetAlpha, t, RT.saved[t]); RT.saved[t] = nil end
            if Shown(t) then action = true end
        else
            if RT.saved[t] == nil then
                local ok, a = pcall(t.GetAlpha, t)
                RT.saved[t] = (ok and type(a) == "number" and not ns.IsSecret(a)) and a or 1
            end
            pcall(t.SetAlpha, t, 0)
        end
    end
    return action
end

function RT.Restore()
    for t, a in pairs(RT.saved) do pcall(t.SetAlpha, t, a) end
    RT.saved = {}
end

---------------------------------------------------------------------------
-- Ours
---------------------------------------------------------------------------
local frame
local function Piece(layer, sub)
    local t = frame:CreateTexture(nil, layer, nil, sub)
    t:Hide()
    return t
end

local function Ensure()
    if frame then return frame end
    frame = CreateFrame("Frame", "ControllerCamHUD_Reticle", UIParent)
    frame:SetSize(48, 48)
    frame:SetFrameStrata("LOW")
    frame:SetFrameLevel(50)
    frame:Hide()
    frame.pieces = {}
    RT.frame = frame
    return frame
end

-- One shape: a texture in the colour, with a darker copy under it so it reads on snow and on night alike
local function Add(kind, w, h, x, y, angle)
    local back, front = Piece("ARTWORK", 0), Piece("ARTWORK", 2)
    for _, t in ipairs({ back, front }) do
        if kind == "line" then t:SetColorTexture(1, 1, 1, 1) else t:SetTexture(ns.media[kind]) end
        if angle and t.SetRotation then t:SetRotation(angle) end
        t:Show()
    end
    local pad = kind == "line" and 2 or 3
    back:SetSize(w + pad, h + pad)
    back:SetPoint("CENTER", frame, "CENTER", x, y)
    front:SetSize(w, h)
    front:SetPoint("CENTER", frame, "CENTER", x, y)
    back:SetVertexColor(0, 0, 0, 0.55)
    frame.pieces[#frame.pieces + 1] = { front = front, back = back }
end

function RT:Build()
    Ensure()
    for _, p in ipairs(frame.pieces) do p.front:Hide(); p.back:Hide() end
    frame.pieces = {}
    local style = ns.db.reticleStyle or 1
    local k = ns.Clamp(tonumber(ns.db.reticleSize) or 1, 0.5, 2.5)
    local B = RT.BASE
    local dot, ring, arm, thick, gap = B.dot * k, B.ring * k, B.arm * k, math.max(1, B.thick * k), B.gap * k
    if style == 2 then
        Add("disc", dot, dot, 0, 0)
    elseif style == 3 then
        Add("ring", ring, ring, 0, 0)
    elseif style == 4 then
        Add("ring", ring, ring, 0, 0)
        Add("disc", dot * 0.8, dot * 0.8, 0, 0)
    elseif style == 5 then
        local d = gap + arm / 2
        Add("line", thick, arm, 0, d)
        Add("line", thick, arm, 0, -d)
        Add("line", arm, thick, d, 0)
        Add("line", arm, thick, -d, 0)
        Add("disc", thick * 1.6, thick * 1.6, 0, 0)
    elseif style == 6 then
        local c = B.chevron * k
        local s = c * 0.35
        Add("line", c, thick, -s, -s * 0.7, math.pi / 4)
        Add("line", c, thick, s, -s * 0.7, -math.pi / 4)
    end
    self.style = style
end

-- The colour now
function RT.Color()
    local choice = ns.db.reticleColor or 3
    if choice == 2 then
        local _, class = UnitClass("player")
        local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if c then return c.r, c.g, c.b end
    elseif choice == 3 and ns.Yes(UnitExists("target")) and not ns.Yes(UnitIsDead("target")) then
        if ns.Yes(UnitCanAttack("player", "target")) then
            local r = ns.Plain(UnitReaction("target", "player"))
            local c = (type(r) == "number" and r == 4) and C.neutral or C.hostile
            return c[1], c[2], c[3]
        end
        return C.friendly[1], C.friendly[2], C.friendly[3]
    end
    return C.text[1], C.text[2], C.text[3]
end

-- An ability's moment (Numbers.lua's Abilities ready): ours pops
function RT:Pop()
    if not (self.active and frame and frame:IsShown()) then return end
    self.popAt = GetTime()
    self.pops = self.pops + 1
end

function RT:Tick(force)
    local g = RT.Game()
    local want = self.active and (ns.db.reticleStyle or 1) > 1 and g ~= nil and Shown(g)
    if not want then
        if frame then frame:Hide() end
        if next(RT.saved) then RT.Restore() end
        self.action = false
        return
    end
    Ensure()
    if self.style ~= ns.db.reticleStyle then self:Build() end
    self.action = HideDot(g)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", g, "CENTER", 0, 0)
    local r, gr, b = RT.Color()
    local alpha = ns.Clamp(tonumber(ns.db.reticleAlpha) or 0.9, 0.2, 1)
    local scale = 1
    if self.popAt then
        local t = GetTime() - self.popAt
        if t >= RT.POP then
            self.popAt = nil
        else
            local k = 1 - t / RT.POP
            local red = ns.Ready and ns.Ready.COLOR or { 1, 0.18, 0.14 }
            r, gr, b = r + (red[1] - r) * k, gr + (red[2] - gr) * k, b + (red[3] - b) * k
            if not (ns.Calm and ns.Calm()) then scale = 1 + 0.6 * k end
        end
    end
    for _, p in ipairs(frame.pieces) do p.front:SetVertexColor(r, gr, b, 1) end
    self.color = { r, gr, b }
    frame:SetScale(scale)
    frame:SetAlpha(self.action and 0 or alpha)          -- the game's icon in its place: ours steps aside
    frame:Show()
end

local driver = CreateFrame("Frame")
local since = 0
driver:SetScript("OnUpdate", ns.Protect(function(_, dt)
    if not RT.active then return end
    since = since + dt
    if since < RT.TICK and not RT.popAt then return end
    since = 0
    RT:Tick()
end))

function RT:Apply(run)
    self.active = run and true or false
    if self.active then
        self:Build()
        self:Tick(true)
    else
        if frame then frame:Hide() end
        RT.Restore()
    end
end

function RT.Describe()
    local g = RT.Game()
    local out = { ("style %s, colour %s, size %s, opacity %s; the game's reticle %s"):format(
        tostring(ns.db and ns.db.reticleStyle), tostring(ns.db and ns.db.reticleColor),
        tostring(ns.db and ns.db.reticleSize), tostring(ns.db and ns.db.reticleAlpha),
        g and (Shown(g) and "shown" or "hidden") or "missing") }
    if g then
        for i, t in ipairs(RT.Pieces(g)) do
            local w, h = t:GetSize()
            out[#out + 1] = ("piece %d: %s, %sx%s, %s, alpha %s%s"):format(i, NameOf(t), tostring(w), tostring(h),
                Shown(t) and "shown" or "hidden", tostring(t:GetAlpha()), RT.saved[t] and " (hidden by us)" or "")
        end
    end
    local seen = {}
    for name, kind in pairs(RT.seen) do seen[#seen + 1] = name .. " = " .. kind end
    table.sort(seen)
    if #seen > 0 then out[#out + 1] = "seen: " .. table.concat(seen, ", ") end
    out[#out + 1] = ("pops %d"):format(RT.pops)
    return out
end

ns.RegisterModule("reticle", RT)
