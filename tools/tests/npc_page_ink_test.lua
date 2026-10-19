-- Offline test under Lua 5.4 for the gossip window's text on a themed page (Windows/NpcWindows.lua PaintGossipRows): the
-- game paints every greeting and option line dark again on each update, and the painter skipped lines it remembered
-- lighting, so the text stayed dark on the dark page.
-- Run from the addon root: lua tools/tests/npc_page_ink_test.lua (CI runs every tools/tests/*_test.lua).
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

local handle = assert(io.open(ROOT .. "/Windows/NpcWindows.lua", "r"))
local source = handle:read("a")
handle:close()
local first = source:find("local lit = setmetatable", 1, true)
local last = first and source:find("local watching", first, true)
assert(first and last, "the page painter is in Windows/NpcWindows.lua")

local GAME = { 0.18, 0.12, 0.06 }
local function Line()
    local fs = { rgb = { GAME[1], GAME[2], GAME[3] }, fixed = false }
    function fs:GetTextColor() return self.rgb[1], self.rgb[2], self.rgb[3] end
    function fs:SetTextColor(r, g, b) self.rgb = { r, g, b } end
    function fs:SetFixedColor(on) self.fixed = on end
    return fs
end
local greeting = { GreetingText = Line() }
local optionText = Line()
local option = { GetFontString = function() return optionText end }
local rows = { greeting, option }
local dark = true
local env = setmetatable({
    ns = {
        PAGE_INK = { 0.9, 0.86, 0.76 },
        PageDark = function() return dark end,
        Near = function(a, b, tol) return math.abs(a - b) <= tol end,
        InkPage = function() end,
        Path = function(frame, a, b) return frame[a][b] end,
    },
    GossipFrame = { GreetingPanel = { ScrollBox = { ForEachFrame = function(_, fn) for _, row in ipairs(rows) do fn(row) end end } } },
    GetMaterialTextColors = function() return GAME, { 0, 0, 0 } end,
    unpack = table.unpack,
}, { __index = _G })
local PaintGossipRows = assert(load(source:sub(first, last - 1) .. "\nreturn PaintGossipRows", "gossip", "t", env))()

local function Lit(fs) return fs.rgb[1] == 0.9 and fs.rgb[2] == 0.86 end

PaintGossipRows()
Check(Lit(greeting.GreetingText) and Lit(optionText), "on a dark page the greeting and options turn near white")
Check(optionText.fixed, "an option's text holds its color through hover")

-- The game's update paints them dark again.
greeting.GreetingText:SetTextColor(GAME[1], GAME[2], GAME[3])
optionText:SetTextColor(GAME[1], GAME[2], GAME[3])
optionText:SetFixedColor(false)
PaintGossipRows()
Check(Lit(greeting.GreetingText) and Lit(optionText), "painted dark again by the game, they turn near white again")

-- The page light again: the game's color back.
dark = false
PaintGossipRows()
Check(greeting.GreetingText.rgb[1] == GAME[1] and optionText.rgb[1] == GAME[1] and not optionText.fixed,
    "a light page gives the game's color back")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("npc_page_ink_test: all checks passed")
