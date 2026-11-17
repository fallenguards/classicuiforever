-- Offline test under Lua 5.4: the Skills tab's lower pane (Character/SkillDetail.lua) hangs on the character window and
-- shows only while the tab is seen. Closed on Skills, the tab's shown flag stays on; a full pass then turned the pane
-- on, and C switches tabs before the window shows (no OnHide), so the pane stood on the Character tab (#301).
-- Run from the addon root: lua tools/tests/skill_pane_seen_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local failed = 0
local function Check(ok, what)
    if not ok then
        failed = failed + 1
        print("FAIL " .. what)
    end
end

local file = assert(io.open(ROOT .. "/Character/SkillDetail.lua", "rb"))
local source = file:read("a")
file:close()

local body = source:match("\nlocal function SkinSkillDetail%(%)(.-)\nend\n")
Check(body ~= nil, "SkinSkillDetail found")
if body then
    Check(body:find("local onSkills = skills:IsVisible%(%)") ~= nil, "the pane follows the Skills tab as seen")
    Check(body:find("skills:IsShown%(%)") == nil, "nothing in it reads the Skills tab's shown flag")
end

if failed > 0 then
    print(failed .. " skill pane check(s) failed")
    os.exit(1)
end
print("skill pane: all checks passed")
