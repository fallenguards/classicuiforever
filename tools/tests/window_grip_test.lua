-- Offline test under Lua 5.4 for the windows' corner grips (Start, Step, Stop, DefaultSize in UI/WindowGrips.lua): the
-- drawn corner follows the cursor less where it was grabbed, the top left is pinned once and only by a real change, the
-- size stays within 50 to 150 percent, a locked window or one a fight holds takes no drag, a right click drops the size.
-- Run from the addon root: lua tools/tests/window_grip_test.lua (CI runs every tools/tests/*_test.lua).
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

local handle = assert(io.open(ROOT .. "/UI/WindowGrips.lua", "r"))
local source = handle:read("a"):gsub("\r\n", "\n")
handle:close()

local function Piece(name)
    local from = source:find("local function " .. name .. "(", 1, true)
    local to = from and source:find("\nend\n", from, true)
    Check(from and to, name .. " is in the file")
    return from and to and source:sub(from, to + 4) or ""
end

-- A window at 100, 700 (UIParent units, scale 1) drawn 300 x 400; the screen 1000 x 768.
local frame = { scale = 1, left = 100, top = 700 }
function frame:GetScale() return self.scale end
function frame:GetLeft() return self.left end
function frame:GetTop() return self.top end

local entry = { key = "character" }
local free, combat, down = true, false, true
local cursorX, cursorY = 0, 0
local saves, places = 0, 0
local scales = {}
local W = {
    IsFree = function() return free end,
    Full = function() return false end,
    Ratio = function(f) return f.scale end,
    DrawnSize = function() return 300, 400 end,
    SaveFrom = function() saves = saves + 1 end,
    Scales = function() return scales end,
    SizeKey = function(e) return e.key end,
    PlaceAll = function()
        places = places + 1
        frame.scale = scales.character or 1
    end,
    Refresh = function() end,
}
local job = { awake = false }
function job:Wake() self.awake = true end
function job:Sleep() self.awake = false end
local state
local grip = { SetButtonState = function(_, s) state = s end }

local env = setmetatable({
    W = W, drag = {}, grips = { character = grip }, job = job, MIN_SCALE = 0.5, MAX_SCALE = 1.5,
    Plain = function(v) return v end,
    ns = { WindowFrame = function() return frame end, WindowLocked = function() return false end,
        MoverHolds = function() return false end },
    UIParent = { GetEffectiveScale = function() return 1 end, GetWidth = function() return 1000 end },
    GetCursorPosition = function() return cursorX, cursorY end,
    IsMouseButtonDown = function() return down end,
    InCombatLockdown = function() return combat end,
    GameTooltip = { Hide = function() end },
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
}, { __index = _G })
env._G = env
local Start, Step, DefaultSize = assert(load("local W, drag, grips, job, MIN_SCALE, MAX_SCALE, Plain = W, drag, grips, job, "
    .. "MIN_SCALE, MAX_SCALE, Plain\n" .. Piece("Usable") .. Piece("Cursor") .. Piece("Stop") .. Piece("Step")
    .. Piece("Start") .. Piece("DefaultSize") .. "\nreturn Start, Step, DefaultSize", "grips", "t", env))()

-- Grabbed 3 in and 2 up from the corner (400, 300).
cursorX, cursorY = 397, 302
Start(entry)
Check(job.awake and state == "PUSHED", "a press on an unlocked window starts the drag")
Step()
Check(saves == 0 and places == 0 and scales.character == nil, "a press with no move: no place pinned, no size")

-- The corner 60 right and 80 down: 1.2 along the diagonal.
cursorX, cursorY = 457, 222
Step()
Check(scales.character == 1.2, "the corner on the cursor: 120 percent, got " .. tostring(scales.character))
Check(saves == 1, "the top left pinned before the first new size")
cursorX, cursorY = 487, 182
Step()
Check(saves == 1, "pinned once per drag")
Check(scales.character == 1.3, "130 percent further out, got " .. tostring(scales.character))

cursorX, cursorY = 997, -400
Step()
Check(scales.character == 1.5, "held at 150 percent")
cursorX, cursorY = 100, 700
Step()
Check(scales.character == 0.5, "held at 50 percent")
cursorX, cursorY = 397, 302
Step()
Check(scales.character == nil, "back on the grab spot: its own size, nothing saved")

down = false
Step()
Check(not job.awake and state == "NORMAL", "the button let go ends the drag")
local placesBefore = places
Step()
Check(places == placesBefore, "nothing after the drag ends")

free = false
Start(entry)
Check(not job.awake, "a locked window takes no drag")
free = true
entry.calm = true
combat = true
Start(entry)
Check(not job.awake, "a calm window takes no drag in a fight")
entry.calm, combat = nil, false

scales.character = 1.3
DefaultSize(entry)
Check(scales.character == nil and frame.scale == 1, "a right click puts its own size back")

if failed > 0 then
    print(failed .. " failed")
    os.exit(1)
end
print("window_grip_test: all passed")
