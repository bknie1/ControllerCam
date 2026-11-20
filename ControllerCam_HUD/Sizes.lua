-- ControllerCam HUD: the game's own things in a place that suits a controller.
-- (The minimap and the quest list are left at the size the game gives them: making them bigger from here
-- threw their layout out, seen in the game. Their size is the game's to set, in Edit Mode.)
--   * The cooldown rows (the game's Cooldown Manager) clear of the gamepad bars: the game puts them at the
--     bottom middle, right where the gamepad buttons are. While you are on one of the game's built-in layouts
--     they sit under the target instead (where the CCHUD layout has them), a little smaller. On a layout of
--     your own they are where you put them: Edit Mode decides, not us.
-- All of it only while the HUD runs, out of combat, and given back in Edit Mode so you can arrange things.

local ADDON, ns = ...

local Z = { active = false, scaled = {}, placed = {} }
ns.Sizes = Z

ns.RegisterSetting({
    key = "rowsAside", kind = "boolean", default = true, command = "cooldownrows", section = "Gamepad bars",
    label = "Cooldown rows clear of the gamepad bars",
    tip = "the game's cooldown rows sit under the target instead of on top of the gamepad buttons, a little smaller (only on the game's built-in layouts: on a layout of your own they stay where you put them)",
})

-- The cooldown rows: where each goes (from the bottom middle of the screen) and how big
Z.ROWS = {
    { name = "EssentialCooldownViewer", x = 0, y = 634, scale = 0.8 },
    { name = "UtilityCooldownViewer", x = 0, y = 596, scale = 0.8 },
}

local function Usable(f)
    if type(f) ~= "table" or type(f.GetScale) ~= "function" or type(f.SetScale) ~= "function" then return false end
    return not (InCombatLockdown() and f.IsProtected and f:IsProtected() == true)
end

-- A frame at a share of its own scale. What it had is remembered (and noticed again when the game sets it anew).
local function Resize(f, k)
    local ok, s = pcall(f.GetScale, f)
    if not ok or type(s) ~= "number" or s <= 0 then return end
    local rec = Z.scaled[f]
    local own = (rec and math.abs(s - rec.set) < 0.005) and rec.own or s
    local want = own * k
    if math.abs(want - s) >= 0.005 then pcall(f.SetScale, f, want) end
    Z.scaled[f] = (math.abs(want - own) >= 0.005) and { own = own, set = want } or nil
end

local function Points(f)
    local list = {}
    for i = 1, (f.GetNumPoints and f:GetNumPoints() or 0) do list[i] = { f:GetPoint(i) } end
    return list
end

-- (a frame of the game's Edit Mode keeps its plain methods under these names; its usual ones are the game's own)
local function Plain(f, name)
    local base = rawget(f, name .. "Base")
    return type(base) == "function" and base or f[name]
end

local function Anchor(f, ...)
    Plain(f, "ClearAllPoints")(f)
    Plain(f, "SetPoint")(f, ...)
end

-- Is the game on one of its built-in layouts? (nil when it does not say)
function Z.BuiltinLayout()
    local layout = ns.Share and ns.Share.Layout()
    if not layout then return nil end
    return layout.builtin ~= nil
end

function Z:Set(on)
    local rows = on and ns.db.rowsAside and Z.BuiltinLayout() == true
    for _, row in ipairs(self.ROWS) do
        local f = _G[row.name]
        if Usable(f) and f.GetPoint and f.SetPoint then
            local rec = self.placed[f]
            if rows then
                local point, rel, _, x, y = f:GetPoint(1)
                local ours = point == "BOTTOM" and rel == UIParent and math.abs((x or 0) - row.x / row.scale) < 0.5
                    and math.abs((y or 0) - row.y / row.scale) < 0.5
                if not ours then
                    if not rec then rec = { points = Points(f) }; self.placed[f] = rec end
                    Resize(f, row.scale)
                    Anchor(f, "BOTTOM", UIParent, "BOTTOM", row.x / row.scale, row.y / row.scale)
                    ns.Note("sizes: %s under the target", row.name)
                end
            elseif rec then
                self.placed[f] = nil
                Resize(f, 1)
                Plain(f, "ClearAllPoints")(f)
                for _, p in ipairs(rec.points) do Plain(f, "SetPoint")(f, unpack(p)) end
            end
        end
    end
end

-- The game sets these again at times (a layout applied, a window opened): ours again, about once a second
local driver = CreateFrame("Frame")
local since = 0
driver:SetScript("OnUpdate", ns.Protect(function(_, dt)
    if not Z.active then return end
    since = since + dt
    if since < 1 then return end
    since = 0
    Z:Set(not ns.arranging)
end))

function Z:Apply(run)
    self.active = run and true or false
    self:Set(self.active and not ns.arranging)
end

function Z.Describe()
    local out = { ("on %s, built-in layout %s"):format(tostring(Z.active), tostring(Z.BuiltinLayout())) }
    for _, list in ipairs({ Z.ROWS }) do
        for _, item in ipairs(list) do
            local name = type(item) == "table" and item.name or item
            local f = _G[name]
            if type(f) == "table" and f.GetScale then
                local ok, s = pcall(f.GetScale, f)
                local point, rel, relPoint, x, y = nil, nil, nil, nil, nil
                if f.GetPoint then point, rel, relPoint, x, y = f:GetPoint(1) end
                out[#out + 1] = ("%s: scale %s%s, protected %s, at %s %s %s"):format(name, ok and tostring(s) or "?",
                    Z.scaled[f] and (" (its own " .. tostring(Z.scaled[f].own) .. ")") or "",
                    tostring(f.IsProtected and f:IsProtected() == true), tostring(point), tostring(x), tostring(y))
            else
                out[#out + 1] = name .. ": not in this client"
            end
        end
    end
    return out
end

ns.RegisterModule("sizes", Z)
