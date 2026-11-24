-- Offline test under Lua 5.4 for the unit menu's Inspect Talents (Skills/Talents.lua). The game's entry asks for the
-- inspect, then opens its own spells window from its event registry; that show ran tainted, so in a fight both windows
-- stood open and an action failed (his snip 16:35, SecureHandlers.lua:52 "Invalid 'self' frame handle"). The entry must
-- ask for the inspect and open ours alone on that player once it is ready; the game's own click never runs.
-- Run from the addon root: lua tools/tests/inspect_talents_menu_test.lua (CI runs every tools/tests/*_test.lua).
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

-- A menu element as the game's Menu builds them: words, a responder, children.
local function Element(text)
    local e = { text = text, children = {} }
    function e:EnumerateElementDescriptions()
        local i = 0
        return function()
            i = i + 1
            if self.children[i] then return i, self.children[i] end
        end
    end
    function e:SetResponder(fn) self.responder = fn end
    function e:Add(child) self.children[#self.children + 1] = child return child end
    return e
end

-- Our talents window: shown, its attributes kept.
local window = Any()
rawset(window, "shown", false)
rawset(window, "attrs", {})
rawset(window, "Show", function(self) rawset(self, "shown", true) end)
rawset(window, "Hide", function(self) rawset(self, "shown", false) end)
rawset(window, "IsShown", function(self) return rawget(self, "shown") end)
rawset(window, "SetAttribute", function(self, k, v) rawget(self, "attrs")[k] = v end)

local modifiers, events = {}, {}
local notified, gameClick = nil, false
local ns = Any()
rawset(ns, "OnForever", function() return true end)
rawset(ns, "IsSecret", function() return false end)
rawset(ns, "TalentWindow", function() return window end)
rawset(ns, "EventFrame", function(_, fn)
    local f = {}
    function f:RegisterEvent(e) events[e] = fn end
    function f:UnregisterEvent(e) events[e] = nil end
    return f
end)
local module
rawset(ns, "RegisterModule", function(_, mod) module = mod end)

local env = setmetatable({
    Menu = { ModifyMenu = function(tag, fn) modifiers[tag] = fn end },
    MenuUtil = { GetElementText = function(e) return e.text end },
    INSPECT_TALENTS = "Inspect Talents",
    NotifyInspect = function(unit) notified = unit end,
    UnitGUID = function(unit) return "Player-1-" .. unit end,
    InCombatLockdown = function() return true end,
}, { __index = function(_, k)
    local real = _G[k]
    if real ~= nil then return real end
    return Any()
end })
local handle = assert(io.open(ROOT .. "/Skills/Talents.lua", "r"))
local source = handle:read("a")
handle:close()
assert(load(source, "@Skills/Talents.lua", "t", env))("ClassicUIForever", ns)
pcall(module.apply)
-- The tree's readers live in the sibling files (TalentsTree.lua, TalentSpecs.lua): stand-ins here.
setmetatable(ns.talents, { __index = function() return function() return nil end end })

-- A party member's menu, in a fight: Inspect Talents inside the Interact submenu, the game's click on it.
local root = Element(nil)
root:Add(Element("Whisper"))
local interact = root:Add(Element("Interact"))
local entry = interact:Add(Element("Inspect Talents"))
entry:SetResponder(function() gameClick = true end)
Check(modifiers.MENU_UNIT_PARTY ~= nil, "the party member's menu is taken")
if modifiers.MENU_UNIT_PARTY then modifiers.MENU_UNIT_PARTY(nil, root, { unit = "party1" }) end
entry.responder()
Check(not gameClick, "the game's own click never runs (its window never opens)")
Check(notified == "party1", "the inspect is asked for that player")
Check(not window:IsShown(), "ours waits for the inspect's data")

-- The game's INSPECT_READY for that player.
if events.INSPECT_READY then events.INSPECT_READY(nil, "INSPECT_READY", "Player-1-party1") end
Check(window:IsShown(), "ours shows once the inspect is ready")
Check(rawget(window, "attrs").inspecting == 1, "and says it is inspecting")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("inspect_talents_menu_test: ok")
