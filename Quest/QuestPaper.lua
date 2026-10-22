local _, ns = ...

-- The game's own quest log page (its parchment) under a quest list of ours, an option per window; the 1.x dark
-- stone stays the default. The page is one picture the size of the game's pane, stretched to the host.

local PAGE = "QuestLog-main-background"
ns.QUEST_PAGE_ATLAS = PAGE

-- A page filling the host, shown while db[key] is on.
function ns.QuestPaper(host, key)
    local tex = ns.OwnTexture(host, "questPaper", "BACKGROUND", -1)
    if ns.Once(host, "questPaper") then
        tex:SetAtlas(PAGE)
        tex:SetAllPoints(host)
    end
    ns.SetShownIf(tex, ns.db[key] == true)
    return tex
end
