-- Offline test under Lua 5.4 for dropping Classic style windows (Windows/Panels.lua ns.DropWindowsSwitch): the switch's
-- saved value goes, from the account and every profile, and every window box keeps its own tick. The first upgrade
-- step forced every window off for a save with the switch off, and a player lost their classic bags and windows.
-- Run from the addon root: lua tools/tests/windows_switch_test.lua (CI runs every tools/tests/*_test.lua).
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

local handle = assert(io.open(ROOT .. "/Windows/Panels.lua", "r"))
local source = handle:read("a"):gsub("\r\n", "\n")
handle:close()
local first = source:find("function ns.DropWindowsSwitch()", 1, true)
local last = first and source:find("\nend\n", first, true)
assert(first and last, "ns.DropWindowsSwitch is in Windows/Panels.lua")

local ns = {}
assert(load(source:sub(first, last + 4), "drop switch", "t", { ns = ns, pairs = pairs, type = type }))()

-- The switch off, the boxes under it as the player left them, a profile the same.
ns.db = { panels = false, bags = true, characterSheet = false, panelMail = true, dbVersion = 25,
    profiles = { old = { panels = false, spellBook = true } } }
ns.DropWindowsSwitch()
Check(ns.db.panels == nil and ns.db.profiles.old.panels == nil, "the switch's value goes from the account and the profile")
Check(ns.db.bags == true and ns.db.panelMail == true and ns.db.profiles.old.spellBook == true, "ticked boxes stay ticked")
Check(ns.db.characterSheet == false, "an unticked box stays unticked")
Check(ns.db.dbVersion == 26, "the step stamps its version")
local count = 0
for _ in pairs(ns.db) do count = count + 1 end
Check(count == 5, "nothing else is added (" .. count .. " keys)")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("windows_switch_test: ok")
