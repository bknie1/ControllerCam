-- ControllerCam HUD: the stance and pet buttons, where their wheel fits.
-- The gamepad bars keep two round buttons under the clusters, by the bottom of the screen: your stances (or
-- forms, auras...) and your pet's commands. Each opens a wheel of choices around itself, and down there the
-- lower half of that wheel is off the screen. Above the clusters sit the green and red targeting icons, which
-- only say what the triggers already do. So: the two buttons move up to where those icons are, and the icons
-- go invisible. The buttons stay the game's own (bindings, wheel, everything); only where they sit changes,
-- and only out of combat, as the game requires. Off, in Edit Mode or with the HUD off, all of it is put back.
--
-- The wheel: the game lays its bars out afresh as the wheel opens, which puts the button back for a moment,
-- and the wheel opens around that spot (seen in the game: 22 units below the screen's edge). So both are
-- looked at every frame: the button goes up again at once, and a wheel found open around a button's old
-- spot is put around the button where it is now.
--
-- The wheels in front and on screen (a switch of its own, padWheels): the game may open a wheel in a fight, when
-- no frame of its may be touched, wherever its button is (half under the screen's edge, too), and a wheel put on
-- one of the bar's buttons may take that button's layer, under the d-pad and the face buttons. So each of the
-- three wheels is told, once, out of a fight, what the game's engine then keeps through any fight: its layer
-- (DIALOG, fixed: a new parent no longer changes it) and to stay on the screen. Nothing of it is moved or hooked
-- for that. Off, or with the HUD off, it is all put back.

local ADDON, ns = ...
local L = ns.L

local P = { active = false, moved = {}, hidden = {} }
ns.PadButtons = P

ns.RegisterSetting({
    key = "padRaise", kind = "boolean", default = true, command = "padraise", section = "Gamepad bars",
    label = "Stance and pet buttons above the bars",
    tip = "the stance and pet command buttons sit where the green and red targeting icons were, so their wheel opens fully on screen; those icons are hidden",
})
ns.RegisterSetting({
    key = "padWheels", kind = "boolean", default = true, command = "padwheels", section = "Gamepad bars",
    label = "Stance and pet wheels in front and on screen",
    tip = "the wheels that open with the shoulder and trigger buttons are drawn in front of the bar's buttons and kept inside the screen, in a fight too, so every choice can be seen; they stay the game's own",
})

local PAGE = "GamepadMainActionBarFramePageUnit"
P.SIDES = {
    { button = "LeftClassAction", icon = "LeftShoulderIcon", prompt = "LeftInputPrompt" },
    { button = "RightClassAction", icon = "RightShoulderIcon", prompt = "RightInputPrompt" },
}
P.RAISE = 112                 -- how far up a button goes when the icon it replaces cannot be found
P.FLYOUTS = { "GamepadSpellFlyout", "GamepadPetActionFlyout", "GamepadPetSpellFlyout" }
P.NEAR = 90                   -- a wheel this close to a button's old spot is that button's (it opened a little off)
P.STRATA = "DIALOG"           -- the wheels over the bar's d-pad and face buttons, never under them
P.RANK = { WORLD = 1, BACKGROUND = 2, LOW = 3, MEDIUM = 4, HIGH = 5, DIALOG = 6, FULLSCREEN = 7,
           FULLSCREEN_DIALOG = 8, TOOLTIP = 9 }
P.BARS = "GamepadMainActionBarFrame"      -- everything of the gamepad bars hangs from this
P.TRIES = 5                   -- a layer the game refuses this many times running is no longer asked for

local function Field(frame, key)
    local v = type(frame) == "table" and rawget(frame, key) or nil
    return type(v) == "table" and v or nil
end

-- Where a frame's middle is, in screen units (nil when the game has not placed it)
local function Scale(f)
    local s = f.GetEffectiveScale and f:GetEffectiveScale() or 1
    return type(s) == "number" and s > 0 and s or 1
end

local function Middle(f)
    if not (f and f.GetCenter) then return nil end
    local ok, x, y = pcall(f.GetCenter, f)
    if not ok or type(x) ~= "number" or type(y) ~= "number" then return nil end
    local s = Scale(f)
    return x * s, y * s, s
end

local function Points(f)
    local list = {}
    for i = 1, (f.GetNumPoints and f:GetNumPoints() or 0) do list[i] = { f:GetPoint(i) } end
    return list
end

local function Restore(f, points)
    f:ClearAllPoints()
    for _, p in ipairs(points) do f:SetPoint(unpack(p)) end
end

-- Is the frame where we put it? (the game lays its bars out again now and then)
local function Ours(f, m)
    local point, rel, relPoint, x, y = f:GetPoint(1)
    return point == "CENTER" and rel == m.page and relPoint == "CENTER"
        and math.abs((x or 0) - m.x) < 0.5 and math.abs((y or 0) - m.y) < 0.5
end

function P:Place(page, side)
    local b = Field(page, side.button)
    if not (b and b.SetPoint and b.GetPoint) then return false end
    local m = self.moved[b]
    if m and Ours(b, m) then return true end                -- still where we put it
    local old = m
    -- the game's own place for it (now, if it laid the bars out again)
    local points = Points(b)
    local bx, by = Middle(b)
    local px, py, ps = Middle(page)
    if not (bx and px) or #points == 0 then return false end
    local s = Scale(b)
    -- where it goes: onto the targeting icon above it, or straight up when there is none
    local icon = Field(page, side.icon)
    local ix, iy = Middle(icon)
    local tx, ty, how
    if ix and iy > by + 10 * s then
        tx, ty, how = ix, iy, "icon"
    else
        tx, ty, how = bx, by + self.RAISE * s, "raised"
        icon = nil
    end
    -- its button hint ("LB + LT") comes along, as far from the button as it was
    local prompt = Field(page, side.prompt)
    local promptMove
    if prompt and prompt.GetPoint and prompt.SetPoint and (prompt:GetNumPoints() or 0) > 0 then
        local _, rel = prompt:GetPoint(1)
        local qx, qy = Middle(prompt)
        if rel ~= b and qx then
            local qs = Scale(prompt)
            promptMove = { frame = prompt, points = Points(prompt), x = (qx - bx) / qs, y = (qy - by) / qs }
        end
    end
    m = { page = page, points = points, x = (tx - px) / s, y = (ty - py) / s, how = how, side = side.button,
          ox = bx, oy = by }                                 -- (where the game keeps it: its wheel opens there)
    b:ClearAllPoints()
    b:SetPoint("CENTER", page, "CENTER", m.x, m.y)
    if promptMove then
        promptMove.frame:ClearAllPoints()
        promptMove.frame:SetPoint("CENTER", b, "CENTER", promptMove.x, promptMove.y)
        m.prompt = promptMove
    elseif old then
        m.prompt = old.prompt                                -- still pinned to the button from last time
    end
    self.moved[b] = m
    ns.Note("pad: %s %s to %.0f,%.0f (from %.0f,%.0f on the screen)", side.button, how, m.x, m.y, bx, by)
    if icon and icon.SetAlpha and self.hidden[icon] == nil then
        self.hidden[icon] = icon:GetAlpha() or 1
        ns.KeepAlpha(icon, 0)
    end
    return true
end

function P:PutBack()
    for b, m in pairs(self.moved) do
        if Ours(b, m) then Restore(b, m.points) end          -- (if the game moved it since, it is already home)
        if m.prompt then Restore(m.prompt.frame, m.prompt.points) end
    end
    self.moved = {}
    for icon, alpha in pairs(self.hidden) do
        ns.KeepAlpha(icon, nil)
        icon:SetAlpha(alpha)
    end
    self.hidden = {}
end

function P:Arrange()
    local page = _G[PAGE]
    if type(page) ~= "table" then return false end
    local any = false
    for _, side in ipairs(self.SIDES) do
        local ok, done = pcall(self.Place, self, page, side)
        if not ok then ns.Error(done) elseif done then any = true end
    end
    return any
end

---------------------------------------------------------------------------
-- The wheels in front and on screen
---------------------------------------------------------------------------
P.was = {}                    -- what we changed on a frame of the game's: { strata, fixed, level, clamped, set }
P.opened = {}                 -- each wheel as it last opened (for /cchud padinfo and the debug report)

-- A method of a frame's, asked quietly: nil when it has none, the call fails, or the answer is a secret
local function Ask(f, method)
    local fn = type(f) == "table" and f[method]
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn, f)
    if ok then return ns.Plain(v) end
end

-- Told quietly: true when the game took it
local function Tell(f, method, value)
    local fn = type(f) == "table" and f[method]
    if type(fn) ~= "function" then return false end
    local ok, err = pcall(fn, f, value)
    if not ok then ns.Note("pad: %s refused: %s", method, tostring(err)) end
    return ok
end

local function Usable(f)
    if type(f) ~= "table" or type(f.GetFrameStrata) ~= "function" or type(f.SetFrameStrata) ~= "function" then
        return false
    end
    return Ask(f, "IsForbidden") ~= true
end

local function Children(f, fn, depth)
    if type(f) ~= "table" or type(f.GetChildren) ~= "function" or depth > 5 then return end
    local ok, kids = pcall(function() return { f:GetChildren() } end)
    if not ok then return end
    for _, child in ipairs(kids) do
        if Usable(child) then
            fn(child)
            Children(child, fn, depth + 1)
        end
    end
end

-- How high the gamepad bars draw right now: the highest layer among their shown frames, the highest level in it,
-- and that layer's rank (nil, 0, 0 without bars)
function P.BarsTop()
    local rank, level, layer = 0, 0, nil
    Children(_G[P.BARS], function(f)
        if not ns.ShownPlain(f) then return end
        local s = Ask(f, "GetFrameStrata")
        local r = s and P.RANK[s] or 0
        local l = Ask(f, "GetFrameLevel")
        l = type(l) == "number" and l or 0
        if r > rank or (r == rank and l > level) then rank, level, layer = r, l, s end
    end, 1)
    return layer, level, rank
end

-- What a frame was like before we first touched it
local function Remember(f)
    local was = P.was[f]
    if not was then
        was = { strata = Ask(f, "GetFrameStrata"), fixed = Ask(f, "HasFixedFrameStrata"),
                clamped = Ask(f, "IsClampedToScreen") }
        P.was[f] = was
    end
    return was
end

-- Out of a fight only (the wheels are protected frames)
function P:Front()
    if InCombatLockdown() then return end
    local want = self.RANK[self.STRATA]
    for _, name in ipairs(self.FLYOUTS) do
        local f = _G[name]
        if Usable(f) then
            local strata = Ask(f, "GetFrameStrata")
            local low = (strata and self.RANK[strata] or 0) < want
            local known = self.was[f]
            if low or not (known and known.set) then
                local was = Remember(f)
                if low and (was.refused or 0) < self.TRIES then
                    if was.set then ns.Note("pad: the game put %s on %s again", name, tostring(strata)) end
                    Tell(f, "SetFrameStrata", self.STRATA)
                    -- (a layer the game will not take is not asked for on every frame: left alone after a few)
                    local now = Ask(f, "GetFrameStrata")
                    was.refused = (now and (self.RANK[now] or 0) >= want) and 0 or (was.refused or 0) + 1
                    if was.refused == self.TRIES then ns.Note("pad: the game keeps %s on %s: left alone", name, tostring(now)) end
                end
                if not was.set then
                    was.set = true
                    Tell(f, "SetFixedFrameStrata", true)     -- (a new parent no longer changes its layer)
                    Tell(f, "SetClampedToScreen", true)      -- (the engine keeps it on screen, in a fight too)
                end
            end
        end
    end
end

-- A wheel just opened, out of a fight: looked at as it stands. A part of it that sits lower than the wheels'
-- layer is brought up to it; where the bars themselves draw as high as the wheel (the game raised them), the
-- wheel goes above them
function P:Stack(name, f)
    if InCombatLockdown() or not Usable(f) then return end
    local want = self.RANK[self.STRATA]
    Children(f, function(child)
        local s = Ask(child, "GetFrameStrata")
        if s and (self.RANK[s] or 0) < want then
            Remember(child)
            Tell(child, "SetFrameStrata", self.STRATA)
            ns.Note("pad: a part of %s was on %s: brought up", name, s)
        end
    end, 1)
    local layer, level, rank = self.BarsTop()
    local mine = self.RANK[Ask(f, "GetFrameStrata") or ""] or 0
    local at = Ask(f, "GetFrameLevel")
    if layer and rank >= mine and type(at) == "number" and (rank > mine or level >= at) then
        local was = Remember(f)
        if rank > mine then Tell(f, "SetFrameStrata", layer) end
        if level >= at then
            if was.level == nil then was.level = at end
            Tell(f, "SetFrameLevel", level + 10)
        end
        ns.Note("pad: the bars draw on %s level %d: %s put above them", layer, level, name)
    end
end

function P:PutBackWheels()
    for f, was in pairs(self.was) do
        if was.clamped ~= nil then Tell(f, "SetClampedToScreen", was.clamped)
        elseif was.set then Tell(f, "SetClampedToScreen", false) end
        if was.fixed ~= nil then Tell(f, "SetFixedFrameStrata", was.fixed)
        elseif was.set then Tell(f, "SetFixedFrameStrata", false) end
        if was.strata then Tell(f, "SetFrameStrata", was.strata) end
        if was.level then Tell(f, "SetFrameLevel", was.level) end
    end
    self.was = {}
end

-- One wheel as it stands: its layer, level, parent and place, and how high the bars draw (read only)
function P.WheelLine(name)
    local f = _G[name]
    if type(f) ~= "table" then return name .. ": this client has none" end
    local parent = Ask(f, "GetParent")
    local layer, level = P.BarsTop()
    local rect = "?"
    if type(f.GetRect) == "function" then
        local ok, l, b, w, h = pcall(f.GetRect, f)
        if ok and type(ns.Plain(l)) == "number" and type(ns.Plain(b)) == "number" then
            rect = ("%.0f,%.0f %.0fx%.0f"):format(l, b, ns.Plain(w) or 0, ns.Plain(h) or 0)
        end
    end
    local owner = "none"
    if type(parent) == "table" then owner = tostring(Ask(parent, "GetName") or "(unnamed)") end
    return ("%s: %s on %s level %s, fixed %s, kept on screen %s, parent %s, protected %s, at %s%s; the bars draw up to %s level %s")
        :format(name, ns.ShownPlain(f) and "shown" or "hidden", tostring(Ask(f, "GetFrameStrata")),
            tostring(Ask(f, "GetFrameLevel")), tostring(Ask(f, "HasFixedFrameStrata")),
            tostring(Ask(f, "IsClampedToScreen")), owner, tostring(Ask(f, "IsProtected")), rect,
            InCombatLockdown() and " (in a fight)" or "", tostring(layer), tostring(level))
end

-- Each wheel as it opens, in a fight too: looked at (kept for the reports), and out of a fight set in order
function P:Watch()
    self.seen = self.seen or {}
    for _, name in ipairs(self.FLYOUTS) do
        local shown = ns.ShownPlain(_G[name])
        if shown and not self.seen[name] then
            self.seen[name] = true
            if self.front then self:Stack(name, _G[name]) end
            if ns.db and ns.db.debug then
                self.opened[name] = self.WheelLine(name)
                ns.Note("pad: %s", self.opened[name])
            end
        elseif not shown then
            self.seen[name] = nil
        end
    end
end

-- How far the engine may have pushed a wheel up to keep it on the screen: half its height, and only for one
-- that now stands on the screen's bottom edge
local function Lift(f)
    if not (P.front and f.GetRect and f.GetHeight) then return 0 end
    local ok, _, bottom = pcall(f.GetRect, f)
    bottom = ok and ns.Plain(bottom) or nil
    if type(bottom) ~= "number" or bottom > 1 then return 0 end
    local okH, h = pcall(f.GetHeight, f)
    h = okH and ns.Plain(h) or nil
    return type(h) == "number" and h / 2 * Scale(f) or 0
end

-- A wheel that is open around a moved button's old spot: around the button itself instead
function P:Wheels()
    for _, name in ipairs(self.FLYOUTS) do
        local f = _G[name]
        if ns.ShownPlain(f) and f.SetPoint and f.ClearAllPoints then
            local fx, fy = Middle(f)
            local lift = fx and Lift(f) or 0
            local best, bestD
            for b, m in pairs(self.moved) do
                if fx and m.ox then
                    local dy = fy - m.oy
                    if dy > 0 then dy = math.max(0, dy - lift) end
                    local d = math.abs(fx - m.ox) + math.abs(dy)
                    if d < self.NEAR * Scale(b) and (not bestD or d < bestD) then best, bestD = b, d end
                end
            end
            local point, rel = nil, nil
            if best and f.GetPoint then point, rel = f:GetPoint(1) end
            if best and not (point == "CENTER" and rel == best) then      -- (not when it is around it already)
                f:ClearAllPoints()
                f:SetPoint("CENTER", best, "CENTER", 0, 0)
                self.wheels = (self.wheels or 0) + 1
                ns.Note("pad: %s put around %s", name, self.moved[best].side)
            end
        end
    end
end

-- The game lays the bars out again at times (a stance, compact mode, a new pet, a wheel opening): ours again,
-- at once, out of combat
local driver = CreateFrame("Frame")
driver:SetScript("OnUpdate", ns.Protect(function()
    if not P.active or InCombatLockdown() then return end
    P:Arrange()
    P:Wheels()
end))
-- (the wheels' layer has a handler of its own: if one of the two keeps failing, it steps aside alone, ns.BREAKER)
local layers = CreateFrame("Frame")
layers:SetScript("OnUpdate", ns.Protect(function()
    if not (P.front or (ns.db and ns.db.debug)) then return end
    if P.front then P:Front() end
    P:Watch()
end))

function P:Apply(run)
    if run and ns.db.padWheels and not ns.arranging then
        self.front = true
        self:Front()
    elseif self.front then
        self.front = false
        self:PutBackWheels()
    end
    local want = run and ns.db.padRaise and not ns.arranging and type(_G[PAGE]) == "table" and true or false
    if want then
        self.active = true
        self:Arrange()
    elseif self.active then
        self.active = false
        self:PutBack()
    end
end

ns.RegisterCheck(function(row, run, db)
    if not _G[PAGE] then return end
    local want = (run and db.padRaise and not ns.arranging) and true or false
    row(want and "the stance and pet buttons sit above the bars" or "the stance and pet buttons are where the game puts them",
        P.active == want)
end)

---------------------------------------------------------------------------
-- /cchud padinfo: what the gamepad bars are made of here and where it all sits, kept in the saved settings
-- (the game writes them on /reload), for when something sits wrong
---------------------------------------------------------------------------
local function Describe(f)
    local x, y = Middle(f)
    local w, h = 0, 0
    if f.GetSize then
        local ok, a, b = pcall(f.GetSize, f)
        if ok then w, h = a or 0, b or 0 end
    end
    local kind = f.GetObjectType and f:GetObjectType() or "?"
    return ("%s %s at %s,%s size %.0fx%.0f alpha %.2f%s"):format(kind,
        (f.IsShown and f:IsShown()) and "shown" or "hidden", x and ("%.0f"):format(x) or "?",
        y and ("%.0f"):format(y) or "?", w, h, f.GetAlpha and (f:GetAlpha() or 1) or 1,
        (f.IsProtected and f:IsProtected()) and " protected" or "")
end

function P.Report()
    local out = {}
    local page = _G[PAGE]
    if type(page) == "table" then
        local keys = {}
        for k, v in pairs(page) do
            if type(k) == "string" and type(v) == "table" and type(v.GetObjectType) == "function" then keys[#keys + 1] = k end
        end
        table.sort(keys)
        for _, k in ipairs(keys) do
            local ok, text = pcall(Describe, page[k])
            out[#out + 1] = k .. ": " .. (ok and text or "?")
        end
    else
        out[#out + 1] = "no gamepad bars"
    end
    for b, m in pairs(P.moved) do
        out[#out + 1] = ("moved %s (%s) to %.0f,%.0f%s"):format(m.side, m.how, m.x, m.y, m.prompt and ", with its hint" or "")
    end
    out[#out + 1] = ("wheels in front: %s"):format(tostring(P.front or false))
    for _, name in ipairs(P.FLYOUTS) do
        local ok, line = pcall(P.WheelLine, name)
        out[#out + 1] = ok and line or (name .. ": ?")
        if P.opened[name] then out[#out + 1] = "  as it last opened: " .. P.opened[name] end
    end
    return out
end

ns.RegisterCommand("padinfo", function()
    local out = P.Report()
    local R = ns.Rest
    if R then
        local n = 0
        for f in pairs(R.frames) do
            n = n + 1
            out[#out + 1] = "rests: " .. tostring(f.GetName and f:GetName() or "?")
        end
        out[#out + 1] = ("rest: %s, alpha %.2f, reason %s, trigger %s"):format(tostring(R.active), R.alpha,
            tostring(R.Reason()), tostring(R.TriggerHeld()))
    end
    local F = ns.Fishing
    if F then out[#out + 1] = "fishing: " .. F.Describe() end
    ns.db.padReport = out
    for _, line in ipairs(out) do print("  " .. line) end
    ns.Say(L["Saved: type /reload so the game writes it to disk."])
end, "/cchud padinfo", "list where the gamepad bars' parts sit and what rests (for troubleshooting)")

ns.RegisterModule("padbuttons", P)
