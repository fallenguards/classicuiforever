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

-- The sheets' rect x0..x1, y0..y1 drawn with its top left at dx, dy, one texture per sheet it crosses.
local function Slice(x0, y0, x1, y1, dx, dy, sublevel)
    for col = math.floor(x0 / SHEET), math.floor((x1 - 1) / SHEET) do
        for row = math.floor(y0 / SHEET), math.floor((y1 - 1) / SHEET) do
            local l, r = math.max(x0, col * SHEET), math.min(x1, (col + 1) * SHEET)
            local t, b = math.max(y0, row * SHEET), math.min(y1, (row + 1) * SHEET)
            local tex = NextTexture("ARTWORK", sublevel)
            ns.SetFile(tex, SHEETS[row + 1][col + 1])
            tex:SetTexCoord((l - col * SHEET) / SHEET, (r - col * SHEET) / SHEET, (t - row * SHEET) / SHEET,
                (b - row * SHEET) / SHEET)
            tex:SetSize(r - l, b - t)
            tex:SetPoint("TOPLEFT", art, "TOPLEFT", dx + l - x0, -(dy + t - y0))
        end
    end
end

-- How far the right end moves out for the pane, in the sheets' units: the divider and the pane's width.
function LM.Widen(paneW) return PANE_X - HOLE_R + paneW / K end

local function Lay(paneW)
    used = 0
    if not paneW then
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
    art:SetSize(ART_W + (paneW and LM.Widen(paneW) or 0), ART_H)
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
    header.title:SetPoint("CENTER", header, "TOPLEFT", ART_W / 2, TITLE_Y)
    header.title:SetText(WORLDMAP_BUTTON or WORLD_MAP)
    header.continent = Dropdown(header, CONTINENT, ContinentMenu)
    header.continent:SetPoint("TOPLEFT", header, "TOPLEFT", ART_W / 2 + DROP_X - DROP_W / 2, DROP_Y)
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

-- paneW: the quest pane's width in the map's units, nil while it is shut.
function LM.Show(map, paneW, noteLevel)
    if laidPane ~= (paneW or false) then
        laidPane = paneW or false
        Lay(paneW)
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

-- Close and size buttons in the right end's two sockets, wherever the pane has moved it.
function LM.PlaceButtons(close, sizer, paneW)
    local right = (ART_W + (paneW and LM.Widen(paneW) or 0) + CLOSE_X) * K
    ns.SetSizeIf(close, CLOSE_SIZE * K, CLOSE_SIZE * K)
    ns.SetPointIf(close, "TOPRIGHT", art, "TOPLEFT", right, CLOSE_Y * K)
    if sizer then
        ns.SetScaleIf(sizer, K)
        ns.SetPointIf(sizer, "RIGHT", close, "LEFT", SIZER_X, 0)
    end
end

-- Map Options in Classic style: its box's right edge from the window's right (+ right), its bottom from the bottom
-- (+ up), in the sheets' units.
local CLASSIC_MAP_OPTIONS_X = -3
local CLASSIC_MAP_OPTIONS_Y = 5
function LM.FootSpot(paneW)
    return art, ART_W + (paneW and LM.Widen(paneW) or 0) + CLASSIC_MAP_OPTIONS_X, CLASSIC_MAP_OPTIONS_Y - ART_H
end
