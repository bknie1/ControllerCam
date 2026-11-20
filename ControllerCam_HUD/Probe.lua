-- ControllerCam HUD: probe.
-- /cchud probe looks at what this client's Gamepad UI is made of (frames, settings, available functions) and
-- keeps it in ControllerCamHUDDB.probe, which the game writes to disk on /reload or logout.

local ADDON, ns = ...

local function say(msg)
    ns.Say(msg)
    if UIErrorsFrame and UIErrorsFrame.AddMessage then pcall(UIErrorsFrame.AddMessage, UIErrorsFrame, msg, 0.4, 0.8, 1) end
end

local CVARS = {
    "InputDeviceInterfaceStyle", "InputDeviceInterfaceType", "GamePadEnable",
    "GamepadShowPersistentInputLegend", "GamepadHudModifierUsesToggle", "GamepadEnableReticleSwingTimer",
    "GamepadFocusStateColor", "GamepadFocusStateOpacity", "GamepadPreferScreenTargeting",
    "GamepadUsePartyTargeting", "GamepadRaidTargetingStyle", "GamepadTargetingModifierVisualDelay",
    "GamePadCursorOnLogin", "GamePadCursorAutoEnable", "GamePadCursorForTargeting",
    "nameplateShowEnemies", "nameplateShowFriends", "nameplateShowAll", "UnitNameOwn", "UnitNameEnemyPlayerName",
    "showTargetOfTarget", "showPartyBackground", "useCompactPartyFrames", "statusText", "statusTextDisplay",
}

local FUNCS = {
    "UnitCastingInfo", "UnitChannelInfo", "UnitAura", "UnitBuff", "UnitDebuff", "C_UnitAuras",
    "issecretvalue", "RegisterUnitWatch", "RegisterStateDriver", "GetClassColor", "C_ClassColor",
    "UnitClassification", "UnitIsTapDenied", "UnitHealthPercent", "UnitGetTotalAbsorbs", "UnitThreatSituation",
    "C_EditMode", "EditModeManagerFrame", "C_GamePad", "C_GamepadUI", "C_GamepadTargeting",
    "C_InputInterfaceStyle", "C_NamePlate", "C_AddOns", "GetBuildInfo", "Settings", "BackdropTemplateMixin",
    "PixelUtil", "C_Spell", "GetSpellInfo", "UnitPowerType", "UnitPartialPower", "GetComboPoints",
}

local NAME_PATTERNS = {
    "gamepad", "crossbar", "legend", "reticle", "compass", "^playerframe", "^targetframe", "^focusframe",
    "^petframe", "^party", "^compact", "nameplate", "^castingbar", "^playercastingbar", "^buffframe",
    "^debufframe", "^minimap", "^objectivetracker", "^quest.*tracker", "^mainmenubar", "^actionbar",
    "^multibar", "^stancebar", "^possessbar", "^extraaction", "^zoneability", "^uiwidget", "^alert",
    "^chatframe1$", "^micro", "^bags", "^improvedforever", "^status", "^durability", "^vehicle",
    "^worldmap", "^questmap", "^questlog", "^questframe", "^containerframe", "smartnav", "^gossip", "^merchant",
    "^lootframe", "^character", "^spellbook", "^talent", "^friends", "^mail",
    "meter", "^auction", "flyout", "radial", "cooldownviewer", "viewer$",
}
ns.PROBE_VERSION = 3          -- raised when what the probe looks for changes (the debug reports then run it again)

local BLIZZARD_ADDONS = {
    "Blizzard_GamepadActionBars", "Blizzard_GamepadUI", "Blizzard_GamePadUI", "Blizzard_GamepadHUD",
    "Blizzard_GamepadTargeting", "Blizzard_GamepadCompass", "Blizzard_GamepadLegend", "Blizzard_UnitFrame",
    "Blizzard_PartyFrame", "Blizzard_CompactRaidFrames", "Blizzard_NamePlates", "Blizzard_EditMode",
    "Blizzard_ActionBar", "Blizzard_ActionBarController", "Blizzard_CastingBar", "Blizzard_BuffFrame",
}

local function IsObject(v)
    if type(v) ~= "table" then return false end
    local ok, yes = pcall(function()
        return type(rawget(v, 0)) == "userdata" and type(v.GetObjectType) == "function"
    end)
    return ok and yes or false
end

local function Safe(fn, ...)
    local ok, a, b, c, d, e = pcall(fn, ...)
    if ok then return a, b, c, d, e end
end

local function Point(f)
    local p, rel, rp, x, y = Safe(f.GetPoint, f, 1)
    if not p then return nil end
    local relName = rel and Safe(rel.GetName, rel) or (rel and "?" or nil)
    return ("%s %s %s %.0f %.0f"):format(p, tostring(relName), tostring(rp), x or 0, y or 0)
end

local function Describe(f)
    local d = { type = Safe(function() return f:GetObjectType() end) }
    d.shown = Safe(f.IsShown, f) and true or false
    d.visible = Safe(f.IsVisible, f) and true or false
    d.protected = Safe(f.IsProtected, f) and true or false
    d.forbidden = Safe(f.IsForbidden, f) and true or false
    local parent = Safe(f.GetParent, f)
    d.parent = parent and (Safe(parent.GetName, parent) or "(unnamed)") or nil
    d.point = Point(f)
    local w, h = Safe(f.GetSize, f)
    if w then d.size = ("%.0fx%.0f"):format(w, h or 0) end
    d.scale = Safe(f.GetScale, f)
    d.alpha = Safe(f.GetAlpha, f)
    d.strata = Safe(f.GetFrameStrata, f)
    d.unit = Safe(f.GetAttribute, f, "unit")
    -- named child fields (parentKey) one level down
    local keys = {}
    for k, v in pairs(f) do
        if type(k) == "string" and IsObject(v) then
            keys[#keys + 1] = k .. "=" .. tostring(Safe(function() return v:GetObjectType() end))
        end
    end
    table.sort(keys)
    if #keys > 0 then d.fields = table.concat(keys, ", ") end
    -- mixin functions, which name what the frame can do
    local funcs = {}
    for k, v in pairs(f) do
        if type(k) == "string" and type(v) == "function" then funcs[#funcs + 1] = k end
    end
    table.sort(funcs)
    if #funcs > 0 then d.methods = table.concat(funcs, ", ") end
    return d
end

local function Matches(name)
    local lower = name:lower()
    for _, p in ipairs(NAME_PATTERNS) do
        if lower:find(p) then return true end
    end
end

function ns.RunProbe(quiet)
    local out = { when = date and date("%Y-%m-%d %H:%M:%S") or tostring(time()), errors = {}, v = ns.PROBE_VERSION }
    ControllerCamHUDDB = ControllerCamHUDDB or {}
    ControllerCamHUDDB.probe = out            -- kept even if a section below fails
    local count = 0

    local function section(name, fn)
        local ok, err = pcall(fn)
        if not ok then out.errors[#out.errors + 1] = name .. ": " .. tostring(err) end
    end

    section("build", function()
        local v, b, d, i = GetBuildInfo()
        out.build = ("%s %s %s %s"):format(tostring(v), tostring(b), tostring(d), tostring(i))
        out.locale = GetLocale()
        out.combat = InCombatLockdown() and true or false
        out.interfaceStyle = C_InputInterfaceStyle.GetCurrentStyle()
    end)

    section("cvars", function()
        out.cvars = {}
        for _, name in ipairs(CVARS) do
            local v = Safe(GetCVar, name)
            out.cvars[name] = v == nil and "(none)" or tostring(v)
        end
    end)

    section("allCvars", function()
        local found = {}
        for _, c in ipairs(C_Console.GetAllCommands()) do
            local n = c.command or ""
            local l = n:lower()
            if l:find("gamepad") or l:find("hud") or l:find("legend") or l:find("crossbar") or l:find("nameplate") then
                found[#found + 1] = n .. "=" .. tostring(Safe(GetCVar, n))
            end
        end
        table.sort(found)
        out.allCvars = found
    end)

    section("funcs", function()
        out.funcs = {}
        for _, name in ipairs(FUNCS) do out.funcs[name] = type(_G[name]) end
    end)

    section("addons", function()
        out.addons = {}
        local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
        for _, name in ipairs(BLIZZARD_ADDONS) do
            out.addons[name] = Safe(loaded, name) and true or false
        end
    end)

    section("frames", function()
        out.frames = {}
        local names = {}
        for name, v in pairs(_G) do
            if type(name) == "string" and IsObject(v) and Matches(name) then names[#names + 1] = name end
        end
        table.sort(names)
        for _, name in ipairs(names) do
            local ok, d = pcall(Describe, _G[name])
            out.frames[name] = ok and d or { error = tostring(d) }
            count = count + 1
        end
    end)

    section("apis", function()
        out.apis = {}
        for _, name in ipairs({ "C_GamePad", "C_GamepadUI", "C_GamepadTargeting", "C_InputInterfaceStyle",
                                "C_NamePlate", "C_EditMode", "C_QuestLog", "C_Map", "C_Container", "C_UnitAuras",
                                "C_SmartNavigation", "C_PartyInfo", "C_Minimap" }) do
            local t = _G[name]
            if type(t) == "table" then
                local names = {}
                for k, v in pairs(t) do
                    if type(k) == "string" and type(v) == "function" then names[#names + 1] = k end
                end
                table.sort(names)
                out.apis[name] = table.concat(names, " ")
            else
                out.apis[name] = "(none)"
            end
        end
    end)

    section("secure", function()
        local btn = CreateFrame("Button", nil, UIParent, "SecureUnitButtonTemplate")
        out.secureUnitButton = btn and true or false
        if btn then btn:Hide() end
    end)

    if quiet then return count end
    if #out.errors > 0 then say("probe had problems: " .. table.concat(out.errors, " | ")) end
    say(("probe saved: %d frames. Type /reload so the game writes it to disk."):format(count))
    return count
end
