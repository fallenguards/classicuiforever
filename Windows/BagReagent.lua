local _, ns = ...

-- The reagent bag's slots in the combined bag (option): buttons of ours from the game's item button template, so they
-- come with the combined bag however it opens. Made out of combat: one made in a fight has its right-click refused.

local REAGENT = Enum.BagIndex.ReagentBag
local GetNumSlots = C_Container.GetContainerNumSlots
local GetSlotInfo = C_Container.GetContainerItemInfo
local GetQuestInfo = C_Container.GetContainerItemQuestInfo
local GetReagentQuality = C_TradeSkillUI and C_TradeSkillUI.GetItemReagentQualityInfo
local EVENTS = { "BAG_UPDATE", "BAG_UPDATE_DELAYED", "BAG_CONTAINER_UPDATE", "ITEM_LOCK_CHANGED", "BAG_UPDATE_COOLDOWN",
    "INVENTORY_SEARCH_UPDATE", "BAG_NEW_ITEMS_UPDATED" }

local R = { slots = {}, list = {}, shown = 0 }

-- The reagent bag's size; made ahead even with the option off, so turning it on in a fight answers at once.
local function BagSize()
    if not (REAGENT and ContainerFrameCombinedBags) then return 0 end
    return GetNumSlots(REAGENT) or 0
end

local function Wanted()
    return ns.db and ns.db.reagentBagCombined and BagSize() or 0
end

-- Retail's reagent rank pip, drawn by us: the template's own registers in the game's callback list as ours.
local function Pip(button, link)
    local info = GetReagentQuality and link and GetReagentQuality(link)
    if not info then
        local pip = button.fcui and button.fcui.pip
        if pip then pip:Hide() end
        return
    end
    local pip = ns.OwnTexture(button, "pip", "OVERLAY", 7)
    ns.SetPointOnce(pip, "TOPLEFT", button, "TOPLEFT", -3, 2)
    pip:SetAtlas(info.iconInventory, true)
    pip:Show()
end

-- One slot as the game's own bag fills it (ContainerFrameMixin:UpdateItems).
local function FillSlot(button, owner)
    local slot = button:GetID()
    local info = GetSlotInfo(REAGENT, slot)
    local quest = GetQuestInfo(REAGENT, slot)
    local texture = info and info.iconFileID
    local quality = info and info.quality
    ClearItemButtonOverlay(button)
    button:SetHasItem(texture)
    button:SetItemButtonTexture(texture)
    SetItemButtonQuality(button, quality, info and info.hyperlink, false, info and info.isBound)
    SetItemButtonCount(button, info and info.stackCount)
    SetItemButtonDesaturated(button, info and info.isLocked)
    button:UpdateExtended()
    button:UpdateQuestItem(quest.isQuestItem, quest.questID, quest.isActive)
    button:UpdateNewItem(quality)
    button:UpdateJunkItem(quality, info and info.hasNoValue)
    button:UpdateItemContextMatching()
    button:UpdateCooldown(texture)
    button:SetReadable(info and info.isReadable)
    button:CheckUpdateTooltip(owner)
    button:SetMatchesSearch(not (info and info.isFiltered))
    Pip(button, info and info.hyperlink)
end

local function Fill()
    local owner = GameTooltip:GetOwner()
    for i = 1, R.shown do FillSlot(R.slots[i], owner) end
end

local function FillSoon()
    ns.Sched.NextFrame("bags.reagentFill", Fill)
end

local function OnEvent(_, event, bag)
    if event == "BAG_CONTAINER_UPDATE" or event == "BAG_UPDATE_DELAYED" then
        -- A reagent bag put on, taken off or swapped: the combined bag's rows change.
        if Wanted() ~= R.shown then ns.ReskinOneBag() end
    elseif event == "BAG_UPDATE" and bag ~= REAGENT then
        return
    end
    FillSoon()
end

-- Events only while the slots show.
local function Listen(on)
    if on then
        ns.RegisterEvents(R.events, EVENTS)
        FillSoon()
    else
        R.events:UnregisterAllEvents()
    end
end

-- The reagent bag's button lights our slots on hover, as the game's bag buttons light theirs (bag row out only).
local function Light(button, on)
    on = on and button:GetIsBarExpanded()
    for i, slot in ipairs(R.slots) do slot.BagIndicator:SetShown(on and i <= R.shown) end
end
local function LightOn(button) Light(button, true) end
local function LightOff(button) Light(button, false) end

-- The bag number the template reads off its parent (never a field on the button: the click would read it as ours).
local function Holder()
    if R.holder then return R.holder end
    local holder = ns.NewFrame("Frame", nil, ContainerFrameCombinedBags)
    holder:SetID(REAGENT)
    holder:SetAllPoints()
    R.events = ns.EventFrame({}, OnEvent)
    holder:SetScript("OnShow", function() Listen(true) end)
    holder:SetScript("OnHide", function() Listen(false) end)
    ns.HookScriptOnce(CharacterReagentBag0Slot, "OnEnter", LightOn, "reagentSlots")
    ns.HookScriptOnce(CharacterReagentBag0Slot, "OnLeave", LightOff, "reagentSlots")
    R.holder = holder
    if holder:IsVisible() then Listen(true) end
    return holder
end

function ns.IsReagentHolder(frame)
    return frame ~= nil and frame == R.holder
end

local function Make(i)
    local button = ns.NewFrame("ItemButton", "ForeverClassicUIReagentSlot" .. i, Holder(), "ContainerFrameItemButtonTemplate")
    button:SetID(i)
    -- Off the game's item context and craft quality lists, which register in the name of whoever shows the button.
    button.GetItemContextMatchResult = nil
    button.noProfessionQualityOverlay = true
    R.slots[i] = button
end

-- Our slots for the combined bag's grid and their count (0 with the option off or no reagent bag). Past those made
-- before a fight, the rest are made once it ends.
function ns.OwnReagentSlots()
    local size = BagSize()
    if size > #R.slots then
        if InCombatLockdown() then
            ns.WhenCalm("bags.reagentSlots", ns.ReskinOneBag)
        else
            for i = #R.slots + 1, size do Make(i) end
        end
    end
    local n = math.min(Wanted(), #R.slots)
    if R.holder then ns.SetShownIf(R.holder, n > 0) end
    wipe(R.list)
    for i, button in ipairs(R.slots) do
        ns.SetShownIf(button, i <= n)
        if i <= n then R.list[i] = button end
    end
    if n ~= R.shown then
        R.shown = n
        FillSoon()
    end
    return R.list, n
end
