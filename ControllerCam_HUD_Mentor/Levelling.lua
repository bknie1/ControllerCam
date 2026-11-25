-- ControllerCam HUD: The Mentor, a levelling plan beside a profession's window.
-- While a profession's window is open, a panel of our own sits beside it: which recipes to make, how many of
-- each, and what that takes, to reach the profession's cap. It is an estimate, made again whenever the window
-- changes (each craft), from what the window shows:
--   * a recipe's colour: orange always gives a point, yellow usually, green sometimes, grey never;
--   * where each recipe changes colour. The game does not say, so it is learned: every time a window is read,
--     each recipe's colour at that rank is noted (for every character of yours, so an alt learns from a main).
--     A change not seen yet is taken to be a usual distance away (Levelling.BAND points between yellow, green
--     and grey).
--   * the chance of a point between yellow and grey, by the rule players have long used:
--     (grey - your rank) / (grey - yellow).
-- Where the profession has a guide (LevelGuides.lua: the steps the well-known levelling guides take, with their
-- alternatives), the plan follows it: each stretch's recipe, or an alternative you already know, and a recipe you
-- do not know yet marked to learn. Without one, each point is taken from the recipe that costs least per point
-- (auction prices where they are known).
-- What it takes is broken down through what your characters can make: a Bronze Bar the plan needs, less the
-- ones you hold, becomes Copper Bars and Tin Bars, and those Copper Ore and Tin Ore, less what you hold of each.
-- What is still missing can be put on the farm list (Farm.lua) with one button.
-- The Mentor says it in a few plain words at the top (a few ways of putting each, picked when the window opens),
-- and names the recipe to learn next when one of your characters has been seen with it (or the window lists it).
-- Only read: nothing in the profession's window is opened, expanded, changed or written to.
-- Also here: beside the game's count of a recipe you can make, a second one that counts your bank too; and in
-- the panel, what you can make with your bank (the game's "Have Materials" only looks in your bags, and it is the
-- game's own filter, so it is left as it is).

local ADDON = ...
local ns = ControllerCamHUD.ns            -- the HUD's own namespace: this file is one of its modules (Modules.lua)
local L = ns.L
local C = ns.colors

local LV = { reads = 0, index = 1, top = 1, rows = {}, entries = {} }
ns.Levelling = LV

LV.BAND = 15              -- points between a recipe turning yellow, green and grey, until it is seen
LV.DEPTH = 4              -- how far down a chain of crafts the breakdown goes (Copper Ore > Copper Bar > Bronze Bar)
LV.UNKNOWN = 100          -- what a reagent with no known price counts as (1 silver), to compare recipes
LV.ROWS = 12
LV.KEYS = { "PADDUP", "PADDDOWN", "PAD1", "PAD3", "PAD4", "PADRSHOULDER", "PAD2", "ESCAPE", "PADLSTICK" }

LV.KEY = "PADLSTICK"      -- while the window is open: L3 takes the plan's buttons, and gives them back
LV.WINDOWS = { "TradeSkillFrame", "CraftFrame", "ProfessionsFrame" }
LV.REACH = 120            -- how far past a window's edge its own tabs may stick out (the panel goes past them)


local CLASSIC = { optimal = 3, medium = 2, easy = 1, trivial = 0 }
local MODERN = { [0] = 3, [1] = 2, [2] = 1, [3] = 0 }
local Plain = ns.Plain

local function ItemOf(link)
    link = Plain(link)
    return type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
end

local function Num(v)
    v = Plain(v)
    return type(v) == "number" and v or nil
end

local function SpellOf(link)
    link = Plain(link)
    return type(link) == "string" and tonumber(link:match("enchant:(%d+)") or link:match("spell:(%d+)")) or nil
end

-- Where recipes change colour, as learned: [kind][recipe] = { yl, yh, gl, gh, xl, xh } (each change between the
-- last rank seen before it and the first seen after it). What a crafted thing is made of: [item] = { m = made
-- each time, k = profession, r = { [reagent] = how many } }
local function CleanBounds(old)
    local out = {}
    if type(old) ~= "table" then return out end
    for kind, list in pairs(old) do
        if type(kind) == "string" and type(list) == "table" then
            local keep = {}
            for name, b in pairs(list) do
                if type(name) == "string" and type(b) == "table" then
                    local c = {}
                    for _, k in ipairs({ "yl", "yh", "gl", "gh", "xl", "xh", "o" }) do c[k] = tonumber(b[k]) end
                    keep[name] = c
                end
            end
            out[kind] = keep
        end
    end
    return out
end
ns.RegisterSaved("skillSteps", CleanBounds)

-- The recipes each character has been seen to know: [name-realm][kind] = { [recipe] = true } (only ever added
-- to, so a list filtered by a search never makes a recipe look unknown)
ns.RegisterSaved("skillKnown", function(old)
    local out = {}
    if type(old) ~= "table" then return out end
    for who, kinds in pairs(old) do
        if type(who) == "string" and type(kinds) == "table" then
            local keep = {}
            for kind, list in pairs(kinds) do
                if type(kind) == "string" and type(list) == "table" then
                    local names = {}
                    for name, on in pairs(list) do
                        if type(name) == "string" and on then names[name] = (type(on) == "number" and on) or true end
                    end
                    keep[kind] = names
                end
            end
            out[who] = keep
        end
    end
    return out
end)

-- The panel put away beside the profession window (L3 brings it back)
ns.RegisterSaved("skillPlanHidden", function(old) return old == true end)

ns.RegisterSaved("skillMakes", function(old)
    local out = {}
    if type(old) ~= "table" then return out end
    for id, rec in pairs(old) do
        if type(id) == "number" and type(rec) == "table" and type(rec.r) == "table" then
            local r, any = {}, false
            for rid, n in pairs(rec.r) do
                if type(rid) == "number" and tonumber(n) and tonumber(n) > 0 and rid ~= id then r[rid] = tonumber(n); any = true end
            end
            if any then
                out[id] = { m = math.max(1, tonumber(rec.m) or 1), k = type(rec.k) == "string" and rec.k or nil, r = r }
            end
        end
    end
    return out
end)

---------------------------------------------------------------------------
-- Reading the open window
---------------------------------------------------------------------------
-- { kind, name, rank, cap, via, list = { { n = recipe, c = colour 3..0, u = points a craft gives, p = what it
-- makes, m = how many, r = { { id, n } } } } }, or nil
local function ReadClassic(craft)
    local line, count, info, reagents, reagentLink, reagentInfo, product, made
    if craft then
        if not (GetCraftDisplaySkillLine and GetNumCrafts and GetCraftInfo and GetCraftNumReagents
                and GetCraftReagentItemLink) then return nil end
        line, count, reagents, reagentLink = GetCraftDisplaySkillLine, GetNumCrafts, GetCraftNumReagents,
            GetCraftReagentItemLink
        reagentInfo, product = GetCraftReagentInfo, GetCraftItemLink
        info = function(i)
            local name, _, kind = GetCraftInfo(i)
            return name, kind, 1
        end
    else
        if not (GetTradeSkillLine and GetNumTradeSkills and GetTradeSkillInfo and GetTradeSkillNumReagents
                and GetTradeSkillReagentItemLink) then return nil end
        line, count, reagents, reagentLink = GetTradeSkillLine, GetNumTradeSkills, GetTradeSkillNumReagents,
            GetTradeSkillReagentItemLink
        reagentInfo, product, made = GetTradeSkillReagentInfo, GetTradeSkillItemLink, GetTradeSkillNumMade
        info = function(i)
            local name, kind, _, _, _, ups = GetTradeSkillInfo(i)
            return name, kind, ups
        end
    end
    local ok, name, rank, cap = pcall(line)
    name = ok and Plain(name)
    if type(name) ~= "string" or name == "" or name == "UNKNOWN" then return nil end
    local read = { name = name, rank = Num(rank), cap = Num(cap), via = craft and "craft" or "tradeskill", list = {} }
    local okN, n = pcall(count)
    for i = 1, (okN and tonumber(n)) or 0 do
        local okI, recipe, kind, ups = pcall(info, i)
        local c = okI and CLASSIC[Plain(kind) or ""]
        recipe = okI and Plain(recipe)
        if c and type(recipe) == "string" then
            local r = { n = recipe, c = c, u = math.max(1, Num(ups) or 1), r = {} }
            if product then
                local okP, link = pcall(product, i)
                r.p = okP and ItemOf(link) or nil
                r.s = okP and SpellOf(link) or nil                           -- (an enchant makes no item)
            end
            if not craft and not r.s and GetTradeSkillRecipeLink then
                local okS, link = pcall(GetTradeSkillRecipeLink, i)
                r.s = okS and SpellOf(link) or nil
            end
            if made then
                local okM, m = pcall(made, i)
                r.m = okM and Num(m) or nil
            end
            local okR, k = pcall(reagents, i)
            for j = 1, (okR and tonumber(k)) or 0 do
                local okL, link = pcall(reagentLink, i, j)
                local id = okL and ItemOf(link)
                local need = 1
                if reagentInfo then
                    local okC, _, _, c2 = pcall(reagentInfo, i, j)
                    need = (okC and Num(c2)) or 1
                end
                if id then r.r[#r.r + 1] = { id = id, n = math.max(1, need) } end
            end
            read.list[#read.list + 1] = r
        end
    end
    return read
end

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
    local read = { name = name, rank = Num(rank), cap = Num(cap), via = "modern", list = {}, missing = {} }
    for _, id in ipairs(ids) do
        local okI, info = pcall(T.GetRecipeInfo, id)
        if okI and type(info) == "table" and info.learned == false then              -- a trainer's, still to learn
            local m = MODERN[Plain(info.relativeDifficulty) or -1]
            local n = Plain(info.name)
            if m and m > 0 and type(n) == "string" then read.missing[#read.missing + 1] = n end
        end
        local c = okI and type(info) == "table" and info.learned and MODERN[Plain(info.relativeDifficulty) or -1]
        local recipe = c and Plain(info.name)
        if c and type(recipe) == "string" then
            local r = { n = recipe, c = c, u = math.max(1, Num(info.numSkillUps) or 1), r = {}, s = Num(id) }
            if T.GetRecipeSchematic then
                local okS, s = pcall(T.GetRecipeSchematic, id, false)
                if okS and type(s) == "table" then
                    r.p, r.m = Num(s.outputItemID), Num(s.quantityMin)
                    for _, slot in ipairs(type(s.reagentSlotSchematics) == "table" and s.reagentSlotSchematics or {}) do
                        if slot.reagentType == nil or slot.reagentType == 1 then             -- the basic reagents
                            local first = type(slot.reagents) == "table" and slot.reagents[1]
                            local rid = first and Num(first.itemID)
                            if rid then r.r[#r.r + 1] = { id = rid, n = math.max(1, Num(slot.quantityRequired) or 1) } end
                        end
                    end
                end
            end
            read.list[#read.list + 1] = r
        end
    end
    return read
end

-- What the open window shows (craft: the older enchanting window)
function LV.Read(craft)
    local read
    if craft then read = ReadClassic(true) else read = ReadClassic(false) or ReadModern() end
    if not read then return nil end
    read.kind = ns.Professions and ns.Professions.Kind(read.name)
    if not read.kind or #read.list == 0 then return nil end
    return read
end

---------------------------------------------------------------------------
-- Learning where recipes change colour, and what things are made of
---------------------------------------------------------------------------
local function Lower(b, k, v) if not b[k] or v < b[k] then b[k] = v end end
local function Higher(b, k, v) if not b[k] or v > b[k] then b[k] = v end end

function LV.Learn(read)
    local db = ns.db
    if not (db and read and read.rank) then return end
    db.skillSteps = db.skillSteps or {}
    db.skillMakes = db.skillMakes or {}
    local steps = db.skillSteps[read.kind] or {}
    db.skillSteps[read.kind] = steps
    local me = ns.Inventory and ns.Inventory.Me and ns.Inventory.Me()
    local known
    if me then
        db.skillKnown = db.skillKnown or {}
        db.skillKnown[me] = db.skillKnown[me] or {}
        known = db.skillKnown[me][read.kind] or {}
        db.skillKnown[me][read.kind] = known
    end
    local r = read.rank
    for _, rec in ipairs(read.list) do
        local b = steps[rec.n] or {}
        steps[rec.n] = b
        Lower(b, "o", r)                                            -- (the lowest rank it was seen at, by anyone)
        if known then known[rec.n] = rec.p or known[rec.n] or true end      -- (what it makes, where it makes one)
        if rec.c == 3 then Higher(b, "yl", r)                       -- orange: all of its changes are still ahead
        elseif rec.c == 2 then Lower(b, "yh", r); Higher(b, "gl", r)
        elseif rec.c == 1 then Lower(b, "gh", r); Higher(b, "xl", r)
        else Lower(b, "xh", r) end
        if rec.p and #rec.r > 0 then
            local made = { m = math.max(1, rec.m or 1), k = read.kind, r = {} }
            for _, x in ipairs(rec.r) do
                if x.id ~= rec.p then made.r[x.id] = x.n end
            end
            if next(made.r) then db.skillMakes[rec.p] = made end
        end
    end
end

-- A colour change between the last rank seen before it and the first seen after it
local function Between(lo, hi)
    if not (lo and hi) then return nil end
    if hi - lo <= 2 then return hi end
    return math.floor((lo + hi + 1) / 2)
end

local function Clamp(v, lo, hi)
    if v and lo and v <= lo then v = lo + 1 end
    if v and hi and v > hi then v = hi end
    return v
end

-- Where a recipe turns yellow, green and grey: what was seen, and what is usual for the rest. b: what was learned,
-- c: its colour now, at rank
function LV.Thresholds(b, c, rank)
    b = b or {}
    local D = LV.BAND
    local Y, G, X = Between(b.yl, b.yh), Between(b.gl, b.gh), Between(b.xl, b.xh)
    if Y and G and G > Y then D = G - Y elseif G and X and X > G then D = X - G
    elseif Y and X and X > Y then D = (X - Y) / 2 end
    if not (Y or G or X) then
        -- nothing seen of its changes yet: your rank is taken to be halfway through its colour
        if c == 3 then Y = math.max(rank, b.yl or rank) + D / 2
        elseif c == 2 then Y = Clamp(rank - D / 2, b.yl, b.yh)
        elseif c == 1 then G = Clamp(rank - D / 2, b.gl, b.gh)
        else return nil end
    end
    if Y and not G then G = (X and (Y + X) / 2) or Y + D end
    if G and not Y then Y = G - D end
    if not X then X = G + D end
    return Clamp(Y, b.yl, b.yh), Clamp(G, b.gl, b.gh), Clamp(X, b.xl, b.xh)
end

-- The chance a craft gives a point at this rank
function LV.Chance(rank, Y, X)
    if not (Y and X) then return 0 end
    if rank < Y then return 1 end
    if rank >= X then return 0 end
    return (X - rank) / (X - Y)
end

-- The recipe to learn next: one this character does not know that still teaches at its rank, seen with one of
-- your other characters (the lowest rank it was seen at, too) or listed by the window as not learned yet.
-- name, rank (or nil)
function LV.NextRecipe(read)
    if not (read and read.kind and read.rank) then return nil end
    local db = ns.db or {}
    local me = ns.Inventory and ns.Inventory.Me and ns.Inventory.Me()
    local known = me and db.skillKnown and db.skillKnown[me] and db.skillKnown[me][read.kind] or {}
    local mine = {}
    for _, rec in ipairs(read.list or {}) do mine[rec.n] = true end
    local steps = db.skillSteps and db.skillSteps[read.kind] or {}
    local best, bestAt
    local function Consider(name, at)
        if mine[name] or known[name] then return end
        local b = steps[name]
        local X = b and select(3, LV.Thresholds(b, nil, read.rank))
        if X and X <= read.rank then return end                                          -- grey for you by now
        if b and b.o and b.o > read.cap then return end                                   -- past this rank's cap
        local better = not best or (at and not bestAt) or (at and bestAt and at < bestAt)
            or ((at == nil) == (bestAt == nil) and at == bestAt and name < best)
        if better then best, bestAt = name, at end
    end
    for _, name in ipairs(read.missing or {}) do Consider(name, steps[name] and steps[name].o) end
    for name, b in pairs(steps) do Consider(name, b.o) end
    return best, bestAt
end

---------------------------------------------------------------------------
-- What you have, and what things are made of
---------------------------------------------------------------------------
-- How many of an item you hold: yours (bags and bank) and your other characters' on this realm (to mail over)
function LV.Have(id)
    local mine, others = 0, 0
    local I = ns.Inventory
    local me = I and I.Me and I.Me()
    local all = ns.db and ns.db.inventory or {}
    if GetItemCount then
        local ok, n = pcall(GetItemCount, id, true)
        mine = (ok and Num(n)) or 0
    end
    local own = me and all[me]
    if own then mine = math.max(mine, (own.bags and own.bags[id] or 0) + (own.bank and own.bank[id] or 0)) end
    local realm = me and me:match("%-(.*)$")
    for who, rec in pairs(all) do
        if who ~= me and type(rec) == "table" and (not realm or who:match("%-(.*)$") == realm) then
            others = others + (type(rec.bags) == "table" and rec.bags[id] or 0) + (type(rec.bank) == "table" and rec.bank[id] or 0)
        end
    end
    return mine + others, mine, others
end

-- What an item is made of, by a recipe one of your characters knows: { m, r = { [reagent] = n } } or nil.
-- From the windows read here; for characters read before, from what each reagent was noted to make.
function LV.MadeOf(id)
    local makes = ns.db and ns.db.skillMakes
    if makes and makes[id] then return makes[id] end
    local found
    for _, rec in pairs(ns.db and ns.db.inventory or {}) do
        for kind, p in pairs(type(rec) == "table" and type(rec.prof) == "table" and rec.prof or {}) do
            for rid, list in pairs(type(p.crafts) == "table" and p.crafts or {}) do
                for _, k in ipairs(list) do
                    if k.p == id and rid ~= id then
                        found = found or { m = math.max(1, k.m or 1), k = kind, r = {} }
                        found.r[rid] = k.n or 1
                    end
                end
            end
        end
    end
    return found
end

local function SortedIds(set)
    local ids = {}
    for id in pairs(set) do ids[#ids + 1] = id end
    table.sort(ids)
    return ids
end

-- All the way down: need = { [item] = how many }. Returns
--   raw   = { [item] = how many more to gather or buy } (after what you hold, at every step of the way)
--   total = { [item] = how many of it the whole plan uses } (for the things in raw)
--   made  = { [item] = how many to make on the way }
--   via   = { [item] = what it is for }  (Copper Ore -> Copper Bar -> Bronze Bar)
function LV.Breakdown(need)
    local raw, total, made, via, used = {}, {}, {}, {}, {}
    local function Take(id, n, depth, seen, parent)
        if parent and not via[id] then via[id] = parent end
        local have = math.max(0, LV.Have(id) - (used[id] or 0))
        local take = math.min(have, n)
        used[id] = (used[id] or 0) + take
        local left = n - take
        local recipe = LV.MadeOf(id)
        if left > 0 and recipe and depth < LV.DEPTH and not seen[id] then
            local times = math.ceil(left / (recipe.m or 1))
            made[id] = (made[id] or 0) + left
            seen[id] = true
            for _, rid in ipairs(SortedIds(recipe.r)) do Take(rid, times * recipe.r[rid], depth + 1, seen, id) end
            seen[id] = nil
        else
            total[id] = (total[id] or 0) + n
            if left > 0 then raw[id] = (raw[id] or 0) + left end
        end
    end
    for _, id in ipairs(SortedIds(need)) do
        if need[id] > 0 then Take(id, need[id], 0, {}, nil) end
    end
    return raw, total, made, via
end

-- What the plan ultimately wants, and the way to get it. The plan works down to the raw things (Ruined Leather
-- Scraps), but a recipe asks for Medium Leather: that is what is listed, the raw things beside it in brackets (and
-- "cheaper to buy" where the auction house sells it for less than its materials cost). Returns rows
-- { id = the thing wanted, more, total, route = { { id, n, total } }, buy = true when buying it is cheaper }.
function LV.Wanted(plan)
    local groups, order = {}, {}
    local function Top(id)
        local x, guard = id, 0
        while plan.via[x] and guard < 12 do x = plan.via[x]; guard = guard + 1 end
        return x
    end
    local ids = SortedIds(plan.raw)
    for _, id in ipairs(ids) do
        local top = Top(id)
        local g = groups[top]
        if not g then
            g = { id = top, route = {} }
            groups[top] = g
            order[#order + 1] = g
        end
        if top == id then
            g.more, g.total = plan.raw[id], plan.total[id]
        else
            g.route[#g.route + 1] = { id = id, n = plan.raw[id], total = plan.total[id] }
        end
    end
    local M = ns.Market
    for _, g in ipairs(order) do
        if #g.route == 0 then
            g.route = nil
        else
            table.sort(g.route, function(a, b) if a.n ~= b.n then return a.n > b.n end return a.id < b.id end)
            g.more = g.more or (plan.made and plan.made[g.id]) or 0
            g.total = g.total or (plan.need and plan.need[g.id]) or g.more
            local priceTop = M and M.Auction and M.Auction(g.id)
            local make, known = 0, true
            for _, r in ipairs(g.route) do
                local p = M and M.Auction and M.Auction(r.id)
                if p then make = make + p * r.n else known = false end
            end
            if priceTop and known and make > 0 and priceTop * g.more < make then g.buy = true end
        end
    end
    table.sort(order, function(a, b)
        if (a.more or 0) ~= (b.more or 0) then return (a.more or 0) > (b.more or 0) end
        return a.id < b.id
    end)
    return order
end

-- What one of an item costs: the auction house's price, or what it is made of, or nil
local function Price(id, depth)
    local M = ns.Market
    local p = M and M.Auction and M.Auction(id)
    if p then return p end
    local recipe = (depth or 0) < LV.DEPTH and LV.MadeOf(id)
    if not recipe then return nil end
    local sum = 0
    for rid, n in pairs(recipe.r) do sum = sum + n * (Price(rid, (depth or 0) + 1) or LV.UNKNOWN) end
    return sum / (recipe.m or 1)
end
LV.Price = Price

local function CraftCost(rec)
    local sum = 0
    for _, x in ipairs(rec.r) do sum = sum + x.n * (Price(x.id) or LV.UNKNOWN) end
    return math.max(1, sum)
end

---------------------------------------------------------------------------
-- Following the guides
---------------------------------------------------------------------------
-- A guide (LevelGuides.lua): [kind] = { { from, to, p = makes, s = spell, n = crafts, m = made each, at = skill
-- it needs, learn = trainer|vendor|drop|quest, r = { reagent, n, ... }, name, alts = { same, why = { ... } } } },
-- or { from, to, gather = ore } where the guides level by gathering.
local function SpellName(id)
    local get = (C_Spell and C_Spell.GetSpellName) or GetSpellInfo
    if not get then return nil end
    local ok, name = pcall(get, id)
    name = ok and Plain(name)
    return type(name) == "string" and name ~= "" and name or nil
end

local function ItemNameOrNil(id)
    local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if not get then return nil end
    local ok, name = pcall(get, id)
    name = ok and Plain(name)
    return type(name) == "string" and name ~= "" and name or nil
end

-- The recipes the window shows, by what they make and by their spell
local function Mine(read)
    local mine = { p = {}, s = {} }
    for _, rec in ipairs(read.list or {}) do
        if rec.s then mine.s[rec.s] = rec end
        if rec.p and not mine.p[rec.p] then mine.p[rec.p] = rec end
    end
    return mine
end

-- A guide's recipe as the plan's own: the window's when you know it (true), else from the guide
function LV.GuideRecipe(g, mine)
    local known = (g.s and mine.s[g.s]) or (g.p and mine.p[g.p])
    if known then return known, true end
    local r = {}
    local list = type(g.r) == "table" and g.r or {}
    for i = 1, #list - 1, 2 do r[#r + 1] = { id = list[i], n = list[i + 1] } end
    local name = (g.s and SpellName(g.s)) or (g.p and ItemNameOrNil(g.p)) or g.name or "?"
    return { n = name, p = g.p, s = g.s, r = r, u = 1, m = g.m or 1, c = 3 }, false
end

-- The crafts for lo..hi, from the guide's count for its whole stretch
local function GuideCrafts(o, g, lo, hi)
    local from, to = o.lo or g[1], o.hi or g[2]                 -- (an alternative may have its own stretch)
    local span = math.max(1, to - from)
    return math.max(1, math.ceil((o.n or (o == g and g.n) or span) * (hi - lo) / span - 1e-6))
end

-- An alternative as the step shows it: another thing to gather, or another recipe
local function Alternative(o, g, lo, hi, mine)
    if o.gather then return { gather = o.gather, why = {} } end
    local rec, known = LV.GuideRecipe(o, mine)
    return { rec = rec, known = known, crafts = GuideCrafts(o, g, lo, hi), why = (o == g) and { "guide" } or o.why or {},
             learn = (not known) and { how = o.learn or "trainer", at = o.at } or nil }
end

-- The crafts a recipe you know takes for lo..hi by its colours (nil where it would turn grey on the way)
local function KnownCrafts(rec, lo, hi, rank, learned)
    local Y, _, X = LV.Thresholds(learned[rec.n], rec.c, rank)
    if not Y then return nil end
    local sum = 0
    for at = lo, hi - 1 do
        local chance = LV.Chance(at, Y, X)
        if chance <= 0 then return nil end
        sum = sum + 1 / (chance * (rec.u or 1))
    end
    return math.max(1, math.ceil(sum - 1e-6))
end

-- The plan's steps from the guide, or nil when the profession has none. And where the guide stops, if short of
-- the target.
function LV.GuideSteps(read, target)
    local guide = ns.LevelGuides and ns.LevelGuides[read.kind]
    if type(guide) ~= "table" or #guide == 0 then return nil end
    local mine = Mine(read)
    local learned = ns.db and ns.db.skillSteps and ns.db.skillSteps[read.kind] or {}
    local steps, reach = {}, read.rank
    for _, g in ipairs(guide) do
        local lo, hi = math.max(g[1], read.rank), math.min(g[2], target)
        if lo < hi then
            reach = math.max(reach, hi)
            local step = { from = lo, to = hi, guide = true, alts = {} }
            if g.gather then
                step.gather = g.gather
                for _, a in ipairs(g.alts or {}) do step.alts[#step.alts + 1] = Alternative(a, g, lo, hi, mine) end
            else
                local options = { g }
                for _, a in ipairs(g.alts or {}) do
                    if not a.gather then options[#options + 1] = a end
                end
                local main
                for _, o in ipairs(options) do                       -- the first you know that still teaches
                    local rec, known = LV.GuideRecipe(o, mine)
                    if known and (rec.c or 0) > 0 then main = o; break end
                end
                main = main or g
                local rec, known = LV.GuideRecipe(main, mine)
                step.rec, step.known = rec, known
                step.colour = known and rec.c or 3
                step.crafts = (known and KnownCrafts(rec, lo, hi, read.rank, learned)) or GuideCrafts(main, g, lo, hi)
                if not known then step.learn = { how = main.learn or "trainer", at = main.at } end
                for _, o in ipairs(options) do
                    if o ~= main then step.alts[#step.alts + 1] = Alternative(o, g, lo, hi, mine) end
                end
            end
            steps[#steps + 1] = step
        end
    end
    return steps, reach
end

---------------------------------------------------------------------------
-- The plan
---------------------------------------------------------------------------
-- { kind, name, rank, target, steps = { { rec, from, to, crafts, colour } }, need = { [item] = n }, raw, total,
--   made, via, short = points no recipe gives, capped = at the cap already }
function LV.Plan(read, target)
    if not (read and read.rank and read.cap) then return nil end
    local plan = { kind = read.kind, name = read.name, rank = read.rank, cap = read.cap, steps = {}, need = {} }
    target = math.min(target or read.cap, read.cap)
    plan.target = target
    if read.rank >= read.cap then plan.capped = true end
    local learned = ns.db and ns.db.skillSteps and ns.db.skillSteps[read.kind] or {}
    local options = {}
    for _, rec in ipairs(read.list) do
        if rec.c >= 1 then
            local Y, G, X = LV.Thresholds(learned[rec.n], rec.c, read.rank)
            if Y then options[#options + 1] = { rec = rec, Y = Y, G = G, X = X, cost = CraftCost(rec) } end
        end
    end
    local guided, reach = LV.GuideSteps(read, target)
    if guided then
        plan.steps, plan.guide = guided, true
        if reach < target and not plan.capped then plan.short = target - reach end
        for _, step in ipairs(plan.steps) do
            for _, x in ipairs(step.rec and step.rec.r or {}) do
                plan.need[x.id] = (plan.need[x.id] or 0) + step.crafts * x.n
            end
        end
        plan.raw, plan.total, plan.made, plan.via = LV.Breakdown(plan.need)
        plan.next, plan.nextAt = LV.NextRecipe(read)
        return plan
    end
    local s, last = read.rank, nil
    while s < target do
        local best, bestCost, bestChance
        for _, o in ipairs(options) do
            local chance = LV.Chance(s, o.Y, o.X)
            if chance > 0 then
                local per = o.cost / (chance * o.rec.u)
                if not best or per < bestCost - 1e-9 or (math.abs(per - bestCost) < 1e-9 and (chance > bestChance
                        or (chance == bestChance and o.rec.n < best.rec.n))) then
                    best, bestCost, bestChance = o, per, chance
                end
            end
        end
        if not best then plan.short = target - s; break end
        if not (last and last.o == best) then
            local colour = (s < best.Y and 3) or (s < best.G and 2) or 1
            last = { o = best, rec = best.rec, from = s, to = s, sum = 0, colour = colour }
            plan.steps[#plan.steps + 1] = last
        end
        last.sum = last.sum + 1 / (bestChance * best.rec.u)
        s = s + 1
        last.to = s
    end
    for _, step in ipairs(plan.steps) do
        step.crafts = math.max(1, math.ceil(step.sum - 1e-6))
        step.o, step.sum = nil, nil
        for _, x in ipairs(step.rec.r) do plan.need[x.id] = (plan.need[x.id] or 0) + step.crafts * x.n end
    end
    plan.raw, plan.total, plan.made, plan.via = LV.Breakdown(plan.need)
    plan.next, plan.nextAt = LV.NextRecipe(read)
    return plan
end

---------------------------------------------------------------------------
-- The panel
---------------------------------------------------------------------------
local frame
local WIDTH, ROW = 320, 20
LV.MODE_W = 96
LV.mode = "plan"

local function KeyName(key)
    if ns.KeyText then return ns.KeyText(key) end                  -- (your controller's own icons: PadIcons.lua)
    local text = GetBindingText and GetBindingText(key) or key
    return (type(text) == "string" and text ~= "") and text or key
end

local function ItemName(id)
    return ns.Professions and ns.Professions.ItemName(id) or ("item " .. tostring(id))
end

local function Icon(id)
    if id and C_Item and C_Item.GetItemIconByID then
        local ok, found = pcall(C_Item.GetItemIconByID, id)
        if ok and (type(found) == "number" or type(found) == "string") then return found end
    end
    return 134400                                                -- the game's question mark
end

local SKILL = {
    [3] = { "|cffff8040", "Professions-Icon-Skill-High" },
    [2] = { "|cffffff00", "Professions-Icon-Skill-Medium" },
    [1] = { "|cff40c040", "Professions-Icon-Skill-Low" },
}
function LV.RecipeText(name, colour)
    local s = SKILL[math.min(3, math.max(1, colour or 1))]
    return "|A:" .. s[2] .. ":12:12|a " .. s[1] .. tostring(name) .. "|r"
end

-- "Copper Bar > Bronze Bar": what a thing to gather is for
function LV.Chain(plan, id)
    local names, at, n = {}, plan.via[id], 0
    while at and n < LV.DEPTH do
        names[#names + 1] = ItemName(at)
        at, n = plan.via[at], n + 1
    end
    return table.concat(names, " > ")
end

-- The Mentor's words at the top of the panel: a few ways of putting each, picked when the window opens (LV.voice),
-- so they do not change with every craft. Each gets the plan and the first step.
local function Pick(list) return list[(LV.voice or 0) % #list + 1] end
LV.SAY = {
    none = { function() return L["Open a profession's window and I'll look over your recipes."] end },
    capped = {
        function(p) return L["That's the cap, %d. A trainer has the next rank for you."]:format(p.rank) end,
        function(p) return L["Nothing more to learn at %d. Go and see a trainer about the next rank."]:format(p.rank) end,
    },
    -- some points no recipe of yours gives: the next recipe, with the rank it was seen at
    nextAt = {
        function(p) return L["You've outgrown your recipes. See a trainer: %s is waiting at %d."]:format(p.next, p.nextAt) end,
        function(p) return L["%d more to %d, and what you know won't take you there. A trainer has %s for you at %d."]:format(
            p.target - p.rank, p.target, p.next, p.nextAt) end,
    },
    next = {
        function(p) return L["You've outgrown your recipes. See a trainer: %s is waiting."]:format(p.next) end,
        function(p) return L["Your recipes stop teaching you %d short of %d. Ask a trainer for %s."]:format(p.short,
            p.target, p.next) end,
    },
    short = {
        function(p) return L["Your recipes run dry %d short of %d. A trainer will have something new."]:format(p.short,
            p.target) end,
        function(p) return L["What you know won't carry you the last %d. Time to see a trainer."]:format(p.short) end,
    },
    -- the best recipe from here is green: it teaches, but not every time
    green = {
        function(p, s) return L["%s won't teach you much now, but it's the best you have. %d more to %d."]:format(
            s.rec.n, p.target - p.rank, p.target) end,
        function(p, s) return L["Slow going from here: %s gives a point now and then. %d to go."]:format(s.rec.n,
            p.target - p.rank) end,
    },
    -- the guides' first step is a recipe you do not know yet
    learn = {
        function(p, s) return L["First you'll want %s, %s. The guides start this stretch with it."]:format(s.rec.n,
            LV.Source(s.learn)) end,
        function(p, s) return L["Learn %s, %s, and we'll begin: %d more to %d."]:format(s.rec.n, LV.Source(s.learn),
            p.target - p.rank, p.target) end,
    },
    -- the guides level this stretch by gathering
    gather = {
        function(p, s) return L["%d more to %d. The guides send you out for %s until %d."]:format(p.target - p.rank,
            p.target, ItemNameOrNil(s.gather) or "?", s.to) end,
        function(p, s) return L["Gathering teaches you here: %s until %d."]:format(ItemNameOrNil(s.gather) or "?", s.to) end,
    },
    -- the guides' recipe, with another they offer
    alt = {
        function(p, s) return L["%d more to %d. Start with %s, or %s if you'd rather: %s."]:format(p.target - p.rank,
            p.target, s.rec.n, s.alts[1].rec.n, LV.Why(s.alts[1].why)) end,
        function(p, s) return L["%s first, as the guides have it. %s does the job too: %s."]:format(s.rec.n,
            s.alts[1].rec.n, LV.Why(s.alts[1].why)) end,
    },
    go = {
        function(p, s) return L["%d more to %d. Start with %s."]:format(p.target - p.rank, p.target, s.rec.n) end,
        function(p, s) return L["%s is your best teacher now. %d points to %d."]:format(s.rec.n, p.target - p.rank,
            p.target) end,
        function(p, s) return L["Steady hands. %s first, and %d to go."]:format(s.rec.n, p.target - p.rank) end,
    },
}

-- Where a recipe is learned, and why an alternative might suit you
LV.SOURCES = { trainer = L["at a trainer"], vendor = L["from a vendor"], drop = L["found as loot"],
               quest = L["from a quest"] }
function LV.Source(learn)
    return learn and LV.SOURCES[learn.how] or LV.SOURCES.trainer
end
LV.WHY = {
    cheap = L["cheaper materials"], vendor = L["materials from a vendor"], gathered = L["materials you gather yourself"],
    sells = L["it sells well"], useful = L["something you'll use"], fewer = L["fewer crafts"],
    recipe = L["a recipe you find or buy"], other = L["other materials"], guide = L["the guides' first choice"],
}
function LV.Why(codes)
    local parts = {}
    for _, code in ipairs(type(codes) == "table" and codes or {}) do
        if LV.WHY[code] then parts[#parts + 1] = LV.WHY[code] end
    end
    if #parts == 0 then parts[1] = LV.WHY.other end
    return table.concat(parts, ", ")
end

-- With the narrative off (Narrative.lua) no Mentor: the same plan in plain words, one way each (a kind without
-- plain words keeps The Mentor's)
LV.PLAIN = {
    none = function() return L["Open a profession's window for a levelling plan."] end,
    capped = function(p) return L["At the cap, %d. A trainer has the next rank."]:format(p.rank) end,
    nextAt = function(p) return L["%d more to %d; your recipes stop short. A trainer has %s at %d."]:format(
        p.target - p.rank, p.target, p.next, p.nextAt) end,
    next = function(p) return L["%d more to %d; your recipes stop short. A trainer has %s."]:format(p.target - p.rank,
        p.target, p.next) end,
    short = function(p) return L["Your recipes stop %d short of %d. A trainer has more."]:format(p.short, p.target) end,
    green = function(p, s) return L["%d more to %d. Best now: %s, green (a point now and then)."]:format(
        p.target - p.rank, p.target, s.rec.n) end,
    learn = function(p, s) return L["%d more to %d. First learn %s, %s."]:format(p.target - p.rank, p.target, s.rec.n,
        LV.Source(s.learn)) end,
    gather = function(p, s) return L["%d more to %d. Gather %s until %d."]:format(p.target - p.rank, p.target,
        ItemNameOrNil(s.gather) or "?", s.to) end,
    alt = function(p, s) return L["%d more to %d. First: %s, or %s (%s)."]:format(p.target - p.rank, p.target, s.rec.n,
        s.alts[1].rec.n, LV.Why(s.alts[1].why)) end,
    go = function(p, s) return L["%d more to %d. First: %s."]:format(p.target - p.rank, p.target, s.rec.n) end,
}
function LV.Voiced() return not ns.Narrative or ns.Narrative.On() end
local function Say(kind, plan, first)
    if not LV.Voiced() and LV.PLAIN[kind] then return LV.PLAIN[kind](plan, first) end
    return Pick(LV.SAY[kind])(plan, first)
end

function LV.Words(plan)
    if not plan then return Say("none") end
    local first = plan.steps[1]
    local kind
    if plan.capped then kind = "capped"
    elseif first and first.gather then kind = "gather"
    elseif first and first.learn then kind = "learn"
    elseif plan.short and plan.next then kind = plan.nextAt and "nextAt" or "next"
    elseif plan.short then kind = "short"
    elseif not first then kind = "short"
    elseif first.colour == 1 then kind = "green"
    elseif first.alts and first.alts[1] then kind = "alt"
    else kind = "go" end
    if kind == "short" and not plan.short then return Say("capped", plan) end
    return Say(kind, plan, first)
end

local function Build()
    frame = CreateFrame("Frame", "ControllerCamHUD_SkillPlanPanel", UIParent)
    frame:SetSize(WIDTH, 200)
    frame:SetFrameStrata("HIGH")
    frame:EnableMouse(true)
    frame.back = frame:CreateTexture(nil, "BACKGROUND")
    frame.back:SetAllPoints(frame)
    frame.back:SetColorTexture(0.03, 0.05, 0.09, 0.94)
    for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" } }) do
        local t = frame:CreateTexture(nil, "BORDER")
        t:SetPoint(side[1], frame, side[1])
        t:SetPoint(side[2], frame, side[2])
        t:SetHeight(1)
        t:SetColorTexture(0.98, 0.77, 0.31, 0.6)
    end
    frame.title = ns.FontString(frame, 12, "LEFT")
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -8)
    frame.title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -24, -8)
    frame.title:SetWidth(WIDTH - 20)
    if frame.title.SetWordWrap then frame.title:SetWordWrap(true) end      -- every word shows, at any text size
    frame.sub = ns.FontString(frame, 9, "LEFT")                -- The Mentor talking: warm parchment, wrapped
    frame.sub:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -4)
    frame.sub:SetPoint("TOPRIGHT", frame.title, "BOTTOMRIGHT", 0, -4)
    frame.sub:SetWidth(WIDTH - 20)
    if frame.sub.SetWordWrap then frame.sub:SetWordWrap(true) end
    frame.sub:SetTextColor(0.91, 0.86, 0.72)
    -- The Mentor's portrait: his profession's icon, beside his name (none with the narrative off)
    if ns.Narrative then
        frame.portrait = ns.Narrative.Portrait(frame, LV.PORTRAIT)
        frame.portrait:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -8)
        frame.portrait:Hide()
    end
    for i = 1, LV.ROWS do
        local r = CreateFrame("Button", nil, frame)
        r:SetSize(WIDTH - 12, ROW - 1)
        r.hl = r:CreateTexture(nil, "BACKGROUND")
        r.hl:SetAllPoints(r)
        r.hl:SetColorTexture(1, 1, 1, 0.1)
        r.hl:Hide()
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(16, 16)
        r.icon:SetPoint("LEFT", r, "LEFT", 2, 0)
        r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        r.text = ns.FontString(r, 9, "LEFT")
        r.text:SetPoint("LEFT", r.icon, "RIGHT", 5, 0)
        r.text:SetPoint("RIGHT", r, "RIGHT", -70, 0)
        r.right = ns.FontString(r, 9, "RIGHT")
        r.right:SetPoint("RIGHT", r, "RIGHT", -4, 0)
        r:SetScript("OnEnter", ns.Protect(function(self) if self.at then LV:Choose(self.at) end end))
        r:SetScript("OnClick", ns.Protect(function(self) if self.at then LV:Choose(self.at); LV:Farm(false) end end))
        LV.rows[i] = r
    end
    frame.detail = ns.FontString(frame, 9, "LEFT")
    frame.detail:SetPoint("LEFT", frame, "LEFT", 10, 0)
    frame.detail:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
    frame.detail:SetWidth(WIDTH - 20)
    if frame.detail.SetWordWrap then frame.detail:SetWordWrap(true) end
    frame.detail:SetTextColor(0.78, 0.88, 1)
    -- the bank's view and back: a button of ours (Y while the plan has the controller's buttons)
    frame.mode = CreateFrame("Button", nil, frame)
    frame.mode:SetSize(LV.MODE_W, 18)
    frame.mode:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 5)
    frame.mode.back = frame.mode:CreateTexture(nil, "BACKGROUND")
    frame.mode.back:SetAllPoints(frame.mode)
    frame.mode.back:SetColorTexture(0.56, 0.82, 1, 0.16)
    frame.mode.text = ns.FontString(frame.mode, 8, "CENTER")
    frame.mode.text:SetPoint("LEFT", frame.mode, "LEFT", 3, 0)
    frame.mode.text:SetPoint("RIGHT", frame.mode, "RIGHT", -3, 0)
    frame.mode:SetScript("OnClick", ns.Protect(function() LV:SetMode(LV.mode == "bank" and "plan" or "bank") end))
    frame.hint = ns.FontString(frame, 8, "LEFT")
    frame.hint:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, 6)
    frame.hint:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10 - LV.MODE_W, 6)
    frame.hint:SetWidth(WIDTH - 20 - LV.MODE_W)
    if frame.hint.SetWordWrap then frame.hint:SetWordWrap(true) end
    frame.hint:SetTextColor(unpack(C.muted))
    -- L3 while the window is open takes the plan's buttons (ns.PadKeys); B, or L3 again, gives them back
    LV.key = ns.PadKeys("PlanKey", { LV.KEY }, function()
        if ns.db.skillPlanHidden then LV:SetHidden(false) else LV:Focus(true) end
    end)
    -- put away: a small tab of ours where the panel was, with the button that brings it back
    LV.tab = CreateFrame("Button", "ControllerCamHUD_SkillPlanTab", UIParent)
    LV.tab:SetSize(132, 20)
    LV.tab:SetFrameStrata("HIGH")
    LV.tab.back = LV.tab:CreateTexture(nil, "BACKGROUND")
    LV.tab.back:SetAllPoints(LV.tab)
    LV.tab.back:SetColorTexture(0.03, 0.05, 0.09, 0.9)
    LV.tab.text = ns.FontString(LV.tab, 9, "CENTER")
    LV.tab.text:SetPoint("LEFT", LV.tab, "LEFT", 4, 0)
    LV.tab.text:SetPoint("RIGHT", LV.tab, "RIGHT", -4, 0)
    LV.tab.text:SetTextColor(0.98, 0.77, 0.31)
    LV.tab:SetScript("OnClick", ns.Protect(function() LV:SetHidden(false) end))
    LV.tab:Hide()
    -- and a close button on the panel (with a mouse)
    frame.close = CreateFrame("Button", nil, frame)
    frame.close:SetSize(16, 16)
    frame.close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
    frame.close.text = ns.FontString(frame.close, 11, "CENTER")
    frame.close.text:SetAllPoints(frame.close)
    frame.close.text:SetText("x")
    frame.close:SetScript("OnClick", ns.Protect(function() LV:SetHidden(true) end))
    LV.keys = ns.PadKeys("Plan", LV.KEYS, function(key) LV:Pad(key) end, function() LV:Focus(false) end)
    frame:SetScript("OnHide", ns.Protect(function()
        LV.focus = false
        LV.keys:Set(false)
        LV.key:Set(false)
    end))
    frame:Hide()
    LV.frame = frame
end

-- The game's profession window that is open, or nil
function LV.Window()
    for _, name in ipairs(LV.WINDOWS) do
        local w = _G[name]
        if type(w) == "table" and w.IsShown and w:IsShown() then return w end
    end
end

-- The rows: the recipes to make, then what is missing to make them
local function Entries(plan)
    local out = {}
    if not plan then return out end
    for _, step in ipairs(plan.steps) do
        out[#out + 1] = { step = step }
        for _, alt in ipairs(step.alts or {}) do out[#out + 1] = { alt = alt, step = step } end    -- the guides' others
    end
    local wanted = LV.Wanted(plan)
    if #wanted > 0 then out[#out + 1] = { head = L["To gather or buy"] } end
    for _, g in ipairs(wanted) do out[#out + 1] = { id = g.id, more = g.more, total = g.total, route = g.route, buy = g.buy } end
    return out
end

-- What you can make with your bank: the window's recipes (and ones this character was seen to know, for a list
-- a filter cut short), with the bank's reagents counted. Those only the bank makes possible first.
local function BankEntries(read)
    local out, seen, BK = {}, {}, LV.Bank
    if not BK then return out end
    local function Add(name, reagents, colour, p)
        if seen[name] or type(reagents) ~= "table" or #reagents == 0 then return end
        seen[name] = true
        local all, bags = BK.Makes(reagents)
        if all and all > 0 then out[#out + 1] = { make = { n = name, r = reagents, c = colour, p = p }, bags = bags, all = all } end
    end
    for _, rec in ipairs(read and read.list or {}) do Add(rec.n, rec.r, rec.c, rec.p) end
    local db = ns.db or {}
    local me = ns.Inventory and ns.Inventory.Me and ns.Inventory.Me()
    local known = read and me and db.skillKnown and db.skillKnown[me] and db.skillKnown[me][read.kind] or {}
    for name, made in pairs(known) do
        local m = type(made) == "number" and db.skillMakes and db.skillMakes[made]
        if m then
            local r = {}
            for _, id in ipairs(SortedIds(m.r)) do r[#r + 1] = { id = id, n = m.r[id] } end
            Add(name, r, nil, made)
        end
    end
    table.sort(out, function(a, b)
        local ga, gb = a.all > a.bags, b.all > b.bags
        if ga ~= gb then return ga end
        if a.all ~= b.all then return a.all > b.all end
        return a.make.n < b.make.n
    end)
    return out
end
LV.BankEntries = BankEntries

local function Reagents(rec, crafts)
    local parts = {}
    for _, x in ipairs(rec and rec.r or {}) do
        local need = crafts * x.n
        parts[#parts + 1] = ("%s %d/%d"):format(ItemName(x.id), math.min(LV.Have(x.id), need), need)
    end
    return L["%d crafts: %s"]:format(crafts, table.concat(parts, ", "))
end

local function Learn(learn)
    if not learn then return nil end
    if learn.at then return L["Learn it %s, at %d."]:format(LV.Source(learn), learn.at) end
    return L["Learn it %s."]:format(LV.Source(learn))
end

local function Detail(plan, e)
    if not e then return "" end
    if e.make then
        local parts = {}
        for _, x in ipairs(e.make.r) do
            local bags, bank = LV.Bank.Held(x.id)
            parts[#parts + 1] = L["%s: %d in your bags, %d in the bank, %d each"]:format(ItemName(x.id), bags, bank, x.n)
        end
        return table.concat(parts, "\n")
    end
    if e.alt and e.alt.gather then
        return L["The guides level this stretch by gathering %s."]:format(ItemName(e.alt.gather))
    end
    if e.alt then
        local text = Reagents(e.alt.rec, e.alt.crafts) .. "\n" .. LV.Why(e.alt.why)
        local learn = Learn(e.alt.learn)
        return learn and (text .. "\n" .. learn) or text
    end
    if e.step and e.step.gather then
        return L["The guides level this stretch by gathering %s."]:format(ItemName(e.step.gather))
    end
    if e.step then
        local text = Reagents(e.step.rec, e.step.crafts)
        local learn = Learn(e.step.learn)
        return learn and (text .. "\n" .. learn) or text
    end
    if e.id then
        local have = LV.Have(e.id)
        local text = L["%s: you have %d, the plan uses %d"]:format(ItemName(e.id), have, e.total or 0)
        local chain = LV.Chain(plan, e.id)
        if chain ~= "" then text = text .. "\n" .. L["for %s"]:format(chain) end
        if e.route then
            local parts = {}
            for _, r in ipairs(e.route) do parts[#parts + 1] = ("%s x%d"):format(ItemName(r.id), r.n) end
            text = text .. "\n" .. (e.buy and L["Cheaper to buy it than to make it from %s"] or L["Made from %s"]):format(table.concat(parts, ", "))
        end
        return text
    end
    return ""
end

-- How tall a wrapped text is (the game measures it; an estimate where it cannot)
local function TextHeight(fs, size)
    local text = fs.GetText and Plain(fs:GetText())
    if type(text) ~= "string" or text == "" then return 0 end
    local h = fs.GetStringHeight and Num(fs:GetStringHeight())
    if h and h > 0 then return math.ceil(h) end
    local plainText = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|A.-|a", "")
    local lines = 0
    local per = math.max(10, math.floor((WIDTH - 20) / (size * 0.55 * (ns.db and tonumber(ns.db.textScale) or 1))))
    for line in (plainText .. "\n"):gmatch("(.-)\n") do lines = lines + math.max(1, math.ceil(#line / per)) end
    return lines * (size + 3)
end
LV.TextHeight = TextHeight

-- The Mentor's face beside his words (his profession's icon; a book before there is a plan), or none with the
-- narrative off. The title and the words start past it; returns how far in.
LV.PORTRAIT = 36
LV.BOOK = "Interface\Icons\INV_Misc_Book_09"
function LV.Face(voiced, kind)
    local p = frame.portrait
    local left = (voiced and p) and (LV.PORTRAIT + 10) or 0
    if p then
        if left > 0 then
            ns.Narrative.Draw(p, { icon = (kind and ns.Narrative.ProfessionIcon(kind)) or LV.BOOK })
            p:Show()
        else
            p:Hide()
        end
    end
    frame.title:ClearAllPoints()
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 10 + left, -8)
    frame.title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -24, -8)
    frame.title:SetWidth(WIDTH - 34 - left)                      -- (clear of the close button)
    frame.sub:SetWidth(WIDTH - 20 - left)
    return left
end

function LV:Refresh()
    if not (frame and frame:IsShown()) then return end
    local plan = self.plan
    local bank = self.mode == "bank"
    self.entries = bank and BankEntries(self.read) or Entries(plan)
    local n = #self.entries
    while self.entries[self.index] and self.entries[self.index].head do self.index = self.index + 1 end
    self.index = ns.Clamp(self.index, 1, math.max(1, n))
    if self.index < self.top then self.top = self.index end
    if self.index > self.top + LV.ROWS - 1 then self.top = self.index - LV.ROWS + 1 end
    self.top = ns.Clamp(self.top, 1, math.max(1, n - LV.ROWS + 1))
    local voiced = LV.Voiced()
    local left = LV.Face(voiced, plan and plan.kind)                 -- (his portrait, or none)
    if bank then
        frame.title:SetText(voiced and L["The Mentor: what your bank can make"] or L["What your bank can make"])
        local only = 0
        for _, e in ipairs(self.entries) do if e.all > e.bags then only = only + 1 end end
        frame.sub:SetText(n == 0 and L["Nothing more to make with what's in your bank."]
            or L["%d you can make counting your bank, %d of them only with it."]:format(n, only))
    else
        if plan and voiced then
            frame.title:SetText(L["The Mentor: %s %d > %d"]:format(plan.name, plan.rank, plan.target))
        elseif plan then
            frame.title:SetText(("%s %d > %d"):format(plan.name, plan.rank, plan.target))
        else
            frame.title:SetText(voiced and L["The Mentor"] or L["Levelling plan"])
        end
        frame.sub:SetText(LV.Words(plan))
    end
    -- under the title and The Mentor's words, however many lines each takes
    local top = 8 + math.max(14, TextHeight(frame.title, 12)) + 4 + TextHeight(frame.sub, 9) + 8
    if left > 0 then top = math.max(top, 8 + LV.PORTRAIT + 8) end   -- (and under his portrait)
    local shown = 0
    for i, r in ipairs(self.rows) do
        local at = self.top + i - 1
        local e = self.entries[at]
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -top - (i - 1) * ROW)
        if e then
            shown = i
            r.at = (not e.head) and at or nil
            r.icon:ClearAllPoints()
            r.icon:SetPoint("LEFT", r, "LEFT", e.alt and 18 or 2, 0)
            if e.head then
                r.icon:Hide()
                r.text:SetText("|cffffd24a" .. e.head .. "|r")
                r.right:SetText("")
            elseif e.make then
                r.icon:Show()
                r.icon:SetTexture(e.make.p and Icon(e.make.p) or 134400)
                r.text:SetText(e.make.c and e.make.c > 0 and LV.RecipeText(e.make.n, e.make.c) or e.make.n)
                r.right:SetText(e.all > e.bags and ("%d |cff8fd0ff[%d]|r"):format(e.bags, e.all) or tostring(e.all))
            elseif e.alt and e.alt.gather then
                r.icon:Show()
                r.icon:SetTexture(Icon(e.alt.gather))
                r.text:SetText("|cff9d9d9d" .. L["or"] .. "|r " .. L["Gather %s"]:format(ItemName(e.alt.gather)))
                r.right:SetText("")
            elseif e.alt then
                r.icon:Show()
                r.icon:SetTexture(e.alt.rec.p and Icon(e.alt.rec.p) or 134400)
                r.text:SetText("|cff9d9d9d" .. L["or"] .. "|r " .. e.alt.rec.n .. "  |cff9d9d9d" .. LV.Why(e.alt.why) .. "|r")
                r.right:SetText("|cff9d9d9dx" .. e.alt.crafts .. "|r")
            elseif e.step and e.step.gather then
                r.icon:Show()
                r.icon:SetTexture(Icon(e.step.gather))
                r.text:SetText(L["Gather %s"]:format(ItemName(e.step.gather)))
                r.right:SetText(("%d-%d"):format(e.step.from, e.step.to))
            elseif e.step then
                r.icon:Show()
                r.icon:SetTexture(e.step.rec.p and Icon(e.step.rec.p) or 134400)
                local name = e.step.learn and ("|cffd8d8d8" .. e.step.rec.n .. "|r")
                    or LV.RecipeText(e.step.rec.n, e.step.colour)
                local text = name .. "  x" .. e.step.crafts
                if e.step.learn then text = text .. "  |cff8fd0ff" .. L["to learn"] .. "|r" end
                r.text:SetText(text)
                r.right:SetText(("%d-%d"):format(e.step.from, e.step.to))
            else
                r.icon:Show()
                r.icon:SetTexture(Icon(e.id))
                local text = ItemName(e.id)
                if e.route then
                    local how
                    if e.buy then
                        how = L["cheaper to buy"]
                    else
                        how = ("%s x%d"):format(ItemName(e.route[1].id), e.route[1].n)
                        if #e.route > 1 then how = how .. ", ..." end
                    end
                    text = text .. "  |cff9d9d9d(" .. how .. ")|r"
                end
                r.text:SetText(text)
                r.right:SetText(("+%d"):format(e.more))
            end
            if self.focus and at == self.index then r.hl:Show() else r.hl:Hide() end
            r:Show()
        else
            r.at = nil
            r:Hide()
        end
    end
    local y = top + shown * ROW + 4
    frame.detail:ClearAllPoints()
    frame.detail:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -y)
    frame.detail:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -y)
    frame.detail:SetText(self.focus and Detail(plan, self.entries[self.index]) or "")
    local detail = TextHeight(frame.detail, 9)
    if detail > 0 then y = y + detail + 6 end
    local wear = self.focus and LV.Wearable() and ("   %s %s"):format(KeyName("PADRSHOULDER"), L["Try on"]) or ""
    local away = ("   %s %s"):format(KeyName(LV.KEY), L["Hide"])
    if self.focus and bank then
        frame.hint:SetText(("%s %s%s   %s %s%s"):format(KeyName("PAD4"), L["The plan"], wear, KeyName("PAD2"), L["Back"],
            away))
    elseif self.focus then
        frame.hint:SetText(("%s %s   %s %s   %s %s%s   %s %s%s"):format(KeyName("PAD1"), L["Farm this"], KeyName("PAD3"),
            L["Farm all"], KeyName("PAD4"), L["With the bank"], wear, KeyName("PAD2"), L["Back"], away))
    else
        frame.hint:SetText(("%s %s, %s"):format(KeyName(LV.KEY), L["Use the plan"], L["twice to hide"]))
    end
    frame.mode.text:SetText(bank and L["The plan"] or L["With the bank"])
    local foot = math.max(18, TextHeight(frame.hint, 8))           -- then the buttons' line, at the bottom
    frame:SetHeight(math.floor(y + 6 + foot + 6 + 0.5))
    self.layout = { top = top, rows = shown, detail = detail, foot = foot, height = y + 12 + foot }
end

-- How far the window's own parts (its tabs down the right edge) stick out past it: read, never changed
function LV.Clearance(w)
    local right = Num(w.GetRight and w:GetRight())
    if not right then return 0 end
    local far = right
    local ok, kids = pcall(function() return { w:GetChildren() } end)
    for _, k in ipairs(ok and kids or {}) do
        if type(k) == "table" and k ~= w and k.IsShown and k:IsShown() then
            local r = Num(k.GetRight and k:GetRight())
            if r and r > far and r <= right + LV.REACH then far = r end
        end
    end
    return far - right
end

-- Beside the game's window, past its tabs; left of it, or under it, where the screen has no room on the right
-- (in the middle of the screen, away from one)
function LV:Place()
    if not frame then return end
    local w = LV.Window()
    local function At(...)
        frame:ClearAllPoints()
        frame:SetPoint(...)
        if LV.tab then LV.tab:ClearAllPoints(); LV.tab:SetPoint(...) end    -- (the tab, put away, where it goes)
    end
    if not w then At("CENTER", UIParent, "CENTER", 0, 40); return end
    local gap = 6 + LV.Clearance(w)
    local right, left = Num(w.GetRight and w:GetRight()), Num(w.GetLeft and w:GetLeft())
    local screen = Num(UIParent.GetRight and UIParent:GetRight()) or Num(UIParent.GetWidth and UIParent:GetWidth())
    if right and screen and right + gap + WIDTH > screen then
        if left and left >= WIDTH + 6 then At("TOPRIGHT", w, "TOPLEFT", -6, 0)
        else At("TOPLEFT", w, "BOTTOMLEFT", 0, -6) end
        return
    end
    At("TOPLEFT", w, "TOPRIGHT", gap, 0)
end

-- Something to try on: what the chosen row makes, else what the recipe chosen in the game's window makes, when it
-- is something you could wear. { id, link } or nil
function LV.Wearable()
    local B = ns.Bags
    if not (B and B.Dressable) then return nil end
    local function Check(id, link)
        if not id then return nil end
        if not link then
            local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
            if get then
                local ok, _, l = pcall(get, id)
                link = ok and type(Plain(l)) == "string" and l or nil
            end
        end
        link = link or ("item:" .. id)
        if B.Dressable({ id = id, link = link }) then return { id = id, link = link } end
    end
    local e = LV.focus and LV.entries[LV.index]
    local rec = e and ((e.alt and e.alt.rec) or (e.step and e.step.rec) or e.make)
    local found = rec and Check(rec.p)
    if found then return found end
    local index, get
    local trade, craft = _G.TradeSkillFrame, _G.CraftFrame
    if type(craft) == "table" and craft.IsShown and craft:IsShown() and GetCraftSelectionIndex then
        index, get = GetCraftSelectionIndex, GetCraftItemLink
    elseif type(trade) == "table" and trade.IsShown and trade:IsShown() and GetTradeSkillSelectionIndex then
        index, get = GetTradeSkillSelectionIndex, GetTradeSkillItemLink
    end
    if not (index and get) then return nil end
    local ok, i = pcall(index)
    i = ok and Num(i)
    if not i or i < 1 then return nil end
    local okL, link = pcall(get, i)
    link = okL and Plain(link)
    if type(link) ~= "string" then return nil end
    return Check(ItemOf(link), link)
end

-- The game's dressing room shows it on you, as a click with Ctrl does
function LV:TryOn()
    local w = LV.Wearable()
    if not w then ns.Say(L["Nothing here to try on."]); return false end
    ns.Bags.TryOn(w.link)
    return true
end

function LV:Show()
    if not frame then Build() end
    if ns.db.skillPlanHidden and not self.away then               -- put away: only the tab, to bring it back
        self:Place()
        frame:Hide()
        self.focus = false
        self.keys:Set(false)
        LV.tab.text:SetText(("%s %s"):format(KeyName(LV.KEY), L["The Mentor"]))
        LV.tab:Show()
        self.key:Set(true)
        return
    end
    LV.tab:Hide()
    if not frame:IsShown() then LV.voice = math.random(0, 59) end   -- The Mentor's way of saying things, this visit
    self:Place()
    frame:Show()
    if not self.focus then self.key:Set(true) end
    self:Refresh()
end

function LV:Hide()
    if frame then frame:Hide() end
    if LV.tab then LV.tab:Hide() end
    self.focus = false
    if self.keys then self.keys:Set(false) end
    if self.key then self.key:Set(false) end
end

-- Put the panel away (only its tab stays beside the window) or bring it back; remembered between sessions
function LV:SetHidden(on)
    ns.db.skillPlanHidden = on and true or false
    if not frame then return end
    if LV.Window() or not on then self:Show() else self:Hide() end
end

function LV:Focus(on)
    if not frame then return end
    self.focus = on and frame:IsShown() and true or false
    if self.focus then
        self.key:Set(false)
        self.keys:Set(true)
    else
        self.keys:Set(false)
        if frame:IsShown() then self.key:Set(true) end
    end
    self:Refresh()
end

-- The plan, or what your bank can make
function LV:SetMode(mode)
    self.mode = (mode == "bank") and "bank" or "plan"
    self.index, self.top = 1, 1
    self:Refresh()
end

function LV:Choose(at)
    local step = (at < self.index) and -1 or 1
    while self.entries[at] and self.entries[at].head do at = at + step end
    if not self.entries[at] then return end
    self.index = at
    self:Refresh()
end

-- The chosen row's missing things (or all of them) onto the farm list
function LV:Farm(all)
    local plan, F = self.plan, ns.Farm
    if not (plan and F) then return 0 end
    local added = 0
    if all then
        for _, id in ipairs(SortedIds(plan.raw)) do
            if F.Add(id, plan.total[id], true) then added = added + 1 end
        end
    else
        local e = self.entries[self.index]
        if e and (e.make or (e.alt and e.alt.gather) or (e.step and e.step.gather and not e.alt)) then return 0 end
        if e and e.alt then
            local need = {}
            for _, x in ipairs(e.alt.rec.r) do need[x.id] = e.alt.crafts * x.n end
            local raw, total = LV.Breakdown(need)
            for _, id in ipairs(SortedIds(raw)) do
                if F.Add(id, total[id], true) then added = added + 1 end
            end
        elseif e and e.id and e.route then
            for _, r in ipairs(e.route) do
                if F.Add(r.id, r.total, true) then added = added + 1 end
            end
        elseif e and e.id then
            if F.Add(e.id, e.total, true) then added = 1 end
        elseif e and e.step then
            local need = {}
            for _, x in ipairs(e.step.rec.r) do need[x.id] = e.step.crafts * x.n end
            local raw, total = LV.Breakdown(need)
            for _, id in ipairs(SortedIds(raw)) do
                if F.Add(id, total[id], true) then added = added + 1 end
            end
        end
    end
    if added > 0 then ns.Say(L["%d added to the farm list."]:format(added))
    else ns.Say(L["Nothing missing: you have what it takes."]) end
    return added
end

function LV:Pad(key)
    if not (frame and frame:IsShown()) then return false end
    if key == "PADDUP" then self:Choose(self.index - 1)
    elseif key == "PADDDOWN" then self:Choose(self.index + 1)
    elseif key == "PAD4" then self:SetMode(self.mode == "bank" and "plan" or "bank")
    elseif key == "PADRSHOULDER" then self:TryOn()
    elseif self.mode == "bank" and (key == "PAD1" or key == "PAD3") then return true      -- (the plan's buttons)
    elseif key == "PAD1" then self:Farm(false)
    elseif key == "PAD3" then self:Farm(true)
    elseif key == "PADLSTICK" then self:SetHidden(true)                    -- L3 again: put it away
    elseif key == "PAD2" or key == "ESCAPE" then self:Focus(false)
    else return false end
    return true
end

---------------------------------------------------------------------------
-- Listening
---------------------------------------------------------------------------
function LV:Update(craft)
    local read = LV.Read(craft)
    local before = self.read
    if read and before and before.kind == read.kind and before.rank == read.rank and #read.list < #before.list then
        LV.Learn(read)                       -- a filtered list (a search): learned from, the plan stays whole
        read = nil
        self:Refresh()
        return
    end
    if read then
        LV.Learn(read)
        self.read = read
        self.plan = LV.Plan(read)
        self.reads = self.reads + 1
        ns.Note("levelling: %s %s/%s, %d recipes, %d steps, %d to gather", read.kind, tostring(read.rank),
            tostring(read.cap), #read.list, self.plan and #self.plan.steps or 0, #SortedIds(self.plan and self.plan.raw or {}))
    end
    if self.active and ns.db.skillPlan and LV.Window() then
        if read then self.away = false; self:Show()
        elseif not self.away then self:Hide() end              -- a window with nothing to level (no recipes)
    end
    self:Refresh()
end

local pending = {}
local function Soon(what)
    if pending[what] then return end
    pending[what] = true
    C_Timer.After(0.35, function()
        pending[what] = nil
        local ok, err = pcall(function()
            if what == "close" then
                if not LV.Window() then LV:Hide() end
            elseif what == "bags" then
                LV:Refresh()
            else
                LV:Update(what == "craft")
            end
        end)
        if not ok then ns.Error(err) end
    end)
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", ns.Protect(function(_, event)
    if event == "TRADE_SKILL_CLOSE" or event == "CRAFT_CLOSE" then Soon("close")
    elseif event == "CRAFT_SHOW" or event == "CRAFT_UPDATE" then Soon("craft")
    elseif event == "BAG_UPDATE_DELAYED" then Soon("bags")
    else Soon("window") end
end))
-- (a window closed without saying so: looked at now and then while the panel, or its tab, is up)
local since = 0
events:SetScript("OnUpdate", ns.Protect(function(_, dt)
    if not ((frame and frame:IsShown()) or (LV.tab and LV.tab:IsShown())) or LV.away then return end
    since = since + dt
    if since < 0.5 then return end
    since = 0
    if not LV.Window() then LV:Hide() end
end))

local EVENTS = { "TRADE_SKILL_SHOW", "TRADE_SKILL_UPDATE", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_CLOSE", "CRAFT_SHOW",
                 "CRAFT_UPDATE", "CRAFT_CLOSE", "BAG_UPDATE_DELAYED" }

function LV:Apply(run)
    local on = run and ns.db.skillPlan and true or false
    if on and not self.active then
        self.active = true
        for _, e in ipairs(EVENTS) do pcall(events.RegisterEvent, events, e) end
        if LV.Window() then Soon("window") end
    elseif not on and self.active then
        self.active = false
        events:UnregisterAllEvents()
        self:Hide()
    end
end

-- /cchud levelplan: the plan of the window last read (beside it while it is open, else in the middle)
function LV:Toggle()
    if frame and frame:IsShown() then
        if LV.Window() and not self.away then self:SetHidden(true) else self.away = false; self:Hide() end
        return false
    end
    if ns.db.skillPlanHidden and LV.Window() then ns.db.skillPlanHidden = false end
    if not self.plan then ns.Say(L["Open a profession's window to make a plan."]); return false end
    self.away = LV.Window() == nil
    self:Show()
    self:Focus(true)
    return true
end

function ControllerCamHUD_SkillPlan() ns.Protect(function() LV:Toggle() end)() end
BINDING_NAME_CCHUD_SKILLPLAN = L["The Mentor (levelling plan): show / hide"]
ns.RegisterCommand("levelplan", function() LV:Toggle() end, "/cchud levelplan",
    "show the levelling plan of the profession window you opened last, with the controller's buttons on it")

function LV.Describe()
    local p = LV.plan
    local steps = 0
    for _, list in pairs(ns.db and ns.db.skillSteps or {}) do for _ in pairs(list) do steps = steps + 1 end end
    local makes = 0
    for _ in pairs(ns.db and ns.db.skillMakes or {}) do makes = makes + 1 end
    return { ("on %s, windows read %d, recipes with colours seen %d, things known to be made of others %d"):format(
        tostring(ns.db and ns.db.skillPlan), LV.reads, steps, makes),
        p and ("plan: %s %d > %d, %d steps, %d to gather, short %s; panel shown %s, buttons %s"):format(p.kind, p.rank,
            p.target, #p.steps, #SortedIds(p.raw), tostring(p.short or 0), tostring(frame ~= nil and frame:IsShown()),
            tostring(LV.focus or false)) or "plan: none yet" }
end

ns.RegisterCheck(function(row, run, db)
    if frame and frame:IsShown() and not LV.away then
        row("the levelling plan is up only beside a profession's window", LV.Window() ~= nil)
    end
    if not (run and db.skillPlan) then
        row("the levelling plan is off", not (frame and frame:IsShown()) or LV.away == true)
    end
end)

ns.RegisterModule("levelling", LV)

---------------------------------------------------------------------------
-- With the bank: how many of a recipe you could make counting your bank too
---------------------------------------------------------------------------
-- The game's recipe list says how many you can make from your bags ("Heavy Silk Bandage [20]"). Beside it a
-- second number, in blue, counts your bank as well ("[20] [40]"): the bank as the game knows it now, or as you
-- last saw it. It shows only when it is more. It is our own text over the list: nothing in the game's window
-- is changed, and the game's own count stays as the game has it.
local BK = { labels = {}, cache = {}, shown = 0 }
LV.Bank = BK
BK.POLL = 0.2              -- how often the rows are looked at while a window is open (they scroll without an event)
BK.COLOUR = "|cff8fd0ff"   -- the bank's blue, as in an item's tooltip
BK.ROWS = { { window = "TradeSkillFrame", prefix = "TradeSkillSkill" }, { window = "CraftFrame", prefix = "Craft", craft = true } }


local function Field(t, k) return type(t) == "table" and rawget(t, k) or nil end

-- How many of an item are in your bags, and how many in your bank
function BK.Held(id)
    local bags, all = 0, 0
    if GetItemCount then
        local ok, n = pcall(GetItemCount, id)
        bags = (ok and Num(n)) or 0
        local okB, m = pcall(GetItemCount, id, true)
        all = (okB and Num(m)) or bags
    end
    local live = math.max(0, all - bags)
    local I = ns.Inventory
    if I and I.bankOpen then return bags, live end                    -- the bank is open: the game knows it now
    local me = I and I.Me and I.Me()
    local rec = me and ns.db and type(ns.db.inventory) == "table" and ns.db.inventory[me]
    local kept = rec and type(rec.bank) == "table" and tonumber(rec.bank[id]) or 0
    return bags, math.max(live, kept)
end

-- How many crafts the reagents make: { { id, n } } > with the bank, from the bags alone (nil: a reagent unknown)
function BK.Makes(reagents)
    if type(reagents) ~= "table" or #reagents == 0 then return nil end
    local withBank, fromBags
    for _, r in ipairs(reagents) do
        if not r.id then return nil end
        local bags, bank = BK.Held(r.id)
        local need = math.max(1, r.n or 1)
        local a, b = math.floor((bags + bank) / need), math.floor(bags / need)
        withBank = withBank and math.min(withBank, a) or a
        fromBags = fromBags and math.min(fromBags, b) or b
    end
    return withBank, fromBags
end

local function ClassicReagents(craft, index)
    local count = craft and GetCraftNumReagents or GetTradeSkillNumReagents
    local link = craft and GetCraftReagentItemLink or GetTradeSkillReagentItemLink
    local info = craft and GetCraftReagentInfo or GetTradeSkillReagentInfo
    if not (count and link) then return nil end
    local list = {}
    local ok, k = pcall(count, index)
    for j = 1, (ok and Num(k)) or 0 do
        local okL, l = pcall(link, index, j)
        local need = 1
        if info then
            local okC, _, _, c = pcall(info, index, j)
            need = (okC and Num(c)) or 1
        end
        list[#list + 1] = { id = okL and ItemOf(l) or nil, n = need }
    end
    return list
end

-- One recipe row of the older windows: the reagents (read once, until bags or the list change), the game's count
local function ClassicRow(craft, index)
    local okI, name, kind, available
    if craft then
        if not GetCraftInfo then return nil end
        local _, k, n
        okI, name, _, k, n = pcall(GetCraftInfo, index)
        kind, available = k, n
    else
        if not GetTradeSkillInfo then return nil end
        okI, name, kind, available = pcall(GetTradeSkillInfo, index)
    end
    name, kind = okI and Plain(name), okI and Plain(kind)
    if type(name) ~= "string" or not CLASSIC[kind or ""] then return nil end          -- (headers have no count)
    local key = (craft and "c:" or "t:") .. index .. ":" .. name
    if BK.cache[key] == nil then BK.cache[key] = ClassicReagents(craft, index) or false end
    return BK.cache[key] or nil, Num(available) or 0
end

-- One recipe row of the newer window (read from the list's own data, never changed)
local function ModernRow(row)
    local data
    if row.GetElementData then
        local ok, d = pcall(row.GetElementData, row)
        data = ok and d or nil
    end
    if type(data) == "table" and data.GetData then
        local ok, d = pcall(data.GetData, data)
        data = ok and d or nil
    end
    local info = type(data) == "table" and rawget(data, "recipeInfo")
    local id = type(info) == "table" and Num(info.recipeID)
    if not id then return nil end
    local key = "m:" .. id
    if BK.cache[key] == nil then
        local T, list = C_TradeSkillUI, false
        if T and T.GetRecipeSchematic then
            local okS, s = pcall(T.GetRecipeSchematic, id, false)
            if okS and type(s) == "table" and type(s.reagentSlotSchematics) == "table" then
                list = {}
                for _, slot in ipairs(s.reagentSlotSchematics) do
                    if slot.reagentType == nil or slot.reagentType == 1 then                 -- the basic reagents
                        local first = type(slot.reagents) == "table" and slot.reagents[1]
                        list[#list + 1] = { id = first and Num(first.itemID), n = Num(slot.quantityRequired) or 1 }
                    end
                end
            end
        end
        BK.cache[key] = list
    end
    return BK.cache[key] or nil, Num(info.numAvailable) or 0
end

-- The recipe rows on screen: each(row, the text ours goes after, reagents, the game's count, the window)
local function EachRow(each)
    for _, kind in ipairs(BK.ROWS) do
        local w = _G[kind.window]
        if type(w) == "table" and w.IsShown and w:IsShown() then
            for i = 1, 40 do
                local b = _G[kind.prefix .. i]
                if type(b) ~= "table" then break end
                local index = b.IsShown and b:IsShown() and b.GetID and Num(b:GetID())
                if index and index > 0 then
                    local reagents, game = ClassicRow(kind.craft, index)
                    if reagents then
                        local count = _G[kind.prefix .. i .. "Count"]
                        local text = type(count) == "table" and count.GetText and Plain(count:GetText())
                        local after = (type(text) == "string" and text ~= "" and count)
                            or _G[kind.prefix .. i .. "Text"] or (b.GetFontString and b:GetFontString())
                        each(b, after, reagents, game, w)
                    end
                end
            end
        end
    end
    local pf = _G.ProfessionsFrame
    if type(pf) == "table" and pf.IsShown and pf:IsShown() then
        local box = Field(Field(Field(pf, "CraftingPage"), "RecipeList"), "ScrollBox")
        if box and box.ForEachFrame then
            pcall(box.ForEachFrame, box, function(row)
                if type(row) ~= "table" or not (row.IsShown and row:IsShown()) then return end
                local reagents, game = ModernRow(row)
                if not reagents then return end
                local count = Field(row, "Count")
                local text = count and count.GetText and Plain(count:GetText())
                each(row, (type(text) == "string" and text ~= "" and count) or Field(row, "Label"), reagents, game, pf)
            end)
        end
    end
end

local function Label(i)
    local l = BK.labels[i]
    if not l then
        l = ns.FontString(BK.frame, 10, "LEFT")
        BK.labels[i] = l
    end
    return l
end

-- Ours after the game's text: in the same font, just past it, kept inside the row
local function Place(l, row, after)
    l:ClearAllPoints()
    if type(after) == "table" and after.GetFont then
        local ok, file, size, flags = pcall(after.GetFont, after)
        if ok and type(file) == "string" and type(size) == "number" then pcall(l.SetFont, l, file, size, flags) end
    end
    local width = type(after) == "table" and after.GetStringWidth and Num(after:GetStringWidth())
    if not width then
        l:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        return
    end
    local x = width + 3
    local left, right = Num(after.GetLeft and after:GetLeft()), Num(row.GetRight and row:GetRight())
    local own = Num(l.GetStringWidth and l:GetStringWidth()) or 0
    if left and right and left + x + own > right - 2 then x = math.max(0, right - 2 - own - left) end
    l:SetPoint("LEFT", after, "LEFT", x, 0)
end

function BK:Refresh()
    if not self.frame then return end
    local used = 0
    if self.active and ns.db and ns.db.skillBank then
        EachRow(function(row, after, reagents, game, window)
            local withBank = BK.Makes(reagents)
            if not withBank or withBank <= game then return end
            used = used + 1
            if used == 1 then                                  -- drawn just over the window, not over everything
                local okS, strata = pcall(window.GetFrameStrata, window)
                local okL, level = pcall(window.GetFrameLevel, window)
                if okS and type(strata) == "string" then self.frame:SetFrameStrata(strata) end
                if okL and type(level) == "number" then self.frame:SetFrameLevel(level + 50) end
            end
            local l = Label(used)
            l:SetText(BK.COLOUR .. "[" .. withBank .. "]|r")
            Place(l, row, after)
            l:Show()
        end)
    end
    for i = used + 1, #self.labels do self.labels[i]:SetText(""); self.labels[i]:Hide() end
    self.shown = used
end

local function AnyWindow()
    for _, name in ipairs(LV.WINDOWS) do
        local w = _G[name]
        if type(w) == "table" and w.IsShown and w:IsShown() then return true end
    end
    return false
end

local BANK_EVENTS = { "TRADE_SKILL_SHOW", "TRADE_SKILL_UPDATE", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_CLOSE",
                      "CRAFT_SHOW", "CRAFT_UPDATE", "CRAFT_CLOSE", "BAG_UPDATE_DELAYED", "BANKFRAME_OPENED",
                      "BANKFRAME_CLOSED" }

local function BuildBank()
    BK.frame = CreateFrame("Frame", "ControllerCamHUD_BankCounts", UIParent)
    BK.frame:SetAllPoints(UIParent)
    BK.frame:EnableMouse(false)
    local since = 0
    BK.frame:SetScript("OnEvent", ns.Protect(function(_, event)
        if event ~= "TRADE_SKILL_SHOW" and event ~= "CRAFT_SHOW" then BK.cache = {} end   -- bags, bank or list changed
        since = BK.POLL                                                                    -- looked at on the next frame
    end))
    BK.frame:SetScript("OnUpdate", ns.Protect(function(_, dt)
        since = since + dt
        if since < BK.POLL then return end
        since = 0
        if AnyWindow() then BK:Refresh() elseif BK.shown > 0 then BK.cache = {}; BK:Refresh() end
    end))
end

function BK:Apply(run)
    local on = run and ns.db.skillBank and true or false
    if on and not self.active then
        if not self.frame then BuildBank() end
        self.active = true
        for _, e in ipairs(BANK_EVENTS) do pcall(self.frame.RegisterEvent, self.frame, e) end
        self.frame:Show()
    elseif not on and self.active then
        self.active = false
        self.frame:UnregisterAllEvents()
        self.cache = {}
        self:Refresh()
        self.frame:Hide()
    end
end

-- (the debug report's levelling section gets a line for these counts)
local DescribePlan = LV.Describe
function LV.Describe()
    local lines = DescribePlan()
    lines[#lines + 1] = ("counts with the bank: on %s, shown %d"):format(tostring(ns.db and ns.db.skillBank), BK.shown)
    return lines
end

ns.RegisterCheck(function(row, run, db)
    if not (run and db.skillBank) then row("no counts with the bank on the game's profession window", BK.shown == 0) end
end)

ns.RegisterModule("craftbank", BK)
