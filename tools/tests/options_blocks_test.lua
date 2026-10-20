-- Offline test under Lua 5.4 for the options window's column blocks (Options/OptionsWindow.lua Blocks): a page's
-- top-level heading keeps the rows after it in its block, so the columns never split a heading from its rows; a page
-- without one splits at any top-level row; All windows' rows for other pages' windows stay out of a search; a page's
-- own search keeps to that page.
-- Run from the addon root: lua tools/tests/options_blocks_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 212

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local failed = 0
local function Check(ok, what)
    if not ok then
        failed = failed + 1
        print("FAIL " .. what)
    end
end

local ns = {}
assert(loadfile(ROOT .. "/Options/OptionsSearch.lua"))("ClassicUIForever", ns)
local handle = assert(io.open(ROOT .. "/Options/OptionsWindow.lua", "r"))
local source = handle:read("a"):gsub("\r\n", "\n")
handle:close()
local first = source:find("local function Blocks(built, text, page, pageOnly)", 1, true)
local last = first and source:find("\nend\n", first, true)
assert(first and last, "Blocks(built, text, page, pageOnly) is in Options/OptionsWindow.lua")
local env = setmetatable({ ns = ns, EMPTY = {} }, { __index = _G })
local Blocks = assert(load(source:sub(first, last + 4) .. "\nreturn Blocks", "Blocks", "t", env))()

-- key, page, parent, name side, sub (a heading)
local SPEC = {
    { "sub:Own", "A", nil, "", true },
    { "also:x", "A", nil, "" },
    { "sub:Here", "A", nil, "", true },
    { "a1", "A", nil, "a one" },
    { "a2", "A", nil, "a two" },
    { "sub:Kids", "A", "a2", "", true },
    { "k1", "A", "a2", "kid one" },
    { "sub:Last", "A", nil, "", true },
    { "a3", "A", nil, "a three" },
    { "x", "B", nil, "x window" },
    { "b1", "B", nil, "b one" },
    { "gone", "B", nil, "gone window" },
}
local built = { rows = {}, kids = {}, parentOf = {}, heads = { A = { head = "A" }, B = { head = "B" } } }
for _, s in ipairs(SPEC) do
    local row = { key = s[1], page = s[2], parent = s[3], keyLow = s[4], tipLow = "", sub = s[5] or nil }
    function row.Hide() end
    if s[1] == "gone" then row.hideIf = function() return true end end
    built.rows[#built.rows + 1] = row
    built.parentOf[s[1]] = s[3]
    if s[3] then
        built.kids[s[3]] = built.kids[s[3]] or {}
        table.insert(built.kids[s[3]], row)
    end
end

local function Keys(block)
    local out = {}
    for _, row in ipairs(block) do out[#out + 1] = row.key end
    return table.concat(out, " ")
end

local blocks = Blocks(built, "", "A")
Check(#blocks == 4, "page A: four blocks, got " .. #blocks)
Check(blocks[1] and Keys(blocks[1]) == "sub:Own also:x", "a heading keeps the row after it: " .. tostring(blocks[1] and Keys(blocks[1])))
Check(blocks[2] and Keys(blocks[2]) == "sub:Here a1 a2", "rows after a heading join it: " .. tostring(blocks[2] and Keys(blocks[2])))
Check(blocks[3] and Keys(blocks[3]) == "sub:Kids k1", "a heading among a row's kids starts its own block")
Check(blocks[4] and Keys(blocks[4]) == "sub:Last a3", "the next heading starts a new block")

blocks = Blocks(built, "", "B")
Check(#blocks == 2, "a page without headings: one block per top-level row, a left-out row none, got " .. #blocks)

blocks = Blocks(built, "x", "A")
local shown = {}
for _, block in ipairs(blocks) do
    for _, row in ipairs(block) do shown[row.key] = true end
end
Check(shown.x and not shown["also:x"], "a search shows the window's own row, not its All windows copy")
Check(not shown["sub:Own"], "a search shows no headings")

-- A page's own search: that page's matches only, laid as the page lays them.
blocks = Blocks(built, "one", "A", true)
shown = {}
for _, block in ipairs(blocks) do
    for _, row in ipairs(block) do shown[row.key] = true end
    Check(not block.head, "a page's own search puts no page titles over its rows")
end
Check(shown.a1 and not shown.b1, "a page's own search shows that page's rows only")

if failed > 0 then
    print("options blocks: " .. failed .. " failures")
    os.exit(1)
end
print("options blocks: ok")
