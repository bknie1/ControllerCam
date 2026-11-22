-- ControllerCam HUD: chat and map.
--   * Chat: the text of every chat window fades out after a few seconds without new messages, so the screen
--     stays clear; new messages show again. Uses the chat windows' own fading, put back as it was when off.
--   * Map: your coordinates under the world map.

local ADDON, ns = ...
local L = ns.L

local W = { chatActive = false, chatSaved = {}, mapActive = false }
ns.World = W

ns.RegisterSetting({
    key = "chatFade", kind = "boolean", default = true, command = "chatfade", section = "General",
    label = "Chat fades when quiet", tip = "chat text fades out after a few seconds without new messages",
})
ns.RegisterSetting({
    key = "chatTime", kind = "number", default = 45, min = 5, max = 300, command = "chattime", section = "General",
    label = "Seconds before chat fades", tip = "how long chat text stays before it fades",
})
ns.RegisterSetting({
    key = "mapCoords", kind = "boolean", default = true, command = "mapcoords", section = "General",
    label = "Coordinates on the map", tip = "your coordinates under the world map",
})

local function ChatFrames()
    local list = {}
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local f = _G["ChatFrame" .. i]
        if type(f) == "table" and f.SetFading and f.SetTimeVisible then list[#list + 1] = f end
    end
    return list
end
W.ChatFrames = ChatFrames

function W:ApplyChat(want)
    if want then
        for _, f in ipairs(ChatFrames()) do
            if not self.chatSaved[f] then
                self.chatSaved[f] = { fading = f.GetFading and f:GetFading(), time = f.GetTimeVisible and f:GetTimeVisible() }
            end
            f:SetFading(true)
            f:SetTimeVisible(ns.db.chatTime)
        end
        self.chatActive = true
    elseif self.chatActive then
        for f, was in pairs(self.chatSaved) do
            if was.fading ~= nil then f:SetFading(was.fading) end
            if was.time ~= nil then f:SetTimeVisible(was.time) end
        end
        self.chatSaved, self.chatActive = {}, false
    end
end

---------------------------------------------------------------------------
-- Map coordinates: a child of the map, so it only works while the map is open
---------------------------------------------------------------------------
local coords
local function PlayerCoords()
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return nil end
    local map = C_Map.GetBestMapForUnit("player")
    if not map then return nil end
    local pos = C_Map.GetPlayerMapPosition(map, "player")       -- nil in instances that hide it
    if not pos then return nil end
    local x, y = pos:GetXY()
    if ns.IsSecret(x) or ns.IsSecret(y) or not x or (x == 0 and y == 0) then return nil end
    return x * 100, y * 100
end

local since = 0
local OnUpdate = ns.Protect(function(self, dt)
    since = since + dt
    if since < 0.2 then return end
    since = 0
    local x, y = PlayerCoords()
    if x then self.text:SetText(("%.1f, %.1f"):format(x, y)) else self.text:SetText("") end
end)

function W:ApplyMap(want)
    local map = _G.WorldMapFrame
    if want and type(map) == "table" and not coords then
        coords = CreateFrame("Frame", "ControllerCamHUD_MapCoords", map)
        coords:SetSize(160, 20)
        coords:SetPoint("BOTTOM", map, "BOTTOM", 0, 6)
        coords:SetFrameStrata("HIGH")
        coords.text = ns.FontString(coords, 13, "CENTER")
        coords.text:SetPoint("CENTER", coords, "CENTER", 0, 0)
        W.coords = coords
    end
    if not coords then self.mapActive = false; return end
    if want then
        coords:SetScript("OnUpdate", OnUpdate)
        since = 1
        coords:Show()
    else
        coords:SetScript("OnUpdate", nil)
        coords:Hide()
    end
    self.mapActive = want and true or false
end

function W:Apply(run)
    self:ApplyChat(run and ns.db.chatFade and true or false)
    self:ApplyMap(run and ns.db.mapCoords and true or false)
end

ns.RegisterCheck(function(row, run, db)
    local wantChat = (run and db.chatFade) and true or false
    row(wantChat and "chat fades when quiet" or "chat fading is the game's own", W.chatActive == wantChat)
    if _G.WorldMapFrame then
        local wantMap = (run and db.mapCoords) and true or false
        row(wantMap and "the map shows your coordinates" or "the map is left alone", W.mapActive == wantMap)
    end
end)

ns.RegisterModule("world", W)
