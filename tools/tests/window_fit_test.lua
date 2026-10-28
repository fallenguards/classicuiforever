-- Offline test under Lua 5.4 for a window's size kept inside the screen (UI/GameSpot.lua ns.ScreenFitScale, and the map's
-- fight lay, Map/WorldMapFight.lua MapPlace): a size saved in another look or UI scale never lays it past the screen.
-- 134% on the Classic map's 768 tall sheet ran 1029 tall on a screen 853 tall at UI scale 0.9 (2026-10-28).
-- Run from the addon root: lua tools/tests/window_fit_test.lua (CI runs every tools/tests/*_test.lua).
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
local function Near(a, b) return a and math.abs(a - b) < 0.001 end

local function Read(path)
    local handle = assert(io.open(ROOT .. "/" .. path, "r"))
    local text = handle:read("a")
    handle:close()
    return text
end
local function Cut(source, from, to)
    local first = source:find(from, 1, true)
    local last = first and source:find(to, first, true)
    assert(first and last, "the code to test is where it was: " .. from)
    return source:sub(first, last - 1)
end

local SCREEN_W, SCREEN_H, UI = 1560, 853, 0.9
local ui = { GetSize = function() return SCREEN_W, SCREEN_H end, GetEffectiveScale = function() return UI end }
local ns = { Safe = function(v) return v end }
local env = setmetatable({ ns = ns, UIParent = ui, Plain = ns.Safe }, { __index = _G })
assert(load(Cut(Read("UI/GameSpot.lua"), "function ns.WindowRatio", "-- A window's spot from a row start")
    .. "\nfunction ns.Fit(...) return ns.ScreenFitScale(...) end", "fit", "t", env))()

local function Window(scale, parentScale)
    return { GetScale = function() return scale end,
        GetEffectiveScale = function() return scale * (parentScale or 1) * UI end }
end

-- The Classic map at 134% on its 1002 x 768 sheet.
Check(Near(ns.Fit(Window(1.34), 1.34, 1002, 768), SCREEN_H / 768), "134% on the 768 tall sheet fits the screen's height")
Check(Near(ns.Fit(Window(1), 0.8, 1002, 768), 0.8), "a size that fits stays")
Check(Near(ns.Fit(Window(1), 1.5, 1300, 500), SCREEN_W / 1300), "a wide one fits the screen's width")
-- Under a scaled parent (half size), the same window may be twice as big.
Check(Near(ns.Fit(Window(1, 0.5), 1.5, 1002, 768), 1.5), "a scaled parent's room counts")
Check(ns.Fit(Window(1), 1.2, nil, nil) == 1.2, "no size read, no change")

-- The fight lay's own reckoning of the map's scale.
local scales = { map = 1.34 }
ns.windowEdit = {
    ByKey = { map = { key = "map" } }, Worn = function() return true end, Scales = function() return scales end,
    SizeKey = function(entry) return entry.key end, PlaceOf = function() return 16, 737 end,
}
local MapPlace = assert(load(Cut(Read("Map/WorldMapFight.lua"), "local function MapPlace", "-- Out of combat, last")
    .. "\nreturn MapPlace", "map", "t", env))()
local k, left, top = MapPlace(1002, 768, 0.6)
Check(Near(k, SCREEN_H / 768), "in a fight the map fits the screen too")
Check(left == 16 and Near(top, SCREEN_H), "and stands inside it")
scales.map = nil
Check(Near(MapPlace(1002, 768, 0.6), 0.6), "no size of the player's: the style's own")

if failed > 0 then os.exit(1) end
print("window fit: ok")
