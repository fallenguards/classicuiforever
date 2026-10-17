-- Offline test under Lua 5.4 for where our target and focus cast bars hang (Units/CastBars.lua Position): on the aura
-- rows only where the game hung the bar there itself. The rows are a private frame; the game marks the bar before it
-- anchors it there, and an anchor of ours alone was refused at every pass ("Anchoring disallowed", 18x at login).
-- The code is cut out of the file and run.
-- Run from the addon root: lua tools/tests/cast_bar_rows_test.lua (CI runs every tools/tests/*_test.lua).
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

local handle = assert(io.open(ROOT .. "/Units/CastBars.lua", "r"))
local source = handle:read("a")
handle:close()
local first = source:find("local function Position(bar)", 1, true)
local last = source:find("ns.PlaceUnitSpellBar = Position", 1, true)
assert(first and last and last > first, "the cast bar placement is in the file")

local onTop = false
local ns = { UF = { AurasOnTop = function() return onTop end } }
local env = setmetatable({ ns = ns, active = true, InCombatLockdown = function() return false end },
    { __index = _G })
local Position = assert(load(source:sub(first, last - 1) .. "\nreturn Position", "cast bar placement", "t", env))()

local rows = { name = "rows" }
local frame = { name = "frame" }
function frame:GetAuraContainer() return rows end

-- The bar as the game left it: anchored on the rows or on the frame; records our anchor.
local function Bar(on)
    local bar = { point = on }
    function bar:GetParent() return frame end
    function bar:GetPoint() return "TOPLEFT", self.point, "BOTTOMLEFT", 0, 0 end
    function bar:ClearAllPoints() self.ours = nil end
    function bar:SetPoint(_, rel) self.ours = rel end
    return bar
end

local bar = Bar(rows)
Position(bar)
Check(bar.ours == rows, "the game hung it on the rows: ours keeps it under them")

bar = Bar(frame)
frame.buffsOnTop = true
Position(bar)
Check(bar.ours ~= rows, "the game hung it on the frame (its hidden Buffs On Top set): never on the rows from ours alone")
frame.buffsOnTop = nil

onTop = true
bar = Bar(rows)
Position(bar)
Check(bar.ours == frame, "our rows over the frame: the bar goes under the frame")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("cast_bar_rows_test: ok")
