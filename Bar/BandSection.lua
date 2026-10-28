local _, ns = ...
local L = ns.L
local B = ns.band

-- The latency bar and the key ring as pieces of their own: in the band's section (BandShape) until hidden (their options,
-- or the box's dialog) or dragged off the band by their edit mode box to stand alone in their own cut of the section art.
-- Dropped near the band they go back. Places are ours (db.latencyPos, db.keyRingPos), as the micro menu's.

local BAND_H, BAND_RUN = B.BAND_H, B.BAND_RUN
local Seat, CurrentPlan = B.Seat, B.CurrentPlan
local SHEET = B.PIECES[5]
local KEY_Y = 20.5   -- Era's key ring: 1 above the band's foot
local KEY_PAD, TIGHT_GAP = 0, 0   -- the bare key ring: its home the key itself, touching the bags (its art has its own rim)
local RUN = {}

-- u0, u1: the piece standing alone. The shared post between window and slot is wider than the end posts: the latency bar
-- keeps 8 of its 9 columns, the key ring takes its own end post mirrored (cap, cap wide) on its left instead.
local ELEMENTS = {
    { label = L["BAR_LATENCY_BAR"], hideKey = "hideLatencyBar", posKey = "latencyPos", u0 = 0, u1 = 22, cap = 0 },
    { label = L["BAR_KEY_RING"], hideKey = "hideKeyRing", posKey = "keyRingPos", u0 = 23, u1 = 45, cap = 7 },
}
local LATENCY, KEYRING = ELEMENTS[1], ELEMENTS[2]

local function Hidden(el) return ns.db[el.hideKey] == true end
local function Moved(el) return ns.ValidPlace(ns.db[el.posKey]) end

-- The key ring on its side (its dialog): off the band it lies flat, as the game's does by a column of bags, its cut of
-- the section turned with it; dropped by a column's far end it rides there (keyRingSnap). turn: "cw" or "ccw" as the
-- bags' floor (BandBags FloorRun), nil upright.
local SNAP_REACH = 24
local function Flat(el) return el == KEYRING and ns.db.keyRingFlat == true end
local function Snapped(el) return el == KEYRING and B.KeyRingWithBags() and B.BagsFarEnd() ~= nil end
-- The key ring off the band without its cut of art: its own Hide Bar Art, or the bags' with Hide key ring art too
-- (#195), riding the bags or not.
local function Bare(el)
    return el == KEYRING and (ns.db.keyRingArtHidden == true or (ns.db.hideBagsArt == true and ns.db.keyRingArtWithBags == true))
end

-- Hidden, or with no place of ours this layout, the client's key ring is hidden (it lays it beside its bags at its own size:
-- the empty box left of the row). Hidden, not faded: an alpha animation on it undoes any fade. Given back as the band goes.
local keyOff, keyWasShown, keyJob = false, false, nil
-- Sole writer of keyOff; the watch that hides it again is awake only while it is on.
local function SetKeyOff(off)
    keyOff = off
    if not keyJob then return end
    if off then keyJob:Wake() else keyJob:Sleep() end
end
local function KeyRingShown(shown)
    local keyRing = KeyRingButton
    if not keyRing then return end
    if not shown then
        if not keyOff then keyWasShown = keyRing:IsShown() end
        SetKeyOff(true)
        if keyRing:IsShown() then keyRing:Hide() end
        if keyRing:IsMouseEnabled() then keyRing:EnableMouse(false) end
    elseif keyOff then
        SetKeyOff(false)
        ns.SetAlphaIf(keyRing, 1)
        keyRing:EnableMouse(true)
        if keyWasShown then keyRing:Show() end
    end
end
function B.KeyRingBack() KeyRingShown(true) end

-- Shown by the client: hidden again the frame after, never inside its pass.
local function HideAgain()
    if keyOff and B.active then KeyRingShown(false) end
end
local function KeyRingSeen(shown)
    if shown and keyOff then ns.Sched.NextFrame("band.keyRingHide", HideAgain) end
end

-- Its band x and width inside the section, or nil when it is not there.
local function OnBand(el, plan)
    if not plan.tailStart then return nil end
    local latency, key = B.TailParts()
    local u0, u1 = plan.tailU0, plan.tailU1
    if el == LATENCY then
        if not latency then return nil end
        if plan.tailSlot then u1 = 14 end
    else
        if not key then return nil end
        if latency then u0 = 14 end
    end
    return plan.tailStart + u0 - plan.tailU0, u1 - u0
end

-- Where a drop puts it back on the band: its place in the section, or where the section stands or would stand.
local function BandSpot(el)
    local plan = CurrentPlan()
    local x = OnBand(el, plan)
    if x then return x end
    if plan.tailStart then return el == LATENCY and plan.tailStart or plan.tailStart + plan.tailU1 - plan.tailU0 end
    if plan.microFirst then return plan.microEnd end
    if plan.bagsFirst then return plan.bagsEnd end
    return plan.bagsStart or plan.width
end

------------------------------------------------------------------ dialog

local dialog
local DIALOG_H, FLAT_ROW = 136, 32
local function RefreshDialog()
    if not (dialog and dialog:IsShown() and dialog.el) then return end
    local key = dialog.el == KEYRING
    -- Its art is the band's while it stands there.
    local artRow = key and (Moved(dialog.el) or Snapped(dialog.el))
    dialog.title:SetText(dialog.el.label)
    dialog.check:SetChecked(Hidden(dialog.el))
    dialog.flat:SetShown(key)
    dialog.flat:SetChecked(Flat(dialog.el))
    dialog.art:SetShown(artRow)
    dialog.art:SetChecked(ns.db.keyRingArtHidden == true)
    dialog:SetHeight(DIALOG_H + (key and FLAT_ROW or 0) + (artRow and FLAT_ROW or 0))
    dialog.reset:SetEnabled(Moved(dialog.el) or (key and (ns.db.keyRingSnap == true or ns.db.keyRingFlat == true)))
end

local function Save()
    RefreshDialog()
    ns.QueueChanged()
end

-- One of the dialog's checks, under anchor (the dialog's top for the first).
local function DialogCheck(anchor, first, text, onClick)
    local check = CreateFrame("CheckButton", nil, dialog, "UICheckButtonTemplate")
    check:SetSize(30, 30)
    if first then
        check:SetPoint("TOPLEFT", anchor, "TOPLEFT", 20, -46)
    else
        check:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    end
    ns.EditModeCheck(check)
    local label = check:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
    label:SetPoint("LEFT", check, "RIGHT", 4, 0)
    label:SetText(text)
    check:SetScript("OnClick", onClick)
    return check
end

local function Dialog()
    if dialog then return dialog end
    dialog = B.EditDialog("ForeverClassicUISectionDialog", 300, 136)
    dialog.check = DialogCheck(dialog, true, L["BAR_HIDE"], function(self)
        local key = dialog.el.hideKey
        ns.db[key] = self:GetChecked() and true or false
        ns.ToggleChanged(key)
        if ns.db[key] then dialog:Hide() end
    end)
    -- The key ring only: on its side off the band, to ride the far end of a column of bags.
    dialog.flat = DialogCheck(dialog.check, false, L["BAR_KEY_RING_FLAT"], function(self)
        ns.db.keyRingFlat = self:GetChecked() and true or false
        if not ns.db.keyRingFlat then ns.db.keyRingSnap = false end
        Save()
    end)
    -- The key ring off the band only: its own cut of art.
    dialog.art = DialogCheck(dialog.flat, false, HUD_EDIT_MODE_SETTING_ACTION_BAR_HIDE_BAR_ART or "Hide Bar Art",
        function(self)
            ns.db.keyRingArtHidden = self:GetChecked() and true or false
            Save()
        end)
    dialog.reset = B.EditDialogReset(dialog, function()
        ns.db[dialog.el.posKey] = nil
        if dialog.el == KEYRING then ns.db.keyRingSnap, ns.db.keyRingFlat = false, false end
        Save()
    end)
    dialog:SetScript("OnShow", RefreshDialog)
    dialog:SetScript("OnHide", function()
        local home = dialog.el and dialog.el.home
        if home then home.handle.Dress("editmode-actionbar-highlight") end
    end)
    return dialog
end

------------------------------------------------------------------ homes

local HANDLE_TIP = { anchor = "ANCHOR_TOP", text = function(self) return self.el.label end, r = 1, g = 1, b = 1, lines = {
    { L["BAR_DRAG_OFF_THE_BAR_TO"], 1, 0.82, 0 },
    { L["BAR_CLICK_TO_HIDE_IT_OR"], 1, 0.82, 0 },
} }

local function Undrag()
    LATENCY.dragged, KEYRING.dragged = false, false
end

local function DragStart(handle)
    local home = handle.el.home
    if InCombatLockdown() and home:IsProtected() then return end
    handle.Dress("editmode-actionbar-selected")
    handle.el.moving, handle.el.dragged = true, true
    home:StartMoving()
end

-- A frame's point on screen (its edges in effective units).
local function PointAt(frame, point)
    local l, r, t, b = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
    if not (l and r and t and b) then return nil end
    local k = frame:GetEffectiveScale()
    local x = point:find("LEFT") and l or point:find("RIGHT") and r or (l + r) / 2
    local y = point:find("TOP") and t or point:find("BOTTOM") and b or (t + b) / 2
    return x * k, y * k
end

-- The flat key ring dropped by a column of bags' far end.
local function NearColumn(el, home)
    if not Flat(el) then return false end
    local frame, point, relPoint = B.BagsFarEnd()
    if not frame then return false end
    local hx, hy = PointAt(home, point)
    local fx, fy = PointAt(frame, relPoint)
    if not (hx and fx) then return false end
    local reach = SNAP_REACH * UIParent:GetEffectiveScale()
    return math.abs(hx - fx) < reach and math.abs(hy - fy) < reach
end

-- Read before the stop: StopMovingOrSizing drops the anchors of a frame others hang on (the key ring on its home).
local function DragStop(handle)
    local el = handle.el
    if not el.moving then return end
    local home = el.home
    local left, bottom = home:GetLeft(), home:GetBottom()
    local spot = BandSpot(el)
    local near = spot and B.NearBandSlot(home, spot, 0, "BOTTOMLEFT")
    local column = not near and NearColumn(el, home)
    home:StopMovingOrSizing()
    el.moving = false
    ns.Sched.NextFrame("band.sectionUndrag", Undrag)
    handle.Dress("editmode-actionbar-highlight")
    local place = (not near and not column and left and bottom)
        and { point = "BOTTOMLEFT", relPoint = "BOTTOMLEFT", x = left, y = bottom }
    ns.db[el.posKey] = place or nil
    if el == KEYRING then ns.db.keyRingSnap = column and true or false end
    Save()
end

local function MouseUp(handle, button)
    local el = handle.el
    if button == "RightButton" then
        ns.db[el.posKey] = nil
        if el == KEYRING then ns.db.keyRingSnap, ns.db.keyRingFlat = false, false end
        Save()
        return
    end
    -- The release ending a drag is not a click.
    if el.moving or el.dragged then return end
    ns.EditMode.TakePick()
    local d = Dialog()
    -- The dialog moving from one piece to the other: the first one's box back to the plain look.
    local was = d.el and d.el.home
    if was and was ~= el.home and was.handle then was.handle.Dress("editmode-actionbar-highlight") end
    d.el = el
    handle.Dress("editmode-actionbar-selected")
    ns.SetPointOnce(d, "BOTTOM", el.home, "TOP", 0, 40)
    d:Show()
    RefreshDialog()
end

local function Home(el)
    if el.home then return el.home end
    local home = CreateFrame("Frame", nil, B.art)
    home:SetClampedToScreen(true)
    home:SetMovable(true)
    home.art = home:CreateTexture(nil, "BACKGROUND")
    if el.cap > 0 then home.cap = home:CreateTexture(nil, "BACKGROUND") end
    if el == LATENCY then home.tube = B.MakeTube(home) end
    local handle = B.SelectionHandle(home)
    handle.el = el
    handle:SetScript("OnDragStart", DragStart)
    handle:SetScript("OnDragStop", DragStop)
    handle:SetScript("OnMouseUp", MouseUp)
    ns.AttachTip(handle, HANDLE_TIP)
    home.handle = handle
    el.home = home
    return home
end

-- A cut of the section sheet across the home from x (u0 > u1 mirrors it), turned as the home.
local TURNED_RUN = { tint = ns.BRONZE_SOFT, point = "TOPLEFT", show = true }
local function Cut(home, tex, x, width, u0, u1, turn)
    local l, r, t, b = u0 / 256, u1 / 256, SHEET.band[1], SHEET.band[2]
    if turn == "cw" then
        RUN[1], RUN[2], RUN[3], RUN[4], RUN[5], RUN[6], RUN[7], RUN[8] = l, b, r, b, l, t, r, t
        ns.Dress(tex, SHEET.key, TURNED_RUN, home, 0, -x, BAND_H, width, RUN)
    elseif turn == "ccw" then
        RUN[1], RUN[2], RUN[3], RUN[4], RUN[5], RUN[6], RUN[7], RUN[8] = r, t, l, t, r, b, l, b
        ns.Dress(tex, SHEET.key, BAND_RUN, home, 0, x, BAND_H, width, RUN)
    else
        RUN[1], RUN[2], RUN[3], RUN[4], RUN[5], RUN[6], RUN[7], RUN[8] = l, r, t, b, nil, nil, nil, nil
        ns.Dress(tex, SHEET.key, BAND_RUN, home, x, 0, width, BAND_H, RUN)
    end
end

-- On the band over its piece of the section (the band draws the art), or alone at its place in its own cut; the key
-- ring flat, or riding a column's far end.
local function Place(el, plan, level)
    local pos = not Hidden(el) and ns.db[el.posKey] or nil
    if pos ~= nil and not ns.ValidPlace(pos) then
        ns.db[el.posKey], pos = nil, nil
    end
    local snapped = not Hidden(el) and Snapped(el)
    local x, w = OnBand(el, plan)
    if (not pos and not x and not snapped) or (el == KEYRING and not B.KeyButton()) then
        if el.home then el.home:Hide() end
        return false
    end
    local home = Home(el)
    -- Riding the bags' floor: under it, so the floor's end post covers the cut's own.
    ns.SetLevelIf(home, math.max(0, level - (snapped and 2 or 1)))
    local left   -- the sheet's u at the home's left edge
    local turn, scale = nil, 1
    -- No art: the home is the key itself (across too, so the key centres on the bags at any size), and against the bags
    -- it stands as close as they stand to each other.
    local bare, cross = Bare(el), BAND_H
    if pos or snapped then
        left = el.u0 - el.cap
        local long = el.cap + el.u1 - el.u0
        if bare then
            cross = B.KEYRING_H + 2 * KEY_PAD
            long = B.KEYRING_W + 2 * KEY_PAD
            left = B.TAIL_SLOT - long / 2
        end
        local frame, point, relPoint, rowScale, dx
        if snapped then
            frame, point, relPoint, rowScale, dx = B.BagsFarEnd()
            turn, scale = B.BagsColumn(), rowScale or 1
            if bare and dx and dx ~= 0 then dx = dx > 0 and TIGHT_GAP or -TIGHT_GAP end
        elseif Flat(el) then
            turn = "cw"
        end
        ns.SetScaleIf(home, scale)
        if turn then home:SetSize(cross, long) else home:SetSize(long, cross) end
        if snapped and not el.moving then
            ns.SetPointIf(home, point, frame, relPoint, dx or 0, 0)
        elseif not el.moving then
            ns.SetPointOnce(home, pos.point, UIParent, pos.relPoint, pos.x, pos.y)
        end
        if Bare(el) then
            home.art:Hide()
            if home.cap then home.cap:Hide() end
        else
            Cut(home, home.art, el.cap, el.u1 - el.u0, el.u0, el.u1, turn)
            if home.cap then Cut(home, home.cap, 0, el.cap, el.u1, el.u1 - el.cap, turn) end
        end
    else
        left = plan.tailU0 + x - plan.tailStart
        ns.SetScaleIf(home, 1)
        home:SetSize(w, BAND_H)
        if not ns.IsAt(home, "BOTTOMLEFT", B.art, "BOTTOMLEFT", x, 0) then
            ns.SetPointOnce(home, "BOTTOMLEFT", B.art, "BOTTOMLEFT", x, 0)
        end
        home.art:Hide()
        if home.cap then home.cap:Hide() end
    end
    if not home:IsShown() then home:Show() end
    if el == LATENCY then
        -- On the band the band's own tube shows (BandLatency).
        B.PlaceTube(home.tube, home, pos and (B.TAIL_WINDOW - left) or nil)
    else
        local keyRing = B.KeyButton()
        -- Retail's reagent bag squeezed in as a bag: a bag's height, its frame.
        local squished = keyRing ~= KeyRingButton and B.ReagentSquished()
        local tall = squished and B.Bag().size or B.KEYRING_H
        -- The key's middle on the upright cut, turned with the home.
        local px, py = B.TAIL_SLOT - left, bare and cross / 2 or KEY_Y
        if turn then
            Seat(keyRing, scale, tall, B.KEYRING_W, level)
        else
            Seat(keyRing, scale, B.KEYRING_W, tall, level)
        end
        if turn == "cw" then
            keyRing:SetPoint("CENTER", home, "TOPLEFT", py, -px)
        elseif turn == "ccw" then
            keyRing:SetPoint("CENTER", home, "BOTTOMLEFT", cross - py, px)
        else
            keyRing:SetPoint("CENTER", home, "BOTTOMLEFT", px, py)
        end
        if squished then
            ns.UnskinKeyRing(keyRing)
            ns.SkinBagButton(keyRing, tall, false, false, B.KEYRING_W)
        else
            ns.UnskinBagButton(keyRing)
            ns.SkinKeyRing(keyRing, turn)
        end
        -- Its edit mode box on the key itself, not the cut's full height.
        local handle = home.handle
        if handle and not ns.IsAt(handle, "TOPLEFT", keyRing, "TOPLEFT", 0, 0) then
            handle:ClearAllPoints()
            handle:SetAllPoints(keyRing)
        end
    end
    return true
end

-- The key ring riding a moved bag row, and its home there: faded with the row (BandBagsShow).
function B.KeyRingRides() return Snapped(KEYRING) and true or false end
function B.KeyRingHome() return KEYRING.home end

-- Every bag layout, after the row (which takes the key ring only when it has no place here).
local watched = false
function B.LaySection(level)
    if not ns.db then return end
    local plan = CurrentPlan()
    if KeyRingButton and not watched then
        watched = true
        ns.Sched.OnVisible(KeyRingButton, "band.keyRingSeen", KeyRingSeen)
        keyJob = ns.Sched.Attach(KeyRingButton, { name = "band.keyRingOff", every = 0.1, fn = HideAgain, awake = false })
    end
    Place(LATENCY, plan, level)
    local placed = Place(KEYRING, plan, level)
    KeyRingShown(not Hidden(KEYRING) and placed)
    -- Retail's reagent bag as the piece: faded, never hidden (the game shows and hides it with the bags).
    local key = B.KeyButton()
    if key and key ~= KeyRingButton then B.ReagentSeen(key, not Hidden(KEYRING) and placed) end
end

-- Our edit mode boxes (micro menu, latency bar, key ring) up while edit mode is open, their dialogs shut after or once a
-- piece of the game's is picked (BandWatch's edit beat).
-- A group's level moves with its buttons' and takes the box along: set again as it shows.
local function ShowHandle(home, want)
    local handle = home and home.handle
    if not handle or handle:IsShown() == want then return end
    if want then handle:SetFrameLevel(1010) end
    handle:SetShown(want)
end

function B.ShowEditHandles(art, editing)
    local micro = art and art.microHome
    ShowHandle(micro, editing)
    for _, el in ipairs(ELEMENTS) do
        if el.home then ShowHandle(el.home, editing and el.home:IsShown()) end
    end
    if editing and not ns.EditMode.GamePicked() then return end
    if art and art.microDialog and art.microDialog:IsShown() then art.microDialog:Hide() end
    if dialog and dialog:IsShown() then dialog:Hide() end
    -- The gryphons' dialog; out of edit mode our Windows edit mode shuts it itself.
    if editing and ns.windowEdit then ns.windowEdit.HideDialog() end
end
