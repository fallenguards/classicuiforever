-- Offline test under Lua 5.4 for a closed window's home before a fight (UI/WindowPanels.lua ns.HomeBlocks with the row
-- solver): the map and the game's windows its opening closes take no room, so a spellbook opened in a fight after the
-- map shut stands at the row's start, not past where the map was; the sheet and talents still hold their room.
-- Run from the addon root: lua tools/tests/window_home_test.lua (CI runs every tools/tests/*_test.lua).
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
local function Cut(path, from)
    local handle = assert(io.open(ROOT .. path, "r"))
    local source = handle:read("a")
    handle:close()
    local first = source:find(from, 1, true)
    assert(first, path .. ": the code to test is in the file")
    return source:sub(first)
end

-- Era's rule as UI/Windows.lua has it: ours carry fcuiPushable, the game's windows their panel list's number.
local pushable = { FriendsFrame = 0, QuestLogFrame = 0, CharacterFrame = 3, PlayerSpellsFrame = 6 }
local function Replaces(opener, other)
    return opener == _G.WorldMapFrame or ((opener.fcuiPushable or 0) == 0 and (pushable[other:GetName()] or 0) == 0)
end
local function Game(name) return { GetName = function() return name end } end
WorldMapFrame, FriendsFrame, QuestLogFrame = Game("WorldMapFrame"), Game("FriendsFrame"), Game("QuestLogFrame")
CharacterFrame, PlayerSpellsFrame = Game("CharacterFrame"), Game("PlayerSpellsFrame")
function wipe(t) for k in pairs(t) do t[k] = nil end return t end

local ns = { windowParts = { Replaces = Replaces, LeaveOpen = { PlayerSpellsFrame = true },
    Beside = { CharacterFrame = true, MacroFrame = true } } }
assert(loadfile(ROOT .. "/UI/WindowRow.lua"))("ClassicUIForever", ns)
assert(load(Cut("/UI/WindowPanels.lua", "local homeBlocks = {}"), "home blocks", "t", setmetatable({ ns = ns }, { __index = _G })))()

local book, talents = { fcuiPushable = 0 }, { fcuiPushable = 6 }
local map, sheet, social, spells = { 0, 1400, "WorldMapFrame" }, { 0, 352, "CharacterFrame" }, { 16, 354, "FriendsFrame" },
    { 386, 1188, "PlayerSpellsFrame" }

local function Names(blocks)
    local list = {}
    for i, block in ipairs(blocks) do list[i] = block[3] end
    return table.concat(list, ", ")
end

local home = ns.HomeBlocks(book, { map, sheet })
Check(#home == 1 and home[1] == sheet, "the map takes no room in the book's home, the sheet does: " .. Names(home))
home = ns.HomeBlocks(book, { social })
Check(#home == 0, "the social window (pushable 0, as the book) closes as the book opens: no room held: " .. Names(home))
home = ns.HomeBlocks(talents, { social, spells })
Check(#home == 2, "talents (pushable 6) stand beside the social window and the game's spell window: " .. Names(home))
home = ns.HomeBlocks(book, { map, spells })
Check(#home == 1 and home[1] == spells, "the game's spell window is never closed by us: it keeps its room: " .. Names(home))

-- The fight's start with the map open: the book's home is the row's start, where it opens once the map has shut.
local out = ns.SolveWindowRow({ start = 0, screen = 1920, stay = true, game = ns.HomeBlocks(book, { map }),
    ours = { { width = 352, drawn = 384 } } }, {})
Check(out.x[1] == 0, "the book homed at the row's start with the map up, got " .. tostring(out.x[1]))
out = ns.SolveWindowRow({ start = 0, screen = 1920, stay = true, game = ns.HomeBlocks(book, { map, sheet }),
    ours = { { width = 352, drawn = 384 } } }, {})
Check(out.x[1] == 352, "with the sheet up too, past the sheet, got " .. tostring(out.x[1]))

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("window_home_test: all checks passed")
