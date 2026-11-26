-- ControllerCam HUD: what an item's stats are worth to you.
-- The stat lines of an item's tooltip, with their value for your character in brackets beside each line. The
-- game's tooltip is only read, never written to (docs/DESIGN.md rule 11): the brackets are text of our own, laid
-- just after the game's line. As many values as fit inside the tooltip go there, the ones that matter most first;
-- what does not fit hangs on the panel under it (Tooltip.lua).
--   +10 Agility   (+20 RAP, +10 AP, +0.19% crit, +0.5% dodge)
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
    tip = "beside each stat line of an item's tooltip, what it is worth to your character: attack power, ranged attack power, crit, dodge, health, mana. What does not fit inside the tooltip is on the panel under it",
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

-- What n points of a stat are worth to you: the values, the ones that matter most first (maybe none), or nil
function ST.Parts(stat, n)
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
        if c.ranged > c.agi then                                 -- (a hunter's bow before their blade)
            add(n * c.ranged, L["RAP"], "rap")
            add(n * c.agi, L["AP"], "ap")
        else
            add(n * c.agi, L["AP"], "ap")
            add(n * c.ranged, L["RAP"], "rap")
        end
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
    return parts
end

-- Values in brackets, from the first to the last asked for
local function Bracket(parts, from, to)
    local some = {}
    for i = from or 1, to or #parts do some[#some + 1] = parts[i] end
    return GREY .. "(|r" .. table.concat(some, GREY .. ", |r") .. GREY .. ")|r"
end

-- What n points of a stat are worth to you: the text in brackets, or nil
function ST.Worth(stat, n)
    local parts = ST.Parts(stat, n)
    return parts and Bracket(parts) or nil
end

local MARK = GREY .. "(|r"
-- A tooltip line's values, or nil when it is not a stat line (or has them already)
local function LineParts(text)
    if type(text) ~= "string" or ns.IsSecret(text) or text:find(MARK, 1, true) then return nil end
    for _, p in ipairs(Patterns()) do
        local sign, num = text:match(p.pattern)
        if num then return ST.Parts(p.stat, (sign == "-" and -1 or 1) * tonumber(num)) end
    end
end

-- A tooltip line's text with its worth added, or nil when it is not a stat line (or is already done)
function ST.Annotate(text)
    local parts = LineParts(text)
    if parts then return text .. " " .. Bracket(parts) end
end

---------------------------------------------------------------------------
-- Beside the line: text of our own, just after the game's
---------------------------------------------------------------------------
ST.GAP = 5                    -- between the game's words and ours
ST.BETWEEN = 40               -- the least the game leaves between a line's left and right words
ST.over = setmetatable({}, { __mode = "k" })

-- A number the game gives that can be reckoned with, or nil (a call that fails, a secret value)
local function Measure(object, method)
    if type(object) ~= "table" or not object[method] then return nil end
    local ok, v = pcall(object[method], object)
    if ok and not ns.IsSecret(v) and type(v) == "number" then return v end
end

local function Words(fs)
    if type(fs) ~= "table" or not fs.GetText then return nil end
    local ok, text = pcall(fs.GetText, fs)
    if ok and not ns.IsSecret(text) and type(text) == "string" then return text end
end

local function Put(o)
    for _, m in ipairs(o.marks) do m.line, m.text = nil, nil; m.fs:Hide() end
end

-- Ours for one tooltip: a frame that goes where it goes, and hides with it
local function Over(tooltip)
    local o = ST.over[tooltip]
    if o then return o end
    local ok, f = pcall(CreateFrame, "Frame", nil, tooltip)
    if not ok or not f then return nil end
    f:SetFrameStrata("TOOLTIP")
    local level = Measure(tooltip, "GetFrameLevel")
    if level then f:SetFrameLevel(level + 2) end
    f:SetSize(1, 1)
    f:SetPoint("TOPLEFT", tooltip, "TOPLEFT", 0, 0)
    o = { frame = f, marks = {} }
    ST.over[tooltip] = o
    -- the tooltip filled with something else (a creature, a spell, another item): ours go with the old words
    f:SetScript("OnUpdate", ns.Protect(function()
        if not (ST.active and ns.db.statValues) then Put(o); return end         -- switched off
        for _, m in ipairs(o.marks) do
            if m.line then
                local shown = m.line.IsShown == nil or ns.Yes(m.line:IsShown())
                if not shown or Words(m.line) ~= m.text then m.line, m.text = nil, nil; m.fs:Hide() end
            end
        end
    end))
    f:SetScript("OnHide", ns.Protect(function() Put(o) end))
    return o
end

-- The words on a line's right, when it has some
local function RightOf(name, i)
    local right = _G[name .. "TextRight" .. i]
    if right and right.IsShown and ns.Yes(right:IsShown()) and (Words(right) or "") ~= "" then return right end
end

-- How wide the tooltip's own words are, which is how wide the game makes it. Said by the lines themselves, so it
-- is known as the tooltip fills; its edges are only right once it has been laid out. Nil where it does not say.
local function Widest(name, n)
    local widest
    for i = 1, n do
        local line = _G[name .. "TextLeft" .. i]
        local w = line and Words(line) and Measure(line, "GetStringWidth")
        local right = w and RightOf(name, i)
        if right then w = w + (Measure(right, "GetStringWidth") or 0) + ST.BETWEEN end
        if w and (not widest or w > widest) then widest = w end
    end
    return widest
end

-- How many of a line's values fit after it, put there: 0 where there is no room, or the game does not say
local function Beside(o, name, i, widest, line, text, parts)
    if not o or not widest or RightOf(name, i) then return 0 end
    local width = Measure(line, "GetStringWidth")
    if not width then return 0 end
    local room = widest - width - ST.GAP
    local m
    for _, each in ipairs(o.marks) do
        if not each.line then m = each; break end
    end
    if not m then
        m = { fs = ns.FontString(o.frame, 10, "LEFT") }
        if m.fs.SetWordWrap then m.fs:SetWordWrap(false) end
        o.marks[#o.marks + 1] = m
    end
    for n = #parts, 1, -1 do
        m.fs:SetText(Bracket(parts, 1, n))
        local w = Measure(m.fs, "GetStringWidth")
        if w and w <= room then
            m.fs:ClearAllPoints()
            m.fs:SetPoint("LEFT", line, "LEFT", width + ST.GAP, 0)
            m.fs:Show()
            m.line, m.text = line, text
            return n
        end
    end
    m.fs:Hide()
    return 0
end

-- What stands beside a tooltip's lines right now: { { line, text } } (for the tests)
function ST.Marks(tooltip)
    local out, o = {}, ST.over[tooltip]
    for _, m in ipairs(o and o.marks or {}) do
        if m.line then out[#out + 1] = { line = m.line, text = m.fs:GetText() } end
    end
    return out
end

-- A tooltip's stat lines with their worth. Each goes beside its line, as much of it as fits inside the tooltip;
-- what is left is returned, { { text }, ... }, for the panel under it (Inventory.lua puts it there). The
-- tooltip's lines are read, never changed: written to, they carried the HUD's name into the game's own tooltip
-- code, which the game then refused to let run.
function ST.Lines(tooltip)
    local out = {}
    if type(tooltip) == "table" and ST.over[tooltip] then Put(ST.over[tooltip]) end
    if not (ST.active and ns.db.statValues) or type(tooltip) ~= "table" or not (tooltip.GetName and tooltip.NumLines) then
        return out
    end
    local okN, name = pcall(tooltip.GetName, tooltip)
    local okL, n = pcall(tooltip.NumLines, tooltip)
    name, n = okN and ns.Plain(name), okL and ns.Plain(n)
    if type(name) ~= "string" or type(n) ~= "number" then return out end
    local o
    local okW, widest = pcall(Widest, name, n)
    widest = okW and widest or nil
    for i = 2, n do
        local fs = _G[name .. "TextLeft" .. i]
        local text = fs and Words(fs)
        local parts = text and LineParts(text)
        if parts then
            o = o or Over(tooltip)
            local ok, fit = pcall(Beside, o, name, i, widest, fs, text, parts)
            fit = ok and fit or 0
            if fit == 0 then
                out[#out + 1] = { text .. " " .. Bracket(parts) }
            elseif fit < #parts then
                out[#out + 1] = { text .. " " .. GREY .. "...|r " .. Bracket(parts, fit + 1) }
            end
        end
    end
    if o then o.frame:Show() end
    return out
end

function ST:Apply(run)
    self.active = run and true or false
    if not self.active then
        for _, o in pairs(self.over) do Put(o) end
    end
end

ns.RegisterModule("stats", ST)
