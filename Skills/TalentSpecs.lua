local _, ns = ...

-- Dual spec as Era's talent window has it: a tab per spec down the right edge (the spellbook's) once the character has
-- two; the spec not in use drawn as it is, grayed and locked, with Activate in its points bar's place.

local TL = ns.talents
local SpecInfo = C_SpecializationInfo or {}

-- Era's: the first at the spellbook's first spot, the next 22 under it.
local GAP = -22
-- Activate over the points bar, Era's spot; with the three trees, in Apply's place at the foot.
local ACTIVATE_Y, ACTIVATE_FOOT_Y, ACTIVATE_PAD = -45, -2, 40
local HYBRID_ICON = "Interface\\Icons\\Ability_DualWieldSpecialization"
local UNTALENTED_ICON = "Interface\\Icons\\Ability_Marksmanship"
local SPECS = 2

-- tabs, activate, refresh(); shown: the spec picked; trees: each spec's three trees as last read.
local S = { tabs = {}, trees = {}, shown = 1 }

-- The character's spec count and the active one. /fcuidev dualspec sets TL.fakeSpecs = { active = n }: a second spec
-- drawn from the one there is, Activate swapping which is in use.
function TL.SpecGroups()
    local count = GetNumSpecGroups and GetNumSpecGroups() or 1
    local active = SpecInfo.GetActiveSpecGroup and SpecInfo.GetActiveSpecGroup() or 1
    local fake = TL.fakeSpecs
    if fake then return math.max(count, SPECS), fake.active end
    return count, active
end

local function SpecName(group)
    if group == 1 then return TALENT_SPEC_PRIMARY or "Primary Talents" end
    return TALENT_SPEC_SECONDARY or "Secondary Talents"
end

-- Era's main tree of a spec: the most points, when well clear of the rest; nil for a hybrid or nothing spent.
function TL.MainTree(trees)
    local high, low, highIndex
    local sorted = {}
    for i, tree in ipairs(trees) do
        sorted[i] = tree.spent
        if not high or tree.spent > high then high, highIndex = tree.spent, i end
        if not low or tree.spent < low then low = tree.spent end
    end
    if not high then return nil end
    table.sort(sorted)
    local mid = sorted[math.floor(#sorted / 2) + 1]
    if 3 * (mid - low) < 2 * (high - low) then return highIndex end
    return nil
end

-- The main tree's icon, Era's hybrid one with points in more than one, or its untalented one.
local function SpecIcon(trees)
    if not trees then return UNTALENTED_ICON end
    local main = TL.MainTree(trees)
    if main then return trees[main].icon end
    local spent = 0
    for _, tree in ipairs(trees) do spent = spent + tree.spent end
    return (#trees > 1 and spent > 0) and HYBRID_ICON or UNTALENTED_ICON
end

-- The player's spec on screen when it is not the one in use, else nil. tabsOn: the player's own talents, unhosted.
function TL.OtherSpec(tabsOn)
    local count, active = TL.SpecGroups()
    if not tabsOn or count < SPECS or S.shown == active then return nil end
    return S.shown
end

-- The window's title with two specs: the shown one's name.
function TL.SpecTitle(tabsOn)
    local count = TL.SpecGroups()
    if tabsOn and count >= SPECS then return SpecName(S.shown) end
    return nil
end

-- The window opening, or the spec in use changing: its tab picked.
function TL.ShowActiveSpec()
    local _, active = TL.SpecGroups()
    S.shown = active
end

local function Tab_OnClick(self)
    PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
    S.shown = self:GetID()
    -- A click on the picked tab would uncheck it.
    self:SetChecked(true)
    S.refresh()
end

local function Tab_OnEnter(self)
    local group = self:GetID()
    local _, active = TL.SpecGroups()
    local trees = S.trees[group]
    local main = trees and TL.MainTree(trees)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(SpecName(group))
    if group == active then
        GameTooltip:AddLine(TALENT_ACTIVE_SPEC_STATUS or "These are your active talents", GREEN_FONT_COLOR:GetRGB())
    end
    for i, tree in ipairs(trees or ns.EMPTY) do
        local color = i == main and GREEN_FONT_COLOR or HIGHLIGHT_FONT_COLOR
        GameTooltip:AddDoubleLine(tree.name, tree.spent, 1, 1, 1, color:GetRGB())
    end
    GameTooltip:Show()
end

-- Off while the switch casts, as Era's.
local function UpdateActivate()
    local spell = TALENT_ACTIVATION_SPELLS and TALENT_ACTIVATION_SPELLS[S.shown]
    local casting = spell and C_Spell and C_Spell.IsCurrentSpell and C_Spell.IsCurrentSpell(spell)
    if ns.IsSecret(casting) then casting = false end
    S.activate:SetEnabled(not casting)
end

local function Activate()
    local fake = TL.fakeSpecs
    if fake then
        fake.active = S.shown
        S.refresh()
    elseif SpecInfo.SetActiveSpecGroup then
        SpecInfo.SetActiveSpecGroup(S.shown)
    end
end

-- The tabs and Activate on the talents window; refresh() draws it again.
function TL.BuildSpecs(frame, refresh)
    S.refresh = refresh
    for group = 1, SPECS do
        local tab = ns.SkillLineTab(frame, S.tabs[group - 1], GAP)
        tab:SetID(group)
        tab:SetScript("OnClick", Tab_OnClick)
        tab:SetScript("OnEnter", Tab_OnEnter)
        tab:SetScript("OnLeave", GameTooltip_Hide)
        S.tabs[group] = tab
    end
    local button = ns.PanelButton(frame, TALENT_SPEC_ACTIVATE or "Activate")
    local label = button:GetFontString()
    button:SetWidth(math.ceil(label and label:GetStringWidth() or 0) + ACTIVATE_PAD)
    button:SetScript("OnClick", Activate)
    button:SetScript("OnShow", function(self) ns.RegisterEvents(self, { "CURRENT_SPELL_CAST_CHANGED" }) end)
    button:SetScript("OnHide", function(self) self:UnregisterAllEvents() end)
    button:SetScript("OnEvent", UpdateActivate)
    button:Hide()
    S.activate = button
end

-- The tabs, Activate and the points bar for what the window shows, after the tree is drawn.
function TL.DrawSpecs(frame, tabsOn)
    local count, active = TL.SpecGroups()
    local dual = tabsOn and count >= SPECS
    for group, tab in ipairs(S.tabs) do
        tab:SetShown(dual)
        if dual then
            S.trees[group] = TL.ReadSpecTrees(group ~= active and group or nil)
            tab:SetNormalTexture(SpecIcon(S.trees[group]))
            tab:SetChecked(group == S.shown)
            if GameTooltip:IsOwned(tab) then Tab_OnEnter(tab) end
        end
    end
    local other = TL.OtherSpec(tabsOn) ~= nil
    local three = frame.trees and frame.trees.on
    local button = S.activate
    if other then
        if three then
            ns.SetPointOnce(button, "TOP", frame.foot, "TOP", 0, ACTIVATE_FOOT_Y)
        else
            ns.SetPointOnce(button, "TOP", frame, "TOP", 0, ACTIVATE_Y)
        end
        UpdateActivate()
    end
    button:SetShown(other)
    frame.spentBar:SetShown(not three and not other)
    frame.learn:SetShown(not (three and other))
    local slot = dual and ns.SIDE_TAB_SLOT or nil
    if TL.specSlot ~= slot then
        TL.specSlot = slot
        if frame.trees then frame.trees.Reslot() end
    end
end
