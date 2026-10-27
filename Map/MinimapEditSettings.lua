local _, ns = ...

-- The game's edit mode settings for the minimap that our 1.x cluster follows: Size and Header Underneath.

local MM = ns.MM
-- Header Underneath as Era lays it (Classic Minimap.lua SetHeaderUnderneath): the map's top at the cluster's, the
-- bar's top 6 under the map's bottom, the clock where it was. The coordinates go under the bar.
local RING_UP = 22
local PLATE_Y = -146
local MAP_FOOT = 140   -- the map's bottom in the cluster, gone up
local COORDS_Y = -16   -- the coordinates under the map's bottom and the clock, with the header on top

local function Setting(read, key)
    local cluster = MinimapCluster
    local setting = Enum and Enum.EditModeMinimapSetting and Enum.EditModeMinimapSetting[key]
    if not (cluster and cluster[read] and setting) then return nil end
    local ok, value = pcall(cluster[read], cluster, setting)
    if ok then return value end
end

-- Edit mode's size: the map container's scale and our pieces' frame's (Map/Minimap.lua).
function MM.MapSize()
    local value = Setting("GetSettingValue", "Size")
    if type(value) == "number" and value > 0 then return value / 100 end
    return 1
end

-- How far the ring and map go up, the plate's top, and the coordinates' spot under the map's bottom.
function MM.HeaderOffsets()
    if Setting("GetSettingValueBool", "HeaderUnderneath") ~= true then return 0, 0, COORDS_Y end
    return RING_UP, PLATE_Y, MAP_FOOT + PLATE_Y - 33
end
