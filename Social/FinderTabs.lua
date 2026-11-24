local _, ns = ...

-- The finder's three side tabs (Create Listing, Group Browser, Who), on both the Who tab and the dressed finder.
-- Pages turn only by the client's own side tabs, lent over ours: our turns taint selectedTab.

local S = ns.social

-- Plain setters: the arrows never swap to bronze copies.
local RAW = { set = "raw" }
local TOGGLE_TIP = { text = function() return _G.LOOKING_FOR_GROUP or _G.GROUP_FINDER or "Group Finder" end }
-- The client's side tab per page, by our tab's index; its own Who page's only while our who list is off (#210: ours then
-- shut the finder for a list that never came).
local CATCH_KEYS = { "ListingTab", "BrowsingTab", "WhoListingTab" }
-- The client's own who page, which a click on its micro button can reopen.
local WHO_PAGE = 3

-- Built per call: the tab strings are read at build time, not at file load.
local function Entries()
    return {
        { index = 1, icon = "Interface/Icons/INV_Helmet_08", text = _G.LFG_LIST_TAB_1 or "Create Listing" },
        { index = 2, icon = "Interface/Icons/Achievement_General_StayClassy", text = _G.LFG_LIST_TAB_2 or "Group Browser" },
        { who = true, icon = "Interface/Icons/INV_OwlDragonMount", text = _G.LFG_LIST_TAB_3 or WHO or "Who" },
    }
end

-- Our tabs' icons and tooltips for another window's finder tabs, by page (3: Who).
function S.FinderTabEntries() return Entries() end

-- ns.NewSideTab lives in SpellBook.lua, which loads later: looked up per call. The first tab hangs off anchor.
local function NewFinderTab(parent, i, prev, entry, anchor)
    local side = ns.NewSideTab(parent, i, prev)
    if i == 1 then
        ns.SetPointOnce(side, "TOPLEFT", anchor, "TOPRIGHT", -3, -58)
    end
    side:SetNormalTexture(entry.icon)
    side.tooltip = entry.text
    return side
end

local whoTabs, whoToggle = {}, nil
-- Hide Who side tab: the finder without it, so Who is only reached from the social window. With our finder off, the
-- finder's Who tab goes only when Who lives in the social window (Social/SocialWindow.lua S.WhoInSocialOnly).
local function FinderWhoHidden()
    if S.WhoInSocialOnly() then return true end
    if S.WhoInFinder() then return false end
    return ns.db ~= nil and ns.db.hideFinderWho == true
end

-- Our who list off, or Who left in the game's finder: the finder's own Who page stands for it.
function S.FinderWhoOwn() return S.WhoInFinder() or not (ns.ModuleInForce and ns.ModuleInForce("whoList")) end

-- Who in the social window with our finder off: the game's finder shows no Who tab, side or top (its old style's);
-- held through its own tab passes, given back when Who goes home. Only tabs we hid are shown again.
local hidTabs = {}
local function KeepFinderWhoOff()
    local finder = _G["LFGParentFrame"]
    if not finder then return end
    local off = S.WhoInSocialOnly ~= nil and S.WhoInSocialOnly()
    for _, key in ipairs({ "WhoListingTab", "Tab3" }) do
        local tab = finder[key]
        if tab and off and tab:IsShown() then
            hidTabs[key] = true
            tab:Hide()
        elseif tab and not off and hidTabs[key] then
            hidTabs[key] = nil
            tab:Show()
        end
    end
end
S.KeepFinderWhoOff = KeepFinderWhoOff
ns.AttachWhenLoaded(function()
    local finder = _G["LFGParentFrame"]
    if not finder then return false end
    finder:HookScript("OnShow", KeepFinderWhoOff)
    if finder.UpdateTabs then ns.HookMethod(finder, "UpdateTabs", KeepFinderWhoOff) end
    KeepFinderWhoOff()
    return true
end)
-- On it now: the window is the game's there (Social/GroupFinder.lua stands down), its own tabs at home.
function S.FinderOnOwnWho()
    local finder = _G["LFGParentFrame"]
    return finder ~= nil and finder:IsShown() and S.FinderWhoOwn() and finder.selectedTab == WHO_PAGE
end
local finderTabs = {}

---------------------------------------------------------------- the client's tabs over ours

-- index -> our tab the client's lies over, and whether ours is lit for it; the client tab's own parent and point.
local lent, lit, home = {}, {}, {}
-- Another addon's window with finder side tabs of its own (LFG Forever's): { window, hosts = { [index] = tab }, lit }.
local outer = {}
local outerHost = setmetatable({}, { __mode = "k" })

-- A host's hover mark: ours lock their highlight, another addon's tab says it through its window's lit(tab, on).
local function Light(host, on)
    local paint = outerHost[host]
    if paint then
        if paint.lit then paint.lit(host, on) end
    elseif host.LockHighlight then
        if on then host:LockHighlight() else host:UnlockHighlight() end
    end
end

local function Catcher(index)
    local finder = _G["LFGParentFrame"]
    return finder and finder[CATCH_KEYS[index]]
end

-- Widget calls only: the client's tab keeps its own click, which turns the page in its name.
local function Lend(index, host)
    local catcher = Catcher(index)
    if not catcher or lent[index] == host then return end
    if not home[index] then home[index] = { parent = catcher:GetParent(), point = { catcher:GetPoint(1) } } end
    if lent[index] and lit[index] then Light(lent[index], false) end
    lent[index], lit[index] = host, false
    catcher:SetParent(host)
    catcher:ClearAllPoints()
    catcher:SetAllPoints(host)
    catcher:SetFrameLevel(host:GetFrameLevel() + 2)
    catcher:SetAlpha(0)
    if not catcher:IsMouseEnabled() then catcher:EnableMouse(true) end
end

-- No finder tabs of ours (groupFinder off): the client's tab goes back to its own place.
local function GiveBack(index, finder)
    local catcher, mine = Catcher(index), lent[index]
    if not catcher or not mine then return end
    if lit[index] then Light(mine, false) end
    lent[index], lit[index] = nil, false
    local was = home[index]
    catcher:SetParent(was and was.parent or finder)
    catcher:ClearAllPoints()
    if was and was.point[1] then
        catcher:SetPoint(unpack(was.point))
    else
        -- Off the finder's edge, not the first tab, which may still be lent out.
        local below = index == 1 and 0 or (Catcher(1):GetHeight() + 2) * (index - 1)
        catcher:SetPoint("TOPLEFT", finder, "TOPRIGHT", 0, -60 - below)
    end
    catcher:SetFrameLevel(finder:GetFrameLevel() + 1)
    catcher:SetAlpha(1)
    if not catcher:IsMouseEnabled() then catcher:EnableMouse(true) end
end

local RunCatchers
local onFinder = false

-- The other window's tab for this page while that window shows and the finder is shut.
local function OuterHost(index, up)
    if up then return nil end
    for _, o in ipairs(outer) do
        local host = o.hosts[index]
        if host and o.window:IsVisible() and host:IsVisible() then return host end
    end
end

-- The finder's micro button, and the secure pad our minimap's group finder icon presses it through (that press never
-- reached the micro button's tab: a /who, then the icon, opened the Who list, 2026-11-24).
local function MicroHosts()
    -- Its owner's lookup (Map/MinimapMicro.lua), never a typed name: a guessed one found no pad (2026-11-24).
    local icon = ns.GroupFinderIcon and ns.GroupFinderIcon()
    return _G["LFDMicroButton"], icon and ns.PadOf and ns.PadOf(icon)
end
local function IsMicroHost(host)
    local micro, pad = MicroHosts()
    return host ~= nil and (host == micro or host == pad)
end

-- One of those, hovered while the finder is shut on another page (the Who list after a /who): the first page's tab lies
-- over it, so the press turns the page in the client's name and the finder opens there.
local function MicroHost(finder, up)
    if up or finder.selectedTab == 1 then return nil end
    local micro, pad = MicroHosts()
    if micro and micro:IsVisible() and micro:IsEnabled() and micro:IsMouseOver() then return micro end
    if pad and pad:IsVisible() and pad:IsMouseOver() then return pad end
    return nil
end
local WatchMicro

-- Over the Who tab's while those show and the finder is shut or hovered there, else the finder's.
local function SyncCatchers()
    local finder = _G["LFGParentFrame"]
    if not finder then return end
    -- Also run while the finder shows: with no finder tabs of ours its tabs must still come home.
    if not onFinder then
        onFinder = true
        RunCatchers(finder, "finder.catchers")
    end
    WatchMicro()
    local up = finder:IsShown()
    local micro = MicroHost(finder, up)
    local own = S.FinderOnOwnWho()
    local whoHidden = FinderWhoHidden()
    for _, side in ipairs(finderTabs) do ns.SetShownIf(side, not own and not (side.index == nil and whoHidden)) end
    -- Hide Who side tab also covers the client's own Who page tab, which stands at its place with our who list on.
    local clientWho = Catcher(WHO_PAGE)
    if clientWho and not lent[WHO_PAGE] then ns.SetShownIf(clientWho, not (whoHidden and not S.FinderWhoOwn())) end
    for index = 1, #CATCH_KEYS do
        local host
        if index == WHO_PAGE then
            if S.FinderWhoOwn() then
                local social = S.whoTab
                local onSocial = social and social:IsVisible() and (not up or social:IsMouseOver())
                host = onSocial and social or OuterHost(index, up) or finderTabs[index]
            end
        else
            local who = whoTabs[index]
            local onWho = who and who:IsVisible() and (not up or who:IsMouseOver())
            host = onWho and who or OuterHost(index, up) or finderTabs[index]
            if index == 1 and micro then host = micro end
        end
        if own then host = nil end
        if host then Lend(index, host) else GiveBack(index, finder) end
        local catcher, mine = Catcher(index), lent[index]
        if catcher and mine then
            local over = catcher:IsVisible() and catcher:IsMouseOver() and true or false
            if over ~= lit[index] then
                lit[index] = over
                Light(mine, over)
            end
        end
    end
end

-- Runs every frame while parent shows.
function RunCatchers(parent, name)
    ns.Sched.OnFrame(ns.NewFrame("Frame", nil, parent), { name = name, every = 0, fn = SyncCatchers })
end

---------------------------------------------------------------- opening on a page

-- The client turned its finder under our Who tab's tab: shown on that page in the social window's place.
local pending
local function OpenOnPage()
    local index = pending
    pending = nil
    local finder = _G["LFGParentFrame"]
    if not finder or not index or finder.selectedTab ~= index then return end
    -- In a fight too: shown raw (our Escape closes it); only a locked finder stays shut.
    if not finder:IsShown() and not ns.ShowPanel(finder) then
        ns.SayNotInCombat()
        return
    end
    if FriendsFrame and FriendsFrame:IsShown() then ns.HidePanel(FriendsFrame) end
    for _, o in ipairs(outer) do
        if o.window:IsShown() then o.window:Hide() end
    end
end

-- Nothing else runs the catchers while no finder or Who tab shows: the hover does, on either host (a pad made later is
-- hooked on the next pass, out of a fight: a secure frame takes no hook in one).
local function WatchHost(host)
    if host and not InCombatLockdown() and ns.Once(host, "finderMicroWatch") then host:HookScript("OnEnter", SyncCatchers) end
end
WatchMicro = function()
    local micro, pad = MicroHosts()
    WatchHost(micro)
    WatchHost(pad)
end

local clickWatch
local function WatchClicks()
    if clickWatch then return end
    clickWatch = ns.EventFrame({ "GLOBAL_MOUSE_UP", "PLAYER_REGEN_ENABLED" }, function(_, event, button)
        -- The finder's code refused to load in a fight: fetched after it, so the client's tab is lent before a click.
        if event == "PLAYER_REGEN_ENABLED" then
            if whoTabs[1] and whoTabs[1]:IsVisible() then S.SyncWhoFinderTabs() end
            return
        end
        if button ~= "LeftButton" then return end
        for index = 1, #CATCH_KEYS do
            local host, catcher = lent[index], Catcher(index)
            local opens = host and (host.onWho or IsMicroHost(host) or host == S.whoTab or outerHost[host])
            if opens and catcher and catcher:IsVisible() and catcher:IsMouseOver() then
                -- Next frame: the client's own mouse-up turns the page first.
                pending = index
                ns.Sched.NextFrame("finder.openOnPage", OpenOnPage)
            end
        end
    end)
end

---------------------------------------------------------------- the social window's Who tab, our list off

-- Reached only without the client's tab over it: in a fight before the finder's code loaded, or on its Who page already.
function S.OpenFinderWho()
    local finder = _G["LFGParentFrame"]
    if finder and finder:IsShown() and finder.selectedTab == WHO_PAGE then
        if FriendsFrame and FriendsFrame:IsShown() then ns.HidePanel(FriendsFrame) end
    elseif InCombatLockdown() then
        ns.SayNotInCombat()
    end
end

-- While the social window shows it: the finder's code fetched, then the client's Who tab kept over ours.
local socialWatch, warmed
local function SocialWho()
    if not warmed and not _G["LFGParentFrame"] and not InCombatLockdown() and ns.WarmGroupFinder then
        warmed = true
        ns.WarmGroupFinder(true)
    end
    SyncCatchers()
end

function S.WatchSocialWho(host, on)
    if on and not socialWatch then
        socialWatch = ns.NewFrame("Frame", nil, host)
        ns.Sched.OnFrame(socialWatch, { name = "social.whoCatchers", every = 0, fn = SocialWho })
        WatchClicks()
        WatchMicro()
    end
    if socialWatch then ns.SetShownIf(socialWatch, on) end
end

---------------------------------------------------------------- on the Who tab

-- Put away behind a small arrow, as the professions book's are.
local function FinderOpen() return ns.db and ns.db.whoTabs and true or false end

function S.SyncWhoFinderTabs()
    local open = FinderOpen()
    -- The finder's code is fetched as the tabs come out, not at the click.
    if open and ns.WarmGroupFinder then ns.WarmGroupFinder() end
    for _, side in ipairs(whoTabs) do
        side:SetShown(open)
        side:SetChecked(side.who and true or false)
    end
    ns.PanelToggleFace(whoToggle, open, RAW)
    SyncCatchers()
end

-- The third tab is the who list itself; the other two open the client's
-- finder on their page. Parented to the who panel, anchored to host.
function S.BuildWhoFinderTabs(host, panel)
    if whoToggle or not ns.NewSideTab then return end
    for i, entry in ipairs(Entries()) do
        local side = NewFinderTab(panel, i, whoTabs[i - 1], entry, host)
        side.who, side.onWho = entry.who, true
        side:SetScript("OnClick", function(self)
            self:SetChecked(self.who and true or false)
            if self.who then return end
            -- Reached only without the client's tab over ours: in a fight, or before its code loaded.
            if InCombatLockdown() then
                ns.SayNotInCombat()
                return
            end
            if ns.WarmGroupFinder then ns.WarmGroupFinder() end
            local finder = _G["LFGParentFrame"]
            if finder and not finder:IsShown() then
                PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
                ns.ShowPanel(finder)
                if FriendsFrame and FriendsFrame:IsShown() then ns.HidePanel(FriendsFrame) end
            end
        end)
        whoTabs[i] = side
    end
    RunCatchers(panel, "who.catchers")
    WatchClicks()
    WatchMicro()
    whoToggle = ns.PanelToggle(panel, "ClassicUIForeverWhoTabsToggle", 24, "TOPRIGHT", host, "TOPRIGHT", -8, -28,
        panel:GetFrameLevel() + 20, function()
            ns.db.whoTabs = not FinderOpen()
            S.SyncWhoFinderTabs()
        end, TOGGLE_TIP)
    S.SyncWhoFinderTabs()
end

---------------------------------------------------------------- another addon's window

-- LendFinderTabs(window, hosts, lit): while window shows with the finder shut, the client's tab for page i lies over
-- hosts[i] (3: only with our who list off), so a click turns the page in the client's name; the finder then opens in
-- its place and window hides. lit(host, on): the hover mark, as the client's tab takes the mouse.
function S.LendFinderTabs(window, hosts, onLit)
    for _, o in ipairs(outer) do
        if o.window == window then return end
    end
    local entry = { window = window, hosts = hosts, lit = onLit }
    outer[#outer + 1] = entry
    for _, host in pairs(hosts) do outerHost[host] = entry end
    RunCatchers(window, "finder.outerCatchers")
    WatchClicks()
end

---------------------------------------------------------------- on the finder

-- anchor: the frame the art's edges are (the finder's Era origin); the window when absent.
function S.BuildFinderSideTabs(parent, anchor)
    if #finderTabs > 0 or not ns.NewSideTab then return end
    for i, entry in ipairs(Entries()) do
        local side = NewFinderTab(parent, i, finderTabs[i - 1], entry, anchor or parent)
        side.index = entry.index
        side:SetScript("OnClick", function(self)
            if entry.who then
                PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
                self:SetChecked(parent.selectedTab == WHO_PAGE)
                -- The client's own Who tab over this one turns the page.
                if S.FinderWhoOwn() then return end
                -- Back to the Who tab in this window's place: this one goes first (in a fight too, unless it is locked).
                if ns.HidePanel(parent) then ns.OpenWhoList() end
                return
            end
            -- Under the client's tab, which turns the page; only its mark is kept here.
            self:SetChecked(parent.selectedTab == entry.index)
        end)
        side:SetShown(not (entry.who and FinderWhoHidden()))
        finderTabs[i] = side
    end
    WatchMicro()
    SyncCatchers()
end

-- Runs at 10 Hz while the finder is up: written only on change.
function S.SyncFinderSideTabs(parent)
    for _, side in ipairs(finderTabs) do
        local want = (side.index or WHO_PAGE) == parent.selectedTab
        if (side:GetChecked() and true or false) ~= want then side:SetChecked(want) end
    end
end

local function IsCatcher(frame)
    for index = 1, #CATCH_KEYS do
        if Catcher(index) == frame then return true end
    end
    return false
end

-- Other addons' side tabs on the finder (LFG Forever's, #335) under our last shown one; theirs again on its own Who page.
---------------------------------------------------------------- the window another addon's finder tab opens

-- Another addon's finder tab opens its own window in the finder's place: the two share one spot, a drag of either moves
-- it (its own spot made the switch jump). Found as the window that came up with the press, never by name; finderFresh:
-- the finder's next show goes on the shared spot, after a mover put it on its own.
local partner, finderSpot, shownAtPress
local finderFresh, sessionRead = false, false

-- A frame's top left in screen pixels, nil while unreadable.
local function Spot(frame)
    local left, top = frame:GetLeft(), frame:GetTop()
    if ns.AnySecret(left, top) or not (left and top) then return nil end
    local k = frame:GetEffectiveScale()
    return { left * k, top * k }
end

local function PutOn(frame, spot)
    if not spot or (InCombatLockdown() and frame:IsProtected()) then return end
    local k = frame:GetEffectiveScale()
    ns.SetPointIf(frame, "TOPLEFT", UIParent, "BOTTOMLEFT", spot[1] / k, spot[2] / k)
end

-- The shared spot; saved only while a partner shares it, and only when it changed (the finder's pass runs 10 a second).
local function Keep(spot)
    if not spot then return end
    finderSpot = spot
    if not partner then return end
    local saved = ns.db.finderSpot
    if type(saved) ~= "table" or math.abs((saved[1] or 0) - spot[1]) > 0.5 or math.abs((saved[2] or 0) - spot[2]) > 0.5 then
        ns.db.finderSpot = { spot[1], spot[2] }
    end
end

local function OnFinderSpot(frame)
    local finder = _G["LFGParentFrame"]
    PutOn(frame, (finder and finder:IsVisible() and Spot(finder)) or finderSpot)
    -- It came up in the finder's place: the finder's next show starts from the shared spot again.
    finderFresh = true
end

-- Dropped: its spot is the finder's from now.
-- A mover holding the finder takes no spot from us (it puts the finder back at once): the partner follows the finder.
local function FinderHeld()
    local finder = _G["LFGParentFrame"]
    return finder ~= nil and ns.MoverHolds(finder) and true or false
end

-- A mover drags a window it holds by its own press handlers on that window, keeping the spot itself. A drag of the
-- partner is handed to them while one holds the finder: the mover moves and keeps the finder's spot, the partner rides
-- its drag box (its own drop was forgotten at the switch back).
local handing, stoppingOwn = false, false
local function MoverBox(finder)
    local name = finder:GetName()
    return name and _G[name .. "Move"]
end

local function PartnerDropped()
    if stoppingOwn or not partner then return end
    if handing then
        handing = false
        local finder = _G["LFGParentFrame"]
        local up = finder and finder.MA_OnMouseUp
        if type(up) == "function" then pcall(up, finder, finder, "LeftButton") end
        local box = finder and MoverBox(finder)
        local spot = type(box) == "table" and Spot(box) or nil
        Keep(spot)
        PutOn(partner, spot or finderSpot)
        return
    end
    if not FinderHeld() then Keep(Spot(partner)) end
end

local function PartnerDragStart()
    if not (partner and FinderHeld()) then return end
    stoppingOwn = true
    partner:StopMovingOrSizing()
    stoppingOwn = false
    local finder = _G["LFGParentFrame"]
    local down, box = finder.MA_OnMouseDown, MoverBox(finder)
    -- No such handlers (left to other addons by the setting alone): the partner stays on the finder's spot.
    if type(down) ~= "function" or type(box) ~= "table" or not pcall(down, finder, finder, "LeftButton") then
        OnFinderSpot(partner)
        return
    end
    handing = true
    ns.SetPointOnce(partner, "TOPLEFT", box, "TOPLEFT", 0, 0)
end

local function TakePartner(frame)
    if partner == frame then return end
    partner = frame
    ns.db.finderPartner = frame:GetName()
    frame:HookScript("OnShow", OnFinderSpot)
    ns.HookMethod(frame, "StartMoving", PartnerDragStart)
    ns.HookMethod(frame, "StopMovingOrSizing", PartnerDropped)
end

-- A locked game window among them (the communities add dialog) errors on any question from our code: passed over.
local function NoteShown(child, set)
    if ns.IsForbidden(child) then return end
    if child:IsShown() then set[child] = true end
end

-- The tab's own press opens the window: the one named window up now that was not at the press.
local function PressStart()
    shownAtPress = {}
    ns.EachChild(UIParent, NoteShown, shownAtPress)
end
local function PressEnd()
    local before = shownAtPress
    shownAtPress = nil
    if not before then return end
    local now, found = {}, nil
    ns.EachChild(UIParent, NoteShown, now)
    for frame in pairs(now) do
        if not before[frame] and frame:GetName() and frame ~= _G["LFGParentFrame"] then
            -- Two came up: no telling which the tab opened.
            if found then return end
            found = frame
        end
    end
    if not found then return end
    TakePartner(found)
    OnFinderSpot(found)
end

-- Each pass while the finder shows: just up, back on the shared spot (a mover puts it on its own saved one as it shows);
-- after that its own spot, so a drag of it moves the shared one; the partner of an earlier session found again.
local function KeepPartner(parent)
    local name = ns.db.finderPartner
    if not partner and type(name) == "string" and name ~= "" and type(_G[name]) == "table" then TakePartner(_G[name]) end
    -- A partner's last session: its shared spot stands for a mover's saved one at the first show.
    if not sessionRead then
        sessionRead = true
        local saved = ns.db.finderSpot
        if partner and type(saved) == "table" and type(saved[1]) == "number" and type(saved[2]) == "number" then
            finderSpot, finderFresh = { saved[1], saved[2] }, true
        end
    end
    if finderFresh then
        finderFresh = false
        if partner and not FinderHeld() then PutOn(parent, finderSpot) end
    end
    Keep(Spot(parent))
    for _, tab in ipairs(ns.AdoptedSideTabs and ns.AdoptedSideTabs(parent) or {}) do
        if ns.Once(tab, "finderPartnerPress") then
            tab:HookScript("OnMouseDown", PressStart)
            tab:HookScript("OnMouseUp", PressEnd)
        end
    end
end

function S.AdoptFinderOthers(parent)
    if not ns.AdoptSideTabs then return end
    local last
    if not S.FinderOnOwnWho() then
        for _, side in ipairs(finderTabs) do
            if side:IsShown() then last = side end
        end
    end
    ns.AdoptSideTabs(parent, last, IsCatcher)
    KeepPartner(parent)
end

-- In a fight too: only a widget's shown state (the client's tab over it hides with it).
ns.OnToggle(function(key)
    if key == "finderWhoInSocial" then KeepFinderWhoOff() end
    if key ~= "hideFinderWho" and key ~= "finderWhoInSocial" then return end
    for _, side in ipairs(finderTabs) do
        if not side.index then side:SetShown(not FinderWhoHidden()) end
    end
end)

-- dbVersion 35: the finder's Who side tab hidden for every install (dbVersion 28 had kept it for installs from before);
-- Hide Who side tab under Social turns it back.
function ns.HideFinderWhoNow()
    local db = ns.db
    db.hideFinderWho = true
    for _, shot in pairs(type(db.profiles) == "table" and db.profiles or {}) do
        if type(shot) == "table" then shot.hideFinderWho = nil end
    end
    db.dbVersion = 35
end
