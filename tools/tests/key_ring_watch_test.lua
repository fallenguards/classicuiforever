-- Offline test under Lua 5.4 for the watch that hides the client's key ring again (Bar/BandSection.lua), on the real
-- scheduler (Core/Scheduler.lua). The watch ran every frame while the key ring showed, which is when it has nothing
-- to do. Now its frame is hidden unless the key ring is held off, so it runs only for a key ring the client showed
-- again; what it does then is unchanged.
-- Run from the addon root: lua tools/tests/key_ring_watch_test.lua (CI runs every tools/tests/*_test.lua).
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

------------------------------------------------------------------ the stub client

-- A frame's OnUpdate runs only while it and everything above it show.
local frames = {}
local function Frame(parent)
    local frame = { shown = true, parent = parent, scripts = {}, mouse = true }
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    function frame:IsShown() return self.shown end
    function frame:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
    function frame:SetScript(name, fn) self.scripts[name] = fn end
    function frame:GetScript(name) return self.scripts[name] end
    function frame:IsMouseEnabled() return self.mouse end
    function frame:EnableMouse(on) self.mouse = on end
    frames[#frames + 1] = frame
    return frame
end
function CreateFrame(_, _, parent) return Frame(parent) end
local clock = 0
function GetTime() return clock end
C_Timer = { After = function() end }

local ns = { Report = function(message) error(message, 0) end, SetAlphaIf = function() end, PassReads = function(fn) return fn end }
assert(loadfile(ROOT .. "/Core/Scheduler.lua"))("ClassicUIForever", ns)

local keyRing = Frame()
KeyRingButton = keyRing

-- One drawn frame: every visible frame's OnUpdate. Returns how many of the key ring's watchers ran.
local function Draw()
    clock = clock + 0.1
    local ran = 0
    for _, frame in ipairs(frames) do
        local onUpdate = frame.scripts.OnUpdate
        if onUpdate and frame:IsVisible() then
            if frame.parent == keyRing then ran = ran + 1 end
            onUpdate(frame, 0.1)
        end
    end
    return ran
end
local function DrawMany(count)
    local ran = 0
    for _ = 1, count do ran = ran + Draw() end
    return ran
end

------------------------------------------------------------------ the key ring's piece, cut out of the file and run

local handle = assert(io.open(ROOT .. "/Bar/BandSection.lua", "r"))
local source = handle:read("a")
handle:close()

local first = source:find("local keyOff, keyWasShown", 1, true)
local last = source:find("-- Its band x and width inside the section", 1, true)
Check(first and last and last > first, "the key ring's piece is in the file")
local chunk = first and last and (source:sub(first, last - 1)
    .. "\nreturn KeyRingShown, HideAgain, function(job) keyJob = job end") or ""

local B = { active = true }
local run, err = load(chunk, "key ring", "t", setmetatable({ B = B, ns = ns }, { __index = _G }))
Check(run ~= nil, "the piece loads (" .. tostring(err) .. ")")
local KeyRingShown, HideAgain, SetJob
if run then KeyRingShown, HideAgain, SetJob = run() end
KeyRingShown, SetJob = KeyRingShown or function() end, SetJob or function() end

-- The band's line that makes the watch, as it stands in the file.
local ATTACH = 'keyJob = ns.Sched.Attach(KeyRingButton, { name = "band.keyRingOff", every = 0.1, fn = HideAgain, awake = false })'
Check(source:find(ATTACH, 1, true) ~= nil, "the band makes the watch asleep and keeps it")
SetJob(ns.Sched.Attach(keyRing, { name = "band.keyRingOff", every = 0.1, fn = HideAgain, awake = false }))

------------------------------------------------------------------ checks

-- Ours to show: the key ring stands on the band and the watch has nothing to do.
KeyRingShown(true)
Check(keyRing:IsShown(), "the key ring shows on the band")
Check(DrawMany(20) == 0, "while the key ring shows the watch never runs")

-- Held off (hidden in its options, or no place for it in this layout).
KeyRingShown(false)
Check(not keyRing:IsShown() and not keyRing:IsMouseEnabled(), "held off, the key ring is hidden and takes no mouse")
Check(DrawMany(20) == 0, "while it stays hidden the watch never runs")

-- The client shows it again and the show is missed: the watch hides it within its beat.
keyRing:Show()
keyRing:EnableMouse(true)
Check(DrawMany(3) >= 1, "a key ring shown again wakes the watch")
Check(not keyRing:IsShown() and not keyRing:IsMouseEnabled(), "the watch hides it again")

-- Not while the band is going.
B.active = false
keyRing:Show()
DrawMany(3)
Check(keyRing:IsShown(), "with the band off the watch leaves the key ring alone")
B.active = true
DrawMany(3)
Check(not keyRing:IsShown(), "with the band back the watch hides it")

-- Given back: shown as it was, and the watch asleep again.
KeyRingShown(true)
Check(keyRing:IsShown() and keyRing:IsMouseEnabled(), "given back, the key ring shows and takes the mouse")
Check(DrawMany(20) == 0, "given back, the watch never runs")

-- No watcher could be made (the scheduler answered nil): holding it off still works.
SetJob(nil)
KeyRingShown(false)
Check(not keyRing:IsShown(), "with no watch the key ring is still hidden")
KeyRingShown(true)
Check(keyRing:IsShown(), "with no watch the key ring still comes back")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("key_ring_watch_test: ok")
