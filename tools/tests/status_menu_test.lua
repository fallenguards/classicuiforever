-- Offline test under Lua 5.4 for Appear Offline in our social window's status menu (Social/StatusMenu.lua), over a
-- stand-in of the game's old status menu (Camelot FriendsFrame.lua: three entries that set only what changed from the
-- status they last set themselves). The fourth entry hides you; every entry after it shows you again; the button's
-- check and tooltip follow the real presence; Social unchecked or a client menu with its own entry stays the game's.
-- Run from the addon root: lua tools/tests/status_menu_test.lua (CI runs every tools/tests/*_test.lua).
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

FRIENDS_TEXTURE_ONLINE = "Interface\\FriendsFrame\\StatusIcon-Online"
FRIENDS_TEXTURE_AFK = "Interface\\FriendsFrame\\StatusIcon-Away"
FRIENDS_TEXTURE_DND = "Interface\\FriendsFrame\\StatusIcon-DnD"
FRIENDS_TEXTURE_OFFLINE = "Interface\\FriendsFrame\\StatusIcon-Offline"
FRIENDS_LIST_AVAILABLE, FRIENDS_LIST_AWAY, FRIENDS_LIST_BUSY = "Available", "Away", "Busy"
FRIENDS_LIST_STATUS_TOOLTIP = "Your status: %s"
SOCIAL_UI_PRESENCE_TYPE_LABEL_APPEAR_OFFLINE = "Appear Offline"
function nop() end

-- The account's presence, as the server keeps it.
local afk, dnd, hidden = false, false, false
local calls = {}
function BNGetInfo() return 1, "Me#1", 1, "", afk, dnd, true, hidden end
C_BattleNet = {
    SetAFK = function(on) calls[#calls + 1] = "afk " .. tostring(on) afk = on if on then dnd = false end end,
    SetDND = function(on) calls[#calls + 1] = "dnd " .. tostring(on) dnd = on if on then afk = false end end,
    SetAppearOffline = function(on) calls[#calls + 1] = "offline " .. tostring(on) hidden = on end,
}

-- A menu entry and root, as the proxies addons are handed.
local function Entry(text, data)
    local e = { text = text, data = data }
    function e.GetData(self) return self.data end
    function e.SetIsSelected(self, fn) self.isSelected = fn end
    function e.IsSelected(self) return self.isSelected ~= nil and self.isSelected(self.data) end
    function e.SetResponder(self, fn) self.responder = fn end
    function e.HookResponder(self, fn)
        local was = self.responder
        self.responder = function(...) was(...) fn(...) end
    end
    function e.Pick(self) self.responder(self.data) end
    return e
end
local function Root()
    local r = { list = {} }
    function r.CreateButton(self, text, _, data)
        local e = Entry(text, data)
        self.list[#self.list + 1] = e
        return e
    end
    function r.EnumerateElementDescriptions(self) return ipairs(self.list) end
    return r
end

-- The game's generator: its own idea of the status, set only by its own picks.
local gameStatus = FRIENDS_TEXTURE_ONLINE
local function GameMenu(withOffline)
    local root = Root()
    local function IsSelected(status) return gameStatus == status end
    local function SetSelected(status)
        if status == gameStatus then return end
        gameStatus = status
        if status == FRIENDS_TEXTURE_ONLINE then
            C_BattleNet.SetAFK(false)
            C_BattleNet.SetDND(false)
        elseif status == FRIENDS_TEXTURE_AFK then
            C_BattleNet.SetAFK(true)
        elseif status == FRIENDS_TEXTURE_DND then
            C_BattleNet.SetDND(true)
        end
    end
    local statuses = { FRIENDS_TEXTURE_ONLINE, FRIENDS_TEXTURE_AFK, FRIENDS_TEXTURE_DND }
    if withOffline then statuses[4] = FRIENDS_TEXTURE_OFFLINE end
    for _, status in ipairs(statuses) do
        local e = root:CreateButton(status, nop, status)
        e:SetIsSelected(IsSelected)
        e:SetResponder(SetSelected)
    end
    return root
end

local modify
Menu = { ModifyMenu = function(tag, fn) if tag == "MENU_FRIENDS_STATUS" then modify = fn end end }
local tipText, owned = nil, true
GameTooltip = { IsOwned = function() return owned end, SetText = function(_, t) tipText = t end, Show = function() end }
local dropdown = { scripts = {} }
FriendsFrameStatusDropdown = dropdown
local dressing = true
local ns = {
    panels = { Dressing = function(key) return key == "panelSocial" and dressing end },
    Safe = function(v, fallback) if v == nil then return fallback end return v end,
    HookScriptOnce = function(frame, script, fn) frame.scripts[script] = fn end,
}
assert(loadfile(ROOT .. "/Social/StatusMenu.lua"))("ClassicUIForever", ns)
Check(modify ~= nil, "the status menu's entries are added through the game's hook")

local function Build(withOffline)
    local root = GameMenu(withOffline)
    modify(dropdown, root)
    return root
end
local function Picked(root)
    local on = {}
    for _, e in ipairs(root.list) do if e:IsSelected() then on[#on + 1] = e.data end end
    return table.concat(on, ",")
end
local function Calls() local s = table.concat(calls, ", ") calls = {} return s end

-- Four entries, Appear Offline last with the offline icon.
local root = Build()
Check(#root.list == 4, "four entries")
local offline = root.list[4]
Check(offline and offline.data == FRIENDS_TEXTURE_OFFLINE, "the fourth is Appear Offline")
Check(offline and offline.text:find("StatusIcon-Offline.tga", 1, true) and offline.text:find("Appear Offline", 1, true),
    "with the offline icon and the game's label")
Check(Picked(root) == FRIENDS_TEXTURE_ONLINE, "Available checked while online")

-- Appear Offline hides you; the button's check moves to it.
offline:Pick()
Check(hidden and Calls() == "offline true", "Appear Offline hides you")
root = Build()
Check(Picked(root) == FRIENDS_TEXTURE_OFFLINE, "the check is on Appear Offline")

-- Available again (the game thinks you never left it, so its own entry does nothing): ours shows you.
root.list[1]:Pick()
Check(not hidden and not afk and not dnd, "Available shows you again")
Check(Calls() == "offline false, afk false, dnd false", "through the whole presence")
root = Build()
Check(Picked(root) == FRIENDS_TEXTURE_ONLINE, "the check back on Available")

-- Hidden, then Away: shown as away.
Build().list[4]:Pick()
calls = {}
root = Build()
root.list[2]:Pick()
Check(not hidden and afk, "Away after Appear Offline shows you away")
root = Build()
Check(Picked(root) == FRIENDS_TEXTURE_AFK, "the check on Away")

-- Busy, then Available, picked as usual: still right with ours after the game's.
root.list[3]:Pick()
Check(dnd and not afk, "Busy")
Build().list[1]:Pick()
Check(not afk and not dnd and not hidden, "Available")

-- The button's tooltip names the real status.
Build().list[4]:Pick()
dropdown.scripts.OnEnter(dropdown)
Check(tipText == "Your status: Appear Offline", "the tooltip says Appear Offline")
owned = false
tipText = nil
dropdown.scripts.OnEnter(dropdown)
Check(tipText == nil, "another owner's tooltip left alone")
owned = true
Build().list[1]:Pick()

-- Social unchecked: the game's menu as it is.
dressing = false
root = Build()
Check(#root.list == 3, "Social unchecked: three entries")
gameStatus = FRIENDS_TEXTURE_AFK
Check(Picked(root) == FRIENDS_TEXTURE_AFK, "and the game's own check")
calls = {}
root.list[1]:Pick()
Check(Calls() == "afk false, dnd false", "and the game's own pick")
tipText = nil
dropdown.scripts.OnEnter(dropdown)
Check(tipText == nil, "and the game's own tooltip")
dressing = true

-- A client whose menu lists Appear Offline already keeps its own.
gameStatus = FRIENDS_TEXTURE_ONLINE
root = Build(true)
Check(#root.list == 4, "a client's own Appear Offline: no second one")
hidden = true
Check(Picked(root) == FRIENDS_TEXTURE_ONLINE, "and its own checks")

print(failed == 0 and "status_menu_test: ok" or ("status_menu_test: " .. failed .. " failed"))
if failed > 0 then os.exit(1) end
