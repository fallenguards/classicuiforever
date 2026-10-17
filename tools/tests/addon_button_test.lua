-- Offline test under Lua 5.4 for other addons' ring buttons on our minimap (Map/Minimap.lua RefreshAddonButton): our
-- pass refreshes each through LibDBIcon to follow our ring, and a button its addon hid by LibDBIcon's Hide (its own
-- setting, the saved hide flag untouched) stays hidden; one shown stays shown (#191, TipTac's came back).
-- Run from the addon root: lua tools/tests/addon_button_test.lua (CI runs every tools/tests/*_test.lua).
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

local handle = assert(io.open(ROOT .. "/Map/Minimap.lua", "r"))
local source = handle:read("a")
handle:close()
local first = source:find("local function RefreshAddonButton", 1, true)
local last = first and source:find("local function Layout()", first, true)
assert(first and last, "RefreshAddonButton is in Map/Minimap.lua")
local Refresh = assert(load(source:sub(first, last - 1) .. "\nreturn RefreshAddonButton", "refresh", "t", _G))()

-- A button and LibDBIcon's Refresh as the library has it: shown unless the saved hide flag is set.
local function Button(shown, hideFlag)
    local b = { shown = shown, db = { hide = hideFlag } }
    function b:IsShown() return self.shown end
    function b:Show() self.shown = true end
    function b:Hide() self.shown = false end
    return b
end
local ldbi = { objects = {} }
function ldbi:Refresh(name)
    local b = self.objects[name]
    if not b.db.hide then b:Show() else b:Hide() end
end

ldbi.objects.tiptac = Button(false, false)
Refresh(ldbi, "tiptac", ldbi.objects.tiptac)
Check(not ldbi.objects.tiptac.shown, "hidden by LibDBIcon's Hide, its hide flag off: stays hidden")

ldbi.objects.shown = Button(true, false)
Refresh(ldbi, "shown", ldbi.objects.shown)
Check(ldbi.objects.shown.shown, "a shown button stays shown")

ldbi.objects.flag = Button(true, true)
Refresh(ldbi, "flag", ldbi.objects.flag)
Check(not ldbi.objects.flag.shown, "its hide flag set: Refresh hides it")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("addon_button_test: ok")
