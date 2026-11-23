-- ControllerCam HUD: nameplates.
-- The game still creates, places, shows and hides every nameplate, and its nameplate options still decide
-- which ones exist. We make its drawing invisible and put ours on the same plate:
--   name (with the player's title), a subtitle (guild, or the NPC's job), level and an elite mark,
--   a health bar and a power bar, a cast bar with the spell and who it is aimed at, and a clear mark on your
--   target. Friends show only their name until they are in a fight. Stands down when another nameplate
--   addon is loaded.

local ADDON, ns = ...
local L, C, U = ns.L, ns.colors, ns.Unit

-- plates: by unit, while on screen. byPlate: our drawing for each plate the game made (it reuses them).
-- byGuid: our drawing by the unit's GUID, for hit effects.
local NP = { active = false, plates = {}, byPlate = setmetatable({}, { __mode = "k" }), byGuid = {} }
ns.Nameplates = NP

local function Setting(key, label, tip, default)
    ns.RegisterSetting({ key = key, kind = "boolean", default = default, command = key:lower(), section = "Nameplates",
                         label = label, tip = tip })
end
Setting("nameplates", "Nameplates", "our look on the game's nameplates (its nameplate options still apply)", true)
Setting("plateTitles", "Player titles", "show a player's title with their name", true)
Setting("plateSubtitles", "Guilds and NPC jobs", "a line under the name: the player's guild, or what the NPC does", true)
Setting("plateFriendBars", "Bars for friends in a fight", "friendly plates show health, power and casts while that unit is in combat", true)
Setting("plateFriendsGame", "The game's own friendly nameplates", "leave friendly plates (your party, other players, friendly NPCs) to the game's own look; ours only on enemies", false)
Setting("platePower", "Power bars", "a thin mana, rage or energy bar under the health bar", true)
Setting("plateCastTarget", "Cast target", "who a cast is aimed at, next to the spell's name", true)
Setting("platePercent", "Health percent", "the health percent on the bar", true)
Setting("plateTargetName", "Name on your target's plate", "off: your target's plate drops its name and level (the target frame shows them)", true)
Setting("plateLevels", "Levels on nameplates", "the level in front of an enemy's name, coloured by difficulty", true)
Setting("plateCompact", "Compact nameplates", "nameplates about half as wide", false)
Setting("plateCastAlert", "Loud enemy casts", "an enemy's cast flashes, swells and pulses ever faster until it lands, so it can be interrupted in time", true)
Setting("plateClassIcons", "Class icons on nameplates", "a player's class icon in front of their name, friend or enemy", true)
Setting("plateServiceIcons", "What NPCs do, as icons", "an icon over friendly NPCs that offer something: a bag over vendors, an anvil over smiths who repair, a book over trainers... (the game's own icons; they show even while the plate itself waits to be pointed at)", true)
Setting("plateHoverNPC", "Friendly NPCs only when pointed at", "the plates of friendly NPCs (vendors, quest givers, townsfolk) show only while you point at them, like their tooltip", false)
Setting("plateObjects", "Names on things you can interact with", "a name over ore, chests, plaques and the like while you face them (off: they stay bare, as the game's own prompt already says what they are)", false)
-- How big the bars are, and how much of a name: your call. And a whole look in one press (Full, Minimal, Minimal
-- mini), which sets the switches above and below at once; each can still be changed afterwards.
NP.SIZE_W, NP.SIZE_H = { 0.6, 1, 1.25 }, { 0.7, 1, 1.45 }
ns.RegisterSetting({
    key = "plateSize", kind = "number", default = 2, min = 1, max = 3, section = "Nameplates",
    choices = { "Small", "Normal", "Large" }, command = "platesize", label = "Nameplate size",
    tip = "how big the bars on nameplates are: small and slim, normal, or large (wider and taller)",
})
ns.RegisterSetting({
    key = "plateName", kind = "number", default = 1, min = 1, max = 3, section = "Nameplates",
    choices = { "Full name", "Short name", "No name" }, command = "platename", label = "Names on nameplates",
    tip = "the name on a plate with a health bar: in full, cut short, or left out (the target frame gives it in full; the level and class icon stay). A plate with no bar, a friendly NPC's, always keeps its name",
})
NP.LOOKS = {
    { plateSize = 2, plateName = 1, platePower = true, platePercent = true, plateValue = false, plateLevels = true,
      plateClassIcons = true, plateTitles = true, plateSubtitles = true, plateDebuffs = true, plateBuffs = true,
      plateAllDebuffs = false, plateCastTarget = true },
    { plateSize = 2, plateName = 2, platePower = false, platePercent = true, plateValue = false, plateLevels = true,
      plateClassIcons = true, plateTitles = false, plateSubtitles = false, plateDebuffs = true, plateBuffs = true,
      plateAllDebuffs = false, plateCastTarget = false },
    { plateSize = 1, plateName = 3, platePower = false, platePercent = true, plateValue = false, plateLevels = true,
      plateClassIcons = true, plateTitles = false, plateSubtitles = false, plateDebuffs = true, plateBuffs = true,
      plateAllDebuffs = false, plateCastTarget = false },
}
ns.RegisterSetting({
    key = "plateLook", kind = "number", default = 1, min = 1, max = 3, section = "Nameplates",
    choices = { "Full", "Minimal", "Minimal mini" }, command = "platelook", label = "Nameplate look",
    tip = "the nameplate switches in one press. Full: everything. Minimal: no power bar, guild or title, short names. Minimal mini: small bars with health, your debuffs and the buffs that matter, level and class, no name (the target frame has it). Threat, crowd control and loud casts always stay",
    set = function(v)
        ns.db.plateLook = v
        for key, value in pairs(NP.LOOKS[v] or {}) do ns.db[key] = value end
    end,
})

-- (in your language: the options show the choices as L[choice])
NP.NAMES = { L["Small"], L["Normal"], L["Large"], L["Full name"], L["Short name"], L["No name"], L["Full"],
             L["Minimal"], L["Minimal mini"] }

-- Small: the size chosen, or the compact bar style (Options' style switch)
function NP.Size()
    local size = tonumber(ns.db.plateSize) or 2
    if size == 2 and ns.db.plateCompact then size = 1 end
    return size
end

-- The name as the plate shows it: in full, cut short (14 letters), or none where the plate has a bar to say who
-- it is by; a name the game keeps to itself is shown as it is
NP.SHORT = 14
function NP.ShownName(o, name)
    local mode = tonumber(ns.db.plateName) or 1
    if mode == 1 or not o.bars or type(name) ~= "string" or ns.IsSecret(name) then return name end
    if mode == 3 then return "" end
    local letters = {}
    for ch in name:gmatch("[%z\1-\127\194-\244][\128-\191]*") do letters[#letters + 1] = ch end
    if #letters <= NP.SHORT then return name end
    return table.concat(letters, "", 1, NP.SHORT - 1):gsub("%s+$", "") .. "…"
end

Setting("plateMini", "Mini plates", "minions, critters and grey enemies that give no experience get a small plate: a slim bar with your debuffs on it and no name (a critter, with no bar, keeps its name; the game's own option decides whether they have plates at all)", true)

-- Minor units: the game's "minus" classification (minions, small adds) and critters, by creature type in each
-- game language
local CRITTER = { Critter = true, Kleintier = true, ["Alimaña"] = true, Bestiole = true, Animale = true,
                  ["동물"] = true, Bicho = true, ["Существо"] = true, ["小动物"] = true, ["小動物"] = true }
local MINI_SCALE = 0.8          -- minor units: the whole plate a little smaller ...
local MINI_BAR = 0.625          -- ... and the bar shorter: half the width of a normal plate's

-- A minor unit: a minion, a critter, or an enemy so far below you it gives nothing (grey, "trivial")
function NP.IsMinor(unit, kind)
    if kind == "minus" or kind == "trivial" then return true end
    local ok, ctype = pcall(UnitCreatureType, unit)
    if ok and not ns.IsSecret(ctype) and CRITTER[ctype or ""] then return true end
    if UnitIsTrivial then
        local okT, trivial = pcall(UnitIsTrivial, unit)
        if okT and trivial and not ns.IsSecret(trivial) then return true end
    end
    local okL, level = pcall(UnitLevel, unit)
    if okL and type(level) == "number" and not ns.IsSecret(level) and level > 0 then
        local r, g, b = ns.LevelColor(level)
        local grey = math.abs(r - g) < 0.06 and math.abs(g - b) < 0.06 and r < 0.7
        if grey then return true end                                     -- the grey of "no experience"
    end
    return false
end

NP.OTHERS = { "Platynator", "Plater", "Kui_Nameplates", "TidyPlates", "TidyPlates_ThreatPlates", "NeatPlates",
              "ElvUI", "bdNameplates" }
local W, H = 120, 7
NP.SHAKE = 0.5                  -- a plate shakes this much of what the target frame does
local TARGET_SCALE, OTHER_ALPHA = 1.15, 0.85
local LOOK_EVERY = 0.3          -- friends entering or leaving a fight have no event of their own

-- Another addon that draws nameplates, if one is loaded
function NP:Rival()
    local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    if not loaded then return nil end
    for _, name in ipairs(self.OTHERS) do
        if loaded(name) then return name end
    end
end

-- The game's own drawing on a plate: every child frame of the plate that is not ours
local function Natives(plate)
    local list = {}
    local mine = NP.byPlate[plate]
    local icon = mine and mine.service
    for _, child in ipairs({ plate:GetChildren() }) do
        if child ~= mine and child ~= icon and child.SetAlpha then list[#list + 1] = child end
    end
    local uf = plate.UnitFrame or plate.unitFrame
    if type(uf) == "table" and uf.SetAlpha then
        local seen = false
        for _, c in ipairs(list) do if c == uf then seen = true end end
        if not seen then list[#list + 1] = uf end
    end
    return list
end

-- Hidden natives stay hidden: the game sets their alpha again on its own (target changes, range), so every
-- time it does, it is set back to 0.
-- Looked at every frame (the game fades its own plate by distance as you move: looked at less often, it flashed
-- through ours), and what is inside it too (its bar, its name), which the game leaves alone: so even a frame
-- where the game has set its plate's alpha again shows nothing of it.
local insideOf = setmetatable({}, { __mode = "k" })     -- (kept in a table of ours: nothing written on the game's frame)
local function HideNative(frame, hide)
    local inside = {}
    local okC, kids = pcall(function() return { frame:GetChildren() } end)
    for _, c in ipairs(okC and kids or {}) do if c.SetAlpha then inside[#inside + 1] = c end end
    local okR, regions = pcall(function() return { frame:GetRegions() } end)
    for _, r in ipairs(okR and regions or {}) do if r.SetAlpha then inside[#inside + 1] = r end end
    if hide then
        ns.KeepAlphaFast(frame, 0)
        for _, part in ipairs(inside) do pcall(part.SetAlpha, part, 0) end
        insideOf[frame] = inside
    else
        ns.KeepAlphaFast(frame, nil)
        frame:SetAlpha(1)
        for _, part in ipairs(insideOf[frame] or inside) do pcall(part.SetAlpha, part, 1) end
        insideOf[frame] = nil
    end
end

local function Text(value)
    if type(value) ~= "string" or ns.IsSecret(value) or value == "" then return nil end
    return value
end

---------------------------------------------------------------------------
-- Reading the unit
---------------------------------------------------------------------------
-- The name as players know it: with the title when wanted, and the realm of someone from another realm
local function FullName(unit)
    local db = ns.db
    if db.plateTitles and ns.Yes(UnitIsPlayer(unit)) and UnitPVPName then
        local titled = Text(UnitPVPName(unit))
        if titled then
            local bare, realm = titled:match("^(.-)%-([^%-%s]+)$")      -- a title may come with "-Realm" on
            if bare then return ns.FullName(bare, realm) end
            local _, r = UnitName(unit)
            return ns.FullName(titled, Text(r))
        end
    end
    local name, realm = UnitName(unit)
    if ns.IsSecret(name) and ns.IsTarget(unit) then
        name, realm = UnitName("target")                -- your target's name may be readable where the plate's is not
    end
    if ns.IsSecret(name) then                           -- or by who they are
        local n, r = ns.NameByGUID(unit)
        if n then name, realm = n, r end
    end
    if ns.IsSecret(name) then return name end          -- the game shows it for us (see SetName)
    name = Text(name) or ""
    return ns.FullName(name, Text(realm))
end

-- /cchud names: what the game gives for your target's name, piece by piece (for troubleshooting)
ns.RegisterCommand("names", function()
    if not UnitExists("target") then ns.Say(L["Target something first."]); return end
    local function show(v) if ns.IsSecret(v) then return "(secret)" end return tostring(v) end
    local n, r = UnitName("target")
    print(("  UnitName: %s | %s"):format(show(n), show(r)))
    if UnitPVPName then print("  UnitPVPName: " .. show(UnitPVPName("target"))) end
    local gn, gr = ns.NameByGUID("target")
    print(("  by GUID: %s | %s"):format(show(gn), show(gr)))
    local o = NP.plates and C_NamePlate.GetNamePlateForUnit and NP.byPlate[C_NamePlate.GetNamePlateForUnit("target") or 0]
    if o then print("  on its plate: " .. show(o.name:GetText())) end
    print("  we show: " .. show((U.Info("target"))))
end, "/cchud names", "show what the game gives for your target's name (for troubleshooting)")

-- A name on a font string: a player's class icon, the level, the name, in that order (icon and level only
-- where they are wanted). A name the game keeps secret cannot be joined to other text by us, so the game
-- puts the line together itself.
local function SetName(fs, name, level, mark)
    local front = (mark or "") .. (level and (level .. " ") or "")
    if ns.IsSecret(name) then
        if front == "" or not pcall(fs.SetFormattedText, fs, "%s%s", front, name) then
            pcall(fs.SetText, fs, name)                -- handed to the game as it is: it can show it
        end
        return
    end
    fs:SetText(((front .. (name or "")):gsub("%s+$", "")))
end
NP.SetName = SetName

-- The rank around the name: wings in the classic gold or silver, a skull in front for a boss; and the soft
-- glow of the same colour behind the bar
function NP.ShowRank(o, kind, level)
    local rank = o.hostile and not o.mini and ns.RankOf(kind, level) or nil
    local h = math.ceil(10 * (ns.db.textScale or 1))
    if rank and rank.wings then
        local c = rank.wings
        for _, wing in ipairs({ o.wingL, o.wingR }) do
            wing:SetVertexColor(c[1], c[2], c[3], 1)
            wing:SetSize(h * 2, h)
            wing:ClearAllPoints()
            wing:Show()
        end
        local first = (rank.mark == "skull") and o.mark or o.name
        o.wingL:SetPoint("RIGHT", first, "LEFT", -2, 0)
        o.wingR:SetPoint("LEFT", o.name, "RIGHT", 2, 0)
    else
        o.wingL:Hide()
        o.wingR:Hide()
    end
    if rank and rank.mark == "skull" then
        o.mark:SetVertexColor(rank.color[1], rank.color[2], rank.color[3], 1)
        o.mark:SetSize(h + 2, h + 2)
        o.mark:ClearAllPoints()
        o.mark:SetPoint("RIGHT", o.name, "LEFT", -2, 0)
        o.mark:Show()
    else
        o.mark:Hide()
    end
    if rank and o.bars then
        o.rankGlow:SetVertexColor(rank.glow[1], rank.glow[2], rank.glow[3], 1)
        o.rankGlow:Show()
    else
        o.rankGlow:Hide()
    end
    o.rank = rank
end

-- How visible a plate's name is: hidden on your target's plate when that option is off (on every target
-- alike, whoever it is attacking), and on a mini plate with a bar; shown otherwise
function NP.NameAlpha(o)
    if o.bars and not ns.db.plateTargetName and o.unit and ns.IsTarget(o.unit) then return 0 end
    if o.mini and o.bars then return 0 end          -- a mini plate's bar needs no name (a critter's name stays)
    return 1
end

-- The line under the name: a player's guild, or an NPC's job (<Stable Master>), read from its tooltip's second
-- line; a line with a number in it is the level line, not a job.
local function Subtitle(unit)
    local ok, value = pcall(function()
        if ns.Yes(UnitIsPlayer(unit)) then return GetGuildInfo(unit) end
        local data = C_TooltipInfo and C_TooltipInfo.GetUnit and C_TooltipInfo.GetUnit(unit)
        local line = data and data.lines and data.lines[2]
        local v = line and line.leftText
        if Text(v) and not v:find("%d") then return v end
    end)
    return ok and Text(value) or nil
end
NP.FullName, NP.Subtitle = FullName, Subtitle

---------------------------------------------------------------------------
-- Building
---------------------------------------------------------------------------
local function New(plate)
    local o = CreateFrame("Frame", nil, plate)
    o:SetAllPoints(plate)
    -- the game fades its plate for a unit out of sight (behind a wall, a tree) and back as it walks out: with a
    -- few about, ours flashed with it. Ours keeps its own alpha (UpdateTarget), steady.
    if o.SetIgnoreParentAlpha then pcall(o.SetIgnoreParentAlpha, o, true) end
    o.edge = o:CreateTexture(nil, "BACKGROUND")
    o.edge:SetTexture(ns.media.soft)
    o.edge:SetVertexColor(1, 1, 1, 0.7)
    o.name = ns.FontString(o, 10, "CENTER")
    o.sub = ns.FontString(o, 8, "CENTER")
    o.sub:SetTextColor(unpack(C.muted))
    o.health = ns.CreateBar(o, W, H)
    o.health:SetPoint("CENTER", o, "CENTER", 0, 0)
    o.edge:SetPoint("TOPLEFT", o.health, "TOPLEFT", -12, 10)
    o.edge:SetPoint("BOTTOMRIGHT", o.health, "BOTTOMRIGHT", 12, -10)
    o.edge:Hide()
    o.percent = ns.FontString(o.health.over, 7, "RIGHT")      -- small: the bar is not tall
    o.percent:SetPoint("RIGHT", o.health, "RIGHT", -4, 0)
    o.power = ns.CreateBar(o, W - 12, 2, { square = true })
    o.power:SetPoint("TOP", o.health, "BOTTOM", 0, -2)
    o.mark = o:CreateTexture(nil, "OVERLAY")              -- a boss's skull, in front of the name
    o.mark:SetTexture(ns.media.skull)
    o.mark:SetSize(14, 14)
    o.mark:Hide()
    o.wingL = o:CreateTexture(nil, "ARTWORK")            -- the classic rank flourish around the name
    o.wingL:SetTexture(ns.media.wing)
    o.wingR = o:CreateTexture(nil, "ARTWORK")
    o.wingR:SetTexture(ns.media.wing)
    o.wingR:SetTexCoord(1, 0, 0, 1)
    o.wingL:Hide()
    o.wingR:Hide()
    o.nameGlow = o:CreateTexture(nil, "BACKGROUND")       -- the angry glow behind a name when it is on you
    o.nameGlow:SetTexture(ns.media.soft)
    o.nameGlow:SetBlendMode("ADD")
    o.nameGlow:SetAlpha(0)
    o.rankGlow = o:CreateTexture(nil, "BACKGROUND")
    o.rankGlow:SetTexture(ns.media.soft)
    o.rankGlow:SetPoint("TOPLEFT", o.health, "TOPLEFT", -10, 7)
    o.rankGlow:SetPoint("BOTTOMRIGHT", o.health, "BOTTOMRIGHT", 10, -7)
    o.rankGlow:SetAlpha(0.6)
    o.rankGlow:Hide()
    o.castTime = ns.FontString(o, 8, "LEFT")
    o.castTime:SetTextColor(unpack(C.muted))
    o.castTime:Hide()
    o.castSpark = nil
    o.cast = ns.CreateBar(o, W - 10, 6, { square = true })
    o.cast:SetColor(unpack(C.cast))
    o.cast:Hide()
    -- the call to action: a glow around the cast bar that pulses faster as the cast nears its end
    o.castGlow = o:CreateTexture(nil, "BACKGROUND")
    o.castGlow:SetTexture(ns.media.soft)
    o.castGlow:SetBlendMode("ADD")
    o.castGlow:SetPoint("TOPLEFT", o.cast, "TOPLEFT", -16, 12)
    o.castGlow:SetPoint("BOTTOMRIGHT", o.cast, "BOTTOMRIGHT", 16, -12)
    o.castGlow:SetAlpha(0)
    o.castText = ns.FontString(o, 9, "CENTER")
    o.castText:SetPoint("TOP", o.cast, "BOTTOM", 0, -2)
    o.castText:Hide()
    return o
end

-- Where everything sits: name and subtitle above the bars, or just the name and subtitle for a friend at peace
local function Arrange(o)
    o.name:ClearAllPoints()
    o.sub:ClearAllPoints()
    o.cast:ClearAllPoints()
    local hasSub = o.sub:IsShown()
    if o.bars then
        o.health:Show()
        if hasSub then
            o.sub:SetPoint("BOTTOM", o.health, "TOP", 0, 3)
            o.nameAnchor = { "BOTTOM", o.sub, "TOP", 0, 1 }
        else
            o.nameAnchor = { "BOTTOM", o.health, "TOP", 0, 3 }
        end
        o.name:SetPoint(unpack(o.nameAnchor))
        local below = o.power:IsShown() and o.power or o.health
        o.cast:SetPoint("TOP", below, "BOTTOM", 0, -3)
    else
        o.health:Hide()
        o.power:Hide()
        o.nameAnchor = { "CENTER", o, "CENTER", 0, hasSub and 5 or 0 }
        o.name:SetPoint(unpack(o.nameAnchor))
        if hasSub then o.sub:SetPoint("TOP", o.name, "BOTTOM", 0, -1) end
        o.cast:SetPoint("TOP", hasSub and o.sub or o.name, "BOTTOM", 0, -3)
    end
end

---------------------------------------------------------------------------
-- Updating
---------------------------------------------------------------------------
local UpdateTarget          -- (defined below)

local function WantsBars(o)
    if o.hostile then return true end
    return ns.db.plateFriendBars and ns.Yes(UnitAffectingCombat(o.unit))
end

local function UpdatePower(o, instant)
    local cur, max, token = U.Power(o.unit)
    -- only a unit that really has a resource: mana when it has any at all; rage, energy and the rest while
    -- there is some in the bar (monsters that never build it show an empty track otherwise)
    local has = not ns.IsSecret(max) and not ns.IsSecret(cur) and type(max) == "number" and max > 0
        and (token == "MANA" or (type(cur) == "number" and cur > 0))
    local show = o.bars and not o.mini and ns.db.platePower and has
    if show then
        o.power:SetColor(unpack(C.power[token or ""] or C.power.MANA))
        o.power:SetValues(cur, max, instant)
        o.power:Show()
    else
        o.power:Hide()
    end
end

local function UpdateHealth(o, instant)
    local cur, max = U.Health(o.unit)
    local before = o.health:GetFraction()
    local frac = o.health:Update(cur, max, instant)
    -- a hit: only on your target's plate and only right after a cast of yours (anyone else's damage, a guard's,
    -- a pet's, a stranger's, left every plate around shaking), and gentler than the target frame
    if not instant and before and frac and frac < before - 0.001 and ns.Impact and ns.Impact.active
        and GetTime() - (o.lastImpact or 0) > 0.3 and ns.IsTarget(o.unit)
        and ns.Impact.JustYou and ns.Impact.JustYou() then
        ns.Impact:Hit({ frame = o, anchor = o.plate, bar = o.health }, "physical", false, NP.SHAKE)
    end
    o.health:SetColor(ns.UnitFrames.TargetHealthColor(o.unit, frac))
    o.health:SetAbsorb(ns.UnitFrames.Absorb(o.unit))
    o.health:SetExecute(o.bars and not o.mini and ns.UnitFrames.Execute(o.unit, frac) or nil)   -- open to an execute
    if ns.Impact and ns.Impact.Bleed then ns.Impact:Bleed(o.health, o.bars and o.unit or nil, frac) end
    ns.PlateStates:Update(o, frac)
end

local function UpdateAuras(o) ns.PlateStates:Update(o, o.health:GetFraction()) end

-- Its raid mark, at the left end of its bar (a name-only friend: where the bar would be)
-- Its raid mark: left of the bar; on a plate with no bar (a friend's name alone), just before where the line's text
-- starts (and before a class icon there), not at the hidden bar's end, which lay over the level
function NP.Mark(o)
    if not (o and o.unit) then return end
    ns.ShowRaidMark(o, o, o.unit, 20, "RIGHT", o.health, "LEFT", -5, 0)
    local t = rawget(o, "raidMark")
    if not t then return end
    t:ClearAllPoints()
    if o.bars then
        t:SetPoint("RIGHT", o.health, "LEFT", -5, 0)
        return
    end
    local icon = rawget(o, "classTex")
    if icon and icon:IsShown() then
        t:SetPoint("RIGHT", icon, "LEFT", -3, 0)
        return
    end
    local ok, w = pcall(o.name.GetStringWidth, o.name)
    w = (ok and type(w) == "number" and not ns.IsSecret(w)) and w or 0
    t:SetPoint("RIGHT", o.name, "CENTER", -w / 2 - 3, 0)
end

local function UpdateInfo(o)
    local unit = o.unit
    local _, level, kind = U.Info(unit)
    local _, _, isPlayer, attackable = U.Standing(unit)
    o.hostile = attackable and true or false
    -- the name first: if anything below fails, the plate still says who it is (never an empty or stale name)
    local name = FullName(unit)
    SetName(o.name, name)
    o.mini = ns.db.plateMini and not isPlayer and NP.IsMinor(unit, kind) and true or false
    local size = NP.Size()
    local width = W * NP.SIZE_W[size] * (o.mini and MINI_BAR or 1)
    o.health:SetBarWidth(width)
    -- (the compact style narrows a plate, its height stays: only the size chosen sets that)
    local height = math.max(3, math.floor(H * NP.SIZE_H[tonumber(ns.db.plateSize) or 2] + 0.5))
    if o.health.barHeight ~= height then o.health.barHeight = height; o.health:SetHeight(height) end
    o.power:SetBarWidth(width - 12)
    o.cast:SetBarWidth(math.max(40, width - 10))
    o.bars = WantsBars(o)
    name = NP.ShownName(o, name)                                        -- (in full, short, or none: your setting)
    local r, g, b = ns.UnitFrames.TargetColor(unit)
    local mark = NP.ClassMark(unit, isPlayer)                          -- a player's class, in the line itself
    local fcolor                                                        -- the other faction, plainly: its badge big
    if o.bars then                                                      -- beside the bar, or in the name's line
        fcolor = ns.FactionBadge(o.health, unit, o.name)
    else
        ns.FactionBadge(o.health, nil)
        local badge
        badge, fcolor = ns.FactionMark(unit)
        mark = badge .. mark
    end
    o.otherFaction = fcolor and true or false
    local levelText = ns.db.plateLevels and not o.mini and ns.LevelText(level) or nil   -- a small plate: the name only
    if o.hostile then
        local rank = ns.RankOf(kind, level)
        if rank and rank.mark == "skull" then levelText = nil end      -- the skull says it
        SetName(o.name, name, levelText, mark)
        o.name:SetTextColor(unpack(C.text))
    else
        -- a friend: a player reads icon, level, name like everyone else; an NPC is its name alone
        SetName(o.name, name, ns.Yes(isPlayer) and levelText or nil, mark)
        o.name:SetTextColor(r, g, b)
    end
    -- a player: the name in their class's colour, and where the game keeps the class secret (a battleground's
    -- other side) its icon beside the line all the same, the game drawing both
    if ns.db.classNames and ns.Yes(isPlayer) then ns.ClassNameColor(o.name, unit) end
    ns.SecretClassIcon(o, o.name, unit, ns.db.plateClassIcons and ns.Yes(isPlayer) and not o.mini)
    ns.FactionEdge(o.health, fcolor)                                    -- (the name keeps its colours)
    local sub = ns.db.plateSubtitles and not o.mini and Subtitle(unit) or nil
    if sub then
        o.sub:SetText(isPlayer and ("<" .. sub .. ">") or sub)
        o.sub:Show()
    else
        o.sub:Hide()
    end
    NP.ShowRank(o, kind, level)
    NP.Mark(o)
    UpdateHealth(o, true)
    UpdatePower(o, true)
    Arrange(o)
    UpdateTarget(o)
    NP.ServiceIcon(o, isPlayer)
end

-- A player's class as an icon, friend or enemy: in the name's own line, right against the level ("" when there
-- is none to show)
local CLASS_ICONS = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
function NP.ClassMark(unit, isPlayer)
    if not (ns.db.plateClassIcons and ns.Yes(isPlayer) and CLASS_ICON_TCOORDS) then return "" end
    local ok, _, class = pcall(UnitClass, unit)
    local c = ok and class and not ns.IsSecret(class) and CLASS_ICON_TCOORDS[class]
    if not c then return "" end
    return ("|T%s:0:0:0:0:256:256:%d:%d:%d:%d|t"):format(CLASS_ICONS, c[1] * 256, c[2] * 256, c[3] * 256, c[4] * 256)
end

-- What an NPC offers, as an icon above its name. First by what the line under its name says it is (the game's own
-- map-tracking icons, one per kind, so a banker never looks like a vendor; a trainer by what it teaches: the
-- profession's icon, or the class's); otherwise the game's interaction
-- icon (the one by the cursor). It sits on a frame of its own, so it shows even while a townsperson's plate
-- waits until you point at it.
local TRACKING = "Interface\\Minimap\\Tracking\\"
-- kind: words that name it (lower case; English and the main European languages), and its icon
NP.SERVICES = {
    { "guildbank", { "guild bank", "guild vault", "gildenbank", "banque de guilde", "banco de hermandad", "banca di gilda" }, "Banker" },
    { "bank", { "banker", "bankier", "banquier", "banquero", "banchiere", "banqueiro", "банкир" }, "Banker" },
    { "auction", { "auction", "auktion", "enchères", "subastador", "banditore", "leiloeiro", "аукцион" }, "Auctioneer" },
    { "flight", { "flight master", "gryphon master", "wind rider master", "hippogryph master", "bat handler",
                  "flugmeister", "maître de vol", "maestro de vuelo", "maestro di volo", "mestre de voo" }, "FlightMaster" },
    { "inn", { "innkeeper", "gastwirt", "aubergiste", "tabernero", "locandiere", "estalajadeiro", "трактирщик" }, "Innkeeper" },
    { "stable", { "stable master", "stallmeister", "maître des écuries", "maestro de establos", "mastro di stalla" }, "StableMaster" },
    { "battle", { "battlemaster", "kampfmeister", "maître de guerre", "maestro de batalla" }, "BattleMaster" },
    { "poison", { "poison", "gift", "veneno", "veleni" }, "Poisons" },
    { "ammo", { "bowyer", "gunsmith", "arrows", "bullets", "ammunition", "munition", "bogner", "flechas" }, "Ammunition" },
    { "reagent", { "reagent", "reagenz", "composants", "componentes", "reagenti" }, "Reagents" },
    { "food", { "food", "drink", "baker", "butcher", "grocer", "nahrung", "nourriture", "comida", "cibo" }, "Food" },
    { "repair", { "armorsmith", "weaponsmith", "blacksmithing supplies", "armor", "weapon", "rüstung", "waffe",
                  "armurier", "armero", "armaiolo" }, "Repair" },
    { "trainer", { "trainer", "lehrer", "maître", "instructor", "istruttore", "instrutor", "учитель" }, "Profession" },
}

-- Trainers wear what they teach. A profession's trainer has that profession's own icon (the game's: asked for
-- by the profession's spell, with the usual icon file to fall back on); a class trainer has the class's icon.
-- A profession is known by its English words and by its name in your language (the spell's name).
-- { kind, the icon's file, the profession's spell, words }
NP.PROFESSIONS = {
    { "blacksmithing", "Trade_BlackSmithing", 2018, { "blacksmith" } },
    { "leatherworking", "Trade_LeatherWorking", 2108, { "leatherwork" } },
    { "tailoring", "Trade_Tailoring", 3908, { "tailor" } },
    { "alchemy", "Trade_Alchemy", 2259, { "alchem" } },
    { "enchanting", "Trade_Engraving", 7411, { "enchant" } },
    { "engineering", "Trade_Engineering", 4036, { "engineer" } },
    { "jewelcrafting", "INV_Misc_Gem_01", 25229, { "jewelcraft" } },
    { "inscription", "INV_Inscription_Tradeskill01", 45357, { "inscription", "scribe" } },
    { "herbalism", "Trade_Herbalism", 2366, { "herbalis" } },
    { "mining", "Trade_Mining", 2575, { "mining", "miner" } },
    { "skinning", "INV_Misc_Pelt_Wolf_01", 8613, { "skinn" } },
    { "cooking", "INV_Misc_Food_15", 2550, { "cook" } },
    { "fishing", "Trade_Fishing", 7620, { "fish" } },
    { "firstaid", "Spell_Holy_SealOfSacrifice", 3273, { "first aid", "physician", "trauma surgeon" } },
}
local SELLS = { "suppl", "vendor", "merchant", "goods", "trade" }        -- (somebody who sells for it, not teaches)
local TEACHES = { "trainer", "lehrer", "maître", "instructor", "istruttore", "instrutor", "учитель" }
local CLASS_WORDS = { WARRIOR = "warrior", PALADIN = "paladin", HUNTER = "hunter", ROGUE = "rogue", PRIEST = "priest",
                      SHAMAN = "shaman", MAGE = "mage", WARLOCK = "warlock", DRUID = "druid", DEATHKNIGHT = "death knight",
                      MONK = "monk", DEMONHUNTER = "demon hunter", EVOKER = "evoker" }

local function Has(text, words)
    for _, word in ipairs(words) do
        if word ~= "" and text:find(word, 1, true) then return true end
    end
    return false
end

local profWords, classWords
local function Learn()
    profWords, classWords = {}, {}
    local get = (C_Spell and C_Spell.GetSpellName) or GetSpellInfo
    for i, p in ipairs(NP.PROFESSIONS) do
        local words = {}
        for _, w in ipairs(p[4]) do words[#words + 1] = w end
        if get then
            local ok, name = pcall(get, p[3])
            if ok and type(name) == "string" and not ns.IsSecret(name) and #name >= 4 then
                name = name:lower()
                words[#words + 1] = name
                -- (a language that bends the word inside a title, "Angeln" in "Angellehrer": its stem as well)
                if #name >= 6 then words[#words + 1] = name:sub(1, #name - 1) end
            end
        end
        profWords[i] = words
    end
    for token, english in pairs(CLASS_WORDS) do
        local words = { english }
        for _, list in ipairs({ LOCALIZED_CLASS_NAMES_MALE, LOCALIZED_CLASS_NAMES_FEMALE }) do
            local name = type(list) == "table" and list[token]
            if type(name) == "string" and name ~= "" then words[#words + 1] = name:lower() end
        end
        classWords[#classWords + 1] = { token = token, words = words, long = #english }
    end
    table.sort(classWords, function(a, b) return a.long > b.long end)    -- "demon hunter" before "hunter"
end

-- What a trainer teaches, by the line under the name: the kind, its icon, and (a class) where on the sheet of
-- class icons it is. nil for anybody else.
function NP.TrainerKind(text)
    if Has(text, SELLS) then return nil end
    if not profWords then Learn() end
    for i, p in ipairs(NP.PROFESSIONS) do
        if Has(text, profWords[i]) then
            local icon
            local tex = (C_Spell and C_Spell.GetSpellTexture) or GetSpellTexture
            if tex then
                local ok, found = pcall(tex, p[3])
                if ok and (type(found) == "number" or type(found) == "string") and not ns.IsSecret(found) then icon = found end
            end
            return p[1], icon or ("Interface\\Icons\\" .. p[2]), { 0.08, 0.92, 0.08, 0.92 }
        end
    end
    if Has(text, TEACHES) and CLASS_ICON_TCOORDS then
        for _, c in ipairs(classWords) do
            if CLASS_ICON_TCOORDS[c.token] and Has(text, c.words) then
                return "class", "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES", CLASS_ICON_TCOORDS[c.token]
            end
        end
    end
    return nil
end

-- The kind of service in the line under an NPC's name, its icon, and (some icons) the part of the file to show
-- (nil when it says none). named: the text is the NPC's own name, where only the plain kinds are looked for.
function NP.ServiceKind(subtitle, named)
    if type(subtitle) ~= "string" or ns.IsSecret(subtitle) then return nil end
    local text = subtitle:lower()
    if not named then
        local kind, icon, coords = NP.TrainerKind(text)
        if kind then return kind, icon, coords end
    end
    for _, s in ipairs(NP.SERVICES) do
        for _, word in ipairs(s[2]) do
            if text:find(word, 1, true) then return s[1], TRACKING .. s[3] end
        end
    end
end

-- The game's interaction icon has a grey twin for "too far away to use" (a grey bag over a vendor across the
-- square). Over a nameplate the icon says what the NPC is, not whether you can reach it from here: the grey
-- twin is swapped for the plain one (the brown bag). Its name is the plain one's with "unable" in it, as an
-- atlas ("Cursor_unablebuy_32") or as a file ("Interface\Cursor\UnableBuy"). Returns what it found and what
-- it set (nil when it was the plain one already).
NP.cursorsSeen = {}
function NP.PlainCursor(tex)
    local function Without(name) return (name:gsub("[Uu][Nn][Aa][Bb][Ll][Ee]", "")) end
    local okA, atlas = pcall(function() return tex.GetAtlas and tex:GetAtlas() end)
    if okA and type(atlas) == "string" and atlas ~= "" and not ns.IsSecret(atlas) then
        local plain = Without(atlas)
        if plain == atlas then return atlas, nil end
        local known = true
        if C_Texture and C_Texture.GetAtlasInfo then
            local ok, info = pcall(C_Texture.GetAtlasInfo, plain)
            known = ok and info ~= nil
        end
        if known and tex.SetAtlas then
            tex:SetAtlas(plain)
            return atlas, plain
        end
        return atlas, nil
    end
    local okP, path = pcall(function()
        return (tex.GetTextureFilePath and tex:GetTextureFilePath()) or (tex.GetTexture and tex:GetTexture())
    end)
    if okP and type(path) == "string" and path ~= "" and not ns.IsSecret(path) then
        local plain = Without(path)
        if plain == path then return path, nil end
        if tex:SetTexture(plain) == false then               -- (no such file here: the grey one is better than none)
            tex:SetTexture(path)
            return path, nil
        end
        return path, plain
    end
    return okP and path or nil, nil
end

function NP.ServiceIcon(o, isPlayer)
    if not o.service then
        o.service = CreateFrame("Frame", nil, o.plate)
        o.service:SetSize(22, 22)
        if o.service.SetIgnoreParentAlpha then pcall(o.service.SetIgnoreParentAlpha, o.service, true) end
        o.service.icon = o.service:CreateTexture(nil, "OVERLAY")
        o.service.icon:SetAllPoints(o.service)
    end
    local s = o.service
    if s:GetParent() ~= o.plate and s.SetParent then s:SetParent(o.plate) end
    s:ClearAllPoints()
    s:SetPoint("BOTTOM", o.name, "TOP", 0, 2)
    local show, kind = false, nil
    if ns.db.plateServiceIcons and not o.hostile and not isPlayer then
        local icon, coords
        kind, icon, coords = NP.ServiceKind(Subtitle(o.unit))
        if not icon then                                 -- "Auctioneer Tricket": the job in the name itself
            local okN, name = pcall(UnitName, o.unit)
            if okN then kind, icon, coords = NP.ServiceKind(name, true) end
        end
        if icon then
            s.icon:SetTexture(icon)
            if coords then s.icon:SetTexCoord(unpack(coords)) else s.icon:SetTexCoord(0, 1, 0, 1) end
            show = true
        elseif SetUnitCursorTexture then
            local ok, has = pcall(SetUnitCursorTexture, s.icon, o.unit)
            show = ok and has and not ns.IsSecret(has) and true or false
            if show then
                local okC, was, now = pcall(NP.PlainCursor, s.icon)
                local key = okC and tostring(was) or "?"
                if not NP.cursorsSeen[key] then              -- (each kind once, for the report)
                    NP.cursorsSeen[key] = true
                    ns.Note("plates: the game's interaction icon %s%s", key, (okC and now) and (" shown as " .. tostring(now)) or "")
                end
            end
        end
    end
    if show then s:Show() else s:Hide() end
    o.hasService, o.serviceKind = show, kind
end

local function CastOnUpdate(bar)
    local now = GetTime()
    local look = bar.look                        -- a channel or a gathering: little bursts while it runs
    if look and look.every and ns.db.impactFx and ns.Impact and (not bar.nextFx or now >= bar.nextFx) then
        bar.nextFx = now + look.every
        ns.Impact:Burst(bar, look, 0.5)
    end
    if now >= bar.stop and bar.estimated then            -- our own guess of its length ran out: full, until it ends
        bar.fill:SetValue(1)
        NP.CastAlert(bar, now, 1)
        return
    end
    if now >= bar.stop then
        bar:SetScript("OnUpdate", nil)
        bar:Hide()
        bar.text:Hide()
        bar.time:Hide()
        if bar.glow then bar.glow:SetAlpha(0) end
        bar:SetScale(1)
        bar.casting = nil
        if bar.art then bar.art:Stop() end
        return
    end
    local p = (now - bar.start) / (bar.stop - bar.start)
    bar.fill:SetValue(bar.channel and (1 - p) or p)
    if bar.art then bar.art:Update(bar.channel and (1 - p) or p, p, now) end
    if not bar.estimated then bar.time:SetText(("%.1f"):format(bar.stop - now)) end
    -- about to land: the bar brightens, so an interrupt can be timed
    bar.fill:SetAlpha(p > 0.8 and (0.75 + 0.25 * math.sin(now * 30)) or 1)
    NP.CastAlert(bar, now, p)
end

-- The loud part: a swell when the cast starts, then a glow that pulses faster and brighter as it nears the end.
-- Shielded casts (that cannot be interrupted) stay calm.
function NP.CastAlert(bar, now, p)
    local glow = bar.glow
    if not glow then return end
    if not ns.db.plateCastAlert or bar.shielded then
        glow:SetAlpha(0)
        bar:SetScale(1)
        return
    end
    local since = now - (bar.alertStart or now)
    bar:SetScale(since < 0.25 and (1 + 0.5 * (1 - since / 0.25)) or 1)
    local speed = (p or 0) > 0.7 and 16 or 7
    glow:SetAlpha(0.45 + 0.35 * math.abs(math.sin(now * speed)) + ((p or 0) > 0.7 and 0.2 or 0))
end

-- A cast ended in front of you: interrupted (it shatters, red) or landed (a burst in its own colours). The
-- bar lingers a moment so you see which.
local LINGER = 0.45
local SHATTER = { color = { 1, 0.35, 0.3 }, fx = { kind = "sparks", tex = "spark", count = 8, size = 10, life = 0.35, speed = 170 } }
local LANDS = { color = C.cast, fx = { kind = "rays", tex = "spark", count = 4, size = 12, life = 0.4, speed = 45 } }

local function HideCast(o)
    local bar = o.cast
    bar:SetScript("OnUpdate", nil)
    bar:Hide()
    o.castText:Hide()
    o.castTime:Hide()
    if o.castIcon then o.castIcon:Hide(); o.castIconBack:Hide() end
    o.castGlow:SetAlpha(0)
    bar:SetScale(1)
    bar.casting, bar.linger, bar.look, bar.nextFx = nil, nil, nil, nil
    if bar.art then bar.art:Stop() end
end

function NP.CastEnd(o, how)
    local bar = o.cast
    if not (bar.casting and o.bars) then return false end
    bar.casting = nil
    bar.linger = GetTime() + LINGER
    o.castGlow:SetAlpha(0)
    bar:SetScale(1)
    o.castTime:Hide()
    local fx = ns.db.impactFx and ns.Impact
    if how == "interrupted" then
        bar:SetColor(unpack(C.danger))
        bar.fill:SetValue(1)
        bar:Flash(0.6, { 1, 0.3, 0.25 }, 3)
        o.castText:SetText(L["Interrupted"])
        if fx then ns.Impact:Burst(bar, SHATTER, 1) end
    else
        bar.fill:SetValue(bar.channel and 0 or 1)
        bar:Flash(0.3)
        local land = bar.look and bar.look.land
        if fx then ns.Impact:Burst(bar, (land and land.fx) and land or LANDS, 0.8) end
    end
    if bar.art then bar.art:Finish(how ~= "interrupted", GetTime()) end
    bar:SetScript("OnUpdate", function(b)
        local now = GetTime()
        if now >= (b.linger or 0) then HideCast(o) elseif b.art then b.art:Update(nil, nil, now) end
    end)
    return true
end

-- Who a cast is aimed at, for the line beside the spell's name. The game does not say whom a spell is cast
-- at, only whom the caster has targeted, and those differ when it matters: a priest with you targeted who
-- heals is not healing you. A heal cast with an enemy targeted is for that enemy's target, the one it is
-- fighting (the priest itself when you are on the priest, the rifleman when you are on the rifleman), so
-- that is who is named. When that one is no friend of the caster's either, nothing is said.
function NP.CastAim(unit, look)
    local t = unit .. "target"
    local okN, name = pcall(UnitName, t)
    if not okN or name == nil then return nil end
    if look and look.kind == "heal" then
        local function Foe(who)
            local okA, foe = pcall(UnitCanAttack, unit, who)
            return okA and not ns.IsSecret(foe) and foe and true or false
        end
        if Foe(t) then
            local tt = t .. "target"
            local okT, theirs = pcall(UnitName, tt)
            if okT and theirs ~= nil and not Foe(tt) then return theirs end
            return nil
        end
    end
    return name
end

local function UpdateCast(o)
    local bar = o.cast
    bar.text, bar.time, bar.glow = o.castText, o.castTime, o.castGlow
    if not o.castIcon then                             -- the spell's icon, at the left end of the bar
        o.castIconBack = o:CreateTexture(nil, "ARTWORK", nil, 1)
        o.castIconBack:SetColorTexture(0.02, 0.03, 0.06, 0.95)
        o.castIconBack:SetPoint("RIGHT", bar, "LEFT", -3, 0)
        o.castIconBack:SetSize(16, 16)
        o.castIcon = o:CreateTexture(nil, "ARTWORK", nil, 2)
        o.castIcon:SetPoint("CENTER", o.castIconBack, "CENTER", 0, 0)
        o.castIcon:SetSize(14, 14)
        o.castIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        o.castIcon:Hide()
        o.castIconBack:Hide()
    end
    if not bar.spark then
        bar.spark = bar.over:CreateTexture(nil, "OVERLAY")
        bar.spark:SetTexture(ns.media.spark)
        bar.spark:SetBlendMode("ADD")
        bar.spark:SetSize(10, 10)
        bar.spark:SetPoint("CENTER", bar.fill:GetStatusBarTexture(), "RIGHT", 0, 0)
        o.castTime:SetPoint("LEFT", bar, "RIGHT", 4, 0)
    end
    local name, startMS, endMS, channel, shielded = U.Cast(o.unit)
    if not name or not o.bars then
        if bar.linger and o.bars and GetTime() < bar.linger then return end    -- still showing how it ended
        HideCast(o)
        return
    end
    local fresh = not bar.casting
    bar.casting, bar.linger = true, nil
    bar.shielded = (not ns.IsSecret(shielded) and shielded) and true or false
    if fresh then
        local cname, spellID, trade, icon = ns.CastLook.Casting(o.unit)
        bar.look = cname and ns.CastLook.Look(cname, spellID, trade) or nil
        bar.nextFx = nil
        bar.art = bar.art or ns.CastArt.Attach(bar, 0.65, true)      -- the lighter show (CastArt.lua)
        bar.art:Start(bar.look)
        if icon and pcall(o.castIcon.SetTexture, o.castIcon, icon) then
            o.castIcon:SetDesaturated(bar.shielded)          -- cannot be interrupted: greyed
            o.castIcon:Show()
            o.castIconBack:Show()
        else
            o.castIcon:Hide()
            o.castIconBack:Hide()
        end
        bar.alertStart = GetTime()
        if ns.db.plateCastAlert and not bar.shielded then
            local c = bar.look and bar.look.color or C.cast
            o.castGlow:SetVertexColor(c[1], c[2], c[3], 1)
            bar:Flash(0.5, { 1, 0.85, 0.3 }, 2.5)        -- the cast starts with a bang
        end
    end
    local aim = ns.db.plateCastTarget and NP.CastAim(o.unit, bar.look) or nil
    local ok = pcall(function()
        if aim then o.castText:SetFormattedText("%s  |cffb8c2db>|r %s", name, aim)
        else o.castText:SetFormattedText("%s", name) end
    end)
    if not ok then o.castText:SetText(Text(name) or "") end
    o.castText:Show()
    bar:SetColor(unpack(bar.shielded and C.shielded or (bar.look and bar.look.color) or C.cast))
    bar.fill:SetMinMaxValues(0, 1)
    bar.fill:SetAlpha(1)
    bar:Show()
    if ns.IsSecret(startMS) or ns.IsSecret(endMS) or not startMS or not endMS or endMS <= startMS then
        -- the game keeps the times to itself: its own timer runs the bar, and the alert pulses without them;
        -- with no timer either, the bar fills over the spell's own length from when we saw it begin
        o.castTime:Hide()
        bar.estimated = nil
        if fresh then bar.seen = GetTime() end
        if not ns.GameCastTimer(bar, o.unit, channel) then
            local length = (not channel) and ns.CastLength(o.unit)
            if length then
                bar.start, bar.stop, bar.channel, bar.estimated = bar.seen or GetTime(), (bar.seen or GetTime()) + length, false, true
                bar:SetScript("OnUpdate", CastOnUpdate)
                CastOnUpdate(bar)
                return
            end
            bar.fill:SetValue(1)                               -- nothing known: dim, it only says "casting"
            bar.fill:SetAlpha(0.35)
        end
        if bar.art then bar.art:Stop() end
        bar:SetScript("OnUpdate", function(b)
            ns.CastTick(b)                                     -- (on the cast's own duration: where it is now)
            NP.CastAlert(b, GetTime(), nil)
        end)
        NP.CastAlert(bar, GetTime(), nil)
        return
    end
    bar.estimated, bar.duration = nil, nil
    o.castTime:Show()
    bar.start, bar.stop, bar.channel = startMS / 1000, endMS / 1000, channel and true or false
    bar:SetScript("OnUpdate", CastOnUpdate)
    CastOnUpdate(bar)
end

-- Is this unit the one you point at (the cursor, or the controller's soft targeting)?
local POINTED = { "mouseover", "softinteract", "softfriend" }
local function Pointed(unit)
    for _, token in ipairs(POINTED) do
        local ok, same = pcall(UnitIsUnit, unit, token)
        if ok and same and not ns.IsSecret(same) then return true end
    end
    return false
end

-- A friendly NPC's plate waits until you point at it, when that option is on (never your target's, and never
-- one with bars up for a fight)
function NP.Waits(o)
    if o.object and not ns.db.plateObjects then return true end     -- a thing, not someone: bare unless asked for
    if not ns.db.plateHoverNPC or o.hostile or o.bars then return false end
    local ok, isPlayer = pcall(UnitIsPlayer, o.unit)
    if ok and isPlayer and not ns.IsSecret(isPlayer) then return false end
    if ns.IsTarget(o.unit) then return false end
    return not Pointed(o.unit)
end

function UpdateTarget(o)
    local isTarget = ns.IsTarget(o.unit)
    local any = UnitExists("target")
    o:SetScale((o.mini and MINI_SCALE or 1) * (isTarget and TARGET_SCALE or 1))
    -- your target's name is on the target frame already: its plate may leave it out
    if not o.spawn then
        local a = NP.NameAlpha(o)
        o.name:SetAlpha(a)
        o.sub:SetAlpha(a)
    end
    o.waiting = NP.Waits(o)
    if o.waiting then o:SetAlpha(0) else o:SetAlpha((isTarget or not any) and 1 or OTHER_ALPHA) end
    if o.service then o.service:SetAlpha(1) end    -- (steady too, and still saying what it is while the plate waits)
    if isTarget and o.bars then o.edge:Show() else o.edge:Hide() end
end

local function Full(o)
    UpdateInfo(o)
    UpdateCast(o)
    UpdateTarget(o)
    ns.PlateStates:Quest(o)
end
NP.Full = Full

-- Do we style this unit's plate? Enemies always; friends unless they are left to the game (the option)
function NP.Ours(unit)
    if not ns.db.plateFriendsGame then return true end
    return ns.Yes(UnitCanAttack("player", unit))
end

-- Never a stale plate: the game reuses plates for other units, so whatever happens while reading the new one,
-- nothing of the last one stays on it.
function NP:Add(unit)
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if not plate then return end
    local before = self.plates[unit]
    if before and before.plate ~= plate then self:Remove(unit) end   -- the token moved to another plate
    local o = self.byPlate[plate]
    if plate.IsForbidden and plate:IsForbidden() then           -- the game's own (friends in a dungeon): not ours
        if o then
            if o.unit and self.plates[o.unit] == o then self:Remove(o.unit) else o:Hide() end
        end
        return
    end
    if not NP.Ours(unit) then                                    -- a friend, left to the game (the option)
        if o and o.unit and self.plates[o.unit] == o then self:Remove(o.unit) end
        return
    end
    if not o then
        o = New(plate)
        self.byPlate[plate] = o
    end
    if o.unit and o.unit ~= unit and self.plates[o.unit] == o then self:Remove(o.unit) end
    o.unit, o.plate = unit, plate
    o.guid = ns.GUID(unit)
    -- the controller's soft targeting gives a plate to things too (ore, a chest, a plaque): known by their GUID
    o.object = (type(o.guid) == "string" and o.guid:find("^GameObject%-")) and true or false
    self.plates[unit] = o
    if o.guid then self.byGuid[o.guid] = o end
    pcall(o.name.SetText, o.name, "")        -- blank until this unit is read: never the last one's name
    for _, native in ipairs(Natives(plate)) do HideNative(native, true) end
    o:Show()
    o.auraFresh = true                       -- the same token may now be another unit: the game's rows look again
    local ok, err = pcall(Full, o)
    if not ok then ns.Error(err) end
    ns.PlateStates:Spawn(o)
end

function NP:Remove(unit)
    local o = self.plates[unit]
    if not o then return end
    self.plates[unit] = nil
    o:Hide()                         -- first: whatever follows, the plate never shows this unit again
    if o.guid and self.byGuid[o.guid] == o then self.byGuid[o.guid] = nil end
    o.guid = nil
    pcall(function()
        if ns.Impact then ns.Impact:Stop(o) end
        ns.PlateStates:Stop(o)
        HideCast(o)                  -- the game reuses this plate for another unit: nothing of this one's cast stays
        if o.service then o.service:Hide() end
    end)
    for _, native in ipairs(Natives(o.plate)) do HideNative(native, false) end
end

-- Every plate we hold still on the unit it was made for? (A missed event, a zone change.) Those that are not
-- are dropped, and the ones on screen we do not hold yet are taken up.
-- Only what is certain counts as stale: the unit is gone, or its plate is another one now. (The game does not
-- always hand out a friend's plate when asked; that is no reason to drop it.)
NP.dropped = {}
function NP:Resync()
    local stale = {}
    for unit, o in pairs(self.plates) do
        local why
        local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
        if not UnitExists(unit) then why = "gone"
        elseif ok and plate ~= nil and plate ~= o.plate then why = "moved"
        elseif not NP.Ours(unit) then why = "left to the game" end
        if why then stale[#stale + 1] = unit; table.insert(NP.dropped, 1, unit .. ": " .. why) end
    end
    while #NP.dropped > 10 do table.remove(NP.dropped) end
    for _, unit in ipairs(stale) do self:Remove(unit) end
    if C_NamePlate.GetNamePlates then
        for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
            local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
            if type(unit) == "string" and not ns.IsSecret(unit) and not self.plates[unit] then self:Add(unit) end
        end
    end
end

function NP:Refresh()
    self:Resync()                                -- friends handed to the game, or taken back
    for _, o in pairs(self.plates) do Full(o) end
end

-- /cchud plates: every plate on screen, and whether it wears our look (for troubleshooting). Kept in the saved
-- settings too, so it can be read after a reload.
function NP.Report()
    local rows = {}
    local function yes(v) if ns.IsSecret(v) then return "secret" end return v and "yes" or "no" end
    rows[#rows + 1] = ("active: %s, rival: %s, game's friendly plates: %s"):format(yes(NP.active),
        NP:Rival() or "none", yes(ns.db.plateFriendsGame))
    local cvar = NP.FriendsCVar()
    local changed = {}
    for name, rec in pairs(ns.db.plateInsideWas or {}) do changed[#changed + 1] = ("%s (was %s, set %s)"):format(name, rec.was, rec.set) end
    rows[#rows + 1] = ("where the game keeps friendly nameplates to itself: %s (it said so here: %s), in a fight: %s, the game's setting for friendly nameplates: %s = %s, changed by us in here: %s"):format(
        yes(NP.Inside()), yes(NP.kept), yes(NP.fighting), tostring(cvar), tostring(cvar and GetCVar(cvar)),
        #changed > 0 and table.concat(changed, ", ") or "nothing")
    local settings = NP.Settings()
    rows[#rows + 1] = "the game's nameplate settings: " .. (#settings > 0 and table.concat(settings, ", ") or "not listed by this client")
    -- plates the game keeps to itself (friends in a dungeon) are only listed when asked for by name
    local hidden, total = 0, 0
    pcall(function()
        for _, plate in ipairs(C_NamePlate.GetNamePlates(true) or {}) do
            total = total + 1
            if plate.IsForbidden and plate:IsForbidden() == true then hidden = hidden + 1 end
        end
    end)
    rows[#rows + 1] = ("plates on screen: %d, of which the game keeps to itself: %d; the game showed its own drawing again %d times (each put away at once)"):format(total, hidden, ns.alphaFixes or 0)
    local seen = {}
    for _, plate in ipairs(C_NamePlate.GetNamePlates and C_NamePlate.GetNamePlates() or {}) do
        local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
        local o = NP.byPlate[plate]
        seen[plate] = true
        rows[#rows + 1] = ("%s: forbidden %s, enemy %s, ours %s, shown %s, held %s"):format(tostring(unit),
            yes(plate.IsForbidden and plate:IsForbidden()), yes(unit and UnitCanAttack("player", unit)),
            yes(o ~= nil), yes(o and o:IsShown()), yes(o and unit and NP.plates[unit] == o))
    end
    for unit, o in pairs(NP.plates) do
        if not seen[o.plate] then rows[#rows + 1] = unit .. ": held, but the game did not list its plate" end
    end
    for _, d in ipairs(NP.dropped) do rows[#rows + 1] = "dropped " .. d end
    return rows
end

ns.RegisterCommand("plates", function()
    local rows = NP.Report()
    ns.db.plateReport = rows
    for _, r in ipairs(rows) do print("  " .. r) end
end, "/cchud plates", "list the nameplates on screen and whether they wear our look (for troubleshooting)")

local UNIT_EVENTS = {
    UNIT_HEALTH = UpdateHealth, UNIT_MAXHEALTH = UpdateHealth, UNIT_FACTION = Full,
    UNIT_ABSORB_AMOUNT_CHANGED = UpdateHealth,
    UNIT_NAME_UPDATE = Full, UNIT_LEVEL = Full, UNIT_CLASSIFICATION_CHANGED = Full,
    UNIT_POWER_UPDATE = UpdatePower, UNIT_MAXPOWER = UpdatePower, UNIT_DISPLAYPOWER = UpdatePower,
    UNIT_AURA = UpdateAuras, UNIT_THREAT_SITUATION_UPDATE = UpdateAuras, UNIT_THREAT_LIST_UPDATE = UpdateAuras,
    UNIT_SPELLCAST_START = UpdateCast, UNIT_SPELLCAST_STOP = UpdateCast, UNIT_SPELLCAST_FAILED = UpdateCast,
    UNIT_SPELLCAST_INTERRUPTED = function(o) NP.CastEnd(o, "interrupted") end,
    UNIT_SPELLCAST_SUCCEEDED = function(o) NP.CastEnd(o, "landed") end, UNIT_SPELLCAST_DELAYED = UpdateCast,
    UNIT_SPELLCAST_CHANNEL_START = UpdateCast, UNIT_SPELLCAST_CHANNEL_STOP = UpdateCast,
    UNIT_SPELLCAST_CHANNEL_UPDATE = UpdateCast,
}

local events = CreateFrame("Frame")
local OnEvent = ns.Protect(function(_, event, unit)
    if event == "NAME_PLATE_UNIT_ADDED" then
        NP:Add(unit)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        NP:Remove(unit)
    elseif event == "PLAYER_ENTERING_WORLD" then            -- a new zone or instance: start clean
        NP:Resync()
    elseif event == "PLAYER_TARGET_CHANGED" or event == "UPDATE_MOUSEOVER_UNIT"
        or event == "PLAYER_SOFT_INTERACT_CHANGED" or event == "PLAYER_SOFT_FRIEND_CHANGED" then
        for _, o in pairs(NP.plates) do UpdateTarget(o) end
    elseif event == "QUEST_LOG_UPDATE" or event == "UNIT_QUEST_LOG_CHANGED" then
        for _, o in pairs(NP.plates) do ns.PlateStates:Quest(o) end
    elseif event == "RAID_TARGET_UPDATE" then
        for _, o in pairs(NP.plates) do NP.Mark(o) end
    else
        local o = unit and NP.plates[unit]
        if o then UNIT_EVENTS[event](o) end
    end
end)

-- A few times a second: friends entering or leaving a fight; every second, no stale plate
local since, sinceSync = 0, 0
local OnUpdate = ns.Protect(function(_, dt)
    since, sinceSync = since + dt, sinceSync + dt
    if since < LOOK_EVERY then return end
    since = 0
    if sinceSync >= 1 then sinceSync = 0; NP:Resync() end
    for _, o in pairs(NP.plates) do
        if WantsBars(o) ~= o.bars then Full(o) else UpdateAuras(o) end
        if ns.db.plateHoverNPC and not o.hostile then UpdateTarget(o) end   -- pointing away has no event
    end
end)

function NP:Apply(run)
    local want = run and ns.db.nameplates and not self:Rival() and C_NamePlate ~= nil and true or false
    if want == self.active then
        if want then self:Refresh() end           -- a setting of ours changed
        return
    end
    self.active = want
    if want then
        for event in pairs(UNIT_EVENTS) do pcall(events.RegisterEvent, events, event) end
        for _, e in ipairs({ "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "PLAYER_TARGET_CHANGED",
                             "QUEST_LOG_UPDATE", "UNIT_QUEST_LOG_CHANGED", "UPDATE_MOUSEOVER_UNIT",
                             "PLAYER_SOFT_INTERACT_CHANGED", "PLAYER_SOFT_FRIEND_CHANGED", "PLAYER_ENTERING_WORLD",
                             "RAID_TARGET_UPDATE" }) do
            pcall(events.RegisterEvent, events, e)
        end
        events:SetScript("OnEvent", OnEvent)
        events:SetScript("OnUpdate", OnUpdate)
        if C_NamePlate.GetNamePlates then          -- plates that are already on screen
            for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
                local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
                if type(unit) == "string" then self:Add(unit) end
            end
        end
    else
        events:UnregisterAllEvents()
        events:SetScript("OnEvent", nil)
        events:SetScript("OnUpdate", nil)
        local units = {}
        for unit in pairs(self.plates) do units[#units + 1] = unit end
        for _, unit in ipairs(units) do self:Remove(unit) end
    end
end

---------------------------------------------------------------------------
-- Friends inside a dungeon or a raid. In there the game draws the nameplates of friendly players itself and
-- addons may not touch them (no addon can: the choice is the game's full plates, names only, or none). They
-- cannot wear our look, and your party stood out in the game's bars in the middle of ours. The game has
-- options of its own for exactly this, and those are what we use, while you are inside:
--   names only   friendly players show as their name alone, in their class colour, with no bar: which is how
--                our own friendly nameplates look while nothing is going on. And as ours do, they get their
--                bars back for a fight (the game's own bars: that part cannot be ours), when "Bars for friends
--                in a fight" is on. (On to begin with.)
--   hidden       the game's friendly nameplates switched off altogether. (Off to begin with.)
-- They are the game's settings, changed out of combat (the moment a fight starts and the moment it ends still
-- count as that), each put back the way you had it when you leave. One you change yourself while inside is
-- left as you set it.
-- Where: a dungeon, raid or scenario, and anywhere else the game says it is keeping a plate to itself. In
-- the open world and in battlegrounds the plates are ours to dress, and nothing here applies.
---------------------------------------------------------------------------
Setting("plateFriendsInside", "Party nameplates in dungeons: names only", "inside a dungeon or raid the game draws friendly players' nameplates itself and addons may not change them: in there the game's own options are set to show them as class-coloured names without bars, like ours, with the game's bars back while you fight (when bars for friends in a fight are on); all put back when you leave", true)
Setting("plateFriendsHide", "Party nameplates in dungeons: hidden", "inside a dungeon or raid, switch the game's nameplates for friendly players off altogether (and back the way you had them when you leave)", false)
-- What each of the game's settings was before we changed it inside, and what we set it to
ns.RegisterSaved("plateInsideWas", function(old)
    local was = {}
    if type(old) == "table" then
        for cvar, rec in pairs(old) do
            if type(cvar) == "string" and type(rec) == "table" and type(rec.was) == "string" and type(rec.set) == "string" then
                was[cvar] = { was = rec.was, set = rec.set }
            end
        end
    end
    return was
end)
ns.RegisterSaved("plateFriendsWas", function(old) return (old == "0" or old == "1") and old or nil end)   -- (from 1.3.0's first try)

-- The game's setting for the nameplates of friendly players, by the names clients have had for it
local FRIEND_CVARS = { "nameplateShowFriendlyPlayers", "nameplateShowFriends", "nameplateShowFriendlyPlayerUnits" }
function NP.FriendsCVar()
    if not GetCVar then return nil end
    for _, name in ipairs(FRIEND_CVARS) do
        local ok, v = pcall(GetCVar, name)
        if ok and v ~= nil then return name end
    end
    return nil
end

-- The game's own options that make its friendly nameplates look like ours: the name alone, in the class colour
NP.NAMES_ONLY = { { "nameplateShowOnlyNameForFriendlyPlayerUnits", "1" },
                  { "nameplateUseClassColorForFriendlyPlayerUnitNames", "1" } }

-- Every setting of the game's that has to do with showing nameplates, with its value (for troubleshooting:
-- which of them this client has)
function NP.Settings()
    local out = {}
    local list
    if C_Console and C_Console.GetAllCommands then
        local ok, all = pcall(C_Console.GetAllCommands)
        list = ok and all or nil
    elseif ConsoleGetAllCommands then
        local ok, all = pcall(ConsoleGetAllCommands)
        list = ok and all or nil
    end
    for _, c in ipairs(type(list) == "table" and list or {}) do
        local name = type(c) == "table" and c.command
        if type(name) == "string" then
            local low = name:lower()
            if low:find("nameplate") and #out < 120 then
                local ok, v = pcall(GetCVar, name)
                out[#out + 1] = name .. " = " .. tostring(ok and v or "?")
            end
        end
    end
    table.sort(out)
    return out
end

local INSIDE = { party = true, raid = true, scenario = true }
function NP.Inside()
    if NP.kept then return true end                     -- the game said so itself, here
    if not IsInInstance then return false end
    local ok, inside, kind = pcall(IsInInstance)
    return ok and ns.Yes(inside) and INSIDE[kind] or false
end

-- Which of the game's settings we want at which value while inside (setting -> value)
function NP.InsideWants(db)
    local want = {}
    if db.plateFriendsInside then
        for _, pair in ipairs(NP.NAMES_ONLY) do want[pair[1]] = pair[2] end
        -- a fight: their bars back, as on our own friendly plates
        if NP.fighting and db.plateFriendBars then want[NP.NAMES_ONLY[1][1]] = "0" end
    end
    if db.plateFriendsHide then
        local cvar = NP.FriendsCVar()
        if cvar then want[cvar] = "0" end
    end
    return want
end

function NP:FriendsInside(starting)
    -- (never in a fight, then after it; the moment a fight starts is still before it for the game)
    if (InCombatLockdown() and not starting) or not (GetCVar and SetCVar) then return end
    local db = ns.db
    local was = db.plateInsideWas
    if db.plateFriendsWas then                           -- switched off by 1.3.0's first try: ours to put back
        local cvar = NP.FriendsCVar()
        if cvar and not was[cvar] then was[cvar] = { was = db.plateFriendsWas, set = "0" } end
        db.plateFriendsWas = nil
    end
    local on = self.active and not db.plateFriendsGame and NP.Inside()
    local want = on and NP.InsideWants(db) or {}
    for cvar, rec in pairs(was) do                       -- no longer wanted: as you had it
        if want[cvar] == nil then
            if GetCVar(cvar) == rec.set then SetCVar(cvar, rec.was) end      -- (changed by hand meanwhile: left)
            ns.Note("plates: %s as it was (%s)", cvar, rec.was)
            was[cvar] = nil
        end
    end
    for cvar, value in pairs(want) do
        local now = GetCVar(cvar)
        local rec = was[cvar]
        if now == nil then                                                  -- (a client without it: nothing)
        elseif not rec then
            if now ~= value then
                was[cvar] = { was = now, set = value }
                SetCVar(cvar, value)
                ns.Note("plates: inside, the game's %s set to %s (it was %s)", cvar, value, tostring(now))
            end
        elseif rec.set ~= value and now == rec.set then                     -- ours still: the other way for now
            rec.set = value
            SetCVar(cvar, value)
        end
    end
end

local inside = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED",
                     "FORBIDDEN_NAME_PLATE_UNIT_ADDED" }) do
    pcall(inside.RegisterEvent, inside, e)
end
inside:SetScript("OnEvent", ns.Protect(function(_, event)
    if not ns.db then return end
    if event == "PLAYER_ENTERING_WORLD" then
        NP.kept = false                                 -- somewhere new: not known yet
    elseif event == "FORBIDDEN_NAME_PLATE_UNIT_ADDED" then
        if NP.kept then return end
        NP.kept = true                                  -- the game is keeping a plate to itself, right here
        ns.Note("plates: the game keeps a nameplate to itself here")
    elseif event == "PLAYER_REGEN_DISABLED" then
        NP.fighting = true
        NP:FriendsInside(true)
        return
    elseif event == "PLAYER_REGEN_ENABLED" then
        NP.fighting = false
    end
    NP:FriendsInside()
end))

local applyPlates = NP.Apply
function NP:Apply(run)
    applyPlates(self, run)
    self:FriendsInside()
end

ns.RegisterCheck(function(row, run, db)
    local rival = NP:Rival()
    local want = (run and db.nameplates and not rival and C_NamePlate ~= nil) and true or false
    row(want and "nameplates wear our look"
        or (rival and ("nameplates are left to " .. rival) or "nameplates are left alone"), NP.active == want)
end)

ns.RegisterModule("nameplates", NP)
