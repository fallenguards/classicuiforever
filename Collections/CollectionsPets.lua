local _, ns = ...

-- The Collections window's Pets page: the pets this account owns (Forever lists no others), the picked one's creature in
-- the model box, Summon or Dismiss at its foot.

local CW = ns.collections
local PJ = C_PetJournal
local IsSecret = ns.IsSecret

local PETS_ICON = "Interface\\Icons\\INV_Box_PetCarrier_01"

local function List()
    local out = {}
    for _, petID in ipairs(PJ.GetOwnedPetIDs and PJ.GetOwnedPetIDs() or ns.EMPTY) do
        local info = PJ.GetPetInfoTableByPetID(petID)
        local name = info and (info.customName or info.name)
        if type(name) == "string" and not IsSecret(name) then
            out[#out + 1] = { id = petID, name = name, icon = info.icon, collected = true, displayID = info.displayID,
                source = info.sourceText }
        end
    end
    table.sort(out, CW.ByCollectedName)
    return out
end

local function Show(entry, box)
    if type(entry.source) == "string" and not IsSecret(entry.source) then box.source:SetText(entry.source) end
    CW.ShowCreature(box, entry.displayID)
end

local function Summoned(entry)
    return PJ.GetSummonedPetGUID and PJ.GetSummonedPetGUID() == entry.id
end

local function Action(entry)
    if Summoned(entry) then return CW.Text("PET_DISMISS", "COLL_DISMISS"), true end
    return CW.Text("SUMMON", "COLL_SUMMON"), PJ.PetIsSummonable(entry.id) == true
end

-- A second summon of the out pet sends it home.
local function Act(entry)
    PJ.SummonPetByGUID(entry.id)
end

local function Pickup(entry)
    PJ.PickupPet(entry.id)
end

local function Tip(entry)
    if GameTooltip.SetCompanionPet then GameTooltip:SetCompanionPet(entry.id) else GameTooltip:SetText(entry.name) end
end

CW.AddPage({
    key = "pets", tab = 2, icon = PETS_ICON, tip = { "PETS", "COLL_PETS" }, ownedOnly = true,
    events = { "COMPANION_UPDATE", "PET_JOURNAL_LIST_UPDATE", "NEW_PET_ADDED", "PET_JOURNAL_PET_DELETED" },
    List = List, Show = Show, Action = Action, Act = Act, Pickup = Pickup, Tip = Tip,
})
