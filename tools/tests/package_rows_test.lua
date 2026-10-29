-- Offline test under Lua 5.4: the standalone packages over the real options list (Options/Toggles.lua), the real
-- package specs (tools/standalone.py) and Core/Package.lua, on both clients. No package keeps a row needing a setting
-- it lacks; the classic bar's rows on other pages go with Action Bars; the look modules go with every package that
-- shows their work; chat notes keep their default; every module runs in some package or is listed as unplaced.
-- Run from the addon root: lua tools/tests/package_rows_test.lua (CI runs every tools/tests/*_test.lua).
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

-- Global looks: the module, and the packages whose pieces show its work.
local LOOKS = {
    classicFonts = { "ActionBars", "UnitFrames", "Nameplates" },   -- key labels and counts, pet bar numbers, plate names
    eraCoins = { "Bags", "Quests", "Maps" },                       -- bag money, quest rewards, the map's quest list
}
-- Modules no package carries yet: the next wave places them.
local UNPLACED = { hideHelpButtons = true, hideZoneText = true, lootToast = true, zoneTerritory = true }

-- Any frame or region: every method answers another stub.
local NUMBERS = { GetStringWidth = 60, GetStringHeight = 12, GetWidth = 100, GetHeight = 24 }
local Stub
local function Method(_, name)
    if NUMBERS[name] then return function() return NUMBERS[name] end end
    return function() return Stub() end
end
function Stub() return setmetatable({}, { __index = Method }) end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end

-- The specs as the build tool resolves them (python on the path, as CI has).
local function Specs()
    local cmd = 'cd "%s" && %s -c "import sys; sys.path.insert(0, \'tools\'); import standalone; '
        .. '[print(chr(9).join([p[\'id\'], \',\'.join(p[\'pages\']), \',\'.join(p[\'roots\']), \',\'.join(p[\'modules\']), '
        .. 'str(p[\'forever\'])])) for p in standalone.PACKAGES]"'
    for _, py in ipairs({ "python3", "python" }) do
        local pipe = io.popen(string.format(cmd, ROOT, py) .. " 2>&1")
        local text = pipe and pipe:read("a")
        if pipe then pipe:close() end
        if text and text:find("ActionBars", 1, true) then
            local out = {}
            for line in text:gmatch("[^\r\n]+") do
                local id, pages, roots, modules, forever = line:match("^(%w+)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t(%w+)$")
                local function List(s)
                    local list = {}
                    for item in s:gmatch("[%w_]+") do list[#list + 1] = item end
                    return list
                end
                if id then
                    out[#out + 1] = { id = id, pages = List(pages), roots = List(roots), modules = List(modules),
                        forever = forever == "True" }
                end
            end
            return out
        end
    end
end

local modules = {}
for file in Read("ClassicUIForever.toc"):gmatch("([%w\\/_]+%.lua)") do
    local ok, text = pcall(Read, (file:gsub("\\", "/")))
    if ok then
        for name in text:gmatch('ns%.RegisterModule%("(%w+)"') do modules[#modules + 1] = name end
    end
end

local function Fresh(forever)
    local L = setmetatable({}, { __index = function(_, key) return key end })
    local ns = setmetatable({ L = L, ART = { CHECK = "check" }, EMPTY = {}, db = {}, ENGLISH_CLIENT = true },
        { __index = function() return function() return Stub() end end })
    ns.OnForever = function() return forever end
    ns.NewFrame = function() return Stub() end
    ns.PACKAGE = false
    GameTooltip, MenuUtil, SOUNDKIT = Stub(), Stub(), {}
    assert(loadfile(ROOT .. "/Options/Toggles.lua"))("ClassicUIForever", ns)
    return ns
end

local specs = Specs()
Check(specs and #specs > 0, "tools/standalone.py lists its packages")
for _, forever in ipairs({ true, false }) do
    local client = forever and "forever" or "retail"
    local base = Fresh(forever)
    local barRows = {}
    for _, entry in ipairs(base.TOGGLES) do
        if entry.needs == "classicBar" then barRows[#barRows + 1] = entry[1] end
    end
    local ran = {}
    for _, spec in ipairs(specs or {}) do
        if forever or not spec.forever then
            local ns = Fresh(forever)
            local parent, needs = {}, {}
            for _, entry in ipairs(ns.TOGGLES) do parent[entry[1]], needs[entry[1]] = entry.parent, entry.needs end
            ns.WINDOW_LIST = {}
            rawset(ns, "INERT", false)
            ns.PACKAGE = { title = spec.id, pages = spec.pages, roots = spec.roots, modules = spec.modules }
            assert(loadfile(ROOT .. "/Core/Package.lua"))("ClassicUIForever", ns)
            ns.ApplyPackage()
            local kept, name = ns.PACKAGE.kept, client .. " " .. spec.id
            for _, entry in ipairs(ns.TOGGLES) do
                Check(not entry.needs or kept[entry.needs], name .. ": keeps " .. entry[1] .. " without " .. tostring(entry.needs))
            end
            if spec.id == "ActionBars" then
                for _, key in ipairs(barRows) do Check(kept[key], name .. ": the classic bar's row " .. key .. " goes with the bars") end
            end
            for look, owners in pairs(LOOKS) do
                for _, owner in ipairs(owners) do
                    if owner == spec.id then Check(kept[look], name .. ": keeps " .. look) end
                end
            end
            Check(ns.db.addonMessages == nil and ns.db.barsTakenNote == nil, name .. ": chat notes keep their default")
            local function Can(key, depth)
                if depth > 20 or not ns.PackageRuns(key) then return false end
                if needs[key] and needs[key] ~= key and not Can(needs[key], depth + 1) then return false end
                if parent[key] and parent[key] ~= key then return Can(parent[key], depth + 1) end
                return true
            end
            for _, module in ipairs(modules) do
                if Can(module, 0) then ran[module] = true end
            end
        end
    end
    for _, module in ipairs(modules) do
        local foreverOnly = module == "legacyWindow" and not forever
        Check(ran[module] or UNPLACED[module] or foreverOnly, client .. ": module " .. module .. " runs in no package")
    end
end

if failed > 0 then
    print(failed .. " package rows check(s) failed")
    os.exit(1)
end
print("package rows: all checks passed")
