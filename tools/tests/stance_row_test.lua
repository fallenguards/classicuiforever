-- Offline test under Lua 5.4 for the band's stance, possess and pet row at Era's spots (Bar/BandBars.lua, Bar/ClassicBar.lua):
-- Era's x, spacing and gap over bar 2 (EditModePresetLayouts, UIParentManageFramePositions), the row down on the band's top
-- while bar 2's spot is free, and Era's backing pieces by form count (StanceBar.xml, StanceBarOverrides.lua).
-- Run from the addon root: lua tools/tests/stance_row_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local failed = 0
local function Check(ok, what)
    if not ok then
        failed = failed + 1
        print("FAIL: " .. what)
    end
end

local function Source(path)
    local handle = assert(io.open(ROOT .. "/" .. path, "r"))
    local text = handle:read("a")
    handle:close()
    return text
end

local bars, classic = Source("Bar/BandBars.lua"), Source("Bar/ClassicBar.lua")

------------------------------------------------------------------ Era's numbers

Check(bars:find("local STANCE_X, PET_X, SMALL_BUTTON = 41.5, 71, 30\n", 1, true) ~= nil,
    "stance and possess at Era's 41.5, the pet bar at its 71 (band px)")
Check(bars:find("local STANCE_PITCH, PET_PITCH = 37, 38\n", 1, true) ~= nil,
    "Era's spacing: 7 between stance buttons, 8 between pet buttons")
Check(classic:find("local SMALL_GAP, SMALL_ROW_Y = 7, 56\n", 1, true) ~= nil,
    "7 over the bar under it, or 56 up with its backing on the band's 53 px top")

------------------------------------------------------------------ the stacking

Check(classic:find("if lowerOn and not onLine then rowY, free = overLower, false end", 1, true) ~= nil,
    "bar 2 on the band takes the row up and its backing off")
Check(classic:find("if upperOn and upper:IsShown() and underRow then", 1, true) ~= nil,
    "bar 3 lifts the row only where it runs under it")
Check(classic:find("local underRow = upperX < B.PetRowEnd()", 1, true) ~= nil, "under the row: bar 3 starts before it ends")
Check(classic:find("LayoutPetRow(rowY, high, free)", 1, true) ~= nil, "the row is laid at its foot, free or not")
Check(bars:find("DrawBacking(bar, pinned and free and x == STANCE_X and BackingFits(bar))", 1, true) ~= nil,
    "a stance or possess backing only at Era's spot, nothing before it")
Check(bars:find("DrawBacking(PetActionBar, pinned and free and own and BackingFits(PetActionBar))", 1, true) ~= nil,
    "the pet backing only with the pet bar on its own spot")
Check(bars:find("own and y - 1 or y", 1, true) ~= nil, "Era's pet bar stands 1 under the stance bar")
Check(bars:find("return (size == nil or size == 100) and B.PadGap(bar, SMALL_BUTTON) == 0 and not B.BarBare(", 1, true) ~= nil,
    "the backing fits only Era's size and spacing, and goes with Hide Bar Art")

------------------------------------------------------------------ the backing's pieces by form count

local body = bars:match("local function DressStance%(back, forms, possess%)\n(.-)\nend\n")
Check(body ~= nil, "DressStance is found")
local placed
local env = setmetatable({
    B = { BAND_RUN = {} },
    ns = { Dress = function(tex, key, _, _, x, y, w, h) placed[tex] = { key = key, x = x, y = y, w = w, h = h } end },
}, { __index = _G })
local DressStance = assert(load("local back, forms, possess = ...\n" .. (body or ""), "DressStance", "t", env))

local function Run(forms, possess)
    placed = {}
    local back = { left = {}, right = {}, middles = {} }
    function back.CreateTexture() return {} end
    local middles = DressStance(back, forms, possess)
    return back, middles
end

local back, middles = Run(1)
Check(placed[back.left].x == -11 and placed[back.left].y == -3 and placed[back.left].w == 47, "left end: Era's -11, -3, 47 wide")
Check(placed[back.right].x == 1 and middles == 0, "one form: the right end 12 into the left one, no middle")
back, middles = Run(2)
Check(placed[back.right].x == 37 and middles == 0, "two forms: the right end 1 past the left one")
back, middles = Run(5)
Check(middles == 3, "five forms: a middle per form after the second")
Check(placed[back.middles[1]].x == 36 and placed[back.middles[3]].x == 110 and placed[back.middles[2]].w == 37,
    "middles 37 apart from the left end's edge")
Check(placed[back.right].x == 147 and placed[back.right].key == "stanceBar", "the right end past the last middle")
back, middles = Run(0, true)
Check(placed[back.right].x == 36 and middles == 0, "possess: the two ends side by side")

if failed > 0 then
    print(string.format("stance row: %d failed", failed))
    os.exit(1)
end
print("stance row: ok")
