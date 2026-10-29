-- Offline test under Lua 5.4 for the standalone packages (Core/Package.lua, tools/standalone.py): a package keeps its
-- pages' rows, its roots and every row under them, each page titled once; every other setting reads off, also after a
-- profile fill; its edit mode boxes are its own; every edit mode box has an owner; every package names real pages,
-- rows and modules. Run from the addon root: lua tools/tests/standalone_test.lua.
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

function wipe(t) for k in pairs(t) do t[k] = nil end return t end

local L = setmetatable({}, { __index = function(_, key) return key end })

-- A package from a page and a root, over rows across three pages.
local function Fixture()
    local ns = { L = L, EMPTY = {}, db = {} }
    ns.TOGGLES = {
        { "gameMenu", group = "GROUP_ALL_WINDOWS", windows = { "bags", "panelSocial", "gameMenu" } },
        { "panelSocial" },
        { "bronzeTheme", group = "GROUP_LOOK" },
        { "themeDark", parent = "bronzeTheme", radio = "theme" },
        { "themeBronze", radio = "theme" },
        { "classicFonts" },
        { "bags", group = "GROUP_BAGS" },
        { "oneBag", parent = "bags" },
        { "unitFrames", group = "GROUP_UNIT_FRAMES" },
        { "castBars", parent = "unitFrames" },
    }
    ns.WINDOW_LIST = { { key = "character" }, { key = "social" }, { key = "minimapMail", section = "UI_MINIMAP" },
        { key = "gryphonLeft" } }
    ns.PACKAGE = { title = "ClassicUI Forever: Bags", pages = { "GROUP_BAGS" }, roots = { "bronzeTheme", "panelSocial" },
        modules = { "panels" } }
    assert(loadfile(ROOT .. "/Core/Package.lua"))("ClassicUIForever", ns)
    return ns
end

local ns = Fixture()
ns.ApplyPackage()
local keys, groups = {}, {}
for _, entry in ipairs(ns.TOGGLES) do
    keys[#keys + 1] = entry[1]
    if entry.group then groups[#groups + 1] = entry.group end
end
Check(table.concat(keys, " ") == "panelSocial bronzeTheme themeDark themeBronze bags oneBag",
    "kept rows: page, roots, a child, a radio sibling: " .. table.concat(keys, " "))
Check(table.concat(groups, " ") == "GROUP_ALL_WINDOWS GROUP_LOOK GROUP_BAGS", "each page titled once: " .. table.concat(groups, " "))
local master = ns.TOGGLES[1].windows
Check(master and #master == 2 and master[1] == "bags" and master[2] == "panelSocial", "All windows lists kept windows only")
Check(ns.db.classicFonts == false and ns.db.unitFrames == false and ns.db.castBars == false and ns.db.gameMenu == false,
    "settings outside the package off")
Check(ns.db.bags == nil and ns.db.oneBag == nil, "the package's own settings untouched")
local profile = { unitFrames = true, bags = true }
ns.PackageMask(profile)
Check(profile.unitFrames == false and profile.bags == true, "a profile fill masked too")
Check(ns.PackageRuns("bags") and ns.PackageRuns("panels") and ns.PackageRuns("options"), "own modules run")
Check(not ns.PackageRuns("unitFrames") and not ns.PackageRuns("tooltips"), "other modules stay off")
local boxes = {}
for _, entry in ipairs(ns.WINDOW_LIST) do boxes[#boxes + 1] = entry.key end
Check(table.concat(boxes, " ") == "social", "edit mode boxes owned by kept settings: " .. table.concat(boxes, " "))

-- The full addon: no package, nothing trimmed or masked.
local full = { L = L, EMPTY = {}, db = {}, TOGGLES = { { "bags", group = "GROUP_BAGS" } }, WINDOW_LIST = { { key = "x" } } }
assert(loadfile(ROOT .. "/Core/Package.lua"))("ClassicUIForever", full)
full.ApplyPackage()
Check(#full.TOGGLES == 1 and #full.WINDOW_LIST == 1 and next(full.db) == nil, "the full addon is untouched")
Check(full.PackageRuns("anything"), "the full addon runs every module")

-- Every edit mode box has an owner: in BOX_OWNERS, or a minimap piece.
local owners = Read("Core/Package.lua"):match("local BOX_OWNERS = (%b{})")
local list = Read("UI/WindowList.lua")
for block in list:gmatch("{ key = (.-)\n    [{}%-]") do
    local key = block:match('^"(%w+)"')
    if key and not block:find('section = L%["UI_MINIMAP"%]') then
        Check(owners:find("[%s{]" .. key .. " = ") ~= nil, "edit mode box " .. key .. " has an owner in BOX_OWNERS")
    end
end

-- Every package names real options pages, options rows and modules.
local rows, modules, pages = {}, {}, {}
for key in Read("Options/Toggles.lua"):gmatch('{ "(%w+)", L%[') do rows[key] = true end
for _, path in ipairs({ "ClassicUIForever.toc" }) do
    for file in Read(path):gmatch("([%w\\/_]+%.lua)") do
        local ok, text = pcall(Read, (file:gsub("\\", "/")))
        if ok then
            for name in text:gmatch('ns%.RegisterModule%("(%w+)"') do modules[name] = true end
        end
    end
end
for key in Read("Locales/enUS.lua"):gmatch('L%["(GROUP_[%u_]+)"%]') do pages[key] = true end
local packages = Read("tools/standalone.py"):match("PACKAGES = (%b[])")
Check(packages ~= nil, "tools/standalone.py lists its packages")
for spec in (packages or ""):gmatch("dict(%b())") do
    local id = spec:match('id="(%w+)"')
    local fields = { pages = spec:match("pages=(%b[])") or "", modules = spec:match("modules=(%b[])") or "",
        roots = (spec:match("roots=(.-),%s*modules=") or ""):gsub("THEME", '"bronzeTheme"') }
    for list_name, known in pairs({ pages = pages, roots = rows, modules = modules }) do
        for item in fields[list_name]:gmatch('"(%w+)"') do
            Check(known[item], id .. ": " .. list_name .. " " .. item .. " exists")
        end
    end
end

-- The guard the build writes: a package goes inert with the full addon or another standalone enabled.
-- The file as the tool writes it (python on the path, as CI has).
local function Generated()
    local cmd = 'cd "%s" && %s -c "import sys; sys.path.insert(0, \'tools\'); import standalone; '
        .. 'sys.stdout.write(standalone.package_lua(standalone.PACKAGES[1]))"'
    for _, py in ipairs({ "python3", "python" }) do
        local pipe = io.popen(string.format(cmd, ROOT, py) .. " 2>&1")
        local text = pipe and pipe:read("a")
        if pipe then pipe:close() end
        if text and text:find("ns.PACKAGE", 1, true) then return text end
    end
end
local src = Generated()
Check(src ~= nil, "tools/standalone.py writes a package's first file")

-- The addon list shows each package's title as it is, Standalone said once.
local function Titles()
    local cmd = 'cd "%s" && %s -c "import sys; sys.path.insert(0, \'tools\'); import standalone; '
        .. '[print(standalone.toc_text(\'## Title: x\', p, p[\'folder\']).splitlines()[0] + chr(9) + p[\'title\']) '
        .. 'for p in standalone.PACKAGES]"'
    for _, py in ipairs({ "python3", "python" }) do
        local pipe = io.popen(string.format(cmd, ROOT, py) .. " 2>&1")
        local text = pipe and pipe:read("a")
        if pipe then pipe:close() end
        if text and text:find("## Title", 1, true) then return text end
    end
end
-- Every addon list picture (tools/standalone_icons/<Id>.png) is named after a package.
local function StrayIcons()
    local cmd = 'cd "%s" && %s -c "import os, sys; sys.path.insert(0, \'tools\'); import standalone; '
        .. 'ids = {p[\'id\'] for p in standalone.PACKAGES}; '
        .. 'print(\'icons:\', *[f for f in os.listdir(standalone.ICONS) if f[:-4] not in ids or not f.endswith(\'.png\')])"'
    for _, py in ipairs({ "python3", "python" }) do
        local pipe = io.popen(string.format(cmd, ROOT, py) .. " 2>&1")
        local text = pipe and pipe:read("a")
        if pipe then pipe:close() end
        if text and text:find("icons:", 1, true) then return text:match("icons:(.-)%s*$") end
    end
end
local stray = StrayIcons()
Check(stray == "", "standalone_icons holds only <Id>.png pictures of packages; stray: " .. tostring(stray))

local titles = Titles() or ""
Check(titles ~= "", "tools/standalone.py writes a package's toc title")
for line, title in titles:gmatch("## Title: ([^\t\n]+)\t([^\n]+)") do
    Check(line == title:gsub("\r$", ""), "toc title " .. line .. " is the package's own")
end

local function Guard(enabled)
    if not src then return "no file" end
    local names = { "ClassicUIForever", "ClassicUIForeverStandaloneBags", "ClassicUIForeverStandaloneChat" }
    C_AddOns = {
        GetAddOnEnableState = function(which) return enabled[type(which) == "number" and names[which] or which] and 2 or 0 end,
        GetNumAddOns = function() return #names end,
        GetAddOnInfo = function(i) return names[i] end,
    }
    local gns = {}
    local chunk = assert(load(src, "Package.lua"))
    chunk("ClassicUIForeverStandaloneBags", gns)
    return gns.INERT
end
Check(Guard({ ClassicUIForeverStandaloneBags = true }) == nil, "alone, the package runs")
Check(Guard({ ClassicUIForever = true, ClassicUIForeverStandaloneBags = true }) == "full", "the full addon enabled: inert")
Check(Guard({ ClassicUIForeverStandaloneBags = true, ClassicUIForeverStandaloneChat = true }) == "other",
    "another standalone enabled: inert")

-- Every released piece is a pick in the issue forms' Which addon?, and its Support page link picks it; the full addon's
-- link picks the first option.
local function Released()
    local cmd = 'cd "%s" && %s -c "import sys; sys.path.insert(0, \'tools\'); import standalone; '
        .. '[print(p[\'title\'] + chr(9) + p[\'issues\']) for p in standalone.PACKAGES '
        .. 'if p[\'wave\'] == 1 and p[\'folder\'].startswith(standalone.PREFIX)]"'
    for _, py in ipairs({ "python3", "python" }) do
        local pipe = io.popen(string.format(cmd, ROOT, py) .. " 2>&1")
        local text = pipe and pipe:read("a")
        if pipe then pipe:close() end
        if text and text:find("Standalone", 1, true) then return text end
    end
end
local function Decode(s) return (s:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)) end
local released = Released() or ""
Check(released ~= "", "tools/standalone.py lists the released pieces")
for _, form in ipairs({ ".github/ISSUE_TEMPLATE/bug_report.yml", ".github/ISSUE_TEMPLATE/feature_request.yml" }) do
    local text = Read(form)
    local options = text:match("id: addon.-options:\n(.-)\n%s+default:") or ""
    local first = options:match('%- "([^"]+)"')
    Check(first == "ClassicUI Forever (full addon)", form .. ": the full addon first")
    local welcome = Read("Options/Welcome.lua"):match("issues/new/choose%?addon=([^\"]+)\"")
    Check(welcome and Decode(welcome) == first, "the full addon's link picks the first option")
    for title, url in released:gmatch("([^\t\n]+)\t([^\n]+)") do
        Check(options:find('- "' .. title .. '"', 1, true) ~= nil, form .. " lists " .. title)
        Check(Decode(url:match("addon=(.+)$") or "") == title, title .. ": its link picks it")
    end
end

if failed > 0 then
    print(failed .. " standalone check(s) failed")
    os.exit(1)
end
print("standalone: all checks passed")
