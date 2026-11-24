-- Offline test under Lua 5.4 for the professions window's side tabs with What's Training (Skills/ProfessionsSideTabs.lua,
-- Skills/ProfessionsFootTabs.lua). His report (2026-11-24): with the side tabs shown, our face tab stood under them as a
-- second Professions tab; What's Training's tab ignored their hover fade; the game's tabs kept their own large look.
-- Shown (always or hover): the classic look, no face tab, What's Training's under the last side tab, fading with them on
-- hover. Hidden: the face tab and What's Training's stay up (the only way in). A side tab pressed turns the list back.
-- Run from the addon root: lua tools/tests/prof_side_tabs_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 122 212 431 432

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local failed = 0
local function Check(ok, what)
    print((ok and "PASS " or "FAIL ") .. what)
    if not ok then failed = failed + 1 end
end

local AnyMT = {}
local function Any() return setmetatable({}, AnyMT) end
AnyMT.__index = function(t, k)
    if type(k) ~= "string" then return nil end
    local v = Any()
    rawset(t, k, v)
    return v
end
AnyMT.__call = function() return Any() end
AnyMT.__concat = function() return "" end

-- A tab or frame: shown, alpha, scale, points, mouse, hooked scripts.
local function Tab(name)
    local t = { name = name, shown = true, alpha = 1, scale = 1, points = nil, mouse = true, over = false, hooks = {} }
    function t:IsShown() return self.shown end
    function t:IsVisible() return self.shown end
    function t:SetScale(s) self.scale = s end
    function t:GetScale() return self.scale end
    function t:EnableMouse(on) self.mouse = on end
    function t:IsMouseEnabled() return self.mouse end
    function t:IsMouseOver() return self.over end
    function t:SetChecked(on) self.checked = on end
    function t:SetScript(k, fn) self.hooks[k] = fn end
    function t:HookScript(k, fn) self.hooks[k] = fn end
    function t:GetFrameLevel() return 5 end
    function t:Hide() self.shown = false end
    function t:Show() self.shown = true end
    setmetatable(t, { __index = function() return function() return Any() end end })
    return t
end

local window = Tab("ProfessionsFrame")
window.ProfessionsOverviewTab = Tab("overview")
window.rightProfessionTabs = { Tab("mining"), Tab("firstAid"), Tab("cooking") }
local page = Tab("page")
local list = Tab("WhatsTrainingCraftingPage")
list.shown = false
local returned = false
local returnTab = Tab("WhatsTrainingCraftingReturnTab")
returnTab.customMouseUpHandler = function() returned = true list.shown = false end

local db = { professionTabs = true, professionTabsHover = false, professionTabsHidden = false }
local adoptedWith, nextFns, jobs = nil, {}, {}
local ns = Any()
local T = Any()
rawset(ns, "prof", T)
rawset(ns, "db", db)
rawset(ns, "EMPTY", {})
rawset(ns, "L", setmetatable({}, { __index = function(_, k) return k end }))
rawset(T, "Page", function() return page end)
rawset(T, "Host", function() return window end)
rawset(T, "BookW", function() return 339 end)
rawset(ns, "OnForever", function() return true end)
rawset(ns, "ModuleInForce", function() return true end)
rawset(ns, "SpellBookActive", function() return true end)
rawset(ns, "SetShownIf", function(f, on) f.shown = on and true or false end)
rawset(ns, "SetPointOnce", function(f, point, rel, relPoint, x, y) f.points = { point, rel, relPoint, x, y } end)
rawset(ns, "SetAlphaIf", function(f, a) f.alpha = a end)
rawset(ns, "SetScaleIf", function(f, s) f.scale = s end)
rawset(ns, "SetLevelIf", function() end)
rawset(ns, "HookScriptOnce", function(f, k, fn) f.hooks[k] = fn end)
rawset(ns, "KeepDrained", function() end)
rawset(ns, "NewSideTab", function(_, i) return Tab(i == 1 and "face" or "train") end)
rawset(ns, "AdoptSideTabs", function(_, _, _, first) adoptedWith = first end)
rawset(ns, "AdoptedSideTabs", function()
    return { window.ProfessionsOverviewTab, window.rightProfessionTabs[1], window.rightProfessionTabs[2],
        window.rightProfessionTabs[3] }
end)
rawset(ns, "Sched", {
    Job = function(spec) local job = { fn = spec.fn, awake = false }
        function job:Wake() self.awake = true end
        function job:Sleep() self.awake = false end
        jobs[#jobs + 1] = job
        return job
    end,
    NextFrame = function(key, fn) nextFns[key] = fn end,
})

local env = setmetatable({
    ProfessionsFrame = window,
    WhatsTrainingCraftingTab = Tab("WhatsTrainingCraftingTab"),
    WhatsTrainingCraftingReturnTab = returnTab,
    WhatsTrainingCraftingPage = list,
    InCombatLockdown = function() return false end,
    GetTime = function() return 100 end,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
}, { __index = function(_, k)
    local real = _G[k]
    if real ~= nil then return real end
    return Any()
end })
local function Load(path)
    local handle = assert(io.open(ROOT .. "/" .. path, "r"))
    local source = handle:read("a")
    handle:close()
    assert(load(source, "@" .. path, "t", env))("ClassicUIForever", ns)
end
Load("Skills/ProfessionsFootTabs.lua")
Load("Skills/ProfessionsSideTabs.lua")
-- What's Training's frames, read through _G by the code.
_G.WhatsTrainingCraftingTab = env.WhatsTrainingCraftingTab
_G.WhatsTrainingCraftingReturnTab = returnTab
_G.WhatsTrainingCraftingPage = list

local function Pass()
    pcall(T.BookTabs)
    if T.SyncTabs then T.SyncTabs() end
    -- The fade runs to its end.
    for _ = 1, 100 do
        for _, job in ipairs(jobs) do if job.awake then job.fn(job) end end
    end
    if T.SyncTabs then T.SyncTabs() end
end
local function Ours()
    if not T.TrainingSideTabs then return nil, nil end
    return T.TrainingSideTabs()
end
local last = window.rightProfessionTabs[3]

-- Always shown.
Pass()
local face, train = Ours()
Check(adoptedWith ~= nil and adoptedWith[1] == window and adoptedWith[2] == 2 and adoptedWith[3] == -65,
    "the game's side tabs wear the classic look from the spellbook's first tab spot")
Check(last.scale == 1, "a classic tab keeps its own size (" .. tostring(last.scale) .. ")")
Check(face ~= nil and not face.shown, "no second Professions tab under the side tabs")
Check(train ~= nil and train.points and train.points[2] == last, "What's Training's tab stands under the last side tab")
Check(train ~= nil and train.alpha == 1, "and is up with them")

-- On hover, the mouse away: What's Training's fades with them; then the mouse on it.
db.professionTabs = false
Pass()
Check(last.alpha == 0 and train.alpha == 0, "on hover, away: the side tabs and What's Training's are faded")
train.over = true
Pass()
Check(last.alpha == 1 and train.alpha == 1, "on hover, the mouse on What's Training's: all come up")
train.over = false

-- Hidden: ours stay up, the face tab back at the column's top.
db.professionTabsHidden = true
Pass()
Check(last.alpha == 0, "hidden: the side tabs are faded out")
Check(face.shown and train.shown and train.alpha == 1, "hidden: the face tab and What's Training's stay up")
Check(train.points and train.points[2] == face, "hidden: What's Training's under the face tab")

-- Shown again, the list up: a side tab pressed turns it back.
db.professionTabs, db.professionTabsHidden = true, false
Pass()
list.shown = true
local press = window.rightProfessionTabs[1].hooks.OnMouseUp
Check(press ~= nil, "a side tab's press is watched")
if press then press(window.rightProfessionTabs[1]) end
for _, fn in pairs(nextFns) do fn() end
Check(returned, "pressing a side tab with the list up turns back to its face")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("prof_side_tabs_test: ok")
