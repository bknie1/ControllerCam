-- ControllerCam HUD: /cchud commands.

local ADDON, ns = ...
local L = ns.L
local say = ns.Say

local onoff = ns.OnOff

local HELP = {
    { "/cchud",                       "show status" },
    { "/cchud on | off",              "turn the HUD on or off (off brings the game's own frames back)" },
    { "/cchud always on | off",       "also use the HUD in the mouse & keyboard UI" },
    { "/cchud player | target | pet | focus on | off", "use our frame for it, or the game's own" },
    { "/cchud vertical on | off",     "slim upright health and power bars beside your character" },
    { "/cchud tot on | off",          "target of target (the game's own option, also in its menus)" },
    { "/cchud cooldowns on | off",    "the game's Cooldown Manager (the game's own option)" },
    { "/cchud resource on | off",     "your health and power under your character (the game's own option)" },
    { "/cchud auratooltip on | off",  "the tooltip that pops up when a buff starts (the game's own option)" },
    { "/cchud blizzard on | off",     "keep the game's own player and target frames visible (on) or put them aside (off)" },
    { "/cchud chat on | off",         "move the chat window to the top left while the HUD runs" },
    { "/cchud classcolor on | off",   "colour your bar, and other players' bars, by class" },
    { "/cchud vendor on | off",       "the vendor's Sell junk button asks what to sell; quick move at vendor and bank" },
    { "/cchud sell",                  "at a vendor: choose what to sell (also: sell junk, sell recommended, sell white | green | blue)" },
    { "/cchud autosell on | off",     "sell junk by your rules as soon as a vendor opens" },
    { "/cchud sellgear on | off",     "count white weapons and armor as junk" },
    { "/cchud junk | keep | bank <item>", "mark an item: always sold, never sold, or for the bank (shift-click it into the chat line)" },
    { "/cchud deposit",               "at the bank: deposit what the bank already holds, and every item marked for it" },
    { "/cchud withdraw",              "at the bank: take out what you already carry some of" },
    { "/cchud autodeposit on | off",  "deposit as soon as the bank opens" },
    { "/cchud reagents on | off",     "the bank takes reagents by itself (the game's own option)" },
    { "/cchud shade on | off",        "a soft dark band behind the target's text, to keep it readable" },
    { "/cchud text <80-250>",         "text size, in percent (150 reads well on a TV)" },
    { "/cchud idle <0-100>",          "how visible the player bar stays when nothing is happening (0 hides it)" },
    { "/cchud scale <50-200>",        "size of the frames, in percent" },
    { "/cchud unlock | lock",         "drag the frames to where you want them (the game's Edit Mode does this too)" },
    { "/cchud reset",                 "put the frames back where they started" },
    { "/cchud demo",                  "play a short made-up fight, to see how the frames react (again to stop)" },
    { "/cchud check",                 "compare what is on screen with the settings (check all lists every row)" },
    { "/cchud probe",                 "save a description of this client's Gamepad UI (for troubleshooting)" },
    { "/cchud help",                  "show this list" },
}

local function Status()
    local db = ns.db
    say(L["%s  |  Gamepad UI: %s  |  running: %s"]:format(onoff(db.enabled), onoff(ns.IsGamepadUI()),
        onoff(ns.ShouldRun())))
    say(L["player %s, target %s, pet %s, focus %s  |  game frames put aside: %s  |  chat moved: %s"]:format(
        onoff(db.units.player), onoff(db.units.target), onoff(db.units.pet), onoff(db.units.focus),
        onoff(db.hideBlizzard), onoff(db.chat)))
    say(L["native options: target of target %s, Cooldown Manager %s, personal resource %s"]:format(
        onoff(ns.GetNative("tot")), onoff(ns.GetNative("cooldowns")), onoff(ns.GetNative("resource"))))
    say(L["text size %d%%  |  text shade: %s"]:format(db.textScale * 100 + 0.5, onoff(db.textShade)))
    say(L["vendor and bank help: %s  |  auto-sell: %s  |  white gear is junk: %s"]:format(onoff(db.vendor),
        onoff(db.sell.auto), onoff(db.sell.gear)))
    say(L["idle visibility %d%%  |  scale %d%%  |  class colours: %s"]:format(db.idle * 100 + 0.5,
        db.scale * 100 + 0.5, onoff(db.classColors)))
    if ns.IsPending() then say(L["Changes are applied when combat ends."]) end
    for _, err in ipairs(ns.errors) do say("|cffff5555" .. L["error:"] .. "|r " .. err) end
end

local function Help()
    say(L["A minimal action-game HUD for the Gamepad UI."])
    for _, rows in ipairs({ HELP, ns.helpRows }) do
        for _, row in ipairs(rows) do
            print(("  |cffffd100%s|r  %s"):format(row[1], L[row[2]]))
        end
    end
end

local Toggle = ns.Toggle

local function Applied()
    if ns.Apply() == false then say(L["Changes are applied when combat ends."]) end
end

SLASH_CCHUD1 = "/cchud"
SLASH_CCHUD2 = "/chud"                     -- the short name: ControllerCam HUD, "Chud"
SlashCmdList["CCHUD"] = function(msg)
    local db = ns.db
    if not db then return end
    local cmd, arg = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd, arg = cmd:lower(), arg:lower()

    if cmd == "" or cmd == "status" then
        Status()
    elseif cmd == "help" or cmd == "?" then
        Help()
    elseif cmd == "on" or cmd == "off" then
        db.enabled, db.asked = (cmd == "on"), true
        say(db.enabled and L["enabled"] or L["disabled: the game's own frames are back"])
        Applied()
    elseif cmd == "always" then
        db.always = Toggle(arg, db.always)
        say(L["use in the mouse & keyboard UI too: %s"]:format(onoff(db.always)))
        Applied()
    elseif db.units[cmd] ~= nil then
        db.units[cmd] = Toggle(arg, db.units[cmd])
        say(("%s: %s"):format(cmd, onoff(db.units[cmd])))
        Applied()
    elseif cmd == "blizzard" then
        db.hideBlizzard = not Toggle(arg, not db.hideBlizzard)
        say(L["game frames put aside: %s"]:format(onoff(db.hideBlizzard)))
        Applied()
    elseif cmd == "chat" then
        db.chat = Toggle(arg, db.chat)
        say(L["chat moved to the top left: %s"]:format(onoff(db.chat)))
        Applied()
    elseif cmd == "classcolor" or cmd == "classcolour" or cmd == "classcolors" then
        db.classColors = Toggle(arg, db.classColors)
        say(L["class colours: %s"]:format(onoff(db.classColors)))
        ns.UnitFrames:Refresh()
    elseif ns.NATIVE[cmd] then
        -- the game's own option: flip it there, so its menus and ours always agree
        local current = ns.GetNative(cmd)
        if current == nil then say(L["This client does not have that option."]); return end
        local want = Toggle(arg, current)
        if ns.SetNative(cmd, want) then
            say(L["%s: %s (the game's own option)"]:format(cmd, onoff(want)))
        else
            say(L["The game did not accept that right now."])
        end
        Applied()
    elseif cmd == "vendor" then
        db.vendor = Toggle(arg, db.vendor)
        say(L["vendor and bank help: %s"]:format(onoff(db.vendor)))
        Applied()
    elseif cmd == "autosell" then
        db.sell.auto = Toggle(arg, db.sell.auto)
        say(L["auto-sell: %s"]:format(onoff(db.sell.auto)))
    elseif cmd == "sellgear" then
        db.sell.gear = Toggle(arg, db.sell.gear)
        say(L["white gear is junk: %s"]:format(onoff(db.sell.gear)))
    elseif cmd == "sell" then
        local V = ns.Vendor
        if not V.active then say(L["Vendor help is off."]); return end
        if not V.merchantOpen then say(L["Open a vendor first."]); return end
        if arg == "" then
            V:Prompt()
        elseif arg == "junk" then
            V:SellJunk()
        elseif arg == "recommended" then
            V:ConfirmAdvised()
        else
            local quality = V.ParseQuality(arg)
            if not quality then say(L["usage: /cchud sell [junk | recommended | white | green | blue]"]); return end
            V:Confirm(V:Collect("quality", quality))
        end
    elseif cmd == "deposit" then
        if not ns.Vendor.active then say(L["Vendor help is off."]); return end
        ns.Vendor:Deposit()
    elseif cmd == "withdraw" then
        if not ns.Vendor.active then say(L["Vendor help is off."]); return end
        ns.Vendor:Withdraw()
    elseif cmd == "autodeposit" then
        db.sell.deposit = Toggle(arg, db.sell.deposit)
        say(L["deposit marked items when the bank opens: %s"]:format(onoff(db.sell.deposit)))
    elseif cmd == "junk" or cmd == "keep" or cmd == "bank" then
        local id = tonumber((msg or ""):match("item:(%d+)")) or tonumber(arg)
        if not id then say(L["usage: /cchud junk <item> (shift-click the item into the chat line)"]); return end
        local sell = db.sell
        sell.junk[id], sell.keep[id], sell.bank[id] = nil, nil, nil
        sell[cmd][id] = true
        say((cmd == "junk" and L["item %d: junk, sold with the rest"] or cmd == "keep" and L["item %d: kept, never sold"]
            or L["item %d: for the bank"]):format(id))
    elseif cmd == "shade" then
        db.textShade = Toggle(arg, db.textShade)
        say(L["text shade: %s"]:format(onoff(db.textShade)))
        ns.UnitFrames:ApplyLook()
    elseif cmd == "text" then
        local n = tonumber(arg)
        if not n then say(L["usage: /cchud text <80-250>"]); return end
        db.textScale = ns.Clamp(n, 80, 250) / 100
        say(L["text size %d%%"]:format(db.textScale * 100 + 0.5))
        ns.UnitFrames:ApplyLook()
    elseif cmd == "demo" then
        local UF = ns.UnitFrames
        if UF.fake then
            UF:SetDemo(false)
            say(L["demo stopped"])
        elseif not ns.ShouldRun() then
            say(L["The HUD is not running."])
        elseif UF:SetDemo(true) then
            say(L["Demo running: a made-up fight on a loop. Type /cchud demo again to stop."])
        else
            say(L["Not in combat."])
        end
    elseif cmd == "check" then
        ns.RunCheck(arg == "all")
    elseif cmd == "idle" then
        local n = tonumber(arg)
        if not n then say(L["usage: /cchud idle <0-100>"]); return end
        db.idle = ns.Clamp(n, 0, 100) / 100
        say(L["idle visibility %d%%"]:format(db.idle * 100 + 0.5))
    elseif cmd == "scale" then
        local n = tonumber(arg)
        if not n then say(L["usage: /cchud scale <50-200>"]); return end
        db.scale = ns.Clamp(n, 50, 200) / 100
        say(L["scale %d%%"]:format(db.scale * 100 + 0.5))
        Applied()
    elseif cmd == "unlock" or cmd == "lock" then
        if cmd == "unlock" and not ns.ShouldRun() then say(L["The HUD is not running."]); return end
        if ns.UnitFrames:SetUnlocked(cmd == "unlock") then
            say(cmd == "unlock" and L["Drag the frames, then type /cchud lock."] or L["frames locked"])
        else
            say(L["Not in combat."])
        end
    elseif cmd == "reset" and arg == "all" then
        local name = ns.Presets:ResetAll()
        say(L["Everything is back to how it started: settings, frames and the screen layout (your vendor marks and price history are kept)."])
        if name and not (ns.Share.Layout() or {}).name then
            say(L["A layout named '%s' was added to the game's Edit Mode. Choose it there to use it (Game Menu > Edit Mode > Layout)."]:format(name))
        end
    elseif cmd == "reset" then
        ns.UnitFrames:ResetPositions()
        say(L["frames are back where they started"])
    elseif cmd == "probe" then
        ns.RunProbe()
    elseif ns.commands[cmd] then
        ns.commands[cmd](arg, msg)
    elseif ns.ModuleForCommand and ns.ModuleForCommand(cmd) then
        ns.ModuleList.Off(ns.ModuleForCommand(cmd))        -- a module's command, and the module is off
    else
        say(L["unknown command '%s'. Type /cchud help"]:format(cmd))
    end
end

-- /cchud errors: the last errors the HUD met, newest first (also after a reload); /cchud errors clear
ns.RegisterSaved("errorLog", function(old)
    local out = {}
    if type(old) ~= "table" then return out end
    for _, e in ipairs(old) do
        if type(e) == "table" and type(e.text) == "string" and #out < 15 then
            out[#out + 1] = { when = tostring(e.when or ""), text = e.text }
        end
    end
    return out
end)
ns.RegisterCommand("errors", function(arg)
    local log = ns.db.errorLog or {}
    if arg == "clear" then
        ns.db.errorLog = {}
        ns.Say(L["Error list cleared."])
        return
    end
    if #log == 0 then ns.Say(L["No errors recorded."]); return end
    for i = math.min(#log, 10), 1, -1 do print(("  %s  %s"):format(log[i].when, log[i].text)) end
    ns.Say(L["%d errors recorded (newest last). /cchud errors clear empties the list."]:format(#log))
end, "/cchud errors [clear]", "the last errors the HUD met, also after a reload (to report them)")
