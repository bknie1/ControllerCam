-- ControllerCam HUD: the look. Colors, fonts and the bar every unit frame is built from.

local ADDON, ns = ...

local MEDIA = "Interface\\AddOns\\ControllerCam_HUD\\Media\\"
ns.media = {
    bar = MEDIA .. "bar", mask = MEDIA .. "mask", soft = MEDIA .. "soft",
    spark = MEDIA .. "spark", mark = MEDIA .. "mark", bobber = MEDIA .. "bobber",
    quest = MEDIA .. "quest", skull = MEDIA .. "skull", wing = MEDIA .. "wing", threat = MEDIA .. "threat",
    ring = MEDIA .. "ring", disc = MEDIA .. "disc", mapring = MEDIA .. "mapring", halo = MEDIA .. "halo",
    vines = MEDIA .. "vines",
    -- cast bar art (CastArt.lua)
    pick = MEDIA .. "pick", hammer = MEDIA .. "hammer", flame = MEDIA .. "flame", crystal = MEDIA .. "crystal",
    ghost = MEDIA .. "ghost", leaf = MEDIA .. "leaf", runes = MEDIA .. "runes", roots = MEDIA .. "roots",
    bolt = MEDIA .. "bolt", flower = MEDIA .. "flower", vine = MEDIA .. "vine", fish = MEDIA .. "fish",
}

ns.colors = {
    health   = { 0.49, 0.84, 0.56 },
    caution  = { 0.98, 0.77, 0.31 },
    danger   = { 0.92, 0.33, 0.38 },
    hostile  = { 0.92, 0.33, 0.38 },
    neutral  = { 0.98, 0.77, 0.31 },
    friendly = { 0.49, 0.84, 0.56 },
    tapped   = { 0.55, 0.57, 0.62 },
    cast     = { 0.98, 0.77, 0.31 },
    calm     = { 0.55, 0.76, 1.00 },        -- an enemy that is not on you
    angry    = { 1.00, 0.22, 0.20 },        -- an enemy that is on you
    combat   = { 0.98, 0.55, 0.25 },
    shielded = { 0.70, 0.72, 0.78 },
    text     = { 0.96, 0.97, 1.00 },
    muted    = { 0.72, 0.76, 0.86 },
    back     = { 0.04, 0.06, 0.11, 0.72 },
    power = {
        MANA = { 0.33, 0.59, 0.91 }, RAGE = { 0.88, 0.32, 0.32 }, ENERGY = { 0.98, 0.84, 0.36 },
        FOCUS = { 0.95, 0.62, 0.33 }, RUNIC_POWER = { 0.33, 0.80, 0.95 },
    },
}

ns.fonts = {}

---------------------------------------------------------------------------
-- One font for everything, if you choose one: the HUD's own text, and the game's shared fonts that its windows,
-- tooltips, chat and buttons are drawn with. Each keeps its size and outline; only the typeface changes, and
-- the game's own come back when you choose "The game's" or the HUD stops. Offered where the game's language is
-- written in Latin letters: these fonts have no Cyrillic, Korean or Chinese characters.
---------------------------------------------------------------------------
ns.FONT_CHOICES = { { "game" }, { "friz", "Friz Quadrata", "Fonts\\FRIZQT__.TTF" },
                    { "arial", "Arial Narrow", "Fonts\\ARIALN.TTF" }, { "skurri", "Skurri", "Fonts\\skurri.ttf" },
                    { "morpheus", "Morpheus", "Fonts\\MORPHEUS.TTF" } }
local LATIN = { enUS = true, enGB = true, deDE = true, esES = true, esMX = true, frFR = true, itIT = true,
                ptBR = true, ptPT = true }
function ns.FontsOffered()
    local loc = GetLocale and GetLocale() or "enUS"
    return LATIN[loc] or false
end
ns.RegisterSaved("font", function(old)
    for _, c in ipairs(ns.FONT_CHOICES) do if c[1] == old then return old end end
    return "game"
end)

-- The typeface chosen (a file), or nil for the game's own
function ns.ChosenFont()
    local key = ns.db and ns.db.font
    if not (ns.fontsRunning and key and key ~= "game" and ns.FontsOffered()) then return nil end
    for _, c in ipairs(ns.FONT_CHOICES) do if c[1] == key then return c[3] end end
end

-- The game's shared fonts (every Font object it keeps under a name): the chosen typeface, or their own back
local swapped = {}
ns.fontsSwapped = swapped
function ns.ApplyGameFont()
    local file = ns.ChosenFont()
    if not file then
        for font, own in pairs(swapped) do
            local ok, _, size, flags = pcall(font.GetFont, font)
            if ok and type(size) == "number" then pcall(font.SetFont, font, own, size, flags) end
            swapped[font] = nil
        end
        return 0
    end
    local n = 0
    for name, v in pairs(_G) do
        if type(name) == "string" and type(v) == "table" and name:find("Font", 1, true) then
            local ok, kind = pcall(function() return v.GetObjectType and v:GetObjectType() end)
            if ok and kind == "Font" then
                local okF, cur, size, flags = pcall(v.GetFont, v)
                if okF and type(cur) == "string" and type(size) == "number" and size > 0 then
                    if swapped[v] == nil then swapped[v] = cur end
                    if cur ~= file then pcall(v.SetFont, v, file, size, flags) end
                    n = n + 1
                end
            end
        end
    end
    return n
end

ns.RegisterModule("fonts", { Apply = function(_, run)
    ns.fontsRunning = run and true or false
    ns.ApplyGameFont()
    ns.ApplyFonts()
end })

local function FontFile() return ns.ChosenFont() or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF" end
ns.FontFile = FontFile

function ns.FontName(key)
    for _, c in ipairs(ns.FONT_CHOICES) do if c[1] == key then return c[2] or ns.L["The game's"] end end
    return ns.L["The game's"]
end

ns.RegisterCommand("font", function(arg)
    local L = ns.L
    if not ns.FontsOffered() then ns.Say(L["Fonts can be chosen only where the game's language is written in Latin letters."]); return end
    local key = (arg or ""):lower()
    local found
    for _, c in ipairs(ns.FONT_CHOICES) do if c[1] == key then found = c[1] end end
    if not found then
        ns.Say(L["Font: %s"]:format(ns.FontName(ns.db.font)))
        ns.Say("/cchud font game | friz | arial | skurri | morpheus")
        return
    end
    ns.db.font = found
    ns.Apply()
    if ns.RefreshOptions then ns.RefreshOptions() end
    ns.Say(L["Font: %s"]:format(ns.FontName(found)))
end, "/cchud font game | friz | arial | skurri | morpheus",
    "one font for the HUD and the game's own text (windows, tooltips, chat, buttons); each keeps its size")
local function TextScale() return ns.db and ns.db.textScale or 1 end

-- Re-applies the text size setting to every text of the HUD.
function ns.ApplyFonts()
    for _, fs in ipairs(ns.fonts) do
        fs.fontK, fs.fontFlags = 1, "OUTLINE"
        fs:SetFont(FontFile(), fs.baseSize * TextScale(), "OUTLINE")
    end
end

-- A font string at a share of its usual size, with an outline ("OUTLINE" or "THICKOUTLINE")
function ns.SetFontScale(fs, k, flags)
    k = math.floor(k * 100 + 0.5) / 100
    if fs.fontK == k and fs.fontFlags == flags then return end
    fs.fontK, fs.fontFlags = k, flags
    fs:SetFont(FontFile(), fs.baseSize * TextScale() * k, flags or "OUTLINE")
end

function ns.FontString(parent, size, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs.baseSize = size
    ns.fonts[#ns.fonts + 1] = fs
    fs:SetFont(FontFile(), size * TextScale(), "OUTLINE")
    fs:SetShadowColor(0, 0, 0, 0.9)
    fs:SetShadowOffset(1, -1)
    fs:SetJustifyH(justify or "LEFT")
    fs:SetTextColor(unpack(ns.colors.text))
    return fs
end

---------------------------------------------------------------------------
-- Bar: a slanted, tinted fill over a dark track, with a pale "trail" that lingers for a moment where
-- health was just lost. Values the game marks as secret are handed straight to the game's own status bar
-- (no arithmetic is possible on them), so those bars simply do not animate.
---------------------------------------------------------------------------
local FILL_SPEED = 14        -- how fast the fill catches up (per second, eased)
local TRAIL_HOLD = 0.35      -- seconds the trail waits after a hit
local TRAIL_SPEED = 0.7      -- share of the bar the trail drains per second

local function BarOnUpdate(self, dt)
    local v, max = self.goal, self.max
    local settled = true
    if v and self.disp then
        local d = v - self.disp
        if math.abs(d) <= max * 0.002 then
            self.disp = v
        else
            self.disp = self.disp + d * math.min(1, dt * FILL_SPEED)
        end
        if self.trailValue <= self.disp then
            self.trailValue = self.disp
        else
            self.hold = self.hold - dt
            if self.hold <= 0 then
                self.trailValue = math.max(self.disp, self.trailValue - max * TRAIL_SPEED * dt)
            end
        end
        self.fill:SetValue(self.disp)
        self.trail:SetValue(self.trailValue)
        settled = self.disp == v and self.trailValue == self.disp
    end
    if settled then
        self:SetScript("OnUpdate", nil)
        self.animating = false
    end
end

local BarMethods = {}

function BarMethods:SetValues(cur, max, instant)
    self.rawMax = max
    if ns.IsSecret(cur) or ns.IsSecret(max) then
        -- no numbers to animate, but a flash that is running still fades out (BarOnUpdate skips the numbers)
        self.secret, self.goal, self.max, self.disp = true, nil, nil, nil
        self.fill:SetMinMaxValues(0, max)
        self.fill:SetValue(cur)
        self.trail:SetMinMaxValues(0, max)
        self.trail:SetValue(cur)
        return
    end
    cur, max = tonumber(cur) or 0, tonumber(max) or 0
    if max <= 0 then cur, max = 0, 1 end
    if cur > max then cur = max end
    self.secret = false
    if self.max ~= max then
        self.fill:SetMinMaxValues(0, max)
        self.trail:SetMinMaxValues(0, max)
        -- keep what is on screen at the same share of the bar
        if self.max and self.disp then
            self.disp = self.disp / self.max * max
            self.trailValue = self.trailValue / self.max * max
        end
        self.max = max
    end
    if instant or not self.disp then
        self.goal, self.disp, self.trailValue, self.hold = cur, cur, cur, 0
        self.fill:SetValue(cur)
        self.trail:SetValue(cur)
        return
    end
    if self.goal and cur < self.goal then self.hold = TRAIL_HOLD end
    self.goal = cur
    if not self.animating and (self.disp ~= cur or self.trailValue ~= self.disp) then
        self.animating = true
        self:SetScript("OnUpdate", BarOnUpdate)
    end
end

-- A flash over the bar, stronger for a bigger hit. color: { r, g, b } (white when left out); fade: how fast it
-- fades (per second). It fades on a timer of its own: a bar whose own timer something else runs (a cast bar,
-- filled by the cast) would otherwise keep the flash lit for good, a solid bright bar.
local function FlashOnUpdate(driver, dt)
    local bar = driver.bar
    bar.flashA = math.max(0, (bar.flashA or 0) - dt * (bar.flashFade or 3.5))
    bar.flashTex:SetAlpha(bar.flashA)
    if bar.flashA <= 0 then driver:SetScript("OnUpdate", nil) end
end

function BarMethods:Flash(share, color, fade)
    if not self.flashTex then
        local flash = self.over:CreateTexture(nil, "OVERLAY")
        flash:SetAllPoints(self)
        flash:SetTexture(ns.media.bar)
        flash:SetBlendMode("ADD")
        if self.mask then pcall(flash.AddMaskTexture, flash, self.mask) end
        self.flashTex = flash
        self.flashDriver = CreateFrame("Frame", nil, self)
        self.flashDriver.bar = self
    end
    local c = color or { 1, 1, 1 }
    self.flashTex:SetVertexColor(c[1], c[2], c[3], 1)
    self.flashFade = fade or 3.5
    self.flashA = math.min(1, 0.45 + (share or 0) * 2)
    self.flashTex:SetAlpha(self.flashA)
    self.flashDriver:SetScript("OnUpdate", FlashOnUpdate)
end

-- SetValues, plus the flash when the value dropped. Returns the filled share (nil when secret).
function BarMethods:Update(cur, max, instant)
    local before = self:GetFraction()
    self:SetValues(cur, max, instant)
    local after = self:GetFraction()
    if not instant and before and after and after < before - 0.001 then self:Flash(before - after) end
    return after
end

-- Incoming heals, drawn right after the filled part (works with secret values too: the game's own bars do
-- the arithmetic). nil hides it.
local function Extra(self, key, after, r, g, b, a)
    local x = self[key]
    if not x then
        x = CreateFrame("StatusBar", nil, self)
        x:SetStatusBarTexture(ns.media.bar)
        x:SetStatusBarColor(r, g, b, a)
        x:SetFrameLevel(self.fill:GetFrameLevel())
        if self.mask then pcall(function() x:GetStatusBarTexture():AddMaskTexture(self.mask) end) end
        self[key] = x
    end
    x:ClearAllPoints()
    x:SetPoint("TOPLEFT", after, "TOPRIGHT", 0, 0)
    x:SetPoint("BOTTOMLEFT", after, "BOTTOMRIGHT", 0, 0)
    x:SetWidth(self:GetWidth())
    return x
end

local function Some(v)
    if v == nil then return false end
    if ns.IsSecret(v) then return true end
    return type(v) == "number" and v > 0
end

-- The colour of the heal on its way: its school's (holy gold, nature green...), or the plain heal green (nil)
function BarMethods:SetIncomingColor(c)
    self.healColor = c
    if self.healBar then
        if c then self.healBar:SetStatusBarColor(c[1], c[2], c[3], 0.65)
        else self.healBar:SetStatusBarColor(0.55, 1, 0.6, 0.55) end
    end
end

-- Heals on their way: yours first, from the end of the health, in its school's colour; then everyone else's,
-- paler, after it (others may be nil: then heal is all of it, in the one colour)
ns.OTHERS_HEAL = { 0.86, 0.95, 1 }
function BarMethods:SetIncoming(heal, others)
    if self.vertical then
        local plain = type(heal) == "number" and type(others) == "number" and not ns.IsSecret(heal) and not ns.IsSecret(others)
        return self:SetIncomingUp(plain and (heal + others) or (Some(heal) and heal or others))
    end
    if self.SetClipsChildren and not self.clipped then self:SetClipsChildren(true); self.clipped = true end
    local max = self.rawMax
    local fillTex = self.fill:GetStatusBarTexture()
    local after = fillTex
    if Some(heal) and max then
        local h = Extra(self, "healBar", fillTex, 0.55, 1, 0.6, 0.55)
        self:SetIncomingColor(self.healColor)
        h:SetMinMaxValues(0, max)
        h:SetValue(heal)
        h:Show()
        after = h:GetStatusBarTexture()
    elseif self.healBar then
        self.healBar:Hide()
    end
    if Some(others) and max then
        local c = ns.OTHERS_HEAL
        local o = Extra(self, "othersBar", after, c[1], c[2], c[3], 0.4)
        o:SetMinMaxValues(0, max)
        o:SetValue(others)
        o:Show()
    elseif self.othersBar then
        self.othersBar:Hide()
    end
end

-- A unit's heals on their way: yours, and everyone else's (the game's own totals). Where the game keeps the
-- amounts to itself no sum can be done: then all of it comes as one, and others is nil.
function ns.IncomingHeals(unit)
    if not UnitGetIncomingHeals then return nil, nil end
    local okA, all = pcall(UnitGetIncomingHeals, unit)
    if not okA then return nil, nil end
    local okM, mine = pcall(UnitGetIncomingHeals, unit, "player")
    if not okM or ns.IsSecret(all) or ns.IsSecret(mine) or type(all) ~= "number" then return all, nil end
    mine = type(mine) == "number" and mine or 0
    return mine, math.max(0, all - mine)
end

---------------------------------------------------------------------------
-- Who is healing: the heals on their way that aren't yours, by name. The game is asked about each healer in turn
-- (how much of theirs is on its way to this unit) and only one it answers with a number we can read is named;
-- where it keeps that to itself there is no name, and nothing is guessed from who happens to be casting.
-- Asked: your group, then your target, focus and pointer for a healer from outside it.
---------------------------------------------------------------------------
ns.OTHER_HEALERS = { "target", "focus", "mouseover" }

-- The first name ("Taric" for "Taric Lumenshield"): the room is a bar's. A secret name is passed on unread.
local function FirstName(name)
    if ns.IsSecret(name) then return name end
    if type(name) ~= "string" then return nil end
    return name:match("^[^%s%-]+")
end

-- The names of those healing `unit` (not you), in the group's order, or nil. heal and others are what
-- ns.IncomingHeals said.
function ns.IncomingHealers(unit, heal, others)
    if not (UnitGetIncomingHeals and ns.db and ns.db.healerNames) then return nil end
    if not (Some(heal) or Some(others)) then return nil end
    -- others is a plain number only when the game lets the totals be read: then none of theirs means nobody to
    -- ask about, and the asking stops once the named account for all of it
    local total
    if not ns.IsSecret(others) and type(others) == "number" then
        if others <= 0 then return nil end
        total = others
    end
    local names, named, seen = {}, 0, {}
    local me = ns.GUID("player")
    if me then seen[me] = true end
    local function Ask(healer, outsider)
        local okE, there = pcall(UnitExists, healer)
        if not (okE and ns.Yes(there)) then return end
        local okI, mine = pcall(UnitIsUnit, healer, "player")
        if okI and ns.Yes(mine) then return end
        local guid = ns.GUID(healer)
        if guid then
            if seen[guid] then return end
            seen[guid] = true
        elseif outsider then
            return                              -- who it is can't be told: it may be one already named
        end
        local ok, amount = pcall(UnitGetIncomingHeals, unit, healer)
        if not ok or ns.IsSecret(amount) or type(amount) ~= "number" or amount <= 0 then return end
        local okN, name = pcall(UnitName, healer)
        if not okN then return end
        local short = FirstName(name)
        if ns.IsSecret(short) or short then
            names[#names + 1] = short
            named = named + amount
        end
    end
    local raid = IsInRaid and ns.Yes(IsInRaid())
    local prefix, size = raid and "raid" or "party", raid and 40 or 4
    for i = 1, size do
        if total and named >= total then break end
        Ask(prefix .. i)
    end
    for _, healer in ipairs(ns.OTHER_HEALERS) do
        if total and named >= total then break end
        Ask(healer, true)
    end
    return #names > 0 and names or nil
end

-- The healers' names, in the paler heal colour: along the bar at its right end, where their heal grows; above an
-- upright bar, one under the other. A couple at most (one on a narrow bar), then how many more. nil hides them.
ns.HEALERS_NARROW = 90          -- raid tiles are under this; a healer's party row (95) is not
function BarMethods:SetHealers(names)
    local fs = self.healerText
    if not names then
        if fs then fs:Hide() end
        return
    end
    if not fs then
        local layer = ns.FactionLayer(self)     -- over the bar: what is drawn on it is clipped to its edges
        fs = ns.FontString(layer, self.vertical and 7 or 8, "RIGHT")
        if self.vertical then
            fs:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT", 0, 4)
        else
            fs:SetPoint("RIGHT", self, "RIGHT", -3, 0)
            fs:SetPoint("LEFT", self, "LEFT", 3, 0)
            if fs.SetWordWrap then fs:SetWordWrap(false) end
        end
        local c = ns.OTHERS_HEAL
        fs:SetTextColor(c[1], c[2], c[3], 1)
        self.healerText = fs
    end
    local most = 3
    if not self.vertical then
        local ok, w = pcall(self.GetWidth, self)
        most = (ok and type(w) == "number" and not ns.IsSecret(w) and w < ns.HEALERS_NARROW) and 1 or 2
    end
    local shown = math.min(#names, most)
    local parts, values = {}, {}
    for i = 1, shown do parts[i], values[i] = "%s", names[i] end
    local format = table.concat(parts, self.vertical and "\n" or ", ")
    if #names > shown then
        format = format .. (self.vertical and "\n+%d" or " +%d")
        values[shown + 1] = #names - shown
    end
    -- (the game puts the names in itself: one it keeps secret can be shown, never read or joined)
    if pcall(fs.SetFormattedText, fs, format, unpack(values, 1, #values)) then fs:Show() else fs:Hide() end
end

-- A unit's heals on its bar, and (named true) who the others' are from
function ns.ShowIncoming(bar, unit, named)
    local heal, others = ns.IncomingHeals(unit)
    bar:SetIncoming(heal, others)
    bar:SetHealers(named and ns.IncomingHealers(unit, heal, others) or nil)
end

-- A shield on the unit: how much it will soak, as a silver-blue band laid over the bar from its far end (the top
-- of an upright bar), with a bright edge where it begins. Drawn from the end rather than after the health, so it
-- shows on a full bar too and works with amounts the game keeps to itself (the bar is given them unread).
ns.SHIELD_COLOR = { 0.72, 0.85, 1 }
function BarMethods:SetAbsorb(amount)
    local max = self.rawMax
    if not (Some(amount) and max and ns.db and ns.db.shieldBars) then
        if self.absorbBar then self.absorbBar:Hide() end
        return
    end
    local x = self.absorbBar
    if not x then
        local c = ns.SHIELD_COLOR
        x = CreateFrame("StatusBar", nil, self)
        x:SetAllPoints(self)
        x:SetStatusBarTexture(ns.media.bar)
        x:SetStatusBarColor(c[1], c[2], c[3], 0.55)
        if x.SetReverseFill then x:SetReverseFill(true) end
        if self.vertical then x:SetOrientation("VERTICAL") end
        x:SetFrameLevel((self.over and self.over:GetFrameLevel() or self.fill:GetFrameLevel()) - 0)
        if self.mask then pcall(function() x:GetStatusBarTexture():AddMaskTexture(self.mask) end) end
        local edge = x:CreateTexture(nil, "OVERLAY")
        edge:SetColorTexture(0.9, 0.96, 1, 0.9)
        local tex = x:GetStatusBarTexture()
        if self.vertical then
            edge:SetHeight(1)
            edge:SetPoint("BOTTOMLEFT", tex, "BOTTOMLEFT", 0, 0)
            edge:SetPoint("BOTTOMRIGHT", tex, "BOTTOMRIGHT", 0, 0)
        else
            edge:SetWidth(1)
            edge:SetPoint("TOPLEFT", tex, "TOPLEFT", 0, 0)
            edge:SetPoint("BOTTOMLEFT", tex, "BOTTOMLEFT", 0, 0)
        end
        x.edge = edge
        self.absorbBar = x
    end
    x:SetMinMaxValues(0, max)
    x:SetValue(amount)
    x:Show()
end

-- The same for an upright bar: the heal sits on top of the filled part
function BarMethods:SetIncomingUp(heal)
    local max = self.rawMax
    if not (Some(heal) and max) then
        if self.healBar then self.healBar:Hide() end
        return
    end
    local h = self.healBar
    if not h then
        h = CreateFrame("StatusBar", nil, self)
        h:SetStatusBarTexture(ns.media.bar)
        h:SetStatusBarColor(0.55, 1, 0.6, 0.55)
        h:SetOrientation("VERTICAL")
        h:SetFrameLevel(self.fill:GetFrameLevel())
        self.healBar = h
    end
    if self.SetClipsChildren and not self.clipped then self:SetClipsChildren(true); self.clipped = true end
    local fillTex = self.fill:GetStatusBarTexture()
    h:ClearAllPoints()
    h:SetPoint("BOTTOMLEFT", fillTex, "TOPLEFT", 0, 0)
    h:SetPoint("BOTTOMRIGHT", fillTex, "TOPRIGHT", 0, 0)
    h:SetHeight(self:GetHeight())
    h:SetMinMaxValues(0, max)
    h:SetValue(heal)
    h:Show()
end

-- A level's colour against yours, like the game's: grey (no challenge), green, yellow, orange, red (and red
-- for "??"). Uses the game's own colours when it has them.
local function GreenRange(level)
    if GetQuestGreenRange then
        local ok, r = pcall(GetQuestGreenRange)
        if ok and type(r) == "number" then return r end
    end
    if level <= 5 then return 5 elseif level <= 39 then return math.floor(level / 10) + 5 end
    return math.floor(level / 5) + 1
end

function ns.LevelColor(level)
    if type(level) ~= "number" or ns.IsSecret(level) or level <= 0 then return 1, 0.1, 0.1 end
    if GetQuestDifficultyColor then
        local ok, c = pcall(GetQuestDifficultyColor, level)
        if ok and type(c) == "table" and c.r then return c.r, c.g, c.b end
    end
    local mine = UnitLevel("player") or 1
    local diff = level - mine
    if diff >= 5 then return 1, 0.1, 0.1 end
    if diff >= 3 then return 1, 0.5, 0.25 end
    if diff >= -2 then return 1, 0.82, 0 end
    if -diff <= GreenRange(mine) then return 0.25, 0.75, 0.25 end
    return 0.5, 0.5, 0.5
end

-- "35" in its level colour, ready to go in front of a name
-- A player's full name: the game hands it over in two parts ("Faith", "Ashborne") and writes it "Faith-Ashborne";
-- in this game mode the second part is the last name players know each other by, so it is shown as a name:
-- "Faith Ashborne". A name the game keeps secret is passed on as it is.
-- Character names never hold a hyphen, so one in a name is always that join: it becomes a space wherever the
-- game hands the name over already joined.
function ns.FullName(name, last)
    if type(name) ~= "string" or ns.IsSecret(name) then return name end
    local first, joined = name:match("^([^%-]+)%-(.+)$")
    if first then name, last = first, (last == nil or last == "") and joined or last end
    if not (ns.db and ns.db.lastNames) or ns.IsSecret(last) or type(last) ~= "string" or last == "" then return name end
    -- the game may hand the name over with the last name in it already (a player's title name does)
    if name == last or name:sub(-(#last + 1)) == " " .. last then return name end
    return name .. " " .. last
end

-- A player's name and last name by their GUID, when the game lets us read them that way (nil, nil if not)
function ns.NameByGUID(unit)
    local ok, guid = pcall(UnitGUID, unit)
    if not ok or not guid or ns.IsSecret(guid) or not GetPlayerInfoByGUID then return nil end
    local ok2, _, _, _, _, _, name, last = pcall(GetPlayerInfoByGUID, guid)
    if ok2 and type(name) == "string" and not ns.IsSecret(name) then
        return name, (not ns.IsSecret(last)) and last or nil
    end
end

---------------------------------------------------------------------------
-- The other faction, plainly: a player of the other faction wears the faction's badge (the game's own) before
-- the name, and an outline in the faction's colour round the health bar, Alliance blue and Horde red, on
-- nameplates and the target frame. Names keep their colours (they are read by colour too). Your own faction is
-- left as it is. (Setting: factionMarks, UnitFrames.lua.)
---------------------------------------------------------------------------
ns.FACTION_COLOR = { Alliance = { 0.30, 0.58, 1.00 }, Horde = { 0.95, 0.28, 0.24 } }
local FACTION_ICON = { Alliance = "Interface\\TargetingFrame\\UI-PVP-Alliance",
                       Horde = "Interface\\TargetingFrame\\UI-PVP-Horde" }
local function Faction(unit)
    if not UnitFactionGroup then return nil end
    local ok, f = pcall(UnitFactionGroup, unit)
    if ok and type(f) == "string" and not ns.IsSecret(f) then return f end
end
-- The other faction's name, when the unit is a player of it (and the option is on), else nil
function ns.OtherFaction(unit)
    if not (ns.db and ns.db.factionMarks and unit and UnitIsPlayer) then return nil end
    local ok, isPlayer = pcall(UnitIsPlayer, unit)
    if not (ok and ns.Yes(isPlayer)) then return nil end
    local theirs, mine = Faction(unit), Faction("player")
    if theirs and mine and theirs ~= mine and FACTION_ICON[theirs] then return theirs end
end
-- In a battleground or arena (crowded, and everyone across is the other faction)
ns.PVP_KINDS = { pvp = true, arena = true }
function ns.InPvP()
    if not IsInInstance then return false end
    local ok, inside, kind = pcall(IsInInstance)
    return ok and ns.Yes(inside) and ns.PVP_KINDS[kind] or false
end

-- The colour a player of the other faction is marked in: the faction's own (Alliance blue, Horde red), or, with
-- "Ally or enemy" chosen, the red of an enemy whichever faction it is (setting: factionStyle, UnitFrames.lua)
ns.ENEMY_COLOR = { 0.95, 0.28, 0.24 }
function ns.FactionColor(f)
    if not f then return nil end
    if ns.db and ns.db.factionStyle == 2 then return ns.ENEMY_COLOR end
    return ns.FACTION_COLOR[f]
end

-- The faction's marks on a bar (its outline, a tint over the health, the badge beside it) live on a layer of
-- their own over the bar, not on the bar: a bar that shows incoming heals clips what is drawn on it to its own
-- edges, which took the badge and the outline (both just outside) away on the target frame. The layer shows and
-- hides with the bar.
local function Layer(bar)
    local layer = rawget(bar, "factionLayer")
    if layer then return layer end
    local okP, parent = pcall(bar.GetParent, bar)
    layer = CreateFrame("Frame", nil, (okP and parent) or UIParent)
    layer:SetAllPoints(bar)
    local okL, level = pcall(bar.GetFrameLevel, bar)
    layer:SetFrameLevel(((okL and tonumber(level)) or 1) + 10)
    bar.factionLayer = layer
    if bar.HookScript then
        bar:HookScript("OnShow", function() layer:Show() end)
        bar:HookScript("OnHide", function() layer:Hide() end)
    end
    local okS, shown = pcall(bar.IsShown, bar)
    if okS and not shown then layer:Hide() end
    return layer
end
ns.FactionLayer = Layer

-- An outline round a bar in a faction's colour and a light tint of it over the health (color nil: none). Made the
-- first time, on the bar's layer, the outline just outside its edges.
ns.FACTION_EDGE = 2
ns.FACTION_TINT = 0.22
function ns.FactionEdge(bar, color)
    if type(bar) ~= "table" or not bar.CreateTexture then return end
    -- PvP: no tint. A bar the game won't let us colour by class there stays hostile red, and the faction's tint
    -- over it (Alliance blue) turned it pink; and everyone across is the other faction anyway (its badge says so)
    if color and ns.InPvP() then color = nil end
    local e = rawget(bar, "factionEdge")
    if not color then
        if e then for _, t in ipairs(e) do t:Hide() end end
        if rawget(bar, "factionTint") then bar.factionTint:Hide() end
        bar.factionShown = false
        return
    end
    local layer = Layer(bar)
    if not e then
        local w = ns.FACTION_EDGE
        e = {}
        for i, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
            local t = layer:CreateTexture(nil, "OVERLAY", nil, 7)
            t:SetColorTexture(1, 1, 1, 1)
            if side == "TOP" or side == "BOTTOM" then
                local y = side == "TOP" and w or -w
                t:SetPoint(side .. "LEFT", bar, side .. "LEFT", -w, y)
                t:SetPoint(side .. "RIGHT", bar, side .. "RIGHT", w, y)
                t:SetHeight(w)
            else
                local x = side == "LEFT" and -w or w
                t:SetPoint("TOP" .. side, bar, "TOP" .. side, x, 0)
                t:SetPoint("BOTTOM" .. side, bar, "BOTTOM" .. side, x, 0)
                t:SetWidth(w)
            end
            e[i] = t
        end
        bar.factionEdge = e
        local tint = layer:CreateTexture(nil, "ARTWORK")                -- the highlight: the bar lit in its colour
        tint:SetColorTexture(1, 1, 1, 1)
        tint:SetBlendMode("ADD")
        tint:SetAllPoints(bar)
        bar.factionTint = tint
    end
    for _, t in ipairs(e) do
        t:SetVertexColor(color[1], color[2], color[3], 0.95)
        t:Show()
    end
    bar.factionTint:SetVertexColor(color[1], color[2], color[3], ns.FACTION_TINT)
    bar.factionTint:Show()
    bar.factionShown = true
end

-- A player's class, where the game keeps it secret (a battleground's other side): the game can still show it for
-- us. A name takes its colour (C_ClassColor's colour, FontString:SetTextColor) and a texture its icon (the game's
-- GetClassAtlas, Texture:SetAtlas); a bar does not take a secret colour, so bars stay as they are there. (Tried in
-- the game: /cchud classprobe.) A way the game refuses is never tried again: each refusal counts as an addon error.
ns.secretWays = {}
local function Way(key, fn, ...)
    if ns.secretWays[key] == false or type(fn) ~= "function" then return false end
    local ok, a, b, c = pcall(fn, ...)
    if not ok then ns.secretWays[key] = false; return false end
    ns.secretWays[key] = true
    return true, a, b, c
end
ns.CLASS_ICONS = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"

-- A player's name in their class's colour, the class kept secret or not; false where it cannot be had
function ns.ClassNameColor(fs, unit)
    if not (fs and unit) then return false end
    local okC, _, class = pcall(UnitClass, unit)
    if not okC then return false end
    if not ns.IsSecret(class) then
        local c = type(class) == "string" and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if not c then return false end
        fs:SetTextColor(c.r, c.g, c.b)
        return true
    end
    local okG, color = Way("classColor", C_ClassColor and C_ClassColor.GetClassColor, class)
    if not okG or type(color) ~= "table" or not color.GetRGB then return false end
    local okR, r, g, b = Way("classRGB", color.GetRGB, color)
    if not okR then return false end
    return (Way("classNameColor", fs.SetTextColor, fs, r, g, b))
end

-- A player's health bar in their class's colour where the game keeps the class secret (a battleground's other
-- side): the game refuses that colour on the bar itself (StatusBar:SetStatusBarColor), so it goes on the bar's
-- own texture (Texture:SetVertexColor), the way a name takes it (FontString:SetTextColor). Tried once: a way the
-- game refuses is never tried again (each refusal counts as an addon error), and the bar keeps its usual colour.
-- True when the bar took it. (A class the game shows: TargetHealthColor colours the bar as ever.)
function ns.ClassBarColor(bar, unit)
    if not (type(bar) == "table" and bar.fill and unit and ns.db and ns.db.classColors) then return false end
    local okP, isPlayer = pcall(UnitIsPlayer, unit)
    if not (okP and ns.Yes(isPlayer)) then return false end
    local okD, dead = pcall(UnitIsDeadOrGhost, unit)
    if okD and ns.Yes(dead) then return false end
    local okC, _, class = pcall(UnitClass, unit)
    if not (okC and ns.IsSecret(class)) then return false end
    local okG, color = Way("classColor", C_ClassColor and C_ClassColor.GetClassColor, class)
    if not okG or type(color) ~= "table" or not color.GetRGB then return false end
    local okR, r, g, b = Way("classRGB", color.GetRGB, color)
    if not okR then return false end
    local okT, tex = pcall(bar.fill.GetStatusBarTexture, bar.fill)
    if not (okT and type(tex) == "table" and tex.SetVertexColor) then return false end
    if ns.secretWays.classBarColor == false then return false end
    pcall(bar.fill.SetStatusBarColor, bar.fill, 1, 1, 1, 1)          -- (white under it: the texture's colour shows)
    return (Way("classBarColor", tex.SetVertexColor, tex, r, g, b, 1))
end

-- A player's class icon on a texture, the class kept secret or not; false where it cannot be had
function ns.ClassIconTexture(tex, unit)
    if not (tex and unit) then return false end
    local okC, _, class = pcall(UnitClass, unit)
    if not okC then return false end
    if not ns.IsSecret(class) then
        local c = type(class) == "string" and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
        if not c then return false end
        tex:SetTexture(ns.CLASS_ICONS)
        tex:SetTexCoord(c[1], c[2], c[3], c[4])
        return true
    end
    local okA, atlas = Way("classAtlas", rawget(_G, "GetClassAtlas") or (C_Texture and C_Texture.GetClassAtlas), class)
    if not okA then return false end
    tex:SetTexCoord(0, 1, 0, 1)
    return (Way("classIcon", tex.SetAtlas, tex, atlas))
end

-- The icon of a class kept secret, as a texture of its own just before a line of text (the line can't carry it:
-- a secret can't be written into text). holder keeps it (holder.classTex); hidden when there is none to show.
function ns.SecretClassIcon(holder, fs, unit, show, bar)
    local t = rawget(holder, "classTex")
    local okC, _, class = pcall(UnitClass, unit)
    if not (show and okC and ns.IsSecret(class)) then
        if t then t:Hide() end
        return false
    end
    if not t then
        t = holder:CreateTexture(nil, "OVERLAY")
        holder.classTex = t
    end
    local okF, _, size = pcall(fs.GetFont, fs)
    size = (okF and tonumber(size)) or 12
    t:SetSize(size + 2, size + 2)
    local okW, w = pcall(fs.GetStringWidth, fs)
    local known = okW and type(w) == "number" and not ns.IsSecret(w) and w > 0
    local okJ, justify = pcall(fs.GetJustifyH, fs)
    t:ClearAllPoints()
    t.onBar = false
    if okJ and justify == "LEFT" then
        t:SetPoint("RIGHT", fs, "LEFT", -2, 0)
    elseif known then
        t:SetPoint("RIGHT", fs, "CENTER", -w / 2 - 2, 0)
    elseif bar then
        -- the name's width kept secret too (a battleground's other side): measuring it is refused, and guessing put
        -- the icon over the middle of the name. At the bar's left end instead, clear of the name; and left of the
        -- other faction's badge where that is there (it sits at the bar's end too, and hid the icon)
        local badge = rawget(bar, "factionBadge")
        local okB, badgeShown = false, false
        if badge then okB, badgeShown = pcall(badge.IsShown, badge) end
        if okB and badgeShown == true then
            t:SetPoint("RIGHT", badge, "LEFT", -3, 0)
        else
            t:SetPoint("RIGHT", bar, "LEFT", -4, 0)
        end
        t.onBar = true
    else
        t:SetPoint("BOTTOM", fs, "TOP", 0, 1)              -- (no bar: above the line)
    end
    if ns.ClassIconTexture(t, unit) then t:Show(); return true end
    t:Hide()
    return false
end

-- The badge as text (before a name, the name's own height) and the faction's colour, or "" and nil. For a plate
-- with no bar; where there is a bar the badge is a picture of its own beside it (FactionBadge): a badge bigger
-- than the text inside the text made the line taller than its place and pushed the name down into the bar.
function ns.FactionMark(unit)
    local f = ns.OtherFaction(unit)
    if not f then return "", nil end
    return ("|T%s:0:0:0:0:64:64:0:40:0:40|t"):format(FACTION_ICON[f]), ns.FactionColor(f)
end

-- The badge, big, just left of a bar (made the first time, on the bar itself): shown for a player of the other
-- faction, hidden otherwise. Its size: FACTION_BADGE times the name's font (`text`), within BADGE_MIN..BADGE_MAX.
-- Returns the faction's colour, or nil.
ns.FACTION_BADGE, ns.BADGE_MIN, ns.BADGE_MAX = 1.8, 16, 36
function ns.FactionBadge(bar, unit, text)
    if type(bar) ~= "table" or not bar.CreateTexture then return nil end
    local f = unit and ns.OtherFaction(unit)
    local t = rawget(bar, "factionBadge")
    if not f then
        if t then t:Hide() end
        return nil
    end
    if not t then
        t = Layer(bar):CreateTexture(nil, "OVERLAY", nil, 7)              -- (on the bar's layer: never clipped)
        t:SetTexCoord(0, 40 / 64, 0, 40 / 64)
        t:SetPoint("RIGHT", bar, "LEFT", -6, 0)
        bar.factionBadge = t
    end
    local font = 12
    if type(text) == "table" and text.GetFont then
        local ok, _, height = pcall(text.GetFont, text)
        if ok and tonumber(height) then font = tonumber(height) end
    end
    local size = math.max(ns.BADGE_MIN, math.min(ns.BADGE_MAX, math.floor(font * ns.FACTION_BADGE + 0.5)))
    t:SetTexture(FACTION_ICON[f])
    t:SetSize(size, size)
    t:Show()
    return ns.FactionColor(f)
end

function ns.LevelText(level)
    local r, g, b = ns.LevelColor(level)
    local shown = (type(level) == "number" and not ns.IsSecret(level) and level > 0) and tostring(level) or "??"
    return ("|cff%02x%02x%02x%s|r"):format(r * 255, g * 255, b * 255, shown)
end

-- How a unit's rank looks: the mark beside its name and the glow around its bar.
--   normal: nothing; rare: silver; elite: gold; rare elite: silver mark on a gold glow; boss: a red skull
-- wings: the classic dragon-frame flourish around a nameplate's name (gold for elite, silver for rare)
ns.RANK = {
    rare      = { mark = "mark",  color = { 0.82, 0.85, 0.92 }, glow = { 0.82, 0.85, 0.92 }, wings = { 0.82, 0.85, 0.92 } },
    elite     = { mark = "mark",  color = { 1, 0.78, 0.25 },    glow = { 1, 0.78, 0.25 },    wings = { 1, 0.78, 0.25 } },
    rareelite = { mark = "mark",  color = { 0.82, 0.85, 0.92 }, glow = { 1, 0.78, 0.25 },    wings = { 0.82, 0.85, 0.92 } },
    worldboss = { mark = "skull", color = { 1, 0.2, 0.2 },      glow = { 1, 0.2, 0.2 },      wings = { 1, 0.78, 0.25 } },
}

function ns.RankOf(kind, level)
    if kind == "worldboss" or (type(level) == "number" and not ns.IsSecret(level) and level <= 0) then
        return ns.RANK.worldboss
    end
    return ns.RANK[kind or ""]
end

---------------------------------------------------------------------------
-- Raid target marks (skull, cross, star...): the game's own icons, on whatever shows a unit. Made the first time
-- a unit there is marked. holder keeps it (as holder.raidMark), parent draws it, then its size and where it goes.
-- Where the game keeps the mark secret it is drawn by the game's own sheet of them, unread.
---------------------------------------------------------------------------
ns.RAID_MARKS = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
ns.marksShown = 0
function ns.ShowRaidMark(holder, parent, unit, size, ...)
    local ok, index = false, nil
    if unit and GetRaidTargetIndex then ok, index = pcall(GetRaidTargetIndex, unit) end
    local t = holder.raidMark
    local secret = ok and ns.IsSecret(index)
    if not secret then
        index = ok and tonumber(index) or nil
        if not index or index < 1 or index > 8 then
            if t then t:Hide() end
            holder.raidIndex = nil
            return nil
        end
    end
    if not t then
        t = parent:CreateTexture(nil, "OVERLAY", nil, 7)
        t:SetTexture(ns.RAID_MARKS)
        t:SetSize(size, size)
        t:SetPoint(...)
        holder.raidMark = t
    end
    if secret then
        if not (t.SetSpriteSheetCell and pcall(t.SetSpriteSheetCell, t, index, 4, 4)) then
            t:Hide()
            return nil
        end
    else
        local col, row = (index - 1) % 4, math.floor((index - 1) / 4)
        t:SetTexCoord(col * 0.25, (col + 1) * 0.25, row * 0.25, (row + 1) * 0.25)
    end
    t:Show()
    -- (a mark the game keeps secret cannot be compared with the last one: counted as new, kept as "secret")
    local last = holder.raidIndex
    if secret or ns.IsSecret(last) or last ~= index then ns.marksShown = ns.marksShown + 1 end
    holder.raidIndex = secret and "secret" or index
    return index
end

-- Sets a mark texture and a glow texture (either may be nil) for a rank; returns the rank (or nil)
function ns.ShowRank(mark, glow, kind, level)
    local rank = ns.RankOf(kind, level)
    if mark then
        if rank then
            mark:SetTexture(ns.media[rank.mark])
            mark:SetVertexColor(rank.color[1], rank.color[2], rank.color[3], 1)
            mark:Show()
        else
            mark:Hide()
        end
    end
    if glow then
        if rank then
            glow:SetVertexColor(rank.glow[1], rank.glow[2], rank.glow[3], 1)
            glow:Show()
        else
            glow:Hide()
        end
    end
    return rank
end

-- A cast whose times the game keeps to itself (an enemy's, in a fight). Its bar still has to fill, so each of
-- these is tried in turn, and what was used and why the ones before it were not is kept for the reports:
--   1. the cast's duration, as the game hands it out: its elapsed time is read every frame and passed to the
--      bar unseen, the way health the game hides is ("elapsed")
--   2. the bar's own timer, run by the game on that duration ("timer")
--   3. the spell's own cast time, from the moment we saw the cast begin ("spell length", an estimate)
--   4. how long this kind of unit took over a cast the last time we watched one through ("learned", an estimate)
--   5. none of it known: a dim full bar that only says "casting"
ns.castRoutes, ns.castWhy, ns.castLearned = {}, {}, {}
local function Took(route)
    ns.castRoutes[route] = (ns.castRoutes[route] or 0) + 1
    ns.castRoute = route
    return route
end
ns.CastTook = Took
local function Why(stage, err)
    err = tostring(err)
    if ns.castWhy[stage] ~= err then
        ns.castWhy[stage] = err
        ns.Note("cast bars: %s was not to be had (%s)", stage, err)
    end
end

-- Returns "elapsed" or "timer" when the game runs the bar, false when it cannot. With "elapsed" the bar keeps
-- the duration (bar.duration) and whoever shows it calls ns.CastTick(bar) every frame.
function ns.GameCastTimer(bar, unit, channel)
    bar.duration, bar.durationChannel = nil, nil
    local get = channel and UnitChannelDuration or UnitCastingDuration
    if not get then
        Why("the cast's duration", "this game has no function for it")
        return false
    end
    local okD, duration = pcall(get, unit)
    if not okD then Why("the cast's duration", duration); return false end
    -- (never tested as true or false: the game may hand it out as something that cannot be looked at)
    if not ns.IsSecret(duration) and duration == nil then
        Why("the cast's duration", "the game gave none for a unit that is casting")
        return false
    end
    local ok, err = pcall(function()
        bar.fill:SetMinMaxValues(0, duration:GetTotalDuration())
        bar.fill:SetValue(channel and duration:GetRemainingDuration() or duration:GetElapsedDuration())
    end)
    if ok then
        bar.duration, bar.durationChannel = duration, channel and true or false
        return Took("elapsed")
    end
    Why("the cast's elapsed time", err)
    bar.fill:SetMinMaxValues(0, 1)
    if not bar.fill.SetTimerDuration then
        Why("the bar's own timer", "this game has none")
        return false
    end
    -- which way it runs is said outright: a cast fills, a channel drains
    local way = Enum and Enum.StatusBarTimerDirection
    way = way and (channel and way.RemainingTime or way.ElapsedTime) or nil
    ok, err = pcall(function()
        if way ~= nil then bar.fill:SetTimerDuration(duration, nil, way) else bar.fill:SetTimerDuration(duration) end
    end)
    if ok then return Took("timer") end
    Why("the bar's own timer", err)
    return false
end

-- Every frame, for a bar that runs on the cast's own duration: where the cast is now
function ns.CastTick(bar)
    local d = bar.duration
    if not d then return end
    local ok, v = pcall(bar.durationChannel and d.GetRemainingDuration or d.GetElapsedDuration, d)
    if ok then pcall(bar.fill.SetValue, bar.fill, v) end
end

-- How long a kind of unit takes over a cast, watched on our own clock from the cast's start to its landing
-- (the game does not hide when those happen). Kept by the unit's name: the last cast we saw through.
local function Who(unit)
    local ok, name = pcall(UnitName, unit)
    if ok and type(name) == "string" and not ns.IsSecret(name) and name ~= "" then return name end
end
local began, learnedCount = {}, 0
local learner = CreateFrame("Frame")
for _, event in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_STOP",
                         "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED" }) do
    pcall(learner.RegisterEvent, learner, event)
end
learner:SetScript("OnEvent", function(_, event, unit)
    if type(unit) ~= "string" or unit == "player" then return end
    local now = GetTime()
    if event == "UNIT_SPELLCAST_START" then
        began[unit] = { at = now, who = Who(unit) }
    elseif event == "UNIT_SPELLCAST_STOP" then                -- (comes with the landing, before it or after)
        if began[unit] then began[unit].stopped = now end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local b = began[unit]
        began[unit] = nil
        if b and b.who and b.who == Who(unit) and (not b.stopped or now - b.stopped < 0.3) then
            local took = (b.stopped or now) - b.at
            if took > 0.4 and took < 15 then
                if not ns.castLearned[b.who] then
                    learnedCount = learnedCount + 1
                    if learnedCount > 300 then ns.castLearned, learnedCount = {}, 1 end
                end
                ns.castLearned[b.who] = took
            end
        end
    else
        began[unit] = nil
    end
end)

-- How long the spell a unit is casting takes (seconds; nil when that cannot be known), and how it is known:
-- by the spell itself, or by what this kind of unit took the last time. For a cast whose times the game
-- keeps to itself and gives no duration for: its bar then fills from the moment we saw the cast begin. An
-- estimate: haste and pushback are not in it.
function ns.CastLength(unit)
    local _, spellID = ns.CastLook.Casting(unit)
    local ms
    if spellID and not ns.IsSecret(spellID) then
        if C_Spell and C_Spell.GetSpellInfo then
            local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
            if ok and type(info) == "table" then ms = info.castTime end
        end
        if ms == nil and GetSpellInfo then
            local ok, _, _, _, t = pcall(GetSpellInfo, spellID)
            if ok then ms = t end
        end
    end
    if type(ms) == "number" and not ns.IsSecret(ms) and ms > 0 then
        ns.castRoute = "spell length"
        return ms / 1000
    end
    local who = Who(unit)
    local learned = who and ns.castLearned[who]
    if learned then
        ns.castRoute = "learned"
        return learned
    end
    ns.castRoute = "unknown"
    return nil
end

-- For the reports: how enemy cast bars were run, and why not better
function ns.CastRoutes()
    local out, n = {}, 0
    for _ in pairs(ns.castLearned) do n = n + 1 end
    out[1] = ("the last hidden cast ran on: %s; the game ran %d by elapsed time and %d by its timer; lengths learned by watching: %d"):format(
        tostring(ns.castRoute or "none yet"), ns.castRoutes.elapsed or 0, ns.castRoutes.timer or 0, n)
    for stage, why in pairs(ns.castWhy) do out[#out + 1] = ("%s: %s"):format(stage, why) end
    return out
end

-- A health colour that runs from green through yellow to red as health drops (frac 0-1)
function ns.HealthGradient(frac)
    frac = ns.Clamp(frac, 0, 1)
    local hi, mid, lo = ns.colors.health, ns.colors.caution, ns.colors.danger
    local a, b, t
    if frac >= 0.5 then a, b, t = mid, hi, (frac - 0.5) * 2 else a, b, t = lo, mid, frac * 2 end
    return a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t
end

-- The same colour when the game keeps health secret: the game evaluates it on a colour curve itself.
local curve
function ns.HealthGradientFor(unit)
    if not (C_CurveUtil and C_CurveUtil.CreateColorCurve and UnitHealthPercent and CreateColor) then return nil end
    local ok, color = pcall(function()
        if not curve then
            curve = C_CurveUtil.CreateColorCurve()
            for _, point in ipairs({ { 0, ns.colors.danger }, { 0.5, ns.colors.caution }, { 1, ns.colors.health } }) do
                local c = point[2]
                curve:AddPoint(point[1], CreateColor(c[1], c[2], c[3], 1))
            end
        end
        return UnitHealthPercent(unit, true, curve)
    end)
    if ok and color and color.GetRGB then return color:GetRGB() end
end

---------------------------------------------------------------------------
-- Execute range: an enemy at a quarter of its health or less. Its bar throbs red, a glow round it beating like a
-- pulse, so you know it is open to an Execute, a Hammer of Wrath, a killing blow.
---------------------------------------------------------------------------
ns.EXECUTE = 0.25

-- Is it in range? true or false where health can be read. Where the game keeps health to itself, the game is
-- asked on a curve of its own and answers with something only a frame can take (1 in range, 0 not), which is
-- handed on as it is; nil when even that cannot be had.
local execCurve
function ns.ExecuteState(unit, frac)
    if type(frac) == "number" and not ns.IsSecret(frac) then return frac > 0 and frac <= ns.EXECUTE end
    if not (C_CurveUtil and C_CurveUtil.CreateCurve and UnitHealthPercent) then return nil end
    local ok, a = pcall(function()
        if not execCurve then
            execCurve = C_CurveUtil.CreateCurve()
            if execCurve.SetType and Enum and Enum.LuaCurveType and Enum.LuaCurveType.Step then
                execCurve:SetType(Enum.LuaCurveType.Step)
            end
            execCurve:AddPoint(0, 1)
            execCurve:AddPoint(ns.EXECUTE, 1)
            execCurve:AddPoint(ns.EXECUTE + 0.0001, 0)
            execCurve:AddPoint(1, 0)
        end
        return UnitHealthPercent(unit, true, execCurve)
    end)
    if ok and a ~= nil then return a end
    return nil
end

local executing = {}
local execDriver = CreateFrame("Frame")
local function ExecPulse()
    local now, calm = GetTime(), ns.Calm and ns.Calm()
    local any = false
    for bar in pairs(executing) do
        any = true
        local beat = calm and 0.5 or (0.5 + 0.5 * math.sin(now * 6.5))    -- about a beat a second
        local e = bar.exec
        e.glow:SetAlpha(0.35 + 0.45 * beat)
        e.tint:SetAlpha(0.12 + 0.28 * beat)
    end
    if not any then execDriver:SetScript("OnUpdate", nil) end
end

-- state: true, false, the game's own answer (see ns.ExecuteState), or nil (not known: off)
function BarMethods:SetExecute(state)
    if not state then
        if self.exec then self.exec:Hide() end
        executing[self] = nil
        return
    end
    if not self.exec then
        local e = CreateFrame("Frame", nil, self)
        e:SetAllPoints(self)
        e:SetFrameLevel((self.over and self.over:GetFrameLevel() or self:GetFrameLevel()) + 1)
        e.glow = e:CreateTexture(nil, "BACKGROUND")               -- a red glow round the bar, beating
        e.glow:SetTexture(ns.media.soft)
        e.glow:SetBlendMode("ADD")
        e.glow:SetVertexColor(1, 0.12, 0.08, 1)
        e.glow:SetPoint("TOPLEFT", self, "TOPLEFT", -10, 8)
        e.glow:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 10, -8)
        e.tint = e:CreateTexture(nil, "OVERLAY")                  -- and the bar itself throbbing red with it
        e.tint:SetTexture(ns.media.bar)
        e.tint:SetBlendMode("ADD")
        e.tint:SetVertexColor(1, 0.1, 0.05, 1)
        e.tint:SetAllPoints(self)
        self.exec = e
    end
    self.exec:Show()
    if state == true then self.exec:SetAlpha(1) else pcall(self.exec.SetAlpha, self.exec, state) end
    self.executeState = state
    executing[self] = true
    execDriver:SetScript("OnUpdate", ExecPulse)
    ExecPulse()
end

-- Share of the bar that is filled (0-1), or nil when the game keeps the value secret.
function BarMethods:GetFraction()
    if self.secret or not self.goal or not self.max then return nil end
    return self.goal / self.max
end

-- A new width, with the segment marks moved to match
function BarMethods:SetBarWidth(width)
    if self.barWidth == width then return end
    self.barWidth = width
    self:SetWidth(width)
    if self.vertical then return end
    local n = #self.ticks + 1
    for i, tick in ipairs(self.ticks) do
        tick:ClearAllPoints()
        tick:SetPoint("LEFT", self, "LEFT", math.floor(width * i / n + 0.5), 0)
    end
end

function BarMethods:SetColor(r, g, b)
    self.fill:SetStatusBarColor(r, g, b, 1)
end

function ns.CreateBar(parent, width, height, opts)
    opts = opts or {}
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetSize(width, height)

    local shadow = bar:CreateTexture(nil, "BACKGROUND")
    shadow:SetTexture(ns.media.soft)
    shadow:SetVertexColor(0, 0, 0, 0.6)
    shadow:SetPoint("TOPLEFT", bar, "TOPLEFT", -10, 8)
    shadow:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 10, -8)
    bar.shadow = shadow

    local back = bar:CreateTexture(nil, "BORDER")
    back:SetAllPoints(bar)
    back:SetColorTexture(unpack(ns.colors.back))
    bar.back = back

    local trail = CreateFrame("StatusBar", nil, bar)
    trail:SetAllPoints(bar)
    trail:SetStatusBarTexture(ns.media.bar)
    trail:SetStatusBarColor(1, 1, 1, 0.6)
    trail:SetMinMaxValues(0, 1)
    trail:SetValue(0)
    bar.trail = trail

    local fill = CreateFrame("StatusBar", nil, bar)
    fill:SetAllPoints(bar)
    fill:SetStatusBarTexture(ns.media.bar)
    fill:SetMinMaxValues(0, 1)
    fill:SetValue(0)
    fill:SetFrameLevel(trail:GetFrameLevel() + 1)
    bar.fill = fill

    local over = CreateFrame("Frame", nil, bar)
    over:SetAllPoints(bar)
    over:SetFrameLevel(fill:GetFrameLevel() + 1)
    bar.over = over

    -- segment marks, like a shooter's health bar
    if opts.vertical then                     -- fills from the bottom up
        bar.vertical = true
        fill:SetOrientation("VERTICAL")
        trail:SetOrientation("VERTICAL")
    end
    bar.ticks = {}
    for i = 1, (opts.segments or 1) - 1 do
        local tick = over:CreateTexture(nil, "ARTWORK")
        tick:SetColorTexture(0.02, 0.03, 0.06, 0.65)
        if opts.vertical then
            tick:SetSize(width, 1)
            tick:SetPoint("BOTTOM", bar, "BOTTOM", 0, math.floor(height * i / opts.segments + 0.5))
        else
            tick:SetSize(1, height)
            tick:SetPoint("LEFT", bar, "LEFT", math.floor(width * i / opts.segments + 0.5), 0)
        end
        bar.ticks[i] = tick
    end

    -- slanted ends; a client without mask textures keeps square ones
    if not opts.square and not opts.vertical and bar.CreateMaskTexture then
        pcall(function()
            local mask = bar:CreateMaskTexture()
            mask:SetAllPoints(bar)
            mask:SetTexture(ns.media.mask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            back:AddMaskTexture(mask)
            fill:GetStatusBarTexture():AddMaskTexture(mask)
            trail:GetStatusBarTexture():AddMaskTexture(mask)
            bar.mask = mask
        end)
    end

    for name, fn in pairs(BarMethods) do bar[name] = fn end
    return bar
end

---------------------------------------------------------------------------
-- Threat: how your threat on a unit stands, as one shield icon and one colour, the same on the target frame
-- and on nameplates.
--   max      it is on you                          red, strong
--   gaining  you are about to pull it              red and yellow, turn about
--   losing   someone is about to take it from you  yellow and blue, turn about
--   calm     it is not on you                      blue
---------------------------------------------------------------------------
ns.THREAT_STATE = { [3] = "max", [2] = "losing", [1] = "gaining", [0] = "calm" }
local THREAT_ICON = { max = 0, gaining = 1, losing = 2, calm = 3 }
function ns.SetThreatIcon(tex, state)
    local i = THREAT_ICON[state] or 3
    tex:SetTexture(ns.media.threat)
    tex:SetTexCoord(i / 4, (i + 1) / 4, 0, 1)
end

local YELLOW = { 1, 0.86, 0.25 }
local function Mix(a, b, k)
    return a[1] + (b[1] - a[1]) * k, a[2] + (b[2] - a[2]) * k, a[3] + (b[3] - a[3]) * k
end
-- r, g, b, alpha of the glow at this moment (now: GetTime())
function ns.ThreatLook(state, now)
    local C = ns.colors
    if state == "max" then
        return C.angry[1], C.angry[2], C.angry[3], 0.85 + 0.15 * math.sin(now * 4)
    elseif state == "gaining" then
        local r, g, b = Mix(C.angry, YELLOW, 0.5 + 0.5 * math.sin(now * 7))
        return r, g, b, 0.75
    elseif state == "losing" then
        local r, g, b = Mix(YELLOW, C.calm, 0.5 + 0.5 * math.sin(now * 4))
        return r, g, b, 0.7
    elseif state == "calm" then
        return C.calm[1], C.calm[2], C.calm[3], 0.4
    end
    return 1, 1, 1, 0
end

-- Your threat on a unit: state (above, or nil out of a fight), and your share in percent (or nil)
function ns.ThreatOn(unit)
    local status, pct
    if UnitDetailedThreatSituation then
        local ok, _, s, p = pcall(UnitDetailedThreatSituation, "player", unit)
        if ok and not ns.IsSecret(s) and type(s) == "number" then status = s end
        if ok and not ns.IsSecret(p) and type(p) == "number" then pct = p end
    end
    if status == nil and UnitThreatSituation then
        local ok, s = pcall(UnitThreatSituation, "player", unit)
        if ok and not ns.IsSecret(s) and type(s) == "number" then status = s end
    end
    if status == nil then                       -- no numbers: the unit's own target says it
        local ok, onMe = pcall(UnitIsUnit, unit .. "target", "player")
        if ok and not ns.IsSecret(onMe) then status = onMe and 3 or 0 end
    end
    return status and ns.THREAT_STATE[status], pct
end
