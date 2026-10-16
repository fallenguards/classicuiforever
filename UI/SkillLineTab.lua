local _, ns = ...

-- The spellbook's skill line tab down a window's right edge: an icon in the old plate, gold edge when picked.

local SKILL_TAB = { checked = "checked", add = { Highlight = true, Checked = true }, states = { "Highlight", "Checked" } }
-- The first tab's spot off the window's top right, and the gap down to the next.
local FIRST_X, FIRST_Y, GAP = -32, -65, -17
-- A window with these tabs, beside the next (ns.SetSlotWidth): its art's 352 and the tabs clear of the next window.
ns.SIDE_TAB_SLOT = 392

-- SkillLineTab(parent, prev) -> a hidden check button under prev (or at the first spot); its icon, scripts and id are the caller's.
function ns.SkillLineTab(parent, prev)
    local tab = ns.NewFrame("CheckButton", nil, parent)
    tab:SetSize(32, 32)
    if prev then
        tab:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, GAP)
    else
        tab:SetPoint("TOPLEFT", parent, "TOPRIGHT", FIRST_X, FIRST_Y)
    end
    local plate = tab:CreateTexture(nil, "BACKGROUND")
    ns.SetTex(plate, "sbSkillTab")
    plate:SetSize(64, 64)
    plate:SetPoint("TOPLEFT", tab, "TOPLEFT", -3, 11)
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
