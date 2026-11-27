-- ControllerCam HUD: the narrative. Every window the HUD improves has someone in it who helps you, as in a
-- role-playing game: a portrait (the game draws them: the vendor you are talking to, or you), a name, and one
-- short line about what the window shows and why it matters. Nothing to press: they only talk.
--   * your bags: you, muttering over them in your race's way (how much room is left, what the junk is worth,
--     what is new, what is worth selling);
--   * a vendor: the vendor (what they would pay for, what the auction house pays more for, your repairs);
--   * the bank: the banker (what of yours belongs in the bank, what the bank holds more of);
--   * the mailbox: the Postmaster (how many letters, what is in them, what waits for coin on delivery);
--   * the flight master's map: the flight master (how long the ride to the place you point at takes);
--   * fishing, and the fish journal: you, at the water (fish that got away, your bait, the fish still to find);
--   * the camp fire's scene: you, by the fire (the rest you have saved up);
--   * the auction house's Market: the Broker, and a profession's window: The Mentor (their own panels,
--     AuctionPanel.lua and Levelling.lua, ask N.On() whether to be characters or plain).
-- And you, now and then, on what just happened: Commentary.lua, with its lines in Remarks.lua.
-- One switch: with it off every window is plain and quiet (no portraits, no names, no voices, plain words).
-- Only shows: nothing of the game's windows is changed; each card is a child of its window, so it goes with it.

local ADDON = ...
local ns = ControllerCamHUD.ns            -- the HUD's own namespace: this file is one of its modules (Modules.lua)
local L, C = ns.L, ns.colors

local N = { cards = {}, voice = {} }
ns.Narrative = N


N.PORTRAIT = 44              -- the portrait's side
N.MIN_W, N.MAX_W = 260, 420  -- how wide a card may be (as wide as its window, between these)
N.GAP = 4                    -- between a card and its window
N.TALK = 2.4                 -- how long a speaker's lips move for a new line
N.SOON = 0.3                 -- a window's line is worked out again at most this often
N.LOW = 4                    -- bags with this many free slots or fewer are nearly full
N.GOLD = { 1, 0.82, 0.32 }
N.SAYS = { 0.91, 0.86, 0.72 } -- what they say: warm parchment, as The Mentor and the Broker
N.EDGE = { 0.98, 0.77, 0.31 }

local function Num(v) v = ns.Plain(v); return type(v) == "number" and v or nil end
local function Str(v) v = ns.Plain(v); return (type(v) == "string" and v ~= "") and v or nil end
local function Try(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if ok then return a, b, c, d end
end
N.Num, N.Try = Num, Try

function N.On() return ns.db ~= nil and ns.db.narrative ~= false and N.running ~= false end

---------------------------------------------------------------------------
-- The portrait: the game's own 3D model of the speaker (a unit: you, or the one you talk to), its flat
-- portrait where a model cannot be had, or an icon for one who is not a unit (the Postmaster, The Mentor)
---------------------------------------------------------------------------
N.ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
function N.Portrait(parent, size)
    local p = CreateFrame("Frame", nil, parent)
    p:SetSize(size, size)
    p.back = p:CreateTexture(nil, "BACKGROUND")
    p.back:SetAllPoints(p)
    p.back:SetColorTexture(0, 0, 0, 0.75)
    p.tex = p:CreateTexture(nil, "ARTWORK")
    p.tex:SetPoint("TOPLEFT", p, "TOPLEFT", 1, -1)
    p.tex:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -1, 1)
    local ok, model = pcall(CreateFrame, "PlayerModel", nil, p)
    if ok and type(model) == "table" then
        model:SetPoint("TOPLEFT", p, "TOPLEFT", 1, -1)
        model:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -1, 1)
        model:Hide()
        p.model = model
    end
    p.edge = {}
    for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
                            { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local t = p:CreateTexture(nil, "OVERLAY")
        t:SetPoint(side[1], p, side[1])
        t:SetPoint(side[2], p, side[2])
        if side[3] then t:SetHeight(1) else t:SetWidth(1) end
        t:SetColorTexture(N.EDGE[1], N.EDGE[2], N.EDGE[3], 0.8)
        p.edge[#p.edge + 1] = t
    end
    return p
end

-- Who to draw: speaker = { unit = "npc" | "player" | nil, icon = texture }. Returns how it was drawn.
function N.Draw(p, speaker)
    local unit = speaker.unit
    local here = unit and ns.Yes(Try(UnitExists, unit))
    if here and p.model and pcall(p.model.SetUnit, p.model, unit) then
        Try(p.model.SetPortraitZoom, p.model, 1)
        Try(p.model.SetCamDistanceScale, p.model, 1)
        p.model:Show()
        p.tex:Hide()
        p.from = "model"
        return p.from
    end
    if p.model then p.model:Hide() end
    p.tex:Show()
    if here and SetPortraitTexture and pcall(SetPortraitTexture, p.tex, unit) then
        p.tex:SetTexCoord(0, 1, 0, 1)
        p.from = "portrait"
        return p.from
    end
    p.tex:SetTexture(speaker.icon or N.ICON)
    p.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    p.from = "icon"
    return p.from
end

-- A new line: the model's lips move for a moment (the game's talk animation), then it stands at rest
function N.Talk(p)
    if not (p and p.from == "model" and p.model) then return end
    p.talks = (p.talks or 0) + 1
    local this = p.talks
    Try(p.model.SetAnimation, p.model, 60)
    if C_Timer and C_Timer.After then
        C_Timer.After(N.TALK, function()
            if p.talks == this then Try(p.model.SetAnimation, p.model, 0) end
        end)
    end
end

---------------------------------------------------------------------------
-- The card: the portrait, the speaker's name and their line, over the top of their window (under it where the
-- screen has no room above; beside it where there is room for neither, as with a tall window)
---------------------------------------------------------------------------
local function Height(fs, size, width)
    local h = Num(Try(fs.GetStringHeight, fs))
    if h and h > 0 then return math.ceil(h) end
    local text = Str(Try(fs.GetText, fs)) or ""
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    local per = math.max(10, math.floor((width or 300) / (size * 0.55)))
    return math.max(1, math.ceil(#text / per)) * (size + 3)
end
N.Height = Height

function N.Card(id)
    local card = N.cards[id]
    if card then return card end
    card = CreateFrame("Frame", "ControllerCamHUD_Speaker_" .. id, UIParent)
    if card.SetClampedToScreen then card:SetClampedToScreen(true) end         -- (never off the screen)
    card:SetSize(N.MIN_W, 60)
    card.back = card:CreateTexture(nil, "BACKGROUND")
    card.back:SetAllPoints(card)
    card.back:SetColorTexture(0.03, 0.04, 0.07, 0.92)
    for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" } }) do
        local t = card:CreateTexture(nil, "BORDER")
        t:SetPoint(side[1], card, side[1])
        t:SetPoint(side[2], card, side[2])
        t:SetHeight(1)
        t:SetColorTexture(N.EDGE[1], N.EDGE[2], N.EDGE[3], 0.6)
    end
    card.portrait = N.Portrait(card, N.PORTRAIT)
    card.portrait:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -8)
    card.name = ns.FontString(card, 11, "LEFT")
    card.name:SetPoint("TOPLEFT", card.portrait, "TOPRIGHT", 10, 0)
    card.name:SetPoint("RIGHT", card, "RIGHT", -10, 0)
    card.name:SetTextColor(N.GOLD[1], N.GOLD[2], N.GOLD[3])
    if card.name.SetWordWrap then card.name:SetWordWrap(false) end
    card.words = ns.FontString(card, 10, "LEFT")
    card.words:SetPoint("TOPLEFT", card.name, "BOTTOMLEFT", 0, -3)
    card.words:SetPoint("RIGHT", card, "RIGHT", -10, 0)
    card.words:SetTextColor(N.SAYS[1], N.SAYS[2], N.SAYS[3])
    if card.words.SetWordWrap then card.words:SetWordWrap(true) end
    card:Hide()
    card.id = id
    N.cards[id] = card
    return card
end

-- Over its window, as wide as it; under it when the top of the screen is too close
function N.Place(card, host)
    local w = Num(Try(host.GetWidth, host)) or N.MIN_W
    w = ns.Clamp(w, N.MIN_W, N.MAX_W)
    card:SetWidth(w)
    local text = w - 8 - N.PORTRAIT - 10 - 10
    card.words:SetWidth(text)
    local h = math.max(8 + N.PORTRAIT + 8,
        math.floor(8 + Height(card.name, 11, text) + 3 + Height(card.words, 10, text) + 9 + 0.5))
    card:SetHeight(h)
    card:ClearAllPoints()
    local top, hostK = Num(Try(host.GetTop, host)), Num(Try(host.GetEffectiveScale, host)) or 1
    local roof, uiK = Num(Try(UIParent.GetTop, UIParent)), Num(Try(UIParent.GetEffectiveScale, UIParent)) or 1
    local over = not (top and roof) or (top + h + N.GAP) * hostK <= roof * uiK
    local bottom = Num(Try(host.GetBottom, host))
    -- the bank's own buttons may be under the bank: the card goes under them
    local gap = N.GAP + ((ns.Vendor and ns.Vendor.bankRow == "under" and host == rawget(_G, "BankFrame")) and 28 or 0)
    if over then
        card:SetPoint("BOTTOMLEFT", host, "TOPLEFT", 0, N.GAP)
        card.at = "over"
    elseif not bottom or (bottom - h - gap) >= 0 then
        card:SetPoint("TOPLEFT", host, "BOTTOMLEFT", 0, -gap)
        card.at = "under"
    else
        local right, wide = Num(Try(host.GetRight, host)), Num(Try(UIParent.GetRight, UIParent))
        if right and wide and (right + N.GAP + w) * hostK > wide * uiK then
            card:SetPoint("TOPRIGHT", host, "TOPLEFT", -N.GAP, 0)
            card.at = "left"
        else
            card:SetPoint("TOPLEFT", host, "TOPRIGHT", N.GAP, 0)
            card.at = "right"
        end
    end
    ns.Note("narrative: %s speaks %s its window", tostring(card.id), card.at)
    return card.at
end

-- Speak in a window: speaker = { unit, name, icon, still = a thought: lips do not move }. Nothing (and the card put away) with the narrative off,
-- no words, or the window closed.
function N.Speak(id, host, speaker, words)
    if not (N.On() and type(host) == "table" and words and words ~= "" and ns.ShownPlain(host)) then
        return N.Hush(id)
    end
    local card = N.Card(id)
    if card:GetParent() ~= host then
        card:SetParent(host)
        Try(card.SetFrameStrata, card, Str(Try(host.GetFrameStrata, host)) or "HIGH")
        Try(card.SetFrameLevel, card, (Num(Try(host.GetFrameLevel, host)) or 1) + 10)
    end
    local name = speaker.name or (speaker.unit and Str(Try(UnitName, speaker.unit))) or ""
    local who = tostring(speaker.unit) .. "|" .. name .. "|" .. tostring(speaker.icon)
    if who ~= card.who or not card:IsShown() then
        N.Draw(card.portrait, speaker)
        card.who = who
    end
    card.name:SetText(name)
    if words ~= card.said then
        card.words:SetText(words)
        card.said = words
        if not speaker.still then N.Talk(card.portrait) end
    end
    N.Place(card, host)
    card:Show()
    return card
end

function N.Hush(id)
    local card = N.cards[id]
    if card then
        card:Hide()
        card.said, card.who = nil, nil
    end
    return nil
end

-- What a card says now (for the tests and the debug report), or nil when it is not showing
function N.Said(id)
    local card = N.cards[id]
    return card and card:IsShown() and card.said or nil
end

-- A window's line worked out again shortly (bags change many slots at once: once for them all)
function N.Soon(id, fn)
    if N.soon and N.soon[id] then return end
    N.soon = N.soon or {}
    N.soon[id] = true
    C_Timer.After(N.SOON, function()
        N.soon[id] = nil
        local ok, err = pcall(fn)
        if not ok then ns.Error(err) end
    end)
end

local function Shown(name)
    local f = rawget(_G, name)
    return ns.ShownPlain(f) and f or nil
end

---------------------------------------------------------------------------
-- You: your name, your model, and a voice that is your race's
---------------------------------------------------------------------------
function N.Me() return { unit = "player", name = Str(Try(UnitName, "player")) } end

-- A few words before you get to the point, the way your people would put it. Grumbling (N.RACE) only when the
-- advice really marks something as junk or for sale: what you carry is never called clutter or dead weight just
-- for being there. Otherwise a calm word (N.CALM).
N.RACE = {
    Human = L["Right, then."],
    Dwarf = L["Och, what a heap."],
    Gnome = L["Now, let's see, let's see..."],
    NightElf = L["Elune grant me patience."],
    Draenei = L["By the Naaru, such a jumble."],
    Worgen = L["Blasted pack."],
    Pandaren = L["A tidy pack is a light pack."],
    Orc = L["Bah. Too much clutter."],
    Scourge = L["Dead weight, the lot of it."],
    Tauren = L["Patience. The Earth Mother provides."],
    Troll = L["Ey, what we got here, mon?"],
    BloodElf = L["Such clutter. Unbecoming."],
    Goblin = L["Time is money. Let's count it."],
    HighOrder = L["Disorder. This will not do."],
    Windshaper = L["Too heavy. The wind likes a light traveller."],
}
N.CALM = {
    Human = L["Right, then."],
    Dwarf = L["Aye, that'll do."],
    Gnome = L["Now, let's see, let's see..."],
    NightElf = L["Elune be thanked."],
    Draenei = L["The Light provides."],
    Worgen = L["Hrm. Good enough."],
    Pandaren = L["A tidy pack is a light pack."],
    Orc = L["Hm. Enough to fight with."],
    Scourge = L["Travelling light. Good."],
    Tauren = L["Patience. The Earth Mother provides."],
    Troll = L["Ey, what we got here, mon?"],
    BloodElf = L["Acceptable. Barely."],
    Goblin = L["Time is money. Let's count it."],
    HighOrder = L["Everything catalogued. Good."],
    Windshaper = L["Light enough for the wind. Good."],
}
-- the allied races speak as their kin
N.KIN = { DarkIronDwarf = "Dwarf", EarthenDwarf = "Dwarf", LightforgedDraenei = "Draenei", KulTiran = "Human",
          Mechagnome = "Gnome", MagharOrc = "Orc", HighmountainTauren = "Tauren", ZandalariTroll = "Troll",
          VoidElf = "BloodElf", Nightborne = "BloodElf", Undead = "Scourge" }
-- Forever's Skyborne share one name in the game; which people they are is told by the race's number, or else
-- by their side: the High Order of the Alliance, the Windshapers of the Horde
N.SKYBORNE = { [95] = "HighOrder", [96] = "Windshaper", Alliance = "HighOrder", Horde = "Windshaper" }
function N.Race()
    local _, race, number = Try(UnitRace, "player")
    race = Str(race)
    if race and race:lower():find("skyborne", 1, true) then
        return N.SKYBORNE[Num(number) or 0] or N.SKYBORNE[Str(Try(UnitFactionGroup, "player")) or ""]
    end
    return race and (N.KIN[race] or race) or nil
end
function N.Mutter(words, grumble)
    if not words then return nil end
    local open = (grumble and N.RACE or N.CALM)[N.Race() or ""]
    return open and (open .. " " .. words) or words
end

---------------------------------------------------------------------------
-- What things are worth
---------------------------------------------------------------------------
local function VendorPrice(id)
    local M = ns.Market
    local price = M and M.Vendor and Try(M.Vendor, id)
    return Num(price) or 0
end

-- How many slots are free in your bags, and how many there are (counted slot by slot where the game has no count)
local function FreeSlots()
    local CC = C_Container or {}
    local get = CC.GetContainerNumFreeSlots or GetContainerNumFreeSlots
    local slots = CC.GetContainerNumSlots or GetContainerNumSlots
    local id = CC.GetContainerItemID or GetContainerItemID
    local free, total = 0, 0
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        local size = Num(Try(slots, bag)) or 0
        total = total + size
        local n = get and Num(Try(get, bag))
        if n then
            free = free + n
        elseif id then
            for slot = 1, size do if Try(id, bag, slot) == nil then free = free + 1 end end
        end
    end
    return free, total
end
N.FreeSlots = FreeSlots

---------------------------------------------------------------------------
-- Your bags: you, muttering
---------------------------------------------------------------------------
-- s = { free, total, junk = count, junkWorth = copper, new, sell, vendor = at a vendor, bank = how many belong
-- in the bank (at the bank) }. The one thing most worth saying, then why; and whether it is about junk or what to
-- sell (the advice's own marks), the only time you grumble about what you carry.
N.FEW = 12                   -- this many things or fewer, none to sell: just what you need on the road
function N.BagWords(s)
    local money = ns.Money or tostring
    if (s.total or 0) > 0 and s.free == 0 then
        if (s.junk or 0) > 0 and (s.junkWorth or 0) > 0 then
            return L["Not a slot to spare. The junk would fetch %s: selling it makes room."]:format(money(s.junkWorth)), true
        end
        return L["Not a slot to spare. Anything I won't need on the road can wait in the bank."]
    end
    if s.vendor and (s.junk or 0) > 0 then
        return L["Junk: %d, worth %s here. X sells the one I've picked; Smart sell takes it all."]:format(s.junk,
            money(s.junkWorth or 0)), true
    end
    if (s.bank or 0) > 0 then
        return L["%d of these belong in the bank: it holds more of the same, or I marked them. Deposit puts them away."]
            :format(s.bank)
    end
    if (s.total or 0) > 0 and s.free <= N.LOW then
        if (s.junk or 0) > 0 and (s.junkWorth or 0) > 0 then
            return L["Only %d slots left. The junk would fetch %s at any vendor."]:format(s.free, money(s.junkWorth)), true
        end
        return L["Only %d slots left. Time to sell or bank a few things."]:format(s.free)
    end
    if (s.new or 0) > 0 then
        return L["New since I last looked: %d. The gold dot marks each one."]:format(s.new)
    end
    if (s.sell or 0) > 0 then
        return L["Worth selling: %d. The Sell filter gathers them, and each tooltip says where it fetches most."]
            :format(s.sell), true
    end
    if (s.junk or 0) > 0 then
        return L["Junk: %d, worth %s. The next vendor can have it."]:format(s.junk, money(s.junkWorth or 0)), true
    end
    if (s.total or 0) - (s.free or 0) <= N.FEW then return L["Just the essentials. Nothing worth selling."] end
    return L["All in order, and %d slots free."]:format(s.free or 0)
end

-- The game's own bag window, when one is open: the combined bags, or the backpack
function N.GameBags()
    return Shown("ContainerFrameCombinedBags") or Shown("ContainerFrame1")
end

-- What the game's bags hold, as your thoughts need it. Only what can be said of the game's own window: nothing of
-- our window's gold dots or filters. Junk as the HUD marks it (yours, or grey and not kept)
function N.ReadGameBags()
    local free, total = FreeSlots()
    local s = { free = free, total = total, junk = 0, junkWorth = 0, new = 0, sell = 0, vendor = false }
    local CC = C_Container or {}
    local sell = ns.db.sell or { junk = {}, keep = {} }
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        for slot = 1, Num(Try(CC.GetContainerNumSlots, bag)) or 0 do
            local info = Try(CC.GetContainerItemInfo, bag, slot)
            local id = type(info) == "table" and Num(info.itemID) or nil
            if id and not sell.keep[id] and (sell.junk[id] or Num(info.quality) == 0) then
                s.junk = s.junk + 1
                s.junkWorth = s.junkWorth + VendorPrice(id) * (Num(info.stackCount) or 1)
            end
        end
    end
    return s
end

function N.Bags()
    local B = ns.Bags
    local host = rawget(_G, "ControllerCamHUD_Bags")
    if not (B and B.open and host and B.read) then
        -- the game's own bags (the start): quiet while the banker or a vendor is talking
        local game, V = N.GameBags(), ns.Vendor
        if not game or (V and (V.bankOpen or V.merchantOpen)) then return N.Hush("bags") end
        local s = N.ReadGameBags()
        N.bagState = s
        return N.Speak("bags", game, N.Me(), N.Mutter(N.BagWords(s)))
    end
    if B.view == "bank" then return N.Hush("bags") end
    local read = B.read
    local s = { free = math.max(0, (read.total or 0) - (read.used or 0)), total = read.total or 0, junk = 0,
                junkWorth = 0, new = 0, sell = (B.counts and B.counts.sell) or 0, vendor = B.merchantOpen }
    for _, e in ipairs(read.items or {}) do
        if B.Junk and B.Junk(e) then
            s.junk = s.junk + 1
            s.junkWorth = s.junkWorth + VendorPrice(e.id) * (e.count or 1)
        end
        if e.new then s.new = s.new + 1 end
    end
    local V = ns.Vendor
    if B.bankOpen and V and V.CollectBank then
        local list = Try(V.CollectBank, V)
        s.bank = type(list) == "table" and #list or 0
    end
    N.bagState = s
    return N.Speak("bags", host, N.Me(), N.Mutter(N.BagWords(s)))
end

---------------------------------------------------------------------------
-- A vendor
---------------------------------------------------------------------------
-- r = { vendor = how many they would buy, worth = copper, auction = how many the auction house pays more for,
-- gain = copper more, full = bags full, repaired = copper just paid, repair = copper still to pay }
function N.VendorWords(r)
    local money = ns.Money or tostring
    local first
    if (r.repaired or 0) > 0 then first = L["Your gear's mended: %s."]:format(money(r.repaired))
    elseif (r.repair or 0) > 0 then
        first = L["I can mend your gear for %s; a broken piece gives you none of its armour or stats."]:format(
            money(r.repair))
    end
    local line
    if r.full and (r.vendor or 0) > 0 then
        line = L["Your bags are full. I'll take %d things for %s: Smart sell, and you have room again."]:format(
            r.vendor, money(r.worth or 0))
    elseif (r.vendor or 0) > 0 then
        line = L["I'll give you %s for %d things: the junk, and what the auction house wouldn't pay more for. Smart sell, and it's done."]
            :format(money(r.worth or 0), r.vendor)
    elseif (r.auction or 0) > 0 then
        line = L["Keep the %d the auction house wants: it pays %s more than I would."]:format(r.auction,
            money(r.gain or 0))
    elseif r.full then
        line = L["Your bags are full. Sell me something before you buy."]
    else
        line = L["Nothing in your bags I'd pay well for. Have a look at my wares."]
    end
    return first and (first .. " " .. line) or line
end

function N.Vendor()
    local host = Shown("MerchantFrame")
    local V = ns.Vendor
    if not (host and V and V.Recommend) then return N.Hush("vendor") end
    local rec = Try(V.Recommend, V)
    if type(rec) ~= "table" then return N.Hush("vendor") end
    local free, total = FreeSlots()
    local r = { vendor = #(rec.vendor or {}), worth = rec.total or 0, auction = #(rec.auction or {}),
                gain = rec.gain or 0, full = total > 0 and free == 0 }
    local fixed = V.repaired
    if fixed and N.visitAt and (fixed.at or 0) >= N.visitAt then r.repaired = fixed.cost end
    if not r.repaired and ns.Yes(Try(CanMerchantRepair)) then
        local cost = Num(Try(GetRepairAllCost))
        if cost and cost > 0 then r.repair = cost end
    end
    return N.Speak("vendor", host, { unit = "npc" }, N.VendorWords(r))
end

---------------------------------------------------------------------------
-- The bank: the banker
---------------------------------------------------------------------------
-- b = { deposit = how many of yours belong in the bank, withdraw = how many it holds more of, free }
function N.BankWords(b)
    if (b.deposit or 0) > 0 then
        return L["%d of what you carry belong in here: I hold more of the same, or you marked them. Deposit puts them away."]
            :format(b.deposit)
    end
    if (b.withdraw or 0) > 0 then
        return L["I hold more of %d things you carry. Withdraw tops your bags up before you head out."]:format(b.withdraw)
    end
    if (b.free or 0) <= N.LOW then
        return L["Your bags are nearly full. Leave what you won't need on the road with me."]
    end
    return L["All safe with me, and your bags have %d slots free."]:format(b.free or 0)
end

function N.Bank()
    local host = Shown("BankFrame")
    local V = ns.Vendor
    if not (host and V and V.CollectBank) then return N.Hush("bank") end
    local deposit, withdraw = Try(V.CollectBank, V), Try(V.CollectWithdraw, V)
    local b = { deposit = type(deposit) == "table" and #deposit or 0,
                withdraw = type(withdraw) == "table" and #withdraw or 0, free = (FreeSlots()) }
    return N.Speak("bank", host, { unit = "npc" }, N.BankWords(b))
end

---------------------------------------------------------------------------
-- The mailbox: the Postmaster
---------------------------------------------------------------------------
N.MAIL_ICON = "Interface\\Icons\\INV_Letter_15"
-- m = { letters, money, items, cod = letters that want coin on delivery, full, takeAll = the button is there }
function N.MailWords(m)
    if (m.letters or 0) == 0 then return L["Nothing for you today. I checked twice."] end
    local parts = {}
    if (m.money or 0) > 0 then parts[#parts + 1] = (ns.Money or tostring)(m.money) end
    if m.items == 1 then parts[#parts + 1] = L["1 item"]
    elseif (m.items or 0) > 1 then parts[#parts + 1] = L["%d items"]:format(m.items) end
    local out
    if #parts == 0 then
        out = L["Letters for you: %d, nothing attached. Read them when you like."]:format(m.letters)
    else
        out = L["Letters for you: %d. In them: %s."]:format(m.letters, table.concat(parts, L[" and "]))
        if m.takeAll then out = out .. " " .. L["Take everything empties them in one go."] end
    end
    if (m.cod or 0) > 0 then out = out .. " " .. L["Coin on delivery: %d. Those you open and pay for yourself."]:format(m.cod) end
    if m.full and (m.items or 0) > 0 then out = out .. " " .. L["Your bags are full: the items wait in their letters."] end
    return out
end

function N.Mail()
    local host = Shown("MailFrame") or Shown("InboxFrame")
    local MB = ns.Mail
    if not (host and MB and MB.Count and MB.Letter) then return N.Hush("mail") end
    local shown, total = MB.Count()
    local m = { letters = total or 0, money = 0, items = 0, cod = 0, takeAll = ns.db.mailTakeAll and true or false }
    for i = 1, shown or 0 do
        local l = MB.Letter(i)
        if l then
            if l.cod > 0 then m.cod = m.cod + 1
            else
                m.money = m.money + l.money
                m.items = m.items + #l.items
            end
        end
    end
    m.full = (FreeSlots()) == 0
    return N.Speak("mail", host, { name = L["Postmaster"], icon = N.MAIL_ICON }, N.MailWords(m))
end

---------------------------------------------------------------------------
-- The flight master's map: the flight master
---------------------------------------------------------------------------
-- f = { place = the place pointed at, eta = seconds, guess = from the map, not flown }
function N.FlightWords(f)
    if not f.place then return L["Where to? Point at a place and I'll tell you how long the ride takes."] end
    local F = ns.Flights
    local clock = F and F.Clock or tostring
    if f.eta and f.guess then
        return L["%s: about %s by the map. You haven't flown that one yet."]:format(f.place, clock(f.eta))
    elseif f.eta then
        return L["%s: about %s, going by your last flight there."]:format(f.place, clock(f.eta))
    end
    return L["%s: I can't say how long yet. Fly it once and I'll know."]:format(f.place)
end

function N.Flight()
    local host = Shown("TaxiFrame") or Shown("FlightMapFrame")
    local F = ns.Flights
    if not (host and F) then return N.Hush("flight") end
    local f = {}
    local h = F.hover
    if h and h.name then
        f.place = h.name
        local rec = F.Route and F.here and ns.db.flightTimes and ns.db.flightTimes[F.Route(F.here, h.name)]
        if rec and rec.t then
            f.eta = rec.t
        else
            local pace = h.dist and F.map and ns.db.flightPace and ns.db.flightPace[F.map]
            if pace then f.eta, f.guess = h.dist * pace.s, true end
        end
    end
    return N.Speak("flight", host, { unit = "npc" }, N.FlightWords(f))
end

---------------------------------------------------------------------------
-- Fishing: you, at the water
---------------------------------------------------------------------------
-- w = { caught, away, bait = seconds left or nil, unknown = fish here not landed yet, known = landed here,
-- whole = every fish of this water is known, capped = your skill is at its cap }
N.BAIT_LOW = 60
function N.FishWords(w)
    if (w.away or 0) >= 2 and w.away >= (w.caught or 0) then
        return L["%d got away. This water wants more skill than I have: bait helps, and so does a better pole."]:format(w.away)
    end
    if not w.bait and (w.away or 0) > 0 and not w.capped then
        return L["No bait on the hook. It adds to my skill, so fewer get away."]
    end
    if w.bait and w.bait < N.BAIT_LOW then
        return L["Bait's nearly spent. Another on the hook keeps my skill up."]
    end
    if (w.unknown or 0) > 0 then
        return L["Fish here I haven't landed yet: %d. Keep casting."]:format(w.unknown)
    end
    if w.whole and (w.known or 0) > 0 then
        return L["I've landed every fish this water has. Somewhere new, then."]
    end
    return nil
end

function N.Fishing()
    local host = rawget(_G, "ControllerCamHUD_FishPanel")
    local J, F = ns.FishLog, ns.Fishing
    if not (host and J and F and ns.ShownPlain(host)) then return N.Hush("fish") end
    local C = ns.Commentary                                 -- (a remark has your card for a moment)
    local remark = C and C.Current()
    if remark then return N.Speak("fish", host, C.Speaker(remark), C.Words(remark)) end
    local w = { caught = J.session and J.session.caught or 0, away = J.session and J.session.away or 0,
                bait = F.BaitLeft and Num(Try(F.BaitLeft)) or nil, unknown = 0, known = 0 }
    local waters, whole = Try(J.Waters)
    w.whole = whole and true or false
    for _, s in ipairs(waters or {}) do
        if s.id then
            if s.known then w.known = w.known + 1 else w.unknown = w.unknown + 1 end
        end
    end
    local rank, _, cap = Try(F.Skill)
    rank, cap = Num(rank), Num(cap)
    w.capped = rank and cap and rank >= cap or false
    return N.Speak("fish", host, N.Me(), N.FishWords(w))
end

-- The fish journal: you, leafing through it
function N.JournalWords(kinds, whole)
    if (kinds or 0) == 0 then return L["Nothing landed yet. The first fish of every water goes in here."] end
    if whole then
        return L["Kinds landed: %d. Every water hides a few more: the fishing panel shows a ? for each I haven't caught there."]
            :format(kinds)
    end
    return L["Kinds landed: %d. Every water has fish of its own."]:format(kinds)
end

function N.Journal()
    local host = rawget(_G, "ControllerCamHUD_FishJournalWindow")
    local W = ns.FishJournal
    if not (host and W and W.Fish and ns.ShownPlain(host)) then return N.Hush("journal") end
    local list = Try(W.Fish)
    local _, whole = Try(ns.FishLog and ns.FishLog.Waters)
    return N.Speak("journal", host, N.Me(), N.JournalWords(type(list) == "table" and #list or 0, whole))
end

---------------------------------------------------------------------------
-- By the camp fire: you, at rest (Campfire.lua shows it in its scene)
---------------------------------------------------------------------------
function N.CampWords()
    local level, max = Num(Try(UnitLevel, "player")), Num(Try(GetMaxPlayerLevel))
    if level and max and level >= max then return nil end
    local rested = Num(Try(GetXPExhaustion))
    if rested and rested > 0 then
        return L["Rested by the fire: the next %d experience from kills comes double."]:format(math.floor(rested))
    end
    return L["No rest saved up. A night at an inn or in a city, and kills give double experience for a while."]
end

---------------------------------------------------------------------------
-- The Mentor's portrait: his profession's own icon
---------------------------------------------------------------------------
function N.ProfessionIcon(kind)
    local P = ns.Professions
    for _, p in ipairs(P and P.LIST or {}) do
        if p[1] == kind then
            local get = (C_Spell and C_Spell.GetSpellTexture) or GetSpellTexture
            return Str(Try(get, p[2])) or Num(Try(get, p[2]))
        end
    end
    return nil
end

---------------------------------------------------------------------------
-- When to speak
---------------------------------------------------------------------------
-- Every window's line again (the switch changed, a window opened)
function N.Refresh()
    for _, fn in ipairs({ N.Bags, N.Vendor, N.Bank, N.Mail, N.Flight, N.Fishing, N.Journal }) do
        local ok, err = pcall(fn)
        if not ok then ns.Error(err) end
    end
    local AP, LV = ns.AuctionPanel, ns.Levelling
    if AP and AP.Refresh then pcall(AP.Portrait); pcall(AP.Refresh, AP) end
    if LV and LV.Refresh then pcall(LV.Refresh, LV) end
end

local watch = CreateFrame("Frame")
N.watch = watch
local function Later(id, fn) N.Soon(id, fn) end
watch:SetScript("OnEvent", ns.Protect(function(_, event)
    if event == "MERCHANT_SHOW" then
        N.visitAt = GetTime() - 1                       -- (the repair made as the window opened counts)
        Later("vendor", N.Vendor)
    elseif event == "MERCHANT_CLOSED" then N.Hush("vendor")
    elseif event == "BANKFRAME_OPENED" then Later("bank", N.Bank)
    elseif event == "BANKFRAME_CLOSED" then N.Hush("bank")
    elseif event == "MAIL_SHOW" or event == "MAIL_INBOX_UPDATE" then Later("mail", N.Mail)
    elseif event == "MAIL_CLOSED" then N.Hush("mail")
    elseif event == "TAXIMAP_OPENED" then
        N.flightSince = 0
        watch:SetScript("OnUpdate", N.FlightTick)
        Later("flight", N.Flight)
    elseif event == "TAXIMAP_CLOSED" then
        watch:SetScript("OnUpdate", nil)
        N.Hush("flight")
    elseif event == "BAG_UPDATE_DELAYED" or event == "MERCHANT_UPDATE" then
        if N.cards.bags and N.cards.bags:IsShown() and N.GameBags() then Later("bags", N.Bags) end
        if N.cards.vendor and N.cards.vendor:IsShown() then Later("vendor", N.Vendor) end
        if N.cards.bank and N.cards.bank:IsShown() then Later("bank", N.Bank) end
        if N.cards.mail and N.cards.mail:IsShown() then Later("mail", N.Mail) end
    end
end))
-- the place pointed at on the flight master's map changes: his answer too (Flights.lua remembers the place)
N.FlightTick = ns.Protect(function(_, dt)
    N.flightSince = (N.flightSince or 0) + (dt or 0)
    if N.flightSince < 0.2 then return end
    N.flightSince = 0
    local F = ns.Flights
    local place = F and F.hover and F.hover.name
    if place ~= N.flightPlace then
        N.flightPlace = place
        N.Flight()
    end
end)

-- The game says nothing when its bags open or close: looked at a few times a second
local bagWatch, bagSince, bagOpen = CreateFrame("Frame"), 0, nil
bagWatch:SetScript("OnUpdate", ns.Protect(function(_, dt)
    if not N.running then return end
    bagSince = bagSince + (dt or 0)
    if bagSince < 0.3 then return end
    bagSince = 0
    local B, V = ns.Bags, ns.Vendor
    local game = (not (B and B.open)) and N.GameBags() or nil
    local now = game and not (V and (V.bankOpen or V.merchantOpen)) and game or false
    if now ~= bagOpen then
        bagOpen = now
        if now then Later("bags", N.Bags)
        elseif not (B and B.open) then N.Hush("bags") end
    end
end))

local EVENTS = { "MERCHANT_SHOW", "MERCHANT_CLOSED", "MERCHANT_UPDATE", "BANKFRAME_OPENED", "BANKFRAME_CLOSED",
                 "MAIL_SHOW", "MAIL_INBOX_UPDATE", "MAIL_CLOSED", "TAXIMAP_OPENED", "TAXIMAP_CLOSED",
                 "BAG_UPDATE_DELAYED" }
function N:Apply(run)
    local want = run and ns.db.narrative ~= false and true or false
    local was = self.running
    self.running = want
    if want and not self.registered then
        self.registered = true
        for _, e in ipairs(EVENTS) do pcall(watch.RegisterEvent, watch, e) end
    elseif not want and self.registered then
        self.registered = false
        watch:UnregisterAllEvents()
        watch:SetScript("OnUpdate", nil)
    end
    if not want then for id in pairs(self.cards) do N.Hush(id) end end
    if was ~= nil and was ~= want then N.Refresh() end    -- (the open windows turn to characters, or plain)
end

function N.Describe()
    local out = {}
    for id, card in pairs(N.cards) do
        if card:IsShown() then
            out[#out + 1] = ("%s (%s, %s): %s"):format(id, tostring(card.portrait.from), tostring(card.at),
                tostring(card.said))
        end
    end
    table.sort(out)
    local more = ns.Commentary and ("; " .. ns.Commentary.Describe()) or ""
    return ("on %s, race %s; %s"):format(tostring(N.On()), tostring(N.Race()),
        #out > 0 and table.concat(out, "; ") or "nobody speaking") .. more
end

ns.RegisterModule("narrative", N)
