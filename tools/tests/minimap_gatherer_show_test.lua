-- Offline test under Lua 5.4 for our minimap frames' shown state (Map/MinimapShow.lua ns.MinimapShowAs): it goes
-- through the frame's own Show and Hide, so a button gatherer that swaps those on a ring button it keeps on the map
-- (hidden while its bag is shut) is never gone round by a SetShown.
-- Run from the addon root: lua tools/tests/minimap_gatherer_show_test.lua (CI runs every tools/tests/*_test.lua).
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

local ns = { MM = {}, db = {}, FadeTo = function() end }
assert(loadfile(ROOT .. "/Map/MinimapShow.lua"))("ClassicUIForever", ns)

local function Frame(shown)
    local frame = { shown = shown }
    function frame.IsShown(self) return self.shown end
    function frame.SetShown(self, on) self.shown = on end
    function frame.Show(self) self.shown = true end
    function frame.Hide(self) self.shown = false end
    return frame
end

-- A gatherer holding the button with its bag shut: its Show keeps the button hidden.
local bagOpen, asked = false, 0
local button = Frame(false)
local ownShow = button.Show
button.Show = function(self)
    asked = asked + 1
    if bagOpen then ownShow(self) end
end
ns.MinimapShowAs(button, nil)
Check(asked == 1, "showing the button asks its Show")
Check(button.shown == false, "the gatherer's shut bag keeps it hidden")
bagOpen = true
ns.MinimapShowAs(button, nil)
Check(button.shown == true, "with the bag open it shows")

-- A frame of ours with nothing swapped: shown and hidden as before.
local box = Frame(true)
ns.MinimapShowAs(box, "hide")
Check(box.shown == false, "hide hides")
ns.MinimapShowAs(box, "hover")
Check(box.shown == true, "on hover it is shown, faded by the hover watch")
ns.MinimapShowAs(box, nil)
Check(box.shown == true, "shown stays shown")

local source = assert(io.open(ROOT .. "/Map/MinimapShow.lua", "r")):read("a")
Check(not source:find("SetShownIf(frame", 1, true), "our minimap frames never take SetShown")

if failed > 0 then
    print(string.format("minimap gatherer show: %d failed", failed))
    os.exit(1)
end
print("minimap gatherer show: ok")
