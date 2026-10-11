-- Offline test under Lua 5.4 for Communities as a button (SyncCommunities in Social/GuildOpeners.lua): off, both tabs
-- stand as before; on, the guild page carries the button and the row is 1.x's four; with no guild the Communities tab
-- stands in the Guild tab's place, unless that is turned off too; the row is laid again only when something changed.
-- Run from the addon root: lua tools/tests/communities_button_test.lua (CI runs every tools/tests/*_test.lua).
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

local handle = assert(io.open(ROOT .. "/Social/GuildOpeners.lua", "r"))
local source = handle:read("a")
handle:close()
local from = source:find("local function SyncCommunities()", 1, true)
local to = from and source:find("\nend\n", from, true)
Check(from and to, "SyncCommunities is in the file")
local body = from and to and source:sub(from, to + 4) or ""

local function Frame(shown)
    local f = { shown = shown }
    function f:IsShown() return self.shown end
    return f
end

local placed, inGuild = 0, true
local env = setmetatable({
    G = { active = true, panel = { communities = Frame(false) } },
    S = { PlaceTabs = function() placed = placed + 1 end },
    ns = {
        db = {},
        SetShownIf = function(f, on)
            on = on and true or false
            if f.shown == on then return false end
            f.shown = on
            return true
        end,
    },
    InGuild = function() return inGuild end,
    BuildCommunitiesButton = function() end,
    communitiesTab = Frame(true),
    tab = Frame(true),
}, { __index = _G })
local Sync = assert(load(body .. "\nreturn SyncCommunities", "sync", "t", env))()

local function Case(button, noGuildTab, guild)
    env.ns.db.communitiesButton, env.ns.db.communitiesNoGuildTab, inGuild = button, noGuildTab, guild
    Sync()
    return env.tab.shown, env.communitiesTab.shown, env.G.panel.communities.shown, env.S.fourTabs
end

local guildTab, commTab, button, four = Case(false, true, true)
Check(guildTab and commTab and not button and not four, "off: both tabs, no button, five-tab padding")
guildTab, commTab, button = Case(false, true, false)
Check(guildTab and commTab and not button, "off with no guild: both tabs as before")
guildTab, commTab, button, four = Case(true, true, true)
Check(guildTab and not commTab and button and four, "on: Guild tab, the button, 1.x's four")
guildTab, commTab, button = Case(true, true, false)
Check(not guildTab and commTab and button, "on with no guild: Communities in the Guild tab's place")
guildTab, commTab = Case(true, false, false)
Check(guildTab and not commTab, "on, no guild, swap off: the grayed Guild tab and no Communities tab")

local before = placed
Case(true, false, false)
Case(true, false, false)
Check(placed == before, "the row is not laid again when nothing changed")
Case(false, true, true)
Check(placed == before + 1, "a change lays the row once")

env.G.active = false
before = placed
Case(true, true, false)
Check(placed == before, "nothing while the guild roster is off")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("communities_button_test: ok")
