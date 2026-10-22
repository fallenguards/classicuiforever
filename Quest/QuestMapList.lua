local _, ns = ...

-- The combined map's quest list on the sheets' column, the picked quest's text on the left page and its rewards on
-- the right (the 3.x map): the log's headers and quests, a quest's objectives under its title. The hosts come from
-- Map/WorldMapCombined.lua; Quest/QuestLogDetail.lua writes the pages.

local QL = ns.QL

local QM = {}
ns.QuestMapList = QM

local CHECK_MARK = ns.ART.CHECK .. "Check"
local CHECK_BOX, CHECK_DOWN = "Interface\\Buttons\\UI-CheckBox-Up", "Interface\\Buttons\\UI-CheckBox-Down"
local CHECK_GLOW, CHECK_OFF = "Interface\\Buttons\\UI-CheckBox-Highlight", "Interface\\Buttons\\UI-CheckBox-Check-Disabled"
-- The list's room in the column (its rim and the book's spine at its left, the drawn scroll track at its right) and
-- the pages' in their parchment. Each bar's left from its host's right edge, its arrows' tops and feet from the host's:
-- the list's in the track's squares, the text's at its parchment's edge short of the spine, the rewards' on the binding.
local LIST_L, LIST_R, LIST_T, LIST_B = 14, 23, 8, 8
local PAGE_L, PAGE_T, PAGE_B = 8, 8, 8
local TEXT_R, REWARDS_R = 20, 4
local LIST_BAR_X, LIST_BAR_TOP, LIST_BAR_FOOT = -16, 2, 1
local TEXT_BAR_X, REWARDS_BAR_X, PAGE_BAR_TOP, PAGE_BAR_FOOT = -13, 0, 2, 2
local HEADER_EXTRA, ROW_GAP = 2, 3
local TITLE_X, HEADER_TITLE_X, LINE_X, CHECK_SIZE = 6, 22, 14, 16
local MAX_LINES = 8
local WHEEL_STEP = 30
local TRACK_GAP = 14        -- Track Quest's box left of Map Options
local TRACK_ALONE_X = -140  -- its box's right from the foot's, with no Map Options box
local DONE = { 0.6, 0.6, 0.6 }

local LOG_EVENTS = { "QUEST_LOG_UPDATE", "QUEST_WATCH_LIST_CHANGED", "UNIT_QUEST_LOG_CHANGED", "GROUP_ROSTER_UPDATE",
    "PLAYER_MONEY", "GET_ITEM_INFO_RECEIVED" }

local list, detail, rewards, track, window
local rows = {}
local selectedID
local hasTimer = false

local Update

local function SetHasTimer(on) hasTimer = on end

------------------------------------------------------------------ list rows

local function Line(row, i, y)
    local lines = row.lines
    local fs = lines[i]
    if not fs then
        fs = row:CreateFontString(nil, "ARTWORK")
        fs:SetFontObject(ns.QuestListFontSmall)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(false)
        lines[i] = fs
    end
    ns.SetTwoPointsIf(fs, "TOPLEFT", row, "TOPLEFT", LINE_X, -y, "TOPRIGHT", row, "TOPRIGHT", -CHECK_SIZE - 2, -y)
    return fs
end

local function RowClick(row)
    local info = row.info
    if not info then return end
    if info.isHeader then
        PlaySound(QL.ToggleHeader(info) and SOUNDKIT.IG_QUEST_LIST_CLOSE or SOUNDKIT.IG_QUEST_LIST_OPEN)
        Update()
        return
    end
    if IsModifiedClick("CHATLINK") and ChatFrameUtil and ChatFrameUtil.InsertLink then
        local link = GetQuestLink(info.questID)
        if link and ChatFrameUtil.InsertLink(link) then return end
    end
    if IsShiftKeyDown() then QL.SetWatched(info.questID, not QL.IsWatched(info.questID)) end
    selectedID = info.questID
    C_QuestLog.SetSelectedQuest(info.questID)
    PlaySound(SOUNDKIT.IG_QUEST_LIST_SELECT)
    Update()
end

local function RowEnter(row)
    if row.info then row.title:SetTextColor(1, 1, 1) end
end

-- The picked quest stays white; the rest go back to their level color.
local function RowLeave(row)
    local info = row.info
    if info and (info.isHeader or info.questID ~= selectedID) then row.title:SetTextColor(QL.LevelColor(info)) end
end

local function MakeRow(i)
    local row = ns.NewFrame("Button", nil, list.child)
    row.lines = {}
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(16, 16)
    row.icon:SetPoint("TOPLEFT", row, "TOPLEFT", 2, -1)
    row.glow = row:CreateTexture(nil, "HIGHLIGHT")
    row.glow:SetTexture(ns.ART.PLUS_GLOW)
    row.glow:SetBlendMode("ADD")
    row.glow:SetAllPoints(row.icon)
    row.title = row:CreateFontString(nil, "ARTWORK")
    row.title:SetFontObject(ns.QuestListFont)
    row.title:SetJustifyH("LEFT")
    row.title:SetWordWrap(false)
    row.check = row:CreateTexture(nil, "OVERLAY")
    row.check:SetTexture(CHECK_MARK)
    row.check:SetSize(CHECK_SIZE, CHECK_SIZE)
    row.check:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
    -- 1.x: the picked quest's bar in its level color, under white text.
    row.band = row:CreateTexture(nil, "BACKGROUND")
    ns.SetTex(row.band, "questLogHighlight")
    row.band:SetBlendMode("ADD")
    row.band:SetAllPoints(row)
    row:SetScript("OnClick", RowClick)
    row:SetScript("OnEnter", RowEnter)
    row:SetScript("OnLeave", RowLeave)
    row:RegisterForClicks("LeftButtonUp")
    rows[i] = row
    return row
end

-- Header: collapse icon and name. Quest: title, its objectives under it, a check if tracked. Returns the row's height.
local function FillRow(row, info, y)
    row.info = info
    local r, g, b = QL.LevelColor(info)
    local titleH, lineH = ns.QuestFontHeights()
    local height
    if info.isHeader then
        height = titleH + HEADER_EXTRA
        ns.SetCollapseIcon(row.icon, info.isCollapsed)
        row.icon:Show()
        row.glow:Show()
        row.title:SetText(info.title or "")
        row.title:SetTextColor(r, g, b)
        for i = 1, #row.lines do row.lines[i]:Hide() end
        row.check:Hide()
        row.band:Hide()
    else
        row.icon:Hide()
        row.glow:Hide()
        local level = ns.db.questLevels and tonumber(info.difficultyLevel or info.level)
        row.title:SetText((level and level > 0 and ("[" .. level .. "] ") or "") .. (info.title or ""))
        local n, index = 0, info.questLogIndex
        for i = 1, math.min(GetNumQuestLeaderBoards(index) or 0, MAX_LINES) do
            local text, kind, finished = GetQuestLogLeaderBoard(i, index)
            if not text or text == "" then text = kind end
            if text and text ~= "" then
                n = n + 1
                local fs = Line(row, n, titleH + (n - 1) * lineH)
                fs:SetText("- " .. text)
                if finished then fs:SetTextColor(unpack(DONE)) else fs:SetTextColor(1, 1, 1) end
                fs:Show()
            end
        end
        for i = n + 1, #row.lines do row.lines[i]:Hide() end
        height = titleH + n * lineH + ROW_GAP
        row.check:SetShown(QL.IsWatched(info.questID))
        local picked = info.questID == selectedID
        row.band:SetShown(picked)
        if picked then
            row.band:SetVertexColor(r, g, b)
            row.title:SetTextColor(1, 1, 1)
        else
            row.title:SetTextColor(r, g, b)
        end
    end
    local x = info.isHeader and HEADER_TITLE_X or TITLE_X
    ns.SetTwoPointsIf(row.title, "TOPLEFT", row, "TOPLEFT", x, 0, "BOTTOMRIGHT", row, "TOPRIGHT", -CHECK_SIZE - 2, -titleH)
    ns.SetTwoPointsIf(row, "TOPLEFT", list.child, "TOPLEFT", 0, -y, "BOTTOMRIGHT", list.child, "TOPRIGHT", 0, -(y + height))
    row:Show()
    return height
end

----------------------------------------------------------------- the pages

local function UpdateDetail()
    QL.ResetDetail(window)
    local info = selectedID and QL.QuestInLog(selectedID)
    track:SetEnabled(info ~= nil)
    track:SetChecked(info ~= nil and QL.IsWatched(selectedID))
    if not info then
        hasTimer = false
        detail.child:SetHeight(1)
        detail.bar:SetRange(0)
        rewards.child:SetHeight(1)
        rewards.bar:SetRange(0)
        return
    end
    -- The pages' first showing has no size yet: their size change refills.
    if detail:GetWidth() < 60 then return end
    window.textW = detail:GetWidth() - 8
    window.rewardH = rewards:GetHeight()
    detail.child:SetWidth(detail:GetWidth())
    rewards.child:SetWidth(rewards:GetWidth())
    QL.FillDetail(window, info, detail:GetHeight(), SetHasTimer)
end

-- Collects once; the rows down the column, the pages for the picked quest.
function Update()
    if not (list and list:IsVisible()) then return end
    local entries = QL.CollectEntries()
    local current = C_QuestLog.GetSelectedQuest()
    if selectedID and not QL.QuestInLog(selectedID) then selectedID = nil end
    if not selectedID and current and current > 0 and QL.QuestInLog(current) then selectedID = current end
    if not selectedID then selectedID = QL.FirstQuest() end
    local y = 0
    for i, info in ipairs(entries) do
        y = y + FillRow(rows[i] or MakeRow(i), info, y)
    end
    for i = #entries + 1, #rows do rows[i]:Hide() end
    list.child:SetWidth(list:GetWidth())
    list.child:SetHeight(math.max(y, 1))
    list.bar:SetRange(math.max(0, y - list:GetHeight()), WHEEL_STEP)
    list.empty:SetShown(#entries == 0)
    UpdateDetail()
end

------------------------------------------------------------------ building

-- A scrolling box in the host's room with the old scroll bar on the host's drawn track (barX from its right edge, the
-- arrows top and foot from its); the wheel scrolls it.
local function Pane(host, l, r, t, b, barX, barTop, barFoot)
    local scroll = ns.NewFrame("ScrollFrame", nil, host)
    scroll:SetPoint("TOPLEFT", host, "TOPLEFT", l, -t)
    scroll:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -r, b)
    scroll:SetClipsChildren(true)
    local child = ns.NewFrame("Frame", nil, scroll)
    child:SetSize(1, 1)
    scroll:SetScrollChild(child)
    scroll.child = child
    scroll.bar = ns.ClassicScrollBar(host, scroll, function(value) scroll:SetVerticalScroll(value) end)
    scroll.bar:ClearAllPoints()
    scroll.bar:SetPoint("TOPLEFT", host, "TOPRIGHT", barX, barTop - 16)
    scroll.bar:SetPoint("BOTTOMLEFT", host, "BOTTOMRIGHT", barX, barFoot + 16)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(_, delta) scroll.bar:SetValue(scroll.bar:GetValue() - delta * WHEEL_STEP) end)
    -- The share dragged: the boxes change size, the text reflows.
    scroll:SetScript("OnSizeChanged", function() ns.Sched.NextFrame("questMap.size", Update) end)
    return scroll
end

local function TrackClick(self)
    if not selectedID then
        self:SetChecked(false)
        return
    end
    QL.SetWatched(selectedID, self:GetChecked())
    PlaySound(self:GetChecked() and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
    Update()
end

-- Track Quest at the foot, the 3.x check box.
local function TrackCheck(foot)
    local button = ns.NewFrame("CheckButton", nil, foot)
    button:SetSize(24, 24)
    button:SetNormalTexture(CHECK_BOX)
    button:SetPushedTexture(CHECK_DOWN)
    button:SetHighlightTexture(CHECK_GLOW)
    button:GetHighlightTexture():SetBlendMode("ADD")
    button:SetCheckedTexture(CHECK_MARK)
    button:SetDisabledCheckedTexture(CHECK_OFF)
    local label = button:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    label:SetPoint("LEFT", button, "RIGHT", 2, 0)
    label:SetText(TRACK_QUEST or "Track Quest")
    button.label = label
    button:SetScript("OnClick", TrackClick)
    return button
end

-- Track Quest's box left of Map Options' (its label runs on to the right), else at the foot's right.
function QM.LayFoot()
    if not track then return end
    local box = ns.MapOptions.Frame()
    local labelW = track.label:GetStringWidth() or 0
    if box then
        ns.SetPointIf(track, "RIGHT", box, "LEFT", -TRACK_GAP - labelW, 0)
    else
        ns.SetPointIf(track, "RIGHT", track:GetParent(), "RIGHT", TRACK_ALONE_X - labelW, 0)
    end
end

-- A reward item's data arriving late redraws the pages alone.
local function OnEvent(_, event)
    if event == "GET_ITEM_INFO_RECEIVED" then
        if selectedID then ns.Sched.Soon("questMap.detail", UpdateDetail) end
        return
    end
    ns.Sched.Soon("questMap.update", Update)
end

function QM.Attach(hosts)
    list = Pane(hosts.list, LIST_L, LIST_R, LIST_T, LIST_B, LIST_BAR_X, LIST_BAR_TOP, LIST_BAR_FOOT)
    list.empty = list:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    list.empty:SetPoint("TOPLEFT", list, "TOPLEFT", 10, -20)
    list.empty:SetPoint("RIGHT", list, "RIGHT", -10, 0)
    list.empty:SetText(QUESTLOG_NO_QUESTS_TEXT or "You have no quests.")
    list.empty:Hide()
    ns.QuestPaper(list, "mapQuestCombinedPaper")
    detail = Pane(hosts.pageL, PAGE_L, TEXT_R, PAGE_T, PAGE_B, TEXT_BAR_X, PAGE_BAR_TOP, PAGE_BAR_FOOT)
    rewards = Pane(hosts.pageR, PAGE_L, REWARDS_R, PAGE_T, PAGE_B, REWARDS_BAR_X, PAGE_BAR_TOP, PAGE_BAR_FOOT)
    window = { detailChild = detail.child, detailBar = detail.bar, rewardChild = rewards.child, rewardBar = rewards.bar,
        sizedText = true }
    track = TrackCheck(hosts.foot)
    -- Log events while the column shows; one refill per frame however many arrive.
    hosts.list:SetScript("OnShow", function(self)
        ns.RegisterEvents(self, LOG_EVENTS, "player")
        Update()
    end)
    hosts.list:SetScript("OnHide", function(self) self:UnregisterAllEvents() end)
    hosts.list:SetScript("OnEvent", OnEvent)
    -- A timed quest's clock, once a second while its page shows.
    ns.Sched.Attach(hosts.pageL, { name = "questMap.timer", every = 1, fn = function() if hasTimer then UpdateDetail() end end })
end

-- The game's "open the log at this quest" while the combined map shows: picked in its list, the map stays up.
function QM.Take(questID)
    if not (list and list:IsVisible() and questID) then return false end
    QL.CollectEntries()
    if not QL.QuestInLog(questID) then return false end
    selectedID = questID
    C_QuestLog.SetSelectedQuest(questID)
    Update()
    return true
end

ns.OnToggle(function(key)
    if key == "mapQuestCombinedPaper" and list then ns.QuestPaper(list, key) end
    if (ns.ThemeKey(key) or key == "eraCoins" or key == "questLevels" or key == "questListFontSize"
        or key == "questTextFontSize") and list and list:IsVisible() then Update() end
end)

-- For the dev addon's mapcombo probe: the panes, the rows shown, the picked quest.
function QM.State()
    if not list then return nil end
    local shown = 0
    for _, row in ipairs(rows) do
        if row:IsShown() then shown = shown + 1 end
    end
    return { list = list, detail = detail, rewards = rewards, track = track, rows = shown, picked = selectedID, timer = hasTimer }
end
