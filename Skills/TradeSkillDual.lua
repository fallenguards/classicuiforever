local _, ns = ...

-- The trade skill window's two shapes (Skills/TradeSkill.lua): Era's single pane, the list over the detail, and the
-- double pane, the list beside the detail in the 3.x quest log's double frame, its panes in stone. Every spot here.

local D = {}
ns.tradeDual = D

local ROW_H = 16
D.ROWS = 19
local LEFT, RIGHT = "questLogDualLeft", "questLogDualRight"
-- The double frame in the page's units: its art less 12 across and 13 down, as Era's frame (TradeSkillExtras.lua).
local W, H = 668, 426

-- Spots in the page's units. rank: its top left, then its right end (single) or width (double); bar: x, top, bottom;
-- detail: the scroll's corners; foot: each button's left and width (single: chained from Create All and Exit).
local SINGLE = { rows = 8, rank = { 61, -24 }, rankRight = -9, list = { 10, -83 }, listW = 316, listWBar = 293,
    bar = { 311, -99, -197 }, all = { 14, -62 }, filter = { -11, -52 }, search = { 75, -57 },
    detail = { 8, -221, 305, -397 } }
local DOUBLE = { rows = D.ROWS, rank = { 61, -32 }, rankW = 268, list = { 8, -84 }, listW = 296, listWBar = 296,
    bar = { 313, -77, -379 }, all = { 12, -64 }, search = { 350, -32 },
    detail = { 336, -61, 636, -395 },
    -- Each button from the middle of its box's rims to the other's, across and down (the boxes' rims, art 410 to 435).
    foot = { y = 6, h = 21, createAll = { 6, 109 }, create = { 211, 99 }, exit = { 581, 81 } } }
-- The double pane's filter: its top right from the window's (+ right, + up), as tall as the search box and on its line.
local FILTER_RIGHT = -16
local FILTER_TOP = -26
local FILTER_WIDTH = 118
local FILTER_HEIGHT = 31
-- The count row in the middle foot box, as the 3.x frame: arrows at its rims, the box between (+ right, + up). The
-- box's border starts 5 left of QUANTITY_BOX_X.
local QUANTITY_LEFT_ARROW_X = 117
local QUANTITY_LEFT_ARROW_Y = 6
local QUANTITY_LEFT_ARROW_WIDTH = 23
local QUANTITY_LEFT_ARROW_HEIGHT = 22
local QUANTITY_RIGHT_ARROW_X = 187
local QUANTITY_RIGHT_ARROW_Y = 6
local QUANTITY_RIGHT_ARROW_WIDTH = 23
local QUANTITY_RIGHT_ARROW_HEIGHT = 22
local QUANTITY_BOX_X = 144
local QUANTITY_BOX_Y = 7
local QUANTITY_BOX_WIDTH = 44
local QUANTITY_BOX_HEIGHT = 19
local QUANTITY_TEXT_X = 0
-- The single pane's: Era's arrows and count box, the filter's size.
local ARROW_W, ARROW_H, BOX_W, BOX_H = 23, 22, 30, 20
local SINGLE_FILTER_W, SINGLE_FILTER_H = 118, 27
-- The panes' dark marble fills, each edge over the parchment's to its rim (+ right, + up).
local LIST_PANE_LEFT = 8
local LIST_PANE_TOP = -61
local LIST_PANE_RIGHT = 307
local LIST_PANE_BOTTOM = -396
local DETAIL_PANE_LEFT = 335
local DETAIL_PANE_TOP = -61
local DETAIL_PANE_RIGHT = 639
local DETAIL_PANE_BOTTOM = -398
local PANES = { { LIST_PANE_LEFT, LIST_PANE_TOP, LIST_PANE_RIGHT, LIST_PANE_BOTTOM },
    { DETAIL_PANE_LEFT, DETAIL_PANE_TOP, DETAIL_PANE_RIGHT, DETAIL_PANE_BOTTOM } }

-- Forever: laid on Era's frame's spot (Skills/ProfessionsBookFrame.lua).
D.FRAME_ART = {
    { key = LEFT, layer = "BACKGROUND", w = 512, h = 512, point = "TOPLEFT" },
    { key = RIGHT, layer = "BACKGROUND", w = 256, h = 512, point = "TOPLEFT", x = 512 },
}

-- Retail, under the window's own border as Era's (TradeSkillExtras.lua): from under the title strip, past the ring.
local function Cut(key, fileW, fileX, x0, y0, x1, y1)
    return { key = key, layer = "BACKGROUND", w = x1 - x0, h = y1 - y0, point = "TOPLEFT", x = x0 - 12, y = 13 - y0,
        coords = { (x0 - fileX) / fileW, (x1 - fileX) / fileW, y0 / 512, y1 / 512 } }
end
local WINDOW_ART = {
    Cut(LEFT, 512, 0, 72, 34, 512, 439),
    Cut(LEFT, 512, 0, 12, 67, 72, 439),
    Cut(RIGHT, 256, 512, 512, 34, 679, 439),
}

local dual = false
function D.On() return dual end
function D.Size(singleW, singleH)
    if dual then return W, H end
    return singleW, singleH
end

local function Shown(list, on)
    for _, tex in ipairs(list or ns.EMPTY) do tex:SetShown(on) end
end

local function Box(region, panel, x0, y0, x1, y1)
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", panel, "TOPLEFT", x0, y0)
    region:SetPoint("BOTTOMRIGHT", panel, "TOPLEFT", x1, y1)
end

local function DualArt(panel)
    if panel.dualFills then return end
    panel.dualFills = {}
    for i, r in ipairs(PANES) do
        local tex = ns.TileTex(panel:CreateTexture(nil, "BACKGROUND", nil, 2), "marbleBg", nil, ns.PANE_SHADE)
        Box(tex, panel, r[1], r[2], r[3], r[4])
        panel.dualFills[i] = tex
    end
    if not ns.OnForever() then panel.dualWindow = ns.DressPieces(panel, WINDOW_ART, nil, true) end
end

-- The list's rows for the shape: the first n of all built, the rest hidden.
local function Rows(panel, n)
    panel.allRows = panel.allRows or panel.rows
    local rows = {}
    for i, row in ipairs(panel.allRows) do
        if i <= n then rows[i] = row else row:Hide() end
    end
    panel.rows = rows
end

-- The count box's art: its ends as tall as the box, its middle stretched between them in the double pane, Era's 19 wide
-- in the single.
local function CountBox(count, width, height, textX, stretch)
    count:SetSize(width, height)
    count:SetTextInsets(textX, 0, 0, 0)
    count.Left:SetHeight(height)
    count.Right:SetHeight(height)
    local middle = count.Middle
    ns.SetPointOnce(middle, "TOPLEFT", count, "TOPLEFT", 3, 0)
    if stretch then
        middle:SetPoint("BOTTOMRIGHT", count.Right, "BOTTOMLEFT", 0, 0)
    else
        middle:SetSize(19, height)
    end
end

local function Foot(panel, s)
    local foot = s.foot
    local createAll, create, exit, dec, inc = panel.createAll, panel.create, panel.exit, panel.dec, panel.inc
    local count = panel.count
    createAll:ClearAllPoints()
    create:ClearAllPoints()
    exit:ClearAllPoints()
    dec:ClearAllPoints()
    inc:ClearAllPoints()
    count:ClearAllPoints()
    local h = foot and foot.h or 22
    createAll:SetHeight(h)
    create:SetHeight(h)
    exit:SetHeight(h)
    if foot then
        createAll:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", foot.createAll[1], foot.y)
        createAll:SetWidth(foot.createAll[2])
        dec:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", QUANTITY_LEFT_ARROW_X, QUANTITY_LEFT_ARROW_Y)
        dec:SetSize(QUANTITY_LEFT_ARROW_WIDTH, QUANTITY_LEFT_ARROW_HEIGHT)
        inc:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", QUANTITY_RIGHT_ARROW_X, QUANTITY_RIGHT_ARROW_Y)
        inc:SetSize(QUANTITY_RIGHT_ARROW_WIDTH, QUANTITY_RIGHT_ARROW_HEIGHT)
        count:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", QUANTITY_BOX_X, QUANTITY_BOX_Y)
        CountBox(count, QUANTITY_BOX_WIDTH, QUANTITY_BOX_HEIGHT, QUANTITY_TEXT_X, true)
        create:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", foot.create[1], foot.y)
        create:SetWidth(foot.create[2])
        exit:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", foot.exit[1], foot.y)
        exit:SetWidth(foot.exit[2])
        return
    end
    createAll:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 6, 4)
    createAll:SetWidth(80)
    dec:SetPoint("LEFT", createAll, "RIGHT", 3, 0)
    dec:SetSize(ARROW_W, ARROW_H)
    inc:SetSize(ARROW_W, ARROW_H)
    count:SetPoint("LEFT", dec, "RIGHT", 4, 0)
    CountBox(count, BOX_W, BOX_H, 0, false)
    exit:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -5, 4)
    exit:SetWidth(80)
    create:SetPoint("RIGHT", exit, "LEFT", -1, 0)
    create:SetWidth(80)
    inc:SetPoint("RIGHT", create, "LEFT", -3, 0)
end

-- Places the page in the shape picked; the caller draws the list and detail again.
function D.Layout(panel)
    local s = dual and DOUBLE or SINGLE
    if dual then DualArt(panel) end
    if panel.singleSize then panel:SetSize(D.Size(panel.singleSize[1], panel.singleSize[2])) end
    Shown(panel.dualFills, dual)
    Shown(panel.dualWindow, dual)
    Shown(panel.eraWindow, not dual)
    Shown(panel.eraOverlays, not dual)
    Shown(panel.bar.column, not dual)
    Shown(panel.detailBar.column, not dual)
    local rank = panel.rank
    if s.rankW then
        ns.SetPointOnce(rank, "TOPLEFT", panel, "TOPLEFT", s.rank[1], s.rank[2])
        rank:SetWidth(s.rankW)
    else
        rank:ClearAllPoints()
        rank:SetPoint("TOPLEFT", panel, "TOPLEFT", s.rank[1], s.rank[2])
        rank:SetPoint("RIGHT", panel, "RIGHT", panel.rankRight or s.rankRight, 0)
    end
    Rows(panel, s.rows)
    panel.listW, panel.listWBar = s.listW, s.listWBar
    ns.SetPointOnce(panel.list, "TOPLEFT", panel, "TOPLEFT", s.list[1], s.list[2])
    panel.list:SetSize(s.listW, s.rows * ROW_H)
    panel.listBox:SetHeight(s.rows * ROW_H + 25)
    local bar = panel.bar
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", panel, "TOPLEFT", s.bar[1], s.bar[2])
    bar:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", s.bar[1], s.bar[3])
    ns.SetPointOnce(panel.collapseAll, "TOPLEFT", panel, "TOPLEFT", s.all[1], s.all[2])
    if dual then
        ns.SetPointOnce(panel.filter, "TOPRIGHT", panel, "TOPRIGHT", FILTER_RIGHT, FILTER_TOP)
        panel.filter:SetSize(FILTER_WIDTH, FILTER_HEIGHT)
    else
        ns.SetPointOnce(panel.filter, "TOPRIGHT", panel, "TOPRIGHT", s.filter[1], s.filter[2])
        panel.filter:SetSize(SINGLE_FILTER_W, SINGLE_FILTER_H)
    end
    local search = panel.search
    search:ClearAllPoints()
    search:SetPoint("TOPLEFT", panel, "TOPLEFT", s.search[1], s.search[2])
    search:SetPoint("RIGHT", panel.filter, "LEFT", -14, 0)
    Box(panel.detailScroll, panel, s.detail[1], s.detail[2], s.detail[3], s.detail[4])
    Foot(panel, s)
end

-- The page built: its shape now and its redraw for a switch.
function D.Built(panel, refresh)
    D.panel, D.refresh = panel, refresh
    D.Layout(panel)
end

local function Set(on)
    on = on and true or false
    if dual == on then return end
    dual = on
    local panel = D.panel
    if panel then
        D.Layout(panel)
        if panel:IsShown() then D.refresh() end
    end
    -- The window takes the new size on the watch's next pass.
    if ns.OnForever() and ns.StartProfessionsWatch then ns.StartProfessionsWatch() end
end

ns.RegisterModule("tradeSkillDual", { apply = function() Set(true) end, restore = function() Set(false) end })
