-- Offline test under Lua 5.4 for bars 2 and 3 on the classic band (Bar/ClassicBar.lua PairWidths): the pair keeps its
-- spots when either bar is turned off, as Era's bars never move. The one left on jumped to its old spot (2026-11-20).
-- Run from the addon root: lua tools/tests/bar_pair_keep_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local failed = 0
local function Check(ok, what)
    if not ok then
        failed = failed + 1
        print("FAIL: " .. what)
    end
end

local source = assert(io.open(ROOT .. "/Bar/ClassicBar.lua")):read("a")
local function Body(pattern, what)
    local body = source:match(pattern)
    Check(body ~= nil, what .. " is found")
    return body or ""
end
local shapeBody = Body("local function BandRowShape%(bar%)\n(.-)\nend\n", "BandRowShape")
local pairBody = Body("local function PairWidths%(%)\n(.-)\nend\n", "PairWidths")

local function Bar(shown, moved)
    local buttons = {}
    for i = 1, 12 do buttons[i] = i end
    return { shown = shown, moved = moved, actionButtons = buttons, IsShown = function(self) return self.shown end }
end
local lower, upper = Bar(true), Bar(true)
local env = setmetatable({
    MultiBarBottomLeft = lower, MultiBarBottomRight = upper,
    ns = { GetMainBar = function() return {} end },
    B = { shape = {}, PadGap = function() return 0 end },
    OneBar = function() return false end,
    SystemMoved = function(bar) return bar.moved == true end,
    BarVertical = function() return false end,
    BarRows = function() return 1 end,
    BandScale = function() return 1 end,
    IconScale = function() return 1 end,
    RowSlots = function(bar) return #bar.actionButtons end,
    BUTTON_PITCH = 42, SLOT_SPACE = 6,
}, { __index = _G })
env.BandRowShape = assert(load("local bar = ...\n" .. shapeBody, "BandRowShape", "t", env))
local PairWidths = assert(load(pairBody, "PairWidths", "t", env))

local both1, both2 = PairWidths()
Check(both1 ~= nil and both2 ~= nil, "both bars on: laid as one centred run")
lower.shown = false
local only3a, only3b = PairWidths()
Check(only3a == both1 and only3b == both2, "bar 2 turned off: bar 3 keeps the pair's spot")
lower.shown, upper.shown = true, false
local only2a, only2b = PairWidths()
Check(only2a == both1 and only2b == both2, "bar 3 turned off: bar 2 keeps the pair's spot")
upper.shown, upper.moved = true, true
Check(PairWidths() == nil, "a bar moved off the band leaves the other on its own spot")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("bar_pair_keep_test: ok")
