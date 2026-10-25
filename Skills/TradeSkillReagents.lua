local _, ns = ...

-- The old trade skill window's reagent sums (Skills/TradeSkill.lua): a slot's needs and what is in reach, the list a
-- craft hands the game, and on retail the expansion whose recipes show.

local R = {}
ns.tradeReagents = R

local RETAIL = not ns.OnForever()
local EMPTY = ns.EMPTY
local BASIC = Enum.CraftingReagentType and Enum.CraftingReagentType.Basic
local TIERED = Enum.TradeskillSlotDataType and Enum.TradeskillSlotDataType.ModifiedReagent

-- Forever: bags only (the bank offered crafts crafting cannot reach). Retail crafts from the banks too, as its page counts.
local function Count(itemID)
    if RETAIL then return C_Item.GetItemCount(itemID, true, false, true, true) or 0 end
    return C_Item.GetItemCount(itemID, false, false, false) or 0
end

function R.IsBasic(slot)
    return BASIC == nil or slot.reagentType == BASIC
end

-- Every tier of a slot's reagent counts as one.
function R.Have(slot)
    local total = 0
    for _, reagent in ipairs(slot.reagents or EMPTY) do
        if reagent.itemID then total = total + Count(reagent.itemID) end
    end
    return total
end

-- Basic slots as { itemID shown, quantity (may be 0), slot }; nil if the schematic is unreadable.
function R.Read(recipeID)
    local ok, schematic = pcall(C_TradeSkillUI.GetRecipeSchematic, recipeID, false)
    if not ok or not schematic or not schematic.reagentSlotSchematics then return nil end
    local list = {}
    for _, slot in ipairs(schematic.reagentSlotSchematics) do
        local first = slot.reagents and slot.reagents[1]
        if R.IsBasic(slot) and first and first.itemID then
            list[#list + 1] = { first.itemID, slot.quantityRequired or 0, slot }
        end
    end
    return list
end

-- One craft's share of a tiered slot from what is in reach: lowest tier first, or best first.
local function Fill(list, slot, best)
    local reagents = slot.reagents
    local left = slot.quantityRequired or 0
    local from, to, step = 1, #reagents, 1
    if best then from, to, step = #reagents, 1, -1 end
    for i = from, to, step do
        local reagent = reagents[i]
        local take = math.min(left, reagent.itemID and Count(reagent.itemID) or 0)
        if take > 0 then
            list[#list + 1] = { reagent = reagent, dataSlotIndex = slot.dataSlotIndex, quantity = take }
            left = left - take
        end
        if left <= 0 then return end
    end
end

-- What a craft hands the game beside the recipe: its tiered slots filled, as the game's own page fills them. nil with none.
function R.Infos(needs, best)
    local list
    for _, need in ipairs(needs or EMPTY) do
        local slot = need[3]
        if TIERED and slot.dataSlotType == TIERED then
            list = list or {}
            Fill(list, slot, best)
        end
    end
    return list
end

function R.Tiered(schematic)
    for _, slot in ipairs(schematic and schematic.reagentSlotSchematics or EMPTY) do
        if TIERED and slot.dataSlotType == TIERED and R.IsBasic(slot) then return true end
    end
    return false
end

-- Retail recipes the old window cannot run: they pick an item, or a slot of theirs must take an extra reagent.
function R.GameOnly(info, schematic)
    if not RETAIL then return false end
    if info.isSalvageRecipe or info.isRecraft or info.isEnchantingRecipe or info.isGatheringRecipe or info.isDummyRecipe then
        return true
    end
    for _, slot in ipairs(schematic and schematic.reagentSlotSchematics or EMPTY) do
        if slot.required and not R.IsBasic(slot) then return true end
    end
    return false
end

-- Optional or finishing reagents, or a quality to steer: the game's page has them.
function R.HasExtras(info, schematic)
    if not RETAIL then return false end
    if info.supportsQualities then return true end
    for _, slot in ipairs(schematic and schematic.reagentSlotSchematics or EMPTY) do
        if not R.IsBasic(slot) then return true end
    end
    return false
end

------------------------------------------------------------------ retail: one expansion's recipes

local picked   -- the expansion's skill line; ours alone, the game's own pick is left as it is

-- The profession's expansions, newest first as the game lists them; none on Forever, a linked or an NPC's list.
function R.Lines()
    if not RETAIL or not C_TradeSkillUI.GetChildProfessionInfos then return EMPTY end
    return C_TradeSkillUI.GetChildProfessionInfos() or EMPTY
end

-- The picked expansion's info (name, rank); the game's own pick until ours is one of this profession's.
function R.Line()
    local lines = R.Lines()
    local current = #lines > 0 and C_TradeSkillUI.GetChildProfessionInfo() or nil
    local own
    for _, line in ipairs(lines) do
        if line.professionID == picked then return line end
        if current and line.professionID == current.professionID then own = line end
    end
    return own or lines[1]
end

function R.PickLine(professionID)
    picked = professionID
    if R.Changed then R.Changed() end
end

-- Recipes not learned yet listed too, as the game's Show Unlearned; R.Changed is the window's refresh.
local unlearned = false
function R.Unlearned() return unlearned end
function R.ToggleUnlearned()
    unlearned = not unlearned
    if R.Changed then R.Changed() end
end

------------------------------------------------------------------ Era's subclass filter: what a recipe makes

-- The item type a recipe makes ("Consumable", "Trade Goods"), the names Era's subclass list shows; false: nothing.
local typeOf = {}
function R.TypeOf(recipeID)
    local known = typeOf[recipeID]
    if known ~= nil then return known or nil end
    local api = C_TradeSkillUI
    local schematic = api.GetRecipeSchematic and api.GetRecipeSchematic(recipeID, false)
    local item = schematic and schematic.outputItemID
    local itemType = item and select(2, C_Item.GetItemInfoInstant(item)) or nil
    typeOf[recipeID] = itemType or false
    return itemType
end

-- The types picked to show; none picked lists every recipe. Cleared as a profession opens, as Era's list is.
local shownTypes = {}
R.types = {}   -- the open profession's types, sorted (the window's Collect fills it)
function R.TypeShown(itemType) return next(shownTypes) == nil or (itemType ~= nil and shownTypes[itemType] == true) end
function R.TypePicked(itemType) return shownTypes[itemType] == true end
function R.ToggleType(itemType)
    shownTypes[itemType] = not shownTypes[itemType] or nil
    if R.Changed then R.Changed() end
end
function R.ClearTypes() wipe(shownTypes) end
