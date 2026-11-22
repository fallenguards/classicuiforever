local _, ns = ...
local L = ns.L

-- Era's Loot Rolls window (Classic LootHistory.xml) in place of the game's /loot window: a tooltip box with the bag icon
-- and its title, every drop a row (its icon in the small loot frame; winner, roll type and roll once done), + on a row
-- lists each player's roll. Fed by the game's loot history, newest encounter first; sized both ways from Era's tab.

local P = ns.panels
local A = P.after

-- Era's window: 210 x 175, 103 tall at the least, its foot 180 up and 280 right of the screen's middle.
local ERA_W, ERA_H, MIN_H = 210, 175, 103
local MAX_W, MAX_H = 1000, 1200
local HOME_X, HOME_Y = 280, 180
local LIST_RIGHT, LIST_FOOT = 28, 7
-- Rows: an item 36 tall, 5 between items, its players 16 tall from 2 under it, 1 between.
local ITEM_H, ITEM_GAP, PLAYER_H, PLAYER_TOP, PLAYER_GAP, FIRST_TOP = 36, 5, 16, 2, 1, 2
local GRIP_X, GRIP_Y = -3, 3
-- Era's resize tab: 32 x 16 under the foot, 7 of it over the edge.
local SIZE_TAB = "Interface\\RaidFrame\\Raid-Move-Down"
local TAB_W, TAB_H, TAB_UP = 32, 16, 7
-- The corner grip shows only with the cursor this close to the corner (inside), or this far past it (outside).
local NEAR_IN, NEAR_OUT = 24, 4

local TOAST = "Interface\\LootFrame\\LootToast"
local DIVIDER_COORDS = { 0.00097656, 0.17773438, 0.74218750, 0.89062500 }
local BORDER_LEFT = { 0.79101563, 0.80664063, 0.57421875, 0.69921875 }
local BORDER_RIGHT = { 0.73242188, 0.74804688, 0.80859375, 0.93359375 }
local BORDER_MID = { 0.75, 0.764648438, 0.80859375, 0.93359375 }
local ICON_BORDER = { 0.62792969, 0.65722656, 0.87500000, 0.99218750 }
local BAG = "Interface\\Minimap\\Tracking\\Banker"
local TIP_DIVIDER = "Interface\\Common\\UI-TooltipDivider"
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
local WIN_MARK = "Interface\\Buttons\\UI-CheckBox-Check"
local TOGGLE = { plus = "Interface\\Buttons\\UI-PlusButton-", minus = "Interface\\Buttons\\UI-MinusButton-" }
local DICE, COIN, PASS_ICON = "Interface\\Buttons\\UI-GroupLoot-Dice-Up", "Interface\\Buttons\\UI-GroupLoot-Coin-Up",
    "Interface\\Buttons\\UI-GroupLoot-Pass-Up"
local RED = { 1, 0.1, 0.1 }

local TIP = { text = L["UI_RESIZE"], r = 1, g = 1, b = 1, lines = { { L["UI_RESIZE_TIP"], nil, nil, nil, true } } }

local win            -- our window, made on first use
local expanded = {}  -- "encounter:drop" -> true

------------------------------------------------------------------ the game's loot history

-- Each drop of every encounter, newest encounter first, in the game's order within one.
local function Drops()
    local list, encounters = {}, {}
    for i, encounter in ipairs(C_LootHistory.GetAllEncounterInfos() or ns.EMPTY) do encounters[i] = encounter end
    table.sort(encounters, function(a, b) return (a.startTime or 0) > (b.startTime or 0) end)
    for _, encounter in ipairs(encounters) do
        local id = encounter.encounterID
        for _, drop in ipairs(C_LootHistory.GetSortedDropsForEncounter(id) or ns.EMPTY) do
            local info = C_LootHistory.GetSortedInfoForDrop(id, drop.lootListKey) or drop
            list[#list + 1] = { encounter = id, key = id .. ":" .. tostring(drop.lootListKey), info = info }
        end
    end
    return list
end

-- A roll's icon and tooltip word, as Era's (need, greed, pass); nothing before the player rolls.
local function RollArt(state)
    local S = Enum.EncounterLootDropRollState
    if state == S.NeedMainSpec or state == S.NeedOffSpec then return DICE, NEED end
    if state == S.Greed then return COIN, GREED end
    if state == S.Pass then return PASS_ICON, PASS end
    if S.Transmog and state == S.Transmog then return COIN, GREED end
end

local function Done(info) return info.winner ~= nil or info.allPassed == true end

local function WinnerRoll(info)
    for _, roll in ipairs(info.rollInfos or ns.EMPTY) do
        if roll.isWinner then return roll end
    end
end

-- Era lists a player once the roll is done only if they rolled (or are you); while it runs, everyone.
local function Shown(info, roll)
    return roll.isSelf or roll.roll ~= nil or not Done(info)
end

local function ClassRGB(class)
    local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if color then return color.r, color.g, color.b end
    return 1, 1, 1
end

------------------------------------------------------------------ rows

local function Piece(row, layer, sub, coords, w, h)
    local tex = row:CreateTexture(nil, layer, nil, sub)
    tex:SetTexture(TOAST)
    tex:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    tex:SetSize(w, h)
    return tex
end

local function SetToggle(button, open)
    local base = open and TOGGLE.minus or TOGGLE.plus
    button:SetNormalTexture(base .. "UP")
    button:SetPushedTexture(base .. "Down")
    button:SetDisabledTexture(base .. "Disabled")
end

local function ItemRow(parent)
    local row = ns.NewFrame("Button", nil, parent)
    row:SetHeight(ITEM_H)
    row:SetHitRectInsets(20, 0, 0, 0)
    local divider = Piece(row, "BACKGROUND", 1, DIVIDER_COORDS, 181, 38)
    divider:SetPoint("TOPLEFT", row, "TOPLEFT", -2, 1)
    divider:SetPoint("TOPRIGHT", row, "TOPRIGHT", 2, 1)
    row.icon = row:CreateTexture(nil, "BACKGROUND", nil, 3)
    row.icon:SetSize(28, 28)
    row.icon:SetPoint("LEFT", row, "LEFT", 23, -2)
    row.left = Piece(row, "BACKGROUND", 3, BORDER_LEFT, 16, 32)
    row.left:SetPoint("LEFT", row.icon, "RIGHT", 3, 0)
    row.right = Piece(row, "BACKGROUND", 3, BORDER_RIGHT, 16, 32)
    row.right:SetPoint("RIGHT", row, "RIGHT", 0, -2)
    local mid = Piece(row, "BACKGROUND", 3, BORDER_MID, 16, 32)
    mid:SetPoint("TOPLEFT", row.left, "TOPRIGHT")
    mid:SetPoint("BOTTOMRIGHT", row.right, "BOTTOMLEFT")
    row.iconBorder = Piece(row, "ARTWORK", 0, ICON_BORDER, 30, 30)
    row.iconBorder:SetPoint("CENTER", row.icon, "CENTER")
    row.name = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    row.name:SetJustifyH("LEFT")
    row.name:SetJustifyV("MIDDLE")
    row.name:SetPoint("TOPLEFT", row.left, "TOPLEFT", 2, -2)
    row.roll = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    row.roll:SetJustifyH("RIGHT")
    row.roll:SetSize(24, 16)
    row.roll:SetPoint("BOTTOMRIGHT", row.right, "BOTTOMRIGHT", -2, 2)
    row.rollType = row:CreateTexture(nil, "ARTWORK")
    row.rollType:SetSize(16, 16)
    row.winner = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    row.winner:SetJustifyH("LEFT")
    row.winner:SetPoint("TOPLEFT", row.left, "LEFT", 2, 0)
    row.winner:SetPoint("BOTTOMRIGHT", row.rollType, "BOTTOMLEFT", -2, 0)
    row.toggle = ns.NewFrame("Button", nil, row)
    row.toggle:SetSize(14, 14)
    row.toggle:SetPoint("LEFT", row, "LEFT", 5, 0)
    row.toggle:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight", "ADD")
    row.toggle:SetScript("OnClick", function() if row.key then ns.LootRollsToggle(row.key) end end)
    row:SetScript("OnEnter", function(self)
        if not self.link then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetHyperlink(self.link)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row:SetScript("OnClick", function(self)
        if self.link and IsModifiedClick("CHATLINK") then HandleModifiedItemClick(self.link) end
    end)
    return row
end

-- The item's icon, name and colour; a link the client has not loaded yet reads as Era's retrieving line, in red.
local function FillItem(row, drop)
    local info = drop.info
    local open = expanded[drop.key] == true
    row.link = info.itemHyperlink
    row.key = drop.key
    SetToggle(row.toggle, open)
    local name, quality, texture
    if row.link then
        local got = { C_Item.GetItemInfo(row.link) }
        name, quality, texture = got[1], got[3], got[10]
    end
    local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if name then
        row.icon:SetTexture(texture)
        row.name:SetText(name)
        local r, g, b = 1, 1, 1
        if color then r, g, b = color.r, color.g, color.b end
        row.iconBorder:SetVertexColor(r, g, b)
        row.name:SetVertexColor(r, g, b)
    else
        row.icon:SetTexture(QUESTION)
        row.name:SetText(RETRIEVING_DATA or "")
        row.iconBorder:SetVertexColor(RED[1], RED[2], RED[3])
        row.name:SetVertexColor(RED[1], RED[2], RED[3])
    end
    -- Done and folded: the name above, the winner, roll type and roll on the box's foot line.
    local foot = Done(info) and not open
    if foot then
        ns.SetTwoPointsIf(row.name, "TOPLEFT", row.left, "TOPLEFT", 2, -2, "BOTTOMRIGHT", row.right, "RIGHT", -2, 0)
    else
        ns.SetTwoPointsIf(row.name, "TOPLEFT", row.left, "TOPLEFT", 2, -2, "BOTTOMRIGHT", row.right, "BOTTOMRIGHT", -2, 2)
    end
    row.roll:SetShown(foot and info.winner ~= nil)
    row.rollType:SetShown(foot)
    row.winner:SetShown(foot)
    if not foot then return end
    if info.winner then
        local won = WinnerRoll(info)
        row.rollType:SetTexture((RollArt(won and won.state)))
        local roll = info.winner.roll or (won and won.roll)
        if roll then
            ns.SetPointOnce(row.rollType, "RIGHT", row.roll, "LEFT", 2, -1)
        else
            ns.SetPointOnce(row.rollType, "BOTTOMRIGHT", row.right, "BOTTOMRIGHT", -2, 1)
        end
        row.roll:SetText(roll or "")
        row.winner:SetText(info.winner.playerName or UNKNOWNOBJECT)
        row.winner:SetVertexColor(ClassRGB(info.winner.playerClass))
    else
        row.rollType:SetTexture(PASS_ICON)
        ns.SetPointOnce(row.rollType, "BOTTOMRIGHT", row.right, "BOTTOMRIGHT", -2, 1)
        row.winner:SetText(LOOT_HISTORY_ALL_PASSED)
        row.winner:SetVertexColor(RED[1], RED[2], RED[3])
    end
end

local function PlayerRow(parent)
    local row = ns.NewFrame("Button", nil, parent)
    row:SetHeight(PLAYER_H)
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetColorTexture(1, 1, 1, 0.08)
    row.bg:SetPoint("TOPLEFT", row, "TOPLEFT")
    row.bg:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 10, 0)
    row.roll = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    row.roll:SetJustifyH("RIGHT")
    row.roll:SetSize(24, 16)
    row.roll:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    row.icon = ns.NewFrame("Frame", nil, row)
    row.icon:SetSize(16, 16)
    row.icon.tex = row.icon:CreateTexture(nil, "ARTWORK")
    row.icon.tex:SetAllPoints()
    row.icon:SetScript("OnEnter", function(self)
        if not self.tip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.tip, nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    row.icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row.name = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    row.name:SetJustifyH("LEFT")
    row.name:SetPoint("LEFT", row, "LEFT", 25, 0)
    row.name:SetPoint("RIGHT", row.icon, "LEFT", -2, 0)
    row.mark = row:CreateTexture(nil, "ARTWORK")
    row.mark:SetTexture(WIN_MARK)
    row.mark:SetSize(16, 16)
    row.mark:SetPoint("RIGHT", row.name, "LEFT", -1, 0)
    return row
end

-- One player's roll (roll nil: the all passed line), Era's alternate shading on odd lines.
local function FillPlayer(row, roll, index)
    row.bg:SetShown(roll == nil or index % 2 == 1)
    if not roll then
        row.name:SetText(LOOT_HISTORY_ALL_PASSED)
        row.name:SetVertexColor(RED[1], RED[2], RED[3])
        row.icon.tex:SetTexture(PASS_ICON)
        row.icon.tip = PASS
        row.roll:SetText("")
        ns.SetPointOnce(row.icon, "RIGHT", row, "RIGHT", -2, -1)
        row.mark:Hide()
        return
    end
    row.name:SetText(roll.playerName or UNKNOWNOBJECT)
    row.name:SetVertexColor(ClassRGB(roll.playerClass))
    local art, tip = RollArt(roll.state)
    row.icon.tex:SetTexture(art)
    row.icon.tip = tip
    if not art then
        row.roll:SetText("... ")
        ns.SetPointOnce(row.icon, "RIGHT", row.roll, "LEFT", 2, -1)
    elseif not roll.roll then
        row.roll:SetText("")
        ns.SetPointOnce(row.icon, "RIGHT", row, "RIGHT", -2, -1)
    else
        row.roll:SetText(roll.roll)
        ns.SetPointOnce(row.icon, "RIGHT", row.roll, "LEFT", 2, -1)
    end
    row.mark:SetShown(roll.isWinner == true)
end

------------------------------------------------------------------ the window

local function Pool(list, make)
    list.used = 0
    return function()
        list.used = list.used + 1
        local row = list[list.used]
        if not row then
            row = make(win.child)
            list[list.used] = row
        end
        return row
    end
end

-- Every row again, as Era's full update: items, an open item's players under it, the list's height and scroll.
local function Lay()
    if not (win and win:IsShown()) then return end
    local width = win.scroll:GetWidth()
    local nextItem, nextPlayer = Pool(win.items, ItemRow), Pool(win.players, PlayerRow)
    local y = -FIRST_TOP
    for _, drop in ipairs(Drops()) do
        local row = nextItem()
        ns.SetPointOnce(row, "TOPLEFT", win.child, "TOPLEFT", 0, y)
        row:SetWidth(width)
        FillItem(row, drop)
        row:Show()
        y = y - ITEM_H
        if expanded[drop.key] then
            local info, index, any = drop.info, 0, false
            local function Line(roll)
                index = index + 1
                local line = nextPlayer()
                y = y - (any and PLAYER_GAP or PLAYER_TOP)
                any = true
                ns.SetPointOnce(line, "TOPLEFT", win.child, "TOPLEFT", 0, y)
                line:SetWidth(width)
                FillPlayer(line, roll, index)
                line:Show()
                y = y - PLAYER_H
            end
            if Done(info) and not info.winner then
                Line(nil)
            else
                for _, roll in ipairs(info.rollInfos or ns.EMPTY) do
                    if Shown(info, roll) then Line(roll) end
                end
            end
        end
        y = y - ITEM_GAP
    end
    for i = win.items.used + 1, #win.items do win.items[i]:Hide() end
    for i = win.players.used + 1, #win.players do win.players[i]:Hide() end
    local height = -y
    win.child:SetSize(width, math.max(height, 1))
    win.bar:SetRange(height - win.scroll:GetHeight(), ITEM_H + ITEM_GAP)
end

local function LaySoon() ns.Sched.NextFrame("lootRolls.lay", Lay) end

local function Clamp(value, low, high) return math.max(low, math.min(high, value)) end

local function SavedSize()
    local w, h = tonumber(ns.db.lootHistoryW) or 0, tonumber(ns.db.lootHistoryH) or 0
    if w > 0 and h > 0 then return Clamp(w, ERA_W, MAX_W), Clamp(h, MIN_H, MAX_H) end
    return ERA_W, ERA_H
end

local LOOT_EVENTS = { "LOOT_HISTORY_UPDATE_ENCOUNTER", "LOOT_HISTORY_UPDATE_DROP", "LOOT_HISTORY_CLEAR_HISTORY",
    "GET_ITEM_INFO_RECEIVED" }

local function Header(frame)
    local bag = frame:CreateTexture(nil, "ARTWORK")
    bag:SetTexture(BAG)
    bag:SetSize(18, 18)
    bag:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -5)
    local label = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("LEFT", bag, "RIGHT", 3, 1)
    label:SetText(LOOT_ROLLS)
    frame.label = label
    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetTexture(TIP_DIVIDER)
    divider:SetHeight(8)
    divider:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -20)
    divider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -20)
    frame.divider = divider
    local close = ns.NewFrame("Button", nil, frame)
    close:SetSize(32, 32)
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function() frame:Hide() end)
    ns.SkinCloseButton(close, true)
    frame.close = close
    local drag = ns.NewFrame("Button", nil, frame)
    drag:SetPoint("TOPLEFT", frame, "TOPLEFT")
    drag:SetPoint("BOTTOMRIGHT", close, "BOTTOMLEFT")
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function() frame:StartMoving() end)
    drag:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
end

local function List(frame)
    local scroll = ns.NewFrame("ScrollFrame", nil, frame)
    scroll:SetPoint("TOPLEFT", frame.divider, "BOTTOMLEFT", 0, 1)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -LIST_RIGHT, LIST_FOOT)
    local child = ns.NewFrame("Frame", nil, scroll)
    child:SetSize(1, 1)
    scroll:SetScrollChild(child)
    local bar = ns.ClassicScrollBar(frame, scroll, function(value) scroll:SetVerticalScroll(value) end)
    local back = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    back:SetColorTexture(0, 0, 0, 1)
    back:SetPoint("TOPLEFT", bar.up, "TOPLEFT", -2, 2)
    back:SetPoint("BOTTOMRIGHT", bar.down, "BOTTOMRIGHT", 0, -2)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(_, delta) bar:SetValue(bar:GetValue() - delta * (ITEM_H + ITEM_GAP)) end)
    scroll:SetScript("OnSizeChanged", LaySoon)
    frame.scroll, frame.child, frame.bar = scroll, child, bar
end

local Cursor = ns.UICursor

local function SaveSize(frame) ns.db.lootHistoryW, ns.db.lootHistoryH = frame:GetSize() end
local function EraSize(frame)
    ns.db.lootHistoryW, ns.db.lootHistoryH = 0, 0
    frame:SetSize(ERA_W, ERA_H)
end

-- The tab's drag: up and down the height, as Era's; sideways the width, evenly both sides (top and middle kept).
local tabDrag   -- cursor, size and top at the press
local tabJob
local function TabStop()
    if not tabDrag then return end
    tabDrag = nil
    tabJob:Sleep()
    SaveSize(win)
end
local function TabStep()
    if not tabDrag then return tabJob:Sleep() end
    if not IsMouseButtonDown("LeftButton") then return TabStop() end
    local x, y = Cursor()
    local w = Clamp(tabDrag.w + 2 * (x - tabDrag.x), ERA_W, math.min(MAX_W, UIParent:GetWidth()))
    local h = Clamp(tabDrag.h + tabDrag.y - y, MIN_H, math.min(MAX_H, tabDrag.top))
    win:SetSize(w, h)
end
tabJob = ns.Sched.Job({ name = "lootRolls.tabDrag", every = 0, awake = false, fn = TabStep })

local function SizeTab(frame)
    local tab = ns.NewFrame("Button", nil, frame)
    tab:SetSize(TAB_W, TAB_H)
    tab:SetPoint("TOP", frame, "BOTTOM", 0, TAB_UP)
    tab:SetNormalTexture(SIZE_TAB)
    tab:RegisterForClicks("RightButtonUp")
    tab:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" or tabDrag then return end
        local x, y = Cursor()
        local w, h = frame:GetSize()
        local middle, top = frame:GetCenter(), frame:GetTop()
        tabDrag = { x = x, y = y, w = w, h = h, top = top }
        ns.SetPointOnce(frame, "TOP", UIParent, "BOTTOMLEFT", middle, top)
        GameTooltip:Hide()
        tabJob:Wake()
    end)
    tab:SetScript("OnMouseUp", function(_, button) if button == "LeftButton" then TabStop() end end)
    tab:SetScript("OnClick", function() EraSize(frame) end)
    ns.AttachTip(tab, TIP)
    frame.sizeTab = tab
end

-- Near the corner only (or while it sizes): Era's window has none.
local function GripNear(frame)
    if frame.gripHeld then return true end
    local right, bottom = frame:GetRight(), frame:GetBottom()
    if not (right and bottom) then return false end
    local x, y = Cursor()
    return x > right - NEAR_IN and x < right + NEAR_OUT and y < bottom + NEAR_IN and y > bottom - NEAR_OUT
end

local function Grip(frame)
    local grip = ns.GripButton(frame)
    grip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", GRIP_X, GRIP_Y)
    grip:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" then return end
        frame.gripHeld = true
        frame:StartSizing("BOTTOMRIGHT", true)
    end)
    grip:SetScript("OnMouseUp", function(_, button)
        if button ~= "LeftButton" then return end
        frame.gripHeld = nil
        frame:StopMovingOrSizing()
        SaveSize(frame)
    end)
    grip:SetScript("OnClick", function() EraSize(frame) end)
    ns.AttachTip(grip, TIP)
    grip:Hide()
    frame.grip = grip
    ns.Sched.Attach(frame, { name = "lootRolls.grip", every = 0.05, fn = function()
        ns.SetShownIf(grip, GripNear(frame))
    end })
end

local function Make()
    local frame = ns.NewFrame("Frame", "ForeverClassicUILootRolls", UIParent)
    frame:Hide()
    frame:SetPoint("BOTTOM", UIParent, "BOTTOM", HOME_X, HOME_Y)
    frame:SetSize(SavedSize())
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:SetResizeBounds(ERA_W, MIN_H, MAX_W, MAX_H)
    frame:SetClampedToScreen(true)
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    ns.TipRim(frame, 0, 0, 0, 0)
    Header(frame)
    List(frame)
    SizeTab(frame)
    Grip(frame)
    frame.items, frame.players = {}, {}
    ns.EventFrame(LOOT_EVENTS, function() if frame:IsShown() then LaySoon() end end)
    frame:SetScript("OnShow", Lay)
    ns.CloseOnEscape(frame)
    return frame
end

local function Window()
    win = win or Make()
    return win
end
ns.LootRollsWindow = Window

-- A row's + or -: its players open or fold, as Era's.
function ns.LootRollsToggle(key)
    expanded[key] = not expanded[key] or nil
    Lay()
end

------------------------------------------------------------------ in place of the game's

local function Wanted() return P.Dressing("panelLootHistory") end

-- The game's window waits under a hidden frame of ours: its shows never reach the screen, so its OnShow (which takes
-- the gamepad's focus) never runs. Hidden from our code instead, it ran its OnHide in our name and kept that focus.
local game, stash, stashedFrom
local function Park()
    if stashedFrom or game:IsVisible() then return end
    if not stash then
        stash = ns.NewFrame("Frame")
        stash:Hide()
    end
    stashedFrom = { game:GetParent(), game:GetFrameStrata() }
    game:SetParent(stash)
end

-- Unchecked: back under its parent, shut (the shown mark the game set on it while parked is cleared unseen first).
local function Unpark()
    if not stashedFrom then return end
    if game:IsShown() then game:Hide() end
    game:SetParent(stashedFrom[1])
    game:SetFrameStrata(stashedFrom[2])
    stashedFrom = nil
end

-- /loot: the game's toggle ran on its parked window; ours toggles.
local function Toggled()
    if not Wanted() then
        Unpark()
        if win then win:Hide() end
        return
    end
    Park()
    local frame = Window()
    frame:SetShown(not frame:IsShown())
end

-- A chat loot link: ours opens with that encounter's drops open, as the game's opens on it.
local function OpenTo(encounterID)
    if not Wanted() then return Unpark() end
    Park()
    local any = false
    for _, drop in ipairs(Drops()) do
        if drop.encounter == encounterID then
            expanded[drop.key] = true
            any = true
        end
    end
    if not any then return end
    local frame = Window()
    if frame:IsShown() then Lay() else frame:Show() end
end

function A.GroupLootHistoryFrame(frame)
    if not ns.Once(frame, "eraLootRolls") then return end
    game = frame
    Park()
    ns.HookGlobal("ToggleLootHistoryFrame", Toggled)
    ns.HookGlobal("SetLootHistoryFrameToEncounter", OpenTo)
end
