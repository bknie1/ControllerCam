-- ControllerCam HUD: how a cast looks, by what it is.
-- Your cast bar and the enemies' take their colour and their little effects from the kind of cast:
--   mining        ore orange, chips of stone flying off at every swing
--   herbs         leaf green, motes drifting up
--   skinning      blood red, quick nicks
--   opening       brass, the click of a lock
--   crafting      bronze, sparks off the anvil
--   disenchanting violet, runes turning
--   travel        sky blue, light rising (hearthstone, teleports)
--   mount         dust kicked up
--   lightning     pale blue (lightning bolts and the like: nature by school, but they look like the sky's)
--   roots         the spells that hold a foe in roots
--   a heal        growing green (or the gold of a holy heal), whatever its school
--   a spell       the colour and effects of its school (physical, holy, fire, nature, frost, shadow, arcane),
--                 learned from the combat log
-- Gathering and the rest are known by the game's own name for the profession spell, so it works in every
-- language.

local ADDON, ns = ...
local C = ns.colors

local K = {}
ns.CastLook = K

local function FX(kind, tex, count, size, life, speed)
    return { kind = kind, tex = tex, count = count, size = size, life = life, speed = speed }
end

K.KINDS = {
    mining     = { color = { 0.92, 0.58, 0.26 }, fx = FX("sparks", "spark", 5, 10, 0.3, 130), every = 0.55,
                   ids = { 2575, 2576, 3564, 10248, 29354, 50310, 74517, 102161, 158754, 195122, 265837, 366260 } },
    herbs      = { color = { 0.45, 0.95, 0.4 }, fx = FX("motes", "soft", 4, 9, 0.9, 22), every = 0.4,
                   ids = { 2366, 2368, 3570, 11993, 28695, 50300, 74519, 110413, 158745, 193290, 265819, 366252 } },
    skinning   = { color = { 0.92, 0.32, 0.28 }, fx = FX("sparks", "spark", 4, 9, 0.25, 110), every = 0.5,
                   ids = { 8613, 8617, 8618, 10768, 32678, 50305, 74522, 102216, 158756, 194174, 265856, 366263 } },
    opening    = { color = { 0.95, 0.82, 0.45 }, fx = FX("sparks", "spark", 3, 8, 0.25, 90), every = 0.7,
                   ids = { 1804, 3365, 6247, 6477, 6478, 21651, 22810, 8386 } },
    disenchant = { color = { 0.78, 0.45, 1 }, fx = FX("runes", "mark", 3, 11, 0.6, 15), every = 0.45,
                   ids = { 13262 } },
    travel     = { color = { 0.5, 0.8, 1 }, fx = FX("motes", "soft", 3, 12, 1.0, 30), every = 0.3,
                   ids = { 8690, 556, 18960, 3561, 3562, 3563, 3565, 3566, 3567, 32271, 32272, 49358, 49359 } },
    lightning  = { color = { 0.66, 0.84, 1 }, fx = FX("sparks", "spark", 4, 10, 0.25, 130), every = 0.5,
                   ids = { 403, 421, 324, 26364, 45284, 51490 } },
    roots      = { color = { 0.56, 0.78, 0.36 }, fx = FX("motes", "soft", 4, 9, 0.9, 22), every = 0.5,
                   ids = { 339, 16689, 19975, 102359, 64695 } },
    crafting   = { color = { 1, 0.74, 0.35 }, fx = FX("sparks", "spark", 4, 9, 0.3, 120), every = 0.6 },
    mount      = { color = { 0.82, 0.72, 0.52 }, fx = FX("smoke", "soft", 3, 16, 0.6, 18), every = 0.45 },
}

-- The school of the spells players cast most, by one rank of each (every rank shares the name). A spell not
-- listed here is learned as you play: from the combat log, or from the hit or heal that follows your cast.
K.SCHOOLS = {
    holy = { 635, 19750, 879, 2812, 24275, 26573, 20473, 20154, 20271, 21082, 20165, 20166, 20375, 19740, 19742,
             20217, 1038, 465, 7294, 642, 633, 7328, 1152, 4987, 853, 2878, 585, 2054, 2050, 2060, 2061, 139, 596,
             14914, 1243, 17, 2006, 20925, 19876 },
    fire = { 133, 2136, 2120, 2948, 11366, 348, 6353, 5676, 5740, 1949, 8050, 1535, 3599, 8190, 11113, 543 },
    frost = { 116, 122, 120, 10, 11426, 168, 7302, 8056, 6143, 12472 },
    arcane = { 5143, 1449, 1459, 118, 1953, 8921, 2912, 3044, 604, 1008 },
    shadow = { 686, 172, 980, 689, 1120, 6789, 5782, 589, 8092, 15407, 8122, 1454, 17877, 702, 1714, 5138, 2944 },
    nature = { 403, 421, 8042, 331, 8004, 1064, 5176, 339, 774, 8936, 5185, 740, 16914, 5570, 1978, 1126, 467,
               2484, 5394 },
}
local schoolByID = {}
for school, ids in pairs(K.SCHOOLS) do for _, id in ipairs(ids) do schoolByID[id] = school end end

-- Heals, by one rank of each. A heal not listed here is learned as you play, from the combat log.
K.HEALS = { 331, 8004, 1064, 5185, 774, 8936, 740, 5394, 18562, 635, 19750, 2054, 2050, 2060, 2061, 139, 596, 633 }
K.HEAL_COLOR = { nature = { 0.45, 0.9, 0.4 } }      -- the bar of a heal; other schools keep their own colour
local healByID = {}
for _, id in ipairs(K.HEALS) do healByID[id] = true end

-- The game's names for all those spells (in your language), filled the first time they are needed
local byName, schoolByName, healByName
local function Names()
    if byName then return byName end
    byName, schoolByName, healByName = {}, {}, {}
    local get = (C_Spell and C_Spell.GetSpellName) or GetSpellInfo
    local function name(id)
        local ok, n = pcall(get, id)
        if ok and type(n) == "string" and not ns.IsSecret(n) then return n end
    end
    for kind, def in pairs(K.KINDS) do
        for _, id in ipairs(def.ids or {}) do
            local n = name(id)
            if n then byName[n] = kind end
        end
    end
    for id, school in pairs(schoolByID) do
        local n = name(id)
        if n then schoolByName[n] = school end
    end
    for id in pairs(healByID) do
        local n = name(id)
        if n then healByName[n] = true end
    end
    return byName
end

-- Is this spell a heal? Learned, listed, or known by its name
function K.IsHeal(name, spellID)
    if spellID and not ns.IsSecret(spellID) then
        local IM = ns.Impact
        if (IM and IM.HEAL_OF and IM.HEAL_OF[spellID]) or healByID[spellID] then return true end
    end
    if type(name) == "string" and not ns.IsSecret(name) then
        Names()
        return healByName[name] or false
    end
    return false
end

-- A spell's school: learned, listed, or known by its name
function K.SchoolOf(name, spellID)
    local IM = ns.Impact
    if spellID and not ns.IsSecret(spellID) then
        local learned = IM and IM.SCHOOL_OF and IM.SCHOOL_OF[spellID]
        if learned then return learned end
        if schoolByID[spellID] then return schoolByID[spellID] end
    end
    if type(name) == "string" and not ns.IsSecret(name) then
        Names()
        return schoolByName[name]
    end
end

-- The kind of a cast: name and spellID as the game gives them (either may be secret), tradeSkill when the
-- game says it is a craft. Returns a key of KINDS, "school", or nil.
function K.Kind(name, spellID, tradeSkill)
    if tradeSkill and not ns.IsSecret(tradeSkill) then return "crafting" end
    if spellID and not ns.IsSecret(spellID) then
        for kind, def in pairs(K.KINDS) do
            for _, id in ipairs(def.ids or {}) do if id == spellID then return kind end end
        end
        if C_MountJournal and C_MountJournal.GetMountFromSpell then
            local ok, mount = pcall(C_MountJournal.GetMountFromSpell, spellID)
            if ok and mount and not ns.IsSecret(mount) then return "mount" end
        end
    end
    if type(name) == "string" and not ns.IsSecret(name) and Names()[name] then return Names()[name] end
    if K.SchoolOf(name, spellID) then return "school" end
    return nil
end

-- The look of a cast: { color, fx, every (seconds between little bursts while it runs), land (a profile for
-- when it lands) }, or nil for the plain look
function K.Look(name, spellID, tradeSkill)
    local kind = K.Kind(name, spellID, tradeSkill)
    if not kind then return nil end
    if kind == "school" then
        kind = K.SchoolOf(name, spellID)
        if K.IsHeal(name, spellID) then return K.HealLook(kind) end
    end
    return K.LookOf(kind)
end

-- The look of a heal of this school: the school's own effects when it lands, in the colour of growing things
function K.HealLook(school)
    local p = ns.Impact.PROFILES[school] or ns.Impact.PROFILES.nature
    return { kind = "heal", school = school, color = K.HEAL_COLOR[school] or p.color, fx = p.fx, every = 0.5, land = p }
end

-- The look of a kind of cast: a key of KINDS, "heal", or a school ("fire", "frost"...)
function K.LookOf(kind)
    local def = K.KINDS[kind]
    if def then return { kind = kind, color = def.color, fx = def.fx, every = def.every, land = def } end
    if kind == "heal" then return K.HealLook("nature") end
    -- a physical cast keeps the plain bar: no colour of its own, no bursts, only a glint of steel (CastArt.lua)
    if kind == "physical" then return { kind = "physical", color = C.cast } end
    local p = kind and ns.Impact.PROFILES[kind]
    if not p then return nil end
    -- while it is cast, its school's effect now and then, lighter; when it lands, the full one
    return { kind = kind, color = p.color, fx = p.fx, every = 0.4, land = p }
end

-- The name to show for a cast. The game names some casts by how they work inside ("Opening - No Text"): those
-- show their plain part. Gathering and opening say what you are working on when the game can name it
-- ("Opening: Sweet Nectar Barrel", "Mining: Copper Vein").
local WORKING = { opening = true, mining = true, herbs = true, skinning = true, disenchant = true }
function K.Label(name, look)
    if type(name) ~= "string" or ns.IsSecret(name) then return name end
    local working = look and WORKING[look.kind]
    local plain = name:match("^(.-)%s+%-%s+.+$")
    if plain and plain ~= "" and (working or name:find("%- [Nn]o [Tt]ext$")) then name = plain end
    if working then
        local ok, what = pcall(UnitName, "softinteract")
        if ok and type(what) == "string" and not ns.IsSecret(what) and what ~= "" then
            return ("%s: %s"):format(name, what)
        end
    end
    return name
end

-- What a unit is casting, for K.Look: name, spellID, tradeSkill, icon
function K.Casting(unit)
    local ok, name, _, icon, _, _, tradeSkill, _, _, spellID = pcall(UnitCastingInfo, unit)
    if ok and name then return name, spellID, tradeSkill, icon end
    local ok2, cname, _, cicon, _, _, ctrade, _, cspell = pcall(UnitChannelInfo, unit)
    if ok2 and cname then return cname, cspell, ctrade, cicon end
    return nil
end
