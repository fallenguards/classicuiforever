-- Offline test under Lua 5.4 for the One bar art offer (Bar/BandShape.lua LeftOn, ShowArt): a save from before 0.35.0
-- that turned One bar on and off has any mix of its six pieces left on, the micro and bag art hidden with the key
-- ring's shown again in one; the offer must come for any art still hidden, and Show them must turn off exactly what
-- is on, in the settings in use and in each profile. The all-six rule showed the popup for a profile and did nothing.
-- Run from the addon root: lua tools/tests/one_bar_art_test.lua (CI runs every tools/tests/*_test.lua).
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

local handle = assert(io.open(ROOT .. "/Bar/BandShape.lua", "r"))
local source = handle:read("a"):gsub("\r\n", "\n")
handle:close()
local first = source:find("-- Turned on with One bar", 1, true)
local last = first and source:find("function ns.ShowOneBarArt", first, true)
assert(first and last, "the One bar art offer is in Bar/BandShape.lua")

local popup, changed
local ns = {
    L = setmetatable({}, { __index = function(_, key) return key end }),
    Popup = function(_, def) popup = def end,
    TogglesChanged = function(keys) changed = keys end,
}
assert(load(source:sub(first, last - 1), "one bar art", "t", { ns = ns, ipairs = ipairs, pairs = pairs, type = type }))()

-- A 0.34.0 save: One bar on, then off, the key ring's art shown again by hand.
ns.db = { oneBar = false, hideMicroArt = true, hideBagsArt = true, keyRingArtHidden = false, bagsTight = true }
ns.NoteOneBarArt()
Check(ns.db.oneBarArtNote == true, "micro and bag art left hidden: the offer comes")
Check(ns.db.dbVersion == 23, "the migration stamps its version")
changed = nil
popup.OnAccept()
Check(ns.db.hideMicroArt == false and ns.db.hideBagsArt == false and ns.db.bagsTight == false,
    "Show them turns off what was on")
Check(ns.db.keyRingArtHidden == false and ns.db.hideLatencyBar == nil, "and leaves what was not on alone")
Check(changed and #changed == 3, "the three changed keys are applied (" .. tostring(changed and #changed) .. ")")
Check(ns.db.oneBarArtNote == nil, "the offer is answered")

-- Nothing left hidden: no offer.
ns.db = { oneBar = false, hideLatencyBar = true }
ns.NoteOneBarArt()
Check(ns.db.oneBarArtNote == nil, "no art hidden: no offer, whatever else One bar set")

-- One bar still on: its look is wanted.
ns.db = { oneBar = true, hideMicroArt = true, hideBagsArt = true, keyRingArtHidden = true }
ns.NoteOneBarArt()
Check(ns.db.oneBarArtNote == nil, "One bar on: no offer")

-- Only a profile left so: the offer comes, and Show them clears that profile's pieces, the settings in use untouched.
ns.db = { oneBar = false, profiles = { old = { hideBagsArt = true, keyRingWithBags = true } } }
ns.NoteOneBarArt()
Check(ns.db.oneBarArtNote == true, "a profile left hidden: the offer comes")
changed = nil
popup.OnAccept()
Check(ns.db.profiles.old.hideBagsArt == nil and ns.db.profiles.old.keyRingWithBags == nil, "the profile's pieces go")
Check(changed == nil and ns.db.hideBagsArt == nil, "the settings in use, with nothing hidden, are left alone")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("one_bar_art_test: ok")
