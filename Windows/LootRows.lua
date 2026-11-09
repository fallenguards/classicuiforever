local _, ns = ...

-- The classic loot list: our four rows, Era's LootButton1-4, on the game's loot window, filled from the loot slots and
-- looting through LootSlot. The game's own list stands parked off the window (Windows/Loot.lua): a row height, anchor
-- or scroll spot written there ran its list as ours for the session, and a fight then refused the window's open (#275).

local ROWS = 4
local ROW_X, ROW_Y, ROW_STEP, ICON = 26, -75, 41, 37   -- the first icon's spot in the window and Era's pitch
local TEXT_W, TEXT_H, TEXT_GAP = 93, 38, 8
local NAME_BOX = { own = "nameBox", layer = "BACKGROUND", sublevel = 1, coords = { 0, 1, 0, 1 }, w = 130, h = 62,
    point = "LEFT", x = 30, show = true }
local LOCKED_TINT, PLAIN_TINT = { 0.9, 0, 0 }, { 1, 1, 1 }

-- Whole pages as in 1.x: four rows, three once the arrows are needed; page counts from 0. cleared: a slot was just
-- looted, and a page with nothing left on it turns to the next, as Era's. hasItem(slot): the slot still holds something.
function ns.LootPageOf(total, page, cleared, hasItem)
    local paged = total > ROWS
    local rows = paged and ROWS - 1 or ROWS
    local last = paged and math.ceil(total / rows) - 1 or 0
    page = math.max(0, math.min(page, last))
    if cleared and page < last then
        local left = false
        for i = 1, rows do
            local slot = page * rows + i
            if slot <= total and hasItem(slot) then
                left = true
                break
            end
        end
        if not left then page = page + 1 end
    end
    return page, rows, last, paged
end

-- A looted slot answers no icon.
function ns.LootSlotFilled(slot) return (GetLootSlotInfo(slot)) ~= nil end

local function Click(row)
    local slot = row.slot
    if not slot then return end
    if IsModifiedClick() then
        HandleModifiedItemClick(GetLootSlotLink(slot))
    else
        LootSlot(slot)
    end
end

-- Era's tooltip: beside the icon, over the window. Coins have none.
local function Enter(row)
    local slot = row.slot
    if not slot then return end
    local kind = GetLootSlotType(slot)
    if kind == Enum.LootSlotType.Item then
        GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
        GameTooltip:SetLootItem(slot)
    elseif kind == Enum.LootSlotType.Currency then
        GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
        GameTooltip:SetLootCurrency(slot)
    end
    CursorUpdate(row)
end

local function Leave(row)
    if GameTooltip:IsOwned(row) then GameTooltip:Hide() end
    ResetCursor()
end

local function NewRow(frame, i, onWheel)
    local row = ns.NewFrame("ItemButton", "ForeverClassicUILootRow" .. i, frame)
    row:SetSize(ICON, ICON)
    row:SetPoint("TOPLEFT", frame, "TOPLEFT", ROW_X, ROW_Y - (i - 1) * ROW_STEP)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    ns.DressNew(row, "lootNameFrame", NAME_BOX)
    local text = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    text:SetSize(TEXT_W, TEXT_H)
    text:SetPoint("LEFT", row, "RIGHT", TEXT_GAP, 0)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("MIDDLE")
    row.text = text
    local quest = row:CreateTexture(nil, "OVERLAY")
    quest:SetAllPoints(row)
    quest:Hide()
    row.quest = quest
    row:SetScript("OnClick", Click)
    row:SetScript("OnEnter", Enter)
    row:SetScript("OnLeave", Leave)
    if onWheel then
        row:EnableMouseWheel(true)
        row:SetScript("OnMouseWheel", onWheel)
    end
    row:Hide()
    return row
end

-- The slot's icon, count, quality, lock tint and quest mark, as the game's row shows them; false for a looted slot.
local function Fill(row, slot)
    local texture, item, quantity, currencyID, quality, locked, isQuestItem, questID, isActive = GetLootSlotInfo(slot)
    if texture == nil then return false end
    if currencyID then
        item, texture, quantity, quality = CurrencyContainerUtil.GetCurrencyContainerInfo(currencyID, quantity, item, texture, quality)
    end
    row.slot = slot
    SetItemButtonTexture(row, texture)
    SetItemButtonCount(row, quantity)
    quality = quality or Enum.ItemQuality.Common
    SetItemButtonQuality(row, quality, GetLootSlotLink(slot))
    local color = ColorManager.GetColorDataForItemQuality(quality)
    if color then row.text:SetVertexColor(color.color:GetRGB()) end
    row.text:SetText(item)
    local tint = locked and LOCKED_TINT or PLAIN_TINT
    SetItemButtonTextureVertexColor(row, tint[1], tint[2], tint[3])
    SetItemButtonNormalTextureVertexColor(row, tint[1], tint[2], tint[3])
    if questID and not isActive then
        row.quest:SetTexture(TEXTURE_ITEM_QUEST_BANG)
        row.quest:Show()
    elseif questID or isQuestItem then
        row.quest:SetTexture(TEXTURE_ITEM_QUEST_BORDER)
        row.quest:Show()
    else
        row.quest:Hide()
    end
    row:Show()
    -- The tooltip under the mouse follows the slot's new state.
    if GameTooltip:IsOwned(row) then Enter(row) end
    return true
end

local rows = {}

-- The page's slots on our rows (made on the first call, onWheel their wheel handler); rows past the page hide.
function ns.FillLootRows(frame, page, perPage, onWheel)
    if not rows[1] then
        for i = 1, ROWS do rows[i] = NewRow(frame, i, onWheel) end
    end
    local total = GetNumLootItems()
    for i = 1, ROWS do
        local row, slot = rows[i], page * perPage + i
        if not (i <= perPage and slot <= total and Fill(row, slot)) then
            row.slot = nil
            row:Hide()
        end
    end
end
