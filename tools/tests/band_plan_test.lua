-- Offline test for the band plan (Bar/BandShape.lua) under Lua 5.4.
-- Run from the addon root: lua tools/tests/band_plan_test.lua (CI runs every tools/tests/*_test.lua).
-- The latency and key ring section may drop its own left post only right after a real post (the micro row's, the
-- bags' end); what follows the page number slot starts at its post, not past the dark stone beside the box.
-- A client with no key ring has its reagent bag as the key ring piece: the section draws its slot as the key ring's.
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 122 212

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

-- Any method on a stub frame does nothing.
local function Stub()
    return setmetatable({}, { __index = function() return function() end end })
end
function CreateFrame() return Stub() end
function GetTime() return 0 end
local keyRingStub = Stub()
CharacterReagentBag0Slot = Stub()

-- Other addon helpers the band files touch at load: callable, indexable, doing nothing.
local Loose = {}
setmetatable(Loose, { __index = function() return Loose end, __call = function() return Loose end })
local ns = setmetatable({
    L = setmetatable({}, { __index = function(_, k) return k end }),
    ValidPlace = function(p) return type(p) == "table" and p.point ~= nil end,
    db = {},
}, { __index = function() return Loose end })
for _, file in ipairs({ "Bar/Band.lua", "Bar/BandShape.lua" }) do
    local chunk = assert(loadfile(ROOT .. "/" .. file))
    chunk("ClassicUIForever", ns)
end
local B = ns.band
-- Later files' answers the band reads (Bar/BandBagsShow.lua): no pick, nothing folded.
B.BagsFolded = function() return false end
B.BagExtraCells = function() return B.ReagentSlot() and 1 or 0 end

-- Section starts that leave out its own left post (B.TailSpan: latency after a post 7, key ring alone after one 23).
local POSTLESS = { [7] = true, [23] = true }

local failures, cases = 0, 0
for _, micro in ipairs({ true, false }) do
for _, bags in ipairs({ true, false }) do
for _, bagsFirst in ipairs({ true, false }) do
for _, noPages in ipairs({ true, false }) do
for _, hideLatency in ipairs({ true, false }) do
for _, hideKey in ipairs({ true, false }) do
for _, reagent in ipairs({ true, false }) do
for _, eraBags in ipairs({ true, false }) do
for _, keyRing in ipairs({ true, false }) do
    KeyRingButton = keyRing and keyRingStub or nil
    ns.db.hideLatencyBar, ns.db.hideKeyRing = hideLatency, hideKey
    ns.db.reagentBagSlot, ns.db.eraBagSize = reagent, eraBags
    B.shape.noPages = noPages
    local plan = B.BandPlan(micro, bags, bagsFirst, B.MICRO_REGION_MAX)
    cases = cases + 1
    -- Bar 2 right of bar 1: its run between bar 1's and the rest, which all stands 504 further along; left of it: its
    -- run first, bar 1's run and first button 504 further along, the rest the same.
    local rightPlan = B.BandPlan(micro, bags, bagsFirst, B.MICRO_REGION_MAX, 504)
    if not (rightPlan.bar2Start == plan.base and rightPlan.bar2X == plan.base and rightPlan.bar1X == B.ROW_X
        and rightPlan.base == plan.base + 504 and rightPlan.width == plan.width + 504) then
        failures = failures + 1
        print(string.format("FAIL bar 2 right: micro=%s bags=%s base %s->%s width %s->%s", tostring(micro), tostring(bags),
            tostring(plan.base), tostring(rightPlan.base), tostring(plan.width), tostring(rightPlan.width)))
    end
    local leftPlan = B.BandPlan(micro, bags, bagsFirst, B.MICRO_REGION_MAX, 504, true)
    if not (leftPlan.bar2Start == 0 and leftPlan.bar2X == B.ROW_X and leftPlan.bar1X == B.ROW_X + 504
        and leftPlan.bar1Start == B.ROW_X + 504 and leftPlan.base == plan.base + 504 and leftPlan.width == plan.width + 504) then
        failures = failures + 1
        print(string.format("FAIL bar 2 left: micro=%s bags=%s bar1X %s base %s->%s", tostring(micro), tostring(bags),
            tostring(leftPlan.bar1X), tostring(plan.base), tostring(leftPlan.base)))
    end
    -- A piece after the page number slot starts at its post, under the box's edge: no dark stone between.
    local after = not plan.microFirst and not noPages and (plan.tailStart or plan.bagsStart)
    local edge = plan.base + B.PAGE_POST
    if after and not (plan.pageEdge == edge and (plan.tailStart == edge or plan.bagsStart == edge)) then
        failures = failures + 1
        print(string.format("FAIL dark stone after the page number post: micro=%s bags=%s bagsFirst=%s start=%s edge=%s",
            tostring(micro), tostring(bags), tostring(bagsFirst), tostring(after), tostring(plan.pageEdge)))
    end
    if plan.tailStart and POSTLESS[plan.tailU0] then
        local afterMicroPost = plan.microPost ~= nil and plan.tailStart == plan.microPost + B.POST_W
        local afterBags = plan.bagsEnd ~= nil and plan.tailStart == plan.bagsEnd
        if not (afterMicroPost or afterBags) then
            failures = failures + 1
            print(string.format("FAIL section drops its left post with no post before it: micro=%s bags=%s bagsFirst=%s"
                .. " noPages=%s hideLatency=%s hideKey=%s tailStart=%s tailU0=%s", tostring(micro), tostring(bags),
                tostring(bagsFirst), tostring(noPages), tostring(hideLatency), tostring(hideKey),
                tostring(plan.tailStart), tostring(plan.tailU0)))
        end
    end
    -- The key slot is drawn exactly while the key ring piece stands on the band: Forever's key ring, or with none the
    -- reagent bag out of a full slot.
    local piece = keyRing or not reagent
    if plan.tailStart and (plan.tailSlot and true or false) ~= (piece and not hideKey) then
        failures = failures + 1
        print(string.format("FAIL key slot drawn %s with the piece %s: micro=%s bags=%s keyRing=%s reagentSlot=%s hideKey=%s",
            tostring(plan.tailSlot), tostring(piece and not hideKey), tostring(micro), tostring(bags), tostring(keyRing),
            tostring(reagent), tostring(hideKey)))
    end
end end end end end end end end end

-- A hidden key ring never rides the bags: their pick shows every button riding the row (Main bar alone flickered it).
KeyRingButton = keyRingStub
B.shape.bags = false
for _, withBags in ipairs({ true, false }) do
    ns.db.oneBar, ns.db.keyRingWithBags, ns.db.hideKeyRing = true, withBags, true
    cases = cases + 1
    if B.KeyRingWithBags() then
        failures = failures + 1
        print(string.format("FAIL hidden key ring rides the bags: withBags=%s", tostring(withBags)))
    end
end
ns.db.oneBar, ns.db.hideKeyRing, ns.db.keyRingWithBags = false, false, true
cases = cases + 1
if not B.KeyRingWithBags() then
    failures = failures + 1
    print("FAIL a shown key ring with the option on stays off the bags moved off the band")
end

-- A row that fits the third sheet (eight buttons: region 257 less the trim) draws Era's art (eram bar): the sheet to its
-- end at 768, the section from there with its own post, the bags after it at 806 (their first slot at Era's 813).
KeyRingButton = keyRingStub
ns.db.hideLatencyBar, ns.db.hideKeyRing, ns.db.reagentBagSlot, ns.db.eraBagSize, ns.db.keyRingWithBags = false, false, false, true, false
B.shape.noPages = false
for _, region in ipairs({ 248, 257 }) do
    local plan = B.BandPlan(true, true, false, region)
    cases = cases + 1
    if not (plan.wholeSheet and plan.microEnd == 768 and plan.tailStart == 768 and plan.tailU0 == 0 and plan.microPost == nil
        and plan.bagsStart == 806) then
        failures = failures + 1
        print(string.format("FAIL region %d: Era's whole third sheet (microEnd=%s tailStart=%s tailU0=%s microPost=%s bagsStart=%s)",
            region, tostring(plan.microEnd), tostring(plan.tailStart), tostring(plan.tailU0), tostring(plan.microPost),
            tostring(plan.bagsStart)))
    end
end
-- Past the sheet (more buttons): the row ends on its post and the section starts past it, as before.
local long = B.BandPlan(true, true, false, 300)
cases = cases + 1
if long.wholeSheet or long.microPost == nil or long.tailStart ~= long.microPost + B.POST_W then
    failures = failures + 1
    print("FAIL a row past the third sheet keeps its post before the section")
end

-- Any micro floor ends on Era's third sheet's last 48 columns (its fade to black and rim) and fills its width exactly;
-- the whole sheet is drawn unbroken.
for _, case in ipairs({ { 211, 45 }, { 100, 45 }, { 300, 45 }, { 420, 37 }, { 30, 45 } }) do
    local width, u0 = case[1], case[2]
    local runs = B.MicroRuns(512, width, u0)
    cases = cases + 1
    local x, ok = 512, true
    for _, run in ipairs(runs) do
        if run[1] ~= x or run[2] <= 0 or math.abs((run[4] - run[3]) * 256 - run[2]) > 1e-9 then ok = false end
        x = x + run[2]
    end
    local last = runs[#runs]
    local endW = math.min(width, 48)
    if not ok or x ~= 512 + width or last[4] ~= 1 or math.abs(last[3] * 256 - (256 - endW)) > 1e-9 then
        failures = failures + 1
        print(string.format("FAIL micro floor width %d from u %d: %d runs, ends at %d", width, u0, #runs, x))
    end
end
local whole = B.MicroRuns(557, 211, 45)
cases = cases + 1
if not (#whole == 2 and whole[1][4] == whole[2][3]) then
    failures = failures + 1
    print("FAIL the whole third sheet breaks before its end")
end

print(string.format("band plan: %d cases, %d failures", cases, failures))
if failures > 0 then os.exit(1) end
