-- Offline test under Lua 5.4 for a quest title under the mouse in the map side tab's list (Quest/QuestMapPane.lua
-- SkinTitle): the game's own hover paints the title in its modern difficulty's highlight, so a quest 1.x draws gray
-- turned green under the mouse. Ours turns it white as Era's quest log does, and the mouse leaving gives back ours.
-- Run from the addon root: lua tools/tests/quest_title_hover_test.lua (CI runs every tools/tests/*_test.lua).
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

local handle = assert(io.open(ROOT .. "/Quest/QuestMapPane.lua", "r"))
local source = handle:read("a")
handle:close()
local first = source:find("-- 1.x difficulty color; gold when", 1, true)
local last = first and source:find("local function SkinRows", first, true)
assert(first and last, "the title dressing is in Quest/QuestMapPane.lua")

local GRAY, GOLD, WHITE = { 0.5, 0.5, 0.5 }, { 1, 0.82, 0 }, { 1, 1, 1 }
-- The game's own colors for this quest: its modern rating calls it standard (green), its hover the bright green.
local GAME, GAME_HOVER = { 0.25, 0.75, 0.25 }, { 0.43, 0.93, 0.43 }

local function Text()
    local fs = { color = {} }
    function fs:SetTextColor(r, g, b) self.color = { r, g, b } end
    function fs:GetHeight() return 12 end
    function fs:SetFontObject() end
    function fs:GetText() return "Egg Hunt" end
    function fs:SetText() end
    return fs
end

-- A title button as the game's template makes it: its own OnEnter and OnLeave scripts run first, then hooks.
local function Title()
    local button = { questID = 500, questLogIndex = 1, Text = Text(), TagText = Text(), hooks = {} }
    button.scripts = {
        OnEnter = function(self)
            self.Text:SetTextColor(table.unpack(GAME_HOVER))
            self.TagText:SetTextColor(table.unpack(GAME_HOVER))
        end,
        OnLeave = function(self)
            self.Text:SetTextColor(table.unpack(GAME))
            self.TagText:SetTextColor(table.unpack(GAME))
        end,
    }
    function button:HookScript(name, fn)
        self.hooks[name] = self.hooks[name] or {}
        table.insert(self.hooks[name], fn)
    end
    function button:Run(name)
        self.scripts[name](self)
        for _, fn in ipairs(self.hooks[name] or {}) do fn(self) end
    end
    return button
end

local colored = true
local env = setmetatable({
    active = true,
    wipe = function(t) for k in pairs(t) do t[k] = nil end end,
    C_QuestLog = { GetInfo = function() return { difficultyLevel = 10, level = 10 } end,
        GetQuestDifficultyLevel = function() return 10 end },
    ns = {
        QuestTitlesColored = function() return colored end,
        QuestLevelColor = function() return table.unpack(GRAY) end,
        Once = function(frame, key)
            frame.once = frame.once or {}
            if frame.once[key] then return false end
            frame.once[key] = true
            return true
        end,
        StripQuestLevel = function() end,
        QuestListFont = {},
    },
}, { __index = _G })
local SkinTitle = assert(load(source:sub(first, last - 1) .. "\nreturn SkinTitle", "title", "t", env))()

local function Is(fs, want) return fs.color[1] == want[1] and fs.color[2] == want[2] and fs.color[3] == want[3] end
local function Shown(fs) return table.concat(fs.color, ",") end

local button = Title()
SkinTitle(button)
Check(Is(button.Text, GRAY), "dressed: the title is 1.x's gray (" .. Shown(button.Text) .. ")")

button:Run("OnEnter")
Check(Is(button.Text, WHITE), "under the mouse: the title is white, not the game's green (" .. Shown(button.Text) .. ")")
Check(Is(button.TagText, WHITE), "under the mouse: its tag is white too (" .. Shown(button.TagText) .. ")")

button:Run("OnLeave")
Check(Is(button.Text, GRAY), "the mouse gone: gray again (" .. Shown(button.Text) .. ")")

-- A row the game reuses is dressed once: its hooks are not added again.
SkinTitle(button)
Check(#(button.hooks.OnEnter or {}) == 1 and #(button.hooks.OnLeave or {}) == 1, "a reused row keeps one hook each")

-- The map's Quest Difficulty Color off: titles are gold, still white under the mouse.
colored = false
SkinTitle(button)
Check(Is(button.Text, GOLD), "the filter off: the title is gold (" .. Shown(button.Text) .. ")")
button:Run("OnEnter")
Check(Is(button.Text, WHITE), "the filter off, under the mouse: white (" .. Shown(button.Text) .. ")")
button:Run("OnLeave")
Check(Is(button.Text, GOLD), "the filter off, the mouse gone: gold again (" .. Shown(button.Text) .. ")")

-- Ours turned off: the game's own colors, hover included.
env.active = false
button:Run("OnEnter")
Check(Is(button.Text, GAME_HOVER), "ours off: the game's hover color stays (" .. Shown(button.Text) .. ")")
button:Run("OnLeave")
Check(Is(button.Text, GAME), "ours off: the game's own color on leave (" .. Shown(button.Text) .. ")")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("quest_title_hover_test: ok")
