-- Offline test under Lua 5.4 for Other addons in the theme's parts (Art/Bronze.lua PlainTree, Art/ThemeParts.lua): the
-- walks over the game's windows leave another addon's frames out unless it is checked, EasyFind's always (its theme is
-- its own), ours never; a piece a walk painted in one goes back as it is left out.
-- Run from the addon root: lua tools/tests/theme_addons_test.lua (CI runs every tools/tests/*_test.lua).
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

-- The game's own globals are secure; an addon's are not.
local GAME = { CharacterFrame = true, PaperDollFrame = true }
function issecurevariable(name) return GAME[name] == true end
UIParent = {}
wipe = function(t) for k in pairs(t) do t[k] = nil end end

local function Frame(name)
    local frame = { name = name }
    function frame:GetName() return self.name end
    function frame:GetParent() return nil end
    return frame
end

local DARK = { tint = { 0.4, 0.4, 0.4 } }
local noop = function() end
local ns = {
    db = {},
    bronze = { THEMES = { dark = DARK }, THEME_KEYS = {} },
    ThemeName = function() return "dark" end,
    IsSecret = function() return false end,
    IsForbidden = function() return false end,
    EventFrame = noop,
    OnToggle = noop,
    RegisterModule = noop,
}
assert(loadfile(ROOT .. "/Art/ThemeParts.lua"))("ClassicUIForever", ns)
assert(loadfile(ROOT .. "/Art/Bronze.lua"))("ClassicUIForever", ns)
local PlainTree = ns.bronze.PlainTree

local addon, easyFind = Frame("SomeAddonPanel"), Frame("EasyFindSearchBar")
local ours, game, unnamed = Frame("ForeverClassicUISpellbook"), Frame("PaperDollFrame"), Frame(nil)

Check(PlainTree(addon), "another addon's frame is left out by default")
Check(PlainTree(easyFind), "EasyFind's frame is left out by default")
Check(not PlainTree(ours), "our own frame is walked")
Check(not PlainTree(game), "the game's frame is walked")
Check(not PlainTree(unnamed), "an unnamed frame is walked")
Check(ns.bronze.AddonFrame(addon) and not ns.bronze.AddonFrame(ours) and not ns.bronze.AddonFrame(game),
    "only another addon's frame counts as one")

ns.db.themePartAddons = true
Check(not PlainTree(addon), "Other addons checked: another addon's frame is walked")
Check(PlainTree(easyFind), "Other addons checked: EasyFind's frame is still left out")

-- A piece a walk painted inside another addon's frame follows Other addons.
local piece = Frame(nil)
ns.MarkAddonPiece(piece)
Check(ns.ThemeFor(piece) == DARK, "Other addons checked: its piece takes the theme")
ns.db.themePartAddons = false
Check(ns.ThemeFor(piece) == nil, "Other addons left out: its piece goes back as drawn")
ns.db.themePartAddons = nil
Check(ns.ThemeFor(piece) == nil, "never set: its piece stays as drawn")
Check(ns.ThemeFor(Frame(nil)) == DARK, "an unmarked piece keeps the theme")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("theme_addons_test: all checks passed")
