local _, ns = ...

-- The quest log's detail pane: the selected quest's text and rewards down the parchment. A window with a rewardChild
-- (the combined map's right page) takes the rewards there from its top; its textW sets the lines' width.

local QL = ns.QL

local TEXT_W = 285
-- Two reward buttons plus the gap span the text width; the 1.x button is 147 wide.
local REWARD_GAP, REWARD_W = 3, 147

local function FirstFont(...)
    for i = 1, select("#", ...) do
        local name = select(i, ...)
        if _G[name] then return name end
    end
    return "GameFontNormal"
end

local FONT_TITLE = FirstFont("QuestTitleFont", "QuestFont_Large", "GameFontNormalLarge")
local FONT_BODY = FirstFont("QuestFont", "QuestFontNormalSmall", "GameFontNormal")
local FONT_SMALL = FirstFont("QuestFontNormalSmall", "GameFontNormalSmall")
local INK_R, INK_G, INK_B = 0.18, 0.12, 0.06    -- parchment ink
-- A finished objective; lighter on a page a dark theme darkened.
local DONE, PALE_DONE = { 0.2, 0.2, 0.2 }, { 0.6, 0.6, 0.6 }
local function Ink() return ns.PageInk(INK_R, INK_G, INK_B) end
local function Done() return unpack(ns.PageDark() and PALE_DONE or DONE) end

-- The window FillDetail last wrote.
local frame

-- Pooled font strings and reward buttons per child frame (a window's text child, its rewards child).
local pools = setmetatable({}, { __mode = "k" })
local function Pool(child)
    local pool = pools[child]
    if not pool then
        pool = { strings = {}, used = 0, rewards = {}, rewardsUsed = 0 }
        pools[child] = pool
    end
    return pool
end

local function TextW() return frame.textW or TEXT_W end
-- A window with sizedText (the combined map's pages) writes in the fonts at the player's quest text size.
local function Font(name) return frame.sizedText and ns.QuestTextFont(name) or name end
local function RewardScale() return math.max(0.2, (TextW() - REWARD_GAP) / 2 / REWARD_W) end

local function DetailString(child, font, width, x, y, anchor, relPoint)
    local pool = Pool(child)
    pool.used = pool.used + 1
    local fs = pool.strings[pool.used]
    if not fs then
        fs = child:CreateFontString(nil, "ARTWORK")
        pool.strings[pool.used] = fs
    end
    fs:SetFontObject(font)
    fs:SetJustifyH("LEFT")
    fs:SetWidth(width)
    ns.SetPointOnce(fs, "TOPLEFT", anchor or child, relPoint or "TOPLEFT", x or 0, y or 0)
    fs:SetTextColor(Ink())
    fs:Show()
    return fs
end

local function RewardEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    pcall(GameTooltip.SetQuestLogItem, GameTooltip, self.rewardType, self.index, self.questID)
    GameTooltip:Show()
end

local function RewardClick(self)
    if IsModifiedClick("CHATLINK") and ChatFrameUtil and ChatFrameUtil.InsertLink then
        local ok, link = pcall(GetQuestLogItemLink, self.rewardType, self.index, self.questID)
        if ok and link then ChatFrameUtil.InsertLink(link) end
    end
end

-- The 1.x reward button at its native 147x41, scaled so two fit across the page.
local function RewardButton(child)
    local pool = Pool(child)
    pool.rewardsUsed = pool.rewardsUsed + 1
    local button = pool.rewards[pool.rewardsUsed]
    if not button then
        button = ns.RewardSlot(child, RewardEnter, RewardClick)
        pool.rewards[pool.rewardsUsed] = button
    end
    button:SetScale(RewardScale())
    button:Show()
    return button
end

local function ResetPool(child)
    local pool = child and pools[child]
    if not pool then return end
    for i = 1, pool.used do pool.strings[i]:Hide() end
    for i = 1, pool.rewardsUsed do pool.rewards[i]:Hide() end
    pool.used, pool.rewardsUsed = 0, 0
end

function QL.ResetDetail(window)
    window = window or frame
    if not window then return end
    ResetPool(window.detailChild)
    ResetPool(window.rewardChild)
end

local function Coins(copper) return ns.CoinText(copper) end

-- The scroll child spans the pane's top to the last piece; the bar scrolls the rest.
local function Fit(child, last, bar, paneH)
    local top, bottom = child:GetTop(), last and last:GetBottom()
    local height = (top and bottom) and (top - bottom + 12) or paneH
    child:SetHeight(math.max(height, paneH))
    bar:SetRange(math.max(0, height - paneH), 20)
end

-- Rewards under `last`, two per row, coins after the header (money alone still gets one).
local function RewardGrid(child, questID, last, kind, count, header, coins)
    if count <= 0 and not coins then return last end
    local label = DetailString(child, Font(FONT_SMALL), TextW(), 0, -5, last, "BOTTOMLEFT")
    label:SetText(header)
    last = label
    if coins then
        local line = DetailString(child, Font(FONT_SMALL), TextW(), 0, 0, label, "TOPLEFT")
        ns.SetPointOnce(line, "LEFT", label, "LEFT", (label:GetStringWidth() or 0) + 15, 0)
        line:SetText(coins)
    end
    local rowAnchor, scale = last, RewardScale()
    for i = 1, count do
        local button = RewardButton(child)
        button.rewardType, button.index, button.questID = kind, i, questID
        local name, texture, count2, _, itemID
        if kind == "choice" then
            name, texture, count2, _, _, itemID = GetQuestLogChoiceInfo(i, questID)
        else
            name, texture, count2, _, _, itemID = GetQuestLogRewardInfo(i, questID)
        end
        button.icon:SetTexture(texture)
        button.count:SetText((count2 or 0) > 1 and count2 or "")
        button.name:SetText(name or (itemID and ("item " .. itemID)) or "")
        -- 1.x showed reward names in white regardless of quality.
        button.name:SetTextColor(1, 1, 1)
        button:ClearAllPoints()
        -- Offsets are in the button's scaled units.
        if i % 2 == 1 then
            button:SetPoint("TOPLEFT", rowAnchor, "BOTTOMLEFT", 0, -4 / scale)
            rowAnchor = button
            last = button
        else
            button:SetPoint("TOPLEFT", rowAnchor, "TOPRIGHT", REWARD_GAP / scale, 0)
        end
    end
    return last
end

-- Rewards after `last` on the text's child, or from the top of the window's own rewards child: choices, fixed items
-- with money, then experience.
local function LayoutRewards(last, questID)
    local apart = frame.rewardChild
    local child = apart or frame.detailChild
    local numChoices = GetNumQuestLogChoices(questID, true) or 0
    local numRewards = GetNumQuestLogRewards(questID) or 0
    local money = GetQuestLogRewardMoney(questID) or 0
    local xp = GetQuestLogRewardXP and GetQuestLogRewardXP(questID) or 0
    if numChoices + numRewards + money + xp <= 0 then
        if apart then Fit(apart, nil, frame.rewardBar, frame.rewardH or 1) end
        return last
    end
    local title
    if apart then
        title = DetailString(child, Font(FONT_TITLE), TextW(), 5, -5)
    else
        title = DetailString(child, Font(FONT_TITLE), TextW(), 0, -10, last, "BOTTOMLEFT")
    end
    title:SetText(QUEST_REWARDS or "Rewards")
    local tail = title
    tail = RewardGrid(child, questID, tail, "choice", numChoices, REWARD_CHOICES or "Choose one of the following rewards:")
    tail = RewardGrid(child, questID, tail, "reward", numRewards,
        numChoices > 0 and (REWARD_ITEMS or "You will also receive:") or (REWARD_ITEMS_ONLY or "You will receive:"),
        money > 0 and Coins(money) or nil)
    if xp > 0 then
        local line = DetailString(child, Font(FONT_SMALL), TextW(), 0, -4, tail, "BOTTOMLEFT")
        line:SetText(string.format("%s: %s", REWARD_XP or "Experience", BreakUpLargeNumbers and BreakUpLargeNumbers(xp) or xp))
        tail = line
    end
    if apart then
        Fit(apart, tail, frame.rewardBar, frame.rewardH or 1)
        return last
    end
    return tail
end

-- Writes the page for info, a quest in the log; setHasTimer is the window's timer switch, called where the timer is read.
function QL.FillDetail(window, info, detailH, setHasTimer)
    frame = window
    local child = frame.detailChild
    local selectedID = info.questID
    C_QuestLog.SetSelectedQuest(selectedID)
    local questIndex = info.questLogIndex
    local textW = TextW()
    local fontTitle, fontBody, fontSmall = Font(FONT_TITLE), Font(FONT_BODY), Font(FONT_SMALL)

    local titleText = info.title or ""
    if C_QuestLog.IsFailed and C_QuestLog.IsFailed(selectedID) then
        titleText = titleText .. " - (" .. (FAILED or "Failed") .. ")"
    end
    local title = DetailString(child, fontTitle, textW, 5, -5)
    title:SetText(titleText)
    local last = title

    local description, objectivesText = GetQuestLogQuestText(questIndex)
    if objectivesText and objectivesText ~= "" then
        local objectives = DetailString(child, fontBody, textW - 10, 0, -5, last, "BOTTOMLEFT")
        objectives:SetText(objectivesText)
        last = objectives
    end

    local timeLeft = GetQuestLogTimeLeft and GetQuestLogTimeLeft()
    setHasTimer(timeLeft ~= nil)
    if timeLeft then
        local timer = DetailString(child, fontSmall, textW, 0, -10, last, "BOTTOMLEFT")
        timer:SetText((TIME_REMAINING or "Time Remaining:") .. " " .. SecondsToTime(timeLeft))
        last = timer
    end

    local numObjectives = GetNumQuestLeaderBoards(questIndex) or 0
    for i = 1, numObjectives do
        local text, kind, finished = GetQuestLogLeaderBoard(i, questIndex)
        if not text or text == "" then text = kind end
        local line = DetailString(child, fontSmall, textW, 0, i == 1 and -10 or -2, last, "BOTTOMLEFT")
        if finished then
            line:SetTextColor(Done())
            text = text .. " (" .. (COMPLETE or "Complete") .. ")"
        end
        line:SetText(text)
        last = line
    end

    local required = C_QuestLog.GetRequiredMoney and C_QuestLog.GetRequiredMoney(selectedID) or 0
    if required > 0 then
        local line = DetailString(child, fontSmall, textW, 0, numObjectives > 0 and -4 or -10, last, "BOTTOMLEFT")
        line:SetText((REQUIRED_MONEY or "Required Money:") .. " " .. Coins(required))
        if required > GetMoney() then line:SetTextColor(1, 0.1, 0.1) else line:SetTextColor(Done()) end
        last = line
    end

    if description and description ~= "" then
        local header = DetailString(child, fontTitle, textW, 0, -10, last, "BOTTOMLEFT")
        header:SetText(QUEST_DESCRIPTION or "Description")
        local body = DetailString(child, fontBody, textW - 10, 0, -5, header, "BOTTOMLEFT")
        body:SetText(description)
        last = body
    end

    last = LayoutRewards(last, selectedID)
    Fit(child, last, frame.detailBar, detailH)
end
