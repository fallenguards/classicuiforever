-- dbVersion 22: Main bar alone is gone; One bar alone sets its pieces' own options, so nobody's band changes. In the
-- account and every profile.
-- luacheck: std lua54
local ROOT = arg and arg[0] and arg[0]:match("^(.*)/tools/tests/") or "."
local failed = 0
local function Check(label, got, want)
    if got ~= want then
        failed = failed + 1
        print("FAIL " .. label .. ": got " .. tostring(got) .. ", want " .. tostring(want))
    end
end

local ns = { band = {}, db = {} }
local source = assert(io.open(ROOT .. "/Bar/BandShape.lua")):read("a")
local first = source:find("-- dbVersion 22:", 1, true)
local last = first and select(2, source:find("\nend\n", first, true))
assert(first and last, "the move is in Bar/BandShape.lua")
assert(load(source:sub(first, last), "move", "t", setmetatable({ ns = ns }, { __index = _G })))()

ns.db = {
    -- One bar alone (its default): no latency bar, key ring with the bags, as it looked.
    oneBar = true, hideLatencyBar = false, keyRingWithBags = false,
    profiles = {
        -- One bar with its pieces kept: the page arrows stay, now the modern ones.
        kept = { oneBar = true, oneBarAlone = false, hideLatencyBar = false },
        -- No One bar: nothing to move.
        full = { oneBar = false, oneBarAlone = true, hideLatencyBar = false },
    },
}
ns.OneBarAloneGone()
local db, p = ns.db, ns.db.profiles
Check("a lone band hides its latency bar", db.hideLatencyBar, true)
Check("and keeps its key ring with the bags", db.keyRingWithBags, true)
Check("a band that kept its pieces keeps page arrows", p.kept.modernPageArrows, true)
Check("and its latency bar", p.kept.hideLatencyBar, false)
Check("no One bar: its latency bar as it was", p.full.hideLatencyBar, false)
Check("the old key goes", p.full.oneBarAlone == nil and p.kept.oneBarAlone == nil, true)
Check("the version moves on", db.dbVersion, 22)

if failed > 0 then os.exit(1) end
print("one_bar_look_test: ok")
