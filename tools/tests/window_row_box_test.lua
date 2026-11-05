-- Offline test under Lua 5.4 for the Window row box (#162; UI/GameSpot.lua): its place in windowPos.windowRow moves
-- the row's start, the game's own row windows stand off their manager's line by the same shift without stacking it on
-- each pass, and a game window stays in the row on the game's line or the box's.
-- Run from the addon root: lua tools/tests/window_row_box_test.lua (CI runs every tools/tests/*_test.lua).
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

local H = 853
local env = setmetatable({
    UIParent = { GetHeight = function() return H end, GetEffectiveScale = function() return 1 end },
    UIPanelWindows = { CharacterFrame = {} },
    GetUIPanelLayoutAttribute = function(name) return name == "TOP_OFFSET" and -116 or 16 end,
}, { __index = _G })
env._G = env
local ns = { Safe = function(v) return v end, db = {} }
function ns.DbTable(key)
    ns.db[key] = ns.db[key] or {}
    return ns.db[key]
end
assert(loadfile(ROOT .. "/UI/GameSpot.lua", "t", env))("ClassicUIForever", ns)

local function Near(a, b) return math.abs(a - b) < 1e-6 end

-- No box place: no shift, nothing learned away.
Check(ns.WindowRowPlaced() == nil, "no place: none")
local dx, dy = ns.WindowRowShift()
Check(dx == 0 and dy == 0, "no place: no shift")

-- The row's own start is Era's spot: 16 left of the game's (16) and 12 over its top (-116): 0, -104, i.e. H - 104 up.
ns.DbTable("windowPos").windowRow = { 200, H - 304 }
dx, dy = ns.WindowRowShift()
Check(Near(dx, 200) and Near(dy, -200), string.format("the box 200 right and 200 down: shift %s, %s", dx, dy))

-- A game window's y on its anchor: the manager's own plus the shift, once, however many passes.
local panel = {}
local y1 = ns.GameRowY(panel, -116, 1)
local y2 = ns.GameRowY(panel, y1, 1)
Check(Near(y1, -316) and Near(y2, -316), string.format("the y rides the shift once: %s then %s", y1, y2))
-- The manager lays it anew (its own y back): the shift goes on top of that one.
Check(Near(ns.GameRowY(panel, -120, 1), -320), "a new manager y takes the shift")
-- In its own units at a scale of 2: half the shift.
Check(Near(ns.GameRowY({}, -58, 2), -158), "the shift in the window's own units")

-- In the row on the game's line and on the box's, out of it far from both.
local function Panel(top, height)
    return { GetTop = function() return top end, GetHeight = function() return height end,
        GetEffectiveScale = function() return 1 end, GetAttribute = function() return nil end,
        GetName = function() return "CharacterFrame" end }
end
Check(not ns.GameWindowOffRow(Panel(H - 116, 450)), "on the game's line: in the row")
Check(not ns.GameWindowOffRow(Panel(H - 316, 450)), "on the box's line, 200 down: in the row")
Check(ns.GameWindowOffRow(Panel(H - 500, 450)), "far under both: out of the row")

-- Reset: the box's place gone, no shift again.
ns.db.windowPos.windowRow = nil
dx, dy = ns.WindowRowShift()
Check(dx == 0 and dy == 0, "reset: no shift")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("window_row_box_test: all checks passed")
