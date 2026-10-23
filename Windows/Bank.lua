local _, ns = ...

-- 1.x bank: gravel floor, gold slot titles, rings over dark holes, the old bag on
-- empty bag slots (red while unbought), Era's foot, no shadows or divider, banker in the ring.
-- The client resets its art on every refresh and show, so ours goes back after each.

local IsSecret, AnySecret = ns.IsSecret, ns.AnySecret
local FULL = { 0, 1, 0, 1 }
-- Raw path and full tint: the quickslot file, not the slotNormal key.
local QUICK_RING = { set = "raw", tint = true, coords = FULL, point = "CENTER", y = -1 }
local FLOOR_TILE = { tint = false, coords = FULL }

local Near = ns.Near

local ringFile   -- the ring's file as the client reports it once set

-- Our ring still intact (file, full coords, size, spot)? The client's refresh
-- lays its atlas back over it.
local function RingInPlace(normal, button, size)
    if ringFile == nil then return false end
    local atlas = normal:GetAtlas()
    if IsSecret(atlas) or (atlas ~= nil and atlas ~= "") then return false end
    local file = normal:GetTexture()
    if IsSecret(file) or file ~= ringFile then return false end
    local ulx, uly, llx, lly, urx, ury, lrx, lry = normal:GetTexCoord()
    if AnySecret(ulx, uly, llx, lly, urx, ury, lrx, lry) then return false end
    if not (ulx == 0 and uly == 0 and llx == 0 and lly == 1 and urx == 1 and ury == 0 and lrx == 1 and lry == 1) then return false end
    local w, h = normal:GetSize()
    if AnySecret(w, h) or type(w) ~= "number" or type(h) ~= "number" or not Near(w, size) or not Near(h, size) then return false end
    return ns.IsAt(normal, "CENTER", button, "CENTER", 0, -1) == true
end

-- Old ring over a near-black hole, as the 1.x sheet cut each slot.
local function SlotArt(button)
    ns.QuestItemLook(button)
    local normal = button:GetNormalTexture()
    if normal then
        local w = button:GetWidth()
        if not w or w < 1 then w = 37 end
        local size = w * 64 / 37
        if RingInPlace(normal, button, size) then
            ns.BronzeTint(normal)
        else
            ns.Dress(normal, ns.ART.QUICKSLOT, QUICK_RING, button, nil, nil, size, size)
            if ringFile == nil then
                local file = normal:GetTexture()
                if file ~= nil and not IsSecret(file) then ringFile = file end
            end
        end
    end
    local bg = button.Background
    if bg then
        bg:SetColorTexture(0.06, 0.06, 0.06, 1)
        bg:ClearAllPoints()
        bg:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
        bg:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
        bg:SetAlpha(1)
    end
end

local function SkinSlot(button)
    if not button then return end
    if not button.fcuiBankSlot then
        button.fcuiBankSlot = true
        -- After the client's refresh, which puts its atlases back.
        if type(button.Refresh) == "function" then
            hooksecurefunc(button, "Refresh", SlotArt)
        end
        if type(button.UpdateBackgroundForBankType) == "function" then
            hooksecurefunc(button, "UpdateBackgroundForBankType", SlotArt)
        end
    end
    SlotArt(button)
end

local function SkinSlots(panel)
    if not panel or not panel.itemButtonPool then return end
    for button in panel.itemButtonPool:EnumerateActive() do SkinSlot(button) end
end

-- Bag slot: old ring, no lock, old bag icon when empty, red while unbought.
local function BagArt(button)
    SlotArt(button)
    if button.DisabledOverlay then button.DisabledOverlay:Hide() end
    local icon = button.icon
    if not icon then return end
    local unbought = button.tooltipText == BANK_BAG_PURCHASE
    if unbought or not icon:GetTexture() then
        icon:SetTexture(ns.TexPath("bagSlotIcon"))
        icon:SetTexCoord(0, 1, 0, 1)
        icon:Show()
        if unbought then icon:SetVertexColor(1, 0.1, 0.1) else icon:SetVertexColor(1, 1, 1) end
    else
        icon:SetVertexColor(1, 1, 1)
    end
end

local function SkinBagSlot(button)
    if not button then return end
    if not button.fcuiBankBag then
        button.fcuiBankBag = true
        if type(button.SetItemButtonTexture) == "function" then
            hooksecurefunc(button, "SetItemButtonTexture", BagArt)
        end
    end
    BagArt(button)
end

local function SkinBagSlots(frame)
    if not frame.itemButtonBagPool then return end
    for button in frame.itemButtonBagPool:EnumerateActive() do SkinBagSlot(button) end
end

-- Banker portrait fallback: when the client skips it, the ring shows a hole.
local function FillPortrait(frame)
    local portrait = frame.PortraitContainer and frame.PortraitContainer.portrait
    if not portrait or portrait:GetTexture() then return end
    if UnitExists("npc") then
        SetPortraitTexture(portrait, "npc")
    else
        SetPortraitTexture(portrait, "player")
    end
end

-- Era's bank under Forever's taller grid (eram bankframe): the bag row, the purchase line and the money strip spaced as
-- Era's, from the window's foot. The grid keeps Forever's 8 columns; the window grows FOOT_ROOM to hold Era's spacing.
local FOOT_ROOM = 49
local BAG_X, BAG_STEP, BAG_TOP, BAG_LABEL_TOP = 47, 50, 142, 160
local GRID_MIDDLE = 240
local BUY_Y, COST_X, BUY_RIGHT, BUY_TEXT_X, BUY_TEXT_Y, BUY_TEXT_W = 45, 116, 366, 246, 75, 280
-- The money on the strip's floor, its copper 3 short of the gold rim (468): the client's display ends 13 past it.
local MONEY_X, MONEY_Y, MONEY_END = 303, 17.5, 468
-- The foot of Forever's own bank sheet (the same art as Era's): metal bar and gold-rimmed strip, rows 391-411, ends
-- kept and the middle stretched between the metal's inner edges; its foot 5 over the metal (seen in game).
local BANK_SHEET = "Interface\\BankFrame\\UI-BankFrame"
local FOOT_V0, FOOT_V1, FOOT_H, FOOT_IN, FOOT_Y = 391 / 512, 412 / 512, 21, 4, 9
local FOOT_LEFT = { set = "raw", tint = true, point = "BOTTOMLEFT", x = FOOT_IN, y = FOOT_Y, w = 24, h = FOOT_H,
    coords = { 20 / 512, 44 / 512, FOOT_V0, FOOT_V1 }, show = true }
local FOOT_RIGHT = { set = "raw", tint = true, point = "BOTTOMRIGHT", x = -FOOT_IN, y = FOOT_Y, w = 30, h = FOOT_H,
    coords = { 360 / 512, 390 / 512, FOOT_V0, FOOT_V1 }, show = true }
local FOOT_MIDDLE = { set = "raw", tint = true, coords = { 44 / 512, 360 / 512, FOOT_V0, FOOT_V1 }, show = true }

local sized = setmetatable({}, { __mode = "k" })
local purchaseText = setmetatable({}, { __mode = "k" })

-- After each client layout (it sizes the window to its rows): the room for Era's foot, once per layout.
local function Heighten(frame)
    local panel = frame and frame.BankPanel
    local h = panel and panel:GetHeight()
    if not h or IsSecret(h) or Near(h, sized[frame] or -1) then return end
    sized[frame] = h + FOOT_ROOM
    panel:SetHeight(h + FOOT_ROOM)
    frame:SetHeight(h + FOOT_ROOM)
end

local function LayFoot(frame)
    local left = ns.Dress(ns.OwnTexture(frame, "bankFootLeft", "BACKGROUND", 3), BANK_SHEET, FOOT_LEFT, frame)
    local right = ns.Dress(ns.OwnTexture(frame, "bankFootRight", "BACKGROUND", 3), BANK_SHEET, FOOT_RIGHT, frame)
    local middle = ns.Dress(ns.OwnTexture(frame, "bankFootMiddle", "BACKGROUND", 3), BANK_SHEET, FOOT_MIDDLE)
    middle:ClearAllPoints()
    middle:SetPoint("BOTTOMLEFT", left, "BOTTOMRIGHT", 0, 0)
    middle:SetPoint("TOPRIGHT", right, "TOPLEFT", 0, 0)
end

-- Era's bag row, its label over it, the purchase line and the money on the strip.
local function PlaceFoot(frame)
    LayFoot(frame)
    if frame.BagText then frame.BagText:SetAlpha(0) end
    local label = ns.OwnFontString(frame, "bagSlotsTitle", "ARTWORK")
    label:SetFontObject(ns.FONT_GOLD)
    label:SetText(BAGSLOTTEXT or "Bag Slots")
    ns.SetPointOnce(label, "TOP", frame, "BOTTOMLEFT", GRID_MIDDLE, BAG_LABEL_TOP)
    label:Show()
    local cost = frame.BagCost
    if cost then ns.SetPointOnce(cost, "LEFT", frame, "BOTTOMLEFT", COST_X, BUY_Y) end
    local panel = frame.BankPanel
    if not panel then return end
    if panel.MoneyDisplay and cost then ns.SetPointOnce(panel.MoneyDisplay, "LEFT", cost, "RIGHT", 10, 0) end
    local buy = panel.PurchaseButton
    if buy then
        ns.SetPointOnce(buy, "RIGHT", frame, "BOTTOMLEFT", BUY_RIGHT, BUY_Y)
        -- Era's question over the line: on the button, so it shows only while a slot is for sale.
        local text = purchaseText[frame]
        if not text and BANKSLOTPURCHASE_LABEL then
            text = buy:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            text:SetWidth(BUY_TEXT_W)
            text:SetJustifyH("LEFT")
            text:SetText(BANKSLOTPURCHASE_LABEL)
            text:SetPoint("CENTER", frame, "BOTTOMLEFT", BUY_TEXT_X, BUY_TEXT_Y)
            purchaseText[frame] = text
        end
    end
    local money = panel.MoneyFrame
    if money then
        if money.Border then money.Border:SetAlpha(0) end
        -- With the transfer buttons right of it, the whole frame ends on the strip's floor instead.
        local transfer = money.WithdrawButton and money.WithdrawButton:IsShown()
        local x = transfer and (MONEY_END - (money:GetWidth() or 0)) or MONEY_X
        ns.SetPointOnce(money, "LEFT", frame, "BOTTOMLEFT", x, MONEY_Y)
    end
end

local function PlaceBagSlots(frame)
    if not frame.itemButtonBagPool then return end
    for button in frame.itemButtonBagPool:EnumerateActive() do
        -- Full size under the item columns, from the first, as Era's.
        local i = (tonumber(button.bagSlotID) or 2) - 1
        button:SetScale(1)
        ns.SetPointOnce(button, "TOPLEFT", frame, "BOTTOMLEFT", BAG_X + (i - 1) * BAG_STEP, BAG_TOP)
    end
end

-- Everything the client may put back; on skin and every show.
local function DressWindow(frame)
    local panel = frame.BankPanel
    if frame.Background then frame.Background:SetAlpha(0) end
    ns.FadeAtlas(frame, "bank-divider", true)
    if frame.fcui and frame.fcui.insetFloor then frame.fcui.insetFloor:Hide() end
    if panel then
        ns.FadeTextures(panel.NineSlice)
        if panel.EdgeShadows then panel.EdgeShadows:Hide() end
        -- Gravel over the whole inside of the metal, above the client's stone (1.x), down to the border's solid line as
        -- the backing: below it the corner's bevel is open.
        local floor = ns.TileTex(ns.OwnTexture(frame, "bankFloor", "BACKGROUND", 1), "bankFloor", FLOOR_TILE)
        floor:ClearAllPoints()
        floor:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -20)
        floor:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 7)
        floor:Show()
        if panel.PurchaseButton then ns.SkinRedButton(panel.PurchaseButton) end
        local money = panel.MoneyFrame
        if money then
            if money.WithdrawButton then ns.SkinRedButton(money.WithdrawButton) end
            if money.DepositButton then ns.SkinRedButton(money.DepositButton) end
        end
        -- "Item Slots" over the grid, as in 1.x.
        local title = frame.fcui and frame.fcui.itemSlotsTitle
        if not title then
            title = frame:CreateFontString(nil, "ARTWORK")
            title:SetFontObject(ns.FONT_GOLD)
            title:SetText(ITEMSLOTTEXT or "Item Slots")
            frame.fcui.itemSlotsTitle = title
        end
        ns.SetPointOnce(title, "TOP", panel, "TOP", 0, -46)
        title:Show()
        SkinSlots(panel)
    end
    if frame.BagCost then frame.BagCost:SetFontObject(ns.FONT_GOLD) end
    SkinBagSlots(frame)
    -- Era's foot is for Forever's bank (its bag row and cost line); retail's tabbed bank keeps the game's layout.
    if ns.OnForever() then
        Heighten(frame)
        PlaceFoot(frame)
        PlaceBagSlots(frame)
    end
    FillPortrait(frame)
end

local function AfterLayout(panel)
    SkinSlots(panel)
    if ns.OnForever() then Heighten(panel:GetParent()) end
end

local function AfterBagButtons(frame)
    SkinBagSlots(frame)
    PlaceBagSlots(frame)
end

function ns.SkinBank(frame)
    frame.fcui = frame.fcui or {}
    DressWindow(frame)
    if frame.fcuiBank then return end
    frame.fcuiBank = true
    local panel = frame.BankPanel
    if panel then
        ns.HookMethod(panel, "GenerateItemSlotsForSelectedTab", AfterLayout)
        ns.HookMethod(panel, "RefreshBankPanel", SkinSlots)
    end
    ns.HookMethod(frame, "RefreshBagButtons", AfterBagButtons)
    frame:HookScript("OnShow", DressWindow)
end
