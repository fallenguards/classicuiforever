-- dbVersion 21: one color became a theme's default; Flat color's saves turn into Textured color's, so nobody's look
-- changes. In the account and every profile.
-- luacheck: std lua54
local ROOT = arg and arg[0] and arg[0]:match("^(.*)/tools/tests/") or "."
local failed = 0
local function Check(label, got, want)
    if got ~= want then
        failed = failed + 1
        print("FAIL " .. label .. ": got " .. tostring(got) .. ", want " .. tostring(want))
    end
end

local ns = { bronze = { THEMES = {}, THEME_KEYS = {} }, EventFrame = function() end }
assert(loadfile(ROOT .. "/Art/ThemeParts.lua"))("ClassicUIForever", ns)
assert(loadfile(ROOT .. "/Art/ThemeFlat.lua"))("ClassicUIForever", ns)

ns.db = {
    -- A theme without Flat color: textured everywhere, as it looked.
    bronzeTheme = true, themeFlat = false,
    profiles = {
        -- Flat color on every part: the new default, nothing to keep.
        allFlat = { bronzeTheme = true, themeFlat = true, flatHideBorders = true },
        -- Flat color with the spellbook left out: the spellbook stays textured, the rest one color.
        bookOut = { bronzeTheme = true, themeFlat = true, flatSpellbook = false },
        -- No theme: the new default waits for one.
        none = { bronzeTheme = false, themeFlat = false },
    },
}
ns.KeepTexturedLook()
local db, p = ns.db, ns.db.profiles
Check("a theme without Flat color stays textured", db.themeTextured, true)
Check("its parts keep their default (all textured)", db.texturedSpellbook, nil)
Check("Flat color everywhere stays one color", p.allFlat.themeTextured, nil)
Check("the part Flat color left out stays textured", p.bookOut.themeTextured == true and p.bookOut.texturedSpellbook, true)
Check("the parts it covered stay one color", p.bookOut.texturedBars == false and p.bookOut.texturedWindows == false, true)
Check("no theme: the new default", p.none.themeTextured, nil)
Check("the old keys go", db.themeFlat == nil and p.allFlat.flatHideBorders == nil and p.bookOut.flatSpellbook == nil, true)
Check("the save is marked", db.dbVersion, 21)

if failed > 0 then
    print("textured look: " .. failed .. " failures")
    os.exit(1)
end
print("textured look: ok")
