-- Offline test under Lua 5.4: the old trade skill window's count box acts as Era's TradeSkillInputBox. A click selects
-- the number so typing replaces it, leaving the box drops the selection, and a typed 0 reads as 1. Ours only put the
-- cursor in, so typing added digits to the old number (2026-11-21).
-- Run from the addon root: lua tools/tests/trade_count_box_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local failed = 0
local function Check(ok, what)
    if not ok then
        failed = failed + 1
        print("FAIL: " .. what)
    end
end

local extras = assert(io.open(ROOT .. "/Skills/TradeSkillExtras.lua")):read("a")
local foot = extras:match("function ns%.TradeSkillFoot%(panel, craft, step%)\n(.-)\nend\n")
Check(foot ~= nil, "TradeSkillFoot is found")

-- Any frame: records scripts and the edit box calls the test reads back.
local function Frame(kind)
    local f = { kind = kind, scripts = {}, text = "", highlights = {} }
    return setmetatable(f, { __index = function(_, key)
        if key == "SetScript" then return function(self, name, fn) self.scripts[name] = fn end end
        if key == "SetText" then return function(self, text) self.text = text end end
        if key == "GetText" then return function(self) return self.text end end
        if key == "HighlightText" then
            return function(self, from, to) self.highlights[#self.highlights + 1] = { from, to } end
        end
        if key == "GetFrameLevel" then return function() return 1 end end
        return function() end
    end })
end

local made = {}
local env = setmetatable({
    ns = {
        NewFrame = function(kind)
            local f = Frame(kind)
            made[#made + 1] = f
            return f
        end,
        PanelButton = function() return Frame("Button") end,
        DressPieces = function() return {} end,
        DrainInput = function() end,
        ShellExitButton = function() return Frame("Button") end,
    },
    PageArrow = function() return Frame("Button") end,
    unpack = table.unpack,
}, { __index = _G })

if foot then
    local Foot = assert(load("local panel, craft, step = ...\n" .. foot, "TradeSkillFoot", "t", env))
    local panel = { detailBox = Frame("Frame") }
    Foot(panel, function() end, function() end)
    local count = panel.count
    Check(count ~= nil and count.kind == "EditBox", "the foot keeps its count box on the window")
    count = count or Frame("EditBox")

    local gained, lost, changed = count.scripts.OnEditFocusGained, count.scripts.OnEditFocusLost,
        count.scripts.OnTextChanged
    Check(gained ~= nil, "the count box has OnEditFocusGained")
    Check(lost ~= nil, "the count box has OnEditFocusLost")
    Check(changed ~= nil, "the count box has OnTextChanged")
    if gained then
        gained(count)
        local h = count.highlights[#count.highlights]
        Check(h ~= nil and h[1] == nil and h[2] == nil, "a click selects the whole number")
    end
    if lost then
        lost(count)
        local h = count.highlights[#count.highlights]
        Check(h ~= nil and h[1] == 0 and h[2] == 0, "leaving the box drops the selection")
    end
    if changed then
        count.text = "0"
        changed(count)
        Check(count.text == "1", "a typed 0 reads as 1")
        count.text = "12"
        changed(count)
        Check(count.text == "12", "other numbers stay as typed")
    end
end

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("trade_count_box_test: ok")
