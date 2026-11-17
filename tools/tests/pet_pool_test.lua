-- Offline test under Lua 5.4 for the pet copy pool (Spells/PetPool.lua): a pet's book entries get two real copies each
-- on the bonus pages' slots; a pass places only the copies missing, and a copy stays where it is. A pet swap used to
-- re-place every copy (each one a stall in the game), so commands shared by pets must never move and another pet's
-- copies must wait for its return. Run from the addon root: lua tools/tests/pet_pool_test.lua (CI runs every test).
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

-- Pet books. Attack's copy reads back under its pet action id, Follow's with id 0 (as the game does); one passive.
local ATTACK = { name = "Attack", actionID = 117440514, icon = 1001 }
local FOLLOW = { name = "Follow", actionID = 117440513, icon = 1002, readsZero = true }
local HOUND = { ATTACK, FOLLOW, { name = "Growl", spellID = 2649, actionID = 2649, icon = 1003 },
    { name = "Faster Attack", spellID = 100, actionID = 100, icon = 1004, isPassive = true } }
local CAT = { ATTACK, FOLLOW, { name = "Bite", spellID = 17253, actionID = 17253, icon = 1005 } }
local BEAR = { ATTACK, FOLLOW, { name = "Claw", spellID = 16827, actionID = 16827, icon = 1006 } }
local GHOST = { ATTACK, FOLLOW, { name = "Fade", spellID = 555, actionID = 555, icon = 1007, vanishes = true } }
local BOOK = HOUND
-- Action slots as the server keeps them: slot -> { kind, id, sub, icon }.
local slots = {}
local cursor
local picked, placed = 0, 0
local combat, forms, clock = false, 0, 0

function InCombatLockdown() return combat end
function GetNumShapeshiftForms() return forms end
function GetTime() clock = clock + 1 return clock end
function GetNumMacros() return 0, 0 end
function GetMacroInfo() return nil end
function DeleteMacro() end
function HasAction(slot) return slots[slot] ~= nil end
function GetActionInfo(slot)
    local a = slots[slot]
    if a then return a.kind, a.id, a.sub end
end
function GetActionTexture(slot) return slots[slot] and slots[slot].icon end
function GetCursorInfo() return cursor and cursor.kind end
function ClearCursor() cursor = nil end
function PickupAction(slot)
    picked = picked + 1
    cursor, slots[slot] = slots[slot], cursor
end
-- A copy the game will not keep is dropped; the slot keeps what it had.
function PlaceAction(slot)
    placed = placed + 1
    if cursor and cursor.vanishes then
        cursor = nil
        return
    end
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
    PickupSpellBookItem = function(i)
        local e = BOOK[i]
        cursor = { kind = "spell", id = e.readsZero and 0 or (e.spellID or e.actionID), sub = "pet", icon = e.icon,
            vanishes = e.vanishes }
    end,
}

local ns = { IsSecret = function() return false end }
assert(loadfile(ROOT .. "/Spells/PetPool.lua"))("ClassicUIForever", ns)

local function Pass()
    placed, picked = 0, 0
    return ns.SyncPetPool()
end

-- First pass: two copies each of the three entries, in book order from slot 73; the passive gets none.
local n = Pass()
Check(n == 6 and placed == 6, "the first pass places two copies of each of three entries (" .. tostring(n) .. ")")
local attack, growl = ns.PetPoolSlots(1), ns.PetPoolSlots(3)
Check(attack and attack[1] == 73 and attack[2] == 74, "Attack's copies on slots 73 and 74")
Check(growl and growl[1] == 77 and growl[2] == 78, "Growl's copies on slots 77 and 78")
Check(ns.PetPoolSlots(4) == nil, "no copies for a passive")

-- A second pass finds every copy in place: nothing placed, nothing picked up.
n = Pass()
Check(n == 0 and placed == 0 and picked == 0, "a pass with every copy in place places nothing (" .. tostring(n) .. ")")

-- A fight's drag took one of Attack's copies: only that one comes back, on the same slot.
slots[73] = nil
n = Pass()
Check(n == 1 and slots[73] and slots[73].icon == 1001, "only the copy taken is placed again, on its slot")

-- A copy the game reads back another way (no id, the icon alone) still counts.
slots[74] = { kind = "petaction", icon = 1001 }
Check(Pass() == 0 and placed == 0, "a copy known by its icon alone is not placed again")

-- A pet swap: the shared commands stay, only the new pet's own spell is placed; the old pet's copies wait.
BOOK = CAT
n = Pass()
Check(n == 2 and placed == 2 and picked == 0, "a swap places only the new pet's own spell (" .. tostring(n) .. ")")
Check(slots[77].id == 2649 and slots[78].id == 2649, "the old pet's copies stay")
Check(slots[79].id == 17253 and slots[80].id == 17253, "the new spell goes on empty slots")
BOOK = HOUND
Check(Pass() == 0 and placed == 0, "swapping back places nothing")

-- A full pool: an extra copy of the pet's own goes first, then the copies of a pet not out this session, never the
-- copies of pets out lately, never a player's own action.
for slot = 81, 120 do slots[slot] = { kind = "spell", id = 999, sub = "pet", icon = 2000 } end
slots[100] = { kind = "spell", id = 117440514, sub = "pet", icon = 1001 }
slots[101] = { kind = "spell", id = 133, icon = 3000 }
BOOK = CAT
Pass()
BOOK = BEAR
n = Pass()
Check(n == 2, "the new pet's spell finds room (" .. tostring(n) .. ")")
Check(slots[100].id == 16827 and slots[81].id == 16827, "the extra copy first, then the oldest pet's")
Check(slots[77].id == 2649 and slots[79].id == 17253, "pets out this session keep their copies")
Check(slots[101].id == 133, "a player's own action is left alone")

-- A copy the game will not keep is tried once, never again (it used to be placed on every pass).
BOOK = GHOST
n = Pass()
Check(n == 2, "the first try places its copies (" .. tostring(n) .. ")")
n = Pass()
Check(n == 0 and placed == 0, "a copy the game did not keep is not tried again (" .. tostring(n) .. ")")

-- Never in a fight, never with forms, never over something on the cursor.
BOOK = HOUND
combat = true
Check(Pass() == nil, "no pass in a fight")
combat, forms = false, 2
Check(Pass() == nil, "no pass with forms (their pages hold the bonus bars)")
forms = 0
cursor = { kind = "item" }
Check(Pass() == nil and cursor ~= nil, "a busy cursor is left alone")
cursor = nil

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("pet_pool_test: all checks passed")
