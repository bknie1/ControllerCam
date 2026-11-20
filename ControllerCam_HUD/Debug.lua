-- ControllerCam HUD: debug reports.
-- While "Debug reports" is on, the troubleshooting reports are gathered without being asked for:
--   * a few seconds after you log in (and the probe of this client's Gamepad UI once per game build),
--   * again at the moment you reload or log out, which is when the game writes the saved settings: the file
--     then holds the screen as it was just before,
--   * when the auction house opens, and whenever one of the gamepad wheels (stances, pet commands) is on screen.
-- Along the way the modules leave short notes (ns.Note) of what they did: the last 120 are kept too.
-- All of it goes to ControllerCamHUDDB.debugReport. Nothing leaves your computer.
--
-- On while the addon is being finished; D.DEFAULT goes to false before it is published (the tests refuse a
-- tagged build with it on).

local ADDON, ns = ...
local L = ns.L

local D = { DEFAULT = false, flyouts = {}, seen = {} }
ns.Debug = D

ns.RegisterSetting({
    key = "debug", kind = "boolean", default = D.DEFAULT, command = "debug", section = "General", share = false,
    label = "Debug reports",
    tip = "gather the troubleshooting reports by themselves: when you log in, and again when you reload or log out (they are kept in the saved settings)",
    onChange = function(on)
        ns.Debug.TaintLog()
        if on then ns.Debug.Collect("switched on") end
    end,
})

-- While the reports are on, the game keeps its own record of what it refused and why (Logs/taint.log in the
-- game's folder): its "taintLog" setting, switched on with the reports and put back with them.
ns.RegisterSaved("taintLogWas", function(old) return (old == "0" or old == "1" or old == "2") and old or nil end)
function D.TaintLog()
    if not (ns.db and GetCVar and SetCVar) then return end
    local ok, now = pcall(GetCVar, "taintLog")
    if not ok or now == nil then return end
    if ns.db.debug then
        if now == "0" then
            ns.db.taintLogWas = now
            pcall(SetCVar, "taintLog", "1")
        end
    elseif ns.db.taintLogWas then
        if now == "1" then pcall(SetCVar, "taintLog", ns.db.taintLogWas) end
        ns.db.taintLogWas = nil
    end
end

local function Stamp() return date and date("%Y-%m-%d %H:%M:%S") or tostring(time and time() or 0) end

local function Text(v)
    if ns.IsSecret(v) then return "(secret)" end
    return tostring(v)
end

---------------------------------------------------------------------------
-- The sections
---------------------------------------------------------------------------
local PAD_KEYS = { "PAD1", "PAD2", "PAD3", "PAD4", "PAD5", "PAD6", "PADDUP", "PADDDOWN", "PADDLEFT", "PADDRIGHT",
                   "PADLSHOULDER", "PADRSHOULDER", "PADLTRIGGER", "PADRTRIGGER", "PADLSTICK", "PADRSTICK",
                   "PADBACK", "PADFORWARD", "PADSOCIAL", "PADSYSTEM" }
local ACTIONS = { "INTERACTTARGET", "INTERACTMOUSEOVER", "GAMEPADLEFTMOD", "GAMEPADRIGHTMOD", "JUMP", "TOGGLEAUTORUN",
                  "CCHUD_FISHING", "CCHUD_MARKET", "CCHUD_SORT", "CCHUD_QUICKMOVE" }

local function Screen()
    local out = {}
    local w, h = UIParent:GetSize()
    out[#out + 1] = ("UIParent %sx%s scale %s effective %s"):format(Text(w), Text(h), Text(UIParent:GetScale()),
        Text(UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()))
    if GetPhysicalScreenSize then
        local ok, pw, ph = pcall(GetPhysicalScreenSize)
        if ok then out[#out + 1] = ("screen %sx%s"):format(Text(pw), Text(ph)) end
    end
    for _, cvar in ipairs({ "uiScale", "useUiScale", ns.STYLE_CVAR, "SoftTargetInteract", "SoftTargetEnemy",
                            "autoLootDefault", "GamePadEnable" }) do
        out[#out + 1] = cvar .. " = " .. Text((GetCVar(cvar)))
    end
    if GetBuildInfo then
        local v, b, _, toc = GetBuildInfo()
        out[#out + 1] = ("build %s %s %s"):format(Text(v), Text(b), Text(toc))
    end
    return out
end

local function Bindings()
    local out = {}
    if not GetBindingKey then return out end
    for _, action in ipairs(ACTIONS) do
        local keys = { GetBindingKey(action) }
        out[#out + 1] = action .. " = " .. (#keys > 0 and table.concat(keys, " ") or "(none)")
    end
    if GetBindingAction then
        for _, key in ipairs(PAD_KEYS) do
            local ok, plain = pcall(GetBindingAction, key, false)
            local ok2, now = pcall(GetBindingAction, key, true)
            plain, now = ok and plain or "?", ok2 and now or "?"
            if plain ~= "" or now ~= "" then
                out[#out + 1] = key .. " -> " .. Text(plain) .. ((now ~= plain) and ("  (now: " .. Text(now) .. ")") or "")
            end
        end
    end
    return out
end

local function Resting()
    local R, out = ns.Rest, {}
    if not R then return out end
    out[#out + 1] = ("active %s, alpha %.2f, reason %s, trigger %s, minimap redrawn %d times"):format(tostring(R.active),
        R.alpha, tostring((R.Reason())), tostring(R.TriggerHeld()), R.redraws or 0)
    for f, base in pairs(R.frames) do
        out[#out + 1] = ("%s: alpha %.2f (its own %.2f), shown %s"):format(tostring(f.GetName and f:GetName() or "?"),
            f:GetAlpha() or 1, base, tostring(f.IsShown and f:IsShown() and true or false))
    end
    return out
end

local function Casting()
    local CB, out = ns.CastBar, {}
    if not CB then return out end
    out[#out + 1] = ("active %s, last cast: %s"):format(tostring(CB.active), tostring(D.lastCast))
    return out
end

local function Errors()
    local out = {}
    for i, e in ipairs(ns.errors) do out[i] = e end
    return out
end

-- What the game refused us: an action only its own interface may take, or one that our code had touched.
-- The game names what was called; kept here so it can be read afterwards.
D.refused = {}
local guard = CreateFrame("Frame")
pcall(guard.RegisterEvent, guard, "ADDON_ACTION_FORBIDDEN")
pcall(guard.RegisterEvent, guard, "ADDON_ACTION_BLOCKED")
guard:SetScript("OnEvent", function(_, event, addon, what)
    if addon ~= ADDON then return end
    local line = ("%s %s: %s"):format(date and date("%H:%M:%S") or "", event == "ADDON_ACTION_FORBIDDEN" and "forbidden" or "blocked",
        tostring(what))
    if debugstack and (D.traced or 0) < 8 then              -- the first few: the path that led to it
        D.traced = (D.traced or 0) + 1
        local ok, stack = pcall(debugstack, 2, 12, 0)
        local from, path = {}, {}
        if ok and type(stack) == "string" then
            for file, n in stack:gmatch("ControllerCam_HUD[/\\]([%w_]+%.lua)[^:\n]*:(%d+)") do
                if file ~= "Debug.lua" then from[#from + 1] = file .. ":" .. n end
            end
            for row in stack:gmatch("[^\n]+") do              -- the game's own lines too: where it was when it refused
                if #path < 8 and not row:find("Debug%.lua") then
                    path[#path + 1] = (row:gsub("^%s+", ""):gsub("Interface[/\\]", ""):sub(1, 110))
                end
            end
        end
        if #from > 0 then line = line .. " from " .. table.concat(from, " < ") end
        if #path > 0 then line = line .. " | path: " .. table.concat(path, " < ") end
    end
    D.refused[#D.refused + 1] = line
    if #D.refused > 30 then table.remove(D.refused, 1) end
    ns.Note("refused: %s", line)
end)

local function Layouts()
    local out, E = {}, _G.C_EditMode
    local have = {}
    for _, name in ipairs({ "GetLayouts", "SaveLayouts", "SetActiveLayout", "ConvertLayoutInfoToString",
                            "ConvertStringToLayoutInfo" }) do
        have[#have + 1] = name .. "=" .. ((type(E) == "table" and type(E[name]) == "function") and "yes" or "no")
    end
    out[1] = table.concat(have, " ")
    if type(E) == "table" and type(E.GetLayouts) == "function" then
        local ok, all = pcall(E.GetLayouts)
        if ok and type(all) == "table" then
            local names = {}
            for i, layout in ipairs(type(all.layouts) == "table" and all.layouts or {}) do
                names[i] = ("%s (kind %s)"):format(tostring(layout.layoutName), tostring(layout.layoutType))
            end
            out[#out + 1] = ("active number %s of %d built in + %d yours: %s"):format(tostring(all.activeLayout),
                ns.Share.BuiltinLayouts(), #names, table.concat(names, ", "))
        else
            out[#out + 1] = "GetLayouts failed: " .. tostring(all)
        end
    end
    local layout = ns.Share and ns.Share.Layout()
    if layout and layout.builtin then
        out[#out + 1] = "active: the game's " .. layout.builtin
    elseif layout then
        out[#out + 1] = ("active: '%s', its text:"):format(layout.name)
        out[#out + 1] = layout.text
    end
    out[#out + 1] = "screen offered: " .. tostring(ns.db.screenAsked)
    return out
end

D.SECTIONS = {
    { "layout", Layouts },
    { "chat", function() return ns.Chat and ns.Chat.Describe and { ns.Chat.Describe() } or {} end },
    { "refused", function() return D.refused end },
    { "sizes", function() return ns.Sizes and ns.Sizes.Describe() or {} end },
    { "screen", Screen },
    { "bindings", Bindings },
    { "pad", function() return ns.PadButtons and ns.PadButtons.Report() or {} end },
    { "rest", Resting },
    { "fishing", function()
        local out = {}
        for _, part in ipairs({ ns.Fishing, ns.FishLog, ns.FishPanel, ns.FishGame }) do
            if part and part.Describe then out[#out + 1] = part.Describe() end
        end
        return out
    end },
    { "quests", function() return ns.Quests and ns.Quests.Describe and { ns.Quests.Describe() } or {} end },
    { "padicons", function() return ns.PadIcons and { ns.PadIcons.Describe() } or {} end },
    { "auction", function() return ns.AuctionPanel and ns.AuctionPanel.Describe() or {} end },
    { "cast", Casting },
    { "plates", function() return ns.Nameplates and ns.Nameplates.Report and ns.Nameplates.Report() or {} end },
    { "auras", function()
        if not (ns.Auras and ns.Auras.Report and UnitExists("target")) then return {} end
        return ns.Auras.Report("target")
    end },
    { "flyouts", function()
        local out = {}
        for name, text in pairs(D.flyouts) do out[#out + 1] = name .. ": " .. text end
        table.sort(out)
        return out
    end },
    { "errors", Errors },
}

-- Everything, now. why: what asked for it ("login", "logout"...). Kept under that name, so the report from
-- your login and the one from the moment you reloaded sit side by side.
function D.Collect(why)
    if not ns.db then return nil end
    local report = { when = Stamp(), why = why }
    for _, s in ipairs(D.SECTIONS) do
        local ok, rows = pcall(s[2])
        report[s[1]] = ok and rows or { "failed: " .. tostring(rows) }
    end
    pcall(ns.RunCheck, false, true)                          -- the self-check, quietly (kept as "check")
    local all = type(ns.db.debugReport) == "table" and ns.db.debugReport or {}
    local slot = (why == "login" or why == "logout") and why or "asked"
    all[slot] = report
    all.notes = ns.notes
    ns.db.debugReport = all
    return report
end

---------------------------------------------------------------------------
-- The gamepad wheels: where each one opened, and whether the screen cut it off
---------------------------------------------------------------------------
D.WHEELS = { "GamepadSpellFlyout", "GamepadPetActionFlyout", "GamepadPetSpellFlyout", "GamepadRadial" }

-- ... and whatever else the game calls a wheel or a flyout here (by the names the probe found)
local function WheelNames()
    if D.wheelNames then return D.wheelNames end
    local names, have = {}, {}
    for _, name in ipairs(D.WHEELS) do names[#names + 1], have[name] = name, true end
    local frames = ns.db and type(ns.db.probe) == "table" and ns.db.probe.frames
    for name in pairs(type(frames) == "table" and frames or {}) do
        if type(name) == "string" and not have[name] and #name < 40 and #names < 40 then
            local low = name:lower()
            if (low:find("radial") or low:find("flyout") or low:find("wheel")) and not low:find("button")
                and not low:find("anim") then
                names[#names + 1], have[name] = name, true
            end
        end
    end
    D.wheelNames = names
    return names
end

local function Wheels()
    for _, name in ipairs(WheelNames()) do
        local f = _G[name]
        local shown = type(f) == "table" and f.IsShown and f:IsShown() == true
        if shown and not D.seen[name] then
            D.seen[name] = true
            local ok, left, bottom, w, h = pcall(f.GetRect, f)
            if ok and type(left) == "number" and type(bottom) == "number" then
                local s = (f.GetEffectiveScale and f:GetEffectiveScale()) or 1
                local us = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
                if type(s) ~= "number" then s = 1 end
                if type(us) ~= "number" then us = 1 end
                local uw, uh = UIParent:GetSize()
                local l, b, r, t = left * s / us, bottom * s / us, (left + (w or 0)) * s / us, (bottom + (h or 0)) * s / us
                local cut = b < 0 or l < 0 or r > (uw or r) or t > (uh or t)
                D.flyouts[name] = ("left %.0f bottom %.0f right %.0f top %.0f of %.0fx%.0f%s"):format(l, b, r, t,
                    uw or 0, uh or 0, cut and "  CUT OFF" or "")
                ns.Note("%s opened: %s", name, D.flyouts[name])
            else
                D.flyouts[name] = "shown, no place known"
            end
        elseif not shown and D.seen[name] then
            D.seen[name] = nil
        end
    end
end

---------------------------------------------------------------------------
-- When
---------------------------------------------------------------------------
local function Build()
    if not GetBuildInfo then return "?" end
    local v, b = GetBuildInfo()
    return tostring(v) .. " " .. tostring(b)
end

local function AtLogin()
    D.TaintLog()
    if not (ns.db and ns.db.debug) then return end
    -- the probe is heavy: once per game build (and again when what it looks for changed)
    local probe = ns.db.probe
    if ns.RunProbe and (type(probe) ~= "table" or probe.for_ ~= Build() or probe.v ~= ns.PROBE_VERSION) then
        pcall(ns.RunProbe, true)
        if type(ns.db.probe) == "table" then ns.db.probe.for_ = Build() end
    end
    D.Collect("login")
end

local events = CreateFrame("Frame")
local since = 0
events:SetScript("OnUpdate", function(_, dt)
    if not (ns.db and ns.db.debug) then return end
    since = since + dt
    if since < 0.25 then return end
    since = 0
    local ok, err = pcall(Wheels)
    if not ok then ns.Error(err) end
end)
events:SetScript("OnEvent", function(_, event)
    if not (ns.db and ns.db.debug) then return end
    if event == "PLAYER_LOGIN" then
        C_Timer.After(6, function() local ok, err = pcall(AtLogin); if not ok then ns.Error(err) end end)
    elseif event == "PLAYER_LOGOUT" then
        pcall(D.Collect, "logout")                           -- the game writes the saved settings right after
    elseif event == "AUCTION_HOUSE_SHOW" then
        C_Timer.After(1.5, function()
            local AP = ns.AuctionPanel
            if not AP then return end
            local ok, rows = pcall(AP.Describe)
            if ok then for _, row in ipairs(rows) do ns.Note("auction house: %s", row) end end
        end)
    end
end)
for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_LOGOUT", "AUCTION_HOUSE_SHOW" }) do pcall(events.RegisterEvent, events, e) end
