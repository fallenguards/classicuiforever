-- Offline test under Lua 5.4 for the public API (Core/API.lua, global ClassicUIForeverAPI), which other addons build
-- on: each window's Open and GetFrame route to the right call, parts by name and pattern, nothing for unknown names,
-- and Open refused while a replacement is not in force.
-- Run from the addon root: lua tools/tests/api_test.lua (CI runs every tools/tests/*_test.lua).
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

local calls = {}
local function Log(name, ...) calls[#calls + 1] = table.concat({ name, ... }, " ") end
local function Called(text)
    for _, line in ipairs(calls) do if line == text then return true end end
    return false
end

local function Frame(fields)
    local f = fields or {}
    f.shown = f.shown ~= false
    function f:IsShown() return self.shown end
    return f
end

local inForce = { spellBook = true, talents = true, legacyWindow = true, tradeSkill = true, trainer = true,
    professionsBook = true, questLog = true }
local book = Frame({ Search = "search", SkillTabs = { "skill1" }, BookTabs = { "foot1" } })
local talents = Frame({ learn = "learnBtn", reset = "resetBtn", tabs = { "tree1", "tree2", "tree3" } })
local legacy = Frame({ learn = "legacyLearn" })
local trade = Frame({ create = "createBtn", createAll = "allBtn", count = "countBox", searchBox = "searchBox" })
local trainer = Frame({ train = "trainBtn" })
local bookPage = Frame()
local fight = false

local ns = {
    ModuleInForce = function(name) return inForce[name] == true end,
    SpellBookShowSpell = function(id) Log("showSpell", id) return id == 133 end,
    ShowSpellBookBank = function(pet) Log("bank", tostring(pet)) end,
    SpellBookButtonFor = function(id) return "spellButton" .. id end,
    SpellBookButtonSpell = function() return nil end,
    ShowTalentSpell = function(id) Log("talentSpell", id) return true end,
    ShowTalents = function(tab) Log("talents", tostring(tab)) return true end,
    TalentWindowButtonFor = function(frame, id) return (frame == talents and "talent" or "legacyTalent") .. id end,
    ShowLegacy = function(page) Log("legacy", tostring(page)) return true end,
    LegacyPageTab = function(n) return "page" .. n end,
    TradeSkillWant = function(id) Log("want", id) end,
    TradeSkillPanel = function() return trade end,
    TradeSkillRowFor = function(id) return "recipeRow" .. id end,
    TrainerPanel = function() return trainer end,
    TrainerRowFor = function(n) return "serviceRow" .. n end,
    OpenProfessionsBook = function() Log("profBook") return true end,
    prof = { Page = function() return bookPage end, BookCard = function(kind, n) return kind .. n end },
    MicroButtonNow = function(name) return name == "CharacterMicroButton" and "ringPortrait" or nil end,
}

local env = setmetatable({
    ForeverClassicUISpellBook = book, ClassicUIForeverTalents = talents, ClassicUIForeverLegacy = legacy,
    MicroMenu = Frame(), UIParent = Frame(),
    InCombatLockdown = function() return fight end,
    C_TradeSkillUI = { OpenRecipe = function(id) Log("openRecipe", id) end },
}, { __index = _G })
env._G = env
assert(loadfile(ROOT .. "/Core/API.lua", "t", env))("ClassicUIForever", ns)
local API = env.ClassicUIForeverAPI
Check(API and API.version == 1, "the API is out at version 1")

-- Open
Check(API.Open("spellBook", "spell:133") and Called("showSpell 133") and not Called("bank false"),
    "spellbook on a spell's page")
calls = {}
API.Open("spellBook", "spell:999")
Check(Called("showSpell 999") and Called("bank false"), "a spell no tab lists: the book opens all the same")
calls = {}
API.Open("spellBook", "pet")
Check(Called("bank true"), "the pet's book")
Check(API.Open("talents", "talent:5") and Called("talentSpell 5"), "talents on a talent's tab")
Check(API.Open("talents", 2) and Called("talents 2"), "talents on a tree tab")
Check(API.Open("legacyWindow", "tree") and Called("legacy tree"), "legacy on a page")
Check(API.Open("tradeSkill", "recipe:42") and Called("want 42") and not Called("openRecipe 42"),
    "a recipe picked in the open window; the game's protected opener never called")
trade.shown = false
Check(API.Open("tradeSkill", "recipe:43") == false and not Called("want 43"), "no window open: nothing asked")
trade.shown = true
Check(API.Open("tradeSkill") == false, "no trade skill without a recipe")
Check(API.Open("trainer") == false, "no trainer opening")
Check(API.Open("professionsBook") and Called("profBook"), "the professions book")
Check(API.Open("microMenu") == false, "the micro menu opens nothing")
inForce.talents = false
Check(API.Open("talents", 1) == false, "a replacement not in force: nothing opens")
inForce.talents = true
Check(API.Open("nope") == false, "an unknown window opens nothing")

-- GetFrame
Check(API.GetFrame("spellBook", "spell:7") == "spellButton7", "spellbook spell button")
Check(API.GetFrame("talents") == talents and API.GetFrame("talents", "learn") == "learnBtn", "talents and a named part")
Check(API.GetFrame("talents", "tab:3") == "tree3" and API.GetFrame("talents", "talent:9") == "talent9", "talent tab and button")
Check(API.GetFrame("legacyWindow", "tab:2") == "page2" and API.GetFrame("legacyWindow", "talent:4") == "legacyTalent4",
    "legacy page tab and tree button")
Check(API.GetFrame("tradeSkill", "recipe:42") == "recipeRow42" and API.GetFrame("tradeSkill", "create") == "createBtn",
    "trade skill recipe row and Create")
Check(API.GetFrame("trainer", "service:3") == "serviceRow3" and API.GetFrame("trainer", "train") == "trainBtn",
    "trainer row and Train")
Check(API.GetFrame("professionsBook") == bookPage and API.GetFrame("professionsBook", "secondary:2") == "secondary2",
    "professions book page and card")
Check(API.GetFrame("microMenu", "CharacterMicroButton") == "ringPortrait", "a micro button where it stands now")
Check(API.GetFrame("microMenu", "HelpMicroButton") == nil, "a micro button shown nowhere: nil")
Check(API.GetFrame("talents", "talent:nope") == nil and API.GetFrame("talents", "bogus") == nil, "unknown parts: nil")
Check(API.GetFrame("nope") == nil and API.GetFrame("nope", "part") == nil, "unknown windows: nil")

-- SecureOpener: the key's secure button for a window in force, nothing otherwise.
env.ClassicUIForeverTalentsBind = Frame()
Check(API.SecureOpener("talents") == "ClassicUIForeverTalentsBind", "talents' secure opener by name")
Check(API.SecureOpener("spellBook") == nil, "no opener before its button exists")
inForce.talents = false
Check(API.SecureOpener("talents") == nil, "no opener while not in force")
inForce.talents = true
Check(API.SecureOpener("trainer") == nil and API.SecureOpener("nope") == nil, "no opener for windows without one")

-- Windows lists every window with its parts and patterns.
local list = API.Windows()
local function Has(name, part)
    for _, p in ipairs(list[name] or {}) do if p == part then return true end end
    return false
end
Check(Has("talents", "talent:<spellID>") and Has("tradeSkill", "recipe:<recipeID>") and Has("trainer", "service:<index>")
    and Has("legacyWindow", "tab:<n>") and Has("professionsBook", "primary:<n>") and Has("microMenu", "<micro button name>"),
    "Windows lists the new patterns")

if failed > 0 then
    print(failed .. " failed")
    os.exit(1)
end
print("api_test: all passed")
