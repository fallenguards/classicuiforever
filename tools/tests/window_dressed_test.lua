-- Offline test under Lua 5.4 for the window list (UI/WindowList.lua): every game window in it says when it is ours
-- (dressed), so nothing of ours (place, size, lock, grip, drag strip, hooks) goes on it while its restyle is off (#192:
-- the map's lock and reset showed on the game's own map).
-- Run from the addon root: lua tools/tests/window_dressed_test.lua (CI runs every tools/tests/*_test.lua).
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

local ns = { L = setmetatable({}, { __index = function(_, k) return k end }), OnForever = function() return true end,
    db = { worldMap = false }, ModuleInForce = function() return false end, panels = { Dressing = function() return false end } }
assert(loadfile(ROOT .. "/UI/WindowList.lua"))("ClassicUIForever", ns)

local seen = 0
for _, entry in ipairs(ns.WINDOW_LIST) do
    if entry.client or entry.quests then
        seen = seen + 1
        Check(type(entry.dressed) == "function", entry.key .. ": a game window with no dressed()")
        if type(entry.dressed) == "function" then
            Check(not entry.dressed(), entry.key .. ": dressed with every restyle off")
        end
    end
end
Check(seen >= 7, "the game windows are listed (saw " .. seen .. ")")

-- Each turns ours with its own restyle.
ns.ModuleInForce = function(key) return key == "characterSheet" end
local byKey = {}
for _, entry in ipairs(ns.WINDOW_LIST) do byKey[entry.key] = entry end
Check(byKey.character.dressed() and not byKey.social.dressed(), "the sheet's restyle dresses the character window alone")
ns.ModuleInForce = function() return false end
ns.panels.Dressing = function(key) return key == "panelSocial" end
Check(byKey.social.dressed() and not byKey.questGiver.dressed(), "Classic style windows' social box dresses social alone")
ns.db.worldMap = true
Check(byKey.map.dressed(), "the classic map dresses the map")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("window_dressed_test: ok")
