-- Offline tests for Options/EraScale.lua under Lua 5.4: Reset toggles sets the boxes as the classic layout does, the 36 px
-- bar included at Classic Era's interface size (it put back the game-sized bar); a reinstall on the classic layout at
-- Era's size starts with the 36 px bar.
-- Run from the addon root: lua tools/tests/reset_toggles_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 212

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

------------------------------------------------------------------ the stub client

local screenHeight, uiScale = 1440, 0.71
function GetPhysicalScreenSize() return 2560, screenHeight end
function GetScreenDPIScale() return 1 end
UIParent = { GetScale = function() return uiScale end }

------------------------------------------------------------------ the addon

local noop = function() end
local classicLayout, changed = true, nil
local ns = {
    ClassicLayoutActive = function() return classicLayout end,
    TogglesChanged = function(keys) changed = keys[1] end,
    L = setmetatable({}, { __index = function(_, key) return key end }),
    options = { TITLE = "ClassicUI Forever" },
    Popup = noop,
    TOGGLES = { { "classicBar" }, { "classicBarSize" }, { "hideCombatGlow" } },
    DB_DEFAULTS = { classicBar = true, classicBarSize = false, hideCombatGlow = false },
}
assert(loadfile(ROOT .. "/Options/EraScale.lua"))("ClassicUIForever", ns)

------------------------------------------------------------------ checks

local failures = 0
local function Check(ok, what)
    if not ok then
        failures = failures + 1
        print("FAIL: " .. what)
    end
end

-- Era's size at 1440 tall: 768 / 1440 held to 0.9.
uiScale = 0.9
ns.db = { classicBar = false, classicBarSize = false, hideCombatGlow = true }
ns.ResetToggles()
Check(ns.db.classicBar == true and ns.db.hideCombatGlow == false, "every box back to its default")
Check(ns.db.classicBarSize == true, "at Era's interface size the bars come back classic-sized, as the classic layout sets them")

-- The game's default scale: the game-sized bar, the default.
uiScale = 0.71
ns.db = { classicBarSize = true }
ns.ResetToggles()
Check(ns.db.classicBarSize == false, "at another interface size the bar size is the default")

-- Settings gone (a reinstall): the classic layout at Era's size gets the 36 px bar it was laid for, once.
local function FreshLogin(scale, layout)
    uiScale, classicLayout, changed = scale, layout, nil
    ns.db = { classicBarSize = false }
    ns.freshSettings = true
    ns.EraSizeOnFreshInstall()
end
FreshLogin(0.9, true)
Check(ns.db.classicBarSize == true and changed == "classicBarSize", "reinstall on the classic layout at Era's size: 36 px bar")
Check(ns.freshSettings == nil, "asked once per load")
FreshLogin(0.71, true)
Check(ns.db.classicBarSize == false, "the classic layout at another size keeps the game-sized bar")
FreshLogin(0.9, false)
Check(ns.db.classicBarSize == false, "a new player (no classic layout yet) keeps the game-sized bar")
uiScale, classicLayout = 0.9, true
ns.db, ns.freshSettings = { classicBarSize = false }, nil
ns.EraSizeOnFreshInstall()
Check(ns.db.classicBarSize == false, "saved settings are never changed")

if failures > 0 then
    print(string.format("reset toggles: %d failed", failures))
    os.exit(1)
end
print("reset toggles: ok")
