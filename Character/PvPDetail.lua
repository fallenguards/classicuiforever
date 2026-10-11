local _, ns = ...

-- PvP tab side panel: the arrow widens the sheet as on the character tab. The page reads what the game's own detail
-- pane reads: the rank, the season's rank points and cap, the next rank with rewards and where they are sold.

local T = ns.sheet

local RANK_FACTION = 2800
local PAD, ICON, ICON_GAP = 8, 28, 6
-- Column 14 in from each inset edge, as the game's pane: ragged lines leave the block centered.
local SIDE = 14
-- The game's pane in 1.x pieces. Rule under the rank: the 1.x stat box's top edge, 4 rows, cut inside its corners'
-- curves (x 6 to 109 of 128 run straight) and stretched across the column.
local RULE_H, RULE_LEFT, RULE_RIGHT = 4, 8 / 128, 104 / 128
-- Next rewards heading on the iron inset box; the reward's icon in the 1.x item slot ring (64 for a 37 icon), 2 in
-- like the game's slot.
local BANNER_H, BANNER_EDGE = 32, 16
local RING, ICON_X = math.floor(64 * ICON / 37 + 0.5), 2
local EVENTS = { "UPDATE_FACTION", "MAJOR_FACTION_RENOWN_LEVEL_CHANGED" }
local GOLD, WHITE, GRAY = { 1, 0.82, 0 }, { 1, 1, 1 }, { 0.5, 0.5, 0.5 }

local pane, page, toggle
local open, seen, restored = false, false, false
local lines, icons, rings, used = {}, {}, {}, 0
local rule, banner

-- The rank's title for the player's faction and sex, as the game names it.
local function RankName(rank)
    if rank <= 0 then return _G.PVP_RANK_0_NAME or "" end
    local side = UnitFactionGroup("player") == "Alliance" and 1 or 0
    local key = string.format("PVP_RANK_%d_%d", Enum.PvPRanks.Rank_1 + rank - 1, side)
    return GetText(key, UnitSex("player")) or ""
end

local function Format(text, ...)
    if type(text) ~= "string" then return "" end
    return string.format(text, ...)
end

-- Rank points from nothing to a rank.
local function Total(rank)
    if not rank then return 0 end
    return C_MajorFactions.GetTotalReputationForRenownLevel(RANK_FACTION, rank) or 0
end

-- The rule across the column, gap under the last line.
local function Rule(gap)
    if not rule then
        rule = page:CreateTexture(nil, "BORDER")
        ns.SetTex(rule, "charStatBox")
        rule:SetTexCoord(RULE_LEFT, RULE_RIGHT, 0, RULE_H / 128)
        rule:SetHeight(RULE_H)
    end
    ns.SetTwoPointsIf(rule, "TOPLEFT", page, "TOPLEFT", 0, -(page.y + gap), "TOPRIGHT", page, "TOPRIGHT", 0, -(page.y + gap))
    rule:Show()
    page.y = page.y + gap + RULE_H
end

-- A heading on the iron inset box across the column, its words on the box (a page line sat under its floor).
local function Heading(text, gap)
    if not banner then
        banner = ns.SkillInsetBox(page, BANNER_EDGE)
        banner:SetHeight(BANNER_H)
        banner.label = banner:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        banner.label:SetPoint("LEFT", banner, "LEFT", BANNER_EDGE / 2, 1)
        banner.label:SetPoint("RIGHT", banner, "RIGHT", -BANNER_EDGE / 2, 1)
        banner.label:SetWordWrap(false)
    end
    ns.SetPointOnce(banner, "TOPLEFT", page, "TOPLEFT", 0, -(page.y + gap))
    banner:SetWidth(page.width)
    banner.label:SetText(text)
    banner:Show()
    page.y = page.y + gap + BANNER_H
end

-- One wrapped line under the last, gap below it; icon: a reward's picture in its ring left of the text (false: none
-- it has).
local function Add(text, font, color, gap, center, icon)
    used = used + 1
    local line = lines[used]
    if not line then
        line = page:CreateFontString(nil, "ARTWORK")
        line:SetWordWrap(true)
        lines[used] = line
        icons[used] = page:CreateTexture(nil, "ARTWORK")
        icons[used]:SetSize(ICON, ICON)
        icons[used]:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        rings[used] = page:CreateTexture(nil, "OVERLAY")
        ns.SetTex(rings[used], "slotNormal")
        rings[used]:SetSize(RING, RING)
        rings[used]:SetPoint("CENTER", icons[used], "CENTER")
    end
    local tex = icons[used]
    local inset = icon and (ICON_X + ICON + ICON_GAP) or 0
    line:SetFontObject(font)
    line:SetTextColor(color[1], color[2], color[3])
    line:SetJustifyH(center and "CENTER" or "LEFT")
    line:SetWidth(page.width - inset)
    line:SetText(text)
    local height = line:GetStringHeight()
    if icon then
        tex:SetTexture(icon)
        ns.SetPointOnce(tex, "TOPLEFT", page, "TOPLEFT", ICON_X, -(page.y + gap))
        ns.SetPointOnce(line, "LEFT", tex, "RIGHT", ICON_GAP, 0)
        height = math.max(height, ICON)
    else
        ns.SetPointOnce(line, "TOPLEFT", page, "TOPLEFT", 0, -(page.y + gap))
    end
    tex:SetShown(icon and true or false)
    rings[used]:SetShown(icon and true or false)
    line:Show()
    page.y = page.y + gap + height
end

-- The first rank above the player's that pays out, its rewards and their vendor.
local function Rewards(rank, top)
    for level = rank + 1, top do
        local rewards = C_MajorFactions.GetRenownRewardsForLevel(RANK_FACTION, level)
        if rewards and #rewards > 0 then
            Heading(Format(_G.PVP_RANK_NEXT_REWARD, level), 14)
            for _, reward in ipairs(rewards) do
                if reward.description then Add(reward.description, "GameFontNormalSmall", GOLD, 10, false, reward.icon) end
            end
            local horde = UnitFactionGroup("player") == "Horde"
            Add((horde and _G.PVP_RANK_REWARDS_VENDOR_HORDE or _G.PVP_RANK_REWARDS_VENDOR_ALLIANCE) or "",
                "GameFontHighlightSmall", WHITE, 10)
            return
        end
    end
end

local function Fill()
    if not page or not seen then return end
    used, page.y = 0, 0
    if rule then rule:Hide() end
    if banner then banner:Hide() end
    local read = C_MajorFactions and C_MajorFactions.GetMajorFactionProgressionInfo
    local info = read and read(RANK_FACTION)
    if not info then
        Add(_G.PVP_RANK_DETAIL_UNAVAILABLE or "", "GameFontHighlightSmall", GRAY, 0, true)
    else
        local rank, top = info.renownLevel or 0, info.maxLevel or 0
        Add(RankName(rank), "GameFontNormal", GOLD, 0, true)
        if rank > 0 then Add(Format(_G.PVP_RANK_NUMBER, rank), "GameFontHighlightSmall", WHITE, 2, true) end
        Rule(4)
        Add(Format(_G.PVP_RANK_SEASON_RANKUP_DESCRIPTION, Total(top), top), "GameFontHighlightSmall", WHITE, 6)
        local mine = Total(rank) + (info.renownReputationEarned or 0)
        local cap, before = Total(info.currentWeekProgressiveMaxLevel), Total(info.previousWeekProgressiveMaxLevel)
        if mine > 0 and cap == 0 then
            Add(Format(_G.PVP_RANK_SEASON_PROGRESS_NO_MAX, mine), "GameFontHighlightSmall", WHITE, 8)
        elseif mine > 0 then
            Add(Format(_G.PVP_RANK_SEASON_PROGRESS, mine, cap), "GameFontHighlightSmall", WHITE, 8)
        end
        if cap - before > 0 then Add(Format(_G.PVP_RANK_WEEKLY_CAP_INCREASE, cap - before), "GameFontNormalSmall", GOLD, 4) end
        Rewards(rank, top)
    end
    for i = used + 1, #lines do
        lines[i]:Hide()
        icons[i]:Hide()
        rings[i]:Hide()
    end
end

local function QueueFill()
    ns.Sched.NextFrame("sheet.pvpFill", Fill)
end

local function Sync()
    if not pane then return end
    pane:SetShown(T.active and open and true or false)
    ns.SidePanelArrowFace(toggle, open)
    ns.SetShownIf(toggle, T.active and true or false)
end

-- Open or shut is kept (db.pvpPaneOpen), apart from the character tab's panel.
local function SetOpen(state)
    open = state and true or false
    if ns.db then ns.db.pvpPaneOpen = open end
    Sync()
    PlaySound(open and SOUNDKIT.IG_CHARACTER_INFO_OPEN or SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
    ns.SignalSheetLaid()
end

-- The sheet's close button and title move out with the panel.
local function Seen(state)
    seen = state
    ns.PlaceSheetChrome()
end

local function Build()
    local tab = PVPRankFrame
    if pane or not tab then return end
    local innerW, innerTop, innerBottom
    pane, innerW, innerTop, innerBottom = ns.SidePanel("ForeverClassicUIPvPPane", tab)
    page = ns.NewFrame("Frame", nil, pane)
    page:SetPoint("TOPLEFT", pane, "TOPLEFT", SIDE, innerTop - PAD)
    page:SetPoint("BOTTOMRIGHT", pane, "TOPLEFT", innerW - SIDE, innerBottom + PAD)
    page.width, page.y = innerW - 2 * SIDE, 0
    pane:SetScript("OnShow", function()
        Seen(true)
        ns.RegisterEvents(pane, EVENTS)
        Fill()
    end)
    pane:SetScript("OnHide", function()
        pane:UnregisterAllEvents()
        Seen(false)
    end)
    pane:SetScript("OnEvent", QueueFill)
    toggle = ns.SidePanelArrow(tab, "ForeverClassicUIPvPToggle", tab:GetFrameLevel() + 10,
        function() return open end, function() SetOpen(not open) end)
end

-- Read by the sheet through the side panel's extent.
function ns.PvPPaneSeen()
    return T.active and open and seen
end

-- With the PvP tab's skin: on apply and on each showing.
function T.PvPPane()
    if not restored and ns.db then
        restored = true
        open = ns.db.pvpPaneOpen == true
    end
    Build()
    Sync()
end

function T.PvPPaneOff()
    if pane then pane:Hide() end
    if toggle then toggle:Hide() end
end
