-- Offline test under Lua 5.4 for the windows' row (ns.SolveWindowRow in UI/WindowRow.lua): the game's windows stay
-- where the game put them and ours stand past the last in the order opened, whatever order they opened in (#154);
-- the row starts where the game's does; a held window stays; out of a fight the oldest of ours closes for room.
-- Run from the addon root: lua tools/tests/window_row_test.lua (CI runs every tools/tests/*_test.lua).
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
local Solve = ns.SolveWindowRow

-- Era's old windows: 352 of room in the row, 384 drawn.
local function Ours(extra)
    local w = { width = 352, drawn = 384 }
    for k, v in pairs(extra or {}) do w[k] = v end
    return w
end

local function Row(start, screen, game, ours, stay)
    return Solve({ start = start, screen = screen, game = game, ours = ours, stay = stay }, {})
end

local function Xs(out, n)
    local list = {}
    for i = 1, n do list[i] = tostring(out.x[i]) end
    return table.concat(list, ", ")
end

local out = Row(0, 1920, {}, { Ours() })
Check(out.x[1] == 0, "alone: the row's start")
out = Row(0, 1920, {}, { Ours(), Ours() })
Check(out.x[1] == 0 and out.x[2] == 352, "two of ours side by side in the order opened: " .. Xs(out, 2))

-- #154: a layout addon starts the game's row at 540 (Era's spot 524); the sheet stands there, 352 of art.
local SCREEN, START = 2141, 524
local sheet = { 524, 876, "CharacterFrame" }
out = Row(START, SCREEN, { sheet }, { Ours() })
Check(out.x[1] == 876, "#154 sheet then spellbook: the book past the sheet, not at the screen's edge: " .. Xs(out, 1))
out = Row(START, SCREEN, { sheet }, { Ours(), Ours() })
Check(out.x[1] == 876 and out.x[2] == 1228, "#154 sheet, talents, spellbook: one row: " .. Xs(out, 2))
local finish = ns.WindowRowEnd({ start = START, screen = SCREEN, game = { sheet }, ours = { Ours(), Ours() } }, out, 250)
Check(finish == 1580, "the row's end past the last of ours: " .. tostring(finish))
out = Row(START, SCREEN, {}, { Ours(), Ours() })
Check(out.x[1] == 524 and out.x[2] == 876, "#154 talents then spellbook alone: from the game's row start: " .. Xs(out, 2))
out = Row(START, SCREEN, { sheet }, { Ours(), Ours() })
Check(out.x[1] == 876 and out.x[2] == 1228, "#154 talents, spellbook, then the sheet: ours step past it: " .. Xs(out, 2))

-- The game's windows in the row, wherever the game stood them: ours past the last, never in a gap between.
out = Row(0, 1920, { { 0, 352, "CharacterFrame" }, { 700, 1050, "MacroFrame" } }, { Ours() })
Check(out.x[1] == 1050, "past the game's last window, not in the gap before it: " .. Xs(out, 1))

out = Row(0, 1920, { { 0, 600, "ProfessionsFrame" } }, { Ours({ shares = { ProfessionsFrame = true } }) })
Check(out.x[1] == 0, "a window that shares a place with a game one takes that place")

out = Row(0, 1920, { { 0, 1900, "WorldMapFrame" } }, { Ours() })
Check(out.x[1] == 0, "a game window too wide to share the screen with is left out")

out = Row(0, 1920, {}, { Ours({ keep = 700 }) })
Check(out.x[1] == 700, "a window kept beside a game one stands past it")

-- Held (the spellbook over its casting layer in a fight): it stays, the rest stand clear of it.
out = Row(0, 1920, {}, { Ours(), Ours({ held = 0 }) })
Check(out.x[1] == 352 and out.x[2] == 0, "held at the start: the older one stands past it: " .. Xs(out, 2))
out = Row(0, 1920, { { 0, 352, "CharacterFrame" } }, { Ours({ held = 0 }) }, true)
Check(out.x[1] == 0, "held: kept even where a game window stands")

-- No room past the screen's right edge.
local narrow = { { 0, 352, "CharacterFrame" } }
out = Row(0, 1100, narrow, { Ours(), Ours(), Ours() })
Check(out.close[1] == 1 and #out.close == 1, "out of a fight the oldest of ours closes for room")
Check(out.x[1] == nil and out.x[2] == 352 and out.x[3] == 704, "the rest step left into its room: " .. Xs(out, 3))
out = Row(0, 1100, narrow, { Ours(), Ours(), Ours() }, true)
Check(#out.close == 0, "in a fight nothing closes")
Check(out.x[3] == 716, "in a fight the last stands at the screen's edge: " .. Xs(out, 3))
out = Row(0, 1200, { { 800, 1152, "CharacterFrame" } }, { Ours() })
Check(#out.close == 0 and out.x[1] == 816, "only the game in the way: back on the screen, nothing closed: " .. Xs(out, 1))
out = Row(0, 1100, narrow, { Ours({ held = 352 }), Ours(), Ours() })
Check(out.close[1] == 2 and out.x[1] == 352, "a held window never closes; the next oldest does: " .. Xs(out, 3))

-- The game's window opened last (CurseForge: sheet, quest log, then the game's talents): ours give way to it.
local function GameLast(game, ours, screen)
    return Solve({ start = 0, screen = screen, game = game, ours = ours, gameLast = true }, {})
end
local talentsAfterSheet = { { 0, 352, "CharacterFrame" }, { 384, 1250, "PlayerSpellsFrame" } }
out = GameLast(talentsAfterSheet, { Ours() }, 1366)
Check(out.close[1] == 1 and out.x[1] == nil, "no room past the game's newest window: our quest log shuts, not pushed over it")
out = GameLast(talentsAfterSheet, { Ours() }, 1920)
Check(#out.close == 0 and out.x[1] == 1250, "room past it: our quest log stands after the game's window: " .. Xs(out, 1))
out = GameLast(talentsAfterSheet, { Ours(), Ours() }, 1366)
Check(#out.close == 2, "no room for any of ours: all shut, oldest first")
out = Row(0, 1366, talentsAfterSheet, { Ours() })
Check(#out.close == 0 and out.x[1] == 982, "ours opened last keeps the newest: back on the screen, not shut: " .. Xs(out, 1))

-- A closed window's trial (its spot before a fight): past the open ones, nothing closed.
out = Row(0, 1100, narrow, { Ours(), Ours(), Ours() }, true)
Check(#out.close == 0, "a trial closes nothing")

if failed > 0 then
    print(failed .. " failed")
    os.exit(1)
end
print("window_row_test: all passed")
