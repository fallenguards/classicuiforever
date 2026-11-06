local _, ns = ...

-- The classic map's lay in a fight, from our code (Map/WorldMapClassic.lua LAY, the snippet, out of one): the map is no
-- protected frame, so its size and anchors take; its refit then runs as ours until the game's own next. t: Target().

function ns.LayMapInFight(t)
    local map = WorldMapFrame
    local canvas, pane = map.ScrollContainer, map.QuestLog
    if t.w then map:SetSize(t.w, t.h) end
    canvas:SetScale(t.k or 1)
    canvas:ClearAllPoints()
    canvas:SetPoint("TOPLEFT", map, "TOPLEFT", t.l, t.t)
    canvas:SetPoint("BOTTOMRIGHT", map, t.rp, t.r, t.b)
    if pane then
        pane:ClearAllPoints()
        pane:SetPoint(t.qp, map, t.qp, t.qx1, t.qy1)
        pane:SetPoint("BOTTOMRIGHT", map, t.qr, t.qx2, t.qy2)
    end
    local details = pane and pane.DetailsFrame
    if details then details:SetHeight(t.dh) end
    local text = details and details.ScrollFrame
    if text then
        ns.SetPointOnce(text, "TOPLEFT", details, "TOPLEFT", t.dtx, t.dty)
        text:SetHeight(t.dth)
    end
end
