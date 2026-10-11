local _, ns = ...

-- The old book on two parchment pages: primary rows (emblem, name, rank, green bar, two plated spells), three short secondary rows.
-- BookPage and its spell buttons are the client's and cast: parents kept, only moved; other card art faded, our rows draw the rest.
-- Fills reset a primary card's spells to fixed offsets from its foot (combat too): the card is cut to their column and moved instead.

local T = {}
ns.prof = T -- shared with the window half (watcher, faces, tabs): ProfessionsWindow.lua
T.built = false

local SHEET = "Interface\\Spellbook\\ProfessionsBook"
local PAGE_LEFT = "Interface\\Spellbook\\Professions-Book-Left"
local PAGE_RIGHT = "Interface\\Spellbook\\Professions-Book-Right"
-- Rows, from the content frame's top left corner (rowY: two primaries, three secondaries): the full book (its second
-- primary raised 15 onto its band), or the 1.x window's size (option), each row on its own band of the page cut
-- off on the right, stacked with no spare parchment.
local BIG = { rowX = 80, rowW = 437, ring = 72, ringX = 7, ringY = -12, textX = 100, nameY = -8, rankW = 182,
    spellX = 288, plates = true, rowY = { -62, -153, -284, -355, -431 } }
-- Small, on the spellbook's parchment (it starts 63 down): no ring (the spell buttons carry the icon), the text at
-- the secondaries' left, the unlearn button after the bar's end, each primary in the middle of its band; the spells at
-- 4/5 size (two stacked fit a band) and the secondaries' in the primaries' column.
local SMALL = { rowX = 17, rowW = 305, ring = 48, ringX = 4, ringY = -29, noRing = true, textX = 6, nameY = -31,
    missingY = -40, cardDrop = 11, unlearnRight = true, centerSpells = true, rankW = 97, spellX = 154, barW = 64,
    plates = false, iconsX = 154, spellScale = 0.8, descX = 129, descSize = 9, rowY = { -46, -124, -230, -294, -358 },
    segMid = { 106.5, 186.5 } }
-- The banded page (option): its ring and spots from before.
local SMALL_BANDED = setmetatable({ ringY = -23, noRing = false, textX = 58, nameY = -11, missingY = -20, cardDrop = 5,
    unlearnRight = false, centerSpells = false, spellX = 159, iconsX = 159, spellScale = 1, segMid = false,
    rowY = { -37, -131, -230, -294, -358 } }, { __index = SMALL })
-- segMid (small page): each primary's segment middle on the page, between its band's lines (BANDS): the text block and
-- the spells stand on it, rowY unused for those two.
-- A primary row's rank line, from the row's top; its bar 5 under it.
local RANK_Y, BAR_GAP = 56, 5
-- The banded page's art: { texture top, bottom, drawn top } on the left page from its spine margin, 322 wide.
-- Every band drawn PULL further into the art, so the secondaries' emblems (at x 150-186) stand near their names; a cut
-- inside a band showed a seam, so the whole band moves and its soft left rim goes under the window's metal.
local PULL = 24
local SMALL_ART_X, SMALL_ART_U, SMALL_ART_W = 8, 64, 322
local SMALL_BANDS = {
    { 26, 38, 24 },    -- the page's top edge
    { 38, 132, 36 },   -- first primary band
    { 38, 132, 130 },  -- second primary, on the first's band
    { 236, 300, 224 }, -- Cooking
    { 314, 378, 288 }, -- Fishing
    { 392, 456, 352 }, -- First Aid
    { 458, 466, 416 }, -- the page's foot
}
-- The small page on the spellbook's own parchment: only the secondaries' emblems, lifted off the page art as a shading
-- (multiply) and a highlight (add) layer (dev/tools/prof_emblems.py), where their bands had them. { x, y, w, h, cell }
-- on the page; each 128 x 64 cell from its top left.
local EMBLEMS = {
    { 68, 226, 80, 56, 0 },   -- Cooking
    { 72, 290, 96, 52, 1 },   -- Fishing
    { 70, 349, 84, 57, ns.OnForever() and 2 or 3 },   -- First Aid; retail's Archaeology
}
local EMBLEM_LAYERS = { { "professionsEmblemsMod", "MOD" }, { "professionsEmblemsAdd", "ADD" } }
-- The old page's primary bands on the parchment, the same two layers (322 wide): { y on the page, height, top in the
-- 512 x 128 sheet }. The first runs on its plain grain (sheet 96) to the second's top line; under them the same line
-- and its shading, the band's top (sheet 3-38); no line has the light rim the old page has over it (sheet 0-2).
local BANDS = { { 67, 54, 3 }, { 121, 21, 96 }, { 145, 54, 3 }, { 199, 13, 104 }, { 227, 36, 3 } }
-- Cut to the parchment inside the frame's dark inset line, 4 in on the left and 2 on the right.
local PARCH_BAND_X, PARCH_BAND_W, PARCH_CUT_L, PARCH_CUT_R = 8, 322, 4, 2
local BAND_LAYERS = { { "professionsBandsMod", "MOD" }, { "professionsBandsAdd", "ADD" } }
local PRIMARY_H, SECONDARY_H = 100, 52

function T.Big() return ns.db == nil or ns.db.profBookBig == true end
local function Banded() return ns.db ~= nil and ns.db.profBookBands == true end
local function Spec()
    if T.Big() then return BIG end
    return Banded() and SMALL_BANDED or SMALL
end
-- Bands are 76 apart, rows 70: each band is redrawn centred on its row (First
-- Aid by its emblem, high in the art). { art top, art bottom, drawn top, drawn
-- bottom } in the 512 px page.
local BAND_X = 64 -- the page margin left of here runs straight down and stays put
local BAND_STRIPS = {
    { 286, 302, 236, 252 }, -- plain parchment under the ornament
    { 236, 298, 252, 314 }, -- Cooking
    { 304, 380, 314, 390 }, -- Fishing
    { 380, 432, 390, 442 }, -- First Aid
    { 432, 456, 442, 456 }, -- First Aid foot, squeezed to the book edge
}
-- Retail's book is a window of its own (ProfessionsBookFrame) with the same cards under other names.
local FOREVER = ns.OnForever()
-- The x the client gives a primary card's buttons from its left: Forever's from the foot, retail's from our 170's right.
local CLIENT_BUTTON_X = FOREVER and 15 or 21

-- What the client draws on a card, faded (see FadeCard); both clients' names.
local CARD_ART = { "Background", "ProfessionName", "professionName", "specialization", "missingHeader", "missingText", "Rank",
    "rank", "icon", "IconBorder" }

local SetShownIf = ns.SetShownIf

local rows = {}

-- The window the book stands in.
function T.Host()
    if FOREVER then return ProfessionsFrame end
    return _G.ProfessionsBookFrame
end

local function Page()
    if FOREVER then return ProfessionsFrame and ProfessionsFrame.BookPage end
    return _G.ProfessionsBookFrame
end
T.Page = Page

local function Content()
    if not FOREVER then return _G.ProfessionsContentFrame end
    local page = Page()
    return page and page.ProfessionsContentFrame
end

local function Card(content, name)
    return content[name] or (not FOREVER and _G[name]) or nil
end

local function Font(fontString, name, fallback)
    local object = _G[name] or _G[fallback]
    if object then fontString:SetFontObject(object) end
end

---------------------------------------------------------------------------
-- The rows
---------------------------------------------------------------------------

local function NewBar(parent, index)
    -- The old bar is still a client template; made from here it is ours. Named: retail's template hangs its
    -- pieces by $parent names, and nameless bars' backs ran from one bar to another.
    local ok, bar = pcall(ns.NewFrame, "StatusBar", "ClassicUIForeverProfessionBar" .. index, parent, "ProfessionStatusBarTemplate")
    if not ok or not bar then
        bar = ns.NewFrame("StatusBar", nil, parent)
        bar:SetSize(95, 16)
        bar:SetStatusBarTexture("Interface\\Spellbook\\Professions-Progress-Fill")
        bar.rankText = bar:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
        bar.rankText:SetPoint("CENTER", 0, 2)
    end
    if bar.capped then bar.capped:Hide() end
    return bar
end

local function NewRow(content, primary, index)
    local row = ns.NewFrame("Frame", nil, content)
    row.index = index
    row.primary = primary

    row.name = row:CreateFontString(nil, "ARTWORK")
    row.rank = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.rank:SetJustifyH("LEFT")
    row.bar = NewBar(row, index)
    row.missingHeader = row:CreateFontString(nil, "ARTWORK")
    row.missingText = row:CreateFontString(nil, "ARTWORK")
    Font(row.missingText, "SubSpellFont", "GameFontHighlightSmall")
    row.missingText:SetJustifyH("LEFT")
    row.missingText:SetTextColor(0.1, 0.05, 0.05)

    if primary then
        local ring = row:CreateTexture(nil, "ARTWORK", nil, 1)
        ring:SetTexture(SHEET)
        ring:SetTexCoord(0.43359375, 0.72265625, 0.14843750, 0.72656250)
        row.ring = ring
        local icon = row:CreateTexture(nil, "ARTWORK", nil, 0)
        row.icon = icon

        Font(row.name, "QuestTitleFontBlackShadow", "GameFontNormalLarge")
        row.name:SetJustifyH("LEFT")
        row.bar:SetPoint("TOPLEFT", row.rank, "BOTTOMLEFT", 14, -BAR_GAP)

        Font(row.missingHeader, "QuestTitleFontBlackShadow", "GameFontNormalLarge")
        row.missingHeader:SetTextColor(0.85, 0.7, 0.6)
        row.missingText:SetPoint("TOPLEFT", row.missingHeader, "BOTTOMLEFT", 0, -1)
    else
        row.bar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 16, 2)
        row.rank:SetPoint("BOTTOMLEFT", row.bar, "TOPLEFT", -14, 4)
        row.rank:SetPoint("BOTTOMRIGHT", row.bar, "TOPRIGHT", 25, 4)
        Font(row.name, "QuestFont_Shadow_Small", "GameFontNormal")
        row.name:SetJustifyH("LEFT")
        row.name:SetTextColor(1, 0.82, 0)
        row.name:SetShadowColor(0, 0, 0)
        row.name:SetPoint("BOTTOMLEFT", row.rank, "TOPLEFT", 0, 2)
        row.name:SetPoint("BOTTOMRIGHT", row.rank, "TOPRIGHT", 0, 2)

        Font(row.missingHeader, "QuestFont_Large", "GameFontNormalLarge")
        row.missingHeader:SetTextColor(0.15, 0.1, 0.1)
        row.missingHeader:SetPoint("TOPLEFT", row, "TOPLEFT", 4, -15)
        row.missingText:SetPoint("RIGHT", row, "RIGHT", -5, 0)
    end
    return row
end

-- A row's size and inner spots for the page size.
-- A primary row's text block: its name's top to its bar's foot, from the row's top. The rank line by its font's size,
-- not its text's: rows, cards and spells are placed at different times and must agree.
local function BarFoot(row)
    return RANK_Y + (select(2, row.rank:GetFont()) or 10) + BAR_GAP + (row.bar:GetHeight() or 16)
end
local function TextMiddle(row, spec) return (-spec.nameY + BarFoot(row)) / 2 end

-- Row i's top on the page: a primary's text block in the middle of its segment where the page has them.
local function RowTop(i, spec)
    local row = rows[i]
    if i <= 2 and spec.segMid and row then return TextMiddle(row, spec) - spec.segMid[i] end
    return spec.rowY[i]
end

local function LayRow(row, content, spec)
    row:SetSize(spec.rowW, row.primary and PRIMARY_H or SECONDARY_H)
    row.bar.fullW = row.bar.fullW or row.bar:GetWidth()
    row.bar:SetWidth(spec.barW or row.bar.fullW)
    ns.SetPointOnce(row, "TOPLEFT", content, "TOPLEFT", spec.rowX, RowTop(row.index, spec))
    if row.primary then
        SetShownIf(row.ring, not spec.noRing)
        SetShownIf(row.icon, not spec.noRing)
        row.ring:SetSize(spec.ring, spec.ring)
        ns.SetPointOnce(row.ring, "TOPLEFT", row, "TOPLEFT", spec.ringX, spec.ringY)
        local inset = spec.ring / 9
        ns.SetPointOnce(row.icon, "TOPLEFT", row.ring, "TOPLEFT", inset, -inset)
        row.icon:SetPoint("BOTTOMRIGHT", row.ring, "BOTTOMRIGHT", -inset, inset)
        ns.SetPointOnce(row.name, "TOPLEFT", row, "TOPLEFT", spec.textX, spec.nameY)
        row.name:SetWidth(spec.spellX - spec.textX - 4)
        ns.SetPointOnce(row.rank, "TOPLEFT", row, "TOPLEFT", spec.textX, -RANK_Y)
        row.rank:SetWidth(spec.rankW)
        ns.SetPointOnce(row.missingHeader, "TOPLEFT", row, "TOPLEFT", spec.textX + 20, spec.missingY or -20)
        row.missingText:SetWidth(spec.rowW - spec.textX - 32)
    else
        -- Untrained: the description after the emblem on the small page, at the row's right on the full one.
        row.missingText:ClearAllPoints()
        if spec.descX then
            row.missingText:SetPoint("LEFT", row, "LEFT", spec.descX, 0)
            row.missingText:SetWidth(spec.rowW - spec.descX - 5)
        else
            row.missingText:SetPoint("RIGHT", row, "RIGHT", -5, 0)
            row.missingText:SetWidth(spec.rowW - 187)
        end
    end
    -- The small page's descriptions a point smaller, to fit their band.
    local font, size, flags = row.missingText:GetFont()
    row.descSize = row.descSize or size
    if font then row.missingText:SetFont(font, spec.descSize or row.descSize, flags) end
end

-- Rank title for a skill cap, in the old book's wording.
local function RankTitle(maxRank)
    local ranks = PROFESSION_RANKS
    if type(ranks) ~= "table" or not maxRank then return "" end
    local title = ""
    for _, entry in ipairs(ranks) do
        title = entry[2] or title
        if maxRank <= (entry[1] or 0) then break end
    end
    return title
end

local MISSING = {
    { header = "PROFESSIONS_FIRST_PROFESSION", text = "PROFESSIONS_MISSING_PROFESSION" },
    { header = "PROFESSIONS_SECOND_PROFESSION", text = "PROFESSIONS_MISSING_PROFESSION" },
    { header = "PROFESSIONS_COOKING", text = "PROFESSIONS_COOKING_MISSING" },
    { header = "PROFESSIONS_FISHING", text = "PROFESSIONS_FISHING_MISSING" },
    { header = FOREVER and "PROFESSIONS_FIRST_AID" or "PROFESSIONS_ARCHAEOLOGY",
        text = FOREVER and "PROFESSIONS_FIRST_AID_MISSING" or "PROFESSIONS_ARCHAEOLOGY_MISSING" },
}

local function FillRow(row, index, slot)
    local name, texture, rank, maxRank, rankModifier, _
    if index and GetProfessionInfo then
        name, texture, rank, maxRank, _, _, _, rankModifier = GetProfessionInfo(index)
    end
    local known = name ~= nil
    row.name:SetShown(known)
    row.rank:SetShown(known)
    row.bar:SetShown(known)
    row.missingHeader:SetShown(not known)
    row.missingText:SetShown(not known)
    if row.icon then
        if known and texture then
            row.icon:SetTexture(texture)
            row.icon:SetDesaturated(false)
        else
            row.icon:SetTexture("Interface\\Icons\\INV_Scroll_04")
        end
        -- Past the icon's own border, cut round to the ring's hole.
        ns.RoundIcon(row.icon, 1)
    end
    if not known then
        local words = MISSING[slot] or MISSING[1]
        row.missingHeader:SetText(_G[words.header] or "")
        row.missingText:SetText(_G[words.text] or "")
        return
    end
    row.name:SetText(name)
    row.rank:SetText(RankTitle(maxRank))
    rank, maxRank = rank or 0, maxRank or 0
    row.bar:SetMinMaxValues(0, math.max(1, maxRank))
    row.bar:SetValue(rank)
    if row.bar.capRight then row.bar.capRight:SetShown(maxRank > 0 and rank >= maxRank) end
    if row.bar.rankText then
        if rankModifier and rankModifier > 0 then
            row.bar.rankText:SetFormattedText(TRADESKILL_RANK_WITH_MODIFIER or "%d (+%d)/%d", rank, rankModifier, maxRank)
        else
            row.bar.rankText:SetFormattedText(TRADESKILL_RANK or "%d/%d", rank, maxRank)
        end
    end
end

---------------------------------------------------------------------------
-- Professions past the five rows (Poisons): the client's side tab and our General tab reach them, not this page
---------------------------------------------------------------------------

local IsSecret = ns.IsSecret

-- The client's side tab rule for a profession listing no spells: spellOffset + 1 counts if it opens a trade skill.
function T.OpensTrade(info)
    local id = info and info.spellID
    if not id or IsSecret(id) or not (C_TradeSkillUI and C_TradeSkillUI.CanTradeSkillShowCraftingUI) then return false end
    local ok, can = pcall(C_TradeSkillUI.CanTradeSkillShowCraftingUI, id)
    return ok and not IsSecret(can) and can == true
end

-- The old book's plate right of a spell button.
local plates = {}   -- spell button -> its plate
local function SpellPlate(button)
    local plate = button:CreateTexture(nil, "BACKGROUND")
    plates[button] = plate
    plate:SetTexture(SHEET)
    plate:SetTexCoord(0.00390625, 0.42578125, 0.14843750, 0.46875000)
    plate:SetSize(108, 41)
    plate:SetPoint("LEFT", button, "RIGHT", 1, 0)
    return plate
end

function T.FillRows()
    if not T.built or not GetProfessions then return end
    local prof1, prof2, faid, fish, cook = GetProfessions()
    FillRow(rows[1], prof1, 1)
    FillRow(rows[2], prof2, 2)
    FillRow(rows[3], cook, 3)
    FillRow(rows[4], fish, 4)
    FillRow(rows[5], faid, 5)
end

---------------------------------------------------------------------------
-- The client's cards
---------------------------------------------------------------------------

-- Faded, never hidden: the client re-shows these on every fill but leaves alpha alone.
local function FadeCard(card)
    ns.FadeKeys(card, CARD_ART)
    -- Retail's emblem ring has a name only.
    local ring = not FOREVER and card.GetName and _G[card:GetName() .. "IconBorder"]
    if ring then ring:SetAlpha(0) end
    local bar = card.StatusBar or card.statusBar
    if bar then
        bar:SetAlpha(0)
        if bar.EnableMouse then bar:EnableMouse(false) end
    end
end

local function DressSpellButton(button)
    if not button or not ns.Once(button, "spellPlate") then return end
    -- Retail's button still carries the old plate and icon.
    if not FOREVER then
        plates[button] = _G[button:GetName() .. "NameFrame"]
        return
    end
    SpellPlate(button)
    -- Drop this client's square icon frame and rounded mask.
    if button.IconTextureOverlay then button.IconTextureOverlay:SetAlpha(0) end
    if button.IconTexture and button.OutlineMask and button.IconTexture.RemoveMaskTexture then
        pcall(button.IconTexture.RemoveMaskTexture, button.IconTexture, button.OutlineMask)
    end
end

-- A spell button at the page's size (spec.spellScale of the client's): its icon, states and glow fill it, its name
-- hangs off its side at full size. Returns how much shorter than the client's it stands.
local fullSize = setmetatable({}, { __mode = "k" })
local plateHeight = setmetatable({}, { __mode = "k" })
local function SizeSpell(button, spec)
    if not button then return 0 end
    local full = fullSize[button]
    if not full then
        full = button:GetWidth()
        fullSize[button] = full
    end
    local scale = spec.spellScale or 1
    local size = full * scale
    ns.SetSizeIf(button, size, size)
    -- Its name plate as tall as it, in step.
    local plate = plates[button]
    if plate then
        plateHeight[plate] = plateHeight[plate] or plate:GetHeight()
        ns.SetSizeIf(plate, plate:GetWidth(), plateHeight[plate] * scale)
    end
    return full - size
end

local function DressUnlearn(card, content, y, spec)
    local button = card.UnlearnButton
    if not button then return end
    -- Level with the bar: just left of its end cap, or (spellbook parchment) a little past its far end. Retail's button
    -- is scaled 0.7: its offsets and icon in its own units.
    local scale = button:GetScale()
    if not scale or scale <= 0 then scale = 1 end
    local x = spec.unlearnRight and spec.rowX + spec.textX + 14 + spec.barW + 26 or spec.rowX + spec.textX - 15
    ns.SetPointOnce(button, "CENTER", content, "TOPLEFT", x / scale, (y - 76) / scale)
    if button.Icon then
        button.Icon:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
        button.Icon:SetSize(16 / scale, 16 / scale)
        button.Icon:SetAlpha(0.75)
    end
    if button.Overlay then button.Overlay:SetAlpha(0) end
    if card.GamepadUnlearnButton then ns.SetPointOnce(card.GamepadUnlearnButton, "RIGHT", button, "LEFT", -2, 0) end
end

-- Cards hold casting buttons: placed out of combat only, retried after.
function T.PlaceCards()
    local content = Content()
    if not content or InCombatLockdown() then return false end
    local spec = Spec()
    for i = 1, 2 do
        local card = Card(content, "PrimaryProfession" .. i)
        if card then
            local y = RowTop(i, spec)
            card:SetSize(170, PRIMARY_H)
            ns.SetPointOnce(card, "TOPLEFT", content, "TOPLEFT", spec.rowX + spec.spellX - CLIENT_BUTTON_X, y - (spec.cardDrop or 5))
            FadeCard(card)
            DressSpellButton(card.SpellButton1)
            DressSpellButton(card.SpellButton2)
            SizeSpell(card.SpellButton1, spec)
            SizeSpell(card.SpellButton2, spec)
            DressUnlearn(card, content, y, spec)
        end
    end
    for i = 1, 3 do
        local card = Card(content, "SecondaryProfession" .. i)
        if card then
            card:SetSize(spec.rowW, SECONDARY_H)
            ns.SetPointOnce(card, "TOPLEFT", content, "TOPLEFT", spec.rowX, spec.rowY[2 + i])
            FadeCard(card)
            -- Small page: the first spell with its name plate after the bar, any more as icons to its left.
            local previous
            for n = 1, 4 do
                local button = card["SpellButton" .. n]
                if button then
                    DressSpellButton(button)
                    -- Smaller, it keeps the row's middle.
                    local short = SizeSpell(button, spec)
                    local named = spec.plates or n == 1
                    if plates[button] then plates[button]:SetShown(named) end
                    ns.SetAlphaIf(button.spellString, named and 1 or 0)
                    ns.SetAlphaIf(button.subSpellString, named and 1 or 0)
                    button:ClearAllPoints()
                    if not spec.plates then
                        if previous then
                            button:SetPoint("TOPRIGHT", previous, "TOPLEFT", -4, 0)
                        else
                            button:SetPoint("TOPLEFT", card, "TOPLEFT", spec.iconsX, -6 - short / 2)
                        end
                    elseif previous then
                        button:SetPoint("TOPRIGHT", previous, "TOPLEFT", -109, 0)
                    else
                        button:SetPoint("TOPRIGHT", card, "TOPRIGHT", -109, -6)
                    end
                    previous = button
                end
            end
        end
    end
    return true
end

---------------------------------------------------------------------------
-- The book
---------------------------------------------------------------------------

-- The full book's pages: the spellbook parchment's tones (Forever, our left page), or the Cataclysm page (option, and
-- retail, whose left page carries Archaeology). Only on a change.
local function PaintFull()
    local full = rows.full
    local parchment = FOREVER and not Banded()
    if not full or full.parchment == parchment then return end
    full.parchment = parchment
    local function Left(tex)
        if parchment then ns.SetTex(tex, "professionsBookLeftParchment")
        elseif not (FOREVER and ns.SetTex(tex, "professionsBookLeft")) then tex:SetTexture(PAGE_LEFT) end
    end
    Left(full.left)
    for _, band in ipairs(full.strips) do
        Left(band)
        band:SetTexCoord(unpack(band.coords))
    end
    if parchment then ns.SetTex(full.right, "professionsBookRightParchment") else full.right:SetTexture(PAGE_RIGHT) end
end

function T.Build()
    local page, content = Page(), Content()
    if T.built or not page or not content then return T.built end
    -- Forever: our left page has First Aid's emblem where the client's has Archaeology's (Art/Textures.lua).
    -- Retail keeps the client's page, drawn on the content frame: on the window itself it lies under the chrome.
    local function PageArt(tex)
        if not (FOREVER and ns.SetTex(tex, "professionsBookLeft")) then tex:SetTexture(PAGE_LEFT) end
    end
    local artHost = FOREVER and page or content
    local left = artHost:CreateTexture(nil, "BACKGROUND", nil, 2)
    left:SetSize(512, 512)
    left:SetPoint("TOPLEFT", page, "TOPLEFT", 7, -25)
    local right = artHost:CreateTexture(nil, "BACKGROUND", nil, 2)
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
    rows.art = { left, right }
    rows.full = { left = left, right = right, strips = {} }
    for _, strip in ipairs(BAND_STRIPS) do
        local band = artHost:CreateTexture(nil, "BACKGROUND", nil, 3)
        -- Both corners on the page texture, so neighbouring strips share an edge exactly.
        band:SetPoint("TOPLEFT", left, "TOPLEFT", BAND_X, -strip[3])
        band:SetPoint("BOTTOMRIGHT", left, "TOPRIGHT", 0, -strip[4])
        band.coords = { BAND_X / 512, 1, strip[1] / 512, strip[2] / 512 }
        rows.art[#rows.art + 1] = band
        rows.full.strips[#rows.full.strips + 1] = band
    end
    rows.small = {}
    -- Clipped to the window's inside: the page stands lower than the window, and the art ran past its foot.
    local clip = ns.NewFrame("Frame", nil, artHost)
    clip:SetPoint("TOPLEFT", T.Host(), "TOPLEFT", 4, -20)
    clip:SetPoint("BOTTOMRIGHT", T.Host(), "BOTTOMRIGHT", -4, 4)
    clip:SetClipsChildren(true)
    clip:SetFrameLevel(artHost:GetFrameLevel())
    rows.clip = clip
    rows.bands = {}
    local artEnd = SMALL_ART_U + SMALL_ART_W
    for _, band in ipairs(SMALL_BANDS) do
        local tex = clip:CreateTexture(nil, "BACKGROUND", nil, 2)
        PageArt(tex)
        tex:SetTexCoord((SMALL_ART_U + PULL) / 512, (artEnd + PULL) / 512, band[1] / 512, band[2] / 512)
        tex:SetPoint("TOPLEFT", page, "TOPLEFT", SMALL_ART_X, -band[3])
        tex:SetSize(SMALL_ART_W, band[2] - band[1])
        rows.bands[#rows.bands + 1] = tex
    end
    for _, b in ipairs(BANDS) do
        for _, layer in ipairs(BAND_LAYERS) do
            local tex = clip:CreateTexture(nil, "BACKGROUND", nil, 2)
            ns.SetTex(tex, layer[1])
            tex:SetBlendMode(layer[2])
            tex:SetTexCoord(PARCH_CUT_L / 512, (PARCH_BAND_W - PARCH_CUT_R) / 512, b[3] / 128, (b[3] + b[2]) / 128)
            tex:SetPoint("TOPLEFT", page, "TOPLEFT", PARCH_BAND_X + PARCH_CUT_L, -b[1])
            tex:SetSize(PARCH_BAND_W - PARCH_CUT_L - PARCH_CUT_R, b[2])
            rows.small[#rows.small + 1] = tex
        end
    end
    for _, e in ipairs(EMBLEMS) do
        for _, layer in ipairs(EMBLEM_LAYERS) do
            local tex = clip:CreateTexture(nil, "BACKGROUND", nil, 2)
            ns.SetTex(tex, layer[1])
            tex:SetBlendMode(layer[2])
            tex:SetTexCoord(0, e[3] / 128, e[5] * 64 / 256, (e[5] * 64 + e[4]) / 256)
            tex:SetPoint("TOPLEFT", page, "TOPLEFT", e[1], -e[2])
            tex:SetSize(e[3], e[4])
            rows.small[#rows.small + 1] = tex
        end
    end
    for i = 1, 2 do rows[i] = NewRow(content, true, i) end
    for i = 1, 3 do rows[2 + i] = NewRow(content, false, 2 + i) end
    T.built = true
    T.Lay()
    return true
end

-- Rows and art for the page size; the cards (casting buttons) follow in PlaceCards, out of combat.
function T.Lay()
    local content = Content()
    if not T.built or not content then return end
    local spec = Spec()
    for i = 1, 5 do LayRow(rows[i], content, spec) end
    if T.shown ~= nil then T.ShowOurs(T.shown) end
end

-- Old book's mid-row spells: each fill resets them to 10 and 60 (whole offsets, no tie at 0.5); casting buttons, out of combat.
-- The full book's spots, set outright: the small page's centring may have moved them since the client's last fill.
local SPELL_LOW, SPELL_HIGH, SPELL_ONE = 15, 56, 46
local Near = ns.Near
local function Foot(button, want)
    local point, rel, relPoint, x, y = button:GetPoint(1)
    if point == "BOTTOMLEFT" and not Near(y, want, 0.5) then button:SetPoint(point, rel, relPoint, x, want) end
end

-- A spell button's middle at center down from its card's top (the client hangs them by their foot).
local function PutSpell(button, center)
    local point, rel, relPoint, x, y = button:GetPoint(1)
    if point ~= "BOTTOMLEFT" then return end
    local want = PRIMARY_H - center - (button:GetHeight() or 0) / 2
    if not y or math.abs(y - want) > 0.5 then button:SetPoint(point, rel, relPoint, x, want) end
end

-- Parchment page: the spells' middle level with the row's text, the name's top to the bar's foot; a pair as far
-- apart as the old book's.
local function CenterSpells(row, spec, first, second)
    local middle = TextMiddle(row, spec) - spec.cardDrop
    if first and second and first:IsShown() and second:IsShown() then
        -- As close as the old book's pair at their size.
        local half = (SPELL_HIGH - SPELL_LOW) * (spec.spellScale or 1) / 2
        PutSpell(first, middle - half)
        PutSpell(second, middle + half)
    elseif first and first:IsShown() then
        PutSpell(first, middle)
    end
end

function T.TightenSpells()
    local content = Content()
    if not content or InCombatLockdown() then return end
    local spec = Spec()
    for i = 1, 2 do
        local card = Card(content, "PrimaryProfession" .. i)
        local first, second = card and card.SpellButton1, card and card.SpellButton2
        if spec.centerSpells and rows[i] then
            CenterSpells(rows[i], spec, first, second)
        elseif first and second and first:IsShown() and second:IsShown() then
            Foot(first, SPELL_HIGH)
            Foot(second, SPELL_LOW)
        elseif first and first:IsShown() then
            Foot(first, SPELL_ONE)
        end
    end
end

-- A texture loads from disk when first drawn: the book's bands, bars and icons came up frames after the window. Each
-- file the window holds (not its other pages) drawn once at alpha 0 on a speck of ours, some seconds after login.
local PRELOAD_AFTER, PRELOAD_FOR = 5, 5
local OTHER_PAGES = { "CraftingPage", "SpecPage", "OrdersPage" }
local preload, preloaded

local function PreloadTex(region)
    if not region:IsObjectType("Texture") then return end
    local atlas, file = region:GetAtlas(), region:GetTexture()
    local key = atlas or file
    if not key or ns.IsSecret(key) or preloaded[key] then return end
    preloaded[key] = true
    local tex = preload:CreateTexture(nil, "BACKGROUND")
    if atlas then tex:SetAtlas(atlas) else tex:SetTexture(file) end
    tex:SetAllPoints(preload)
    tex:SetAlpha(0)
end

local function PreloadFrom(frame, skip)
    if skip[frame] then return end
    ns.EachRegion(frame, PreloadTex)
    ns.EachChild(frame, PreloadFrom, skip)
end

function T.Preload()
    if preload then return end
    preload = ns.NewFrame("Frame", nil, UIParent)
    preload:SetSize(1, 1)
    preload:SetPoint("BOTTOMLEFT")
    C_Timer.After(PRELOAD_AFTER, function()
        local host = T.Host()
        if not host then return end
        preloaded = {}
        local skip = {}
        for _, key in ipairs(OTHER_PAGES) do
            if host[key] then skip[host[key]] = true end
        end
        PreloadFrom(host, skip)
        C_Timer.After(PRELOAD_FOR, function() preload:Hide() end)
    end)
end

-- Our art only once the cards are placed (impossible in combat): a book first
-- opened in combat showed our rows over the client's cards.
function T.ShowOurs(on)
    if not T.built then return end
    T.shown = on
    local big = T.Big()
    -- The small page's art inside the window's metal: the chrome's backing marks where the rails start.
    local host = T.Host()
    local fcui = host and host.fcui
    local backing = fcui and fcui.backing
    if backing and rows.clipOn ~= backing then
        rows.clipOn = backing
        rows.clip:ClearAllPoints()
        rows.clip:SetAllPoints(backing)
    end
    local banded = Banded()
    if big then PaintFull() end
    for _, tex in ipairs(rows.art) do SetShownIf(tex, on and big) end
    for _, tex in ipairs(rows.small) do SetShownIf(tex, on and not big and not banded) end
    for _, tex in ipairs(rows.bands) do SetShownIf(tex, on and not big and banded) end
    for i = 1, 5 do
        if rows[i] then SetShownIf(rows[i], on) end
    end
end
