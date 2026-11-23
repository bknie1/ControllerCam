-- ControllerCam HUD: party and raid.
-- The game's own party and raid frames stay exactly where and what they are: they keep doing the targeting
-- (clicks, the D-pad group targeting and its highlight), the sorting, and they follow their options and Edit
-- Mode. We only make them invisible and draw our own look in the same place, one overlay per frame.
-- A client that keeps its party frames hidden in the Gamepad UI gets party frames of our own instead: secure
-- buttons (click to target, the unit menu), stacked on the left under the focus frame.
-- A healer gets a look of their own (below, "The healer's look"): the party beside the character, each with the
-- button that targets them, and slimmer raid frames, each showing only what a healer needs.

local ADDON, ns = ...
local L, C, U = ns.L, ns.colors, ns.Unit

local G = { active = false, overlays = {}, slim = {} }     -- slim: the healer's tiles over raid frames
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

G.NARROW = 120                -- a frame narrower than this has its status after the name, not at its right end
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
    -- How they are (80%, Dead, Offline). On a wide frame it sits at the right end, and the name stops short of
    -- it. On a narrow one (the game's own party frames are) a name runs past the frame's end, so there it
    -- follows the name instead of lying across it.
    o.narrow = o.width < G.NARROW
    if o.narrow then
        o.status = ns.FontString(o, 9, "LEFT")
        o.status:SetPoint("LEFT", o.name, "RIGHT", 5, 0)
    else
        o.status = ns.FontString(o, 9, "RIGHT")
        o.status:SetPoint("TOPRIGHT", o, "TOPRIGHT", -3, -2)
        o.name:SetWidth(o.width - 52)
        if o.name.SetWordWrap then o.name:SetWordWrap(false) end
    end
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
            if p.h then
                p.h:Hide()
                p.h.unit = nil
            end
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
    o.health:SetAbsorb(ns.UnitFrames.Absorb(unit))
    if UnitGetIncomingHeals then                             -- heals on their way: yours, then everyone else's
        if ns.Bloom then o.health:SetIncomingColor(ns.Bloom.IncomingColor(unit)) end
        o.health:SetIncoming(ns.IncomingHeals(unit))
    end
    local pcur, pmax, token = U.Power(unit)
    o.power:SetValues(pcur, pmax, instant)
    o.power:SetColor(unpack(C.power[token or ""] or C.power.MANA))
    pcall(o.name.SetText, o.name, ns.FullName(UnitName(unit)) or "")
    ns.ShowRaidMark(o, o, unit, 16, "RIGHT", o, "LEFT", -3, 0)        -- a raid mark: just outside, on the left
    if offline ~= o.offline then                             -- gone: their name is as faint as their bar
        o.offline = offline
        o.name:SetTextColor(unpack(offline and C.muted or C.text))
    end
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

---------------------------------------------------------------------------
-- The healer's look (setting: Off / In a healing spec / Always). In a party: our own party frames, beside your
-- character, between it and the cooldown callouts, one row a member: the button that targets them (the Gamepad
-- UI's own: LB and a D-pad direction), their name, how much healing they need, a debuff you can cure. In a raid:
-- the game's raid frames keep their places and their LB + D-pad navigation; our look over each is a slimmer
-- tile with the same three things. Whoever is out of range, or out of sight altogether, is dimmed. Nothing else:
-- no power, no raid marks, no percent.
-- Our party frames are secure buttons: laid out again (moved, resized) only out of combat.
---------------------------------------------------------------------------
ns.RegisterSetting({
    key = "healerFrames", kind = "number", default = 2, min = 1, max = 3, command = "healerframes",
    section = "Frames",
    choices = { "Off", "In a healing spec", "Always" },
    label = "Healer's party and raid",
    tip = "in a party: your party beside your character, each with the button that targets them; in a raid: slimmer frames. Each shows only how much healing they need, a debuff you can cure, and whether they are in range",
})
G.HEALER_NAMES = { L["Off"], L["In a healing spec"], L["Always"] }

-- The talent trees that heal, by their place in the talent window
G.HEALER_TREES = { PALADIN = { [1] = true }, PRIEST = { [1] = true, [2] = true }, SHAMAN = { [3] = true },
                   DRUID = { [3] = true } }
-- What each class can cure, by the spell that does it
G.CURE_SPELLS = {
    PALADIN = { { 4987, "Magic", "Poison", "Disease" }, { 1152, "Poison", "Disease" } },     -- Cleanse, Purify
    PRIEST = { { 527, "Magic" }, { 988, "Magic" }, { 528, "Disease" }, { 552, "Disease" } },
    DRUID = { { 2782, "Curse" }, { 8946, "Poison" }, { 2893, "Poison" } },
    SHAMAN = { { 526, "Poison" }, { 2870, "Disease" } },
    MAGE = { { 475, "Curse" } },
}
G.CURE_COLORS = { Magic = { 0.2, 0.6, 1 }, Curse = { 0.6, 0, 1 }, Disease = { 0.6, 0.4, 0 }, Poison = { 0, 0.6, 0 } }
-- The Gamepad UI's friendly targeting: hold LB, and each D-pad direction (and face button) is a unit
G.TARGET_BAR = "GamepadMainActionBarFramePageUnitFriendlyTargetingActionBar"
G.TARGET_KEYS = { dpadTopButton = "PADDUP", dpadRightButton = "PADDRIGHT", dpadBottomButton = "PADDDOWN",
                  dpadLeftButton = "PADDLEFT", faceBottomButton = "PAD1", faceRightButton = "PAD2",
                  faceLeftButton = "PAD3", faceTopButton = "PAD4" }
G.TARGET_ORDER = { "dpadTopButton", "dpadRightButton", "dpadBottomButton", "dpadLeftButton", "faceBottomButton",
                   "faceRightButton", "faceLeftButton", "faceTopButton" }
-- (a bar without those fields: its first four buttons by their place, as seen in the game: left, up, right, down)
G.TARGET_BY_INDEX = { "dpadLeftButton", "dpadTopButton", "dpadRightButton", "dpadBottomButton" }
G.MODIFIER = "PADLSHOULDER"
-- Party rows: their size, the room for the button at their left end and the cure at their right, and how far
-- short of the cooldown callouts they end (where those would be when they are off: right of your character)
G.HEAL = { w = 150, h = 24, gap = 6, bind = 36, cure = 16, beside = 22, x = 150, y = -40 }
G.NEED = 0.95                       -- under this share of their health, how much they are missing is written
G.FAR, G.UNSEEN = 0.4, 0.25         -- out of range; out of sight altogether (too far to target)
G.TILE_INSET = { 0.08, 0.14 }       -- a raid tile is this much smaller than the game's frame, each side
local HEAL_BACK = { 0.30, 0.07, 0.09, 0.85 }   -- the empty part of a healer's bar: what they are missing, in red

local function Try(fn, ...)
    if type(fn) ~= "function" then return false end
    return pcall(fn, ...)
end

-- Is the talent group you have on a healer's? true / false, and its tree
function G.HealingSpec()
    if G.spec then return G.spec.healer, G.spec.tree end
    local V = ns.Vendor
    local _, class = UnitClass("player")
    local trees = G.HEALER_TREES[class or ""]
    local tree
    if trees and V and V.SpecGroups and V.Trees and V.MainTree then
        local ok, _, active = pcall(V.SpecGroups)
        local okT, points = false, nil
        if ok then okT, points = pcall(V.Trees, active) end
        if okT then tree = V.MainTree(points) end
    end
    G.spec = { healer = (tree and trees and trees[tree]) and true or false, tree = tree }
    return G.spec.healer, tree
end

-- Is the healer's look wanted now (the setting, and for "In a healing spec" your talents)?
function G.Wanted()
    local mode = tonumber(ns.db and ns.db.healerFrames) or 2
    if mode <= 1 then return false end
    if mode >= 3 then return true end
    return (G.HealingSpec())
end

local function Known(id)
    local asked = false
    for _, fn in ipairs({ IsPlayerSpell or false, IsSpellKnown or false }) do
        local ok, yes = Try(fn, id)
        if ok then
            asked = true
            if yes == true then return true end
        end
    end
    return not asked                      -- a client that cannot say: as if known
end

-- The kinds of debuff you can cure now: { Magic = true, ... }
function G.Cures()
    if G.cures then return G.cures end
    local _, class = UnitClass("player")
    local out = {}
    for _, spell in ipairs(G.CURE_SPELLS[class or ""] or {}) do
        if Known(spell[1]) then
            for i = 2, #spell do out[spell[i]] = true end
        end
    end
    G.cures = out
    return out
end

local function CureFilter() return "HARMFUL|" .. ((ns.AuraWidgets and ns.AuraWidgets.DISPEL) or "RAID") end

-- A debuff on the unit you can cure (where the game draws none for us), or nil. The game picks the ones you can
-- dispel; one whose kind it tells must be a kind your class cures.
function G.Curable(unit)
    local cures = G.Cures()
    if not next(cures) then return nil end
    local filter = CureFilter()
    local list = U.Filtered and U.Filtered(unit, "HARMFUL", filter, 8)
    if not list then
        list = {}
        for i = 1, 40 do
            local a = U.Aura and U.Aura(unit, i, filter)
            if not a then break end
            list[#list + 1] = a
        end
    end
    for _, a in ipairs(list) do
        local kind = a.dispelName
        if ns.IsSecret(kind) then return a end                     -- the game's own filter chose it
        if type(kind) == "string" and cures[kind] then return a end
    end
    return nil
end

-- The button that targets each unit: { [unit] = text }. The Gamepad UI's friendly targeting bar says which
-- direction holds whom; failing that, a binding of the game's own (Target Party Member 1-4, Target Self).
local function KeyParts(key, size)
    local out = {}
    for part in tostring(key):gmatch("[^%-]+") do out[#out + 1] = ns.KeyText(part, size) end
    return table.concat(out, "")
end
function G.Binds(size)
    local out, bar = {}, _G[G.TARGET_BAR]
    if type(bar) == "table" then
        local byIndex = {}
        for i, field in ipairs(G.TARGET_BY_INDEX) do byIndex[field] = _G[G.TARGET_BAR .. "ActionButton" .. i] end
        for _, field in ipairs(G.TARGET_ORDER) do
            local b = bar[field]
            if type(b) ~= "table" then b = byIndex[field] end
            local unit = type(b) == "table" and UnitOf(b)
            if unit and not out[unit] then
                out[unit] = ns.KeyText(G.MODIFIER, size) .. ns.KeyText(G.TARGET_KEYS[field], size)
            end
        end
    end
    if GetBindingKey then
        local function bound(unit, action)
            if out[unit] then return end
            local ok, key = pcall(GetBindingKey, action)
            if ok and type(key) == "string" and not ns.IsSecret(key) then out[unit] = KeyParts(key, size) end
        end
        for i = 1, 4 do bound("party" .. i, "TARGETPARTYMEMBER" .. i) end
        bound("player", "TARGETSELF")
    end
    return out
end

-- Where the party goes: its right end a little short of where the cooldown callouts start
function G.Beside()
    local soon = ns.Numbers and ns.Numbers.Soon
    local x, y
    if soon and soon.Spot then
        local ok, sx, sy = pcall(soon.Spot)
        if ok and type(sx) == "number" and type(sy) == "number" then x, y = sx, sy end
    end
    x, y = x or G.HEAL.x, y or G.HEAL.y
    return math.floor(x - G.HEAL.beside + 0.5), math.floor(y + 0.5)
end

-- The cure: the game's own icon of a debuff you can dispel, edged in its kind's colour, or ours
local function NewCure(o, size, y)
    local W = ns.AuraWidgets
    local row = W and W.Row(o, { filter = CureFilter(), max = 1, size = size, text = 8, typed = true,
                                 grow = "LEFT", spacing = 0, bare = true })
    if row then
        row:SetPoint(row.point, o, "BOTTOMRIGHT", 0, y)
        o.cureRow = row
    else
        local b = ns.AuraButton(o, size, 8)
        b:SetPoint("BOTTOMRIGHT", o, "BOTTOMRIGHT", 0, y)
        b.time:Hide()
        b.count:Hide()
        o.cureButton = b
    end
end

local function NewHealLook(o, w, h, opts)
    o.heal = true
    o.width = w
    o.edge = o:CreateTexture(nil, "BACKGROUND")           -- lit when this is your target
    o.edge:SetTexture(ns.media.soft)
    o.edge:SetVertexColor(1, 1, 1, 0.45)
    o.edge:SetPoint("TOPLEFT", o, "TOPLEFT", -6, 5)
    o.edge:SetPoint("BOTTOMRIGHT", o, "BOTTOMRIGHT", 6, -5)
    o.edge:Hide()
    -- the bar and the cure stop short of each other. The name line runs over the cure's column only on a tile,
    -- where the cure sits low, under it; on a party row the cure is level with the whole row.
    local left, right = opts.bind or 0, opts.cure + 3
    local top = opts.tile and 0 or right
    if opts.bind then
        o.bind = ns.FontString(o, 11, "CENTER")
        o.bind:SetPoint("CENTER", o, "LEFT", left / 2, 0)
        o.bind:SetWidth(left)
        if o.bind.SetWordWrap then o.bind:SetWordWrap(false) end
    end
    o.name = ns.FontString(o, opts.text, "LEFT")
    o.name:SetPoint("TOPLEFT", o, "TOPLEFT", left + 1, 0)
    if o.name.SetWordWrap then o.name:SetWordWrap(false) end
    o.need = ns.FontString(o, opts.text, "RIGHT")
    o.need:SetPoint("TOPRIGHT", o, "TOPRIGHT", -top, 0)
    if o.need.SetWordWrap then o.need:SetWordWrap(false) end
    o.health = ns.CreateBar(o, math.max(10, w - left - right), opts.bar, { square = true })
    o.health:SetPoint("BOTTOMLEFT", o, "BOTTOMLEFT", left, 2)
    o.health.back:SetColorTexture(unpack(HEAL_BACK))
    if opts.tile then o.health.shadow:Hide() else o.health.shadow:SetVertexColor(0, 0, 0, 0.35) end
    o.left, o.right, o.top = left, right, top
    o.line = w - left - 1 - top                        -- the name line: the name, then the need at its end
    o.name:SetWidth(math.max(10, o.line))
    NewCure(o, opts.cure, opts.tile and 1 or math.floor((h - opts.cure) / 2 + 0.5))
    o:Hide()
    return o
end

-- The name takes what the need at the end of its line leaves it, so the two never run into each other
local function Fit(o)
    local nw = 0
    if (o.need:GetText() or "") ~= "" then
        local ok, w = pcall(o.need.GetStringWidth, o.need)
        nw = (ok and type(w) == "number" and not ns.IsSecret(w)) and w or 0
    end
    o.name:SetWidth(math.max(10, o.line - (nw > 0 and nw + 4 or 0)))
end

-- One of our party frames, in the healer's look
local function NewHealerRow(button)
    local o = CreateFrame("Frame", nil, UIParent)
    o:SetFrameStrata("LOW")
    o:SetAllPoints(button)
    o.native = button
    return NewHealLook(o, G.HEAL.w, G.HEAL.h, { bind = G.HEAL.bind, cure = G.HEAL.cure, text = 10, bar = 9 })
end

local function Height(native)
    local ok, h = pcall(native.GetHeight, native)
    return (ok and type(h) == "number" and h > 12) and h or 36
end
-- A raid tile: over the game's raid frame, a little inside it
local function TileSize(native)
    local w, h = Width(native), Height(native)
    local ix, iy = math.floor(w * G.TILE_INSET[1] + 0.5), math.floor(h * G.TILE_INSET[2] + 0.5)
    return w - 2 * ix, h - 2 * iy, ix, iy
end
local function PlaceTile(o, native)
    local w, h, ix, iy = TileSize(native)
    o:ClearAllPoints()
    o:SetPoint("TOPLEFT", native, "TOPLEFT", ix, -iy)
    o:SetPoint("BOTTOMRIGHT", native, "BOTTOMRIGHT", -ix, iy)
    return w, h
end
local function NewTile(native)
    local o = CreateFrame("Frame", nil, UIParent)
    o:SetFrameStrata("LOW")
    local w, h = PlaceTile(o, native)
    o.native, o.tile, o.nativeWidth = native, true, Width(native)
    return NewHealLook(o, w, h, { cure = 12, text = 8, bar = math.max(4, math.min(8, h - 13)), tile = true })
end

local function HealColor(unit, frac, gone)
    if gone then return unpack(C.tapped) end
    if frac and frac <= 0.35 then return unpack(C.danger) end
    if frac and frac <= 0.7 then return unpack(C.caution) end
    if ns.db.classColors then
        local r, g, b = ns.UnitFrames.ClassColor(unit)
        if r then return r, g, b end
    end
    return unpack(C.health)
end

-- The cure shown (or not) for whoever the look is on now. fresh: the same token, another person
local function Cure(o, fresh)
    if o.cureRow then
        ns.AuraWidgets.Show(o.cureRow, o.unit, CureFilter(), o.unit ~= nil, fresh)
        return
    end
    local b = o.cureButton
    local a = o.unit and G.Curable(o.unit)
    if a then
        ns.ShowAura(b, o.unit, a)
        if b.cooldown and b.cooldown.SetHideCountdownNumbers then b.cooldown:SetHideCountdownNumbers(true) end
        b.count:SetText("")
        b.kind = ns.Plain(a.dispelName)
        local c = G.CURE_COLORS[b.kind or ""] or C.text
        b.back:SetColorTexture(c[1], c[2], c[3], 1)
        b.time:Hide()
    else
        b:Hide()
    end
    o.cured = a and true or false
end

local function UpdateHeal(o, instant)
    local unit = o.unit
    local dead = Plainly(UnitIsDeadOrGhost(unit))
    local offline = false
    if UnitIsConnected then
        local c = UnitIsConnected(unit)
        offline = not ns.IsSecret(c) and not c
    end
    local cur, max = U.Health(unit)
    local frac = o.health:Update(cur, max, instant)
    o.health:SetColor(HealColor(unit, frac, dead or offline))
    if UnitGetIncomingHeals then                             -- heals on their way: none wasted on them
        if ns.Bloom then o.health:SetIncomingColor(ns.Bloom.IncomingColor(unit)) end
        o.health:SetIncoming(ns.IncomingHeals(unit))
    end
    pcall(o.name.SetText, o.name, (UnitName(unit)) or "")
    if offline ~= o.offline then
        o.offline = offline
        o.name:SetTextColor(unpack(offline and C.muted or C.text))
    end
    local state = (offline and L["Offline"]) or (dead and L["Dead"]) or (o.unseen and L["Too far"]) or nil
    if state then
        o.need:SetText(state)
        o.need:SetTextColor(unpack(C.muted))
    elseif frac and frac < G.NEED and not o.tile then     -- (on a raid tile the bar says it: no number)
        o.need:SetText("-" .. tostring(ns.ShortNumber(math.max(0, (tonumber(max) or 0) - (tonumber(cur) or 0)))))
        o.need:SetTextColor(unpack(C.text))
    else
        o.need:SetText("")
    end
    Fit(o)
end

-- The quick part for a healer's look: target, range, and out of sight altogether
local function HealGlance(o)
    if Plainly(UnitIsUnit(o.unit, "target")) then o.edge:Show() else o.edge:Hide() end
    local unseen = false
    if UnitIsVisible then
        local ok, seen = pcall(UnitIsVisible, o.unit)
        unseen = (ok and not ns.IsSecret(seen) and seen == false) and true or false
    end
    if unseen ~= (o.unseen or false) then
        o.unseen = unseen
        UpdateHeal(o, true)
    end
    if unseen then o:SetAlpha(G.UNSEEN); return end
    local inRange, checked = true, false
    if UnitInRange then inRange, checked = UnitInRange(o.unit) end
    if ns.IsSecret(inRange) or ns.IsSecret(checked) then
        if o.SetAlphaFromBoolean and not ns.IsSecret(checked) and checked == false then o:SetAlpha(1)
        elseif o.SetAlphaFromBoolean then pcall(o.SetAlphaFromBoolean, o, inRange, 1, G.FAR)
        else o:SetAlpha(1) end
        return
    end
    o:SetAlpha((checked and not inRange) and G.FAR or 1)
end

local function SetBind(o, text)
    if not o.bind then return end
    text = text or ""
    if o.bindText ~= text then
        o.bindText = text
        o.bind:SetText(text)
    end
end

-- Our party frames laid out for the look wanted ("healer" beside your character, or "plain" on the left).
-- Only out of combat; in a fight they stay as they are.
function G:Arrange(healer)
    if InCombatLockdown() then return end
    local want = healer and "healer" or "plain"
    local x, y
    if healer then x, y = G.Beside() end
    if self.arranged == want and (not healer or (self.at and self.at[1] == x and self.at[2] == y)) then return end
    self.arranged = want
    local mover = self.partyMover
    local w, h, gap = PARTY_W, PARTY_H, PARTY_GAP
    mover:ClearAllPoints()
    if healer then
        w, h, gap = G.HEAL.w, G.HEAL.h, G.HEAL.gap
        mover:SetPoint("RIGHT", UIParent, "CENTER", x, y)
        self.at = { x, y }
    else
        mover:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 44, -200)
        self.at = nil
    end
    mover:SetSize(w, 4 * h + 3 * gap)
    for i, p in ipairs(self.party) do
        p.button:SetSize(w, h)
        p.button:ClearAllPoints()
        p.button:SetPoint("TOPLEFT", mover, "TOPLEFT", 0, -(i - 1) * (h + gap))
        if healer and not p.h then p.h = NewHealerRow(p.button) end
    end
end

local function NewOverlay(native) return NewOverlayFor(native) end

local function PartyNative(native)
    local unit = UnitOf(native)
    return type(unit) == "string" and (unit:match("^party") or unit == "player")
end

-- Who a unit is (its GUID), or nil where the game keeps it secret. A slot is not a person: when someone leaves
-- the party (kicked while offline, say) the ones after move up a slot, "party3" becoming "party2", and a look
-- kept for "party2" went on showing whoever was there before until something else redrew it.
local function Who(unit)
    local ok, guid = pcall(UnitGUID, unit)
    if ok and type(guid) == "string" and not ns.IsSecret(guid) then return guid end
end
-- Draw this look for `unit` now, all of it, when the unit or the person behind it changed (or `force`)
local function Fresh(o, unit, force)
    local who = Who(unit)
    local changed = force or o.unit ~= unit or not o:IsShown() or o.who ~= who
    o.unit, o.who = unit, who
    o:Show()
    if changed then
        if o.heal then
            o.unseen = nil
            UpdateHeal(o, true)
            Cure(o, true)
        else
            Update(o, true)
        end
    end
end
local function Hide(o)
    if not o then return end
    o.unit = nil
    o:Hide()
    if o.cureRow then ns.AuraWidgets.Show(o.cureRow, nil, nil, false) end
end

function G:Refresh(force)
    local drawn, found = 0, {}
    -- whether the game shows any party frame at all; when it does not, ours take their place
    local inRaid = IsInRaid and IsInRaid() or false
    local partyShown = false
    for _, native in ipairs(Natives()) do
        if PartyNative(native) and IsVisible(native) then partyShown = true end
    end
    -- the healer's look: in a party, our own party frames beside your character, whatever the game shows
    local healer = self.active and G.Wanted() or false
    self.healer = healer
    self:SetOwnParty(self.active and not inRaid and (healer or not partyShown))
    local ownHealer = false                 -- our party frames are laid out as the healer's (and drawn so)
    if self.ownParty then
        self:Arrange(healer)
        ownHealer = self.arranged == "healer"
        local binds = ownHealer and G.Binds(14) or nil
        self.binds = binds
        for i, p in ipairs(self.party) do
            local o, unit = ownHealer and p.h or p.o, "party" .. i
            Hide(ownHealer and p.o or p.h)
            if p.button:IsVisible() and UnitExists(unit) then
                Fresh(o, unit, force)
                if ownHealer then
                    SetBind(o, binds[unit])
                    HealGlance(o)
                else
                    Glance(o)
                end
                drawn = drawn + 1
            else
                Hide(o)
            end
        end
    end
    -- one look per person: the game may show the same party member twice (its party frames and its raid-style
    -- ones at once); the first of them is drawn on (the party frames, where the D-pad's group targeting is)
    local drawnFor = {}
    for _, native in ipairs(Natives()) do
        local unit = IsVisible(native) and UnitOf(native) or nil
        local twice = unit and drawnFor[unit]
        found[#found + 1] = ("%s=%s%s"):format(tostring(native.GetName and native:GetName() or "?"),
            tostring((UnitOf(native))), (not IsVisible(native)) and "(hidden)" or twice and "(again)" or "")
        if twice then unit = nil end
        if unit then drawnFor[unit] = true end
        if unit and ownHealer and PartyNative(native) then unit = nil end    -- (ours beside you show them)
        -- the healer's look over a raid frame is a slim tile; the plain one covers it
        local look, other = healer and self.slim or self.overlays, healer and self.overlays or self.slim
        Hide(other[native])
        local o = look[native]
        if unit and UnitExists(unit) then
            if not o then
                o = healer and NewTile(native) or NewOverlay(native)
                look[native] = o
            end
            local w = Width(native)
            if o.tile then
                if math.abs(w - o.nativeWidth) > 1 then
                    o.nativeWidth = w
                    local tw = PlaceTile(o, native)
                    o.width = tw
                    o.health:SetWidth(math.max(10, tw - o.left - o.right))
                    o.line = tw - o.left - 1 - o.top
                    Fit(o)
                end
            elseif math.abs(w - o.width) > 1 then
                o.width = w
                o.health:SetWidth(w - 6)
                o.power:SetWidth(w - 6)
            end
            Fresh(o, unit, force)
            if o.heal then HealGlance(o) else Glance(o) end
            drawn = drawn + 1
        elseif o then
            Hide(o)
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
                      "UNIT_NAME_UPDATE", "UNIT_CONNECTION", "UNIT_ABSORB_AMOUNT_CHANGED", "UNIT_HEAL_PREDICTION",
                      "UNIT_AURA" }
local WORLD_EVENTS = { "GROUP_ROSTER_UPDATE", "PLAYER_TARGET_CHANGED", "PLAYER_ENTERING_WORLD", "RAID_TARGET_UPDATE" }
-- your talents or spells changed: whether you heal, and what you can cure, are asked again
local SPEC_EVENTS = { "PLAYER_TALENT_UPDATE", "ACTIVE_TALENT_GROUP_CHANGED", "CHARACTER_POINTS_CHANGED",
                      "TRAIT_CONFIG_UPDATED", "PLAYER_SPECIALIZATION_CHANGED", "SPELLS_CHANGED" }
local isSpecEvent = {}
for _, e in ipairs(SPEC_EVENTS) do isSpecEvent[e] = true end
local isUnitEvent = {}
for _, e in ipairs(UNIT_EVENTS) do isUnitEvent[e] = true end

local events = CreateFrame("Frame")
local since = 0
local OnEvent = ns.Protect(function(_, event, unit)
    if isUnitEvent[event] then
        local aura = event == "UNIT_AURA"
        local function redraw(o)
            if not (o and o.unit == unit and o:IsShown()) then return end
            if o.heal then
                if aura then Cure(o) else UpdateHeal(o, false) end
            elseif not aura then
                Update(o, false)
            end
        end
        for _, o in pairs(G.overlays) do redraw(o) end
        for _, o in pairs(G.slim) do redraw(o) end
        for _, p in ipairs(G.party or {}) do
            redraw(p.o)
            redraw(p.h)
        end
    elseif isSpecEvent[event] then
        G.spec, G.cures = nil, nil
        G:Refresh(true)
    else
        -- the roster changed (someone joined, left, was kicked): every look drawn again, slots may hold others now
        G:Refresh(event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD")
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
        for _, e in ipairs(SPEC_EVENTS) do pcall(events.RegisterEvent, events, e) end
        G.spec, G.cures = nil, nil
        events:SetScript("OnEvent", OnEvent)
        events:SetScript("OnUpdate", OnUpdate)
        self:Refresh()
    else
        events:UnregisterAllEvents()
        events:SetScript("OnEvent", nil)
        events:SetScript("OnUpdate", nil)
        for _, o in pairs(self.overlays) do Hide(o) end
        for _, o in pairs(self.slim) do Hide(o) end
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
        local healer, tree = G.HealingSpec()
        local binds = {}
        for unit, text in pairs(G.binds or {}) do binds[#binds + 1] = unit .. " " .. text end
        table.sort(binds)
        row(G.healer and "the healer's look is on" or "the healer's look is off", true,
            ("setting %s, talent tree %s (%s), party laid out %s, buttons: %s"):format(
                tostring(G.HEALER_NAMES[tonumber(db.healerFrames) or 2] or db.healerFrames),
                tostring(tree), healer and "heals" or "does not heal", tostring(G.arranged),
                #binds > 0 and table.concat(binds, ", ") or "none"))
    end
end)

ns.RegisterModule("group", G)
