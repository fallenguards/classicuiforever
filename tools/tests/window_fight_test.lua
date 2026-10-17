-- Offline test under Lua 5.4 for the window row in a fight (UI/WindowRow.lua ns.LayFightWindows with the row solver):
-- the game's side windows stand as its manager lays them out of one (by pushable, then opening; its spacing and x
-- offsets), the classic sheet on Era's spot, round windows that cannot move; ours past them. The expected spots are
-- the out-of-fight ones /fcuidev fightwindows read in game (social 16, the sheet 370 beside it, ours at 722).
-- Run from the addon root: lua tools/tests/window_fight_test.lua (CI runs every tools/tests/*_test.lua).
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

local ns = {}
assert(loadfile(ROOT .. "/UI/WindowRow.lua"))("ClassicUIForever", ns)

local START, GAP, SCREEN = 16, 32, 1536

-- The game's windows: social (pushable 0, 338 wide), the classic sheet (pushable 3; Era's step 16 left, 352 drawn).
local function Social(opened) return { width = 338, xoff = 0, pushable = 0, opened = opened } end
local function Sheet(opened) return { width = 338, xoff = 0, pushable = 3, opened = opened, shift = -16, drawn = 352 } end
local function Other(opened, pushable) return { width = 338, xoff = 0, pushable = pushable or 0, opened = opened } end

local function Lay(members, fixed)
    return ns.LayFightWindows({ start = START, gap = GAP, screen = SCREEN, members = members, fixed = fixed or {} }, {})
end

-- Drawn left of member i.
local function At(members, x, i) return x[i] + (members[i].shift or 0) end

local m = { Social(1) }
local x = Lay(m)
Check(At(m, x, 1) == 16, "social alone: the game's left spot, got " .. tostring(At(m, x, 1)))

m = { Sheet(1) }
x = Lay(m)
Check(At(m, x, 1) == 0, "the sheet alone: Era's spot, got " .. tostring(At(m, x, 1)))

-- Either order opened: social left, the sheet beside it, as out of a fight.
for _, order in ipairs({ { 1, 2 }, { 2, 1 } }) do
    m = { Sheet(order[1]), Social(order[2]) }
    x = Lay(m)
    Check(At(m, x, 2) == 16 and At(m, x, 1) == 370, string.format("sheet %d, social %d: social 16, sheet 370; got %s, %s",
        order[1], order[2], tostring(At(m, x, 2)), tostring(At(m, x, 1))))
end

-- Equal pushable: the order opened.
m = { Social(2), Other(1) }
x = Lay(m)
Check(At(m, x, 2) == 16 and At(m, x, 1) == 16 + 338 + GAP, "equal pushable: the first opened on the left")

-- A third: past the sheet's drawn edge, the game's spacing on.
m = { Social(1), Sheet(2), Other(3, 5) }
x = Lay(m)
Check(At(m, x, 3) == 370 + 352 + GAP, "a third past the sheet's drawn edge, got " .. tostring(At(m, x, 3)))

-- The middle one closed: the third slides into its room.
m = { Social(1), Other(3, 5) }
x = Lay(m)
Check(At(m, x, 2) == 16 + 338 + GAP, "the middle one closed: the third slides left, got " .. tostring(At(m, x, 2)))

-- A window that cannot move (the spellbook held over its casting buttons): the rest stand past it, never over it.
-- Flush past a held one of ours (as ours stand flush against the game's), the game's spacing past a locked game window.
m = { Social(1) }
x = Lay(m, { { 0, 392, 0 } })
Check(At(m, x, 1) == 392, "flush past the held spellbook, got " .. tostring(At(m, x, 1)))
m = { Sheet(1) }
x = Lay(m, { { 0, 392, 0 } })
Check(At(m, x, 1) == 392, "the sheet flush past the held spellbook (fight 2 stood it 32 off), got " .. tostring(At(m, x, 1)))
m = { Social(1) }
x = Lay(m, { { 0, 384 } })
Check(At(m, x, 1) == 384 + GAP, "past a locked game window, its spacing, got " .. tostring(At(m, x, 1)))
m = { Social(1), Sheet(2) }
x = Lay(m, { { 360, 752 } })
Check(At(m, x, 2) >= 752 and At(m, x, 1) == 16, "the sheet past a held window where it would stand, got "
    .. tostring(At(m, x, 2)))

-- Its own x offset; the screen's edge.
m = { { width = 338, xoff = -4, pushable = 0, opened = 1 } }
x = Lay(m)
Check(At(m, x, 1) == 12, "its own x offset, got " .. tostring(At(m, x, 1)))
m = { Social(1), Other(2), Other(3), Other(4), Other(5) }
x = Lay(m)
Check(At(m, x, 5) + 338 <= SCREEN, "the last stays on the screen, got " .. tostring(At(m, x, 5)))

-- Past a window drawn narrower than the game's width for it (the professions book, 339 of 376, x offset -4): the
-- sheet its spacing past the drawn edge, Era's step left: 367, not 408 (the reference's hole).
m = { { width = 376, drawn = 339, xoff = -4, pushable = 0, opened = 1 }, Sheet(2) }
x = Lay(m)
Check(At(m, x, 1) == 12 and At(m, x, 2) == 367, "the sheet past the professions book's drawn edge, got "
    .. tostring(At(m, x, 2)))

-- Ours stand past the laid row: past the sheet beside social, at 722 as out of a fight.
m = { Social(1), Sheet(2) }
x = Lay(m)
local s = { start = 0, screen = SCREEN, ours = { { width = 352, drawn = 384 } },
    game = { { At(m, x, 1), At(m, x, 1) + 338, "FriendsFrame" }, { At(m, x, 2), At(m, x, 2) + 352, "CharacterFrame" } } }
local laid = ns.SolveWindowRow(s, {})
Check(laid.x[1] == 722, "ours past the sheet, got " .. tostring(laid.x[1]))

-- The double pane quest log takes its whole 680 (its slot width): the next of ours stands past it.
s = { start = 0, screen = SCREEN, game = {}, ours = { { width = 680, drawn = 680 }, { width = 352, drawn = 384 } } }
laid = ns.SolveWindowRow(s, {})
Check(laid.x[2] == 680, "past the double quest log, got " .. tostring(laid.x[2]))

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("window_fight_test: ok")
