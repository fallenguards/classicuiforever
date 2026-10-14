-- Offline test under Lua 5.4 for Era's panel rule (UI/Windows.lua Pushable, Replaces): a window opened where another
-- stands closes it only when neither can be pushed aside (both pushable 0, Era's UIParentPanelManager); otherwise they
-- stand side by side. Ours carry Era's numbers, the game's windows their own panel list's. Our old rule closed the quest
-- log for talents, and talents for the social window, where Era keeps both. The code is cut out of the file and run.
-- Run from the addon root: lua tools/tests/era_panel_rule_test.lua (CI runs every tools/tests/*_test.lua).
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
local function Cut(path, from, to)
    local handle = assert(io.open(ROOT .. path, "r"))
    local source = handle:read("a")
    handle:close()
    local first = source:find(from, 1, true)
    local last = first and source:find(to, first, true)
    assert(first and last, path .. ": the code to test is in the file")
    return source:sub(first, last - 1)
end

-- The game's panel list as Forever has it, and one window that says its own in an attribute.
local env = setmetatable({
    ns = { Safe = function(v) return v end },
    UIPanelWindows = { FriendsFrame = { pushable = 0 }, MerchantFrame = { pushable = 0 }, CharacterFrame = { pushable = 3 },
        MacroFrame = { pushable = 1 } },
}, { __index = _G })
env._G = env
local body = Cut("/UI/Windows.lua", "local function Pushable(frame)", "-- How much of the character window")
local Replaces = assert(load(body .. "\nreturn Replaces", "era rule", "t", env))()

local function Ours(name, pushable)
    return { fcuiPushable = pushable, GetName = function() return name end, GetAttribute = function() return nil end }
end
local function Game(name, attribute)
    return { GetName = function() return name end, GetAttribute = function() return attribute end }
end

-- Ours registered with Era's numbers (spellbook and quest log 0, talents and Legacy 6).
local book, log, talents, legacy = Ours("book", 0), Ours("log", 0), Ours("talents", 6), Ours("legacy", 6)
local social, merchant, sheet, macros = Game("FriendsFrame"), Game("MerchantFrame"), Game("CharacterFrame"), Game("MacroFrame")

Check(Replaces(log, book) and Replaces(book, log), "the quest log and spellbook replace each other, as in Era")
Check(Replaces(social, book) and Replaces(book, social), "the social window and spellbook replace each other, as in Era")
Check(not Replaces(talents, log) and not Replaces(log, talents), "talents and the quest log stand side by side, as in Era")
Check(not Replaces(social, talents) and not Replaces(talents, social), "the social window and talents stand side by side")
Check(not Replaces(talents, book) and not Replaces(legacy, book), "talents and Legacy stand beside the spellbook")
Check(not Replaces(legacy, talents), "Legacy and talents stand side by side")
Check(Replaces(merchant, log) and not Replaces(merchant, talents), "a vendor replaces the quest log, not talents")
Check(not Replaces(sheet, book) and not Replaces(macros, book), "the character and macro windows stand beside ours")
Check(not Replaces(Game("SomePanel", 2), book), "a game window's own pushable attribute is read first")
Check(Replaces(Game("UnlistedPanel"), book), "a game window in no list counts as 0")
-- Era's map (allowOtherPanels 0) replaces what it opens on; this client's says 1.
env.WorldMapFrame = Game("WorldMapFrame")
Check(Replaces(env.WorldMapFrame, talents) and Replaces(env.WorldMapFrame, legacy), "the map closes talents and Legacy, as in Era")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("era_panel_rule_test: all checks passed")
