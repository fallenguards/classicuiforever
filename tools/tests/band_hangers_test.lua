-- Offline test under Lua 5.4 for a piece the player snapped to a band bar (Bar/BandHangers.lua UnhookPieces). Outside
-- edit mode the game holds the bar's own frame at its spot while the band draws the buttons elsewhere, so a snap
-- measured on the frame put the totem bar three slots right of where edit mode showed it (#263). The screen anchor is
-- measured on the bar's drawn box (its slots); a holder with no buttons, or a bar whose buttons are not on slots,
-- keeps its frame.
-- Run from the addon root: lua tools/tests/band_hangers_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 212

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local failed = 0
local function Check(ok, what)
    if not ok then
        failed = failed + 1
        print("FAIL " .. what)
    end
end

-- Frames with a box; an anchor by BOTTOMLEFT or TOPLEFT lands the box, as the client lays it.
local function Frame(name, left, bottom, w, h, parent)
    local f = { name = name, left = left, bottom = bottom, w = w, h = h, parent = parent }
    function f:GetLeft() return self.left end
    function f:GetBottom() return self.bottom end
    function f:GetTop() return self.bottom + self.h end
    function f:GetScale() return 1 end
    function f:GetParent() return self.parent end
    function f:SetSize(width, height) self.w, self.h = width, height end
    return f
end
UIParent = Frame("UIParent", 0, 0, 1600, 900)
function InCombatLockdown() return false end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end

local art = Frame("ForeverClassicUIBar", 0, 0, 1024, 53, UIParent)
local bar2 = Frame("MultiBarBottomLeft", 372, 56, 498, 36, UIParent)   -- the game's own spot
bar2.actionButtons = {}
local drawn = { 255, 753, 91, 55 }                                       -- left, right, top, bottom as the band draws it
local xp = Frame("MainStatusTrackingBarContainer", 2, 42, 1020, 10, art)
_G.MultiBarBottomLeft, _G.MainStatusTrackingBarContainer = bar2, xp

local anchors, made = {}, 0
local ns = {
    band = { OWNED_SYSTEMS = { "MultiBarBottomLeft", "MainStatusTrackingBarContainer" }, art = art,
        SystemMoved = function() return false end,
        ColumnBox = function(bar) if bar == bar2 and drawn then return drawn[1], drawn[2], drawn[3], drawn[4] end end },
    EditMode = { Live = function() return false end },
    InDefaultPosition = function() return false end,
    Safe = function(v) return v end,
    NewFrame = function(_, name, parent) made = made + 1 return Frame(name or "measure", 0, 0, 0, 0, parent) end,
    SetSizeIf = function(frame, w, h) frame:SetSize(w, h) end,
}
local function Anchor(piece, point, rel, relPoint, x, y)
    anchors[#anchors + 1] = { piece, point, rel, relPoint, x, y }
    local relY = relPoint == "TOPLEFT" and rel:GetTop() or rel:GetBottom()
    piece.left, piece.bottom = rel:GetLeft() + x, relY + y
end
ns.SetPointOnce, ns.SetPointIf = Anchor, Anchor
assert(loadfile(ROOT .. "/Bar/BandHangers.lua"))("ClassicUIForever", ns)
local B = ns.band

local function AnchorOf(piece)
    for i = #anchors, 1, -1 do
        if anchors[i][1] == piece then return anchors[i] end
    end
end

local totem = Frame("MultiCastActionBarFrame", 0, 0, 230, 38, UIParent)
totem.systemInfo = { anchorInfo = { point = "BOTTOMLEFT", relativeTo = "MultiBarBottomLeft", relativePoint = "TOPLEFT",
    offsetX = 0, offsetY = 4 } }
local xpRider = Frame("Rider", 0, 0, 50, 10, UIParent)
xpRider.systemInfo = { anchorInfo = { point = "BOTTOMLEFT", relativeTo = "MainStatusTrackingBarContainer",
    relativePoint = "TOPLEFT", offsetX = 10, offsetY = 0 } }
EditModeManagerFrame = { registeredSystemFrames = { totem, xpRider, bar2, xp } }

B.UnhookPieces()
local last = AnchorOf(totem)
Check(last and last[3] == UIParent and last[2] == "BOTTOMLEFT", "the totem bar hangs on the screen")
Check(totem.left == 255 and totem.bottom == 95, "at the spot its snap gives on the drawn bar ("
    .. tostring(totem.left) .. "," .. tostring(totem.bottom) .. ")")
Check(xpRider.left == 12 and xpRider.bottom == 52, "a piece on a holder with no buttons measures on the holder")
B.UnhookPieces()
Check(made == 1, "one measuring frame for every pass")

-- The bar's buttons not on slots (no drawn box): its own frame.
anchors, drawn = {}, nil
B.UnhookPieces()
Check(totem.left == 372 and totem.bottom == 96, "a bar with no drawn box measures on its frame ("
    .. tostring(totem.left) .. "," .. tostring(totem.bottom) .. ")")
drawn = { 255, 753, 91, 55 }

-- Edit mode open: the game's own snap back on the frame, so its drags and snaps work as the game's.
anchors = {}
B.RehookPieces()
local back = AnchorOf(totem)
Check(back and back[3] == bar2 and back[4] == "TOPLEFT", "edit mode puts the snap back on the frame")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("band_hangers_test: all checks passed")
