local _, ns = ...

-- The classic map in a fight: the game lays it at its own size and spot on its first open and on maximize or restore,
-- and our snippet cannot start from our code then. Secure watchers lay the map frame, from values set as the fight
-- begins; Era's picture box hangs from its top left, so it needs no lay (a fight's snippet reaches protected frames only).

local MF = ns.MapFight

-- Under the quest pane toggle, which the game shows after its restore and hides after its maximize, last in its own
-- sizing and placing; and under the map for an open already maximized. The toggle shown is the state: restored.
-- v: the quest pane open (1) or shut (0), told by the width the game left the map (its own, or ours).
local FIGHT_LAY = [[
    if not PlayerInCombat() then return end
    local lay = self:GetFrameRef("lay")
    if lay:GetAttribute("on") ~= 1 or lay:GetAttribute("busy") then return end
    local map = self:GetFrameRef("map")
    if not map:IsShown() then return end
    local width = map:GetWidth()
    local v = (math.abs(width - lay:GetAttribute("cw1")) < 1 or math.abs(width - lay:GetAttribute("w1")) < 1) and 1 or 0
    lay:SetAttribute("busy", true)
    map:SetWidth(lay:GetAttribute("w" .. v))
    map:SetHeight(lay:GetAttribute("h" .. v))
    if lay:GetAttribute("place") ~= 1 then
        lay:SetAttribute("busy", nil)
        return
    end
    map:ClearAllPoints()
    if self:GetFrameRef("toggle"):IsShown() then
        local k = lay:GetAttribute("k")
        map:SetScale(k)
        map:SetPoint("TOPLEFT", "$parent", "BOTTOMLEFT", lay:GetAttribute("x" .. v) / k, lay:GetAttribute("y" .. v) / k)
    else
        map:SetScale(lay:GetAttribute("full" .. v))
        map:SetPoint("TOP", "$parent", "TOP", 0, 0)
    end
    lay:SetAttribute("busy", nil)
]]

-- Out of combat, last as the fight begins: the box, scale and spot the pass would lay, quest pane open and shut, and
-- the widths the game gives the map either way.
local Hang

local function FightValues()
    local map = MF.Map()
    if InCombatLockdown() or not map then return end
    local lay = MF.Layout()
    local style = MF.EraStyle()
    ns.SetAttributeIf(lay, "on", style and 1 or 0)
    Hang(style and not ns.MoverHolds(map))
    if not style then return end
    -- Left to another addon (a mover, or Leave game windows): our box only, as out of combat; no scale or spot.
    ns.SetAttributeIf(lay, "place", ns.MoverHolds(map) and 0 or 1)
    local own = map.minimizedWidth or 0
    ns.SetAttributeIf(lay, "cw1", own + (map.questLogWidth or 0))
    local screenH = UIParent:GetHeight()
    for v = 0, 1 do
        local w, h = MF.Size(style, v == 1)
        local k, left, top = ns.MapPlaceFor(w, h, MF.WindowedBase(style))
        if not left then
            local down
            left, down = ns.GameHome(map, h * k)
            top = screenH - down
        end
        ns.SetAttributeIf(lay, "w" .. v, w)
        ns.SetAttributeIf(lay, "h" .. v, h)
        ns.SetAttributeIf(lay, "full" .. v, MF.FullScale(w, h))
        ns.SetAttributeIf(lay, "x" .. v, left)
        ns.SetAttributeIf(lay, "y" .. v, top)
        ns.SetAttributeIf(lay, "k", k)
    end
end

local made = false
local watchers = {}   -- watch -> the map frame it hangs on while our layout lays the map in fights
local shelf           -- off the map, a hidden frame of ours
local function Watch(parent, onHide)
    local map = MF.Map()
    local watch = ns.NewFrame("Frame", nil, shelf, "SecureHandlerShowHideTemplate")
    watch:SetFrameRef("lay", MF.Layout())
    watch:SetFrameRef("map", map)
    watch:SetFrameRef("toggle", map.SidePanelToggle)
    watch:SetAttribute("_onshow", FIGHT_LAY)
    if onHide then watch:SetAttribute("_onhide", FIGHT_LAY) end
    watchers[watch] = parent
end

-- A secure child makes the map and the toggle protected in fights (the game's keys and clicks still open and size it),
-- and another addon's moves and scaling are refused then (#220): on the map only while ours lays it, else on the shelf.
Hang = function(on)
    for watch, parent in pairs(watchers) do
        local want = on and parent or shelf
        if watch:GetParent() ~= want then watch:SetParent(want) end
    end
end

-- Made once out of combat. Each hangs from a frame, never a region.
local function MakeWatchers()
    local map = MF.Map()
    if made or InCombatLockdown() or not (map and map.SidePanelToggle) then return end
    made = true
    shelf = ns.NewFrame("Frame", nil, UIParent)
    shelf:Hide()
    Watch(map, false)
    Watch(map.SidePanelToggle, true)
    FightValues()
end

-- Not yet locked as the fight's first event dispatches: the values are set then, and on every login and load.
ns.EventFrame({ "PLAYER_REGEN_DISABLED", "PLAYER_ENTERING_WORLD", "ADDON_LOADED" }, function(_, event)
    if event ~= "PLAYER_REGEN_DISABLED" then MakeWatchers() end
    FightValues()
end)
ns.OnToggle(function() FightValues() end)
