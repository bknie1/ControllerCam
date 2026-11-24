-- ControllerCam HUD: the spirit healer's countdown, always in sight.
-- In a battleground a ghost by the spirit healer is brought back with the next wave, and the game says when in a
-- window of its own. With a controller that window was easily lost: its first button is Cancel (A cancels your
-- resurrection) and B closes it, and nothing brings it back. The game's window is left as it is (opened by us it
-- would carry our code into the game's own dialogs); this is the HUD's own line under the top of the screen,
-- which no button closes: "Resurrection in 12 s", and, if the countdown has stopped while you are still by the
-- spirit healer, that talking to it starts it again. Gone the moment you are alive or walk away.

local ADDON, ns = ...
local L = ns.L

local RS = {}
ns.Resurrect = RS
RS.TICK = 0.2

local frame
local function Build()
    if frame then return frame end
    frame = CreateFrame("Frame", "ControllerCamHUD_Resurrect", UIParent)
    frame:SetFrameStrata("DIALOG")
    frame:SetSize(420, 34)
    frame:SetPoint("TOP", UIParent, "TOP", 0, -190)
    frame:SetIgnoreParentAlpha(true)                          -- (never faded with the rest of the screen)
    frame.back = frame:CreateTexture(nil, "BACKGROUND")
    frame.back:SetColorTexture(0.03, 0.04, 0.07, 0.78)
    frame.back:SetAllPoints(frame)
    frame.text = ns.FontString(frame, 16, "CENTER")
    frame.text:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame:Hide()
    return frame
end

local function Plain(v) v = ns.Plain(v); return type(v) == "number" and v or nil end
local function Yes(fn, ...)
    if type(fn) ~= "function" then return false end
    local ok, v = pcall(fn, ...)
    return ok and ns.Yes(v) or false
end

-- What to say now (or nil: nothing to show)
function RS.Words()
    if not RS.inRange or not Yes(UnitIsGhost, "player") then return nil end
    local left = Plain(select(2, pcall(rawget(_G, "GetAreaSpiritHealerTime") or function() return nil end)))
    if left and left > 0 then return L["Resurrection in %d s"]:format(math.ceil(left)) end
    return L["Talk to the spirit healer to be resurrected with the next wave"]
end

function RS.Update()
    local words = RS.Words()
    if not words then
        if frame then frame:Hide() end
        return
    end
    Build()
    frame.text:SetText(words)
    frame:Show()
end

local acc = 0
local watcher = CreateFrame("Frame")
watcher:SetScript("OnUpdate", ns.Protect(function(_, dt)
    if not RS.inRange then return end
    acc = acc + (dt or 0)
    if acc < RS.TICK then return end
    acc = 0
    RS.Update()
end))
watcher:SetScript("OnEvent", ns.Protect(function(_, event)
    if event == "AREA_SPIRIT_HEALER_IN_RANGE" then
        RS.inRange = true
    elseif event == "AREA_SPIRIT_HEALER_OUT_OF_RANGE" or event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST"
        or event == "PLAYER_ENTERING_WORLD" then
        RS.inRange = false
    end
    RS.Update()
end))
for _, e in ipairs({ "AREA_SPIRIT_HEALER_IN_RANGE", "AREA_SPIRIT_HEALER_OUT_OF_RANGE", "PLAYER_ALIVE",
                     "PLAYER_UNGHOST", "PLAYER_ENTERING_WORLD" }) do
    pcall(watcher.RegisterEvent, watcher, e)
end

RS.Build = Build
