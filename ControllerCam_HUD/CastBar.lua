-- ControllerCam HUD: your cast bar.
-- Drawn where the game's own cast bar sits, so moving that one in Edit Mode moves ours. The game's bar is
-- put aside while ours runs.

local ADDON, ns = ...
local L, C, U = ns.L, ns.colors, ns.Unit

local CB = { active = false }
ns.CastBar = CB

ns.RegisterSetting({
    key = "castWindup", kind = "boolean", default = true, command = "windup", section = "Frames",
    label = "Cast wind-up", tip = "your cast bar glows brighter as the cast fills and bursts when it lands",
})
ns.RegisterSetting({
    key = "fishing", kind = "boolean", default = true, command = "fishing", section = "Frames",
    label = "Fishing float", tip = "while fishing, a float bobs on your cast bar and it shows what is likely to bite here",
})
ns.RegisterSetting({
    key = "castbar", kind = "boolean", default = true, command = "castbar", section = "Frames",
    label = "Cast bar", tip = "our cast bar in place of the game's (it stays where Edit Mode puts the game's)",
})

ns.RegisterSetting({
    key = "castScale", kind = "number", default = 1.35, min = 0.8, max = 2, percent = true, command = "castsize",
    section = "Frames", label = "Cast bar size",
    tip = "how large your cast bar is drawn, with the fishing float and everything else that plays on it",
})

ns.RegisterSetting({
    key = "fishBig", kind = "boolean", default = true, command = "fishbig", section = "Frames",
    label = "Fishing front and centre",
    tip = "while you fish, the cast bar moves to the middle of the screen and is drawn larger: the line, the float and what bites are the main event",
})

local NATIVE = "PlayerCastingBarFrame"
local FISH_SCALE, FISH_Y = 1.5, -100          -- while fishing: this much larger, this far under the middle of the screen
local W, H = 260, 12
local LINE = 2                -- while fishing the bar is the line: thin, with the float at its end
local LINGER = 0.45           -- how long the result (done, interrupted) stays on screen
local LINE_DOTS = 22          -- the fishing line is drawn as this many points along a curve
local TIP_X, TIP_Y = 0.1, 46  -- where it leads: this share along the bar, this far above it
local WATER = { kind = "fishing", color = { 0.6, 0.84, 1 } }

local frame, bar
local FISHING = { [7620] = true, [7731] = true, [7732] = true, [18248] = true, [33095] = true, [51294] = true,
                  [88868] = true, [110410] = true, [131474] = true, [158743] = true }
local LANDED = { color = C.cast, fx = { kind = "rays", tex = "spark", count = 5, size = 16, life = 0.45, speed = 50 } }

local function Build()
    frame = CreateFrame("Frame", "ControllerCamHUD_CastBar", UIParent)
    frame:SetSize(W, H + 16)
    frame:SetFrameStrata("MEDIUM")
    bar = ns.CreateBar(frame, W, H)
    bar:SetPoint("BOTTOM", frame, "BOTTOM", 0, 0)
    bar.spark = bar.over:CreateTexture(nil, "OVERLAY")
    bar.spark:SetTexture(ns.media.spark)
    bar.spark:SetBlendMode("ADD")
    bar.spark:SetSize(18, 18)
    bar.spark:SetPoint("CENTER", bar.fill:GetStatusBarTexture(), "RIGHT", 0, 0)
    -- the wind-up: a glow under the bar that builds as the cast fills
    bar.charge = frame:CreateTexture(nil, "BACKGROUND")
    bar.charge:SetTexture(ns.media.soft)
    bar.charge:SetPoint("TOPLEFT", bar, "TOPLEFT", -18, 14)
    bar.charge:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 18, -14)
    bar.charge:SetBlendMode("ADD")
    bar.charge:SetAlpha(0)
    -- fishing: a float riding the end of the bar, and what bites here
    bar.bobber = bar.over:CreateTexture(nil, "OVERLAY")
    bar.bobber:SetTexture(ns.media.bobber)
    bar.bobber:SetSize(22, 22)
    bar.bobber:Hide()
    -- and the line: loose, from the top of the float up to where a rod's tip would be, fading as it climbs
    bar.line = {}
    for i = 1, LINE_DOTS do
        local dot = bar.over:CreateTexture(nil, "ARTWORK")
        dot:SetColorTexture(0.88, 0.94, 1, 1)
        dot:SetSize(1.6, 1.6)
        dot:Hide()
        bar.line[i] = dot
    end
    frame.catch = ns.FontString(frame, 10, "LEFT")
    frame.catch:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 8, -5)
    frame.catch:SetTextColor(unpack(C.muted))
    frame.catchIcon = frame:CreateTexture(nil, "ARTWORK")
    frame.catchIcon:SetSize(18, 18)
    frame.catchIcon:SetPoint("RIGHT", frame.catch, "LEFT", -4, 0)
    frame.catchIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    frame.catch:Hide()
    frame.catchIcon:Hide()
    frame.label = ns.FontString(frame, 11, "LEFT")
    frame.label:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 8, 4)
    frame.time = ns.FontString(frame, 10, "RIGHT")
    frame.time:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", -8, 4)
    frame.time:SetTextColor(unpack(C.muted))
    frame:Hide()
    CB.frame, CB.bar = frame, bar
    CB.art = ns.CastArt.Attach(bar, 1)                 -- what works on the bar while it fills (CastArt.lua)
end

-- The fishing line: a loose curve from the top of the float (x along the bar, y above it) up to where a rod's
-- tip would be. It hangs slack, sways a little, and fades out towards the top: it leads to nowhere on screen.
local function DrawLine(x, y, now)
    local tx, ty = W * TIP_X, TIP_Y
    local slack = 8 + 10 * (1 - math.min(1, math.abs(x - tx) / W))      -- looser as the float comes in
    local cx = (x + tx) / 2 + math.sin(now * 1.1) * 5
    local cy = (y + ty) / 2 - slack - math.sin(now * 1.7) * 3
    for i, dot in ipairs(bar.line) do
        local t = (i - 1) / (LINE_DOTS - 1)
        local a, b, c = (1 - t) * (1 - t), 2 * (1 - t) * t, t * t
        dot:ClearAllPoints()
        dot:SetPoint("CENTER", bar, "BOTTOMLEFT", a * x + b * cx + c * tx, a * y + b * cy + c * ty)
        dot:SetAlpha(0.8 * (1 - t) ^ 0.7)
        dot:Show()
    end
end

local function HideLine()
    for _, dot in ipairs(bar.line) do dot:Hide() end
end

local function Place()
    local k = ns.db.castScale or 1
    frame:ClearAllPoints()
    if CB.fishing and ns.db.fishBig then             -- the main event: in the middle, where you look
        k = k * FISH_SCALE
        frame:SetScale(k)
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, FISH_Y / k)
        return
    end
    frame:SetScale(k)                                -- (it grows up and out from where the game's bar sits)
    local native = _G[NATIVE]
    if native then
        frame:SetPoint("BOTTOM", native, "BOTTOM", 0, 0)
    else
        frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 294)
    end
end

local function Stop()
    frame:SetScript("OnUpdate", nil)
    frame:Hide()
    CB.casting, CB.until_, CB.fishing, CB.look, CB.nextFx = false, nil, false, nil, nil
    bar.charge:SetAlpha(0)
    bar.bobber:Hide()
    HideLine()
    bar.spark:Show()
    bar:SetHeight(H)
    frame.catch:Hide()
    frame.catchIcon:Hide()
    Place()
    CB.art:Stop()
    if CB.demo then CB:DemoNext() end
end

-- How far along the cast is, 0-1 (nil without times)
local function Progress(now)
    if not CB.timed then return nil end
    return ns.Clamp((now - CB.start) / (CB.stop - CB.start), 0, 1)
end

local function OnUpdate()
    local now = GetTime()
    if CB.until_ then                         -- showing a result for a moment
        if now >= CB.until_ then Stop() else CB.art:Update(nil, nil, now) end
        return
    end
    if not CB.timed then return end
    if now >= CB.stop then
        CB:Result(false)
        return
    end
    local p = Progress(now)
    local fill = CB.channel and (1 - p) or p
    local share = fill
    bar.fill:SetValue(fill)
    CB.art:Update(fill, p, now)
    if not CB.channel and not CB.fishing and not CB.demo and ns.Rumble then ns.Rumble:Build(p) end   -- felt as it builds
    frame.time:SetText(("%.1f"):format(CB.stop - now))
    if CB.fishing then
        -- the float bobs on the water at the end of the line
        local fill = bar.fill:GetStatusBarTexture()
        bar.bobber:ClearAllPoints()
        local bob = 3 + math.sin(now * 5) * 3
        bar.bobber:SetPoint("CENTER", fill, "RIGHT", 0, bob)
        DrawLine(W * share, bob + 10, now)
        bar.charge:SetAlpha(0)
    end
    -- what kind of cast it is: a little burst now and then (stone chips while mining, leaves while picking
    -- herbs...), off the end of the bar
    local look = CB.look
    if look and look.every and not CB.fishing and not CB.art.bursts and ns.db.impactFx and ns.Impact then
        if not CB.nextFx or now >= CB.nextFx then
            CB.nextFx = now + look.every
            ns.Impact:Burst(bar, look, 0.7)
        end
    end
    if CB.fishing then
        return                                -- the float is the show
    end
    if ns.db.castWindup and not CB.channel then
        -- the wind-up: the glow builds, the spark grows, and it pulses when the cast is about to land
        local k = p * p
        local pulse = p > 0.85 and (0.15 * math.sin(now * 30)) or 0
        bar.charge:SetAlpha(ns.Clamp(k * 0.8 + pulse, 0, 1))
        bar.spark:SetSize(14 + 14 * p, 14 + 14 * p)
    else
        bar.charge:SetAlpha(0)
    end
end

CB.OnUpdate = OnUpdate

-- A cast ended: flash it (done) or mark it (interrupted), then let it linger briefly.
function CB:Result(failed)
    if not self.casting then return end
    self.casting, self.timed = false, false
    self.art:Finish(not failed, GetTime())
    if ns.Rumble and not self.demo then ns.Rumble:BuildEnd(not failed) end
    if failed then
        bar:SetColor(unpack(C.danger))
        frame.label:SetText(L["Interrupted"])
    else
        bar.fill:SetValue(self.channel and 0 or 1)
        bar:Flash(0.2)
        if ns.db.castWindup and not self.fishing and ns.Impact and ns.db.impactFx then
            local land = self.look and self.look.land
            ns.Impact:Burst(bar, (land and land.fx) and land or LANDED, 1)   -- the cast lands, in its own way
        end
    end
    bar.charge:SetAlpha(0)
    bar.bobber:Hide()
    HideLine()
    frame.time:SetText("")
    self.until_ = GetTime() + LINGER
    frame:SetScript("OnUpdate", OnUpdate)
end

function CB:Refresh()
    if not self.active then return end
    local name, startMS, endMS, channel, shielded = U.Cast("player")
    if not name then
        if self.casting then self:Result(false) end
        return
    end
    self.demo = nil                                     -- a real cast ends the show of all of them
    self.casting, self.until_, self.channel = true, nil, channel and true or false
    local cname, spellID, trade = ns.CastLook.Casting("player")
    self.look = (not ns.UnitFrames.fake) and cname and ns.CastLook.Look(cname, spellID, trade) or nil
    pcall(frame.label.SetText, frame.label, ns.CastLook.Label(name, self.look))
    self.nextFx = nil
    local color = (not ns.IsSecret(shielded) and shielded) and C.shielded or (self.look and self.look.color) or C.cast
    bar:SetColor(unpack(color))
    bar.charge:SetVertexColor(color[1], color[2], color[3], 1)
    self:Fishing(channel)
    bar.fill:SetMinMaxValues(0, 1)
    bar.trail:SetValue(0)
    frame:Show()
    if ns.IsSecret(startMS) or ns.IsSecret(endMS) or not startMS or not endMS or endMS <= startMS then
        self.timed = false
        bar.fill:SetValue(1)
        frame.time:SetText("")
        self.art:Stop()                                 -- nothing to follow along the bar
    else
        self.timed, self.start, self.stop = true, startMS / 1000, endMS / 1000
        self.art:Start(self.fishing and WATER or self.look)
    end
    if ns.Debug then
        local said = ("%s, kind %s, animation %s"):format(tostring(ns.Plain(cname)), tostring(self.look and self.look.kind),
            tostring(self.art.kind))
        if said ~= ns.Debug.lastCast then ns.Debug.lastCast = said; ns.Note("cast: %s", said) end
    end
    frame:SetScript("OnUpdate", OnUpdate)
    OnUpdate()
end

---------------------------------------------------------------------------
-- Fishing: what is likely to bite here. Read from Improved Forever's fishing data when that addon is loaded
-- (its data is not ours to copy); otherwise the bar just says where you are fishing.
---------------------------------------------------------------------------
local byName

local function FishingData()
    local IF = _G.ImprovedForever
    return type(IF) == "table" and type(IF.FishingData) == "table" and IF.FishingData or nil
end

-- name -> list of { id, chance }, for zones and for the smaller areas inside them
local function Index(D)
    if byName then return byName end
    byName = {}
    local function add(row, list)
        local name, catches = row:match("^([^|]+)|"), row:match("([^|]*)$")
        if not name or not catches then return end
        local fish = {}
        for id, chance in catches:gmatch("(%d+):([%d.]+)") do
            fish[#fish + 1] = { id = tonumber(id), chance = tonumber(chance) }
        end
        byName[name] = fish
    end
    for _, row in pairs(D.areas or {}) do if type(row) == "string" then add(row) end end
    for _, row in pairs(D.zones or {}) do
        if type(row) == "string" then
            local name = row:match("^([^|]+)|")
            if name and not byName[name] then add(row) end
        end
    end
    return byName
end

-- The likeliest fish here: { name, icon, chance } list, best first (at most n), or nil
function CB.LikelyCatch(n)
    local D = FishingData()
    if not D then return nil end
    local index = Index(D)
    local list = index[GetSubZoneText and GetSubZoneText() or ""] or index[GetZoneText and GetZoneText() or ""]
    if not list then return nil end
    local out = {}
    for _, f in ipairs(list) do
        local row = D.items and D.items[f.id]
        if type(row) == "string" and row:match("|fish$") then
            local icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(f.id)
            out[#out + 1] = { id = f.id, name = row:match("^([^|]+)"), icon = icon, chance = f.chance }
        end
    end
    table.sort(out, function(a, b) return a.chance > b.chance end)
    while #out > (n or 2) do table.remove(out) end
    return #out > 0 and out or nil
end

function CB:Fishing(channel)
    local spellID = channel and select(8, UnitChannelInfo("player"))
    self.fishing = (not ns.IsSecret(spellID)) and FISHING[spellID or 0] and ns.db.fishing or false
    self:FishingLook(self.fishing)
    if not self.fishing then return end
    frame.label:SetText("")                           -- the float says what this is; the time stays
    local catch = CB.LikelyCatch(2)
    if catch then
        local parts = {}
        for _, f in ipairs(catch) do parts[#parts + 1] = ("%s %d%%"):format(f.name, math.floor(f.chance + 0.5)) end
        frame.catch:SetText(L["Likely:"] .. " " .. table.concat(parts, ", "))
        if catch[1].icon then
            frame.catchIcon:SetTexture(catch[1].icon)
            frame.catchIcon:Show()
        else
            frame.catchIcon:Hide()
        end
    else
        frame.catch:SetText((GetSubZoneText and GetSubZoneText() ~= "" and GetSubZoneText()) or (GetZoneText and GetZoneText()) or "")
        frame.catchIcon:Hide()
    end
    frame.catch:Show()
end

-- The fishing look: the bar thins to a line the colour of water, with the float at its end. The bright edge
-- that rides the front of other casts is put away: it stood right on the float and the rings round it.
function CB:FishingLook(on)
    Place()
    if on then
        bar:SetHeight(LINE)
        bar:SetColor(unpack(WATER.color))
        bar.charge:SetAlpha(0)
        bar.spark:Hide()
        bar.bobber:Show()
    else
        bar:SetHeight(H)
        bar.spark:Show()
        bar.bobber:Hide()
        HideLine()
        frame.catch:Hide()
        frame.catchIcon:Hide()
    end
end
CB.FISHING = FISHING

---------------------------------------------------------------------------
-- /cchud casttest: every kind of cast once, a short made-up cast each
---------------------------------------------------------------------------
CB.DEMO = { "mining", "crafting", "herbs", "nature", "lightning", "roots", "heal", "arcane", "fire", "frost", "shadow",
            "holy", "physical", "fishing" }

function CB:DemoNext()
    local kind = self.demo and table.remove(self.demo, 1)
    if not kind then self.demo = nil; return end
    local fishing = kind == "fishing"
    local now = GetTime()
    self.casting, self.until_, self.channel, self.fishing = true, nil, fishing, fishing
    self.look = (not fishing) and ns.CastLook.LookOf(kind) or nil
    self.timed, self.start, self.stop, self.nextFx = true, now, now + 2.4, nil
    frame.label:SetText(fishing and "" or kind)
    local color = self.look and self.look.color or C.cast
    bar:SetColor(unpack(color))
    bar.charge:SetVertexColor(color[1], color[2], color[3], 1)
    self:FishingLook(fishing)
    bar.fill:SetMinMaxValues(0, 1)
    bar.trail:SetValue(0)
    frame:Show()
    self.art:Start(fishing and WATER or self.look)
    frame:SetScript("OnUpdate", self.OnUpdate)
end

function CB:Demo()
    if not self.active or self.casting or self.until_ then return false end
    self.demo = {}
    for i, kind in ipairs(self.DEMO) do self.demo[i] = kind end
    self:DemoNext()
    return true
end

local FAILED = { UNIT_SPELLCAST_INTERRUPTED = true, UNIT_SPELLCAST_FAILED = true }
local EVENTS = { "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
                 "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP",
                 "UNIT_SPELLCAST_CHANNEL_UPDATE", "PLAYER_ENTERING_WORLD" }

local events = CreateFrame("Frame")
local OnEvent = ns.Protect(function(_, event, unit)
    if unit and unit ~= "player" then return end
    if ns.UnitFrames.fake then return end
    if FAILED[event] then
        -- a failed instant while a real cast keeps going is not ours to show
        if CB.casting and not U.Cast("player") then CB:Result(true) end
        return
    end
    CB:Refresh()
end)

function CB:Apply(run)
    local want = run and ns.db.castbar and not ns.arranging and true or false
    ns.SetBlizzardHidden(NATIVE, want)
    if want and not frame then Build() end
    if frame then Place() end
    if want == self.active then return end
    self.active = want
    if want then
        for _, e in ipairs(EVENTS) do pcall(events.RegisterEvent, events, e) end
        events:SetScript("OnEvent", OnEvent)
        self:Refresh()
    else
        events:UnregisterAllEvents()
        events:SetScript("OnEvent", nil)
        self.demo = nil
        Stop()
    end
end

ns.RegisterCheck(function(row, run, db)
    local want = (run and db.castbar and not ns.arranging) and true or false
    row(want and "the cast bar is ours" or "the cast bar is the game's", CB.active == want)
    if _G[NATIVE] then
        row(("the game's cast bar is %s"):format(want and "put aside" or "left alone"), ns.IsBlizzardHidden(NATIVE) == want)
    end
end)

ns.RegisterModule("castbar", CB)
