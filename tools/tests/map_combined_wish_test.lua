-- Offline test under Lua 5.4 for the combined map's hold on the client's quest pane (Map/WorldMapClassic.lua
-- ShutClientPane). The client shuts its map on the map key only while the pane's shown state agrees with the pane's
-- saved wish (questLogOpen), and it keeps that wish per character: with the pane put away and the wish still at open,
-- the key opened the map and never shut it. So the wish is cleared with the pane, on whichever character that is.
-- Run from the addon root: lua tools/tests/map_combined_wish_test.lua (CI runs every tools/tests/*_test.lua).
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

local handle = assert(io.open(ROOT .. "/Map/WorldMapClassic.lua", "r"))
local source = handle:read("a")
handle:close()
local first = assert(source:find("local function ShutClientPane", 1, true), "ShutClientPane is in the file")
local last = assert(source:find("local function DressEra", first, true))

local combined, fight, wish = true, false, "1"
local closed, hidden = 0, 0
local env = setmetatable({
    ns = { GetCVar = function(name) return name == "questLogOpen" and wish or nil end },
    InCombatLockdown = function() return fight end,
    -- The client's own close: the wish to shut, then the pane hidden.
    QuestMapFrame_Close = function(userAction)
        closed = closed + 1
        if userAction then wish = "0" end
    end,
}, { __index = _G })
local ShutClientPane = assert(load("local function Combined() return COMBINED() end\n" .. source:sub(first, last - 1)
    .. "\nreturn ShutClientPane", "pane", "t", env))()
env.COMBINED = function() return combined end

local shown = true
local map = { QuestLog = { IsShown = function() return shown end, Hide = function() hidden = hidden + 1 end } }

ShutClientPane(map)
Check(closed == 1 and hidden == 0 and wish == "0", "the pane up with its wish at open: shut the client's way, the wish cleared")
ShutClientPane(map)
Check(closed == 1 and hidden == 1, "the pane up with the wish already shut (a tracker's click): hidden, the wish left")

closed, hidden, wish, fight = 0, 0, "1", true
ShutClientPane(map)
Check(closed == 0 and hidden == 0 and wish == "1", "in a fight nothing is shut or written")
fight, shown = false, false
ShutClientPane(map)
Check(closed == 0 and hidden == 0, "the pane already away: nothing to do")
shown, combined = true, false
ShutClientPane(map)
Check(closed == 0 and hidden == 0 and wish == "1", "without the combined layout the client's pane and wish are the client's")

Check(source:find("\n    ShutClientPane(map)\n", 1, true) ~= nil, "the map's pass shuts the pane through it")
Check(not source:find("map.QuestLog:Hide()", 1, true), "the pass never hides the pane with its wish left at open")

if failed > 0 then
    print(string.format("map combined wish: %d failed", failed))
    os.exit(1)
end
print("map combined wish: ok")
