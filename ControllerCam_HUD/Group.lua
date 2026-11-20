-- ControllerCam HUD: party and raid.
-- The game's own party and raid frames stay exactly where and what they are: they keep doing the targeting
-- (clicks, the D-pad group targeting and its highlight), the sorting, and they follow their options and Edit
-- Mode. We only make them invisible and draw our own look in the same place, one overlay per frame.
-- A client that keeps its party frames hidden in the Gamepad UI gets party frames of our own instead: secure
-- buttons (click to target, the unit menu), stacked on the left under the focus frame.

local ADDON, ns = ...
local L, C, U = ns.L, ns.colors, ns.Unit

local G = { active = false, overlays = {} }
ns.Group = G

ns.RegisterSetting({
    key = "group", kind = "boolean", default = true, command = "group", section = "Frames",
    label = "Party and raid frames",
    tip = "draw our look over the game's party and raid frames (their targeting and options keep working)",
})

G.CONTAINERS = { "PartyFrame", "CompactRaidFrameContainer" }
local OUT_OF_RANGE = 0.45

-- Every frame of the game that shows a group member, whichever kind this client and its options use.
local function Natives()
    local list = {}
    local party = _G.PartyFrame
    for i = 1, 4 do
        local f = (type(party) == "table" and party["MemberFrame" .. i]) or _G["PartyMemberFrame" .. i]
        if f then list[#list + 1] = f end
    end
    for i = 1, 5 do
        local f = _G["CompactPartyFrameMember" .. i]
        if f then list[#list + 1] = f end
    end
    for i = 1, 40 do
        local f = _G["CompactRaidFrame" .. i]
        if f then list[#list + 1] = f end
    end
    for group = 1, 8 do
        for i = 1, 5 do
            local f = _G["CompactRaidGroup" .. group .. "Member" .. i]
            if f then list[#list + 1] = f end
        end
    end
    -- and anything else inside the game's containers that shows a unit (a client may name them its own way)
    local seen = {}
    for _, f in ipairs(list) do seen[f] = true end
    local function scan(frame, depth)
        if depth > 3 or type(frame) ~= "table" or not frame.GetChildren then return end
        for _, child in ipairs({ frame:GetChildren() }) do
            if not seen[child] then
                local ok, unit = pcall(child.GetAttribute, child, "unit")
                if ok and type(unit) == "string" and (unit:match("^party") or unit:match("^raid") or unit == "player") then
                    seen[child] = true
                    list[#list + 1] = child
                else
                    scan(child, depth + 1)
                end
            end
        end
    end
    for _, name in ipairs(G.CONTAINERS) do scan(_G[name], 1) end
    scan(_G.CompactPartyFrame, 1)
    return list
end

local function UnitOf(native)
    local ok, unit = pcall(native.GetAttribute, native, "unit")
    if ok and type(unit) == "string" then return unit end
    if type(native.displayedUnit) == "string" then return native.displayedUnit end
    if type(native.unit) == "string" then return native.unit end
end

local function IsVisible(native)
    local ok, visible = pcall(native.IsVisible, native)
    return ok and visible and true or false
end

local function Width(native)
    local ok, w = pcall(native.GetWidth, native)
    return (ok and type(w) == "number" and w > 20) and w or 100
end

local function NewOverlayFor(native, width)
    local o = CreateFrame("Frame", nil, UIParent)
    o:SetFrameStrata("LOW")
    o:SetAllPoints(native)
    o.native, o.width = native, width or Width(native)
    o.edge = o:CreateTexture(nil, "BACKGROUND")           -- lit when this is your target
    o.edge:SetTexture(ns.media.soft)
    o.edge:SetVertexColor(1, 1, 1, 0.55)
    o.edge:SetPoint("TOPLEFT", o, "TOPLEFT", -8, 6)
    o.edge:SetPoint("BOTTOMRIGHT", o, "BOTTOMRIGHT", 8, -6)
    o.edge:Hide()
    o.name = ns.FontString(o, 10, "LEFT")
    o.name:SetPoint("TOPLEFT", o, "TOPLEFT", 3, -2)
    o.status = ns.FontString(o, 9, "RIGHT")
    o.status:SetPoint("TOPRIGHT", o, "TOPRIGHT", -3, -2)
    o.status:SetTextColor(unpack(C.muted))
    o.health = ns.CreateBar(o, o.width - 6, 8, { square = o.width < 90 })
    o.health:SetPoint("BOTTOMLEFT", o, "BOTTOMLEFT", 3, 7)
    o.power = ns.CreateBar(o, o.width - 6, 3, { square = true })
    o.power:SetPoint("BOTTOMLEFT", o, "BOTTOMLEFT", 3, 2)
    o:Hide()
    return o
end

local function Color(unit, frac, gone)
    if gone then return unpack(C.tapped) end
    if frac and frac <= 0.25 then return unpack(C.danger) end
    if ns.db.classColors then
        local r, g, b = ns.UnitFrames.ClassColor(unit)
        if r then return r, g, b end
    end
    return unpack(C.health)
end

local PARTY_W, PARTY_H, PARTY_GAP = 180, 30, 12

function G:BuildParty()
    if self.party then return end
    self.party = {}
    local mover = CreateFrame("Frame", "ControllerCamHUD_partyMover", UIParent)
    mover:SetSize(PARTY_W, 4 * (PARTY_H + PARTY_GAP))
    mover:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 44, -200)
    self.partyMover = mover
    for i = 1, 4 do
        local b = CreateFrame("Button", "ControllerCamHUD_party" .. i, UIParent, "SecureUnitButtonTemplate")
        b:SetSize(PARTY_W, PARTY_H)
        b:SetPoint("TOPLEFT", mover, "TOPLEFT", 0, -(i - 1) * (PARTY_H + PARTY_GAP))
        b:SetAttribute("unit", "party" .. i)
        b:SetAttribute("type1", "target")
        b:SetAttribute("type2", "togglemenu")
        b:RegisterForClicks("AnyUp")
        b:Hide()
        local o = NewOverlayFor(b, PARTY_W)
        self.party[i] = { button = b, o = o }
    end
end

-- Our own party frames: on while the game's are hidden (and we are not in a raid). Only out of combat.
function G:SetOwnParty(on)
    if on == (self.ownParty or false) or InCombatLockdown() then return end
    self:BuildParty()
    self.ownParty = on
    for _, p in ipairs(self.party) do
        if on then
            RegisterUnitWatch(p.button)
        else
            UnregisterUnitWatch(p.button)
            p.button:Hide()
            p.o:Hide()
            p.o.unit = nil
        end
    end
end

-- true / false, and false for an answer the game keeps secret (testing a secret would fail)
local function Plainly(v) if ns.IsSecret(v) then return false end return v and true or false end

local function Update(o, instant)
    local unit = o.unit
    local dead = Plainly(UnitIsDeadOrGhost(unit))
    local offline = false
    if UnitIsConnected then
        local c = UnitIsConnected(unit)
        offline = not ns.IsSecret(c) and not c
    end
    local cur, max = U.Health(unit)
    local frac = o.health:Update(cur, max, instant)
    o.health:SetColor(Color(unit, frac, dead or offline))
    local pcur, pmax, token = U.Power(unit)
    o.power:SetValues(pcur, pmax, instant)
    o.power:SetColor(unpack(C.power[token or ""] or C.power.MANA))
    pcall(o.name.SetText, o.name, ns.FullName(UnitName(unit)) or "")
    if offline then
        o.status:SetText(L["Offline"])
    elseif dead then
        o.status:SetText(L["Dead"])
    elseif frac and frac < 0.999 then
        o.status:SetText(("%d%%"):format(math.floor(frac * 100 + 0.5)))
    else
        o.status:SetText("")
    end
end

-- The quick part, done a few times a second: is it your target, is it in range
local function Glance(o)
    if Plainly(UnitIsUnit(o.unit, "target")) then o.edge:Show() else o.edge:Hide() end
    local inRange, checked = true, false
    if UnitInRange then inRange, checked = UnitInRange(o.unit) end
    if ns.IsSecret(inRange) or ns.IsSecret(checked) then
        -- the game keeps range secret: it sets the alpha from its own answer, unseen by us
        if o.SetAlphaFromBoolean and not ns.IsSecret(checked) and checked == false then o:SetAlpha(1)
        elseif o.SetAlphaFromBoolean then pcall(o.SetAlphaFromBoolean, o, inRange, 1, OUT_OF_RANGE)
        else o:SetAlpha(1) end
        return
    end
    o:SetAlpha((checked and not inRange) and OUT_OF_RANGE or 1)
end

local function NewOverlay(native) return NewOverlayFor(native) end

local function PartyNative(native)
    local unit = UnitOf(native)
    return type(unit) == "string" and (unit:match("^party") or unit == "player")
end

function G:Refresh()
    local drawn, found = 0, {}
    -- whether the game shows any party frame at all; when it does not, ours take their place
    local inRaid = IsInRaid and IsInRaid() or false
    local partyShown = false
    for _, native in ipairs(Natives()) do
        if PartyNative(native) and IsVisible(native) then partyShown = true end
    end
    self:SetOwnParty(self.active and not inRaid and not partyShown)
    if self.ownParty then
        for _, p in ipairs(self.party) do
            local o, unit = p.o, "party" .. _
            if p.button:IsVisible() and UnitExists(unit) then
                local changed = o.unit ~= unit or not o:IsShown()
                o.unit = unit
                o:Show()
                if changed then Update(o, true) end
                Glance(o)
                drawn = drawn + 1
            else
                o.unit = nil
                o:Hide()
            end
        end
    end
    for _, native in ipairs(Natives()) do
        local unit = IsVisible(native) and UnitOf(native) or nil
        found[#found + 1] = ("%s=%s%s"):format(tostring(native.GetName and native:GetName() or "?"),
            tostring((UnitOf(native))), IsVisible(native) and "" or "(hidden)")
        local o = self.overlays[native]
        if unit and UnitExists(unit) then
            if not o then
                o = NewOverlay(native)
                self.overlays[native] = o
            end
            local w = Width(native)
            if math.abs(w - o.width) > 1 then
                o.width = w
                o.health:SetWidth(w - 6)
                o.power:SetWidth(w - 6)
            end
            local changed = o.unit ~= unit or not o:IsShown()
            o.unit = unit
            o:Show()
            if changed then Update(o, true) end
            Glance(o)
            drawn = drawn + 1
        elseif o then
            o.unit = nil
            o:Hide()
        end
    end
    self.drawn, self.found = drawn, found
    -- the game's frames are only made invisible while ours are really drawn over them: in a group where we
    -- found nothing to draw on, the game's own frames stay in sight
    local grouped = (IsInGroup and IsInGroup()) or (IsInRaid and IsInRaid()) or false
    self.failOpen = self.active and grouped and drawn == 0 or false
    for _, name in ipairs(self.CONTAINERS) do ns.SetBlizzardFaded(name, self.active and not self.failOpen) end
    return drawn
end

local UNIT_EVENTS = { "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER",
                      "UNIT_NAME_UPDATE", "UNIT_CONNECTION" }
local WORLD_EVENTS = { "GROUP_ROSTER_UPDATE", "PLAYER_TARGET_CHANGED", "PLAYER_ENTERING_WORLD" }
local isUnitEvent = {}
for _, e in ipairs(UNIT_EVENTS) do isUnitEvent[e] = true end

local events = CreateFrame("Frame")
local since = 0
local OnEvent = ns.Protect(function(_, event, unit)
    if isUnitEvent[event] then
        for _, o in pairs(G.overlays) do
            if o.unit == unit and o:IsShown() then Update(o, false) end
        end
        for _, p in ipairs(G.party or {}) do
            if p.o.unit == unit and p.o:IsShown() then Update(p.o, false) end
        end
    else
        G:Refresh()
    end
end)
local OnUpdate = ns.Protect(function(_, dt)
    since = since + dt
    if since >= 0.25 then
        since = 0
        G:Refresh()
    end
end)

function G:Apply(run)
    local want = run and ns.db.group and not ns.arranging and true or false
    if not want then
        for _, name in ipairs(self.CONTAINERS) do ns.SetBlizzardFaded(name, false) end
    end
    if want == self.active then
        if want then self:Refresh() end
        return
    end
    self.active = want
    if want then
        for _, e in ipairs(UNIT_EVENTS) do pcall(events.RegisterEvent, events, e) end
        for _, e in ipairs(WORLD_EVENTS) do pcall(events.RegisterEvent, events, e) end
        events:SetScript("OnEvent", OnEvent)
        events:SetScript("OnUpdate", OnUpdate)
        self:Refresh()
    else
        events:UnregisterAllEvents()
        events:SetScript("OnEvent", nil)
        events:SetScript("OnUpdate", nil)
        for _, o in pairs(self.overlays) do
            o.unit = nil
            o:Hide()
        end
        self:SetOwnParty(false)
    end
end

ns.RegisterCheck(function(row, run, db)
    local want = (run and db.group and not ns.arranging) and true or false
    row(want and "party and raid frames wear our look" or "party and raid frames are left alone", G.active == want)
    local faded = want and not G.failOpen
    for _, name in ipairs(G.CONTAINERS) do
        if _G[name] then
            row(("the game's %s is %s"):format(name, faded and "invisible but working" or "visible"),
                ns.IsBlizzardFaded(name) == faded)
        end
    end
    if want then
        local grouped = (IsInGroup and IsInGroup()) or false
        row("party and raid members are drawn", not grouped or (G.drawn or 0) > 0,
            ("%d drawn; found: %s"):format(G.drawn or 0, table.concat(G.found or {}, ", ")))
    end
end)

ns.RegisterModule("group", G)
