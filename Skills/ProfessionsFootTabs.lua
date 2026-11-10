local _, ns = ...
local L = ns.L

-- The spellbook's foot tabs on the professions book page, with their secure pads (ProfessionsWindow.lua calls these).

local T = ns.prof
local Page = T.Page
local SetShownIf = ns.SetShownIf

-- The spellbook's foot tabs in the same spot, so the two windows turn into each
-- other like the old book's pages. On the book page (a crafting page has none);
-- both windows are the client's to show in combat, so no turn there.
local bookTabs
-- Secure pads over the Spellbook and pet tabs, under the client's window so they show and hide with it, in a fight
-- too (a pad on UIParent is placed out of combat only). Anchored to the window, never the tabs: the window turns
-- protected by them, and every write on it here already waits for a fight's end; the tabs stay free.
local bookPads
-- The book's tabs on the spellbook's own spots: 61 over its frame's foot is 12 under this window's.
local TAB_Y = -12
local function TabY() return TAB_Y end
-- The spellbook's first tab centres (79 wide, 66 narrow) less its border's 12 in from its frame; Collections third.
local WIDE = { x = 67, step = 108, drawn = 100, overlap = -20, hit = 14, slot = { 0, 1, 2 } }
local NARROW = { x = 54, step = 80, drawn = 74, overlap = -48, hit = 27, slot = { 0, 1, 3, 2 } }
local BORDER_W = 338   -- the spellbook's border, 12 to 350
local firstX   -- the first tab's centre as last laid (the row centred when it would stand off to the right)
local function Spec()
    return ns.BookCollectionsTab and ns.BookCollectionsTab() and NARROW or WIDE
end

-- Gamepad on at login: the game's navigator walks this window and would press the drawn tab (our Lua, which cannot
-- shut a window the gamepad holds), so the secure pads wear the tabs and the drawn ones go.
local function PadTabs() return ns.padSession == true end
local wanted = {}   -- tab index -> it would show (the drawn tab hidden for its pad)

-- Shown with its tab inside the window, never by the window: placed while it was shut, a pad went hidden for the fight.
local function PadShown(i)
    local page = Page()
    local up = PadTabs() and wanted[i] or bookTabs[i]:IsShown()
    return up and page ~= nil and page:IsShown()
end

-- What's Training's professions list (recipes still to learn) opens from a side tab of ours on either face of this
-- window, under a tab that turns back to the face: the book, or the open profession under its own icon; its own tabs
-- on this window stand down, hidden as they show (#260).
local TRAINING_TABS = { "WhatsTrainingCraftingTab", "WhatsTrainingCraftingReturnTab" }
-- The spellbook's first side tab spot (Spells/SpellBook.lua): just past the window's right edge, 65 down.
local TRAIN_X, TRAIN_Y, TRAIN_GAP = 2, -65, -17
local PROF_ICON = "Interface\\Icons\\INV_SideTab_Professions_c60"
local faceTab, trainTab, faceIcon
local function TrainingOurs()
    return ns.OnForever() and ns.ModuleInForce("professionsBook") and ns.SpellBookActive and ns.SpellBookActive()
end
local function TrainingOff(piece)
    if TrainingOurs() and piece:IsShown() then piece:Hide() end
end
local function TrainingListUp()
    local list = _G.WhatsTrainingCraftingPage
    return list ~= nil and list:IsShown()
end

-- Its list is laid for the game's wide window (a 552 search row, centered): on our book the search box starts clear of
-- the portrait ring and takes the page's width less the Filter button, which ends over the list's scroll bar; its own
-- title stands down for ours.
local SEARCH_X, SEARCH_Y, FILTER_W, FILTER_GAP, LIST_GUTTER = 62, -16, 108, 4, 14
local titleTaken = false
local function FitTraining(list)
    local title = _G.WhatsTrainingCraftingTitle
    if not TrainingOurs() then
        if titleTaken and title then title:Show() end
        titleTaken = false
        return
    end
    local search = _G.WhatsTrainingCraftingSearchBox
    if search then
        ns.SetPointOnce(search, "TOPLEFT", list, "TOPLEFT", SEARCH_X, SEARCH_Y)
        local width = list:GetWidth() - SEARCH_X - FILTER_W - FILTER_GAP - LIST_GUTTER
        if width > 0 then search:SetWidth(width) end
    end
    if title and title:IsShown() then
        title:Hide()
        titleTaken = true
    end
end

-- The list up checks its tab, the face its own.
local function CheckSideTabs()
    if not faceTab then return end
    local up = TrainingListUp()
    faceTab:SetChecked(not up)
    trainTab:SetChecked(up)
end

-- The face under the list: the book's page, else the open profession's crafting page (ours or the game's).
local function CraftFace(frame, page)
    local crafting = frame.CraftingPage
    return not page:IsShown() and crafting ~= nil and crafting:IsShown()
end

-- The face tab wears its face: the book's icon and name, or the open profession's.
local function WearFace(frame, page)
    local icon, tip = PROF_ICON, TRADE_SKILLS or "Professions"
    if CraftFace(frame, page) then
        local api = C_TradeSkillUI
        local info = api and api.GetBaseProfessionInfo and api.GetBaseProfessionInfo()
        local own = info and info.professionID and api.GetTradeSkillTexture and api.GetTradeSkillTexture(info.professionID)
        if own then icon, tip = own, info.professionName or tip end
    end
    if faceIcon ~= icon then
        faceIcon = icon
        faceTab:SetNormalTexture(icon)
    end
    faceTab.tooltip = tip
end

-- Its own launcher's and return tab's handlers, as their clicks run them.
local function Press(name)
    local tab = _G[name]
    local handler = tab and tab.customMouseUpHandler
    if type(handler) == "function" then handler(tab, "LeftButton", true) end
end
local function OpenTraining()
    -- Its own window (the option) on its professions page where it has one; else its list over this window.
    if ns.TrainingOwnWindow and ns.TrainingOwnWindow() and not ns.TrainingAttached() and ns.ToggleTrainingWindow(nil, true) then
        CheckSideTabs()
        return
    end
    if not TrainingListUp() then Press("WhatsTrainingCraftingTab") end
    CheckSideTabs()
end
local function CloseTraining()
    if TrainingListUp() then Press("WhatsTrainingCraftingReturnTab") end
    CheckSideTabs()
end

-- Under the profession side tabs while they are up (hover or always), else at the column's top, past the face's
-- width (the book's, our trade skill window's, or the game's own page); the list's tab hangs under the face's.
local function PlaceSideTabs(frame, page)
    local last
    if not (ns.db and ns.db.professionTabsHidden == true) then
        for _, tab in ipairs(frame.rightProfessionTabs or ns.EMPTY) do
            if tab:IsShown() then last = tab end
        end
    end
    if last then
        ns.SetPointOnce(faceTab, "TOPLEFT", last, "BOTTOMLEFT", 0, TRAIN_GAP)
        return
    end
    local width = T.BookW()
    if CraftFace(frame, page) then
        local ours = ns.TradeSkillActive and ns.TradeSkillActive()
        width = ours and (ns.TradeSkillWindowSize()) or frame:GetWidth()
    end
    ns.SetPointOnce(faceTab, "TOPLEFT", frame, "TOPLEFT", width + TRAIN_X, TRAIN_Y)
end

local function TrainingStandsDown(frame, page)
    for _, name in ipairs(TRAINING_TABS) do
        local piece = _G[name]
        if piece then
            ns.HookScriptOnce(piece, "OnShow", TrainingOff, "profTraining")
            TrainingOff(piece)
        end
    end
    local list = _G.WhatsTrainingCraftingPage
    if list then
        ns.HookScriptOnce(list, "OnShow", FitTraining, "profTrainingFit")
        ns.HookScriptOnce(list, "OnShow", CheckSideTabs, "profTrainingTabs")
        ns.HookScriptOnce(list, "OnHide", CheckSideTabs, "profTrainingTabs")
        if list:IsShown() then FitTraining(list) end
        ns.TrainingPageLook(list, TrainingOurs())
    end
    if not (_G.WhatsTrainingCraftingTab and ns.NewSideTab and TrainingOurs()) then
        if faceTab then
            faceTab:Hide()
            trainTab:Hide()
        end
        return
    end
    -- On the window itself, not a face's page: they stay as the faces turn under the list.
    if not faceTab then
        faceTab = ns.NewSideTab(frame, 1, nil)
        faceTab:SetScript("OnClick", CloseTraining)
        trainTab = ns.NewSideTab(frame, 2, faceTab)
        trainTab.tooltip = L["SPELL_WHAT_CAN_I_TRAIN"]
        trainTab:SetScript("OnClick", OpenTraining)
    end
    WearFace(frame, page)
    ns.WearTrainingIcon(trainTab, true)
    PlaceSideTabs(frame, page)
    CheckSideTabs()
    -- Over the Era art frames, children of the window too; the toplevel window's raise re-levels, so each pass.
    local level = frame:GetFrameLevel() + 3
    ns.SetLevelIf(faceTab, level)
    ns.SetLevelIf(trainTab, level)
    local up = page:IsShown() or CraftFace(frame, page)
    SetShownIf(faceTab, up)
    SetShownIf(trainTab, up)
end

-- The game's controller footer under the foot tabs, not over them (widget calls only: its fields stay the game's).
local FOOTER_Y = -28
local function PlaceFooter()
    local frame, page = T.Host(), Page()
    local footer = frame and frame.bookPageFooter
    local legend = footer and footer.inputLegend
    if legend and page and page:IsShown() then ns.SetPointIf(legend, "TOPLEFT", frame, "BOTTOMLEFT", 0, FOOTER_Y) end
end

-- A pad worn as its tab: the full sheet on the tab's spot, its art and label.
local function WearTab(pad, i, x, y, r, narrow)
    local tab = bookTabs[i]
    ns.SetPointOnce(pad, "CENTER", T.Host(), "TOPLEFT", x, y)
    pad:SetSize(tab:GetWidth() * r, tab:GetHeight() * r)
    pad:SetText(tab:GetText())
    if ns.DressBookTab then ns.DressBookTab(pad, narrow) end
end

-- From the tabs' fixed layout, so a shut window places them too. From the window's top: the tabs hang from the shape's
-- foot, a book's height down, and in a fight the shape stands past the window's foot.
local function PlaceBookPads()
    local frame = T.Host()
    if not bookPads or not frame or InCombatLockdown() then return end
    local k = frame:GetEffectiveScale()
    if not (k and k > 0) then return end
    local hit, spec = ns.BOOK_TAB_HIT, Spec()
    for i, pad in pairs(bookPads) do
        local tab, slot = bookTabs[i], spec.slot[i]
        -- The wide row has no Collections tab
        if not slot then
            pad:Hide()
        elseif PadTabs() then
            local r = tab:GetEffectiveScale() / k
            WearTab(pad, i, ((firstX or spec.x) + slot * spec.step) * r, TabY() * r - T.BookH(), r, spec == NARROW)
            pad:SetFrameLevel(tab:GetFrameLevel() + 5)
            pad:SetShown(PadShown(i))
        else
            local r = tab:GetEffectiveScale() / k
            local w, h = tab:GetWidth(), tab:GetHeight()
            -- The drawn tab only; the sheet's blank margin reached over the window's buttons.
            ns.SetPointOnce(pad, "BOTTOMLEFT", frame, "TOPLEFT", ((firstX or spec.x) + slot * spec.step - w / 2 + spec.hit) * r,
                (TabY() - h / 2 + hit.bottom) * r - T.BookH())
            pad:SetSize((w - 2 * spec.hit) * r, (h - hit.top - hit.bottom) * r)
            pad:SetFrameLevel(tab:GetFrameLevel() + 5)
            pad:SetShown(PadShown(i))
        end
    end
end

T.PlaceBookPads = PlaceBookPads
function T.FirstBookTab() return bookTabs and bookTabs[1] end

-- A crafting page hides the tabs' page under them; the pads, on the window, must follow, out of combat.
function T.SyncBookPads()
    if not bookPads or InCombatLockdown() then return end
    for i, pad in pairs(bookPads) do
        if bookTabs[i] and pad:IsShown() ~= PadShown(i) then
            PlaceBookPads()
            return
        end
    end
end

-- A secure pad for a foot tab: no art, the tab under it shows the press and glow; worn as the tab under the gamepad.
-- HIGH: the toplevel window raises itself over a same-strata pad on every click.
local function NewPad(frame, tab)
    local pad = ns.NewFrame("Button", nil, frame, "SecureActionButtonTemplate")
    pad:SetFrameStrata("HIGH")
    pad:RegisterForClicks("AnyUp", "AnyDown")
    pad:SetAttribute("useOnKeyDown", false)
    if PadTabs() then
        pad.picked = "sbTab1Selected"
        pad.Text = pad:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        pad.Text:SetHeight(13)
        pad.Text:SetPoint("CENTER", pad, "CENTER", 2, 3)
        pad:SetFontString(pad.Text)
        pad:SetNormalFontObject(GameFontNormalSmall)
        pad:SetHighlightFontObject(GameFontHighlightSmall)
    else
        pad:SetScript("OnMouseDown", function() if tab:IsEnabled() then tab:SetButtonState("PUSHED") end end)
        pad:SetScript("OnMouseUp", function() if tab:IsEnabled() then tab:SetButtonState("NORMAL") end end)
        pad:SetScript("OnEnter", function() tab:LockHighlight() end)
        pad:SetScript("OnLeave", function() tab:UnlockHighlight() end)
        -- Shut under the cursor by its own click: no OnLeave comes, so the glow goes here.
        pad:SetScript("OnHide", function()
            tab:UnlockHighlight()
            if tab:IsEnabled() then tab:SetButtonState("NORMAL") end
        end)
    end
    pad:Hide()
    return pad
end

function T.BookTabs()
    local frame, page = T.Host(), Page()
    if not frame or not page or not ns.NewBookTab then return end
    TrainingStandsDown(frame, page)
    local on = ns.SpellBookActive and ns.SpellBookActive() and true or false
    if not bookTabs then
        if not on then return end
        bookTabs = {}
        for i = 1, 4 do bookTabs[i] = ns.NewBookTab(page, i, bookTabs[i - 1]) end
        bookTabs[1]:SetText(SPELLBOOK or "Spellbook")
        bookTabs[4]:SetText(L["SKILL_COLLECTIONS"])
        bookTabs[2]:SetText(TRADE_SKILLS or "Professions")
        bookTabs[2]:SetEnabled(false)
        for i, tab in ipairs(bookTabs) do
            tab:SetScript("OnClick", function()
                if i == 2 then return end
                if i == 4 then
                    ns.BookPageTurn()
                    if _G.CollectionsMicroButton then _G.CollectionsMicroButton:Click() end
                    return
                end
                if InCombatLockdown() then ns.SayNotInCombat() return end
                PlaySound(SOUNDKIT.IG_ABILITY_PAGE_TURN)
                ns.HidePanel(frame)
                ns.ShowSpellBookBank(i == 3)
            end)
        end
        -- Each pad turns the book to its tab (SpellBook's wrap), then presses the spellbook key (its macro closes this
        -- window first): the book opens on that tab in a fight too.
        local key = ns.SpellBookBindButton and ns.SpellBookBindButton()
        if key then
            bookPads = {}
            for _, i in ipairs({ 1, 3 }) do
                local pad = NewPad(frame, bookTabs[i])
                pad:SetAttribute("type", "click")
                pad:SetAttribute("clickbutton", key)
                if ns.SpellBookTurnPad then ns.SpellBookTurnPad(pad, i == 3) end
                if ns.BookTurnPad then ns.BookTurnPad(pad) end
                pad:SetScript("PostClick", function(_, _, down)
                    if down or not ns.SpellBookTurnTo(i == 3) then return end
                    PlaySound(SOUNDKIT.IG_ABILITY_PAGE_TURN)
                    ns.HidePanel(frame)
                end)
                bookPads[i] = pad
            end
            -- Collections: the hidden micro button's own click, in a fight too; under the gamepad the game holds its
            -- window open, so its own close goes first, natively.
            local coll = _G.CollectionsMicroButton
            if coll then
                local pad = NewPad(frame, bookTabs[4])
                if PadTabs() then
                    pad:SetAttribute("type", "macro")
                    pad:SetAttribute("macrotext", "/click ProfessionsFrameCloseButton\n/click CollectionsMicroButton")
                else
                    pad:SetAttribute("type", "click")
                    pad:SetAttribute("clickbutton", coll)
                end
                if ns.BookCollectionsPad then ns.BookCollectionsPad(pad) end
                bookPads[4] = pad
            end
        end
    end
    -- Tucked under the bottom border like the old foot tabs; at -13 they floated clear of it.
    local spec = Spec()
    local narrow = spec == NARROW
    local order = narrow and { 1, 2, 4, 3 } or { 1, 2, 3 }
    local petUp = on and ns.SpellBookPetTitle and ns.SpellBookPetTitle() ~= nil
    local count = (narrow and 3 or 2) + (petUp and 1 or 0)
    firstX = ns.BalancedTabX(spec.x, spec.drawn, spec.step, count, 0, BORDER_W)
    for n, i in ipairs(order) do
        local tab = bookTabs[i]
        if n == 1 then
            ns.SetPointOnce(tab, "CENTER", frame, "BOTTOMLEFT", firstX, TabY())
        else
            ns.SetPointOnce(tab, "LEFT", bookTabs[order[n - 1]], "RIGHT", spec.overlap, 0)
        end
        if ns.DressBookTab then ns.DressBookTab(tab, narrow) end
    end
    -- As the spellbook's foot: unpicked tabs under the window's border, the picked one (disabled) over it.
    local slice = frame.NineSlice
    if slice then
        local level = slice:GetFrameLevel()
        for _, tab in ipairs(bookTabs) do ns.SetLevelIf(tab, tab:IsEnabled() and math.max(1, level - 1) or level + 1) end
    end
    local pet = on and ns.SpellBookPetTitle and ns.SpellBookPetTitle() or nil
    if pet and narrow then pet = PET or "Pet" end
    if pet and bookTabs[3]:GetText() ~= pet then bookTabs[3]:SetText(pet) end
    wanted[1], wanted[3], wanted[4] = on, on and pet ~= nil, on and narrow
    local padTabs = PadTabs() and bookPads ~= nil
    SetShownIf(bookTabs[1], wanted[1] and not padTabs)
    SetShownIf(bookTabs[2], on)
    SetShownIf(bookTabs[3], wanted[3] and not padTabs)
    SetShownIf(bookTabs[4], wanted[4] and not padTabs)
    PlaceBookPads()
    if PadTabs() then ns.Sched.Attach(frame, { name = "prof.padFooter", every = 0.2, fn = PlaceFooter }) end
end
