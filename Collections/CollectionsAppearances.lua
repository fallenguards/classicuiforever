local _, ns = ...

-- The Collections window's Appearances page: one slot's appearances (the slot picked in the search's place), each read
-- with the slot location the game's wardrobe passes (the list call without it aborts the client); the picked look tried
-- on your character in the model box. Names and icons come from a look's sources, read only for the page shown.

local CW = ns.collections
local TC = C_TransmogCollection
local IsSecret = ns.IsSecret

local APPEARANCES_ICON = "Interface\\Icons\\INV_Chest_Cloth_17"
-- Armor categories (Enum.TransmogCollectionType) to their equipment slot and the game's slot name.
local ARMOR = {
    { 1, 1, "HEADSLOT" }, { 2, 3, "SHOULDERSLOT" }, { 3, 15, "BACKSLOT" }, { 4, 5, "CHESTSLOT" }, { 5, 4, "SHIRTSLOT" },
    { 6, 19, "TABARDSLOT" }, { 7, 9, "WRISTSLOT" }, { 8, 10, "HANDSSLOT" }, { 9, 6, "WAISTSLOT" }, { 10, 7, "LEGSSLOT" },
    { 11, 8, "FEETSLOT" },
}
local MAIN_HAND, OFF_HAND, RANGED = 16, 17, 18

local A = { slot = 1 }

-- Weapon categories: the enum's from Wand to its last (a number past its end is an error, not a nil answer).
local function WeaponRange()
    local types, last = Enum.TransmogCollectionType or ns.EMPTY, 0
    for _, value in pairs(types) do
        if type(value) == "number" and value > last then last = value end
    end
    return types.Wand or #ARMOR + 1, last
end

-- The categories this character's wardrobe lists, armor first: weapons the game names (its class can use).
local function Categories()
    if A.categories then return A.categories end
    local out, slots, names = {}, {}, {}
    for _, row in ipairs(ARMOR) do
        out[#out + 1] = row[1]
        slots[row[1]], names[row[1]] = row[2], _G[row[3]] or row[3]
    end
    local first, last = WeaponRange()
    for category = first, last do
        local name, isWeapon, _, mainHand, offHand, ranged = TC.GetCategoryInfo(category)
        if type(name) == "string" and isWeapon then
            out[#out + 1] = category
            slots[category] = (mainHand and MAIN_HAND) or (offHand and OFF_HAND) or (ranged and RANGED) or nil
            names[category] = name
        end
    end
    A.categories, A.slots, A.names = out, slots, names
    return out
end

local function Location(category)
    Categories()
    local slotID = A.slots[category]
    if not slotID then return nil end
    return { slotID = slotID, type = Enum.TransmogType and Enum.TransmogType.Appearance or 0,
        modification = Enum.TransmogModification and Enum.TransmogModification.Main or 0 }
end

local function ByOrder(a, b)
    if a.collected ~= b.collected then return a.collected end
    return (a.order or 0) < (b.order or 0)
end

-- The game starts the wardrobe's filters over each session: the player's picks are saved (db.collectionsShow.appearances)
-- and put back the first time the page lists.
local function Remember()
    local saved = { collected = TC.GetCollectedShown(), missing = TC.GetUncollectedShown(), class = TC.GetClassFilter(),
        sources = {} }
    for i = 1, TC.GetNumTransmogSources() do
        if TC.IsValidTransmogSource(i) then saved.sources[i] = TC.IsSourceTypeFilterChecked(i) end
    end
    ns.DbTable("collectionsShow").appearances = saved
end

local function Restore()
    if A.restored then return end
    A.restored = true
    local saved = ns.DbTable("collectionsShow").appearances
    if type(saved) ~= "table" then return end
    if saved.collected ~= nil then TC.SetCollectedShown(saved.collected) end
    if saved.missing ~= nil then TC.SetUncollectedShown(saved.missing) end
    if saved.class then TC.SetClassFilter(saved.class) end
    for i, on in pairs(saved.sources or ns.EMPTY) do
        if TC.IsValidTransmogSource(i) then TC.SetSourceTypeFilter(i, on) end
    end
end

local function List()
    Restore()
    local location = Location(A.slot)
    local out = {}
    if not location then return out end
    for _, visual in ipairs(TC.GetCategoryAppearances(A.slot, location) or ns.EMPTY) do
        if not visual.isHideVisual then
            out[#out + 1] = { id = visual.visualID, collected = visual.isCollected == true, order = visual.uiOrder,
                name = "", category = A.slot }
        end
    end
    table.sort(out, ByOrder)
    return out
end

-- A look's name and icon from its first collected source (else its first), read as the look is drawn.
local function Fill(entry)
    if entry.filled then return end
    entry.filled = true
    local sources = TC.GetAppearanceSources(entry.id, entry.category, Location(entry.category)) or ns.EMPTY
    local pick = sources[1]
    for _, source in ipairs(sources) do
        if source.isCollected then pick = source break end
    end
    if not pick then return end
    entry.sourceID, entry.itemID, entry.sourceType = pick.sourceID, pick.itemID, pick.sourceType
    if type(pick.name) == "string" and not IsSecret(pick.name) then entry.name = pick.name end
    entry.icon = pick.itemID and C_Item.GetItemIconByID(pick.itemID) or nil
end

local function Show(entry, box)
    local source = entry.sourceType and _G["TRANSMOG_SOURCE_" .. entry.sourceType]
    if type(source) == "string" then box.source:SetText(source) end
    if not entry.sourceID then return end
    box.model:Show()
    box.model:SetUnit("player")
    box.model:TryOn(entry.sourceID)
    box.model:SetFacing(0)
end

local function Action() end

local function Tip(entry)
    if entry.itemID then GameTooltip:SetItemByID(entry.itemID) else GameTooltip:SetText(entry.name) end
end

-- The Filter menu is the wardrobe's own filters (collected, sources, class), set on the player's pick; Forever's own
-- default shows collected looks only, kept.
local function Shown()
    return TC.GetCollectedShown(), TC.GetUncollectedShown()
end

local function Check(get, set, after)
    return function() return get() end, function()
        set(not get())
        after()
    end
end

local function SourceEntries(after)
    local out = {
        { CW.Text("CHECK_ALL", "COLL_CHECK_ALL"), click = function()
            TC.SetAllSourceTypeFilters(true)
            after()
        end },
        { CW.Text("UNCHECK_ALL", "COLL_UNCHECK_ALL"), click = function()
            TC.SetAllSourceTypeFilters(false)
            after()
        end },
    }
    for i = 1, TC.GetNumTransmogSources() do
        local name = TC.IsValidTransmogSource(i) and _G["TRANSMOG_SOURCE_" .. i]
        if type(name) == "string" then
            local check, toggle = Check(function() return TC.IsSourceTypeFilterChecked(i) end,
                function(on) TC.SetSourceTypeFilter(i, on) end, after)
            out[#out + 1] = { name, check = check, toggle = toggle }
        end
    end
    return out
end

-- Every class, as the wardrobe's class menu; the game starts it on your own.
local function ClassEntries(after)
    local out = {}
    for _, classID in ipairs(C_SpecializationInfo.GetAllClassIDs() or ns.EMPTY) do
        local info = C_CreatureInfo.GetClassInfo(classID)
        if info then
            out[#out + 1] = { info.className, radio = function() return TC.GetClassFilter() == classID end,
                pick = function()
                    TC.SetClassFilter(classID)
                    after()
                end }
        end
    end
    return out
end

local function FilterEntries(refiltered)
    local function after()
        Remember()
        refiltered()
    end
    local collected, toggleCollected = Check(TC.GetCollectedShown, TC.SetCollectedShown, after)
    local missing, toggleMissing = Check(TC.GetUncollectedShown, TC.SetUncollectedShown, after)
    return {
        { CW.Text("COLLECTED", "COLL_COLLECTED"), check = collected, toggle = toggleCollected },
        { CW.Text("NOT_COLLECTED", "COLL_NOT_COLLECTED"), check = missing, toggle = toggleMissing },
        { divider = true },
        { CW.Text("SOURCES", "COLL_SOURCES"), sub = function() return SourceEntries(after) end },
        { CW.Text("CLASS", "COLL_CLASS"), sub = function() return ClassEntries(after) end },
    }
end

local Picker = {
    Get = function() return A.slot end,
    -- From outside (an addon asking for a look): false when the list has no such category.
    Set = function(category)
        for _, known in ipairs(Categories()) do
            if known == category then
                A.slot = category
                return true
            end
        end
        return false
    end,
    Label = function(category)
        Categories()
        return A.names[category] or ""
    end,
    Entries = function(after)
        local out = {}
        for _, category in ipairs(Categories()) do
            out[#out + 1] = { A.names[category], function()
                A.slot = category
                after()
            end, function() return A.slot == category end }
        end
        return out
    end,
}

CW.AddPage({
    -- After Heirlooms on retail, as the game's window has them.
    key = "appearances", tab = ns.OnForever() and 4 or 5, pan = true, icon = APPEARANCES_ICON, tip = { "WARDROBE", "COLL_APPEARANCES" },
    events = { "TRANSMOG_COLLECTION_UPDATED", "TRANSMOG_COLLECTION_SOURCE_ADDED", "TRANSMOG_COLLECTION_SOURCE_REMOVED" },
    List = List, Fill = Fill, Show = Show, Action = Action, Tip = Tip, Shown = Shown, FilterEntries = FilterEntries,
    Picker = Picker,
    -- An addon asks by source: its look, in its category.
    Want = function(sourceID)
        local info = TC.GetSourceInfo(sourceID)
        if info then return info.visualID, info.categoryID end
    end,
})
