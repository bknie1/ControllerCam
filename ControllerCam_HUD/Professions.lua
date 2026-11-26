-- ControllerCam HUD: what your characters' professions can still learn from.
-- Each character's crafting professions and how far along they are, noted at login from the game's list of
-- skills; and, whenever a profession's window is open, its recipes as the game shows them: which still give a
-- skill point (orange and yellow ones, the game's own colours), what each needs and what each makes. With that
-- an item in your bags is kept when it still gives you, or another of your characters on this realm, a skill
-- point (mail it over); when the profession's next steps use it (the levelling guides' recipes ahead of you,
-- LevelGuides.lua); or when it crafts something the auction house pays more for than the item itself, every
-- material counted (and an item's tooltip compares the two: as it is, and crafted).
-- Nothing is guessed: a profession whose window has not been opened yet keeps nothing but what its guide uses.
-- Only read: nothing in a profession's window is opened, expanded or changed.

local ADDON, ns = ...
local L = ns.L

local P = { reads = 0 }
ns.Professions = P

ns.RegisterSetting({
    key = "skillKeep", kind = "boolean", default = true, command = "skillkeep", section = "Bags, bank and vendor",
    label = "Keep what your professions still need",
    tip = "an item that one of your characters' recipes still gives a skill point for (orange and yellow recipes, as the game shows them in the profession's window), that the profession's next steps use (the levelling guides' recipes, and those another of your characters knows, up to 75 points ahead), or that crafts something worth more at the auction house than the item itself, is kept, not sold, and its tooltip says why. A Cooking or First Aid material is also kept for a recipe not learned yet, with where to learn it, as are that recipe and the skill books. Recipes are read when a profession's window is open",
})

-- The crafting professions: a key, the game's spell for it (its name in your language), its name in English
P.LIST = {
    { "alchemy", 2259, "Alchemy" }, { "blacksmithing", 2018, "Blacksmithing" }, { "enchanting", 7411, "Enchanting" },
    { "engineering", 4036, "Engineering" }, { "leatherworking", 2108, "Leatherworking" },
    { "tailoring", 3908, "Tailoring" }, { "cooking", 2550, "Cooking" }, { "firstaid", 3273, "First Aid" },
    { "mining", 2575, "Mining" }, { "jewelcrafting", 25229, "Jewelcrafting" }, { "inscription", 45357, "Inscription" },
}
P.LEVEL = 2               -- a recipe this colour or better gives a skill-up: 3 orange, 2 yellow, 1 green, 0 grey
P.BETTER = 1.5            -- crafting is worth it when what it makes brings this many times the item's own price
P.MIN = 2000              -- and at least this much more (20 silver) over a stack of the item, after the house's cut
local CLASSIC = { optimal = 3, medium = 2, easy = 1, trivial = 0 }
local MODERN = { [0] = 3, [1] = 2, [2] = 1, [3] = 0 }      -- the game's relative difficulty: optimal .. trivial

local function Plain(v) if ns.IsSecret(v) then return nil end return v end

-- A profession's key from its name (the skill's or the window's), in your language or in English
local byName
function P.Kind(name)
    name = Plain(name)
    if type(name) ~= "string" then return nil end
    if not byName then
        byName = {}
        local get = (C_Spell and C_Spell.GetSpellName) or GetSpellInfo
        for _, p in ipairs(P.LIST) do
            byName[p[3]:lower()] = p[1]
            local ok, n = pcall(get, p[2])
            if ok and type(n) == "string" and not ns.IsSecret(n) then byName[n:lower()] = p[1] end
        end
    end
    return byName[name:lower()]
end

-- This character's record (Inventory.lua keeps one per character)
local function Record()
    local I = ns.Inventory
    local me = I and I.Me and I.Me()
    if not (me and ns.db) then return nil end
    ns.db.inventory = ns.db.inventory or {}
    local rec = ns.db.inventory[me]
    if not rec then
        rec = { bags = {}, bank = {}, money = 0 }
        ns.db.inventory[me] = rec
    end
    rec.prof = rec.prof or {}
    return rec
end

-- The gathering professions that have no window of recipes: their names (in English, as your language has them,
-- and the game's spell for the two that have one by that name)
local gatherNames
function P.GatherKind(name)
    name = Plain(name)
    if type(name) ~= "string" then return nil end
    if not gatherNames then
        gatherNames = { herbalism = "herbalism", skinning = "skinning", fishing = "fishing" }
        for kind, text in pairs({ herbalism = L["Herbalism"], skinning = L["Skinning"], fishing = L["Fishing"] }) do
            gatherNames[text:lower()] = kind
        end
        local get = (C_Spell and C_Spell.GetSpellName) or GetSpellInfo
        for kind, spell in pairs({ skinning = 8613, fishing = 7620 }) do
            local ok, n = pcall(get, spell)
            if ok and type(n) == "string" and not ns.IsSecret(n) then gatherNames[n:lower()] = kind end
        end
    end
    return gatherNames[name:lower()]
end

-- Which of them each character has: [name-realm] = { [kind] = { name, rank, cap } } (The Mentor says "farm" for
-- what yours bring, Recipes.lua)
ns.RegisterSaved("gatherSkills", function(old)
    local out = {}
    if type(old) ~= "table" then return out end
    for who, kinds in pairs(old) do
        if type(who) == "string" and type(kinds) == "table" then
            local keep = {}
            for kind, g in pairs(kinds) do
                if type(kind) == "string" and type(g) == "table" then
                    keep[kind] = { name = type(g.name) == "string" and g.name or nil, rank = tonumber(g.rank),
                                   cap = tonumber(g.cap) }
                end
            end
            out[who] = keep
        end
    end
    return out
end)

---------------------------------------------------------------------------
-- Your professions and their ranks, from the game's list of skills
---------------------------------------------------------------------------
function P:ReadSkills()
    local rec = Record()
    if not rec then return false end
    local found, gather = {}, {}
    if GetNumSkillLines and GetSkillLineInfo then
        local ok, n = pcall(GetNumSkillLines)
        for i = 1, (ok and tonumber(n)) or 0 do
            local ok2, name, header, _, rank, _, _, cap = pcall(GetSkillLineInfo, i)
            local kind = ok2 and not Plain(header) and P.Kind(name)
            if kind and type(Plain(rank)) == "number" then found[kind] = { name = name, rank = rank, cap = Plain(cap) } end
            local other = ok2 and not Plain(header) and P.GatherKind(name)
            if other and type(Plain(rank)) == "number" then
                gather[other] = { name = name, rank = rank, cap = Plain(cap) }
            end
        end
    elseif GetProfessions and GetProfessionInfo then
        local ok, a, b, c, d, e = pcall(GetProfessions)
        local list = { a, b, c, d, e }
        for i = 1, ok and 5 or 0 do
            local index = list[i]
            if type(index) == "number" then
                local ok, name, _, rank, cap = pcall(GetProfessionInfo, index)
                local kind = ok and P.Kind(name)
                if kind then found[kind] = { name = name, rank = Plain(rank), cap = Plain(cap) } end
                local other = ok and P.GatherKind(name)
                if other then gather[other] = { name = name, rank = Plain(rank), cap = Plain(cap) } end
            end
        end
    else
        return false
    end
    local me = ns.Inventory and ns.Inventory.Me and ns.Inventory.Me()
    if me then
        ns.db.gatherSkills = ns.db.gatherSkills or {}
        ns.db.gatherSkills[me] = next(gather) and gather or nil
    end
    for kind, f in pairs(found) do
        local p = rec.prof[kind] or {}
        p.name, p.rank, p.cap = f.name, f.rank, f.cap or p.cap
        rec.prof[kind] = p
    end
    for kind in pairs(rec.prof) do                            -- one you no longer have
        if not found[kind] then rec.prof[kind] = nil end
    end
    return true
end

---------------------------------------------------------------------------
-- The recipes, while a profession's window is open
---------------------------------------------------------------------------
local function ItemOf(link)
    link = Plain(link)
    return type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
end

local function Add(uses, id, level)
    if id and level then uses[id] = math.max(uses[id] or 0, level) end
end

-- Which recipes a reagent still gives a point for (their names, orange first, then yellow, then green: a green
-- one only may give one): why[reagent] = { { n, l }, ... }
local whyNow
local function AddWhy(id, level, recipe)
    if not (whyNow and id and level and level >= 1 and type(recipe) == "string") then return end
    local list = whyNow[id]
    if not list then list = {}; whyNow[id] = list end
    for _, r in ipairs(list) do if r.n == recipe then return end end
    list[#list + 1] = { n = recipe, l = level }
    table.sort(list, function(a, b) if a.l ~= b.l then return a.l > b.l end return a.n < b.n end)
    while #list > 5 do table.remove(list) end
end

-- What a reagent goes into: crafts[reagent] = { { p = what it makes, n = how many it takes, m = how many it
-- makes }, ... } (a few per reagent: the ones worth most are found when an item is looked at)
local function AddCraft(crafts, id, product, need, made)
    if not (id and product) or id == product then return end
    local list = crafts[id]
    if not list then list = {}; crafts[id] = list end
    for _, c in ipairs(list) do if c.p == product then return end end
    if #list < 6 then
        list[#list + 1] = { p = product, n = math.max(1, tonumber(need) or 1), m = math.max(1, tonumber(made) or 1) }
    end
end

-- The older window (GetTradeSkillInfo) and the older enchanting window (GetCraftInfo) work alike.
-- f: { line, count, info, reagents, reagentLink, reagentInfo, product, made }
local function ReadList(f, via)
    local ok, name, rank, cap = pcall(f.line)
    name = ok and Plain(name)
    if type(name) ~= "string" or name == "" or name == "UNKNOWN" then return nil end
    local uses, crafts, recipes = {}, {}, 0
    whyNow = {}
    local okN, n = pcall(f.count)
    for i = 1, (okN and tonumber(n)) or 0 do
        local level, recipe = f.info(i)
        if level then
            recipes = recipes + 1
            local out, made
            if f.product then
                local okP, link = pcall(f.product, i)
                out = okP and ItemOf(link)
            end
            if f.made then
                local okM, m = pcall(f.made, i)
                made = okM and Plain(m)
            end
            local okR, r = pcall(f.reagents, i)
            for k = 1, (okR and tonumber(r)) or 0 do
                local okL, link = pcall(f.reagentLink, i, k)
                local id = okL and ItemOf(link)
                if level >= 1 then Add(uses, id, level); AddWhy(id, level, recipe) end
                if out and id then
                    local need
                    if f.reagentInfo then
                        local okI, _, _, count = pcall(f.reagentInfo, i, k)
                        need = okI and Plain(count)
                    end
                    AddCraft(crafts, id, out, need, made)
                end
            end
        end
    end
    return name, Plain(rank), Plain(cap), uses, recipes, via, crafts, whyNow
end

local function ReadTradeSkill()
    if not (GetTradeSkillLine and GetNumTradeSkills and GetTradeSkillInfo and GetTradeSkillNumReagents
            and GetTradeSkillReagentItemLink) then return nil end
    return ReadList({ line = GetTradeSkillLine, count = GetNumTradeSkills, info = function(i)
        local ok, recipe, kind = pcall(GetTradeSkillInfo, i)
        return ok and CLASSIC[Plain(kind) or ""] or nil, ok and Plain(recipe) or nil
    end, reagents = GetTradeSkillNumReagents, reagentLink = GetTradeSkillReagentItemLink,
        reagentInfo = GetTradeSkillReagentInfo, product = GetTradeSkillItemLink, made = GetTradeSkillNumMade },
        "tradeskill")
end

local function ReadCraft()
    if not (GetCraftDisplaySkillLine and GetNumCrafts and GetCraftInfo and GetCraftNumReagents
            and GetCraftReagentItemLink) then return nil end
    return ReadList({ line = GetCraftDisplaySkillLine, count = GetNumCrafts, info = function(i)
        local ok, recipe, _, kind = pcall(GetCraftInfo, i)
        return ok and CLASSIC[Plain(kind) or ""] or nil, ok and Plain(recipe) or nil
    end, reagents = GetCraftNumReagents, reagentLink = GetCraftReagentItemLink, reagentInfo = GetCraftReagentInfo,
        product = GetCraftItemLink }, "craft")
end

-- The newer window (C_TradeSkillUI)
local function ReadModern()
    local T = C_TradeSkillUI
    if not (T and T.GetAllRecipeIDs and T.GetRecipeInfo) then return nil end
    local name, rank, cap
    if T.GetBaseProfessionInfo then
        local ok, info = pcall(T.GetBaseProfessionInfo)
        if ok and type(info) == "table" then name, rank, cap = info.professionName, info.skillLevel, info.maxSkillLevel end
    end
    if not Plain(name) and T.GetTradeSkillLine then
        local ok, _, n, r, c = pcall(T.GetTradeSkillLine)
        if ok then name, rank, cap = n, r, c end
    end
    name = Plain(name)
    if type(name) ~= "string" or name == "" then return nil end
    local ok, ids = pcall(T.GetAllRecipeIDs)
    if not ok or type(ids) ~= "table" then return nil end
    local uses, crafts, recipes = {}, {}, 0
    whyNow = {}
    for _, id in ipairs(ids) do
        local okI, info = pcall(T.GetRecipeInfo, id)
        local level = okI and type(info) == "table" and info.learned and MODERN[Plain(info.relativeDifficulty) or -1]
        if level then
            recipes = recipes + 1
            local okS, s
            if T.GetRecipeSchematic then okS, s = pcall(T.GetRecipeSchematic, id, false) end
            if okS and type(s) == "table" and type(s.reagentSlotSchematics) == "table" then
                local out, made = Plain(s.outputItemID), Plain(s.quantityMin)
                for _, slot in ipairs(s.reagentSlotSchematics) do
                    if slot.reagentType == nil or slot.reagentType == 1 then          -- the basic reagents
                        for _, r in ipairs(slot.reagents or {}) do
                            local rid = Plain(r.itemID)
                            if level >= 1 then Add(uses, rid, level); AddWhy(rid, level, Plain(info.name)) end
                            AddCraft(crafts, rid, out, Plain(slot.quantityRequired), made)
                        end
                    end
                end
            elseif level >= 1 and T.GetRecipeNumReagents and T.GetRecipeReagentItemLink then
                local okR, r = pcall(T.GetRecipeNumReagents, id)
                for k = 1, (okR and tonumber(r)) or 0 do
                    local okL, link = pcall(T.GetRecipeReagentItemLink, id, k)
                    Add(uses, okL and ItemOf(link), level)
                end
            end
        end
    end
    return name, Plain(rank), Plain(cap), uses, recipes, "modern", crafts, whyNow
end

-- Reads the window that is open. A list with fewer recipes than the last read is taken for a filtered one
-- (a search, "have materials"): what it adds is kept, nothing is taken away.
function P:ReadWindow(craft)
    local rec = Record()
    if not rec then return false end
    local name, rank, cap, uses, recipes, via, crafts, why
    if craft then
        name, rank, cap, uses, recipes, via, crafts, why = ReadCraft()
    else
        name, rank, cap, uses, recipes, via, crafts, why = ReadTradeSkill()
        if not name then name, rank, cap, uses, recipes, via, crafts, why = ReadModern() end
    end
    local kind = P.Kind(name)
    if not kind or not recipes or recipes == 0 then
        P.last = ("%s: %s, %s recipes"):format(tostring(via or "no list"), tostring(name), tostring(recipes))
        return false
    end
    local p = rec.prof[kind] or {}
    local filtered = p.recipes and recipes < p.recipes and type(p.uses) == "table"
    if filtered then
        for id, level in pairs(uses) do p.uses[id] = math.max(p.uses[id] or 0, level) end
        p.crafts = p.crafts or {}
        for id, list in pairs(crafts or {}) do
            for _, c in ipairs(list) do AddCraft(p.crafts, id, c.p, c.n, c.m) end
        end
        p.why = p.why or {}
        for id, list in pairs(why or {}) do if not p.why[id] then p.why[id] = list end end
    else
        p.uses, p.recipes, p.crafts, p.why = uses, recipes, crafts or {}, why or {}
    end
    p.name, p.rank, p.cap, p.at, p.via = name, rank or p.rank, cap or p.cap, time and time() or 0, via
    rec.prof[kind] = p
    P.reads = P.reads + 1
    local n = 0
    for _ in pairs(uses) do n = n + 1 end
    P.last = ("%s: %s %s/%s, %d recipes, %d reagents still give a point%s"):format(via, name, tostring(p.rank),
        tostring(p.cap), recipes, n, filtered and " (a filtered list: added to what was read before)" or "")
    ns.Note("professions: %s", P.last)
    return true
end

---------------------------------------------------------------------------
-- Who can still learn from an item
---------------------------------------------------------------------------
local function ItemKind(id)
    local get = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not get then return nil end
    local ok, _, _, _, _, _, classID, subclassID = pcall(get, id)
    if ok then return Plain(classID), Plain(subclassID) end
end

-- The character's short name ("Sol" for "Sol-Forever")
function P.Short(who) return type(who) == "string" and (who:match("^([^-]+)") or who) or "" end

-- { who = name-realm, mine = true when it is you, kind, name = the profession's, rank, cap } for a character
-- of yours on this realm whose recipes, as last read from the profession's window, still give a skill point
-- for this item; you come before your other characters. Nil when none does, or none has been read.
local function Mine()
    local me = ns.Inventory and ns.Inventory.Me and ns.Inventory.Me()
    return me, me and me:match("%-(.*)$")
end

local function Characters()
    local all = ns.db and ns.db.skillKeep and ns.db.inventory
    if type(all) ~= "table" then return function() end end
    local me, realm = Mine()
    local list = {}
    for who, rec in pairs(all) do
        if type(rec) == "table" and type(rec.prof) == "table" and (not realm or who:match("%-(.*)$") == realm) then
            list[#list + 1] = { who = who, rec = rec, mine = who == me }
        end
    end
    table.sort(list, function(a, b) if a.mine ~= b.mine then return a.mine end return a.who < b.who end)
    local i = 0
    return function() i = i + 1; return list[i] end
end
P.Characters = Characters

local function Direct(id)
    for c in Characters() do
        for kind, p in pairs(c.rec.prof) do
            local room = not (p.rank and p.cap) or p.rank < p.cap
            if room and p.at and type(p.uses) == "table" and (p.uses[id] or 0) >= P.LEVEL then
                return { who = c.who, mine = c.mine, kind = kind, name = p.name, rank = p.rank, cap = p.cap, sure = true }
            end
        end
    end
    return nil
end

-- A skill-up it gives: one of your characters' recipes still gives a point for it, or for what a recipe of yours
-- makes of it (Iron Ore gives no point smelted, but the Iron Bar it makes does, at Blacksmithing): then via = what
-- it is made into. Only recipes read from a profession's window: nothing is guessed.
function P.Wants(id)
    if type(id) ~= "number" then return nil end
    local w = Direct(id)
    if w then return w end
    for c in Characters() do
        for _, p in pairs(c.rec.prof) do
            for _, k in ipairs((type(p.crafts) == "table" and p.crafts[id]) or {}) do
                w = k.p ~= id and Direct(k.p)
                if w then w.via = k.p; return w end
            end
        end
    end
    return nil
end

-- Smelting, where the guides stop short of it: [ore] = { bar, the Mining skill it takes }
P.SMELT = { [2770] = { 2840, 1 }, [2771] = { 3576, 65 }, [2775] = { 2842, 75 }, [2772] = { 3575, 125 },
            [2776] = { 3577, 155 }, [3858] = { 3860, 175 }, [7911] = { 6037, 230 }, [10620] = { 12359, 250 } }
P.STALE = 7 * 86400       -- auction prices older than this are said to be old

-- A character of yours on this realm with this profession: the first one (you first), or nil
local function Has(kind, at)
    for c in Characters() do
        local p = c.rec.prof[kind]
        if p and (not at or (tonumber(p.rank) or 0) >= at) then return c, p end
    end
    return nil
end

-- What one of an item costs to get: the auction house's price, or a merchant's (Market.lua notes what merchants
-- sell, and theirs never runs out), the lower of the two; else what it is made of, by a recipe of yours. The
-- price and when it was seen (the oldest of them, for something made), or nil when one has no price.
local MadeOf
function P.Cost(id, depth)
    local M = ns.Market
    local auction, t
    if M and M.Auction then auction, t = M.Auction(id) end
    local merchant = M and M.MerchantPrice and M.MerchantPrice(id)
    if auction and merchant then
        if merchant <= auction then return merchant, nil end
        return auction, t
    end
    if auction then return auction, t end
    if merchant then return merchant, nil end
    local recipe = (depth or 0) < 2 and MadeOf(id)
    if not recipe then return nil end
    local sum, oldest = 0, nil
    for _, rid in ipairs(P.SortedKeys(recipe.r)) do
        local each, seen = P.Cost(rid, (depth or 0) + 1)
        if not each then return nil, nil, rid end
        sum = sum + each * recipe.r[rid]
        if seen and (not oldest or seen < oldest) then oldest = seen end
    end
    return sum / (recipe.m or 1), oldest
end

function P.SortedKeys(set)
    local ids = {}
    for id in pairs(set) do ids[#ids + 1] = id end
    table.sort(ids)
    return ids
end

-- What an item is made of by a recipe of yours: { m = made each time, k = profession, r = { [reagent] = n } }:
-- as The Mentor read it from a profession's window, or a bar smelted from its ore by a miner of yours
MadeOf = function(id)
    local LV = ns.Levelling
    local made = LV and LV.MadeOf and LV.MadeOf(id)
    if made then return made end
    for ore, s in pairs(P.SMELT) do
        if s[1] == id and Has("mining", s[2]) then return { m = 1, k = "mining", r = { [ore] = 1 } } end
    end
    return nil
end
P.MadeOf = MadeOf

-- What it costs to make one of an item, by a recipe of yours, against what it sells for: { cost (for one made),
-- price (at the auction house, each), profit (after the house's cut), missing (a material with no price), at
-- (when the oldest price was seen) }, or nil when no recipe of yours makes it
function P.MakeCost(id)
    if type(id) ~= "number" then return nil end
    local recipe = MadeOf(id)
    if not recipe then return nil end
    local out, sum, oldest = {}, 0, nil
    for _, rid in ipairs(P.SortedKeys(recipe.r)) do
        local each, seen, deeper = P.Cost(rid)
        if not each then out.missing = deeper or rid; break end
        sum = sum + each * recipe.r[rid]
        if seen and (not oldest or seen < oldest) then oldest = seen end
    end
    local M = ns.Market
    local price, t
    if M and M.Auction then price, t = M.Auction(id) end
    out.price = price
    if t and (not oldest or t < oldest) then oldest = t end
    out.at = oldest
    if not out.missing then
        out.cost = sum / (recipe.m or 1)
        if price then out.profit = price * 0.95 - out.cost end
    end
    return out
end

-- What this item could be crafted into by a recipe a character of yours knows (as read from the profession's
-- window), or smelted into by a miner of yours: { { p = what it makes, n = how many it takes, m = how many it
-- makes, kind, who, mine, name } }
local function Products(id)
    local out, seen = {}, {}
    for c in Characters() do
        for kind, p in pairs(c.rec.prof) do
            for _, k in ipairs((type(p.crafts) == "table" and p.crafts[id]) or {}) do
                if not seen[k.p] then
                    seen[k.p] = true
                    out[#out + 1] = { p = k.p, n = k.n or 1, m = k.m or 1, kind = kind, who = c.who, mine = c.mine,
                                      name = p.name }
                end
            end
        end
    end
    local s = P.SMELT[id]
    if s and not seen[s[1]] then
        local c, p = Has("mining", s[2])
        if c then
            out[#out + 1] = { p = s[1], n = 1, m = 1, kind = "mining", who = c.who, mine = c.mine, name = p.name }
        end
    end
    return out
end

-- One of this item as it is, against made into something: own = what it brings as it is (the auction house
-- after its cut, or a vendor; worked out when not given). For the best of what your recipes make of it:
--   { product, kind, who, mine, name, n, m, own, price = the product's at the auction house, others = what the
--     other materials of one craft cost, each = what one of this item is worth made into it (the product after
--     the house's cut, less the other materials, for each of this item it takes), worth = clearly worth the
--     effort (P.BETTER times as much, and P.MIN more over a stack of it), stale = days since the oldest price
--     when that is more than P.STALE,
--     missing = an item with no price to go by (then nothing is worked out) }
-- or nil when nothing of yours makes anything of it. Every material counts, at what it costs to get (P.Cost).
function P.CraftValue(id, own)
    local M = ns.Market
    if type(id) ~= "number" or not (M and M.Auction) then return nil end
    if own == nil then own = math.max((M.Auction(id) or 0) * 0.95, (M.Vendor and M.Vendor(id)) or 0) end
    local now = time and time() or 0
    local best
    local function Better(c)
        if not best then return true end
        if (best.missing ~= nil) ~= (c.missing ~= nil) then return best.missing ~= nil end
        if best.worth ~= c.worth then return c.worth end
        return (c.each or 0) > (best.each or 0)
    end
    for _, k in ipairs(Products(id)) do
        local recipe = MadeOf(k.p)
        local r = (recipe and recipe.r and recipe.r[id]) and recipe.r or { [id] = k.n }
        local n, m = r[id], (recipe and recipe.m) or k.m or 1
        local c = { product = k.p, kind = k.kind, who = k.who, mine = k.mine, name = k.name, n = n, m = m, own = own }
        local price, t = M.Auction(k.p)
        if not price then
            c.missing = k.p
        else
            local others, oldest = 0, t
            for _, rid in ipairs(P.SortedKeys(r)) do
                if rid ~= id then
                    local each, seen, deeper = P.Cost(rid)
                    if not each then c.missing = deeper or rid; break end
                    others = others + each * r[rid]
                    if seen and seen < oldest then oldest = seen end
                end
            end
            if not c.missing then
                local net = price * 0.95 * m
                c.price, c.others = price, others
                c.each = (net - others) / n
                -- worth the effort: clearly more each, and P.MIN more over a stack of it (a smelted stack of ore)
                c.worth = c.each > own and c.each >= own * P.BETTER
                    and (c.each - own) * ((M.Stack and M.Stack(id)) or 1) >= P.MIN
                c.stale = now - oldest > P.STALE and math.floor((now - oldest) / 86400) or nil
            end
        end
        if Better(c) then best = c end
    end
    return best
end

-- What this item crafts that is worth more than the item itself (P.CraftValue, when clearly worth the effort):
-- { craft = true, product, price (each, at the auction house), each (what one of this item is worth made into
-- it), who, mine, kind, name, value = the whole comparison }, or nil
function P.Crafts(id, own)
    local c = P.CraftValue(id, own)
    if not (c and c.worth) then return nil end
    return { craft = true, product = c.product, price = c.price, each = c.each, who = c.who, mine = c.mine,
             kind = c.kind, name = c.name, sure = true, value = c }
end

---------------------------------------------------------------------------
-- What your professions will need soon: the steps of the levelling guides (LevelGuides.lua) still ahead of a
-- character of yours, within P.AHEAD points, and the recipes another of your characters was seen with that this
-- one has yet to learn. For ore, through the bar it is smelted into. Only for a profession that character has.
---------------------------------------------------------------------------
P.AHEAD = 75              -- how far past your rank "soon" reaches: one rank of training

-- Built once from the guides: uses[reagent] = { { kind, from, to, name, s = spell, p = product, main } },
-- makes[reagent] = { { p, kind, at } } (what the guides make of it)
local guideIndex
function P.GuideIndex()
    if guideIndex then return guideIndex end
    guideIndex = { uses = {}, makes = {} }
    for kind, guide in pairs(ns.LevelGuides or {}) do
        for _, g in ipairs(guide) do
            local options = { g }
            for _, a in ipairs(g.alts or {}) do options[#options + 1] = a end
            for _, o in ipairs(options) do
                if not o.gather and type(o.r) == "table" then
                    local from, to = o.lo or math.max(g[1], o.at or 0), o.hi or g[2]
                    for i = 1, #o.r - 1, 2 do
                        local rid = o.r[i]
                        local list = guideIndex.uses[rid] or {}
                        guideIndex.uses[rid] = list
                        list[#list + 1] = { kind = kind, from = from, to = to, name = o.name, s = o.s, p = o.p,
                                            main = o == g }
                        if o.p and o.p ~= rid then
                            local mk = guideIndex.makes[rid] or {}
                            guideIndex.makes[rid] = mk
                            mk[#mk + 1] = { p = o.p, kind = kind, at = o.at }
                        end
                    end
                end
            end
        end
    end
    return guideIndex
end

local function SpellName(id)
    local get = (C_Spell and C_Spell.GetSpellName) or GetSpellInfo
    if not (get and id) then return nil end
    local ok, name = pcall(get, id)
    name = ok and Plain(name)
    return type(name) == "string" and name ~= "" and name or nil
end

local function GuideRecipeName(u)
    local name = SpellName(u.s)
    if name then return name end
    if u.p then
        local item = P.ItemName(u.p)
        if not item:find("^item %d") then return item end
    end
    return u.name or "?"
end

-- What an item goes into on the way: { { p, kind } } (smelted, made by the guides' recipes, or by yours), for a
-- profession one of your characters has
local function Into(id)
    local out, seen = {}, {}
    local function Add(p, kind, at)
        if p and p ~= id and not seen[p] and Has(kind, at and at - P.AHEAD) then seen[p] = true; out[#out + 1] = { p = p, kind = kind, at = at } end
    end
    local s = P.SMELT[id]
    if s then Add(s[1], "mining", s[2]) end
    for _, mk in ipairs(P.GuideIndex().makes[id] or {}) do Add(mk.p, mk.kind, mk.at) end
    for product, made in pairs(ns.db and ns.db.skillMakes or {}) do
        if type(made) == "table" and type(made.r) == "table" and made.r[id] and made.k then Add(product, made.k) end
    end
    table.sort(out, function(a, b) return a.p < b.p end)
    return out
end

-- The recipes this character does not know yet that another of yours was seen with, and what they need:
-- each(name, from = the lowest rank it was seen at, reagents)
local function OthersRecipes(who, kind, each)
    local db = ns.db or {}
    local known = db.skillKnown or {}
    local mine = known[who] and known[who][kind] or {}
    local steps = db.skillSteps and db.skillSteps[kind] or {}
    for other, kinds in pairs(known) do
        if other ~= who and type(kinds) == "table" and type(kinds[kind]) == "table" then
            for name, product in pairs(kinds[kind]) do
                local made = type(product) == "number" and db.skillMakes and db.skillMakes[product]
                local b = steps[name]
                if not mine[name] and made and type(made.r) == "table" and b and b.o then each(name, b.o, made.r) end
            end
        end
    end
end

-- A material one of your characters' professions will use soon: { who, mine, kind, name = the profession's, rank,
-- from = the skill it is needed from, recipe = the recipe's name, via = what it is made into first (ore: the
-- bar) }; you first, then what is needed now, then what is needed soonest. Nil when none will.
function P.Ahead(id)
    if type(id) ~= "number" or not (ns.db and ns.db.skillKeep) then return nil end
    local index = P.GuideIndex()
    local best
    local function Consider(c, kind, p, from, recipe, via, main)
        local rank = tonumber(p.rank)
        local w = { who = c.who, mine = c.mine, kind = kind, name = p.name, rank = rank, from = math.max(from, rank),
                    recipe = recipe, via = via, main = main }
        if not best then best = w; return end
        local function Key(x) return { x.mine and 0 or 1, x.from, x.via and 1 or 0, x.main and 0 or 1 } end
        local a, b = Key(w), Key(best)
        for i = 1, #a do
            if a[i] ~= b[i] then if a[i] < b[i] then best = w end return end
        end
    end
    local function Look(c, kind, p, item, via)
        local rank = tonumber(p.rank)
        for _, u in ipairs(index.uses[item] or {}) do
            if u.kind == kind and u.to > rank and u.from <= rank + P.AHEAD then
                Consider(c, kind, p, u.from, GuideRecipeName(u), via, u.main)
            end
        end
        OthersRecipes(c.who, kind, function(name, from, reagents)
            if reagents[item] and from > rank and from <= rank + P.AHEAD then Consider(c, kind, p, from, name, via, false) end
        end)
    end
    local into = Into(id)
    for c in Characters() do
        for kind, p in pairs(c.rec.prof) do
            if type(tonumber(p.rank)) == "number" then
                Look(c, kind, p, id, nil)
                for _, x in ipairs(into) do Look(c, kind, p, x.p, x.p) end
            end
        end
    end
    return best
end

-- Why it is kept, in a few words: "Blacksmithing needs it from 210 (you're at 180), for Heavy Mithril Gauntlet",
-- "made into Mithril Bar: Blacksmithing needs it from 210 (Sol is at 180), for Heavy Mithril Gauntlet"
function P.AheadWords(w)
    if type(w) ~= "table" then return "" end
    local prof, recipe = tostring(w.name or w.kind), tostring(w.recipe)
    local text
    if w.from <= w.rank then
        text = w.mine and L["%s needs it now (you're at %d), for %s"]:format(prof, w.rank, recipe)
            or L["%s needs it now (%s is at %d), for %s"]:format(prof, P.Short(w.who), w.rank, recipe)
    else
        text = w.mine and L["%s needs it from %d (you're at %d), for %s"]:format(prof, w.from, w.rank, recipe)
            or L["%s needs it from %d (%s is at %d), for %s"]:format(prof, w.from, P.Short(w.who), w.rank, recipe)
    end
    if w.via then text = L["made into %s"]:format(P.ItemName(w.via)) .. ": " .. text end
    return text
end

---------------------------------------------------------------------------
-- Disenchanting. What green, blue and purple weapons and armor give (as in Classic), by item level, and the
-- Enchanting skill it takes. Each row: up to this item level, the dust { id, fewest, most }, the essence, the
-- shard. Green armor gives dust three times in four, an essence one time in five, a shard one in twenty; green
-- weapons the other way round for dust and essence. Blue gives the shard; purple a few shards, or a Nexus
-- Crystal at the top.
---------------------------------------------------------------------------
P.DE_SKILL = { { 20, 1 }, { 25, 25 }, { 30, 50 }, { 35, 75 }, { 40, 100 }, { 45, 125 }, { 50, 150 },
               { 55, 175 }, { 60, 200 }, { 999, 225 } }
P.DE = {
    { 15, { 10940, 1, 2 }, { 10938, 1, 2 } },                    -- Strange Dust, Lesser Magic Essence
    { 20, { 10940, 2, 3 }, { 10939, 1, 2 }, 10978 },             -- Greater Magic Essence, Small Glimmering Shard
    { 25, { 10940, 4, 6 }, { 10998, 1, 2 }, 10978 },             -- Lesser Astral Essence
    { 30, { 11083, 1, 2 }, { 11082, 1, 2 }, 11084 },             -- Soul Dust, Greater Astral, Large Glimmering
    { 35, { 11083, 2, 5 }, { 11134, 1, 2 }, 11138 },             -- Lesser Mystic Essence, Small Glowing Shard
    { 40, { 11137, 1, 2 }, { 11135, 1, 2 }, 11139 },             -- Vision Dust, Greater Mystic, Large Glowing
    { 45, { 11137, 2, 5 }, { 11174, 1, 2 }, 11177 },             -- Lesser Nether Essence, Small Radiant Shard
    { 50, { 11176, 1, 2 }, { 11175, 1, 2 }, 11178 },             -- Dream Dust, Greater Nether, Large Radiant
    { 55, { 11176, 2, 5 }, { 16202, 1, 2 }, 14343 },             -- Lesser Eternal Essence, Small Brilliant Shard
    { 999, { 16204, 1, 2 }, { 16203, 1, 2 }, 14344 },            -- Illusion Dust, Greater Eternal, Large Brilliant
}
P.NEXUS = 20725
P.DE_BETTER, P.DE_MIN = 1.1, 50       -- worth it when its materials bring a tenth more than selling it, and 50c more

local function Bracket(list, ilvl)
    for _, row in ipairs(list) do if ilvl <= row[1] then return row end end
end

-- What disenchanting it gives: { { id, n = how many on average, chance }, ... } and the skill it takes; or nil
-- for anything that cannot be disenchanted (white or grey, not weapons or armor)
function P.DisenchantMats(id)
    local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if not get then return nil end
    local ok, _, _, quality, ilvl = pcall(get, id)
    quality, ilvl = ok and Plain(quality), ok and Plain(ilvl)
    local classID = ItemKind(id)
    if type(quality) ~= "number" or type(ilvl) ~= "number" or quality < 2 or quality > 4 or ilvl < 5
        or (classID ~= 2 and classID ~= 4) then
        return nil
    end
    local row = Bracket(P.DE, ilvl)
    local skill = Bracket(P.DE_SKILL, ilvl)[2]
    local function avg(m) return (m[2] + m[3]) / 2 end
    local mats = {}
    if quality == 2 then
        local dust, essence = classID == 4 and 0.75 or 0.20, classID == 4 and 0.20 or 0.75
        if not row[4] then dust, essence = dust + 0.025, essence + 0.025 end
        mats[1] = { id = row[2][1], n = avg(row[2]), chance = dust }
        mats[2] = { id = row[3][1], n = avg(row[3]), chance = essence }
        if row[4] then mats[3] = { id = row[4], n = 1, chance = 0.05 } end
        table.sort(mats, function(a, b) return a.chance > b.chance end)
    elseif quality == 3 then
        mats[1] = { id = row[4] or 10978, n = 1, chance = 1 }
    elseif ilvl > 55 then
        mats[1] = { id = P.NEXUS, n = 1, chance = 1 }
    else
        mats[1] = { id = row[4] or 10978, n = 3, chance = 1 }
    end
    return mats, skill
end

-- What an enchanter of yours makes of it, against what it sells for (own: the auction house after its cut, or a
-- vendor): { who, mine, kind, name, rank, cap, mats, skill, value, priced } when one of yours with the skill for
-- it would rather disenchant it: its materials bring clearly more than selling it (value: what they bring, by
-- the auction house's prices), or one of them still gives that enchanter a skill-up (skill: true). Only
-- characters of yours on this realm and of your faction; for an item bound to you, only you. Nil otherwise.
function P.Disenchant(id, own, bound)
    if type(id) ~= "number" then return nil end
    local mats, need = P.DisenchantMats(id)
    if not mats then return nil end
    local M = ns.Market
    local value, priced = 0, true
    for _, m in ipairs(mats) do
        local price = M and M.Auction and M.Auction(m.id)
        m.price = price
        if price then value = value + price * 0.95 * m.n * m.chance
        elseif m.chance >= 0.2 then priced = false end           -- (a shard that seldom comes matters little)
    end
    local all = ns.db and ns.db.inventory or {}
    local me = Mine()
    local faction = me and all[me] and all[me].faction
    local best
    for c in Characters() do
        local p = c.rec.prof.enchanting
        local sameSide = not (faction and c.rec.faction and c.rec.faction ~= faction)
        if p and type(p.rank) == "number" and p.rank >= need and (c.mine or (not bound and sameSide)) then
            local skill = false
            local room = not (p.rank and p.cap) or p.rank < p.cap
            if room and p.at and type(p.uses) == "table" then
                for _, m in ipairs(mats) do
                    if m.chance >= 0.2 and (p.uses[m.id] or 0) >= P.LEVEL then skill = true end
                end
            end
            local worth = priced and value >= (own or 0) * P.DE_BETTER and value - (own or 0) >= P.DE_MIN
            if (skill or worth) and not best then
                best = { who = c.who, mine = c.mine, kind = "enchanting", name = p.name, rank = p.rank, cap = p.cap,
                         mats = mats, skill = skill, value = priced and value or nil, disenchant = true }
            end
        end
    end
    return best
end

-- One material in a few words: "Soul Dust x1.5 (12s each)", its chance when it seldom comes ("5%")
function P.MatText(m)
    local text = P.ItemName(m.id)
    if m.n ~= 1 then text = text .. (" x%s"):format((("%.1f"):format(m.n)):gsub("%.0$", "")) end
    if m.chance < 1 then text = text .. (" %d%%"):format(math.floor(m.chance * 100 + 0.5)) end
    if m.price then text = text .. "  " .. L["%s each"]:format(ns.Money(m.price)) end
    return text
end

-- Your professions whose window has not been opened yet (their recipes are unknown, so nothing is kept for
-- them): their names, in the game's words
function P.Unread()
    local I = ns.Inventory
    local me = I and I.Me and I.Me()
    local rec = me and ns.db and ns.db.inventory and ns.db.inventory[me]
    local out = {}
    for kind, p in pairs(rec and rec.prof or {}) do
        if not p.at then out[#out + 1] = tostring(p.name or kind) end
    end
    table.sort(out)
    return out
end

-- The recipes a skill-up is for (as read from that character's profession window): { { n = name, l = 3|2|1 } }
-- (for what it is made into, when that is where the point is)
function P.Recipes(w, id)
    local rec = w and ns.db and ns.db.inventory and ns.db.inventory[w.who]
    local p = rec and rec.prof and rec.prof[w.kind]
    return (p and type(p.why) == "table" and p.why[w.via or id]) or {}
end

-- An item's name, or "item 1234" while the game has not shown it yet
function P.ItemName(id)
    local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local ok, name = pcall(get, id)
    name = ok and Plain(name)
    return type(name) == "string" and name or ("item " .. tostring(id))
end

-- One recipe, in the colour the profession's window shows it in (orange, yellow, green), behind the window's own
-- skill-up arrows
P.SKILL = {
    [3] = { "|cffff8040", "Professions-Icon-Skill-High" },
    [2] = { "|cffffff00", "Professions-Icon-Skill-Medium" },
    [1] = { "|cff40c040", "Professions-Icon-Skill-Low" },
}
function P.RecipeText(r)
    local s = P.SKILL[math.min(3, math.max(1, r.l or 1))]
    return "|A:" .. s[2] .. ":12:12|a " .. s[1] .. tostring(r.n) .. "|r"
end

-- What to say about it: "Alchemy 120/150", "Alchemy 120/150, Sol" for a skill-up; "Crafts: Heavy Grinding Stone,
-- 1g 20s" (", Sol") for something worth crafting
function P.Words(w)
    if not w then return "" end
    local text
    if w.craft then
        local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
        local ok, name = pcall(get, w.product)
        name = ok and Plain(name) or ("item " .. tostring(w.product))
        text = L["Crafts: %s"]:format(("%s, %s"):format(name, ns.Money(w.price or 0)))
    else
        text = tostring(w.name or w.kind)
        if w.rank and w.cap then text = ("%s %d/%d"):format(text, w.rank, w.cap) end
    end
    if not w.mine then text = text .. ", " .. P.Short(w.who) end
    return text
end

---------------------------------------------------------------------------
-- Listening
---------------------------------------------------------------------------
local pending = {}
local function Soon(what)
    if pending[what] then return end
    pending[what] = true
    C_Timer.After(0.3, function()
        pending[what] = nil
        local ok, err = pcall(function()
            if what == "skills" then P:ReadSkills() else P:ReadWindow(what == "craft") end
        end)
        if not ok then ns.Error(err) end
    end)
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", ns.Protect(function(_, event)
    if event == "PLAYER_ENTERING_WORLD" or event == "SKILL_LINES_CHANGED" then Soon("skills")
    elseif event == "CRAFT_SHOW" or event == "CRAFT_UPDATE" then Soon("craft")
    else Soon("window") end
end))

-- Noted whenever the addon is loaded, like what your characters carry (Inventory.lua): it stays right for
-- your other characters
function P:Apply(run)
    if self.watching then return end
    self.watching = true
    for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "SKILL_LINES_CHANGED", "TRADE_SKILL_SHOW", "TRADE_SKILL_UPDATE",
                         "TRADE_SKILL_LIST_UPDATE", "CRAFT_SHOW", "CRAFT_UPDATE" }) do
        pcall(events.RegisterEvent, events, e)
    end
    Soon("skills")
end

-- For the reports
function P.Describe()
    local out = {}
    local api = {}
    if GetTradeSkillLine then api[#api + 1] = "tradeskill" end
    if GetCraftDisplaySkillLine then api[#api + 1] = "craft" end
    if C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs then api[#api + 1] = "modern" end
    if GetNumSkillLines then api[#api + 1] = "skill lines" end
    if GetProfessions then api[#api + 1] = "GetProfessions" end
    out[1] = ("on %s; this game has: %s; windows read: %d; last: %s"):format(tostring(ns.db and ns.db.skillKeep),
        table.concat(api, ", "), P.reads, tostring(P.last or "none yet"))
    for who, rec in pairs(ns.db and ns.db.inventory or {}) do
        for kind, p in pairs(rec.prof or {}) do
            local n = 0
            for _ in pairs(p.uses or {}) do n = n + 1 end
            out[#out + 1] = ("%s: %s %s/%s, recipes %s (%s), %d reagents give a point"):format(P.Short(who), kind,
                tostring(p.rank), tostring(p.cap), p.at and tostring(p.recipes) or "not read", tostring(p.via), n)
        end
    end
    return out
end

ns.RegisterModule("professions", P)
