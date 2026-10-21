local _, ns = ...

-- The book's other pages: Collections while its tab stands for it, and the game's professions window on its book page.
-- While one is up the spellbook's micro button stays pushed, and the book's key and button shut that page rather than
-- turn to the spells; shut, the key opens the spells. The bind decides in its own secure run, in a fight too.

local SHUT_NAME = "ForeverClassicUICollectionsShut"
local COLLECTIONS_FLAG = "fcui-collections-page"
local BOOK_BUTTONS = { "SpellbookMicroButton", "PlayerSpellsMicroButton" }
local P = {}

local function ProfessionsBookPage()
    local frame = _G.ProfessionsFrame
    return frame ~= nil and frame:IsShown() and frame.BookPage ~= nil and frame.BookPage:IsShown()
end

-- A page turn (a foot tab): the old page goes a frame or two before the new one shows; the button holds through it.
local TURN_GRACE = 0.3
local turnUntil = 0

-- A page of the book up now, or one on its way (the micro button's pushed state reads it).
function ns.BookPageUp()
    return (ns.CollectionsBookPage and ns.CollectionsBookPage()) or ProfessionsBookPage() or GetTime() < turnUntil
end

-- The micro button from every page's state, once the frame's shows and hides are done: the classic bar's own sync
-- (Bar/BarSkins.lua WindowUp reads the pages), or the client's update hooked by the book (MicroButtonFollows).
local function Refresh()
    if ns.RefreshMicroButtons then ns.RefreshMicroButtons() end
    for _, name in ipairs(BOOK_BUTTONS) do
        local button = _G[name]
        if button and button.UpdateMicroButton then button:UpdateMicroButton() end
    end
end
function ns.BookPagesChanged() ns.Sched.NextFrame("bookPages.micro", Refresh) end

function ns.BookPageTurn()
    turnUntil = GetTime() + TURN_GRACE
    ns.BookPagesChanged()
    C_Timer.After(TURN_GRACE + 0.05, ns.BookPagesChanged)
end
local function TurnOnUp(_, _, down) if not down then ns.BookPageTurn() end end

-- Collections cannot be read by the bind's secure run in a fight (a plain frame of ours): a flag on the bind stands for
-- it, set by our code out of a fight and by the tab's secure pad in one; the press that shuts the page clears it.
local function SyncFlag()
    local bind = _G.ForeverClassicUISpellBookBind
    if not P.wired or not bind or InCombatLockdown() then return end
    bind:SetAttribute(COLLECTIONS_FLAG, (ns.CollectionsBookPage and ns.CollectionsBookPage()) or nil)
end
function ns.CollectionsPageChanged()
    SyncFlag()
    ns.BookPagesChanged()
end

-- The professions window is the game's and protected (its book page's spell buttons are secure): read as it is.
local TURN_FLAG = "fcui-page-turn"
local PRESS = [[
    if self:GetAttribute("]] .. TURN_FLAG .. [[") then
        if not down then self:SetAttribute("]] .. TURN_FLAG .. [[", nil) end
        return
    end
    if self:GetAttribute("]] .. COLLECTIONS_FLAG .. [[") then
        if not down then self:SetAttribute("]] .. COLLECTIONS_FLAG .. [[", nil) end
        return "Button5"
    end
    local prof, page = control:GetFrameRef("prof"), control:GetFrameRef("profPage")
    if prof and page and (not PlayerInCombat() or (prof:IsProtected() and page:IsProtected()))
        and prof:IsShown() and page:IsShown() then
        return "Button6"
    end
]]

-- A page's foot tab turning to the spells presses the bind too (Skills/ProfessionsFootTabs.lua): it says so first,
-- and the bind does what it always did (shut that page, open the book).
local turnPads = {}
local function WrapTurns()
    if not P.header or InCombatLockdown() then return end
    for pad, wrapped in pairs(turnPads) do
        if not wrapped then
            turnPads[pad] = true
            SecureHandlerWrapScript(pad, "OnClick", P.header, [[
                local bind = control:GetFrameRef("bind")
                bind:SetAttribute("]] .. TURN_FLAG .. [[", true)
            ]])
        end
    end
end
function ns.BookTurnPad(pad)
    if turnPads[pad] ~= nil then return end
    turnPads[pad] = false
    pad:HookScript("PostClick", TurnOnUp)
    WrapTurns()
end

-- A page's foot tab opening Collections (the professions window's): in its own secure run the page is up, in a fight too.
local collPads = {}
local function WrapCollPads()
    if not P.header or InCombatLockdown() then return end
    for pad, wrapped in pairs(collPads) do
        if not wrapped then
            collPads[pad] = true
            SecureHandlerWrapScript(pad, "OnClick", P.header, [[
                if down then return end
                control:GetFrameRef("bind"):SetAttribute("]] .. COLLECTIONS_FLAG .. [[", true)
            ]])
        end
    end
end
function ns.BookCollectionsPad(pad)
    if collPads[pad] ~= nil then return end
    collPads[pad] = false
    pad:HookScript("PostClick", TurnOnUp)
    WrapCollPads()
end

-- The game's professions window as a page of the book (our book on, its book page up): in the row it is ours, on the
-- book's spot past the game's windows, not the left slot the game's manager gives it (the sheet flipped sides). Retail's
-- is its own window, which the game spaces as 575 wide.
function ns.BookPageWindow(frame)
    local forever = ns.OnForever()
    local prof = forever and _G.ProfessionsFrame or _G.ProfessionsBookFrame
    if not prof or (frame and frame ~= prof) or not ns.ModuleInForce("professionsBook") then return nil end
    if (forever and ProfessionsBookPage()) or (not forever and prof:IsShown()) then return prof end
end

-- A mover holds the page on its own spot: the book stands where the page is (the page's corner 12, -14 off the book's,
-- as edit mode pairs them), so the pages still turn in place.
local PAGE_X, PAGE_Y = 12, -14
function ns.BookFollowsPage(page)
    local book = _G.ForeverClassicUISpellBook
    if not book or (InCombatLockdown() and ns.WindowLocked(book)) then return end
    local left, top, scale = page:GetLeft(), page:GetTop(), page:GetEffectiveScale()
    if ns.AnySecret(left, top, scale) or not (left and top) then return end
    local toUI, k = scale / UIParent:GetEffectiveScale(), ns.WindowRatio(book) or 1
    local x, y = left * toUI - PAGE_X, top * toUI - PAGE_Y - UIParent:GetHeight()
    ns.SetPointIf(book, "TOPLEFT", UIParent, "TOPLEFT", x / k, y / k)
end

local function WatchProfessions()
    local frame = _G.ProfessionsFrame
    if P.profWatched or not (P.header and frame and frame.BookPage) or InCombatLockdown() then return end
    P.profWatched = true
    -- Its profession tabs stand past its art, as the book's side tabs; on the book's spot each frame it is up.
    if ns.SetSlotWidth then ns.SetSlotWidth(frame, ns.SIDE_TAB_SLOT) end
    ns.Sched.Attach(frame, { name = "bookPages.spot", every = 0, fn = ns.KeepBookPageSpot })
    P.header:SetFrameRef("prof", frame)
    P.header:SetFrameRef("profPage", frame.BookPage)
    ns.Sched.OnVisible(frame, "bookPages.prof", ns.BookPagesChanged)
    ns.Sched.OnVisible(frame.BookPage, "bookPages.profPage", ns.BookPagesChanged)
end

-- Out of combat, once the bind and the Collections tab's pad exist (the book's first build).
function ns.WireBookPages()
    local bind, book = _G.ForeverClassicUISpellBookBind, _G.ForeverClassicUISpellBook
    if P.wired or InCombatLockdown() or not (bind and book) then
        WatchProfessions()
        return
    end
    P.wired = true
    local shut = ns.NewFrame("Button", SHUT_NAME, UIParent)
    shut:SetScript("OnClick", function() if ns.ShutCollectionsPage then ns.ShutCollectionsPage() end end)
    P.header = CreateFrame("Frame", nil, UIParent, "SecureHandlerBaseTemplate")
    P.header:SetFrameRef("bind", bind)
    bind:SetAttribute("type5", "macro")
    bind:SetAttribute("macrotext5", "/click " .. SHUT_NAME)
    bind:SetAttribute("type6", "macro")
    bind:SetAttribute("macrotext6", "/click ProfessionsFrameCloseButton")
    SecureHandlerWrapScript(bind, "OnClick", P.header, PRESS)
    -- The book's own foot tabs to its other pages: pads while the layer is up, the tabs themselves otherwise.
    for i, key in pairs({ [2] = "prof", [4] = "coll" }) do
        local foot = book.FootPads and book.FootPads[key]
        if foot then foot:HookScript("PostClick", TurnOnUp) end
        if foot and key == "coll" then
            SecureHandlerWrapScript(foot, "OnClick", P.header, [[
                if down then return end
                control:GetFrameRef("bind"):SetAttribute("]] .. COLLECTIONS_FLAG .. [[", true)
            ]])
        end
        local tab = book.BookTabs and book.BookTabs[i]
        if tab then tab:HookScript("OnClick", ns.BookPageTurn) end
    end
    ns.Sched.OnVisible(book, "bookPages.book", ns.BookPagesChanged)
    WatchProfessions()
    WrapTurns()
    WrapCollPads()
    SyncFlag()
end

ns.EventFrame({ "ADDON_LOADED", "PLAYER_REGEN_ENABLED" }, function()
    ns.WireBookPages()
    WrapTurns()
    WrapCollPads()
    SyncFlag()
end)
