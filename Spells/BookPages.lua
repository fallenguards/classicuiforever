local _, ns = ...

-- The book's other pages: Collections while its tab stands for it, and the game's professions window on its book page.
-- While one is up the spellbook's micro button stays pushed, and the book's key and button shut that page rather than
-- turn to the spells; shut, the key opens the book on it again. The bind decides in its own secure run, in a fight too.

local SHUT_NAME = "ForeverClassicUICollectionsShut"
local COLLECTIONS_FLAG = "fcui-collections-page"
-- The page the book showed last ("prof", "coll"; nil: the spells): out of a fight from what shows, in one from the pads.
local LAST_PAGE = "fcui-last-page"
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

-- A page that just showed is the book's last (out of a fight; a shown edge, so the newest wins).
local function Showed(page)
    local bind = _G.ForeverClassicUISpellBookBind
    if P.wired and bind and not InCombatLockdown() then bind:SetAttribute(LAST_PAGE, page) end
end

-- Collections cannot be read by the bind's secure run in a fight (a plain frame of ours): a flag on the bind stands for
-- it, set by our code out of a fight and by the tab's secure pad in one; the press that shuts the page clears it.
local function SyncFlag()
    local bind = _G.ForeverClassicUISpellBookBind
    if not P.wired or not bind or InCombatLockdown() then return end
    bind:SetAttribute(COLLECTIONS_FLAG, (ns.CollectionsBookPage and ns.CollectionsBookPage()) or nil)
end
function ns.CollectionsPageChanged(shown)
    SyncFlag()
    if shown and ns.CollectionsBookPage and ns.CollectionsBookPage() then Showed("coll") end
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
    local last = self:GetAttribute("]] .. LAST_PAGE .. [[")
    if last == "prof" then return "Button7" end
    if last == "coll" then
        if not down then self:SetAttribute("]] .. COLLECTIONS_FLAG .. [[", true) end
        return "Button8"
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
                bind:SetAttribute("]] .. LAST_PAGE .. [[", nil)
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

-- A page's foot tab opening Collections (the professions window's): in its own secure run, the page is the last one
-- and up, in a fight too.
local collPads = {}
local function WrapCollPads()
    if not P.header or InCombatLockdown() then return end
    for pad, wrapped in pairs(collPads) do
        if not wrapped then
            collPads[pad] = true
            SecureHandlerWrapScript(pad, "OnClick", P.header, [[
                if down then return end
                local bind = control:GetFrameRef("bind")
                bind:SetAttribute("]] .. LAST_PAGE .. [[", "coll")
                bind:SetAttribute("]] .. COLLECTIONS_FLAG .. [[", true)
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

local function ProfessionsShown()
    if ProfessionsBookPage() then Showed("prof") end
    ns.BookPagesChanged()
end

-- The game's professions window as a page of the book (our book on, its book page up): in the row it is ours, on the
-- book's spot past the game's windows, not the left slot the game's manager gives it (the sheet flipped sides).
function ns.BookPageWindow(frame)
    local prof = _G.ProfessionsFrame
    if not prof or (frame and frame ~= prof) then return nil end
    if ns.ModuleInForce("professionsBook") and ProfessionsBookPage() then return prof end
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
    ns.Sched.OnVisible(frame, "bookPages.prof", ProfessionsShown)
    ns.Sched.OnVisible(frame.BookPage, "bookPages.profPage", ProfessionsShown)
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
    bind:SetAttribute("type7", "macro")
    bind:SetAttribute("macrotext7", "/click ProfessionMicroButton")
    bind:SetAttribute("type8", "macro")
    bind:SetAttribute("macrotext8", "/click CollectionsMicroButton")
    SecureHandlerWrapScript(bind, "OnClick", P.header, PRESS)
    -- The book's own foot tabs to its other pages: pads while the layer is up, the tabs themselves otherwise.
    for i, key in pairs({ [2] = "prof", [4] = "coll" }) do
        local foot = book.FootPads and book.FootPads[key]
        if foot then
            foot:HookScript("PostClick", TurnOnUp)
            SecureHandlerWrapScript(foot, "OnClick", P.header, [[
                if down then return end
                local bind = control:GetFrameRef("bind")
                bind:SetAttribute("]] .. LAST_PAGE .. [[", "]] .. key .. [[")
                if "]] .. key .. [[" == "coll" then bind:SetAttribute("]] .. COLLECTIONS_FLAG .. [[", true) end
            ]])
        end
        local tab = book.BookTabs and book.BookTabs[i]
        if tab then tab:HookScript("OnClick", ns.BookPageTurn) end
    end
    ns.Sched.OnVisible(book, "bookPages.book", function(shown)
        if shown then Showed(nil) end
        ns.BookPagesChanged()
    end)
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
