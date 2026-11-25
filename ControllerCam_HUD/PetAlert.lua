-- ControllerCam HUD: your pet is hungry, where you cannot miss it.
-- A hunter's pet tells how it is (happy, content, unhappy) through a thin band beside the pet bar (UnitFrames.lua),
-- which is easy to miss, and a pet left unfed leaves. So the mood also has a cue of its own, away from the bars:
--   * in the world (the screen awake: a fight, a pulled trigger, an enemy targeted, anything going on): small and
--     plain, but obvious: a piece of food that pulses, in the mood's colour (yellow content, red unhappy), just under
--     the top middle of the screen. No words.
--   * at rest (the screen resting: nothing going on): tasteful: the same food, smaller and softer, breathing slowly,
--     with one line beside it ("Your pet is getting hungry", "Your pet is hungry").
-- A line in chat, once, as the mood drops to content and again to unhappy; a short sound at unhappy. Nothing for a
-- happy pet, a pet without a mood (a warlock's, a guardian) or a game that does not say. With Reduce animations it
-- does not pulse. Off in Edit Mode.

local ADDON, ns = ...
local L = ns.L

local PA = { shown = 0 }
ns.PetAlert = PA

ns.RegisterSetting({
    key = "petAlert", kind = "boolean", default = true, command = "petalert", section = "Frames",
    label = "Pet hunger alert",
    tip = "when your pet is content or unhappy (hungry): a piece of food near the top of the screen, small and pulsing while you play, softer with a line of words while the screen rests; once in chat and a sound when it is unhappy. Nothing for a happy pet",
})

PA.TICK = 0.25
PA.Y = -92
PA.COLORS = { [2] = { 1, 0.82, 0.25 }, [1] = { 1, 0.3, 0.22 } }     -- content, unhappy
PA.SOUND = 8959                                                      -- the raid warning's

local frame
local function Build()
    if frame then return frame end
    frame = CreateFrame("Frame", "ControllerCamHUD_PetAlert", UIParent)
    frame:SetFrameStrata("HIGH")
    frame:SetSize(280, 40)
    frame:SetPoint("TOP", UIParent, "TOP", 0, PA.Y)
    frame:SetIgnoreParentAlpha(true)                         -- (never faded with the rest of the screen)
    frame.glow = frame:CreateTexture(nil, "BACKGROUND")
    frame.glow:SetTexture(ns.media and ns.media.soft or "Interface\\Buttons\\WHITE8X8")
    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetTexture("Interface\\Icons\\INV_Misc_Food_14")
    frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    frame.text = ns.FontString(frame, 12, "LEFT")
    frame:Hide()
    return frame
end

-- 1 unhappy, 2 content (nil: nothing to say, or a happy pet)
function PA.Mood()
    if not (ns.db and ns.db.petAlert) or ns.arranging then return nil end
    if not (UnitExists and ns.Yes(UnitExists("pet"))) then return nil end
    local UF = ns.UnitFrames
    local mood = UF and UF.PetMood and UF.PetMood()
    if mood == 1 or mood == 2 then return mood end
end

-- The screen resting (nothing going on), as the HUD's fade has it
function PA.Resting()
    local R = ns.Rest
    return (R and R.active and (R.alpha or 1) < 0.95) and true or false
end

local function Place(f, mood, resting)
    local c = PA.COLORS[mood]
    local size = resting and 22 or 30
    f.icon:SetSize(size, size)
    f.icon:ClearAllPoints()
    f.glow:ClearAllPoints()
    f.glow:SetPoint("CENTER", f.icon, "CENTER", 0, 0)
    f.glow:SetSize(size * 2.6, size * 2.6)
    f.glow:SetVertexColor(c[1], c[2], c[3], 1)
    if resting then
        f.text:Show()
        f.text:SetText(mood == 1 and L["Your pet is hungry"] or L["Your pet is getting hungry"])
        f.text:SetTextColor(c[1], c[2], c[3])
        f:SetSize(280, 28)
        f.icon:SetPoint("LEFT", f, "LEFT", 4, 0)
        f.text:ClearAllPoints()
        f.text:SetPoint("LEFT", f.icon, "RIGHT", 8, 0)
    else
        f.text:Hide()
        f:SetSize(size + 8, size + 8)
        f.icon:SetPoint("CENTER", f, "CENTER", 0, 0)
    end
end

function PA.Update()
    local mood = PA.Mood()
    if mood ~= PA.mood then                                  -- a change: said once
        local was = PA.mood
        PA.mood = mood
        if mood == 2 and (was == nil or was == 3) then
            ns.Say(L["Your pet is getting hungry."])
        elseif mood == 1 then
            ns.Say(L["Your pet is hungry: feed it."])
            local sound = (SOUNDKIT and SOUNDKIT.RAID_WARNING) or PA.SOUND
            if PlaySound then pcall(PlaySound, sound) end
        end
    end
    if not mood then
        if frame then frame:Hide() end
        PA.shape = nil
        return
    end
    local resting = PA.Resting()
    local f = Build()
    local shape = mood .. (resting and "r" or "w")
    if shape ~= PA.shape then
        PA.shape = shape
        Place(f, mood, resting)
    end
    -- the pulse: slow and soft at rest; quick and plain in the world (unhappy), steady when content
    local calm = ns.Calm and ns.Calm()
    local t = GetTime and GetTime() or 0
    local a
    if calm then
        a = resting and 0.75 or 1
    elseif resting then
        a = 0.6 + 0.2 * math.sin(t * 1.6)
    elseif mood == 1 then
        a = 0.75 + 0.25 * math.sin(t * 5)
    else
        a = 0.9
    end
    f:SetAlpha(a)
    f.glow:SetAlpha(resting and 0.35 or 0.55)
    if not f:IsShown() then f:Show(); PA.shown = PA.shown + 1 end
end

local acc = 0
local watcher = CreateFrame("Frame")
watcher:SetScript("OnUpdate", ns.Protect(function(_, dt)
    acc = acc + (dt or 0)
    if acc < PA.TICK and not (frame and frame:IsShown()) then return end
    if acc < PA.TICK * 0.5 then return end                   -- (the pulse reads smoothly)
    acc = 0
    PA.Update()
end))
for _, e in ipairs({ "UNIT_HAPPINESS", "UNIT_PET", "PET_UI_UPDATE", "PLAYER_ENTERING_WORLD" }) do
    pcall(watcher.RegisterEvent, watcher, e)
end
watcher:SetScript("OnEvent", ns.Protect(function() PA.Update() end))
