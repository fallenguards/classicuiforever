-- Offline test under Lua 5.4 for a moved bags piece once edit mode closes (Bar/BandBags.lua HoldBackpackEnd). Edit mode
-- keeps the spot at the size the piece wore there (our unfolded row, 205 x 39) and, closing, lays the piece again at the
-- game's own bags bar size (247 x 45). Held by its backpack corner at that size and sized back to ours, the bags went 21
-- right and 6 down at every close (/fcuidev bagdrag, 2026-11-23). Numbers from that run; the code is cut out and run.
-- Run from the addon root: lua tools/tests/bags_moved_spot_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 122 212

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local failed = 0
local function Check(ok, what)
    if not ok then
        failed = failed + 1
        print("FAIL " .. what)
    end
end
local function Cut(path, from, to)
    local handle = assert(io.open(ROOT .. path, "r"))
    local source = handle:read("a")
    handle:close()
    local first = source:find(from, 1, true)
    local last = first and source:find(to, first, true)
    assert(first and last, path .. ": the code to test is in the file")
    return source:sub(first, last - 1)
end

-- A piece on one point against the screen's bottom left; its edges follow its size around that point.
local UIParent = {}
local SPAN = { LEFT = 0, RIGHT = 1, TOP = 1, BOTTOM = 0 }
local function Piece(point, x, y, w, h)
    local p = { point = point, x = x, y = y, w = w, h = h }
    local function Along(spot, horizontal)
        local key
        if horizontal then key = spot:match("LEFT") or spot:match("RIGHT") else key = spot:match("TOP") or spot:match("BOTTOM") end
        return key and SPAN[key] or 0.5
    end
    function p:GetSize() return self.w, self.h end
    function p:SetSize(w, h) self.w, self.h = w, h end
    function p:GetLeft() return self.x - Along(self.point, true) * self.w end
    function p:GetRight() return self:GetLeft() + self.w end
    function p:GetBottom() return self.y - Along(self.point, false) * self.h end
    function p:GetTop() return self:GetBottom() + self.h end
    function p:SetPoint(point, _, _, x, y) self.point, self.x, self.y = point, x, y end
    return p
end

local B = { Remember = function() end }
local layout, live = nil, false
local ns = { db = { bagsOldSpot = false }, ActiveLayoutInfo = function() return layout end,
    EditMode = { Live = function() return live end },
    SetPointIf = function(f, point, rel, relPoint, x, y) f:SetPoint(point, rel, relPoint, x, y) end }
local env = setmetatable({ B = B, ns = ns, UIParent = UIParent, UnitGUID = function() return "Player-1" end,
    Enum = { EditModeSystem = { Bags = 9 }, EditModeLayoutType = { Account = 0, Character = 1 } } }, { __index = _G })
local Hold = assert(load(Cut("/Bar/BandBags.lua", "local END_CORNER = ", "-- One bar: on the micro group box")
    .. "\nreturn HoldBackpackEnd", "hold backpack end", "t", env))()
local LEFT = { turn = nil }

-- Left at the spot edit mode keeps: top center (1314.5, 405), our row 205 x 39, so 1212..1417 x 366..405.
-- Edit mode closes: the same anchor at the game's size. Then our layout: the hold, and the piece sized to its row.
local piece = Piece("TOP", 1314.5, 405, 247, 45)
Hold(piece, LEFT, 205, 39, 205, 39)
piece:SetSize(205, 39)
Check(math.abs(piece:GetLeft() - 1212) < 0.5 and math.abs(piece:GetBottom() - 366) < 0.5,
    string.format("the bags stand where they were left (1212, 366), not moved (now %.1f, %.1f)", piece:GetLeft(), piece:GetBottom()))

-- Backpack only: the row folds to 37 wide out of edit mode; the backpack's end stays where edit mode had it (1417, 366).
piece = Piece("TOP", 1314.5, 405, 247, 45)
Hold(piece, LEFT, 37, 39, 205, 39)
piece:SetSize(37, 39)
Check(math.abs(piece:GetRight() - 1417) < 0.5 and math.abs(piece:GetBottom() - 366) < 0.5,
    string.format("folded: the backpack keeps its end at (1417, 366) (now %.1f, %.1f)", piece:GetRight(), piece:GetBottom()))

-- Unfolded again in play: the piece hangs by the backpack's corner and grows from it, the bags beside it.
Hold(piece, LEFT, 205, 39, 205, 39)
piece:SetSize(205, 39)
Check(math.abs(piece:GetRight() - 1417) < 0.5 and math.abs(piece:GetLeft() - 1212) < 0.5,
    string.format("unfolded: back over 1212..1417 (now %.1f..%.1f)", piece:GetLeft(), piece:GetRight()))

-- A second close in a row moves nothing more.
piece = Piece("TOP", 1314.5, 405, 247, 45)
for _ = 1, 3 do
    Hold(piece, LEFT, 205, 39, 205, 39)
    piece:SetSize(205, 39)
    piece.w, piece.h = 247, 45
end
piece.w, piece.h = 205, 39
Check(math.abs(piece:GetLeft() - 1212) < 0.5 and math.abs(piece:GetBottom() - 366) < 0.5, "three closes: still where left")

-- Bags moved before the update (dbVersion 38): drawn where the player has been seeing them, the old way, while edit
-- mode's record of their spot in the active layout is the one first seen after the update. A drop or an arrow nudge
-- changes the record (a quick one too: the earlier pickup watch missed one, 2026-11-23); a revert brings it back.
assert(load(Cut("/Bar/BandBags.lua", "function ns.KeepBagsSpot()", "-- One bar: on the micro group box"), "keep spot", "t", env))()
ns.KeepBagsSpot()
Check(type(ns.db.bagsOldSpot) == "table" and ns.db.dbVersion == 38, "the update step marks the bags moved before it")
local Old = function()
    local p = Piece("TOP", 1314.5, 405, 247, 45)
    Hold(p, LEFT, 205, 39, 205, 39)
    p:SetSize(205, 39)
    return math.abs(p:GetLeft() - 1233) < 0.5 and math.abs(p:GetBottom() - 360) < 0.5
end
Check(Old(), "layouts not loaded yet: drawn as before the update")
Check(next(ns.db.bagsOldSpot) == nil, "and nothing recorded until they are")
local saved = { point = "TOP", relativeTo = "UIParent", relativePoint = "TOP", offsetX = 556, offsetY = -449 }
layout = { layoutName = "Mine", layoutType = 0, systems = { { system = 9, anchorInfo = saved } } }
for _ = 1, 3 do Check(Old(), "the spot first seen after the update: drawn as before, at every close and load") end
-- A drop (or a nudge) in edit mode rewrites the record: the fix from there, in edit mode too.
live = true
saved.offsetX = 600
Check(not Old(), "moved in edit mode: the bags stand where dropped")
-- Exit without saving: the record goes back, and so does the old view.
saved.offsetX = 556
live = false
Check(Old(), "a revert: drawn as before again")
-- Moved and saved: edit mode shut on the new spot, the fix for this layout for good.
live = true
saved.offsetX = 600
Check(not Old(), "moved again")
live = false
Check(not Old(), "saved and shut: where left")
saved.offsetX = 556
Check(not Old(), "and for good, even back on the old spot")
-- Another layout first seen now keeps its own old view.
layout = { layoutName = "Other", layoutType = 0, systems = { { system = 9, anchorInfo = { point = "TOPLEFT",
    relativeTo = "UIParent", relativePoint = "TOPLEFT", offsetX = 1312, offsetY = -769 } } } }
Check(Old(), "another layout: its own spot kept as before")
-- A player who never had the update step: the fix from the start.
ns.db.bagsOldSpot = false
Check(not Old(), "never marked: where left")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("bags_moved_spot_test: ok")
