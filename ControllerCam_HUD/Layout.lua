-- ControllerCam HUD: screen layout. Moves the chat window to the top left so the bottom left is free for the
-- player bar. The move only lasts while the HUD runs: the position is never saved, and the game's own
-- layout (Edit Mode) puts the window back as soon as the HUD stops, or on the next login without the addon.

local ADDON, ns = ...

local Layout = { active = false }
ns.Layout = Layout

Layout.CHAT_POINT = { "TOPLEFT", 36, -48 }

local function Chat() return _G.ChatFrame1 end

-- The plain widget methods: an Edit Mode frame's own SetPoint also marks the layout as changed.
local function ClearPoints(frame) (frame.ClearAllPointsBase or frame.ClearAllPoints)(frame) end
local function SetPoint(frame, ...) (frame.SetPointBase or frame.SetPoint)(frame, ...) end

function Layout:MoveChat()
    local chat = Chat()
    if not chat then return end
    if not self.saved then
        self.saved = {}
        for i = 1, (chat.GetNumPoints and chat:GetNumPoints() or 0) do
            self.saved[i] = { chat:GetPoint(i) }
        end
    end
    local p = self.CHAT_POINT
    ClearPoints(chat)
    SetPoint(chat, p[1], UIParent, p[1], p[2], p[3])
end

function Layout:RestoreChat()
    local chat = Chat()
    if not chat then return end
    if chat.ApplySystemAnchor then
        local ok = pcall(chat.ApplySystemAnchor, chat)
        if ok then self.saved = nil; return end
    end
    if self.saved and #self.saved > 0 then
        ClearPoints(chat)
        for _, pt in ipairs(self.saved) do SetPoint(chat, unpack(pt)) end
    end
    self.saved = nil
end

function Layout:Apply(run)
    local want = run and ns.db.chat and true or false
    local chat = Chat()
    if not chat then return end
    if want then
        -- the game re-applies its layout now and then (login, layout switch): move the window again after it
        if not self.hooked and chat.ApplySystemAnchor then
            self.hooked = true
            hooksecurefunc(chat, "ApplySystemAnchor", function()
                if Layout.active and not Layout.restoring then Layout:MoveChat() end
            end)
        end
        self.active = true
        self:MoveChat()
    elseif self.active then
        self.active = false
        self.restoring = true
        self:RestoreChat()
        self.restoring = false
    end
end

ns.RegisterModule("layout", Layout)
