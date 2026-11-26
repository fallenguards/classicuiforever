-- Offline test under Lua 5.4 for another addon's switch button on the professions window's title bar
-- (Skills/ProfessionsWindow.lua T.KeepSwitchLeft). It stands its 60 x 15 button 30 in from the window's top right, over
-- our lock and reset (his snip 17:22); his pick: the title bar's left end, past the portrait ring
-- (Skills/ProfessionsBookFrame.lua T.RingRight).
-- Run from the addon root: lua tools/tests/title_switch_spot_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 122 212 431 432

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local failed = 0
local function Check(ok, what)
    print((ok and "PASS " or "FAIL ") .. what)
    if not ok then failed = failed + 1 end
end

local AnyMT = {}
local function Any() return setmetatable({}, AnyMT) end
AnyMT.__index = function(t, k)
    if type(k) ~= "string" then return nil end
    local v = Any()
    rawset(t, k, v)
    return v
end
AnyMT.__call = function() return Any() end
AnyMT.__concat = function() return "" end

local window = { children = {} }
function window:GetChildren() return table.unpack(self.children) end
local function Child(w, h, point, rel, relPoint, x, y)
    local c = { w = w, h = h, p = { point, rel, relPoint, x, y } }
    function c:GetWidth() return self.w end
    function c:GetHeight() return self.h end
    function c:GetPoint() return table.unpack(self.p) end
    window.children[#window.children + 1] = c
    return c
end
local other = Child(32, 32, "TOPRIGHT", window, "TOPRIGHT", -5, -5)   -- the X
local switch = Child(60, 15, "TOPRIGHT", nil, "TOPRIGHT", -30, -4)       -- the switch, anchored to its parent

local ns = Any()
local T = Any()
rawset(ns, "prof", T)
rawset(ns, "EMPTY", {})
rawset(ns, "AnySecret", function() return false end)
rawset(ns, "Near", function(a, b, d) return math.abs((a or 0) - (b or 0)) <= d end)
rawset(ns, "EachChild", function(frame, fn, a) for _, c in ipairs(frame.children) do fn(c, a) end end)
rawset(ns, "SetPointIf", function(f, point, rel, relPoint, x, y) f.p = { point, rel, relPoint, x, y } return true end)
local env = setmetatable({}, { __index = function(_, k)
    local real = _G[k]
    if real ~= nil then return real end
    return Any()
end })
for _, path in ipairs({ "Skills/ProfessionsBookFrame.lua", "Skills/ProfessionsWindow.lua" }) do
    local handle = assert(io.open(ROOT .. "/" .. path, "r"))
    local source = handle:read("a")
    handle:close()
    assert(load(source, "@" .. path, "t", env))("ClassicUIForever", ns)
end

Check(type(T.KeepSwitchLeft) == "function" and type(T.RingRight) == "function", "the switch's spot is kept by the pass")
if type(T.KeepSwitchLeft) == "function" then
    T.KeepSwitchLeft(window, "trade")
    local p = switch.p
    Check(p[1] == "TOPLEFT" and p[2] == window and p[3] == "TOPLEFT", "the switch stands from the window's top left")
    Check(p[4] == T.RingRight("trade") + 6 and p[4] > 0, "past the portrait ring (" .. tostring(p[4]) .. ")")
    Check(p[5] == -4, "at its own height on the title bar")
    Check(other.p[1] == "TOPRIGHT" and other.p[4] == -5, "the window's other children are left alone")
    -- Its addon draws it again on its own spot: put back past the ring.
    switch.p = { "TOPRIGHT", nil, "TOPRIGHT", -30, -4 }
    T.KeepSwitchLeft(window, "tradeDual")
    Check(switch.p[1] == "TOPLEFT" and switch.p[4] == T.RingRight("tradeDual") + 6, "after its addon lays it again, back past the ring")
end

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("title_switch_spot_test: ok")
