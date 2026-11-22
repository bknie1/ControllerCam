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

local function Fits(id)
    if C_PlayerInfo and C_PlayerInfo.CanUseItem then
        local ok, can = pcall(C_PlayerInfo.CanUseItem, id)
        if ok and can == false then return false end
    end
    local stats = (C_Item and C_Item.GetItemStats) or GetItemStats
    local spec = GetSpecialization and GetSpecialization()
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

-- An item's score for you, or nil when the game says nothing of its stats
function V.Score(item, equipLoc)
    local get = (C_Item and C_Item.GetItemStats) or GetItemStats
    local w = V.WEIGHTS[Class() or ""]
    if not (get and w and item) then return nil end
    local link = item
    if type(item) == "number" then
        local info = (C_Item and C_Item.GetItemInfo) or GetItemInfo
        link = info and select(2, info(item)) or ("item:" .. item)
    end
    local ok, stats = pcall(get, link)
    if not ok or type(stats) ~= "table" then return nil end
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
local function ForYou(item, equipLoc)
    local id, classID, subclassID = Instant(item)
    if not id then return true end
    if not Fits(id) then return false end
    if classID == 4 and equipLoc ~= "INVTYPE_CLOAK" and (subclassID or 0) >= 1 and subclassID <= 4 then
        local kind = V.ArmorKind()
        if kind and subclassID ~= kind then return false end         -- lighter (or heavier) than you wear
    end
    return true
end
V.ForYou = ForYou

-- What you wear where it would go, scored: the weakest of its slots (a ring, a trinket, a one-hander), or for
-- a two-hander both hands together. Returns the score, the worn item's level, and whether a slot is empty.
local function Worn(equipLoc, slots)
    local scores, levels, empty = {}, {}, false
    for _, slot in ipairs(slots) do
        local worn = GetInventoryItemLink and GetInventoryItemLink("player", slot)
        if not worn then
            local main = GetInventoryItemLink and GetInventoryItemLink("player", 16)
            local _, _, _, mainLoc = Instant(main)
            if not (slot == 17 and mainLoc == "INVTYPE_2HWEAPON") then empty = true end
        else
            local _, _, _, wornLoc = Instant(worn)
            scores[#scores + 1] = V.Score(worn, wornLoc)
            levels[#levels + 1] = ItemLevel(worn)
        end
    end
    local score, level
    if equipLoc == "INVTYPE_2HWEAPON" then
        local off = GetInventoryItemLink and GetInventoryItemLink("player", 17)
        score = scores[1]
        if score and off then
            local _, _, _, offLoc = Instant(off)
            score = score + (V.Score(off, offLoc) or 0)
        end
        level = levels[1]
    else
        for i, sc in ipairs(scores) do if score == nil or sc < score then score, level = sc, levels[i] end end
        if score == nil then for _, l in ipairs(levels) do if level == nil or l < level then level = l end end end
    end
    return score, level, empty
end

-- Clearly better than what you wear: worth putting on (gear for you, scoring a good bit above what you wear
-- there, or by item level where the game says nothing of the stats)
function V.Upgrade(item, equipLoc)
    local slots = SLOTS[equipLoc or ""]
    if not slots or not ForYou(item, equipLoc) then return false end
    local id = Instant(item)
    for _, slot in ipairs(slots) do
        local worn = GetInventoryItemLink and GetInventoryItemLink("player", slot)
        if worn and id and Instant(worn) == id then return false end  -- what you wear yourself
    end
    local wornScore, wornLevel, empty = Worn(equipLoc, slots)
    if empty then return true end
    local mine = V.Score(item, equipLoc)
    if mine and wornScore then return mine > wornScore * V.BETTER + 0.5 end
    local lvl = ItemLevel(item)
    return (lvl and wornLevel and lvl > wornLevel) and true or false
end

-- Could it be as good as what you wear there? Then it is never junk. Only gear for you counts; gear you cannot
-- use, of another class's main stat or another kind of armor goes like anything else.
function V.MaybeUpgrade(item, equipLoc)
    local slots = SLOTS[equipLoc or ""]
    if not slots then return false end
    if not ForYou(item, equipLoc) then return false end
    local wornScore, wornLevel, empty = Worn(equipLoc, slots)
    if empty then return true end
    local mine = V.Score(item, equipLoc)
    if mine and wornScore then return mine >= wornScore * V.ABOUT end
    local lvl = ItemLevel(item)
    if not lvl or not wornLevel then return true end                  -- cannot tell: kept
    return lvl >= wornLevel
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

-- Never sold by a rule: tools, fishing poles, gear with a use of its own, and consumables still the best of their
-- kind you carry
function V.Protected(id, quality, classID, subclassID)
    if V.TOOLS[id] then return true end
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
    if mode == "quality" then return quality <= upTo end
    return sell.gear and quality == 1
end

-- The items to sell, biggest first, and what they are worth together.
function V:Collect(mode, upTo)
    local list, total = {}, 0
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
                    elseif verdict == "skill" or verdict == "craft" then
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
                        if sell.junk[id] or known or boundGear or unlisted
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
-- Deposit and Withdraw, as two buttons beside the bank's search box (shown with the bank)
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
        return
    end
    if type(bank) ~= "table" or not bank.CreateTexture then return end
    if not self.bankButtons then
        local withdraw = BankButton(bank, L["Withdraw"],
            L["take out of the bank what you already carry some of (materials, potions, food), to top your bags up"],
            function() V:Withdraw() end)
        local deposit = BankButton(bank, L["Deposit"],
            L["put in the bank what it already holds some of, and what you marked for it"],
            function() V:Deposit() end)
        local box = _G.BankItemSearchBox or rawget(bank, "SearchBox")
        if type(box) == "table" and box.GetObjectType then
            withdraw:SetPoint("RIGHT", box, "LEFT", -10, 0)
        else
            withdraw:SetPoint("TOPRIGHT", bank, "TOPRIGHT", -60, -32)
        end
        deposit:SetPoint("RIGHT", withdraw, "LEFT", -4, 0)
        self.bankButtons = { deposit = deposit, withdraw = withdraw }
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
function V:MoveOpen()
    return (self.merchantOpen or self.bankOpen or self.tradeOpen or self.mailOpen) and true or false
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
            say(L["Repaired for %s from the guild bank"]:format(ns.Money(cost)))
            return true
        end
    end
    if (GetMoney() or 0) < cost then
        say(L["Not enough gold to repair everything (%s)."]:format(ns.Money(cost)))
        return false
    end
    RepairAllItems(false)
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
