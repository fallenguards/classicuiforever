-- Offline test under Lua 5.4 for One Bag per profile (Core/Profiles.lua, Core/Core.lua). One Bag is the game's Combined
-- Bags, which the game keeps once per account: a profile could not hold it, the account's value was read back at every
-- load (a CurseForge question, 2026-11-21). Now the profile's pick is written at the load, before the game reads it
-- (its bag code read clean after that write: dev bagmode probe), and a change in the game's own controls goes into the
-- profile in use. Profiles made at this load hold no pick, so the game's setting stands on a first install.
-- Run from the addon root: lua tools/tests/profile_one_bag_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 122 212

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local failed = 0
local function Check(ok, what)
    if not ok then
        failed = failed + 1
        print("FAIL: " .. what)
    end
end

local combined = "1"
local watcher
local runs = true
local function Load(db, char)
    ForeverClassicUICharDB = char
    watcher = nil
    local ns = {
        L = setmetatable({}, { __index = function(_, k) return k end }),
        TOGGLES = { { "oneBag" }, { "bags" } },
        DB_DEFAULTS = { oneBag = false, bags = true },
        PackageMask = function() end,
        DbTable = function(key) db[key] = db[key] or {} end,
        GetCVar = function(name) if name == "combinedBags" then return combined end end,
        EventFrame = function(event, fn) watcher = { event = event, fn = fn } return {} end,
        PackageRuns = function(key) return key ~= "oneBag" or runs end,
        db = db,
    }
    assert(loadfile(ROOT .. "/Core/Profiles.lua"))("ClassicUIForever", ns)
    return ns
end

-- A first install: profiles made now hold no pick; the game's Combined Bags stands.
combined = "1"
local ns = Load({ oneBag = false, bags = true }, nil)
local made = ns.LoadProfile()
Check(made == true, "a first load makes the profiles")
Check(ns.ProfileOneBagWant(made) == nil, "and writes nothing: a new player's combined bags stay combined")
Check(ns.db.oneBag == true and ns.db.profiles.Default.oneBag == true, "the game's setting is the profile's first pick")

-- A character on a profile with individual bags, while another character left the account on combined.
combined = "1"
ns = Load({ oneBag = true, bags = true, profiles = { Default = { oneBag = true }, Single = {} } }, { profile = "Single" })
made = ns.LoadProfile()
Check(made == false and ns.db.oneBag == false, "the profile's pick is loaded: individual bags")
Check(ns.ProfileOneBagWant(made) == "0", "the load writes individual bags for this character")

-- A character on the combined profile after that.
combined = "0"
ns = Load({ oneBag = false, bags = true, profiles = { Default = { oneBag = true }, Single = {} } }, { profile = "Default" })
made = ns.LoadProfile()
Check(ns.ProfileOneBagWant(made) == "1", "and combined bags for the next one")

-- Same as the game already: nothing written. No game setting (another client): nothing written.
combined = "1"
Check(ns.ProfileOneBagWant(made) == nil, "nothing written when the game already matches")
combined = nil
Check(ns.ProfileOneBagWant(made) == nil, "nothing written without the game's setting")

-- A package without our bags (a standalone) has One Bag forced off: the game's setting is never written.
runs = false
combined = "1"
ns = Load({ oneBag = false, bags = true, profiles = { Default = {} } }, { profile = "Default" })
made = ns.LoadProfile()
Check(ns.ProfileOneBagWant(made) == nil, "a package without our bags leaves Combined Bags alone")
runs = true
ns = Load({ oneBag = true, bags = true, profiles = { Default = { oneBag = true }, Single = {} } }, { profile = "Default" })
made = ns.LoadProfile()

-- The game's own bag menu or settings: the change goes into the profile in use, and is stored with it.
combined = "0"
Check(watcher and watcher.event == "CVAR_UPDATE", "the game's setting changes are followed")
watcher.fn(nil, "CVAR_UPDATE", "showQuestLevel")
Check(ns.db.oneBag == true, "another setting's change is ignored")
watcher.fn(nil, "CVAR_UPDATE", "combinedBags")
Check(ns.db.oneBag == false, "a Combined Bags change made in the game's own controls is One Bag's")
ns.StoreProfile()
Check(ns.db.profiles.Default.oneBag == nil, "and the profile keeps it (individual is the default, kept as no entry)")

-- The write sits in Core.lua's own load branch, right after the profile loads, where the checker counts it.
local handle = assert(io.open(ROOT .. "/Core/Core.lua", "r"))
local core = handle:read("a")
handle:close()
local at = core:find("local oneBag = ns.ProfileOneBagWant(ns.LoadProfile())", 1, true)
Check(at ~= nil, "Core.lua loads the profile and asks for One Bag's write")
Check(at and core:find('if oneBag then ns.SetCVar("combinedBags", oneBag) end', at, true) ~= nil, "and writes it there")
local branch = core:find('if event == "ADDON_LOADED" then', 1, true)
Check(branch and at and branch < at, "inside the addon's own load")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("profile_one_bag_test: ok")
