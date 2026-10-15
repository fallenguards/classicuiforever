-- Offline test under Lua 5.4 for the moused-over plate's glow (Units/NamePlates.lua LookGlows, OverGlow, OverLeft): the
-- client fires UPDATE_MOUSEOVER_UNIT when the mouse finds a unit, never when it leaves one, so the glow stayed lit until
-- another unit was hovered. While a plate glows for the mouse a watch looks again and sleeps once it is gone.
-- Run from the addon root: lua tools/tests/plate_hover_test.lua (CI runs every tools/tests/*_test.lua).
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
local function Cut(source, from, to)
    local first = source:find(from, 1, true)
    local last = first and source:find(to, first, true)
    assert(first and last, "the code to test is in Units/NamePlates.lua")
    return source:sub(first, last - 1)
end

local handle = assert(io.open(ROOT .. "/Units/NamePlates.lua", "r"))
local source = handle:read("a")
handle:close()

-- A plate whose glow texture remembers whether it shows.
local function Plate()
    local glow = { shown = false }
    function glow:SetShown(on) self.shown = on end
    return { glow = glow }
end
local plate = Plate()
local units = {}
local job = { awake = false }
function job:Wake() self.awake = true end
function job:Sleep() self.awake = false end

local env = setmetatable({
    job = job,
    ns = { Path = function(frame) return frame and frame.glow end },
    PlateFor = function(token) return units[token] end,
    EachPlate = function(fn) fn(plate) end,
}, { __index = _G })
local body = "local overJob = job\n"
    .. Cut(source, "local glowTarget, glowOver", "local function Glow(")
    .. Cut(source, "local function OverGlow()", "-- Sole writer of NP.active.")
    .. "\nreturn OverGlow, OverLeft"
local OverGlow, OverLeft = assert(load(body, "hover", "t", env))()

-- The mouse finds a player: its plate glows and the watch wakes.
units.mouseover = plate
OverGlow()
Check(plate.glow.shown, "the moused-over plate glows")
Check(job.awake, "the watch wakes while a plate glows for the mouse")

-- The mouse leaves: no event; the watch's next look takes the glow off and it sleeps.
units.mouseover = nil
OverLeft()
Check(not plate.glow.shown, "the glow goes when the mouse leaves the unit")
Check(not job.awake, "the watch sleeps once nothing glows for the mouse")

-- The target keeps its own glow.
units.target, units.mouseover = plate, plate
OverGlow()
units.mouseover = nil
OverLeft()
Check(plate.glow.shown, "the target's plate keeps its glow after the mouse leaves it")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("plate_hover_test: all checks passed")
