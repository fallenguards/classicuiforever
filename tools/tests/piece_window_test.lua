-- Offline test under Lua 5.4: a standalone piece's one-page settings (Options/PieceWindow.lua) for every package, over
-- the real options list, its package trim (Core/Package.lua) and the real row builder (Options/OptionsRows.lua). Every
-- setting shows once; a page with a heading has rows enough or is the piece's own; one section has no heading; the
-- minimap button sits in the foot unless the piece holds the whole Minimap page.
-- Run from the addon root: lua tools/tests/piece_window_test.lua (CI runs every tools/tests/*_test.lua).
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

-- Any frame or region: every method answers another stub; a field never set (parent, setting) reads nil.
local NUMBERS = { GetStringWidth = 60, GetStringHeight = 12, GetWidth = 100, GetHeight = 24 }
local Stub
local function Method(_, name)
    if name:match("^%l") then return nil end
    if NUMBERS[name] then return function() return NUMBERS[name] end end
    return function() return Stub() end
end
function Stub() return setmetatable({}, { __index = Method }) end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end

local function Specs()
    local cmd = 'cd "%s" && %s -c "import sys; sys.path.insert(0, \'tools\'); import standalone; '
        .. '[print(chr(9).join([p[\'id\'], \',\'.join(p[\'pages\']), \',\'.join(p[\'roots\']), \',\'.join(p[\'modules\'])])) '
        .. 'for p in standalone.PACKAGES]"'
    for _, py in ipairs({ "python3", "python" }) do
        local pipe = io.popen(string.format(cmd, ROOT, py) .. " 2>&1")
        local text = pipe and pipe:read("a")
        if pipe then pipe:close() end
        if text and text:find("Nameplates", 1, true) then
            local out = {}
            for line in text:gmatch("[^\r\n]+") do
                local id, pages, roots, modules = line:match("^(%w+)\t([^\t]*)\t([^\t]*)\t([^\t]*)$")
                local function List(s)
                    local list = {}
                    for item in s:gmatch("[%w_]+") do list[#list + 1] = item end
                    return list
                end
                if id then out[#out + 1] = { id = id, pages = List(pages), roots = List(roots), modules = List(modules) } end
            end
            return out
        end
    end
end

-- One package's ns: the options list trimmed to it, its rows built, the piece window's planner loaded.
local function Piece(spec)
    local L = setmetatable({}, { __index = function(_, key) return key end })
    local ns = setmetatable({ L = L, ART = { CHECK = "check" }, EMPTY = {}, db = {}, ENGLISH_CLIENT = true },
        { __index = function() return function() return Stub() end end })
    ns.OnForever = function() return false end
    ns.NewFrame = function() return Stub() end
    ns.PACKAGE = false
    GameTooltip, MenuUtil, SOUNDKIT = Stub(), Stub(), {}
    assert(loadfile(ROOT .. "/Options/Toggles.lua"))("ClassicUIForever", ns)
    ns.WINDOW_LIST = {}
    rawset(ns, "INERT", false)
    ns.PACKAGE = { title = "ClassicUI Forever: Standalone " .. spec.id, pages = spec.pages, roots = spec.roots,
        modules = spec.modules, piece = true }
    assert(loadfile(ROOT .. "/Core/Package.lua"))("ClassicUIForever", ns)
    ns.ApplyPackage()
    assert(loadfile(ROOT .. "/Options/OptionsRows.lua"))("ClassicUIForever", ns)
    ns.options.BoxConfirm = function() return function() end end
    assert(loadfile(ROOT .. "/Options/PieceWindow.lua"))("ClassicUIForever", ns)
    return ns, ns.options
end

local specs = Specs()
Check(specs and #specs > 0, "tools/standalone.py lists its packages")
for _, spec in ipairs(specs or {}) do
    local ns, O = Piece(spec)
    local built = O.BuildRows(Stub(), 272)
    local sections, foot = O.PiecePlan(built, ns.PACKAGE)
    local blocks = O.PieceBlocks(built, sections)
    local name = spec.id
    local seen, heads, lines = {}, 0, 0
    for _, block in ipairs(blocks) do
        for _, line in ipairs(block) do
            lines = lines + 1
            if line.head then
                heads = heads + 1
            else
                Check(not seen[line], name .. ": " .. tostring(line.key) .. " shows once")
                seen[line] = true
            end
        end
    end
    -- Every setting row (not a heading, not All windows' copy of a row shown elsewhere) is on the page or in the foot.
    for _, row in ipairs(built.rows) do
        if not row.sub and not row.setting and not (row.hideIf and row.hideIf()) then
            Check(seen[row] or row == foot, name .. ": " .. tostring(row.key) .. " is on the page")
        end
    end
    Check(not seen[foot or false], name .. ": the foot's row is not on the page too")
    Check(#sections > 1 and heads == #sections or #sections == 1 and heads == 0,
        name .. ": headings only with more than one section (" .. #sections .. " sections, " .. heads .. " headings)")
    local own = {}
    for _, id in ipairs(spec.pages) do own[id] = true end
    local minimapOwn = own.GROUP_MINIMAP
    Check(minimapOwn and foot == nil or not minimapOwn and foot ~= nil and foot.key == "minimapButton",
        name .. ": the minimap button in the foot unless the piece holds the Minimap page")
    local columns, tallest, scrolls = O.PieceShape(blocks)
    local titles = {}
    for _, section in ipairs(sections) do titles[#titles + 1] = section.title or "(one)" end
    print(string.format("  %-16s %d lines, %d column(s), %d tall%s: %s", name, lines, columns, tallest,
        scrolls and " (scrolls)" or "", table.concat(titles, ", ")))
end

-- The pieces the window was drawn for, by name.
local function Plan(id)
    for _, spec in ipairs(specs or {}) do
        if spec.id == id then
            local ns, O = Piece(spec)
            local built = O.BuildRows(Stub(), 272)
            local sections, foot = O.PiecePlan(built, ns.PACKAGE)
            return sections, foot, O.PieceBlocks(built, sections)
        end
    end
end
local sections, _, blocks = Plan("Nameplates")
Check(sections and #sections == 1, "Nameplates: one section, so no heading")
local last = blocks and blocks[#blocks]
Check(last and last[#last].key == "classicFonts", "Nameplates: Classic fonts joins the end of the plates' rows")
sections = Plan("ActionBars")
Check(sections and #sections == 2 and sections[1].title == "GROUP_ACTION_BARS" and sections[2].title == "GROUP_BAGS",
    "Action Bars: the bars' section, then the bags'")

if failed > 0 then
    print(failed .. " piece window check(s) failed")
    os.exit(1)
end
print("piece window: all checks passed")
