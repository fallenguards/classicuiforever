-- Offline test under Lua 5.4: with Social unchecked the social window is the game's (Core/Core.lua ModuleInForce over
-- the real options list). Every module that takes the social window's opener (S.UseOpener in Social/*.lua) needs
-- Social, so none of our tabs or lists stays in that window and the social keys open the game's own.
-- Run from the addon root: lua tools/tests/social_off_test.lua (CI runs every tools/tests/*_test.lua).
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
    local file = assert(io.open(ROOT .. "/" .. path, "rb"))
    local text = file:read("a")
    file:close()
    return text
end

-- The real options list, over stubs.
local NUMBERS = { GetStringWidth = 60, GetStringHeight = 12, GetWidth = 100, GetHeight = 24 }
local Stub
local function Method(_, name)
    if NUMBERS[name] then return function() return NUMBERS[name] end end
    return function() return Stub() end
end
function Stub() return setmetatable({}, { __index = Method }) end
local L = setmetatable({}, { __index = function(_, key) return key end })
local opts = setmetatable({ L = L, ART = { CHECK = "check" }, EMPTY = {}, db = {}, ENGLISH_CLIENT = true },
    { __index = function() return function() return Stub() end end })
opts.OnForever = function() return true end
opts.NewFrame = function() return Stub() end
opts.PACKAGE = false
GameTooltip, MenuUtil, SOUNDKIT = Stub(), Stub(), {}
assert(loadfile(ROOT .. "/Options/Toggles.lua"))("ClassicUIForever", opts)

-- The modules that take the social window's opener, read from the source.
local takers = {}
local toc = Read("ClassicUIForever.toc")
for path in toc:gmatch("(Social\\[%w_]+%.lua)") do
    local text = Read((path:gsub("\\", "/")))
    for key in text:gmatch('S%.UseOpener%(%s*"([%w_]+)"%s*,%s*true') do takers[key] = true end
end
Check(takers.whoList and takers.guildRoster, "the who list and the guild roster take the opener")

-- Core's module gate over the real list.
function CreateFrame()
    local f = {}
    function f.RegisterEvent() end
    function f.SetScript() end
    return f
end
StaticPopupDialogs = {}
function InCombatLockdown() return false end
function GetBuildInfo() return "", "", "", 16001 end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
C_Timer = { After = function() end }
local ns = { L = L }
assert(loadfile(ROOT .. "/Core/Core.lua"))("ClassicUIForever", ns)
function ns.PackageRuns() return true end
ns.RELOAD_KEYS = {}
ns.TOGGLES = opts.TOGGLES

local db = { panelSocial = false }
ns.db = db
for key in pairs(takers) do
    Check(ns.ModuleInForce(key) == false, key .. " stands down with Social unchecked")
end
Check(ns.ModuleInForce("guildClassColors") == false, "the roster's own rows with it")
db.panelSocial = true
for key in pairs(takers) do
    Check(ns.ModuleInForce(key) == true, key .. " runs with Social checked")
end
db.whoList = false
Check(ns.ModuleInForce("whoList") == false and ns.ModuleInForce("guildRoster") == true, "each still turns off alone")

print(failed == 0 and "social_off_test: ok" or ("social_off_test: " .. failed .. " failed"))
if failed > 0 then os.exit(1) end
