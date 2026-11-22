-- ControllerCam HUD: self-check. /cchud check compares what is on screen with what the settings say should be
-- there, one row per fact, and keeps the result in ControllerCamHUDDB.check (written to disk on /reload).

local ADDON, ns = ...
local L = ns.L

local NEEDED = { "UnitHealth", "UnitHealthMax", "UnitPower", "UnitPowerType", "UnitCastingInfo", "UnitChannelInfo",
                 "RegisterUnitWatch", "UnregisterUnitWatch", "InCombatLockdown" }

function ns.RunCheck(showAll, quiet)
    local db = ns.db
    local rows, failed = {}, 0
    local function row(name, ok, detail)
        ok = ok and true or false
        rows[#rows + 1] = { name = name, ok = ok, detail = detail and tostring(detail) or nil }
        if not ok then failed = failed + 1 end
    end

    local flag = GetCVar(ns.STYLE_CVAR)
    local run = ns.ShouldRun() and true or false
    row("the Gamepad UI setting can be read", flag ~= nil, flag)
    row("the HUD runs exactly when it should", run == ((db.enabled and (db.always or flag == "1")) and true or false))
    row("no change is waiting for combat to end", not ns.IsPending())

    local UF = ns.UnitFrames
    for _, key in ipairs({ "player", "target", "pet", "tot", "focus", "vertical" }) do
        local f = UF.frames[key]
        if UF:Wanted(key, run) then
            row(key .. " frame exists", f ~= nil)
            if f then
                row(key .. " frame is switched on", f.on)
                row(key .. " frame follows the right unit", f.button:GetAttribute("unit") == f.unit)
                local expect = (key == "player" or UF.fake ~= nil or UnitExists(f.unit)) and true or false
                row(key .. " frame is visible exactly when it has something to show",
                    (f.button:IsShown() and true or false) == expect)
                row(key .. " health bar has its art", f.health.fill:GetStatusBarTexture() ~= nil)
                row(key .. " health bar has its shape", f.health.mask ~= nil or f.health.vertical == true)
            end
        else
            row(key .. " frame is off", not f or (not f.on and not f.button:IsShown()))
        end
    end

    local hidden = _G.ControllerCamHUDHidden
    for name, key in pairs({ PlayerFrame = "player", TargetFrame = "target", FocusFrame = "focus" }) do
        local frame = _G[name]
        if frame then
            local own = db.units[key] or (key == "player" and db.units.vertical)
            local want = (run and db.hideBlizzard and own) and true or false
            row(want and ("the game's " .. name .. " is invisible but working") or ("the game's " .. name .. " is left alone"),
                ns.IsBlizzardFaded(name) == want and (not want or frame:GetAlpha() == 0))
            row(("the game's %s stays where the game keeps it"):format(name), frame:GetParent() ~= hidden)
        end
    end
    row("the hidden holder is hidden", hidden ~= nil and not hidden:IsShown())

    local chat = _G.ChatFrame1
    if chat then
        local want = (run and db.chat) and true or false
        row(want and "the chat window is moved" or "the chat window is left alone", ns.Layout.active == want)
        if want then row("the chat window sits top left", (chat:GetPoint(1)) == "TOPLEFT") end
    end

    if _G.EditModeManagerFrame and run then
        row("frames can be dragged in Edit Mode", UF.editHooked == true)
    end

    for _, check in ipairs(ns.checks) do
        local ok, err = pcall(check, row, run, db)
        if not ok then row("a module's own check ran", false, err) end
    end

    for _, name in ipairs(NEEDED) do
        row("game function " .. name, type(_G[name]) == "function")
    end
    row("no errors so far", #ns.errors == 0, ns.errors[1])

    db.check = { when = date and date("%Y-%m-%d %H:%M:%S") or tostring(time()), failed = failed, rows = rows }

    if quiet then return failed, rows end
    for _, r in ipairs(rows) do
        if showAll or not r.ok then
            print(("  %s  %s%s"):format(r.ok and "|cff33ff33ok|r  " or "|cffff5555FAIL|r", r.name,
                (not r.ok and r.detail) and (" (" .. r.detail .. ")") or ""))
        end
    end
    ns.Say(L["check: %d of %d passed"]:format(#rows - failed, #rows))
    return failed, rows
end
