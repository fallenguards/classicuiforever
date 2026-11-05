-- Offline test under Lua 5.4 for the unit frames' bar texts (Units/UnitFrameCore.lua UF.BarTexts): Forever re-anchors
-- the target and focus right number to its parent's RIGHT -3 on every update (Camelot UpdateHealthBarVisuals, 70790),
-- so the parent our texts get must end where that lands on our own right offset, not at the frame's edge.
-- Run from the addon root: lua tools/tests/bar_text_parent_test.lua (CI runs every tools/tests/*_test.lua).
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
local function Frame(name)
    local f = { name = name, points = {}, children = {} }
    function f:GetFrameLevel() return 5 end
    function f:ClearAllPoints() self.points = {} end
    function f:SetPoint(point, rel, relPoint, x, y)
        self.points[point] = { rel = rel, relPoint = relPoint, x = x or 0, y = y or 0 }
    end
    function f:SetParent(parent) self.parent = parent end
    f.SetDrawLayer, f.SetFontObject, f.EnableMouse, f.Show, f.SetAllPoints = NOOP, NOOP, NOOP, NOOP, NOOP
    return f
end

-- The addon table: what UnitFrameCore reads at load answers a no-op; its own frames are plain fakes.
local ns = setmetatable({}, { __index = function() return NOOP end })
ns.OwnFrame = function(parent, key)
    parent.children[key] = parent.children[key] or Frame(key)
    return parent.children[key]
end
assert(loadfile(ROOT .. "/Units/UnitFrameCore.lua"))("ClassicUIForever", ns)
local UF = ns.UF
UF.HoverBoth = NOOP

local TARGET_TEXTS = { { "CENTER", 0, 0 }, { "LEFT", 5, 0 }, { "RIGHT", -7, 0 } }
for _, power in ipairs({ false, true }) do
    local frame, bar = Frame("frame"), Frame("bar")
    local center, left, right = Frame("center"), Frame("left"), Frame("right")
    UF.BarTexts(frame, nil, bar, { center, left, right }, TARGET_TEXTS, Frame("client"), frame, "target", power)
    local parent = right.parent
    local what = power and "power" or "health"
    Check(parent and parent.points.BOTTOMRIGHT and parent.points.BOTTOMRIGHT.rel == bar,
        what .. ": the texts' parent ends on the bar, not on the frame's text holder")
    Check(parent and parent.points.TOPLEFT and parent.points.TOPLEFT.rel == bar, what .. ": the parent starts on the bar")
    -- The client's SetPoint("RIGHT", -3, 0) on its parent: where the number's right edge ends, off the bar's right.
    local landed = parent and parent.points.BOTTOMRIGHT and parent.points.BOTTOMRIGHT.x + UF.CLIENT_RIGHT_X
    Check(landed == TARGET_TEXTS[3][2], what .. ": the client's re-anchor lands on our -7 (got " .. tostring(landed) .. ")")
    Check(right.points.RIGHT and right.points.RIGHT.rel == bar and right.points.RIGHT.x == -7,
        what .. ": our own anchor still on the bar at -7")
end

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("bar_text_parent_test: all checks passed")
