-- Offline test under Lua 5.4 for the bag windows beside the right bars (Bar/BandWatch.lua, B.ColumnBox in
-- Bar/BandBars.lua). The game sends a right bar the layout holds as default to the screen's edge (an item on the cursor,
-- a stance change, a fight) and outside edit mode leaves it there; its buttons stay on our slots. The width beside the
-- bars is read from the slots, so the bags stay where they were (they jumped 39 sideways when it read the frame). With
-- the band off the buttons are the bar's again and the frame is what is drawn.
-- Run from the addon root: lua tools/tests/bags_after_bars_test.lua (CI runs every tools/tests/*_test.lua).
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

local handle = assert(io.open(ROOT .. "/Bar/BandWatch.lua", "r"))
local source = handle:read("a")
handle:close()

------------------------------------------------------------------ the lane's order

local from = source:find('placer:SetScript("OnUpdate"', 1, true)
Check(from ~= nil, "the lane's frame script is in the file")
local lane = from and source:sub(from) or ""
local bars = lane:find("SafeCall(PlaceTick", 1, true)
local bags = lane:find("SafeCall(AnchorOpenBags)", 1, true)
Check(bars ~= nil, "the lane puts the bars back (PlaceTick)")
Check(bags ~= nil, "the lane places the open bag windows (AnchorOpenBags)")
Check(bars and bags and bags > bars, "the bag windows are placed after the bars are put back")

-- Nowhere else: a second call ahead of the bars would bring the jump back. One definition and one guarded call.
local calls = 0
for _ in source:gmatch("AnchorOpenBags%s*%(") do calls = calls + 1 end
for _ in source:gmatch("SafeCall%(AnchorOpenBags") do calls = calls + 1 end
Check(calls == 2, "the bag windows are placed from one spot only (" .. calls .. " mentions)")

------------------------------------------------------------------ the width beside the bars, cut out of the files and run

local first = source:find("local function LiveSideWidth()", 1, true)
local last = source:find("B.SideColumnsWidth = SideColumnsWidth", 1, true)
Check(first and last and last > first, "the width's two functions are in the file")
local chunk = first and last and source:sub(first, last + #"B.SideColumnsWidth = SideColumnsWidth") or ""

handle = assert(io.open(ROOT .. "/Bar/BandBars.lua", "r"))
local barsSource = handle:read("a")
handle:close()
local boxFrom = barsSource:find("function B.ColumnBox(bar)", 1, true)
local boxTo = boxFrom and barsSource:find("\nend\n", boxFrom, true)
Check(boxFrom and boxTo, "the drawn box's function is in Bar/BandBars.lua")
local boxChunk = boxFrom and boxTo and barsSource:sub(boxFrom, boxTo + 4) or ""

local fight = false
local function Box(left, right, top, bottom)
    return {
        left = left, right = right, top = top, bottom = bottom, alpha = 1,
        IsVisible = function() return true end,
        IsShown = function() return true end,
        GetEffectiveAlpha = function(self) return self.alpha end,
        GetEffectiveScale = function() return 1 end,
        GetLeft = function(self) return self.left end,
        GetRight = function(self) return self.right end,
        GetTop = function(self) return self.top end,
        GetBottom = function(self) return self.bottom end,
    }
end
local slotOf = {}
-- A right column of 12: the frame and, on our slots, the buttons drawn 42 apart down from 602.
local function Column(left)
    local bar = Box(left, left + 36, 602, 104)
    bar.actionButtons = {}
    for i = 1, 12 do
        local slot = Box(left, left + 36, 602 - (i - 1) * 42, 566 - (i - 1) * 42)
        local button = { IsShown = function() return true end }
        button.GetParent = function() return button.home end
        button.home = slot
        slotOf[button] = slot
        bar.actionButtons[i] = button
    end
    return bar
end
-- His screen: the outer bar 2 in from the edge, the inner one 44 in.
local outer, inner = Column(1479), Column(1437)
local B = {}
local env = setmetatable({
    B = B, math = math, ipairs = ipairs, slotOf = slotOf,
    SideBarPair = function() return { outer, inner } end,
    InCombatLockdown = function() return fight end,
    UIParent = { GetRight = function() return 1517 end, GetEffectiveScale = function() return 1 end },
}, { __index = _G })
for name, text in pairs({ ["drawn box"] = boxChunk, ["side width"] = chunk }) do
    local run, err = load(text, name, "t", env)
    Check(run ~= nil, "the " .. name .. " loads (" .. tostring(err) .. ")")
    if run then run() end
end
local Width = B.SideColumnsWidth or function() return -1 end

Check(Width() == 80, "both right bars standing: 80 wide (" .. Width() .. ")")
Check(source:find("B.sideCalm = B.LiveSideWidth()", 1, true) ~= nil, "the band's snapshot keeps the width our pass left")
B.sideCalm = B.LiveSideWidth and B.LiveSideWidth()

-- The game sends the inner bar's frame to the edge, over the outer one; its buttons stay on our slots.
inner.left, inner.right = 1476, 1512
Check(Width() == 80, "the game carries the frame off: the slots still stand 80 in, the bags stay (" .. Width() .. ")")
fight = true
Check(Width() == 80, "in a fight too: 80 (" .. Width() .. ")")
fight = false

-- A faded column is not beside anything.
for _, button in ipairs(inner.actionButtons) do slotOf[button].alpha = 0 end
Check(Width() == 38, "the inner column faded: the outer one alone, 38 (" .. Width() .. ")")
for _, button in ipairs(inner.actionButtons) do slotOf[button].alpha = 1 end

-- Band off: the buttons are the bar's again, and the frame is what is drawn.
for _, button in ipairs(inner.actionButtons) do button.home = inner end
Check(Width() == 41, "band off: the inner frame at the edge, 41 (" .. Width() .. ")")
inner.left, inner.right = 1437, 1473
Check(Width() == 80, "band off, the frame back: 80 (" .. Width() .. ")")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("bags_after_bars_test: ok")
