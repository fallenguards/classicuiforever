local _, ns = ...

-- The Collections window's Pets page: retail's pet journal through its own filters (owned pets and the species still to
-- find), Forever's owned pets (it lists no others); the picked one's creature in the model box, Summon or Dismiss.

local CW = ns.collections
local PJ = C_PetJournal
local IsSecret = ns.IsSecret

local PETS_ICON = "Interface\\Icons\\INV_Box_PetCarrier_01"
local OWNED_ONLY = ns.OnForever()
local searched = false

local function OwnedList()
    local out = {}
    for _, petID in ipairs(PJ.GetOwnedPetIDs and PJ.GetOwnedPetIDs() or ns.EMPTY) do
        local info = PJ.GetPetInfoTableByPetID(petID)
        local name = info and (info.customName or info.name)
        if type(name) == "string" and not IsSecret(name) then
            out[#out + 1] = { id = petID, petID = petID, speciesID = info.speciesID, name = name, icon = info.icon,
                collected = true, displayID = info.displayID, source = info.sourceText }
        end
    end
    table.sort(out, CW.ByCollectedName)
    return out
end

-- The journal's own list: an owned pet by its ID, a species not yet found by its species.
local function GameList()
    if not searched and PJ.ClearSearchFilter then
        searched = true
        PJ.ClearSearchFilter()
    end
    local out = {}
    for i = 1, PJ.GetNumPets() or 0 do
        local petID, speciesID, owned, customName, _, _, revoked, speciesName, icon, _, _, source = PJ.GetPetInfoByIndex(i)
        local name = customName or speciesName
        if type(name) == "string" and not IsSecret(name) and not revoked then
            out[#out + 1] = { id = petID or ("species" .. tostring(speciesID)), petID = petID, speciesID = speciesID,
                name = name, icon = icon, collected = owned == true, source = source }
        end
    end
    table.sort(out, CW.ByCollectedName)
    return out
end

local function DisplayID(entry)
    if entry.displayID then return entry.displayID end
    local info = entry.petID and PJ.GetPetInfoTableByPetID(entry.petID)
    if info then return info.displayID end
    if entry.speciesID then return (select(12, PJ.GetPetInfoBySpeciesID(entry.speciesID))) end
end

local function Show(entry, box)
    if type(entry.source) == "string" and not IsSecret(entry.source) then box.source:SetText(entry.source) end
    CW.ShowCreature(box, DisplayID(entry))
end

local function Summoned(entry)
    return entry.petID ~= nil and PJ.GetSummonedPetGUID and PJ.GetSummonedPetGUID() == entry.petID
end

local function Action(entry)
    if Summoned(entry) then return CW.Text("PET_DISMISS", "COLL_DISMISS"), true end
    return CW.Text("SUMMON", "COLL_SUMMON"), entry.petID ~= nil and PJ.PetIsSummonable(entry.petID) == true
end

-- A second summon of the out pet sends it home.
local function Act(entry)
    if entry.petID then PJ.SummonPetByGUID(entry.petID) end
end

local function Pickup(entry)
    if entry.petID then PJ.PickupPet(entry.petID) end
end

local function Tip(entry)
    if entry.petID and GameTooltip.SetCompanionPet then GameTooltip:SetCompanionPet(entry.petID) else GameTooltip:SetText(entry.name) end
end

local function FilterRow(label, filter, after)
    if not filter then return nil end
    return CW.FilterCheck(label, function() return PJ.IsFilterChecked(filter) end,
        function(on) PJ.SetFilterChecked(filter, on) end, after)
end

local function FilterEntries(after)
    return CW.Rows(
        FilterRow(CW.Text("COLLECTED", "COLL_COLLECTED"), _G.LE_PET_JOURNAL_FILTER_COLLECTED, after),
        FilterRow(CW.Text("NOT_COLLECTED", "COLL_NOT_COLLECTED"), _G.LE_PET_JOURNAL_FILTER_NOT_COLLECTED, after),
        { divider = true },
        FilterRow(CW.GameName("PET_FILTER_BATTLE_PETS"), _G.LE_PET_JOURNAL_FILTER_TYPE_BATTLE_PETS, after),
        FilterRow(CW.GameName("PET_FILTER_NON_COMBAT_PETS"), _G.LE_PET_JOURNAL_FILTER_TYPE_NON_COMBAT_PETS, after),
        CW.FilterSub(CW.GameName("PET_FAMILIES"), PJ.SetAllPetTypesChecked, PJ.GetNumPetTypes(),
            function(i) return CW.GameName("BATTLE_PET_NAME_" .. i) end, PJ.IsPetTypeChecked, PJ.SetPetTypeFilter, after),
        CW.FilterSub(CW.Text("SOURCES", "COLL_SOURCES"), PJ.SetAllPetSourcesChecked, PJ.GetNumPetSources(),
            function(i) return CW.GameName("BATTLE_PET_SOURCE_" .. i) end, PJ.IsPetSourceChecked, PJ.SetPetSourceChecked, after))
end

CW.AddPage({
    key = "pets", tab = 2, icon = PETS_ICON, tip = { "PETS", "COLL_PETS" }, ownedOnly = OWNED_ONLY,
    events = { "COMPANION_UPDATE", "PET_JOURNAL_LIST_UPDATE", "NEW_PET_ADDED", "PET_JOURNAL_PET_DELETED" },
    List = OWNED_ONLY and OwnedList or GameList, Show = Show, Action = Action, Act = Act, Pickup = Pickup, Tip = Tip,
    Shown = not OWNED_ONLY and CW.AllShown or nil, FilterEntries = not OWNED_ONLY and FilterEntries or nil,
})
