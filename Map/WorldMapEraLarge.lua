local _, ns = ...

-- Classic Era's large world map (Blizzard_WorldMap Vanilla) at its own size: its 1024 x 768 sheets
-- round the picture, the header's Continent and Zone drop downs and Zoom Out, the zoom note over the picture's corner.
-- WorldMapClassic.lua lays the picture and quest pane in the holes given here; numbers below are the sheets' own units.

local LM = {}
ns.MapLarge = LM

local SHEET = 256
local ART_W, ART_H = 1024, 768
-- The sheets' scale (LM.Fit): Era's own maximized, the game's own map height windowed. The text keeps the game's size.
local K = 1
-- The picture's hole (Era's ScrollContainer: 11 in, 70 down, 11 from the right, 30 up) and its rim rows.
local HOLE_L, HOLE_T, HOLE_R, HOLE_B = 11, 70, 1013, 738
-- Pane open: the sheets' own divider (columns 702 to 711, joined to the header and footer rims at rows 62 and 744) with
-- its rim on the picture's right edge, the pane's hole after it; the header and footer run on in plain stone (columns
-- 760 to 900) up to the right end (the right knot, both sockets, the border).
local DIV_L, DIV_R, DIV_T, DIV_B, DIV_RIM = 702, 711, 62, 744, 2
local DIV_X = HOLE_R - DIV_RIM
local PANE_X = DIV_X + DIV_R - DIV_L
local FILL_L, FILL_R, RIGHT_END = 760, 900, 900
-- The sheets' own quest layout (the 3.x map): the picture to the divider, the list column after it, a band and two
-- pages under the picture; the pages' parchment and the spine between them, measured on the sheets.
local LIST_L, LIST_R = DIV_R, HOLE_R
local BAND_T, BAND_B, PAGES_B = 532, 538, HOLE_B
local PAGE_L, SPINE_L, SPINE_R, PAGE_R = 27, 345, 362, 689
-- Era's picture, 1002 x 668: the combined layout keeps its aspect, at the share of its size the player drags.
local PICTURE_W, PICTURE_H = 1002, 668
local NATIVE_W, NATIVE_H = DIV_L - HOLE_L, BAND_T - HOLE_T
local SHARE_MIN, SHARE_MAX = 0.5, 0.86
-- The rims' plain run, repeated for a taller window; the rows under the band (the pages' edge) stay at the foot.
local RIM_FILL_T, RIM_FILL_B = 300, 400
-- The list column's ends, kept as drawn (the scroll track's squares sit in them), and its right strip (the track):
-- the cover between them stretches to the column's height and width.
local COL_TOP_B, COL_FOOT_T, COL_TRACK_W = 100, 700, 30
local COL_ROWS = { { HOLE_T, COL_TOP_B }, { COL_TOP_B, COL_FOOT_T }, { COL_FOOT_T, HOLE_B } }
local COL_COLS = { { LIST_L, LIST_R - COL_TRACK_W }, { LIST_R - COL_TRACK_W, LIST_R } }
-- Era's header (Vanilla Blizzard_WorldMap.xml): Continent 130 wide, its top 80 left of the middle and 36 down, Zone
-- 5 right of it, Zoom Out 110 x 22 another 5 on; the labels 12 over each. The title 12 down. Era's Zoom Out sits 3 up
-- for its own button art; ours fills its frame, so centred on the drop downs.
local DROP_W, DROP_H, DROP_X, DROP_Y, DROP_GAP = 130, 24, -80, -36, 5
local ZOOM_W, ZOOM_H, ZOOM_Y = 110, 22, 0
local LABEL_Y, TITLE_Y = 12, -12
-- Windowed, the band is 30 short of Era's at the text's size: the labels beside their drop downs, one row under the
-- title, the two drop downs' facing edges the same way off the middle with the Zone label between them. The title's
-- middle and the row's from the band's top (+ up); a label to its drop down; after a drop down.
local WIN_TITLE_Y = -10
local WIN_ROW_Y = -32
local WIN_LABEL_GAP = 4
local WIN_GAP = 10
-- The zoom note: 179 x 40, its left 468 left of the middle and 86 down; the glass 32, the text 32 in and 5 down.
local NOTE_W, NOTE_H, NOTE_X, NOTE_Y, GLASS, NOTE_TEXT_X, NOTE_TEXT_Y = 179, 40, -468, -86, 32, 32, -5
-- Close in the right socket as Era's (its top right 4 past the edge and 4 up), the size button 12 into it.
local CLOSE_X, CLOSE_Y, CLOSE_SIZE, SIZER_X = 4, 4, 32, 12

local SHEETS = {}
for row, name in ipairs({ "Top", "Middle", "Bottom" }) do
    SHEETS[row] = {}
    for col = 1, 4 do SHEETS[row][col] = "Interface\\WorldMap\\UI-WorldMap-" .. name .. col end
end

local art, header, over, rim
-- The sheets' pieces on art; the right rim beside the pane on rim, over the pane's scroll column (it runs past its hole).
local pool = { list = {}, used = 0 }
local rimPool = { list = {}, used = 0 }
local drawing = pool
local laidPane

local function NextTexture(layer, sublevel)
    local p = drawing
    p.used = p.used + 1
    local tex = p.list[p.used]
    if not tex then
        tex = p.frame:CreateTexture(nil, "ARTWORK")
        p.list[p.used] = tex
    end
    tex:SetDrawLayer(layer or "ARTWORK", sublevel or 0)
    tex:ClearAllPoints()
    tex:Show()
    return tex
end

-- The sheets' rect x0..x1, y0..y1 drawn with its top left at dx, dy, one texture per sheet it crosses; kx, ky
-- stretch it (1 as the sheets have it).
local function Slice(x0, y0, x1, y1, dx, dy, sublevel, kx, ky)
    kx, ky = kx or 1, ky or 1
    for col = math.floor(x0 / SHEET), math.floor((x1 - 1) / SHEET) do
        for row = math.floor(y0 / SHEET), math.floor((y1 - 1) / SHEET) do
            local l, r = math.max(x0, col * SHEET), math.min(x1, (col + 1) * SHEET)
            local t, b = math.max(y0, row * SHEET), math.min(y1, (row + 1) * SHEET)
            local tex = NextTexture("ARTWORK", sublevel)
            ns.SetFile(tex, SHEETS[row + 1][col + 1])
            tex:SetTexCoord((l - col * SHEET) / SHEET, (r - col * SHEET) / SHEET, (t - row * SHEET) / SHEET,
                (b - row * SHEET) / SHEET)
            tex:SetSize((r - l) * kx, (b - t) * ky)
            tex:SetPoint("TOPLEFT", art, "TOPLEFT", dx + (l - x0) * kx, -(dy + (t - y0) * ky))
        end
    end
end

-- The picture's size at a share of Era's, and where the divider and the band under it fall.
local function Split(share)
    local w, h = math.floor(PICTURE_W * share + 0.5), math.floor(PICTURE_H * share + 0.5)
    return w, h, HOLE_L + w, HOLE_T + h
end

-- The footer (the rim and rail under the picture, 30 rows) keeps the text's height whatever the sheets wear: its rows
-- are stretched by 1/K, so Map Options and the coordinates fit it. The sheets' height with it, in the sheets' units.
local function FootH(k) return (ART_H - HOLE_B) / (k or K) end
local function SheetsH(k) return HOLE_B + FootH(k) end

-- The combined window for a shape (the picture's share, the list column's width, the pages' height): the rims and
-- bands round them as the sheets have them.
local function CombinedSize(shape, k)
    local w, h = Split(shape.share)
    return w + HOLE_L + DIV_R - DIV_L + shape.listW + ART_W - HOLE_R, h + HOLE_T + BAND_B - BAND_T + shape.pagesH + FootH(k)
end

-- The sheets' rows y0..y1 drawn dy down at width w (ky stretching them): the left part to its right end, plain stone
-- repeated for the rest (cut short of the right end when narrower), the right end last.
local function HRun(y0, y1, dy, w, ky)
    local extra = w - ART_W
    if extra >= 0 then
        Slice(0, y0, RIGHT_END, y1, 0, dy, 0, 1, ky)
        for x = RIGHT_END, RIGHT_END + extra - 1, FILL_R - FILL_L do
            Slice(FILL_L, y0, FILL_L + math.min(FILL_R - FILL_L, RIGHT_END + extra - x), y1, x, dy, 0, 1, ky)
        end
    else
        Slice(0, y0, RIGHT_END + extra, y1, 0, dy, 0, 1, ky)
    end
    Slice(RIGHT_END, y0, ART_W, y1, w - (ART_W - RIGHT_END), dy, 0, 1, ky)
end

-- A rim's columns x0..x1 drawn dx right at the hole's height hgt: the picture's rows to the band, the plain run
-- repeated for the rest (cut when shorter), the band's and pages' rows last.
local function VRun(x0, x1, dx, hgt)
    local extra = hgt - (HOLE_B - HOLE_T)
    if extra >= 0 then
        Slice(x0, HOLE_T, x1, BAND_T, dx, HOLE_T)
        for y = BAND_T, BAND_T + extra - 1, RIM_FILL_B - RIM_FILL_T do
            Slice(x0, RIM_FILL_T, x1, RIM_FILL_T + math.min(RIM_FILL_B - RIM_FILL_T, BAND_T + extra - y), dx, y)
        end
    else
        Slice(x0, HOLE_T, x1, BAND_T + extra, dx, HOLE_T)
    end
    Slice(x0, BAND_T, x1, HOLE_B, dx, BAND_T + extra)
end

-- The list column at listX, colW wide and inner tall: its ends and track strip as drawn, the cover between stretched.
local function LayColumn(listX, colW, inner)
    local foot = HOLE_B - COL_FOOT_T
    local kx = (colW - COL_TRACK_W) / (COL_COLS[1][2] - COL_COLS[1][1])
    local ky = (inner - (COL_TOP_B - HOLE_T) - foot) / (COL_FOOT_T - COL_TOP_B)
    for r, rows in ipairs(COL_ROWS) do
        local dy = r == 1 and HOLE_T or r == 2 and COL_TOP_B or HOLE_T + inner - foot
        for c, cols in ipairs(COL_COLS) do
            local dx = c == 1 and listX or listX + colW - COL_TRACK_W
            Slice(cols[1], rows[1], cols[2], rows[2], dx, dy, 0, c == 1 and kx or 1, r == 2 and ky or 1)
        end
    end
end

-- The sheets' quest layout for a shape: the header and footer run to the window's width, the rims to its height, the
-- hole's parchment under the picture, the divider at its right, the list column after it, the band and pages under
-- the picture at its width and the pages' height.
local function LayCombined(shape)
    local w, h, splitX, splitY = Split(shape.share)
    local W, H = CombinedSize(shape)
    local inner = H - HOLE_T - FootH()
    HRun(0, HOLE_T, 0, W)
    HRun(HOLE_B, ART_H, H - FootH(), W, 1 / K)
    VRun(0, HOLE_L, 0, inner)
    VRun(HOLE_R, ART_W, W - (ART_W - HOLE_R), inner)
    local kx = w / NATIVE_W
    Slice(HOLE_L, HOLE_T, DIV_L, BAND_T, HOLE_L, HOLE_T, 0, kx, h / NATIVE_H)
    Slice(DIV_L, DIV_T, DIV_R, DIV_B, splitX, DIV_T, 1, 1, (H - DIV_T - (ART_H - DIV_B) / K) / (DIV_B - DIV_T))
    LayColumn(splitX + DIV_R - DIV_L, shape.listW, inner)
    Slice(HOLE_L, BAND_T, DIV_L, BAND_B, HOLE_L, splitY, 0, kx, 1)
    Slice(HOLE_L, BAND_B, DIV_L, PAGES_B, HOLE_L, splitY + BAND_B - BAND_T, 0, kx, shape.pagesH / (PAGES_B - BAND_B))
    art.paneBack:Hide()
    art:SetSize(W, H)
    header:SetWidth(W * K)
end

-- How far the right end moves out for the pane, in the sheets' units: the divider and the pane's width (the map's units).
function LM.Widen(paneW, k) return PANE_X - HOLE_R + paneW / (k or K) end

local function Lay(paneW, shape)
    pool.used, rimPool.used = 0, 0
    if shape then
        LayCombined(shape)
    elseif not paneW then
        Slice(0, 0, ART_W, HOLE_B, 0, 0)
        Slice(0, HOLE_B, ART_W, ART_H, 0, HOLE_B, 0, 1, 1 / K)
        art.paneBack:Hide()
    else
        local widen = LM.Widen(paneW)
        Slice(0, 0, RIGHT_END, HOLE_B, 0, 0)
        Slice(0, HOLE_B, RIGHT_END, ART_H, 0, HOLE_B, 0, 1, 1 / K)
        for x = RIGHT_END, RIGHT_END + widen - 1, FILL_R - FILL_L do
            local w = math.min(FILL_R - FILL_L, RIGHT_END + widen - x)
            Slice(FILL_L, 0, FILL_L + w, HOLE_T, x, 0)
            Slice(FILL_L, HOLE_B, FILL_L + w, ART_H, x, HOLE_B, 0, 1, 1 / K)
        end
        Slice(RIGHT_END, 0, ART_W, HOLE_T, RIGHT_END + widen, 0)
        Slice(RIGHT_END, HOLE_B, ART_W, ART_H, RIGHT_END + widen, HOLE_B, 0, 1, 1 / K)
        Slice(DIV_L, DIV_T, DIV_R, HOLE_B, DIV_X, DIV_T, 1)
        Slice(DIV_L, HOLE_B, DIV_R, DIV_B, DIV_X, HOLE_B, 1, 1, 1 / K)
        -- The rim beside the pane, rim joint to rim joint, over the pane's scroll column.
        drawing = rimPool
        Slice(HOLE_R, DIV_T, ART_W, HOLE_B, HOLE_R + widen, DIV_T)
        Slice(HOLE_R, HOLE_B, ART_W, DIV_B, HOLE_R + widen, HOLE_B, 0, 1, 1 / K)
        drawing = pool
        art.paneBack:ClearAllPoints()
        art.paneBack:SetPoint("TOPLEFT", art, "TOPLEFT", PANE_X, -HOLE_T)
        art.paneBack:SetPoint("BOTTOMRIGHT", art, "TOPLEFT", HOLE_R + widen, -HOLE_B)
        art.paneBack:Show()
    end
    for i = pool.used + 1, #pool.list do pool.list[i]:Hide() end
    for i = rimPool.used + 1, #rimPool.list do rimPool.list[i]:Hide() end
    if shape then return end
    art:SetSize(ART_W + (paneW and LM.Widen(paneW) or 0), SheetsH())
    header:SetWidth(ART_W * K)
end

------------------------------------------------------------------ header

local continents
local zonesOf = {}

-- Era's GetCurrentMapContinent: the continent a map sits in, nil above one.
local function ContinentOf(id)
    local info = id and C_Map.GetMapInfo(id)
    if not info or info.mapType <= Enum.UIMapType.World then return nil end
    if info.mapType == Enum.UIMapType.Continent then return info end
    return MapUtil.GetMapParentInfo(id, Enum.UIMapType.Continent)
end

local function Map() return WorldMapFrame end
local function Go(info) Map():SetMapID(info.mapID) end
local function ZoomOut() Map():NavigateToParentMap() end

local function ContinentPicked(info)
    local now = ContinentOf(Map():GetMapID())
    return now ~= nil and now.mapID == info.mapID
end

local function ZonePicked(info) return Map():GetMapID() == info.mapID end

local function ContinentMenu(_, root)
    local world = not continents and MapUtil.GetMapParentInfo(Map():GetMapID(), Enum.UIMapType.World, true)
    if world then
        continents = {}
        for _, info in ipairs(C_Map.GetMapChildrenInfo(world.mapID) or {}) do
            if info.mapType == Enum.UIMapType.Continent then continents[#continents + 1] = info end
        end
    end
    for _, info in ipairs(continents or {}) do root:CreateRadio(info.name, ContinentPicked, Go, info) end
end

local function ByName(a, b) return a.name < b.name end

local function ZoneMenu(_, root)
    local continent = ContinentOf(Map():GetMapID())
    if not continent then return end
    local zones = zonesOf[continent.mapID]
    if not zones then
        zones = {}
        for _, info in ipairs(C_Map.GetMapChildrenInfo(continent.mapID) or {}) do
            if info.mapType == Enum.UIMapType.Zone then zones[#zones + 1] = info end
        end
        table.sort(zones, ByName)
        zonesOf[continent.mapID] = zones
    end
    for _, info in ipairs(zones) do root:CreateRadio(info.name, ZonePicked, Go, info) end
end

local function Dropdown(parent, menu)
    local dd = ns.NewFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    dd:SetSize(DROP_W, DROP_H)
    ns.EraDropdownArt(dd, -1, -1, -24)
    if dd.Text then dd.Text:SetFontObject("GameFontHighlightSmall") end
    if dd.SetDefaultText then dd:SetDefaultText("") end
    dd:SetupMenu(menu)
    return dd
end

local function Label(text)
    local label = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetText(text)
    return label
end

-- The header over the sheets' band: Era's layout at Era's scale, the one row windowed.
local function LayHeader()
    local h = header
    h:SetSize(ART_W * K, HOLE_T * K)
    local title, continent, zone, zoom = h.title, h.continent, h.zone, h.zoomOut
    local continentLabel, zoneLabel = h.continentLabel, h.zoneLabel
    for _, piece in ipairs({ title, continent, zone, zoom, continentLabel, zoneLabel }) do piece:ClearAllPoints() end
    if K == 1 then
        title:SetPoint("CENTER", h, "TOP", 0, TITLE_Y)
        continent:SetPoint("TOPLEFT", h, "TOP", DROP_X - DROP_W / 2, DROP_Y)
        continentLabel:SetPoint("TOPLEFT", continent, "TOPLEFT", 0, LABEL_Y)
        zone:SetPoint("LEFT", continent, "RIGHT", DROP_GAP, 0)
        zoneLabel:SetPoint("TOPLEFT", zone, "TOPLEFT", 0, LABEL_Y)
        zoom:SetPoint("LEFT", zone, "RIGHT", DROP_GAP, ZOOM_Y)
        return
    end
    title:SetPoint("CENTER", h, "TOP", 0, WIN_TITLE_Y)
    local half = (WIN_GAP + zoneLabel:GetStringWidth() + WIN_LABEL_GAP) / 2
    continent:SetPoint("RIGHT", h, "TOP", -half, WIN_ROW_Y)
    continentLabel:SetPoint("RIGHT", continent, "LEFT", -WIN_LABEL_GAP, 0)
    zone:SetPoint("LEFT", h, "TOP", half, WIN_ROW_Y)
    zoneLabel:SetPoint("RIGHT", zone, "LEFT", -WIN_LABEL_GAP, 0)
    zoom:SetPoint("LEFT", zone, "RIGHT", WIN_GAP, 0)
end

local function Header(map)
    header = ns.NewFrame("Frame", nil, map.BorderFrame)
    header:SetPoint("TOPLEFT", map, "TOPLEFT", 0, 0)
    header.title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header.title:SetText(WORLDMAP_BUTTON or WORLD_MAP)
    header.continent = Dropdown(header, ContinentMenu)
    header.continentLabel = Label(CONTINENT)
    header.zone = Dropdown(header, ZoneMenu)
    header.zoneLabel = Label(ZONE)
    header.zoomOut = ns.PanelButton(header, ZOOM_OUT, ZOOM_W)
    header.zoomOut:SetHeight(ZOOM_H)
    header.zoomOut:SetScript("OnClick", ZoomOut)
    LayHeader()
end

-- The note's spot over the picture's corner, in the map's units.
local function LayNote()
    over:SetSize(ART_W * K, ART_H * K)
    ns.SetPointIf(over.note, "TOPLEFT", over, "TOPLEFT", (ART_W / 2 + NOTE_X) * K, NOTE_Y * K)
end

-- Era's zoom note over the picture's top left: a click on it zooms out too.
local function Note(map)
    over = ns.NewFrame("Frame", nil, map)
    over:SetPoint("TOPLEFT", map, "TOPLEFT", 0, 0)
    local note = ns.NewFrame("Button", nil, over)
    note:SetSize(NOTE_W, NOTE_H)
    note:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    note:SetScript("OnClick", ZoomOut)
    local glass = note:CreateTexture(nil, "BACKGROUND")
    ns.SetFile(glass, "Interface\\WorldMap\\WorldMap-MagnifyingGlass")
    glass:SetSize(GLASS, GLASS)
    glass:SetPoint("TOPLEFT")
    local text = note:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("TOPLEFT", note, "TOPLEFT", NOTE_TEXT_X, NOTE_TEXT_Y)
    text:SetText(ZOOM_OUT_BUTTON_TEXT)
    over.note = note
    LayNote()
end

------------------------------------------------------------------ for WorldMapClassic.lua

-- Built on first use, under the picture as Era's; the header and the note over it.
function LM.Art(map, level)
    if art then return art end
    art = ns.NewFrame("Frame", nil, map)
    art:SetScale(K)
    art:SetPoint("TOPLEFT", map, "TOPLEFT", 0, 0)
    art:SetFrameLevel(level)
    art.paneBack = art:CreateTexture(nil, "BACKGROUND")
    art.paneBack:SetColorTexture(0, 0, 0, 1)
    rim = ns.NewFrame("Frame", nil, art)
    rim:SetAllPoints(art)
    pool.frame, rimPool.frame = art, rim
    Header(map)
    Note(map)
    art:Hide()
    header:Hide()
    over:Hide()
    return art
end

function LM.Frame() return art end

-- Ours, kept when a fight's fade walks the map.
function LM.Keep(into)
    if art then into[art], into[header], into[over], into[rim] = true, true, true, true end
end

-- The rim beside the pane over both of the pane's scroll bars (their column runs past the hole into it).
local function BarLevel(bar) return bar and bar:GetFrameLevel() or 0 end
local function RimLevel(noteLevel)
    local list = _G.QuestScrollFrame and _G.QuestScrollFrame.ScrollBar
    local details = QuestMapFrame and QuestMapFrame.DetailsFrame and QuestMapFrame.DetailsFrame.ScrollFrame
    return math.max(noteLevel, BarLevel(list), BarLevel(details and details.ScrollBar)) + 1
end

-- paneW: the quest pane's width in the map's units, nil while it is shut; shape: the combined layout's (its own list
-- and pages; one table per shape, Map/WorldMapCombined.lua), nil for the plain one.
function LM.Show(map, paneW, noteLevel, shape)
    local key = shape or paneW or false
    if laidPane ~= key then
        laidPane = key
        Lay(paneW, shape)
    end
    ns.SetShownIf(art, true)
    ns.SetShownIf(header, true)
    ns.SetShownIf(over, true)
    ns.SetLevelIf(over, noteLevel)
    ns.SetLevelIf(rim, RimLevel(noteLevel))
    local id = map:GetMapID()
    if header.forMap ~= id then
        header.forMap = id
        header.continent:GenerateMenu()
        header.zone:GenerateMenu()
        if ContinentOf(id) then header.zoomOut:Enable() else header.zoomOut:Disable() end
    end
end

function LM.Hide()
    if not art then return end
    art:Hide()
    header:Hide()
    over:Hide()
end

-- The window's size, the picture's box and the pane's, in the map's units from its top left (y down); k: a sheet
-- scale other than the one worn (the edit mode box asks the windowed one).
function LM.Size(paneW, k)
    k = k or K
    return (ART_W + (paneW and LM.Widen(paneW, k) or 0)) * k, SheetsH(k) * k
end
function LM.Picture() return HOLE_L * K, HOLE_T * K, HOLE_R * K, HOLE_B * K end
function LM.Pane(paneW) return PANE_X * K, HOLE_T * K, PANE_X * K + paneW, HOLE_B * K end
LM.SHEET_H = ART_H
function LM.Scale() return K end

-- The combined layout's boxes for a shape, in the map's units from its top left (y down): the picture, the list
-- column, the left and right pages' parchment, the divider. One table, rebuilt as the shape or the scale changes.
local boxes, boxesFor = {}, nil
LM.NATIVE_SHARE, LM.NATIVE_LIST_W, LM.NATIVE_PAGES_H = NATIVE_W / PICTURE_W, LIST_R - LIST_L, PAGES_B - BAND_B
-- The window's width past the picture and list, and its height past the picture and pages (the map's units).
function LM.SideRoom() return (HOLE_L + DIV_R - DIV_L + ART_W - HOLE_R) * K end
function LM.FootRoom() return (HOLE_T + BAND_B - BAND_T + FootH()) * K end
function LM.ClampShare(share) return math.max(SHARE_MIN, math.min(SHARE_MAX, share or LM.NATIVE_SHARE)) end
function LM.CombinedSize(shape, k)
    k = k or K
    local W, H = CombinedSize(shape, k)
    return W * k, H * k
end
function LM.CombinedBoxes(shape)
    if boxesFor == shape then return boxes end
    boxesFor = shape
    local w, h, splitX, splitY = Split(shape.share)
    local kx, listX, pageT = w / NATIVE_W, splitX + DIV_R - DIV_L, splitY + BAND_B - BAND_T
    local pagesB, listB = pageT + shape.pagesH, HOLE_T + h + BAND_B - BAND_T + shape.pagesH
    boxes.picture = { HOLE_L * K, HOLE_T * K, splitX * K, splitY * K }
    boxes.list = { listX * K, HOLE_T * K, (listX + shape.listW) * K, listB * K }
    boxes.pageL = { (HOLE_L + (PAGE_L - HOLE_L) * kx) * K, pageT * K, (HOLE_L + (SPINE_L - HOLE_L) * kx) * K, pagesB * K }
    boxes.pageR = { (HOLE_L + (SPINE_R - HOLE_L) * kx) * K, pageT * K, (HOLE_L + (PAGE_R - HOLE_L) * kx) * K, pagesB * K }
    boxes.divider = { splitX * K, DIV_T * K, (splitX + DIV_R - DIV_L) * K, (listB + DIV_B - HOLE_B) * K }
    return boxes
end
-- The share a picture corner at x, y (the map's units from the hole's top left) asks, aspect kept: the nearer axis.
function LM.ShareFor(x, y) return LM.ClampShare(math.min(x / K / PICTURE_W, y / K / PICTURE_H)) end
-- The share a picture w wide or h tall (the map's units) asks, and the picture's size at a share.
function LM.ShareForWidth(w) return LM.ClampShare(w / K / PICTURE_W) end
function LM.ShareForHeight(h) return LM.ClampShare(h / K / PICTURE_H) end
function LM.PictureSize(share)
    local w, h = Split(share)
    return w * K, h * K
end

-- Close and size buttons in the right end's two sockets, wherever the pane has moved it.
function LM.PlaceButtons(close, sizer)
    local right = (art:GetWidth() + CLOSE_X) * K
    ns.SetSizeIf(close, CLOSE_SIZE * K, CLOSE_SIZE * K)
    ns.SetPointIf(close, "TOPRIGHT", art, "TOPLEFT", right, CLOSE_Y * K)
    if sizer then
        ns.SetScaleIf(sizer, K)
        ns.SetPointIf(sizer, "RIGHT", close, "LEFT", SIZER_X, 0)
    end
end

-- Map Options in Classic style: its box's right edge from the window's right (+ right), its bottom from the bottom
-- (+ up: the box 24 tall in the footer's 30), in the map's units; clear of the unlocked map's corner grip.
local CLASSIC_MAP_OPTIONS_X = -3
local CLASSIC_MAP_OPTIONS_Y = 3
function LM.FootSpot()
    local x = math.min(CLASSIC_MAP_OPTIONS_X, -ns.WindowGripRoom("map"))
    return art, art:GetWidth() * K + x, CLASSIC_MAP_OPTIONS_Y - art:GetHeight() * K
end

-- The footer's left: the picture's left edge, the art's bottom (the map's units).
function LM.FootLeft() return art, HOLE_L * K, -art:GetHeight() * K end

-- The sheets' scale for the map's mode (Map/WorldMapClassic.lua): the art re-laid, the header and note placed again.
function LM.Fit(k)
    if k == K then return end
    K = k
    laidPane, boxesFor = nil, nil
    if not art then return end
    art:SetScale(K)
    LayHeader()
    LayNote()
end
