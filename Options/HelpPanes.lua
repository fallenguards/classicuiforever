local _, ns = ...
local L = ns.L

-- The FAQ and Support pages: a caption at the page's top, and text on their own scroll child that the page swaps into the
-- list (as Profiles). Option names and key bindings are read as the page shows, in the game's language.

local O = ns.options
local TITLE = O.TITLE
local ANSWER_GAP, ITEM_GAP, BUTTON_GAP = 3, 12, 6
local BUTTON_W, POST_W = 170, 220
local EASYFIND_URL = "https://www.curseforge.com/wow/addons/easyfind"
local DONATE_URL = "https://buymeacoffee.com/easyfind"

local function KeyOf(binding)
    local key = GetBindingKey(binding)
    if not key then return L["FAQ_NOT_BOUND"] end
    local Text = _G.GetBindingText
    return Text and Text(key) or key
end

-- The game's own name for the Recent Allies tab.
local function RecentAllies()
    local header = _G.FriendsTabHeader
    local tab = header and header.GetTabButton and header.recentAlliesTabID and header:GetTabButton(header.recentAlliesTabID)
    return tab and tab:GetText() or _G.CONTACTS_RECENT_ALLIES_TITLE or ""
end

-- Question, answer, and the answer's values. ask: the question's values (else the addon's name). on = "forever" or
-- on = "retail": that client's alone.
local FAQ = {
    { "FAQ_LFG_Q", "FAQ_LFG_A", on = "forever",
        function() return KeyOf("TOGGLEGROUPFINDER"), L["OPT_hideMicroGroupFinder"], L["OPT_hideMicroButtons"] end },
    -- Retail has no finder tabs on the Who tab.
    { "FAQ_LFG_Q", "FAQ_LFG_RETAIL_A", on = "retail",
        function() return KeyOf("TOGGLEGROUPFINDER"), L["OPT_hideMicroGroupFinder"], L["OPT_hideMicroButtons"] end },
    -- Only Forever has a Legacy button.
    { "FAQ_LEGACY_Q", "FAQ_LEGACY_A", on = "forever",
        function() return L["OPT_hideMicroLegacy"], L["OPT_hideMicroButtons"], L["OPT_microMinimapButtons"] end },
    { "FAQ_PROFESSIONS_Q", "FAQ_PROFESSIONS_A",
        function() return KeyOf("TOGGLEPROFESSIONBOOK"), L["OPT_hideProfessionsButton"], L["OPT_hideMicroButtons"] end },
    { "FAQ_COLLECTIONS_Q", "FAQ_COLLECTIONS_A",
        function()
            return L["SKILL_COLLECTIONS"], KeyOf("TOGGLECOLLECTIONS"), L["OPT_hideMicroCollections"], L["OPT_hideMicroButtons"]
        end },
    -- Retail's own buttons that leave the micro menu.
    { "FAQ_RETAILBUTTONS_Q", "FAQ_RETAILBUTTONS_A", on = "retail",
        function()
            return L["OPT_hideMicroAchievements"], KeyOf("TOGGLEACHIEVEMENT"), L["OPT_hideMicroJournal"],
                KeyOf("TOGGLEENCOUNTERJOURNAL"), L["OPT_hideMicroButtons"]
        end,
        ask = function() return L["OPT_hideMicroAchievements"], L["OPT_hideMicroJournal"], L["OPT_hideMicroHousing"] end },
    { "FAQ_QUICKJOIN_Q", "FAQ_QUICKJOIN_A", function()
        local allies = RecentAllies()
        return _G.FRIENDS, allies, _G.QUICK_JOIN, allies
    end, ask = function() return _G.QUICK_JOIN end, on = "retail" },
    -- Forever's round bag beside the key ring; retail has no key ring, so the bag takes its slot.
    { "FAQ_REAGENT_Q", "FAQ_REAGENT_A", on = "forever",
        function() return L["OPT_reagentBagRound"], L["OPT_reagentBagSlot"] end },
    { "FAQ_REAGENT_Q", "FAQ_REAGENT_RETAIL_A", on = "retail", function() return L["OPT_reagentBagSlot"] end },
    { "FAQ_BARS_Q", "FAQ_BARS_A" },
    { "FAQ_MOVE_Q", "FAQ_MOVE_A", function() return L["UI_CLASSICUI_FOREVER_WINDOWS"] end },
    { "FAQ_SETTING_Q", "FAQ_SETTING_A", function() return L["OPTWIN_SEARCH_TOGGLES"] end },
    { "FAQ_FOREVER_Q", "FAQ_FOREVER_A", on = "forever" },
    { "FAQ_OWNLOOK_Q", "FAQ_OWNLOOK_A", on = "retail" },
    { "FAQ_OTHER_ADDON_Q", "FAQ_OTHER_ADDON_A" },
}
for i = #FAQ, 1, -1 do
    local on = FAQ[i].on
    if on and (on == "forever") ~= ns.OnForever() then table.remove(FAQ, i) end
end

-- top: the page's top under its title; headH: how much of the page the caption (and what stands under it) takes.
local function Pane(frame, top, list, headH)
    local pane = ns.NewFrame("Frame", nil, frame)
    pane:SetAllPoints(frame)
    pane:Hide()
    local caption = pane:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    caption:SetPoint("TOPLEFT", top, "TOPLEFT", 2, 0)
    caption:SetWidth(list:GetWidth())
    caption:SetJustifyH("LEFT")
    pane.caption, pane.headH = caption, headH
    local child = ns.NewFrame("Frame", nil, list)
    child:SetSize(list:GetWidth(), 1)
    child:Hide()
    pane.child = child
    return pane, child
end

local function Text(child, font)
    local text = child:CreateFontString(nil, "OVERLAY", font)
    text:SetWidth(child:GetWidth() - 12)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetSpacing(2)
    return text
end

-- Shown pieces down the child, each gap under the one before (none over the first); beside: next to that piece.
local function Stack(child, pieces, setRange)
    local y, first = 0, true
    for _, piece in ipairs(pieces) do
        local region = piece.region
        if piece.beside then
            ns.SetPointOnce(region, "LEFT", piece.beside, "RIGHT", BUTTON_GAP, 0)
        elseif region:IsShown() then
            y = y + (first and 0 or piece.gap)
            first = false
            ns.SetPointOnce(region, "TOPLEFT", child, "TOPLEFT", piece.x or 0, -y)
            y = y + (region.GetStringHeight and region:GetStringHeight() or region:GetHeight())
        end
    end
    child:SetHeight(math.max(1, y))
    setRange(y)
end

-- Every word of the search somewhere in the question or its answer.
local function Matches(row, words)
    local text = (row.question:GetText() .. " " .. row.answer:GetText()):lower()
    for _, word in ipairs(words) do
        if not text:find(word, 1, true) then return false end
    end
    return true
end

function O.FaqPane(frame, top, list, setRange)
    local pane, child = Pane(frame, top, list, 50)
    pane.caption:SetText(L["FAQ_CAPTION"])
    local find = ns.SearchBox(pane, 240, L["FAQ_SEARCH"])
    find:SetPoint("TOPLEFT", pane.caption, "BOTTOMLEFT", 4, -8)
    local pieces, rows = {}, {}
    for i = 1, #FAQ do
        local question, answer = Text(child, "GameFontNormal"), Text(child, "GameFontHighlight")
        pieces[#pieces + 1] = { region = question, gap = ITEM_GAP }
        pieces[#pieces + 1] = { region = answer, gap = ANSWER_GAP }
        rows[i] = { question = question, answer = answer }
    end
    local none = Text(child, "GameFontDisable")
    none:SetText(L["FAQ_NONE"])
    pieces[#pieces + 1] = { region = none, gap = 0 }
    function pane.Refresh()
        local typed = find:GetText()
        local words = {}
        for word in typed:lower():gmatch("%S+") do words[#words + 1] = word end
        local any = false
        for i, item in ipairs(FAQ) do
            local row = rows[i]
            -- Not an and/or: that keeps only ask's first value.
            if item.ask then
                row.question:SetText(L[item[1]]:format(item.ask()))
            else
                row.question:SetText(L[item[1]]:format(TITLE))
            end
            row.answer:SetText(item[3] and L[item[2]]:format(item[3]()) or L[item[2]])
            local hit = Matches(row, words)
            row.question:SetShown(hit)
            row.answer:SetShown(hit)
            any = any or hit
        end
        none:SetShown(not any)
        find.hint:SetShown(typed == "")
        find.clear:SetShown(typed ~= "")
        Stack(child, pieces, setRange)
    end
    find:SetScript("OnTextChanged", pane.Refresh)
    return pane
end

function O.SupportPane(frame, top, list, setRange)
    local pane, child = Pane(frame, top, list, 22)
    pane.caption:SetText(L["SUPPORT_CAPTION"]:format(TITLE))
    local pieces = {}
    local function Add(font, text, gap)
        local region = Text(child, font)
        region:SetText(text)
        pieces[#pieces + 1] = { region = region, gap = gap }
    end
    local function Button(label, onClick, beside, width)
        local button = ns.PanelButton(child, label, width or BUTTON_W)
        button:SetScript("OnClick", onClick)
        pieces[#pieces + 1] = { region = button, gap = BUTTON_GAP, beside = beside }
        return button
    end
    Add("GameFontNormal", L["SUPPORT_FEEDBACK_HEAD"], 0)
    -- The status report first: what a report needs before it is posted.
    Add("GameFontHighlight", L["SUPPORT_FEEDBACK"]:format(L["OPTWIN_STATUS_REPORT"]), ANSWER_GAP)
    Button(L["OPTWIN_STATUS_REPORT"], ns.ShowStatus)
    Add("GameFontHighlight", L["SUPPORT_POST"], ITEM_GAP)
    local github = Button(L["OPTWIN_GITHUB_PREFERRED"], O.CopyGitHub, nil, POST_W)
    Button(L["OPTWIN_CURSEFORGE"], O.CopyCurseForge, github)
    Add("GameFontNormal", L["SUPPORT_MORE_HEAD"], ITEM_GAP)
    Add("GameFontHighlight", L["SUPPORT_MORE"], ANSWER_GAP)
    Button(L["SUPPORT_MORE_BUTTON"], function() O.CopyLink(L["SUPPORT_MORE_BUTTON"], EASYFIND_URL) end)
    Add("GameFontNormal", L["SUPPORT_DONATE_HEAD"], ITEM_GAP)
    Add("GameFontHighlight", L["SUPPORT_DONATE"]:format(TITLE), ANSWER_GAP)
    Button(L["SUPPORT_DONATE_BUTTON"], function() O.CopyLink(L["SUPPORT_DONATE_BUTTON"], DONATE_URL) end)
    function pane.Refresh() Stack(child, pieces, setRange) end
    return pane
end
