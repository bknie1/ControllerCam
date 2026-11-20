-- ControllerCam HUD: the screen rests out of combat.
-- One fade for the whole HUD, all or nothing: the gamepad bars, the minimap, the quest list, the damage meter
-- and the experience bar rest together, faint, while nothing is going on, and come back together
--   * for a fight,
--   * while a trigger is held (and for a few seconds after: a pull of the trigger is how you look at them),
--   * while an enemy is targeted,
--   * while the controller's cursor is out, or the mouse is over one of them.
-- The game sets the alpha of some of these itself at times: ours is put back each time, from a timer of our
-- own (never from inside the game's code). Off, or with the HUD off, everything has the alpha it had.

local ADDON, ns = ...
local L = ns.L

local R = { active = false, alpha = 1, awake = 0, frames = {} }
ns.Rest = R

ns.RegisterSetting({
    key = "hudFade", kind = "boolean", default = true, command = "hudfade", section = "Gamepad bars",
    label = "Fade out of combat",
    tip = "the gamepad bars, minimap, quest list, damage meter and experience bar rest together out of combat, and come back for a fight, a pulled trigger or an enemy target",
})
ns.RegisterSetting({
    key = "hudIdle", kind = "number", default = 0.3, min = 0, max = 1, percent = true, command = "hudidle",
    section = "Gamepad bars", label = "The screen at rest", tip = "how visible the resting parts of the screen stay out of combat (0 hides them)",
    onChange = function() end,
})

-- The parts that rest (each can be left out, under Advanced)
R.PARTS = {
    { key = "restBars", label = "Rests: gamepad bars", names = { "GamepadMainActionBarFrame" } },
    { key = "restMinimap", label = "Rests: minimap", names = { "MinimapCluster" } },
    { key = "restTracker", label = "Rests: quest list", names = { "ObjectiveTrackerFrame", "QuestWatchFrame", "WatchFrame" } },
    { key = "restMeter", label = "Rests: damage meter", names = { "DamageMeter", "DamageMeterFrame" }, prefix = "^DamageMeter" },
    { key = "restXP", label = "Rests: experience bar", names = { "StatusTrackingBarManager", "MainStatusTrackingBarContainer" } },
    { key = "restBuffs", label = "Rests: buffs", names = { "BuffFrame" } },
    { key = "restRows", label = "Rests: cooldown rows", names = { "EssentialCooldownViewer", "UtilityCooldownViewer",
                                                                 "BuffIconCooldownViewer", "BuffBarCooldownViewer" } },
}
for _, part in ipairs(R.PARTS) do
    ns.RegisterSetting({ key = part.key, kind = "boolean", default = true, command = part.key:lower(),
                         section = "Gamepad bars", label = part.label,
                         tip = "whether this part of the screen takes part in the fade out of combat" })
end

local LINGER = 4              -- seconds the screen stays up after the last reason to
local FADE_IN, FADE_OUT = 6, 1.5

---------------------------------------------------------------------------
-- Finding the frames
---------------------------------------------------------------------------
local function IsFrame(v)
    return type(v) == "table" and type(v.SetAlpha) == "function" and type(v.GetAlpha) == "function"
end

-- A part the game names in ways we cannot know ahead (the damage meter): top-level frames by a name pattern.
-- Looked for a few times only: going through every global is not free.
local scans = {}
local function Scan(part)
    local s = scans[part.key]
    if not s then s = { tries = 0, at = 0, found = {} }; scans[part.key] = s end
    local now = GetTime()
    if #s.found > 0 or s.tries >= 5 or now < s.at then return s.found end
    s.tries, s.at = s.tries + 1, now + 10
    for name, v in pairs(_G) do
        if type(name) == "string" and name:find(part.prefix) then
            pcall(function()                              -- (a frame the game forbids us to look at is skipped)
                if IsFrame(v) and type(v.GetParent) == "function" and v:GetParent() == UIParent then
                    s.found[#s.found + 1] = v
                end
            end)
        end
    end
    return s.found
end

function R.Find(part)
    local list = {}
    for _, name in ipairs(part.names) do
        if IsFrame(_G[name]) then list[#list + 1] = _G[name] end
    end
    if #list == 0 and part.prefix then
        for _, f in ipairs(Scan(part)) do list[#list + 1] = f end
    end
    return list
end

-- Which frames rest right now (frame -> the alpha it had)
local function Collect()
    local want = {}
    for _, part in ipairs(R.PARTS) do
        if ns.db[part.key] then
            for _, f in ipairs(R.Find(part)) do want[f] = true end
        end
    end
    for f, base in pairs(R.frames) do
        if not want[f] then                              -- no longer one of ours: as it was
            R.frames[f] = nil
            f:SetAlpha(base)
        end
    end
    for f in pairs(want) do
        if R.frames[f] == nil then
            local a = f:GetAlpha() or 1
            R.frames[f] = (a > 0) and a or 1
        end
    end
end

---------------------------------------------------------------------------
-- Is there a reason to be up?
---------------------------------------------------------------------------
local function PadDown(binding)
    local G = C_GamePad
    if not (G and G.GetDeviceMappedState and G.ButtonBindingToIndex) then return false end
    local ok, state = pcall(G.GetDeviceMappedState)
    if not ok or type(state) ~= "table" or type(state.buttons) ~= "table" then return false end
    local ok2, i = pcall(G.ButtonBindingToIndex, binding)
    return ok2 and type(i) == "number" and state.buttons[i + 1] and true or false
end

R.PadDown = PadDown

function R.TriggerHeld()
    if GetBindingKey and IsKeyDown then
        for _, action in ipairs({ "GAMEPADLEFTMOD", "GAMEPADRIGHTMOD" }) do
            for _, key in ipairs({ GetBindingKey(action) }) do
                local ok, down = pcall(IsKeyDown, key)
                if ok and down then return true end
            end
        end
    end
    return PadDown("PADLTRIGGER") or PadDown("PADRTRIGGER")
end

local function CursorOut()
    local nav = _G.SmartNavigation
    if type(nav) ~= "table" or type(nav.IsCursorHidden) ~= "function" or not nav.IsShown then return false end
    local ok, hidden = pcall(nav.IsCursorHidden, nav)
    return ok and hidden == false and nav:IsShown() and true or false
end

local function MouseOver()
    for f in pairs(R.frames) do
        if f.IsMouseOver and f:IsVisible() then
            local ok, over = pcall(f.IsMouseOver, f)
            if ok and over == true then return true end
        end
    end
    return false
end

-- Why the screen is up right now (a word, for /cchud padinfo), or nil
function R.Reason()
    if ns.arranging or (ns.UnitFrames and ns.UnitFrames.unlocked) then return "arranging" end
    if ns.Yes(UnitAffectingCombat("player")) then return "combat" end
    if R.TriggerHeld() then return "trigger" end
    if UnitExists("target") and ns.Yes(UnitCanAttack("player", "target")) and not ns.Yes(UnitIsDead("target")) then
        return "enemy"
    end
    if CursorOut() then return "cursor" end
    if MouseOver() then return "mouse" end
    return nil
end

function R.Wanted(now)
    local reason = R.Reason()
    if reason ~= R.reason then
        R.reason = reason
        ns.Note("rest: %s", reason and ("up for " .. reason) or "nothing going on")
    end
    if reason then R.awake = now + LINGER end
    if now < R.awake then return 1 end
    return ns.db.hudIdle
end

---------------------------------------------------------------------------
-- Running
---------------------------------------------------------------------------
local driver = CreateFrame("Frame")
local sinceLook, sinceFind, want = 1, 0, 1

local function SetAll(a)
    for f, base in pairs(R.frames) do
        local v = base * a
        if math.abs((f:GetAlpha() or 1) - v) > 0.004 then f:SetAlpha(v) end
    end
end

-- The minimap draws its terrain apart from the rest of itself, and (indoors above all) can lose it when its
-- transparency changes. Asking for another zoom level and back makes it draw the terrain again; done each
-- time the fade comes to rest, at either end.
R.redraws = 0
function R.RedrawMinimap()
    local map = _G.Minimap
    if not (type(map) == "table" and map.GetZoom and map.SetZoom) or not R.frames[_G.MinimapCluster or false] then return end
    local ok, zoom = pcall(map.GetZoom, map)
    if not ok or type(zoom) ~= "number" then return end
    pcall(map.SetZoom, map, zoom > 0 and zoom - 1 or zoom + 1)
    pcall(map.SetZoom, map, zoom)
    R.redraws = R.redraws + 1
end

local moving = false
local Tick = ns.Protect(function(_, dt)
    sinceLook, sinceFind = sinceLook + dt, sinceFind + dt
    if sinceFind >= 2 then                               -- frames that were made since (the meter, the tracker)
        sinceFind = 0
        Collect()
    end
    if sinceLook >= 0.05 then
        sinceLook = 0
        want = R.Wanted(GetTime())
    end
    local a = R.alpha
    if a ~= want then
        if want > a then a = math.min(want, a + FADE_IN * dt) else a = math.max(want, a - FADE_OUT * dt) end
        R.alpha = a
        moving = true
    end
    SetAll(a)                                            -- also when the game set its own alpha: ours again
    if moving and a == want then
        moving = false
        R.RedrawMinimap()
    end
end)

function R:Apply(run)
    local want_ = run and ns.db.hudFade and true or false
    if want_ then
        Collect()
        if not self.active then
            self.active = true
            self.alpha, self.awake = 1, GetTime() + LINGER
            sinceLook, sinceFind, want = 1, 0, 1
            driver:SetScript("OnUpdate", Tick)
        end
    elseif self.active then
        self.active = false
        driver:SetScript("OnUpdate", nil)
        for f, base in pairs(self.frames) do f:SetAlpha(base) end
        R.RedrawMinimap()
        self.frames = {}
        self.alpha = 1
    end
end

ns.RegisterCheck(function(row, run, db)
    local on = (run and db.hudFade) and true or false
    row(on and "the screen rests out of combat" or "the screen does not fade", R.active == on)
    if on then
        local n = 0
        for _ in pairs(R.frames) do n = n + 1 end
        row("parts of the screen that rest were found", n > 0, n .. " frames")
    end
end)

ns.RegisterModule("rest", R)
