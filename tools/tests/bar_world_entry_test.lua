-- Offline test under Lua 5.4 for the classic bar pieces' first run (Core/Core.lua Runs, the PLAYER_ENTERING_WORLD
-- branch): a bar piece stands down until world entry and runs in that event itself, so a bar addon loading after us
-- has taken the bars first and its buttons are never dressed and handed back (2026-11-15); taken, it stays down.
-- Run from the addon root: lua tools/tests/bar_world_entry_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 122

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local handlers = {}
function CreateFrame()
    local f = {}
    function f.RegisterEvent() end
    function f.SetScript(_, kind, fn) if kind == "OnEvent" then handlers[#handlers + 1] = fn end end
    return f
end
StaticPopupDialogs = {}
function InCombatLockdown() return false end
function GetBuildInfo() return "", "", "", 120100 end
function geterrorhandler() return function() end end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
C_Timer = { After = function() end }

local ns = { L = setmetatable({}, { __index = function(_, k) return k end }) }
assert(loadfile(ROOT .. "/Core/Core.lua"))("ClassicUIForever", ns)
function ns.PackageRuns() return true end
function ns.WriteHeldCVars() end
ns.RELOAD_KEYS = {}
ns.TOGGLES = { { "plain" } }
local taken = false
function ns.BarsTaken() return taken end
ns.db, ns.ready = { plain = true }, true

local ran = {}
ns.RegisterModule("plain", { apply = function() ran[#ran + 1] = "bar" end, restore = function() ran[#ran + 1] = "bar-off" end,
    barPiece = true })
ns.RegisterModule("plain", { id = "other", apply = function() ran[#ran + 1] = "other" end,
    restore = function() ran[#ran + 1] = "other-off" end })
local function Ran() local s = table.concat(ran, ",") ran = {} return s end

local failed = 0
local function Check(what, got, want)
    if got ~= want then
        failed = failed + 1
        print(string.format("FAIL %s: got %s, want %s", what, tostring(got), tostring(want)))
    end
end
local function Fire(event)
    for _, fn in ipairs(handlers) do pcall(fn, nil, event) end
end

Check("not entered at load", ns.worldEntered, false)
ns.ApplyAll()
Check("the login pass leaves the bar piece down", Ran(), "bar-off,other")
Fire("PLAYER_ENTERING_WORLD")
Check("world entry runs the bar piece in the event", Ran(), "bar,other")
Check("entered after", ns.worldEntered, true)
Fire("PLAYER_ENTERING_WORLD")
Check("a later world entry runs no pass in the event", Ran(), "")
taken = true
ns.ApplyAll()
Check("bars taken: the bar piece stands down", Ran(), "bar-off,other")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("bar_world_entry_test: ok")
