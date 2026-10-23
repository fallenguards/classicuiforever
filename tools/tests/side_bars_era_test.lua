-- Offline test under Lua 5.4 for bars 4 and 5 at Era's spot (Bar/BandBars.lua SideTop, ns.KeepSideBarSpot): Era's
-- edit mode (UpdateRightActionBarPositions) hangs bar 4 on the screen's right edge with its middle 35 under the
-- screen's, at any icon size; ours hung both from the bottom right corner 98 up, as 1.12 did. An install from before
-- keeps that spot (dbVersion 27) until the classic layout button.
-- Run from the addon root: lua tools/tests/side_bars_era_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local failed = 0
local function Check(ok, what)
    if not ok then
        failed = failed + 1
        print("FAIL " .. what)
    end
end

local handle = assert(io.open(ROOT .. "/Bar/BandBars.lua", "r"))
local source = handle:read("a")
handle:close()
local first = source:find("local ERA_SIDE_Y", 1, true)
local last = first and source:find("local function SideColumn", first, true)
assert(first and last, "the side bar spot is in Bar/BandBars.lua")

local ns = { db = {} }
local env = setmetatable({ ns = ns }, { __index = _G })
local SideTop, Gap = assert(load("local BUTTON_PITCH, BUTTON_SIZE, SIDE_BAR_Y = 42, 36, 98\nlocal SIDE_COL_H = 12 * BUTTON_PITCH\n"
    .. source:sub(first, last - 1) .. "\nreturn SideTop, ERA_SIDE_GAP", "side", "t", env))()

-- Era's: the column (12 buttons 36 high, 6 apart: 498) centred 35 under the screen's middle at any icon size.
ns.db.sideBarsEra = true
for _, icon in ipairs({ 1, 0.8, 1.5 }) do
    local point, top = SideTop(icon)
    local middle = top * icon - 498 * icon / 2
    Check(point == "RIGHT" and math.abs(middle - -35) < 0.001, "Era: the column's middle 35 under the screen's at icon " .. icon)
end
Check(Gap == 7, "Era: bar 5 stands 7 beside bar 4")

-- Before: from the bottom right corner, its top 98 + 12 pitches up.
ns.db.sideBarsEra = false
local point, top = SideTop(1)
Check(point == "BOTTOMRIGHT" and top == 98 + 504, "1.12's spot kept for an install from before")

-- The migration: an install from before keeps 1.12's spot, a pick already made stays, profiles too.
ns.db = { profiles = { a = {}, b = { sideBarsEra = true } } }
ns.KeepSideBarSpot()
Check(ns.db.sideBarsEra == false and ns.db.profiles.a.sideBarsEra == false, "an install from before keeps 1.12's spot")
Check(ns.db.profiles.b.sideBarsEra == true, "a profile's own pick stays")
Check(ns.db.dbVersion == 27, "the migration writes dbVersion 27")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("side_bars_era_test: all checks passed")
