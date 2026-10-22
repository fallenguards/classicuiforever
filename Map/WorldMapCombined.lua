local _, ns = ...
local L = ns.L

-- The classic map's combined layout (#73): Era's sheets carry the 3.x quest map, a list column beside the picture and
-- two pages under it, with our quest list, text and rewards on them (Quest/QuestMapList.lua). Unlocked, the picture's
-- corner scales it (aspect kept) with the window following; the divider widens the list inside the window as it stands.

local MC = {}
ns.MapCombined = MC

local GRIP_IN = 2          -- the corner grip's bottom right in from the picture's corner
local EDGE_OUT = 2         -- the divider grip's reach past the divider's art, each side
local OVER_PICTURE = 3     -- our hosts' level over the picture's
local SNAP, EDGE_SNAP = 0.01, 0.005
local LIST_MIN, LIST_MAX, PAGES_MIN, PAGES_MAX = 220, 640, 120, 4000
local HOST_KEYS = { "list", "pageL", "pageR" }

local TIP = { text = L["UI_MAP_SHARE"], r = 1, g = 1, b = 1, lines = { { L["UI_MAP_SHARE_TIP"], nil, nil, nil, true } } }
local EDGE_TIP = { text = L["UI_MAP_LIST_WIDTH"], r = 1, g = 1, b = 1, lines = { { L["UI_MAP_LIST_WIDTH_TIP"], nil, nil, nil, true } } }

local hosts         -- list, pageL, pageR, foot: ours on the map, placed by the boxes
local grip, edge
local drag = {}     -- the drag under way: the map, its grip, the shape laid, the grab offsets, the window's size
local job
local mapEntry
local footBox = {}
local shape = {}    -- the shape the saved numbers make; a new table as any of them changes

local function LM() return ns.MapLarge end

-- A saved number, else the sheets' own (0 or nil).
local function Saved(key, own, low, high)
    local value = tonumber(ns.db[key]) or 0
    if value <= 0 then return own end
    return math.max(low, math.min(high, value))
end

-- The share saved, else the sheets' own.
function MC.Share() return LM().ClampShare(Saved("mapQuestShare", nil, 0, 1)) end

-- The shape the saved numbers make (the picture's share, the list's width, the pages' height): the same table while
-- none changes, so the art and the boxes rebuild only then.
function MC.Shape()
    local share = MC.Share()
    local listW = Saved("mapQuestListW", LM().NATIVE_LIST_W, LIST_MIN, LIST_MAX)
    local pagesH = Saved("mapQuestPagesH", LM().NATIVE_PAGES_H, PAGES_MIN, PAGES_MAX)
    if shape.share ~= share or shape.listW ~= listW or shape.pagesH ~= pagesH then
        shape = { share = share, listW = listW, pagesH = pagesH }
    end
    return shape
end

-- The shape the picture is laid with: the one before a drag until it ends (its lay refits the picture once).
function MC.LaidShape() return drag.laid or MC.Shape() end

-- For the layout: the picture's box (the map's units from its top left, y down), the window's size and the scale the
-- box wears. The box keeps the laid shape's size, scaled to the share dragged now (1 outside a drag), so the picture
-- needs no refit until the drag ends.
function MC.PictureBox()
    local laid, live = MC.LaidShape(), MC.Shape()
    local box = LM().CombinedBoxes(laid).picture
    local k = live.share / laid.share
    local l, t = box[1] / k, box[2] / k
    local w, h = LM().CombinedSize(live)
    return l, t, l + box[3] - box[1], t + box[4] - box[2], w, h, k
end

local function Entry()
    if mapEntry then return mapEntry end
    for _, entry in ipairs(ns.windowEdit.WINDOWS) do
        if entry.key == "map" then mapEntry = entry end
    end
    return mapEntry
end

-- Unlocked, windowed, held by no other addon, out of a fight (the lay waits one out).
local function Usable(map)
    local W, entry = ns.windowEdit, Entry()
    if not entry or not W.IsFree(entry) or W.Full(entry, map) or ns.MoverHolds(map) then return false end
    return not InCombatLockdown()
end

local function Cursor(map)
    local x, y = GetCursorPosition()
    local s = map:GetEffectiveScale()
    return x / s, y / s
end

local function Stop()
    if not drag.map then return end
    local which = drag.grip
    wipe(drag)
    job:Sleep()
    which:SetButtonState("NORMAL", false)
    ns.MapFight.Relay()
end

-- The picture's corner on the cursor (less where it was grabbed): its share from the hole's top left, snapped.
local function CornerStep(x, y, left, top)
    local hole = LM().CombinedBoxes(MC.Shape()).picture
    local share = LM().ShareFor(x - drag.dx - (left + hole[1]), (top - hole[2]) - (y + drag.dy))
    share = math.floor(share / SNAP + 0.5) * SNAP
    if math.abs(share - MC.Share()) < SNAP / 2 then return end
    ns.db.mapQuestShare = share
end

-- The divider on the cursor: the list takes the width left of it, the picture the rest (aspect kept), the pages the
-- height left under the picture; the window stays as it was.
local function EdgeStep(x)
    local lm, W, H = LM(), drag.w, drag.h
    local listW = math.max(LIST_MIN, math.min(LIST_MAX, drag.listW - (x - drag.x)))
    local share = math.min(lm.ShareForWidth(W - lm.SIDE_ROOM - listW), lm.ShareForHeight(H - lm.FOOT_ROOM - PAGES_MIN))
    share = math.floor(share / EDGE_SNAP + 0.5) * EDGE_SNAP
    local w, h = lm.PictureSize(share)
    local now = MC.Shape()
    if math.abs(share - now.share) < EDGE_SNAP / 2 then return end
    ns.db.mapQuestShare, ns.db.mapQuestListW, ns.db.mapQuestPagesH = share, W - lm.SIDE_ROOM - w, H - lm.FOOT_ROOM - h
end

-- The map's pass that frame lays the art, our hosts and the picture (scaled to it) at the new shape.
local function Step()
    local map = drag.map
    if not map then return end
    if not IsMouseButtonDown("LeftButton") then
        Stop()
        return
    end
    local left, top = map:GetLeft(), map:GetTop()
    if not (left and top) then return end
    local x, y = Cursor(map)
    if drag.grip == edge then EdgeStep(x) else CornerStep(x, y, left, top) end
end

job = ns.Sched.Job({ name = "map.shareDrag", every = 0, awake = false, fn = Step })

local function Start(map, which)
    if drag.map or not Usable(map) then return end
    local left, top = map:GetLeft(), map:GetTop()
    if not (left and top) then return end
    local x, y = Cursor(map)
    local now = MC.Shape()
    local box = LM().CombinedBoxes(now).picture
    drag.map, drag.grip, drag.laid = map, which, now
    drag.dx, drag.dy = x - (left + box[3]), (top - box[4]) - y
    drag.x, drag.listW = x, now.listW
    drag.w, drag.h = LM().CombinedSize(now)
    which:SetButtonState("PUSHED", true)
    GameTooltip:Hide()
    job:Wake()
end

-- The sheets' own shape again: either grip's right click, and the window's own size reset (UI/WindowGrips.lua).
function MC.Reset()
    local db = ns.db
    if (db.mapQuestShare or 0) == 0 and (db.mapQuestListW or 0) == 0 and (db.mapQuestPagesH or 0) == 0 then return end
    db.mapQuestShare, db.mapQuestListW, db.mapQuestPagesH = 0, 0, 0
    ns.MapFight.Relay()
end

local function Handle(button, map, tip)
    button:SetScript("OnClick", MC.Reset)
    button:SetScript("OnMouseDown", function(_, press) if press == "LeftButton" then Start(map, button) end end)
    button:SetScript("OnMouseUp", function(_, press) if press == "LeftButton" then Stop() end end)
    ns.AttachTip(button, tip)
    button:Hide()
end

local function MakeGrips(map)
    grip = ns.GripButton(map)
    Handle(grip, map, TIP)
    -- The divider: no art of its own, a light band under the mouse.
    edge = ns.NewFrame("Button", nil, map)
    ns.MarkWindowPiece(edge)
    local band = edge:CreateTexture(nil, "HIGHLIGHT")
    band:SetColorTexture(1, 1, 1, 0.25)
    band:SetAllPoints(edge)
    edge:RegisterForClicks("RightButtonUp")
    Handle(edge, map, EDGE_TIP)
end

local function Hosts(map)
    if hosts then return hosts end
    hosts = {}
    for _, key in ipairs(HOST_KEYS) do
        hosts[key] = ns.NewFrame("Frame", nil, map)
        hosts[key]:Hide()
    end
    hosts.foot = ns.NewFrame("Frame", nil, map)
    hosts.foot:Hide()
    MakeGrips(map)
    ns.QuestMapList.Attach(hosts)
    return hosts
end

local function Place(frame, box, level)
    ns.SetPointIf(frame, "TOPLEFT", frame:GetParent(), "TOPLEFT", box[1], -box[2])
    ns.SetSizeIf(frame, box[3] - box[1], box[4] - box[2])
    ns.SetLevelIf(frame, level)
    ns.SetShownIf(frame, true)
end

-- Our hosts on the boxes, the grips at the picture's corner and on the divider; boxes nil puts them all away.
function MC.Lay(map, boxes)
    local h = Hosts(map)
    if not boxes then
        for _, key in ipairs(HOST_KEYS) do ns.SetShownIf(h[key], false) end
        ns.SetShownIf(h.foot, false)
        ns.SetShownIf(grip, false)
        ns.SetShownIf(edge, false)
        return
    end
    local level = map.ScrollContainer:GetFrameLevel() + OVER_PICTURE
    for _, key in ipairs(HOST_KEYS) do Place(h[key], boxes[key], level) end
    local _, bottom = LM().CombinedSize(MC.Shape())
    footBox[1], footBox[2], footBox[3], footBox[4] = boxes.picture[1], boxes.list[4], boxes.list[3], bottom
    Place(h.foot, footBox, level)
    ns.QuestMapList.LayFoot()
    local pic, div = boxes.picture, boxes.divider
    local on = drag.map ~= nil or Usable(map)
    ns.SetLevelIf(grip, level + 1)
    ns.SetPointIf(grip, "BOTTOMRIGHT", map, "TOPLEFT", pic[3] - GRIP_IN, -(pic[4] - GRIP_IN))
    ns.SetShownIf(grip, on)
    ns.SetLevelIf(edge, level + 1)
    ns.SetPointIf(edge, "TOPLEFT", map, "TOPLEFT", div[1] - EDGE_OUT, -div[2])
    ns.SetSizeIf(edge, div[3] - div[1] + 2 * EDGE_OUT, div[4] - div[2])
    ns.SetShownIf(edge, on)
end

-- For the dev addon's mapcombo probe.
function MC.Pieces() return hosts, grip, edge end

-- Ours, kept when a fight's fade walks the map.
function MC.Keep(into)
    if not hosts then return end
    for _, key in ipairs(HOST_KEYS) do into[hosts[key]] = true end
    into[hosts.foot], into[grip], into[edge] = true, true, true
end
