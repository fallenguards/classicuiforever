-- Offline test under Lua 5.4 for the pet pieces the client lays on the Character view (PetOnCharacterView in
-- Character/PetView.lua): a hunter pet's happiness face shows itself, so the client's summon put the pet in the player's
-- model and its XP bar came up; ours, run after, hides the bar and gives the player back, and leaves the pet view alone.
-- Run from the addon root: lua tools/tests/pet_char_view_test.lua (CI runs every tools/tests/*_test.lua).
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

local handle = assert(io.open(ROOT .. "/Character/PetView.lua", "r"))
local source = handle:read("a")
handle:close()
local from = source:find("local function PetOnCharacterView(", 1, true)
local to = from and source:find("\nend\n", from, true)
Check(from and to, "PetOnCharacterView is in the file")
local body = from and to and source:sub(from, to + 4) or ""
Check(source:find('ns.EventFrame({ "UNIT_PET", "UNIT_PET_EXPERIENCE" }, PetOnCharacterView, "player")', 1, true),
    "the watcher takes the player's pet events")

local function Frame(shown)
    local f = { shown = shown }
    function f:IsShown() return self.shown end
    function f:Hide() self.shown = false end
    return f
end

local setPlayer, petView, hasPet = 0, false, true
local env = setmetatable({
    T = { active = true, PetView = function() return petView end },
    PaperDollFrame = Frame(true),
    PetPaperDollPetHappinessInfo = Frame(true),
    PetPaperDollFrameExpBar = Frame(true),
    HasPetUI = function() return hasPet end,
    PaperDollFrame_SetPlayer = function() setPlayer = setPlayer + 1 end,
}, { __index = _G })
env._G = env
local Watch = assert(load(body .. "\nreturn PetOnCharacterView", "watch", "t", env))()

Watch(nil, "UNIT_PET")
Check(not env.PetPaperDollFrameExpBar.shown, "summon on the Character view: the pet XP bar goes")
Check(setPlayer == 1, "summon on the Character view: the player's model comes back")

env.PetPaperDollFrameExpBar.shown = true
Watch(nil, "UNIT_PET_EXPERIENCE")
Check(not env.PetPaperDollFrameExpBar.shown, "pet XP on the Character view: the bar goes")
Check(setPlayer == 1, "pet XP: the model is left alone")

petView = true
env.PetPaperDollFrameExpBar.shown = true
Watch(nil, "UNIT_PET")
Check(env.PetPaperDollFrameExpBar.shown and setPlayer == 1, "pet view: the client's pieces stay")
petView = false

env.PetPaperDollPetHappinessInfo.shown = false
Watch(nil, "UNIT_PET")
Check(env.PetPaperDollFrameExpBar.shown and setPlayer == 1, "no happiness face (no hunter pet): the client did nothing, nor do we")

env.PetPaperDollPetHappinessInfo.shown = true
env.T.active = false
Watch(nil, "UNIT_PET")
Check(setPlayer == 1, "the sheet off: nothing")

-- Training points: Forever's C_PetInfo pair (total, used) gives what is left to spend.
local tpFrom = source:find("local function TrainingPoints()", 1, true)
local tpTo = tpFrom and source:find("\nend\n", tpFrom, true)
Check(tpFrom and tpTo, "TrainingPoints is in the file")
local tpEnv = setmetatable({
    C_PetInfo = { GetPetTrainingPoints = function() return 23, 8 end },
    ns = { IsSecret = function() return false end },
}, { __index = _G })
tpEnv._G = tpEnv
local TrainingPoints = assert(load(source:sub(tpFrom or 1, (tpTo or 0) + 4) .. "\nreturn TrainingPoints", "tp", "t", tpEnv))()
Check(TrainingPoints() == 15, "Forever's training points: 23 earned, 8 used, 15 to spend")

-- The XP bar: the client's fill track is inset 6 a side and its fill 15 tall for its own art; Era's fill is the bar.
local dress = source:match("local function DressXP%(bar, doll%)(.-)\nend\n") or ""
Check(dress:find("area:SetAllPoints(bar)", 1, true) ~= nil, "the fill's track is the whole bar, not the client's inset")
Check(dress:find("fill:SetHeight(PET_XP_H)", 1, true) ~= nil, "the fill is the bar's height, not the client's 15")

-- The pet's stat boxes hold only what the game fills: it gives pets no attributes (all 0) and no weapon skill, so the
-- left box lists its own pet pane's stats; five shown a box, the rest wheeled through with the stat panes' bar.
handle = assert(io.open(ROOT .. "/Character/CharacterStats.lua", "r"))
local stats = handle:read("a")
handle:close()
for _, name in ipairs({ "UnitHealthMax", "GetUnitSpeed", "GetPetCritChance", "GetPetMeleeHaste" }) do
    Check(stats:find(name .. '("pet")', 1, true) or stats:find(name .. "()", 1, true), "the pet box reads " .. name)
end
local rows = stats:match("function T%.PetStatRows%(pet%)(.-)\nend\n") or ""
Check(rows:find("for _, row in ipairs(T.petRows) do left.list[#left.list + 1] = row end", 1, true) ~= nil,
    "the left box lists the pet's health, speed, crit and haste")
Check(rows:find("for _, row in ipairs(T.attributes) do row:Hide() end", 1, true) ~= nil,
    "no attribute rows for a pet (the game gives it none: always 0)")
Check(rows:find("{ attack and T.attack, T.attackPower, T.damage, defense and T.defense, T.armor }", 1, true) ~= nil,
    "the right box keeps Era's rows the game fills, Attack only where it has a weapon skill")
Check(stats:find("ns.StatScroll.Build(box, PET_SHOWN", 1, true) ~= nil, "the pet boxes scroll with the stat panes' bar")

local layFrom = stats:find("local function LayPetBox(box)", 1, true)
local layTo = layFrom and stats:find("\nend\n", layFrom, true)
local layEnv = { ipairs = ipairs, ns = {
    SetPointOnce = function(row, _, _, _, _, y) row.y = y end,
    SetShownIf = function(row, shown) row.shown = shown end,
} }
local LayPetBox = assert(load("local PET_ROWS_Y, PET_SHOWN = -5, 5\n" .. stats:sub(layFrom or 1, (layTo or 0) + 4)
    .. "\nreturn LayPetBox", "lay", "t", layEnv))()
Check(stats:find("ns.StatScroll.Build(box, PET_SHOWN, PET_PITCH,", 1, true) ~= nil, "both pet boxes step their rows alike")
local box = { list = {}, offset = 0, rowX = 6, rowPitch = 14 }
for i = 1, 7 do box.list[i] = {} end
LayPetBox(box)
Check(box.list[1].shown and box.list[5].shown and not box.list[6].shown, "five rows shown, the rest below the fold")
Check(box.list[1].y == -5 and box.list[5].y == -61, "5 down, 14 a row")
box.offset = 2
LayPetBox(box)
Check(not box.list[2].shown and box.list[3].y == -5 and box.list[7].shown, "wheeled down two, the seventh comes in")

-- The boxes fit their rows (no empty foot), and stand lower by as much, so their foot stays over the XP bar.
local fitFrom = stats:find("local function FitPetBoxes(rows)", 1, true)
local fitTo = fitFrom and stats:find("\nend\n", fitFrom, true)
local heights = {}
local function Piece(key) return { GetHeight = function() return heights[key] end, SetHeight = function(_, h) heights[key] = h end } end
local fitEnv = { ipairs = ipairs, math = math, ns = { EMPTY = {} }, T = { leftBox = { {}, Piece("left") }, petBox = { {}, Piece("right") } } }
local FitPetBoxes = assert(load("local PET_SHOWN, PET_ROWS_Y, BOX_MIDDLE, BOX_CAPS, PET_PITCH, ROW_H = 5, -5, 53, 32, 14, 13\n"
    .. stats:sub(fitFrom or 1, (fitTo or 0) + 4) .. "\nreturn FitPetBoxes", "fit", "t", fitEnv))()
Check(FitPetBoxes(4) == 20 and heights.left == 33 and heights.right == 33,
    "four rows 14 apart: 5 above the first and 5 under the last (65 tall)")
Check(FitPetBoxes(nil) == 0 and heights.left == 53, "the character's view: Era's box")
Check(FitPetBoxes(9) == 6 and heights.left == 47, "more than five: five rows fit, the rest scroll")
Check(source:find("pet and PET_ATTRS_Y - shrink or CHAR_ATTRS_Y", 1, true) ~= nil, "the shorter boxes keep their foot")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("pet_char_view_test: ok")
