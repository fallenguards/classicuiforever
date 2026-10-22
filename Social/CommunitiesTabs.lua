local _, ns = ...
local S = ns.social

-- The Communities window wears the social window's foot row in both its modes: Friends, Who, Guild and Raid take the
-- player back to that page, Communities stands picked. Friends and Raid press the game's own tab through a pad, so the
-- Raid page keeps its protected buttons. Its small mode takes the social window's size.

local ORDER = { "friends", "who", "guild", "communities", "raid" }
-- Era's social window (UI/WindowList.lua), the size every page of it has; the client minimizes to 322 x 406.
local SOCIAL_W, SOCIAL_H, CLIENT_W, CLIENT_H = 338, 424, 322, 406
-- The community drop-down past the ring in the small mode (the stream one follows it), both narrowed so the headset
-- button keeps clear; the client has them at 5, -28 and 145 and 115 wide. The chat bar 4 off its text, not 13: the
-- old track art is wider than the game's thin bar and ran into the window's right edge.
local LIST_X, LIST_Y, DROP_W, STREAM_W = 58, -28, 100, 115
local BAR_X, CLIENT_BAR_X = 12, 13
local listWidth
local tabs = {}
local order = {}
local host, laid, sized

local function Minimized() return COMMUNITIES_FRAME_DISPLAY_MODES and COMMUNITIES_FRAME_DISPLAY_MODES.MINIMIZED end
local function Dressed() return ns.panels ~= nil and ns.panels.Dressing("panelCommunities") end
local function Small()
    return host ~= nil and host:IsShown() and host.GetDisplayMode ~= nil and host:GetDisplayMode() == Minimized()
end
local function Up() return host ~= nil and host:IsShown() and Dressed() end

-- The Communities window away and the social window up; a pad's press then picks the game's page.
local function OpenSocial()
    if host then ns.HidePanel(host) end
    if FriendsFrame then ns.ShowPanel(FriendsFrame) end
end

local function ToWho()
    OpenSocial()
    if ns.OpenWhoList then ns.OpenWhoList() end
end

local function ToGuild()
    OpenSocial()
    if ns.OpenGuildRoster then ns.OpenGuildRoster() end
end

local function Wanted(key)
    if key == "who" then return ns.db.whoList ~= false and not S.WhoTabHidden() end
    if key == "guild" then return ns.db.guildRoster ~= false end
    return true
end

local function Size(w, h)
    if math.abs(host:GetWidth() - w) > 0.5 or math.abs(host:GetHeight() - h) > 0.5 then host:SetSize(w, h) end
end

local function Width(frame, w)
    if frame and math.abs(frame:GetWidth() - w) > 0.5 then frame:SetWidth(w) end
end

-- The small mode as a social page: the game's portrait pieces back inside our ring, the community drop-down past it,
-- the chat's scroll bar in from the edge.
local function SmallLook(on)
    local overlay, list, stream = host.PortraitOverlay, host.CommunitiesListDropdown, host.StreamDropdown
    if overlay then ns.SetShownIf(overlay, on) end
    local chat = host.Chat
    local bar, text = chat and chat.ScrollBar, chat and chat.MessageFrame
    if bar and text then
        local x = on and BAR_X or CLIENT_BAR_X
        ns.SetTwoPointsIf(bar, "TOPLEFT", text, "TOPRIGHT", x, 0, "BOTTOMLEFT", text, "BOTTOMRIGHT", x, -4)
    end
    if not list then return end
    listWidth = listWidth or list:GetWidth()
    if on then
        ns.SetPointIf(list, "TOPLEFT", host, "TOPLEFT", LIST_X, LIST_Y)
        Width(list, DROP_W)
        Width(stream, DROP_W)
    else
        ns.SetPointIf(list, "TOPLEFT", host, "TOPLEFT", 5, -28)
        if listWidth then Width(list, listWidth) end
        Width(stream, STREAM_W)
    end
end

-- The small window at the social window's size while ours; shown tabs laid again only as the set or the width changes.
local function Sync()
    local up = Up()
    if up and Small() then
        Size(SOCIAL_W, SOCIAL_H)
        SmallLook(true)
        sized = true
    elseif sized and Small() then
        Size(CLIENT_W, CLIENT_H)
        SmallLook(false)
        sized = nil
    end
    wipe(order)
    local sig = up and tostring(host:GetWidth()) or "off"
    for _, key in ipairs(ORDER) do
        local tab = tabs[key]
        if tab then
            local shown = up and Wanted(key)
            ns.SetShownIf(tab, shown)
            if shown then
                order[#order + 1] = tab
                sig = sig .. key
            end
        end
    end
    if up and sig ~= laid then
        laid = sig
        S.LayTabRow(host, order)
    end
end

local function NewTab(key, name, id, text, onClick)
    local tab = S.NewTab(host, name, id, text)
    -- The row's spot is its own: the window's tab lift (a re-dress on each open) rode the tabs 10 up.
    ns.SetTabLift(tab, 0)
    if PanelTemplates_DeselectTab then PanelTemplates_DeselectTab(tab) end
    if onClick then tab:SetScript("OnClick", onClick) end
    tabs[key] = tab
    return tab
end

local function PadTo(tab, client)
    ns.MapPad(tab, "HIGH", nil, function() return S.StandInMacro(client) end, Up, nil, OpenSocial)
end

local function Build(frame)
    if host then return end
    host = frame
    PadTo(NewTab("friends", "ClassicUIForeverCommunitiesFriendsTab", 94, FRIENDS or "Friends"), _G.FriendsFrameTab1)
    NewTab("who", "ClassicUIForeverCommunitiesWhoTab", 95, WHO or "Who", ToWho)
    NewTab("guild", "ClassicUIForeverCommunitiesGuildTab", 96, GUILD or "Guild", ToGuild)
    local here = NewTab("communities", "ClassicUIForeverCommunitiesPageTab", 97, COMMUNITIES or "Communities")
    if PanelTemplates_SelectTab then PanelTemplates_SelectTab(here) end
    local raid = S.ClientTab(_G.FRIEND_TAB_RAID)
    if raid then PadTo(NewTab("raid", "ClassicUIForeverCommunitiesRaidTab", 98, RAID or "Raid"), raid) end
    ns.Sched.Attach(host, { name = "communities.foot", every = 0.25, fn = Sync })
    -- The client sizes the window as the mode turns: ours before the draw.
    ns.Sched.OnMove(host, Sync)
end

-- From the window's dressing pass (Windows/Panels.lua), once the Communities addon has loaded.
function ns.CommunitiesFootTabs(frame)
    if not (frame and FriendsFrame and _G.FriendsFrameTab1) then return end
    Build(frame)
    Sync()
end
