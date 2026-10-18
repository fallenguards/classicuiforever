local _, ns = ...

-- Another addon's square-map border (an unnamed backdrop frame round the map) fades while our round minimap is on (#108);
-- each goes back to the alpha it had as ours turns off.

local faded = setmetatable({}, { __mode = "k" })   -- frame -> its alpha before

-- Centered on the map and at least its size: a frame round it, not a pin or a button on it.
local function SquareBorder(child)
    if faded[child] or child:GetName() or type(child.GetBackdrop) ~= "function" then return false end
    local ok, backdrop = pcall(child.GetBackdrop, child)
    if not ok or type(backdrop) ~= "table" or not backdrop.edgeFile then return false end
    local x, y = child:GetCenter()
    local mx, my = Minimap:GetCenter()
    local w, mw = child:GetWidth(), Minimap:GetWidth()
    if ns.AnySecret(x, y, mx, my, w, mw) or not (x and mx and w and mw) then return false end
    return ns.Near(x, mx, 2) and ns.Near(y, my, 2) and w >= mw
end

local function Fade(child)
    if SquareBorder(child) then faded[child] = child:GetAlpha() end
    if faded[child] then ns.SetAlphaIf(child, 0) end
end

function ns.FadeSquareBorders(on)
    if not Minimap then return end
    if on then
        ns.EachChild(Minimap, Fade)
        return
    end
    for frame, alpha in pairs(faded) do
        frame:SetAlpha(alpha)
        faded[frame] = nil
    end
end

-- Square minimap (our own option): the map square, its border Era's ring made square, our rim pieces along its edge.
local MM = ns.MM
function MM.Square()
    return MM.active and ns.db.minimapSquare == true
end
-- Other addons' minimap buttons ask the shape (the convention minimap button libraries follow); kept if one exists.
if _G.GetMinimapShape == nil then
    function _G.GetMinimapShape() return MM.Square() and "SQUARE" or "ROUND" end
end
