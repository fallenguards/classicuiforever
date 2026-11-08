-- Offline test under Lua 5.4 for taking the game's level prefix off quest titles (Quest/QuestLogData.lua
-- ns.StripQuestLevel). Since Forever build 70291 the game puts "[17] " in front of every tracker and map list title
-- whatever its Show Quest Levels says (#140); with our Quest levels option off it comes off, colour code kept.
-- Run from the addon root: lua tools/tests/quest_level_strip_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 212

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local failed = 0
local function Check(ok, what)
    if not ok then
        failed = failed + 1
        print("FAIL " .. what)
    end
end

local forever = true
local cvar = "0"
local ns = {}
ns.GetCVar = function(name) return name == "showQuestLevel" and cvar or nil end
ns.OnForever = function() return forever end
ns.IsSecret = function() return false end
assert(loadfile(ROOT .. "/Quest/QuestLogData.lua"))("ClassicUIForever", ns)

local function Text(s)
    return { s = s, GetText = function(self) return self.s end, SetText = function(self, v) self.s = v end }
end
local function Stripped(s, level)
    local text = Text(s)
    ns.StripQuestLevel(text, level)
    return text.s
end

-- Party members on the quest: the game puts their count first, and it stays; only the level comes off.
Check(Stripped("[2] [17] Wolves", 17) == "[2] Wolves", "the party count stays, the level comes off")
Check(Stripped("[2] [17+] Elite Quest", 17) == "[2] Elite Quest", "the party count stays before an elite level")
Check(Stripped("|cff40c040[2] [17] Wolves|r", 17) == "|cff40c040[2] Wolves|r", "the party count stays inside a colour")
Check(Stripped("[2] Wolves", 17) == "[2] Wolves", "a lone party count is not the level")
Check(Stripped("[17] Wolves", 17) == "Wolves", "the quest's own level comes off")
Check(Stripped("[17] The Defias Brotherhood") == "The Defias Brotherhood", "a plain prefix comes off")
Check(Stripped("[24+] Elite Quest (Elite)") == "Elite Quest (Elite)", "an elite prefix comes off")
Check(Stripped("|cff40c040[12] Wolves|r") == "|cff40c040Wolves|r", "inside a difficulty colour the colour stays")
Check(Stripped("The [5] Pillars") == "The [5] Pillars", "brackets inside a title stay")
Check(Stripped("Wolves") == "Wolves", "a title with no prefix is left alone")
cvar = "1"
Check(Stripped("[17] Wolves") == "[17] Wolves", "with Quest levels on the prefix stays")
cvar = "0"
forever = false
Check(Stripped("[17] Wolves") == "[17] Wolves", "retail's prefix follows its own setting, left alone")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("quest_level_strip_test: ok")
