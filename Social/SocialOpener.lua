local _, ns = ...

-- The social window's opener: a secure button the social keys, the friends button by chat and the guild button press.
-- With the game's new social window on (a server switch) the client's friends toggle opens that one, so while a list of
-- ours stands in the old window (who list, guild roster) the keys open ours.

local S = ns.social

local OPENER = "ForeverClassicUISocialOpen"
local SOCIAL_BINDINGS = { "TOGGLESOCIAL", "TOGGLEFRIENDSTAB" }
local KEY_EVENTS = { "UPDATE_BINDINGS", "SOCIAL_UI_SYSTEM_STATUS_UPDATED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD" }
-- The toast's click runs the client's friends toggle: a counted panel that opens in combat. With the new window on that
-- toggle opens the new one, so ours opens from Lua (raw in a fight, Escape armed by the opener's click).
local TOAST_OPEN = "/click QuickJoinToastButton"

local users = {}   -- module key -> true while its list is on
local opener

function S.OpenerMacro() return ns.SocialUIOn() and "" or TOAST_OPEN end

local escArmed = setmetatable({}, { __mode = "k" })
function S.ArmEscape(button, on)
    if not button or (escArmed[button] or false) == on or not ns.EscArmOnClick then return end
    escArmed[button] = on
    if on then
        ns.EscArmOnClick(button, "social")
    elseif SecureHandlerUnwrapScript then
        SecureHandlerUnwrapScript(button, "OnClick")
    end
end

function S.SocialShown() return FriendsFrame and FriendsFrame:IsShown() and true or false end

function S.ToggleSocial()
    if not FriendsFrame then return end
    if S.SocialShown() then
        local guild = ns.guild and ns.guild.panel
        if guild and guild:IsShown() then guild:Hide() end
        ns.HidePanel(FriendsFrame)
    else
        ns.ShowPanel(FriendsFrame)
    end
    ns.RefreshMicroButtons()
end

local function Wanted() return next(users) ~= nil end

local function UpdateKeys()
    if not opener or InCombatLockdown() then return end
    ClearOverrideBindings(opener)
    local newUI = ns.SocialUIOn()
    ns.SetAttributeIf(opener, "macrotext", S.OpenerMacro())
    S.ArmEscape(opener, newUI)
    if not (newUI and Wanted()) then return end
    for _, binding in ipairs(SOCIAL_BINDINGS) do
        local key, second = GetBindingKey(binding)
        for _, k in ipairs({ key, second }) do
            if k then SetOverrideBindingClick(opener, true, k, ns.KeyProxy(OPENER), "LeftButton") end
        end
    end
end

-- The friends button by chat where its own click opens the new window, or the roster settles the page after it; a
-- group toast on it keeps its own click (the quick join list).
local function ToastPad(toast)
    return Wanted() and (ns.SocialUIOn() or users.guildRoster) and not toast.displayedToast
end

local function Build()
    if opener or InCombatLockdown() then return end
    local toast = _G["QuickJoinToastButton"]
    if not toast then return end
    opener = CreateFrame("Button", OPENER, UIParent, "SecureActionButtonTemplate")
    -- Sized and placed off screen: a button with neither is never clicked.
    opener:SetSize(1, 1)
    opener:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -500, 500)
    opener:EnableMouse(false)
    opener:RegisterForClicks("AnyUp", "AnyDown")
    opener:SetAttribute("useOnKeyDown", false)
    opener:SetAttribute("type", "macro")
    opener:SetAttribute("macrotext", S.OpenerMacro())
    opener:SetScript("PreClick", function(self, _, down)
        if down then return end
        self.was = S.SocialShown()
    end)
    -- A press that changed nothing (window up: the toast turns a page; toast waiting: it does nothing; the new window
    -- on: an empty macro) is toggled from here.
    opener:HookScript("OnClick", function(self, _, down)
        if down or not Wanted() then return end
        if self.was == S.SocialShown() then S.ToggleSocial() end
        self.was = nil
        ns.RefreshMicroButtons()
    end)
    ns.RegisterEvents(opener, KEY_EVENTS)
    opener:SetScript("OnEvent", UpdateKeys)
    ns.MapPad(toast, nil, nil, opener, function() return ToastPad(toast) end)
    ns.HookMethod(toast, "ShowToast", ns.PlacePads)
    ns.HookMethod(toast, "ToastToFriendFinished", ns.PlacePads)
end

-- A module's list in the window (key: the module) takes the opener out of a fight or lets it go; returns the opener.
function S.UseOpener(key, on)
    users[key] = on or nil
    if on then Build() end
    UpdateKeys()
    return opener
end
