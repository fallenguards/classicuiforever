-- Offline test under Lua 5.4 for a ring button riding a game frame another addon took (Map/MinimapButton.lua Position,
-- Map/MinimapMicro.lua rideParent). A button gatherer's tray took the queue eye; our group finder icon rode it with two
-- move helpers from UIParent, and the tray had no anchor on its own drag (/fcuidev framedrag). The rider's helpers
-- let go while the host sits off its game parent, from the first look and on each reparent, and pin again when it
-- is back.
-- Run from the addon root: lua tools/tests/ride_held_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 212

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local failed = 0
local function Check(ok, what)
    if not ok then
        failed = failed + 1
        print("FAIL " .. what)
    end
end

local Frame = {}
Frame.__index = function(_, key) return Frame[key] or function() end end
function Frame:GetParent() return self.parent end
function Frame:GetEffectiveScale() return 1 end
function Frame:GetWidth() return 140 end
function Frame:GetFrameLevel() return 2 end
function Frame:CreateTexture() return setmetatable({}, Frame) end
function Frame:CreateFontString() return setmetatable({}, Frame) end
function Frame:IsShown() return true end
function Frame:GetName() return self.name end
function Frame:SetParent(parent) self.parent = parent end
function CreateFrame(_, name, parent) return setmetatable({ name = name, parent = parent }, Frame) end
UIParent = setmetatable({ name = "UIParent" }, Frame)
Minimap = setmetatable({ name = "Minimap" }, Frame)
function InCombatLockdown() return false end

local noop = function() end
local letGo, hooks = {}, {}
local ns = {
    SetScaleIf = noop, SetPointOnce = noop, SetAlphaIf = noop, DressStates = noop, AttachTip = noop, MinimapShow = noop,
    MinimapShowAs = noop, HookScriptOnce = noop, OnToggle = noop, PlaceSavedWindows = noop, RingLook = noop,
    Safe = function(v) return v end,
    L = setmetatable({}, { __index = function(_, key) return key end }),
    db = {},
    Sched = { OnFrame = function() return { Wake = noop, Sleep = noop } end,
        LetGo = function(frame, loose) letGo[#letGo + 1] = { frame, loose } end },
    MM = { Square = function() return false end },
    HookMethod = function(frame, method, fn) hooks[#hooks + 1] = { frame, method, fn } end,
    RingPoint = noop, RegisterModule = noop, DressNew = noop, RoundIcon = noop, MinimapButtonBorder = noop, Dress = noop,
}
assert(loadfile(ROOT .. "/Map/MinimapButton.lua"))("ClassicUIForever", ns)

local function Last() return letGo[#letGo] end

-- The eye on its game parent: the rider's helpers stay.
local eye = setmetatable({ name = "QueueStatusButton", parent = UIParent }, Frame)
local show = ns.RingButton({ name = "RiderButton", key = "rider", angleKey = "riderAngle", angle = 137,
    ride = function() return eye end, rideParent = UIParent, piece = true, show = "GroupFinderButton", face = noop })
show()
local rider = Last() and Last()[1]
Check(rider ~= nil and rider.name == "RiderButton" and Last()[2] == false, "at home the rider's helpers are kept")
local eyeHook
for i = 1, #hooks do
    if hooks[i][1] == eye and hooks[i][2] == "SetParent" then eyeHook = hooks[i][3] end
end
Check(eyeHook ~= nil, "the host's reparent is watched")

-- Another addon's tray takes the eye: the helpers let go.
local tray = setmetatable({ name = "SomeTray", parent = UIParent }, Frame)
eye:SetParent(tray)
eyeHook(eye, tray)
Check(Last()[1] == rider and Last()[2] == true, "the eye taken, the rider's helpers let go")

-- Back on its game parent: pinned again.
eye:SetParent(UIParent)
eyeHook(eye, UIParent)
Check(Last()[1] == rider and Last()[2] == false, "the eye back home, the helpers pin again")

-- The eye already taken at the first look.
letGo = {}
local eye2 = setmetatable({ name = "Eye2", parent = tray }, Frame)
local show2 = ns.RingButton({ name = "Rider2", key = "rider2", angleKey = "rider2Angle", angle = 100,
    ride = function() return eye2 end, rideParent = UIParent, piece = true, show = "GroupFinderButton", face = noop })
show2()
Check(Last() and Last()[2] == true, "a host already taken at the first look lets go at once")

-- A ride with no game parent named never counts as taken.
letGo = {}
local show3 = ns.RingButton({ name = "Rider3", key = "rider3", angleKey = "rider3Angle", angle = 50,
    ride = function() return eye2 end, piece = true, show = "GroupFinderButton", face = noop })
show3()
Check(Last() and Last()[2] == false, "no rideParent: never held")

-- The group finder icon names the eye's game parent.
local src = assert(io.open(ROOT .. "/Map/MinimapMicro.lua")):read("a")
Check(src:find("ride = function%(%) return QueueStatusButton end, rideParent = UIParent") ~= nil
    and src:find("rideParent = spec.rideParent") ~= nil, "the group finder icon rides the eye with its game parent named")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("ride_held_test: all checks passed")
