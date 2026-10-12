local _, ns = ...
local L = ns.L

-- The classic Legacy window: the old talent window (UI/TalentWindow.lua), its pages on skill line tabs down the right
-- edge; the tree on the talent art, the others as Era's Skills tab. Each page file adds itself with LG.AddPage; a page
-- is built the first time it shows, and its events are registered only while it shows.

local LG = { pages = {} }
ns.legacy = LG

local frame, watch, current
local tabs = {}

-- The game's own wording where this client has it.
function LG.Text(global, key)
    local text = _G[global]
    if type(text) == "string" and text ~= "" then return text end
    return L[key]
end

local LegacyConsts = Constants and Constants.LegacyConsts or ns.EMPTY
LG.POINTS_CURRENCY = LegacyConsts.LEGACY_POINTS_TRAIT_CURRENCY_ID or 4225
LG.TRACK_FACTION = LegacyConsts.LEGACY_REWARD_TRACK_FACTION_ID or 2802
-- The points earned line in the Era sheet's grey strip, left of Close.
local EARNED_X, EARNED_Y = 24, -421

-- The account's Legacy Points earned so far (its reward track level); nil when the client cannot say.
function LG.Earned()
    local get = C_MajorFactions and C_MajorFactions.GetCurrentRenownLevel
    local earned = get and get(LG.TRACK_FACTION)
    return type(earned) == "number" and earned or nil
end

-- The All tab: every section folded, or all opened when all are folded.
local function FoldAll(page, collapsed)
    local fold = false
    for _, line in ipairs(page.lines) do
        if line.header and line.expanded then fold = true end
    end
    for _, line in ipairs(page.lines) do
        if line.header then collapsed[line.id] = fold or nil end
    end
    LG.Refresh()
end

-- A page as Era's Skills tab (UI/EraSkills.lua) with the points earned in its foot strip; hidden. spec: collapsed
-- (section ids folded), pick(line), link(line) for the chat link key, onEnter(line, region) for a bar's tooltip.
function LG.EraPage(window, spec)
    local page
    local collapsed = spec.collapsed
    local owner = {
        onLabel = function(line)
            collapsed[line.id] = not collapsed[line.id] or nil
            LG.Refresh()
        end,
        onBar = function(line)
            if IsModifiedClick("CHATLINK") then
                local link = spec.link(line)
                if link and not ns.IsSecret(link) then ChatFrameUtil.InsertLink(link) end
                return
            end
            spec.pick(line)
            LG.Refresh()
        end,
        onAll = function() FoldAll(page, collapsed) end,
        onClose = function() window:Hide() end,
        onUnlearn = function() end,
        onEnter = spec.onEnter,
    }
    page = ns.eraSkills.Build(window, owner)
    page.earned = page:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    page.earned:SetPoint("LEFT", page, "TOPLEFT", EARNED_X, EARNED_Y)
    return page
end

-- The page's foot line: earned, out of all the challenges give.
function LG.DrawEarned(page)
    local earned = LG.Earned()
    local most = C_Traits.GetMaxAvailableTraitCurrency and C_Traits.GetMaxAvailableTraitCurrency(LG.POINTS_CURRENCY, false)
    page.earned:SetText(earned and type(most) == "number"
        and string.format(L["LEGACY_EARNED"], "|cffffffff" .. earned .. "|r", "|cffffffff" .. most .. "|r") or "")
end

-- page: { key, tab, icon, tip = { global, key }, title = { global, key }, events, build(frame), shown(frame, on),
-- refresh(frame), learn(tree) }. tab is its place in the game's own Legacy window (Reward Track, Challenges, Tree),
-- which opens on the first.
function LG.AddPage(page)
    LG.pages[page.tab] = page
end

-- The current page drawn again.
function LG.Refresh()
    if not (frame and frame:IsShown() and current) then return end
    frame.title:SetText(LG.Text(current.title[1], current.title[2]))
    current.refresh(frame)
end

local function RefreshSoon()
    ns.Sched.NextFrame("legacy.refresh", LG.Refresh)
end

local function Listen(on)
    watch:UnregisterAllEvents()
    if on and current and current.events then ns.RegisterEvents(watch, current.events) end
end

local function ShowPage(page)
    if current == page then return end
    if current then current.shown(frame, false) end
    current = page
    if not page.built then
        page.built = true
        page.build(frame)
    end
    page.shown(frame, true)
    for i, tab in ipairs(tabs) do tab:SetChecked(LG.pages[i] == page) end
    if frame:IsShown() then
        Listen(true)
        LG.Refresh()
    end
end

local function Tab_OnClick(self)
    PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
    ShowPage(LG.pages[self:GetID()])
    -- A click on the picked tab would uncheck it.
    self:SetChecked(true)
end

local function Tab_OnEnter(self)
    local page = LG.pages[self:GetID()]
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(LG.Text(page.tip[1], page.tip[2]))
    GameTooltip:Show()
end

local function Learn(tree)
    if current and current.learn then current.learn(tree) end
end

local function BuildTabs()
    for i, page in ipairs(LG.pages) do
        local tab = ns.SkillLineTab(frame, tabs[i - 1])
        tab:SetID(i)
        tab:SetNormalTexture(page.icon)
        tab:SetScript("OnClick", Tab_OnClick)
        tab:SetScript("OnEnter", Tab_OnEnter)
        tab:SetScript("OnLeave", GameTooltip_Hide)
        tab:Show()
        tabs[i] = tab
    end
end

local function Build()
    if frame then return frame end
    frame = ns.TalentWindow("ClassicUIForeverLegacy", { refresh = LG.Refresh, learn = Learn })
    -- A change is a burst of events: one refresh, next frame.
    watch = ns.EventFrame({}, RefreshSoon)
    BuildTabs()
    frame:SetScript("OnShow", function()
        ns.TalentWindowShown(frame, true)
        Listen(true)
        if SetPortraitTexture then SetPortraitTexture(frame.portrait, "player") end
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
        LG.Refresh()
    end)
    frame:SetScript("OnHide", function()
        Listen(false)
        ns.TalentWindowShown(frame, false)
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
    end)
    -- After the window's own SetScripts, which wipe earlier hooks; the next window keeps clear of the page tabs.
    ns.SetSlotWidth(frame, ns.SIDE_TAB_SLOT)
    ns.RegisterClassicWindow(frame, true)
    ns.CloseOnEscape(frame)
    -- The talent art, scroll bar, Apply foot and foot tabs are the tree page's: hidden until it shows.
    ns.TalentTreeShown(frame, false)
    ShowPage(LG.pages[1])
    return frame
end

-- Forever's Legacy system, with its trees' configs; retail has the same tree calls but no Legacy system.
local function Supported()
    return ns.OnForever() and type(C_Traits) == "table" and type(C_Traits.GetConfigIDByTreeID) == "function"
        and type(C_Traits.GetTreeNodes) == "function"
end

local active = false

local function Toggle()
    Build()
    frame:SetShown(not frame:IsShown())
end

-- The Legacy micro button opens this window while on, and the minimap icon with it (it presses the button); in a fight
-- the frame after, as the talents button.
local TakeButton = ns.WindowMicro({ "LegacyMicroButton" }, function()
    if InCombatLockdown() then ns.Sched.NextFrame("legacy.open", Toggle) else Toggle() end
end)

-- The game's Legacy key opens this window too.
local key = ns.WindowKey("ClassicUIForeverLegacyBind", "TOGGLELEGACYSYSTEM", Toggle, "legacy")

-- While the game's spell window leaves ours no room, the key and the micro button close it first in the player's name
-- (UI/WindowCloser.lua): the key's own secure click, and a pad over the button that presses the key.
local function CloserMacro()
    if active and ns.GameSpellsCloser(frame) then return "/click " .. key.name end
end
ns.OnGameSpellsRoom(function() key:PressFirst(active and ns.GameSpellsCloser(frame) or nil) end)

local function Apply()
    if not Supported() then return end
    active = true
    TakeButton(true)
    key:Set(true)
    if ns.MapPad and _G.LegacyMicroButton then ns.MapPad(_G.LegacyMicroButton, nil, nil, CloserMacro, function() return active end) end
end

local function Restore()
    active = false
    TakeButton(false)
    key:Set(false)
    if frame and frame:IsShown() then frame:Hide() end
end

-- The gamepad cannot navigate our windows (Core/Gamepad.lua): with it on at login the game's window stays.
ns.RegisterModule("legacyWindow", { apply = Apply, restore = Restore, padLogin = true })

-- Public API (Core/API.lua): the window shown, on a page if given (its key: rewards, challenges, tree; or its tab
-- number); false when it cannot show.
function ns.ShowLegacy(page)
    if not (active and Supported()) or ns.padSession then return false end
    Build()
    if not frame:IsShown() then frame:Show() end
    local want = type(page) == "number" and LG.pages[page] or nil
    for _, each in pairs(LG.pages) do
        if each.key == page then want = each end
    end
    if want then ShowPage(want) end
    return frame:IsShown()
end
function ns.LegacyPageTab(n) return tabs[n] end

-- Opens or closes the window (/fcui legacy); false when this client or session cannot show it (said in chat).
function ns.ToggleLegacy()
    if not Supported() then
        ns.Print(L["CHAT_LEGACY_NOT_HERE"])
        return false
    end
    if ns.padSession then
        ns.Print(L["CHAT_LEGACY_NO_GAMEPAD"])
        return false
    end
    if not active then
        ns.Print(L["CHAT_LEGACY_OFF"])
        return false
    end
    Toggle()
    return true
end
