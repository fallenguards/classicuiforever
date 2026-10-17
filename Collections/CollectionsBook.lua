local _, ns = ...
local L = ns.L

-- The Collections window as a page of the spellbook, as the old book's pages: the book's foot tabs at its foot
-- (Spellbook, Professions, Collections picked, the pet's), on the book's spot, one of the three windows up at a time.

local CW = ns.collections

-- The spellbook's foot spots (Spells/SpellBook.lua LayTabs): wide 1.x tabs, narrow with a fourth tab or the book's own
-- Collections tab; the book's drawn border runs 12 to 350.
local WIDE = { first = 79, step = 108, drawn = 100, overlap = -20 }
local NARROW = { first = 66, step = 80, drawn = 74, overlap = -48 }
local TAB_Y, ART_LEFT, ART_RIGHT = 61, 12, 350

local B = {}

local function PetTitle()
    return ns.SpellBookPetTitle and ns.SpellBookPetTitle() or nil
end

-- Plain buttons on our own window: laid in a fight too (the pet's tab hung empty past the rest till one ended).
local function LayTabs()
    local pet = PetTitle()
    local narrow = pet ~= nil or (ns.BookCollectionsTab and ns.BookCollectionsTab()) or false
    local spec = narrow and NARROW or WIDE
    local tabs = B.tabs
    local order = { tabs[1], tabs[2], tabs[3], pet and tabs[4] or nil }
    if pet then tabs[4]:SetText(narrow and PET or pet) end
    ns.SetShownIf(tabs[4], pet ~= nil)
    local first = ns.BalancedTabX(spec.first, spec.drawn, spec.step, #order, ART_LEFT, ART_RIGHT)
    for i, tab in ipairs(order) do
        if i == 1 then
            ns.SetPointOnce(tab, "CENTER", B.frame, "BOTTOMLEFT", first, TAB_Y)
        else
            ns.SetPointOnce(tab, "LEFT", order[i - 1], "RIGHT", spec.overlap, 0)
        end
        ns.DressBookTab(tab, narrow)
    end
end

-- A turn to another page: it opens, then this window shuts.
local function TurnTo(open)
    ns.BookPageTurn()
    if not open() then return end
    PlaySound(SOUNDKIT.IG_ABILITY_PAGE_TURN)
    B.frame:Hide()
end

local function OpenBook() return ns.ShowSpellBookBank(false) end
local function OpenPet() return ns.ShowSpellBookBank(true) end

-- The game opens its professions window only for the player's own press, never in a fight from ours.
local function OpenProfessions()
    if InCombatLockdown() then
        ns.SayNotInCombat()
        return false
    end
    return ns.OpenProfessionsBook and ns.OpenProfessionsBook()
end

local OPENERS = { OpenBook, OpenProfessions, nil, OpenPet }

local function BuildTabs(frame)
    local tabs = {}
    for i = 1, 4 do
        local tab = ns.NewBookTab(frame, i, tabs[i - 1])
        local open = OPENERS[i]
        tab:SetScript("OnClick", function() if open then TurnTo(open) end end)
        -- The pet's only with a pet (LayTabs).
        if i < 4 then tab:Show() end
        tabs[i] = tab
    end
    tabs[1]:SetText(SPELLBOOK or "Spellbook")
    tabs[2]:SetText(TRADE_SKILLS or "Professions")
    tabs[3]:SetText(L["SKILL_COLLECTIONS"])
    -- Picked, as the book's picked tab: disabled, drawn over the border.
    tabs[3]:SetEnabled(false)
    B.tabs = tabs
end

-- The book or the professions window coming up shuts this one; this one coming up shuts them. In a fight the book too:
-- the tab's or the button's macro dropped its casting layer first, and its own hide fades it till the fight ends (it
-- stayed up beside this window). The professions window only out of one (the pad's macro closes it there).
local function OthersShut()
    local book = _G.ForeverClassicUISpellBook
    if book and book:IsShown() and book:GetAlpha() > 0 then ns.HideSpellBook() end
    if InCombatLockdown() then return end
    local prof = _G.ProfessionsFrame
    if prof and prof:IsShown() then ns.HidePanel(prof) end
end

local function WatchOthers()
    local book = _G.ForeverClassicUISpellBook
    if book and not B.bookWatched then
        B.bookWatched = true
        ns.Sched.OnVisible(book, "collections.book", function(shown)
            if shown and B.frame:IsShown() then B.frame:Hide() end
        end)
    end
    local prof = _G.ProfessionsFrame
    if prof and not B.profWatched then
        B.profWatched = true
        ns.Sched.AfterShow(prof, "collections.book", function()
            if B.frame:IsShown() then B.frame:Hide() end
        end)
    end
end

-- The micro button's pad closes the book page up first, in a fight too: the macro lines, or nil.
function CW.BookCloserLines()
    local lines = ""
    local book = _G.ForeverClassicUISpellBook
    if book and book:IsShown() then lines = "/click ForeverClassicUISpellBookLayerOff\n" end
    local prof = _G.ProfessionsFrame
    if prof and prof:IsShown() and _G.ProfessionsFrameCloseButton then lines = lines .. "/click ProfessionsFrameCloseButton\n" end
    return lines ~= "" and lines or nil
end

-- A page of the book while the book's Collections tab stands for it (its micro button hidden): Spells/BookPages.lua.
function ns.CollectionsBookPage()
    return B.frame ~= nil and B.frame:IsShown() and ns.BookCollectionsTab ~= nil and ns.BookCollectionsTab() == true
end
function ns.ShutCollectionsPage()
    if B.frame and B.frame:IsShown() then B.frame:Hide() end
end

-- Called as the window is built and each time it shows.
function CW.BuildFoot(frame)
    B.frame = frame
    -- Our own watch: the window's SetScripts after this wipe a hook on it.
    ns.Sched.OnVisible(frame, "collections.page", ns.CollectionsPageChanged)
    if not (ns.NewBookTab and ns.SpellBookActive and ns.SpellBookActive()) then return end
    BuildTabs(frame)
end

function CW.FootShown()
    WatchOthers()
    OthersShut()
    if B.tabs then LayTabs() end
    ns.WireBookPages()
end
