local _, ns = ...

-- Era shows the side bars' empty slots while the spellbook is open (its OnShow, the client's spell collection reason).
-- Ours: the book's secure layer sets a bit of our own in each button's "showgrid" and shows its empty slots as it
-- opens, and clears it as it shuts. From a snippet, so in a fight too, and the attribute the bars read stays clean.

local BARS = { "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft", "MultiBar5", "MultiBar6",
    "MultiBar7" }
local SLOTS = 12

-- 1024: clear of the client's reasons (1, 2, 4). A button the bar holds back ("statehidden") stays hidden.
local GRID_ON = [[
    for i = 1, control:GetAttribute("count") or 0 do
        local button = control:GetFrameRef("b" .. i)
        local grid = button:GetAttribute("showgrid") or 0
        if grid % 2048 < 1024 then button:SetAttribute("showgrid", grid + 1024) end
        if not button:GetAttribute("statehidden") then button:Show() end
    end
]]
local GRID_OFF = [[
    for i = 1, control:GetAttribute("count") or 0 do
        local button = control:GetFrameRef("b" .. i)
        local grid = button:GetAttribute("showgrid") or 0
        if grid % 2048 >= 1024 then
            grid = grid - 1024
            button:SetAttribute("showgrid", grid)
        end
        if grid == 0 and not HasAction(control:GetAttribute("s" .. i)) then button:Hide() end
    end
]]

-- The buttons the snippets walk: shown bars, within each bar's button count, with their action slots. Out of combat;
-- a fight opens with what it was as the fight began.
local function Gather(wrap)
    if InCombatLockdown() then return end
    local n = 0
    for _, name in ipairs(BARS) do
        local bar = _G[name]
        local page = bar and bar:IsShown() and bar:GetAttribute("actionpage")
        if page then
            for i = 1, math.min(SLOTS, bar.numButtonsShowable or SLOTS) do
                local button = _G[name .. "Button" .. i]
                if button then
                    n = n + 1
                    wrap:SetFrameRef("b" .. n, button)
                    wrap:SetAttribute("s" .. n, (page - 1) * SLOTS + i)
                end
            end
        end
    end
    wrap:SetAttribute("count", n)
end

-- On the book's layer; returns the gather, for the book to run before it opens the layer itself.
function ns.BookGrid(layer)
    local wrap = CreateFrame("Frame", nil, UIParent, "SecureHandlerBaseTemplate")
    SecureHandlerWrapScript(layer, "OnShow", wrap, GRID_ON)
    SecureHandlerWrapScript(layer, "OnHide", wrap, GRID_OFF)
    local function GatherNow() Gather(wrap) end
    -- Its own click (key, micro pad) opens it out of combat too.
    layer:HookScript("PreClick", GatherNow)
    ns.EventFrame({ "PLAYER_ENTERING_WORLD", "EDIT_MODE_LAYOUTS_UPDATED", "PLAYER_REGEN_DISABLED" }, GatherNow)
    return GatherNow
end
