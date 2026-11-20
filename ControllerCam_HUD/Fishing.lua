-- ControllerCam HUD: one-button fishing.
-- With a fishing pole in your hands, your interact button is your fishing button. While no line is out and
-- there is nothing to interact with, it casts your line. While the float is out it is the game's own interact
-- button again, so the same press hooks the fish when the float bobs. The catch is taken for you. Nothing to
-- switch on: it is there while you hold a pole and gone when you put it away, and never in a fight.
-- /cchud fish (or its key binding) pauses it, for when you want the button to yourself with a pole in hand.
--
-- How: while the button should cast, it is bound to the Fishing spell (a binding override, as the game
-- provides for addons; set and cleared out of combat only). At every other moment there is no override at
-- all: the button is the game's. Nothing is pressed for you: each cast and each hook is your press.
--
-- Which button: the keys bound to the game's Interact, if any. The Gamepad UI keeps its interact button to
-- itself (it is not a key binding), so there it is PAD3 (Square, or X), the button the game starts with;
-- /cchud fishkey names another.
--
-- Another button, a trigger say: it is not the game's interact button, so there is nothing of the game's to
-- give it back to while the float is out. Then it is bound to the game's Interact command for that time, which
-- is what hooks the fish; and it casts whether or not something stands in front of you, since it was never
-- your way of interacting.
--
-- Bait: press the button twice quickly and the second press puts your best bait on the pole, when the pole has
-- none. For the half second after a cast of yours begins, the button is bound to a button of the game's secure
-- kind that uses the bait; after that it is as described above. No fish bites that early, so no catch is lost.

local ADDON, ns = ...
local L = ns.L

local F = { active = false, paused = false, state = nil, keys = {} }
ns.Fishing = F

ns.RegisterSetting({
    key = "fishMode", kind = "boolean", default = true, command = "fishmode", section = "Fishing",
    label = "One-button fishing",
    tip = "with a fishing pole in your hands, your interact button casts your line whenever there is nothing to interact with, and hooks the fish when the float bobs; the catch is taken for you",
})

ns.RegisterSetting({
    key = "fishBait", kind = "boolean", default = true, command = "fishbait", section = "Fishing",
    label = "Bait on a double press",
    tip = "press your fishing button twice quickly: the second press puts the best bait in your bags on your pole, when the pole has none",
})

F.KEY = "PAD3"                -- the Gamepad UI's interact button to begin with
F.DOUBLE = 0.5                -- a second press this soon after your cast began is a double press
-- Bait, best first: the item, and what it adds to your fishing
F.BAITS = { { 6533, 100 }, { 7307, 75 }, { 6532, 75 }, { 6811, 50 }, { 6530, 50 }, { 6529, 25 } }
local POLE_SUBCLASS = 20      -- the game's item sub-class of fishing poles (a weapon)

ns.RegisterSaved("fishKey", function(old)
    return (type(old) == "string" and old:match("^PAD%w+$")) and old or nil
end)

local owner = CreateFrame("Frame", "ControllerCamHUD_FishingKeys", UIParent)

---------------------------------------------------------------------------
-- What the game knows
---------------------------------------------------------------------------
function F.HasPole()
    local id = GetInventoryItemID and GetInventoryItemID("player", 16)
    if not id or ns.IsSecret(id) then return false end
    local get = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not get then return false end
    local ok, _, _, _, _, _, classID, subID = pcall(get, id)
    return ok and classID == 2 and subID == POLE_SUBCLASS or false
end

-- The Fishing spell by its name in your language (every rank shares it)
function F.Spell()
    local get = (C_Spell and C_Spell.GetSpellName) or GetSpellInfo
    if not get then return nil end
    for id in pairs(ns.CastBar and ns.CastBar.FISHING or { [7620] = true }) do
        local ok, name = pcall(get, id)
        if ok and type(name) == "string" and not ns.IsSecret(name) and name ~= "" then return name end
    end
    return nil
end

-- Is your line out? (you are channelling a fishing spell)
function F.LineOut()
    if not UnitChannelInfo then return false end
    local ok, name, _, _, _, _, _, _, spellID = pcall(UnitChannelInfo, "player")
    if not ok or not name then return false end
    if ns.IsSecret(spellID) then return false end
    return (ns.CastBar and ns.CastBar.FISHING or {})[spellID or 0] and true or false
end

-- Is there something to interact with (someone to talk to, a thing to open)? Then the button is needed for that.
function F.Busy()
    if not UnitExists then return false end
    local ok, there = pcall(UnitExists, "softinteract")
    return ok and ns.Yes(there)
end

-- Your Fishing skill: its level, what is added to it right now (bait, pole, anything else), and its cap
function F.Skill()
    local fishing = F.Spell()
    if GetProfessions and GetProfessionInfo then
        local ok, _, _, _, fish = pcall(GetProfessions)
        if ok and type(fish) == "number" then
            local ok2, _, _, rank, cap, _, _, _, bonus = pcall(GetProfessionInfo, fish)
            if ok2 and type(rank) == "number" and not ns.IsSecret(rank) then
                return rank, tonumber(bonus) or 0, tonumber(cap) or rank
            end
        end
    end
    if not (GetNumSkillLines and GetSkillLineInfo and fishing) then return nil end
    local ok, n = pcall(GetNumSkillLines)
    for i = 1, (ok and tonumber(n)) or 0 do
        local ok2, name, header, _, rank, _, bonus, cap = pcall(GetSkillLineInfo, i)
        if ok2 and name == fishing and not header and type(rank) == "number" then
            return rank, tonumber(bonus) or 0, tonumber(cap) or rank
        end
    end
    return nil
end

-- How long the bait on your pole still lasts, in seconds (nil without bait)
function F.BaitLeft()
    if not GetWeaponEnchantInfo then return nil end
    local ok, has, ms = pcall(GetWeaponEnchantInfo)
    if not ok or not ns.Yes(has) or type(ms) ~= "number" or ns.IsSecret(ms) then return nil end
    return ms / 1000
end

-- The best bait in your bags that you can use: its item, its name, and what it adds
function F.Bait()
    local count = (C_Item and C_Item.GetItemCount) or GetItemCount
    if not count then return nil end
    local usable = (C_Item and C_Item.IsUsableItem) or IsUsableItem
    for _, bait in ipairs(F.BAITS) do
        local ok, n = pcall(count, bait[1])
        if ok and type(n) == "number" and n > 0 then
            local can = true
            if usable then
                local ok2, yes = pcall(usable, bait[1])
                if ok2 and yes == false then can = false end
            end
            if can then
                local name
                local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
                if get then
                    local ok3, text = pcall(get, bait[1])
                    if ok3 and type(text) == "string" then name = text end
                end
                return bait[1], name or ("item:" .. bait[1]), bait[2]
            end
        end
    end
    return nil
end

-- Could a double press put bait on right now? (it is wanted, there is some, and the pole has none)
function F.BaitReady()
    if not (ns.db and ns.db.fishBait and SetOverrideBindingClick) then return false end
    if F.BaitLeft() then return false end
    return F.Bait() ~= nil
end

-- The game's secure button that uses the bait (and, where the game asks what to put it on, names the pole)
local baitButton
local function BaitButton(id)
    if not id then return nil end
    if not baitButton then
        local ok, b = pcall(CreateFrame, "Button", "ControllerCamHUD_FishingBait", UIParent, "SecureActionButtonTemplate")
        if not ok or not b then return nil end
        baitButton = b
        if b.RegisterForClicks then pcall(b.RegisterForClicks, b, "AnyDown", "AnyUp") end
        F.baitButton = b
    end
    baitButton:SetAttribute("type", "item")
    baitButton:SetAttribute("item", "item:" .. id)
    baitButton:SetAttribute("target-slot", 16)
    return baitButton
end

-- The buttons that fish: your interact keys, or (the Gamepad UI has none) the one named for it
function F.Keys()
    local keys = {}
    if GetBindingKey then
        for _, key in ipairs({ GetBindingKey("INTERACTTARGET") }) do
            if type(key) == "string" then keys[#keys + 1] = key end
        end
    end
    if #keys == 0 then keys[1] = (ns.db and ns.db.fishKey) or F.KEY end
    return keys
end

-- Is this button the game's own interact button? (the hook is then the game's to do, with no binding of ours)
function F.IsInteract(key)
    if GetBindingKey then
        for _, k in ipairs({ GetBindingKey("INTERACTTARGET") }) do
            if k == key then return true end
        end
    end
    return key == F.KEY
end

---------------------------------------------------------------------------
-- The hint on screen while the button casts
---------------------------------------------------------------------------
F.FLOAT = 40
local hint
local function Hint()
    if hint then return hint end
    hint = CreateFrame("Frame", "ControllerCamHUD_FishingHint", UIParent)
    hint:SetSize(260, 40)
    hint:SetFrameStrata("MEDIUM")
    local native = _G.PlayerCastingBarFrame
    if native then hint:SetPoint("BOTTOM", native, "BOTTOM", 0, 0)
    else hint:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 294) end
    hint.icon = hint:CreateTexture(nil, "ARTWORK")
    hint.icon:SetTexture(ns.media.bobber)
    hint.icon:SetSize(F.FLOAT, F.FLOAT)                         -- large enough to be seen from the couch
    hint.text = ns.FontString(hint, 12, "CENTER")
    hint.text:SetPoint("CENTER", hint, "CENTER", F.FLOAT / 2, 0)
    hint.icon:SetPoint("RIGHT", hint.text, "LEFT", -6, 0)
    hint:Hide()
    hint:SetScript("OnUpdate", function(self)
        self.icon:ClearAllPoints()                              -- the float bobs while it waits
        self.icon:SetPoint("RIGHT", self.text, "LEFT", -6, math.sin(GetTime() * 3) * 3)
    end)
    F.hint = hint
    return hint
end

local function KeyName(key)
    local text = GetBindingText and GetBindingText(key) or key
    return (type(text) == "string" and text ~= "") and text or key
end
F.KeyName = KeyName

---------------------------------------------------------------------------
-- The button
---------------------------------------------------------------------------
-- What the button should do right now: "cast", "hook" (a button that is not the game's interact button, while
-- the float is out), or nil for the game's own
function F:Want()
    if not self.active or self.paused or InCombatLockdown() or not F.HasPole() then return nil end
    local own = F.IsInteract(F.Keys()[1])
    if F.LineOut() then
        if self.baitUntil and GetTime() < self.baitUntil and F.BaitReady() then return "bait" end
        return (not own) and "hook" or nil
    end
    if own and F.Busy() then return nil end
    return F.Spell() and "cast" or nil
end

function F:Bind()
    if InCombatLockdown() then return end
    local state = self:Want()
    if state == self.state then return end
    self.state = state
    ClearOverrideBindings(owner)
    if state == "cast" then
        self.keys, self.spell = F.Keys(), F.Spell()
        for _, key in ipairs(self.keys) do
            if SetOverrideBindingSpell then SetOverrideBindingSpell(owner, true, key, self.spell) end
        end
        local key = self.keys[1]
        ns.Note("fishing: %s casts (the game now says: %s)", key, tostring(GetBindingAction and GetBindingAction(key, true)))
        local h = Hint()
        h.text:SetText(L["Fishing: %s casts"]:format(KeyName(key)))
        h:Show()
        if not self.told then                                   -- said once, the first time it happens
            self.told = true
            ns.Say(L["Fishing mode: %s casts your line, and hooks the fish when the float bobs."]:format(KeyName(key)))
        end
    elseif state == "bait" then
        local button = BaitButton((F.Bait()))
        if button then
            for _, key in ipairs(F.Keys()) do SetOverrideBindingClick(owner, true, key, button:GetName(), "LeftButton") end
            ns.Note("fishing: a second press now puts bait on")
        end
        if hint then hint:Hide() end
    elseif state == "hook" then
        local keys = F.Keys()
        for _, key in ipairs(keys) do SetOverrideBinding(owner, true, key, "INTERACTTARGET") end
        ns.Note("fishing: %s hooks (the game now says: %s)", keys[1], tostring(GetBindingAction and GetBindingAction(keys[1], true)))
        if hint then hint:Hide() end
    else
        ns.Note("fishing: the button is the game's again")
        if hint then hint:Hide() end
    end
end

-- /cchud fish: the button to yourself for now, or fishing again
function F:Toggle()
    self.paused = not self.paused
    if self.paused then
        self:Bind()
        ns.Say(L["Fishing mode: off."])
        return
    end
    if not self.active then return end
    if not F.HasPole() then ns.Say(L["Fishing mode needs a fishing pole in your hands."]); return end
    if not F.Spell() then ns.Say(L["You do not know Fishing."]); return end
    self.told = false
    self:Bind()
end

---------------------------------------------------------------------------
-- Watching: your pole, your line, what is in front of you, the catch
---------------------------------------------------------------------------
-- The catch: taken for you (your auto loot setting is left as you have it)
local function TakeCatch()
    if not (GetNumLootItems and LootSlot) then return end
    if GetCVar and GetCVar("autoLootDefault") == "1" then return end        -- the game takes it already
    for i = GetNumLootItems(), 1, -1 do pcall(LootSlot, i) end
end

local function Release()
    F.state, F.baitUntil = nil, nil
    ClearOverrideBindings(owner)
    if hint then hint:Hide() end
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", ns.Protect(function(_, event, unit)
    if event == "PLAYER_REGEN_DISABLED" then
        Release()                                               -- (bindings can still be cleared at this moment)
    elseif event == "PLAYER_EQUIPMENT_CHANGED" or event == "UNIT_INVENTORY_CHANGED" then
        if unit and event == "UNIT_INVENTORY_CHANGED" and unit ~= "player" then return end
        F.pole = F.HasPole()
        F:Bind()
    elseif event == "LOOT_OPENED" then
        if ns.FishLog then ns.FishLog:Read() end                -- written down before it leaves the line
        if F.pole and not F.paused then TakeCatch() end
    elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
        if unit ~= "player" then return end
        -- your cast began: for a moment a second press is for the bait
        if F.state == "cast" and F.LineOut() and F.BaitReady() then
            F.baitUntil = GetTime() + F.DOUBLE
            C_Timer.After(F.DOUBLE + 0.05, ns.Protect(function() F.baitUntil = nil; F:Bind() end))
        end
        F:Bind()
    elseif event:sub(1, 5) ~= "UNIT_" or unit == "player" then  -- a fight ended, your line, what is in front of you
        F:Bind()
    end
end))

-- (what is in front of you can change without the game saying so: looked at a few times a second)
local since = 0
events:SetScript("OnUpdate", ns.Protect(function(_, dt)
    if not (F.active and F.pole) then return end
    since = since + dt
    if since < 0.3 then return end
    since = 0
    F:Bind()
end))

local EVENTS = { "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_EQUIPMENT_CHANGED", "UNIT_INVENTORY_CHANGED",
                 "PLAYER_SOFT_INTERACT_CHANGED", "LOOT_OPENED", "UNIT_SPELLCAST_CHANNEL_START",
                 "UNIT_SPELLCAST_CHANNEL_STOP" }

function F:Apply(run)
    local want = run and ns.db.fishMode and true or false
    if want and not self.active then
        self.active = true
        for _, e in ipairs(EVENTS) do pcall(events.RegisterEvent, events, e) end
    elseif not want and self.active then
        self.active = false
        events:UnregisterAllEvents()
        Release()
    end
    self.pole = want and F.HasPole() or false
    self:Bind()
end

function F.Describe()
    local rank, bonus, cap = F.Skill()
    local bait, baitName = F.Bait()
    return ("on %s, paused %s, button does %s, pole %s, spell %s, keys %s (the game's interact: %s), something to interact with %s, soft interact %s; skill %s +%s of %s; bait on the pole for %s s, best in the bags %s (%s), a double press can use it %s"):format(
        tostring(F.active), tostring(F.paused), tostring(F.state or "the game's"), tostring(F.HasPole()),
        tostring((F.Spell())), table.concat(F.Keys(), " "), tostring(F.IsInteract(F.Keys()[1])), tostring(F.Busy()),
        tostring((GetCVar and GetCVar("SoftTargetInteract")) or nil), tostring(rank), tostring(bonus), tostring(cap),
        tostring(F.BaitLeft()), tostring(bait), tostring(baitName), tostring(F.BaitReady()))
end

function ControllerCamHUD_Fishing() ns.Protect(function() F:Toggle() end)() end
BINDING_NAME_CCHUD_FISHING = L["Fishing mode: one button casts and hooks"]
ns.RegisterCommand("fish", function() F:Toggle() end, "/cchud fish",
    "one-button fishing off for now, or on again (with a pole in your hands it is on by itself)")
-- The buttons by the names on them
F.NAMES = { a = "PAD1", b = "PAD2", x = "PAD3", y = "PAD4", cross = "PAD1", circle = "PAD2", square = "PAD3",
            triangle = "PAD4", lt = "PADLTRIGGER", rt = "PADRTRIGGER", l2 = "PADLTRIGGER", r2 = "PADRTRIGGER",
            lb = "PADLSHOULDER", rb = "PADRSHOULDER", l1 = "PADLSHOULDER", r1 = "PADRSHOULDER" }

ns.RegisterCommand("fishkey", function(arg)
    local key = F.NAMES[(arg or ""):lower()] or (arg or ""):upper()
    if not key:match("^PAD%w+$") then ns.Say(L["usage:"] .. " /cchud fishkey x | rt | lt | rb | lb | a | b | y"); return end
    if InCombatLockdown() then ns.Say(L["Not in combat."]); return end
    ns.db.fishKey = key
    Release()
    F:Bind()
    ns.Say(L["Fishing button: %s"]:format(KeyName(key)))
end, "/cchud fishkey <button>", "the button that fishes: your interact button to begin with (Square or X), or any other, a trigger for one (rt)")

ns.RegisterModule("fishing", F)
