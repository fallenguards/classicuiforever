-- Offline test under Lua 5.4 for the minimap ring buttons' press (Map/MinimapButton.lua ns.RingPress): Era's
-- MiniMapButtonTemplate moves the face 1 right and 1 down while held and back on release; ours had no press at all.
-- The code is cut out of the file and run.
-- Run from the addon root: lua tools/tests/ring_press_test.lua (CI runs every tools/tests/*_test.lua).
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

-- A face on one point, as the ring's dress lays it.
local holder = {}
local face = { point = { "CENTER", holder, "TOPLEFT", 17, -16 } }
function face:GetPoint() return table.unpack(self.point) end
-- A button whose hooks are kept by script name.
local button = { hooks = {} }
function button:HookScript(script, fn) self.hooks[script] = fn end

-- The release watch: its handler kept, its event's registration counted.
local watch = { events = {} }
function watch:RegisterEvent(event) self.events[event] = true end
function watch:UnregisterAllEvents() self.events = {} end
local ns = {
    SetPointOnce = function(region, ...) region.point = { ... } end,
    HookScriptOnce = function(frame, script, fn) frame.hooks[script] = fn end,
    EventFrame = function(_, fn)
        watch.fn = fn
        return watch
    end,
}
local env = setmetatable({ ns = ns }, { __index = _G })
assert(load(Cut("/Map/MinimapButton.lua", "-- Era's minimap button press", "local function Build(ring)"), "ring press",
    "t", env))()

local function At(x, y) return face.point[4] == x and face.point[5] == y and face.point[2] == holder end
ns.RingPressable(button, face)
button.hooks.OnMouseDown(button)
Check(At(18, -17), "held: the face 1 right and 1 down, as Era's minimap buttons")
button.hooks.OnMouseDown(button)
Check(At(18, -17), "a second down while held moves it no further")
button.hooks.OnMouseUp(button)
Check(At(17, -16), "released: back on its spot")
button.hooks.OnMouseUp(button)
Check(At(17, -16), "an up with no press leaves it be")
-- A drag took the mouse up (the eye stayed pressed, off centre): any release lets it go.
button.hooks.OnMouseDown(button)
Check(watch.events.GLOBAL_MOUSE_UP, "a press listens for the next release anywhere")
watch.fn(watch)
Check(At(17, -16), "a release away from the button lets the face go")
Check(not watch.events.GLOBAL_MOUSE_UP, "and stops listening")
ns.RingPress(button, true)
button.hooks.OnHide(button)
Check(At(17, -16), "hidden while held: back on its spot")
-- A pad over the button (a micro icon's) passes its press on; its drag takes the mouse up from the pad too.
watch.events = {}
ns.RingPress(button, true)
Check(At(18, -17), "a pad's press moves the face")
Check(watch.events.GLOBAL_MOUSE_UP, "a pad's press listens for the next release anywhere")
ns.RingPress(button, false)
Check(At(17, -16), "and its release puts it back")
ns.RingPress({}, true)
Check(At(17, -16), "a button that is no ring button's: nothing moves")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("ring_press_test: all checks passed")
