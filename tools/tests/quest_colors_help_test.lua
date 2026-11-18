-- Offline test under Lua 5.4 for the help around Forever's map filter Quest Difficulty Color, which players keep taking
-- for our bug (their quests all yellow): the Quests row that is the filter itself, the FAQ answer, and a chat line the
-- first time the quest log opens each session with the filter off, naming that row (Quest/QuestLogData.lua).
-- Run from the addon root: lua tools/tests/quest_colors_help_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 122 212

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local failed = 0
local function Check(ok, what)
    if not ok then
        failed = failed + 1
        print("FAIL " .. what)
    end
end

local function Source(path)
    local handle = assert(io.open(ROOT .. "/" .. path, "r"))
    local text = handle:read("a")
    handle:close()
    return text
end

------------------------------------------------------------------ the row mirrors the filter, the chat line names it

local cvars = { showQuestDifficultyColor = "0", showQuestLevel = "1" }
local printed = {}
local ns = { db = {}, L = { QUEST_COLORS_OFF = "off %s, check %s", OPT_questColors = "Quest difficulty colors" } }
ns.GetCVar = function(name) return cvars[name] end
ns.OnForever = function() return true end
ns.IsSecret = function() return false end
ns.Print = function(text) printed[#printed + 1] = text end
ns.ChatLink = function(target, label) return "[" .. target .. ":" .. label .. "]" end
_G.MAP_QUEST_DIFFICULTY_TEXT = "Quest Difficulty Color"
assert(loadfile(ROOT .. "/Quest/QuestLogData.lua"))("ClassicUIForever", ns)
local QL = ns.QL

QL.ReadFilters()
Check(ns.db.questColors == false and ns.db.questLevels == true, "the rows read both filters from the game")
cvars.showQuestDifficultyColor = "1"
QL.ReadFilters()
Check(ns.db.questColors == true, "the row follows the filter turned on from the map")

-- Off: one line on the first open, naming the game's filter and linking our row.
cvars.showQuestDifficultyColor = "0"
QL.SayColorsOff()
QL.SayColorsOff()
Check(#printed == 1, "one chat line a session (" .. #printed .. ")")
Check(printed[1] and printed[1]:find("Quest Difficulty Color", 1, true) ~= nil, "the line names the game's filter")
Check(printed[1] and printed[1]:find("[questcolors:Quest difficulty colors]", 1, true) ~= nil,
    "the line links the row that brings the colors back")

-- Each run below is a fresh session: the file loaded again.
local function Session(db, filter)
    printed, cvars.showQuestDifficultyColor = {}, filter
    ns.db = db
    assert(loadfile(ROOT .. "/Quest/QuestLogData.lua"))("ClassicUIForever", ns)
    ns.QL.SayColorsOff()
    return #printed
end
Check(Session({}, "1") == 0, "colors on: no line")
Check(Session({ addonMessages = false }, "0") == 0, "Addon messages off: no line")
Check(Session({ questColorsNote = false }, "0") == 0, "its own row off: no line")

-- Item arrivals: only a reward the page waits on.
QL = ns.QL
QL.WaitForItem(100)
Check(QL.ItemArrived(200) == false, "another addon's item redraws nothing")
Check(QL.ItemArrived(100) == true, "a waited reward redraws the page")
Check(QL.ItemArrived(100) == false, "once")

------------------------------------------------------------------ wired in the files

local toggles = Source("Options/Toggles.lua")
Check(toggles:find('{ "questColors", L["OPT_questColors"], L["OPT_questColors_TIP"], hideIf = OnRetail,', 1, true) ~= nil,
    "the Quests page has the row, Forever only")
Check(toggles:find('"questColorsNote", L["OPT_questColorsNote"], L["OPT_questColorsNote_TIP"], parent = "addonMessages"',
    1, true) ~= nil, "the chat line has its row under Addon messages")
local row = toggles:match('{ "questColors",.-search = "([^"]+)"')
for _, word in ipairs({ "yellow", "color", "difficulty" }) do
    Check(row and row:find(word, 1, true) ~= nil, "the row is found by searching " .. word)
end
Check(Source("Core/Core.lua"):find('if key == "questColors" and ns.OnForever() then', 1, true) ~= nil,
    "a click on the row writes the game's filter, on Forever only")
Check(Source("Options/Welcome.lua"):find('target == "questcolors" then\n%s*ns.OpenOptionsAt%("questColors"%)') ~= nil,
    "the chat line's link opens the options at the row")
Check(Source("Quest/QuestLogWindow.lua"):find("QL.SayColorsOff()", 1, true) ~= nil, "the quest log's open says it")
local help = Source("Options/HelpPanes.lua")
Check(help:find('{ "FAQ_QUESTCOLORS_Q", "FAQ_QUESTCOLORS_A", on = "forever", needs = { "questColors" }', 1, true) ~= nil,
    "the FAQ answers it")
Check(help:find('"FAQ_QUESTCOLORS_Q"', 1, true) < help:find('"FAQ_LFG_Q"', 1, true), "first of the real questions")

if failed > 0 then
    print(string.format("quest colors help: %d failed", failed))
    os.exit(1)
end
print("quest colors help: ok")
