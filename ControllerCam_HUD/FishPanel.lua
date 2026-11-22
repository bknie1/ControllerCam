-- ControllerCam HUD: the fishing interface.
-- With a fishing pole in your hands, at the bottom of the screen, where the gamepad bars are while you are
-- not fishing (they are put away meanwhile; if you keep them, it sits where your target frame does and steps
-- aside for a target): the fish of the water you stand at (the ones you have not landed here are a "?"), your
-- Fishing skill as a small bar with what bait and pole add to it, how many you caught and how many got away
-- at this water, the bait on your pole and how long it lasts, your latest catch with its weight, and beside
-- it a tally of what you have landed here this session, kind by kind. The tally and the counts start again
-- when you move on to another zone.
-- It has no box: the text has its shadow and a soft shade lies under it. It is plain while your line is out
-- and a touch fainter between casts; it is gone in a fight and when the pole is put away. It only shows:
-- nothing in it takes a press.

local ADDON, ns = ...
local L = ns.L
local C = ns.colors

local P = { active = false, slots = {}, rows = {} }
ns.FishPanel = P

P.LINGER = 12                 -- seconds after your line came in that it stays plain
P.IDLE = 0.9                  -- how visible it is between casts
P.LATEST = 14                 -- seconds your latest catch is spelled out
P.ROWS = 5                    -- kinds listed in the tally
local SLOT, GAP = 30, 4
P.BOTTOM = 40                 -- how far above the bottom of the screen it sits
local BAR_W, BAR_H, WIDTH, ROW = 180, 4, 200, 20

ns.RegisterSetting({
    key = "fishPanel", kind = "boolean", default = true, command = "fishpanel", section = "Fishing",
    label = "Fishing interface",
    tip = "with a fishing pole in your hands: the fish of the water you stand at (the ones you have not landed here stay hidden), your Fishing skill and what your bait adds, how many you caught and how many got away, how long your bait lasts, and your latest catches",
})

local frame

local function Clock(seconds)
    seconds = math.max(0, math.floor(seconds + 0.5))
    return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end
P.Clock = Clock

-- Where it goes: the bottom of the screen while the gamepad bars are put away; with the bars kept, the target
-- frame's place (wherever you have put that), or the top of the screen without one
function P.Bottom() return ns.Fishing and ns.Fishing.barsHidden and true or false end
function P.Place(f)
    f:ClearAllPoints()
    if P.Bottom() then
        P.at = "bottom"
        f:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, P.BOTTOM)
        return
    end
    P.at = "top"
    local target = ns.UnitFrames and ns.UnitFrames.frames and ns.UnitFrames.frames.target
    if target and target.mover then
        f:SetPoint("TOP", target.mover, "TOP", 0, 0)
    else
        f:SetPoint("TOP", UIParent, "TOP", 0, -78)
    end
end

local function Build()
    frame = CreateFrame("Frame", "ControllerCamHUD_FishPanel", UIParent)
    frame:SetSize(WIDTH, 120)
    frame:SetFrameStrata("MEDIUM")
    P.Place(frame)
    frame.shade = frame:CreateTexture(nil, "BACKGROUND", nil, -2)   -- a soft shade, no box: nothing to spill out of
    frame.shade:SetTexture(ns.media.soft)
    frame.shade:SetVertexColor(0, 0, 0, 0.5)
    frame.shade:SetPoint("TOPLEFT", frame, "TOPLEFT", -70, 26)
    frame.shade:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 70, -22)
    frame.tallyShade = frame:CreateTexture(nil, "BACKGROUND", nil, -2)
    frame.tallyShade:SetTexture(ns.media.soft)
    frame.tallyShade:SetVertexColor(0, 0, 0, 0.45)
    frame.tallyShade:SetPoint("TOPLEFT", frame, "TOPRIGHT", -20, 22)
    frame.tallyShade:Hide()
    for i = 1, ns.FishLog.SLOTS do
        local s = { back = frame:CreateTexture(nil, "BACKGROUND"), icon = frame:CreateTexture(nil, "ARTWORK"),
                    q = ns.FontString(frame, 12, "CENTER") }
        s.back:SetSize(SLOT, SLOT)
        s.back:SetColorTexture(0.03, 0.05, 0.09, 0.6)
        s.icon:SetSize(SLOT - 2, SLOT - 2)
        s.icon:SetPoint("CENTER", s.back, "CENTER", 0, 0)
        s.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        s.q:SetPoint("CENTER", s.back, "CENTER", 0, 0)
        s.q:SetText("?")
        s.q:SetTextColor(unpack(C.muted))
        P.slots[i] = s
    end
    -- your skill: a small bar, its level and what is added to it
    frame.skill = ns.FontString(frame, 10, "CENTER")
    frame.skill:SetPoint("TOP", frame, "TOP", 0, -(SLOT + 8))
    frame.track = frame:CreateTexture(nil, "BACKGROUND")
    frame.track:SetSize(BAR_W, BAR_H)
    frame.track:SetPoint("TOP", frame.skill, "BOTTOM", 0, -3)
    frame.track:SetColorTexture(0.03, 0.05, 0.09, 0.75)
    frame.fill = frame:CreateTexture(nil, "ARTWORK")
    frame.fill:SetHeight(BAR_H)
    frame.fill:SetPoint("LEFT", frame.track, "LEFT", 0, 0)
    frame.fill:SetColorTexture(0.6, 0.84, 1, 0.95)
    frame.stats = ns.FontString(frame, 10, "CENTER")
    frame.stats:SetPoint("TOP", frame.track, "BOTTOM", 0, -6)
    frame.stats:SetTextColor(unpack(C.muted))
    frame.bait = ns.FontString(frame, 10, "CENTER")
    frame.bait:SetPoint("TOP", frame.stats, "BOTTOM", 0, -3)
    -- your latest catch, spelled out for a moment; beside it all, what you have landed here this session
    frame.latest = ns.FontString(frame, 10, "CENTER")
    frame.latest:SetPoint("TOP", frame.bait, "BOTTOM", 0, -6)
    frame.latest:SetTextColor(unpack(C.cast))
    for i = 1, P.ROWS do
        local r = { text = ns.FontString(frame, 10, "LEFT"), icon = frame:CreateTexture(nil, "ARTWORK"),
                    count = ns.FontString(frame, 10, "RIGHT") }
        r.icon:SetSize(16, 16)
        r.icon:SetPoint("TOPLEFT", frame, "TOPRIGHT", 44, -((i - 1) * ROW + 4))
        r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        r.text:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
        r.count:SetPoint("RIGHT", r.icon, "LEFT", -6, 0)
        r.count:SetTextColor(unpack(C.muted))
        P.rows[i] = r
    end
    frame:Hide()
    P.frame = frame
end

local function Icon(id, icon)
    if icon then return icon end
    if id and C_Item and C_Item.GetItemIconByID then
        local ok, found = pcall(C_Item.GetItemIconByID, id)
        if ok and (type(found) == "number" or type(found) == "string") then return found end
    end
    return nil
end

-- The parts that change with the clock: the bait, and the latest catch fading
function P:Tick(now)
    local F = ns.Fishing
    local left = F.BaitLeft()
    if left then
        frame.bait:SetText(L["Bait %s"]:format(Clock(left)))
        if left < 60 then frame.bait:SetTextColor(unpack(C.caution)) else frame.bait:SetTextColor(unpack(C.health)) end
    else
        frame.bait:SetText(L["No bait"])                  -- (how to put some on is said by the cast prompt)
        frame.bait:SetTextColor(unpack(C.muted))
    end
    local c = ns.FishLog.feed[1]
    local age = c and (now - c.at) or P.LATEST
    frame.latest:SetAlpha(c and ns.Clamp((P.LATEST - age) / 4, 0, 1) or 0)
end

function P:Refresh()
    if not (frame and frame:IsShown()) then return end
    local J, F = ns.FishLog, ns.Fishing
    J:Water()                                              -- (moved on to another water: the tally starts again)
    local waters = J.Waters()
    local n = #waters
    for i, s in ipairs(P.slots) do
        local w = waters[i]
        if w then
            s.back:ClearAllPoints()
            s.back:SetPoint("TOP", frame, "TOP", (i - (n + 1) / 2) * (SLOT + GAP), 0)
            s.back:Show()
            local icon = w.known and Icon(w.id, w.icon)
            if icon then
                s.icon:SetTexture(icon)
                s.icon:Show()
                s.q:Hide()
            else
                s.icon:Hide()
                s.q:Show()
            end
        else
            s.back:Hide(); s.icon:Hide(); s.q:Hide()
        end
        s.known = w and w.known or false
    end
    local rank, bonus, cap = F.Skill()
    if rank then
        local text = ("%s %d"):format(F.Spell() or "", rank)
        if bonus and bonus > 0 then text = text .. (" |cff7dd68f(+%d)|r"):format(bonus) end
        if cap and cap > 0 then text = text .. (" / %d"):format(cap) end
        frame.skill:SetText(text)
        frame.fill:SetWidth(math.max(0.01, BAR_W * ns.Clamp(rank / math.max(1, cap or rank), 0, 1)))
        frame.skill:Show(); frame.track:Show(); frame.fill:Show()
    else
        frame.skill:SetText("")
        frame.track:Hide(); frame.fill:Hide()
    end
    P.share = rank and ns.Clamp(rank / math.max(1, cap or rank), 0, 1) or nil
    frame.stats:SetText(L["Caught %d"]:format(J.session.caught) .. "     " .. L["Got away %d"]:format(J.session.away))
    local c = J.feed[1]
    if c then
        local text = c.name or ("item:" .. c.id)
        if c.weight then text = text .. "  " .. J.Pounds(c.weight) end
        if c.new then text = text .. "  |cffffd24a" .. L["new!"] .. "|r"
        elseif c.best then text = text .. "  |cffffd24a" .. L["best!"] .. "|r" end
        frame.latest:SetText(text)
    else
        frame.latest:SetText("")
    end
    local tally = J.Tally()
    local shown = 0
    for i, r in ipairs(P.rows) do
        local t = tally[i]
        if t then
            shown = i
            r.text:SetText(t.name or ("item:" .. t.id))
            r.count:SetText(("x%d"):format(t.n))
            local icon = Icon(t.id, t.icon)
            if icon then r.icon:SetTexture(icon); r.icon:Show() else r.icon:Hide() end
            r.text:Show(); r.count:Show()
        else
            r.text:Hide(); r.count:Hide(); r.icon:Hide()
        end
    end
    P.tallied = shown
    local shade = ns.db.textShade ~= false
    if shade then frame.shade:Show() else frame.shade:Hide() end
    if shade and shown > 0 then
        frame.tallyShade:SetSize(250, shown * ROW + 48)
        frame.tallyShade:Show()
    else
        frame.tallyShade:Hide()
    end
    self:Tick(GetTime())
end

function P:Want()
    if not (self.active and not ns.arranging and not InCombatLockdown() and ns.Fishing.HasPole()) then return false end
    if P.Bottom() then return true end
    local ok, target = pcall(UnitExists, "target")         -- up where the target frame sits: a target has the place
    return not (ok and ns.Yes(target))
end

local driver = CreateFrame("Frame")
local since, slow = 1, 0
driver:SetScript("OnUpdate", ns.Protect(function(_, dt)
    if not P.active then return end
    since = since + dt
    if since < 0.25 then return end
    slow = slow + since
    since = 0
    local want = P:Want()
    if want and not frame then Build() end
    if not frame then return end
    if want ~= frame:IsShown() then
        if want then
            P.Place(frame)
            frame:Show()
            P:Refresh()
        else
            frame:Hide()
        end
    end
    if not want then return end
    if (P.Bottom() and "bottom" or "top") ~= P.at then P.Place(frame) end      -- (the bars were put away, or kept)
    local now, J = GetTime(), ns.FishLog
    local lively = J.cast or (J.lineAt and now - J.lineAt < P.LINGER)
    frame:SetAlpha(lively and 1 or P.IDLE)
    if slow >= 2 then                                    -- the water, the skill: looked at again now and then
        slow = 0
        P:Refresh()
    else
        P:Tick(now)
    end
end))

function P:Apply(run)
    self.active = run and ns.db.fishPanel and true or false
    if frame and not self:Want() then frame:Hide() end
    since = 1
end

ns.RegisterCheck(function(row, run, db)
    if not (run and db.fishPanel) then
        row("the fishing interface is put away", not (frame and frame:IsShown()))
    end
end)

function P.Describe()
    return ("on %s, shown %s at the %s, slots known %s, kinds in the tally %s"):format(tostring(P.active),
        tostring(frame and frame:IsShown() or false), tostring(P.at),
        (function()
            local n = 0
            for _, s in ipairs(P.slots) do if s.known then n = n + 1 end end
            return n
        end)(), tostring(P.tallied or 0))
end

ns.RegisterModule("fishpanel", P)
