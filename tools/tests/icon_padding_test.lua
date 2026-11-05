-- Offline test for Icon Padding on the band (Bar/Band.lua B.PadGap, Bar/BandShape.lua) under Lua 5.4: the game's
-- slider past its least (2) spreads the buttons, and bar 1's sockets (and bar 2's on the line) widen with them, every
-- pit under its button and the runs edge to edge; at the least nothing moves.
-- Run from the addon root: lua tools/tests/icon_padding_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 122 212

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local function Stub()
    return setmetatable({}, { __index = function() return function() end end })
end
function CreateFrame() return Stub() end
function GetTime() return 0 end
Enum = { EditModeActionBarSetting = { IconPadding = 4, NumIcons = 1 } }

local Loose = {}
setmetatable(Loose, { __index = function() return Loose end, __call = function() return Loose end })
local ns = setmetatable({
    L = setmetatable({}, { __index = function(_, k) return k end }),
    ValidPlace = function(p) return type(p) == "table" and p.point ~= nil end,
    db = { hideLatencyBar = true, hideKeyRing = true },
}, { __index = function() return Loose end })
for _, file in ipairs({ "Bar/Band.lua", "Bar/BandShape.lua" }) do
    assert(loadfile(ROOT .. "/" .. file))("ClassicUIForever", ns)
end
local B = ns.band
B.BagsFolded = function() return false end
B.BagExtraCells = function() return 0 end

local failed = 0
local function Check(ok, what)
    if not ok then
        failed = failed + 1
        print("FAIL " .. what)
    end
end

local function Bar(pad) return { GetSettingValue = function() return pad end } end

-- The gap: none at the game's least or unset, 1 px a step near enough, scaled for the 30 px buttons.
Check(B.PadGap(Bar(nil)) == 0 and B.PadGap(Bar(2)) == 0, "no gap at the least or unset")
Check(B.PadGap(Bar(3)) == 1 and B.PadGap(Bar(10)) == 6, "padding 3 adds 1, padding 10 adds 6")
Check(B.PadGap(Bar(10), 30) == 5, "pet and stance buttons take their share")

local PITCH, ROW_X = B.BUTTON_PITCH, B.ROW_X

-- Where combined sheet u (sheets 1 and 2 as 0 to 512) lands in the bar runs, or nil.
local function Lands(list, u, from)
    for i = from or 1, #list do
        local x, w, sheet, u0, u1, owner = table.unpack(list[i])
        if owner == "bar" and sheet <= 2 then
            local a, b = u0 * 256 + (sheet - 1) * 256, u1 * 256 + (sheet - 1) * 256
            if u >= a - 1e-6 and u < b - 1e-6 then return x + (u - a) * w / (b - a), i end
        end
    end
end

local function Plan(gap1, gap2, icons, bar2Slots, left)
    B.shape.cut = (12 - icons) * PITCH
    B.shape.bar1Gap, B.shape.bar2Gap = gap1, gap2
    local bar2W = bar2Slots and bar2Slots * PITCH + (bar2Slots - 1) * gap2 or nil
    B.shape.plan = B.BandPlan(false, false, false, B.MICRO_REGION_MAX, bar2W, left)
    return B.shape.plan, B.Segments()
end

-- Each shown pit under its button: bar 1's i-th at bar1X + (i - 1) (42 + gap); the runs edge to edge up to the page room.
for _, case in ipairs({ { 6, 12 }, { 6, 10 }, { 1, 1 }, { 3, 7 } }) do
    local gap, icons = case[1], case[2]
    local plain = Plan(0, 0, icons)
    local plan, list = Plan(gap, 0, icons)
    Check(plan.base == plain.base + (icons - 1) * gap, string.format("bar 1 (%d icons, gap %d): the band %d wider",
        icons, gap, (icons - 1) * gap))
    local from = 1
    for i = 1, icons do
        local u = ROW_X + (12 - icons + i - 1) * PITCH
        local x, at = Lands(list, u, from)
        from = at or from
        Check(x and math.abs(x - (plan.bar1X + (i - 1) * (PITCH + gap))) < 1e-6,
            string.format("bar 1 (%d icons, gap %d): pit %d at %s", icons, gap, i, tostring(x)))
    end
    local reach = 0
    for _, seg in ipairs(list) do
        if seg[6] == "bar" and seg[3] <= 2 then
            Check(math.abs(seg[1] - reach) < 1e-6, string.format("bar 1 (%d icons, gap %d): runs meet at %s", icons, gap,
                tostring(seg[1])))
            reach = seg[1] + seg[2]
        end
    end
    Check(math.abs(reach - plan.base) < 1e-6, string.format("bar 1 (%d icons, gap %d): its runs end at the page room",
        icons, gap))
end

-- Bar 2 on the line, right of bar 1 and left of it: its pits under its buttons too.
for _, left in ipairs({ false, true }) do
    local plan, list = Plan(4, 5, 12, 6, left)
    for i = 1, 6 do
        local x = Lands(list, ROW_X + (left and 6 or 0) * PITCH + (i - 1) * PITCH)
        if left then
            Check(x and math.abs(x - (plan.bar2X + (i - 1) * (PITCH + 5))) < 1e-6,
                string.format("bar 2 left: pit %d at %s", i, tostring(x)))
        else
            local _, at = Lands(list, ROW_X + 11 * PITCH)
            x = Lands(list, ROW_X + (i - 1) * PITCH, (at or 0) + 1)
            Check(x and math.abs(x - (plan.bar2X + (i - 1) * (PITCH + 5))) < 1e-6,
                string.format("bar 2 right: pit %d at %s", i, tostring(x)))
        end
    end
    local _, lastAt = Lands(list, ROW_X + 11 * PITCH, left and 3 or 1)
    Check(lastAt ~= nil, "bar 2 " .. (left and "left" or "right") .. ": bar 1's runs drawn")
end

-- At the least: the band's own two sheets, as before.
local plan, list = Plan(0, 0, 12)
Check(list[1][1] == 0 and list[1][2] == 256 and list[2][1] == 256 and list[2][2] == 256 and plan.base == 512,
    "no padding: bar 1's two sheets whole")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("icon_padding_test: all checks passed")
