-- Offline test under Lua 5.4 for UI/PadNav.lua: the window of ours on top takes the pad through override bindings to
-- key proxies, the pointer starts top left and moves by direction, A binds to a protected button by name out of a
-- fight and the pointer stays on it in one, the game's navigator up makes the layer yield, B closes, a hide lets go.
-- Run from the addon root: lua tools/tests/pad_nav_test.lua (CI runs every tools/tests/*_test.lua).
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

------------------------------------------------------------------ the stub client

local combat = false
function InCombatLockdown() return combat end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end

local bindings = {}        -- key -> the proxy name bound, nil once cleared
local cleared = 0
local gameKeys = {}        -- key -> an action the game's key sets put over ours
function SetOverrideBindingClick(_, _, key, name)
    bindings[key] = name
    gameKeys[key] = nil
end
function ClearOverrideBindings() wipe(bindings) cleared = cleared + 1 end
function GetBindingAction(key)
    if gameKeys[key] then return gameKeys[key] end
    return bindings[key] and ("CLICK " .. bindings[key] .. ":LeftButton") or ""
end

local Region = {}
Region.__index = function(_, key) return Region[key] or function() end end
function Region:GetSize() return 32, 32 end
function Region:GetStringWidth() return 40 end

local Frame = {}
Frame.__index = Frame
local function NewFrame(kind, name, parent)
    local f = setmetatable({ kind = kind, name = name, parent = parent, children = {}, scripts = {}, hooks = {},
        shown = true, mouse = true, enabled = true, points = {} }, Frame)
    if parent then parent.children[#parent.children + 1] = f end
    if name then _G[name] = f end
    return f
end
function CreateFrame(kind, name, parent) return NewFrame(kind, name, parent) end
function Frame:GetName() return self.name end
function Frame:GetParent() return self.parent end
function Frame:GetChildren() return table.unpack(self.children) end
function Frame:IsObjectType(kind) return self.kind == kind end
function Frame:IsForbidden() return false end
function Frame:IsProtected() return self.protected == true end
function Frame:SetSize(w, h) self.w, self.h = w, h end
function Frame:SetWidth(w) self.w = w end
function Frame:SetHeight(h) self.h = h end
function Frame:SetPoint(...) self.points[#self.points + 1] = { ... } end
function Frame:ClearAllPoints() self.points = {} end
function Frame:EnableMouse(on) self.mouse = on end
function Frame:IsMouseEnabled() return self.mouse end
function Frame:IsEnabled() return self.enabled end
function Frame:RegisterForClicks() end
function Frame:SetFrameStrata() end
function Frame:SetFrameLevel() end
function Frame:GetAlpha() return 1 end
function Frame:SetScript(script, fn) self.scripts[script] = fn end
function Frame:GetScript(script) return self.scripts[script] end
function Frame:HookScript(script, fn)
    self.hooks[script] = self.hooks[script] or {}
    table.insert(self.hooks[script], fn)
end
local function Run(self, script, ...)
    if self.scripts[script] then self.scripts[script](self, ...) end
    for _, fn in ipairs(self.hooks[script] or {}) do fn(self, ...) end
end
function Frame:Show() if not self.shown then self.shown = true Run(self, "OnShow") end end
function Frame:Hide() if self.shown then self.shown = false Run(self, "OnHide") end end
function Frame:IsShown() return self.shown end
function Frame:IsVisible()
    local f = self
    while f do
        if not f.shown then return false end
        f = f.parent
    end
    return true
end
-- A button's box: left, top and size.
function Frame:At(left, top, w, h) self.left, self.top, self.w, self.h = left, top, w or 30, h or 20 return self end
function Frame:GetLeft() return self.left end
function Frame:GetTop() return self.top end
function Frame:GetCenter()
    if not self.left then return nil end
    return self.left + self.w / 2, self.top - self.h / 2
end
function Frame:LockHighlight() self.lit = true end
function Frame:UnlockHighlight() self.lit = false end
function Frame:Click(button) Run(self, "OnClick", button, true) end
function Frame:CreateTexture() return setmetatable({}, Region) end
function Frame:CreateFontString() return setmetatable({}, Region) end
function Frame:SetInputKey(key) self.inputKey = key end
function Frame:SetText(text) self.text = text end

UIParent = NewFrame("Frame", "UIParent")
SmartNavigation = NewFrame("Frame", "SmartNavigation")
SmartNavigation.shown = false

------------------------------------------------------------------ the addon

local ns = { EMPTY = setmetatable({}, { __newindex = function() error("EMPTY written") end }) }
ns.IsSecret = function() return false end
ns.IsForbidden = function() return false end
ns.SafeCall = function(fn, ...) return pcall(fn, ...) end
ns.KeyProxy = function(name) return name .. "Key" end
ns.NewFrame = function(kind, name, parent) return NewFrame(kind, name, parent) end
ns.SetPointOnce = function(frame, ...) frame:ClearAllPoints() frame:SetPoint(...) end
ns.HookScriptOnce = function(frame, script, fn) frame:HookScript(script, fn) end
local keepKeys, bindingEvent
ns.Sched = { NextFrame = function(_, fn) fn() end, Attach = function(_, spec) keepKeys = spec.fn end }
ns.EventFrame = function(events, fn) if events == "UPDATE_BINDINGS" then bindingEvent = fn end end
ns.GamepadUI = function() return true end
ns.OnForever = function() return true end
ns.EachChild = function(frame, fn, a1)
    local n = 0
    for _, child in ipairs(frame.children) do
        n = n + 1
        fn(child, a1)
    end
    return n
end

assert(loadfile(ROOT .. "/UI/PadNav.lua"))("ClassicUIForever", ns)

------------------------------------------------------------------ the checks

local closed = 0
local window = NewFrame("Frame", "ClassicUIForeverTestWindow", UIParent)
window.shown = false
local one = NewFrame("Button", nil, window):At(10, 110)       -- top left
local two = NewFrame("Button", nil, window):At(100, 110)      -- right of it
local three = NewFrame("Button", nil, window):At(10, 60)      -- under the first
local spell = NewFrame("Button", "ClassicUIForeverTestSpell", window):At(100, 60)
spell.protected = true
local deaf = NewFrame("Button", nil, window):At(10, 10)       -- takes no mouse: not a stop
deaf.mouse = false
local pressed = {}
for _, b in ipairs({ one, two, three }) do b:SetScript("OnClick", function(self) pressed[#pressed + 1] = self end) end
local prompted
ns.PadNav(window, { close = function() closed = closed + 1 end, prompts = {
    { key = "PAD3", text = "Bind", fn = function(_, button) prompted = button end },
    { key = "PAD4", text = "Edit", click = "GameEditButton" } } })

-- The pointer is private: the selection reads by the button's locked highlight.
local function Press(name) _G[name]:Click("LeftButton") end

Check(next(bindings) == nil, "a hidden window binds nothing")
window:Show()
Check(bindings.PADDUP == "ClassicUIForeverPadupKey" and bindings.PADDRIGHT == "ClassicUIForeverPadrightKey",
    "shown, the d-pad binds to the move proxies through key proxies")
Check(bindings.PAD2 == "ClassicUIForeverPadCloseKey", "B binds to the close proxy")
Check(bindings.PAD1 == "ClassicUIForeverPadPressKey", "A binds to the press proxy over a plain button")
Check(bindings.PAD3 == "ClassicUIForeverPadPrompt1Key", "a prompt with fn binds to its proxy")
Check(bindings.PAD4 == "GameEditButtonKey", "a prompt with click binds to the game's button by name")
Check(one.lit == true and not two.lit, "the top left button is selected first")
Press("ClassicUIForeverPadPrompt1")
Check(prompted == one, "a prompt's fn gets the selected button")

-- The game's key sets bind the pad keys over ours as they change: ours go back on top.
gameKeys.PAD3 = "GAMEPADACTIONBUTTON5"
Check(bindingEvent ~= nil and keepKeys ~= nil, "a binding event and a timer while the legend shows look after the keys")
bindingEvent()
Check(GetBindingAction("PAD3") == "CLICK ClassicUIForeverPadPrompt1Key:LeftButton" and bindings.PADDUP == "ClassicUIForeverPadupKey",
    "a key the game took back is ours again, every other one set anew")
local before = cleared
keepKeys()
Check(cleared == before, "keys still ours: nothing is set again")

Press("ClassicUIForeverPadright")
Check(two.lit == true and one.lit == false, "right moves to the button beside it")
Press("ClassicUIForeverPaddown")
Check(spell.lit == true and two.lit == false, "down moves to the button under it")
Check(bindings.PAD1 == "ClassicUIForeverTestSpellKey", "A binds to a protected button by its name's key proxy")

combat = true
Press("ClassicUIForeverPadleft")
Check(spell.lit == true and not three.lit, "in a fight the pointer stays on the protected button A is bound to")
combat = false
Press("ClassicUIForeverPadleft")
Check(three.lit == true and spell.lit == false, "out of it, left moves on")
Check(bindings.PAD1 == "ClassicUIForeverPadPressKey", "A is back on the press proxy over a plain button")
Press("ClassicUIForeverPadPress")
Check(pressed[1] == three, "A presses the plain button's own click")
Press("ClassicUIForeverPaddown")
Check(three.lit == true, "a button that takes no mouse is no stop")

-- A frame of ours that takes the pad keys itself (the bind dialog): the layer lets go while it shows.
local binder = NewFrame("Frame", "ClassicUIForeverTestBinder", UIParent)
binder.shown = false
ns.PadNavYield(binder)
binder:Show()
Check(next(bindings) == nil, "a frame that binds the keys itself shows: the layer lets go of its keys")
binder:Hide()
Check(bindings.PADDUP == "ClassicUIForeverPadupKey", "it hides: the layer's keys are back")

SmartNavigation:Show()
Check(next(bindings) == nil and cleared >= 1, "the game's navigator up: the layer yields its bindings")
SmartNavigation:Hide()
Check(bindings.PADDUP == "ClassicUIForeverPadupKey", "the navigator gone: the bindings are back")
Check(three.lit == true, "the selection is kept across the yield")

Press("ClassicUIForeverPadClose")
Check(closed == 1, "B runs the window's close")
window:Hide()
Check(next(bindings) == nil, "the window hidden: the bindings are let go")

-- A list at its shown end scrolls under the pointer instead of the pointer leaving it.
local listWin = NewFrame("Frame", "ClassicUIForeverTestList", UIParent)
listWin.shown = false
NewFrame("Button", nil, listWin):At(10, 100)   -- the list's first row
local rowB = NewFrame("Button", nil, listWin):At(10, 70)
local below = NewFrame("Button", nil, listWin):At(10, 20)
local scrolled = 0
ns.PadNav(listWin, { scroll = function(button, dy)
    if button == rowB and dy < 0 and scrolled < 2 then scrolled = scrolled + 1 return true end
    return false
end })
listWin:Show()
Press("ClassicUIForeverPaddown")
Check(rowB.lit == true, "down moves along the list")
Press("ClassicUIForeverPaddown")
Check(scrolled == 1 and rowB.lit == true and not below.lit, "at the list's shown end down scrolls, the pointer stays")
Press("ClassicUIForeverPadright")
Check(rowB.lit == true, "a sideways move never scrolls")
Press("ClassicUIForeverPaddown")
Press("ClassicUIForeverPaddown")
Check(below.lit == true, "the list at its real end: down leaves it")
listWin:Hide()

-- The gamepad interface off: no pick, no held highlight, even when a window asks the layer to refresh.
local pad = ns.GamepadUI
ns.GamepadUI = function() return false end
local quiet = NewFrame("Frame", "ClassicUIForeverTestQuiet", UIParent)
quiet.shown = false
local quietButton = NewFrame("Button", nil, quiet):At(300, 300)
ns.PadNav(quiet)
quiet:Show()
ns.PadNavRefresh(quiet)
Check(not quietButton.lit and next(bindings) == nil, "gamepad off: the window shows with no pick and no keys")
quiet:Hide()
ns.GamepadUI = pad

-- Two windows: the one shown last has the pad; closing it hands the pad back.
local other = NewFrame("Frame", "ClassicUIForeverTestOther", UIParent)
other.shown = false
local only = NewFrame("Button", nil, other):At(200, 200)
ns.PadNav(other)
window:Show()
other:Show()
Check(only.lit == true, "the window shown last takes the pad")
other:Hide()
Check(one.lit == true or two.lit == true or three.lit == true, "the one under it has the pad again")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("pad_nav_test: ok")
