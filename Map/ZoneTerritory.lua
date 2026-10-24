local _, ns = ...

-- Era's territory line outside the capitals (#55): Forever's zone PvP query answers nothing there, though its zone data
-- holds each zone's side as Era's does (AreaTable FactionGroupMask: 2 Alliance, 4 Horde, 0 contested). The game's own
-- zone text, minimap name colour and tooltip then show it as they show a capital's.

local active = false

-- Era's zones by their map (UiMapAssignment), from that mask; the capitals answer for themselves.
local A, H, C = "Alliance", "Horde", "contested"
local SIDE = {
    [1411] = H, [1412] = H, [1413] = H, [1416] = C, [1417] = C, [1418] = C, [1419] = C, [1420] = H, [1421] = H,
    [1422] = C, [1423] = C, [1424] = C, [1425] = C, [1426] = A, [1427] = C, [1428] = C, [1429] = A, [1430] = C,
    [1431] = C, [1432] = A, [1433] = C, [1434] = C, [1435] = C, [1436] = A, [1437] = C, [1438] = A, [1439] = A,
    [1440] = C, [1441] = C, [1442] = C, [1443] = C, [1444] = C, [1445] = C, [1446] = C, [1447] = C, [1448] = C,
    [1449] = C, [1450] = C, [1451] = C, [1452] = C,
}
-- The game's colours for each (ZoneText.lua, Minimap.lua).
local COLOR = { friendly = { 0.1, 1, 0.1 }, hostile = { 1, 0.1, 0.1 }, contested = { 1, 0.7, 0 } }

-- Ours where the game has none: pvpType and the side's name, or nil (the game answered, an instance, a zone not Era's).
local function Territory()
    if not active or C_PvP.GetZonePVPInfo() ~= nil or IsInInstance() then return nil end
    local id = C_Map.GetBestMapForUnit("player")
    while id do
        local side = SIDE[id]
        if side == C then return C end
        if side then return side == UnitFactionGroup("player") and "friendly" or "hostile", side == A and FACTION_ALLIANCE or FACTION_HORDE end
        local info = C_Map.GetMapInfo(id)
        id = info and info.parentMapID ~= 0 and info.parentMapID or nil
    end
end

local function TerritoryLine(pvpType, factionName)
    if pvpType == C then return CONTESTED_TERRITORY end
    return string.format(FACTION_CONTROLLED_TERRITORY, factionName)
end

-- After the game's zone text: its line again as the game decides it, shown as the territory changes or a zone loads.
local shownType
local function ZoneText(showZone)
    local pvpType, factionName = Territory()
    if not pvpType then
        shownType = nil
        return
    end
    local c = COLOR[pvpType]
    ZoneTextString:SetTextColor(c[1], c[2], c[3])
    SubZoneTextString:SetTextColor(c[1], c[2], c[3])
    if shownType == pvpType and not showZone then return end
    shownType = pvpType
    PVPInfoTextString:SetText(TerritoryLine(pvpType, factionName))
    PVPInfoTextString:SetTextColor(c[1], c[2], c[3])
    SubZoneTextString:SetPoint("TOP", PVPInfoTextString, "BOTTOM", 0, 0)
end

local painted = false
local function MinimapName()
    local pvpType = Territory()
    if pvpType then
        local c = COLOR[pvpType]
        MinimapZoneText:SetTextColor(c[1], c[2], c[3])
        painted = true
    elseif painted then
        painted = false
        if C_PvP.GetZonePVPInfo() == nil then MinimapZoneText:SetTextColor(NORMAL_FONT_COLOR:GetRGB()) end
    end
end

-- The zone name's tooltip drawn again by the game's own function with ours (it calls back here with a type: done).
local function MinimapTip(pvpType)
    if pvpType ~= nil then return end
    local ours, factionName = Territory()
    if not ours or not GameTooltip:IsOwned(MinimapCluster.ZoneTextButton) then return end
    GameTooltip:ClearLines()
    Minimap_SetTooltip(ours, factionName)
end

local hooked = false
local function Apply()
    active = ns.OnForever()
    if not active then return end
    if not hooked then
        hooked = true
        ns.HookGlobal("SetZoneText", ZoneText)
        ns.HookGlobal("Minimap_Update", MinimapName)
        ns.HookGlobal("Minimap_SetTooltip", MinimapTip)
    end
    if MinimapZoneText then MinimapName() end
end

local function Restore()
    if not active then return end
    active = false
    if MinimapZoneText then MinimapName() end
end

ns.RegisterModule("zoneTerritory", { apply = Apply, restore = Restore })

-- Hide zone text: the frame that shows it stops hearing zone changes; unchecked, it hears them again.
local ZONE_EVENTS = { "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA" }
local deaf = false
local function QuietZones(hide)
    if hide == deaf then return end
    deaf = hide
    if not hide then
        ns.RegisterEvents(ZoneTextFrame, ZONE_EVENTS)
        return
    end
    for _, event in ipairs(ZONE_EVENTS) do ZoneTextFrame:UnregisterEvent(event) end
    ZoneTextFrame:Hide()
    SubZoneTextFrame:Hide()
end

ns.RegisterModule("hideZoneText", { apply = function() QuietZones(true) end, restore = function() QuietZones(false) end })

-- In a fight too: the options pass waits one out.
ns.OnToggle(function(key)
    if key == "hideZoneText" then QuietZones(ns.ModuleInForce(key)) end
end)
