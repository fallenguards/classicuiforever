local _, ns = ...

-- 1.x loot window: one 256x256 sheet over a 170x240 window, loot icon and skull in the ring, four rows of ours with
-- the old name box (Windows/LootRows.lua) and two page arrows. The game's list and bar stand parked off the window,
-- never laid by us: a size or scroll spot of ours written there ran the list as ours and a fight refused its open (#275).

local P = ns.panels
local IsSecret, AnySecret = ns.IsSecret, ns.AnySecret

local LOOT_W, LOOT_H, LOOT_ROW = 170, 240, 41
local LOOT_TOP = 71   -- the list's top from the window's top
local PAGER_ICONS = { "ScrollUp", "ScrollDown" }   -- the old chat buttons (Windows/Chat.lua)
local LOOT_EVENTS = { "LOOT_SLOT_CLEARED", "LOOT_SLOT_CHANGED", "LOOT_OPENED" }
-- Loot at the mouse: the cursor 31 in and 27 down on the first icon (26, -75), as Era puts it; Era's lowest window top.
local CURSOR_X, CURSOR_Y, CURSOR_LOWEST_TOP = 26 + 31, 75 + 27, 350
local LOOT_HUSHED = { "NameFrame", "BorderFrame", "HighlightNameFrame", "PushedNameFrame", "QualityStripe", "QualityText" }
local FULL = { 0, 1, 0, 1 }
local NAME_BOX = { own = "nameBox", layer = "BACKGROUND", sublevel = 1, coords = FULL, w = 130, h = 62, point = "LEFT", show = true }
local SHEET = { own = "lootPanel", layer = "BACKGROUND", sublevel = -2, coords = FULL, w = 256, h = 256, point = "TOPLEFT", y = 4, show = true }
local ICON = { own = "lootIcon", layer = "BACKGROUND", sublevel = -1, w = 58, h = 58, point = "TOPLEFT", x = 10, y = -5, show = true }
local SKULL = { own = "lootSkull", layer = "ARTWORK", sublevel = 0, w = 58, h = 58, point = "TOPLEFT", x = 10, y = -5, show = true }
local CHANGED = { changed = true }
local PARKED_X = -4000   -- off the screen, left of the window
local ours = setmetatable({}, { __mode = "k" })   -- our children of the game's window: never faded with its art

-- Gamepad interface at login: the game's list stays in the window at Era's list spot, its rows the game's (46 tall,
-- 2 apart, 6 in) and its own scrolling, as the navigator's step reads the list's state (#264). Era's spots come back
-- by moving what shows: each row's item up to the Era slot of the row it stands in.
local function PadList() return ns.padSession == true end
local GAME_IN, GAME_STEP = 6, 48
local ITEM_X, ITEM_Y = 5, -4   -- the game's item spot in its row
local PAD_LIST_X, PAD_LIST_Y = 21 - GAME_IN, GAME_IN - LOOT_TOP
local PAD_LIST_H = LOOT_H + PAD_LIST_Y - 5   -- down to Era's foot
local PAD_LIST_BODY = string.format([[ local box = self:GetFrameRef("box") box:SetHeight(%d) box:GetHeight() ]], PAD_LIST_H)

local function SkinLootElement(element)
    -- Every look: the client re-lights these as it fills a row, after dressing.
    ns.FadeKeys(element, LOOT_HUSHED, 0, CHANGED)
    if not ns.Once(element, "loot") then return end
    local item = element.Item
    ns.DressNew(element, "lootNameFrame", NAME_BOX, item or element, item and 30 or 35, 0)
    if element.Text and item then
        ns.SetPointOnce(element.Text, "LEFT", item, "RIGHT", 8, 0)
        element.Text:SetSize(93, 38)
        element.Text:SetJustifyV("MIDDLE")
    end
end

-- A looted row stays as an empty slot until close; hide its name box with it.
local function SyncBox(element)
    local nameBox = element.fcui and element.fcui.nameBox
    if not nameBox then return end
    -- A looted slot comes back from the list as the bare template, no item button: empty.
    local filled = element.Item ~= nil and element.Item:IsShown()
    if element.Text then
        local text = element.Text:GetText()
        if not IsSecret(text) and (text or "") == "" then filled = false end
    end
    nameBox:SetShown(filled and true or false)
end

local function PadRow(element)
    local item, box = element.Item, LootFrame and LootFrame.ScrollBox
    local top, boxTop = element:GetTop(), box and box:GetTop()
    if not (item and top and boxTop) or AnySecret(top, boxTop) then return end
    local slot = math.floor((boxTop - GAME_IN - top) / GAME_STEP + 0.5)
    ns.SetPointIf(item, "TOPLEFT", element, "TOPLEFT", ITEM_X, ITEM_Y + boxTop - GAME_IN - slot * LOOT_ROW - top)
end

local function PageRow(element)
    SyncBox(element)
    PadRow(element)
end

-- The look's visitor: also hushes and dresses rows.
local function LookRow(element)
    SkinLootElement(element)
    PageRow(element)
end

-- The game's list and its bar off the window's size: the same size, one anchor. Only once the game's own layout has
-- settled them (a frame after the first show): a size change of theirs in our run would lay the list as ours.
local parked, padSized = false, false
local function Park(child, frame, x, y)
    if not child then return true end
    local w, h = child:GetSize()
    if AnySecret(w, h) or not (w > 0 and h > 0) then return false end
    child:SetSize(w, h)
    ns.SetPointOnce(child, "TOPLEFT", frame, "TOPLEFT", x, y)
    return true
end

local function ParkList(frame)
    if parked then return true end
    local box = frame.ScrollBox
    if not box then return false end
    local x, y = PARKED_X, 0
    if PadList() then x, y = PAD_LIST_X, PAD_LIST_Y end
    parked = Park(box, frame, x, y) and Park(frame.ScrollBar, frame, PARKED_X, 0)
    return parked
end

-- The pad list's height, Era's four rows: set in a secure run out of a fight, so the list's own layout stays the game's.
local listWrap
local function SizePadList(box)
    if InCombatLockdown() then return false end
    if not listWrap then
        listWrap = CreateFrame("Frame", nil, UIParent, "SecureHandlerBaseTemplate")
        listWrap:SetFrameRef("box", box)
    end
    listWrap:Execute(PAD_LIST_BODY)
    return true
end

local function EnableIf(button, on)
    if button:IsEnabled() ~= on then button:SetEnabled(on) end
end

-- The page shown, from 0; a new loot starts on the first.
local page = 0

-- cleared: a slot was just looted (a page with nothing left turns to the next, Windows/LootRows.lua ns.LootPageOf).
local function UpdateLootPages(frame, visit, cleared)
    -- The game sizes the window as it opens and in edit mode; the old size goes back after its pass, the list off it.
    if parked then ns.SetSizeIf(frame, LOOT_W, LOOT_H) end
    local pager = frame.fcuiPager
    if not pager then return end
    if PadList() then
        local box = frame.ScrollBox
        if box and box.ForEachFrame then box:ForEachFrame(visit or PageRow) end
        if box and parked and not padSized then padSized = SizePadList(box) end
        ns.SetShownIf(pager, false)
        return
    end
    local rows, last, paged
    page, rows, last, paged = ns.LootPageOf(GetNumLootItems(), page, cleared, ns.LootSlotFilled)
    ns.FillLootRows(frame, page, rows, pager.wheel)
    ns.SetShownIf(pager, paged)
    if paged then
        EnableIf(pager.up, page > 0)
        EnableIf(pager.down, page < last)
    end
end

-- The client's spot at the mouse fits its own rows; ours put the skull ring under the cursor.
local function AtCursor(frame)
    local gamepad = InputUtil and InputUtil.IsGamepadUIEnabled and InputUtil.IsGamepadUIEnabled()
    if not (ns.GetCVarBool("lootUnderMouse") or gamepad) then return false end
    if GetNumLootItems() == 0 then return true end
    local scale = frame:GetEffectiveScale()
    local x, y = GetCursorPosition()
    ns.SetPointOnce(frame, "TOPLEFT", nil, "BOTTOMLEFT", x / scale - CURSOR_X, math.max(y / scale + CURSOR_Y, CURSOR_LOWEST_TOP))
    return true
end

-- Not at the mouse and on its edit mode default: past the open windows, as Era's; a spot given in edit mode stays.
local function Place(frame)
    if AtCursor(frame) or ns.InDefaultPosition(frame) == false then
        ns.StopStandingPast(frame)
    else
        ns.StandPastWindows(frame)
    end
end

-- Overflow pages with two arrows at the foot, as in 1.x.
local function LootPager(frame)
    if frame.fcuiPager then UpdateLootPages(frame) return end
    local pager = ns.NewFrame("Frame", nil, frame)
    ours[pager] = true
    pager:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    pager:SetSize(LOOT_W, 40)
    frame.fcuiPager = pager
    local function Arrow(kind, x)
        local button = ns.NewFrame("Button", nil, pager)
        button:SetSize(32, 32)
        button:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", x, 6)
        ns.ChatIconButton(button, "Scroll" .. kind, PAGER_ICONS)
        return button
    end
    -- Centred on the dark body (x 21-180), not the window; labels level with arrows.
    pager.up = Arrow("Up", 23)
    pager.down = Arrow("Down", 146)
    local prev = pager:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    prev:SetPoint("LEFT", pager.up, "RIGHT", 2, 0)
    prev:SetText(PREV or "Prev")
    local nxt = pager:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    nxt:SetPoint("RIGHT", pager.down, "LEFT", -2, 0)
    nxt:SetText(NEXT or "Next")
    local function Turn(direction)
        page = page + direction
        UpdateLootPages(frame)
    end
    local function Page(direction)
        Turn(direction)
        PlaySound(SOUNDKIT.IG_ABILITY_PAGE_TURN)
    end
    pager.up:SetScript("OnClick", function() Page(-1) end)
    pager.down:SetScript("OnClick", function() Page(1) end)
    -- Our shell over the window, mouse off (clicks go through to the rows and the close button): the loot events land
    -- here, and the wheel turns pages instead of free scrolling; the gamepad's list scrolls as the game's.
    local shell = ns.NewFrame("Frame", nil, frame)
    ours[shell] = true
    shell:SetPoint("TOPLEFT")
    shell:SetSize(LOOT_W, LOOT_H)
    shell:EnableMouse(false)
    if not PadList() then
        pager.wheel = function(_, delta) Turn(-delta) end
        shell:EnableMouseWheel(true)
        shell:SetScript("OnMouseWheel", pager.wheel)
    else
        -- The look's job over the game's rows while the window is up: its rows appear with its own scrolls, no event.
        local look = ns.NewFrame("Frame", nil, frame)
        ours[look] = true
        local job = ns.Sched.OnFrame(look, { name = "loot.look", every = 0.02, fn = function() UpdateLootPages(frame, LookRow) end })
        look:SetScript("OnShow", function() job:Kick() end)
    end
    -- After the game's own show pass, ahead of the first draw. The first show waits one frame more: the list parks once
    -- the game's layout has settled it, and nothing of ours reads the window before that.
    local kept, up
    local function Settle()
        UpdateLootPages(frame)
        Place(frame)
        kept, up = { frame:GetLeft(), frame:GetTop() }, true
    end
    ns.Sched.AfterShow(frame, "loot.pages", function()
        if parked then return Settle() end
        ns.Sched.NextFrame("loot.park", function()
            if ParkList(frame) and frame:IsShown() then Settle() end
        end)
    end)
    ns.Sched.OnVisible(frame, "loot.up", function(shown) if not shown then up = false end end)
    ns.RegisterEvents(shell, LOOT_EVENTS)
    local cleared = false
    local function Redraw()
        if frame:IsShown() then UpdateLootPages(frame, nil, cleared) end
        cleared = false
    end
    shell:SetScript("OnEvent", function(_, event)
        if event == "LOOT_OPENED" then
            page = 0
            -- The same loot opened again (a click with full bags): the game's open placed the window again.
            if up and kept then ns.SetPointOnce(frame, "TOPLEFT", nil, "BOTTOMLEFT", kept[1], kept[2]) end
        end
        if event == "LOOT_SLOT_CLEARED" then cleared = true end
        ns.Sched.NextFrame("loot.update", Redraw)
    end)
    UpdateLootPages(frame)
end

-- Fade client textures and unused text on the window and each child not kept.
local FadeBlizzardArt
local function FadeArtRegion(region, frame, keep)
    if ns.IsOwnRegion(frame, region) then return end
    if region:IsObjectType("Texture") then
        region:SetAlpha(0)
    elseif region:IsObjectType("FontString") and not keep[region] then
        region:SetAlpha(0)
    end
end
local function FadeArtChild(child, keep)
    if not (keep[child] or ours[child]) then FadeBlizzardArt(child, keep) end
end
FadeBlizzardArt = function(frame, keep)
    ns.EachRegion(frame, FadeArtRegion, frame, keep)
    ns.EachChild(frame, FadeArtChild, keep)
end

-- Era gives an item's tooltip to its icon, the tooltip beside it over the window; Forever's to the whole row, so it
-- opened past the window's right edge. Put on the icon after the client fills it, while our look is on (the pad list).
local function TipOnIcon(tip)
    local owner = tip:GetOwner()
    local item = owner and owner.Item
    local box, sheet = LootFrame and LootFrame.ScrollBox, LootFrame and LootFrame.fcui and LootFrame.fcui.lootPanel
    if not (item and box and sheet and sheet:IsShown()) then return end
    local target = owner:GetParent()
    if not (target and target:GetParent() == box) then return end
    ns.SetPointOnce(tip, "BOTTOMLEFT", item, "TOPRIGHT", 0, 0)
end

-- Era's window shows at once: the game's open slide and fade replayed on a reopen (a click with full bags), a jump.
local function StillOpen(frame)
    local anim = frame.ShowAnim
    if not anim then return end
    for _, piece in ipairs({ anim:GetAnimations() }) do
        if piece:IsObjectType("Translation") then
            piece:SetOffset(0, 0)
        elseif piece:IsObjectType("Alpha") then
            piece:SetFromAlpha(1)
            piece:SetToAlpha(1)
        end
    end
end

local function SkinLoot(frame)
    StillOpen(frame)
    ns.HookMethod(GameTooltip, "SetLootItem", TipOnIcon)
    ns.HookMethod(GameTooltip, "SetLootCurrency", TipOnIcon)
    local close = frame.ClosePanelButton or frame.CloseButton
    local title = frame.TitleContainer and frame.TitleContainer.TitleText
    local keep = {}
    if frame.ScrollBox then keep[frame.ScrollBox] = true end
    if close then keep[close] = true end
    if title then keep[title] = true end
    FadeBlizzardArt(frame, keep)
    if frame.fcui and frame.fcui.titleStrip then frame.fcui.titleStrip:Hide() end
    ns.DressNew(frame, "lootPanel", SHEET)
    ns.DressNew(frame, "lootIcon", ICON)
    ns.DressNew(frame, "lootSkull", SKULL)
    ns.SetPointOnce(title, "CENTER", frame, "TOPLEFT", 115, -24)
    if close then
        ns.SkinCloseButton(close)
        ns.SetPointOnce(close, "CENTER", frame, "TOPLEFT", 177, -21)
    end
    local box = frame.ScrollBox
    if box then
        -- The pad list's rows are dressed by the look's job, not a list callback; its shadows darkened the end rows.
        if PadList() and box.ForEachFrame then box:ForEachFrame(SkinLootElement) end
        if box.Shadows then box.Shadows:SetAlpha(0) end
    end
    -- The thin scroll bar goes, deaf to the mouse; off the window once the list parks.
    if frame.ScrollBar then
        frame.ScrollBar:SetAlpha(0)
        frame.ScrollBar:EnableMouse(false)
    end
    LootPager(frame)
end
P.after.LootFrame = SkinLoot
