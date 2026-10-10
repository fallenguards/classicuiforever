-- Offline test under Lua 5.4: a module that is off runs its hand-back on every pass, so one off since login must
-- write nothing on the game's frames (they may be another addon's by then). Each file below is loaded alone against a
-- stub client that counts every write on a game frame, and its hand-backs run twice.
-- Run from the addon root: lua tools/tests/restore_idle_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 212

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

-- Each group is loaded in load order into one addon table: a module's files share their state through it.
local GROUPS = {
    { "Bar/Buttons.lua" }, { "Bar/CastAnim.lua" }, { "Bar/PageArrows.lua" },
    { "Character/CharacterModel.lua", "Character/CharacterCore.lua", "Character/CharacterStats.lua",
        "Character/CharacterLists.lua", "Character/SkillDetail.lua", "Character/ReputationDetail.lua",
        "Character/CurrencyDetail.lua", "Character/CharacterSheet.lua", "Character/PetView.lua", "Character/StatPanes.lua",
        "Character/EquipmentPane.lua" },
    { "Map/MapFade.lua" }, { "Map/Minimap.lua", "Map/MinimapTracking.lua" }, { "Map/MinimapButton.lua", "Map/MinimapMicro.lua", "Map/MinimapCollector.lua" },
    { "Quest/QuestTracker.lua", "Quest/QuestWatch.lua" },
    { "Quest/QuestLogData.lua", "Quest/QuestLogShare.lua", "Quest/QuestLogWindow.lua", "Quest/QuestLogDetail.lua",
        "Quest/QuestLog.lua" },
    { "Quest/QuestMapPane.lua" },
    { "Skills/SkillShell.lua", "Skills/ProfessionsBook.lua", "Skills/ProfessionsBookFrame.lua",
        "Skills/ProfessionsFootTabs.lua", "Skills/ProfessionsWindow.lua", "Skills/TradeSkillExtras.lua",
        "Skills/TradeSkill.lua", "Skills/Talents.lua", "Skills/TalentsTree.lua" },
    { "Social/SocialWindow.lua", "Social/GuildData.lua", "Social/GuildRoster.lua", "Social/GuildNoteBridge.lua",
        "Social/GuildOpeners.lua", "Social/WhoFilters.lua", "Social/WhoList.lua", "Social/FinderTabs.lua",
        "Social/GroupFinder.lua" },
    { "Spells/SpellBook.lua" }, { "UI/ClassicFonts.lua" }, { "UI/ClientDialogs.lua" }, { "UI/ClientMenus.lua" },
    { "UI/Dialogs.lua" }, { "UI/EditModeLook.lua" }, { "UI/Tooltips.lua" },
    { "Units/UnitFrameCore.lua", "Units/HoverNumbers.lua", "Units/PlayerFrame.lua", "Units/TargetFrame.lua",
        "Units/ThreatNumber.lua", "Units/DruidMana.lua", "Units/PartyPetFrames.lua", "Units/RaidManager.lua",
        "Units/UnitFrames.lua" },
    { "Units/BuffArrow.lua" }, { "Units/CastBars.lua" }, { "Units/SwingTimers.lua" }, { "Units/ResourceDisplay.lua" },
    { "Units/StatusFont.lua" }, { "Units/MirrorTimers.lua" }, { "Units/ComboPoints.lua" },
    { "Units/NamePlates.lua", "Units/NamePlateOptions.lua" }, { "Units/LastNames.lua" },
    { "Windows/Bags.lua" }, { "Windows/Chat.lua" }, { "Windows/DamageMeter.lua" }, { "Windows/LootRoll.lua" },
    { "Windows/WindowChrome.lua", "Windows/Panels.lua" },
}
-- Left out: Bar/ClassicBar.lua and Skills/Trainer.lua, frozen paths.

-- Modules whose hand-back gives the game's parts back: turned on and off again it must still write, once. Only those
-- whose apply runs under the stub client.
local HANDS_BACK = { castAnim = true, comboPoints = true, mirrorTimers = true, hideBuffArrow = true, questTracker = true }

------------------------------------------------------------------ the stub client

local realG = {}
for k, v in pairs(_G) do realG[k] = v end

-- Method names that change a frame.
local WRITES = { "^Set", "^Show$", "^Hide$", "^Clear", "^Enable", "^Disable", "^Register", "^Unregister", "^Raise$", "^Lower$",
    "^Play$", "^Stop", "^Add", "^Remove", "^Hook", "^Update", "^Layout$", "^Refresh", "^Mark" }
local function IsWrite(name)
    if type(name) ~= "string" then return false end
    for _, pat in ipairs(WRITES) do
        if name:find(pat) then return true end
    end
    return false
end

local writes
local Soft, Piece

-- Ours: anything the addon makes or keeps for itself. Answers any lookup or call with another of its kind.
local softMeta = {}
function Soft(name)
    return setmetatable({ softName = name }, softMeta)
end
local function Num() return 0 end
softMeta.__index = function(self, key)
    if type(key) == "number" then return nil end
    local child = Soft(tostring(rawget(self, "softName")) .. "." .. tostring(key))
    rawset(self, key, child)
    return child
end
softMeta.__call = function(self, ...)
    local name = rawget(self, "softName") or ""
    local leaf = name:match("([^.]+)$") or name
    -- A helper of ours handed a game frame: a write when its name says it changes one.
    for i = 1, select("#", ...) do
        local arg = select(i, ...)
        if getmetatable(arg) == Piece and (IsWrite(leaf) or leaf:find("^Fade") or leaf:find("^Unfade") or leaf:find("^Undrain")
            or leaf:find("^Untint") or leaf:find("^Drain") or leaf:find("^Dress") or leaf:find("^Paint") or leaf:find("^Old")) then
            writes[#writes + 1] = name .. "(" .. tostring(rawget(arg, "pieceName")) .. ")"
            break
        end
    end
    -- A walk over a frame's parts visits one.
    if leaf:find("^Each") or leaf:find("^ForEach") then
        for i = 1, select("#", ...) do
            local fn = select(i, ...)
            if type(fn) == "function" then
                local root = select(1, ...)
                fn(getmetatable(root) == Piece and root.Part or Piece.New("walked"))
            end
        end
    end
    if leaf == "Path" then
        local node = ...
        for i = 2, select("#", ...) do
            if getmetatable(node) ~= Piece then break end
            node = node[(select(i, ...))]
        end
        return node
    end
    return Soft(name .. "()")
end
softMeta.__concat = function() return "" end
softMeta.__add, softMeta.__sub, softMeta.__mul, softMeta.__div, softMeta.__unm, softMeta.__mod = Num, Num, Num, Num, Num, Num
softMeta.__lt = function() return false end
softMeta.__le = function() return false end
softMeta.__len = function() return 0 end

-- The game's: a frame, a region or a function of the client. Every write on it is counted.
Piece = {}
function Piece.New(name)
    return setmetatable({ pieceName = name }, Piece)
end
Piece.__index = function(self, key)
    if type(key) == "number" then return nil end
    -- Our own table on a game frame.
    if key == "fcui" then return nil end
    local child = Piece.New(tostring(rawget(self, "pieceName")) .. "." .. tostring(key))
    rawset(child, "pieceLeaf", key)
    rawset(self, key, child)
    return child
end
Piece.__call = function(self, owner, ...)
    local leaf = rawget(self, "pieceLeaf")
    if not leaf then return nil end   -- a client function: nothing back
    if IsWrite(leaf) then
        writes[#writes + 1] = rawget(self, "pieceName")
        return nil
    end
    if leaf:find("^Create") then return Soft("made") end
    if leaf:find("^Enumerate") then
        local sent = false
        return function()
            if sent then return nil end
            sent = true
            return Piece.New(rawget(self, "pieceName") .. ".active")
        end
    end
    if leaf == "GetParent" then return owner.Parent end
    if leaf == "GetChildren" or leaf == "GetRegions" then return owner.Part end
    if leaf:find("^Is") or leaf:find("^Has") then return true end
    if leaf == "GetAlpha" or leaf == "GetScale" then return 0.5 end
    if leaf == "GetFrameLevel" then return 1 end
    if leaf:find("^Get") then return nil end
    return nil
end
Piece.__concat = softMeta.__concat
Piece.__len = softMeta.__len

local CLIENT = {
    CreateFrame = function() return Soft("frame") end,
    InCombatLockdown = function() return false end,
    GetTime = function() return 0 end,
    hooksecurefunc = function() end,
    issecretvalue = function() return false end,
    UnitClass = function() return "Class", "CLASS" end,
    UnitExists = function() return false end,
    UnitName = function() return "Name" end,
    GetRealmName = function() return "Realm" end,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    tinsert = table.insert, tremove = table.remove, unpack = table.unpack, strsplit = function() end,
    format = string.format, strfind = string.find, strlower = string.lower, strupper = string.upper, strsub = string.sub,
    floor = math.floor, ceil = math.ceil, min = math.min, max = math.max, abs = math.abs,
    GetLocale = function() return "enUS" end,
    C_Timer = { After = function() end, NewTicker = function() return Soft("ticker") end },
}

local function FreshClient()
    for k in pairs(_G) do
        if realG[k] == nil then _G[k] = nil end
    end
    for k, v in pairs(CLIENT) do _G[k] = v end
    setmetatable(_G, { __index = function(_, key)
        if type(key) ~= "string" then return nil end
        -- Constants and enums read as numbers or tables of ours; frames and functions as the game's.
        if key:find("^NUM_") or key:find("^MAX_") or key:find("_MAX$") or key:find("^LE_") then return 1 end
        if key:find("^[A-Z0-9_]+$") then return Soft(key) end
        if key == "Enum" or key == "Constants" or key == "LibStub" then return Soft(key) end
        local piece = Piece.New(key)
        rawset(_G, key, piece)
        return piece
    end })
end

------------------------------------------------------------------ run

local failures = 0
local function Fail(what)
    failures = failures + 1
    print("FAIL: " .. what)
end

local function RunGroup(group)
    local label = group[#group]
    FreshClient()
    writes = {}
    local modules = {}
    local ns = Soft("ns")
    rawset(ns, "RegisterModule", function(key, mod) modules[#modules + 1] = { key = mod.id or key, mod = mod } end)
    rawset(ns, "db", {})
    rawset(ns, "L", setmetatable({}, { __index = function(_, key) return key end }))
    rawset(ns, "IsSecret", function() return false end)
    rawset(ns, "AnySecret", function() return false end)
    rawset(ns, "ModuleInForce", function() return false end)
    for _, path in ipairs(group) do
        local chunk, err = loadfile(ROOT .. "/" .. path)
        if not chunk then Fail(path .. ": " .. tostring(err)) return end
        local ok, loadErr = pcall(chunk, "ClassicUIForever", ns)
        if not ok then Fail(path .. " did not load under the stub client: " .. tostring(loadErr)) return end
    end
    for _, entry in ipairs(modules) do
        local mod = entry.mod
        if mod.restore and mod.restore ~= mod.apply then
            writes = {}
            for pass = 1, 2 do
                local ran, runErr = pcall(mod.restore)
                if not ran then Fail(label .. " " .. entry.key .. ": hand-back pass " .. pass .. " raised " .. tostring(runErr)) break end
            end
            if #writes > 0 then
                Fail(string.format("%s %s: off since login, its hand-back wrote %d time(s) on the game's frames: %s", label,
                    entry.key, #writes, table.concat(writes, ", ", 1, math.min(#writes, 8))))
            end
            if HANDS_BACK[entry.key] then
                local applied, applyErr = pcall(mod.apply)
                if not applied then Fail(label .. " " .. entry.key .. ": apply raised " .. tostring(applyErr)) end
                writes = {}
                pcall(mod.restore)
                if #writes == 0 then Fail(label .. " " .. entry.key .. ": turned off after an apply, nothing was handed back") end
                writes = {}
                pcall(mod.restore)
                if #writes > 0 then Fail(label .. " " .. entry.key .. ": a later pass while off wrote again: " .. writes[1]) end
            end
        end
    end
end

for _, group in ipairs(GROUPS) do RunGroup(group) end
setmetatable(_G, nil)

if failures > 0 then
    print(string.format("restore idle: %d failed", failures))
    os.exit(1)
end
print("restore idle: ok")
