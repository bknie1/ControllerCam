-- Additions to wow_mock.lua for the ControllerCam HUD tests: units, frames that remember what was done to
-- them, the game's own player / target / chat frames, and "secret" values.
-- Expects the global HUD_TEST_DIR (set by the test runner).

local mock = dofile(HUD_TEST_DIR .. "/wow_mock.lua")

---------------------------------------------------------------------------
-- Frames that record what the addon does to them
---------------------------------------------------------------------------
local baseCreate = CreateFrame
local decorate

local function child(kind, parent)
    local f = decorate(baseCreate(kind))
    f.parent = parent
    return f
end

function decorate(f)
    f.points, f.attrs, f.alpha, f.scale, f.level = {}, {}, 1, 1, 1
    f.SetPoint = function(self, ...) self.points[#self.points + 1] = { ... } end
    f.ClearAllPoints = function(self) self.points = {} end
    f.SetAllPoints = function(self, other) self.points = { { "ALL", other } } end
    f.GetNumPoints = function(self) return #self.points end
    f.GetPoint = function(self, i) return unpack(self.points[i] or {}) end
    f.SetAlpha = function(self, a) self.alpha = a end
    f.GetAlpha = function(self) return self.alpha end
    f.SetScale = function(self, s) self.scale = s end
    f.GetScale = function(self) return self.scale end
    f.SetFrameLevel = function(self, n) self.level = n end
    f.GetFrameLevel = function(self) return self.level end
    f.SetFrameStrata = function(self, s) self.strata = s end
    f.SetAttribute = function(self, k, v) self.attrs[k] = v end
    f.GetAttribute = function(self, k) return self.attrs[k] end
    f.SetParent = function(self, p) self.parent = p end
    f.GetParent = function(self) return self.parent end
    f.SetSize = function(self, w, h) self.width, self.height = w, h end
    f.SetHeight = function(self, h) self.height = h end
    f.GetHeight = function(self) return self.height or 10 end
    f.GetCenter = function(self) return self.cx or 0, self.cy or 0 end
    f.SetMinMaxValues = function(self, a, b) self.min, self.max = a, b end
    f.SetStatusBarTexture = function(self, t)
        self.barPath = t; self.barTex = self.barTex or child("Texture", self); self.barTex.texture = t
    end
    f.GetStatusBarTexture = function(self) self.barTex = self.barTex or child("Texture", self); return self.barTex end
    f.SetStatusBarColor = function(self, r, g, b, a) self.color = { r, g, b, a } end
    f.SetVertexColor = function(self, r, g, b, a) self.vcolor = { r, g, b, a } end
    f.SetTextColor = function(self, r, g, b, a) self.tcolor = { r, g, b, a } end
    f.SetTexture = function(self, t) self.texture = t end
    f.GetTexture = function(self) return self.texture end
    f.GetTextureFilePath = function(self) return type(self.texture) == "string" and self.texture or nil end
    f.GetAtlas = function(self) return self.atlas end
    f.SetAtlas = function(self, a) self.atlas, self.texture = a, nil end
    f.SetFont = function(self, file, size, flags) self.fontFile, self.fontSize, self.fontFlags = file, size, flags end
    f.GetFont = function(self) return self.fontFile or "Fonts\FRIZQT__.TTF", self.fontSize or 12, self.fontFlags or "" end
    f.SetWordWrap = function(self, v) self.wordWrap = v end
    f.GetObjectType = function(self) return self.kind or "Frame" end
    f.GetTexCoord = function(self)
        if self.texCoord then return unpack(self.texCoord) end
        return 0, 0, 0, 1, 1, 0, 1, 1
    end
    f.GetRegions = function(self)
        local list = {}
        for _, other in ipairs(mock.frames) do
            if other.parent == self and (other.kind == "Texture" or other.kind == "FontString") then list[#list + 1] = other end
        end
        return unpack(list)
    end
    f.SetFormattedText = function(self, fmt, ...)            -- the game formats secret values itself
        local args = { ... }
        for i = 1, select("#", ...) do
            if type(args[i]) == "table" and args[i].secret then args[i] = 42 end
        end
        self.text = string.format(fmt, unpack(args, 1, select("#", ...)))
    end
    f.GetChildren = function(self)
        local kids = {}
        for _, other in ipairs(mock.frames) do
            if other.parent == self and other.kind ~= "Texture" and other.kind ~= "FontString"
                and other.kind ~= "MaskTexture" then
                kids[#kids + 1] = other
            end
        end
        return unpack(kids)
    end
    f.SetCooldown = function(self, start, duration) self.cdStart, self.cdDuration = start, duration end
    f.SetOrientation = function(self, o) self.orientation = o end
    f.SetTimerDuration = function(self, d, _, way) self.timer, self.timerWay = d, way end
    f.SetTextScale = function(self, k) self.textScale = k end
    f.SetTexCoord = function(self, ...) self.texCoord = { ... } end
    f.AddMaskTexture = function(self, m) self.mask = m end
    f.CreateTexture = function(self) return child("Texture", self) end
    f.CreateLine = function(self)
        local l = child("Texture", self)
        l.SetStartPoint = function(s, ...) s.from = { ... } end
        l.SetEndPoint = function(s, ...) s.to = { ... } end
        l.SetThickness = function(s, t) s.thickness = t end
        return l
    end
    f.CreateFontString = function(self) return child("FontString", self) end
    f.CreateMaskTexture = function(self) return child("MaskTexture", self) end
    f.RegisterUnitEvent = function(self, e) self:RegisterEvent(e) end
    f.GetName = function(self) return self.__name end
    f.IsVisible = function(self) return self.shown end
    f.IsForbidden = function() return false end
    f.HookScript = function(self, k, fn)
        local old = self.scripts[k]
        self.scripts[k] = function(...) if old then old(...) end; fn(...) end
    end
    f.UnregisterAllEvents = function(self) for e in pairs(self.events) do self.events[e] = nil end end
    f.EnableMouse = function(self, v) self.mouse = v and true or false end
    f.SetMovable = function(self, v) self.movable = v and true or false end
    f.StartMoving = function(self) self.moving = true end
    f.StopMovingOrSizing = function(self) self.moving = false end
    return f
end

function CreateFrame(kind, name, parent, template)
    local f = decorate(baseCreate(kind, name, parent, template))
    f.parent = parent
    return f
end

decorate(UIParent)
UIParent.cx, UIParent.cy = 512, 384

-- The game's own frames
PlayerFrame = CreateFrame("Button", "PlayerFrame", UIParent)
TargetFrame = CreateFrame("Button", "TargetFrame", UIParent)
FocusFrame = CreateFrame("Button", "FocusFrame", UIParent)
ChatFrame1 = CreateFrame("Frame", "ChatFrame1", UIParent)
mock.chatAnchor = { "CENTER", UIParent, "CENTER", -541, -314 }
mock.anchorCalls = 0
ChatFrame1.points = { mock.chatAnchor }
ChatFrame1.ClearAllPointsBase = ChatFrame1.ClearAllPoints      -- an Edit Mode frame keeps the plain methods here
ChatFrame1.SetPointBase = ChatFrame1.SetPoint
ChatFrame1.ApplySystemAnchor = function(self)
    mock.anchorCalls = mock.anchorCalls + 1
    self.points = { mock.chatAnchor }
end

-- The game's party and raid frames, and its cast bar
PartyFrame = CreateFrame("Frame", "PartyFrame", UIParent)
for i = 1, 4 do
    local m = CreateFrame("Button", nil, PartyFrame)
    m.attrs.unit, m.shown, m.width = "party" .. i, false, 120
    PartyFrame["MemberFrame" .. i] = m
end
CompactRaidFrameContainer = CreateFrame("Frame", "CompactRaidFrameContainer", UIParent)
function mock.raidFrame(i, unit)
    local m = CreateFrame("Button", "CompactRaidFrame" .. i, CompactRaidFrameContainer)
    m.attrs.unit, m.width = unit, 72
    return m
end
PlayerCastingBarFrame = CreateFrame("StatusBar", "PlayerCastingBarFrame", UIParent)

-- The gamepad action bars
GamepadMainActionBarFrame = CreateFrame("Frame", "GamepadMainActionBarFrame", UIParent)
GamepadMainActionBarFrame.SetScaleBase = GamepadMainActionBarFrame.SetScale    -- an Edit Mode frame keeps the plain method here
do
    local page = CreateFrame("Frame", "GamepadMainActionBarFramePageUnit", GamepadMainActionBarFrame)
    page.LeftShoulderBackground = page:CreateTexture()
    page.RightShoulderBackground = page:CreateTexture()
    for _, suffix in ipairs({ "TopCenteredAnchorTopBar", "LeftCenteredAnchorLeftBar", "RightCenteredAnchorRightBar",
                              "BottomCenteredAnchorBottomBar" }) do
        local bar = CreateFrame("Frame", "GamepadMainActionBarFramePageUnit" .. suffix, page)
        bar.BackgroundWatermark, bar.LeftButtonFrame, bar.RightButtonFrame =
            bar:CreateTexture(), bar:CreateTexture(), bar:CreateTexture()
        bar.BackgroundFocus = bar:CreateTexture()
        for i = 1, 8 do                                         -- its buttons, with the game's regions
            local name = "GamepadMainActionBarFramePageUnit" .. suffix .. "ActionButton" .. i
            local b = CreateFrame("CheckButton", name, bar)
            b.width = i <= 4 and 32 or 30
            b.GetWidth = function(self) return self.width end
            b.NormalTexture, b.SlotArt, b.SlotBackground = b:CreateTexture(), b:CreateTexture(), b:CreateTexture()
            b.Name, b.Count, b.HotKey = b:CreateFontString(), b:CreateFontString(), b:CreateFontString()
        end
    end
    page.LeftClassAction = CreateFrame("CheckButton", "GamepadMainActionBarFramePageUnitLeftClassAction", page)
    page.LeftClassAction.NormalTexture = page.LeftClassAction:CreateTexture()
end

-- The rest of the game's interface the restyle dresses
GameTooltip.NineSlice = CreateFrame("Frame", nil, GameTooltip)
GameTooltipStatusBar = CreateFrame("StatusBar", "GameTooltipStatusBar", GameTooltip)
for _, name in ipairs({ "GameTooltipHeaderText", "GameTooltipText", "GameTooltipTextSmall", "ObjectiveTrackerHeaderFont",
                        "ObjectiveTrackerLineFont" }) do
    _G[name] = CreateFrame("Font", name)
    _G[name]:SetFont("Fonts\FRIZQT__.TTF", 12, "")
end
BuffFrame = CreateFrame("Frame", "BuffFrame", UIParent)
BuffFrame.AuraContainer = CreateFrame("Frame", nil, BuffFrame)
function mock.addBuff()
    local b = CreateFrame("Button", nil, BuffFrame.AuraContainer)
    b.Icon, b.Duration, b.Count = b:CreateTexture(), b:CreateFontString(), b:CreateFontString()
    return b
end
mock.addBuff()
ObjectiveTrackerFrame = CreateFrame("Frame", "ObjectiveTrackerFrame", UIParent)
ObjectiveTrackerFrame.Header = CreateFrame("Frame", nil, ObjectiveTrackerFrame)
ObjectiveTrackerFrame.Header.Background = ObjectiveTrackerFrame.Header:CreateTexture()
ObjectiveTrackerFrame.Header.Text = ObjectiveTrackerFrame.Header:CreateFontString()
MinimapCluster = CreateFrame("Frame", "MinimapCluster", UIParent)
Minimap = CreateFrame("Minimap", "Minimap", UIParent)
Minimap.GetWidth = function() return 198 end
Minimap.zoom = 0
Minimap.GetZoom = function(self) return self.zoom end
Minimap.SetZoom = function(self, z) self.zoom = z end
MinimapCompassTexture = Minimap:CreateTexture()
MinimapZoneText = Minimap:CreateFontString()
StatusTrackingBarManager = CreateFrame("Frame", "StatusTrackingBarManager", UIParent)
StatusTrackingBarManager.MainStatusTrackingBarContainer = CreateFrame("Frame", nil, StatusTrackingBarManager)
StatusTrackingBarManager.MainStatusTrackingBarContainer.BarFrameTexture =
    StatusTrackingBarManager.MainStatusTrackingBarContainer:CreateTexture()
ChatFrame1EditBox = CreateFrame("EditBox", "ChatFrame1EditBox", UIParent)
for _, part in ipairs({ "Left", "Mid", "Right" }) do _G["ChatFrame1EditBox" .. part] = ChatFrame1EditBox:CreateTexture() end
ChatFrame1Tab = CreateFrame("Button", "ChatFrame1Tab", UIParent)
ChatFrame1Tab.Text = ChatFrame1Tab:CreateFontString()

-- Chat windows (their own fading) and the world map
for i = 1, 3 do
    local f = _G["ChatFrame" .. i] or CreateFrame("Frame", "ChatFrame" .. i, UIParent)
    f.fading, f.timeVisible = false, 120
    f.SetFading = function(self, v) self.fading = v end
    f.GetFading = function(self) return self.fading end
    f.SetTimeVisible = function(self, v) self.timeVisible = v end
    f.GetTimeVisible = function(self) return self.timeVisible end
end
NUM_CHAT_WINDOWS = 3
WorldMapFrame = CreateFrame("Frame", "WorldMapFrame", UIParent)
WorldMapFrame.shown = false                     -- (closed until a test opens it)
mock.clockMs = 0                                -- the game's own clock in ms: a handler can make itself slow
function debugprofilestop() return mock.clockMs + (mock.time or 0) * 1000 end
mock.playerPos = { 0.738, 0.328 }
C_Map = C_Map or {}

-- Tooltips: where the game puts them by default
GameTooltip.SetOwner = function(self, owner, anchor)
    self.owner, self.anchor = owner, anchor
    self.owned = (self.owned or 0) + 1
end
GameTooltip.SetAnchorType = function(self, anchor) self.anchor = anchor end
function GameTooltip_SetDefaultAnchor(tooltip, parent)
    tooltip:SetOwner(parent, "ANCHOR_NONE")
    tooltip.cornered = true
end

-- Edit Mode and the Cooldown Manager
EditModeManagerFrame = CreateFrame("Frame", "EditModeManagerFrame", UIParent)
EditModeManagerFrame.shown = false
function mock.editMode(open)
    EditModeManagerFrame.shown = open
    local script = EditModeManagerFrame.scripts[open and "OnShow" or "OnHide"]
    if script then script(EditModeManagerFrame) end
end
mock.cooldownFrames = { "EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer",
                        "BuffBarCooldownViewer" }
for _, name in ipairs(mock.cooldownFrames) do CreateFrame("Frame", name, UIParent) end
mock.cvars.cooldownViewerEnabled, mock.defaults.cooldownViewerEnabled = "1", "0"
mock.knownCVars.cooldownViewerEnabled = true
for name, value in pairs({ showTargetOfTarget = "1", nameplateShowSelf = "0", bankAutoDepositReagents = "0",
                           GamepadShowAutoAuraTooltip = "1", nameplateShowFriendlyPlayers = "1",
                           nameplateShowOnlyNameForFriendlyPlayerUnits = "0",
                           nameplateUseClassColorForFriendlyPlayerUnitNames = "0" }) do
    mock.cvars[name], mock.defaults[name], mock.knownCVars[name] = value, value, true
end

---------------------------------------------------------------------------
-- Units
---------------------------------------------------------------------------
mock.units = {
    player = { name = "Ghostlight", health = 1000, healthMax = 1000, power = 500, powerMax = 500,
               powerToken = "MANA", level = 33, class = "HUNTER", isPlayer = true },
}
local function U(unit) return mock.units[unit] end

-- A value the game will not let addons read: any arithmetic or comparison on it fails.
function mock.secret() return { secret = true } end
function issecretvalue(v) return type(v) == "table" and v.secret == true end

function UnitExists(unit) return U(unit) ~= nil end
function UnitHealth(unit) return U(unit) and U(unit).health or 0 end
function UnitHealthMax(unit) return U(unit) and U(unit).healthMax or 0 end
function UnitPower(unit) return U(unit) and U(unit).power or 0 end
function UnitPowerMax(unit) return U(unit) and U(unit).powerMax or 0 end
function UnitPowerType(unit) return 0, U(unit) and U(unit).powerToken or "MANA" end
function UnitName(unit) return U(unit) and U(unit).name, U(unit) and U(unit).realm end
function UnitLevel(unit) return U(unit) and U(unit).level or 0 end
function UnitClassification(unit) return U(unit) and U(unit).classification or "normal" end
function UnitIsPlayer(unit) return U(unit) and U(unit).isPlayer or false end
function UnitClass(unit) return "Class", U(unit) and U(unit).class end
function UnitReaction(unit) return U(unit) and U(unit).reaction end
function UnitCanAttack(_, unit) return U(unit) and U(unit).attackable or false end
function UnitIsDead(unit) return U(unit) and U(unit).dead or false end
function UnitIsGhost() return false end
function UnitIsTapDenied(unit) return U(unit) and U(unit).tapped or false end
function UnitIsDeadOrGhost(unit) return U(unit) and U(unit).dead or false end
function UnitIsConnected(unit) return not (U(unit) and U(unit).offline) end
function UnitInRange(unit) return not (U(unit) and U(unit).far), true end
function UnitIsUnit(a, b) return U(a) ~= nil and U(a) == U(b) end
function IsInRaid()
    for unit in pairs(mock.units) do if unit:match("^raid") then return true end end
    return false
end
mock.keysDown = {}
function IsKeyDown(key) return mock.keysDown[key] or false end
mock.bindings = {}                -- action -> { keys }, for bindings a test sets
function GetBindingKey(action)
    if mock.bindings[action] then return unpack(mock.bindings[action]) end
    if action == "GAMEPADLEFTMOD" then return "PADLTRIGGER" end
    if action == "GAMEPADRIGHTMOD" then return "PADRTRIGGER" end
end
function IsInGroup()
    for unit in pairs(mock.units) do if unit:match("^party") or unit:match("^raid") then return true end end
    return false
end
function UnitGUID(unit) return U(unit) and (U(unit).guid or ("guid-" .. unit)) end
function UnitCreatureType(unit) return U(unit) and U(unit).creature end
function UnitLevel(unit) return U(unit) and U(unit).level or 0 end
function UnitCastingDuration(unit) local c = U(unit) and U(unit).cast; return c and c.durationObject end
function UnitChannelDuration(unit) local c = U(unit) and U(unit).cast; return c and c.durationObject end
function UnitGetIncomingHeals(unit) return U(unit) and U(unit).incoming end
function UnitGetTotalAbsorbs(unit) return U(unit) and U(unit).absorb end
function UnitThreatSituation(_, unit) return U(unit) and U(unit).threat end
function UnitDetailedThreatSituation(_, unit)
    local u = U(unit)
    if not u or u.threat == nil then return nil end
    return u.threat == 3, u.threat, u.threatPct, u.threatPct, 0
end
function UnitHealthPercent(unit)
    local u = U(unit)
    if not u then return 0 end
    if u.pct then return u.pct end
    return (tonumber(u.health) or 0) / math.max(1, tonumber(u.healthMax) or 1)
end
function UnitPVPName(unit) return U(unit) and U(unit).title end
function GetGuildInfo(unit) return U(unit) and U(unit).guild end
-- per-unit combat: the player follows mock.state.combat, everyone else their own "combat" field
function UnitAffectingCombat(unit)
    if unit == nil or unit == "player" then return mock.state.combat end
    return U(unit) and U(unit).combat or false
end
C_TooltipInfo = {
    GetUnit = function(unit)
        local u = U(unit)
        if not u then return nil end
        local lines = { { leftText = u.name }, { leftText = u.job or ("Level " .. tostring(u.level or 1)) } }
        for _, line in ipairs(u.questLines or {}) do lines[#lines + 1] = line end
        return { lines = lines }
    end,
}
-- The combat log: the test sets mock.logEntry, then fires COMBAT_LOG_EVENT_UNFILTERED
function CombatLogGetCurrentEventInfo() return unpack(mock.logEntry or {}) end
-- A hit as the combat log reports it. kind: "SWING_DAMAGE" or "SPELL_DAMAGE"
function mock.logHit(kind, sourceUnit, destUnit, school, crit)
    local e = { mock.time, kind, false, UnitGUID(sourceUnit), "src", 0, 0, UnitGUID(destUnit), "dst", 0, 0 }
    if kind == "SWING_DAMAGE" then
        e[12], e[13], e[14], e[15], e[16], e[17], e[18] = 100, -1, school, 0, 0, 0, crit or false
    else
        e[12], e[13], e[14], e[15], e[16], e[17], e[18], e[19], e[20], e[21] = 133, "Spell", school, 100, -1, school, 0, 0, 0, crit or false
    end
    mock.logEntry = e
    mock.fire("COMBAT_LOG_EVENT_UNFILTERED")
end
function UnitCastingInfo(unit)
    local c = U(unit) and U(unit).cast
    if c and not c.channel then return c.name, c.name, c.icon or 1, c.start, c.stop, c.trade or false, nil, c.shielded, c.spellId end
end
function UnitChannelInfo(unit)
    local c = U(unit) and U(unit).cast
    if c and c.channel then return c.name, c.name, 1, c.start, c.stop, false, c.shielded, c.spellId end
end
mock.subzone = ""
function GetSubZoneText() return mock.subzone end
RAID_CLASS_COLORS = { HUNTER = { r = 0.67, g = 0.83, b = 0.45 }, MAGE = { r = 0.25, g = 0.78, b = 0.92 } }

-- Secure "unit watch": the game shows the button while its unit exists.
mock.watched = {}
local function syncWatch()
    for button in pairs(mock.watched) do button.shown = UnitExists(button.attrs.unit) end
end
function RegisterUnitWatch(button) mock.watched[button] = true; syncWatch() end
function UnregisterUnitWatch(button) mock.watched[button] = nil end

function mock.setUnit(unit, data)
    mock.units[unit] = data
    syncWatch()
    if unit == "target" then mock.fire("PLAYER_TARGET_CHANGED") end
    if unit == "pet" then mock.fire("UNIT_PET", "player") end
    if unit == "focus" then mock.fire("PLAYER_FOCUS_CHANGED") end
    if unit:match("^party") or unit:match("^raid") then
        for i = 1, 4 do
            local m = PartyFrame["MemberFrame" .. i]
            m.shown = UnitExists(m.attrs.unit) and not mock.partyHidden     -- some clients hide them in the Gamepad UI
        end
        mock.fire("GROUP_ROSTER_UPDATE")
    end
end

---------------------------------------------------------------------------
-- Bags, vendor, bank, dialogs
---------------------------------------------------------------------------
MerchantSellAllJunkButton = CreateFrame("Button", "MerchantSellAllJunkButton", UIParent)
mock.nativeJunkClicks = 0
mock.nativeJunkClick = function() mock.nativeJunkClicks = mock.nativeJunkClicks + 1 end
MerchantSellAllJunkButton.scripts.OnClick = mock.nativeJunkClick

-- mock.bags[bag][slot] = { id, quality, price, count, class (2 weapon, 4 armor, 0 consumable, 7 trade), name, ... }
mock.bags = { [0] = {}, [1] = {}, [2] = {}, [3] = {}, [4] = {} }
mock.bagSize = 16
mock.sold, mock.moved, mock.gold = {}, {}, 0
mock.merchant, mock.bank = false, false
mock.leftOut = {}                 -- bags the game leaves out of junk selling
mock.items = {}                   -- id -> the item, for lookups by id
function mock.put(bag, slot, item)
    mock.bags[bag][slot] = item
    mock.items[item.id] = item
end
NUM_BAG_SLOTS = 4
Enum.BagSlotFlags = { ExcludeJunkSell = 64 }
C_Container = {
    GetContainerNumSlots = function(bag) return mock.bags[bag] and mock.bagSize or 0 end,
    GetContainerItemInfo = function(bag, slot)
        local it = mock.bags[bag] and mock.bags[bag][slot]
        if not it then return nil end
        return { itemID = it.id, quality = it.quality, stackCount = it.count or 1, isLocked = it.locked or false,
                 hasNoValue = it.noValue or false, hyperlink = "|Hitem:" .. it.id .. "|h[" .. it.name .. "]|h" }
    end,
    GetContainerItemID = function(bag, slot)
        local it = mock.bags[bag] and mock.bags[bag][slot]
        return it and it.id
    end,
    GetContainerItemEquipmentSetInfo = function(bag, slot)
        local it = mock.bags[bag] and mock.bags[bag][slot]
        return it and it.inSet or false
    end,
    GetBackpackSellJunkDisabled = function() return mock.leftOut[0] or false end,
    GetBagSlotFlag = function(bag) return mock.leftOut[bag] or false end,
    UseContainerItem = function(bag, slot)
        local it = mock.bags[bag] and mock.bags[bag][slot]
        if not it then return end
        if mock.merchant then
            mock.sold[#mock.sold + 1] = it.id
            mock.gold = mock.gold + it.price * (it.count or 1)
            mock.bags[bag][slot] = nil
        elseif mock.bank then
            mock.moved[#mock.moved + 1] = it.id
            mock.bags[bag][slot] = nil
        else
            mock.usedItem = it.id
        end
    end,
}
C_Spell = { GetSpellName = function(id) return mock.spellNames and mock.spellNames[id] end }
C_Item = {
    GetItemIconByID = function(id) return 1000 + id end,
    GetItemInfo = function(item)
        local id = tonumber(item) or tonumber(tostring(item):match("item:(%d+)"))
        local it = mock.items[id]
        if not it then return nil end
        return it.name, nil, it.quality, it.ilvl, it.req, it.kind, it.subkind, it.stack, nil, it.icon, it.price
    end,
    GetItemInfoInstant = function(id)
        if type(id) == "string" then id = tonumber(id:match("item:(%d+)")) or id end    -- (a link, as the game takes)
        local it = mock.items[id]
        if not it then return nil end
        return id, nil, nil, it.loc, nil, it.class, it.sub
    end,
    GetItemSpell = function(id)
        local it = mock.items[id]
        return it and it.use or nil
    end,
}
mock.worn = {}                    -- slot -> item id worn there (its item level comes from mock.items)
function GetInventoryItemLink(unit, slot)
    local id = mock.worn[slot]
    return id and ("|Hitem:" .. id .. "|h[x]|h") or nil
end

function mock.openMerchant(open)
    mock.merchant = open
    mock.fire(open and "MERCHANT_SHOW" or "MERCHANT_CLOSED")
end
function mock.openBank(open)
    mock.bank = open
    mock.fire(open and "BANKFRAME_OPENED" or "BANKFRAME_CLOSED")
end

-- The item the cursor is over: a button that knows its bag and slot, inside a child the cursor really hits.
function mock.pointAt(bag, slot)
    if not bag then mock.focus = nil; return end
    local button = CreateFrame("Button")
    button.GetBagID = function() return bag end
    button.GetID = function() return slot end
    local icon = CreateFrame("Frame")
    icon.parent = button
    mock.focus = icon
end
function GetMouseFoci() return { mock.focus } end

-- Dialog boxes: remembered, and answered by the test.
StaticPopupDialogs = {}
mock.popups = {}
function StaticPopup_Show(which, a, b)
    local d = StaticPopupDialogs[which]
    local frame = { which = which, text = string.format(d.text, a, b), dialog = d }
    mock.popups[#mock.popups + 1] = frame
    mock.visiblePopup = frame
end
function StaticPopup_FindVisible(which)
    if mock.visiblePopup and mock.visiblePopup.which == which then return mock.visiblePopup end
end
-- the player (or an addon) presses a button of a dialog
function StaticPopup_OnClick(frame, index)
    local d = frame.dialog
    if index == 1 and d.OnAccept then d.OnAccept() end
    mock.clicked = (mock.clicked or 0) + 1
    mock.visiblePopup = nil
end
-- Press a button of the dialog on screen: "accept", "alt" or "cancel".
function mock.answer(button)
    local p = table.remove(mock.popups)
    local d = p.dialog
    local fn = (button == "accept" and d.OnAccept) or (button == "alt" and d.OnAlt) or (button == "cancel" and d.OnCancel)
    if fn then fn() end
    mock.advance(0.01)
    return p
end

---------------------------------------------------------------------------
-- Auras, combo points, nameplates, quests
---------------------------------------------------------------------------
C_UnitAuras = {
    GetAuraDataByIndex = function(unit, index, filter)
        mock.auraFilter = filter
        local u = mock.units[unit]
        if u and u.noPlayerFilter and filter:find("PLAYER") then return nil end    -- a client without the filter
        return u and u.auras and u.auras[index]
    end,
}
-- The list of a unit's effects, and the game's own filter over it
local function auraList(unit)
    local u = mock.units[unit]
    local list = {}
    for i, a in ipairs(u and u.auras or {}) do
        a.auraInstanceID = a.auraInstanceID or (1000 + i)
        list[#list + 1] = a
    end
    return list
end
C_UnitAuras.GetUnitAuras = function(unit, filter)
    mock.auraFilter = filter
    return auraList(unit)
end
mock.auraFilters = {}
C_UnitAuras.GetUnitAuraInstanceIDs = function(unit, filter)
    mock.auraFilter = filter
    mock.auraFilters[filter] = true
    local ids = {}
    for _, a in ipairs(auraList(unit)) do
        local keep = true
        if filter:find("PLAYER") then keep = (a.sourceUnit == "player" or a.isFromPlayerOrPlayerPet == true or a.mine == true) end
        if filter:find("CROWD_CONTROL") then keep = keep and a.cc == true end
        if keep then ids[#ids + 1] = a.auraInstanceID end
    end
    return ids
end
mock.noModernAuras = function()
    C_UnitAuras.GetUnitAuras, C_UnitAuras.GetUnitAuraInstanceIDs = nil, nil
end

-- The game's aura display element ("AuraContainer"): off unless a test turns it on, like an older client.
mock.auraContainer = false
mock.containers = {}
local plainCreate = CreateFrame
function CreateFrame(kind, name, parent, template)
    if kind ~= "AuraContainer" then return plainCreate(kind, name, parent, template) end
    if not mock.auraContainer then error("Unknown frame type 'AuraContainer'") end
    local f = plainCreate("Frame", name, parent, template)
    f.groups = {}
    f.AddAuraGroup = function(self, key, _, opts)
        local g = { init = opts.initializeFrame, enabled = false, frames = {} }
        self.groups[key] = g
        -- one icon made now, so its look can be checked
        local icon = plainCreate("Frame", nil, self)
        icon.SetFlattensRenderLayers = function() end
        icon.EnableMouseMotion = function() end
        icon.SetIcon = function(i, t) i.iconTex = t end
        icon.SetDurationCooldown = function(i, c) i.cd = c end
        icon.SetDurationText = function(i, fs, opts) i.timeText, i.timeOpts = fs, opts end
        icon.SetApplicationCount = function(i, fs) i.countText = fs end
        icon.AddDispelTypeTexture = function(i, tex, o) i.dispelTex, i.dispelOpts = tex, o end
        g.init(icon)
        g.icon = icon
    end
    f.SetAuraGroupLayout = function(self, key, l) self.groups[key].layout = l end
    f.SetAuraGroupMaxFrameCount = function(self, key, n) self.groups[key].max = n end
    f.SetAuraGroupCandidateFilters = function(self, key, c) self.groups[key].candidates = c end
    f.SetAuraGroupFilterString = function(self, key, s)
        for word in s:gmatch("[^|!]+") do        -- a filter this client does not know: refused
            if mock.unknownFilters and mock.unknownFilters[word] then error("Unknown aura filter " .. word) end
        end
        self.groups[key].filter = s
    end
    f.SetAuraGroupEnabled = function(self, key, on) self.groups[key].enabled = on end
    f.SetFlowLayoutGrowthDirection = function(self, a, b) self.grow = a end
    f.SetFlowLayoutAnchorPoint = function(self, p) self.flowAnchor = p end
    f.SetUnit = function(self, u) self.unit = u; self.setUnitCalls = (self.setUnitCalls or 0) + 1 end
    f.UpdateAllAuras = function(self) self.looks = (self.looks or 0) + 1 end
    f.GetAuraGroupFrameCount = function(self, key) return #self.groups[key].frames end
    f.GetAuraGroupFrame = function(self, key, i) return self.groups[key].frames[i] end
    f.SetEnabled = function(self, on) self.enabled = on end
    mock.containers[#mock.containers + 1] = f
    return f
end
AnchorUtil = { FlowDirection = { Right = "right", Left = "left", Up = "up", Down = "down" } }
Enum.TooltipDataLineType = { QuestObjective = 8, QuestTitle = 17 }
CLASS_ICON_TCOORDS = { MAGE = { 0.25, 0.5, 0, 0.25 }, HUNTER = { 0, 0.25, 0.25, 0.5 } }
mock.layoutSelected = nil
EditModeManagerFrame.SelectLayout = function(self, index) mock.layoutSelected = index end
Enum.EditModeGamepadMainActionBarSetting = { ShowEmptyBars = 1, UseCompactLayout = 2 }
mock.compact = false
EditModeManagerFrame.OnSystemSettingChange = function(self, frame, setting, value)
    if setting == 2 then mock.compact = (value == 1) end
end
EditModeManagerFrame.SaveLayouts = function() mock.layoutsSaved = (mock.layoutsSaved or 0) + 1 end
GamepadMainActionBarFramePageUnit.ShouldUseCompactLayout = function() return mock.compact end
GamepadMainActionBarFrame.PageUnit = GamepadMainActionBarFramePageUnit
mock.combo = 0
function GetComboPoints() return mock.combo end

mock.plates = {}
C_NamePlate = {
    GetNamePlateForUnit = function(unit) return mock.plates[unit] end,
    GetNamePlates = function()
        local list = {}
        for unit, plate in pairs(mock.plates) do plate.namePlateUnitToken = unit; list[#list + 1] = plate end
        return list
    end,
}
function mock.addPlate(unit, data)
    local plate = CreateFrame("Frame", nil, UIParent)
    plate.UnitFrame = CreateFrame("Button", nil, plate)
    mock.plates[unit], mock.units[unit] = plate, data
    mock.fire("NAME_PLATE_UNIT_ADDED", unit)
    return plate
end
function mock.removePlate(unit)
    mock.fire("NAME_PLATE_UNIT_REMOVED", unit)
    mock.plates[unit], mock.units[unit] = nil, nil
end

-- The quest log: headings (zones) with their quests, and which quests are tracked.
mock.log = {}            -- { title = "Zone", isHeader = true } / { title =, questID = }
mock.watched = mock.watched or {}
mock.tracked = {}        -- questID -> true
mock.zone, mock.onMap = "Arathi Highlands", {}
function GetRealZoneText() return mock.zone end
function GetZoneText() return mock.zone end
C_Map.GetBestMapForUnit = function() return 1 end
C_Map.GetPlayerMapPosition = function()
    if not mock.playerPos then return nil end
    local x, y = mock.playerPos[1], mock.playerPos[2]
    return { GetXY = function() return x, y end }
end
C_QuestLog = {
    GetNumQuestLogEntries = function() return #mock.log end,
    GetInfo = function(i) return mock.log[i] end,
    GetQuestWatchType = function(id) return mock.tracked[id] and 0 or nil end,
    AddQuestWatch = function(id) mock.tracked[id] = true end,
    RemoveQuestWatch = function(id) mock.tracked[id] = nil end,
    GetQuestsOnMap = function() return mock.onMap end,
}
function mock.trackedList()
    local list = {}
    for id in pairs(mock.tracked) do list[#list + 1] = id end
    table.sort(list)
    return table.concat(list, ",")
end

-- Run every frame's OnUpdate, like the game does each rendered frame.
function mock.update(seconds, step)
    step = step or 0.05
    local t = 0
    while t < seconds - 1e-9 do
        mock.advance(step)
        for i = 1, #mock.frames do
            local f = mock.frames[i]
            if f.scripts.OnUpdate then f.scripts.OnUpdate(f, step) end
        end
        t = t + step
    end
end

-- Tooltip callbacks for addons, money, the realm, and the game's bag sorting
Enum.TooltipDataType = Enum.TooltipDataType or { Item = 0, Spell = 1, Unit = 2 }
mock.tipCalls = {}
TooltipDataProcessor = {
    AllTypes = "ALL",
    AddTooltipPostCall = function(kind, fn)
        mock.tipCalls[kind] = mock.tipCalls[kind] or {}
        table.insert(mock.tipCalls[kind], fn)
    end,
}
-- An item's tooltip as the game fills it: every addon callback for items runs, the lines are returned
function mock.itemTooltip(id)
    local tip = { lines = {} }
    tip.AddDoubleLine = function(self, l, r) self.lines[#self.lines + 1] = { l, r } end
    tip.AddLine = function(self, l) self.lines[#self.lines + 1] = { l } end
    for _, kind in ipairs({ Enum.TooltipDataType.Item, "ALL" }) do
        for _, fn in ipairs(mock.tipCalls[kind] or {}) do fn(tip, { type = Enum.TooltipDataType.Item, id = id }) end
    end
    mock.lastTip = tip
    -- what the HUD says about the item: on its own panel under the tooltip; nothing may be added to the tooltip
    assert(#tip.lines == 0, "a line was added to the game's tooltip")
    return mock.annexLines and mock.annexLines(tip) or tip.lines
end
mock.money = 12345
function GetMoney() return mock.money end
function GetNormalizedRealmName() return "Forever" end
mock.sorted = {}
C_Container.SortBags = function() mock.sorted[#mock.sorted + 1] = "bags" end
C_Container.SortBankBags = function() mock.sorted[#mock.sorted + 1] = "bank" end

-- Chat: the game's message filters for addons, class colours per kind of chat, players by GUID
mock.chatFilters = {}
function ChatFrame_AddMessageEventFilter(event, fn)
    mock.chatFilters[event] = mock.chatFilters[event] or {}
    table.insert(mock.chatFilters[event], fn)
end
mock.lineID = 0
-- A message as one chat window would show it: nil when hidden, else the text it shows
function mock.chat(event, msg, author, guid)
    mock.lineID = mock.lineID + 1
    local args = { msg, author, "", "", "", "", 0, 0, "", 0, mock.lineID, guid, 0, false, false, false, false }
    for _, fn in ipairs(mock.chatFilters[event] or {}) do
        local res = { fn(ChatFrame1, event, unpack(args, 1, 17)) }
        if res[1] then return nil end
        if res[2] ~= nil then
            for i = 2, #res do args[i - 1] = res[i] end
        end
    end
    mock.lastArgs = args
    return args[1]
end
mock.guids = {}
function GetPlayerInfoByGUID(guid)
    local p = mock.guids[guid]
    if not p then return nil end
    return "Class", p.class, "Race", "RACE", 0, p.name, "Forever"
end
ChatTypeInfo = {}
for _, kind in ipairs({ "SAY", "YELL", "EMOTE", "PARTY", "GUILD", "WHISPER", "CHANNEL1", "CHANNEL2" }) do
    ChatTypeInfo[kind] = { colorNameByClass = false }
end
function SetChatColorNameByClass(kind, on) ChatTypeInfo[kind].colorNameByClass = on end

-- Repairs
mock.repairCost, mock.canRepair, mock.repaired = 0, true, nil
function CanMerchantRepair() return mock.merchant and mock.canRepair end
function GetRepairAllCost() return mock.repairCost, mock.repairCost > 0 end
function RepairAllItems(guild)
    mock.repaired = guild and "guild" or "own"
    if not guild then mock.money = mock.money - mock.repairCost end
    mock.repairCost = 0
end
mock.guildRepair = false
function CanGuildBankRepair() return mock.guildRepair end
function GetGuildBankWithdrawMoney() return -1 end

-- The game's interaction icon for a unit (a vendor's bag...): set on a texture, true when there is one
function SetUnitCursorTexture(texture, unit)
    local u = mock.units[unit]
    if u and u.cursor then texture:SetTexture(u.cursor); return true end
    return false
end

-- The controller: rumble motors and the light bar
mock.rumble, mock.led = {}, nil
C_GamePad = {
    SetVibration = function(motor, intensity) mock.rumble[#mock.rumble + 1] = { motor = motor, k = intensity } end,
    StopVibration = function() mock.rumble[#mock.rumble + 1] = { motor = "stop" } end,
    SetLedColor = function(c) mock.led = c end,
    ClearLedColor = function() mock.led = "cleared" end,
}
function CreateColor(r, g, b) return { r = r, g = g, b = b } end

-- The game's number formatter for countdowns: remembers its rules
Enum.NumericRuleFormatRounding = { Down = 0, Up = 1, Nearest = 2 }
C_StringUtil = { CreateNumericRuleFormatter = function()
    local f = {}
    f.SetBreakpoints = function(self, rules) self.rules = rules end
    return f
end }

-- Key bindings an addon puts over yours while it needs them
mock.overrides, mock.overrideOwner = {}, {}
function SetOverrideBinding(owner, priority, key, command) mock.overrides[key], mock.overrideOwner[key] = command, owner end
function SetOverrideBindingSpell(owner, priority, key, spell)
    mock.overrides[key], mock.overrideOwner[key] = "SPELL " .. tostring(spell), owner
end
function ClearOverrideBindings(owner)
    for key, who in pairs(mock.overrideOwner) do
        if who == owner then mock.overrides[key], mock.overrideOwner[key] = nil, nil end
    end
end
function SetOverrideBindingClick(owner, priority, key, button, mouse)
    mock.overrides[key], mock.overrideOwner[key] = "CLICK " .. tostring(button) .. ":" .. tostring(mouse or "LeftButton"), owner
end
ContainerFrame1 = CreateFrame("Frame", "ContainerFrame1", UIParent)
ContainerFrame1:Hide()

-- Fishing: what is on the line ({ { id, name, count, quality } }), bait on the pole (seconds left), your skills
mock.loot, mock.fishingLoot, mock.looted = {}, false, {}
date = date or os.date
function IsFishingLoot() return mock.fishingLoot end
function GetNumLootItems() return #mock.loot end
function GetLootSlotLink(i)
    local it = mock.loot[i]
    return it and ("|cffffffff|Hitem:" .. it.id .. ":0:0|h[" .. it.name .. "]|h|r") or nil
end
function GetLootSlotInfo(i)
    local it = mock.loot[i]
    if not it then return nil end
    return 1000 + it.id, it.name, it.count or 1, nil, it.quality or 1, false
end
function LootSlot(i) mock.looted[#mock.looted + 1] = i end
-- A catch comes up: the game says the loot is ready, opens it, and closes it again
function mock.land(items)
    mock.loot, mock.fishingLoot = items, true
    mock.fire("LOOT_READY")
    mock.fire("LOOT_OPENED")
    mock.loot, mock.fishingLoot = {}, false
    mock.fire("LOOT_CLOSED")
end
ERR_FISH_ESCAPED = "Your fish got away!"
mock.enchant = nil
function GetWeaponEnchantInfo()
    if mock.enchant then return true, mock.enchant * 1000, 0, 264 end
    return false
end
function GetItemCount(id)
    local n = 0
    for _, bag in pairs(mock.bags) do
        for _, it in pairs(bag) do if it.id == id then n = n + (it.count or 1) end end
    end
    return n
end
mock.skills = {}                  -- { { name, rank, bonus, cap } }
function GetNumSkillLines() return #mock.skills end
function GetSkillLineInfo(i)
    local s = mock.skills[i]
    if not s then return nil end
    return s.name, s.header or false, true, s.rank, 0, s.bonus or 0, s.cap
end

-- The older auction house's list: { { id, count, buyout } }
mock.auctions = {}
function GetNumAuctionItems(kind) return #mock.auctions end
function GetAuctionItemInfo(kind, i)
    local a = mock.auctions[i]
    if not a then return nil end
    return "name", 1, a.count, 1, true, 1, "", 0, 0, a.buyout, 0, false, nil, "owner", nil, 0, a.id, true
end

-- Flights: the flight master's map (its places, which one you are at), its buttons, and being on a flight
mock.taxi = { nodes = {}, current = nil, onTaxi = false }
function NumTaxiNodes() return #mock.taxi.nodes end
function TaxiNodeName(i) return mock.taxi.nodes[i] end
function TaxiNodeGetType(i)
    if not mock.taxi.nodes[i] then return "NONE" end
    return i == mock.taxi.current and "CURRENT" or "REACHABLE"
end
function UnitOnTaxi(unit) return unit == "player" and mock.taxi.onTaxi or false end
-- where each place is on the flight map (0..1 each way), and the map's id
mock.taxi.pos = {}
function TaxiNodePosition(i)
    local p = mock.taxi.pos[i]
    if p then return p[1], p[2] end
end
function GetTaxiMapID() return mock.taxi.map or 1415 end
-- One of the flight map's buttons (the pointer is over it when it is mock.focus)
function mock.taxiButton(i)
    local b = _G["TaxiButton" .. i] or CreateFrame("Button", "TaxiButton" .. i)
    b.GetID = function() return i end
    b.IsMouseOver = function(self) return mock.focus == self end
    return b
end
-- Open the map at `from` (an index of nodes), choose `to` with the pointer, take off; fly() lands after `seconds`
function mock.takeFlight(nodes, from, to)
    mock.taxi.nodes, mock.taxi.current = nodes, from
    mock.fire("TAXIMAP_OPENED")
    local b = mock.taxiButton(to)
    mock.focus = b
    mock.fire("TAXIMAP_CLOSED")
    mock.focus = nil
    mock.taxi.onTaxi = true
    mock.fire("PLAYER_CONTROL_LOST")
end
function mock.landFlight(subzone)
    mock.taxi.onTaxi = false
    mock.subzone = subzone or mock.subzone
    mock.fire("PLAYER_CONTROL_GAINED")
end

function mock.loadHud(path, ns)
    local fn, err = loadfile(path)
    if not fn then error(err) end
    return fn("ControllerCam_HUD", ns)
end

return mock
