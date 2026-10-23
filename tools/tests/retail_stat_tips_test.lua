-- Offline test under Lua 5.4 for the classic stat panes' crit and haste tooltips on each client (Character/StatPanes.lua,
-- #208): they called Forever's CharacterCritChanceFrame_OnEnter and CharacterHasteFrame_OnEnter, which retail has not, so
-- the call failed in the line's pcall and retail showed nothing. Retail's come from its own line functions instead.
-- Run from the addon root: lua tools/tests/retail_stat_tips_test.lua (CI runs every tools/tests/*_test.lua).
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

local handle = assert(io.open(ROOT .. "/Character/StatPanes.lua", "r"))
local source = handle:read("a")
handle:close()
local first = source:find("-- Retail has one crit and one haste", 1, true)
local last = first and source:find("local function School", first, true)
assert(first and last, "the stat tooltips are in Character/StatPanes.lua")

local shown
local function Frame()
    local f = {}
    function f:CreateFontString() return { SetText = function() end } end
    function f:Hide() end
    function f:Show() end
    return f
end

local function Load(forever, globals)
    shown = nil
    local G = {
        PaperDollStatTooltip = function(row) shown = { row.tooltip, row.tooltip2 } end,
        STAT_HIT_CHANCE = "Hit Chance",
    }
    for k, v in pairs(globals) do G[k] = v end
    local env = setmetatable({
        _G = G,
        CreateFrame = Frame,
        ns = { OnForever = function() return forever end },
    }, { __index = _G })
    return assert(load(source:sub(first, last - 1) .. "\nreturn CritTip, HasteTip", "tips", "t", env))()
end

-- Retail: no Forever functions; its line functions set the tooltip fields on the line given.
local CritTip, HasteTip = Load(false, {
    PaperDollFrame_SetCritChance = function(line, unit)
        line.Value:SetText("12%")
        line.tooltip, line.tooltip2 = "Critical Strike 12.00%", "Critical Strike rating 1234 (+5.00%)"
    end,
    PaperDollFrame_SetHaste = function(line, unit)
        line.tooltip, line.tooltip2 = "Haste 8.00%", "Haste rating 900 (+3.00%)"
    end,
})
local row = {}
CritTip(row)
Check(shown and shown[1] == "Critical Strike 12.00%" and shown[2] == "Critical Strike rating 1234 (+5.00%)",
    "retail: crit shows its own tooltip with the rating")
HasteTip(row)
Check(shown and shown[1] == "Haste 8.00%" and shown[2] == "Haste rating 900 (+3.00%)", "retail: haste shows its own tooltip")
HasteTip(row)
Check(row.tooltip == "Haste 8.00%", "the row keeps the last tooltip read")

-- Forever: its own functions, given all three schools.
local got
CritTip, HasteTip = Load(true, {
    CharacterCritChanceFrame_OnEnter = function(self, melee, ranged, spell) got = { "crit", melee, ranged, spell } end,
    CharacterHasteFrame_OnEnter = function(self, melee, ranged, spell) got = { "haste", melee, ranged, spell } end,
})
row = { fcuiMelee = 1, fcuiRanged = 2, fcuiSpell = 3 }
CritTip(row)
Check(got and got[1] == "crit" and got[2] == 1 and got[3] == 2 and got[4] == 3, "Forever: crit is the game's, all three schools")
HasteTip(row)
Check(got and got[1] == "haste" and got[4] == 3, "Forever: haste is the game's, all three schools")
Check(shown == nil, "Forever never reads retail's line functions")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("retail_stat_tips_test: all checks passed")
