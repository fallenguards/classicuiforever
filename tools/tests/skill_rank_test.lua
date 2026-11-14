-- Offline test under Lua 5.4 for the skill bar's rank text (Character/CharacterLists.lua EraRank): the game's
-- "250 / 300" is written as 1.x's "250/300", and a rank that is a secret string (the Defense row with a bonus) is never
-- searched: it is written again from the row's own numbers. The code is cut out of the file and run.
-- Run from the addon root: lua tools/tests/skill_rank_test.lua (CI runs every tools/tests/*_test.lua).
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

local function Cut(path, from, to)
    local handle = assert(io.open(ROOT .. path, "r"))
    local source = handle:read("a")
    handle:close()
    local first = source:find(from, 1, true)
    local last = first and source:find(to, first, true)
    assert(first and last, path .. ": the code to test is in the file")
    return source:sub(first, last - 1)
end

-- A secret stands in as a value that errors when indexed, as the game's does for our code.
local SECRET = setmetatable({}, { __index = function() error("attempt to index a secret string value") end })
local SECRET_BONUS = setmetatable({}, { __index = function() error("attempt to index a secret number value") end })
local ns = { IsSecret = function(v) return v == SECRET or v == SECRET_BONUS end }

local code = Cut("/Character/CharacterLists.lua", 'local RANK_BONUS = ', "-- Reputation: old plate")
local EraRank = assert(load(code .. "\nreturn EraRank", "EraRank", "t", setmetatable({ ns = ns }, { __index = _G })))()

local written
local bar = { Text = {
    SetText = function(_, text) written = { "text", text } end,
    SetFormattedText = function(_, fmt, ...) written = { "formatted", fmt, ... } end,
} }
local row = { GetElementData = function() return { rank = 108, maxRank = 115, modifier = SECRET_BONUS } end }

written = nil
EraRank(bar, row, "250 / 300")
Check(written and written[1] == "text" and written[2] == "250/300", "the game's spaced rank is written as 250/300")

written = nil
EraRank(bar, row, "250/300")
Check(written == nil, "a rank already in the old form is left alone")

written = nil
EraRank(bar, row, nil)
EraRank(bar, row, 12)
Check(written == nil, "no text and a number are left alone")

written = nil
local ok, err = pcall(EraRank, bar, row, SECRET)
Check(ok, "a secret rank is never searched: " .. tostring(err))
Check(written and written[1] == "formatted" and written[3] == 108 and written[4] == SECRET_BONUS and written[5] == 115,
    "a secret rank is written again from the row's rank, bonus and top rank")
Check(written and written[2]:find("%)|r/%%d$") ~= nil, "in the old form, no spaces round the slash")

written = nil
ok = pcall(EraRank, bar, { GetElementData = function() return nil end }, SECRET)
Check(ok and written == nil, "a secret rank on a row with no data is left as the game wrote it")

-- The dressing pass judges by the text the game stored on the bar: a font string that once held a secret answers
-- secret from GetText ever after, plain text or not, and would be written in the bonus form with a bonus of 0.
local handle = assert(io.open(ROOT .. "/Character/CharacterLists.lua", "r"))
local source = handle:read("a")
handle:close()
Check(source:find("EraRank(bar, row, bar.barProgressText)", 1, true) ~= nil, "the dressing pass passes the bar's stored text")
Check(source:find("EraRank(bar, row, bar.Text:GetText())", 1, true) == nil, "the dressing pass never reads the bar's text back")

if failed > 0 then
    print(string.format("skill rank: %d failed", failed))
    os.exit(1)
end
print("skill rank: ok")
