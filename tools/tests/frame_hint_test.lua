-- Offline test under Lua 5.4 for Hide right-click hint (UI/Tooltips.lua TrimHint, Core/Scheduler.lua Sched.OnResize).
-- A unit frame's tooltip ends in a blank line and "<Right click for Frame Settings>" (Forever's UnitFrame_UpdateTooltip,
-- rebuilt every 0.2 s); both are hidden in the layout pass that sizes the tooltip, read only. The size helper is one
-- frame of the tooltip's size off screen (out of /fstack's list), made only once the setting is on; a secret line is
-- left alone; our bar tooltips add no hint while it is on.
-- Run from the addon root: lua tools/tests/frame_hint_test.lua (CI runs every tools/tests/*_test.lua).
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

-- Size helpers as Sched.OnResize pins them.
local helpers = {}
local function Frame(parent)
    local frame = { parent = parent, scripts = {}, points = {} }
    function frame:GetParent() return self.parent end
    function frame:SetScript(name, fn) self.scripts[name] = fn end
    function frame:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function frame:ClearAllPoints() self.points = {} end
    function frame:Hide() end
    function frame:Show() end
    return frame
end
UIParent = Frame(nil)
function CreateFrame(_, _, parent)
    local frame = Frame(parent)
    if parent == UIParent then helpers[#helpers + 1] = frame end
    return frame
end
function GetTime() return 0 end
C_Timer = { After = function() end }

-- The tooltip: lines with text and shown state; Show counts re-lays.
local SECRET = setmetatable({}, { __tostring = function() return "secret" end })
UNIT_POPUP_RIGHT_CLICK = "<Right click for Frame Settings>"
local lines = {}
local tip = { shown = true, relays = 0 }
function tip:NumLines() return #lines end
function tip:IsShown() return self.shown end
function tip:Show() self.relays = self.relays + 1 end
GameTooltip = tip
local function Lines(texts)
    lines = {}
    for i, text in ipairs(texts) do
        local line = { text = text, shown = true }
        function line:GetText() return self.text end
        function line:IsShown() return self.shown end
        function line:Hide() self.shown = false end
        lines[i] = line
        _G["GameTooltipTextLeft" .. i] = line
    end
    tip.relays = 0
end

local loginFn, toggleFns = nil, {}
local ns = { Report = function() end, PassReads = function(fn) return fn end, db = { hideFrameHint = true },
    EditMode = { Live = function() return false end }, OnEditMode = function() end,
    IsSecret = function(v) return v == SECRET end,
    EventFrame = function(event, fn) if event == "PLAYER_LOGIN" then loginFn = fn end return Frame(nil) end,
    OnToggle = function(fn) toggleFns[#toggleFns + 1] = fn end,
    RegisterModule = function() end, ART = {} }
assert(loadfile(ROOT .. "/Core/Scheduler.lua"))("ClassicUIForever", ns)
ns.Sched.Attach = function() end
assert(loadfile(ROOT .. "/UI/Tooltips.lua"))("ClassicUIForever", ns)

-- Off at login: nothing made; turned on: one helper of the tooltip's size, off screen.
ns.db.hideFrameHint = false
Check(loginFn ~= nil, "a login handler")
loginFn()
Check(#helpers == 0, "no size helper while the setting is off")
ns.db.hideFrameHint = true
for _, fn in ipairs(toggleFns) do fn("hideFrameHint") end
for _, fn in ipairs(toggleFns) do fn("hideFrameHint") end
Check(#helpers == 1, "one size helper once it is on, made once (got " .. #helpers .. ")")
local helper = helpers[1]
local trim = helper and helper.scripts.OnSizeChanged
Check(trim ~= nil, "the helper hears size changes")
local both = helper and #helper.points == 2
for _, point in ipairs(helper and helper.points or {}) do
    both = both and point[2] == tip and point[4] >= 10000
end
Check(both, "both helper corners on the tooltip, shifted off screen")
trim = trim or function() end

-- The client's build: the hint and the blank above it hidden, one re-lay.
Lines({ "Name", "Level 60", " ", UNIT_POPUP_RIGHT_CLICK })
trim()
Check(not lines[4].shown and not lines[3].shown, "hint and blank line hidden")
Check(lines[1].shown and lines[2].shown, "the unit's own lines kept")
Check(tip.relays == 1, "one re-lay after hiding")
-- The re-lay's own resize: nothing more.
trim()
Check(tip.relays == 1, "no second re-lay once trimmed")

-- Other tooltips untouched.
Lines({ "Item", UNIT_POPUP_RIGHT_CLICK, "Sell price" })
trim()
Check(lines[2].shown and tip.relays == 0, "a hint not last is left alone")
Lines({ "Name", "Level 60", " ", SECRET })
trim()
Check(lines[4].shown and lines[3].shown and tip.relays == 0, "a secret last line is left alone")
Lines({ "Name", "Level 60", "Guild", UNIT_POPUP_RIGHT_CLICK })
trim()
Check(not lines[4].shown and lines[3].shown, "a text line above the hint stays")
tip.shown = false
Lines({ "Name", " ", UNIT_POPUP_RIGHT_CLICK })
trim()
Check(tip.relays == 0, "a hidden tooltip is never shown")
tip.shown = true

-- Off: the client's line stays.
ns.db.hideFrameHint = false
Lines({ "Name", " ", UNIT_POPUP_RIGHT_CLICK })
trim()
Check(lines[3].shown and lines[2].shown, "setting off: the hint stays")

-- Read only, and our bar tooltips follow the setting.
local source = Read("UI/Tooltips.lua")
local section = source:match("local hintWatched.-\nend\n\nlocal function WatchHint") or ""
Check(section ~= "", "TrimHint found")
Check(not section:find("hooksecurefunc", 1, true) and not section:find("HookScript", 1, true)
    and not section:find("SetUnit", 1, true), "TrimHint hooks nothing and never rebuilds the tooltip")
Check(Read("Units/HoverNumbers.lua"):find("UNIT_POPUP_RIGHT_CLICK and not ns.db.hideFrameHint", 1, true) ~= nil,
    "bar tooltips add no hint while it is on")

if failed > 0 then
    print(failed .. " frame hint check(s) failed")
    os.exit(1)
end
print("frame hint: all checks passed")
