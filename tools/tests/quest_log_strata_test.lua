-- Offline test under Lua 5.4 for the quest log's strata (Quest/QuestLogWindow.lua Build): it was HIGH, so no game
-- window (MEDIUM; a click raises one only within its strata) could be dragged over it, and its secure pads sat on
-- DIALOG over whatever covered its buttons (his report 2026-11-24). Then 0.65.0's MEDIUM pads sat under the raised
-- log and Share Quest stopped sharing (a player's report, /fcuidev questpads FAIL): each pad must ride over the log
-- (ns.MapPad given the log; tools/tests/pad_rides_window_test.lua checks the riding). The whole file is loaded against
-- a stand-in client and the log is built through ns.ShowQuestLog.
-- Run from the addon root: lua tools/tests/quest_log_strata_test.lua (CI runs every tools/tests/*_test.lua).
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

-- Anything the code asks for that this test does not care about: any field is one more, any call returns one, numbers
-- made from it are 0. Numeric keys stay nil, so a loop over one ends.
local AnyMT = {}
local function Any() return setmetatable({}, AnyMT) end
AnyMT.__index = function(t, k)
    if type(k) ~= "string" then return nil end
    local v = Any()
    rawset(t, k, v)
    return v
end
AnyMT.__call = function() return Any() end
for _, op in ipairs({ "__add", "__sub", "__mul", "__div", "__mod", "__pow", "__unm", "__idiv" }) do
    AnyMT[op] = function() return 0 end
end
AnyMT.__concat = function(a, b)
    return (type(a) == "table" and "" or tostring(a)) .. (type(b) == "table" and "" or tostring(b))
end
AnyMT.__lt = function() return false end
AnyMT.__le = function() return false end
AnyMT.__len = function() return 0 end

-- A frame keeps its strata as the client does: set, else its parent's, else MEDIUM.
local env
local function Frame(name, parent)
    local f = Any()
    rawset(f, "SetFrameStrata", function(self, strata) rawset(self, "strata", strata) end)
    rawset(f, "GetFrameStrata", function(self)
        return rawget(self, "strata") or (parent and parent.GetFrameStrata and parent:GetFrameStrata()) or "MEDIUM"
    end)
    rawset(f, "GetParent", function() return parent end)
    rawset(f, "IsShown", function() return false end)
    if name then rawset(env, name, f) end
    return f
end

local pads = {}
local ns = Any()
rawset(ns, "MapPad", function(button, strata)
    pads[#pads + 1] = strata or "MEDIUM"
    return Any()
end)
local function Shown(v) return type(v) == "table" and "a frame" or tostring(v) end

env = setmetatable({}, { __index = function(_, k)
    local real = _G[k]
    if real ~= nil then return real end
    return Any()
end })
rawset(env, "UIParent", Frame(nil, nil))
rawset(env, "InCombatLockdown", function() return false end)
rawset(env, "CreateFrame", function(_, name, parent) return Frame(name, type(parent) == "table" and parent or nil) end)

local handle = assert(io.open(ROOT .. "/Quest/QuestLogWindow.lua", "r"))
local source = handle:read("a")
handle:close()
assert(load(source, "@Quest/QuestLogWindow.lua", "t", env))("ClassicUIForever", ns)
-- What runs after Build (the first fill) may trip on the stand-ins; the window and its pads are made by then.
pcall(ns.ShowQuestLog)

local log = ns.QL.Frame()
Check(type(log) == "table", "opening the quest log builds it")
local windows = env.UIParent:GetFrameStrata()
if type(log) == "table" then
    Check(log:GetFrameStrata() == windows, "the quest log is on the game windows' strata " .. windows
        .. ", so a window dragged over it goes over it (now " .. tostring(log:GetFrameStrata()) .. ")")
end
Check(#pads >= 4, "the log's pads are made: Show Map, the close X, Exit, Share (" .. #pads .. ")")
for i, strata in ipairs(pads) do
    Check(strata == log, "pad " .. i .. " over a log button rides over the log, so the raised log never covers it (now "
        .. Shown(strata) .. ")")
end

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("quest_log_strata_test: ok")
