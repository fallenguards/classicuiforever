local _, ns = ...

-- 1.x combo points: five orbs curving down the right of the target portrait, each glinting as it lights.
-- Our own orbs in the 1.13 shape; the client's (Forever's ComboFrame, retail's under the player frame) are faded.

local POINTS = 5
-- Orb centres on the portrait rim, top right down to just above the level badge.
local RADIUS = 39
local ANGLES = { 50, 32, 14, -4, -22 }   -- 18 degree steps: 12px orbs on a 39px ring just touch
local function OrbCentre(index)
    local a = math.rad(ANGLES[index])
    return RADIUS * math.cos(a), RADIUS * math.sin(a)
end
local SHEET = "comboPoint"
local ORB_BG = { layer = "BACKGROUND", w = 12, h = 16, point = "TOPLEFT", coords = { 0, 0.375, 0, 1 } }
local ORB_FILL = { layer = "ARTWORK", w = 8, h = 16, point = "TOPLEFT", x = 2, coords = { 0.375, 0.5625, 0, 1 }, alpha = 0 }
local ORB_GLOW = { layer = "OVERLAY", w = 14, h = 16, point = "TOPLEFT", y = 4, coords = { 0.5625, 1, 0, 1 }, blend = "ADD", alpha = 0 }
local WORLD_EVENTS = { "PLAYER_TARGET_CHANGED", "PLAYER_ENTERING_WORLD", "UPDATE_SHAPESHIFT_FORM", "COMBO_TARGET_CHANGED" }
local POWER_EVENTS = { "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER" }

local active = false
local frame
local lastPoints = 0

local function Ring()
    return ns.Path(TargetFrame, "TargetFrameContainer", "Portrait") or TargetFrame
end

-- Pinned to the portrait so the arc follows it.
local function PinOrb(orb, index)
    local x, y = OrbCentre(index)
    ns.SetPointOnce(orb, "CENTER", Ring(), "CENTER", x, y)
end

-- Forever's ComboFrame (70291+): five modern orbs it re-lays on every update. Each orb's own alpha it never sets.
local clientTaken = false
local function ClientOrbs(alpha)
    for _, point in ipairs(ComboFrame and ComboFrame.ComboPoints or ns.EMPTY) do ns.SetAlphaIf(point, alpha) end
end

---------------------------------------------------------------- our own

local function Orb(parent)
    local orb = CreateFrame("Frame", nil, parent)
    orb:SetSize(12, 12)
    ns.DressNew(orb, SHEET, ORB_BG)
    orb.lit = ns.DressNew(orb, SHEET, ORB_FILL)
    orb.shine = ns.DressNew(orb, SHEET, ORB_GLOW)
    return orb
end

local function Glint(orb)
    -- Highlight fades in, then the shine flashes over it and fades.
    UIFrameFadeIn(orb.lit, 0.4, orb.lit:GetAlpha(), 1)
    UIFrameFade(orb.shine, {
        mode = "IN", timeToFade = 0.3, startAlpha = 0, endAlpha = 1,
        finishedFunc = function() UIFrameFadeOut(orb.shine, 0.4, 1, 0) end,
    })
end

local function Update()
    if not frame or not active then return end
    local max = ns.Safe(UnitPowerMax("player", Enum.PowerType.ComboPoints), 0)
    -- Forever keeps the points on the target.
    local points = ns.OnForever() and GetComboPoints("player", "target") or UnitPower("player", Enum.PowerType.ComboPoints)
    points = ns.Safe(points, 0)
    if max <= 0 or points <= 0 or not UnitExists("target") or not UnitCanAttack("player", "target") then
        frame:Hide()
        for i = 1, POINTS do
            frame.orbs[i].lit:SetAlpha(0)
            frame.orbs[i].shine:SetAlpha(0)
        end
        lastPoints = 0
        return
    end
    if not frame:IsShown() then
        frame:Show()
        UIFrameFadeIn(frame, 0.3, 0, 1)
    end
    for i = 1, POINTS do
        local orb = frame.orbs[i]
        orb:SetShown(i <= max)
        if i <= points then
            if i > lastPoints then Glint(orb) end
        else
            orb.lit:SetAlpha(0)
            orb.shine:SetAlpha(0)
        end
    end
    lastPoints = points
end

local function Build()
    frame = CreateFrame("Frame", nil, TargetFrame)
    frame:SetSize(64, 64)
    frame:SetPoint("CENTER", Ring(), "CENTER", 0, 0)
    -- A strata over the target frame and its PvP flag, as Era's ComboFrame (MEDIUM, toplevel).
    frame:SetFrameStrata("MEDIUM")
    frame:SetToplevel(true)
    frame.orbs = {}
    for i = 1, POINTS do
        frame.orbs[i] = Orb(frame)
        PinOrb(frame.orbs[i], i)
    end
    frame:Hide()
    ns.RegisterEvents(frame, WORLD_EVENTS)
    ns.RegisterEvents(frame, POWER_EVENTS, "player")
    frame:SetScript("OnEvent", Update)
end

local function Apply()
    active = true
    if not TargetFrame then ns.MissingPiece("TargetFrame") return end
    -- Retail's display under the player frame.
    ns.Fade(ComboPointPlayerFrame)
    ns.Fade(DruidComboPointBarFrame)
    if ComboFrame then
        clientTaken = true
        ClientOrbs(0)
    end
    if not frame then Build() else for i, orb in ipairs(frame.orbs) do PinOrb(orb, i) end end
    Update()
end

local function Restore()
    if not active then return end
    active = false
    if frame then frame:Hide() end
    ns.Unfade(ComboPointPlayerFrame)
    ns.Unfade(DruidComboPointBarFrame)
    if clientTaken then
        clientTaken = false
        ClientOrbs(1)
    end
end

ns.RegisterModule("comboPoints", { apply = Apply, restore = Restore })
