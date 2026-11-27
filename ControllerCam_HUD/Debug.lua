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

-- Why the game refuses: its own code read a value that an addon wrote, and from then on it is not trusted
-- with what only the game may do. The game can say of any value who wrote it last (issecurevariable), so the
-- first time something is refused, everything of the gamepad interface is asked about once: its tables and
-- the frames' own fields, and every global of the game's that carries our name. Only looked at; nothing is
-- called and nothing is written.
D.SUSPECTS = { "Gamepad", "SmartNav", "FrameControls", "BindingSet", "InputPrompt", "ActionBar", "Tooltip", "Popup",
               "UISpecialFrames", "UIPanelWindows", "UIMenus", "Merchant" }
D.tainted, D.windows = {}, {}
local function OurName(name)
    return name:find("^ControllerCam") or name:find("^CCHUD") or name:find("^SLASH_CCHUD") or name:find("^SLASH_CONTROLLERCAM")
        or name:find("^BINDING_[%u]+_CCHUD") or name:find("^BINDING_[%u]+_CONTROLLERCAM")
end
function D.Tainted()
    local out = {}
    if type(issecurevariable) ~= "function" then return { "the game cannot say who wrote a value" } end
    local tables, checked = 0, 0
    local function Row(text)
        if #out < 80 then out[#out + 1] = text end
    end
    local function Look(t, label)
        tables = tables + 1
        for k in pairs(t) do
            if type(k) == "string" then
                checked = checked + 1
                local ok, secure, by = pcall(issecurevariable, t, k)
                if ok and not secure then Row(("%s.%s (written by %s)"):format(label, k, tostring(by))) end
            end
        end
    end
    for name, v in pairs(_G) do
        if type(name) == "string" then
            checked = checked + 1
            local ok, secure, by = pcall(issecurevariable, name)
            if ok and not secure and ns.IsOurAddon(by) and not OurName(name) then
                Row(("global %s (written by %s)"):format(name, tostring(by)))
            end
            if type(v) == "table" and tables < 4000 and not OurName(name) then
                for _, word in ipairs(D.SUSPECTS) do
                    if name:find(word, 1, true) then
                        pcall(Look, v, name)
                        break
                    end
                end
            end
        end
    end
    table.sort(out)
    table.insert(out, 1, ("%d values asked about in %d tables: %d not the game's own"):format(checked, tables, #out))
    return out
end

-- And then every other table the game keeps under a name, a few hundred a frame so the game does not stall:
-- what carries our name there is added to the list (D.tainted) as it is found.
D.CHUNK = 300
function D.TaintedEverywhere()
    if type(issecurevariable) ~= "function" or D.sweeping then return end
    D.sweeping = true
    local names = {}
    for name, v in pairs(_G) do
        if type(name) == "string" and type(v) == "table" and not OurName(name) then
            local suspect = false
            for _, word in ipairs(D.SUSPECTS) do
                if name:find(word, 1, true) then suspect = true; break end
            end
            if not suspect then names[#names + 1] = name end
        end
    end
    local at, found, checked = 0, 0, 0
    local function Step()
        for _ = 1, D.CHUNK do
            at = at + 1
            local name = names[at]
            if not name then
                D.sweeping = false
                D.tainted[#D.tainted + 1] = ("everywhere else: %d values asked about in %d tables: %d not the game's own"):format(
                    checked, #names, found)
                return
            end
            local t = _G[name]
            if type(t) == "table" then
                pcall(function()
                    for k in pairs(t) do
                        if type(k) == "string" or type(k) == "number" then
                            checked = checked + 1
                            local ok, secure, by = pcall(issecurevariable, t, k)
                            if ok and not secure and ns.IsOurAddon(by) then
                                found = found + 1
                                if found <= 40 then
                                    D.tainted[#D.tainted + 1] = ("%s[%s] (written by %s)"):format(name, tostring(k), tostring(by))
                                end
                            end
                        end
                    end
                end)
            end
        end
        C_Timer.After(0.02, Step)
    end
    Step()
end

-- What was open at that moment: the game's windows and ours, and what the pointer was on
function D.Windows()
    local out = {}
    for _, list in ipairs({ _G.UISpecialFrames or {}, _G.UIMenus or {} }) do
        for _, name in ipairs(list) do
            local f = _G[name]
            if type(f) == "table" and f.IsShown then
                local ok, shown = pcall(f.IsShown, f)
                if ok and shown == true then out[#out + 1] = name end
            end
        end
    end
    if type(_G.UIPanelWindows) == "table" then
        for name in pairs(_G.UIPanelWindows) do
            local f = _G[name]
            if type(f) == "table" and f.IsShown then
                local ok, shown = pcall(f.IsShown, f)
                if ok and shown == true then out[#out + 1] = name end
            end
        end
    end
    local focus = GetMouseFoci and select(2, pcall(GetMouseFoci)) or nil
    if type(focus) == "table" then
        for _, f in ipairs(focus) do
            local ok, name = pcall(function() return f.GetDebugName and f:GetDebugName() or f:GetName() end)
            if ok and type(name) == "string" then out[#out + 1] = "pointer on " .. name:sub(1, 80) end
        end
    end
    table.sort(out)
    return out
end

-- What the game refused us: an action only its own interface may take, or one that our code had touched.
-- The game names what was called; kept here so it can be read afterwards.
D.refused = {}
local guard = CreateFrame("Frame")
pcall(guard.RegisterEvent, guard, "ADDON_ACTION_FORBIDDEN")
pcall(guard.RegisterEvent, guard, "ADDON_ACTION_BLOCKED")
guard:SetScript("OnEvent", function(_, event, addon, what)
    if not ns.IsOurAddon(addon) then return end          -- (the HUD or one of its modules)
    local line = ("%s %s: %s"):format(date and date("%H:%M:%S") or "", event == "ADDON_ACTION_FORBIDDEN" and "forbidden" or "blocked",
        tostring(what))
    if debugstack and (D.traced or 0) < 4 then              -- the first few: the path that led to it
        D.traced = (D.traced or 0) + 1
        local ok, stack = pcall(debugstack, 2, 30, 0)
        local from, path = {}, {}
        if ok and type(stack) == "string" then
            for file, n in stack:gmatch("ControllerCam_HUD[/\\]([%w_]+%.lua)[^:\n]*:(%d+)") do
                if file ~= "Debug.lua" then from[#from + 1] = file .. ":" .. n end
            end
            for row in stack:gmatch("[^\n]+") do              -- the game's own lines too: where it was when it refused
                if #path < 24 and not row:find("Debug%.lua") then
                    path[#path + 1] = (row:gsub("^%s+", ""):gsub("Interface[/\\]", ""):gsub("AddOns/Blizzard_", "B_"):sub(1, 120))
                end
            end
        end
        if #from > 0 then line = line .. " from " .. table.concat(from, " < ") end
        if #path > 0 then line = line .. " | path: " .. table.concat(path, " < ") end
    end
    D.refused[#D.refused + 1] = line
    if #D.refused > 30 then table.remove(D.refused, 1) end
    ns.Note("refused: %s", line)
    if not D.asked and ns.db and ns.db.debug then          -- once: what was open, and whose values the game read
        D.asked = true
        local ok, windows = pcall(D.Windows)
        D.windows = ok and windows or { tostring(windows) }
        local function Ask()
            local ok2, found = pcall(D.Tainted)
            D.tainted = ok2 and found or { tostring(found) }
            for i = 1, math.min(#D.tainted, 12) do ns.Note("not the game's own: %s", D.tainted[i]) end
            if C_Timer and C_Timer.After then pcall(D.TaintedEverywhere) end
        end
        if C_Timer and C_Timer.After then C_Timer.After(0, Ask) else Ask() end
    end
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
    { "enemy casts", function() return ns.CastRoutes and ns.CastRoutes() or {} end },
    { "readouts", function() return ns.Readout and ns.Readout.Describe() or {} end },
    { "big moments", function() return ns.Moments and ns.Moments.Describe and ns.Moments.Describe() or {} end },
    { "cooldown callouts", function() return ns.Numbers and ns.Numbers.Soon and ns.Numbers.Soon.Describe() or {} end },
    { "campfire", function() return ns.Campfire and ns.Campfire.Describe() or {} end },
    { "stepped aside", function()                -- handlers that kept failing and were set aside for a while (Core.lua)
        local out = {}
        for where, t in pairs(ns.BREAKER.trips) do out[#out + 1] = ("%s: %d times"):format(tostring(where), t.count) end
        table.sort(out)
        return out
    end },
    { "reticle", function() return ns.Reticle and ns.Reticle.Describe() or {} end },
    { "professions", function() return ns.Professions and ns.Professions.Describe() or {} end },
    { "specs", function() return ns.Vendor and ns.Vendor.DescribeSpecs and ns.Vendor.DescribeSpecs() or {} end },
    { "damage meter", function() return ns.Skin and ns.Skin.MeterDescribe and ns.Skin.MeterDescribe() or {} end },
    { "aura rows", function() return ns.AuraWidgets and ns.AuraWidgets.Describe and { ns.AuraWidgets.Describe() } or {} end },
    { "tainted", function() return D.tainted end },
    { "open when refused", function() return D.windows end },
    { "sizes", function() return ns.Sizes and ns.Sizes.Describe() or {} end },
    { "screen", Screen },
    { "bindings", Bindings },
    { "pad", function() return ns.PadButtons and ns.PadButtons.Report() or {} end },
    { "form sets", function() return ns.FormSets and ns.FormSets.Describe() or {} end },
    { "rest", Resting },
    { "fishing", function()
        local out = {}
        for _, part in ipairs({ ns.Fishing, ns.FishLog, ns.FishPanel, ns.FishGame }) do
            if part and part.Describe then out[#out + 1] = part.Describe() end
        end
        return out
    end },
    { "quests", function() return ns.Quests and ns.Quests.Describe and { ns.Quests.Describe() } or {} end },
    { "travel", function()
        local out = {}
        for _, part in ipairs({ ns.Flights, ns.FlightGame, ns.Ride, ns.Hydrate }) do
            if part and part.Describe then out[#out + 1] = part.Describe() end
        end
        return out
    end },
    { "breath", function() return ns.Breath and { ns.Breath.Describe() } or {} end },
    { "padicons", function() return ns.PadIcons and { ns.PadIcons.Describe() } or {} end },
    { "auction", function() return ns.AuctionPanel and ns.AuctionPanel.Describe() or {} end },
    { "narrative", function() return ns.Narrative and { ns.Narrative.Describe() } or {} end },
    { "transmog", function() return ns.TransmogSets and ns.TransmogSets.Describe() or {} end },
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
        local P = ns.PadButtons                           -- the gamepad wheels' layer, as each last opened
        for _, name in ipairs(P and P.opened and P.FLYOUTS or {}) do
            if P.opened[name] then out[#out + 1] = P.opened[name] end
        end
        return out
    end },
    { "item actions", function() return ns.ItemActions and ns.ItemActions.Describe() or {} end },
    { "slow", function() return D.Slow() end },
    { "modules", function() return ns.ModuleList and ns.ModuleList.Describe() or {} end },
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
        -- (frames only: a wheel's flashing art has "Flyout" in its name too, and its blinking filled the notes)
        local okK, kind = false, nil
        if type(f) == "table" and f.GetObjectType then okK, kind = pcall(f.GetObjectType, f) end
        local shown = not (okK and (kind == "Texture" or kind == "FontString")) and ns.ShownPlain(f)
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

---------------------------------------------------------------------------
-- Long frames: a moment the game stood still (a frame that took D.HITCH or more), kept with how much of it was
-- the HUD's own work and which of its handlers took the most. Told by /cchud slow, and kept in the reports.
-- Always on: it only reads the game's clock.
---------------------------------------------------------------------------
D.HITCH = 0.4
D.hitches = {}
local hitch = CreateFrame("Frame")
local was, wasTop, wasWhere = 0, 0, nil
hitch:SetScript("OnUpdate", function(_, dt)
    local S = ns.spent
    if not S then return end
    if type(dt) == "number" and dt >= D.HITCH then
        local top, where = S.top, S.topWhere
        if wasTop > top then top, where = wasTop, wasWhere end
        local line = ("%.1f the game stood still %.0f ms; the HUD's part %.0f ms (most: %s, %.0f ms)%s"):format(
            GetTime and GetTime() or 0, dt * 1000, S.now + was, tostring(where or "-"), top,
            ns.MapOpen() and "; the map open" or "")
        D.hitches[#D.hitches + 1] = line
        if #D.hitches > 20 then table.remove(D.hitches, 1) end
        ns.Note("%s", line)
    end
    was, wasTop, wasWhere = S.now, S.top, S.topWhere
    S.now, S.top, S.topWhere = 0, 0, nil
end)

-- What the game's own addon profiler says of the camera, the HUD and each of the HUD's modules loaded, where it has one
function D.Profiler()
    local P = C_AddOnProfiler
    if type(P) ~= "table" or type(P.GetAddOnMetric) ~= "function" then return { "the game has no addon profiler" } end
    local metrics = Enum and Enum.AddOnProfilerMetric
    local out = {}
    local addons = { "ControllerCam", "ControllerCam_HUD" }
    for _, m in ipairs(ns.ModuleList and ns.ModuleList.list or {}) do
        if m.state == "loaded" then addons[#addons + 1] = m.addon end
    end
    for _, addon in ipairs(addons) do
        local parts = {}
        for name, id in pairs(type(metrics) == "table" and metrics or {}) do
            local ok, v = pcall(P.GetAddOnMetric, addon, id)
            if ok and type(v) == "number" and not ns.IsSecret(v) then parts[#parts + 1] = ("%s %.2f"):format(name, v) end
        end
        table.sort(parts)
        out[#out + 1] = addon .. ": " .. (#parts > 0 and table.concat(parts, ", ") or "nothing told")
    end
    return out
end

function D.Slow()
    local out = {}
    for _, line in ipairs(D.hitches) do out[#out + 1] = line end
    for _, line in ipairs(ns.spent and ns.spent.calls or {}) do out[#out + 1] = "slow call " .. line end
    for _, line in ipairs(D.Profiler()) do out[#out + 1] = "profiler " .. line end
    return out
end

ns.RegisterCommand("slow", function()
    if #D.hitches == 0 then
        ns.Say(L["The game has not stood still since you logged in."])
    else
        ns.Say(L["Moments the game stood still, and the HUD's part in each:"])
        for i = math.max(1, #D.hitches - 7), #D.hitches do print("  " .. D.hitches[i]) end
    end
    local calls = ns.spent and ns.spent.calls or {}
    if #calls > 0 then
        ns.Say(L["The HUD's slowest moments:"])
        for i = math.max(1, #calls - 7), #calls do print("  " .. calls[i]) end
    end
    for _, line in ipairs(D.Profiler()) do print("  " .. line) end
end, "/cchud slow", "the moments the game stood still since you logged in, and how much of each was the HUD's own work")

-- /cchud classprobe: what the game keeps secret about your target's class, and which of its own ways can still
-- show a class it keeps secret (a bar's colour, a name's colour, an icon). Each is tried once, by hand: a refused
-- try counts as an addon error, so this is never run by itself. The answers are kept (ns.db.classProbe).
ns.RegisterSaved("classProbe", function(old) return type(old) == "table" and old or nil end)
function D.ClassProbe(unit)
    unit = unit or "target"
    local out = {}
    local function say(k, v) out[#out + 1] = ("%s: %s"):format(k, tostring(v)) end
    local function kind(v) return ns.IsSecret(v) and "secret" or (v == nil and "nil" or type(v)) end
    local okP, isPlayer = pcall(UnitIsPlayer, unit)
    say("UnitIsPlayer", okP and kind(isPlayer) or "error")
    local okC, _, class = pcall(UnitClass, unit)
    say("UnitClass", okC and kind(class) or "error")
    local okG, guid = pcall(UnitGUID, unit)
    say("UnitGUID", okG and kind(guid) or "error")
    local okN, name = pcall(UnitName, unit)
    say("UnitName", okN and kind(name) or "error")
    if okC and class ~= nil then
        local getColor = C_ClassColor and C_ClassColor.GetClassColor
        local color
        if getColor then
            local ok, c = pcall(getColor, class)
            say("C_ClassColor.GetClassColor", ok and kind(c) or ("refused: " .. tostring(c)))
            color = ok and c or nil
        end
        local r, g, b
        if color and color.GetRGB then
            local ok, cr, cg, cb = pcall(color.GetRGB, color)
            say("color:GetRGB", ok and kind(cr) or "refused")
            if ok then r, g, b = cr, cg, cb end
        end
        if r ~= nil then
            local bar = CreateFrame("StatusBar")
            local okB = pcall(bar.SetStatusBarColor, bar, r, g, b)
            say("StatusBar:SetStatusBarColor(class)", okB and "works" or "refused")
            local fs = UIParent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            local okF = pcall(fs.SetTextColor, fs, r, g, b)
            say("FontString:SetTextColor(class)", okF and "works" or "refused")
        end
        local atlasFn = GetClassAtlas or (C_Texture and C_Texture.GetClassAtlas)
        if atlasFn then
            local ok, atlas = pcall(atlasFn, class)
            say("GetClassAtlas", ok and kind(atlas) or "refused")
            if ok and atlas ~= nil then
                local t = UIParent:CreateTexture()
                local okA = pcall(t.SetAtlas, t, atlas)
                say("Texture:SetAtlas(class atlas)", okA and "works" or "refused")
            end
        else
            say("GetClassAtlas", "missing")
        end
    end
    if ns.db then ns.db.classProbe = { when = date and date("%Y-%m-%d %H:%M") or "?", lines = out } end
    return out
end
ns.RegisterCommand("classprobe", function()
    if not UnitExists("target") then ns.Say(L["Target something first."]); return end
    for _, line in ipairs(D.ClassProbe("target")) do print("  " .. line) end
end, "/cchud classprobe", "what the game keeps secret about your target's class, and which ways can still show it (run once, on an enemy player in a battleground)")

local events = CreateFrame("Frame")
local since = 0
events:SetScript("OnUpdate", function(_, dt)
    if not (ns.db and ns.db.debug) then return end
    since = since + dt
    if since < 0.25 then return end
    since = 0
    local ok, err = pcall(Wheels)
    if not ok then ns.Error(err) end
    if ns.BagLayout then                                     -- the combined bags' layout, as they last opened
        ok, err = pcall(ns.BagLayout.Watch, ns.BagLayout)
        if not ok then ns.Error(err) end
    end
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
