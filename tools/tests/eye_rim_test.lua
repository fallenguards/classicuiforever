-- Offline test under Lua 5.4 for the queue eye's watch (Map/MinimapEye.lua OffRim, EyeTick): the game lays its eye again
-- at its own spot with no event (a minimap scale change, the micro menu's layout, a queue), and the watch only placed
-- it when edit mode's saved spot changed, so the eye and the group finder icon riding it stood at the game's spot.
-- Run from the addon root: lua tools/tests/eye_rim_test.lua (CI runs every tools/tests/*_test.lua).
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

local handle = assert(io.open(ROOT .. "/Map/MinimapEye.lua", "r"))
local source = handle:read("a")
handle:close()
local first = source:find("local function OffRim", 1, true)
local last = first and source:find("-- Entry wakes the poll", first, true)
assert(first and last, "the eye's watch is in Map/MinimapEye.lua")

local Minimap, MicroMenu = { name = "Minimap" }, { name = "MicroMenu" }
local eye = { points = {} }
function eye:GetNumPoints() return #self.points end
function eye:GetPoint(i) return table.unpack(self.points[i]) end
function eye:GetEffectiveScale() return 1 end
local placed = 0
local env = setmetatable({
    Minimap = Minimap,
    QueueStatusButton = eye,
    MM = { active = true },
    ns = {
        EditMode = { state = false },
        GroupFinderIcon = function() return true end,
        -- One point, at this spot (Core/Setters.lua's, without the secret reads).
        IsAt = function(region, point, rel, relPoint, x, y, tol)
            if region:GetNumPoints() ~= 1 then return nil end
            local p, r, rp, px, py = region:GetPoint(1)
            return p == point and r == rel and rp == relPoint and math.abs(px - x) <= tol and math.abs(py - y) <= tol
        end,
    },
    FollowDialog = function() end,
    EyeMoved = function() return false end,
    Dragged = function() return eye.dragged == true end,
    AnchorSig = function() return 0, 0 end,
    PlaceEye = function() placed = placed + 1 end,
    SetEyeWatch = function() end,
}, { __index = _G })
local chunk = "local snapped, rimX, rimY, lookUntil = true, -95.2, -12.5, 0\n" .. source:sub(first, last - 1)
    .. "\nreturn EyeTick, function(on) snapped = on end"
local EyeTick, SetSnapped = assert(load(chunk, "eye", "t", env))()

local job, clock = {}, 0
-- A second apart: past the 0.1 s look outside edit mode.
local function Tick()
    placed = 0
    clock = clock + 1
    EyeTick(job, clock)
    return placed
end

-- First look: the signature is new, so it places; the eye stands on the rim after.
eye.points = { { "CENTER", Minimap, "CENTER", -95.2, -12.5 } }
Tick()
Check(Tick() == 0, "on the rim with nothing changed, the eye is left alone")

-- Forever's own default spot: the minimap's lower left.
eye.points = { { "CENTER", Minimap, "CENTER", -68, -68 } }
Check(Tick() == 1, "laid at the game's minimap spot, the eye goes back on the rim")

-- Retail's: beside the micro menu, at the screen's foot.
eye.points = { { "BOTTOMRIGHT", MicroMenu, "BOTTOMLEFT", -15, 12 } }
Check(Tick() == 1, "laid beside the micro menu, the eye goes back on the rim")

-- Dragged in edit mode (by its selection box): left to the mouse, then placed once on the drop.
eye.points = { { "CENTER", Minimap, "CENTER", -95.2, -12.5 } }
Tick()
eye.dragged = true
Tick()
eye.points = { { "TOPLEFT", UIParent, "BOTTOMLEFT", 400, 300 } }
Check(Tick() == 0, "while edit mode drags the eye, the watch leaves it to the mouse")
Check(Tick() == 0, "and on every look of the drag")
eye.dragged = false
Check(Tick() == 1, "dropped, it is placed on the rim toward the drop")

-- Edit mode: the micro menu's anchor lays the eye at its corner with no event, frame after frame; each frame's look puts
-- it back (a 0.1 s look let it show there, twitching).
env.ns.EditMode.state = true
local frameClock = clock
for n = 1, 3 do
    eye.points = { { "BOTTOMRIGHT", MicroMenu, "BOTTOMLEFT", -15, 12 } }
    placed = 0
    frameClock = frameClock + 0.016
    EyeTick(job, frameClock)
    Check(placed == 1, "in edit mode, frame " .. n .. " after the game lays it at the micro menu, it is back on the rim")
    eye.points = { { "CENTER", Minimap, "CENTER", -95.2, -12.5 } }
end
env.ns.EditMode.state = false
clock = frameClock + 1

-- Snap to minimap off: wherever edit mode and the game put it.
SetSnapped(false)
Check(Tick() == 0, "with Snap to minimap off the eye stays where the game lays it")

-- Default position: the angle an older version kept for our icon holds until the eye is placed in edit mode; after that
-- a reset is Era's spot.
local first2 = source:find("local function SnapAngle", 1, true)
local last2 = first2 and source:find("-- An install from before", first2, true)
assert(first2 and last2, "the eye's angle is in Map/MinimapEye.lua")
local moved = false
local db = { lfgButtonAngle = 187.3 }
local angleEnv = setmetatable({
    ns = { db = db, WindowRatio = function() return 1 end },
    Minimap = { GetCenter = function() return 0, 0 end },
    EyeMoved = function() return moved end,
    EditModeCenter = function() return 0, 100 end,
    math = setmetatable({ atan2 = math.atan }, { __index = math }),   -- the game's Lua 5.1 has atan2
}, { __index = _G })
local SnapAngle = assert(load("local ERA_ANGLE = 137\n" .. source:sub(first2, last2 - 1) .. "\nreturn SnapAngle", "angle",
    "t", angleEnv))()
Check(SnapAngle(eye) == 187.3, "never placed in edit mode, the old icon angle holds")
moved = true
Check(SnapAngle(eye) == 90, "placed in edit mode, the eye faces that place")
moved = false
Check(SnapAngle(eye) == 137 and db.lfgButtonAngle == nil, "reset after that, it is Era's spot")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("eye_rim_test: all checks passed")
