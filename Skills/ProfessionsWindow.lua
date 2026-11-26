local _, ns = ...

-- Window around the book (ProfessionsBook.lua): size per face (shut at the book's size, the face a fight opens),
-- side tabs behind an arrow, the spellbook's foot tabs, book/crafting turns, and the one watcher for book and trade skill.

local T = ns.prof
local Page = T.Page
local Build, PlaceCards, FillRows = T.Build, T.PlaceCards, T.FillRows
local ShowOurs, TightenSpells = T.ShowOurs, T.TightenSpells
local EMPTY = ns.EMPTY

local active = false
-- The spellbook's drawn border (339 x 425; full size draws it bigger), its corner on that border: the spellbook's
-- art starts at (12, -118) and the manager stands a left panel at (16, -116).
local BOOK_W, BOOK_H = 339, 425
local BOOK_X, BOOK_Y, SMALL_TELL_W = -4, -2, 380
local function BookW() return BOOK_W end
local function BookH() return BOOK_H end
T.BookW, T.BookH = BookW, BookH
local SizeButton
local sizeWas
-- The side tabs (Skills/ProfessionsSideTabs.lua).
local FillTabIcons, SyncTabs = T.FillTabIcons, T.SyncTabs

-- Book size on the book, the client's on a crafting page; out of combat only (casting buttons).
-- The manager places from its stored size, rechecked per tab, and the client writes 750 back: tell it ours and re-place each time.
-- Read via the registration: the manager's first copy onto the frame overwrites earlier writes.
local function PanelAttr(frame, name)
    local value = frame:GetAttribute("UIPanelLayout-" .. name)
    if value == nil and not frame:GetAttribute("UIPanelLayout-defined") then
        local registered = UIPanelWindows and UIPanelWindows[frame:GetName()]
        value = registered and registered[name]
    end
    return value
end
local function SetPanelAttr(frame, name, value)
    if SetUIPanelAttribute then SetUIPanelAttribute(frame, name, value) else frame:SetAttribute("UIPanelLayout-" .. name, value) end
end

-- The client registers the window 35 in from the left for its own side tabs; ours stand at the usual left edge.
local function TellManager(frame, width, height)
    if not sizeWas.attrs then
        sizeWas.attrs = { PanelAttr(frame, "width"), PanelAttr(frame, "height"), PanelAttr(frame, "xoffset"),
            PanelAttr(frame, "yoffset") }
    end
    local small = width == BOOK_W
    local wantWidth, wantHeight = small and SMALL_TELL_W or width or sizeWas.attrs[1], height or sizeWas.attrs[2]
    -- Book and trade skill page on one spot, the spellbook's border's: a page turn never moves the window.
    local wantX = width and BOOK_X or sizeWas.attrs[3]
    local wantY = width and BOOK_Y or sizeWas.attrs[4]
    if PanelAttr(frame, "width") == wantWidth and PanelAttr(frame, "height") == wantHeight
        and PanelAttr(frame, "xoffset") == wantX and PanelAttr(frame, "yoffset") == wantY then return end
    SetPanelAttr(frame, "width", wantWidth)
    SetPanelAttr(frame, "height", wantHeight)
    SetPanelAttr(frame, "xoffset", wantX)
    SetPanelAttr(frame, "yoffset", wantY)
    if frame:IsShown() and UpdateUIPanelPositions then pcall(UpdateUIPanelPositions, frame) end
end

-- tellWidth/tellHeight: what the manager is told, when not the size.
local function FitWindow(width, height, tellWidth, tellHeight)
    local frame = ProfessionsFrame
    if not frame or InCombatLockdown() then return false end
    if width then
        if not sizeWas then sizeWas = { frame:GetWidth(), frame:GetHeight() } end
        if math.abs(frame:GetWidth() - width) > 0.5 or math.abs(frame:GetHeight() - height) > 0.5 then
            frame:SetSize(width, height)
        end
        TellManager(frame, tellWidth or width, tellHeight or height)
    elseif sizeWas then
        if math.abs(frame:GetHeight() - sizeWas[2]) > 0.5 then frame:SetHeight(sizeWas[2]) end
        if frame:GetWidth() < sizeWas[1] - 0.5 then frame:SetWidth(sizeWas[1]) end
        TellManager(frame, nil, nil)
    end
    return true
end

-- The popout beside the close button: the full book or the small one, on a trade skill its double pane or single; the
-- same switches as the options.
local sizeButton
local function PickSize(big)
    local key = sizeButton.trade and "tradeSkillDual" or "profBookBig"
    if not ns.db or (ns.db[key] == true) == big then return end
    ns.db[key] = big
    ns.ToggleChanged(key)
end

SizeButton = function(book, trade)
    local frame = T.Host()
    if not frame then return end
    if not sizeButton then
        local ok, button = pcall(ns.NewFrame, "Frame", nil, frame, "MaximizeMinimizeButtonFrameTemplate")
        if not ok or not button then return end
        sizeButton = button
        button:SetOnMaximizedCallback(function() PickSize(true) end)
        button:SetOnMinimizedCallback(function() PickSize(false) end)
        if ns.panels and ns.panels.MaxMinBeside then ns.panels.MaxMinBeside(button, frame.CloseButton, 8) end
    end
    local close = frame.CloseButton
    if close then ns.SetLevelIf(sizeButton, close:GetFrameLevel() + 1) end
    sizeButton.trade = trade
    if (trade and ns.tradeDual.On()) or (not trade and T.Big()) then
        sizeButton:SetMinimizedLook()
    else
        sizeButton:SetMaximizedLook()
    end
    ns.SetShownIf(sizeButton, (book or trade) and true or false)
end

-- Another addon's 60 x 15 switch button, 30 in from the window's top right, stood over our lock and reset: it stands at
-- the title bar's left end instead, past the portrait ring. Found by its spot and size, never its code.
local SWITCH_W, SWITCH_H, SWITCH_X, SWITCH_Y, SWITCH_GAP = 60, 15, -30, -4, 6
local titleSwitch
local function IsTitleSwitch(child, frame)
    local point, rel, relPoint, x, y = child:GetPoint(1)
    if ns.AnySecret(point, rel, x, y) or point ~= "TOPRIGHT" or (rel ~= nil and rel ~= frame) then return false end
    return relPoint == "TOPRIGHT" and ns.Near(x, SWITCH_X, 1) and ns.Near(y, SWITCH_Y, 1)
        and ns.Near(child:GetWidth(), SWITCH_W, 0.5) and ns.Near(child:GetHeight(), SWITCH_H, 0.5)
end
local function FindTitleSwitch(child, frame)
    if not titleSwitch and IsTitleSwitch(child, frame) then titleSwitch = child end
end
local function KeepSwitchLeft(frame, kind)
    local ring = kind and T.RingRight(kind)
    if not ring then return end
    if not titleSwitch then ns.EachChild(frame, FindTitleSwitch, frame) end
    if titleSwitch then ns.SetPointIf(titleSwitch, "TOPLEFT", frame, "TOPLEFT", ring + SWITCH_GAP, SWITCH_Y) end
end
T.KeepSwitchLeft = KeepSwitchLeft

-- Turn back to the book piece by piece: calling the window's own code would taint it.
local function BackToBook()
    local frame, page = ProfessionsFrame, Page()
    if not frame or not page or InCombatLockdown() then return false end
    page:Show()
    if frame.CraftingPage then frame.CraftingPage:Hide() end
    local title = frame.TitleContainer and frame.TitleContainer.TitleText
    if title and TRADE_SKILLS then title:SetText(TRADE_SKILLS) end
    ns.ProfessionPortrait(true)
    for _, tab in ipairs(frame.rightProfessionTabs or EMPTY) do
        if tab.SelectedTexture then tab.SelectedTexture:Hide() end
    end
    local overview = frame.ProfessionsOverviewTab
    if overview and overview.SelectedTexture then overview.SelectedTexture:Show() end
    return true
end

-- In a fight the window can't be resized (secure spell buttons), and one written on then can't close till it ends. A book
-- opened in a fight past a smaller window is drawn past it: border, title and tabs hang from our shape, which alone is
-- resized, with the chrome's stone copied under the part it adds.
local shape
-- Windows/WindowChrome.lua's cuts for its backing, streaks and title strip.
local GROW_CUTS = {
    backing = { "rockBg", { coords = { 0, 1, 0, 1 } } },
    streaks = { "frameSheet", { vert = false, coords = { 0, 1, 0.671875, 0.9609375 } } },
    titleStrip = { "frameSheet", { vert = false, coords = { 0, 1, 0.2890625, 0.421875 } } },
}

-- Nothing protected may hang from the shape, or it locks in a fight too.
local function GrowReady()
    return shape ~= nil and ns.Safe(shape:IsProtected(), true) == false
end

local function Smaller(frame, width, height)
    return ns.Safe(frame:GetWidth(), width) < width - 0.5 or ns.Safe(frame:GetHeight(), height) < height - 0.5
end

-- Once the window wears our chrome; the shape follows the window until grown.
local function EnsureShape(frame)
    local fcui = frame.fcui
    if shape or not (fcui and fcui.backing) or InCombatLockdown() then return end
    shape = ns.NewFrame("Frame", nil, frame)
    shape:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    shape:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    shape.grown, shape.art = false, {}
    for key, cut in pairs(GROW_CUTS) do
        local from = fcui[key]
        if from then
            local layer, sublevel = from:GetDrawLayer()
            local tex = ns.TileTex(shape:CreateTexture(nil, layer, nil, sublevel), cut[1], cut[2])
            tex.from = from
            tex:Hide()
            shape.art[#shape.art + 1] = tex
        end
    end
    T.shape = shape
end

-- Anchors on the window moved to the shape; out of combat only, sizes equal then.
local function Rehome(object, frame)
    if not object or ns.Safe(object:IsProtected(), true) then return end
    for i = 1, object:GetNumPoints() do
        local point, rel, relPoint, x, y = object:GetPoint(i)
        if not ns.AnySecret(point, rel, relPoint, x, y) and rel == frame then
            object:SetPoint(point, shape, relPoint, x, y)
        end
    end
end

-- The client's panel manager scales the window to 1 as it shows it (UpdateScaleForFit). Out of combat our windows edit
-- mode puts the size back the frame after; the window is protected (the book tab pads) and a fight refuses that, so
-- the secure openers put it back in their own click, after the client's show.
local sizeWrap
local function RefreshSize()
    local frame = ProfessionsFrame
    if not frame or not sizeWrap or InCombatLockdown() then return end
    sizeWrap:SetFrameRef("prof", frame)
    -- The player's size (none while a mover holds it) times the full size book's.
    local size = not ns.MoverHolds(frame) and ns.WindowScale and ns.WindowScale("professions") or 1
    sizeWrap:SetAttribute("scale", size * ns.ProfessionsZoom())
    -- The spellbook's spot (its follower's place): the click stands the window there, as one window with the book.
    local placed, left, top = ns.WindowPlaced("professions")
    sizeWrap:SetAttribute("placeL", placed and not ns.MoverHolds(frame) and left or nil)
    sizeWrap:SetAttribute("placeT", placed and not ns.MoverHolds(frame) and top or nil)
end
T.RefreshSize = RefreshSize

-- The client lays a card's spells again as the book shows (Blizzard_ProfessionsBook FormatProfession), in a fight too,
-- where they are protected: the openers' click puts them on our spots after that show (spellIJ refs, x and y).
local spellSpots = {}
local function KeepSpellSpots()
    if not sizeWrap or InCombatLockdown() then return end
    for i = 1, 2 do
        local card = T.BookCard and T.BookCard("primary", i)
        for j = 1, 2 do
            local name = "spell" .. i .. j
            local button = card and card["SpellButton" .. j]
            local x, y
            if button and button:IsShown() then
                local point, rel, relPoint, px, py = button:GetPoint(1)
                if point == "BOTTOMLEFT" and rel == card and relPoint == "BOTTOMLEFT" and not ns.AnySecret(px, py) then
                    x, y = px, py
                end
            end
            local was = spellSpots[name]
            if not was or was.button ~= button or was.x ~= x or was.y ~= y then
                spellSpots[name] = { button = button, x = x, y = y }
                if button then sizeWrap:SetFrameRef(name, button) end
                sizeWrap:SetAttribute(name .. "x", x)
                sizeWrap:SetAttribute(name .. "y", y)
            end
        end
    end
end
T.KeepSpellSpots = KeepSpellSpots

-- Our book openers (key, micro button, spellbook tab): the window recasts the profession picked last as it shows, inside
-- the click, so a trade skill opening in it is that recast (TRADE_SKILL_SHOW below).
local function MarkBookAsked() T.bookAskedAt = GetTime() end
function ns.ProfessionsSizeWrap(button)
    if not button then return end
    button:HookScript("PreClick", MarkBookAsked)
    sizeWrap = sizeWrap or CreateFrame("Frame", nil, UIParent, "SecureHandlerBaseTemplate")
    -- The client's top left kept through the size, as the windows pass keeps it (ScaleKept); then the spellbook's spot.
    SecureHandlerWrapScript(button, "OnClick", sizeWrap, [[ if not down then return nil, "size" end ]], [[
        for i = 1, 2 do
            for j = 1, 2 do
                local name = "spell" .. i .. j
                local b, x, y = control:GetFrameRef(name), control:GetAttribute(name .. "x"), control:GetAttribute(name .. "y")
                if b and x and y and b:IsShown() then b:SetPoint("BOTTOMLEFT", "$parent", "BOTTOMLEFT", x, y) end
            end
        end
        local f = control:GetFrameRef("prof")
        local s = control:GetAttribute("scale")
        if not (f and s and f:IsShown()) then return end
        local old, l, b, w, h = f:GetScale(), f:GetRect()
        local pl, pt = control:GetAttribute("placeL"), control:GetAttribute("placeT")
        if old == s and not pl then return end
        f:SetScale(s)
        if pl and pt then l, b, h, old = pl, pt, 0, 1 end
        if l then
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", "$parent", "BOTTOMLEFT", l * old / s, (b + h) * old / s)
        end
    ]])
    RefreshSize()
end

-- Every pass: chrome dressed late (a window first met in a fight) hangs from the window again.
local function Home(frame)
    if not shape or InCombatLockdown() then return end
    Rehome(frame.NineSlice, frame)
    Rehome(frame.TitleContainer, frame)
    Rehome(frame.ProfessionsOverviewTab, frame)
    Rehome(T.FirstBookTab(), frame)
    T.PlaceBookPads()
    RefreshSize()
end

-- A copy takes its stone's points, moved from the window to the shape.
local function Mirror(tex, frame)
    local from = tex.from
    tex:ClearAllPoints()
    for i = 1, from:GetNumPoints() do
        local point, rel, relPoint, x, y = from:GetPoint(i)
        if not ns.AnySecret(point, rel, relPoint, x, y) then
            tex:SetPoint(point, rel == frame and shape or rel, relPoint, x, y)
        end
    end
    tex:SetHeight(ns.Safe(from:GetHeight(), 0))
end

-- Book size on the shape (ours, so free in a fight), solid where it passes the window.
local function Grow(on)
    if not shape then return end
    on = on and active and GrowReady() or false
    if InCombatLockdown() and not GrowReady() then return end
    local frame = ProfessionsFrame
    if on then ns.SetLevelIf(shape, math.max(0, frame:GetFrameLevel() - 1)) end
    if shape.grown == on then return end
    shape.grown = on
    ns.SetPointOnce(shape, "TOPLEFT", frame, "TOPLEFT", 0, 0)
    if on then
        shape:SetSize(BookW(), BookH())
    else
        shape:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    end
    shape:EnableMouse(on)
    for _, tex in ipairs(shape.art) do
        if on then Mirror(tex, frame) end
        tex:SetShown(on and tex.from:IsShown())
    end
end

-- Shut: sized for how it may open in a fight, where it can't be resized.
-- Shut, the book's size with ours on: a fight cannot resize it and the book is what opens in one (his pick, 2026-11-24:
-- at trade skill size the book stood in an empty double pane); a trade skill opened in a fight overhangs till it ends.
local function SizeShut(_, tradeOn)
    if active then
        FitWindow(BookW(), BookH())
    elseif tradeOn then
        FitWindow(ns.TradeSkillWindowSize())
    end
end
T.SizeShut = SizeShut

-- The portrait as the page up: the professions icon on the book, the open profession's on its page. Held each pass
-- of the watch: the client paints its own on its events, which left the last profession's or the book's up a while.
-- book nil: read from the page (a craft's list update while on the book swapped it every craft).
local BOOK_ICON = "Interface/ICONS/INV_SideTab_Professions_c60"
local portraitSet, portraitWanted   -- the icon we last put there, as a file id and as asked
function ns.ProfessionPortrait(book)
    local frame = ProfessionsFrame
    local portrait = frame and frame.PortraitContainer and frame.PortraitContainer.portrait
    if not portrait then return end
    if book == nil then
        local page = Page()
        book = active and page ~= nil and page:IsVisible()
    end
    local icon = BOOK_ICON
    if not book then
        local api = C_TradeSkillUI
        local info = api and api.GetBaseProfessionInfo and api.GetBaseProfessionInfo()
        icon = info and info.professionID and api.GetTradeSkillTexture and api.GetTradeSkillTexture(info.professionID)
        if not icon then return end
    end
    local now = portrait:GetTextureFileID()
    if now ~= nil and now == portraitSet and portraitWanted == icon then return end
    portrait:SetTexture(icon)
    portraitSet, portraitWanted = portrait:GetTextureFileID(), icon
end

-- Turn to the crafting page piece by piece: the client turns only when the
-- profession changes, so First Aid, shut, First Aid again left the book up.
local function ToCraft()
    local frame, page = ProfessionsFrame, Page()
    local crafting = frame and frame.CraftingPage
    if not frame or not page or not crafting or InCombatLockdown() then return false end
    if not page:IsShown() and crafting:IsShown() then return true end
    page:Hide()
    crafting:Show()
    local info = C_TradeSkillUI and C_TradeSkillUI.GetBaseProfessionInfo and C_TradeSkillUI.GetBaseProfessionInfo()
    local id = info and info.professionID
    local title = frame.TitleContainer and frame.TitleContainer.TitleText
    if title and info and info.professionName and info.professionName ~= "" then title:SetText(info.professionName) end
    ns.ProfessionPortrait()
    local overview = frame.ProfessionsOverviewTab
    if overview and overview.SelectedTexture then overview.SelectedTexture:Hide() end
    for _, tab in ipairs(frame.rightProfessionTabs or EMPTY) do
        if tab.SelectedTexture then tab.SelectedTexture:SetShown(id ~= nil and tab.skillLine == id) end
    end
    return true
end

-- Opened from the spellbook's tab via ShowUIPanel so it shows in the client's
-- name; refused to addons in combat.
function ns.OpenProfessionsBook()
    -- Retail's book is a window of its own: the tab's pad presses the game's own opener.
    if not ns.OnForever() then return false end
    if InCombatLockdown() then ns.SayNotInCombat() return false end
    if not ProfessionsFrame and C_AddOns and C_AddOns.LoadAddOn then
        pcall(C_AddOns.LoadAddOn, "Blizzard_ProfessionsBook")
        pcall(C_AddOns.LoadAddOn, "Blizzard_Professions")
    end
    local frame = ProfessionsFrame
    if not frame then return false end
    -- Book size before it shows.
    if active then FitWindow(BookW(), BookH()) end
    BackToBook()
    if not frame:IsShown() then
        MarkBookAsked()
        ns.ShowPanel(frame)
    end
    return true
end

-- ADDON_LOADED: the client loaded the window itself (asked early, or a session begun in combat): the watch takes it.
local WATCH_EVENTS = { "SKILL_LINES_CHANGED", "SPELLS_CHANGED", "PLAYER_REGEN_ENABLED", "TRADE_SKILL_SHOW", "ADDON_LOADED" }

-- Watched from a frame of our own, never hooked into the client's page.
local watch

-- The shut gate's one writer (R8): pending asks for full passes while shut until one completes.
local function SetPending(on)
    if not watch then return end
    watch.pending = on
    if on then watch:Show() end
end

-- Our child under the window runs only while it is visible: wakes the sleeping watch on the frame it shows.
local function EnsureOpenHost(frame)
    if watch.openHost or not frame then return end
    watch.openHost = ns.Sched.Attach(frame, { name = "professions.open", every = 0, fn = function()
        if watch:IsShown() then return end
        watch:Show()
        local tick = watch:GetScript("OnUpdate")
        if tick then tick(watch, 0) end
    end })
    -- A craft's refresh (a disenchant cast) paints its profession on the portrait, book page up too: ours back in the
    -- same breath, not at the watch's next pass (the icon flickered to Enchanting on every cast).
    ns.HookMethod(frame, "SetPortraitToAsset", function()
        if active then ns.ProfessionPortrait() end
    end)
end

local function NoteShown(w, bookShown)
    local frame = ProfessionsFrame
    ns.Persist(string.format("professions: shown, book %s, %dx%d, placed %s, combat %s, grown %s", tostring(bookShown),
        frame:GetWidth() or 0, frame:GetHeight() or 0, tostring(w.placedNow), tostring(InCombatLockdown()),
        tostring(shape and shape.grown)))
end

-- Lockdown is not yet set while this dispatches: the last out-of-combat chance to size the shut window.
local function FightStart()
    local frame = ProfessionsFrame
    if not frame or frame:IsShown() then return end
    SetPending(true)
    local tick = watch:GetScript("OnUpdate")
    if tick then
        watch.since = 1
        tick(watch, 0)
    end
end

-- Every frame the watch is awake: whether the window is shut, on which face, and the turns that follow.
local function FaceTick(self, now)
    -- First, so the face read below is the book before this frame draws.
    if self.restoreBook and BackToBook() then self.restoreBook = false end
    -- Every frame: whether the window is shut, and on which face.
    local shut = ProfessionsFrame and not ProfessionsFrame:IsShown()
    local book = Page()
    -- A face turned (a cast, a tab): full pass now, so size and chrome follow.
    local bookShown = book and book:IsShown() or false
    if bookShown ~= self.bookShown then
        self.bookShown = bookShown
        self.since = 1
        SetPending(true)
    end
    if shut then
        -- A never-opened window opens on the book, though its page starts hidden.
        local castNow = (now - (self.ownCastAt or 0)) < 3
        local wasBook = self.bookWhenShut
        self.bookWhenShut = (book and book:IsShown() or (not self.everShown and not castNow)) and true or false
        -- Shut on a crafting page, or never opened (preloaded, it came up blank at book size): back to the book for micro button and key.
        -- Not within 3 s of a trade skill opening while shut (castNow): the player's cast shows a beat later and would be lost.
        if active and book and not book:IsShown() and not InCombatLockdown() and not castNow then
            if BackToBook() then
                self.bookWhenShut = true
                ns.Persist("professions: shut window turned to the book")
            end
        end
        -- The shut size follows the opening face.
        if self.bookWhenShut ~= wasBook then SetPending(true) end
    elseif ProfessionsFrame then
        if ns.debugSink and (not self.everShown or self.wasShut) then NoteShown(self, bookShown) end
        self.everShown = true
        self.ownCastAt = nil
    end
    -- Full pass on the frame the window appears, so ours is laid before it draws,
    -- and the frame it shuts, so it has its fight size before one can start.
    if self.wasShut ~= (shut and true or false) then
        self.since = 1
        SetPending(true)
    end
    self.wasShut = shut and true or false
    -- A profession just asked for, turned to if the client has not.
    if self.wantCraft then
        if now - self.wantCraft > 3 then
            self.wantCraft = nil
        elseif active and ProfessionsFrame and not self.restoreBook and ToCraft() then
            if ProfessionsFrame:IsShown() then self.wantCraft = nil end
        end
    end
    return shut
end

-- The watch itself: the face read every frame awake, the full pass on its gates; asleep while shut and settled.
local placed = false
local function WatchTick(self, elapsed)
    -- GetTime is constant within a frame; read once.
    local now = GetTime()
    local shut = FaceTick(self, now)
    self.since = (self.since or 0) + elapsed
    -- Shut and settled: asleep till an event, the window showing (open host) or a pending pass wakes it.
    if shut and not self.dirty and not self.pending then
        if not self.wantCraft and not self.restoreBook and now - (self.ownCastAt or 0) >= 3 then self:Hide() end
        return
    end
    -- Shut and pending: 2 Hz.
    if self.since < ((shut and not self.dirty) and 0.5 or 0.1) then return end
    self.since = 0
    -- Load the window ourselves, once, out of combat at the first chance: first
    -- loaded in combat it came up as the client's (a session begun in combat has
    -- only its first moments).
    if not ProfessionsFrame and not self.loadTried and not InCombatLockdown()
        and (active or (ns.TradeSkillActive and ns.TradeSkillActive())) then
        if C_AddOns and C_AddOns.LoadAddOn then
            self.loadTried = true
            local okBook, bookLoaded = pcall(C_AddOns.LoadAddOn, "Blizzard_ProfessionsBook")
            local okMain, main = pcall(C_AddOns.LoadAddOn, "Blizzard_Professions")
            if ns.debugSink then
                ns.Persist(string.format("professions: early load book %s/%s main %s/%s frame %s", tostring(okBook),
                    tostring(bookLoaded), tostring(okMain), tostring(main), tostring(ProfessionsFrame ~= nil)))
            end
        end
    end
    local frame = ProfessionsFrame
    local page = Page()
    -- Not loaded yet: asleep till its ADDON_LOADED.
    if not frame or not page then
        if self.loadTried or not active then self:Hide() end
        return
    end
    EnsureOpenHost(frame)
    if active then FillTabIcons() end
    -- By face: book, trade skill, or the client's own when neither module is on.
    local bookUp = active and page:IsVisible() and true or false
    local crafting = frame.CraftingPage
    local tradeOn = ns.TradeSkillActive and ns.TradeSkillActive()
    local craftUp = not bookUp and tradeOn and crafting and crafting:IsVisible() and true or false
    SizeButton(bookUp, craftUp)
    local trade = ns.tradeDual.On() and "tradeDual" or "trade"
    if active then T.PrepareEraFrames() end
    T.EraFrame(bookUp and "book" or craftUp and trade or nil)
    if craftUp then KeepSwitchLeft(frame, trade) end
    T.Zoom(T.Big() and not craftUp)
    if bookUp or craftUp then ns.ProfessionPortrait(bookUp) end
    T.SyncBookPads()
    SyncTabs()
    T.BookTabs()
    if active then EnsureShape(frame) end
    Home(frame)
    if bookUp then
        -- Refused in a fight: grown past the window instead.
        FitWindow(BookW(), BookH())
        Grow(Smaller(frame, BookW(), BookH()))
    else
        Grow(false)
        if craftUp then
            FitWindow(ns.TradeSkillWindowSize())
        elseif frame:IsVisible() then
            FitWindow(nil)
        else
            SizeShut(self, tradeOn)
        end
    end
    if ns.ShowTradeSkill then ns.ShowTradeSkill(craftUp) end
    -- One page of the book at a time: a trade skill opened from the action bar shuts the spellbook, as its own press does.
    local book = _G.ForeverClassicUISpellBook
    if craftUp and book and book:IsShown() and book:GetAlpha() > 0 and ns.HideSpellBook then ns.HideSpellBook() end
    -- Build and place as soon as the window exists, open or not: impossible once combat starts.
    if active then
        if not T.built then Build() end
        if T.built and (self.dirty or not placed) then
            local was = placed
            placed = PlaceCards() or placed
            if placed ~= was and ns.debugSink then ns.Persist("professions: cards placed, combat " .. tostring(InCombatLockdown())) end
            FillRows()
            self.dirty = false
        end
        self.placedNow = placed
        ShowOurs(placed)
        if placed then
            TightenSpells()
            KeepSpellSpots()
            T.Preload()
        end
    end
    SetPending(false)
end

-- Starts the watch; a running one takes a full pass for the module that turned on.
local function StartWatch()
    if watch then
        SetPending(true)
        return
    end
    watch = CreateFrame("Frame")
    T.watch = watch
    ns.RegisterEvents(watch, WATCH_EVENTS)
    -- Opened by micro button, key or our spellbook tab, the window recasts the profession picked last as it shows: that trade
    -- skill gets the book back. Any other is the player's cast and stays.
    watch:SetScript("OnEvent", function(self, event)
        self:Show()
        if event == "ADDON_LOADED" then return end
        if event == "TRADE_SKILL_SHOW" then
            local frame = ProfessionsFrame
            local now = GetTime()
            -- Opened inside our book opener's click: the window's own recast. Out of combat, where the book can turn.
            local recast = now - (T.bookAskedAt or 0) < 0.1
            if recast and active and frame and frame:IsShown() and not InCombatLockdown() then
                self.restoreBook = true
            else
                self.ownCastAt = now
                self.wantCraft = now
                -- Turn, size and dress now, not next tick: the window shows this instant and
                -- stood as the book for that tick.
                if active and frame and ToCraft() then
                    -- The window may not count as shown yet: past the shut gate.
                    SetPending(true)
                    local tick = self:GetScript("OnUpdate")
                    if tick then
                        self.since = 1
                        tick(self, 0)
                    end
                end
            end
        end
        self.dirty = true
        -- The client's book refills on these (a craft's skill-up too), its spells back at its spots; at a fight's end
        -- another addon's window restore has the manager re-place it on the client's spot: our pass this frame, before
        -- it draws, not up to a tenth later.
        if event ~= "TRADE_SKILL_SHOW" and (self.bookShown or event == "PLAYER_REGEN_ENABLED")
            and ProfessionsFrame and ProfessionsFrame:IsVisible() then
            self.since = 1
        end
    end)
    ns.Sched.OnFrame(watch, { name = "professions.watch", every = 0, fn = function(_, since) WatchTick(watch, since) end })
    local fightStart = CreateFrame("Frame")
    fightStart:RegisterEvent("PLAYER_REGEN_DISABLED")
    fightStart:SetScript("OnEvent", FightStart)
end
ns.StartProfessionsWatch = StartWatch

local function Apply()
    active = true
    -- Retail's book is its own window with no faces to turn: its driver (Skills/ProfessionsBookRetail.lua).
    if not ns.OnForever() then
        T.RetailBook(true, SizeButton)
        return
    end
    StartWatch()
    -- Three passes now: load, turn to the book and size, settle.
    local tick = watch and watch:GetScript("OnUpdate")
    if tick then
        for _ = 1, 3 do
            watch.since = 1
            SetPending(true)
            tick(watch, 0)
        end
        watch.since = 1
        SetPending(true)
        if ns.debugSink then
            ns.Persist(string.format("professions: first pass, fight %s, window %s", tostring(InCombatLockdown()), tostring(ProfessionsFrame ~= nil)))
        end
    end
end

local function Restore()
    if not active then return end
    active = false
    ns.needsReload = true
    if not ns.OnForever() then
        T.RetailBook(false, SizeButton)
        return
    end
    SetPending(true)
end

ns.RegisterModule("professionsBook", { apply = Apply, restore = Restore })

-- Only their alpha changes: at once, in a fight too.
ns.OnToggle(function(key)
    if key == "professionTabs" or key == "professionTabsHover" or key == "professionTabsHidden" then SyncTabs() end
end)

-- The page size or its art switched (options or popout): rows now, cards and window on the watch's next pass (out of combat).
ns.OnToggle(function(key)
    if key ~= "profBookBig" and key ~= "profBookBands" then return end
    if T.Lay then T.Lay() end
    if watch then
        watch.dirty = true
        SetPending(true)
        watch:Show()
    end
end)
