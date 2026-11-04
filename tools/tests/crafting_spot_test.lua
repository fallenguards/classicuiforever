-- Offline test under Lua 5.4 for retail's crafting window's spot (Skills/TradeSkillRetail.lua OnLine): the game lays it
-- 35 right of its slot, which comes off; opened beside our professions book, the game puts it in its center slot past
-- the book's 575 wide space, while the book stands past it as ours in the row: it takes the row's start (#233).
-- Run from the addon root: lua tools/tests/crafting_spot_test.lua (CI runs every tools/tests/*_test.lua).
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

local NOOP = function() end
local ROW_LEFT, ROW_TOP, OFFSET = 16, -116, 35

UIParent = {}
function InCombatLockdown() return false end
C_TradeSkillUI = { IsRuneforging = function() return false end, IsNPCCrafting = function() return false end }

-- The game's crafting window, anchored where its manager laid it.
local function Window()
    local w = { x = 0, y = 0, CraftingPage = { IsShown = function() return true end, SetSize = NOOP } }
    function w:GetNumPoints() return 1 end
    function w:GetPoint() return "TOPLEFT", UIParent, "TOPLEFT", self.x, self.y end
    function w:GetWidth() return 338 end
    function w:GetHeight() return 424 end
    w.SetSize = NOOP
    return w
end

local book = { name = "ProfessionsBookFrame" }
local slots, bookOurs, stood = {}, true, nil
function GetUIPanel(slot) return slots[slot] end

local tick, onVisible
local ns = {
    L = {}, tradeReagents = {},
    OnForever = function() return false end,
    Safe = function(v) return v end,
    Near = function(a, b, tol) return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= tol end,
    MoverHolds = function() return false end,
    FramePlaced = function() return false end,
    WindowRatio = function() return 1 end,
    GameRow = function() return ROW_LEFT, ROW_TOP end,
    GameXOffset = function() return OFFSET end,
    BookPageWindow = function(frame) if bookOurs and frame == book then return book end end,
    TradeSkillActive = function() return true end,
    TradeSkillPage = function() return {} end,
    TradeSkillWindowSize = function() return 338, 424 end,
    SetPointOnce = NOOP, SetAlphaIf = NOOP, SetShownIf = NOOP,
    Sched = {
        Attach = function(_, spec) tick = spec.fn end,
        OnVisible = function(_, _, fn) onVisible = fn end,
    },
    EventFrame = function(_, fn) ProfessionsFrame = ProfessionsFrame or Window(); fn({ UnregisterAllEvents = NOOP }) end,
}
ns.windowParts = {
    TopLeft = function(frame, x, y)
        stood = x
        frame.x, frame.y = x, y
        return true
    end,
}

ProfessionsFrame = Window()
assert(loadfile(ROOT .. "/Skills/TradeSkillRetail.lua"))("ClassicUIForever", ns)
Check(tick ~= nil, "the window's tick is attached")

-- The game lays it again at x: the tick stands it; returns where it stood.
local function Laid(x)
    stood = nil
    ProfessionsFrame.x, ProfessionsFrame.y = x, -55
    tick()
    return stood
end

-- Opened alone: the game's left slot, its offset off.
slots = { left = ProfessionsFrame }
Check(Laid(ROW_LEFT + OFFSET) == ROW_LEFT, "alone: on the row's start, the game's 35 off")

-- Opened beside our book: the game's center slot past the book's 575; the row's start instead.
onVisible(false)
slots = { left = book, center = ProfessionsFrame }
Check(Laid(ROW_LEFT + 575 + OFFSET) == ROW_LEFT, "beside our book: on the row's start, the book past it (#233)")
tick()
Check(ProfessionsFrame.x == ROW_LEFT, "stood there, it stays")

-- The book opened after it: the game's left slot, as alone.
onVisible(false)
slots = { left = ProfessionsFrame, center = book }
Check(Laid(ROW_LEFT + OFFSET) == ROW_LEFT, "the book opened after: on the row's start")

-- The game's own book (ours off): the game's slot kept, its offset off.
onVisible(false)
bookOurs = false
slots = { left = book, center = ProfessionsFrame }
Check(Laid(ROW_LEFT + 575 + OFFSET) == ROW_LEFT + 575, "beside the game's own book: the game's center slot")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("crafting_spot_test: all checks passed")
