-- Offline test under Lua 5.4 for the classic layout's unit frame spots (Options/Layout.lua ERA_FRAME_SPOTS): Era's
-- Classic preset is its Blizzard_EditMode/Classic file's EDIT_MODE_CLASSIC_SYSTEM_MAP (player TOPLEFT -1, 0; target
-- 232, 0; focus 174, -178). The layout once used the mainline file's Classic preset (player 4, -4; target 250, -4),
-- the game's own, and both frames stood lower and right of Era's. Both writers (the layout's data and the reset job's
-- frame spots) read the one table.
-- Run from the addon root: lua tools/tests/era_frame_spots_test.lua (CI runs every tools/tests/*_test.lua).
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

local handle = assert(io.open(ROOT .. "/Options/Layout.lua", "r"))
local source = handle:read("a")
handle:close()

local line = source:match("local ERA_FRAME_SPOTS = (%b{})")
assert(line, "the spots table is in Options/Layout.lua")
local spots = assert(load("return " .. line, "spots", "t", {}))()
local ERA = { PlayerFrame = { -1, 0 }, TargetFrame = { 232, 0 }, FocusFrame = { 174, -178 } }
for name, want in pairs(ERA) do
    local got = spots[name]
    Check(got and got[1] == want[1] and got[2] == want[2], name .. " at Era's Classic preset spot " .. want[1] .. ", " .. want[2])
end

-- Both writers read the table; no spot written by hand.
Check(source:find("Indices.Player] = ERA_FRAME_SPOTS.PlayerFrame", 1, true) ~= nil, "the layout data takes the player's spot")
Check(source:find("Indices.Target] = ERA_FRAME_SPOTS.TargetFrame", 1, true) ~= nil, "the layout data takes the target's spot")
Check(source:find("Indices.Focus] = ERA_FRAME_SPOTS.FocusFrame", 1, true) ~= nil, "the layout data takes the focus's spot")
Check(source:find('"PlayerFrame", "TOPLEFT", unpack(era.PlayerFrame)', 1, true) ~= nil, "the reset job takes the player's spot")
Check(source:find('"TargetFrame", "TOPLEFT", unpack(era.TargetFrame)', 1, true) ~= nil, "the reset job takes the target's spot")
Check(source:find('"FocusFrame", "TOPLEFT", unpack(era.FocusFrame)', 1, true) ~= nil, "the reset job takes the focus's spot")
Check(not source:find("{ 4, -4 }", 1, true) and not source:find("{ 250, -2 }", 1, true), "no mainline preset spots left")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("era_frame_spots_test: all checks passed")
