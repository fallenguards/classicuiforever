-- Offline tests for Quest/QuestWatch.lua under Lua 5.4: Classic Era's quest watch lines over the game's watch list.
-- Run from the addon root: lua tools/tests/quest_watch_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 212

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

------------------------------------------------------------------ the stub client

-- A font string: 6 wide a letter; wrapped, a line of 13 per started width.
local Text = {}
Text.__index = Text
function Text:SetJustifyH() end
function Text:SetJustifyV() end
function Text:SetIndentedWordWrap() end
function Text:SetText(text) self.text = text end
function Text:GetText() return self.text end
function Text:SetWidth(w) self.width = w end
function Text:SetHeight(h) self.height = h end
function Text:SetSize(w, h) self.width, self.height = w, h end
function Text:GetStringWidth() return #self.text * 6 end
function Text:GetStringHeight() return math.ceil(#self.text * 6 / self.width) * 13 end
function Text:SetTextColor(r, g, b) self.rgb = string.format("%.2f %.2f %.2f", r, g, b) end
function Text:Show() self.shown = true end
function Text:Hide() self.shown = false end

local Frame = {}
Frame.__index = Frame
local made = {}
local function NewFrame() return setmetatable({ scripts = {} }, Frame) end
function Frame:CreateFontString()
    local line = setmetatable({}, Text)
    made[#made + 1] = line
    return line
end
function Frame:SetFrameStrata() end
function Frame:SetSize(w, h) self.w, self.h = w, h end
function Frame:SetShown(on) self.shown = on end
function Frame:Show() self.shown = true end
function Frame:Hide() self.shown = false end
function Frame:GetScale() return 1 end
function Frame:RegisterForClicks() end
function Frame:SetScript(name, fn) self.scripts[name] = fn end
function Frame:SetAllPoints() end
function Frame:IsMouseOver() return false end
function Frame:UnregisterAllEvents() end

function CreateFrame() return NewFrame() end
UIParent = NewFrame()
function IsModifiedClick() return false end

local quests = {
    { id = 1, title = "Tumors", goals = { { text = "0/5 Mossy Tumor", finished = false } } },
    { id = 2, title = "No objectives", goals = {} },
    { id = 3, title = "Crown of the Earth", goals = { { text = "Bring the Filled Vessel to Arch Druid Fandral Staghelm in Darnassus.",
        finished = true } } },
    { id = 4, title = "Darkness", goals = { { text = "1/1 Amulet", finished = true }, { text = "0/1 Other Amulet", finished = false } } },
}
C_QuestLog = {
    GetNumQuestWatches = function() return #quests end,
    GetQuestIDForQuestWatchIndex = function(i) return quests[i].id end,
    GetQuestObjectives = function(id) return quests[id].goals end,
    GetTitleForQuestID = function(id) return quests[id].title end,
}

------------------------------------------------------------------ the addon

local apply
local noop = function() end
local ns = {
    db = { questWatch = true },
    NewFrame = function() return NewFrame() end,
    SetPointOnce = noop, SyncGameTracker = noop, OnToggle = noop, RegisterEvents = noop,
    EventFrame = function() return NewFrame() end,
    IsSecret = function() return false end,
    RegisterModule = function(_, spec) apply = spec.apply end,
    TOGGLE_RADIO = {},
    Sched = { OnVisible = noop },
}
assert(loadfile(ROOT .. "/Quest/QuestWatch.lua"))("ClassicUIForever", ns)
apply()

------------------------------------------------------------------ checks

local failures = 0
local function Check(ok, what)
    if not ok then
        failures = failures + 1
        print("FAIL: " .. what)
    end
end
local shown = {}
for _, line in ipairs(made) do
    if line.shown then shown[#shown + 1] = line end
end
local DIM, GOLD, GREY, WHITE = "0.75 0.61 0.00", "1.00 0.82 0.00", "0.80 0.80 0.80", "1.00 1.00 1.00"

Check(#shown == 7, "three quests with objectives make seven lines, the one without is left out (" .. #shown .. ")")
Check(shown[1].text == "Tumors" and shown[1].rgb == DIM, "a title with work left is dim gold")
Check(shown[2].text == " - Mossy Tumor: 0/5" and shown[2].rgb == GREY, "a count the Era way, grey until done: " .. tostring(shown[2].text))
Check(shown[3].text == "Crown of the Earth" and shown[3].rgb == GOLD, "a title with every objective done is bright gold")
Check(shown[4].text == " - Bring the Filled Vessel to Arch Druid Fandral Staghelm in Darnassus." and shown[4].rgb == WHITE,
    "a sentence objective is left as written, white when done")
Check(shown[4].width == 280 and shown[4].height == 26, "a long line wraps at Era's 280 (" .. tostring(shown[4].width) .. " x "
    .. tostring(shown[4].height) .. ")")
Check(shown[2].height == 13, "a short line is one line of 13")
Check(shown[5].rgb == DIM and shown[6].text == " - Amulet: 1/1" and shown[7].text == " - Other Amulet: 0/1",
    "one objective left keeps the title dim")

-- Room for a block above the quests: the first title moves under it, the watch grows by it and the gap, and is as wide
-- as the widest of the two.
local points = {}
ns.SetPointOnce = function(frame, _, _, _, _, y) points[frame] = y end
local home = ns.QuestWatchFrame()
local plainH = home.h
Check(ns.QuestWatchRoom("top", 40, 400) == true, "room is kept while the watch is the pick")
Check(points[shown[1]] == -44, "the first title under the room and a gap (" .. tostring(points[shown[1]]) .. ")")
Check(home.h == plainH + 44 and home.w == 410, "taller by the room and gap, as wide as the block (" .. home.w .. ")")
ns.QuestWatchRoom("top", nil)
ns.QuestWatchRoom("bottom", 30, 100)
Check(points[shown[1]] == 0 and home.h == plainH + 34, "room under the quests: the titles stay, the watch grows")
local saved = quests
quests = {}
ns.QuestWatchRoom("bottom", 30, 100)
Check(home.shown == true and home.h == 30, "no quests: the watch shows for the block alone, its height")
quests = saved
ns.QuestWatchRoom("bottom", nil)
Check(home.h == plainH, "given back, the watch is as before")

-- The tracker's three boxes as one choice: an install from before keeps what it showed.
ns.db = {
    questTracker = false, dbVersion = 10,
    profiles = {
        watch = { questWatch = true, hideObjectiveTracker = true },
        hidden = { hideObjectiveTracker = true },
        look = {},
    },
}
ns.OneTrackerChoice()
Check(ns.db.gameObjectiveTracker == true, "the classic look off before: the game's own tracker picked")
local watch, hidden, look = ns.db.profiles.watch, ns.db.profiles.hidden, ns.db.profiles.look
Check(watch.questWatch == true and watch.questTracker == false and watch.hideObjectiveTracker == false, "the watch stays the pick")
Check(hidden.hideObjectiveTracker == true and hidden.questTracker == false, "hidden stays the pick")
Check(next(look) == nil, "the default look is left alone")
Check(ns.db.dbVersion == 11, "writes dbVersion 11")

if failures > 0 then
    print(string.format("quest watch: %d failed", failures))
    os.exit(1)
end
print("quest watch: ok")
