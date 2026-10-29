local _, ns = ...
if not ns.PACKAGE then return end
local L = ns.L

-- A standalone piece's settings: one page of the full window's rows (O.BuildRows) in sections, sized to them, with
-- Era's Interface Options tabs on its box for Profiles, FAQ and Support; the options calls reach it through O.Window.

local O = ns.options
local EMPTY = ns.EMPTY
local ROW, INDENT = O.ROW, O.INDENT
-- The full window's column: every row's text fits it there.
local COL_W, COL_GAP = 272, 16
local BOX_X, PAD, LIST_TOP, BAR_ROOM = 16, 12, 10, 28
local TAB_TOP, TAB_H, TAB_SIDE, TAB_OVERLAP, TAB_INSET = 30, 24, 20, 16, 6
local BOX_TOP = TAB_TOP + TAB_H - 2
local FOOT_H, FOOT_Y = 40, 14
-- Two columns past ONE_COLUMN lines, three where two would pass MAX_LINES; past that a column scrolls under a search.
-- The Settings tab is as tall as its rows (SETTINGS_MIN at least); a reading tab takes READ_LINES, the top kept.
local ONE_COLUMN, MAX_LINES, SETTINGS_MIN, READ_LINES = 20, 24, 3, 12
-- A page from the full window with fewer rows than this joins the first section instead of heading its own.
local SECTION_MIN = 3
local SEARCH_W = 150
local TAB_COORDS = { { 0, 0.15625 }, { 0.15625, 0.84375 }, { 0.84375, 1 } }
local SETTINGS_TAB = L["OPTWIN_TAB_SETTINGS"]
local TABS = { { SETTINGS_TAB }, { L["OPTWIN_TAB_PROFILES"], "ProfilesPane" }, { L["OPTWIN_TAB_FAQ"], "FaqPane" },
    { L["OPTWIN_TAB_SUPPORT"], "SupportPane" } }
-- The piece's own name over the window ("ClassicUI Forever: Standalone Nameplates" is its addon list title).
local NAME = O.TITLE:match(":%s*Standalone%s+(.+)$") or O.TITLE

local function Shown(row) return not (row.hideIf and row.hideIf()) end

local function Lines(built, row)
    if not Shown(row) then return 0 end
    local n = 1
    for _, kid in ipairs(built.kids[row.key] or EMPTY) do n = n + Lines(built, kid) end
    return n
end

-- The page's sections in list order ({ title, rows }: top-level rows) and the minimap button's row for the foot. A page
-- the piece lists, or one of SECTION_MIN rows, is a section; the rest join the first section's end.
function O.PiecePlan(built, pkg)
    local own, minimap = {}, L["GROUP_MINIMAP"]
    for _, id in ipairs(pkg.pages or EMPTY) do own[L[id]] = true end
    local pages, tops = {}, {}
    for _, row in ipairs(built.rows) do
        -- setting: All windows' copy of a row with a section of its own.
        if not row.parent and not row.setting then
            if not tops[row.page] then
                tops[row.page] = {}
                pages[#pages + 1] = row.page
            end
            table.insert(tops[row.page], row)
        end
    end
    local foot
    if not own[minimap] then
        for i, row in ipairs(tops[minimap] or EMPTY) do
            if row.key == "minimapButton" then foot = table.remove(tops[minimap], i) break end
        end
    end
    local sections, joined = {}, {}
    for _, page in ipairs(pages) do
        local n = 0
        for _, row in ipairs(tops[page]) do
            if not row.sub then n = n + Lines(built, row) end
        end
        if own[page] or n >= SECTION_MIN then
            -- All windows in a piece lists only its own windows.
            local title = page == L["GROUP_ALL_WINDOWS"] and L["UI_WINDOWS"] or page
            sections[#sections + 1] = { title = title, rows = tops[page] }
        else
            -- A joining page's sub-headings head nothing.
            for _, row in ipairs(tops[page]) do
                if not row.sub then joined[#joined + 1] = row end
            end
        end
    end
    if not sections[1] then sections[1] = { rows = {} } end
    for _, row in ipairs(joined) do table.insert(sections[1].rows, row) end
    return sections, foot
end

-- The page as blocks kept whole in a column: a top-level row with every row under it, a top-level sub-heading with the
-- rows after it; a section's title ({ head = title }, only with more than one) leads its first block. hit: a search's.
function O.PieceBlocks(built, sections, hit)
    local blocks = {}
    local function Visible(row) return Shown(row) and (not hit or hit[row.key]) end
    local function NewBlock(sub)
        local block = { sub = sub }
        blocks[#blocks + 1] = block
        return block
    end
    -- A sub-heading under a row starts a block too, as on the full window: the columns may split before it.
    local function Walk(block, row)
        block[#block + 1] = row
        for _, kid in ipairs(built.kids[row.key] or EMPTY) do
            if Visible(kid) then
                if kid.sub then block = NewBlock(true) end
                block = Walk(block, kid)
            end
        end
        return block
    end
    for _, section in ipairs(sections) do
        local first, block = #blocks + 1, nil
        for _, row in ipairs(section.rows) do
            if Visible(row) then
                if row.sub or not (block and block.sub) then block = NewBlock(row.sub) end
                block = Walk(block, row)
            end
        end
        -- A sub-heading left with no rows under it.
        for i = #blocks, first, -1 do
            if #blocks[i] == 1 and blocks[i].sub then table.remove(blocks, i) end
        end
        if #sections > 1 and blocks[first] then table.insert(blocks[first], 1, { head = section.title }) end
    end
    return blocks
end

-- The blocks in order over columns, the tallest as short as it can be: each column's first block, and its lines.
function O.PieceSplit(blocks, columns)
    local n, sum = #blocks, { [0] = 0 }
    for i = 1, n do sum[i] = sum[i - 1] + #blocks[i] end
    -- best[c][i]: the tallest of c columns holding blocks 1 to i; from[c][i]: the block the last of them starts at.
    local best, from = { {} }, { {} }
    for i = 0, n do best[1][i], from[1][i] = sum[i], 1 end
    for c = 2, columns do
        best[c], from[c] = {}, {}
        for i = 0, n do
            best[c][i], from[c][i] = best[c - 1][i], i + 1
            for j = 1, i do
                local tall = math.max(best[c - 1][j - 1], sum[i] - sum[j - 1])
                if tall < best[c][i] then best[c][i], from[c][i] = tall, j end
            end
        end
    end
    local starts, i = { 1 }, n
    for c = columns, 2, -1 do
        starts[c] = from[c][i]
        i = starts[c] - 1
    end
    return starts, best[columns][n]
end

-- A section's title: gold over a rule to the column's edge.
local function Head(frame, title)
    local head = frame.heads[title]
    if head then return head end
    head = ns.NewFrame("Frame", nil, frame.child)
    head:SetSize(COL_W - 8, ROW)
    local text = head:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    text:SetPoint("LEFT", head, "LEFT", 2, 0)
    text:SetText(title)
    local line = head:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(unpack(O.LINE_COLOR))
    line:SetHeight(1)
    line:SetPoint("LEFT", text, "RIGHT", 8, 0)
    line:SetPoint("RIGHT", head, "RIGHT", 0, 0)
    head:Hide()
    frame.heads[title] = head
    return head
end

local function Clean(box) return ((box:GetText() or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")) end

-- A search's rows and its best matches, as the full window finds them; nil while empty.
local function Hits(built, text)
    if text == "" then return nil, nil end
    local words = {}
    for word in text:gmatch("%S+") do words[#words + 1] = word:gsub("%p", "%%%0") end
    local level, best = {}, 0
    for _, row in ipairs(built.rows) do
        level[row] = ns.OptionMatchLevel(row, words)
        if level[row] > best then best = level[row] end
    end
    local matched = {}
    for _, row in ipairs(built.rows) do matched[row] = best > 0 and level[row] == best end
    return ns.OptionSearchHits(built.rows, matched, built.parentOf, true, words), matched
end

local function Lay(frame)
    local built, child = frame.built, frame.child
    local text = frame.search and Clean(frame.search) or ""
    local hit, matched = Hits(built, text)
    for _, row in ipairs(built.rows) do
        if row ~= frame.foot then row:Hide() end
    end
    for _, head in pairs(frame.heads) do head:Hide() end
    local blocks = O.PieceBlocks(built, frame.sections, hit)
    local starts = O.PieceSplit(blocks, frame.columns)
    local column, y, tallest = 1, 0, 0
    for i, block in ipairs(blocks) do
        while starts[column + 1] and i >= starts[column + 1] do column, y = column + 1, 0 end
        for _, line in ipairs(block) do
            local region = line.head and Head(frame, line.head) or line
            local x = (column - 1) * (COL_W + COL_GAP) + (line.head and 0 or (line.depth or 0) * INDENT)
            ns.SetPointOnce(region, "TOPLEFT", child, "TOPLEFT", x, -y * ROW)
            region.listAt = y
            region:Show()
            if region.keyLow then O.ShowMatch(region, matched ~= nil and matched[region] == true) end
            y = y + 1
            if y > tallest then tallest = y end
        end
    end
    child:SetHeight(math.max(1, tallest * ROW))
    frame.bar:SetRange(math.max(0, tallest * ROW - frame.list:GetHeight()), ROW)
end

local function SetTabPicked(tab, picked, box)
    local left, middle, right = unpack(tab.pieces)
    for i, piece in ipairs(tab.pieces) do
        ns.SetTex(piece, picked and "optionsTabActive" or "optionsTabInactive")
        piece:SetTexCoord(TAB_COORDS[i][1], TAB_COORDS[i][2], 0, 1)
    end
    -- Era's picked tab hangs 3 lower, over the box's edge.
    local drop = picked and -3 or 0
    ns.SetPointOnce(left, "BOTTOMLEFT", tab, "BOTTOMLEFT", 0, drop)
    ns.SetPointOnce(right, "BOTTOMRIGHT", tab, "BOTTOMRIGHT", 0, drop)
    middle:ClearAllPoints()
    middle:SetPoint("TOPLEFT", left, "TOPRIGHT")
    middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
    tab.text:SetFontObject(picked and "GameFontHighlightSmall" or "GameFontNormalSmall")
    ns.SetPointOnce(tab.text, "CENTER", tab, "CENTER", 0, picked and -2 or -3)
    tab:SetFrameLevel(box:GetFrameLevel() + (picked and 2 or -1))
end

-- Era's OptionsFrameTabButtonTemplate: its two sides and a middle as wide as the label needs.
local function Tabs(frame, box)
    frame.tabs = {}
    local prev
    for i, spec in ipairs(TABS) do
        local tab = ns.NewFrame("Button", nil, frame)
        tab:SetHeight(TAB_H)
        tab.text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        tab.text:SetText(spec[1])
        tab:SetWidth(math.ceil(tab.text:GetStringWidth()) + 2 * TAB_SIDE)
        tab.pieces = {}
        for p = 1, 3 do
            tab.pieces[p] = tab:CreateTexture(nil, "BACKGROUND")
            tab.pieces[p]:SetSize(TAB_SIDE, TAB_H)
        end
        local glow = tab:CreateTexture(nil, "HIGHLIGHT")
        ns.SetTex(glow, "topTabHighlight")
        glow:SetBlendMode("ADD")
        glow:SetPoint("TOPLEFT", tab, "TOPLEFT", 6, 2)
        glow:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -6, -4)
        if prev then
            tab:SetPoint("LEFT", prev, "RIGHT", -TAB_OVERLAP, 0)
        else
            tab:SetPoint("BOTTOMLEFT", box, "TOPLEFT", TAB_INSET, -2)
        end
        tab:SetScript("OnClick", function() frame:ShowTab(i) end)
        frame.tabs[i], prev = tab, tab
    end
end

-- The tabs' row with the search beside it: the window is at least this wide.
local function TabsWidth(frame, searching)
    local w = TAB_INSET
    for i, tab in ipairs(frame.tabs) do w = w + tab:GetWidth() - (i > 1 and TAB_OVERLAP or 0) end
    return w + (searching and SEARCH_W + 16 or 0) + 8
end

-- Our windows that move (band pieces are the game's edit mode's): Reset windows puts them back.
local function HasWindows()
    for _, entry in ipairs(ns.WINDOW_LIST or EMPTY) do
        if not entry.piece then return true end
    end
    return false
end

local confirmReset = O.BoxConfirm("ForeverClassicUIPieceResetConfirm", L["OPTWIN_PAGE_RESET_CONFIRM"]:format(SETTINGS_TAB),
    L["OPTWIN_RESET_SCALE"], function() return L["OPTWIN_RESET_SCALE_TIP"]:format(ns.EraScalePercent() or 90) end)

local function ResetAll(frame)
    confirmReset(ns.EraScaleWanted and ns.EraScaleWanted() or false, function(scale)
        ns.ResetToggles(nil)
        for _, row in ipairs(frame.built.rows) do
            if row.reset then row.reset() end
        end
        ns.ApplyAll()
        ns.AskReloadIfNeeded()
        if scale then ns.UseEraScale() end
        frame:Refresh(true)
    end)
end

local function Tip(region, label, tooltip)
    region.label, region.tooltip = label, tooltip
    ns.AttachTip(region, O.OPTION_TIP)
end

-- The foot under the settings: the minimap button's box at the left, Default toggles (and Reset windows) at the right.
local function Foot(frame)
    frame.footRegions = {}
    local foot = frame.foot
    if foot then
        foot:SetParent(frame)
        ns.SetPointOnce(foot, "BOTTOMLEFT", frame, "BOTTOMLEFT", BOX_X + 2, FOOT_Y - 1)
        foot.listAt = nil
        frame.footRegions[1] = foot
    end
    local reset = ns.PanelButton(frame, L["OPTWIN_RESET_TOGGLES"], 110)
    reset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -BOX_X, FOOT_Y)
    reset:SetScript("OnClick", function() ResetAll(frame) end)
    Tip(reset, L["OPTWIN_RESET_TOGGLES"], L["OPTWIN_PAGE_RESET_TIP"])
    frame.footRegions[#frame.footRegions + 1] = reset
    if HasWindows() then
        local windows = ns.PanelButton(frame, L["OPTWIN_RESET_WINDOWS"], 110)
        windows:SetPoint("RIGHT", reset, "LEFT", -6, 0)
        windows:SetScript("OnClick", function() StaticPopup_Show("FCUI_WINDOWS_RESET") end)
        Tip(windows, L["OPTWIN_RESET_WINDOWS"], L["OPTWIN_PUTS_EVERY_WINDOW_BACK"])
        frame.footRegions[#frame.footRegions + 1] = windows
    end
end

-- The page's shape from its blocks, unsearched: columns, the taller column's lines, and whether it scrolls.
function O.PieceShape(blocks)
    local _, total = O.PieceSplit(blocks, 1)
    local columns = total > ONE_COLUMN and 2 or 1
    local _, tallest = O.PieceSplit(blocks, columns)
    if tallest > MAX_LINES then
        columns = 3
        _, tallest = O.PieceSplit(blocks, columns)
    end
    return columns, tallest, tallest > MAX_LINES
end

local function Measure(frame)
    local columns, tallest, scrolls = O.PieceShape(O.PieceBlocks(frame.built, frame.sections))
    frame.columns, frame.scrolls = columns, scrolls
    frame.lines = math.max(SETTINGS_MIN, math.min(tallest, MAX_LINES))
end

-- A new height with the top kept where it is.
local function Resize(frame, height)
    if math.abs(frame:GetHeight() - height) < 0.5 then return end
    local left, top = frame:GetLeft(), frame:GetTop()
    frame:SetHeight(height)
    if left and top and not O.Embedded() then ns.SetPointOnce(frame, "TOPLEFT", UIParent, "BOTTOMLEFT", left, top) end
end

local function Show(frame)
    local pane = frame.panes[frame.tab]
    for i, tab in ipairs(frame.tabs) do SetTabPicked(tab, i == frame.tab, frame.box) end
    for _, other in pairs(frame.panes) do
        other:SetShown(other == pane)
        other.child:SetShown(other == pane)
    end
    frame.child:SetShown(not pane)
    for _, region in ipairs(frame.footRegions) do region:SetShown(not pane) end
    if frame.search then frame.search:SetShown(not pane) end
    -- A reading tab takes the foot's room too.
    local lines = pane and math.max(frame.lines, READ_LINES) or frame.lines
    local boxH = LIST_TOP + lines * ROW + 8 + (pane and FOOT_H - 12 or 0)
    frame.box:SetHeight(boxH)
    Resize(frame, BOX_TOP + boxH + (pane and 12 or FOOT_H))
    local top = LIST_TOP + (pane and pane.headH or 0)
    ns.SetPointOnce(frame.list, "TOPLEFT", frame.box, "TOPLEFT", PAD, -top)
    frame.list:SetHeight(boxH - top - 8)
    local child = pane and pane.child or frame.child
    if frame.list:GetScrollChild() ~= child then frame.list:SetScrollChild(child) end
    if pane then pane:Refresh() else Lay(frame) end
end

local function Panes(frame, box)
    -- Where a reading tab puts its caption and buttons, over the list.
    local top = ns.NewFrame("Frame", nil, box)
    top:SetPoint("TOPLEFT", box, "TOPLEFT", PAD, -LIST_TOP)
    top:SetSize(frame.list:GetWidth(), 1)
    local function SetRange(h) frame.bar:SetRange(math.max(0, h - frame.list:GetHeight()), ROW) end
    frame.panes = {}
    for i, spec in ipairs(TABS) do
        if spec[2] then frame.panes[i] = O[spec[2]](box, top, frame.list, SetRange) end
    end
end

local function Build()
    local frame = O.OptionsFrame(NAME)
    local box = ns.NewFrame("Frame", nil, frame, "BackdropTemplate")
    ns.Backdrop(box, ns.BACKDROP.TIP16, O.BOX_LOOK)
    box:SetPoint("TOPLEFT", frame, "TOPLEFT", BOX_X, -BOX_TOP)
    box:SetFrameLevel(frame:GetFrameLevel() + 3)
    frame.box = box
    local list = ns.NewFrame("ScrollFrame", nil, box)
    list:SetClipsChildren(true)
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta) frame.bar:SetValue(frame.bar:GetValue() - delta * ROW) end)
    local child = ns.NewFrame("Frame", nil, list)
    list:SetScrollChild(child)
    frame.list, frame.child, frame.heads = list, child, {}

    frame.built = O.BuildRows(child, COL_W)
    frame.sections, frame.foot = O.PiecePlan(frame.built, ns.PACKAGE)
    Measure(frame)
    Tabs(frame, box)
    local content = frame.columns * COL_W + (frame.columns - 1) * COL_GAP
    local boxW = math.max(PAD + content + BAR_ROOM, TabsWidth(frame, frame.scrolls))
    box:SetWidth(boxW)
    frame:SetSize(boxW + 2 * BOX_X, BOX_TOP + LIST_TOP + frame.lines * ROW + 8 + FOOT_H)
    list:SetWidth(boxW - PAD - BAR_ROOM)
    child:SetSize(list:GetWidth(), 1)
    frame.bar = ns.ClassicScrollBar(box, list, function(value) list:SetVerticalScroll(value) end)
    frame.bar.hideWhenIdle = true
    if frame.scrolls then
        local search = ns.SearchBox(frame, SEARCH_W, L["OPTWIN_SEARCH_PAGE"])
        search:SetPoint("BOTTOMRIGHT", box, "TOPRIGHT", -8, 2)
        search:SetScript("OnTextChanged", function(self)
            self.hint:SetShown(self:GetText() == "")
            self.clear:SetShown(self:GetText() ~= "")
            frame.bar:SetValue(0)
            Lay(frame)
        end)
        frame.search = search
    end
    Foot(frame)
    Panes(frame, box)
    frame.tab = 1

    function frame:ShowTab(i)
        self.tab = i
        self.bar:SetValue(0)
        Show(self)
    end
    function frame:Refresh(keepScroll)
        O.RefreshRows(self.built)
        if not keepScroll then self.bar:SetValue(0) end
        Show(self)
        if keepScroll then self.list:SetVerticalScroll(self.bar:GetValue()) end
    end
    frame:SetScript("OnShow", function(self) self:Refresh() end)
    -- After SetScript, which would wipe its OnShow hooks; inside the game's settings its own Escape closes it.
    ns.CloseOnEscape(frame, nil, function() return not O.Embedded() end)
    return frame
end

-- Inside the game's settings: on its panel at the canvas's top left, scaled to its width.
local function Embed(frame, host)
    O.IntoHost(frame, host)
    local roomW = host:GetWidth() or 0
    frame:SetScale(roomW > 0 and math.min(1, roomW / frame:GetWidth()) or 1)
    ns.SetPointOnce(frame, "TOPLEFT", host, "TOPLEFT", -BOX_X, 0)
    frame:Show()
end

-- One row lit on the Settings tab, scrolled to it (EasyFind's search opens here); one setting's row.
local function ShowRow(frame, row)
    if frame.search and frame.search:GetText() ~= "" then frame.search:SetText("") end
    frame:ShowTab(1)
    O.ShowMatch(row, true)
    frame.bar:SetValue(math.max(0, ((row.listAt or 1) - 1) * ROW))
end

local function OpenAt(frame, key)
    for _, row in ipairs(frame.built.rows) do
        if (row.setting or row.key) == key and row.listAt then return ShowRow(frame, row) end
    end
end

O.Window = { Build = Build, Embed = Embed, StandAlone = O.OutOfHost, ShowRow = ShowRow, OpenAt = OpenAt }

-- The game's settings: one entry, no pages under it.
function ns.OptionsPageNames() return {} end
