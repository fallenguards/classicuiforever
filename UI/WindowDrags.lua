local _, ns = ...

-- A window's drags: our title strip's, and another addon's on a game window we watch; the handles' tables through
-- ns.windowEdit (UI/WindowHandles.lua).

local W = ns.windowEdit
local Plain = ns.Safe
local weak = { __mode = "k" }
local ourDrag = setmetatable({}, weak)   -- window frame -> true while our strip drags it
local lastLeft = setmetatable({}, weak)  -- window frame -> where it was drawn on the drag's last frame
local lastTop = setmetatable({}, weak)

-- Where a dragged window is drawn, kept for a stop that leaves it no anchor.
local function Keep(frame)
    local left, top = Plain(frame:GetLeft()), Plain(frame:GetTop())
    if left and top then lastLeft[frame], lastTop[frame] = left, top end
end

-- StartMoving calls no SetPoint: a window's followers (the spellbook's casting layer) are told each frame mid drag.
local function FollowDragged()
    for frame in pairs(W.Moving) do
        if frame.OnClassicPlaced then frame:OnClassicPlaced() end
        Keep(frame)
    end
end
local dragJob = ns.Sched.Job({ name = "windows.dragFollow", every = 0, awake = false, fn = FollowDragged })

local function StripDragStart(self)
    local frame = self:GetParent()
    local entry = W.EntryOf[frame]
    if (InCombatLockdown() and (entry.calm or ns.WindowLocked(frame))) or W.Full(entry, frame) then return end
    W.Moving[frame] = true
    ourDrag[frame] = true
    ns.Sched.LetGo(frame, true)
    -- Held on the screen while dragged.
    W.ClampWas[frame] = frame:IsClampedToScreen() and true or false
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:StartMoving()
    dragJob:Wake()
end

-- StopMovingOrSizing drops the anchors of a frame others hang on: read where it was drawn first, then set it there.
local function StripDragStop(self)
    local frame = self:GetParent()
    if not W.Moving[frame] then return end
    local entry = W.EntryOf[frame]
    W.SaveFrom(entry, frame)
    frame:StopMovingOrSizing()
    if frame.SetUserPlaced then pcall(frame.SetUserPlaced, frame, false) end
    W.Moving[frame] = nil
    ourDrag[frame] = nil
    if not next(W.Moving) then dragJob:Sleep() end
    frame:SetClampedToScreen(W.ClampWas[frame] == true)
    -- All, so a window sharing the place is watched from its first one.
    W.PlaceAll()
    ns.Sched.LetGo(frame, false)
end

-- A fight starting mid drag: the window stops where it is while it can still be told to (the fight's first event
-- runs before the lockdown); told at the release instead, a protected window (the map in fights) refuses and keeps
-- following the cursor till the fight ends.
ns.EventFrame("PLAYER_REGEN_DISABLED", function()
    for frame in pairs(W.Moving) do
        local strip = W.Strips[frame]
        if ourDrag[frame] and strip then StripDragStop(strip) end
    end
end)

-- The title strip that drags an unlocked window; nothing on a locked one.
local function Strip(entry)
    local frame = ns.WindowFrame(entry)
    if not frame then return end
    local strip = W.Strips[frame]
    if not W.IsFree(entry) or ns.MoverHolds(frame) then
        if strip then strip:Hide() end
        return
    end
    if not strip then
        strip = ns.NewFrame("Frame", nil, frame)
        ns.MarkWindowPiece(strip)
        strip:EnableMouse(true)
        strip:RegisterForDrag("LeftButton")
        strip:SetScript("OnDragStart", StripDragStart)
        strip:SetScript("OnDragStop", StripDragStop)
        W.Strips[frame] = strip
    end
    -- The height may follow an option (the social window's title-only drag).
    local h = entry.stripH
    if type(h) == "function" then h = h() end
    h = h or W.STRIP_H
    if strip.h ~= h then
        strip.h = h
        strip:ClearAllPoints()
        strip:SetPoint("TOPLEFT", frame, "TOPLEFT", W.STRIP_LEFT, 0)
        strip:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -(entry.stripRight or W.STRIP_RIGHT), -h)
    end
    ns.SetLevelIf(strip, frame:GetFrameLevel() + W.STRIP_LIFT)
    -- The client's controls in the title bar (the social window's status drop-down) keep their clicks over the strip.
    for _, name in ipairs(entry.over or ns.EMPTY) do
        local control = _G[name]
        if control and not ns.IsForbidden(control) then ns.SetLevelIf(control, frame:GetFrameLevel() + W.STRIP_LIFT + 1) end
    end
    if not strip:IsShown() then strip:Show() end
end

-- Another addon dragging a game window we watch (a map addon's map): with our move helpers anchored to it, StartMoving leaves
-- it with no anchor and no rect at once, and the stop with no anchor, which that addon reads, saves and sets back as nil. Our
-- hooks run after each call: a broken start is ended and redone with the helpers let go; a bare stop gets an anchor where drawn.
local repairing = false
local function Anchor(frame, left, top)
    if left and top then frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top) end
end
local function ForeignDragStart(frame)
    if repairing or ourDrag[frame] or W.Moving[frame] or InCombatLockdown() then return end
    W.Moving[frame] = true
    if Plain(frame:GetLeft()) == nil and lastLeft[frame] then
        repairing = true
        frame:StopMovingOrSizing()
        ns.Sched.LetGo(frame, true)
        Anchor(frame, lastLeft[frame], lastTop[frame])
        frame:StartMoving()
        repairing = false
    else
        ns.Sched.LetGo(frame, true)
    end
    Keep(frame)
    dragJob:Wake()
end
local function ForeignDragStop(frame)
    if repairing or ourDrag[frame] or not W.Moving[frame] then return end
    W.Moving[frame] = nil
    if not next(W.Moving) then dragJob:Sleep() end
    -- With the stop's own anchor the helpers are refused on the window (anchor families): anchored by us where drawn.
    local left, top = Plain(frame:GetLeft()) or lastLeft[frame], Plain(frame:GetTop()) or lastTop[frame]
    if left and top then
        frame:ClearAllPoints()
        Anchor(frame, left, top)
    end
    local entry = W.EntryOf[frame]
    if W.PlaceOf(entry) and W.Worn(entry) then W.SaveFrom(entry, frame) end
    ns.Sched.LetGo(frame, false)
end

W.Strip, W.ForeignDragStart, W.ForeignDragStop, W.KeepDrawn = Strip, ForeignDragStart, ForeignDragStop, Keep
