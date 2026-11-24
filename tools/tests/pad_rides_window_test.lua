-- Offline test under Lua 5.4 for a secure pad over a button in one of our windows (UI/SecurePad.lua ns.MapPad given the
-- window, UI/StackOver.lua). 0.65.0 put the quest log's pads on the log's strata at a level over their buttons, but
-- here raise order, not level, decides what is on top: the log, raised as it opened, covered its own pads, and Share
-- Quest (which shares only through its pad) did nothing (a player's report; /fcuidev questpads: Exit's pad at level 7
-- under its button at level 2). The stand-in client stacks as his client measured (/fcuidev stacktest v1 to v4). The
-- real MapPad and StackOver run; the pad must hold the press over its button whenever its window is the top one.
-- Run from the addon root: lua tools/tests/pad_rides_window_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 122 212 432

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
    local handle = assert(io.open(ROOT .. path, "r"))
    local source = handle:read("a")
    handle:close()
    return source
end

------------------------------------------------------------------ the stand-in client

local RANK = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5 }
local counter = 0
local frames, events, nextFrame = {}, {}, {}
local focus

local function Lift(f)
    counter = counter + 1
    f.order = counter
end
local function Noop() end

local Frame = {}
local FrameMT = { __index = function(_, k)
    if Frame[k] ~= nil then return Frame[k] end
    if type(k) == "string" and k:match("^%u") then return Noop end
end }
function Frame:GetName() return self.name end
function Frame:GetParent() return self.parent end
function Frame:IsProtected() return self.protected end
function Frame:IsForbidden() return false end
function Frame:SetFrameStrata(s)
    assert(RANK[s], "a strata name")
    self.strata = s
end
function Frame:GetFrameStrata() return self.strata end
function Frame:SetToplevel(on) self.toplevel = on end
function Frame:Raise() if self.toplevel then Lift(self) end end
function Frame:HookScript(script, fn)
    rawset(self, "scripts", rawget(self, "scripts") or {})
    table.insert(self.scripts, { script, fn })
end
function Frame:Show()
    local was = self.shown
    if not was and self.toplevel then Lift(self) end
    self.shown = true
    if was then return end
    for _, s in ipairs(rawget(self, "scripts") or {}) do
        if s[1] == "OnShow" then s[2](self) end
    end
end
function Frame:Hide() self.shown = false end
function Frame:IsShown() return self.shown end
function Frame:IsVisible()
    if not self.shown then return false end
    return self.parent == nil or self.parent:IsVisible()
end
function Frame:SetFrameLevel(level) self.level = level end
function Frame:GetFrameLevel() return self.level end
function Frame:GetLeft() return 100 end
function Frame:GetBottom() return 100 end
function Frame:GetWidth() return 120 end
function Frame:GetHeight() return 22 end
function Frame:GetEffectiveScale() return 1 end
function Frame:GetHitRectInsets() return 0, 0, 0, 0 end
function Frame:GetScript() return nil end

local function NewFrame(name, parent, protected)
    local f = setmetatable({ name = name or "?", parent = parent, protected = protected or false, strata = "MEDIUM",
        toplevel = false, shown = true, order = 0, level = parent and parent.level + 1 or 0 }, FrameMT)
    frames[#frames + 1] = f
    return f
end

local UIParent = NewFrame("UIParent")
-- The tree a frame draws in: its UIParent child.
local function Root(f)
    while f.parent and f.parent ~= UIParent do f = f.parent end
    return f
end
-- What holds a press at the button's spot: every frame there is one of these trees; strata, then raise order.
local function Top(spot)
    local best
    for _, f in ipairs(spot) do
        local root = Root(f)
        if f:IsVisible() and (not best or RANK[root.strata] > RANK[Root(best).strata]
            or (RANK[root.strata] == RANK[Root(best).strata] and root.order > Root(best).order)) then best = f end
    end
    return best
end
local function Fire(event)
    for _, fn in ipairs(events[event] or {}) do fn() end
end
local function RunNextFrame()
    for _ = 1, 3 do
        local queued = nextFrame
        nextFrame = {}
        for _, fn in pairs(queued) do fn() end
    end
end
-- The player presses a frame: the client raises its toplevel tree itself (no Lua Raise), then GLOBAL_MOUSE_DOWN.
local function Press(f)
    local root = Root(f)
    if root.toplevel then Lift(root) end
    focus = f
    Fire("GLOBAL_MOUSE_DOWN")
    RunNextFrame()
end

local reported = {}
local ns = {
    Report = function(err) reported[#reported + 1] = tostring(err) end,
    IsForbidden = function(f) return not f end,
    HookMethod = function(f, method, fn)
        local original = f[method]
        rawset(f, method, function(self, ...)
            original(self, ...)
            fn(self, ...)
        end)
        return true
    end,
    EventFrame = function(list, fn)
        if type(list) == "string" then list = { list } end
        for _, event in ipairs(list) do
            events[event] = events[event] or {}
            table.insert(events[event], fn)
        end
    end,
    Sched = { NextFrame = function(key, fn) nextFrame[key] = fn end, OnMove = Noop, OnVisible = Noop, Attach = Noop },
    OnEditMode = Noop, OnToggle = Noop,
    EditMode = { Live = function() return false end },
    SetPointOnce = Noop,
    SetAttributeIf = Noop,
}
local env = setmetatable({
    ns = ns, UIParent = UIParent,
    InCombatLockdown = function() return false end,
    GetMouseFoci = function() return { focus } end,
    CreateFrame = function(_, name, parent, template)
        local f = NewFrame(name, parent, template == "SecureActionButtonTemplate")
        return f
    end,
}, { __index = _G })
for _, path in ipairs({ "/UI/StackOver.lua", "/UI/SecurePad.lua" }) do
    assert(load(Read(path), "@" .. path:sub(2), "t", env))("ClassicUIForever", ns)
end

------------------------------------------------------------------ our quest log, its Share pad, another window

local log = NewFrame("ForeverClassicUIQuestLog", UIParent)
log:SetToplevel(true)
log.shown = false
local share = NewFrame("ForeverClassicUIQuestLog.share", log)
local other = NewFrame("MacroFrame", UIParent)
other:SetToplevel(true)
other.shown = false

log:Show()
local pad = ns.MapPad(share, log, Noop, "/click Share")
RunNextFrame()
Check(#reported == 0, "the pad is placed without an error (" .. tostring(reported[1]) .. ")")
Check(pad ~= nil and pad:IsShown(), "the pad over Share is shown while the log is")
if pad then
    local spot = { share, pad, other }
    Check(Top(spot) == pad, "the log open: the pad holds the press over Share (now " .. tostring(Top(spot).name) .. ")")
    other:Show()
    Check(Top(spot) == other, "a window opened over the log covers Share and its pad")
    Press(log)
    Check(Top(spot) == pad, "a press on the log brings it forward with the pad over Share")
    Press(other)
    Check(Top(spot) == other, "a press on the other window covers them again")
    Press(pad)
    Check(Top(spot) == pad, "a press on Share's spot through its pad brings the log forward, the pad on top")
    log:Hide()
    log:Show()
    RunNextFrame()
    Check(Top(spot) == pad, "the log closed and opened again: the pad over Share holds the press")
end

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("pad_rides_window_test: ok")
