-- Offline test under Lua 5.4 for the band's bag row in a fight (Bar/BandBags.lua B.LayoutBags). At a level-up in a fight
-- the game laid its bags piece again by the micro menu (a specialization event's edit mode pass) and only it may move
-- that piece then; the row hung from the piece and went with it, 135 left and 4 up, until the fight ended (a ding
-- watch, 2026-11-21). In a fight the row hangs from the band where the piece's end stands; out of one, from the piece.
-- Run from the addon root: lua tools/tests/bags_fight_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 122 212 431

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local failed = 0
local function Check(ok, what)
    if not ok then
        failed = failed + 1
        print("FAIL: " .. what)
    end
end

-- Anything not modelled answers as a no-op; data fields stay nil.
local function Loose(t)
    return setmetatable(t or {}, { __index = function(_, k)
        if type(k) == "string" and k:match("^%u") and not k:match("Pool$") then return function() end end
    end })
end
local function Frame(name)
    local f = Loose({ name = name, points = {}, scale = 1 })
    function f.SetPoint(self, ...) self.points[#self.points + 1] = { ... } end
    function f.ClearAllPoints(self) self.points = {} end
    function f.GetScale(self) return self.scale end
    function f.GetEffectiveScale() return 1 end
    function f.SetSize(self, w, h) self.w, self.h = w, h end
    function f.GetPoint(self, i) local p = self.points[i or 1] if p then return table.unpack(p) end end
    function f.GetNumPoints(self) return #self.points end
    return f
end

local fight = false
function InCombatLockdown() return fight end
Enum = { BagsDirection = { Left = 0, Right = 1, Up = 0, Down = 1 } }
local art = Frame("ForeverClassicUIBar")
BagsBar = Frame("BagsBar")
BagsBar.isHorizontal, BagsBar.direction = true, 0
MainMenuBarBackpackButton = Frame("MainMenuBarBackpackButton")
CharacterBag0Slot, CharacterBag1Slot = Frame("CharacterBag0Slot"), Frame("CharacterBag1Slot")
CharacterBag2Slot, CharacterBag3Slot = Frame("CharacterBag2Slot"), Frame("CharacterBag3Slot")
CharacterReagentBag0Slot = Frame("CharacterReagentBag0Slot")
UIParent = Frame("UIParent")

local calm = {}
local B = Loose({
    BAND_H = 53, CORNER_X = 0, KEYRING_H = 39,
    BAG_BUTTONS = { "MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot",
        "CharacterBag3Slot" },
    PIECES = { era = { key = "bandBags", band = { 0, 1 } } },
    art = art, shape = { bags = true }, active = true,
    BandNow = function() return 1 end,
    Seat = function(button, scale, w, h) button.scale, button.w, button.h = scale, w, h end,
    OneBar = function() return false end,
    MicroOut = function() return false end,
    CurrentPlan = function() return { width = 1024, bagsEnd = 1018 } end,
    ButtonLevel = function() return 5 end,
    Bag = function() return { size = 37, gap = 5, x = 0, y = 2, sheet = "era" } end,
    BagsFolded = function() return false end,
    ReagentSlot = function() return false end,
    ReagentHidden = function() return false end,
    BagsMode = function() return "shown" end,
    BagsTight = function() return false end,
    Remember = function() end,
})
local ns = Loose({
    band = B, L = setmetatable({}, { __index = function(_, k) return k end }), db = {},
    Sched = Loose({ Job = function() return Loose({}) end }),
    BarsTaken = function() return false end,
    WhenCalm = function(key, fn) calm[key] = fn end,
    SetPointOnce = function(f, ...) f:ClearAllPoints() f:SetPoint(...) end,
    SetShownIf = function() end,
    Near = function(a, b, d) return math.abs(a - b) <= d end,
})
assert(loadfile(ROOT .. "/Bar/BandBags.lua"))("ClassicUIForever", ns)
Check(type(B.LayoutBags) == "function", "the band lays its bag row")

local function Last(f) return f.points[#f.points] or {} end

-- Out of a fight: the piece laid over the band's bag part, the row hung from it (edit mode's box on the bags).
B.LayoutBags()
local p = Last(BagsBar)
Check(p[1] == "BOTTOMRIGHT" and p[2] == art and p[3] == "BOTTOMLEFT" and p[4] == 1018 and p[5] == 1,
    "out of a fight the piece is laid on the band, its corner at 1018, 1")
Check(BagsBar.w and BagsBar.h == 39, "and sized to the row")
local pack = Last(MainMenuBarBackpackButton)
Check(pack[1] == "RIGHT" and pack[2] == BagsBar and pack[3] == "RIGHT", "the backpack hangs from the piece's right end")
local pieceRight = { x = p[4], y = (p[5] or 0) + (BagsBar.h or 0) / 2 }

-- A fight: the game lays its piece by the micro menu; the row is laid again and must not follow it.
fight = true
BagsBar.points = { { "BOTTOMLEFT", Frame("MicroMenuContainer"), "BOTTOMRIGHT", 7, -4 } }
B.LayoutBags()
pack = Last(MainMenuBarBackpackButton)
Check(pack[2] ~= BagsBar, "in a fight the backpack no longer hangs from the piece the game moved")
Check(pack[1] == "RIGHT" and pack[2] == art and pack[3] == "BOTTOMLEFT", "it hangs from the band, by its right end")
Check(pack[4] == pieceRight.x and pack[5] == pieceRight.y,
    "where the piece's right end stood: 1018, 20.5 (the backpack's own centre before the ding)")
Check(Last(BagsBar)[2] ~= art, "the piece itself is left where the game put it")
Check(type(calm["band.bagsPiece"]) == "function", "the row goes back on the piece when the fight ends")
local bag0 = Last(CharacterBag0Slot)
Check(bag0[2] == MainMenuBarBackpackButton, "the bags still chain from the backpack")

-- The fight ends: the piece laid on the band again, the row back on it.
fight = false
B.LayoutBags()
pack = Last(MainMenuBarBackpackButton)
Check(pack[2] == BagsBar and Last(BagsBar)[2] == art, "after the fight the piece is on the band and the row on the piece")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("bags_fight_test: ok")
