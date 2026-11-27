-- ControllerCam HUD: the modules, each an addon of its own that is loaded only while it is switched on.
-- A part you switch off costs nothing: its files are not read, its frames are never made, nothing of it runs.
--   * The switches are here, in the core, so each is always in the options and in /cchud, loaded or not.
--   * A module is loaded (C_AddOns.LoadAddOn) once the settings are read, when one of its switches is on, and at
--     once when you switch it on during play (after combat). Its other settings register as it loads.
--   * Switched off it stops at once, as every part does; its memory is freed at your next /reload.
--   * Its settings are kept while it is not loaded (Core.lua keeps what no setting claims).
--   * A command or key binding of a module that is off says how to switch it on.
-- The modules' files start with `local ns = ControllerCamHUD.ns`: one namespace for the HUD and its modules.

local ADDON, ns = ...
local L = ns.L

-- Each module: its addon (the folder), the switches that load it, its other settings that /cchud export carries
-- while it is not loaded (with their defaults), what it needs loaded first (its toc's Dependencies, which the
-- game loads by itself), its commands besides the switches', and the key bindings (Bindings.xml) it answers
local MODULES = {
    { addon = "ControllerCam_HUD_Nameplates", switches = { "nameplates" },
      keys = { plateValue = false, plateDebuffs = true, plateAllDebuffs = false, plateBuffs = true,
               plateCC = true, plateThreat = true, threatPercent = false, plateQuest = true, plateMotion = true,
               plateTitles = true, plateSubtitles = true, plateFriendBars = true, plateFriendsGame = false,
               platePower = true, plateCastTarget = true, platePercent = true, plateTargetName = true,
               plateLevels = true, plateCompact = false, plateCastAlert = true, plateClassIcons = true,
               plateServiceIcons = true, plateHoverNPC = false, plateObjects = false, plateSize = 2,
               plateName = 1, plateLook = 1, plateMini = true, plateFriendsInside = true,
               plateFriendsHide = false },
      commands = { "names", "platealldebuffs", "platebuffs", "platecastalert", "platecasttarget", "platecc",
                   "plateclassicons", "platecompact", "platedebuffs", "platefriendbars", "platefriendsgame",
                   "platefriendshide", "platefriendsinside", "platehovernpc", "platelevels", "platelook", "platemini",
                   "platemotion", "platename", "plateobjects", "platepercent", "platepower", "platequest", "plates",
                   "plateserviceicons", "platesize", "platesubtitles", "platetargetname", "platethreat",
                   "platetitles", "platevalue", "threatpercent" } },
    { addon = "ControllerCam_HUD_Group", switches = { "group" }, keys = { healerFrames = 2 },
      commands = { "healerframes" } },
    { addon = "ControllerCam_HUD_Numbers",
      switches = { "numbers", "readyAlerts", "soonCallouts", "soonBuffs", "bigMoments", "abilityRumble" },
      keys = { momentPlace = 1 },
      commands = { "momentplace", "momenttest" } },
    { addon = "ControllerCam_HUD_Bags", switches = { "bagWindow" }, keys = { bagOrder = 1 }, commands = { "bagorder" } },
    { addon = "ControllerCam_HUD_Market", switches = { "ahPanel" },
      keys = { ahVoice = true, ahShowKept = false, ahCandles = false },
      commands = { "ahcandles", "ahinfo", "ahkept", "ahvoice", "market" }, bindings = { "ControllerCamHUD_Market" } },
    { addon = "ControllerCam_HUD_Mentor", switches = { "skillPlan", "skillBank", "farmList" },
      keys = { farmSide = 1 },
      commands = { "farm", "levelplan" },
      bindings = { "ControllerCamHUD_SkillPlan", "ControllerCamHUD_Farm", "ControllerCamHUD_FarmAdd" } },
    { addon = "ControllerCam_HUD_Transmog", switches = { "transmogSets", "tipAppearance" } },
    { addon = "ControllerCam_HUD_Compass", switches = { "compass" }, keys = { compassPlace = 1 },
      commands = { "compassdemo", "compassplace" } },
    { addon = "ControllerCam_HUD_Fishing", switches = { "fishMode", "fishJournal", "fishPanel" },
      keys = { fishRecast = true, fishBait = true, fishHideBars = true, fishGame = true },
      commands = { "fish", "fishbait", "fishgame", "fishhidebars", "fishkey", "fishplay", "fishrecast", "journal" },
      bindings = { "ControllerCamHUD_Fishing", "ControllerCamHUD_FishJournal" } },
    { addon = "ControllerCam_HUD_Narrative", switches = { "narrative" }, keys = { commentary = true },
      commands = { "commentary" } },
    { addon = "ControllerCam_HUD_Campfire", switches = { "campScene" }, commands = { "campfire" } },
    { addon = "ControllerCam_HUD_Flights", switches = { "flights", "flightScene", "flightGame" },
      keys = { flightRider = true, flightWeather = true, flightOrbit = true },
      needs = { "ControllerCam_HUD_Campfire" },        -- the flight on film is the camp fire's film
      commands = { "flightorbit", "flightplay", "flightrider", "flightscores", "flightweather", "routes" },
      bindings = { "ControllerCamHUD_FlightGame" } },
}

local MO = { list = MODULES, byAddon = {}, bySwitch = {}, byCommand = {} }
ns.ModuleList = MO
for _, m in ipairs(MODULES) do
    m.state = "off"           -- off, loaded, missing (no folder), disabled (unticked in the AddOns list) or refused
    MO.byAddon[m.addon] = m
    for _, key in ipairs(m.switches) do MO.bySwitch[key] = m end
    for _, cmd in ipairs(m.commands or {}) do MO.byCommand[cmd] = m end
end

---------------------------------------------------------------------------
-- The switches (their own words, as they were in each module)
---------------------------------------------------------------------------
ns.RegisterSetting({
    key = "nameplates", kind = "boolean", default = true, command = "nameplates", section = "Nameplates",
    label = "Nameplates",
    tip = "our look on the game's nameplates (its nameplate options still apply)",
})

ns.RegisterSetting({
    key = "group", kind = "boolean", default = true, command = "group", section = "Frames",
    label = "Party and raid frames",
    tip = "draw our look over the game's party and raid frames (their targeting and options keep working)",
})

ns.RegisterSetting({
    key = "numbers", kind = "boolean", default = true, command = "numbers", section = "Frames",
    label = "Stylized numbers on you",
    tip = "the damage and healing you take pop like your own hits, instead of the game's scrolling text (follows the game's option for combat text on you)",
})

ns.RegisterSetting({
    key = "readyAlerts", kind = "boolean", default = true, command = "ready", section = "Frames",
    label = "Abilities ready",
    tip = "when an ability only a moment allows becomes usable (Mongoose Bite, Overpower, Revenge, Riposte, Counterattack) or the game lights one up on your bar: its name in bold red in the middle of the screen for a moment",
})

ns.RegisterSetting({
    key = "soonCallouts", kind = "boolean", default = true, command = "cdcallout", section = "Frames",
    label = "Cooldowns coming back",
    tip = "your key abilities rise and grow beside your character in the last two seconds of their cooldown, then pop gold the moment they are ready (in place of a cooldown bar)",
})

ns.RegisterSetting({
    key = "soonBuffs", kind = "boolean", default = true, command = "buffcallout", section = "Frames",
    label = "Buffs wearing off",
    tip = "a buff you cast on yourself (a Seal, Holy Shield, a shout or shield) calls out with your cooldowns as it runs out, and in red the moment it is gone, also when it is used up early",
})

ns.RegisterSetting({
    key = "bigMoments", kind = "boolean", default = true, command = "bigmoments", section = "Effects",
    label = "Big moments",
    tip = "a burst is pinned big and golden in the middle of the screen: crits landing back to back, each within a second of the last (a double swing, Judgement and Holy Strike together), with what they did together (at most twice a fight)",
})

ns.RegisterSetting({
    key = "abilityRumble", kind = "boolean", default = true, command = "abilityrumble", section = "Effects",
    label = "Rumble: your key abilities",
    tip = "each class's key abilities have a feel of their own on the controller (a Judgement splashes, a Holy Strike snaps, Windfury knocks three times)",
})

ns.RegisterSetting({
    key = "bagWindow", kind = "boolean", default = false, command = "bagwindow", section = "Bags, bank and vendor",
    label = "Our own bag window (experimental)",
    tip = "your bags in a window of the HUD's own, in place of the game's: every item together, the empty slots gathered at the end, your bags in a row of their own, and quick filters along the top (LB and RB). The bank too, while it is open. Off, as it starts: the game's own bags and bank, with our quick sort (R3), quick deposit and withdraw, and the item tooltips' extra lines",
})

ns.RegisterSetting({
    key = "ahPanel", kind = "boolean", default = true, command = "ahpanel", section = "Bags, bank and vendor",
    label = "Market tab at the auction house",
    tip = "a Market tab on the auction house: what in your bags is worth selling there and why, a price chart beside it, and posting in one press",
})

ns.RegisterSetting({
    key = "skillPlan", kind = "boolean", default = true, command = "levelhelp", section = "Bags, bank and vendor",
    label = "The Mentor: a levelling plan beside the profession window",
    tip = "while a profession's window is open, a panel beside it says which recipes to make and how many to reach the cap, and what that takes, down to the ore and herbs; an estimate from the recipes' colours",
})

ns.RegisterSetting({
    key = "skillBank", kind = "boolean", default = true, command = "skillbank", section = "Bags, bank and vendor",
    label = "Profession window: how many you could make with your bank",
    tip = "beside the game's count of a recipe you can make from your bags, a second count in blue includes the reagents in your bank. It shows only when that makes more",
    onChange = function()
        ns.Apply()
        local BK = ns.Levelling and ns.Levelling.Bank
        if BK and BK.Refresh then BK:Refresh() end
    end,
})

ns.RegisterSetting({
    key = "farmList", kind = "boolean", default = true, command = "farmlist", section = "Quests",
    label = "Farm list beside the quest list",
    tip = "things you mean to gather, with how many you have and how many you want: your bags and bank and your other characters' on this realm. Add the reagents of a levelling plan with one button, or any item",
})

ns.RegisterSetting({
    key = "transmogSets", kind = "boolean", default = true, command = "transmogsets", section = "Items and auction house",
    label = "Sets tab at the transmogrifier",
    tip = "a Sets tab in the Transmogrify window: gear from your collection that shares a name (Green Iron Helm, Green Iron Gauntlets...) and the game's own sets, put on your outfit in one press, with Undo; nothing is kept or paid until you press Apply",
})

ns.RegisterSetting({
    key = "tipAppearance", kind = "boolean", default = true, command = "tipappearance", section = "Items and auction house",
    label = "Appearance collected, in item tooltips",
    tip = "under the tooltip of gear and cosmetics: whether its look is in your collection yet, or only through another item that looks the same, so you can tell what is new to you",
})

ns.RegisterSetting({
    key = "compass", kind = "boolean", default = true, command = "compass", section = "Quests",
    label = "Quest compass",
    tip = "a compass along the top of the screen: the way you face, and your quests where they lie, each with how far it is. The quest the game points you to stands out",
})

ns.RegisterSetting({
    key = "fishMode", kind = "boolean", default = true, command = "fishmode", section = "Fishing",
    label = "One-button fishing",
    tip = "with a fishing pole in your hands: your interact button to cast your line whenever there is nothing to interact with, and again to hook the fish when the float bobs; the catch is taken for you. B to put the pole away and take your weapons back",
})

ns.RegisterSetting({
    key = "fishJournal", kind = "boolean", default = true, command = "fishjournal", section = "Fishing",
    label = "Fish journal",
    tip = "every catch is written into your fish journal: how many of each kind, where you first landed it, and a weight made up for fun with your best of each (/cchud journal opens it)",
})

ns.RegisterSetting({
    key = "fishPanel", kind = "boolean", default = true, command = "fishpanel", section = "Fishing",
    label = "Fishing interface",
    tip = "with a fishing pole in your hands: the fish of the water you stand at (the ones you have not landed here stay hidden), your Fishing skill and what your bait adds, how many you caught and how many got away, how long your bait lasts, and your latest catches",
})

ns.RegisterSetting({
    key = "narrative", kind = "boolean", default = true, command = "narrative", section = "General",
    label = "Narrative: characters in the windows",
    tip = "every window the HUD improves has someone who helps you, with their portrait and a short line on what is in front of you and why: you over your bags and at the water, the vendor, the banker, the Postmaster, the flight master, the Broker at the auction house and The Mentor at your profession; off: the windows are plain and quiet",
})

ns.RegisterSetting({
    key = "campScene", kind = "boolean", default = true, command = "campscene", section = "Effects",
    label = "Campfire scene",
    tip = "sit still at a camp for a few seconds and the screen turns to film for a minute: the camera circles you, your big moments since the last camp are told (bosses, levels, professions, new mounts), and the camp's buffs close it, by class. Any move or button ends it",
})

ns.RegisterSetting({
    key = "flights", kind = "boolean", default = true, command = "flights", section = "Quests, chat and map",
    label = "Flights: time and countdown",
    tip = "on a flight, where to and how long is said in chat, and a bar at the top of the screen counts down to the landing; each route's time is learned from your flights",
})

ns.RegisterSetting({
    key = "flightScene", kind = "boolean", default = true, command = "flightscene", section = "Effects",
    label = "Cinematic flights",
    tip = "on a flight master's flight the screen turns to film: black bars, the HUD faded back, the camera drawn out wide and swinging slowly round you and your mount, with the flight bar in the top bar. The flight game, a window or a button steps out of it, and it bows out as you come in to land",
})

ns.RegisterSetting({
    key = "flightGame", kind = "boolean", default = true, command = "flightgame", section = "Quests, chat and map",
    label = "Flights: a game on the way",
    tip = "on a flight a small game is offered under the flight bar, and one button starts it (only that button is taken until you do): flap your mount over the treetops and past the zeppelins, and net the riders coming the other way, grounding them for flight gold. The same button again is high altitude: the game is put away and the buttons are the game's again. Never in a fight, gone on landing",
})

-- Each switch knows its module (Options gives it the line on memory, and greys it while the module's folder is
-- missing or the module is unticked in the game's AddOns list)
for _, def in ipairs(ns.settings) do
    local m = def.key and MO.bySwitch[def.key]
    if m then
        def.module = m
        def.available = function() return m.state ~= "missing" and m.state ~= "disabled" end
    end
end

---------------------------------------------------------------------------
-- Loading
---------------------------------------------------------------------------
local function GameCall(name, ...)
    local fn = (C_AddOns and C_AddOns[name]) or _G[name]
    if type(fn) ~= "function" then return false end
    return pcall(fn, ...)
end

function MO.IsLoaded(m)
    local ok, loaded = GameCall("IsAddOnLoaded", m.addon)
    return ok and loaded == true or false
end

-- Wanted: the HUD is on and one of its switches is, or a module that needs it is wanted
function MO.Wanted(m)
    local db = ns.db
    if not (db and db.enabled) then return false end
    for _, key in ipairs(m.switches) do
        if db[key] then return true end
    end
    for _, other in ipairs(MODULES) do
        for _, need in ipairs(other.needs or {}) do
            if need == m.addon and MO.Wanted(other) then return true end
        end
    end
    return false
end

local function Load(m)
    local ok, loaded, why = GameCall("LoadAddOn", m.addon)
    if not ok then return false, "error" end
    -- (unticked in the game's AddOns list, it is refused with DISABLED: that is your choice, and it is left so)
    return loaded and true or false, why
end

-- Every module that is wanted and not loaded yet, loaded now (the settings must have been read; never in a fight:
-- Core.lua calls this from ns.Apply, which waits for combat to end)
function ns.LoadWanted()
    if not ns.db then return end
    local fresh = false
    for _, m in ipairs(MODULES) do
        if MO.IsLoaded(m) then
            m.state = "loaded"
        elseif m.state ~= "missing" and m.state ~= "disabled" and MO.Wanted(m) then
            local loaded, why = Load(m)
            if loaded then
                m.state, fresh = "loaded", true
                ns.Note("module %s loaded", m.addon)
            else
                m.state = (why == "MISSING") and "missing" or (why == "DISABLED") and "disabled" or "refused"
                ns.Note("module %s not loaded: %s", m.addon, tostring(why))
            end
        end
    end
    for _, m in ipairs(MODULES) do                        -- (one loaded with another, as its dependency)
        if m.state ~= "loaded" and MO.IsLoaded(m) then m.state, fresh = "loaded", true end
    end
    if fresh and ns.OptionsAddNew then ns.OptionsAddNew() end
    return fresh
end

---------------------------------------------------------------------------
-- What a module that is not loaded says
---------------------------------------------------------------------------
local function SwitchOf(m)
    for _, def in ipairs(ns.settings) do
        if def.key == m.switches[1] then return def end
    end
end

-- "One-button fishing is off: /cchud fishmode on", or why it could not be loaded
function MO.Why(m)
    local def = SwitchOf(m)
    local label = def and L[def.label] or m.addon
    if m.state == "missing" then return L["%s is not installed: the folder %s is not in your AddOns folder."]:format(label, m.addon) end
    if m.state == "disabled" then return L["%s is turned off in the game's AddOns list: tick %s there to use it."]:format(label, m.addon) end
    if m.state == "refused" then return L["%s could not be loaded: the game refused it (%s)."]:format(label, m.addon) end
    if InCombatLockdown and InCombatLockdown() and MO.Wanted(m) then return L["Changes are applied when combat ends."] end
    return L["%s is off: /cchud %s on"]:format(label, def and def.command or "")
end

function MO.Off(m) ns.Say(MO.Why(m)) end

-- A command nobody has registered: the module's, when it belongs to one that is not loaded
function ns.ModuleForCommand(cmd)
    local m = MO.byCommand[cmd]
    if m and not MO.IsLoaded(m) then return m end
end

-- A switch's line on memory (for its tip in the options): freed at the next /reload, once nothing else keeps it
function MO.FreeNote(def)
    local m = def.module
    if not m then return nil end
    local others = {}
    local function add(key)
        if key == def.key then return end
        for _, d in ipairs(ns.settings) do
            if d.key == key and d.label then others[#others + 1] = L[d.label] end
        end
    end
    for _, key in ipairs(m.switches) do add(key) end
    for _, other in ipairs(MODULES) do
        for _, need in ipairs(other.needs or {}) do
            if need == m.addon then for _, key in ipairs(other.switches) do add(key) end end
        end
    end
    if #others == 0 then return L["Turning it off frees its memory at your next /reload."] end
    return L["Turning it off frees its memory at your next /reload, once these are off too: %s."]:format(table.concat(others, ", "))
end

-- The key bindings of a module that is not loaded: each says how to switch it on (the module's own takes the
-- name over as it loads)
for _, m in ipairs(MODULES) do
    for _, name in ipairs(m.bindings or {}) do
        if _G[name] == nil then
            _G[name] = function() ns.Protect(function() if not MO.IsLoaded(m) then MO.Off(m) end end)() end
        end
    end
end

-- The settings of the modules that are not loaded: key -> default (for /cchud export and import, and the presets)
function MO.UnloadedKeys()
    local out = {}
    for _, m in ipairs(MODULES) do
        if not MO.IsLoaded(m) then
            for key, default in pairs(m.keys or {}) do out[key] = default end
        end
    end
    return out
end

-- In the debug reports: each module's state
function MO.Describe()
    local out = {}
    for _, m in ipairs(MODULES) do
        out[#out + 1] = ("%s: %s%s"):format(m.addon, m.state, MO.Wanted(m) and "" or " (not wanted)")
    end
    return out
end
