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

local ADDON, ns = ...
local L = ns.L

local P = { active = false, moved = {}, hidden = {} }
ns.PadButtons = P

ns.RegisterSetting({
    key = "padRaise", kind = "boolean", default = true, command = "padraise", section = "Gamepad bars",
    label = "Stance and pet buttons above the bars",
    tip = "the stance and pet command buttons sit where the green and red targeting icons were, so their wheel opens fully on screen; those icons are hidden",
})

local PAGE = "GamepadMainActionBarFramePageUnit"
P.SIDES = {
    { button = "LeftClassAction", icon = "LeftShoulderIcon", prompt = "LeftInputPrompt" },
    { button = "RightClassAction", icon = "RightShoulderIcon", prompt = "RightInputPrompt" },
}
P.RAISE = 112                 -- how far up a button goes when the icon it replaces cannot be found
P.FLYOUTS = { "GamepadSpellFlyout", "GamepadPetActionFlyout", "GamepadPetSpellFlyout" }
P.NEAR = 40                   -- a wheel this close to a button's old spot is that button's

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

-- A wheel that is open around a moved button's old spot: around the button itself instead
function P:Wheels()
    for _, name in ipairs(self.FLYOUTS) do
        local f = _G[name]
        if ns.ShownPlain(f) and f.SetPoint and f.ClearAllPoints then
            local fx, fy = Middle(f)
            local best, bestD
            for b, m in pairs(self.moved) do
                if fx and m.ox then
                    local d = math.abs(fx - m.ox) + math.abs(fy - m.oy)
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

function P:Apply(run)
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
