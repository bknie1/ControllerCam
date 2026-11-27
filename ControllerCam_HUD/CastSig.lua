-- ControllerCam HUD: the main abilities' own shows on a cast bar.
-- CastLook.SIGS says which ability gets which show; CastArt plays it over the school's own (Full and Subtle).
--   charge    a bolt: motes run along what is filled and gather at the right end of the bar, which swells and
--             throbs quicker until it looks ready to burst; when the cast lands it fires, each in its own way:
--               burst    streaks thrown out to the right (Fireball, Pyroblast, Incinerate)
--               shatter  shards of ice flung out, spinning (Frostbolt)
--               lance    one long streak shot off the end of the bar (Shadow Bolt, Soul Fire)
--               implode  a ring drawn in to a point, then knocked out again (Arcane Blast, Mind Blast)
--               beam     a shaft of light standing on the end of the bar (Smite, Holy Fire, Exorcism)
--               engulf   flames leap along the whole bar (Immolate)
--               arc      one stroke of lightning the length of the bar (Lightning Bolt)
--             A cast cut short never fires: what had gathered sinks and goes out.
--   orb       Wrath: a ball of force wound up in the middle of the bar, wisps circling in to it fast and faster;
--             when it lands the ball is thrown off the right end, at the enemy
--   reticle   Aimed Shot: sights that wander over the bar, less and less, and sit dead on its middle the moment
--             the shot goes (they turn red as they lock). A bow's sights are a ring and a pin, a gun's a
--             crosshair. A shot cut short: the sights drop away.
--   missiles  Arcane Missiles (a channel, the bar empties): its bolts wait over the bar and leave one by one
--   tether    Mind Flay, Drain Life (channels): motes flow along the bar, to the foe or back to you, and the end
--             they flow to throbs at every tick
-- Everything follows the bar's own progress, so a cast pushed back by a hit stays in step. Nameplates and Subtle
-- get fewer pieces and a smaller ending.

local ADDON, ns = ...
local A = ns.CastArt
local Put, Turn, Scatter, Clamp01 = A.Put, A.Turn, A.Scatter, A.Clamp01
local sin, cos, floor, max, min, pi = math.sin, math.cos, math.floor, math.max, math.min, math.pi

local SHOWS = A.SHOWS

-- How many pieces: your own bar at Full, at Subtle, a nameplate
local function Count(art, full, subtle, light)
    if art.light then return light end
    return art.subtle and subtle or full
end
-- How big an ending is: smaller on nameplates and at Subtle
local function Reach(art) return (art.light or art.subtle) and 0.6 or 1 end
local function Pale(c, k) return c[1] * (1 - k) + k, c[2] * (1 - k) + k, c[3] * (1 - k) + k end

---------------------------------------------------------------------------
-- Charge
---------------------------------------------------------------------------
local FIRE = { burst = { "spark", 6 }, shatter = { "crystal", 6 }, lance = { "spark", 1 }, implode = { "ring", 2 },
               beam = { "spark", 1 }, engulf = { "flame", 5 }, arc = { "bolt", 1 } }

SHOWS.charge = {
    fade = 0.55,
    start = function(art)
        local o, sig, c = art.o, art.sig, art.color
        local r, g, b = Pale(c, 0.35)
        o.motes, o.fx = {}, {}
        for j = 1, Count(art, 9, 4, 3) do o.motes[j] = art:Piece(sig.tex or "soft", "ADD", r, g, b) end
        o.glow = art:Piece("soft", "ADD", c[1], c[2], c[3])
        o.core = art:Piece("soft", "ADD", Pale(c, 0.8))
        local fire = FIRE[sig.fire] or FIRE.burst
        local n = fire[2] > 2 and Count(art, fire[2], 3, 3) or fire[2]
        for j = 1, n do
            if fire[1] == "flame" then o.fx[j] = art:Piece("flame", "ADD", 1, 0.85, 0.6)
            else o.fx[j] = art:Piece(fire[1], "ADD", Pale(c, 0.5)) end
        end
        o.flash = art:Piece("soft", "ADD", Pale(c, 0.3))
        o.charge, o.fired, o.fizzled = 0, false, false
    end,
    update = function(art, edge, p, now)
        local o, sig, s, w, h = art.o, art.sig, art.scale, art.w, art.h
        local big = sig.big or 1
        local n = #o.motes
        local seen = math.ceil(n * (0.3 + 0.7 * p))
        local lying = (sig.tex == "spark") and pi / 2 or nil
        for j, t in ipairs(o.motes) do
            if j > seen or edge < 4 then
                t:SetAlpha(0)
            else
                -- from somewhere along what is filled to the right end, quicker as it nears it
                local l = (now * (0.7 + 0.9 * p) + Scatter(j, 1)) % 1
                local x0 = edge * Scatter(j, 2)
                Put(art, t, x0 + (w - x0) * l * l, sin(now * 5 + j * 2.1) * (h / 2 + 7 * s) * (1 - l),
                    (7 + 4 * Scatter(j, 3)) * s * (1 - 0.4 * l))
                if lying then Turn(t, lying) end
                t:SetAlpha(sin(l * pi) * (0.35 + 0.6 * p))
            end
        end
        -- what has gathered: it swells with the cast, throbs quicker, and trembles when it is about to go
        local throb = 1 + 0.12 * sin(now * (8 + 30 * p))
        local tremble = (p > 0.85 and not art.subtle and not art.light) and sin(now * 70) * 1.5 * s * (p - 0.85) / 0.15 or 0
        local size = (8 + 26 * p * p) * big * s * throb
        Put(art, o.glow, w + tremble, 0, size)
        o.glow:SetAlpha(0.3 + 0.55 * p)
        Put(art, o.core, w + tremble, 0, size * 0.45)
        o.core:SetAlpha(0.2 + 0.8 * p)
        for _, t in ipairs(o.fx) do t:SetAlpha(0) end
        o.flash:SetAlpha(0)
        o.charge, o.size = (8 + 26 * p * p) * big, size
    end,
    finish = function(art, k, now, landed)
        local o, sig, s, w, h = art.o, art.sig, art.scale, art.w, art.h
        local big, m = sig.big or 1, Reach(art)
        local size = o.size or 8 * s
        for _, t in ipairs(o.motes) do t:SetAlpha(0) end
        if not landed then                                          -- cut short: it sinks and goes out, unfired
            o.fizzled = true
            Put(art, o.glow, w, -8 * k * s, size * (1 - k))
            o.glow:SetAlpha(0.6 * (1 - k))
            Put(art, o.core, w, -8 * k * s, size * 0.45 * (1 - k))
            o.core:SetAlpha(0.5 * (1 - k))
            return
        end
        o.fired = true
        Put(art, o.glow, w, 0, size * (1 + 1.5 * k))
        o.glow:SetAlpha(1 - k)
        o.core:SetAlpha((1 - k) * (1 - k))
        Put(art, o.flash, w, 0, (40 + 60 * k) * big * s * m, (30 + 40 * k) * big * s * m)
        o.flash:SetAlpha(1)
        local fx, nf, how = o.fx, #o.fx, sig.fire
        if how == "lance" then
            Put(art, fx[1], w + (10 + 90 * k) * s * m, 0, 8 * s * big, (40 + 50 * k) * s * big * m)
            Turn(fx[1], pi / 2)
            fx[1]:SetAlpha(1)
        elseif how == "implode" then
            local inward = k < 0.4
            Put(art, fx[1], w, 0, max(4, 60 - 54 * (k / 0.4)) * big * s * m)
            fx[1]:SetAlpha(inward and 1 or 0)
            Put(art, fx[2], w, 0, (6 + 110 * max(0, (k - 0.4) / 0.6)) * big * s * m)
            fx[2]:SetAlpha(inward and 0 or 1)
        elseif how == "beam" then
            Put(art, fx[1], w - 6 * s, 0, (10 + 8 * sin(k * pi)) * s * big, (h + 70 * s * m) * (0.5 + 0.5 * min(1, k * 4)))
            fx[1]:SetAlpha(1)
        elseif how == "engulf" then
            local tall = (14 + 16 * sin(min(1, k * 2) * pi / 2)) * s * big * m
            for j, t in ipairs(fx) do
                Put(art, t, (j - 0.5) * w / nf, h / 2 + tall * 0.4, tall * 0.8, tall)
                t:SetAlpha(1)
            end
        elseif how == "arc" then
            Put(art, fx[1], w / 2, 0, w, 20 * s * big)
            fx[1]:SetAlpha(floor(now * 30) % 2 == 0 and 1 or 0.6)
        else                                                        -- burst, shatter: thrown out to the right in a fan
            local d = (20 + 70 * k) * big * s * m
            for j, t in ipairs(fx) do
                local a = (j / (nf + 1) - 0.5) * 2.2
                if how == "shatter" then
                    Put(art, t, w + cos(a) * d, sin(a) * d * 0.7, 9 * s)
                    Turn(t, k * 6 * (j % 2 * 2 - 1))
                else
                    Put(art, t, w + cos(a) * d, sin(a) * d * 0.7, 6 * s, (14 + 10 * (1 - k)) * s)
                    Turn(t, a - pi / 2)
                end
                t:SetAlpha(1)
            end
        end
    end,
}

---------------------------------------------------------------------------
-- Orb
---------------------------------------------------------------------------
SHOWS.orb = {
    fade = 0.5,
    start = function(art)
        local o, sig, c = art.o, art.sig, art.color
        o.wisps, o.trail = {}, {}
        for i = 1, Count(art, 11, 6, 5) do o.wisps[i] = art:Piece(sig.tex or "soft", "ADD", Pale(c, 0.5)) end
        o.eye = art:Piece("halo", "ADD", c[1], c[2], c[3])
        for i = 1, Count(art, 4, 2, 2) do o.trail[i] = art:Piece("soft", "ADD", Pale(c, 0.3)) end
        o.ball = art:Piece("soft", "ADD", Pale(c, 0.7))
        o.spin, o.thrown = 0, false
    end,
    update = function(art, edge, p, now)
        local o, s, w, h = art.o, art.scale, art.w, art.h
        local n, cx = #o.wisps, w / 2
        o.speed = art.sig.slow and (2.2 + 3 * p) or (4.5 + 9 * p)       -- (the Hearthstone's whirl turns at 1.8 to 4.4)
        o.spin = now * o.speed
        local rx, ry = min(w * 0.2, 46 * s) * (0.6 + 0.4 * p), h / 2 + (6 + 8 * p) * s
        o.rx, o.ry = rx, ry
        for i, t in ipairs(o.wisps) do
            local life = (now * 1.4 + i / n) % 1                         -- drawn in to the ball, then out again
            local a = o.spin + i * (2 * pi / n) + life * 2.4
            local r = 1 - life * 0.85
            Put(art, t, cx + cos(a) * rx * r, sin(a) * ry * r, (8 + 5 * p) * s * (1 - life * 0.4), (3 + 2 * p) * s)
            Turn(t, a + pi / 2)
            t:SetAlpha(sin(life * pi) * (0.4 + 0.55 * p))
        end
        Put(art, o.eye, cx, 0, (12 + 20 * p) * s)
        Turn(o.eye, -o.spin * 0.5)
        o.eye:SetAlpha(0.25 + 0.5 * p)
        Put(art, o.ball, cx, 0, (5 + 11 * p * p) * s * (1 + 0.1 * sin(now * (10 + 30 * p))))
        o.ball:SetAlpha(0.3 + 0.7 * p)
        for _, t in ipairs(o.trail) do t:SetAlpha(0) end
        o.x = cx
    end,
    finish = function(art, k, now, landed)
        local o, s, w = art.o, art.scale, art.w
        local n, cx = #o.wisps, w / 2
        local rx, ry = o.rx or w * 0.2, o.ry or art.h
        for i, t in ipairs(o.wisps) do                                   -- the wind lets go
            local a = o.spin + i * (2 * pi / n) + k * 2
            Put(art, t, cx + cos(a) * rx * (1 + k), sin(a) * ry * (1 + k), 9 * s, 3 * s)
            Turn(t, a + pi / 2)
            t:SetAlpha(0.5 * (1 - k))
        end
        o.eye:SetAlpha(0.6 * (1 - k))
        if not landed then                                               -- cut short: the ball dwindles where it is
            Put(art, o.ball, cx, 0, 12 * s * (1 - k))
            o.ball:SetAlpha(0.6 * (1 - k))
            return
        end
        o.thrown = true
        o.x = cx + (w / 2 + 60 * s) * k * k                              -- thrown off the right end, at the enemy
        Put(art, o.ball, o.x, 0, 16 * s * (1 - 0.3 * k))
        o.ball:SetAlpha(1)
        for i, t in ipairs(o.trail) do
            Put(art, t, o.x - i * 12 * s * k, 0, (12 - 2 * i) * s)
            t:SetAlpha(0.5)
        end
    end,
}

---------------------------------------------------------------------------
-- Reticle
---------------------------------------------------------------------------
-- What you shoot with: "gun" (guns and crossbows: a crosshair) or "bow" (a ring and a pin). A bow when the game
-- cannot say.
function A.Sights()
    if type(GetInventoryItemID) ~= "function" then return "bow" end
    local info = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if type(info) ~= "function" then return "bow" end
    for _, slot in ipairs({ 18, 16 }) do                                -- the ranged slot, or the main hand
        local ok, id = pcall(GetInventoryItemID, "player", slot)
        if ok and type(id) == "number" and not ns.IsSecret(id) then
            local okI, _, _, _, _, _, class, sub = pcall(info, id)
            if okI and class == 2 and not ns.IsSecret(sub) then
                if sub == 3 or sub == 18 then return "gun" end
                if sub == 2 then return "bow" end
            end
        end
    end
    return "bow"
end

local CREAM, LOCKED = { 0.95, 0.9, 0.8 }, { 1, 0.3, 0.25 }
local LOCK_FROM = 0.92           -- the sights turn red from here: about to go

local function Sight(art, g, x, y, size, color, alpha, gun)
    local s = art.scale
    local r, gr, b = color[1], color[2], color[3]
    Put(art, g.ring, x, y, gun and size * 0.6 or size)
    g.ring:SetVertexColor(r, gr, b, 1)
    g.ring:SetAlpha(alpha)
    local len = gun and size * 0.55 or size * 0.3
    local d = (gun and size * 0.3 or size * 0.5) + len / 2
    local thick = max(1, 1.5 * s)
    for i, t in ipairs(g.ticks) do
        if i <= 2 then Put(art, t, x + (i == 1 and -d or d), y, len, thick)
        elseif gun then Put(art, t, x, y + (i == 3 and -d or d), thick, len) end
        t:SetVertexColor(r, gr, b, 1)
        t:SetAlpha((i <= 2 or gun) and alpha or 0)
    end
    Put(art, g.pin, x, y, 4 * s)
    g.pin:SetVertexColor(r, gr, b, 1)
    g.pin:SetAlpha(gun and 0 or alpha)
end

-- Where sight i comes to rest: the middle of the bar (several: side by side around it)
local function Rest(art, i, n) return art.w / 2 + (i - (n + 1) / 2) * 20 * art.scale end

SHOWS.reticle = {
    fade = 0.45,
    start = function(art)
        local o = art.o
        o.sights, o.gun = {}, A.Sights() == "gun"
        for i = 1, art.light and 1 or (art.sig.sights or 1) do
            local g = { ring = art:Piece("ring"), ticks = {}, pin = art:Piece("soft") }
            for j = 1, 4 do g.ticks[j] = art:Piece("bar") end
            o.sights[i] = g
        end
        o.flash = art:Piece("soft", "ADD", 1, 0.85, 0.7)
        o.locked = false
    end,
    update = function(art, edge, p, now)
        local o, s, w = art.o, art.scale, art.w
        local n = #o.sights
        local sway = 1 - p
        if art.sig.quick then sway = sway * sway * 0.5 end              -- a quick shot barely wanders
        local amp = min(w * 0.36, 110 * s)
        local color = p >= LOCK_FROM and LOCKED or CREAM
        for i, g in ipairs(o.sights) do
            local ph = i * 2.1
            local x = Rest(art, i, n) + (sin(now * 2.3 + ph) * amp + sin(now * 5.1 + ph * 2) * amp * 0.2) * sway
            local y = cos(now * 3.1 + ph) * 7 * s * sway
            Sight(art, g, x, y, (22 - 8 * p) * s, color, 0.9, o.gun)
            if i == 1 then o.x, o.y = x, y end
        end
        o.flash:SetAlpha(0)
        o.locked = p >= 1
    end,
    finish = function(art, k, now, landed)
        local o, s = art.o, art.scale
        local n = #o.sights
        for i, g in ipairs(o.sights) do
            if landed then                                               -- dead on the middle, and it fires
                Sight(art, g, Rest(art, i, n), 0, (14 + 14 * k) * s, LOCKED, 1, o.gun)
                if i == 1 then o.x, o.y = Rest(art, i, n), 0 end
            else                                                         -- cut short: the sights drop away
                local x = (i == 1 and o.x or Rest(art, i, n)) + 40 * k * s
                Sight(art, g, x, (o.y or 0) - 14 * k * s, 16 * s, CREAM, 0.9 * (1 - k), o.gun)
            end
        end
        if landed then
            o.locked = true
            Put(art, o.flash, art.w / 2, 0, (10 + 40 * k) * s * Reach(art))
            o.flash:SetAlpha(1)
        end
    end,
}

---------------------------------------------------------------------------
-- Missiles (a channel: the bar empties as p goes from 0 to 1)
---------------------------------------------------------------------------
local FLIGHT = 0.35              -- seconds a missile takes to leave

local function Missiles(art, now, k)
    local o, s, w, h = art.o, art.scale, art.w, art.h
    local n = #o.orbs
    for i, t in ipairs(o.orbs) do
        local tail = o.tails[i]
        local x0, y0 = w * (0.2 + 0.6 * (i - 0.5) / n), h / 2 + 9 * s + sin(now * 3 + i) * 1.5 * s
        local at = o.at[i]
        if not at then                                                   -- waiting over the bar
            Put(art, t, x0, y0, 7 * s)
            t:SetAlpha(0.85 * (1 - (k or 0)))
            tail:SetAlpha(0)
        else
            local f = (now - at) / FLIGHT
            if f >= 1 or f < 0 then
                t:SetAlpha(0)
                tail:SetAlpha(0)
            else                                                         -- down to the bar and off its right end
                local x, y = x0 + (w + 30 * s - x0) * f * f, y0 * (1 - f)
                Put(art, t, x, y, 9 * s)
                t:SetAlpha(1)
                Put(art, tail, x - 12 * s, y, 6 * s, 26 * s)
                Turn(tail, pi / 2)
                tail:SetAlpha(0.8)
            end
        end
    end
end

SHOWS.missiles = {
    fade = 0.4,
    start = function(art)
        local o, c = art.o, art.color
        o.orbs, o.tails, o.at, o.fired = {}, {}, {}, 0
        for i = 1, art.sig.ticks or 5 do
            o.orbs[i] = art:Piece("soft", "ADD", Pale(c, 0.5))
            o.tails[i] = art:Piece("spark", "ADD", Pale(c, 0.3))
        end
    end,
    update = function(art, edge, p, now)
        local o = art.o
        local n = #o.orbs
        for i = 1, n do                                                  -- one leaves at each tick of the channel
            if not o.at[i] and p >= (i - 0.2) / n then o.at[i], o.fired = now, i end
        end
        Missiles(art, now)
    end,
    finish = function(art, k, now) Missiles(art, now, k) end,           -- (those in flight fly on; the rest fade)
}

---------------------------------------------------------------------------
-- Tether (a channel)
---------------------------------------------------------------------------
SHOWS.tether = {
    start = function(art)
        local o, c = art.o, art.sig.color or art.color
        o.dots, o.beats = {}, 0
        for j = 1, Count(art, 10, 6, 4) do o.dots[j] = art:Piece("soft", "ADD", Pale(c, 0.3)) end
        o.pulse = art:Piece("halo", "ADD", Pale(c, 0.2))
    end,
    update = function(art, edge, p, now)
        local o, s, w, h = art.o, art.scale, art.w, art.h
        local n, dir = #o.dots, art.sig.dir or 1
        for j, t in ipairs(o.dots) do
            local l = (now * 0.9 * dir + j / n) % 1                      -- along the whole bar, one way
            Put(art, t, w * l, sin(l * pi * 3 + now * 4) * (h / 2 + 3 * s) * 0.8, (5 + 3 * sin(l * pi)) * s)
            t:SetAlpha(0.75 * sin(l * pi))
        end
        local ticks = art.sig.ticks or 3
        local phase = (p * ticks) % 1                                    -- the end it flows to throbs at each tick
        o.beats = floor(p * ticks)
        if o.beats < 1 or phase > 0.25 then
            o.pulse:SetAlpha(0)
        else
            Put(art, o.pulse, dir > 0 and w or 0, 0, (14 + 22 * phase / 0.25) * s)
            o.pulse:SetAlpha(1 - phase / 0.25)
        end
    end,
    finish = function() end,
}

-- The self-check (and so the debug report) says which of the main abilities this game can name: one it cannot
-- is one it does not have, or one whose ID here is wrong
ns.RegisterCheck(function(row, run, db)
    if not (run and db.castArt) then return end
    local known, missing = ns.CastLook.SigsKnown()
    row("main abilities with a look of their own", true,
        ("%d named by this game%s"):format(known, #missing > 0 and ", not found: " .. table.concat(missing, " ") or ""))
end)

-- /cchud sigtest: the main abilities' shows, one after another, on your cast bar
A.SIG_DEMO = { "fireball", "frostbolt", "shadowbolt", "blast", "smite", "immolate", "lightningbolt", "wrath", "aimed",
               "missiles", "mindflay" }
ns.RegisterCommand("sigtest", function()
    local CB = ns.CastBar
    if not (CB and CB.Demo) then return end
    CB:Demo(A.SIG_DEMO)
end, "/cchud sigtest", "show the main abilities' own cast animations once, on your cast bar")
