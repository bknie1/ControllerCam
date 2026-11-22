-- ControllerCam HUD: a game on the way, played under the flight bar (Flights.lua) while a flight master's
-- mount carries you.
--   * On a flight it is offered, not started: one line under the flight bar says which button starts it, and
--     that one button is the only one taken until you press it. An option turns it off altogether.
--   * Playing: your mount (the same one the flight bar shows) flies through a lane of clouds. A flaps it up and
--     it sinks again on its own; the gaps in the clouds are wide and the clouds slow, and flying into one only
--     fogs the net gun for a moment and ends your run of catches. Nothing is lost, nobody falls.
--   * Riders come the other way, small round portraits of the game's own (the other side's peoples, on the other
--     side's mounts). X fires a net: a rider it catches is grounded, never slain, and floats down under a
--     parachute. Each one is worth flight gold (more for a run without a cloud), shown small; the total is kept
--     with the HUD's saved settings, for later.
--   * Y again is high altitude: the game is put away (the flight bar stays) and every button is the game's
--     again, but the one that brings it back. A fight, the landing or the HUD stopping put it away at once.
-- Its buttons are bound with key bindings of its own only while it is played (ns.PadKeys), never in a fight,
-- and given back on landing. Nothing of the game's flight, map or buttons is touched. With fewer animations
-- the riders fly straight, the grounded drop straight down and nothing tilts or spins.
--
-- For later, not built yet: an on-rails section where a wing of the other side's riders comes at you; hazards
-- (a goblin's parachuted dynamite you can set off and must fly clear of); catching parachuting loot and goodies
-- with your fishing line; a boss every few encounters; power-ups bought with flight gold.

local ADDON, ns = ...
local L = ns.L
local C = ns.colors

local G = { state = "off", gold = 0, streak = 0, grounded = 0, fired = 0, bumps = 0, active = false }
ns.FlightGame = G

G.W, G.H = 300, 84                 -- the lane: as wide as the flight bar, and how tall
G.X = 44                           -- where your mount flies, from the lane's left
G.EDGE = 9                         -- your mount keeps this far from the lane's top and bottom
G.GRAVITY, G.FLAP, G.FALL = 230, 105, 150    -- how fast it sinks, how hard a flap lifts it, its fastest fall
G.SPEED = 42                       -- the clouds drift by this fast (pixels a second)
G.EVERY = 3.4                      -- a bank of clouds this often (seconds)
G.GAP, G.CLOUD_W = 50, 30          -- the gap in a bank of clouds; how wide a bank is
G.RIDER_EVERY = { 2.2, 4.2 }       -- a rider every this many seconds (between the two)
G.RIDER_SPEED = { 60, 80 }
G.RIDERS = 4                       -- riders in the lane at once, at most
G.NET_SPEED, G.NET_EVERY, G.NETS = 190, 0.5, 3   -- a net's speed, how often one can be fired, how many fly at once
G.HIT = 13                         -- a net this close to a rider catches it
G.DAZED = 1.2                      -- a cloud fogs the net gun this long
G.DROP = 34                        -- a grounded rider floats down this fast
G.YOU, G.RIDER = 24, 18            -- sizes of your mount and a rider's
G.WORTH = 5                        -- a catch is worth 1 flight gold, one more for each in a run, up to this
G.KEYS = { "PAD1", "PAD3", "PAD4" } -- A flaps, X fires a net, Y is high altitude
G.START = "PAD4"                   -- the one button bound while the game is offered or away at high altitude

ns.RegisterSetting({
    key = "flightGame", kind = "boolean", default = true, command = "flightgame", section = "Quests, chat and map",
    label = "Flights: a game on the way",
    tip = "on a flight a small game is offered under the flight bar, and one button starts it (only that button is taken until you do): flap your mount up through the clouds and net the riders coming the other way, grounding them for flight gold. The same button again is high altitude: the game is put away and the buttons are the game's again. Never in a fight, gone on landing",
})

-- Flight gold: all you have won (kept for later), and the most on one flight
local function Count(old)
    local n = tonumber(old)
    return (n and n >= 0) and math.floor(n) or 0
end
ns.RegisterSaved("flightGold", Count)
ns.RegisterSaved("flightGameBest", Count)

local function Random() return (G.random or math.random)() end
local function Between(range) return range[1] + (range[2] - range[1]) * Random() end

local function Plain(v) if ns.IsSecret(v) then return nil end return v end
local function OnTaxi()
    if type(UnitOnTaxi) ~= "function" then return false end
    local ok, on = pcall(UnitOnTaxi, "player")
    return ok and ns.Yes(on)
end

-- On a flight the flight bar shows (it is what the game is played under)
function G.Flying()
    local F = ns.Flights
    return F ~= nil and F.flight ~= nil and OnTaxi()
end

---------------------------------------------------------------------------
-- Who comes the other way: the other side's peoples, on the other side's mounts. Their faces are the game's own
-- portraits of each people (its atlas where it has one, else its sheet of race icons).
---------------------------------------------------------------------------
G.PEOPLES = {
    Alliance = { mount = "gryphon", races = { "Human", "Dwarf", "NightElf", "Gnome" } },
    Horde = { mount = "windrider", races = { "Orc", "Scourge", "Tauren", "Troll" } },
}
local ATLAS_NAME = { Scourge = "undead", NightElf = "nightelf" }
G.RACE_SHEET = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Races"

function G.Others()
    local ok, faction = false, nil
    if type(UnitFactionGroup) == "function" then ok, faction = pcall(UnitFactionGroup, "player") end
    faction = ok and Plain(faction) or nil
    return faction == "Alliance" and G.PEOPLES.Horde or G.PEOPLES.Alliance
end

-- A people's face on a texture: true when the game had one
function G.Face(tex, race, female)
    local sex = female and "female" or "male"
    local atlas = "raceicon-" .. (ATLAS_NAME[race] or race:lower()) .. "-" .. sex
    if tex.SetAtlas and C_Texture and C_Texture.GetAtlasInfo then
        local ok, info = pcall(C_Texture.GetAtlasInfo, atlas)
        if ok and Plain(info) then
            tex:SetTexCoord(0, 1, 0, 1)
            tex:SetAtlas(atlas)
            return true
        end
    end
    local coords = type(RACE_ICON_TCOORDS) == "table" and RACE_ICON_TCOORDS[race:upper() .. "_" .. sex:upper()]
    if type(coords) == "table" and #coords >= 4 then
        tex:SetTexture(G.RACE_SHEET)
        tex:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
        return true
    end
    return false
end

---------------------------------------------------------------------------
-- The game itself (no drawing here)
---------------------------------------------------------------------------
function G:NewRound()
    self.y, self.vy = G.H / 2, 0
    self.clouds, self.riders, self.nets = {}, {}, {}
    self.nextCloud, self.nextRider = 1.2, 1.6
    self.cool, self.dazed, self.clock = 0, 0, 0
    self.gold, self.streak, self.grounded, self.fired, self.bumps = 0, 0, 0, 0, 0
    self.word, self.wordUntil = nil, nil
    self.round = true
end

function G:Say(text, seconds)
    self.word, self.wordUntil = text, (GetTime() or 0) + (seconds or 1.5)
end

function G:Flap()
    if self.state ~= "playing" then return false end
    self.vy = G.FLAP
    return true
end

function G:Fire()
    if self.state ~= "playing" or self.cool > 0 or self.dazed > 0 or #self.nets >= G.NETS then return false end
    self.nets[#self.nets + 1] = { x = G.X + G.YOU / 2, y = self.y, spin = 0 }
    self.cool = G.NET_EVERY
    self.fired = self.fired + 1
    return true
end

function G:Ground(r)
    r.down, r.fall = true, G.DROP
    self.streak = self.streak + 1
    self.grounded = self.grounded + 1
    local worth = math.min(G.WORTH, self.streak)
    self.gold = self.gold + worth
    local db = ns.db
    db.flightGold = (db.flightGold or 0) + worth
    if self.gold > (db.flightGameBest or 0) then db.flightGameBest = self.gold end
    self:Say(L["Grounded! +%d"]:format(worth))
end

function G:Bump(c)
    c.bumped = true
    self.dazed = G.DAZED
    self.bumps = self.bumps + 1
    if self.streak > 1 then self:Say(L["Into the clouds: the run ends"]) end
    self.streak = 0
end

function G:Step(dt)
    local calm = ns.Calm()
    self.clock = self.clock + dt
    -- you: a flap lifts, and it sinks again on its own; the lane's top and bottom only hold it in
    self.vy = math.max(-G.FALL, self.vy - G.GRAVITY * dt)
    self.y = self.y + self.vy * dt
    if self.y < G.EDGE then
        self.y, self.vy = G.EDGE, 0
    elseif self.y > G.H - G.EDGE then
        self.y, self.vy = G.H - G.EDGE, math.min(self.vy, 0)
    end
    self.cool = math.max(0, self.cool - dt)
    self.dazed = math.max(0, self.dazed - dt)
    -- the clouds drift by, a gap in each bank
    self.nextCloud = self.nextCloud - dt
    if self.nextCloud <= 0 then
        local half = G.GAP / 2
        self.clouds[#self.clouds + 1] = { x = G.W + G.CLOUD_W, gap = half + 6 + (G.H - G.GAP - 12) * Random() }
        self.nextCloud = G.EVERY
    end
    for i = #self.clouds, 1, -1 do
        local c = self.clouds[i]
        c.x = c.x - G.SPEED * dt
        if c.x < -G.CLOUD_W then
            table.remove(self.clouds, i)
        elseif not c.bumped and math.abs(c.x - G.X) < G.CLOUD_W / 2 + 7
            and math.abs(self.y - c.gap) > G.GAP / 2 - 7 then
            self:Bump(c)
        end
    end
    -- riders come the other way
    self.nextRider = self.nextRider - dt
    if self.nextRider <= 0 then
        self.nextRider = Between(G.RIDER_EVERY)
        if #self.riders < G.RIDERS then
            local who = G.Others()
            local race = who.races[math.floor(Random() * #who.races) + 1] or who.races[1]
            local mount = (race == "Scourge" and Random() < 0.5) and "bat" or who.mount
            local base = 14 + (G.H - 28) * Random()
            self.riders[#self.riders + 1] = { x = G.W + 12, y = base, base = base, speed = Between(G.RIDER_SPEED),
                race = race, female = Random() < 0.5, mount = mount, phase = Random() * 6.28 }
        end
    end
    for i = #self.riders, 1, -1 do
        local r = self.riders[i]
        if r.down then                              -- grounded: down under its parachute, drifting with the wind
            r.x = r.x - G.SPEED * dt
            r.y = r.y - r.fall * dt
            if r.y < -16 then table.remove(self.riders, i) end
        else
            r.x = r.x - r.speed * dt
            r.y = calm and r.base or (r.base + math.sin(self.clock * 1.6 + r.phase) * 6)
            if r.x < -14 then table.remove(self.riders, i) end
        end
    end
    -- nets fly ahead and catch the first rider they come to
    for i = #self.nets, 1, -1 do
        local n = self.nets[i]
        n.x = n.x + G.NET_SPEED * dt
        n.spin = n.spin + dt * 6
        local caught
        for _, r in ipairs(self.riders) do
            if not r.down and math.abs(r.x - n.x) < G.HIT and math.abs(r.y - n.y) < G.HIT then caught = r; break end
        end
        if caught then
            table.remove(self.nets, i)
            self:Ground(caught)
        elseif n.x > G.W + 10 then
            table.remove(self.nets, i)
        end
    end
end

---------------------------------------------------------------------------
-- Its buttons: bound only while it is played; one button while it is offered or away at high altitude
---------------------------------------------------------------------------
local playKeys, startKey
local function Keys()
    if playKeys then return end
    playKeys = ns.PadKeys("FlightGame", G.KEYS, function(key) G:Pad(key) end, function() G:Pause("fight") end)
    startKey = ns.PadKeys("FlightStart", { G.START }, function() G:Toggle() end)
end

function G:Pad(key)
    if key == "PAD1" then self:Flap()
    elseif key == "PAD3" then self:Fire()
    elseif key == "PAD4" then self:Toggle()
    end
end

-- What is bound, set to what the moment wants (what is let go of first, then what is taken)
G.bound = "none"
function G:Bind()
    Keys()
    local want = "none"
    if self.active and not InCombatLockdown() and G.Flying() then
        if self.state == "playing" then want = "play"
        elseif self.state == "offered" or self.state == "paused" then want = "start" end
    end
    if want == self.bound then return end
    if want ~= "play" then playKeys:Set(false) end
    if want ~= "start" then startKey:Set(false) end
    if want == "play" then playKeys:Set(true) elseif want == "start" then startKey:Set(true) end
    self.bound = want
end

---------------------------------------------------------------------------
-- Under the flight bar
---------------------------------------------------------------------------
local frame, hint

local function Letter(key) return ns.PadIcons and ns.PadIcons.Letter and ns.PadIcons.Letter(key) or nil end
local function KeyText(key)
    local letter = Letter(key)
    if letter then return "|cffffffff" .. letter .. "|r" end
    local text = GetBindingText and GetBindingText(key) or key
    return (type(text) == "string" and text ~= "") and text or key
end
G.KeyText = KeyText

local function Tex(parent, layer, sub, path)
    local t = parent:CreateTexture(nil, layer, nil, sub)
    if path then t:SetTexture(path) end
    return t
end

-- Under the flight bar's own lines
local function Anchor(f, below)
    local bar = ns.Flights and ns.Flights.frame and ns.Flights.frame.bar
    f:ClearAllPoints()
    if bar then f:SetPoint("TOP", bar, "BOTTOM", 0, below)
    else f:SetPoint("TOP", UIParent, "TOP", 0, -150) end
end

local function Build()
    frame = CreateFrame("Frame", "ControllerCamHUD_FlightGameLane", UIParent)
    frame:SetSize(G.W, G.H)
    frame:SetFrameStrata("MEDIUM")
    if frame.SetClipsChildren then pcall(frame.SetClipsChildren, frame, true) end
    Anchor(frame, -38)
    local back = Tex(frame, "BACKGROUND", -2, ns.media.soft)         -- a soft dark sky, no box
    back:SetVertexColor(0.02, 0.05, 0.1, 0.6)
    back:SetPoint("TOPLEFT", frame, "TOPLEFT", -20, 8)
    back:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 20, -22)
    frame.back = back
    G.cloudTex = {}
    for i = 1, 4 do                                                    -- banks of clouds: a body and a puff, above
        local set = {}                                                 -- the gap and below it
        for j = 1, 4 do
            local t = Tex(frame, "BORDER", j % 2, ns.media.soft)
            t:SetVertexColor(0.92, 0.95, 1, j % 2 == 1 and 0.42 or 0.5)
            t:Hide()
            set[j] = t
        end
        G.cloudTex[i] = set
    end
    G.riderTex = {}
    for i = 1, G.RIDERS do
        local r = {}
        r.mount = Tex(frame, "ARTWORK", 1)
        r.mount:SetSize(G.RIDER, G.RIDER)
        r.mount:SetTexCoord(0.9, 0.1, 0.1, 0.9)                        -- (facing the other way; the icon's frame off)
        r.face = Tex(frame, "ARTWORK", 3)
        r.face:SetSize(12, 12)
        r.chute = Tex(frame, "ARTWORK", 0, ns.media.halo)              -- a small parachute, once grounded
        r.chute:SetSize(22, 12)
        r.chute:SetVertexColor(1, 0.95, 0.85, 0.85)
        r.net = Tex(frame, "OVERLAY", 0, ns.media.ring)                -- and the net round it
        r.net:SetSize(G.RIDER + 6, G.RIDER + 6)
        r.net:SetVertexColor(0.85, 0.9, 1, 0.9)
        for _, t in pairs(r) do t:Hide() end
        G.riderTex[i] = r
    end
    G.netTex = {}
    for i = 1, G.NETS do
        local t = Tex(frame, "OVERLAY", 1, ns.media.ring)
        t:SetSize(10, 10)
        t:SetVertexColor(0.85, 0.92, 1, 0.95)
        t:Hide()
        G.netTex[i] = t
    end
    local you = Tex(frame, "ARTWORK", 4)                               -- your mount, cut round, in a thin gold ring
    you:SetSize(G.YOU, G.YOU)
    you:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    if frame.CreateMaskTexture then
        pcall(function()
            local mask = frame:CreateMaskTexture()
            mask:SetTexture(ns.media.disc, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            mask:SetAllPoints(you)
            you:AddMaskTexture(mask)
        end)
    end
    frame.you = you
    local ring = Tex(frame, "ARTWORK", 5, ns.media.ring)
    ring:SetVertexColor(1, 0.84, 0.45, 0.95)
    ring:SetPoint("TOPLEFT", you, "TOPLEFT", -2, 2)
    ring:SetPoint("BOTTOMRIGHT", you, "BOTTOMRIGHT", 2, -2)
    frame.ring = ring
    frame.score = ns.FontString(frame, 10, "RIGHT")                    -- flight gold, small, in a corner
    frame.score:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -3)
    frame.score:SetTextColor(unpack(C.caution))
    frame.word = ns.FontString(frame, 10, "CENTER")                    -- what just happened
    frame.word:SetPoint("TOP", frame, "TOP", 0, -3)
    frame.word:SetTextColor(unpack(C.text))
    frame.help = ns.FontString(frame, 9, "CENTER")                     -- how it is played, under the lane
    frame.help:SetPoint("TOP", frame, "BOTTOM", 0, -4)
    frame.help:SetTextColor(unpack(C.muted))
    frame:Hide()
    G.frame = frame
    -- the one line while it is offered, or away at high altitude
    hint = CreateFrame("Frame", "ControllerCamHUD_FlightGameHint", UIParent)
    hint:SetSize(G.W, 14)
    hint:SetFrameStrata("MEDIUM")
    Anchor(hint, -36)
    hint.text = ns.FontString(hint, 9, "LEFT")
    hint.text:SetPoint("LEFT", hint, "LEFT", 0, 0)
    hint.text:SetTextColor(unpack(C.muted))
    hint:Hide()
    G.hint = hint
end

-- Things come into the lane at its right and leave at its left: faded at the edges (in case the game does not
-- clip what we draw to the lane)
local function Edge(x, w)
    return ns.Clamp(math.min((G.W + w / 2 - x) / w, (x + w / 2) / w), 0, 1)
end

local function At(t, x, y)
    t:ClearAllPoints()
    t:SetPoint("CENTER", frame, "BOTTOMLEFT", x, y)
end

function G:Draw(now)
    if not frame then return end
    local calm = ns.Calm()
    local fl = ns.Flights and ns.Flights.flight
    local kind = fl and fl.mount or "gryphon"
    if frame.youKind ~= kind then
        frame.you:SetTexture(ns.Flights.MOUNTS[kind] or ns.Flights.MOUNTS.gryphon)
        frame.youKind = kind
    end
    At(frame.you, G.X, self.y)
    if frame.you.SetRotation then
        pcall(frame.you.SetRotation, frame.you, calm and 0 or ns.Clamp(self.vy / 400, -0.35, 0.3))
    end
    local fog = self.dazed > 0 and (calm and 0.55 or (0.45 + 0.35 * math.abs(math.sin(now * 10)))) or 1
    frame.you:SetAlpha(fog)
    frame.ring:SetAlpha(fog)
    -- clouds
    for i, set in ipairs(G.cloudTex) do
        local c = self.clouds[i]
        if c then
            local a = Edge(c.x, G.CLOUD_W)
            local top = G.H - (c.gap + G.GAP / 2)
            local low = c.gap - G.GAP / 2
            set[1]:ClearAllPoints()
            set[1]:SetPoint("TOP", frame, "TOPLEFT", c.x, 6)
            set[1]:SetSize(G.CLOUD_W, math.max(1, top + 6))
            set[2]:SetSize(G.CLOUD_W + 12, 18)
            At(set[2], c.x, c.gap + G.GAP / 2 + 2)
            set[3]:ClearAllPoints()
            set[3]:SetPoint("BOTTOM", frame, "BOTTOMLEFT", c.x, -6)
            set[3]:SetSize(G.CLOUD_W, math.max(1, low + 6))
            set[4]:SetSize(G.CLOUD_W + 12, 18)
            At(set[4], c.x, c.gap - G.GAP / 2 - 2)
            for _, t in ipairs(set) do
                t:SetAlpha(a)
                if a > 0 then t:Show() else t:Hide() end
            end
        else
            for _, t in ipairs(set) do t:Hide() end
        end
    end
    -- riders
    for i, rt in ipairs(G.riderTex) do
        local r = self.riders[i]
        if r and Edge(r.x, G.RIDER) > 0 then
            local a = Edge(r.x, G.RIDER)
            if rt.mountKind ~= r.mount then
                rt.mount:SetTexture(ns.Flights.MOUNTS[r.mount] or ns.Flights.MOUNTS.gryphon)
                rt.mountKind = r.mount
            end
            if rt.race ~= r.race or rt.female ~= r.female then
                rt.hasFace = G.Face(rt.face, r.race, r.female)
                rt.race, rt.female = r.race, r.female
            end
            At(rt.mount, r.x, r.y)
            At(rt.face, r.x - 5, r.y + 8)
            rt.mount:SetAlpha(a * (r.down and 0.8 or 1))
            rt.face:SetAlpha(a)
            rt.mount:Show()
            if rt.hasFace then rt.face:Show() else rt.face:Hide() end
            if r.down then
                local sway = calm and 0 or math.sin(now * 3 + r.phase) * 2
                At(rt.chute, r.x + sway, r.y + 17)
                At(rt.net, r.x, r.y)
                rt.chute:SetAlpha(a)
                rt.net:SetAlpha(a)
                rt.chute:Show()
                rt.net:Show()
            else
                rt.chute:Hide()
                rt.net:Hide()
            end
        else
            for _, t in pairs({ rt.mount, rt.face, rt.chute, rt.net }) do t:Hide() end
        end
    end
    -- nets
    for i, t in ipairs(G.netTex) do
        local n = self.nets[i]
        if n then
            At(t, n.x, n.y)
            if t.SetRotation and not calm then pcall(t.SetRotation, t, n.spin) end
            t:Show()
        else
            t:Hide()
        end
    end
    frame.score:SetText(L["%d flight gold"]:format(self.gold))
    if self.wordUntil and now < self.wordUntil then
        frame.word:SetText(self.word)
        frame.word:Show()
    else
        frame.word:Hide()
    end
    frame.help:SetText(("%s   %s   %s"):format(L["%s flap"]:format(KeyText("PAD1")), L["%s net"]:format(KeyText("PAD3")),
        L["%s high altitude"]:format(KeyText("PAD4"))))
end

-- What shows: the lane while it is played, the one line while it is offered or away
function G:Show()
    local flying = self.active and G.Flying()
    local lane = flying and self.state == "playing"
    local line = flying and (self.state == "offered" or self.state == "paused") and not InCombatLockdown()
    if not frame and not (lane or line) then return end
    if not frame then Build() end
    if lane then
        Anchor(frame, -38)
        if ns.db.textShade ~= false then frame.back:Show() else frame.back:Hide() end
        frame:Show()
    else
        frame:Hide()
    end
    if line then
        Anchor(hint, -36)
        local text
        if self.state == "paused" then
            text = L["%s: back to the game (%d flight gold)"]:format(KeyText(G.START), self.gold)
        else
            text = L["%s: a game on the way"]:format(KeyText(G.START))
        end
        hint.text:SetText(text)
        hint:Show()
    else
        hint:Hide()
    end
end

---------------------------------------------------------------------------
-- Offered, played, at high altitude, put away
---------------------------------------------------------------------------
function G:Play()
    if not (self.active and G.Flying()) or InCombatLockdown() then return false end
    if not self.round then self:NewRound() end
    self.state = "playing"
    self:Bind()
    self:Show()
    self:Draw(GetTime())
    ns.Note("flight game: playing (flight gold %d)", self.gold)
    return true
end

function G:Pause(why)
    if self.state ~= "playing" then return false end
    self.state = "paused"
    self:Bind()
    self:Show()
    ns.Note("flight game: high altitude (%s)", tostring(why or "you"))
    return true
end

function G:Toggle()
    if self.state == "playing" then return self:Pause("you") end
    return self:Play()
end

-- Off the flight (landed, the option off, the HUD stopped): everything given back, the round over
function G:Stop(why)
    local was = self.state
    self.state = "off"
    self:Bind()
    if frame then frame:Hide() end
    if hint then hint:Hide() end
    self.shownFor = nil                                       -- (the next flight shows its line afresh)
    if was ~= "off" then
        if self.round and self.grounded > 0 then
            ns.Note("flight game: over (%s), %d grounded, flight gold %d", tostring(why), self.grounded, self.gold)
        end
        self.round = false
    end
end

-- Every frame: a flight begins (offered), ends (put away), a fight comes (high altitude); the game moves on
function G:Tick(dt)
    local flying = G.Flying() and not ns.arranging
    if not flying then
        if self.state ~= "off" then self:Stop("landed") end
        return
    end
    if self.state == "off" then
        self.state = "offered"
        self.round = false
    end
    if self.state == "playing" and InCombatLockdown() then self:Pause("fight") end
    self:Bind()
    if self.state == "playing" then
        self:Step(math.min(dt, 0.1))
        if frame and not frame:IsShown() then self:Show() end
        self:Draw(GetTime())
    elseif self.shownFor ~= self.state .. tostring(InCombatLockdown()) then
        self:Show()
    end
    self.shownFor = self.state .. tostring(InCombatLockdown())
end

local driver = CreateFrame("Frame")
local Tick = ns.Protect(function(_, dt) G:Tick(dt or 0) end)
local events = CreateFrame("Frame")
events:SetScript("OnEvent", ns.Protect(function()
    if G.active then G:Tick(0) end                            -- (landed or lost control: looked at at once)
end))

function G:Apply(run)
    self.active = run and ns.db.flightGame and true or false
    if self.active then
        driver:SetScript("OnUpdate", Tick)
        pcall(events.RegisterEvent, events, "PLAYER_CONTROL_GAINED")
        pcall(events.RegisterEvent, events, "PLAYER_REGEN_ENABLED")
    else
        driver:SetScript("OnUpdate", nil)
        events:UnregisterAllEvents()
        self:Stop("off")
    end
    self.shownFor = nil
end

---------------------------------------------------------------------------
-- A key binding, a command, the debug report
---------------------------------------------------------------------------
function G.Command()
    if not G.active then
        ns.Say(L["The flight game is off: /cchud flightgame on"])
    elseif not G.Flying() then
        ns.Say(L["The flight game is played on a flight."])
    elseif InCombatLockdown() then
        ns.Say(L["Not in a fight."])
    else
        G:Toggle()
    end
end

local Command = ns.Protect(function() G.Command() end)
function ControllerCamHUD_FlightGame() Command() end
BINDING_NAME_CCHUD_FLIGHTGAME = L["Flight game: play / high altitude"]

ns.RegisterCommand("flightplay", function() G.Command() end, "/cchud flightplay",
    "on a flight: start the flight game, or take it to high altitude and back")

function G.Describe()
    return ("on %s, %s, buttons %s, flight gold now %d (all %d, best %d), grounded %d, nets %d, clouds %d"):format(
        tostring(G.active), G.state, G.bound, G.gold or 0, ns.db and ns.db.flightGold or 0,
        ns.db and ns.db.flightGameBest or 0, G.grounded or 0, G.fired or 0, G.bumps or 0)
end

ns.RegisterModule("flightgame", G)
