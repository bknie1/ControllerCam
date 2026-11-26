-- ControllerCam options: Options > AddOns > ControllerCam (situations) and ControllerCam > Profiles (editor, sharing).

local ADDON, ns = ...
local L = ns.L

local refreshing = false
local refreshers = {}      -- functions run whenever a panel is shown or data changes

local function Tooltip(frame, text)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(text, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- A tooltip with a profile's name, what it feels like and what it changes. getId: a function (the profile can
-- change while the button stays).
local function ProfileTooltip(frame, getId)
    frame:SetScript("OnEnter", function(self)
        local id = getId()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if not id then
            GameTooltip:SetText(L["(no change)"], 1, 1, 1)
            GameTooltip:AddLine(L["Left-click: next profile. Right-click: previous profile. The first entry, no change, leaves the camera alone."], 0.8, 0.8, 0.8, true)
        else
            local name, desc, rows = ns.DescribeProfile(id)
            GameTooltip:SetText(name .. (ns.IsEdited(id) and (" " .. L["(edited)"]) or ""), 1, 0.82, 0)
            GameTooltip:AddLine(desc, 1, 1, 1, true)
            for _, row in ipairs(rows) do GameTooltip:AddDoubleLine(row[1], row[2], 0.7, 0.7, 0.7, 1, 1, 1) end
            GameTooltip:AddLine(L["Left-click: next profile. Right-click: previous profile."], 0.5, 0.5, 0.5, true)
        end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function RefreshAll()
    if not ns.db then return end
    refreshing = true
    for _, fn in ipairs(refreshers) do fn() end
    refreshing = false
end
ns.RefreshOptions = RefreshAll

local function MakeButton(parent, label, tip, w, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w or 180, 24)
    b:SetText(label)
    local fs = b:GetFontString()                         -- widen for longer translations
    if fs then b:SetWidth(math.max(w or 180, fs:GetStringWidth() + 30)) end
    b:SetScript("OnClick", onClick)
    if tip then Tooltip(b, tip) end
    return b
end

local function MakeCheckbox(parent, name, label, tip, get, set)
    local cb = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
    local text = cb.Text or (name and _G[name .. "Text"])
    if text then text:SetText(label) end
    cb:SetScript("OnClick", function(self)
        if not refreshing then set(self:GetChecked() and true or false); RefreshAll() end
    end)
    if tip then Tooltip(cb, tip) end
    refreshers[#refreshers + 1] = function() cb:SetChecked(get()) end
    return cb
end

---------------------------------------------------------------------------
-- A small popup with a text box: used to show an export string and to paste one for import.
---------------------------------------------------------------------------
local box
local function EnsureBox()
    if box then return box end
    box = CreateFrame("Frame", "ControllerCamTextBox", UIParent, "BackdropTemplate")
    box:SetSize(520, 150)
    box:SetPoint("CENTER")
    box:SetFrameStrata("DIALOG")
    if box.SetBackdrop then
        box:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                          edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                          tile = true, tileSize = 32, edgeSize = 32, insets = { left = 8, right = 8, top = 8, bottom = 8 } })
    end
    box:EnableMouse(true)
    box:Hide()
    box.title = box:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    box.title:SetPoint("TOP", 0, -16)
    box.edit = CreateFrame("EditBox", "ControllerCamTextBoxEdit", box, "InputBoxTemplate")
    box.edit:SetSize(470, 24)
    box.edit:SetPoint("TOP", box.title, "BOTTOM", 0, -16)
    box.edit:SetAutoFocus(false)
    box.edit:SetMaxLetters(1500)
    box.edit:SetScript("OnEscapePressed", function() box:Hide() end)
    box.hint = box:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    box.hint:SetPoint("TOP", box.edit, "BOTTOM", 0, -6)
    box.ok = MakeButton(box, L["Import"], nil, 120, function()
        local id, err = ns.ImportString(box.edit:GetText())
        if id then
            ns.Say((L["Imported '%s'. /ccam use \"%s\" to try it."]):format(ns.ProfileName(id), ns.ProfileName(id)))
            if ns.SelectProfile then ns.SelectProfile(id) end
            box:Hide()
            RefreshAll()
        else
            box.hint:SetText("|cffff5555" .. err .. "|r")
        end
    end)
    box.ok:SetPoint("BOTTOMRIGHT", -140, 16)
    box.close = MakeButton(box, L["Close"], nil, 120, function() box:Hide() end)
    box.close:SetPoint("BOTTOMRIGHT", -16, 16)
    return box
end

-- text: show it, selected, for copying.  nil text: an empty box to paste an import string into.
function ns.ShowTextBox(title, text)
    local b = EnsureBox()
    b.title:SetText(title)
    b.edit:SetText(text or "")
    if text then
        b.hint:SetText(L["Press Ctrl+C to copy, then Esc."])
        b.ok:Hide()
        b.edit:HighlightText()
    else
        b.hint:SetText(L["Paste a ControllerCam string here (Ctrl+V), then press Import."])
        b.ok:Show()
    end
    b:Show()
    b.edit:SetFocus()
end

---------------------------------------------------------------------------
-- Main panel: situations
---------------------------------------------------------------------------
local panel = CreateFrame("Frame", "ControllerCamOptionsPanel")
panel.name = "ControllerCam"

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("ControllerCam")

local blurb = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
blurb:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
blurb:SetWidth(560)
blurb:SetJustifyH("LEFT")
blurb:SetText(L["Camera profiles for controller play. Pick what the camera feels like in each situation. Left-click a profile to go to the next one, right-click for the previous one."])

local status = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
status:SetPoint("TOPLEFT", blurb, "BOTTOMLEFT", 0, -12)
status:SetJustifyH("LEFT")

local enabled = MakeCheckbox(panel, "ControllerCamOptEnabled", L["Enable ControllerCam"],
    L["Turn the camera control on or off. When off, your original camera settings are put back."],
    function() return ns.db.enabled end, function(v) ns.SetEnabled(v) end)
enabled:SetPoint("TOPLEFT", status, "BOTTOMLEFT", -2, -8)

-- Quick picks: the default experience first, the game's own camera last
local quickLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
quickLabel:SetPoint("TOPLEFT", enabled, "BOTTOMLEFT", 2, -10)
quickLabel:SetText(L["Quick pick:"])

local qs = MakeButton(panel, L["Recommended setup"], L["Action camera with calmer profiles for cities, mounts, flying and raids."], 150,
    function() ns.ApplyStarter(); RefreshAll() end)
qs:SetPoint("TOPLEFT", quickLabel, "BOTTOMLEFT", 0, -6)
local qa = MakeButton(panel, L["Action"], nil, 110,
    function() ns.UseEverywhere("action"); RefreshAll() end)
ProfileTooltip(qa, function() return "action" end)
qa:SetPoint("LEFT", qs, "RIGHT", 6, 0)
local qh = MakeButton(panel, L["Hybrid"], nil, 110,
    function() ns.UseEverywhere("hybrid"); RefreshAll() end)
ProfileTooltip(qh, function() return "hybrid" end)
qh:SetPoint("LEFT", qa, "RIGHT", 6, 0)
local qc = MakeButton(panel, L["Classic"], nil, 110,
    function() ns.UseEverywhere("classic"); RefreshAll() end)
ProfileTooltip(qc, function() return "classic" end)
qc:SetPoint("LEFT", qh, "RIGHT", 6, 0)

-- One row per situation: a button that cycles through the profiles.
local rowsHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
rowsHeader:SetPoint("TOPLEFT", qs, "BOTTOMLEFT", 0, -14)
rowsHeader:SetText(L["Profile for each situation (the first one that applies wins, from the top):"])

local function Cycle(sit, step)
    local ids = ns.ProfileIds()
    local cur = ns.db.assign[sit]
    local idx = 0                                        -- 0 = "no change"
    for i, id in ipairs(ids) do if id == cur then idx = i end end
    idx = (idx + step) % (#ids + 1)
    ns.Assign(sit, idx == 0 and nil or ids[idx])
    RefreshAll()
end

local prev = rowsHeader
for _, sit in ipairs(ns.SITUATIONS) do
    local label = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, (prev == rowsHeader) and -8 or -9)
    label:SetWidth(200)
    label:SetJustifyH("LEFT")
    label:SetText(ns.SITUATION_LABEL[sit])

    local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btn:SetSize(220, 20)
    btn:SetPoint("LEFT", label, "RIGHT", 8, 0)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetScript("OnClick", function(_, mouse) Cycle(sit, mouse == "RightButton" and -1 or 1) end)
    ProfileTooltip(btn, function() return ns.db.assign[sit] end)
    refreshers[#refreshers + 1] = function()
        local id = ns.db.assign[sit]
        btn:SetText(id and ns.ProfileName(id) or L["(no change)"])
    end
    prev = label
end

local delay = CreateFrame("Slider", "ControllerCamOptDelay", panel, "OptionsSliderTemplate")
delay:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 6, -34)
delay:SetWidth(240)
delay:SetMinMaxValues(0, 10)
delay:SetValueStep(0.5)
if delay.SetObeyStepOnDrag then delay:SetObeyStepOnDrag(true) end
local delayText = _G["ControllerCamOptDelayText"]
local function DelayLabel(v) if delayText then delayText:SetText((L["Keep a situation for %.1f s after it ends"]):format(v)) end end
if _G["ControllerCamOptDelayLow"] then _G["ControllerCamOptDelayLow"]:SetText("0") end
if _G["ControllerCamOptDelayHigh"] then _G["ControllerCamOptDelayHigh"]:SetText("10") end
delay:SetScript("OnValueChanged", function(_, value)
    DelayLabel(value)
    if not refreshing then ns.SetExitDelay(value) end
end)
Tooltip(delay, L["Stops the camera from flickering between profiles when a situation switches on and off quickly."])
refreshers[#refreshers + 1] = function() delay:SetValue(ns.db.exitDelay); DelayLabel(ns.db.exitDelay) end

-- Your overall strength of the shoulder offset, beside the delay
local strength = CreateFrame("Slider", "ControllerCamOptOffset", panel, "OptionsSliderTemplate")
strength:SetPoint("LEFT", delay, "RIGHT", 60, 0)
strength:SetWidth(220)
strength:SetMinMaxValues(0, 200)
strength:SetValueStep(5)
if strength.SetObeyStepOnDrag then strength:SetObeyStepOnDrag(true) end
local strengthText = _G["ControllerCamOptOffsetText"]
local function StrengthLabel(v) if strengthText then strengthText:SetText((L["Shoulder offset strength: %d%%"]):format(v + 0.5)) end end
if _G["ControllerCamOptOffsetLow"] then _G["ControllerCamOptOffsetLow"]:SetText("0") end
if _G["ControllerCamOptOffsetHigh"] then _G["ControllerCamOptOffsetHigh"]:SetText("200") end
strength:SetScript("OnValueChanged", function(_, value)
    StrengthLabel(value)
    if not refreshing then ns.SetOffsetScale(value / 100) end
end)
Tooltip(strength, L["Moves the over-the-shoulder camera further out or back toward the middle, in every profile. Handy if your character's size makes it sit differently."])
refreshers[#refreshers + 1] = function()
    strength:SetValue(ns.db.offsetScale * 100); StrengthLabel(ns.db.offsetScale * 100)
end

-- Closer on an enemy target (0: off)
local near = CreateFrame("Slider", "ControllerCamOptTargetZoom", panel, "OptionsSliderTemplate")
near:SetPoint("TOPLEFT", delay, "BOTTOMLEFT", 0, -34)
near:SetWidth(240)
near:SetMinMaxValues(0, 15)
near:SetValueStep(0.5)
if near.SetObeyStepOnDrag then near:SetObeyStepOnDrag(true) end
local nearText = _G["ControllerCamOptTargetZoomText"]
local function NearLabel(v)
    if not nearText then return end
    if v > 0 then nearText:SetText((L["Closer on an enemy target: %.1f yards"]):format(v))
    else nearText:SetText(L["Closer on an enemy target: off"]) end
end
if _G["ControllerCamOptTargetZoomLow"] then _G["ControllerCamOptTargetZoomLow"]:SetText(L["off"]) end
if _G["ControllerCamOptTargetZoomHigh"] then _G["ControllerCamOptTargetZoomHigh"]:SetText("15") end
near:SetScript("OnValueChanged", function(_, value)
    NearLabel(value)
    if not refreshing then ns.SetTargetZoom(value) end
end)
Tooltip(near, L["Target an enemy and the camera comes in to this distance; let it go and it goes back to where you had it (not while mounted). Roam far out, fight up close."])
refreshers[#refreshers + 1] = function() near:SetValue(ns.db.targetZoom or 0); NearLabel(ns.db.targetZoom or 0) end

local flip = MakeCheckbox(panel, "ControllerCamOptFlip", L["Mirror the shoulder offset (other shoulder)"],
    L["Swaps which shoulder the camera looks over."],
    function() return ns.db.flipShoulder end, function(v) ns.SetFlipShoulder(v) end)
flip:SetPoint("TOPLEFT", near, "BOTTOMLEFT", -8, -16)

local moving = MakeCheckbox(panel, "ControllerCamOptMovement", L["Profiles also set how you move and the stick's speeds"],
    L["Facing and turning as you move, and the stick's camera speeds, set by each profile. Off: your own settings, as you had them."],
    function() return ns.db.movement == true end, function(v) ns.SetMovement(v) end)
moving:SetPoint("TOPLEFT", flip, "BOTTOMLEFT", 0, -4)

local nowDesc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
nowDesc:SetPoint("TOPLEFT", moving, "BOTTOMLEFT", 2, -10)
nowDesc:SetWidth(560)
nowDesc:SetJustifyH("LEFT")

local helpText = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
helpText:SetPoint("TOPLEFT", nowDesc, "BOTTOMLEFT", 0, -10)
helpText:SetJustifyH("LEFT")
helpText:SetText(L["Slash commands: /ccam help"])

refreshers[#refreshers + 1] = function()
    local st = ns.Status()
    nowDesc:SetText(st.id and (st.profile .. ": " .. ns.ProfileDescription(st.id)) or "")
    if st.profile then
        status:SetText((L["Now: %s (%s)"]):format(st.profile, st.sit == "force" and L["forced"] or ns.SITUATION_LABEL[st.sit]))
    else
        status:SetText(L["Now: nothing applied yet"])
    end
end

panel:SetScript("OnShow", RefreshAll)
panel.OnRefresh = RefreshAll
panel.OnCommit = function() end
panel.OnDefault = function() ns.ApplyStarter(); RefreshAll() end

---------------------------------------------------------------------------
-- Second panel: profiles (pick, copy, share) and the setting editor
---------------------------------------------------------------------------
local pp = CreateFrame("Frame", "ControllerCamProfilesPanel")
pp.name = L["Profiles"]

local ptitle = pp:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
ptitle:SetPoint("TOPLEFT", 16, -16)
ptitle:SetText("ControllerCam - " .. L["Profiles"])

local selected                                           -- profile id being shown
function ns.SelectProfile(id) selected = id end
local function Selected()
    if not selected or not ns.GetProfile(selected) then selected = "action" end
    return selected
end

local selBtn = CreateFrame("Button", nil, pp, "UIPanelButtonTemplate")
selBtn:SetSize(240, 24)
selBtn:SetPoint("TOPLEFT", ptitle, "BOTTOMLEFT", 0, -12)
selBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
selBtn:SetScript("OnClick", function(_, mouse)
    local ids = ns.ProfileIds()
    local idx = 1
    for i, id in ipairs(ids) do if id == Selected() then idx = i end end
    idx = ((idx - 1 + (mouse == "RightButton" and -1 or 1)) % #ids) + 1
    selected = ids[idx]
    RefreshAll()
end)
Tooltip(selBtn, L["Left-click: next profile. Right-click: previous profile."])

local descText = pp:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
descText:SetPoint("TOPLEFT", selBtn, "BOTTOMLEFT", 0, -8)
descText:SetWidth(560)
descText:SetJustifyH("LEFT")

local function Act(fn) return function() fn(); RefreshAll() end end

local bUse = MakeButton(pp, L["Use everywhere"], L["Use this profile in every situation."], 130,
    Act(function() ns.UseEverywhere(Selected()) end))
bUse:SetPoint("TOPLEFT", descText, "BOTTOMLEFT", 0, -10)
local bCopy = MakeButton(pp, L["Make a copy"], L["Makes an editable copy of this profile."], 110,
    Act(function() selected = ns.DuplicateProfile(Selected()) or selected end))
bCopy:SetPoint("LEFT", bUse, "RIGHT", 6, 0)
local bSave = MakeButton(pp, L["Save my current camera"], L["Saves the camera settings you have right now as a new profile."], 170,
    Act(function() selected = ns.CaptureCurrent(L["My profile"]) or selected end))
bSave:SetPoint("LEFT", bCopy, "RIGHT", 6, 0)
local bExport = MakeButton(pp, L["Export"], L["Shows a string you can share."], 90,
    function() ns.ShowTextBox(ns.ProfileName(Selected()), ns.ExportById(Selected())) end)
bExport:SetPoint("TOPLEFT", bUse, "BOTTOMLEFT", 0, -6)
local bImport = MakeButton(pp, L["Import"], L["Add a profile from a shared string."], 90,
    function() ns.ShowTextBox(L["Import"], nil) end)
bImport:SetPoint("LEFT", bExport, "RIGHT", 6, 0)
local bDelete = MakeButton(pp, L["Delete"], L["Deletes this custom profile."], 90,
    Act(function() local id = Selected(); if not ns.IsBuiltin(id) then ns.DeleteProfile(id); selected = nil end end))
bDelete:SetPoint("LEFT", bImport, "RIGHT", 6, 0)
local bReset = MakeButton(pp, L["Reset to original"], L["Puts this built-in profile back to its original settings."], 140,
    Act(function() ns.ResetBuiltin(Selected()) end))
bReset:SetPoint("LEFT", bDelete, "RIGHT", 6, 0)

local advanced = MakeCheckbox(pp, "ControllerCamOptAdvanced", L["Advanced: show and edit every setting"],
    L["Shows every setting, in groups, and lets you change the built-in profiles too. Your changes are kept, and Reset to original brings the original back."],
    function() return ns.db.advanced end, function(v) ns.SetAdvanced(v) end)
advanced:SetPoint("TOPLEFT", ptitle, "TOPRIGHT", 40, 8)

local readonly = pp:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
readonly:SetPoint("TOPLEFT", bExport, "BOTTOMLEFT", 0, -10)
readonly:SetWidth(560)
readonly:SetJustifyH("LEFT")

-- The editor: a menu of areas (one per group of settings) over a scrolling page for the chosen one. Only shown
-- when the profile can be edited; otherwise the presets stay the whole story.
local menu = CreateFrame("Frame", nil, pp)
menu:SetPoint("TOPLEFT", readonly, "BOTTOMLEFT", 0, -8)

local scroll = CreateFrame("ScrollFrame", "ControllerCamEditorScroll", pp, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", menu, "BOTTOMLEFT", 0, -8)
scroll:SetPoint("BOTTOMRIGHT", pp, "BOTTOMRIGHT", -30, 12)
local content = CreateFrame("Frame", nil, scroll)
content:SetSize(630, 10)
scroll:SetScrollChild(content)

local editors = {}
local areas = {}                 -- group id -> { frame, button, help, height }
local area = ns.GROUPS[1].id     -- the one on show
ns.editorAreas = areas

local function SetEditable(widget, on)
    widget:SetAlpha(on and 1 or 0.5)
    if widget.SetEnabled then widget:SetEnabled(on) end
end

local function SetShown(widget, on)
    if on then widget:Show() else widget:Hide() end
end

local function DisplayValue(s, v)
    return ns.FormatSettingValue(s, v)
end

local function CurveToText(c)
    return c and ns.FormatSettingValue(ns.SETTING_BY_KEY.shoulderCurve, c) or ""
end

local function Line(parent, font, x, y, width, text)
    local fs = parent:CreateFontString(nil, "ARTWORK", font)
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetWidth(width)
    fs:SetJustifyH("LEFT")
    if text then fs:SetText(text) end
    return fs
end

local function MakeSlider(parent, x, y, lo, hi, step, onChange)
    local sl = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    sl:SetPoint("TOPLEFT", x, y)
    sl:SetWidth(170)
    sl:SetMinMaxValues(lo, hi)
    sl:SetValueStep(step)
    if sl.SetObeyStepOnDrag then sl:SetObeyStepOnDrag(true) end
    for _, part in ipairs({ "Text", "Low", "High" }) do         -- the template's own labels: the row has its own
        local fs = sl[part]
        if type(fs) == "table" and fs.SetText then fs:SetText("") end
    end
    sl:SetScript("OnValueChanged", function(_, v)
        if refreshing then return end
        onChange(v)
        RefreshAll()
    end)
    return sl
end

-- The table by zoom view over a "by zoom" setting: its switch, then one slider for each view
local VIEW_TABLES = {
    shoulderCurve = { switch = L["Change the offset with zoom"],
        help = L["How far to the side at each distance. The camera eases from one to the next."],
        lo = 0, hi = 4, step = 0.1, per = 1, text = function(v) return ns.FormatNumber(v) end },
    focusCurve = { switch = L["Change the target focus with zoom"],
        help = L["How much of your target focus strength at each distance. Off: all of it everywhere."],
        lo = 0, hi = 100, step = 5, per = 100, text = function(v) return ("%d%%"):format(v * 100 + 0.5) end },
    fovCurve = { switch = L["Change the field of view with zoom"],
        help = L["The field of view at each distance, as a share of your own. Off: yours is left alone."],
        lo = 80, hi = 120, step = 1, per = 100, text = function(v) return ("%d%%"):format(v * 100 + 0.5) end },
}
local VIEW_TABLE_HEIGHT = 62 + 30 * #ns.ZOOM_VIEWS

local function ViewTable(parent, s, y)
    local spec = VIEW_TABLES[s.key]
    local box = CreateFrame("Frame", nil, parent)
    box:SetPoint("TOPLEFT", 0, y)
    box:SetSize(630, VIEW_TABLE_HEIGHT)

    local name = "ControllerCamOptByZoom_" .. s.key
    local switch = CreateFrame("CheckButton", name, box, "UICheckButtonTemplate")
    switch:SetPoint("TOPLEFT", 4, 0)
    local switchText = switch.Text or _G[name .. "Text"]        -- (named by either of the template's ways)
    if switchText then switchText:SetText(spec.switch) end
    switch:SetScript("OnClick", function(self)
        if refreshing then return end
        ns.SetByZoom(Selected(), s.key, self:GetChecked() and true or false)
        RefreshAll()
    end)
    Line(box, "GameFontDisableSmall", 8, -26, 600, spec.help)
    local here = Line(box, "GameFontHighlightSmall", 8, -42, 600)

    local rows = {}
    for i, view in ipairs(ns.ZOOM_VIEWS) do
        local ry = -62 - (i - 1) * 30
        local label = Line(box, "GameFontHighlightSmall", 24, ry, 236,
            (L["%s (%s to %s yards)"]):format(L[view.name], ns.FormatNumber(view.from), ns.FormatNumber(view.to)))
        local value = Line(box, "GameFontNormalSmall", 262, ry, 110)
        local slider = MakeSlider(box, 380, ry - 2, spec.lo, spec.hi, spec.step, function(v)
            local x = math.min(math.max(v, spec.lo), spec.hi) / spec.per
            ns.SetViewValue(Selected(), s.key, i, ns.Round(x, 2))
        end)
        rows[i] = { label = label, value = value, slider = slider }
    end

    local function Refresh(p, editable)
        local curve = p.values[s.key]
        local values = curve and ns.ViewValues(curve)
        switch:SetChecked(curve ~= nil)
        SetEditable(switch, editable)
        local zoom = tonumber(GetCameraZoom and GetCameraZoom())
        local at = zoom and ns.ViewAt(zoom)
        here:SetText(at and (L["You are at %.1f yards now: %s."]):format(zoom, L[ns.ZOOM_VIEWS[at].name]) or "")
        for i, row in ipairs(rows) do
            local v = values and values[i]
            row.slider:SetValue((v or ns.VIEW_DEFAULTS[s.key][i]) * spec.per)
            row.value:SetText(v and spec.text(v) or "-")
            SetEditable(row.slider, editable and curve ~= nil)
            if row.label.SetTextColor then                    -- the view you are in, in gold
                if i == at then row.label:SetTextColor(1, 0.82, 0) else row.label:SetTextColor(1, 1, 1) end
            end
        end
    end
    return box, Refresh
end

local ROW_HEIGHT = 46

local function SettingRow(parent, s, y)
    local row = { setting = s }
    Line(parent, "GameFontHighlightSmall", 8, y, 250, L[s.label])
    if s.help then Line(parent, "GameFontDisableSmall", 8, y - 15, 360, L[s.help]) end
    local value = Line(parent, "GameFontNormalSmall", 262, y, 110)
    row.value = value

    if s.kind == "curve" then
        local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
        eb:SetSize(220, 20)
        eb:SetPoint("TOPLEFT", 380, y + 3)
        eb:SetAutoFocus(false)
        eb:SetMaxLetters(200)
        Tooltip(eb, L["Distance and value pairs, for example 0:2 8:2 20:0. Empty: not by zoom. Press Enter to apply."])
        eb:SetScript("OnEnterPressed", function(self)
            local id = Selected()
            local points = {}
            for z, v in self:GetText():gmatch("([^%s:]+):([^%s:]+)") do points[#points + 1] = { tonumber(z), tonumber(v) } end
            if #points == 0 then ns.SetValue(id, s.key, nil) else ns.SetValue(id, s.key, points) end
            self:ClearFocus()
            RefreshAll()
        end)
        row.widget = eb
        row.refresh = function(p, editable)
            eb:SetText(CurveToText(p.values[s.key]))
            SetEditable(eb, editable)
            value:SetText(p.values[s.key] and "" or L["off"])
        end
    elseif s.kind == "bool" then
        local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 376, y + 6)
        cb:SetScript("OnClick", function(self)
            if refreshing then return end
            ns.SetValue(Selected(), s.key, self:GetChecked() and 1 or 0)
            RefreshAll()
        end)
        row.widget = cb
        row.refresh = function(p, editable)
            local v = p.values[s.key]
            cb:SetChecked(v == 1)
            SetEditable(cb, editable)
            value:SetText(DisplayValue(s, v))
        end
    else
        local lo, hi = s.min, s.max
        local sl = MakeSlider(parent, 380, y - 2, lo, hi, s.step or 1, function(v)
            if s.kind == "mul" then v = "x" .. ns.FormatNumber(v) end
            ns.SetValue(Selected(), s.key, v)
        end)
        row.widget = sl
        row.refresh = function(p, editable)
            local v = p.values[s.key]
            local byZoom = s.key == "shoulder" and p.values.shoulderCurve ~= nil
            local shown = v
            if v == "d" or v == nil then shown = (s.kind == "mul") and 1 or (s.key == "shoulder" and 0 or lo)
            elseif s.kind == "mul" then shown = tonumber(v:sub(2)) end
            sl:SetValue(shown)
            SetEditable(sl, editable and not byZoom)
            value:SetText(byZoom and L["by zoom"] or DisplayValue(s, v))
        end
    end

    if s.kind ~= "curve" then
        local reset = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        reset:SetSize(64, 20)
        reset:SetPoint("TOPLEFT", 560, y + 2)
        reset:SetText(L["Default"])
        reset:SetScript("OnClick", function()
            ns.SetValue(Selected(), s.key, nil)
            RefreshAll()
        end)
        Tooltip(reset, L["Use the game's default for this setting."])
        row.reset = reset
    end
    editors[#editors + 1] = row
end

local function BuildArea(group)
    local frame = CreateFrame("Frame", nil, content)
    frame:SetPoint("TOPLEFT", 0, 0)
    local a = { frame = frame, group = group }
    a.help = Line(frame, "GameFontHighlight", 0, -4, 600, L[group.help])
    local y = -48

    local list = {}
    for _, s in ipairs(ns.SETTINGS) do
        if s.group == group.id then list[#list + 1] = s end
    end

    local function Table(s)
        local box, refresh = ViewTable(frame, s, y)
        if s.probe then                  -- a setting this game may not have: say so in its place instead
            a.probe = { box = box, top = y }
            a.probe.missing = Line(frame, "GameFontDisableSmall", 8, y, 600,
                L["This game has no field of view setting that add-ons can change."])
        end
        editors[#editors + 1] = { setting = s, refresh = refresh }
        y = y - VIEW_TABLE_HEIGHT - 8
        return box
    end

    -- the offset's table is what most people come here for: first in its area
    for _, s in ipairs(list) do
        if s.key == "shoulderCurve" then Table(s) end
    end
    for _, s in ipairs(list) do
        local box = s.kind == "curve" and s.key ~= "shoulderCurve" and Table(s)
        if s.probe then
            SettingRow(box, s, -VIEW_TABLE_HEIGHT - 8)       -- (its points: gone with the table)
        else
            SettingRow(frame, s, y)
        end
        y = y - ROW_HEIGHT
    end
    a.height = -y + 12
    frame:SetSize(630, a.height)
    return a
end

-- the menu: a button for each area, onto a second line when a language needs it
local mx, my = 0, 0
for _, group in ipairs(ns.GROUPS) do
    local a = BuildArea(group)
    local b = MakeButton(menu, L[group.id], L[group.help], 84, function()
        area = group.id
        if scroll.SetVerticalScroll then scroll:SetVerticalScroll(0) end
        RefreshAll()
    end)
    local fs = b:GetFontString()
    local w = math.max(84, (fs and fs:GetStringWidth() or 0) + 30)
    if mx + w > 630 and mx > 0 then mx, my = 0, my - 26 end
    b:SetPoint("TOPLEFT", mx, my)
    mx = mx + w + 4
    a.button = b
    areas[group.id] = a
end
menu:SetSize(630, 24 - my)

refreshers[#refreshers + 1] = function()
    local id = Selected()
    local p = ns.GetProfile(id)
    descText:SetText(ns.ProfileDescription(id))
    local editable = ns.IsEditable(id)
    SetEditable(bDelete, not ns.IsBuiltin(id))
    SetEditable(bReset, ns.IsEdited(id))
    selBtn:SetText(ns.ProfileName(id) .. (ns.IsEdited(id) and (" " .. L["(edited)"]) or ""))
    if editable and ns.IsBuiltin(id) then
        readonly:SetText(L["Advanced editing is on. Changes to a built-in profile are kept; Reset to original brings it back."])
    elseif editable then
        readonly:SetText(L["Settings not listed use the game default. Pick a group below to see its settings."])
    else
        readonly:SetText(L["The presets are all most people need. To change one, make a copy, or tick Advanced to see every setting."])
    end
    SetShown(menu, editable)
    SetShown(scroll, editable)

    local height = areas[area].height
    for groupId, a in pairs(areas) do
        SetShown(a.frame, groupId == area)
        local mark = groupId == area and a.button.LockHighlight or a.button.UnlockHighlight
        if mark then mark(a.button) end
        local text = L[a.group.help]
        if ns.MOVEMENT_GROUPS[groupId] and ns.db.movement ~= true then
            text = text .. " |cffff9933" .. L["Only used once you let the profiles set how you move (ControllerCam's first page)."] .. "|r"
        end
        a.help:SetText(text)
        if a.probe then
            local has = ns.FovCVar() ~= nil
            SetShown(a.probe.box, has)
            SetShown(a.probe.missing, not has)
            if groupId == area and not has then height = -a.probe.top + 40 end
        end
    end
    for _, row in ipairs(editors) do
        row.refresh(p, editable)
        if row.reset then SetEditable(row.reset, editable) end
    end
    content:SetHeight(height)
end

pp:SetScript("OnShow", RefreshAll)
pp.OnRefresh = RefreshAll
pp.OnCommit = function() end
pp.OnDefault = function() end

---------------------------------------------------------------------------
-- Register in Options > AddOns
---------------------------------------------------------------------------
if Settings and Settings.RegisterCanvasLayoutCategory then
    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    if Settings.RegisterCanvasLayoutSubcategory then
        Settings.RegisterCanvasLayoutSubcategory(category, pp, pp.name)
    end
    Settings.RegisterAddOnCategory(category)
    ControllerCamSettings = { category = category }      -- the HUD (a second addon) puts its pages under ours
    ns.OpenOptions = function()
        local id = category.GetID and category:GetID() or category.ID
        Settings.OpenToCategory(id)
    end
elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
    pp.parent = panel.name
    InterfaceOptions_AddCategory(pp)
    ns.OpenOptions = function()
        InterfaceOptionsFrame_OpenToCategory(panel)
        InterfaceOptionsFrame_OpenToCategory(panel)
    end
end

ns.OnDBReady = RefreshAll
