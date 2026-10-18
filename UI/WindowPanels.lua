local _, ns = ...

-- Game windows opened and closed from our code: through the game's panel call out of a fight, raw in one (its Escape
-- then needs our stand-in). Ours (UI/Windows.lua) keep clear of a raw one in the row.

local rawShown = ns.windowRawShown

-- A window shown raw in a fight is off the client's panel list, so its Escape skips it. A child of ours signed up with
-- our Escape stands in, counted open while the window shows off that list (read each frame, not on show edges).
-- Never under a client layout frame (its layout pass would be ours).
local PANEL_SLOTS = { "left", "center", "right", "doublewide", "fullscreen" }
local escProxies = {}

local function OnPanelList(frame)
    local panelIn = _G.GetUIPanel
    if not panelIn then return true end
    for i = 1, #PANEL_SLOTS do
        if panelIn(PANEL_SLOTS[i]) == frame then return true end
    end
    return false
end

local function EscProxy(frame)
    if escProxies[frame] or frame.Layout then return end
    local proxy = ns.NewFrame("Frame", nil, frame)
    escProxies[frame] = proxy
    ns.CloseOnEscape(proxy, function() ns.HidePanel(frame) end, function() return not OnPanelList(frame) end, frame)
    if ns.debugSink then ns.Persist("esc: stand-in made for " .. tostring(frame:GetName())) end
end

-- In combat the client refuses addon opens: an unprotected window is shown raw (outside the
-- panel list; our Escape closes it), a protected one is left alone. With the gamepad on too: its focus would be ours.
function ns.ShowPanel(frame)
    if not frame or frame:IsShown() then return true end
    if not InCombatLockdown() and not ns.GamepadUI() then
        if ShowUIPanel then ShowUIPanel(frame) else frame:Show() end
        return true
    end
    if frame.IsProtected and frame:IsProtected() then return false end
    -- No anchor until its panel call has opened it once: a spot to measure from; the row lays it as it shows.
    if frame.GetNumPoints and frame:GetNumPoints() == 0 then
        frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", ns.GameRow())
    end
    frame:Show()
    rawShown[frame] = true
    ns.NoteWindowOpened(frame)
    ns.LayWindowsNow()
    EscProxy(frame)
    return true
end

-- A window the gamepad holds is left for its own close: shut from our code, every later close is refused.
function ns.HidePanel(frame)
    if not frame or not frame:IsShown() then return true end
    if ns.GamepadUI() then
        if ns.GamepadHolds(frame) or (frame.IsProtected and frame:IsProtected()) then return false end
        frame:Hide()
        return true
    end
    if not InCombatLockdown() then
        if HideUIPanel then HideUIPanel(frame) else frame:Hide() end
        return true
    end
    if frame.IsProtected and frame:IsProtected() then return false end
    frame:Hide()
    return true
end

-- In a fight the game's side windows are laid as its manager lays them out of one (UI/WindowRow.lua LayFightWindows):
-- its own and the ones shown here, round the fixed (locked ones, our held ones flush); ours then stand past them all.
local fight = { fixed = {}, members = {} }
local laidX, laidFrames, laidSet = {}, {}, {}
local openedAt, opened = setmetatable({}, { __mode = "k" }), 0

-- The order windows opened in, for the lay's ties: stamped by the game window watch and by the raw open here.
function ns.NoteWindowOpened(frame)
    if openedAt[frame] then return end
    opened = opened + 1
    openedAt[frame] = opened
end
function ns.NoteWindowClosed(frame) openedAt[frame] = nil end
function ns.FightLaid(frame) return laidSet[frame] == true end

-- A game side window the lay moves: seen, not locked, not placed by the player or a mover, standing in the row.
local function Member(frame)
    local P = ns.windowParts
    -- The map stands where the game puts it, in a fight as out of one: never laid with the row.
    if frame == _G.WorldMapFrame then return false end
    if not P.Seen(frame) or P.Locked(frame) or ns.MoverTakes(frame) then return false end
    if (ns.FramePlaced and ns.FramePlaced(frame)) or ns.GameWindowOffRow(frame) then return false end
    return P.BlockSpan(frame:GetName(), frame) ~= nil
end

local function Add(frame)
    if laidSet[frame] then return end
    laidSet[frame] = true
    laidFrames[#laidFrames + 1] = frame
end

local function Describe(i, frame, sheet)
    local P = ns.windowParts
    local m = fight.members[i] or {}
    fight.members[i] = m
    local k = ns.WindowRatio(frame) or 1
    local left, right = P.BlockSpan(frame:GetName(), frame)
    m.width, m.xoff = ns.GamePanelWidth(frame) * k, ns.GameXOffset(frame)
    m.pushable, m.opened = ns.GamePanelValue(frame, "pushable") or 0, openedAt[frame] or 0
    -- Past what each draws: the sheet's art and the professions book are narrower than the game's widths.
    m.span, m.shift, m.drawn = right - left, 0, right - left
    if frame == sheet then m.shift = P.ERA_X * k end
end

function ns.LayFightRaw(row)
    wipe(laidFrames)
    wipe(laidSet)
    wipe(fight.fixed)
    local kept = 0
    for i = 1, #row.game do
        local block = row.game[i]
        local frame = _G[block[3]]
        if frame and Member(frame) then
            Add(frame)
        else
            kept = kept + 1
            row.game[kept] = block
            fight.fixed[#fight.fixed + 1] = { block[1], block[2] }
        end
    end
    for i = #row.game, kept + 1, -1 do row.game[i] = nil end
    for frame in pairs(rawShown) do
        if frame:IsShown() and Member(frame) then Add(frame) end
    end
    for _, w in ipairs(row.ours) do
        if w.held then fight.fixed[#fight.fixed + 1] = { w.held, w.held + w.width, 0 } end
    end
    local sheet = ForeverClassicUI_CharacterSheetActive and CharacterFrame
    for i, frame in ipairs(laidFrames) do Describe(i, frame, sheet) end
    for i = #laidFrames + 1, #fight.members do fight.members[i] = nil end
    fight.gap, fight.screen, fight.start = ns.windowParts.SheetGap(), UIParent:GetWidth(), ns.GameRow()
    ns.LayFightWindows(fight, laidX)
    -- Laid, they are the game's row: ours stand past what each draws.
    for i, frame in ipairs(laidFrames) do
        local m = fight.members[i]
        local left = laidX[i] + m.shift
        row.game[#row.game + 1] = { left, left + math.max(m.drawn or m.width, m.span), frame:GetName() }
    end
end

-- The game's height for each (its y offset, its fit for a tall one); the classic sheet on Era's anchor and spot.
function ns.PlaceFightRaw()
    local P = ns.windowParts
    for i, frame in ipairs(laidFrames) do
        local k, x, m = ns.WindowRatio(frame), laidX[i], fight.members[i]
        if k and x then
            local down = ns.GameDown(frame)
            if m.shift ~= 0 then
                ns.SetPointIf(frame, "TOPLEFT", P.eraHost, "TOPLEFT", x / k + P.ERA_X, -down / k + P.ERA_Y)
            else
                ns.SetPointIf(frame, "TOPLEFT", UIParent, "TOPLEFT", x / k, -down / k)
            end
        end
    end
end

-- The book's page (the professions window) on the book's spot each frame it is up: the game's manager lays it in its
-- left slot on every panel event, and a frame of that showed, over the sheet. Its first open lays the row at once.
function ns.KeepBookPageSpot()
    local P, page = ns.windowParts, ns.BookPageWindow and ns.BookPageWindow()
    if not (page and P.Seen(page)) then return end
    if ns.MoverTakes(page) then return ns.BookFollowsPage(page) end
    -- Its first open: the row (which settles the sheet first), then the page, this frame.
    if not P.pageX then ns.LayWindowsNow() end
    if P.pageX then P.StandAt(page, P.pageX) end
end

-- For the dev addon's fight probe: the last fight lay's input, answer and windows.
function ns.WindowFightState() return fight, laidX, laidFrames end
