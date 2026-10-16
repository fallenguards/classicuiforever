local _, ns = ...
local L = ns.L
local B = ns.band

-- The bag bar pick (options, Bag bar): the row hidden, faded till a bag window opens or the mouse is over it, or folded to
-- the backpack alone with a small arrow beside it while the mouse is there; the band's sockets, the floor and the game's own
-- bar go with it. Alpha, mouse and show flags only, so a pick made in a fight answers in it; what shows and goes fades.

local BAG_BUTTONS = B.BAG_BUTTONS
local SetFrameAlphaIf, SetShownIf = ns.SetFrameAlphaIf, ns.SetShownIf
local MODES = { hideBagsAlways = "hidden", hideBagsOpen = "open", hideBagsHover = "hover", bagsBackpackOnly = "backpack" }
local FADE = 0.25
local revealed = false        -- a bag window open (open), or the mouse over the row (hover)
local arrowRevealed = false   -- the mouse over the row or the arrow
local hooked = false
local buttons = {}
local lit = setmetatable({}, { __mode = "k" })   -- row button -> true while the row's alpha lights it
local arrow

-- Edit mode shows the row whatever the pick: its box must be there to take. Bars another addon holds are its own.
function B.BagsMode()
    local db = ns.db
    if not db or ns.EditMode.Live() or ns.BarsTaken() then return "shown" end
    for key, mode in pairs(MODES) do
        if db[key] == true then return mode end
    end
    return "shown"
end

-- Backpack only, folded: the bags, reagent bag and key slot away (the arrow's own state, saved).
function B.BagsFolded() return B.BagsMode() == "backpack" and not (ns.db and ns.db.bagsUnfolded == true) end

-- Cells past the five sockets: the reagent slot's.
function B.BagExtraCells() return B.ReagentSlot() and 1 or 0 end

-- The band's bag sockets: drawn full, or faded with the row.
function B.BagRunAlpha()
    local mode = B.BagsMode()
    return (mode ~= "open" and mode ~= "hover" or revealed) and 1 or 0
end

-- The reagent bag's own hover (BandBags) may light it: never on a hidden, folded or faded row.
function B.ReagentMayLight()
    local mode = B.BagsMode()
    if mode == "hidden" or B.BagsFolded() then return false end
    return mode == "shown" or mode == "backpack" or revealed
end

-- The row's buttons: the bags, the reagent bag (unless its own hover owns it, BandBags), and the key ring on the game's
-- bar or riding a moved row.
local function Buttons(band)
    local n = 0
    for _, name in ipairs(BAG_BUTTONS) do
        local button = _G[name]
        if button then
            n = n + 1
            buttons[n] = button
        end
    end
    if CharacterReagentBag0Slot and not B.ReagentHoverWanted() then
        n = n + 1
        buttons[n] = CharacterReagentBag0Slot
    end
    if KeyRingButton and (not band or B.KeyRingRides()) then
        n = n + 1
        buttons[n] = KeyRingButton
    end
    for i = n + 1, #buttons do buttons[i] = nil end
    return n
end

------------------------------------------------------------------ the fade

-- The row's alpha and the arrow's walk to their targets a frame at a time; a lit item button's own SetAlpha lights its
-- regions again first (unlit, the frame's alpha alone hides them).
local rowAlpha, rowTarget, arrowAlpha, arrowTarget = 1, 1, 0, 0
local lastTick

local function Paint()
    for i = 1, #buttons do
        local button = buttons[i]
        SetFrameAlphaIf(button, lit[button] and rowAlpha or 0)
    end
    local art = B.art
    if art then
        for _, tex in ipairs(art.bagRun or buttons) do if tex.SetTexture then tex:SetAlpha(rowAlpha) end end
        if art.bagFloor then art.bagFloor:SetAlpha(rowAlpha) end
        local home = B.KeyRingHome()
        if home and B.KeyRingRides() then home:SetAlpha(rowAlpha) end
    end
    if arrow then arrow:SetAlpha(arrowAlpha) end
end

local function Toward(value, target, step)
    if value < target then return math.min(target, value + step) end
    return math.max(target, value - step)
end

local fadeJob
local function FadeStep()
    local now = GetTime()
    local step = (now - (lastTick or now)) / FADE
    lastTick = now
    rowAlpha, arrowAlpha = Toward(rowAlpha, rowTarget, step), Toward(arrowAlpha, arrowTarget, step)
    Paint()
    if rowAlpha == rowTarget and arrowAlpha == arrowTarget then fadeJob:Sleep() end
end
fadeJob = ns.Sched.Job({ name = "bags.fade", every = 0, awake = false, fn = FadeStep })

-- Targets set; at once when nothing fades (the pick, a band pass), else from where the fade stands.
local function FadeTo(row, arrowWanted, atOnce)
    rowTarget, arrowTarget = row, arrowWanted
    if atOnce then
        rowAlpha, arrowAlpha = row, arrowWanted
        Paint()
        return
    end
    if rowAlpha ~= rowTarget or arrowAlpha ~= arrowTarget then
        lastTick = nil
        fadeJob:Wake()
    end
end

------------------------------------------------------------------ what reveals

local function AnyBagOpen()
    local combined = ContainerFrameCombinedBags
    if combined and combined:IsShown() then return true end
    for i = 1, NUM_CONTAINER_FRAMES or 13 do
        local frame = _G["ContainerFrame" .. i]
        if frame and frame:IsShown() then return true end
    end
    return false
end

-- The row's whole box (its buttons, the band's sockets or the floor under a moved row, the arrow) is one hover zone of
-- ours: gaps and socket art count as over the row. Hover only, so a click goes through to what lies under it.
local zone
local box = {}

local function Grow(region)
    if not (region and region:IsVisible()) then return end
    local l, b, w, h = region:GetRect()
    if not l or ns.IsSecret(l) then return end
    local k = region:GetEffectiveScale() / UIParent:GetEffectiveScale()
    l, b, w, h = l * k, b * k, w * k, h * k
    box.l, box.b = math.min(box.l or l, l), math.min(box.b or b, b)
    box.r, box.t = math.max(box.r or l + w, l + w), math.max(box.t or b + h, b + h)
end

-- The mouse anywhere on the row's box, or over one of its buttons or the arrow.
local function OverRow()
    if zone and zone:IsVisible() and zone:IsMouseOver() then return true end
    for i = 1, Buttons(false) do
        local button = buttons[i]
        if button:IsVisible() and button:IsMouseOver() then return true end
    end
    return arrow ~= nil and arrow:IsVisible() and arrow:IsMouseOver()
end

local Apply
local function Reveal(on)
    on = on and true or false
    if revealed == on then return end
    revealed = on
    Apply()
end
local function ArrowReveal(on)
    on = on and true or false
    if arrowRevealed == on then return end
    arrowRevealed = on
    Apply()
end
local function BagsChanged() if B.BagsMode() == "open" then Reveal(AnyBagOpen()) end end
local function HoverChanged()
    local over = OverRow()
    if B.BagsMode() == "hover" then Reveal(over) end
    ArrowReveal(over)
end
-- Its own key: the reagent bag's hover (BandBags) queues under bags.hover on the same buttons, and the last one queued runs.
local function HoverLeft() ns.Sched.NextFrame("bags.rowHover", HoverChanged) end

local function HoverZone(wanted, n)
    if not wanted then
        if zone then zone:Hide() end
        return
    end
    box.l, box.b, box.r, box.t = nil, nil, nil, nil
    local level
    for i = 1, n do
        Grow(buttons[i])
        level = math.min(level or buttons[i]:GetFrameLevel(), buttons[i]:GetFrameLevel())
    end
    local art = B.art
    for _, tex in ipairs(art and art.bagRun or {}) do Grow(tex) end
    Grow(art and art.bagFloor)
    Grow(arrow)
    if not box.l then
        if zone then zone:Hide() end
        return
    end
    if not zone then
        zone = ns.NewFrame("Frame", nil, UIParent)
        zone:SetScript("OnEnter", HoverChanged)
        zone:SetScript("OnLeave", HoverLeft)
        zone:EnableMouse(true)
        zone:SetMouseClickEnabled(false)
    end
    ns.SetStrataIf(zone, buttons[1]:GetFrameStrata())
    ns.SetLevelIf(zone, math.max(0, (level or 1) - 1))
    ns.SetSizeIf(zone, box.r - box.l, box.t - box.b)
    ns.SetPointIf(zone, "BOTTOMLEFT", UIParent, "BOTTOMLEFT", box.l, box.b)
    zone:Show()
end

-- Bag windows seen opening and closing; the mouse entering and leaving the row's buttons (leave judged a frame later).
local function Hook()
    if hooked then return end
    hooked = true
    if ContainerFrameCombinedBags then ns.Sched.OnVisible(ContainerFrameCombinedBags, "bags.show", BagsChanged) end
    for i = 1, NUM_CONTAINER_FRAMES or 13 do
        local frame = _G["ContainerFrame" .. i]
        if frame then ns.Sched.OnVisible(frame, "bags.show", BagsChanged) end
    end
    for i = 1, Buttons(false) do
        buttons[i]:HookScript("OnEnter", HoverChanged)
        buttons[i]:HookScript("OnLeave", HoverLeft)
    end
end

------------------------------------------------------------------ the fold arrow

-- The band's stone page arrow, small, turned along the row: just past the backpack folded, past the last bag unfolded,
-- seen only while the mouse is over the row or itself. A click folds or unfolds at once, in a fight too; the band's
-- own pass (the part's width) follows out of combat.
local ARROW = { coords = { 0, 1, 0, 1 }, fill = true, add = true }
local STONE = { "arrowUpUp", "arrowUpDown", "arrowUpDisabled", "arrowUpHighlight" }
local ARROW_SHARE, ARROW_GAP = 0.8, 2

local function FoldClick()
    ns.db.bagsUnfolded = ns.db.bagsUnfolded ~= true
    Apply()
    ns.WhenCalm("bags.fold", function() if B.Apply then B.Apply() end end)
end

local function Turn(tex, _, angle) tex:SetRotation(angle) end

-- Up is the art's own way; along the row's growth folded (the bags come out that way), back unfolded.
local function Angle(dx, dy)
    local angle = math.atan2(-dx, dy)
    return B.BagsFolded() and angle or angle + math.pi
end

local function Arrow()
    if arrow then return arrow end
    arrow = ns.NewFrame("Button", nil, UIParent)
    ns.DressStates(arrow, STONE[1], STONE[2], STONE[3], STONE[4], ARROW)
    arrow:SetScript("OnClick", FoldClick)
    ns.AttachTip(arrow, { text = function() return B.BagsFolded() and L["BAGS_SHOW_BAGS"] or L["BAGS_HIDE_BAGS"] end })
    arrow:HookScript("OnEnter", HoverChanged)
    arrow:HookScript("OnLeave", HoverLeft)
    arrow:SetAlpha(0)
    return arrow
end

-- Beside prev in the row's growth, a gap on, at a share of the buttons' size.
local function Beside(a, prev, grow, size, level, scale)
    local across = math.floor(size * ARROW_SHARE + 0.5)
    a:SetSize(across, across)
    ns.SetScaleIf(a, scale)
    ns.SetLevelIf(a, level)
    ns.SetPointIf(a, grow[1], prev, grow[2], grow[3] * ARROW_GAP, grow[4] * ARROW_GAP)
    ns.EachState(a, ns.KEYS.STATES, Turn, Angle(grow[3], grow[4]))
    a:Show()
end

-- On the band's row past prev; nil prev takes the arrow off the row.
function B.LayFoldArrow(prev, grow, size, level, scale)
    if not prev then
        if arrow then arrow:Hide() end
        return
    end
    local a = Arrow()
    if a:GetParent() ~= B.art then a:SetParent(B.art) end
    Beside(a, prev, grow, size, level + 1, scale)
end

-- The game's own bar (classic bar off), laid as the game lays it: the bags to the backpack's left.
local LEFTWARD = { "RIGHT", "LEFT", -1, 0 }
local function LayArrowOnGameBar()
    local backpack = MainMenuBarBackpackButton
    if not backpack then return end
    local a = Arrow()
    if a:GetParent() ~= UIParent then a:SetParent(UIParent) end
    local reagent = CharacterReagentBag0Slot
    local beside = B.BagsFolded() and backpack or (reagent and reagent:IsShown() and reagent) or _G.CharacterBag3Slot or backpack
    Beside(a, beside, LEFTWARD, backpack:GetWidth() or 30, backpack:GetFrameLevel() + 1,
        backpack:GetEffectiveScale() / UIParent:GetEffectiveScale())
end

------------------------------------------------------------------ the pick applied

-- Every bag layout's end, a reveal, a fold, the pick: the row as the pick wants it now. The game's own bar keeps its
-- buttons (it lays them), faded; the band's row hides them, its sockets and floor fade with them. The reagent bag is
-- faded, never hidden: the game shows and hides that one itself with the bags' state.
Apply = function(atOnce)
    Hook()
    local mode = B.BagsMode()
    local band = ns.ModuleInForce("classicBar") and B.art ~= nil and not ns.BarsTaken()
    local fold = B.BagsFolded()
    local seen = mode == "shown" or mode == "backpack" or (mode ~= "hidden" and revealed)
    local reagent = CharacterReagentBag0Slot
    local n = Buttons(band)
    for i = 1, n do
        local button = buttons[i]
        local folds = fold and button ~= MainMenuBarBackpackButton and button ~= KeyRingButton
        local shown = band and button ~= reagent and (mode ~= "hidden" and not folds) or nil
        if shown ~= nil then SetShownIf(button, shown) end
        local lights = seen and not folds
        if lights and not lit[button] then button:SetAlpha(1) end
        lit[button] = lights or nil
        local mouse = lights or (mode == "hover" and not folds)
        if button:IsMouseEnabled() ~= mouse then button:EnableMouse(mouse) end
    end
    if mode == "backpack" and not band then
        LayArrowOnGameBar()
    elseif arrow and mode ~= "backpack" then
        arrow:Hide()
    end
    HoverZone(mode == "hover" or mode == "backpack", n)
    B.ReagentHoverCheck()
    FadeTo(seen and 1 or 0, (mode == "backpack" and arrowRevealed) and 1 or 0, atOnce)
end
B.ApplyBagsMode = function() Apply(true) end

-- A pick changed, in a fight too: what is revealed read afresh and the row answers at once; the band's own pass (which
-- closes it up over a hidden or folded row) follows out of combat.
ns.OnToggle(function(key)
    if not MODES[key] and key ~= "showBags" then return end
    revealed = B.BagsMode() == "open" and AnyBagOpen() or false
    arrowRevealed = false
    Apply(true)
end)

ns.RegisterModule("showBags", { apply = B.ApplyBagsMode, restore = B.ApplyBagsMode, barPiece = true })
