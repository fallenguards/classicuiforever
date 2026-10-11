local _, ns = ...
local L = ns.L

-- Buttons on the minimap ring, 1.x tracking-button style, dragged round it with their angle saved: our options button
-- (gryphon) here, the addon button collector in MinimapCollector.lua.

local SIZE = 32
local FULL = { 0, 1, 0, 1 }

-- Ring centre is at (20, 19) on its 64px sheet; the face's edge hides under the ring.
local RING_SIZE = 54
local CX, CY = RING_SIZE * 20 / 64, -RING_SIZE * 19 / 64
local FACE = 24

-- 8-value coords: centre (u, v), half span, turned counter-clockwise by degrees.
local function Turned(u, v, half, degrees)
    local c, s = math.cos(math.rad(degrees)) * half, math.sin(math.rad(degrees)) * half
    return { u - c + s, v - s - c, u - c - s, v - s + c, u + c + s, v + s - c, u + c - s, v + s + c }
end

-- The art's gryphon sits low and leans forward: centre on its body, zoom in, stand it upright.
local GRYPHON = { layer = "ARTWORK", coords = Turned(0.578, 0.586, 0.436, 22), w = FACE, h = FACE,
    point = "CENTER", relPoint = "TOPLEFT", x = CX, y = CY }
-- An icon file's face, cropped past its own border.
local ICON_FACE = { layer = "ARTWORK", coords = { 0.08, 0.92, 0.08, 0.92 }, w = FACE, h = FACE,
    point = "CENTER", relPoint = "TOPLEFT", x = CX, y = CY }
ns.RING_ICON_FACE = ICON_FACE
-- Black disc under it: the zoomed art's own disc no longer reaches the ring everywhere.
local BACK = { layer = "BACKGROUND", w = FACE, h = FACE, point = "CENTER", relPoint = "TOPLEFT", x = CX, y = CY,
    vertex = { 0, 0, 0 } }
local RING = { layer = "OVERLAY", w = RING_SIZE, h = RING_SIZE, point = "TOPLEFT" }
local HL_RING = { coords = FULL, fill = true, add = true, states = { "Highlight" } }

local rings = {}

-- The micro icons are the map's own pieces: off the map's own children, where button gatherers look for addon buttons.
local pieceHost
local function Home(ring)
    if not ring.piece then return Minimap end
    if not pieceHost then
        pieceHost = CreateFrame("Frame", nil, Minimap)
        pieceHost:SetAllPoints(Minimap)
    end
    return pieceHost
end

local function Radius()
    local map = Minimap
    return (map and map:GetWidth() or 140) / 2 + 5
end

-- Ring spots other pieces stand on by default (mail, day and night, tracking spell, tracking glass, zoom out, zoom in),
-- the arcs the zone bar and the clock cover, and how far apart two 32 px buttons must be, all in degrees.
local TAKEN = { 12, 34, 159, 186, 302, 322 }
local COVERED = { { 60, 120 }, { 246, 294 } }
local APART = 25

local function Angle(ring)
    return ns.db and ns.db[ring.angleKey] or ring.freeAngle or ring.angle
end

local function Apart(a, b)
    local d = math.abs(a - b) % 360
    return d > 180 and 360 - d or d
end

-- A button in the addon bag leaves its ring spot empty.
local function OnMap(ring)
    return not ring.button or ring.button:GetParent() == Home(ring)
end

-- How far the nearest piece or button is from a spot; nil on a covered arc.
local function Room(degrees, self)
    for _, arc in ipairs(COVERED) do
        if degrees >= arc[1] and degrees <= arc[2] then return nil end
    end
    local room = 360
    for _, taken in ipairs(TAKEN) do room = math.min(room, Apart(degrees, taken)) end
    for _, other in ipairs(rings) do
        if other ~= self and other.active and OnMap(other) then room = math.min(room, Apart(degrees, Angle(other))) end
    end
    return room
end

-- A button with no place of its own (spec.free): the nearest clear spot to its own, kept while it stays clear; on a full
-- ring the roomiest spot.
local function FreeSpot(ring)
    if not ring.free or (ns.db and ns.db[ring.angleKey]) then return end
    if ring.freeAngle and (Room(ring.freeAngle, ring) or 0) >= APART then return end
    local best, bestRoom = ring.angle, -1
    for step = 0, 180 do
        for sign = 1, -1, -2 do
            local degrees = (ring.angle + sign * step) % 360
            local room = Room(degrees, ring)
            if room and room >= APART then
                ring.freeAngle = degrees
                return
            elseif room and room > bestRoom then
                best, bestRoom = degrees, room
            end
        end
    end
    ring.freeAngle = best
end

-- Only we move these buttons, so an unchanged angle, radius and size means no move.
-- Not while collected into the addon button bag (another parent). Offsets count in the button's own size (edit mode's).
local function Position(ring)
    local button = ring.button
    if not button or not Minimap or button:GetParent() ~= Home(ring) then return end
    local degrees = Angle(ring)
    local r = Radius()
    local k = button:GetEffectiveScale() / Minimap:GetEffectiveScale()
    if degrees == ring.placedAngle and r == ring.placedRadius and k == ring.placedScale then return end
    ring.placedAngle, ring.placedRadius, ring.placedScale = degrees, r, k
    ns.RingPoint(button, degrees, r, k)
end

local function PositionAll()
    for i = 1, #rings do
        if rings[i].active then Position(rings[i]) end
    end
end

-- Where a ring button sits, or would while it is off (never built), by its edit mode entry key: its centre in
-- UIParent units.
function ns.RingButtonSpot(key)
    if not Minimap then return nil end
    for i = 1, #rings do
        local ring = rings[i]
        if ring.key == key then
            local mx, my = Minimap:GetCenter()
            if not mx or ns.AnySecret(mx, my) then return nil end
            local a, r = math.rad(Angle(ring)), Radius()
            local k = Minimap:GetEffectiveScale() / UIParent:GetEffectiveScale()
            return (mx + math.cos(a) * r) * k, (my + math.sin(a) * r) * k
        end
    end
end

-- Edit mode's drag, reset and size steps, by its entry key (ns.LayPiece).
function ns.PlaceRingButton(key)
    for i = 1, #rings do
        if rings[i].key == key and rings[i].active then Position(rings[i]) end
    end
end

-- Last cursor and map per ring, to skip idle frames.
local function OnDragUpdate(job)
    local ring = job.ring
    local mx, my = Minimap:GetCenter()
    local scale = Minimap:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    if cx == ring.dragX and cy == ring.dragY and mx == ring.dragMX and my == ring.dragMY and scale == ring.dragScale then return end
    ring.dragX, ring.dragY, ring.dragMX, ring.dragMY, ring.dragScale = cx, cy, mx, my, scale
    ns.db[ring.angleKey] = ns.MinimapCursorAngle()
    Position(ring)
end

-- HookMethod dedups per frame and method, so this Layout hook is dropped when Minimap.lua
-- hooked first; the SetSize hook, fired by that Layout, does the repositioning.
local hooked = false
local function HookMap()
    if hooked then return end
    hooked = true
    if MinimapCluster then ns.HookMethod(MinimapCluster, "Layout", PositionAll) end
    ns.HookMethod(Minimap, "SetSize", PositionAll)
end

-- A ring button's look on a 32 square frame: the black disc, the face, the ring. Returns the face.
function ns.RingLook(frame, face, name)
    ns.DressNew(frame, "portraitMask", BACK)
    -- Round mask first: RoundIcon sets its own crop, which the dress then replaces.
    local icon = frame:CreateTexture(name)
    ns.RoundIcon(icon)
    face(icon)
    ns.MinimapButtonBorder(ns.DressNew(frame, "trackingBorder", RING))
    return icon
end
ns.RING_HIGHLIGHT = HL_RING

local function Build(ring)
    local b = CreateFrame("Button", ring.name, Home(ring))
    b:SetSize(SIZE, SIZE)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel((Minimap:GetFrameLevel() or 2) + 8)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    -- Pure child watcher, asleep until a drag starts.
    local dragJob = ns.Sched.OnFrame(CreateFrame("Frame", nil, b),
        { name = ring.name .. ".drag", every = 0, awake = false, fn = OnDragUpdate })
    dragJob.ring = ring
    b:SetMovable(true)
    -- Named: a gatherer that takes the button shows its <name>Icon.
    b.icon = ns.RingLook(b, ring.face, ring.name .. "Icon")
    ns.DressStates(b, nil, nil, nil, "zoomHighlight", HL_RING)
    b:SetScript("OnClick", ring.onClick)
    -- Shift, as other addons' minimap buttons move; a pad over the button hands its drag here (UI/SecurePad.lua), and
    -- follows the button only out of a fight.
    b:SetScript("OnDragStart", function()
        if not IsShiftKeyDown() or InCombatLockdown() then return end
        ring.dragX = nil
        dragJob:Wake()
    end)
    b:SetScript("OnDragStop", function()
        dragJob:Sleep()
        Position(ring)
    end)
    ns.AttachTip(b, ring.tip)
    return b
end

-- spec: { name, key (its edit mode entry), angleKey, angle (default degrees), free (takes the nearest clear spot), show
-- (its on hover id), piece (the map's own, not an addon button), face(texture), onClick(button, mouse), tip }; returns
-- show and hide.
function ns.RingButton(spec)
    rings[#rings + 1] = spec
    local function Show()
        FreeSpot(spec)
        spec.active = true
        if not Minimap then return end
        if not spec.button then
            spec.button = Build(spec)
            -- Its edit mode size, now that the named frame exists.
            if ns.PlaceSavedWindows then ns.PlaceSavedWindows() end
        end
        Position(spec)
        spec.button:Show()
        ns.MinimapShow(spec.button, spec.show)
        HookMap()
    end
    local function Hide()
        spec.active = false
        if spec.button then
            ns.MinimapShow(spec.button, nil)
            spec.button:Hide()
        end
    end
    -- Shown or on hover picked in the options.
    ns.OnToggle(function(key)
        if spec.active and (key == "show" .. spec.show or key == "hover" .. spec.show) then Show() end
    end)
    return Show, Hide
end

local ShowOptions, HideOptions = ns.RingButton({
    name = "ForeverClassicUIMinimapButton",
    key = "minimapOptionsButton",
    angleKey = "minimapButtonAngle",
    angle = 213,   -- clear of the tracking glass (186) under the tracking spell
    show = "OptionsButton",
    face = function(icon) ns.Dress(icon, "gryphonIcon", GRYPHON) end,
    onClick = function(_, mouse)
        if mouse == "RightButton" then
            if ns.ShowWelcome then ns.ShowWelcome() end
        else
            ns.OpenOptions()
        end
    end,
    tip = { anchor = "ANCHOR_LEFT", text = L["MAP_CLASSICUI_FOREVER"], r = 1, g = 1, b = 1, lines = {
        { L["MAP_LEFT_CLICK_OPTIONS"], 0.8, 0.8, 0.8 },
        { L["MAP_RIGHT_CLICK_WELCOME_NOTE"], 0.8, 0.8, 0.8 },
        { L["MAP_DRAG_TO_MOVE_AROUND_THE"], 0.8, 0.8, 0.8 },
    } },
})

ns.RegisterModule("minimapButton", { apply = ShowOptions, restore = HideOptions })

-- The options button's default spot left the tracking glass (200 to 213): one never dragged follows, in the account and
-- every profile. Runs before the defaults fill.
function ns.FreeOptionsButton()
    local db = ns.db
    if db.minimapButtonAngle == 200 then db.minimapButtonAngle = nil end
    for _, shot in pairs(type(db.profiles) == "table" and db.profiles or {}) do
        if type(shot) == "table" and shot.minimapButtonAngle == 200 then shot.minimapButtonAngle = nil end
    end
    db.dbVersion = 12
end
