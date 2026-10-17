local _, ns = ...

-- Classic Era's world map in the header style picked: Classic (WorldMapEraLarge.lua), none (Era's small map) or the
-- game's own. The quest pane in a second hole the art widens across; Map Options at the foot (WorldMapOptions.lua).
-- Size and anchors change inside a snippet, out of combat: from our code the map's refit would run as ours.

local P = ns.panels

-- Classic Era's numbers (Blizzard_WorldMap Vanilla): frame, art pieces, the map's hole, title, close button.
local ERA_W, ERA_H = 610, 438
-- The frame's two sheets, through the theme's copies.
local ART_LEFT_FILE = "Interface\\WorldMap\\UI-WorldMapSmall-Left"
local ART_RIGHT_FILE = "Interface\\WorldMap\\UI-WorldMapSmall-Right"
local ART_X, ART_LEFT_W, ART_RIGHT_W, ART_H = 12, 512, 128, 512
local CANVAS_LEFT, CANVAS_TOP, CANVAS_RIGHT, CANVAS_BOTTOM = 20, 22, 600, 410
local TITLE_Y = -12
-- The X's top right from the right art piece's, and its size.
local MAP_CLOSE_X = -44
local MAP_CLOSE_Y = 5
local MAP_CLOSE_SIZE = 32
local MAXIMIZE_GAP = 10
-- Map Options' box: its bottom right 10 in from the art's right end and 5 up, MoP's spot.
-- Map Options in none style: its box's right edge from the window's right (+ right), its bottom from the bottom (+ up).
local NONE_MAP_OPTIONS_X = -9
local NONE_MAP_OPTIONS_Y = 5
-- Under the picture as Era's (LowerFrameLevel); only the footer's top line, art rows 405 to 412, drawn over it.
local ART_UNDER_MAP = 1
local FOOT_LINE_OVER_MAP = 2
local FOOT_LINE_TOP, FOOT_LINE_BOTTOM = 405, 412
-- Quest pane: its own hole right of the map's; the art widens across it. Rect from the frame's top left.
local QUEST_PANE_X = 607        -- pane's left (+ right)
local QUEST_PANE_Y = 22         -- pane's top, down from the frame's top (+ lower)
local QUEST_PANE_W = 330        -- pane's width (+ wider; the window widens with it)
local QUEST_PANE_H = 390        -- pane's height (+ taller): down to the footer, as the map's picture
-- The quest pane's scroll column moved from the game's spot to meet each frame's border (+ right).
local CLASSIC_SCROLL_COLUMN_X = 7
local NONE_SCROLL_COLUMN_X = 0
local PANE_BAR_SHIFT = { classic = CLASSIC_SCROLL_COLUMN_X, none = NONE_SCROLL_COLUMN_X }
local DIVIDER_X = 598           -- divider between map and pane: its left, its rim on the map's right end (+ right)
-- The large map's one divider (UI-WorldMap-Middle3, columns 190 to 199: a rim each side), straight, rows 20 to 412.
local DIVIDER_FILE = "Interface\\WorldMap\\UI-WorldMap-Middle3"
local DIVIDER_L, DIVIDER_R, DIVIDER_W = 190 / 256, 199 / 256, 9
-- Era art columns and rows: the right piece's column a picture ends at (the map's at 600) and its art's end; the
-- divider's rows; the left piece's first clear column.
local PICTURE_RIGHT_COL, ART_RIGHT_COL = 76, 86
local EDGE_TOP, EDGE_BOTTOM = 20, 412
local FILL_MIN_COL = 17
-- Forever's own small map and its picture's place (its XML: 2 in, under the 67 tall title row, 3 in from the right
-- past the quest pane, 2 up), restored when its layout is wanted.
local FOREVER_W, FOREVER_H = 702, 534
local FOREVER_LEFT, FOREVER_TOP, FOREVER_RIGHT, FOREVER_BOTTOM = 2, 67, 3, 2
-- Its quest pane (its AttachQuestLog): width, then 3 in from the right, 25 down, 3 up.
local FOREVER_PANE_W, FOREVER_PANE_RIGHT, FOREVER_PANE_TOP, FOREVER_PANE_BOTTOM = 333, 3, 25, 3
-- Its quest details: a fixed 502 tall under the pane's top (1 down), fitted to Era's shorter pane; the text in it
-- 5 in, 43 down, 430 tall.
local FOREVER_DETAILS_H, DETAILS_TOP = 502, 1
local FOREVER_DETAILS_TEXT_X, FOREVER_DETAILS_TEXT_Y, FOREVER_DETAILS_TEXT_H = 5, -43, 430
-- Era layout: the details text, its scroll bar, Back and the parchment up into the header band's room (+ up).
local DETAILS_LIFT = 14

local EXTRAS = { "NavBar", "WorldMapTrackingPinButton" }

local layout, art, title
local hidden = {}          -- client piece -> true while we hold it hidden
local eraDressed
local titleFor             -- the map id the title was written for

-- The map picture anchors from its parent, the map frame: a snippet's anchor target must be "$parent" or protected.
local LAY = [[
    local map, canvas = self:GetFrameRef("map"), self:GetFrameRef("canvas")
    local w = self:GetAttribute("w")
    if w then
        map:SetWidth(w)
        map:SetHeight(self:GetAttribute("h"))
    end
    canvas:ClearAllPoints()
    canvas:SetPoint("TOPLEFT", "$parent", "TOPLEFT", self:GetAttribute("l"), self:GetAttribute("t"))
    canvas:SetPoint("BOTTOMRIGHT", "$parent", self:GetAttribute("rp"), self:GetAttribute("r"), self:GetAttribute("b"))
    local pane = self:GetFrameRef("pane")
    if pane then
        pane:ClearAllPoints()
        pane:SetPoint(self:GetAttribute("qp"), "$parent", self:GetAttribute("qp"), self:GetAttribute("qx1"),
            self:GetAttribute("qy1"))
        pane:SetPoint("BOTTOMRIGHT", "$parent", self:GetAttribute("qr"), self:GetAttribute("qx2"), self:GetAttribute("qy2"))
    end
    local details = self:GetFrameRef("details")
    if details then details:SetHeight(self:GetAttribute("dh")) end
    local text = self:GetFrameRef("detailsText")
    if text then
        text:ClearAllPoints()
        text:SetPoint("TOPLEFT", "$parent", "TOPLEFT", self:GetAttribute("dtx"), self:GetAttribute("dty"))
        text:SetHeight(self:GetAttribute("dth"))
    end
]]

-- The client fits the picture to its box only as it opens: hidden and shown here, its own open refits it.
local REFIT = [[
    local map = self:GetFrameRef("map")
    if map:IsShown() then
        map:Hide(true)
        map:Show(true)
    end
]]

local function Map() return WorldMapFrame end

-- "classic", "none" or "forever" (Map navigation bar in the options).
local function NavStyle()
    local db = ns.db
    if db.mapNavBar == true then return "forever" end
    if db.mapNavNone == true then return "none" end
    return "classic"
end

-- The header style the map wears now, nil for the game's own.
local function EraStyle()
    local style = Map() and ns.ModuleInForce("worldMap") and NavStyle()
    if style and style ~= "forever" then return style end
end

-- Maximized, an Era style keeps its own layout scaled up to the screen as the game's fills it (its height, 30 short of
-- its width); the game holds it by its top over its black backdrop. Our window manager wears the scale.
local FULL_SIDE_MARGIN = 30
local fullScale
local function Fill(k)
    if k == fullScale then return end
    local was = fullScale
    fullScale = k
    ns.PlaceSavedWindows()
    -- Restored: the game placed it while it still wore the big scale.
    local map = Map()
    if was and not k and not map:IsMaximized() and not ns.WindowPlaced("map") then ns.GameSpot(map) end
end
function ns.FullMapScale() return fullScale end

-- Windowed, the header style (Era's full screen sheets, 768 tall) at the game's own map height: beside the other
-- styles, not the screen's whole height. A size the player gives the map stands in for it.
local windowedScale
local function Windowed(k)
    if k == windowedScale then return end
    windowedScale = k
    ns.PlaceSavedWindows()
end
function ns.MapWindowedScale() return windowedScale end
local function WindowedScale()
    local _, h = ns.MapLarge.Size(nil)
    return (Map().minimizedHeight or FOREVER_H) / h
end

local function FullScale(t)
    local screenW, screenH = UIParent:GetSize()
    return math.min(screenH / t.h, (screenW - FULL_SIDE_MARGIN) / t.w)
end

local function PaneShown()
    local pane = Map().QuestLog
    return pane and pane:IsShown() and true or false
end

local function PaneW() return PaneShown() and QUEST_PANE_W or nil end

local function Layout()
    if layout then return layout end
    local map = Map()
    layout = CreateFrame("Frame", nil, UIParent, "SecureHandlerBaseTemplate")
    layout:SetFrameRef("map", map)
    layout:SetFrameRef("canvas", map.ScrollContainer)
    if map.QuestLog then layout:SetFrameRef("pane", map.QuestLog) end
    local details = map.QuestLog and map.QuestLog.DetailsFrame
    if details then layout:SetFrameRef("details", details) end
    if details and details.ScrollFrame then layout:SetFrameRef("detailsText", details.ScrollFrame) end
    return layout
end

-- The right art piece's left and the window's width with the pane open: its hole ends at the pane's right.
local function PaneArtX() return QUEST_PANE_X + QUEST_PANE_W - PICTURE_RIGHT_COL end
local function PaneWindowW() return PaneArtX() + ART_RIGHT_COL end

-- The quest details fitted to a pane this tall (Era layout: lifted into the header band's room).
local function Details(t, paneH)
    t.dh = paneH - DETAILS_TOP
    t.dtx, t.dty = FOREVER_DETAILS_TEXT_X, FOREVER_DETAILS_TEXT_Y + DETAILS_LIFT
    t.dth = FOREVER_DETAILS_TEXT_H - (FOREVER_DETAILS_H - t.dh) + DETAILS_LIFT
    return t
end

-- The map picture's two anchors (from the map frame's top left, then its given corner), the quest pane's (its first
-- corner from the same corner of the frame, its bottom right from qr) and the frame's size. style nil: the game's.
local function Target(style)
    local map = Map()
    if style == "classic" then
        local LM = ns.MapLarge
        local l, t, r, b = LM.Picture()
        local x1, y1, x2, y2 = LM.Pane(QUEST_PANE_W)
        local w, h = LM.Size(PaneW())
        return Details({ l = l, t = -t, rp = "TOPLEFT", r = r, b = -b, qp = "TOPLEFT", qx1 = x1, qy1 = -y1,
            qr = "TOPLEFT", qx2 = x2, qy2 = -y2, w = w, h = h }, y2 - y1)
    end
    if style then
        return Details({ l = CANVAS_LEFT, t = -CANVAS_TOP, rp = "TOPLEFT", r = CANVAS_RIGHT, b = -CANVAS_BOTTOM,
            qp = "TOPLEFT", qx1 = QUEST_PANE_X, qy1 = -QUEST_PANE_Y,
            qr = "TOPLEFT", qx2 = QUEST_PANE_X + QUEST_PANE_W, qy2 = -(QUEST_PANE_Y + QUEST_PANE_H),
            w = PaneShown() and PaneWindowW() or ERA_W, h = ERA_H }, QUEST_PANE_H)
    end
    local pane = PaneShown() and (map.questLogWidth or FOREVER_PANE_W) or 0
    local t = { l = FOREVER_LEFT, t = -FOREVER_TOP, rp = "BOTTOMRIGHT", r = -(FOREVER_RIGHT + pane), b = FOREVER_BOTTOM,
        qp = "TOPRIGHT", qx1 = -FOREVER_PANE_RIGHT, qy1 = -FOREVER_PANE_TOP,
        qr = "BOTTOMRIGHT", qx2 = -FOREVER_PANE_RIGHT, qy2 = FOREVER_PANE_BOTTOM, dh = FOREVER_DETAILS_H,
        dtx = FOREVER_DETAILS_TEXT_X, dty = FOREVER_DETAILS_TEXT_Y, dth = FOREVER_DETAILS_TEXT_H }
    if not map:IsMaximized() then
        local w = map.minimizedWidth or FOREVER_W
        t.w, t.h = w + pane, map.minimizedHeight or FOREVER_H
        -- The picture's right from the window's left: the game widens the window for the pane before our next pass,
        -- and fits the picture to its box at once; a box tied to the right edge took the pane's width for that fit.
        t.rp, t.r = "BOTTOMLEFT", w - FOREVER_RIGHT
    end
    return t
end

local function Near(a, b) return a and math.abs(a - b) < 0.5 end

local function PointIs(region, i, point, rel, relPoint, x, y)
    local p, r, rp, px, py = region:GetPoint(i)
    return p == point and r == rel and rp == relPoint and Near(px, x) and Near(py, y)
end

-- The picture's box alone: a fight leaves it as laid, while the game may re-size the frame as it opens.
local function PictureLaid(t)
    local map = Map()
    local canvas = map.ScrollContainer
    return canvas:GetNumPoints() == 2 and PointIs(canvas, 1, "TOPLEFT", map, "TOPLEFT", t.l, t.t)
        and PointIs(canvas, 2, "BOTTOMRIGHT", map, t.rp, t.r, t.b)
end

local function Laid(t)
    local map = Map()
    if t.w and not (Near(map:GetWidth(), t.w) and Near(map:GetHeight(), t.h)) then return false end
    local pane = map.QuestLog
    local details = pane and pane.DetailsFrame
    if details and not Near(details:GetHeight(), t.dh) then return false end
    local text = details and details.ScrollFrame
    if text and not (Near(text:GetHeight(), t.dth) and text:GetNumPoints() == 1
        and PointIs(text, 1, "TOPLEFT", details, "TOPLEFT", t.dtx, t.dty)) then
        return false
    end
    if pane and not (pane:GetNumPoints() == 2 and PointIs(pane, 1, t.qp, map, t.qp, t.qx1, t.qy1)
        and PointIs(pane, 2, "BOTTOMRIGHT", map, t.qr, t.qx2, t.qy2)) then
        return false
    end
    return PictureLaid(t)
end

local PANE_KEYS = { "qp", "qx1", "qy1", "qr", "qx2", "qy2", "dh", "dtx", "dty", "dth" }
local layFailed   -- a refused snippet stops the layout for the session, reported once
local laidAt      -- when a lay last moved the picture's box; its fit is checked a frame later
local function Lay(t)
    if layFailed or InCombatLockdown() or Laid(t) then return end
    laidAt = GetTime()
    local lay = Layout()
    lay:SetAttribute("w", t.w)
    lay:SetAttribute("h", t.h)
    lay:SetAttribute("l", t.l)
    lay:SetAttribute("t", t.t)
    lay:SetAttribute("rp", t.rp)
    lay:SetAttribute("r", t.r)
    lay:SetAttribute("b", t.b)
    for _, key in ipairs(PANE_KEYS) do lay:SetAttribute(key, t[key]) end
    local ok, err = pcall(lay.Execute, lay, LAY)
    if not ok then
        layFailed = true
        geterrorhandler()("world map layout: " .. tostring(err))
    end
end

-- The client's fit (its base scale) against the box the picture has now.
local function Fitted()
    local map = Map()
    local canvas = map.ScrollContainer
    local id = map:GetMapID()
    local layers = id and C_Map.GetMapArtLayers(id)
    local layer = layers and layers[1]
    if not (layer and canvas.baseScale) then return true end
    local want = math.min(canvas:GetWidth() / layer.layerWidth, canvas:GetHeight() / layer.layerHeight)
    return math.abs(canvas.baseScale - want) < 0.001
end

-- Once per lay, out of combat. Never with the gamepad on: the hide drops the map from its focus, and the show from a
-- snippet never gives it back (nothing selected until Start). The box is laid while the map is shut instead.
local function Refit()
    if not laidAt or laidAt == GetTime() or layFailed or InCombatLockdown() then return end
    laidAt = nil
    if ns.GamepadUI() or not Map():IsShown() or Fitted() then return end
    local ok, err = pcall(Layout().Execute, Layout(), REFIT)
    if not ok then geterrorhandler()("world map refit: " .. tostring(err)) end
end

local function Art()
    if art then return art end
    local map = Map()
    art = ns.NewFrame("Frame", nil, map)
    art:SetSize(ERA_W, ERA_H)
    art:SetPoint("TOPLEFT", map, "TOPLEFT", 0, 0)
    art:SetFrameLevel(math.max(0, map.ScrollContainer:GetFrameLevel() - ART_UNDER_MAP))
    -- The footer's top line over the picture (the client's tiled backing fills its box), under its pins (2000 up).
    local foot = ns.NewFrame("Frame", nil, art)
    foot:SetAllPoints(art)
    foot:SetFrameLevel(map.ScrollContainer:GetFrameLevel() + FOOT_LINE_OVER_MAP)
    local footRows = FOOT_LINE_BOTTOM - FOOT_LINE_TOP
    local footRun = ART_X + ART_LEFT_W - CANVAS_LEFT
    for i, run in ipairs({ { CANVAS_LEFT, footRun }, { CANVAS_LEFT + footRun, CANVAS_RIGHT - CANVAS_LEFT - footRun } }) do
        local line = foot:CreateTexture(nil, "ARTWORK")
        ns.SetFile(line, ART_LEFT_FILE)
        line:SetSize(run[2], footRows)
        line:SetTexCoord((ART_LEFT_W - run[2]) / ART_LEFT_W, 1, FOOT_LINE_TOP / ART_H, FOOT_LINE_BOTTOM / ART_H)
        line:SetPoint("TOPLEFT", art, "TOPLEFT", run[1], -FOOT_LINE_TOP)
        foot[i] = line
    end
    local left = art:CreateTexture(nil, "ARTWORK")
    ns.SetFile(left, ART_LEFT_FILE)
    left:SetSize(ART_LEFT_W, ART_H)
    left:SetPoint("TOPLEFT", art, "TOPLEFT", ART_X, 0)
    local right = art:CreateTexture(nil, "ARTWORK")
    ns.SetFile(right, ART_RIGHT_FILE)
    right:SetSize(ART_RIGHT_W, ART_H)
    art.right = right
    -- Pane open: the left piece's end repeated up to the right piece, one divider, dark behind.
    art.fill = art:CreateTexture(nil, "ARTWORK")
    ns.SetFile(art.fill, ART_LEFT_FILE)
    art.divider = art:CreateTexture(nil, "ARTWORK", nil, 1)
    ns.SetFile(art.divider, DIVIDER_FILE)
    art.divider:SetSize(DIVIDER_W, EDGE_BOTTOM - EDGE_TOP)
    art.divider:SetTexCoord(DIVIDER_L, DIVIDER_R, 0, 1)
    art.divider:SetPoint("TOPLEFT", art, "TOPLEFT", DIVIDER_X, -EDGE_TOP)
    art.paneBack = art:CreateTexture(nil, "BACKGROUND")
    art.paneBack:SetColorTexture(0, 0, 0, 1)
    art.paneBack:SetPoint("TOPLEFT", art.divider, "TOPLEFT", 0, 0)
    art.paneBack:SetPoint("BOTTOMRIGHT", right, "TOPLEFT", PICTURE_RIGHT_COL, -EDGE_BOTTOM)
    -- Over the map's border frame, which holds the client's own title; centred over the map.
    local titleHost = ns.NewFrame("Frame", nil, map.BorderFrame)
    titleHost:SetAllPoints(art)
    title = titleHost:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("CENTER", art, "TOPLEFT", ERA_W / 2, TITLE_Y)
    art.titleHost = titleHost
    art:Hide()
    return art
end

-- Era's pieces for the window without the pane, or widened across it.
local artPane
local function LayArt(a, pane)
    if artPane == pane then return end
    artPane = pane
    local rightX = pane and PaneArtX() or ART_X + ART_LEFT_W
    a:SetSize(pane and PaneWindowW() or ERA_W, ERA_H)
    ns.SetPointOnce(a.right, "TOPLEFT", a, "TOPLEFT", rightX, 0)
    local fillW = math.min(rightX - (ART_X + ART_LEFT_W), ART_LEFT_W - FILL_MIN_COL)
    if pane and fillW > 0 then
        a.fill:SetSize(fillW, ART_H)
        a.fill:SetTexCoord((ART_LEFT_W - fillW) / ART_LEFT_W, 1, 0, 1)
        ns.SetPointOnce(a.fill, "TOPRIGHT", a.right, "TOPLEFT", 0, 0)
    end
    a.fill:SetShown(pane and fillW > 0)
    a.divider:SetShown(pane)
    a.paneBack:SetShown(pane)
end

-- Era's title: the continent's name inside one, else World Map.
local function MapTitle()
    local id = Map():GetMapID()
    local info = id and C_Map.GetMapInfo(id)
    while info and info.mapType and info.mapType > Enum.UIMapType.Continent and info.parentMapID do
        info = C_Map.GetMapInfo(info.parentMapID)
    end
    if info and info.mapType == Enum.UIMapType.Continent then return info.name end
    return WORLD_MAP or "World Map"
end

-- The client's coordinates line: the map's child holding PlayerCoords, found once.
local coords
local function NoteCoords(child)
    if child.PlayerCoords then coords = child end
end

local function Coords(map)
    if not coords then ns.EachChild(map, NoteCoords) end
    return coords
end

-- One line in the footer under the picture, from its left edge, level with Map Options' middle (its box 24 tall, 5 up):
-- the player's, the cursor's beside it. The game stacks its rows; only their labels move, its settings still show them.
local FOOT_MID = 17
local COORDS_GAP = 16
local labelPoints = {}   -- label -> the game's points, taken back with its look

local function PlaceLabel(label, rel, relPoint, x, y)
    if not labelPoints[label] then
        local points = {}
        for i = 1, label:GetNumPoints() do points[i] = { label:GetPoint(i) } end
        labelPoints[label] = points
    end
    ns.SetPointIf(label, "LEFT", rel, relPoint, x, y)
end

local function PlaceCoords(map, style)
    local panel = Coords(map)
    if not panel then return end
    local rel, x, y
    if style == "classic" then rel, x, y = ns.MapLarge.FootLeft() else rel, x, y = Art(), CANVAS_LEFT, -ERA_H end
    y = y + FOOT_MID
    local player = panel.PlayerCoords.Label
    PlaceLabel(player, rel, "TOPLEFT", x, y)
    local after = panel.PlayerCoords:IsShown()
    -- The cursor's and the gamepad crosshair's take turns on the canvas: one spot for both.
    for _, row in ipairs({ panel.CursorCoords, panel.CrosshairCoords }) do
        if after then PlaceLabel(row.Label, player, "RIGHT", COORDS_GAP, 0) else PlaceLabel(row.Label, rel, "TOPLEFT", x, y) end
    end
end

local function GameCoords()
    for label, points in pairs(labelPoints) do
        label:ClearAllPoints()
        for _, p in ipairs(points) do label:SetPoint(p[1], p[2], p[3], p[4], p[5]) end
    end
    wipe(labelPoints)
end

-- The pane's two scroll bars moved right by shift, or back on the game's own points (nil).
local barPoints = setmetatable({}, { __mode = "k" })
local function PaneBars()
    local details = QuestMapFrame and QuestMapFrame.DetailsFrame and QuestMapFrame.DetailsFrame.ScrollFrame
    return _G.QuestScrollFrame and _G.QuestScrollFrame.ScrollBar, details and details.ScrollBar
end

local function ShiftBar(bar, shift)
    if not bar then return end
    local was = barPoints[bar]
    if shift then
        if not was then
            was = {}
            for i = 1, bar:GetNumPoints() do was[i] = { bar:GetPoint(i) } end
            barPoints[bar] = was
        end
        local first = was[1]
        if not first or ns.IsAt(bar, first[1], first[2], first[3], first[4] + shift, first[5]) then return end
        bar:ClearAllPoints()
        for _, p in ipairs(was) do bar:SetPoint(p[1], p[2], p[3], p[4] + shift, p[5]) end
    elseif was then
        barPoints[bar] = nil
        bar:ClearAllPoints()
        for _, p in ipairs(was) do bar:SetPoint(unpack(p)) end
    end
end

local function ShiftBars(shift)
    local list, details = PaneBars()
    ShiftBar(list, shift)
    ShiftBar(details, shift)
end

local function HoldHidden(piece)
    if not piece then return end
    if piece:IsShown() then
        hidden[piece] = true
        piece:Hide()
    end
end

-- Era's small map: its two sheets, the continent's name, the X in the right sheet's socket.
local function DressSmall(map, close, sizer)
    ns.MapLarge.Hide()
    local a = Art()
    LayArt(a, PaneShown())
    ns.SetShownIf(a, true)
    ns.SetShownIf(a.titleHost, true)
    local id = map:GetMapID()
    if id ~= titleFor then
        titleFor = id
        title:SetText(MapTitle())
    end
    if close then
        ns.SetSizeIf(close, MAP_CLOSE_SIZE, MAP_CLOSE_SIZE)
        ns.SetPointIf(close, "TOPRIGHT", a.right, "TOPRIGHT", MAP_CLOSE_X, MAP_CLOSE_Y)
    end
    if sizer and close then
        ns.SetScaleIf(sizer, 1)
        ns.SetPointIf(sizer, "RIGHT", close, "LEFT", MAXIMIZE_GAP, 0)
    end
    local x = math.min(NONE_MAP_OPTIONS_X, -ns.WindowGripRoom("map"))
    ns.MapOptions.Place(map, a, a:GetWidth() + x, NONE_MAP_OPTIONS_Y - ERA_H, 1)
end

-- Era's large map: its sheets, header and buttons (WorldMapEraLarge.lua).
local function DressLarge(map, close, sizer)
    if art then
        art:Hide()
        art.titleHost:Hide()
    end
    local LM, level = ns.MapLarge, map.ScrollContainer:GetFrameLevel()
    local paneW = PaneW()
    LM.Art(map, math.max(0, level - ART_UNDER_MAP))
    LM.Show(map, paneW, level + FOOT_LINE_OVER_MAP)
    if close then LM.PlaceButtons(close, sizer, paneW) end
    local rel, x, y = LM.FootSpot(paneW)
    ns.MapOptions.Place(map, rel, x, y, LM.SCALE)
end

local function DressEra(style)
    local map = Map()
    local border = map.BorderFrame
    ns.SetAlphaIf(border.NineSlice, 0)
    ns.SetAlphaIf(border.TitleContainer, 0)
    ns.SetAlphaIf(border.InsetBorderTop, 0)
    if border.fcui and border.fcui.titleStrip then ns.SetShownIf(border.fcui.titleStrip, false) end
    ns.SetAlphaIf(_G["WorldMapFrameBg"], 0)
    for _, key in ipairs(EXTRAS) do HoldHidden(map[key]) end
    -- The quest pane toggle sits on the footer's border: over its line.
    if map.SidePanelToggle then
        ns.SetLevelIf(map.SidePanelToggle, map.ScrollContainer:GetFrameLevel() + FOOT_LINE_OVER_MAP + 1)
    end
    ShiftBars(PANE_BAR_SHIFT[style])
    ns.QuestPaneFloor(true)
    local close, sizer = border.CloseButton, border.MaximizeMinimizeFrame
    if style == "classic" then DressLarge(map, close, sizer) else DressSmall(map, close, sizer) end
    PlaceCoords(map, style)
    eraDressed = style
end

local function DressForever()
    if not eraDressed then return end
    eraDressed = nil
    local map = Map()
    local border = map.BorderFrame
    if art then
        art:Hide()
        art.titleHost:Hide()
    end
    ns.MapLarge.Hide()
    ns.MapOptions.Release(map)
    GameCoords()
    ShiftBars(nil)
    ns.QuestPaneFloor(false)
    border.NineSlice:SetAlpha(1)
    if border.TitleContainer then border.TitleContainer:SetAlpha(1) end
    if border.InsetBorderTop then border.InsetBorderTop:SetAlpha(1) end
    if border.fcui and border.fcui.titleStrip then border.fcui.titleStrip:Show() end
    if _G["WorldMapFrameBg"] then _G["WorldMapFrameBg"]:SetAlpha(1) end
    for piece in pairs(hidden) do piece:Show() end
    wipe(hidden)
    local close = border.CloseButton
    if close then
        ns.SetSizeIf(close, P.CLOSE_SIZE, P.CLOSE_SIZE)
        P.PlaceInSocket(close, border)
    end
    if border.MaximizeMinimizeFrame and close then
        ns.SetScaleIf(border.MaximizeMinimizeFrame, 1)
        P.MaxMinBeside(border.MaximizeMinimizeFrame, close, 8)
    end
end

local touched   -- the map picture's anchors are ours from the first Era lay on

-- Hide map quest button: faded and deaf, as the client shows it again on every open.
local QUEST_BUTTON_PARTS = { "OpenButton", "CloseButton" }
local questButtonHidden = false
local function QuestButton(map)
    local toggle = map.SidePanelToggle
    local hide = ns.db.hideMapQuestButton == true
    if not toggle or hide == questButtonHidden then return end
    questButtonHidden = hide
    toggle:SetAlpha(hide and 0 or 1)
    for _, key in ipairs(QUEST_BUTTON_PARTS) do
        if toggle[key] then toggle[key]:EnableMouse(not hide) end
    end
end

-- Opened in a fight, the game sizes the frame its own way (702 x 534) and Era's size waits for the fight's end: what
-- of the frame's own lies outside Era's art (its border, portrait ring, buttons placed for its size) fades till then.
local SLACK = 2
local faded = {}     -- client piece -> its alpha before
local fadedFor       -- the frame and art sizes the fade was worked out for
local keep = setmetatable({}, { __mode = "k" })   -- whole trees that stay: ours, the picture, the pane, the X
local rect = {}

local function Bounds(region)
    local l, t, r, b = region:GetLeft(), region:GetTop(), region:GetRight(), region:GetBottom()
    if not l or ns.AnySecret(l, t, r, b) then return nil end
    return l, t, r, b
end

local function Inside(region)
    local l, t, r, b = Bounds(region)
    return not l or (l >= rect[1] - SLACK and r <= rect[3] + SLACK and t <= rect[2] + SLACK and b >= rect[4] - SLACK)
end

local function Overlaps(region)
    local l, t, r, b = Bounds(region)
    return not l or (l < rect[3] and r > rect[1] and t > rect[4] and b < rect[2])
end

local function FadeOut(piece)
    if faded[piece] == nil then faded[piece] = piece:GetAlpha() end
    piece:SetAlpha(0)
end

-- Faded is not gone: the frame's own body past the art, and its pieces there, still took the clicks meant for the world.
-- Each mouse area is cut to the art (a child's does not follow its parent's); not a resize, so no refit runs as ours.
local clipped = {}   -- frame -> its hit insets before
local function ClipMouse(frame)
    if clipped[frame] or not frame:IsMouseEnabled() or frame:IsProtected() then return end
    local l, t, r, b = Bounds(frame)
    if not l then return end
    clipped[frame] = { frame:GetHitRectInsets() }
    frame:SetHitRectInsets(math.max(0, rect[1] - l), math.max(0, r - rect[3]), math.max(0, t - rect[2]),
        math.max(0, rect[4] - b))
end

local FadeTree
local function FadeRegion(region)
    if region:IsShown() and not Inside(region) then FadeOut(region) end
end
local function FadeChild(child, depth)
    if keep[child] or not child:IsShown() or Inside(child) then return end
    ClipMouse(child)
    if Overlaps(child) then FadeTree(child, depth) else FadeOut(child) end
end
FadeTree = function(frame, depth)
    ns.EachRegion(frame, FadeRegion)
    if depth < 4 then ns.EachChild(frame, FadeChild, depth + 1) end
end

local function FadeOutside(map, style)
    local a = style == "classic" and ns.MapLarge.Frame() or Art()
    local key = string.format("%.0fx%.0f/%.0f", map:GetWidth(), map:GetHeight(), a:GetWidth())
    if fadedFor == key then return end
    fadedFor = key
    rect[1], rect[2], rect[3], rect[4] = Bounds(a)
    if not rect[1] then return end
    local border = map.BorderFrame
    for _, piece in ipairs({ a, a.titleHost, map.ScrollContainer, map.QuestLog, border.CloseButton,
        border.MaximizeMinimizeFrame, map.BlackoutFrame }) do
        if piece then keep[piece] = true end
    end
    ns.MapLarge.Keep(keep)
    ns.MapOptions.Keep(keep, map)
    ClipMouse(map)
    FadeTree(map, 0)
end

local function Unfade()
    fadedFor = nil
    for piece, alpha in pairs(faded) do piece:SetAlpha(alpha) end
    wipe(faded)
    for frame, insets in pairs(clipped) do
        if not frame:IsProtected() then frame:SetHitRectInsets(insets[1], insets[2], insets[3], insets[4]) end
    end
    wipe(clipped)
end

local function Pass()
    local map = Map()
    if not map then return end
    QuestButton(map)
    local style = EraStyle()
    if style then
        touched = true
        local t = Target(style)
        Lay(t)
        -- Laid taller than the game's own size it was placed with: raised as the game would fit it.
        if laidAt == GetTime() and Map():IsShown() then ns.FitGameWindow("map") end
        if Laid(t) then
            DressEra(style)
            Unfade()
            Fill(map:IsMaximized() and FullScale(t) or nil)
            Windowed(style == "classic" and not map:IsMaximized() and WindowedScale() or nil)
        elseif InCombatLockdown() and PictureLaid(t) then
            DressEra(style)
            FadeOutside(map, style)
        else
            Unfade()
            DressForever()
            -- In a fight its size stays as it is (a pass that could not lay it is not the game's own look).
            if not InCombatLockdown() then
                Fill(nil)
                Windowed(nil)
            end
        end
    elseif touched then
        Unfade()
        DressForever()
        Lay(Target(nil))
        Fill(nil)
        Windowed(nil)
    end
    Refit()
end

-- The Era art frame, or nil before the first lay (dev selftest map.fightmouse).
function ns.ClassicMapArt() return art end

-- For the fight layer (Map/WorldMapFight.lua): the layout header, the style worn and its box, quest pane open or shut.
ns.MapFight = {
    Map = Map, Layout = Layout, EraStyle = EraStyle, Target = Target, PANE_KEYS = PANE_KEYS,
    FullScale = function(w, h) return FullScale({ w = w, h = h }) end,
    -- The style's own windowed size (the header style's), nil for the rest.
    WindowedBase = function(style) return style == "classic" and WindowedScale() or nil end,
    Size = function(style, withPane)
        if style == "classic" then return ns.MapLarge.Size(withPane and QUEST_PANE_W or nil) end
        return withPane and PaneWindowW() or ERA_W, ERA_H
    end,
}

-- How far the Era layout lifts the quest details' text (its Back button follows, Quest/QuestMapPane.lua).
function ns.MapDetailsLift() return eraDressed and DETAILS_LIFT or 0 end

-- The Era frame drawn now, its right edge the border's outer edge (Core/API.lua's worldMap); nil in the game's look.
function ns.ClassicMapBorder()
    if eraDressed == "classic" then return ns.MapLarge.Frame() end
    return eraDressed and art or nil
end

-- The edit mode box: the size the header style draws, the client's for its own layout.
function ns.ClassicMapSize()
    local style = ns.ModuleInForce("worldMap") and NavStyle()
    if style == "classic" then
        local w, h = ns.MapLarge.Size(nil)
        return w, h, ns.MapLarge.Size(QUEST_PANE_W) - w
    elseif style == "none" then
        return ERA_W, ERA_H, PaneWindowW() - ERA_W
    end
    return FOREVER_W, FOREVER_H, FOREVER_PANE_W
end

-- The map shut: its box laid now, so its own next open fits the picture to it with no refit.
local function LayShut()
    local map = Map()
    if not ns.ready or not map or map:IsShown() then return end
    Pass()
end

local function Attach()
    local map = Map()
    if not map or not map.ScrollContainer or not map.TitleCanvasSpacerFrame then return false end
    ns.Sched.Attach(map, { name = "map.classic", every = 0, fn = Pass })
    ns.Sched.OnVisible(map, "map.classicShut", function(shown)
        if not shown then ns.Sched.NextFrame("map.classicShut", LayShut) end
    end)
    ns.Sched.NextFrame("map.classicShut", LayShut)
    return true
end

-- At login, and after a fight that held off a lay.
ns.EventFrame({ "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED" }, function() LayShut() end)

ns.AttachWhenLoaded(Attach)

local PASS_KEYS = { mapNavBar = true, mapNavClassic = true, mapNavNone = true, worldMap = true, hideMapQuestButton = true,
    mapOptions = true, mapOptionsHover = true, mapOptionsHidden = true }
local STYLE_KEYS = { mapNavBar = true, mapNavClassic = true, mapNavNone = true }

-- A style picked: each draws the map at its own game's size, said once a session.
ns.Popup("FCUI_MAP_STYLE_SIZE", { text = ns.L["MAP_STYLE_SIZE"], button1 = OKAY or "Okay", button2 = false })
local sizeSaid

ns.OnToggle(function(key)
    if PASS_KEYS[key] then
        if Map() and Map():IsShown() then Pass() else LayShut() end
    end
    if STYLE_KEYS[key] and ns.db[key] == true and not sizeSaid then
        sizeSaid = true
        StaticPopup_Show("FCUI_MAP_STYLE_SIZE")
    end
end)
