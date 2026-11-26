-- ControllerCam HUD: Cooking and First Aid recipes (RecipeData.lua) and what they mean for what you carry.
--   * A material one of your characters could still level with is kept, and the tooltip says which recipe it
--     goes into and where that recipe is learned: a trainer, a vendor (who and where), a quest or a drop. Also
--     for a recipe that character has not learned yet, and before the profession's window was ever opened.
--   * A recipe's item (Recipe: Mystery Stew) and a profession's skill book are kept for the character of yours
--     who can still use them.
--   * For The Mentor: where a material comes from (farm, vendor or auction) and the ranks a recipe changes
--     colour at.
-- Only read: nothing of the game's is changed.

local ADDON, ns = ...
local L = ns.L

local R = {}
ns.Recipes = R

R.KINDS = { "cooking", "firstaid" }
R.AHEAD = 100             -- a recipe this far past your rank still keeps its materials; further off, a note only

local function Plain(v) if ns.IsSecret(v) then return nil end return v end

-- Built once from the data: uses[reagent] = { { kind, rec }, ... }, books[recipe item] = { kind, rec },
-- made[kind][product] = rec
local index
local function Index()
    if index then return index end
    index = { uses = {}, books = {}, made = {} }
    local data = ns.RecipeData or {}
    for _, kind in ipairs(R.KINDS) do
        index.made[kind] = {}
        for _, rec in ipairs(data[kind] or {}) do
            index.made[kind][rec.p] = rec
            if rec.book then index.books[rec.book] = { kind = kind, rec = rec } end
            for i = 1, #rec.r - 1, 2 do
                local list = index.uses[rec.r[i]] or {}
                index.uses[rec.r[i]] = list
                list[#list + 1] = { kind = kind, rec = rec }
            end
        end
    end
    return index
end

-- The recipe of a profession that makes an item, or nil
function R.For(kind, product)
    local made = kind and Index().made[kind]
    return made and product and made[product] or nil
end

---------------------------------------------------------------------------
-- Names
---------------------------------------------------------------------------
local function SpellName(id)
    local get = (C_Spell and C_Spell.GetSpellName) or GetSpellInfo
    if not (get and id) then return nil end
    local ok, name = pcall(get, id)
    name = ok and Plain(name)
    return type(name) == "string" and name ~= "" and name or nil
end

local function ItemName(id)
    local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if not get then return nil end
    local ok, name = pcall(get, id)
    name = ok and Plain(name)
    return type(name) == "string" and name ~= "" and name or nil
end

-- A recipe's name in your language: its spell's, else what it makes, else the English one
function R.Name(rec)
    return SpellName(rec.s) or ItemName(rec.p) or rec.name
end

-- A zone's name in your language (the game's, by its area ID), else in English
function R.Zone(area)
    if C_Map and C_Map.GetAreaInfo then
        local ok, name = pcall(C_Map.GetAreaInfo, area)
        name = ok and Plain(name)
        if type(name) == "string" and name ~= "" then return name end
    end
    local zones = ns.RecipeData and ns.RecipeData.zones
    return zones and zones[area] or "?"
end

---------------------------------------------------------------------------
-- Where a recipe is learned
---------------------------------------------------------------------------
-- "A" or "H" for a faction as the game names it, or nil
function R.Side(faction)
    if faction == "Alliance" then return "A" elseif faction == "Horde" then return "H" end
    return nil
end

-- This character's side
function R.MySide()
    local get = UnitFactionGroup
    if not get then return nil end
    local ok, faction = pcall(get, "player")
    return ok and R.Side(Plain(faction)) or nil
end

local function Serves(side, mine) return side == "B" or not mine or side == mine end

local function Here()
    local get = GetRealZoneText or GetZoneText
    if not get then return nil end
    local ok, name = pcall(get)
    name = ok and Plain(name)
    return type(name) == "string" and name or nil
end

-- A walking trader (Desolace's two on the road): one in stock at a time, wherever they are
local function Walks(v) return v[3] == "on the road" end

-- The vendors of a recipe who sell to your side: one in the zone you are in first, then those who stay put, as
-- listed; walking traders last
function R.Vendors(rec, side)
    local all = ns.RecipeData and ns.RecipeData.vendors
    local here = Here()
    local near, stay, walk = {}, {}, {}
    for _, i in ipairs(rec.v or {}) do
        local v = all and all[i]
        if v and Serves(v[4], side) then
            if Walks(v) then walk[#walk + 1] = v
            elseif here and R.Zone(v[2]) == here then near[#near + 1] = v
            else stay[#stay + 1] = v end
        end
    end
    for _, v in ipairs(stay) do near[#near + 1] = v end
    for _, v in ipairs(walk) do near[#near + 1] = v end
    return near
end

-- The best way to learn it for your side: { how, order (lower is easier), vendors, quest, drop }, or nil when your
-- side has none. how: "trainer", "vendor", "quest", "drop", "season"
function R.Source(rec, side)
    if rec.trainer then return { how = "trainer", order = 1 } end
    if rec.season then return { how = "season", order = 6 } end
    local vendors = R.Vendors(rec, side)
    if vendors[1] and not Walks(vendors[1]) then return { how = "vendor", order = 2, vendors = vendors } end
    for _, q in ipairs(rec.q or {}) do
        if Serves(q[3], side) then return { how = "quest", order = 3, quest = q } end
    end
    if vendors[1] then return { how = "vendor", order = 4, vendors = vendors } end
    if rec.drop then return { how = "drop", order = 5, drop = rec.drop } end
    return nil
end

-- A vendor and where they stand: "Ogg'marr in Brackenwall Village, Dustwallow Marsh"
local function VendorWords(v)
    local zone = R.Zone(v[2])
    if Walks(v) then return L["%s, who walks the road in %s"]:format(v[1], zone) end
    if v[3] ~= "" then return L["%s in %s"]:format(v[1], v[3] .. ", " .. zone) end
    return L["%s in %s"]:format(v[1], zone)
end

-- Where to get a recipe, in one sentence: "The recipe is sold by Ogg'marr in Brackenwall Village, Dustwallow
-- Marsh (2 more vendors sell it)". prof: the profession's name, for a trainer's
function R.Where(source, prof)
    if not source then return nil end
    if source.how == "trainer" then return L["Any %s trainer teaches it"]:format(prof) end
    if source.how == "season" then return L["The recipe is sold only during the Feast of Winter Veil"] end
    if source.how == "quest" then
        return L["The recipe is a quest reward: %s (%s)"]:format(source.quest[1], R.Zone(source.quest[2]))
    end
    if source.how == "drop" then
        local zone, who = source.drop[1], source.drop[2]
        if who ~= "" then return L["The recipe drops from %s in %s"]:format(who, R.Zone(zone)) end
        if zone > 0 then return L["The recipe drops from creatures in %s"]:format(R.Zone(zone)) end
        return L["The recipe is a rare drop from creatures around the world"]
    end
    local text = L["The recipe is sold by %s"]:format(VendorWords(source.vendors[1]))
    if #source.vendors > 1 then text = text .. " " .. L["(more sellers: %d)"]:format(#source.vendors - 1) end
    return text
end

---------------------------------------------------------------------------
-- Your characters
---------------------------------------------------------------------------
-- Does this character know the recipe? true; false when its profession's window was read without it; nil when the
-- window was never read, so nothing says
function R.Knows(who, kind, rec)
    local db = ns.db or {}
    local record = db.inventory and db.inventory[who]
    local p = record and record.prof and record.prof[kind]
    for _, list in pairs(p and type(p.crafts) == "table" and p.crafts or {}) do
        for _, c in ipairs(list) do
            if c.p == rec.p then return true end
        end
    end
    local known = db.skillKnown and db.skillKnown[who] and db.skillKnown[who][kind]
    if known then
        for name, product in pairs(known) do
            if product == rec.p or name == rec.name then return true end
        end
        local own = SpellName(rec.s)
        if own and known[own] then return true end
    end
    if p and p.at then return false end
    return nil
end

-- Your characters on this realm with a profession (you first): { who, mine, class, side, name, rank, cap }
local function With(kind)
    local out = {}
    local P = ns.Professions
    if not (P and P.Characters) then return out end
    for c in P.Characters() do
        local others = ns.db.gatherSkills and ns.db.gatherSkills[c.who]
        local p = c.rec.prof[kind] or (others and others[kind]) or nil
        local rank = p and tonumber(p.rank)
        if rank then
            out[#out + 1] = { who = c.who, mine = c.mine, class = c.rec.class, side = R.Side(c.rec.faction),
                              name = tostring(p.name or kind), rank = rank, cap = tonumber(p.cap) }
        end
    end
    return out
end

local function Short(who) return ns.Professions.Short(who) end

-- Every recipe of one of your characters this material could still level with (orange or yellow once learned),
-- best first: you before your other characters, recipes in reach before far ones, then what you know, what a
-- trainer teaches, a vendor's, a quest's, a walking trader's, a drop, a season's; then the lowest skill
function R.Options(id)
    local uses = type(id) == "number" and Index().uses[id]
    local out = {}
    if not uses then return out end
    local cooks = {}
    for _, u in ipairs(uses) do
        cooks[u.kind] = cooks[u.kind] or With(u.kind)
        for _, c in ipairs(cooks[u.kind]) do
            local rec = u.rec
            if c.rank < rec.c[3] and not rec.raid and (not rec.class or rec.class == c.class) then
                local known = R.Knows(c.who, u.kind, rec)
                local source = R.Source(rec, c.side)
                if known or source then
                    out[#out + 1] = { kind = u.kind, rec = rec, who = c.who, mine = c.mine, name = c.name,
                                      rank = c.rank, known = known == true, source = source,
                                      later = not known and rec.at > c.rank + R.AHEAD,
                                      order = known and 0 or source.order }
                end
            end
        end
    end
    local function Key(o)
        return { o.mine and 0 or 1, o.later and 1 or 0, o.order, o.rec.at, o.rec.p }
    end
    table.sort(out, function(a, b)
        local x, y = Key(a), Key(b)
        for i = 1, #x do
            if x[i] ~= y[i] then return x[i] < y[i] end
        end
        return a.who < b.who
    end)
    return out
end

-- The reason in a line: "Cooking: makes Mystery Stew (needs 175, you're at 180)"
local function Why(o)
    local name = R.Name(o.rec)
    if o.known then
        if o.mine then return L["%s: your %s still gives a skill-up"]:format(o.name, name) end
        return L["%s's %s: their %s still gives a skill-up"]:format(Short(o.who), o.name, name)
    end
    if o.mine then return L["%s: makes %s (needs %d, you're at %d)"]:format(o.name, name, o.rec.at, o.rank) end
    return L["%s's %s: makes %s (needs %d, now at %d)"]:format(Short(o.who), o.name, name, o.rec.at, o.rank)
end

-- "Also goes into Mystery Stew (175), Dragonbreath Chili (200)": the same character's other recipes in reach
local function Also(options, best)
    local names = {}
    for _, o in ipairs(options) do
        if o ~= best and o.who == best.who and not o.later and #names < 2 then
            names[#names + 1] = ("%s (%d)"):format(R.Name(o.rec), o.rec.at)
        end
    end
    if #names == 0 then return nil end
    return L["Also goes into %s"]:format(table.concat(names, ", "))
end

-- Why a material is kept for a recipe: { why = one line, lines = { where to get the recipe, its others },
-- recipe = the option (R.Options) }, or nil when none in reach could still level one of your characters
function R.Keep(id)
    local options = R.Options(id)
    local best = options[1]
    for _, o in ipairs(options) do
        if not o.later then best = o; break end
    end
    if not best or best.later then return nil end
    local lines = {}
    if not best.known then lines[#lines + 1] = R.Where(best.source, best.name) end
    local also = Also(options, best)
    if also then lines[#lines + 1] = also end
    return { why = Why(best), lines = lines, recipe = best }
end

-- A recipe too far off to keep for: two lines to go under whatever else is advised, or nil
function R.Later(id)
    if R.Keep(id) then return nil end
    local o = R.Options(id)[1]
    if not o then return nil end
    local text
    if o.mine then
        text = L["Later, %s: makes %s at %d (you're at %d)"]:format(o.name, R.Name(o.rec), o.rec.at, o.rank)
    else
        text = L["Later, %s's %s: makes %s at %d"]:format(Short(o.who), o.name, R.Name(o.rec), o.rec.at)
    end
    return { text, R.Where(o.source, o.name) }
end

-- A recipe's item, or a profession's skill book, that one of your characters can still use: { why, lines,
-- book = true }, or nil
function R.Book(id)
    local data = ns.RecipeData
    if type(id) ~= "number" or not data then return nil end
    local taught = Index().books[id]
    if taught then
        local rec = taught.rec
        for _, c in ipairs(With(taught.kind)) do
            if c.rank < rec.c[3] and (not rec.class or rec.class == c.class)
                    and R.Knows(c.who, taught.kind, rec) ~= true then
                local why
                if c.mine then
                    why = L["teaches %s (%s %d, you're at %d)"]:format(R.Name(rec), c.name, rec.at, c.rank)
                else
                    why = L["teaches %s (%s %d, for %s, now at %d)"]:format(R.Name(rec), c.name, rec.at, Short(c.who),
                        c.rank)
                end
                return { why = why, lines = {}, book = true }
            end
        end
        return nil
    end
    local book = data.books and data.books[id]
    if not book then return nil end
    for _, c in ipairs(With(book.kind)) do
        if c.cap and c.cap < book.cap then
            local why
            if c.mine then
                why = L["raises your %s to %d (your cap is %d)"]:format(c.name, book.cap, c.cap)
            else
                why = L["raises %s's %s to %d (their cap is %d)"]:format(Short(c.who), c.name, book.cap, c.cap)
            end
            return { why = why, lines = {}, book = true }
        end
    end
    return nil
end

---------------------------------------------------------------------------
-- Where a material comes from (for The Mentor)
---------------------------------------------------------------------------
-- Your own gathering professions: mining, herbalism, skinning, fishing > its name in the game's words
function R.Gathering()
    local out = {}
    local I = ns.Inventory
    local me = I and I.Me and I.Me()
    local record = me and ns.db and ns.db.inventory and ns.db.inventory[me]
    local mining = record and record.prof and record.prof.mining
    if mining then out.mining = tostring(mining.name or "mining") end
    for kind, p in pairs(me and ns.db and ns.db.gatherSkills and ns.db.gatherSkills[me] or {}) do
        out[kind] = tostring(p.name or kind)
    end
    return out
end

-- How you get a material: "farm" (and your profession's name) when a gathering profession of yours brings it;
-- "vendor" when a vendor sells it without running out (and who, when you have seen it at one); else "auction"
function R.How(id)
    local data = ns.RecipeData or {}
    local kind = data.gather and data.gather[id]
    if kind then
        local mine = R.Gathering()[kind]
        if mine then return "farm", mine end
    end
    local seen = ns.db and ns.db.merchantSeen and ns.db.merchantSeen[id]
    if seen then return "vendor", L["last seen sold by %s in %s"]:format(seen[1], seen[2]) end
    if data.seasonItems and data.seasonItems[id] then return "vendor", L["sold only during the Feast of Winter Veil"] end
    if data.vendorItems and data.vendorItems[id] then return "vendor", L["trade supply vendors sell it"] end
    if ns.Market and ns.Market.MerchantPrice and ns.Market.MerchantPrice(id) then return "vendor" end
    return "auction"
end
