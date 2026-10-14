local _, ns = ...

-- Our windows stay outside the client's panel system so they can open in combat;
-- they close the client's and vice versa, and stand side by side clear of the client's.

local classicWindows = {}
-- Ours held where they stand while one has left the row open (dragged or sized out of it), till the next opening, close
-- or reset: they slid into its gap before.
local stay = setmetatable({}, { __mode = "k" })
local inRow = setmetatable({}, { __mode = "k" })   -- the row's members last pass, ours and the game's
-- An opening, close or reset lays the row afresh: no hold, and members counted anew (a pass asleep missed a leaving).
local function Release()
    wipe(stay)
    wipe(inRow)
end
ns.ReleaseWindowRow = Release
local WatchClientWindows   -- forward declared: must stay local

-- Client windows outside its panel list; the map opens on its own terms.
local LOOSE_PANELS = { "WorldMapFrame" }

-- Never closed by us: closing talents clears the bars' empty-slot note, which the client never sets again.
local LEAVE_OPEN = { PlayerSpellsFrame = true }
-- Client windows that stand beside ours instead of replacing them (macros take spells from the book, as in Era).
local BESIDE = { CharacterFrame = true, MacroFrame = true }
-- Client windows that float over ours, closing none and taking no room (loot: at the cursor or its edit mode place, as Era).
local FLOATS = { LootFrame = true }
-- Era's panel rule: a window opened where another stands closes it only when neither can be pushed aside (both
-- pushable 0); otherwise they stand side by side. Ours carry Era's numbers (ns.RegisterClassicWindow), the game's its own.
local function Pushable(frame)
    if frame.fcuiPushable then return frame.fcuiPushable end
    local value = ns.Safe(frame:GetAttribute("UIPanelLayout-pushable"))
    local name = value == nil and UIPanelWindows and frame:GetName()
    if name then value = UIPanelWindows[name] and UIPanelWindows[name].pushable end
    return type(value) == "number" and value or 0
end
-- Era's map (allowOtherPanels 0, this client's 1) replaces what it opens on; ours close it as they open (LOOSE_PANELS).
local function Replaces(opener, other)
    return opener == _G.WorldMapFrame or (Pushable(opener) == 0 and Pushable(other) == 0)
end
-- How much of the character window the old sheet's art fills.
local BESIDE_WIDTH = 352
-- Pieces a client window hangs past its right edge.
local SIDE_PIECES = { CharacterFrame = { "ModeTabs" } }
local PlaceClassicWindows   -- forward declared: must stay local

-- The gamepad's windows close only by their own hand (Core/Gamepad.lua): ours then stand beside them.
-- opener: ours, which closes a game window only as Era's rule says.
local function HideClientPanels(opener, except)
    if InCombatLockdown() or ns.GamepadUI() then return end
    for name in pairs(UIPanelWindows or {}) do
        local panel = _G[name]
        -- The guild window kept open unseen under our roster (note bridge).
        local ghost = ns.guildGhost and name == "CommunitiesFrame"
        if panel and panel ~= except and not LEAVE_OPEN[name] and not BESIDE[name] and not FLOATS[name] and not ghost
            and panel:IsShown() and HideUIPanel and Replaces(opener, panel) then
            pcall(HideUIPanel, panel)
        end
    end
    for _, name in ipairs(LOOSE_PANELS) do
        local panel = _G[name]
        if panel and panel ~= except and panel:IsShown() and HideUIPanel then
            pcall(HideUIPanel, panel)
        end
    end
end

-- Windows that replace ours, watched (a hook on the panel call ran inside the client's pass for every window).
local NPC_WINDOWS = { "GossipFrame", "QuestFrame", "MerchantFrame", "MailFrame", "BankFrame", "ClassTrainerFrame",
    "AuctionHouseFrame", "AuctionFrame", "TradeFrame", "TaxiFrame", "FlightMapFrame", "PetStableFrame", "StableFrame",
    "ItemTextFrame", "TabardFrame", "GuildRegistrarFrame", "PetitionFrame", "CraftFrame", "TradeSkillFrame",
    "ProfessionsFrame", "BarberShopFrame", "GuildBankFrame", "InspectFrame" }
local npcWindow = {}
for _, name in ipairs(NPC_WINDOWS) do npcWindow[name] = true end

local clientShown = {}
local windowWatch

-- Load-on-demand windows join the panel list as they load: rebuild on ADDON_LOADED and every 5 s.
-- Two tables in turn, so a rebuild mid-walk (a load set off by an opening) leaves the walked one whole.
-- watchFrames[i] is watchNames[i]'s frame, nil until it exists.
local watchNames, spareNames, watchHave = {}, {}, {}
local watchFrames, spareFrames = {}, {}
local namesAt   -- nil: rebuild on the next ask
local function IsWindow(panel)
    return type(panel) == "table" and panel.IsShown and true or false
end
local function AddWatchName(name)
    if type(name) == "string" and not watchHave[name] then
        watchHave[name] = true
        local n = #watchNames + 1
        watchNames[n] = name
        local panel = _G[name]
        if IsWindow(panel) then watchFrames[n] = panel end
    end
end
local function ClientWindows()
    local now = GetTime()
    if not namesAt or now - namesAt > 5 then
        namesAt = now
        watchNames, spareNames = spareNames, watchNames
        watchFrames, spareFrames = spareFrames, watchFrames
        wipe(watchNames)
        wipe(watchFrames)
        wipe(watchHave)
        for name in pairs(UIPanelWindows or ns.EMPTY) do AddWatchName(name) end
        for _, name in ipairs(LOOSE_PANELS) do AddWatchName(name) end
        for _, name in ipairs(NPC_WINDOWS) do AddWatchName(name) end
    end
    return watchNames, watchFrames
end

-- Slot i's frame; a window made later is looked up until it exists.
local function WindowAt(names, frames, i)
    local panel = frames[i]
    if panel then return panel end
    panel = _G[names[i]]
    if not IsWindow(panel) then return nil end
    frames[i] = panel
    return panel
end

-- Secret values read as nil for layout.
local Plain = ns.Safe

-- The spellbook's faded stand-in takes no room.
local function Seen(frame)
    if not frame:IsVisible() then return false end
    local alpha = frame.GetEffectiveAlpha and Plain(frame:GetEffectiveAlpha())
    return alpha == nil or alpha > 0
end

-- Left, right in UIParent units, plus the frame's scale ratio (client windows may have their own).
local function Span(frame)
    local left, right = Plain(frame:GetLeft()), Plain(frame:GetRight())
    local scale, screen = Plain(frame:GetEffectiveScale()), UIParent:GetEffectiveScale()
    if not left or not right or not scale or not screen or screen <= 0 then return nil end
    local k = scale / screen
    return left * k, right * k, k
end

-- A client window's drawn left and right edges.
local function ClientSpan(name, panel)
    if not Seen(panel) then return nil end
    local left, right, k = Span(panel)
    if not left then return nil end
    if name == "CharacterFrame" and ForeverClassicUI_CharacterSheetActive then
        -- The old sheet's art is narrower than its frame; the equipment dialog hangs off its edge.
        local extra = ns.EquipmentPaneExtent and ns.EquipmentPaneExtent() or 0
        return left, left + (BESIDE_WIDTH + extra) * k
    end
    local pieces = SIDE_PIECES[name]
    for i = 1, pieces and #pieces or 0 do
        local piece = panel[pieces[i]]
        if type(piece) == "table" and piece.IsVisible and Seen(piece) then
            -- Measure the column's tabs where present: its box is wider.
            local parts = type(piece.Tabs) == "table" and piece.Tabs or { piece }
            for _, part in ipairs(parts) do
                if part.IsVisible and part:IsVisible() then
                    local _, edge = Span(part)
                    if edge and edge > right then right = edge end
                end
            end
        end
    end
    return left, right
end

-- Ours stand round the sheet and talents (in a fight, round whatever stayed up); centre and full-screen ones float.
local function StandsBeside(name)
    if FLOATS[name] or (ns.guildGhost and name == "CommunitiesFrame") then return false end
    if BESIDE[name] or LEAVE_OPEN[name] then return true end
    local info = UIPanelWindows and UIPanelWindows[name]
    local area = type(info) == "table" and info.area
    return area ~= "center" and area ~= "full"
end

local function BlockSpan(name, panel)
    if not StandsBeside(name) then return nil end
    local ok, left, right = pcall(ClientSpan, name, panel)
    if ok and left and right then return left, right end
end

-- The frame's own width when wider than its slot (the dual-pane quest log).
local function Drawn(frame, width)
    local drawn = Plain(frame:GetWidth())
    return (drawn and drawn > width) and drawn or width
end

-- The note bridge's unseen guild window is not one the player opened.
local function ClientUp(name, panel)
    if not panel:IsShown() then return false end
    return not (ns.guildGhost and name == "CommunitiesFrame")
end

-- Marks client windows already up as seen, so they don't close ours.
local function RecordClientWindows()
    local names, frames = ClientWindows()
    for i = 1, #names do
        local panel = WindowAt(names, frames, i)
        if panel then clientShown[names[i]] = ClientUp(names[i], panel) end
    end
end

-- Openings counted across ours (fcuiShownAt) and the game's side windows: which came last decides who gives way.
local openings = { count = 0, game = 0 }

local function ClientWindowOpened(name, panel)
    if FLOATS[name] then return end
    openings.count = openings.count + 1
    openings.game = openings.count
    Release()
    -- Talents and the sheet share the screen with ours, in combat too; anything else by Era's rule.
    if not (LEAVE_OPEN[name] or BESIDE[name]) then ns.HideReplacedWindows(panel) end
    PlaceClassicWindows()
    -- The social window gives way to an NPC's window too.
    if npcWindow[name] and FriendsFrame and FriendsFrame ~= panel and FriendsFrame:IsShown() then
        ns.HidePanel(FriendsFrame)
    end
end

-- Every frame while ours or the social window is up (ours must go the instant the client's shows).
local function AnyOursUp()
    if FriendsFrame and FriendsFrame:IsShown() then return true end
    for frame in pairs(classicWindows) do
        if frame:IsShown() then return true end
    end
    return false
end

local function WindowPass()
    local names, frames = ClientWindows()
    for i = 1, #names do
        local name, panel = names[i], frames[i]
        if not panel then
            panel = _G[name]
            if IsWindow(panel) then frames[i] = panel else panel = nil end
        end
        if panel then
            -- ClientUp inline: one read per window.
            local shown = panel:IsShown() and not (name == "CommunitiesFrame" and ns.guildGhost)
            if shown and not clientShown[name] then ClientWindowOpened(name, panel) end
            if clientShown[name] and not shown then Release() end
            clientShown[name] = shown
        end
    end
    -- The game's row may have changed under ours: the pass moves only what stands elsewhere now.
    PlaceClassicWindows()
end

-- Rebuild names on any load, or a newly listed window goes unnoticed until the next rebuild.
local function NamesStale()
    namesAt = nil
end

-- Every frame while ours or the social window is up, else asleep till an opening of either wakes it.
local windowJob
local function WatchPre(job)
    if AnyOursUp() then return true end
    job:Sleep()
    return false
end

local function WakeWindowWatch()
    if not windowJob or windowJob:IsAwake() then return end
    RecordClientWindows()
    windowJob:Wake()
end

function WatchClientWindows()
    if windowWatch then return end
    windowWatch = ns.EventFrame("ADDON_LOADED", NamesStale)
    -- Otherwise every 0.25 s: walking 100+ windows every frame was the addon's second cost.
    windowJob = ns.Sched.OnFrame(windowWatch, { name = "windows.watch", every = 0.25, pre = WatchPre, fn = WindowPass })
    if FriendsFrame then ns.Sched.Attach(FriendsFrame, { name = "windows.social", every = 0, fn = WakeWindowWatch }) end
end

-- Ours that a window opened now replaces by Era's rule.
function ns.HideReplacedWindows(opener)
    for frame in pairs(classicWindows) do
        if frame ~= opener and frame:IsShown() and Replaces(opener, frame) then frame:Hide() end
    end
end

-- Ours stand side by side in open order, shifting left as one shuts.
local SLOT_STEP = 352
-- Era's old 384 x 512 windows stood 16 left of and 12 above the game's own spot (0, -104 against 16, -116).
local ERA_X, ERA_Y = -16, 12
-- A window's room beside the next, where it is wider than a slot (side tabs past its art); see ns.SetSlotWidth.
local slotWidths = setmetatable({}, { __mode = "k" })
local function SlotWidth(frame) return slotWidths[frame] or SLOT_STEP end

-- Side tabs down a window's right edge stand past its art: the next window keeps clear of them.
function ns.SetSlotWidth(frame, width) slotWidths[frame] = width end
-- Client windows that are another tab of this one (the spellbook's professions): it takes their place, never stands past.
local slotShares = setmetatable({}, { __mode = "k" })
function ns.SetSlotShares(frame, names) slotShares[frame] = names end

-- Our row's first spot, UIParent units: Era's spot from the game's row start, wherever the game's layout puts that.
local function RowStart()
    local left, top = ns.GameRow()
    return left + ERA_X, top + ERA_Y
end
function ns.ClassicSlot() return RowStart() end

-- Protected or anchor-restricted, asked under pcall.
local function Locked(frame)
    local ok, locked = pcall(frame.IsProtected, frame)
    if not (ok and locked) and frame.IsAnchoringRestricted then
        ok, locked = pcall(frame.IsAnchoringRestricted, frame)
    end
    return ok and locked
end
ns.WindowLocked = Locked

-- Our last anchor per window, in its own units; any other anchor means the player or a window mover moved it.
local placedX = setmetatable({}, { __mode = "k" })
local placedY = setmetatable({}, { __mode = "k" })

-- Moved off its slot: out of the row, left where it was put. A place of the player's, or another anchor (a window
-- mover); not the spellbook's own anchors, which its casting layer keeps.
local function Moved(frame)
    if ns.FramePlaced and ns.FramePlaced(frame) then return true end
    local x = placedX[frame]
    if not x or frame.fcuiHoldX then return false end
    local count = frame:GetNumPoints()
    if ns.IsSecret(count) then return false end
    if count ~= 1 then return true end
    local point, rel, relPoint, ox, oy = frame:GetPoint(1)
    if ns.AnySecret(point, rel, relPoint, ox, oy) or not ox or not oy then return false end
    return point ~= "TOPLEFT" or relPoint ~= "TOPLEFT" or (rel ~= nil and rel ~= UIParent)
        or math.abs(ox - x) > 0.5 or math.abs(oy - (placedY[frame] or oy)) > 0.5
end

-- Where a window must stay, or nil: its own fcuiHoldX (the spellbook under live casting buttons), held by one that left
-- the row, or in a fight a protected window's actual place.
local function HeldAt(frame)
    local at = frame.fcuiHoldX and frame:fcuiHoldX()
    if at then return at end
    if stay[frame] then return stay[frame] end
    if not (InCombatLockdown() and Locked(frame)) then return nil end
    local left = Span(frame)
    return left and math.floor(left + 0.5) or frame.fcuiSlotX or 0
end

-- x and y in UIParent units; the anchor in the window's own (a size of ours scales it).
local function PlaceAt(frame, x, y)
    local k = ns.WindowRatio(frame) or 1
    local ox, oy = x / k, y / k
    frame.fcuiSlotX = x
    if placedX[frame] == ox and placedY[frame] == oy then return end
    placedX[frame], placedY[frame] = ox, oy
    ns.SetPointOnce(frame, "TOPLEFT", UIParent, "TOPLEFT", ox, oy)
    if frame.OnClassicPlaced then frame:OnClassicPlaced(x, y) end
end

-- The solver's state and answer (UI/WindowRow.lua), refilled each pass; order[i] is ours i, oldest first.
local row = { game = {}, ours = {} }
local laid = { x = {}, close = {} }
local order = {}
local solved = false   -- a pass has filled row and laid

-- The game's row: the windows its manager stands in a row, those we showed raw in a fight (off its list), and the map.
local ROW_SLOTS = { "left", "center", "right", "doublewide" }
local rawShown = setmetatable({}, { __mode = "k" })
ns.windowRawShown = rawShown   -- UI/WindowPanels.lua adds to it
local counted = {}

local function AddGame(n, panel)
    if counted[panel] or not panel:IsShown() then return n end
    counted[panel] = true
    -- Placed by the player (our edit mode, or a window mover off the row's line): out of the row.
    if (ns.FramePlaced and ns.FramePlaced(panel)) or ns.GameWindowOffRow(panel) or ns.MoverHolds(panel) then return n end
    local name = panel:GetName()
    local left, right = BlockSpan(name, panel)
    if not left then return n end
    n = n + 1
    local block = row.game[n] or {}
    block[1], block[2], block[3] = left, right, name
    row.game[n] = block
    return n
end

local function GameRow()
    wipe(counted)
    local n = 0
    local getPanel = _G.GetUIPanel
    for _, slot in ipairs(ROW_SLOTS) do
        local panel = getPanel and getPanel(slot)
        if IsWindow(panel) then n = AddGame(n, panel) end
    end
    for panel in pairs(rawShown) do
        if panel:IsShown() then n = AddGame(n, panel) else rawShown[panel] = nil end
    end
    for _, name in ipairs(LOOSE_PANELS) do
        local panel = _G[name]
        if IsWindow(panel) then n = AddGame(n, panel) end
    end
    for i = #row.game, n + 1, -1 do row.game[i] = nil end
end

local function ByOpening(a, b) return (a.fcuiShownAt or 0) < (b.fcuiShownAt or 0) end

local function Describe(i, frame)
    local w = row.ours[i] or {}
    row.ours[i] = w
    -- In UIParent units: a size of ours (edit mode's) makes the window take more room than its slot.
    local k, slot = ns.WindowRatio(frame) or 1, SlotWidth(frame)
    w.width = slot * k
    w.drawn = Drawn(frame, slot) * k
    w.shares = slotShares[frame]
    -- fcuiKeep names the client window it belongs beside (the inspect window's talents).
    local keep, right = frame.fcuiKeep and frame:fcuiKeep(), nil
    if keep and keep:IsShown() then right = select(2, Span(keep)) end
    w.keep = right and math.floor(right + 0.5) or nil
    return w
end

-- Ours open and not moved, oldest first.
local function OurRow()
    local n = 0
    for frame in pairs(classicWindows) do
        if frame:IsShown() and not Moved(frame) then
            n = n + 1
            order[n] = frame
        end
    end
    for i = #order, n + 1, -1 do order[i] = nil end
    table.sort(order, ByOpening)
    for i, frame in ipairs(order) do Describe(i, frame).held = HeldAt(frame) end
    for i = #row.ours, n + 1, -1 do row.ours[i] = nil end
    -- A game window opened after all of ours: it stays, and ours give way to it.
    row.gameLast = n > 0 and openings.game > (order[n].fcuiShownAt or 0)
end

-- A floating client window on its own spot (loot off the cursor) stands past the row, as Era's loot; ours stay.
local standing = setmetatable({}, { __mode = "k" })
local function StandPast(frame)
    if InCombatLockdown() and Locked(frame) then return end
    local k, width = ns.WindowRatio(frame), Plain(frame:GetWidth())
    if not (k and width and solved) then return end
    local _, y = RowStart()
    width = width * k
    local x = math.max(0, math.min(ns.WindowRowEnd(row, laid), math.floor(UIParent:GetWidth() - width)))
    ns.SetPointIf(frame, "TOPLEFT", UIParent, "TOPLEFT", x / k, y / k)
end
local function StandingPass()
    for frame in pairs(standing) do
        if frame:IsShown() then StandPast(frame) end
    end
end

-- One of the row's members last pass still open but out of it now holds the rest (stay above).
local function NoteLeavers()
    local now = {}
    for _, block in ipairs(row.game) do
        if _G[block[3]] then now[_G[block[3]]] = true end
    end
    for frame in pairs(classicWindows) do
        if frame:IsShown() and not Moved(frame) then now[frame] = true end
    end
    local left = false
    for frame in pairs(inRow) do left = left or (frame:IsShown() and not now[frame]) end
    wipe(inRow)
    for frame in pairs(now) do
        inRow[frame] = true
        if left and classicWindows[frame] and frame.fcuiSlotX then stay[frame] = frame.fcuiSlotX end
    end
end

local function Solve(keep)
    GameRow()
    NoteLeavers()
    OurRow()
    local x, y = RowStart()
    row.start, row.screen, row.stay = x, UIParent:GetWidth(), keep
    ns.SolveWindowRow(row, laid)
    return y
end

-- Never tell the client's manager where to stand its windows: that write made its opening run as ours, and its health
-- text then compared a secret. Ours stand past the game's row, a held one stays; out of a fight the oldest closes for room.
PlaceClassicWindows = function()
    local y = Solve(InCombatLockdown())
    for i, frame in ipairs(order) do
        local x = laid.x[i]
        if x and row.ours[i].held then
            frame.fcuiSlotX = x
        elseif x then
            PlaceAt(frame, x, y)
        end
    end
    solved = true
    StandingPass()
    -- Each close lays the row again from its OnHide.
    if laid.close[1] then
        local shut = {}
        for n, i in ipairs(laid.close) do shut[n] = order[i] end
        for _, frame in ipairs(shut) do frame:Hide() end
    end
end

function ns.StandPastWindows(frame)
    standing[frame] = true
    PlaceClassicWindows()
end
function ns.StopStandingPast(frame) standing[frame] = nil end

-- A placed window's reset (WindowHandles.lua): ours back on the row now; false for a client window.
function ns.ReturnClassicWindow(frame)
    if not classicWindows[frame] then return false end
    Release()
    placedX[frame] = nil
    local _, y = RowStart()
    PlaceAt(frame, frame.fcuiSlotX or 0, y)
    PlaceClassicWindows()
    return true
end

-- Out of a fight, closed windows wait where they would open next: a book opened in a fight cannot move then.
local function HomeClosedWindows()
    if InCombatLockdown() then return end
    local y = Solve(true)
    local n = #order + 1
    for frame in pairs(classicWindows) do
        if not frame:IsShown() and not Moved(frame) then
            Describe(n, frame).held = nil
            ns.SolveWindowRow(row, laid)
            if laid.x[n] then PlaceAt(frame, laid.x[n], y) end
        end
    end
    row.ours[n] = nil
end
-- The last moment before combat anything may move, and the first after, to re-place what it held.
local HOME_EVENTS = { "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }
ns.EventFrame(HOME_EVENTS, function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        HomeClosedWindows()
    else
        PlaceClassicWindows()
        HomeClosedWindows()
    end
end)

-- Room past the game's windows for one of ours opened now, and whether the game's spell window is in that row.
function ns.RowRoomFor(frame)
    GameRow()
    local finish, spells = RowStart(), false
    for _, block in ipairs(row.game) do
        finish = math.max(finish, block[2])
        spells = spells or block[3] == "PlayerSpellsFrame"
    end
    local k = ns.WindowRatio(frame) or 1
    return UIParent:GetWidth() - finish - Drawn(frame, SlotWidth(frame)) * k, spells
end

-- For the dev addon's row probe: the last pass's state, answer and our windows in it.
function ns.WindowRowState() return row, laid, order end

-- The manager counts the sheet as frame + 82 (mode tabs); we draw BESIDE_WIDTH, so the next stands at that edge.
local SHEET_NEXT = { left = { "center", "right" }, center = { "right" } }
local sheetGap

-- Moves a client window's left edge to x on its manager's anchor, on screen; nil if it cannot move.
-- A protected client window moved by our code is tainted (PVEFrame's list then compares secrets): out of combat it
-- moves inside a snippet instead, which runs securely; in combat it is not moved at all.
local positioner
local POSITION_BODY = [[
    local f = self:GetFrameRef("f")
    if not f then return end
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", self:GetParent(), "TOPLEFT", self:GetAttribute("x"), self:GetAttribute("y"))
]]
local function SecureTopLeft(panel, x, y)
    if InCombatLockdown() then return false end
    positioner = positioner or CreateFrame("Frame", nil, UIParent, "SecureHandlerBaseTemplate")
    positioner:SetFrameRef("f", panel)
    positioner:SetAttribute("x", x)
    positioner:SetAttribute("y", y)
    positioner:Execute(POSITION_BODY)
    return true
end

-- Era's spot stands on our own anchor at UIParent's corner: an addon that shifts the game's UIParent-anchored windows
-- (a centering one) took our moved x for a fresh one and shifted it a second time (#154).
local eraHost = ns.NewFrame("Frame", nil, UIParent)
eraHost:SetSize(1, 1)
eraHost:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)

local function StandAt(panel, x)
    if InCombatLockdown() and Locked(panel) then return end
    local left, right, k = Span(panel)
    if not left then return end
    if x > left then x = math.max(left, math.min(x, UIParent:GetWidth() - (right - left))) end
    if math.abs(x - left) < 0.5 then return left end
    if Plain(panel:GetNumPoints()) ~= 1 then return end
    local point, rel, relPoint, ox, oy = panel:GetPoint(1)
    ox, oy = Plain(ox), Plain(oy)
    if not ox or not oy or Plain(point) ~= "TOPLEFT" or Plain(relPoint) ~= "TOPLEFT" then return end
    -- UIParent, or the sheet's Era anchor (the same corner), kept as it is.
    if rel ~= nil and Plain(rel) ~= UIParent and rel ~= eraHost then return end
    local newX = ox + (x - left) / k
    if Locked(panel) then
        if not SecureTopLeft(panel, newX, oy) then return end
    elseif not pcall(panel.SetPoint, panel, "TOPLEFT", rel or UIParent, "TOPLEFT", newX, oy) then
        return
    end
    return x
end

local function CloseSheetGap()
    local getPanel, getWidth = _G.GetUIPanel, _G.GetUIPanelWidth
    if not ForeverClassicUI_CharacterSheetActive or not getPanel or not getWidth then return end
    local slot = (getPanel("left") == CharacterFrame and "left") or (getPanel("center") == CharacterFrame and "center")
    local keys = slot and SHEET_NEXT[slot]
    local first = keys and getPanel(keys[1])
    if not (first and first:IsShown()) then return end
    local ok, _, x = pcall(ClientSpan, "CharacterFrame", CharacterFrame)
    if not (ok and x) then return end
    if not sheetGap then
        local layout = _G.GetUIPanelLayoutAttribute
        local gap = layout and Plain(layout("PANEl_SPACING_X"))
        sheetGap = type(gap) == "number" and gap or 32
    end
    for _, key in ipairs(keys) do
        local panel = getPanel(key)
        -- A native center window is centred, not in the row.
        if not (panel and panel:IsShown()) or panel:GetAttribute("UIPanelLayout-area") == "center" then return end
        if ns.MoverHolds(panel) then return end
        -- A faded one (the spellbook's stand-in) takes no room and stays put.
        if Seen(panel) then
            local at = StandAt(panel, x + (Plain(panel:GetAttribute("UIPanelLayout-xoffset")) or 0) + sheetGap)
            local okWidth, width = pcall(getWidth, panel)
            width = okWidth and Plain(width)
            -- One left where the manager put it keeps the next one in step.
            if not at or type(width) ~= "number" then return end
            x = at + width
        end
    end
end

-- Top and bottom in UIParent units.
local function Rows(frame)
    local top, bottom = Plain(frame:GetTop()), Plain(frame:GetBottom())
    local k = Plain(frame:GetEffectiveScale())
    if not (top and bottom and k) then return nil end
    k = k / UIParent:GetEffectiveScale()
    return top * k, bottom * k
end

-- Whether frame at a place (top left and drawn size, UIParent units) would cover another open window; except shares
-- its place (the spellbook for the classic professions book), so is never in the way.
function ns.WindowCovers(frame, left, top, width, height, except)
    local right, bottom = left + width, top - height
    local function Covers(l, r, t, b) return l and t and l < right and r > left and t > bottom and b < top end
    local names, frames = ClientWindows()
    for i = 1, #names do
        local panel = WindowAt(names, frames, i)
        if panel and panel ~= frame and panel ~= except and panel:IsShown() then
            local l, r = BlockSpan(names[i], panel)
            local t, b = Rows(panel)
            if Covers(l, r, t, b) then return true end
        end
    end
    for other in pairs(classicWindows) do
        if other ~= frame and other ~= except and Seen(other) then
            local l, r = Span(other)
            local t, b = Rows(other)
            if Covers(l, r, t, b) then return true end
        end
    end
    return false
end

-- In a fight, a window of ours held over its casting layer where the client stands the sheet: the sheet stands past
-- it, as ours cannot move then. A sheet on its edit mode place (not the client's anchor) stays.
local function SheetPastHeld()
    if not InCombatLockdown() then return end
    local ok, sheetLeft, sheetRight = pcall(ClientSpan, "CharacterFrame", CharacterFrame)
    local sheetTop, sheetBottom = Rows(CharacterFrame)
    if not (ok and sheetLeft and sheetTop) then return end
    for frame in pairs(classicWindows) do
        if frame:IsShown() and frame.fcuiHoldX and frame:fcuiHoldX() then
            local left, right = Span(frame)
            local top, bottom = Rows(frame)
            -- Touching by under a unit (a fractional row start) is not covering.
            if left and top and sheetLeft < right - 1 and sheetRight > left + 1 and sheetTop > bottom and sheetBottom < top then
                StandAt(CharacterFrame, math.floor(right + 0.5))
                return
            end
        end
    end
end

-- The sheet at Era's spot (ERA_X, ERA_Y from the game's). Only the client's own anchor moves: a y we set stays (gap and
-- held passes keep y), and an edit mode place (anchored off the foot) is never touched; one that gave way to another
-- window is on the client's anchor, so it takes Era's height with the rest.

-- The y this pass last set per window.
local eraY = setmetatable({}, { __mode = "k" })

local function AtEraSpot(frame)
    if ns.WindowMoving and ns.WindowMoving(frame) then return end
    if Plain(frame:GetNumPoints()) ~= 1 then return end
    local point, rel, relPoint, x, y = frame:GetPoint(1)
    x, y = Plain(x), Plain(y)
    if Plain(point) ~= "TOPLEFT" or Plain(relPoint) ~= "TOPLEFT" or not x or not y or rel == eraHost then return end
    if rel ~= nil and Plain(rel) ~= UIParent then return end
    if eraY[frame] and math.abs(y - eraY[frame]) < 0.5 then return end
    if InCombatLockdown() and Locked(frame) then return end
    eraY[frame] = y + ERA_Y
    pcall(frame.SetPoint, frame, "TOPLEFT", eraHost, "TOPLEFT", x + ERA_X, eraY[frame])
end

local function SheetPass()
    if (ns.WindowMoving and ns.WindowMoving(CharacterFrame)) or ns.MoverHolds(CharacterFrame) then return end
    AtEraSpot(CharacterFrame)
    SheetPastHeld()
    CloseSheetGap()
end

-- Parented to the character window so it runs only while that is up.
if CharacterFrame then
    ns.Sched.OnFrame(ns.NewFrame("Frame", nil, CharacterFrame), { name = "windows.sheetGap", every = 0, fn = SheetPass })
end

-- pushable: Era's number for the window it stands for (its panel rule, Pushable above); 0 when none.
function ns.RegisterClassicWindow(frame, pushable)
    if not frame or classicWindows[frame] then return end
    classicWindows[frame] = true
    -- Built on the row's first slot (ns.ClassicSlot): that anchor is ours until something else moves it. Read before a
    -- saved place takes it.
    if frame:GetNumPoints() == 1 then
        local point, rel, relPoint, x, y = frame:GetPoint(1)
        if point == "TOPLEFT" and relPoint == "TOPLEFT" and rel == UIParent then placedX[frame], placedY[frame] = x, y end
    end
    -- A micro button's window made on first open; a place given in edit mode applies from now.
    if ns.MicroWindowsChanged then ns.MicroWindowsChanged() end
    if ns.PlaceSavedWindows then ns.PlaceSavedWindows() end
    frame.fcuiPushable = pushable or 0
    frame:HookScript("OnShow", function(self)
        -- The watch may be asleep or on its slow beat and not have seen them yet.
        RecordClientWindows()
        if windowJob then windowJob:Wake() end
        openings.count = openings.count + 1
        self.fcuiShownAt = openings.count
        Release()
        -- A window held in a fight (the spellbook over its live casting layer) comes straight back when hidden, and
        -- then hid this one: the two flashed in turn. A held one neither closes nor is closed; the rest lay out round it.
        local selfHeld = self.fcuiHoldX and self:fcuiHoldX()
        for other in pairs(classicWindows) do
            local otherHeld = other.fcuiHoldX and other:fcuiHoldX()
            if other ~= self and other:IsShown() and Replaces(self, other) and not selfHeld
                and not otherHeld then
                other:Hide()
            end
        end
        -- fcuiKeep names the client window it belongs beside (the inspect window's talents).
        HideClientPanels(self, self.fcuiKeep and self:fcuiKeep() or nil)
        PlaceClassicWindows()
        if ns.GameSpellsRoomChanged then ns.GameSpellsRoomChanged() end
    end)
    frame:HookScript("OnHide", function()
        Release()
        PlaceClassicWindows()
        HomeClosedWindows()
        if ns.GameSpellsRoomChanged then ns.GameSpellsRoomChanged() end
    end)
    WatchClientWindows()
end
