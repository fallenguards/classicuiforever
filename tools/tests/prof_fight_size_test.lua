-- Offline test under Lua 5.4 for the professions window's shut size (Skills/ProfessionsWindow.lua SizeShut). A fight
-- cannot resize it (its casting buttons are protected), so it waits shut at the size it will open at. It waited at the
-- trade skill's size: on Era's double pane trade skill the book, opened from the spellbook in a fight, stood in an empty
-- double pane at another spot (his snip 16:16). His pick: the book's size whenever our book is on.
-- Run from the addon root: lua tools/tests/prof_fight_size_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 122 212 431 432

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local failed = 0
local function Check(ok, what)
    print((ok and "PASS " or "FAIL ") .. what)
    if not ok then failed = failed + 1 end
end

local AnyMT = {}
local function Any() return setmetatable({}, AnyMT) end
AnyMT.__index = function(t, k)
    if type(k) ~= "string" then return nil end
    local v = Any()
    rawset(t, k, v)
    return v
end
AnyMT.__call = function() return Any() end
AnyMT.__concat = function() return "" end

-- The game's professions window, shut, last sized for a crafting face.
local window = { w = 680, h = 520 }
function window:GetWidth() return self.w end
function window:GetHeight() return self.h end
function window:SetSize(w, h) self.w, self.h = w, h end
function window:SetWidth(w) self.w = w end
function window:SetHeight(h) self.h = h end
function window:IsShown() return false end
setmetatable(window, { __index = function() return function() return Any() end end })

local ns = Any()
local T = Any()
rawset(ns, "prof", T)
rawset(ns, "EMPTY", {})
rawset(ns, "OnForever", function() return true end)
-- Era's double pane trade skill window.
rawset(ns, "TradeSkillWindowSize", function() return 680, 520 end)
local module
rawset(ns, "RegisterModule", function(_, mod) module = mod end)

local env = setmetatable({ ProfessionsFrame = window, InCombatLockdown = function() return false end },
    { __index = function(_, k)
        local real = _G[k]
        if real ~= nil then return real end
        return Any()
    end })
local handle = assert(io.open(ROOT .. "/Skills/ProfessionsWindow.lua", "r"))
local source = handle:read("a")
handle:close()
assert(load(source, "@Skills/ProfessionsWindow.lua", "t", env))("ClassicUIForever", ns)

-- Our book on.
pcall(module.apply)
Check(type(T.SizeShut) == "function", "the shut size is reachable")
if type(T.SizeShut) == "function" then
    -- Shut on a crafting face, a trade skill on (the case of his snip).
    T.SizeShut({ bookWhenShut = false }, true)
    Check(window.w == T.BookW() and window.h == T.BookH(),
        string.format("shut after crafting it waits at the book's size (%s x %s)", tostring(window.w), tostring(window.h)))
    -- Shut on the book.
    window.w, window.h = 680, 520
    T.SizeShut({ bookWhenShut = true }, true)
    Check(window.w == T.BookW(), "shut on the book it waits at the book's size")
end

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("prof_fight_size_test: ok")
