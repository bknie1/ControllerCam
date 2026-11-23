-- ControllerCam HUD: a flight on film.
-- On a flight master's flight (Flights.lua's flight bar is up) the screen turns to film a few seconds after take-off,
-- as at a camp fire (Campfire.lua): black bars close in from the top and the bottom, the rest of the screen fades
-- back and the camera draws out wide and circles slowly round you and your mount, a whole turn in about a minute and
-- a half (a switch of its own leaves it a still shot). About half a minute out it comes round behind you again.
-- Where you are going comes up in the bottom bar, and each new zone you fly into after it.
--   * The flight bar rises into the top bar and stays there, readable, with the flight game's line under it.
--   * The flight game steps out of the film at once (its lane plays over the screen as ever); put away at high
--     altitude, the film comes back. A window (the map, your bags) or a button or stick of yours steps out too, and
--     the film comes back once the controller has been left alone for a few seconds.
--   * It bows out as you come in to land, just before the weather where you land is said, so you see yourself come
--     in; on a route whose time is not known yet, at the landing.
--   * A fight, the landing, the HUD stopping or a reload in the air end it at once and give everything back: the
--     screen, the flight bar's place, the camera's distance and its direction, and its offset (held by the camera
--     addon meanwhile).
-- Everything moves with one value, how far the film has come in, so it comes and goes smoothly whatever the reason.
-- With Reduce animations on the camera stays where it is and the bars fade in where they stand. Nothing of the
-- game's flight, map or buttons is touched; the frames moved are the HUD's own.

local ADDON = ...
local ns = ControllerCamHUD.ns            -- the HUD's own namespace: this file is one of its modules (Modules.lua)
local L = ns.L

local R = { active = false, shown = 0 }
ns.Ride = R


ns.RegisterSetting({
    key = "flightOrbit", kind = "boolean", default = true, command = "flightorbit", section = "Effects",
    label = "Cinematic flights: the camera circles you",
    tip = "on film, the camera circles slowly round you and your mount, a whole turn in about a minute and a half, and comes round behind you again before you land. Off: a still shot",
})

R.AFTER = 3                      -- seconds after take-off before it comes in
R.IN, R.OUT, R.QUICK = 2.5, 3.5, 0.8   -- seconds to come in, to bow out as you land, to step out of your way
R.BOW = 2                        -- it bows out this long before the weather line (Flights' WEATHER_BEFORE)
R.MIN = 25                       -- a flight with less than this left on film after take-off is not filmed at all
R.BACK = 8                       -- the controller left alone this long after a button or a stick: back on film
R.RETURN = 3                     -- back this long after the game is put away or a window closes
R.BAR = 0.11                     -- each black bar: this share of the screen's height
R.ZOOM = 8                       -- the camera draws out this much further
R.ORBIT = 4                      -- the camera circles you this fast (degrees a second: a whole turn in 90 seconds)
R.HOME_LEAD, R.HOME_TIME = 10, 12   -- coming in: it starts round behind you this long before it bows out, and takes
                                    -- this long (the shorter way round), so it is behind you as the weather is said
R.HOME = 2                       -- behind you to within this many degrees
R.VMAX, R.STEP = 30, 0.25        -- its fastest turn, and the steps its speed changes by (degrees a second)
R.STICK = 0.35                   -- a stick pushed this far is a hand on the controller
R.CAPTION = { 1.2, 7.5 }         -- where you are going: in, out (seconds of film)
R.ZONE = 5                       -- a new zone's name shows this long
R.THROTTLE = 0.2                 -- the slower checks (windows, the controller), this often

local Plain, Yes = ns.Plain, ns.Yes
local function Clamp01(k) return math.max(0, math.min(1, k)) end
local function Ease(k) k = Clamp01(k); return k * k * (3 - 2 * k) end
local function Window(t, a, b, f) return math.min(Clamp01((t - a) / f), Clamp01((b - t) / f)) end
local function Call(fn, ...)
    if type(fn) ~= "function" then return false end
    return pcall(fn, ...)
end
local function Asks(fn, ...)
    if type(fn) ~= "function" then return false end
    local ok, v = pcall(fn, ...)
    return ok and Yes(v)
end
local function Text(fn)
    local ok, v = Call(fn)
    v = ok and Plain(v) or nil
    return (type(v) == "string" and v ~= "") and v or nil
end

local function Flight()
    local F = ns.Flights
    local fl = F and F.flight
    if fl and Asks(UnitOnTaxi, "player") then return fl end
end

-- Seconds to the landing, when the flight's time is known
local function Left(fl, now)
    return fl and tonumber(fl.eta) and fl.at and (fl.eta - (now - fl.at)) or nil
end

local function BowAt()
    return ((ns.Flights and tonumber(ns.Flights.WEATHER_BEFORE)) or 15) + R.BOW
end

---------------------------------------------------------------------------
-- The film
---------------------------------------------------------------------------
local film
local function Build()
    if film then return end
    film = CreateFrame("Frame", "ControllerCamHUD_FlightFilm")      -- under nothing: the screen it fades is not its
    film:SetFrameStrata("LOW")                                      -- parent (the flight bar sits above its bars)
    film:SetAllPoints(WorldFrame or UIParent)
    film.top = film:CreateTexture(nil, "BACKGROUND")
    film.top:SetColorTexture(0, 0, 0, 1)
    film.top:SetPoint("TOPLEFT", film, "TOPLEFT", 0, 0)
    film.top:SetPoint("TOPRIGHT", film, "TOPRIGHT", 0, 0)
    film.bottom = film:CreateTexture(nil, "BACKGROUND")
    film.bottom:SetColorTexture(0, 0, 0, 1)
    film.bottom:SetPoint("BOTTOMLEFT", film, "BOTTOMLEFT", 0, 0)
    film.bottom:SetPoint("BOTTOMRIGHT", film, "BOTTOMRIGHT", 0, 0)
    film.title = ns.FontString(film, 24, "CENTER")
    film.title:SetPoint("CENTER", film.bottom, "CENTER", 0, 9)
    film.title:SetTextColor(1, 0.93, 0.8, 1)
    film.sub = ns.FontString(film, 13, "CENTER")
    film.sub:SetPoint("TOP", film.title, "BOTTOM", 0, -4)
    film.sub:SetTextColor(0.85, 0.82, 0.74, 1)
    film:Hide()
    R.frame = film
end

-- The HUD's own frames that ride along on the film while it plays: the flight bar, the flight game's line and lane
local function Riders()
    local F, G = ns.Flights, ns.FlightGame
    return { F and F.frame, G and G.hint, G and G.frame }
end

local function Adopt(s)
    for _, f in ipairs(Riders()) do
        if f and not s.adopted[f] and f.SetParent then
            local okP, parent = pcall(f.GetParent, f)
            local okS, strata = pcall(f.GetFrameStrata, f)
            s.adopted[f] = { parent = okP and parent or UIParent, strata = okS and strata or "MEDIUM" }
            pcall(f.SetParent, f, film)
            pcall(f.SetFrameStrata, f, s.adopted[f].strata)
        end
    end
    local bar = ns.Flights and ns.Flights.frame
    if bar and not s.bar and bar.GetPoint then                     -- where the flight bar sits, to give it back
        local ok, point, rel, relPoint, x, y = pcall(bar.GetPoint, bar, 1)
        if ok and point then s.bar = { f = bar, point = point, rel = rel, relPoint = relPoint, x = x or 0, y = y or 0 } end
    end
end

local function Release(s)
    local b = s.bar
    if b then
        pcall(b.f.ClearAllPoints, b.f)
        pcall(b.f.SetPoint, b.f, b.point, b.rel or UIParent, b.relPoint, b.x, b.y)
    end
    for f, rec in pairs(s.adopted) do
        pcall(f.SetParent, f, rec.parent or UIParent)
        pcall(f.SetFrameStrata, f, rec.strata)
    end
    s.adopted, s.bar = {}, nil
end

local function SetUIAlpha(a) pcall(UIParent.SetAlpha, UIParent, a) end

local function Hold(on)
    local cam = _G.ControllerCam
    if type(cam) == "table" and type(cam.Hold) == "function" then pcall(cam.Hold, on) end
end

local function YawSpeed()
    local v = GetCVar and tonumber(GetCVar("cameraYawMoveSpeed"))
    return (v and v > 0) and v or 180
end

-- The camera's turn, in degrees a second (+ to the right), in steps. Where the game will not turn it (a call
-- refused, or missing), it stays a still shot from then on.
local function StopTurning()
    Call(MoveViewRightStop)
    Call(MoveViewLeftStop)
end

local function Turn(s, v)
    v = math.max(-R.VMAX, math.min(R.VMAX, v))
    v = math.floor(v / R.STEP + 0.5) * R.STEP
    if math.abs(v) < R.STEP then v = 0 end
    if v == s.v then return end
    if s.v > 0 and v <= 0 then Call(MoveViewRightStop) end
    if s.v < 0 and v >= 0 then Call(MoveViewLeftStop) end
    local ok = true
    if v > 0 then ok = Call(MoveViewRightStart, v / YawSpeed())
    elseif v < 0 then ok = Call(MoveViewLeftStart, -v / YawSpeed()) end
    if not ok then
        StopTurning()
        R.noTurn, s.v = true, 0
        ns.Note("flight film: the camera cannot be turned here: a still shot")
        return
    end
    s.v = v
end

-- Drawn out wide, or back to the distance it had
local function Zoom(s, out, now)
    if s.calm or out == s.out then return end
    local cur = GetCameraZoom and tonumber(Plain(GetCameraZoom()))
    if out then
        if not cur then return end
        s.base, s.outAt = cur, now
        Call(CameraZoomOut, R.ZOOM)
    else
        local back = R.ZOOM
        if cur and s.base and now - (s.outAt or now) > 2 then back = cur - s.base end   -- (settled: what it moved)
        if back > 0.05 then Call(CameraZoomIn, back) elseif back < -0.05 then Call(CameraZoomOut, -back) end
    end
    s.out = out
end

local function Caption(s, title, sub, from, to)
    if not title then return end
    film.title:SetText(title)
    film.sub:SetText(sub or "")
    s.caption = { from = from, to = to }
end

-- Where you are going: "Booty Bay", and under it "Stranglethorn  ·  Evening"
local function Destination(s, fl)
    local F = ns.Flights
    local place, zone
    if F and F.Split and fl.to then place, zone = F.Split(fl.to) end
    local when = F and F.TimeOfDay and F.TimeOfDay() or nil
    if not place then place, zone = Text(GetZoneText), nil end
    local sub = (zone and when) and (zone .. "  ·  " .. when) or zone or when
    Caption(s, place, sub, s.t + R.CAPTION[1], s.t + R.CAPTION[2])
end

---------------------------------------------------------------------------
-- Why not on film now: a word, and whether it ends the film at once (else it steps out gently)
---------------------------------------------------------------------------
local function Stick(state)
    if type(state.sticks) ~= "table" then return false end
    for _, st in pairs(state.sticks) do
        if type(st) == "table" then
            local x, y = tonumber(st.x) or 0, tonumber(st.y) or 0
            if math.abs(x) > R.STICK or math.abs(y) > R.STICK then return true end
        end
    end
    return false
end

local function HandsOn()
    local CF = ns.Campfire
    if CF and CF.AnyPadButton and CF.AnyPadButton() then return true end
    local G = C_GamePad
    if not (G and G.GetDeviceMappedState) then return false end
    local ok, state = pcall(G.GetDeviceMappedState)
    return ok and type(state) == "table" and Stick(state)
end

function R.Why(now)
    if not (R.active and ns.db.flightScene) then return "off", true end
    local fl = Flight()
    if not fl then return "not on a flight", true end
    if ns.Campfire and ns.Campfire.scene then return "the campfire scene", true end
    if Yes(UnitAffectingCombat("player")) or Yes(InCombatLockdown()) then return "a fight", true end
    if Asks(UnitIsDeadOrGhost, "player") then return "dead", true end
    if R.fl ~= fl then                                              -- a new flight: its own film
        R.fl, R.done, R.inputAt, R.blockedAt, R.toldTo = fl, nil, nil, nil, nil
    end
    if R.done then return R.done, false end
    local left = Left(fl, now)
    if left and left <= BowAt() then
        if R.scene then R.done = "coming in to land" end            -- (and not again on this flight)
        return "coming in to land", false
    end
    if now - fl.at < R.AFTER then return "taking off", false end
    if not R.scene and left and left < BowAt() + R.MIN then return "a short flight", false end
    if ns.arranging then return "arranging", false end
    local G = ns.FlightGame
    if G and G.state == "playing" then R.blockedAt = now; return "the flight game", false end
    if now - (R.checkedAt or -1) >= R.THROTTLE then
        R.checkedAt = now
        local CF = ns.Campfire
        R.window = CF and CF.WindowOpen and CF.WindowOpen() or false
        if HandsOn() then R.inputAt = now end
    end
    if R.window then R.blockedAt = now; return "a window", false end
    if R.inputAt and now - R.inputAt < R.BACK then return "your controller", false end
    if R.blockedAt and now - R.blockedAt < R.RETURN then return "a moment", false end
    return nil
end

---------------------------------------------------------------------------
-- Playing
---------------------------------------------------------------------------
function R.Start(now)
    if R.scene then return false end
    Build()
    local okA, alpha = pcall(UIParent.GetAlpha, UIParent)
    local okS, scale = pcall(UIParent.GetEffectiveScale, UIParent)
    film:SetScale((okS and type(scale) == "number" and scale > 0) and scale or 1)
    local s = { at = now, t = 0, p = 0, target = 1, v = 0, yaw = 0, adopted = {},
                calm = ns.Calm() and true or false,
                alpha = (okA and type(Plain(alpha)) == "number") and alpha or 1 }
    R.scene = s
    Hold(true)
    if ns.Veil then ns.Veil("flight", true) end                    -- (names out of the picture)
    film.title:SetText("")
    film.sub:SetText("")
    film.title:SetAlpha(0)
    film.sub:SetAlpha(0)
    film:Show()
    Adopt(s)
    local fl = R.fl
    if fl and R.toldTo ~= (fl.to or "?") then                      -- where you are going: once a flight
        R.toldTo = fl.to or "?"
        Destination(s, fl)
    end
    R.shown = R.shown + 1
    ns.Note("flight film: rolls (to %s)", tostring(fl and fl.to or "?"))
    return true
end

function R.Finish(why)
    local s = R.scene
    if not s then return end
    R.scene = nil
    Turn(s, 0)
    StopTurning()                                                   -- (whatever it was doing: never left turning)
    Zoom(s, false, GetTime())
    SetUIAlpha(s.alpha)
    if ns.Campfire and ns.Campfire.Minimap then ns.Campfire.Minimap(s, false) end
    Release(s)
    if film then film:Hide() end
    if ns.Veil then ns.Veil("flight", false) end
    Hold(false)
    R.last = why
    ns.Note("flight film: ends (%s) after %.0f s", tostring(why), GetTime() - s.at)
end

function R.Step(now, dt, why, hard)
    local s = R.scene
    if not s then return end
    if hard then R.Finish(why); return end
    s.t = s.t + dt
    s.target = why and 0 or 1
    local slow = why == "coming in to land"                        -- (anything else: out of your way at once)
    local rate = s.target > s.p and 1 / R.IN or 1 / (slow and R.OUT or R.QUICK)
    if s.target > s.p then s.p = math.min(s.target, s.p + rate * dt) else s.p = math.max(s.target, s.p - rate * dt) end
    local k = Ease(s.p)
    Adopt(s)                                                        -- (the game's line, made after the film began)
    -- the screen fades back, the bars close in
    SetUIAlpha(s.alpha * (1 - k))
    if ns.Campfire and ns.Campfire.Minimap then ns.Campfire.Minimap(s, k > 0.5) end   -- (its marks don't fade)
    local okH, h = pcall(UIParent.GetHeight, UIParent)             -- (the film is scaled as the screen is)
    h = (okH and type(Plain(h)) == "number" and h > 0) and h or 768
    local bar = h * R.BAR
    if s.calm then
        film.top:SetHeight(bar)
        film.bottom:SetHeight(bar)
        film.top:SetAlpha(k)
        film.bottom:SetAlpha(k)
    else
        film.top:SetHeight(math.max(1, bar * k))
        film.bottom:SetHeight(math.max(1, bar * k))
        film.top:SetAlpha(k > 0 and 1 or 0)
        film.bottom:SetAlpha(k > 0 and 1 or 0)
    end
    -- the flight bar rises into the top bar (its middle a little over the bar's middle)
    local b = s.bar
    if b then
        local y = b.y + (-(bar / 2) + 9 - b.y) * k
        pcall(b.f.ClearAllPoints, b.f)
        pcall(b.f.SetPoint, b.f, b.point, b.rel or UIParent, b.relPoint, b.x, y)
    end
    -- the words in the bottom bar
    local c = s.caption
    local a = c and Window(s.t, c.from, c.to, 0.9) * k or 0
    film.title:SetAlpha(a)
    film.sub:SetAlpha(a)
    -- the camera: drawn out, circling slowly round you; round behind you again as you come in. Stepping out of
    -- your way (the game, a window, your hand on the controller) it stops at once: the camera is yours.
    Zoom(s, s.target == 1, now)
    local going = s.target == 1 or slow
    if not s.calm and ns.db.flightOrbit and not R.noTurn then
        local left = Left(R.fl, now)
        if not s.home and going and left and left <= BowAt() + R.HOME_LEAD then
            local r = s.yaw % 360                                   -- how far past behind you: the shorter way back
            s.home = { from = s.yaw, to = (r <= 180) and (s.yaw - r) or (s.yaw + 360 - r), at = s.t }
        end
        local v = 0
        local h = s.home
        if h and going then
            local q = Clamp01((s.t - h.at) / R.HOME_TIME)
            local want = h.from + (h.to - h.from) * Ease(q)
            v = (h.to - h.from) * 6 * q * (1 - q) / R.HOME_TIME + (want - s.yaw) / 0.5
            if q >= 1 and math.abs(h.to - s.yaw) <= R.HOME then v = 0 end
        elseif s.target == 1 then
            v = k * R.ORBIT                                         -- (eased in with the film)
        end
        Turn(s, v)
        s.yaw = s.yaw + s.v * dt
    elseif s.v ~= 0 then
        Turn(s, 0)
    end
    local homed = not (s.home and going) or (s.v == 0 and math.abs(s.home.to - s.yaw) <= R.HOME)
    if s.target == 0 and s.p == 0 and homed then
        R.Finish(why)                                               -- gone: everything given back
    end
end

-- A new zone under you: its name in the bottom bar
function R.Zone()
    local s = R.scene
    if not (s and s.target == 1 and s.p > 0.5) then return end
    local zone = Text(GetZoneText)
    if not zone or zone == R.lastZone then return end
    R.lastZone = zone
    Caption(s, zone, Text(GetSubZoneText) ~= zone and Text(GetSubZoneText) or nil, s.t, s.t + R.ZONE)
end

---------------------------------------------------------------------------
-- Running
---------------------------------------------------------------------------
local watcher = CreateFrame("Frame")
watcher:SetScript("OnUpdate", ns.Protect(function(_, dt)
    if not R.active then return end
    local now = GetTime()
    if not R.scene and now - (R.idleAt or -1) < R.THROTTLE then return end   -- (on the ground: a look now and then)
    R.idleAt = now
    local why, hard = R.Why(now)
    R.why = why
    if R.scene then
        R.Step(now, math.min(dt or 0, 0.1), why, hard)
    elseif not why then
        R.Start(now)
        R.Step(now, 0, nil, false)
    end
end))

watcher:SetScript("OnEvent", ns.Protect(function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        if R.scene then R.done = "a fight" end
        R.Finish("a fight")
    elseif event == "PLAYER_LEAVING_WORLD" then R.Finish("a loading screen")
    elseif event == "ZONE_CHANGED_NEW_AREA" then R.Zone()
    elseif event == "PLAYER_CONTROL_GAINED" then
        if R.scene and not Flight() then R.Finish("landed") end
    end
end))

local EVENTS = { "PLAYER_REGEN_DISABLED", "PLAYER_LEAVING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_CONTROL_GAINED" }

function R:Apply(run)
    local want = run and ns.db.flightScene and true or false
    if want and not self.active then
        self.active = true
        for _, e in ipairs(EVENTS) do pcall(watcher.RegisterEvent, watcher, e) end
    elseif not want and self.active then
        self.active = false
        watcher:UnregisterAllEvents()
        R.Finish("off")
    end
end

function R.Describe()
    local s = R.scene
    return ("flight film: on %s, rolled %d, %s; last ended: %s"):format(tostring(R.active), R.shown,
        s and ("playing, in %.2f, turning %.2f deg/s, turned %.0f deg%s"):format(s.p, s.v, s.yaw,
            s.home and " (coming round behind you)" or "")
            or ("not playing: " .. tostring(R.why or "-")), tostring(R.last or "-"))
end

ns.RegisterModule("ride", R)
