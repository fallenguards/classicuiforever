local _, ns = ...

-- Forever lays the bag's own icon, faded, over the combined bag's empty slots on each update (EmptyBagIcon), so a
-- quiver's slots read as the quiver's (#334); Plain empty slots hides it. The game sets hasItem before it paints a slot,
-- and asks only its own combined bag for the icon: a pass of ours (the option turned off) shows it as the game would.
function ns.BagEmptyLook(button)
    if button.icon then button.icon:SetAlpha(button.hasItem and 1 or 0) end
    local bagIcon = button.EmptyBagIcon
    if not bagIcon then return end
    if ns.db and ns.db.oneBagPlainSlots == true then
        if bagIcon:IsShown() then bagIcon:Hide() end
    elseif not bagIcon:IsShown() and not button.hasItem and bagIcon:GetTexture() ~= nil
        and button.ShouldUseBagIconForEmptySlot and button:ShouldUseBagIconForEmptySlot() then
        bagIcon:Show()
    end
end
