-- ControllerCam HUD: the numbers for what happens to you, in the style of your own hits.
-- The game shows the damage you deal as big golden numbers that pop, and what you take as small plain text
-- that scrolls. While this is on, what you take gets the same treatment: in the game's damage font, popping in
-- and falling away beside your character, coloured by the damage school; heals rise in green; crits are
-- bigger and hold longer; a dodge, parry or miss says so.
-- Tightly coupled to the game's own option ("combat text for you"): when that is off, nothing shows here
-- either. When on, our numbers stand in for the game's scrolling text, which is made invisible meanwhile.

local ADDON, ns = ...
local C = ns.colors

local N = { active = false, live = {}, free = {} }
ns.Numbers = N

ns.RegisterSetting({
    key = "numbers", kind = "boolean", default = true, command = "numbers", section = "Frames",
    label = "Stylized numbers on you",
    tip = "the damage and healing you take pop like your own hits, instead of the game's scrolling text (follows the game's option for combat text on you)",
})

local CVAR = "enableFloatingCombatText"
local POP, LIFE = 0.14, 1.1
-- crits and dodges are the big moments: they slam in, stick where they landed, then fade (like your own crits)
local SLAM, HOLD, FADE = 0.12, 0.85, 0.5
local SIZE = 26
local SCATTER = 1.4                -- how far apart a burst spreads
-- what missed you: the game's own words for it (DODGE, PARRY... are its texts in your language)
local AVOID = { DODGE = "Dodge", PARRY = "Parry", MISS = "Miss", BLOCK = "Block", RESIST = "Resist",
                IMMUNE = "Immune", EVADE = "Evade", ABSORB = "Absorb", DEFLECT = "Deflect", REFLECT = "Reflect" }
local function Word(action)
    local w = _G[action]
    if type(w) == "string" and w ~= "" then return w end
    return AVOID[action]
end

local holder = CreateFrame("Frame", nil, UIParent)
holder:SetSize(10, 10)
holder:SetFrameStrata("HIGH")
N.holder = holder

-- Where they appear: with the vertical bars on, just above the bars on your left, falling away outward (they
-- move with the bars, also when those follow the camera); otherwise just right of your character. Above the
-- bars and not on them, so a number never sits over your health and power while you need to read them.
N.RAISE = 14                       -- how far above the top of the bars they start
local side = 1
function N:Place()
    local UF = ns.UnitFrames
    local bars = UF and UF.frames and UF.frames.vertical
    holder:ClearAllPoints()
    if bars and bars.on then
        local h = UF.LAYOUT and UF.LAYOUT.vertical and UF.LAYOUT.vertical.h or 96      -- how tall the bars are
        holder:SetPoint("CENTER", bars.visual, "CENTER", -18, h / 2 + N.RAISE)
        side = -1
    else
        holder:SetPoint("CENTER", UIParent, "CENTER", 110, 30)
        side = 1
    end
    self.side = side
end

local function Font()
    return DAMAGE_TEXT_FONT or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end

local function Take()
    local fs = table.remove(N.free)
    if not fs then
        fs = holder:CreateFontString(nil, "OVERLAY")
        fs:SetShadowColor(0, 0, 0, 0.85)
        fs:SetShadowOffset(2, -2)
    end
    return fs
end

-- The game's option: may we show anything? (A client without it: yes.)
local function GameAllows()
    local v = GetCVar and GetCVar(CVAR)
    return v == nil or v == "1"
end

local driver = CreateFrame("Frame")
local function Tick(_, dt)
    for i = #N.live, 1, -1 do
        local n = N.live[i]
        n.t = n.t + dt
        local fs = n.fs
        if n.t >= n.life then
            fs:Hide()
            table.remove(N.live, i)
            N.free[#N.free + 1] = fs
        else
            if n.sticky then
                -- slam in huge, overshoot a little, then stay put and swell faintly; at the end rise and fade
                local scale
                if n.t < SLAM then
                    local k = n.t / SLAM
                    scale = n.big - (n.big - 0.92) * k
                elseif n.t < SLAM + 0.08 then
                    scale = 0.92 + 0.13 * (n.t - SLAM) / 0.08
                else
                    scale = 1.05 + 0.03 * math.min(1, (n.t - SLAM - 0.08) / HOLD)
                end
                local size = math.floor(n.size * scale + 0.5)
                if size ~= n.drawn then
                    n.drawn = size
                    fs:SetFont(Font(), size, "THICKOUTLINE")
                end
                local out = math.max(0, n.t - (n.life - FADE))
                fs:ClearAllPoints()
                fs:SetPoint("CENTER", holder, "CENTER", n.x, n.y + 30 * out)
                fs:SetAlpha(1 - out / FADE)
            else
                -- pop in big, settle, then drift away (hits fall to the side, heals rise) and fade
                local k = n.t / POP
                local scale = k < 1 and (n.big - (n.big - 1) * k) or 1
                local size = math.floor(n.size * scale + 0.5)
                if size ~= n.drawn then
                    n.drawn = size
                    fs:SetFont(Font(), size, "THICKOUTLINE")
                end
                local after = math.max(0, n.t - POP)
                local x = n.x + n.dx * after
                local y = n.y + n.dy * after - (n.fall and 60 * after * after or 0)
                fs:ClearAllPoints()
                fs:SetPoint("CENTER", holder, "CENTER", x, y)
                local fade = n.life - 0.35
                fs:SetAlpha(n.t > fade and math.max(0, 1 - (n.t - fade) / 0.35) or 1)
            end
        end
    end
    if #N.live == 0 then driver:SetScript("OnUpdate", nil) end
end
Tick = ns.Protect(Tick)

-- One number. kind: "hit" / "heal" / "word". value: a number (may be secret) or a word. color {r,g,b}.
function N:Show(kind, value, color, crit)
    local fs = Take()
    local n = { fs = fs, t = 0, kind = kind, crit = crit and true or false }
    n.sticky = crit or kind == "word"
    n.size = (crit and SIZE * 1.4 or SIZE) * ((kind == "word") and 0.9 or 1)
    n.big = n.sticky and 2.4 or 1.6
    n.life = n.sticky and (SLAM + 0.08 + HOLD + FADE) or LIFE
    -- each new one starts apart from the last (a lane, and a little chance), so a burst stays readable
    self.lane = ((self.lane or 0) % 3) + 1
    local lane = self.lane - 2
    local jx, jy = (math.random() - 0.5) * 16 * SCATTER, (math.random() - 0.5) * 10 * SCATTER
    if kind == "heal" then
        n.x, n.y, n.dx, n.dy = -20 * SCATTER + lane * 14 * SCATTER + jx, lane * 10 * SCATTER + jy, 6 * SCATTER, 46
    elseif n.sticky then                                   -- where it lands, it stays: a little above the rest
        n.x, n.y = 10 + lane * 18 * SCATTER + jx, 44 + lane * 8 * SCATTER + jy
    else
        n.x, n.y, n.dx, n.dy, n.fall = 10 + lane * 14 * SCATTER + jx, 20 + lane * 12 * SCATTER + jy, 40 * SCATTER, 20, true
    end
    n.x, n.dx = n.x * side, (n.dx or 0) * side            -- on the left of you: mirrored, falling outward
    fs:SetFont(Font(), math.floor(n.size * n.big + 0.5), "THICKOUTLINE")
    n.drawn = math.floor(n.size * n.big + 0.5)
    fs:SetTextColor(color[1], color[2], color[3], 1)
    local ok = pcall(function()
        if kind == "word" then fs:SetText(value)
        elseif kind == "heal" then fs:SetFormattedText("+%d", value)
        else fs:SetFormattedText(crit and "-%d!" or "-%d", value) end
    end)
    if not ok then N.free[#N.free + 1] = fs; return end
    fs:ClearAllPoints()
    fs:SetPoint("CENTER", holder, "CENTER", n.x, n.y)
    fs:SetAlpha(1)
    fs:Show()
    self.live[#self.live + 1] = n
    self.shown = (self.shown or 0) + 1
    driver:SetScript("OnUpdate", Tick)
end

local function SchoolColor(mask)
    local IM = ns.Impact
    local school = IM and IM.School(mask) or "physical"
    if school == "physical" then return C.danger or { 1, 0.25, 0.2 } end
    return IM.PROFILES[school].color
end

local HEAL = { 0.35, 1, 0.45 }
local WORD = { 0.85, 0.88, 0.95 }

local function Plain(v)
    if ns.IsSecret(v) then return nil end
    return v
end

-- UNIT_COMBAT for you: what happened, how hard, which school
local events = CreateFrame("Frame")
events:SetScript("OnEvent", ns.Protect(function(_, _, unit, action, flag, amount, mask)
    if unit ~= "player" or not N.active or not GameAllows() or ns.UnitFrames.fake then return end
    action = Plain(action)
    local crit = Plain(flag) == "CRITICAL"
    if action == "WOUND" then
        if not ns.IsSecret(amount) and type(amount) ~= "number" then return end
        N:Show("hit", amount, SchoolColor(Plain(mask)), crit)
    elseif action == "HEAL" then
        if not ns.IsSecret(amount) and type(amount) ~= "number" then return end
        N:Show("heal", amount, HEAL, crit)
    elseif action and AVOID[action] then
        N:Show("word", Word(action), WORD)
    end
end))

-- The demo plays its hits through here too (only yours: the player's frame)
function N:Demo(unit, amount, school, crit)
    if unit ~= "player" or not self.active or not GameAllows() then return end
    if school == "heal" then
        self:Show("heal", amount, HEAL, crit)
    else
        local IM = ns.Impact
        local color = (school and school ~= "physical" and IM and IM.PROFILES[school]) and IM.PROFILES[school].color
            or C.danger or { 1, 0.25, 0.2 }
        self:Show("hit", math.abs(amount), color, crit)
    end
end

-- The game's scrolling text for you: invisible while ours stands in. It loads on demand, so we look again
-- whenever an addon of the game's loads.
local function FadeGame()
    ns.SetBlizzardFaded("CombatText", N.active and GameAllows())
    N:Place()
end

local loader = CreateFrame("Frame")
loader:SetScript("OnEvent", ns.Protect(function(_, event, name)
    if event == "ADDON_LOADED" and name ~= "Blizzard_CombatText" then return end
    FadeGame()
end))

function N:Apply(run)
    local want = run and ns.db.numbers and true or false
    if want ~= self.active then
        self.active = want
        if want then
            pcall(events.RegisterUnitEvent, events, "UNIT_COMBAT", "player")
            pcall(loader.RegisterEvent, loader, "ADDON_LOADED")
            pcall(loader.RegisterEvent, loader, "CVAR_UPDATE")
        else
            events:UnregisterAllEvents()
            loader:UnregisterAllEvents()
            for _, n in ipairs(self.live) do n.fs:Hide(); self.free[#self.free + 1] = n.fs end
            self.live = {}
        end
    end
    FadeGame()
end

ns.RegisterModule("numbers", N)
