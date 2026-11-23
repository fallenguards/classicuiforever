-- Offline test under Lua 5.4 for the Legacy window's challenges list (Legacy/LegacyChallenges.lua over
-- Legacy/LegacyWindow.lua): sections nest under their parents as the game's own window nests them (the classes under
-- Classes), and the search keeps a whole section when its name, or a section's over it, holds the words.
-- Run from the addon root: lua tools/tests/legacy_challenges_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 122 212

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local failed = 0
local function Check(ok, what)
    if not ok then
        failed = failed + 1
        print("FAIL " .. what)
    end
end

local NOOP = function() end
local function Stub(fields)
    return setmetatable(fields or {}, { __index = function() return NOOP end })
end

-- The client's categories (Achievement_Category: name, parent) and challenges (name, completed, words, steps).
-- GetCategoryList names the sections holding challenges, a child before its parent; Classes and Tradeskills hold none.
local CATS = {
    [15568] = { "Classes", -1 }, [15577] = { "Druid", 15568 }, [15579] = { "Mage", 15568 },
    [15593] = { "Dungeons", -1 }, [15586] = { "Tradeskills", -1 }, [15587] = { "Alchemy", 15586 },
}
local LIST = { 15577, 15579, 15593, 15587 }
local CHALLENGES = {
    [15577] = { { 1, "Shapeshifter", false, "Shift forms.", {} } },
    [15579] = { { 2, "Polymorph Master", true, "Turn foes into sheep.", { "Polymorph a beast" } },
        { 3, "Dungeon Delver", false, "Enter a dungeon.", {} } },
    [15593] = { { 4, "Ragefire Chasm", false, "Clear the caves under Orgrimmar.", { "Taragaman", "Bazzalan" } },
        { 5, "The Deadmines", true, "Defeat Van Cleef.", {} } },
    [15587] = { { 6, "Potion Brewer", false, "Brew potions.", {} } },
}
local BY_ID = {}
for _, list in pairs(CHALLENGES) do for _, c in ipairs(list) do BY_ID[c[1]] = c end end
function GetCategoryList() return LIST end
function GetCategoryInfo(id) local c = CATS[id] if c then return c[1], c[2] end end
function GetCategoryNumAchievements(id) return #(CHALLENGES[id] or {}) end
function GetAchievementInfo(id, index)
    local c = CHALLENGES[id][index]
    return c[1], c[2], 10, c[3], 11, 22, 26, c[4], 0, 0
end
function GetAchievementNumCriteria(id) return #BY_ID[id][5] end
function GetAchievementCriteriaInfo(id, index) return BY_ID[id][5][index], 0, false, 0, 1 end
wipe = function(t) for k in pairs(t) do t[k] = nil end end
PlaySound, SOUNDKIT = NOOP, {}
InCombatLockdown = function() return false end
C_Traits = { GetConfigIDByTreeID = NOOP, GetTreeNodes = NOOP }

local function Window()
    local w = Stub({ scripts = {}, shown = false })
    w.title, w.portrait, w.scroll = Stub(), Stub(), Stub()
    function w:SetScript(name, fn) self.scripts[name] = fn end
    function w:IsShown() return self.shown end
    function w:SetShown(on) self.shown = on end
    function w:Hide() self.shown = false end
    return w
end

local tabs, page, owner, box, apply = {}, nil, nil, nil, nil
local ns
ns = {
    L = setmetatable({ LEGACY_COMPLETED_ON = "Completed %s" }, { __index = function(_, key) return key end }),
    EMPTY = {}, SIDE_TAB_SLOT = 0,
    db = {},
    OnForever = function() return true end,
    IsSecret = function() return false end,
    PadNav = NOOP,
    WindowOpeners = function() return NOOP end,
    GameText = function(_, key) return key end,
    SideTabsFor = function(_, pages, onClick)
        for i in ipairs(pages) do
            local t = Stub({ id = i })
            function t:GetID() return self.id end
            t.click = function() onClick(t) end
            tabs[i] = t
        end
        return tabs
    end,
    RegisterModule = function(_, spec) apply = spec.apply end,
    TalentWindow = function() return Window() end,
    TalentTrees = NOOP, SetPointOnce = NOOP, TalentTreeShown = NOOP,
    EventFrame = function() return Stub() end,
    Sched = { NextFrame = NOOP },
    SetSlotWidth = NOOP, RegisterClassicWindow = NOOP, CloseOnEscape = NOOP, TalentWindowShown = NOOP,
    MicroButtonFollows = NOOP, RegisterEvents = NOOP, DrawTalentTab = NOOP, Print = NOOP,
    -- UI/EraSkills.lua's page: what it is asked to draw.
    eraSkills = { Build = function(_, o)
        owner = o
        page = Stub({ lines = {}, scroll = Stub(), empty = Stub() })
        function page:CreateFontString() return Stub() end
        return page
    end },
    SearchBox = function()
        box = Stub({ text = "", hint = Stub(), clear = Stub() })
        function box:SetScript(_, fn) self.onText = fn end
        function box:GetText() return self.text end
        return box
    end,
    ShellFilterButton = function() return Stub() end,
}
assert(loadfile(ROOT .. "/Legacy/LegacyWindow.lua"))("ClassicUIForever", ns)
local LG = ns.legacy
LG.Earned = NOOP
for _, tab in ipairs({ 1, 3 }) do
    LG.AddPage({ key = "other" .. tab, tab = tab, tip = {}, title = {}, build = NOOP, shown = NOOP, refresh = NOOP })
end
assert(loadfile(ROOT .. "/Legacy/LegacyChallenges.lua"))("ClassicUIForever", ns)
apply()
Check(ns.ToggleLegacy(), "the window opens")
tabs[2].click()
LG.Refresh()
Check(page ~= nil and box ~= nil, "the challenges page is built")

-- The list as text: a section "#name/depth", a challenge its name.
local function Shown()
    local out = {}
    for _, line in ipairs(page.lines) do
        out[#out + 1] = line.header and ("#" .. line.name .. "/" .. (line.depth or 0)) or line.name
    end
    return table.concat(out, ", ")
end
local function Search(text)
    box.text = text
    box.onText(box)
end
local function Expect(want, what)
    local got = Shown()
    Check(got == want, what .. "\n  want: " .. want .. "\n  got:  " .. got)
end

Expect("#Classes/0, #Druid/1, Shapeshifter, #Mage/1, Polymorph Master, Dungeon Delver, #Dungeons/0, Ragefire Chasm, "
    .. "The Deadmines, #Tradeskills/0, #Alchemy/1, Potion Brewer", "the classes nest under Classes, Alchemy under Tradeskills")

Search("dungeons")
Expect("#Dungeons/0, Ragefire Chasm, The Deadmines", "dungeons: the whole Dungeons section")
Search("Dungeon")
Expect("#Classes/0, #Mage/1, Dungeon Delver, #Dungeons/0, Ragefire Chasm, The Deadmines",
    "dungeon: the Dungeons section and a challenge named for one, under its sections")
Search("classes")
Expect("#Classes/0, #Druid/1, Shapeshifter, #Mage/1, Polymorph Master, Dungeon Delver", "classes: every class section")
Search("mage poly")
Expect("#Classes/0, #Mage/1, Polymorph Master", "two words: the section's name and the challenge's")
Search("rage")
Expect("#Dungeons/0, Ragefire Chasm", "a challenge's name alone")
Search("orgrimmar")
Expect("#Dungeons/0, Ragefire Chasm", "a word of its description")
Search("bazzalan")
Expect("#Dungeons/0, Ragefire Chasm", "a step of several")
Search("beast")
Expect("#Classes/0, #Mage/1, Polymorph Master", "its one step")
Search("sheep mage")
Expect("#Classes/0, #Mage/1, Polymorph Master", "words from its description and its section")
Search("11/22/26")
Expect("#Classes/0, #Mage/1, Polymorph Master, #Dungeons/0, The Deadmines", "the date it was completed")
Search("nothing here")
Expect("", "no match: an empty list")
Search("")

-- Folding: Classes folded hides the classes; the All tab opens every section, those folded under another too.
owner.onLabel({ header = true, id = 15579 })
owner.onLabel({ header = true, id = 15568 })
Expect("#Classes/0, #Dungeons/0, Ragefire Chasm, The Deadmines, #Tradeskills/0, #Alchemy/1, Potion Brewer",
    "Classes folded: its classes hidden")
owner.onAll()
Expect("#Classes/0, #Dungeons/0, #Tradeskills/0", "All: every section folded")
owner.onAll()
Expect("#Classes/0, #Druid/1, Shapeshifter, #Mage/1, Polymorph Master, Dungeon Delver, #Dungeons/0, Ragefire Chasm, "
    .. "The Deadmines, #Tradeskills/0, #Alchemy/1, Potion Brewer", "All again: every section open, Mage too")

local selected
for _, line in ipairs(page.lines) do if line.selected then selected = line.name end end
Check(selected == "Shapeshifter", "the first challenge shown is picked")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("legacy_challenges_test: ok")
