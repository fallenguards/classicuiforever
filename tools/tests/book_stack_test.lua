-- Offline test under Lua 5.4 for how our spellbook and its casting layer stack with other windows (Spells/BookStack.lua,
-- the layer's creation in Spells/SpellBook.lua). The layer was on strata HIGH, so its spell icons showed and took the
-- mouse through a window moved over the book (his winstack log 2026-11-24, the macro window). The stand-in client
-- stacks as his client measured (/fcuidev stacktest v1 to v4): higher strata wins, then raise order; frame level
-- does not count; only a toplevel frame is raised, by Raise, by a show, or by the client on a press; a fight locks the
-- secure layer. The layer's creation lines are cut from the file and run with the real BookStack.lua.
-- Run from the addon root: lua tools/tests/book_stack_test.lua (CI runs every tools/tests/*_test.lua).
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
local function Cut(path, from, to)
    local source = Read(path)
    local first = source:find(from, 1, true)
    local last = first and source:find(to, first, true)
    assert(first and last, path .. ": the code to test is in the file")
    return source:sub(first, last - 1)
end

------------------------------------------------------------------ the stand-in client

local RANK = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5 }
local lockdown, counter = false, 0
local frames, events, nextFrame = {}, {}, {}
local focus

local function Blocked(f, what)
    if lockdown and f.protected then error("blocked in a fight: " .. what .. " on " .. f.name, 3) end
end
local function Lift(f)
    counter = counter + 1
    f.order = counter
end

local Frame = {}
Frame.__index = Frame
function Frame:GetName() return self.name end
function Frame:GetParent() return self.parent end
function Frame:IsProtected() return self.protected end
function Frame:IsForbidden() return false end
function Frame:SetFrameStrata(s) Blocked(self, "SetFrameStrata") self.strata = s end
function Frame:GetFrameStrata() return self.strata end
function Frame:SetToplevel(on) Blocked(self, "SetToplevel") self.toplevel = on end
function Frame:Raise() Blocked(self, "Raise") if self.toplevel then Lift(self) end end
function Frame:Show()
    Blocked(self, "Show")
    if not self.shown and self.toplevel then Lift(self) end
    self.shown = true
end
function Frame:Hide() Blocked(self, "Hide") self.shown = false end
function Frame:SetShown(on) if on then self:Show() else self:Hide() end end
function Frame:IsShown() return self.shown end
function Frame:IsVisible() return self.shown end
for _, name in ipairs({ "EnableMouse", "SetSize", "SetPoint", "ClearAllPoints", "SetFrameLevel" }) do
    Frame[name] = function(self) Blocked(self, name) end
end

local function NewFrame(name, parent, protected)
    local f = setmetatable({ name = name or "?", parent = parent, protected = protected or false, strata = "MEDIUM",
        toplevel = false, shown = true, order = 0 }, Frame)
    frames[#frames + 1] = f
    return f
end

local UIParent = NewFrame("UIParent")
local function Top()
    local best
    for _, f in ipairs(frames) do
        if f ~= UIParent and f.shown then
            if not best or RANK[f.strata] > RANK[best.strata]
                or (RANK[f.strata] == RANK[best.strata] and f.order > best.order) then best = f end
        end
    end
    return best
end
local function Fire(event)
    for _, fn in ipairs(events[event] or {}) do fn() end
end
local function RunNextFrame()
    local queued = nextFrame
    nextFrame = {}
    for _, fn in pairs(queued) do fn() end
end
-- The player presses a frame: the client raises a toplevel frame itself (no Lua Raise), then GLOBAL_MOUSE_DOWN.
local function Press(f)
    if f.toplevel then Lift(f) end
    focus = f
    Fire("GLOBAL_MOUSE_DOWN")
    RunNextFrame()
end
local function Fight(on)
    if on then
        Fire("PLAYER_REGEN_DISABLED")
        lockdown = true
    else
        lockdown = false
        Fire("PLAYER_REGEN_ENABLED")
    end
end

local ns = {
    IsForbidden = function(f) return not f end,
    HookMethod = function(f, method, fn)
        local original = f[method]
        f[method] = function(self, ...)
            original(self, ...)
            fn(self, ...)
        end
        return true
    end,
    EventFrame = function(list, fn)
        if type(list) == "string" then list = { list } end
        for _, event in ipairs(list) do
            events[event] = events[event] or {}
            table.insert(events[event], fn)
        end
    end,
    Sched = { NextFrame = function(key, fn) nextFrame[key] = fn end },
    ClassicSlot = function() return 0, 0 end,
}
local env = setmetatable({
    ns = ns, UIParent = UIParent, BOOK_W = 1, BOOK_H = 1,
    InCombatLockdown = function() return lockdown end,
    GetMouseFoci = function() return { focus } end,
    CreateFrame = function(_, name, parent, template)
        local f = NewFrame(name, parent, template == "SecureActionButtonTemplate")
        f.shown = true
        return f
    end,
}, { __index = _G })

------------------------------------------------------------------ our book, its layer, and the macro window

assert(load(Read("/Spells/BookStack.lua"), "@Spells/BookStack.lua", "t", env))("ClassicUIForever", ns)
local book = NewFrame("ForeverClassicUISpellBook", UIParent)
book:SetToplevel(true)
book.shown = false
env.f = book
local layer = assert(load(Cut("/Spells/SpellBook.lua",
    'local clicks = CreateFrame("Button", "ForeverClassicUISpellBookClicks"', "f.Clicks = clicks")
    .. "\nreturn clicks", "layer", "t", env))()
local macro = NewFrame("MacroFrame", UIParent)
macro:SetToplevel(true)
macro.shown = false

-- The book opens: shown, then its OnShow shows the layer (SetLayer).
local function OpenBook()
    book:Show()
    layer:Show()
end

local function Name(f) return f and f.name or "nothing" end
local function Expect(want, what)
    Check(Top() == want, what .. ": " .. Name(want) .. " is on top (now " .. Name(Top()) .. ")")
end

OpenBook()
Expect(layer, "the book opened: its spell icons over it")
macro:Show()
Expect(macro, "the macro window opened over the book: it covers the spell icons")
Press(macro)
Expect(macro, "a press on the macro window keeps it over the book")
Press(book)
Expect(layer, "a press on the book brings the book forward with its spell icons over it")
Press(macro)
Expect(macro, "a press on the macro window again: it covers the book and its icons")
Press(layer)
Expect(layer, "a press on a spell icon brings the book and its icons forward")

-- A fight: nothing of ours may raise the locked layer; the book must not bury it.
local ok, err = pcall(Fight, true)
Check(ok, "the fight starts without a blocked call (" .. tostring(err) .. ")")
ok, err = pcall(Press, book)
Check(ok, "a press on the book in a fight makes no blocked call (" .. tostring(err) .. ")")
Expect(layer, "in a fight, a press on the book leaves its spell icons on top")
macro:Raise()
Expect(macro, "in a fight, a window raised after the book covers it")
book:Hide()
book:Show()
Expect(macro, "in a fight, the book reopened stays under that window, its icons too")
ok, err = pcall(Fight, false)
Check(ok, "the fight ends without a blocked call (" .. tostring(err) .. ")")
Expect(macro, "the fight's end keeps the stack")
Press(book)
Expect(layer, "after the fight, a press on the book brings it and its icons forward")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("book_stack_test: ok")
