-- ControllerCam HUD: bags, bank and vendor.
--   * /cchud sell (and its key binding) asks what to sell, in a window of the HUD's own. Until the auction
--     house has been read: junk by your rules, junk with white weapons and armor, or with green ones too.
--     Once prices are known: the recommended sale (what a vendor pays best for; what is worth more at the
--     auction house, and what still gives one of your characters a skill-up, stays), junk alone, or by
--     quality. Anything beyond grey items is listed and confirmed first. The game's own "Sell all junk"
--     button is left as the game made it.
--   * Auto-sell: the same rules, applied as soon as a vendor opens (off unless you turn it on).
--   * Quick move: one bindable action on the item you are pointing at. Sells it at a vendor, moves it into
--     or out of the bank at a banker.
--   * Mark item: tag the item you are pointing at as junk (always sold), kept (never sold) or bank
--     (deposited with one command, or by itself when the bank opens).
-- Bags the game is told to leave out of junk selling are left out here too.

local ADDON, ns = ...
local L = ns.L
local say = ns.Say

local V = { active = false, merchantOpen = false, bankOpen = false }
ns.Vendor = V

local SELL_GAP = 0.15                       -- seconds between sales (the game refuses a faster pace)
local GEAR = { [2] = true, [4] = true }     -- item classes: weapon, armor
V.QUALITY = { [0] = "Poor (grey)", [1] = "Common (white)", [2] = "Uncommon (green)", [3] = "Rare (blue)" }
local QUALITY_WORD = { grey = 0, gray = 0, poor = 0, white = 1, common = 1, green = 2, uncommon = 2, blue = 3, rare = 3 }

---------------------------------------------------------------------------
-- Items
---------------------------------------------------------------------------
function ns.Money(copper)
    copper = math.floor(copper or 0)
    local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    local parts = {}
    if g > 0 then parts[#parts + 1] = g .. "g" end
    if s > 0 then parts[#parts + 1] = s .. "s" end
    if c > 0 or #parts == 0 then parts[#parts + 1] = c .. "c" end
    return table.concat(parts, " ")
end

-- The same, in the coins' colours (gold, silver, copper), for tooltips
function ns.MoneyColored(copper)
    copper = math.floor(copper or 0)
    local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    local parts = {}
    if g > 0 then parts[#parts + 1] = "|cffffd700" .. g .. "g|r" end
    if s > 0 then parts[#parts + 1] = "|cffc7c7cf" .. s .. "s|r" end
    if c > 0 or #parts == 0 then parts[#parts + 1] = "|cffeda55f" .. c .. "c|r" end
    return table.concat(parts, " ")
end

local function SellPrice(link, id)
    local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if not get then return nil end
    local name, _, _, _, _, _, _, _, _, _, price = get(link or id)
    return price, name
end

-- class, subclass and where it is worn (INVTYPE_...)
local function ItemKind(id)
    local get = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not get then return nil end
    local _, _, _, equipLoc, _, classID, subclassID = get(id)
    return classID, subclassID, equipLoc
end

---------------------------------------------------------------------------
-- What is never junk, whatever the rules say (unless you mark the item as junk yourself)
---------------------------------------------------------------------------
-- Tools of the trade look like white weapons: a mining pick is a main-hand axe, a blacksmith hammer a mace.
V.TOOLS = {}
for _, id in ipairs({ 2901, 20723, 40772, 40892, 40893,          -- mining picks, the army knives
                      5956, 7005, 12709, 19901,                   -- blacksmith hammer, skinning knives
                      6219, 10498, 9149, 4471, 5060,              -- spanner, micro-adjustor, philosopher's stone,
                                                                  -- flint and tinder, thieves' tools
                      6218, 6339, 11130, 11145, 16207,            -- enchanting rods
                      6256, 12225, 6365, 6366, 6367, 19022, 19970 }) do  -- fishing poles
    V.TOOLS[id] = true
end
local TOOL_SUBCLASS = { [14] = true, [20] = true }   -- weapons: miscellaneous (tools), fishing poles
-- Tools that do the same job, so that one of them is enough: picks, skinning knives, fishing poles
V.TOOL_KINDS = { { 2901, 20723, 40772, 40892, 40893 }, { 7005, 12709, 19901 },
                 { 6256, 12225, 6365, 6366, 6367, 19022, 19970 } }
local kindOf = {}
for _, kind in ipairs(V.TOOL_KINDS) do for _, id in ipairs(kind) do kindOf[id] = kind end end

-- A tool of the trade (by the list above, or a weapon of the tools' kinds)
function V.IsTool(id, classID, subclassID)
    if V.TOOLS[id] then return true end
    return classID == 2 and TOOL_SUBCLASS[subclassID or -1] and true or false
end

-- Your last one of its kind (in your bags, your bank and in your hands together)? Then it is never sold nor
-- put up for auction: with a second Blacksmith Hammer, one of them may go.
function V.LastTool(id)
    if not GetItemCount then return true end
    local total = 0
    for _, each in ipairs(kindOf[id] or { id }) do
        local ok, n = pcall(GetItemCount, each, true)
        if ok and type(n) == "number" and not ns.IsSecret(n) then total = total + n end
    end
    return total <= 1
end

-- Where an item is worn: the slots to compare it with
local SLOTS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_BODY = { 4 },
    INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 },
    INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 },
    INVTYPE_CLOAK = { 15 }, INVTYPE_WEAPON = { 16, 17 }, INVTYPE_SHIELD = { 17 }, INVTYPE_2HWEAPON = { 16 },
    INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_HOLDABLE = { 17 },
    INVTYPE_RANGED = { 18 }, INVTYPE_THROWN = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_RELIC = { 18 },
}

local function ItemLevel(item)
    if not item then return nil end
    if C_Item and C_Item.GetDetailedItemLevelInfo then
        local ok, lvl = pcall(C_Item.GetDetailedItemLevelInfo, item)
        if ok and type(lvl) == "number" and not ns.IsSecret(lvl) then return lvl end
    end
    local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if get then
        local ok, _, _, _, lvl = pcall(get, item)
        if ok and type(lvl) == "number" and not ns.IsSecret(lvl) then return lvl end
    end
    return nil
end

-- Clearly better than what you wear: worth putting on. Only gear you can use, with your specialization's main
-- stat (strength, agility, intellect) if it has one at all, armor of the kind you wear in that slot, and a
-- higher item level than what you wear there (or nothing worn there, except an off hand beside a two-hander).
local PRIMARY = { [1] = "ITEM_MOD_STRENGTH_SHORT", [2] = "ITEM_MOD_AGILITY_SHORT", [4] = "ITEM_MOD_INTELLECT_SHORT" }
local function Instant(item)
    local get = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not get then return nil end
    local ok, id, _, _, equipLoc, _, classID, subclassID = pcall(get, item)
    if not ok then return nil end
    return id, classID, subclassID, equipLoc
end

-- anySpec: leave the main stat to each spec (V.Specs below knows them), so another spec's gear still fits
local function Fits(id, anySpec)
    if C_PlayerInfo and C_PlayerInfo.CanUseItem then
        local ok, can = pcall(C_PlayerInfo.CanUseItem, id)
        if ok and can == false then return false end
    end
    local stats = (C_Item and C_Item.GetItemStats) or GetItemStats
    local spec = not anySpec and GetSpecialization and GetSpecialization()
    local primary
    if spec and GetSpecializationInfo then
        local ok, _, _, _, _, _, stat = pcall(GetSpecializationInfo, spec)
        primary = ok and PRIMARY[stat]
    end
    if stats and primary then
        local link = select(2, ((C_Item and C_Item.GetItemInfo) or GetItemInfo)(id))
        local ok, list = pcall(stats, link or ("item:" .. id))
        if ok and type(list) == "table" then
            local any = false
            for _, key in pairs(PRIMARY) do if list[key] then any = true end end
            if any and not list[primary] then return false end                   -- someone else's main stat
        end
    end
    return true
end

V.Instant, V.Fits = Instant, Fits

---------------------------------------------------------------------------
-- How good a piece of gear is for you: its stats, each weighed by what it does for your class, and a weapon's
-- damage per second. Compared with what you wear in its slot, this decides "better than yours" (worth putting
-- on) and "could be as good" (never sold by a rule). An item level says little in itself: a green robe of
-- intellect is worthless to a warrior, whatever its level.
---------------------------------------------------------------------------
-- What a point of each stat is worth to each class (roughly; the main stat is 1)
V.WEIGHTS = {
    WARRIOR = { STRENGTH = 1, AGILITY = 0.7, STAMINA = 0.6, SPIRIT = 0.05, ATTACK_POWER = 0.5, ARMOR = 0.02, DPS = 4 },
    PALADIN = { STRENGTH = 1, AGILITY = 0.5, STAMINA = 0.6, INTELLECT = 0.4, SPIRIT = 0.2, ATTACK_POWER = 0.5,
                SPELL_POWER = 0.6, ARMOR = 0.02, DPS = 3 },
    HUNTER = { AGILITY = 1, STRENGTH = 0.1, STAMINA = 0.5, INTELLECT = 0.35, SPIRIT = 0.1, ATTACK_POWER = 0.5,
               RANGED_ATTACK_POWER = 0.45, ARMOR = 0.01, DPS = 0.8, RANGED_DPS = 4 },
    ROGUE = { AGILITY = 1, STRENGTH = 0.6, STAMINA = 0.5, ATTACK_POWER = 0.5, ARMOR = 0.01, DPS = 4 },
    SHAMAN = { STRENGTH = 0.6, AGILITY = 0.4, INTELLECT = 0.8, STAMINA = 0.5, SPIRIT = 0.3, ATTACK_POWER = 0.3,
               SPELL_POWER = 0.8, ARMOR = 0.015, DPS = 2 },
    DRUID = { STRENGTH = 0.6, AGILITY = 0.6, INTELLECT = 0.8, STAMINA = 0.5, SPIRIT = 0.4, ATTACK_POWER = 0.3,
              SPELL_POWER = 0.8, ARMOR = 0.01, DPS = 1 },
    MAGE = { INTELLECT = 1, SPIRIT = 0.5, STAMINA = 0.6, SPELL_POWER = 1, ARMOR = 0.005, DPS = 0.2 },
    PRIEST = { INTELLECT = 1, SPIRIT = 0.6, STAMINA = 0.6, SPELL_POWER = 1, ARMOR = 0.005, DPS = 0.2 },
    WARLOCK = { INTELLECT = 1, SPIRIT = 0.3, STAMINA = 0.7, SPELL_POWER = 1, ARMOR = 0.005, DPS = 0.2 },
}
V.WEIGHTS.DEATHKNIGHT, V.WEIGHTS.MONK = V.WEIGHTS.WARRIOR, V.WEIGHTS.ROGUE
V.WEIGHTS.DEMONHUNTER, V.WEIGHTS.EVOKER = V.WEIGHTS.ROGUE, V.WEIGHTS.MAGE
-- ratings of every kind, the same for everyone
local RATINGS = { CRIT_RATING = 0.8, HIT_RATING = 0.8, HASTE_RATING = 0.6, MASTERY_RATING = 0.6, VERSATILITY = 0.6,
                  CRIT_SPELL_RATING = 0.6, HIT_SPELL_RATING = 0.6 }
V.BETTER = 1.05                -- clearly better: this much over what you wear
V.ABOUT = 0.95                 -- could be as good: this close to it

-- The armor your class wears at your level (4 plate, 3 mail, 2 leather, 1 cloth); lighter armor is no upgrade
local ARMOR_AT = { WARRIOR = { 3, 4 }, PALADIN = { 3, 4 }, DEATHKNIGHT = { 4, 4 }, HUNTER = { 2, 3 },
                   SHAMAN = { 2, 3 }, EVOKER = { 3, 3 }, ROGUE = { 2, 2 }, DRUID = { 2, 2 }, MONK = { 2, 2 },
                   DEMONHUNTER = { 2, 2 }, MAGE = { 1, 1 }, PRIEST = { 1, 1 }, WARLOCK = { 1, 1 } }
function V.ArmorKind()
    local _, class = UnitClass("player")
    local at = ARMOR_AT[ns.Plain(class) or ""]
    if not at then return nil end
    local level = ns.Plain(UnitLevel("player"))
    return (type(level) == "number" and level >= 40) and at[2] or at[1]
end

local function Class()
    local _, class = UnitClass("player")
    return ns.Plain(class)
end

-- An item's stats, as the game gives them ({ ITEM_MOD_... = n }), or nil
local function Stats(item)
    local get = (C_Item and C_Item.GetItemStats) or GetItemStats
    if not (get and item) then return nil end
    local link = item
    if type(item) == "number" then
        local info = (C_Item and C_Item.GetItemInfo) or GetItemInfo
        link = info and select(2, info(item)) or ("item:" .. item)
    end
    local ok, stats = pcall(get, link)
    if not ok or type(stats) ~= "table" then return nil end
    return stats
end

-- An item's score for you (weights: a spec's, the class's when not given), or nil when the game says nothing of
-- its stats
function V.Score(item, equipLoc, weights)
    local w = weights or V.WEIGHTS[Class() or ""]
    if not (w and item) then return nil end
    local stats = Stats(item)
    if not stats then return nil end
    local score, any = 0, false
    for key, value in pairs(stats) do
        local name = type(key) == "string" and key:gsub("^ITEM_MOD_", ""):gsub("_SHORT$", "")
        if name == "RESISTANCE0_NAME" then name = "ARMOR" end
        if name == "DAMAGE_PER_SECOND" then
            local ranged = equipLoc == "INVTYPE_RANGED" or equipLoc == "INVTYPE_RANGEDRIGHT" or equipLoc == "INVTYPE_THROWN"
            name = (ranged and w.RANGED_DPS) and "RANGED_DPS" or "DPS"
        end
        local weight = name and (w[name] or RATINGS[name])
        if weight and type(value) == "number" and not ns.IsSecret(value) then
            score, any = score + value * weight, true
        end
    end
    return any and score or 0
end

-- Is it gear for you at all: usable, with no other class's main stat, and armor of the kind you wear?
-- anySpec: whichever of your specs (the main stat is then each spec's own to judge)
local function ForYou(item, equipLoc, anySpec)
    local id, classID, subclassID = Instant(item)
    if not id then return true end
    if not Fits(id, anySpec) then return false end
    if classID == 4 and equipLoc ~= "INVTYPE_CLOAK" and (subclassID or 0) >= 1 and subclassID <= 4 then
        local kind = V.ArmorKind()
        if kind and subclassID ~= kind then return false end         -- lighter (or heavier) than you wear
    end
    return true
end
V.ForYou = ForYou

-- What you wear where it would go, scored: the weakest of its slots (a ring, a trinket, a one-hander), or for
-- a two-hander both hands together. Returns the score, the worn item's level, and whether a slot is empty.
local function Worn(equipLoc, slots, weights)
    local scores, levels, empty = {}, {}, false
    for _, slot in ipairs(slots) do
        local worn = GetInventoryItemLink and GetInventoryItemLink("player", slot)
        if not worn then
            local main = GetInventoryItemLink and GetInventoryItemLink("player", 16)
            local _, _, _, mainLoc = Instant(main)
            if not (slot == 17 and mainLoc == "INVTYPE_2HWEAPON") then empty = true end
        else
            local _, _, _, wornLoc = Instant(worn)
            scores[#scores + 1] = V.Score(worn, wornLoc, weights)
            levels[#levels + 1] = ItemLevel(worn)
        end
    end
    local score, level
    if equipLoc == "INVTYPE_2HWEAPON" then
        local off = GetInventoryItemLink and GetInventoryItemLink("player", 17)
        score = scores[1]
        if score and off then
            local _, _, _, offLoc = Instant(off)
            score = score + (V.Score(off, offLoc, weights) or 0)
        end
        level = levels[1]
    else
        for i, sc in ipairs(scores) do if score == nil or sc < score then score, level = sc, levels[i] end end
        if score == nil then for _, l in ipairs(levels) do if level == nil or l < level then level = l end end end
    end
    return score, level, empty
end

---------------------------------------------------------------------------
-- Your specs. WoW: Forever has two talent groups (dual specialization: GetNumSpecGroups, the one you have on
-- from C_SpecializationInfo.GetActiveSpecGroup) and the classic talent trees, kept as trait groups: the points
-- in each come from C_Traits (GetSpecialization there says 1 whatever you play). Older clients:
-- GetNumTalentGroups / GetActiveTalentGroup and GetTalentTabInfo. A talent group's spec is the tree with the most
-- points in it; with no points, or two trees level, it has none we could name, and the class's weights stand.
---------------------------------------------------------------------------
ns.RegisterSetting({
    key = "upgradeSpecs", kind = "number", default = 2, min = 1, max = 3, command = "upgradespecs",
    section = "Bags, bank and vendor",
    choices = { "Current spec only", "Primary and secondary", "Any spec" },
    label = "Upgrades: for which specs",
    tip = "which of your specs an upgrade counts for, in tooltips, on the Market and in what is never sold: the talents you have on now, both of your talent groups, or any of your class's talent trees",
})
V.SPEC_NAMES = { L["Current spec only"], L["Primary and secondary"], L["Any spec"] }

-- The trees that want other gear than their class's weights above (by the tree's place in the game's talent
-- window). main: the one main stat the tree lives on; gear with another main stat and not this one is not for it.
V.TREE_WEIGHTS = {
    WARRIOR = { [3] = { STAMINA = 1, STRENGTH = 0.8, AGILITY = 0.6, SPIRIT = 0.05, ATTACK_POWER = 0.3,
                        ARMOR = 0.03, DPS = 2 } },
    PALADIN = { [1] = { INTELLECT = 1, SPELL_POWER = 0.9, SPIRIT = 0.4, STAMINA = 0.5, STRENGTH = 0.1, ARMOR = 0.01,
                        DPS = 0.2, main = "INTELLECT" },
                [2] = { STAMINA = 1, STRENGTH = 0.7, AGILITY = 0.4, INTELLECT = 0.3, SPELL_POWER = 0.4, ARMOR = 0.03,
                        DPS = 1.5 },
                [3] = { STRENGTH = 1, AGILITY = 0.5, STAMINA = 0.6, INTELLECT = 0.2, ATTACK_POWER = 0.5, ARMOR = 0.02,
                        DPS = 4, main = "STRENGTH" } },
    SHAMAN = { [1] = { INTELLECT = 1, SPELL_POWER = 1, SPIRIT = 0.3, STAMINA = 0.5, ARMOR = 0.01, DPS = 0.2,
                       main = "INTELLECT" },
               [2] = { STRENGTH = 1, AGILITY = 0.8, STAMINA = 0.5, INTELLECT = 0.2, ATTACK_POWER = 0.5, ARMOR = 0.015,
                       DPS = 4 },
               [3] = { INTELLECT = 1, SPELL_POWER = 0.9, SPIRIT = 0.4, STAMINA = 0.5, ARMOR = 0.01, DPS = 0.2,
                       main = "INTELLECT" } },
    DRUID = { [1] = { INTELLECT = 1, SPELL_POWER = 1, SPIRIT = 0.4, STAMINA = 0.5, ARMOR = 0.005, DPS = 0.2,
                      main = "INTELLECT" },
              [2] = { AGILITY = 1, STRENGTH = 0.9, STAMINA = 0.7, ATTACK_POWER = 0.45, ARMOR = 0.03, DPS = 0.1 },
              [3] = { INTELLECT = 1, SPELL_POWER = 0.9, SPIRIT = 0.6, STAMINA = 0.4, ARMOR = 0.005, DPS = 0.2,
                      main = "INTELLECT" } },
}

-- While a whole bag is gone through (V:Collect, V:Recommend): your specs and your gear are read once, not once an
-- item. Only within the same moment (GetTime), so a list left behind by an error goes stale at once.
function V.BeginBatch() V.batch = { at = GetTime and GetTime() } end
function V.EndBatch() V.batch = nil end
function V.Batch()
    local b = V.batch
    if b and b.at == (GetTime and GetTime()) then return b end
    return nil
end

local function Try(fn, ...)
    if type(fn) ~= "function" then return false end
    return pcall(fn, ...)
end
local function Num(v) v = ns.Plain(v); return type(v) == "number" and v or nil end
local function Str(v) v = ns.Plain(v); return (type(v) == "string" and v ~= "") and v or nil end

-- How many talent groups you have (1, or 2 with dual specialization), and the one you have on
function V.SpecGroups()
    local SI = C_SpecializationInfo
    local ok, n = Try(GetNumSpecGroups)
    n = ok and Num(n)
    if not n then ok, n = Try(GetNumTalentGroups); n = ok and Num(n) end
    local active
    for _, fn in ipairs({ SI and SI.GetActiveSpecGroup or false, GetActiveSpecGroup or false,
                          GetActiveTalentGroup or false }) do
        local okA, a = Try(fn)
        a = okA and Num(a)
        if a and a >= 1 then active = a; break end
    end
    active = active or 1
    return math.max(n or 1, active, 1), active
end

-- A talent group's trees: { [tree] = points spent }, { [tree] = its name }, how many trees (each nil where the
-- game does not say)
function V.Trees(group)
    local points, names, count = {}, {}, nil
    local SI, T = C_SpecializationInfo, C_Traits
    -- WoW: Forever: the trees are the trait groups of the talent group's loadout
    local ok, config = Try(SI and SI.GetCombatConfigIDForSpecGroup, group)
    config = ok and Num(config)
    if config and T then
        local okI, info = Try(T.GetConfigInfo, config)
        local tree = okI and type(info) == "table" and type(info.treeIDs) == "table" and Num(info.treeIDs[1])
        local okD, groups = Try(T.GetGroupDisplayInfoByTreeID, tree)
        if tree and okD and type(groups) == "table" then
            local ids, at = {}, {}
            for _, d in ipairs(groups) do
                local id = type(d) == "table" and Num(d.groupID)
                local order = type(d) == "table" and Num(d.orderIndex)
                if id and order then
                    ids[#ids + 1], at[id] = id, order + 1
                    names[order + 1] = Str(d.name)
                end
            end
            if #ids > 0 then count = #ids end
            local okC, spent = Try(T.GetGroupCurrencyInfo, config, ids)
            if okC and type(spent) == "table" then
                for _, s in ipairs(spent) do
                    local tab = type(s) == "table" and at[Num(s.traitNodeGroupID) or -1]
                    local c = tab and type(s.currencyInfos) == "table" and s.currencyInfos[1]
                    local n = type(c) == "table" and Num(c.spent)
                    if n then points[tab] = n end
                end
            end
        end
    end
    -- older clients: a talent tab for each tree (name, icon, points...; later id, name, text, icon, points...)
    local okN, tabs = Try(GetNumTalentTabs)
    tabs = okN and Num(tabs)
    count = count or tabs
    local fromTabs = next(points) == nil
    for tab = 1, count or 0 do
        local okT, a, b, c, _, e = Try(GetTalentTabInfo, tab, false, false, group)
        if okT then
            local later = Num(a) ~= nil
            names[tab] = names[tab] or Str(later and b or a)
            local n = Num(later and e or c)
            if fromTabs and n then points[tab] = n end
        end
        if not names[tab] then
            local okS, _, name = Try(SI and SI.GetSpecializationInfo, tab)
            names[tab] = okS and Str(name) or nil
        end
    end
    return points, names, count
end

-- The tree with the most points; none with no points at all, or with two trees level at the top
function V.MainTree(points)
    local best, most, level = nil, 0, false
    for tree, n in pairs(points or {}) do
        if n > most then best, most, level = tree, n, false
        elseif n == most and n > 0 then level = true end
    end
    if level then return nil end
    return best
end

-- The specs an upgrade counts for (mode: 1 the one you have on, 2 both talent groups, 3 any tree of your class;
-- the setting when not given): { { tree, name, rel = "current" | "other" | "none", group, weights, main } }.
-- The one you have on comes first, always there (without a tree when it has none yet). A second talent group with
-- the same tree as the first adds nothing.
function V.Specs(mode)
    mode = tonumber(mode) or (ns.db and tonumber(ns.db.upgradeSpecs)) or 2
    local batch = V.Batch()
    if batch and batch.specs and batch.specs[mode] then return batch.specs[mode] end
    local class = Class() or ""
    local n, active = V.SpecGroups()
    local out, seen = {}, {}
    local function add(tree, rel, group, names)
        if tree then
            if seen[tree] then return end
            seen[tree] = true
        end
        local own = tree and V.TREE_WEIGHTS[class] and V.TREE_WEIGHTS[class][tree]
        out[#out + 1] = { tree = tree, name = tree and names[tree], rel = rel, group = group,
                          weights = own or V.WEIGHTS[class], main = own and own.main }
    end
    local points, names, count = V.Trees(active)
    add(V.MainTree(points), "current", active, names)
    if mode >= 2 then
        for g = 1, n do
            if g ~= active then
                local p, nm = V.Trees(g)
                for tree, name in pairs(names) do nm[tree] = nm[tree] or name end
                local tree = V.MainTree(p)
                if tree then add(tree, "other", g, nm) end
            end
        end
    end
    if mode >= 3 then
        for tree = 1, count or 0 do add(tree, "none", nil, names) end
    end
    if batch then
        batch.specs = batch.specs or {}
        batch.specs[mode] = out
    end
    return out
end

-- Gear with another main stat and not this spec's own: not for it
local MAIN_STAT = { STRENGTH = "ITEM_MOD_STRENGTH_SHORT", AGILITY = "ITEM_MOD_AGILITY_SHORT",
                    INTELLECT = "ITEM_MOD_INTELLECT_SHORT" }
local function OtherMain(item, main)
    local stats = main and Stats(item)
    if not stats or stats[MAIN_STAT[main]] then return false end
    for _, key in pairs(MAIN_STAT) do if stats[key] then return true end end
    return false
end

-- Everything of yours that is worn: what you wear, and the gear for you in your bags ({ id, link, loc })
local function Owned()
    local batch = V.Batch()
    if batch and batch.owned then return batch.owned end
    local list = {}
    for slot = 1, 18 do
        local link = GetInventoryItemLink and GetInventoryItemLink("player", slot)
        local id, _, _, loc = Instant(link)
        if id and SLOTS[loc or ""] then list[#list + 1] = { id = id, link = link, loc = loc, worn = true } end
    end
    local last = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
    for bag = 0, last do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local id = info and info.itemID
            if id and not ns.IsSecret(id) then
                local link = info.hyperlink or id
                local _, classID, _, loc = Instant(link)
                if GEAR[classID or -1] and SLOTS[loc or ""] and ForYou(link, loc, true) then
                    list[#list + 1] = { id = id, link = link, loc = loc }
                end
            end
        end
    end
    if batch then batch.owned = list end
    return list
end

-- What that spec would wear there, of what you own (but `skip`), against the item: the item's worth there
-- (with the other hand, for a weapon), and the best of yours there (nil: nothing of yours goes there).
-- unknown: the game said nothing of the stats of something of yours there. wornFirst: what you wear wins a tie
-- (a second one as good as yours is no reason to keep it).
local HAND_MAIN = { INVTYPE_WEAPON = true, INVTYPE_WEAPONMAINHAND = true }
local HAND_OFF = { INVTYPE_SHIELD = true, INVTYPE_WEAPONOFFHAND = true, INVTYPE_HOLDABLE = true }
local function Against(owned, weights, slots, equipLoc, skip, mine, wornFirst)
    local unknown = false
    local function score(o)
        local s = V.Score(o.link, o.loc, weights)
        if s == nil then unknown = true end
        return (s or 0) + ((wornFirst and o.worn) and 1e-6 or 0)
    end
    if equipLoc == "INVTYPE_2HWEAPON" or HAND_MAIN[equipLoc] or HAND_OFF[equipLoc] then
        local okD, dual = Try(CanDualWield)
        dual = okD and dual == true
        local two, main, mainAt, off
        for i, o in ipairs(owned) do
            if o.id ~= skip then
                if o.loc == "INVTYPE_2HWEAPON" then two = math.max(two or 0, score(o))
                elseif HAND_MAIN[o.loc] then
                    local s = score(o)
                    if not main or s > main then main, mainAt = s, i end
                end
            end
        end
        for i, o in ipairs(owned) do
            if o.id ~= skip and i ~= mainAt and (HAND_OFF[o.loc] or (dual and o.loc == "INVTYPE_WEAPON")) then
                off = math.max(off or 0, score(o))
            end
        end
        if unknown then return nil, nil, true end
        local base = (two or main or off) and math.max(two or 0, (main or 0) + (off or 0)) or nil
        local value
        if equipLoc == "INVTYPE_2HWEAPON" then value = mine
        elseif equipLoc == "INVTYPE_WEAPON" then value = mine + math.max(off or 0, dual and main or 0)
        elseif HAND_MAIN[equipLoc] then value = mine + (off or 0)
        else value = (main or 0) + mine end
        return value, base
    end
    local into, scores = {}, {}
    for _, s in ipairs(slots) do into[s] = true end
    for _, o in ipairs(owned) do
        if o.id ~= skip then
            for _, s in ipairs(SLOTS[o.loc] or {}) do
                if into[s] then scores[#scores + 1] = score(o); break end
            end
        end
    end
    if unknown then return nil, nil, true end
    if #scores < #slots then return mine, nil end                     -- a slot that spec would leave empty
    table.sort(scores, function(a, b) return a > b end)
    return mine, scores[#slots]                                       -- the weakest of what it would wear
end

-- Is it better for this spec (about: could it be as good)? The spec you have on goes by what you wear (or by
-- item level where the game says nothing of the stats); another goes by the best you own for it, and only by
-- the stats: where the game gives none, nothing is said for another spec.
local function Judge(spec, item, equipLoc, slots, id, about)
    local w = spec.weights
    if spec.main and OtherMain(item, spec.main) then return false end
    if spec.rel == "current" then
        local wornScore, wornLevel, empty = Worn(equipLoc, slots, w)
        if empty then return true end
        local mine = V.Score(item, equipLoc, w)
        if mine and wornScore then
            if about then return mine >= wornScore * V.ABOUT end
            return mine > wornScore * V.BETTER + 0.5
        end
        local lvl = ItemLevel(item)
        if about then
            if not lvl or not wornLevel then return true end          -- cannot tell: kept
            return lvl >= wornLevel
        end
        return (lvl and wornLevel and lvl > wornLevel) and true or false
    end
    local mine = V.Score(item, equipLoc, w)
    if not mine then return false end
    local value, base, unknown = Against(Owned(), w, slots, equipLoc, id, mine)
    if unknown then return false end
    if not base then return true end
    if about then return value >= base * V.ABOUT end
    return value > base * V.BETTER + 0.5
end

-- The specs of yours (the setting says which count; V.Specs) it is better for: { spec, ... }. about: those it
-- could be as good for instead. Only gear for you counts; gear you cannot use, of another class's main stat or
-- another kind of armor is for none of them.
local function For(item, equipLoc, mode, about)
    local list = {}
    local slots = SLOTS[equipLoc or ""]
    if not slots then return list end
    local specs = V.Specs(mode)
    if not ForYou(item, equipLoc, #specs > 1 or specs[1].tree ~= nil) then return list end
    local id = Instant(item)
    if not about then
        for _, slot in ipairs(slots) do
            local worn = GetInventoryItemLink and GetInventoryItemLink("player", slot)
            if worn and id and Instant(worn) == id then return list end   -- what you wear yourself
        end
    end
    for _, spec in ipairs(specs) do
        if Judge(spec, item, equipLoc, slots, id, about) then list[#list + 1] = spec end
    end
    return list
end

-- Clearly better than what you wear: worth putting on (gear for you, scoring a good bit above what you wear
-- there, or by item level where the game says nothing of the stats). For another spec of yours: better than the
-- best you own for it. V.UpgradeSpecs says for which.
function V.UpgradeSpecs(item, equipLoc, mode) return For(item, equipLoc, mode, false) end
function V.Upgrade(item, equipLoc, mode) return #For(item, equipLoc, mode, false) > 0 end

-- Could it be as good as what you wear there (or, for another spec of yours, as the best you own for it)? Then
-- it is never junk.
function V.MaybeUpgrade(item, equipLoc, mode) return #For(item, equipLoc, mode, true) > 0 end

-- The specs of yours for which it is among what that spec would wear, of all you own (worn or in your bags; level
-- with the best counts, but a tie with what you wear does not): your Protection sword and shield while you play Holy. Never sold, whatever the rules.
-- The specs: those the upgrade setting counts, and never fewer than both talent groups. Only by the stats: where
-- the game gives none (for it, or for something of yours in that slot), nothing is said.
function V.BestFor(item, equipLoc, mode)
    local list = {}
    local slots = SLOTS[equipLoc or ""]
    if not slots then return list end
    mode = math.max(tonumber(mode) or (ns.db and tonumber(ns.db.upgradeSpecs)) or 2, 2)
    local specs = V.Specs(mode)
    if not ForYou(item, equipLoc, #specs > 1 or specs[1].tree ~= nil) then return list end
    local id = Instant(item)
    for _, spec in ipairs(specs) do
        if not (spec.main and OtherMain(item, spec.main)) then
            local mine = V.Score(item, equipLoc, spec.weights)
            if mine then
                local value, base, unknown = Against(Owned(), spec.weights, slots, equipLoc, id, mine, true)
                if not unknown and (not base or value >= base) then list[#list + 1] = spec end
            end
        end
    end
    return list
end

-- The name of one of the game's equipment sets this item is in ("" when the set has no name to give), or nil
-- Gear plainly for selling (to a vendor, or the auction house where it pays clearly more): white of any binding,
-- or green that binds when equipped and is not bound yet, that is
--   * armor your class never wears: lighter than you wear now (cloth or leather for a paladin), or heavier than
--     your class ever wears (plate for a priest); a warrior of 30 keeps plate for 40;
--   * or below the item level of what you wear where it goes (rings, trinkets and one-handers: the lower of the
--     two slots; nothing worn there: not below).
-- Returns its reason, or nil. Only the rule itself: the reasons to keep come first (M.Verdict).
-- bound: true when it is bound to you (nil: not known, taken as not bound).
function V.PlainlySellable(id, equipLoc, bound, classID, subclassID)
    if classID == nil then classID, subclassID, equipLoc = ItemKind(id) end
    if not GEAR[classID or -1] then return nil end
    local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if not get then return nil end
    local ok, quality, bind = pcall(function()
        local info = { get(id) }
        return info[3], info[14]
    end)
    quality, bind = ok and ns.Plain(quality), ok and ns.Plain(bind)
    if quality == 2 then
        if bind ~= 2 or bound == true then return nil end        -- green: only one that binds when equipped, unbound
    elseif quality ~= 1 then
        return nil                                               -- never blue or better (nor grey: junk anyway)
    end
    if classID == 4 and equipLoc ~= "INVTYPE_CLOAK" and (subclassID or 0) >= 1 and subclassID <= 4 then
        local _, class = UnitClass("player")
        local at = ARMOR_AT[ns.Plain(class) or ""]
        local now = V.ArmorKind()
        if at and now and (subclassID < now or subclassID > at[2]) then return L["not your armour type"] end
    end
    local slots = SLOTS[equipLoc or ""]
    local mine = ItemLevel(id)
    if not slots or not mine then return nil end
    if equipLoc == "INVTYPE_2HWEAPON" then slots = { 16 } end
    if equipLoc == "INVTYPE_WEAPON" then                         -- the off hand too only for those who dual-wield
        local okD, dual = Try(CanDualWield)
        if not (okD and dual == true) then slots = { 16 } end
    end
    local lowest
    for _, slot in ipairs(slots) do
        local worn = GetInventoryItemLink and GetInventoryItemLink("player", slot)
        local lvl = worn and ItemLevel(worn)
        if not lvl then return nil end                           -- nothing there (or no level to go by)
        if lowest == nil or lvl < lowest then lowest = lvl end
    end
    if lowest and mine < lowest then return L["below what you wear"] end
    return nil
end

function V.EquipmentSetOf(id)
    local ES = C_EquipmentSet
    local ok, sets = Try(ES and ES.GetEquipmentSetIDs)
    if not ok or type(sets) ~= "table" then return nil end
    for _, set in ipairs(sets) do
        local okI, items = Try(ES.GetItemIDs, set)
        if okI and type(items) == "table" then
            for _, each in pairs(items) do
                if Num(each) == id then
                    local okN, name = Try(ES.GetEquipmentSetInfo, set)
                    return (okN and Str(name)) or ""
                end
            end
        end
    end
    return nil
end

---------------------------------------------------------------------------
-- Upgrades for your other characters: the HUD notes what each one wears, its class and level (Inventory.lua).
-- An item is an upgrade for one when that character can put it on now (its level, its class's weapons and the
-- armor it wears) and it scores clearly above what that character wears there, by its class's weights (their
-- talents are not known here). Only characters on this realm and of your faction (the mail goes no further),
-- seen wearing something; never for an item bound to you.
---------------------------------------------------------------------------
-- The weapons (subclasses) each class can learn, and which armor of the off hand and relic slot it takes
V.CLASS_WEAPONS = {
    WARRIOR = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 15, 16, 18 }, PALADIN = { 0, 1, 4, 5, 6, 7, 8 },
    HUNTER = { 0, 1, 2, 3, 6, 7, 8, 10, 13, 15, 16, 18 }, ROGUE = { 2, 3, 4, 7, 13, 15, 16, 18 },
    PRIEST = { 4, 10, 15, 19 }, SHAMAN = { 0, 1, 4, 5, 10, 13, 15 }, MAGE = { 7, 10, 15, 19 },
    WARLOCK = { 7, 10, 15, 19 }, DRUID = { 4, 5, 10, 13, 15 },
}
local CAN_WEAPON = {}
for class, list in pairs(V.CLASS_WEAPONS) do
    CAN_WEAPON[class] = {}
    for _, sub in ipairs(list) do CAN_WEAPON[class][sub] = true end
end
local SHIELD_CLASS = { WARRIOR = true, PALADIN = true, SHAMAN = true }
local RELIC_CLASS = { [7] = "PALADIN", [8] = "DRUID", [9] = "SHAMAN" }        -- librams, idols, totems
local DUAL_CLASS = { WARRIOR = true, ROGUE = true, HUNTER = true }

-- Can a character of this class and level put it on now?
function V.Wearable(item, class, level)
    local id, classID, subclassID, equipLoc = Instant(item)
    if not id or not SLOTS[equipLoc or ""] or not V.WEIGHTS[class or ""] then return false end
    local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local ok, _, _, _, _, req = pcall(get, item)
    req = ok and ns.Plain(req)
    if type(req) == "number" and req > (level or 0) then return false end
    if classID == 2 then
        return CAN_WEAPON[class] and CAN_WEAPON[class][subclassID or -1] or false
    elseif classID == 4 then
        if equipLoc == "INVTYPE_CLOAK" or (subclassID or 0) == 0 then return true end
        if subclassID >= 1 and subclassID <= 4 then
            local at = ARMOR_AT[class]
            return at and subclassID == ((level or 0) >= 40 and at[2] or at[1]) or false
        end
        if subclassID == 6 then return SHIELD_CLASS[class] or false end
        if RELIC_CLASS[subclassID] then return RELIC_CLASS[subclassID] == class end
        return false
    end
    return false
end

-- Your other characters this item could go to: { { who, rec }, ... } (by name)
local function Others()
    local all = ns.db and ns.db.inventory
    local I = ns.Inventory
    local me = I and I.Me and I.Me()
    if type(all) ~= "table" or not me then return {} end
    local realm = me:match("%-(.*)$")
    local mine = all[me] and all[me].faction
    local list = {}
    for who, rec in pairs(all) do
        if who ~= me and type(rec) == "table" and who:match("%-(.*)$") == realm and type(rec.worn) == "table"
            and next(rec.worn) and rec.class and rec.level
            and not (mine and rec.faction and rec.faction ~= mine) then
            list[#list + 1] = { who = who, rec = rec }
        end
    end
    table.sort(list, function(a, b) return a.who < b.who end)
    return list
end

-- Is it clearly better than what this character wears where it would go?
local function BetterFor(item, equipLoc, rec)
    local w = V.WEIGHTS[rec.class]
    local mine = V.Score(item, equipLoc, w)
    if not mine or mine <= 0 then return false end
    local slots = SLOTS[equipLoc]
    if equipLoc == "INVTYPE_WEAPON" and not DUAL_CLASS[rec.class] then slots = { 16 } end
    local id = Instant(item)
    local function score(slot)
        local worn = rec.worn[slot]
        if not worn then return nil end
        local wid, _, _, loc = Instant(worn)
        if wid and wid == id then return math.huge end             -- they wear one already
        return V.Score(worn, loc, w) or false                      -- false: the game says nothing of it
    end
    local base
    if equipLoc == "INVTYPE_2HWEAPON" then
        local main, off = score(16), score(17)
        if main == false or off == false then return false end
        if main == nil and off == nil then return true end
        base = (main or 0) + (off or 0)
    else
        for _, slot in ipairs(slots) do
            local s = score(slot)
            if s == false then return false end
            if s == nil then
                local main = rec.worn[16]
                local _, _, _, mainLoc = Instant(main)
                if not (slot == 17 and mainLoc == "INVTYPE_2HWEAPON") then return true end   -- an empty slot
            elseif base == nil or s < base then
                base = s                                           -- the weakest of its slots
            end
        end
        if base == nil then return false end
    end
    return mine > base * V.BETTER + 0.5
end

-- The other characters of yours it is an upgrade for: { { who, rec }, ... }. bound: it is yours alone.
function V.AltUpgrades(item, equipLoc, bound)
    local out = {}
    if bound or not item then return out end
    if not equipLoc then equipLoc = select(4, Instant(item)) end
    if not SLOTS[equipLoc or ""] then return out end
    for _, c in ipairs(Others()) do
        if V.Wearable(item, c.rec.class, c.rec.level) and BetterFor(item, equipLoc, c.rec) then
            out[#out + 1] = c
        end
    end
    return out
end

-- For the debug report: what the game says of your specs
function V.DescribeSpecs()
    local n, active = V.SpecGroups()
    local SI = C_SpecializationInfo
    local out = { ("groups %d, on %d; GetNumSpecGroups %s, GetActiveSpecGroup %s, C_Traits %s, GetTalentTabInfo %s, "
        .. "GetSpecialization %s, setting %s"):format(n, active, type(GetNumSpecGroups),
        type(SI and SI.GetActiveSpecGroup), type(C_Traits), type(GetTalentTabInfo), type(GetSpecialization),
        tostring(ns.db and ns.db.upgradeSpecs)) }
    for g = 1, n do
        local points, names, count = V.Trees(g)
        local parts = {}
        for tree = 1, count or 0 do
            parts[#parts + 1] = ("%d %s %s"):format(tree, tostring(names[tree]), tostring(points[tree]))
        end
        out[#out + 1] = ("group %d: %d trees, main %s: %s"):format(g, count or 0, tostring(V.MainTree(points)),
            table.concat(parts, ", "))
    end
    return out
end

local function HasUse(id)
    local get = (C_Item and C_Item.GetItemSpell) or GetItemSpell
    if not get then return false end
    local ok, name = pcall(get, id)
    return ok and name ~= nil
end

-- Consumables (potions, elixirs, flasks, food and drink, bandages...) are kept while they are the best of their
-- kind you carry: only one outclassed by a better one in your bags goes (a Minor Healing Potion when you carry
-- Healing Potions). Its kind: the same sort of consumable doing the same thing, by the name of what it does when
-- used ("Healing Potion", "Restore Mana", "Food", "Drink"); better: a higher level to use it, then a higher item
-- level. Food that leaves you Well Fed has no equal (each feeds something else), nor has anything with no use to
-- go by, nor food when we cannot tell whether it does.
V.WELL_FED = 19705                                   -- the spell "Well Fed", for its name in the game's language
local FOOD = 5                                       -- the consumables' "Food & Drink"
local function WellFed(id)
    local name = (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(V.WELL_FED))
        or (GetSpellInfo and GetSpellInfo(V.WELL_FED))
    local get = C_TooltipInfo and C_TooltipInfo.GetItemByID
    if type(name) ~= "string" or ns.IsSecret(name) or not get then return nil end      -- cannot tell
    local ok, data = pcall(get, id)
    if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then return nil end
    for _, line in ipairs(data.lines) do
        local text = ns.Plain(line.leftText)
        if type(text) == "string" and text:find(name, 1, true) then return true end
    end
    return false
end

local function ConsumableKind(id)
    local classID, subclassID = ItemKind(id)
    if classID ~= 0 then return nil end
    local spell = (C_Item and C_Item.GetItemSpell) or GetItemSpell
    local ok, use = pcall(spell, id)
    use = ok and ns.Plain(use)
    if type(use) ~= "string" then return nil end
    if subclassID == FOOD and WellFed(id) ~= false then return nil end
    return tostring(subclassID) .. ":" .. use
end

local function ConsumableRank(id)
    local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local ok, _, _, _, ilvl, req = pcall(get, id)
    ilvl, req = ok and ns.Plain(ilvl), ok and ns.Plain(req)
    return (type(req) == "number" and req or 0) * 10000 + (type(ilvl) == "number" and ilvl or 0)
end

function V.Outclassed(id)
    local kind = ConsumableKind(id)
    if not kind then return false end
    local rank = ConsumableRank(id)
    local last = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
    for bag = 0, last do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local other = C_Container.GetContainerItemID(bag, slot)
            if other and other ~= id and not ns.IsSecret(other) and ConsumableKind(other) == kind
                and ConsumableRank(other) > rank then
                return true
            end
        end
    end
    return false
end

-- A consumable of yours to keep: not grey, and not outclassed
function V.KeepConsumable(id, quality, classID)
    if classID == nil then classID = ItemKind(id) end
    if quality == nil and ns.Market then quality = ns.Market.Quality(id) end
    return classID == 0 and (quality or 1) >= 1 and not V.Outclassed(id)
end

-- The item's tooltip, its left lines as plain text (nil when the game gives none)
local function TipTexts(id)
    local get = C_TooltipInfo and C_TooltipInfo.GetItemByID
    if not get then return nil end
    local ok, data = pcall(get, id)
    if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then return nil end
    local out = {}
    for _, line in ipairs(data.lines) do
        local text = type(line) == "table" and ns.Plain(line.leftText)
        if type(text) == "string" then out[#out + 1] = text end
    end
    return out
end

-- One of the game's texts ("%d |4Charge:Charges;", "Unique (%d)") as a pattern for a whole line
local function LinePattern(text)
    if type(text) ~= "string" or ns.IsSecret(text) then return nil end
    text = text:gsub("|4[^;]*;", "")
    text = text:gsub("([%(%)%.%+%-%*%?%[%]%^%$%%])", "%%%1")
    text = text:gsub("%%%%d", "%%d+"):gsub("%%%%s", ".+"):gsub("", ".-")
    return "^" .. text .. "$"
end
-- Does a line match one of the patterns? (patterns: a list that may have holes where a game text is missing)
local function AnyLine(lines, patterns, n)
    for _, line in ipairs(lines or {}) do
        for i = 1, n do
            local p = patterns[i]
            if p and line:find(p) then return true end
        end
    end
    return false
end

-- How many go in a stack (1: it does not stack), or nil
local function StackSize(id)
    local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if not get then return nil end
    local ok, stack = pcall(function() return select(8, get(id)) end)
    stack = ok and ns.Plain(stack)
    return type(stack) == "number" and stack or nil
end

local function QualityOf(id, quality)
    if quality == nil and ns.Market then quality = ns.Market.Quality(id) end
    return quality
end

-- Something you use and keep: a Use: of its own, one to a stack and no charges to use up (a sleeping bag, a toy,
-- a hearthstone, a fishing pole, a trinket with a use). Never grey. Where the game does not say how it stacks,
-- nothing is said.
function V.Reusable(id, quality)
    quality = QualityOf(id, quality)
    if not quality or quality < 1 or not HasUse(id) or StackSize(id) ~= 1 then return false end
    local charges = { LinePattern(_G.ITEM_SPELL_CHARGES), "^%d+ [Cc]harges?$" }
    return not AnyLine(TipTexts(id), charges, 2)
end

-- Unique ("Unique", "Unique (1)" in its tooltip; not "Unique-Equipped"), not grey nor a quest item: yours to keep
function V.UniqueKeep(id, quality, classID)
    quality = QualityOf(id, quality)
    if not quality or quality < 1 then return false end
    if classID == nil then classID = ItemKind(id) end
    if classID == 12 then return false end                 -- (a quest item none of yours needs goes as before)
    local unique = { LinePattern(_G.ITEM_UNIQUE), LinePattern(_G.ITEM_UNIQUE_MULTIPLE), "^Unique$", "^Unique %(%d+%)$" }
    return AnyLine(TipTexts(id), unique, 4)
end

-- Never sold by a rule: tools, fishing poles, gear with a use of its own, anything you use and keep, unique
-- things, and consumables still the best of their kind you carry
function V.Protected(id, quality, classID, subclassID)
    if V.TOOLS[id] then return true end
    if V.Reusable(id, quality) or V.UniqueKeep(id, quality, classID) then return true end
    if classID == 0 and V.KeepConsumable(id, quality, classID) then return true end
    if classID == 2 and TOOL_SUBCLASS[subclassID or -1] then return true end
    if GEAR[classID or -1] and (quality or 0) >= 1 and HasUse(id) then return true end
    return false
end

local function BagLeftOut(bag)
    local ok, out = pcall(function()
        if bag == 0 then return C_Container.GetBackpackSellJunkDisabled() end
        return C_Container.GetBagSlotFlag(bag, Enum.BagSlotFlags.ExcludeJunkSell)
    end)
    return ok and out and true or false
end

local function InSet(bag, slot)
    local ok, inSet = pcall(C_Container.GetContainerItemEquipmentSetInfo, bag, slot)
    return ok and inSet and true or false
end

-- Should this item go? mode "rules": your junk rules. mode "quality": weapons and armor up to `quality`.
-- Your own marks come first; then tools and the like are never junk; grey is; other weapons and armor only
-- when they cannot be an upgrade for you.
function V:Decide(id, quality, classID, mode, upTo, subclassID, equipLoc, link)
    local sell = ns.db.sell
    if sell.keep[id] or sell.bank[id] then return false end
    if sell.junk[id] then return true end
    if ns.Quests and ns.Quests.ItemWant and ns.Quests.ItemWant(id) then return false end   -- a quest of yours needs it
    if V.Protected(id, quality, classID, subclassID) then return false end
    if quality == 0 then return true end
    if not GEAR[classID or -1] then return false end
    if V.MaybeUpgrade(link or id, equipLoc) then return false end
    if V.EquipmentSetOf(id) then return false end                                     -- in one of your sets
    if #V.BestFor(link or id, equipLoc) > 0 then return false end                    -- the best you own for a spec
    if #V.AltUpgrades(link or id, equipLoc) > 0 then return false end                -- for another of yours
    if quality >= 2 and ns.Professions and ns.Professions.Disenchant
        and ns.Professions.Disenchant(id, (SellPrice(link, id))) then
        return false                                                                  -- for your enchanter
    end
    if mode == "quality" then return quality <= upTo end
    return sell.gear and quality == 1
end

-- The items to sell, biggest first, and what they are worth together.
function V:Collect(mode, upTo)
    local list, total = {}, 0
    V.BeginBatch()
    local last = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
    for bag = 0, last do
        if not BagLeftOut(bag) then
            for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if info and info.itemID and not info.isLocked and not info.hasNoValue and type(info.quality) == "number" then
                    local price, name = SellPrice(info.hyperlink, info.itemID)
                    local classID, subclassID, equipLoc = ItemKind(info.itemID)
                    if price and price > 0 and not InSet(bag, slot)
                        and self:Decide(info.itemID, info.quality, classID, mode, upTo, subclassID, equipLoc,
                                        info.hyperlink) then
                        local worth = price * (info.stackCount or 1)
                        list[#list + 1] = { bag = bag, slot = slot, id = info.itemID, worth = worth,
                                            quality = info.quality, name = name or info.hyperlink or ("item " .. info.itemID) }
                        total = total + worth
                    end
                end
            end
        end
    end
    V.EndBatch()
    table.sort(list, function(a, b)
        if a.worth ~= b.worth then return a.worth > b.worth end
        if a.bag ~= b.bag then return a.bag < b.bag end
        return a.slot < b.slot
    end)
    return list, total
end

---------------------------------------------------------------------------
-- Recommended: each item where it does best
---------------------------------------------------------------------------
-- { vendor = items to sell now, total, auction = worth more there (kept), gain, skill = still a skill-up for one
-- of yours (kept), unknown = how many have no price to go by (left alone) }. An item goes to the vendor when
-- the auction house is known to pay less, or when your junk rules sell it anyway; weapons and armor that
-- cannot be an upgrade and are green at most go too when bound (the auction house cannot take them) or when the
-- auction house, read lately, had none up (nobody sells it there: a green that will not sell is junk).
function V:Recommend()
    local out = { vendor = {}, auction = {}, skill = {}, quest = {}, unknown = 0, total = 0, gain = 0 }
    V.BeginBatch()
    local M = ns.Market
    local sell = ns.db.sell
    local last = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
    for bag = 0, last do
        if not BagLeftOut(bag) then
            for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                local id = info and info.itemID
                if id and not ns.IsSecret(id) and not info.isLocked and type(info.quality) == "number"
                    and not InSet(bag, slot) then
                    local price, name = SellPrice(info.hyperlink, id)
                    local classID, subclassID, equipLoc = ItemKind(id)
                    local count = info.stackCount or 1
                    local bound = info.isBound and true or false
                    local item = { bag = bag, slot = slot, id = id, quality = info.quality, count = count,
                                   worth = (price or 0) * count, name = name or info.hyperlink or ("item " .. id) }
                    local verdict, more, want = M.Verdict(id, bound)
                    if sell.keep[id] or sell.bank[id] or (V.Protected(id, info.quality, classID, subclassID)
                                                         and not sell.junk[id]) then
                        -- yours to keep
                    elseif verdict == "quest" then
                        item.want = want                             -- (a quest of yours needs it)
                        out.quest[#out.quest + 1] = item
                    elseif verdict == "skill" or verdict == "craft" or verdict == "disenchant" then
                        item.want = want                             -- (your professions still need it)
                        out.skill[#out.skill + 1] = item
                    elseif verdict == "auction" then
                        item.gain = (more or 0) * count
                        out.auction[#out.auction + 1] = item
                        out.gain = out.gain + item.gain
                    elseif verdict == "vendor" and price and price > 0 and not info.hasNoValue then
                        local known = M.Auction(id) ~= nil
                        local gear = GEAR[classID or -1] and info.quality <= 2
                            and not V.MaybeUpgrade(info.hyperlink or id, equipLoc)
                        local boundGear = bound and gear
                        -- white and green gear nobody has up at the auction house (it was all read lately and
                        -- had none): no market for it, a vendor's
                        local unlisted = gear and not known and M.ReadLately()
                        local plain = type(want) == "table" and want.plain      -- (V.PlainlySellable)
                        if sell.junk[id] or known or boundGear or unlisted or plain
                            or self:Decide(id, info.quality, classID, "rules", nil, subclassID, equipLoc, info.hyperlink) then
                            out.vendor[#out.vendor + 1] = item
                            out.total = out.total + item.worth
                        else
                            out.unknown = out.unknown + 1
                        end
                    end
                end
            end
        end
    end
    V.EndBatch()
    table.sort(out.vendor, function(a, b) return a.worth > b.worth end)
    table.sort(out.auction, function(a, b) return a.gain > b.gain end)
    return out
end

---------------------------------------------------------------------------
-- Selling, one item at a time
---------------------------------------------------------------------------
V.log = {}                       -- what we sold this session, newest first (the vendor can buy it back)
local function Finish()
    local sold, gold, kind = V.sold or 0, V.gold or 0, V.kind
    V.queue, V.sold, V.gold, V.kind = nil, nil, nil, nil
    local after = V.after
    V.after = nil
    if sold > 0 then
        if kind == "bank" then
            say(L["deposited %d items"]:format(sold))
        elseif kind == "withdraw" then
            say(L["took %d items out of the bank"]:format(sold))
        else
            say(L["sold %d items for %s (/cchud sold lists them)"]:format(sold, ns.Money(gold)))
        end
    end
    if after then after() end
end

local Step
Step = ns.Protect(function()
    local queue = V.queue
    if not queue then return end
    local banking = V.kind == "bank" or V.kind == "withdraw"
    local open = (banking and (V.bankOpen or (ns.Inventory and ns.Inventory.bankOpen))) or (not banking and V.merchantOpen)
    if not open or #queue == 0 then return Finish() end
    local item = table.remove(queue, 1)
    local info = C_Container.GetContainerItemInfo(item.bag, item.slot)
    if info and info.itemID == item.id and not info.isLocked then      -- still the item we decided on
        C_Container.UseContainerItem(item.bag, item.slot)
        V.sold, V.gold = V.sold + 1, V.gold + item.worth
        if V.kind == "sell" then
            table.insert(V.log, 1, { name = item.name, worth = item.worth })
            if #V.log > 30 then table.remove(V.log) end
        end
    end
    C_Timer.After(SELL_GAP, Step)
end)

function V:Sell(list)
    if self.queue then return false end
    if #list == 0 then say(L["Nothing to sell."]); return false end
    self.queue, self.sold, self.gold, self.kind = list, 0, 0, "sell"
    Step()
    return true
end

ns.RegisterSetting({
    key = "depositMatching", kind = "boolean", default = true, command = "depositmatch", section = "Bags, bank and vendor",
    label = "Deposit also puts away what the bank already holds",
    tip = "a deposit moves every item your bank already has some of (materials, potions...), on top of the items you marked for the bank; never grey items, tools or items you marked as junk or kept",
})

-- Would a deposit take this item because the bank already holds some? Not grey items, tools, gear you could
-- use, or items you marked yourself (junk, kept)
function V.Matches(id, quality, held)
    if not (held and held[id]) then return false end
    local sell = ns.db.sell
    if sell.junk[id] or sell.keep[id] or (quality or 1) == 0 then return false end
    local classID, subclassID = ItemKind(id)
    return not V.Protected(id, quality, classID, subclassID)
end

-- Everything in the bags that is marked for the bank, and (when turned on) what the bank already holds
function V:CollectBank()
    local list = {}
    local held = ns.db.depositMatching and ns.Inventory and ns.Inventory.BankIds(true) or nil
    local last = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
    for bag = 0, last do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local id = info and info.itemID
            if id and not ns.IsSecret(id) and not info.isLocked
                and (ns.db.sell.bank[id] or V.Matches(id, info.quality, held)) then
                list[#list + 1] = { bag = bag, slot = slot, id = id, worth = 0 }
            end
        end
    end
    return list
end

-- Out of the bank: what you already carry some of (to top your bags back up: materials, potions, food...), never
-- what you marked for the bank or as junk
function V:CollectWithdraw()
    local carried, list = {}, {}
    local last = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
    for bag = 0, last do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local id = C_Container.GetContainerItemID(bag, slot)
            if id and not ns.IsSecret(id) then carried[id] = true end
        end
    end
    local sell = ns.db.sell
    local I = ns.Inventory
    for _, bag in ipairs(I and I.BankBags and I.BankBags() or {}) do
        local ok, slots = pcall(C_Container.GetContainerNumSlots, bag)
        for slot = 1, (ok and slots) or 0 do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local id = info and info.itemID
            if id and not ns.IsSecret(id) and not info.isLocked and carried[id] and not sell.bank[id] and not sell.junk[id] then
                list[#list + 1] = { bag = bag, slot = slot, id = id, worth = 0 }
            end
        end
    end
    return list
end

function V:Withdraw()
    if not (self.bankOpen or (ns.Inventory and ns.Inventory.bankOpen)) then say(L["Open the bank first."]); return false end
    if self.queue then return false end
    local list = self:CollectWithdraw()
    if #list == 0 then say(L["Nothing to take out: the bank holds none of what you carry."]); return false end
    self.queue, self.sold, self.gold, self.kind = list, 0, 0, "withdraw"
    Step()
    return true
end

---------------------------------------------------------------------------
-- Crafting materials (the game's Trade Goods), in and out of the bank: all at once, or one kind at a time (the
-- game's own kinds and names: Metal & Stone, Cloth, Herb, Leather...). Never grey items or what you marked as
-- junk. Out of the bank: no more stacks than your bags have room for.
---------------------------------------------------------------------------
V.MATERIALS = 7                                        -- the game's Trade Goods item class

function V.KindName(sub)
    local get = (C_Item and C_Item.GetItemSubClassInfo) or rawget(_G, "GetItemSubClassInfo")
    local ok, name = false, nil
    if get then ok, name = pcall(get, V.MATERIALS, sub) end
    if ok and type(name) == "string" and name ~= "" and not ns.IsSecret(name) then return name end
    return L["Materials"] .. " " .. tostring(sub)
end

local function BagList(where)
    if where == "bank" then
        local I = ns.Inventory
        return I and I.BankBags and I.BankBags() or {}
    end
    local list = {}
    for bag = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4 do list[#list + 1] = bag end
    return list
end

-- The materials in your bags or the bank ({ bag, slot, id, sub }), of one kind (sub) or all
function V.Materials(where, sub)
    local list, sell = {}, ns.db.sell
    for _, bag in ipairs(BagList(where)) do
        local ok, slots = pcall(C_Container.GetContainerNumSlots, bag)
        for slot = 1, (ok and slots) or 0 do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local id = info and info.itemID
            if id and not ns.IsSecret(id) and not info.isLocked and (info.quality or 1) > 0 and not sell.junk[id] then
                local classID, subclassID = ItemKind(id)
                if classID == V.MATERIALS and (sub == nil or subclassID == sub) then
                    list[#list + 1] = { bag = bag, slot = slot, id = id, sub = subclassID or 0, worth = 0 }
                end
            end
        end
    end
    return list
end

-- The kinds there, most stacks first: { { sub, name, count } }
function V.MaterialKinds(where)
    local by, kinds = {}, {}
    for _, m in ipairs(V.Materials(where)) do
        local k = by[m.sub]
        if not k then
            k = { sub = m.sub, name = V.KindName(m.sub), count = 0 }
            by[m.sub] = k
            kinds[#kinds + 1] = k
        end
        k.count = k.count + 1
    end
    table.sort(kinds, function(a, b)
        if a.count ~= b.count then return a.count > b.count end
        return a.name < b.name
    end)
    return kinds
end

local function FreeBagSlots()
    local free = 0
    for _, bag in ipairs(BagList("bags")) do
        local ok, slots = pcall(C_Container.GetContainerNumSlots, bag)
        for slot = 1, (ok and slots) or 0 do
            if not C_Container.GetContainerItemID(bag, slot) then free = free + 1 end
        end
    end
    return free
end

-- Move materials: "bank" puts yours in, "bags" takes the bank's out; sub: one kind, or nil for all
function V:MoveMaterials(to, sub)
    if not (self.bankOpen or (ns.Inventory and ns.Inventory.bankOpen)) then say(L["Open the bank first."]); return false end
    if self.queue then return false end
    local list = V.Materials(to == "bank" and "bags" or "bank", sub)
    if to == "bags" then
        local room = FreeBagSlots()
        if room == 0 and #list > 0 then say(L["Your bags are full."]); return false end
        while #list > room do table.remove(list) end
    end
    if #list == 0 then
        say(to == "bank" and L["No materials in your bags to put away."] or L["No materials in the bank to take out."])
        return false
    end
    self.queue, self.sold, self.gold, self.kind = list, 0, 0, to == "bank" and "bank" or "withdraw"
    Step()
    return true
end

-- The choices, for the bag window's Y menu and the bank window's Materials button: { { text, fn } }
function V.MaterialChoices(to)
    local from = to == "bank" and "bags" or "bank"
    local kinds = V.MaterialKinds(from)
    local out = {}
    if #kinds == 0 then return out end
    local all = 0
    for _, k in ipairs(kinds) do all = all + k.count end
    out[1] = { text = L["All materials (%d)"]:format(all), fn = function() V:MoveMaterials(to, nil) end }
    for _, k in ipairs(kinds) do
        out[#out + 1] = { text = ("%s (%d)"):format(k.name, k.count), fn = function() V:MoveMaterials(to, k.sub) end }
    end
    return out
end

-- The bank window's Materials list (with a mouse): deposit and withdraw, each kind a row
local function MaterialsList(anchor)
    local list = V.materialsList
    if not list then
        list = CreateFrame("Frame", nil, UIParent)
        list:SetFrameStrata("DIALOG")
        list:SetSize(230, 40)
        list:EnableMouse(true)
        list.back = list:CreateTexture(nil, "BACKGROUND")
        list.back:SetColorTexture(0.03, 0.04, 0.07, 0.94)
        list.back:SetAllPoints(list)
        list.rows = {}
        list:Hide()                                        -- (made hidden: the first click opens it)
        V.materialsList = list
    end
    if list:IsShown() then list:Hide(); return end
    local rows = {}
    for _, to in ipairs({ "bank", "bags" }) do
        local choices = V.MaterialChoices(to)
        rows[#rows + 1] = { head = to == "bank" and L["Deposit materials"] or L["Withdraw materials"] }
        if #choices == 0 then
            rows[#rows + 1] = { text = to == "bank" and L["No materials in your bags to put away."]
                or L["No materials in the bank to take out."], muted = true }
        end
        for _, c in ipairs(choices) do rows[#rows + 1] = c end
    end
    for i, r in ipairs(rows) do
        local b = list.rows[i]
        if not b then
            b = CreateFrame("Button", nil, list)
            b:SetSize(218, 20)
            b:SetPoint("TOPLEFT", list, "TOPLEFT", 6, -6 - (i - 1) * 21)
            b.text = ns.FontString(b, 11, "LEFT")
            b.text:SetPoint("LEFT", b, "LEFT", 4, 0)
            b.hl = b:CreateTexture(nil, "HIGHLIGHT")
            b.hl:SetColorTexture(1, 1, 1, 0.12)
            b.hl:SetAllPoints(b)
            list.rows[i] = b
        end
        b.text:SetText(r.head and ("|cffffd100" .. r.head .. "|r") or (r.muted and ("|cff999999" .. r.text .. "|r") or r.text))
        b:SetScript("OnClick", r.fn and ns.Protect(function() list:Hide(); r.fn() end) or nil)
        b:EnableMouse(r.fn ~= nil)
        b:Show()
    end
    for i = #rows + 1, #list.rows do list.rows[i]:Hide() end
    list:SetHeight(#rows * 21 + 10)
    list:ClearAllPoints()
    list:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
    list:Show()
end
V.MaterialsList = MaterialsList

---------------------------------------------------------------------------
-- Quick Deposit, Quick Withdraw and Materials, as buttons beside the bank's search box (shown with the bank)
---------------------------------------------------------------------------
local function BankButton(parent, text, tip, fn)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(76, 22)
    b:SetText(text)
    b:SetScript("OnClick", ns.Protect(fn))
    b:SetScript("OnEnter", function(self)
        local t = ns.Tooltip and ns.Tooltip.Own()
        if not t then return end
        t:SetOwner(self, "ANCHOR_TOP")
        t:SetText(tip, 1, 1, 1, 1, true)
        t:Show()
    end)
    b:SetScript("OnLeave", function()
        local t = ns.Tooltip and ns.Tooltip.Own()
        if t then t:Hide() end
    end)
    return b
end

function V:BankButtons(show)
    local bank = _G.BankFrame
    if not show then
        if self.bankButtons then for _, b in pairs(self.bankButtons) do b:Hide() end end
        if V.materialsList then V.materialsList:Hide() end
        return
    end
    if type(bank) ~= "table" or not bank.CreateTexture then return end
    if not self.bankButtons then
        local withdraw = BankButton(bank, L["Quick Withdraw"],
            L["take out of the bank what you already carry some of (materials, potions, food), to top your bags up"],
            function() V:Withdraw() end)
        local deposit = BankButton(bank, L["Quick Deposit"],
            L["put in the bank what it already holds some of, and what you marked for it"],
            function() V:Deposit() end)
        local materials
        materials = BankButton(bank, L["Materials"],
            L["crafting materials in or out of the bank: all of them, or one kind at a time (metal and stone, cloth, herbs...)"],
            function() MaterialsList(materials) end)
        for _, b in ipairs({ withdraw, deposit, materials }) do
            local fs = b:GetFontString()
            local w = fs and tonumber(fs:GetStringWidth()) or 0
            b:SetWidth(math.max(76, w + 20))
        end
        local box = _G.BankItemSearchBox or rawget(bank, "SearchBox")
        if type(box) == "table" and box.GetObjectType then
            materials:SetPoint("RIGHT", box, "LEFT", -10, 0)
        else
            materials:SetPoint("TOPRIGHT", bank, "TOPRIGHT", -60, -32)
        end
        withdraw:SetPoint("RIGHT", materials, "LEFT", -4, 0)
        deposit:SetPoint("RIGHT", withdraw, "LEFT", -4, 0)
        self.bankButtons = { deposit = deposit, withdraw = withdraw, materials = materials }
    end
    for _, b in pairs(self.bankButtons) do b:Show() end
end

-- Smart sell, on the vendor window beside the game's own "Sell all junk" (which stays the game's): the
-- recommended sale (what a vendor pays best for, junk included), listed and confirmed first. Before the auction
-- house has been read it asks with the presets.
function V:SmartSell()
    if not self.merchantOpen then say(L["Open a vendor first."]); return end
    V.DefinePopups()                                    -- (defined further down)
    if ns.Market and ns.Market.HasData() then self:ConfirmAdvised() else self:Prompt() end
end

function V:MerchantButton(show)
    local merchant = _G.MerchantFrame
    if not show then
        if self.smartButton then self.smartButton:Hide() end
        return
    end
    if type(merchant) ~= "table" or not merchant.CreateTexture then return end
    if not self.smartButton then
        local b = BankButton(merchant, L["Smart sell"],
            L["sell what a vendor pays best for: junk, and what the auction house would not do better with (listed and confirmed first); what is worth more at the auction house or still needed by your professions stays"],
            function() V:SmartSell() end)
        b:SetWidth(96)
        -- in the row of the merchant's tabs, after its last one (Merchant, Buyback): the bottom of the window is
        -- full (repairs, Sell Junk, the item to buy back), and the game's own buttons stay as they are
        local last
        for i = 1, 4 do
            local tab = _G["MerchantFrameTab" .. i]
            if type(tab) == "table" and tab.GetObjectType then last = tab end
        end
        if last then
            b:SetPoint("LEFT", last, "RIGHT", 6, 0)
        else
            b:SetPoint("TOPRIGHT", merchant, "BOTTOMRIGHT", -8, -4)
        end
        self.smartButton = b
    end
    self.smartButton:Show()
end

function V:Deposit(quiet)
    if not (self.bankOpen or (ns.Inventory and ns.Inventory.bankOpen)) then say(L["Open the bank first."]); return false end
    if self.queue then return false end
    local list = self:CollectBank()
    if #list == 0 then
        if not quiet then
            say(ns.db.depositMatching and L["Nothing to deposit: your bank holds none of what you carry, and nothing is marked for it."]
                or L["Nothing is marked for the bank. Point at an item and use Mark item."])
        end
        return false
    end
    self.queue, self.sold, self.gold, self.kind = list, 0, 0, "bank"
    Step()
    return true
end

---------------------------------------------------------------------------
-- Asking what to sell (in a window of the HUD's own: A, X, Y and B answer it)
---------------------------------------------------------------------------
local function Names(list, max)
    local names = {}
    for i = 1, math.min(#list, max) do names[i] = list[i].name end
    local text = table.concat(names, ", ")
    if #list > max then text = text .. ", ..." end
    return text
end

local DefinePopups

local function OnlyGrey(list)
    for _, item in ipairs(list) do
        if item.quality ~= 0 then return false end
    end
    return true
end

local function Later(fn) C_Timer.After(0, fn) end       -- let the dialog that was answered close first

local function Count(list, gold) return L["%d items, %s"]:format(#list, ns.Money(gold)) end

-- "Peacebloom (Alchemy 120/150)", "Copper Ore (Blacksmithing 80/150, Sol)"
-- The items of a list, one line each: its icon, its name in its quality's colour, and how many ("x 20"),
-- stacks of the same item together, in the list's order; at most max lines, then how many more
V.LIST_MAX = 8
local function ItemLines(list, max, extra)
    local order, byId = {}, {}
    for _, item in ipairs(list) do
        local key = item.id or item.name
        local e = byId[key]
        if not e then
            e = { item = item, count = 0 }
            byId[key] = e
            order[#order + 1] = e
        end
        e.count = e.count + (item.count or 1)
    end
    local lines = {}
    for i = 1, math.min(#order, max) do
        local e = order[i]
        local item = e.item
        local icon = item.id and ((C_Item and C_Item.GetItemIconByID) or GetItemIcon)
        local okI, tex = pcall(icon or error, item.id)
        local q = item.quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[item.quality]
        local name = tostring(item.name)
        if q and q.hex then name = q.hex .. name .. "|r" end
        local line = ((okI and tex) and ("|T%s:14:14|t "):format(tex) or "") .. name
        if e.count > 1 then line = line .. ("  x %d"):format(e.count) end
        local more = extra and extra(item)
        if more then line = line .. "  |cffb8c2db" .. more .. "|r" end
        lines[#lines + 1] = "   " .. line
    end
    if #order > max then lines[#lines + 1] = "   |cffb8c2db" .. L["...and %d more"]:format(#order - max) .. "|r" end
    return table.concat(lines, "\n")
end
V.ItemLines = ItemLines

-- A heading in gold, then its items
local function Section(title, list, extra)
    return "|cffffd24a" .. title .. "|r\n" .. ItemLines(list, V.LIST_MAX, extra)
end
V.Section = Section

local function SkillNames(list, max)
    local names = {}
    for i = 1, math.min(#list, max) do
        names[i] = ("%s (%s)"):format(list[i].name, ns.Professions.Words(list[i].want))
    end
    local text = table.concat(names, ", ")
    if #list > max then text = text .. ", ..." end
    return text
end

function V:Confirm(list, total)
    if #list == 0 then say(L["Nothing to sell."]); return end
    self.pending = list
    ns.Dialog.Show("CCHUD_SELL_CONFIRM", #list, Section(L["Sell to the vendor: %s"]:format(ns.Money(total)), list))
end

function V:AskQuality()
    local common, commonGold = self:Collect("quality", 1)
    local uncommon, uncommonGold = self:Collect("quality", 2)
    self.choice = { { common, commonGold }, { uncommon, uncommonGold } }
    ns.Dialog.Show("CCHUD_SELL_QUALITY", ("%d, %s"):format(#common, ns.Money(commonGold)),
        ("%d, %s"):format(#uncommon, ns.Money(uncommonGold)))
end

-- The recommended sale: what goes, with what stays and why under it
function V:ConfirmAdvised()
    if not (ns.Market and ns.Market.HasData()) then
        say(L["No auction house prices yet: visit the auction house once."])
        return
    end
    local r = self:Recommend()
    if #r.vendor == 0 then say(L["Nothing to sell."]); return end
    -- what the vendor gets, then what stays and why, each a heading over its items
    local text = Section(L["Sell to the vendor: %s"]:format(ns.Money(r.total)), r.vendor)
    if #r.auction > 0 then text = text .. "\n\n" .. Section(L["Kept: worth more at the auction house"], r.auction) end
    if #r.skill > 0 then
        text = text .. "\n\n" .. Section(L["Kept for your professions"], r.skill,
            function(item) return item.want and ns.Professions.Words(item.want) or nil end)
    end
    if #r.quest > 0 then text = text .. "\n\n" .. Section(L["Kept for your quests"], r.quest) end
    self.pending = r.vendor
    ns.Dialog.Show("CCHUD_SELL_CONFIRM", #r.vendor, text)
end

-- What to sell? Presets until the auction house has been read; then the recommended sale first
function V:Prompt()
    if not self.merchantOpen then say(L["Open a vendor first."]); return end
    if self.queue then return end
    DefinePopups()
    local junk, total = self:Collect("rules")
    self.junk, self.junkTotal = junk, total
    if ns.Market and ns.Market.HasData() then
        local r = self:Recommend()
        ns.Dialog.Show("CCHUD_SELL_ADVISED", Count(r.vendor, r.total), #r.auction, #r.skill, Count(junk, total))
        return
    end
    local white, whiteGold = self:Collect("quality", 1)
    local green, greenGold = self:Collect("quality", 2)
    self.choice = { { white, whiteGold }, { green, greenGold } }
    ns.Dialog.Show("CCHUD_SELL", Count(junk, total), Count(white, whiteGold), Count(green, greenGold))
end

-- Junk by the rules. Grey items go straight away, like the game's own button; anything else is confirmed.
function V:SellJunk()
    local junk, total = self:Collect("rules")
    if OnlyGrey(junk) then return self:Sell(junk) end
    self:Confirm(junk, total)
end

-- Under the question: your professions whose window has not been opened yet (their skill-ups cannot count),
-- and for the recommended sale, that the estimates are only as good as what the windows have shown
local function Unread()
    local list = ns.Professions and ns.Professions.Unread() or {}
    if #list == 0 then return nil end
    return L["Open these profession windows once so their skill-ups count: %s"]:format(table.concat(list, ", "))
end
V.Unread = Unread
local function AdvisedFooter()
    local lines = { L["For the best estimates, open your profession windows and the auction house now and then."] }
    local unread = Unread()
    if unread then lines[#lines + 1] = unread end
    return table.concat(lines, "\n")
end

-- (asked in a window of our own, Core.lua: never in the game's dialog box)
function DefinePopups()
    if V.popups then return end
    V.popups = true
    local function dialog(extra) return extra end
    local Define = ns.Dialog.Define
    Define("CCHUD_SELL", dialog({
        text = L["What to sell?\n\nJunk: %s\nWith white weapons and armor: %s\nWith green weapons and armor: %s\n\nAfter a visit to the auction house, recommendations are offered here too."],
        button1 = L["Junk"], button2 = CANCEL or "Cancel", button3 = L["+ White gear"], button4 = L["+ Green gear"],
        OnAccept = function() Later(function() V:SellJunk() end) end,
        OnAlt = function() local c = V.choice[1]; Later(function() V:Confirm(c[1], c[2]) end) end,
        OnExtra = function() local c = V.choice[2]; Later(function() V:Confirm(c[1], c[2]) end) end,
        Footer = Unread,
    }))
    Define("CCHUD_SELL_ADVISED", dialog({
        text = L["What to sell?\n\nRecommended: %s to the vendor. %d items stay because they are worth more at the auction house, %d because your professions still need them.\nJunk only: %s"],
        button1 = L["Recommended"], button2 = CANCEL or "Cancel", button3 = L["Junk"], button4 = L["By quality"],
        OnAccept = function() Later(function() V:ConfirmAdvised() end) end,
        OnAlt = function() Later(function() V:SellJunk() end) end,
        OnExtra = function() Later(function() V:AskQuality() end) end,
        Footer = AdvisedFooter,
    }))
    Define("CCHUD_SELL_QUALITY", dialog({
        text = L["Sell weapons and armor up to which quality?\n\nCommon (white): %s\nUncommon (green): %s"],
        button1 = L["Common"], button2 = CANCEL or "Cancel", button3 = L["Uncommon"],
        OnAccept = function() local c = V.choice[1]; Later(function() V:Confirm(c[1], c[2]) end) end,
        OnAlt = function() local c = V.choice[2]; Later(function() V:Confirm(c[1], c[2]) end) end,
    }))
    Define("CCHUD_SELL_CONFIRM", dialog({
        text = L["Sell %d items?\n\n%s"], list = true,
        button1 = L["Sell"], button2 = CANCEL or "Cancel",
        OnAccept = function() local list = V.pending; V.pending = nil; if list then V:Sell(list) end end,
        OnCancel = function() V.pending = nil end,
    }))
end
V.DefinePopups = DefinePopups

---------------------------------------------------------------------------
-- The item you are pointing at
---------------------------------------------------------------------------
local function PointedSlot()
    local frame
    if GetMouseFoci then
        local foci = GetMouseFoci()
        frame = foci and foci[1]
    elseif GetMouseFocus then
        frame = GetMouseFocus()
    end
    for _ = 1, 4 do
        if type(frame) ~= "table" then return nil end
        if frame.GetBagID and frame.GetID then
            local ok, bag = pcall(frame.GetBagID, frame)
            local ok2, slot = pcall(frame.GetID, frame)
            if ok and ok2 and type(bag) == "number" and type(slot) == "number" and slot > 0 then return bag, slot end
        end
        frame = frame.GetParent and frame:GetParent()
    end
end
V.PointedSlot = PointedSlot

-- Sell at a vendor, deposit or withdraw at a banker, hand over in a trade, attach to a letter. Does nothing
-- elsewhere (so it can never use an item).
V.Pointed = PointedSlot

function V:QuickMove()
    if not self.active then return end
    if InCombatLockdown() then return end
    if not self:MoveOpen() then
        say(L["Quick move works at a vendor (sell), a banker (deposit, withdraw), in a trade or at the mailbox."])
        return
    end
    local bag, slot = PointedSlot()
    if not bag then say(L["Point at an item first."]); return end
    C_Container.UseContainerItem(bag, slot)
end

-- Is a window open where quick move moves things?
-- Is a window open where R3 moves things? Each is noted open by its event, and still has to be in sight: an event
-- for its closing that never came (the mailbox's, on some games) left R3 taken for good, away from the game's ping.
V.MOVE_WINDOWS = { merchantOpen = "MerchantFrame", bankOpen = "BankFrame", tradeOpen = "TradeFrame",
                   mailOpen = "MailFrame" }
function V:MoveOpen()
    local open = false
    for flag, name in pairs(V.MOVE_WINDOWS) do
        if self[flag] then
            local f = _G[name]
            local ok, shown = false, nil
            if type(f) == "table" and f.IsShown then ok, shown = pcall(f.IsShown, f) end
            if not ok or ns.IsSecret(shown) then open = true                 -- (no window to look at: as noted)
            elseif shown then open = true
            else self[flag] = false end                                       -- closed, though nothing said so
        end
    end
    return open
end

-- Cycle the item you are pointing at: no mark -> junk (always sold) -> kept (never sold) -> bank -> no mark.
function V:MarkItem(id)
    if not self.active and not id then return end
    if not id then
        local bag, slot = PointedSlot()
        if not bag then say(L["Point at an item first."]); return end
        id = C_Container.GetContainerItemID(bag, slot)
        if not id then return end
    end
    local sell = ns.db.sell
    local _, name = SellPrice(nil, id)
    name = name or ("item " .. id)
    if sell.junk[id] then
        sell.junk[id], sell.keep[id] = nil, true
        say(L["%s: kept, never sold"]:format(name))
    elseif sell.keep[id] then
        sell.keep[id], sell.bank[id] = nil, true
        say(L["%s: bank, deposited when you ask (never sold)"]:format(name))
    elseif sell.bank[id] then
        sell.bank[id] = nil
        say(L["%s: no mark"]:format(name))
    else
        sell.junk[id] = true
        say(L["%s: junk, sold with the rest"]:format(name))
    end
end

-- Key bindings (Bindings.xml)
BINDING_HEADER_CCHUD = "ControllerCam"
BINDING_NAME_CCHUD_QUICKMOVE = L["Quick move: sell, bank, trade or mail the item you point at"]
BINDING_NAME_CCHUD_MARKITEM = L["Mark the item: junk / kept / bank / no mark"]
function ControllerCamHUD_QuickMove() ns.Protect(function() V:QuickMove() end)() end
function ControllerCamHUD_MarkItem() ns.Protect(function() V:MarkItem() end)() end
BINDING_NAME_CCHUD_DEPOSIT = L["Deposit: put in the bank what it already holds, and what you marked for it"]
function ControllerCamHUD_Deposit() ns.Protect(function() V:Deposit() end)() end
BINDING_NAME_CCHUD_WITHDRAW = L["Withdraw: take out of the bank what you already carry some of"]
BINDING_NAME_CCHUD_SMARTSELL = L["Smart sell: what a vendor pays best for, listed and confirmed first"]
function ControllerCamHUD_SmartSell() ns.Protect(function() V:SmartSell() end)() end
function ControllerCamHUD_Withdraw() ns.Protect(function() V:Withdraw() end)() end

---------------------------------------------------------------------------
-- Turning on and off
---------------------------------------------------------------------------
-- When a vendor opens: grey items and the ones you marked as junk go by themselves; anything else your rules
-- count as junk (white weapons and armor) is listed and asked about first, never sold silently
function V:AutoSell()
    local junk = self:Collect("rules")
    local sure, ask, askTotal = {}, {}, 0
    for _, item in ipairs(junk) do
        if item.quality == 0 or ns.db.sell.junk[item.id] then
            sure[#sure + 1] = item
        else
            ask[#ask + 1] = item
            askTotal = askTotal + item.worth
        end
    end
    local function Ask() if #ask > 0 then self:Confirm(ask, askTotal) end end
    if #sure > 0 then
        self.after = Ask
        self:Sell(sure)
    else
        Ask()
    end
end

ns.RegisterCommand("sold", function()
    if #V.log == 0 then ns.Say(L["Nothing sold yet this session."]); return end
    for _, item in ipairs(V.log) do print(("  %s  %s"):format(tostring(item.name), ns.Money(item.worth))) end
    ns.Say(L["A vendor's Buyback tab buys these back until you log out."])
end, "/cchud sold", "list what was sold for you this session, to buy something back")

---------------------------------------------------------------------------
-- Repairs: everything, as soon as a vendor who repairs opens (from the guild bank first when allowed)
---------------------------------------------------------------------------
ns.RegisterSetting({
    key = "autoRepair", kind = "boolean", default = true, command = "autorepair", section = "Bags, bank and vendor",
    label = "Repair at vendors", tip = "repair everything as soon as a vendor who repairs opens",
})
ns.RegisterSetting({
    key = "repairGuild", kind = "boolean", default = false, command = "repairguild", section = "Bags, bank and vendor",
    label = "Repair from the guild bank", tip = "pay for repairs from the guild bank when your guild allows it, your own gold otherwise",
})

function V:Repair()
    if not (CanMerchantRepair and CanMerchantRepair() and GetRepairAllCost and RepairAllItems) then return false end
    local cost, can = GetRepairAllCost()
    if ns.IsSecret(cost) or type(cost) ~= "number" or cost <= 0 or can == false then return false end
    if ns.db.repairGuild and CanGuildBankRepair and CanGuildBankRepair() then
        local limit = GetGuildBankWithdrawMoney and GetGuildBankWithdrawMoney()
        if type(limit) == "number" and (limit < 0 or limit >= cost) then
            RepairAllItems(true)
            V.repaired = { cost = cost, at = GetTime() }             -- (the vendor mentions it: Narrative.lua)
            say(L["Repaired for %s from the guild bank"]:format(ns.Money(cost)))
            return true
        end
    end
    if (GetMoney() or 0) < cost then
        say(L["Not enough gold to repair everything (%s)."]:format(ns.Money(cost)))
        return false
    end
    RepairAllItems(false)
    V.repaired = { cost = cost, at = GetTime() }
    say(L["Repaired for %s"]:format(ns.Money(cost)))
    return true
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", ns.Protect(function(_, event)
    if event == "MERCHANT_SHOW" then
        V.merchantOpen = true
        V:MerchantButton(true)
        if ns.db.autoRepair then V:Repair() end
        if ns.db.sell.auto then V:AutoSell() end
    elseif event == "MERCHANT_CLOSED" then
        V.merchantOpen = false
    elseif event == "BANKFRAME_OPENED" then
        V.bankOpen = true
        V:BankButtons(true)
        if ns.db.sell.deposit then V:Deposit(true) end
    elseif event == "BANKFRAME_CLOSED" then
        V.bankOpen = false
    elseif event == "TRADE_SHOW" then V.tradeOpen = true
    elseif event == "TRADE_CLOSED" then V.tradeOpen = false
    elseif event == "MAIL_SHOW" then V.mailOpen = true
    elseif event == "MAIL_CLOSED" then V.mailOpen = false
    end
end))

-- The game's own "Sell all junk" button is the game's and is left alone: it sells grey items as the game does.
-- What to sell by your marks and by quality is asked by /cchud sell (and its key binding) in our own window.
function V:Apply(run)
    local want = run and ns.db.vendor and true or false
    if want and not self.active then
        self.active = true
        DefinePopups()
        for _, event in ipairs({ "MERCHANT_SHOW", "MERCHANT_CLOSED", "BANKFRAME_OPENED", "BANKFRAME_CLOSED",
                                 "TRADE_SHOW", "TRADE_CLOSED", "MAIL_SHOW", "MAIL_CLOSED" }) do
            pcall(events.RegisterEvent, events, event)
        end
    elseif not want and self.active then
        self.active = false
        events:UnregisterAllEvents()
        self.queue, self.pending = nil, nil
        self:BankButtons(false)
        self:MerchantButton(false)
        if ns.Dialog.visible and ns.Dialog.visible.which:find("^CCHUD_SELL") then ns.Dialog.Close("override") end
    end
end

function V.ParseQuality(text)
    local n = tonumber(text)
    if n == nil then n = QUALITY_WORD[text or ""] end
    if n and V.QUALITY[n] then return n end
end

ns.RegisterModule("vendor", V)
