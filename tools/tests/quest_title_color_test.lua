-- Offline test under Lua 5.4 for quest title colors in our quest lists (Quest/QuestLogData.lua QL.LevelColor): Forever's
-- map filter Quest Difficulty Color switches the level colors in the quest log and both map lists as it does in the
-- tracker, and each list draws its titles again as the filter changes (the game rebuilds none of them for it).
-- Run from the addon root: lua tools/tests/quest_title_color_test.lua (CI runs every tools/tests/*_test.lua).
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

local forever, cvar = true, nil
local ns = {}
ns.GetCVar = function(name) return name == "showQuestDifficultyColor" and cvar or nil end
ns.OnForever = function() return forever end
ns.IsSecret = function() return false end
ns.QuestLevelColor = function() return 0.25, 0.75, 0.25 end
ns.QuestYellow = function() return 1, 0.92, 0 end
assert(loadfile(ROOT .. "/Quest/QuestLogData.lua"))("ClassicUIForever", ns)
local QL = ns.QL

local function Is(info, r, g, b)
    local cr, cg, cb = QL.LevelColor(info)
    return cr == r and cg == g and cb == b
end
local quest, header = { level = 20 }, { isHeader = true }

Check(Is(quest, 0.25, 0.75, 0.25), "the filter never set: a quest has its level color")
cvar = "1"
Check(Is(quest, 0.25, 0.75, 0.25), "the filter on: a quest has its level color")
cvar = "0"
Check(Is(quest, 1, 0.92, 0), "the filter off: a quest is the plain yellow")
Check(Is(header, 0.7, 0.7, 0.7), "the filter off: a header keeps its own color")
forever = false
Check(Is(quest, 0.25, 0.75, 0.25), "a client without the filter colors by level whatever the setting reads")

local function Source(path)
    local handle = assert(io.open(ROOT .. "/" .. path, "r"))
    local text = handle:read("a")
    handle:close()
    return text
end
for _, path in ipairs({ "Quest/QuestLogWindow.lua", "Quest/QuestMapList.lua", "Quest/QuestMapPane.lua" }) do
    local text = Source(path)
    Check(text:find("CVAR_UPDATE", 1, true) ~= nil and text:find('"showQuestDifficultyColor"', 1, true) ~= nil,
        path .. ": the list draws its titles again as the filter changes")
end
Check(Source("Quest/QuestMapPane.lua"):find("if level and ns.QuestTitlesColored() then", 1, true) ~= nil,
    "the game's own map list, dressed, follows the filter")
Check(Source("Quest/QuestTracker.lua"):find("if level and ns.QuestTitlesColored() then", 1, true) ~= nil,
    "the tracker asks the same answer")

if failed > 0 then
    print(string.format("quest title color: %d failed", failed))
    os.exit(1)
end
print("quest title color: ok")
