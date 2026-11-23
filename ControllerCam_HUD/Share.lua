-- ControllerCam HUD: share your whole setup as one line of text.
-- Export writes every setting, which frames are on, where they sit, and your vendor rules and marks into a
-- line you can copy; import reads such a line back. The same line carries ControllerCam's camera setup (when
-- that addon is there) and the game's own layout (Edit Mode), so one line is the whole screen. The line is
-- plain data: importing only ever sets known settings to values of the right kind and range, hands the
-- camera's part to ControllerCam and the layout to the game (each checks its own), and never runs anything.
-- /cchud export, /cchud import, or the buttons in the options.

local ADDON, ns = ...
local L = ns.L

local SH = {}
ns.Share = SH

local PREFIX = "CCHUD1:"

local function Esc(s) return (tostring(s):gsub("[%%;=]", function(c) return ("%%%02X"):format(c:byte()) end)) end
local function Unesc(s) return (s:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)) end

local function Value(v)
    if type(v) == "boolean" then return v and "b1" or "b0" end
    if type(v) == "number" then return "n" .. (v == math.floor(v) and ("%d"):format(v) or ("%.4f"):format(v)) end
    return "s" .. Esc(v)
end

local function Parse(text)
    local kind, rest = text:sub(1, 1), text:sub(2)
    if kind == "b" then return rest == "1" end
    if kind == "n" then return tonumber(rest) end
    if kind == "s" then return Unesc(rest) end
end

-- Every plain setting there is: { key = { default, min, max } }
-- (a setting registered with share = false stays on your machine)
local function Known()
    local known, private = {}, {}
    for _, def in ipairs(ns.settings) do
        if def.key and def.share == false then
            private[def.key] = true
        elseif def.key and def.default ~= nil and type(def.default) ~= "table" then
            known[def.key] = { default = def.default, min = def.min, max = def.max }
        end
    end
    for key, value in pairs(ns.DEFAULTS) do
        if not known[key] and not private[key] and type(value) ~= "table" then known[key] = { default = value } end
    end
    -- and those of the modules that are not loaded (switched off): kept, carried and taken all the same
    for key, default in pairs(ns.ModuleList and ns.ModuleList.UnloadedKeys() or {}) do
        if not known[key] then known[key] = { default = default } end
    end
    return known
end

function SH.Export()
    local db = ns.db
    local parts = {}
    local function put(path, v)
        if v ~= nil then parts[#parts + 1] = Esc(path) .. "=" .. Value(v) end
    end
    for key in pairs(Known()) do
        local v = db[key]
        if type(v) == "boolean" or type(v) == "number" or type(v) == "string" then put(key, v) end
    end
    for unit, on in pairs(db.units or {}) do put("units." .. unit, on) end
    for frame, p in pairs(db.pos or {}) do
        if type(p) == "table" then put("pos." .. frame .. ".x", p.x); put("pos." .. frame .. ".y", p.y) end
    end
    local sell = db.sell or {}
    for _, key in ipairs({ "auto", "gear", "deposit" }) do put("sell." .. key, sell[key]) end
    for _, list in ipairs({ "junk", "keep", "bank" }) do
        for id in pairs(sell[list] or {}) do put("sell." .. list .. "." .. id, true) end
    end
    table.sort(parts)
    return PREFIX .. table.concat(parts, ";")
end

-- Reads a line back. Returns how many values were taken and how many were left out (unknown or wrong).
function SH.Import(text)
    if type(text) ~= "string" then return nil end
    text = text:gsub("%s", "")
    if text:sub(1, #PREFIX) ~= PREFIX then return nil end
    local db, known = ns.db, Known()
    local taken, skipped = 0, 0
    local frames = { tot = true }
    for unit in pairs(db.units or {}) do frames[unit] = true end
    for item in text:sub(#PREFIX + 1):gmatch("[^;]+") do
        local rawPath, rawValue = item:match("^(.-)=(.+)$")
        local path, v = rawPath and Unesc(rawPath), rawValue and Parse(rawValue)
        local ok = false
        if path and v ~= nil then
            local def = known[path]
            if def and type(v) == type(def.default) then
                if type(v) == "number" then v = ns.Clamp(v, def.min or -1e6, def.max or 1e6) end
                db[path] = v
                ok = true
            else
                local unit = path:match("^units%.(%w+)$")
                local frame, axis = path:match("^pos%.(%w+)%.([xy])$")
                local sellKey = path:match("^sell%.(%a+)$")
                local list, id = path:match("^sell%.(%a+)%.(%d+)$")
                if unit and db.units[unit] ~= nil and type(v) == "boolean" then
                    db.units[unit] = v
                    ok = true
                elseif frame and frames[frame] and type(v) == "number" then
                    db.pos[frame] = db.pos[frame] or {}
                    db.pos[frame][axis] = ns.Clamp(v, -3000, 3000)
                    ok = true
                elseif sellKey and (sellKey == "auto" or sellKey == "gear" or sellKey == "deposit") and type(v) == "boolean" then
                    db.sell[sellKey] = v
                    ok = true
                elseif list and (list == "junk" or list == "keep" or list == "bank") and v == true then
                    db.sell[list][tonumber(id)] = true
                    ok = true
                end
            end
        end
        if ok then taken = taken + 1 else skipped = skipped + 1 end
    end
    for frame, p in pairs(db.pos) do                    -- a position needs both halves
        if type(p) ~= "table" or type(p.x) ~= "number" or type(p.y) ~= "number" then db.pos[frame] = nil end
    end
    ns.Apply()
    if ns.UnitFrames and ns.UnitFrames.ApplyLook then ns.UnitFrames:ApplyLook() end
    if ns.RefreshOptions then ns.RefreshOptions() end
    return taken, skipped
end

---------------------------------------------------------------------------
-- The whole setup in one line:   CCUI1:<checksum>:<part>|<part>...   each part <name>=<text>
--   hud      the HUD's settings (a CCHUD1 line as above)
--   cam      ControllerCam's camera setup, as that addon writes it
--   game     modern | classic: the game's built-in layout that was active
--   lay, layname   or one of your own layouts, as the game's Edit Mode writes it, and its name
-- The checksum (Adler-32 of everything after it) catches a line that was cut short or changed.
---------------------------------------------------------------------------
local ALL, ALL_VERSION = "CCUI", 1
local MAX_LINE, MAX_LAYOUT = 60000, 12000
SH.MAX_LAYOUTS = 5                                   -- the game keeps this many of your own layouts per kind

local function Sum(s)
    local a, b = 1, 0
    for i = 1, #s do
        a = (a + s:byte(i)) % 65521
        b = (b + a) % 65521
    end
    return ("%08x"):format(b * 65536 + a)
end
SH.Sum = Sum

-- A part's text without anything a pasted line could lose or gain: no spaces, no line breaks, no "|"
local function Pack(s)
    return (tostring(s):gsub("[%%|~%c\128-\255]", function(c) return ("%%%02X"):format(c:byte()) end):gsub(" ", "~"))
end
local function Unpack(s) return Unesc((s:gsub("~", " "))) end

-- The game's layout functions, when this client has every one that is asked for
local function EditMode(...)
    local E = _G.C_EditMode
    if type(E) ~= "table" then return nil end
    for i = 1, select("#", ...) do
        if type(E[(select(i, ...))]) ~= "function" then return nil end
    end
    return E
end

-- How many built-in layouts come before your own in the game's numbering
function SH.BuiltinLayouts()
    local n = 0
    for _ in pairs(Enum and Enum.EditModePresetLayouts or {}) do n = n + 1 end
    return n > 0 and n or 2
end

-- The name of the game's n-th built-in layout, in small letters ("modern", "classic", "gamepad" on this client)
function SH.BuiltinName(n)
    for name, value in pairs(Enum and Enum.EditModePresetLayouts or {}) do
        if type(name) == "string" and value == n - 1 then return name:lower() end
    end
    return n == 2 and "classic" or "modern"
end

-- The game's layout that is active now: { builtin = its name }, or { name, text } for one of yours
function SH.Layout()
    local E = EditMode("GetLayouts", "ConvertLayoutInfoToString")
    if not E then return nil end
    local ok, all = pcall(E.GetLayouts)
    if not ok or type(all) ~= "table" or type(all.activeLayout) ~= "number" then return nil end
    local own = all.activeLayout - SH.BuiltinLayouts()
    if own < 1 then
        return { builtin = SH.BuiltinName(all.activeLayout) }
    end
    local info = type(all.layouts) == "table" and all.layouts[own]
    if type(info) ~= "table" then return nil end
    local ok2, text = pcall(E.ConvertLayoutInfoToString, info)
    if not ok2 or type(text) ~= "string" or text == "" or #text > MAX_LAYOUT then return nil end
    return { name = type(info.layoutName) == "string" and info.layoutName or "", text = text }
end

-- Adds a layout to the game's own (or replaces yours of the same name). The game reads the text itself; a
-- text it does not accept changes nothing. Returns true, the name, and whether it is the active layout.
-- Choosing a layout is the player's to do, in Edit Mode: the game refuses that to addons (seen in the game:
-- "blocked from an action only available to the Blizzard UI"), so it is never tried here.
function SH.SetLayout(name, text)
    if InCombatLockdown() then return false end
    local E = EditMode("GetLayouts", "SaveLayouts", "ConvertStringToLayoutInfo")
    if not E or type(text) ~= "string" or text == "" or #text > MAX_LAYOUT or text:find("[^\32-\126]") then
        ns.Note("layout: not tried (%s)", E and "the text is not one" or "the game lacks the functions")
        return false
    end
    local ok, info = pcall(E.ConvertStringToLayoutInfo, text)
    local ok2, all = pcall(E.GetLayouts)
    if not (ok and ok2 and type(info) == "table" and type(all) == "table" and type(all.layouts) == "table") then
        ns.Note("layout: the game did not take the text (%s / %s)", tostring(ok and type(info) or info),
            tostring(ok2 and type(all) or all))
        return false
    end
    name = type(name) == "string" and name:gsub("[|%c]", "") or ""
    if name == "" or #name > 60 then name = "ControllerCam" end
    local kind = Enum and Enum.EditModeLayoutType and Enum.EditModeLayoutType.Account or 1
    info.layoutName, info.layoutType = name, kind
    local at, count, last = nil, 0, 0                -- yours for the whole account come first, in a row
    for i, layout in ipairs(all.layouts) do
        if type(layout) == "table" and layout.layoutType == kind then
            count, last = count + 1, i
            if layout.layoutName == name then at = i end
        end
    end
    if at then
        all.layouts[at] = info
    else
        if count >= SH.MAX_LAYOUTS then
            ns.Note("layout: the game already keeps %d of yours", count)
            return false
        end
        at = last + 1
        table.insert(all.layouts, at, info)
    end
    local index = SH.BuiltinLayouts() + at
    local saved, why = pcall(E.SaveLayouts, all)
    if not saved then
        ns.Note("layout: saving failed (%s)", tostring(why))
        return false
    end
    local okNow, now = pcall(E.GetLayouts)                   -- (a refused call says nothing: look for ourselves)
    local kept, active = false, okNow and type(now) == "table" and now.activeLayout or nil
    for _, layout in ipairs(okNow and type(now) == "table" and type(now.layouts) == "table" and now.layouts or {}) do
        if type(layout) == "table" and layout.layoutName == name then kept = true end
    end
    ns.Note("layout: '%s' as number %d: the game %s it, active is now %s", name, index, kept and "has" or "does not have",
        tostring(active))
    if not kept then return false end
    return true, name, active == index
end

-- Is a layout of this name among yours in the game's Edit Mode?
function SH.HasLayout(name)
    local E = EditMode("GetLayouts")
    if not E then return false end
    local ok, all = pcall(E.GetLayouts)
    for _, layout in ipairs(ok and type(all) == "table" and type(all.layouts) == "table" and all.layouts or {}) do
        if type(layout) == "table" and layout.layoutName == name then return true end
    end
    return false
end

function SH.ExportAll()
    local parts = { "hud=" .. Pack(SH.Export()) }
    local cam = _G.ControllerCam
    if type(cam) == "table" and type(cam.ExportSetup) == "function" then
        local ok, text = pcall(cam.ExportSetup)
        if ok and type(text) == "string" and text ~= "" then parts[#parts + 1] = "cam=" .. Pack(text) end
    end
    local layout = SH.Layout()
    if layout and layout.builtin then
        parts[#parts + 1] = "game=" .. layout.builtin
    elseif layout then
        parts[#parts + 1] = "layname=" .. Pack(layout.name)
        parts[#parts + 1] = "lay=" .. Pack(layout.text)
    end
    local body = table.concat(parts, "|")
    return ("%s%d:%s:%s"):format(ALL, ALL_VERSION, Sum(body), body)
end

-- Reads a line back: a whole setup, or the HUD's settings alone (as earlier versions wrote them). Returns
-- what happened: { taken, skipped, camera = true | false, cameraWhy, layout = its name | false } (camera and
-- layout stay nil when the line has no such part), or nil and "damaged" / "newer" for a line it cannot read.
function SH.ImportAll(text)
    if type(text) ~= "string" then return nil end
    text = text:gsub("%s", "")
    if text:sub(1, #PREFIX) == PREFIX then
        local taken, skipped = SH.Import(text)
        return { taken = taken, skipped = skipped }
    end
    if #text > MAX_LINE then return nil end
    local ver, sum, body = text:match("^" .. ALL .. "(%d+):(%x%x%x%x%x%x%x%x):(.+)$")
    if not ver then return nil end
    if tonumber(ver) > ALL_VERSION then return nil, "newer" end
    if Sum(body) ~= sum:lower() then return nil, "damaged" end
    local part = {}
    for item in body:gmatch("[^|]+") do
        local name, value = item:match("^(%a+)=(.*)$")
        if name then part[name] = Unpack(value) end
    end
    if not part.hud or part.hud:sub(1, #PREFIX) ~= PREFIX then return nil end

    local out = {}
    if part.game then                                            -- a built-in one: yours to choose in Edit Mode
        out.layout = false
    elseif part.lay then
        local ok, name, active = SH.SetLayout(part.layname, part.lay)
        out.layout, out.layoutActive = ok and name or false, active or false
    end
    out.taken, out.skipped = SH.Import(part.hud)
    if part.cam then
        local cam = _G.ControllerCam
        out.camera = false
        if type(cam) == "table" and type(cam.ImportSetup) == "function" then
            local ok, done, why = pcall(cam.ImportSetup, part.cam)
            out.camera = (ok and done) and true or false
            if ok and not done and type(why) == "string" then out.cameraWhy = why end
        end
    end
    return out
end

---------------------------------------------------------------------------
-- The boxes to copy from and paste into (the game's own dialogs)
---------------------------------------------------------------------------
local function Box(dialog) return dialog.editBox or dialog.EditBox end

local function Define()
    if SH.defined or not StaticPopupDialogs then return end
    SH.defined = true
    StaticPopupDialogs["CCHUD_EXPORT"] = {
        text = L["Your whole setup (HUD, camera and the game's layout): copy this line (Ctrl+C) to keep or share it."],
        button1 = OKAY or "OK", hasEditBox = true, editBoxWidth = 340, maxLetters = 0,
        OnShow = function(self)
            local box = Box(self)
            if box then box:SetText(SH.text or ""); box:HighlightText(); box:SetFocus() end
        end,
        EditBoxOnEscapePressed = function(box) box:GetParent():Hide() end,
        timeout = 0, whileDead = true, hideOnEscape = true,
    }
    StaticPopupDialogs["CCHUD_IMPORT"] = {
        text = L["Paste a line of HUD settings (Ctrl+V) and accept."],
        button1 = ACCEPT or "Accept", button2 = CANCEL or "Cancel", hasEditBox = true, editBoxWidth = 340,
        maxLetters = 0,
        OnAccept = function(self) SH.FromBox(Box(self)) end,
        EditBoxOnEnterPressed = function(box) SH.FromBox(box); box:GetParent():Hide() end,
        EditBoxOnEscapePressed = function(box) box:GetParent():Hide() end,
        timeout = 0, whileDead = true, hideOnEscape = true,
    }
end

function SH.FromBox(box)
    local got, why = SH.ImportAll(box and box:GetText())
    if not got then
        ns.Say(why == "damaged" and L["That line is damaged: copy it again, completely."]
            or why == "newer" and L["That line was made by a newer version: update the addon."]
            or L["That is not a line of HUD settings."])
        return
    end
    ns.Say(L["Settings imported: %d taken, %d left out."]:format(got.taken, got.skipped))
    if got.camera then
        ns.Say(L["The camera setup came along."])
    elseif got.camera == false then
        ns.Say(L["The camera setup was left as it is."] .. (got.cameraWhy and (" " .. got.cameraWhy) or ""))
    end
    if got.layout and got.layoutActive then
        ns.Say(L["The game's layout is now '%s'."]:format(got.layout))
    elseif got.layout then
        ns.Say(L["A layout named '%s' was added to the game's Edit Mode. Choose it there to use it (Game Menu > Edit Mode > Layout)."]:format(got.layout))
    elseif got.layout == false then
        ns.Say(L["The game's layout was left as it is."])
    end
end

function SH.ShowExport()
    Define()
    SH.text = SH.ExportAll()
    StaticPopup_Show("CCHUD_EXPORT")
end

function SH.ShowImport()
    if InCombatLockdown() then ns.Say(L["Not in combat."]); return end
    Define()
    StaticPopup_Show("CCHUD_IMPORT")
end

ns.RegisterCommand("export", function() SH.ShowExport() end, "/cchud export",
    "your settings as one line of text, to keep or share")
ns.RegisterCommand("import", function() SH.ShowImport() end, "/cchud import",
    "take settings from a line of text made by /cchud export")
