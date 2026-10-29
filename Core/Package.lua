local _, ns = ...

-- A standalone package (ClassicUI Forever: Standalone <Name>): its build's first file sets ns.PACKAGE (pages, roots,
-- modules) and holds the guard. Here the package keeps its own options rows, edit mode boxes and modules; every other
-- setting reads off, whatever a profile or old save says. The full addon has no ns.PACKAGE and none of this runs.

-- Inert ("full": the full addon is enabled; "other": another standalone is): every other file of ours returned at its
-- first line. All that is left is a line at login saying why.
if ns.INERT then
    local notice = CreateFrame("Frame")
    notice:RegisterEvent("PLAYER_LOGIN")
    notice:SetScript("OnEvent", function()
        local text = ns.INERT == "full" and ns.L["PKG_OFF_FULL"] or ns.L["PKG_OFF_OTHER"]
        DEFAULT_CHAT_FRAME:AddMessage(string.format(text, ns.PACKAGE.title))
    end)
    return
end

-- Our edit mode's boxes by the settings that own them; the minimap's pieces go with the minimap.
local BOX_OWNERS = { character = { "characterSheet" }, professions = { "professionsBook", "tradeSkill" },
    talents = { "talents" }, legacy = { "legacyWindow" }, collections = { "collectionsWindow" }, questLog = { "questLog" },
    map = { "worldMap" }, spellBook = { "spellBook" }, questWatch = { "questWatch" }, gryphonLeft = { "classicBar" },
    gryphonRight = { "classicBar" }, social = { "panelSocial" }, groupFinder = { "groupFinder" },
    questGiver = { "panelQuest" }, gossip = { "panelGossip" }, minimapOptionsButton = { "minimapButton" } }

local function Set(list)
    local set = {}
    for _, key in ipairs(list or ns.EMPTY) do set[key] = true end
    return set
end

-- A row's page: its own group, else the row above's, as the options window lays them.
local function PageOf()
    local page, pageOf = nil, {}
    for _, entry in ipairs(ns.TOGGLES) do
        page = entry.group or page
        pageOf[entry[1]] = page
    end
    return pageOf
end

-- The rows on the package's pages and its roots, then every row under a kept one and every row of a kept radio group.
local function KeptRows(pkg, pageOf)
    local pages, kept = {}, Set(pkg.roots)
    for _, id in ipairs(pkg.pages or ns.EMPTY) do pages[ns.L[id]] = true end
    for _, entry in ipairs(ns.TOGGLES) do
        if pages[pageOf[entry[1]]] then kept[entry[1]] = true end
    end
    local grew = true
    while grew do
        grew = false
        local radios = {}
        for _, entry in ipairs(ns.TOGGLES) do
            if kept[entry[1]] and entry.radio then radios[entry.radio] = true end
        end
        for _, entry in ipairs(ns.TOGGLES) do
            local key = entry[1]
            if not kept[key] and ((entry.parent and kept[entry.parent]) or (entry.radio and radios[entry.radio])) then
                kept[key], grew = true, true
            end
        end
    end
    return kept
end

-- The options list down to the kept rows; each page's first kept row carries its title, and the All windows list rides
-- it with only the kept windows.
local function TrimRows(kept, pageOf)
    local windows
    for _, entry in ipairs(ns.TOGGLES) do windows = windows or entry.windows end
    local rows, last = {}, nil
    for _, entry in ipairs(ns.TOGGLES) do
        if kept[entry[1]] then
            local page = pageOf[entry[1]]
            entry.group = page ~= last and page or nil
            entry.windows = nil
            if entry.group and entry.group == ns.L["GROUP_ALL_WINDOWS"] and windows then
                local own = {}
                for _, key in ipairs(windows) do
                    if kept[key] then own[#own + 1] = key end
                end
                entry.windows = own
            end
            rows[#rows + 1] = entry
            last = page
        end
    end
    wipe(ns.TOGGLES)
    for i, entry in ipairs(rows) do ns.TOGGLES[i] = entry end
end

local function OwnsBox(entry, kept)
    local owners = BOX_OWNERS[entry.key]
    if not owners and entry.section == ns.L["UI_MINIMAP"] then owners = { "minimap" } end
    for _, key in ipairs(owners or ns.EMPTY) do
        if kept[key] then return true end
    end
    return false
end

-- Whether a module may run in this package: its own rows, its modules with no row, and the options.
function ns.PackageRuns(key)
    local pkg = ns.PACKAGE
    if not pkg then return true end
    return key == "options" or (pkg.kept and pkg.kept[key]) == true or pkg.modules[key] == true
end

-- Every setting outside the package off, on the db or a profile being filled.
function ns.PackageMask(db)
    local pkg = ns.PACKAGE
    if not (pkg and pkg.off) then return end
    for key in pairs(pkg.off) do db[key] = false end
end

-- ADDON_LOADED, before the profile loads: the package's rows, boxes and settings.
function ns.ApplyPackage()
    local pkg = ns.PACKAGE
    if not pkg then return end
    pkg.modules = Set(pkg.modules)
    local pageOf = PageOf()
    local kept = KeptRows(pkg, pageOf)
    pkg.kept, pkg.off = kept, {}
    for _, entry in ipairs(ns.TOGGLES) do
        if not kept[entry[1]] then pkg.off[entry[1]] = true end
    end
    TrimRows(kept, pageOf)
    for i = #ns.WINDOW_LIST, 1, -1 do
        if not OwnsBox(ns.WINDOW_LIST[i], kept) then table.remove(ns.WINDOW_LIST, i) end
    end
    ns.PackageMask(ns.db)
end
