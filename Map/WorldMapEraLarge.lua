local _, ns = ...

-- Classic Era's large world map (Blizzard_WorldMap Vanilla) at its own size: its 1024 x 768 sheets
-- round the picture, the header's Continent and Zone drop downs and Zoom Out, the zoom note over the picture's corner.
-- WorldMapClassic.lua lays the picture and quest pane in the holes given here; numbers below are the sheets' own units.

local LM = {}
ns.MapLarge = LM

local SHEET = 256
local ART_W, ART_H = 1024, 768
-- Drawn at Era's own size, its text and buttons too; edit mode's size shrinks the whole map.
local K = 1
LM.SCALE = K
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
-- The zoom note: 179 x 40, its left 468 left of the middle and 86 down; the glass 32, the text 32 in and 5 down.
local NOTE_W, NOTE_H, NOTE_X, NOTE_Y, GLASS, NOTE_TEXT_X, NOTE_TEXT_Y = 179, 40, -468, -86, 32, 32, -5
-- Close in the right socket as Era's (its top right 4 past the edge and 4 up), the size button 12 into it.
local CLOSE_X, CLOSE_Y, CLOSE_SIZE, SIZER_X = 4, 4, 32, 12

local SHEETS = {}
for row, name in ipairs({ "Top", "Middle", "Bottom" }) do
    SHEETS[row] = {}
    for col = 1, 4 do SHEETS[row][col] = "Interface\\WorldMap\\UI-WorldMap-" .. name .. col end
end

local art, header, over
local textures, used = {}, 0
local laidPane

local function NextTexture(layer, sublevel)
    used = used + 1
    local tex = textures[used]
    if not tex then
        tex = art:CreateTexture(nil, "ARTWORK")
        textures[used] = tex
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

-- The combined window for a shape (the picture's share, the list column's width, the pages' height): the rims and
-- bands round them as the sheets have them.
local function CombinedSize(shape)
    local w, h = Split(shape.share)
    return w + HOLE_L + DIV_R - DIV_L + shape.listW + ART_W - HOLE_R, h + HOLE_T + BAND_B - BAND_T + shape.pagesH + ART_H - HOLE_B
end

-- The sheets' rows y0..y1 drawn dy down at width w: the left part to its right end, plain stone repeated for the rest
-- (cut short of the right end when narrower), the right end last.
local function HRun(y0, y1, dy, w)
    local extra = w - ART_W
    if extra >= 0 then
        Slice(0, y0, RIGHT_END, y1, 0, dy)
        for x = RIGHT_END, RIGHT_END + extra - 1, FILL_R - FILL_L do
            Slice(FILL_L, y0, FILL_L + math.min(FILL_R - FILL_L, RIGHT_END + extra - x), y1, x, dy)
        end
    else
        Slice(0, y0, RIGHT_END + extra, y1, 0, dy)
    end
    Slice(RIGHT_END, y0, ART_W, y1, w - (ART_W - RIGHT_END), dy)
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
    local inner = H - HOLE_T - (ART_H - HOLE_B)
    HRun(0, HOLE_T, 0, W)
    HRun(HOLE_B, ART_H, H - (ART_H - HOLE_B), W)
    VRun(0, HOLE_L, 0, inner)
    VRun(HOLE_R, ART_W, W - (ART_W - HOLE_R), inner)
    local kx = w / NATIVE_W
    Slice(HOLE_L, HOLE_T, DIV_L, BAND_T, HOLE_L, HOLE_T, 0, kx, h / NATIVE_H)
    Slice(DIV_L, DIV_T, DIV_R, DIV_B, splitX, DIV_T, 1, 1, (H - DIV_T - (ART_H - DIV_B)) / (DIV_B - DIV_T))
    LayColumn(splitX + DIV_R - DIV_L, shape.listW, inner)
    Slice(HOLE_L, BAND_T, DIV_L, BAND_B, HOLE_L, splitY, 0, kx, 1)
    Slice(HOLE_L, BAND_B, DIV_L, PAGES_B, HOLE_L, splitY + BAND_B - BAND_T, 0, kx, shape.pagesH / (PAGES_B - BAND_B))
    art.paneBack:Hide()
    art:SetSize(W, H)
    header:SetWidth(W)
end

-- How far the right end moves out for the pane, in the sheets' units: the divider and the pane's width.
function LM.Widen(paneW) return PANE_X - HOLE_R + paneW / K end

local function Lay(paneW, shape)
    used = 0
    if shape then
        LayCombined(shape)
    elseif not paneW then
        Slice(0, 0, ART_W, ART_H, 0, 0)
        art.paneBack:Hide()
    else
        local widen = LM.Widen(paneW)
        Slice(0, 0, RIGHT_END, ART_H, 0, 0)
        for x = RIGHT_END, RIGHT_END + widen - 1, FILL_R - FILL_L do
            local w = math.min(FILL_R - FILL_L, RIGHT_END + widen - x)
            Slice(FILL_L, 0, FILL_L + w, HOLE_T, x, 0)
            Slice(FILL_L, HOLE_B, FILL_L + w, ART_H, x, HOLE_B)
        end
        Slice(RIGHT_END, 0, ART_W, HOLE_T, RIGHT_END + widen, 0)
        Slice(RIGHT_END, HOLE_B, ART_W, ART_H, RIGHT_END + widen, HOLE_B)
        Slice(HOLE_R, HOLE_T, ART_W, HOLE_B, HOLE_R + widen, HOLE_T)
        Slice(DIV_L, DIV_T, DIV_R, DIV_B, DIV_X, DIV_T, 1)
        art.paneBack:ClearAllPoints()
        art.paneBack:SetPoint("TOPLEFT", art, "TOPLEFT", PANE_X, -HOLE_T)
        art.paneBack:SetPoint("BOTTOMRIGHT", art, "TOPLEFT", HOLE_R + widen, -HOLE_B)
        art.paneBack:Show()
    end
    for i = used + 1, #textures do textures[i]:Hide() end
    if shape then return end
    art:SetSize(ART_W + (paneW and LM.Widen(paneW) or 0), ART_H)
    header:SetWidth(ART_W)
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

local function Dropdown(parent, label, menu)
    local dd = ns.NewFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    dd:SetSize(DROP_W, DROP_H)
    ns.EraDropdownArt(dd, -1, -1, -24)
    if dd.Text then dd.Text:SetFontObject("GameFontHighlightSmall") end
    if dd.SetDefaultText then dd:SetDefaultText("") end
    dd:SetupMenu(menu)
    local text = dd:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("TOPLEFT", dd, "TOPLEFT", 0, LABEL_Y)
    text:SetText(label)
    return dd
end

local function Header(map)
    header = ns.NewFrame("Frame", nil, map.BorderFrame)
    header:SetScale(K)
    header:SetSize(ART_W, HOLE_T)
    header:SetPoint("TOPLEFT", map, "TOPLEFT", 0, 0)
    header.title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header.title:SetPoint("CENTER", header, "TOP", 0, TITLE_Y)
    header.title:SetText(WORLDMAP_BUTTON or WORLD_MAP)
    header.continent = Dropdown(header, CONTINENT, ContinentMenu)
    header.continent:SetPoint("TOPLEFT", header, "TOP", DROP_X - DROP_W / 2, DROP_Y)
    header.zone = Dropdown(header, ZONE, ZoneMenu)
    header.zone:SetPoint("LEFT", header.continent, "RIGHT", DROP_GAP, 0)
    header.zoomOut = ns.PanelButton(header, ZOOM_OUT, ZOOM_W)
    header.zoomOut:SetHeight(ZOOM_H)
    header.zoomOut:SetPoint("LEFT", header.zone, "RIGHT", DROP_GAP, ZOOM_Y)
    header.zoomOut:SetScript("OnClick", ZoomOut)
end

-- Era's zoom note over the picture's top left: a click on it zooms out too.
local function Note(map)
    over = ns.NewFrame("Frame", nil, map)
    over:SetScale(K)
    over:SetSize(ART_W, ART_H)
    over:SetPoint("TOPLEFT", map, "TOPLEFT", 0, 0)
    local note = ns.NewFrame("Button", nil, over)
    note:SetSize(NOTE_W, NOTE_H)
    note:SetPoint("TOPLEFT", over, "TOPLEFT", ART_W / 2 + NOTE_X, NOTE_Y)
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
    if art then into[art], into[header], into[over] = true, true, true end
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

-- The window's size, the picture's box and the pane's, in the map's units from its top left (y down).
function LM.Size(paneW) return (ART_W + (paneW and LM.Widen(paneW) or 0)) * K, ART_H * K end
function LM.Picture() return HOLE_L * K, HOLE_T * K, HOLE_R * K, HOLE_B * K end
function LM.Pane(paneW) return PANE_X * K, HOLE_T * K, PANE_X * K + paneW, HOLE_B * K end

-- The combined layout's boxes for a shape, in the map's units from its top left (y down): the picture, the list
-- column, the left and right pages' parchment, the divider. One table, rebuilt as the shape changes.
local boxes, boxesFor = {}, nil
LM.NATIVE_SHARE, LM.NATIVE_LIST_W, LM.NATIVE_PAGES_H = NATIVE_W / PICTURE_W, LIST_R - LIST_L, PAGES_B - BAND_B
-- The window's width past the picture and list, and its height past the picture and pages (the map's units).
LM.SIDE_ROOM, LM.FOOT_ROOM = (HOLE_L + DIV_R - DIV_L + ART_W - HOLE_R) * K, (HOLE_T + BAND_B - BAND_T + ART_H - HOLE_B) * K
function LM.ClampShare(share) return math.max(SHARE_MIN, math.min(SHARE_MAX, share or LM.NATIVE_SHARE)) end
function LM.CombinedSize(shape)
    local W, H = CombinedSize(shape)
    return W * K, H * K
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
-- (+ up), in the sheets' units; clear of the unlocked map's corner grip.
local CLASSIC_MAP_OPTIONS_X = -3
local CLASSIC_MAP_OPTIONS_Y = 5
function LM.FootSpot()
    local x = math.min(CLASSIC_MAP_OPTIONS_X, -ns.WindowGripRoom("map"))
    return art, art:GetWidth() + x, CLASSIC_MAP_OPTIONS_Y - art:GetHeight()
end

-- The footer's left: the picture's left edge, the art's bottom.
function LM.FootLeft() return art, HOLE_L, -art:GetHeight() end
