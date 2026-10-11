-- Offline test under Lua 5.4 for Hide locked slots (LockedSlots and Lock in Windows/Bags.lua): without an authenticator
-- the game adds locked backpack slots, which the option fades and deafens; an account with one has none, so nothing
-- changes for it, option on or off.
-- Run from the addon root: lua tools/tests/locked_slots_test.lua (CI runs every tools/tests/*_test.lua).
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

local handle = assert(io.open(ROOT .. "/Windows/Bags.lua", "r"))
local source = handle:read("a")
handle:close()

local function Piece(name)
    local from = source:find("local function " .. name .. "(", 1, true)
    local to = from and source:find("\nend\n", from, true)
    Check(from and to, name .. " is in the file")
    return from and to and source:sub(from, to + 4) or ""
end

local max, usable = 20, 16
local env = setmetatable({
    BACKPACK = 0,
    ns = { db = { hideLockedSlots = true } },
    ContainerFrame_GetContainerNumSlots = function() return max, usable end,
}, { __index = _G })
env._G = env
env.locked = setmetatable({}, { __mode = "k" })
function env.ns.SetFrameAlphaIf(frame, alpha) frame.alpha = alpha end
local LockedSlots, Lock = assert(load("local BACKPACK, locked = BACKPACK, locked\n" .. Piece("LockedSlots") .. Piece("Lock")
    .. "\nreturn LockedSlots, Lock", "locked", "t", env))()

local open, count = LockedSlots()
Check(open == 16 and count == 4, "no authenticator: 16 usable, 4 locked")

usable = 20
Check(LockedSlots() == nil, "an authenticator: no locked slots, nothing to hide")

env.ns.DevLockedSlots = 4
open, count = LockedSlots()
Check(open == 16 and count == 4, "dev stand-in: an authenticator's last four read as locked")
env.ns.DevLockedSlots = nil

usable = 16
env.ns.db.hideLockedSlots = false
Check(LockedSlots() == nil, "option off: nothing hidden")

local function Button()
    local b = { alpha = 1, mouse = true, extendedFrame = { mouse = true } }
    local function Mouse(self) return self.mouse end
    local function SetMouse(self, on) self.mouse = on end
    b.IsMouseEnabled, b.EnableMouse = Mouse, SetMouse
    b.extendedFrame.IsMouseEnabled, b.extendedFrame.EnableMouse = Mouse, SetMouse
    return b
end

local slot = Button()
Lock(slot, false)
Check(slot.alpha == 1 and slot.mouse and slot.extendedFrame.mouse, "a slot never locked is left alone")
Lock(slot, true)
Check(slot.alpha == 0 and not slot.mouse and not slot.extendedFrame.mouse, "a locked slot: faded, deaf, its padlock deaf")
Lock(slot, false)
Check(slot.alpha == 1 and slot.mouse and slot.extendedFrame.mouse, "given back: shown and heard again")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("locked_slots_test: ok")
