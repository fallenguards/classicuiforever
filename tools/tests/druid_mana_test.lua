-- Offline test for the druid form mana bar's numbers (Units/DruidMana.lua) under Lua 5.4: they follow the game's own
-- rule for bar text (TextStatusBar): shown while its Status Text switch is on, in the picked format; with the switch
-- off, on hover only. The bar read the format alone, so its numbers stayed up with status text turned off.
-- Run from the addon root: lua tools/tests/druid_mana_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 212

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

------------------------------------------------------------------ the stub client and addon

local Region = {}
Region.__index = function(_, key) return Region[key] or function() end end
local function New() return setmetatable({ shown = false }, Region) end
function Region:CreateFontString() return New() end
function Region:CreateTexture() return New() end
function Region:CreateMaskTexture() return New() end
function Region:GetStatusBarTexture() return New() end
function Region:GetFrameLevel() return 1 end
function Region:Show() self.shown = true end
function Region:Hide() self.shown = false end
function Region:SetFormattedText(format, ...) self.text = string.format(format, ...) end
function Region:SetText(text) self.text = text end

Enum = { PowerType = { Mana = 0, Rage = 1, Energy = 3, LunarPower = 8 } }
PlayerFrame = New()
function UnitClass() return "Druid", "DRUID" end
function UnitPower() return 400 end
function UnitPowerMax() return 1000 end
local power = 1
function UnitPowerType() return power end
function UnitPowerPercent() return 40 end
function BreakUpLargeNumbers(value) return tostring(value) end
unpack = table.unpack

local cvars = { statusText = "1", statusTextDisplay = "NUMERIC" }
local bar, hover, events
local ns = setmetatable({ db = {}, UF = { active = true, frames = { player = { power = New() } } } },
    { __index = function() return function() end end })
ns.IsSecret = function() return false end
ns.GetCVar = function(name) return cvars[name] end
ns.NewFrame = function(kind)
    local frame = New()
    if kind == "StatusBar" then bar = frame end
    return frame
end
ns.Sched = { OnHover = function(_, fn) hover = fn end }
ns.EventFrame = function(_, fn)
    events = fn
    return New()
end
ns.SetShownIf = function(region, shown) region.shown = shown end

assert(loadfile(ROOT .. "/Units/DruidMana.lua"))("ClassicUIForever", ns)
ns.DruidManaSync()

------------------------------------------------------------------ the checks

local failed = 0
local function Check(ok, what)
    if not ok then
        failed = failed + 1
        print("FAIL " .. what)
    end
end
local function Texts()
    return (bar.center.shown and "center " .. tostring(bar.center.text) or "")
        .. (bar.left.shown and "left " .. tostring(bar.left.text) or "") .. (bar.right.shown and " right " .. tostring(bar.right.text) or "")
end
local function Look(switch, format, over)
    cvars.statusText, cvars.statusTextDisplay = switch, format
    hover(over)
    events()
    return Texts()
end

Check(bar ~= nil and bar.shown, "a druid in a form with mana has the bar")
Check(Look("1", "NUMERIC", false) == "center 400 / 1000", "status text on, numeric: " .. Texts())
Check(Look("1", "PERCENT", false) == "center 40%", "status text on, percent: " .. Texts())
Check(Look("1", "BOTH", false) == "left 40% right 400", "status text on, both: " .. Texts())

-- The switch off: no numbers, whatever the format still says; on hover they show.
for _, format in ipairs({ "NUMERIC", "PERCENT", "BOTH", "NONE" }) do
    Check(Look("0", format, false) == "", "status text off, format " .. format .. ", no hover: nothing (" .. Texts() .. ")")
end
Check(Look("0", "NONE", true) == "left 40% right 400", "status text off, on hover: both numbers, as the hover option gives (" .. Texts() .. ")")
ns.db.hoverBothNumbers = false
Check(Look("0", "NONE", true) == "center 400 / 1000", "status text off, on hover, both numbers off: " .. Texts())
Check(Look("0", "PERCENT", true) == "center 40%", "status text off, on hover, percent picked: " .. Texts())

-- Retail's moonkin on Astral Power: the same bar (the game's own is faded, Units/PlayerFrame.lua) (#212).
power = 8
events()
Check(bar.shown, "moonkin's Astral Power: the bar")
power = 0
events()
Check(not bar.shown, "caster form on mana: no bar")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("druid_mana_test: ok")
