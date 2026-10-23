local _, ns = ...

-- The game's search box and Clean Up button on the bags, each with a Hide option (both shown by default). The game shows
-- them again on each bag layout; our skin's search step (Windows/Bags.lua PlaceSearch) runs this after it.
function ns.ShowBagHeader()
    local skin = ns.db and ns.db.bags ~= false
    local box, sort = _G.BagItemSearchBox, _G.BagItemAutoSortButton
    if box then ns.SetShownIf(box, not (skin and ns.db.hideBagSearch == true)) end
    if sort then ns.SetShownIf(sort, not (skin and ns.db.hideBagCleanup == true)) end
end

ns.OnToggle(function(key)
    if key == "hideBagSearch" or key == "hideBagCleanup" or key == "bags" then ns.ShowBagHeader() end
end)
