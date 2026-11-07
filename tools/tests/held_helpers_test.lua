-- Offline test under Lua 5.4 for the move helpers of a button another addon's frame holds (Core/Scheduler.lua
-- Sched.LetGo, Map/MinimapButton.lua). A button gatherer's tray took our minimap ring button, and our two helpers
-- (UIParent to the button) left the tray no anchor on its own drag, so it never moved. Held helpers stay loose, also
-- when made later and when edit mode closes, and pin again once the button is back home.
-- Run from the addon root: lua tools/tests/held_helpers_test.lua (CI runs every tools/tests/*_test.lua).
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

local helpers = {}
local function Frame(parent)
    local frame = { parent = parent, scripts = {}, points = 0 }
    function frame:GetParent() return self.parent end
    function frame:SetScript(name, fn) self.scripts[name] = fn end
    function frame:Hide() end
    function frame:Show() end
    function frame:SetPoint() self.points = self.points + 1 end
    function frame:ClearAllPoints() self.points = 0 end
    return frame
end
UIParent = Frame(nil)
function CreateFrame(_, _, parent)
    local frame = Frame(parent)
    if parent == UIParent then helpers[#helpers + 1] = frame end
    return frame
end
function GetTime() return 0 end
C_Timer = { After = function() end }

local editLive, editFns = false, {}
local ns = { Report = function() end, PassReads = function(fn) return fn end,
    EditMode = { Live = function() return editLive end },
    OnEditMode = function(fn) editFns[#editFns + 1] = fn end }
assert(loadfile(ROOT .. "/Core/Scheduler.lua"))("ClassicUIForever", ns)
local Sched = ns.Sched

local function EditMode(live)
    editLive = live
    for i = 1, #editFns do editFns[i]() end
end

local function Pinned(list)
    for i = 1, #list do
        if list[i].points ~= 2 then return false end
    end
    return true
end
local function Loose(list)
    for i = 1, #list do
        if list[i].points ~= 0 then return false end
    end
    return true
end

local minimap = Frame(UIParent)
local tray = Frame(minimap)
local button = Frame(minimap)
local other = Frame(minimap)

Sched.OnMove(button, function() end)
local ours = { helpers[#helpers - 1], helpers[#helpers] }
Sched.OnMove(other, function() end)
local others = { helpers[#helpers - 1], helpers[#helpers] }
Check(Pinned(ours) and Pinned(others), "helpers pin on their button")

-- A gatherer's tray takes the button: its helpers let go, the others stay.
button.parent = tray
Sched.LetGo(button, true)
Check(Loose(ours), "a held button's helpers let go")
Check(Pinned(others), "other buttons keep their helpers")

-- Edit mode opens and closes: the held button's helpers stay loose.
EditMode(true)
Check(Loose(ours) and Loose(others), "edit mode lets every helper go")
EditMode(false)
Check(Loose(ours), "closing edit mode does not pin a held button's helpers")
Check(Pinned(others), "closing edit mode pins the rest")

-- A watcher made while the button is held: loose from the start.
Sched.OnMove(button, function() end)
Check(Loose({ helpers[#helpers - 1], helpers[#helpers] }), "a helper made while held starts loose")

-- Back home: every helper on it pins again.
button.parent = minimap
Sched.LetGo(button, false)
Check(Pinned(ours) and Pinned({ helpers[#helpers - 1], helpers[#helpers] }), "back home, its helpers pin again")

-- The ring button tells the scheduler on each reparent: held anywhere but its home and our addon bag.
local src = assert(io.open(ROOT .. "/Map/MinimapButton.lua")):read("a")
Check(src:find('HookMethod%(b, "SetParent"') ~= nil and src:find("Sched%.LetGo%(self, parent ~= Home%(ring%)") ~= nil,
    "ring buttons let their helpers go when another frame takes them")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("held_helpers_test: all checks passed")
