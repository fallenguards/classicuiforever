-- Offline test under Lua 5.4 for the shop on the 1.x micro row (Bar/BandMicro.lua, Bar/GameMicro.lua ns.ShopOffRow):
-- hidden by default, by its own box even with Hide micro buttons off, and an upgrade shows no shop it never showed: a
-- classic bar's save hides it, the game's own micro menu keeps its pick (the account and every profile).
-- Run from the addon root: lua tools/tests/shop_row_test.lua (CI runs every tools/tests/*_test.lua).
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
local function Read(path)
    local handle = assert(io.open(ROOT .. "/" .. path, "r"))
    local text = handle:read("a")
    handle:close()
    return text
end
local function Cut(source, from, to)
    local first = source:find(from, 1, true)
    local last = first and source:find(to, first, true)
    assert(first and last, "the code to test is where it was: " .. from)
    return source:sub(first, last - 1)
end

local ns = {}
GetLocale = GetLocale or function() return "enUS" end
assert(loadfile(ROOT .. "/Core/Localization.lua"))("ClassicUIForever", ns)
assert(loadfile(ROOT .. "/Locales/enUS.lua"))("ClassicUIForever", ns)
assert(loadfile(ROOT .. "/Core/Defaults.lua"))("ClassicUIForever", ns)
Check(ns.DB_DEFAULTS.hideMicroShop == true, "the shop is hidden by default")
Check(Read("Bar/Band.lua"):find("B.MICRO_SKIP = { HelpMicroButton = true }", 1, true) ~= nil,
    "only the game's Help is kept off the row for good")

local env = setmetatable({ ns = ns }, { __index = _G })
local hidden = assert(load(Cut(Read("Bar/BandMicro.lua"), "local OWN_ROW", "local function MicroSkipped")
    .. "\nreturn HiddenByOption", "row", "t", env))()
Check(hidden({ hideMicroShop = true, hideMicroButtons = false }, "hideMicroShop"), "hidden by its own box, Hide micro buttons off")
Check(not hidden({ hideMicroShop = false, hideMicroButtons = true }, "hideMicroShop"), "unchecked, it shows")
Check(not hidden({ hideMicroGuild = true, hideMicroButtons = false }, "hideMicroGuild"), "other buttons still follow Hide micro buttons")

local migrate = Cut(Read("Bar/GameMicro.lua"), "function ns.ShopOffRow", "\nend") .. "\nend"
assert(load(migrate, "migrate", "t", env))()
ns.db = { classicBar = true, hideMicroShop = false, profiles = {
    band = { hideMicroShop = false }, game = { classicBar = false }, gameShown = { classicBar = false, hideMicroShop = true } } }
ns.ShopOffRow()
local db = ns.db
Check(db.hideMicroShop == true, "a classic bar's save hides the shop it never showed")
Check(db.profiles.band.hideMicroShop == true, "and a classic bar's profile")
Check(db.profiles.game.hideMicroShop == false, "the game's micro menu keeps the shop it showed")
Check(db.profiles.gameShown.hideMicroShop == true, "and a pick made there")
Check(db.dbVersion == 30, "the save's version")

if failed > 0 then os.exit(1) end
print("shop row: ok")
