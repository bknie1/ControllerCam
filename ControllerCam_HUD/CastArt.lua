-- ControllerCam HUD: what works on a cast bar while it fills.
-- A cast bar shows what is being cast, not only how far along it is:
--   mining      little picks peck at the end of the bar, chips fly at every strike
--   crafting    a hammer does the same
--   herbs       leaves sprout along the bar as it fills
--   nature      green lightning runs along it, stroke after stroke
--   lightning   the same in the pale blue of the sky
--   roots       (the spells that root a foe) roots creep along it, budding as they go
--   a heal      a vine winds along it and flowers open on it, one after another
--   a holy heal wounds along the bar that the light sears shut one by one; the bar blazes when it lands
-- Every show builds with the cast and ends on something when it lands: fire kindles, catches and leaps;
-- lightning arcs now and then, then faster, then flashes; flowers open; runes take shape; ice shatters.
--   physical    only a glint of steel
--   arcane      runes hover over the bar, faint at first, and take shape one by one as the cast reaches them
--   fire        flames burn along what is filled, taller as the cast builds
--   frost       ice crystals freeze onto the bar one after another, and shatter when it lands
--   shadow      a dark haze with shades drifting through it: hooded, hollow-eyed, their jaws hanging open
--   holy        rays of light rise off it
--   fishing     the water rings around your float
-- Your own cast bar wears the full show; nameplates a lighter one (fewer pieces, smaller).
-- One Art belongs to one bar: Start(look) when a cast begins, Update(fill, progress, now) every frame,
-- Finish(landed) when it ends (the art fades, in its own way), Stop() to clear it.

local ADDON, ns = ...

local A = { FADE = 0.4 }
ns.CastArt = A

ns.RegisterSetting({
    key = "castArt", kind = "boolean", default = true, command = "castart", section = "Frames",
    label = "Cast bar animations",
    tip = "a cast bar shows what is being cast: picks chip at it while mining, lightning runs along it for nature, a vine flowers for a heal, runes take shape for arcane, flames, ice and shades for fire, frost and shadow",
})

-- Which show a kind of cast gets (a kind is a key of CastLook.KINDS, a school, or "fishing")
A.STYLE_OF = {
    mining = "tool", crafting = "tool", herbs = "leaves", nature = "bolts", lightning = "bolts", roots = "roots",
    heal = "vines", arcane = "runes", disenchant = "runes", fire = "flames", frost = "crystals", shadow = "wisps",
    holy = "rays", travel = "rays", physical = "glint", fishing = "ripples",
}

local sin, cos, floor, max, min, pi = math.sin, math.cos, math.floor, math.max, math.min, math.pi
local function Clamp01(v) return v < 0 and 0 or (v > 1 and 1 or v) end

---------------------------------------------------------------------------
-- Pieces: textures on a layer over the bar, reused from cast to cast
---------------------------------------------------------------------------
local Art = {}
Art.__index = Art

function Art:Piece(tex, blend, r, g, b)
    self.n = self.n + 1
    local t = self.pieces[self.n]
    if not t then
        t = self.layer:CreateTexture(nil, "OVERLAY")
        self.pieces[self.n] = t
    end
    t:SetTexture(ns.media[tex])
    t:SetBlendMode(blend or "BLEND")
    t:SetTexCoord(0, 1, 0, 1)
    if t.SetRotation then t:SetRotation(0) end
    t:SetVertexColor(r or 1, g or 1, b or 1, 1)
    t:SetAlpha(0)
    t:Show()
    return t
end

-- x: from the bar's left end; y: above the middle of the bar
local function Put(art, t, x, y, w, h)
    t:SetSize(w, h or w)
    t:ClearAllPoints()
    t:SetPoint("CENTER", art.layer, "LEFT", x, y)
end

local function Turn(t, radians)
    if t.SetRotation then t:SetRotation(radians) end
end

---------------------------------------------------------------------------
-- The shows. start(art) makes the pieces; update(art, edge, p, now) places them (edge: where the fill ends, in
-- pixels from the left; p: how far along the cast is, 0-1); finish(art, k, now, landed) is the way out (k 0-1).
---------------------------------------------------------------------------
local STYLES = {}
A.STYLES = STYLES

-- A tool pecking at the end of the bar (and two more working behind it on your own bar)
STYLES.tool = {
    bursts = true,
    start = function(art)
        local st = art.state
        st.tools, st.phase, st.strikes = {}, {}, 0
        local tex = art.kind == "crafting" and "hammer" or "pick"
        for i = 1, art.light and 1 or 2 do st.tools[i] = art:Piece(tex) end
    end,
    update = function(art, edge, p, now)
        local s, st = art.scale, art.state
        local size = 22 * s
        for i, t in ipairs(st.tools) do
            local x = edge - (i - 1) * 26 * s
            if x < 4 then
                t:SetAlpha(0)
            else
                -- raised slowly, brought down fast
                local phase = (now * 1.9 + i * 0.37) % 1
                local lift = phase < 0.72 and (phase / 0.72) or (1 - (phase - 0.72) / 0.28)
                Put(art, t, x - size * 0.42, art.h / 2 + size * 0.08 + lift * 5 * s, size)
                Turn(t, lift * 0.7)
                t:SetAlpha(i == 1 and 1 or 0.75)
                if st.phase[i] and phase < st.phase[i] then          -- it struck
                    st.strikes = st.strikes + 1
                    if i == 1 then A.Strike(art) end
                end
                st.phase[i] = phase
            end
        end
    end,
}

-- Leaves sprouting along the top of the bar
STYLES.leaves = {
    start = function(art)
        local st = art.state
        st.leaves = {}
        local n = max(2, floor(art.w / (30 * art.scale)))
        for j = 1, n do st.leaves[j] = art:Piece("leaf") end
    end,
    update = function(art, edge, p, now)
        local s, st = art.scale, art.state
        local n = #st.leaves
        for j, t in ipairs(st.leaves) do
            local x = (j - 0.5) * art.w / n
            local grow = Clamp01((edge - x) / (12 * s))
            if grow <= 0 then
                t:SetAlpha(0)
            else
                local size = (14 + (j * 5) % 4) * s * grow
                Put(art, t, x, art.h / 2 + size * 0.42, size)
                Turn(t, sin(now * 2.2 + j) * 0.22 + ((j % 2 == 0) and 0.45 or -0.45))
                t:SetAlpha(1)
            end
        end
    end,
}

-- Roots creeping along the bar (a spell that roots a foe), budding above and below as they pass
STYLES.roots = {
    start = function(art)
        local st, c = art.state, art.color
        st.strip = art:Piece("roots")
        st.tip = art:Piece("soft", "ADD", c[1], c[2], c[3])
        st.buds = {}
        local n = max(2, floor(art.w / (46 * art.scale)))
        for j = 1, n do st.buds[j] = art:Piece("leaf") end
    end,
    update = function(art, edge, p, now)
        local s, st = art.scale, art.state
        if edge < 3 then
            st.strip:SetAlpha(0)
            st.tip:SetAlpha(0)
        else
            st.strip:SetTexCoord(0, Clamp01(edge / art.w), 0, 1)       -- only as much of the strip as has grown
            Put(art, st.strip, edge / 2, 0, edge, 26 * s)
            st.strip:SetAlpha(0.88 + 0.08 * sin(now * 3))
            Put(art, st.tip, edge, 0, 22 * s, 12 * s)                  -- the growing tip, alive
            st.tip:SetAlpha(0.45 + 0.3 * sin(now * 8))
        end
        local n = #st.buds
        for j, t in ipairs(st.buds) do
            local x = (j - 0.3) * art.w / n
            local grow = Clamp01((edge - x) / (14 * s))
            if grow <= 0 then
                t:SetAlpha(0)
            else
                local up = j % 2 == 1
                local size = 12 * s * grow
                if up then t:SetTexCoord(0, 1, 0, 1) else t:SetTexCoord(0, 1, 1, 0) end
                Put(art, t, x, (up and 1 or -1) * (art.h / 2 + 5 * s + size * 0.2), size)
                t:SetAlpha(0.95)
            end
        end
    end,
}

-- Lightning running along what is filled: a stroke leaps, flickers and is gone, then another somewhere else
-- (green for nature, the pale blue of the sky for lightning), with a crackle where the fill ends. When the
-- cast lands one last stroke runs the whole bar.
STYLES.bolts = {
    start = function(art)
        local st, c = art.state, art.color
        local r, g, b = 0.5 + c[1] * 0.5, 0.5 + c[2] * 0.5, 0.5 + c[3] * 0.5
        st.bolts, st.strokes, st.beat, st.last = {}, 0, 0, nil
        for j = 1, art.light and 1 or 2 do st.bolts[j] = art:Piece("bolt", "ADD", r, g, b) end
        st.crackle = art:Piece("bolt", "ADD", r, g, b)
        st.flash = art:Piece("soft", "ADD", r, g, b)
    end,
    update = function(art, edge, p, now)
        local s, st = art.scale, art.state
        local dt = st.last and (now - st.last) or 0
        st.last = now
        if dt < 0 or dt > 0.5 then dt = 0 end
        st.beat = st.beat + dt * (1.2 + 2.6 * p)                        -- it arcs now and then at first, then faster
        st.strokes = 0
        st.flash:SetAlpha(0)
        for j, t in ipairs(st.bolts) do
            local beat = st.beat + j * 0.47                             -- each keeps its own time
            local n, k = floor(beat), (beat % 1) / 0.45
            if edge < 24 * s or k > 1 then
                t:SetAlpha(0)
            else
                local r1, r2 = (n * 0.618 + j * 0.31) % 1, (n * 0.377 + j * 0.73) % 1    -- where, and how long
                local len = min(edge, (30 + 64 * r2) * (0.55 + 0.45 * p) * s)             -- and longer as it builds
                t:SetTexCoord(r2 > 0.5 and 1 or 0, r2 > 0.5 and 0 or 1, r1 > 0.5 and 1 or 0, r1 > 0.5 and 0 or 1)
                Put(art, t, len / 2 + (edge - len) * r1, (r1 - 0.5) * 4 * s, len, (13 + 9 * p * r2) * s)
                t:SetAlpha((1 - k) * (0.75 + 0.25 * sin(now * 70 + j)))
                st.strokes = st.strokes + 1
            end
        end
        if edge < 6 then
            st.crackle:SetAlpha(0)
        else
            local flip = floor(now * 14) % 2 == 0
            st.crackle:SetTexCoord(0, 0.4, flip and 0 or 1, flip and 1 or 0)          -- a short piece of a stroke
            Put(art, st.crackle, edge - 7 * s, 0, 18 * s, (11 + 6 * p) * s)
            st.crackle:SetAlpha((floor(now * 23) % 3 == 0 and 0.7 or 0.3) * (0.5 + 0.5 * p))
        end
    end,
    finish = function(art, k, now, landed)
        local st = art.state
        st.crackle:SetAlpha(0)
        for j, t in ipairs(st.bolts) do t:SetAlpha(0) end
        if not landed then return end
        local t = st.bolts[1]                                           -- one last stroke the length of the bar
        t:SetTexCoord(0, 1, 0, 1)
        Put(art, t, art.w / 2, 0, art.w, 22 * art.scale)
        t:SetAlpha(1)
        Put(art, st.flash, art.w / 2, 0, art.w * 1.15, (art.h + 34 * art.scale) * (0.7 + k))   -- in a flash of light
        st.flash:SetAlpha(1)
    end,
}

-- A heal: a vine winds along what is filled and flowers open on it, one after another, turning as they
-- open. When the heal lands they all swell. A holy heal's are gold.
local function FlowerAt(art, t, j, n, open, swell, now)
    local s = art.scale
    local up = j % 2 == 1
    local size = 14 * s * open * (1 + swell)
    Put(art, t, (j - 0.5) * art.w / n, (up and 1 or -1) * (art.h / 2 + 3 * s), size)
    Turn(t, (1 - open) * 1.4 * (up and 1 or -1) + sin(now * 1.5 + j) * 0.08)
    t:SetAlpha(1)
end

STYLES.vines = {
    start = function(art)
        local st, c = art.state, art.color
        local r, g, b = 1, 1, 1
        if art.look.school and art.look.school ~= "nature" then r, g, b = 0.6 + c[1] * 0.4, 0.6 + c[2] * 0.4, 0.6 + c[3] * 0.4 end
        st.strip = art:Piece("vine", nil, r, g, b)
        st.flowers, st.opened = {}, 0
        local n = max(2, min(art.light and 3 or 5, floor(art.w / (40 * art.scale))))
        for j = 1, n do st.flowers[j] = art:Piece("flower", nil, r, g, b) end
    end,
    update = function(art, edge, p, now)
        local s, st = art.scale, art.state
        if edge < 3 then
            st.strip:SetAlpha(0)
        else
            st.strip:SetTexCoord(0, Clamp01(edge / art.w), 0, 1)       -- only as much of the vine as has grown
            Put(art, st.strip, edge / 2, 0, edge, 22 * s)
            st.strip:SetAlpha(0.95)
        end
        local n = #st.flowers
        st.opened = 0
        for j, t in ipairs(st.flowers) do
            local open = Clamp01((edge - (j - 0.5) * art.w / n) / (18 * s))
            if open <= 0 then
                t:SetAlpha(0)
            else
                if open >= 1 then st.opened = st.opened + 1 end
                FlowerAt(art, t, j, n, open, 0, now)
            end
        end
    end,
    finish = function(art, k, now, landed)
        if not landed then return end
        local st = art.state
        for j, t in ipairs(st.flowers) do FlowerAt(art, t, j, #st.flowers, 1, 0.4 * sin(k * pi), now) end
    end,
}

-- A holy heal: wounds along the bar that the light sears shut as the cast reaches them, each flaring white
-- hot and cooling to a warm golden seam; a bright edge runs with the cast, and the bar blazes when it lands.
STYLES.sear = {
    start = function(art)
        local st = art.state
        st.wounds, st.closed = {}, 0
        for j = 1, art.light and 2 or 4 do
            st.wounds[j] = { cut = art:Piece("bolt", nil, 0.5, 0.06, 0.06), seam = art:Piece("bolt", "ADD", 1, 0.9, 0.55) }
        end
        st.edge = art:Piece("spark", "ADD", 1, 0.96, 0.75)
        st.blaze = art:Piece("soft", "ADD", 1, 0.92, 0.6)
    end,
    update = function(art, edge, p, now)
        local s, st = art.scale, art.state
        local n = #st.wounds
        local span = art.w / n
        st.closed = 0
        st.blaze:SetAlpha(0)
        for j, w in ipairs(st.wounds) do
            local x = (j - 0.5) * span
            local k = Clamp01((edge - (x - span * 0.4)) / (span * 0.8))   -- how far the light has run along this one
            local flip = j % 2 == 0
            w.cut:SetTexCoord(flip and 1 or 0, flip and 0 or 1, 0, 1)
            w.seam:SetTexCoord(flip and 1 or 0, flip and 0 or 1, 0, 1)
            Put(art, w.cut, x, 0, span * 0.8, 12 * s)
            w.cut:SetAlpha(0.75 * (1 - k))                                -- the wound, closing
            Put(art, w.seam, x, 0, span * 0.8, (12 + 6 * sin(k * pi)) * s)
            w.seam:SetAlpha(k <= 0 and 0 or (0.35 + 0.65 * sin(k * pi)))  -- white hot as it sears, a warm seam after
            if k >= 1 then st.closed = st.closed + 1 end
        end
        if edge < 4 then
            st.edge:SetAlpha(0)
        else
            Put(art, st.edge, edge, 0, 12 * s, art.h + 14 * s)
            st.edge:SetAlpha(0.6 + 0.3 * sin(now * 11))
        end
    end,
    finish = function(art, k, now, landed)
        local st = art.state
        st.edge:SetAlpha(0)
        if not landed then return end
        Put(art, st.blaze, art.w / 2, 0, art.w * (1.1 + 0.3 * k), (art.h + 26 * art.scale) * (1 + k))
        st.blaze:SetAlpha(1)
    end,
}

-- A physical cast (an aimed shot, a slam) keeps the plain bar: only a glint of steel runs along what is filled
STYLES.glint = {
    start = function(art) art.state.glint = art:Piece("spark", "ADD", 1, 1, 1) end,
    update = function(art, edge, p, now)
        local t = art.state.glint
        local k = (now * 0.9) % 1.6
        if edge < 10 or k > 1 then
            t:SetAlpha(0)
        else
            Put(art, t, k * edge, 0, 9 * art.scale, art.h + 8 * art.scale)
            t:SetAlpha(0.55 * sin(k * pi))
        end
    end,
}

-- Runes hovering over the bar: faint until the cast reaches them, then they take shape and shimmer
STYLES.runes = {
    start = function(art)
        local st, c = art.state, art.color
        st.runes = {}
        for j = 1, art.light and 3 or 5 do
            local t = art:Piece("runes", "ADD", 0.5 + c[1] * 0.5, 0.5 + c[2] * 0.5, 0.5 + c[3] * 0.5)
            local g = (j - 1) % 4
            t:SetTexCoord(g / 4, (g + 1) / 4, 0, 1)
            st.runes[j] = t
        end
    end,
    update = function(art, edge, p, now)
        local s, st = art.scale, art.state
        local n = #st.runes
        st.shaped = 0
        for j, t in ipairs(st.runes) do
            local x = (j - 0.5) * art.w / n
            local k = Clamp01((edge - x + 8 * s) / (16 * s))
            if k >= 1 then st.shaped = st.shaped + 1 end
            local size = 15 * s * (1.6 - 0.6 * k)
            Put(art, t, x, art.h / 2 + 10 * s + sin(now * 2 + j * 1.7) * 2 * s, size)
            t:SetAlpha(0.14 + k * (0.6 + 0.26 * sin(now * 9 + j * 2.1)))
        end
    end,
    finish = function(art, k, now, landed)
        if not landed then return end
        local s, st = art.scale, art.state
        local n = #st.runes
        for j, t in ipairs(st.runes) do                                 -- the spell is cast: they flare and lift away
            Put(art, t, (j - 0.5) * art.w / n, art.h / 2 + (10 + k * 12) * s, 15 * s * (1 + k * 0.9))
            t:SetAlpha(1)
        end
    end,
}

-- Fire: it kindles (a couple of low flickers), catches (the flames stand up one after another) and roars as
-- the cast nears its end; when it lands they leap and are gone in a flash. Each is the painted flame with
-- its own glow over it.
local function Heat(p)                                     -- how big the fire is at this point of the cast
    if p < 0.25 then return 0.4 + p * 0.6 end              -- kindling
    if p < 0.45 then return 0.55 + (p - 0.25) * 2.5 end    -- it catches
    return 1.05 + (p - 0.45) * 0.55                        -- and builds
end
A.Heat = Heat

local function FlameAt(art, f, x, tall, glow)
    Put(art, f[1], x, art.h / 2 + tall * 0.4, tall * 0.8, tall)
    f[1]:SetAlpha(0.95)
    Put(art, f[2], x, art.h / 2 + tall * 0.4, tall * 0.8, tall)
    f[2]:SetAlpha(glow)
end

STYLES.flames = {
    start = function(art)
        local st = art.state
        st.flames, st.x, st.lit = {}, {}, 0
        for j = 1, art.light and 3 or 8 do
            st.flames[j] = { art:Piece("flame"), art:Piece("flame", "ADD", 1, 0.8, 0.5) }
        end
        st.flash = art:Piece("soft", "ADD", 1, 0.55, 0.15)
    end,
    update = function(art, edge, p, now)
        local s, st = art.scale, art.state
        local n = #st.flames
        local base = 13 * Heat(p) * s
        local lit = max(2, math.ceil(n * Clamp01(0.25 + p * 1.1)))      -- how many burn yet
        st.lit = edge < 5 and 0 or lit
        st.flash:SetAlpha(0)
        for j, f in ipairs(st.flames) do
            local lead = j == n                                         -- the last one burns at the very edge
            if edge < 5 or not (lead or j < lit) then
                f[1]:SetAlpha(0)
                f[2]:SetAlpha(0)
            else
                local x = lead and edge or (edge * (j - 0.5) / max(1, lit - 1) + sin(now * 3 + j * 1.9) * 1.5 * s)
                local tall = base * (lead and 1.45 or 1)
                    * (0.72 + 0.28 * sin(now * 13 + j * 2.4) + 0.12 * sin(now * 29 + j))
                st.x[j] = x
                FlameAt(art, f, x, tall, 0.3 + 0.2 * sin(now * 17 + j * 1.3))
            end
        end
    end,
    finish = function(art, k, now, landed)
        if not landed then return end
        local s, st = art.scale, art.state
        for j, f in ipairs(st.flames) do                                -- they leap
            if st.x[j] then FlameAt(art, f, st.x[j], 13 * Heat(1) * s * (1 + 1.4 * k), 0.6) end
        end
        Put(art, st.flash, art.w / 2, art.h / 2, art.w * 1.2, (art.h + 44 * s) * (0.6 + k))
        st.flash:SetAlpha(1)
    end,
}

-- Ice freezing onto the bar, crystal by crystal, with a glint passing over; it shatters when the cast lands
local function CrystalAt(art, t, j, x, grow, drift, spin)
    local s = art.scale
    local up = j % 2 == 1
    local size = (13 + (j * 37) % 6) * s * grow
    if up then t:SetTexCoord(0, 1, 0, 1) else t:SetTexCoord(0, 1, 1, 0) end
    Put(art, t, x + (drift or 0) * ((j % 3) - 1), (up and 1 or -1) * (art.h / 2 + size * 0.28 + (drift or 0)),
        size * 0.9, size)
    Turn(t, (((j * 53) % 7) - 3) * 0.07 + (spin or 0) * (up and 1 or -1))
end

STYLES.crystals = {
    start = function(art)
        local st = art.state
        st.crystals = {}
        for j = 1, art.light and 3 or 7 do st.crystals[j] = art:Piece("crystal") end
        st.glint = art:Piece("spark", "ADD", 0.85, 0.96, 1)
    end,
    update = function(art, edge, p, now)
        local s, st = art.scale, art.state
        local n = #st.crystals
        st.frozen = 0
        for j, t in ipairs(st.crystals) do
            local x = (j - 0.5) * art.w / n
            local grow = Clamp01((edge - x) / (9 * s))
            if grow <= 0 then
                t:SetAlpha(0)
            else
                if grow >= 1 then st.frozen = st.frozen + 1 end
                CrystalAt(art, t, j, x, grow)
                t:SetAlpha(0.95)
            end
        end
        local gx = ((now * 0.55) % 1.3) * edge
        if edge < 8 or gx > edge then
            st.glint:SetAlpha(0)
        else
            Put(art, st.glint, gx, 0, 10 * s, art.h + 10 * s)
            st.glint:SetAlpha(0.6)
        end
    end,
    finish = function(art, k, now, landed)
        local st = art.state
        st.glint:SetAlpha(0)
        if not landed then return end
        local n = #st.crystals
        for j, t in ipairs(st.crystals) do                              -- they burst off the bar
            CrystalAt(art, t, j, (j - 0.5) * art.w / n, 1, k * 16 * art.scale, k * 1.6)
            t:SetAlpha(0.95)
        end
    end,
}

-- A dark haze over what is filled, with little shades drifting through it and fading in and out
STYLES.wisps = {
    start = function(art)
        local st = art.state
        st.haze = art:Piece("soft", nil, 0.2, 0.08, 0.32)
        st.wisps = {}
        for j = 1, art.light and 1 or 2 do st.wisps[j] = art:Piece("ghost") end
    end,
    update = function(art, edge, p, now)
        local s, st = art.scale, art.state
        if edge < 4 then
            st.haze:SetAlpha(0)
        else
            Put(art, st.haze, edge / 2, 0, edge + 20 * s, art.h + 18 * s)
            st.haze:SetAlpha(0.45 + 0.15 * sin(now * 2.2))
        end
        local span = max(edge, 24 * s)
        local n = #st.wisps
        for j, t in ipairs(st.wisps) do
            local swing = now * 1.25 + j * 2.3
            local x = min(art.w, max(0, span * (j / (n + 1)) + sin(swing) * 16 * s))
            local size = 18 * s * (0.9 + 0.15 * sin(now * 3 + j))
            if cos(swing) >= 0 then t:SetTexCoord(0, 1, 0, 1) else t:SetTexCoord(1, 0, 0, 1) end   -- it faces its way
            Put(art, t, x, sin(now * 2.1 + j * 1.7) * (art.h / 2 + 7 * s), size)
            t:SetAlpha(max(0, 0.5 + 0.4 * sin(now * 1.6 + j * 2.9)))
        end
    end,
}

-- Rays of light rising off what is filled
STYLES.rays = {
    start = function(art)
        local st, c = art.state, art.color
        st.rays = {}
        for j = 1, art.light and 3 or 6 do st.rays[j] = art:Piece("spark", "ADD", c[1], c[2], c[3]) end
        st.flash = art:Piece("soft", "ADD", c[1], c[2], c[3])
    end,
    update = function(art, edge, p, now)
        local s, st = art.scale, art.state
        local n = #st.rays
        local up = max(1, math.ceil(n * (0.34 + 0.66 * p)))            -- one or two at first, all of them by the end
        st.flash:SetAlpha(0)
        for j, t in ipairs(st.rays) do
            if edge < 5 or j > up then
                t:SetAlpha(0)
            else
                local phase = (now * 0.9 + j * 0.37) % 1
                Put(art, t, edge * (j - 0.5) / up, art.h / 2 + phase * (12 + 8 * p) * s, 8 * s, (12 + 6 * p) * s * (1 - phase * 0.4))
                t:SetAlpha((1 - phase) * 0.75)
            end
        end
    end,
    finish = function(art, k, now, landed)
        if not landed then return end
        local st = art.state
        Put(art, st.flash, art.w / 2, 0, art.w * 1.1, (art.h + 30 * art.scale) * (0.7 + k))
        st.flash:SetAlpha(1)
    end,
}

-- Fishing: rings spreading on the water around the float at the end of the line
STYLES.ripples = {
    start = function(art)
        local st = art.state
        st.rings = {}
        for i = 1, 2 do st.rings[i] = art:Piece("ring", nil, 0.75, 0.92, 1) end
    end,
    update = function(art, edge, p, now)
        local s, st = art.scale, art.state
        for i, t in ipairs(st.rings) do
            local phase = (now * 0.6 + i * 0.5) % 1
            local w = (10 + 32 * phase) * s
            Put(art, t, edge, -1, w, w * 0.32)
            t:SetAlpha((1 - phase) * 0.7)
        end
    end,
}

---------------------------------------------------------------------------
-- An Art
---------------------------------------------------------------------------
-- A tool struck the bar: chips fly (your own bar only; nameplates stay calm)
function A.Strike(art)
    if art.light or not (ns.db.impactFx and ns.Impact and art.look and art.look.fx) then return end
    ns.Impact:Burst(art.bar, art.look, 0.6)
end

-- bar: one of ours (ns.CreateBar); scale: how big the pieces are; light: fewer of them (nameplates)
function A.Attach(bar, scale, light)
    local art = setmetatable({ bar = bar, scale = scale or 1, light = light and true or false, pieces = {}, n = 0,
                               state = {} }, Art)
    local layer = CreateFrame("Frame", nil, bar:GetParent())
    layer:SetAllPoints(bar)
    layer:SetFrameLevel((bar.over and bar.over:GetFrameLevel() or bar:GetFrameLevel()) + 3)
    layer:Hide()
    art.layer = layer
    return art
end

-- look: what CastLook.Look gives ({ kind =, color =, fx = }); false when this kind of cast has no show
function Art:Start(look)
    self:Stop()
    local key = look and A.STYLE_OF[look.kind] or ""
    if look and look.kind == "heal" and look.school == "holy" then key = "sear" end      -- light, not leaves
    local style = STYLES[key]
    if not style or not ns.db.castArt then return false end
    self.look, self.kind, self.style, self.color = look, look.kind, style, look.color or { 1, 1, 1 }
    self.bursts = style.bursts and not self.light or false
    self.w, self.h = self.bar:GetWidth() or 100, self.bar:GetHeight() or 8
    if self.w < 1 then self.w = 100 end
    self.n, self.state = 0, {}
    style.start(self)
    self.layer:SetAlpha(1)
    self.layer:Show()
    return true
end

-- fill: how full the bar is drawn (0-1); progress: how far along the cast is (0-1); now: GetTime()
function Art:Update(fill, progress, now)
    local style = self.style
    if not style then return end
    if self.finishing then
        local k = (now - self.finishing) / A.FADE
        if k >= 1 then self:Stop(); return end
        self.layer:SetAlpha(1 - k)
        if style.finish then style.finish(self, k, now, self.landed) end
        return
    end
    if not fill then return end
    local w = self.bar:GetWidth()
    if type(w) == "number" and w > 1 then self.w = w end
    self.edge = fill * self.w
    style.update(self, self.edge, progress or 0, now)
end

function Art:Finish(landed, now)
    if not self.style or self.finishing then return end
    self.finishing, self.landed = now or GetTime(), landed and true or false
end

function Art:Stop()
    for i = 1, #self.pieces do self.pieces[i]:Hide() end
    self.layer:Hide()
    self.style, self.kind, self.look, self.finishing, self.landed, self.bursts, self.edge = nil
end

-- How many pieces are on screen (for the self-check and the tests)
function Art:Shown()
    local n = 0
    for i = 1, #self.pieces do
        local t = self.pieces[i]
        if t:IsShown() and (t:GetAlpha() or 0) > 0 then n = n + 1 end
    end
    return n
end

-- /cchud casttest: every show once, on your cast bar
ns.RegisterCommand("casttest", function()
    local CB = ns.CastBar
    if not (CB and CB.Demo) then return end
    CB:Demo()
end, "/cchud casttest", "show every cast bar animation once, on your cast bar")
