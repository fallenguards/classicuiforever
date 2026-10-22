local _, ns = ...

-- Old scroll bars: our slider, the old knob and arrows on client thin bars, the column behind.

local FadeKeys, KEYS = ns.FadeKeys, ns.KEYS

local KNOB_H = 24
local KNOB_COORDS = { 0.2, 0.8, 0.125, 0.875 }
local KNOB = { layer = "ARTWORK", w = 18, h = KNOB_H, coords = KNOB_COORDS }
local OWN_KNOB = { own = "knob", layer = "ARTWORK", w = 18, h = KNOB_H, coords = KNOB_COORDS }
-- The arrow sheets are 32x32 with the 16x16 arrow in the middle.
local ARROW_COORDS = { 0.25, 0.75, 0.25, 0.75 }
local ARROW = { coords = ARROW_COORDS, add = true }
-- One pixel right: the old track sits that far over.
local ARROW_OVER = { own = "arrow", layer = "ARTWORK", coords = ARROW_COORDS,
    point = "TOPLEFT", x = 1, point2 = "BOTTOMRIGHT", x2 = 1, show = true }

function ns.ClassicScrollBar(parent, anchorTo, onValue)
    local bar = ns.NewFrame("Slider", nil, parent)
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(16)
    bar:SetPoint("TOPLEFT", anchorTo, "TOPRIGHT", 6, -16)
    bar:SetPoint("BOTTOMLEFT", anchorTo, "BOTTOMRIGHT", 6, 16)
    bar:SetThumbTexture((ns.DressNew(bar, "scrollKnob", KNOB)))
    bar:SetValueStep(1)
    bar:SetObeyStepOnDrag(true)
    bar:SetMinMaxValues(0, 0)
    bar:SetValue(0)

    local function Arrow(kind, point, relPoint)
        local button = ns.NewFrame("Button", nil, bar)
        button:SetSize(16, 16)
        button:SetPoint(point, bar, relPoint, 0, 0)
        local key = "scroll" .. kind .. "Button"
        ns.DressStates(button, key .. "Up", key .. "Down", key .. "Disabled", key .. "Highlight", ARROW)
        return button
    end
    bar.up = Arrow("Up", "BOTTOM", "TOP")
    bar.down = Arrow("Down", "TOP", "BOTTOM")
    bar.up:SetScript("OnClick", function() bar:SetValue(bar:GetValue() - bar.step) PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON) end)
    bar.down:SetScript("OnClick", function() bar:SetValue(bar:GetValue() + bar.step) PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON) end)
    bar.step = 1

    function bar:SetRange(max, step)
        self.step = step or 1
        max = math.max(0, max)
        local value = self:GetValue()
        self:SetMinMaxValues(0, max)
        self:SetValue(math.min(value, max))
        -- Nothing to scroll: only the knob goes (arrows grey out), unless hideWhenIdle.
        self:SetShown(not self.hideWhenIdle or max > 0)
        local thumb = self:GetThumbTexture()
        if thumb then thumb:SetShown(max > 0) end
        self:Refresh()
    end
    function bar:Refresh()
        local _, max = self:GetMinMaxValues()
        local value = self:GetValue()
        self.up:SetEnabled(value > 0)
        self.down:SetEnabled(value < max)
    end
    bar:SetScript("OnValueChanged", function(self, value)
        self:Refresh()
        onValue(value)
    end)
    return bar
end

-- How far past the track's ends the knob runs, per bar, where its arrows stand further out than the client's; the foot
-- its own when the down arrow stands further than the up one.
local knobReach = setmetatable({}, { __mode = "k" })
local knobFoot = setmetatable({}, { __mode = "k" })
function ns.KnobReach(bar, reach, foot)
    knobReach[bar] = reach
    knobFoot[bar] = foot
end
-- How far beside the arrows' line the knob stands, per bar (ScrollTrackArt's spec).
local knobOffset = setmetatable({}, { __mode = "k" })
function ns.KnobOffset(bar, x) knobOffset[bar] = x end
-- Bars whose knob stays at the top with nothing to scroll, as Era's text boxes kept theirs.
local knobStays = setmetatable({}, { __mode = "k" })
function ns.KnobStays(bar) knobStays[bar] = true end

-- The client's thumb stretches with the content, so the knob is placed by scroll fraction.
function ns.ClassicKnob(bar)
    local track = bar.Track
    local thumb = track and track.Thumb
    if not thumb then return end
    FadeKeys(thumb, KEYS.THUMB)
    local knob = ns.DressNew(track, "scrollKnob", OWN_KNOB)
    local function Place()
        local pct = bar.fcuiPct or 0
        -- Nothing to scroll: no knob, as the client hides its thumb (the wheel still moves pct), or one held at the top.
        if bar.HasScrollableExtent then
            local ok, can = pcall(bar.HasScrollableExtent, bar)
            if ok and not can then
                if not knobStays[bar] then
                    knob:Hide()
                    return
                end
                pct = 0
            end
        end
        -- The client's track stops 3 px short of its arrows; the old knob ran up to them.
        local reach = knobReach[bar] or bar.fcuiKnobReach or 3
        local foot = knobFoot[bar] or reach
        local room = math.max(0, (track:GetHeight() or 0) - KNOB_H)
        -- On the arrows' line: the track may sit off to one side.
        local dx = 0
        local arrow = bar.Back or bar.Forward
        local refX = arrow and arrow.GetCenter and arrow:GetCenter()
        if not refX and bar.GetCenter then refX = bar:GetCenter() end
        local trackX = track.GetCenter and track:GetCenter()
        if refX and trackX then dx = refX - trackX end
        dx = dx + (knobOffset[bar] or bar.fcuiArrowOffset or 0)
        ns.SetPointOnce(knob, "TOP", track, "TOP", dx, reach - pct * (room + reach + foot))
        knob:Show()
    end
    if ns.Once(bar, "knobHooked") then
        if bar.SetScrollPercentageInternal then
            hooksecurefunc(bar, "SetScrollPercentageInternal", function(self, pct) self.fcuiPct = pct or 0 Place() end)
        end
        if bar.Update then hooksecurefunc(bar, "Update", Place) end
        track:HookScript("OnSizeChanged", Place)
    end
    Place()
end

-- Our arrow over a client stepper follows its state: greyed with nothing to scroll that way.
function ns.ArrowStates(button, tex, kind)
    local base = "scroll" .. kind .. "Button"
    local function State(_, down)
        ns.SetTex(tex, base .. (not button:IsEnabled() and "Disabled" or down == true and "Down" or "Up"))
    end
    if ns.Once(button, "arrowStates") then
        button:HookScript("OnEnable", State)
        button:HookScript("OnDisable", State)
        button:HookScript("OnMouseDown", function() if button:IsEnabled() then State(nil, true) end end)
        button:HookScript("OnMouseUp", State)
    end
    State()
end

function ns.SkinMinimalScrollBar(bar)
    if not bar or bar.fcuiSkinned then return end
    bar.fcuiSkinned = true
    local track = bar.Track
    if track then
        FadeKeys(track, KEYS.THUMB)
        if track.Thumb then track.Thumb:SetWidth(16) end
        -- The arrow art is a pixel right of its button; the knob follows.
        bar.fcuiArrowOffset = 1
        ns.ClassicKnob(bar)
    end
    local function Arrow(button, kind)
        if not button then return end
        if button.Texture then button.Texture:SetAlpha(0) end
        button:SetSize(16, 16)
        ns.ArrowStates(button, ns.DressNew(button, "scroll" .. kind .. "ButtonUp", ARROW_OVER), kind)
    end
    Arrow(bar.Back, "Up")
    Arrow(bar.Forward, "Down")
end

-- Era's trim bar (WowTrimScrollBar) on a client minimal bar by its atlases (same art on every client): plate, capped
-- column, arrows, three piece knob on the client's thumb (its length and travel kept). Metal drained, gold arrows kept.
-- Era's numbers (TrimScrollBar.xml), from the bar's own edges (x + right, y + up):
local ERA_SCROLL_WIDTH = 25
local ERA_SCROLL_UP_ARROW_X = 4
local ERA_SCROLL_UP_ARROW_Y = -4
local ERA_SCROLL_DOWN_ARROW_X = 4
local ERA_SCROLL_DOWN_ARROW_Y = 4
local ERA_SCROLL_KNOB_X = 4
local ERA_SCROLL_TRACK_TOP = -22
local ERA_SCROLL_TRACK_BOTTOM = 22
local ERA_SCROLL_COLUMN_X = 0
local ERA_SCROLL_COLUMN_TOP = 0
local ERA_SCROLL_COLUMN_BOTTOM = 0
local ERA_SCROLL_PLATE_LEFT = 2
local ERA_SCROLL_PLATE_TOP = -3
local ERA_SCROLL_PLATE_RIGHT = -3
local ERA_SCROLL_PLATE_BOTTOM = 3
-- Era's own, for a bar that brings no numbers of its own (ns.TrimScrollBar's spec).
local ERA_SCROLL = {
    width = ERA_SCROLL_WIDTH,
    upX = ERA_SCROLL_UP_ARROW_X,
    upY = ERA_SCROLL_UP_ARROW_Y,
    downX = ERA_SCROLL_DOWN_ARROW_X,
    downY = ERA_SCROLL_DOWN_ARROW_Y,
    knobX = ERA_SCROLL_KNOB_X,
    trackTop = ERA_SCROLL_TRACK_TOP,
    trackBottom = ERA_SCROLL_TRACK_BOTTOM,
    columnX = ERA_SCROLL_COLUMN_X,
    columnTop = ERA_SCROLL_COLUMN_TOP,
    columnBottom = ERA_SCROLL_COLUMN_BOTTOM,
    plateLeft = ERA_SCROLL_PLATE_LEFT,
    plateTop = ERA_SCROLL_PLATE_TOP,
    plateRight = ERA_SCROLL_PLATE_RIGHT,
    plateBottom = ERA_SCROLL_PLATE_BOTTOM,
}
local TRIM_ARROW_W, TRIM_ARROW_H = 18, 16
local TRIM_KNOB_W, TRIM_CAP_H, TRIM_KNOB_IN, TRIM_CENTER_H = 18, 21, 5, 1022
local TRIM_KNOB = {
    up = { "UI-ScrollBar-Knob-EndCap-Top", "UI-ScrollBar-Knob-Center", "UI-ScrollBar-Knob-EndCap-Bottom" },
    over = { "UI-ScrollBar-Knob-MouseOver-EndCap-Top", "UI-ScrollBar-Knob-MouseOver-Center",
        "UI-ScrollBar-Knob-MouseOver-EndCap-Bottom" },
    off = { "UI-ScrollBar-Knob-EndCap-Top-Disabled", "UI-ScrollBar-Knob-Center-Disabled",
        "UI-ScrollBar-Knob-EndCap-Bottom-Disabled" },
}

local function TrimArrow(bar, button, art, point, x, y)
    if button.Texture then button.Texture:SetAlpha(0) end
    button:SetSize(TRIM_ARROW_W, TRIM_ARROW_H)
    ns.SetPointOnce(button, point, bar, point, x, y)
    local face = ns.OwnTexture(button, "trimFace", "ARTWORK")
    local over = ns.OwnTexture(button, "trimOver", "OVERLAY")
    over:SetAtlas(art .. "-Highlight")
    over:SetAllPoints(face)
    local function State(down)
        local on = button:IsEnabled()
        face:SetAtlas(art .. (not on and "-Disabled" or down and "-Down" or "-Up"))
        -- Pressed: a pixel down and right, as Era's arrows.
        local d = on and down and 1 or 0
        ns.SetTwoPointsIf(face, "TOPLEFT", button, "TOPLEFT", d, -d, "BOTTOMRIGHT", button, "BOTTOMRIGHT", d, -d)
        over:SetShown(on and button:IsMouseOver())
    end
    State(false)
    return State
end

local function HookArrow(button, State)
    local function Rest() State(false) end
    button:HookScript("OnEnable", Rest)
    button:HookScript("OnDisable", Rest)
    button:HookScript("OnMouseDown", function() State(true) end)
    button:HookScript("OnMouseUp", Rest)
    button:HookScript("OnEnter", Rest)
    button:HookScript("OnLeave", Rest)
end

local function TrimKnob(thumb)
    FadeKeys(thumb, KEYS.THUMB)
    -- On our own frame over the thumb: shown and hidden with it, sized by its own script (no client hook on size).
    local ear = ns.NewFrame("Frame", nil, thumb)
    ear:SetAllPoints(thumb)
    local top = ear:CreateTexture(nil, "ARTWORK", nil, 2)
    local mid = ear:CreateTexture(nil, "ARTWORK", nil, 1)
    local bottom = ear:CreateTexture(nil, "ARTWORK", nil, 2)
    top:SetSize(TRIM_KNOB_W, TRIM_CAP_H)
    top:SetPoint("TOP", ear, "TOP", 0, 0)
    bottom:SetSize(TRIM_KNOB_W, TRIM_CAP_H)
    bottom:SetPoint("BOTTOM", ear, "BOTTOM", 0, 0)
    mid:SetWidth(TRIM_KNOB_W)
    mid:SetPoint("TOP", ear, "TOP", 0, -TRIM_KNOB_IN)
    mid:SetPoint("BOTTOM", ear, "BOTTOM", 0, TRIM_KNOB_IN)
    ns.DrainBronze(top)
    ns.DrainBronze(mid)
    ns.DrainBronze(bottom)
    local function Paint()
        local set = not thumb:IsEnabled() and TRIM_KNOB.off or thumb:IsMouseOver() and TRIM_KNOB.over or TRIM_KNOB.up
        top:SetAtlas(set[1])
        mid:SetAtlas(set[2])
        bottom:SetAtlas(set[3])
        -- Era's centre strip is cut to the knob's length, never stretched.
        local h = math.max(0, (ear:GetHeight() or 0) - 2 * TRIM_KNOB_IN)
        mid:SetTexCoord(0, 1, 0, math.min(1, h / TRIM_CENTER_H))
    end
    ear:SetScript("OnSizeChanged", Paint)
    Paint()
    return Paint
end

-- No client hooks (a quiet dialog): a watch while the bar shows repaints an arrow or the knob when its state changes.
local function QuietTrim(bar, name, arrows, thumb, paintKnob)
    local seen = {}
    ns.Sched.OnFrame(ns.NewFrame("Frame", nil, bar), { name = name, every = 0, fn = function()
        for button, State in pairs(arrows) do
            local down = button:IsEnabled() and button:GetButtonState() == "PUSHED"
            local now = (button:IsEnabled() and 1 or 0) + (down and 2 or 0) + (button:IsMouseOver() and 4 or 0)
            if seen[button] ~= now then
                seen[button] = now
                State(down)
            end
        end
        local now = (thumb:IsEnabled() and 1 or 0) + (thumb:IsMouseOver() and 2 or 0)
        if seen[thumb] ~= now then
            seen[thumb] = now
            paintKnob()
        end
    end })
end

-- quiet: a watch name instead of hooks on the client's arrows and thumb; spec: its own numbers, as ERA_SCROLL.
function ns.TrimScrollBar(bar, quiet, spec)
    local track = bar and bar.Track
    if not (track and track.Thumb) or not ns.Once(bar, "trimBar") then return end
    spec = spec or ERA_SCROLL
    bar:SetWidth(spec.width)
    local plate = ns.OwnTexture(bar, "trimPlate", "BACKGROUND")
    plate:SetColorTexture(0, 0, 0, 0.75)
    ns.SetTwoPointsIf(plate, "TOPLEFT", bar, "TOPLEFT", spec.plateLeft, spec.plateTop,
        "BOTTOMRIGHT", bar, "BOTTOMRIGHT", spec.plateRight, spec.plateBottom)
    local head = ns.OwnTexture(bar, "trimHead", "ARTWORK")
    head:SetAtlas("UI-ScrollBar-EndCap-Top", true)
    ns.SetPointOnce(head, "TOPLEFT", bar, "TOPLEFT", spec.columnX, spec.columnTop)
    local foot = ns.OwnTexture(bar, "trimFoot", "ARTWORK")
    foot:SetAtlas("UI-ScrollBar-EndCap-Bottom", true)
    ns.SetPointOnce(foot, "BOTTOMLEFT", bar, "BOTTOMLEFT", spec.columnX, spec.columnBottom)
    local run = ns.OwnTexture(bar, "trimRun", "ARTWORK")
    run:SetAtlas("!UI-ScrollBar-Center", true)
    ns.SetTwoPointsIf(run, "TOPLEFT", head, "BOTTOMLEFT", 0, 0, "BOTTOMRIGHT", foot, "TOPRIGHT", 0, 0)
    ns.DrainBronze(head)
    ns.DrainBronze(foot)
    ns.DrainBronze(run)
    -- Era's track in from each end; the client thumb (8 wide, centred) runs on it, the knob centred over it.
    FadeKeys(track, KEYS.THUMB)
    ns.SetTwoPointsIf(track, "TOPLEFT", bar, "TOPLEFT", spec.knobX, spec.trackTop,
        "BOTTOMRIGHT", bar, "BOTTOMLEFT", spec.knobX + TRIM_KNOB_W, spec.trackBottom)
    local thumb = track.Thumb
    local paintKnob = TrimKnob(thumb)
    local arrows = {}
    if bar.Back then
        arrows[bar.Back] = TrimArrow(bar, bar.Back, "UI-ScrollBar-ScrollUpButton", "TOPLEFT",
            spec.upX, spec.upY)
    end
    if bar.Forward then
        arrows[bar.Forward] = TrimArrow(bar, bar.Forward, "UI-ScrollBar-ScrollDownButton", "BOTTOMLEFT",
            spec.downX, spec.downY)
    end
    if quiet then
        QuietTrim(bar, quiet, arrows, thumb, paintKnob)
        return
    end
    for button, State in pairs(arrows) do HookArrow(button, State) end
    thumb:HookScript("OnEnter", paintKnob)
    thumb:HookScript("OnLeave", paintKnob)
    thumb:HookScript("OnEnable", paintKnob)
    thumb:HookScript("OnDisable", paintKnob)
end

-- Scroll column: a head up to 256 tall, a 108 foot, the head's plain run stretched between.
local TRACK_FOOT = 108
-- The column's see-through channel: from its left edge to its right, in from its ends.
local HOUSING_CHANNEL_LEFT, HOUSING_CHANNEL_RIGHT, HOUSING_CHANNEL_TOP = 6, 25, 4
local fits = 0   -- a name per bar for its next-frame fit

local function ColumnPiece(tex)
    ns.SetTex(tex, "charScrollBar")
    tex:SetWidth(31)
    tex:ClearAllPoints()
end

local function ColumnPieces(top, middle, foot)
    ColumnPiece(top)
    ColumnPiece(middle)
    ColumnPiece(foot)
end

local function JoinColumn(top, middle, foot)
    foot:SetHeight(TRACK_FOOT)
    foot:SetTexCoord(0.515625, 1, 0, TRACK_FOOT / 256)
    middle:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, 0)
    middle:SetPoint("BOTTOMLEFT", foot, "TOPLEFT", 0, 0)
    middle:SetTexCoord(0, 0.484375, 0.3, 0.7)
end

-- Too short for foot plus socket: no column rather than overlapping pieces.
local function FitColumn(top, middle, foot, total)
    if total < TRACK_FOOT + 24 then
        top:Hide() middle:Hide() foot:Hide()
        return
    end
    local head = math.min(256, total - TRACK_FOOT)
    top:SetHeight(head)
    top:SetTexCoord(0, 0.484375, 0, head / 256)
    top:Show()
    foot:Show()
    middle:SetShown(total - TRACK_FOOT - head > 0.5)
end

-- Moves a client arrow by dx, dy, once.
local function Nudge(button, flag, dx, dy)
    if not button or button[flag] then return end
    local point, relativeTo, relativePoint, x, y = button:GetPoint(1)
    if point then
        button[flag] = true
        ns.SetPointOnce(button, point, relativeTo, relativePoint, (x or 0) + dx, (y or 0) + dy)
    end
end

-- spec, per bar: the column's left and its ends past the bar's (houseTop up, houseFoot down), the arrows' nudges, the
-- knob beside the arrows' line and its run past the track's ends. Head and up arrow 2 higher, foot and down 2 lower.
local TRACK_SPEC = { houseX = -10.5, houseTop = 7, houseFoot = -6, upX = 0, upY = 2, downX = 0, downY = -2,
    knobX = 1, knobReach = 7 }
ns.TRACK_SPEC = TRACK_SPEC

-- The column's holder: a child of the window itself, one level under its border (over every floor and backing),
-- laid on the bar and shown with it. On the bar a bar standing above its window (the Communities chat's) drew the
-- column over the edge, and a child of the bar stays in the bar's strata.
local function ColumnHolder(bar)
    local window = bar
    while window:GetParent() and window:GetParent() ~= UIParent do window = window:GetParent() end
    local holder = ns.NewFrame("Frame", nil, window)
    holder:SetAllPoints(bar)
    local slice = window.NineSlice
    local under = slice and slice.GetFrameLevel and slice:GetFrameLevel()
    holder:SetFrameLevel(type(under) == "number" and under - 1 or (window:GetFrameLevel() or 0) + 2)
    return holder
end

function ns.ScrollTrackArt(bar, spec)
    spec = spec or TRACK_SPEC
    if not bar or bar.fcuiTrackArt or not bar.GetHeight then return end
    bar.fcuiTrackArt = true
    -- A bar with its own track (the sheet's lists) keeps it.
    if bar.fcui and bar.fcui.trackTop then return end
    local holder = ColumnHolder(bar)
    -- A bar faded (the loot window with nothing to scroll, the bags) fades the column with it, as a child would.
    local function Alpha() holder:SetAlpha(bar:GetEffectiveAlpha() or 1) end
    ns.HookMethod(bar, "SetAlpha", Alpha)
    local top = ns.OwnTexture(holder, "trackTop", "BACKGROUND", 0)
    local middle = ns.OwnTexture(holder, "trackMiddle", "BACKGROUND", 0)
    local foot = ns.OwnTexture(holder, "trackBottom", "BACKGROUND", 1)
    ColumnPieces(top, middle, foot)
    top:SetPoint("TOPLEFT", bar, "TOPLEFT", spec.houseX, spec.houseTop)
    Nudge(bar.Back, "fcuiRaised", spec.upX, spec.upY)
    foot:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", spec.houseX, spec.houseFoot)
    Nudge(bar.Forward, "fcuiLowered", spec.downX, spec.downY)
    JoinColumn(top, middle, foot)
    -- The art's channel (columns 6-24) is see-through: the old frames had a dark inset behind it.
    local channel = ns.OwnTexture(holder, "trackChannel", "BACKGROUND", -1)
    ns.TileTex(channel, "marbleBg", nil, ns.PANE_SHADE or 0.9)
    channel:SetPoint("TOPLEFT", top, "TOPLEFT", HOUSING_CHANNEL_LEFT, -HOUSING_CHANNEL_TOP)
    channel:SetPoint("BOTTOMRIGHT", foot, "BOTTOMLEFT", HOUSING_CHANNEL_RIGHT, HOUSING_CHANNEL_TOP)
    -- The channel hangs on the head and foot: with them hidden it loses its shape and drew a 256 box over the window.
    local function Fit()
        FitColumn(top, middle, foot, (bar:GetHeight() or 0) + spec.houseTop - spec.houseFoot)
        channel:SetShown(top:IsShown())
        Alpha()
    end
    -- Sized via our own frame: the client resets the bar's size script, dropping any hook on it. Once more next frame:
    -- a window sized as it opens (Communities) gave the first fit the bar's old height, and the column had a hole.
    local ear = ns.NewFrame("Frame", nil, bar)
    ear:SetAllPoints(bar)
    fits = fits + 1
    local again = "scroll.fit" .. fits
    local function FitSoon()
        Fit()
        ns.Sched.NextFrame(again, Fit)
    end
    ear:SetScript("OnSizeChanged", FitSoon)
    ear:SetScript("OnShow", function()
        holder:Show()
        FitSoon()
    end)
    ear:SetScript("OnHide", function() holder:Hide() end)
    -- Visible, not shown: a bar in a hidden list (the ignore list) is shown while its list is not.
    holder:SetShown(bar:IsVisible())
    Fit()
    -- Arrows moved out at each end, so the knob reaches further.
    knobReach[bar] = knobReach[bar] or spec.knobReach
    knobOffset[bar] = spec.knobX
    if bar.Track then ns.ClassicKnob(bar) end
end

-- Same column behind our own bar, whose arrows sit outside it; shown and hidden with the bar.
function ns.ScrollColumnOn(bar)
    if not bar or bar.fcuiColumn or not bar.up or not bar.down then return end
    bar.fcuiColumn = true
    local top = bar:CreateTexture(nil, "BACKGROUND", nil, 0)
    local middle = bar:CreateTexture(nil, "BACKGROUND", nil, 0)
    local foot = bar:CreateTexture(nil, "BACKGROUND", nil, 1)
    ColumnPieces(top, middle, foot)
    top:SetPoint("TOPLEFT", bar.up, "TOPLEFT", -7.5, 5)
    foot:SetPoint("BOTTOMLEFT", bar.down, "BOTTOMLEFT", -7.5, -4)
    JoinColumn(top, middle, foot)
    local function Fit()
        FitColumn(top, middle, foot, (bar:GetHeight() or 0) + 32 + 9)
    end
    bar:HookScript("OnSizeChanged", Fit)
    Fit()
end

-- Thin scroll bars a few levels under a window; a forbidden frame (the bank has one) is never queried.
local function SkinUnder(child, depth)
    ns.SkinScrollBarsUnder(child, depth)
end
function ns.SkinScrollBarsUnder(frame, depth)
    if not frame or (depth or 0) <= 0 or type(frame) ~= "table" or not frame.GetChildren then return end
    if ns.IsForbidden(frame) then return end
    local bar = rawget(frame, "ScrollBar")
    if type(bar) == "table" and not ns.IsForbidden(bar) and bar.Track and bar.Back and bar.Forward then
        ns.SkinMinimalScrollBar(bar)
        ns.ScrollTrackArt(bar)
    end
    ns.EachChildProtected(frame, SkinUnder, depth - 1)
end

-- Bars that move inside the client's own passes: no client hook, the knob follows a watch that runs while the bar shows.
-- column: the track column behind it too.
function ns.QuietScrollBar(bar, name, column)
    if not bar or bar.fcuiSkinned or not (bar.Track and bar.Back and bar.Forward) then return end
    if not (bar.GetScrollPercentage and bar.GetVisibleExtentPercentage) then return end
    ns.Once(bar, "knobHooked")
    ns.SkinMinimalScrollBar(bar)
    if column then ns.ScrollTrackArt(bar) end
    local track = bar.Track
    local pct, ext, height
    ns.Sched.OnFrame(ns.NewFrame("Frame", nil, bar), { name = name, every = 0, fn = function()
        local p, e, h = bar:GetScrollPercentage(), bar:GetVisibleExtentPercentage(), track:GetHeight()
        if p == pct and e == ext and h == height then return end
        pct, ext, height = p, e, h
        bar.fcuiPct = p
        ns.ClassicKnob(bar)
    end })
end
