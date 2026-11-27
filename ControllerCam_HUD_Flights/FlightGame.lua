-- ControllerCam HUD: a game on the way, played while a flight master's mount carries you (Flights.lua shows the
-- flight bar at the top of the screen). The game is played in the middle of the screen, over you on your mount,
-- so the names of the zones you fly into (the game's own, high in the middle) stay in sight above it.
--   * On a flight it is offered, not started: one line under the flight bar says which button starts it (and
--     your best on this route, and the flight gold you have to spend), and that one button is the only one taken
--     until you press it. An option turns it off altogether.
--   * Playing: your mount (the same one the flight bar shows) flies a lane of open sky. A flaps it up and it
--     sinks again on its own. Treetops rise from below and zeppelins drift past at all heights (mostly the
--     goblins', now and then the Horde's or the Alliance's, the factions' with the game's own badge), sometimes a
--     treetop with a zeppelin over it and a gap between; how tall, how big, how wide the gap and how far apart all
--     vary. Clouds drift behind as scenery only.
--   * Riders of the other side come the other way (the game's own portraits of their peoples, on their mounts).
--     X fires a net: a rider it catches is grounded, never slain, and floats down under a parachute. Each is
--     worth flight gold, more for a run of catches. Some riders throw a net at you.
--   * Lives and rounds: a bump, a net on you or a drake's fire costs a life, and a moment's grace follows (you
--     blink). Each round is a stretch of open sky and then something to get through, in turn: one of your side's
--     zeppelins crossing while the other side's riders net at it; one of their zeppelins coming in, its nets
--     thrown straight, in a fan, curving or weaving; a drake breathing a sweep of fire and curving fireballs.
--     Getting through clears the round: its gold is banked and a life comes back. Out of lives you are shot down:
--     the round's gold is lost (what was banked stays yours), and A starts again from round one. Each round is a
--     little harder than the last.
--   * Upgrades for flight gold, kept from flight to flight: LB chooses one, RB buys it, and the line under the
--     lane says what it does in numbers (the net's reach, nets at once, lives); the nets drawn grow with their
--     reach. What you earned, what you spent and what was lost when shot down are kept apart.
--   * Your best on each route (from > to, as the flight bar knows it) is kept: /cchud flightscores lists them.
--   * How it is played shows under the lane as a run starts (and briefly when it comes back), then the buttons
--     and the upgrade on offer stay there.
--   * Y again is high altitude: the game is put away (the flight bar stays) and every button is the game's
--     again, but the one that brings it back. A fight, the landing or the HUD stopping put it away at once.
-- Its buttons are bound with key bindings of its own only while it is played (ns.PadKeys), never in a fight,
-- and given back on landing. Nothing of the game's flight, map or buttons is touched. With fewer animations
-- the riders and zeppelins fly straight, the clouds behind stand still, the grounded drop straight down and
-- nothing tilts or spins. The treetop, zeppelins, drake and cloud are drawings of our own
-- (docs/make_flight_art.py); the fire is the HUD's own painted flame.
--
-- For later, not built yet: hazards (a goblin's parachuted dynamite you can set off and must fly clear of);
-- catching parachuting loot and goodies with your fishing line; a drake that dives across the lane.

local ADDON = ...
local ns = ControllerCamHUD.ns            -- the HUD's own namespace: this file is one of its modules (Modules.lua)
local L = ns.L
local C = ns.colors

local G = { state = "off", gold = 0, purse = 0, streak = 0, grounded = 0, fired = 0, bumps = 0, netted = 0,
            burned = 0, active = false, pick = 1, roundNo = 1, lives = 0, grace = 0 }
ns.FlightGame = G

local MEDIA = "Interface\\AddOns\\ControllerCam_HUD\\Media\\"
G.ART = { tree = MEDIA .. "treetop", zeppelin = MEDIA .. "zeppelin", cloud = MEDIA .. "cloud",
          Horde = MEDIA .. "zeppelin_horde", Alliance = MEDIA .. "zeppelin_alliance", drake = MEDIA .. "dragon" }
G.BADGE = { Alliance = "Interface\\TargetingFrame\\UI-PVP-Alliance", Horde = "Interface\\TargetingFrame\\UI-PVP-Horde" }

G.W, G.H = 300, 140                -- the lane, in its own units: as wide as the flight bar, and how tall
G.SCALE = 1.35                     -- drawn this much larger on the screen
G.Y = -24                          -- the lane's middle: this far under the middle of the screen (screen pixels), over
                                   -- you on your mount (the zone names the game shows high in the middle stay clear)
G.X = 48                           -- where your mount flies, from the lane's left
G.EDGE = 10                        -- your mount keeps this far from the lane's top and bottom
G.GRAVITY, G.FLAP, G.FALL = 240, 120, 160    -- how fast it sinks, how hard a flap lifts it, its fastest fall
G.SPEED = 44                       -- treetops (and the zeppelins with them) go by this fast (units a second)
G.SPACING = { 1.7, 3.6 }           -- the next treetop or zeppelin comes after this many seconds (between the two)
G.FIRST = 3                        -- the first one after this long: time to read how it is played
G.TREE = { 26, 80 }                -- how tall a treetop alone rises (its height in the lane)
G.ZEP_W = { 42, 72 }               -- how wide a zeppelin is (it is half as tall)
G.ZEP_Y = { 30, 118 }              -- where a zeppelin alone drifts (its middle)
G.PAIR = 0.35                      -- how often a treetop comes with a zeppelin over it
G.LONE_ZEP = 0.45                  -- otherwise, how often it is a zeppelin alone (else a treetop alone)
G.GAP = { 52, 76 }                 -- the gap between a treetop and the zeppelin over it
G.PAIR_TREE = { 22, 52 }           -- how tall the treetop under a zeppelin is
G.DRIFT = { 0, 14 }                -- a zeppelin alone drifts a little faster than the wind, by this much
G.NEUTRAL = 0.7                    -- most zeppelins drifting by are the goblins'; the rest the Horde's or the Alliance's
G.THINGS = 10                      -- treetops and zeppelins in the lane at once, at most
G.CLOUDS, G.CLOUD_SPEED = 3, 14    -- the clouds behind: how many, how fast they drift (scenery only)
G.INTRO, G.AGAIN = 7, 3            -- how long how it is played shows: as a run starts, and when it comes back
G.RIDER_EVERY = { 2.2, 4.2 }       -- a rider every this many seconds (between the two)
G.RIDER_SPEED = { 60, 80 }
G.RIDERS = 4                       -- riders in the lane at once, at most
G.SHOOTERS = 0.25                  -- how many riders throw a net at you as they pass
G.NET_SPEED, G.NET_EVERY, G.NETS = 190, 0.5, 3   -- a net's speed, how often one can be fired, how many fly at once
G.HIT = 13                         -- a net this close to a rider catches it
G.FOE_SPEED, G.FOE_HIT = 115, 11   -- the other side's nets: how fast, how close counts
G.CURVE = 150                      -- how hard a curving net or fireball bends on its way
G.WEAVE = 16                       -- how far a weaving net swings up and down
G.REACH = 7                        -- how close your mount (its middle) can come to a treetop or zeppelin: forgiving
G.DAZED = 1.2                      -- a hit fogs the net gun this long
G.DROP = 34                        -- a grounded rider floats down this fast
G.YOU, G.RIDER = 24, 18            -- sizes of your mount and a rider's
G.WORTH = 5                        -- a catch is worth 1 flight gold, one more for each in a run, up to this
-- Lives: a run starts with these (Thick harness: more); after a hit nothing hits you for a moment
G.LIVES, G.GRACE = 3, 1.6
G.DOWN_WAIT = 1.2                  -- shot down: A starts again after this long
-- Rounds: open sky for this long (the first, then each after), then the round's event, in turn
G.EVENT_FIRST, G.EVENT_EVERY = 30, 25
G.EVENTS = { "escort", "boss", "drake" }
G.HARDER, G.HARDEST = 0.15, 2      -- each round this much harder (more often, more of them), up to twice as hard
G.SHIP_W, G.SHIP_SPEED = 84, 22            -- your side's zeppelin: how wide, how fast it crosses
G.ESCORT_RIDERS = { 1.0, 1.8 }             -- riders come this often while it crosses
G.ESCORT_BONUS, G.ESCORT_LOSS = 12, 4      -- what seeing it across is worth, less this for each net on it
G.BOSS_W, G.BOSS_HP = 100, 8               -- their zeppelin: how wide, how many nets bring it down
G.BOSS_SHOT = { 1.4, 2.2 }                 -- it throws this often
G.PATTERNS = { "aimed", "lob", "fan", "wave" }   -- how: straight, curving, three in a fan, weaving (the first raid
                                                 -- of a run: the first three)
G.BOSS_TIME, G.BOSS_BONUS = 30, 25         -- it sails off after this long; bringing it down is worth this
G.DRAKE_W, G.DRAKE_HP = 90, 10             -- a drake: how wide, how many nets drive it off
G.DRAKE_EVERY = { 2.4, 3.4 }               -- between its attacks
G.DRAKE_INHALE = 0.8                       -- it draws breath first (its mouth glows): time to get clear
G.DRAKE_BREATH, G.DRAKE_SWEEP = 1.1, 36    -- a breath: this long, sweeping from this far above you to below (or up)
G.DRAKE_TIME, G.DRAKE_BONUS = 32, 30       -- it flies off after this long; driving it off is worth this
G.FIRE_SPEED, G.FIRE_HIT = 120, 8          -- its fire: how fast, how close counts
G.FIRES = 28                               -- fire in the lane at once, at most
-- Upgrades, kept from flight to flight: three levels each, at these prices
G.UPGRADES = {
    { key = "net", label = "Wider net", tip = "catches riders from further away", cost = { 40, 80, 160 } },
    { key = "reload", label = "Quick reload", tip = "fire again sooner, and one more net in the air", cost = { 40, 80, 160 } },
    { key = "harness", label = "Thick harness", tip = "one more life each run", cost = { 60, 120, 240 } },
}
G.KEYS = { "PAD1", "PAD3", "PAD4", "PADLSHOULDER", "PADRSHOULDER" }   -- A flap, X net, Y high altitude, LB, RB
G.START = "PAD4"                   -- the one button bound while the game is offered or away at high altitude

-- Flight gold: all you have earned, what you spent on upgrades, what was lost when shot down (what is left is
-- yours to spend), the most on one run, the best on each route ("From > To" -> gold), and the upgrades bought
local function Count(old)
    local n = tonumber(old)
    return (n and n >= 0) and math.floor(n) or 0
end
ns.RegisterSaved("flightGold", Count)
ns.RegisterSaved("flightGoldSpent", Count)
ns.RegisterSaved("flightGoldLost", Count)
ns.RegisterSaved("flightGameBest", Count)
ns.RegisterSaved("flightGameRoutes", function(old)
    local out = {}
    if type(old) ~= "table" then return out end
    for route, n in pairs(old) do
        if type(route) == "string" and tonumber(n) and tonumber(n) > 0 then out[route] = math.floor(tonumber(n)) end
    end
    return out
end)
ns.RegisterSaved("flightGameUpgrades", function(old)
    local out = {}
    for _, u in ipairs(G.UPGRADES) do
        local n = type(old) == "table" and tonumber(old[u.key]) or 0
        out[u.key] = math.max(0, math.min(#u.cost, math.floor(n or 0)))
    end
    return out
end)

local function Random() return (G.random or math.random)() end
local function Between(range) return range[1] + (range[2] - range[1]) * Random() end
local function Sign() return Random() < 0.5 and 1 or -1 end

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
-- Flight gold and upgrades
---------------------------------------------------------------------------
-- Yours to spend: what you earned, less what you spent and lost, less this round's gold (not banked yet)
function G.Wallet()
    local db = ns.db or {}
    return math.max(0, (db.flightGold or 0) - (db.flightGoldSpent or 0) - (db.flightGoldLost or 0) - (G.purse or 0))
end

function G.Level(key)
    local up = ns.db and ns.db.flightGameUpgrades
    return up and tonumber(up[key]) or 0
end

-- What each upgrade gives at a level: the net's reach, nets in the air at once, lives
function G.Value(key, lvl)
    if key == "net" then return G.HIT + 3 * lvl end
    if key == "reload" then return G.NETS + lvl end
    return G.LIVES + lvl
end

-- What the next level of it does, in numbers
function G.Effect(key, lvl)
    local a, b = G.Value(key, lvl), G.Value(key, lvl + 1)
    if key == "net" then return L["net reach %d to %d"]:format(a, b) end
    if key == "reload" then return L["%d to %d nets at once"]:format(a, b) end
    return L["%d to %d lives"]:format(a, b)
end

function G.Hit() return G.Value("net", G.Level("net")) end
function G.Nets() return G.Value("reload", G.Level("reload")) end
function G.Reload() return G.NET_EVERY - 0.08 * G.Level("reload") end
function G.Lives() return G.Value("harness", G.Level("harness")) end

-- The route this flight flies ("From > To"), when both ends are known
function G.Route()
    local F = ns.Flights
    local fl = F and F.flight
    return fl and F.Route and F.Route(fl.from, fl.to) or nil
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

-- Your side and theirs ("Horde" or "Alliance"); a player of no side yet flies with the Horde against the Alliance
function G.Sides()
    local ok, faction = false, nil
    if type(UnitFactionGroup) == "function" then ok, faction = pcall(UnitFactionGroup, "player") end
    faction = ok and Plain(faction) or nil
    if faction == "Alliance" then return "Alliance", "Horde" end
    return "Horde", "Alliance"
end

function G.Others()
    local _, theirs = G.Sides()
    return G.PEOPLES[theirs]
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
-- The clouds behind: scenery, never in the way
local function Cloud(x)
    return { x = x, y = G.H * (0.45 + 0.45 * Random()), w = 70 + 50 * Random() }
end

-- A new run: round one, every life, no gold yet
function G:NewRun()
    self.y, self.vy = G.H / 2, 0
    self.things, self.riders, self.nets, self.foes, self.fires = {}, {}, {}, {}, {}
    self.clouds = {}
    for i = 1, G.CLOUDS do self.clouds[i] = Cloud((i - 0.5) * (G.W / G.CLOUDS) + 30 * Random()) end
    self.nextThing, self.nextRider = G.FIRST, G.FIRST + 0.6
    self.phase, self.nextEvent, self.ship, self.boss, self.drake = "open", G.EVENT_FIRST, nil, nil, nil
    self.roundNo, self.lives, self.purse = 1, G.Lives(), 0
    self.cool, self.dazed, self.grace, self.clock, self.downAt = 0, 0, 0, 0, nil
    self.gold, self.streak, self.grounded, self.fired, self.bumps, self.netted, self.burned = 0, 0, 0, 0, 0, 0, 0
    self.word, self.wordUntil, self.banner, self.bannerUntil = nil, nil, nil, nil
    self.route = G.Route()
    self.routeBest = self.route and ns.db.flightGameRoutes[self.route] or 0
    self.toldBest = false
    self.started = true
end

function G:Say(text, seconds)
    self.word, self.wordUntil = text, (GetTime() or 0) + (seconds or 1.5)
end

-- Large, in the middle of the lane: a round cleared, shot down, a new run
function G:Banner(text, seconds)
    self.banner, self.bannerUntil = text, (GetTime() or 0) + (seconds or 2.5)
end

-- Each round a little harder than the last
function G:Hard()
    return math.min(G.HARDEST, 1 + G.HARDER * ((self.roundNo or 1) - 1))
end

-- Flight gold won: this run's, this round's (banked when the round is cleared), all you have earned, the best on
-- one run and on this route
function G:Earn(n)
    if n <= 0 then return end
    local db = ns.db
    self.gold = self.gold + n
    self.purse = (self.purse or 0) + n
    db.flightGold = (db.flightGold or 0) + n
    if self.gold > (db.flightGameBest or 0) then db.flightGameBest = self.gold end
    if self.route then
        local best = db.flightGameRoutes[self.route] or 0
        if self.gold > best then
            db.flightGameRoutes[self.route] = self.gold
            if best > 0 and not self.toldBest then
                self.toldBest = true
                self:Say(L["Your best on this route!"], 2.5)
                return true
            end
        end
    end
end

function G:Flap()
    if self.state ~= "playing" or self.phase == "down" then return false end
    self.vy = G.FLAP
    return true
end

function G:Fire()
    if self.state ~= "playing" or self.phase == "down" or self.cool > 0 or self.dazed > 0
            or #self.nets >= G.Nets() then
        return false
    end
    self.nets[#self.nets + 1] = { x = G.X + G.YOU / 2, y = self.y, spin = 0 }
    self.cool = G.Reload()
    self.fired = self.fired + 1
    return true
end

function G:Ground(r)
    r.down, r.fall = true, G.DROP
    self.streak = self.streak + 1
    self.grounded = self.grounded + 1
    local worth = math.min(G.WORTH, self.streak)
    if not self:Earn(worth) then self:Say(L["Grounded! +%d"]:format(worth)) end
end

-- Shot down: the round's gold is lost (what was banked stays yours); A starts again from round one
function G:ShotDown()
    local lost = self.purse or 0
    ns.db.flightGoldLost = (ns.db.flightGoldLost or 0) + lost
    self.purse, self.lost = 0, lost
    self.phase, self.downAt = "down", self.clock
    self.ship, self.boss, self.drake = nil, nil, nil
    self.foes, self.fires, self.nets = {}, {}, {}
    self.word, self.wordUntil = nil, nil
    self:Banner(lost > 0 and L["Shot down! %d unbanked gold lost"]:format(lost) or L["Shot down!"], 3)
    ns.Note("flight game: shot down in round %d, %d gold this run, %d lost", self.roundNo, self.gold, lost)
end

-- A hit: a bump, a net on you or fire. It costs a life (not while you blink after the last one) and fogs the net
-- gun a moment; the last life lost, you are shot down.
function G:Hurt(why)
    if self.grace > 0 or self.phase == "down" then return false end
    self.lives = self.lives - 1
    self.grace, self.dazed = G.GRACE, G.DAZED
    self.streak = 0
    if why == "bump" then self.bumps = self.bumps + 1
    elseif why == "net" then self.netted = self.netted + 1
    else self.burned = self.burned + 1 end
    if self.lives <= 0 then
        self.lives = 0
        self:ShotDown()
        return true
    end
    if why == "bump" then self:Say(L["Bumped! Lives left: %d"]:format(self.lives))
    elseif why == "net" then self:Say(L["Netted! Lives left: %d"]:format(self.lives))
    else self:Say(L["Scorched! Lives left: %d"]:format(self.lives)) end
    return true
end

-- Shot down, A again: a new run from round one (on the same flight, the same route)
function G:Again()
    if self.phase ~= "down" or self.clock - (self.downAt or 0) < G.DOWN_WAIT then return false end
    self:NewRun()
    self.nextThing, self.nextRider = 1.5, 2
    self:Banner(L["Round %d"]:format(1), 2)
    ns.Note("flight game: again")
    return true
end

-- The upgrades: LB chooses the next one (and says what it does), RB buys the one chosen
function G:Next()
    self.pick = self.pick % #G.UPGRADES + 1
    local u = G.UPGRADES[self.pick]
    local lvl = G.Level(u.key)
    local text = ("%s: %s"):format(L[u.label], L[u.tip])
    if lvl < #u.cost then text = ("%s (%s)"):format(text, G.Effect(u.key, lvl)) end
    self:Say(text, 3)
end

function G:Buy()
    local u = G.UPGRADES[self.pick]
    local lvl = G.Level(u.key)
    if lvl >= #u.cost then
        self:Say(L["%s is fully upgraded"]:format(L[u.label]), 2)
        return false
    end
    local cost, have = u.cost[lvl + 1], G.Wallet()
    if have < cost then
        self:Say(L["%d more flight gold for that"]:format(cost - have), 2)
        return false
    end
    local effect = G.Effect(u.key, lvl)
    ns.db.flightGoldSpent = (ns.db.flightGoldSpent or 0) + cost
    ns.db.flightGameUpgrades[u.key] = lvl + 1
    if u.key == "harness" and self.started and self.phase ~= "down" then self.lives = self.lives + 1 end   -- (now)
    self:Say(L["%s %d: %s"]:format(L[u.label], lvl + 1, effect), 3)
    ns.Note("flight game: bought %s %d for %d", u.key, lvl + 1, cost)
    return true
end

-- A treetop: { kind = "tree", x, top (how tall it rises), w }. Drawn as tall as it rises (its picture is twice as
-- tall as it is wide), so a taller one is a larger tree, not a stretched one.
local function Tree(x, top)
    return { kind = "tree", x = x, top = top, w = (top + 4) / 2 }
end
-- Whose zeppelin drifts by: mostly the goblins', now and then the Horde's or the Alliance's
local function Side()
    local r = Random()
    if r < G.NEUTRAL then return "neutral" end
    return r < G.NEUTRAL + (1 - G.NEUTRAL) / 2 and "Horde" or "Alliance"
end
-- A zeppelin: { kind = "zeppelin", side, x, y (the middle of its envelope), w, h, drift, base, phase }
local function Zeppelin(x, y, w, drift, side)
    return { kind = "zeppelin", side = side or Side(), x = x, y = y, base = y, w = w, h = w / 2, drift = drift,
             phase = Random() * 6.28 }
end

-- What comes next, and when: a treetop alone, a zeppelin alone, or a treetop with a zeppelin over it and a gap
-- to fly through. Each leaves a way past.
function G:Spawn()
    local r = Random()
    local at = G.W + 40
    if r < G.PAIR then
        local top = Between(G.PAIR_TREE)
        local w = Between(G.ZEP_W)
        local gap = Between(G.GAP)
        self.things[#self.things + 1] = Tree(at, top)
        self.things[#self.things + 1] = Zeppelin(at, top + gap + w / 2 * 0.3, w, 0)   -- (keeps pace: the gap stays)
    elseif r < G.PAIR + (1 - G.PAIR) * G.LONE_ZEP then
        self.things[#self.things + 1] = Zeppelin(at, Between(G.ZEP_Y), Between(G.ZEP_W), Between(G.DRIFT))
    else
        self.things[#self.things + 1] = Tree(at, Between(G.TREE))
    end
    while #self.things > G.THINGS do table.remove(self.things, 1) end
end

-- Is your mount (its middle at G.X, y) touching it? Forgiving: the canopy is taken narrower than drawn, the
-- zeppelin is its envelope only.
function G.Touches(t, y)
    local dx = math.abs(t.x - G.X)
    if t.kind == "tree" then
        return dx < t.w * 0.36 + G.REACH and y < t.top + G.REACH - 4
    end
    local a, b = t.w * 0.42 + G.REACH, t.h * 0.3 + G.REACH
    local dy = y - t.y
    return (dx / a) ^ 2 + (dy / b) ^ 2 < 1
end

-- Is this point on a zeppelin's envelope (or a drake's body)?
local function OnEnvelope(z, x, y, pad)
    local a, b = z.w * 0.45 + (pad or 0), z.h * 0.32 + (pad or 0)
    return ((x - z.x) / a) ^ 2 + ((y - z.y) / b) ^ 2 < 1
end

-- Something thrown left, from (x, y), that reaches the height ty as it reaches tx: straight, or bending on its
-- way (curve: how hard, up or down), or weaving up and down (weave: how far)
local function Shot(list, speed, x, y, tx, ty, curve, weave)
    local t = math.max(20, x - tx) / speed
    local ay = curve or 0
    local s = { x = x, y = y, cy = y, vx = speed, vy = (ty - y - 0.5 * ay * t * t) / t, ay = ay, amp = weave or 0,
                t = 0, spin = 0 }
    list[#list + 1] = s
    return s
end

-- A net of theirs, at you or at your side's zeppelin
local function Throw(self, x, y, tx, ty, at, curve, weave)
    Shot(self.foes, G.FOE_SPEED, x, y, tx, ty, curve, weave).at = at
end

-- Its way along: a little further left, bending or weaving as it was thrown
local function Fly(s, dt)
    s.t = (s.t or 0) + dt
    s.x = s.x - (s.vx or G.FOE_SPEED) * dt
    s.vy = (s.vy or 0) + (s.ay or 0) * dt
    s.cy = (s.cy or s.y) + s.vy * dt
    s.y = s.cy + (s.amp or 0) * math.sin(s.t * 7)
end

-- Their zeppelin throws: straight at you, curving, three in a fan, or weaving
local function Volley(self, b)
    local kind = G.PATTERNS[math.floor(Random() * b.patterns) + 1] or "aimed"
    local x, y = b.x - b.w * 0.4, b.y
    if kind == "fan" then
        for _, dy in ipairs({ -36, 0, 36 }) do Throw(self, x, y, G.X, self.y + dy, "you") end
    elseif kind == "lob" then
        Throw(self, x, y, G.X, self.y, "you", Sign() * G.CURVE)
    elseif kind == "wave" then
        Throw(self, x, y, G.X, self.y, "you", 0, G.WEAVE)
    else
        Throw(self, x, y, G.X, self.y, "you")
    end
    b.last = kind
end

-- The drake's mouth (its head is at its left)
local function Mouth(d)
    return d.x - d.w * 0.46, d.y + d.h * 0.08
end

-- Something to get through, ending each round: an escort, a raid, a drake, in turn
function G:BeginEvent(kind)
    kind = kind or G.EVENTS[((self.roundNo or 1) - 1) % #G.EVENTS + 1]
    local mine, theirs = G.Sides()
    local cycle = math.floor(((self.roundNo or 1) - 1) / #G.EVENTS)       -- (each time round, a tougher one)
    if kind == "escort" then
        local w = G.SHIP_W
        self.ship = { kind = "zeppelin", side = mine, x = G.W + w / 2, y = G.H * 0.62, base = G.H * 0.62, w = w,
                      h = w / 2, hits = 0, phase = 0 }
        self.phase = "escort"
        self.nextRider = 0.8
        self:Say(L["Your side's zeppelin: keep their nets off it!"], 3)
    elseif kind == "boss" then
        local w = G.BOSS_W
        local hp = G.BOSS_HP + 3 * cycle
        self.boss = { kind = "zeppelin", side = theirs, x = G.W + w / 2, y = G.H / 2, w = w, h = w / 2,
                      hp = hp, full = hp, shot = 2.5, time = 0, patterns = cycle > 0 and #G.PATTERNS or 3 }
        self.phase = "boss"
        self:Say(L["Their zeppelin: net it down before it nets you!"], 3)
    else
        local w = G.DRAKE_W
        local hp = G.DRAKE_HP + 3 * cycle
        self.drake = { x = G.W + w / 2, y = G.H / 2, w = w, h = w / 2, hp = hp, full = hp, time = 0, wait = 2.2,
                       attacks = 0 }
        self.phase = "drake"
        self:Say(L["A drake! Dodge its fire, and net it to drive it off"], 3)
    end
end

-- The round's event is over: the round is cleared, its gold banked, a life back, and on to the next
function G:EndEvent(text)
    self.phase, self.ship, self.boss, self.drake = "open", nil, nil, nil
    self.nextEvent = G.EVENT_EVERY
    self.nextThing = math.max(self.nextThing, 1.2)
    local banked = self.purse or 0
    self.purse = 0
    self.lives = math.min(math.max(G.Lives(), self.lives), self.lives + 1)
    if text then self:Say(text, 3) end
    self:Banner(L["Round %d cleared: %d gold banked"]:format(self.roundNo, banked), 3)
    ns.Note("flight game: round %d cleared, %d banked", self.roundNo, banked)
    self.roundNo = self.roundNo + 1
end

-- The drake: comes in, draws breath (its mouth glows), then breathes a sweep of fire across where you were, or
-- throws two fireballs that curve in on you; it flies off in the end, or sooner when netted enough
local function StepDrake(self, d, dt, hard)
    d.time = d.time + dt
    if d.fled then
        d.x, d.y = d.x + 70 * dt, d.y + 45 * dt
        if d.y > G.H + d.h then self:EndEvent() end
        return
    end
    if d.time > G.DRAKE_TIME and not d.breath then d.leaving, d.inhale = true, nil end
    if d.leaving then
        d.x, d.y = d.x + 60 * dt, d.y + 20 * dt
        if d.x > G.W + d.w then self:EndEvent(L["The drake flies off"]) end
        return
    end
    d.x = math.max(G.W - 56, d.x - 45 * dt)
    if not (d.inhale or d.breath) then d.y = G.H / 2 + math.sin(d.time * 0.6) * (G.H / 2 - 36) end
    local mx, my = Mouth(d)
    if d.inhale then
        d.inhale = d.inhale - dt
        if d.inhale <= 0 then
            d.inhale = nil
            if d.attacks % 2 == 1 then                       -- a breath, sweeping across where you were
                d.breath, d.puff = G.DRAKE_BREATH, 0
                d.from, d.to = d.aim + d.dir * G.DRAKE_SWEEP, d.aim - d.dir * G.DRAKE_SWEEP
            else                                             -- two fireballs, bending in from above and below
                for _, way in ipairs({ 1, -1 }) do
                    Shot(self.fires, G.FIRE_SPEED * 0.85, mx, my, G.X, self.y, way * G.CURVE).big = true
                end
                d.wait = Between(G.DRAKE_EVERY) / hard
            end
        end
    elseif d.breath then
        d.breath = d.breath - dt
        d.puff = d.puff - dt
        while d.puff <= 0 do
            local p = 1 - math.max(0, d.breath) / G.DRAKE_BREATH
            if #self.fires < G.FIRES then Shot(self.fires, G.FIRE_SPEED, mx, my, G.X, d.from + (d.to - d.from) * p) end
            d.puff = d.puff + 0.06
        end
        if d.breath <= 0 then
            d.breath = nil
            d.wait = Between(G.DRAKE_EVERY) / hard
        end
    elseif d.x <= G.W - 54 then
        d.wait = d.wait - dt
        if d.wait <= 0 then
            d.attacks = d.attacks + 1
            d.inhale, d.aim, d.dir = G.DRAKE_INHALE, self.y, Sign()
        end
    end
end

function G:Step(dt)
    local calm = ns.Calm()
    local down = self.phase == "down"
    local hard = self:Hard()
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
    self.grace = math.max(0, self.grace - dt)
    -- the clouds behind drift slowly (and stand still with fewer animations)
    if not calm then
        for i, c in ipairs(self.clouds) do
            c.x = c.x - G.CLOUD_SPEED * dt
            if c.x < -c.w / 2 then self.clouds[i] = Cloud(G.W + c.w / 2 + 20 * Random()) end
        end
    end
    -- open sky for a while, then the round's event
    if self.phase == "open" then
        self.nextEvent = self.nextEvent - dt
        if self.nextEvent <= 0 then self:BeginEvent() end
    end
    -- treetops and zeppelins come by (not while something is happening), more often round by round
    if self.phase == "open" then
        self.nextThing = self.nextThing - dt
        if self.nextThing <= 0 then
            self:Spawn()
            self.nextThing = Between(G.SPACING) / math.sqrt(hard)
        end
    end
    for i = #self.things, 1, -1 do
        local t = self.things[i]
        t.x = t.x - (G.SPEED + (t.drift or 0)) * dt
        if t.kind == "zeppelin" then
            t.y = calm and t.base or (t.base + math.sin(self.clock * 1.1 + t.phase) * (t.drift > 0 and 4 or 0))
        end
        if t.x < -t.w then
            table.remove(self.things, i)
        elseif not t.bumped and not down and G.Touches(t, self.y) then
            t.bumped = true
            self:Hurt("bump")
        end
    end
    -- your side's zeppelin crosses slowly
    local ship = self.ship
    if ship then
        ship.x = ship.x - G.SHIP_SPEED * dt
        ship.y = calm and ship.base or (ship.base + math.sin(self.clock * 0.9) * 3)
        if ship.x < -ship.w / 2 then
            local bonus = math.max(0, G.ESCORT_BONUS - G.ESCORT_LOSS * ship.hits)
            self:Earn(bonus)
            self:EndEvent(bonus > 0 and L["Seen safely across: +%d"]:format(bonus) or L["It made it across, tangled"])
        end
    end
    -- their zeppelin comes in, throws at you, and sails off in the end (or goes down under its parachutes)
    local boss = self.boss
    if boss then
        boss.time = boss.time + dt
        if boss.down then
            boss.x, boss.y = boss.x - G.SPEED * 0.5 * dt, boss.y - 22 * dt
            if boss.y < -boss.h then self:EndEvent() end
        elseif boss.time > G.BOSS_TIME then
            boss.x, boss.y = boss.x + 50 * dt, boss.y + 16 * dt
            if boss.x > G.W + boss.w then self:EndEvent(L["Their zeppelin sails off"]) end
        else
            boss.x = math.max(G.W - 64, boss.x - 40 * dt)
            boss.y = G.H / 2 + math.sin(boss.time * 0.7) * (G.H / 2 - 36)
            boss.shot = boss.shot - dt
            if boss.shot <= 0 and boss.x <= G.W - 60 then
                Volley(self, boss)
                boss.shot = Between(G.BOSS_SHOT) / hard
            end
        end
    end
    if self.drake then StepDrake(self, self.drake, dt, hard) end
    -- riders come the other way (more of them while your side's zeppelin crosses, none in a raid or with a drake)
    if self.phase == "open" or self.phase == "escort" then
        self.nextRider = self.nextRider - dt
        if self.nextRider <= 0 then
            self.nextRider = Between(self.phase == "escort" and G.ESCORT_RIDERS or G.RIDER_EVERY) / hard
            if #self.riders < G.RIDERS then
                local who = G.Others()
                local race = who.races[math.floor(Random() * #who.races) + 1] or who.races[1]
                local mount = (race == "Scourge" and Random() < 0.5) and "bat" or who.mount
                local base = 16 + (G.H - 32) * Random()
                self.riders[#self.riders + 1] = { x = G.W + 12, y = base, base = base, speed = Between(G.RIDER_SPEED),
                    race = race, female = Random() < 0.5, mount = mount, phase = Random() * 6.28,
                    shooter = Random() < G.SHOOTERS * hard }
            end
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
            if not r.threw and not down then        -- a net at your side's zeppelin, or at you
                if ship and r.x > ship.x and r.x - ship.x < 120 then
                    r.threw = true
                    Throw(self, r.x - 8, r.y, ship.x, ship.y, "ship")
                elseif r.shooter and r.x - G.X < 150 and r.x - G.X > 60 then
                    r.threw = true                  -- (from the third round some of them curve)
                    local curve = (self.roundNo >= 3 and Random() < 0.4) and Sign() * G.CURVE * 0.7 or nil
                    Throw(self, r.x - 8, r.y, G.X, self.y, "you", curve)
                end
            end
            if r.x < -14 then table.remove(self.riders, i) end
        end
    end
    -- their nets fly left: on you they cost a life, on your side's zeppelin they cost the escort's reward
    for i = #self.foes, 1, -1 do
        local f = self.foes[i]
        Fly(f, dt)
        f.spin = f.spin + dt * 5
        if not down and self.grace <= 0 and math.abs(f.x - G.X) < G.FOE_HIT and math.abs(f.y - self.y) < G.FOE_HIT then
            table.remove(self.foes, i)
            self:Hurt("net")
            if self.phase == "down" then break end          -- (shot down: every net is gone)
        elseif ship and f.at == "ship" and OnEnvelope(ship, f.x, f.y) then
            table.remove(self.foes, i)
            ship.hits = ship.hits + 1
            self:Say(L["A net on your side's zeppelin"])
        elseif f.x < -10 or f.y < -10 or f.y > G.H + 10 then
            table.remove(self.foes, i)
        end
    end
    if self.phase == "down" then down = true end          -- (shot down just now)
    -- the drake's fire: nothing stops it but getting out of the way
    for i = #self.fires, 1, -1 do
        local f = self.fires[i]
        Fly(f, dt)
        local reach = f.big and G.FIRE_HIT + 2 or G.FIRE_HIT
        if not down and self.grace <= 0 and (f.x - G.X) ^ 2 + (f.y - self.y) ^ 2 < reach * reach then
            table.remove(self.fires, i)
            self:Hurt("fire")
            if self.phase == "down" then break end          -- (shot down: the fire is gone)
        elseif f.x < -10 or f.y < -14 or f.y > G.H + 14 then
            table.remove(self.fires, i)
        end
    end
    -- your nets fly ahead: a rider, a net of theirs, their zeppelin or the drake
    local reach = G.Hit()
    local drake = self.drake
    for i = #self.nets, 1, -1 do
        local n = self.nets[i]
        n.x = n.x + G.NET_SPEED * dt
        n.spin = n.spin + dt * 6
        local done = false
        for _, r in ipairs(self.riders) do
            if not r.down and math.abs(r.x - n.x) < reach and math.abs(r.y - n.y) < reach then
                self:Ground(r)
                done = true
                break
            end
        end
        if not done then
            for j, f in ipairs(self.foes) do
                if math.abs(f.x - n.x) < G.FOE_HIT + 2 and math.abs(f.y - n.y) < G.FOE_HIT + 2 then
                    table.remove(self.foes, j)
                    done = true
                    break
                end
            end
        end
        if not done and boss and not boss.down and boss.time <= G.BOSS_TIME and OnEnvelope(boss, n.x, n.y) then
            done = true
            boss.hp = boss.hp - 1
            if boss.hp <= 0 then
                boss.down = true
                self.foes = {}
                if not self:Earn(G.BOSS_BONUS) then self:Say(L["Their zeppelin is down! +%d"]:format(G.BOSS_BONUS), 3) end
            end
        end
        if not done and drake and not drake.fled and not drake.leaving and OnEnvelope(drake, n.x, n.y) then
            done = true
            drake.hp = drake.hp - 1
            if drake.hp <= 0 then
                drake.fled, drake.inhale, drake.breath = true, nil, nil
                if not self:Earn(G.DRAKE_BONUS) then self:Say(L["The drake flees! +%d"]:format(G.DRAKE_BONUS), 3) end
            end
        end
        if done or n.x > G.W + 10 then table.remove(self.nets, i) end
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
    if key == "PAD1" then
        if self.phase == "down" then self:Again() else self:Flap() end
    elseif key == "PAD3" then self:Fire()
    elseif key == "PAD4" then self:Toggle()
    elseif key == "PADLSHOULDER" then self:Next()
    elseif key == "PADRSHOULDER" then self:Buy()
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
-- In the middle of the screen
---------------------------------------------------------------------------
local frame, sky, hint

-- A button as your controller shows it (its own icon where the HUD has one), else its name
local function KeyText(key)
    if ns.KeyText then
        local ok, text = pcall(ns.KeyText, key)
        if ok and type(text) == "string" and text ~= "" then return text end
    end
    local text = GetBindingText and GetBindingText(key) or key
    return (type(text) == "string" and text ~= "") and text or key
end
G.KeyText = KeyText

local function Tex(parent, layer, sub, path)
    local t = parent:CreateTexture(nil, layer, nil, sub)
    if path then t:SetTexture(path) end
    return t
end

-- The lane: in the middle of the screen, over you on your mount, drawn G.SCALE larger
local function Place(f)
    f:SetScale(G.SCALE)
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", 0, G.Y / G.SCALE)
end

-- The one line while it is offered or away: under the flight bar's own lines
local function Anchor(f, below)
    local bar = ns.Flights and ns.Flights.frame and ns.Flights.frame.bar
    f:ClearAllPoints()
    if bar then f:SetPoint("TOP", bar, "BOTTOM", 0, below)
    else f:SetPoint("TOP", UIParent, "TOP", 0, -150) end
end

local function Zep(parent, sub)                         -- a zeppelin's picture, and its side's badge on the cloth
    local t = Tex(parent, "BORDER", sub)
    local b = Tex(parent, "BORDER", sub + 1)
    b:SetTexCoord(0, 40 / 64, 0, 40 / 64)
    t:Hide()
    b:Hide()
    return t, b
end

G.LIFE_SLOTS = G.LIVES + 3                              -- (as many lives as Thick harness can give)

local function Build()
    -- the frame: the lane and the lines under it (never clipped); the sky inside it: what is drawn in the lane
    -- (clipped to it, where the game can)
    frame = CreateFrame("Frame", "ControllerCamHUD_FlightGameLane", UIParent)
    frame:SetSize(G.W, G.H)
    frame:SetFrameStrata("MEDIUM")
    Place(frame)
    sky = CreateFrame("Frame", nil, frame)
    sky:SetAllPoints(frame)
    if sky.SetClipsChildren then pcall(sky.SetClipsChildren, sky, true) end
    frame.sky = sky
    local back = Tex(frame, "BACKGROUND", -2, ns.media.soft)         -- a soft evening sky, no box
    back:SetVertexColor(0.1, 0.2, 0.38, 0.7)
    back:SetPoint("TOPLEFT", frame, "TOPLEFT", -60, 10)
    back:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 60, -60)          -- (and under the lines below it)
    frame.back = back
    G.cloudTex = {}
    for i = 1, G.CLOUDS do                                             -- the clouds behind, faint
        local t = Tex(sky, "BACKGROUND", -1, G.ART.cloud)
        t:SetVertexColor(0.9, 0.94, 1, 0.28)
        t:Hide()
        G.cloudTex[i] = t
    end
    G.thingTex, G.thingBadge = {}, {}
    for i = 1, G.THINGS do                                             -- treetops and zeppelins
        G.thingTex[i], G.thingBadge[i] = Zep(sky, 0)
    end
    G.shipTex, G.shipBadge = Zep(sky, 2)                               -- your side's zeppelin, crossing
    G.bossTex, G.bossBadge = Zep(sky, 4)                               -- theirs, raiding
    G.drakeTex = Tex(sky, "BORDER", 6, G.ART.drake)                    -- a drake
    G.drakeTex:Hide()
    G.drakeGlow = Tex(sky, "BORDER", 7, ns.media.halo)                 -- its mouth, glowing as it draws breath
    G.drakeGlow:SetVertexColor(1, 0.6, 0.2, 0.9)
    G.drakeGlow:Hide()
    G.bossChute = {}
    for i = 1, 2 do
        local t = Tex(sky, "BORDER", 3, ns.media.halo)
        t:SetSize(30, 16)
        t:SetVertexColor(1, 0.95, 0.85, 0.85)
        t:Hide()
        G.bossChute[i] = t
    end
    G.bossBar = Tex(sky, "OVERLAY", 2)                                  -- how many nets it can still take
    G.bossBar:SetColorTexture(0.92, 0.33, 0.38, 0.9)
    G.bossBar:SetHeight(3)
    G.bossBar:Hide()
    G.riderTex = {}
    for i = 1, G.RIDERS do
        local r = {}
        r.mount = Tex(sky, "ARTWORK", 1)
        r.mount:SetSize(G.RIDER, G.RIDER)
        r.mount:SetTexCoord(0.9, 0.1, 0.1, 0.9)                        -- (facing the other way; the icon's frame off)
        r.face = Tex(sky, "ARTWORK", 3)
        r.face:SetSize(12, 12)
        r.chute = Tex(sky, "ARTWORK", 0, ns.media.halo)                -- a small parachute, once grounded
        r.chute:SetSize(22, 12)
        r.chute:SetVertexColor(1, 0.95, 0.85, 0.85)
        r.net = Tex(sky, "OVERLAY", 0, ns.media.ring)                  -- and the net round it
        r.net:SetSize(G.RIDER + 6, G.RIDER + 6)
        r.net:SetVertexColor(0.85, 0.9, 1, 0.9)
        for _, t in pairs(r) do t:Hide() end
        G.riderTex[i] = r
    end
    G.netTex = {}
    for i = 1, G.NETS + 3 do                                           -- your nets (more with Quick reload)
        local t = Tex(sky, "OVERLAY", 1, ns.media.ring)
        t:SetSize(10, 10)
        t:SetVertexColor(0.85, 0.92, 1, 0.95)
        t:Hide()
        G.netTex[i] = t
    end
    G.foeTex = {}
    for i = 1, 10 do                                                   -- theirs, reddish
        local t = Tex(sky, "OVERLAY", 1, ns.media.ring)
        t:SetSize(11, 11)
        t:SetVertexColor(1, 0.55, 0.45, 0.95)
        t:Hide()
        G.foeTex[i] = t
    end
    G.fireTex = {}
    for i = 1, G.FIRES do                                              -- the drake's fire (the HUD's painted flame)
        local t = Tex(sky, "OVERLAY", 2, ns.media.flame)
        t:SetSize(12, 12)
        t:Hide()
        G.fireTex[i] = t
    end
    local you = Tex(sky, "ARTWORK", 4)                                 -- your mount, cut round, in a thin gold ring
    you:SetSize(G.YOU, G.YOU)
    you:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    if sky.CreateMaskTexture then
        pcall(function()
            local mask = sky:CreateMaskTexture()
            mask:SetTexture(ns.media.disc, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            mask:SetAllPoints(you)
            you:AddMaskTexture(mask)
        end)
    end
    frame.you = you
    local ring = Tex(sky, "ARTWORK", 5, ns.media.ring)
    ring:SetVertexColor(1, 0.84, 0.45, 0.95)
    ring:SetPoint("TOPLEFT", you, "TOPLEFT", -2, 2)
    ring:SetPoint("BOTTOMRIGHT", you, "BOTTOMRIGHT", 2, -2)
    frame.ring = ring
    -- your lives, top left: small copies of your mount (the lost ones faint), and the round beside them
    G.lifeTex = {}
    for i = 1, G.LIFE_SLOTS do
        local t = Tex(frame, "OVERLAY", 1)
        t:SetSize(10, 10)
        t:SetTexCoord(0.1, 0.9, 0.1, 0.9)
        t:SetPoint("TOPLEFT", frame, "TOPLEFT", 4 + (i - 1) * 12, -4)
        t:Hide()
        G.lifeTex[i] = t
    end
    frame.roundText = ns.FontString(frame, 9, "LEFT")
    frame.roundText:SetTextColor(unpack(C.muted))
    frame.score = ns.FontString(sky, 10, "RIGHT")                      -- this run's gold, small, in a corner
    frame.score:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -3)
    frame.score:SetTextColor(unpack(C.caution))
    frame.word = ns.FontString(sky, 10, "CENTER")                      -- what just happened
    frame.word:SetPoint("TOP", frame, "TOP", 0, -16)
    frame.word:SetWidth(G.W - 40)
    frame.word:SetTextColor(unpack(C.text))
    frame.banner = ns.FontString(sky, 14, "CENTER")                    -- a round cleared, shot down
    frame.banner:SetPoint("CENTER", frame, "CENTER", 0, 14)
    frame.banner:SetWidth(G.W - 20)
    frame.banner:SetTextColor(unpack(C.caution))
    -- under the lane: how it is played as a run starts, then the buttons and the upgrade on offer
    frame.lines = {}
    for i = 1, 3 do
        local fs = ns.FontString(frame, 9, "CENTER")
        fs:SetPoint("TOP", i == 1 and frame or frame.lines[i - 1], "BOTTOM", 0, i == 1 and -6 or -3)
        fs:SetWidth(G.W + 120)                                         -- (one line each, at the usual text size)
        fs:SetTextColor(unpack(C.muted))
        frame.lines[i] = fs
    end
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

-- A zeppelin on its picture: its side's colours, and the game's own badge of the side on the cloth
local function DrawZep(t, b, z, alpha)
    if not z or alpha <= 0 then
        t:Hide()
        b:Hide()
        return
    end
    local art = G.ART[z.side] or G.ART.zeppelin
    if t.art ~= art then
        t:SetTexture(art)
        t.art = art
    end
    t:ClearAllPoints()
    t:SetSize(z.w, z.h)
    t:SetPoint("CENTER", frame, "BOTTOMLEFT", z.x, z.y - z.h * 0.14)   -- (the envelope sits high in the picture)
    t:SetAlpha(alpha)
    t:SetVertexColor(1, 1, 1, 1)
    if z.down then t:SetVertexColor(0.65, 0.65, 0.7, 1) end
    t:Show()
    local badge = G.BADGE[z.side]
    if badge then
        b:SetTexture(badge)
        b:SetSize(z.h * 0.42, z.h * 0.42)
        At(b, z.x - z.w * 0.2, z.y)
        b:SetAlpha(alpha)
        b:Show()
    else
        b:Hide()
    end
end

-- How it is played, in three short lines
function G.HowTo()
    return {
        L["%s flap  ·  dodge treetops, zeppelins, nets and fire"]:format(KeyText("PAD1")),
        L["%s net riders for flight gold  ·  %s high altitude"]:format(KeyText("PAD3"), KeyText("PAD4")),
        L["Clear a round to bank its gold: shot down, it is lost  ·  %s %s upgrades"]:format(
            KeyText("PADLSHOULDER"), KeyText("PADRSHOULDER")),
    }
end

-- The upgrade on offer (what it does, in numbers), and what you have to spend
function G.Shop()
    local u = G.UPGRADES[G.pick] or G.UPGRADES[1]
    local lvl = G.Level(u.key)
    local offer
    if lvl >= #u.cost then
        offer = L["%s is fully upgraded"]:format(L[u.label])
    else
        offer = L["%s %s %d: %s, %d gold"]:format(KeyText("PADRSHOULDER"), L[u.label], lvl + 1, G.Effect(u.key, lvl),
            u.cost[lvl + 1])
    end
    return ("%s  ·  %s  ·  %s"):format(offer, L["%s next"]:format(KeyText("PADLSHOULDER")),
        L["%d gold to spend"]:format(G.Wallet()))
end

local function Hide(...)
    for i = 1, select("#", ...) do select(i, ...):Hide() end
end

function G:Draw(now)
    if not frame then return end
    local calm = ns.Calm()
    local fl = ns.Flights and ns.Flights.flight
    local kind = fl and fl.mount or "gryphon"
    local mountArt = ns.Flights.MOUNTS[kind] or ns.Flights.MOUNTS.gryphon
    if frame.youKind ~= kind then
        frame.you:SetTexture(mountArt)
        for _, t in ipairs(G.lifeTex) do t:SetTexture(mountArt) end
        frame.youKind = kind
    end
    At(frame.you, G.X, self.y)
    local down = self.phase == "down"
    if frame.you.SetRotation then
        local tilt = down and -0.6 or ns.Clamp(self.vy / 400, -0.35, 0.3)
        pcall(frame.you.SetRotation, frame.you, calm and 0 or tilt)
    end
    local fog = self.dazed > 0 and (calm and 0.55 or (0.45 + 0.35 * math.abs(math.sin(now * 10)))) or 1
    if self.grace > 0 and not calm and math.floor(now * 8) % 2 == 0 then fog = 0.25 end   -- (blinking: safe)
    if down then fog = 0.4 end
    frame.you:SetAlpha(fog)
    frame.ring:SetAlpha(fog)
    -- your lives, and the round
    local most = math.min(G.LIFE_SLOTS, math.max(G.Lives(), self.lives))
    for i, t in ipairs(G.lifeTex) do
        if i <= most then
            t:SetAlpha(i <= self.lives and 1 or 0.22)
            t:Show()
        else
            t:Hide()
        end
    end
    frame.roundText:ClearAllPoints()
    frame.roundText:SetPoint("TOPLEFT", frame, "TOPLEFT", 6 + most * 12, -3)
    frame.roundText:SetText(L["Round %d"]:format(self.roundNo))
    -- the clouds behind
    for i, t in ipairs(G.cloudTex) do
        local c = self.clouds[i]
        if c then
            t:SetSize(c.w, c.w / 2)
            At(t, c.x, c.y)
            t:SetAlpha(Edge(c.x, c.w))
            t:Show()
        else
            t:Hide()
        end
    end
    -- treetops rise from the lane's foot; zeppelins drift
    for i, t in ipairs(G.thingTex) do
        local th = self.things[i]
        local a = th and Edge(th.x, th.w) or 0
        if th and th.kind == "tree" and a > 0 then
            G.thingBadge[i]:Hide()
            if t.art ~= G.ART.tree then
                t:SetTexture(G.ART.tree)
                t.art = G.ART.tree
            end
            t:ClearAllPoints()
            t:SetSize(th.w, th.top + 4)
            t:SetPoint("BOTTOM", frame, "BOTTOMLEFT", th.x, -4)
            t:SetAlpha(a)
            t:SetVertexColor(1, 1, 1, 1)
            t:Show()
        else
            DrawZep(t, G.thingBadge[i], th, a)
        end
    end
    -- your side's zeppelin, and theirs (with how many nets it can still take, and its parachutes once down)
    DrawZep(G.shipTex, G.shipBadge, self.ship, self.ship and Edge(self.ship.x, self.ship.w) or 0)
    local boss = self.boss
    DrawZep(G.bossTex, G.bossBadge, boss, boss and Edge(boss.x, boss.w) or 0)
    for i, t in ipairs(G.bossChute) do
        if boss and boss.down then
            At(t, boss.x + (i == 1 and -0.25 or 0.25) * boss.w, boss.y + boss.h * 0.55)
            t:Show()
        else
            t:Hide()
        end
    end
    -- the drake, its mouth glowing as it draws breath
    local d = self.drake
    if d then
        At(G.drakeTex, d.x, d.y)
        G.drakeTex:SetSize(d.w, d.h)
        G.drakeTex:SetAlpha(Edge(d.x, d.w))
        G.drakeTex:Show()
        if d.inhale or d.breath then
            local mx, my = Mouth(d)
            local grow = d.inhale and (1 - d.inhale / G.DRAKE_INHALE) or 1
            local size = 8 + 16 * grow + ((calm or not d.inhale) and 0 or math.sin(now * 30) * 2)
            At(G.drakeGlow, mx, my)
            G.drakeGlow:SetSize(size, size)
            G.drakeGlow:Show()
        else
            G.drakeGlow:Hide()
        end
    else
        Hide(G.drakeTex, G.drakeGlow)
    end
    local foe = (boss and not boss.down and boss) or (d and not d.fled and not d.leaving and d) or nil
    if foe then
        G.bossBar:ClearAllPoints()
        G.bossBar:SetPoint("LEFT", frame, "BOTTOMLEFT", foe.x - foe.w * 0.35, foe.y + foe.h * 0.46)
        G.bossBar:SetWidth(math.max(1, foe.w * 0.7 * foe.hp / (foe.full or G.BOSS_HP)))
        G.bossBar:Show()
    else
        G.bossBar:Hide()
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
            Hide(rt.mount, rt.face, rt.chute, rt.net)
        end
    end
    -- nets: yours (as wide as they reach) and theirs; the drake's fire
    local netSize = G.Hit() * 0.8
    for _, pair in ipairs({ { G.netTex, self.nets }, { G.foeTex, self.foes }, { G.fireTex, self.fires } }) do
        local mine = pair[1] == G.netTex
        local fire = pair[1] == G.fireTex
        for i, t in ipairs(pair[1]) do
            local n = pair[2][i]
            if n then
                At(t, n.x, n.y)
                if mine then t:SetSize(netSize, netSize) end
                if fire then
                    local s = (n.big and 15 or 10) + (calm and 0 or math.min(4, (n.t or 0) * 6))
                    t:SetSize(s, s)
                elseif t.SetRotation and not calm then
                    pcall(t.SetRotation, t, n.spin)
                end
                t:Show()
            else
                t:Hide()
            end
        end
    end
    frame.score:SetText(L["%d flight gold"]:format(self.gold))
    if self.wordUntil and now < self.wordUntil then
        frame.word:SetText(self.word)
        frame.word:Show()
    else
        frame.word:Hide()
    end
    if self.bannerUntil and now < self.bannerUntil then
        frame.banner:SetText(self.banner)
        frame.banner:SetAlpha(calm and 1 or math.min(1, self.bannerUntil - now))
        frame.banner:Show()
    else
        frame.banner:Hide()
    end
    -- under the lane: how it is played as a run starts (fading at the end), then the buttons and the upgrade;
    -- shot down: how far you got, and A to go again
    local lines = frame.lines
    local left = (self.introUntil or 0) - now
    if down then
        local ready = self.clock - (self.downAt or 0) >= G.DOWN_WAIT
        lines[1]:SetText(L["Shot down in round %d with %d flight gold"]:format(self.roundNo, self.gold))
        lines[2]:SetText(L["%s fly again from round 1"]:format(KeyText("PAD1")))
        lines[3]:SetText(G.Shop())
        for i = 1, 3 do
            lines[i]:SetTextColor(unpack(i == 2 and C.text or C.muted))
            lines[i]:SetAlpha((i == 2 and not ready) and 0.4 or 1)
            lines[i]:Show()
        end
    elseif left > 0 then
        local how = G.HowTo()
        for i = 1, 3 do
            lines[i]:SetText(how[i])
            lines[i]:SetTextColor(unpack(C.text))
            lines[i]:SetAlpha(calm and 1 or math.min(1, left))
            lines[i]:Show()
        end
    else
        lines[1]:SetText(("%s   %s   %s"):format(L["%s flap"]:format(KeyText("PAD1")), L["%s net"]:format(KeyText("PAD3")),
            L["%s high altitude"]:format(KeyText("PAD4"))))
        lines[2]:SetText(G.Shop())
        for i = 1, 2 do
            lines[i]:SetTextColor(unpack(C.muted))
            lines[i]:SetAlpha(1)
            lines[i]:Show()
        end
        lines[3]:Hide()
    end
end

-- The line under the flight bar while it is offered: the button, your best on this route, gold to spend
function G.Offer()
    local parts = { L["%s: a game on the way"]:format(KeyText(G.START)) }
    local route = G.Route()
    local best = route and ns.db.flightGameRoutes[route]
    if best and best > 0 then parts[#parts + 1] = L["best on this route: %d"]:format(best) end
    local wallet = G.Wallet()
    if wallet > 0 then parts[#parts + 1] = L["%d flight gold to spend on upgrades"]:format(wallet) end
    return table.concat(parts, "  ·  ")
end

-- What shows: the lane while it is played, the one line while it is offered or away
function G:Show()
    local flying = self.active and G.Flying()
    local lane = flying and self.state == "playing"
    local line = flying and (self.state == "offered" or self.state == "paused") and not InCombatLockdown()
    if not frame and not (lane or line) then return end
    if not frame then Build() end
    if lane then
        Place(frame)
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
            text = G.Offer()
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
    if self.started then
        self.introUntil = (GetTime() or 0) + G.AGAIN                -- (back from high altitude: a reminder)
    else
        self:NewRun()
        self.introUntil = (GetTime() or 0) + G.INTRO
    end
    self.state = "playing"
    self:Bind()
    self:Show()
    self:Draw(GetTime())
    ns.Note("flight game: playing (flight gold %d, round %d)", self.gold, self.roundNo)
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

-- Off the flight (landed, the option off, the HUD stopped): everything given back, the run over. The landing
-- is not your doing: the round's gold is kept.
function G:Stop(why)
    local was = self.state
    self.state = "off"
    self:Bind()
    if frame then frame:Hide() end
    if hint then hint:Hide() end
    self.shownFor = nil                                       -- (the next flight shows its line afresh)
    self.purse = 0
    if was ~= "off" then
        if self.started and (self.grounded > 0 or self.gold > 0) then
            ns.Note("flight game: over (%s), round %d, %d grounded, flight gold %d, route %s", tostring(why),
                self.roundNo, self.grounded, self.gold, tostring(self.route))
        end
        self.started = false
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
        self.started = false
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
-- A key binding, commands, the debug report
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

-- Your best on each route, your flight gold, and the upgrades you have
ns.RegisterCommand("flightscores", function()
    local db = ns.db
    local list = {}
    for route, n in pairs(db.flightGameRoutes or {}) do list[#list + 1] = { route, n } end
    table.sort(list, function(a, b) if a[2] ~= b[2] then return a[2] > b[2] end return a[1] < b[1] end)
    ns.Say(L["Flight game: earned %d, spent %d, lost %d, %d to spend."]:format(db.flightGold or 0,
        db.flightGoldSpent or 0, db.flightGoldLost or 0, G.Wallet()))
    for _, r in ipairs(list) do print(("  %s  %d"):format(r[1], r[2])) end
    if #list == 0 then print("  " .. L["No routes played yet."]) end
    local ups = {}
    for _, u in ipairs(G.UPGRADES) do ups[#ups + 1] = ("%s %d/%d"):format(L[u.label], G.Level(u.key), #u.cost) end
    print("  " .. table.concat(ups, ", "))
end, "/cchud flightscores", "the flight game: your best on each route, your flight gold and your upgrades")

function G.Describe()
    local db = ns.db or {}
    local routes = 0
    for _ in pairs(db.flightGameRoutes or {}) do routes = routes + 1 end
    local ups = {}
    for _, u in ipairs(G.UPGRADES) do ups[#ups + 1] = u.key .. " " .. G.Level(u.key) end
    return ("on %s, %s, buttons %s, %s, round %d, lives %d, flight gold now %d (unbanked %d; earned %d, spent %d, "
        .. "lost %d, best %d, routes %d), grounded %d, nets %d, bumps %d, netted %d, burned %d, upgrades %s"):format(
        tostring(G.active), G.state, G.bound, tostring(G.phase), G.roundNo or 1, G.lives or 0, G.gold or 0,
        G.purse or 0, db.flightGold or 0, db.flightGoldSpent or 0, db.flightGoldLost or 0, db.flightGameBest or 0,
        routes, G.grounded or 0, G.fired or 0, G.bumps or 0, G.netted or 0, G.burned or 0, table.concat(ups, ", "))
end

ns.RegisterModule("flightgame", G)
