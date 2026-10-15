local _, ns = ...

-- A pet's book entries (commands, stances, spells) drag to the bars in a fight from real copies of their own, up to five
-- each on the bonus pages' action slots (73 to 120, never shown by a class with a pet); the secure drag takes the first
-- copy still there (SpellBook.lua DRAG_BODY). Copies live on the server: only a missing one is placed, out of combat.

local IsSecret = ns.IsSecret
local POOL_FIRST, POOL_LAST, POOL_MAX = 73, 120, 5
local BANK_PET = Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Pet or 1
-- An earlier build dragged through macros; the tag finds any still in the list.
local PET_MACRO_TAG = "#fcuipet"

local pool = {}   -- pet book index -> its copies' slots, in order
local macrosCleared = false

local function ClearOldMacros()
    if macrosCleared then return end
    macrosCleared = true
    local consts = Constants and Constants.MacroConsts
    local base = consts and consts.MAX_ACCOUNT_MACROS or 120
    local _, perChar = GetNumMacros()
    for i = base + (perChar or 0), base + 1, -1 do
        local _, _, body = GetMacroInfo(i)
        if body and body:find(PET_MACRO_TAG, 1, true) then DeleteMacro(i) end
    end
end

local function ActionIcon(slot)
    local get = C_ActionBar and C_ActionBar.GetActionTexture or GetActionTexture
    return get and get(slot)
end

-- The pet book's entries worth a copy: commands, stances and spells, never passives. A command's id is its pet action id.
local function Entries()
    local out, icons = {}, {}
    local ok, count = pcall(C_SpellBook.HasPetSpells)
    if not ok or not count or IsSecret(count) then return out, icons end
    for i = 1, count do
        local info = C_SpellBook.GetSpellBookItemInfo(i, BANK_PET)
        local id = info and not info.isPassive and (info.spellID or info.actionID)
        if id and not IsSecret(id) then
            local icon = C_SpellBook.GetSpellBookItemTexture(i, BANK_PET) or info.iconID
            out[#out + 1] = { index = i, spellID = info.spellID, actionID = info.actionID, icon = icon }
            if icon then icons[icon] = true end
        end
    end
    return out, icons
end

-- A slot ours to use: empty, or holding a pet action (nothing else lands on the bonus pages of a class without forms).
local function Free(slot, icons)
    if not HasAction(slot) then return true end
    local kind, _, sub = GetActionInfo(slot)
    return sub == "pet" or kind == "petaction" or icons[ActionIcon(slot) or 0] == true
end

-- The slot holds this entry's copy: by id (a spell's, a command's pet action id), else by icon. A copy missed here is
-- placed again on every pass, which showed as icons cycling under the cursor after each load.
local function Holds(slot, e)
    if not HasAction(slot) then return false end
    local _, id = GetActionInfo(slot)
    if id ~= nil and not IsSecret(id) and (id == e.spellID or id == e.actionID) then return true end
    return ActionIcon(slot) == e.icon
end

-- The free slots shared out in book order, POOL_MAX each at most; the same pet gets the same plan every time.
local function Plan(entries, icons)
    local free, want = {}, {}
    for slot = POOL_FIRST, POOL_LAST do
        if Free(slot, icons) then free[#free + 1] = slot end
    end
    local copies = math.min(POOL_MAX, math.floor(#free / #entries))
    local n = 0
    wipe(pool)
    for _, e in ipairs(entries) do
        local list = {}
        for i = 1, copies do
            list[i] = free[n + i]
            want[free[n + i]] = e
        end
        n = n + copies
        pool[e.index] = list
    end
    return free, want
end

-- Out of combat with nothing on the cursor: the plan laid, missing copies placed, stale pet actions cleared. Returns
-- how many copies were placed, nil when nothing could be done (a fight, forms, no pet out, the cursor busy).
function ns.SyncPetPool()
    if InCombatLockdown() or GetNumShapeshiftForms() > 0 then return nil end
    ClearOldMacros()
    local entries, icons = Entries()
    -- No pet out: the copies stay for the next one.
    if #entries == 0 then return nil end
    local free, want = Plan(entries, icons)
    if GetCursorInfo() then return nil end
    local placed = 0
    for _, slot in ipairs(free) do
        local e = want[slot]
        if not e then
            if HasAction(slot) then
                PickupAction(slot)
                ClearCursor()
            end
        elseif not Holds(slot, e) then
            C_SpellBook.PickupSpellBookItem(e.index, BANK_PET)
            PlaceAction(slot)
            ClearCursor()
            placed = placed + 1
        end
    end
    return placed
end

-- The copies' slots of a pet book entry, for its button's pool attributes; nil without a plan.
function ns.PetPoolSlots(index) return pool[index] end
