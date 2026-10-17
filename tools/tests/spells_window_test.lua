-- Offline test under Lua 5.4 for retail's talents: the game's spells window takes the classic dress under the Talent
-- window row (Windows/Panels.lua, Windows/PanelAfters.lua), and our own window stands down off Forever
-- (Skills/Talents.lua). On Forever nothing of this applies.
-- Run from the addon root: lua tools/tests/spells_window_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 212

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local failed = 0
local function Check(ok, what)
    if not ok then
        failed = failed + 1
        print("FAIL: " .. what)
    end
end

------------------------------------------------------------------ the stub client and addon

local Region = {}
Region.__index = function(_, key) return Region[key] or function() end end
local function New(name) return setmetatable({ name = name }, Region) end
function Region:SetAlpha(alpha) self.alpha = alpha end
function Region:SetAllPoints(other) self.over = other end
function Region:IsObjectType(kind) return kind == "Frame" end

local quiet = { __index = function() return function() end end }

-- The addon as one client sees it; modules lists what each file registered.
local function Addon(onForever)
    local modules, red, drops, drained, visible = {}, {}, {}, {}, {}
    local ns = setmetatable({ EMPTY = {} }, quiet)
    ns.L = setmetatable({}, { __index = function(_, key) return key end })
    ns.RELOAD_KEYS = {}
    ns.panels = setmetatable({ after = {}, active = true, skinned = {} }, quiet)
    ns.OnForever = function() return onForever end
    ns.RegisterModule = function(key, module) modules[key] = module end
    ns.SkinRedButton = function(button) red[button] = true end
    ns.SkinDropdown = function(dropdown) drops[dropdown or false] = true end
    ns.DrainInput = function(box) drained[box] = true end
    ns.EachKey = function(owner, keys, fn)
        for _, key in ipairs(keys) do
            if owner[key] then fn(owner[key]) end
        end
    end
    ns.OwnTexture = function(frame, key)
        local own = rawget(frame, "own") or {}
        frame.own = own
        own[key] = own[key] or New(key)
        return own[key]
    end
    ns.TileTex = function(tex, key)
        tex.tile = key
        return tex
    end
    local later = {}
    ns.Sched = setmetatable({
        OnVisible = function(host, name, fn) visible[host] = fn end,
        NextFrame = function(_, fn) later[#later + 1] = fn end,
    }, quiet)
    ns.SetAlphaIf = function(region, alpha) region.alpha = alpha end
    ns.RunLater = function()
        local run = later
        later = {}
        for _, fn in ipairs(run) do fn() end
    end
    return ns, { modules = modules, red = red, drops = drops, drained = drained, visible = visible }
end

local function Load(file, ns)
    assert(loadfile(ROOT .. "/" .. file))("ClassicUIForever", ns)
end

local function SpellsWindow()
    local frame = New("PlayerSpellsFrame")
    local talents = New("TalentsFrame")
    for _, key in ipairs({ "ApplyButton", "InspectCopyButton", "SearchBox", "BottomBar" }) do talents[key] = New(key) end
    talents.LoadSystem = New("LoadSystem")
    talents.LoadSystem.Dropdown = New("Dropdown")
    frame.TalentsFrame = talents
    frame.SpecFrame = New("SpecFrame")
    frame.spellBookTabID = 3
    frame.bookTab = New("SpellbookTab")
    frame.bookTab.mouse = true
    function frame.bookTab:EnableMouse(on) self.mouse = on end
    function frame:GetTabButton(id) return id == 3 and self.bookTab or nil end
    local specs = { { ActivateButton = New("Activate1") }, { ActivateButton = New("Activate2") } }
    frame.SpecFrame.SpecContentFramePool = { EnumerateActive = function()
        local i = 0
        return function()
            i = i + 1
            return specs[i]
        end
    end }
    return frame, specs
end

local function Entry(ns)
    for _, entry in ipairs(ns.panels.WINDOWS) do
        if entry[1] == "PlayerSpellsFrame" then return entry end
    end
end

------------------------------------------------------------------ retail

do
    local ns, seen = Addon(false)
    Load("Windows/PanelAfters.lua", ns)
    Load("Windows/Panels.lua", ns)
    local entry = Entry(ns)
    Check(entry ~= nil, "retail: the spells window is in the panels' list")
    Check(entry and entry.toggle == "talents", "retail: it follows the Talent window row")
    Check(entry and entry.addon == "Blizzard_PlayerSpells", "retail: it is dressed as its addon loads")
    Check(entry and entry.after == ns.panels.after.PlayerSpellsFrame, "retail: its after is the spells window's")
    -- Its pages end 4 above the frame's foot, where the client's border line stands; a lifted line bared them.
    Check(entry and entry.lift == 5 and entry.tabLift == 0, "retail: border and tabs stay on the client's foot line")

    local frame, specs = SpellsWindow()
    PlayerSpellsFrame = frame
    local talents = frame.TalentsFrame
    ns.panels.after.PlayerSpellsFrame(frame)
    Check(seen.red[talents.ApplyButton], "Apply Changes takes the old red button")
    Check(seen.red[talents.InspectCopyButton], "the inspect copy button takes the old red button")
    Check(seen.drops[talents.LoadSystem.Dropdown], "the loadout drop down is dressed")
    Check(seen.drained[talents.SearchBox], "the search box is drained")
    local stone = talents.own and talents.own.footStone
    Check(stone and stone.tile == "rockBg" and stone.over == talents.BottomBar, "stone lies under the foot row")
    Check(talents.BottomBar.alpha == 0, "the game's foot bar is faded under it")
    Check(not seen.red[specs[1].ActivateButton], "an Activate button waits for its tab to show")
    seen.visible[frame.SpecFrame](true)
    ns.RunLater()
    Check(seen.red[specs[1].ActivateButton] and seen.red[specs[2].ActivateButton], "every Activate button is red once the tab shows")

    -- With our spellbook on, the game's Spellbook tab goes unseen, and comes back with it off; never before the dress.
    local tab = frame.bookTab
    local bookOn = true
    ns.SpellBookActive = function() return bookOn end
    ns.GameBookTab()
    Check(rawget(tab, "alpha") == nil and tab.mouse == true, "an undressed window's Spellbook tab is left alone")
    ns.panels.skinned[frame] = true
    ns.GameBookTab()
    Check(tab.alpha == 0 and tab.mouse == false, "our spellbook on: the game's Spellbook tab is unseen and takes no mouse")
    bookOn = false
    ns.GameBookTab()
    Check(tab.alpha == 1 and tab.mouse == true, "our spellbook off: the game's Spellbook tab is back")

    -- Our own window never takes the game's buttons there.
    local rowApply, rowRestore = function() end, function() end
    ns.panels.RowPass = function() return rowApply, rowRestore end
    Load("Skills/Talents.lua", ns)
    local module = seen.modules.talents
    Check(module and module.apply == rowApply and module.restore == rowRestore, "retail: the Talent window row runs the panels' pass")
    Check(module and not module.padHost, "retail: no gamepad hosting of our window")
    PlayerSpellsFrame = nil
end

------------------------------------------------------------------ Forever

do
    local ns, seen = Addon(true)
    Load("Windows/PanelAfters.lua", ns)
    Load("Windows/Panels.lua", ns)
    Check(Entry(ns) == nil, "Forever: the spells window is left out of the panels' list")
    local asked = false
    ns.panels.RowPass = function() asked = true end
    Load("Skills/Talents.lua", ns)
    local module = seen.modules.talents
    Check(module and module.padHost == true and not asked, "Forever: the Talent window row is our own window")
end

------------------------------------------------------------------ the spellbook's macro for a pad

-- The bind button's work is a macro of its own; pressed from a pad's macro its click fired and the layer's never did
-- (retail, read live 2026-10-03). The pad's macro presses the layer itself, then a sized button whose PostClick lets
-- the book follow.
do
    local file = assert(io.open(ROOT .. "/Spells/SpellBook.lua", "r"))
    local text = file:read("a")
    file:close()
    local body = text:match("function ns%.BookPadMacro%(%)(.-)\nend")
    Check(body ~= nil, "ns.BookPadMacro is found")
    Check(body and body:find("ns.ClickProxy(CLICK_NAME)", 1, true) ~= nil, "the follow button is a sized click proxy")
    Check(body and body:find('SetScript("PostClick", FollowLayer)', 1, true) ~= nil, "the book follows the layer from its PostClick")
    Check(body and body:find("/click ForeverClassicUISpellBookClicks", 1, true) ~= nil, "the macro presses the layer itself")
    Check(body and not body:find("BIND_NAME", 1, true) and not body:find("clickbutton", 1, true),
        "the macro never reaches the bind button")
    Check(text:find('bindButton:SetScript("PostClick", FollowLayer)', 1, true) ~= nil, "the key's path follows the layer the same way")
end

------------------------------------------------------------------ a spell shift-clicked into a macro

-- With the macro box focused the book hands it the spell's name and rank as text, as the client's own book does
-- ("Serpent Sting(Rank 2)"); it handed a chat link, which is no spell to /cast (#124).
do
    local file = assert(io.open(ROOT .. "/Spells/SpellBook.lua", "r"))
    local text = file:read("a")
    file:close()
    local source = text:match("(local function MacroText%(.-\nend)\n")
    Check(source ~= nil, "MacroText is found")
    if source then
        local secret = {}
        local MacroText = assert(load("local IsSecret = ...\n" .. source .. "\nreturn MacroText"))(function(v) return v == secret end)
        Check(MacroText("Serpent Sting", "Rank 2", false) == "Serpent Sting(Rank 2)", "a ranked spell goes in as Name(Rank)")
        Check(MacroText("Auto Shot", "", false) == "Auto Shot", "a spell with no rank goes in by its name")
        Check(MacroText("Auto Shot", nil, false) == "Auto Shot", "a missing rank is no rank")
        Check(MacroText("Dodge", "", true) == nil, "a passive is not put into a macro")
        Check(MacroText(secret, "Rank 1", false) == nil, "a secret name is never written")
        Check(MacroText("Raptor Strike", secret, false) == "Raptor Strike", "a secret rank is left off")
    end
    -- The click lands on the casting button, which ArmSpell fills: the name and rank must be put there (set on the
    -- slot under it, the click found none and wrote nothing at all).
    local arm = text:match("local function ArmSpell%(.-\nend\n")
    Check(arm ~= nil and arm:find("btn.macroName, btn.macroRank =", 1, true) ~= nil, "the casting button keeps the name and rank")
    local _, sets = text:gsub("%.macroName, [%w_]+%.macroRank =", "")
    Check(sets == 1, "the name and rank are set in one place only (" .. sets .. ")")
    local click = text:match("local function Button_PostClick%(.-\nend\n")
    Check(click ~= nil and click:find("MacroFrameText", 1, true) ~= nil and click:find("HasFocus", 1, true) ~= nil,
        "the click asks whether the macro box has the focus")
    local focus, link = click and click:find("HasFocus", 1, true), click and click:find("GetSpellBookItemLink", 1, true)
    Check(focus ~= nil and link ~= nil and focus < link, "the macro text is tried before the chat link")
end

-- A link click on a profession's button casts nothing, so neither the secure wrap nor the click shuts the book (a
-- shift-click into a macro closed it; an ability's did not).
do
    local file = assert(io.open(ROOT .. "/Spells/SpellBook.lua", "r"))
    local text = file:read("a")
    file:close()
    local pre = text:match("local TRADE_PRE = %[%[(.-)%]%]")
    Check(pre ~= nil and pre:find('not IsModifiedClick("CHATLINK")', 1, true) ~= nil, "the profession wrap leaves a link click alone")
    local click = text:match("local function Button_PostClick%(.-\nend\n")
    Check(click ~= nil and click:find("if not linking and self:GetAttribute(\"trade\")", 1, true) ~= nil,
        "the click does not shut the book on a link click")
end

-- The classic talents window the same way: the talent's spell by name, tried before the link, never a passive. Its
-- talent buttons are the old talent window's, shared with the Legacy window (UI/TalentWindow.lua).
do
    local file = assert(io.open(ROOT .. "/UI/TalentWindow.lua", "r"))
    local text = file:read("a")
    file:close()
    local click = text:match("local function Button_OnClick%(.-\nend\n")
    Check(click ~= nil, "the talent button's click is found")
    local focus, link = click and click:find("HasFocus", 1, true), click and click:find("GetSpellLink", 1, true)
    Check(focus ~= nil and link ~= nil and focus < link, "a talent's macro text is tried before its chat link")
    Check(click ~= nil and click:find("GetSpellName", 1, true) ~= nil and click:find("IsSpellPassive", 1, true) ~= nil,
        "a talent goes into a macro by its spell's name, a passive not at all")
end

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("spells_window_test: ok")
