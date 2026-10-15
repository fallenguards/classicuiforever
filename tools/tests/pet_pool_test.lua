-- Offline test under Lua 5.4 for the pet copy pool (Spells/PetPool.lua): a pet's book entries get real copies on the
-- bonus pages' slots, shared out in book order; a pass places only the copies missing. A copy of a command was not
-- recognised by its pet action id before, so every pass placed every copy again: icons cycled under the cursor at
-- each load. Run from the addon root: lua tools/tests/pet_pool_test.lua (CI runs every tools/tests/*_test.lua).
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

-- The pet book: Attack and Follow are commands (a pet action id, no spell), Growl a spell, one passive.
local BOOK = {
    { name = "Attack", actionID = 117440514, icon = 1001 },
    { name = "Follow", actionID = 117440513, icon = 1002 },
    { name = "Growl", spellID = 2649, actionID = 2649, icon = 1003 },
    { name = "Faster Attack", spellID = 100, actionID = 100, icon = 1004, isPassive = true },
}
-- Action slots as the server keeps them: slot -> { kind, id, sub, icon }.
local slots = {}
local cursor
local picked, placed = 0, 0
local combat, forms = false, 0

function InCombatLockdown() return combat end
function GetNumShapeshiftForms() return forms end
function GetNumMacros() return 0, 0 end
function GetMacroInfo() return nil end
function DeleteMacro() end
function HasAction(slot) return slots[slot] ~= nil end
function GetActionInfo(slot)
    local a = slots[slot]
    if a then return a.kind, a.id, a.sub end
end
function GetActionTexture(slot) return slots[slot] and slots[slot].icon end
function GetCursorInfo() return cursor end
function ClearCursor() cursor = nil end
function PickupAction(slot)
    picked = picked + 1
    cursor, slots[slot] = slots[slot], cursor
end
function PlaceAction(slot)
    placed = placed + 1
    slots[slot], cursor = cursor, slots[slot]
end
function wipe(t)
    for k in pairs(t) do t[k] = nil end
    return t
end
Enum = { SpellBookSpellBank = { Pet = 1 } }
C_SpellBook = {
    HasPetSpells = function() return #BOOK end,
    GetSpellBookItemInfo = function(i) return BOOK[i] end,
    GetSpellBookItemTexture = function(i) return BOOK[i].icon end,
    -- A command's copy reads back as a "pet" spell action under its pet action id.
    PickupSpellBookItem = function(i)
        local e = BOOK[i]
        cursor = { kind = "spell", id = e.spellID or e.actionID, sub = "pet", icon = e.icon }
    end,
}

local ns = { IsSecret = function() return false end }
assert(loadfile(ROOT .. "/Spells/PetPool.lua"))("ClassicUIForever", ns)

-- First pass: five copies each of the three entries, in book order from slot 73; the passive gets none.
local n = ns.SyncPetPool()
Check(n == 15 and placed == 15, "the first pass places five copies of each of three entries (" .. tostring(n) .. ")")
local attack, growl = ns.PetPoolSlots(1), ns.PetPoolSlots(3)
Check(attack and attack[1] == 73 and attack[5] == 77, "Attack's copies on slots 73 to 77")
Check(growl and growl[1] == 83 and growl[5] == 87, "Growl's copies on slots 83 to 87")
Check(ns.PetPoolSlots(4) == nil, "no copies for a passive")
Check(slots[73].id == 117440514 and slots[83].id == 2649, "copies hold the entries' ids")

-- A second pass finds every copy in place by its id: nothing placed, nothing picked up (the old cycling).
placed, picked = 0, 0
n = ns.SyncPetPool()
Check(n == 0 and placed == 0 and picked == 0, "a pass with every copy in place places nothing (" .. tostring(n) .. ")")

-- A fight's drags took two of Attack's copies: only those two come back, on the same slots.
slots[73], slots[75] = nil, nil
placed = 0
n = ns.SyncPetPool()
Check(n == 2 and placed == 2 and slots[73] and slots[75], "only the two copies taken are placed again")
Check(ns.PetPoolSlots(1)[1] == 73, "the plan stays the same")

-- A copy the game reads back another way (no id, the icon alone) still counts.
slots[74] = { kind = "petaction", icon = 1001 }
placed = 0
Check(ns.SyncPetPool() == 0 and placed == 0, "a copy known by its icon alone is not placed again")

-- Never in a fight, never with forms, never over something on the cursor.
combat = true
Check(ns.SyncPetPool() == nil, "no pass in a fight")
combat, forms = false, 2
Check(ns.SyncPetPool() == nil, "no pass with forms (their pages hold the bonus bars)")
forms = 0
cursor = { kind = "item" }
Check(ns.SyncPetPool() == nil and cursor ~= nil, "a busy cursor is left alone")
cursor = nil

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("pet_pool_test: all checks passed")
