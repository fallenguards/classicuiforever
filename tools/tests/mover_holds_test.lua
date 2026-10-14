-- Offline test under Lua 5.4 for game windows a window mover holds (UI/GameSpot.lua ns.MoverHolds): a mover that makes a
-- <window>Move frame for each window it takes puts that window back on its own spot on every show, so our reset and our
-- row's learned shift must leave it alone (the character window reset to the mover's spot, and ours opened past it).
-- Run from the addon root: lua tools/tests/mover_holds_test.lua (CI runs every tools/tests/*_test.lua).
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

-- The character window, the game's left panel, where a mover put it: on the game's line, far right.
local sheet = { left = 600, top = SCREEN_H - 116, moves = 0 }
function sheet:GetName() return "CharacterFrame" end
function sheet:IsShown() return true end
function sheet:IsVisible() return true end
function sheet:GetWidth() return 384 end
function sheet:GetHeight() return 512 end
function sheet:GetLeft() return self.left end
function sheet:GetTop() return self.top end
function sheet:GetEffectiveScale() return 1 end
function sheet:GetAttribute() return nil end
function sheet:SetPoint() self.moves = self.moves + 1 end
function GetUIPanel(slot) if slot == "left" then return sheet end end

local ns = {
    Safe = function(v) return v end,
    FramePlaced = function() return false end,
    WindowMoving = function() return false end,
    WindowLocked = function() return false end,
    WindowCovers = function() return false end,
}
assert(loadfile(ROOT .. "/UI/GameSpot.lua"))("ClassicUIForever", ns)

-- A mover holds it: our reset leaves it, and the row learns no shift from where the mover put it.
_G.CharacterFrameMove = {}
Check(ns.MoverHolds(sheet), "a <window>Move frame means a mover holds the window")
ns.GameSpot(sheet)
Check(sheet.moves == 0, "our reset does not move a window a mover holds")
local left = ns.GameRow()
Check(left == 16, "the row learns no shift from a window a mover holds (start " .. tostring(left) .. ")")

-- No mover: the reset puts it on its slot as before.
_G.CharacterFrameMove = nil
Check(not ns.MoverHolds(sheet), "no mover frame, ours")
ns.GameSpot(sheet)
Check(sheet.moves == 1, "with no mover, the reset puts it on the game's spot")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("mover_holds_test: all checks passed")
