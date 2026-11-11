local _, ns = ...

-- The chat's alert container (the friends button first in it, toasts above it) over the chat column's top button by
-- the screen's coordinates, never hung on the chat: a non-child on a frame another addon sizes ends its stop with no
-- points (#247, the text-to-speech button rides the container). Friends hidden, it stands over the chat's top left.

local ALERTS_UP = 4
-- The client's own foot for its chat alerts: 27 over ChatFrame1's top, clear of the tabs.
local TOAST_UP = 27
local TOASTS = { "BNToastFrame", "TimeAlertFrame", "VoiceChatPromptActivateChannel", "VoiceChatChannelActivatedNotification" }
-- The world refresh toast: hung once at load on the container's top left at this offset, outside its stack.
local SHARD, SHARD_X, SHARD_Y = "ShardTransferImminentFrame", 30, 55
local was   -- the container's own width and points, for the hand-back
local lifting   -- toasts kept over the chat while the column carries the container
local shardMoved

local function Save(alerts)
    if was then return end
    was = { w = alerts:GetWidth(), n = alerts:GetNumPoints() }
    for i = 1, was.n do was[i] = { alerts:GetPoint(i) } end
end

-- The container stacks its alerts from its foot: an unseen friends button under it stood it 40 up, so the button's
-- measured rise is taken off.
local function Rise(alerts)
    local quick = _G["QuickJoinToastButton"]
    local qb, ab = quick and quick:IsShown() and quick:GetBottom(), alerts:GetBottom()
    if not (qb and ab) or ns.AnySecret(qb, ab) then return 0 end
    return math.max(0, math.floor((qb * quick:GetEffectiveScale() - ab * alerts:GetEffectiveScale()) / alerts:GetEffectiveScale() + 0.5))
end

-- A toast stacks on the column's top button, over the text of a chat taller than the column: up to the client's own
-- spot over the chat, never down. Run after the client's show pass, ahead of the draw.
local function LiftToasts()
    local chat = lifting and _G.ChatFrame1
    local top = chat and chat:GetTop()
    if not top or ns.AnySecret(top) then return end
    for _, name in ipairs(TOASTS) do
        local toast = _G[name]
        if toast and toast:IsShown() then
            local left, bottom = toast:GetLeft(), toast:GetBottom()
            local foot = top * chat:GetEffectiveScale() / toast:GetEffectiveScale() + TOAST_UP
            if left and bottom and not ns.AnySecret(left, bottom) and bottom < foot - 0.5 then
                ns.SetPointOnce(toast, "BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, foot)
            end
        end
    end
end

-- The world refresh toast keeps riding the container, its offset raised to the same foot over the chat.
local function LiftShard(alerts)
    local toast, chat = _G[SHARD], _G.ChatFrame1
    local top, alertsTop = chat and chat:GetTop(), alerts:GetTop()
    if not (toast and top and alertsTop) or ns.AnySecret(top, alertsTop) then return end
    local scale = toast:GetEffectiveScale()
    local y = (top * chat:GetEffectiveScale() - alertsTop * alerts:GetEffectiveScale()) / scale + TOAST_UP
    ns.SetPointOnce(toast, "BOTTOMLEFT", alerts, "TOPLEFT", SHARD_X, math.max(SHARD_Y, y))
    shardMoved = true
end

-- rel: the column's top button; chat: its window; friendsOff: the friends button hidden by us; width: the column's.
function ns.PlaceChatAlerts(rel, chat, friendsOff, width)
    local alerts = _G.ChatAlertFrame
    if not alerts then return end
    Save(alerts)
    lifting = true
    for _, name in ipairs(TOASTS) do
        if _G[name] then ns.Sched.AfterShow(_G[name], "chat.toast", LiftToasts) end
    end
    alerts:SetWidth(width)
    local base = friendsOff and chat or rel
    local left, top, right = base:GetLeft(), base:GetTop(), base:GetRight()
    if not (left and top and right) or ns.AnySecret(left, top, right) then return end
    local k = base:GetEffectiveScale() / alerts:GetEffectiveScale()
    local y = top * k + ALERTS_UP - Rise(alerts)
    if base == chat then
        ns.SetPointOnce(alerts, "BOTTOMLEFT", UIParent, "BOTTOMLEFT", left * k, y)
    else
        ns.SetPointOnce(alerts, "BOTTOM", UIParent, "BOTTOMLEFT", (left + right) / 2 * k, y)
    end
    LiftShard(alerts)
end

-- The container's own width and points again (the classic chat off).
function ns.RestoreChatAlerts()
    local alerts = _G.ChatAlertFrame
    lifting = nil
    if shardMoved and alerts and _G[SHARD] then
        ns.SetPointOnce(_G[SHARD], "BOTTOMLEFT", alerts, "TOPLEFT", SHARD_X, SHARD_Y)
        shardMoved = nil
    end
    if not (was and alerts) then return end
    alerts:SetWidth(was.w)
    alerts:ClearAllPoints()
    for i = 1, was.n do
        local p = was[i]
        alerts:SetPoint(p[1], p[2] or alerts:GetParent(), p[3], p[4], p[5])
    end
    was = nil
end
