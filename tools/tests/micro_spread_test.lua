-- Offline test under Lua 5.4 for Spread the rest evenly (Bar/BandMicro.lua SpreadStep, run from the file itself): the
-- shown buttons span the whole kept row, and a lone one stands on the last seat by the latency bar (#213: it kept its
-- own seat, a hidden seat's gap after it).
-- Run from the addon root: lua tools/tests/micro_spread_test.lua (CI runs every tools/tests/*_test.lua).
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

local handle = assert(io.open(ROOT .. "/Bar/BandMicro.lua", "rb"))
local src = handle:read("a"):gsub("\r\n", "\n")
handle:close()
local w, step = src:match("local MICRO_Y, MICRO_W, MICRO_H, MICRO_STEP = %-?%d+, (%-?%d+), %-?%d+, (%-?%d+)")
local need = src:match("\nlocal function MicroNeed%(.-\nend\n")
local spread = src:match("\nlocal function SpreadStep%(.-\nend\n")
Check(w and need and spread, "BandMicro.lua's MICRO_W, MicroNeed and SpreadStep are found")
if not (w and need and spread) then os.exit(1) end
local MICRO_W, MICRO_STEP = tonumber(w), tonumber(step)

local db = {}
local ns = { db = db }
local function IsSeatHidden(button) return button.hidden end
local SpreadStep, MicroNeed = assert(load("local MICRO_W, MICRO_STEP, ns, IsSeatHidden = ...\n" .. need .. spread
    .. "return SpreadStep, MicroNeed"))(MICRO_W, MICRO_STEP, ns, IsSeatHidden)

-- A kept row of count seats, the ones listed shown; the rest hidden in their seats.
local function Row(count, shown)
    local row = {}
    for i = 1, count do row[i] = { hidden = true } end
    for _, i in ipairs(shown) do row[i].hidden = false end
    return row
end
local function Span(count) return count * MICRO_W + (count - 1) * MICRO_STEP end

db.hideMicroButtons, db.hideMicroKeepWidth, db.hideMicroSpread = true, true, true
-- Game Menu alone of 14 (retail's row; Help's seat after it).
local on, _, lead = SpreadStep(Row(14, { 13 }), 1, 1)
Check(on and math.abs(lead + MICRO_W - Span(14)) < 1e-9, "a lone shown button ends where the row ends (lead "
    .. tostring(lead) .. ")")
-- Two shown: the first at the start, the second ending at the row's end.
local gap
on, gap, lead = SpreadStep(Row(14, { 1, 13 }), 2, 1)
Check(on and lead == 0 and math.abs(2 * MICRO_W + gap - Span(14)) < 1e-9, "two shown buttons span the row")
-- All shown: nothing to spread.
on = SpreadStep(Row(5, { 1, 2, 3, 4, 5 }), 5, 1)
Check(on == false, "a full row is not spread")
-- Spread off: a hidden button keeps its gap, the lone one its own seat.
db.hideMicroSpread = false
on, _, lead = SpreadStep(Row(14, { 13 }), 1, 1)
Check(on == false and lead == 0, "with Spread off a lone button keeps its own seat")
-- A width worn (Menu Width 150%): a lone one ends at the wider row's end too.
on, _, lead = SpreadStep(Row(1, { 1 }), 1, 1.5)
Check(on and math.abs(lead + MICRO_W - MicroNeed(1) * 1.5) < 1e-9, "a lone button ends at a worn width's end")

-- The layout leads the row by it, and a hidden seat gets no point: the game's enable and disable put its alpha back
-- (Escape showed the hidden housing button), a frame with no point is not drawn.
Check(src:find("local spread, step, lead = SpreadStep(wanted, seen, worn)", 1, true)
    and src:find("local x, last, lastEnd, seatsChanged = rowIn / scale + lead, nil, 0, rowChanged", 1, true),
    "the row's first shown button takes the lead")
-- Width kept: hidden seats after the last shown button keep their room (the floor was trimmed to Game Menu, 305 of 325).
Check(src:find("FitRegion(last, art, (x - step - lastEnd) * scale)", 1, true), "the floor ends past the last seat, shown or not")
-- A button going off or back onto the row moves its pad (one left behind stayed clickable where the button had been).
Check(src:find("if not offRow[button] then rowChanged = true end", 1, true), "a button leaving the row moves the pads")
Check(src:find("if not hidden then\n            button:SetPoint(", 1, true), "a hidden seat gets no point")
-- A fitted or resized row on the band is centered on the 1.x row, not stood on its floor line.
Check(src:find("rowY = MICRO_Y + MICRO_H * (1 - scale) / 2", 1, true), "the row is centered on the 1.x row")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("micro_spread_test: ok")
