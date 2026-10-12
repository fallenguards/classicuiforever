local _, ns = ...
local L = ns.L

-- The old talent window, shared by the talents and Legacy windows: title, X, points-spent bar, the tree scrolling on
-- Era's background (buttons, rank plates, branches, arrows), the foot (undo, points left, Apply) and foot tabs.
-- A click stages, Apply commits; each window reads its own tree and hands it to ns.DrawTalentTab.

local IsSecret = ns.IsSecret

local WINDOW_W, WINDOW_H = 384, 512
local VIEW_X, VIEW_Y, VIEW_W, VIEW_H = 22, -77, 296, 332
local BUTTON, START_X, START_Y, PITCH = 37, 35, 20, 63
-- The foot's undo spot, points box and its text.
local RESET_X, RESET_Y = 17, 101
local POINTS_BOX_W, POINTS_BOX_H, POINTS_TEXT_X = 196, 24, -10
local ART = "Interface\\TalentFrame\\"
local BRANCHES, ARROWS = ART .. "UI-TalentBranches", ART .. "UI-TalentArrows"
-- The X: its centre from the window's top right.
local CLOSE_X, CLOSE_Y, CLOSE_SIZE = -46, -24, 32

-- The branch sheet: a lit row of pieces over a grey one.
local BRANCH = {
    vertical = { [true] = { 0, 0.125, 0, 0.484375 }, [false] = { 0, 0.125, 0.515625, 1 } },
    horizontal = { [true] = { 0.2578125, 0.3828125, 0, 0.5 }, [false] = { 0.2578125, 0.3828125, 0.5, 1 } },
}
-- Keyed by the way the arrow points (Era names them by the side they sit on: its "right" points left).
local ARROW = {
    down = { [true] = { 0, 0.5, 0, 0.5 }, [false] = { 0, 0.5, 0.5, 1 } },
    right = { [true] = { 0.5, 1, 0, 0.5 }, [false] = { 0.5, 1, 0.5, 1 } },
    left = { [true] = { 1, 0.5, 0, 0.5 }, [false] = { 1, 0.5, 0.5, 1 } },
}

-- The talent sheet's top pieces are gone from this client; the character
-- window's general top is the same art.
local TALENT_QUARTERS = {
    { key = "charGeneralTopLeft", layer = "BORDER", w = 256, h = 256, point = "TOPLEFT" },
    { key = "charGeneralTopRight", layer = "BORDER", w = 128, h = 256, point = "TOPRIGHT" },
    { set = "file", key = ART .. "UI-TalentFrame-BotLeft", layer = "BORDER", w = 256, h = 256, point = "BOTTOMLEFT" },
    { set = "file", key = ART .. "UI-TalentFrame-BotRight", layer = "BORDER", w = 128, h = 256, point = "BOTTOMRIGHT" },
}
-- The skill bars' rim cut in three, so its round ends keep their shape at any length.
local CAP = 14
local RIM = { layer = "ARTWORK", key = "skillsBarBorder", cap = CAP, ox = 5, oy = 5,
    coords = { { 0, CAP / 256, 0, 1 }, { CAP / 256, 1 - CAP / 256, 0, 1 }, { 1 - CAP / 256, 1, 0, 1 } } }
-- Both sheets are 128 x 32; the picked face stands 4 higher and opens the window's foot, as 1.x's tabs did.
local FOOT_COORDS = { { 0, 0.15625, 0, 1 }, { 0.15625, 0.84375, 0, 1 }, { 0.84375, 1, 0, 1 } }
-- The shared tab faces: one spot for both (a 4 lower unpicked face left a gap to the frame), the shared height.
local FOOT_ON = { layer = "BACKGROUND", key = "tabActive", cap = 20, height = 32, oy = ns.TAB_PICKED_Y, middle = "edge",
    coords = FOOT_COORDS }
local FOOT_OFF = { layer = "BACKGROUND", key = "tabInactive", cap = 20, height = 32, oy = ns.TAB_OFF_Y, middle = "edge",
    coords = FOOT_COORDS }
local RESET_TIP = { text = function() return TALENT_FRAME_RESET_BUTTON_TOOLTIP_TITLE or "Reset Pending Changes" end }
local WORD_EVENTS = { "TOOLTIP_DATA_UPDATE" }
local TABS = 3

--------------------------------------------------------------- the pieces

-- Pieces are handed out in pool order and all taken back at once.
local function Acquire(pool, parent, file)
    local n = (pool.n or 0) + 1
    pool.n = n
    local tex = pool[n]
    if not tex then
        tex = parent:CreateTexture(nil, "ARTWORK")
        tex:SetTexture(file)
        pool[n] = tex
    end
    return tex
end

local function ReleaseAll(pool)
    for _, tex in ipairs(pool) do tex:Hide() end
    pool.n = 0
end

-- A view's cells (the window's one tree, or a pane of the three: UI/TalentTrees.lua): view.geo is the first's top left
-- in it, then the pitch across and down.
local GEO = { START_X, START_Y, PITCH, PITCH }
local function CellX(view, column) return view.geo[1] + column * view.geo[3] end
local function CellY(view, tier) return -(view.geo[2] + tier * view.geo[4]) end

local function BranchPiece(frame, lit, kind, x, y, w, h)
    local child = frame.child
    local tex = Acquire(frame.branchPool, child, BRANCHES)
    tex:SetTexCoord(unpack(BRANCH[kind][lit]))
    ns.SetPointOnce(tex, "TOPLEFT", child, "TOPLEFT", x, y)
    tex:SetSize(w, h)
    tex:Show()
end

local function BranchArrow(frame, lit, kind, x, y)
    local tex = Acquire(frame.arrowPool, frame.arrows, ARROWS)
    tex:SetTexCoord(unpack(ARROW[kind][lit]))
    ns.SetPointOnce(tex, "TOPLEFT", frame.child, "TOPLEFT", x, y)
    tex:SetSize(32, 32)
    tex:Show()
end

-- A run of branch between two places, and the arrow into the second.
local function DrawEdge(frame, from, to, lit)
    local fx, fy, tx, ty = CellX(frame, from.column), CellY(frame, from.tier), CellX(frame, to.column), CellY(frame, to.tier)
    local half = BUTTON / 2
    if from.tier == to.tier then
        -- Along the row.
        local right = to.column > from.column
        local x1 = (right and fx + BUTTON or tx + BUTTON) - 2
        local x2 = (right and tx or fx) + 2
        BranchPiece(frame, lit, "horizontal", x1, fy - half + 16, math.max(1, x2 - x1), 32)
        BranchArrow(frame, lit, right and "right" or "left", right and (tx - 20) or (tx + BUTTON - 12), ty - half + 16)
    else
        -- Across first where the columns differ, then down.
        if from.column ~= to.column then
            local right = to.column > from.column
            local x1 = right and (fx + BUTTON - 2) or (tx + half - 16)
            local x2 = right and (tx + half + 16) or (fx + 2)
            BranchPiece(frame, lit, "horizontal", x1, fy - half + 16, math.max(1, x2 - x1), 32)
            BranchPiece(frame, lit, "vertical", tx + half - 16, fy - half, 32, math.max(1, (fy - half) - ty - 2))
        else
            BranchPiece(frame, lit, "vertical", tx + half - 16, fy - BUTTON + 2, 32, math.max(1, (fy - BUTTON) - ty + 4))
        end
        BranchArrow(frame, lit, "down", tx + half - 16, ty + 20)
    end
end

-- Old tooltip: name, rank, unmet needs in red, rank text, then "Next rank".
-- Text goes in as plain lines: passed as tooltip data, the client later redrew
-- the tooltip from that data alone and dropped the rest.
local function AddDescription(entryID, rank)
    if not (entryID and C_TooltipInfo and C_TooltipInfo.GetTraitEntry) then return false end
    local ok, data = pcall(C_TooltipInfo.GetTraitEntry, entryID, rank)
    if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then return false end
    for _, line in ipairs(data.lines) do
        local text, right = line.leftText, line.rightText
        if type(text) == "string" and text ~= "" and not IsSecret(text) then
            local color = line.leftColor
            local r, g, b = color and color.r or 1, color and color.g or 0.82, color and color.b or 0
            if type(right) == "string" and right ~= "" and not IsSecret(right) then
                -- A line in two halves: "Instant" and "3 min cooldown".
                local other = line.rightColor
                GameTooltip:AddDoubleLine(text, right, r, g, b, other and other.r or 1, other and other.g or 1, other and other.b or 1)
            else
                GameTooltip:AddLine(text, r, g, b, line.wrapText ~= false)
            end
        end
    end
    return true
end

-- Talent text can arrive late: rewrite on TOOLTIP_DATA_UPDATE, registered only
-- while a talent tooltip can be up. One listener for every window: one tooltip shows at a time.
local words, hovered
local wordsOn = false
local Button_OnEnter
local function HearWords(on)
    if wordsOn == on then return end
    if on then
        if not words then
            words = CreateFrame("Frame")
            words:SetScript("OnEvent", function(self)
                local button = hovered
                if not button or not button.window:IsShown() or not GameTooltip:IsOwned(button) then return end
                local now = GetTime()
                if self.last and now - self.last < 0.2 then return end
                self.last = now
                Button_OnEnter(button)
            end)
        end
        wordsOn = ns.RegisterEvents(words, WORD_EVENTS) > 0
    elseif words then
        wordsOn = false
        words:UnregisterEvent("TOOLTIP_DATA_UPDATE")
    end
end

-- Unmet needs, in red: points in the tree first, then the talent it hangs from, which has to be full.
local function AddNeeds(talent, tree, tab)
    for _, condID in ipairs(talent.conditions) do
        local ok, cond = pcall(C_Traits.GetConditionInfo, tree.configID, condID)
        if ok and cond and cond.isGate and not cond.isMet and cond.spentAmountRequired then
            GameTooltip:AddLine(string.format(TOOLTIP_TALENT_TIER_POINTS or "Requires %d points in %s Talents",
                cond.spentAmountRequired, tab and tab.name or ""), 1, 0.1, 0.1, true)
        end
    end
    for _, other in pairs(tree.nodesByID) do
        for _, edge in ipairs(other.edges) do
            if edge.targetNode == talent.nodeID and edge.type ~= 0 and other.rank < other.maxRank then
                local otherName = other.spellID and C_Spell.GetSpellName(other.spellID) or "?"
                local format = TOOLTIP_TALENT_PREREQ or (other.maxRank == 1 and L["SKILL_REQUIRES_N_POINT_IN_X"] or L["SKILL_REQUIRES_N_POINTS_IN_X"])
                GameTooltip:AddLine(string.format(format, other.maxRank, otherName), 1, 0.1, 0.1, true)
            end
        end
    end
end

Button_OnEnter = function(self)
    local talent, window = self.talent, self.window
    local tree = window and window.tree
    if not talent or not tree then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local name = talent.spellID and C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(talent.spellID)
    hovered = self
    HearWords(true)
    if not name or not (C_TooltipInfo and C_TooltipInfo.GetTraitEntry) then
        -- A client without the talent text: the spell's own tooltip.
        if talent.spellID and GameTooltip.SetSpellByID then GameTooltip:SetSpellByID(talent.spellID) end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(string.format(TOOLTIP_TALENT_RANK or "Rank %d/%d", talent.rank, talent.maxRank), 1, 1, 1)
    else
        GameTooltip:SetText(name, 1, 1, 1)
        GameTooltip:AddLine(string.format(TOOLTIP_TALENT_RANK or "Rank %d/%d", talent.rank, talent.maxRank), 1, 1, 1)
        AddNeeds(talent, tree, window.tab)
        AddDescription(talent.entryID, math.max(talent.rank, 1))
        if talent.rank > 0 and talent.rank < talent.maxRank then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(TOOLTIP_TALENT_NEXT_RANK or "Next rank:", 1, 1, 1)
            AddDescription(talent.entryID, talent.rank + 1)
        end
    end
    if talent.canBuy and not tree.inspect then
        GameTooltip:AddLine(TOOLTIP_TALENT_LEARN or "Click to learn", 0.1, 1, 0.1)
    end
    GameTooltip:Show()
end

local function Button_OnLeave(self)
    if hovered == self then hovered = nil end
    GameTooltip:Hide()
    HearWords(false)
end

local function Button_OnClick(self, mouse)
    local talent, window = self.talent, self.window
    local tree = window.tree
    -- Shift-click links it in chat, in a fight and on an inspected tree too, as the game's window does.
    if talent and talent.spellID and mouse == "LeftButton" and IsModifiedClick("CHATLINK") then
        -- Into a macro: the spell's name as text, no rank (a link there is no spell to /cast, #124); never a passive.
        local macro = _G.MacroFrameText
        if macro and macro:HasFocus() then
            local name, passive = C_Spell.GetSpellName(talent.spellID), C_Spell.IsSpellPassive(talent.spellID)
            if IsSecret(passive) then passive = false end
            if not passive and type(name) == "string" and not IsSecret(name) then ChatFrameUtil.InsertLink(name) end
            return
        end
        local link = C_Spell.GetSpellLink(talent.spellID)
        if link and not IsSecret(link) then ChatFrameUtil.InsertLink(link) end
        return
    end
    if not talent or not tree or tree.inspect or InCombatLockdown() then return end
    if mouse == "RightButton" then
        if talent.canRefund then pcall(C_Traits.RefundRank, tree.configID, talent.nodeID) end
    elseif talent.canBuy then
        pcall(C_Traits.PurchaseRank, tree.configID, talent.nodeID)
    end
    window.spec.refresh()
    if GameTooltip:IsOwned(self) then Button_OnEnter(self) end
end

local function TalentButton(frame, index)
    local button = frame.buttons[index]
    if button then return button end
    button = ns.NewFrame("Button", nil, frame.child)
    button.window = frame
    button:SetSize(BUTTON, BUTTON)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button.icon = button:CreateTexture(nil, "BORDER")
    button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
    button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    -- A filled square under the icon: only its edge shows, tinted by state.
    button.slot = button:CreateTexture(nil, "BACKGROUND")
    button.slot:SetTexture("Interface\\Buttons\\UI-EmptySlot-White")
    button.slot:SetSize(64, 64)
    button.slot:SetPoint("CENTER", button, "CENTER", 0, -1)
    button.rankBorder = button:CreateTexture(nil, "OVERLAY")
    button.rankBorder:SetTexture(ART .. "TalentFrame-RankBorder")
    button.rankBorder:SetSize(32, 32)
    button.rankBorder:SetPoint("CENTER", button, "BOTTOMRIGHT", -2, 2)
    button.rankText = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.rankText:SetPoint("CENTER", button.rankBorder, "CENTER", 0, 0)
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    highlight:SetBlendMode("ADD")
    highlight:SetAllPoints(button.icon)
    button:SetScript("OnEnter", Button_OnEnter)
    button:SetScript("OnLeave", Button_OnLeave)
    button:SetScript("OnClick", Button_OnClick)
    frame.buttons[index] = button
    return button
end

-- Buttons made ahead, hidden (the gamepad's read of a hosted window finds them all).
function ns.TalentButtons(frame, count)
    for i = 1, count do TalentButton(frame, i):Hide() end
end

-- One tab face as a list: its three pieces and, named by face, its hover glow (the picked face has none: 1.x
-- disabled the picked tab).
local function FootFace(tab, spec, face)
    local left, middle, right = ns.ThreeSlice(tab, nil, spec)
    for i, piece in ipairs({ left, middle, right }) do ns.LengthenTabPiece(piece, FOOT_COORDS[i][1], FOOT_COORDS[i][2], spec.oy) end
    return { left, middle, right, face and ns.TabGlow(tab, face, spec, left, middle, ns.TabPieceFoot(right)) or nil }
end

local function SetFootTab(self, text, picked)
    if self.text ~= text then
        self.text = text
        self.label:SetText(text)
        self:SetWidth(math.ceil(self.label:GetStringWidth() or 0) + 40)
    end
    if self.picked ~= picked then
        self.picked = picked
        for _, tex in ipairs(self.on) do ns.ShowTabPiece(tex, picked) end
        for _, tex in ipairs(self.off) do ns.ShowTabPiece(tex, not picked) end
        self:SetNormalFontObject(picked and "GameFontHighlightSmall" or "GameFontNormalSmall")
    end
end

-- Our own foot tab: the client template resizes and moves its tabs on every
-- pick (it cut ours to "B...").
local function FootTab(parent)
    local tab = ns.NewFrame("Button", nil, parent)
    tab:SetHeight(32)
    tab.on = FootFace(tab, FOOT_ON)
    tab.off = FootFace(tab, FOOT_OFF, "glowOff")
    -- One point and no width: the label is always its whole text.
    tab.label = tab:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    -- One spot, picked or not: the shared tab label height.
    tab.label:SetPoint("CENTER", tab, "CENTER", 0, ns.TabTextY())
    -- The button's own label: white on hover and picked, gold otherwise, as 1.x.
    tab:SetFontString(tab.label)
    tab:SetNormalFontObject("GameFontNormalSmall")
    tab:SetHighlightFontObject("GameFontHighlightSmall")
    tab.Set = SetFootTab
    return tab
end

--------------------------------------------------------------- the window

-- Frame, art, portrait, title and X.
local function BuildShell(name, spec)
    local frame = CreateFrame("Frame", name, UIParent)
    frame.spec = spec
    frame.buttons, frame.branchPool, frame.arrowPool = {}, {}, {}
    frame:SetSize(WINDOW_W, WINDOW_H)
    frame:SetFrameStrata("MEDIUM")
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    -- Era's margins: past the art the world takes the mouse.
    frame:SetHitRectInsets(0, 30, 0, 45)
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", ns.ClassicSlot())
    frame:Hide()
    -- Hosted, the game's window places and closes it; otherwise our window handles move it.
    if not spec.hosted then ns.CloseWithGameMenu(frame) end

    frame.quarters = ns.DressPieces(frame, TALENT_QUARTERS, nil, true)

    local portrait = frame:CreateTexture(nil, "BACKGROUND")
    portrait:SetSize(60, 60)
    portrait:SetPoint("TOPLEFT", frame, "TOPLEFT", 7, -6)
    frame.portrait = portrait

    local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    -- In its bar 24 down, from the top: a taller window (the three trees) keeps it there.
    title:SetPoint("CENTER", frame, "TOP", 6, -24)
    frame.title = title

    local close = ns.NewFrame("Button", nil, frame)
    -- Sized after the skin, which sets the stock 32.
    ns.SkinCloseButton(close, true)
    close:SetSize(CLOSE_SIZE, CLOSE_SIZE)
    close:SetPoint("CENTER", frame, "TOPRIGHT", CLOSE_X, CLOSE_Y)
    close:SetScript("OnClick", function() frame:Hide() end)
    frame.close = close
    -- A secure pad over it: a fight's Escape binding (UI/Escape.lua) is let go in the same click.
    if ns.EscDisarmOnClick and not spec.hosted then
        ns.EscDisarmOnClick(ns.MapPad(close, "DIALOG", function() frame:Hide() end, ""))
    end
    return frame
end

-- A dark bar with the skill bars' old round-ended grey rim and a label in its middle (bar.text).
local function RimBar(parent)
    local bar = ns.NewFrame("Frame", nil, parent)
    bar:SetHeight(13)
    local back = bar:CreateTexture(nil, "BACKGROUND")
    back:SetColorTexture(0, 0, 0, 0.6)
    back:SetPoint("TOPLEFT", bar, "TOPLEFT", 1, 0)
    back:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -1, 0)
    ns.ThreeSlice(bar, nil, RIM)
    bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bar.text:SetPoint("CENTER", bar, "CENTER", 0, 0)
    return bar
end

-- A tree in a view that scrolls, on Era's background with its scroll bar beside it, filled into view (the window, or
-- a pane of the three: UI/TalentTrees.lua); placed by the caller through view.scroll.
local function TreeView(view)
    view.geo = GEO
    view.buttons, view.branchPool, view.arrowPool = view.buttons or {}, view.branchPool or {}, view.arrowPool or {}
    local scroll = ns.NewFrame("ScrollFrame", nil, view)
    scroll:SetSize(VIEW_W, VIEW_H)
    scroll:EnableMouseWheel(true)
    local child = ns.NewFrame("Frame", nil, scroll)
    child:SetSize(VIEW_W, VIEW_H)
    scroll:SetScrollChild(child)
    view.scroll, view.child = scroll, child
    -- The arrows stand over the talents they point into.
    view.arrows = ns.NewFrame("Frame", nil, child)
    view.arrows:SetAllPoints(child)
    view.arrows:SetFrameLevel(child:GetFrameLevel() + 5)

    local background = {}
    for _, key in ipairs({ "TopLeft", "TopRight", "BottomLeft", "BottomRight" }) do
        background[key] = child:CreateTexture(nil, "BACKGROUND")
    end
    background.TopLeft:SetPoint("TOPLEFT", child, "TOPLEFT", 0, 0)
    background.TopRight:SetPoint("TOPLEFT", background.TopLeft, "TOPRIGHT", 0, 0)
    background.BottomLeft:SetPoint("TOPLEFT", background.TopLeft, "BOTTOMLEFT", 0, 0)
    background.BottomRight:SetPoint("TOPLEFT", background.TopLeft, "BOTTOMRIGHT", 0, 0)
    view.background = background

    view.bar = ns.ClassicScrollBar(view, scroll, function(value) scroll:SetVerticalScroll(value or 0) end)
    ns.ScrollColumnOn(view.bar)
    scroll:SetScript("OnMouseWheel", function(_, delta)
        view.bar:SetValue((view.bar:GetValue() or 0) - delta * 30)
    end)
    return view
end

-- Points spent on the rimmed bar, and the tree in a window that scrolls.
local function BuildView(frame)
    local spentBar = RimBar(frame)
    spentBar:SetWidth(258)
    spentBar:SetPoint("TOP", frame, "TOP", 12, -48)
    frame.spentBar, frame.spent = spentBar, spentBar.text
    TreeView(frame)
    frame.scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", VIEW_X, VIEW_Y)
end

-- Foot: undo, points-left box, Apply Changes, fixed sizes so nothing moves when
-- a point is staged; buttons grey until needed; Escape and the X close. The old
-- art's painted points box is covered with stone.
local function BuildFoot(frame, spec)
    local foot = ns.NewFrame("Frame", nil, frame)
    frame.foot = foot
    -- From the window's foot (Era's 409 and 435 down of 512), to the border's inner edge, 44 in from the right in the old
    -- art; 352 ran past the window's side.
    foot:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 14, 103)
    foot:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -44, 77)
    local footStone = foot:CreateTexture(nil, "BACKGROUND")
    footStone:SetAllPoints(foot)
    ns.TileTex(footStone, "rockBg")

    -- Undo and Apply at opposite ends: side by side, a slip undid points meant to be applied.
    frame.reset = ns.PanelButton(foot, "", 28)
    frame.reset:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", RESET_X, RESET_Y)
    -- The arrow, small enough to sit inside the button with room round it.
    local undo = frame.reset:CreateTexture(nil, "OVERLAY")
    undo:SetSize(13, 13)
    undo:SetPoint("CENTER", frame.reset, "CENTER", 0, 0)
    if not (undo.SetAtlas and pcall(undo.SetAtlas, undo, "talents-button-undo")) or not undo:GetAtlas() then
        ns.SetFile(undo, "Interface/Buttons/UI-RotationLeft-Button-Up")
    end
    frame.undoIcon = undo
    frame.reset:SetScript("OnClick", function()
        local tree = frame.tree
        if tree and C_Traits.RollbackConfig then pcall(C_Traits.RollbackConfig, tree.configID) end
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        spec.refresh()
    end)
    frame.reset:SetMotionScriptsWhileDisabled(true)
    ns.AttachTip(frame.reset, RESET_TIP)

    local pointsBox = ns.SkillInsetBox(foot, 16, true, 0.55)
    pointsBox:SetPoint("LEFT", frame.reset, "RIGHT", 2, 0)
    pointsBox:SetSize(POINTS_BOX_W, POINTS_BOX_H)
    frame.pointsBox = pointsBox
    frame.points = pointsBox:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    frame.points:SetPoint("RIGHT", pointsBox, "RIGHT", POINTS_TEXT_X, 0)

    frame.learn = ns.PanelButton(foot, L["SKILL_APPLY_CHANGES"], 104)
    frame.learn:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", -36, 101)
    frame.learn:SetScript("OnClick", function()
        local tree = frame.tree
        if not tree or InCombatLockdown() then return end
        spec.learn(tree)
        spec.refresh()
    end)
end

local function BuildTabs(frame, spec)
    frame.tabs = {}
    for i = 1, TABS do
        local tab = FootTab(frame)
        if i == 1 then
            tab:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 15, 78)
        else
            tab:SetPoint("TOPLEFT", frame.tabs[i - 1], "TOPRIGHT", -15, 0)
        end
        tab:SetScript("OnClick", function()
            if frame.tabIndex == i then return end
            frame.tabIndex = i
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
            frame.bar:SetValue(0)
            spec.refresh()
        end)
        frame.tabs[i] = tab
    end
end

-- TalentWindow(name, spec) -> frame, hidden. spec: hosted (the gamepad's window places and closes it), refresh() to
-- read and draw again, learn(tree) to commit. frame.tabIndex is the picked foot tab; the caller sets its scripts.
function ns.TalentWindow(name, spec)
    local frame = BuildShell(name, spec)
    frame.tabIndex = 1
    BuildView(frame)
    BuildFoot(frame, spec)
    BuildTabs(frame, spec)
    return frame
end

-- The tree's own pieces (the talent art, points bar, tree, scroll bar, foot and foot tabs) shown or hidden, for a
-- window that shows another page in their place; the title stays. The next DrawTalentTab sets the foot tabs again.
function ns.TalentTreeShown(frame, shown)
    for _, tex in ipairs(frame.quarters) do tex:SetShown(shown) end
    frame.spentBar:SetShown(shown)
    frame.scroll:SetShown(shown)
    frame.foot:SetShown(shown)
    if not shown then
        frame.bar:Hide()
        for _, tab in ipairs(frame.tabs) do tab:Hide() end
    end
end

-- The window's show and hide: a talent tooltip up across a hide and show keeps its listener.
function ns.TalentWindowShown(frame, shown)
    if not shown then
        HearWords(false)
    elseif hovered and hovered.window == frame then
        HearWords(true)
    end
end

-- The background, pulled to the tree's length. Lower files are 128 tall but painted for 75 rows (the old cut);
-- drawn whole they left the tree's foot bare.
local function DrawBackground(frame, name, height)
    local top, bottom = height * 256 / 331, height * 75 / 331
    local art = frame.background
    for key, piece in pairs(art) do
        if name then
            if frame.backgroundName ~= name then piece:SetTexture(ART .. name .. "-" .. key) end
            piece:Show()
        else
            piece:Hide()
        end
    end
    if name then frame.backgroundName = name end
    art.TopLeft:SetSize(256, top)
    art.TopRight:SetSize(64, top)
    art.BottomLeft:SetSize(256, bottom)
    art.BottomRight:SetSize(64, bottom)
    art.BottomLeft:SetTexCoord(0, 1, 0, 75 / 128)
    art.BottomRight:SetTexCoord(0, 1, 0, 75 / 128)
end

-- Public API (Core/API.lua): a talent window's shown button for a talent's spell (talents, the Legacy tree).
function ns.TalentWindowButtonFor(frame, spellID)
    if not (frame and frame:IsShown() and frame.buttons) or type(spellID) ~= "number" then return nil end
    for _, view in ipairs(frame.panes or { frame }) do
        for _, button in ipairs(view.buttons) do
            if button:IsVisible() and button.talent and button.talent.spellID == spellID then return button end
        end
    end
end

local function DrawButtons(frame, tab)
    local child = frame.child
    for i, talent in ipairs(tab.nodes) do
        local button = TalentButton(frame, i)
        button.talent = talent
        ns.SetPointOnce(button, "TOPLEFT", child, "TOPLEFT", CellX(frame, talent.column), CellY(frame, talent.tier))
        button.icon:SetTexture(talent.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        local ranked, maxed = talent.rank > 0, talent.rank >= talent.maxRank
        if maxed or (ranked and not talent.canBuy) then
            button.icon:SetDesaturated(false)
            button.slot:SetVertexColor(1, 0.82, 0)
            button.rankText:SetTextColor(1, 0.82, 0)
        elseif talent.canBuy or ranked then
            button.icon:SetDesaturated(false)
            button.slot:SetVertexColor(0.1, 1, 0.1)
            button.rankText:SetTextColor(0.1, 1, 0.1)
        else
            button.icon:SetDesaturated(true)
            button.slot:SetVertexColor(0.5, 0.5, 0.5)
            button.rankText:SetTextColor(0.5, 0.5, 0.5)
        end
        local showRank = ranked or talent.canBuy
        button.rankBorder:SetShown(showRank)
        button.rankText:SetShown(showRank)
        button.rankText:SetText(talent.rank)
        button:Show()
    end
    -- The arrows: from a talent to each one it opens.
    for _, talent in ipairs(tab.nodes) do
        for _, edge in ipairs(talent.edges) do
            local target = frame.tree.nodesByID[edge.targetNode]
            if target and edge.type ~= 0 and target.column and target ~= talent then
                DrawEdge(frame, talent, target, talent.rank >= talent.maxRank)
            end
        end
    end
end

-- The tabs along the foot: the tree's tabs, or the names given (one tree per tab, the picked one read).
local function DrawFootTabs(frame, tree, names)
    for i, tabButton in ipairs(frame.tabs) do
        local name = names and names[i] or (tree and tree.tabs[i] and tree.tabs[i].name)
        tabButton:SetShown(name ~= nil)
        if name then tabButton:Set(name, i == frame.tabIndex) end
    end
end

-- A tab's tree in a view's cells (its down pitch may be squeezed).
local function TreeHeight(view, tab) return 2 * view.geo[2] + (tab.tiers - 1) * view.geo[4] + BUTTON end

-- A view's tab drawn (view.tree set): background and buttons as tall as the tree, scrolled in its view's height.
local function DrawView(view, tab, look)
    local room = view.scroll:GetHeight() or VIEW_H
    local height = math.max(room, TreeHeight(view, tab))
    view.child:SetSize(VIEW_W, height)
    DrawBackground(view, look.background and look.background(tab), height)
    DrawButtons(view, tab)
    local over = math.max(0, height - room)
    view.bar:SetRange(over, 20)
    view.scroll:SetVerticalScroll(math.min(view.bar:GetValue() or 0, over))
end

-- The foot's points and buttons for the tree as staged.
local function DrawFoot(frame, tree, look)
    frame.points:SetText(look.points or "")
    frame.learn:SetEnabled(tree.staged)
    frame.reset:SetEnabled(tree.staged)
    frame.undoIcon:SetDesaturated(not tree.staged)
    frame.undoIcon:SetAlpha(tree.staged and 1 or 0.5)
end

-- For the three trees side by side (UI/TalentTrees.lua).
ns.talentView = { TreeView = TreeView, DrawView = DrawView, DrawBackground = DrawBackground, DrawFoot = DrawFoot,
    TreeHeight = TreeHeight, RimBar = RimBar, ReleaseAll = ReleaseAll, ART = ART, VIEW_X = VIEW_X, VIEW_Y = VIEW_Y,
    VIEW_W = VIEW_W, VIEW_H = VIEW_H, GEO = GEO, BUTTON = BUTTON, RESET_X = RESET_X, RESET_Y = RESET_Y,
    POINTS_BOX_W = POINTS_BOX_W, POINTS_BOX_H = POINTS_BOX_H, POINTS_TEXT_X = POINTS_TEXT_X }

-- DrawTalentTab(frame, tree, look): the picked tab drawn. look: background(tab) -> an Era tree's art or nil; title;
-- points (the foot's points-left text); tabNames (each foot tab a tree of its own: tree is the picked one, drawn
-- whole). A missing or empty tree draws nothing. With its three trees up, all three (UI/TalentTrees.lua).
function ns.DrawTalentTab(frame, tree, look)
    if frame.trees and frame.trees.on then return frame.trees.Draw(tree, look) end
    frame.tree, frame.tab = tree, nil
    ReleaseAll(frame.branchPool)
    ReleaseAll(frame.arrowPool)
    for _, button in ipairs(frame.buttons) do button:Hide() end
    frame.title:SetText(look.title or "")
    local names = look.tabNames
    if frame.tabIndex > (names and #names or tree and #tree.tabs or 1) then frame.tabIndex = 1 end
    if names then DrawFootTabs(frame, nil, names) end
    if not tree or #tree.tabs == 0 then
        frame.points:SetText("")
        frame.spent:SetText("")
        frame.learn:SetEnabled(false)
        frame.reset:SetEnabled(false)
        frame.child:SetSize(VIEW_W, VIEW_H)
        frame.bar:SetRange(0, 20)
        frame.scroll:SetVerticalScroll(0)
        -- One tree per tab: its background stands empty.
        if names and look.background then DrawBackground(frame, look.background(), VIEW_H) end
        return
    end
    local tab = tree.tabs[names and 1 or frame.tabIndex]
    frame.tab = tab
    if not names then DrawFootTabs(frame, tree) end

    frame.spent:SetText(string.format(L["SKILL_POINTS_SPENT_IN_X_TALENTS"], tab.name) .. "|cffffffff" .. tab.spent .. "|r")
    DrawFoot(frame, tree, look)
    DrawView(frame, tab, look)
end
