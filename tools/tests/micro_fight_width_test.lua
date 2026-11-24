-- Offline test under Lua 5.4 for a hidden micro button pick on the game's own micro menu (Bar/GameMicro.lua) in a
-- fight. The game shows the shop button again on every micro button update (StoreMicroButtonMixin:UpdateMicroButton
-- calls self:Show()), each button's OnShow and OnHide lay the menu out again, and the layout counts the menu's shown
-- children; the container is protected in a fight, so our hide waits for calm. A pick shown and counted in a fight
-- widened the menu 27 px and moved the centered bottom row 14 px until the fight ended (combatbars v4, 2026-11-24).
-- The fakes keep the client's visibility rules: a frame is visible when it and every parent are shown, and OnShow or
-- OnHide fire when that changes (a Show, a Hide or a SetParent).
-- Run from the addon root: lua tools/tests/micro_fight_width_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 122 212 431 432

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local failed = 0
local function Check(ok, what)
    print((ok and "PASS " or "FAIL ") .. what)
    if not ok then failed = failed + 1 end
end

-- Frames ------------------------------------------------------------------------------------------------------------
local Frame = {}
Frame.__index = Frame
local function NewFrame(name, parent)
    local f = setmetatable({ name = name, shown = true, children = {}, hooks = {} }, Frame)
    if parent then
        f.parent = parent
        parent.children[#parent.children + 1] = f
    end
    if name then _G[name] = f end
    return f
end
function Frame:GetName() return self.name end
function Frame:IsShown() return self.shown end
function Frame:IsVisible()
    if not self.shown then return false end
    return self.parent == nil or self.parent:IsVisible()
end
function Frame:GetParent() return self.parent end
function Frame:GetChildren() return table.unpack(self.children) end
function Frame:HookScript(what, fn)
    self.hooks[what] = self.hooks[what] or {}
    table.insert(self.hooks[what], fn)
end
local function Run(f, what)
    for _, fn in ipairs(f.hooks[what] or {}) do fn(f) end
end
-- Each frame of a subtree with its visibility, parents first.
local function Walk(f, out)
    out[#out + 1] = { f, f:IsVisible() }
    for _, c in ipairs(f.children) do Walk(c, out) end
    return out
end
local function Change(f, apply)
    local before = Walk(f, {})
    apply()
    for _, e in ipairs(before) do
        local now = e[1]:IsVisible()
        if now and not e[2] then Run(e[1], "OnShow") elseif e[2] and not now then Run(e[1], "OnHide") end
    end
end
function Frame:Show() if not self.shown then Change(self, function() self.shown = true end) end end
function Frame:Hide() if self.shown then Change(self, function() self.shown = false end) end end
function Frame:SetParent(p)
    if p == self.parent then return end
    Change(self, function()
        local old = self.parent
        if old then
            for i, c in ipairs(old.children) do
                if c == self then table.remove(old.children, i) break end
            end
        end
        self.parent = p
        if p then p.children[#p.children + 1] = self end
    end)
end

-- The game's micro menu --------------------------------------------------------------------------------------------
local combat = false
_G.InCombatLockdown = function() return combat end
_G.UIParent = NewFrame("UIParent")
local container = NewFrame("MicroMenuContainer", UIParent)
local menu = NewFrame("MicroMenu", container)
local BUTTON_W = 27
local refused = 0
-- GridLayoutFrameMixin:Layout through BaseLayoutMixin:GetLayoutChildren: the shown children with a layoutIndex.
function menu:Layout()
    local n = 0
    for _, c in ipairs(self.children) do
        if c:IsShown() and c.layoutIndex then n = n + 1 end
    end
    self.width = n * BUTTON_W - 22
end
-- MicroMenuContainerMixin:Layout: its size is protected in a fight (our calls are refused there, the game's are not).
function container:Layout(byUs)
    menu:Layout()
    if combat and byUs then refused = refused + 1 return end
    self.width = menu.width
end
local NAMES = { "CharacterMicroButton", "ProfessionMicroButton", "SpellbookMicroButton", "TalentMicroButton",
    "QuestLogMicroButton", "GuildMicroButton", "LFDMicroButton", "CollectionsMicroButton", "StoreMicroButton",
    "MainMenuMicroButton" }
local byUs = false    -- the layout runs in our call (a show or hide of ours)
for i, name in ipairs(NAMES) do
    local b = NewFrame(name, menu)
    b.layoutIndex = i
    -- MainMenuBarMicroButtonMixin:OnShow and OnHide.
    b:HookScript("OnShow", function() container:Layout(byUs) end)
    b:HookScript("OnHide", function() container:Layout(byUs) end)
end
container:Layout()
-- The game's UpdateMicroButtons, from a window's show: the shop button's update shows it, always.
local function UpdateMicroButtons() StoreMicroButton:Show() end
-- The bottom row stands centered on the container's width.
local function RowLeft() return -container.width / 2 end

-- Our module ---------------------------------------------------------------------------------------------------------
local calm = {}
local def
local ns = {
    db = { hideMicroButtons = true, hideMicroShop = true },
    ModuleInForce = function() return false end,
    BarsTaken = function() return false end,
    WhenCalm = function(key, fn) calm[key] = fn end,
    Sched = { AfterShow = function(host, _, fn) host:HookScript("OnShow", function() byUs = true fn() byUs = false end) end },
    RegisterModule = function(_, d) def = d end,
    NewFrame = function(_, name, parent) return NewFrame(name, parent) end,
}
assert(loadfile(ROOT .. "/Bar/GameMicro.lua"))("ClassicUIForever", ns)
local function Apply()
    byUs = true
    def.apply()
    byUs = false
end
local function Calm()
    combat = false
    local queued = calm
    calm = {}
    byUs = true
    for _, fn in pairs(queued) do fn() end
    byUs = false
end

local full = container.width
Apply()
local picked = container.width
Check(picked == full - BUTTON_W, "the shop pick takes its button off the menu")
Check(not StoreMicroButton:IsVisible(), "the shop button is not drawn")

UpdateMicroButtons()
Check(container.width == picked and not StoreMicroButton:IsVisible(), "a window opening out of a fight leaves it off")

combat = true
local rowBefore = RowLeft()
UpdateMicroButtons()
Check(container.width == picked, "a window opening in a fight: the menu keeps its width (" .. container.width .. ")")
Check(RowLeft() == rowBefore, "the bottom row stays where it stood in the fight")
Check(not StoreMicroButton:IsVisible(), "the shop button is not drawn in the fight")
Check(refused == 0, "no call of ours on the protected container in the fight")

Calm()
Check(container.width == picked, "after the fight: the width is the same, nothing moves")
Check(not StoreMicroButton:IsVisible(), "after the fight the shop button is still off")

-- The pick taken away: the button back on the menu, shown, counted.
ns.db.hideMicroShop = false
Apply()
Check(StoreMicroButton:GetParent() == MicroMenu, "the pick gone: the shop button is back on the menu")
Check(StoreMicroButton:IsVisible() and container.width == full, "and shown in its place, the menu its full width")

-- Picked again, then handed back while the game had shown it (parked, its own shown flag on).
ns.db.hideMicroShop = true
Apply()
UpdateMicroButtons()
ns.db.hideMicroShop = false
Apply()
Check(StoreMicroButton:IsVisible() and container.width == full, "a hand-back after the game showed it parked")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("micro_fight_width_test: ok")
