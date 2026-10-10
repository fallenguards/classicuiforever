-- Offline tests for Map/Minimap.lua under Lua 5.4: the module's hand-back runs on every pass while it is off, and
-- puts the game's pieces back only when it took them this session; held by something else, they stay where they are.
-- Run from the addon root: lua tools/tests/minimap_handback_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 212

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

------------------------------------------------------------------ the stub client and addon

-- Answers any call or lookup with itself: the helpers the hand-back does not depend on.
local Any
Any = setmetatable({}, { __index = function() return Any end, __call = function() return Any end })

-- A client piece: its parent, alpha and points, with a count of every write.
local function Piece(parent)
    local piece = { parent = parent, alpha = 1, writes = 0 }
    function piece:SetParent(to) self.parent, self.writes = to, self.writes + 1 end
    function piece:GetParent() return self.parent end
    function piece:SetAlpha(alpha) self.alpha, self.writes = alpha, self.writes + 1 end
    function piece:GetAlpha() return self.alpha end
    function piece:ClearAllPoints() self.writes = self.writes + 1 end
    function piece:SetAllPoints() self.writes = self.writes + 1 end
    return piece
end

local module
local ns = setmetatable({
    MM = {},
    RegisterModule = function(key, mod) if key == "minimap" then module = mod end end,
    SetPointOnce = function(frame) frame.writes = frame.writes + 1 end,
    SetAlphaIf = function(frame, alpha) frame:SetAlpha(alpha) end,
    Unfade = function(frame) frame.writes = frame.writes + 1 end,
}, { __index = function() return Any end })
assert(loadfile(ROOT .. "/Map/Minimap.lua"))("ClassicUIForever", ns)
assert(loadfile(ROOT .. "/Map/MinimapTracking.lua"))("ClassicUIForever", ns)
assert(loadfile(ROOT .. "/Map/MinimapDiel.lua"))("ClassicUIForever", ns)
assert(module and module.apply and module.restore, "the minimap module registers apply and restore")

-- Its calendar half is Map/MinimapCalendar.lua's: the button back on the map, seen.
function ns.MM.HideCalendar()
    GameTimeFrame:SetParent(Minimap)
    GameTimeFrame:SetAlpha(1)
end
-- The eye's half is Map/MinimapEye.lua's.
function ns.MM.UnplaceEye() end

-- Held elsewhere: the day/night, the coordinates and the calendar sit under a hidden frame that is not ours.
local hidden = {}
local function Client()
    Minimap = {}
    local box = { PlayerCoords = Piece(hidden) }
    box.PlayerCoords.CoordText = Piece(box.PlayerCoords)
    MinimapCluster = { DielFrame = Piece(hidden), MinimapContainer = box, BorderTop = Piece() }
    GameTimeFrame = Piece(hidden)
    GameTimeFrame.alpha = 0
    return MinimapCluster.DielFrame, box.PlayerCoords, GameTimeFrame, box
end

------------------------------------------------------------------ checks

local failures = 0
local function Check(ok, what)
    if not ok then
        failures = failures + 1
        print("FAIL: " .. what)
    end
end

-- Off since login: every pass runs the hand-back, and nothing of the game's is written.
local diel, coords, calendar = Client()
module.restore()
module.restore()
Check(diel.parent == hidden and diel.writes == 0, "off since login: the day/night stays where it was put")
Check(coords.parent == hidden and coords.writes == 0, "off since login: the coordinates are left alone")
Check(calendar.parent == hidden and calendar.alpha == 0, "off since login: the calendar is left alone")
Check(MinimapCluster.BorderTop.writes == 0, "off since login: the zone bar is left alone")

-- On, then turned off: the pieces go back to the client's frames once, and later passes leave them.
MinimapCluster = nil
module.apply()
local box
diel, coords, calendar, box = Client()
module.restore()
Check(diel.parent == MinimapCluster, "turned off: the day/night is back in the cluster")
Check(coords.parent == box, "turned off: the coordinates are back in their box")
Check(calendar.parent == Minimap and calendar.alpha == 1, "turned off: the calendar is back on the map")
diel.parent, diel.writes = hidden, 0
module.restore()
Check(diel.parent == hidden and diel.writes == 0, "a later pass while off writes nothing")

if failures > 0 then
    print(failures .. " check(s) failed")
    os.exit(1)
end
print("minimap_handback_test: all checks passed")
