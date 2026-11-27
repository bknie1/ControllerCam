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
--   revive        bringing a pet back to life: the green of new growth (Revive Pet)
--   a heal        growing green (or the gold of a holy heal), whatever its school
--   a spell       the colour and effects of its school (physical, holy, fire, nature, frost, shadow, arcane),
--                 learned from the combat log
-- Gathering and the rest are known by the game's own name for the profession spell, so it works in every
-- language.

local ADDON, ns = ...
local C, L = ns.colors, ns.L

local K = {}
ns.CastLook = K

---------------------------------------------------------------------------
-- How much of all this you want: one choice over the hit effects and the cast bar animations.
--   full     effects come in from a bar's ends and strike at its eight hit areas (slashes land where they fall),
--            wounds open and keep bleeding, casts charge up and fire, and the main abilities have their own look
--   subtle   the same, calmer: fixed places only, fewer pieces, nothing shakes
--   classic  the look before all that, unchanged
--   none     colour, status effects and icons only
-- The switches under it (hit particles, wounds, cast bar animations, wind-up) still turn their own part off.
---------------------------------------------------------------------------
ns.FX_LEVELS = { "Full", "Subtle", "Classic", "None" }
ns.FX_NAMES = { L["Full"], L["Subtle"], L["Classic"], L["None"] }      -- (in your language: the options show them so)
local LEVEL = { "full", "subtle", "classic", "none" }
ns.RegisterSetting({
    key = "effects", kind = "number", default = 1, min = 1, max = #ns.FX_LEVELS, section = "Effects",
    choices = ns.FX_LEVELS, command = "effects",
    label = "Hit and cast effects",
    tip = "Full: effects come in from a bar's edges and strike at its eight hit areas, wounds open below half and a quarter of a foe's health, bolts charge up and fire, and the main abilities each have their own look. Subtle: the same in fixed places, with fewer pieces and no shaking. Classic: the look from before. None: colour, status effects and icons only",
})
function ns.Effects() return LEVEL[ns.db and ns.db.effects or 1] or "full" end

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
    revive     = { color = { 0.5, 0.95, 0.5 }, fx = FX("motes", "soft", 5, 10, 1.1, 26), every = 0.45,
                   ids = { 982 } },
    crafting   = { color = { 1, 0.74, 0.35 }, fx = FX("sparks", "spark", 4, 9, 0.3, 120), every = 0.6 },
    mount      = { color = { 0.82, 0.72, 0.52 }, fx = FX("smoke", "soft", 3, 16, 0.6, 18), every = 0.45 },
}

-- The school of the spells players cast most, by one rank of each (every rank shares the name). A spell not
-- listed here is learned as you play: from the combat log, or, as a guess, from the hit or heal that follows
-- your cast. A guess never speaks for a spell listed here.
K.SCHOOLS = {
    holy = { 635, 19750, 879, 2812, 24275, 26573, 20473, 20154, 20271, 21082, 20165, 20166, 20375, 19740, 19742,
             20217, 1038, 465, 7294, 642, 633, 7328, 1152, 4987, 853, 2878, 585, 2054, 2050, 2060, 2061, 139, 596,
             14914, 1243, 17, 2006, 20925, 19876 },
    fire = { 133, 2136, 2120, 2948, 11366, 348, 6353, 5676, 5740, 1949, 8050, 1535, 3599, 8190, 11113, 543, 29722,
             51505 },
    frost = { 116, 122, 120, 10, 11426, 168, 7302, 8056, 6143, 12472 },
    arcane = { 5143, 1449, 1459, 118, 1953, 8921, 2912, 3044, 604, 1008, 30451 },
    shadow = { 686, 172, 980, 689, 1120, 6789, 5782, 589, 8092, 15407, 8122, 1454, 17877, 702, 1714, 5138, 2944 },
    nature = { 403, 421, 8042, 331, 8004, 1064, 5176, 339, 774, 8936, 5185, 740, 16914, 5570, 1978, 1126, 467,
               2484, 5394, 136 },                 -- (136: Mend Pet, a hunter's nature heal)
}
local schoolByID = {}
for school, ids in pairs(K.SCHOOLS) do for _, id in ipairs(ids) do schoolByID[id] = school end end

-- Heals, by one rank of each. A heal not listed here is learned as you play, from the combat log.
K.HEALS = { 331, 8004, 1064, 5185, 774, 8936, 740, 5394, 18562, 635, 19750, 2054, 2050, 2060, 2061, 139, 596, 633,
            136 }
K.HEAL_COLOR = { nature = { 0.45, 0.9, 0.4 } }      -- the bar of a heal; other schools keep their own colour
local healByID = {}
for _, id in ipairs(K.HEALS) do healByID[id] = true end

---------------------------------------------------------------------------
-- The main abilities: a look of their own on top of their school's (Full and Subtle; CastSig.lua plays them).
-- One rank of each; every rank and every language is known by the game's name for it. A spell this game does
-- not have is simply never named. Adding one is a line here.
--   show     which of CastSig's shows it gets:
--     charge    it gathers at the right end of the bar as the cast fills, and fires when it lands (how: fire =)
--     orb       a ball of force wound up in the middle of the bar, thrown at the enemy when it lands
--     reticle   sights that wander and lock onto the middle the moment the shot goes
--     missiles  a channel: its bolts wait over the bar and leave one by one
--     tether    a channel: something flows along the bar, to the foe or back to you
--   school   its school where the game has not told us yet (and the plain bar's colour for physical)
--   solo     its show stands alone, without the school's own running under it
--   room     how much further than usual its show reaches above and below the bar
---------------------------------------------------------------------------
K.SIGS = {
    -- mage
    fireball    = { ids = { 133 },   school = "fire",   show = "charge", tex = "flame", fire = "burst" },
    pyroblast   = { ids = { 11366 }, school = "fire",   show = "charge", tex = "flame", fire = "burst", big = 1.5, room = 10 },
    scorch      = { ids = { 2948 },  school = "fire",   show = "charge", tex = "spark", fire = "burst", big = 0.7 },
    frostbolt   = { ids = { 116 },   school = "frost",  show = "charge", tex = "crystal", fire = "shatter" },
    frostfire   = { ids = { 44614 }, school = "fire",   show = "charge", tex = "crystal", fire = "burst" },
    missiles    = { ids = { 5143 },  school = "arcane", show = "missiles", ticks = 5, solo = true },
    blast       = { ids = { 30451 }, school = "arcane", show = "charge", tex = "mark", fire = "implode" },
    -- warlock
    shadowbolt  = { ids = { 686 },   school = "shadow", show = "charge", tex = "soft", fire = "lance" },
    immolate    = { ids = { 348 },   school = "fire",   show = "charge", tex = "flame", fire = "engulf" },
    incinerate  = { ids = { 29722 }, school = "fire",   show = "charge", tex = "flame", fire = "burst", big = 1.2 },
    soulfire    = { ids = { 6353 },  school = "fire",   show = "charge", tex = "flame", fire = "lance", big = 1.5, room = 10 },
    searing     = { ids = { 5676 },  school = "fire",   show = "charge", tex = "spark", fire = "burst", big = 0.7 },
    chaosbolt   = { ids = { 50796 }, school = "fire",   show = "charge", tex = "soft", fire = "lance", big = 1.4, room = 8 },
    drainlife   = { ids = { 689 },   school = "shadow", show = "tether", dir = -1, ticks = 5, color = { 0.5, 1, 0.35 } },
    drainsoul   = { ids = { 1120 },  school = "shadow", show = "tether", dir = -1, ticks = 5 },
    -- priest
    smite       = { ids = { 585 },   school = "holy",   show = "charge", tex = "spark", fire = "beam" },
    holyfire    = { ids = { 14914 }, school = "holy",   show = "charge", tex = "flame", fire = "beam", big = 1.3, room = 6 },
    mindblast   = { ids = { 8092 },  school = "shadow", show = "charge", tex = "soft", fire = "implode" },
    mindflay    = { ids = { 15407 }, school = "shadow", show = "tether", dir = 1, ticks = 3 },
    -- druid
    wrath       = { ids = { 5176 },  school = "nature", show = "orb", solo = true, room = 6 },
    starfire    = { ids = { 2912 },  school = "arcane", show = "orb", solo = true, room = 6, slow = true, tex = "mark" },
    -- shaman
    lightningbolt = { ids = { 403 },  school = "nature", show = "charge", tex = "spark", fire = "arc" },
    chain       = { ids = { 421 },   school = "nature", show = "charge", tex = "spark", fire = "arc", big = 1.2 },
    lavaburst   = { ids = { 51505 }, school = "fire",   show = "charge", tex = "flame", fire = "burst", big = 1.4, room = 8 },
    -- hunter
    aimed       = { ids = { 19434 }, school = "physical", show = "reticle", room = 8 },
    steady      = { ids = { 56641 }, school = "physical", show = "reticle", quick = true, room = 8 },
    multishot   = { ids = { 2643 },  school = "physical", show = "reticle", sights = 3, room = 8 },
    -- paladin
    exorcism    = { ids = { 879 },   school = "holy",   show = "charge", tex = "spark", fire = "beam" },
    holywrath   = { ids = { 2812 },  school = "holy",   show = "charge", tex = "spark", fire = "implode", big = 1.2 },
    -- warrior
    slam        = { ids = { 1464 },  school = "physical", show = "charge", tex = "spark", fire = "lance", big = 0.8 },
}
for key, sig in pairs(K.SIGS) do sig.key = key end

---------------------------------------------------------------------------
-- The melee pass: what an instant ability looks like where it lands (Impact.lua draws it at a hit area of the
-- bar). One rank of each, known by name as above.
--   slash  one cut            cross  two, crossing        claw   three, side by side
--   stab   a thrust from the side                         bash   a blunt blow: a ring knocked out of the bar
--   arrow  a shot flying in along the bar
-- color: its own, else the colour of the hit's school. heavy: it shakes the bar that much harder.
---------------------------------------------------------------------------
local GOLD, STORM, ICE, FEL = { 1, 0.9, 0.55 }, { 0.6, 0.85, 1 }, { 0.65, 0.9, 1 }, { 0.6, 1, 0.4 }
K.STRIKES = {
    slash = { ids = { 78, 1464, 772, 1715, 6572, 20243, 1752, 16511, 2973, 1495, 2974, 45902, 55050 } },
    cross = { ids = { 12294, 23881, 1680, 845, 1329, 53385, 49998 } },
    heavy = { kind = "cross", heavy = 1.5, ids = { 5308, 2098, 22568 } },                 -- the finishers
    stab  = { ids = { 53, 8676, 703, 5938, 1766, 7384 } },
    bash  = { heavy = 1.3, ids = { 23922, 6343, 1776, 6807, 6552, 72 } },
    claw  = { ids = { 1082, 5221, 33876, 33878, 1822, 1079, 779, 33745 } },
    arrow = { ids = { 3044, 1978, 2643, 19434, 56641, 75, 53209, 34026 } },
    light = { kind = "slash", color = GOLD, ids = { 35395, 20271, 24275 } },
    hammer = { kind = "bash", color = GOLD, heavy = 1.3, ids = { 853 } },
    storm = { kind = "cross", color = STORM, ids = { 17364, 60103 } },
    shock = { kind = "bash", ids = { 8042, 8050, 8056 } },
    rime  = { kind = "cross", color = ICE, ids = { 49020, 49143, 45477 } },
    blight = { kind = "slash", color = FEL, ids = { 45462, 55090 } },
}
for key, def in pairs(K.STRIKES) do def.key, def.kind = key, def.kind or key end
K.SWING = { key = "swing", kind = "slash" }             -- a plain swing of your weapon
K.SHOT = { key = "shot", kind = "arrow" }               -- and a plain shot

-- The game's names for all those spells (in your language), filled the first time they are needed
local byName, schoolByName, healByName, sigByName, strikeByName
local sigByID, strikeByID = {}, {}
for _, sig in pairs(K.SIGS) do for _, id in ipairs(sig.ids) do sigByID[id] = sig end end
for _, def in pairs(K.STRIKES) do for _, id in ipairs(def.ids) do strikeByID[id] = def end end
local function Names()
    if byName then return byName end
    byName, schoolByName, healByName, sigByName, strikeByName = {}, {}, {}, {}, {}
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
    for id, sig in pairs(sigByID) do
        local n = name(id)
        if n then sigByName[n] = sig end
    end
    for id, def in pairs(strikeByID) do
        local n = name(id)
        if n then strikeByName[n] = def end
    end
    return byName
end

local function Known(byID, names, name, spellID)
    if spellID and not ns.IsSecret(spellID) and byID[spellID] then return byID[spellID] end
    if type(name) == "string" and not ns.IsSecret(name) then
        Names()
        return names()[name]
    end
    return nil
end
-- A main ability's own look (an entry of K.SIGS), or nil: by its ID, or by its name for the other ranks
function K.Sig(name, spellID) return Known(sigByID, function() return sigByName end, name, spellID) end
-- How an instant ability strikes (an entry of K.STRIKES), or nil
function K.Strike(name, spellID) return Known(strikeByID, function() return strikeByName end, name, spellID) end
-- Which of the main abilities this game can name (for the debug report): "23 of 30", and those it cannot
function K.SigsKnown()
    Names()
    local known, missing = 0, {}
    for key, sig in pairs(K.SIGS) do
        local found = false
        for _, s in pairs(sigByName) do if s == sig then found = true; break end end
        if found then known = known + 1 else missing[#missing + 1] = key end
    end
    table.sort(missing)
    return known, missing
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

-- A spell's school: as the combat log told it, listed, known by its name, or (last of all) guessed from the
-- hits that followed it
function K.SchoolOf(name, spellID)
    local IM = ns.Impact
    local id = spellID and not ns.IsSecret(spellID) and spellID or nil
    if id then
        local learned = IM and IM.SCHOOL_OF and IM.SCHOOL_OF[id]
        if learned then return learned end
        if schoolByID[id] then return schoolByID[id] end
    end
    if type(name) == "string" and not ns.IsSecret(name) then
        Names()
        if schoolByName[name] then return schoolByName[name] end
    end
    return id and IM and IM.Guess and IM.Guess(id) or nil
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
    local sig = K.Sig(name, spellID)
    if not kind then
        -- a main ability whose school the game has not told us yet still has its look
        local look = sig and K.LookOf(sig.school)
        if look then look.sig = sig end
        return look
    end
    if kind == "school" then
        kind = K.SchoolOf(name, spellID)
        if K.IsHeal(name, spellID) then return K.HealLook(kind) end
    end
    local look = K.LookOf(kind)
    if look then look.sig = sig end
    return look
end

-- The look of one of the main abilities by its key in K.SIGS (for /cchud casttest)
function K.SigLook(key)
    local sig = K.SIGS[key]
    local look = sig and K.LookOf(sig.school)
    if look then look.sig = sig end
    return look
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
