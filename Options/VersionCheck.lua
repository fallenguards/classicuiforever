local _, ns = ...
local L = ns.L

-- Update notice: no addon reaches the internet, so a newer version is heard from players who have it over the hidden
-- addon channel (guild, group); one chat line a session, never saved, so a forged version costs one line.
-- Wire: prefix FCUIVer; hello "1\tH"; version "1\tV\t<version>".

-- A standalone piece numbers its versions apart from the full addon: it compares only with the same piece.
local PREFIX = ns.PACKAGE and ns.PACKAGE.id and ("FCUIV" .. ns.PACKAGE.id):sub(1, 16) or "FCUIVer"
local PROTOCOL = "1"
local HELLO, VERSION = "H", "V"
local VERSION_PATTERN = "^%d+%.%d+%.%d+$"
-- Answers spread out, or a whole guild replies in the same instant.
local REPLY_MIN, REPLY_MAX = 2, 5
-- Channels with a real roster; whispers are unsolicited and dropped.
local ROSTER = { GUILD = true, PARTY = true, RAID = true, INSTANCE_CHAT = true }

local state = { newest = nil, told = false, replying = {}, guildHello = false, inGroup = false }

local function Valid(version)
    return type(version) == "string" and not ns.IsSecret(version) and version:match(VERSION_PATTERN) ~= nil
end

-- 1 when a is newer than b, -1 when older, 0 when the same.
local function Compare(a, b)
    local a1, a2, a3 = a:match("^(%d+)%.(%d+)%.(%d+)$")
    local b1, b2, b3 = b:match("^(%d+)%.(%d+)%.(%d+)$")
    for _, pair in ipairs({ { a1, b1 }, { a2, b2 }, { a3, b3 } }) do
        local x, y = tonumber(pair[1]), tonumber(pair[2])
        if x ~= y then return x > y and 1 or -1 end
    end
    return 0
end

local function Own() return ns.AddonVersion and ns.AddonVersion() or nil end

-- The client refuses some sends (a restricted instance); that is not an error of ours.
local function Send(channel, payload)
    if channel and C_ChatInfo and C_ChatInfo.SendAddonMessage then
        pcall(C_ChatInfo.SendAddonMessage, PREFIX, payload, channel)
    end
end

local function GroupChannel()
    local inInstance, kind = IsInInstance()
    if inInstance and kind ~= "none" then return "INSTANCE_CHAT" end
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
    return nil
end

local function Tell()
    if state.told or not ns.db or ns.db.addonMessages == false then return end
    state.told = true
    ns.Print(string.format(L["UPDATE_AVAILABLE"], state.newest, Own() or "?", ns.ChatLink("curseforge", "CurseForge")))
end

-- Every version heard passes here; the dev addon calls it to show the line without a second player.
function ns.VersionHeard(version, channel)
    local own = Own()
    if not ROSTER[channel] or not Valid(version) or not Valid(own) then return false end
    if Compare(version, own) <= 0 or (state.newest and Compare(version, state.newest) <= 0) then return false end
    state.newest = version
    Tell()
    return true
end

local function Reply(channel)
    if not ROSTER[channel] or state.replying[channel] then return end
    state.replying[channel] = true
    C_Timer.After(REPLY_MIN + math.random() * (REPLY_MAX - REPLY_MIN), function()
        state.replying[channel] = nil
        local own = Own()
        if Valid(own) then Send(channel, PROTOCOL .. "\t" .. VERSION .. "\t" .. own) end
    end)
end

local function OnEvent(_, event, prefix, message, channel)
    if event == "CHAT_MSG_ADDON" then
        if ns.IsSecret(prefix) or prefix ~= PREFIX or type(message) ~= "string" or ns.IsSecret(message) then return end
        if ns.IsSecret(channel) then return end
        local proto, command, value = strsplit("\t", message)
        if proto ~= PROTOCOL then return end
        if command == HELLO then
            Reply(channel)
        elseif command == VERSION then
            ns.VersionHeard(value, channel)
        end
    elseif event == "GROUP_ROSTER_UPDATE" then
        local now = IsInGroup() or IsInRaid()
        if now and not state.inGroup then Send(GroupChannel(), PROTOCOL .. "\t" .. HELLO) end
        state.inGroup = now
    else
        -- Not PLAYER_LOGIN: the guild can read empty on a cold login, so a later loading screen tries again.
        if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX) end
        state.inGroup = IsInGroup() or IsInRaid()
        if not state.guildHello and IsInGuild() then
            state.guildHello = true
            Send("GUILD", PROTOCOL .. "\t" .. HELLO)
        end
    end
end

ns.EventFrame({ "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "CHAT_MSG_ADDON" }, OnEvent)
