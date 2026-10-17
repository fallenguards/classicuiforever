local _, ns = ...
local L = ns.L

-- ClassicUI Forever Windows: our edit mode for the windows. A placeholder drag places a window; its dialog holds Movable
-- anytime, Size and resets. Places (db.windowPos, UIParent units) and sizes (db.windowScale) are put back the frame after
-- anyone moves the window, never inside the client's pass.

local WINDOWS = ns.WINDOW_LIST
-- The whole painted title bar, clear of the portrait on the left and the lock and close on the right.
local STRIP_H, STRIP_LEFT, STRIP_RIGHT = 40, 60, 90
local STRIP_LIFT = 20
local Plain = ns.Safe

local weak = { __mode = "k" }
local entryOf = setmetatable({}, weak)   -- window frame -> its entry, once watched
local strips = setmetatable({}, weak)    -- window frame -> its drag strip
local moving = setmetatable({}, weak)    -- window frame -> true mid free drag
local dragged = setmetatable({}, weak)   -- placeholder -> true once this press dragged it

-- Our saved tables, a broken entry dropped as read (settings outlive sessions; one bad value errored every pass).
local function Clean(key, valid)
    local list = ns.DbTable(key)
    for name, value in pairs(list) do
        if not valid(value) then list[name] = nil end
    end
    return list
end

local function ValidSpot(pos) return type(pos) == "table" and type(pos[1]) == "number" and type(pos[2]) == "number" end
local function ValidScale(scale) return type(scale) == "number" and scale >= 0.5 and scale <= 1.5 end
local function ValidFlag(flag) return flag == true end

local function Places() return Clean("windowPos", ValidSpot) end

local function Freed() return Clean("windowFree", ValidFlag) end
local function Scales() return Clean("windowScale", ValidScale) end

local byKey = {}
for _, entry in ipairs(WINDOWS) do byKey[entry.key] = entry end

-- The entry whose place and unlock this one shares, and this one's corner from it.
local function Leader(entry)
    if entry.follows and (entry.followIf == nil or (ns.db and ns.db[entry.followIf])) then
        return byKey[entry.follows], entry.followX, entry.followY
    end
    return entry, 0, 0
end

-- The key its size is saved under: the leader's when it follows that too.
local function SizeKey(entry)
    return entry.followSize and Leader(entry).key or entry.key
end

-- Its top left in UIParent units, or nil.
local function PlaceOf(entry)
    local leader, dx, dy = Leader(entry)
    local pos = Places()[leader.key]
    if pos then return pos[1] + dx, pos[2] + dy end
end

local function SetPlace(entry, x, y)
    local leader, dx, dy = Leader(entry)
    Places()[leader.key] = { x - dx, y - dy }
end

-- A game window wears our place, size, lock and grip while its restyle is on (UI/WindowList.lua dressed); off, it is the
-- game's and other addons' (#192), ours kept for its return. Locked, a dressed one stays where it was put.
local function Worn(entry)
    if not entry.dressed then return true end
    return entry.dressed() and true or false
end

-- A choice's rows: its radio group's toggles, the label past "Calendar: " as the item's own words.
local function ChoiceRows(group)
    local rows = {}
    for _, toggle in ipairs(ns.TOGGLES) do
        if toggle.radio == group then
            local text = toggle[2]:match(":%s*(.+)$") or toggle[2]
            rows[#rows + 1] = { key = toggle[1], text = (text:gsub("^%l", string.upper)) }
        end
    end
    return rows
end

-- Settings the item dialogs write beyond places, sizes and unlocks: Save lights for them, Revert puts them back.
local function DialogKeys()
    local keys = { "mapFade" }
    for _, entry in ipairs(WINDOWS) do
        if entry.choice then
            for _, row in ipairs(ChoiceRows(entry.choice)) do keys[#keys + 1] = row.key end
        end
    end
    return keys
end

-- Every setting this mode writes goes through here (checker EDITSAVE); a key outside Save and Revert is an error.
local function Set(key, value)
    local covered = key == "mapUnlocked"
    for _, entry in ipairs(WINDOWS) do covered = covered or key == entry.toggle or key == entry.ringKey end
    for _, k in ipairs(DialogKeys()) do covered = covered or k == key end
    if not covered then geterrorhandler()("windows edit mode: " .. tostring(key) .. " is outside Save and Revert") end
    rawset(ns.db, key, value)
end
-- A saved size by window key, for a secure re-apply (the client fits a panel to 1 as it shows it).
function ns.WindowScale(key) return Scales()[byKey[key] and SizeKey(byKey[key]) or key] end
-- Mid drag by its title bar: the window placing passes leave it to the mouse.
function ns.WindowMoving(frame) return moving[frame] == true end
function ns.WindowPlaced(key)
    if byKey[key] then return Worn(byKey[key]) and PlaceOf(byKey[key]) ~= nil end
    return Places()[key] ~= nil
end
-- A place carried over from an older record (the gryphons' old handle).
function ns.SetWindowPlace(key, x, y) SetPlace(byKey[key], x, y) end
-- A window the player placed (ours or the game's): out of the windows' row.
function ns.FramePlaced(frame)
    for _, entry in ipairs(WINDOWS) do
        if not entry.piece and ns.WindowFrame(entry) == frame then return Worn(entry) and PlaceOf(entry) ~= nil end
    end
    return false
end

local function IsFree(entry)
    if not Worn(entry) then return false end
    if entry.toggle then return ns.db[entry.toggle] == true end
    return Freed()[Leader(entry).key] == true
end


local Ratio = ns.WindowRatio

-- Maximized, the map fills the screen: none of our place or size, the game's own or an Era style's scale.
local function Full(entry, frame)
    return entry.quests and frame and frame.IsMaximized and frame:IsMaximized() and true or false
end
local function FullScale() return ns.FullMapScale and ns.FullMapScale() or nil end

-- The part of the window its art fills, in its own units.
local function DrawnSize(entry, frame)
    local w, h = Plain(frame:GetWidth()), Plain(frame:GetHeight())
    if not (w and h) then return nil end
    local cut = entry.cut
    if cut and math.abs(w - 384) < 1 and math.abs(h - 512) < 1 then return w - cut[1], h - cut[2] end
    return w, h
end

local scaled = setmetatable({}, weak)   -- window frame -> true while it wears a size of ours
local clampWas = setmetatable({}, weak) -- window frame -> its clamp before a drag of ours

-- A top left (UIParent units) that keeps the window's drawn part on the screen.
local function OnScreen(entry, frame, k, left, top)
    local w, h = DrawnSize(entry, frame)
    if not w then return left, top end
    local screenW, screenH = UIParent:GetSize()
    left = math.max(0, math.min(left, screenW - w * k))
    top = math.min(screenH, math.max(top, h * k))
    return left, top
end

local PlaceAll

-- A piece on the minimap ring drags round it: an angle, not a place.
local function OnRing(entry) return entry.ringKey ~= nil and (entry.ringIf == nil or ns.db[entry.ringIf] == true) end
local function Fixed(entry) return entry.fixedIf ~= nil and ns.db[entry.fixedIf] == true end

-- A new size on the game's own spot (no place of ours) keeps it on screen: the offsets count in the window's scale.
local function ScaleKept(frame, scale)
    local old = Plain(frame:GetScale())
    if not ns.SetScaleIf(frame, scale) or not old or frame:GetNumPoints() ~= 1 then return end
    local point, rel, relPoint, x, y = frame:GetPoint(1)
    if Plain(x) and Plain(y) then frame:SetPoint(point, rel, relPoint, x * old / scale, y * old / scale) end
end

local function Apply(entry)
    local frame = ns.WindowFrame(entry)
    if not frame or moving[frame] or ns.MoverHolds(frame) then return end
    local left, top, scale
    if Worn(entry) then
        left, top = PlaceOf(entry)
        scale = Scales()[SizeKey(entry)]
    end
    -- A size the window's own look asks on top of the player's (the full size professions book).
    local zoom = entry.zoom and entry.zoom() or 1
    if zoom ~= 1 then scale = (scale or 1) * zoom end
    -- Windowed, the map's header style at its own size till the player gives it one.
    if entry.quests and not scale and ns.MapWindowedScale then scale = ns.MapWindowedScale() end
    if Full(entry, frame) then left, scale = nil, FullScale() end
    if not (left or scale or scaled[frame]) then return end
    -- calm: its casting layer moves out of combat only.
    if InCombatLockdown() and (entry.calm or ns.WindowLocked(frame)) then
        ns.WhenCalm("windowPlaces", PlaceAll)
        return
    end
    -- In a fight the map keeps the size it wears: its look re-laid there gave it the game's own for a pass (huge).
    if entry.quests and InCombatLockdown() then
        ns.WhenCalm("windowPlaces", PlaceAll)
    -- No size of ours (or the map maximized): its own.
    elseif scale then
        ScaleKept(frame, scale)
        scaled[frame] = true
    elseif scaled[frame] then
        ScaleKept(frame, 1)
        scaled[frame] = nil
    end
    if not left then return end
    local k = Ratio(frame)
    if not k then return end
    local x, y = OnScreen(entry, frame, k, left, top)
    -- The game stands its windows side by side: a place that would cover another open one waits till it closes.
    if entry.client then
        local w, h = DrawnSize(entry, frame)
        local leader = Leader(entry)
        if w and ns.WindowCovers(frame, x, y, w * k, h * k, ns.WindowFrame(leader)) then return end
    end
    x, y = x / k, y / k
    if not ns.IsAt(frame, "TOPLEFT", UIParent, "BOTTOMLEFT", x, y) then
        ns.SetPointOnce(frame, "TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
    end
end

-- From the frame's drawn top left.
local function SaveFrom(entry, frame)
    local k = Ratio(frame)
    local left, top = Plain(frame:GetLeft()), Plain(frame:GetTop())
    if not (k and left and top) then return end
    SetPlace(entry, OnScreen(entry, frame, k, left * k, top * k))
end

-- Watched from the first place or unlock: placed as it shows, and put back the frame after anyone moves it.
local function Watch(entry)
    local frame = ns.WindowFrame(entry)
    if not frame or entryOf[frame] then return end
    entryOf[frame] = entry
    local function Put() Apply(entry) end
    -- Before it draws, shown or moved (the map's quest toggle re-lays it through the panel manager): later, it flashed there.
    local shown = ns.Sched.AfterShow(frame, "windowPlace", Put)
    -- The game's windows (the map too), which another addon may drag: where one is drawn is kept for that drag.
    if entry.client or entry.quests then
        local drags = ns.windowEdit
        ns.Sched.OnMove(frame, function()
            drags.KeepDrawn(frame)
            shown()
        end)
        ns.HookMethod(frame, "StartMoving", drags.ForeignDragStart)
        ns.HookMethod(frame, "StopMovingOrSizing", drags.ForeignDragStop)
    else
        ns.Sched.OnMove(frame, shown)
    end
end

local MAP_ENTRY = WINDOWS[5]

PlaceAll = function()
    if not ns.db then return end
    for _, entry in ipairs(WINDOWS) do
        local frame, ours = ns.WindowFrame(entry), Worn(entry)
        -- Nothing made or hooked on a game window that is not ours; one handed back (scaled) gets its size back.
        if ours and ns.MakeWindowLock then ns.MakeWindowLock(entry) end
        if ours and ns.MakeWindowGrip then ns.MakeWindowGrip(entry) end
        if (ours and (PlaceOf(entry) or Scales()[SizeKey(entry)] or IsFree(entry))) or (frame and scaled[frame])
            or (entry.quests and ours and (FullScale() or (ns.MapWindowedScale and ns.MapWindowedScale())))
            or (entry.zoom and entry.zoom() ~= 1) then
            if ours then Watch(entry) end
            Apply(entry)
        end
        -- Also off again: a strip made earlier goes.
        if frame and (IsFree(entry) or strips[frame]) then ns.windowEdit.Strip(entry) end
    end
    if ns.SyncWindowLocks then ns.SyncWindowLocks() end
end

ns.OnToggle(function(key) if key == MAP_ENTRY.toggle or key == "worldMap" then PlaceAll() end end)

-- Leave game windows to other addons: a size ours gave one goes back to the game's; turned off, ours place them again.
-- A protected one (professions) waits for calm.
local function LeaveGameWindows()
    if InCombatLockdown() then ns.WhenCalm("windowsLeft", LeaveGameWindows) return end
    for frame in pairs(scaled) do
        if ns.MoverHolds(frame) then
            ns.SetScaleIf(frame, 1)
            scaled[frame] = nil
        end
    end
    PlaceAll()
end
ns.OnToggle(function(key) if key == "leaveGameWindows" then LeaveGameWindows() end end)

-- Our windows are made on first open; client ones as their addon loads.
ns.PlaceSavedWindows = PlaceAll
ns.EventFrame({ "ADDON_LOADED", "PLAYER_LOGIN" }, function() if ns.db then PlaceAll() end end)

------------------------------------------------------------------ edit mode

local dialog, selected
local handles = {}
-- The map's placeholder: with its quest log pane (as it opens) or the map alone; one place and size for both.
local mapOnly = false

-- The map's scale of ours and, when the player placed it, its top left (UIParent units) for a box w x h, as Apply lays
-- it: read ahead of a fight, when the fight layer lays the map (Map/WorldMapFight.lua).
function ns.MapPlaceFor(w, h, base)
    local entry = byKey.map
    local worn = entry and Worn(entry)
    local scale = (worn and Scales()[SizeKey(entry)]) or base or 1
    local left, top
    if worn then left, top = PlaceOf(entry) end
    if not left then return scale end
    local screenW, screenH = UIParent:GetSize()
    return scale, math.max(0, math.min(left, screenW - w * scale)), math.min(screenH, math.max(top, h * scale))
end

-- A game window our layout grew after the game laid it (the classic map opening at the game's height): raised as the
-- game's own fit raises a tall window, its left kept. One the player placed stays.
function ns.FitGameWindow(key)
    local entry = byKey[key]
    local frame = entry and ns.WindowFrame(entry)
    if not frame or PlaceOf(entry) or Full(entry, frame) or not frame:IsShown() or ns.MoverHolds(frame) then return end
    if InCombatLockdown() and ns.WindowLocked(frame) then return end
    local left, top, h, k = Plain(frame:GetLeft()), Plain(frame:GetTop()), Plain(frame:GetHeight()), Ratio(frame)
    if not (left and top and h and k) then return end
    local _, down = ns.GameHome(frame, h * k)
    local want = UIParent:GetHeight() - down
    if top * k >= want - 0.5 then return end
    -- Anchors cleared first: one a drag's end left is refused a second beside it (UI/GameSpot.lua).
    ns.SetPointOnce(frame, "TOPLEFT", UIParent, "TOPLEFT", left, -down / k)
end

-- Back where the client or our slots put it: ours on the slots, the game's at its own spot or on their next opening.
local function Return(entry)
    local frame = ns.WindowFrame(entry)
    if entry.piece then
        if ns.LayPiece then ns.LayPiece(entry.key) end
    elseif frame then
        -- A calm or locked window moves its secure pieces with it: home once the fight ends.
        if InCombatLockdown() and (entry.calm or ns.WindowLocked(frame)) then
            ns.WhenCalm("windowReturn." .. entry.key, function() Return(entry) end)
            return
        end
        ns.ReturnClassicWindow(frame)
        -- The map is a game window too: the game's left panel spot.
        if (entry.client or entry.quests) and not Full(entry, frame) and Worn(entry) then
            ns.GameSpot(frame)
            -- Ours held for its leaving lay out again round it.
            ns.ReleaseWindowRow()
        end
    end
end

-- Every window sharing the place goes home with it.
local function Reset(entry)
    local leader = Leader(entry)
    Places()[leader.key] = nil
    if entry.ringKey then Set(entry.ringKey, nil) end
    for _, other in ipairs(WINDOWS) do
        if other == entry or Leader(other) == leader then Return(other) end
    end
end

-- The placeholder's size in the window's own units: as drawn, the map (Era's or the client's) in the width picked.
local function PreviewSize(entry, frame)
    if entry.quests then
        local w, h, quests = ns.ClassicMapSize()
        return w + (mapOnly and 0 or quests), h
    end
    if frame then
        local w, h = DrawnSize(entry, frame)
        if w then return w, h end
    end
    return entry.w, entry.h
end

-- A placeholder's rect in UIParent units: its place, else where the window is drawn now, else its spot (the map and a
-- new-style game window on the game's spot, the rest on the first slot).
local function HandleRect(entry)
    local frame, left, top = ns.WindowFrame(entry), PlaceOf(entry)
    local full = Full(entry, frame)
    local k = (frame and not full and Ratio(frame)) or Scales()[SizeKey(entry)] or 1
    local w, h = PreviewSize(entry, frame)
    w, h = w * k, h * k
    if left and not OnRing(entry) then return left, top, w, h end
    -- A piece shown only at times (the tracking spell's icon) still has its spot on the minimap while hidden.
    if frame and not full and (frame:IsShown() or entry.piece) then
        local x, y = Plain(frame:GetLeft()), Plain(frame:GetTop())
        if x and y then return x * k, y * k, w, h end
    end
    -- A ring button turned off has no frame yet: its box where it would stand on the ring.
    if entry.piece then
        local cx, cy = ns.RingButtonSpot(entry.key)
        if cx then return cx - w / 2, cy + h / 2, w, h end
    end
    if (entry.client or entry.quests) and not entry.cut then
        local x, down = ns.GameHome(nil, h)
        if frame then x, down = ns.GameHome(frame, h) end
        return x, UIParent:GetHeight() - down, w, h
    end
    local x, y = ns.ClassicSlot()
    return x, UIParent:GetHeight() + y, w, h
end

local function LayHandle(entry)
    local handle = handles[entry.key]
    if not handle then return end
    local x, y, w, h = HandleRect(entry)
    handle:SetSize(w, h)
    if not ns.IsAt(handle, "TOPLEFT", UIParent, "BOTTOMLEFT", x, y) then
        ns.SetPointOnce(handle, "TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
    end
end

-- Edit mode's own look: blue, and yellow while its dialog is open.
local function DressHandles()
    local open = dialog and dialog:IsShown() and selected
    for key, handle in pairs(handles) do
        handle.sel.Dress(open and open.key == key and "editmode-actionbar-selected" or "editmode-actionbar-highlight")
    end
end

local DIALOG_H, VIEW_H, FREE_Y = 214, 34, -44
local CONTROL_W = 200 -- floor: the size slider's width, which the choice dropdown matches (its longest row fits)
-- The map's extra rows: its view switch over Movable anytime, Fade while moving under it.
local MAP_ROWS = 2

local function Refresh()
    if not (dialog and selected and dialog:IsShown()) then return end
    local views = selected.quests == true
    dialog.title:SetText(selected.label)
    dialog:SetHeight(views and DIALOG_H + VIEW_H * MAP_ROWS or DIALOG_H)
    dialog.views:SetShown(views)
    dialog.wide:SetChecked(not mapOnly)
    dialog.narrow:SetChecked(mapOnly)
    ns.SetPointOnce(dialog.check, "TOPLEFT", dialog, "TOPLEFT", 20, views and FREE_Y - VIEW_H or FREE_Y)
    dialog.check:SetChecked(IsFree(selected))
    dialog.check:SetShown(not selected.piece)
    -- The map's fade is the addon's own setting (the game's mapFade), the same as in the options.
    dialog.fade:SetShown(views)
    dialog.fade:SetChecked(ns.db.mapFade == true)
    local choice = selected.choice ~= nil
    dialog.choice:SetShown(choice)
    if choice then
        dialog.choice.label:SetText(selected.choiceLabel)
        dialog.choice.dropdown:GenerateMenu()
    end
    if selected.piece then
        -- Rows from those shown: the choice, then size.
        if choice then
            ns.SetPointOnce(dialog.choice, "TOPLEFT", dialog, "TOPLEFT", 20, FREE_Y)
            ns.SetPointOnce(dialog.sizeLabel, "TOPLEFT", dialog.choice, "BOTTOMLEFT", 0, -4)
        else
            ns.SetPointOnce(dialog.sizeLabel, "TOPLEFT", dialog, "TOPLEFT", 20, FREE_Y)
        end
        dialog:SetHeight(choice and DIALOG_H or DIALOG_H - VIEW_H)
    else
        ns.SetPointOnce(dialog.sizeLabel, "TOPLEFT", views and dialog.fade or dialog.check, "BOTTOMLEFT", 0, -4)
    end
    dialog.reset:SetEnabled(PlaceOf(selected) ~= nil or (OnRing(selected) and ns.db[selected.ringKey] ~= nil))
    dialog.resize:SetEnabled(Scales()[SizeKey(selected)] ~= nil and not Fixed(selected))
    if dialog.InitSlider then dialog.InitSlider() end
end

-- Unlock: the map's goes through its option (lock button and settings box follow); the rest are kept here.
local function SetFree(entry, on)
    if entry.toggle then
        Set(entry.toggle, on)
        ns.ToggleChanged(entry.toggle)
    else
        Freed()[Leader(entry).key] = on or nil
    end
    PlaceAll()
end

-- The same switch as the options row: the options follow, and the item is laid again.
local function PickChoice(key)
    Set(key, true)
    ns.ToggleChanged(key)
    if selected then LayHandle(selected) end
    Refresh()
end

local function ChoiceRow(dialog)
    local row = ns.NewFrame("Frame", nil, dialog)
    row:SetSize(343, 32)
    local label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
    label:SetSize(100, 32)
    label:SetJustifyH("LEFT")
    label:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.label = label
    local dropdown = ns.NewFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate")
    dropdown:SetWidth(CONTROL_W)
    dropdown:SetPoint("LEFT", label, "RIGHT", 5, 0)
    -- The old drop down box, as the settings window's, not the client's bronze one.
    ns.SkinDropdown(dropdown)
    dropdown:SetupMenu(function(_, root)
        if not (selected and selected.choice) then return end
        for _, choice in ipairs(ChoiceRows(selected.choice)) do
            root:CreateRadio(choice.text, function(key) return ns.db[key] == true end, PickChoice, choice.key)
        end
    end)
    row.dropdown = dropdown
    return row
end

local function Percent(value) return string.format("%d%%", value) end
local function SizeValues()
    local scale = selected and Scales()[SizeKey(selected)] or 1
    return math.floor(scale * 100 + 0.5), 50, 150, 20
end

-- No dialog refresh here: that would re-fill the slider under the player's hand.
local function OnSize(value)
    if not selected then return end
    local scale = math.max(0.5, math.min(1.5, value / 100))
    Scales()[SizeKey(selected)] = math.abs(scale - 1) > 0.001 and scale or nil
    PlaceAll()
    -- A piece at its own spot keeps that spot's middle as it grows.
    if selected.piece and ns.LayPiece then ns.LayPiece(selected.key) end
    for _, other in ipairs(WINDOWS) do
        if SizeKey(other) == SizeKey(selected) then LayHandle(other) end
    end
    if dialog then dialog.resize:SetEnabled(Scales()[SizeKey(selected)] ~= nil) end
end

-- The map's placeholder width.
local function PickView(only)
    if not (selected and selected.quests) then return end
    mapOnly = only
    LayHandle(selected)
    Refresh()
end

local function ViewCheck(parent, text, x, only)
    local check = ns.NewFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetSize(30, 30)
    check:SetPoint("LEFT", parent, "LEFT", x, 0)
    ns.EditModeCheck(check)
    local label = check:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
    label:SetPoint("LEFT", check, "RIGHT", 4, 0)
    label:SetText(text)
    check:SetScript("OnClick", function() PickView(only) end)
    return check
end

local FADE_TIP = { text = L["UI_FADE_WHILE_MOVING"], r = 1, g = 1, b = 1, lines = { {
    L["UI_THE_MAP_DIMS_WHILE_YOU"], nil, nil, nil, true } } }

local FREE_TIP = { text = L["UI_MOVABLE_ANYTIME"], r = 1, g = 1, b = 1, lines = { {
    L["UI_DRAG_THE_WINDOW_BY_ITS"],
    nil, nil, nil, true } } }

-- Shaped like edit mode's own dialog, as the band's pieces are.
local function Dialog()
    if dialog then return dialog end
    local B = ns.band
    dialog = B.EditDialog("ForeverClassicUIWindowDialog", 383, DIALOG_H)
    dialog:SetClampedToScreen(true)
    -- The map only: its placeholder with or without the quest log pane.
    local views = ns.NewFrame("Frame", nil, dialog)
    views:SetSize(343, 30)
    views:SetPoint("TOPLEFT", dialog, "TOPLEFT", 20, FREE_Y)
    dialog.views = views
    dialog.wide = ViewCheck(views, L["UI_WITH_QUEST_LOG"], 0, false)
    dialog.narrow = ViewCheck(views, L["UI_MAP_ONLY"], 180, true)
    local check = ns.NewFrame("CheckButton", nil, dialog, "UICheckButtonTemplate")
    check:SetSize(30, 30)
    check:SetPoint("TOPLEFT", dialog, "TOPLEFT", 20, FREE_Y)
    ns.EditModeCheck(check)
    -- On the check itself, so it hides with it (a piece has no Movable anytime row).
    local label = check:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
    label:SetPoint("LEFT", check, "RIGHT", 4, 0)
    label:SetText(L["UI_MOVABLE_ANYTIME_BY_ITS_TITLE"])
    check:SetScript("OnClick", function(self) SetFree(selected, self:GetChecked() and true or false) end)
    ns.AttachTip(check, FREE_TIP)
    dialog.check = check
    dialog.choice = ChoiceRow(dialog)
    local fade = ns.NewFrame("CheckButton", nil, dialog, "UICheckButtonTemplate")
    fade:SetSize(30, 30)
    fade:SetPoint("TOPLEFT", check, "BOTTOMLEFT", 0, -4)
    ns.EditModeCheck(fade)
    -- On the check itself, so it hides with it on every window but the map.
    local fadeLabel = fade:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
    fadeLabel:SetPoint("LEFT", fade, "RIGHT", 4, 0)
    fadeLabel:SetText(L["UI_FADE_WHILE_MOVING"])
    fade:SetScript("OnClick", function(self)
        Set("mapFade", self:GetChecked() and true or false)
        ns.ToggleChanged("mapFade")
    end)
    ns.AttachTip(fade, FADE_TIP)
    dialog.fade = fade
    local size = dialog:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
    dialog.sizeLabel = size
    size:SetSize(100, 32)
    size:SetJustifyH("LEFT")
    size:SetPoint("TOPLEFT", check, "BOTTOMLEFT", 0, -4)
    size:SetText(HUD_EDIT_MODE_SETTING_MICRO_MENU_SIZE or "Size")
    local slider, formatters = B.StepperSlider(dialog, CONTROL_W, size, 5, Percent)
    if slider then
        -- Greyed while the piece is fixed (the calendar behind the day/night: sized by the icon).
        dialog.InitSlider = B.GuardedSlider(slider, SizeValues, OnSize, { formatters = formatters, owner = dialog,
            enabled = function() return not (selected and Fixed(selected)) end, label = size })
    end
    dialog.reset = B.EditDialogReset(dialog, function()
        Reset(selected)
        LayHandle(selected)
        Refresh()
    end)
    local resize = ns.NewFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    resize:SetSize(330, 28)
    resize:SetPoint("BOTTOM", dialog.reset, "TOP", 0, 6)
    resize:SetText(L["BAR_RESET_TO_DEFAULT_SIZE"])
    resize:SetScript("OnClick", function()
        OnSize(100)
        Refresh()
    end)
    ns.EditModeRed(resize)
    dialog.resize = resize
    dialog:HookScript("OnHide", DressHandles)
    return dialog
end

local DIALOG_GAP = 8

local function Select(entry)
    ns.EditMode.TakePick()
    selected = entry
    local d = Dialog()
    local handle = handles[entry.key]
    local left, right = Plain(handle:GetLeft()), Plain(handle:GetRight())
    local top, bottom = Plain(handle:GetTop()), Plain(handle:GetBottom())
    -- Placed on its first open only, then it stays where it is or is dragged, as the client's settings dialog does.
    if left and right and top and bottom and d:GetNumPoints() == 0 then
        -- Beside the box on the side with room, else under or over it: never on it (the clamp pushed it back on).
        local w, screenW = d:GetWidth(), UIParent:GetWidth()
        if right + DIALOG_GAP + w <= screenW then
            ns.SetPointOnce(d, "LEFT", UIParent, "BOTTOMLEFT", right + DIALOG_GAP, (top + bottom) / 2)
        elseif left - DIALOG_GAP - w >= 0 then
            ns.SetPointOnce(d, "RIGHT", UIParent, "BOTTOMLEFT", left - DIALOG_GAP, (top + bottom) / 2)
        elseif bottom - DIALOG_GAP - d:GetHeight() >= 0 then
            ns.SetPointOnce(d, "TOP", UIParent, "BOTTOMLEFT", (left + right) / 2, bottom - DIALOG_GAP)
        else
            ns.SetPointOnce(d, "BOTTOM", UIParent, "BOTTOMLEFT", (left + right) / 2, top + DIALOG_GAP)
        end
    end
    d:Show()
    DressHandles()
    Refresh()
end

local function HandleDown(self) dragged[self] = nil end

-- Round the ring: the angle follows the cursor each frame and the piece is laid there, its box with it.
local ringJob
local function RingStep(job)
    local entry = job.entry
    if not (entry and ns.MinimapCursorAngle) then return end
    Set(entry.ringKey, ns.MinimapCursorAngle())
    Return(entry)
    LayHandle(entry)
end

-- A gameEdit piece follows its box each frame of a drag, on the spot it would snap to (home or a bar's edge).
local followJob
local function FollowStep(job)
    local handle = job.handle
    local frame = handle and ns.WindowFrame(handle.entry)
    if not frame then return end
    local x, y
    if ns.SnapPieceDrop then x, y = ns.SnapPieceDrop(handle.entry.key, handle) end
    if x == "home" then
        ns.LayPiece(handle.entry.key, true)
        return
    end
    local left, top, k = x or Plain(handle:GetLeft()), y or Plain(handle:GetTop()), Ratio(frame)
    if left and top and k then ns.SetPointOnce(frame, "TOPLEFT", UIParent, "BOTTOMLEFT", left / k, top / k) end
end

local function Follow(handle, on)
    local frame = ns.WindowFrame(handle.entry)
    if not frame then return end
    if on then
        followJob = followJob or ns.Sched.OnFrame(CreateFrame("Frame"), { name = "windows.pieceDrag", every = 0,
            awake = false, fn = FollowStep })
        followJob.handle = handle
        moving[frame] = true
        followJob:Wake()
    elseif followJob and followJob.handle == handle then
        followJob:Sleep()
        followJob.handle = nil
        moving[frame] = nil
    end
end

local function HandleDragStart(self)
    dragged[self] = true
    if Fixed(self.entry) then return end
    if OnRing(self.entry) then
        ringJob = ringJob or ns.Sched.OnFrame(CreateFrame("Frame"), { name = "windows.ringDrag", every = 0, awake = false,
            fn = RingStep })
        ringJob.entry = self.entry
        ringJob:Wake()
        return
    end
    self:StartMoving()
    if self.entry.gameEdit then Follow(self, true) end
end

local function HandleUp(self, button)
    if button == "LeftButton" and not dragged[self] then Select(self.entry) end
end

-- A drop gives the window its place at once.
local function HandleDropped(self)
    local entry = self.entry
    if ringJob and ringJob.entry == entry then
        ringJob:Sleep()
        ringJob.entry = nil
        LayHandle(entry)
        if selected == entry then Refresh() end
        return
    end
    if entry.gameEdit then Follow(self, false) end
    local left, top = Plain(self:GetLeft()), Plain(self:GetTop())
    if not (left and top) then return end
    if Fixed(entry) then
        LayHandle(entry)
        return
    end
    -- A gameEdit piece snaps as the game's pieces did: home near its own spot, else to the bars.
    if entry.gameEdit and ns.SnapPieceDrop then
        local x, y = ns.SnapPieceDrop(entry.key, self)
        if x == "home" then
            Reset(entry)
            LayHandle(entry)
            if selected == entry then Refresh() end
            return
        end
        left, top = x or left, y or top
    end
    SetPlace(entry, left, top)
    -- A window sharing the place moves with it.
    local leader = Leader(entry)
    for _, other in ipairs(WINDOWS) do
        if handles[other.key] and (other == entry or Leader(other) == leader) then LayHandle(other) end
    end
    PlaceAll()
    if selected == entry then Refresh() end
end

local function Handle(entry)
    local handle = handles[entry.key]
    if handle then return handle end
    handle = CreateFrame("Frame", nil, UIParent)
    handle.entry = entry
    -- Over the windows it stands for, under our mode window and dialogs; a band piece (the gryphons) over the game's
    -- boxes but under the band's smaller ones (key ring, latency bar, micro menu at 1010).
    local strata, level = "DIALOG", 50
    if entry.gameEdit then strata, level = "MEDIUM", 1004 end
    handle:SetFrameStrata(strata)
    handle:SetFrameLevel(level)
    ns.MakeDraggable(handle, HandleDropped)
    handle:SetScript("OnDragStart", HandleDragStart)
    handle:SetScript("OnMouseDown", HandleDown)
    handle:SetScript("OnMouseUp", HandleUp)
    -- Edit mode's selection box over it; the mouse stays the placeholder's.
    local sel = ns.band.SelectionHandle(handle, entry.label)
    sel:SetFrameStrata(strata)
    sel:SetFrameLevel(level + 1)
    sel:EnableMouse(false)
    sel:Show()
    handle.sel = sel
    handles[entry.key] = handle
    return handle
end

-- One window's placeholder up or down; its dialog goes with it.
local function ShowHandle(entry, on)
    -- A window a mover holds has no box here: it places that window.
    if on and (ns.MoverHolds(ns.WindowFrame(entry)) or not Worn(entry)) then on = false end
    if on then
        Handle(entry)
        LayHandle(entry)
        handles[entry.key]:Show()
        DressHandles()
    elseif handles[entry.key] then
        handles[entry.key]:Hide()
        if selected == entry and dialog then dialog:Hide() end
    end
end

-- Shared with UI/WindowsEditMode.lua, the mode window around these placeholders.
ns.windowEdit = {
    WINDOWS = WINDOWS, Return = Return, Clean = Clean, ValidFlag = ValidFlag, Places = Places, Scales = Scales, Freed = Freed,
    Ratio = Ratio, PlaceAll = PlaceAll, LayHandle = LayHandle, Refresh = Refresh, IsFree = IsFree, Full = Full, Reset = Reset,
    STRIP_LEFT = STRIP_LEFT, STRIP_LIFT = STRIP_LIFT, StripOf = function(frame) return strips[frame] end,
    ShowHandle = ShowHandle, Set = Set, DialogKeys = DialogKeys, PlaceOf = PlaceOf, SetFree = SetFree, SetPlace = SetPlace, Worn = Worn,
    Leader = Leader, SizeKey = SizeKey, DrawnSize = DrawnSize, SaveFrom = SaveFrom,
    HideDialog = function() if dialog then dialog:Hide() end end,
    -- The drags (UI/WindowDrags.lua): the tables they keep with us.
    Moving = moving, EntryOf = entryOf, Strips = strips, ClampWas = clampWas, STRIP_RIGHT = STRIP_RIGHT, STRIP_H = STRIP_H,
}

-- The map's lock and option switch its Movable anytime too.
ns.OnToggle(function(key) if key == MAP_ENTRY.toggle or key == "mapFade" or key == "worldMap" then Refresh() end end)
