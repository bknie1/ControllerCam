-- ControllerCam HUD: the experimental features notice.
-- The game asks at every login whether you accept its experimental features. Once you have answered "yes"
-- yourself, the HUD remembers that you did and answers it for you on later logins (switch it off in the
-- options to be asked again). It never answers a notice you have not accepted yourself.

local ADDON, ns = ...
local L = ns.L

local N = {}
ns.Notices = N

ns.RegisterSetting({
    key = "autoNotice", kind = "boolean", default = true, command = "autonotice", section = "General",
    label = "Confirm the experimental features notice",
    tip = "after you have accepted the game's experimental features notice once, it is accepted for you at later logins",
})
-- the notices you have accepted, by the game's own name for them
ns.RegisterSaved("acceptedNotices", function(old)
    local t = {}
    if type(old) == "table" then
        for k, v in pairs(old) do if type(k) == "string" and v == true then t[k] = true end end
    end
    return t
end)

-- "experimental" in the game's languages
N.WORDS = { "experimental", "experimentell", "expérimental", "sperimental", "실험", "экспериментальн", "实验", "實驗" }

function N.IsExperimental(which)
    local dialog = type(StaticPopupDialogs) == "table" and StaticPopupDialogs[which]
    if type(which) == "string" and which:lower():find("experiment") then return true end
    local text = dialog and dialog.text
    if type(text) ~= "string" then return false end
    text = text:lower()
    for _, word in ipairs(N.WORDS) do
        if text:find(word, 1, true) then return true end
    end
    return false
end

-- You accepted one: remember it
local function OnClick(dialog, index)
    if not ns.db or index ~= 1 or type(dialog) ~= "table" then return end
    local which = dialog.which
    if which and N.IsExperimental(which) then ns.db.acceptedNotices[which] = true end
end

-- It is shown again: answer it, if you have before
local function OnShow(which)
    if not (ns.db and ns.db.autoNotice and ns.db.acceptedNotices[which]) then return end
    C_Timer.After(0, function()
        local frame = StaticPopup_FindVisible and StaticPopup_FindVisible(which)
        if frame and StaticPopup_OnClick then
            StaticPopup_OnClick(frame, 1)
            N.answered = (N.answered or 0) + 1
        end
    end)
end

if type(StaticPopup_OnClick) == "function" then hooksecurefunc("StaticPopup_OnClick", ns.Protect(OnClick)) end
if type(StaticPopup_Show) == "function" then hooksecurefunc("StaticPopup_Show", ns.Protect(OnShow)) end

ns.RegisterCommand("forgetnotices", function()
    ns.db.acceptedNotices = {}
    ns.Say(L["The game's notices will be asked again."])
end, "/cchud forgetnotices", "forget the notices you have accepted, so the game asks again")
