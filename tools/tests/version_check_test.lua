-- Offline test under Lua 5.4 for the update notice (Options/VersionCheck.lua): a newer version heard on a roster channel
-- gives one chat line a session with the CurseForge link; older, equal, malformed or whispered versions give none; the
-- addon messages option off keeps chat quiet; a hello is answered once per channel.
-- Run from the addon root: lua tools/tests/version_check_test.lua (CI runs every tools/tests/*_test.lua).
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

local printed, sent, timers, onEvent = {}, {}, {}, nil
local function Load(messages)
    printed, sent, timers = {}, {}, {}
    local ns = {
        L = { UPDATE_AVAILABLE = "version %s is out (you have %s). Get it on %s." },
        db = { addonMessages = messages },
        IsSecret = function() return false end,
        AddonVersion = function() return "0.24.0" end,
        Print = function(line) printed[#printed + 1] = line end,
        ChatLink = function(target, label) return "[" .. target .. ":" .. label .. "]" end,
        EventFrame = function(_, fn) onEvent = fn end,
    }
    C_ChatInfo = {
        SendAddonMessage = function(prefix, payload, channel) sent[#sent + 1] = { prefix, payload, channel } end,
        RegisterAddonMessagePrefix = function() end,
    }
    C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
    IsInInstance = function() return false, "none" end
    IsInRaid, IsInGroup, IsInGuild = function() return false end, function() return false end, function() return true end
    strsplit = function(sep, text)
        local out = {}
        for piece in (text .. sep):gmatch("(.-)" .. sep) do out[#out + 1] = piece end
        return table.unpack(out)
    end
    assert(loadfile(ROOT .. "/Options/VersionCheck.lua"))("ClassicUIForever", ns)
    return ns
end

local ns = Load(true)
Check(ns.VersionHeard("0.25.0", "WHISPER") == false, "a whispered version is dropped")
Check(ns.VersionHeard("0.24.0", "GUILD") == false, "the same version is no news")
Check(ns.VersionHeard("0.23.9", "GUILD") == false, "an older version is no news")
Check(ns.VersionHeard("0.25", "GUILD") == false and ns.VersionHeard("v0.25.0", "GUILD") == false, "malformed versions dropped")
Check(#printed == 0, "no line yet")
Check(ns.VersionHeard("0.24.10", "PARTY") == true, "a newer patch counts as numbers, not text")
Check(#printed == 1 and printed[1] == "version 0.24.10 is out (you have 0.24.0). Get it on [curseforge:CurseForge].",
    "one line with both versions and the link: " .. tostring(printed[1]))
Check(ns.VersionHeard("0.25.0", "GUILD") == true and #printed == 1, "a still newer version: noted, no second line")

ns = Load(false)
Check(ns.VersionHeard("0.25.0", "GUILD") == true and #printed == 0, "addon messages off: noted, chat stays quiet")

Load(true)
onEvent(nil, "PLAYER_ENTERING_WORLD")
Check(#sent == 1 and sent[1][1] == "FCUIVer" and sent[1][2] == "1\tH" and sent[1][3] == "GUILD", "login: one hello to the guild")
onEvent(nil, "PLAYER_ENTERING_WORLD")
Check(#sent == 1, "a later loading screen sends no second hello")
onEvent(nil, "CHAT_MSG_ADDON", "FCUIVer", "1\tH", "GUILD")
onEvent(nil, "CHAT_MSG_ADDON", "FCUIVer", "1\tH", "GUILD")
Check(#timers == 1, "hellos on one channel get one answer")
timers[1]()
Check(#sent == 2 and sent[2][2] == "1\tV\t0.24.0" and sent[2][3] == "GUILD", "the answer is our version")
onEvent(nil, "CHAT_MSG_ADDON", "FCUIVer", "1\tV\t0.26.1", "RAID")
Check(#printed == 1 and printed[1]:find("0.26.1", 1, true), "a version message on a roster channel gives the line")
onEvent(nil, "CHAT_MSG_ADDON", "OtherAddon", "1\tV\t9.9.9", "GUILD")
Check(#printed == 1, "other prefixes are ignored")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("version_check_test: ok")
