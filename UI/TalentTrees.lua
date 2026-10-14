local _, ns = ...
local L = ns.L

-- Three trees side by side (option) in the talents window or the Legacy tree, each in Era's view, in Era's frame widened
-- by its own art, inset lines on the seams and foot. Height: each scrolls, the window grows, or rows squeeze into Era's;
-- without scroll bars the trees touch. Drawn through UI/TalentWindow.lua's pieces.

local V = ns.talentView

-- A tree's view, or with its scroll bar (Era's 22 to 340), then the seam's 6: the seam never covers a tree.
local SEAM = 6
local VIEW_STEP, BAR_STEP = 296 + SEAM, 318 + SEAM
-- The points bars in Era's band, narrow enough for the first to stand clear of the portrait ring (to 70 across).
local HEADER_W, HEADER_Y = 180, -48
local WINDOW_W, WINDOW_H = 384, 512
-- Era's frame grown: the left pieces' last 64 columns repeated across, the top pieces' last 64 rows repeated down past
-- the band; each seam into the next piece is the art's own.
local STRIP, REPEAT_X, REPEAT_Y = 64, 192, 192
local TOP_LEFT, TOP_RIGHT = "charGeneralTopLeft", "charGeneralTopRight"
local BOT_LEFT = V.ART .. "UI-TalentFrame-BotLeft"
-- The game's inset border, its edges alone: a seam's right and left edge side by side, the trees' foot.
local INSET_LEFT, INSET_RIGHT, INSET_FOOT = "!UI-Frame-InnerLeftTile", "!UI-Frame-InnerRightTile", "_UI-Frame-InnerBotTile"
-- The three trees' foot (+ right, + up); the talents box from the foot's right end, its text from the box's.
local UNDO_BUTTON_X = 17
local UNDO_BUTTON_Y = 101
local APPLY_BUTTON_Y = -2
local APPLY_BUTTON_PADDING = 40
local TALENTS_BOX_RIGHT = -1
local TALENTS_BOX_Y = -1
local TALENTS_BOX_WIDTH = 196
local TALENTS_BOX_HEIGHT = 24
local TALENTS_TEXT_RIGHT = -10

local keyOf = setmetatable({}, { __mode = "k" })   -- a piece's art, set when it changes

-- A window's added pieces (frame.trees.art), reused in order.
local function Piece(frame, n, key, file, x0, y0, w, h, fileW, point, x, y, drawH)
    local art = frame.trees.art
    local tex = art[n]
    if not tex then
        tex = frame:CreateTexture(nil, "BORDER")
        art[n] = tex
    end
    if keyOf[tex] ~= key then
        keyOf[tex] = key
        if file then ns.SetFile(tex, key) else ns.SetTex(tex, key) end
    end
    tex:SetTexCoord(x0 / fileW, (x0 + w) / fileW, y0 / 256, (y0 + h) / 256)
    tex:SetSize(w, drawH or h)
    ns.SetPointOnce(tex, point, frame, point, x, y)
    tex:Show()
end

-- The pieces for a window wide and tall past Era's 384 x 512: each top column (its key, first column, width, file width,
-- corner, x) has its last rows repeated down, the added columns their whole top too; the bottom pieces as they are.
local function Grow(frame, wide, tall)
    local n = 0
    local function Add(...)
        n = n + 1
        Piece(frame, n, ...)
    end
    local cols = { { TOP_LEFT, 0, 256, 256, "TOPLEFT", 0 }, { TOP_RIGHT, 0, 128, 128, "TOPRIGHT", 0 } }
    for col = 0, math.ceil(wide / STRIP) - 1 do
        local w, x = math.min(STRIP, wide - col * STRIP), 256 + col * STRIP
        cols[#cols + 1] = { TOP_LEFT, REPEAT_X, w, 256, "TOPLEFT", x }
        Add(TOP_LEFT, false, REPEAT_X, 0, w, 256, 256, "TOPLEFT", x, 0)
        Add(BOT_LEFT, true, REPEAT_X, 0, w, 256, 256, "BOTTOMLEFT", x, 0)
    end
    for _, c in ipairs(cols) do
        local key, x0, w, fileW, point, x = c[1], c[2], c[3], c[4], c[5], c[6]
        for row = 0, math.ceil(tall / STRIP) - 1 do
            Add(key, false, x0, REPEAT_Y, w, math.min(STRIP, tall - row * STRIP), fileW, point, x, -256 - row * STRIP)
        end
    end
    local art = frame.trees.art
    for i = n + 1, #art do art[i]:Hide() end
end

-- One inset edge, drained to the old silver as the game's inset border is.
local function Edge(frame, atlas)
    local tex = frame:CreateTexture(nil, "OVERLAY")
    tex:SetAtlas(atlas, true)
    ns.KeepDrained(tex)
    return tex
end

-- The talents' height pick: scroll, tall or squeeze.
local function TalentsMode()
    local db = ns.db
    if db.talentsTall == true then return "tall" end
    if db.talentsSqueeze == true then return "squeeze" end
    return "scroll"
end

local function Step(mode) return mode == "scroll" and BAR_STEP or VIEW_STEP end
-- Past the single tree's view and bar (22 to 340).
local function Wide(mode) return 3 * Step(mode) - SEAM - 318 end

local function Pane(frame, lines)
    local pane = ns.NewFrame("Frame", nil, frame)
    pane:SetAllPoints(frame)
    pane.spec = frame.spec
    V.TreeView(pane)
    pane.geo = { V.GEO[1], V.GEO[2], V.GEO[3], V.GEO[4] }
    pane.header = V.RimBar(pane)
    pane.header:SetWidth(HEADER_W)
    -- The seam on its right: two edges back to back over the next tree's start.
    pane.seam = { Edge(lines, INSET_RIGHT), Edge(lines, INSET_LEFT) }
    pane:Hide()
    return pane
end

-- Views, headers and seams for the pick, and the views as tall as room.
local function Lay(frame, mode, room)
    local step = Step(mode)
    for i, pane in ipairs(frame.panes) do
        local x = V.VIEW_X + (i - 1) * step
        ns.SetPointOnce(pane.scroll, "TOPLEFT", frame, "TOPLEFT", x, V.VIEW_Y)
        pane.scroll:SetHeight(room)
        pane.bar.hideWhenIdle = mode ~= "scroll"
        -- Over its tree's middle.
        ns.SetPointOnce(pane.header, "TOP", frame, "TOPLEFT", x + V.VIEW_W / 2, HEADER_Y)
        local right, left = pane.seam[1], pane.seam[2]
        local seam = x + step - SEAM / 2
        right:SetShown(i < #frame.panes)
        left:SetShown(i < #frame.panes)
        ns.SetTwoPointsIf(right, "TOPRIGHT", frame, "TOPLEFT", seam, V.VIEW_Y, "BOTTOMRIGHT", frame, "TOPLEFT", seam,
            V.VIEW_Y - room)
        ns.SetTwoPointsIf(left, "TOPLEFT", frame, "TOPLEFT", seam, V.VIEW_Y, "BOTTOMLEFT", frame, "TOPLEFT", seam,
            V.VIEW_Y - room)
    end
    local foot = frame.trees.foot
    ns.SetTwoPointsIf(foot, "TOPLEFT", frame, "TOPLEFT", V.VIEW_X, V.VIEW_Y - room, "TOPRIGHT", frame, "TOPLEFT",
        V.VIEW_X + 3 * step - SEAM, V.VIEW_Y - room)
end

-- The window in its pick and room (Era's 332, or the tallest tree with Tall).
local function Size(frame, mode, room)
    local trees = frame.trees
    if trees.mode == mode and trees.room == room then return end
    trees.mode, trees.room = mode, room
    local wide, tall = Wide(mode), room - V.VIEW_H
    frame:SetSize(WINDOW_W + wide, WINDOW_H + tall)
    Lay(frame, mode, room)
    Grow(frame, wide, tall)
    -- The row stands the next window past its full width.
    ns.SetSlotWidth(frame, (trees.opts.slot or 352) + wide)
end

-- A pane's tree and tab: one of the trees given (look.trees, a tab each), or one of the tree's three tabs.
local function PaneTree(tree, look, i)
    if look.trees then
        local own = look.trees[i]
        return own, own and own.tabs[1]
    end
    return tree, tree and tree.tabs[i]
end

-- tree: the window's (its foot; for look.trees, their parts), look as ns.DrawTalentTab's.
local function Draw(frame, tree, look)
    frame.tree, frame.tab = tree, nil
    frame.title:SetText(look.title or "")
    local mode, room = frame.trees.opts.mode(), V.VIEW_H
    for _, pane in ipairs(frame.panes) do
        local _, tab = PaneTree(tree, look, pane.index)
        -- Squeezed: the rows' pitch down till the tree fits Era's height.
        local pitch = V.GEO[4]
        if mode == "squeeze" and tab and tab.tiers > 1 then
            pitch = math.min(pitch, math.floor((V.VIEW_H - 2 * V.GEO[2] - V.BUTTON) / (tab.tiers - 1)))
        end
        pane.geo[4] = pitch
        if mode == "tall" and tab then room = math.max(room, V.TreeHeight(pane, tab)) end
    end
    Size(frame, mode, room)
    for i, pane in ipairs(frame.panes) do
        V.ReleaseAll(pane.branchPool)
        V.ReleaseAll(pane.arrowPool)
        for _, button in ipairs(pane.buttons) do button:Hide() end
        local own, tab = PaneTree(tree, look, i)
        pane.tree, pane.tab = own, tab
        pane.header:SetShown(tab ~= nil)
        if tab then
            pane.header.text:SetText(string.format(L["SKILL_POINTS_IN_X"], tab.name) .. "|cffffffff"
                .. tab.spent .. "|r")
            V.DrawView(pane, tab, look)
        else
            V.DrawBackground(pane, nil, room)
            pane.bar:SetRange(0, 20)
        end
    end
    if tree then V.DrawFoot(frame, tree, look) else frame.points:SetText("") end
end

-- The foot: undo at the left, Apply in the middle and the points at the right; or the single tree's row. Apply is cut
-- to 104 to fit the single tree's foot; here it takes its label's width and more.
local APPLY_W, APPLY_MIN = 104, 140
local function Foot(frame, on)
    local reset, box, text, learn = frame.reset, frame.pointsBox, frame.points, frame.learn
    reset:ClearAllPoints()
    box:ClearAllPoints()
    text:ClearAllPoints()
    learn:ClearAllPoints()
    if on then
        reset:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", UNDO_BUTTON_X, UNDO_BUTTON_Y)
        box:SetPoint("RIGHT", frame.foot, "RIGHT", TALENTS_BOX_RIGHT, TALENTS_BOX_Y)
        box:SetSize(TALENTS_BOX_WIDTH, TALENTS_BOX_HEIGHT)
        text:SetPoint("RIGHT", box, "RIGHT", TALENTS_TEXT_RIGHT, 0)
        learn:SetPoint("TOP", frame.foot, "TOP", 0, APPLY_BUTTON_Y)
        local label = learn:GetFontString()
        learn:SetWidth(math.max(APPLY_MIN, math.ceil(label and label:GetStringWidth() or 0) + APPLY_BUTTON_PADDING))
    else
        reset:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", V.RESET_X, V.RESET_Y)
        box:SetPoint("LEFT", reset, "RIGHT", 2, 0)
        box:SetSize(V.POINTS_BOX_W, V.POINTS_BOX_H)
        text:SetPoint("RIGHT", box, "RIGHT", V.POINTS_TEXT_X, 0)
        learn:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", -36, 101)
        learn:SetWidth(APPLY_W)
    end
end

-- The window in its shape: three trees, or its one tree under foot tabs.
local function Shape(frame, on)
    local trees = frame.trees
    if trees.on == on then return end
    trees.on = on
    for _, pane in ipairs(frame.panes) do pane:SetShown(on) end
    trees.lines:SetShown(on)
    Foot(frame, on)
    frame.spentBar:SetShown(not on)
    frame.scroll:SetShown(not on)
    if on then
        frame.bar:Hide()
        for _, tab in ipairs(frame.tabs) do tab:Hide() end
        Size(frame, trees.opts.mode(), V.VIEW_H)
    else
        trees.mode, trees.room = nil, nil
        frame:SetSize(WINDOW_W, WINDOW_H)
        for _, tex in ipairs(trees.art) do tex:Hide() end
        ns.SetSlotWidth(frame, trees.opts.slot)
    end
end

local function Reshape(frame)
    Shape(frame, frame.trees.opts.wanted(frame) == true)
end

-- The talents window's: its option and height pick, the game's own window in place while hosted or ours is off.
local TALENTS = {
    wanted = function(frame)
        return ns.db and ns.db.talentsThreePane == true and not frame.spec.hosted and ns.TalentsActive()
    end,
    mode = TalentsMode,
    keys = { talentsThreePane = true, talentsScroll = true, talentsTall = true, talentsSqueeze = true, talents = true },
}

local windows = {}
-- A talent window as built (Skills/Talents.lua, or the Legacy tree's page): its panes, and its shape for the option
-- now. opts (the talents' when none): wanted(frame), mode() for the height pick, keys (toggles that reshape it), slot
-- (its row width at one tree; the talents' default). frame.trees.Reshape() after anything wanted() reads changes.
function ns.TalentTrees(frame, opts)
    windows[#windows + 1] = frame
    -- Over the trees' art and arrows; the seams and foot pass clear of the buttons.
    local lines = ns.NewFrame("Frame", nil, frame)
    lines:SetAllPoints(frame)
    lines:Hide()
    frame.panes = {}
    for i = 1, 3 do
        frame.panes[i] = Pane(frame, lines)
        frame.panes[i].index = i
    end
    lines:SetFrameLevel(frame.panes[3].arrows:GetFrameLevel() + 2)
    frame.trees = { on = false, lines = lines, foot = Edge(lines, INSET_FOOT), art = {}, opts = opts or TALENTS,
        Draw = function(tree, look) Draw(frame, tree, look) end, Reshape = function() Reshape(frame) end }
    Reshape(frame)
end

-- Our own windows, nothing protected in them: the options answer at once, in a fight too.
ns.OnToggle(function(key)
    for _, frame in ipairs(windows) do
        if frame.trees.opts.keys[key] then
            Reshape(frame)
            if frame:IsShown() then frame.spec.refresh() end
        end
    end
end)
