-- Offline test under Lua 5.4 for a class color where the game hides the class (UI/Colors.lua ns.ClassRGB and its
-- callers ns.HealthColor and ns.NameBoxColor). In battlegrounds the game hides every enemy player's class from addons
-- (UnitClass answers secret values): the class was dropped and enemy players' plates stayed red, their target frame
-- green (2026-11-23). The game's class color call takes the hidden class from addon code and its answer goes to a
-- color call as it is. Secret values here are tables the fake IsSecret knows. The code is cut out of the file and run.
-- Run from the addon root: lua tools/tests/class_color_test.lua (CI runs every tools/tests/*_test.lua).
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

local HIDDEN, R, G, B = {}, {}, {}, {}
local secret = { [HIDDEN] = true, [R] = true, [G] = true, [B] = true }
local asked
local game = { C_ClassColor = { GetClassColor = function(class)
    asked = class
    return { r = R, g = G, b = B }
end } }
local class = "MAGE"
local ns = { db = {} }
local env = setmetatable({
    ns = ns,
    _G = game,
    IsSecret = function(v) return secret[v] == true end,
    RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 } },
    UnitIsPlayer = function() return true end,
    UnitClass = function() return class, class end,
    UnitCanAttack = function(_, unit) return unit == "target" end,
    EnemyColor = function() return nil end,
    Hostile = function(unit) return unit == "target" end,
}, { __index = _G })
assert(load(Cut("/UI/Colors.lua", "function ns.ClassRGB(", "-- In a dungeon UnitIsPlayer"), "class rgb", "t", env))()
assert(load(Cut("/UI/Colors.lua", "local CLASS_FRAMES = ", "function ns.KeepEnemyPlayerColor"), "health color", "t", env))()
assert(load(Cut("/UI/Colors.lua", "local NAME_FRAMES = ", "function ns.SetHealth"), "name box color", "t", env))()

------------------------------------------------------------------ the helper

local r, g, b = ns.ClassRGB("MAGE")
Check(r == 0.25 and g == 0.78 and b == 0.92, "a class in hand: its color from the table")
Check(ns.ClassRGB(nil) == nil and ns.ClassRGB("NOBODY") == nil, "no class or an unknown one: nothing")
r, g, b = ns.ClassRGB(HIDDEN)
Check(asked == HIDDEN, "a hidden class goes to the game's class color call as it is")
Check(r == R and g == G and b == B, "and its hidden answer comes back as it is, for a color call")
game.C_ClassColor.GetClassColor = function() return nil end
Check(ns.ClassRGB(HIDDEN) == nil, "the game's call with no answer: nothing, no error")
game.C_ClassColor = nil
Check(ns.ClassRGB(HIDDEN) == nil, "no class color call in this client: nothing")
game.C_ClassColor = { GetClassColor = function() return { r = R, g = G, b = B } end }

------------------------------------------------------------------ its callers

ns.db.classColorHealth = true
class = HIDDEN
r = ns.HealthColor("target")
Check(r == R, "Class colored health on an enemy player whose class is hidden: the hidden class color, not green")
ns.db.classColorNames = true
r = ns.NameBoxColor("target")
Check(r == R, "Class colored name box on an enemy player whose class is hidden: the hidden class color")
class = "MAGE"
r = ns.HealthColor("target")
Check(r == 0.25, "a class in hand still gets its own color")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("class_color_test: ok")
