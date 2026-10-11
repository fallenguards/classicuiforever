-- Offline test under Lua 5.4 for the social window's foot tabs: retail's client has a Who tab of its own, which leaves
-- the row while ours stands in it and comes back when ours goes; a row too long for the window is pulled in to fit
-- (Social/SocialWindow.lua).
-- Run from the addon root: lua tools/tests/social_tabs_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 212

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local failed = 0
local function Check(ok, what)
    if not ok then
        failed = failed + 1
        print("FAIL: " .. what)
    end
end

local quiet = { __index = function() return function() end end }

local function Addon(onForever)
    local ns = setmetatable({}, quiet)
    ns.OnForever = function() return onForever end
    -- Our art replaces the client's atlas.
    ns.Dress = function(tex) tex.atlas = nil end
    ns.SetAlphaIf = function(region, alpha) region.alpha = alpha end
    ns.WhenCalm = function(_, fn) fn() end
    ns.SetShownIf = function(region, on) region.shown = on and true or false end
    return ns
end

local function Load(file, ns)
    assert(loadfile(ROOT .. "/" .. file))("ClassicUIForever", ns)
end

InCombatLockdown = function() return false end

------------------------------------------------------------------ the client's Who tab

local Tab = {}
Tab.__index = Tab
function Tab:IsShown() return self.shown end
function Tab:ClearAllPoints() self.after, self.first = nil, nil end
function Tab:SetPoint(point, rel, _, x)
    if point == "LEFT" then self.after = rel end
    if point == "TOPLEFT" then self.first, self.x = true, x end
end
function Tab:Show() self.shown = true end
function Tab:Hide() self.shown = false end
function Tab:SetScript() end
function Tab:SetID() end
function Tab:SetText() end
-- A label's drawn width, set by the test.
function Tab:GetFontString()
    local tab = self
    return { GetStringWidth = function() return tab.labelWidth or 30 end }
end
function Tab:GetID() return self.id end
function Tab:GetName() return self.name end
function Tab:EnableMouse(on) self.mouse = on end

local function NewTab() return setmetatable({ shown = true, mouse = true, alpha = 1 }, Tab) end

local function Social(clientWho)
    FriendsFrame = { GetWidth = function() return 338 end }
    for i = 1, 8 do _G["FriendsFrameTab" .. i] = nil end
    FriendsFrameTab1, FriendsFrameTab3, FriendsFrameTab4 = NewTab(), NewTab(), NewTab()
    FriendsFrameTab1.id, FriendsFrameTab1.name = 1, "FriendsFrameTab1"
    FriendsFrameTab3.id, FriendsFrameTab3.name = 2, "FriendsFrameTab3"
    FriendsFrameTab2 = clientWho and NewTab() or nil
    FRIEND_TAB_WHO = clientWho and 2 or nil
    local ns = Addon(not clientWho)
    ns.guild = {}
    ns.WhoPanel = function() return nil end
    -- Tabs only: the expand button's template is left unmade here.
    ns.NewFrame = function(_, name, _, template)
        if template ~= "PanelTabButtonTemplate" then return nil end
        local tab = NewTab()
        if name then _G[name] = tab end
        return tab
    end
    Load("Social/SocialWindow.lua", ns)
    ns.social.whoTab = NewTab()
    return ns.social
end

do
    local S = Social(true)
    Check(S.ClientWhoTab(true) == true, "retail: the client's Who tab is taken")
    S.PlaceTabs()
    Check(FriendsFrameTab2.alpha == 0 and FriendsFrameTab2.mouse == false, "retail: it is unseen and takes no mouse")
    Check(S.whoTab.after == FriendsFrameTab1, "retail: our Who tab stands after Friends")
    Check(FriendsFrameTab3.after == S.whoTab, "retail: Raid follows our tabs, not the client's Who tab")
    Check(S.ClientWhoTab(true) == false, "retail: taking it twice changes nothing")

    Check(S.ClientWhoTab(false) == true, "retail: the tab is handed back")
    S.PlaceTabs()
    Check(FriendsFrameTab2.alpha == 1 and FriendsFrameTab2.mouse == true, "retail: handed back, it shows and takes the mouse")
    Check(FriendsFrameTab3.after == FriendsFrameTab2, "retail: handed back, it stands in the row again")
end

do
    local S = Social(false)
    Check(S.ClientWhoTab(true) == false, "Forever: no client Who tab to take")
    S.PlaceTabs()
    Check(FriendsFrameTab3.after == S.whoTab, "Forever: the row is Friends, Who, then the client's others")
end

------------------------------------------------------------------ the game's new social window

-- Beta 70291's switch hides the client's Friends tab; ours stands first in the row, picked while no list of ours is up.
do
    local S = Social(false)
    C_SocialUI = { IsSystemEnabled = function() return true end }
    SocialUIFrame = {}
    PanelTemplates_SelectTab = function(tab) tab.picked = true end
    PanelTemplates_DeselectTab = function(tab) tab.picked = false end
    PanelTemplates_GetSelectedTab = function() return 1 end
    FRIEND_TAB_RAID = 2
    FriendsFrameTab1.shown, FriendsFrameTab3.shown = false, false
    S.PlaceTabs()
    local ours = _G.ClassicUIForeverFriendsTab
    Check(ours ~= nil, "switch on: our Friends tab is made")
    if ours then
        Check(ours.shown and ours.after == nil and ours.first == true, "switch on: our Friends tab stands first")
        Check(S.whoTab.after == ours, "switch on: Who follows our Friends tab")
        Check(ours.picked == true, "switch on: with no list of ours up, Friends is picked")
    end
    local raid = _G.ClassicUIForeverRaidTab
    Check(raid ~= nil and raid.shown and raid.after == S.whoTab, "switch on: our Raid tab stands where the client's was")
    Check(raid ~= nil and raid.picked == false, "switch on: on the friends page Raid is not picked")
    C_SocialUI = { IsSystemEnabled = function() return false end }
    FriendsFrameTab1.shown, FriendsFrameTab3.shown = true, true
    S.PlaceTabs()
    Check(ours == nil or ours.shown == false, "switch off: ours is gone")
    Check(_G.ClassicUIForeverRaidTab == nil or _G.ClassicUIForeverRaidTab.shown == false, "switch off: our Raid tab is gone")
    Check(S.whoTab.after == FriendsFrameTab1, "switch off: the client's Friends tab is first again")
    C_SocialUI, SocialUIFrame = nil, nil
end

------------------------------------------------------------------ a long language's row

-- Shown tabs' right end with the pads the row was given (the tabs overlap 14).
local function RowEnd(first, tabs)
    local right = first.x
    for i, tab in ipairs(tabs) do
        right = right + tab.labelWidth + tab.fcuiPad + (i > 1 and -14 or 0)
    end
    return right
end

do
    local S = Social(false)
    FriendsFrameTab3.shown, FriendsFrameTab4.shown = false, false
    local row = { FriendsFrameTab1, S.whoTab }
    FriendsFrameTab1.labelWidth, S.whoTab.labelWidth = 40, 25
    S.PlaceTabs()
    Check(FriendsFrameTab1.x == 5 and FriendsFrameTab1.fcuiPad == 38, "a short row keeps Era's start and padding")

    -- 5 + 290 + 2 * 38 - 14 = 357: 19 over the window's 338.
    FriendsFrameTab1.labelWidth, S.whoTab.labelWidth = 180, 110
    S.PlaceTabs()
    Check(FriendsFrameTab1.x == 0, "a long row starts further left")
    Check(FriendsFrameTab1.fcuiPad < 38 and S.whoTab.fcuiPad == FriendsFrameTab1.fcuiPad, "every tab gives up the same padding")
    Check(RowEnd(FriendsFrameTab1, row) <= 338, "the long row ends inside the window")

    -- 5 + 273 + 2 * 38 - 14 = 340: 2 over.
    FriendsFrameTab1.labelWidth, S.whoTab.labelWidth = 163, 110
    S.PlaceTabs()
    Check(FriendsFrameTab1.x == 3 and FriendsFrameTab1.fcuiPad == 38,
        "a row a little too long only starts further left")
    Check(RowEnd(FriendsFrameTab1, row) <= 338, "that row ends inside the window")
end

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("social_tabs_test: ok")
