-- ControllerCam HUD: each form and stance its own actions on the gamepad bar.
-- The classic action bar swaps to another set of actions in bear or cat form, in a warrior's defensive or
-- berserker stance, in a rogue's stealth. The game's gamepad bar does it too, in its own way: its Stance Bar. The
-- game keeps eight gamepad actions for each stance (C_GamepadUI.GetFirstGamepadActionBarStorageSlotIndexForActiveStance:
-- bear form's from slot 281), and while you are in a stance its Stance Bar takes the place of one cluster of the
-- bar. Which cluster is the game's setting GamepadStanceBarOverride (Enum.GamepadStanceBarOverride: None,
-- Page1LeftBar, Page1RightBar, Page1BottomBar, Page2TopBar...). The game does the switching itself, in a fight
-- too; nothing of ours is in it.
--
-- What is missing in the game is only this: a form's stance bar starts with a couple of abilities at most, and
-- the setting is nowhere a player on a controller finds it. So here:
--   * the setting has a row in our options (the cluster of your first set: the left trigger's, the right
--     trigger's, both triggers', or off). It is the game's own setting, changed as its own menus would;
--   * the first time you shift into a form, out of combat, the empty buttons of its stance bar are filled with
--     that form's abilities, as you would drag them there. What is on it stays; what you take off later stays off.
--
-- Tried before this and given up, all seen in the game on 2026-11-27 (do not try them again):
--   * turning each bar button's "action" attribute from a secure state driver: the game's buttons don't read it;
--   * turning the game's page from the restricted environment (CallMethod "SetCurrentPage"): CallMethod runs the
--     method forced insecure, the bar's state is then tainted ("*** TaintForced ***") and the game refuses its own
--     SetPreferredGamepadInteractTarget (MainActionBarFrame.lua:373) until a /reload;
--   * the bar, its page unit, tracker and page switch have no secure paging attribute; the game has three sets
--     (slots 181, 209, 237, 28 each) and no storage for more.

local ADDON, ns = ...
local L = ns.L

local S = { STANCE_SLOTS = 8, CLUSTER_CVAR = "GamepadStanceBarOverride", notes = {}, skipped = {} }
ns.FormSets = S

local PAGE = "GamepadMainActionBarFramePageUnit"

local function G(name) return rawget(_G, name) end

-- (a call of the game's, quietly: every answer, or nothing when it fails)
local function Pass(ok, ...)
    if ok then return ... end
end
local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    return Pass(pcall(fn, ...))
end

local function Api() local api = G("C_GamepadUI"); return type(api) == "table" and api or nil end

-- Who you are, for what is kept for each character: "Name-Realm"
function S.Character()
    local name, realm = ns.Plain(Call(G("UnitName"), "player")), ns.Plain(Call(G("GetRealmName")))
    return tostring(name or "?") .. "-" .. tostring(realm or "")
end

-- This client has the game's stance bar: its storage for a stance, and its setting
function S.Available()
    local api = Api()
    return api ~= nil and type(api.GetFirstGamepadActionBarStorageSlotIndexForActiveStance) == "function"
        and ns.Plain(Call(G("GetCVar"), S.CLUSTER_CVAR)) ~= nil
end

---------------------------------------------------------------------------
-- The game's setting, in the options: which cluster of your first set a form's own actions stand in for
-- (1 None, 2 the left trigger's, 3 the right trigger's, 4 both triggers'; the game's values, as they are). A value
-- of another set (5-12, from the game's own menus) shows none chosen and is left alone until you choose.
---------------------------------------------------------------------------
local CLUSTERS = { "Off", "Left trigger", "Right trigger", "Both triggers" }
local _ = { L["Off"], L["Left trigger"], L["Right trigger"], L["Both triggers"] }     -- (for the translations)
ns.RegisterSetting({
    id = "stanceCluster", section = "Gamepad bars", share = false, basic = true, command = "stancebar",
    kind = "number", min = 1, max = #CLUSTERS, choices = CLUSTERS,
    label = "A form's own actions take the place of",
    tip = "which cluster of your gamepad bar a form's or stance's own actions stand in for while you are in it (bear, cat, defensive stance...); this is the game's own Stance Bar setting, so the game does the switching, in a fight too",
    available = function() return S.Available() end,
    get = function() return tonumber(ns.Plain(Call(G("GetCVar"), S.CLUSTER_CVAR))) or 0 end,
    set = function(v)
        if InCombatLockdown() then ns.Say(L["Not in combat."]); return end
        S.SetCluster(v)
        ns.db.stanceChosen[S.Character()] = true             -- (yours now: our starting choice never comes back)
    end,
    onChange = function() end,
})

-- The game's setting, set as its own menus would
function S.SetCluster(v)
    local set = (C_CVar and C_CVar.SetCVar) or G("SetCVar")
    Call(set, S.CLUSTER_CVAR, tostring(math.floor(v)))
    ns.Note("formsets: %s set to %s, now %s", S.CLUSTER_CVAR, tostring(v), tostring(ns.Plain(Call(G("GetCVar"), S.CLUSTER_CVAR))))
end

-- To begin with: the left trigger's cluster (2), the user's choice of 2026-11-27 (the game's own start is the
-- right trigger's). Once for each character, out of combat, and only while the game's setting is still on the
-- game's own starting value: a cluster chosen by you, here or in the game's menus, is never changed.
S.START = 2
ns.RegisterSaved("stanceChosen", function(v)
    local out = {}
    for key, yes in pairs(type(v) == "table" and v or {}) do
        if type(key) == "string" and yes == true then out[key] = true end
    end
    return out
end)
function S:Apply(run)
    if not (run and S.Available()) or InCombatLockdown() then return end
    local me = S.Character()
    if ns.db.stanceChosen[me] then return end
    ns.db.stanceChosen[me] = true
    local now = tonumber(ns.Plain(Call(G("GetCVar"), S.CLUSTER_CVAR)))
    local default = tonumber(ns.Plain(Call(G("GetCVarDefault"), S.CLUSTER_CVAR))) or 3
    if now == default and now ~= S.START then S.SetCluster(S.START) end
end
ns.RegisterModule("formsets", S)

ns.RegisterSetting({
    key = "formFill", kind = "boolean", default = true, command = "formfill", section = "Gamepad bars",
    label = "Fill a form's own bar with its abilities",
    tip = "the first time you shift into a form or stance, out of combat, the empty buttons of its own bar are filled with that form's abilities from your spellbook, so the form is ready to fight with; what is on it already stays, and what you take off afterwards stays off",
})

-- Forms whose bar was filled once: "<character>:<spell>"
ns.RegisterSaved("stanceFilled", function(v)
    local out = {}
    for key, yes in pairs(type(v) == "table" and v or {}) do
        if type(key) == "string" and yes == true then out[key] = true end
    end
    return out
end)

-- Which cluster the stance bar stands in for, as the game names it ("Page1RightBar"), and the setting's value
function S.StanceOverride()
    local value = tonumber(ns.Plain(Call(G("GetCVar"), S.CLUSTER_CVAR)))
    local names = type(Enum) == "table" and Enum.GamepadStanceBarOverride
    for name, v in pairs(type(names) == "table" and names or {}) do
        if v == value then return name, value end
    end
    return nil, value
end

---------------------------------------------------------------------------
-- Your forms, and the one you are in
---------------------------------------------------------------------------
local function SpellName(spell)
    for _, get in ipairs({ C_Spell and C_Spell.GetSpellName, G("GetSpellInfo") }) do
        local name = Call(get, spell)
        if type(name) == "string" and name ~= "" then return name end
    end
    return "#" .. tostring(spell)
end

-- Your forms and stances, in the game's order: { index, spell, name }
function S.Forms()
    local out = {}
    local count = Call(G("GetNumShapeshiftForms")) or 0
    for i = 1, (type(count) == "number" and count or 0) do
        local r = { Call(G("GetShapeshiftFormInfo"), i) }
        local spell                                          -- (its spell: the last number after the icon)
        for k = 2, 6 do
            if type(r[k]) == "number" then spell = r[k] end
        end
        if spell then out[#out + 1] = { index = i, spell = spell, name = SpellName(spell) } end
    end
    return out
end

-- The form you are in now, or nil
function S.Current()
    local now = Call(G("GetShapeshiftForm"))
    if type(now) ~= "number" or now == 0 then return nil end
    for _, f in ipairs(S.Forms()) do
        if f.index == now then return f end
    end
end

local function Character() return S.Character() end

---------------------------------------------------------------------------
-- What goes on a form's bar: its own set from the keyboard bar (the classic bar swaps to it in the form), then
-- its abilities you know, by how often they are used (each by its first rank's id; the rank you know goes on)
---------------------------------------------------------------------------
local STEALTH = { 8676, 703, 1833, 6770, 921, 1725, 14183, 2983 }   -- ambush, garrote, cheap shot, sap, pick pocket...
local BEAR = { 6807, 779, 6795, 99, 5211, 16979, 5229, 22842, 5209, 16857 }   -- maul, swipe, growl, roar, bash...
S.ABILITIES = {
    [768] = { 1082, 1822, 5221, 1079, 22568, 5217, 5215, 6785, 9005, 1850, 8998, 16857 },  -- claw, rake, shred, rip...
    [5487] = BEAR, [9634] = BEAR,
    [71] = { 355, 2565, 6572, 7386, 72, 23922, 78, 1160, 676, 12809, 871, 12975, 2687 },  -- taunt, shield block...
    [2458] = { 1680, 23881, 5308, 78, 845, 6552, 20252, 18499, 1715, 1464, 1719, 2687 },   -- whirlwind, bloodthirst...
    [1784] = STEALTH, [1785] = STEALTH, [1786] = STEALTH, [1787] = STEALTH,
}

-- The rank of a spell you know (its first rank's id in), or nil
local function Known(base)
    local name = SpellName(base)
    if name:sub(1, 1) == "#" then return nil end
    local id
    local info = C_Spell and C_Spell.GetSpellInfo and Call(C_Spell.GetSpellInfo, name)
    if type(info) == "table" then id = ns.Plain(info.spellID) end
    if not id then id = ns.Plain(select(7, Call(G("GetSpellInfo"), name))) end
    if type(id) ~= "number" then return nil end
    local known = G("IsSpellKnown")
    if type(known) == "function" and Call(known, id) == false then return nil end
    return id
end

local function Pickup(kind)
    if kind == "spell" then return (C_Spell and C_Spell.PickupSpell) or G("PickupSpell") end
    if kind == "item" then return (C_Item and C_Item.PickupItem) or G("PickupItem") end
    if kind == "macro" then return G("PickupMacro") end
end

-- (what an action is, for telling two of the same apart: a spell by its name, whatever its rank)
local function ActionKey(kind, id)
    if kind == nil or id == nil then return nil end
    return kind == "spell" and ("spell:" .. SpellName(id)) or (tostring(kind) .. ":" .. tostring(id))
end

-- In order: { kind, id }
function S.FillList(f)
    local list, seen = {}, {}
    local function add(kind, id)
        local key = Pickup(kind) and ActionKey(kind, id)
        if not key or seen[key] then return end
        seen[key] = true
        list[#list + 1] = { kind = kind, id = id }
    end
    local offset = ns.Plain(Call(G("GetBonusBarOffset")))
    if type(offset) == "number" and offset > 0 then               -- (the keyboard bar's set for the form: 73-84...)
        local first = (5 + offset) * 12
        for i = 1, 12 do
            local kind, id = Call(G("GetActionInfo"), first + i)
            add(ns.Plain(kind), ns.Plain(id))
        end
    end
    for _, base in ipairs(S.ABILITIES[f.spell] or {}) do
        local id = Known(base)
        if id then add("spell", id) end
    end
    return list
end

---------------------------------------------------------------------------
-- The stance bar of the form you are in
---------------------------------------------------------------------------
-- Its slots (none out of any stance): what the game's own stance bar buttons run, read off them, in their order;
-- where they can't be read, counted on from the game's first slot for the stance. how: "buttons" or "counted"
function S.StanceSlots()
    local api = Api()
    if not api then return nil end
    local first = ns.Plain(Call(api.GetFirstGamepadActionBarStorageSlotIndexForActiveStance))
    if type(first) ~= "number" then return nil end
    local slots, seen = {}, {}
    for i = 1, S.STANCE_SLOTS do
        local b = G(PAGE .. "TopCenteredAnchorStanceBarActionButton" .. i)
        local action = type(b) == "table" and ns.Plain(rawget(b, "action"))
        if type(action) == "number" and action >= first and action < first + 2 * S.STANCE_SLOTS and not seen[action] then
            seen[action] = true
            slots[#slots + 1] = action
        end
    end
    if #slots > 0 then return slots, "buttons" end
    for i = 0, S.STANCE_SLOTS - 1 do
        if ns.Plain(Call(api.IsValidGamepadActionStorageSlotIndex, first + i)) == false then break end
        slots[#slots + 1] = first + i
    end
    return #slots > 0 and slots or nil, "counted"
end

-- As it stands, for the report: "281 282* 283..." (* holds something), and how the slots were found
function S.StanceLine()
    local slots, how = S.StanceSlots()
    if not slots then return "no stance bar now" end
    local parts = {}
    for i, slot in ipairs(slots) do parts[i] = tostring(slot) .. (Call(G("HasAction"), slot) and "*" or "") end
    return ("stance bar slots (%s): %s"):format(tostring(how), table.concat(parts, " "))
end

-- One action into a slot, as dragging it there does; true when it is there afterwards
local function Place(slot, action)
    Call(G("ClearCursor"))
    Call(Pickup(action.kind), action.id)
    if Call(G("GetCursorInfo")) == nil then return false end
    Call(G("PlaceAction"), slot)
    Call(G("ClearCursor"))
    return Call(G("HasAction"), slot) and true or false
end

-- (why a form's bar was not filled, noted once a form)
local function Skip(f, why)
    if S.skipped[f.spell] == why then return end
    S.skipped[f.spell] = why
    ns.Note("formsets: %s stance bar not filled: %s", f.name, why)
end

-- Topped up: what is on it stays where it is (the game puts a couple there itself), and the form's abilities that
-- are not on it yet go on its empty buttons, in order. Returns how many went on and how many were there already;
-- nil when there is no stance bar to fill just now.
function S.FillStance(f)
    if InCombatLockdown() then return nil end
    local slots = S.StanceSlots()
    if not slots then Skip(f, "the game names no stance bar slots yet"); return nil end
    local have, free, there = {}, {}, 0
    for _, slot in ipairs(slots) do
        if Call(G("HasAction"), slot) then
            there = there + 1
            local kind, id = Call(G("GetActionInfo"), slot)
            local key = ActionKey(ns.Plain(kind), ns.Plain(id))
            if key then have[key] = true end
        else
            free[#free + 1] = slot
        end
    end
    if #free == 0 then Skip(f, "it is full: " .. S.StanceLine()); return 0, there end
    local list, placed, failed = S.FillList(f), 0, 0
    for _, action in ipairs(list) do
        local slot = free[placed + failed + 1]               -- (a button that won't take one is passed over)
        if not slot then break end
        if not have[ActionKey(action.kind, action.id)] then
            if Place(slot, action) then placed = placed + 1 else failed = failed + 1 end
        end
    end
    ns.Note("formsets: %s stance bar: %d there already, %d added of %d known (%d would not go on); %s", f.name, there,
        placed, #list, failed, S.StanceLine())
    return placed, there
end

-- A form shifted into: its bar filled, once (in a fight: after it, if you are still in the form)
function S.Shifted()
    if not (ns.db and ns.db.formFill and ns.ShouldRun() and S.Available()) then return end
    local f = S.Current()
    if not f then return end
    local key = Character() .. ":" .. f.spell
    if ns.db.stanceFilled[key] or InCombatLockdown() then return end
    local n, there = S.FillStance(f)
    if n == nil then return end
    -- (nothing went on an empty bar: tried again at your next shift; else done, and what you take off stays off)
    if n == 0 and (there or 0) == 0 then return end
    ns.db.stanceFilled[key] = true
    if n > 0 then
        ns.Say(L["%s now has %d of its abilities on the game's own stance bar, which takes the place of one of your trigger bars while you are in that form. Rearrange them as you like."]:format(f.name, n))
    end
end

-- (a moment after a shift, how the game's stance bar stands: for the debug report)
local function Record()
    if not (ns.db and ns.db.debug) then return end           -- (only while debug reports are on)
    local bar = G(PAGE .. "TopCenteredAnchorStanceBar")
    local name, value = S.StanceOverride()
    local line = ("shifted to %s: %s; the game's stance bar active %s, in place of %s (%s)"):format(
        tostring(Call(G("GetShapeshiftForm"))), S.StanceLine(),
        tostring(type(bar) == "table" and ns.Plain(rawget(bar, "isOverrideBarActive"))), tostring(name), tostring(value))
    if S.notes[#S.notes] == line then return end
    S.notes[#S.notes + 1] = line
    if #S.notes > 12 then table.remove(S.notes, 1) end
    ns.Note("formsets: %s", line)
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "UPDATE_SHAPESHIFT_FORM", "PLAYER_REGEN_ENABLED" }) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", ns.Protect(function(_, event)
    if not ns.db then return end
    S.Shifted()
    -- (and a moment on: the game names a stance's slots a little after the shift itself)
    if event == "UPDATE_SHAPESHIFT_FORM" and C_Timer and C_Timer.After then
        C_Timer.After(0.3, ns.Protect(function() S.Shifted(); Record() end))
    end
end))

---------------------------------------------------------------------------
-- The self-check and the debug report
---------------------------------------------------------------------------
ns.RegisterCheck(function(row, run, db)
    if not (run and db.formFill) then return end
    if #S.Forms() == 0 then return end
    local name, value = S.StanceOverride()
    row("the game's stance bar gives each form its own actions", S.Available(),
        S.Available() and ("in place of %s (%s)"):format(tostring(name), tostring(value))
        or "this client has no gamepad stance bar; nothing to do")
end)

function S.Describe()
    local name, value = S.StanceOverride()
    local out = { ("the game's stance bar: available %s, in place of %s (%s), filling %s; now: %s"):format(
        tostring(S.Available()), tostring(name), tostring(value), tostring(ns.db and ns.db.formFill), S.StanceLine()) }
    local me = Character()
    for _, f in ipairs(S.Forms()) do
        out[#out + 1] = ("form %d (spell %d) %s: %s"):format(f.index, f.spell, f.name,
            ns.db and ns.db.stanceFilled[me .. ":" .. f.spell] and "filled once" or "not filled yet")
    end
    for _, line in ipairs(S.notes) do out[#out + 1] = line end
    return out
end
