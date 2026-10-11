local _, ns = ...

-- The friends page's sub-tabs: Friends, Recent Allies and Friend Requests, ours over the client's header tabs. Recent
-- Allies and Friend Requests are our own lists over the friends list (the game's switch shows neither in this window);
-- the ignore list is the client's own window, from its drop down.

local S = ns.social
local IsSecret, Safe = ns.IsSecret, ns.Safe

local PAGES = {
    { key = "friends", label = FRIENDS or "Friends" },
    { key = "allies", label = CONTACTS_RECENT_ALLIES_TAB_NAME or "Recent Allies" },
    { key = "requests" },
}
-- The who list's widths (Classic Era's) for the same four facts.
local ALLY_COLUMNS = {
    { key = "name", label = NAME or "Name", x = 4, w = 83, justify = "LEFT" },
    { key = "zone", label = ZONE or "Zone", x = 87, w = 105, justify = "LEFT" },
    { key = "level", label = LEVEL_ABBR or "Lvl", x = 192, w = 32, justify = "LEFT" },
    { key = "class", label = CLASS or "Class", x = 224, w = 92, justify = "LEFT" },
}
local REQUEST_COLUMNS = { { key = "name", label = NAME or "Name", x = 4, w = 312, justify = "LEFT" } }
local ALLY_EVENTS = { "RECENT_ALLIES_CACHE_UPDATE", "RECENT_ALLIES_DATA_READY", "RECENT_ALLY_DATA_UPDATED" }
local REQUEST_EVENTS = { "BN_FRIEND_INVITE_ADDED", "BN_FRIEND_INVITE_REMOVED", "BN_FRIEND_INVITE_LIST_INITIALIZED" }
-- Battle.net names in the friends list's blue.
local BNET_BLUE = { 0.51, 0.773, 1 }
-- Sub-tab row: room left at the window's right; each tab's label padding may shrink to this (its caps then overlap it).
local ROW_RIGHT, MIN_PAD = 6, -15
-- Client pieces our pages stand over: the list, its foot buttons.
local CLIENT_FRIENDS = { "FriendsListFrame", "FriendsFrameAddFriendButton", "FriendsFrameSendMessageButton" }

local current = "friends"
local tabs, pages = {}, {}
local allies, requests = {}, {}
local clientTabsOff = false

-- Under the switch, while a window of ours dresses the friends window (the guild roster or the who list is on); with it
-- off the client's own Recent Allies page and its Quick Join swap stay.
local function Wanted()
    if not (FriendsFrame and ns.SocialUIOn()) then return false end
    return (ns.guild and ns.guild.active) or (S.whoTab ~= nil and S.whoTab:IsShown()) or false
end

---------------------------------------------------------------- data

local function ClassOf(classID)
    local info = C_CreatureInfo and C_CreatureInfo.GetClassInfo and classID and C_CreatureInfo.GetClassInfo(classID)
    if not info then return "", nil end
    return info.className or "", info.classFile
end

local function Matches(entry, find)
    if not find then return true end
    for _, field in ipairs({ entry.name, entry.zone, entry.class }) do
        if field:lower():find(find, 1, true) then return true end
    end
    return false
end

-- Online first, then by name; the latest meeting kept for the tooltip. find: the search line's text, lower case.
local function CollectAllies(find)
    wipe(allies)
    local api = C_RecentAllies
    if not (api and api.GetRecentAllies) then return end
    local ok, list = pcall(api.GetRecentAllies)
    if not ok or type(list) ~= "table" then return end
    for _, ally in ipairs(list) do
        local char, state = ally.characterData, ally.stateData
        if char and type(char.fullName) == "string" and not IsSecret(char.fullName) then
            local class, classFile = ClassOf(Safe(char.classID, nil))
            local met = ally.interactionData and ally.interactionData.interactions
            local entry = {
                name = char.fullName,
                zone = Safe(state and state.currentLocation, "") or "",
                level = Safe(char.level, 0),
                class = class,
                classFile = classFile,
                online = state and Safe(state.isOnline, false) or false,
                met = met and met[1] and Safe(met[1].description, nil),
            }
            if Matches(entry, find) then allies[#allies + 1] = entry end
        end
    end
    table.sort(allies, function(a, b)
        if a.online ~= b.online then return a.online end
        return a.name:lower() < b.name:lower()
    end)
end

-- Pending Battle.net friend requests, in the client's order; ns.DevFriendRequests: the dev addon's stand-ins
-- (/fcuidev fakerequests), never sent to the client.
local function CollectRequests()
    wipe(requests)
    local stand = ns.DevFriendRequests
    if type(stand) == "table" then
        for _, invite in ipairs(stand) do requests[#requests + 1] = invite end
        return
    end
    local info = C_BattleNet and C_BattleNet.GetFriendInviteInfo
    if not (info and BNGetNumFriendInvites) then return end
    for i = 1, Safe(BNGetNumFriendInvites(), 0) or 0 do
        local invite = info(i)
        if invite and invite.inviteID and invite.accountName then
            requests[#requests + 1] = { id = invite.inviteID, name = invite.accountName }
        end
    end
end

-- The dev addon's stand-in words (another client's), so a long language's tab row shows on this one.
local function Label(text) return ns.DevLabel and ns.DevLabel(text) or text end

local function RequestsLabel()
    local count = BNGetNumFriendInvites and Safe(BNGetNumFriendInvites(), 0) or 0
    if type(ns.DevFriendRequests) == "table" then count = #ns.DevFriendRequests end
    return format(Label(FRIEND_REQUESTS or "Friend Requests (%d)"), count)
end

---------------------------------------------------------------- the lists

local function Selected(page) return page.entries and page.selected and page.entries[page.selected] end

local function UpdateRows(page)
    local offset = ns.ListOffset(page.bar)
    local shown = S.RowCount(page)
    for i, row in ipairs(page.rows) do
        local entry = i <= shown and page.entries[offset + i] or nil
        local picked = page.selected == offset + i
        if not entry then
            S.HideRow(row)
        elseif page.key == "allies" then
            S.ShowRow(row, entry, entry.zone, entry.level, entry.class, entry.classFile, picked, not entry.online)
        else
            row.entry = entry
            row.Name:SetText(entry.name)
            row.Name:SetTextColor(BNET_BLUE[1], BNET_BLUE[2], BNET_BLUE[3])
            row.Selected:SetShown(picked)
            row:Show()
        end
    end
    page.bar:SetRange(math.max(0, #page.entries - shown))
    local entry = Selected(page)
    page.left:SetEnabled(entry ~= nil)
    page.right:SetEnabled(entry ~= nil)
    if page.empty then page.empty:SetShown(#page.entries == 0) end
end

local function Refresh(page)
    if not page or not page:IsShown() then return end
    if page.key == "allies" then
        local text = page.query and page.query:GetText() or ""
        CollectAllies(text ~= "" and text:lower() or nil)
        page.found:SetText(format(WHO_NUM_RESULTS or "%d", #allies))
    else
        CollectRequests()
    end
    if page.selected and page.selected > #page.entries then page.selected = nil end
    UpdateRows(page)
end

local function RowClick(self, button)
    local page = self:GetParent():GetParent():GetParent()
    if not self.entry then return end
    for i, entry in ipairs(page.entries) do
        if entry == self.entry then page.selected = i end
    end
    UpdateRows(page)
    if button == "RightButton" and page.key == "allies" then S.ShowPlayerMenu(page, self.entry) end
end

local function RowDoubleClick(self)
    if self.entry and self:GetParent():GetParent():GetParent().key == "allies" then ns.Whisper(self.entry.name) end
end

-- Where you last met, under the name.
local function RowEnter(self)
    local entry = self.entry
    if not (entry and entry.met) then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(entry.name, 1, 0.82, 0)
    GameTooltip:AddLine(entry.met, 1, 1, 1, true)
    GameTooltip:Show()
end

---------------------------------------------------------------- the pages

-- A foot button over one of the client's (faded under ours), its size and place.
local function FootButton(page, over, text, onClick)
    local button = ns.PanelButton(page, text, 120)
    local client = _G[over]
    if client then button:SetAllPoints(client) end
    button:SetScript("OnClick", function()
        local entry = Selected(page)
        onClick(entry)
    end)
    return button
end

-- A request answered by the client's own call; the pick clears so a second click answers no one. A dev stand-in leaves
-- its list as the server takes a real one away (whose removal event refreshes the list and the tab's count).
local function Answer(page, entry, send)
    if not entry then return end
    page.selected = nil
    local stand = ns.DevFriendRequests
    if entry.dev and type(stand) == "table" then
        for i, invite in ipairs(stand) do
            if invite == entry then
                table.remove(stand, i)
                break
            end
        end
        Refresh(page)
        local tab = tabs.requests
        local onEvent = tab and tab:GetScript("OnEvent")
        if onEvent then onEvent(tab) end
        return
    end
    UpdateRows(page)
    if not entry.dev and send then send(entry.id) end
end

-- The who list's layout: plates, the list box down to an unseen bar over the buttons; Recent Allies adds its count and
-- search line under the list, the inset running round them to the buttons.
local function BuildPage(key)
    local host = FriendsFrame
    local inset = _G.FriendsFrameInset or host
    local page = ns.NewFrame("Frame", key == "allies" and "ClassicUIForeverAlliesPage" or "ClassicUIForeverRequestsPage", host)
    page.key = key
    -- Not page.list: the shared list builder keeps its scroll frame there.
    page.entries = key == "allies" and allies or requests
    page:SetPoint("TOPLEFT", inset, "TOPLEFT", 2, -2)
    page:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -8, 12)
    page:SetFrameLevel(host:GetFrameLevel() + 6)
    page:EnableMouse(true)
    page:Hide()
    local first
    if key == "allies" then
        page.left = FootButton(page, "FriendsFrameAddFriendButton", GROUP_INVITE or "Group Invite",
            function(entry) if entry then S.Invite(entry.name) end end)
        page.right = FootButton(page, "FriendsFrameSendMessageButton", ADD_FRIEND or "Add Friend",
            function(entry) if entry then S.AddFriend(entry.name) end end)
        first = page.left
    else
        page.left = FootButton(page, "FriendsFrameAddFriendButton", ACCEPT or "Accept",
            function(entry) Answer(page, entry, BNAcceptFriendInvite) end)
        page.right = FootButton(page, "FriendsFrameSendMessageButton", DECLINE or "Decline",
            function(entry) Answer(page, entry, BNDeclineFriendInvite) end)
        first = page.left
    end
    local divider = ns.StoneBar(page)
    divider:SetAlpha(0)
    divider:SetPoint("BOTTOM", first, "TOP", 0, 3)
    S.Span(divider, host)
    local columns = key == "allies" and ALLY_COLUMNS or REQUEST_COLUMNS
    local headerRow, _, band = S.HeaderRow(page, host, columns)
    -- The band from the inset's top: one lower left the shade over the list's floor bare beside the sub-tabs, a dark line.
    band:SetPoint("TOP", inset, "TOP", 0, 0)
    page.listBox = S.ListBox(page, host, headerRow, divider)
    -- The inset border down to the buttons on both pages, as on Friends.
    page.insetFoot = first
    if key == "allies" then
        page.found = page.listBox:CreateFontString(nil, "ARTWORK")
        page.found:SetFontObject(ns.FONT_GOLD_SMALL or "GameFontNormalSmall")
        page.found:SetPoint("BOTTOM", page.listBox, "BOTTOM", 0, 19)
        local query = S.SearchLine(page, function(self) self:ClearFocus() end)
        query:HookScript("OnTextChanged", function() Refresh(page) end)
        S.ScrollRows(page, page.found, 2, function() UpdateRows(page) end, columns, RowClick, RowDoubleClick, S.PlaceListBar)
        -- The game alone may ask for the data (TryRequestRecentAlliesData is forbidden to addons): its lists ask as they
        -- open; ours reads what it holds and follows its updates.
        page:SetScript("OnShow", function(self)
            ns.RegisterEvents(self, ALLY_EVENTS)
            Refresh(self)
        end)
    else
        S.ScrollRows(page, divider, 2, function() UpdateRows(page) end, columns, RowClick, RowDoubleClick)
        page.empty = page.listBox:CreateFontString(nil, "ARTWORK", "GameFontDisable")
        page.empty:SetPoint("CENTER", page.listBox, "CENTER", 0, 0)
        page.empty:SetText(NO_FRIEND_REQUESTS or "")
        page:SetScript("OnShow", function(self)
            ns.RegisterEvents(self, REQUEST_EVENTS)
            Refresh(self)
        end)
    end
    for _, row in ipairs(page.rows) do
        row:SetScript("OnEnter", RowEnter)
        row:SetScript("OnLeave", GameTooltip_Hide)
    end
    page:SetScript("OnHide", function(self) self:UnregisterAllEvents() end)
    page:SetScript("OnEvent", function(self) Refresh(self) end)
    pages[key] = page
    return page
end

---------------------------------------------------------------- the sub-tabs

-- The client's header tabs stay as they are, unseen and deaf under ours.
local function ClientTabMouse()
    local system = FriendsTabHeader and FriendsTabHeader.TabSystem
    if system then ns.EachChild(system, function(child) child:EnableMouse(not clientTabsOff) end) end
end

local function ClientTabs(off)
    local system = FriendsTabHeader and FriendsTabHeader.TabSystem
    if not system or off == clientTabsOff then return end
    clientTabsOff = off
    ns.SetAlphaIf(system, off and 0 or 1)
    ns.WhenCalm("social.headerTabs", ClientTabMouse)
end

local function TabClick(self)
    PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
    current = self.page
    S.SyncContactPages()
end

-- The three labels at their padding; a row running past the window's right gives up padding alike, then the longest
-- label is cut. Run as the sub-tabs show and as the count changes.
local function FitTabs()
    local first, last = tabs.friends, tabs.requests
    for _, info in ipairs(PAGES) do
        local tab = tabs[info.key]
        tab:SetText(info.key == "requests" and RequestsLabel() or Label(info.label))
        ns.SkinTopTab(tab, 0, nil, true)
    end
    local left, right = first:GetLeft(), FriendsFrame:GetRight()
    if not left or not right or IsSecret(left) or IsSecret(right) then return end
    local over = last:GetRight() - (right - ROW_RIGHT)
    if over <= 0 then return end
    local pad = math.max(MIN_PAD, -math.ceil(over / #PAGES))
    for _, info in ipairs(PAGES) do ns.SkinTopTab(tabs[info.key], pad, nil, true) end
    over = last:GetRight() - (right - ROW_RIGHT)
    if over <= 0 then return end
    local longest
    for _, info in ipairs(PAGES) do
        local tab = tabs[info.key]
        if not longest or tab:GetWidth() > longest:GetWidth() then longest = tab end
    end
    ns.SkinTopTab(longest, pad, math.floor(longest.Text:GetStringWidth() - over), true)
end

-- The requests tab's count follows the requests while the tabs are up.
local function CountRequests(self)
    if self:IsShown() then FitTabs() end
end

local function BuildTabs()
    local system = FriendsTabHeader and FriendsTabHeader.TabSystem
    local previous
    for i, info in ipairs(PAGES) do
        local tab = ns.NewFrame("Button", "ClassicUIForeverContactTab" .. i, FriendsFrame, "PanelTopTabButtonTemplate")
        tab:SetText(info.key == "requests" and RequestsLabel() or info.label)
        tab.page = info.key
        tab:SetScript("OnClick", TabClick)
        ns.SkinTopTab(tab, nil, nil, true)
        if previous then
            tab:SetPoint("LEFT", previous, "RIGHT", 0, 0)
        else
            tab:SetPoint("BOTTOMLEFT", system or _G.FriendsFrameInset, system and "BOTTOMLEFT" or "TOPLEFT", 0, 0)
        end
        tabs[info.key] = tab
        previous = tab
    end
    local requestsTab = tabs.requests
    requestsTab:SetScript("OnShow", function(self) ns.RegisterEvents(self, REQUEST_EVENTS) end)
    requestsTab:SetScript("OnHide", function(self) self:UnregisterAllEvents() end)
    requestsTab:SetScript("OnEvent", CountRequests)
    BuildPage("allies")
    BuildPage("requests")
end

-- The client's list and foot buttons step aside (alpha) while one of our pages covers them.
local function ClientFriends(shown)
    for _, name in ipairs(CLIENT_FRIENDS) do
        local frame = _G[name]
        if frame then ns.SetAlphaIf(frame, shown and 1 or 0) end
    end
end

-- Run after the window's own tab and list changes settle (Soon): on the friends foot tab with nothing of ours over it,
-- the sub-tabs and the picked page show; else none. A shut window starts on Friends again, as the client does.
function S.SyncContactPages()
    if not Wanted() then
        if next(tabs) then
            for _, tab in pairs(tabs) do tab:Hide() end
            for _, page in pairs(pages) do page:Hide() end
            ClientTabs(false)
            ClientFriends(true)
        end
        return
    end
    if not next(tabs) then BuildTabs() end
    local open = FriendsFrame:IsShown()
    if not open then current = "friends" end
    local onFriends = open and not S.OverlayUp() and not S.OnRaidPage()
    ClientTabs(true)
    for key, tab in pairs(tabs) do
        ns.SetShownIf(tab, onFriends)
        if onFriends then
            if key == current then PanelTemplates_SelectTab(tab) else PanelTemplates_DeselectTab(tab) end
        end
    end
    for key, page in pairs(pages) do ns.SetShownIf(page, onFriends and key == current) end
    if onFriends then
        FitTabs()
        ClientFriends(current == "friends")
    end
    if ns.SocialInsetBorder then ns.SocialInsetBorder() end
end

-- One of our pages covers the friends list (Windows/Panels.lua leaves the client's inset border off then).
function ns.ContactPageUp()
    for _, page in pairs(pages) do
        if page:IsShown() then return true end
    end
    return false
end
