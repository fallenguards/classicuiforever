local _, ns = ...
local L = ns.L
local B = ns.band

-- Hide This Bar for either status bar: its bars unseen with no mouse, and a box of ours under edit mode's dialog. The
-- client's segment posts kept unseen under our strips.

local SetAlphaIf = ns.SetAlphaIf

-- The client's segment posts on a holder (from its pool); the strip draws the 1.x ones. One faded post per holder is
-- kept as its sample (weak).
local samplePost = setmetatable({}, { __mode = "k" })
function B.SetDividers(container, alpha)
    local pool = container and container.HorizontalDividersPool
    if not (pool and pool.EnumerateActive) then return end
    local sample
    for divider in pool:EnumerateActive() do
        divider:SetAlpha(alpha)
        sample = sample or divider
    end
    samplePost[container] = alpha == 0 and sample or nil
end

-- Faded posts back at full alpha with no rebuild, as the holder's fade-in ends (a login in a fight kept them all fight).
function B.PostsBack(container)
    local post = samplePost[container]
    return post ~= nil and post:IsShown() and post:GetAlpha() > 0.01
end

-- Posts faded per holder (weak): a released post keeps alpha 0 (the pool's reset only hides), so only a grown pool is walked.
local fadedCount = setmetatable({}, { __mode = "k" })
function B.FadeNewDividers(container)
    local pool = container and container.HorizontalDividersPool
    if not (pool and pool.GetNumActive and pool.EnumerateActive) then return end
    local count = pool:GetNumActive()
    if count <= (fadedCount[container] or 0) then return end
    for divider in pool:EnumerateActive() do SetAlphaIf(divider, 0) end
    fadedCount[container] = count
end
function B.ForgetFadedPosts() wipe(fadedCount) end

-- Hide This Bar (the client has no such setting): per holder, kept in our settings.
local function HideKey(holder)
    if holder == nil then return nil end
    if holder == MainStatusTrackingBarContainer then return "hideStatusMain" end
    if holder == SecondaryStatusTrackingBarContainer then return "hideStatusSecond" end
    return nil
end

local function StatusHidden(holder)
    local key = HideKey(holder)
    return key ~= nil and ns.db ~= nil and ns.db[key] == true
end
B.StatusHidden = StatusHidden

-- A hidden holder's bars go unseen and take no mouse; the client fades only the holder, never its bars.
local barsHidden = setmetatable({}, { __mode = "k" })
function B.ShowHolderBars(container)
    local hide = StatusHidden(container)
    if not hide and not barsHidden[container] then return end
    for _, bar in pairs(container.bars or {}) do
        SetAlphaIf(bar, hide and 0 or 1)
        if bar.EnableMouse and bar:IsMouseEnabled() == hide then bar:EnableMouse(not hide) end
    end
    barsHidden[container] = hide or nil
end

-- Hide This Bar under the client's dialog: a frame of ours on UIParent, never a child of the dialog's layout.
local hideBox
local function HideClick(self)
    local key = HideKey(hideBox.holder)
    if not (key and ns.db) then return end
    ns.db[key] = self:GetChecked() and true or false
    ns.ToggleChanged(key)
    B.WakeBars()
end

local function HideBox()
    hideBox = hideBox or ns.CheckPanel(190, L["BAR_HIDE_THIS_BAR"], HideClick)
    return hideBox
end

function B.FollowHideBox(dialog, holder)
    local key = HideKey(holder)
    if not key then
        if hideBox and hideBox:IsShown() then hideBox:Hide() end
        return
    end
    local box = HideBox()
    box.holder = holder
    ns.SetLevelIf(box, math.min(dialog:GetFrameLevel() + 20, 9000))
    if not ns.IsAt(box, "TOP", dialog, "BOTTOM", 0, 4) then ns.SetPointOnce(box, "TOP", dialog, "BOTTOM", 0, 4) end
    local want = ns.db and ns.db[key] == true or false
    if box.check:GetChecked() ~= want then box.check:SetChecked(want) end
    if not box:IsShown() then box:Show() end
end

