local _, ns = ...
local L = ns.L

-- The /fcui options window: the pages down the left (the toggles' groups, then Profiles, FAQ and Support), the picked
-- one on the right; typing in the search lists the matches from every page. The game's settings page shows this same
-- window, moved in and scaled to its room.

local O = ns.options
local TITLE = O.TITLE
local EMPTY = ns.EMPTY
local ROW, INDENT = O.ROW, O.INDENT
local WIDTH, COLUMNS = 800, 2
local SIDE_X, SIDE_W = 20, 166
local PANE_X, PANE_TOP = 196, 34
local PANE_W = WIDTH - PANE_X - 20
local NAV_ROW, NAV_TOP, SEARCH_Y = 18, 64, 38
-- The game's settings' home page: its search row over the list, and the page it stands for.
local HOME_HEAD, HOME = 30, {}
-- The list inside the page box: under its title row, clear of the scroll bar.
local LIST_X, LIST_TOP = PANE_X + 12, PANE_TOP + 38
local LIST_W = PANE_W - 40
local NOTE_GAP = 8
-- A toggles page's foot: its Toggle none and Default toggles, the list ending above them; its own search at the top.
local PAGE_FOOT, PAGE_FOOT_Y, PAGE_SEARCH_W = 32, 9, 190
local LINE_COLOR = { 0.47, 0.47, 0.47, 0.63 }
-- The 1.x options boxes: the tooltip edge in grey over a dark fill.
local BOX_LOOK = { bg = { 0.15, 0.15, 0.15, 0.85 }, bgFirst = true, base = { 0.6, 0.6, 0.6, 1 } }
local TOPLEVEL = { toplevel = true }
local HIGHLIGHT = "Interface\\QuestFrame\\UI-QuestTitleHighlight"
-- After the toggles' pages, the reading pages: title key and builder.
local PANES = { { "OPTWIN_TAB_PROFILES", "ProfilesPane" }, { "OPTWIN_TAB_FAQ", "FaqPane" }, { "OPTWIN_TAB_SUPPORT", "SupportPane" } }

local window, embedded

-- keys: the toggles touched (nil: every one). Bulk writes skip ToggleChanged's per-key side effects on purpose; the
-- reload ask runs before Refresh reads it.
local function Finish()
    ns.ApplyAll()
    ns.AskReloadIfNeeded()
    if window then window:Refresh(true) end
end

local function TurnOff(keys)
    for _, entry in ipairs(ns.TOGGLES) do
        local key = entry[1]
        if (not keys or keys[key]) and O.InNone(key) then ns.db[key] = false end
    end
    -- A radio pick that is a classic piece: the game's own choice instead.
    for _, key in ipairs(O.NONE_PICKS) do
        if not keys or keys[key] then
            for _, other in ipairs(ns.TOGGLE_RADIO[key] or EMPTY) do ns.db[other] = other == key end
        end
    end
    Finish()
end

-- numbers: the number rows to put back too, through their setters so they apply live.
local function Reset(keys, numbers)
    ns.ResetToggles(keys)
    for _, row in ipairs(numbers) do row.reset() end
    Finish()
end

local function NumberRows(rows, page)
    local out = {}
    for _, row in ipairs(rows) do
        if row.reset and (not page or row.page == page) then out[#out + 1] = row end
    end
    return out
end

-- Toggle none and Default toggles for every page: the interface size's box in their confirms (#181). Toggle none's
-- while Era's size we set still stands; Default toggles' while the interface stands at another size than Era's.
local function ScalePercent()
    local scale = tonumber(ns.db.eraScale) or tonumber(ns.GetCVar("uiScale")) or 1
    return math.floor(scale * 100 + 0.5)
end

local confirmNone = O.BoxConfirm("ForeverClassicUINoneConfirm", L["OPTWIN_ALL_NONE_CONFIRM"], L["OPTWIN_NONE_SCALE"],
    function() return L["OPTWIN_NONE_SCALE_TIP"]:format(ScalePercent()) end)
local function ConfirmNone()
    confirmNone(ns.EraScaleOurs and ns.EraScaleOurs() or false, function(scale)
        TurnOff(nil)
        if scale then ns.EraScaleGiveBack() end
    end)
end

local confirmReset = O.BoxConfirm("ForeverClassicUIResetConfirm", L["OPTWIN_ALL_RESET_CONFIRM"], L["OPTWIN_RESET_SCALE"],
    function() return L["OPTWIN_RESET_SCALE_TIP"]:format(ns.EraScalePercent() or 90) end)
local function ConfirmReset()
    confirmReset(ns.EraScaleWanted and ns.EraScaleWanted() or false, function(scale)
        Reset(nil, window and NumberRows(window.built.rows) or EMPTY)
        if scale then ns.UseEraScale() end
    end)
end
-- A page's own: data holds its keys (and number rows for the reset); the text names the page.
ns.Popup("FCUI_PAGE_NONE", {
    text = L["OPTWIN_PAGE_NONE_CONFIRM"],
    button1 = OKAY,
    button2 = CANCEL,
    OnAccept = function(_, data) TurnOff(data.keys) end,
})
ns.Popup("FCUI_PAGE_RESET", {
    text = L["OPTWIN_PAGE_RESET_CONFIRM"],
    button1 = OKAY,
    button2 = CANCEL,
    OnAccept = function(_, data) Reset(data.keys, data.numbers) end,
})

local function Tip(region, label, tooltip)
    region.label, region.tooltip = label, tooltip
    ns.AttachTip(region, O.OPTION_TIP)
end

-- Every page's buttons: label, tooltip, popup.
local ALL_BUTTONS = {
    { "OPTWIN_TOGGLE_NONE", "OPTWIN_TURNS_EVERY_PIECE_OF_THE", ConfirmNone },
    { "OPTWIN_RESET_TOGGLES", "OPTWIN_PUTS_EVERY_CHECKBOX_AND_NUMBER", ConfirmReset },
    { "OPTWIN_RESET_WINDOWS", "OPTWIN_PUTS_EVERY_WINDOW_BACK", "FCUI_WINDOWS_RESET" },
}
local function AllPagesButton(parent, spec, width)
    local button = ns.PanelButton(parent, L[spec[1]], width)
    button:SetScript("OnClick", function()
        if type(spec[3]) == "function" then spec[3]() else StaticPopup_Show(spec[3]) end
    end)
    Tip(button, L[spec[1]], L[spec[2]])
    return button
end

-- Drawn on host (a box), placed from the window's corner.
local function Line(host, frame, x, y, w)
    local line = host:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(unpack(LINE_COLOR))
    line:SetSize(w, 1)
    line:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -y)
    return line
end

-- A page's name in the list: gold, white with the quest log's highlight while picked.
local function NavButton(box, frame, label, y, onClick)
    local button = ns.NewFrame("Button", nil, box)
    button:SetSize(SIDE_W - 12, NAV_ROW)
    button:SetPoint("TOPLEFT", frame, "TOPLEFT", SIDE_X + 6, -y)
    local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", button, "LEFT", 8, 0)
    text:SetText(label)
    button:SetFontString(text)
    button:SetHighlightTexture(HIGHLIGHT, "ADD")
    button:SetScript("OnClick", onClick)
    function button:SetPicked(on)
        text:SetFontObject(on and "GameFontHighlight" or "GameFontNormal")
        if on then self:LockHighlight() else self:UnlockHighlight() end
    end
    return button
end

-- The toggles' pages: their groups' titles in list order.
local function Pages()
    local pages = {}
    for _, entry in ipairs(ns.TOGGLES) do
        if entry.group then pages[#pages + 1] = entry.group end
    end
    return pages
end

-- The page list as wide as its longest name in the game's language (Italian runs long); the window grows as much.
local function FitNames(frame, pages)
    local probe = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    local names = { unpack(pages) }
    for _, spec in ipairs(PANES) do names[#names + 1] = L[spec[1]] end
    local widest = 0
    for _, name in ipairs(names) do
        probe:SetText(name)
        widest = math.max(widest, probe:GetStringWidth())
    end
    probe:Hide()
    local extra = math.max(0, math.ceil(widest - (SIDE_W - 26)))
    SIDE_W, PANE_X, WIDTH = SIDE_W + extra, PANE_X + extra, WIDTH + extra
    LIST_X = PANE_X + 12
end

-- The left side: search, then the pages' box with its All pages buttons at the foot. Returns its height.
local function Sidebar(frame, pages)
    local search = ns.SearchBox(frame, SIDE_W - 14, L["OPTWIN_SEARCH_TOGGLES"])
    search:SetPoint("TOPLEFT", frame, "TOPLEFT", SIDE_X + 8, -SEARCH_Y)
    frame.search = search

    local box = ns.NewFrame("Frame", nil, frame, "BackdropTemplate")
    ns.Backdrop(box, ns.BACKDROP.TIP16, BOX_LOOK)
    box:SetPoint("TOPLEFT", frame, "TOPLEFT", SIDE_X, -NAV_TOP)
    box:SetWidth(SIDE_W)
    frame.navBox = box
    frame.nav = {}
    local y = NAV_TOP + 9
    for _, page in ipairs(pages) do
        frame.nav[page] = NavButton(box, frame, page, y, function() frame:ShowPage(page) end)
        y = y + NAV_ROW
        if page == O.MASTER_PAGE then
            Line(box, frame, SIDE_X + 10, y + 4, SIDE_W - 20)
            y = y + 9
        end
    end
    Line(box, frame, SIDE_X + 10, y + 4, SIDE_W - 20)
    y = y + 9
    for _, spec in ipairs(PANES) do
        local name = L[spec[1]]
        frame.nav[name] = NavButton(box, frame, name, y, function() frame:ShowPage(name) end)
        y = y + NAV_ROW
    end
    -- All pages: its name in the middle of the line, the line broken round it.
    y = y + 9
    local head = box:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    head:SetPoint("CENTER", frame, "TOPLEFT", SIDE_X + SIDE_W / 2, -y)
    head:SetText(L["OPTWIN_ALL_PAGES"])
    local half = head:GetStringWidth() / 2 + 6
    Line(box, frame, SIDE_X + 10, y, SIDE_W / 2 - half - 10)
    Line(box, frame, SIDE_X + SIDE_W / 2 + half, y, SIDE_W / 2 - half - 10)
    y = y + 11
    for _, spec in ipairs(ALL_BUTTONS) do
        AllPagesButton(box, spec, SIDE_W - 20):SetPoint("TOPLEFT", frame, "TOPLEFT", SIDE_X + 10, -y)
        y = y + 26
    end
    box:SetHeight(y + 6 - NAV_TOP)
    return y + 6
end

-- The list's top under a reading page's header (headH), down to the box's foot, less a toggles page's buttons (foot).
local function FitList(frame, headH, foot)
    local list = frame.list
    ns.SetPointOnce(list, "TOPLEFT", frame, "TOPLEFT", LIST_X, -(LIST_TOP + headH))
    list:SetSize(LIST_W, frame.listBottom - LIST_TOP - headH - (foot or 0))
end

-- The window's foot (bottom): the page box and its list down to it.
local function SetFoot(frame, bottom)
    frame:SetHeight(bottom + 20)
    frame.pageBox:SetHeight(bottom - PANE_TOP)
    frame.listBottom = bottom - 8
end

-- The right side: the page's box, its title, the page's own Toggle none and Reset toggles, the scrolling list; its foot
-- level with the sidebar's (bottom).
local function PageArea(frame, bottom)
    local box = ns.NewFrame("Frame", nil, frame, "BackdropTemplate")
    ns.Backdrop(box, ns.BACKDROP.TIP16, BOX_LOOK)
    box:SetPoint("TOPLEFT", frame, "TOPLEFT", PANE_X, -PANE_TOP)
    box:SetSize(PANE_W, bottom - PANE_TOP)
    frame.pageBox = box
    local title = box:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", box, "TOPLEFT", 14, -12)
    frame.pageTitle = title
    local reset = ns.PanelButton(box, L["OPTWIN_RESET_TOGGLES"], 110)
    reset:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -12, PAGE_FOOT_Y)
    reset:SetScript("OnClick", function()
        local data = { keys = frame:PageKeys(), numbers = NumberRows(frame.built.rows, frame.page) }
        StaticPopup_Show("FCUI_PAGE_RESET", frame.page, nil, data)
    end)
    Tip(reset, L["OPTWIN_RESET_TOGGLES"], L["OPTWIN_PAGE_RESET_TIP"])
    local none = ns.PanelButton(box, L["OPTWIN_TOGGLE_NONE"], 110)
    none:SetPoint("RIGHT", reset, "LEFT", -6, 0)
    none:SetScript("OnClick", function() StaticPopup_Show("FCUI_PAGE_NONE", frame.page, nil, { keys = frame:PageKeys() }) end)
    Tip(none, L["OPTWIN_TOGGLE_NONE"], L["OPTWIN_PAGE_NONE_TIP"])
    frame.pageButtons = { none, reset }
    -- This page's own search, where its buttons stood: only its rows (the sidebar's searches every page).
    local find = ns.SearchBox(box, PAGE_SEARCH_W, L["OPTWIN_SEARCH_PAGE"])
    find:SetPoint("TOPRIGHT", box, "TOPRIGHT", -16, -10)
    frame.pageSearch = find
    -- The game's settings' home page (its ClassicUI Forever entry): every page's buttons in the header, the search
    -- under it, a line while it is empty.
    frame.homeButtons = {}
    for i = #ALL_BUTTONS, 1, -1 do
        local button = AllPagesButton(box, ALL_BUTTONS[i], 110)
        local prev = frame.homeButtons[#frame.homeButtons]
        if prev then button:SetPoint("RIGHT", prev, "LEFT", -6, 0) else button:SetPoint("TOPRIGHT", box, "TOPRIGHT", -12, -7) end
        button:Hide()
        frame.homeButtons[#frame.homeButtons + 1] = button
    end
    frame.homeHint = box:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.homeHint:SetPoint("TOPLEFT", frame, "TOPLEFT", LIST_X + 4, -(LIST_TOP + HOME_HEAD))
    frame.homeHint:SetText(L["OPTWIN_SETTINGS_HOME"])
    frame.homeHint:Hide()

    -- Where a reading page puts its caption and buttons, over its list.
    local top = ns.NewFrame("Frame", nil, box)
    top:SetPoint("TOPLEFT", frame, "TOPLEFT", LIST_X, -LIST_TOP)
    top:SetSize(LIST_W, 1)
    frame.pageTop = top
    -- A toggles page's note (O.PAGE_NOTES) over its rows, the list under it.
    local note = box:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    note:SetPoint("TOPLEFT", top, "TOPLEFT", 4, 0)
    note:SetPoint("TOPRIGHT", top, "TOPRIGHT", -4, 0)
    note:SetJustifyH("LEFT")
    note:Hide()
    frame.pageNote = note
    local list = ns.NewFrame("ScrollFrame", nil, box)
    list:SetClipsChildren(true)
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta) frame.listBar:SetValue(frame.listBar:GetValue() - delta * ROW) end)
    local child = ns.NewFrame("Frame", nil, list)
    child:SetSize(LIST_W, 1)
    list:SetScrollChild(child)
    frame.list, frame.listChild = list, child
    frame.listBottom = bottom - 8
    FitList(frame, 0)
    frame.listBar = ns.ClassicScrollBar(box, list, function(value) list:SetVerticalScroll(value) end)
    frame.listBar.hideWhenIdle = true
end

-- Word starts in name, keywords or page title first, tooltip only when nothing matched those. A page shows its rows, each
-- top-level row and its own with them a block for the columns; searching shows every page's matches with the boxes above
-- them, each page under its title, matches lit; pageOnly: a page's own search, its matches laid as the page lays them.
local function Blocks(built, text, page, pageOnly)
    local words = {}
    for word in text:gmatch("%S+") do words[#words + 1] = word:gsub("%p", "%%%0") end
    local level, best = {}, 0
    for _, row in ipairs(built.rows) do
        level[row] = #words > 0 and ns.OptionMatchLevel(row, words) or 0
        if level[row] > best then best = level[row] end
    end
    local matched = {}
    for _, row in ipairs(built.rows) do matched[row] = best > 0 and level[row] == best end
    local searching = text ~= ""
    local hit = ns.OptionSearchHits(built.rows, matched, built.parentOf, searching, words)
    local across = searching and not pageOnly
    local blocks, byPage, count = {}, {}, 0
    local function NewBlock(head)
        local block = { head = head, rows = head and 1 or 0 }
        blocks[#blocks + 1] = block
        count = count + block.rows
        return block
    end
    local function Push(block, row)
        block[#block + 1] = row
        block.rows = block.rows + 1
        count = count + 1
    end
    -- On a page a sub-heading starts a block of its own, so the columns may split before it.
    local function AddKids(block, key)
        for _, other in ipairs(built.kids[key] or EMPTY) do
            if hit[other.key] then
                if other.sub and not across then block = NewBlock() end
                Push(block, other)
                block = AddKids(block, other.key)
            end
        end
        return block
    end
    -- A page's top-level heading keeps the rows after it in its block, so the columns never split a heading from them.
    local section
    for _, row in ipairs(built.rows) do
        local shown = hit[row.key] and (across or row.page == page) and not (row.hideIf and row.hideIf())
        if not shown then
            row:Hide()
        elseif not row.parent then
            -- Searching: one block per page under its title; a page: one per top-level row, or per heading's run.
            local block = across and byPage[row.page] or (not across and not row.sub and section)
            if not block then
                block = NewBlock(across and built.heads[row.page] or nil)
                if across then byPage[row.page] = block end
            end
            Push(block, row)
            local last = AddKids(block, row.key)
            if not across and (row.sub or section) then section = last end
        end
    end
    return blocks, count, matched
end

local function Clean(box) return ((box:GetText() or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")) end

local function PlaceRows(frame)
    if not frame.built then return end
    local built = frame.built
    local text, own = Clean(frame.search), Clean(frame.pageSearch)
    local pageOnly = text == "" and own ~= ""
    if pageOnly then text = own end
    local blocks, count, matched = Blocks(built, text, frame.page, pageOnly)
    for _, head in pairs(built.heads) do head:Hide() end
    -- Column-major, whole blocks in order: split where the taller column is shortest.
    local split, shortest, before = #blocks, math.huge, 0
    for i = 0, #blocks do
        if i > 0 then before = before + blocks[i].rows end
        local taller = math.max(before, count - before)
        if taller < shortest then split, shortest = i, taller end
    end
    local colW = LIST_W / COLUMNS
    local column, row, per = 0, 0, 0
    local child = frame.listChild
    local function Put(at, region, x)
        ns.SetPointOnce(region, "TOPLEFT", child, "TOPLEFT", column * colW + x, -at * ROW)
        region:Show()
        if region.keyLow then O.ShowMatch(region, text ~= "" and matched[region] == true) end
    end
    for i, block in ipairs(blocks) do
        if column < COLUMNS - 1 and i == split + 1 and row > 0 then column, row = column + 1, 0 end
        if block.head then
            Put(row, block.head, 0)
            row = row + 1
        end
        for _, region in ipairs(block) do
            Put(row, region, (region.depth or 0) * INDENT)
            row = row + 1
        end
        if row > per then per = row end
    end
    child:SetHeight(math.max(1, per * ROW))
    frame.listBar:SetRange(math.max(0, per * ROW - frame.list:GetHeight()), ROW)
end

-- What the right side shows: a toggles page, a reading page, or the search's matches from every page. keepScroll: a
-- refresh after a toggle stays where the player is; a new page, a search or an open starts at the top (#197).
local function Show(frame, keepScroll)
    local searching = (frame.search:GetText() or "") ~= ""
    local home = frame.page == HOME
    local pane = not searching and frame.panes[frame.page]
    frame.search.hint:SetShown(not searching)
    frame.search.clear:SetShown(searching)
    frame.pageTitle:SetText(searching and (_G.SEARCH or L["OPTWIN_SEARCH_TOGGLES"]) or home and TITLE or frame.page)
    local toggles = not searching and not pane and not home
    for _, button in ipairs(frame.pageButtons) do button:SetShown(toggles) end
    local own = frame.pageSearch:GetText() or ""
    frame.pageSearch:SetShown(toggles)
    frame.pageSearch.hint:SetShown(own == "")
    frame.pageSearch.clear:SetShown(own ~= "")
    for _, button in ipairs(frame.homeButtons) do button:SetShown(home) end
    frame.homeHint:SetShown(home and not searching)
    for name, other in pairs(frame.panes) do
        other:SetShown(other == pane)
        other.child:SetShown(other == pane)
        if frame.nav[name] then frame.nav[name]:SetPicked(name == frame.page and not searching) end
    end
    for name, button in pairs(frame.nav) do
        if not frame.panes[name] then button:SetPicked(name == frame.page and not searching) end
    end
    local note = not searching and not pane and not home and O.PAGE_NOTES[frame.page]
    frame.pageNote:SetText(note or "")
    frame.pageNote:SetShown(note and true or false)
    FitList(frame, pane and pane.headH or home and HOME_HEAD or note and math.ceil(frame.pageNote:GetStringHeight()) + NOTE_GAP or 0,
        toggles and PAGE_FOOT or 0)
    local child = pane and pane.child or frame.listChild
    if frame.list:GetScrollChild() ~= child then frame.list:SetScrollChild(child) end
    frame.listChild:SetShown(not pane)
    if not keepScroll then frame.listBar:SetValue(0) end
    if pane then pane:Refresh() else PlaceRows(frame) end
    -- The range clamps the bar's value; the list follows it even when the value did not change.
    if keepScroll then frame.list:SetVerticalScroll(frame.listBar:GetValue()) end
end

-- The game's settings show this window on its subcategory page (nil: our entry, the home page with the search), the
-- contents at the host's left on the game's own panel. Its bare left strip lies over the game's list: no mouse there.
local function Embed(frame, host, page)
    embedded = host
    frame.chrome = frame.chrome or { frame.fill, frame.header, frame.title, frame.close }
    for _, region in ipairs(frame.chrome) do if region then region:Hide() end end
    frame.navBox:Hide()
    frame.pageBox:SetBackdrop(nil)
    frame:EnableMouse(false)
    frame.search:SetShown(page == nil)
    ns.SetPointOnce(frame.search, "TOPLEFT", frame.pageTop, "TOPLEFT", 4, 0)
    frame:SetBackdrop(nil)
    frame:RegisterForDrag()
    frame:SetParent(host)
    frame:SetFrameStrata(host:GetFrameStrata())
    frame:SetFrameLevel(host:GetFrameLevel() + 1)
    -- Scaled to the room's width, the page down to its foot as the game's own pages run.
    local shift = PANE_X - SIDE_X
    local scale = math.min(1, (host:GetWidth() or WIDTH) / (WIDTH - shift))
    if scale <= 0 then scale = 1 end
    frame:SetScale(scale)
    local roomH = host:GetHeight() or 0
    SetFoot(frame, roomH > 0 and math.max(PANE_TOP + 120, roomH / scale - 20) or frame.standBottom)
    ns.SetPointOnce(frame, "TOPLEFT", host, "TOPLEFT", -shift, 0)
    frame:Show()
    frame:ShowPage(page or HOME)
end

local function StandAlone(frame)
    embedded = nil
    frame.navBox:Show()
    ns.Backdrop(frame.pageBox, ns.BACKDROP.TIP16, BOX_LOOK)
    frame:EnableMouse(true)
    frame.search:Show()
    ns.SetPointOnce(frame.search, "TOPLEFT", frame, "TOPLEFT", SIDE_X + 8, -SEARCH_Y)
    if frame.page == HOME then frame.page = Pages()[1] end
    for _, region in ipairs(frame.chrome or EMPTY) do if region then region:Show() end end
    ns.Backdrop(frame, ns.BACKDROP.DIALOG)
    frame:RegisterForDrag("LeftButton")
    frame:SetParent(UIParent)
    frame:SetFrameStrata("HIGH")
    frame:SetScale(1)
    SetFoot(frame, frame.standBottom)
    ns.SetPointOnce(frame, "CENTER", UIParent, "CENTER", 0, 0)
end

local function Build()
    -- HIGH, not DIALOG: on edit mode's strata its panel backing drew over our boxes.
    local frame = O.DialogWindow("ForeverClassicUIOptions", 0, "HIGH", TOPLEVEL)
    -- The old backdrop is see-through; a dark fill keeps the list readable.
    local fill = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    fill:SetColorTexture(0.03, 0.03, 0.03, 0.45)
    fill:SetPoint("TOPLEFT", frame, "TOPLEFT", 11, -12)
    fill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 11)
    frame.fill = fill
    frame.header, frame.title = ns.DialogHeader(frame, TITLE)
    frame.close = ns.DialogClose(frame, function() frame:Hide() end)

    local pages = Pages()
    FitNames(frame, pages)
    local bottom = Sidebar(frame, pages)
    frame:SetSize(WIDTH, bottom + 20)
    frame.standBottom = bottom
    PageArea(frame, bottom)
    frame.built = O.BuildRows(frame.listChild, LIST_W / COLUMNS)
    local function SetRange(h) frame.listBar:SetRange(math.max(0, h - frame.list:GetHeight()), ROW) end
    frame.panes = {}
    for _, spec in ipairs(PANES) do
        frame.panes[L[spec[1]]] = O[spec[2]](frame.pageBox, frame.pageTop, frame.list, SetRange)
    end
    frame.page = pages[1]
    function O.ShowPage(page) frame:ShowPage(page) end

    function frame:ShowPage(page)
        self.page = page
        -- A page's own search is that page's: a new page starts whole.
        if self.pageSearch:GetText() ~= "" then self.pageSearch:SetText("") end
        if self.search:GetText() ~= "" then self.search:SetText("") else Show(self) end
    end
    -- This page's toggles, drop groups' items included.
    function frame:PageKeys()
        local keys = {}
        for _, row in ipairs(self.built.rows) do
            if row.page == self.page then
                if row.toggle then keys[row.setting or row.key] = true end
                for _, key in ipairs(row.keys or EMPTY) do keys[key] = true end
            end
        end
        return keys
    end
    function frame:Lay() Show(self) end
    frame.search:SetScript("OnTextChanged", function() Show(frame) end)
    frame.pageSearch:SetScript("OnTextChanged", function() Show(frame) end)

    function frame:Refresh(keepScroll)
        -- The one box mirroring a game setting: read fresh.
        ns.ReadGameDamageNumbers()
        local parentOf = self.built.parentOf
        for _, row in ipairs(self.built.rows) do
            -- Done by another toggle (offBy): checked and grayed, as it is in force.
            local doneBy = O.OffByOn(row.offBy)
            row:SetChecked(doneBy or ns.db[row.setting or row.key] ~= false)
            -- Disabled and grayed under any parent that is off.
            local on, up = not (row.needs and ns.db[row.needs] == false), row.parent
            while up do
                if ns.db[up] == false then on = false break end
                up = parentOf[up]
            end
            if on and (ns.BarRowHeld(row.setting or row.key) or doneBy or (row.grayWhen and ns.db[row.grayWhen] == true)
                or (row.grayIf and row.grayIf())) then on = false end
            row:SetEnabled(on)
            -- A button row's label keeps the button's own fonts.
            if not row.button then row.text:SetFontObject(on and (row.font or "GameFontHighlight") or "GameFontDisable") end
        end
        Show(self, keepScroll)
    end
    frame:SetScript("OnShow", function(self) self:Refresh() end)
    frame:HookScript("OnHide", function() if ns.SetMeterPanning then ns.SetMeterPanning(false) end end)
    -- After SetScript, which would wipe its OnShow hooks; inside the game's settings its own Escape closes it.
    ns.CloseOnEscape(frame, nil, function() return not embedded end)
    return frame
end

local function Window()
    window = window or Build()
    return window
end

-- The game's settings: its ClassicUI Forever entry (page nil) and a subcategory per page, each a canvas the window
-- moves into while it shows.
local canvases = {}
function ns.OptionsCanvas(page)
    local key = page or HOME
    if canvases[key] then return canvases[key] end
    local canvas = CreateFrame("Frame", page == nil and "ForeverClassicUIOptionsCanvas" or nil, UIParent)
    canvas:Hide()
    canvas:SetScript("OnShow", function(self) Embed(Window(), self, page) end)
    canvas:SetScript("OnHide", function(self)
        -- Another page's canvas may have taken the window first.
        if embedded ~= self then return end
        StandAlone(window)
        window:Hide()
    end)
    canvases[key] = canvas
    return canvas
end

-- The pages in list order, the game's settings' subcategories: the toggles' groups, then the reading pages.
function ns.OptionsPageNames()
    local names = Pages()
    for _, spec in ipairs(PANES) do names[#names + 1] = L[spec[1]] end
    return names
end

-- A toggle changed from outside the window.
function ns.RefreshOptionsWindow()
    if window and window:IsShown() then window:Refresh(true) end
end

function ns.OpenOptions()
    local frame = Window()
    -- Shown inside the game's settings: out to stand alone, open.
    local inside = embedded ~= nil
    if inside then StandAlone(frame) end
    frame:SetShown(inside or not frame:IsShown())
end

-- Open on one toggle (a chat link's "here"): its label searched, so its row shows lit.
function ns.OpenOptionsAt(key)
    local frame = Window()
    if embedded ~= nil then StandAlone(frame) end
    frame:Show()
    for _, entry in ipairs(ns.TOGGLES) do
        if entry[1] == key then
            frame.search:SetText(entry[2])
            return
        end
    end
end
