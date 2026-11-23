local _, ns = ...
local L = ns.L

-- The Legacy window's challenges page as Era's Skills tab (UI/EraSkills.lua): the challenge categories as its folding
-- sections, nested as the game's own window nests them, each challenge a skill bar of its progress, the picked one in
-- the detail pane; a search line and a filter beside the All tab. Read from the client's achievement data.

local LG = ns.legacy

local POINTS_CURRENCY = LG.POINTS_CURRENCY
-- Window coordinates beside Era's All tab (it ends near 132).
local SEARCH_X, SEARCH_Y, SEARCH_W = 142, -50, 110
local FILTER_X, FILTER_Y, FILTER_W = 258, -47, 82
local STEP_DONE, STEP_OPEN = "|cff1aff1a", "|cff808080"
-- Sections under sections, as deep as read: the client's run two (Classes over each class).
local MAX_DEPTH = 4

local page
local lines, collapsed = {}, {}
-- Every section header with a challenge left, shown or folded away under another (the All tab folds them all).
local sections = {}
local selected
local query = ""
local words = {}
local show = { completed = true, incomplete = true }

-- Legacy Points a challenge gives; nil when the client cannot say.
local function PointsFor(id)
    local get = C_Traits and C_Traits.GetTraitCurrencyForAchievement
    if not get then return nil end
    local ok, points = pcall(get, POINTS_CURRENCY, id)
    return ok and type(points) == "number" and points or nil
end

-- How far along a challenge is: one counted step by its count, else its steps done of all.
local function Progress(id, completed)
    local count = GetAchievementNumCriteria and GetAchievementNumCriteria(id) or 0
    if count == 1 then
        local _, _, done, quantity, required = GetAchievementCriteriaInfo(id, 1)
        if type(required) == "number" and required > 1 and type(quantity) == "number" then
            return math.min(quantity, required), required
        end
        return (done or completed) and 1 or 0, 1
    end
    if count == 0 then return completed and 1 or 0, 1 end
    local done = 0
    for index = 1, count do
        if select(3, GetAchievementCriteriaInfo(id, index)) then done = done + 1 end
    end
    return done, count
end

local function DoneText(line)
    local date = FormatShortDate and line.day and FormatShortDate(line.day, line.month, line.year)
        or (line.month and string.format("%d/%d/%02d", line.month, line.day, line.year)) or ""
    return string.format(L["LEGACY_COMPLETED_ON"], date)
end

-- The detail's words: the description, then each step in green once done.
local function Words(line)
    local parts = { line.description or "" }
    local count = GetAchievementNumCriteria and GetAchievementNumCriteria(line.id) or 0
    if count > 1 then
        parts[#parts + 1] = ""
        for index = 1, count do
            local text, _, done = GetAchievementCriteriaInfo(line.id, index)
            if type(text) == "string" and text ~= "" then parts[#parts + 1] = (done and STEP_DONE or STEP_OPEN) .. text .. "|r" end
        end
    end
    if line.completed then
        parts[#parts + 1] = ""
        parts[#parts + 1] = STEP_DONE .. DoneText(line) .. "|r"
    end
    return table.concat(parts, "\n")
end

-- The detail's points line; nil when the client cannot say.
local function Cost(line)
    return line.points and string.format(L["LEGACY_POINTS"], "|cffffffff" .. line.points .. "|r") or nil
end

-- All a challenge shows, lowered, for the search: its sections (path), name, points, words, every step and its date.
local function SearchText(item, path)
    local parts = { path, item.name, Cost(item) or "", Words(item) }
    for index = 1, GetAchievementNumCriteria and GetAchievementNumCriteria(item.id) or 0 do
        local step = GetAchievementCriteriaInfo(item.id, index)
        if type(step) == "string" and not ns.IsSecret(step) then parts[#parts + 1] = step end
    end
    return (table.concat(parts, "\n"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):lower())
end

-- Each word of the search somewhere in what the challenge shows: "dungeons" keeps all of Dungeons.
local function Found(item, path)
    if #words == 0 then return true end
    local text = SearchText(item, path)
    for _, word in ipairs(words) do
        if not text:find(word, 1, true) then return false end
    end
    return true
end

local function ReadCategory(category, path)
    local items = {}
    for index = 1, GetCategoryNumAchievements(category) or 0 do
        local id, name, _, completed, month, day, year, description, _, icon = GetAchievementInfo(category, index)
        if id and (completed and show.completed or not completed and show.incomplete) then
            local item = { id = id, name = name or "", completed = completed and true or false,
                description = description, icon = icon, month = month, day = day, year = year, points = PointsFor(id),
                count = true }
            if Found(item, path) then
                item.rank, item.most = Progress(id, completed)
                items[#items + 1] = item
            end
        end
    end
    return items
end

-- The client's categories as a tree by their parents, in its order, as the game's own window builds it.
local function Tree()
    local nodes, roots = {}, {}
    local function Node(category, depth)
        local node = nodes[category]
        if node then return node end
        local name, parent = GetCategoryInfo(category)
        node = { id = category, name = name or "", low = (name or ""):lower(), kids = {} }
        nodes[category] = node
        local up = depth < MAX_DEPTH and type(parent) == "number" and parent ~= -1 and Node(parent, depth + 1)
        if up then up.kids[#up.kids + 1] = node else roots[#roots + 1] = node end
        return node
    end
    for _, category in ipairs(GetCategoryList and GetCategoryList() or ns.EMPTY) do Node(category, 0) end
    return roots
end

-- A section's challenges left by the search and filter; true when it or one under it keeps any.
local function Gather(node, path, depth)
    path = path .. "\n" .. node.low
    node.items = ReadCategory(node.id, path)
    node.any = #node.items > 0
    for _, kid in ipairs(depth < MAX_DEPTH and node.kids or ns.EMPTY) do
        if Gather(kid, path, depth + 1) then node.any = true end
    end
    return node.any
end

-- Era's list: a section, its challenges, then the sections under it, all hidden while it is folded.
local function Emit(node, depth, shown)
    if not node.any or depth > MAX_DEPTH then return end
    local header = { header = true, id = node.id, name = node.name, depth = depth, expanded = not collapsed[node.id] }
    sections[#sections + 1] = header
    if shown then lines[#lines + 1] = header end
    local open = shown and header.expanded
    if open then
        for _, item in ipairs(node.items) do lines[#lines + 1] = item end
    end
    for _, kid in ipairs(node.kids) do Emit(kid, depth + 1, open) end
end

-- The first challenge shown is picked by default.
local function Collect()
    wipe(lines)
    wipe(sections)
    for _, root in ipairs(Tree()) do
        Gather(root, "", 0)
        Emit(root, 0, true)
    end
    local first, still
    for _, line in ipairs(lines) do
        if not line.header then
            first = first or line.id
            if line.id == selected then still = true end
        end
    end
    if not still then selected = first end
    for _, line in ipairs(lines) do line.selected = not line.header and line.id == selected end
end

local function Detail()
    for _, line in ipairs(lines) do
        if not line.header and line.id == selected then
            return { name = line.name, rank = line.rank, most = line.most, count = true, cost = Cost(line), words = Words(line) }
        end
    end
end

local function Refresh()
    if not page then return end
    Collect()
    page.lines, page.sections = lines, sections
    page:Draw()
    page:DrawDetail(Detail())
    LG.DrawEarned(page)
end

local SPEC = {
    collapsed = collapsed,
    pick = function(line) selected = line.id end,
    link = function(line) return GetAchievementLink and GetAchievementLink(line.id) end,
}

local function SearchBox()
    local box = ns.SearchBox(page, SEARCH_W, SEARCH or "Search")
    box:SetPoint("TOPLEFT", page, "TOPLEFT", SEARCH_X, SEARCH_Y)
    box:SetScript("OnTextChanged", function(self)
        local text = (self:GetText() or ""):lower()
        self.hint:SetShown(text == "")
        self.clear:SetShown(text ~= "")
        if text == query then return end
        query = text
        wipe(words)
        for word in text:gmatch("%S+") do words[#words + 1] = word end
        page.scroll:SetValue(0)
        LG.Refresh()
    end)
end

local function FilterItem(key, global, fallback)
    return { LG.Text(global, fallback), function()
        show[key] = not show[key]
        LG.Refresh()
    end, function() return show[key] end }
end

local function Filter()
    local filter = ns.ShellFilterButton(page)
    filter:SetWidth(FILTER_W)
    filter:SetPoint("TOPLEFT", page, "TOPLEFT", FILTER_X, FILTER_Y)
    local list
    filter:SetScript("OnClick", function(self)
        if not list then
            list = ns.DropList({
                FilterItem("completed", "ACHIEVEMENTFRAME_FILTER_COMPLETED", "LEGACY_SHOW_COMPLETED"),
                FilterItem("incomplete", "ACHIEVEMENTFRAME_FILTER_INCOMPLETE", "LEGACY_SHOW_INCOMPLETE"),
            })
            list:Follow(page)
        end
        list:Toggle(self)
    end)
end

local function Build(window)
    page = LG.EraPage(window, SPEC)
    page.empty:SetText(L["LEGACY_NO_CHALLENGES"])
    SearchBox()
    Filter()
end

local function Shown(_, on)
    page:SetShown(on)
end

LG.AddPage({
    key = "challenges", tab = 2, icon = "Interface\\Icons\\Achievement_GuildPerk_HonorableMention",
    tip = { "LEGACY_CHALLENGE_TAB_TOOLTIP", "LEGACY_CHALLENGES" }, title = { "LEGACY_CHALLENGE_FRAME_TITLE", "LEGACY_CHALLENGES" },
    -- Challenges earned and their steps' progress; points earned.
    events = { "ACHIEVEMENT_EARNED", "CRITERIA_UPDATE", "TRAIT_TREE_CURRENCY_INFO_UPDATED", "MAJOR_FACTION_RENOWN_LEVEL_CHANGED" },
    build = Build, shown = Shown, refresh = Refresh,
})
