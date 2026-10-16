local _, ns = ...
local L = ns.L

-- The classic Collections window (Forever): the spellbook's frame, search and filter in its top band, the picked entry's
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
local PAGE_Y, PAGE_ARROW, PREV_X, NEXT_X, PAGE_TEXT_X = -407, 32, 50, 314, 182
local ACTION_W, ROTATE, BIG_ICON = 96, 26, 64
local TURN_SPEED = math.pi
local CREATURE_ROOM, CREATURE_FACING = 1.3, math.pi / 5
local ADD_HL = { add = true }

-- Window state in one table (upvalue room): frame, box, search, filter pick, page, the current page and its lists.
local W = { tabs = {}, cells = {}, page = 1, picked = {}, entries = {}, shown = {}, show = { collected = true, missing = true } }
local active = false

CW.Text = ns.GameText

-- page: key, tab, icon, tip, events, List() -> { id, name, icon, collected }, Fill, Show(entry, box), Action -> label,
-- enabled; Act or Macro (the button's secure pad), Pickup, Tip; FilterEntries(after) and Shown() -> collected, missing
-- (a page on the game's own filters); ownedOnly (no filter); Picker { Entries(after), Get, Label } (in the search's place).
function CW.AddPage(page)
    CW.pages[page.tab] = page
end

-- A creature (a mount, a pet) in the box's model, which frames it itself; its camera pulled back a step for room round
-- it, turned a little to show its side.
function CW.ShowCreature(box, displayID)
    if type(displayID) ~= "number" or displayID <= 0 then return end
    local model = box.model
    model:Show()
    model:SetDisplayInfo(displayID)
    model:SetPortraitZoom(0)
    model:SetCamDistanceScale(CREATURE_ROOM)
    model:SetPosition(0, 0, 0)
    model:SetFacing(CREATURE_FACING)
end

-- The pages' order: collected first, then by name.
function CW.ByCollectedName(a, b)
    if a.collected ~= b.collected then return a.collected end
    return a.name < b.name
end

-- The page's own filter state (the game's, for Appearances), else the window's two checks.
local function Wanted(entry)
    if W.current.ownedOnly then return true end
    local collected, missing = W.show.collected, W.show.missing
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

local function DrawBox()
    local box, entry = W.box, PickedEntry()
    box.name:SetText(entry and entry.name or "")
    box.source:SetText("")
    box.model:Hide()
    box.model:ClearModel()
    box.bigIcon:Hide()
    box.action:Hide()
    if not entry then return end
    if W.current.Fill then W.current.Fill(entry) end
    box.name:SetText(entry.name)
    W.current.Show(entry, box)
    local label, enabled = W.current.Action(entry)
    if label then
        box.action:SetText(label)
        box.action:SetEnabled(enabled and true or false)
        box.action:Show()
    end
end

local function DrawGrid()
    local first = (W.page - 1) * PER_PAGE
    local picked = PickedEntry()
    for i, cell in ipairs(W.cells) do
        local entry = W.shown[first + i]
        cell.entry = entry
        if entry then
            if W.current.Fill then W.current.Fill(entry) end
            cell.icon:SetTexture(entry.icon)
            cell.icon:SetDesaturated(not entry.collected)
            cell.icon:SetAlpha(entry.collected and 1 or 0.6)
            cell.checked:SetShown(entry == picked)
        end
        cell:SetShown(entry ~= nil)
    end
    local pages = math.max(1, math.ceil(#W.shown / PER_PAGE))
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
    W.page = math.min(W.page, math.max(1, math.ceil(#W.shown / PER_PAGE)))
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
    box.source:SetMaxLines(3)
    box.source:SetTextColor(0.75, 0.75, 0.75)
    -- An entry with no model (a toy): its icon large in the box.
    box.bigIcon = over:CreateTexture(nil, "ARTWORK")
    box.bigIcon:SetSize(BIG_ICON, BIG_ICON)
    box.bigIcon:SetPoint("CENTER", box, "CENTER", 0, -6)
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
    RotateButton(over, "rotateRight", 1):SetPoint("LEFT", left, "RIGHT", 2, 0)
    W.turnJob = ns.Sched.OnFrame(ns.NewFrame("Frame", nil, box), { name = "collections.turn", every = 0, awake = false,
        fn = function(_, since)
            local model = box.model
            if W.turn and model:IsVisible() then model:SetFacing((model:GetFacing() or 0) + W.turn * TURN_SPEED * since) end
        end })
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

local function Refiltered()
    W.page = 1
    RefreshSoon()
end

-- The Filter menu's rows: the page's own (Appearances: the wardrobe's), else Collected and Not Collected on this list.
local function FilterEntries()
    if W.current.FilterEntries then return W.current.FilterEntries(Refiltered) end
    local show = W.show
    return {
        { CW.Text("COLLECTED", "COLL_COLLECTED"), check = function() return show.collected end,
            toggle = function() show.collected = not show.collected Refiltered() end },
        { CW.Text("NOT_COLLECTED", "COLL_NOT_COLLECTED"), check = function() return show.missing end,
            toggle = function() show.missing = not show.missing Refiltered() end },
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
    local pages = math.max(1, math.ceil(#W.shown / PER_PAGE))
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
    frame.portrait = frame:CreateTexture(nil, "ARTWORK")
    frame.portrait:SetSize(58, 58)
    frame.portrait:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -8)
    if ns.RoundIcon then ns.RoundIcon(frame.portrait, 2) end
    frame.title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    frame.title:SetPoint("CENTER", frame, "CENTER", 6, 230)
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
    BuildPaging(frame)
    W.tabs = ns.SideTabsFor(frame, CW.pages, Tab_OnClick, Tab_OnEnter)
    CW.BuildFoot(frame)
    -- A change is a burst of events: one refresh, next frame.
    W.watch = ns.EventFrame({}, RefreshSoon)
    frame:SetScript("OnShow", function()
        CW.FootShown()
        Listen(true)
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
        CW.Refresh()
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

-- Forever's journals by ID; retail keeps the game's own window in our frame.
local function Supported()
    return ns.OnForever() and type(C_MountJournal) == "table" and type(C_MountJournal.GetMountIDs) == "function"
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
