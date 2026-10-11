-- Offline test under Lua 5.4 for where a floating client window stands (PastAll in UI/Windows.lua): the loot window on
-- its default spot goes past every open window, as Era's packed panel row put it. A gap left of an open window is not
-- past it: the loot window stood left of a character sheet in the second slot (2026-10-11).
-- Run from the addon root: lua tools/tests/loot_stand_test.lua (CI runs every tools/tests/*_test.lua).
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

local handle = assert(io.open(ROOT .. "/UI/Windows.lua", "r"))
local source = handle:read("a")
handle:close()
local from = source:find("local function PastAll(blocks, width)", 1, true)
local to = from and source:find("\nend\n", from, true)
Check(from and to, "PastAll is in UI/Windows.lua")
local env = setmetatable({ UIParent = { GetWidth = function() return 1536 end }, ipairs = ipairs },
    { __index = _G })
local chunk = from and to and load(source:sub(from, to + 4) .. "\nreturn PastAll", "past all", "t", env)
local PastAll = chunk and chunk() or function() return -1 end

-- Blocks: { left, right, client window? }.
Check(PastAll({}, 250) == 0, "nothing open: the first slot")
Check(PastAll({ { 290, 674, true } }, 250) == 674, "the sheet in the second slot: past it, not in the gap left of it")
Check(PastAll({ { 0, 384 }, { 384, 768, true } }, 250) == 768, "two windows side by side: past both")
Check(PastAll({ { 0, 384, true }, { 0, 1536, true } }, 250) == 384, "a full-screen window is not stood past")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("loot_stand_test: ok")
