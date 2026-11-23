local _, ns = ...

-- The spellbook's skill line tab down a window's right edge: an icon in the old plate, gold edge when picked.

local SKILL_TAB = { checked = "checked", add = { Highlight = true, Checked = true }, states = { "Highlight", "Checked" } }
-- The first tab's spot off the window's top right, and the gap down to the next.
local FIRST_X, FIRST_Y, GAP = -32, -65, -17
-- A window with these tabs, beside the next (ns.SetSlotWidth): its art's 352 and the tabs clear of the next window.
ns.SIDE_TAB_SLOT = 392

local SIZE = 32

-- The old plate behind a tab: the spellbook's sheet, 3 left and 11 over.
local function Plate(tab, plate)
    ns.SetTex(plate, "sbSkillTab")
    plate:SetSize(64, 64)
    plate:SetPoint("TOPLEFT", tab, "TOPLEFT", -3, 11)
end

-- SkillLineTab(parent, prev, gap) -> a hidden check button gap under prev (the spellbook's 17), or at the first spot; its
-- icon, scripts and id are the caller's.
function ns.SkillLineTab(parent, prev, gap)
    local tab = ns.NewFrame("CheckButton", nil, parent)
    tab:SetSize(SIZE, SIZE)
    if prev then
        tab:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, gap or GAP)
    else
        tab:SetPoint("TOPLEFT", parent, "TOPRIGHT", FIRST_X, FIRST_Y)
    end
    Plate(tab, tab:CreateTexture(nil, "BACKGROUND"))
    tab:SetNormalTexture("")
    ns.DressStates(tab, nil, nil, nil, "highlight", SKILL_TAB)
    tab:Hide()
    return tab
end

-- One shown tab per page (in tab order, each with its icon), ids from 1; the caller's click and tooltip.
function ns.SideTabsFor(parent, pages, onClick, onEnter)
    local tabs = {}
    for i, page in ipairs(pages) do
        local tab = ns.SkillLineTab(parent, tabs[i - 1])
        tab:SetID(i)
        tab:SetNormalTexture(page.icon)
        tab:SetScript("OnClick", onClick)
        tab:SetScript("OnEnter", onEnter)
        tab:SetScript("OnLeave", GameTooltip_Hide)
        tab:Show()
        tabs[i] = tab
    end
    return tabs
end

---------------------------------------------------------------- other addons' side tabs

-- Another addon's side tab on a window wearing ours (LFG Forever's on the group finder, #335): the game's large side tab,
-- its template known by the mixin, drawn as ours and stacked under our last shown one. Its click, tooltip and checked
-- state stay its own; everything goes back when ours stand down.
local LARGE_LOOK = { "Background", "SelectedTexture", "TabGlow", "HighlightTexture" }
local OUR_LOOK = { "sideTabPlate", "sideTabGlow", "sideTabChecked" }
local adopted = setmetatable({}, { __mode = "k" })
local held = setmetatable({}, { __mode = "k" })

local function LargeSideTab(frame)
    local mixin = _G.SidePanelTabButtonMixin
    if not mixin or ns.IsForbidden(frame) or frame.Icon == nil then return false end
    return frame.SetCustomOnMouseUpHandler == mixin.SetCustomOnMouseUpHandler
end

local function Gather(child, list, own)
    if LargeSideTab(child) and not (own and own(child)) then list[#list + 1] = child end
end

local function Has(list, item)
    for _, entry in ipairs(list) do
        if entry == item then return true end
    end
    return false
end

-- The icon fills the tab, as ours do: again after the template's press nudge and its interior size.
local function FitIcon(tab)
    if not adopted[tab] then return end
    ns.SetPointIf(tab.Icon, "CENTER", tab, "CENTER", 0, 0)
    ns.SetSizeIf(tab.Icon, SIZE, SIZE)
end

-- Our gold edge while its own selected mark is up.
local function Mirror(tab)
    if not adopted[tab] then return end
    local selected = tab.SelectedTexture
    ns.SetShownIf(tab.fcui.sideTabChecked, selected ~= nil and selected:IsShown())
end

local function Adopt(tab)
    local icon = tab.Icon
    local was = { w = tab:GetWidth(), h = tab:GetHeight(), points = ns.PointsOf(tab), alpha = {},
        iconW = icon:GetWidth(), iconH = icon:GetHeight(), iconPoints = ns.PointsOf(icon) }
    for _, key in ipairs(LARGE_LOOK) do
        local piece = tab[key]
        if piece and piece.SetAlpha then
            was.alpha[key] = piece:GetAlpha()
            piece:SetAlpha(0)
        end
    end
    -- The large tab's cut-out shape, off the square icon.
    if tab.Mask and icon.RemoveMaskTexture then
        was.mask = tab.Mask
        ns.WearMask(icon, tab.Mask, false)
    end
    adopted[tab] = was
    if ns.Once(tab, "sideTabAdopt") then
        Plate(tab, ns.OwnTexture(tab, "sideTabPlate", "BACKGROUND"))
        local glow = ns.OwnTexture(tab, "sideTabGlow", "HIGHLIGHT")
        ns.SetTex(glow, "highlight")
        local checked = ns.OwnTexture(tab, "sideTabChecked", "OVERLAY")
        ns.SetTex(checked, "checked")
        for _, edge in ipairs({ glow, checked }) do
            edge:SetAllPoints(tab)
            edge:SetBlendMode("ADD")
        end
        ns.HookScriptOnce(tab, "OnMouseDown", FitIcon, "sideTabAdopt")
        ns.HookScriptOnce(tab, "OnMouseUp", FitIcon, "sideTabAdopt")
        ns.HookMethod(tab, "UpdateIconInterior", FitIcon)
        ns.HookMethod(tab, "SetChecked", Mirror)
    end
    tab.fcui.sideTabPlate:Show()
    tab.fcui.sideTabGlow:Show()
    tab:SetSize(SIZE, SIZE)
    FitIcon(tab)
    Mirror(tab)
end

local function GiveBack(tab)
    local was = adopted[tab]
    if not was then return end
    adopted[tab] = nil
    for _, key in ipairs(OUR_LOOK) do tab.fcui[key]:Hide() end
    for key, alpha in pairs(was.alpha) do tab[key]:SetAlpha(alpha) end
    local icon = tab.Icon
    if was.mask then ns.WearMask(icon, was.mask, true) end
    icon:SetSize(was.iconW, was.iconH)
    ns.PutPoints(icon, was.iconPoints)
    tab:SetSize(was.w, was.h)
    ns.PutPoints(tab, was.points)
end

-- AdoptSideTabs(window, under, own), from the window's own pass while it shows. under: our last shown tab, or nil to give
-- the others back; own(frame): true for the game's own tabs there, left alone. Children are read again on a count change.
function ns.AdoptSideTabs(window, under, own)
    local state = held[window]
    if not state then
        state = { count = -1, list = {} }
        held[window] = state
    end
    local count = window:GetNumChildren()
    if count ~= state.count then
        state.count = count
        local before = state.list
        state.list = {}
        ns.EachChild(window, Gather, state.list, own)
        for _, tab in ipairs(before) do
            if not Has(state.list, tab) then GiveBack(tab) end
        end
    end
    local prev = under
    for _, tab in ipairs(state.list) do
        if not under then
            GiveBack(tab)
        else
            if not adopted[tab] then Adopt(tab) end
            if tab:IsShown() then
                ns.SetPointIf(tab, "TOPLEFT", prev, "BOTTOMLEFT", 0, GAP)
                ns.SetSizeIf(tab, SIZE, SIZE)
                FitIcon(tab)
                Mirror(tab)
                prev = tab
            end
        end
    end
end
