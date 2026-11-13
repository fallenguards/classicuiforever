-- Offline test under Lua 5.4 for Class colored name box (UI/Colors.lua ns.NameBoxColor, Units/TargetFrame.lua).
-- The player, target and focus frames are each picked under the option. On the target and focus the game colours the
-- name box only as the unit changes, so ours taken off (the option, or that frame unchecked) puts the game's colour
-- back at once: it stayed class colored until the next target or reload. The code is cut out of the files and run.
-- Run from the addon root: lua tools/tests/name_box_color_test.lua (CI runs every tools/tests/*_test.lua).
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

------------------------------------------------------------------ which frames wear it

local ns = { db = {}, ClassRGB = function() return 0.5, 0.25, 0.75 end }
local players = { player = true, target = true, focus = true }
local env = setmetatable({
    ns = ns,
    IsSecret = function() return false end,
    UnitIsPlayer = function(unit) return players[unit] == true end,
    UnitClass = function() return "Mage", "MAGE" end,
    Hostile = function(unit) return unit == "focus" end,
}, { __index = _G })
assert(load(Cut("/UI/Colors.lua", "local NAME_FRAMES = ", "function ns.SetHealth"), "name box color", "t", env))()
local function Wears(unit) return ns.NameBoxColor(unit) ~= nil end

Check(not Wears("player") and not Wears("target"), "the option off: no frame wears it")
ns.db.classColorNames = true
Check(Wears("player") and Wears("target") and Wears("focus"), "the option on, nothing unchecked: all three wear it")
-- Each side under it: the focus here is an enemy player.
ns.db.classColorNamesEnemies = false
Check(Wears("target") and not Wears("focus"), "Enemy players off: an enemy's box keeps the game's color")
ns.db.classColorNamesEnemies = nil
ns.db.classColorNamesFriends = false
Check(not Wears("target") and Wears("focus"), "Friendly players off: only an enemy's box wears it")
ns.db.classColorNamesFriends = nil
ns.db.classColorNamesPlayer = false
Check(not Wears("player") and Wears("target") and Wears("focus"), "Player unchecked: target and focus alone")
ns.db.classColorNamesPlayer, ns.db.classColorNamesFocus = true, false
Check(Wears("player") and Wears("target") and not Wears("focus"), "Focus unchecked: player and target alone")
players.target = false
Check(not Wears("target"), "a target that is no player keeps the game's color")
players.target = true

------------------------------------------------------------------ the target's box goes back to the game's color

local box = {}
local tapped, controlled = false, true
local frame = { }
ns.AnySecret = function() return false end
ns.SetVertexColorIf = function(region, r, g, b) region.r, region.g, region.b = r, g, b end
local env2 = setmetatable({
    ns = ns,
    SetShownIf = function(region, shown) region.shown = shown end,
    UnitPlayerControlled = function() return controlled end,
    UnitIsTapDenied = function() return tapped end,
    UnitSelectionColor = function() return 0, 0, 1, 1 end,
    setmetatable = setmetatable,
}, { __index = _G })
-- The two locals above the frame pass, and its name box lines as one function.
local body = Cut("/Units/TargetFrame.lua", "local classBoxed = ", "local function ApplyClassification")
local lines = Cut("/Units/TargetFrame.lua", "    local box = main and main.ReputationColor", "    -- CastBars reads this")
local Pass = assert(load(body .. "\nreturn function(frame, entry, main, minus, style)\n" .. lines .. "\nend", "target name box", "t", env2))()
local main = { ReputationColor = box }
local entry = { unit = "target" }

ns.db = { classColorNames = true }
Pass(frame, entry, main)
Check(box.r == 0.5, "the option on: the target's box in the class color")
ns.db.classColorNames = false
Pass(frame, entry, main)
Check(box.r == 0 and box.b == 1, "the option off: the game's color back at once (blue for a friend), no reload")
box.r, box.g, box.b = 0.9, 0.9, 0.9
Pass(frame, entry, main)
Check(box.r == 0.9, "and left to the game after that: its color is written once, not on every pass")
ns.db = { classColorNames = true, classColorNamesTarget = false }
Pass(frame, entry, main)
Check(box.r == 0.9, "Target unchecked from the start: never ours")
ns.db.classColorNamesTarget = true
Pass(frame, entry, main)
ns.db.classColorNamesTarget = false
tapped, controlled = true, false
Pass(frame, entry, main)
Check(box.r == 0.5 and box.g == 0.5 and box.b == 0.5, "taken off on a tapped mob: the game's grey")

------------------------------------------------------------------ Name box color: the game's color per frame

tapped, controlled = false, true
ns.db = {}
Pass(frame, entry, main)
Check(box.shown == true, "Target picked (the default, as Classic Era): the game's colored box shows")
ns.db.nameBoxTarget = false
Pass(frame, entry, main)
Check(box.shown == false, "Target unchecked: no colored box, plain as the player frame's")
ns.db.classColorNames = true
Pass(frame, entry, main)
Check(box.shown == true and box.r == 0.5, "a class color of ours still shows there")
ns.db.classColorNames = false
Pass(frame, entry, main)
Check(box.shown == false, "and the box is plain again once the class color goes")
ns.db.nameBoxTarget = true
Pass(frame, entry, main, false, "name")
Check(box.shown == false, "thick health over the name: hidden whatever is picked")
Pass({}, { unit = "focus" }, main)
Check(box.shown == true, "the focus frame follows its own pick")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("name_box_color_test: ok")
