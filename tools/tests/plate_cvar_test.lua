-- Offline test under Lua 5.4 for the nameplates' answer to a changed CVar, target and focus (Units/NamePlates.lua).
-- Every CVar written by the game or any addon laid every plate out twice; now only one named for the plates does. The
-- names below are the ones the client's plate files listen to (Blizzard_NamePlates, the same on both clients); ours are
-- read from our files. A target or focus change re-lays only the plate that lost it and the one that gained it (#127).
-- Run from the addon root: lua tools/tests/plate_cvar_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 212

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local failed = 0
local function Check(ok, what)
    if not ok then
        failed = failed + 1
        print("FAIL " .. what)
    end
end

local function ReadFile(path)
    local handle = assert(io.open(ROOT .. path, "r"))
    local text = handle:read("a")
    handle:close()
    return text
end

------------------------------------------------------------------ the event handler, cut out of the file and run

local source = ReadFile("/Units/NamePlates.lua")
local first = source:find("local ALL_EVENTS = {", 1, true)
local last = source:find("local function Apply()", 1, true)
Check(first and last and last > first, "the plates' event handler is in the file")
local chunk = first and last and (source:sub(first, last - 1) .. "\nreturn OnEvent") or ""

local relays, queued = 0, {}
-- The plate shown for each unit token now.
local plateOf = {}
local env = setmetatable({
    NP = { active = true, Unpaint = function() end },
    CAST_EVENTS = {},
    held = {},
    castCut = {},
    QueueRelay = function(unitFrame)
        if unitFrame == nil then relays = relays + 1 else queued[#queued + 1] = unitFrame end
    end,
    PlateFor = function(token) return plateOf[token] end,
    LivePlate = function(token) return plateOf[token] end,
    MaybePlayer = function() return false end,
    SetSweeping = function() end,
    ns = { Sched = { NextFrame = function() end }, Path = function() end },
}, { __index = _G })
local run, err = load(chunk, "plate events", "t", env)
Check(run ~= nil, "the handler loads (" .. tostring(err) .. ")")
local OnEvent = run and run() or function() end

-- Whether a change of this CVar lays every plate out again, and whether it drops the kept plate size.
local function Changed(name)
    relays, env.plateScale = 0, 1.25
    OnEvent(nil, "CVAR_UPDATE", name, "1")
    return relays == 1, env.plateScale == nil
end

------------------------------------------------------------------ the client's plate CVars

local CLIENT = {
    "nameplateInfoDisplay", "nameplateCastBarDisplay", "nameplateThreatDisplay", "nameplateEnemyNpcAuraDisplay",
    "nameplateEnemyPlayerAuraDisplay", "nameplateFriendlyPlayerAuraDisplay", "nameplateShowDebuffsOnFriendly",
    "nameplateDebuffPadding", "nameplateAuraScale", "nameplateSize", "nameplateStyle", "nameplateSimplifiedTypes",
    "SoftTargetNameplateSize", "nameplateShowFriendlyNpcs", "nameplateShowOnlyNameForFriendlyPlayerUnits",
    "nameplateUseClassColorForFriendlyPlayerUnitNames", "nameplateShowAllPersonalAuras",
    "nameplateShowFriendlyRealmName", "nameplateForceShowUnitName", "nameplateShowFriendlyClassColor",
    "nameplateShowClassColor",
    -- The engine's own, spelled with capitals.
    "NamePlateHorizontalScale", "NamePlateVerticalScale", "nameplateOverlapV", "nameplateMaxDistance",
}
for _, name in ipairs(CLIENT) do
    local relaid, dropped = Changed(name)
    Check(relaid, name .. " lays the plates out again")
    Check(dropped, name .. " drops the kept plate size")
end

------------------------------------------------------------------ ours, read from our files

local ours = 0
for _, path in ipairs({ "/Units/NamePlates.lua", "/Units/NamePlateOptions.lua" }) do
    local text = ReadFile(path)
    for name in text:gmatch('_CVAR = "([^"]+)"') do
        ours = ours + 1
        Check(Changed(name), "our " .. name .. " lays the plates out again")
    end
    local list = text:match("SCALE_CVARS = (%b{})")
    for name in (list or ""):gmatch('"([^"]+)"') do
        ours = ours + 1
        Check(Changed(name), "our " .. name .. " lays the plates out again")
    end
end
Check(ours >= 6, "our plate CVars were found in our files (" .. ours .. ")")

------------------------------------------------------------------ everything else

for _, name in ipairs({ "Sound_MasterVolume", "cameraDistanceMaxZoomFactor", "autoLootDefault", "chatBubbles",
    "SoftTargetIconEnemy", "UnitNameNPC", "showTargetOfTarget" }) do
    local relaid, dropped = Changed(name)
    Check(not relaid, name .. " lays no plate out")
    Check(not dropped, name .. " keeps the plate size")
end

-- The other whole-pass events answer as before.
for _, event in ipairs({ "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED" }) do
    relays = 0
    OnEvent(nil, event)
    Check(relays == 1, event .. " lays the plates out again")
end

------------------------------------------------------------------ target and focus: two plates, never all

local A, B, C = { "plate A" }, { "plate B" }, { "plate C" }
local function Changed2(event, token, now)
    relays, queued = 0, {}
    plateOf[token] = now
    OnEvent(nil, event)
    return relays, queued
end
for _, case in ipairs({ { "PLAYER_TARGET_CHANGED", "target" }, { "PLAYER_FOCUS_CHANGED", "focus" } }) do
    local event, token = case[1], case[2]
    env.held[token] = A
    local all, laid = Changed2(event, token, B)
    Check(all == 0, event .. " lays no whole pass")
    Check(#laid == 2 and laid[1] == A and laid[2] == B, event .. " re-lays the old and the new plate")
    Check(env.held[token] == B, event .. " keeps the new plate")
    all, laid = Changed2(event, token, nil)
    Check(all == 0 and #laid == 1 and laid[1] == B, event .. " to a unit with no plate re-lays only the old one")
    Check(env.held[token] == nil, event .. " to a unit with no plate keeps none")
    -- The unit's plate shows up later (it came into range): that plate is the one held.
    plateOf[token], plateOf.nameplate3 = C, C
    OnEvent(nil, "NAME_PLATE_UNIT_ADDED", "nameplate3")
    Check(env.held[token] == C, token .. "'s plate added later is held")
    OnEvent(nil, "NAME_PLATE_UNIT_REMOVED", "nameplate3")
    Check(env.held[token] == nil, token .. "'s plate removed is let go")
    plateOf[token], plateOf.nameplate3 = nil, nil
end

-- Turned off, nothing answers.
env.NP.active = false
Check(not Changed("nameplateSize"), "with the plates off a CVar lays nothing out")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("plate_cvar_test: ok")
