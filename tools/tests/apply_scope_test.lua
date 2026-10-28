-- Offline test under Lua 5.4 for the scoped pass (Core/Core.lua ns.ApplyChanged): a changed setting or game setting
-- runs only the modules that read it in their last run (toggles and parents too), later work counts, an error runs
-- every pass, writes reach the saved table, and a fight runs only inFight modules until it ends.
-- Run from the addon root: lua tools/tests/apply_scope_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 122

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local events = {}
function CreateFrame()
    local f = {}
    function f.RegisterEvent() end
    function f.SetScript(_, _, fn) events[#events + 1] = fn end
    return f
end
StaticPopupDialogs = {}
local fight = false
function InCombatLockdown() return fight end
function GetBuildInfo() return "", "", "", 120100 end
local errors = 0
function geterrorhandler() return function() errors = errors + 1 end end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
C_Timer = { After = function() end }

local ns = { L = setmetatable({}, { __index = function(_, k) return k end }) }
assert(loadfile(ROOT .. "/Core/Core.lua"))("ClassicUIForever", ns)
function ns.PackageRuns() return true end
function ns.WriteHeldCVars() end
local cvars = { rotate = "0" }
function ns.GetCVar(name) ns.NoteCVarRead(name) return cvars[name] end
ns.RELOAD_KEYS = {}
ns.TOGGLES = { { "parent" }, { "child", parent = "parent" }, { "plain" } }

local saved = { parent = true, child = true, plain = true, a = 1, b = 1, list = { 1 } }
ns.db, ns.ready = saved, true

local ran, later = {}, nil
local function Mod(key, apply, extra)
    local mod = { apply = function() ran[#ran + 1] = key apply() end, restore = function() ran[#ran + 1] = key .. "-off" end }
    for k, v in pairs(extra or {}) do mod[k] = v end
    ns.RegisterModule(extra and extra.key or key, mod)
end
local failing = false
Mod("plain", function() local _ = ns.db.a end)
Mod("child", function() local _ = ns.db.b end)
Mod("writer", function() ns.db.made = ns.db.a + 1 end, { key = "plain" })
Mod("reader", function() local _ = ns.db.made end, { key = "plain" })
Mod("unset", function() local _ = ns.db.notYet end, { key = "plain" })
Mod("listed", function() local _ = ns.db.list end, { key = "plain" })
Mod("broken", function() if failing then error("x") end end, { key = "plain" })
Mod("deferred", function() later = ns.PassReads(function() local _ = ns.db.late end) end, { key = "plain" })
Mod("fighter", function() local _ = ns.db.f end, { key = "plain", inFight = true })
Mod("game", function() local _ = ns.GetCVar("rotate") end, { key = "plain" })

local failed, passed = 0, 0
local function Check(name, got, want)
    if got == want then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("FAIL %s: got %s, want %s", name, tostring(got), tostring(want)))
    end
end
local function Ran() local s = table.concat(ran, ",") ran = {} return s end

ns.ApplyAll()
Check("full pass runs all", Ran(), "plain,child,writer,reader,unset,listed,broken,deferred,fighter,game")
Check("db is the saved table after", ns.db, saved)
Check("writes reach the saved table", rawget(saved, "made"), 2)
later()

ns.ApplyChanged({})
Check("nothing changed runs nothing", Ran(), "")

saved.b = 2
ns.ApplyChanged({ "b" })
Check("only the reader of b", Ran(), "child")

saved.parent = false
ns.ApplyChanged({ "parent" })
Check("a parent toggle runs its child's module", Ran(), "child-off")
saved.parent = true
ns.ApplyChanged({})
Check("values tell without names", Ran(), "child")

saved.a = 5
ns.ApplyChanged({ "a" })
Check("a write runs its reader in the same pass", Ran(), "plain,writer,reader")

saved.notYet = true
ns.ApplyChanged({ "notYet" })
Check("a key read unset, then set", Ran(), "unset")

saved.list[1] = 2
ns.ApplyChanged({})
Check("a table's entry changed", Ran(), "listed")
saved.list[2] = { 1 }
ns.ApplyChanged({})
Ran()
saved.list[2][1] = 2
ns.ApplyChanged({})
Check("a change further down, not named", Ran(), "")
ns.ApplyChanged({ "list" })
Check("a change further down, named", Ran(), "listed")

cvars.rotate = "1"
ns.ApplyChanged({})
Check("a game setting it read changed", Ran(), "game")
ns.ApplyChanged({})
Check("then quiet", Ran(), "")

saved.late = 1
ns.ApplyChanged({ "late" })
Check("deferred work's reads count", Ran(), "deferred")

failing = true
saved.c = 1
ns.ApplyAll()
Ran()
errors = 0
ns.ApplyChanged({})
Check("a module that failed runs every pass", Ran(), "broken")
Check("its error reported", errors, 1)
Check("db is the saved table after an error", ns.db, saved)
failing = false
ns.ApplyChanged({})
Ran()
ns.ApplyChanged({})
Check("fixed, it is skipped again", Ran(), "")

fight = true
saved.f, saved.b = 2, 3
ns.ApplyChanged({ "f", "b" })
Check("in a fight only inFight modules", Ran(), "fighter")
fight = false
for _, fn in ipairs(events) do fn(nil, "PLAYER_REGEN_ENABLED") end
Check("the fight's end runs the full pass", Ran(), "plain,child,writer,reader,unset,listed,broken,deferred,fighter,game")

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
