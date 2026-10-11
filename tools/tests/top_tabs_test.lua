-- Offline test for the macro window's tabs (Windows/Tabs.lua, Windows/PanelAfters.lua) under Lua 5.4: they follow
-- Classic Era's TabButtonTemplate and its Blizzard_MacroUI.xml, not the character window's foot tabs turned over.
-- A foot tab's label is never cut by a width the game fixed for an older word.
-- Run from the addon root: lua tools/tests/top_tabs_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 212

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

------------------------------------------------------------------ the stub client and addon

local Region = {}
Region.__index = function(_, key) return Region[key] or function() end end
local function New(name) return setmetatable({ name = name, points = {} }, Region) end
function Region:SetPoint(point, rel, relPoint, x, y)
    self.points[#self.points + 1] = { point = point, rel = rel, relPoint = relPoint, x = x, y = y }
end
function Region:ClearAllPoints() self.points = {} end
function Region:SetWidth(w) self.width = w end
function Region:SetHeight(h) self.height = h end
function Region:IsShown() return self.shown end
function Region:GetStringWidth() return self.label end

local function Tab(name, label)
    local tab = New(name)
    for _, field in ipairs({ "Left", "Middle", "Right", "LeftActive", "MiddleActive", "RightActive" }) do tab[field] = New(field) end
    tab.Text = New(name .. "Text")
    tab.Text.label = label
    function tab:GetParent() return {} end
    return tab
end

MacroFrameTab1, MacroFrameTab2 = Tab("MacroFrameTab1", 80), Tab("MacroFrameTab2", 100)

local hooks, specs, art = {}, {}, {}
local after = {}
local quiet = { __index = function() return function() end end }
local ns = setmetatable({ panels = setmetatable({ after = after }, quiet), KEYS = { TAB_GLOW = {} }, EMPTY = {} }, quiet)
ns.HookGlobal = function(name, fn) hooks[name] = fn end
ns.SkillInsetBox = false
ns.ThreeSlice = function(tab, _, spec)
    specs[tab] = specs[tab] or {}
    specs[tab][spec.fields[1]] = spec
end
ns.OwnTexture = function(frame, key)
    local own = rawget(frame, "own") or {}
    frame.own = own
    own[key] = own[key] or New(key)
    return own[key]
end
ns.SetTex = function(tex, key) art[tex] = key end
ns.SetPointOnce = function(region, ...)
    region:ClearAllPoints()
    region:SetPoint(...)
end

assert(loadfile(ROOT .. "/Windows/Tabs.lua"))("ClassicUIForever", ns)
assert(loadfile(ROOT .. "/Windows/PanelAfters.lua"))("ClassicUIForever", ns)

------------------------------------------------------------------ the checks

local failed = 0
local function Check(ok, what)
    if not ok then
        failed = failed + 1
        print("FAIL " .. what)
    end
end

-- The window skin dresses each tab, then the macro window's own pass places them.
local frame = { name = "MacroFrame" }
local first, second = MacroFrameTab1, MacroFrameTab2
ns.SkinTopTab(first)
ns.SkinTopTab(second)
after.MacroFrame(frame)

-- Era's TabButtonTemplate: the help tab sheet in quarters, caps 16 x 32 on the foot, the picked face 3 lower.
for _, tab in ipairs({ first, second }) do
    local on, off = specs[tab].LeftActive, specs[tab].Left
    Check(on.key == "topTabActive" and off.key == "topTabInactive", tab.name .. " wears the help tab sheets")
    Check(on.cap == 16 and off.cap == 16 and on.height == 32 and off.height == 32, tab.name .. " caps are 16 x 32")
    Check(on.edge == "BOTTOM" and off.edge == "BOTTOM" and on.oy == -3 and (off.oy or 0) == 0,
        tab.name .. " faces sit on the foot, the picked one 3 lower")
    Check(on.coords[1][2] == 0.25 and on.coords[2][2] == 0.75 and on.coords[3][1] == 0.75 and on.coords[1][3] == 0,
        tab.name .. " art is cut in quarters, upright")
    Check(tab.height == 32, tab.name .. " is 32 high")
end

-- Era's widths: the label plus 32; the character tab gives up 15 and its label stops at 130.
Check(first.width == 80 + 32, "the general tab is its label plus the caps (" .. tostring(first.width) .. ")")
Check(second.width == 100 - 15 + 32, "the character tab gives up 15 (" .. tostring(second.width) .. ")")
second.Text.label = 200
hooks.PanelTemplates_TabResize(second)
Check(second.width == 130 - 15 + 32 and second.Text.width == 115,
    "a long name stops the character tab at 147, its label at 115 (" .. tostring(second.width) .. ", " .. tostring(second.Text.width) .. ")")

-- Era's spots: the first 51 in and 28 down from the window's top left, the second against it.
local p = first.points[1]
Check(#first.points == 1 and p.point == "TOPLEFT" and p.rel == frame and p.relPoint == "TOPLEFT" and p.x == 51 and p.y == -28,
    "the general tab is at 51, -28 of the window")
p = second.points[1]
Check(#second.points == 1 and p.point == "LEFT" and p.rel == first and p.relPoint == "RIGHT" and p.x == 0 and p.y == 0,
    "the character tab starts at the general tab's right edge")

-- Era's label: a 13 high box 5 above the tab's foot, the same on the picked tab and the other (the art has no room
-- higher on the unpicked face: its body starts 11 down the 32).
first.LeftActive.shown, second.LeftActive.shown = true, false
hooks.PanelTemplates_SelectTab(first)
hooks.PanelTemplates_DeselectTab(second)
for _, tab in ipairs({ first, second }) do
    p = tab.Text.points[1]
    Check(#tab.Text.points == 1 and p.point == "BOTTOM" and p.rel == tab and p.relPoint == "BOTTOM" and p.y == 5,
        tab.name .. " label stands 5 above the tab foot")
    Check(tab.Text.height == 13, tab.name .. " label box is 13 high")
end

-- Era's hover glow: the old tab highlight, the tab's width, 2 right and 8 under its foot.
local glow = first.own.glow
Check(art[glow] == "topTabHighlight" and glow.height == 32, "the hover glow is Era's tab highlight, 32 high")
Check(#glow.points == 2 and glow.points[1].x == 2 and glow.points[1].y == -8 and glow.points[2].x == 2 and glow.points[2].y == -8,
    "the hover glow spans the tab, 2 right and 8 under its foot")

-- A foot tab's label at its own width: the game's resize had fixed it for the word before, which cut the new one.
local foot = Tab("FootTab", 60)
foot.fcuiPad = 38
foot.Text.width = 40
ns.FitBottomTab(foot)
Check(foot.Text.width == 0 and foot.width == 60 + 38,
    "a foot tab's label is freed from the width the game fixed (" .. tostring(foot.Text.width) .. ", " .. tostring(foot.width) .. ")")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("top_tabs_test: ok")
