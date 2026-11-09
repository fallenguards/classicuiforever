local _, ns = ...

-- What's Training's professions list (its page over the professions window) laid as the spellbook's trainer list: a
-- line a recipe (icon, name, its profession, the skill at the right) under its category bar, profession headers
-- folded away, on the skill windows' black marble (his pick), the book's page faded under it. Its list runs as it did.

local T = ns.prof
-- The spellbook list's lines: 16 apart; a heading its own bar (28, the band's art), 8 under the lines before it.
local ROW_PITCH, HEAD_H, HEAD_GAP, ICON = 16, 28, 8, 14
local NAME_X, SUB_GAP, NAME_GAP, SKILL_RIGHT = ICON + 4, 2, 8, -4
-- The heading's fold mark (Era's plus and minus) at the bar's left, its words after it; its own words started at 8.
local FOLD_X, FOLD, HEAD_TEXT_X, OWN_HEAD_X = 6, 16, 26, 8
local PLUS, MINUS = "Interface\\Buttons\\UI-PlusButton-Up", "Interface\\Buttons\\UI-MinusButton-Up"
-- Its icon as it made it.
local OWN_ICON, OWN_ICON_X = 24, 8
-- A folded profession header: out of the way, never zero for the list's sums.
local FOLDED = 1
-- The list box: its own left and top, the foot where its hint stood (its own foot 36).
local BOX_LEFT, BOX_TOP, BOX_RIGHT, BOX_FOOT, OWN_BOX_FOOT = 14, -51, -30, 14, 36
local DRESS_EVERY = 0.1
-- Era's arrow centered on the 18 high Filter button (23 x 22 from its top right).
local ARROW_X, ARROW_Y, LABEL_RIGHT = -1, 2, -24

local styled = false
local undo = {}                                      -- what the look took, handed back in reverse when it goes
local looked = setmetatable({}, { __mode = "k" })    -- rows dressed once

local function Hide(piece)
    if not piece or not piece:IsShown() then return end
    piece:Hide()
    undo[#undo + 1] = function() piece:Show() end
end

-- Our font, the color it had kept (the list colors a heading by its category).
local function Font(text, object)
    local was = text:GetFontObject()
    local r, g, b = text:GetTextColor()
    text:SetFontObject(object)
    text:SetTextColor(r, g, b)
    undo[#undo + 1] = function()
        text:SetFontObject(was)
        text:SetTextColor(r, g, b)
    end
end

local function HideUnnamed(child)
    if not child:GetName() then Hide(child) end
end

local function HideSelf(self)
    if styled then self:Hide() end
end

-- The skill windows' black marble on the face's own art frame (the spellbook's on the book, Era's trade skill window on
-- a profession), under its gray border and header as on the spellbook page; its own dark page goes.
local marbles = {}
local function Marble()
    local kind = T.EraKind and T.EraKind()
    local holder = kind and T.EraHolder(kind)
    if not holder then return nil end
    local floor = marbles[holder]
    if not floor then
        floor = ns.TrainingMarble(holder)
        floor:Hide()
        marbles[holder] = floor
    end
    return floor
end
local function HideMarbles()
    for _, floor in pairs(marbles) do floor:Hide() end
end

-- The list's heights: a recipe line, a heading, a profession header folded.
local function Extent(index, node)
    local data = node:GetData()
    if data.recipe then return ROW_PITCH end
    if data.profession then return FOLDED end
    return index == 1 and HEAD_H or HEAD_H + HEAD_GAP
end
local function NoIndent() return 0 end

-- After its own layout (its last call is the source cell's width): the spellbook list's line, the name at the icon,
-- the profession after it to the skill, which stands at the right.
local function LayRecipe(row)
    local data = row.data
    if not styled or not data then return end
    local name, skill = row.cells[1], row.cells[2]
    ns.SetPointOnce(name, "LEFT", row, "LEFT", NAME_X, 0)
    name:SetWidth(0)
    ns.SetPointOnce(skill, "RIGHT", row, "RIGHT", SKILL_RIGHT, 0)
    skill:SetJustifyH("RIGHT")
    skill:SetWidth(0)
    local sub = ns.OwnFontString(row, "profSub", "OVERLAY", "NewSubSpellFont")
    sub:SetJustifyH("LEFT")
    sub:SetWordWrap(false)
    sub:SetText(data.profession or "")
    ns.SetTwoPointsIf(sub, "LEFT", name, "RIGHT", SUB_GAP, 0, "RIGHT", skill, "LEFT", -SUB_GAP, 0)
    -- A name that would run into the skill ends in an ellipsis (its hover tooltip has it whole); the profession
    -- shows only where both fit.
    local room = (row:GetWidth() or 0) - NAME_X - (skill:GetStringWidth() or 0) - NAME_GAP
    local wide, subWide = name:GetStringWidth() or 0, sub:GetStringWidth() or 0
    if wide + SUB_GAP + subWide <= room then
        sub:Show()
    else
        sub:Hide()
        if wide > room then name:SetWidth(math.max(1, room)) end
    end
end

local function DressRecipe(row)
    if looked[row] then return end
    looked[row] = true
    Hide(row.iconBorder)
    Hide(row.cells[3])
    row.icon:SetSize(ICON, ICON)
    ns.SetPointOnce(row.icon, "LEFT", row, "LEFT", 0, 0)
    Font(row.cells[1], "GameFontNormal")
    row.cells[1]:SetTextColor(NORMAL_FONT_COLOR:GetRGB())
    Font(row.cells[2], "GameFontHighlight")
    undo[#undo + 1] = function()
        row.icon:SetSize(OWN_ICON, OWN_ICON)
        ns.SetPointOnce(row.icon, "LEFT", row, "LEFT", OWN_ICON_X, 0)
        local sub = row.fcui and row.fcui.profSub
        if sub then sub:Hide() end
    end
    ns.HookMethod(row.cells[3], "SetWidth", function() LayRecipe(row) end)
    ns.HookMethod(row.rankBackground, "SetShown", HideSelf)
    ns.HookMethod(row.separator, "SetShown", HideSelf)
    LayRecipe(row)
end

-- The bar's mark: plus folded, minus open.
local function UpdateFold(row)
    local fold = row.fcui and row.fcui.fold
    local node = fold and row.GetElementData and row:GetElementData()
    if node and node.IsCollapsed then fold:SetTexture(node:IsCollapsed() and PLUS or MINUS) end
end

-- A left click folds the section (its right click keeps its menu).
local function FoldSection(row, button)
    if button ~= "LeftButton" or not styled then return end
    local node = row.GetElementData and row:GetElementData()
    if not (node and node.SetCollapsed) then return end
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    node:SetCollapsed(not node:IsCollapsed())
    UpdateFold(row)
end

local function DressHeading(row)
    if looked[row] then return end
    looked[row] = true
    local heading = row.heading
    Font(heading, "GameFontNormal")
    ns.SetTwoPointsIf(heading, "BOTTOMLEFT", row, "BOTTOMLEFT", HEAD_TEXT_X, 0, "BOTTOMRIGHT", row, "BOTTOMRIGHT", -OWN_HEAD_X, 0)
    local fold = ns.OwnTexture(row, "fold", "OVERLAY")
    fold:SetSize(FOLD, FOLD)
    ns.SetPointOnce(fold, "LEFT", row, "LEFT", FOLD_X, 0)
    fold:Show()
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    ns.HookScriptOnce(row, "OnClick", FoldSection, "trainingFold")
    undo[#undo + 1] = function()
        ns.SetTwoPointsIf(heading, "BOTTOMLEFT", row, "BOTTOMLEFT", OWN_HEAD_X, 0, "BOTTOMRIGHT", row, "BOTTOMRIGHT", -OWN_HEAD_X, 0)
        fold:Hide()
        row:RegisterForClicks("RightButtonUp")
    end
end

local function DressRow(row)
    if row.cells then
        DressRecipe(row)
        row.rankBackground:Hide()
        row.separator:Hide()
    elseif row.heading then
        DressHeading(row)
        UpdateFold(row)
    elseif row.ButtonText and not looked[row] then
        looked[row] = true
        row:SetAlpha(0)
        undo[#undo + 1] = function() row:SetAlpha(1) end
    end
end

-- The folded profession headers were the list's only handle on a group: here every group stays open (its saved
-- folds and its menu's fold-all are undone as they land).
local function ExpandAll(view)
    if not styled then return end
    local changed = false
    for _, category in ipairs(view.categoryNodes or ns.EMPTY) do
        for _, node in ipairs(category:GetNodes()) do
            if node:IsCollapsed() then
                node:SetCollapsed(false, false, true)
                changed = true
            end
        end
    end
    if changed and view.provider then view.provider:Invalidate() end
end

local function DressList(view)
    ExpandAll(view)
    local box = view.scrollBox
    if box and box.ForEachFrame then box:ForEachFrame(DressRow) end
end

local function Relist(box)
    if box.FullUpdate then box:FullUpdate(ScrollBoxConstants and ScrollBoxConstants.UpdateImmediately) end
end

-- The page up: the book's page faded and our trade skill page hidden under it, the face's marble shown; its art frame
-- is made out of a fight, so the marble may come at a later show.
local function Fade(on)
    if not styled then return end
    T.FadePage(on)
    ns.TradeSkillCover(on)
    HideMarbles()
    local floor = Marble()
    if floor then floor:SetShown(on) end
end
local function FadeIn() Fade(true) end
local function FadeOut() Fade(false) end

local function Style(page, view)
    styled = true
    -- The title stands down in ProfessionsFootTabs.
    ns.EachChild(page, HideUnnamed)
    undo[#undo + 1] = HideMarbles
    Hide(view.footer)
    local box = view.scrollBox
    ns.SetTwoPointsIf(box, "TOPLEFT", view, "TOPLEFT", BOX_LEFT, BOX_TOP, "BOTTOMRIGHT", view, "BOTTOMRIGHT", BOX_RIGHT, BOX_FOOT)
    local tree = box:GetView()
    local extent, indent = tree:GetElementExtentCalculator(), tree.elementIndentCalculator
    tree:SetElementExtentCalculator(Extent)
    tree:SetElementIndentCalculator(NoIndent)
    undo[#undo + 1] = function()
        ns.SetTwoPointsIf(box, "TOPLEFT", view, "TOPLEFT", BOX_LEFT, BOX_TOP, "BOTTOMRIGHT", view, "BOTTOMRIGHT", BOX_RIGHT, OWN_BOX_FOOT)
        tree:SetElementExtentCalculator(extent)
        tree:SetElementIndentCalculator(indent)
        Relist(box)
    end
    ns.SkinMinimalScrollBar(_G.WhatsTrainingCraftingScrollBar)
    ns.EraDropdownArt(view.filterDropdown, ARROW_X, ARROW_Y, LABEL_RIGHT)
    -- Its every fill folds groups back as saved: opened again in the same breath.
    ns.HookMethod(view, "Filter", ExpandAll)
    DressList(view)
    Relist(box)
    Fade(page:IsShown())
end

local function Unstyle()
    styled = false
    for i = #undo, 1, -1 do undo[i]() end
    wipe(undo)
    wipe(looked)
    T.FadePage(false)
    ns.TradeSkillCover(false)
end

-- The look on (the book ours) or off, applied once; new rows dressed every 0.1 s while the page shows.
function ns.TrainingPageLook(page, on)
    local view = _G.WhatsTrainingCraftingRecipeList
    if not (view and view.scrollBox and view.scrollBox.GetView and view.filterDropdown and view.footer) then return end
    if on and not styled then
        Style(page, view)
        ns.HookScriptOnce(page, "OnShow", FadeIn, "trainingFade")
        ns.HookScriptOnce(page, "OnHide", FadeOut, "trainingFade")
        ns.Sched.Attach(page, { name = "prof.trainingLook", every = DRESS_EVERY, fn = function()
            if styled then DressList(view) end
        end })
    elseif not on and styled then
        Unstyle()
    end
end
