-- Offline test under Lua 5.4 for other addons' side tabs on a window wearing ours (UI/SkillLineTab.lua ns.AdoptSideTabs,
-- Social/FinderTabs.lua S.AdoptFinderOthers). LFG Forever hangs the game's large side tab under the finder's own Who
-- tab, which we lend over our hidden one: it stood a slot low at the game's size (#335). It must wear our plate at our
-- size under our last shown tab, keep its own click, and go back whole on the finder's own Who page.
-- Run from the addon root: lua tools/tests/side_tab_adopt_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 122 212 213

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end
unpack = table.unpack

local failed = 0
local function Check(ok, what)
    if not ok then
        failed = failed + 1
        print("FAIL " .. what)
    end
end

------------------------------------------------------------------ the stub client: frames and textures as the game's

local Region = {}
local RegionMT = { __index = Region }
local function NewRegion(kind, parent, layer)
    local r = setmetatable({ _kind = kind, _parent = parent, _alpha = 1, _points = {}, _shown = true, _w = 0, _h = 0,
        _children = {}, _regions = {}, _scripts = {}, _hooks = {}, _masks = {}, _layer = layer, _level = 1 }, RegionMT)
    if parent then
        local list = (kind == "Texture" or kind == "MaskTexture") and parent._regions or parent._children
        list[#list + 1] = r
        r._level = (parent._level or 0) + 1
    end
    return r
end
function Region:IsForbidden() return false end
function Region:GetName() return self._name end
function Region:GetParent() return self._parent end
function Region:SetParent(p)
    local old = self._parent
    if old then
        for i, c in ipairs(old._children) do
            if c == self then table.remove(old._children, i) break end
        end
    end
    self._parent = p
    p._children[#p._children + 1] = self
end
function Region:GetNumChildren() return #self._children end
function Region:GetChildren() return unpack(self._children) end
function Region:CreateTexture(_, layer) return NewRegion("Texture", self, layer) end
function Region:SetSize(w, h) self._w, self._h = w, h end
function Region:GetWidth() return self._w end
function Region:GetHeight() return self._h end
function Region:GetSize() return self._w, self._h end
function Region:ClearAllPoints() self._points = {} end
-- The game's forms: (point, x, y) and (point, rel[, relPoint, x, y]); the same point again replaces it.
function Region:SetPoint(point, rel, relPoint, x, y)
    if type(rel) == "number" then rel, relPoint, x, y = self._parent, point, rel, relPoint end
    rel = rel or self._parent
    relPoint = relPoint or point
    for i, p in ipairs(self._points) do
        if p[1] == point then table.remove(self._points, i) break end
    end
    self._points[#self._points + 1] = { point, rel, relPoint, x or 0, y or 0 }
end
function Region:SetAllPoints(rel) self._points = { { "TOPLEFT", rel, "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", rel, "BOTTOMRIGHT", 0, 0 } } end
function Region:GetNumPoints() return #self._points end
-- A top left set on the screen's corner is where the frame then stands (the game's rect follows its anchor).
local function Corner(self)
    local p = self._points[1]
    if p and p[1] == "TOPLEFT" and p[2] == UIParent and p[3] == "BOTTOMLEFT" then return p[4], p[5] end
end
function Region:GetLeft() local x = Corner(self) return x or self._left end
function Region:GetTop() local _, y = Corner(self) return y or self._top end
function Region:StopMovingOrSizing() end
function Region:GetEffectiveScale() return self._scale or 1 end
function Region:IsProtected() return false end
function Region:GetPoint(i) local p = self._points[i or 1] if p then return p[1], p[2], p[3], p[4], p[5] end end
function Region:SetAlpha(a) self._alpha = a end
function Region:GetAlpha() return self._alpha end
function Region:Show() self._shown = true end
function Region:Hide() self._shown = false end
function Region:SetShown(s) self._shown = s and true or false end
function Region:IsShown() return self._shown end
function Region:IsVisible()
    local r = self
    while r do
        if not r._shown then return false end
        r = r._parent
    end
    return true
end
function Region:IsMouseOver() return self._over == true end
function Region:IsMouseEnabled() return self._mouse ~= false end
function Region:EnableMouse(on) self._mouse = on end
function Region:SetFrameLevel(l) self._level = l end
function Region:GetFrameLevel() return self._level end
function Region:SetTexture(path) self._tex = path end
function Region:SetAtlas(atlas) self._atlas = atlas end
function Region:SetTexCoord(...) self._coords = { ... } end
function Region:SetBlendMode(m) self._blend = m end
function Region:AddMaskTexture(m) self._masks[#self._masks + 1] = m end
function Region:RemoveMaskTexture(m)
    for i, have in ipairs(self._masks) do
        if have == m then table.remove(self._masks, i) return end
    end
end
function Region:SetScript(name, fn) self._scripts[name], self._hooks[name] = fn, {} end
function Region:GetScript(name) return self._scripts[name] end
function Region:HookScript(name, fn)
    self._hooks[name] = self._hooks[name] or {}
    table.insert(self._hooks[name], fn)
end
function Region:Fire(name, ...)
    if self._scripts[name] then self._scripts[name](self, ...) end
    for _, fn in ipairs(self._hooks[name] or {}) do fn(self, ...) end
end
function Region:SetID(id) self._id = id end
function Region:GetID() return self._id end
function Region:SetChecked(on) self._checked = on and true or false end
function Region:GetChecked() return self._checked end
function Region:SetNormalTexture(t) self._normal = t end
function Region:LockHighlight() end
function Region:UnlockHighlight() end

function hooksecurefunc(t, name, fn)
    local old = t[name]
    t[name] = function(...)
        local a, b, c = old(...)
        fn(...)
        return a, b, c
    end
end
function Mixin(object, ...)
    for i = 1, select("#", ...) do
        for k, v in pairs((select(i, ...))) do object[k] = v end
    end
    return object
end
function CreateFromMixins(...) return Mixin({}, ...) end
function InCombatLockdown() return false end
function PlaySound() end
SOUNDKIT = { IG_CHARACTER_INFO_TAB = 1 }
C_Texture = { GetAtlasInfo = function() return { width = 48, height = 48 } end }
TextureKitConstants = { UseAtlasSize = true }
UIParent = NewRegion("Frame")

-- SidePanelTabButtonMixin, as Forever's Blizzard_SharedXML Mainline/SharedUIPanelTemplates.lua and its Camelot override.
SidePanelTabButtonMixin = {}
function SidePanelTabButtonMixin.CalculateTabSizeBasedOnTabArt()
    local info = C_Texture.GetAtlasInfo("common-sidetab")
    return info.width, info.height - 5
end
function SidePanelTabButtonMixin:OnLoad()
    self:InitializeSizeForTabArt()
    self:InitializeIconAnchoring()
end
function SidePanelTabButtonMixin:InitializeSizeForTabArt()
    self:SetSize(SidePanelTabButtonMixin.CalculateTabSizeBasedOnTabArt())
end
function SidePanelTabButtonMixin:InitializeIconAnchoring()
    local x, y = self:GetFinalIconAnchorOffsets()
    self.Icon:ClearAllPoints()
    self.Icon:SetPoint("CENTER", x, y)
end
function SidePanelTabButtonMixin:GetFinalIconAnchorOffsets() return self:GetIconAnchorOffsetsForTabArt() end
function SidePanelTabButtonMixin:GetIconAnchorOffsetsForTabArt() return -4, 0 end
function SidePanelTabButtonMixin:GetPressedIconAnchorOffsets()
    local x, y = self:GetFinalIconAnchorOffsets()
    return x + 1, y - 1
end
function SidePanelTabButtonMixin:OnMouseDown(button)
    if button == "LeftButton" then
        local x, y = self:GetPressedIconAnchorOffsets()
        self.Icon:SetPoint("CENTER", x, y)
    end
end
function SidePanelTabButtonMixin:OnMouseUp(button, upInside)
    if button == "LeftButton" then
        local x, y = self:GetFinalIconAnchorOffsets()
        self.Icon:SetPoint("CENTER", x, y)
    end
    if self.customMouseUpHandler then self.customMouseUpHandler(self, button, upInside) end
end
function SidePanelTabButtonMixin:SetCustomOnMouseUpHandler(handler) self.customMouseUpHandler = handler end
function SidePanelTabButtonMixin:SetFillToInterior(fill, extent)
    self.fillToInterior = fill
    self.interiorExtent = extent
    self:UpdateIconInterior()
end
function SidePanelTabButtonMixin:UpdateIconInterior()
    if self.fillToInterior then
        local extent = self.interiorExtent or 50
        self.Icon:SetTexCoord(0.03125, 0.96875, 0.03125, 0.96875)
        self.Icon:SetSize(extent, extent)
    end
end
function SidePanelTabButtonMixin:SetChecked(checked)
    if self.SelectedTexture then self.SelectedTexture:SetShown(checked) end
    self:UpdateIconInterior()
end

-- LargeSideTabButtonTemplate's regions and scripts (Mainline/SharedUIPanelTemplates.xml:1008-1068), then its mixin.
local function LargeSideTab(name, parent, mixin)
    local tab = NewRegion("Frame", parent)
    tab._name = name
    if name then _G[name] = tab end
    Mixin(tab, mixin or SidePanelTabButtonMixin)
    tab.Background = tab:CreateTexture(nil, "BACKGROUND")
    tab.Icon = tab:CreateTexture(nil, "ARTWORK")
    tab.Mask = NewRegion("MaskTexture", tab, "ARTWORK")
    tab.Icon:AddMaskTexture(tab.Mask)
    tab.SelectedTexture = tab:CreateTexture(nil, "OVERLAY")
    tab.TabGlow = tab:CreateTexture(nil, "OVERLAY")
    tab.TabGlow:SetAlpha(0)
    tab.HighlightTexture = tab:CreateTexture(nil, "HIGHLIGHT")
    for _, script in ipairs({ "OnMouseDown", "OnMouseUp", "OnEnter", "OnLeave" }) do
        tab:SetScript(script, tab[script])
    end
    tab:OnLoad()
    return tab
end

function CreateFrame(kind, name, parent, template)
    if template == "LargeSideTabButtonTemplate" then return LargeSideTab(name, parent) end
    local f = NewRegion(kind, parent or UIParent)
    f._name = name
    return f
end

-- The finder and its three right tabs (Blizzard_LFGVanilla_ParentFrame.xml:94-121, ParentFrame.lua:93-105).
local LFGParentFrameRightTabMixin = CreateFromMixins(SidePanelTabButtonMixin)
function LFGParentFrameRightTabMixin:OnLoad()
    SidePanelTabButtonMixin.OnLoad(self)
    self.Icon:SetSize(30, 30)
end
local finder = NewRegion("Frame", UIParent)
finder._name = "LFGParentFrame"
LFGParentFrame = finder
finder.selectedTab = 2
local prevRight
for i, key in ipairs({ "ListingTab", "BrowsingTab", "WhoListingTab" }) do
    local tab = LargeSideTab(nil, finder, LFGParentFrameRightTabMixin)
    tab:SetID(i)
    if prevRight then
        tab:SetPoint("TOPLEFT", prevRight, "BOTTOMLEFT", 0, -2)
    else
        tab:SetPoint("TOPLEFT", finder, "TOPRIGHT", 0, -60)
    end
    finder[key] = tab
    prevRight = tab
end

------------------------------------------------------------------ the addon's own pieces

local ns = { social = {}, db = { hideFinderWho = true }, PassReads = function(fn) return fn end }
local inForce = { whoList = true, groupFinder = true }
function ns.ModuleInForce(key) return inForce[key] == true end
function ns.OnToggle() end
function ns.NewFrame(kind, name, parent) return CreateFrame(kind, name, parent) end
function ns.SetTex(tex, key) tex._key = key end
function ns.DressStates() end
-- Art/ThemeLayers.lua's on a piece with no theme layer: the mask on or off the piece itself.
function ns.WearMask(piece, mask, on)
    if on then piece:AddMaskTexture(mask) else piece:RemoveMaskTexture(mask) end
end
ns.Sched = { OnFrame = function() end, NextFrame = function() end }
function ns.EventFrame() return NewRegion("Frame") end

local function Load(path)
    local chunk = assert(loadfile(ROOT .. "/" .. path))
    chunk("ClassicUIForever", ns)
end
Load("Core/Util.lua")
Load("Core/Setters.lua")
Load("Core/Hooks.lua")
Load("UI/SkillLineTab.lua")
ns.NewSideTab = function(parent, i, prev)
    local tab = ns.SkillLineTab(parent, prev)
    tab:SetID(i)
    return tab
end
Load("Social/FinderTabs.lua")
local S = ns.social

------------------------------------------------------------------ LFG Forever's tab, as its core/blizzardtab.lua builds it

local opened = 0
local function LFGForeverTab()
    local t = CreateFrame("Frame", "LFGForeverBlizzardTab", finder, "LargeSideTabButtonTemplate")
    t.Icon:SetAtlas("lfgforever-eye")
    t.Icon:SetSize(30, 30)
    t:SetFillToInterior(true)
    t:SetPoint("TOPLEFT", finder.WhoListingTab, "BOTTOMLEFT", 0, -2)
    t:SetChecked(false)
    t.tooltipText = "LFG Forever"
    t:SetCustomOnMouseUpHandler(function(_, button, upInside)
        if button == "LeftButton" and upInside then opened = opened + 1 end
    end)
    return t
end
local lfg = LFGForeverTab()
local before = { w = lfg:GetWidth(), h = lfg:GetHeight(), point = { lfg:GetPoint(1) }, iconW = lfg.Icon:GetWidth() }

------------------------------------------------------------------ on the finder, our who list on, Who side tab hidden

S.BuildFinderSideTabs(finder, finder)
finder:Show()
S.AdoptFinderOthers(finder)

local function Ours(i)
    for _, child in ipairs(finder._children) do
        if child._id == i and child._kind == "CheckButton" then return child end
    end
end
local two, three = Ours(2), Ours(3)
Check(two and two:IsShown() and three and not three:IsShown(), "our tabs: Create Listing and Group Browser up, Who hidden")

local function Near(a, b) return math.abs((a or 0) - b) < 0.01 end
local p, rel, relPoint, x, y = lfg:GetPoint(1)
Check(lfg:GetNumPoints() == 1 and p == "TOPLEFT" and rel == two and relPoint == "BOTTOMLEFT" and Near(x, 0)
    and Near(y, -17), "LFG Forever's tab under our last shown tab, the spellbook's 17 down (was under the hidden slot)")
Check(Near(lfg:GetWidth(), 32) and Near(lfg:GetHeight(), 32),
    "LFG Forever's tab at our 32 (was " .. before.w .. " x " .. before.h .. ")")
Check(lfg.Background:GetAlpha() == 0 and lfg.HighlightTexture:GetAlpha() == 0 and lfg.SelectedTexture:GetAlpha() == 0,
    "the large tab's art off")
Check(#lfg.Icon._masks == 0, "the large tab's cut-out off the icon")
-- Our piece on it, or a stand-in that reads as hidden when the tab was never taken.
local function Own(key)
    return lfg.fcui and lfg.fcui[key] or { IsShown = function() return false end, GetWidth = function() return 0 end }
end
local plate = Own("sideTabPlate")
Check(plate._key == "sbSkillTab" and plate:IsShown() and Near(plate:GetWidth(), 64), "our plate behind it")
Check(Own("sideTabGlow")._key == "highlight" and Own("sideTabGlow")._layer == "HIGHLIGHT",
    "our hover glow")
local function IconFills()
    local ip, irel, irp, ix, iy = lfg.Icon:GetPoint(1)
    return lfg.Icon:GetNumPoints() == 1 and ip == "CENTER" and irel == lfg and irp == "CENTER" and Near(ix, 0)
        and Near(iy, 0) and Near(lfg.Icon:GetWidth(), 32) and Near(lfg.Icon:GetHeight(), 32)
end
Check(IconFills(), "its icon fills the tab, as ours")
Check(not Own("sideTabChecked"):IsShown(), "not checked: no gold edge")

-- Its own click, through the template's press and release.
lfg:Fire("OnMouseDown", "LeftButton")
Check(IconFills(), "pressed: the icon stays put (the template nudges it 4 left for its wider art)")
lfg:Fire("OnMouseUp", "LeftButton", true)
Check(IconFills() and opened == 1, "released: its own handler ran, the icon in place")
lfg:SetChecked(true)
Check(IconFills() and Own("sideTabChecked"):IsShown(), "checked: our gold edge, its interior size held at 32")
lfg:SetChecked(false)
Check(not Own("sideTabChecked"):IsShown(), "unchecked: the edge off")

-- The game's own right tabs are left alone.
for _, key in ipairs({ "ListingTab", "BrowsingTab", "WhoListingTab" }) do
    Check(finder[key].fcui == nil, "the game's own " .. key .. " not taken")
end

-- Hide Who side tab off: ours shows Who, theirs follows it.
three:Show()
S.AdoptFinderOthers(finder)
Check(select(2, lfg:GetPoint(1)) == three, "our Who tab shown: LFG Forever's under it")
three:Hide()
S.AdoptFinderOthers(finder)
Check(select(2, lfg:GetPoint(1)) == two, "Who hidden again: back under Group Browser")

-- A second addon's tab made later: read on the count change, stacked under the first; a hidden one skipped.
local other = CreateFrame("Frame", "OtherAddonTab", finder, "LargeSideTabButtonTemplate")
other:SetPoint("TOPLEFT", finder, "TOPRIGHT", 0, -300)
S.AdoptFinderOthers(finder)
Check(select(2, other:GetPoint(1)) == lfg and Near(other:GetWidth(), 32), "a later addon's tab under LFG Forever's")
lfg:Hide()
S.AdoptFinderOthers(finder)
Check(select(2, other:GetPoint(1)) == two, "LFG Forever's hidden: the next stands in its place")
lfg:Show()
S.AdoptFinderOthers(finder)

-- The finder's own Who page with our who list off: the window is the game's, theirs go back whole.
inForce.whoList = false
finder.selectedTab = 3
S.AdoptFinderOthers(finder)
local bp, brel, brp, _, by = lfg:GetPoint(1)
Check(brel == finder.WhoListingTab and bp == "TOPLEFT" and brp == "BOTTOMLEFT" and Near(by, -2),
    "the game's own Who page: LFG Forever's tab back under the game's Who tab")
Check(Near(lfg:GetWidth(), before.w) and Near(lfg:GetHeight(), before.h), "back at the game's size")
Check(lfg.Background:GetAlpha() == 1 and lfg.HighlightTexture:GetAlpha() == 1 and #lfg.Icon._masks == 1,
    "its own art and cut-out back")
Check(Near(lfg.Icon:GetWidth(), before.iconW) and select(4, lfg.Icon:GetPoint(1)) == -4, "its icon at its own size and spot")
Check(not Own("sideTabPlate"):IsShown() and not Own("sideTabGlow"):IsShown(), "our plate and glow gone")
lfg:SetChecked(true)
Check(Near(lfg.Icon:GetWidth(), 50), "given back: the template's interior size is its own again")
lfg:SetChecked(false)

-- And taken again on the next page.
inForce.whoList = true
finder.selectedTab = 2
S.AdoptFinderOthers(finder)
Check(select(2, lfg:GetPoint(1)) == two and Near(lfg:GetWidth(), 32), "the next page: taken again")

-- A window with none of ours (LFG Forever's own): its tabs from the first spot down, in order, a hidden one skipped.
local lone = CreateFrame("Frame", "LoneWindow", nil)
local anchor = CreateFrame("Frame", nil, lone)
local mine = {}
for i = 1, 3 do
    mine[i] = CreateFrame("Frame", nil, lone, "LargeSideTabButtonTemplate")
    mine[i]:SetPoint("TOPLEFT", lone, "TOPRIGHT", 0, -60 * i)
end
mine[2]:Hide()
ns.AdoptSideTabs(lone, nil, nil, { anchor, -3, -58 })
local fp, frel, frp, fx, fy = mine[1]:GetPoint(1)
Check(fp == "TOPLEFT" and frel == anchor and frp == "TOPRIGHT" and Near(fx, -3) and Near(fy, -58)
    and Near(mine[1]:GetWidth(), 32), "first spot: the first tab at the given spot, at our 32")
Check(select(2, mine[3]:GetPoint(1)) == mine[1] and Near(select(5, mine[3]:GetPoint(1)), -17),
    "first spot: the next shown tab 17 under it, the hidden one skipped")
ns.AdoptSideTabs(lone, nil, nil, nil)
Check(select(2, mine[1]:GetPoint(1)) == lone, "neither under nor first: the tabs go back to their own spots")

-- The finder's pass calls it on both of its paths.
local handle = assert(io.open(ROOT .. "/Social/GroupFinder.lua", "r"))
local fit = handle:read("a")
handle:close()
Check(select(2, fit:gsub("S%.AdoptFinderOthers%(parent%)", "")) == 2, "the finder's pass runs it, standing down too")

------------------------------------------------------------------ the window another addon's finder tab opens

-- LFG Forever's tab opens its own window in the finder's place, one at a time, and that window stood where its addon
-- kept it, so the switch jumped (2026-11-24). It must open on the finder's spot, found by what came up with the tab's
-- press, its name kept for the next session; a standalone open takes the finder's last spot.
ns.db.finderPartner = ""
ns.db.finderSpot = { 111, 222 }
finder:Show()
finder.selectedTab = 2
finder._left, finder._top = 700, 600
-- No partner yet: the finder is never put anywhere by this, whatever was saved.
S.AdoptFinderOthers(finder)
Check(Corner(finder) == nil, "no other addon's window: the finder stays where its own placement put it")
local window = CreateFrame("Frame", "PartnerWindow", UIParent)
window:Hide()
-- A locked game window among UIParent's children (CommunitiesAddDialog): asking it anything errors from our code.
local locked = CreateFrame("Frame", "LockedDialog", UIParent)
function locked:IsForbidden() return true end
function locked:IsShown() error("calling 'IsShown' on bad self (Attempt to access forbidden object)") end
window:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
S.AdoptFinderOthers(finder)
-- The press: its own handler opens its window and shuts the finder on the release.
lfg:Fire("OnMouseDown", "LeftButton")
window:Show()
finder:Hide()
lfg:Fire("OnMouseUp", "LeftButton", true)
local wp, wrel, wrp, wx, wy = window:GetPoint(1)
Check(wp == "TOPLEFT" and wrel == UIParent and wrp == "BOTTOMLEFT" and wx == 700 and wy == 600,
    string.format("the tab's window opens on the finder's spot (now %s %s %s, %s)", tostring(wp), tostring(wrp), tostring(wx), tostring(wy)))
Check(ns.db.finderPartner == "PartnerWindow", "its name kept for the next session")
-- The finder moved (MoveAny), then the window opened on its own (its minimap button): the finder's last spot.
window:Hide()
finder:Show()
S.AdoptFinderOthers(finder)
finder:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 300, 500)
S.AdoptFinderOthers(finder)
finder:Hide()
window:Show()
window:Fire("OnShow")
wx, wy = select(4, window:GetPoint(1))
Check(wx == 300 and wy == 500, "opened on its own: on the finder's last spot")
-- A window at another scale lands on the same screen spot.
window._scale = 2
window:Fire("OnShow")
wx, wy = select(4, window:GetPoint(1))
Check(wx == 150 and wy == 250, "at another scale: the same spot on screen")
window._scale = 1

-- Move both: its window dragged and dropped at 900, 700; back to the finder, which MoveAny puts on its own saved spot
-- (300, 500) as it shows: our pass puts it on the drop.
window:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 900, 700)
window:StopMovingOrSizing()
window:Hide()
finder:ClearAllPoints()
finder._left, finder._top = 300, 500
finder:Show()
S.AdoptFinderOthers(finder)
Check(finder:GetLeft() == 900 and finder:GetTop() == 700, string.format(
    "its window dropped elsewhere: the finder opens on the drop (now %s, %s)", tostring(finder:GetLeft()), tostring(finder:GetTop())))
Check(type(ns.db.finderSpot) == "table" and ns.db.finderSpot[1] == 900, "the shared spot kept for the next session")
-- The finder dragged (MoveAny) to 400, 650 while up: its window opens there next.
finder:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 400, 650)
S.AdoptFinderOthers(finder)
finder:Hide()
window:Show()
window:Fire("OnShow")
wx, wy = select(4, window:GetPoint(1))
Check(wx == 400 and wy == 650, "the finder dragged: its window opens on the finder's new spot")
-- A later pass while the finder is up, not just shown, leaves it where it is.
window:Hide()
finder:Show()
S.AdoptFinderOthers(finder)
S.AdoptFinderOthers(finder)
Check(finder:GetLeft() == 400, "after its first pass the finder is placed by whoever moves it, not by this")

------------------------------------------------------------------ a /who, then our minimap group finder icon

-- A /who leaves the finder shut on its own Who page. Our minimap icon presses the micro button through a secure pad, a
-- press the micro button's tab never caught, so the Who list opened in the finder's place (/fcuidev finderopen,
-- 2026-11-24). Hovering the pad lays the first page's tab over it; its press turns the page in the client's name.
local icon = CreateFrame("Button", "ForeverClassicUIGroupFinderButton", UIParent)
local pad = CreateFrame("Button", "ClassicUIForeverMapPad19", UIParent)
-- Found by its owner's lookup (Map/MinimapMicro.lua ns.GroupFinderIcon), as the game finds it, never by a name.
ns.GroupFinderIcon = function() return icon end
ns.PadOf = function(button) return button == icon and pad or nil end
finder:Hide()
finder.selectedTab = 3
S.WatchSocialWho(UIParent, true)
pad._over = true
pad:Fire("OnEnter")
Check(finder.ListingTab:GetParent() == pad, "a /who then the minimap icon hovered: the first page's tab lies over its pad")
pad._over = false
finder.selectedTab = 1
finder:Show()
pad:Fire("OnEnter")
Check(finder.ListingTab:GetParent() ~= pad, "the finder up on its first page: the tab leaves the pad")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("side_tab_adopt_test: ok")
