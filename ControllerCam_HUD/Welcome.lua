-- ControllerCam HUD: the first run.
-- The HUD comes in the same download as ControllerCam, and not everyone who wants the camera wants a new
-- interface. So the first time it loads beside ControllerCam it rests (switched off, the game untouched) and
-- asks: the camera with the HUD, or the camera alone. Installed on its own, or with settings from before,
-- it does not ask. Switching the HUD on or off yourself answers the question just the same.
-- /cchud welcome asks again.
--
-- A second question follows a yes, and comes once to anyone using the HUD on one of the game's built-in
-- layouts: shall the screen be set up for it (Presets.SCREEN, a layout added to the game's Edit Mode)?
-- Someone who arranged a layout of their own is not asked. /cchud setup asks again.

local ADDON, ns = ...
local L = ns.L

local W = {}
ns.Welcome = W

W.DELAY = 3          -- seconds after login, so the question is not lost among the loading screen's last moments

function W.CameraLoaded()
    local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    if type(loaded) ~= "function" then return false end
    local ok, yes = pcall(loaded, "ControllerCam")
    if ok and (yes == true or yes == 1) then return true end
    return type(_G.ControllerCam) == "table" and type(_G.ControllerCam.ExportSetup) == "function"
end

function W.Answer(hud)
    local db = ns.db
    db.asked, db.enabled = true, hud and true or false
    ns.Apply()
    if ns.RefreshOptions then ns.RefreshOptions() end
    if hud then
        ns.Say(L["The HUD is on while the Gamepad UI is in use. Its options: Options > AddOns > ControllerCam > HUD, or /cchud."])
        if ns.IsPending() then ns.Say(L["Changes are applied when combat ends."]) end
        W.Later(0.5, function() if W.CanOfferScreen() then W.AskScreen() end end)
    else
        ns.Say(L["Camera only: the HUD rests and the game's interface is as it was. /cchud on switches it on."])
    end
end

function W.Later(seconds, fn)
    if C_Timer and C_Timer.After then C_Timer.After(seconds, ns.Protect(fn)) end
end

-- Is the screen question due? Only with the HUD on, only once, and only on a built-in layout of the game.
function W.CanOfferScreen()
    local db = ns.db
    if not (db and db.enabled and db.asked ~= false) or db.screenAsked then return false end
    local layout = ns.Share and ns.Share.Layout()
    return layout ~= nil and layout.builtin ~= nil
end

function W.Screen(yes)
    local db = ns.db
    if not yes then db.screenAsked = true; return end
    if InCombatLockdown() then ns.Say(L["Not in combat."]); return end       -- it asks again next time
    db.screenAsked = true
    local ok, name, switched = ns.Presets:Screen()
    if ok and switched then
        ns.Say(L["The game's layout is now '%s'."]:format(name))
    elseif ok then
        ns.Say(L["A layout named '%s' was added to the game's Edit Mode. Choose it there to use it (Game Menu > Edit Mode > Layout)."]:format(name))
    else
        ns.Say(L["The game's layout was left as it is."])
    end
end

local function Define()
    if W.defined or not StaticPopupDialogs then return end
    W.defined = true
    StaticPopupDialogs["CCHUD_SCREEN"] = {
        text = L["Set up the screen for the controller too? This adds a layout named CCHUD to the game's Edit Mode, for you to choose there: it puts the cooldown rows under the target, clear of the gamepad buttons. Your own layouts are kept (/cchud setup offers this again)."],
        button1 = L["Set it up"], button2 = L["Not now"],
        OnAccept = function() W.Screen(true) end,
        OnCancel = function(_, _, reason)
            if reason ~= "timeout" and reason ~= "override" then W.Screen(false) end
        end,
        timeout = 0, whileDead = true, hideOnEscape = false,
    }
    StaticPopupDialogs["CCHUD_WELCOME"] = {
        text = L["ControllerCam comes with a controller interface, the HUD: its own unit frames, nameplates, cast bar and more while the Gamepad UI is in use. Do you want it, or the camera alone?"],
        button1 = L["Camera + HUD"], button2 = L["Camera only"],
        OnAccept = function() W.Answer(true) end,
        -- closed by the game (another dialog took its place, say) is not an answer: it asks again next time
        OnCancel = function(_, _, reason)
            if reason ~= "timeout" and reason ~= "override" then W.Answer(false) end
        end,
        timeout = 0, whileDead = true, hideOnEscape = false,
    }
end

function W.Ask()
    Define()
    if not (W.defined and StaticPopup_Show) then return false end
    StaticPopup_Show("CCHUD_WELCOME")
    return true
end

function W.AskScreen()
    Define()
    if not (W.defined and StaticPopup_Show) then return false end
    StaticPopup_Show("CCHUD_SCREEN")
    return true
end

-- At login, before anything is applied (Core.lua)
function W.Login()
    local db = ns.db
    if not db then return end
    if db.asked == false then
        if db.enabled then                       -- you switched it on yourself since: that was the answer
            db.asked = true
        elseif not W.CameraLoaded() then         -- installed on its own: it is wanted
            db.asked, db.enabled = true, true
        else
            W.Later(W.DELAY, function() if ns.db.asked == false then W.Ask() end end)
            return
        end
    end
    W.Later(W.DELAY, function()
        if not InCombatLockdown() and W.CanOfferScreen() then W.AskScreen() end
    end)
end

ns.RegisterCommand("welcome", function() W.Ask() end, "/cchud welcome",
    "ask again: the camera with the HUD, or the camera alone")
ns.RegisterCommand("setup", function()
    if ns.db.asked == false then W.Ask(); return end
    local layout = ns.Share and ns.Share.Layout()
    if not layout then ns.Say(L["This client does not let addons change the layout."]); return end
    ns.db.screenAsked = false
    W.AskScreen()
end, "/cchud setup", "offer the screen layout made for the HUD again (the game's Edit Mode)")
