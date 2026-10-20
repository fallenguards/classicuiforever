local _, ns = ...
local L = ns.L

-- The Pets page's battle team (retail), as the character sheet's side panel: an arrow in the box's corner widens the
-- window with its own art (the close button and side tabs move out with its edge). Three loadout slots, each its pet,
-- level, health and three abilities (a click takes the other of its pair); a pet dropped onto a slot; Revive Battle Pets.

local PJ, PB = C_PetJournal, _G.C_PetBattles
if ns.OnForever() or not (PJ and PJ.GetPetLoadOutInfo and PB) then return end
local CW = ns.collections

-- The window widens by a copy of its left quarters' columns 76..256 (past the portrait ring: band and parchment), set
-- between them and the right quarters, which it runs on into seamlessly. The team stands on the new parchment, its
-- title in the band; from the window's top left.
local WINDOW_W, EXTRA = 384, 180
local PANEL_X, PANEL_Y, PANEL_W, PANEL_H = 352, -41, 160, 380
local ARROW, ARROW_INSET = 24, 4
local SLOT_TOP, SLOT_H, ICON, ABILITY, ABILITY_STEP = -44, 98, 37, 26, 30
local SLOTS, REVIVE_SPELL = 3, 125439

local T = { slots = {}, open = false }

local function Unlocked() return PJ.IsJournalUnlocked and PJ.IsJournalUnlocked() == true end

-- The pair a slot's ability button holds: ability j and j + 3 of the species, each with its level.
local function Pair(speciesID, j)
    local abilities, levels = PJ.GetPetAbilityList(speciesID)
    if not abilities then return nil end
    return abilities[j], levels[j], abilities[j + 3], levels[j + 3]
end

local function AbilityTip(self)
    if not self.abilityID then return end
    local _, name, _, _, description = PB.GetAbilityInfoByID(self.abilityID)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(name or "")
    if type(description) == "string" then GameTooltip:AddLine(description, 1, 1, 1, true) end
    GameTooltip:Show()
end

local function Ability_OnClick(self)
    local slot = self:GetParent()
    if not (slot.speciesID and Unlocked()) then return end
    local a, aLevel, b, bLevel = Pair(slot.speciesID, self:GetID())
    local other, otherLevel = a, aLevel
    if self.abilityID == a then other, otherLevel = b, bLevel end
    if other and (otherLevel or 0) <= (slot.level or 0) then PJ.SetAbility(slot:GetID(), self:GetID(), other) end
end

-- A pet on the cursor (dragged from the page) takes the slot.
local function TakeCursorPet(self)
    local kind, petID = GetCursorInfo()
    if kind ~= "battlepet" or not Unlocked() then return false end
    PJ.SetPetLoadOutInfo(self:GetParent():GetID(), petID)
    ClearCursor()
    return true
end

local function Icon_OnClick(self)
    TakeCursorPet(self)
end

local function Icon_OnDragStart(self)
    local petID = self:GetParent().petID
    if petID and Unlocked() then PJ.PickupPet(petID) end
end

local function Icon_OnEnter(self)
    local petID = self:GetParent().petID
    if not petID then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if GameTooltip.SetCompanionPet then GameTooltip:SetCompanionPet(petID) end
    GameTooltip:Show()
end

local function BuildSlot(panel, i)
    local slot = ns.NewFrame("Frame", nil, panel)
    slot:SetID(i)
    slot:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, SLOT_TOP - (i - 1) * SLOT_H)
    slot:SetPoint("RIGHT", panel, "RIGHT", 0, 0)
    slot:SetHeight(SLOT_H - 8)
    local icon = ns.NewFrame("Button", nil, slot)
    icon:SetSize(ICON, ICON)
    icon:SetPoint("TOPLEFT", slot, "TOPLEFT", 0, 0)
    local empty = icon:CreateTexture(nil, "BACKGROUND")
    ns.SetTex(empty, "sbEmptySlot")
    empty:SetSize(64, 64)
    empty:SetPoint("TOPLEFT", icon, "TOPLEFT", -3, 3)
    icon.art = icon:CreateTexture(nil, "BORDER")
    icon.art:SetAllPoints(icon)
    local normal = icon:CreateTexture(nil, "ARTWORK")
    ns.SetTex(normal, "slotNormal")
    normal:SetSize(64, 64)
    normal:SetPoint("CENTER", icon, "CENTER", 0, 0)
    ns.DressStates(icon, nil, "slotPushed", nil, "highlight", { add = true })
    icon:RegisterForDrag("LeftButton")
    icon:SetScript("OnClick", Icon_OnClick)
    icon:SetScript("OnReceiveDrag", TakeCursorPet)
    icon:SetScript("OnDragStart", Icon_OnDragStart)
    icon:SetScript("OnEnter", Icon_OnEnter)
    icon:SetScript("OnLeave", GameTooltip_Hide)
    slot.icon = icon
    slot.name = slot:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    slot.name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, -1)
    slot.name:SetPoint("RIGHT", slot, "RIGHT", 0, 0)
    slot.name:SetJustifyH("LEFT")
    slot.name:SetWordWrap(false)
    slot.info = slot:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    slot.info:SetPoint("TOPLEFT", slot.name, "BOTTOMLEFT", 0, -3)
    slot.info:SetPoint("RIGHT", slot, "RIGHT", 0, 0)
    slot.info:SetJustifyH("LEFT")
    -- A locked or empty slot's words, across the row.
    slot.note = slot:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    slot.note:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -6)
    slot.note:SetPoint("RIGHT", slot, "RIGHT", 0, 0)
    slot.note:SetJustifyH("LEFT")
    slot.abilities = {}
    for j = 1, 3 do
        local button = ns.NewFrame("Button", nil, slot)
        button:SetID(j)
        button:SetSize(ABILITY, ABILITY)
        button:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", (j - 1) * ABILITY_STEP, -8)
        button.art = button:CreateTexture(nil, "ARTWORK")
        button.art:SetAllPoints(button)
        ns.DressStates(button, nil, nil, nil, "highlight", { add = true })
        button:SetScript("OnClick", Ability_OnClick)
        button:SetScript("OnEnter", AbilityTip)
        button:SetScript("OnLeave", GameTooltip_Hide)
        slot.abilities[j] = button
    end
    return slot
end

local function EmptySlot(slot, text)
    slot.petID, slot.speciesID, slot.level = nil, nil, nil
    slot.icon.art:SetTexture(nil)
    slot.name:SetText("")
    slot.info:SetText("")
    slot.note:SetText(text or "")
    for _, button in ipairs(slot.abilities) do button:Hide() end
end

local function FillSlot(slot)
    local i = slot:GetID()
    local petID, a1, a2, a3, locked = PJ.GetPetLoadOutInfo(i)
    if locked then return EmptySlot(slot, CW.GameName("BATTLE_PET_UNLOCK_HELP_" .. i) or "") end
    local speciesID, customName, level, name, icon, _
    if petID then speciesID, customName, level, _, _, _, _, name, icon = PJ.GetPetInfoByPetID(petID) end
    if not speciesID then
        local label = CW.GameName("BATTLE_PET_SLOT")
        return EmptySlot(slot, label and label:format(i) or "")
    end
    slot.petID, slot.speciesID, slot.level = petID, speciesID, level
    slot.icon.art:SetTexture(icon)
    slot.name:SetText(customName or name or "")
    local health, maxHealth = PJ.GetPetStats(petID)
    local dead = health == 0
    slot.icon.art:SetDesaturated(dead)
    slot.info:SetText(string.format("%s %d\n%d / %d", CW.Text("LEVEL", "COLL_LEVEL"), level or 0, health or 0, maxHealth or 0))
    if dead then slot.info:SetTextColor(1, 0.3, 0.3) else slot.info:SetTextColor(1, 1, 1) end
    slot.note:SetText("")
    for j, current in ipairs({ a1, a2, a3 }) do
        local button = slot.abilities[j]
        local _, _, abilityIcon = PB.GetAbilityInfoByID(current or 0)
        button.abilityID = current ~= 0 and current or nil
        button.art:SetTexture(abilityIcon)
        button:SetShown(button.abilityID ~= nil)
    end
end

local function Refresh()
    if not (T.panel and T.panel:IsShown()) then return end
    for _, slot in ipairs(T.slots) do FillSlot(slot) end
    T.readOnly:SetShown(not Unlocked())
end

local EVENTS = { "PET_JOURNAL_LIST_UPDATE", "PET_JOURNAL_PET_DELETED", "PET_JOURNAL_PETS_HEALED", "BATTLE_PET_CURSOR_CLEAR",
    "PET_BATTLE_LEVEL_CHANGED", "PET_BATTLE_CLOSE", "COMPANION_UPDATE" }

-- A quarter's copied columns, in the gap.
local function Span(frame, key, y)
    local tex = frame:CreateTexture(nil, "BACKGROUND")
    ns.SetTex(tex, key)
    tex:SetTexCoord((256 - EXTRA) / 256, 1, 0, 1)
    tex:SetSize(EXTRA, 256)
    tex:SetPoint("TOPLEFT", frame, "TOPLEFT", 256, y)
    tex:Hide()
    return tex
end

-- Wider by the team's run of art while it shows; the next window keeps clear of the tabs past it.
local function Widen(frame, open)
    frame:SetWidth(WINDOW_W + (open and EXTRA or 0))
    for _, tex in ipairs(T.spans) do tex:SetShown(open) end
    T.panel:SetShown(open)
    ns.SetSlotWidth(frame, ns.SIDE_TAB_SLOT + (open and EXTRA or 0))
end

local function BuildPanel(frame)
    T.spans = { Span(frame, "sbTopLeft", 0), Span(frame, "sbBotLeft", -256) }
    local panel = ns.NewFrame("Frame", nil, frame)
    panel:SetSize(PANEL_W, PANEL_H)
    panel:SetPoint("TOPLEFT", frame, "TOPLEFT", PANEL_X, PANEL_Y)
    panel:Hide()
    -- In the band under the window's title, where the page's search and filter stand.
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOP", panel, "TOP", 0, -10)
    title:SetText(L["COLL_TEAM"])
    for i = 1, SLOTS do T.slots[i] = BuildSlot(panel, i) end
    T.readOnly = panel:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
    T.readOnly:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 30)
    T.readOnly:SetPoint("RIGHT", panel, "RIGHT", 0, 0)
    T.readOnly:SetText(CW.GameName("PET_JOURNAL_READONLY_TEXT") or "")
    -- Revive Battle Pets is the player's spell: cast through a secure pad over the button.
    local spell = C_Spell.GetSpellName(REVIVE_SPELL) or ""
    local revive = ns.PanelButton(panel, spell, PANEL_W)
    revive:SetPoint("BOTTOM", panel, "BOTTOM", 0, 0)
    ns.MapPad(revive, "HIGH", Refresh, function() return spell ~= "" and ("/cast " .. spell) or nil end,
        function() return panel:IsVisible() end)
    T.watch = ns.EventFrame({}, function() ns.Sched.NextFrame("collections.team", Refresh) end)
    panel:SetScript("OnShow", function()
        ns.RegisterEvents(T.watch, EVENTS)
        Refresh()
    end)
    panel:SetScript("OnHide", function() T.watch:UnregisterAllEvents() end)
    T.panel = panel
end

local function SetOpen(frame, open)
    T.open = open
    Widen(frame, open)
    ns.PanelToggleFace(T.arrow, open)
end

-- The arrow in the box's top right corner, over the creature.
local function Build(frame, box)
    BuildPanel(frame)
    local arrow = ns.NewFrame("Button", nil, box)
    arrow:SetSize(ARROW, ARROW)
    arrow:SetPoint("TOPRIGHT", box, "TOPRIGHT", -ARROW_INSET, -ARROW_INSET)
    arrow:SetFrameLevel(box:GetFrameLevel() + 10)
    arrow:SetHighlightTexture(ns.ART.HILIGHT, "ADD")
    arrow:SetScript("OnClick", function() SetOpen(frame, not T.open) end)
    ns.AttachTip(arrow, { text = function() return L["COLL_TEAM"] end })
    T.arrow = arrow
    SetOpen(frame, false)
end

-- The arrow on the Pets page while the journal can hold a team; the window as wide as the player left it there.
function CW.OnPage(page, frame, box)
    local pets = page.key == "pets" and Unlocked()
    if pets and not T.arrow then Build(frame, box) end
    if not T.arrow then return end
    T.arrow:SetShown(pets)
    Widen(frame, pets and T.open)
end
