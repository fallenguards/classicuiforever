-- Offline test under Lua 5.4 for our record of bags dropped on the band (Bar/ClassicBar.lua ReadBagsHeld). A band drop
-- never writes the layout, so the layout keeps the bag bar at the drop spot and the record (bagsHeld) is what seats it.
-- At login every bar reads as default until edit mode sets it up: the record is kept through that. A save without the
-- record (fresh, or cleared) takes a bag bar the layout holds at a band spot as dropped there.
-- Run from the addon root: lua tools/tests/bags_held_test.lua (CI runs every tools/tests/*_test.lua).
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

local handle = assert(io.open(ROOT .. "/Bar/ClassicBar.lua", "r"))
local source = handle:read("a")
handle:close()

------------------------------------------------------------------ one place lets the record go

local first = source:find("local function ReadBagsHeld(moved)", 1, true)
local last = first and source:find("\nend\n", first, true)
Check(first and last, "ReadBagsHeld is in Bar/ClassicBar.lua")
local chunk = first and last and source:sub(first, last + 4) or ""

local writes = 0
for _ in source:gmatch("bagsHeld = false") do writes = writes + 1 end
Check(writes == 2, "the record is let go in ReadBagsHeld and at a drop off the band only (" .. writes .. " writes)")
local read = source:find("ReadBagsHeld(bagsMoved)", 1, true)
local shapeBags = source:find("shape.bags = ((not bagsMoved)", 1, true)
Check(read and shapeBags and read < shapeBags, "the pass reads the record before it decides the bags are on the band")

------------------------------------------------------------------ the function, run

local env = {}
local function Run(case)
    env.db = { bagsHeld = case.held, bagsFirst = false, bagsSnapScale = case.snap or 0 }
    env.ns = {
        db = env.db,
        InDefaultPosition = function(_, requireInitialized)
            if requireInitialized and not case.ready then return nil end
            return not case.moved
        end,
        EditMode = { Live = function() return case.editing == true end },
    }
    env.B = { BagsTurned = function() return case.turned == true end }
    env.BagsBar = { GetScale = function() return case.scale or 1 end }
    env.DropPlace = function(which, frame, current)
        Check(which == "bags" and frame == env.BagsBar, "the drop rule is asked about the bag bar")
        return case.place
    end
    env.InCombatLockdown = function() return case.fight == true end
    local fn = assert(load("local ns, B, BagsBar, DropPlace, InCombatLockdown = ns, B, BagsBar, DropPlace, "
        .. "InCombatLockdown\n" .. chunk .. "\nreturn ReadBagsHeld", "ReadBagsHeld", "t", env))()
    fn(case.moved)
    return env.db
end

-- Login: edit mode has not set the bag bar up, so it reads as default; the record stays.
local db = Run({ held = true, ready = false, moved = false, snap = 0.85, scale = 0.85 })
Check(db.bagsHeld == true, "an unset bag bar at login keeps the record")

-- Set up and at its default spot (Reset To Default Position): the record goes.
db = Run({ held = true, ready = true, moved = false })
Check(db.bagsHeld == false, "a bag bar back at its default lets the record go")

-- Held and away from default: nothing changes.
db = Run({ held = true, ready = true, moved = true, place = nil })
Check(db.bagsHeld == true, "a held bag bar at its drop spot keeps the record")

-- Fresh save, the layout holds the bag bar at a band spot: taken as dropped there, its size as socket size.
db = Run({ held = false, ready = true, moved = true, place = true, scale = 0.85 })
Check(db.bagsHeld == true, "a bag bar the layout holds at a band spot is taken as dropped there")
Check(db.bagsFirst == true, "it takes the order the drop rule gives")
Check(math.abs(db.bagsSnapScale - 0.85) < 0.001, "the size it wears counts as socket size")

db = Run({ held = false, ready = true, moved = true, place = false })
Check(db.bagsHeld == true and db.bagsFirst == false, "the other order is taken too (false is a place, not none)")

-- Away from the band: left where the layout has it.
db = Run({ held = false, ready = true, moved = true, place = nil })
Check(db.bagsHeld == false and db.bagsSnapScale == 0, "a bag bar away from the band stays off it")

-- Edit mode drops, fights and turned rows decide nothing here.
for _, case in ipairs({
    { what = "in edit mode", editing = true },
    { what = "in a fight", fight = true },
    { what = "turned", turned = true },
}) do
    case.held, case.ready, case.moved, case.place = false, true, true, true
    db = Run(case)
    Check(db.bagsHeld == false, "a bag bar at a band spot " .. case.what .. " is not taken")
end

if failed > 0 then
    print(failed .. " bags held check(s) failed")
    os.exit(1)
end
print("bags held: all checks passed")
