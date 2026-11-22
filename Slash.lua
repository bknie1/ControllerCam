-- ControllerCam slash commands: /ccam (or /controllercam). Type /ccam help.

local ADDON, ns = ...
local L = ns.L

local say = function(msg) ns.Say(msg) end

local function onoff(b)
    return b and ("|cff33ff33" .. L["on"] .. "|r") or ("|cffff5555" .. L["off"] .. "|r")
end

-- Split on spaces, but keep "quoted text" together.
function ns.Tokenize(str)
    local out = {}
    local i = 1
    str = str or ""
    while i <= #str do
        local c = str:sub(i, i)
        if c:match("%s") then
            i = i + 1
        elseif c == '"' then
            local close = str:find('"', i + 1, true)
            if close then
                out[#out + 1] = str:sub(i + 1, close - 1)
                i = close + 1
            else
                out[#out + 1] = str:sub(i + 1)
                break
            end
        else
            local e = str:find("%s", i) or (#str + 1)
            out[#out + 1] = str:sub(i, e - 1)
            i = e
        end
    end
    return out
end

local function profileOrSay(token)
    local id, why = ns.FindProfile(token)
    if not id then
        if why == "ambiguous" then
            say((L["'%s' matches more than one profile. Type more of the name."]):format(token or ""))
        else
            say((L["No profile called '%s'. /ccam list shows them."]):format(token or ""))
        end
    end
    return id
end

local function situationFor(token)
    token = (token or ""):lower()
    for _, sit in ipairs(ns.SITUATIONS) do
        if sit == token then return sit end
    end
    for _, sit in ipairs(ns.SITUATIONS) do               -- also the shown label, e.g. "combat"
        if ns.SITUATION_LABEL[sit]:lower():find(token, 1, true) and token ~= "" then return sit end
    end
end

local function Status()
    local db = ns.GetDB()
    local st = ns.Status()
    say(("%s  |  %s: %s"):format(onoff(db.enabled), L["current"],
        st.profile and ("|cffffd100" .. st.profile .. "|r (" .. (st.sit == "force" and L["forced"] or ns.SITUATION_LABEL[st.sit]) .. ")")
                    or L["nothing applied yet"]))
    for _, sit in ipairs(ns.SITUATIONS) do
        local id = db.assign[sit]
        print(("  %-26s %s"):format(ns.SITUATION_LABEL[sit], id and ns.ProfileName(id) or ("|cff999999" .. L["no change"] .. "|r")))
    end
end

local function List()
    local db = ns.GetDB()
    for _, id in ipairs(ns.ProfileIds()) do
        local tag = ""
        if not ns.IsBuiltin(id) then tag = " |cff999999(" .. L["custom"] .. ")|r"
        elseif ns.IsEdited(id) then tag = " |cff999999" .. L["(edited)"] .. "|r" end
        print(("  |cffffd100%s|r%s - %s"):format(ns.ProfileName(id), tag, ns.ProfileDescription(id)))
    end
end

local function Settings_()
    for _, s in ipairs(ns.SETTINGS) do
        print(("  |cffffd100%s|r  %s"):format(s.key, L[s.label]))
    end
end

local HELP = {
    { "/ccam",                              "show status" },
    { "/ccam list",                         "list the profiles" },
    { "/ccam describe <profile>",           "what a profile feels like and every setting it changes" },
    { "/ccam use <profile>",                "use one profile everywhere (try: action, hybrid, classic)" },
    { "/ccam starter",                      "the recommended setup: Action camera with calmer profiles for cities, mounts, flying, raids" },
    { "/ccam set <situation> <profile|none>", "choose the profile for one situation (/ccam shows the list)" },
    { "/ccam force <profile>",              "use a profile now, whatever the situation" },
    { "/ccam auto",                         "stop forcing a profile" },
    { "/ccam save <name>",                  "save your current camera settings as a new profile" },
    { "/ccam copy <profile> [new name]",    "make an editable copy of a profile" },
    { "/ccam edit <profile> <setting> <value|default>", "change a setting of a custom profile (/ccam settings lists them)" },
    { "/ccam curve <profile> <zoom:offset ...>", "shoulder offset by camera distance, e.g. /ccam curve mine 0:2 8:2 20:0" },
    { "/ccam advanced [on|off]",            "allow editing the built-in profiles too (/ccam reset <profile> brings the original back)" },
    { "/ccam reset <profile>",              "put an edited built-in profile back to its original settings" },
    { "/ccam delete <profile>",              "delete a custom profile" },
    { "/ccam export <profile>",             "show a string you can share" },
    { "/ccam import <string>",              "add a profile from a shared string" },
    { "/ccam flip",                         "switch the shoulder offset to the other shoulder" },
    { "/ccam formoffset <percent | reset>", "the shoulder offset in the form you are in (druid forms, ghost wolf), in percent of normal" },
    { "/ccam delay <seconds>",              "how long a situation is kept after it ends (default 1.5)" },
    { "/ccam targetzoom <yards>",           "on an enemy target the camera comes in this close, and goes back out after (0: off)" },
    { "/ccam on | off",                     "turn on, or turn off and restore your original camera settings" },
    { "/ccam info",                         "show the zoom, shoulder offset and motion settings right now (for troubleshooting)" },
    { "/ccam notice",                       "let the game ask about its experimental camera settings again at the next login" },
    { "/ccam config",                       "open the options panel (Options > AddOns > ControllerCam)" },
    { "/ccam help",                         "show this list" },
}

local function Help()
    say(L["Camera profiles for controller play. Out of the box you get an Action camera; Hybrid and Classic are one command away."])
    for _, row in ipairs(HELP) do
        print(("  |cffffd100%s|r  %s"):format(row[1], L[row[2]]))
    end
end

-- Shows text the player can copy: a popup with an edit box if the options panel provides one, else chat.
local function ShowText(title, text)
    if ns.ShowTextBox then ns.ShowTextBox(title, text) else print(text) end
end

local function reason(why)
    if why == "builtin" then return L["Built-in profiles are locked. Turn on advanced editing (/ccam advanced on) or make a copy: /ccam copy <profile>"] end
    if why == "unknown" then return L["Unknown setting. /ccam settings lists them."] end
    if why == "range" then return L["That value is outside the allowed range."] end
    return L["That value is not valid."]
end

local function parseEditValue(s, raw)
    if raw:lower() == "default" or raw:lower() == "d" then return "d" end
    if s.kind == "mul" then
        if raw:match("^x") then return raw end
        return "x" .. raw
    end
    if raw:lower() == "on" then return 1 end
    if raw:lower() == "off" then return 0 end
    return tonumber(raw)
end

local function Command(msg)
    local db = ns.GetDB()
    if not db then return end
    local args = ns.Tokenize(msg)
    local cmd = (table.remove(args, 1) or ""):lower()
    local rest = table.concat(args, " ")

    if cmd == "" or cmd == "status" then Status()
    elseif cmd == "help" or cmd == "?" then Help()
    elseif cmd == "list" then List()
    elseif cmd == "settings" then Settings_()
    elseif cmd == "describe" or cmd == "show" then
        local id = profileOrSay(rest)
        if id then
            local name, desc, rows = ns.DescribeProfile(id)
            print(("|cffffd100%s|r%s"):format(name, ns.IsEdited(id) and (" " .. L["(edited)"]) or ""))
            print("  " .. desc)
            for _, row in ipairs(rows) do print(("  %s: |cffffffff%s|r"):format(row[1], row[2])) end
            print("  |cff999999" .. L["Everything not listed uses the game default."] .. "|r")
        end
    elseif cmd == "on" then ns.SetEnabled(true); say(L["enabled"])
    elseif cmd == "off" then ns.SetEnabled(false); say(L["disabled. Your original camera settings were restored."])
    elseif cmd == "use" then
        local id = profileOrSay(rest)
        if id then ns.UseEverywhere(id); say((L["Using '%s' everywhere."]):format(ns.ProfileName(id))) end
    elseif cmd == "starter" then
        ns.ApplyStarter(); say(L["Recommended setup applied."])
    elseif cmd == "set" then
        local sit = situationFor(args[1])
        if not sit then say(L["Unknown situation. Use one of:"] .. " " .. table.concat(ns.SITUATIONS, ", ")); return end
        local name = table.concat(args, " ", 2)
        if name == "" then say(L["usage: /ccam set <situation> <profile|none>"]); return end
        if name:lower() == "none" then
            ns.Assign(sit, nil); say((L["%s: no change"]):format(ns.SITUATION_LABEL[sit]))
        else
            local id = profileOrSay(name)
            if id then ns.Assign(sit, id); say(("%s: %s"):format(ns.SITUATION_LABEL[sit], ns.ProfileName(id))) end
        end
    elseif cmd == "force" then
        local id = profileOrSay(rest)
        if id then ns.Force(id); say((L["Forcing '%s'. /ccam auto goes back to the situations."]):format(ns.ProfileName(id))) end
    elseif cmd == "auto" then
        ns.Force(nil); say(L["The camera follows your situations again."])
    elseif cmd == "save" then
        local id = ns.CaptureCurrent(rest ~= "" and rest or L["My profile"])
        if id then say((L["Saved as '%s'."]):format(ns.ProfileName(id))) end
    elseif cmd == "copy" then
        local id = profileOrSay(args[1])
        if id then
            local new = ns.DuplicateProfile(id, args[2] and table.concat(args, " ", 2) or nil)
            if new then say((L["Saved as '%s'."]):format(ns.ProfileName(new))) end
        end
    elseif cmd == "edit" then
        local id = profileOrSay(args[1])
        if not id then return end
        local s = ns.SETTING_BY_KEY[args[2] or ""]
        if not s then say(reason("unknown")); return end
        if not args[3] then say(L["usage: /ccam edit <profile> <setting> <value|default>"]); return end
        if s.kind == "curve" then say(L["Use /ccam curve for the offset by zoom."]); return end
        local ok, why = ns.SetValue(id, s.key, (function()
            local v = parseEditValue(s, args[3])
            if v == "d" then return nil end                           -- "default" = remove from the profile
            return v
        end)())
        say(ok and L["Done."] or reason(why))
    elseif cmd == "curve" then
        local id = profileOrSay(args[1])
        if not id then return end
        local points = {}
        for i = 2, #args do
            local z, v = args[i]:match("^([^:]+):([^:]+)$")
            points[#points + 1] = { tonumber(z), tonumber(v) }
        end
        if #points == 0 then
            local ok = ns.SetValue(id, "shoulderCurve", nil)
            say(ok and L["Done."] or reason("builtin"))
            return
        end
        local ok, why = ns.SetValue(id, "shoulderCurve", points)
        say(ok and L["Done."] or reason(why == "curve" and "type" or why))
    elseif cmd == "advanced" then
        local arg = (args[1] or ""):lower()
        if arg == "on" then ns.SetAdvanced(true) elseif arg == "off" then ns.SetAdvanced(false)
        elseif arg == "" then ns.SetAdvanced(not db.advanced) else say(L["usage: /ccam advanced [on|off]"]); return end
        say((L["Advanced editing is %s."]):format(onoff(db.advanced)))
    elseif cmd == "reset" then
        local id = profileOrSay(rest)
        if id then
            if ns.ResetBuiltin(id) then say((L["'%s' is back to its original settings."]):format(ns.ProfileName(id)))
            else say((L["Nothing to reset: '%s' has not been edited."]):format(ns.ProfileName(id))) end
        end
    elseif cmd == "delete" then
        local id = profileOrSay(rest)
        if id then
            if ns.IsBuiltin(id) then say(L["Built-in profiles cannot be deleted."]) else
                local name = ns.ProfileName(id)
                ns.DeleteProfile(id); say((L["Deleted '%s'."]):format(name))
            end
        end
    elseif cmd == "export" then
        local id = profileOrSay(rest)
        if id then ShowText(ns.ProfileName(id), ns.ExportById(id)) end
    elseif cmd == "import" then
        local id, err = ns.ImportString(rest)
        if id then say((L["Imported '%s'. /ccam use \"%s\" to try it."]):format(ns.ProfileName(id), ns.ProfileName(id))) else say(err) end
    elseif cmd == "flip" then
        ns.SetFlipShoulder(not db.flipShoulder); say(db.flipShoulder and L["Shoulder offset mirrored."] or L["Shoulder offset back to normal."])
    elseif cmd == "formoffset" then
        local arg = (args[1] or ""):lower()
        if not ns.CurrentForm() then say(L["You are not in a form."]); return end
        local n = tonumber(arg)
        if arg == "" then
            say((L["Shoulder offset in this form: %d%%"]):format(ns.ShoulderScale() * 100 + 0.5))
        elseif arg == "reset" then
            ns.SetFormOffset(nil)
            say((L["Shoulder offset in this form: %d%%"]):format(ns.ShoulderScale() * 100 + 0.5))
        elseif n and n >= 0 and n <= 200 then
            ns.SetFormOffset(n / 100)
            say((L["Shoulder offset in this form: %d%%"]):format(n + 0.5))
        else
            say(L["usage: /ccam formoffset <percent> (or reset)"])
        end
    elseif cmd == "delay" then
        local n = tonumber(args[1])
        if n and n >= 0 then ns.SetExitDelay(n); say((L["Situations are kept for %.1f seconds after they end."]):format(db.exitDelay))
        else say(L["usage: /ccam delay <seconds>"]) end
    elseif cmd == "targetzoom" or cmd == "closer" then
        local n = tonumber(args[1]) or (args[1] == "off" and 0) or nil
        if n and n >= 0 then
            ns.SetTargetZoom(n)
            if db.targetZoom > 0 then say((L["On an enemy target the camera comes in to %.1f yards."]):format(db.targetZoom))
            else say(L["The camera keeps its distance on an enemy target."]) end
        else say(L["usage: /ccam targetzoom <yards> (0 or off: off)"]) end
    elseif cmd == "config" or cmd == "options" then
        if ns.OpenOptions then ns.OpenOptions() else say(L["options panel is not available in this client"]) end
    elseif cmd == "info" then
        local st = ns.Status()
        local zoom = tonumber(GetCameraZoom and GetCameraZoom())
        local p = st.id and ns.GetProfile(st.id)
        local curveValue
        if p and p.values.shoulderCurve and zoom then curveValue = ns.EvalCurve(p.values.shoulderCurve, zoom) end
        say(("profile %s  |  situation %s  |  Gamepad UI %s"):format(tostring(st.profile), tostring(st.sit), tostring(ns.IsGamepadUI())))
        say(("zoom %s  |  curve says %s  |  test_cameraOverShoulder = %s"):format(
            zoom and ns.FormatNumber(zoom) or "?", curveValue and ns.FormatNumber(curveValue) or "-", tostring(GetCVar("test_cameraOverShoulder"))))
        say(("CameraKeepCharacterCentered = %s  |  CameraReduceUnexpectedMovement = %s  |  head tracking strength = %s"):format(
            tostring(GetCVar("CameraKeepCharacterCentered")), tostring(GetCVar("CameraReduceUnexpectedMovement")),
            tostring(GetCVar("test_cameraHeadMovementStrength"))))
    elseif cmd == "notice" then
        ns.AskNoticeAgain()
        say(L["The game will ask about its experimental camera settings again at the next login."])
    elseif cmd == "debug" then
        ns.SetDebug(not ns.IsDebug()); say("debug " .. onoff(ns.IsDebug()))
    else
        say((L["unknown command '%s'. Type /ccam help"]):format(cmd))
    end
end

ns.Command = Command

SLASH_CONTROLLERCAM1 = "/ccam"
SLASH_CONTROLLERCAM2 = "/controllercam"
SlashCmdList["CONTROLLERCAM"] = Command
