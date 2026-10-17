local _, ns = ...

-- Era's threat percent over the target frame (its TargetFrameNumericalThreat), as our own box, and the same over the
-- focus frame: the game shows its own only with threatShowNumeric on, a setting no code of ours may write at load.
-- The game's own fades on our classic frames, under ours or with the option off (it showed with the option off).

local UF = ns.UF
local IsSecret = ns.IsSecret
local UnitDetailedThreatSituation, UnitThreatPercentageOfLead = UnitDetailedThreatSituation, UnitThreatPercentageOfLead
local GetThreatStatusColor = GetThreatStatusColor

-- Era's numbers: a 49 x 18 box, its colored fill 37 x 14 and the label 3 and 4 down from the box's top; the box where
-- TargetFrame.lua puts the game's own.
local BOX_W, BOX_H, FILL_W, FILL_H, FILL_Y, TEXT_Y = 49, 18, 37, 14, -3, -4
local BOX_X, BOX_Y = -30, -26
local BORDER_COORDS = { 0, 0.765625, 0, 0.5625 }
local FRAMES = { target = "TargetFrame", focus = "FocusFrame" }
-- The mobs' threat lists and the player's standing on them; a new target or focus, the fight's end, a group or zone change.
local UNIT_EVENTS = { "UNIT_THREAT_LIST_UPDATE", "UNIT_THREAT_SITUATION_UPDATE" }
local EVENTS = { "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "PLAYER_REGEN_ENABLED", "GROUP_ROSTER_UPDATE",
    "PLAYER_ENTERING_WORLD" }
local boxes, live, shown, faded = {}, {}, {}, {}
local driver, focusDriver

-- Over a thick bar the name steps up while the box shows, its foot 1 over the box's top (UnitFrameCore.lua).
UF.THREAT_BOX_TOP = BOX_Y + BOX_H
function UF.ThreatShown(unit) return shown[unit] == true end

local function GameNumber(frame)
    return ns.Path(frame, "TargetFrameContent", "TargetFrameContentContextual", "NumericalThreat")
end

local function Build(frame)
    local box = ns.NewFrame("Frame", nil, frame)
    box:SetSize(BOX_W, BOX_H)
    box:SetPoint("BOTTOM", frame, "TOP", BOX_X, BOX_Y)
    box.fill = box:CreateTexture(nil, "BACKGROUND")
    ns.SetTex(box.fill, "statusBar")
    box.fill:SetSize(FILL_W, FILL_H)
    box.fill:SetPoint("TOP", box, "TOP", 0, FILL_Y)
    box.border = box:CreateTexture(nil, "ARTWORK")
    ns.SetTex(box.border, "threatBorder")
    box.border:SetTexCoord(unpack(BORDER_COORDS))
    box.border:SetAllPoints(box)
    box.text = box:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    box.text:SetPoint("TOP", box, "TOP", 0, TEXT_Y)
    box:Hide()
    return box
end

-- Only in a group: in a party or raid, or inside a dungeon, raid or other instance.
local function Allowed()
    return not ns.db.threatNumberGrouped or IsInGroup() or (IsInInstance())
end

-- The game's own reading (UnitFrame_UpdateThreatIndicator): your share, or your lead over the next while tanking.
local function UpdateBox(unit)
    local box = boxes[unit]
    if not box then return end
    local show = false
    if live[unit] and Allowed() and UnitExists(unit) and not UnitIsDead(unit) and UnitClassification(unit) ~= "minus" then
        local tanking, status, _, raw = UnitDetailedThreatSituation("player", unit)
        local value = raw
        if tanking and not IsSecret(tanking) then value = UnitThreatPercentageOfLead("player", unit) end
        if value and status and not IsSecret(value) and not IsSecret(status) and value ~= 0 then
            box.text:SetFormattedText("%1.0f%%", value)
            box.fill:SetVertexColor(GetThreatStatusColor(status))
            show = true
        end
    end
    ns.SetShownIf(box, show)
    if shown[unit] ~= show then
        shown[unit] = show
        UF.PlaceTargetName(unit)
    end
end

local function Update()
    UpdateBox("target")
    UpdateBox("focus")
end

-- Each with its classic frame and the option; called by the unit frame module and the option's switch.
function ns.ThreatNumberSync()
    local any = false
    for unit, name in pairs(FRAMES) do
        local frame = _G[name]
        local classic = frame ~= nil and UF.active and UF.On(unit)
        local on = classic and ns.db.threatNumber ~= false
        if on and not boxes[unit] then boxes[unit] = Build(frame) end
        live[unit] = on
        any = any or on
        local game = frame and GameNumber(frame)
        -- The game's number back only with the frame handed back, where we faded it.
        if game and (classic or faded[unit]) then
            faded[unit] = classic or nil
            ns.SetAlphaIf(game, classic and 0 or 1)
        end
    end
    if any and not driver then
        driver = ns.EventFrame(EVENTS, Update)
        focusDriver = ns.EventFrame(UNIT_EVENTS, Update, "focus")
    end
    if driver then
        driver:UnregisterAllEvents()
        focusDriver:UnregisterAllEvents()
        if any then
            ns.RegisterEvents(driver, EVENTS)
            ns.RegisterEvents(driver, UNIT_EVENTS, "player", "target")
            ns.RegisterEvents(focusDriver, UNIT_EVENTS, "focus")
        end
    end
    Update()
end

-- The options pass waits out a fight, where threat shows: the switch answers at once.
ns.OnToggle(function(key)
    if key == "threatNumber" or key == "threatNumberGrouped" then ns.ThreatNumberSync() end
end)
