local _, ns = ...

-- The chat's alert container (the friends button first in it, toasts above it) over the chat column's top button by
-- the screen's coordinates, never hung on the chat: a non-child on a frame another addon sizes ends its stop with no
-- points (#247, the text-to-speech button rides the container). Friends hidden, it stands over the chat's top left.

local ALERTS_UP = 4
local was   -- the container's own width and points, for the hand-back

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

-- rel: the column's top button; chat: its window; friendsOff: the friends button hidden by us; width: the column's.
function ns.PlaceChatAlerts(rel, chat, friendsOff, width)
    local alerts = _G.ChatAlertFrame
    if not alerts then return end
    Save(alerts)
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
end

-- The container's own width and points again (the classic chat off).
function ns.RestoreChatAlerts()
    local alerts = _G.ChatAlertFrame
    if not (was and alerts) then return end
    alerts:SetWidth(was.w)
    alerts:ClearAllPoints()
    for i = 1, was.n do
        local p = was[i]
        alerts:SetPoint(p[1], p[2] or alerts:GetParent(), p[3], p[4], p[5])
    end
    was = nil
end
