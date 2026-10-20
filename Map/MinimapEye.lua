local _, ns = ...
local L = ns.L

-- Queue eye (its own edit mode system) in Era's look. The game's edit mode places and sizes it; with Snap to minimap it
-- sits on the minimap's rim, toward that place (Era's spot until moved). Our rows hang under edit mode's dialog for it:
-- Snap to minimap, Show when not queued (our icon riding it, Map/MinimapMicro.lua) and Default Size.

local MM = ns.MM
local B = ns.band

local SIZE = 32   -- a ring button's (Map/MinimapButton.lua)
-- Era's LFG-Eye sheet: 29 frames of 64 on 512 x 256, 0.1 s each (its LFGEye.lua).
local FRAMES, PER_ROW, FRAME_U, FRAME_V, FRAME_TIME = 29, 8, 64 / 512, 64 / 256, 0.1
-- Outside edit mode only these move or resize the eye (probe P2); the spec change can switch the active layout.
local EYE_EVENTS = { "EDIT_MODE_LAYOUTS_UPDATED", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED", "PLAYER_ENTERING_WORLD",
    "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_REGEN_ENABLED" }
local EYE_LOOK = 0.3   -- polling after each wake, for a client move that lands a few frames late
-- Era's eye on the rim (degrees), and the rim's reach past the map's edge (a ring button's).
local ERA_ANGLE, RIM_OUT = 137, 5

local eyeWatch
local extra       -- our rows under edit mode's dialog for the eye
local lookUntil = 0
local over, face  -- our look over the game's eye, and its Era eye
local frame = 0
local snapped = false   -- the eye's points ours (on the rim) until edit mode's go back
local rimX, rimY        -- its offsets there

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

-- Edit mode drags the eye by its selection box: the eye itself never reads as dragged.
local function Dragged(eye)
    return eye.Selection ~= nil and eye.Selection:IsDragging() or false
end

local function EyeMoved(eye)
    return ns.InDefaultPosition(eye) == false
end

-- Edit mode's saved anchor for the eye, read where its own points are ours (on the rim).
local function Anchor(eye)
    local info = eye.systemInfo and eye.systemInfo.anchorInfo
    if type(info) == "table" and info.point and info.relativePoint then return info end
end

-- Where edit mode has the eye: its centre in UIParent units, read on a stand-in of its size and scale.
local probe
local function EditModeCenter(eye)
    local info = Anchor(eye)
    if not info then return nil end
    probe = probe or CreateFrame("Frame", nil, UIParent)
    local scale = ns.Safe(eye:GetScale()) or 1
    probe:SetScale(scale)
    probe:SetSize(SIZE, SIZE)
    probe:ClearAllPoints()
    if not pcall(probe.SetPoint, probe, info.point, info.relativeTo, info.relativePoint, (info.offsetX or 0) / scale,
        (info.offsetY or 0) / scale) then return nil end
    local x, y = probe:GetCenter()
    local k = ns.WindowRatio(probe)
    if not (x and y and k) then return nil end
    return x * k, y * k
end

-- The rim's angle: toward edit mode's place, or at its default Era's spot (or the angle an older version kept for our
-- icon there, until the eye is placed in edit mode: then its reset is Era's spot).
local function SnapAngle(eye)
    if not EyeMoved(eye) then return ns.db.lfgButtonAngle or ERA_ANGLE end
    ns.db.lfgButtonAngle = nil
    local x, y = EditModeCenter(eye)
    local mx, my = Minimap:GetCenter()
    local mk = ns.WindowRatio(Minimap)
    if not (x and mx and mk) then return nil end
    return math.deg(math.atan2(y - my * mk, x - mx * mk)) % 360
end

-- An install from before Snap to minimap: the eye stood on the rim on our icon, or at Era's spot until moved; one moved
-- with our icon off stood free, and keeps standing free.
local function Decide(eye)
    if ns.db.eyeSnapMinimap ~= "auto" then return end
    local home = ns.InDefaultPosition(eye, true)
    if home == nil then return end
    ns.db.eyeSnapMinimap = home or ns.db.lfgMinimapButton ~= false
end

-- Edit mode's place back after the rim; at its default the game's container lays it again on its next pass.
local function Unsnap(eye)
    if not snapped then return end
    snapped = false
    local info = Anchor(eye)
    if not info or not EyeMoved(eye) then return end
    local scale = ns.Safe(eye:GetScale()) or 1
    eye:ClearAllPoints()
    pcall(eye.SetPoint, eye, info.point, info.relativeTo, info.relativePoint, (info.offsetX or 0) / scale,
        (info.offsetY or 0) / scale)
end

local function PlaceEye()
    local eye = QueueStatusButton
    if not eye or not Minimap then return end
    -- A ring button's look over the game's eye, which fades; its glow stays (a group found). Border and eye are the
    -- button's children, so edit mode's size scales both.
    if not over then
        over = CreateFrame("Frame", nil, eye)
        over:SetSize(SIZE, SIZE)
        face = ns.RingLook(over, ns.EraEyeFace)
        -- Era's eye press; its hide watched on our face's frame, not the game's eye.
        ns.RingPressable(eye, face, over)
        ns.DressStates(eye, nil, nil, nil, "zoomHighlight", ns.RING_HIGHLIGHT)
        ns.Sched.Attach(over, { name = "minimap.eyeTurn", every = FRAME_TIME, fn = Turn })
    end
    if eye.Eye then ns.SetAlphaIf(eye.Eye, 0) end
    if not over:IsShown() then over:Show() end
    over:SetFrameLevel(eye:GetFrameLevel() + 5)
    ns.SetPointOnce(over, "CENTER", eye, "CENTER", 0, 0)
    ns.SetSizeIf(eye, SIZE, SIZE)
    -- On the rim the minimap's edit mode box covers the eye's: lift it to HIGH.
    if eye.Selection and eye.Selection.SetFrameStrata and eye.Selection:GetFrameStrata() ~= "HIGH" then
        eye.Selection:SetFrameStrata("HIGH")
    end
    if Dragged(eye) or InCombatLockdown() then return end
    if eye:GetParent() ~= UIParent then eye:SetParent(UIParent) end
    Decide(eye)
    if ns.db.eyeSnapMinimap == false then
        Unsnap(eye)
    else
        local angle = SnapAngle(eye)
        if angle then
            local k = eye:GetEffectiveScale() / Minimap:GetEffectiveScale()
            ns.RingPoint(eye, angle, Minimap:GetWidth() / 2 + RIM_OUT, k)
            snapped = true
            rimX, rimY = select(4, eye:GetPoint(1))
        end
    end
    -- Our icon rides the eye: its spot and size follow.
    if ns.PlaceRingButton then ns.PlaceRingButton("minimapGroupFinder") end
end
MM.PlaceEye = PlaceEye

-- Our minimap off: the game's own eye back, at the place edit mode gave it.
function MM.UnplaceEye()
    local eye = QueueStatusButton
    if not eye or not over then return end
    over:Hide()
    if eye.Eye then ns.SetAlphaIf(eye.Eye, 1) end
    if not InCombatLockdown() then Unsnap(eye) end
end

-- Written as the interface reloads, never mid-game.
local function DefaultSizeClick() ns.AskSizeReset("eyeSize", "group finder eye") end

-- Our rows under edit mode's dialog for the eye, beside it, not in it (the dialog would count a child into its size).
local function Extra()
    if extra then return extra end
    extra = CreateFrame("Frame", "ForeverClassicUIEyeExtra", UIParent)
    extra:SetFrameStrata("DIALOG")
    extra:SetFrameLevel(200)
    extra:SetHeight(108)
    extra:Hide()
    B.PanelBorder(extra)
    extra.snap = B.DialogCheck(extra, extra, "TOPLEFT", 22, -14, L["MAP_EYE_SNAP"], function(self)
        ns.db.eyeSnapMinimap = self:GetChecked() and true or false
        ns.ToggleChanged("eyeSnapMinimap")
    end)
    extra.idle = B.DialogCheck(extra, extra.snap, "BOTTOMLEFT", 0, -2, L["MAP_EYE_IDLE"], function(self)
        ns.db.lfgMinimapButton = self:GetChecked() and true or false
        ns.ToggleChanged("lfgMinimapButton")
    end)
    extra.resize = B.DialogFoot(extra, L["MAP_EYE_OPTIONS_APPLY"], L["MAP_DEFAULT_SIZE"], DefaultSizeClick)
    return extra
end

local function FollowDialog()
    local dialog, eye = EditModeSystemSettingsDialog, QueueStatusButton
    local up = MM.active and ns.EditMode.state and dialog and dialog:IsShown() and eye and dialog.attachedToSystem == eye
    if not up then
        if extra and extra:IsShown() then extra:Hide() end
        return
    end
    Extra()
    extra:ClearAllPoints()
    extra:SetPoint("TOPLEFT", dialog, "BOTTOMLEFT", 0, 6)
    extra:SetPoint("TOPRIGHT", dialog, "BOTTOMRIGHT", 0, 6)
    extra.snap:SetChecked(ns.db.eyeSnapMinimap ~= false)
    extra.idle:SetChecked(ns.db.lfgMinimapButton ~= false)
    local revert = dialog.Buttons and dialog.Buttons.RevertChangesButton
    if revert then
        extra.resize:ClearAllPoints()
        extra.resize:SetPoint("LEFT", revert, "RIGHT", 6, 0)
        extra.resize:SetPoint("RIGHT", dialog.Buttons, "RIGHT", 0, 0)
        extra.resize:SetEnabled(not ns.Near(eye:GetScale(), 1, 0.001))
    end
    extra.resize:SetShown(revert ~= nil)
    extra:Show()
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

-- Edit mode's place for the eye as one number pair, to see it change (a drop, a revert, a reset).
local function AnchorSig(eye)
    local info = Anchor(eye)
    if not info then return 0, 0 end
    return info.offsetX or 0, info.offsetY or 0
end

-- The game lays the eye again at its own spot, with no event (a minimap scale change, the micro menu's layout, a queue).
local function OffRim(eye)
    return snapped and ns.IsAt(eye, "CENTER", Minimap, "CENTER", rimX, rimY, 0.01) ~= true
end

-- No events for moves, resets or size changes in edit mode: poll there. The settings dialog shows only in edit mode.
local function EyeTick(job, now)
    local editing = ns.EditMode.state
    if editing then FollowDialog() end
    local eye = QueueStatusButton
    if MM.active and eye then
        local moved, scale = EyeMoved(eye), eye:GetEffectiveScale()
        local dragging = Dragged(eye)
        local ax, ay = AnchorSig(eye)
        local icon = ns.GroupFinderIcon()
        if moved ~= job.moved or scale ~= job.scale or dragging ~= job.dragging or ax ~= job.ax or ay ~= job.ay
            or icon ~= job.icon or (not dragging and OffRim(eye)) then
            job.moved, job.scale, job.dragging, job.ax, job.ay, job.icon = moved, scale, dragging, ax, ay, icon
            PlaceEye()
        end
    end
    if not editing and now >= lookUntil then SetEyeWatch(false) end
end

-- Entry wakes the poll; exit takes one look (the client reverts or saves the layout), and the dialog, ours with it.
local function EditEdge()
    if not ns.EditMode.state and extra then extra:Hide() end
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
    -- Its move wakes the watch, which puts it back on the rim.
    if QueueStatusButton then ns.Sched.OnMove(QueueStatusButton, EyeEvent) end
    SetEyeWatch(true)
end

ns.OnToggle(function(key)
    if key == "eyeSnapMinimap" and MM.active and eyeWatch then SetEyeWatch(true) end
end)

-- dbVersion 18: Snap to minimap is new. Existing installs decide at the first look (Decide), in the account and every
-- profile; the active profile is read after.
function ns.EyeSnapToDecide()
    local db = ns.db
    local function Mark(t)
        if t.eyeSnapMinimap == nil then t.eyeSnapMinimap = "auto" end
    end
    Mark(db)
    for _, shot in pairs(type(db.profiles) == "table" and db.profiles or {}) do
        if type(shot) == "table" then Mark(shot) end
    end
    db.dbVersion = 18
end
