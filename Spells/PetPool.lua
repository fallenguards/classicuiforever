local _, ns = ...

-- A pet's book entries drag to the bars in a fight from copies on the bonus pages' slots (73 to 120, never shown with
-- a pet); the secure drag takes the first copy still there (SpellBook.lua DRAG_BODY). A placed copy costs the game
-- about 11 ms, so copies stay put: the commands all pets share never move, another pet's spells wait for its return.

local IsSecret = ns.IsSecret
local POOL_FIRST, POOL_LAST, COPIES = 73, 120, 2
local BANK_PET = Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Pet or 1
-- An earlier build dragged through macros; the tag finds any still in the list.
local PET_MACRO_TAG = "#fcuipet"

local pool = {}       -- pet book index -> its copies' slots
local seen = {}       -- copy key -> when its pet was last out; another pet's copies make room, the oldest first
local lastPlaced = {} -- slot -> key placed there by the last pass
local refused = {}    -- key -> true: the game did not keep its copy, never placed again this session
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

-- The pet book's entries worth a copy: commands, stances and spells, never passives. A spell is keyed by its id, a
-- command by its icon (its copy reads back with id 0).
local function Entries()
    local out = {}
    local ok, count = pcall(C_SpellBook.HasPetSpells)
    if not ok or not count or IsSecret(count) then return out end
    for i = 1, count do
        local info = C_SpellBook.GetSpellBookItemInfo(i, BANK_PET)
        local id = info and not info.isPassive and (info.spellID or info.actionID)
        if id and not IsSecret(id) then
            local icon = C_SpellBook.GetSpellBookItemTexture(i, BANK_PET) or info.iconID
            out[#out + 1] = { index = i, spellID = info.spellID, actionID = info.actionID, icon = icon,
                key = info.spellID and ("s" .. info.spellID) or ("i" .. tostring(icon)) }
        end
    end
    return out
end

-- A pool slot's copy as a key, nil when empty, false when it is no pet's (a player's own action stays).
local function SlotKey(slot, icons)
    if not HasAction(slot) then return nil end
    local kind, id, sub = GetActionInfo(slot)
    local icon = ActionIcon(slot)
    if sub ~= "pet" and kind ~= "petaction" and not icons[icon or 0] then return false end
    if id ~= nil and not IsSecret(id) and id ~= 0 then return "s" .. id end
    return "i" .. tostring(icon)
end

-- Out of combat with nothing on the cursor: the pet's copies found, the missing ones placed on empty slots, then on its
-- own spare copies, then on other pets' copies. Returns how many were placed, nil when nothing could be done (a fight,
-- forms, no pet out, the cursor busy).
function ns.SyncPetPool()
    if InCombatLockdown() or GetNumShapeshiftForms() > 0 then return nil end
    ClearOldMacros()
    local entries = Entries()
    -- No pet out: the copies stay for the next one.
    if #entries == 0 then return nil end
    local byKey, icons, now = {}, {}, GetTime()
    for _, e in ipairs(entries) do
        seen[e.key] = now
        byKey[e.key] = e
        if e.actionID then byKey["s" .. e.actionID] = byKey["s" .. e.actionID] or e end
        if e.icon then
            byKey["i" .. e.icon] = byKey["i" .. e.icon] or e
            icons[e.icon] = true
        end
    end
    wipe(pool)
    local room, spare, others, owner = {}, {}, {}, {}
    for slot = POOL_FIRST, POOL_LAST do
        local key = SlotKey(slot, icons)
        local e = key and byKey[key]
        if key == nil then
            room[#room + 1] = slot
        elseif e then
            owner[slot] = e.key
            local list = pool[e.index] or {}
            pool[e.index] = list
            if #list < COPIES then list[#list + 1] = slot else spare[#spare + 1] = slot end
        elseif key then
            others[#others + 1] = { slot = slot, at = seen[key] or 0 }
        end
    end
    for slot, key in pairs(lastPlaced) do
        if owner[slot] ~= key then refused[key] = true end
    end
    wipe(lastPlaced)
    if GetCursorInfo() then return nil end
    table.sort(others, function(a, b)
        if a.at ~= b.at then return a.at < b.at end
        return a.slot < b.slot
    end)
    for _, slot in ipairs(spare) do room[#room + 1] = slot end
    for _, other in ipairs(others) do room[#room + 1] = other.slot end
    local placed, taken = 0, 0
    for _, e in ipairs(entries) do
        local list = pool[e.index] or {}
        pool[e.index] = list
        while #list < COPIES and not refused[e.key] and room[taken + 1] do
            taken = taken + 1
            local slot = room[taken]
            C_SpellBook.PickupSpellBookItem(e.index, BANK_PET)
            PlaceAction(slot)
            ClearCursor()
            list[#list + 1] = slot
            lastPlaced[slot] = e.key
            placed = placed + 1
        end
    end
    return placed
end

-- The copies' slots of a pet book entry, for its button's pool attributes; nil without a plan.
function ns.PetPoolSlots(index) return pool[index] end
