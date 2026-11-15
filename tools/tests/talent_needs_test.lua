-- Offline test under Lua 5.4 for the talents window's red needs (UI/TalentWindow.lua AddNeeds): Forever's points-in-
-- the-tree need is a condition the client marks no gate (isGate false, /fcuidev talentgates 2026-11-15) whose amount is
-- the points still missing; the line names Era's total (missing plus spent in the tree), once, while unmet.
-- Run from the addon root: lua tools/tests/talent_needs_test.lua (CI runs every tools/tests/*_test.lua).
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

local source = assert(io.open(ROOT .. "/UI/TalentWindow.lua")):read("a")
local body = source:match("local function AddNeeds%(talent, tree, tab%)\n(.-)\nend\n")
Check(body ~= nil, "AddNeeds is found")

local lines = {}
local conds = {}
local env = setmetatable({
    GameTooltip = { AddLine = function(_, text, r, g, b) lines[#lines + 1] = { text = text, r = r, g = g, b = b } end },
    C_Traits = { GetConditionInfo = function(_, condID) return conds[condID] end },
    C_Spell = { GetSpellName = function(id) return "Spell" .. tostring(id) end },
    TOOLTIP_TALENT_TIER_POINTS = "Requires %d points in %s Talents",
    L = {},
}, { __index = _G })
local AddNeeds = assert(load("local talent, tree, tab = ...\n" .. (body or ""), "AddNeeds", "t", env))

local function Run(talentConds, spent)
    lines = {}
    local talent = { nodeID = 1, conditions = talentConds }
    local tree = { configID = 7, nodesByID = {} }
    AddNeeds(talent, tree, { name = "Fury", spent = spent })
    return lines
end

conds[1] = { isGate = false, isMet = false, spentAmountRequired = 3, type = 0 }
local out = Run({ 1 }, 22)
Check(#out == 1 and out[1].text == "Requires 25 points in Fury Talents", "a non-gate tree need shows Era's total (" ..
    tostring(out[1] and out[1].text) .. ")")
Check(out[1] and out[1].r == 1 and out[1].g < 0.2, "the line is red")

conds[2] = { isGate = false, isMet = true, spentAmountRequired = 0, type = 0 }
Check(#Run({ 2 }, 30) == 0, "a met need shows nothing")

conds[3] = { isGate = true, isMet = false, spentAmountRequired = 8, type = 0 }
out = Run({ 1, 3 }, 2)
Check(#out == 1 and out[1].text == "Requires 10 points in Fury Talents", "two needs show the largest once")

Check(#Run({}, 0) == 0, "no conditions, no line")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("talent_needs_test: ok")
