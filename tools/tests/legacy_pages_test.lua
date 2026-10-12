-- Offline test under Lua 5.4 for the Legacy window's pages (Legacy/LegacyWindow.lua, Legacy/LegacyTree.lua): the
-- tree's scroll bar, Apply foot and foot tabs show only on the tree page, from the window's first open on.
-- Run from the addon root: lua tools/tests/legacy_pages_test.lua (CI runs every tools/tests/*_test.lua).
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

-- Any method a stub is asked for does nothing.
local NOOP = function() end
local function Stub(fields)
    return setmetatable(fields or {}, { __index = function() return NOOP end })
end

local function Window()
    local w = Stub({ scripts = {}, shown = false, treeShown = true })
    w.title, w.portrait, w.scroll = Stub(), Stub(), Stub()
    w.child = Stub({ CreateFontString = function() return Stub() end })
    w.tabIndex = 1
    function w:SetScript(name, fn) self.scripts[name] = fn end
    function w:IsShown() return self.shown end
    function w:SetShown(on)
        self.shown = on
        local fn = self.scripts[on and "OnShow" or "OnHide"]
        if fn then fn(self) end
    end
    function w:Hide() self:SetShown(false) end
    return w
end

local tabs = {}
local function Tab()
    local t = Stub({ scripts = {} })
    function t:SetID(id) self.id = id end
    function t:GetID() return self.id end
    function t:SetScript(name, fn) self.scripts[name] = fn end
    tabs[#tabs + 1] = t
    return t
end

PlaySound, SOUNDKIT = NOOP, {}
InCombatLockdown = function() return false end
C_Traits = { GetConfigIDByTreeID = function() return nil end, GetTreeNodes = NOOP }

local window, apply
local ns = {
    L = setmetatable({}, { __index = function(_, key) return key end }), EMPTY = {}, SIDE_TAB_SLOT = 0,
    OnForever = function() return true end,
    WindowMicro = function() return NOOP end,
    WindowKey = function() return { Set = NOOP, PressFirst = NOOP, name = "key" } end,
    OnGameSpellsRoom = NOOP,
    RegisterModule = function(_, spec) apply = spec.apply end,
    TalentWindow = function() window = Window() return window end,
    TalentTreeShown = function(w, on) w.treeShown = on end,
    EventFrame = function() return Stub() end,
    SkillLineTab = Tab,
    Sched = { NextFrame = NOOP },
    SetSlotWidth = NOOP, RegisterClassicWindow = NOOP, CloseOnEscape = NOOP, TalentWindowShown = NOOP,
    RegisterEvents = NOOP, DrawTalentTab = NOOP, Print = NOOP,
}
assert(loadfile(ROOT .. "/Legacy/LegacyWindow.lua"))("ClassicUIForever", ns)
local LG = ns.legacy
-- The other two pages as plain pages: they draw their own and leave the tree's pieces alone.
for tab, key in ipairs({ "rewards", "challenges" }) do
    LG.AddPage({ key = key, tab = tab, tip = {}, title = {}, build = NOOP, shown = NOOP, refresh = NOOP })
end
assert(loadfile(ROOT .. "/Legacy/LegacyTree.lua"))("ClassicUIForever", ns)
Check(LG.pages[3] and LG.pages[3].key == "tree", "the tree is the third page")

apply()
Check(ns.ToggleLegacy(), "the window opens")
Check(window.shown, "the window shows")
Check(window.treeShown == false, "first open, on the reward track: no tree pieces")
local function Pick(index) tabs[index].scripts.OnClick(tabs[index]) end
Pick(2)
Check(window.treeShown == false, "challenges first: no tree pieces")
Pick(3)
Check(window.treeShown == true, "the tree page shows its pieces")
Pick(2)
Check(window.treeShown == false, "back on challenges: no tree pieces")
Pick(1)
Check(window.treeShown == false, "the reward track: no tree pieces")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("legacy_pages_test: ok")
