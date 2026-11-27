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

---------------------------------------------------------------------------
-- /cchud bagprobe: the game's own bags, bank and item menus, looked at for a while as you use them: which menu
-- and item functions exist here, what the windows are made of, what their button lines say, which button the
-- game's cursor is on, and what opens (a menu of the game's: its tag and its words). Read only: nothing of the
-- game's is hooked, opened, changed or pressed. Kept in ControllerCamHUDDB.nativeProbe (the game writes it to
-- disk on /reload).
---------------------------------------------------------------------------
local L = ns.L
local B = { SECONDS = 90, EVERY = 0.25 }
ns.BagProbe = B

B.WINDOWS = { "ContainerFrameCombinedBags", "ContainerFrame1", "ContainerFrame2", "ContainerFrame3",
              "ContainerFrame4", "ContainerFrame5", "ContainerFrame6", "BankFrame", "BankPanel", "BankSlotsFrame",
              "ReagentBankFrame", "AccountBankPanel" }
B.TABLES = { "Menu", "MenuUtil", "MenuResponse", "C_Container", "C_Bank", "C_Item", "SmartNavigation" }
B.FUNCS = { "DressUpItemLink", "DressUpLink", "IsDressableItem", "DeleteCursorItem", "ClearCursor",
            "GetCursorInfo", "PurchaseSlot", "GetBankSlotCost", "GetNumBankSlots", "SortBags", "SortBankBags",
            "GetMouseFoci", "GetMouseFocus", "UIDropDownMenu_Initialize", "ToggleDropDownMenu",
            "SmartNavigation_AddJumpNavigationOverride" }

local function Call(f, method, ...)
    local fn = type(f) == "table" and f[method]
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn, f, ...)
    if ok then return ns.Plain(v) end
end

local function Object(v)
    return type(v) == "table" and type(v.GetObjectType) == "function"
end

local function Forbidden(f) return Call(f, "IsForbidden") == true end

-- The names of a table's functions, and of the parts it holds, in order
local function Members(t)
    local funcs, parts = {}, {}
    if type(t) ~= "table" then return "", "" end
    for k, v in pairs(t) do
        if type(k) == "string" then
            if type(v) == "function" then funcs[#funcs + 1] = k
            elseif Object(v) then parts[#parts + 1] = k .. "=" .. tostring(Call(v, "GetObjectType")) end
        end
    end
    table.sort(funcs)
    table.sort(parts)
    return table.concat(funcs, " "), table.concat(parts, " ")
end

local function Name(f)
    return tostring(Call(f, "GetName") or "(unnamed " .. tostring(Call(f, "GetObjectType")) .. ")")
end

-- Every word shown in a frame and its parts, and the pictures beside them (a button line's icons)
local function Words(f, out, depth)
    if #out >= 60 or depth > 5 or not Object(f) or Forbidden(f) then return out end
    if type(f.GetRegions) == "function" then
        local ok, regions = pcall(function() return { f:GetRegions() } end)
        for _, r in ipairs(ok and regions or {}) do
            if Call(r, "IsShown") == true then
                local kind = Call(r, "GetObjectType")
                if kind == "FontString" then
                    local t = Call(r, "GetText")
                    if type(t) == "string" and t ~= "" then out[#out + 1] = t end
                elseif kind == "Texture" and depth > 0 then
                    local a = Call(r, "GetAtlas")
                    if type(a) == "string" and a:lower():find("gamepad") then out[#out + 1] = "<" .. a .. ">" end
                end
            end
        end
    end
    if type(f.GetChildren) == "function" then
        local ok, kids = pcall(function() return { f:GetChildren() } end)
        for _, c in ipairs(ok and kids or {}) do
            if Call(c, "IsShown") == true then Words(c, out, depth + 1) end
        end
    end
    return out
end

-- A window's button line (the game's "input legend"), by the places it was found at
local function Legends(window)
    local found = {}
    for _, key in ipairs({ "gamepadFooter", "footer", "Footer" }) do
        local footer = rawget(window, key)
        local legend = type(footer) == "table" and rawget(footer, "inputLegend") or nil
        if Object(legend) then found[key .. ".inputLegend"] = legend end
    end
    for k, v in pairs(window) do
        if type(k) == "string" and k:lower():find("inputlegend$") and Object(v) then found[k] = v end
    end
    local name = Call(window, "GetName")
    local global = type(name) == "string" and rawget(_G, name .. "FooterinputLegend") or nil
    if Object(global) then found[name .. "FooterinputLegend"] = global end
    return found
end

local function Button(f)
    local d = { name = Name(f) }
    d.methods = (Members(f))
    local chain, p = {}, Call(f, "GetParent")
    for _ = 1, 6 do
        if type(p) ~= "table" then break end
        chain[#chain + 1] = Name(p)
        p = Call(p, "GetParent")
    end
    d.parents = table.concat(chain, " < ")
    for _, m in ipairs({ "GetID", "GetBagID", "GetBankTabID", "GetContainerSlotID" }) do
        if type(f[m]) == "function" then d[m] = tostring(Call(f, m)) end
    end
    if ns.ItemActions then
        local bag, slot = ns.ItemActions.SlotOf(f)
        d.slotFound = bag and (tostring(bag) .. " " .. tostring(slot)) or "none"
    end
    return d
end

-- A menu of the game's that is open: whatever says what it is (its tag), and its words
local function OpenMenu()
    local menus = rawget(_G, "Menu")
    local manager = type(menus) == "table" and type(menus.GetManager) == "function" and select(2, pcall(menus.GetManager)) or nil
    if type(manager) ~= "table" or Call(manager, "IsAnyMenuOpen") ~= true then return nil end
    local menu = Call(manager, "GetOpenMenu")
    if type(menu) ~= "table" then return { tag = "(open, no way to reach it)" } end
    local description = Call(menu, "GetMenuDescription") or rawget(menu, "menuDescription")
    local tag = type(description) == "table" and (Call(description, "GetTag") or rawget(description, "tag")) or nil
    local d = { tag = tostring(tag or "(no tag found)"), words = table.concat(Words(menu, {}, 0), " | ") }
    local funcs, parts = Members(menu)
    d.methods, d.parts = funcs, parts
    if type(description) == "table" then d.description = (Members(description)) end
    return d
end

---------------------------------------------------------------------------
-- The combined bags as they are laid out: every frame in the window and where it sits. For moving the icon that
-- heads each bag's run of slots out of the grid: which frames those are is read here, not guessed. Read only.
-- Taken while debug is on, a moment after the window opens (and by /cchud bagprobe), and kept in
-- ControllerCamHUDDB.bagLayout, so it is still there after the window is closed and the game reloaded.
---------------------------------------------------------------------------
local Layout = { WINDOW = "ContainerFrameCombinedBags", MAX = 240, DEPTH = 4, SETTLE = 2 }
ns.BagLayout = Layout

-- Everything a method answers, each value only if the game lets us read it
local function All(f, method, ...)
    local fn = type(f) == "table" and f[method]
    if type(fn) ~= "function" then return {} end
    local got = { pcall(fn, f, ...) }
    if not got[1] then return {} end
    local out = {}
    for i = 2, 8 do out[i - 1] = ns.Plain(got[i]) end
    return out
end

local function Number(v) return type(v) == "number" and ("%.0f"):format(v) or "?" end

-- What the parent calls a part: its own name, else the key it hangs from, else its place among its brothers
local function PartName(parent, f, i)
    local name = Call(f, "GetName")
    if type(name) == "string" then return name end
    for k, v in pairs(parent) do
        if v == f and type(k) == "string" then return k end
    end
    return "#" .. i
end

local function Picture(f)
    for _, key in ipairs({ "icon", "Icon", "IconTexture" }) do
        local t = f[key]
        if Object(t) then
            local art = Call(t, "GetAtlas") or Call(t, "GetTexture")
            if art then return tostring(art) end
        end
    end
end

local function Line(window, f, path)
    local bits = { path, tostring(Call(f, "GetObjectType")) }
    local left, top = Call(f, "GetLeft"), Call(f, "GetTop")
    local wl, wt = Call(window, "GetLeft"), Call(window, "GetTop")
    if type(left) == "number" and type(top) == "number" and type(wl) == "number" and type(wt) == "number" then
        bits[#bits + 1] = "at " .. Number(left - wl) .. "," .. Number(wt - top)      -- right and down of its corner
    end
    bits[#bits + 1] = Number(Call(f, "GetWidth")) .. "x" .. Number(Call(f, "GetHeight"))
    local p = All(f, "GetPoint", 1)
    if p[1] then
        local to = type(p[2]) == "table" and Name(p[2]) or tostring(p[2])
        bits[#bits + 1] = ("%s>%s:%s %s,%s"):format(tostring(p[1]), to, tostring(p[3]), Number(p[4]), Number(p[5]))
    end
    if All(f, "IsProtected")[1] == true then bits[#bits + 1] = "protected" end
    if Call(f, "IsShown") ~= true then bits[#bits + 1] = "hidden" end
    for _, m in ipairs({ "GetBagID", "GetID" }) do
        local v = Call(f, m)
        if v ~= nil then bits[#bits + 1] = m .. "=" .. tostring(v) end
    end
    if type(f.BagSlotOnClick) == "function" then bits[#bits + 1] = "(a bag's button)" end
    local art = Picture(f)
    if art then bits[#bits + 1] = "art=" .. art end
    return table.concat(bits, " ")
end

local function Walk(window, f, path, out, depth)
    local kids = {}
    if type(f.GetChildren) == "function" then
        local ok, list = pcall(function() return { f:GetChildren() } end)
        if ok then kids = list end
    end
    for i, c in ipairs(kids) do
        if #out >= Layout.MAX then return end
        if Object(c) and not Forbidden(c) then
            local here = path .. PartName(f, c, i)
            out[#out + 1] = Line(window, c, here)
            -- (a button's own parts say nothing about where things sit)
            local kind = Call(c, "GetObjectType")
            if depth < Layout.DEPTH and kind ~= "Button" and kind ~= "ItemButton" and kind ~= "CheckButton" then
                Walk(window, c, here .. ".", out, depth + 1)
            end
        end
    end
end

function Layout.Read(window)
    local out = { Line(window, window, "window") .. " parent=" .. Name(Call(window, "GetParent") or window) }
    Walk(window, window, "", out, 1)
    return out
end

-- One reading of each opening, once the game has had a moment to lay it out
function Layout:Watch()
    local window = rawget(_G, self.WINDOW)
    if not Object(window) or Forbidden(window) or Call(window, "IsShown") ~= true then
        self.looks = nil
        return
    end
    self.looks = (self.looks or 0) + 1
    if self.looks == self.SETTLE then self:Keep(window) end
end

function Layout:Keep(window)
    ns.db.bagLayout = { when = date and date("%Y-%m-%d %H:%M:%S") or tostring(time()), lines = self.Read(window) }
end

function B:Start()
    local out ={ when = date and date("%Y-%m-%d %H:%M:%S") or tostring(time()), exists = {}, tables = {},
                  windows = {}, legends = {}, cursor = {}, menus = {}, opened = {}, errors = {} }
    ns.db.nativeProbe = out
    self.out, self.left, self.since, self.had = out, self.SECONDS, 0, {}
    local function section(name, fn)
        local ok, err = pcall(fn)
        if not ok then out.errors[#out.errors + 1] = name .. ": " .. tostring(err) end
    end
    section("functions", function()
        for _, name in ipairs(self.FUNCS) do out.exists[name] = type(rawget(_G, name)) end
        for _, name in ipairs(self.TABLES) do
            local t = rawget(_G, name)
            out.tables[name] = type(t) == "table" and (Members(t)) or ("(" .. type(t) .. ")")
        end
        local menus = rawget(_G, "Menu")
        for _, name in ipairs({ "ModifyMenu", "OpenMenu", "GetManager", "PrintOpenMenuTags", "GetOpenMenuTags" }) do
            out.exists["Menu." .. name] = type(menus) == "table" and type(menus[name]) or "nil"
        end
        local util = rawget(_G, "MenuUtil")
        out.exists["MenuUtil.CreateContextMenu"] = type(util) == "table" and type(util.CreateContextMenu) or "nil"
    end)
    -- what is on screen already: what turns up after this is what your presses opened
    section("screen", function()
        for _, f in ipairs({ UIParent:GetChildren() }) do
            if Call(f, "IsShown") == true then self.had[f] = true end
        end
    end)
    self.frame:SetScript("OnUpdate", self.tick)
    ns.Say(L["Looking at your bags and bank for %d seconds: open them, point at items, open the game's own item menu. Then type /reload."]:format(self.SECONDS))
end

local function Count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

function B:Look()
    local out = self.out
    Layout:Watch()
    for _, name in ipairs(self.WINDOWS) do
        local window = rawget(_G, name)
        if Object(window) and not Forbidden(window) and Call(window, "IsShown") == true then
            if not out.windows[name] then
                local funcs, parts = Members(window)
                out.windows[name] = { methods = funcs, parts = parts, strata = tostring(Call(window, "GetFrameStrata")),
                                      words = table.concat(Words(window, {}, 0), " | ") }
            end
            for key, legend in pairs(Legends(window)) do
                if Call(legend, "IsShown") == true then
                    local line = table.concat(Words(legend, {}, 1), " | ")
                    if line ~= "" and Count(out.legends) < 60 then out.legends[name .. " " .. key .. ": " .. line] = true end
                end
            end
        end
    end
    local nav = rawget(_G, "SmartNavigation")
    local button = type(nav) == "table" and Call(nav, "GetCurrentButton") or nil
    if Object(button) and not Forbidden(button) then
        local d = Button(button)
        local key = d.name .. " in " .. d.parents
        if not out.cursor[key] and Count(out.cursor) < 25 then out.cursor[key] = d end
    end
    local menu = OpenMenu()
    if menu then
        local key = menu.tag .. ": " .. tostring(menu.words)
        if not out.menus[key] and Count(out.menus) < 20 then
            out.menus[key] = menu
            ns.Note("bagprobe: a menu opened: %s", key)
        end
    end
    -- anything else that opened (a menu of the game's that is not of its Menu kind)
    for _, f in ipairs({ UIParent:GetChildren() }) do
        if Object(f) and not self.had[f] and not Forbidden(f) and Call(f, "IsShown") == true
            and Count(out.opened) < 40 then
            self.had[f] = true
            local name = Name(f)
            if not name:find("^ControllerCam") then
                local funcs = Members(f)
                out.opened[#out.opened + 1] = { name = name, methods = funcs, words = table.concat(Words(f, {}, 0), " | ") }
            end
        end
    end
end

function B:Stop()
    self.frame:SetScript("OnUpdate", nil)
    if not self.out then return end
    local out = self.out
    self.out = nil
    ns.Say(L["Done looking: %d windows, %d button lines, %d menus. Type /reload so the game writes it to disk."]:format(
        Count(out.windows), Count(out.legends), Count(out.menus)))
end

B.frame = CreateFrame("Frame")
B.tick = ns.Protect(function(_, elapsed)
    B.left, B.since = B.left - elapsed, B.since + elapsed
    if B.since >= B.EVERY then
        B.since = 0
        if B.out then B:Look() end
    end
    if B.left <= 0 then B:Stop() end
end)

ns.RegisterCommand("bagprobe", function() B:Start() end, "/cchud bagprobe",
    "look at the game's own bags, bank and item menus for a while, for troubleshooting")
