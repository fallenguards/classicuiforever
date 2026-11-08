local _, ns = ...

-- What's Training's list on a page of the classic book, under its own side tab, as that addon's spellbook tab shows it:
-- its floating window (built by its slash command) is carried into the book, its dialog chrome put away, its pieces on
-- Era's spots. The book shows and hides it with the page; its own openers open the book on the page.

-- Era's page, the rows 8 lower and one fewer (his pick): 16 apart, over the arrows' spots (hidden with the page);
-- the bar in the page's margin.
local ROWS = 21
local SEARCH_X, SEARCH_Y, SEARCH_W = 81, -34, 124
local ROW_X, ROW_Y = 26, -86
local BAR_TOP, BAR_RIGHT, BAR_FOOT = -83, -65, 81
-- The window's own rect: the page body, off the title row and foot tabs (its rows and bar hang on the book itself).
local BODY_TOP, BODY_RIGHT, BODY_FOOT = -30, -34, 79
-- The skill windows' black marble over the parchment (his pick: the words read better there), a region of the book
-- over its art and under its title and every child (the X, the tabs): its edges from the book's (x + right, y + up),
-- inside the art's bright inset lines (measured: rows 34 and 431, columns 15 and 349).
local TRAINING_MARBLE_LEFT = 19
local TRAINING_MARBLE_TOP = -35
local TRAINING_MARBLE_RIGHT = -41
local TRAINING_MARBLE_BOTTOM = 82
-- The ring's corner lies on the marble: the ring alone and the icon in its hole drawn again over it.
local RING_PIECES = {
    { key = "sbIcon", layer = "BACKGROUND", sublevel = 2, w = 58, h = 58, point = "TOPLEFT", x = 10, y = -8 },
    { key = "sbRing", layer = "BACKGROUND", sublevel = 3, w = 96, h = 96, point = "TOPLEFT" },
}

local list, pieces

local function HideRegion(region) region:Hide() end

-- The marble on a frame wearing the spellbook's art (the book; the professions book's frame, Skills/ProfessionsTraining.lua).
function ns.TrainingMarble(frame)
    local marble = ns.MarbleFloor(frame, 1)
    ns.SetTwoPointsIf(marble, "TOPLEFT", frame, "TOPLEFT", TRAINING_MARBLE_LEFT, TRAINING_MARBLE_TOP,
        "BOTTOMRIGHT", frame, "BOTTOMRIGHT", TRAINING_MARBLE_RIGHT, TRAINING_MARBLE_BOTTOM)
    return marble
end

local function Pieces(book)
    if pieces then return pieces end
    pieces = ns.DressPieces(book, RING_PIECES, nil, true)
    pieces[#pieces + 1] = ns.TrainingMarble(book)
    for _, piece in ipairs(pieces) do piece:Hide() end
    return pieces
end

local function BookShowsList(book)
    return book:IsShown() and ns.SpellBookTrainingUp()
end

local function Attach(frame, book)
    frame:SetParent(book)
    frame:SetFrameStrata(book:GetFrameStrata())
    frame:SetFrameLevel(book:GetFrameLevel() + 5)
    frame:SetMovable(false)
    frame:RegisterForDrag()
    frame:SetClampedToScreen(false)
    -- Its rows take the mouse; the window itself leaves the book's to the book.
    frame:EnableMouse(false)
    ns.EachRegion(frame, HideRegion)
    local close = _G[frame:GetName() .. "Close"]
    if close then close:Hide() end
    ns.SetTwoPointsIf(frame, "TOPLEFT", book, "TOPLEFT", 0, BODY_TOP, "BOTTOMRIGHT", book, "BOTTOMRIGHT", BODY_RIGHT, BODY_FOOT)
    ns.SetPointOnce(frame.searchBox, "TOPLEFT", book, "TOPLEFT", SEARCH_X, SEARCH_Y)
    frame.searchBox:SetWidth(SEARCH_W)
    ns.SetTwoPointsIf(frame.scrollBar, "TOPLEFT", book, "TOPLEFT", 0, BAR_TOP, "BOTTOMRIGHT", book, "BOTTOMRIGHT", BAR_RIGHT, BAR_FOOT)
    local rows = frame.rows
    ns.SetTwoPointsIf(rows[1], "TOPLEFT", book, "TOPLEFT", ROW_X, ROW_Y, "RIGHT", frame.scrollBar, "RIGHT", 0, 0)
    -- Built for more rows than the page holds: the rest stay out of sight and its bar scrolls by the page's count.
    frame.maxRows = ROWS
    for i = ROWS + 1, #rows do
        rows[i]:SetAlpha(0)
        rows[i]:EnableMouse(false)
    end
    -- Shown from outside (its slash command, its minimap button): the book opens on the page.
    frame:HookScript("OnShow", function(self)
        if BookShowsList(book) then return end
        if not ns.ShowSpellBookTraining() then self:Hide() end
    end)
    -- Hidden from outside while the page is up (the client's Escape): the book goes with it, as Era's did.
    frame:HookScript("OnHide", function(self)
        if BookShowsList(book) and not self:IsShown() then ns.HideSpellBook() end
    end)
    book:HookScript("OnHide", function() frame:Hide() end)
end

-- The list, carried into the book on first use; nil without the addon.
function ns.TrainingList(book)
    if list then return list end
    local open = SlashCmdList and SlashCmdList.WHATSTRAINING
    if type(open) ~= "function" then return nil end
    local frame = _G.WhatsTrainingFloatingFrame
    if not frame then
        -- Its command builds the window and shows it; another addon's code, kept from ending our click.
        pcall(open, "")
        frame = _G.WhatsTrainingFloatingFrame
    end
    if not frame or not frame.rows or not frame.scrollBar or not frame.searchBox then return nil end
    Attach(frame, book)
    list = frame
    return frame
end

-- The page's pieces: the list up and the spells' slots, arrows, page number, search and options down, or back.
function ns.ShowTrainingPage(book, on)
    on = on == true and list ~= nil
    if list then
        list:SetShown(on)
        for _, piece in ipairs(Pieces(book)) do piece:SetShown(on) end
    end
    -- The drawn slots; the casting buttons over them are secure and stay as they are (their layer is down).
    for _, btn in ipairs(book.Buttons) do btn.slotFrame:SetShown(not on) end
    book.PageText:SetShown(not on)
    book.PrevPage:SetShown(not on)
    book.NextPage:SetShown(not on)
    book.Search:SetShown(not on and ns.db.spellBookSearch ~= false)
    if on then book.Options:Hide() end
end
