local _, ns = ...

-- The Collections window's Toys page: the toys you own, from the game's toy list rebuilt as its toy box does on opening;
-- the picked toy's icon in the box and Use at its foot, used through the action button's secure pad.

local CW = ns.collections
local TB = C_ToyBox
local IsSecret = ns.IsSecret

local TOYS_ICON = "Interface\\Icons\\Trade_Archaeology_ChestofTinyGlassAnimals"

local function List()
    local out = {}
    TB.ForceToyRefilter()
    for i = 1, TB.GetNumFilteredToys() or 0 do
        local itemID = TB.GetToyFromIndex(i)
        if type(itemID) == "number" and itemID > 0 then
            local _, name, icon = TB.GetToyInfo(itemID)
            if type(name) == "string" and not IsSecret(name) and PlayerHasToy(itemID) then
                out[#out + 1] = { id = itemID, name = name, icon = icon, collected = true }
            end
        end
    end
    table.sort(out, CW.ByCollectedName)
    return out
end

local function Show(entry, box)
    box.bigIcon:SetTexture(entry.icon)
    box.bigIcon:SetDesaturated(not entry.collected)
    box.bigIcon:Show()
end

local function Action(entry)
    return CW.Text("USE", "COLL_USE"), entry.collected and (not TB.IsToyUsable or TB.IsToyUsable(entry.id) ~= false)
end

-- What the action button's pad runs: the game uses a known toy by its name.
local function Macro(entry)
    if entry.collected then return "/use " .. entry.name end
end

local function Pickup(entry)
    TB.PickupToyBoxItem(entry.id)
end

local function Tip(entry)
    if GameTooltip.SetToyByItemID then GameTooltip:SetToyByItemID(entry.id) else GameTooltip:SetText(entry.name) end
end

CW.AddPage({
    key = "toys", tab = 3, icon = TOYS_ICON, tip = { "TOY_BOX", "COLL_TOYS" }, ownedOnly = true,
    events = { "TOYS_UPDATED", "NEW_TOY_ADDED" },
    List = List, Show = Show, Action = Action, Macro = Macro, Pickup = Pickup, Tip = Tip,
})
