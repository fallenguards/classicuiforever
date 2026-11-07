-- Offline test under Lua 5.4 for Same size near and far (Units/NamePlateOptions.lua): the box mirrors the two plate
-- scale CVars, which the game keeps per character, and only a click writes them, held in a fight.
-- Run from the addon root: lua tools/tests/plates_one_size_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 122

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

------------------------------------------------------------------ the stub client

local handlers = {}
function CreateFrame()
    local f = {}
    function f.RegisterEvent() end
    function f.SetScript(_, _, fn) handlers[#handlers + 1] = fn end
    return f
end
StaticPopupDialogs = {}
local fight = false
function InCombatLockdown() return fight end
function GetBuildInfo() return "", "", "", 16001 end
local errors = 0
function geterrorhandler() return function(err) errors = errors + 1 print("error: " .. tostring(err)) end end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
C_Timer = { After = function() end }

local DEFAULTS = { nameplateMinScale = "0.800000", nameplateSelectedScale = "1.200000" }
local cvars, writes = {}, 0
C_CVar = {
    GetCVar = function(name) return cvars[name] end,
    SetCVar = function(name, value) writes = writes + 1 cvars[name] = tostring(value) return true end,
}

local ns = { L = setmetatable({}, { __index = function(_, k) return k end }), NP = { EachPlate = function() return 0 end } }
assert(loadfile(ROOT .. "/Core/Core.lua"))("ClassicUIForever", ns)
assert(loadfile(ROOT .. "/Core/Settings.lua"))("ClassicUIForever", ns)
-- Core/Util.lua's readers as the addon has them: a read is noted for the pass.
function ns.GetCVar(name) ns.NoteCVarRead(name) return cvars[name] end
function ns.GetCVarDefault(name) return DEFAULTS[name] end
function ns.PackageRuns() return true end
ns.RELOAD_KEYS = {}
assert(loadfile(ROOT .. "/Units/NamePlateOptions.lua"))("ClassicUIForever", ns)

local failed, passed = 0, 0
local function Check(what, ok)
    if ok then
        passed = passed + 1
    else
        failed = failed + 1
        print("FAIL " .. what)
    end
end

local function Character(minScale, selectedScale)
    cvars.nameplateMinScale, cvars.nameplateSelectedScale = minScale, selectedScale
end
local function Click(on)
    ns.db.platesOneSize = on
    ns.ToggleChanged("platesOneSize")
end
local function FightEnds()
    fight = false
    for _, fn in ipairs(handlers) do fn(nil, "PLAYER_REGEN_ENABLED") end
end

-- The shared profile has the box on.
local saved = { platesOneSize = true }
ns.db, ns.ready = saved, true

------------------------------------------------------------------ a character never clicked, then its click

Character("0.800000", "1.200000")
ns.ApplyAll()
Check("a new character shows the box off", saved.platesOneSize == false)
Check("a pass alone writes no game setting", writes == 0)

Click(true)
Check("the click writes the far scale", cvars.nameplateMinScale == "1")
Check("the click writes the target scale", cvars.nameplateSelectedScale == "1")
Check("the values before are kept", saved.platesOneSizeWas ~= nil and saved.platesOneSizeWas.nameplateMinScale == "0.800000"
    and saved.platesOneSizeWas.nameplateSelectedScale == "1.200000")
Check("the box stays on after the click's pass", saved.platesOneSize == true)

------------------------------------------------------------------ a character clicked before, then its click off

saved.platesOneSize = false
Character("1", "1")
ns.ApplyAll()
Check("a character set before shows the box on", saved.platesOneSize == true)

Click(false)
Check("the click off gives the far scale back", cvars.nameplateMinScale == "0.800000")
Check("the click off gives the target scale back", cvars.nameplateSelectedScale == "1.200000")
Check("the values before are let go", saved.platesOneSizeWas == nil)
Check("the box stays off after the click's pass", saved.platesOneSize == false)

Character("1", "1.200000")
ns.ApplyAll()
Check("one scale alone shows the box off", saved.platesOneSize == false)

------------------------------------------------------------------ a click in a fight waits for its end

Character("0.800000", "1.200000")
ns.ApplyAll()
fight = true
Click(true)
Check("nothing written in a fight", cvars.nameplateMinScale == "0.800000" and cvars.nameplateSelectedScale == "1.200000")
Check("the box keeps the click in a fight", saved.platesOneSize == true)
FightEnds()
Check("written as the fight ends", cvars.nameplateMinScale == "1" and cvars.nameplateSelectedScale == "1")
Check("the box on after the fight", saved.platesOneSize == true)

------------------------------------------------------------------ a client without these settings

Character(nil, nil)
saved.platesOneSize = true
ns.ApplyAll()
Check("a client without the settings leaves the box alone", saved.platesOneSize == true)

Check("no pass raised an error", errors == 0)
print(string.format("plates one size: %d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
