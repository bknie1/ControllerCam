-- ControllerCam HUD: a sip of water now and then.
-- A gentle reminder in the upper middle of the screen: a flask of water, "Time for a sip of water", how long you
-- have played. It drifts in, a drop falls and rings spread from it, it holds a few seconds and fades. With Reduce
-- animations it only fades in and out where it stands. A short line in chat says it too.
--   * Every so often while you play (an hour to begin with; "Water reminder every" sets it).
--   * As a flight begins, a natural break (not when the last reminder was recent).
-- Never in a fight: a reminder that comes due in one waits until it is over, and a fight that starts takes it
-- off the screen at once.

local ADDON, ns = ...
local L = ns.L

local H = { running = false, shown = 0 }
ns.Hydrate = H

ns.RegisterSetting({
    key = "hydrate", kind = "boolean", default = true, command = "hydrate", section = "General",
    label = "Reminder to drink water",
    tip = "now and then while you play, a gentle reminder to have a sip of water (never in a fight)",
})
ns.RegisterSetting({
    key = "hydrateEvery", kind = "number", default = 60, min = 15, max = 180, command = "hydrateevery",
    section = "General", label = "Water reminder every (minutes)",
    tip = "how many minutes of play between reminders to drink water",
    onChange = function() end,
})
ns.RegisterSetting({
    key = "hydrateFlight", kind = "boolean", default = true, command = "hydrateflight", section = "General",
    label = "Water reminder as a flight begins",
    tip = "a flight is a natural break: the reminder to drink water comes as one begins, unless the last was not long ago",
    onChange = function() end,
})

H.FLIGHT_GAP = 20 * 60        -- a flight brings the reminder when the last one was at least this long ago
H.IN, H.HOLD, H.OUT = 0.9, 6, 1.4
H.Y = 250
H.ICON = "Interface\\Icons\\INV_Drink_07"
local RINGS = 3

local function Fighting()
    return InCombatLockdown() or ns.Yes(UnitAffectingCombat and UnitAffectingCombat("player"))
end

---------------------------------------------------------------------------
-- The reminder on screen
---------------------------------------------------------------------------
local frame
local function Build()
    frame = CreateFrame("Frame", "ControllerCamHUD_Water", UIParent)
    frame:SetSize(360, 56)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, H.Y)
    frame:SetFrameStrata("HIGH")
    frame.band = frame:CreateTexture(nil, "BACKGROUND")
    frame.band:SetTexture(ns.media.soft)
    frame.band:SetVertexColor(0, 0, 0, 1)
    frame.band:SetPoint("TOPLEFT", frame, "TOPLEFT", -60, 16)
    frame.band:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 60, -16)
    frame.glow = frame:CreateTexture(nil, "BACKGROUND")
    frame.glow:SetTexture(ns.media.soft)
    frame.glow:SetBlendMode("ADD")
    frame.glow:SetVertexColor(0.45, 0.75, 1, 1)
    frame.glow:SetSize(130, 90)
    frame.glow:SetPoint("CENTER", frame, "LEFT", 26, 0)
    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetTexture(H.ICON)
    frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    frame.icon:SetSize(36, 36)
    frame.title = ns.FontString(frame, 16, "LEFT")
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 54, -10)
    frame.title:SetTextColor(0.72, 0.88, 1)
    frame.sub = ns.FontString(frame, 11, "LEFT")
    frame.sub:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -3)
    frame.sub:SetTextColor(0.82, 0.92, 1)
    frame.drop = frame:CreateTexture(nil, "OVERLAY")
    frame.drop:SetTexture(ns.media.soft)
    frame.drop:SetBlendMode("ADD")
    frame.drop:SetVertexColor(0.75, 0.92, 1, 1)
    frame.rings = {}
    for i = 1, RINGS do
        local r = frame:CreateTexture(nil, "ARTWORK")
        r:SetTexture(ns.media.ring)
        r:SetBlendMode("ADD")
        r:SetVertexColor(0.6, 0.85, 1, 1)
        r:SetAlpha(0)
        frame.rings[i] = r
    end
    frame:Hide()
    H.frame = frame
end

local function Clamp01(k) return math.max(0, math.min(1, k)) end
local function Ease(k) k = Clamp01(k); return 1 - (1 - k) * (1 - k) end

function H.Draw(now)
    local m = H.live
    if not (m and frame) then return end
    local t = now - m.at
    local total = H.IN + H.HOLD + H.OUT
    if t >= total then H.Hide(); return end
    local outK = Clamp01((t - H.IN - H.HOLD) / H.OUT)
    local alpha = math.min(Clamp01(t / H.IN), 1 - outK)
    local y = H.Y
    if not m.calm then y = y + 14 * (1 - Ease(t / H.IN)) end         -- it drifts down into place
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, y)
    frame:SetAlpha(alpha)
    frame.band:SetAlpha(ns.db.textShade ~= false and 0.4 or 0)
    local bob = m.calm and 0 or math.sin(t * 1.8) * 2                 -- the flask rocks a little
    frame.icon:ClearAllPoints()
    frame.icon:SetPoint("CENTER", frame, "LEFT", 26, bob)
    for _, r in ipairs(frame.rings) do r:SetAlpha(0) end
    frame.drop:SetAlpha(0)
    if m.calm then frame.glow:SetAlpha(0); return end
    frame.glow:SetAlpha((0.25 + 0.1 * math.sin(t * 2)) * (1 - outK))
    -- a drop falls from above the flask, then rings spread where it lands
    local fall = 0.7
    local u = (t - 0.4) / fall
    if u > 0 and u < 1 then
        frame.drop:ClearAllPoints()
        frame.drop:SetPoint("CENTER", frame, "LEFT", 26, 40 - 58 * u * u)
        frame.drop:SetSize(7, 9)
        frame.drop:SetAlpha(1 - u * 0.3)
    end
    for i, r in ipairs(frame.rings) do
        local start = 0.4 + fall + (i - 1) * 0.5
        local p = (t - start) / 1.6
        if p > 0 and p < 1 then
            local size = 24 + 90 * p
            r:ClearAllPoints()
            r:SetPoint("CENTER", frame, "LEFT", 26, -18)
            r:SetSize(size, size * 0.4)
            r:SetAlpha((1 - p) * 0.7 * (1 - outK))
        end
    end
end

local driver = CreateFrame("Frame")
local function Tick() H.Draw(GetTime()) end
Tick = ns.Protect(Tick)

function H.Hide()
    H.live = nil
    driver:SetScript("OnUpdate", nil)
    if frame then frame:Hide() end
end

-- How long you have played since you logged in, in words
local function Played()
    local m = math.floor((GetTime() - (H.since or GetTime())) / 60 + 0.5)
    if m >= 60 then return L["%d h"]:format(math.floor(m / 60 + 0.5)) end
    return L["%d min"]:format(math.max(1, m))
end

-- why: "time" (it was due) or "flight"
function H.Show(why)
    if not frame then Build() end
    local now = GetTime()
    H.last, H.waiting = now, false
    H.shown = H.shown + 1
    local sub = why == "flight" and L["A flight is a good moment for it."] or L["You have played for %s."]:format(Played())
    frame.title:SetText(L["Time for a sip of water"])
    frame.sub:SetText(sub)
    H.live = { at = now, calm = ns.Calm() and true or false, why = why }
    frame:Show()
    H.Draw(now)
    driver:SetScript("OnUpdate", Tick)
    if ns.Chat and ns.Chat.Line then ns.Chat.Line("water", L["Time for a sip of water"]) end
    ns.Note("water: reminder (%s)", tostring(why))
    return true
end

---------------------------------------------------------------------------
-- When
---------------------------------------------------------------------------
function H.Due(now)
    return now - (H.last or now) >= (ns.db.hydrateEvery or 60) * 60
end

-- A look now and then (every few seconds, nothing in between)
local clock = CreateFrame("Frame")
local since = 0
clock:SetScript("OnUpdate", ns.Protect(function(_, dt)
    if not (H.running and ns.db.hydrate) then return end
    since = since + dt
    if since < 5 then return end
    since = 0
    if H.live or not H.Due(GetTime()) then return end
    if Fighting() then H.waiting = true; return end            -- (after the fight)
    H.Show("time")
end))

function H.OnFlight()
    if not (H.running and ns.db.hydrate and ns.db.hydrateFlight) or H.live then return end
    if GetTime() - (H.last or -1e9) < H.FLIGHT_GAP then return end
    H.Show("flight")
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", ns.Protect(function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        if H.live then H.Hide(); H.waiting = true end           -- off the screen for the fight, and again after it
    elseif event == "PLAYER_REGEN_ENABLED" then
        if H.waiting then
            C_Timer.After(4, ns.Protect(function()
                if H.running and ns.db.hydrate and H.waiting and not H.live and not Fighting() then H.Show("time") end
            end))
        end
    end
end))

function H:Apply(run)
    local want = run and ns.db.hydrate and true or false
    if want and not self.running then
        self.since = self.since or GetTime()
        self.last = self.last or GetTime()                     -- (the first one an interval after you start)
        pcall(events.RegisterEvent, events, "PLAYER_REGEN_DISABLED")
        pcall(events.RegisterEvent, events, "PLAYER_REGEN_ENABLED")
    elseif not want and self.running then
        events:UnregisterAllEvents()
        self.waiting = false
        H.Hide()
    end
    self.running = want
end

function H.Describe()
    local now = GetTime()
    return ("water reminder on %s, every %s min, at flights %s, shown %d, next in %s, waiting for a fight to end %s"):format(
        tostring(H.running), tostring(ns.db and ns.db.hydrateEvery), tostring(ns.db and ns.db.hydrateFlight), H.shown,
        H.last and ("%d s"):format(math.max(0, (ns.db.hydrateEvery or 60) * 60 - (now - H.last))) or "-",
        tostring(H.waiting or false))
end

ns.RegisterCommand("watertest", function() H.Show("time") end, "/cchud watertest", "show the reminder to drink water")

ns.RegisterModule("hydrate", H)
