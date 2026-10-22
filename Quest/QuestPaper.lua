local _, ns = ...

-- The map's quest lists' looks: the game's own quest log page (its parchment) under a list of ours, an option per
-- window (the 1.x dark stone stays the default), and the lists' fonts at the size the player picks.

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

-- The map's quest lists' text (the combined map's rows and the side tab's): the game's fonts at the size offset the
-- player picks, gold titles and white lines. Our rows take a change at once, the game's as its list next refreshes.
ns.QUEST_FONT_MIN, ns.QUEST_FONT_MAX = -3, 8
local function QuestFont(name, base, r, g, b)
    local font = CreateFont(name)
    font:SetFontObject(base)
    font:SetTextColor(r, g, b)
    font:SetJustifyH("LEFT")
    return font
end
ns.QuestListFont = QuestFont("ClassicUIForeverQuestList", "GameFontNormal", 1, 0.82, 0)
ns.QuestListFontSmall = QuestFont("ClassicUIForeverQuestListSmall", "GameFontHighlightSmall", 1, 1, 1)
-- A header under the mouse: white at the list's size.
ns.QuestListFontHover = QuestFont("ClassicUIForeverQuestListHover", "GameFontHighlight", 1, 1, 1)
local SIZED = { { ns.QuestListFont, "GameFontNormal" }, { ns.QuestListFontSmall, "GameFontHighlightSmall" },
    { ns.QuestListFontHover, "GameFontHighlight" } }

-- The quest text's fonts (the pages' title, body and lines, the side tab's details) as sized copies of the game's:
-- a base's name gives its copy, a copy's name itself, so a string once switched stays switched.
local TEXT_BASES = { "QuestTitleFont", "QuestFont_Large", "QuestFont", "QuestFontNormalSmall", "GameFontNormalLarge",
    "GameFontNormal", "GameFontNormalSmall" }
local textFonts = {}
for _, base in ipairs(TEXT_BASES) do
    if _G[base] then
        local font = CreateFont("ClassicUIForeverQuestText" .. base)
        font:SetFontObject(base)
        textFonts[base] = font
        textFonts[font:GetName()] = font
    end
end
function ns.QuestTextFont(name) return textFonts[name] or name end

local function Offset(key)
    return math.max(ns.QUEST_FONT_MIN, math.min(ns.QUEST_FONT_MAX, tonumber(ns.db and ns.db[key]) or 0))
end

local function SizeQuestFonts()
    local offset = Offset("questListFontSize")
    for _, pair in ipairs(SIZED) do
        local file, size, flags = _G[pair[2]]:GetFont()
        if file then pair[1]:SetFont(file, size + offset, flags) end
    end
    offset = Offset("questTextFontSize")
    for _, base in ipairs(TEXT_BASES) do
        if textFonts[base] then
            local file, size, flags = _G[base]:GetFont()
            if file then textFonts[base]:SetFont(file, size + offset, flags) end
        end
    end
end
-- After the classic fonts' own pass, so the files are theirs.
ns.RegisterModule("questListFont", { apply = SizeQuestFonts, restore = SizeQuestFonts })

-- The options' number rows (Options/OptionsRows.lua).
function ns.SetQuestListFontSize(value)
    ns.db.questListFontSize = value
    ns.ToggleChanged("questListFontSize")
end
function ns.SetQuestTextFontSize(value)
    ns.db.questTextFontSize = value
    ns.ToggleChanged("questTextFontSize")
end

-- Row heights for lists laid by hand: each font's size plus its leading.
function ns.QuestFontHeights()
    local _, title = ns.QuestListFont:GetFont()
    local _, line = ns.QuestListFontSmall:GetFont()
    return math.floor((title or 12) + 4.5), math.floor((line or 10) + 3.5)
end
