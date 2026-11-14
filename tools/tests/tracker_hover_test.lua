-- Offline test under Lua 5.4 for the classic look's colors on the game's objective tracker (Quest/QuestTracker.lua).
-- The game highlights a block under the mouse and, as the mouse leaves, writes its own title and line colors back:
-- ours go on again then, and under the mouse the game's highlight stays. A title has its level color only while
-- Forever's map filter Quest Difficulty Color is on (gold when off), and a change of that filter or of Show Quest
-- Levels writes every quest's title again at once, as the game builds it. The code is cut out of the file and run.
-- Run from the addon root: lua tools/tests/tracker_hover_test.lua (CI runs every tools/tests/*_test.lua).
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

local function Cut(from, to)
    local handle = assert(io.open(ROOT .. "/Quest/QuestTracker.lua", "r"))
    local source = handle:read("a")
    handle:close()
    local first = source:find(from, 1, true)
    local last = first and source:find(to, first, true)
    assert(first and last, "the code to test is in the file: " .. from)
    return source:sub(first, last - 1)
end

-- The game's color styles, each with the one it swaps to under the mouse; a done line has none.
local STYLE = {
    Normal = { r = 0.8, g = 0.8, b = 0.8 }, NormalHighlight = { r = 1, g = 1, b = 1 },
    Failed = { r = 0.6, g = 0.1, b = 0.1 }, FailedHighlight = { r = 1, g = 0.1, b = 0.1 },
    Header = { r = 0.75, g = 0.61, b = 0 }, HeaderHighlight = { r = 1, g = 0.82, b = 0 },
    Complete = { r = 0.6, g = 0.6, b = 0.6 },
}
for _, name in ipairs({ "Normal", "Failed", "Header" }) do
    STYLE[name].reverse, STYLE[name .. "Highlight"].reverse = STYLE[name .. "Highlight"], STYLE[name]
end

local LEVEL_GREEN = { 0.25, 0.75, 0.25 }
local GOLD = { 1, 0.82, 0 }
local forever, cvars = true, {}
local ns = {
    EMPTY = {},
    OnForever = function() return forever end,
    GetCVar = function(name) return cvars[name] end,
    QuestTitlesColored = function() return not forever or cvars.showQuestDifficultyColor ~= "0" end,
    QuestLevelColor = function() return LEVEL_GREEN[1], LEVEL_GREEN[2], LEVEL_GREEN[3] end,
    StripQuestLevel = function() end,
    -- As the game's secure hook: ours runs after the method, with its arguments.
    HookMethod = function(frame, method, fn)
        local old = frame[method]
        frame[method] = function(...)
            old(...)
            fn(...)
        end
    end,
}

local PRELUDE = [[
local active = true
local SIZE_TITLE, SIZE_LINE = 11, 10
local function Shadow() end
local function SetFontIf() end
local function SizeStep() return 0 end
local function SkinItemButton() end
]]
local code = PRELUDE .. Cut("local GOLD = ", "local HEADER_ART") .. Cut("local function QuestLevelAndColor", "local function SkinModules")
-- The game's title: the level always in front on Forever, the difficulty color around it while its filter is on.
local function GameTitle(_, title)
    title = "[20] " .. title
    if cvars.showQuestDifficultyColor ~= "0" then title = "|cff40c040" .. title .. "|r" end
    return title
end
local module = { usedBlocks = { quest = {} }, GetQuestTagText = function() return "(Elite)" end }
local env = setmetatable({
    ns = ns, OBJECTIVE_TRACKER_COLOR = STYLE,
    C_QuestLog = { GetQuestDifficultyLevel = function() return 20 end },
    ObjectiveTrackerFrame = { modules = { module, { usedBlocks = { other = { {} } } } } },
    QuestUtils_GetQuestName = function() return "Wolves" end,
    SetQuestTitleLevelAndDifficultyColor = GameTitle,
}, { __index = _G })
local SkinBlock, ours, FilterChanged = assert(load(code
    .. "\nreturn SkinBlock, { GREY = GREY, WHITE = WHITE, GREEN = GREEN }, FilterChanged", "tracker", "t", env))()

local function Text(text, line)
    return {
        text = text, line = line,
        GetText = function(self) return self.text end,
        SetText = function(self, value) self.text = value end,
        SetTextColor = function(self, r, g, b) self.rgb = { r, g, b } end,
        GetParent = function(self) return self.line end,
    }
end

local function Paint(fontString, style)
    fontString:SetTextColor(style.r, style.g, style.b)
    fontString.colorStyle = style
end

-- The game's block: text set in a style (its highlight under the mouse), and the hover pass over title and lines.
local function Block()
    local block = { id = 7, poiQuestID = 7, usedLines = {}, parentModule = module }
    module.usedBlocks.quest[7] = block
    block.HeaderText = Text("Wolves")
    function block:SetStringText(fontString, text, _, style, useHighlight)
        fontString:SetText(text)
        style = style or STYLE.Normal
        if useHighlight and style.reverse then style = style.reverse end
        if fontString.colorStyle ~= style then Paint(fontString, style) end
    end
    function block:ForEachUsedLine(fn)
        for _, line in pairs(self.usedLines) do fn(line) end
    end
    function block:UpdateHighlight()
        Paint(self.HeaderText, self.isHighlighted and STYLE.HeaderHighlight or STYLE.Header)
        local dash = self.isHighlighted and STYLE.NormalHighlight or STYLE.Normal
        for _, line in pairs(self.usedLines) do
            local style = line.Text.colorStyle.reverse
            if style then
                Paint(line.Text, style)
                line.Dash:SetTextColor(dash.r, dash.g, dash.b)
            end
        end
    end
    function block:Add(key, text, style)
        local line = self.usedLines[key] or {}
        line.Text, line.Dash = line.Text or Text("", line), line.Dash or Text("-", line)
        self.usedLines[key] = line
        self:SetStringText(line.Text, text, nil, style, self.isHighlighted)
        return line
    end
    function block:Hover(over)
        self.isHighlighted = over
        self:UpdateHighlight()
    end
    block:SetStringText(block.HeaderText, "Wolves", nil, STYLE.Header, false)
    return block
end

local function Is(fontString, r, g, b)
    local rgb = fontString.rgb
    return rgb ~= nil and rgb[1] == r and rgb[2] == g and rgb[3] == b
end
local function IsOurs(fontString, rgb) return Is(fontString, rgb[1], rgb[2], rgb[3]) end
local function IsStyle(fontString, style) return Is(fontString, style.r, style.g, style.b) end

local block = Block()
local none = block:Add(1, "0/5 Boars slain", STYLE.Normal)
local some = block:Add(2, "2/5 Wolves slain", STYLE.Normal)
local done = block:Add(3, "Speak to the innkeeper", STYLE.Complete)
local lost = block:Add(4, "Keep the caravan alive", STYLE.Failed)
SkinBlock(block)

local function OursEverywhere(when)
    Check(IsOurs(block.HeaderText, LEVEL_GREEN), when .. ": the title has the quest's level color")
    Check(IsOurs(none.Text, ours.GREY) and IsOurs(none.Dash, ours.GREY), when .. ": an untouched goal and its dash are grey")
    Check(IsOurs(some.Text, ours.WHITE) and IsOurs(some.Dash, ours.WHITE), when .. ": a started goal and its dash are white")
    Check(IsOurs(done.Text, ours.GREEN), when .. ": a done goal is green")
    Check(IsStyle(lost.Text, STYLE.Failed), when .. ": a failed goal keeps the game's red")
end
OursEverywhere("first dressed")

block:Hover(true)
Check(IsStyle(block.HeaderText, STYLE.HeaderHighlight), "under the mouse the title has the game's highlight")
Check(IsStyle(some.Text, STYLE.NormalHighlight) and IsStyle(some.Dash, STYLE.NormalHighlight),
    "under the mouse a goal and its dash have the game's highlight")
Check(IsStyle(lost.Text, STYLE.FailedHighlight), "under the mouse a failed goal has the game's brighter red")

block:Add(2, "3/5 Wolves slain", STYLE.Normal)
block:SetStringText(block.HeaderText, "Wolves", nil, STYLE.Header, true)
Check(IsStyle(some.Text, STYLE.NormalHighlight), "a goal the game writes again under the mouse keeps the highlight")
Check(IsStyle(block.HeaderText, STYLE.HeaderHighlight), "a title the game writes again under the mouse keeps the highlight")

block:Hover(false)
OursEverywhere("the mouse gone")

block:Add(1, "5/5 Boars slain", STYLE.Normal)
Check(IsOurs(none.Text, ours.GREEN) and IsOurs(none.Dash, ours.GREEN), "a goal filled after a hover turns green")

-- The filter off: the title is gold at rest and after a hover, never its level color.
cvars.showQuestDifficultyColor = "0"
block:SetStringText(block.HeaderText, "[20] Wolves", nil, STYLE.Header, false)
Check(IsOurs(block.HeaderText, GOLD), "filter off: the title is gold")
block:Hover(true)
block:Hover(false)
Check(IsOurs(block.HeaderText, GOLD), "filter off: the title is gold again as the mouse leaves")

-- The filter changed with the tracker in view: each quest's title is written again at once, the game's way.
cvars.showQuestDifficultyColor = "1"
FilterChanged(nil, "CVAR_UPDATE", "showQuestDifficultyColor")
Check(block.HeaderText.text == "|cff40c040[20] Wolves (Elite)|r", "filter turned on: the title carries the game's color at once")
Check(IsOurs(block.HeaderText, LEVEL_GREEN), "filter turned on: the level color under it")
cvars.showQuestDifficultyColor = "0"
FilterChanged(nil, "CVAR_UPDATE", "showQuestDifficultyColor")
Check(block.HeaderText.text == "[20] Wolves (Elite)", "filter turned off: the title is plain at once")
Check(IsOurs(block.HeaderText, GOLD), "filter turned off: the title is gold at once")
block.HeaderText.text = "stale"
FilterChanged(nil, "CVAR_UPDATE", "showQuestLevel")
Check(block.HeaderText.text == "[20] Wolves (Elite)", "Show Quest Levels changed: the title is written again at once")
block.HeaderText.text = "stale"
FilterChanged(nil, "CVAR_UPDATE", "questPOI")
Check(block.HeaderText.text == "stale", "another setting writes no title")

-- Retail has no such filter: the level color as ever.
forever = false
block:SetStringText(block.HeaderText, "Wolves", nil, STYLE.Header, false)
Check(IsOurs(block.HeaderText, LEVEL_GREEN), "retail: the title keeps its level color")

if failed > 0 then
    print(string.format("tracker hover: %d failed", failed))
    os.exit(1)
end
print("tracker hover: ok")
