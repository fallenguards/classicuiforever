local _, ns = ...

-- Era's city and town markers on the continent maps (#165). Forever draws Era's numbers from a newer sheet where its
-- tower is 6 and house 5 (capitals, Era 5, got the house), and its towns lost their continent flag: the capitals'
-- markers get the tower painted back, towns get markers of ours, sized and placed as the game's (MapCanvasPinMixin).

local GetPOITextureCoords = C_Minimap.GetPOITextureCoords
local GetMapPosFromWorldPos = C_Map.GetMapPosFromWorldPos
local GetMapInfoAtPosition = C_Map.GetMapInfoAtPosition
local GetAreaInfo = C_Map.GetAreaInfo
local GetExploredAreaIDsAtPosition = C_MapExplorationInfo.GetExploredAreaIDsAtPosition

local TOWER, HOUSE = 6, 5
local ERA_CAPITAL, ERA_TOWN = 5, 4
local POI_ICONS = "Interface\\Minimap\\POIIcons"
local PIN, ICON = 32, 16
-- The game's area markers grow from 1 to 1.2 as the map zooms in.
local SCALE_OUT, SCALE_IN = 1, 1.2
local CONTINENT_MAP = { [0] = 1415, [1] = 1414 }
local CONTINENT_OF = { [1415] = 0, [1414] = 1 }
local POI_TEMPLATE = "AreaPOIPinTemplate"

local CAPITALS = { [8] = true, [16] = true, [18] = true, [29] = true, [33] = true, [38] = true }
-- POI id, continent (0 Eastern Kingdoms, 1 Kalimdor), world x, y, the area of the same name (dev/tools/map_markers.py),
-- and the area Era's row waits for: Era shows those two only once it is explored (#205, /eram towns).
local TOWNS = {
    { 3, 0, -10564.7, -1170.7, 42 },      -- Darkshire
    { 10, 0, -9227.7, -2201.5, 69 },      -- Lakeshire
    { 11, 0, -3672.7, -828.5, 150 },      -- Menethil Harbor
    { 15, 0, -10503.7, 1027.8, 108 },     -- Sentinel Hill
    { 17, 0, 508.1, 1619.0, 228 },        -- The Sepulcher
    { 19, 0, -5349.3, -2959.9, 144 },     -- Thelsamar
    { 22, 0, -803.0, -531.7, 271 },       -- Southshore
    { 23, 0, -27.0, -900.6, 272 },        -- Tarren Mill
    { 25, 0, -991.6, -3528.3, 321 },      -- Hammerfall
    { 26, 0, -6676.4, -2186.7, 340 },     -- Kargath
    { 35, 1, -455.9, -2652.1, 380 },      -- The Crossroads
    { 39, 1, -951.4, -3680.1, 392 },      -- Ratchet
    { 40, 0, -14383.3, 487.1, 35 },       -- Booty Bay
    { 41, 0, -12378.4, 185.7, 117 },      -- Grom'gol Base Camp
    { 42, 1, 2720.4, -382.4, 415 },       -- Astranaar
    { 44, 1, 2658.8, 1449.7, 467 },       -- Stonetalon Peak
    { 45, 1, -4510.0, -779.5, 489 },      -- Thalanaar
    { 46, 1, -5454.1, -2445.5, 484 },     -- Freewind Post
    { 701, 1, 936.3, 911.0, 460 },        -- Sun Rock Retreat
    { 788, 0, -10443.7, -3277.5, 75 },    -- Stonard
    { 789, 1, -7139.1, -3752.1, 976 },    -- Gadgetzan
    { 790, 1, -4395.0, 215.6, 1099 },     -- Camp Mojache
    { 791, 1, -3680.2, -4388.5, 513 },    -- Theramore Isle
    { 792, 0, 234.9, -2127.8, 348 },      -- Aerie Peak
    { 794, 1, 6723.5, -4662.5, 2255 },    -- Everlook
    { 795, 1, -1657.8, 3097.9, 2408 },    -- Shadowprey Village
    { 796, 1, -4435.0, 3276.7, 1116 },    -- Feathermoon Stronghold
    { 798, 1, 6439.3, 412.0, 442 },       -- Auberdine
    { 799, 1, 202.5, 1308.2, 608 },       -- Nijel's Point
    { 1469, 1, -2352.7, -1921.7, 378 },   -- Camp Taurajo
    { 1471, 1, 2286.4, -2564.7, 431 },    -- Splintertree Post
    { 1507, 0, -573.5, -4590.5, 3317, 307 },    -- Revantusk Village (The Overlook Cliffs)
    { 1685, 1, -6886.1, 718.4, 3425, 3425 },    -- Cenarion Hold
}
local TOWN_IDS = {}
for _, row in ipairs(TOWNS) do TOWN_IDS[row[1]] = row end

local M = {
    markers = {},
    spots = {},
    -- Client pin -> the poiInfo it was painted for; a new acquire brings a new table and the game's own paint.
    painted = setmetatable({}, { __mode = "k" }),
    gameShows = {},
    laid = {},
    -- POI id -> its waited-for area explored; read again each time the map opens.
    explored = {},
    reads = 0,
}

local function On() return ns.db ~= nil and ns.db.mapMarkers ~= false end

local function Paint(pin, index)
    local x1, x2, y1, y2 = GetPOITextureCoords(index)
    if pin.Texture then pin.Texture:SetTexCoord(x1, x2, y1, y2) end
    if pin.HighlightTexture then pin.HighlightTexture:SetTexCoord(x1, x2, y1, y2) end
end

-- Era's picture for one of its markers, while the row still holds Era's number.
local function EraIndex(info)
    if info.atlasName then return nil end
    local id = info.areaPoiID
    if CAPITALS[id] and info.textureIndex == ERA_CAPITAL then return TOWER end
    if TOWN_IDS[id] and info.textureIndex == ERA_TOWN then return HOUSE end
end

-- The game's markers on the map shown: Era's picture painted on, or handed back with the option off.
local function PaintPins(map, on)
    wipe(M.gameShows)
    local level
    for pin in map:EnumeratePinsByTemplate(POI_TEMPLATE) do
        local info = pin.poiInfo
        if info then
            M.gameShows[info.areaPoiID] = true
            level = level or pin:GetFrameLevel()
            local was = M.painted[pin]
            if was and was ~= info then M.painted[pin] = nil end
            local want = on and EraIndex(info)
            if want and M.painted[pin] ~= info then
                Paint(pin, want)
                M.painted[pin] = info
            elseif not want and M.painted[pin] then
                Paint(pin, info.textureIndex)
                M.painted[pin] = nil
            end
        end
    end
    return level
end

local function Spot(row)
    local spot = M.spots[row[1]]
    if not spot then
        local _, pos = GetMapPosFromWorldPos(row[2], CreateVector2D(row[3], row[4]), CONTINENT_MAP[row[2]])
        if not pos then return nil end
        spot = { pos.x, pos.y }
        M.spots[row[1]] = spot
    end
    return spot[1], spot[2]
end

local function Explored(row)
    if not row[6] then return true end
    local seen = M.explored[row[1]]
    if seen == nil then
        seen = false
        local x, y = Spot(row)
        local zone = x and GetMapInfoAtPosition(CONTINENT_MAP[row[2]], x, y)
        local _, pos
        if zone then _, pos = GetMapPosFromWorldPos(row[2], CreateVector2D(row[3], row[4]), zone.mapID) end
        local areas = pos and GetExploredAreaIDsAtPosition(zone.mapID, pos)
        if areas then
            for _, area in ipairs(areas) do
                if area == row[6] then seen = true end
            end
        end
        M.explored[row[1]] = seen
    end
    return seen
end

local function TownName(marker)
    local row = TOWN_IDS[marker.poi]
    return row and GetAreaInfo(row[5])
end

local function Marker(row, canvas)
    local marker = M.markers[row[1]]
    if not marker then
        marker = ns.NewFrame("Frame", nil, canvas)
        marker:SetSize(PIN, PIN)
        local tex = marker:CreateTexture(nil, "ARTWORK")
        tex:SetSize(ICON, ICON)
        tex:SetPoint("CENTER")
        tex:SetTexture(POI_ICONS)
        tex:SetTexCoord(GetPOITextureCoords(HOUSE))
        -- Hover for the name; a click goes through to the map below (clicks off after the scripts, which turn them on).
        marker.poi = row[1]
        ns.AttachTip(marker, { text = TownName, r = 1, g = 1, b = 1 })
        marker:EnableMouse(true)
        marker:SetMouseClickEnabled(false)
        M.markers[row[1]] = marker
    end
    return marker
end

local function HideMarkers()
    if not M.laid.continent then return end
    for _, marker in pairs(M.markers) do ns.SetShownIf(marker, false) end
    wipe(M.laid)
end

local function PinScale(map)
    local zoom = math.min(math.max(map:GetCanvasZoomPercent() or 0, 0), 1)
    return (SCALE_OUT + (SCALE_IN - SCALE_OUT) * zoom) / map:GetCanvasScale() * map:GetGlobalPinScale()
end

local function Lay(map, continent, canvas, level)
    local scale = PinScale(map)
    local w, h = canvas:GetWidth(), canvas:GetHeight()
    local laid, shown = M.laid, 0
    for id in pairs(M.gameShows) do if TOWN_IDS[id] then shown = shown + 1 end end
    if laid.continent == continent and laid.scale == scale and laid.w == w and laid.h == h and laid.level == level
        and laid.shown == shown and laid.reads == M.reads then return end
    laid.continent, laid.scale, laid.w, laid.h, laid.level, laid.shown = continent, scale, w, h, level, shown
    laid.reads = M.reads
    for _, row in ipairs(TOWNS) do
        local x, y = Spot(row)
        local wanted = row[2] == continent and x ~= nil and not M.gameShows[row[1]] and Explored(row)
        local marker = (wanted or M.markers[row[1]]) and Marker(row, canvas)
        if wanted then
            marker:SetScale(scale)
            if level then ns.SetLevelIf(marker, level) end
            ns.SetPointOnce(marker, "CENTER", canvas, "TOPLEFT", w * x / scale, -h * y / scale)
        end
        if marker then ns.SetShownIf(marker, wanted) end
    end
end

local function Pass()
    local map = WorldMapFrame
    local canvas = map and map.ScrollContainer and map.ScrollContainer.Child
    if not canvas then return end
    local on = On()
    local level = PaintPins(map, on)
    local continent = on and CONTINENT_OF[map:GetMapID()]
    if continent then Lay(map, continent, canvas, level) else HideMarkers() end
end

-- For the dev self-test: the rows, a town's spot and a marker as laid.
ns.MapMarkers = { TOWNS = TOWNS, CAPITALS = CAPITALS, Spot = Spot, Explored = Explored, markers = M.markers,
    painted = M.painted }

local function Attach()
    local map = WorldMapFrame
    if not map or not map.ScrollContainer then return false end
    ns.Sched.OnVisible(map, "map.markers.explored", function(shown)
        if shown then
            wipe(M.explored)
            M.reads = M.reads + 1
        end
    end)
    ns.Sched.Attach(map, { name = "map.markers", every = 0, fn = Pass })
    return true
end

ns.AttachWhenLoaded(Attach)

ns.OnToggle(function(key)
    if key == "mapMarkers" and WorldMapFrame and WorldMapFrame:IsShown() then Pass() end
end)
