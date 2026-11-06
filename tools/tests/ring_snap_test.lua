-- Offline test under Lua 5.4: every minimap ring icon's box in ClassicUI Forever Windows (UI/WindowList.lua) carries a
-- Stay on minimap switch that is also its ringIf, its key on by default (Core/Defaults.lua), on both clients; the calendar
-- (its own Mode choice) and retail's eye box (its own switch) stand apart. Asked for 2026-11-05.
-- Run from the addon root: lua tools/tests/ring_snap_test.lua (CI runs every tools/tests/*_test.lua).
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

local defaults = { L = setmetatable({}, { __index = function(_, key) return key end }) }
assert(loadfile(ROOT .. "/Core/Defaults.lua"))("ClassicUIForever", defaults)
local DB = defaults.DB_DEFAULTS

local APART = { calendar = true, minimapEye = true }
local function Load(forever)
    local ns = { L = defaults.L, OnForever = function() return forever end }
    assert(loadfile(ROOT .. "/UI/WindowList.lua"))("ClassicUIForever", ns)
    return ns.WINDOW_LIST
end

for _, forever in ipairs({ true, false }) do
    local client = forever and "Forever" or "retail"
    local rings = 0
    for _, entry in ipairs(Load(forever)) do
        if entry.ringKey and not APART[entry.key] then
            rings = rings + 1
            Check(type(entry.switch) == "string" and entry.ringIf == entry.switch,
                client .. ": " .. entry.key .. " has the Stay on minimap switch as its ringIf")
            Check(entry.switchLabel == "MAP_EYE_SNAP", client .. ": " .. entry.key .. " says Stay on minimap")
            Check(entry.switch and DB[entry.switch] == true, client .. ": " .. tostring(entry.switch) .. " is on by default")
        end
    end
    Check(rings >= 10, client .. ": the ring icons are listed (" .. rings .. ")")
    -- The other minimap pieces stay at their minimap spot while their switch is on.
    local stayers = 0
    for _, entry in ipairs(Load(forever)) do
        if entry.stays then
            stayers = stayers + 1
            Check(type(entry.switch) == "string" and entry.switchLabel == "MAP_EYE_SNAP" and DB[entry.switch] == true,
                client .. ": " .. entry.key .. " stays on the minimap by a Stay on minimap switch on by default")
        end
    end
    Check(stayers == 7, client .. ": the zone name, tracking, mail, clock, day and night, coordinates and calendar stay (" .. stayers .. ")")
end

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("ring_snap_test: ok")
