-- Offline test under Lua 5.4 for the social window's opener (Social/SocialOpener.lua): with the game's new social window
-- on, the social keys open ours while any list of ours is on (the who list alone too), and go back to the game's when
-- none is; a fight holds the change until it ends.
-- Run from the addon root: lua tools/tests/social_opener_test.lua (CI runs every tools/tests/*_test.lua).
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

local quiet = { __index = function() return function() end end }

local fighting, newUI = false, true
local bound = {}   -- key -> the button it clicks
InCombatLockdown = function() return fighting end
GetBindingKey = function(binding) if binding == "TOGGLESOCIAL" then return "O" end end
ClearOverrideBindings = function() bound = {} end
SetOverrideBindingClick = function(_, _, key, target) bound[key] = target end

local Frame = {}
Frame.__index = Frame
function Frame:SetAttribute(name, value) self.attrs[name] = value end
function Frame:SetScript(name, fn) self.scripts[name] = fn end
function Frame:HookScript(name, fn) self.hooks[name] = fn end
function Frame:IsShown() return self.shown end
function Frame:GetAlpha() return 1 end
local function NewFrame() return setmetatable({ attrs = {}, scripts = {}, hooks = {}, shown = false }, Frame) end
for _, name in ipairs({ "SetSize", "SetPoint", "EnableMouse", "RegisterForClicks" }) do Frame[name] = function() end end

CreateFrame = function(_, name)
    local f = NewFrame()
    if name then _G[name] = f end
    return f
end
UIParent = NewFrame()
FriendsFrame = NewFrame()
QuickJoinToastButton = NewFrame()

local padWhen
local ns = setmetatable({}, quiet)
ns.social, ns.guild = {}, {}
ns.SocialUIOn = function() return newUI end
ns.KeyProxy = function(name) return name .. "Key" end
ns.SetAttributeIf = function(f, name, value) f.attrs[name] = value end
ns.RegisterEvents = function(f, list) f.events = list end
ns.MapPad = function(button, _, _, _, when) if button == QuickJoinToastButton then padWhen = when end end
ns.ShowPanel = function(f) f.shown = true end
ns.HidePanel = function(f) f.shown = false end
assert(loadfile(ROOT .. "/Social/SocialOpener.lua"))("ClassicUIForever", ns)
local S = ns.social

local OPENER_KEY = "ForeverClassicUISocialOpenKey"

-- The new window on, the guild roster off, the who list on: O opens ours.
local opener = S.UseOpener("whoList", true)
Check(opener ~= nil, "the who list alone makes the opener")
Check(bound.O == OPENER_KEY, "the who list alone: O clicks our opener")
Check(padWhen and padWhen() == true, "the who list alone: the friends button by chat opens ours")
Check(opener and opener.attrs.macrotext == "", "the new window on: the opener's macro leaves the client's toggle alone")

-- A press opens ours, the next shuts it.
local function Press()
    opener.scripts.PreClick(opener, "LeftButton", false)
    opener.hooks.OnClick(opener, "LeftButton", false)
end
Press()
Check(FriendsFrame.shown == true, "a press opens our window")
Press()
Check(FriendsFrame.shown == false, "a second press shuts it")

-- Both lists on, then the who list off: the roster keeps O.
S.UseOpener("guildRoster", true)
S.UseOpener("whoList", false)
Check(bound.O == OPENER_KEY, "the roster alone: O still clicks our opener")

-- No list of ours: O and the button are the game's again.
S.UseOpener("guildRoster", false)
Check(bound.O == nil, "no list of ours: O is the game's")
Check(not padWhen(), "no list of ours: the friends button is the game's")

-- Turned on in a fight: bound once it ends.
fighting = true
S.UseOpener("whoList", true)
Check(bound.O == nil, "in a fight: nothing bound yet")
fighting = false
opener.scripts.OnEvent(opener, "PLAYER_REGEN_ENABLED")
Check(bound.O == OPENER_KEY, "after the fight: O clicks our opener")

-- Without the new window the client's own toggle opens ours: no keys, no button pad for the who list.
newUI = false
opener.scripts.OnEvent(opener, "SOCIAL_UI_SYSTEM_STATUS_UPDATED")
Check(bound.O == nil, "the new window off: O is the game's (it opens ours)")
Check(not padWhen(), "the new window off: the friends button is the game's for the who list")
Check(opener.attrs.macrotext == "/click QuickJoinToastButton", "the new window off: the opener clicks the toast")
S.UseOpener("guildRoster", true)
Check(padWhen() == true, "the new window off: the roster still settles the button's press")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("social_opener_test: all checks passed")
