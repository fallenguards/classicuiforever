local _, ns = ...
local L = ns.L

-- Lower section of the old skills tab (bar, words, unlearn), in a frame of ours under the list. The client's own detail
-- pane stays as the client keeps it: showing or laying it from here ran its refresh in our name and marked what the
-- client reads there, and a weapon skill rising in a fight then stopped the client's own sums (#295).

local T = ns.sheet
local Take, Own = T.Take, T.Own
local SkinListEntry = T.SkinListEntry

local DETAIL_H = 124
T.DETAIL_H = DETAIL_H
local FOOT_H = 26          -- the grey strip with the Close button
local SCROLL_COLUMN = 22   -- the description's scroll bar column at the right
-- The words' scroll bar in its column, each piece by itself: from the column's left (+ right), the up arrow's top
-- from the column's top and the down arrow's foot from its bottom (+ up), the knob's two ends the same way.
local WORDS_SCROLL_X = 7
local WORDS_SCROLL_UP_ARROW_Y = -5
local WORDS_SCROLL_DOWN_ARROW_Y = 4
local WORDS_SCROLL_KNOB_TOP = -18
local WORDS_SCROLL_KNOB_BOTTOM = 17
local WORDS_WHEEL = 24

local CANCEL = "Interface\\Buttons\\CancelButton-"
local CANCEL_UP, CANCEL_DOWN, CANCEL_HIGHLIGHT = CANCEL .. "Up", CANCEL .. "Down", CANCEL .. "Highlight"
-- The art is mostly margin: the mouse is taken over the square only.
local UNLEARN = { set = "raw", add = true, hit = { 9, 9, 9, 9 } }
local FOOT_STONE = { shade = { 1.25, 1.2, 1.1 } }

ns.Popup("FCUI_UNLEARN_SKILL", {
    text = UNLEARN_SKILL_PROMPT or "Unlearn %s?",
    button1 = YES or "Yes",
    button2 = NO or "No",
    OnAccept = function(_, skillID)
        if C_SkillInfo and C_SkillInfo.AbandonSkill and skillID then pcall(C_SkillInfo.AbandonSkill, skillID) end
    end,
    showAlert = 1,
    preferredIndex = false,
})

-- The picked skill, as the client's own detail pane reads it.
local function SelectedSkill()
    if not (C_SkillInfo and C_SkillInfo.GetSelectedSkill and C_SkillInfo.GetSkillLineInfo) then return nil end
    local ok, index = pcall(C_SkillInfo.GetSelectedSkill)
    if not ok or not index or index <= 0 then return nil end
    local fine, info = pcall(C_SkillInfo.GetSkillLineInfo, index)
    if not fine or type(info) ~= "table" or info.isHeader then return nil end
    return info
end

-- Forever's weapon skill breakdown (its SkillsFrame.lua math and strings) under the words, where the client's own rows
-- overran the window: hit and crit against an equal-level enemy and a raid boss, glancing blows in melee.
local RANKS_PER_LEVEL, BOSS_LEVELS = 5, 3
-- Skill line -> ranged.
local WEAPON_LINES = { [43] = false, [44] = false, [45] = true, [46] = true, [54] = false, [55] = false, [136] = false,
    [160] = false, [172] = false, [173] = false, [176] = true, [226] = true, [228] = true, [229] = false, [162] = false,
    [3014] = false }

local function SkillGap(levels, skill)
    return ((UnitLevel("player") or 1) + levels) * RANKS_PER_LEVEL - skill
end

local function Signed(value)
    if value == 0 then value = 0 end
    local text = string.format("%.2f%%", value)
    return value > 0 and "+" .. text or text
end

local function GlancingChance(skill)
    skill = math.min((UnitLevel("player") or 1) * RANKS_PER_LEVEL, skill)
    return math.max(-100, math.min(100, (0.02 * SkillGap(BOSS_LEVELS, skill) + 0.1) * 100))
end

local function GlancingPenalty(skill)
    local gap = SkillGap(BOSS_LEVELS, skill)
    local low = 1.30 - 0.05 * gap + (gap > 10 and 0.1 or 0)
    low = math.max(0.01, math.min(low, 0.91))
    local high = 1.20 - 0.03 * gap + (gap > 10 and 0.1 or 0)
    high = math.min(0.99, math.max(high, 0.20))
    return 100 - math.max(0, math.min(1, (low + high) / 2)) * 100
end

local function Heading(text)
    return "|cffffffff" .. text .. "|r"
end

local function Row(text)
    return NORMAL_FONT_COLOR and NORMAL_FONT_COLOR:WrapTextInColorCode(text) or text
end

-- The lines under a weapon skill's words, or nil.
local function WeaponDetail(info)
    local ranged = info and WEAPON_LINES[info.skillID]
    if ranged == nil or not (ns.db and ns.db.weaponSkillDetail ~= false) then return nil end
    local skill = (info.rank or 0) + (info.modifier or 0)
    local same, boss = Signed(SkillGap(0, skill) * -0.04), Signed(SkillGap(BOSS_LEVELS, skill) * -0.04)
    local sameText = ranged and WEAPON_SKILL_DETAIL_SAME_LEVEL_RANGED or WEAPON_SKILL_DETAIL_SAME_LEVEL
    local bossText
    if ranged then
        bossText = WEAPON_SKILL_DETAIL_BOSS_RANGED and WEAPON_SKILL_DETAIL_BOSS_RANGED:format(boss, boss)
    else
        bossText = WEAPON_SKILL_DETAIL_BOSS and WEAPON_SKILL_DETAIL_BOSS:format(boss, boss,
            string.format("%.0f%%", GlancingChance(skill)), string.format("%.0f%%", GlancingPenalty(skill)))
    end
    if not (sameText and bossText and WEAPON_SKILL_DETAIL_SAME_LEVEL_HEADER and WEAPON_SKILL_DETAIL_BOSS_HEADER) then
        return nil
    end
    return table.concat({ Heading(WEAPON_SKILL_DETAIL_SAME_LEVEL_HEADER), Row(sameText:format(same, same)), "",
        Heading(WEAPON_SKILL_DETAIL_BOSS_HEADER), Row(bossText) }, "\n")
end

-- The old short line: the client's string of that name is now the whole warning.
local function UnlearnTip()
    local line = UNLEARN_SKILL_TOOLTIP
    if type(line) ~= "string" or #line > 40 then line = L["CHAR_UNLEARN_THIS_PROFESSION"] end
    return line
end
local UNLEARN_TIP = { text = UnlearnTip, r = 1, g = 0.82, b = 0 }

local function UnlearnClick()
    local picked = SelectedSkill()
    if picked and picked.isAbandonable and StaticPopup_Show then
        StaticPopup_Show("FCUI_UNLEARN_SKILL", picked.name, nil, picked.skillID)
    end
end

local function CloseClick()
    if CharacterFrame then ns.HidePanel(CharacterFrame) end
end

-- The section's pieces, made once.
local S

-- The words' box and its scroll range; Era's text boxes kept the knob at the top with nothing to scroll.
local function WordsRange()
    local tall = S.words:GetStringHeight() or 0
    S.child:SetSize(math.max(1, S.scroll:GetWidth()), math.max(1, tall))
    S.wordsBar:SetRange(math.max(0, tall - S.scroll:GetHeight()), WORDS_WHEEL)
    local knob = S.wordsBar:GetThumbTexture()
    if knob then knob:Show() end
end

local function Section()
    if S then return S end
    S = {}
    local holder = Own(ns.NewFrame("Frame", nil, CharacterFrame))
    holder:SetClipsChildren(true)
    S.holder = holder
    -- A stone bar between the list and the section.
    S.divider = ns.StoneBar(CharacterFrame)
    if S.divider then Own(S.divider) end
    S.host = ns.NewFrame("Frame", nil, holder)

    -- Measure only, never drawn: the words' box, clear of the scroll column and grey foot.
    local box = holder:CreateTexture(nil, "BACKGROUND", nil, 1)
    box:SetColorTexture(0, 0, 0, 0)
    box:SetPoint("TOPLEFT", holder, "TOPLEFT", 2, -38)
    box:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -SCROLL_COLUMN, FOOT_H + 2)
    box:Hide()
    local scroll = ns.NewFrame("ScrollFrame", nil, holder)
    scroll:SetPoint("TOPLEFT", box, "TOPLEFT", 6, -4)
    scroll:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -6, 4)
    local child = ns.NewFrame("Frame", nil, scroll)
    child:SetSize(1, 1)
    scroll:SetScrollChild(child)
    local words = child:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    words:SetJustifyH("LEFT")
    words:SetJustifyV("TOP")
    words:SetPoint("TOPLEFT", child, "TOPLEFT", 0, 0)
    words:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, 0)
    S.scroll, S.child, S.words = scroll, child, words

    -- The list's scroll column continues down to the grey foot; on the window, as the section clips.
    local column = Own(ns.NewFrame("Frame", nil, CharacterFrame))
    column:SetWidth(31)
    local top = column:CreateTexture(nil, "BACKGROUND", nil, 1)
    ns.SetTex(top, "charScrollBar")
    top:SetPoint("TOPLEFT", column, "TOPLEFT", 0, 0)
    top:SetPoint("TOPRIGHT", column, "TOPRIGHT", 0, 0)
    local bottom = column:CreateTexture(nil, "BACKGROUND", nil, 1)
    ns.SetTex(bottom, "charScrollBar")
    bottom:SetPoint("BOTTOMLEFT", column, "BOTTOMLEFT", 0, 0)
    bottom:SetPoint("BOTTOMRIGHT", column, "BOTTOMRIGHT", 0, 0)
    column.top, column.bottom = top, bottom
    S.column = column
    -- On the column, not the section: the section clips, and the up arrow stands above its top in the column's head.
    local bar = ns.ClassicScrollBar(column, scroll, function(value) scroll:SetVerticalScroll(value) end)
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", column, "TOPLEFT", WORDS_SCROLL_X, WORDS_SCROLL_KNOB_TOP)
    bar:SetPoint("BOTTOMLEFT", column, "BOTTOMLEFT", WORDS_SCROLL_X, WORDS_SCROLL_KNOB_BOTTOM)
    ns.SetPointOnce(bar.up, "TOPLEFT", column, "TOPLEFT", WORDS_SCROLL_X, WORDS_SCROLL_UP_ARROW_Y)
    ns.SetPointOnce(bar.down, "BOTTOMLEFT", column, "BOTTOMLEFT", WORDS_SCROLL_X, WORDS_SCROLL_DOWN_ARROW_Y)
    S.wordsBar = bar
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(_, delta) bar:SetValue(bar:GetValue() - delta * WORDS_WHEEL) end)
    scroll:SetScript("OnSizeChanged", WordsRange)

    -- The old skills window's foot: grey stone with Close at its right.
    local foot = ns.NewFrame("Frame", nil, holder)
    local stone = ns.TileTex(foot:CreateTexture(nil, "BACKGROUND", nil, 2), "rockBg", FOOT_STONE)
    stone:SetAllPoints(foot)
    local line = foot:CreateTexture(nil, "BORDER")
    line:SetColorTexture(0.52, 0.48, 0.40, 1)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", foot, "TOPLEFT", 0, 0)
    line:SetPoint("TOPRIGHT", foot, "TOPRIGHT", 0, 0)
    local close = ns.PanelButton(foot, CLOSE or "Close", 80)
    close:SetPoint("RIGHT", foot, "RIGHT", -2, 0)
    close:SetScript("OnClick", CloseClick)
    foot:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 0, 0)
    foot:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 0, 0)
    foot:SetHeight(FOOT_H)

    local unlearn = ns.NewFrame("Button", nil, holder)
    unlearn:SetSize(32, 32)
    ns.DressStates(unlearn, CANCEL_UP, CANCEL_DOWN, nil, CANCEL_HIGHLIGHT, UNLEARN)
    ns.AttachTip(unlearn, UNLEARN_TIP)
    unlearn:SetScript("OnClick", UnlearnClick)
    S.unlearn = unlearn
    return S
end

-- With the tab: the section, its divider and its column.
function T.HideSkillDetail()
    if not S then return end
    S.holder:Hide()
    S.column:Hide()
    if S.divider then S.divider:Hide() end
end

local function SkinSkillDetail()
    -- Also reached from the client's pane and tab, which outlive the sheet.
    if not T.active then return end
    local skills = SkillsFrame
    local detail = skills and skills.SkillDetailFrame
    if not detail or not CharacterFrame then return end
    -- Seen, not the tab's flag: closed on Skills the flag stays on, and C switches tabs before the window shows (#301).
    local onSkills = skills:IsVisible() and true or false
    local s = Section()
    local holder = s.holder
    -- Full width inside the art; 2 taller so the grey foot meets the window's bottom edge.
    ns.SetTwoPointsIf(holder, "BOTTOMLEFT", CharacterFrame, "BOTTOMLEFT", 20, 84,
        "BOTTOMRIGHT", CharacterFrame, "BOTTOMRIGHT", -44, 84)
    holder:SetHeight(DETAIL_H + 2)
    holder:SetFrameLevel(CharacterFrame:GetFrameLevel() + 6)

    local divider = s.divider
    if divider then
        divider:ClearAllPoints()
        divider:SetPoint("BOTTOM", holder, "TOP", 0, 6)
        divider:SetPoint("LEFT", holder, "LEFT", -2, 0)
        divider:SetPoint("RIGHT", holder, "RIGHT", -SCROLL_COLUMN - 2, 0)
        divider:SetShown(onSkills)
    end

    -- The client's rank bar, carried in: the client fills it wherever it hangs. The name goes on it, as in the list.
    local info = SelectedSkill()
    local bar = detail.RankBar
    if bar then
        s.host.Content = s.host.Content or { SkillsBar = bar }
        SkinListEntry(s.host, "SkillsBar")
        local name = bar.fcui and bar.fcui.name
        if name then name:SetText(info and info.name or "") end
        Take(bar, "parent")
        if bar:GetParent() ~= holder then bar:SetParent(holder) end
        -- Narrower than the list's bars: the unlearn button stands at its end.
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", holder, "TOPLEFT", 46, -12)
        bar:SetPoint("RIGHT", holder, "RIGHT", -70, 0)
        -- Its fill was sized for the width it had before this move.
        T.FitFill(bar)
        ns.SetPointOnce(s.unlearn, "LEFT", bar, "RIGHT", 0, 0)
    else
        ns.SetPointOnce(s.unlearn, "TOPRIGHT", holder, "TOPRIGHT", -8, -10)
    end

    -- The skill's words, a weapon's hit tables under them; back at the top for another skill.
    local text = info and info.description
    if type(text) ~= "string" then text = "" end
    local extra = text ~= "" and WeaponDetail(info)
    s.words:SetText(extra and (text .. "\n\n" .. extra) or text)
    local id = info and info.skillID
    if s.shown ~= id then
        s.shown = id
        s.wordsBar:SetValue(0)
    end

    local column = s.column
    -- Grey foot up to the divider's top, meeting the list track's foot.
    local tall = DETAIL_H + 2 - FOOT_H + 10
    local half = math.floor(tall / 2)
    column:SetFrameLevel(holder:GetFrameLevel() + 1)
    -- 8 left of the list's bar, measured: the list is a scaled frame.
    local x = -68
    local listBar = skills.ScrollBar
    local barLeft, right = listBar and listBar:GetLeft(), CharacterFrame:GetRight()
    if barLeft and right then x = barLeft - 8 - right end
    ns.SetPointOnce(column, "BOTTOMLEFT", CharacterFrame, "BOTTOMRIGHT", x, 84 + FOOT_H)
    column:SetHeight(tall)
    column.top:SetHeight(half)
    column.top:SetTexCoord(0, 0.484375, 0, half / 256)
    column.bottom:SetHeight(tall - half)
    column.bottom:SetTexCoord(0.515625, 1, (108 - (tall - half)) / 256, 108 / 256)
    column:SetShown(onSkills)

    s.unlearn:SetShown(info ~= nil and info.isAbandonable == true)
    holder:SetShown(onSkills)
    WordsRange()
end
T.SkinSkillDetail = SkinSkillDetail
ns.OnToggle(function(key)
    if key == "weaponSkillDetail" then ns.SafeCall(SkinSkillDetail) end
end)
