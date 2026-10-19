-- Offline tests for the addon buttons' picks under Lua 5.4: each button's own pick over Addon buttons' (Map/MinimapShow.lua)
-- and the options button's old pick kept as its override (Map/MinimapButtonPicks.lua, dbVersion 20, #194).
-- Run from the addon root: lua tools/tests/button_picks_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 212

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local passed, failed = 0, 0
local function Check(ok, msg)
    if ok then
        passed = passed + 1
    else
        failed = failed + 1
        print("FAIL: " .. msg)
    end
end

local ns = { MM = {}, L = setmetatable({}, { __index = function(_, key) return key end }) }
function ns.OnToggle() end
assert(loadfile(ROOT .. "/Map/MinimapShow.lua"))("ClassicUIForever", ns)
assert(loadfile(ROOT .. "/Map/MinimapButtonPicks.lua"))("ClassicUIForever", ns)
local MM = ns.MM
local OUR = MM.OUR_BUTTON

-- A button's state: its own pick, else Addon buttons'; all shown in the addon bag; hidden with the minimap closed.
ns.db = { showMinimapAddonButtons = true }
Check(MM.AddonButtonState("Details") == nil, "no picks: shown with Addon buttons")
ns.db = { hoverMinimapAddonButtons = true }
Check(MM.AddonButtonState("Details") == "hover", "no pick of its own: Addon buttons' on hover")
ns.db.minimapButtonPicks = { Details = "show", BugSack = "hide", Junk = "junk" }
Check(MM.AddonButtonState("Details") == nil, "its own Shown wins over Addon buttons' on hover")
Check(MM.AddonButtonState("BugSack") == "hide", "its own Hidden")
Check(MM.AddonButtonState("Junk") == "hover", "a damaged pick follows Addon buttons")
Check(MM.AddonButtonState(nil) == "hover", "an unnamed button follows Addon buttons")
ns.db.minimapCollector = true
Check(MM.AddonButtonState("BugSack") == nil, "the addon bag holds them all shown")
ns.db.minimapCollector = nil
MM.closed = true
Check(MM.AddonButtonState("Details") == "hide", "the closed minimap hides even a Shown one")
MM.closed = nil
Check(MM.AddonButtonKey({ GetName = function() return "LibDBIcon10_Details" end }) == "Details",
    "a LibDBIcon button's key is its name there")

-- The options button's own pick, where it differed from Addon buttons', is kept as its override in every profile.
ns.db = { dbVersion = 19, showOptionsButton = true, hoverOptionsButton = false, hoverMinimapAddonButtons = true,
    showMinimapAddonButtons = false, profiles = { Default = {}, Tank = { hoverOptionsButton = true },
    Heal = { hideMinimapAddonButtons = true }, Same = { hoverOptionsButton = true, hoverMinimapAddonButtons = true } } }
ns.KeepOptionsButtonPick()
local db, shots = ns.db, ns.db.profiles
Check(db.minimapButtonPicks and db.minimapButtonPicks[OUR] == "show", "always over on hover kept as Shown")
Check(db.showOptionsButton == nil and db.hoverOptionsButton == nil, "the old keys are gone")
Check(shots.Default.minimapButtonPicks == nil, "a profile on both defaults keeps no pick")
Check(shots.Tank.minimapButtonPicks[OUR] == "hover" and shots.Tank.hoverOptionsButton == nil, "on hover over shown kept")
Check(shots.Heal.minimapButtonPicks[OUR] == "show", "always over hidden kept as Shown")
Check(shots.Same.minimapButtonPicks == nil, "the same pick as Addon buttons needs none")
Check(db.dbVersion == 20, "the save is marked migrated")

print(string.format("button picks: %d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
