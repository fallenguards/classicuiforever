-- Offline test under Lua 5.4 for what a minimap icon presses (UI/SecurePad.lua ns.PressTarget).
-- A micro button with a closer's pad (the game's spell window in the way) is pressed through that pad only while it
-- has a macro to run; otherwise the button itself, or the icon did nothing (the Legacy icon, 0.26.0 to 0.27.0).
-- Run from the addon root: lua tools/tests/press_target_test.lua (CI runs every tools/tests/*_test.lua).
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

local NOOP = function() end
-- Any frame: every method a no-op.
local function Frame() return setmetatable({}, { __index = function() return NOOP end }) end
function CreateFrame() return Frame() end
function InCombatLockdown() return false end
UIParent = Frame()
MinimapCluster = { ZoneTextButton = Frame() }
local ns = {
    Sched = { NextFrame = NOOP, OnMove = NOOP, OnVisible = NOOP, Attach = NOOP },
    EventFrame = NOOP, OnEditMode = NOOP, OnToggle = NOOP,
}
assert(loadfile(ROOT .. "/UI/SecurePad.lua"))("ClassicUIForever", ns)

local active, inTheWay = true, false
local legacy = Frame()
ns.MapPad(legacy, nil, nil, function() if inTheWay then return "/click CloseIt" end end, function() return active end)
local closer = ns.PadOf(legacy)

Check(ns.PressTarget(legacy) == legacy, "nothing in the way: the icon presses the micro button itself")
inTheWay = true
Check(ns.PressTarget(legacy) == closer, "the game's spell window in the way: the closer's pad")
active = false
Check(ns.PressTarget(legacy) == legacy, "our window off: the micro button")

local quest = Frame()
ns.MapPad(quest, nil, nil, Frame(), function() return true end)
Check(ns.PressTarget(quest) == ns.PadOf(quest), "a pad that clicks a button is pressed whenever wanted")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("press_target_test: all checks passed")
