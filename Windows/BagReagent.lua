local _, ns = ...

-- Slots of ours in the combined bag for a bag it leaves out: the reagent bag (option) and the key ring (option, #185).
-- Buttons from the game's item button template, so they come with the combined bag however it opens. Made out of
-- combat: one made in a fight has its right-click refused.

local REAGENT = Enum.BagIndex.ReagentBag
local KEYRING = Enum.BagIndex.Keyring
local GetNumSlots = C_Container.GetContainerNumSlots
local GetSlotInfo = C_Container.GetContainerItemInfo
local GetQuestInfo = C_Container.GetContainerItemQuestInfo
local GetReagentQuality = C_TradeSkillUI and C_TradeSkillUI.GetItemReagentQualityInfo
local EVENTS = { "BAG_UPDATE", "BAG_UPDATE_DELAYED", "BAG_CONTAINER_UPDATE", "ITEM_LOCK_CHANGED", "BAG_UPDATE_COOLDOWN",
    "INVENTORY_SEARCH_UPDATE", "BAG_NEW_ITEMS_UPDATED" }

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
local function FillSlot(button, bag, owner)
    local slot = button:GetID()
    local info = GetSlotInfo(bag, slot)
    local quest = GetQuestInfo(bag, slot)
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

-- bag: its index; prefix: the buttons' global names; wanted(): its option; watch(own): hooks once the holder exists.
local function OwnBag(bag, prefix, wanted, watch)
    local R = { slots = {}, list = {}, shown = 0 }

    -- Its size; made ahead even with the option off, so turning it on in a fight answers at once.
    local function BagSize()
        if not (bag and ContainerFrameCombinedBags) then return 0 end
        -- The key ring as the game sizes its own window: the rows its keys fill, never the container (32, most locked).
        if bag == KEYRING and type(GetKeyRingSize) == "function" then return math.max(GetKeyRingSize() or 0, 4) end
        return GetNumSlots(bag) or 0
    end

    local function Wanted()
        return wanted() and BagSize() or 0
    end

    local function Fill()
        local owner = GameTooltip:GetOwner()
        for i = 1, R.shown do FillSlot(R.slots[i], bag, owner) end
    end

    local function FillSoon()
        ns.Sched.NextFrame("bags.ownFill." .. prefix, Fill)
    end

    local function OnEvent(_, event, changed)
        if event == "BAG_CONTAINER_UPDATE" or event == "BAG_UPDATE_DELAYED" then
            -- A bag put on, taken off or swapped: the combined bag's rows change.
            if Wanted() ~= R.shown then ns.ReskinOneBag() end
        elseif event == "BAG_UPDATE" and changed ~= bag then
            return
        end
        FillSoon()
    end

    -- The key ring's bag button lit while its slots show in the one bag, as the game lights a bag's for its open bag
    -- (its own update knows the combined bag holds no key ring).
    local function LitKey(lit)
        local button = bag == KEYRING and KeyRingButton
        if button and button.SlotHighlightTexture then button.SlotHighlightTexture:SetShown(lit) end
    end

    -- Events only while the slots show.
    local function Listen(on)
        if on then
            ns.RegisterEvents(R.events, EVENTS)
            FillSoon()
        else
            R.events:UnregisterAllEvents()
        end
        LitKey(on and R.shown > 0)
    end

    -- The bag number the template reads off its parent (never a field on the button: the click would read it as ours).
    local function Holder()
        if R.holder then return R.holder end
        local holder = ns.NewFrame("Frame", nil, ContainerFrameCombinedBags)
        holder:SetID(bag)
        holder:SetAllPoints()
        R.events = ns.EventFrame({}, OnEvent)
        holder:SetScript("OnShow", function() Listen(true) end)
        holder:SetScript("OnHide", function() Listen(false) end)
        R.holder = holder
        ns.bags.ownChildren[holder] = true
        if watch then watch(R) end
        if holder:IsVisible() then Listen(true) end
        return holder
    end

    local function Make(i)
        local button = ns.NewFrame("ItemButton", prefix .. i, Holder(), "ContainerFrameItemButtonTemplate")
        button:SetID(i)
        -- Off the game's item context and craft quality lists, which register in the name of whoever shows the button.
        button.GetItemContextMatchResult = nil
        button.noProfessionQualityOverlay = true
        R.slots[i] = button
    end

    -- Our slots for the combined bag's grid and their count (0 with the option off or no such bag). Past those made
    -- before a fight, the rest are made once it ends.
    function R.Slots()
        local size = BagSize()
        if size > #R.slots then
            if InCombatLockdown() then
                ns.WhenCalm("bags.ownSlots." .. prefix, ns.ReskinOneBag)
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
        LitKey(n > 0 and R.holder ~= nil and R.holder:IsVisible())
        return R.list, n
    end

    return R
end

-- A hovered bag button lights its slots in the combined bag, as the game's own do.
local function Light(R, on)
    for i, slot in ipairs(R.slots) do slot.BagIndicator:SetShown(on and i <= R.shown) end
end

-- The reagent bag's band button, bag row out only (the game's rule for its own).
local function LightReagent(R)
    local function Lit(button, on) Light(R, on and button:GetIsBarExpanded()) end
    ns.HookScriptOnce(CharacterReagentBag0Slot, "OnEnter", function(button) Lit(button, true) end, "reagentSlots")
    ns.HookScriptOnce(CharacterReagentBag0Slot, "OnLeave", function(button) Lit(button, false) end, "reagentSlots")
end

-- The key ring's band button; the game's own light knows nothing of these slots.
local function LightKeyring(R)
    if not KeyRingButton then return end
    ns.HookScriptOnce(KeyRingButton, "OnEnter", function() Light(R, true) end, "keyringSlots")
    ns.HookScriptOnce(KeyRingButton, "OnLeave", function() Light(R, false) end, "keyringSlots")
end

local reagent = OwnBag(REAGENT, "ForeverClassicUIReagentSlot", function() return ns.db and ns.db.reagentBagCombined end,
    LightReagent)
local keyring = OwnBag(KEYRING, "ForeverClassicUIKeyringSlot", function() return ns.db and ns.db.oneBagKeyring == true end,
    LightKeyring)

ns.OwnReagentSlots = reagent.Slots
ns.OwnKeyringSlots = keyring.Slots

-- The one bag's own bag buttons (Windows/BagSlotRow.lua): our slots for ours, the game's light for its.
function ns.LightBagSlots(bag, on)
    if bag == REAGENT or bag == KEYRING then
        Light(bag == REAGENT and reagent or keyring, on)
    elseif ContainerFrameCombinedBags then
        ContainerFrameCombinedBags:SetItemsMatchingBagHighlighted(bag, on)
    end
end
