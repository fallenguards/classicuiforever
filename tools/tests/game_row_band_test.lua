-- Offline test under Lua 5.4 for which game windows stand in the windows' row (ns.GameWindowOffRow in UI/GameSpot.lua):
-- the band the game's manager places in, from its line up to the highest its fit raises a window. The game's spell
-- window on its first open (laid at its two-page size, then shrunk to its talents, 2026-10-12) stays in the row; a
-- window moved down by hand leaves it.
-- Run from the addon root: lua tools/tests/game_row_band_test.lua (CI runs every tools/tests/*_test.lua).
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

local H = 853
local env = setmetatable({
    UIParent = { GetHeight = function() return H end, GetEffectiveScale = function() return 1 end },
    UIPanelWindows = { PlayerSpellsFrame = { yoffset = 75 }, CharacterFrame = {} },
    GetUIPanelLayoutAttribute = function(name) return name == "TOP_OFFSET" and -116 or 16 end,
}, { __index = _G })
env._G = env
local ns = { Safe = function(v) return v end }
assert(loadfile(ROOT .. "/UI/GameSpot.lua", "t", env))("ClassicUIForever", ns)

local function Panel(name, top, height)
    return {
        GetTop = function() return top end, GetHeight = function() return height end,
        GetEffectiveScale = function() return 1 end, GetAttribute = function() return nil end,
        GetName = function() return name end,
    }
end

Check(not ns.GameWindowOffRow(Panel("CharacterFrame", H - 116, 450)), "the sheet on the game's line: in the row")
Check(not ns.GameWindowOffRow(Panel("CharacterFrame", H - 104, 450)), "the classic sheet on Era's spot, 12 up: in the row")
Check(not ns.GameWindowOffRow(Panel("PlayerSpellsFrame", H - 10, 708)),
    "the spell window raised by the fit, its height changed after it was laid: in the row")
Check(not ns.GameWindowOffRow(Panel("PlayerSpellsFrame", H - 41, 600)), "the spell window on its own line: in the row")
Check(ns.GameWindowOffRow(Panel("CharacterFrame", H - 300, 450)), "the sheet moved down by hand: out of the row")
Check(ns.GameWindowOffRow(Panel("PlayerSpellsFrame", H - 200, 708)), "the spell window moved down by hand: out of the row")

if failed > 0 then
    print(failed .. " failed")
    os.exit(1)
end
print("game_row_band_test: all passed")
