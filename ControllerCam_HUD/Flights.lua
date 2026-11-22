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

local ADDON, ns = ...
local L = ns.L

local F = { running = false, flights = 0, learned = 0 }
ns.Flights = F

ns.RegisterSetting({
    key = "flights", kind = "boolean", default = true, command = "flights", section = "Quests, chat and map",
    label = "Flights: time and countdown",
    tip = "on a flight, where to and how long is said in chat, and a bar at the top of the screen counts down to the landing; each route's time is learned from your flights",
})

ns.RegisterSetting({
    key = "flightRider", kind = "boolean", default = true, command = "flightrider", section = "Quests, chat and map",
    label = "Flights: your mount along the bar",
    tip = "a gryphon, a wind rider or a bat (whichever the flight master gave you) glides along the flight bar towards where you land",
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
-- The flight under way when the game was reloaded: { from, to, at = time(), dist, map }
ns.RegisterSaved("flightNow", function(old)
    if type(old) ~= "table" or not tonumber(old.at) then return nil end
    return { from = type(old.from) == "string" and old.from or nil, to = type(old.to) == "string" and old.to or nil,
             at = tonumber(old.at), dist = tonumber(old.dist), map = type(old.map) == "string" and old.map or nil,
             mount = type(old.mount) == "string" and old.mount or nil }
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
        h = { name = name, slot = slot, how = how, dist = F.Distance(slot) }
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
    if not fl.to then
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
                            mount = fresh and F.mount or nil }
    fl.mount = F.MOUNTS[fl.mount or ""] and fl.mount or F.MountOf()
    F.flight, F.picked, F.pickedDist = fl, nil, nil
    F.flights = F.flights + 1
    local route = F.Route(fl.from, fl.to)
    local rec = route and ns.db.flightTimes[route]
    fl.eta, fl.guess = rec and rec.t or nil, nil
    local pace = not fl.eta and fl.to and fl.dist and fl.map and ns.db.flightPace[fl.map]
    if pace then fl.eta, fl.guess = fl.dist * pace.s, true end        -- not flown yet: a guess from the distance
    if not resumed then
        ns.db.flightNow = { from = fl.from, to = fl.to, at = time(), dist = fl.dist, map = fl.map, mount = fl.mount }
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
    ns.Note("flight: landed at %s after %s (route %s)", tostring(to), F.Clock(took), tostring(route))
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
            F.picked, F.how, F.pickedDist = h.name, h.how, h.dist
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
              mount = saved.mount })
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
