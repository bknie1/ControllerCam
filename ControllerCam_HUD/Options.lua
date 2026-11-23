-- ControllerCam HUD: options (Options > AddOns > ControllerCam HUD, with a page per area under it).
-- Every row is one registered setting: the same switches the /cchud commands flip. Rows under "Native Options"
-- are the game's own settings themselves, so this panel and the game's menus always agree.

local ADDON, ns = ...
local L = ns.L
local Options = { UNCHOSEN = 0.45 }        -- how faint the buttons not chosen in a row of choices are
ns.OptionsLook = Options

---------------------------------------------------------------------------
-- The settings that already had commands, described here so they get a row too
---------------------------------------------------------------------------
local order = 0
local function View(def)
    order = order + 1
    def.order = order
    if def.key then def.default = ns.DEFAULTS[def.key] end
    return ns.RegisterSetting(def)
end
local function Unit(key, label, tip)
    View({ section = "Frames", kind = "boolean", label = label, tip = tip,
           get = function() return ns.db.units[key] end, set = function(v) ns.db.units[key] = v end })
end
local function Sell(key, label, tip)
    View({ section = "Bags, bank and vendor", kind = "boolean", label = label, tip = tip,
           get = function() return ns.db.sell[key] end, set = function(v) ns.db.sell[key] = v end,
           onChange = function() end })
end
local function Native(key, label, tip)
    View({ section = "Native Options", kind = "boolean", label = label, tip = tip,
           get = function() return ns.GetNative(key) end, set = function(v) ns.SetNative(key, v) end,
           available = function() return ns.GetNative(key) ~= nil end })
end
local function Look() ns.UnitFrames:Refresh(); ns.UnitFrames:ApplyLook() end

View({ section = "General", kind = "boolean", key = "enabled", label = "Enabled",
       tip = "the whole HUD; off brings the game's own frames back",
       share = false, onChange = function() ns.db.asked = true; ns.Apply() end })
View({ section = "General", kind = "boolean", key = "always", label = "Also in the mouse & keyboard UI",
       tip = "normally the HUD only runs while the Gamepad UI is in use" })
View({ section = "General", kind = "boolean", key = "hideBlizzard", label = "Put the game's frames aside",
       tip = "hide the game's player, target and focus frames while ours are shown" })
View({ section = "General", kind = "boolean", key = "chat", label = "Chat window at the top left",
       tip = "move the chat window to the top left while the HUD runs" })

Unit("player", "Player frame", "our player bar, top left")
Unit("target", "Target frame", "our target bar, top centre")
Unit("pet", "Pet bar", "a small pet bar under the player bar, or beside the vertical bars")
Unit("focus", "Focus frame", "our focus frame")
Unit("vertical", "Vertical bars", "slim upright health and power bars beside your character, for a third-person view (in place of the player bar)")
View({ section = "Frames", kind = "number", key = "verticalIdle", min = 0, max = 1, percent = true, onChange = function() end,
       label = "Vertical bars when idle", tip = "how visible the vertical bars stay at full health out of combat (0 hides them)" })
View({ section = "Frames", kind = "boolean", key = "classColors", label = "Class colours", onChange = Look,
       tip = "colour your bar, and other players' bars, by class" })
View({ section = "Frames", kind = "boolean", key = "classIcons", label = "Class icons", onChange = Look,
       tip = "a class icon in front of a player's name on the target and target of target" })
View({ section = "Frames", kind = "boolean", key = "targetThreat", label = "Threat on the target frame", onChange = Look,
       tip = "a shield icon and a glow on the target frame: red while it attacks you, red and yellow when you are about to pull it, yellow and blue when you are losing it, blue when it is not on you" })
View({ section = "Frames", kind = "boolean", id = "compactAll", label = "Compact bars everywhere",
       tip = "the target frame and nameplates in their compact style, a little over half as wide (each one can still be set on its own; presets never change it)",
       get = function() return (ns.db.targetCompact and ns.db.plateCompact) and true or false end,
       set = function(v) ns.db.targetCompact, ns.db.plateCompact = v, v end,
       onChange = function() Look(); ns.Apply() end })
View({ section = "Frames", kind = "boolean", key = "targetCompact", label = "Compact target frame", onChange = Look,
       tip = "the target frame a little over half as wide" })
View({ section = "Frames", kind = "boolean", key = "combatColors", label = "Health colours in a fight", onChange = Look,
       tip = "in a fight, health bars turn from green through yellow to red as health drops" })
View({ section = "Frames", kind = "boolean", key = "textShade", label = "Shade behind text", onChange = Look,
       tip = "a soft dark band behind the target's text, to keep it readable" })
View({ section = "Frames", kind = "number", key = "textScale", min = 0.8, max = 2.5, percent = true,
       label = "Text size", tip = "size of the text on our frames", onChange = Look })
View({ section = "Frames", kind = "number", key = "scale", min = 0.5, max = 2, percent = true,
       label = "Frame size", tip = "size of our unit frames" })
View({ section = "Frames", kind = "number", key = "combatAlpha", min = 0, max = 1, percent = true, onChange = function() end,
       label = "Your bars in a fight", tip = "how visible your bars, pet and focus are in a fight until something calls for attention" })
View({ section = "Frames", kind = "number", key = "alertHealth", min = 0, max = 1, percent = true, onChange = function() end,
       label = "Full when health is below", tip = "your bars come back in full when your health drops below this" })
View({ section = "Frames", kind = "number", key = "alertPower", min = 0, max = 1, percent = true, onChange = function() end,
       label = "Full when mana is below", tip = "your bars come back in full when your mana drops below this" })
View({ section = "Frames", kind = "number", key = "idle", min = 0, max = 1, percent = true, onChange = function() end,
       label = "Player bar when idle", tip = "how visible the player bar stays at full health or out of combat (0 hides it)" })

View({ section = "Bags, bank and vendor", kind = "boolean", key = "vendor", label = "Vendor and bank help",
       tip = "the vendor's Sell junk button asks what to sell; quick move at vendor and bank" })
Sell("auto", "Sell junk when a vendor opens", "sell junk by your rules as soon as a vendor opens")
Sell("gear", "White weapons and armor are junk", "count white weapons and armor as junk (never tools, fishing poles, gear with a use, or anything that could be an upgrade; always asked first)")
Sell("deposit", "Deposit when the bank opens", "items marked for the bank, and what the bank already holds (when that is on), go in by themselves")

Native("tot", "Target of target", "the game's option; our small frame follows it")
Native("cooldowns", "Cooldown Manager", "the game's Cooldown Manager")
Native("resource", "Personal Resource Display", "your health and power under your character")
Native("reagents", "Bank takes reagents by itself", "the game's option for the bank")
Native("auratooltip", "Tooltip when a buff starts", "the game's option: a buff's tooltip pops up for a moment when it is applied (Gamepad UI)")
Native("chatclass", "Class colours for names in chat", "the game's chat setting for every kind of chat at once: a player's name in their class colour")

---------------------------------------------------------------------------
-- The panel: a main page (presets, layouts, demo, self-check, the Advanced switch, the basics of "General")
-- and one page per area under it. Out of the box each page shows the main switches; "Show advanced options"
-- adds the fine tuning.
---------------------------------------------------------------------------
-- The switches shown without Advanced (by label); everything else is fine tuning
local BASIC = {}
for _, label in ipairs({
    "Enabled", "Player frame", "Target frame", "Pet bar", "Focus frame", "Vertical bars", "Class icons",
    "Text size", "Party and raid frames", "Cast bar",
    "Hit effects by damage school", "Hit particles", "Cast wind-up", "Fishing float", "Health colours in a fight",
    "Nameplates", "Your debuffs", "Quest marker", "Aggro glow", "Mini plates", "Compact nameplates",
    "Compact target frame", "Loud enemy casts", "Fade out of combat", "Your bars in a fight", "Threat on the target frame",
    "Enemy buffs", "Crowd control icon", "Enemy buffs on the target", "Only the effects that matter",
    "Debuffs on a friendly target", "The game's own friendly nameplates", "Confirm the experimental features notice",
    "Full when health is below", "Player bar when idle", "Vertical bars when idle",
    "Quest list: current zone only", "Chat fades when quiet", "Coordinates on the map", "Tooltips follow the cursor",
    "Vendor and bank help", "Sell junk when a vendor opens", "Slim gamepad bars",
    "Target of target", "Cooldown Manager", "Personal Resource Display", "Tooltip when a buff starts",
    "Restyle the game's own frames", "Stylized numbers on you", "Item counts in tooltips", "Repair at vendors",
    "Class icon and level in chat", "Hide gold sellers and repeated adverts", "Class colours for names in chat",
    "Friendly NPCs only when pointed at", "Incoming heals in their school's colour", "Heals over time grow on the bar",
    "Controller vibration", "Rumble: your key abilities", "Big moments", "Vibration strength", "Light bar shows your health",
    "Cast bar animations", "The screen at rest", "Stance and pet buttons above the bars", "One-button fishing",
    "Market tab at the auction house", "Debug reports", "Chat text size", "Cast bar size",
    "Cooldown rows clear of the gamepad bars", "Fishing front and centre", "Fish journal", "Fishing interface",
    "Bait on a double press", "Quest list: nearest first", "Quest list: recommended order",
    "Quest list: no group quests while alone", "Quest list: only the nearest", "Shields show as a ward",
    "A game while the float is out", "Party nameplates in dungeons: names only", "Party nameplates in dungeons: hidden",
    "Seconds before chat fades", "Quest list: short objectives", "Gamepad bars put away while fishing",
    "Reduce animations", "Catches and camp buffs across the screen",
    "Quest progress in chat", "Flights: time and countdown", "Flights: a game on the way", "Reminder to drink water", "Water reminder every (minutes)",
    "Hide repeated guild recruitment",
    "Keep what your quests need", "Quest compass", "Quest compass: place",
    "Quest progress to your party",
    "Fades: gamepad bars", "Fades: minimap", "Fades: quest list", "Fades: damage meter", "Fades: experience bar",
    "Fades: buffs", "Fades: cooldown rows", "Aiming dot", "Narrative: characters in the windows",
}) do BASIC[label] = true end
ns.BASIC_OPTIONS = BASIC

-- Where each setting goes: its page, and the heading it sits under there, in the order shown. One page per
-- thing you might want to change, so it is found where you would look for it. (A setting is named by its key, or
-- by its label where it has none.)
local LAYOUT = {
    { page = "General", groups = {
        { "enabled", "always", "hideBlizzard", "debug" },
        { head = "Narrative", "narrative" },
        { head = "Water reminder", "hydrate", "hydrateEvery", "hydrateFlight" },
    } },
    { page = "Your frames", groups = {
        { head = "Your bars", "Player frame", "Vertical bars", "verticalIdle", "followZoom", "idle", "Pet bar", "petMood",
          "Personal Resource Display", "breathBar", "sleepy" },
        { head = "In a fight", "combatAlpha", "alertHealth", "alertPower", "playerShake" },
        { head = "Health bars", "classColors", "combatColors", "shieldBars", "wards", "healColors", "hotVines" },
        { head = "Cast bar", "castbar", "castScale", "castUpright", "castArt", "castWindup" },
        { head = "Size and text", "scale", "textScale", "textShade", "compactAll" },
    } },
    { page = "Target, party and raid", groups = {
        { head = "Target and focus", "Target frame", "Focus frame", "Target of target", "targetCompact",
          "targetHealthText", "targetThreat", "threatPercent", "executeGlow" },
        { head = "Names and classes", "classIcons", "classNames", "lastNames", "repColors", "factionMarks", "factionStyle" },
        { head = "Effects on the target", "auras", "targetBuffs", "smartAuras", "friendDebuffs", "combo" },
        { head = "Party and raid", "group", "healerFrames" },
    } },
    { page = "Nameplates", groups = {
        { head = "Which nameplates", "nameplates", "plateFriendsGame", "plateHoverNPC", "plateObjects", "plateMini",
          "plateFriendsInside", "plateFriendsHide" },
        { head = "Look", "plateLook", "plateSize", "plateCompact", "plateName", "plateMotion" },
        { head = "Names", "plateLevels", "plateClassIcons", "plateTitles", "plateSubtitles", "plateServiceIcons",
          "plateTargetName", "plateQuest" },
        { head = "Health and power", "plateValue", "platePercent", "platePower", "plateFriendBars" },
        { head = "In a fight", "plateThreat", "plateCastAlert", "plateCastTarget", "plateDebuffs", "plateAllDebuffs",
          "plateBuffs", "plateCC" },
    } },
    { page = "Effects", groups = {
        { head = "Hits", "impacts", "impactFx", "woundFx" },
        { head = "Numbers and callouts", "numbers", "readyAlerts", "soonCallouts", "soonBuffs", "Tooltip when a buff starts" },
        { head = "Big moments", "bigMoments", "momentPlace" },
        { head = "Out of a fight", "readouts", "campScene" },
    } },
    { page = "Vibration", groups = {
        { head = "Controller", "rumble", "rumbleStrength", "lightBar" },
        { head = "What rumbles", "abilityRumble", "rumbleHits", "rumbleCrits", "rumbleInterrupts", "rumbleLowHealth",
          "rumbleAggro", "rumbleAlerts", "rumbleSeals", "rumbleCasts", "rumbleLevel" },
    } },
    { page = "Camera and aiming", groups = {
        { head = "Aiming dot", "reticleStyle", "reticleColor", "reticleSize", "reticleAlpha" },
        { head = "Camera", "presetZoom", "followCamera" },
    } },
    { page = "Gamepad bars", groups = {
        { head = "Gamepad bars", "bars", "barScale", "padRaise" },
        { head = "Cooldowns", "rowsAside", "Cooldown Manager" },
    } },
    { page = "Screen fade", groups = {
        { "hudFade", "hudIdle" },
        { head = "What fades", "restBars", "restMinimap", "restTracker", "restMeter", "restXP", "restBuffs", "restRows" },
    } },
    { page = "Restyled game frames", groups = {
        { "skin" },
        { head = "Which frames", "skintooltips", "skingamepad", "skinbuffs", "skintracker", "skinminimap", "skinxpbar",
          "xpScale", "skinchat", "skindamagemeter" },
    } },
    { page = "Chat and messages", groups = {
        { head = "Chat window", "chat", "chatScale", "chatFade", "chatTime" },
        { head = "Names in chat", "Class colours for names in chat", "chatInfo", "chatShort", "chatFirstName" },
        { head = "Filters", "chatSpam", "chatRecruit" },
        { head = "Error messages", "quietErrors", "quietNotReady" },
    } },
    { page = "Quests and map", groups = {
        { head = "Quest list", "questzone", "questSolo", "questNear", "questNearest", "questPlan", "questFocusNear",
          "questShort" },
        { head = "Quest compass", "compass", "compassPlace" },
        { head = "Quest progress", "questProgress", "questParty", "questPartyAll" },
        { head = "Farm list", "farmList", "farmSide" },
        { head = "Map", "mapCoords" },
    } },
    { page = "Flights", groups = {
        { head = "Flight bar", "flights", "flightRider", "flightWeather", "flightGame" },
        { head = "Cinematic flights", "flightScene", "flightOrbit" },
    } },
    { page = "Bags, bank and vendor", groups = {
        { head = "Bags", "bagWindow", "bagOrder", "padSort", "padMove" },
        { head = "Vendor", "vendor", "Sell junk when a vendor opens", "White weapons and armor are junk", "autoRepair",
          "repairGuild" },
        { head = "Bank", "Deposit when the bank opens", "depositMatching", "Bank takes reagents by itself" },
        { head = "Mail", "mailTakeAll", "mailSubject" },
    } },
    { page = "Items and auction house", groups = {
        { head = "Item advice", "auctionVerdict", "adviceUnsure", "upgradeSpecs", "statValues", "questItems", "skillKeep" },
        { head = "Tooltips", "invTotals", "vendorPrice", "auctionPrice" },
        { head = "Auction house", "ahPanel", "auctionScan", "ahStrategy", "ahVoice", "ahShowKept", "ahCandles" },
        { head = "Appearances", "transmogSets", "tipAppearance" },
    } },
    { page = "Fishing and professions", groups = {
        { head = "Fishing", "fishMode", "fishing", "fishBig", "fishRecast", "fishBait", "fishHideBars", "fishJournal",
          "fishPanel", "fishGame" },
        { head = "Professions", "skillPlan", "skillBank" },
    } },
    { page = "Accessibility", groups = {
        { "reduceMotion" },
    } },
}
-- The pages under the main one, in this order (the same as above)
local PAGES = { "Your frames", "Target, party and raid", "Nameplates", "Effects", "Vibration", "Camera and aiming",
                "Gamepad bars", "Screen fade", "Restyled game frames", "Chat and messages", "Quests and map", "Flights",
                "Bags, bank and vendor", "Items and auction house", "Fishing and professions", "Accessibility" }

local PLACE = {}                                  -- name -> { page, group, rank }
local rank = 0
for _, p in ipairs(LAYOUT) do
    for gi, g in ipairs(p.groups) do
        for _, name in ipairs(g) do
            rank = rank + 1
            PLACE[name] = { page = p.page, group = g, rank = rank }
        end
    end
end
Options.LAYOUT, Options.PAGES = LAYOUT, PAGES

-- A setting not in the list above (none should be): the page its section names
local PAGE_OF = {
    ["General"] = "General", ["Frames"] = "Your frames", ["Effects"] = "Effects", ["Nameplates"] = "Nameplates",
    ["Quests"] = "Quests and map", ["Quests, chat and map"] = "Quests and map", ["Gamepad bars"] = "Gamepad bars",
    ["Bags, bank and vendor"] = "Bags, bank and vendor", ["Native Options"] = "Your frames",
    ["Look"] = "Restyled game frames", ["Fishing"] = "Fishing and professions", ["Accessibility"] = "Accessibility",
    ["Screen fade"] = "Screen fade",
}

local function PlaceOf(def)
    return (def.key and PLACE[def.key]) or (def.id and PLACE[def.id]) or (def.label and PLACE[def.label])
end
Options.PlaceOf = PlaceOf

local function PageOf(def)
    local place = PlaceOf(def)
    if place then return place.page end
    return PAGE_OF[def.section or ""] or "General"
end
ns.OptionPageOf = PageOf

ns.RegisterSetting({
    key = "advancedOptions", kind = "boolean", default = false, command = "advanced", section = "Options",
    label = "Show advanced options", tip = "every setting, not only the main switches",
    onChange = function() if ns.LayoutOptions then ns.LayoutOptions() end end,
})

local refreshers, refreshing, built = {}, false, false
local pages = {}
ns.optionRows = {}

local function RefreshAll()
    refreshing = true
    for _, fn in ipairs(refreshers) do fn() end
    refreshing = false
end
ns.RefreshOptions = RefreshAll

local function Tooltip(frame, text)
    -- (a tooltip of our own: the game's is never opened or closed by us, Tooltip.lua says why)
    frame:SetScript("OnEnter", function(self)
        local tip = ns.Tooltip and ns.Tooltip.Own()
        if not tip then return end
        tip:SetOwner(self, "ANCHOR_RIGHT")
        tip:SetText(text, 1, 1, 1, 1, true)
        tip:Show()
    end)
    frame:SetScript("OnLeave", function()
        local tip = ns.Tooltip and ns.Tooltip.Own()
        if tip then tip:Hide() end
    end)
end

local function Text(parent, template, text)
    local fs = parent:CreateFontString(nil, "ARTWORK", template)
    fs:SetText(text)
    return fs
end

local function Button(parent, label, onClick, tip, width)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetText(label)
    local fs = b:GetFontString()
    b:SetSize(width or math.max(120, (fs and fs:GetStringWidth() or 100) + 30), 24)
    b:SetScript("OnClick", onClick)
    if tip then Tooltip(b, tip) end
    return b
end

-- Quick switches, right under the modules: the bar style (compact or full, everywhere or one by one)
ns.STYLE = { "compactAll", "targetCompact", "plateCompact" }

-- The HUD's modules, switched on and off at the top of its main page: every part you might want or not, one
-- switch each (what's on the screen, then the windows, then the extras), so you take only the parts you want
ns.MODULES = { "nameplates", "group", "castbar", "impacts", "numbers", "bigMoments", "rumble", "skin", "hudFade",
               "bars", "compass", "questzone",
               "bagWindow", "vendor", "invTotals", "ahPanel", "skillPlan", "fishMode", "transmogSets", "narrative",
               "flights", "campScene", "chatSpam", "chatInfo" }

local function NewPage(name, parentName)
    local frame = CreateFrame("Frame", nil)
    frame.name = name
    frame.parent = parentName
    local title = Text(frame, "GameFontNormalLarge", name == "ControllerCam HUD" and name or L[name])
    title:SetPoint("TOPLEFT", 16, -16)
    frame.title = title
    return frame
end

-- One row per setting, inside a scrolling area of the page
local function Row(content, def)
    local row = { def = def, page = PageOf(def), basic = BASIC[def.label] or false }
    if def.kind == "boolean" then
        local cb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
        if cb.Text then cb.Text:SetText(L[def.label]) end
        cb:SetScript("OnClick", function(self)
            if refreshing then return end
            ns.Set(def, self:GetChecked() and true or false)
            RefreshAll()
        end)
        row.widget, row.height = cb, 28
        refreshers[#refreshers + 1] = function()
            cb:SetChecked(ns.Get(def) and true or false)
            if def.available then cb:SetEnabled(def.available() and true or false) end
        end
    elseif def.choices then
        -- one of a few (a number setting, 1 to the number of choices): a button each, the chosen one lit
        local label = Text(content, "GameFontHighlight", L[def.label])
        local holder = CreateFrame("Frame", nil, content)
        local perRow = 3                                  -- (more than three wrap onto the next row)
        local rows = math.ceil(#def.choices / perRow)
        holder:SetSize(math.min(#def.choices, perRow) * 92, 24 + (rows - 1) * 28)
        local buttons = {}
        for i, choice in ipairs(def.choices) do
            local b = Button(holder, L[choice], function()
                if refreshing then return end
                ns.Set(def, i)
                RefreshAll()
            end, def.tip and L[def.tip], 88)
            b:SetPoint("TOPLEFT", holder, "TOPLEFT", ((i - 1) % perRow) * 92, -math.floor((i - 1) / perRow) * 28)
            -- the chosen one: a gold line under it and gold text; the others dimmed (still pressable)
            b.chosenLine = b:CreateTexture(nil, "OVERLAY")
            b.chosenLine:SetColorTexture(1, 0.82, 0.2, 1)
            b.chosenLine:SetHeight(2)
            b.chosenLine:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 4, -1)
            b.chosenLine:SetPoint("TOPRIGHT", b, "BOTTOMRIGHT", -4, -1)
            b.chosenLine:Hide()
            buttons[i] = b
        end
        row.widget, row.label, row.height, row.buttons = holder, label, 32 + (rows - 1) * 28, buttons
        refreshers[#refreshers + 1] = function()
            local v = ns.Get(def)
            for i, b in ipairs(buttons) do
                local on = i == v
                if on then b:LockHighlight() else b:UnlockHighlight() end
                b:SetAlpha(on and 1 or Options.UNCHOSEN)
                b.chosenLine:SetShown(on)
                b.chosen = on
                local fs = b.GetFontString and b:GetFontString()
                if fs and fs.SetTextColor then
                    if on then fs:SetTextColor(1, 0.82, 0.2) else fs:SetTextColor(0.75, 0.75, 0.75) end
                end
            end
        end
    else
        local mult = def.percent and 100 or 1
        local label = Text(content, "GameFontHighlight", "")
        local sl = CreateFrame("Slider", nil, content, "OptionsSliderTemplate")
        sl:SetWidth(200)
        sl:SetMinMaxValues(def.min * mult, def.max * mult)
        sl:SetValueStep(def.percent and 5 or 1)
        if sl.SetObeyStepOnDrag then sl:SetObeyStepOnDrag(true) end
        local function show(v)
            label:SetText(("%s: %s"):format(L[def.label], def.percent and ("%d%%"):format(v * 100 + 0.5) or tostring(v)))
        end
        sl:SetScript("OnValueChanged", function(_, v)
            if refreshing then return end
            ns.Set(def, v / mult)
            show(ns.Get(def))
        end)
        row.widget, row.label, row.height = sl, label, 36
        refreshers[#refreshers + 1] = function()
            local v = ns.Get(def)
            sl:SetValue(v * mult)
            show(v)
        end
    end
    if def.tip then Tooltip(row.widget, L[def.tip]) end
    ns.optionRows[#ns.optionRows + 1] = row
    return row
end

local function Scroll(page, below)
    local scroll = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", below, "BOTTOMLEFT", 0, -12)
    scroll:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -30, 12)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(560, 100)
    scroll:SetScrollChild(content)
    page.content, page.rows = content, {}
    return content
end

-- Show the rows a page should have (basic, or all with Advanced), one under the other
function ns.LayoutOptions()
    local advanced = ns.db and ns.db.advancedOptions
    for _, page in pairs(pages) do
        local y = -4
        for _, row in ipairs(page.rows) do
            local show = advanced or row.basic
            if row.members then                           -- a heading: shown with what is under it
                show = false
                for _, m in ipairs(row.members) do
                    if advanced or m.basic then show = true; break end
                end
                if show and y < -4 then y = y - 8 end     -- (a little room above it)
            end
            row.widget:ClearAllPoints()
            if row.label then row.label:ClearAllPoints() end
            if show then
                if row.label then
                    row.label:SetPoint("TOPLEFT", page.content, "TOPLEFT", 14, y - 4)
                    row.widget:SetPoint("TOPLEFT", page.content, "TOPLEFT", 300, y - 4)
                    row.label:Show()
                else
                    row.widget:SetPoint("TOPLEFT", page.content, "TOPLEFT", 8, y)
                end
                row.widget:Show()
                y = y - row.height
            else
                row.widget:Hide()
                if row.label then row.label:Hide() end
            end
        end
        page.content:SetHeight(-y + 20)
        if page.hint then
            if advanced then page.hint:Hide() else page.hint:Show() end
        end
    end
end

local main = NewPage("ControllerCam HUD")

function ns.BuildOptions()
    if built or not ns.db then return end
    built = true

    -- the main page
    local note = Text(main, "GameFontHighlightSmall",
        L["Shown while the Gamepad UI is in use. Drag our frames in the game's Edit Mode."])
    note:SetPoint("TOPLEFT", main.title, "BOTTOMLEFT", 0, -6)
    local presetsHead = Text(main, "GameFontNormal", L["Presets"])
    presetsHead:SetPoint("TOPLEFT", note, "BOTTOMLEFT", 0, -14)
    local prev, rowStart, rows = nil, nil, 0
    for i, preset in ipairs(ns.Presets.HUD) do
        local b = Button(main, L[preset.label], function() ns.Presets:Apply(preset.key) end, L[preset.tip])
        if (i - 1) % 4 == 0 then                       -- four to a row
            b:SetPoint("TOPLEFT", rowStart or presetsHead, "BOTTOMLEFT", 0, -6)
            rowStart, rows = b, rows + 1
        else
            b:SetPoint("LEFT", prev, "RIGHT", 8, 0)
        end
        prev = b
    end
    local sizeHead = Text(main, "GameFontNormal", L["Sized for"])
    sizeHead:SetPoint("TOPLEFT", rowStart, "BOTTOMLEFT", 0, -12)
    local tv = Button(main, L["TV"], function() SlashCmdList["CCHUD"]("sizefor tv") end,
        L["size the text for a TV across the room, or for a monitor at arm's length"])
    tv:SetPoint("TOPLEFT", sizeHead, "BOTTOMLEFT", 0, -6)
    local monitor = Button(main, L["Monitor"], function() SlashCmdList["CCHUD"]("sizefor monitor") end,
        L["size the text for a TV across the room, or for a monitor at arm's length"])
    monitor:SetPoint("LEFT", tv, "RIGHT", 8, 0)
    rowStart = tv
    -- the icons on the buttons: the game's own style for the controller in use (PadIcons.lua)
    local iconsHead = Text(main, "GameFontNormal", L["Button icons"])
    iconsHead:SetPoint("TOPLEFT", rowStart, "BOTTOMLEFT", 0, -12)
    prev = nil
    ns.padIconButtons = {}
    for _, kind in ipairs(ns.PadIcons.ORDER) do
        local b = Button(main, ns.PadIcons.Name(kind), function() SlashCmdList["CCHUD"]("padicons " .. kind) end,
            L["the icons the game shows for your controller's buttons: found by itself for the controller in use, or the kind you choose"], 94)
        if prev then
            b:SetPoint("LEFT", prev, "RIGHT", 6, 0)
        else
            b:SetPoint("TOPLEFT", iconsHead, "BOTTOMLEFT", 0, -6)
            rowStart = b
        end
        ns.padIconButtons[kind] = b
        prev = b
    end
    if ns.FontsOffered() then
        local fontHead = Text(main, "GameFontNormal", L["Font"])
        fontHead:SetPoint("TOPLEFT", rowStart, "BOTTOMLEFT", 0, -12)
        prev = nil
        for _, c in ipairs(ns.FONT_CHOICES) do
            local b = Button(main, ns.FontName(c[1]), function() SlashCmdList["CCHUD"]("font " .. c[1]) end,
                L["one font for the HUD and the game's own text (windows, tooltips, chat, buttons); each keeps its size"], 94)
            if prev then
                b:SetPoint("LEFT", prev, "RIGHT", 6, 0)
            else
                b:SetPoint("TOPLEFT", fontHead, "BOTTOMLEFT", 0, -6)
                rowStart = b
            end
            prev = b
        end
    end
    local layoutHead = Text(main, "GameFontNormal", L["Reset the game's layout"])
    layoutHead:SetPoint("TOPLEFT", rowStart, "BOTTOMLEFT", 0, -12)
    prev = nil
    for _, layout in ipairs(ns.Presets.GAME) do
        local b = Button(main, L[layout.label], function()
            SlashCmdList["CCHUD"]("layout " .. layout.key)
        end, L["put our frames back where they start, for the game's own Modern or Classic layout"])
        if prev then b:SetPoint("LEFT", prev, "RIGHT", 8, 0) else b:SetPoint("TOPLEFT", layoutHead, "BOTTOMLEFT", 0, -6) end
        prev = b
    end
    local toolsHead = Text(main, "GameFontNormal", L["Try it out"])
    toolsHead:SetPoint("TOPLEFT", layoutHead, "BOTTOMLEFT", 0, -42)
    local demo = Button(main, L["Play the demo"], function() SlashCmdList["CCHUD"]("demo") end)
    demo:SetPoint("TOPLEFT", toolsHead, "BOTTOMLEFT", 0, -6)
    local test = Button(main, L["Show every hit effect"], function() SlashCmdList["CCHUD"]("hittest") end)
    test:SetPoint("LEFT", demo, "RIGHT", 8, 0)
    local check = Button(main, L["Run the self-check"], function() ns.RunCheck(true) end)
    check:SetPoint("LEFT", test, "RIGHT", 8, 0)
    local compact = Button(main, L["Gamepad bars: compact / full"], function() SlashCmdList["CCHUD"]("compact") end,
        L["the game's gamepad bars in compact or full mode (the same as its Edit Mode setting)"])
    compact:SetPoint("TOPLEFT", demo, "BOTTOMLEFT", 0, -8)
    local export = Button(main, L["Export settings"], function() ns.Share.ShowExport() end,
        L["your settings as one line of text, to keep or share"])
    export:SetPoint("LEFT", compact, "RIGHT", 8, 0)
    local import = Button(main, L["Import settings"], function() ns.Share.ShowImport() end,
        L["take settings from a line of text made by /cchud export"])
    import:SetPoint("LEFT", export, "RIGHT", 8, 0)

    local below = compact
    pages.General = main
    local content = Scroll(main, below)
    main.content = content

    -- the area pages
    for _, name in ipairs(PAGES) do
        local page = NewPage(name, main.name)
        local hint = Text(page, "GameFontHighlightSmall", L["Tick “Show advanced options” on the main page for every setting."])
        hint:SetPoint("TOPLEFT", page.title, "BOTTOMLEFT", 0, -6)
        page.hint = hint
        Scroll(page, hint)
        pages[name] = page
    end

    -- every setting, in registration order, on its page
    local advancedRow
    for _, def in ipairs(ns.settings) do
        if def.label then
            local page = pages[PageOf(def)] or main
            if def.key == "advancedOptions" then page = main end
            local row = Row(page.content, def)
            if def.key == "advancedOptions" then
                row.basic = true
                advancedRow = row
            else
                page.rows[#page.rows + 1] = row
            end
        end
    end
    -- each page in the order above, under its headings (anything not listed goes last)
    for _, page in pairs(pages) do
        local placed, rest = {}, {}
        for _, row in ipairs(page.rows) do
            local place = PlaceOf(row.def)
            if place then placed[#placed + 1] = { row = row, place = place } else rest[#rest + 1] = row end
        end
        table.sort(placed, function(a, b) return a.place.rank < b.place.rank end)
        local rows, group, head = {}, nil, nil
        for _, p in ipairs(placed) do
            if p.place.group ~= group then
                group, head = p.place.group, nil
                if group.head then
                    head = { widget = Text(page.content, "GameFontNormal", L[group.head]), height = 24, members = {} }
                    rows[#rows + 1] = head
                end
            end
            if head then head.members[#head.members + 1] = p.row end
            rows[#rows + 1] = p.row
        end
        for _, row in ipairs(rest) do rows[#rows + 1] = row end
        page.rows = rows
    end

    -- the modules: one switch each, at the top of the main page, so you take only the parts you want
    local list = {}
    local head = Text(main.content, "GameFontNormal", L["Modules"])
    list[1] = { widget = head, height = 26, basic = true }
    for _, key in ipairs(ns.MODULES) do
        for _, def in ipairs(ns.settings) do
            if def.key == key and def.label then
                local row = Row(main.content, def)
                row.basic = true
                list[#list + 1] = row
                break
            end
        end
    end
    list[#list + 1] = { widget = Text(main.content, "GameFontNormal", L["Quick switches"]), height = 26, basic = true }
    for _, key in ipairs(ns.STYLE) do
        for _, def in ipairs(ns.settings) do
            if (def.key == key or def.id == key) and def.label then
                local row = Row(main.content, def)
                row.basic = true
                list[#list + 1] = row
                break
            end
        end
    end
    local rest = Text(main.content, "GameFontNormal", L["General"])
    list[#list + 1] = { widget = rest, height = 26, basic = true }
    for i = #list, 1, -1 do table.insert(main.rows, 1, list[i]) end
    if advancedRow then table.insert(main.rows, 1, advancedRow) end
    ns.LayoutOptions()
    RefreshAll()
end

local function OnShow()
    ns.BuildOptions()
    RefreshAll()
end

-- Register the main page, then the area pages under it (they are built when the main page is first shown, or
-- by the first area page shown)
local areaFrames = {}
for _, name in ipairs(PAGES) do
    local holder = CreateFrame("Frame")
    holder.name = name
    holder:SetScript("OnShow", ns.Protect(function(self)
        OnShow()
        local page = pages[name]
        if page and not page.placed then
            page.placed = true
            page:SetParent(self)
            page:SetAllPoints(self)
        end
        if page then page:Show() end
    end))
    areaFrames[name] = holder
end
main:SetScript("OnShow", ns.Protect(OnShow))

-- Under ControllerCam's own options when the camera addon is there: Options > AddOns > ControllerCam > HUD, with
-- the HUD's pages under it (Frames, Nameplates...); on its own otherwise
local family = _G.ControllerCamSettings
if Settings and Settings.RegisterCanvasLayoutCategory then
    local category
    if family and family.category and Settings.RegisterCanvasLayoutSubcategory then
        category = Settings.RegisterCanvasLayoutSubcategory(family.category, main, L["HUD"])
        for _, name in ipairs(PAGES) do
            Settings.RegisterCanvasLayoutSubcategory(category, areaFrames[name], L[name])
        end
        ns.nested = true
    else
        category = Settings.RegisterCanvasLayoutCategory(main, main.name)
        if Settings.RegisterCanvasLayoutSubcategory then
            for _, name in ipairs(PAGES) do
                Settings.RegisterCanvasLayoutSubcategory(category, areaFrames[name], L[name])
            end
        end
        Settings.RegisterAddOnCategory(category)
    end
    ns.OpenOptions = function()
        Settings.OpenToCategory(category.GetID and category:GetID() or category.ID)
    end
elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(main)
    for _, name in ipairs(PAGES) do
        areaFrames[name].parent = main.name
        InterfaceOptions_AddCategory(areaFrames[name])
    end
    ns.OpenOptions = function()
        InterfaceOptionsFrame_OpenToCategory(main)
        InterfaceOptionsFrame_OpenToCategory(main)
    end
end

ns.RegisterCommand("config", function()
    if ns.OpenOptions then ns.OpenOptions() else ns.Say(L["The options panel is not available in this client."]) end
end, "/cchud config", "open the options panel (Options > AddOns > ControllerCam HUD)")
