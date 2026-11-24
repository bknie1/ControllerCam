-- ControllerCam HUD: flights.
--   * Taking a flight says where to and how long in chat: "[F] Booty Bay: about 2:10".
--   * A bar at the top of the screen, in the HUD's bar style, fills up on the way and counts down to the landing,
--     with what carries you (a gryphon, a wind rider, a bat) gliding along its end. It goes on landing.
--   * How long each route takes (where you start -> where you land) is learned from the flights you take, and
--     kept with the HUD's saved settings. On a route not flown before, the time is a guess from how far it goes
--     on the map, at the pace your other flights on that map flew; before any flight there it is not known: it
--     says so, and the bar counts the time up instead.
-- Where you start is the flight master's map's own word for it. Where you go is the place you last pointed at
-- while the map was open (the controller's cursor too, or the place whose tooltip showed), only looked at;
-- failing that, the flight point named like the place you land at. Nothing of the game's map, buttons or
-- flight is touched.

local ADDON = ...
local ns = ControllerCamHUD.ns            -- the HUD's own namespace: this file is one of its modules (Modules.lua)
local L = ns.L

local F = { running = false, flights = 0, learned = 0 }
ns.Flights = F


ns.RegisterSetting({
    key = "flightRider", kind = "boolean", default = true, command = "flightrider", section = "Quests, chat and map",
    label = "Flights: your mount along the bar",
    tip = "a gryphon, a wind rider or a bat (whichever the flight master gave you) glides along the flight bar towards where you land",
})

ns.RegisterSetting({
    key = "flightWeather", kind = "boolean", default = true, command = "flightweather", section = "Quests, chat and map",
    label = "Flights: the weather where you land",
    tip = "on landing, chat says what the air is like where you came down, as the place usually is (hot and humid in Stranglethorn, snow underfoot in Dun Morogh), and the time of day",
})

F.W, F.H, F.Y = 300, 10, -96   -- the bar: width, height; where it sits under the top of the screen
F.MAX = 3600                  -- a flight longer than this was not one flight (a disconnect, a long pause): not learned

-- Learned times: "From > To" -> { t = seconds, n = flights averaged }
ns.RegisterSaved("flightTimes", function(old)
    local out = {}
    if type(old) ~= "table" then return out end
    for route, rec in pairs(old) do
        if type(route) == "string" and type(rec) == "table" and tonumber(rec.t) and tonumber(rec.t) > 0 then
            out[route] = { t = tonumber(rec.t), n = math.max(1, math.min(5, math.floor(tonumber(rec.n) or 1))) }
        end
    end
    return out
end)
-- The flight under way when the game was reloaded: { from, to, at = time(), dist, map, mount, stops }, and after
-- asking to land early: early, with the time to the stop (eta, guess)
local function CleanStops(list)
    if type(list) ~= "table" then return nil end
    local out = {}
    for i = 1, math.min(#list, 20) do
        local s = list[i]
        if type(s) ~= "table" or not tonumber(s.f) then return nil end
        out[i] = { n = type(s.n) == "string" and s.n or nil, f = tonumber(s.f) }
    end
    return #out > 0 and out or nil
end
ns.RegisterSaved("flightNow", function(old)
    if type(old) ~= "table" or not tonumber(old.at) then return nil end
    return { from = type(old.from) == "string" and old.from or nil, to = type(old.to) == "string" and old.to or nil,
             at = tonumber(old.at), dist = tonumber(old.dist), map = type(old.map) == "string" and old.map or nil,
             mount = type(old.mount) == "string" and old.mount or nil, stops = CleanStops(old.stops),
             early = old.early and true or nil, eta = tonumber(old.eta), guess = old.guess and true or nil }
end)
-- The pace of your flights on each flight map, for a guess at a route not flown yet: map -> { s = seconds for
-- each unit of the map's distance, n = flights averaged }
F.PACE_N = 10
ns.RegisterSaved("flightPace", function(old)
    local out = {}
    if type(old) ~= "table" then return out end
    for map, rec in pairs(old) do
        if type(map) == "string" and type(rec) == "table" and tonumber(rec.s) and tonumber(rec.s) > 0 then
            out[map] = { s = tonumber(rec.s), n = math.max(1, math.min(F.PACE_N, math.floor(tonumber(rec.n) or 1))) }
        end
    end
    return out
end)

function F.Route(from, to) return (from and to) and (from .. " > " .. to) or nil end

function F.Clock(seconds)
    seconds = math.max(0, math.floor((seconds or 0) + 0.5))
    return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

local function Plain(v) if ns.IsSecret(v) then return nil end return v end
local function Ask(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a = pcall(fn, ...)
    if ok then return Plain(a) end
end

local function OnTaxi() return ns.Yes(Ask(UnitOnTaxi, "player")) end

---------------------------------------------------------------------------
-- What carries you: the Horde's flight masters keep wind riders, the Alliance's gryphons; the bat handlers of
-- the Forsaken (known by who they are) keep bats. The game's own icons of them.
---------------------------------------------------------------------------
F.MOUNTS = {
    gryphon = "Interface\\Icons\\Ability_Mount_Gryphon_01",
    windrider = "Interface\\Icons\\Ability_Mount_Wyvern_01",
    bat = "Interface\\Icons\\Ability_Hunter_Pet_Bat",
}
-- bat handlers: Undercity, the Sepulcher, Tarren Mill, Light's Hope
F.BATS = { [4551] = true, [2226] = true, [2389] = true, [12636] = true }
function F.MountOf()
    local guid = Ask(UnitGUID, "npc")
    local id = type(guid) == "string" and tonumber(guid:match("^%a+%-%d+%-%d+%-%d+%-%d+%-(%d+)"))
    if id and F.BATS[id] then return "bat" end
    local faction = Ask(UnitFactionGroup, "player")
    return faction == "Horde" and "windrider" or "gryphon"
end

---------------------------------------------------------------------------
-- The flight master's map: where you are, and the places it offers
---------------------------------------------------------------------------
function F.ReadMap()
    local nodes, here, hereSlot = {}, nil, nil
    local n = tonumber(Ask(NumTaxiNodes)) or 0
    for i = 1, math.min(n, 200) do
        local name = Ask(TaxiNodeName, i)
        if type(name) == "string" and name ~= "" then
            nodes[i] = name
            if Ask(TaxiNodeGetType, i) == "CURRENT" then here, hereSlot = name, i end
        end
    end
    if n == 0 and C_TaxiMap and C_TaxiMap.GetAllTaxiNodes and C_Map and C_Map.GetBestMapForUnit then
        local map = Ask(C_Map.GetBestMapForUnit, "player")
        local list = map and Ask(C_TaxiMap.GetAllTaxiNodes, map)
        local current = Enum and Enum.FlightPathState and Enum.FlightPathState.Current or 0
        for i, node in ipairs(type(list) == "table" and list or {}) do
            local name = type(node) == "table" and Plain(node.name)
            if type(name) == "string" then
                nodes[node.slotIndex or i] = name
                if Plain(node.state) == current then here = name end
            end
        end
    end
    F.nodes, F.here, F.hereSlot = nodes, here, hereSlot
    local map = Ask(GetTaxiMapID)
    F.map = (type(map) == "number" or type(map) == "string") and tostring(map) or "taxi"
    return here
end

-- How far a place is from here on the flight master's map: along the flight's own legs where the map draws
-- them, else in a straight line. In the map's own units (its width is 1; its height counts for less).
local TALL = 2 / 3
local function Two(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b = pcall(fn, ...)
    if ok then return tonumber(Plain(a)), tonumber(Plain(b)) end
end
local function Apart(x1, y1, x2, y2) return math.sqrt((x2 - x1) ^ 2 + ((y2 - y1) * TALL) ^ 2) end
function F.Distance(slot)
    if type(slot) ~= "number" then return nil end
    local legs = tonumber(Ask(GetNumRoutes, slot)) or 0
    if legs > 0 and TaxiGetSrcX and TaxiGetSrcY and TaxiGetDestX and TaxiGetDestY then
        local d = 0
        for leg = 1, math.min(legs, 20) do
            local sx, sy = tonumber(Ask(TaxiGetSrcX, slot, leg)), tonumber(Ask(TaxiGetSrcY, slot, leg))
            local dx, dy = tonumber(Ask(TaxiGetDestX, slot, leg)), tonumber(Ask(TaxiGetDestY, slot, leg))
            if not (sx and sy and dx and dy) then d = 0; break end
            d = d + Apart(sx, sy, dx, dy)
        end
        if d > 0 then return d end
    end
    if not F.hereSlot then return nil end
    local x1, y1 = Two(TaxiNodePosition, F.hereSlot)
    local x2, y2 = Two(TaxiNodePosition, slot)
    if not (x1 and y1 and x2 and y2) then return nil end
    local d = Apart(x1, y1, x2, y2)
    return d > 0 and d or nil
end

-- The stops along the way to a place: the flight point each of its legs ends at, with how far along the whole way
-- it is (0..1; the last one is the place itself). Where you come down when you ask to land early: the first stop
-- still ahead. Nil where the map does not draw the legs.
F.STOP_NEAR = 0.02            -- (a leg's end this close to a flight point on the map is that point)
function F.Stops(slot)
    if type(slot) ~= "number" or not (TaxiGetSrcX and TaxiGetSrcY and TaxiGetDestX and TaxiGetDestY) then return nil end
    local legs = tonumber(Ask(GetNumRoutes, slot)) or 0
    if legs < 1 then return nil end
    local at = {}
    for i, name in pairs(F.nodes or {}) do
        local x, y = Two(TaxiNodePosition, i)
        if x and y then at[#at + 1] = { name, x, y } end
    end
    local stops, d = {}, 0
    for leg = 1, math.min(legs, 20) do
        local sx, sy = tonumber(Ask(TaxiGetSrcX, slot, leg)), tonumber(Ask(TaxiGetSrcY, slot, leg))
        local dx, dy = tonumber(Ask(TaxiGetDestX, slot, leg)), tonumber(Ask(TaxiGetDestY, slot, leg))
        if not (sx and sy and dx and dy) then return nil end
        d = d + Apart(sx, sy, dx, dy)
        local best, near
        for _, p in ipairs(at) do
            local e = Apart(p[2], p[3], dx, dy)
            if not near or e < near then best, near = p[1], e end
        end
        stops[leg] = { n = (near and near <= F.STOP_NEAR) and best or nil, d = d }
    end
    if d <= 0 then return nil end
    for _, s in ipairs(stops) do s.f, s.d = s.d / d, nil end
    stops[#stops].f = 1
    return stops
end

-- The pace of this map from routes already flown: with no pace of its own yet, the routes whose both ends this
-- map shows (and whose time is known) give one, so the first flight from a new place is a guess too. (A route
-- learned before paces were kept, or flown from somewhere else, counts as well.)
function F.Seed()
    local paces = ns.db and ns.db.flightPace
    if not (paces and F.map and F.nodes) or paces[F.map] then return false end
    local at = {}
    for i, name in pairs(F.nodes) do
        local x, y = Two(TaxiNodePosition, i)
        if x and y then at[name] = { x, y } end
    end
    local sum, n = 0, 0
    for route, rec in pairs(ns.db.flightTimes or {}) do
        local a, b = route:match("^(.-) > (.+)$")
        a, b = a and at[a], b and at[b]
        if a and b then
            local d = Apart(a[1], a[2], b[1], b[2])
            if d > 0.005 then sum, n = sum + rec.t / d, n + 1 end
        end
    end
    if n == 0 then return false end
    paces[F.map] = { s = sum / n, n = math.min(n, F.PACE_N) }
    ns.Note("flight: pace for map %s from %d routes flown: %.0f s", F.map, n, sum / n)
    return true
end

-- A place of the map in a frame of the game's: one of its buttons (by its number), or a pin that carries its node
local function PlaceOf(frame)
    if type(frame) ~= "table" then return nil end
    local data = rawget(frame, "taxiNodeData")
    if type(data) == "table" and type(Plain(data.name)) == "string" then
        return data.name, tonumber(Plain(data.slotIndex))
    end
    local okN, name = pcall(function() return frame:GetName() end)
    local index = okN and type(name) == "string" and tonumber(name:match("^TaxiButton(%d+)$"))
    if index then
        local okI, id = pcall(function() return frame:GetID() end)
        index = (okI and tonumber(id) and tonumber(id) > 0) and tonumber(id) or index
        local place = F.nodes and F.nodes[index] or Ask(TaxiNodeName, index)
        if type(place) == "string" then return place, index end
    end
end

-- A place you can fly to (not where you are, not one out of reach)
local function Open(slot)
    if not slot then return true end
    local kind = Ask(TaxiNodeGetType, slot)
    return kind ~= "CURRENT" and kind ~= "NONE" and kind ~= "DISTANT"
end

-- The place pointed at now: under the pointer (the controller's cursor moves it too), a button that says the
-- pointer is over it, or the button the game's tooltip is showing (which is where a controller's choice shows)
function F.Pointed()
    local focus
    if GetMouseFoci then
        local ok, list = pcall(GetMouseFoci)
        focus = ok and type(list) == "table" and list[1] or nil
    elseif GetMouseFocus then
        local ok, f = pcall(GetMouseFocus)
        focus = ok and f or nil
    end
    local name, slot = PlaceOf(focus)
    if name and Open(slot) then return name, slot, "pointer" end
    for i in pairs(F.nodes or {}) do
        local b = _G["TaxiButton" .. i]
        if type(b) == "table" and b.IsMouseOver then
            local ok, over = pcall(b.IsMouseOver, b)
            if ok and ns.Yes(over) then
                name, slot = PlaceOf(b)
                if name and Open(slot) then return name, slot, "button" end
            end
        end
    end
    local tip = _G.GameTooltip
    if type(tip) == "table" and tip.IsShown and tip.GetOwner and ns.Yes(Ask(tip.IsShown, tip)) then
        local ok, owner = pcall(tip.GetOwner, tip)
        name, slot = PlaceOf(ok and owner or nil)
        if name and Open(slot) then return name, slot, "tooltip" end
    end
end

-- While the map is open, the last place pointed at is remembered (with how far it is): when you choose one the
-- map closes at once, and by the time it says so nothing of it is under the pointer any more
F.hover = nil
function F.Remember()
    local name, slot, how = F.Pointed()
    if not name then return end
    local h = F.hover
    if not (h and h.name == name) then
        h = { name = name, slot = slot, how = how, dist = F.Distance(slot), stops = F.Stops(slot) }
        F.hover = h
    end
    h.at = GetTime()
end
local watch = CreateFrame("Frame")
local watchSince = 0
local function Watch(_, dt)
    watchSince = watchSince + dt
    if watchSince < 0.1 then return end
    watchSince = 0
    F.Remember()
end
Watch = ns.Protect(Watch)
F.HOVER_KEPT = 3              -- (a place pointed at longer ago than this as the map closed was not the choice)

-- Where you landed: the flight point named like the place you are at ("Booty Bay, Stranglethorn" at Booty Bay)
function F.Landed()
    local sub, zone = Ask(GetSubZoneText), Ask(GetZoneText) or Ask(GetRealZoneText)
    local function Find(place)
        if type(place) ~= "string" or place == "" then return nil end
        for _, name in pairs(F.nodes or {}) do
            if name == place or name:sub(1, #place + 1) == place .. "," then return name end
        end
    end
    return Find(sub) or Find(zone) or ((type(sub) == "string" and sub ~= "") and sub) or zone
end

---------------------------------------------------------------------------
-- The bar
---------------------------------------------------------------------------
-- Each text has a place of its own, so they never run into each other:
--           Hammerfall                               1:12
--           [======================--------------]
--           Arathi - a guess from the distance
-- the place where you land on the left over the bar, the time on the right (what is left, or what has gone by
-- with a + in front while the time is not known), and a muted line under it (the zone, and how sure the time is).
local frame
F.TIME_W = 90
F.RIDER, F.WAKE = 34, 46       -- the rider's size; how long its wake
F.BOB, F.SWAY = 2.5, 0.08      -- how far it rises and falls (pixels), how far it tilts (radians), as wings beat
local function Build()
    frame = CreateFrame("Frame", "ControllerCamHUD_Flight", UIParent)
    frame:SetSize(F.W + 34, F.H)
    frame:SetPoint("TOP", UIParent, "TOP", 0, F.Y)
    frame:SetFrameStrata("MEDIUM")
    frame.bar = ns.CreateBar(frame, F.W, F.H)
    frame.bar:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
    frame.bar:SetColor(unpack(ns.colors.calm))
    local back = frame:CreateTexture(nil, "BACKGROUND", nil, -2)       -- a soft dark ground under all of it
    back:SetTexture(ns.media.soft)
    back:SetVertexColor(0, 0, 0, 0.55)
    back:SetPoint("TOPLEFT", frame.bar, "TOPLEFT", -70, 46)
    back:SetPoint("BOTTOMRIGHT", frame.bar, "BOTTOMRIGHT", 30, -40)
    frame.back = back
    frame.time = ns.FontString(frame, 15, "RIGHT")
    frame.time:SetPoint("BOTTOMRIGHT", frame.bar, "TOPRIGHT", 0, 15)
    frame.time:SetWidth(F.TIME_W)
    frame.time:SetTextColor(unpack(ns.colors.caution))
    frame.name = ns.FontString(frame, 14, "LEFT")
    frame.name:SetPoint("BOTTOMLEFT", frame.bar, "TOPLEFT", 0, 15)
    frame.name:SetPoint("RIGHT", frame.time, "LEFT", -8, 0)
    frame.status = ns.FontString(frame, 11, "LEFT")
    frame.status:SetPoint("TOPLEFT", frame.bar, "BOTTOMLEFT", 0, -15)
    frame.status:SetPoint("TOPRIGHT", frame.bar, "BOTTOMRIGHT", 0, -15)
    frame.status:SetTextColor(unpack(ns.colors.muted))
    for _, fs in ipairs({ frame.time, frame.name, frame.status }) do
        if fs.SetWordWrap then fs:SetWordWrap(false) end                -- one line each, cut short if need be
    end
    -- the rider: a round portrait of your mount (the game's icon of it, cut round, in a thin gold ring) riding the
    -- end of the bar like a slider, a soft wake behind it, and a mark where you land at the bar's far end
    local over = CreateFrame("Frame", nil, frame)
    over:SetAllPoints(frame)
    over:SetFrameLevel(frame.bar:GetFrameLevel() + 6)
    frame.over = over
    local goal = over:CreateTexture(nil, "ARTWORK")
    goal:SetTexture(ns.media.soft)
    goal:SetSize(12, 12)
    goal:SetPoint("CENTER", frame.bar, "RIGHT", 0, 0)
    goal:SetVertexColor(unpack(ns.colors.caution))
    frame.goal = goal
    local wake = over:CreateTexture(nil, "BACKGROUND")
    wake:SetTexture(ns.media.soft)
    wake:SetSize(F.WAKE, 8)
    wake:SetVertexColor(1, 1, 1, 0.3)
    frame.wake = wake
    local glow = over:CreateTexture(nil, "BORDER")
    glow:SetTexture(ns.media.soft)
    glow:SetSize(F.RIDER + 14, F.RIDER + 14)
    glow:SetVertexColor(0, 0, 0, 0.7)
    frame.glow = glow
    local rider = over:CreateTexture(nil, "ARTWORK", nil, 2)
    rider:SetSize(F.RIDER, F.RIDER)
    rider:SetTexCoord(0.1, 0.9, 0.1, 0.9)                              -- (the icon's own frame trimmed off)
    if over.CreateMaskTexture then                                       -- cut round by our own disc
        pcall(function()
            local mask = over:CreateMaskTexture()
            mask:SetTexture(ns.media.disc, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            mask:SetAllPoints(rider)
            rider:AddMaskTexture(mask)
            frame.riderMask = mask
        end)
    end
    frame.rider = rider
    local ring = over:CreateTexture(nil, "ARTWORK", nil, 3)           -- a thin gold ring round it
    ring:SetTexture(ns.media.ring)
    ring:SetVertexColor(1, 0.84, 0.45, 0.95)
    ring:SetPoint("TOPLEFT", rider, "TOPLEFT", -3, 3)
    ring:SetPoint("BOTTOMRIGHT", rider, "BOTTOMRIGHT", 3, -3)
    frame.ring = ring
    glow:SetPoint("CENTER", rider, "CENTER", 0, 0)
    wake:SetPoint("RIGHT", rider, "CENTER", -10, 0)
    frame:Hide()
    F.frame = frame
end

-- "Hammerfall, Arathi" -> "Hammerfall", "Arathi"
function F.Split(place)
    if type(place) ~= "string" then return nil, nil end
    local name, zone = place:match("^(.-),%s*(.+)$")
    if name and name ~= "" then return name, zone end
    return place, nil
end

function F.Draw(now)
    local fl = F.flight
    if not (fl and frame) then return end
    local gone = now - fl.at
    local name, zone = F.Split(fl.to)
    frame.name:SetText(name or L["Flight"])
    local how
    if fl.early then
        how = fl.to and L["landing early"] or L["landing at the next flight point"]
    elseif not fl.to then
        how = L["destination unknown"]
    elseif fl.guess then
        how = L["a guess from the distance"]
    elseif not fl.eta then
        how = L["first flight on this route: learning its time"]
    end
    local parts = {}
    if zone then parts[#parts + 1] = zone end
    if how then parts[#parts + 1] = how end
    frame.status:SetText(table.concat(parts, " - "))
    if fl.eta then
        local left = fl.eta - gone
        frame.bar:SetAlpha(1)
        frame.bar:SetValues(math.min(gone, fl.eta), fl.eta)            -- filling up: how far along the way
        frame.time:SetText(left > 0 and F.Clock(left) or L["landing"])
    else
        frame.bar:SetValues(1, 1, true)                                 -- (no end to count down to: a calm full bar)
        frame.bar:SetAlpha(0.5)
        frame.time:SetText("+" .. F.Clock(gone))
    end
end

-- The rider, every frame: at the end of what is filled, rising and falling as its wings beat. With no time
-- known it wanders over the middle of the bar, there and back.
function F.Ride(now)
    local fl = F.flight
    if not (fl and frame and frame.rider) then return end
    local show = ns.db.flightRider and true or false
    for _, t in ipairs({ frame.rider, frame.ring, frame.glow, frame.wake, frame.goal }) do
        if show then t:Show() else t:Hide() end
    end
    if not show then return end
    if frame.mountKind ~= fl.mount then
        frame.rider:SetTexture(F.MOUNTS[fl.mount] or F.MOUNTS.gryphon)
        frame.mountKind = fl.mount
    end
    local gone = now - fl.at
    local p
    if fl.eta then p = math.min(1, math.max(0, gone / fl.eta))
    else p = 0.5 + 0.3 * math.sin(gone * 0.2) end
    local calm = ns.Calm()
    local bob = calm and 0 or math.sin(now * 5) * F.BOB
    frame.rider:ClearAllPoints()
    frame.rider:SetPoint("CENTER", frame.bar, "LEFT", p * F.W, 1 + bob)
    if frame.rider.SetRotation then pcall(frame.rider.SetRotation, frame.rider, calm and 0 or math.cos(now * 5) * F.SWAY) end
    frame.wake:SetWidth(math.max(1, math.min(F.WAKE, p * F.W)))
    frame.wake:SetAlpha(fl.eta and 1 or 0.6)
    F.at = p
end

local driver = CreateFrame("Frame")
local since = 0
local function Tick(_, dt)
    if F.flight then F.Ride(GetTime()) end
    since = since + dt
    if since < 0.25 then return end
    since = 0
    if not F.flight then driver:SetScript("OnUpdate", nil); return end
    if not OnTaxi() then F.Land(); return end
    F.Draw(GetTime())
    F.WeatherAhead(GetTime())
end
Tick = ns.Protect(Tick)

---------------------------------------------------------------------------
-- Taking off and landing
---------------------------------------------------------------------------
local function Say(text)
    if not (ns.Chat and ns.Chat.Line and ns.Chat.Line("flight", text)) then ns.Say(text) end
end

function F.Start(resumed)
    if F.flight or not F.running then return end
    local now = GetTime()
    local fresh = now - (F.closedAt or -100) <= 10      -- (a flight without the map, a quest's: from and to unknown)
    local fl = resumed or { from = fresh and F.here or nil, to = fresh and F.picked or nil, at = now,
                            dist = fresh and F.pickedDist or nil, map = fresh and F.map or nil,
                            mount = fresh and F.mount or nil, stops = fresh and F.pickedStops or nil }
    fl.mount = F.MOUNTS[fl.mount or ""] and fl.mount or F.MountOf()
    F.flight, F.picked, F.pickedDist, F.pickedStops = fl, nil, nil, nil
    F.flights = F.flights + 1
    if not fl.early then                         -- (resumed after asking to land early: its own time to the stop)
        local route = F.Route(fl.from, fl.to)
        local rec = route and ns.db.flightTimes[route]
        fl.eta, fl.guess = rec and rec.t or nil, nil
        local pace = not fl.eta and fl.to and fl.dist and fl.map and ns.db.flightPace[fl.map]
        if pace then fl.eta, fl.guess = fl.dist * pace.s, true end    -- not flown yet: a guess from the distance
    end
    if not resumed then
        ns.db.flightNow = { from = fl.from, to = fl.to, at = time(), dist = fl.dist, map = fl.map, mount = fl.mount,
                            stops = fl.stops }
        if fl.to and fl.guess then
            Say(L["%s: about %s, a guess from the distance"]:format(fl.to, F.Clock(fl.eta)))
        elseif fl.to and fl.eta then
            Say(L["%s: about %s"]:format(fl.to, F.Clock(fl.eta)))
        elseif fl.to then
            Say(L["%s: first flight on this route, time unknown"]:format(fl.to))
        else
            Say(L["On a flight, destination unknown"])
        end
        if ns.Hydrate and ns.Hydrate.OnFlight then ns.Hydrate.OnFlight() end
    end
    ns.Note("flight: from %s to %s (%s), %s", tostring(fl.from), tostring(fl.to), tostring(F.how or "-"),
        fl.eta and ("eta " .. F.Clock(fl.eta) .. (fl.guess and " (a guess)" or "")) or "eta unknown")
    if not frame then Build() end
    frame.bar:SetAlpha(1)
    frame.bar:SetValues(fl.eta and 0 or 1, fl.eta or 1, true)        -- (empty at take-off)
    F.Draw(now)
    F.Ride(now)
    frame:Show()
    since = 0
    driver:SetScript("OnUpdate", Tick)
end

function F.Land()
    local fl = F.flight
    if not fl then return end
    F.flight = nil
    ns.db.flightNow = nil
    driver:SetScript("OnUpdate", nil)
    if frame then frame:Hide() end
    local took = GetTime() - fl.at
    local to = fl.to or F.Landed()
    local route = F.Route(fl.from, to)
    ns.Note("flight: landed at %s after %s (route %s%s)", tostring(to), F.Clock(took), tostring(route),
        fl.early and ", landed early: not learned" or "")
    if took >= 5 and ns.db.flightWeather and not fl.weatherSaid then   -- (not said already as you came in)
        C_Timer.After(F.WEATHER_AFTER, function() F.SayWeather(to) end)   -- (once the zone is the new one)
    end
    if fl.early then return end                               -- (a landing asked for is no measure of the route)
    if not route or took < 5 or took > F.MAX then return end
    if fl.dist and fl.dist > 0 and fl.map then                -- the pace of flights on this map, for guesses
        local pace = ns.db.flightPace[fl.map]
        local s = took / fl.dist
        if pace then
            pace.s = (pace.s * pace.n + s) / (pace.n + 1)
            pace.n = math.min(pace.n + 1, F.PACE_N)
        else
            ns.db.flightPace[fl.map] = { s = s, n = 1 }
        end
    end
    local rec = ns.db.flightTimes[route]
    if rec then
        rec.t = (rec.t * rec.n + took) / (rec.n + 1)
        rec.n = math.min(rec.n + 1, 5)
    else
        ns.db.flightTimes[route] = { t = took, n = 1 }
        F.learned = F.learned + 1
        Say(L["%s: flight time learned, %s"]:format(to, F.Clock(took)))
    end
end

-- Asked to land early (the game's button to leave a flight): you come down at the next flight point on the way,
-- so the bar goes there, with the time to it. The next stop is the first one still ahead of how far along the way
-- you are; without the route's stops or its time the bar says only that you land at the next flight point.
F.AHEAD = 0.02                -- (a stop you are about to pass is not where you come down)
function F.EarlyLanding()
    local fl = F.flight
    if not fl or fl.early or not OnTaxi() then return end
    local now = GetTime()
    local gone = now - fl.at
    local stop
    if fl.eta and fl.stops then
        local p = gone / fl.eta
        for _, s in ipairs(fl.stops) do
            if s.f > p + F.AHEAD then stop = s; break end
        end
        stop = stop or fl.stops[#fl.stops]
        if stop.f >= 1 then return end                        -- the place you were going anyway: nothing changes
    end
    fl.early = true
    if stop and stop.n then
        fl.to, fl.eta = stop.n, fl.eta * stop.f
        Say(L["Landing early: %s, about %s"]:format(stop.n, F.Clock(math.max(0, fl.eta - gone))))
    else
        fl.to, fl.eta, fl.guess = nil, nil, nil
        Say(L["Landing early at the next flight point"])
    end
    ns.Note("flight: asked to land early, %s", tostring(fl.to or "next flight point"))
    local saved = ns.db.flightNow
    if saved then saved.to, saved.early, saved.eta, saved.guess = fl.to, true, fl.eta, fl.guess end
    F.Draw(now)
end
if type(TaxiRequestEarlyLanding) == "function" and hooksecurefunc then
    hooksecurefunc("TaxiRequestEarlyLanding", ns.Protect(function()
        if F.running then F.EarlyLanding() end
    end))
end

---------------------------------------------------------------------------
-- The weather where you land. The game says nothing of its weather, so this is the air of the place as it usually
-- is, by its map (Stranglethorn is hot and humid, Dun Morogh cold), never rain or sun it cannot see; two ways of
-- saying each, which one by the day. With the time of day: "Evening at Booty Bay: hot and humid, ..."
---------------------------------------------------------------------------
F.WEATHER_AFTER = 1
F.WEATHER_BEFORE = 15          -- seconds before the landing: said as you come in (when the flight's time is known)
F.CLIMATES = {
    snow = { L["crisp and cold, snow underfoot and your breath hanging in the air"],
             L["bitterly cold, with a wind off the peaks that finds every gap in your armour"] },
    jungle = { L["hot and humid, the air thick enough to drink"], L["sticky heat under the canopy, and the insects loud"] },
    desert = { L["hot and dry, with dust on the wind"], L["baking sun and cracked earth; drink when you can"] },
    ash = { L["smoke and ash on a hot wind"], L["scorched air, with cinders drifting"] },
    gloom = { L["grey and cold, a damp mist that clings"], L["a chill in the air and little light to speak of"] },
    mild = { L["mild and fair, with a gentle breeze"], L["pleasant weather, good for travelling"] },
    forest = { L["cool and green, the leaves whispering"], L["soft light through the trees, and the air fresh"] },
    marsh = { L["muggy and damp, the ground soft underfoot"], L["warm, wet air and the smell of the bog"] },
}
local CLIMATE_OF = {
    snow = { 1416, 1426, 1452, 1455 },
    jungle = { 1434, 1449 },
    desert = { 1411, 1413, 1418, 1441, 1443, 1446, 1451, 1454 },
    ash = { 1419, 1427, 1428 },
    gloom = { 1420, 1421, 1422, 1423, 1430, 1431, 1448, 1458 },
    mild = { 1412, 1417, 1424, 1425, 1429, 1432, 1433, 1436, 1442, 1447, 1453, 1456 },
    forest = { 1438, 1439, 1440, 1444, 1450, 1457 },
    marsh = { 1435, 1437, 1445 },
}
F.CLIMATE = {}
for climate, maps in pairs(CLIMATE_OF) do
    for _, map in ipairs(maps) do F.CLIMATE[map] = climate end
end

-- The map you are on, or the zone it is part of (a town's own map)
function F.Climate()
    if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
    local map = tonumber(Ask(C_Map.GetBestMapForUnit, "player"))
    for _ = 1, 3 do
        if not map then return nil end
        if F.CLIMATE[map] then return F.CLIMATE[map], map end
        local info = C_Map.GetMapInfo and Ask(C_Map.GetMapInfo, map)
        map = type(info) == "table" and tonumber(Plain(info.parentMapID)) or nil
    end
end

function F.TimeOfDay()
    local h = tonumber(Ask(GetGameTime))
    if not h then return nil end
    if h >= 5 and h < 7 then return L["Dawn"] end
    if h >= 7 and h < 12 then return L["Morning"] end
    if h >= 12 and h < 17 then return L["Afternoon"] end
    if h >= 17 and h < 21 then return L["Evening"] end
    return L["Night"]
end

-- The climate of where you land, by the zone in its name ("Booty Bay, Stranglethorn": Stranglethorn Vale), for
-- the weather said while you are still in the air over somewhere else
function F.ClimateOf(place)
    local _, zone = F.Split(place)
    zone = type(zone) == "string" and zone:lower() or nil
    if not (zone and C_Map and C_Map.GetMapInfo) then return nil end
    for map, climate in pairs(F.CLIMATE) do
        local info = Ask(C_Map.GetMapInfo, map)
        local name = type(info) == "table" and Plain(info.name)
        name = type(name) == "string" and name:lower() or nil
        if name and (name == zone or name:sub(1, #zone) == zone or zone:sub(1, #name) == name) then
            return climate, map
        end
    end
end

-- The line said as you land at `place` (ahead: still in the air, so by the place's own zone first), or nil where
-- the place's air is not known
function F.Weather(place, ahead)
    local climate, map
    if ahead then climate, map = F.ClimateOf(place) end
    if not climate then climate, map = F.Climate() end
    if not climate then return nil end
    local ways = F.CLIMATES[climate]
    local day = math.floor((time and time() or 0) / 86400)
    local air = ways[(day + map) % #ways + 1]
    local name = F.Split(place) or Ask(GetSubZoneText) or Ask(GetZoneText)
    local when = F.TimeOfDay()
    if type(name) == "string" and name ~= "" and when then return L["%s at %s: %s"]:format(when, name, air) end
    return air
end

-- As you come in to land: the weather where you land, said once, F.WEATHER_BEFORE seconds out
function F.WeatherAhead(now)
    local fl = F.flight
    if not (fl and fl.eta and fl.to and ns.db.flightWeather) or fl.weatherSaid then return end
    local left = fl.eta - (now - fl.at)
    if left > F.WEATHER_BEFORE or left <= 0 then return end
    fl.weatherSaid = true
    local line = F.Weather(fl.to, true)
    if line then Say(line) end
end

function F.SayWeather(place)
    if not (F.running and ns.db.flightWeather) or F.flight then return end
    local line = F.Weather(place)
    if line then Say(line) end
end

-- On a flight now? (the map just closed, control was lost): taken off
local function Check()
    if F.running and not F.flight and OnTaxi() then F.Start() end
end
Check = ns.Protect(Check)

local events = CreateFrame("Frame")
events:SetScript("OnEvent", ns.Protect(function(_, event)
    if event == "TAXIMAP_OPENED" then
        F.ReadMap()
        F.Seed()
        F.mount = F.MountOf()
        F.picked, F.pickedDist, F.hover = nil, nil, nil
        watchSince = 0
        watch:SetScript("OnUpdate", Watch)
    elseif event == "TAXIMAP_CLOSED" then
        watch:SetScript("OnUpdate", nil)
        F.Remember()                                          -- (one last look)
        local h = F.hover
        F.closedAt = GetTime()
        if h and h.at and F.closedAt - h.at <= F.HOVER_KEPT then
            F.picked, F.how, F.pickedDist, F.pickedStops = h.name, h.how, h.dist, h.stops
        end
        F.hover = nil
        for _, t in ipairs({ 0.5, 1.5, 3 }) do C_Timer.After(t, Check) end
    elseif event == "PLAYER_CONTROL_LOST" then
        C_Timer.After(0.3, Check)
        C_Timer.After(1.5, Check)
    elseif event == "PLAYER_CONTROL_GAINED" then
        if F.flight and not OnTaxi() then F.Land() end
    elseif event == "PLAYER_ENTERING_WORLD" then
        F.Resume()
    end
end))

-- After a reload in the air: the flight under way goes on (its time counted from when it began)
function F.Resume()
    if F.flight then
        if not OnTaxi() then F.Land() end
        return
    end
    local saved = ns.db.flightNow
    if not saved then return end
    local gone = time() - saved.at
    if not OnTaxi() or gone < 0 or gone > F.MAX then ns.db.flightNow = nil; return end
    F.Start({ from = saved.from, to = saved.to, at = GetTime() - gone, dist = saved.dist, map = saved.map,
              mount = saved.mount, stops = saved.stops, early = saved.early, eta = saved.eta, guess = saved.guess })
end

local EVENTS = { "TAXIMAP_OPENED", "TAXIMAP_CLOSED", "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED",
                 "PLAYER_ENTERING_WORLD" }
function F:Apply(run)
    local want = run and ns.db.flights and true or false
    if want == self.running then return end
    self.running = want
    if want then
        for _, e in ipairs(EVENTS) do pcall(events.RegisterEvent, events, e) end
        F.Resume()
    else
        events:UnregisterAllEvents()
        driver:SetScript("OnUpdate", nil)
        watch:SetScript("OnUpdate", nil)
        F.flight = nil                               -- (what was under way stays saved for a reload)
        if frame then frame:Hide() end
    end
end

function F.Describe()
    local routes, paces = 0, {}
    for _ in pairs(ns.db and ns.db.flightTimes or {}) do routes = routes + 1 end
    for map, rec in pairs(ns.db and ns.db.flightPace or {}) do paces[#paces + 1] = ("%s %.0f s (%d)"):format(map, rec.s, rec.n) end
    table.sort(paces)
    local fl = F.flight
    return ("flights on %s, taken %d, routes known %d (learned now %d), pace for guesses: %s, under way: %s; the game has: UnitOnTaxi %s, NumTaxiNodes %s, C_TaxiMap %s, route legs %s, node positions %s"):format(
        tostring(F.running), F.flights, routes, F.learned, #paces > 0 and table.concat(paces, ", ") or "none",
        fl and ("%s > %s (%s), eta %s"):format(tostring(fl.from), tostring(fl.to), tostring(F.how or "-"),
            fl.eta and (F.Clock(fl.eta) .. (fl.guess and " (a guess)" or "")) or "unknown") or "no",
        tostring(UnitOnTaxi ~= nil), tostring(NumTaxiNodes ~= nil), tostring(C_TaxiMap ~= nil),
        tostring(GetNumRoutes ~= nil and TaxiGetDestX ~= nil), tostring(TaxiNodePosition ~= nil))
end

ns.RegisterCommand("routes", function()
    local list = {}
    for route, rec in pairs(ns.db.flightTimes or {}) do list[#list + 1] = { route, rec.t } end
    table.sort(list, function(a, b) return a[1] < b[1] end)
    ns.Say(L["%d flight routes known."]:format(#list))
    for _, r in ipairs(list) do print(("  %s  %s"):format(r[1], F.Clock(r[2]))) end
end, "/cchud routes", "list the flight routes whose times are known")

ns.RegisterModule("flights", F)
