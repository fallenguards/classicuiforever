local _, ns = ...

-- The Collections window's Toys page: the game's toy list rebuilt as its toy box does on opening, through its filters on
-- retail (Forever: the toys you own), laid as the spellbook's pages; a click on one you own uses it, through a pad.

local CW = ns.collections
local TB = C_ToyBox
local IsSecret = ns.IsSecret

local TOYS_ICON = "Interface\\Icons\\Trade_Archaeology_ChestofTinyGlassAnimals"
-- Forever's list holds toys it never gives: yours only, no filters.
local OWNED_ONLY = ns.OnForever()
local searched = false

local function List()
    if not searched and TB.SetFilterString then
        searched = true
        TB.SetFilterString("")
    end
    local out = {}
    TB.ForceToyRefilter()
    for i = 1, TB.GetNumFilteredToys() or 0 do
        local itemID = TB.GetToyFromIndex(i)
        if type(itemID) == "number" and itemID > 0 then
            local _, name, icon = TB.GetToyInfo(itemID)
            local owned = PlayerHasToy(itemID) == true
            if type(name) == "string" and not IsSecret(name) and (owned or not OWNED_ONLY) then
                out[#out + 1] = { id = itemID, name = name, icon = icon, collected = owned }
            end
        end
    end
    table.sort(out, CW.ByCollectedName)
    return out
end

-- What the action button's pad runs: the game uses a known toy by its name.
local function Macro(entry)
    if entry.collected then return "/use " .. entry.name end
end

local function Pickup(entry)
    TB.PickupToyBoxItem(entry.id)
end

local function SourceName(i)
    local info = _G.C_ToyBoxInfo
    return info and info.IsToySourceValid(i) and CW.GameName("BATTLE_PET_SOURCE_" .. i) or nil
end

local function FilterEntries(after)
    return CW.Rows(
        CW.FilterCheck(CW.Text("COLLECTED", "COLL_COLLECTED"), TB.GetCollectedShown, TB.SetCollectedShown, after),
        CW.FilterCheck(CW.Text("NOT_COLLECTED", "COLL_NOT_COLLECTED"), TB.GetUncollectedShown, TB.SetUncollectedShown, after),
        CW.FilterCheck(CW.GameName("PET_JOURNAL_FILTER_USABLE_ONLY"), function() return not TB.GetUnusableShown() end,
            function(on) TB.SetUnusableShown(not on) end, after),
        { divider = true },
        CW.FilterSub(CW.Text("SOURCES", "COLL_SOURCES"), TB.SetAllSourceTypeFilters, C_PetJournal.GetNumPetSources(), SourceName,
            TB.IsSourceTypeFilterChecked, TB.SetSourceTypeFilter, after),
        CW.FilterSub(CW.GameName("EXPANSION_FILTER_TEXT"), TB.SetAllExpansionTypeFilters, _G.GetNumExpansions(),
            function(i) return CW.GameName("EXPANSION_NAME" .. (i - 1)) end, TB.IsExpansionTypeFilterChecked,
            TB.SetExpansionTypeFilter, after))
end

local function Tip(entry)
    if GameTooltip.SetToyByItemID then GameTooltip:SetToyByItemID(entry.id) else GameTooltip:SetText(entry.name) end
end

CW.AddPage({
    key = "toys", tab = 3, icon = TOYS_ICON, tip = { "TOY_BOX", "COLL_TOYS" }, ownedOnly = OWNED_ONLY,
    -- A toy not yet in the item cache has no name: listed as the game sends it.
    events = OWNED_ONLY and { "TOYS_UPDATED", "NEW_TOY_ADDED" } or { "TOYS_UPDATED", "NEW_TOY_ADDED", "GET_ITEM_INFO_RECEIVED" },
    book = true, List = List, Macro = Macro, Pickup = Pickup, Tip = Tip,
    Shown = not OWNED_ONLY and CW.AllShown or nil, FilterEntries = not OWNED_ONLY and FilterEntries or nil,
})
