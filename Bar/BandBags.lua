local _, ns = ...
local L = ns.L
local B = ns.band

-- Bag row: on the band's bag part, off it on the client's bags piece, or in one-bar mode's corner;
-- plus our panel under edit mode's Bags dialog.

local BAND_H, CORNER_X = B.BAND_H, B.CORNER_X
local BAG_BUTTONS, PIECES = B.BAG_BUTTONS, B.PIECES
-- Buttons sit centred on the sheet's sockets (B.Bag: size, gap, backpack corner).
local KEYRING_W, KEYRING_H, KEYRING_GAP = 18, 39, -5
B.KEYRING_W, B.KEYRING_H = KEYRING_W, KEYRING_H
-- Round reagent bag (reagentBagSlot off): a small button at the top corner between key ring and last bag. On, it takes a
-- full slot left of the last bag (the band's extra socket) and the key ring moves out past it.
local REAGENT_SIZE = 17
local BandNow, Seat, OneBar, MicroOut = B.BandNow, B.Seat, B.OneBar, B.MicroOut
local MicroUserScale, CurrentPlan, ButtonLevel = B.MicroUserScale, B.CurrentPlan, B.ButtonLevel
local Dress, FadeTextures = ns.Dress, ns.FadeTextures

-- The bag part from its post as a floor (with the reagent slot: head, the extra socket, the rest).
local FLOOR_TEX = { tint = ns.BRONZE_SOFT }

-- The client's bag bar draws art behind the slots that shows round the key ring; fade it except on the bag buttons.
local function KeepsBag(child) return child.GetBagID or child.GetID end
local BAGS_BAR_ART = { children = true, skipChild = KeepsBag }

-- Lay a client edit mode piece over a band rectangle given in band pixels; the piece's own scale reads the offsets.
function ns.OverlayOnBand(frame, point, bandPoint, x, y, w, h, relativeTo)
    local art = B.art
    if not frame or not art then return end
    local fs = frame:GetEffectiveScale() / art:GetEffectiveScale()
    if not fs or fs <= 0 then fs = 1 end
    ns.SetPointOnce(frame, point, relativeTo or art, bandPoint, x / fs, y / fs)
    frame:SetSize(w / fs, h / fs)
end

-- Off the band the row carries a floor of band art from the bags' post (the key ring stays in the section); with the
-- reagent slot: head, extra socket, rest. turn, as edit mode turns the row: "cw" a column up (backpack at its foot),
-- "ccw" down, "mirror" a row growing right, nil as drawn. x runs along the strip from its far end.
local function FloorRun(floor, tex, x, width, u0, u1, turn)
    local sheet = PIECES[B.Bag().sheet]
    Dress(tex, sheet.key, FLOOR_TEX)
    local l, r, t, b = u0 / 256, u1 / 256, sheet.band[1], sheet.band[2]
    if turn == "cw" then
        ns.SetPointOnce(tex, "TOPLEFT", floor, "TOPLEFT", 0, -x)
        tex:SetSize(BAND_H, width)
        tex:SetTexCoord(l, b, r, b, l, t, r, t)
    elseif turn == "ccw" then
        ns.SetPointOnce(tex, "BOTTOMLEFT", floor, "BOTTOMLEFT", 0, x)
        tex:SetSize(BAND_H, width)
        tex:SetTexCoord(r, t, l, t, r, b, l, b)
    elseif turn == "mirror" then
        ns.SetPointOnce(tex, "TOPRIGHT", floor, "TOPRIGHT", -x, 0)
        tex:SetSize(width, BAND_H)
        tex:SetTexCoord(r, l, t, b)
    else
        ns.SetPointOnce(tex, "TOPLEFT", floor, "TOPLEFT", x, 0)
        tex:SetSize(width, BAND_H)
        tex:SetTexCoord(l, r, t, b)
    end
    tex:Show()
end

local function LayFloor(art, square, floating, buttonScale, level, backpack, turn)
    local floor = art.bagFloor
    if not floating then
        if floor then floor:Hide() end
        return
    end
    if not floor then
        floor = CreateFrame("Frame", nil, art)
        floor.tex = floor:CreateTexture(nil, "BACKGROUND")
        floor.socket = floor:CreateTexture(nil, "BACKGROUND")
        floor.rest = floor:CreateTexture(nil, "BACKGROUND")
        art.bagFloor = floor
    end
    local bag = B.Bag()
    local long = B.BagPart() - bag.trim
    if turn == "cw" or turn == "ccw" then floor:SetSize(BAND_H, long) else floor:SetSize(long, BAND_H) end
    local u0, s0, s1 = 256 - bag.part + bag.trim, bag.socketU0, bag.socketU1
    if square then
        local head, unit = s0 - u0, s1 - s0
        FloorRun(floor, floor.tex, 0, head, u0, s0, turn)
        FloorRun(floor, floor.socket, head, unit, s0, s1, turn)
        FloorRun(floor, floor.rest, head + unit, 256 - s0, s0, 256, turn)
    else
        FloorRun(floor, floor.tex, 0, 256 - u0, u0, 256, turn)
        floor.socket:Hide()
        floor.rest:Hide()
    end
    floor:SetScale(buttonScale)
    floor:SetFrameLevel(math.max(0, level - 1))
    -- The backpack keeps its spot on the strip: its corner by the strip's backpack end, turned with it.
    if turn == "cw" then
        ns.SetPointOnce(floor, "BOTTOMLEFT", backpack, "BOTTOMLEFT", -bag.y, bag.x)
    elseif turn == "ccw" then
        ns.SetPointOnce(floor, "TOPRIGHT", backpack, "TOPRIGHT", bag.y, -bag.x)
    elseif turn == "mirror" then
        ns.SetPointOnce(floor, "BOTTOMLEFT", backpack, "BOTTOMLEFT", bag.x, -bag.y)
    else
        ns.SetPointOnce(floor, "BOTTOMRIGHT", backpack, "BOTTOMRIGHT", -bag.x, -bag.y)
    end
    floor:Show()
end

-- The frame's own alpha: the item button's SetAlpha fans out to its icon and ring (and left them at 0 for good, the
-- compare reading the frame); seen, those regions are lit again through it.
local function ReagentSeen(reagent, seen)
    if seen then reagent:SetAlpha(1) end
    ns.SetFrameAlphaIf(reagent, seen and 1 or 0)
    if reagent:IsMouseEnabled() ~= seen then reagent:EnableMouse(seen) end
end

-- Reagent bag on hover: the round button shows while the mouse is over the row (its own spot included, so its
-- click still works unseen). Enter and leave hooks on the row's buttons, set once; leave is judged a frame later.
local hoverHooked = false
local function RowButtons()
    local list = {}
    for _, name in ipairs(BAG_BUTTONS) do list[#list + 1] = _G[name] end
    list[#list + 1] = KeyRingButton
    list[#list + 1] = CharacterReagentBag0Slot
    return list
end
local function HoverWanted()
    return ns.db and ns.db.reagentBagHover == true and not B.ReagentSlot()
end
local function HoverCheck()
    local reagent = CharacterReagentBag0Slot
    if not reagent or not HoverWanted() then return end
    local over = false
    for _, button in ipairs(RowButtons()) do
        if button and button:IsVisible() and button:IsMouseOver() then over = true break end
    end
    if over then reagent:SetAlpha(1) end
    ns.SetFrameAlphaIf(reagent, over and 1 or 0)
end
local function HookHover()
    if hoverHooked then return end
    hoverHooked = true
    for _, button in ipairs(RowButtons()) do
        if button then
            ns.HookScriptOnce(button, "OnEnter", HoverCheck)
            ns.HookScriptOnce(button, "OnLeave", function() ns.Sched.NextFrame("bags.hover", HoverCheck) end)
        end
    end
end

-- Edit mode's Orientation and Direction for the bags, as the client's bags bar lays them (BagsBar.lua): the backpack at
-- the end the row grows away from, each bag chained on the one before. { point, relativePoint, x, y } per step.
local GROW = {
    left = { "RIGHT", "LEFT", -1, 0 }, right = { "LEFT", "RIGHT", 1, 0, turn = "mirror" },
    up = { "BOTTOM", "TOP", 0, 1, turn = "cw" }, down = { "TOP", "BOTTOM", 0, -1, turn = "ccw" },
}
local function Grow()
    local bar, dirs = BagsBar, Enum and Enum.BagsDirection
    if not (bar and dirs) then return GROW.left end
    if bar.isHorizontal ~= false then return bar.direction == dirs.Right and GROW.right or GROW.left end
    return bar.direction == dirs.Down and GROW.down or GROW.up
end

-- Turned (any way but the classic row growing left), the row cannot sit in the band's sockets: it stands as a moved row
-- does, its floor turned with it (ClassicBar ReadShape).
function B.BagsTurned() return Grow() ~= GROW.left end

-- A column of bags (edit mode's Vertical): its floor's turn, else nil.
function B.BagsColumn()
    local turn = Grow().turn
    return (turn == "cw" or turn == "ccw") and turn or nil
end

-- A column's far end, for the key ring lying flat to ride on (BandSection): the frame, the key ring home's point, the
-- frame's point and the row's scale; nil when there is no column.
function B.BagsFarEnd()
    local turn, art = B.BagsColumn(), B.art
    if not turn or not art then return nil end
    local up = turn == "cw"
    local floor, last = art.bagFloor, art.bagsLast
    if floor and floor:IsShown() then
        return floor, up and "BOTTOMLEFT" or "TOPLEFT", up and "TOPLEFT" or "BOTTOMLEFT", floor:GetScale()
    end
    if last and last:IsShown() then
        return last, up and "BOTTOM" or "TOP", up and "TOP" or "BOTTOM", last:GetScale()
    end
end

-- One more piece on the row, a step on from prev; step is the overlap between sockets (negative: a gap).
local function Chain(button, prev, grow, step)
    button:SetPoint(grow[1], prev, grow[2], -grow[3] * step, -grow[4] * step)
end

function B.LayoutBags()
    local backpack = MainMenuBarBackpackButton
    if not backpack then return end
    local grow = Grow()
    local vertical = grow[4] ~= 0
    local art, shape = B.art, B.shape
    local piece = BagsBar
    local out = piece and not shape.bags
    local bag = B.Bag()
    local size, gap = bag.size, bag.gap
    local lift = (KEYRING_H - size) / 2
    local home, homePoint, homeY = art, "BOTTOMRIGHT", bag.y
    local homeX
    local buttonScale = 1
    local square = B.ReagentSlot()
    local rowW = size + 4 * (size - gap)
    if square then rowW = rowW + size - gap end
    -- The key slot's tenant: never the key ring (its own piece, BandSection.lua).
    local slim = B.SlimReagent() and CharacterReagentBag0Slot or nil
    if slim then rowW = rowW + KEYRING_W - KEYRING_GAP end
    -- The piece's box: a column swaps its sides, as the client's does.
    local boxW, boxH = rowW, KEYRING_H
    if vertical then boxW, boxH = KEYRING_H, rowW end
    -- On the band: socket size. Off it (moved, or one-bar corner): edit mode's Size with the band scale divided out.
    local band = BandNow()
    if piece and (out or OneBar()) then
        buttonScale = (piece:GetScale() or 1) / band
    elseif piece then
        -- The player's Size counts on the band too; snapping back resets it. The size worn when last snapped
        -- counts as socket size (no layout write); a Size picked later is theirs.
        buttonScale = piece:GetScale() or 1
        local snap = ns.db and ns.db.bagsSnapScale or 0
        if snap > 0 and ns.Near(buttonScale, snap, 0.001) then buttonScale = 1 end
    end
    if out then
        home, homeX, homeY = piece, 0, lift
    else
        local relativeTo
        if OneBar() then
            -- Over the micro group while it stands in the corner, else on the floor.
            local under = MicroOut() and 0 or BAND_H * MicroUserScale() / band
            relativeTo, homeX, homeY = art.sideAnchor, CORNER_X - 4 * buttonScale, under + 6 * buttonScale
        else
            -- By the plan: the bags are not always last on the band.
            homePoint, homeX = "BOTTOMLEFT", (CurrentPlan().bagsEnd or CurrentPlan().width) + bag.x
        end
        -- The row hangs from the client's bags piece, laid over it first, so edit mode's box sits on the bags
        -- and a drag carries them. A piece mid-drag stays in the player's hand.
        if piece then
            if not piece.isDragging then
                -- Its own anchor kept: the hand-back puts it back without running edit mode's anchor pass.
                B.Remember(piece, true)
                ns.OverlayOnBand(piece, "BOTTOMRIGHT", homePoint, homeX, homeY - lift * buttonScale, boxW * buttonScale, boxH * buttonScale, relativeTo)
            end
            home, homePoint, homeX, homeY = piece, "BOTTOMRIGHT", 0, lift
        elseif relativeTo then
            home = relativeTo
        end
    end
    local level = ButtonLevel()
    local prev
    -- Backpack at the piece's end the row grows from (the classic row: its right end), four bags a socket apart, then
    -- the key ring hole.
    for _, name in ipairs(BAG_BUTTONS) do
        local button = _G[name]
        if button then
            Seat(button, buttonScale, size, size, level)
            if prev then
                Chain(button, prev, grow, gap)
            elseif home == piece then
                button:SetPoint(grow[1], piece, grow[1], 0, 0)
            else
                button:SetPoint("BOTTOMRIGHT", home, homePoint, homeX / buttonScale, homeY / buttonScale)
            end
            ns.SkinBagButton(button, size, name == "MainMenuBarBackpackButton")
            button:Show()
            prev = button
        end
    end
    local lastBag = prev
    if square then
        local reagent = CharacterReagentBag0Slot
        Seat(reagent, buttonScale, size, size, level)
        Chain(reagent, prev, grow, gap)
        ns.SkinBagButton(reagent, size, false, false)
        reagent:Show()
        ReagentSeen(reagent, true)
        prev = reagent
    end
    if slim then
        Seat(slim, buttonScale, KEYRING_W, KEYRING_H, level)
        Chain(slim, prev, grow, KEYRING_GAP)
        ns.SkinKeyRing(slim)
    end
    if not square and KeyRingButton and CharacterReagentBag0Slot then
        -- Both (Forever): the reagent bag is the small round one, centred level with the bags between key ring and last bag.
        local reagent = CharacterReagentBag0Slot
        Seat(reagent, buttonScale, REAGENT_SIZE, REAGENT_SIZE, level + 2)
        reagent:SetPoint("CENTER", lastBag, grow[2], 2 * grow[3], 2 * grow[4])
        ns.SkinBagButton(reagent, REAGENT_SIZE, false, true)
        if HoverWanted() then
            ReagentSeen(reagent, true)
            HookHover()
            HoverCheck()
        else
            ReagentSeen(reagent, true)
        end
    end
    art.bagsLast = prev
    -- Once moved, the piece is only sized to its row.
    if piece and out then piece:SetSize(boxW, boxH) end
    -- The floor: a strip of the band from the backpack, turned with the row.
    LayFloor(art, square, (out or OneBar()) and not ns.db.hideBagsArt, buttonScale, level, backpack, grow.turn)
    B.LaySection(level)
    if BagBarExpandToggle then BagBarExpandToggle:Hide() end
    if BagsBar then FadeTextures(BagsBar, 0, BAGS_BAR_ART) end
    B.BagDividers(0)
    B.MainBarDividers(0)
end

-- The client's dividers between a bar's buttons (pooled frames on it): faded, 1 gives them back.
local DIVIDER_POOLS = { "HorizontalDividersPool", "VerticalDividersPool" }
local function Dividers(bar, alpha)
    for _, key in ipairs(DIVIDER_POOLS) do
        local pool = bar and bar[key]
        if pool and pool.EnumerateActive then
            for divider in pool:EnumerateActive() do ns.SetAlphaIf(divider, alpha) end
        end
    end
end

-- Beside our bag row.
function B.BagDividers(alpha) Dividers(BagsBar, alpha) end

-- Between the main bar's buttons: a spell drag shows every slot and the client lays them there, lifted over our art
-- (Era has none). Faded every frame of a drag, the new ones included, and at each layout.
function B.MainBarDividers(alpha) Dividers(MainActionBar, alpha) end

local dragDividers = ns.Sched.Job({ name = "bar.dragDividers", every = 0, awake = false, fn = function()
    if B.active then B.MainBarDividers(0) end
end })
local function DragDividersDone()
    if B.active then B.MainBarDividers(0) end
    dragDividers:Sleep()
end
-- The client lays them again whenever bar 1's buttons change their action (a page swap for Stealth or a form, a slot
-- filled or emptied, an override bar), new ones at full alpha (#143). Its handlers run first on the same event: faded
-- at once, before the frame is drawn, then on the next two frames for a swap that lands later.
local function FadeAgain()
    if B.active then B.MainBarDividers(0) end
end
local function FadeAgainAfter()
    FadeAgain()
    ns.Sched.NextFrame("bar.dividersAfter", FadeAgain)
end
ns.EventFrame({ "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR", "ACTIONBAR_SLOT_CHANGED", "UPDATE_SHAPESHIFT_FORM",
    "UPDATE_OVERRIDE_ACTIONBAR", "PLAYER_ENTERING_WORLD" }, function()
    if not B.active then return end
    B.MainBarDividers(0)
    ns.Sched.NextFrame("bar.dividersNext", FadeAgainAfter)
end)

ns.EventFrame({ "ACTIONBAR_SHOWGRID", "ACTIONBAR_HIDEGRID" }, function(_, event)
    if not B.active then return end
    B.MainBarDividers(0)
    if event == "ACTIONBAR_SHOWGRID" then
        dragDividers:Wake()
    else
        -- The client lays them once more as the grid goes.
        ns.Sched.NextFrame("bar.dragDividers", DragDividersDone)
    end
end)

local function BagsCheck(extra, rel, relPoint, x, y, label, onClick)
    local check = CreateFrame("CheckButton", nil, extra, "UICheckButtonTemplate")
    check:SetSize(30, 30)
    check:SetPoint("TOPLEFT", rel, relPoint, x, y)
    check:SetScript("OnClick", onClick)
    ns.EditModeCheck(check)
    local text = check:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
    text:SetPoint("LEFT", check, "RIGHT", 6, 0)
    text:SetText(label)
    return check
end

local function FollowClick(self)
    ns.db.bagWindowsFollow = self:GetChecked() and true or false
end

-- The addon's own "opened bags above the bag buttons" and "one bag" toggles.
local function AboveClick(self)
    ns.db.bagsAboveRow = self:GetChecked() and true or false
    ns.ToggleChanged("bagsAboveRow")
end

local function WholeNumber(value) return tostring(math.floor(value + 0.5)) end

-- The one bag columns slider: its range, its write, and when it is live.
local function ColumnValues()
    local low, high = ns.ONE_BAG_COLUMNS_MIN or 4, ns.ONE_BAG_COLUMNS_MAX or 16
    return tonumber(ns.db.oneBagColumns) or low, low, high, high - low
end

local function OnColumns(value)
    if ns.SetOneBagColumns then ns.SetOneBagColumns(value) end
end

local function OneBagOn() return ns.db.oneBag == true end

-- Reset To Default Size (the client's dialog lacks it), beside Revert Changes: written as the interface reloads.
local function ResetBagsSize() ns.AskSizeReset("bagsSize", "bags") end

-- Our bag settings panel, hung under edit mode's Bags dialog while it is up: beside it, not in it
-- (the dialog would count a child into its size).
local function BagsExtra()
    local art = B.art
    local extra = art.bagsExtra
    if extra then return extra end
    extra = CreateFrame("Frame", "ForeverClassicUIBagsExtra", UIParent)
    extra:SetFrameStrata("DIALOG")
    extra:SetFrameLevel(200)
    extra:SetHeight(216)
    extra:Hide()
    art.bagsExtra = extra
    B.PanelBorder(extra)
    local check = BagsCheck(extra, extra, "TOPLEFT", 22, -14, L["BAR_OPENED_BAGS_TAKE_THIS_SIZE"], FollowClick)
    extra.check = check
    local above = BagsCheck(extra, check, "BOTTOMLEFT", 0, -2, L["BAR_OPENED_BAGS_ABOVE_THE_BAG"], AboveClick)
    extra.above = above
    local hideArt = BagsCheck(extra, above, "BOTTOMLEFT", 0, -2, HUD_EDIT_MODE_SETTING_ACTION_BAR_HIDE_BAR_ART or "Hide Bar Art",
        function(self)
            ns.MicroTouched()
            ns.db.hideBagsArt = self:GetChecked() and true or false
            ns.ToggleChanged("hideBagsArt")
        end)
    extra.art = hideArt
    local one = BagsCheck(extra, hideArt, "BOTTOMLEFT", 0, -2, L["BAR_ONE_BAG_ALL_BAGS_OPEN"], function(self)
        ns.db.oneBag = self:GetChecked() and true or false
        ns.ToggleChanged("oneBag")
        if extra.InitColumns then extra.InitColumns() end
    end)
    extra.one = one
    -- One bag window's width in slots; only with One bag on.
    local colsLabel = extra:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
    colsLabel:SetPoint("TOPLEFT", one, "BOTTOMLEFT", 6, -10)
    colsLabel:SetText(L["BAR_ONE_BAG_COLUMNS"])
    extra.colsLabel = colsLabel
    local slider, formatters = B.StepperSlider(extra, 180, colsLabel, 10, WholeNumber)
    if slider then
        extra.slider = slider
        extra.InitColumns = B.GuardedSlider(slider, ColumnValues, OnColumns,
            { formatters = formatters, owner = extra, enabled = OneBagOn, label = colsLabel })
    end
    -- Addon settings save on click, outside Save/Revert, and say so (a dark Save reads as "nothing happened").
    local saved = extra:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    saved:SetPoint("BOTTOMLEFT", extra, "BOTTOMLEFT", 26, 14)
    saved:SetText(L["BAR_BAG_WINDOW_OPTIONS_APPLY_AND"])
    local resize = CreateFrame("Button", nil, extra, "UIPanelButtonTemplate")
    resize:SetHeight(28)
    resize:SetText(L["BAR_RESET_TO_DEFAULT_SIZE"])
    resize:SetFrameLevel(210)
    resize:SetScript("OnClick", ResetBagsSize)
    ns.EditModeRed(resize)
    extra.resize = resize
    return extra
end

function B.FollowBagsDialog(editing)
    local dialog = EditModeSystemSettingsDialog
    local up = editing and dialog and dialog:IsShown() and dialog.attachedToSystem == BagsBar
    local extra = B.art and B.art.bagsExtra
    if not up then
        if extra and extra:IsShown() then extra:Hide() end
        return
    end
    extra = BagsExtra()
    extra:ClearAllPoints()
    extra:SetPoint("TOPLEFT", dialog, "BOTTOMLEFT", 0, 6)
    extra:SetPoint("TOPRIGHT", dialog, "BOTTOMRIGHT", 0, 6)
    extra.check:SetChecked(ns.db.bagWindowsFollow and true or false)
    if extra.one then extra.one:SetChecked(ns.db.oneBag == true) end
    if extra.above then extra.above:SetChecked(ns.db.bagsAboveRow == true) end
    if extra.art then extra.art:SetChecked(ns.db.hideBagsArt == true) end
    if extra.InitColumns then extra.InitColumns() end
    local revert = dialog.Buttons and dialog.Buttons.RevertChangesButton
    if revert and extra.resize then
        extra.resize:ClearAllPoints()
        extra.resize:SetPoint("LEFT", revert, "RIGHT", 6, 0)
        extra.resize:SetPoint("RIGHT", dialog.Buttons, "RIGHT", 0, 0)
        extra.resize:Show()
    elseif extra.resize then
        extra.resize:Hide()
    end
    extra:Show()
end
