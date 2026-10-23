local _, ns = ...
local L = ns.L

-- The 1.x guild tab, rebuilt rather than re-anchored: this client keeps the
-- guild in the Communities window, which is left alone.

local G, S = ns.guild, ns.social
local EntryKey, LastOnline, GuildMOTD, GuildTitle = G.EntryKey, G.LastOnline, G.GuildMOTD, G.GuildTitle

local PILL_BORDER = "Interface\\ClassTrainerFrame\\UI-ClassTrainer-FilterBorder"
local CHECK_UP = ns.ART.CHECK .. "Up"
local CHECK_MARK = ns.ART.CHECK .. "Check"
local CHECK_HOVER = ns.ART.CHECK .. "Highlight"

-- Era's guild tab (Classic FriendsFrame.xml, eram guild), from the window's top left. Plates: w, barW with the scroll
-- bar; row texts: x from the row's left (Era's highlight, 8 in), tw wide, barX/barTw with the bar.
local COLUMNS = {
    { key = "name", label = NAME or "Name", w = 83, x = 9, tw = 88, justify = "LEFT" },
    { key = "zone", label = ZONE or "Zone", w = 120, barW = 105, x = 90, tw = 110, barTw = 95, justify = "LEFT" },
    { key = "level", label = LEVEL_ABBR or "Lvl", w = 32, x = 204, barX = 189, tw = 20, justify = "CENTER" },
    { key = "class", label = CLASS or "Class", w = 92, x = 236, barX = 221, tw = 87, barTw = 80, justify = "LEFT" },
}
-- The status view (foot arrow): rank, note, last online in the same slots.
local STATUS_COLUMNS = {
    { key = "name", label = NAME or "Name", w = 83, x = 9, tw = 75, justify = "LEFT" },
    { key = "rank", label = RANK or "Rank", w = 75, x = 89, tw = 55, justify = "LEFT" },
    { key = "note", label = LABEL_NOTE or "Note", w = 90, barW = 75, x = 155, tw = 85, barTw = 70, justify = "LEFT" },
    { key = "lastOnline", label = LASTONLINE or "Last Online", w = 75, x = 250, barX = 235, tw = 80, justify = "LEFT" },
}
local ROW_TEXTS = { "Name", "Zone", "Level", "Class" }
local ROSTER_EVENTS = { "GUILD_ROSTER_UPDATE", "PLAYER_GUILD_UPDATE", "GUILD_MOTD" }
local ROWS, ROW_H = 13, 16
-- Foot buttons: 123, 98, 104 wide at 3, 128, 228, their feet 4 up.
local GUILD_INFO_BUTTON_X = 3
local GUILD_INFO_BUTTON_WIDTH = 123
local GUILD_ADD_MEMBER_BUTTON_X = 128
local GUILD_ADD_MEMBER_BUTTON_WIDTH = 98
local GUILD_CONTROL_BUTTON_X = 228
local GUILD_CONTROL_BUTTON_WIDTH = 104
local GUILD_BUTTONS_Y = 4
-- The status arrow's left, 98 under the window's middle; further in with the scroll bar.
local STATUS_X, STATUS_BAR_X, STATUS_Y = 295, 272, -98
local ROW_BAR = "Interface\\FriendsFrame\\UI-FriendsFrame-HighlightBar"
local statusView = false

-- The offline pill: the trainer's filter border cut in three.
local OFFLINE_PILL = {
    { key = PILL_BORDER, set = "raw", layer = "BACKGROUND", w = 12, h = 28, coords = { 0.90625, 1, 0, 1 }, point = "TOPRIGHT" },
    { key = PILL_BORDER, set = "raw", layer = "BACKGROUND", w = 186, h = 28, coords = { 0.09375, 0.90625, 0, 1 }, point = "RIGHT", relPoint = "LEFT", chain = true },
    { key = PILL_BORDER, set = "raw", layer = "BACKGROUND", w = 12, h = 28, coords = { 0, 0.09375, 0, 1 }, point = "RIGHT", relPoint = "LEFT", chain = true },
}
local OFFLINE_BOX = { set = "raw", layer = "ARTWORK", w = 20, h = 20, point = "RIGHT", x = -8 }
local OFFLINE_CHECK = { set = "raw", layer = "OVERLAY", w = 20, h = 20, point = "CENTER" }
local OFFLINE_HOVER = { set = "raw", layer = "HIGHLIGHT", blend = "ADD", w = 20, h = 20, point = "CENTER" }
local STATUS_ARROW = { add = true }
local STATUS_TIP = { text = function()
    return statusView and (GUILD_STATUS or "Guild Status") or (PLAYER_STATUS or "Player Status")
end, r = 1, g = 1, b = 1 }

---------------------------------------------------------------- the list

-- The current view's columns onto the plates and row texts; Era narrows them round its scroll bar.
local function ApplyView()
    local panel = G.panel
    if not panel then return end
    local columns = statusView and STATUS_COLUMNS or COLUMNS
    local barOn = panel.bar:IsShown()
    panel.barOn = barOn
    for i, header in ipairs(panel.headers) do
        local column = columns[i]
        header.key = column.key
        header:SetWidth(barOn and column.barW or column.w)
        header.Text:SetText(column.label)
    end
    for _, row in ipairs(panel.rows) do
        for i, key in ipairs(ROW_TEXTS) do
            local text, column = row[key], columns[i]
            ns.SetPointOnce(text, "LEFT", row, "LEFT", barOn and column.barX or column.x, 0)
            text:SetSize(barOn and column.barTw or column.tw, 14)
            text:SetJustifyH(column.justify)
        end
    end
    ns.SetPointOnce(panel.status, "LEFT", FriendsFrame, "LEFT", barOn and STATUS_BAR_X or STATUS_X, STATUS_Y)
end

local function UpdateRows()
    local panel = G.panel
    if not panel then return end
    local roster, selected = G.roster, G.selected
    local offset = ns.ListOffset(panel.bar)
    local shown = S.RowCount(panel)
    for i, row in ipairs(panel.rows) do
        local entry = i <= shown and roster[offset + i] or nil
        if not entry then
            S.HideRow(row)
        elseif statusView then
            -- Rank, note and last online in the zone, level and class slots, uncolored.
            S.ShowRow(row, entry, entry.rank, entry.note, LastOnline(entry), nil, EntryKey(entry) == selected, not entry.online)
        else
            -- Era's roster: the class in white, as the zone and level.
            S.ShowRow(row, entry, entry.zone, entry.level, entry.class, nil, EntryKey(entry) == selected, not entry.online)
        end
    end
    panel.bar:SetRange(math.max(0, #roster - shown))
    if panel.bar:IsShown() ~= panel.barOn then ApplyView() end
    -- The row pads follow what the rows now hold.
    G.SyncBridge()
    G.FillMemberCard()
end

local function UpdateButtons()
    local panel = G.panel
    if not panel then return end
    panel.control:SetEnabled(IsGuildLeader and IsGuildLeader() and true or false)
    panel.add:SetEnabled(CanGuildInvite and CanGuildInvite() and true or false)
end

local function Refresh()
    local panel = G.panel
    if not panel or not panel:IsShown() then return end
    local total, online = G.CollectRoster()
    G.SortRoster()
    panel.totals:SetText(format(GUILD_TOTAL or "%d Guild Members", total))
    panel.online:SetText(format(GUILD_TOTALONLINE or "(%d Online)", online))
    panel.motd:SetText(GuildMOTD())
    panel.offline:SetChecked(G.ShowOffline())
    if FriendsFrameTitleText then FriendsFrameTitleText:SetText(GuildTitle()) end
    UpdateRows()
    UpdateButtons()
end
G.Refresh = Refresh

-- Reread after combat what the fight held back.
local regen = CreateFrame("Frame")
regen:RegisterEvent("PLAYER_REGEN_ENABLED")
regen:SetScript("OnEvent", function()
    if G.panel and G.panel:IsShown() then Refresh() end
end)

-- A C_GuildInfo call by name, where this client has it.
local function GuildCall(method, name)
    local call = C_GuildInfo and C_GuildInfo[method]
    if call then call(name) end
end

-- Right-click menu; closes on a click elsewhere or with the roster.
local rowMenu

local function NotMe(entry) return entry.name ~= UnitName("player") end

local function ShowRowMenu(entry)
    if not rowMenu then
        rowMenu = ns.RowMenu({
            { section = S.MENU_INTERACT },
            { INVITE or "Invite", function(e) S.Invite(e.name) end,
              function(e) return NotMe(e) and e.online end },
            { WHISPER or "Whisper", function(e) ns.Whisper(e.name) end,
              function(e) return NotMe(e) and e.online end },
            { GUILD_PROMOTE or "Promote", function(e) GuildCall("Promote", e.name) end,
              function(e) return NotMe(e) and CanGuildPromote and CanGuildPromote() end },
            { GUILD_DEMOTE or "Demote", function(e) GuildCall("Demote", e.name) end,
              function(e) return NotMe(e) and CanGuildDemote and CanGuildDemote() end },
            { REMOVE or "Remove", function(e) GuildCall("Uninvite", e.name) end,
              function(e) return NotMe(e) and CanGuildRemove and CanGuildRemove() end },
            { section = S.MENU_OTHER },
            { ADD_FRIEND or "Add Friend", function(e) S.AddFriend(e.name) end, NotMe },
            { IGNORE or "Ignore", function(e) S.Ignore(e.name) end, NotMe },
        })
        rowMenu:Follow(G.panel)
    end
    rowMenu:Open(entry, entry.name)
end

-- The member's status is the client's own frame, opened by the row pad's click on its row; in a fight our card.
local function Row_OnClick(self, button)
    if not self.entry then return end
    G.selected = EntryKey(self.entry)
    if button == "RightButton" then
        UpdateRows()
        ShowRowMenu(self.entry)
        return
    end
    if SetGuildRosterSelection then pcall(SetGuildRosterSelection, self.entry.index) end
    UpdateRows()
    G.ShowMemberCard()
end
G.Row_OnClick = Row_OnClick

local function Row_OnDoubleClick(self)
    if not self.entry or not self.entry.online then return end
    ns.Whisper(self.entry.name)
end
G.Row_OnDoubleClick = Row_OnDoubleClick

-- The client sorts its roster by our field too, so repeat clicks turn it as 1.x did.
local function Header_OnClick(self)
    S.ToggleSort(G.sort, self.key)
    if SortGuildRoster then pcall(SortGuildRoster, self.key) end
    Refresh()
end

-- The client's panels in the window, hidden while the roster is up.
local hidden = { key = "fcuiGuildHidden", swept = "fcuiGuildSwept", pending = false, insetTop = -80 }
S.SettleFrame(hidden)

function G.HideBlizzardPanels() S.HidePanels(hidden, G.panel) end
function G.ShowBlizzardPanels() S.ShowPanels(hidden) end

---------------------------------------------------------------- the panel

-- Era's rows on its highlight's run (8 in, 84 down), its scroll bar beside them (its FauxScrollFrame at -32, -87).
local function PlaceList(bar, list)
    local host = FriendsFrame
    ns.SetPointOnce(list, "TOPLEFT", host, "TOPLEFT", 8, -84)
    list:SetSize(298, ROWS * ROW_H)
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", host, "TOPLEFT", 312, -103)
    bar:SetPoint("BOTTOMLEFT", host, "TOPLEFT", 312, -308)
end

-- Era's guild buttons write small (their NormalFont), the label on the middle.
local function SmallFont(button)
    button:SetNormalFontObject(ns.FONT_GOLD_SMALL)
    button:SetHighlightFontObject("GameFontHighlightSmall")
    button:SetDisabledFontObject("GameFontDisableSmall")
    local label = button:GetFontString()
    if label then ns.SetPointOnce(label, "CENTER", button, "CENTER", 0, 0) end
end

function G.Build()
    local host = FriendsFrame
    if not host then return end
    local panel = S.NewPanel(host, "ClassicUIForeverGuildPanel")
    G.panel = panel

    -- Era's inset round the whole tab (its guild page holds it at 4, -80: hidden.insetTop); plates and bar over it.
    local inset = ns.NewFrame("Frame", nil, panel)
    inset:SetPoint("TOPLEFT", host, "TOPLEFT", 4, -80)
    inset:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -6, 25)
    inset:SetFrameLevel(panel:GetFrameLevel())
    ns.InnerBorder(inset)
    panel.listBox, panel.ownInset, panel.rowBar = inset, true, ROW_BAR

    -- Show Offline Members, the old pill under the title bar; the empty box shows either way.
    local offline = ns.NewFrame("CheckButton", nil, panel)
    panel.offline = offline
    offline:SetSize(210, 23)
    offline:SetPoint("TOPRIGHT", host, "TOPRIGHT", -10, -25)
    ns.DressPieces(offline, OFFLINE_PILL)
    local box = ns.DressNew(offline, CHECK_UP, OFFLINE_BOX)
    local check = ns.DressNew(offline, CHECK_MARK, OFFLINE_CHECK, box)
    offline:SetCheckedTexture(check)
    ns.DressNew(offline, CHECK_HOVER, OFFLINE_HOVER, box)
    local offlineText = offline:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    offlineText:SetPoint("RIGHT", box, "LEFT", -10, 1)
    offlineText:SetText(SHOW_OFFLINE_MEMBERS or "Show Offline Members")
    offline:SetScript("OnClick", function(self)
        if SetGuildRosterShowOffline then pcall(SetGuildRosterShowOffline, self:GetChecked() and true or false) end
        if C_GuildInfo and C_GuildInfo.GuildRoster then pcall(C_GuildInfo.GuildRoster) end
        Refresh()
    end)

    -- The foot: the three old buttons.
    panel.add = ns.PanelButton(panel, ADDMEMBER or "Add Member", GUILD_ADD_MEMBER_BUTTON_WIDTH)
    panel.add:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", GUILD_ADD_MEMBER_BUTTON_X, GUILD_BUTTONS_Y)
    SmallFont(panel.add)
    panel.add:SetScript("OnClick", function()
        -- The client's dialog errors unless told the guild's club.
        if StaticPopup_Show then
            local clubId = C_Club and C_Club.GetGuildClubId and C_Club.GetGuildClubId()
            StaticPopup_Show("ADD_GUILDMEMBER", nil, nil, { clubId = clubId })
        end
    end)

    panel.control = ns.PanelButton(panel, GUILDCONTROL or "Guild Control", GUILD_CONTROL_BUTTON_WIDTH)
    panel.control:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", GUILD_CONTROL_BUTTON_X, GUILD_BUTTONS_Y)
    SmallFont(panel.control)
    panel.control:SetScript("OnClick", function()
        -- Loaded on demand; the client's own opener loads and shows it.
        if GuildControlUI and GuildControlUI:IsShown() then
            ns.HidePanel(GuildControlUI)
        elseif type(GuildControlUI_Show) == "function" then
            GuildControlUI_Show()
            -- The client places it for the wider modern window: moved beside the roster next frame.
            ns.Sched.NextFrame("guild.controlPlace", function()
                if GuildControlUI and GuildControlUI:IsShown() and host:IsShown() and not InCombatLockdown() then
                    ns.SetPointOnce(GuildControlUI, "TOPLEFT", host, "TOPRIGHT", 6, 0)
                end
            end)
        elseif ToggleGuildControlUI then
            ToggleGuildControlUI()
        end
    end)

    panel.info = ns.PanelButton(panel, GUILD_INFORMATION or "Guild Information", GUILD_INFO_BUTTON_WIDTH)
    panel.info:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", GUILD_INFO_BUTTON_X, GUILD_BUTTONS_Y)
    SmallFont(panel.info)
    panel.info:SetScript("OnClick", function()
        -- The client's guild window via the kept toggle; the ghost is dropped first.
        G.DropGhost()
        if G.clientToggleGuild then G.clientToggleGuild() elseif ToggleGuildFrame then ToggleGuildFrame() end
    end)

    -- Era's trainer bar over the message: 1 in to 75 short of the right, 89 up; its end 75 columns drawn in 70.
    local barRun, barEnd = ns.DividerBar(inset)
    barRun:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", 1, 89)
    barRun:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -75, 89)
    barEnd:SetTexCoord(0, 75 / 256, 0.25, 0.5)
    barEnd:SetWidth(70)
    barEnd:SetPoint("LEFT", barRun, "RIGHT", 0, 0)

    -- The message: Era's label at 11, -331, the text box under it (the edit pad covers it).
    local motdLabel = inset:CreateFontString(nil, "ARTWORK")
    motdLabel:SetFontObject(ns.FONT_GOLD_SMALL)
    motdLabel:SetJustifyH("LEFT")
    motdLabel:SetHeight(11)
    motdLabel:SetPoint("TOPLEFT", host, "TOPLEFT", 11, -331)
    motdLabel:SetPoint("TOPRIGHT", host, "TOPLEFT", 236, -331)
    -- The client's string lost "Guild" and the colon; English gets the old words outright.
    local locale = GetLocale and GetLocale() or "enUS"
    if locale == "enUS" or locale == "enGB" then
        motdLabel:SetText(L["SOCIAL_GUILD_MESSAGE_OF_THE_DAY"])
    else
        motdLabel:SetText((GUILD_MOTD_LABEL or "Message of the Day") .. ":")
    end

    panel.motdBox = ns.NewFrame("Frame", nil, inset)
    panel.motdBox:SetPoint("TOPLEFT", motdLabel, "BOTTOMLEFT", 0, -3)
    panel.motdBox:SetPoint("TOPRIGHT", host, "TOPLEFT", 326, -345)
    panel.motdBox:SetHeight(45)
    panel.motd = panel.motdBox:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    panel.motd:SetAllPoints(panel.motdBox)
    panel.motd:SetJustifyH("LEFT")
    panel.motd:SetJustifyV("TOP")

    G.BuildMotdPad(panel)

    -- Era's plates from 7, -57, over the inset's top edge.
    local plates = ns.NewFrame("Frame", nil, panel)
    plates:SetSize(1, 24)
    plates:SetPoint("TOPLEFT", host, "TOPLEFT", 7, -57)
    plates:SetFrameLevel(inset:GetFrameLevel() + 2)
    panel.headers = {}
    local last
    for _, column in ipairs(COLUMNS) do
        last = ns.ColumnHeader(plates, column, last, Header_OnClick, true)
        panel.headers[#panel.headers + 1] = last
    end

    -- The counts under the rows, 98 under the window's middle, both in gold.
    panel.totals = inset:CreateFontString(nil, "ARTWORK")
    panel.totals:SetFontObject(ns.FONT_GOLD_SMALL)
    panel.totals:SetHeight(16)
    panel.totals:SetPoint("LEFT", host, "LEFT", 13, STATUS_Y)

    panel.online = inset:CreateFontString(nil, "ARTWORK")
    panel.online:SetFontObject(ns.FONT_GOLD_SMALL)
    panel.online:SetHeight(16)
    panel.online:SetPoint("LEFT", panel.totals, "RIGHT", 3, 0)

    -- The arrow beside the counts turns the roster over (placed with the view); its tooltip says to which face.
    panel.status = ns.NewFrame("Button", nil, inset)
    panel.status:SetSize(32, 32)
    ns.DressStates(panel.status, "sbNextUp", "sbNextDown", nil, "mouseHighlight", STATUS_ARROW)
    ns.AttachTip(panel.status, STATUS_TIP)

    panel.status:SetScript("OnClick", function(self)
        statusView = not statusView
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        ApplyView()
        -- A sort by a column the new face lacks falls back to the name.
        local columns = statusView and STATUS_COLUMNS or COLUMNS
        local known = false
        for _, column in ipairs(columns) do if column.key == G.sort.field then known = true end end
        if not known then G.sort.field, G.sort.reverse = "name", false end
        Refresh()
        if GameTooltip:IsOwned(self) then self:GetScript("OnEnter")(self) end
    end)

    S.ScrollRows(panel, panel.totals, 4, UpdateRows, COLUMNS, Row_OnClick, Row_OnDoubleClick, PlaceList)
    -- After the rows: the bridge hears the mouse on them.
    G.WatchBridge(panel)

    panel:SetScript("OnShow", function()
        if C_GuildInfo and C_GuildInfo.GuildRoster then pcall(C_GuildInfo.GuildRoster) end
        Refresh()
    end)
    -- The client's member frame closes with the ghost: no pick stays lit for reopening.
    panel:SetScript("OnHide", function()
        G.selected = nil
        G.HideMemberCard()
    end)

    -- Roster events burst: a refresh at most every 0.33 s. Idle, the frame
    -- hides (events still arrive) until one wakes it.
    local driver = ns.EventFrame(ROSTER_EVENTS, function(self)
        self.dirty = true
        G.bridge.stale = true
        if not self:IsShown() then self:Show() end
    end)
    ns.Sched.OnFrame(driver, { name = "guild.rosterDriver", every = 0, fn = function(_, elapsed)
        driver.wait = (driver.wait or 0) - elapsed
        if not driver.dirty then
            if driver.wait <= 0 then driver:Hide() end
            return
        end
        if driver.wait > 0 then return end
        driver.dirty, driver.wait = false, 0.33
        if G.active then Refresh() end
    end })
    panel.driver = driver
end
