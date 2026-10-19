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
    ns.MM.BlobRings(on and ns.MM.Square())
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
-- Not while Rotate Minimap is on: the game turns the map's mask with it, so a square one turns into a diamond.
local MM = ns.MM
function MM.Square()
    return MM.active and ns.db.minimapSquare == true and not ns.GetCVarBool("rotateMinimap")
end
-- The game rings a quest, bonus objective or dig site area round the map's round edge (a hatched band): off on the
-- square map, back at the engine's 1 once round (the client never sets them).
local RING_SETTERS = { "SetQuestBlobRingAlpha", "SetQuestBlobRingScalar", "SetTaskBlobRingAlpha",
    "SetTaskBlobRingScalar", "SetArchBlobRingAlpha", "SetArchBlobRingScalar" }
local ringsOff = false
function MM.BlobRings(off)
    off = off and true or false
    if off == ringsOff then return end
    ringsOff = off
    for _, name in ipairs(RING_SETTERS) do
        if Minimap[name] then Minimap[name](Minimap, off and 0 or 1) end
    end
end
-- Other addons' minimap buttons ask the shape (the convention minimap button libraries follow); kept if one exists.
if _G.GetMinimapShape == nil then
    function _G.GetMinimapShape() return MM.Square() and "SQUARE" or "ROUND" end
end

-- Our minimap off: the client's round shape, and the map open.
function MM.MapBack(wasSquare)
    MM.Reopen()
    if wasSquare and Minimap and Minimap.SetMaskTexture then Minimap:SetMaskTexture((ns.TexPath("portraitMask"))) end
end

-- Rotate Minimap turned (edit mode or a layout's apply): the map round or square again, the option grayed or not.
ns.EventFrame("CVAR_UPDATE", function(_, _, name)
    if name ~= "rotateMinimap" then return end
    if MM.active and ns.db.minimapSquare then ns.Sched.NextFrame("minimap.rotate", MM.Relayout) end
    if ns.RefreshOptionsWindow then ns.RefreshOptionsWindow() end
end)
