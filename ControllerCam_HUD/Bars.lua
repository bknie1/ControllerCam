-- ControllerCam HUD: slimmer gamepad action bars.
-- The game's gamepad bars keep doing everything they do: buttons, bindings, the held-trigger sets, the action
-- editor, compact mode. This only takes weight off them: the heavy background art is made invisible and the
-- whole cluster is drawn smaller. Off by default.

local ADDON, ns = ...
local L = ns.L

local B = { active = false, hidden = {} }
ns.Bars = B

ns.RegisterSetting({
    key = "bars", kind = "boolean", default = false, command = "bars", section = "Gamepad bars",
    label = "Slim gamepad bars", tip = "hide the heavy art behind the gamepad action bars and draw them smaller",
})
ns.RegisterSetting({
    key = "barScale", kind = "number", default = 0.85, min = 0.6, max = 1.2, percent = true, command = "barscale",
    section = "Gamepad bars", label = "Gamepad bar size", tip = "size of the gamepad bars while slim bars are on, in percent",
})

B.MAIN = "GamepadMainActionBarFrame"
local PAGE = "GamepadMainActionBarFramePageUnit"
B.BARS = {
    PAGE .. "TopCenteredAnchorTopBar", PAGE .. "LeftCenteredAnchorLeftBar",
    PAGE .. "RightCenteredAnchorRightBar", PAGE .. "BottomCenteredAnchorBottomBar",
    PAGE .. "TopCenteredAnchorPossessBar", PAGE .. "TopCenteredAnchorStanceBar",
    PAGE .. "FriendlyTargetingActionBar", PAGE .. "HostileTargetingActionBar", PAGE .. "ShortcutsActionBar",
}
local BAR_ART = { "BackgroundWatermark", "LeftButtonFrame", "RightButtonFrame" }
local PAGE_ART = { "LeftShoulderBackground", "RightShoulderBackground" }
local REASSERT = 0.5          -- the game shows its art again now and then: hide it again this often

-- The art textures that exist in this client
function B:Art()
    local list = {}
    local function add(owner, fields)
        if type(owner) ~= "table" then return end
        for _, field in ipairs(fields) do
            local tex = rawget(owner, field)
            if type(tex) == "table" and tex.SetAlpha then list[#list + 1] = tex end
        end
    end
    for _, name in ipairs(self.BARS) do add(_G[name], BAR_ART) end
    add(_G[PAGE], PAGE_ART)
    return list
end

local function HideArt()
    for _, tex in ipairs(B:Art()) do
        if B.hidden[tex] == nil then                       -- (its own alpha, even if the restyle hid it first)
            B.hidden[tex] = (ns.Skin and ns.Skin.Original(tex)) or tex:GetAlpha() or 1
        end
        tex:SetAlpha(0)
    end
end

local function ShowArt()
    for tex, alpha in pairs(B.hidden) do tex:SetAlpha(alpha) end
    B.hidden = {}
end

local function SetScale(frame, scale)
    (frame.SetScaleBase or frame.SetScale)(frame, scale)
end

local driver = CreateFrame("Frame")
local since = 0
local OnUpdate = ns.Protect(function(_, dt)
    since = since + dt
    if since >= REASSERT then
        since = 0
        HideArt()
    end
end)

function B:Apply(run)
    local db = ns.db
    local main = _G[self.MAIN]
    local want = run and db.bars and not ns.arranging and type(main) == "table" and true or false
    if want then
        if not self.active then
            self.active = true
            self.scaleWas = main:GetScale() or 1
            driver:SetScript("OnUpdate", OnUpdate)
        end
        SetScale(main, self.scaleWas * db.barScale)
        HideArt()
    elseif self.active then
        self.active = false
        driver:SetScript("OnUpdate", nil)
        ShowArt()
        if main then SetScale(main, self.scaleWas or 1) end
        self.scaleWas = nil
    end
end

ns.RegisterCheck(function(row, run, db)
    local main = _G[B.MAIN]
    if not main then
        row("this client has the gamepad action bars", not (run and db.bars), "GamepadMainActionBarFrame not found")
        return
    end
    local want = (run and db.bars and not ns.arranging) and true or false
    row(want and "the gamepad bars are slimmed" or "the gamepad bars are left alone", B.active == want)
    if want then row("the gamepad bars' background art was found", #B:Art() > 0, #B:Art() .. " textures") end
end)

---------------------------------------------------------------------------
-- Compact or full: the game's own Edit Mode setting for its gamepad bars, switched from here
---------------------------------------------------------------------------
function B.CompactSetting()
    local enum = Enum and Enum.EditModeGamepadMainActionBarSetting
    if type(enum) ~= "table" then return nil end
    for k, v in pairs(enum) do
        if type(k) == "string" and k:lower():find("compact") then return v end
    end
end

function B:IsCompact()
    local main = _G[self.MAIN]
    local page = main and main.PageUnit
    if page and page.ShouldUseCompactLayout then
        local ok, v = pcall(page.ShouldUseCompactLayout, page)
        if ok then return v and true or false end
    end
    local setting = self.CompactSetting()
    if main and setting and main.GetSettingValueBool then
        local ok, v = pcall(main.GetSettingValueBool, main, setting)
        if ok then return v and true or false end
    end
    return nil
end

function B:SetCompact(on)
    if InCombatLockdown() then return false, L["Not in combat."] end
    local main = _G[self.MAIN]
    if not main then return false, L["This client has no gamepad bars."] end
    local manager, setting, ok = _G.EditModeManagerFrame, self.CompactSetting(), false
    if setting and type(manager) == "table" and manager.OnSystemSettingChange then
        ok = pcall(manager.OnSystemSettingChange, manager, main, setting, on and 1 or 0)
        if ok and manager.SaveLayouts then pcall(manager.SaveLayouts, manager) end
    end
    if not ok and main.SetUseCompactLayout then ok = pcall(main.SetUseCompactLayout, main, on) end
    if not ok then return false, L["This client does not let addons change it; use Edit Mode."] end
    return true
end

ns.RegisterCommand("compact", function(arg)
    local now = B:IsCompact()
    local want = ns.Toggle(arg, now or false)
    local ok, why = B:SetCompact(want)
    if ok then ns.Say(L["gamepad bars: %s"]:format(want and L["compact"] or L["full"])) else ns.Say(why) end
end, "/cchud compact on | off", "the game's gamepad bars in compact or full mode (the same as its Edit Mode setting)")

ns.RegisterModule("bars", B)
