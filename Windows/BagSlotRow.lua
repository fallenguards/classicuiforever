local _, ns = ...
local B = ns.bags

-- The equipped bags in the one bag's last row (option, #185): drag a bag out, or drop or click one in to put it on.
-- Buttons of ours: the game's bag buttons stay on the band.

local BAGS = { Enum.BagIndex.Bag_1, Enum.BagIndex.Bag_2, Enum.BagIndex.Bag_3, Enum.BagIndex.Bag_4 }
local REAGENT = Enum.BagIndex.ReagentBag
local EMPTY_BAG = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag"
local EVENTS = { "BAG_CONTAINER_UPDATE", "PLAYER_EQUIPMENT_CHANGED", "ITEM_LOCK_CHANGED" }
local ToInventory = C_Container.ContainerIDToInventoryID
local S = { buttons = {}, list = {} }

if REAGENT and _G.CharacterReagentBag0Slot then BAGS[#BAGS + 1] = REAGENT end

local function Slot(button) return ToInventory(button:GetID()) end

local function Fill()
    for _, button in ipairs(S.buttons) do
        local slot = Slot(button)
        button.hasItem = true
        _G.SetItemButtonTexture(button, GetInventoryItemTexture("player", slot) or EMPTY_BAG)
        SetItemButtonDesaturated(button, _G.IsInventoryItemLocked(slot))
    end
end

local function Tip(button)
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    if not GameTooltip:SetInventoryItem("player", Slot(button)) then GameTooltip:SetText(_G.EQUIP_CONTAINER or "") end
    GameTooltip:Show()
end

local function PutOn(button) _G.PutItemInBag(Slot(button)) end
local function Click(button)
    if CursorHasItem() then PutOn(button) else _G.PickupBagFromSlot(Slot(button)) end
end

local function Holder()
    if S.holder then return S.holder end
    local holder = ns.NewFrame("Frame", nil, ContainerFrameCombinedBags)
    holder:SetAllPoints()
    B.ownChildren[holder] = true
    local events = ns.EventFrame({}, function() ns.Sched.NextFrame("bags.bagSlotRow", Fill) end)
    holder:SetScript("OnShow", function()
        ns.RegisterEvents(events, EVENTS)
        Fill()
    end)
    holder:SetScript("OnHide", function() events:UnregisterAllEvents() end)
    -- starts shown: made inside an open bag, its first OnShow never comes.
    if holder:IsVisible() then ns.RegisterEvents(events, EVENTS) end
    for i, bag in ipairs(BAGS) do
        -- The bare ItemButton type: no client has an ItemButtonTemplate.
        local button = ns.NewFrame("ItemButton", "ForeverClassicUIOneBagSlot" .. i, holder)
        button:SetID(bag)
        button:SetSize(37, 37)
        button:RegisterForDrag("LeftButton")
        button:SetScript("OnClick", Click)
        button:SetScript("OnDragStart", function(self) _G.PickupBagFromSlot(Slot(self)) end)
        button:SetScript("OnReceiveDrag", PutOn)
        button:SetScript("OnEnter", Tip)
        button:SetScript("OnLeave", GameTooltip_Hide)
        S.buttons[i] = button
    end
    S.holder = holder
    return holder
end

-- The row's buttons for the sections' layout, none with the option off.
function B.BagSlotButtons()
    local on = ns.db and ns.db.oneBagBagSlots == true and ContainerFrameCombinedBags ~= nil
    if not on then
        if S.holder then ns.SetShownIf(S.holder, false) end
        return ns.EMPTY
    end
    ns.SetShownIf(Holder(), true)
    Fill()
    return S.buttons
end
