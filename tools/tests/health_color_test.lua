-- Offline test under Lua 5.4 for Class colored health per frame (UI/Colors.lua ns.HealthColor): with the option on,
-- the player, target and focus frames each take the class color unless unchecked under it, so the target can wear it
-- while the player stays green; any other bar (target of target) follows the option alone. The code is cut out of the
-- file and run.
-- Run from the addon root: lua tools/tests/health_color_test.lua (CI runs every tools/tests/*_test.lua).
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

local handle = assert(io.open(ROOT .. "/UI/Colors.lua", "r"))
local source = handle:read("a")
handle:close()
local first = source:find("local CLASS_FRAMES = ", 1, true)
local last = source:find("-- A player's class colour for the name box", 1, true)
assert(first and last and last > first, "the health color code is in the file")

local ns = { db = {}, ClassRGB = function() return 0.5, 0.25, 0.75 end }
local players = { player = true, target = true, focus = true, targettarget = true }
local env = setmetatable({
    ns = ns,
    EnemyColor = function() return nil end,
    IsSecret = function() return false end,
    UnitIsPlayer = function(unit) return players[unit] == true end,
    UnitClass = function() return "Mage", "MAGE" end,
    UnitCanAttack = function(_, unit) return unit == "target" end,
}, { __index = _G })
assert(load(source:sub(first, last - 1), "health color", "t", env))()

local function Look(unit)
    local r, g, b = ns.HealthColor(unit)
    return (r == 0 and g == 1 and b == 0) and "green" or (r == 0.5 and "class" or "other")
end

Check(Look("player") == "green" and Look("target") == "green", "the option off: green")
ns.db.classColorHealth = true
Check(Look("player") == "class" and Look("target") == "class" and Look("focus") == "class", "the option on, nothing unchecked: all three wear it")
ns.db.classColorHealthPlayer = false
Check(Look("player") == "green", "Player unchecked: the player frame is green (" .. Look("player") .. ")")
Check(Look("target") == "class" and Look("focus") == "class", "and the target and focus keep the class color")
ns.db.classColorHealthPlayer, ns.db.classColorHealthTarget = true, false
Check(Look("player") == "class" and Look("target") == "green", "Target unchecked: the other way round")
Check(Look("targettarget") == "class", "a bar with no pick of its own follows the option")
players.target = false
ns.db.classColorHealthTarget = true
Check(Look("target") == "green", "a target that is no player stays green")
-- Enemy players too: an enemy player keeps the class color unless unchecked; then green here (no enemy color picked).
players.target = true
Check(Look("target") == "class", "an enemy player wears the class color")
ns.db.classColorHealthEnemies = false
Check(Look("target") == "green" and Look("focus") == "class", "Enemy players too off: the enemy goes green, a friend keeps it")
ns.db.classColorHealthEnemies = nil
ns.db.classColorHealth = false
Check(Look("focus") == "green", "the option off again: green, whatever is checked under it")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("health_color_test: ok")
