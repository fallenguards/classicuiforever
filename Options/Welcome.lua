local _, ns = ...
local L = ns.L

-- One-time welcome note. The game cannot open a browser, so links open a copy box.
local O = ns.options
local TITLE = O.TITLE
local WIDTH = 420
-- A standalone package's own project and tracker (tools/standalone.py); the full addon's otherwise.
local PKG = ns.PACKAGE
local CURSEFORGE_URL = PKG and PKG.curseforge or "https://www.curseforge.com/projects/1700043"
local GITHUB_URL = PKG and PKG.issues
    or "https://github.com/fallenguards/classicuiforever/issues/new/choose?addon=ClassicUI%20Forever%20(full%20addon)"

-- A standalone piece's own note: the full addon's names parts a piece may not have.
local BODY = PKG and PKG.piece and L["WELCOME_BODY_PIECE"]:format(ns.SLASH) or L["WELCOME_BODY"]

local OnForever = ns.OnForever

ns.Popup("FCUI_COPY_LINK", {
    text = L["WELCOME_COPY_PROMPT"],
    button1 = CLOSE or "Close",
    hasEditBox = 1,
    editBoxWidth = 360,
    OnShow = function(self, data)
        local box = ns.PopupEditBox(self)
        if box then
            box:SetText(data or "")
            box:HighlightText()
            box:SetFocus()
        end
    end,
    -- Read-only: typed text is reverted.
    EditBoxOnTextChanged = function(self, data)
        if self:GetText() ~= (data or "") then
            self:SetText(data or "")
            self:HighlightText()
        end
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    EditBoxOnEnterPressed = function(self) self:GetParent():Hide() end,
})

local function CopyLink(label, url)
    StaticPopup_Show("FCUI_COPY_LINK", label, nil, url)
end

local function CopyCurseForge() CopyLink(TITLE .. " on CurseForge", CURSEFORGE_URL) end
local function CopyGitHub() CopyLink(TITLE .. " issues on GitHub", GITHUB_URL) end
O.CopyCurseForge, O.CopyGitHub, O.CopyLink = CopyCurseForge, CopyGitHub, CopyLink

-- CurseForge and GitHub buttons; the caller anchors them.
function O.FeedbackButtons(parent, width)
    local curse = ns.PanelButton(parent, L["OPTWIN_CURSEFORGE"], width)
    curse:SetScript("OnClick", CopyCurseForge)
    local github = ns.PanelButton(parent, L["OPTWIN_GITHUB_ISSUES"], width)
    github:SetScript("OnClick", CopyGitHub)
    return curse, github
end

local window

-- The note's text block under the header, as wide as the window allows.
local function BodyText(frame, text)
    local body = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    body:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -50)
    body:SetWidth(WIDTH - 48)
    body:SetJustifyH("LEFT")
    body:SetJustifyV("TOP")
    body:SetSpacing(2)
    body:SetText(text)
    return body
end

local function Build()
    local frame = O.DialogWindow("ForeverClassicUIWelcome", 120)
    ns.DialogHeader(frame, TITLE)

    local body = BodyText(frame, BODY)
    local signoff = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    signoff:SetPoint("TOP", body, "BOTTOM", 0, -14)
    signoff:SetJustifyH("CENTER")
    signoff:SetText(OnForever() and L["WELCOME_SIGNOFF"] or "")

    local curse, github = O.FeedbackButtons(frame, 120)
    local okay = ns.PanelButton(frame, L["OPTWIN_OKAY"], 90)
    okay:SetScript("OnClick", function() frame:Hide() end)

    curse:SetPoint("BOTTOMRIGHT", frame, "BOTTOM", -4, 50)
    github:SetPoint("BOTTOMLEFT", frame, "BOTTOM", 4, 50)
    okay:SetPoint("BOTTOM", frame, "BOTTOM", 0, 20)

    frame:SetScript("OnHide", function()
        ns.db.welcomed = true
        -- The layout question follows.
        ns.CheckLayoutPosition()
    end)

    frame:SetSize(WIDTH, 50 + body:GetStringHeight() + (OnForever() and 30 or 0) + 100)
    return frame
end

function ns.ShowWelcome()
    if not window then window = Build() end
    window:Show()
end

-- Chat link in the game's link blue, handled by OnItemRef.
local function Link(target, label)
    return "|cff70d6ff|Hfcui:" .. target .. "|h[" .. label .. "]|h|r"
end

-- Runs in every hyperlink click.
local function OnItemRef(link)
    local target = type(link) == "string" and link:match("^fcui:(%w+)")
    if target == "status" then
        if ns.ShowStatus then ns.ShowStatus() end
    elseif target == "news" then
        ns.ShowWhatsNew()
    elseif target == "bars" then
        ns.ShowBarsNote()
    elseif target == "look" then
        ns.ShowBarsLook()
    elseif target == "onebar" then
        ns.ShowOneBarArt()
    elseif target == "scale" then
        ns.ShowScaleHelp()
    elseif target == "curseforge" then
        CopyCurseForge()
    elseif target == "github" then
        CopyGitHub()
    elseif target == "easyfind" then
        CopyLink("EasyFind on CurseForge", O.EASYFIND_URL)
    elseif target == "barsnote" then
        ns.OpenOptionsAt("barsTakenNote")
    end
end

-- Hooked on first use, once.
local function HookLinks()
    ns.HookGlobal("SetItemRef", OnItemRef)
end

local WHATSNEW = ns.WHATSNEW
local LATEST = WHATSNEW[1].id
-- This client's list: a version with no entry for it is left out whole (no chat line there, a silent update).
local NEWS = {}
for _, section in ipairs(WHATSNEW) do
    local mine = { id = section.id, version = section.version }
    for _, entry in ipairs(section) do
        if not entry.on or (entry.on == "forever") == ns.OnForever() then mine[#mine + 1] = entry end
    end
    if #mine > 0 then NEWS[#NEWS + 1] = mine end
end
local GOLD, GREY = "|cffffd100", "|cffa0a0a0"
local CHANGELOG_URL = "https://github.com/fallenguards/classicuiforever/blob/main/CHANGELOG.md"
-- The box fits the text up to NEWS_BODY_H; past that it stays that tall and the bar scrolls the rest.
local NEWS_WIDTH, NEWS_BODY_H, NEWS_WHEEL = 480, 280, 28
local NEWS_BAR_ROOM = 24
local NEWS_HEADER = { width = 320 }   -- the plate: "What's New in x.y.z" runs past the stock 256

local function CopyChangelog() CopyLink(string.format(L["WELCOME_CHANGELOG_LINK"], TITLE), CHANGELOG_URL) end

-- The entries of every version newer than seen, each version headed by its number when there is more than one.
local function NewsText(seen)
    local sections = {}
    for _, section in ipairs(NEWS) do
        if section.id > seen then sections[#sections + 1] = section end
    end
    if #sections == 0 then sections[1] = NEWS[1] end
    local lines = {}
    for _, section in ipairs(sections) do
        if #sections > 1 then lines[#lines + 1] = GREY .. section.version .. "|r" end
        for _, entry in ipairs(section) do lines[#lines + 1] = GOLD .. entry[1] .. ":|r " .. entry[2] end
    end
    return table.concat(lines, "\n")
end

local newsWindow
local function BuildNews()
    local frame = O.DialogWindow("ForeverClassicUIWhatsNew", 120)
    ns.DialogHeader(frame, string.format(L["WELCOME_WHATS_NEW_IN"], NEWS[1].version), NEWS_HEADER)
    -- The text in a fixed box, scrolled by the classic bar or the wheel.
    local fullW = NEWS_WIDTH - 48
    local scroll = ns.NewFrame("ScrollFrame", nil, frame)
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -50)
    scroll:EnableMouseWheel(true)
    local child = ns.NewFrame("Frame", nil, scroll)
    scroll:SetScrollChild(child)
    local body = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    body:SetPoint("TOPLEFT", child, "TOPLEFT", 0, 0)
    body:SetJustifyH("LEFT")
    body:SetJustifyV("TOP")
    body:SetSpacing(3)
    local bar = ns.ClassicScrollBar(frame, scroll, function(value) scroll:SetVerticalScroll(value or 0) end)
    bar.hideWhenIdle = true
    scroll:SetScript("OnMouseWheel", function(_, delta) bar:SetValue(bar:GetValue() - delta * NEWS_WHEEL) end)
    local changelog = ns.PanelButton(frame, L["OPTWIN_FULL_CHANGELOG"], 120)
    changelog:SetScript("OnClick", CopyChangelog)
    changelog:SetPoint("BOTTOMRIGHT", frame, "BOTTOM", -4, 20)
    local okay = ns.PanelButton(frame, L["OPTWIN_OKAY"], 90)
    okay:SetScript("OnClick", function() frame:Hide() end)
    okay:SetPoint("BOTTOMLEFT", frame, "BOTTOM", 4, 20)
    -- Refilled on every show: the versions since the one the player saw last.
    frame.Fill = function(_, seen)
        -- Full width first; only text taller than the box gives up room for the bar.
        body:SetText(NewsText(seen))
        body:SetWidth(fullW)
        local height = math.ceil(body:GetStringHeight())
        local textW = fullW
        if height > NEWS_BODY_H then
            textW = fullW - NEWS_BAR_ROOM
            body:SetWidth(textW)
            height = math.ceil(body:GetStringHeight())
        end
        local boxH = math.min(height, NEWS_BODY_H)
        scroll:SetSize(textW, boxH)
        child:SetSize(textW, height)
        bar:SetValue(0)
        bar:SetRange(height - boxH, NEWS_WHEEL)
        scroll:SetVerticalScroll(0)
        scroll:EnableMouseWheel(height > boxH)
        frame:SetSize(NEWS_WIDTH, 50 + boxH + 16 + 22 + 20)
    end
    return frame
end

-- The versions the chat line offered (whatsNewFrom), else the newest one alone (a fresh install was offered none).
function ns.ShowWhatsNew()
    if not newsWindow then newsWindow = BuildNews() end
    local from = tonumber(ns.db and ns.db.whatsNewFrom) or 0
    if from <= 0 or from >= LATEST then from = LATEST - 1 end
    newsWindow:Fill(from)
    newsWindow:Show()
end

-- For players coming from 0.11.0 (list 2), whose bar pieces flipped back with 0.11.1.
local BARS_NOTE = L["WELCOME_BARS_NOTE"]

local barsWindow
function ns.ShowBarsNote()
    if not barsWindow then
        local frame = O.DialogWindow("ForeverClassicUIBarsNote", 120)
        ns.DialogHeader(frame, L["WELCOME_YOUR_BARS"])
        local body = BodyText(frame, BARS_NOTE)
        local check = ns.NewFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
        check:SetSize(26, 26)
        check:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, 18)
        ns.SkinCheckbox(check)
        local label = check:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("LEFT", check, "RIGHT", 2, 0)
        label:SetText(L["OPTWIN_DON_T_SHOW_THIS_AGAIN"])
        check:SetScript("OnClick", function(self) ns.db.barsNoteOff = self:GetChecked() and true or false end)
        frame.check = check
        local okay = ns.PanelButton(frame, L["OPTWIN_OKAY"], 90)
        okay:SetScript("OnClick", function() frame:Hide() end)
        okay:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -22, 20)
        frame:SetSize(WIDTH, 50 + body:GetStringHeight() + 70)
        barsWindow = frame
    end
    barsWindow.check:SetChecked(ns.db.barsNoteOff == true)
    barsWindow:Show()
end

-- Every login for a player who came from 0.11.0, until the note's box is ticked; the Addon messages row hushes it.
function ns.AnnounceBarsNote()
    if not ns.db or not ns.db.barsNote or ns.db.barsNoteOff or ns.db.addonMessages == false then return end
    HookLinks()
    ns.Print(string.format(L["WELCOME_BARS_CHAT"], Link("bars", L["WELCOME_HERE"])))
end

-- 0.14.0's bar changes reached players from before it unasked: back as they were, the classic look, or kept as they are.
local LOOK_BUTTON_W = 128
local lookWindow
function ns.ShowBarsLook()
    if not lookWindow then
        local frame = O.DialogWindow("ForeverClassicUIBarsLook", 120)
        ns.DialogHeader(frame, L["WELCOME_YOUR_BARS"])
        local body = BodyText(frame, L["WELCOME_BARS_LOOK_TEXT"])
        local old = ns.PanelButton(frame, L["WELCOME_PRE_0140_LOOK"], LOOK_BUTTON_W)
        local classic = ns.PanelButton(frame, L["WELCOME_CLASSIC_LOOK"], LOOK_BUTTON_W)
        local keep = ns.PanelButton(frame, L["OPTWIN_KEEP_MINE"], LOOK_BUTTON_W)
        classic:SetPoint("BOTTOM", frame, "BOTTOM", 0, 20)
        old:SetPoint("RIGHT", classic, "LEFT", -6, 0)
        keep:SetPoint("LEFT", classic, "RIGHT", 6, 0)
        -- The switch runs from a game popup's button: from ours the game refused it, from its popups it never has.
        old:SetScript("OnClick", function() frame:Hide() StaticPopup_Show("FCUI_OLD_LOOK_CONFIRM") end)
        classic:SetScript("OnClick", function() frame:Hide() StaticPopup_Show("FCUI_CLASSIC_LOOK_OFFER") end)
        keep:SetScript("OnClick", function() frame:Hide() ns.ChooseBarsLook(nil) end)
        frame:SetSize(WIDTH, 50 + body:GetStringHeight() + 64)
        lookWindow = frame
    end
    lookWindow:Show()
end

-- Every login until they choose; the Addon messages row hushes it.
function ns.AnnounceBarsLook()
    if not ns.db or not ns.db.barsLookNote or ns.db.addonMessages == false then return end
    HookLinks()
    ns.Print(string.format(L["WELCOME_BARS_LOOK_CHAT"], Link("look", L["WELCOME_HERE"])))
end

-- Once per new version, as a chat line with a link; the dev addon clears the mark to see it again.
function ns.AnnounceWhatsNew()
    if not ns.db then return end
    local seen = tonumber(ns.db.whatsNewSeen) or 0
    if seen >= LATEST then return end
    ns.db.whatsNewFrom = seen
    ns.db.whatsNewSeen = LATEST
    if seen == 2 then ns.db.barsNote = true end
    -- Nothing in the new versions for this client: a silent update.
    if NEWS[1].id <= seen then return end
    if ns.db.addonMessages == false then return end
    HookLinks()
    local version = ns.AddonVersion and ns.AddonVersion() or ""
    ns.Print(string.format(L["WELCOME_UPDATED"], version, Link("news", L["WELCOME_HERE"])))
end

-- Chat link for any addon message; installs the click handler.
function ns.ChatLink(target, label)
    HookLinks()
    return Link(target, label)
end

-- Ran the addon before the beta kept saved variables (1.60.1 70009): the classic layout survived.
local function Returning()
    return ns.ClassicLayoutActive()
end

-- Forever's welcome at every login, its options row or Addon messages off hush it: the bug report link (the issues
-- copy box) and EasyFind's page. No hide link in the line: the row is there for whoever looks for it.
local function AnnounceLaunch()
    if not OnForever() or ns.db.addonMessages == false or ns.db.foreverWelcome == false then return end
    HookLinks()
    ns.Print(L["LAUNCH_THANKS"]:format(TITLE, Link("github", L["WELCOME_HERE"])) .. " "
        .. L["LAUNCH_EASYFIND"]:format(Link("easyfind", "EasyFind")))
end

-- A new player gets the welcome, then the layout question as it closes; everyone else the What's New, once per list.
function ns.FirstRun()
    if not ns.db then return end
    ns.SafeCall(AnnounceLaunch)
    -- A standalone package: one chat line naming the full addon (the color picker: its look pick too), no news; the
    -- layout question only with the classic bar.
    if ns.PACKAGE then
        if not ns.db.welcomed then
            ns.db.welcomed = true
            ns.Print(L[ns.PACKAGE.piece and "PKG_INTRO" or "PKG_INTRO_PICKER"]:format(ns.SLASH))
            if not ns.PACKAGE.piece then ns.ShowLookPick() end
        end
        if ns.PACKAGE.kept.classicBar then ns.CheckLayoutPosition() end
        return
    end
    if not ns.db.welcomed and Returning() then ns.db.welcomed = true end
    if ns.db.welcomed then
        ns.SafeCall(ns.AnnounceWhatsNew)
        ns.SafeCall(ns.AnnounceBarsNote)
        ns.SafeCall(ns.AnnounceBarsLook)
        ns.SafeCall(ns.AnnounceOneBarArt)
        ns.SafeCall(ns.AnnounceScaleBack)
        ns.CheckLayoutPosition()
        return
    end
    -- The welcome stands in for this list.
    ns.db.whatsNewSeen = LATEST
    if ns.db.welcomeNote == false or ns.db.addonMessages == false then
        ns.db.welcomed = true
        ns.CheckLayoutPosition()
        return
    end
    ns.ShowWelcome()
end
