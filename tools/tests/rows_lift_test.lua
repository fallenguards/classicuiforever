-- Offline test under Lua 5.4 for the rows over the band at max level (Bar/BandStatus.lua B.RowsLift and BarsTick,
-- Bar/ClassicBar.lua): with no status bar on the band only the thin strip is left, and Era drops bars 2 and 3, the stance
-- and the pet row 5 to it (UIParentManageFramePositions: a shown holder at its spot adds 5). Ours stayed at the XP
-- height, a see-through gap over the strip. Losing the XP bar must re-lay the rows, not only the strip.
-- Run from the addon root: lua tools/tests/rows_lift_test.lua (CI runs every tools/tests/*_test.lua).
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

local function Source(path)
    local handle = assert(io.open(ROOT .. "/" .. path, "r"))
    local text = handle:read("a")
    handle:close()
    return text
end
local status, classic = Source("Bar/BandStatus.lua"), Source("Bar/ClassicBar.lua")

local function Between(text, from, to)
    local a = text:find(from, 1, true)
    local b = a and text:find(to, a, true)
    assert(a and b, "found in Bar/BandStatus.lua: " .. from)
    return text:sub(a, b - 1)
end
local chunk = table.concat({
    Between(status, "local function HasVisibleBar(container)", "\n-- Recheck the XP fill"),
    Between(status, "-- Whether a holder is showing the XP bar.", "\nlocal stacked ="),
    Between(status, "-- The rows over the band: 9 up", "\nlocal function IsHolder"),
    Between(status, "-- What is up, which way round", "\nB.BarsState = BarsState"),
}, "\n")

-- The client's holders: one bar per kind, the holder shown while one is up or in edit mode (UpdateShownState).
local function Bar(xp)
    local bar = { up = false, ExhaustionTick = xp and {} or nil }
    function bar:IsShown() return self.up end
    return bar
end
local function Holder()
    local holder = { shown = false, alpha = 1, moved = false, hidden = false, bars = { xp = Bar(true), rep = Bar(false) } }
    function holder:IsShown() return self.shown end
    function holder:GetAlpha() return self.alpha end
    function holder:SetAlpha(a) self.alpha = a end
    return holder
end
local main, second = Holder(), Holder()
local editMode = false
local function Show(holder, which)
    for key, bar in pairs(holder.bars) do bar.up = key == which end
    holder.shown = which ~= nil or editMode
end

local applies = 0
local B = { active = true, art = {}, barsWatch = { since = 0, asleep = false, wokeAt = 0 } }
function B.SystemMoved(frame) return frame.moved end
function B.WakeBars() end
-- ClassicBar's pass: the rows laid at UPPER_ROW_Y + the lift, recorded for the watch.
local function Layout() B.rowsLaid = B.RowsLift() end
local env = setmetatable({
    B = B,
    ns = { QueueApply = function() applies = applies + 1 Layout() end, IsSecret = function() return false end },
    MainStatusTrackingBarContainer = main,
    SecondaryStatusTrackingBarContainer = second,
    StatusHidden = function(holder) return holder.hidden end,
    StatusPair = function() return { main, second } end,
    ShowHolderBars = function() end,
    LayoutStatusBars = function() end,
    InCombatLockdown = function() return false end,
    EditModeLive = function() return editMode end,
    GetTime = function() return 0 end,
}, { __index = _G })
assert(load(chunk, "rows", "t", env))()

-- A tick after a change, as the watch wakes: the applies it queued.
local function Tick()
    local before = applies
    B.BarsTick()
    return applies - before
end

local UPPER_ROW_Y, STRIP_TOP = 55, 53 - 11 + 7

Show(main, "xp")
Layout()
Tick()
Check(B.rowsLaid == 0, "leveling, XP on the band: the rows at the XP height (" .. tostring(B.rowsLaid) .. ")")

Show(main, nil)
Check(Tick() == 1, "max level, the XP bar gone: the rows are laid again")
Check(B.rowsLaid == -5, "max level: the rows 5 down, as Era's (" .. tostring(B.rowsLaid) .. ")")
local foot = UPPER_ROW_Y + B.rowsLaid
Check(foot - STRIP_TOP == 1, "max level: bar 2's foot 1 over the thin strip, no gap (" .. (foot - STRIP_TOP) .. ")")

Show(main, "rep")
Check(Tick() == 1 and B.rowsLaid == 0, "max level, a faction watched: its bar in the XP spot, the rows back up")

Show(main, "xp")
Show(second, "rep")
Tick()
Check(B.rowsLaid == 9, "a faction bar over XP: 9 up as 1.x (" .. tostring(B.rowsLaid) .. ")")

Show(second, nil)
Tick()
main.hidden = true
Tick()
Check(B.rowsLaid == -5, "Hide This Bar on the XP bar: the strip alone, the rows down (" .. tostring(B.rowsLaid) .. ")")
main.hidden = false
Tick()
Check(B.rowsLaid == 0, "the XP bar shown again: the rows back up (" .. tostring(B.rowsLaid) .. ")")

-- Moved off the band: nothing stands on it, as Era counts a holder only at its default spot.
main.moved = true
Check(B.RowsLift() == -5, "the XP bar moved off the band: the rows down to the strip")
-- Bars stack on a moved holder: the band keeps none.
main.moved, second.moved = false, true
Check(B.RowsLift() == -5, "the XP bar stacked on a moved holder: the rows down to the strip")
second.moved = false

-- Edit mode shows the empty holder in the XP spot (the client's isInEditMode): Era counts it, the rows stay up.
Show(main, nil)
editMode = true
Show(main, nil)
Show(second, nil)
Check(B.RowsLift() == 0, "edit mode at max level: the empty holder in the XP spot, the rows over it")
editMode = false

Check(classic:find("local barLift = RowsLift()\n    B.rowsLaid = barLift\n", 1, true) ~= nil,
    "the band's pass takes the lift from B.RowsLift and records it")
for _, line in ipairs({ "local lowerY = UPPER_ROW_Y + barLift", "upperY = UPPER_ROW_Y + BUTTON_PITCH + barLift",
    "local rowY, free = SMALL_ROW_Y + barLift, true" }) do
    Check(classic:find(line, 1, true) ~= nil, "the lift moves: " .. line)
end
Check(classic:find("local UPPER_ROW_Y = 55 ", 1, true) ~= nil, "bars 2 and 3 at 55 over XP")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("rows_lift_test: ok")
