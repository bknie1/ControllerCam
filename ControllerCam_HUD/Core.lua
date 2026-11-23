-- ControllerCam HUD
-- A minimal action-game HUD that takes over while the Gamepad UI is in use.
--
-- Self-contained by design: nothing here writes to the game's saved interface settings. Blizzard's frames are
-- only put aside while the HUD runs, so turning the HUD off (or removing the addon) brings everything back.

local ADDON, ns = ...

-- The HUD's namespace, shared with its modules: each module is an addon of its own (ControllerCam_HUD_Fishing and
-- the others, loaded only while switched on: Modules.lua), and the game gives every addon a table of its own, so a
-- module's files take this one instead. ControllerCamHUD is also what the camera addon calls (Presets.lua).
ControllerCamHUD = ControllerCamHUD or {}
ControllerCamHUD.ns = ns

-- Is this addon one of ours? The HUD and its modules (the game names the addon it blames for a refused action)
function ns.IsOurAddon(name)
    return type(name) == "string" and not ns.IsSecret(name) and (name == ADDON or name:sub(1, #ADDON + 1) == ADDON .. "_")
end

-- English text is the key; translations can be added later without touching the code.
ns.L = ns.L or setmetatable({}, { __index = function(_, key) return key end })      -- Locales.lua fills it
local L = ns.L

ns.STYLE_CVAR = "InputDeviceInterfaceStyle"     -- "1" while the Gamepad UI is in use (what InputSwap switches)

local MOVABLE = { player = true, target = true, tot = true, focus = true, vertical = true, soon = true }

local DEFAULTS = {
    enabled = true,
    always = false,          -- also run in the mouse & keyboard UI
    hideBlizzard = true,     -- put the game's own player / target frames aside
    chat = false,            -- move the chat window to the top left (off: everything stays where WoW puts it)
    classColors = true,      -- colour your own bar, and other players' bars, by class
    vendor = true,           -- the vendor's "Sell junk" asks what to sell; quick move at vendor and bank
    textShade = true,
    combatColors = true,     -- in a fight, health is coloured by how much is left
    classIcons = true,       -- a class icon in front of a player's name on the target and target of target
    targetCompact = false,   -- the target frame a little over half as wide
    targetThreat = true,     -- the target frame says how your threat stands (Aggro, Pulling, Losing, your share)
    combatAlpha = 0.7,       -- your bars (and pet, focus) in a fight, until a call to action
    alertHealth = 0.5,       -- a call to action: your health below this share ...
    alertPower = 0.3,        -- ... or your mana below this one        -- a soft dark band behind the target's text
    textScale = 1.5,         -- text size (1 = the small desktop size; 1.5 reads well on a TV)
    idle = 0.3,              -- player bar opacity when nothing is happening (0 hides it)
    scale = 1,
    units = { player = true, target = true, pet = true, focus = true, vertical = false },
    verticalIdle = 0.3,      -- the vertical bars at full health or out of combat (0: gone until needed)
    pos = {},
}
ns.DEFAULTS = DEFAULTS

local PREFIX = "|cff66ccffControllerCam HUD:|r "
function ns.Say(msg) print(PREFIX .. msg) end

-- Lua errors are hidden by default, so ours are caught and shown once each.
local seen = {}
ns.errors = {}
function ns.Error(err)
    err = tostring(err)
    if seen[err] then return end
    seen[err] = true
    ns.errors[#ns.errors + 1] = err
    ns.Say("|cffff5555" .. L["error:"] .. "|r " .. err)
    if ns.db then                         -- kept (the last few) so they can be read again: /cchud errors
        ns.db.errorLog = ns.db.errorLog or {}
        table.insert(ns.db.errorLog, 1, { when = date and date("%Y-%m-%d %H:%M") or "", text = err })
        while #ns.db.errorLog > 15 do table.remove(ns.db.errorLog) end
    end
end

-- A short note of something a module did, for the debug reports (Debug.lua): the last 120 are kept, each
-- with the time it was left. Costs nothing while debug reports are off.
ns.notes = {}
function ns.Note(fmt, ...)
    if not (ns.db and ns.db.debug) then return end
    local ok, text = pcall(string.format, fmt, ...)
    if not ok then text = tostring(fmt) end
    local notes = ns.notes
    notes[#notes + 1] = ("%.1f %s"):format(GetTime and GetTime() or 0, text)
    if #notes > 120 then table.remove(notes, 1) end
end

-- Every handler of the HUD runs through this: an error is kept instead of breaking the rest, and the time it
-- took is counted by the game's own clock (Debug.lua's long frames, /cchud slow). A call that took long is kept
-- with the place it was made ("Rest.lua:251").
ns.spent = { now = 0, top = 0, topWhere = nil, calls = {}, depth = 0 }
ns.SLOW_MS = 20
local function Where()
    if type(debugstack) ~= "function" then return "?" end
    local ok, s = pcall(debugstack, 4, 1, 0)          -- (the line that asked for the handler)
    if not (ok and type(s) == "string") then return "?" end
    local file, line = s:match("([%w_]+%.lua)%]?:(%d+)")
    return file and (file .. ":" .. line) or s:sub(1, 60)
end
function ns.MapOpen()
    local m = _G.WorldMapFrame
    if type(m) ~= "table" or not m.IsShown then return false end
    local ok, shown = pcall(m.IsShown, m)
    return ok and shown == true
end
function ns.Slow(where, ms)
    local calls = ns.spent.calls
    calls[#calls + 1] = ("%.1f %s took %.0f ms%s"):format(GetTime and GetTime() or 0, tostring(where), ms,
        ns.MapOpen() and " (the map open)" or "")
    if #calls > 30 then table.remove(calls, 1) end
end
function ns.Protect(fn)
    local clock = debugprofilestop
    if type(clock) ~= "function" then
        return function(...)
            local ok, err = pcall(fn, ...)
            if not ok then ns.Error(err) end
        end
    end
    local where, S = Where(), ns.spent
    return function(...)
        S.depth = S.depth + 1
        local t0 = clock()
        local ok, err = pcall(fn, ...)
        local ms = clock() - t0
        S.depth = S.depth - 1
        if S.depth <= 0 then                                    -- (a handler inside another counts once)
            S.depth = 0
            S.now = S.now + ms
            if ms > S.top then S.top, S.topWhere = ms, where end
        end
        if ms >= ns.SLOW_MS then ns.Slow(where, ms) end
        if not ok then ns.Error(err) end
    end
end

-- A frame's alpha, plainly: nil where the game keeps it secret (in a battleground the game may keep a plate's, and
-- its name's, to itself; working anything out on it is refused, and each refusal counts as an addon error)
function ns.AlphaOf(f)
    if type(f) ~= "table" or not f.GetAlpha then return nil end
    local ok, a = pcall(f.GetAlpha, f)
    if ok and type(a) == "number" and not ns.IsSecret(a) then return a end
end

-- Shown, plainly: true only when the game says so in a value we may look at (a secret answer is never compared:
-- a blocked comparison counts as an addon error, even inside a pcall)
function ns.ShownPlain(f)
    if type(f) ~= "table" or not f.IsShown then return false end
    local ok, on = pcall(f.IsShown, f)
    return ok and not ns.IsSecret(on) and on == true or false
end

function ns.IsSecret(v)
    return type(issecretvalue) == "function" and issecretvalue(v) or false
end

-- What the game says, or nil when it keeps it secret (a secret cannot be tested, compared or used as a key)
function ns.Plain(v)
    if ns.IsSecret(v) then return nil end
    return v
end
-- A yes or no the game gives: false when it keeps it secret
function ns.Yes(v)
    if ns.IsSecret(v) then return false end
    return v and true or false
end

-- Is this unit your target? Asked of the game; when it keeps the answer secret (in a dungeon), by whether
-- its nameplate is your target's.
function ns.IsTarget(unit)
    if not unit then return false end
    local ok, same = pcall(UnitIsUnit, unit, "target")
    if ok and not ns.IsSecret(same) then return same and true or false end
    local get = C_NamePlate and C_NamePlate.GetNamePlateForUnit
    if not get then return false end
    local okA, a = pcall(get, unit)
    local okB, b = pcall(get, "target")
    return okA and okB and a ~= nil and a == b or false
end

-- A unit's GUID, or nil when the game keeps it secret (in dungeons, for one) or there is none. Never use
-- UnitGUID directly: a secret GUID cannot be a table key or be compared.
function ns.GUID(unit)
    if not unit or not UnitGUID then return nil end
    local ok, guid = pcall(UnitGUID, unit)
    if not ok or guid == nil or ns.IsSecret(guid) then return nil end
    return guid
end

function ns.Clamp(v, lo, hi)
    if v < lo then return lo elseif v > hi then return hi end
    return v
end

function ns.OnOff(b)
    return b and ("|cff33ff33" .. L["on"] .. "|r") or ("|cffff5555" .. L["off"] .. "|r")
end

-- "on"/"off" -> true/false; anything else (including nothing) flips the current value
function ns.Toggle(arg, current)
    if arg == "on" then return true elseif arg == "off" then return false end
    return not current
end

-- Money as the game writes it: 12g 3s 50c
function ns.Money(copper)
    copper = math.floor(copper or 0)
    local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    local parts = {}
    if g > 0 then parts[#parts + 1] = g .. "g" end
    if s > 0 then parts[#parts + 1] = s .. "s" end
    if c > 0 or #parts == 0 then parts[#parts + 1] = c .. "c" end
    return table.concat(parts, " ")
end

-- The same, in the coins' colours (gold, silver, copper), for tooltips
function ns.MoneyColored(copper)
    copper = math.floor(copper or 0)
    local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    local parts = {}
    if g > 0 then parts[#parts + 1] = "|cffffd700" .. g .. "g|r" end
    if s > 0 then parts[#parts + 1] = "|cffc7c7cf" .. s .. "s|r" end
    if c > 0 or #parts == 0 then parts[#parts + 1] = "|cffeda55f" .. c .. "c|r" end
    return table.concat(parts, " ")
end

---------------------------------------------------------------------------
-- What modules plug into: settings, commands, self-check rows
---------------------------------------------------------------------------
-- A setting: { key = "name in the saved settings", kind = "boolean" | "number", default =, min =, max =,
--              label = (text shown in options and chat), tip = (one line of explanation), section = (options heading),
--              command = "/cchud word", percent = true (numbers typed and shown as percent),
--              get =, set = (instead of key, for values that live elsewhere), onChange = (instead of a re-apply) }
ns.settings, ns.commands, ns.helpRows, ns.checks = {}, {}, {}, {}

function ns.Get(def)
    if def.get then return def.get() end
    return ns.db[def.key]
end

function ns.Set(def, value)
    if def.kind == "number" then value = ns.Clamp(value, def.min, def.max) end
    if def.set then def.set(value) else ns.db[def.key] = value end
    if def.onChange then def.onChange(value) else ns.Apply() end
end

function ns.RegisterCommand(name, fn, usage, text)
    ns.commands[name] = fn
    if usage then ns.helpRows[#ns.helpRows + 1] = { usage, text } end
end

function ns.RegisterCheck(fn) ns.checks[#ns.checks + 1] = fn end

-- Saved data of another shape (a list, say): fn gets what was saved and returns the cleaned value.
-- A module loaded after the settings were read (switched on during play) has its part cleaned as it registers.
ns.saved = {}
function ns.RegisterSaved(key, fn)
    ns.saved[key] = fn
    if ns.db then ns.db[key] = fn(ns.db[key]) end
end

-- A setting's saved value, cleaned: the default when it is missing or of the wrong kind, a number kept in range
local function Clean(def, v)
    if def.kind == "boolean" then
        if type(v) == "boolean" then return v end
        return def.default
    end
    return ns.Clamp(tonumber(v) or def.default, def.min, def.max)
end

function ns.RegisterSetting(def)
    ns.settings[#ns.settings + 1] = def
    if def.key and ns.db then ns.db[def.key] = Clean(def, ns.db[def.key]) end
    if def.command then
        local usage = "/cchud " .. def.command .. (def.kind == "boolean" and " on | off"
            or (" <%d-%d>"):format(def.min * (def.percent and 100 or 1), def.max * (def.percent and 100 or 1)))
        ns.RegisterCommand(def.command, function(arg)
            if def.kind == "boolean" then
                ns.Set(def, ns.Toggle(arg, ns.Get(def)))
                ns.Say(("%s: %s"):format(L[def.label], ns.OnOff(ns.Get(def))))
            else
                local n = tonumber(arg)
                if not n then ns.Say(L["usage:"] .. " " .. usage); return end
                ns.Set(def, def.percent and n / 100 or n)
                local v = ns.Get(def)
                ns.Say(("%s: %s"):format(L[def.label], def.percent and ("%d%%"):format(v * 100 + 0.5) or tostring(v)))
            end
            if ns.IsPending() then ns.Say(L["Changes are applied when combat ends."]) end
        end, usage, def.tip or def.label)
    end
    return def
end

---------------------------------------------------------------------------
-- Saved settings
---------------------------------------------------------------------------
-- Saved values no version reads any more (they are not kept for a module that may come back)
local DROPPED = { barsFade = true, barsIdle = true, nativeScale = true }

local function InitDB()
    local had = type(ControllerCamHUDDB) == "table"
    local old = had and ControllerCamHUDDB or {}
    if (tonumber(old.v) or 0) < 2 then old.chat = nil end      -- before version 2 the chat window moved by default
    -- before version 5 a plate on you showed its name even with "Name on your target's plate" off, which made
    -- names come and go in a fight; the option now means what it says, so it starts on again
    if (tonumber(old.v) or 0) < 5 then old.plateTargetName = nil end
    -- before version 6 the vertical bars sat closer in (on your character with the shoulder view): bars left at
    -- one of the old spots of a preset or the default take the new one; bars you placed elsewhere stay
    if (tonumber(old.v) or 0) < 6 and type(old.pos) == "table" and type(old.pos.vertical) == "table" then
        local x = tonumber(old.pos.vertical.x)
        if x == -240 or x == -260 or x == -280 or x == -300 then old.pos.vertical = nil end
    end
    -- before version 10 the vertical bars started further out, a long way from your character: bars still at
    -- one of those spots come in to the new one; bars you placed elsewhere stay
    if (tonumber(old.v) or 0) < 10 and type(old.pos) == "table" and type(old.pos.vertical) == "table" then
        local x = tonumber(old.pos.vertical.x)
        if x == -460 or x == -380 then old.pos.vertical.x = -320 end
    end
    -- before version 12 chat faded after 15 seconds, which was too soon: that old default becomes the new one
    if (tonumber(old.v) or 0) < 12 and tonumber(old.chatTime) == 15 then old.chatTime = nil end
    -- before version 12 nameplates showed the health number beside the percent to begin with; now the percent
    -- alone: plates still on that old default take the new one
    if (tonumber(old.v) or 0) < 12 and old.plateValue == true then old.plateValue = nil end
    -- and before version 11 a little further left than now: the same again
    if (tonumber(old.v) or 0) < 11 and type(old.pos) == "table" and type(old.pos.vertical) == "table" then
        if tonumber(old.pos.vertical.x) == -320 then old.pos.vertical.x = -280 end
    end
    -- before version 7 some presets switched class icons off: they are on again once (yours from now on)
    if (tonumber(old.v) or 0) < 7 then old.classIcons = nil end
    -- before version 8 the bar style could be left compact by a preset: full size again once (yours from now on)
    if (tonumber(old.v) or 0) < 8 then old.targetCompact, old.plateCompact = nil, nil end
    -- the gamepad bars' own fade became the fade of the whole screen: what you chose for it carries over
    if old.hudFade == nil and type(old.barsFade) == "boolean" then old.hudFade = old.barsFade end
    if old.hudIdle == nil and tonumber(old.barsIdle) then old.hudIdle = tonumber(old.barsIdle) end
    -- before version 13 the chat rewrites (class icon and level, short channel names, first names) were on by
    -- default: they wrap the game's chat frames, which taints them, and in a battleground every line then counted
    -- addon errors against us until the game warned. Off once for everyone (yours to turn on again, warned)
    if (tonumber(old.v) or 0) < 13 then old.chatInfo, old.chatShort, old.chatFirstName = nil, nil, nil end
    local db = { v = 13, units = {}, pos = {}, saved = {} }
    -- game settings we changed, with the value they had (put back when the HUD stops)
    if type(old.saved) == "table" then
        for name, value in pairs(old.saved) do
            if type(name) == "string" and type(value) == "string" then db.saved[name] = value end
        end
    end
    for _, key in ipairs({ "probe", "check", "auraReport", "plateReport", "padReport" }) do
        if type(old[key]) == "table" then db[key] = old[key] end
    end
    for _, key in ipairs({ "enabled", "always", "hideBlizzard", "chat", "classColors", "textShade", "vendor", "combatColors", "classIcons", "targetCompact", "targetThreat" }) do
        if type(old[key]) == "boolean" then db[key] = old[key] else db[key] = DEFAULTS[key] end
    end
    db.idle = ns.Clamp(tonumber(old.idle) or DEFAULTS.idle, 0, 1)
    db.verticalIdle = ns.Clamp(tonumber(old.verticalIdle) or DEFAULTS.verticalIdle, 0, 1)
    for _, key in ipairs({ "combatAlpha", "alertHealth", "alertPower" }) do
        db[key] = ns.Clamp(tonumber(old[key]) or DEFAULTS[key], 0, 1)
    end
    db.scale = ns.Clamp(tonumber(old.scale) or DEFAULTS.scale, 0.5, 2)
    if (tonumber(old.v) or 0) < 4 then old.textScale = nil end   -- the default text size changed in versions 3 and 4
    db.textScale = ns.Clamp(tonumber(old.textScale) or DEFAULTS.textScale, 0.8, 2.5)
    for key, default in pairs(DEFAULTS.units) do
        local v
        if type(old.units) == "table" then v = old.units[key] end
        if type(v) == "boolean" then db.units[key] = v else db.units[key] = default end
    end
    if type(old.pos) == "table" then
        for key, p in pairs(old.pos) do
            if MOVABLE[key] and type(p) == "table" and tonumber(p.x) and tonumber(p.y) then
                db.pos[key] = { x = tonumber(p.x), y = tonumber(p.y) }
            end
        end
    end
    -- selling: auto (sell as soon as a vendor opens), gear (white weapons and armor count as junk),
    -- deposit (bank the marked items as soon as the bank opens), junk / keep / bank (items marked by hand)
    local sell = type(old.sell) == "table" and old.sell or {}
    db.sell = { auto = sell.auto == true, gear = sell.gear == true, deposit = sell.deposit == true,
                junk = {}, keep = {}, bank = {} }
    for _, list in ipairs({ "junk", "keep", "bank" }) do
        if type(sell[list]) == "table" then
            for id, on in pairs(sell[list]) do
                if type(id) == "number" and on == true then db.sell[list][id] = true end
            end
        end
    end
    for key, clean in pairs(ns.saved) do db[key] = clean(old[key]) end
    local claimed = {}
    for _, def in ipairs(ns.settings) do
        if def.key then
            db[def.key] = Clean(def, old[def.key])
            claimed[def.key] = true
        end
    end
    -- what no setting here claims is kept as it was: the settings of a module that is not loaded (switched off,
    -- Modules.lua) must still be there when it is switched on again. Each is cleaned when its module registers it.
    for key, v in pairs(old) do
        if type(key) == "string" and db[key] == nil and not claimed[key] and ns.saved[key] == nil
            and not DROPPED[key] and type(v) ~= "function" then
            db[key] = v
        end
    end
    -- a first run rests, switched off, until it is known whether the HUD is wanted at all (Welcome.lua);
    -- settings from before mean it was
    if type(old.asked) == "boolean" then db.asked = old.asked else db.asked = had end
    if not had then db.enabled = false end
    db.screenAsked = old.screenAsked == true           -- the screen layout was offered (Welcome.lua)
    db.sizedFor = (old.sizedFor == "tv" or old.sizedFor == "monitor") and old.sizedFor or nil
    ControllerCamHUDDB = db
    ns.db = db
end

---------------------------------------------------------------------------
-- When the HUD runs
---------------------------------------------------------------------------
function ns.IsGamepadUI()
    return GetCVar(ns.STYLE_CVAR) == "1"
end

function ns.ShouldRun()
    return ns.db ~= nil and ns.db.enabled and (ns.db.always or ns.IsGamepadUI())
end

-- Blizzard frames are put under a hidden parent while we replace them, and given back afterwards.
local hiddenParent = CreateFrame("Frame", "ControllerCamHUDHidden", UIParent)
hiddenParent:Hide()
local putAside = {}

function ns.SetBlizzardHidden(name, hide)
    local frame = _G[name]
    if not frame then return end
    if hide and not putAside[name] then
        putAside[name] = frame:GetParent() or UIParent
        frame:SetParent(hiddenParent)
    elseif not hide and putAside[name] then
        frame:SetParent(putAside[name])
        putAside[name] = nil
    end
end

function ns.IsBlizzardHidden(name) return putAside[name] ~= nil end

-- Keeping a frame of the game at an alpha of ours. The game sets the alpha of some of its frames itself (range,
-- fading); we never hook those calls (code of ours running inside the game's own would taint it, and an
-- action button pressed after it could be refused). Instead our own timer looks a few times a second and puts
-- our alpha back.
local kept = {}                  -- frame -> alpha we want it at
local keeper = CreateFrame("Frame")
local since = 0
local function Keep()
    for frame, a in pairs(kept) do
        if ns.AlphaOf(frame) ~= a then frame:SetAlpha(a) end
    end
end
keeper:SetScript("OnUpdate", function(_, dt)
    since = since + dt
    if since < 0.1 then return end
    since = 0
    local ok, err = pcall(Keep)
    if not ok then ns.Error(err) end
end)
ns.KeepAlpha = function(frame, a)
    if a == nil then kept[frame] = nil; return end
    kept[frame] = a
    if ns.AlphaOf(frame) ~= a then frame:SetAlpha(a) end
end

-- The same, looked at every frame: for what the game sets again and again as you move (a nameplate's own
-- drawing, faded by distance), where a tenth of a second is long enough to see it flash through. ns.alphaFixes
-- counts how often the game had shown one again (the debug report says it).
local keptFast = {}
ns.alphaFixes = 0
local fastKeeper = CreateFrame("Frame")
local function KeepFast()
    local any = false
    for frame, a in pairs(keptFast) do
        any = true
        if ns.AlphaOf(frame) ~= a then
            frame:SetAlpha(a)
            ns.alphaFixes = ns.alphaFixes + 1
        end
    end
    if not any then fastKeeper:SetScript("OnUpdate", nil) end
end
local function FastTick()
    local ok, err = pcall(KeepFast)
    if not ok then ns.Error(err) end
end
ns.KeepAlphaFast = function(frame, a)
    if a == nil then keptFast[frame] = nil; return end
    keptFast[frame] = a
    if ns.AlphaOf(frame) ~= a then frame:SetAlpha(a) end
    fastKeeper:SetScript("OnUpdate", FastTick)
end

-- Or only made invisible: the frame stays in place and keeps working (targeting, the controller's unit menu,
-- Edit Mode), under our look.
local faded = {}

function ns.SetBlizzardFaded(name, fade)
    local frame = _G[name]
    if not frame or not frame.SetAlpha then return end
    if fade then
        if not faded[name] then faded[name] = ns.AlphaOf(frame) or 1 end
        ns.KeepAlpha(frame, 0)
    elseif faded[name] then
        local was = faded[name]
        faded[name] = nil
        ns.KeepAlpha(frame, nil)
        frame:SetAlpha(was)
    end
end

function ns.IsBlizzardFaded(name) return faded[name] ~= nil end

-- A window of ours that works with the controller takes its buttons by key bindings of its own: set while the
-- window is open, cleared when it closes, each button bound to a plain button of ours that tells the window.
-- Never by catching the controller's presses and passing the rest on to the game: the game's own handling of
-- such a press (interact, an action, cancel) then runs after code of ours, and the game may refuse it and
-- what follows. Buttons the window has no use for are not touched at all: they stay the game's.
-- Bindings change out of combat only: a fight clears them at once (onLost is told, to close the window), and a
-- change asked for in a fight is made when it ends.
function ns.PadKeys(tag, keys, handler, onLost)
    local K = { on = false, want = false, buttons = {} }
    local owner = CreateFrame("Frame")
    for _, key in ipairs(keys) do
        local b = CreateFrame("Button", "ControllerCamHUD_Key_" .. tag .. "_" .. key, UIParent)
        b:SetScript("OnClick", ns.Protect(function() handler(key) end))
        K.buttons[key] = b
    end
    local function Put()
        if K.want == K.on or InCombatLockdown() then return end
        ClearOverrideBindings(owner)
        if K.want and SetOverrideBindingClick then
            for _, key in ipairs(keys) do
                SetOverrideBindingClick(owner, true, key, "ControllerCamHUD_Key_" .. tag .. "_" .. key, "LeftButton")
            end
        end
        K.on = K.want
    end
    function K:Set(on)
        self.want = on and true or false
        Put()
    end
    pcall(owner.RegisterEvent, owner, "PLAYER_REGEN_DISABLED")
    pcall(owner.RegisterEvent, owner, "PLAYER_REGEN_ENABLED")
    owner:SetScript("OnEvent", ns.Protect(function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then
            if K.on then                                  -- (bindings can still be cleared at this moment)
                ClearOverrideBindings(owner)
                K.on, K.want = false, false
                if onLost then onLost() end
            end
        else
            Put()
        end
    end))
    return K
end

-- A question of ours ("Sell 12 items?") is asked in a window of ours, answered with the controller through
-- key bindings of its own (above) or with the mouse. It is never put in the game's own dialog box: that box
-- is the game's, the controller's cursor works on it with the game's code, and a dialog an addon put there
-- (or one an addon presses a button of) leaves that code running in the addon's name, with the game then
-- refusing what it does next. Seen here as the gamepad bars refusing their own buttons after a vendor.
--   ns.Dialog.Define(which, { text =, button1 =, button2 =, button3 =, button4 =, OnAccept =, OnCancel =,
--                             OnAlt =, OnExtra =, Footer = function returning a line to add, hideOnEscape = false,
--                             list = true (a list: read from the left, in a wider window) })
--   ns.Dialog.Show(which, ...)            the text's %s and %d are filled from the rest
-- button1 is A (accept), button2 is B (cancel; Escape too unless hideOnEscape is false), button3 is X
-- (OnAlt), button4 is Y (OnExtra).
-- OnCancel(nil, nil, reason): "clicked" when you said no, "override" when it was only taken off the screen
-- (another question, a fight), which is not an answer.
local Dialog = { specs = {}, log = {}, KEYS = { "PAD1", "PAD2", "PAD3", "PAD4", "ESCAPE" } }
ns.Dialog = Dialog
local dialogFrame

function Dialog.Define(which, spec) Dialog.specs[which] = spec end

local function DialogButton(parent, index)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(150, 26)
    b.back = b:CreateTexture(nil, "BACKGROUND")
    b.back:SetAllPoints(b)
    b.back:SetColorTexture(0.16, 0.2, 0.3, 0.9)
    b.text = ns.FontString(b, 11, "CENTER")
    b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
    b:SetScript("OnClick", ns.Protect(function() Dialog.Click(index) end))
    return b
end

local function BuildDialog()
    local f = CreateFrame("Frame", "ControllerCamHUD_Dialog", UIParent)
    f:SetSize(440, 150)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true)
    f.back = f:CreateTexture(nil, "BACKGROUND")
    f.back:SetAllPoints(f)
    f.back:SetColorTexture(0.03, 0.04, 0.07, 0.94)
    for _, side in ipairs({ "TOP", "BOTTOM" }) do
        local t = f:CreateTexture(nil, "BORDER")
        t:SetPoint(side .. "LEFT", f, side .. "LEFT")
        t:SetPoint(side .. "RIGHT", f, side .. "RIGHT")
        t:SetHeight(1)
        t:SetColorTexture(0.55, 0.62, 0.75, 0.6)
    end
    f.text = ns.FontString(f, 12, "CENTER")
    f.text:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -16)
    f.text:SetPoint("TOPRIGHT", f, "TOPRIGHT", -18, -16)
    if f.text.SetWordWrap then f.text:SetWordWrap(true) end
    f.buttons = { DialogButton(f, 1), DialogButton(f, 2), DialogButton(f, 3), DialogButton(f, 4) }
    f:Hide()
    dialogFrame = f
    Dialog.frame = f
    Dialog.keys = ns.PadKeys("Ask", Dialog.KEYS, function(key)
        local v = Dialog.visible
        if not v then return end
        if key == "PAD1" then Dialog.Click(1)
        elseif key == "PAD2" then Dialog.Click(2)
        elseif key == "PAD3" then if v.dialog.button3 then Dialog.Click(3) end
        elseif key == "PAD4" then if v.dialog.button4 then Dialog.Click(4) end
        elseif key == "ESCAPE" then if v.dialog.hideOnEscape ~= false then Dialog.Click(2) end
        end
    end, function() Dialog.Close("override") end)
end

local function KeyLabel(key, text)
    local name = ns.KeyText and ns.KeyText(key) or (GetBindingText and GetBindingText(key)) or key
    if type(name) ~= "string" or name == "" then name = key end
    return ("%s  %s"):format(name, text)
end

function Dialog.Show(which, ...)
    local spec = Dialog.specs[which]
    if not spec then return false end
    if Dialog.visible then Dialog.Close("override") end
    if not dialogFrame then BuildDialog() end
    local f = dialogFrame
    local ok, text = pcall(string.format, spec.text, ...)
    text = ok and text or spec.text
    if spec.Footer then                                       -- a line under it that depends on the moment
        local okF, footer = pcall(spec.Footer)
        if okF and type(footer) == "string" and footer ~= "" then text = text .. "\n\n" .. footer end
    end
    f.text:SetJustifyH(spec.list and "LEFT" or "CENTER")
    f.text:SetText(text)
    local order = { { 1, spec.button1, "PAD1" }, { 3, spec.button3, "PAD3" }, { 4, spec.button4, "PAD4" },
                    { 2, spec.button2, "PAD2" } }
    local shown = {}
    for _, o in ipairs(order) do
        local b = f.buttons[o[1]]
        if o[2] then
            b.text:SetText(KeyLabel(o[3], o[2]))
            b:Show()
            shown[#shown + 1] = b
        else
            b:Hide()
        end
    end
    f:SetWidth(math.max(spec.list and 520 or 440, #shown * 160 + 20))
    for i, b in ipairs(shown) do                              -- side by side along the bottom, centred
        b:ClearAllPoints()
        b:SetPoint("BOTTOM", f, "BOTTOM", (i - (#shown + 1) / 2) * 160, 14)
    end
    -- as tall as its words, measured once they are laid out (guessed from the text where that cannot be had)
    local okH, h = pcall(f.text.GetStringHeight, f.text)
    if not (okH and type(h) == "number" and h > 0) then
        local lines = 1
        for _ in text:gmatch("\n") do lines = lines + 1 end
        h = (lines + math.floor(#text / 60)) * 15
    end
    f:SetHeight(math.max(120, h + 76))
    f:Show()
    Dialog.visible = { which = which, text = text, dialog = spec }
    Dialog.log[#Dialog.log + 1] = Dialog.visible
    Dialog.keys:Set(true)
    return true
end

local function TakeDown()
    local v = Dialog.visible
    Dialog.visible = nil
    if dialogFrame then dialogFrame:Hide() end
    if Dialog.keys then Dialog.keys:Set(false) end
    return v
end

-- You answered: 1 the first button, 2 the second (no), 3 the third, 4 the fourth
function Dialog.Click(index)
    local v = TakeDown()
    if not v then return end
    local spec = v.dialog
    if index == 1 then
        if spec.OnAccept then spec.OnAccept() end
    elseif index == 3 then
        if spec.OnAlt then spec.OnAlt() end
    elseif index == 4 then
        if spec.OnExtra then spec.OnExtra() end
    elseif spec.OnCancel then
        spec.OnCancel(nil, nil, "clicked")
    end
end

-- Taken off the screen without an answer
function Dialog.Close(reason)
    local v = TakeDown()
    if v and v.dialog.OnCancel then v.dialog.OnCancel(nil, nil, reason or "override") end
end

-- While the game's Edit Mode is open the screen is being arranged: frames of the game that we draw over are
-- given back, so they can be seen and dragged, and our versions step aside until it closes.
ns.arranging = false
local function HookArranging()
    local manager = _G.EditModeManagerFrame
    if ns.arrangeHooked or type(manager) ~= "table" or not manager.HookScript then return end
    ns.arrangeHooked = true
    manager:HookScript("OnShow", ns.Protect(function() ns.arranging = true; ns.Apply() end))
    manager:HookScript("OnHide", ns.Protect(function() ns.arranging = false; ns.Apply() end))
end

-- Modules: { Apply = function(self, run) end }. Apply is only called out of combat.
ns.modules = {}
function ns.RegisterModule(name, module)
    module.name = name
    ns.modules[#ns.modules + 1] = module
end

local pending = false
function ns.Apply()
    if not ns.db then return end
    if InCombatLockdown() then pending = true; return false end
    pending = false
    if ns.LoadWanted then ns.LoadWanted() end          -- a module switched on: its addon now (Modules.lua)
    local run = ns.ShouldRun()
    for _, module in ipairs(ns.modules) do
        local ok, err = pcall(module.Apply, module, run)
        if not ok then ns.Error(module.name .. ": " .. tostring(err)) end
    end
    return true
end

function ns.IsPending() return pending end

local f = CreateFrame("Frame", "ControllerCamHUDFrame", UIParent)
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
pcall(f.RegisterEvent, f, "CVAR_UPDATE")        -- a game option changed in its own menus
f:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        InitDB()
        if ns.LoadWanted then ns.LoadWanted() end      -- the modules switched on, before the game logs in
    elseif event == "PLAYER_LOGIN" then
        if not ns.db then InitDB() end
        if ns.Welcome then ns.Welcome.Login() end
        HookArranging()
        ns.Apply()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pending then ns.Apply() end
    elseif event == "CVAR_UPDATE" then
        if ns.db and arg1 == ns.NATIVE.tot then ns.Apply() end
    end
end)
