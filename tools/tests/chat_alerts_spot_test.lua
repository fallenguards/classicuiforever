-- Offline test under Lua 5.4 for the chat's alert container with the classic chat off (Windows/ChatAlerts.lua). The game
-- hangs it on ChatFrame1's button column, 27 over its top (ChatAlertFrameMixin:OnLoad), the text-to-speech button riding
-- it; a top-edge sizing of the chat by another addon (Leatrix Plus's easy chat resizing) then left the chat with no
-- points while anything outside it hung on it (chatdrag v4, 2026-11-24). The container must stand on the game's own spot
-- by the screen's coordinates, never hung on the chat, and follow the chat as it moves or sizes; the classic chat's
-- hand-back must not hang it back on the chat.
-- Run from the addon root: lua tools/tests/chat_alerts_spot_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 122 212 431 432

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local failed = 0
local function Check(ok, what)
    print((ok and "PASS " or "FAIL ") .. what)
    if not ok then failed = failed + 1 end
end

-- Frames: points resolve to screen boxes the way the game's do for the anchors used here.
local Frame = {}
Frame.__index = Frame
local function NewFrame(name, parent)
    local f = setmetatable({ name = name, parent = parent, points = {}, scripts = {}, w = 0, h = 0, scale = 1,
        shown = true }, Frame)
    if name then _G[name] = f end
    return f
end
function Frame:GetName() return self.name end
function Frame:GetParent() return self.parent end
function Frame:GetEffectiveScale() return self.scale end
function Frame:IsShown() return self.shown end
function Frame:SetWidth(w) self.w = w end
function Frame:GetWidth() return self.w end
function Frame:ClearAllPoints() self.points = {} end
function Frame:SetPoint(point, rel, relPoint, x, y) self.points[#self.points + 1] = { point, rel, relPoint, x or 0, y or 0 } end
function Frame:GetNumPoints() return #self.points end
function Frame:GetPoint(i) return table.unpack(self.points[i]) end
function Frame:HookScript(script, fn) self.scripts[script] = fn end
-- A box set outright (the chat's and its column's, as the game lays them).
function Frame:Box(left, top) self.left, self.top = left, top end
function Frame:GetLeft() return self.left end
function Frame:GetTop() return self.top end
function Frame:GetBottom() return self.top and self.top - 20 or 0 end
function Frame:GetRight() return (self.left or 0) + 32 end
-- The container's bottom left on screen from its one point.
local function Spot(f)
    local p = f.points[1]
    if not p then return nil end
    local _, rel, _, x, y = table.unpack(p)
    if rel == UIParent then return x, y end
    return rel:GetLeft() + x, rel:GetTop() + y
end
local function InChat(rel, chat)
    while rel do
        if rel == chat then return true end
        rel = rel:GetParent()
    end
    return false
end

_G.UIParent = NewFrame("UIParent")
local chat = NewFrame("ChatFrame1", UIParent)
local column = NewFrame("ChatFrame1ButtonFrame", chat)
chat.buttonFrame = column
column:Box(10, 300)
local alerts = NewFrame("ChatAlertFrame", UIParent)
alerts:SetWidth(32)
-- ChatAlertFrameMixin:OnLoad.
alerts:SetPoint("BOTTOMLEFT", column, "TOPLEFT", 0, 27)

-- Stubs of the helpers the file uses.
local hooks, globals, events, nextFns = {}, {}, {}, {}
local ns = {
    AnySecret = function() return false end,
    SetPointOnce = function(f, ...) f:ClearAllPoints() f:SetPoint(...) end,
    HookMethod = function(f, method, fn) hooks[f] = hooks[f] or {} hooks[f][method] = fn return true end,
    HookGlobal = function(name, fn) globals[name] = fn return true end,
    HookScriptOnce = function(f, script, fn) f:HookScript(script, fn) end,
    EventFrame = function(event, fn) events[event] = fn end,
    Sched = { NextFrame = function(key, fn) nextFns[key] = fn end, AfterShow = function() end },
}
assert(loadfile(ROOT .. "/Windows/ChatAlerts.lua"))("ClassicUIForever", ns)
local function RunNextFrame()
    local fns = nextFns
    nextFns = {}
    for _, fn in pairs(fns) do fn() end
end

-- The world shows, the classic chat off.
if events.PLAYER_ENTERING_WORLD then events.PLAYER_ENTERING_WORLD() end
local x, y = Spot(alerts)
Check(globals.FCF_StopDragging ~= nil and globals.FCF_SetButtonSide ~= nil, "it follows the game's chat drag and side change")
Check(alerts.points[1] and not InChat(alerts.points[1][2], chat), "the container is not hung on the chat")
Check(x == 10 and y == 327, "it stands on the game's own spot, 27 over the column's top (" .. tostring(x) .. "," .. tostring(y) .. ")")

-- The chat sized taller from its top (another addon's sizing), then moved by edit mode.
column:Box(10, 420)
if chat.scripts.OnSizeChanged then chat.scripts.OnSizeChanged(chat) end
RunNextFrame()
x, y = Spot(alerts)
Check(x == 10 and y == 447, "it follows the chat's new top after a sizing (" .. tostring(x) .. "," .. tostring(y) .. ")")
column:Box(600, 250)
if hooks[chat] and hooks[chat].SetPoint then hooks[chat].SetPoint(chat) end
RunNextFrame()
x, y = Spot(alerts)
Check(x == 600 and y == 277, "it follows the chat moved (" .. tostring(x) .. "," .. tostring(y) .. ")")

-- The classic chat on, then off again: its hand-back leaves it off the chat on the game's spot.
local top = NewFrame("TopButton", UIParent)
top:Box(600, 300)
ns.PlaceChatAlerts(top, chat, false, 30)
ns.RestoreChatAlerts()
x, y = Spot(alerts)
Check(alerts.points[1] and not InChat(alerts.points[1][2], chat), "after the classic chat's hand-back it is still off the chat")
Check(x == 600 and y == 277, "and back on the game's spot (" .. tostring(x) .. "," .. tostring(y) .. ")")
Check(alerts:GetWidth() == 32, "with its own width back")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("chat_alerts_spot_test: ok")
