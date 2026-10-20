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

print(string.format("band plan: %d cases, %d failures", cases, failures))
if failures > 0 then os.exit(1) end
