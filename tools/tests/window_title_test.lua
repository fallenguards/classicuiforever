-- Offline test under Lua 5.4 for a dressed window's title line (Windows/WindowChrome.lua PlaceTitle). A plain window
-- (no portrait ring) centres its title in its stone strip, which ends at the X: the title stopped 58 in, a ring window's
-- room, and sat 16 left of the strip's middle (the loot history window's Loot Rolls, 2026-11-21). A maximize button beside
-- the X (the map) keeps the 58, as do ring windows.
-- Run from the addon root: lua tools/tests/window_title_test.lua (CI runs every tools/tests/*_test.lua).
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

local source = assert(io.open(ROOT .. "/Windows/WindowChrome.lua")):read("a")
local block = source:match("\n(local TITLE_SIDE, STRIP_RIGHT = .-\nlocal function PlaceTitle%(frame, plain, left, span%)\n.-\nend)\n")
Check(block ~= nil, "PlaceTitle and its sizes are found")
if not block then
    print(failed .. " check(s) failed")
    os.exit(1)
end
local PlaceTitle = assert(load(block .. "\nreturn PlaceTitle", "PlaceTitle", "t", {}))()

local function Region()
    local r = { points = {} }
    function r.ClearAllPoints(self) self.points = {} end
    function r.SetPoint(self, point, _, _, x, y) self.points[point] = { x, y } end
    return r
end
local function Window(maxButton)
    local frame = { TitleContainer = Region(), fcui = { titleStrip = Region() } }
    if maxButton then frame.MaximizeMinimizeButton = {} end
    return frame
end
-- Each side's room from the window's edge, so a title's middle can be told against its strip's.
local function Middle(region) return (region.points.TOPLEFT[1] - region.points.TOPRIGHT[1]) / 2 end

local plain = Window(false)
PlaceTitle(plain, true, 9)
local title, strip = plain.TitleContainer.points, plain.fcui.titleStrip.points
Check(title.TOPLEFT[1] == 9 and title.TOPRIGHT[1] == -25, "a plain window's title runs from its corner line to the X")
Check(Middle(plain.TitleContainer) == Middle(plain.fcui.titleStrip) - 0 and strip.TOPRIGHT[1] == -25
    and strip.TOPLEFT[1] == 9, "so the title stands in the middle of its strip")

local map = Window(true)
PlaceTitle(map, true, 9)
Check(map.TitleContainer.points.TOPRIGHT[1] == -58, "a plain window with a maximize button keeps room for both buttons")

local ring = Window(false)
PlaceTitle(ring, false, 9)
Check(ring.TitleContainer.points.TOPLEFT[1] == 58 and ring.TitleContainer.points.TOPRIGHT[1] == -58,
    "a ring window's title stays between the ring and the X")

local spanned = Window(false)
PlaceTitle(spanned, false, 9, { 72, -42 })
Check(spanned.TitleContainer.points.TOPLEFT[1] == 72 and spanned.TitleContainer.points.TOPRIGHT[1] == -42,
    "a window's own title line (the book's) wins")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("window_title_test: ok")
