-- Offline test under Lua 5.4 for where Who lives (Social/SocialWindow.lua S.WhoInFinder, S.WhoInSocialOnly,
-- S.WhoTabHidden; Social/FinderTabs.lua the game's finder Who tab; Options/OptionsWindow.lua parentOff). His ask
-- (2026-11-24): with our group finder off, the game's finder keeps its own Who tab (no jump to the social window) and the
-- social window shows none; "Who tab in the social window", usable only with Group finder unchecked, moves Who there and
-- takes the finder's Who tab away. With our finder on, both and the two Hide picks, as before.
-- Run from the addon root: lua tools/tests/who_home_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 122 212 431 432

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local failed = 0
local function Check(ok, what)
    print((ok and "PASS " or "FAIL ") .. what)
    if not ok then failed = failed + 1 end
end

local function Read(path)
    local handle = assert(io.open(ROOT .. path, "r"))
    local source = handle:read("a")
    handle:close()
    return source
end
local function Cut(path, from, to)
    local source = Read(path)
    local first = source:find(from, 1, true)
    local last = first and source:find(to, first, true)
    assert(first and last, path .. ": the code to test is in the file (" .. from .. ")")
    return source:sub(first, last + #to - 1)
end

-- The settings and what is in force.
local db, inForce, forever = {}, {}, true
local attached, hooks = nil, {}
local ns = {
    db = db,
    OnForever = function() return forever end,
    ModuleInForce = function(key) return inForce[key] == true end,
    AttachWhenLoaded = function(fn) attached = fn end,
    HookMethod = function(_, name, fn) hooks[name] = fn end,
}
local S = {}

-- The game's finder: its Who side tab, and its old style's top Who tab (hidden by the game in the modern style).
local function Tab(shown)
    local t = { shown = shown }
    function t:IsShown() return self.shown end
    function t:Show() self.shown = true end
    function t:Hide() self.shown = false end
    return t
end
local finder = { WhoListingTab = Tab(true), Tab3 = Tab(false), UpdateTabs = function() end }
function finder:HookScript(script, fn) hooks[script] = fn end

local env = setmetatable({ ns = ns, S = S, LFGParentFrame = finder }, { __index = _G })
rawset(env, "_G", env)
local function Run(chunk, name, ...)
    return assert(load(chunk, "@" .. name, "t", env))(...)
end
Run("local ns, S = ...\n" .. Cut("/Social/SocialWindow.lua", "local function OurFinderOff()",
    "    return ns.db.hideWhoTab == true\nend"), "Social/SocialWindow.lua", ns, S)
local finderChunk = Cut("/Social/FinderTabs.lua", "local function FinderWhoHidden()", "    return true\nend)")
local FinderWhoHidden = Run("local ns, S = ...\n" .. finderChunk .. "\nreturn FinderWhoHidden", "Social/FinderTabs.lua", ns, S)
if attached then attached() end

local function Setup(finderOn, whoList, inSocial, hideWhoTab, hideFinderWho)
    inForce.groupFinder, inForce.whoList = finderOn, whoList
    db.groupFinder, db.whoList, db.finderWhoInSocial = finderOn, whoList, inSocial
    db.hideWhoTab, db.hideFinderWho = hideWhoTab, hideFinderWho
    if S.KeepFinderWhoOff then S.KeepFinderWhoOff() end
end

-- Our finder on: as before.
Setup(true, true, false, false, true)
Check(not S.WhoInFinder() and not S.WhoInSocialOnly(), "our finder on: neither of the new homes")
Check(not S.WhoTabHidden() and FinderWhoHidden() == true, "our finder on: the two Hide picks rule (social tab up, finder's hidden)")
Setup(true, true, false, true, false)
Check(S.WhoTabHidden() and FinderWhoHidden() == false, "our finder on: Hide Who tab hides the social one, the finder keeps its own")

-- Our finder off, the box unchecked: Who in the game's finder.
Setup(false, true, false, false, true)
Check(S.WhoInFinder(), "our finder off: Who lives in the game's finder")
Check(S.WhoTabHidden(), "and the social window shows no Who tab")
Check(FinderWhoHidden() == false and S.FinderWhoOwn(), "the finder keeps its own Who tab and page, Hide Who side tab or not")
Check(finder.WhoListingTab:IsShown(), "its Who side tab stays up")

-- The box checked: Who in the social window, none in the finder.
Setup(false, true, true, true, false)
Check(S.WhoInSocialOnly() and not S.WhoInFinder(), "checked: Who lives in the social window")
Check(not S.WhoTabHidden(), "the social window shows its Who tab (Hide Who tab, hidden with our finder off, no longer counts)")
Check(FinderWhoHidden() == true and not S.FinderWhoOwn(), "the finder's Who tab is taken away, its page sent to ours")
Check(not finder.WhoListingTab:IsShown(), "its Who side tab is hidden")
finder.WhoListingTab:Show()
if hooks.UpdateTabs then hooks.UpdateTabs(finder) end
Check(not finder.WhoListingTab:IsShown(), "and held hidden through the game's own tab pass")

-- Unchecked again: only what we hid comes back.
Setup(false, true, false, false, true)
Check(finder.WhoListingTab:IsShown(), "unchecked again: its Who side tab is back")
Check(not finder.Tab3:IsShown(), "the top Who tab the game hid itself stays hidden")

-- Checked but our who list off: nothing to stand in the social window, Who stays in the finder.
Setup(false, false, true, false, true)
Check(S.WhoInFinder() and finder.WhoListingTab:IsShown(), "checked with our who list off: Who stays in the finder")

-- Retail: no such finder, Hide Who tab alone.
forever = false
Setup(false, true, true, true, true)
Check(not S.WhoInFinder() and not S.WhoInSocialOnly() and S.WhoTabHidden(), "retail: Hide Who tab alone")
forever = true

-- The game's Who page shown (its Who tab pressed, /who): sent to the social window only while Who lives there.
local sentAway, opened = nil, 0
local wns = { Sched = { AfterShow = function(_, _, fn) sentAway = fn return fn end },
    OpenWhoList = function() opened = opened + 1 return true end,
    AttachWhenLoaded = function(fn) fn() end }
local whoPage = {}
local wenv = setmetatable({ LFGWhoListFrame = whoPage }, { __index = env })
rawset(wenv, "_G", wenv)
assert(load("local ns, S = ...\nlocal active, clientWho, whoShown = true, nil, nil\nlocal function HideBlizzardPanels() end\n"
    .. Cut("/Social/WhoList.lua", "    ns.AttachWhenLoaded(function()\n        local who = _G[\"LFGWhoListFrame\"]",
        "        return true\n    end)"), "@Social/WhoList.lua", "t", wenv))(wns, S)
Check(type(sentAway) == "function", "the game's Who page is watched")
Setup(false, true, false, false, true)
opened = 0
if sentAway then sentAway() end
Check(opened == 0, "Who in the game's finder: its own page stays, the social window does not open")
Setup(false, true, true, false, true)
if sentAway then sentAway() end
Check(opened == 1, "Who in the social window: the game's page goes to ours")
Setup(true, true, false, false, true)
if sentAway then sentAway() end
Check(opened == 2, "our finder on: sent to ours, as before")

-- The options row: under Group finder, usable only while it is unchecked.
local O = { OffByOn = function() return false end }
local ons = { options = O, db = db, BarRowHeld = function() return false end }
Run("local ns, O = ...\n" .. Cut("/Options/OptionsWindow.lua", "function O.RefreshRows(built)", "\n    end\nend"),
    "Options/OptionsWindow.lua", ons, O)
local function Row(key, parent, extra)
    local row = { key = key, parent = parent, text = { SetFontObject = function() end } }
    for k, v in pairs(extra or {}) do row[k] = v end
    function row:SetChecked() end
    function row:SetEnabled(on) self.enabled = on end
    return row
end
local row = Row("finderWhoInSocial", "groupFinder", { parentOff = true, grayWhen = "groupFinder", needs = "whoList" })
local built = { rows = { row }, parentOf = { finderWhoInSocial = "groupFinder" } }
db.groupFinder, db.whoList = true, true
O.RefreshRows(built)
Check(row.enabled == false, "the row is grayed while Group finder is checked")
db.groupFinder = false
O.RefreshRows(built)
Check(row.enabled == true, "and usable once Group finder is unchecked")
db.whoList = false
O.RefreshRows(built)
Check(row.enabled == false, "grayed while our who list is off")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("who_home_test: ok")
