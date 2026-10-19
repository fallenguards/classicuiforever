local _, ns = ...

-- Era's minimap toggle (Minimap close button): an X on the zone bar's end box hides the map and every piece on and
-- round it, the zone bar staying; again brings them back. For the session, as Era's.

local MM = ns.MM
local L = ns.L
local TIP = { anchor = "ANCHOR_LEFT", text = L["MAP_TOGGLE"], r = 1, g = 1, b = 1,
    lines = { { L["MAP_TOGGLE_TIP"], 0.8, 0.8, 0.8 } } }
local button
MM.closed = false

local function Toggle()
    MM.closed = not MM.closed
    PlaySound(MM.closed and SOUNDKIT.IG_MINIMAP_CLOSE or SOUNDKIT.IG_MINIMAP_OPEN)
    MM.Relayout()
end

-- The X shows with the zone bar only, so a shut map can always be opened again.
local function Wanted()
    return ns.db.minimapToggleButton == true and ns.db.hideMinimapHeader ~= true
end

-- Laid with the cluster, before the calendar (which steps left of it): the X 1 right and 1 up of the bar's right edge,
-- as Era's, and the map shut or open.
function MM.LayToggle(cluster, header, level)
    local on = Wanted() and header ~= nil
    if not on then MM.closed = false end
    if cluster.MinimapContainer then cluster.MinimapContainer:SetShown(not MM.closed) end
    if not on then
        if button then button:Hide() end
        return
    end
    if not button then
        button = ns.NewFrame("Button", "ForeverClassicUIMinimapToggle", cluster)
        button:SetSize(32, 32)
        ns.SkinCloseButton(button, true)
        button:SetScript("OnClick", Toggle)
        ns.AttachTip(button, TIP)
    end
    ns.SetLevelIf(button, level)
    ns.SetPointOnce(button, "RIGHT", header, "RIGHT", 1, 1)
    button:Show()
end

function MM.ToggleShown()
    return button ~= nil and button:IsShown()
end

-- Our minimap off: the X gone, and the map open if we shut it.
function MM.Reopen()
    if button then button:Hide() end
    if not MM.closed then return end
    MM.closed = false
    local container = MinimapCluster and MinimapCluster.MinimapContainer
    if container then container:Show() end
end
