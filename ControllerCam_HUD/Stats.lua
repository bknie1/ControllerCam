-- ControllerCam HUD: what an item's stats are worth to you.
-- The stat lines of an item's tooltip, with their value for your character in brackets, on the panel under the
-- tooltip (Tooltip.lua; the game's tooltip is only read, never written to: docs/DESIGN.md rule 11):
--   +10 Agility   (+10 AP, +20 RAP, +0.19% crit, +0.5% dodge)
--   +10 Intellect (+150 mana, +0.17% spell crit)
-- By your class: Strength and Agility into attack power and ranged attack power, Agility into crit and dodge,
-- Stamina into health, Intellect into mana and spell crit (for classes with mana). Crit and dodge per point are
-- read from the game for your level where it says them, otherwise the usual values at level 60, scaled to yours.
-- The stat lines are recognised from the game's own wording, so this works in every language.

local ADDON, ns = ...
local L = ns.L

local ST = { active = false }
ns.Stats = ST

ns.RegisterSetting({
    key = "statValues", kind = "boolean", default = true, command = "statvalues", section = "Bags, bank and vendor",
    label = "What stats are worth to you",
    tip = "under an item's tooltip, its stat lines with their value for your character: attack power, ranged attack power, crit, dodge, health, mana",
})

-- Per class: attack power per Strength and per Agility, ranged attack power per Agility, points of Agility per
-- 1% crit and per 1% dodge at level 60, points of Intellect per 1% spell crit at 60 (nil: no mana)
ST.CLASS = {
    WARRIOR = { str = 2, agi = 0, ranged = 1, crit = 20, dodge = 20 },
    PALADIN = { str = 2, agi = 0, ranged = 0, crit = 20, dodge = 20, spell = 29.5 },
    HUNTER = { str = 1, agi = 1, ranged = 2, crit = 53, dodge = 26.5, spell = 60 },
    ROGUE = { str = 1, agi = 1, ranged = 1, crit = 29, dodge = 14.5 },
    PRIEST = { str = 1, agi = 0, ranged = 0, crit = 20, dodge = 20, spell = 59.5 },
    SHAMAN = { str = 2, agi = 0, ranged = 0, crit = 20, dodge = 20, spell = 59.5 },
    MAGE = { str = 1, agi = 0, ranged = 0, crit = 20, dodge = 20, spell = 59.5 },
    WARLOCK = { str = 1, agi = 0, ranged = 0, crit = 20, dodge = 20, spell = 60.6 },
    DRUID = { str = 2, agi = 0, ranged = 0, crit = 20, dodge = 20, spell = 60 },
}
local HP, MANA = 10, 15

-- The game's wording of a stat line ("%c%s Agility") as a pattern catching the sign and the number
local function Pattern(fmt)
    if type(fmt) ~= "string" then return nil end
    local p = fmt:gsub("%%c%%s", "\1"):gsub("%%c%%d", "\1")
    p = p:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
    p = p:gsub("\1", "([%%+%%-])(%%d+)")
    return "^" .. p .. "$"
end

local patterns
local function Patterns()
    if patterns then return patterns end
    patterns = {}
    local function add(stat, global, english)
        for _, fmt in pairs({ _G[global] or false, english }) do          -- the game's wording, and English
            local p = fmt and Pattern(fmt)
            if p then patterns[#patterns + 1] = { stat = stat, pattern = p } end
        end
    end
    add("str", "ITEM_MOD_STRENGTH", "%c%s Strength")
    add("agi", "ITEM_MOD_AGILITY", "%c%s Agility")
    add("sta", "ITEM_MOD_STAMINA", "%c%s Stamina")
    add("int", "ITEM_MOD_INTELLECT", "%c%s Intellect")
    return patterns
end
ST.Patterns = Patterns

local function Level()
    local level = UnitLevel("player")
    if ns.IsSecret(level) or type(level) ~= "number" or level < 1 then return 60 end
    return math.max(level, 10)
end

-- Percent per point: the game's own figure for you, or the level-60 value scaled to your level
local function PerPoint(fromGame, statIndex, at60)
    if fromGame then
        local okC, total = pcall(fromGame, "player")
        local okS, _, stat = pcall(UnitStat, "player", statIndex)
        if okC and okS and type(total) == "number" and type(stat) == "number" and not ns.IsSecret(total)
            and not ns.IsSecret(stat) and total > 0 and stat > 0 then
            return total / stat
        end
    end
    if not at60 then return nil end
    return 60 / (at60 * Level())                                 -- fewer points per % at low level
end

local function Pct(v) return ("%.2f%%"):format(v):gsub("%.?0+%%$", "%%") end

-- A colour per kind of value, so they read at a glance; the brackets grey
ST.COLOR = { ap = "ff9a4d", rap = "8fdc5a", crit = "ffd24a", dodge = "6fd6c0", health = "5fe06a", mana = "6fa8ff",
             spell = "c99bff" }
local GREY = "|cff9aa3b5"

-- What n points of a stat are worth to you: the text in brackets, or nil
function ST.Worth(stat, n)
    local _, class = UnitClass("player")
    local c = ST.CLASS[class or ""]
    if not c or n == 0 then return nil end
    local sign = n > 0 and "+" or "-"
    n = math.abs(n)
    local parts = {}
    local function add(v, label, kind, pct)
        if v and v > 0 then
            local value = pct and (sign .. Pct(v)) or ("%s%d"):format(sign, math.floor(v + 0.5))
            parts[#parts + 1] = "|cff" .. ST.COLOR[kind] .. value .. " " .. label .. "|r"
        end
    end
    if stat == "str" then
        add(n * c.str, L["AP"], "ap")
    elseif stat == "agi" then
        add(n * c.agi, L["AP"], "ap")
        add(n * c.ranged, L["RAP"], "rap")
        local crit = PerPoint(GetCritChanceFromAgility, 2, c.crit)
        add(crit and n * crit, L["crit"], "crit", true)
        add(n * 60 / (c.dodge * Level()), L["dodge"], "dodge", true)
    elseif stat == "sta" then
        add(n * HP, L["health"], "health")
    elseif stat == "int" then
        if c.spell then
            add(n * MANA, L["mana"], "mana")
            local crit = PerPoint(GetSpellCritChanceFromIntellect, 4, c.spell)
            add(crit and n * crit, L["spell crit"], "spell", true)
        end
    end
    if #parts == 0 then return nil end
    return GREY .. "(|r" .. table.concat(parts, GREY .. ", |r") .. GREY .. ")|r"
end

-- A tooltip line's text with its worth added, or nil when it is not a stat line (or is already done)
local MARK = GREY .. "(|r"
function ST.Annotate(text)
    if type(text) ~= "string" or ns.IsSecret(text) or text:find(MARK, 1, true) then return nil end
    for _, p in ipairs(Patterns()) do
        local sign, num = text:match(p.pattern)
        if num then
            local worth = ST.Worth(p.stat, (sign == "-" and -1 or 1) * tonumber(num))
            if worth then return text .. " " .. worth end
            return nil
        end
    end
end

-- The stat lines of a tooltip with their worth, { { text }, ... }, for the panel under it (Inventory.lua puts
-- them there). The tooltip's lines are read, never changed: written to, they carried the HUD's name into the
-- game's own tooltip code, which the game then refused to let run.
function ST.Lines(tooltip)
    local out = {}
    if not (ST.active and ns.db.statValues) or type(tooltip) ~= "table" or not (tooltip.GetName and tooltip.NumLines) then
        return out
    end
    local okN, name = pcall(tooltip.GetName, tooltip)
    local okL, n = pcall(tooltip.NumLines, tooltip)
    name, n = okN and ns.Plain(name), okL and ns.Plain(n)
    if type(name) ~= "string" or type(n) ~= "number" then return out end
    for i = 2, n do
        local fs = _G[name .. "TextLeft" .. i]
        if fs and fs.GetText then
            local ok, text = pcall(fs.GetText, fs)
            local done = ok and ST.Annotate(text)
            if done then out[#out + 1] = { done } end
        end
    end
    return out
end

function ST:Apply(run)
    self.active = run and true or false
end

ns.RegisterModule("stats", ST)
