-- Offline test under Lua 5.4 for the game's loot history window (/loot, Windows/LootHistory.lua): dressed as every game
-- window, and sized both ways from its corner. It kept the game's look under every theme and sized its height alone
-- (a CurseForge comment, 2026-11-21).
-- Run from the addon root: lua tools/tests/loot_history_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 121

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local failed = 0
local function Check(ok, what)
    if not ok then
        failed = failed + 1
        print("FAIL: " .. what)
    end
end

local function Read(path) return assert(io.open(ROOT .. "/" .. path)):read("a") end

-- Wired in: a row in the window list, loaded before that list reads its afters.
local panels = Read("Windows/Panels.lua")
Check(panels:find('{ "GroupLootHistoryFrame", key = "panelLootHistory", portrait = false, lift = 5, '
    .. 'after = A.GroupLootHistoryFrame }', 1, true) ~= nil, "the window list dresses GroupLootHistoryFrame")
local toc = Read("ClassicUIForever.toc")
local mine, list = toc:find("Windows\\LootHistory.lua", 1, true), toc:find("Windows\\Panels.lua", 1, true)
Check(mine ~= nil and list ~= nil and mine < list, "the toc loads Windows/LootHistory.lua before Windows/Panels.lua")
Check(Read("Core/Defaults.lua"):find("panelLootHistory = true", 1, true) ~= nil, "the window is dressed by default")

-- A frame recording what is done to it.
local function Frame(fields)
    local f = fields or {}
    f.points, f.scripts, f.alpha, f.mouse = {}, {}, 1, true
    function f:ClearAllPoints() self.points = {} end
    function f:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function f:SetAlpha(a) self.alpha = a end
    function f:EnableMouse(on) self.mouse = on end
    function f:SetScript(name, fn) self.scripts[name] = fn end
    function f:SetFrameLevel(level) self.level = level end
    function f:SetSize(w, h) self.w, self.h = w, h end
    function f:GetSize() return self.w, self.h end
    return f
end

local db = { lootHistoryW = 0, lootHistoryH = 0 }
local skinned, acquired, acquiredOwner, tips = {}, nil, nil, 0
local grip
local ns = {
    db = db, L = setmetatable({}, { __index = function(_, k) return k end }),
    panels = { after = {} },
    Once = (function()
        local seen = {}
        return function(frame, key)
            seen[frame] = seen[frame] or {}
            if seen[frame][key] then return false end
            seen[frame][key] = true
            return true
        end
    end)(),
    SetTwoPointsIf = function(region, ...)
        local a = { ... }
        region.points = { { a[1], a[2], a[3], a[4], a[5] }, { a[6], a[7], a[8], a[9], a[10] } }
    end,
    GripButton = function(parent)
        grip = Frame({ parent = parent })
        return grip
    end,
    AttachTip = function() tips = tips + 1 end,
    SkinCloseButton = function(button) skinned[#skinned + 1] = button end,
    SkinDropdown = function(dropdown) skinned[#skinned + 1] = dropdown end,
}
ScrollBoxListMixin = { Event = { OnAcquiredFrame = "OnAcquiredFrame" } }
assert(loadfile(ROOT .. "/Windows/LootHistory.lua"))("ClassicUIForever", ns)

local after = ns.panels.after.GroupLootHistoryFrame
Check(type(after) == "function", "the loot history window has its after")
if type(after) ~= "function" then
    print(failed .. " check(s) failed")
    os.exit(1)
end

local function Row()
    local row = Frame()
    row.Item, row.ItemName = Frame(), Frame()
    return row
end
local shownRow, header = Row(), Frame()
local box = Frame({ rows = { shownRow, header } })
function box:ForEachFrame(fn) for _, row in ipairs(self.rows) do fn(row) end end
function box.RegisterCallback(_, event, fn, owner)
    if event == "OnAcquiredFrame" then acquired, acquiredOwner = fn, owner end
end
local close, dropdown, handle, bg = Frame(), Frame(), Frame(), Frame()
local frame = Frame({ ScrollBox = box, ClosePanelButton = close, EncounterDropdown = dropdown, ResizeButton = handle,
    Bg = bg, panelMaxHeight = 590, w = 261, h = 590 })
function frame:SetResizeBounds(...) self.bounds = { ... } end
function frame:StartSizing(point, fromMouse) self.sizing = { point, fromMouse } end
function frame:StopMovingOrSizing() self.sizing = nil end

-- A size the player left last time comes back.
db.lootHistoryW, db.lootHistoryH = 420, 700
after(frame)

-- The theme: the flat backing fades under our stone; the X and the encounter pick are ours.
Check(bg.alpha == 0, "the flat panel's own backing fades under our stone")
Check(skinned[1] == close and skinned[2] == dropdown, "the X and the encounter pick are dressed")

-- Both ways: wider than the game's 261, never narrower.
local b = frame.bounds or {}
Check(b[1] == 261 and b[2] == 300 and (b[3] or 0) > 261 and (b[4] or 0) > 590, "the window sizes both ways, from the game's least")
local p1, p2 = box.points[1] or {}, box.points[2] or {}
Check(p1[1] == "TOPLEFT" and p1[2] == frame and p1[4] == 6 and p1[5] == -90, "the list keeps the game's top left")
Check(p2[1] == "BOTTOMRIGHT" and p2[2] == frame and p2[3] == "BOTTOMRIGHT" and p2[4] == -23 and p2[5] == 4,
    "the list runs to the window's right edge, as far in as the game's")
Check(frame.w == 420 and frame.h == 700, "the size kept from last time comes back")

-- Rows: a drop's name runs to its row's right end; the passed header has none and is left alone.
local n = shownRow.ItemName.points
Check(n[2] and n[2][1] == "TOPRIGHT" and n[2][2] == shownRow and n[2][4] == -8, "a shown drop's name runs to its row's end")
Check(#header.points == 0, "a header row is left alone")
Check(type(acquired) == "function", "rows the list makes later are widened too")
Check(acquiredOwner ~= nil and acquiredOwner ~= frame and acquiredOwner ~= box,
    "the row hook has an owner of its own (one callback per owner: the game's would be replaced)")
local later = Row()
if acquired then acquired(nil, later) end
Check(later.ItemName.points[2] ~= nil, "a later row's name runs to its end")

-- The corner grip sizes from the bottom right; the game's height-only handle is out of sight and reach.
Check(handle.alpha == 0 and handle.mouse == false, "the game's bottom handle is hidden and unclickable")
Check(grip ~= nil and grip.parent == frame and tips == 1, "our corner grip is on the window with its tip")
if grip then
    local gp = grip.points[1] or {}
    Check(gp[1] == "BOTTOMRIGHT" and gp[2] == frame, "the grip sits in the bottom right corner")
    Check((grip.level or 0) > 600, "the grip is over the rows and the game's handle")
    grip.scripts.OnMouseDown(grip, "LeftButton")
    Check(frame.sizing and frame.sizing[1] == "BOTTOMRIGHT", "a drag sizes from the bottom right")
    frame.w, frame.h = 500, 640
    grip.scripts.OnMouseUp(grip, "LeftButton")
    Check(frame.sizing == nil and db.lootHistoryW == 500 and db.lootHistoryH == 640, "the dragged size is kept")
    grip.scripts.OnClick(grip, "RightButton")
    Check(frame.w == 261 and frame.h == 590 and db.lootHistoryW == 0 and db.lootHistoryH == 0,
        "a right click gives the game's size back")
end

-- A second dress (a theme change) adds no second grip or hook.
local first = grip
after(frame)
Check(grip == first and tips == 1, "dressed again: one grip, one hook")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("loot_history_test: ok")
