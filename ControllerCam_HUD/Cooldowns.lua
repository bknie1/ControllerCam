-- ControllerCam HUD: the game's own options.
-- Some things the HUD offers are simply the game's settings (the ones in its Options and Edit Mode). For
-- those the HUD keeps no setting of its own: a /cchud switch flips the game's setting, and changing it in the
-- game's menus is the same thing. The HUD never turns one on by itself.

local ADDON, ns = ...

ns.NATIVE = {
    cooldowns = "cooldownViewerEnabled",     -- Cooldown Manager
    tot       = "showTargetOfTarget",        -- Target of target
    resource  = "nameplateShowSelf",         -- Personal Resource Display (your health and power under your character)
    reagents  = "bankAutoDepositReagents",   -- Bank: reagents are deposited automatically
    auratooltip = "GamepadShowAutoAuraTooltip", -- Gamepad: a buff's tooltip pops up when it is applied
}

-- Chat: names in their class colour. The game keeps this per kind of chat (its chat settings); ours is one
-- switch over the usual kinds: on when every one of them is.
local CHAT_KINDS = { "SAY", "YELL", "EMOTE", "PARTY", "PARTY_LEADER", "RAID", "RAID_LEADER", "RAID_WARNING", "GUILD",
                     "OFFICER", "WHISPER", "WHISPER_INFORM", "INSTANCE_CHAT", "INSTANCE_CHAT_LEADER" }
for i = 1, 10 do CHAT_KINDS[#CHAT_KINDS + 1] = "CHANNEL" .. i end
ns.NATIVE.chatclass = {
    get = function()
        if not (ChatTypeInfo and SetChatColorNameByClass and ChatTypeInfo.SAY) then return nil end
        for _, kind in ipairs(CHAT_KINDS) do
            local info = ChatTypeInfo[kind]
            if info and not info.colorNameByClass then return false end
        end
        return true
    end,
    set = function(on)
        for _, kind in ipairs(CHAT_KINDS) do
            if ChatTypeInfo[kind] then pcall(SetChatColorNameByClass, kind, on and true or false) end
        end
    end,
}

-- true / false, or nil when this client has no such setting
function ns.GetNative(key)
    local native = ns.NATIVE[key]
    if type(native) == "table" then return native.get() end
    local value = GetCVar(native)
    if value == nil then return nil end
    return value ~= "0"
end

function ns.SetNative(key, on)
    local native = ns.NATIVE[key]
    if type(native) == "table" then native.set(on) else pcall(SetCVar, native, on and "1" or "0") end
    return ns.GetNative(key) == (on and true or false)
end

-- Defaults of ours for a game option, applied once and never again (the player can switch them back)
ns.RegisterSaved("nativeDefaulted", function(old)
    local t = {}
    if type(old) == "table" then
        for k, v in pairs(old) do if type(k) == "string" and v == true then t[k] = true end end
    end
    return t
end)
local ONCE = { auratooltip = false }       -- the buff tooltip pops up over the target frame: off to begin with

-- An earlier version switched the Cooldown Manager on by itself and remembered it: undo that once.
local Native = {}
function Native:Apply(run)
    local saved = ns.db.saved
    for name, value in pairs(saved) do
        pcall(SetCVar, name, value)
        saved[name] = nil
    end
    if not run then return end
    local done = ns.db.nativeDefaulted
    for key, value in pairs(ONCE) do
        if not done[key] and ns.GetNative(key) ~= nil then
            ns.SetNative(key, value)
            done[key] = true
        end
    end
end
ns.RegisterModule("native", Native)
