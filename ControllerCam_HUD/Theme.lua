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
    bolt = MEDIA .. "bolt", flower = MEDIA .. "flower", vine = MEDIA .. "vine",
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

local function FontFile() return STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF" end
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
    if self.flashA and self.flashA > 0 then
        self.flashA = math.max(0, self.flashA - dt * (self.flashFade or 3.5))
        self.flashTex:SetAlpha(self.flashA)
        settled = settled and self.flashA == 0
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
-- fades (per second).
function BarMethods:Flash(share, color, fade)
    if not self.flashTex then
        local flash = self.over:CreateTexture(nil, "OVERLAY")
        flash:SetAllPoints(self)
        flash:SetTexture(ns.media.bar)
        flash:SetBlendMode("ADD")
        if self.mask then pcall(flash.AddMaskTexture, flash, self.mask) end
        self.flashTex = flash
    end
    local c = color or { 1, 1, 1 }
    self.flashTex:SetVertexColor(c[1], c[2], c[3], 1)
    self.flashFade = fade or 3.5
    self.flashA = math.min(1, 0.45 + (share or 0) * 2)
    self.flashTex:SetAlpha(self.flashA)
    if not self.animating then
        self.animating = true
        self:SetScript("OnUpdate", BarOnUpdate)
    end
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

function BarMethods:SetIncoming(heal)
    if self.vertical then return self:SetIncomingUp(heal) end
    if self.SetClipsChildren and not self.clipped then self:SetClipsChildren(true); self.clipped = true end
    local max = self.rawMax
    local fillTex = self.fill:GetStatusBarTexture()
    if Some(heal) and max then
        local h = Extra(self, "healBar", fillTex, 0.55, 1, 0.6, 0.55)
        self:SetIncomingColor(self.healColor)
        h:SetMinMaxValues(0, max)
        h:SetValue(heal)
        h:Show()
    elseif self.healBar then
        self.healBar:Hide()
    end
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

-- A cast bar running on the game's own timer, for when it keeps the cast's times secret. Returns true when
-- the game took it over.
function ns.GameCastTimer(bar, unit, channel)
    local get = channel and UnitChannelDuration or UnitCastingDuration
    if not (get and bar.fill.SetTimerDuration) then return false end
    local ok = pcall(function()
        local duration = get(unit)
        if not duration then error("no duration") end
        bar.fill:SetTimerDuration(duration)
    end)
    return ok
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
