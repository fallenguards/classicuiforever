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

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("pet_char_view_test: ok")
