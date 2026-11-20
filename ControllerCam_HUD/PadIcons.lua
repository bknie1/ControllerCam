-- ControllerCam HUD: the icons on your buttons.
-- The game shows your controller's buttons in one of its own styles: numbers (Generic), letters (A B X Y, as on
-- an Xbox pad or a Steam controller), letters the other way round (as on a Switch pad) or shapes (as on a
-- PlayStation pad). It keeps that style with its settings for each kind of controller, and starts every
-- controller on numbers. This sets the game's style for the controller in use: found by itself from what the
-- controller says it is, or the kind you choose. Nothing is drawn by us; it is the game's own setting, written
-- the way the game provides for (out of combat), and the game's bars, prompts and key names all follow it.
--
--   /cchud padicons auto | xbox | playstation | switch | steam | generic | game
--
-- "auto" only changes a controller that is still on the game's numbers (or that we changed before): a style
-- somebody set by hand is left alone, and so is a controller that is not recognised. "game" puts back what
-- the game had and leaves it alone from then on; switching the HUD off puts it back as well.

local ADDON, ns = ...
local L = ns.L

local I = { tried = {} }
ns.PadIcons = I

-- The game's name for each look
I.STYLE = { xbox = "Letters", steam = "Letters", playstation = "Shapes", switch = "Reverse", generic = "Generic" }
I.LABEL = { xbox = "Xbox", playstation = "PlayStation", switch = "Switch", steam = "Steam" }
I.ORDER = { "auto", "xbox", "playstation", "switch", "steam", "generic" }
local CHOICE = { auto = true, game = true }
for kind in pairs(I.STYLE) do CHOICE[kind] = true end
local ALIAS = { ps = "playstation", ps4 = "playstation", ps5 = "playstation", sony = "playstation", nintendo = "switch",
                deck = "steam", numbers = "generic", numbered = "generic", letters = "xbox", shapes = "playstation" }

-- Who made the controller (the number every USB device carries), and words to look for in its name
local MAKER = { [0x054C] = "playstation", [0x057E] = "switch", [0x045E] = "xbox", [0x28DE] = "steam" }
local WORDS = { { "dualsense", "playstation" }, { "dualshock", "playstation" }, { "playstation", "playstation" },
                { "ps[345] ", "playstation" }, { "steam", "steam" }, { "joy%-con", "switch" }, { "switch", "switch" },
                { "nintendo", "switch" }, { "xbox", "xbox" }, { "x%-box", "xbox" }, { "xinput", "xbox" } }

ns.RegisterSaved("padIcons", function(old) return CHOICE[old] and old or "auto" end)
-- The style the game had for a controller before we changed it ("maker:product" -> style)
ns.RegisterSaved("padIconsWas", function(old)
    local was = {}
    if type(old) == "table" then
        for key, style in pairs(old) do
            if type(key) == "string" and type(style) == "string" then was[key] = style end
        end
    end
    return was
end)

function I.Name(choice)
    if choice == "auto" then return L["Auto"] end
    if choice == "generic" then return L["Generic"] end
    if choice == "game" then return L["the game's own"] end
    return I.LABEL[choice] or tostring(choice)
end

---------------------------------------------------------------------------
-- What the game knows
---------------------------------------------------------------------------
function I:Supported()
    local G = C_GamePad
    return type(G) == "table" and G.GetConfig and G.SetConfig and G.ApplyConfigs and G.GetActiveDeviceID
        and G.GetDeviceRawState and true or false
end

-- The controller in use: { maker, product, name }, or nil
function I.Device()
    if not I:Supported() then return nil end
    local ok, id = pcall(C_GamePad.GetActiveDeviceID)
    if not ok or type(id) ~= "number" then return nil end
    local ok2, state = pcall(C_GamePad.GetDeviceRawState, id)
    if not ok2 or type(state) ~= "table" then return nil end
    return { maker = tonumber(state.vendorID), product = tonumber(state.productID),
             name = type(state.name) == "string" and state.name or "" }
end

-- What kind of controller that is, or nil when it does not say
function I.Detect(device)
    device = device or I.Device()
    if not device then return nil end
    local name = device.name:lower() .. " "
    for _, word in ipairs(WORDS) do
        if name:find(word[1]) then return word[2] end
    end
    return device.maker and MAKER[device.maker] or nil
end

-- The game's settings for the controller in use (its own, or the ones every controller shares)
function I.Config(device)
    device = device or I.Device()
    if not device then return nil end
    for _, id in ipairs({ { vendorID = device.maker, productID = device.product }, {} }) do
        if id.vendorID or not next(id) then
            local ok, config = pcall(C_GamePad.GetConfig, id)
            if ok and type(config) == "table" then
                return config, next(id) and ("%s:%s"):format(tostring(device.maker), tostring(device.product)) or "all"
            end
        end
    end
    return nil
end

function I.Current()
    local config = I.Config()
    return config and (type(config.labelStyle) == "string" and config.labelStyle or "Generic") or nil
end

local function Write(config, style)
    config.labelStyle = style
    local ok = pcall(C_GamePad.SetConfig, config)
    if ok then ok = pcall(C_GamePad.ApplyConfigs) end
    return ok and I.Current() == style
end

---------------------------------------------------------------------------
-- Setting it
---------------------------------------------------------------------------
-- Puts the game's style where the choice wants it. Returns what was done: "set", "same", "left" (nothing to
-- do or not ours to change), "refused", or nil when the game has no such thing or there is no controller.
function I:Sync()
    if not self:Supported() or InCombatLockdown() then return nil end
    local db = ns.db
    local device = I.Device()
    local config, key = I.Config(device)
    if not config then return nil end
    local now = type(config.labelStyle) == "string" and config.labelStyle or "Generic"
    local choice, was = db.padIcons or "auto", db.padIconsWas
    local want
    if choice == "game" then
        want = was[key]                                   -- put back, then forgotten below
    elseif choice == "auto" then
        local kind = I.Detect(device)
        self.found = kind
        if kind and (now == "Generic" or was[key]) then want = I.STYLE[kind] end
    else
        want = I.STYLE[choice]
    end
    if not want then return "left" end
    if want == now then
        if choice == "game" then was[key] = nil end
        return "same"
    end
    local attempt = key .. ">" .. want
    if self.tried[attempt] then return "refused" end     -- asked once already: the game did not take it
    if Write(config, want) then
        if choice == "game" then was[key] = nil elseif not was[key] then was[key] = now end
        ns.Note("button icons: %s is now %s (it was %s)", key, want, now)
        return "set"
    end
    self.tried[attempt] = true
    ns.Note("button icons: the game did not take %s for %s", want, key)
    return "refused"
end

-- Everything we changed, back as the game had it (the HUD is being switched off)
function I:Restore()
    if not self:Supported() or InCombatLockdown() then return end
    local was = ns.db.padIconsWas
    local config, key = I.Config()
    if config and key and was[key] and config.labelStyle ~= was[key] then
        if Write(config, was[key]) then ns.Note("button icons: %s is the game's again (%s)", key, was[key]) end
    end
    if key then was[key] = nil end
end

function I:Use(choice)
    choice = ALIAS[choice] or choice
    if not CHOICE[choice] then return false end
    ns.db.padIcons = choice
    self.tried = {}
    local did = self:Sync()
    if did == nil then
        ns.Say(L["Button icons: %s."]:format(I.Name(choice)) .. " " .. L["No controller is in use right now, or the game has no icon styles: it is set when one is."])
    elseif did == "refused" then
        ns.Say(L["The game did not take the button icons."])
    elseif choice == "auto" and not self.found then
        ns.Say(L["Button icons: %s."]:format(I.Name(choice)) .. " " .. L["The controller does not say what it is: the icons stay as the game has them."])
    elseif choice == "auto" then
        ns.Say(L["Button icons: %s."]:format(I.Name(choice) .. " (" .. I.Name(self.found) .. ")"))
    else
        ns.Say(L["Button icons: %s."]:format(I.Name(choice)))
    end
    if ns.Fishing then ns.Fishing.state = false; ns.Fishing:Bind() end   -- prompts of ours that name a button
    return true
end

---------------------------------------------------------------------------
-- Watching for a controller
---------------------------------------------------------------------------
local events = CreateFrame("Frame")
local waiting = false
events:SetScript("OnEvent", function()
    if waiting then return end
    waiting = true
    C_Timer.After(0.5, ns.Protect(function()
        waiting = false
        if I.active then I:Sync() end
    end))
end)
local EVENTS = { "GAME_PAD_ACTIVE_CHANGED", "GAME_PAD_CONNECTED", "GAME_PAD_CONFIGS_CHANGED", "PLAYER_REGEN_ENABLED" }

function I:Apply(run)
    local db = ns.db
    if not db.enabled then                                -- the HUD is off: the game's own style is back
        if self.active then
            self.active = false
            events:UnregisterAllEvents()
        end
        if next(db.padIconsWas) then self:Restore() end
        return
    end
    local want = run and self:Supported() and true or false
    if want ~= self.active then
        self.active = want
        if want then
            for _, e in ipairs(EVENTS) do pcall(events.RegisterEvent, events, e) end
        else
            events:UnregisterAllEvents()
        end
    end
    if want then self:Sync() end
end

function I.Describe()
    local device = I.Device()
    local config, key = I.Config(device)
    return ("the game has icon styles %s; chosen %s; controller %s (maker %s, product %s), taken for %s; its settings %s, style now %s; changed by us: %s"):format(
        tostring(I:Supported()), tostring(ns.db and ns.db.padIcons), device and device.name or "none",
        tostring(device and device.maker), tostring(device and device.product), tostring(I.Detect(device)),
        tostring(key), tostring(config and config.labelStyle),
        (function()
            local out = {}
            for k, v in pairs(ns.db and ns.db.padIconsWas or {}) do out[#out + 1] = k .. " was " .. v end
            return #out > 0 and table.concat(out, ", ") or "nothing"
        end)())
end

ns.RegisterCommand("padicons", function(arg)
    arg = (arg or ""):lower():match("^%s*(%S*)")
    if arg == "" then
        local now = I.Current()
        ns.Say(L["Button icons: %s."]:format(I.Name(ns.db.padIcons or "auto")) .. (now and (" (" .. now .. ")") or ""))
        return
    end
    if InCombatLockdown() then ns.Say(L["Not in combat."]); return end
    if not I:Use(arg) then
        ns.Say(L["usage:"] .. " /cchud padicons auto | xbox | playstation | switch | steam | generic | game")
    end
end, "/cchud padicons <kind>", "the icons the game shows for your controller's buttons: auto (by the controller in use), xbox, playstation, switch, steam, generic (numbers), or game to leave them as the game has them")

ns.RegisterModule("padicons", I)
