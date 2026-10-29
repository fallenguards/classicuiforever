-- Offline test under Lua 5.4 for the unit frames' Bar texture (UI/Colors.lua): a bar made takes the pick, a pick
-- refills every bar made and the game's heal fills on them, a profile's pick does through its toggle, and an unknown
-- value falls back to the smooth 1.x fill.
-- Run from the addon root: lua tools/tests/unit_bar_texture_test.lua (CI runs every tools/tests/*_test.lua).
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

local handle = assert(io.open(ROOT .. "/UI/Colors.lua", "r"))
local source = handle:read("a")
handle:close()
local first = assert(source:find("-- Unit frame bars' fill", 1, true), "the Bar texture code is in UI/Colors.lua")
local last = assert(source:find("-- 12.x unit values are secret", first, true))

local watchers = {}
local ns = {
    db = { unitBarTexture = "classic" },
    TexPath = function(key) return "path:" .. key end,
    SetBarFill = function(bar, key) bar.fill = "path:" .. key end,
    OnToggle = function(fn) watchers[#watchers + 1] = fn end,
}
function ns.OwnFrame()
    local bar = { coords = nil }
    local tex = { SetTexCoord = function(_, ...) bar.coords = { ... } end }
    function bar.SetSize() end
    function bar.Show() end
    function bar.GetStatusBarTexture() return tex end
    return bar
end
local L = setmetatable({}, { __index = function(_, k) return k end })
local env = setmetatable({ ns = ns, L = L }, { __index = _G })
assert(load(source:sub(first, last - 1), "bar texture", "t", env))()

local health = ns.CreateBar({}, "health", 10, 10)
Check(health.fill == "path:barClassicHD", "a bar made takes the smooth 1.x fill by default")
Check(health.coords and health.coords[2] == 1, "its whole texture shows")
local heal = { SetTexture = function(self, path) self.path = path end }
ns.FillUnitTexture(heal)

ns.SetUnitBarTexture("unitBarTexture", "solid")
Check(ns.db.unitBarTexture == "solid", "the pick is saved")
Check(health.fill == "path:barSolid", "a pick refills a bar made before")
Check(heal.path == "path:barSolid", "and the game's heal fill on it")
Check(ns.CreateBar({}, "power", 10, 10).fill == "path:barSolid", "a bar made after takes the pick")

ns.db.unitBarTexture = "raid"
for _, fn in ipairs(watchers) do fn("unitBarTexture") end
Check(health.fill == "path:barRaid", "a profile's pick refills through its toggle")

ns.db.unitBarTexture = "gone"
for _, fn in ipairs(watchers) do fn("unitBarTexture") end
Check(health.fill == "path:barClassicHD", "an unknown pick falls back to the smooth 1.x fill")

for _, pick in ipairs(ns.UNIT_BAR_TEXTURES) do
    Check(pick.tex and pick.label, "every pick has a texture and a label: " .. tostring(pick.key))
end

if failed > 0 then os.exit(1) end
print("unit bar texture: ok")
