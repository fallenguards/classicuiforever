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
-- Each change of shape and of the tree's pieces, in order.
local steps = {}
local function Step(what) steps[#steps + 1] = what end
-- UI/TalentTrees.lua's side by side: on when the page's wanted() says, as Reshape asks.
local function TalentTrees(frame, opts)
    frame.panes = { Window(), Window(), Window() }
    frame.trees = { on = false }
    function frame.trees.Reshape()
        local on = opts.wanted(frame) == true
        if on ~= frame.trees.on then Step(on and "three" or "one") end
        frame.trees.on = on
    end
    frame.trees.Reshape()
end
wipe = function(t) for k in pairs(t) do t[k] = nil end end
local ns = {
    L = setmetatable({}, { __index = function(_, key) return key end }), EMPTY = {}, SIDE_TAB_SLOT = 0,
    db = { legacyThreePane = true },
    OnForever = function() return true end,
    WindowOpeners = function() return NOOP end,
    GameText = function(_, key) return key end,
    SideTabsFor = function(_, pages, onClick)
        local out = {}
        for i in ipairs(pages) do
            out[i] = Tab()
            out[i]:SetID(i)
            out[i]:SetScript("OnClick", onClick)
        end
        return out
    end,
    RegisterModule = function(_, spec) apply = spec.apply end,
    TalentWindow = function() window = Window() return window end,
    TalentTrees = TalentTrees, SetPointOnce = NOOP,
    TalentTreeShown = function(w, on)
        w.treeShown = on
        Step(on and "pieces" or "no pieces")
    end,
    EventFrame = function() return Stub() end,
    SkillLineTab = Tab,
    Sched = { NextFrame = NOOP },
    SetSlotWidth = NOOP, RegisterClassicWindow = NOOP, CloseOnEscape = NOOP, TalentWindowShown = NOOP,
    MicroButtonFollows = NOOP, RegisterEvents = NOOP, DrawTalentTab = NOOP, Print = NOOP,
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

-- Three trees side by side: only on the tree page, its window widened after the pieces show and narrowed before they go.
Check(window.trees.on == false, "the reward track: one window, not three trees")
steps = {}
Pick(3)
Check(window.trees.on == true, "the tree page with the option on: three trees")
Check(steps[1] == "pieces" and steps[2] == "three", "the tree's pieces show, then the three trees")
steps = {}
Pick(2)
Check(window.trees.on == false, "challenges: not three trees")
Check(steps[1] == "one" and steps[2] == "no pieces", "back to one tree before the tree's pieces go")
ns.db.legacyThreePane = false
Pick(3)
Check(window.trees.on == false, "the option off: one tree per tab")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("legacy_pages_test: ok")
