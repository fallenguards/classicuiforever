local _, ns = ...

-- The Who list's class, race and zone filters, as the game's own Who window has them: kept for the session and sent
-- with each search (classes and races checked off, zones checked on, as the game sends them).

local S = ns.social
local C_FriendList, C_Map, GetNumClasses, GetClassInfo = C_FriendList, C_Map, GetNumClasses, GetClassInfo
local ORIGIN = Enum.SocialWhoOrigin and Enum.SocialWhoOrigin.Social

local classesOff, racesOff, mapsOn = {}, {}, {}
local mapsDefaulted = false
local filters = { classIDs = {}, raceIDs = {}, uiMapIDs = {} }

local function Flip(set, id)
    if set[id] then set[id] = nil else set[id] = true end
end

local function Keys(set, into)
    wipe(into)
    for id in pairs(set) do into[#into + 1] = id end
end

-- Results to our window, a single match too: the game's own who window turns this off as it hides, and we hide it.
function S.SendWho(text)
    if not (C_FriendList and C_FriendList.SendWho) then return end
    Keys(classesOff, filters.classIDs)
    Keys(racesOff, filters.raceIDs)
    Keys(mapsOn, filters.uiMapIDs)
    if C_FriendList.SetWhoToUi then C_FriendList.SetWhoToUi(true) end
    pcall(C_FriendList.SendWho, text or "", ORIGIN, filters)
end

-- Check All and Uncheck All over ids; holdsChecked: the set holds the checked ids (zones), else the unchecked ones.
local function AllRows(set, ids, holdsChecked)
    local function SetAll(checked)
        for _, id in ipairs(ids) do
            if checked == holdsChecked then set[id] = true else set[id] = nil end
        end
    end
    return { CHECK_ALL or "Check All", click = function() SetAll(true) end },
        { UNCHECK_ALL or "Uncheck All", click = function() SetAll(false) end }
end

local function OffList(list, set)
    local ids, entries = {}, {}
    for _, item in ipairs(list) do ids[#ids + 1] = item.id end
    entries[1], entries[2] = AllRows(set, ids, false)
    for _, item in ipairs(list) do
        local id = item.id
        entries[#entries + 1] = { item.name, check = function() return not set[id] end, toggle = function() Flip(set, id) end }
    end
    return entries
end

local classEntries, raceEntries
local function ClassEntries()
    if not classEntries then
        local list = {}
        for i = 1, GetNumClasses() do
            local name, _, id = GetClassInfo(i)
            if id then list[#list + 1] = { name = name, id = id } end
        end
        classEntries = OffList(list, classesOff)
    end
    return classEntries
end

local function RaceEntries()
    if not raceEntries then
        local list = {}
        for _, race in ipairs(C_FriendList.GetWhoRaceFilters() or {}) do list[#list + 1] = { name = race.name, id = race.ID } end
        raceEntries = OffList(list, racesOff)
    end
    return raceEntries
end

-- The world over the player's map, its continents and their zones, as the game's own Zone filter walks them.
local function TopMap()
    local here = C_Map.GetBestMapForUnit("player") or C_Map.GetFallbackWorldMapID()
    local top = here and MapUtil.GetMapParentInfo(here, Enum.UIMapType.World, true)
    return top and top.mapID
end

local function Pickable(id)
    for _, child in ipairs(C_Map.GetMapChildrenInfo(id) or {}) do
        if C_Map.IsMapValidForNavBarDropdown(child.mapID) then return true end
    end
    return false
end

local function ByName(a, b) return a.name < b.name end

local function MapRows(id, into, leaves)
    local children = C_Map.GetMapChildrenInfo(id)
    if not children then return into end
    table.sort(children, ByName)
    for _, child in ipairs(children) do
        local childID = child.mapID
        if C_Map.IsMapValidForNavBarDropdown(childID) then
            if Pickable(childID) then
                into[#into + 1] = { child.name, sub = MapRows(childID, {}, leaves) }
            else
                if not mapsDefaulted then mapsOn[childID] = true end
                leaves[#leaves + 1] = childID
                into[#into + 1] = { child.name, check = function() return mapsOn[childID] end,
                    toggle = function() Flip(mapsOn, childID) end }
            end
        end
    end
    return into
end

local function ZoneEntries()
    local entries, leaves = { false, false }, {}
    local top = TopMap()
    if top then MapRows(top, entries, leaves) end
    mapsDefaulted = true
    entries[1], entries[2] = AllRows(mapsOn, leaves, true)
    return entries
end

-- The filter submenus for the Who list's menu: class, race, zone.
function S.WhoFilterLists()
    return ClassEntries, RaceEntries, ZoneEntries
end
