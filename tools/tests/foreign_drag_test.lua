-- Offline test under Lua 5.4 for another addon's drag of a game window we watch (UI/WindowDrags.lua ForeignDragStart,
-- ForeignDragStop): a start that found our move helpers on the window and broke it (no rect) is ended, the helpers let
-- go, the window set back where it was last drawn and the move started again; every stop anchors the window again
-- where it was drawn (with the stop's own anchor the helpers are refused on it, and a stop may leave none), before the
-- addon reads the point it saves; the spot becomes the window's place only where we place it already. A map addon's
-- drag left the map unseen and its saved point nil, and the map was gone.
-- Run from the addon root: lua tools/tests/foreign_drag_test.lua (CI runs every tools/tests/*_test.lua).
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

local combat = false
function InCombatLockdown() return combat end
UIParent = { name = "UIParent" }

local log = {}
local function Log() return table.concat(log, ",") end
local job = { awake = false }
function job:Wake() self.awake = true end
function job:Sleep() self.awake = false end
-- The map: its anchors, where it is drawn (nil once a start or stop broke it), the moves the engine is asked for.
local map = { points = 1, left = 100, top = 500 }
function map:GetNumPoints() return self.points end
function map:GetLeft() return self.left end
function map:GetTop() return self.top end
function map:StartMoving() log[#log + 1] = "start" end
function map:StopMovingOrSizing() log[#log + 1] = "stop" end
function map:ClearAllPoints() self.points = 0 end
function map:SetPoint(point, rel, relPoint, x, y)
    self.points = 1
    self.set = { point, rel, relPoint, x, y }
    log[#log + 1] = "anchor"
end
local entry = { key = "map", quests = true }
local W = {
    Moving = {}, EntryOf = { [map] = entry }, Strips = {}, ClampWas = {},
    Full = function() return false end, IsFree = function() return true end,
    PlaceOf = function(e) return e.placed end,
    Worn = function(e) return e.worn ~= false end,
    SaveFrom = function(e, f) log[#log + 1] = "save" end,
    PlaceAll = function() log[#log + 1] = "place" end,
    STRIP_LEFT = 0, STRIP_RIGHT = 0, STRIP_H = 0, STRIP_LIFT = 0,
}
local ns = {
    windowEdit = W,
    Safe = function(v) return v end,
    Sched = {
        Job = function(spec) job.fn = spec.fn return job end,
        LetGo = function(_, loose) log[#log + 1] = loose and "loose" or "pinned" end,
    },
    WindowFrame = function() return map end,
    MoverHolds = function() return false end,
    NewFrame = function() return {} end,
    SetLevelIf = function() end,
}
assert(loadfile(ROOT .. "/UI/WindowDrags.lua"))("ClassicUIForever", ns)

local function At(x, y)
    return map.set and map.set[1] == "TOPLEFT" and map.set[2] == UIParent and map.set[3] == "BOTTOMLEFT"
        and map.set[4] == x and map.set[5] == y
end

-- A clean start on a window we place: helpers let go; the stop anchors it where drawn, saves the spot, pins again.
entry.placed = true
W.ForeignDragStart(map)
Check(W.Moving[map] == true and job.awake and Log() == "loose", "a clean start lets our helpers go (" .. Log() .. ")")
W.ForeignDragStop(map)
Check(W.Moving[map] == nil and not job.awake, "the drag is over")
Check(Log() == "loose,anchor,save,pinned" and At(100, 500), "the stop anchors it where drawn, saves, pins (" .. Log() .. ")")

-- #192: placed by us once, Unlock Map since turned off: that addon's drag is its own, not saved as ours.
log, entry.worn = {}, false
W.ForeignDragStart(map)
W.ForeignDragStop(map)
Check(Log() == "loose,anchor,pinned", "a place of ours not worn (toggle off) takes no drag (" .. Log() .. ")")
entry.worn = nil

-- A window we never placed: nothing saved, so ours never moves it from where that addon puts it.
log, entry.placed = {}, nil
W.ForeignDragStart(map)
W.ForeignDragStop(map)
Check(Log() == "loose,anchor,pinned", "a window not placed by us is not taken (" .. Log() .. ")")

-- The start broke the window (helpers were on it): ended, helpers let go, set back where it was last drawn (kept at
-- its last move), started again.
log = {}
map.left, map.top = 300, 700
W.KeepDrawn(map)
map.points, map.left, map.top = 0, nil, nil
W.ForeignDragStart(map)
Check(Log() == "stop,loose,anchor,start", "a broken start is ended and started again clean (" .. Log() .. ")")
Check(At(300, 700), "set back where it was last drawn")
Check(W.Moving[map] == true and job.awake, "the drag goes on")
-- The stop, the window not drawn: anchored where it was last seen.
log, map.set = {}, nil
W.ForeignDragStop(map)
Check(Log() == "anchor,pinned" and At(300, 700), "a stop with the window unseen anchors it where last seen (" .. Log() .. ")")

-- A stop that left no anchor: anchored again where the drag's last frame drew it, before the addon reads.
log, map.set = {}, nil
map.left, map.top = 100, 500
W.ForeignDragStart(map)
map.left, map.top = 200, 600
job.fn()
map.points, map.left, map.top = 0, nil, nil
W.ForeignDragStop(map)
Check(Log() == "loose,anchor,pinned" and map.points == 1, "a window left with no anchor gets one (" .. Log() .. ")")
Check(At(200, 600), "anchored where the drag's last frame drew it")

-- A fight: nothing of ours moves.
log, combat = {}, true
W.ForeignDragStart(map)
Check(W.Moving[map] == nil and #log == 0, "in a fight the drag is left alone")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("foreign_drag_test: all checks passed")
