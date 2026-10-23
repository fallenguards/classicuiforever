-- Offline test under Lua 5.4 for the queue eye's watch (Map/MinimapEye.lua OffRim, EyeTick): the game lays its eye again
-- at its own spot with no event (a minimap scale change, the micro menu's layout, a queue), and the watch only placed
-- it when edit mode's saved spot changed, so the eye and the group finder icon riding it stood at the game's spot. And
-- its catch (CatchMoves, a child stretched to the screen's corner) lets go through edit mode's drag of the eye: hung on,
-- the drop left the eye with no anchor and the game's anchor update errored (SetPoint(nil), 2026-10-22).
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

local Minimap, MicroMenu = { name = "Minimap", scale = 1 }, { name = "MicroMenu" }
function Minimap:GetEffectiveScale() return self.scale end
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
    OwnScale = function() return eye.ownScale or 1 end,
    SetEyeWatch = function() end,
    PinCatch = function(_, on) eye.catchOn = on end,
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
-- Selected in edit mode (the press that starts a drag): the catch is off the eye; deselected, or out of edit mode, on.
eye.isSelected = true
EyeTick(job, frameClock + 0.016)
Check(eye.catchOn == false, "selected in edit mode, the catch is let go")
eye.isSelected = false
EyeTick(job, frameClock + 0.032)
Check(eye.catchOn == true, "deselected, the catch hangs on again")
eye.isSelected = true
env.ns.EditMode.state = false
clock = frameClock + 1
Tick()
Check(eye.catchOn == true, "out of edit mode a stale selection flag keeps the catch on")
eye.isSelected = nil

-- The minimap's edit mode Size changes (#208): the eye is placed again, at the minimap's new scale.
Check(Tick() == 0, "nothing changed, nothing placed")
Minimap.scale = 1.3
Check(Tick() == 1, "the minimap grown, the eye is placed and sized again")
Check(Tick() == 0, "and left alone after")
-- Its own size stepped (retail: our edit mode's box) sizes it again too.
eye.ownScale = 1.2
Check(Tick() == 1, "its own size changed, the eye is sized again")
Check(Tick() == 0, "and left alone after that")

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

-- The catch hangs between the eye and the screen's corner; the press on edit mode's box that selects the eye (and starts
-- its drag) lets it go before the game's StartMoving, so the eye keeps its rect and the drop leaves it an anchor.
local first3 = source:find("local catch, catchOn", 1, true)
local last3 = first3 and source:find("-- The game lays the eye again", first3, true)
local first4 = source:find("local function CatchMoves", 1, true)
local last4 = first4 and source:find("-- Created at the first Layout", first4, true)
assert(first3 and last3 and first4 and last4, "the eye's catch is in Map/MinimapEye.lua")
local catch = { points = 0 }
function catch:SetPoint() self.points = self.points + 1 end
function catch:ClearAllPoints() self.points = 0 end
function catch:SetScript() end
local hooks = {}
local catchEnv = setmetatable({
    CreateFrame = function() return catch end,
    ns = { HookScriptOnce = function(_, script, fn) hooks[script] = fn end },
}, { __index = _G })
local CatchMoves, PinCatch = assert(load(source:sub(first3, last3 - 1) .. source:sub(first4, last4 - 1)
    .. "\nreturn CatchMoves, PinCatch", "catch", "t", catchEnv))()
local system = { Selection = {} }
CatchMoves(system)
Check(catch.points == 2 and hooks.OnMouseDown ~= nil, "the catch hangs between the eye and the screen, hooked on the box's press")
hooks.OnMouseDown()
Check(catch.points == 0, "the press that selects the eye lets the catch go")
PinCatch(system, true)
PinCatch(system, true)
Check(catch.points == 2, "pinned once the eye is no longer selected, not twice")
PinCatch(system, false)
catch.points, hooks = 0, {}
CatchMoves({})
Check(catch.points == 2 and next(hooks) == nil, "retail's eye (no edit mode box) takes no hook")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("eye_rim_test: all checks passed")
