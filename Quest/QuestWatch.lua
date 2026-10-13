local _, ns = ...

-- Classic Era's quest watch in place of the game's objective tracker (#98): each watched quest's title and its
-- objectives as plain lines (Era's QuestWatch_Update), under the minimap left of the side bars, below the durability
-- figure while it shows. The game's tracker is parked by Quest/QuestTracker.lua, out of a fight.

local KEY = "questWatch"
local LINE_H, TITLE_GAP, MAX_LINES, PAD_W = 13, 4, 30, 10
-- Era's frame is 280 wide and its lines never wrap; Forever's sentence objectives would run past it, so ours wrap there.
local MAX_W = 280
-- Era's colors: a title dark gold, gold once every objective is done; an objective grey, white once done.
local TITLE, TITLE_DONE = { 0.75, 0.61, 0 }, { 1, 0.82, 0 }
local GOAL, GOAL_DONE = { 0.8, 0.8, 0.8 }, { 1, 1, 1 }
local WHITE = { 1, 1, 1 }
-- Era's right-side container: 5 in from the side bars, 192 down; the watch 10 under the durability figure.
local SIDE_GAP, TOP_Y, STACK_GAP = 5, -192, 10
local EVENTS = { "QUEST_WATCH_LIST_CHANGED", "QUEST_LOG_UPDATE", "PLAYER_ENTERING_WORLD" }

local home, lines, hits, events, unitEvents, menu
local active = false
-- Room another addon's block keeps above the quests (top) or under them (bottom): { height, width } in the watch's scale.
local rooms = {}

local function Line(i)
    local line = lines[i]
    if line then return line end
    line = home:CreateFontString(nil, "BACKGROUND", "GameFontHighlight")
    line:SetJustifyH("LEFT")
    line:SetJustifyV("TOP")
    line:SetIndentedWordWrap(true)
    lines[i] = line
    return line
end

-- The text on one line of 13, or wrapped at Era's width; returns its width and height.
local function Fill(line, text)
    line:SetWidth(0)
    line:SetText(text)
    local width = line:GetStringWidth()
    if width <= MAX_W then
        line:SetSize(width, LINE_H)
        return width, LINE_H
    end
    line:SetWidth(MAX_W)
    local height = math.max(LINE_H, line:GetStringHeight())
    line:SetHeight(height)
    return MAX_W, height
end

-- Era wrote a count after the name ("Mossy Tumor: 0/5"); this client puts it first.
local function EraText(text)
    local have, need, rest = text:match("^(%d+)/(%d+)%s+(.+)$")
    if rest then return string.format("%s: %s/%s", rest, have, need) end
    return text
end

-- Its top right corner at Era's spot unless placed in edit mode; offsets in its own scale.
local function Lay()
    if not home or (ns.WindowPlaced and ns.WindowPlaced(KEY)) then return end
    local y = TOP_Y
    local durability = DurabilityFrame
    local bottom = durability and durability:IsVisible() and durability:GetBottom()
    if bottom and not ns.IsSecret(bottom) then
        local k = durability:GetEffectiveScale() / UIParent:GetEffectiveScale()
        y = bottom * k - UIParent:GetHeight() - STACK_GAP
    end
    local side = ns.band and ns.band.SideColumnsWidth and ns.band.SideColumnsWidth() or 0
    local scale = home:GetScale()
    ns.SetPointOnce(home, "TOPRIGHT", UIParent, "TOPRIGHT", -(side + SIDE_GAP) / scale, y / scale)
end

local function Color(line, rgb) line:SetTextColor(rgb[1], rgb[2], rgb[3]) end

-- A title's right-click menu, from the client's own words.
local function Menu()
    menu = menu or ns.RowMenu({
        { OBJECTIVES_VIEW_IN_QUESTLOG or "Open Quest Details", function(hit) ns.ShowQuestLog(hit.questID) end,
            function() return ns.QL ~= nil and ns.QL.active == true end },
        { OBJECTIVES_STOP_TRACKING or "Untrack", function(hit) ns.QL.SetWatched(hit.questID, false) end },
        { ABANDON_QUEST or "Abandon Quest", function(hit) ns.QL.AbandonPrompt(hit.questID) end },
    })
    return menu
end

-- Left: the quest in our quest log; with the watch modifier (shift), no longer watched, as in Era's log. Right: its menu.
local function TitleClick(hit, button)
    if button == "RightButton" then
        Menu():Follow(home)
        Menu():Open(hit, hit.title:GetText())
    elseif IsModifiedClick("QUESTWATCHTOGGLE") then
        ns.QL.SetWatched(hit.questID, false)
    else
        ns.ShowQuestLog(hit.questID)
    end
end

-- The mouse area over a title: the lines themselves take none.
local function Hit(i)
    local hit = hits[i]
    if hit then return hit end
    hit = ns.NewFrame("Button", nil, home)
    hit:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    hit:SetScript("OnEnter", function(self) Color(self.title, WHITE) end)
    hit:SetScript("OnLeave", function(self) Color(self.title, self.rgb) end)
    hit:SetScript("OnClick", TitleClick)
    hits[i] = hit
    return hit
end

-- Era's QuestWatch_Update over the game's watch list; a quest with no objectives is left out, as Era did.
local function Update()
    if not active then return end
    local top, bottom = rooms.top, rooms.bottom
    local used, quests = 0, 0
    local widest = math.max(top and top.width or 0, bottom and bottom.width or 0)
    local tall = top and top.height or 0
    for i = 1, C_QuestLog.GetNumQuestWatches() do
        local questID = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
        local goals = questID and C_QuestLog.GetQuestObjectives(questID)
        if goals and #goals > 0 and used + 1 + #goals <= MAX_LINES then
            used, quests = used + 1, quests + 1
            local title = Line(used)
            local width, height = Fill(title, C_QuestLog.GetTitleForQuestID(questID) or "")
            if used == 1 then
                ns.SetPointOnce(title, "TOPLEFT", home, "TOPLEFT", 0, top and -(top.height + TITLE_GAP) or 0)
                if top then tall = tall + TITLE_GAP end
            else
                ns.SetPointOnce(title, "TOPLEFT", lines[used - 1], "BOTTOMLEFT", 0, -TITLE_GAP)
                tall = tall + TITLE_GAP
            end
            title:Show()
            widest, tall = math.max(widest, width), tall + height
            local done = 0
            for _, goal in ipairs(goals) do
                used = used + 1
                local line = Line(used)
                width, height = Fill(line, " - " .. EraText(goal.text or ""))
                ns.SetPointOnce(line, "TOPLEFT", lines[used - 1], "BOTTOMLEFT", 0, 0)
                Color(line, goal.finished and GOAL_DONE or GOAL)
                if goal.finished then done = done + 1 end
                line:Show()
                widest, tall = math.max(widest, width), tall + height
            end
            local hit = Hit(quests)
            hit.title, hit.questID, hit.rgb = title, questID, done == #goals and TITLE_DONE or TITLE
            hit:SetAllPoints(title)
            hit:Show()
            Color(title, hit:IsMouseOver() and WHITE or hit.rgb)
        end
    end
    if bottom then tall = tall + (used > 0 and TITLE_GAP or 0) + bottom.height end
    for i = used + 1, #lines do lines[i]:Hide() end
    for i = quests + 1, #hits do hits[i]:Hide() end
    home:SetShown(used > 0 or top ~= nil or bottom ~= nil)
    home:SetSize(math.max(1, widest + PAD_W), math.max(1, tall))
    Lay()
end

-- Edit mode's reset and size steps.
function ns.LayQuestWatch(key)
    if key == KEY then Lay() end
end

-- The watch while it is the pick, else nil.
function ns.QuestWatchFrame()
    return active and home or nil
end

-- Keeps room for a block at side "top" or "bottom" (one block a side), height nil gives it back; false while the watch
-- is not the pick. The block draws itself: at the watch's top left, or its bottom left.
function ns.QuestWatchRoom(side, height, width)
    if side ~= "top" and side ~= "bottom" then return false end
    rooms[side] = height and { height = height, width = width or 0 } or nil
    if not active then return false end
    Update()
    return true
end

local function Apply()
    if not home then
        home = CreateFrame("Frame", "ForeverClassicUIQuestWatch", UIParent)
        home:SetFrameStrata("LOW")
        home:SetSize(1, 1)
        lines, hits = {}, {}
        events = ns.EventFrame(EVENTS, Update)
        unitEvents = ns.EventFrame({ "UNIT_QUEST_LOG_CHANGED" }, Update, "player")
        if ns.PlaceSavedWindows then ns.PlaceSavedWindows() end
        if DurabilityFrame then ns.Sched.OnVisible(DurabilityFrame, "questWatch.durability", Lay) end
    elseif not active then
        ns.RegisterEvents(events, EVENTS)
        ns.RegisterEvents(unitEvents, { "UNIT_QUEST_LOG_CHANGED" }, "player")
    end
    active = true
    ns.SyncGameTracker()
    Update()
end

local function Restore()
    active = false
    if home then
        home:Hide()
        events:UnregisterAllEvents()
        unitEvents:UnregisterAllEvents()
    end
    ns.SyncGameTracker()
end

ns.RegisterModule(KEY, { apply = Apply, restore = Restore })

-- Any pick of the tracker's choice is seen at once in a fight; the game's tracker follows when it ends.
ns.OnToggle(function(key)
    local group = ns.TOGGLE_RADIO[KEY]
    if not group or ns.TOGGLE_RADIO[key] ~= group then return end
    if ns.db.questWatch then Apply() elseif home then Restore() end
end)

-- The tracker's three boxes became one choice: an install from before keeps what it showed (the watch over hidden, hidden
-- over the look), in the account and every profile. Runs before the defaults fill.
function ns.OneTrackerChoice()
    local db = ns.db
    local function Keep(t)
        if t.questWatch == true then
            t.questTracker, t.hideObjectiveTracker = false, false
        elseif t.hideObjectiveTracker == true then
            t.questTracker = false
        elseif t.questTracker == false then
            t.gameObjectiveTracker = true
        end
    end
    Keep(db)
    for _, shot in pairs(type(db.profiles) == "table" and db.profiles or {}) do
        if type(shot) == "table" then Keep(shot) end
    end
    db.dbVersion = 11
end
