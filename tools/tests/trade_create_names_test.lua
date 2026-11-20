-- Offline test under Lua 5.4: the old trade skill window's Create buttons carry the game's page's names. A craft macro
-- (an enchanter's /run ...CreateButton:Click() then the replace confirm) clicked the game's parked page, whose pick is
-- not ours, and did nothing; ClassicUIForeverTradeSkill.CreateButton is the one to click (GH #325, 2026-11-20).
-- Run from the addon root: lua tools/tests/trade_create_names_test.lua (CI runs every tools/tests/*_test.lua).
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

local extras = assert(io.open(ROOT .. "/Skills/TradeSkillExtras.lua")):read("a")
local foot = extras:match("function ns%.TradeSkillFoot%(panel, craft, step%)\n(.-)\nend\n")
Check(foot ~= nil, "TradeSkillFoot is found")
foot = foot or ""
Check(foot:find("panel%.createAll, panel%.create, panel%.count = createAll, create, count") ~= nil,
    "the foot keeps its Create buttons on the window")
Check(foot:find('create:SetScript%("OnClick", function%(%) craft%(false%) end%)') ~= nil,
    "Create makes the picked recipe")

local trade = assert(io.open(ROOT .. "/Skills/TradeSkill.lua")):read("a")
Check(trade:find('panel = ns%.ShellPage%("ClassicUIForeverTradeSkill", host%)') ~= nil,
    "the window keeps its global name ClassicUIForeverTradeSkill")
local build = trade:match("ns%.TradeSkillFoot%(panel, Craft,.-\n    end%)\n(.-)\n\n") or ""
Check(build:find("panel%.CreateButton, panel%.CreateAllButton = panel%.create, panel%.createAll") ~= nil,
    "Create and Create All carry the game's names right after the foot is built")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("trade_create_names_test: ok")
