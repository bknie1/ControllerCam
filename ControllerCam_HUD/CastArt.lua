-- ControllerCam HUD: what works on a cast bar while it fills.
-- A cast bar shows what is being cast, not only how far along it is:
--   mining      a pick is hauled back and brought down on the bar once a second, in time with your swings at
--               the vein (chips fly, a crack stays); the last blow crumbles the bar and its pieces fall
--   crafting    little hammers peck at the end of the bar
--   herbs       the herb grows along the bar as it fills, as the kind of plant it is when the game names it
--               (a flower on its stem, roots under the bar, kelp swaying under water, leaves in its colour);
--               when it lands they are plucked one after another: a tug, then out, with a crumb of earth
--   skinning    a knife works along the bar and the hide lifts off what is filled, rolled up at the cut; when
--               it lands the bar peels away
--   nature      green lightning runs along it, stroke after stroke
--   lightning   the same in the pale blue of the sky
--   roots       (the spells that root a foe) roots creep along it, budding as they go
--   a heal      a vine winds along it and flowers open on it, one after another
--   a holy heal wounds along the bar that the light sears shut one by one; the bar blazes when it lands
-- Every show grows with the cast, its pieces a little smaller at the start and a little bigger as it completes.
-- Every show builds with the cast and ends on something when it lands: fire kindles, catches and leaps;
-- lightning arcs now and then, then faster, then flashes; flowers open; runes take shape; ice shatters.
--   physical    only a glint of steel
--   arcane      runes hover over the bar, faint at first, and take shape one by one as the cast reaches them
--   fire        flames burn along what is filled, taller as the cast builds
--   frost       ice crystals freeze onto the bar one after another, and shatter when it lands
--   shadow      a dark haze with shades drifting through it: hooded, hollow-eyed, their jaws hanging open
--   holy        rays of light rise off it
--   travel      (a hearthstone, a teleport) a whirlpool of calm wind gathers over the bar: wisps circle its
--               middle and are drawn in to a turning eye, wider and quicker as the cast builds; when it lands the
--               whirl opens out in a ring of light, and you are on your way home
--   fishing     the water rings around your float
--   revive      (Revive Pet) a ring of leaves sprouts round the bar like the marks of a clock, one each twelfth of
--               the cast, while a vine hand sweeps round and a heart of light beats quicker at its middle; when it
--               lands every leaf blooms and a ring of green light opens out: back to life
-- Your own cast bar wears the full show; nameplates a lighter one (fewer pieces, smaller).
-- One Art belongs to one bar: Start(look) when a cast begins, Update(fill, progress, now) every frame,
-- Finish(landed) when it ends (the art fades, in its own way), Stop() to clear it.

local ADDON, ns = ...

local A = { FADE = 0.4, GROW = { 0.85, 1.25 } }      -- pieces' size at the start of a cast and as it completes
ns.CastArt = A

ns.RegisterSetting({
    key = "castArt", kind = "boolean", default = true, command = "castart", section = "Frames",
    label = "Cast bar animations",
    tip = "a cast bar shows what is being cast: picks chip at it while mining, lightning runs along it for nature, a vine flowers for a heal, runes take shape for arcane, flames, ice and shades for fire, frost and shadow",
})

-- Which show a kind of cast gets (a kind is a key of CastLook.KINDS, a school, or "fishing")
A.STYLE_OF = {
    mining = "mine", crafting = "tool", herbs = "leaves", skinning = "peel", nature = "bolts", lightning = "bolts",
    roots = "roots",
    heal = "vines", arcane = "runes", disenchant = "runes", fire = "flames", frost = "crystals", shadow = "wisps",
    holy = "rays", travel = "whirl", physical = "glint", fishing = "ripples", revive = "revive",
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

-- The same "chance" every time for piece j (0-1), so pieces scatter unevenly without a dice roll per frame
local function Scatter(j, salt)
    local v = sin(j * 12.9898 + salt * 78.233) * 43758.5453
    return v - floor(v)
end

---------------------------------------------------------------------------
-- The shows. start(art) makes the pieces; update(art, edge, p, now) places them (edge: where the fill ends, in
-- pixels from the left; p: how far along the cast is, 0-1); finish(art, k, now, landed) is the way out (k 0-1).
---------------------------------------------------------------------------
local STYLES = {}
A.STYLES = STYLES
-- The shows of the main abilities (CastSig.lua fills this): the same three calls, their own state in art.o and
-- what makes this ability's show its own in art.sig (an entry of CastLook.SIGS)
A.SHOWS = {}
A.BARE = { start = function() end, update = function() end }     -- nothing under a show that stands alone
A.Put, A.Turn, A.Scatter, A.Clamp01 = Put, Turn, Scatter, Clamp01  -- (for CastSig.lua)

-- A tool pecking at the end of the bar (and two more working behind it on your own bar)
STYLES.tool = {
    bursts = true,
    start = function(art)
        local st = art.state
        st.tools, st.phase, st.strikes = {}, {}, 0
        local tex = art.kind == "crafting" and "hammer" or "pick"
        for i = 1, art.light and 1 or 2 do st.tools[i] = art:Piece(tex) end
        -- what you are making stands at the end of the bar, taking shape as the cast fills (your own bar)
        local icon = not art.light and art.kind == "crafting" and art.look.icon
        if icon then
            st.item = art:Piece("soft")
            st.item:SetTexture(icon)
            st.item:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end
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
        if st.item then                                     -- grey and faint at first, itself at the end
            local tone = 0.45 + 0.55 * p * p
            Put(art, st.item, art.w + 15 * s, 0, 20 * s)
            st.item:SetVertexColor(tone, tone, tone, 1)
            st.item:SetAlpha(0.3 + 0.7 * p)
        end
    end,
    finish = function(art, k, now, landed)
        local st = art.state
        if not (st.item and landed) then return end
        st.item:SetVertexColor(1, 1, 1, 1)                  -- made: it jumps out at you once
        st.item:SetAlpha(1)
        Put(art, st.item, art.w + 15 * art.scale, 0, 20 * art.scale * (1 + 0.5 * sin(Clamp01(k / 0.6) * pi)))
    end,
}

-- A pick at the vein. You swing at a vein once a second, so the pick on the bar does too: it bounces off the
-- stone, is hauled back slowly, and comes down hard on the second. Every blow throws chips and leaves a crack.
-- The blow that ends the cast breaks the bar: it falls in pieces.
STYLES.mine = {
    bursts = true, fade = 0.8, ownFade = true,
    start = function(art)
        local st, c = art.state, art.color
        st.strikes, st.beat, st.crackAt = 0, 0, {}
        st.cracks = {}
        for i = 1, art.light and 1 or 3 do st.cracks[i] = art:Piece("bolt", nil, 0.12, 0.08, 0.05) end
        st.flash = art:Piece("soft", "ADD", 1, 0.9, 0.7)
        st.chunks = {}
        if not art.light then
            for j = 1, max(6, floor(art.w / (16 * art.scale))) do st.chunks[j] = art:Piece("bar", nil, c[1], c[2], c[3]) end
        end
        st.pick = art:Piece("pick")
    end,
    update = function(art, edge, p, now)
        local s, st = art.scale, art.state
        local t = max(0, now - (art.began or now))
        local beat = t % 1
        if floor(t) > st.beat then                                   -- the second came round: it strikes
            st.beat = floor(t)
            st.strikes = st.strikes + 1
            st.hitAt, st.hitX = now, edge
            st.crackAt[((st.strikes - 1) % #st.cracks) + 1] = edge
            A.Strike(art)
        end
        local lift
        if beat < 0.12 then
            lift = 0.35 * (beat / 0.12)                              -- it bounces off the stone,
        elseif beat < 0.78 then
            local k = (beat - 0.12) / 0.66
            lift = 0.35 + 0.65 * k * (2 - k)                         -- is hauled back, slowing at the top,
        else
            local k = (beat - 0.78) / 0.22
            lift = 1 - k * k                                         -- and comes down hard
        end
        st.lift = lift
        local size = 30 * s
        Put(art, st.pick, max(edge, 6 * s) - size * 0.40, art.h / 2 + size * 0.10 + lift * 10 * s, size)
        Turn(st.pick, lift * 1.25)
        st.pick:SetAlpha(1)
        local since = st.hitAt and (now - st.hitAt) or 1
        if since < 0.18 then
            Put(art, st.flash, st.hitX, 0, (26 + 60 * since) * s, art.h + 16 * s)
            st.flash:SetAlpha(1 - since / 0.18)
        else
            st.flash:SetAlpha(0)
        end
        for i, crack in ipairs(st.cracks) do
            if st.crackAt[i] then
                Put(art, crack, st.crackAt[i], 0, 18 * s, art.h + 6 * s)
                crack:SetAlpha(0.8)
            else
                crack:SetAlpha(0)
            end
        end
        for _, chunk in ipairs(st.chunks) do chunk:SetAlpha(0) end
    end,
    finish = function(art, k, now, landed)
        local s, st = art.scale, art.state
        if not landed or art.light then art.layer:SetAlpha(1 - k); return end
        if not st.crumbled then                                      -- the last blow
            st.crumbled = true
            st.strikes = st.strikes + 1
            A.Strike(art)
            A.HideBar(art)
        end
        local size = 30 * s
        Put(art, st.pick, art.w - size * 0.40, art.h / 2 + size * 0.10, size)
        Turn(st.pick, 0)
        st.pick:SetAlpha(1 - Clamp01(k * 2.2))
        Put(art, st.flash, art.w, 0, (30 + 90 * k) * s, art.h + 22 * s)
        st.flash:SetAlpha(1 - Clamp01(k * 4))
        for _, crack in ipairs(st.cracks) do crack:SetAlpha(0) end
        local n = #st.chunks
        local wide = art.w / n
        local t = k * STYLES.mine.fade
        for j, chunk in ipairs(st.chunks) do
            local a, b, c = Scatter(j, 1), Scatter(j, 2), Scatter(j, 3)
            local u = max(0, t - (1 - j / n) * 0.18)                 -- the pieces by the blow go first
            Put(art, chunk, (j - 0.5) * wide + (a - 0.5) * 44 * s * u, (18 + 34 * b) * s * u - 330 * s * u * u,
                wide * (0.7 + 0.3 * c), art.h * (0.8 + 0.4 * b))    -- a hop, then it falls
            Turn(chunk, (a - 0.5) * 9 * u)
            chunk:SetAlpha(1 - Clamp01((k - 0.55) / 0.45))
        end
    end,
}

-- Herbs: what sprouts along the top of the bar goes by the kind of plant the herb is (CastLook.Own: look.form),
-- when the game names it:
--   flower   a whole plant: a stem out of the bar, the herb's own flower on its tip, the leaf off its foot
--   root     leaves over the bar and the herb's roots creeping down under it; plucked, the roots come up too
--   kelp     strands of it swaying in the water, bubbles rising; when it comes loose it drifts up and away
--   leaf     leaves in the herb's own colour, no flower
--   (none)   plain leaves: nobody said which herb it is
-- Under water (look.wet) bubbles rise off the bar, whatever grows there. When the herb is yours it is plucked,
-- one plant after another from the left: each is tugged (it stretches, held by its root), comes free with a jump
-- and a spin, and drops a crumb of earth (none under water).
local STEM, LEAF_AT, LEAF_OUT = 19, 0.15, 0.85      -- the stem's height; how far up it the leaf sits; its lean
local ROOT = { 0.6, 0.42, 0.26 }                    -- a root whose herb's colour is not known

-- Plant j: its stem's middle at px, py, the whole of it turned by r (the leaf leaning a off the stem)
local function Plant(art, st, j, px, py, tall, lw, lh, a, r, alpha, open)
    local s = art.scale
    local stem, leaf, f = st.stems[j], st.leaves[j], st.flowers[j]
    Put(art, stem, px, py, 1.5 * s, max(0.01, tall))
    Turn(stem, r)
    stem:SetAlpha(alpha)
    local up = tall * (0.5 - LEAF_AT)                   -- the leaf's foot, this far below the stem's middle
    local bx, by = px + sin(r) * up, py - cos(r) * up
    Put(art, leaf, bx - sin(a + r) * 0.42 * lh, by + cos(a + r) * 0.42 * lh, lw, lh)
    Turn(leaf, a + r)
    leaf:SetAlpha(alpha)
    Put(art, f, px - sin(r) * tall / 2, py + cos(r) * tall / 2, max(0.01, 10 * s * open))
    Turn(f, r)
    f:SetAlpha(open > 0 and alpha or 0)
end

-- Plant j's roots, down from x, y: a longer one and a shorter that forks off it, the pair turned by r
local function Roots(art, st, j, x, y, grow, r, alpha)
    local s = art.scale
    local long = (11 + 4 * Scatter(j, 4)) * s * grow
    local lean = (Scatter(j, 2) - 0.5) * 0.5 + r
    for k, t in ipairs(st.roots[j]) do
        local len = max(0.01, k == 1 and long or long * 0.6)
        local a = k == 1 and lean or lean + ((j % 2 == 0) and 0.7 or -0.7)
        Put(art, t, x + sin(a) * len / 2, y - cos(a) * len / 2, (k == 1 and 1.8 or 1.3) * s, len)
        Turn(t, a)
        t:SetAlpha(alpha)
    end
end

-- Strand j of kelp, up from x, y: three blades one over another, swaying, each a little further than the one
-- under it (loose: how far it has come free, 0-1, which lets it sway wider)
local function Kelp(art, st, j, x, y, grow, now, loose, alpha)
    local s = art.scale
    for k, seg in ipairs(st.kelp[j]) do
        local g = Clamp01(grow * 3 - (k - 1))
        if g <= 0 then
            seg:SetAlpha(0)
        else
            local wave = sin(now * 1.7 + j * 1.3 + k * 0.9)
            Put(art, seg, x + wave * (1.6 + 3 * loose) * s * k, y + (k - 0.45) * 6.5 * s, 9 * s * g)
            Turn(seg, -wave * 0.45)
            seg:SetAlpha(alpha)
        end
    end
end

-- Bubbles rising off what is filled (under water), each on its own beat
local function Bubbles(art, st, edge, now, alpha)
    if not st.bubbles then return end
    local s = art.scale
    for i, t in ipairs(st.bubbles) do
        local x = Scatter(i, 1) * art.w
        if x > edge or alpha <= 0 then
            t:SetAlpha(0)
        else
            local k = (now * (0.4 + 0.3 * Scatter(i, 2)) + Scatter(i, 3)) % 1
            Put(art, t, x + sin(now * 3 + i) * 1.5 * s, art.h / 2 + k * 24 * s, (2.5 + 2.5 * Scatter(i, 4)) * s)
            t:SetAlpha(0.65 * (1 - k) * alpha)
        end
    end
end

-- Nothing of plant j shows (the cast has not reached it)
local function NoPlant(st, j)
    st.leaves[j]:SetAlpha(0)
    if st.flowers then st.flowers[j]:SetAlpha(0); st.stems[j]:SetAlpha(0) end
    if st.roots then for _, t in ipairs(st.roots[j]) do t:SetAlpha(0) end end
    if st.kelp then for _, t in ipairs(st.kelp[j]) do t:SetAlpha(0) end end
end

STYLES.leaves = {
    fade = 0.8, ownFade = true,
    start = function(art)
        local st, look = art.state, art.look
        local form = not art.light and look.form or nil
        local b = form == "flower" and look.bloom or nil
        st.form, st.leaves, st.crumbs = form, {}, {}
        local n = max(2, floor(art.w / (30 * art.scale)))
        if b then                                       -- (the stems first: they stand behind leaf and flower)
            st.stems = {}
            for j = 1, n do st.stems[j] = art:Piece("bar", nil, 0.33, 0.55, 0.2) end
        end
        if form == "root" then                          -- (and the roots, in the herb's colour)
            local c = look.tint or ROOT
            st.roots = {}
            for j = 1, n do
                st.roots[j] = { art:Piece("bar", nil, c[1], c[2], c[3]), art:Piece("bar", nil, c[1] * 0.8, c[2] * 0.8, c[3] * 0.8) }
            end
        end
        local r, g, bl = 1, 1, 1                        -- the leaves: the herb's own colour for kelp and leafy herbs
        local tint = (form == "leaf" or form == "kelp") and look.tint
        if tint then
            local keep = form == "kelp" and 0.3 or 0.5
            r, g, bl = keep + (1 - keep) * tint[1], keep + (1 - keep) * tint[2], keep + (1 - keep) * tint[3]
        end
        for j = 1, n do st.leaves[j] = art:Piece("leaf", nil, r, g, bl) end
        if form == "kelp" then
            st.kelp = {}
            for j = 1, n do st.kelp[j] = { st.leaves[j], art:Piece("leaf", nil, r, g, bl), art:Piece("leaf", nil, r, g, bl) } end
        end
        if b then
            st.flowers = {}
            for j = 1, n do st.flowers[j] = art:Piece("flower", nil, b[1], b[2], b[3]) end
        end
        if art.light then return end
        if look.wet then
            st.bubbles = {}
            for i = 1, n * 2 do st.bubbles[i] = art:Piece("soft", "ADD", 0.75, 0.92, 1) end
        else
            for j = 1, n do st.crumbs[j] = art:Piece("soft", nil, 0.42, 0.3, 0.18) end
        end
    end,
    update = function(art, edge, p, now)
        local s, st = art.scale, art.state
        local n = #st.leaves
        Bubbles(art, st, edge, now, 1)
        for j, t in ipairs(st.leaves) do
            local x = (j - 0.5) * art.w / n
            local grow = Clamp01((edge - x) / (12 * s))
            if grow <= 0 then
                NoPlant(st, j)
            else
                local size = (14 + (j * 5) % 4) * s * grow
                local sway = sin(now * 2.2 + j) * 0.22
                if st.kelp then
                    Kelp(art, st, j, x, art.h / 2, grow, now, 0, 1)
                elseif st.flowers then                      -- the flower opens once the plant has grown
                    local tall = STEM * s * grow
                    local open = Clamp01((edge - x - 12 * s) / (14 * s))
                    Plant(art, st, j, x, art.h / 2 + tall / 2, tall, size, size,
                        sway + ((j % 2 == 0) and LEAF_OUT or -LEAF_OUT), 0, 1, open)
                else
                    Put(art, t, x, art.h / 2 + size * 0.42, size)
                    Turn(t, sway + ((j % 2 == 0) and 0.45 or -0.45))
                    t:SetAlpha(1)
                    if st.roots then Roots(art, st, j, x, -art.h / 2, grow, 0, 1) end
                end
            end
        end
    end,
    finish = function(art, k, now, landed)
        local s, st = art.scale, art.state
        if not landed or art.light then art.layer:SetAlpha(1 - k); return end
        local n = #st.leaves
        local picked = 0
        Bubbles(art, st, art.w, now, 1 - k)
        for j, t in ipairs(st.leaves) do
            local u = Clamp01((k - (j - 1) / n * 0.5) / 0.5)        -- one after another, from the left
            local size = (14 + (j * 5) % 4) * s
            local x0 = (j - 0.5) * art.w / n
            local x, y, w, h = x0, art.h / 2 + size * 0.42, size, size
            local rest = (j % 2 == 0) and 0.45 or -0.45
            local lean, alpha, v = rest, 1, 0
            if u < 0.3 then                                         -- the tug: it stretches, held by its root
                local g = sin(u / 0.3 * pi / 2)
                w, h, y = size * (1 - 0.15 * g), size * (1 + 0.35 * g), y + size * 0.17 * g
                lean = lean * (1 - g)
            else                                                    -- and it comes free: a jump and a spin
                v = (u - 0.3) / 0.7
                picked = picked + 1
                y = y + (30 + 8 * Scatter(j, 3)) * s * (1 - (1 - v) * (1 - v))
                x = x + (Scatter(j, 5) - 0.5) * 16 * s * v
                lean = lean + ((j % 2 == 0) and 1.4 or -1.4) * v
                alpha = 1 - Clamp01((v - 0.55) / 0.45)
            end
            if st.kelp then                                         -- kelp comes loose and drifts up, swaying
                Kelp(art, st, j, x0 + (Scatter(j, 5) - 0.5) * 10 * s * v, art.h / 2 + 26 * s * v * (2 - v), 1, now, v, alpha)
            elseif st.flowers then                                  -- the whole plant: stem, leaf and flower
                local out = (j % 2 == 0) and LEAF_OUT or -LEAF_OUT
                if v > 0 then
                    local tall = STEM * s
                    Plant(art, st, j, x, y - size * 0.42 + tall / 2, tall, size, size, out, lean - rest, alpha, 1)
                else
                    local tall = STEM * s * h / size
                    Plant(art, st, j, x0, art.h / 2 + tall / 2, tall, w, h, out, 0, 1, 1)
                end
            else
                Put(art, t, x, y, w, h)
                Turn(t, lean)
                t:SetAlpha(alpha)
                if st.roots then
                    if v > 0 then                                   -- out they come, hanging off the leaf's foot
                        Roots(art, st, j, x + 0.42 * h * sin(lean), y - 0.42 * h * cos(lean), 1, lean - rest, alpha)
                    else
                        Roots(art, st, j, x0, -art.h / 2, 1, 0, 1)
                    end
                end
            end
            local crumb = st.crumbs[j]
            if crumb then                                           -- earth from where it stood
                if v > 0 and v < 1 then
                    Put(art, crumb, x0 + (Scatter(j, 7) - 0.5) * 14 * s * v, art.h / 2 + 10 * s * v - 34 * s * v * v, 4 * s)
                    crumb:SetAlpha(1 - v)
                else
                    crumb:SetAlpha(0)
                end
            end
        end
        st.plucked = picked > 0 and picked or nil
    end,
}

-- Skinning: the hide lifts off the top of what is filled, rolled up where the knife is: a skinning knife works
-- at the cut, its point under the roll, sawing as it goes. When the cast lands the knife is put away and the bar
-- itself peels away, strip after strip from the left, each curling up as it goes.
local KNIFE = 0.95                 -- how the knife is held: its grip up and to the right of its point (radians)
STYLES.peel = {
    fade = 0.75, ownFade = true,
    start = function(art)
        local st, c = art.state, art.color
        local pale = { c[1] + (1 - c[1]) * 0.5, c[2] + (1 - c[2]) * 0.5, c[3] + (1 - c[3]) * 0.5 }
        st.hide = art:Piece("bar", nil, pale[1], pale[2], pale[3])
        st.curl = art:Piece("disc", nil, pale[1], pale[2], pale[3])
        st.strips = {}
        if not art.light then
            st.blade = art:Piece("bar", nil, 0.84, 0.87, 0.92)
            st.grip = art:Piece("bar", nil, 0.42, 0.27, 0.15)
            for j = 1, max(5, floor(art.w / (22 * art.scale))) do st.strips[j] = art:Piece("bar", nil, c[1], c[2], c[3]) end
        end
    end,
    update = function(art, edge, p, now)
        local s, st = art.scale, art.state
        for _, strip in ipairs(st.strips) do strip:SetAlpha(0) end
        if edge < 4 then
            st.hide:SetAlpha(0)
            st.curl:SetAlpha(0)
            if st.blade then st.blade:SetAlpha(0); st.grip:SetAlpha(0) end
            return
        end
        if st.blade then                                              -- the knife, its point at the cut
            local dx, dy = cos(KNIFE), sin(KNIFE)
            local saw = (1 + sin(now * 11)) * 1.6 * s                   -- in and out along its own length
            local long, hold = 14 * s, 7 * s
            local tx, ty = edge + 1 * s, art.h / 2 + 1 * s
            Put(art, st.blade, tx + dx * (long / 2 + saw), ty + dy * (long / 2 + saw), long, 2.4 * s)
            Put(art, st.grip, tx + dx * (long + hold / 2 + saw), ty + dy * (long + hold / 2 + saw), hold, 3.6 * s)
            Turn(st.blade, KNIFE)
            Turn(st.grip, KNIFE)
            st.blade:SetAlpha(1)
            st.grip:SetAlpha(1)
        end
        Put(art, st.hide, edge / 2, art.h / 2 + 2 * s, edge, 2.5 * s)
        st.hide:SetAlpha(0.85)
        local roll = art.h + 5 * s
        Put(art, st.curl, edge, art.h / 2 + 1.5 * s + sin(now * 9) * 0.6 * s, roll)
        st.curl:SetAlpha(1)
    end,
    finish = function(art, k, now, landed)
        local s, st = art.scale, art.state
        if not landed or art.light then art.layer:SetAlpha(1 - k); return end
        if not st.peeled then
            st.peeled = true
            A.HideBar(art)
        end
        st.hide:SetAlpha(0)
        st.curl:SetAlpha(0)
        st.blade:SetAlpha(0)
        st.grip:SetAlpha(0)
        local n = #st.strips
        local wide = art.w / n
        for j, strip in ipairs(st.strips) do
            local u = Clamp01((k - (j - 1) / n * 0.5) / 0.5)          -- one after another, from the left
            Put(art, strip, (j - 0.5) * wide - u * 10 * s, u * u * 26 * s, wide + 1, art.h)
            Turn(strip, u * 1.1)
            strip:SetAlpha(1 - u * u)
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

-- Travel: a whirlpool of calm wind. Wisps go round the middle of the bar on a flattened circle, each drawn in
-- toward the eye as it goes (then it starts again outside), the whole turning faster and opening wider as the
-- cast builds; a soft halo turns slowly at the eye. When it lands the whirl opens out in a ring of light.
STYLES.whirl = {
    fade = 0.6, ownFade = true,
    start = function(art)
        local st, c = art.state, art.color
        local soft = { c[1] * 0.5 + 0.5, c[2] * 0.5 + 0.5, c[3] * 0.5 + 0.5 }       -- calmer, paler
        st.wisps = {}
        for i = 1, art.light and 6 or 12 do st.wisps[i] = art:Piece("soft", "ADD", soft[1], soft[2], soft[3]) end
        st.eye = art:Piece("halo", "ADD", c[1], c[2], c[3])
        st.ring = art:Piece("ring", "ADD", 0.85, 0.95, 1)
        st.spin = 0
    end,
    update = function(art, edge, p, now)
        local s, st = art.scale, art.state
        local n = #st.wisps
        local cx = art.w / 2
        st.spin = now * (1.8 + 2.6 * p)
        local rx = art.w * (0.16 + 0.24 * p)
        local ry = art.h / 2 + (9 + 9 * p) * s
        for i, t in ipairs(st.wisps) do
            local life = (now * 0.5 + i / n) % 1                 -- drawn in to the eye, then out again
            local a = st.spin + i * (2 * pi / n) + life * 2.4
            local r = 1 - life * 0.8
            Put(art, t, cx + cos(a) * rx * r, sin(a) * ry * r, (11 + 8 * p) * s * (1 - life * 0.4), (4 + 3 * p) * s)
            Turn(t, a + pi / 2)                                  -- lying along its way round
            t:SetAlpha(sin(life * pi) * (0.4 + 0.55 * p))
        end
        Put(art, st.eye, cx, 0, (20 + 26 * p) * s)
        Turn(st.eye, -st.spin * 0.5)
        st.eye:SetAlpha(0.2 + 0.5 * p)
        st.ring:SetAlpha(0)
        st.last = p
    end,
    finish = function(art, k, now, landed)
        local s, st = art.scale, art.state
        local n = #st.wisps
        for i, t in ipairs(st.wisps) do                          -- the wind lets go, outward
            local a = st.spin + i * (2 * pi / n) + k * 2
            Put(art, t, art.w / 2 + cos(a) * art.w * (0.4 + 0.3 * k), sin(a) * (art.h / 2 + 18 * s) * (1 + k), 14 * s, 4 * s)
            Turn(t, a + pi / 2)
            t:SetAlpha(0.6 * (1 - k))
        end
        st.eye:SetAlpha(0.6 * (1 - k))
        if landed then
            Put(art, st.ring, art.w / 2, 0, art.w * (0.3 + 1.1 * k), (art.h + 30 * s) * (0.6 + k))
            st.ring:SetAlpha(1 - k)
        else
            st.ring:SetAlpha(0)
        end
    end,
}

-- Revive Pet: nature bringing a life back, in its own time. A dial over the middle of the bar: twelve leaves
-- sprout on a flattened circle like the marks of a clock, each when the cast reaches its hour; a vine hand sweeps
-- round from the top; a heart of soft light beats at the centre, quicker as the cast builds. When it lands each
-- leaf turns into a flower and a ring of green light opens out.
STYLES.revive = {
    fade = 0.7, ownFade = true,
    start = function(art)
        local st, c = art.state, art.color
        st.leaves, st.flowers = {}, {}
        local n = art.light and 8 or 12
        for j = 1, n do
            st.leaves[j] = art:Piece("leaf", nil, c[1], c[2], c[3])
            st.flowers[j] = art:Piece("flower", nil, 1, 1, 1)
            st.flowers[j]:SetAlpha(0)
        end
        st.hand = art:Piece("vine", nil, 1, 1, 1)
        st.heart = art:Piece("halo", "ADD", c[1], c[2], c[3])
        st.ring = art:Piece("ring", "ADD", c[1] * 0.6 + 0.4, c[2] * 0.6 + 0.4, c[3] * 0.6 + 0.4)
        st.ring:SetAlpha(0)
    end,
    update = function(art, edge, p, now)
        local s, st = art.scale, art.state
        local n = #st.leaves
        local cx = art.w / 2
        local rx, ry = math.min(art.w * 0.3, 60 * s), art.h / 2 + 14 * s
        st.rx, st.ry = rx, ry
        for j, t in ipairs(st.leaves) do
            local a = pi / 2 - (j - 1) * 2 * pi / n               -- from the top, clockwise: the hours
            local grow = Clamp01((p * n - (j - 1)) / 0.6)
            if grow <= 0 then
                t:SetAlpha(0)
            else
                Put(art, t, cx + cos(a) * rx, sin(a) * ry, 12 * s * grow)
                Turn(t, a - pi / 2 + sin(now * 2 + j) * 0.1)
                t:SetAlpha(0.95)
            end
        end
        local hand = pi / 2 - p * 2 * pi                          -- the hand sweeps round with the cast
        Put(art, st.hand, cx + cos(hand) * rx * 0.45, sin(hand) * ry * 0.45, rx * 0.9, 8 * s)
        Turn(st.hand, hand)
        st.hand:SetAlpha(0.85)
        local beat = (sin(now * (3 + 7 * p)) + 1) / 2              -- a heart coming back: quicker as it builds
        Put(art, st.heart, cx, 0, (16 + 14 * p + 6 * beat) * s)
        st.heart:SetAlpha(0.25 + 0.45 * p * (0.6 + 0.4 * beat))
    end,
    finish = function(art, k, now, landed)
        local s, st = art.scale, art.state
        local n = #st.leaves
        local cx, rx, ry = art.w / 2, st.rx or art.w * 0.3, st.ry or (art.h / 2 + 14 * s)
        for j, t in ipairs(st.leaves) do
            local a = pi / 2 - (j - 1) * 2 * pi / n
            t:SetAlpha(landed and math.max(0, 1 - k * 2) or (1 - k))
            local f = st.flowers[j]
            if landed then                                         -- every hour blooms
                local open = Clamp01(k * 2.5)
                Put(art, f, cx + cos(a) * rx * (1 + 0.25 * k), sin(a) * ry * (1 + 0.25 * k), 15 * s * open)
                Turn(f, a + k)
                f:SetAlpha(1 - Clamp01((k - 0.6) / 0.4))
            else
                f:SetAlpha(0)
            end
        end
        st.hand:SetAlpha(0.85 * (1 - k))
        st.heart:SetAlpha((landed and 0.9 or 0.4) * (1 - k))
        if landed then                                             -- back to life: the green opens out
            Put(art, st.ring, cx, 0, (rx * 2) * (0.5 + 1.2 * k), (ry * 2) * (0.5 + 1.2 * k))
            st.ring:SetAlpha(1 - k)
        else
            st.ring:SetAlpha(0)
        end
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

-- An ending that takes the bar itself apart (crumbled, plucked, peeled): the bar's own fill goes out of sight,
-- the pieces stand in for it, and it is back when the art stops. Your own bar only.
function A.HideBar(art)
    if art.light or art.hid then return end
    art.hid = true
    local bar = art.bar
    bar.fill:SetAlpha(0)
    if bar.back then bar.back:SetAlpha(0) end
    if bar.spark then bar.spark:SetAlpha(0) end
end

-- bar: one of ours (ns.CreateBar); scale: how big the pieces are; light: fewer of them (nameplates)
function A.Attach(bar, scale, light)
    local art = setmetatable({ bar = bar, scale = scale or 1, base = scale or 1, light = light and true or false,
                               pieces = {}, n = 0, state = {} }, Art)
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
    local level = ns.Effects()
    -- one of the main abilities: its own show over its school's (Full and Subtle; CastSig.lua)
    local sig = look and look.sig and level ~= "classic" and look.sig or nil
    local over = sig and A.SHOWS[sig.show] or nil
    if over and (sig.solo or not style) then style = A.BARE end
    if not style or not ns.db.castArt or level == "none" or ns.Calm() then return false end   -- (Reduce animations: none)
    self.over, self.sig, self.o, self.subtle = over, over and sig or nil, {}, level == "subtle"
    self.look, self.kind, self.style, self.color = look, look.kind, style, look.color or { 1, 1, 1 }
    self.bursts = style.bursts and not self.light or false
    self.w, self.h = self.bar:GetWidth() or 100, self.bar:GetHeight() or 8
    if self.w < 1 then self.w = 100 end
    self.n, self.state = 0, {}
    self.scale = self.base                              -- (how many pieces: by the size it has at heart)
    self.began = GetTime()                              -- (whoever knows when the cast really began says so after)
    style.start(self)
    if over then over.start(self) end
    self.layer:SetAlpha(1)
    self.layer:Show()
    return true
end

-- fill: how full the bar is drawn (0-1); progress: how far along the cast is (0-1); now: GetTime()
function Art:Update(fill, progress, now)
    local style = self.style
    if not style then return end
    if self.finishing then
        local k = (now - self.finishing) / (self.fade or A.FADE)
        if k >= 1 then self:Stop(); return end
        if not style.ownFade then self.layer:SetAlpha(1 - k) end     -- (an ending of its own fades its own pieces)
        if style.finish then style.finish(self, k, now, self.landed) end
        if self.over then self.over.finish(self, k, now, self.landed) end
        return
    end
    if not fill then return end
    local w = self.bar:GetWidth()
    if type(w) == "number" and w > 1 then self.w = w end
    self.edge = fill * self.w
    local p = progress or 0
    self.scale = self.base * (A.GROW[1] + (A.GROW[2] - A.GROW[1]) * Clamp01(p))   -- bigger as it completes
    style.update(self, self.edge, p, now)
    if self.over then self.over.update(self, self.edge, p, now) end
    self.p = p
end

function Art:Finish(landed, now)
    if not self.style or self.finishing then return end
    self.finishing, self.landed = now or GetTime(), landed and true or false
    -- an ending of its own (a bar crumbling) takes its time; a cast cut short just fades
    self.fade = (self.landed and not self.light and self.style.fade) or A.FADE
    if self.over and self.over.fade then self.fade = max(self.fade, self.over.fade) end   -- (a bolt takes its time to go)
end

-- Did one of the main abilities just fire here, and how hard does it shake the bar? (Full only; your own bar)
function Art:Kick()
    if not (self.over and self.landed) or self.subtle or self.light or ns.Calm() then return nil end
    return (self.sig.big or 1) * (self.sig.show == "reticle" and 0.6 or 1)
end

-- How long the ending that is running takes (seconds; 0 when none is)
function Art:Ending()
    return self.finishing and (self.fade or A.FADE) or 0
end

function Art:Stop()
    for i = 1, #self.pieces do self.pieces[i]:Hide() end
    self.layer:Hide()
    if self.hid then                                    -- the bar was taken out of sight for the ending: back
        self.hid = nil
        local bar = self.bar
        bar.fill:SetAlpha(1)
        if bar.back then bar.back:SetAlpha(1) end
        if bar.spark then bar.spark:SetAlpha(1) end
    end
    self.style, self.kind, self.look, self.finishing, self.landed, self.bursts, self.edge, self.fade = nil
    self.over, self.sig, self.o, self.p = nil
end

-- How many pieces are on screen (for the self-check and the tests)
function Art:Shown()
    local n = 0
    for i = 1, #self.pieces do
        local t = self.pieces[i]
        if t:IsShown() and (ns.AlphaOf(t) or 0) > 0 then n = n + 1 end
    end
    return n
end

-- /cchud casttest: every show once, on your cast bar
ns.RegisterCommand("casttest", function()
    local CB = ns.CastBar
    if not (CB and CB.Demo) then return end
    CB:Demo()
end, "/cchud casttest", "show every cast bar animation once, on your cast bar")
