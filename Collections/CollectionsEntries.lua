local _, ns = ...

-- Collection entries other addons ask for by kind and ID (Core/API.lua). A page's Want: the ID as its entries know it,
-- and the picker category holding it (a source's look); EntryKey: the key an entry answers to (a pet's species).

local CW = ns.collections
local W = CW.State()
local KIND_PAGES = { mount = "mounts", pet = "pets", toy = "toys", heirloom = "heirlooms", appearance = "appearances",
    campsite = "campsites" }

local function PageFor(key)
    for _, page in pairs(CW.pages) do
        if page.key == key then return page end
    end
end

local function Is(page, entry, key)
    if page.EntryKey then return page.EntryKey(entry) == key end
    return entry.id == key
end

function ns.CollectionsTabOf(key)
    local page = PageFor(key)
    return page and W.tabs[page.tab]
end

-- The window on the entry's page, turned to it and the entry picked; false while it is not listed (filtered, searched).
function ns.ShowCollectionEntry(kind, id)
    local page = PageFor(KIND_PAGES[kind])
    if not (page and ns.ShowCollections(page.key)) then return false end
    local key, category = id, nil
    if page.Want then key, category = page.Want(id) end
    if key == nil or (category ~= nil and not page.Picker.Set(category)) then return false end
    if page.Picker then W.pickerText:SetText(page.Picker.Label(page.Picker.Get())) end
    CW.Refresh()
    for i, entry in ipairs(W.shown) do
        if Is(page, entry, key) then
            CW.TurnTo(i)
            return true
        end
    end
    return false
end

-- The cell drawing that entry on the page shown now, else nil.
function ns.CollectionEntryCell(kind, id)
    local page = PageFor(KIND_PAGES[kind])
    if not (page and page == W.current and W.frame and W.frame:IsShown()) then return nil end
    local key = id
    if page.Want then key = page.Want(id) end
    for _, cell in ipairs(page.book and W.book or W.cells) do
        if cell:IsShown() and cell.entry and Is(page, cell.entry, key) then return cell end
    end
end
