-- Offline test under Lua 5.4 for Raid panel on hover (Units/RaidManager.lua HoverTick): the game's group panel at the
-- left edge fades out while the mouse is away and back in over it; a secret mouse answer (a fight) counts as away; turned
-- off, the panel comes back in full and the watch sleeps.
-- Run from the addon root: lua tools/tests/raid_manager_hover_test.lua (CI runs every tools/tests/*_test.lua).
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

local handle = assert(io.open(ROOT .. "/Units/RaidManager.lua", "r"))
local source = handle:read("a")
handle:close()
local from = source:find("local function HoverTick()", 1, true)
local to = from and source:find("\nend\n", from, true)
Check(from and to, "HoverTick is in the file")

local SECRET = {}
local over, faded, slept = false, nil, false
local env = {
    CompactRaidFrameManager = { IsMouseOver = function() return over end },
    ns = { db = { raidManagerHover = true }, FadeTo = function(_, alpha) faded = alpha end },
    IsSecret = function(v) return v == SECRET end,
}
local HoverTick = assert(load("local hoverJob = { Sleep = function() SLEPT() end }\n"
    .. source:sub(from or 1, (to or 0) + 4) .. "\nreturn HoverTick", "hover", "t", setmetatable(env, {
        __index = { SLEPT = function() slept = true end } })))()

HoverTick()
Check(faded == 0 and not slept, "on, the mouse away: faded out")
over = true
HoverTick()
Check(faded == 1, "on, the mouse over it: back in full")
over = SECRET
HoverTick()
Check(faded == 0, "a secret mouse answer (a fight) counts as away, never compared")
env.ns.db.raidManagerHover = false
over = false
HoverTick()
Check(faded == 1 and slept, "turned off: back in full, the watch sleeps")

local toggles = assert(io.open(ROOT .. "/Options/Toggles.lua", "r")):read("a")
Check(toggles:find('{ "raidManagerHover", L["OPT_raidManagerHover"], L["OPT_raidManagerHover_TIP"],', 1, true) ~= nil,
    "the option row is there, with no parent (it works with our unit frames off)")
local defaults = assert(io.open(ROOT .. "/Core/Defaults.lua", "r")):read("a")
Check(defaults:find("raidManagerHover = false,", 1, true) ~= nil, "off by default")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("raid_manager_hover_test: ok")
