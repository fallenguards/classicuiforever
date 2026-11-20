local _, ns = ...
local B = ns.band

-- Action bars on the band: button rows at their 1.x spots, page arrows, pet and stance row, right columns, bars 6-8.

local ART_W, BUTTON_PITCH, PAGE_ROOM = B.ART_W, B.BUTTON_PITCH, B.PAGE_ROOM
local BUTTON_SIZE = 36
-- Era's small bars (EditModePresetLayouts): 30 px buttons, stance and possess at 41.5 and 7 apart, pet at 71 and 8 apart.
local STANCE_X, PET_X, SMALL_BUTTON = 41.5, 71, 30
local STANCE_PITCH, PET_PITCH = 37, 38
local SIDE_BAR_X, SIDE_BAR_Y, SIDE_BAR_GAP = -2, 98, 6   -- right bars hang from the bottom right corner
local PAGE_X, PAGE_UP_Y, PAGE_DOWN_Y = 522, -22, -42
local PAGE_OVER_BUTTONS = 2
-- Modern page arrows: the game's spot (MainActionBar.xml), 4 left of bar 1's first button and 9 up, at its 17 x 14.
local MODERN_X, MODERN_Y, MODERN_W, MODERN_H, MODERN_STEP = 4, 9, 17, 14, 10
local ROW_Y = B.ROW_Y
local Remember, BarSetting, BarVertical, BarRows = B.Remember, B.BarSetting, B.BarVertical, B.BarRows
local IconScale, BandScale, BandNow, MatchScale = B.IconScale, B.BandScale, B.BandNow, B.MatchScale
local CurrentPlan = B.CurrentPlan

-- Which row frame each bar's buttons hang on, and whether that row hangs on the bar or the band (or screen corner).
local rowOf = {}
B.rowOf = rowOf

-- Each button stands in a slot of ours under its bar, moved there once by a secure snippet: the client re-lays and
-- rescales its own containers (layout applies, stance count changes, in fights too) and never touches ours.
local slotOf = setmetatable({}, { __mode = "k" })
local mover
local MOVE = [[
    local button, home = self:GetFrameRef("button"), self:GetFrameRef("home")
    button:SetParent(home)
    button:SetFrameLevel(home:GetFrameLevel() + 1)
    button:ClearAllPoints()
    button:SetPoint("CENTER", home, "CENTER", 0, 0)
]]

local function Move(button, home)
    if not mover then mover = CreateFrame("Frame", nil, UIParent, "SecureHandlerBaseTemplate") end
    mover:SetFrameRef("button", button)
    mover:SetFrameRef("home", home)
    local ok, err = pcall(mover.Execute, mover, MOVE)
    if not ok then geterrorhandler()(err) end
end

-- Each bar's slots hang on a holder of ours on the screen, never on the bar: the client rescales, moves and hides its
-- bar frames (edit mode re-lays them on every grid show, in fights too). The holder copies the bar's show rules.
local holderOf, driverOf = {}, {}
-- Era's backing under the stance, possess and pet rows: a child of the bar's holder, shown and faded with it.
local backingOf = {}
local VISIBILITY = { InCombat = "[combat] show; hide", OutOfCombat = "[combat] hide; show" }

local function Driver(bar)
    if bar == PetActionBar then return "[petbattle][overridebar][vehicleui][possessbar] hide; [@pet,exists] show; hide" end
    if bar == PossessActionBar then return "[possessbar] show; hide" end
    if bar == StanceBar and ns.db and ns.db.hideStanceBar then return "hide" end
    local main = bar == ns.GetMainBar()
    local on = main or bar.isShownExternal
    if on == nil then on = bar:IsShown() end
    if not on or bar.visibility == "Hidden" then return "hide" end
    local lead = (main or bar == StanceBar) and "[petbattle][overridebar][vehicleui] hide; " or "[petbattle] hide; "
    return lead .. (VISIBILITY[bar.visibility] or "show")
end

-- Out of combat: strata and show rules follow the bar's as the layout runs.
-- Bars whose own mouse we turned off (given back on the band's hand-back).
local mouseOff = {}

local function Holder(bar)
    local holder = holderOf[bar]
    if not holder then
        -- Its slots hang on the rows, so its own box is a pixel off the screen's corner, out of /fstack's list (#283).
        holder = CreateFrame("Frame", nil, UIParent, "SecureHandlerStateTemplate")
        holder:SetSize(1, 1)
        holder:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", 0, 0)
        holderOf[bar] = holder
    end
    -- At the bar's own alpha, times its Faded Opacity while faded (Bar/BarFade.lua).
    holder:SetAlpha(bar:GetAlpha() * (B.FadeNow and B.FadeNow(bar) or 1))
    if not InCombatLockdown() then
        -- A spell drag lifts the bar to TOOLTIP for the drop: never copied, and its frame takes no mouse, or the lifted empty
        -- frame over our slots eats the drop (bar 1 is mouse-enabled).
        local strata = bar:GetFrameStrata()
        if strata ~= "TOOLTIP" then ns.SetStrataIf(holder, strata) end
        if bar:IsMouseEnabled() then
            bar:EnableMouse(false)
            mouseOff[bar] = true
        end
        local driver = Driver(bar)
        if driverOf[bar] ~= driver then
            driverOf[bar] = driver
            RegisterStateDriver(holder, "visibility", driver)
        end
    end
    return holder
end

-- Read by the theme layers: a bar change restyles only what stands in its bar's holder.
function B.HolderOf(bar) return bar and holderOf[bar] end

-- The button's slot, the button moved into it first; out of combat only, as the layout runs. Explicitly protected:
-- a snippet's SetParent takes no other frame as the new parent.
local function Slot(button, bar)
    -- Neither in our slot nor in its own container: another addon moved it onto its bar, and it stays there.
    local parent = button:GetParent()
    if parent ~= slotOf[button] and parent ~= button.container then return nil end
    local holder = Holder(bar)
    local slot = slotOf[button]
    if not slot then
        slot = CreateFrame("Frame", nil, holder, "SecureFrameTemplate")
        slot:SetSize(button:GetWidth(), button:GetHeight())
        slotOf[button] = slot
    elseif slot:GetParent() ~= holder then
        slot:SetParent(holder)
    end
    if button:GetParent() ~= slot then Move(button, slot) end
    -- The toggled border over the client's frame art: both on OVERLAY 0, the art could draw last and cut its top and
    -- left edges (bars 2 and 3's AddRow art hangs from the top left).
    local checked = button.GetCheckedTexture and button:GetCheckedTexture()
    if checked then
        local layer, sub = checked:GetDrawLayer()
        if ns.AnySecret(layer, sub) or layer ~= "OVERLAY" or sub ~= 1 then checked:SetDrawLayer("OVERLAY", 1) end
    end
    return slot
end

-- Band off (out of combat): every button still in our slot back in the client's container, where its own layout has it.
-- One another addon moved onto its own bar is that addon's: sent "home" under the client's bar it parked hidden, every
-- such bar went blank. Plain calls: the containers are not explicitly protected, so a snippet cannot parent to them.
function B.ButtonsHome()
    for button, slot in pairs(slotOf) do
        local container = button.container
        if container and button:GetParent() == slot then
            button:SetParent(container)
            button:SetFrameLevel(container:GetFrameLevel() + 1)
            ns.SetPointOnce(button, "CENTER", container, "CENTER", 0, 0)
            local checked = button.GetCheckedTexture and button:GetCheckedTexture()
            if checked then checked:SetDrawLayer("OVERLAY", 0) end
        end
    end
    for bar in pairs(mouseOff) do bar:EnableMouse(true) end
    wipe(mouseOff)
    for _, back in pairs(backingOf) do back:Hide() end
end

-- A row hangs on the band while its buttons stand on it, else on the screen (a column at the screen edge, scaled by bar 1's size).
local function Row(index, parent)
    local art = B.art
    local row = art.rows[index]
    if not row then
        row = CreateFrame("Frame", nil, art)
        row:SetSize(1, 1)
        art.rows[index] = row
    end
    parent = parent or art
    if row:GetParent() ~= parent then row:SetParent(parent) end
    return row
end

-- One bar's buttons in a 1.x row or column: containers on a scaled row frame, so buttons come out 36 px (30 on pet/stance),
-- 6 apart and the bar's Icon Padding more.
local function LayoutButtons(bar, rowIndex, point, relTo, relPoint, x, y, vertical, pitch, target, origin, rows)
    -- Taken by another addon since our last full pass: its buttons are that addon's from now on (the band stands down
    -- at the next pass; a watch pass in between pulled them back and the hand-back parked them hidden).
    if not bar or not bar.actionButtons or ns.BarsTaken() then return end
    local art = B.art
    local first = bar.actionButtons[1]
    local size = first and first:GetWidth() or 45
    if not size or size == 0 then size = 45 end
    local scale = (target or BUTTON_SIZE) / size
    local step = ((pitch or BUTTON_PITCH) + B.PadGap(bar, target or BUTTON_SIZE)) / scale
    -- Icon Size rides on the slots, as the client puts it on its containers; the bar keeps scale 1
    -- (edit mode boxes the frame and would count the size twice), and its rectangle is what is drawn.
    -- A bar the game holds keeps its own frame (B.GameHolds).
    local icon = IconScale(bar)
    local held = B.GameHolds(bar)
    if not held then MatchScale(bar, 1) end
    local band = BandNow()
    -- A row on the band is placed in band pixels, a column off it at its own size; the step is read on the slots.
    origin = origin or band
    if origin <= 0 then origin = 1 end
    local onBand = relTo == nil or relTo == art
    local row = Row(rowIndex, onBand and art or UIParent)
    row:SetScale(onBand and (origin / band) or origin)
    ns.SetPointOnce(row, point, relTo, relPoint, x, y)
    local hung = rowOf[bar]
    if not hung then
        hung = {}
        rowOf[bar] = hung
    end
    hung.row, hung.onBar, hung.vertical = row, relTo == bar, vertical and true or false
    -- The rectangle covers the slots the bar is set to (or the buttons it has). Folded rows stack upward
    -- when horizontal, rightward when vertical.
    local slots = BarSetting(bar, "NumIcons")
    rows = math.max(1, rows or 1)
    local shown = (slots and slots > 0) and math.min(slots, #bar.actionButtons) or #bar.actionButtons
    local per = math.max(1, math.ceil(shown / rows))
    local count = 0
    -- Over the gryphons and over this bar's own frame, which takes the mouse (edit mode lifts a bar's level and the
    -- stance and pet bars stand higher than bar 1): a slot under its bar hid its button from the mouse.
    local level = math.max(B.ButtonLevel(), bar:GetFrameLevel() + 2)
    -- Only on change: the pass runs on every stance change, and blind writes to every slot missed a frame.
    for i, button in ipairs(bar.actionButtons) do
        count = i
        local slot = Slot(button, bar)
        if slot then
            ns.SetLevelIf(slot, level)
            ns.SetScaleIf(slot, scale * icon)
            local along, across = (i - 1) % per, math.floor((i - 1) / per)
            if vertical then
                ns.SetPointIf(slot, "TOPLEFT", row, "TOPLEFT", across * step, -along * step)
            else
                ns.SetPointIf(slot, "BOTTOMLEFT", row, "BOTTOMLEFT", along * step, across * step)
            end
        end
    end
    -- Bar rectangle = its buttons, in whole pixels, set only on change: a size change makes the client
    -- re-lay the bar and call us back, and sub-pixel drift each pass walked the buttons.
    if slots and slots > 0 then count = math.min(count, slots) end
    if count > 0 then
        local slot = math.floor((target or BUTTON_SIZE) * icon + 0.5)
        local lines = math.ceil(count / per)
        local along = math.floor((math.min(count, per) - 1) * (step * scale * icon) + slot + 0.5)
        local thick = math.floor((lines - 1) * (step * scale * icon) + slot + 0.5)
        local wide, tall = along, thick
        if vertical then wide, tall = thick, along end
        if not held and (math.abs((bar:GetWidth() or 0) - wide) > 0.5 or math.abs((bar:GetHeight() or 0) - tall) > 0.5) then
            Remember(bar)
            bar:SetSize(wide, tall)
        end
        -- Edit mode's box stays on the bar: the client clamps the bar by the gap between them, and one hung
        -- elsewhere shoved the frame off its anchor. Action Bar 1's also covers the page arrows, which belong to it.
        local selection = bar.Selection
        if selection and selection.SetPoint and not InCombatLockdown() then
            local pages = 0
            if bar == ns.GetMainBar() and not vertical and not ns.barMoved
                and BarSetting(bar, "HideBarScrolling") ~= 1 then
                pages = PAGE_ROOM * band
            end
            if hung.boxed ~= pages then
                hung.boxed = pages
                selection:ClearAllPoints()
                selection:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
                selection:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", pages, 0)
            end
        end
    end
end
B.LayoutButtons = LayoutButtons

-- A bar the player moved, turned or folded is laid out on itself, at its own size and settings.
local function LayoutOnOwnBar(bar, rowIndex, vertical, rows, pitch, target)
    local own = IconScale(bar)
    if vertical then
        LayoutButtons(bar, rowIndex, "TOPLEFT", bar, "TOPLEFT", 0, 0, true, pitch, target, own, rows)
    else
        LayoutButtons(bar, rowIndex, "BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0, false, pitch, target, own, rows)
    end
end
B.LayoutOnOwnBar = LayoutOnOwnBar

-- Bars whose own click we turned off while held (the client's stance bar takes clicks), to hand back after.
local clickHeld = setmetatable({}, { __mode = "k" })
local motionHeld = setmetatable({}, { __mode = "k" })

-- A default bar's frame is carried off while its buttons stay (fights; the game's own re-stacks outside edit mode): its
-- box would drag an unseen frame and a frame that takes clicks (the stance bar, level 70) lands over bar 2. Both take no
-- clicks while held; player-placed bars stay as they are. Set at fight start (still allowed), fight end and each pass.
function B.HoldBandBoxes(held)
    local main = ns.GetMainBar()
    local locked = InCombatLockdown()
    for bar, hung in pairs(rowOf) do
        local onBand
        if bar == main then onBand = not ns.barMoved else onBand = not hung.onBar end
        local selection = bar.Selection
        if selection and selection.EnableMouse and not (selection.IsProtected and selection:IsProtected() and locked) then
            local want = not (held and onBand)
            if selection:IsMouseEnabled() ~= want then selection:EnableMouse(want) end
        end
        if bar.SetMouseClickEnabled and not (bar:IsProtected() and locked) then
            if held and onBand then
                if bar:IsMouseClickEnabled() then
                    bar:SetMouseClickEnabled(false)
                    clickHeld[bar] = true
                end
                -- Motion too: held outside fights now, a frame taking it over the band would cover the buttons' tooltips.
                if bar:IsMouseMotionEnabled() then
                    bar:SetMouseMotionEnabled(false)
                    motionHeld[bar] = true
                end
            elseif not held then
                if clickHeld[bar] then
                    bar:SetMouseClickEnabled(true)
                    clickHeld[bar] = nil
                end
                if motionHeld[bar] then
                    bar:SetMouseMotionEnabled(true)
                    motionHeld[bar] = nil
                end
            end
        end
    end
end

-- Boxes back on their bars, as the client has them.
function B.RestoreSelections()
    for bar in pairs(clickHeld) do
        if not (bar:IsProtected() and InCombatLockdown()) then
            bar:SetMouseClickEnabled(true)
            clickHeld[bar] = nil
        end
    end
    for bar in pairs(motionHeld) do
        if not (bar:IsProtected() and InCombatLockdown()) then
            bar:SetMouseMotionEnabled(true)
            motionHeld[bar] = nil
        end
    end
    for bar, hung in pairs(rowOf) do
        if hung.boxed and bar.Selection then
            hung.boxed = nil
            bar.Selection:ClearAllPoints()
            bar.Selection:SetAllPoints(bar)
            if not bar.Selection:IsMouseEnabled() then bar.Selection:EnableMouse(true) end
        end
    end
end

-- Micro and bag buttons stand over the main bar frame, which takes the mouse and edit mode can raise to level 50.
function B.ButtonLevel()
    local bar = ns.GetMainBar()
    return math.max(B.art:GetFrameLevel() + 20, (bar and bar:GetFrameLevel() or 0) + 10)
end

local function Anchor(frame, point, relPoint, x, y, scale)
    -- A locked frame is the client's to move in a fight.
    if not frame or (InCombatLockdown() and frame:IsProtected()) then return end
    Remember(frame)
    ns.SetPointOnce(frame, point, B.art, relPoint, x, y)
    if scale then ns.SetScaleIf(frame, scale) end
end
B.Anchor = Anchor

local function PlaceArrow(button, w, h, hitX, hitY, rel, relPoint, x, y)
    button:SetSize(w, h)
    button:SetHitRectInsets(hitX, hitX, hitY, hitY)
    ns.SetPointOnce(button, "CENTER", rel, relPoint, x, y)
end

-- Page arrows (w x h, hit insets) centred on rel at x/upY/downY; page number text in font at textX, textY.
function B.PlacePageArrows(pn, w, h, hitX, hitY, rel, relPoint, x, upY, downY, font, textX, textY)
    if pn.UpButton then PlaceArrow(pn.UpButton, w, h, hitX, hitY, rel, relPoint, x, upY) end
    if pn.DownButton then PlaceArrow(pn.DownButton, w, h, hitX, hitY, rel, relPoint, x, downY) end
    if pn.Text then
        pn.Text:SetFontObject(font)
        ns.SetPointOnce(pn.Text, "CENTER", rel, relPoint, textX, textY)
    end
end

-- Page number and arrows on the band corner, 32 px like 1.x, number beside the arrows.
function B.LayoutPageArrows(bar)
    local pn = bar.ActionBarPageNumber
    if not pn then return end
    local art = B.art
    local pageX = CurrentPlan().base + (PAGE_X - ART_W / 2)
    local midY = (PAGE_UP_Y + PAGE_DOWN_Y) / 2
    pn:SetScale(BandNow())
    -- Over the band's buttons and gryphons, in their layer: a window or the full map over the bars covers these too.
    ns.SetStrataIf(pn, "MEDIUM")
    ns.SetLevelIf(pn, math.max(B.ButtonLevel(), B.CapLevel()) + PAGE_OVER_BUTTONS)
    -- Hide Bar Scrolling: the client hides them for it.
    pn:SetShown(BarSetting(bar, "HideBarScrolling") ~= 1)
    if B.ModernPages() then
        ns.SetPointIf(pn, "BOTTOMRIGHT", art, "BOTTOMLEFT", CurrentPlan().bar1X - MODERN_X, ROW_Y + MODERN_Y)
        ns.SetSizeIf(pn, MODERN_W, MODERN_H * 2 + MODERN_STEP)
        B.PlacePageArrows(pn, MODERN_W, MODERN_H, 0, 0, pn, "CENTER", 0, MODERN_STEP, -MODERN_STEP, "GameFontNormal", -1, 0)
        return
    end
    ns.SetPointOnce(pn, "CENTER", art, "TOPLEFT", pageX, midY)
    pn:SetSize(32, 76)
    B.PlacePageArrows(pn, 32, 32, 6, 7, art, "TOPLEFT", pageX, PAGE_UP_Y, PAGE_DOWN_Y, "GameFontNormalSmall",
        pageX + 20, midY + 0.5)
end

-- A bar the band lays on its 1.x row: at its default place, across, one row.
local function OnBandSpot(bar)
    return not (B.SystemMoved(bar) or BarVertical(bar) == true or BarRows(bar) > 1)
end

-- A default-placed bar gets its 1.x row; one the player moved, turned or folded is laid out on itself.
local function BandRow(bar, rowIndex, x, y, pitch, target)
    if not bar then return false end
    if not OnBandSpot(bar) then
        LayoutOnOwnBar(bar, rowIndex, BarVertical(bar) == true, BarRows(bar), pitch, target)
        return false
    end
    local band = BandNow()
    if not B.GameHolds(bar) then Anchor(bar, "BOTTOMLEFT", "BOTTOMLEFT", x * band, y * band, 1) end
    LayoutButtons(bar, rowIndex, "BOTTOMLEFT", B.art, "BOTTOMLEFT", x, y, false, pitch, target)
    return true
end
B.BandRow = BandRow

-- The stance and pet row's lift to its spot over bar 2 when it sits lower (band px).
local rowRaise = 0
-- The totem bar stands on the stance row (LayTotem): the classic chat stands over it too.
local totemHeld = false

-- The pet and stance row's top on the band (UIParent units), shown or not and as over bar 2: the classic chat stands over it.
function B.PetRowTop()
    local top
    for _, bar in ipairs({ StanceBar, PetActionBar, PossessActionBar }) do
        local first, hung = bar and bar.actionButtons and bar.actionButtons[1], rowOf[bar]
        local slot = first and hung and not hung.onBar and slotOf[first]
        local t = slot and slot:GetTop()
        if t then
            t = (t * slot:GetEffectiveScale() + rowRaise * B.art:GetEffectiveScale()) / UIParent:GetEffectiveScale()
            if not top or t > top then top = t end
        end
    end
    local totem = _G.MultiCastActionBarFrame
    local t = totemHeld and totem and totem:IsShown() and totem:GetTop()
    if t then
        t = t * totem:GetEffectiveScale() / UIParent:GetEffectiveScale()
        if not top or t > top then top = t end
    end
    return top
end

-- Era's sheets (StanceBar, PossessActionBar and PetActionBar.xml), in a 30 px button's units from the first one's corner.
local STANCE_LEFT = { 0, 0.734375, 0, 0.296875 }
local STANCE_RIGHT = { 0.328125, 1, 0.3125, 0.6015625 }
local STANCE_MIDDLE = { 0, 1, 0, 1 }
local PET_LEFT = { 0, 1, 0.015625, 0.359375 }
local PET_RIGHT = { 0, 0.71875, 0.375, 0.71875 }

local function Backing(bar)
    local back = backingOf[bar]
    if back or InCombatLockdown() then return back end
    local holder = holderOf[bar]
    if not holder then return nil end
    back = CreateFrame("Frame", nil, holder)
    back:SetSize(1, 1)
    back.left = back:CreateTexture(nil, "BACKGROUND")
    -- Over the left piece, which a single form's right end overlaps.
    back.right = back:CreateTexture(nil, "BORDER")
    -- The theme's Action bars part, as the band's own art: it hangs on our holder, which the part walk reads as Other windows.
    ns.PinThemePart(back.left, "themePartBars")
    ns.PinThemePart(back.right, "themePartBars")
    back.middles = {}
    backingOf[bar] = back
    return back
end

-- The stance bar's runs as Era sets them by its form count: the right end 12 in for one, 1 past the left for two, else
-- past a 37 px middle per form after the second.
local function DressStance(back, forms, possess)
    local run = B.BAND_RUN
    ns.Dress(back.left, "stanceBar", run, back, -11, -3, 47, 38, STANCE_LEFT)
    local rightX = 36 + 37 * math.max(0, forms - 2)
    if possess then rightX = 36 elseif forms <= 1 then rightX = 1 elseif forms == 2 then rightX = 37 end
    ns.Dress(back.right, "stanceBar", run, back, rightX, -3, 43, 38, STANCE_RIGHT)
    local middles = possess and 0 or math.max(0, forms - 2)
    for i = 1, middles do
        local tex = back.middles[i]
        if not tex then
            tex = back:CreateTexture(nil, "BACKGROUND")
            ns.PinThemePart(tex, "themePartBars")
        end
        back.middles[i] = tex
        ns.Dress(tex, "stanceBarMiddle", run, back, 36 + 37 * (i - 1), -3, 37, 38, STANCE_MIDDLE)
    end
    return middles
end

-- Drawn while its bar stands at its own spot on a free band top at its default size and spacing, bar 1's art up.
local function DrawBacking(bar, show)
    local back = backingOf[bar]
    local hung = rowOf[bar]
    if show and hung and not hung.onBar then back = Backing(bar) end
    if not (show and back and hung and not hung.onBar) then
        if back then back:Hide() end
        return
    end
    local forms = bar == StanceBar and GetNumShapeshiftForms() or 0
    ns.SetScaleIf(back, IconScale(bar))
    ns.SetPointIf(back, "BOTTOMLEFT", hung.row, "BOTTOMLEFT", 0, 0)
    ns.SetLevelIf(back, math.max(1, B.ButtonLevel() - 1))
    if back.forms ~= forms then
        back.forms = forms
        local middles = 0
        if bar == PetActionBar then
            ns.Dress(back.left, "petBar", B.BAND_RUN, back, -35, -3, 256, 44, PET_LEFT)
            ns.Dress(back.right, "petBar", B.BAND_RUN, back, 221, -3, 184, 44, PET_RIGHT)
        else
            middles = DressStance(back, forms, bar == PossessActionBar)
        end
        for i = middles + 1, #back.middles do back.middles[i]:Hide() end
    end
    back:Show()
end

-- Its own spot and Era's look: what the client checks before it shows the art (ShouldShowBackgroundArt).
local function BackingFits(bar)
    local size = BarSetting(bar, "IconSize")
    return (size == nil or size == 100) and B.PadGap(bar, SMALL_BUTTON) == 0 and not B.BarBare(ns.GetMainBar())
end

-- A form learned or lost: the stance bar's backing takes the new count.
ns.EventFrame("UPDATE_SHAPESHIFT_FORMS", function()
    local back = backingOf[StanceBar]
    if back and back:IsShown() then DrawBacking(StanceBar, true) end
end)

local LEADS
-- Stance, then possess, from Era's spot; the pet bar at its own or past them. A bar larger than the band pushes the next
-- one out by its growth. Returns the pet bar's x, the row's right end and the first free x past the leads (band px), or
-- lays it at y when given.
local function PetRun(y, free)
    LEADS = LEADS or { StanceBar, PossessActionBar }
    local x, ends = STANCE_X, STANCE_X
    for _, bar in ipairs(LEADS) do
        local pinned = OnBandSpot(bar)
        if y then
            pinned = BandRow(bar, bar == StanceBar and 4 or 5, x, y, STANCE_PITCH, SMALL_BUTTON)
            DrawBacking(bar, pinned and free and x == STANCE_X and BackingFits(bar))
        end
        if pinned and bar:IsShown() and bar.actionButtons then
            local grown = math.max(1, IconScale(bar) / BandScale())
            local step = (STANCE_PITCH + B.PadGap(bar, SMALL_BUTTON)) * grown
            local shown = bar == StanceBar and GetNumShapeshiftForms() or #bar.actionButtons
            ends = x + shown * step
            x = x + #bar.actionButtons * step + 8 * grown
        end
    end
    local petX = math.max(PET_X, x)
    local pet = PetActionBar
    if pet and pet:IsShown() and pet.actionButtons and OnBandSpot(pet) then
        local grown = math.max(1, IconScale(pet) / BandScale())
        ends = petX + #pet.actionButtons * (PET_PITCH + B.PadGap(pet, SMALL_BUTTON)) * grown
    end
    return petX, ends, x
end

-- Where the row's shown buttons end on the band (band px): bar 3 lifts the row only where it runs under them.
function B.PetRowEnd()
    local _, ends = PetRun()
    return ends
end

-- The totem bar on the stance row, where Wrath kept it: the game anchors it to bar 1's frame, which the band leaves to the
-- game while bar 1's buttons stand in our slots, so it landed somewhere new on each load and never at its edit mode box
-- (2026-11-20). Its frame's corner sits 3 under and left of its first button. One placed in edit mode keeps its spot.
local TOTEM_X, TOTEM_INSET = 30, 3
local function LayTotem(y, x)
    local totem = _G.MultiCastActionBarFrame
    totemHeld = false
    if not totem or B.SystemMoved(totem) then return end
    if InCombatLockdown() and totem:IsProtected() then return end
    local band = BandNow()
    Remember(totem)
    -- After a shown stance or possess bar, else at Era's stance spot.
    local left = x and x > STANCE_X and x - TOTEM_INSET or TOTEM_X
    ns.SetPointIf(totem, "BOTTOMLEFT", B.art, "BOTTOMLEFT", left * band, (y - TOTEM_INSET) * band)
    totemHeld = true
end

-- Stance (or possess) bar at the left, pet bar beside it. y: its foot (band px); high: its foot over bar 2; free: bar 2's
-- spot open, the row down on the band with Era's backing.
function B.LayoutPetRow(y, high, free)
    rowRaise = math.max(0, (high or y) - y)
    local petX, _, leadsEnd = PetRun(y, free)
    LayTotem(y, leadsEnd)
    if PetActionBar then
        -- Era's pet bar stands 1 under the stance bar, on its own only.
        local own = petX == PET_X
        local pinned = BandRow(PetActionBar, 6, petX, own and y - 1 or y, PET_PITCH, SMALL_BUTTON)
        DrawBacking(PetActionBar, pinned and free and own and BackingFits(PetActionBar))
    end
end

-- Bars 4 and 5 down the right edge. Buttons hang from the screen, not the bar: edit mode re-anchors right bars whenever
-- the room by the minimap changes (entering combat too) and the column jumped. A bar placed in edit mode keeps its spot.
local SIDE_COL_H = 12 * BUTTON_PITCH
-- Era's (its UpdateRightActionBarPositions): bar 4 on the right edge, its middle 35 under the screen's, bar 5 7 beside.
-- sideBarsEra off: 1.12's, from the bottom right corner 98 up (an install from before keeps it till the layout button).
local ERA_SIDE_Y, ERA_SIDE_GAP = -35, 7
local SIDE_COL_DRAWN = SIDE_COL_H - (BUTTON_PITCH - BUTTON_SIZE)

-- The column's top: the screen point it hangs from and its offset there, in the column's own units. gap: its Icon
-- Padding's px between buttons, the column that much taller each.
local function SideTop(icon, gap)
    local grown = 11 * (gap or 0)
    if ns.db.sideBarsEra then return "RIGHT", ERA_SIDE_Y / icon + (SIDE_COL_DRAWN + grown) / 2 end
    return "BOTTOMRIGHT", SIDE_BAR_Y + SIDE_COL_H + grown
end

-- dbVersion 27: an install from before keeps 1.12's spot.
function ns.KeepSideBarSpot()
    local db = ns.db
    if db.sideBarsEra == nil then db.sideBarsEra = false end
    for _, shot in pairs(type(db.profiles) == "table" and db.profiles or {}) do
        if type(shot) == "table" and shot.sideBarsEra == nil then shot.sideBarsEra = false end
    end
    db.dbVersion = 27
end

local function SideColumn(bar, rowIndex, x)
    if not bar then return false end
    local vertical, rows = BarVertical(bar) ~= false, BarRows(bar)
    if B.SystemMoved(bar) or not vertical or rows > 1 then
        LayoutOnOwnBar(bar, rowIndex, vertical, rows)
        return false
    end
    -- Frame starts at the first button and spans the buttons, so edit mode's box is the column itself.
    local icon = IconScale(bar)
    local relPoint, top = SideTop(icon, B.PadGap(bar))
    if not B.GameHolds(bar) then
        Remember(bar)
        ns.SetScaleIf(bar, 1)
        ns.SetPointIf(bar, "TOPRIGHT", UIParent, relPoint, x * icon, top * icon)
    end
    LayoutButtons(bar, rowIndex, "TOPLEFT", UIParent, relPoint, x - BUTTON_SIZE, top, true, nil, nil, icon)
    return true
end

function B.LayoutSideBars()
    local right, left = MultiBarRight, MultiBarLeft
    local rightPinned = SideColumn(right, 7, SIDE_BAR_X)
    local leftX = SIDE_BAR_X
    if rightPinned and right:IsShown() then
        -- Beside the first: its width in the second's pixels, less the gap.
        local ratio = IconScale(right) / IconScale(left)
        leftX = (SIDE_BAR_X - BUTTON_SIZE) * ratio - (ns.db.sideBarsEra and ERA_SIDE_GAP or SIDE_BAR_GAP)
    end
    SideColumn(left, 8, leftX)
end

-- Bars 6-8 are enabled in the game's Settings (Action Bars). Our toggle hides them; enabling any there turns the
-- toggle off. Never written: the client's apply is refused to addons (blocked). Faded and click-free, keybinds still work.
-- Bottom managed frames stand over the (emptied) micro menu, mid bar 1, and took its mouse: stood over the band instead.
local BOTTOM_MARGIN = 15

-- A shown frame's top in UIParent units, or 0.
local function TopOf(frame)
    if not frame or not frame:IsShown() then return 0 end
    local top = frame:GetTop()
    if not top then return 0 end
    return top * frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
end

-- A bar's drawn box in UIParent units (left, right, top, bottom): its first and last slots while the band holds its
-- buttons, else its frame; nil when not seen. The slots stay put while the game carries the frame off.
function B.ColumnBox(bar)
    local buttons = bar and bar.actionButtons
    local first = buttons and buttons[1]
    local slot = first and slotOf[first]
    local from, to = bar, bar
    if slot and first:GetParent() == slot then
        from, to = slot, slot
        for i = #buttons, 2, -1 do
            local other = slotOf[buttons[i]]
            if other and buttons[i]:IsShown() then
                to = other
                break
            end
        end
    end
    if not from or not from:IsVisible() or (from:GetEffectiveAlpha() or 1) <= 0 then return nil end
    local l1, r1, t1, b1 = from:GetLeft(), from:GetRight(), from:GetTop(), from:GetBottom()
    local l2, r2, t2, b2 = to:GetLeft(), to:GetRight(), to:GetTop(), to:GetBottom()
    if not (l1 and r1 and t1 and b1 and l2 and r2 and t2 and b2) then return nil end
    local k = from:GetEffectiveScale() / UIParent:GetEffectiveScale()
    return math.min(l1, l2) * k, math.max(r1, r2) * k, math.max(t1, t2) * k, math.min(b1, b2) * k
end

-- A band bar by its buttons' slot: the client carries the bar frame off (a fight, the totem bar) while they stay.
local function BarTop(bar)
    local first = bar.actionButtons and bar.actionButtons[1]
    local slot = first and slotOf[first]
    if slot and slot:IsVisible() then return TopOf(slot) end
    return TopOf(bar)
end

local function BandTop()
    local art = B.art
    local top = TopOf(art)
    for bar, hung in pairs(rowOf) do
        if hung.row and hung.row:GetParent() == art then top = math.max(top, BarTop(bar)) end
    end
    for _, holder in ipairs(B.StatusPair()) do
        if holder and B.OnBand(holder) then top = math.max(top, TopOf(holder)) end
    end
    -- A moved group keeps the band as parent: only one standing on it counts, or the stack rose with a moved menu.
    local shape = B.shape
    if shape.micro then
        for _, button in ipairs(B.MicroButtonList and B.MicroButtonList() or {}) do
            if button:GetParent() == art then top = math.max(top, TopOf(button)) end
        end
    end
    if shape.bags then
        for _, name in ipairs(B.BAG_BUTTONS) do
            local button = _G[name]
            if button and button:GetParent() == art then top = math.max(top, TopOf(button)) end
        end
    end
    return top
end

-- Puts the container back on our spot if the client moved it; returns it when moved. Never in combat while protected.
function B.KeepBottomContainer()
    local want = B.bottomWant
    local frame = BottomManagedFrameContainer
    if not (want and B.active and frame) then return nil end
    if InCombatLockdown() and frame:IsProtected() then return nil end
    local scale = frame:GetScale() or 1
    if scale <= 0 then scale = 1 end
    local y = want / scale
    local point, rel, relPoint, x, py = frame:GetPoint(1)
    if frame:GetNumPoints() == 1 and point == "BOTTOM" and rel == UIParent and relPoint == "BOTTOM"
        and math.abs(x or 0) < 0.05 and math.abs((py or 0) - y) < 0.05 then
        return nil
    end
    ns.SetPointOnce(frame, "BOTTOM", UIParent, "BOTTOM", 0, y)
    return frame
end

-- End of the full pass: the container's spot from the band as laid.
function B.PlaceBottomContainer()
    if not B.active or not B.art or InCombatLockdown() then return end
    -- A placed bar 1 is out of the client's bottom stack too; a band dragged to the screen top would lift the container off screen.
    if ns.barMoved then
        B.bottomWant = nil
        return
    end
    local top = BandTop()
    B.bottomWant = top > 0 and math.floor(top + BOTTOM_MARGIN + 0.5) or nil
    B.KeepBottomContainer()
end
