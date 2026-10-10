local _, ns = ...
local L = ns.L

-- Queue eye (its own edit mode system) in Era's look, placed from Minimap.lua's Layout: on our group finder icon while
-- that is on (one button; the icon steps aside while queued), else on the rim until moved. UIParent's child: under the
-- minimap a saved place restored wrong.

local MM = ns.MM

local SIZE = 32   -- a ring button's (Map/MinimapButton.lua)
-- Era's LFG-Eye sheet: 29 frames of 64 on 512 x 256, 0.1 s each (its LFGEye.lua).
local FRAMES, PER_ROW, FRAME_U, FRAME_V, FRAME_TIME = 29, 8, 64 / 512, 64 / 256, 0.1
-- Outside edit mode only these move or resize the eye (probe P2); the spec change can switch the active layout.
local EYE_EVENTS = { "EDIT_MODE_LAYOUTS_UPDATED", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED", "PLAYER_ENTERING_WORLD",
    "PLAYER_SPECIALIZATION_CHANGED" }
local EYE_LOOK = 0.3   -- polling after each wake, for a client move that lands a few frames late

local eyeWatch
local sizeReset
local lookUntil = 0
local over, face   -- our look over the game's eye, and its Era eye
local frame = 0
local heldPoints   -- the eye's own place (moved in edit mode) while it rides the icon

-- Era's LFG-Eye sheet frame n (0 to 28) on tex, cropped as c crops its first frame. The group finder's portrait too.
function ns.EraEyeFrame(tex, n, c)
    local u, v = (n % PER_ROW) * FRAME_U, math.floor(n / PER_ROW) * FRAME_V
    tex:SetTexCoord(c[1] + u, c[2] + u, c[3] + v, c[4] + v)
end
ns.ERA_EYE_FRAMES, ns.ERA_EYE_TIME = FRAMES, FRAME_TIME

-- Era's eye turning while queued; still on its first frame where the game holds its eye still, and in edit mode.
local function Turn()
    local eye = QueueStatusButton
    local still = ns.EditMode.state or (eye and eye.Eye and eye.Eye.IsStaticMode and eye.Eye:IsStaticMode())
    frame = still and 0 or (frame + 1) % FRAMES
    ns.EraEyeFrame(face, frame, ns.ERA_EYE.coords)
end

local function EyeMoved(eye)
    return ns.InDefaultPosition(eye) == false
end

-- Written as the interface reloads, never mid-game.
local function DefaultSizeClick() ns.AskSizeReset("eyeSize", "group finder eye") end

-- Default Size beside Revert Changes for the eye.
local function SizeResetButton()
    local dialog, eye = EditModeSystemSettingsDialog, QueueStatusButton
    local revert = dialog and dialog.Buttons and dialog.Buttons.RevertChangesButton
    if not revert or not eye then return end
    local show = MM.active and dialog:IsShown() and dialog.attachedToSystem == eye and revert:IsVisible()
    if not sizeReset then
        if not show then return end
        sizeReset = CreateFrame("Button", nil, UIParent, "UIPanelButtonTemplate")
        sizeReset:SetFrameStrata("DIALOG")
        sizeReset:SetText(L["MAP_DEFAULT_SIZE"])
        sizeReset:SetScript("OnClick", DefaultSizeClick)
    end
    if show then
        local scale = dialog:GetEffectiveScale() / UIParent:GetEffectiveScale()
        sizeReset:SetScale(scale > 0 and scale or 1)
        sizeReset:SetFrameLevel(dialog:GetFrameLevel() + 20)
        ns.SetPointOnce(sizeReset, "LEFT", revert, "RIGHT", 6, 0)
        sizeReset:SetSize(144, 28)
        sizeReset:SetEnabled(not ns.Near(eye:GetScale(), 1, 0.001))
    end
    sizeReset:SetShown(show)
end

local function PlaceEye()
    local eye, backdrop = QueueStatusButton, MinimapBackdrop
    if not eye or not backdrop then return end
    local icon = ns.GroupFinderIcon()
    -- A ring button's look over the game's eye, which fades; its glow stays (a group found). Border and eye are the
    -- button's children, so edit mode's size scales both; on the icon, drawn at the icon's size.
    if not over then
        over = CreateFrame("Frame", nil, eye)
        over:SetSize(SIZE, SIZE)
        face = ns.RingLook(over, ns.EraEyeFace)
        ns.DressStates(eye, nil, nil, nil, "zoomHighlight", ns.RING_HIGHLIGHT)
        ns.Sched.Attach(over, { name = "minimap.eyeTurn", every = FRAME_TIME, fn = Turn })
    end
    if eye.Eye then ns.SetAlphaIf(eye.Eye, 0) end
    if not over:IsShown() then over:Show() end
    over:SetFrameLevel(eye:GetFrameLevel() + 5)
    local own = eye:GetEffectiveScale()
    local k = (icon and own and own > 0) and icon:GetEffectiveScale() / own or 1
    ns.SetScaleIf(over, k, 0.001)
    ns.SetPointOnce(over, "CENTER", eye, "CENTER", 0, 0)
    eye:SetSize(SIZE * k, SIZE * k)
    -- On the rim the minimap's edit mode box covers the eye's: lift it to HIGH.
    if eye.Selection and eye.Selection.SetFrameStrata and eye.Selection:GetFrameStrata() ~= "HIGH" then
        eye.Selection:SetFrameStrata("HIGH")
    end
    local dragging = eye.IsDragging and eye:IsDragging()
    if dragging or InCombatLockdown() then return end
    if eye:GetParent() ~= UIParent then eye:SetParent(UIParent) end
    if icon then
        if not heldPoints and EyeMoved(eye) then
            heldPoints = {}
            for i = 1, eye:GetNumPoints() do heldPoints[i] = { eye:GetPoint(i) } end
        end
        ns.SetPointOnce(eye, "CENTER", icon, "CENTER", 0, 0)
        return
    end
    -- Off the icon: back to the place edit mode gave it.
    if heldPoints then
        eye:ClearAllPoints()
        for _, p in ipairs(heldPoints) do eye:SetPoint(p[1], p[2], p[3], p[4], p[5]) end
        heldPoints = nil
        return
    end
    if EyeMoved(eye) then return end
    -- Scale is edit mode's; anchor the centre in its own units so it grows in place.
    k = (own and own > 0) and (backdrop:GetEffectiveScale() / own) or 1
    ns.SetPointOnce(eye, "CENTER", backdrop, "TOPLEFT", 38.5 * k, -116.5 * k)
end
MM.PlaceEye = PlaceEye

-- Our minimap off: the game's own eye back, at the place edit mode gave it.
function MM.UnplaceEye()
    local eye = QueueStatusButton
    if not eye or not over then return end
    over:Hide()
    if eye.Eye then ns.SetAlphaIf(eye.Eye, 1) end
    if heldPoints and not InCombatLockdown() then
        eye:ClearAllPoints()
        for _, p in ipairs(heldPoints) do eye:SetPoint(p[1], p[2], p[3], p[4], p[5]) end
        heldPoints = nil
    end
end

-- Sole writer of the eye watch's sleep (R8): awake through edit mode, else a short look after each wake.
local function SetEyeWatch(awake)
    if awake then
        lookUntil = GetTime() + EYE_LOOK
        eyeWatch:Wake()
        eyeWatch:Kick()
    else
        eyeWatch:Sleep()
    end
end

-- No events for moves, resets or size changes in edit mode: poll there. The settings dialog shows only in edit mode.
local function EyeTick(job, now)
    local editing = ns.EditMode.state
    if editing then SizeResetButton() end
    if MM.active and QueueStatusButton then
        local moved = EyeMoved(QueueStatusButton)
        local scale = QueueStatusButton:GetEffectiveScale()
        local icon = ns.GroupFinderIcon()
        local iconScale = icon and icon:GetEffectiveScale()
        if moved ~= job.moved or scale ~= job.scale or icon ~= job.icon or iconScale ~= job.iconScale then
            job.moved, job.scale, job.icon, job.iconScale = moved, scale, icon, iconScale
            PlaceEye()
        end
    end
    if not editing and now >= lookUntil then SetEyeWatch(false) end
end

-- Entry wakes the poll; exit takes one look (the client reverts or saves the layout), and the dialog, ours with it.
local function EditEdge()
    if not ns.EditMode.state and sizeReset then sizeReset:Hide() end
    SetEyeWatch(true)
end

local function EyeEvent()
    SetEyeWatch(true)
end

-- The group finder icon turned on or off, or its size changed: the eye takes a look.
function ns.EyeFollows()
    if eyeWatch and MM.active then SetEyeWatch(true) end
end

-- Created at the first Layout with an eye (after the bar's Init made the edit poll); runs with the module on or off.
function MM.WatchEye()
    if eyeWatch then return end
    eyeWatch = ns.Sched.Job({ name = "minimap.eye", every = 0.1, fn = EyeTick, awake = false })
    local events = CreateFrame("Frame")
    events:SetScript("OnEvent", EyeEvent)
    ns.RegisterEvents(events, EYE_EVENTS)
    ns.OnEditMode(EditEdge)
    SetEyeWatch(true)
end
