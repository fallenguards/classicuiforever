local _, ns = ...

-- Books and opened letters under a theme, as the quest log's page: the parchment inked (ns.InkPage), its dark words near
-- white while the page is dark (ns.PageDark), their own colors back once it is light again.

local HTML_TAGS = { "P", "H1", "H2", "H3" }
local MAIL_PAGE = { "OpenStationeryBackgroundLeft", "OpenStationeryBackgroundRight" }
local DARK = 0.35   -- a word darker than this in every channel is ink
local was = setmetatable({}, { __mode = "k" })   -- font string -> its color before ours

local function SetTags(html, r, g, b)
    for _, tag in ipairs(HTML_TAGS) do html:SetTextColor(tag, r, g, b) end
end

-- A book's text: lit on our dark page; else the game's color for its material (its light text setting reads as stone).
local bookOurs, bookLit = false, false
function ns.InkBookText(ours)
    local html = ItemTextPageText
    if not html then return end
    bookOurs = ours
    if ours and ns.PageDark() then
        bookLit = true
        SetTags(html, unpack(ns.PAGE_INK))
    elseif bookLit then
        bookLit = false
        local material = QuestTextContrast and QuestTextContrast.UseLightText() and "Stone"
            or ItemTextGetMaterial() or "Parchment"
        local text = GetMaterialTextColors(material)
        SetTags(html, text[1], text[2], text[3])
    end
end

-- A letter's word: lit while the page is dark and it is dark; its color back after.
local function InkWord(region, dark)
    if not region:IsObjectType("FontString") then return end
    local r, g, b = region:GetTextColor()
    if ns.AnySecret(r, g, b) then return end
    if dark and r < DARK and g < DARK and b < DARK then
        was[region] = { r, g, b }
        region:SetTextColor(unpack(ns.PAGE_INK))
    elseif not dark and was[region] then
        region:SetTextColor(unpack(was[region]))
        was[region] = nil
    end
end
local function InkWords(frame, dark)
    ns.EachRegion(frame, InkWord, dark)
    ns.EachChild(frame, function(child)
        if not child:IsObjectType("Button") then InkWords(child, dark) end
    end)
end

local mailLit = false
local function InkMail()
    for _, name in ipairs(MAIL_PAGE) do
        if _G[name] then ns.InkPage(_G[name]) end
    end
    local dark = ns.PageDark()
    local body = OpenMailBodyText
    if body and dark then
        mailLit = true
        SetTags(body, unpack(ns.PAGE_INK))
    elseif body and mailLit then
        mailLit = false
        SetTags(body, MailTextFontNormal:GetTextColor())
    end
    if OpenMailScrollChildFrame then InkWords(OpenMailScrollChildFrame, dark) end
end

-- Each letter opened fills the same window: looked at each time it shows and while it stays open.
local watching = false
function ns.panels.after.OpenMailFrame(frame)
    if watching then return end
    watching = true
    ns.Sched.OnVisible(frame, "pageInk.mail", function(shown)
        if shown then ns.Sched.NextFrame("pageInk.mail", InkMail) end
    end)
    ns.Sched.Attach(frame, { name = "pageInk.mailLook", every = 0.5, fn = InkMail })
end

ns.OnToggle(function(key)
    if not ns.ThemeKey(key) then return end
    if ItemTextFrame and ItemTextFrame:IsShown() then ns.InkBookText(bookOurs) end
    if OpenMailFrame and OpenMailFrame:IsShown() then InkMail() end
end)
