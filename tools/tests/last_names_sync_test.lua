-- Offline test under Lua 5.4 for Hide last names and the game's "My Secondary Name" box (UnitSurnameOwn, Units/
-- LastNames.lua): the toggle turns the box off and gives it back, ticking the box turns the toggle off, and the logout
-- repair leaves it alone while the toggle holds it off. The box was skipped, so the two never matched.
-- Run from the addon root: lua tools/tests/last_names_sync_test.lua (CI runs every tools/tests/*_test.lua).
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

local now = 0
local cvars = { UnitSurnameOwn = "1" }
function GetTime() return now end
function InCombatLockdown() return false end
C_Console = { GetAllCommands = function() return { { command = "UnitSurnameOwn" } } end }
C_CVar = { GetCVar = function(name) return cvars[name] end, SetCVar = function() end }

-- Frames keep their event scripts; the one hearing CVAR_UPDATE is the module's driver.
local frames = {}
function CreateFrame()
    local frame = { events = {} }
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:UnregisterEvent(event) self.events[event] = nil end
    function frame:SetScript(_, fn) self.onEvent = fn end
    frames[#frames + 1] = frame
    return frame
end

local module, ns
ns = {
    db = {},
    IsSecret = function() return false end,
    GetCVar = function(name) return cvars[name] end,
    SetCVar = function(name, value) cvars[name] = tostring(value) end,
    TurnCVarBackOn = function(name)
        if cvars[name] ~= "0" then return false end
        cvars[name] = "1"
        return true
    end,
    DbTable = function(key) ns.db[key] = ns.db[key] or {} end,
    RegisterModule = function(_, spec) module = spec end,
    RegisterEvents = function(frame, list) for _, event in ipairs(list) do frame:RegisterEvent(event) end end,
    Sched = { Soon = function() end, NextFrame = function() end, Attach = function() end, OnVisible = function() end },
    NP = { EachPlate = function() end },
    Path = function() return nil end,
}
assert(loadfile(ROOT .. "/Units/LastNames.lua"))("ClassicUIForever", ns)

ns.db.hideLastNames = true
module.apply()
Check(cvars.UnitSurnameOwn == "0", "the toggle turns My Secondary Name off (" .. tostring(cvars.UnitSurnameOwn) .. ")")
Check(ns.db.savedSurnames and ns.db.savedSurnames.UnitSurnameOwn == "1", "its value is kept to give back")

-- The logout repair leaves the box off while the toggle holds it.
ns.RepairSurnames()
Check(cvars.UnitSurnameOwn == "0", "the logout repair leaves My Secondary Name off while the toggle is on")

-- The player ticks the box in the game's settings, past our own write's echo: the toggle follows.
local driver
for _, frame in ipairs(frames) do
    if frame.events.CVAR_UPDATE then driver = frame end
end
now = 10
cvars.UnitSurnameOwn = "1"
driver.onEvent(driver, "CVAR_UPDATE", "UnitSurnameOwn", "1")
Check(ns.db.hideLastNames == false, "ticking My Secondary Name turns Hide last names off")

-- Turned off from our side: the box comes back as it was.
ns.db.hideLastNames = true
module.apply()
module.restore()
Check(cvars.UnitSurnameOwn == "1", "turning the toggle off gives My Secondary Name back")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("last_names_sync_test: all checks passed")
