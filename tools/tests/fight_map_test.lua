-- Offline test under Lua 5.4 for the fight lay (UI/WindowPanels.lua ns.LayFightRaw): the world map is never laid with the
-- row in a fight, it stands where the game puts it as out of one (it moved in a fight when it was); social still is.
-- Run from the addon root: lua tools/tests/fight_map_test.lua (CI runs every tools/tests/*_test.lua).
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

local function Frame(name, left, right)
    return { name = name, left = left, right = right, GetName = function(self) return self.name end,
        IsShown = function() return true end }
end
WorldMapFrame = Frame("WorldMapFrame", 16, 1051)
FriendsFrame = Frame("FriendsFrame", 600, 938)
UIParent = { GetWidth = function() return 1365 end }
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function InCombatLockdown() return true end

local ns = {
    windowRawShown = {},
    windowParts = {
        Seen = function() return true end, Locked = function() return false end, SheetGap = function() return 32 end,
        BlockSpan = function(_, frame) return frame.left, frame.right end, ERA_X = -16, ERA_Y = 12,
    },
    MoverTakes = function() return false end, FramePlaced = function() return false end,
    GameWindowOffRow = function() return false end,
    WindowRatio = function() return 1 end, GameXOffset = function() return 0 end,
    GamePanelWidth = function(frame) return frame.right - frame.left end, GamePanelValue = function() return 0 end,
    GameRow = function() return 16, -116 end,
}
assert(loadfile(ROOT .. "/UI/WindowRow.lua"))("ClassicUIForever", ns)
assert(loadfile(ROOT .. "/UI/WindowPanels.lua"))("ClassicUIForever", ns)

local row = { game = { { 16, 1051, "WorldMapFrame" }, { 600, 938, "FriendsFrame" } }, ours = {} }
ns.LayFightRaw(row)
Check(not ns.FightLaid(WorldMapFrame), "the map is not laid with the row in a fight")
Check(ns.FightLaid(FriendsFrame), "social still is")
local mapKept = false
for _, block in ipairs(row.game) do
    if block[3] == "WorldMapFrame" and block[1] == 16 and block[2] == 1051 then mapKept = true end
end
Check(mapKept, "the map stays a block where it stands, for ours to keep clear of")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("fight_map_test: ok")
