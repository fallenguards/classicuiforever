local _, ns = ...

-- Quest and gossip windows at 1.x height; the old name box behind quest rewards.

local P = ns.panels
local EMPTY = ns.EMPTY

local REWARD_BOX = { own = "nameBox", layer = "BACKGROUND", sublevel = 1, coords = { 0, 1, 0, 1 } }
local REWARD_FRAMES = { "QuestInfoRewardsFrame", "MapQuestInfoRewardsFrame" }
local REWARD_LISTS = { "RewardButtons", "SpellRewardButtons" }

-- The box's left edge from the icon's right (1 over it, as on the quest giver), for the large and the map's small buttons.
local REWARD_BOX_GAP = -1

-- 1.x name box behind the reward text, from the icon's right edge and as tall as the icon; the client borders the icon.
function ns.SkinQuestReward(button)
    local icon = button and button.Icon
    if not icon or not ns.Once(button, "reward") then return end
    local box = ns.DressNew(button, "lootNameFrame", REWARD_BOX)
    local iconW = icon:GetWidth() or 39
    local width = (button:GetWidth() or 147) - iconW - REWARD_BOX_GAP - 2
    ns.FitNamePlate(box, icon, REWARD_BOX_GAP, width, icon:GetHeight() or 39, "RIGHT")
    box:Show()
    if button.NameFrame then button.NameFrame:SetAlpha(0) end
    if button.IconBorder then button.IconBorder:SetAlpha(0) end
end

-- Reward buttons of the quest giver, the log's detail and the map's.
function ns.SkinQuestRewards()
    for _, name in ipairs(REWARD_FRAMES) do
        local frame = _G[name]
        if frame then
            for _, key in ipairs(REWARD_LISTS) do
                for _, button in ipairs(frame[key] or EMPTY) do ns.SkinQuestReward(button) end
            end
        end
    end
    local i = 1
    while _G["QuestInfoItem" .. i] do
        ns.SkinQuestReward(_G["QuestInfoItem" .. i])
        i = i + 1
    end
end

local rewardCount = -1

-- The client only adds reward buttons, so a new count means some are undressed.
local function RewardWatch()
    local count = 0
    for _, name in ipairs(REWARD_FRAMES) do
        local frame = _G[name]
        if frame then
            for _, key in ipairs(REWARD_LISTS) do count = count + #(frame[key] or EMPTY) end
        end
    end
    if count == rewardCount then return end
    rewardCount = count
    ns.SkinQuestRewards()
end

-- Watched while shown, never hooked: keeps our code out of the hidden pass the quest log's Share runs.
local function WatchRewards()
    for _, name in ipairs(REWARD_FRAMES) do
        local frame = _G[name]
        if frame then ns.Sched.Attach(frame, { name = "npc.rewards." .. name, every = 0, fn = RewardWatch }) end
    end
end

-- Client windows are 496 tall (text 403); 1.x held 334 of text. Trimmed once:
-- only the client's layout files size them. Foot buttons follow the bottom edge.
local NPC_WINDOW_TRIM = 69

-- A frame given by name or as itself.
local function Resolve(region)
    if type(region) == "string" then return _G[region] end
    return region
end

-- Cap each page at its scroll area (the tall fixed height scrolled short quests
-- over blank parchment); longer text still scrolls.
local function FitPages(scrolls)
    for _, scroll in ipairs(scrolls or EMPTY) do
        scroll = Resolve(scroll)
        local page = scroll and scroll.GetScrollChild and scroll:GetScrollChild()
        local room = scroll and scroll.GetHeight and scroll:GetHeight()
        if page and room and room > 0 and page.GetHeight and (page:GetHeight() or 0) > room + 0.5 then
            page:SetHeight(room)
            if scroll.UpdateScrollChildRect then scroll:UpdateScrollChildRect() end
        end
    end
end

local function Trim(region, atLeast)
    region = Resolve(region)
    if not region or not region.GetHeight or not region.SetHeight then return end
    local tall = region:GetHeight()
    if tall and tall > atLeast then region:SetHeight(tall - NPC_WINDOW_TRIM) end
end

-- The text area's foot over the window's bottom edge.
local PAGE_FOOT = 27
local MATERIAL_TOP = { "MaterialTopLeft", "MaterialTopRight" }
local MATERIAL_BOTTOM = { "MaterialBotLeft", "MaterialBotRight" }
-- The bottom pieces' art (ItemText-<material>-BotLeft, 128 rows) is solid to row 99, clear below.
local MATERIAL_BOTTOM_SOLID = 100 / 128

-- Parchment sizes from its art, which the client re-sets when theming (it hung
-- below the gossip window): pin its foot to end with the text area.
local function Foot(ground, frame)
    if not ground or not ground.SetPoint then return end
    local point, _, _, x = ground:GetPoint(1)
    if point ~= "TOPLEFT" then return end
    ground:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", x or 7, PAGE_FOOT)
end

-- A quest object's page material (stone, bronze) is four pieces sized for the tall window (#178): squeezed in
-- proportion so the art's solid edge meets the parchment's foot, measured as each page shows.
local materialArt = setmetatable({}, { __mode = "k" })   -- panel -> its pieces' own heights, top and bottom
local materialPanels = {}
local function FitMaterial(panel)
    local topLeft, ground = panel.MaterialTopLeft, panel.Bg
    local art = materialArt[panel]
    local top, foot = topLeft:GetTop(), ground and ground:GetBottom()
    if not (top and foot) or top <= foot then return end
    local scale = (top - foot) / (art[1] + art[2] * MATERIAL_BOTTOM_SOLID)
    for _, key in ipairs(MATERIAL_TOP) do
        if panel[key] then panel[key]:SetHeight(art[1] * scale) end
    end
    for _, key in ipairs(MATERIAL_BOTTOM) do
        if panel[key] then panel[key]:SetHeight(art[2] * scale) end
    end
end
local function FitShownMaterials()
    for _, panel in ipairs(materialPanels) do
        if panel:IsShown() then FitMaterial(panel) end
    end
end
local function WatchMaterial(panel)
    local topLeft, botLeft = panel.MaterialTopLeft, panel.MaterialBotLeft
    if not (topLeft and botLeft) or materialArt[panel] then return end
    materialArt[panel] = { topLeft:GetHeight(), botLeft:GetHeight() }
    materialPanels[#materialPanels + 1] = panel
    ns.Sched.OnVisible(panel, "npc.material", function(shown)
        if shown then ns.Sched.NextFrame("npc.material", FitShownMaterials) end
    end)
end

local function ShortenNpcWindow(frame, scrolls, panels, grounds)
    if not frame then return end
    if frame.fcuiShort then
        FitPages(scrolls)
        return
    end
    local height = frame:GetHeight()
    -- Any height, as long as it is the tall one.
    if not height or height < 470 then return end
    frame.fcuiShort = true
    frame:SetHeight(height - NPC_WINDOW_TRIM)
    for _, scroll in ipairs(scrolls or EMPTY) do Trim(scroll, 200) end
    FitPages(scrolls)
    for _, panel in ipairs(panels or EMPTY) do
        panel = Resolve(panel)
        Trim(panel, 400)
        if panel and panel.Bg then Foot(panel.Bg, frame) end
        if panel then WatchMaterial(panel) end
    end
    for _, ground in ipairs(grounds or EMPTY) do Foot(ground, frame) end
end

local QUEST_SCROLLS = { "QuestDetailScrollFrame", "QuestProgressScrollFrame", "QuestRewardScrollFrame", "QuestGreetingScrollFrame" }
local QUEST_PANELS = { "QuestFrameDetailPanel", "QuestFrameProgressPanel", "QuestFrameRewardPanel", "QuestFrameGreetingPanel" }

------------------------------------------------------------ the page under a theme

-- A theme inks the page as the quest log's (ns.InkPage); a dark one takes the text near white, as the log's. Painted
-- after the game's pass for each page; the game's own colors come back once the page is light again.
local QUEST_TITLES = { "QuestInfoTitleHeader", "QuestInfoDescriptionHeader", "QuestInfoObjectivesHeader",
    "QuestProgressTitleText", "QuestProgressRequiredItemsText", "CurrentQuestsText", "AvailableQuestsText" }
local QUEST_TEXTS = { "QuestInfoDescriptionText", "QuestInfoObjectivesText", "QuestInfoGroupSize", "QuestInfoRewardText",
    "QuestInfoTimerText", "QuestInfoSpellObjectiveLearnLabel", "QuestProgressText", "GreetingText" }
local REWARD_TEXTS = { "ItemChooseText", "ItemReceiveText", "PlayerTitleText", "QuestSessionBonusReward" }
local lit = setmetatable({}, { __mode = "k" })   -- font string -> true while ours is on it

-- The game's colors for the page: its light text setting reads as stone.
local function GameColors()
    local material = QuestFrame_GetMaterial and QuestFrame_GetMaterial() or "Parchment"
    if QuestTextContrast and QuestTextContrast.UseLightText() then material = "Stone" end
    return GetMaterialTextColors(material)
end

-- fixed: a button's text, held from its hover color while ours is on it.
local function PaintLine(fs, title, dark, fixed)
    if not fs then return end
    if dark then
        lit[fs] = true
        if fixed then fs:SetFixedColor(true) end
        fs:SetTextColor(unpack(ns.PAGE_INK))
    elseif lit[fs] then
        lit[fs] = nil
        if fixed then fs:SetFixedColor(false) end
        local text, head = GameColors()
        local c = title and head or text
        fs:SetTextColor(c[1], c[2], c[3])
    end
end

-- A quest object's page (stone, bronze) keeps the game's text colors.
local function QuestPageDark()
    return ns.PageDark() and (not QuestFrame_GetMaterial or QuestFrame_GetMaterial() == "Parchment")
end

local function PaintQuestPage()
    local dark = QuestPageDark()
    for _, name in ipairs(QUEST_PANELS) do
        local panel = _G[name]
        if panel and panel.Bg then ns.InkPage(panel.Bg) end
    end
    for _, name in ipairs(QUEST_TITLES) do PaintLine(_G[name], true, dark) end
    for _, name in ipairs(QUEST_TEXTS) do PaintLine(_G[name], false, dark) end
    local rewards = QuestInfoRewardsFrame
    if rewards then
        PaintLine(rewards.Header, true, dark)
        for _, key in ipairs(REWARD_TEXTS) do PaintLine(rewards[key], false, dark) end
        PaintLine(ns.Path(rewards, "XPFrame", "ReceiveText"), false, dark)
    end
    local pool = QuestFrameGreetingPanel and QuestFrameGreetingPanel.titleButtonPool
    if pool then
        for button in pool:EnumerateActive() do PaintLine(button:GetFontString(), false, dark, true) end
    end
end

-- Gossip: its greeting and every option, looked at while it shows. The game paints them all dark again on each update
-- (its theme container), so a line is read, not remembered.
local gossipDark = false
local function Inked(fs)
    local r, g, b = fs:GetTextColor()
    local ink = ns.PAGE_INK
    return ns.Near(r, ink[1], 0.01) and ns.Near(g, ink[2], 0.01) and ns.Near(b, ink[3], 0.01)
end
local function PaintGossipRow(row)
    local fs = row.GreetingText or (row.GetFontString and row:GetFontString())
    if not fs or (gossipDark and Inked(fs)) or (not gossipDark and not lit[fs]) then return end
    PaintLine(fs, false, gossipDark, row.GreetingText == nil)
end
local function PaintGossipRows()
    gossipDark = ns.PageDark()
    local list = ns.Path(GossipFrame, "GreetingPanel", "ScrollBox")
    if list and list.ForEachFrame then list:ForEachFrame(PaintGossipRow) end
end
local function PaintGossipPage()
    if GossipFrame.Background then ns.InkPage(GossipFrame.Background) end
    PaintGossipRows()
end

local watching = false
local function WatchPages()
    if watching then return end
    watching = true
    for _, name in ipairs(QUEST_PANELS) do
        ns.Sched.OnVisible(_G[name], "npc.page", function(shown)
            if shown then ns.Sched.NextFrame("npc.questPage", PaintQuestPage) end
        end)
    end
    if not GossipFrame then return end
    ns.Sched.OnVisible(GossipFrame, "npc.page", function(shown)
        if shown then ns.Sched.NextFrame("npc.gossipPage", PaintGossipPage) end
    end)
    ns.Sched.Attach(GossipFrame, { name = "npc.gossipRows", every = 0.2, fn = PaintGossipRows })
end

ns.OnToggle(function(key)
    if not ns.ThemeKey(key) then return end
    if QuestFrame and QuestFrame:IsShown() then PaintQuestPage() end
    if GossipFrame and GossipFrame:IsShown() then PaintGossipPage() end
end)

function P.after.QuestFrame(frame)
    ShortenNpcWindow(frame, QUEST_SCROLLS, QUEST_PANELS)
    if frame.Inset then ns.ShowInsetBorder(frame.Inset.NineSlice, true) end
    -- Each panel's per-campaign backdrop, over our parchment otherwise.
    for _, name in ipairs(QUEST_PANELS) do ns.Fade(ns.Path(_G[name], "SealMaterialBG")) end
    ns.SkinQuestRewards()
    WatchRewards()
    WatchPages()
end

function P.after.GossipFrame(frame)
    local panel = frame.GreetingPanel
    ShortenNpcWindow(frame, { panel and panel.ScrollBox }, { panel }, { frame.Background })
    if frame.Inset then ns.ShowInsetBorder(frame.Inset.NineSlice, true, true) end
    WatchPages()
end
