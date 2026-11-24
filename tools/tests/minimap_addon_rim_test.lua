-- Offline test under Lua 5.4 for other addons' own ring buttons on our smaller map (Map/Minimap.lua OntoOurRim). LFG
-- Forever places its button at the map's half width + 5 from its middle, read at its load: placed for the game's map
-- (198 wide) before our pass made it 140, it stood 29 outside our rim (/fcuidev rimwatch, 2026-11-23). Our pass now
-- puts such a button on our rim at its angle; one on the rim, inside the map, LibDBIcon's or hung elsewhere is left.
-- Run from the addon root: lua tools/tests/minimap_addon_rim_test.lua (CI runs every tools/tests/*_test.lua).
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

local square = false
local Minimap = { GetWidth = function() return 140 end, GetEffectiveScale = function() return 1 end }
local MM = { Square = function() return square end }
local ns = {
    AnySecret = function() return false end,
    Safe = function(v) return v end,
    SetPointOnce = function(f, point, rel, relPoint, x, y) f.points = { { point, rel, relPoint, x, y } } end,
}
-- The game's Lua 5.1 has math.atan2; 5.4's math.atan takes both arguments.
local gameMath = setmetatable({ atan2 = math.atan }, { __index = math })
local env = setmetatable({ Minimap = Minimap, MM = MM, ns = ns, math = gameMath }, { __index = _G })
assert(load(Cut("/Map/Minimap.lua", "function ns.RingPoint(", "-- The 1.x calendar button"), "ring point", "t", env))()
local Onto = assert(load(Cut("/Map/Minimap.lua", "local RIM_OUT = ", "local function Layout()") .. "\nreturn OntoOurRim",
    "onto our rim", "t", env))()

local function Button(name, point, rel, relPoint, x, y)
    local b = { name = name, points = { { point, rel, relPoint, x, y } } }
    function b:GetName() return self.name end
    function b:GetNumPoints() return #self.points end
    function b:GetPoint(i) return table.unpack(self.points[i]) end
    function b:GetEffectiveScale() return 1 end
    return b
end
local function At(b) return b.points[1][4], b.points[1][5] end
local function Near(a, b) return math.abs(a - b) < 0.05 end

-- LFG Forever's default angle, 225, placed for the game's 198 map: 104 out, so (-73.5, -73.5).
local r198 = 198 / 2 + 5
local lfg = Button("LFGForeverMinimapButton", "CENTER", Minimap, "CENTER", math.cos(math.rad(225)) * r198, math.sin(math.rad(225)) * r198)
Onto(lfg)
local x, y = At(lfg)
Check(Near(math.sqrt(x * x + y * y), 75) and Near(x, y) and x < 0,
    string.format("placed for the game's map: onto our rim (75 out) at its angle (now %.1f, %.1f)", x, y))

local onRim = Button("OtherMinimapButton", "CENTER", Minimap, "CENTER", 75, 0)
Onto(onRim)
x, y = At(onRim)
Check(x == 75 and y == 0, "already on our rim: left")

local inside = Button("InsideMinimapButton", "CENTER", Minimap, "CENTER", 20, 10)
Onto(inside)
x, y = At(inside)
Check(x == 20 and y == 10, "inside the map: its own spot")

local ldbi = Button("LibDBIcon10_Thing", "CENTER", Minimap, "CENTER", 104, 0)
Onto(ldbi)
x = At(ldbi)
Check(x == 104, "LibDBIcon's button: left to LibDBIcon (its radius may be set on purpose)")

local elsewhere = Button("FreeMinimapButton", "TOPLEFT", {}, "TOPLEFT", 300, -20)
Onto(elsewhere)
x = At(elsewhere)
Check(x == 300, "hung on another frame: left")

-- A square map: the rim at 45 degrees is the corner, (75, 75).
square = true
local corner = Button("CornerMinimapButton", "CENTER", Minimap, "CENTER", 90, 90)
Onto(corner)
x, y = At(corner)
Check(Near(x, 75) and Near(y, 75), string.format("square map: past the corner, onto it (now %.1f, %.1f)", x, y))
local edge = Button("EdgeMinimapButton", "CENTER", Minimap, "CENTER", 75, 30)
Onto(edge)
x, y = At(edge)
Check(x == 75 and y == 30, "square map: on its edge, left")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("minimap_addon_rim_test: ok")
