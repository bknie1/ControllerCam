-- ControllerCam HUD: tooltips follow your cursor.
-- The game puts most tooltips (units in the world, things you point at) in a fixed corner. While the HUD runs
-- they open at your cursor instead, the Gamepad UI's cursor included, except in a fight, where they stay in
-- the corner, out of the way. Tooltips the game anchors to a frame of its own (a buff, a bag slot) are left
-- where they are.
--
-- A tooltip at the cursor sits on top of what you are looking at, so its background and border can be made
-- see-through, as far as you like: the HUD's own glass behind tooltips when the game's frames wear our look,
-- the game's own background otherwise (kept at that level by our timer, and put back when the HUD is off).

local ADDON, ns = ...

local T = { active = false, running = false, faded = {} }
ns.Tooltip = T

T.TIPS = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "EmbeddedItemTooltip",
           "GameTooltipTooltip" }

ns.RegisterSetting({
    key = "tooltipGlass", kind = "number", default = 0.4, min = 0, max = 1, percent = true, command = "tooltipglass",
    section = "Look", label = "Tooltip background",
    tip = "how solid the background and border of tooltips are: 100% is the full dark glass, 0% leaves only the text",
    onChange = function() ns.Tooltip.Glass() end,
})

-- Puts every tooltip's background and border at the level asked for (or back as it was: the HUD is not running)
function T.Glass()
    local S = ns.Skin
    local v = T.running and ns.db.tooltipGlass or 1
    for _, name in ipairs(T.TIPS) do
        local tip = _G[name]
        if type(tip) == "table" then
            local p = S and S.PanelOf and S.PanelOf(tip)
            if p then S.PanelAlpha(p, v) end
            local nine = rawget(tip, "NineSlice")
            if type(nine) == "table" and nine.SetAlpha and nine.GetAlpha then
                if S and S.done and S.done[nine] then
                    T.faded[nine] = nil                     -- our look is on it: the game's own background is put away
                elseif v < 0.995 then
                    if T.faded[nine] == nil then
                        T.faded[nine] = nine:GetAlpha() or 1
                        if S and S.orig then S.orig[nine] = S.orig[nine] or T.faded[nine] end   -- (what "as it was" is)
                    end
                    ns.KeepAlpha(nine, T.faded[nine] * v)
                elseif T.faded[nine] ~= nil then
                    ns.KeepAlpha(nine, nil)
                    nine:SetAlpha(T.faded[nine])
                    if S and S.orig then S.orig[nine] = nil end
                    T.faded[nine] = nil
                end
            end
        end
    end
end

ns.RegisterSetting({
    key = "tooltipCursor", kind = "boolean", default = true, command = "tooltipcursor", section = "General",
    label = "Tooltips follow the cursor", tip = "tooltips open at your cursor instead of the corner of the screen (in a fight they stay in the corner)",
})

local function AtCursor(tooltip, parent)
    if not T.active or not tooltip or not tooltip.SetOwner then return end
    if UnitAffectingCombat("player") then return end         -- in a fight: the game's corner
    local ok = pcall(tooltip.SetOwner, tooltip, parent or UIParent, "ANCHOR_CURSOR_RIGHT", 24, 12)
    if not ok then pcall(tooltip.SetOwner, tooltip, parent or UIParent, "ANCHOR_CURSOR") end
end

function T:Apply(run)
    self.active = run and ns.db.tooltipCursor and true or false
    if self.active and not self.hooked and type(GameTooltip_SetDefaultAnchor) == "function" then
        self.hooked = true
        hooksecurefunc("GameTooltip_SetDefaultAnchor", ns.Protect(AtCursor))
    end
end

-- A key binding to flip it, for a controller button
function ControllerCamHUD_ToggleTooltipCursor() ns.Protect(function()
    ns.db.tooltipCursor = not ns.db.tooltipCursor
    ns.Apply()
    if ns.RefreshOptions then ns.RefreshOptions() end
    ns.Say(ns.db.tooltipCursor and ns.L["Tooltips follow the cursor."] or ns.L["Tooltips stay in their corner."])
end)() end
BINDING_NAME_CCHUD_TOOLTIPCURSOR = ns.L["Tooltips at the cursor: on / off"]

ns.RegisterModule("tooltip", T)
