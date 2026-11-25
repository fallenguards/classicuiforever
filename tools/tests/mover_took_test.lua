-- Offline test under Lua 5.4 for a window a mover takes (UI/GameSpot.lua ns.MoverTakes, ns.MoverTook, ns.MoverHolds;
-- UI/WindowsEditMode.lua HeldBy). A window mover makes its <window>Move frame at a window's first show of a session, so
-- before that show our edit mode offered the row and its size did nothing (#336, proven 2026-11-25: the group finder
-- stayed at 1.00 with our box at 120%). Seen once, the take is remembered: the next session holds the window from the
-- start and the row says why; a window that stands shown 2 s with no mover's frame is free again.
-- Run from the addon root: lua tools/tests/mover_took_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 122 212 431 432

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local failed = 0
local function Check(ok, what)
    print((ok and "PASS " or "FAIL ") .. what)
    if not ok then failed = failed + 1 end
end

local function Cut(path, from, to)
    local handle = assert(io.open(ROOT .. path, "r"))
    local source = handle:read("a")
    handle:close()
    local first = source:find(from, 1, true)
    local last = first and source:find(to, first, true)
    assert(first and last, path .. ": the code to test is in the file")
    return source:sub(first, last + #to - 1)
end

local now = 0
local db = {}
local ns = { db = db, WINDOW_LIST = { { key = "groupFinder", name = "LFGParentFrame", client = true } } }
local frames = {}
local env = setmetatable({ ns = ns, GetTime = function() return now end, UIPanelWindows = {} }, { __index = _G })
rawset(env, "_G", env)
local L = { UI_WINDOW_HELD_MOVER = "mover", UI_WINDOW_HELD_LEFT = "left" }
ns.WindowFrame = function(entry) return frames[entry.name] end

-- From the mover's note to the end of ns.MoverHolds, whatever that function holds.
local function CutThrough(path, from, fn)
    local handle = assert(io.open(ROOT .. path, "r"))
    local source = handle:read("a")
    handle:close()
    local first = source:find(from, 1, true)
    local at = first and source:find(fn, first, true)
    local last = at and source:find("\nend", at, true)
    assert(first and last, path .. ": the code to test is in the file")
    return source:sub(first, last + 3)
end
assert(load("local ns = ...\n" .. CutThrough("/UI/GameSpot.lua", "-- A window mover took this game window",
    "function ns.MoverHolds("), "@UI/GameSpot.lua", "t", env))(ns)
ns.MoverTook = ns.MoverTook or function() return false end
local HeldBy = assert(load("local ns, L = ...\n" .. Cut("/UI/WindowsEditMode.lua", "local function HeldBy(entry)",
    "\nend") .. "\nreturn HeldBy", "@UI/WindowsEditMode.lua", "t", env))(ns, L)

local entry = ns.WINDOW_LIST[1]
local function Window(shown)
    local f = { shown = shown }
    function f:GetName() return "LFGParentFrame" end
    function f:IsShown() return self.shown end
    frames.LFGParentFrame = f
    return f
end

-- Session 1: the finder not made yet, nothing known: the row is ours.
Check(HeldBy(entry) == nil, "nothing known before any show: the row is ours")
-- It shows; the mover takes it.
Window(true)
rawset(env, "LFGParentFrameMove", {})
Check(HeldBy(entry) == "mover", "taken at its show: the row says a mover holds it")
Check(ns.MoverTook("LFGParentFrame"), "and the take is remembered")

-- Session 2: no mover's frame yet, the finder not made: held from the start.
rawset(env, "LFGParentFrameMove", nil)
frames.LFGParentFrame = nil
Check(ns.MoverHolds(nil, "LFGParentFrame") == true, "next session, before its show: held")
Check(HeldBy(entry) == "mover", "and our edit mode's row is grayed with the reason before the window ever shows")
finder = Window(false)
Check(ns.MoverHolds(finder) == true, "made but not shown yet: still held")

-- The mover gone: the window stands shown with no mover's frame; free again after 2 s.
finder.shown = true
now = 10
Check(ns.MoverHolds(finder) == true, "shown with no mover's frame: held for now")
now = 11
ns.MoverHolds(finder)
now = 12.5
Check(ns.MoverHolds(finder) == false, "2 s shown with no mover's frame: free again")
Check(HeldBy(entry) == nil, "and the row is ours again")

-- Left to other addons by our own setting: still said so, by name too.
db.leaveGameWindows = true
Check(HeldBy(entry) == "left", "Leave game windows to other addons: the row says that")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("mover_took_test: ok")
