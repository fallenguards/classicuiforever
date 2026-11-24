-- Offline test under Lua 5.4 for game windows another addon moves (MoveAny), with the real hand-off code cut out of
-- UI/GameSpot.lua (ns.MoverTakes, ns.MoverHolds), Social/GroupFinder.lua (YieldToMover) and UI/WindowsEditMode.lua
-- (HeldBy, RowTip, SyncHeld) and run.
-- #338: MoveAny drags the group finder by its own mouse press, and our art's frame over the window took that press, so
-- neither moved it. #336: our Edit Mode list offered a held window's row, and ticking it did nothing and said nothing
-- (/fcuidev groupclick rows TEST: 7 such rows, 2026-11-24). The game's click rule is modelled: a press goes to the
-- topmost frame under the mouse that takes clicks, and a window's own hook runs only when the press reaches it.
-- Run from the addon root: lua tools/tests/mover_handoff_test.lua (CI runs every tools/tests/*_test.lua).
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

local function Frame(name)
    local f = { name = name, mouse = true, writes = 0 }
    function f:GetName() return self.name end
    function f:IsMouseEnabled() return self.mouse end
    function f:EnableMouse(on)
        self.writes = self.writes + 1
        self.mouse = on and true or false
    end
    return f
end

-- The game's click rule for a window with our art's frame laid over it: the art's frame is on top.
local function Press(window, art)
    if art.mouse then return art end
    if window.mouse then
        if window.hook then window.hook() end
        return window
    end
    return nil
end

local game = {}
local ns = { db = { leaveGameWindows = false },
    WINDOW_LIST = { { key = "groupFinder", name = "LFGParentFrame", client = true }, { key = "spellbook", name = "OurBook" } } }
local env = setmetatable({ ns = ns, _G = game }, { __index = function(_, k) return game[k] ~= nil and game[k] or _G[k] end })
assert(load(Cut("/UI/GameSpot.lua", "-- A window mover took this game window", "-- A window's scale against UIParent's"),
    "game spot", "t", env))()
local Yield = assert(load(Cut("/Social/GroupFinder.lua", "local function YieldToMover", "local watcher")
    .. "\nreturn YieldToMover", "yield", "t", env))()

------------------------------------------------------------------ #338: the press reaches the window a mover holds

local finder, art = Frame("LFGParentFrame"), Frame(nil)
game.LFGParentFrame = finder
local dragged = 0
finder.hook = function() dragged = dragged + 1 end

Yield(art, finder)
Check(art.mouse and Press(finder, art) == art, "no mover: our art's frame takes the click (its strip is not the world)")

-- MoveAny takes the finder: it makes LFGParentFrameMove and hooks the window's own press.
game.LFGParentFrameMove = {}
Yield(art, finder)
Check(not art.mouse, "MoveAny holds the finder: our art's frame stops taking clicks")
Check(Press(finder, art) == finder and dragged == 1, "and a press on the window reaches MoveAny's hook (the drag starts)")
local writes = art.writes
Yield(art, finder)
Yield(art, finder)
Check(art.writes == writes, "the pass runs ten times a second: no write while nothing changed")

-- Leave game windows to other addons on, no mover: still handed off, the press reaches the window.
game.LFGParentFrameMove = nil
ns.db.leaveGameWindows = true
Yield(art, finder)
Check(not art.mouse, "left to other addons by the setting: our art's frame lets the press through too")
ns.db.leaveGameWindows = false
Yield(art, finder)
Check(art.mouse, "the setting off again and no mover: ours takes clicks again")

------------------------------------------------------------------ #336: a held window's row in our Edit Mode list

local L = { UI_WINDOW_HELD_MOVER = "moved by another addon", UI_WINDOW_HELD_LEFT = "left by the setting" }
local frames = { groupFinder = finder, spellbook = Frame("OurBook") }
ns.WindowFrame = function(entry) return frames[entry.key] end
local env2 = setmetatable({ ns = ns, L = L, Label = function(entry) return "Label " .. entry.key end }, { __index = _G })
local HeldBy, RowTip, SyncHeld = assert(load(Cut("/UI/WindowsEditMode.lua", "-- Why another addon has a window",
    "-- top: in the window's units") .. "\nreturn HeldBy, RowTip, SyncHeld", "rows", "t", env2))()

local function Row(entry)
    local row = { entry = entry, enabled = true, checked = false, color = { 1, 1, 1 } }
    function row:SetEnabled(on) self.enabled = on end
    function row:SetChecked(on) self.checked = on and true or false end
    row.label = { SetTextColor = function(_, r, g, b) row.color = { r, g, b } end }
    return row
end
local finderRow = Row(ns.WINDOW_LIST[1])
local bookRow = Row({ key = "spellbook", name = "OurBook",
    tipSpec = { text = "Book", lines = { { "the book's own tip" } } } })
local picked = { groupFinder = true, spellbook = true }

SyncHeld(finderRow, picked)
SyncHeld(bookRow, picked)
Check(finderRow.enabled and finderRow.checked and finderRow.color[1] == 1, "no mover: the finder's row is ours, ticked")
Check(HeldBy(finderRow.entry) == nil, "and says nothing of another addon")

game.LFGParentFrameMove = {}
SyncHeld(finderRow, picked)
SyncHeld(bookRow, picked)
Check(not finderRow.enabled and not finderRow.checked and finderRow.color[1] == 0.5,
    "MoveAny holds the finder: its row grayed and unticked, not offered")
local tip = RowTip(finderRow.entry)
Check(tip.text(finderRow) == "Label groupFinder" and tip.lines[1][1](finderRow) == L.UI_WINDOW_HELD_MOVER,
    "its tip names the window and says another addon moves it")
Check(bookRow.enabled and bookRow.checked, "our own window's row stays ours (a mover never takes ours)")
local bookTip = RowTip(bookRow.entry)
Check(bookTip.text(bookRow) == "Book" and bookTip.lines[1][1](bookRow) == "the book's own tip",
    "our window's row keeps its own tip")

game.LFGParentFrameMove = nil
ns.db.leaveGameWindows = true
SyncHeld(finderRow, picked)
Check(not finderRow.enabled and RowTip(finderRow.entry).lines[1][1](finderRow) == L.UI_WINDOW_HELD_LEFT,
    "left to other addons by the setting: grayed, and the tip names the setting")
ns.db.leaveGameWindows = false
SyncHeld(finderRow, picked)
Check(finderRow.enabled and finderRow.checked and finderRow.color[1] == 1, "the setting off: the row is ours again")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("mover_handoff_test: ok")
