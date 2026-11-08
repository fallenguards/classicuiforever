-- Offline test under Lua 5.4: ns.IsForbidden (Core/Util.lua) answers true for a frame that refuses addon code though
-- its IsForbidden says no (the target's aura buttons, 12.x: a theme walk's GetName on one errored, seen on CurseForge).
-- Run from the addon root: lua tools/tests/forbidden_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local failed = 0
local function Check(ok, what)
    if not ok then
        failed = failed + 1
        print("FAIL " .. what)
    end
end

local function Read(path)
    local handle = assert(io.open(ROOT .. "/" .. path, "rb"))
    local text = handle:read("a"):gsub("\r\n", "\n")
    handle:close()
    return text
end

-- ns.IsForbidden from Core/Util.lua itself, on stub frames.
local util = Read("Core/Util.lua")
local body = util:match("\nfunction ns%.IsForbidden%(object%)\n.-\nend\n")
Check(body ~= nil, "ns.IsForbidden is found in Core/Util.lua")
if body then
    local ns = {}
    assert(load(body, "IsForbidden", "t", setmetatable({ ns = ns }, { __index = _G })))()
    local function Frame(forbidden, name, refuses)
        return {
            IsForbidden = function() return forbidden end,
            GetName = function()
                if refuses then error("Attempt to access forbidden object from code tainted by an AddOn") end
                return name
            end,
        }
    end
    Check(ns.IsForbidden(nil) == true, "nothing is forbidden")
    Check(ns.IsForbidden(Frame(true, "Secret", false)) == true, "a frame saying forbidden is forbidden")
    Check(ns.IsForbidden(Frame(false, "TargetFrameAura1", true)) == true,
        "a frame refusing its name is forbidden, whatever it says")
    Check(ns.IsForbidden(Frame(false, "PlayerFrame", false)) == false, "a plain named frame is not forbidden")
    Check(ns.IsForbidden({}) == false, "a bare table (no name to ask) is not forbidden")
end

-- The art walk's other name read asks under pcall too.
local bronze = Read("Art/Bronze.lua")
Check(bronze:find("local answered, name = pcall(frame.GetName, frame)\n    return answered and AddonName(name)", 1, true),
    "B.AddonFrame asks the name under pcall")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("forbidden_test: ok")
