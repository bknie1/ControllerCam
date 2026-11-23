-- ControllerCam HUD: the fish journal (the window).
-- /cchud journal, or its key binding. Two pages: Fish (every kind you have landed: how many, your heaviest,
-- where and when first, and a few lines about it) and Waters (every place you have fished: how many, which
-- kinds, and a few lines about the place). With the controller: the d-pad chooses, the shoulder buttons (or
-- left and right) turn the page, B closes. With the mouse: point at a row. Those buttons are bound to the
-- window while it is open (ns.PadKeys); every other button stays the game's, and so does a fight.
-- The book itself is kept by FishLog.lua; the lines about fish and waters are in FishLore.lua.

local ADDON, ns = ...
local L = ns.L
local C = ns.colors

local W = { page = "fish", index = 1, top = 1, rows = {}, list = {} }
ns.FishJournal = W

W.KEYS = { "PADDUP", "PADDDOWN", "PADDLEFT", "PADDRIGHT", "PADLSHOULDER", "PADRSHOULDER", "PAD2", "ESCAPE" }
local ROWS, ROW, TOP = 8, 36, 74
local WIDTH, HEIGHT, LIST = 640, 420, 300

local frame

local function KeyName(key)
    if ns.KeyText then return ns.KeyText(key) end                  -- (your controller's own icons: PadIcons.lua)
    local text = GetBindingText and GetBindingText(key) or key
    return (type(text) == "string" and text ~= "") and text or key
end

local function Icon(id, icon)
    if icon then return icon end
    if id and C_Item and C_Item.GetItemIconByID then
        local ok, found = pcall(C_Item.GetItemIconByID, id)
        if ok and (type(found) == "number" or type(found) == "string") then return found end
    end
    return ns.media.bobber
end

---------------------------------------------------------------------------
-- What the pages list
---------------------------------------------------------------------------
-- Every kind landed: fish first, then the rest, each by name
function W.Fish()
    local out = {}
    for id, e in pairs(ns.FishLog.Log().fish) do out[#out + 1] = { id = id, e = e, name = e.name or ("item:" .. id) } end
    table.sort(out, function(a, b)
        if a.e.fish ~= b.e.fish then return a.e.fish end
        if a.name ~= b.name then return a.name < b.name end
        return a.id < b.id
    end)
    return out
end

-- Every water fished, by name
function W.Waters()
    local out = {}
    for name, z in pairs(ns.FishLog.Log().zones) do
        local kinds = 0
        for _ in pairs(z.fish) do kinds = kinds + 1 end
        out[#out + 1] = { name = name, z = z, kinds = kinds }
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

-- The whole book in a line: how many landed, how many kinds, how many got away, and the heaviest
function W.Summary()
    local log = ns.FishLog.Log()
    local kinds, heavy, heaviest = 0, nil, nil
    for id, e in pairs(log.fish) do
        kinds = kinds + 1
        if e.best and (not heavy or e.best > heavy) then heavy, heaviest = e.best, e.name or ("item:" .. id) end
    end
    local text = L["%d landed, %d kinds, %d got away"]:format(log.total, kinds, log.away)
    if heavy then text = text .. "     " .. L["Heaviest: %s, %s"]:format(heaviest, ns.FishLog.Pounds(heavy)) end
    return text
end

---------------------------------------------------------------------------
-- Building
---------------------------------------------------------------------------
local function Build()
    frame = CreateFrame("Frame", "ControllerCamHUD_FishJournalWindow", UIParent)
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)
    frame.back = frame:CreateTexture(nil, "BACKGROUND")
    frame.back:SetAllPoints(frame)
    frame.back:SetColorTexture(0.03, 0.06, 0.1, 0.96)
    for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" } }) do
        local t = frame:CreateTexture(nil, "BORDER")
        t:SetPoint(side[1], frame, side[1])
        t:SetPoint(side[2], frame, side[2])
        t:SetHeight(1)
        t:SetColorTexture(0.6, 0.84, 1, 0.6)
    end
    frame.float = frame:CreateTexture(nil, "ARTWORK")
    frame.float:SetTexture(ns.media.bobber)
    frame.float:SetSize(30, 30)
    frame.float:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -8)
    frame.title = ns.FontString(frame, 15, "LEFT")
    frame.title:SetPoint("LEFT", frame.float, "RIGHT", 6, 4)
    frame.title:SetText(L["Fish journal"])
    frame.summary = ns.FontString(frame, 9, "LEFT")
    frame.summary:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -3)
    frame.summary:SetTextColor(unpack(C.muted))
    frame.tabFish = ns.FontString(frame, 11, "RIGHT")
    frame.tabWaters = ns.FontString(frame, 11, "RIGHT")
    frame.tabWaters:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -14)
    frame.tabFish:SetPoint("RIGHT", frame.tabWaters, "LEFT", -16, 0)
    frame.tabFish:SetText(L["Fish"])
    frame.tabWaters:SetText(L["Waters"])

    for i = 1, ROWS do
        local r = CreateFrame("Button", nil, frame)
        r:SetSize(LIST, ROW - 2)
        r:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -TOP - (i - 1) * ROW)
        r.hl = r:CreateTexture(nil, "BACKGROUND")
        r.hl:SetAllPoints(r)
        r.hl:SetColorTexture(1, 1, 1, 0.09)
        r.hl:Hide()
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(28, 28)
        r.icon:SetPoint("LEFT", r, "LEFT", 6, 0)
        r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        r.name = ns.FontString(r, 10, "LEFT")
        r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 8, -1)
        r.sub = ns.FontString(r, 8, "LEFT")
        r.sub:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 8, 1)
        r.sub:SetTextColor(unpack(C.muted))
        r:SetScript("OnEnter", ns.Protect(function(self) if self.at then W:Choose(self.at) end end))
        r:SetScript("OnClick", ns.Protect(function(self) if self.at then W:Choose(self.at) end end))
        W.rows[i] = r
    end
    frame.count = ns.FontString(frame, 9, "LEFT")
    frame.count:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -TOP - ROWS * ROW - 2)
    frame.count:SetTextColor(unpack(C.muted))

    -- the chosen one, beside the list
    local x = LIST + 28
    frame.bigIcon = frame:CreateTexture(nil, "ARTWORK")
    frame.bigIcon:SetSize(48, 48)
    frame.bigIcon:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -TOP)
    frame.bigIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    frame.name = ns.FontString(frame, 13, "LEFT")
    frame.name:SetPoint("TOPLEFT", frame.bigIcon, "TOPRIGHT", 10, -4)
    frame.name:SetWidth(WIDTH - x - 80)
    frame.facts = ns.FontString(frame, 10, "LEFT")
    frame.facts:SetPoint("TOPLEFT", frame.bigIcon, "BOTTOMLEFT", 0, -12)
    frame.facts:SetWidth(WIDTH - x - 18)
    if frame.facts.SetSpacing then frame.facts:SetSpacing(4) end
    frame.lore = ns.FontString(frame, 10, "LEFT")
    frame.lore:SetPoint("TOPLEFT", frame.facts, "BOTTOMLEFT", 0, -14)
    frame.lore:SetWidth(WIDTH - x - 18)
    frame.lore:SetTextColor(0.78, 0.88, 1)
    if frame.lore.SetSpacing then frame.lore:SetSpacing(3) end
    for _, fs in ipairs({ frame.name, frame.facts, frame.lore }) do
        if fs.SetWordWrap then fs:SetWordWrap(true) end
        if fs.SetJustifyV then fs:SetJustifyV("TOP") end
    end
    frame.empty = ns.FontString(frame, 11, "CENTER")
    frame.empty:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.empty:SetTextColor(unpack(C.muted))
    frame.empty:SetText(L["Nothing landed yet. Take a pole to the water."])
    frame.hint = ns.FontString(frame, 9, "LEFT")
    frame.hint:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 8)
    frame.hint:SetTextColor(unpack(C.muted))

    W.keys = ns.PadKeys("Journal", W.KEYS, function(key) W:Pad(key) end, function() frame:Hide() end)
    frame:SetScript("OnHide", ns.Protect(function() W.keys:Set(false) end))
    -- (Escape is one of its keys while it is open. It is not put on the game's list of windows that Escape
    -- closes: the game goes through that list with its own code, and an entry of ours spoils the run.)
    frame:Hide()
    W.frame = frame
end

---------------------------------------------------------------------------
-- Showing
---------------------------------------------------------------------------
local function Detail(item)
    local J = ns.FishLog
    if W.page == "fish" then
        local e = item.e
        local facts = { L["Landed: %d"]:format(e.n) }
        if e.best then facts[#facts + 1] = L["Heaviest: %s, at %s"]:format(J.Pounds(e.best), e.bestAt or "?") end
        if e.firstAt then
            facts[#facts + 1] = L["First landed: %s"]:format(e.firstAt) .. (e.first and ("  (" .. e.first .. ")") or "")
        end
        return Icon(item.id, e.icon), item.name, table.concat(facts, "\n"), ns.FishLore.fish[item.id]
    end
    local z = item.z
    local facts = { L["Landed here: %d"]:format(z.n), L["Kinds found here: %d"]:format(item.kinds) }
    local names, log = {}, J.Log()
    for id in pairs(z.fish) do names[#names + 1] = (log.fish[id] and log.fish[id].name) or ("item:" .. id) end
    table.sort(names)
    while #names > 8 do table.remove(names) end
    if #names > 0 then facts[#facts + 1] = table.concat(names, ", ") end
    return ns.media.bobber, item.name, table.concat(facts, "\n"), z.map and ns.FishLore.waters[z.map]
end

function W:Refresh()
    if not (frame and frame:IsShown()) then return end
    local J = ns.FishLog
    self.list = (self.page == "fish") and W.Fish() or W.Waters()
    local n = #self.list
    self.index = ns.Clamp(self.index, 1, math.max(1, n))
    if self.index < self.top then self.top = self.index end
    if self.index > self.top + ROWS - 1 then self.top = self.index - ROWS + 1 end
    self.top = ns.Clamp(self.top, 1, math.max(1, n - ROWS + 1))
    frame.summary:SetText(W.Summary())
    frame.tabFish:SetTextColor(unpack(self.page == "fish" and C.text or C.muted))
    frame.tabWaters:SetTextColor(unpack(self.page == "waters" and C.text or C.muted))
    for i, r in ipairs(self.rows) do
        local at = self.top + i - 1
        local item = self.list[at]
        if item then
            r.at = at
            r.name:SetText(item.name)
            if self.page == "fish" then
                r.icon:SetTexture(Icon(item.id, item.e.icon))
                r.sub:SetText(item.e.best and ("x%d     %s"):format(item.e.n, J.Pounds(item.e.best)) or ("x%d"):format(item.e.n))
            else
                r.icon:SetTexture(ns.media.bobber)
                r.sub:SetText(("x%d"):format(item.z.n))
            end
            if at == self.index then r.hl:Show() else r.hl:Hide() end
            r:Show()
        else
            r.at = nil
            r:Hide()
        end
    end
    frame.count:SetText(n > ROWS and ("%d - %d / %d"):format(self.top, math.min(n, self.top + ROWS - 1), n) or "")
    local chosen = self.list[self.index]
    if chosen then
        local icon, name, facts, lore = Detail(chosen)
        frame.bigIcon:SetTexture(icon)
        frame.bigIcon:Show()
        frame.name:SetText(name)
        frame.facts:SetText(facts)
        frame.lore:SetText(lore or "")
        frame.empty:Hide()
    else
        frame.bigIcon:Hide()
        frame.name:SetText("")
        frame.facts:SetText("")
        frame.lore:SetText("")
        frame.empty:Show()
    end
    frame.hint:SetText(("%s %s    %s %s    %s %s"):format(KeyName("PADDUP"), L["Choose"], KeyName("PADRSHOULDER"),
        self.page == "fish" and L["Waters"] or L["Fish"], KeyName("PAD2"), L["Close"]))
    if ns.Narrative then ns.Narrative.Journal() end               -- (you, leafing through it)
end

function W:Choose(at)
    self.index = at
    self:Refresh()
end

function W:Page(page)
    if page == self.page then return end
    self.page, self.index, self.top = page, 1, 1
    self:Refresh()
end

function W:Pad(button)
    if not (frame and frame:IsShown()) then return false end
    if button == "PADDUP" then self:Choose(self.index - 1)
    elseif button == "PADDDOWN" then self:Choose(self.index + 1)
    elseif button == "PADDLEFT" or button == "PADDRIGHT" or button == "PADLSHOULDER" or button == "PADRSHOULDER" then
        self:Page(self.page == "fish" and "waters" or "fish")
    elseif button == "PAD2" or button == "ESCAPE" then self:Close()
    else return false end
    return true
end

function W:Close()
    if frame then frame:Hide() end
    if self.keys then self.keys:Set(false) end
end

function W:Toggle()
    if not frame then Build() end
    if frame:IsShown() then self:Close(); return false end
    frame:Show()
    self.keys:Set(true)
    self:Refresh()
    return true
end

function ControllerCamHUD_FishJournal() ns.Protect(function() W:Toggle() end)() end
BINDING_NAME_CCHUD_FISHJOURNAL = L["Fish journal"]
ns.RegisterCommand("journal", function() W:Toggle() end, "/cchud journal",
    "open or close your fish journal: every kind you have landed, your heaviest of each, and the waters you have fished")
