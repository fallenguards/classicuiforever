local _, ns = ...
local L = ns.L

-- The FAQ and Support pages: a caption at the page's top, and text on their own scroll child that the page swaps into the
-- list (as Profiles). Option names and key bindings are read as the page shows, in the game's language.

local O = ns.options
local TITLE = O.TITLE
local ANSWER_GAP, ITEM_GAP, BUTTON_GAP = 3, 12, 6
local BUTTON_W, POST_W = 170, 220
local EASYFIND_URL = "https://www.curseforge.com/wow/addons/easyfind"
local SUITE, SUITE_URL = "ClassicUI Forever", "https://www.curseforge.com/wow/addons/classicui-forever"
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

-- The game's own label (its global string), or the name on a client without it.
local function G(name) return _G[name] or name end
-- An option named "Label: item": either half.
local function Before(text) return text:match("^(.-):") or text end
local function After(text) return text:match(":%s*(.+)$") or text end

-- A micro button off the bar with only its key to open it (a package without the minimap or spellbook pieces).
local function MicroKey(binding, option)
    return function() return KeyOf(binding), L[option], L["OPT_hideMicroButtons"] end
end

-- Our windows with a lock on the title bar.
local LOCKED = { "characterSheet", "professionsBook", "tradeSkill", "talents", "legacyWindow", "collectionsWindow",
    "questLog", "worldMap", "spellBook", "panelSocial", "groupFinder", "panelQuest", "panelGossip", "windowLocksAlways" }

-- Question, answer, its values; ask: the question's values. on: one client's alone. needs (all) or anyOf (one): the
-- settings or modules the answer names, in this copy. only / notIn: a kind of standalone. A question's first fit shows.
local FAQ = {
    { "FAQ_SUITE_Q", "FAQ_SUITE_A", only = "piece" },
    { "FAQ_SUITE_Q", "FAQ_SUITE_PICKER_A", only = "picker" },
    { "FAQ_LFG_Q", "FAQ_LFG_A", on = "forever", needs = { "hideMicroGroupFinder", "microMinimapButtons", "groupFinder" },
        function() return KeyOf("TOGGLEGROUPFINDER"), L["OPT_hideMicroGroupFinder"], L["OPT_hideMicroButtons"] end },
    -- Retail has no finder tabs on the Who tab.
    { "FAQ_LFG_Q", "FAQ_LFG_RETAIL_A", on = "retail", needs = { "hideMicroGroupFinder", "microMinimapButtons" },
        function() return KeyOf("TOGGLEGROUPFINDER"), L["OPT_hideMicroGroupFinder"], L["OPT_hideMicroButtons"] end },
    { "FAQ_LFG_Q", "FAQ_MICRO_KEY_A", needs = { "hideMicroGroupFinder" },
        MicroKey("TOGGLEGROUPFINDER", "OPT_hideMicroGroupFinder") },
    -- Only Forever has a Legacy button.
    { "FAQ_LEGACY_Q", "FAQ_LEGACY_A", on = "forever", needs = { "hideMicroLegacy", "microMinimapButtons" },
        function() return L["OPT_hideMicroLegacy"], L["OPT_hideMicroButtons"], L["OPT_microMinimapButtons"] end },
    { "FAQ_LEGACY_Q", "FAQ_MICRO_OFF_A", on = "forever", needs = { "hideMicroLegacy" },
        function() return L["OPT_hideMicroLegacy"], L["OPT_hideMicroButtons"] end },
    { "FAQ_PROFESSIONS_Q", "FAQ_PROFESSIONS_A", needs = { "hideProfessionsButton", "spellBook" },
        function() return KeyOf("TOGGLEPROFESSIONBOOK"), L["OPT_hideProfessionsButton"], L["OPT_hideMicroButtons"] end },
    { "FAQ_PROFESSIONS_Q", "FAQ_MICRO_KEY_A", needs = { "hideProfessionsButton" },
        MicroKey("TOGGLEPROFESSIONBOOK", "OPT_hideProfessionsButton") },
    { "FAQ_COLLECTIONS_Q", "FAQ_COLLECTIONS_A", needs = { "hideMicroCollections", "spellBookCollectionsTab" },
        function()
            return L["SKILL_COLLECTIONS"], KeyOf("TOGGLECOLLECTIONS"), L["OPT_hideMicroCollections"], L["OPT_hideMicroButtons"]
        end },
    { "FAQ_COLLECTIONS_Q", "FAQ_MICRO_KEY_A", needs = { "hideMicroCollections" },
        MicroKey("TOGGLECOLLECTIONS", "OPT_hideMicroCollections") },
    -- Retail's own buttons that leave the micro menu.
    { "FAQ_RETAILBUTTONS_Q", "FAQ_RETAILBUTTONS_A", on = "retail", needs = { "hideMicroAchievements", "microMinimapButtons" },
        function()
            return L["OPT_hideMicroAchievements"], KeyOf("TOGGLEACHIEVEMENT"), L["OPT_hideMicroJournal"],
                KeyOf("TOGGLEENCOUNTERJOURNAL"), L["OPT_hideMicroButtons"]
        end,
        ask = function() return L["OPT_hideMicroAchievements"], L["OPT_hideMicroJournal"], L["OPT_hideMicroHousing"] end },
    { "FAQ_RETAILBUTTONS_Q", "FAQ_RETAILBUTTONS_KEY_A", on = "retail", needs = { "hideMicroAchievements" },
        function()
            return L["OPT_hideMicroAchievements"], KeyOf("TOGGLEACHIEVEMENT"), L["OPT_hideMicroJournal"],
                KeyOf("TOGGLEENCOUNTERJOURNAL"), L["OPT_hideMicroButtons"]
        end,
        ask = function() return L["OPT_hideMicroAchievements"], L["OPT_hideMicroJournal"], L["OPT_hideMicroHousing"] end },
    { "FAQ_QUICKJOIN_Q", "FAQ_QUICKJOIN_A", function()
        local allies = RecentAllies()
        return _G.FRIENDS, allies, _G.QUICK_JOIN, allies
    end, ask = function() return _G.QUICK_JOIN end, on = "retail", needs = { "panelSocial" } },
    -- Forever's round bag beside the key ring; retail has no key ring, so the bag takes its slot.
    { "FAQ_REAGENT_Q", "FAQ_REAGENT_A", on = "forever", needs = { "classicBar", "reagentBagSlot" },
        function() return L["OPT_reagentBagRound"], L["OPT_reagentBagSlot"] end },
    { "FAQ_REAGENT_Q", "FAQ_REAGENT_RETAIL_A", on = "retail", needs = { "classicBar", "reagentBagSlot" },
        function() return L["OPT_reagentBagSlot"] end },
    -- The band follows Action Bar 1's own edit mode settings.
    { "FAQ_TENBUTTONS_Q", "FAQ_TENBUTTONS_A", needs = { "classicBar" }, function()
        return G("HUD_EDIT_MODE_SETTING_ACTION_BAR_NUM_ICONS"), G("HUD_EDIT_MODE_SETTING_ACTION_BAR_ICON_SIZE"),
            L["OPT_classicBarSize"], L["GROUP_ACTION_BARS"]
    end },
    { "FAQ_GRYPHONS_Q", "FAQ_GRYPHONS_A", needs = { "classicBar" }, function()
        return L["GROUP_ACTION_BARS"], Before(L["OPT_hideGryphonLeft"]), Before(L["OPT_hideGryphonRight"]),
            After(L["OPT_hideGryphonLeft"])
    end },
    { "FAQ_XPBAR_Q", "FAQ_XPBAR_A", needs = { "classicBar" }, function() return L["BAR_HIDE_THIS_BAR"] end },
    { "FAQ_MOVE_Q", "FAQ_MOVE_A", anyOf = LOCKED, function() return L["UI_CLASSICUI_FOREVER_WINDOWS"] end },
    { "FAQ_MOVERS_Q", "FAQ_MOVERS_A", needs = { "leaveGameWindows", "spellBook", "questLog" },
        function() return L["OPT_leaveGameWindows"] end },
    { "FAQ_SIZE_Q", "FAQ_SIZE_A", needs = { "classicBar", "leaveGameWindows" },
        function() return L["UI_CLASSICUI_FOREVER_WINDOWS"], L["OPT_classicBarSize"] end },
    { "FAQ_SCALE_Q", "FAQ_SCALE_A", needs = { "classicBar" },
        function() return _G.GRAPHICS_LABEL or "Graphics", _G.USE_UISCALE or "Use UI Scale" end },
    { "FAQ_SCALEBACK_Q", "FAQ_SCALEBACK_A", needs = { "classicBar" }, function()
        return L["OPTWIN_TOGGLE_NONE"], L["OPTWIN_NONE_SCALE"], _G.GRAPHICS_LABEL or "Graphics", _G.USE_UISCALE or "Use UI Scale"
    end },
    { "FAQ_SETTING_Q", "FAQ_SETTING_A", function() return L["OPTWIN_SEARCH_TOGGLES"] end },
    { "FAQ_FOREVER_Q", "FAQ_FOREVER_A", on = "forever", notIn = "picker" },
    { "FAQ_OWNLOOK_Q", "FAQ_OWNLOOK_A", on = "retail", notIn = "picker" },
    { "FAQ_GLOW_Q", "FAQ_GLOW_A", needs = { "hideThreatGlow" },
        function() return L["GROUP_UNIT_FRAMES"], L["OPT_hideThreatGlow"], L["OPT_hideCombatGlow"] end },
    { "FAQ_TRACKER_Q", "FAQ_TRACKER_A", needs = { "questTracker" },
        function() return L["GROUP_QUESTS"], Before(L["OPT_questTracker"]) end },
    { "FAQ_PLATES_Q", "FAQ_PLATES_A", needs = { "namePlates" },
        function() return G("NAMEPLATE_OPTIONS_LABEL"), L["OPTWIN_NAME_TEXT_SIZE"], L["GROUP_NAMEPLATES"] end },
    { "FAQ_OTHER_ADDON_Q", "FAQ_OTHER_ADDON_A" },
}

-- Which copy this is: the full addon, a ClassicUI Forever piece, or the color picker.
local function Copy()
    if not ns.PACKAGE then return "full" end
    return ns.PACKAGE.piece and "piece" or "picker"
end

local function Fits(item, copy)
    if item.on and (item.on == "forever") ~= ns.OnForever() then return false end
    if (item.only and item.only ~= copy) or item.notIn == copy then return false end
    for _, key in ipairs(item.needs or ns.EMPTY) do
        if not ns.PackageRuns(key) then return false end
    end
    if not item.anyOf then return true end
    for _, key in ipairs(item.anyOf) do
        if ns.PackageRuns(key) then return true end
    end
    return false
end

-- This client's and this copy's questions, each with its first fitting answer; read once a package is set up.
local function Shown()
    local copy, list, asked = Copy(), {}, {}
    for _, item in ipairs(FAQ) do
        if not asked[item[1]] and Fits(item, copy) then
            asked[item[1]] = true
            list[#list + 1] = item
        end
    end
    return list
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
    local pieces, rows, shown = {}, {}, Shown()
    for i = 1, #shown do
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
        for i, item in ipairs(shown) do
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
        pieces[#pieces + 1] = { region = button, gap = BUTTON_GAP, beside = beside, minW = width or BUTTON_W }
        return button
    end
    Add("GameFontNormal", L["SUPPORT_FEEDBACK_HEAD"], 0)
    -- The status report first: what a report needs before it is posted.
    Add("GameFontHighlight", L["SUPPORT_FEEDBACK"]:format(L["OPTWIN_STATUS_REPORT"]), ANSWER_GAP)
    Button(L["OPTWIN_STATUS_REPORT"], ns.ShowStatus)
    Add("GameFontHighlight", L["SUPPORT_POST"], ITEM_GAP)
    local github = Button(L["OPTWIN_GITHUB_PREFERRED"], O.CopyGitHub, nil, POST_W)
    Button(L["OPTWIN_CURSEFORGE"], O.CopyCurseForge, github)
    -- A standalone: the full addon it comes from.
    local copy = Copy()
    if copy ~= "full" then
        Add("GameFontNormal", SUITE, ITEM_GAP)
        Add("GameFontHighlight", L[copy == "piece" and "FAQ_SUITE_A" or "FAQ_SUITE_PICKER_A"], ANSWER_GAP)
        Button(L["SUPPORT_SUITE_BUTTON"], function() O.CopyLink(L["SUPPORT_SUITE_BUTTON"], SUITE_URL) end, nil, POST_W)
    end
    Add("GameFontNormal", L["SUPPORT_MORE_HEAD"], ITEM_GAP)
    Add("GameFontHighlight", L["SUPPORT_MORE"], ANSWER_GAP)
    Button(L["SUPPORT_MORE_BUTTON"], function() O.CopyLink(L["SUPPORT_MORE_BUTTON"], EASYFIND_URL) end)
    Add("GameFontNormal", L["SUPPORT_DONATE_HEAD"], ITEM_GAP)
    Add("GameFontHighlight", L["SUPPORT_DONATE"]:format(TITLE), ANSWER_GAP)
    Button(L["SUPPORT_DONATE_BUTTON"], function() O.CopyLink(L["SUPPORT_DONATE_BUTTON"], DONATE_URL) end)
    function pane.Refresh()
        -- A label wider than its button (a longer translation, a large font) widens it.
        for _, piece in ipairs(pieces) do
            local label = piece.minW and piece.region:GetFontString()
            if label then piece.region:SetWidth(math.max(piece.minW, label:GetStringWidth() + 24)) end
        end
        Stack(child, pieces, setRange)
    end
    return pane
end
