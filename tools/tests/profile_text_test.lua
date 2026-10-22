-- Offline test under Lua 5.4 for a profile as text (Core/ProfileText.lua): Export writes CUIF1 and one table, Import
-- reads it back with every value kept (quotes and backslashes in strings, decimals, a table setting), drops keys it
-- does not know and values of the wrong type, refuses anything else, and numbers a name already taken.
-- Run from the addon root: lua tools/tests/profile_text_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 212

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local failed = 0
local function Check(ok, what)
    if not ok then
        failed = failed + 1
        print("FAIL " .. what)
    end
end

local used
local ns = {
    L = setmetatable({}, { __index = function(_, key) return key end }),
    DB_DEFAULTS = { hideWhoTab = false, microScale = 1, themeColor = "ffffff", swingColorOff = "cast" },
    ProfileKeys = function() return { "hideWhoTab", "microScale", "themeColor", "minimapButtonPicks", "swingColorOff" } end,
    db = { profiles = { Default = { hideWhoTab = true } } },
    StoreProfile = function() end,
    ProfileName = function() return "Default" end,
    UseProfile = function(name) used = name end,
}
function ns.CheckProfileName(text)
    local name = text:gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" or #name > 32 then return nil end
    for other in pairs(ns.db.profiles) do
        if other:lower() == name:lower() then return nil end
    end
    return name
end
assert(loadfile(ROOT .. "/Core/ProfileText.lua"))("ClassicUIForever", ns)

local function Same(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for k, v in pairs(a) do
        if not Same(v, b[k]) then return false end
    end
    for k in pairs(b) do
        if a[k] == nil then return false end
    end
    return true
end

local shot = { hideWhoTab = true, microScale = 0.85, themeColor = 'b4"71\\ac', swingColorOff = "cast",
    minimapButtonPicks = { EasyFind = true, ["Bug Sack"] = false } }
local text = ns.EncodeProfile("My Look 2", shot)
Check(text:sub(1, 5) == "CUIF1" and not text:find("\n"), "the text starts with the mark and has no line breaks")
local name, back = ns.DecodeProfile(text)
Check(name == "My Look 2", "the name comes back (" .. tostring(name) .. ")")
Check(back and Same(back, shot), "every setting comes back as it was")
Check(select(2, ns.DecodeProfile("  " .. text .. "\n")) ~= nil and ns.DecodeProfile("  " .. text .. "\n") == "My Look 2",
    "surrounding blanks are fine")

local _, picked = ns.DecodeProfile('CUIF1{n="x",s={hideWhoTab=t,nothingOfOurs=t,microScale="big",themeColor="aa",swingColorOff=5}}')
Check(picked and picked.hideWhoTab == true and picked.themeColor == "aa", "known keys of the right type come in")
Check(picked and picked.nothingOfOurs == nil and picked.microScale == nil and picked.swingColorOff == nil,
    "an unknown key and values of the wrong type are dropped")

for _, bad in ipairs({ "hello", "", "CUIF1", "CUIF1{n=1,s={}}", "CUIF1{n=\"a\"}", text:sub(1, #text - 3), text .. "x",
    'CUIF1{n="a",s={minimapButtonPicks={a={b=t}}}}', 'CUIF1{n="a",s={hideWhoTab=true}}', 'CUIF1{n="a",s={hideWhoTab=t,}}' }) do
    local got, why = ns.DecodeProfile(bad)
    Check(got == nil and why == "CORE_NOT_A_PROFILE", "refused: " .. bad:sub(1, 40))
end

Check(ns.ImportProfile(text) == "My Look 2" and used == "My Look 2", "import makes the profile and switches to it")
Check(Same(ns.db.profiles["My Look 2"], shot), "the imported profile holds the settings")
Check(ns.ImportProfile(text) == "My Look 2 2", "a taken name is numbered")
Check(ns.ImportProfile(ns.EncodeProfile("   ", {})) == "CORE_IMPORTED", "a blank name gets a word")
local exported = ns.ExportProfile()
local exportedName, exportedShot = ns.DecodeProfile(exported)
Check(exportedName == "Default" and exportedShot.hideWhoTab == true, "export gives the profile in use")
Check(ns.ImportProfile("nonsense") == nil, "import refuses nonsense")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("profile_text_test: ok")
