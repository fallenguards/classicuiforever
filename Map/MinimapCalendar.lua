local _, ns = ...

-- Forever's calendar button: on the ring under the day/night, hidden behind it, or a square by the zone name.
-- Moved and sized as the Calendar entry of ClassicUI Forever Windows (UI/WindowHandles.lua), which holds its home.

local MM = ns.MM

local KEY = "calendar"
local HOME = "ForeverClassicUICalendarHome"
local RING_SCALE = 0.7 -- under the day/night, inside the cluster's edge
local RING = 40
local SQUARE_W, SQUARE_H = 21, 19 -- the client's ui-hud-calendar atlases
local RING_R = 73        -- ring spot: its middle's distance from the map's middle
local RING_ANGLE = 8     -- ring spot: default angle under the day/night (degrees, 0 = right, + counterclockwise)
local RING_ANGLE_BARE = 40 -- ring spot without a day/night frame: the client's own corner

local home, square
local squareState = "up"

local function Spot()
    local db = ns.db
    if not db or MM.ShowState("MinimapCalendar") == "hide" then return nil end
    local diel = MinimapCluster and MinimapCluster.DielFrame
    if db.calendarBehind and diel then return "behind" end
    if db.calendarZone then return "zone" end
    return "ring"
end

-- Dragged to a place of its own; the ring spot counts an angle instead.
local function Placed() return ns.WindowPlaced and ns.WindowPlaced(KEY) and Spot() ~= "ring" end

-- Mail steps down the ring only while the calendar stands in its ring spot there.
function MM.CalendarUnderDiel()
    return MinimapCluster and MinimapCluster.DielFrame and Spot() == "ring" and ns.db.calendarAngle == nil and true or false
end

-- Edit mode's reset and size steps: laid at the picked spot again.
function ns.LayPiece(key, anyway)
    if (key == KEY or (MM.PIECE_KEYS and MM.PIECE_KEYS[key])) and MM.Relayout then MM.Relayout() end
    if ns.PlaceRingButton then ns.PlaceRingButton(key) end
    if ns.LayGryphon then ns.LayGryphon(key, anyway) end
    if ns.LayQuestWatch then ns.LayQuestWatch(key) end
    if ns.LayTrackingIcon then ns.LayTrackingIcon(key) end
end

-- Picking a spot (options or its edit mode dropdown) puts it there: a place dragged in edit mode goes.
ns.OnToggle(function(key)
    local group = ns.TOGGLE_RADIO and ns.TOGGLE_RADIO[key]
    if not group or group ~= ns.TOGGLE_RADIO.calendarRing then return end
    local places = ns.DbTable("windowPos")
    if places[KEY] == nil then return end
    places[KEY] = nil
    if MM.Relayout then MM.Relayout() end
end)

---------------------------------------------------------------- the square

local function Today()
    local now = C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime and C_DateAndTime.GetCurrentCalendarTime()
    return now and now.monthDay or 1
end

function MM.SquareDay()
    if not (square and square:IsShown()) then return end
    square.tex:SetAtlas("ui-hud-calendar-" .. Today() .. "-" .. squareState)
end

local function SquareState(state)
    squareState = state
    MM.SquareDay()
end

-- Behind day and night, the calendar shows in the day/night's place while the mouse is on it (#202); leaving puts the
-- day/night back whatever the spot.
local function BehindHover(button, over)
    local behind = Spot() == "behind"
    if MM.tod then ns.FadeTo(MM.tod, behind and over and 0 or 1) end
    if behind then ns.FadeTo(button, over and 1 or 0) end
end

-- The client's button, unseen over the square, takes the mouse; the square follows its states.
local function WatchButton(button)
    if not ns.Once(button, "calendarWatch") then return end
    button:HookScript("OnEnter", function(self)
        SquareState("mouseover")
        BehindHover(self, true)
    end)
    button:HookScript("OnLeave", function(self)
        SquareState("up")
        BehindHover(self, false)
    end)
    button:HookScript("OnMouseDown", function() SquareState("down") end)
    button:HookScript("OnMouseUp", function(self) SquareState(self:IsMouseOver() and "mouseover" or "up") end)
end

---------------------------------------------------------------- placing

-- Named: the windows' edit mode places and sizes it by name.
local function Home(cluster)
    if home then return home end
    home = CreateFrame("Frame", HOME, cluster)
    square = CreateFrame("Frame", nil, home)
    square:SetAllPoints(home)
    square.tex = square:CreateTexture(nil, "ARTWORK")
    square.tex:SetAllPoints(square)
    if ns.PlaceSavedWindows then ns.PlaceSavedWindows() end
    return home
end

-- The picked spot's middle, in its parent's units; a place from edit mode is the windows' to set.
local function PlaceHome(box, cluster, map, spot, diel)
    local w, h
    if spot == "zone" then
        w, h = SQUARE_W, SQUARE_H
    else
        local s = diel and RING_SCALE or 1
        w, h = RING * s, RING * s
    end
    box:SetSize(w, h)
    if Placed() then return end
    -- Offsets count in the box's own scale: divided by its edit mode size, it grows round the spot's middle.
    local k = box:GetScale()
    if spot == "zone" then
        -- Where 1.x had the minimap toggle, on the zone name's right end.
        local _, plateY = MM.HeaderOffsets()
        ns.SetPointOnce(box, "CENTER", cluster, "TOPRIGHT", -15 / k, (-13 + plateY) / k)
    else
        local angle = tonumber(ns.db.calendarAngle) or (diel and RING_ANGLE or RING_ANGLE_BARE)
        ns.RingPoint(box, angle, RING_R, box:GetEffectiveScale() / map:GetEffectiveScale())
    end
end

function MM.PlaceCalendar(cluster, map, above)
    local button = GameTimeFrame
    if not button then return end
    local spot = Spot()
    local diel = cluster.DielFrame
    local box = Home(cluster)
    WatchButton(button)
    button:SetShown(spot ~= nil)
    if spot == nil then
        box:Hide()
        return
    end
    ns.SetLevelIf(box, above)
    if spot == "behind" then
        -- Over the day/night, which takes no mouse: the unseen button there opens the calendar, and its edit mode box
        -- sits on the icon.
        -- The icon's own size whatever its edit mode size, which has no say here.
        local w, h = diel:GetSize()
        local k = box:GetScale()
        box:SetSize(w / k, h / k)
        ns.SetPointOnce(box, "CENTER", diel, "CENTER", 0, 0)
    else
        PlaceHome(box, cluster, map, spot, diel)
    end
    ns.MinimapShow(box, "MinimapCalendar")
    -- In the home, so the edit mode size takes it too.
    button:SetParent(box)
    button:SetFrameLevel(above + 1)
    if spot == "behind" then
        square:Hide()
        button:SetScale(1)
        button:SetSize(box:GetSize())
        button:SetHitRectInsets(0, 0, 0, 0)
        ns.FadeTo(button, 0, nil, true)
    elseif spot == "zone" then
        square:Show()
        button:SetScale(1)
        button:SetSize(SQUARE_W, SQUARE_H)
        button:SetHitRectInsets(0, 0, 0, 0)
        ns.FadeTo(button, 0, nil, true)
        MM.SquareDay()
    else
        square:Hide()
        button:SetScale(diel and RING_SCALE or 1)
        button:SetSize(RING, RING)
        button:SetHitRectInsets(6, 0, 5, 10)
        ns.FadeTo(button, 1, nil, true)
    end
    ns.SetPointOnce(button, "CENTER", box, "CENTER", 0, 0)
end

-- Hide button borders: the calendar page inside its ring, cut round (UI-Calendar-Button's gold line runs 18 out from
-- its middle, 50 across): a share of the button's width, which differs by spot.
local DISC_SHARE = 34 / 50
local disc
function MM.CutCalendarRing(button)
    disc = disc or ns.MinimapDiscMask(button, 1)
    local w = button:GetWidth()
    if w and w > 0 then disc:SetSize(w * DISC_SHARE, w * DISC_SHARE) end
    for _, tex in ipairs({ button:GetNormalTexture(), button:GetPushedTexture(), button:GetHighlightTexture() }) do
        ns.MinimapButtonDisc(tex, disc)
    end
end

function MM.HideCalendar()
    if home then home:Hide() end
    if GameTimeFrame then
        GameTimeFrame:SetParent(Minimap)
        ns.SetAlphaIf(GameTimeFrame, 1)
    end
end
