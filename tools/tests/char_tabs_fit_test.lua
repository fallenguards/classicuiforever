-- Offline test under Lua 5.4 for the character window's foot tabs (FitTabs and CenterTabs in Character/CharacterSheet.lua):
-- a row too wide for the art is squeezed: the whole foot from the portrait corner (3), tabs tucked 17, short tabs down to
-- 40, narrowed by exactly what it must and centered there. A row that fits keeps its widths and the body's centering
-- (the border under the portrait, 11). The German row with a pet had only 10 px each side of its labels.
-- Run from the addon root: lua tools/tests/char_tabs_fit_test.lua (CI runs every tools/tests/*_test.lua).
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

local handle = assert(io.open(ROOT .. "/Character/CharacterSheet.lua", "r"))
local source = handle:read("a")
handle:close()
local function Body(header)
    local from = source:find(header, 1, true)
    local to = from and source:find("\nend\n", from, true)
    return from and to and source:sub(from, to + 4) or nil
end
local function Const(name) return tonumber(source:match("local " .. name .. "%s*=%s*([%d.]+)")) end

local fit, center = Body("local function FitTabs(shown)"), Body("local function CenterTabs(shown, strip, squeezed)")
Check(fit and center, "FitTabs and CenterTabs are in the file")

local TAB_FIRST_X, TAB_OVERLAP = Const("TAB_FIRST_X"), source:match("local TAB_OVERLAP, HIT_INSET = (%d+)")
TAB_OVERLAP = tonumber(TAB_OVERLAP)
local squeezeOverlap, squeezeMin = source:match("local SQUEEZE_OVERLAP, SQUEEZE_MIN_WIDTH = (%d+), (%d+)")
local SQUEEZE_OVERLAP, SQUEEZE_MIN_WIDTH = tonumber(squeezeOverlap), tonumber(squeezeMin)
local artLeft, artRight = source:match("local TAB_ART_LEFT, TAB_ART_RIGHT = (%d+), (%d+)")
local TAB_ART_LEFT, TAB_ART_RIGHT = tonumber(artLeft), tonumber(artRight)
Check(TAB_ART_LEFT and TAB_ART_RIGHT, "the tab art's clear edges are in the file")
Check(SQUEEZE_OVERLAP and SQUEEZE_MIN_WIDTH, "the squeeze constants are in the file")
local labelOf = {}
local placedX, tucked
local env = setmetatable({
    TAB_FIRST_X = TAB_FIRST_X, TAB_OVERLAP = TAB_OVERLAP,
    SQUEEZE_OVERLAP = SQUEEZE_OVERLAP, SQUEEZE_MIN_WIDTH = SQUEEZE_MIN_WIDTH,
    TAB_ART_LEFT = TAB_ART_LEFT, TAB_ART_RIGHT = TAB_ART_RIGHT,
    T = { ART_RIGHT_EDGE = 349, ART_LEFT_EDGE = 3, BODY_LEFT_EDGE = 11 },
    TabFloor = function(tab, squeezed) return math.max(squeezed and SQUEEZE_MIN_WIDTH or 44, labelOf[tab] + 20) end,
    ns = { SetPointOnce = function(_, point, _, _, x)
        if point == "BOTTOMLEFT" then placedX = x else tucked = -x end
    end },
}, { __index = _G })
local chunk = load((fit or "") .. "\n" .. (center or "") .. "\nreturn FitTabs, CenterTabs", "tabs", "t", env)
local FitTabs, CenterTabs = chunk()

-- Tabs as SetLabel makes them: label rounded up, plus 30, at least 44.
local function Row(labels)
    local shown = {}
    for i, label in ipairs(labels) do
        local tab = { w = math.max(44, math.min(106, math.ceil(label) + 30)), text = { SetWidth = function() end } }
        function tab:GetWidth() return self.w end
        function tab:SetWidth(w) self.w = w end
        labelOf[tab] = math.ceil(label)
        shown[i] = tab
    end
    return shown
end
local function Edges(shown, overlap)
    local right = placedX - overlap * (#shown - 1)
    for _, tab in ipairs(shown) do right = right + tab.w end
    return placedX, right
end

-- German with a pet: Charakter, Begleiter, Ruf, Fertigkeiten, PvP, Abzeichen, Stats (the probe's label widths).
local german = Row({ 48.6, 45.0, 18.4, 58.1, 19.0, 53.9, 24.9 })
local squeezed = FitTabs(german)
CenterTabs(german, {}, squeezed)
Check(squeezed == true and tucked == SQUEEZE_OVERLAP, "German: squeezed, tabs tucked further")
local left, right = Edges(german, SQUEEZE_OVERLAP)
-- The drawn row against the window's drawn edges at the foot (the body's border at 11, the art's right edge at 349).
local function Gaps(l, r) return l + TAB_ART_LEFT - 11, 349 - (r - TAB_ART_RIGHT) end
local gapL, gapR = Gaps(left, right)
Check(math.abs(gapL - gapR) <= 0.5,
    string.format("German: the drawn row the same distance inside each window edge (%.1f left, %.1f right)", gapL, gapR))
Check(gapL >= 0 and gapR >= 0, "German: the drawn row inside the window")
Check(right - left >= 349 - 3 - 1, string.format("German: cut no more than it must (%.1f wide)", right - left))
local tightest = math.huge
for _, tab in ipairs(german) do tightest = math.min(tightest, tab.w - labelOf[tab]) end
Check(tightest >= 24, string.format("German: every label has at least 12 px each side (%d)", tightest))

-- English without a pet: a row that fits is not cut, and stands centered on the body when its right margin is the less.
local english = Row({ 50, 58, 28, 20, 46, 26 })
local before = {}
for i, tab in ipairs(english) do before[i] = tab.w end
Check(FitTabs(english) == false, "English: not squeezed")
CenterTabs(english, {}, false)
local same = true
for i, tab in ipairs(english) do same = same and tab.w == before[i] end
Check(same, "English: a row that fits keeps every tab's width")
left, right = Edges(english, TAB_OVERLAP)
gapL, gapR = Gaps(left, right)
Check(math.abs(gapL - gapR) <= 0.5 or left == TAB_FIRST_X,
    string.format("English: centered on the body or at 1.x's spot (%.1f to %.1f)", left, right))

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("char_tabs_fit_test: ok")
