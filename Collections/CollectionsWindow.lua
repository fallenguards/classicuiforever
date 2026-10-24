local _, ns = ...
local L = ns.L

-- The classic Collections window: the spellbook's frame, search and filter in its top band, the picked entry's
-- model, name, source and action in a box, a page of eighteen icons, each collection on a side tab as the Legacy window.
-- A collection file adds its page with CW.AddPage; its list is read afresh as the window shows and as the game says.

local CW = { pages = {} }
ns.collections = CW

local WINDOW_W, WINDOW_H = 384, 512
local CLOSE_X, CLOSE_Y, CLOSE_SIZE = -44, -25, 32
-- From the window's top left: search and filter in the band under the title (the spellbook's search spot); the box
-- from where the spellbook's spells start, 7 inside its border (metal at 15 and 349), the filter ending with it; three
-- rows of icons centred under it, and the page line on the spellbook's own spots.
local BOX_X, BOX_Y, BOX_W, BOX_H = 22, -76, 321, 174
local SEARCH_X, SEARCH_Y, SEARCH_W = 86, -47, 108
local FILTER_X, FILTER_Y, FILTER_W = 198, -41, 145
local GRID_X, GRID_Y, CELL, PITCH_X, PITCH_Y, COLUMNS, ROWS = 49, -256, 37, 46, 46, 6, 3
local PER_PAGE = COLUMNS * ROWS
-- A book page (Heirlooms): no box, the spellbook's two columns of six, each a slot with its name and a line beside it.
local BOOK_X, BOOK_Y, BOOK_COLUMN, BOOK_ROW, BOOK_PER_PAGE, BOOK_NAME_W, BOOK_SUB_W = 34, -85, 157, 51, 12, 103, 79
local SUB_FONT = _G.SubSpellFont and "SubSpellFont" or "GameFontHighlightSmall"
local PAGE_Y, PAGE_ARROW, PREV_X, NEXT_X, PAGE_TEXT_X = -407, 32, 50, 314, 182
local ACTION_W, ROTATE, BIG_ICON = 96, 26, 64
local TURN_SPEED = math.pi
local CREATURE_ROOM, CREATURE_FACING = 1.3, math.pi / 5
-- The wheel over a creature moves the camera this far a notch, between these.
local ROOM_STEP, ROOM_MIN, ROOM_MAX = 0.15, 0.6, 4
-- A look on the character zooms as Era's dressing room: portrait zoom 0 to its player maximum, 0.15 a notch.
local ZOOM_STEP, ZOOM_MAX = 0.15, 0.8
local ADD_HL = { add = true }

-- Window state in one table (upvalue room): frame, box, search, filter pick, page, the current page and its lists.
local W = { tabs = {}, cells = {}, book = {}, page = 1, picked = {}, entries = {}, shown = {} }
-- For the dev addon's probes (collzoom): the window's state, read only.
function CW.State() return W end
local active = false

CW.Text = ns.GameText

-- The game's own filters in a page's Filter menu, as its journals lay them; a row the game has no name for is left out.
function CW.GameName(global)
    local text = _G[global]
    if type(text) == "string" and text ~= "" then return text end
end
-- The rows given, the missing ones dropped.
function CW.Rows(...)
    local out = {}
    for i = 1, select("#", ...) do
        local row = select(i, ...)
        if row then out[#out + 1] = row end
    end
    return out
end
function CW.FilterCheck(label, get, set, after)
    if not label then return nil end
    return { label, check = function() return get() == true end, toggle = function()
        set(not get())
        after()
    end }
end
-- A submenu: Check All, Uncheck All, then a box per index the game names (nameOf).
function CW.FilterSub(label, setAll, count, nameOf, get, set, after)
    if not label then return nil end
    local function Entries()
        local out = {
            { CW.Text("CHECK_ALL", "COLL_CHECK_ALL"), click = function()
                setAll(true)
                after()
            end },
            { CW.Text("UNCHECK_ALL", "COLL_UNCHECK_ALL"), click = function()
                setAll(false)
                after()
            end },
        }
        for i = 1, count or 0 do
            local name = nameOf(i)
            if name then
                out[#out + 1] = { name, check = function() return get(i) == true end, toggle = function()
                    set(i, not get(i))
                    after()
                end }
            end
        end
        return out
    end
    return { label, sub = Entries }
end
-- A page listed through the game's filters: the list is already what they show.
function CW.AllShown() return true, true end

-- A picture's middle square as an icon (a campsite's).
local function SquareFrom(tex, atlas)
    local info = C_Texture.GetAtlasInfo(atlas)
    if not (info and info.width > 0 and info.height > 0) then return end
    local l, r, t, b = info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord
    if info.width > info.height then
        local cut = (r - l) * (1 - info.height / info.width) / 2
        l, r = l + cut, r - cut
    else
        local cut = (b - t) * (1 - info.width / info.height) / 2
        t, b = t + cut, b - cut
    end
    tex:SetTexture(info.file)
    tex:SetTexCoord(l, r, t, b)
end

-- page: key, tab, icon, tip, events, List() -> { id, name, icon, collected }, Fill, Show(entry, box), Action -> label,
-- enabled; Act or Macro (the button's secure pad), Pickup, Tip; FilterEntries(after) and Shown() -> collected, missing
-- (a page on the game's own filters); ownedOnly (no filter); Picker { Entries(after), Get, Label } (in the search's place).
function CW.AddPage(page)
    CW.pages[page.tab] = page
end

-- A creature (a mount, a pet) in the box's model, which frames it itself; its camera pulled back a step for room round
-- it, turned a little to show its side.
local function FrameCreature(model)
    model:SetPortraitZoom(0)
    model:SetCamDistanceScale(W.room or CREATURE_ROOM)
    model:SetPosition(0, 0, 0)
end

-- Framed as it is set and again as its model loads: one loaded a moment later was framed by the game, a large creature
-- filling the box.
function CW.ShowCreature(box, displayID)
    if type(displayID) ~= "number" or displayID <= 0 then return end
    local model = box.model
    W.creature, W.room = true, CREATURE_ROOM
    model:Show()
    model:SetDisplayInfo(displayID)
    FrameCreature(model)
    model:SetFacing(CREATURE_FACING)
end

-- The pages' order: collected first, then by name.
function CW.ByCollectedName(a, b)
    if a.collected ~= b.collected then return a.collected end
    return a.name < b.name
end

-- The window's two checks per page, kept across sessions (db.collectionsShow[page]); both on until changed.
local SHOW_DEFAULT = { collected = true, missing = true }
local function ShowState() return ns.DbTable("collectionsShow")[W.current.key] or SHOW_DEFAULT end

-- The page's own filter state (the game's, for Appearances), else the window's two checks.
local function Wanted(entry)
    if W.current.ownedOnly then return true end
    local show = ShowState()
    local collected, missing = show.collected, show.missing
    if W.current.Shown then collected, missing = W.current.Shown() end
    if entry.collected then return collected end
    return missing
end

local function Matches(entry)
    if not Wanted(entry) then return false end
    if W.search == "" then return true end
    return (entry.name or ""):lower():find(W.search, 1, true) ~= nil
end

local function PickedEntry()
    local want = W.picked[W.current.key]
    for _, entry in ipairs(W.entries) do
        if entry.id == want then return entry end
    end
    return W.shown[1]
end

-- The preview's reset button by its option: shown, on hover, or hidden.
local function ResetFace()
    local reset, db = W.reset, ns.db
    if not (reset and db) then return end
    local over = W.box:IsMouseOver()
    over = not ns.IsSecret(over) and over
    local shown = db.hideCollReset ~= true and (db.hoverCollReset ~= true or over)
    reset:SetAlpha(shown and 1 or 0)
    reset:SetShown(db.hideCollReset ~= true)
end
function CW.ResetFaceSoon() ns.Sched.NextFrame("collections.resetFace", ResetFace) end
local RESET_KEYS = { showCollReset = true, hoverCollReset = true, hideCollReset = true }
ns.OnToggle(function(key) if RESET_KEYS[key] then ResetFace() end end)

local function PerPage() return W.current and W.current.book and BOOK_PER_PAGE or PER_PAGE end

local function DrawBox()
    if W.current and W.current.book then return end
    local box, entry = W.box, PickedEntry()
    -- The same pick drawn again (an event burst refreshes the page): its model kept as it stands, not set up again (it
    -- jumped back to its first pose and turn each time). The window's show draws afresh.
    local key = entry and (W.current.key .. ":" .. tostring(entry.id)) or nil
    local same = key ~= nil and key == W.drawn
    W.drawn = key
    box.name:SetText(entry and entry.name or "")
    if not same then
        W.creature = false
        box.source:SetText("")
        box.model:Hide()
        box.model:ClearModel()
        -- A model keeps its place and camera through a clear: a right drag or a creature's pulled-back camera stayed.
        box.model:SetPosition(0, 0, 0)
        box.model:SetCamDistanceScale(1)
        W.zoom = 0
        box.model:SetPortraitZoom(0)
        box.bigIcon:Hide()
        box.picture:Hide()
    end
    box.action:Hide()
    ResetFace()
    if not entry then return end
    if W.current.Fill then W.current.Fill(entry) end
    box.name:SetText(entry.name)
    if not same then W.current.Show(entry, box) end
    local label, enabled = W.current.Action(entry)
    if label then
        box.action:SetText(label)
        box.action:SetEnabled(enabled and true or false)
        box.action:Show()
    end
end

-- The preview drawn as the window opens is framed before its box has its size (the camera aimed off to the side, as
-- collzoom read it): drawn afresh a frame later, as the reset button does.
local function Reframe()
    if not (W.box and W.box:IsVisible()) then return end
    W.drawn = nil
    DrawBox()
end

local function DrawCell(cell, entry, picked)
    cell.entry = entry
    cell:SetShown(entry ~= nil)
    if not entry then return end
    if W.current.Fill then W.current.Fill(entry) end
    if entry.atlas then
        SquareFrom(cell.icon, entry.atlas)
    else
        cell.icon:SetTexture(entry.icon)
        cell.icon:SetTexCoord(0, 1, 0, 1)
    end
    cell.icon:SetDesaturated(not entry.collected)
    cell.icon:SetAlpha(entry.collected and 1 or 0.6)
    cell.checked:SetShown(entry == picked)
    if not cell.name then return end
    -- The game's own colours for a book entry you have and one you lack.
    cell.name:SetText(entry.name)
    if entry.collected then cell.name:SetTextColor(1, 0.82, 0) else cell.name:SetTextColor(0.33, 0.27, 0.2) end
    cell.sub:SetText(W.current.Sub and W.current.Sub(entry) or "")
end

local function DrawGrid()
    local book, per = W.current.book, PerPage()
    local first, picked = (W.page - 1) * per, not book and PickedEntry() or nil
    for _, cell in ipairs(book and W.cells or W.book) do cell:Hide() end
    for i, cell in ipairs(book and W.book or W.cells) do DrawCell(cell, W.shown[first + i], picked) end
    local pages = math.max(1, math.ceil(#W.shown / per))
    W.pageText:SetFormattedText(L["COLL_PAGE"], W.page, pages)
    W.prev:SetEnabled(W.page > 1)
    W.next:SetEnabled(W.page < pages)
end

-- The current page's list read again, filtered and searched; the page kept where it still exists.
function CW.Refresh()
    if not (W.frame and W.frame:IsShown() and W.current) then return end
    W.entries = W.current.List() or ns.EMPTY
    wipe(W.shown)
    for _, entry in ipairs(W.entries) do
        if Matches(entry) then W.shown[#W.shown + 1] = entry end
    end
    W.page = math.min(W.page, math.max(1, math.ceil(#W.shown / PerPage())))
    DrawGrid()
    DrawBox()
end

local function RefreshSoon()
    ns.Sched.NextFrame("collections.refresh", CW.Refresh)
end

local function Listen(on)
    W.watch:UnregisterAllEvents()
    if on and W.current and W.current.events then ns.RegisterEvents(W.watch, W.current.events) end
end

local function ShowPicker(page)
    local picker = page.Picker
    -- A search left from another page would hide every entry here, where names come only as drawn.
    if picker and W.search ~= "" then W.searchBox:SetText("") end
    W.searchBox:SetShown(not picker)
    W.picker:SetShown(picker ~= nil)
    if not picker then return end
    W.pickerText:SetText(picker.Label(picker.Get()))
    W.pickerLists[page] = W.pickerLists[page] or ns.DropList(picker.Entries(function()
        W.pickerText:SetText(picker.Label(picker.Get()))
        W.page = 1
        CW.Refresh()
    end))
    W.pickerLists[page]:Follow(W.frame)
end

-- An atlas picture fitted in the box, its shape kept.
function CW.ShowPicture(box, atlas)
    local info = atlas and C_Texture.GetAtlasInfo(atlas)
    if not (info and info.width > 0 and info.height > 0) then return end
    local k = math.min((BOX_W - 8) / info.width, (BOX_H - 8) / info.height)
    box.picture:SetAtlas(atlas)
    box.picture:SetSize(info.width * k, info.height * k)
    box.picture:Show()
end

-- The tab, title and portrait first: a page whose game data fails still shows as the one picked.
local function ShowPage(page)
    if W.current == page then return end
    W.current, W.page = page, 1
    for i, tab in ipairs(W.tabs) do tab:SetChecked(CW.pages[i] == page) end
    W.frame.title:SetText(CW.Text(page.tip[1], page.tip[2]))
    W.frame.portrait:SetTexture(page.icon)
    -- A page of owned things only (Forever lists no pets but yours) has nothing to filter.
    W.filterButton:SetShown(not page.ownedOnly)
    ShowPicker(page)
    W.box:SetShown(not page.book)
    -- A page's side panel (the Pets page's battle team, Collections/CollectionsTeam.lua).
    if CW.OnPage then CW.OnPage(page, W.frame, W.box) end
    if W.frame:IsShown() then
        Listen(true)
        CW.Refresh()
    end
end

local function Turn(dir)
    W.turn = dir
    if dir then W.turnJob:Wake() else W.turnJob:Sleep() end
end

local function RotateButton(parent, art, dir)
    local button = ns.NewFrame("Button", nil, parent)
    button:SetSize(ROTATE, ROTATE)
    button:SetNormalTexture((ns.TexPath(art .. "Up")))
    button:SetPushedTexture((ns.TexPath(art .. "Down")))
    button:SetHighlightTexture((ns.TexPath("roundHighlight")))
    button:GetHighlightTexture():SetBlendMode("ADD")
    button:SetScript("OnMouseDown", function()
        Turn(dir)
        PlaySound(SOUNDKIT.IG_INVENTORY_ROTATE_CHARACTER)
    end)
    button:SetScript("OnMouseUp", function() Turn(nil) end)
    button:SetScript("OnHide", function() Turn(nil) end)
    return button
end

-- The picked entry's stage: dark box, model, name and source over it, the action at its foot, the turn buttons.
-- Dragged as the game's previews: the left button turns it, the right moves it in the box on a page with pan (the
-- appearances, as the game's wardrobe); per screen pixel.
local DRAG_TURN, DRAG_MOVE = 0.012, 0.01
local function DragModel(model)
    local job = ns.Sched.OnFrame(ns.NewFrame("Frame", nil, model), { name = "collections.drag", every = 0, awake = false,
        fn = function()
            local x, y = GetCursorPosition()
            local dx, dy = x - W.dragX, y - W.dragY
            W.dragX, W.dragY = x, y
            if W.drag == "LeftButton" then
                model:SetFacing((model:GetFacing() or 0) + dx * DRAG_TURN)
            elseif W.drag == "RightButton" then
                local px, py, pz = model:GetPosition()
                model:SetPosition(px or 0, (py or 0) + dx * DRAG_MOVE, (pz or 0) + dy * DRAG_MOVE)
            end
        end })
    local function Stop()
        W.drag = nil
        job:Sleep()
    end
    model:EnableMouse(true)
    model:SetScript("OnMouseDown", function(_, button)
        if button == "RightButton" and not (W.current and W.current.pan) then return end
        if button ~= "LeftButton" and button ~= "RightButton" then return end
        W.drag, W.dragX, W.dragY = button, GetCursorPosition()
        job:Wake()
    end)
    model:SetScript("OnMouseUp", Stop)
    model:SetScript("OnHide", Stop)
end

local function BuildBox(frame)
    local box = ns.NewFrame("Frame", nil, frame)
    box:SetSize(BOX_W, BOX_H)
    box:SetPoint("TOPLEFT", frame, "TOPLEFT", BOX_X, BOX_Y)
    local back = box:CreateTexture(nil, "BACKGROUND")
    back:SetPoint("TOPLEFT", box, "TOPLEFT", 3, -3)
    back:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -3, 3)
    back:SetColorTexture(0.05, 0.06, 0.08, 1)
    ns.InnerBorder(box)
    -- One dressing model: a creature by its display, a look on the character.
    box.model = ns.NewFrame("DressUpModel", nil, box)
    box.model:SetPoint("TOPLEFT", box, "TOPLEFT", 4, -4)
    box.model:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -4, 4)
    box.model:Hide()
    box.model:SetScript("OnModelLoaded", function(self) if W.creature then FrameCreature(self) end end)
    -- The wheel over the model zooms it, not the page.
    box.model:EnableMouseWheel(true)
    box.model:SetScript("OnMouseWheel", function(self, delta)
        if W.creature then
            W.room = math.max(ROOM_MIN, math.min(ROOM_MAX, (W.room or CREATURE_ROOM) - delta * ROOM_STEP))
            self:SetCamDistanceScale(W.room)
        else
            W.zoom = math.max(0, math.min(ZOOM_MAX, (W.zoom or 0) + delta * ZOOM_STEP))
            self:SetPortraitZoom(W.zoom)
        end
    end)
    local over = ns.NewFrame("Frame", nil, box)
    over:SetAllPoints(box)
    over:SetFrameLevel(box.model:GetFrameLevel() + 2)
    box.name = over:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    box.name:SetPoint("TOPLEFT", box, "TOPLEFT", 10, -10)
    box.name:SetPoint("RIGHT", box, "RIGHT", -10, 0)
    box.name:SetJustifyH("LEFT")
    box.source = over:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    box.source:SetPoint("TOPLEFT", box.name, "BOTTOMLEFT", 0, -3)
    box.source:SetPoint("RIGHT", box, "RIGHT", -10, 0)
    box.source:SetJustifyH("LEFT")
    -- From the top: a source past its lines kept its whole height and centred the lines it drew, a gap over them.
    box.source:SetJustifyV("TOP")
    box.source:SetMaxLines(4)
    box.source:SetTextColor(0.75, 0.75, 0.75)
    -- An entry with no model (a toy): its icon large in the box.
    box.bigIcon = over:CreateTexture(nil, "ARTWORK")
    box.bigIcon:SetSize(BIG_ICON, BIG_ICON)
    box.bigIcon:SetPoint("CENTER", box, "CENTER", 0, -6)
    -- A picture page's (a campsite's): as large as the box holds, under the name.
    box.picture = box:CreateTexture(nil, "ARTWORK")
    box.picture:SetPoint("CENTER", box, "CENTER", 0, 0)
    box.picture:Hide()
    box.action = ns.PanelButton(over, "", ACTION_W)
    box.action:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -8, 8)
    box.action:SetScript("OnClick", function()
        local entry = PickedEntry()
        if entry and W.current.Act then W.current.Act(entry) end
        RefreshSoon()
    end)
    -- A page's protected use (a toy) goes through a secure pad over the button, shut in a fight (its text cannot follow
    -- a new pick there); our window keeps no secure child.
    ns.MapPad(box.action, "HIGH", RefreshSoon, function()
        local entry = W.frame:IsShown() and W.current and W.current.Macro and PickedEntry()
        return entry and W.current.Macro(entry) or nil
    end)
    local left = RotateButton(over, "rotateLeft", -1)
    left:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 6, 6)
    local right = RotateButton(over, "rotateRight", 1)
    right:SetPoint("LEFT", left, "RIGHT", 2, 0)
    -- Back to how the pick first showed, turn, place and zoom: drawn afresh.
    local reset = ns.PanelButton(over, "", ROTATE)
    reset:SetPoint("LEFT", right, "RIGHT", 2, 0)
    local icon = reset:CreateTexture(nil, "OVERLAY")
    icon:SetTexture("Interface\\Buttons\\UI-RefreshButton")
    icon:SetSize(14, 14)
    icon:SetPoint("CENTER", 0, 0)
    reset:SetScript("OnClick", function()
        W.drawn = nil
        DrawBox()
    end)
    ns.AttachTip(reset, { text = function() return _G.RESET end })
    W.reset = reset
    -- Its option's on hover: shown while the mouse is over the box, judged a frame after any of its parts says so.
    for _, part in ipairs({ box.model, left, right, reset }) do
        part:HookScript("OnEnter", CW.ResetFaceSoon)
        part:HookScript("OnLeave", CW.ResetFaceSoon)
    end
    W.turnJob = ns.Sched.OnFrame(ns.NewFrame("Frame", nil, box), { name = "collections.turn", every = 0, awake = false,
        fn = function(_, since)
            local model = box.model
            if W.turn and model:IsVisible() then model:SetFacing((model:GetFacing() or 0) + W.turn * TURN_SPEED * since) end
        end })
    DragModel(box.model)
    W.box = box
end

local function Cell_OnClick(self)
    if not self.entry then return end
    W.picked[W.current.key] = self.entry.id
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    DrawGrid()
    DrawBox()
end

local function Cell_OnEnter(self)
    if not self.entry then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if W.current.Tip then W.current.Tip(self.entry, self) else GameTooltip:SetText(self.entry.name) end
    GameTooltip:Show()
end

-- Pickups wait out a fight; the game refuses them in one.
local function Cell_OnDragStart(self)
    if self.entry and W.current.Pickup and not InCombatLockdown() then W.current.Pickup(self.entry) end
end

local function BuildCell(frame, i)
    local cell = ns.NewFrame("Button", nil, frame)
    cell:SetSize(CELL, CELL)
    local column, row = (i - 1) % COLUMNS, math.floor((i - 1) / COLUMNS)
    cell:SetPoint("TOPLEFT", frame, "TOPLEFT", GRID_X + column * PITCH_X, GRID_Y - row * PITCH_Y)
    local empty = cell:CreateTexture(nil, "BACKGROUND")
    ns.SetTex(empty, "sbEmptySlot")
    empty:SetSize(64, 64)
    empty:SetPoint("TOPLEFT", cell, "TOPLEFT", -3, 3)
    cell.icon = cell:CreateTexture(nil, "BORDER")
    cell.icon:SetAllPoints(cell)
    local normal = cell:CreateTexture(nil, "ARTWORK")
    ns.SetTex(normal, "slotNormal")
    normal:SetSize(64, 64)
    normal:SetPoint("CENTER", cell, "CENTER", 0, 0)
    cell.checked = cell:CreateTexture(nil, "OVERLAY")
    ns.SetTex(cell.checked, "checked")
    cell.checked:SetAllPoints(cell)
    cell.checked:SetBlendMode("ADD")
    ns.DressStates(cell, nil, "slotPushed", nil, "highlight", ADD_HL)
    cell:RegisterForDrag("LeftButton")
    cell:SetScript("OnClick", Cell_OnClick)
    cell:SetScript("OnEnter", Cell_OnEnter)
    cell:SetScript("OnLeave", GameTooltip_Hide)
    cell:SetScript("OnDragStart", Cell_OnDragStart)
    return cell
end

-- A book entry does the page's action on a click (Create), as a spell casts.
local function BookCell_OnClick(self)
    if self.entry and W.current.Act then W.current.Act(self.entry) end
    RefreshSoon()
end

local function BuildBookCell(frame, i)
    local cell = BuildCell(frame, i)
    ns.SetPointOnce(cell, "TOPLEFT", frame, "TOPLEFT", BOOK_X + (i > 6 and BOOK_COLUMN or 0), BOOK_Y - (i - 1) % 6 * BOOK_ROW)
    cell:SetScript("OnClick", BookCell_OnClick)
    cell.name = cell:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    cell.name:SetWidth(BOOK_NAME_W)
    cell.name:SetJustifyH("LEFT")
    cell.name:SetMaxLines(3)
    cell.name:SetPoint("LEFT", cell, "RIGHT", 5, 3)
    cell.sub = cell:CreateFontString(nil, "ARTWORK", SUB_FONT)
    cell.sub:SetSize(BOOK_SUB_W, 18)
    cell.sub:SetJustifyH("LEFT")
    cell.sub:SetPoint("TOPLEFT", cell.name, "BOTTOMLEFT", 0, -2)
    -- A page's protected use (a toy) through a secure pad over the slot; none while the page has no use for it.
    ns.MapPad(cell, "HIGH", RefreshSoon, function()
        local entry = cell.entry
        return entry and W.current and W.current.Macro and W.current.Macro(entry) or nil
    end)
    cell:Hide()
    return cell
end

local function Refiltered()
    W.page = 1
    RefreshSoon()
end

local function Flip(field)
    local all = ns.DbTable("collectionsShow")
    local state = all[W.current.key] or { collected = true, missing = true }
    state[field] = not state[field]
    all[W.current.key] = state
    Refiltered()
end

-- The Filter menu's rows: the page's own (Appearances: the wardrobe's), else Collected and Not Collected on this list.
local function FilterEntries()
    if W.current.FilterEntries then return W.current.FilterEntries(Refiltered) end
    return {
        { CW.Text("COLLECTED", "COLL_COLLECTED"), check = function() return ShowState().collected end,
            toggle = function() Flip("collected") end },
        { CW.Text("NOT_COLLECTED", "COLL_NOT_COLLECTED"), check = function() return ShowState().missing end,
            toggle = function() Flip("missing") end },
    }
end

local function BuildFilter(frame)
    local button = ns.NewFrame("Button", nil, frame)
    button:SetSize(FILTER_W, 32)
    button:SetPoint("TOPLEFT", frame, "TOPLEFT", FILTER_X, FILTER_Y)
    ns.DressDropdown(button)
    W.filterButton = button
    local text = button:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    text:SetPoint("RIGHT", button, "RIGHT", -26, 2)
    text:SetText(CW.Text("FILTER", "COLL_FILTER"))
    local menu = ns.TreeMenu(FilterEntries)
    menu:Follow(frame)
    button:SetScript("OnClick", function(self) menu:Toggle(self) end)
end

local function BuildSearch(frame)
    local box = ns.SearchBox(frame, SEARCH_W, CW.Text("SEARCH", "COLL_SEARCH"))
    box:SetPoint("TOPLEFT", frame, "TOPLEFT", SEARCH_X, SEARCH_Y)
    W.searchBox, W.search = box, ""
    -- A page's own pick in the search's place (Appearances: the slot).
    local picker = ns.NewFrame("Button", nil, frame)
    picker:SetSize(SEARCH_W + 12, 32)
    picker:SetPoint("TOPLEFT", frame, "TOPLEFT", SEARCH_X - 8, FILTER_Y)
    ns.DressDropdown(picker)
    W.pickerText = picker:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    W.pickerText:SetPoint("RIGHT", picker, "RIGHT", -26, 2)
    W.pickerLists = {}
    picker:SetScript("OnClick", function(self) W.pickerLists[W.current]:Toggle(self) end)
    picker:Hide()
    W.picker = picker
    box:SetScript("OnTextChanged", function(self)
        local text = self:GetText() or ""
        self.hint:SetShown(text == "")
        self.clear:SetShown(text ~= "")
        W.search, W.page = text:lower(), 1
        CW.Refresh()
    end)
end

local function Step(delta)
    local pages = math.max(1, math.ceil(#W.shown / PerPage()))
    local page = math.max(1, math.min(pages, W.page + delta))
    if page == W.page then return end
    W.page = page
    PlaySound(SOUNDKIT.IG_ABILITY_PAGE_TURN)
    DrawGrid()
end

local function PageButton(frame, art, delta)
    local button = ns.NewFrame("Button", nil, frame)
    button:SetSize(PAGE_ARROW, PAGE_ARROW)
    ns.DressStates(button, art .. "Up", art .. "Down", art .. "Disabled", "mouseHighlight", ADD_HL)
    button:SetScript("OnClick", function() Step(delta) end)
    return button
end

local function BuildPaging(frame)
    W.pageText = frame:CreateFontString(nil, "ARTWORK", "GameFontBlack")
    W.pageText:SetPoint("CENTER", frame, "TOPLEFT", PAGE_TEXT_X, PAGE_Y)
    W.prev = PageButton(frame, "sbPrev", -1)
    W.prev:SetPoint("CENTER", frame, "TOPLEFT", PREV_X, PAGE_Y)
    W.next = PageButton(frame, "sbNext", 1)
    W.next:SetPoint("CENTER", frame, "TOPLEFT", NEXT_X, PAGE_Y)
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(_, delta) Step(delta > 0 and -1 or 1) end)
end

local function Tab_OnClick(self)
    PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
    ShowPage(CW.pages[self:GetID()])
    -- A click on the picked tab would uncheck it.
    self:SetChecked(true)
end

local function Tab_OnEnter(self)
    local page = CW.pages[self:GetID()]
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(CW.Text(page.tip[1], page.tip[2]))
    GameTooltip:Show()
end

local function BuildShell()
    local frame = CreateFrame("Frame", "ClassicUIForeverCollections", UIParent)
    frame:SetSize(WINDOW_W, WINDOW_H)
    frame:SetFrameStrata("MEDIUM")
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    -- Only the painted frame takes the mouse: past its border the world does.
    frame:SetHitRectInsets(0, 34, 0, 79)
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", ns.ClassicSlot())
    frame:Hide()
    ns.DressPieces(frame, ns.SPELLBOOK_QUARTERS)
    -- Under the frame art, as Era's portraits: its own frame cropped, cut round only past the ring.
    frame.portrait = frame:CreateTexture(nil, "BACKGROUND", nil, -1)
    frame.portrait:SetSize(58, 58)
    frame.portrait:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -8)
    ns.RoundIcon(frame.portrait, 0, 0.07)
    frame.title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    -- From the top left: a page's side panel widens the window (Collections/CollectionsTeam.lua).
    frame.title:SetPoint("CENTER", frame, "TOPLEFT", WINDOW_W / 2 + 6, -(WINDOW_H / 2 - 230))
    ns.WindowCloseX(frame, CLOSE_X, CLOSE_Y, CLOSE_SIZE)
    return frame
end

local function Build()
    if W.frame then return W.frame end
    local frame = BuildShell()
    W.frame = frame
    BuildBox(frame)
    BuildSearch(frame)
    BuildFilter(frame)
    for i = 1, PER_PAGE do W.cells[i] = BuildCell(frame, i) end
    for i = 1, BOOK_PER_PAGE do W.book[i] = BuildBookCell(frame, i) end
    BuildPaging(frame)
    W.tabs = ns.SideTabsFor(frame, CW.pages, Tab_OnClick, Tab_OnEnter)
    CW.BuildFoot(frame)
    -- A change is a burst of events: one refresh, next frame.
    W.watch = ns.EventFrame({}, RefreshSoon)
    frame:SetScript("OnShow", function()
        W.drawn = nil
        CW.FootShown()
        Listen(true)
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
        CW.Refresh()
        ns.Sched.NextFrame("collections.reframe", Reframe)
    end)
    frame:SetScript("OnHide", function()
        Listen(false)
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
    end)
    -- After the window's own SetScripts, which wipe earlier hooks; the next window keeps clear of the side tabs. A page
    -- of the spellbook: its pushable (0), so it takes the book's spot (UI/WindowList.lua follows it once moved).
    ns.SetSlotWidth(frame, ns.SIDE_TAB_SLOT)
    ns.RegisterClassicWindow(frame, 0)
    ns.CloseOnEscape(frame)
    ns.CloseWithGameMenu(frame)
    ns.MicroButtonFollows(_G.CollectionsMicroButton, function() return frame:IsShown() end, frame)
    ShowPage(CW.pages[1])
    return frame
end

-- The journals read by ID.
local function Supported()
    return type(C_MountJournal) == "table" and type(C_MountJournal.GetMountIDs) == "function"
end

local function Toggle()
    local frame = Build()
    frame:SetShown(not frame:IsShown())
end

-- The Collections micro button and key open this window while on, and the minimap icon and the spellbook's foot tab
-- with them (they press the button); the button's pad closes the book's other pages first (Collections/CollectionsBook.lua).
local Openers = ns.WindowOpeners({ name = "collections", micro = "CollectionsMicroButton",
    bind = "ClassicUIForeverCollectionsBind", binding = "TOGGLECOLLECTIONS", toggle = Toggle, frame = function() return W.frame end,
    closers = function() return CW.BookCloserLines() end })

-- The openers taken or handed back; the window shut when off.
local function SetActive(on)
    active = on and Supported()
    Openers(active)
    if not active and W.frame and W.frame:IsShown() then W.frame:Hide() end
end

-- The gamepad cannot navigate our windows (Core/Gamepad.lua): with it on at login the game's window stays.
ns.RegisterModule("collectionsWindow", { apply = function() SetActive(true) end, restore = function() SetActive(false) end,
    padLogin = true })

-- The window shown on a page (its key: mounts, pets, toys, heirlooms, appearances); false when it cannot show.
function ns.ShowCollections(pageKey)
    if not (active and Supported()) or ns.padSession then return false end
    Build()
    if not W.frame:IsShown() then W.frame:Show() end
    for _, page in pairs(CW.pages) do
        if page.key == pageKey then ShowPage(page) end
    end
    return W.frame:IsShown()
end
function ns.CollectionsPageTab(n) return W.tabs[n] end
-- Read by the dev addon's probe: the window's state and its page turn.
CW.Probe = { State = function() return W end, ShowPage = function(page) ShowPage(page) end }
