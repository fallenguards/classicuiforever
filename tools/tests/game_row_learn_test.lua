-- Offline test under Lua 5.4 for the row's learned start (UI/GameSpot.lua Learn, ns.GameRow): the game's left window
-- teaches the row where the game's row begins, so a centering addon moves ours too. The loot window is the game's left
-- panel as well, shown at its own edit mode spot on the same line: it must teach nothing, or the row (and a spellbook
-- laid after a fight) went to the loot window's far right spot. Reset windows forgets a learned start.
-- Run from the addon root: lua tools/tests/game_row_learn_test.lua (CI runs every tools/tests/*_test.lua).
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

local SCREEN_H = 853
UIParent = { GetHeight = function() return SCREEN_H end, GetEffectiveScale = function() return 1 end }
local LAYOUT = { LEFT_OFFSET = 16, TOP_OFFSET = -116 }
function GetUIPanelLayoutAttribute(name) return LAYOUT[name] end
function InCombatLockdown() return false end
UIPanelWindows = { LootFrame = { area = "left", pushable = 0 }, CharacterFrame = { area = "left", pushable = 3 } }

-- A game window on the manager's line (top 116 down), standing at left.
local function Panel(name, left, height)
    local panel = { left = left, height = height }
    function panel:GetName() return name end
    function panel:IsVisible() return true end
    function panel:GetLeft() return self.left end
    function panel:GetTop() return SCREEN_H - 116 end
    function panel:GetHeight() return self.height end
    function panel:GetEffectiveScale() return 1 end
    function panel:GetAttribute() return nil end
    return panel
end
local leftPanel
function GetUIPanel(slot) if slot == "left" then return leftPanel end end

local ns = {
    Safe = function(v) return v end,
    FramePlaced = function() return false end,
    WindowMoving = function() return false end,
    MoverHolds = function() return false end,
    WINDOW_FLOATS = { LootFrame = true },
}
assert(loadfile(ROOT .. "/UI/GameSpot.lua"))("ClassicUIForever", ns)

-- The loot window at its edit mode spot, far right on the line: the row starts where the layout says.
leftPanel = Panel("LootFrame", 1266, 300)
local left = ns.GameRow()
Check(left == 16, "the loot window teaches no start (" .. tostring(left) .. ")")
local shift, from = ns.GameRowShift()
Check(shift == 0 and from == nil, "nothing learned from it")

-- The character window moved right by a centering addon: ours follow.
leftPanel = Panel("CharacterFrame", 600, 512)
left = ns.GameRow()
Check(left == 600, "the character window teaches the row its start (" .. tostring(left) .. ")")
shift, from = ns.GameRowShift()
Check(shift == 584 and from == "CharacterFrame", "learned from the character window")

-- Kept with no game window up; Reset windows forgets it.
leftPanel = nil
Check(ns.GameRow() == 600, "a learned start stays while no game window is up")
ns.ForgetRowShift()
Check(ns.GameRow() == 16, "Reset windows puts the row back at the layout's start")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("game_row_learn_test: all checks passed")
