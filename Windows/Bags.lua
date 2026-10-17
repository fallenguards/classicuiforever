local _, ns = ...

-- 1.x bags on the client's containers: bag sheet in Classic's three cuts (top with ring and name, middles per rows, bottom lip),
-- backpack sheet with its money strip, slots on the 41px pitch, the old ring per icon; client art faded.
-- Combined bags (not in 1.x) are one tall backpack, four across unless picked.

local B = ns.bags
local NewBand = B.NewBand

local WIDTH = 192
local COLUMNS = 4
ns.ONE_BAG_COLUMNS_MIN, ns.ONE_BAG_COLUMNS_MAX = 4, 16
local ROW = 41                   -- row pitch: 37 slot + 4 gap
local COL = 42                   -- column pitch: 37 slot + 5 gap
local FIRST_X, FIRST_Y = -12, 9  -- first slot's bottom right, from the frame's
local ROWS_PER_PIECE = 6         -- rows one middle piece of the sheet covers
local BACKPACK_ROWS_PER_PIECE = 5   -- whole rows the sheet holds below the backpack's band start
local ROW_BAR_TOP = 213 / 512    -- a whole row's start on the sheet (lattice bar top)
local SHEET_H = 512
local MIDDLE_TOP = 0.353515625   -- where a row band starts on the sheet
local FIRST_ROW_PIXELS = 9       -- the first row band is cut this much shorter
local BOTTOM_TOP, BOTTOM_BOTTOM, BOTTOM_H = 0.330078125, 0.349609375, 10
local BACKPACK_ROWS = 4          -- the backpack sheet carries four rows and the money strip
local BACKPACK_TOP, BACKPACK_SPLIT = 255, 210   -- the sheet's height, and where it splits when rows are added
local BACKPACK_BASE_H = 240
local BACKPACK_FIRST_Y = -211    -- the first backpack slot's bottom, from the top, with four rows
local BACKPACK_MIDDLE_TOP = 215 / 512   -- backpack extra rows start lower on the sheet than a bag's
local MONEY_Y = -215
-- Close button, its top right from the frame's: the backpack (and the one bag), then every other bag and the key ring.
local BACKPACK_CLOSE_BUTTON_X = 0
local BACKPACK_CLOSE_BUTTON_Y = -1
local BAG_CLOSE_BUTTON_X = 0
local BAG_CLOSE_BUTTON_Y = 0
-- The money strip on the backpack sheet (its top line to its bottom line) and the rim under it; a watched
-- currency row gets a second strip cut the same, and the window grows by one strip.
local STRIP_TOP, STRIP_END = 209, 232
local STRIP_H = STRIP_END - STRIP_TOP
-- The strip's inside from the window's left and right edges (the sheet hangs 64 past the left), and the row's inset.
local STRIP_LEFT, STRIP_RIGHT, TOKEN_INSET = 21, -14, 3
local EMPTY = ns.EMPTY
local QUICK_RING_64 = { set = "raw", tint = true, coords = { 0, 1, 0, 1 }, w = 64, h = 64, point = "CENTER", y = -1 }

local active = false
local KEYRING = Enum.BagIndex.Keyring
local BACKPACK = Enum.BagIndex.Backpack
local REAGENT = Enum.BagIndex.ReagentBag
local hooked = setmetatable({}, { __mode = "k" })
local tints = setmetatable({}, { __mode = "k" })    -- reagent button -> our tint over its socket
local tinted = setmetatable({}, { __mode = "k" })   -- those tints, which the fade skips
local locked = setmetatable({}, { __mode = "k" })   -- item buttons faded as locked slots

-- Without an authenticator the game adds locked slots past the backpack's own; with the option on, the usable count
-- and how many are locked (nil when none are, as with an authenticator).
local function LockedSlots()
    local count = ns.db and ns.db.hideLockedSlots and ContainerFrame_GetContainerNumSlots
    if not count then return nil end
    local max, usable = count(BACKPACK)
    if type(max) ~= "number" or type(usable) ~= "number" then return nil end
    -- Dev stand-in: an account with an authenticator sees its last slots as locked.
    usable = usable - (tonumber(ns.DevLockedSlots) or 0)
    if usable >= max then return nil end
    return usable, max - usable
end

-- Faded and deaf, never hidden: the game lays them out; the padlock's tooltip pad goes deaf too.
local function Lock(button, on)
    if not on and not locked[button] then return end
    locked[button] = on or nil
    ns.SetFrameAlphaIf(button, on and 0 or 1)
    if button:IsMouseEnabled() == on then button:EnableMouse(not on) end
    local pad = button.extendedFrame
    if pad and pad:IsMouseEnabled() == on then pad:EnableMouse(not on) end
end

-- The game's reagent window while our slots stand in the combined bag (option, Windows/BagReagent.lua).
local function ParkedReagent()
    local combined = ContainerFrameCombinedBags
    if not (REAGENT and ns.db and ns.db.reagentBagCombined and combined and combined:IsShown()) then return nil end
    for _, frame in ContainerFrameUtil_EnumerateContainerFrames() do
        if frame:IsShown() and not frame:IsCombinedBagContainer() and frame:GetBagID() == REAGENT then return frame end
    end
end

local function Pieces(frame)
    frame.fcui = frame.fcui or {}
    if not frame.fcui.bagTop then
        frame.fcui.bagTop = NewBand(frame)
        frame.fcui.bagMiddle = {}
        frame.fcui.bagBottom = NewBand(frame)
        frame.fcui.tokenStrip = NewBand(frame)
        frame.fcui.tokenFoot = NewBand(frame)
    end
    return frame.fcui
end

local function Middle(frame, i)
    local list = Pieces(frame).bagMiddle
    if not list[i] then list[i] = NewBand(frame) end
    return list[i]
end

local function ClampColumns(n)
    return math.max(ns.ONE_BAG_COLUMNS_MIN, math.min(ns.ONE_BAG_COLUMNS_MAX, math.floor(n + 0.5)))
end

-- Combined bag: the player's column count; every other bag: four.
local function ColumnsOf(frame)
    local combined = frame.IsCombinedBagContainer and frame:IsCombinedBagContainer()
    if not combined then return COLUMNS end
    return ClampColumns(ns.db and tonumber(ns.db.oneBagColumns) or COLUMNS)
end

local function SetBandColumns(frame, columns)
    local p = Pieces(frame)
    p.bagTop:SetColumns(columns)
    p.bagBottom:SetColumns(columns)
    for _, band in ipairs(p.bagMiddle) do band:SetColumns(columns) end
    p.columns = columns
end

-- Our textures, which the fade skips.
local function IsOurs(frame, region)
    local p = frame.fcui
    if not p then return tinted[region] == true end
    if p.bagTop and (p.bagTop:Owns(region) or p.bagBottom:Owns(region)) then return true end
    if p.tokenStrip and (p.tokenStrip:Owns(region) or p.tokenFoot:Owns(region)) then return true end
    for _, piece in ipairs(p.bagMiddle or EMPTY) do if piece:Owns(region) then return true end end
    for _, piece in ipairs(p.blanks or EMPTY) do if region == piece then return true end end
    return tinted[region] == true
end

-- Fade every client texture but the portrait, slots and controls.
local function FadeFrameRegion(region, frame)
    if region:IsObjectType("Texture") and not IsOurs(frame, region) then region:SetAlpha(0) end
end

local function FadeChildRegion(region, portrait)
    if region:IsObjectType("Texture") and region ~= portrait then region:SetAlpha(0) end
end

local function Kept(frame, child)
    return child == frame.PortraitButton or child == frame.MoneyFrame or child == frame.CloseButton
        or child == frame.FilterIcon or child == BagItemSearchBox or child == BagItemAutoSortButton
        or B.ownChildren[child]
end

local function FadeChild(child, frame, portrait)
    if not Kept(frame, child) and not child.GetBagID and not child.GetSlotAndBagID then
        ns.EachRegion(child, FadeChildRegion, portrait)
    end
end

local function FadeArt(frame)
    ns.EachRegion(frame, FadeFrameRegion, frame)
    local portrait = frame.PortraitContainer and frame.PortraitContainer.portrait
    ns.EachChild(frame, FadeChild, frame, portrait)
    if frame.Bg and frame.Bg.SetAlpha and frame.Bg.IsObjectType and frame.Bg:IsObjectType("Texture") then frame.Bg:SetAlpha(0) end
end

-- Middle band i under last: pixels tall, cut from the sheet at from.
local function DrawMiddle(frame, p, i, last, pixels, from)
    local piece = Middle(frame, i)
    piece:SetColumns(p.columns or COLUMNS)
    piece:SetSheet(p.sheet)
    ns.SetPointOnce(piece, "TOP", last, "BOTTOM", 0, 0)
    piece:SetHeight(pixels)
    piece:SetTexCoord(from, pixels / SHEET_H + from)
    piece:SetAlpha(1)
    piece:Show()
    return piece
end

local function HideMiddles(p, used)
    for j = used + 1, #p.bagMiddle do p.bagMiddle[j]:Hide() end
end

local function DrawBottom(bottom, key, height, from, to, last)
    bottom:SetSheet(key)
    bottom:SetHeight(height)
    bottom:SetTexCoord(from, to)
    ns.SetPointOnce(bottom, "TOP", last, "BOTTOM", 0, 0)
    bottom:SetAlpha(1)
    bottom:Show()
end

-- Sheet pieces for a bag of this many rows, cut as the Classic client did.
local function DrawBag(frame, rows, plusTwo)
    local p = Pieces(frame)
    local top, bottom = p.bagTop, p.bagBottom
    top:SetSheet(p.sheet)
    ns.SetPointOnce(top, "TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    if plusTwo then
        top:SetTexCoord(0.189453125, 0.330078125)
        top:SetHeight(72)
    elseif rows == 1 then
        top:SetTexCoord(0.00390625, 0.16796875)
        top:SetHeight(86)
    else
        top:SetTexCoord(0.00390625, 0.18359375)
        top:SetHeight(94)
    end
    top:SetAlpha(1)
    top:Show()
    local remaining = rows - 1
    local last = top
    local middleHeight = 0
    local i = 0
    while remaining > 0 do
        i = i + 1
        local n = math.min(remaining, ROWS_PER_PIECE)
        -- First piece 9px short (as Classic's) to finish the row the top began;
        -- later ones start on a lattice bar, or the bars break at the join.
        local pixels = n * ROW - (i == 1 and FIRST_ROW_PIXELS or 0)
        last = DrawMiddle(frame, p, i, last, pixels, i == 1 and MIDDLE_TOP or ROW_BAR_TOP)
        middleHeight = middleHeight + pixels
        remaining = remaining - n
    end
    HideMiddles(p, i)
    DrawBottom(bottom, p.sheet, BOTTOM_H, BOTTOM_TOP, BOTTOM_BOTTOM, last)
    return top:GetHeight() + middleHeight + BOTTOM_H
end

-- A second money strip and the rim under last, for the watched currency row; hidden without one.
local function DrawTokenStrip(p, last, on)
    local strip, foot = p.tokenStrip, p.tokenFoot
    if not on then
        strip:Hide()
        foot:Hide()
        return 0
    end
    strip:SetColumns(p.columns or COLUMNS)
    foot:SetColumns(p.columns or COLUMNS)
    DrawBottom(strip, "backpackBg", STRIP_H, STRIP_TOP / BACKPACK_TOP, STRIP_END / BACKPACK_TOP, last)
    DrawBottom(foot, "backpackBg", BACKPACK_TOP - STRIP_END, STRIP_END / BACKPACK_TOP, 1, strip)
    return STRIP_H
end

-- Backpack sheet: four rows plus money strip; extra rows go between its halves, a currency strip under the money.
local function DrawBackpack(frame, rows, token)
    local p = Pieces(frame)
    local top, bottom = p.bagTop, p.bagBottom
    -- Rows past the sheet's four (added between its halves), or fewer (cut out of it); the slots move by as many.
    local extra = rows - BACKPACK_ROWS
    top:SetSheet("backpackBg")
    ns.SetPointOnce(top, "TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    local middleHeight = 0
    -- With a currency strip the sheet stops at the money strip's foot; the strip and the rim follow.
    local sheetEnd = token and STRIP_END or BACKPACK_TOP
    if extra < 0 then
        -- A combined bag of few slots across many columns: the header, then the sheet from as many lattice lines
        -- down as rows go unused (the top row was left an empty lattice).
        local header = BACKPACK_SPLIT - BACKPACK_ROWS * ROW
        local from = header - extra * ROW
        top:SetHeight(header)
        top:SetTexCoord(0, header / BACKPACK_TOP)
        HideMiddles(p, 0)
        DrawBottom(bottom, "backpackBg", sheetEnd - from, from / BACKPACK_TOP, sheetEnd / BACKPACK_TOP, top)
        middleHeight = extra * ROW + DrawTokenStrip(p, bottom, token)
    elseif extra > 0 then
        top:SetHeight(BACKPACK_SPLIT)
        top:SetTexCoord(0, BACKPACK_SPLIT / BACKPACK_TOP)
        local last = top
        local remaining = extra
        local i = 0
        while remaining > 0 do
            i = i + 1
            -- Whole rows at true height, at most five (all the sheet holds from here),
            -- each piece ending on the next one's lattice line; stretched rows drifted.
            local n = math.min(remaining, BACKPACK_ROWS_PER_PIECE)
            last = DrawMiddle(frame, p, i, last, n * ROW, BACKPACK_MIDDLE_TOP)
            middleHeight = middleHeight + n * ROW
            remaining = remaining - n
        end
        HideMiddles(p, i)
        DrawBottom(bottom, "backpackBg", sheetEnd - BACKPACK_SPLIT, BACKPACK_SPLIT / BACKPACK_TOP, sheetEnd / BACKPACK_TOP, last)
        middleHeight = middleHeight + DrawTokenStrip(p, bottom, token)
    else
        top:SetHeight(sheetEnd)
        top:SetTexCoord(0, sheetEnd / BACKPACK_TOP)
        HideMiddles(p, 0)
        bottom:Hide()
        middleHeight = DrawTokenStrip(p, top, token)
    end
    top:SetAlpha(1)
    top:Show()
    return BACKPACK_BASE_H + middleHeight, extra
end

-- The client's watched currency row, when it hangs on this window and shows (widget reads only).
local function TokenRow(frame)
    local row = _G.BackpackTokenFrame
    if row and row:GetParent() == frame and row:IsShown() then return row end
end

local function EmptyLook(button)
    if button.icon then button.icon:SetAlpha(button.hasItem and 1 or 0) end
end

-- Plain quest items: the client only sets the quest border's file and shows it, so a faded one stays faded.
function ns.QuestItemLook(button)
    local quest = button.IconQuestTexture
    if quest then ns.SetAlphaIf(quest, ns.db and ns.db.plainQuestItems == true and 0 or 1) end
end

local function SlotArt(button)
    ns.QuestItemLook(button)
    if not ns.Once(button, "slot") then
        EmptyLook(button)
        return
    end
    if button.SetItemButtonTexture then hooksecurefunc(button, "SetItemButtonTexture", EmptyLook) end
    EmptyLook(button)
    -- Old ring; bronze with the bronze theme.
    ns.Dress(button:GetNormalTexture(), ns.ART.QUICKSLOT, QUICK_RING_64, button)
end

-- The sheet has a socket in every grid place: a short last row gets one patch of
-- plain leather over the empty ones, short of the bars above and beside.
local BLANK_L, BLANK_R, BLANK_T, BLANK_B = 110 / 256, 158 / 256, 126 / 512, 160 / 512
local BLANK_H = 37

local function Blank(frame, i)
    local p = Pieces(frame)
    p.blanks = p.blanks or {}
    if not p.blanks[i] then
        local tex = frame:CreateTexture(nil, "BACKGROUND", nil, 0)
        tex:SetTexCoord(BLANK_L, BLANK_R, BLANK_T, BLANK_B)
        p.blanks[i] = tex
    end
    ns.SetTex(p.blanks[i], p.sheet)
    return p.blanks[i]
end

-- Bags fill from the bottom right, leftward then up (1.x); the combined bag reads
-- like a page, gaps at the bottom right. Anchors are written only when they differ.
local function Place(region, index, dx, dy, frame, columns, rows, count, combined, backpackExtra)
    local column, row
    if combined then
        local k = count - 1 - index
        column = columns - 1 - (k % columns)
        row = rows - 1 - math.floor(k / columns)
    else
        column = index % columns
        row = math.floor(index / columns)
    end
    if backpackExtra then
        ns.SetPointIf(region, "BOTTOMRIGHT", frame, "TOPRIGHT", FIRST_X - column * COL + dx, BACKPACK_FIRST_Y - ROW * backpackExtra + row * ROW + dy)
    else
        ns.SetPointIf(region, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", FIRST_X - column * COL + dx, FIRST_Y + row * ROW + dy)
    end
end

local spare = {}   -- the slot list, reused; a nested pass takes a new one

-- On the slot's parent (our holder in the combined bag), under the slot and over the combined bag's sheet.
local function Tint(button, color)
    local tex = tints[button]
    if not color then
        if tex then tex:Hide() end
        return
    end
    if not tex then
        tex = button:GetParent():CreateTexture(nil, "BACKGROUND")
        tex:SetAllPoints(button)
        tints[button], tinted[tex] = tex, true
    end
    tex:SetColorTexture(color[1], color[2], color[3], color[4])
    tex:Show()
end

-- The slots in page order (combined) or 1.x order; the reagent bag's tinted with tint on; one blank patch (none on a
-- plusTwo bag, whose top has a cut for it). Returns how many patches it used.
local function LaySlots(frame, list, count, columns, combined, backpackExtra, tint, noBlank)
    local rows = math.ceil(count / columns)
    for i = 1, count do
        local button = list[i]
        list[i] = nil
        SlotArt(button)
        Place(button, i - 1, 0, 0, frame, columns, rows, count, combined, backpackExtra)
        Tint(button, B.SlotTint(button, tint))
    end
    local missing = rows * columns - count
    if noBlank or missing <= 0 then return 0 end
    local tex = Blank(frame, 1)
    tex:SetSize(missing * COL - 3, BLANK_H)
    -- Right end at the grid's last place in page order (combined), else the first place past the slots.
    Place(tex, combined and (count - rows * columns) or count, 1, -1, frame, columns, rows, count, combined, backpackExtra)
    tex:Show()
    return 1
end

-- For the sections' layout (Windows/BagSections.lua).
B.COL, B.BLANK_H, B.SlotArt, B.Tint, B.Place, B.Blank = COL, BLANK_H, SlotArt, Tint, Place, Blank

-- Our reagent slots into the list, last slot first: the combined bag's list runs from its foot to its top.
local function AddReagentSlots(list, count, own, n)
    for i = n, 1, -1 do
        count = count + 1
        list[count] = own[i]
    end
    return count
end

-- The slots to lay, foot to top: the game's (locked ones out), ours for the reagent bag before or after (option), the
-- key ring's after everything (option), all in one grid.
local function SlotList(frame, combined)
    local list = spare or {}
    spare = nil
    local count = 0
    local usable = LockedSlots()
    if combined then count = AddReagentSlots(list, count, ns.OwnKeyringSlots()) end
    -- The reagent bag's slots before the backpack's, or after the last bag's (option), as another bag's.
    local own, n = EMPTY, 0
    if combined then own, n = ns.OwnReagentSlots() end
    local last = ns.db and ns.db.reagentSlotsLast == true
    if last then count = AddReagentSlots(list, count, own, n) end
    for _, button in frame:EnumerateValidItems() do
        local off = usable and button:GetBagID() == BACKPACK and button:GetID() > usable or false
        Lock(button, off)
        if not off then
            count = count + 1
            list[count] = button
        end
    end
    if not last then count = AddReagentSlots(list, count, own, n) end
    return list, count
end

local function LayoutItems(frame, backpackExtra, combined, plusTwo)
    if not frame.EnumerateValidItems then return end
    local list, count = SlotList(frame, combined)
    local tint = combined and ns.db and ns.db.reagentBagTint == true
    local blanks
    if combined and B.Sectioned() then
        blanks = B.LaySections(frame, list, count, ColumnsOf(frame), backpackExtra, tint)
    else
        if combined then B.ClearSections(frame) end
        blanks = LaySlots(frame, list, count, ColumnsOf(frame), combined, backpackExtra, tint, plusTwo)
    end
    spare = list
    local made = Pieces(frame).blanks
    if made then for j = blanks + 1, #made do made[j]:Hide() end end
end

-- The gamepad's bag bar in the combined bag (backpack and bag buttons): since beta 70291 the client no longer hides it
-- without a controller, and its buttons, unplaced, pile up over the sort button. Faded and deaf then, never hidden: its
-- buttons' close code would run in our name.
local function Deaf(frame, depth)
    if frame.IsMouseEnabled and frame:IsMouseEnabled() then frame:EnableMouse(false) end
    if depth < 3 then ns.EachChild(frame, Deaf, depth + 1) end
end

-- Returns the bar while it is off, for the sort button to stand above it.
local function GamepadBarOff()
    local bar = _G.GamepadBagBar
    if not bar or ns.GamepadUI() then return nil end
    ns.SetAlphaIf(bar, 0)
    -- Its buttons' dropdowns take the mouse too.
    Deaf(bar, 0)
    return bar
end

-- The sort button near the client's 28 x 26, its foot clear of the top row (51 down); the fixed-size hover glow (24 x 23)
-- cut to match.
local SORT_W, SORT_H, SORT_GLOW_W, SORT_GLOW_H = 24, 22, 21, 20
local function PlaceSearch(frame)
    if BagItemSearchBox and BagItemSearchBox:GetParent() == frame then
        ns.SetPointOnce(BagItemSearchBox, "TOPLEFT", frame, "TOPLEFT", 52, -31)
        BagItemSearchBox:SetSize(104, 16)
    end
    if BagItemAutoSortButton and BagItemAutoSortButton:GetParent() == frame then
        ns.SetPointOnce(BagItemAutoSortButton, "TOPRIGHT", frame, "TOPRIGHT", -10, -28)
        ns.SetSizeIf(BagItemAutoSortButton, SORT_W, SORT_H)
        local glow = BagItemAutoSortButton:GetHighlightTexture()
        if glow then ns.SetSizeIf(glow, SORT_GLOW_W, SORT_GLOW_H) end
    end
    local bar = frame.IsCombinedBagContainer and frame:IsCombinedBagContainer() and GamepadBarOff()
    if bar and BagItemAutoSortButton then ns.SetLevelIf(BagItemAutoSortButton, bar:GetFrameLevel() + 5) end
end

local shape = setmetatable({}, { __mode = "k" })   -- bag frame -> { extra, plusTwo, wider } as last drawn
local parked = setmetatable({}, { __mode = "k" })  -- the game's reagent window while our slots fill the combined bag
function ns.BagIsParked(frame) return parked[frame] == true end

local HEADER = { "PortraitContainer", "TitleContainer", "CloseButton" }
local function Header(frame, shown)
    for _, key in ipairs(HEADER) do
        local piece = frame[key]
        if piece then
            ns.SetAlphaIf(piece, shown and 1 or 0)
            if piece.IsMouseEnabled and piece:IsMouseEnabled() ~= shown then piece:EnableMouse(shown) end
        end
    end
    if frame:IsMouseEnabled() ~= shown then frame:EnableMouse(shown) end
end

-- Opened by B or a vendor beside the combined bag that holds our slots: kept open, so B's toggle still counts it, but
-- its art, header and slots unseen and deaf, the window a dot on the combined bag's corner.
local function Park(frame)
    FadeArt(frame)
    local p = Pieces(frame)
    for _, piece in ipairs({ p.bagTop, p.bagBottom, p.tokenStrip, p.tokenFoot }) do piece:Hide() end
    HideMiddles(p, 0)
    for _, blank in ipairs(p.blanks or EMPTY) do blank:Hide() end
    Header(frame, false)
    for _, button in frame:EnumerateValidItems() do
        Lock(button, true)
        Tint(button, nil)
    end
    frame:SetSize(1, 1)
    ns.SetPointOnce(frame, "TOPLEFT", ContainerFrameCombinedBags, "TOPLEFT", 0, 0)
    parked[frame] = true
end

-- Runs inside the client's layout pass: it stacks bags by height, so a deferred
-- pass would misplace them or flash the client's layout.
-- part: what a layout step of the game's just undid ("size", "items", "trim", "search"); nil is the whole skin.
local function Skin(frame, part)
    if not active or not frame or not frame.GetBagSize then
        if ns.debugSink then
            ns.Persist(string.format("bags: skip %s active %s hasSize %s", tostring(frame and frame:GetName()), tostring(active), tostring(frame and frame.GetBagSize ~= nil)))
        end
        return
    end
    if frame == ParkedReagent() then return Park(frame) end
    if parked[frame] then
        parked[frame] = nil
        Header(frame, true)
        part = nil
    end
    local reagent = ParkedReagent()
    if reagent and not parked[reagent] and frame == ContainerFrameCombinedBags then Park(reagent) end
    local combined = frame.IsCombinedBagContainer and frame:IsCombinedBagContainer() and true or false
    local main = combined or (frame.IsBackpack and frame:IsBackpack())
    local _, lockedCount = LockedSlots()
    local size = (frame:GetBagSize() or 0) - (main and lockedCount or 0)
    if size <= 1 then return end
    local at = shape[frame]
    -- Nothing drawn yet to place by: the whole skin.
    if not at then part = nil end
    if part == "items" then return LayoutItems(frame, at.extra, combined, at.plusTwo) end
    if part == "search" then return PlaceSearch(frame) end
    local keyring = frame.MatchesBagID and frame:MatchesBagID(KEYRING)
    local tokenRow = main and TokenRow(frame)
    if part ~= "trim" then
        local columns = ColumnsOf(frame)
        local own = combined and (select(2, ns.OwnReagentSlots()) + select(2, ns.OwnKeyringSlots())) or 0
        local rows = math.ceil((size + own) / columns)
        if combined and B.Sectioned() then
            local list, count = SlotList(frame, true)
            rows = B.SectionRows(list, count, columns)
            wipe(list)
            spare = list
        end
        SetBandColumns(frame, columns)
        if ns.debugSink then
            ns.Persist(string.format("bags: skin %s size %d rows %d backpack %s", tostring(frame:GetName()), size, rows, tostring(frame.IsBackpack and frame:IsBackpack())))
        end
        FadeArt(frame)
        Pieces(frame).sheet = keyring and "bagComponentsKeyring" or "bagComponents"
        local height
        at = at or {}
        shape[frame] = at
        at.plusTwo = false
        if main then
            height, at.extra = DrawBackpack(frame, rows, tokenRow ~= nil)
        else
            at.plusTwo = size % COLUMNS == 2
            height, at.extra = DrawBag(frame, rows, at.plusTwo), nil
        end
        at.wider = (columns - COLUMNS) * COL
        frame:SetSize(WIDTH + at.wider, height)
    end
    local extra, wider = at.extra, at.wider
    if part == nil then LayoutItems(frame, extra, combined, at.plusTwo) end
    -- The game's add-authenticator button rides the last locked slot: gone with them.
    local add = main and frame.AddSlotsButton
    if add then
        local hide = lockedCount ~= nil
        ns.SetAlphaIf(add, hide and 0 or 1)
        if add:IsMouseEnabled() == hide then add:EnableMouse(not hide) end
    end
    -- Old spots for portrait, name, close, money, search. Move the portrait's
    -- container so its round mask follows; the backpack gets the old bag icon.
    local pc = frame.PortraitContainer
    local portrait = pc and pc.portrait
    if pc then
        pc:SetSize(40, 40)
        ns.SetPointOnce(pc, "TOPLEFT", frame, "TOPLEFT", 4, -4)
        pc:SetFrameLevel(frame:GetFrameLevel())
    end
    if portrait then
        portrait:ClearAllPoints()
        portrait:SetAllPoints(pc)
        portrait:SetDrawLayer("BACKGROUND", -8)
        if main then
            ns.SetTex(portrait, "backpackIcon")
            portrait:SetTexCoord(0, 1, 0, 1)
        elseif keyring then
            ns.SetTex(portrait, "keyringPortrait")
            portrait:SetTexCoord(0, 1, 0, 1)
        end
    end
    local title = frame.TitleContainer and frame.TitleContainer.TitleText
    if title then
        title:SetFontObject("GameFontHighlight")
        ns.SetPointOnce(title, "TOPLEFT", frame, "TOPLEFT", 47, -10)
        title:SetWidth(112 + wider)
        title:SetJustifyH("CENTER")
    end
    local close = frame.CloseButton
    if close then
        ns.SkinCloseButton(close, true)
        ns.SetPointOnce(close, "TOPRIGHT", frame, "TOPRIGHT", main and BACKPACK_CLOSE_BUTTON_X or BAG_CLOSE_BUTTON_X,
            main and BACKPACK_CLOSE_BUTTON_Y or BAG_CLOSE_BUTTON_Y)
    end
    -- Money on the sheet's own strip; the client's pill goes.
    if frame.MoneyFrame and extra then
        local money = frame.MoneyFrame
        ns.SetPointOnce(money, "TOPRIGHT", frame, "TOPRIGHT", -6, MONEY_Y - ROW * extra)
        ns.FadeTextures(money.Border)
    end
    -- The currency row inside the strip under the money, as wide as the money strip's inside.
    if tokenRow and extra then
        local y = -(STRIP_END + ROW * extra + TOKEN_INSET)
        tokenRow:ClearAllPoints()
        tokenRow:SetPoint("TOPLEFT", frame, "TOPLEFT", STRIP_LEFT, y)
        tokenRow:SetPoint("TOPRIGHT", frame, "TOPRIGHT", STRIP_RIGHT, y)
        if tokenRow.Border then ns.FadeTextures(tokenRow.Border) end
    end
    if part == nil then PlaceSearch(frame) end
end

-- The game's layout steps and the part of the skin each undoes (ContainerFrame.lua; a bag opening runs all four
-- after its show, and the whole skin after each cost five skins a bag).
local LAYOUT_PARTS = { UpdateFrameSize = "size", UpdateItemLayout = "items", UpdateSearchBox = "search",
    UpdateMiscellaneousFrames = "trim" }

-- The parked reagent window shut: its header back for its next open; the combined bag shut: it stands alone.
local function Hidden(self)
    if parked[self] then
        parked[self] = nil
        Header(self, true)
    elseif self.IsCombinedBagContainer and self:IsCombinedBagContainer() then
        for reagent in pairs(parked) do Skin(reagent) end
    end
end

local function Hook(frame)
    if hooked[frame] then return end
    hooked[frame] = true
    for method, part in pairs(LAYOUT_PARTS) do
        if type(rawget(frame, method)) == "function" then
            ns.HookMethod(frame, method, function(self) Skin(self, part) end)
        end
    end
    frame:HookScript("OnShow", function(self) Skin(self) end)
    frame:HookScript("OnHide", Hidden)
end

-- Combined bag columns (settings, or the edit mode bags dialog); applies live.
function ns.SetOneBagColumns(columns)
    columns = ClampColumns(tonumber(columns) or COLUMNS)
    if not ns.db then return columns end
    ns.db.oneBagColumns = columns
    ns.ReskinOneBag()
    return columns
end

-- The combined bag laid again while open: its columns, or the reagent slots' count (Windows/BagReagent.lua).
function ns.ReskinOneBag()
    local frame = ContainerFrameCombinedBags
    if active and frame and frame:IsShown() then ns.SafeCall(Skin, frame) end
end

-- Every container frame once, in the order the client lists them.
local frameList, frameSeen = {}, {}
local function AddFrame(frame)
    if frame and not frameSeen[frame] then
        frameSeen[frame] = true
        frameList[#frameList + 1] = frame
    end
end

local function Frames()
    wipe(frameList)
    wipe(frameSeen)
    local container = ContainerFrameContainer
    if container and container.ContainerFrames then
        for _, frame in ipairs(container.ContainerFrames) do AddFrame(frame) end
    end
    for i = 1, 13 do AddFrame(_G["ContainerFrame" .. i]) end
    AddFrame(ContainerFrameCombinedBags)
    return frameList
end

-- oneBag mirrors the client's combinedBags CVar (ns.ToggleChanged writes it), so
-- a change in the game's options shows here too.
local function ReadOneBag()
    if not (ns.db and C_CVar and C_CVar.GetCVar) then return end
    local value = ns.GetCVar("combinedBags")
    if value ~= nil then ns.db.oneBag = tostring(value) == "1" end
end
ns.RegisterModule("oneBag", { apply = ReadOneBag, restore = ReadOneBag })

-- The ring in its own window, as 1.x: the client opens it only once showKeyring is on (its first login
-- holding a key), and with one bag on it opens the combined bag instead.
local function RingFrame()
    for _, frame in ContainerFrameUtil_EnumerateContainerFrames() do
        if frame:IsShown() and not frame:IsCombinedBagContainer() and frame:GetBagID() == KEYRING then return frame end
    end
end

local function FreeFrame()
    for _, frame in ContainerFrameUtil_EnumerateContainerFrames() do
        if not frame:IsShown() and not frame:IsCombinedBagContainer() and frame:CanUseForBagID(KEYRING) then return frame end
    end
end

local click = {}
local function RingPreClick(_, button)
    click.skip = not active or InCombatLockdown() or button ~= "LeftButton" or IsModifiedClick() or CursorHasItem()
        or (KeybindFrames_InQuickKeybindMode and KeybindFrames_InQuickKeybindMode())
        or (ContainerFrame_AllowedToOpenBags and not ContainerFrame_AllowedToOpenBags())
    if click.skip then return end
    local combined = ContainerFrameCombinedBags
    click.bags = combined and combined:IsShown()
    click.ring = RingFrame() ~= nil
end

local function RingClick()
    if click.skip then return end
    local combined = ContainerFrameSettingsManager and ContainerFrameSettingsManager:IsUsingCombinedBags(KEYRING)
    if ns.GetCVarBool("showKeyring") and not combined then return end
    -- Keys in the one bag (its option): the client's own toggle of the one bag stands.
    if combined and ns.db.oneBagKeyring == true then return end
    -- Undo the client's combined bag toggle.
    local bags = ContainerFrameCombinedBags
    if bags and combined then
        if bags:IsShown() and not click.bags then
            bags:Hide()
        elseif click.bags and not bags:IsShown() then
            OpenBackpack()
        end
    end
    local ring = RingFrame()
    if click.ring then
        if ring then ring:Hide() end
        return
    end
    local frame = not ring and FreeFrame()
    if frame then ContainerFrame_GenerateFrame(frame, math.max(GetKeyRingSize(), 4), KEYRING) end
end

-- The options pass waits out a fight; these may change in one, so open bags turn at once.
local RESKIN = { hideLockedSlots = true, reagentBagCombined = true, reagentBagTint = true, reagentSlotsFirst = true,
    reagentSlotsLast = true, oneBagSplitNone = true, oneBagSplitType = true, oneBagSplitBag = true, oneBagKeyring = true,
    oneBagBagSlots = true }
ns.OnToggle(function(key)
    if (key ~= "plainQuestItems" and not RESKIN[key]) or not active then return end
    for _, frame in ipairs(Frames()) do
        if frame:IsShown() and frame.EnumerateValidItems then
            if RESKIN[key] then
                ns.SafeCall(Skin, frame)
            else
                for _, button in frame:EnumerateValidItems() do ns.QuestItemLook(button) end
            end
        end
    end
end)

local function Apply()
    active = true
    if KeyRingButton and KEYRING and ns.Once(KeyRingButton, "emptyRing") then
        KeyRingButton:HookScript("PreClick", RingPreClick)
        KeyRingButton:HookScript("OnClick", RingClick)
    end
    local frames = Frames()
    if ns.debugSink then ns.Persist("bags: apply, frames " .. #frames) end
    for _, frame in ipairs(frames) do
        Hook(frame)
        if frame:IsShown() then Skin(frame) end
    end
    -- Our slots made now, out of combat, before a first open in a fight.
    if not InCombatLockdown() then
        ns.OwnReagentSlots()
        ns.OwnKeyringSlots()
    end
end

local function Restore()
    active = false
    ns.needsReload = true
end

ns.RegisterModule("bags", { apply = Apply, restore = Restore })
