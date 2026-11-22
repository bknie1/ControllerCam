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

-- Quick picks
local quickLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
quickLabel:SetPoint("TOPLEFT", enabled, "BOTTOMLEFT", 2, -10)
quickLabel:SetText(L["Quick pick (use one profile everywhere):"])

local qa = MakeButton(panel, L["Action"], nil, 110,
    function() ns.UseEverywhere("action"); RefreshAll() end)
ProfileTooltip(qa, function() return "action" end)
qa:SetPoint("TOPLEFT", quickLabel, "BOTTOMLEFT", 0, -6)
local qh = MakeButton(panel, L["Hybrid"], nil, 110,
    function() ns.UseEverywhere("hybrid"); RefreshAll() end)
ProfileTooltip(qh, function() return "hybrid" end)
qh:SetPoint("LEFT", qa, "RIGHT", 6, 0)
local qc = MakeButton(panel, L["Classic"], nil, 110,
    function() ns.UseEverywhere("classic"); RefreshAll() end)
ProfileTooltip(qc, function() return "classic" end)
qc:SetPoint("LEFT", qh, "RIGHT", 6, 0)
local qs = MakeButton(panel, L["Recommended setup"], L["Action camera with calmer profiles for cities, mounts, flying and raids."], 150,
    function() ns.ApplyStarter(); RefreshAll() end)
qs:SetPoint("LEFT", qc, "RIGHT", 6, 0)

-- One row per situation: a button that cycles through the profiles.
local rowsHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
rowsHeader:SetPoint("TOPLEFT", qa, "BOTTOMLEFT", 0, -14)
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

local nowDesc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
nowDesc:SetPoint("TOPLEFT", flip, "BOTTOMLEFT", 2, -10)
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

local advanced = MakeCheckbox(pp, "ControllerCamOptAdvanced", L["Advanced: edit built-in profiles"],
    L["Lets you change the built-in profiles too. Your changes are kept, and Reset to original brings the original back."],
    function() return ns.db.advanced end, function(v) ns.SetAdvanced(v) end)
advanced:SetPoint("TOPLEFT", ptitle, "TOPRIGHT", 40, 8)

local readonly = pp:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
readonly:SetPoint("TOPLEFT", bExport, "BOTTOMLEFT", 0, -10)
readonly:SetWidth(560)
readonly:SetJustifyH("LEFT")

-- The editor: one row per setting, in a scrolling area.
local scroll = CreateFrame("ScrollFrame", "ControllerCamEditorScroll", pp, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", readonly, "BOTTOMLEFT", 0, -8)
scroll:SetPoint("BOTTOMRIGHT", pp, "BOTTOMRIGHT", -30, 12)
local content = CreateFrame("Frame", nil, scroll)
content:SetSize(630, 10)
scroll:SetScrollChild(content)

local editors = {}
local function SetEditable(widget, on)
    widget:SetAlpha(on and 1 or 0.5)
    if widget.SetEnabled then widget:SetEnabled(on) end
end

local function DisplayValue(s, v)
    return ns.FormatSettingValue(s, v)
end

local function CurveToText(c)
    return c and ns.FormatSettingValue(ns.SETTING_BY_KEY.shoulderCurve, c) or ""
end

local y, lastGroup = -4, nil
for _, s in ipairs(ns.SETTINGS) do
    if s.group ~= lastGroup then
        lastGroup = s.group
        local g = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        g:SetPoint("TOPLEFT", 0, y - 6)
        g:SetText(L[s.group])
        y = y - 28
    end

    local row = { setting = s }
    local label = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", 8, y)
    label:SetWidth(250)
    label:SetJustifyH("LEFT")
    label:SetText(L[s.label])

    local value = content:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    value:SetPoint("TOPLEFT", 262, y)
    value:SetWidth(110)
    value:SetJustifyH("LEFT")
    row.value = value

    if s.kind == "curve" then
        local eb = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
        eb:SetSize(170, 20)
        eb:SetPoint("TOPLEFT", 380, y + 3)
        eb:SetAutoFocus(false)
        eb:SetMaxLetters(120)
        Tooltip(eb, L["Zoom distance and offset pairs, for example 0:2 8:2 20:0. Empty = no curve. Press Enter to apply."])
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
        local cb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
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
        local sl = CreateFrame("Slider", nil, content, "OptionsSliderTemplate")
        sl:SetPoint("TOPLEFT", 380, y - 2)
        sl:SetWidth(170)
        local step = s.step or 1
        local lo, hi = s.min, s.max
        sl:SetMinMaxValues(lo, hi)
        sl:SetValueStep(step)
        if sl.SetObeyStepOnDrag then sl:SetObeyStepOnDrag(true) end
        sl:SetScript("OnValueChanged", function(self, v)
            if refreshing then return end
            if s.kind == "mul" then v = "x" .. ns.FormatNumber(v) end
            ns.SetValue(Selected(), s.key, v)
            RefreshAll()
        end)
        row.widget = sl
        row.refresh = function(p, editable)
            local v = p.values[s.key]
            local shown = v
            if v == "d" or v == nil then shown = (s.kind == "mul") and 1 or lo
            elseif s.kind == "mul" then shown = tonumber(v:sub(2)) end
            sl:SetValue(shown)
            SetEditable(sl, editable)
            value:SetText(DisplayValue(s, v))
        end
    end

    if s.kind ~= "curve" then
        local reset = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
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
    y = y - 30
end
content:SetHeight(-y + 20)

refreshers[#refreshers + 1] = function()
    local id = Selected()
    local p = ns.GetProfile(id)
    selBtn:SetText(ns.ProfileName(id))
    descText:SetText(ns.ProfileDescription(id))
    local editable = ns.IsEditable(id)
    SetEditable(bDelete, not ns.IsBuiltin(id))
    SetEditable(bReset, ns.IsEdited(id))
    selBtn:SetText(ns.ProfileName(id) .. (ns.IsEdited(id) and (" " .. L["(edited)"]) or ""))
    if editable and ns.IsBuiltin(id) then
        readonly:SetText(L["Advanced editing is on. Changes to a built-in profile are kept; Reset to original brings it back."])
    elseif editable then
        readonly:SetText(L["Settings not listed use the game default. Click a value to change it; the curve box takes zoom:offset pairs."])
    else
        readonly:SetText(L["Built-in profiles are locked. Make a copy, or tick Advanced to edit them."])
    end
    local shownValues = p.values
    for _, row in ipairs(editors) do
        row.refresh({ values = shownValues }, editable)
        if row.reset then SetEditable(row.reset, editable) end
    end
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
