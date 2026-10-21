local _, ns = ...
if not ns.OnForever() then return end

-- A search over the Stats tab (#211): typing swaps the game's list for ours of the matching statistics under their
-- categories, read from the same calls; the game's list is never written. Cleared, its list comes back.

local T = ns.sheet
local L = ns.L
local ROW_H, VISIBLE, PAD, VALUE_W = 20, 17, 10, 70
-- Under the level line, clear of the portrait ring (81 across); the list where the game's stands (CharacterLists).
local BOX_LEFT, BOX_RIGHT, BOX_Y = 90, 280, -53
local LIST_X, LIST_TOP, LIST_RIGHT, LIST_BOTTOM = 12, -76, -66, 86
local S = { all = {}, shown = {}, rows = {}, stale = true }
local GetStatisticsCategoryList, GetStatistic = _G.GetStatisticsCategoryList, _G.GetStatistic

local function Wanted()
    local stats = _G.StatisticsFrame
    return stats ~= nil and stats:IsVisible() and T.active and ns.db.statsSearch == true
end

-- Every statistic with its category's name: rebuilt on a criteria change while ours shows.
local function Gather()
    wipe(S.all)
    for _, category in ipairs(GetStatisticsCategoryList() or {}) do
        local title = GetCategoryInfo(category) or ""
        local head = { isHead = true, name = title, low = title:lower() }
        S.all[#S.all + 1] = head
        for i = 1, GetCategoryNumAchievements(category) or 0 do
            local quantity, skip, id = GetStatistic(category, i)
            if not skip and id then
                local name = select(2, GetAchievementInfo(id)) or _G.UNKNOWN or "?"
                local value = tonumber(quantity)
                S.all[#S.all + 1] = { name = name, low = name:lower(), cat = head,
                    value = (value and value > 0) and tostring(value) or "--" }
            end
        end
    end
    S.stale = false
end

local function Draw(offset)
    for i, row in ipairs(S.rows) do
        local entry = S.shown[offset + i]
        row:SetShown(entry ~= nil)
        if entry then
            row.name:SetFontObject(entry.isHead and "GameFontNormal" or "GameFontHighlight")
            row.name:SetText(entry.name)
            row.value:SetText(entry.isHead and "" or entry.value)
        end
    end
end

-- A category's own name shows all of it; else each match under its category.
local function Filter()
    local text = (S.box:GetText():lower():gsub("^%s+", ""):gsub("%s+$", ""))
    wipe(S.shown)
    local lastHead
    for _, entry in ipairs(S.all) do
        if entry.cat and (entry.low:find(text, 1, true) or entry.cat.low:find(text, 1, true)) then
            if entry.cat ~= lastHead then
                lastHead = entry.cat
                S.shown[#S.shown + 1] = lastHead
            end
            S.shown[#S.shown + 1] = entry
        end
    end
    S.bar:SetValue(0)
    S.bar:SetRange(#S.shown - VISIBLE)
    Draw(0)
end

-- The game's list and bar make way while a search is typed.
local function Searching(on)
    local stats = _G.StatisticsFrame
    if stats.ScrollBox then ns.SetShownIf(stats.ScrollBox, not on) end
    if stats.ScrollBar then ns.SetShownIf(stats.ScrollBar, not on) end
    ns.SetShownIf(S.list, on)
end

local function TextChanged(box)
    local blank = box:GetText() == ""
    box.hint:SetShown(blank)
    box.clear:SetShown(not blank)
    if not blank and S.stale then Gather() end
    Searching(not blank)
    if not blank then Filter() end
end

local function RowTip(row)
    if not row.name:IsTruncated() then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetText(row.name:GetText())
    GameTooltip:Show()
end

local function Build(stats)
    local box = ns.SearchBox(stats, BOX_RIGHT - BOX_LEFT, L["STATS_SEARCH"])
    ns.SetTwoPointsIf(box, "TOPLEFT", CharacterFrame, "TOPLEFT", BOX_LEFT, BOX_Y,
        "TOPRIGHT", CharacterFrame, "TOPLEFT", BOX_RIGHT, BOX_Y)
    box:SetScript("OnTextChanged", TextChanged)
    S.box = box
    local list = ns.NewFrame("Frame", nil, stats)
    list:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", LIST_X, LIST_TOP)
    list:SetPoint("BOTTOMRIGHT", CharacterFrame, "BOTTOMRIGHT", LIST_RIGHT, LIST_BOTTOM)
    list:Hide()
    S.list = list
    for i = 1, VISIBLE do
        local row = ns.NewFrame("Frame", nil, list)
        row:SetHeight(ROW_H)
        row:SetPoint("TOPLEFT", list, "TOPLEFT", PAD, -(i - 1) * ROW_H)
        row:SetPoint("TOPRIGHT", list, "TOPRIGHT", -PAD, -(i - 1) * ROW_H)
        row.value = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        row.value:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        row.value:SetWidth(VALUE_W)
        row.value:SetJustifyH("RIGHT")
        row.name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        row.name:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.name:SetPoint("RIGHT", row.value, "LEFT", -8, 0)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)
        row:SetScript("OnEnter", RowTip)
        row:SetScript("OnLeave", GameTooltip_Hide)
        S.rows[i] = row
    end
    S.bar = ns.ClassicScrollBar(list, list, function(value) Draw(math.floor(value + 0.5)) end)
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta) S.bar:SetValue(S.bar:GetValue() - delta) end)
    -- Values change as the player plays: the next search reads them again.
    local watch = ns.EventFrame({}, function()
        S.stale = true
        if list:IsShown() then
            Gather()
            Filter()
        end
    end)
    ns.Sched.OnVisible(list, "stats.criteria", function(shown)
        if shown then watch:RegisterEvent("CRITERIA_UPDATE") else watch:UnregisterAllEvents() end
    end)
end

-- Shown with the tab while the sheet and the option are on; a shut tab starts clear.
local function Sync()
    local stats = _G.StatisticsFrame
    if not stats then return end
    local want = Wanted()
    if want and not S.box then Build(stats) end
    if not S.box then return end
    if not want and S.box:GetText() ~= "" then S.box:SetText("") end
    ns.SetShownIf(S.box, want)
end

local function Hook()
    local stats = _G.StatisticsFrame
    if not stats or S.hooked then return end
    S.hooked = true
    ns.Sched.OnVisible(stats, "stats.search", function(shown)
        S.stale = true
        Sync()
        if not shown and S.box and S.box:GetText() ~= "" then S.box:SetText("") end
    end)
    Sync()
end

ns.EventFrame("ADDON_LOADED", Hook)
Hook()

ns.OnToggle(function(key)
    if key == "statsSearch" or key == "characterSheet" then Sync() end
end)
