local _, ns = ...

-- The theme on the client's nameplate aura rings (as drawn with the theme off). Watch only: new rings are found after
-- aura updates, in the next frame.

local RING_ATLAS = "UI-HUD-CoolDownManager-IconOverlay"
local LISTS = { "DebuffListFrame", "BuffListFrame", "CrowdControlListFrame" }
local RING_EVENTS = { "UNIT_AURA", "NAME_PLATE_UNIT_ADDED" }

local ringed = setmetatable({}, { __mode = "k" })   -- aura item -> true once its ring is tinted

local function TintRegion(region, item)
    if ringed[item] or not region.GetAtlas or ns.Safe(region:GetAtlas()) ~= RING_ATLAS then return end
    ringed[item] = true
    ns.BronzeTint(region)
end

local function TintItem(item)
    if not ringed[item] then ns.EachRegion(item, TintRegion, item) end
end

local function TintPlate(unitFrame)
    local auras = unitFrame.AurasFrame
    if not auras then return end
    for _, key in ipairs(LISTS) do
        if auras[key] then ns.EachChild(auras[key], TintItem) end
    end
end

-- Plates whose auras changed this frame: the client builds a plate's aura items in its own UNIT_AURA handler, so only
-- those have new rings (#127: every change re-tinted every plate).
local pending = {}   -- nameplate unit -> true

local function TintPending()
    for unit in pairs(pending) do
        pending[unit] = nil
        local unitFrame = ns.NP.LivePlate(unit)
        if unitFrame then TintPlate(unitFrame) end
    end
end

ns.EventFrame(RING_EVENTS, function(_, _, unit)
    if type(unit) == "string" and unit:find("^nameplate") then
        pending[unit] = true
        ns.Sched.NextFrame("namePlates.auraRings", TintPending)
    end
end)
