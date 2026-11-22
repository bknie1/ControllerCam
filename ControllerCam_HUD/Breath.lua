-- ControllerCam HUD: your breath underwater.
-- In place of the game's breath bar, one of ours where you look at yourself: upright beside the vertical bars
-- (the "player data"), or a thin bar under the player frame, or at the top middle of the screen when neither is
-- shown. Light blue, with bubbles rising off it, more and quicker as your breath runs out; red when little is
-- left. The game's own breath bar is only kept out of sight while ours shows (its other timers, fatigue and the
-- like, are the game's as ever). With Reduce animations the bubbles stay away.

local ADDON, ns = ...
local L = ns.L
local C = ns.colors

local B = { active = false, max = nil, bubbles = {} }
ns.Breath = B

ns.RegisterSetting({
    key = "breathBar", kind = "boolean", default = true, command = "breath", section = "Frames",
    label = "Breath with bubbles",
    tip = "underwater, your breath as a bar of ours with bubbles rising off it: beside the vertical bars, under the player frame, or at the top of the screen",
})

B.TIMER = "BREATH"
B.COLOR = { 0.45, 0.78, 1.00 }
B.LOW = 0.2                     -- under this share of breath the bar turns red
B.UP_W, B.UP_GAP = 4, 9         -- upright beside the vertical bars: its width, how far from them
B.FLAT_H = 4                    -- under the player frame
B.TOP_W, B.TOP_H, B.TOP_Y = 220, 8, -140
B.BUBBLES = 8
B.RISE = 34                     -- how far a bubble rises (pixels)

local frame
local function Build()
    frame = CreateFrame("Frame", "ControllerCamHUD_Breath", UIParent)
    frame:SetFrameStrata("MEDIUM")
    frame:SetSize(B.TOP_W, B.TOP_H)
    frame:Hide()
    frame.bubbleLayer = CreateFrame("Frame", nil, frame)
    frame.bubbleLayer:SetAllPoints(frame)
    frame.bubbleLayer:SetFrameLevel(frame:GetFrameLevel() + 4)
    for i = 1, B.BUBBLES do
        local t = frame.bubbleLayer:CreateTexture(nil, "OVERLAY")
        t:SetTexture(ns.media.ring or ns.media.disc)
        t:SetVertexColor(0.75, 0.9, 1, 1)
        t:Hide()
        B.bubbles[i] = { tex = t, born = nil }
    end
    B.frame = frame
end

-- Where it goes: beside the vertical bars, under the player frame, or the top of the screen
function B.Place()
    if not frame then return end
    local UF = ns.UnitFrames
    local v = UF and UF.frames and UF.frames.vertical
    local p = UF and UF.frames and UF.frames.player
    if frame.bar then frame.bar:Hide(); frame.bar = nil end
    frame:ClearAllPoints()
    local bar
    if v and v.on and v.power then
        local beside = (v.upCast and v.upCast:IsShown()) and v.upCast or v.power
        local h = (v.health and v.health:GetHeight()) or 120
        if type(h) ~= "number" or h <= 0 then h = 120 end
        frame:SetSize(B.UP_W, h)
        frame:SetPoint("BOTTOMLEFT", beside, "BOTTOMRIGHT", B.UP_GAP, 0)
        bar = B.upBar or ns.CreateBar(frame, B.UP_W, h, { vertical = true })
        B.upBar = bar
        B.where = "vertical"
    elseif p and p.on and p.power then
        local w = (p.power:GetWidth()) or 200
        if type(w) ~= "number" or w <= 0 then w = 200 end
        frame:SetSize(w, B.FLAT_H)
        frame:SetPoint("TOPLEFT", p.power, "BOTTOMLEFT", 0, -5)
        bar = B.flatBar or ns.CreateBar(frame, w, B.FLAT_H)
        B.flatBar = bar
        B.where = "player"
    else
        frame:SetSize(B.TOP_W, B.TOP_H)
        frame:SetPoint("TOP", UIParent, "TOP", 0, B.TOP_Y)
        bar = B.topBar or ns.CreateBar(frame, B.TOP_W, B.TOP_H)
        B.topBar = bar
        B.where = "top"
    end
    for _, b in ipairs({ B.upBar, B.flatBar, B.topBar }) do if b and b ~= bar then b:Hide() end end
    bar:ClearAllPoints()
    bar:SetAllPoints(frame)
    bar:Show()
    frame.bar = bar
end

-- The game's own breath bar, kept out of sight while ours shows (only the one that times your breath)
function B.Natives()
    local list = {}
    local function Look(f)
        if type(f) == "table" and f.SetAlpha and rawget(f, "timer") == B.TIMER then list[#list + 1] = f end
    end
    for i = 1, (MIRRORTIMER_NUMTIMERS or 3) do Look(_G["MirrorTimer" .. i]) end
    local box = _G.MirrorTimerContainer
    if type(box) == "table" and box.GetChildren then
        local ok, kids = pcall(function() return { box:GetChildren() } end)
        for _, k in ipairs(ok and kids or {}) do Look(k) end
    end
    return list
end
local hidden = {}
local function HideNatives(hide)
    if hide then
        for _, f in ipairs(B.Natives()) do
            if not hidden[f] then hidden[f] = true; ns.KeepAlphaFast(f, 0) end
        end
    else
        for f in pairs(hidden) do ns.KeepAlphaFast(f, nil); pcall(f.SetAlpha, f, 1) end
        hidden = {}
    end
end

-- How much breath is left (0..1), or nil when it is not ticking
function B.Left()
    if not (GetMirrorTimerProgress and B.max and B.max > 0) then return nil end
    local ok, ms = pcall(GetMirrorTimerProgress, B.TIMER)
    if not ok or type(ms) ~= "number" or ns.IsSecret(ms) then return nil end
    return math.max(0, math.min(1, ms / B.max))
end

local function Bubbles(now, left, dt)
    if ns.Calm() then
        for _, b in ipairs(B.bubbles) do b.tex:Hide(); b.born = nil end
        return
    end
    -- more and quicker as breath runs out: one every 0.6 s when full, every 0.12 s when nearly gone
    local every = 0.12 + 0.48 * left
    B.due = (B.due or 0) + dt
    if B.due >= every then
        B.due = 0
        for _, b in ipairs(B.bubbles) do
            if not b.born then
                b.born, b.x, b.size = now, math.random(), 3 + math.random() * 4
                b.life = 0.9 + math.random() * 0.6
                break
            end
        end
    end
    local bar, vertical = frame.bar, B.where == "vertical"
    for _, b in ipairs(B.bubbles) do
        if b.born then
            local t = (now - b.born) / b.life
            if t >= 1 then
                b.born = nil
                b.tex:Hide()
            else
                local tex = b.tex
                tex:SetSize(b.size, b.size)
                tex:ClearAllPoints()
                local wobble = math.sin((now - b.born) * 9 + b.x * 6) * 2
                if vertical then                                   -- from the top of what is left, upwards
                    local h = frame:GetHeight() or 100
                    tex:SetPoint("CENTER", frame, "BOTTOM", wobble + (b.x - 0.5) * 6, h * left + t * B.RISE)
                else                                               -- from along the bar, upwards
                    local w = frame:GetWidth() or 200
                    tex:SetPoint("CENTER", frame, "LEFT", w * left * b.x + wobble, 4 + t * B.RISE)
                end
                tex:SetAlpha(0.85 * (1 - t))
                tex:Show()
            end
        end
    end
end

local since = 0
local function Tick(_, dt)
    if not B.running then return end
    local left = B.Left()
    if not left then return end
    since = since + dt
    if since >= 0.05 then
        since = 0
        frame.bar:SetValues(left, 1, true)
        local c = left < B.LOW and C.danger or B.COLOR
        frame.bar:SetColor(c[1], c[2], c[3])
        HideNatives(true)
    end
    Bubbles(GetTime(), left, dt)
end
Tick = ns.Protect(Tick)

function B.Start(max)
    if not (B.active and ns.db.breathBar) then return end
    B.max = tonumber(max) or B.max
    if not frame then Build() end
    B.Place()
    B.running = true
    B.starts = (B.starts or 0) + 1
    since = 1
    frame:Show()
    frame:SetScript("OnUpdate", Tick)
    HideNatives(true)
end

function B.Stop()
    B.running = false
    if frame then
        frame:SetScript("OnUpdate", nil)
        frame:Hide()
        for _, b in ipairs(B.bubbles) do b.born = nil; b.tex:Hide() end
    end
    HideNatives(false)
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", ns.Protect(function(_, event, timer, value, max)
    if timer ~= B.TIMER and event ~= "PLAYER_ENTERING_WORLD" then return end
    if event == "MIRROR_TIMER_START" then
        B.Start(max)
    elseif event == "MIRROR_TIMER_STOP" then
        B.Stop()
    elseif event == "PLAYER_ENTERING_WORLD" then                 -- (a reload underwater: still ticking?)
        if GetMirrorTimerInfo then
            for i = 1, (MIRRORTIMER_NUMTIMERS or 3) do
                local ok, name, _, maxv = pcall(GetMirrorTimerInfo, i)
                if ok and name == B.TIMER and type(maxv) == "number" and not ns.IsSecret(maxv) and maxv > 0 then
                    B.Start(maxv)
                end
            end
        end
    end
end))

function B:Apply(run)
    local want = run and ns.db.breathBar and true or false
    if want == self.active then
        if want and self.running then B.Place() end
        return
    end
    self.active = want
    if want then
        for _, e in ipairs({ "MIRROR_TIMER_START", "MIRROR_TIMER_STOP", "PLAYER_ENTERING_WORLD" }) do
            pcall(events.RegisterEvent, events, e)
        end
    else
        events:UnregisterAllEvents()
        B.Stop()
    end
end

function B.Describe()
    return ("on %s, showing %s at %s, breath left %s, shown %d times, the game's own bar kept out of sight: %d"):format(
        tostring(B.active), tostring(B.running or false), tostring(B.where or "-"), tostring(B.Left()),
        B.starts or 0, #B.Natives())
end

ns.RegisterModule("breath", B)
