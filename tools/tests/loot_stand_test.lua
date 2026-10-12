-- Offline test under Lua 5.4 for where a floating client window stands (ns.WindowRowEnd in UI/WindowRow.lua): the loot
-- window on its default spot goes past every window in the row, as Era's packed panel row put it. A gap left of an open
-- window is not past it: the loot window stood left of a character sheet in the second slot (2026-10-11).
-- Run from the addon root: lua tools/tests/loot_stand_test.lua (CI runs every tools/tests/*_test.lua).
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

-- The loot window, 250 wide, past a solved row on a 1536 screen.
local function Past(game, ours)
    local s = { start = 0, screen = 1536, game = game, ours = ours or {} }
    return ns.WindowRowEnd(s, ns.SolveWindowRow(s, {}), 250)
end

Check(Past({}) == 0, "nothing open: the first slot")
Check(Past({ { 290, 674, "CharacterFrame" } }) == 674, "the sheet in the second slot: past it, not in the gap left of it")
Check(Past({ { 384, 768, "CharacterFrame" } }, { { width = 384, drawn = 384, held = 0 } }) == 768,
    "two windows side by side: past both")
Check(Past({ { 0, 352, "CharacterFrame" } }, { { width = 352, drawn = 384 } }) == 704, "past ours standing past the sheet")
Check(Past({ { 0, 384, "CharacterFrame" }, { 0, 1536, "WorldMapFrame" } }) == 384, "a full-screen window is not stood past")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("loot_stand_test: ok")
