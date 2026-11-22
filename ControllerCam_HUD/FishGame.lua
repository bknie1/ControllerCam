-- ControllerCam HUD: something to do while the float is out (off unless you switch it on).
-- Played on the cast bar itself, while your line is out: the fish's shadow swims back and forth along the line,
-- and a pale band on the bar shows how far your lure reaches. Hold a trigger and the lure runs along the line;
-- let go and it drifts back. Keep the fish inside the band and the fish grows curious, the band turns gold and a
-- meter under the bar fills. Whatever you land next is the heavier for it (the weights are made up for the
-- journal anyway), and the meter starts again. It carries over from cast to cast, a fish that gets away costs
-- half of it, and every catch in a row without one getting away makes the fish a little quicker.
--
-- It cannot touch your fishing: it binds nothing and takes no button. The trigger is only looked at (the way
-- the screen at rest looks at it), your cast and your hook are the same presses as ever, and with the game
-- off or ignored every catch is exactly what it would have been.

local ADDON, ns = ...
local L = ns.L
local C = ns.colors

local G = { active = false, y = 0.2, s = 0.5, goal = 0.5, m = 0, streak = 0, turn = 0 }
ns.FishGame = G

G.W = 260                     -- the cast bar's length: the line the game is played on
G.BAND = 18                   -- how tall the band of your lure's reach is drawn on the bar
G.SINK, G.RISE = 0.9, 0.6     -- how fast the lure runs along while the trigger is held, and drifts back when not
G.NEAR = 0.16                 -- how close (of the line's length) counts as beside the fish
G.FILL, G.DRAIN = 0.11, 0.035 -- the meter per second, beside the fish and away from it
G.SWIM, G.QUICKER, G.FASTEST = 0.45, 0.03, 0.9     -- the fish's speed, more per catch in a row, at most
G.BONUS = 0.6                 -- a full meter makes the next catch this much heavier
G.UNDER = -24                 -- the meter and the words: this far under the line (under what bites, said there)
local PAD = 10                -- the lure and the fish keep this far from the ends of the line

ns.RegisterSetting({
    key = "fishGame", kind = "boolean", default = false, command = "fishgame", section = "Fishing",
    label = "A game while the float is out",
    tip = "played on the cast bar while your line is out: hold a trigger and your lure runs along the line, let go and it drifts back; keep it beside the shadow of the fish. The better you do, the heavier the made-up weight of your next catch. It takes no button and never touches your cast or your catch",
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
-- On the cast bar
---------------------------------------------------------------------------
-- Where it is played: on our cast bar (drawn at its size: larger while you fish front and centre), or where the
-- game's own cast bar sits when ours is off
function G.Spot()
    local CB = ns.CastBar
    if CB and CB.active and CB.bar then return "castbar", CB.bar, CB.frame end
    local native = _G.PlayerCastingBarFrame
    if type(native) == "table" and native.GetObjectType then return "native", native, nil end
    return "screen", UIParent, nil
end

function G.Place()
    if not frame then return end
    local where, anchor, scaled = G.Spot()
    frame:ClearAllPoints()
    frame:SetScale(scaled and scaled:GetScale() or 1)
    if where == "screen" then
        frame:SetPoint("TOP", UIParent, "BOTTOM", 0, 300)
    else
        frame:SetPoint("TOP", anchor, "CENTER", 0, 0)            -- its top edge along the line itself
    end
    G.where, G.scale = where, scaled and scaled:GetScale() or 1
end

local function Build()
    frame = CreateFrame("Frame", "ControllerCamHUD_FishGame", UIParent)
    frame:SetSize(G.W, 60)
    frame:SetFrameStrata("MEDIUM")
    frame:SetFrameLevel(40)                                       -- over the cast bar
    G.Place()
    frame.shade = frame:CreateTexture(nil, "BACKGROUND", nil, -2) -- a soft shade under the words, no box
    frame.shade:SetTexture(ns.media.soft)
    frame.shade:SetVertexColor(0, 0, 0, 0.5)
    frame.shade:SetPoint("TOPLEFT", frame, "TOPLEFT", -50, G.UNDER + 6)
    frame.shade:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 50, -6)
    frame.band = frame:CreateTexture(nil, "ARTWORK")              -- how far your lure reaches, on the line
    frame.band:SetTexture(ns.media.soft)
    frame.band:SetBlendMode("ADD")
    frame.band:SetSize(2 * G.NEAR * (G.W - 2 * PAD), G.BAND)
    frame.fish = frame:CreateTexture(nil, "ARTWORK", nil, 1)      -- the fish's shadow, swimming along the line
    frame.fish:SetTexture(ns.media.fish)
    frame.fish:SetSize(22, 22)
    frame.fish:SetVertexColor(0.08, 0.16, 0.24, 0.85)
    frame.lure = frame:CreateTexture(nil, "OVERLAY")              -- your lure, in the middle of its band
    frame.lure:SetTexture(ns.media.spark)
    frame.lure:SetBlendMode("ADD")
    frame.lure:SetSize(12, 12)
    frame.track = frame:CreateTexture(nil, "BACKGROUND")         -- the meter: how curious the fish is
    frame.track:SetSize(G.W, 3)
    frame.track:SetPoint("TOP", frame, "TOP", 0, G.UNDER)
    frame.track:SetColorTexture(0.03, 0.05, 0.09, 0.85)
    frame.fill = frame:CreateTexture(nil, "ARTWORK")
    frame.fill:SetHeight(3)
    frame.fill:SetPoint("LEFT", frame.track, "LEFT", 0, 0)
    frame.fill:SetColorTexture(1, 0.82, 0.3, 1)
    frame.title = ns.FontString(frame, 9, "LEFT")                -- what there is to do
    frame.title:SetPoint("TOPLEFT", frame.track, "BOTTOMLEFT", 0, -3)
    frame.title:SetText(L["Keep your lure beside the fish"])
    frame.title:SetTextColor(unpack(C.muted))
    frame.bonus = ns.FontString(frame, 9, "RIGHT")               -- what it is worth
    frame.bonus:SetPoint("TOPRIGHT", frame.track, "BOTTOMRIGHT", 0, -3)
    frame.bonus:SetTextColor(unpack(C.cast))
    frame.text = ns.FontString(frame, 9, "CENTER")               -- how it is played
    frame.text:SetPoint("TOP", frame.track, "BOTTOM", 0, -16)
    frame.text:SetTextColor(unpack(C.muted))
    frame:Hide()
    G.frame = frame
end

local function KeyName(key)
    local text = GetBindingText and GetBindingText(key) or key
    return (type(text) == "string" and text ~= "") and text or key
end

-- Along the line: 0 its start, 1 its end
local function Along(v) return PAD + v * (G.W - 2 * PAD) end

function G:Draw(now)
    local fx = Along(self.s)
    local heading = self.goal >= self.s                    -- (which way the fish is swimming just now)
    frame.fish:ClearAllPoints()
    frame.fish:SetPoint("CENTER", frame, "TOPLEFT", fx, math.sin(now * 3) * 1.5)
    if heading then frame.fish:SetTexCoord(0, 1, 0, 1) else frame.fish:SetTexCoord(1, 0, 0, 1) end
    local near = math.abs(self.y - self.s) < G.NEAR
    self.near = near
    local x = Along(self.y)
    frame.band:ClearAllPoints()
    frame.band:SetPoint("CENTER", frame, "TOPLEFT", x, 0)
    if near then frame.band:SetVertexColor(1, 0.84, 0.35, 0.55) else frame.band:SetVertexColor(1, 1, 1, 0.22) end
    frame.lure:ClearAllPoints()
    frame.lure:SetPoint("CENTER", frame, "TOPLEFT", x, 0)
    frame.fill:SetWidth(math.max(0.01, G.W * self.m))
    frame.bonus:SetText(L["Next catch +%d%%"]:format(math.floor(self.m * G.BONUS * 100 + 0.5)))
    if self.saidUntil and now < self.saidUntil then
        frame.text:SetText(self.said)
        frame.text:SetTextColor(unpack(C.cast))
    else
        local text = L["Hold %s: the lure runs along the line"]:format(KeyName(G.Key()))
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

-- Only while you are fishing: your line is out, or it just came in and there is something to say about it
function G:Want()
    if not (self.active and not ns.arranging and not InCombatLockdown() and ns.Fishing.HasPole()) then return false end
    if ns.FishLog.cast ~= nil then return true end
    return self.saidUntil ~= nil and GetTime() < self.saidUntil
end

local driver = CreateFrame("Frame")
local since = 1
driver:SetScript("OnUpdate", ns.Protect(function(_, dt)
    if not G.active then return end
    since = since + dt
    if since >= 0.25 then
        since = 0
        local want = G:Want()
        if want and not frame then Build() end
        if frame and want ~= frame:IsShown() then
            if want then
                G.Place()
                if ns.db.textShade ~= false then frame.shade:Show() else frame.shade:Hide() end
                frame:Show()
            else
                frame:Hide()
            end
        end
        if frame and want then
            local where, _, scaled = G.Spot()
            if where ~= G.where or (scaled and scaled:GetScale() or 1) ~= G.scale then G.Place() end
        end
    end
    if not (frame and frame:IsShown()) then return end
    if ns.FishLog.cast ~= nil then G:Step(math.min(dt, 0.1)) end     -- your line is out: the water moves
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
    return ("on %s, shown %s (%s), trigger %s (held %s), meter %.2f, in a row %d"):format(tostring(G.active),
        tostring(frame and frame:IsShown() or false), tostring(G.where), G.Key(), tostring(G.Held()), G.m, G.streak)
end

ns.RegisterModule("fishgame", G)
