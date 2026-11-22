-- Offline test under Lua 5.4 for Era's Loot Rolls window in place of the game's /loot window (Windows/LootHistory.lua).
-- The game's window kept Forever's insides under our frame: an encounter pick, a roll timer and 48 px icons in 58 px
-- cards, not Era's (2026-11-21). Era's (Classic LootHistory.xml): a 210 x 175 tooltip box, 36 px rows with 28 px icons,
-- winner, roll type and roll on a done row, + to list the rolls (players who rolled, or everyone while it runs).
-- Run from the addon root: lua tools/tests/loot_history_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 122 212 431

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
Check(Read("Windows/Panels.lua"):find('{ "GroupLootHistoryFrame", key = "panelLootHistory", replaced = true, '
    .. 'after = A.GroupLootHistoryFrame }', 1, true) ~= nil, "the window list has ours stand in for GroupLootHistoryFrame")
local toc = Read("ClassicUIForever.toc")
local mine, list = toc:find("Windows\\LootHistory.lua", 1, true), toc:find("Windows\\Panels.lua", 1, true)
Check(mine and list and mine < list, "the toc loads Windows/LootHistory.lua before Windows/Panels.lua")

-- Frames and regions that remember what is done to them.
local function Region(kind)
    local r = { kind = kind, shown = true, points = {}, scripts = {} }
    -- As the game's: OnShow and OnHide run when it comes into view or leaves it, under a hidden parent never.
    function r.IsVisible(self) return self.shown and (self.parent == nil or self.parent:IsVisible()) end
    local function Change(self, fn)
        local was = self:IsVisible()
        fn()
        local now = self:IsVisible()
        if now ~= was and self.scripts[now and "OnShow" or "OnHide"] then self.scripts[now and "OnShow" or "OnHide"](self) end
    end
    function r.Show(self) Change(self, function() self.shown = true end) end
    function r.Hide(self) Change(self, function() self.shown = false end) end
    function r.SetParent(self, parent) Change(self, function() self.parent = parent end) end
    function r.GetParent(self) return self.parent end
    function r.SetFrameStrata(self, strata) self.strata = strata end
    function r.GetFrameStrata(self) return self.strata end
    function r.SetShown(self, on) if on then self:Show() else self:Hide() end end
    function r.IsShown(self) return self.shown end
    function r.ClearAllPoints(self) self.points = {} end
    function r.SetPoint(self, ...) self.points[#self.points + 1] = { ... } end
    function r.SetSize(self, w, h) self.w, self.h = w, h end
    function r.GetSize(self) return self.w, self.h end
    function r.SetWidth(self, w) self.w = w end
    function r.SetHeight(self, h) self.h = h end
    function r.GetWidth(self) return self.w or 0 end
    function r.GetHeight(self) return self.h or 0 end
    function r.SetText(self, t) self.text = t end
    function r.GetText(self) return self.text end
    function r.SetVertexColor(self, red, g, b) self.color = { red, g, b } end
    function r.SetTexture(self, t) self.texture = t end
    function r.SetScript(self, name, fn) self.scripts[name] = fn end
    function r.GetScript(self, name) return self.scripts[name] end
    function r.HookScript(self, name, fn)
        local was = self.scripts[name]
        self.scripts[name] = function(...) if was then was(...) end fn(...) end
    end
    function r.CreateTexture() return Region("Texture") end
    function r.CreateFontString() return Region("FontString") end
    function r.SetResizeBounds(self, ...) self.bounds = { ... } end
    function r.StartSizing(self, point) self.sizing = point end
    function r.StopMovingOrSizing(self) self.sizing = nil end
    -- Methods not modelled are no-ops; a missing data field (lower case) stays nil.
    return setmetatable(r, { __index = function(_, k)
        if type(k) == "string" and k:match("^%u") then return function() end end
    end })
end
local function Frame(kind, name)
    local f = Region(kind or "Frame")
    f.name = name
    return f
end

local S = { NeedMainSpec = 0, NeedOffSpec = 1, Transmog = 2, Greed = 3, NoRoll = 4, Pass = 5 }
Enum = { EncounterLootDropRollState = S }
NEED, GREED, PASS, LOOT_ROLLS, LOOT_HISTORY_ALL_PASSED = "Need", "Greed", "Pass", "Loot Rolls", "All Passed"
RETRIEVING_DATA, UNKNOWNOBJECT = "Retrieving item information", "Unknown"
RAID_CLASS_COLORS = { MAGE = { r = 0.2, g = 0.8, b = 1 }, WARRIOR = { r = 0.8, g = 0.6, b = 0.4 } }
ITEM_QUALITY_COLORS = { [4] = { r = 0.6, g = 0.2, b = 0.9 }, [1] = { r = 1, g = 1, b = 1 } }
UIParent = Frame("Frame", "UIParent")
GameTooltip = Region("GameTooltip")
IsModifiedClick = function() return false end

local function Roll(name, class, state, roll, winner, self)
    return { playerName = name, playerClass = class, state = state, roll = roll, isWinner = winner, isSelf = self }
end
local ENCOUNTERS = {
    { encounterID = 1, startTime = 100 },
    { encounterID = 2, startTime = 200 },
}
local DROPS = {
    [1] = { { lootListKey = 1, itemHyperlink = "link:cloth", allPassed = true,
        rollInfos = { Roll("Me", "MAGE", S.Pass, nil, false, true), Roll("Bob", "WARRIOR", S.Pass) } } },
    [2] = {
        { lootListKey = 1, itemHyperlink = "link:sword", winner = { playerName = "Bob", playerClass = "WARRIOR", roll = 87 },
            rollInfos = { Roll("Bob", "WARRIOR", S.NeedMainSpec, 87, true), Roll("Me", "MAGE", S.Greed, 30, false, true),
                Roll("Ann", "MAGE", S.Pass) } },
        { lootListKey = 2, itemHyperlink = "link:ring", currentLeader = { playerName = "Ann", roll = 61 },
            rollInfos = { Roll("Ann", "MAGE", S.NeedMainSpec, 61), Roll("Me", "MAGE", S.NoRoll, nil, false, true),
                Roll("Bob", "WARRIOR", S.NoRoll) } },
    },
}
C_LootHistory = {
    GetAllEncounterInfos = function() return ENCOUNTERS end,
    GetSortedDropsForEncounter = function(id) return DROPS[id] or {} end,
    GetSortedInfoForDrop = function(id, key)
        for _, drop in ipairs(DROPS[id] or {}) do if drop.lootListKey == key then return drop end end
    end,
}
local ITEMS = { ["link:sword"] = { "Sword", 4, "sword.blp" }, ["link:cloth"] = { "Cloth", 1, "cloth.blp" } }
C_Item = { GetItemInfo = function(link)
    local item = ITEMS[link]
    if item then return item[1], link, item[2], 60, 60, "", "", 1, "", item[3] end
end }

local dressing = true
local hooks, grip = {}, nil
local db = { lootHistoryW = 0, lootHistoryH = 0 }
local P = { after = {}, Dressing = function(key) return key == "panelLootHistory" and dressing end }
local ns = {
    db = db, panels = P, EMPTY = {}, L = setmetatable({}, { __index = function(_, k) return k end }),
    NewFrame = function(kind, name) return Frame(kind, name) end,
    TipRim = function(host) host.rim = true end,
    SetTwoPointsIf = function(region, p1, r1, rp1, x1, y1, p2, r2, rp2, x2, y2)
        region:ClearAllPoints()
        region:SetPoint(p1, r1, rp1, x1, y1)
        region:SetPoint(p2, r2, rp2, x2, y2)
    end,
    SetPointOnce = function(region, ...)
        region:ClearAllPoints()
        region:SetPoint(...)
    end,
    SkinCloseButton = function() end,
    GripButton = function(parent)
        grip = Frame("Button")
        grip.parent = parent
        return grip
    end,
    AttachTip = function() end,
    EventFrame = function() return Frame() end,
    CloseOnEscape = function(frame) frame.escape = true end,
    Sched = { NextFrame = function(_, fn) fn() end },
    HookGlobal = function(name, fn)
        hooks[name] = fn
        return true
    end,
    Once = (function()
        local seen = {}
        return function(f, key)
            seen[f] = seen[f] or {}
            if seen[f][key] then return false end
            seen[f][key] = true
            return true
        end
    end)(),
    ClassicScrollBar = function()
        local bar = Frame("Slider")
        bar.up, bar.down = Frame("Button"), Frame("Button")
        function bar.SetRange(self, max) self.max = max end
        function bar.GetValue() return 0 end
        return bar
    end,
}
assert(loadfile(ROOT .. "/Windows/LootHistory.lua"))("ClassicUIForever", ns)

local after = P.after.GroupLootHistoryFrame
Check(type(after) == "function", "the game's window has its after")
-- The game's window (its OnShow takes the gamepad's focus) and its openers: /loot's toggle and a chat loot link.
local game = Frame("Frame", "GroupLootHistoryFrame")
game.shown, game.parent, game.strata = false, UIParent, "HIGH"
local gameShows = 0
game.scripts.OnShow = function() gameShows = gameShows + 1 end
local function SlashLoot()
    game:SetShown(not game:IsShown())
    if hooks.ToggleLootHistoryFrame then hooks.ToggleLootHistoryFrame() end
end
local function LootLink(encounterID)
    game:Show()
    if hooks.SetLootHistoryFrameToEncounter then hooks.SetLootHistoryFrameToEncounter(encounterID) end
end
after(game)
Check(type(hooks.ToggleLootHistoryFrame) == "function" and type(hooks.SetLootHistoryFrameToEncounter) == "function",
    "/loot and a chat loot link are heard")
Check(game.parent ~= UIParent and game.parent and not game.parent:IsVisible(), "the game's window waits under a hidden frame")

-- /loot: ours opens, the game's never comes into view (its OnShow never runs); again, ours closes.
SlashLoot()
local win = ns.LootRollsWindow()
Check(win:IsShown(), "/loot opens Era's window")
Check(not game:IsVisible() and gameShows == 0, "the game's window never shows, its OnShow never runs")
local w, h = win:GetSize()
Check(w == 210 and h == 175, "at Era's 210 x 175")
local b = win.bounds or {}
Check(b[1] == 210 and b[2] == 103 and (b[3] or 0) > 210 and (b[4] or 0) > 175, "sized both ways from Era's least")
Check(win.rim and win.escape and win.label.text == "Loot Rolls", "a tooltip box titled Loot Rolls, Escape closes it")

local function ShownRows(pool)
    local out = {}
    for i = 1, pool.used do
        if pool[i]:IsShown() then out[#out + 1] = pool[i] end
    end
    return out
end
local rows = ShownRows(win.items)
Check(#rows == 3, "every drop of every encounter is a row")
Check(rows[1] and rows[1].link == "link:sword" and rows[2].link == "link:ring" and rows[3].link == "link:cloth",
    "newest encounter first, the game's order within it")
local sword, ring, cloth = rows[1], rows[2], rows[3]
Check(sword.h == 36, "rows are Era's 36 tall")
Check(sword.name.text == "Sword" and sword.name.color[1] == 0.6, "a row names its item in its quality colour")
Check(sword.winner.shown and sword.winner.text == "Bob" and sword.roll.text == 87
    and sword.rollType.texture == "Interface\\Buttons\\UI-GroupLoot-Dice-Up", "a done row shows the winner, a need's dice and the roll")
Check(not ring.winner.shown and not ring.rollType.shown, "a roll still running shows no winner yet")
Check(ring.name.text == "Retrieving item information" and ring.icon.texture:find("QuestionMark") ~= nil,
    "an item not loaded yet reads as Era's retrieving line")
Check(cloth.winner.text == "All Passed" and cloth.rollType.texture == "Interface\\Buttons\\UI-GroupLoot-Pass-Up",
    "an all passed row says so with the pass icon")

-- + on a row: its rolls under it, as Era's.
local function Lines() return ShownRows(win.players) end
sword.toggle.scripts.OnClick(sword.toggle)
local lines = Lines()
Check(#lines == 2 and lines[1].name.text == "Bob" and lines[2].name.text == "Me",
    "a done drop lists those who rolled and you, not a silent passer")
Check(lines[1] and lines[1].mark.shown and not lines[2].mark.shown, "the winner's line is checked")
Check(lines[1] and lines[1].bg.shown and not lines[2].bg.shown, "odd lines shaded")
Check(not sword.winner.shown, "an open row moves the winner to its lines")
sword.toggle.scripts.OnClick(sword.toggle)
Check(#Lines() == 0, "- folds it again")
ring.toggle.scripts.OnClick(ring.toggle)
lines = Lines()
Check(#lines == 3 and lines[2].roll.text == "... ", "a running drop lists everyone, waiting ones with ...")
ring.toggle.scripts.OnClick(ring.toggle)
cloth.toggle.scripts.OnClick(cloth.toggle)
lines = Lines()
Check(#lines == 1 and lines[1].name.text == "All Passed", "an all passed drop opens on one All Passed line")
cloth.toggle.scripts.OnClick(cloth.toggle)

-- The corner: a drag keeps its size, a right click gives Era's back.
Check(grip and grip.parent == win, "our corner grip is on the window")
grip.scripts.OnMouseDown(grip, "LeftButton")
Check(win.sizing == "BOTTOMRIGHT", "a drag sizes from the corner")
win.w, win.h = 300, 400
grip.scripts.OnMouseUp(grip, "LeftButton")
Check(db.lootHistoryW == 300 and db.lootHistoryH == 400, "the size is kept for next time")
grip.scripts.OnClick(grip, "RightButton")
Check(win.w == 210 and win.h == 175 and db.lootHistoryW == 0, "a right click gives Era's size back")

SlashLoot()
Check(not win:IsShown(), "/loot again closes it")
SlashLoot()
SlashLoot()
Check(not win:IsShown() and gameShows == 0, "and opens and closes it on every press")

-- A chat loot link: ours opens on that encounter, its drops open; an encounter the history lacks opens nothing.
LootLink(9)
Check(not win:IsShown(), "a link to an encounter not in the history opens nothing")
LootLink(2)
Check(win:IsShown() and #Lines() > 0 and gameShows == 0, "a loot link opens ours with that encounter's rolls")
win:Hide()

-- Unchecked: the next /loot hands the game's window back shut, and from then on /loot opens the game's own.
dressing = false
SlashLoot()
Check(game.parent == UIParent and game.strata == "HIGH" and not game:IsShown() and gameShows == 0,
    "back under its parent, shut, without its OnShow in our name")
Check(not win:IsShown(), "ours stays shut")
SlashLoot()
Check(game:IsVisible() and gameShows == 1 and not win:IsShown(), "the game's own /loot window from then on")

-- Checked while the game's window is up: it is not pulled out from under the player; it waits till it closes.
dressing = true
local up = Frame("Frame", "GroupLootHistoryFrame")
up.parent = UIParent
assert(loadfile(ROOT .. "/Windows/LootHistory.lua"))("ClassicUIForever", ns)
P.after.GroupLootHistoryFrame(up)
Check(up.parent == UIParent and up:IsVisible(), "an open game window stays open")
up:SetShown(false)
hooks.ToggleLootHistoryFrame()
Check(up.parent ~= UIParent and ns.LootRollsWindow():IsShown(), "its next /loot parks it and opens ours")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("loot_history_test: ok")
