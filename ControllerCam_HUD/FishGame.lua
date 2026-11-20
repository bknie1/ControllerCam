-- ControllerCam HUD: something to do while the float is out (off unless you switch it on).
-- Beside the fishing interface is a small stretch of water. Your lure hangs in it, and the shadow of a fish
-- drifts up and down. Hold a trigger and the lure sinks; let go and it rises. Keep the lure beside the shadow
-- and the fish grows curious: a meter fills. Whatever you land next is the heavier for it (the weights are
-- made up for the journal anyway), and the meter starts again. It carries over from cast to cast, a fish that
-- gets away costs half of it, and every catch in a row without one getting away makes the shadow a little
-- quicker.
--
-- It cannot touch your fishing: it binds nothing and takes no button. The trigger is only looked at (the way
-- the screen at rest looks at it), your cast and your hook are the same one press as ever, and with the game
-- off or ignored every catch is exactly what it would have been.

local ADDON, ns = ...
local L = ns.L
local C = ns.colors

local G = { active = false, y = 0.2, s = 0.5, goal = 0.5, m = 0, streak = 0, turn = 0 }
ns.FishGame = G

G.W, G.H = 150, 60            -- the water
G.SINK, G.RISE = 0.9, 0.6     -- how fast the lure sinks while the trigger is held, and rises when it is not
G.NEAR = 0.16                 -- how close (of the water's depth) counts as beside the shadow
G.FILL, G.DRAIN = 0.11, 0.035 -- the meter per second, beside the shadow and away from it
G.SWIM, G.QUICKER, G.FASTEST = 0.45, 0.03, 0.9     -- the shadow's speed, more per catch in a row, at most
G.BONUS = 0.6                 -- a full meter makes the next catch this much heavier

ns.RegisterSetting({
    key = "fishGame", kind = "boolean", default = false, command = "fishgame", section = "Fishing",
    label = "A game while the float is out",
    tip = "a small stretch of water beside the fishing interface: hold a trigger to sink your lure and let go to let it rise, and keep it beside the shadow of the fish. The better you do, the heavier the made-up weight of your next catch. It takes no button and never touches your cast or your catch",
})

local frame

-- The trigger that sinks the lure: the left one, or the right one when the left one is your fishing button
function G.Key()
    local keys = ns.Fishing and ns.Fishing.Keys() or {}
    for _, key in ipairs(keys) do
        if key == "PADLTRIGGER" then return "PADRTRIGGER" end
    end
    return "PADLTRIGGER"
end

-- Is it held? Only looked at: nothing is bound and no press is taken.
function G.Held()
    local key = G.Key()
    if IsKeyDown then
        local ok, down = pcall(IsKeyDown, key)
        if ok and ns.Yes(down) then return true end
    end
    return ns.Rest and ns.Rest.PadDown and ns.Rest.PadDown(key) or false
end

local function Random() return (G.random or math.random)() end

---------------------------------------------------------------------------
-- What the fishing tells it
---------------------------------------------------------------------------
-- A catch is being weighed: how curious was the fish? (0-1; the meter starts again)
function G:Take()
    if not self.active then return 0 end
    local m = self.m
    self.m = 0
    if m > 0.05 then
        self.said, self.saidUntil = L["A curious one: +%d%%"]:format(math.floor(m * G.BONUS * 100 + 0.5)), GetTime() + 4
    end
    return m
end

function G:Landed()
    if not self.active then return end
    self.streak = self.streak + 1
    local log = ns.FishLog.Log()
    if self.streak > (tonumber(log.streak) or 0) then log.streak = self.streak end
end

function G:Away()
    if not self.active then return end
    self.m, self.streak = self.m / 2, 0
end

---------------------------------------------------------------------------
-- The water
---------------------------------------------------------------------------
local function Build()
    frame = CreateFrame("Frame", "ControllerCamHUD_FishGame", UIParent)
    frame:SetSize(G.W, G.H + 34)
    frame:SetFrameStrata("MEDIUM")
    frame:SetPoint("TOPRIGHT", UIParent, "CENTER", -140, ns.FishPanel and ns.FishPanel.Y or -168)
    frame.water = frame:CreateTexture(nil, "BACKGROUND")
    frame.water:SetSize(G.W, G.H)
    frame.water:SetPoint("TOP", frame, "TOP", 0, 0)
    frame.water:SetColorTexture(0.05, 0.16, 0.3, 0.6)
    frame.surface = frame:CreateTexture(nil, "BORDER")
    frame.surface:SetHeight(1.5)
    frame.surface:SetPoint("TOPLEFT", frame.water, "TOPLEFT", 0, 0)
    frame.surface:SetPoint("TOPRIGHT", frame.water, "TOPRIGHT", 0, 0)
    frame.surface:SetColorTexture(0.6, 0.84, 1, 0.9)
    frame.shadow = frame:CreateTexture(nil, "ARTWORK")          -- the fish: a dark shape under the water
    frame.shadow:SetTexture(ns.media.soft)
    frame.shadow:SetVertexColor(0, 0.02, 0.06, 1)
    frame.shadow:SetSize(44, 16)
    frame.thread = frame:CreateTexture(nil, "ARTWORK")          -- your line, down to the lure
    frame.thread:SetWidth(1)
    frame.thread:SetColorTexture(0.88, 0.94, 1, 0.7)
    frame.lure = frame:CreateTexture(nil, "OVERLAY")
    frame.lure:SetTexture(ns.media.bobber)
    frame.lure:SetSize(14, 14)
    frame.track = frame:CreateTexture(nil, "BACKGROUND")        -- the meter: how curious the fish is
    frame.track:SetSize(G.W, 4)
    frame.track:SetPoint("TOP", frame.water, "BOTTOM", 0, -3)
    frame.track:SetColorTexture(0.03, 0.05, 0.09, 0.75)
    frame.fill = frame:CreateTexture(nil, "ARTWORK")
    frame.fill:SetHeight(4)
    frame.fill:SetPoint("LEFT", frame.track, "LEFT", 0, 0)
    frame.fill:SetColorTexture(1, 0.82, 0.3, 0.95)
    frame.text = ns.FontString(frame, 9, "CENTER")
    frame.text:SetPoint("TOP", frame.track, "BOTTOM", 0, -4)
    frame.text:SetTextColor(unpack(C.muted))
    frame:Hide()
    G.frame = frame
end

local function KeyName(key)
    local text = GetBindingText and GetBindingText(key) or key
    return (type(text) == "string" and text ~= "") and text or key
end

function G:Draw(now)
    local x = G.W / 2
    local sway = math.sin(now * 0.9) * 22                  -- the shadow weaves from side to side as it goes
    frame.shadow:ClearAllPoints()
    frame.shadow:SetPoint("CENTER", frame.water, "TOPLEFT", x + sway, -(6 + self.s * (G.H - 12)))
    local near = math.abs(self.y - self.s) < G.NEAR
    frame.shadow:SetAlpha(near and 0.95 or 0.6)
    local depth = 6 + self.y * (G.H - 12)
    frame.lure:ClearAllPoints()
    frame.lure:SetPoint("CENTER", frame.water, "TOPLEFT", x, -depth)
    frame.thread:ClearAllPoints()
    frame.thread:SetPoint("TOP", frame.water, "TOPLEFT", x, 0)
    frame.thread:SetHeight(math.max(1, depth - 5))
    frame.fill:SetWidth(math.max(0.01, G.W * self.m))
    if self.saidUntil and now < self.saidUntil then
        frame.text:SetText(self.said)
        frame.text:SetTextColor(unpack(C.cast))
    else
        local text = L["Hold %s: the lure sinks"]:format(KeyName(G.Key()))
        if self.streak > 1 then text = L["%d in a row"]:format(self.streak) .. "   " .. text end
        frame.text:SetText(text)
        frame.text:SetTextColor(unpack(C.muted))
    end
end

-- The water moves on: only while your line is out
function G:Step(dt)
    local held = G.Held()
    self.held = held
    self.y = ns.Clamp(self.y + (held and G.SINK or -G.RISE) * dt, 0, 1)
    self.turn = self.turn - dt
    if self.turn <= 0 or math.abs(self.s - self.goal) < 0.02 then      -- the fish changes its mind
        self.goal = 0.1 + 0.8 * Random()
        self.turn = 1.2 + 1.4 * Random()
    end
    local speed = math.min(G.FASTEST, G.SWIM + G.QUICKER * self.streak)
    local d = self.goal - self.s
    self.s = self.s + ns.Clamp(d, -speed * dt, speed * dt)
    local near = math.abs(self.y - self.s) < G.NEAR
    self.m = ns.Clamp(self.m + (near and G.FILL or -G.DRAIN) * dt, 0, 1)
end

function G:Refresh() end

function G:Want()
    return self.active and not ns.arranging and not InCombatLockdown() and ns.Fishing.HasPole() and true or false
end

local driver = CreateFrame("Frame")
local since = 1
driver:SetScript("OnUpdate", ns.Protect(function(_, dt)
    if not G.active then return end
    since = since + dt
    local shown = frame and frame:IsShown()
    if since >= 0.25 or shown then
        if since >= 0.25 then
            since = 0
            local want = G:Want()
            if want and not frame then Build() end
            if frame and want ~= frame:IsShown() then
                if want then frame:Show() else frame:Hide() end
            end
            shown = frame and frame:IsShown()
        end
    end
    if not shown then return end
    local out = ns.FishLog.cast ~= nil                      -- your line is out: the water moves
    if out then G:Step(math.min(dt, 0.1)) end
    frame:SetAlpha(out and 1 or 0.5)
    G:Draw(GetTime())
end))

function G:Apply(run)
    self.active = run and ns.db.fishGame and ns.db.fishJournal and true or false
    if not self.active then
        self.m, self.streak = 0, 0
        if frame then frame:Hide() end
    end
    since = 1
end

function G.Describe()
    return ("on %s, shown %s, trigger %s (held %s), meter %.2f, in a row %d"):format(tostring(G.active),
        tostring(frame and frame:IsShown() or false), G.Key(), tostring(G.Held()), G.m, G.streak)
end

ns.RegisterModule("fishgame", G)
