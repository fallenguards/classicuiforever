local _, ns = ...

-- Appear Offline in our social window's status menu (the game's old menu lists Available, Away and Busy only). Every
-- choice there sets the whole presence, as the game's new window does: the old menu's own choices never clear Appear
-- Offline, and it knows only the status it last set itself.

local TAG = "MENU_FRIENDS_STATUS"
local ICON = "\124T%s.tga:16:16:0:0\124t"

local function Wanted() return ns.panels ~= nil and ns.panels.Dressing ~= nil and ns.panels.Dressing("panelSocial") end

local function Label(status)
    if status == FRIENDS_TEXTURE_OFFLINE then
        return _G.SOCIAL_UI_PRESENCE_TYPE_LABEL_APPEAR_OFFLINE or "Appear Offline"
    elseif status == FRIENDS_TEXTURE_AFK then
        return FRIENDS_LIST_AWAY
    elseif status == FRIENDS_TEXTURE_DND then
        return FRIENDS_LIST_BUSY
    end
    return FRIENDS_LIST_AVAILABLE
end

-- The status now, as one of the menu's icons (its entries' data); Appear Offline over Away and Busy, as the game reads it.
local function Presence()
    if not BNGetInfo then return FRIENDS_TEXTURE_ONLINE end
    local _, _, _, _, afk, busy, _, hidden = BNGetInfo()
    if ns.Safe(hidden, false) then return FRIENDS_TEXTURE_OFFLINE end
    if ns.Safe(afk, false) then return FRIENDS_TEXTURE_AFK end
    if ns.Safe(busy, false) then return FRIENDS_TEXTURE_DND end
    return FRIENDS_TEXTURE_ONLINE
end

-- After the game's own choice (or alone, for Appear Offline): the rest of the presence that choice means.
local function SetPresence(status)
    local bn = C_BattleNet
    if not (bn and bn.SetAppearOffline) then return end
    if status == FRIENDS_TEXTURE_OFFLINE then
        bn.SetAppearOffline(true)
        return
    end
    bn.SetAppearOffline(false)
    if status == FRIENDS_TEXTURE_ONLINE then
        bn.SetAFK(false)
        bn.SetDND(false)
    elseif status == FRIENDS_TEXTURE_AFK then
        bn.SetAFK(true)
    elseif status == FRIENDS_TEXTURE_DND then
        bn.SetDND(true)
    end
end

local function IsSelected(status) return Presence() == status end

-- Each time the game builds the menu (every open, and on a status change for the button's icon).
local function AddOffline(_, root)
    if not Wanted() then return end
    for _, entry in root:EnumerateElementDescriptions() do
        -- A client whose menu lists it already keeps its own.
        if entry:GetData() == FRIENDS_TEXTURE_OFFLINE then return end
    end
    for _, entry in root:EnumerateElementDescriptions() do
        entry:SetIsSelected(IsSelected)
        entry:HookResponder(SetPresence)
    end
    local offline = root:CreateButton(ICON:format(FRIENDS_TEXTURE_OFFLINE) .. " " .. Label(FRIENDS_TEXTURE_OFFLINE), nop,
        FRIENDS_TEXTURE_OFFLINE)
    offline:SetIsSelected(IsSelected)
    offline:SetResponder(SetPresence)
end

-- The button's tooltip names the status the game last set itself: this one reads it.
local function StatusTip(dropdown)
    if not (Wanted() and GameTooltip:IsOwned(dropdown) and FRIENDS_LIST_STATUS_TOOLTIP) then return end
    GameTooltip:SetText(FRIENDS_LIST_STATUS_TOOLTIP:format(Label(Presence())))
    GameTooltip:Show()
end

if FRIENDS_TEXTURE_OFFLINE and Menu and Menu.ModifyMenu then
    Menu.ModifyMenu(TAG, AddOffline)
    ns.HookScriptOnce(_G.FriendsFrameStatusDropdown, "OnEnter", StatusTip)
end
