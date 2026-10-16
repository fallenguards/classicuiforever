local _, ns = ...
local L = ns.L

-- Rested XP in the XP bar's tooltip (option, off by default): a line under the client's title (#182).

local kept = {}   -- the client's lines after its title: text, r, g, b each

local function RestedLine()
    if not (ns.db and ns.db.xpTipRested == true) then return end
    if not GameTooltip:IsShown() or GameTooltip:GetOwner() ~= UIParent then return end
    local rest, most = GetXPExhaustion(), UnitXPMax("player")
    if not rest or ns.AnySecret(rest, most) or rest <= 0 or most <= 0 then return end
    local first = _G.GameTooltipTextLeft1
    local title = first and first:GetText()
    if not title or ns.IsSecret(title) then return end
    local count = 0
    for i = 2, GameTooltip:NumLines() do
        local line = _G["GameTooltipTextLeft" .. i]
        local r, g, b = line:GetTextColor()
        kept[count + 1], kept[count + 2], kept[count + 3], kept[count + 4] = line:GetText() or " ", r, g, b
        count = count + 4
    end
    GameTooltip_SetTitle(GameTooltip, title)
    GameTooltip:AddLine(L["UI_RESTED_XP_LINE"]:format(BreakUpLargeNumbers(rest), string.format("%.1f", rest / most * 100)),
        1, 1, 1, true)
    for i = 1, count, 4 do GameTooltip:AddLine(kept[i], kept[i + 1], kept[i + 2], kept[i + 3], true) end
    GameTooltip:Show()
end

ns.EventFrame("PLAYER_LOGIN", function()
    for _, container in ipairs({ MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer }) do
        for _, bar in pairs(container and container.bars or {}) do
            if bar.ExhaustionTick then ns.HookScriptOnce(bar, "OnEnter", RestedLine) end
        end
    end
end)
