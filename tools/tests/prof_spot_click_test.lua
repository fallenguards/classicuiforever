-- Offline test under Lua 5.4 for the professions window's spot when our openers show it (Skills/ProfessionsWindow.lua
-- ns.ProfessionsSizeWrap). The book and the spellbook are one window in our addon: the professions window follows the
-- spellbook's place (UI/WindowList.lua follows = "spellBook", 12 right and 14 down). In a fight the window is protected,
-- so our place waited till the fight's end and the game's panel manager stood it in its own slot: the window jumped
-- from the spellbook's spot on every tab press (his report 2026-11-24). The opener's secure click stands it there itself.
-- Run from the addon root: lua tools/tests/prof_spot_click_test.lua (CI runs every tools/tests/*_test.lua).
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

-- The game's professions window, shown by its panel manager in its own left slot (UIParent units, scale 1).
local window = { scale = 1, l = 16, b = 300, w = 339, h = 425, point = nil }
function window:GetScale() return self.scale end
function window:SetScale(s) self.scale = s end
function window:GetRect() return self.l, self.b, self.w, self.h end
function window:IsShown() return true end
function window:ClearAllPoints() self.point = nil end
function window:SetPoint(point, rel, relPoint, x, y) self.point = { point, rel, relPoint, x, y } end
function window:GetWidth() return self.w end
function window:GetHeight() return self.h end
setmetatable(window, { __index = function() return function() return Any() end end })

-- The secure handler our openers are wrapped with: its attributes and frame refs, its click body kept.
local wrap = { attrs = {}, refs = {} }
function wrap:SetAttribute(k, v) self.attrs[k] = v end
function wrap:GetAttribute(k) return self.attrs[k] end
function wrap:SetFrameRef(k, f) self.refs[k] = f end
function wrap:GetFrameRef(k) return self.refs[k] end
local postBody

local ns = Any()
local T = Any()
rawset(ns, "prof", T)
rawset(ns, "EMPTY", {})
rawset(ns, "MoverHolds", function() return false end)
rawset(ns, "WindowScale", function() return nil end)
rawset(ns, "ProfessionsZoom", function() return 1 end)
-- The spellbook placed at (0, 757): the professions window follows 12 right and 14 down.
rawset(ns, "WindowPlaced", function(key) if key == "professions" then return true, 12, 743 end return false end)

local env = setmetatable({
    ProfessionsFrame = window,
    InCombatLockdown = function() return false end,
    CreateFrame = function() return wrap end,
    SecureHandlerWrapScript = function(_, _, _, _, post) postBody = post end,
}, { __index = function(_, k)
    local real = _G[k]
    if real ~= nil then return real end
    return Any()
end })
local handle = assert(io.open(ROOT .. "/Skills/ProfessionsWindow.lua", "r"))
local source = handle:read("a")
handle:close()
assert(load(source, "@Skills/ProfessionsWindow.lua", "t", env))("ClassicUIForever", ns)

-- The spellbook's Professions tab wrapped, out of a fight (its attributes written then).
local tab = Any()
ns.ProfessionsSizeWrap(tab)
Check(postBody ~= nil, "the opener's click carries a secure body")

-- In a fight: the game shows the window in its own slot, then the click's body runs.
if postBody then
    local body = assert(load(postBody, "=click", "t", setmetatable({ control = wrap }, { __index = _G })))
    body()
end
local p = rawget(window, "point")
Check(p ~= nil and p[1] == "TOPLEFT" and p[3] == "BOTTOMLEFT", "the click stands the window by its top left")
Check(p ~= nil and p[4] == 12 and p[5] == 743,
    "on the spellbook's spot, as one window (" .. tostring(p and p[4]) .. ", " .. tostring(p and p[5]) .. ")")

-- At a size of the player's: the spot in the window's own units.
window.point, window.scale = nil, 1
wrap.attrs.scale = 0.8
if postBody then
    local body = assert(load(postBody, "=click", "t", setmetatable({ control = wrap }, { __index = _G })))
    body()
end
p = rawget(window, "point")
Check(p ~= nil and math.abs(p[4] - 12 / 0.8) < 0.001 and math.abs(p[5] - 743 / 0.8) < 0.001,
    "at the player's size the spot keeps its place on screen")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("prof_spot_click_test: ok")
