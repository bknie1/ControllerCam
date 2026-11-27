-- ControllerCam HUD: presets.
--   * HUD presets: a whole set of our settings in one go. Some also place every frame (pos: where each goes,
--     from the centre of the screen; an empty table puts them back where they start); the rest keep yours.
--   * The game's own layouts: our frames go back where they start, and you are pointed at the game's
--     built-in Modern or Classic layout in Edit Mode. Choosing a layout there is yours to do: the game
--     refuses it to addons.
--   * The screen made for the HUD: a layout of ours added to the game's Edit Mode (SCREEN, below).

local ADDON, ns = ...
local L = ns.L

local P = {}
ns.Presets = P

-- What every preset keeps on, whatever its style: what you need to stay alive and play together. A preset
-- may move these or make them quieter, never take them away.
P.CRITICAL = {
    nameplates = true, castbar = true, group = true, auras = true, targetThreat = true, numbers = true,
    plateThreat = true, plateDebuffs = true, plateCC = true, plateCastAlert = true, plateTargetName = true,
    plateLevels = true,
}

ns.RegisterSetting({
    key = "presetZoom", kind = "boolean", default = true, command = "presetzoom", section = "General",
    label = "Presets set the camera distance",
    tip = "a preset also brings the camera to the distance its layout was made for, once (zoom freely afterwards)",
})

-- What each preset sets. Settings it does not mention keep their value; the bar style (compact or full) is
-- always yours, whatever the preset, and so are class icons. zoom: the camera distance its layout
-- was made for (set once when it is chosen).
P.HUD = {
    { key = "action", label = "Action", zoom = 12,
      tip = "a third-person view: slim vertical bars beside your character, every effect on; out of combat things fade",
      units = { vertical = true, player = true, pet = true, focus = true, target = true },
      set = { group = true, castbar = true, nameplates = true, impacts = true, impactFx = true, castWindup = true,
              combatColors = true, chatFade = true, bars = true, textShade = true,
              plateDebuffs = true, plateQuest = true, plateThreat = true, plateMotion = true, verticalIdle = 0.3,
              idle = 0.3, hudFade = true, hudIdle = 0.3, combatAlpha = 0.7, alertHealth = 0.5,
              plateTargetName = true, plateHoverNPC = false } },
    { key = "classic", label = "Classic", zoom = 15,
      tip = "our frames where WoW has always had them, calmer effects, the game's gamepad bars as they are",
      pos = {},
      units = { vertical = false, player = true, pet = true, focus = true, target = true },
      set = { group = true, castbar = true, nameplates = true, impacts = true, impactFx = false, castWindup = false,
              combatColors = false, chatFade = false, bars = false, textShade = true,
              plateDebuffs = true, plateQuest = true, plateThreat = true, plateMotion = false, idle = 1,
              combatAlpha = 1, hudFade = false, plateHoverNPC = false } },
    { key = "minimal", label = "Minimal",
      tip = "only what you need: friendly NPCs show their plate (with what they do) only while you point at them, aim at them or target them; names without titles; out of combat your bars rest as a faint hint (low health always shows)",
      units = { vertical = true, player = true, pet = true, focus = true, target = true },
      set = { group = true, castbar = true, nameplates = true, impacts = true, impactFx = true, castWindup = true,
              combatColors = true, chatFade = true, bars = true, textShade = false,
              plateSubtitles = true, platePower = false, plateTitles = false, plateDebuffs = true,
              plateQuest = true, plateThreat = true, plateMotion = true, verticalIdle = 0.15, idle = 0.15,
              hudFade = true, hudIdle = 0.15, combatAlpha = 0.6, alertHealth = 0.5, plateTargetName = true,
              plateLevels = true, plateHoverNPC = true } },

    -- whole-screen layouts after other games
    { key = "openworld", label = "Open world", zoom = 15,
      tip = "a clean screen for exploring: slim bars beside you that rest faded, plates without power bars, chat that fades",
      pos = { vertical = { x = -280, y = -20 } },
      units = { vertical = true, player = true, pet = false, focus = false, target = true },
      set = { group = true, castbar = true, nameplates = true, impacts = true, impactFx = true, castWindup = true,
              combatColors = true, chatFade = true, chatTime = 10, bars = true, textShade = false,
              plateSubtitles = true, platePower = false, plateTitles = true, plateTargetName = true,
              plateDebuffs = true, plateQuest = true, plateThreat = true, plateMotion = true, verticalIdle = 0.15,
              plateHoverNPC = false } },
    { key = "adventure", label = "Adventure", zoom = 12,
      tip = "after console open-world adventures: vitals beside you, a small target high in the middle, townsfolk only when you point at them, chat that fades fast",
      pos = { vertical = { x = -280, y = -30 }, target = { x = 0, y = 390 } },
      units = { vertical = true, player = false, pet = true, focus = false, target = true },
      set = { group = true, castbar = true, nameplates = true, impacts = true, impactFx = true, castWindup = true,
              combatColors = true, chatFade = true, chatTime = 6, bars = true, textShade = false,
              plateSubtitles = true, platePower = false, plateTitles = true,
              plateDebuffs = true, plateQuest = true, plateThreat = true, plateMotion = true, verticalIdle = 0.15,
              hudFade = true, hudIdle = 0.15, plateHoverNPC = true } },
    { key = "soulslike", label = "Soulslike", zoom = 8,
      tip = "your bars top left, a big target bar low in the middle like a boss bar, every hit felt",
      pos = { target = { x = 0, y = -150 }, player = { x = -700, y = 470 } },
      units = { vertical = false, player = true, pet = true, focus = false, target = true },
      set = { group = true, castbar = true, nameplates = true, impacts = true, impactFx = true, castWindup = true,
              combatColors = false, chatFade = true, bars = true, textShade = true,
              plateSubtitles = false, platePower = false, plateTitles = false, plateLevels = true, plateTargetName = true,
              plateDebuffs = true, plateQuest = true, plateThreat = true, plateMotion = true, idle = 0.3,
              plateHoverNPC = false } },
    { key = "shooter", label = "Shooter", zoom = 6,
      tip = "upright bars just right of centre, close to where you aim, the target high above, strong hit feedback",
      pos = { vertical = { x = 120, y = -40 }, target = { x = 0, y = 400 } },
      units = { vertical = true, player = true, pet = false, focus = true, target = true },
      set = { group = true, castbar = true, nameplates = true, impacts = true, impactFx = true, castWindup = true,
              combatColors = true, chatFade = true, bars = true, textShade = true,
              plateSubtitles = false, platePower = false, plateTitles = false, plateLevels = true, plateTargetName = true,
              plateDebuffs = true, plateQuest = true, plateThreat = true, plateMotion = true, verticalIdle = 0.3,
              plateHoverNPC = false } },
    { key = "crossbar", label = "Crossbar", zoom = 18,
      tip = "after MMOs played on a controller: the target and focus high in the middle, your bars just above the gamepad bars, party on the left, full plates",
      pos = { target = { x = 0, y = 380 }, focus = { x = 330, y = 380 }, player = { x = 0, y = -160 } },
      units = { vertical = false, player = true, pet = true, focus = true, target = true },
      set = { group = true, castbar = true, nameplates = true, impacts = true, impactFx = false, castWindup = true,
              combatColors = true, chatFade = false, bars = false, textShade = true,
              plateSubtitles = true, platePower = true, platePercent = true, plateLevels = true,
              plateTargetName = true, plateDebuffs = true, plateQuest = true, plateThreat = true,
              plateMotion = true, idle = 1, plateHoverNPC = false } },
    { key = "arpg", label = "ARPG", zoom = 28,
      tip = "after action RPGs: the camera far back, your vitals low on the left, the target high in the middle, minor enemies small, every hit loud",
      pos = { player = { x = -430, y = -330 }, target = { x = 0, y = 400 } },
      units = { vertical = false, player = true, pet = true, focus = false, target = true },
      set = { group = true, castbar = true, nameplates = true, impacts = true, impactFx = true, castWindup = true,
              combatColors = true, chatFade = true, bars = true, textShade = true,
              plateMini = true, plateSubtitles = false, platePower = false, plateTitles = false,
              plateTargetName = true, plateDebuffs = true, plateQuest = true, plateThreat = true,
              plateMotion = true, plateCastAlert = true, idle = 0.3, plateHoverNPC = false } },
    { key = "compass", label = "Compass", zoom = 6,
      tip = "after first-person RPGs: the camera close, your bars low in the middle, the target under the top edge, townsfolk only when you point at them",
      pos = { player = { x = 0, y = -170 }, target = { x = 0, y = 400 } },
      units = { vertical = false, player = true, pet = false, focus = false, target = true },
      set = { group = true, castbar = true, nameplates = true, impacts = true, impactFx = true, castWindup = true,
              combatColors = true, chatFade = true, bars = true, textShade = false,
              plateSubtitles = true, platePower = false, plateTitles = true,
              plateTargetName = true, plateDebuffs = true, plateQuest = true, plateThreat = true,
              plateMotion = true, idle = 0.3, plateHoverNPC = true } },
    { key = "raid", label = "Raid", zoom = 20,
      tip = "WoW's own placement with everything a group needs: party and raid frames, health percents and levels on plates",
      pos = {},
      units = { vertical = false, player = true, pet = true, focus = true, target = true },
      set = { group = true, castbar = true, nameplates = true, impacts = true, impactFx = false, castWindup = true,
              combatColors = true, chatFade = false, bars = false, textShade = true,
              plateSubtitles = true, platePower = true, platePercent = true, plateLevels = true,
              plateTargetName = true, plateDebuffs = true, plateQuest = false, plateThreat = true,
              plateMotion = true, idle = 1, plateHoverNPC = false } },
}

-- ControllerCam's presets: picking one there (for everywhere) picks the HUD preset made for the same play
ns.RegisterSetting({
    key = "followCamera", kind = "boolean", default = true, command = "followcamera", section = "General",
    label = "Follow ControllerCam's presets",
    tip = "choosing a camera preset in ControllerCam for everywhere also chooses the matching HUD preset (the camera keeps its own distance)",
})
P.FROM_CAMERA = { action = "action", hybrid = "openworld", classic = "classic", shooter = "shooter",
                  tactical = "arpg", cinematic = "adventure", targetlock = "soulslike", raid = "raid",
                  cruise = "openworld", skies = "openworld", stroll = "minimal" }

ControllerCamHUD = ControllerCamHUD or {}
function ControllerCamHUD.CameraPreset(id)
    if not (ns.db and ns.db.followCamera) then return false end
    local key = P.FROM_CAMERA[id]
    if not key or not P:Apply(key, true) then return false end
    ns.Say(L["HUD preset: %s, to match the camera"]:format(L[P:Find(key).label]))
    return true
end

-- The camera to a preset's distance, once (the camera addon's situations may change it later, as usual)
function P.Zoom(distance)
    if not (distance and ns.db.presetZoom and GetCameraZoom and CameraZoomIn and CameraZoomOut) then return false end
    local ok, cur = pcall(GetCameraZoom)
    if not ok or type(cur) ~= "number" or ns.IsSecret(cur) then return false end
    local diff = distance - cur
    if math.abs(diff) < 0.2 then return true end
    if diff > 0 then CameraZoomOut(diff) else CameraZoomIn(-diff) end
    return true
end

-- The default of a setting (as registered, or the HUD's own defaults)
local function DefaultOf(key)
    for _, def in ipairs(ns.settings) do
        if def.key == key then return def.default end
    end
    local unloaded = ns.ModuleList and ns.ModuleList.UnloadedKeys() or {}      -- a module that is not loaded
    if unloaded[key] ~= nil then return unloaded[key] end
    return ns.DEFAULTS[key]
end

-- Every setting any preset sets: a preset first puts all of them back to their defaults, so what one preset
-- changed never lingers into the next
function P.Keys()
    if P.keys then return P.keys end
    local seen = {}
    for _, preset in ipairs(P.HUD) do
        for name in pairs(preset.set) do seen[name] = true end
    end
    P.keys = seen
    return seen
end

function P:Find(key)
    for _, preset in ipairs(self.HUD) do
        if preset.key == key then return preset end
    end
end

function P:Apply(key, keepCamera)
    local preset = self:Find(key)
    if not preset then return false end
    local db = ns.db
    for unit, on in pairs(preset.units) do db.units[unit] = on end
    for name in pairs(P.Keys()) do
        local default = DefaultOf(name)
        if default ~= nil then db[name] = default end
    end
    for name, value in pairs(preset.set) do db[name] = value end
    for name, value in pairs(P.CRITICAL) do db[name] = value end       -- never taken away by a preset
    db.units.target = true
    if not (db.units.player or db.units.vertical) then db.units.player = true end
    if preset.pos then
        db.pos = {}
        for frame, p in pairs(preset.pos) do db.pos[frame] = { x = p.x, y = p.y } end
    end
    if keepCamera then
        if preset.zoom then db.followRef = preset.zoom end              -- the camera addon sets the distance
    elseif preset.zoom and P.Zoom(preset.zoom) then
        db.followRef = preset.zoom                                       -- its layout fits this distance
    end
    db.preset = key
    ns.Apply()
    if ns.UnitFrames then ns.UnitFrames:ApplyLook() end
    if ns.RefreshOptions then ns.RefreshOptions() end
    return true
end

---------------------------------------------------------------------------
-- The game's own layouts (Edit Mode): Modern and Classic
---------------------------------------------------------------------------
P.GAME = { { key = "modern", label = "Modern" }, { key = "classic", label = "Classic" } }

-- The index the game's Edit Mode uses for its built-in layout (the built-in ones come first)
function P.GameLayoutIndex(key)
    local presets = Enum and Enum.EditModePresetLayouts
    local value = presets and presets[key == "modern" and "Modern" or "Classic"]
    if type(value) == "number" then return value + 1 end
    return key == "modern" and 1 or 2
end

function P:GameLayout(key)
    if InCombatLockdown() then return false, L["Not in combat."] end
    ns.db.pos = {}                                   -- our frames back where they start
    ns.Apply()
    return true
end

-- How far away you sit: text for a TV across the room, or for a monitor at arm's length. Sets the sizes
-- that are settings of their own (the HUD's text, the chat windows' text, the cast bar); each can be tuned
-- afterwards.
P.SIZES = {
    tv = { textScale = 1.5, chatSize = 20, castScale = 1.35 },
    monitor = { textScale = 1, chatSize = 0, castScale = 1 },                -- (chat: the game's own size)
}
function P:SizeFor(key)
    local sizes = self.SIZES[key]
    if not sizes then return false end
    for name, value in pairs(sizes) do ns.db[name] = value end
    ns.db.sizedFor = key
    ns.Apply()
    if ns.UnitFrames and ns.UnitFrames.ApplyLook then ns.UnitFrames:ApplyLook() end
    if ns.RefreshOptions then ns.RefreshOptions() end
    return true
end

-- The screen layout is in the game's list (added now if it was not): for whoever picks a preset while still on
-- one of the game's built-in layouts. A layout of that name is never overwritten here: it may have been
-- arranged since (only a reset puts ours back). Returns its name when it was added just now.
function P:EnsureScreen()
    local S = ns.Share
    local layout = S and S.Layout()
    if not (layout and layout.builtin) or InCombatLockdown() or S.HasLayout(self.SCREEN.name) then return nil end
    local ok, name = self:Screen()
    return ok and name or nil
end

-- Everything of ours back to how it starts: every setting, which frames show, where they sit, and the
-- screen layout as we made it. What you collected is kept (vendor marks, price history, what was answered).
function P:ResetAll()
    local db = ns.db
    for _, def in ipairs(ns.settings) do
        if def.key and def.default ~= nil and def.share ~= false then db[def.key] = def.default end
    end
    for key, default in pairs(ns.ModuleList and ns.ModuleList.UnloadedKeys() or {}) do db[key] = default end
    for unit, on in pairs(ns.DEFAULTS.units) do db.units[unit] = on end
    db.pos, db.preset, db.followRef, db.sizedFor = {}, nil, nil, nil
    ns.Apply()
    if ns.UnitFrames and ns.UnitFrames.ApplyLook then ns.UnitFrames:ApplyLook() end
    if ns.RefreshOptions then ns.RefreshOptions() end
    if InCombatLockdown() then return nil end
    local ok, name = self:Screen()                   -- ours again, whatever was arranged in it
    return ok and name or nil
end

-- The screen made for the HUD: a layout of the game's own Edit Mode, added beside yours under this name, for
-- you to choose there. It puts the game's cooldown rows under the target, clear of the gamepad buttons; the
-- gamepad bars stay where the game puts them. The text is the game's own share text of that layout.
P.SCREEN = {
    name = "CCHUD",
    text = "1 52 0 10 1 7 7 UIParent 0.0 -4.0 -1 ##$$&('% 0 11 1 7 7 UIParent 0.0 -4.0 -1 ##$$&('%,# 0 12 1 7 7 UIParent 0.0 -4.0 -1 ##$$&('% 1 -1 1 7 1 GamepadMainActionBarFrame 0.0 20.0 -1 ##$#%# 2 -1 1 2 2 UIParent 0.0 0.0 -1 ##$#%(&( 3 0 1 8 7 UIParent -185.0 295.0 -1 $#3# 3 1 1 6 7 UIParent 185.0 295.0 -1 %$3# 3 2 1 6 7 UIParent 386.0 316.0 -1 %#&#3# 3 3 1 0 2 CompactRaidFrameManager 30.0 -170.0 -1 '#(#)#-#.#/#1$3#5#6(7-7$8(9( 3 4 1 0 2 CompactRaidFrameManager 30.0 -150.0 -1 ,#-#.#/#0#1#2(3#5#6(7-7$8(9( 3 5 1 5 5 UIParent 0.0 0.0 -1 &#*$3# 3 6 1 5 5 UIParent 0.0 0.0 -1 -#.#/#4$5#6(7-7$8(9( 3 7 1 4 4 UIParent 0.0 0.0 -1 3# 4 -1 1 7 7 UIParent 0.0 -4.0 -1 # 5 -1 1 7 7 UIParent 0.0 -4.0 -1 # 6 0 1 2 2 UIParent -255.0 -10.0 -1 ##$#%#&.(()( 6 1 1 2 2 UIParent -270.0 -155.0 -1 ##$#%#'+(()(-$ 6 2 1 1 1 UIParent 0.0 -25.0 -1 ##$#%$&.(()(+#,-,$ 7 -1 1 7 7 UIParent 0.0 -4.0 -1 # 8 -1 1 6 6 UIParent 55.0 90.0 -1 #'$A%$&7 9 -1 1 7 7 UIParent 0.0 -4.0 -1 # 10 -1 1 0 0 UIParent 16.0 -116.0 -1 # 11 -1 1 8 8 UIParent -9.0 9.0 -1 # 12 -1 1 2 2 UIParent -110.0 -275.0 -1 #K$#%# 13 -1 1 7 7 UIParent 116.5 6.0 -1 ##$#%) 14 -1 1 6 8 MicroMenuContainer 7.0 -4.0 -1 ##$#%( 15 0 1 7 7 StatusTrackingBarManager 0.0 0.0 -1 &- 15 1 1 7 7 StatusTrackingBarManager 0.0 17.0 -1 &- 16 -1 1 5 5 UIParent 0.0 0.0 -1 #( 17 -1 1 1 1 UIParent 0.0 -100.0 -1 ## 18 -1 1 5 5 UIParent 0.0 0.0 -1 #- 19 -1 1 7 7 UIParent 0.0 0.0 -1 ## 20 0 0 7 7 UIParent 0.0 634.0 -1 ##$/%$&#'%(-($)#+$,$-$ 20 1 0 0 6 EssentialCooldownViewer 0.0 -4.0 -1 ##$*%$&%'%(-($)#+$,$-$ 20 2 0 6 0 EssentialCooldownViewer 0.0 4.0 -1 ##$$%$&#'((-($)#+$,$-$ 20 3 1 7 7 UIParent 420.0 430.0 -1 #$$$%#&('((-($)#*#+$,$-$.-.$ 21 -1 1 7 7 UIParent -410.0 380.0 -1 ##%#&#'((()#*-*$+#,&-#.#/(0#1# 22 0 1 8 7 UIParent -457.0 336.0 -1 #$$$%#&('((#)U*$+%,$-#.#/U0% 22 1 1 1 1 UIParent 0.0 -40.0 -1 &('()U*#+% 22 2 1 1 1 UIParent 0.0 -90.0 -1 &('()U*#+% 22 3 1 1 1 UIParent 0.0 -130.0 -1 &('()U*#+% 23 -1 1 0 0 UIParent 0.0 0.0 -1 ##$#%$&7&%'7(%)U+$,$-$.(/U 24 -1 1 1 1 UIParent 0.0 -182.0 -1 # 25 -1 1 5 7 UIParent -28.0 128.0 -1 # 26 0 0 0 0 UIParent -26.0 5.0 -1 ## 26 1 1 3 5 BagsBar -30.0 5.0 -1 ## 27 -1 1 4 4 Minimap -68.0 -68.0 -1 #- 28 -1 1 4 4 UIParent 0.0 0.0 -1 #( 29 0 1 7 7 UIParent 0.0 450.0 -1 #($U%#&A&$')($)$ 29 1 1 7 7 UIParent 0.0 425.0 -1 #($U%#&A&$')($)$ 29 2 1 7 7 UIParent 0.0 400.0 -1 #($U%#&A&$')($)$ 30 -1 0 7 7 UIParent 0.0 34.0 -1 #$$$%#&$'$",
}

function P:Screen()
    if not (ns.Share and ns.Share.SetLayout) then return false end
    return ns.Share.SetLayout(self.SCREEN.name, self.SCREEN.text)
end

ns.RegisterCommand("preset", function(arg)
    if arg == "" then
        local names = {}
        for _, p in ipairs(P.HUD) do names[#names + 1] = p.key end
        ns.Say(L["usage:"] .. " /cchud preset " .. table.concat(names, " | "))
        return
    end
    if P:Apply(arg) then
        ns.Say(L["preset: %s"]:format(L[P:Find(arg).label]))
        if ns.IsPending() then ns.Say(L["Changes are applied when combat ends."]) end
        local added = P:EnsureScreen()               -- the game's side of the screen, for you to choose
        if added then
            ns.Say(L["A layout named '%s' was added to the game's Edit Mode. Choose it there to use it (Game Menu > Edit Mode > Layout)."]:format(added))
        end
    else
        ns.Say(L["unknown preset '%s'"]:format(arg))
    end
end, "/cchud preset <name>", "set the whole HUD to a preset: action, classic, minimal, openworld, adventure, soulslike, shooter, crossbar, arpg, compass, raid")

-- The bar style, quickly: /cchud compactall, /cchud targetcompact (nameplates: /cchud platecompact)
local function Style(set, arg)
    local on = (arg == "on") or (arg ~= "off" and nil)
    if on == nil then ns.Say(L["usage:"] .. " on | off"); return end
    set(on)
    if ns.UnitFrames then ns.UnitFrames:ApplyLook() end
    ns.Apply()
    if ns.RefreshOptions then ns.RefreshOptions() end
end
ns.RegisterCommand("compactall", function(arg)
    Style(function(v) ns.db.targetCompact, ns.db.plateCompact = v, v end, arg)
end, "/cchud compactall on | off", "the target frame and nameplates compact or full, both at once")
ns.RegisterCommand("targetcompact", function(arg)
    Style(function(v) ns.db.targetCompact = v end, arg)
end, "/cchud targetcompact on | off", "the target frame compact or full")

ns.RegisterCommand("sizefor", function(arg)
    if not P:SizeFor(arg) then ns.Say(L["usage:"] .. " /cchud sizefor tv | monitor"); return end
    ns.Say(arg == "tv" and L["Sized for a TV: bigger text on the HUD and in chat."]
        or L["Sized for a monitor: text at its plain size."])
    if ns.IsPending() then ns.Say(L["Changes are applied when combat ends."]) end
end, "/cchud sizefor tv | monitor", "size the text for a TV across the room, or for a monitor at arm's length")

ns.RegisterCommand("layout", function(arg)
    if arg ~= "modern" and arg ~= "classic" then
        ns.Say(L["usage:"] .. " /cchud layout modern | classic")
        return
    end
    local ok, why = P:GameLayout(arg)
    if ok then
        ns.Say(L["Our frames are back where they start. Choose the game's %s layout in Edit Mode (Game Menu > Edit Mode > Layout)."]:format(
            L[arg == "modern" and "Modern" or "Classic"]))
    else
        ns.Say(why)
    end
end, "/cchud layout modern | classic", "put our frames back where they start, for the game's own Modern or Classic layout")
