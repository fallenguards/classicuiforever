local _, ns = ...

-- Shared by the guild roster and who list. Helpers only: each module owns its
-- frames, hooks and settle frame, and calls these at its own build points.

local S = {}
ns.social = S

local ROW_H = 16
-- A row's text ends this short of its column, so a long one cuts with "..." instead of meeting the next.
local COLUMN_TEXT_GAP = 6

-- The client's panels inside the social window, faded under our lists.
local CLIENT_PANELS = { "FriendsListFrame", "IgnoreListFrame", "WhoFrame", "RaidFrame", "QuickJoinFrame", "FriendsFrameBroadcastInput" }

-- The old gold list bar: raw path (the bundled key would swap to bronze), sheet tail cut off.
local GOLD_SEL = { set = "raw", layer = "BACKGROUND", fill = true, blend = "ADD", vertex = { 1, 0.82, 0, 1 },
    coords = { 0, 0.97, 0, 1 }, show = false }
local GOLD_HL = { set = "raw", layer = "HIGHLIGHT", fill = true, blend = "ADD", vertex = { 1, 0.82, 0, 1 },
    coords = { 0, 0.97, 0, 1 } }

---------------------------------------------------------------- tabs

-- The game's new social window (beta 70291, a server switch): the game's friends toggle opens it, and the old window
-- left to us hides its own Friends and Raid tabs and lists no Recent Allies.
function ns.SocialUIOn()
    local api = _G.C_SocialUI
    return api ~= nil and api.IsSystemEnabled ~= nil and api.IsSystemEnabled() == true and _G.SocialUIFrame ~= nil
end

local friendsTab, raidTab
local SyncFriendsTab, NewSocialUI, StandInPad

-- The client's own tabs along the window's foot, a new list each call.
function S.FriendsFrameTabs()
    local tabs = {}
    for i = 1, 8 do
        local frame = _G["FriendsFrameTab" .. i]
        if frame then tabs[#tabs + 1] = frame end
    end
    return tabs
end

-- Our tab up (every client tab down) or down.
function S.SelectFriendsTab(tab, on)
    if on then
        if PanelTemplates_SelectTab then PanelTemplates_SelectTab(tab) end
        for _, other in ipairs(S.FriendsFrameTabs()) do
            if PanelTemplates_DeselectTab then PanelTemplates_DeselectTab(other) end
        end
    else
        if PanelTemplates_DeselectTab then PanelTemplates_DeselectTab(tab) end
    end
    ns.FitBottomTab(tab)
    if tab ~= friendsTab then SyncFriendsTab() end
end

function S.NewTab(host, name, id, text)
    local tab = ns.NewFrame("Button", name, host, "PanelTabButtonTemplate")
    tab:SetID(id)
    tab:SetText(text)
    ns.SkinBottomTab(tab)
    return tab
end

-- A module's hooks on the social window, in chain order: client tab
-- clicks, ShowSubFrame (who only), Update, OnShow, OnHide.
function S.HookFriendsFrame(host, h)
    for _, other in ipairs(S.FriendsFrameTabs()) do
        other:HookScript("OnClick", h.tabClick)
    end
    if h.showSubFrame and type(FriendsFrame_ShowSubFrame) == "function" then
        hooksecurefunc("FriendsFrame_ShowSubFrame", h.showSubFrame)
    end
    if type(FriendsFrame_Update) == "function" then
        hooksecurefunc("FriendsFrame_Update", h.update)
    end
    host:HookScript("OnShow", h.onShow)
    host:HookScript("OnHide", h.onHide)
end

-- 1.x tab order: Friends, Who, Guild, Communities, then the client's others.
-- Era's gap: the client's tabs past the first have no anchors of their own, so a measured gap read its layout's state.
local TAB_GAP = -14
local SOCIAL_TAB_PAD = 38
-- Foot tab row, placed from the window's foot; its faces are Era's (Windows/Tabs.lua).
local SOCIAL_TAB_X = 5          -- first tab: its left from the window's left (+ right)
local SOCIAL_TAB_Y = 2          -- tab row: its top above the window's foot (+ up; moves the picked tab too)
-- A row too long for the window (German): the first tab starts further left, then every tab gives up the same padding.
local TIGHT_TAB_X = 0           -- first tab's left at most this far in (+ right)
local TIGHT_TAB_PAD = 24        -- least padding a tab keeps round its label
-- Retail's client has a Who tab of its own (Forever's has none): unseen and off the row while ours stands in it.
local clientWhoOff = false
local function ClientWho() return FRIEND_TAB_WHO and _G["FriendsFrameTab" .. FRIEND_TAB_WHO] or nil end
local function ClientWhoMouse()
    local tab = ClientWho()
    if tab then tab:EnableMouse(not clientWhoOff) end
end
-- True when the tab changed hands.
function S.ClientWhoTab(off)
    local tab = ClientWho()
    if not tab or off == clientWhoOff then return false end
    clientWhoOff = off
    ns.SetAlphaIf(tab, off and 0 or 1)
    ns.WhenCalm("social.clientWho", ClientWhoMouse)
    return true
end

-- Retail's Quick Join tab stood past the window's edge: off the row, its list reached from Recent Allies (below).
local quickOff = false
local function ClientQuick()
    local id = _G.FRIEND_TAB_QUICK_JOIN
    return id and _G["FriendsFrameTab" .. id] or nil
end

-- Covered while a list of ours is up.
local function OverlayUp()
    local who = ns.WhoPanel and ns.WhoPanel()
    local guild = ns.guild and ns.guild.panel
    return (who and who:IsShown()) or (guild and guild:IsShown()) or false
end

-- The client's foot tab picked is its Raid one: the old raid page stands in the window.
local function OnRaidPage()
    local id = _G.FRIEND_TAB_RAID
    return id ~= nil and FriendsFrame ~= nil and PanelTemplates_GetSelectedTab(FriendsFrame) == id
end

local function Pick(tab, on)
    if not tab or not tab:IsShown() then return end
    if on then PanelTemplates_SelectTab(tab) else PanelTemplates_DeselectTab(tab) end
    ns.FitBottomTab(tab)
end

S.OverlayUp, S.OnRaidPage = OverlayUp, OnRaidPage

SyncFriendsTab = function()
    local covered, raid = OverlayUp(), OnRaidPage()
    Pick(friendsTab, not covered and not raid)
    Pick(raidTab, not covered and raid)
    -- After the lists' own show and hide work, which puts the client's panels back.
    if S.SyncContactPages then ns.Sched.Soon("social.pages", S.SyncContactPages) end
end

local function HideOurLists()
    local who = ns.WhoPanel and ns.WhoPanel()
    if who and who:IsShown() then ns.HideWhoList() end
    local guild = ns.guild and ns.guild.panel
    if guild and guild:IsShown() then ns.HideGuildRoster() end
end

-- Without its pad (in a fight): our lists step aside; the raid page cannot be put away then.
local function FriendsTabClick()
    PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
    if OnRaidPage() and InCombatLockdown() then
        ns.SayNotInCombat()
        return
    end
    HideOurLists()
    SyncFriendsTab()
end

-- The row's first tab: the client's Friends tab, or ours while the switch hides it.
local function FirstTab()
    local client = _G.FriendsFrameTab1
    local ours = ns.SocialUIOn() and client ~= nil and not client:IsShown()
    if ours and not friendsTab and FriendsFrame then
        friendsTab = S.NewTab(FriendsFrame, "ClassicUIForeverFriendsTab", 89, FRIENDS or "Friends")
        friendsTab:SetScript("OnClick", FriendsTabClick)
        -- The row's tuned spot is the first tab's own: no window lift on top.
        ns.SetTabLift(friendsTab, 0)
        StandInPad(friendsTab, client)
    end
    if friendsTab then ns.SetShownIf(friendsTab, ours) end
    if ours then return friendsTab end
    return client
end

-- The client's Raid tab, hidden by the switch; ours in its place presses it.
local function ClientRaid()
    for _, tab in ipairs(S.FriendsFrameTabs()) do
        if tab:GetID() == _G.FRIEND_TAB_RAID then return tab end
    end
end

local function RaidTab()
    local client = ClientRaid()
    local ours = ns.SocialUIOn() and client ~= nil and not client:IsShown()
    if ours and not raidTab and FriendsFrame then
        raidTab = S.NewTab(FriendsFrame, "ClassicUIForeverRaidTab", 93, RAID or "Raid")
        PanelTemplates_DeselectTab(raidTab)
        -- Without its pad: in a fight, where the client's tab cannot be pressed for us.
        raidTab:SetScript("OnClick", function() if InCombatLockdown() then ns.SayNotInCombat() end end)
        StandInPad(raidTab, client)
    end
    if raidTab then ns.SetShownIf(raidTab, ours) end
end

-- The first tab's left and every tab's padding, so the shown tabs end inside the window.
local function RowFit(order)
    local labels, shown = 0, 0
    for _, entry in ipairs(order) do
        local text = entry:IsShown() and (entry.Text or entry:GetFontString())
        if text then
            labels = labels + math.ceil(text:GetStringWidth() or 0)
            shown = shown + 1
        end
    end
    local room = FriendsFrame:GetWidth()
    if shown == 0 or not room or room <= 0 then return SOCIAL_TAB_X, SOCIAL_TAB_PAD end
    local over = SOCIAL_TAB_X + labels + shown * SOCIAL_TAB_PAD + (shown - 1) * TAB_GAP - room
    if over <= 0 then return SOCIAL_TAB_X, SOCIAL_TAB_PAD end
    if over <= SOCIAL_TAB_X - TIGHT_TAB_X then return SOCIAL_TAB_X - over, SOCIAL_TAB_PAD end
    over = over - (SOCIAL_TAB_X - TIGHT_TAB_X)
    return TIGHT_TAB_X, math.max(TIGHT_TAB_PAD, SOCIAL_TAB_PAD - math.ceil(over / shown))
end

function S.PlaceTabs()
    local blizzard = S.FriendsFrameTabs()
    local clientWho = clientWhoOff and ClientWho() or nil
    local clientQuick = quickOff and ClientQuick() or nil
    local order = {}
    local first = FirstTab()
    if first then order[#order + 1] = first end
    local whoTab = S.whoTab
    if whoTab then order[#order + 1] = whoTab end
    local guildTab = _G["ClassicUIForeverGuildTab"]
    if guildTab then order[#order + 1] = guildTab end
    local communitiesTab = _G["ClassicUIForeverCommunitiesTab"]
    if communitiesTab then order[#order + 1] = communitiesTab end
    RaidTab()
    if raidTab then order[#order + 1] = raidTab end
    for i = 2, #blizzard do
        if blizzard[i] ~= clientWho and blizzard[i] ~= clientQuick then order[#order + 1] = blizzard[i] end
    end
    -- Five tabs where 1.x had four: 19 either side of the label, not 25.
    local x, pad = RowFit(order)
    for _, entry in ipairs(order) do
        if entry.fcuiPad ~= pad then
            entry.fcuiPad = pad
            ns.FitBottomTab(entry)
        end
    end
    local previous
    for _, entry in ipairs(order) do
        if entry:IsShown() then
            entry:ClearAllPoints()
            if previous then
                entry:SetPoint("LEFT", previous, "RIGHT", TAB_GAP, 0)
                entry:SetPoint("BOTTOM", previous, "BOTTOM", 0, 0)
            else
                entry:SetPoint("TOPLEFT", FriendsFrame, "BOTTOMLEFT", x, SOCIAL_TAB_Y)
            end
            previous = entry
        end
    end
    NewSocialUI()
end

-------------------------------------------------------- client panels

-- state = { key = hidden mark, swept = sweep mark, pending = false }, one per module.
-- On REGEN_ENABLED: sets the mouse combat refused.
function S.Settle(state)
    if not state.pending then return end
    state.pending = false
    for _, name in ipairs(CLIENT_PANELS) do
        local frame = _G[name]
        if frame and frame.EnableMouse then
            -- A panel either list holds down stays down.
            frame:EnableMouse(not (frame.fcuiGuildHidden or frame.fcuiWhoHidden))
        end
    end
end

-- One per module, made where it loads: a shared frame would reorder REGEN_ENABLED.
function S.SettleFrame(state)
    return ns.EventFrame("PLAYER_REGEN_ENABLED", function() S.Settle(state) end)
end

function S.HidePanels(state, panel)
    local key = state.key
    for _, name in ipairs(CLIENT_PANELS) do
        local frame = _G[name]
        if frame and frame:IsShown() then
            frame:SetAlpha(0)
            -- The client refuses mouse changes on its frames in a fight; alpha alone hides it until then.
            if frame.EnableMouse and not InCombatLockdown() then
                frame:EnableMouse(false)
            else
                state.pending = true
            end
            frame[key] = true
        end
    end
    local header = FriendsFrame and FriendsFrame.FriendsTabHeader
    if header then header:SetAlpha(0) end
    ns.SweepFriendsFrame(state.swept, true)
    ns.KeepFriendsSwept(panel, state.swept)
end

function S.ShowPanels(state)
    local key = state.key
    for _, name in ipairs(CLIENT_PANELS) do
        local frame = _G[name]
        if frame and frame[key] then
            frame:SetAlpha(1)
            if frame.EnableMouse and not InCombatLockdown() then
                frame:EnableMouse(true)
            else
                state.pending = true
            end
            frame[key] = nil
        end
    end
    local header = FriendsFrame and FriendsFrame.FriendsTabHeader
    if header then header:SetAlpha(1) end
    ns.SweepFriendsFrame(state.swept, false)
end

---------------------------------------------------------------- lists

-- Across the window, 5 in from either side.
local function Span(frame, host)
    frame:SetPoint("LEFT", host, "LEFT", 5, 0)
    frame:SetPoint("RIGHT", host, "RIGHT", -5, 0)
end
S.Span = Span

-- A module's hidden panel over the window's body, above the client's.
function S.NewPanel(host, name)
    local panel = ns.NewFrame("Frame", name, host)
    panel:SetPoint("TOPLEFT", host, "TOPLEFT", 8, -64)
    panel:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -8, 12)
    panel:SetFrameLevel(host:GetFrameLevel() + 6)
    panel:Hide()
    return panel
end

function S.RowCount(panel)
    if not panel then return 0 end
    return math.max(1, math.floor((panel.list:GetHeight() or 0) / ROW_H))
end

-- A list row: gold bar on the chosen row and under the mouse, one text per column (row.Name, row.Zone, ...).
local function ListRow(parent, index, columns, onClick, onDoubleClick)
    local row = ns.NewFrame("Button", nil, parent)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(index - 1) * ROW_H)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -(index - 1) * ROW_H)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.Selected = ns.DressNew(row, ns.ART.GOLD_BAR, GOLD_SEL)
    ns.DressNew(row, ns.ART.GOLD_BAR, GOLD_HL)
    for _, column in ipairs(columns) do
        local text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        text:SetPoint("LEFT", row, "LEFT", column.x, 0)
        text:SetWidth(column.w - COLUMN_TEXT_GAP)
        text:SetJustifyH(column.justify)
        text:SetWordWrap(false)
        row[column.key:gsub("^%l", string.upper)] = text
    end
    row:SetScript("OnClick", onClick)
    row:SetScript("OnDoubleClick", onDoubleClick)
    return row
end

-- The column plates on a band of the window's stone; each(header, column)
-- runs as each plate is made. Returns the header row and the plates.
function S.HeaderRow(panel, host, columns, onClick, each)
    local headerBand = ns.NewFrame("Frame", nil, panel)
    headerBand:SetHeight(22)
    headerBand:SetPoint("TOP", panel, "TOP", 0, 1)
    Span(headerBand, host)
    local stone = ns.StoneFill(headerBand, "BACKGROUND")
    stone:SetAllPoints(headerBand)

    local headerRow = ns.NewFrame("Frame", nil, panel)
    headerRow:SetHeight(20)
    headerRow:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    headerRow:SetPoint("RIGHT", panel, "RIGHT", -22, 0)
    local headers, last = {}, nil
    for _, column in ipairs(columns) do
        last = ns.ColumnHeader(headerRow, column, last, onClick)
        headers[#headers + 1] = last
        if each then each(last, column) end
    end
    return headerRow, headers
end

-- The box the list sits in, from under the plates down to bottom.
function S.ListBox(panel, host, headerRow, bottom)
    local box = ns.SectionBox(panel)
    box:SetPoint("TOP", headerRow, "BOTTOM", 0, -5)
    Span(box, host)
    box:SetPoint("BOTTOM", bottom, "TOP", 0, 1)
    return box
end

-- The who list's foot line under a list box (panel.listBox): the client's lens, its X once typed. onEnter(box) on Enter;
-- the box is panel.query.
-- The search glass: grey with no theme, the theme's metal under one.
local LENS_SHADE = { shade = 0.6, off = 0.6 }
function S.SearchLine(panel, onEnter)
    local query = ns.NewFrame("EditBox", nil, panel.listBox, "InputBoxTemplate")
    panel.query = query
    query:SetPoint("BOTTOMLEFT", panel.listBox, "BOTTOMLEFT", 6, -7)
    query:SetPoint("RIGHT", panel.listBox, "RIGHT", -2, 0)
    query:SetHeight(18)
    -- The input's thin border is bronze here; drained, it is the old silver.
    ns.DrainInput(query)
    local lens = query:CreateTexture(nil, "OVERLAY")
    lens:SetTexture("Interface/Common/UI-Searchbox-Icon")
    lens:SetSize(14, 14)
    lens:SetPoint("LEFT", query, "LEFT", 1, -2)
    ns.BronzeTint(lens, LENS_SHADE)
    query:SetTextInsets(16, 20, 0, 0)
    local clear = ns.SearchClear(query)
    query:HookScript("OnTextChanged", function(self)
        clear:SetShown((self:GetText() or "") ~= "")
    end)
    query:SetAutoFocus(false)
    query:SetFontObject("ChatFontNormal")
    query:SetMaxLetters(60)
    query:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    query:SetScript("OnEnterPressed", onEnter)
    return query
end

-- The bar the pane's full height, down beside the count to the search line.
function S.PlaceListBar(bar, list)
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", list, "TOPRIGHT", 6, -13)
    bar:SetPoint("BOTTOMLEFT", list, "BOTTOMRIGHT", 6, 1)
end

-- The list over foot (gap above it), its bar and 30 rows. placeBar(bar,
-- list) re-anchors the bar before its column is put on.
function S.ScrollRows(panel, foot, gap, onValue, columns, onClick, onDoubleClick, placeBar)
    local list = ns.NewFrame("Frame", nil, panel.listBox)
    list:SetPoint("TOPLEFT", panel.listBox, "TOPLEFT", 8, -4)
    list:SetPoint("BOTTOMRIGHT", foot, "TOPRIGHT", 0, gap)
    list:SetPoint("RIGHT", panel.listBox, "RIGHT", -26, 0)
    list:EnableMouseWheel(true)
    panel.list = list

    local bar = ns.ClassicScrollBar(panel, list, onValue)
    panel.bar = bar
    if placeBar then placeBar(bar, list) end
    -- No bar until the list outgrows its box, then the old scroll column round it.
    bar.hideWhenIdle = true
    ns.ScrollColumnOn(bar)
    -- Era's list inset, its foot on panel.insetFoot (the Who buttons) where set.
    ns.ListInset(panel.listBox, bar, panel.insetFoot)
    list:SetScript("OnMouseWheel", function(_, delta)
        bar:SetValue((bar:GetValue() or 0) - delta)
    end)

    panel.rows = {}
    for i = 1, 30 do panel.rows[i] = ListRow(list, i, columns, onClick, onDoubleClick) end
    return list
end

-- A row of either list: gold name, white zone and level, class colour or white; dim greys all four (offline).
function S.ShowRow(row, entry, zone, level, class, classFile, selected, dim)
    row.entry = entry
    row.Name:SetText(entry.name)
    row.Zone:SetText(zone)
    row.Level:SetText(level)
    row.Class:SetText(class)
    if dim then
        row.Name:SetTextColor(0.5, 0.5, 0.5)
        row.Zone:SetTextColor(0.5, 0.5, 0.5)
        row.Level:SetTextColor(0.5, 0.5, 0.5)
        row.Class:SetTextColor(0.5, 0.5, 0.5)
    else
        row.Name:SetTextColor(1, 0.82, 0)
        row.Zone:SetTextColor(1, 1, 1)
        row.Level:SetTextColor(1, 1, 1)
        local r, g, b = ns.ClassRGB(classFile)
        if r then row.Class:SetTextColor(r, g, b) else row.Class:SetTextColor(1, 1, 1) end
    end
    row.Selected:SetShown(selected)
    row:Show()
end

function S.HideRow(row)
    row.entry = nil
    row:Hide()
end

-- A second click on the same column turns the order round.
function S.ToggleSort(sort, key)
    if sort.field == key then
        sort.reverse = not sort.reverse
    else
        sort.field, sort.reverse = key, false
    end
end

---------------------------------------------------------------- names

function S.Invite(name)
    if C_PartyInfo and C_PartyInfo.InviteUnit then C_PartyInfo.InviteUnit(name) end
end

function S.AddFriend(name)
    if C_FriendList and C_FriendList.AddFriend then C_FriendList.AddFriend(name) end
end

function S.Ignore(name)
    if C_FriendList and C_FriendList.AddIgnore then C_FriendList.AddIgnore(name) end
end

-- Era's player menu section heads.
S.MENU_INTERACT = _G.UNIT_FRAME_DROPDOWN_SUBSECTION_TITLE_INTERACT or "Interact"
S.MENU_OTHER = _G.UNIT_FRAME_DROPDOWN_SUBSECTION_TITLE_OTHER or "Other Options"

-- One player menu for every list here (Report and Copy Name are the client's alone); entry.name is the player.
function S.ShowPlayerMenu(owner, entry)
    if not S.playerMenu then
        S.playerMenu = ns.RowMenu({
            { section = S.MENU_INTERACT },
            { INVITE or "Invite", function(who) S.Invite(who.name) end },
            { WHISPER or "Whisper", function(who) ns.Whisper(who.name) end },
            { section = S.MENU_OTHER },
            { ADD_FRIEND or "Add Friend", function(who) S.AddFriend(who.name) end },
            { IGNORE or "Ignore", function(who) S.Ignore(who.name) end },
        })
    end
    S.playerMenu:Follow(owner)
    S.playerMenu:Open(entry, entry.name)
end

---------------------------------------------------------------- recent allies

-- Invite button pulled in off the scroll column; the pin and clock icons move with it.
local INVITE_X = -4
local alliesWatch, alliesCount

local function PlaceAllyRow(row)
    if not ns.Once(row, "allyPlaced") then return end
    ns.SetPointOnce(row.PartyButton, "RIGHT", row, "RIGHT", INVITE_X, 0)
    ns.SetPointOnce(row.StateIconContainer, "TOPRIGHT", row, "TOPRIGHT", INVITE_X - 24, 0)
end

-- Pooled rows keep our anchors, so only a new row needs placing.
local function AlliesChanged(job)
    local n = job.target:GetNumChildren()
    if n ~= alliesCount then
        alliesCount = n
        return true
    end
end

local function PlaceAllies(job)
    ns.EachChild(job.target, PlaceAllyRow)
end

---------------------------------------------------------------- quick join

-- Two buttons in the foot band of the Recent Allies list and of the Quick Join list swap between the two, through
-- the client's own tabs (a pad over ours presses them, so the lists stay the game's). Out of a fight.
local SWAP_X, SWAP_Y = 2, 2    -- the first tab's left from the list box's left, its top above the box's foot
local JOIN_W = 112             -- the game's Request to Join button (135 wide): narrower, clear of the tabs
local ALLIES_PROXY = "ForeverClassicUIRecentAlliesTab"
local alliesProxy
local quickTabs = {}

local function NoOp() end
local function SwapWanted() return ns.panels and ns.panels.active end

local function AlliesTab()
    local header = _G.FriendsTabHeader
    return header and header.GetTabButton and header.recentAlliesTabID and header:GetTabButton(header.recentAlliesTabID)
end

-- Back to Recent Allies: the Friends tab, then its Recent Allies tab.
local function AlliesMacro()
    local tab = AlliesTab()
    if not tab then return "/click FriendsFrameTab1" end
    if not InCombatLockdown() then
        alliesProxy = alliesProxy or ns.ClickProxy(ALLIES_PROXY)
        ns.SetAttributeIf(alliesProxy, "clickbutton", tab)
    end
    return "/click FriendsFrameTab1\n/click " .. ALLIES_PROXY
end

-- Our Quick Join tabs wear the client tab's text, which carries the count; the resize fits them to it.
local function QuickText()
    local tab = ClientQuick()
    local text = tab and tab:GetText() or _G.QUICK_JOIN
    for i = 1, #quickTabs do
        quickTabs[i]:SetText(text)
        PanelTemplates_TabResize(quickTabs[i], 0)
    end
end

local function QuickMouse()
    local tab = ClientQuick()
    if tab then tab:EnableMouse(not quickOff) end
end

-- One of the macro window's tabs, turned over to hang from the list box's foot; the pad over it takes the click.
local function SwapTab(pane, name, text)
    local tab = ns.NewFrame("Button", name, pane, "PanelTopTabButtonTemplate")
    tab:SetScript("OnClick", nil)
    tab:SetText(text)
    ns.SkinHangTab(tab)
    return tab
end

-- onAllies: the pair under the Recent Allies list (its own tab picked), else under the Quick Join list.
local function SwapPair(pane, onAllies)
    local label = AlliesTab()
    local suffix = onAllies and "Allies" or "Quick"
    local allies = SwapTab(pane, "ForeverClassicUISwapAllies" .. suffix, label and label:GetText() or _G.CONTACTS_RECENT_ALLIES_TITLE)
    local quick = SwapTab(pane, "ForeverClassicUISwapQuick" .. suffix, _G.QUICK_JOIN)
    allies:SetPoint("TOPLEFT", _G.FriendsFrameInset, "BOTTOMLEFT", SWAP_X, SWAP_Y)
    quick:SetPoint("LEFT", allies, "RIGHT", 0, 0)
    quickTabs[#quickTabs + 1] = quick
    PanelTemplates_SelectTab(onAllies and allies or quick)
    PanelTemplates_DeselectTab(onAllies and quick or allies)
    if onAllies then
        ns.MapPad(quick, "HIGH", NoOp, ClientQuick(), SwapWanted)
    else
        ns.MapPad(allies, "HIGH", NoOp, AlliesMacro, SwapWanted)
    end
    ns.Sched.OnVisible(pane, "social.quickJoin", QuickText)
end

-- Once the window is dressed on a client with both lists.
function ns.SocialQuickJoin()
    local allies, quick, tab = _G.RecentAlliesFrame, _G.QuickJoinFrame, ClientQuick()
    if quickOff or not (allies and quick and tab) then return end
    quickOff = true
    ns.SetAlphaIf(tab, 0)
    ns.WhenCalm("social.clientQuick", QuickMouse)
    SwapPair(allies, true)
    SwapPair(quick, false)
    if quick.JoinQueueButton then quick.JoinQueueButton:SetWidth(JOIN_W) end
    ns.EventFrame("SOCIAL_QUEUE_UPDATE", QuickText)
    QuickText()
    S.PlaceTabs()
end

-- The watch hangs under the list, so it only runs while the tab shows.
function ns.PlaceRecentAllyRows()
    local host = _G["RecentAlliesFrame"]
    local list = host and host.List
    local target = list and list.ScrollBox and list.ScrollBox.ScrollTarget
    if alliesWatch or not target then return end
    alliesWatch = ns.NewFrame("Frame", nil, list)
    local job = ns.Sched.OnFrame(alliesWatch, { name = "friends.recentAllies", every = 0.25, pre = AlliesChanged, fn = PlaceAllies })
    job.target = target
end

---------------------------------------------------------------- the game's new social window

-- Our Friends and Raid tabs press the client's hidden ones, so the page changes in its own pass, as before the switch.
-- Off the raid page the raid frame is parked first: the raid parent's first tab takes it back and presses the client's
-- Friends tab (ClaimRaidFrame); the switch left nothing else to hide it.
local function StandInMacro(client)
    local text = "/click " .. client:GetName()
    if client == _G.FriendsFrameTab1 and _G.RaidParentFrameTab1 and _G.RaidFrame and _G.RaidFrame:GetParent() == FriendsFrame then
        text = "/click RaidParentFrameTab1\n" .. text
    end
    return text
end

local function PadWanted() return ns.SocialUIOn() and FriendsFrame ~= nil and FriendsFrame:IsShown() end
local function AfterPress()
    HideOurLists()
    SyncFriendsTab()
end

StandInPad = function(tab, client)
    if not client:GetName() then return end
    ns.MapPad(tab, "HIGH", AfterPress, function() return StandInMacro(client) end, PadWanted)
end

NewSocialUI = function()
    SyncFriendsTab()
end
