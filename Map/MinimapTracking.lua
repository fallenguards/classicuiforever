local _, ns = ...

-- 1.x MiniMapTracking: the active tracking spell on the rim; right-click cancels it. Its buff leaves the buff bar
-- meanwhile (TrackingBuff.lua). Era's size, a ring larger than the others, unless Same size as other buttons.

local MM = ns.MM
local C_Minimap = _G.C_Minimap
local trackFrame
-- Era's MiniMapTracking (MinimapTracking_Simple.xml): 33 square, a 64 ring, its square 24 icon 2 right and 2 down.
local ERA = { size = 33, ring = 64, icon = 24, x = 2, y = -2 }
-- The others' size: a 52 ring like the mail and eye, the icon round in its hole (ring centre at 20, 19 of 64).
local SAME = { size = 32, ring = 52, icon = 22, round = true }
local TRACK_BORDER = { layer = "ARTWORK", w = 52, h = 52, point = "TOPLEFT" }
local TRACK_EVENTS = { "MINIMAP_UPDATE_TRACKING", "SPELLS_CHANGED", "PLAYER_ENTERING_WORLD" }

local function TrackingOn() return MM.active and ns.db and ns.db.classicTracking ~= false end
MM.TrackingOn = TrackingOn

-- The frame, ring and icon at Era's size or the others'; Era's icon square, its edges under the ring.
local function Shape(frame)
    local look = ns.db and ns.db.trackingSameSize and SAME or ERA
    local icon = frame.icon
    frame:SetSize(look.size, look.size)
    frame.border:SetSize(look.ring, look.ring)
    icon:SetSize(look.icon, look.icon)
    icon:ClearAllPoints()
    if look.round then
        icon:SetPoint("CENTER", frame.border, "TOPLEFT", look.ring * 20 / 64, -look.ring * 19 / 64)
        local made = icon.fcuiMask ~= nil
        ns.RoundIcon(icon)
        if made and not frame.masked then icon:AddMaskTexture(icon.fcuiMask) end
        frame.masked = true
    else
        icon:SetPoint("CENTER", frame, "CENTER", look.x, look.y)
        icon:SetTexCoord(0, 1, 0, 1)
        if frame.masked then icon:RemoveMaskTexture(icon.fcuiMask) end
        frame.masked = false
    end
end

local function ActiveTrackingSpell()
    if not (C_Minimap and C_Minimap.GetNumTrackingTypes and C_Minimap.GetTrackingInfo) then return nil end
    local count = C_Minimap.GetNumTrackingTypes()
    if ns.IsSecret(count) or type(count) ~= "number" then return nil end
    for i = 1, count do
        local info = C_Minimap.GetTrackingInfo(i)
        if info and not ns.AnySecret(info.active, info.type) and info.active and info.type == "spell" then
            return i, info
        end
    end
    return nil
end

local function UpdateTracking()
    local frame = trackFrame
    local index, info
    if frame and TrackingOn() then index, info = ActiveTrackingSpell() end
    if MM.TrackingBuff then MM.TrackingBuff(info) end
    if not frame then return end
    frame.index = index
    frame.spellID = info and not ns.IsSecret(info.spellID) and info.spellID or nil
    frame.name = info and info.name
    if info then
        frame.icon:SetTexture(info.texture)
        Shape(frame)
    end
    frame:SetShown(index ~= nil)
end
MM.UpdateTracking = UpdateTracking

local function QueueTracking() ns.Sched.Soon("minimap.tracking", UpdateTracking) end

local function TrackingMouseUp(self, button)
    if button == "RightButton" and self.index and C_Minimap.SetTracking then
        C_Minimap.SetTracking(self.index, false)
    end
end

local function TrackingEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
    if self.spellID and GameTooltip.SetSpellByID then
        GameTooltip:SetSpellByID(self.spellID)
    else
        GameTooltip:SetText(self.name or "", 1, 1, 1)
    end
    GameTooltip:Show()
end

-- Era's rim spot, in our backdrop's coordinates, until it is dragged round the ring (shift-drag, or edit mode): then at
-- its angle, as far from the map's middle as Era's spot is.
local TRACK_KEY, TRACK_ANGLE, TRACK_R = "minimapTrackingIcon", "trackingIconAngle", 83.6
local function PlaceTracking()
    local frame = trackFrame
    if not frame then return end
    local degrees = ns.db and ns.db[TRACK_ANGLE]
    if degrees then
        ns.RingPoint(frame, degrees, TRACK_R, frame:GetEffectiveScale() / Minimap:GetEffectiveScale())
    else
        ns.SetPointOnce(frame, "TOPLEFT", frame:GetParent(), "TOPLEFT", 11, -26)
    end
end
function ns.LayTrackingIcon(key)
    if key == TRACK_KEY then PlaceTracking() end
end

function MM.TrackingFrame(backdrop, level)
    local frame = trackFrame
    if not frame then
        frame = ns.NewFrame("Frame", "ForeverClassicUIMinimapTrackingIcon", backdrop)
        trackFrame = frame
        frame:Hide()
        frame:EnableMouse(true)
        -- Shift-drag round the ring, as our ring buttons move.
        frame:RegisterForDrag("LeftButton")
        local drag = ns.Sched.OnFrame(ns.NewFrame("Frame", nil, frame), { name = "minimap.trackingDrag", every = 0,
            awake = false, fn = function()
                ns.db[TRACK_ANGLE] = ns.MinimapCursorAngle()
                PlaceTracking()
            end })
        frame:SetScript("OnDragStart", function() if IsShiftKeyDown() then drag:Wake() end end)
        frame:SetScript("OnDragStop", function() drag:Sleep() end)
        if ns.PlaceSavedWindows then ns.PlaceSavedWindows() end
        frame.border = ns.DressNew(frame, "trackingBorder", TRACK_BORDER)
        ns.MinimapButtonBorder(frame.border)
        frame.icon = frame:CreateTexture(nil, "BORDER")
        Shape(frame)
        frame:SetScript("OnMouseUp", TrackingMouseUp)
        frame:SetScript("OnEnter", TrackingEnter)
        frame:SetScript("OnLeave", GameTooltip_Hide)
        frame:SetScript("OnEvent", QueueTracking)
        ns.RegisterEvents(frame, TRACK_EVENTS)
        UpdateTracking()
    end
    frame:SetFrameLevel(level)
    PlaceTracking()
end

-- Seen at once, in a fight too: a plain frame of ours.
ns.OnToggle(function(key)
    if key ~= "trackingSameSize" or not trackFrame then return end
    Shape(trackFrame)
    PlaceTracking()
end)
