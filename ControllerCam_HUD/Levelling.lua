-- ControllerCam HUD: a levelling plan beside a profession's window.
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
-- Each point is taken from the recipe that costs least per point (auction prices where they are known).
-- What it takes is broken down through what your characters can make: a Bronze Bar the plan needs, less the
-- ones you hold, becomes Copper Bars and Tin Bars, and those Copper Ore and Tin Ore, less what you hold of each.
-- What is still missing can be put on the farm list (Farm.lua) with one button.
-- Only read: nothing in the profession's window is opened, expanded, changed or written to.

local ADDON, ns = ...
local L = ns.L
local C = ns.colors

local LV = { reads = 0, index = 1, top = 1, rows = {}, entries = {} }
ns.Levelling = LV

LV.BAND = 15              -- points between a recipe turning yellow, green and grey, until it is seen
LV.DEPTH = 4              -- how far down a chain of crafts the breakdown goes (Copper Ore > Copper Bar > Bronze Bar)
LV.UNKNOWN = 100          -- what a reagent with no known price counts as (1 silver), to compare recipes
LV.ROWS = 12
LV.KEYS = { "PADDUP", "PADDDOWN", "PAD1", "PAD3", "PAD2", "ESCAPE", "PADLSTICK" }
LV.KEY = "PADLSTICK"      -- while the window is open: L3 takes the plan's buttons, and gives them back
LV.WINDOWS = { "TradeSkillFrame", "CraftFrame", "ProfessionsFrame" }

ns.RegisterSetting({
    key = "skillPlan", kind = "boolean", default = true, command = "levelhelp", section = "Bags, bank and vendor",
    label = "Levelling plan beside the profession window",
    tip = "while a profession's window is open, a panel beside it says which recipes to make and how many to reach the cap, and what that takes, down to the ore and herbs; an estimate from the recipes' colours",
})

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
                    for _, k in ipairs({ "yl", "yh", "gl", "gh", "xl", "xh" }) do c[k] = tonumber(b[k]) end
                    keep[name] = c
                end
            end
            out[kind] = keep
        end
    end
    return out
end
ns.RegisterSaved("skillSteps", CleanBounds)

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
    local read = { name = name, rank = Num(rank), cap = Num(cap), via = "modern", list = {} }
    for _, id in ipairs(ids) do
        local okI, info = pcall(T.GetRecipeInfo, id)
        local c = okI and type(info) == "table" and info.learned and MODERN[Plain(info.relativeDifficulty) or -1]
        local recipe = c and Plain(info.name)
        if c and type(recipe) == "string" then
            local r = { n = recipe, c = c, u = math.max(1, Num(info.numSkillUps) or 1), r = {} }
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
    local r = read.rank
    for _, rec in ipairs(read.list) do
        local b = steps[rec.n] or {}
        steps[rec.n] = b
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
    return plan
end

---------------------------------------------------------------------------
-- The panel
---------------------------------------------------------------------------
local frame
local WIDTH, ROW = 320, 20

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
    frame.title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -8)
    frame.sub = ns.FontString(frame, 8, "LEFT")
    frame.sub:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -2)
    frame.sub:SetPoint("TOPRIGHT", frame.title, "BOTTOMRIGHT", 0, -2)
    frame.sub:SetTextColor(unpack(C.muted))
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
    if frame.detail.SetWordWrap then frame.detail:SetWordWrap(true) end
    frame.detail:SetTextColor(0.78, 0.88, 1)
    frame.hint = ns.FontString(frame, 8, "LEFT")
    frame.hint:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, 6)
    frame.hint:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 6)
    frame.hint:SetTextColor(unpack(C.muted))
    -- L3 while the window is open takes the plan's buttons (ns.PadKeys); B, or L3 again, gives them back
    LV.key = ns.PadKeys("PlanKey", { LV.KEY }, function() LV:Focus(true) end)
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
    for _, step in ipairs(plan.steps) do out[#out + 1] = { step = step } end
    local ids = SortedIds(plan.raw)
    table.sort(ids, function(a, b)
        if plan.raw[a] ~= plan.raw[b] then return plan.raw[a] > plan.raw[b] end
        return a < b
    end)
    if #ids > 0 then out[#out + 1] = { head = L["To gather or buy"] } end
    for _, id in ipairs(ids) do out[#out + 1] = { id = id, more = plan.raw[id], total = plan.total[id] } end
    return out
end

local function Detail(plan, e)
    if not e then return "" end
    if e.step then
        local parts = {}
        for _, x in ipairs(e.step.rec.r) do
            local need = e.step.crafts * x.n
            parts[#parts + 1] = ("%s %d/%d"):format(ItemName(x.id), math.min(LV.Have(x.id), need), need)
        end
        return L["%d crafts: %s"]:format(e.step.crafts, table.concat(parts, ", "))
    end
    if e.id then
        local have = LV.Have(e.id)
        local text = L["%s: you have %d, the plan uses %d"]:format(ItemName(e.id), have, e.total or 0)
        local chain = LV.Chain(plan, e.id)
        if chain ~= "" then text = text .. "\n" .. L["for %s"]:format(chain) end
        return text
    end
    return ""
end

function LV:Refresh()
    if not (frame and frame:IsShown()) then return end
    local plan = self.plan
    self.entries = Entries(plan)
    local n = #self.entries
    while self.entries[self.index] and self.entries[self.index].head do self.index = self.index + 1 end
    self.index = ns.Clamp(self.index, 1, math.max(1, n))
    if self.index < self.top then self.top = self.index end
    if self.index > self.top + LV.ROWS - 1 then self.top = self.index - LV.ROWS + 1 end
    self.top = ns.Clamp(self.top, 1, math.max(1, n - LV.ROWS + 1))
    if plan then
        frame.title:SetText(L["Levelling plan: %s %d > %d"]:format(plan.name, plan.rank, plan.target))
        local sub = L["an estimate from the recipes' colours, made again as you level"]
        if plan.capped then sub = L["At the cap: a trainer has the next rank."]
        elseif plan.short then sub = L["%d points no recipe of yours gives: learn new ones at a trainer"]:format(plan.short) end
        frame.sub:SetText(sub)
    else
        frame.title:SetText(L["Levelling plan"])
        frame.sub:SetText(L["Open a profession's window to make a plan."])
    end
    local shown = 0
    for i, r in ipairs(self.rows) do
        local at = self.top + i - 1
        local e = self.entries[at]
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -40 - (i - 1) * ROW)
        if e then
            shown = i
            r.at = (not e.head) and at or nil
            if e.head then
                r.icon:Hide()
                r.text:SetText("|cffffd24a" .. e.head .. "|r")
                r.right:SetText("")
            elseif e.step then
                r.icon:Show()
                r.icon:SetTexture(e.step.rec.p and Icon(e.step.rec.p) or 134400)
                r.text:SetText(LV.RecipeText(e.step.rec.n, e.step.colour) .. "  x" .. e.step.crafts)
                r.right:SetText(("%d-%d"):format(e.step.from, e.step.to))
            else
                r.icon:Show()
                r.icon:SetTexture(Icon(e.id))
                r.text:SetText(ItemName(e.id))
                r.right:SetText(("+%d"):format(e.more))
            end
            if self.focus and at == self.index then r.hl:Show() else r.hl:Hide() end
            r:Show()
        else
            r.at = nil
            r:Hide()
        end
    end
    local y = -40 - shown * ROW - 6
    frame.detail:ClearAllPoints()
    frame.detail:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, y)
    frame.detail:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, y)
    frame.detail:SetText(self.focus and Detail(plan, self.entries[self.index]) or "")
    if self.focus then
        frame.hint:SetText(("%s %s   %s %s   %s %s"):format(KeyName("PAD1"), L["Farm this"], KeyName("PAD3"),
            L["Farm all"], KeyName("PAD2"), L["Back"]))
    else
        frame.hint:SetText(("%s %s"):format(KeyName(LV.KEY), L["Use the plan"]))
    end
    frame:SetHeight(40 + shown * ROW + (self.focus and 40 or 6) + 18)
end

-- Beside the game's window (or in the middle of the screen, away from one)
function LV:Place()
    if not frame then return end
    local w = LV.Window()
    frame:ClearAllPoints()
    if w then frame:SetPoint("TOPLEFT", w, "TOPRIGHT", 6, 0)
    else frame:SetPoint("CENTER", UIParent, "CENTER", 0, 40) end
end

function LV:Show()
    if not frame then Build() end
    self:Place()
    frame:Show()
    if not self.focus then self.key:Set(true) end
    self:Refresh()
end

function LV:Hide()
    if frame then frame:Hide() end
    self.focus = false
    if self.keys then self.keys:Set(false) end
    if self.key then self.key:Set(false) end
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
        if e and e.id then
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
    elseif key == "PAD1" then self:Farm(false)
    elseif key == "PAD3" then self:Farm(true)
    elseif key == "PAD2" or key == "ESCAPE" or key == "PADLSTICK" then self:Focus(false)
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
-- (a window closed without saying so: looked at now and then while the panel is up)
local since = 0
events:SetScript("OnUpdate", ns.Protect(function(_, dt)
    if not (frame and frame:IsShown()) or LV.away then return end
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
    if frame and frame:IsShown() then self.away = false; self:Hide(); return false end
    if not self.plan then ns.Say(L["Open a profession's window to make a plan."]); return false end
    self.away = LV.Window() == nil
    self:Show()
    self:Focus(true)
    return true
end

function ControllerCamHUD_SkillPlan() ns.Protect(function() LV:Toggle() end)() end
BINDING_NAME_CCHUD_SKILLPLAN = L["Levelling plan: show / hide"]
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
