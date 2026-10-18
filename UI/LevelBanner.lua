local _, ns = ...

-- The game's level-up banners ("You've reached level", the new spells and dungeons after it): 1.x had none, so they go
-- unless Level-up banner is ticked. The toast frame (a layout frame: no watcher child of ours) moves into a full-screen
-- frame of ours, whose alpha hides it whatever its own fades do; a check runs each frame only while it is up.
local LEVEL_UP_TYPES = { "LevelUp", "LevelUpSpell", "LevelUpDungeon", "LevelUpRaid", "LevelUpPvP", "LevelUpOther" }
local levelUp = {}
local types = Enum and Enum.EventToastEventType
for _, name in ipairs(LEVEL_UP_TYPES) do
    if types and types[name] then levelUp[types[name]] = true end
end

local holder, job
local hiding = false

local function LevelToast(frame)
    local toast = frame.currentDisplayingToast
    local info = toast and toast.toastInfo
    return info ~= nil and levelUp[info.eventType] == true
end

-- Unseen and click-through while hidden: its hover would pause the toast, its click dismiss it.
local function Hide(frame, hide)
    if hide == hiding then return end
    hiding = hide
    if hide and not holder then
        holder = CreateFrame("Frame", nil, UIParent)
        holder:SetAllPoints(UIParent)
        frame:SetParent(holder)
    end
    if holder then holder:SetAlpha(hide and 0 or 1) end
    frame:EnableMouse(not hide)
end

local function Check(running)
    local frame = _G.EventToastManagerFrame
    if not frame:IsShown() then
        Hide(frame, false)
        running:Sleep()
        return
    end
    Hide(frame, ns.db ~= nil and ns.db.levelUpBanner == false and LevelToast(frame))
end

-- The game shows its toasts from this event (its own handler runs first); the next toast in a run needs no event.
ns.EventFrame("DISPLAY_EVENT_TOASTS", function()
    if not _G.EventToastManagerFrame or not next(levelUp) then return end
    job = job or ns.Sched.Job({ name = "levelBanner", every = 0, awake = false, fn = Check })
    job:Wake()
    Check(job)
end)
