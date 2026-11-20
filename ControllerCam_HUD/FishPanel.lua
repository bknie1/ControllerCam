-- ControllerCam HUD: the fishing interface.
-- With a fishing pole in your hands, under the middle of the screen: the fish of the water you stand at (the
-- ones you have not landed here are a "?"), your Fishing skill as a small bar with what bait and pole add to
-- it, how many you caught and how many got away since you logged in, the bait on your pole and how long it
-- lasts, and to its right your latest catches. It is plain while your line is out and fainter between casts;
-- it is gone in a fight and when the pole is put away. It only shows: nothing in it takes a press.
-- It is kept low and wide: there is not much room between the fishing line and the gamepad bars.

local ADDON, ns = ...
local L = ns.L
local C = ns.colors

local P = { active = false, slots = {}, rows = {} }
ns.FishPanel = P

P.Y = -168                    -- how far under the middle of the screen
P.LINGER = 12                 -- seconds after your line came in that it stays plain
P.IDLE = 0.6                  -- how visible it is between casts
P.FEED_LIFE = 90              -- seconds a catch stays in the feed
local SLOT, GAP, ROWS = 30, 4, 3
local BAR_W, BAR_H = 180, 4

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

local function Build()
    frame = CreateFrame("Frame", "ControllerCamHUD_FishPanel", UIParent)
    frame:SetSize(240, 96)
    frame:SetFrameStrata("MEDIUM")
    frame:SetPoint("TOP", UIParent, "CENTER", 0, P.Y)
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
    for i = 1, ROWS do                                      -- the feed: beside it, the latest on top
        local r = { text = ns.FontString(frame, 10, "LEFT"), icon = frame:CreateTexture(nil, "ARTWORK") }
        r.icon:SetSize(16, 16)
        r.icon:SetPoint("TOPLEFT", frame, "TOPRIGHT", 16, -(i - 1) * 22 - 2)
        r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        r.text:SetPoint("LEFT", r.icon, "RIGHT", 5, 0)
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

-- The parts that change with the clock: the bait and the feed's fading
function P:Tick(now)
    local F = ns.Fishing
    local left = F.BaitLeft()
    if left then
        frame.bait:SetText(L["Bait %s"]:format(Clock(left)))
        if left < 60 then frame.bait:SetTextColor(unpack(C.caution)) else frame.bait:SetTextColor(unpack(C.health)) end
    else
        local _, name = F.Bait()
        if name and F.BaitReady() then
            frame.bait:SetText(L["No bait: press %s twice for %s"]:format(F.KeyName(F.Keys()[1]), name))
        else
            frame.bait:SetText(L["No bait"])
        end
        frame.bait:SetTextColor(unpack(C.muted))
    end
    for i, r in ipairs(P.rows) do
        local c = ns.FishLog.feed[i]
        local age = c and (now - c.at) or P.FEED_LIFE
        if c and age < P.FEED_LIFE then
            local a = ns.Clamp((P.FEED_LIFE - age) / 20, 0, 1) * (1 - (i - 1) * 0.25)
            r.text:SetAlpha(a)
            r.icon:SetAlpha(a)
        else
            r.text:SetAlpha(0)
            r.icon:SetAlpha(0)
        end
    end
end

function P:Refresh()
    if not (frame and frame:IsShown()) then return end
    local J, F = ns.FishLog, ns.Fishing
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
    for i, r in ipairs(P.rows) do
        local c = J.feed[i]
        if c then
            local text = c.name or ("item:" .. c.id)
            if c.weight then text = text .. "  " .. J.Pounds(c.weight) end
            if c.new then text = text .. "  |cffffd24a" .. L["new!"] .. "|r"
            elseif c.best then text = text .. "  |cffffd24a" .. L["best!"] .. "|r" end
            r.text:SetText(text)
            local icon = Icon(c.id, c.icon)
            if icon then r.icon:SetTexture(icon); r.icon:Show() else r.icon:Hide() end
        else
            r.text:SetText("")
            r.icon:Hide()
        end
    end
    self:Tick(GetTime())
end

function P:Want()
    return self.active and not ns.arranging and not InCombatLockdown() and ns.Fishing.HasPole() and true or false
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
            frame:Show()
            P:Refresh()
        else
            frame:Hide()
        end
    end
    if not want then return end
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
    return ("on %s, shown %s, slots known %s"):format(tostring(P.active), tostring(frame and frame:IsShown() or false),
        (function()
            local n = 0
            for _, s in ipairs(P.slots) do if s.known then n = n + 1 end end
            return n
        end)())
end

ns.RegisterModule("fishpanel", P)
