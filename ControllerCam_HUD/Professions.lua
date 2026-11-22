-- ControllerCam HUD: what your characters' professions can still learn from.
-- Each character's crafting professions and how far along they are, noted at login from the game's list of
-- skills; and, whenever a profession's window is open, its recipes as the game shows them: which still give a
-- skill point (orange and yellow ones, the game's own colours), what each needs and what each makes. With that
-- an item in your bags is kept when it still gives you, or another of your characters on this realm, a skill
-- point (mail it over); or when it crafts something the auction house pays more for than the item itself.
-- Nothing is guessed: a profession whose window has not been opened yet keeps nothing.
-- Only read: nothing in a profession's window is opened, expanded or changed.

local ADDON, ns = ...
local L = ns.L

local P = { reads = 0 }
ns.Professions = P

ns.RegisterSetting({
    key = "skillKeep", kind = "boolean", default = true, command = "skillkeep", section = "Bags, bank and vendor",
    label = "Keep what your professions still need",
    tip = "an item that one of your characters' recipes still gives a skill point for (orange and yellow recipes, as the game shows them in the profession's window), or that crafts something worth more at the auction house than the item itself, is kept, not sold, and its tooltip says why. Recipes are read when a profession's window is open",
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
P.MIN = 2000              -- and at least this much (20 silver) at the auction house, after its cut
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

---------------------------------------------------------------------------
-- Your professions and their ranks, from the game's list of skills
---------------------------------------------------------------------------
function P:ReadSkills()
    local rec = Record()
    if not rec then return false end
    local found = {}
    if GetNumSkillLines and GetSkillLineInfo then
        local ok, n = pcall(GetNumSkillLines)
        for i = 1, (ok and tonumber(n)) or 0 do
            local ok2, name, header, _, rank, _, _, cap = pcall(GetSkillLineInfo, i)
            local kind = ok2 and not Plain(header) and P.Kind(name)
            if kind and type(Plain(rank)) == "number" then found[kind] = { name = name, rank = rank, cap = Plain(cap) } end
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
            end
        end
    else
        return false
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

-- What this item crafts that is worth more than the item itself: own = what the item brings as it is (the
-- auction house after its cut, or a vendor). { craft = true, product, price (each, at the auction house), each
-- (what one of this item is worth made into it), who, mine, kind, name } for the best one, or nil. Only for
-- recipes a character of yours knows, and only with the auction house's price for what they make.
function P.Crafts(id, own)
    local M = ns.Market
    if type(id) ~= "number" or not (M and M.Auction) then return nil end
    local best
    for c in Characters() do
        for kind, p in pairs(c.rec.prof) do
            for _, k in ipairs((type(p.crafts) == "table" and p.crafts[id]) or {}) do
                local price = M.Auction(k.p)
                if price then
                    local net = price * 0.95 * (k.m or 1)
                    local each = net / (k.n or 1)
                    if net >= P.MIN and each >= (own or 0) * P.BETTER and (not best or each > best.each) then
                        best = { craft = true, product = k.p, price = price, each = each, who = c.who, mine = c.mine,
                                 kind = kind, name = p.name, sure = true }
                    end
                end
            end
        end
    end
    return best
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
