-- Offline check of the English text picks (Core/Localization.lua): on a German client a picked part keeps its English
-- strings, the rest stay German, and nothing changes without saved settings or picks.
-- Run from the addon root: lua tools/tests/english_text_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 121 122

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local FILES = { "Core/Localization.lua", "Locales/enUS.lua", "Locales/enUS_WhatsNew.lua", "Locales/enUS_Help.lua", "Locales/enUS_Windows.lua", "Locales/deDE.lua",
    "Locales/deDE_WhatsNew.lua" }
-- One key per part, with its English text.
local SAMPLES = {
    englishSettings = { "OPT_threatNumber", "UI_BY_REACTION" },
    englishNews = { "WN14_2_TITLE", "WELCOME_BODY" },
    englishMessages = { "CHAT_14", "CORE_TYPE_A_NAME" },
    englishWindows = { "UI_SHOW", "BAR_KEY_RING" },
}

local function Load(saved, locale)
    ForeverClassicUIDB = saved
    GetLocale = function() return locale end
    local ns = {}
    for _, path in ipairs(FILES) do assert(loadfile(ROOT .. "/" .. path))("ClassicUIForever", ns) end
    return ns.L, ns
end

local english = Load(nil, "enUS")
local passed, failed = 0, 0
local function Check(ok, what)
    if ok then passed = passed + 1 else failed = failed + 1 print("FAIL " .. what) end
end

for part, keys in pairs(SAMPLES) do
    local L = Load({ [part] = true }, "deDE")
    for other, otherKeys in pairs(SAMPLES) do
        for _, key in ipairs(otherKeys) do
            local want = other == part
            Check((L[key] == english[key]) == want, string.format("%s picked: %s %s", part, key,
                want and "should be English" or "should be German"))
        end
    end
    for _, key in ipairs(keys) do Check(english[key] ~= key, "sample key exists: " .. key) end
end

local plain = Load({}, "deDE")
local unsaved = Load(nil, "deDE")
for _, keys in pairs(SAMPLES) do
    for _, key in ipairs(keys) do
        Check(plain[key] ~= english[key], "no picks: " .. key .. " German")
        Check(unsaved[key] ~= english[key], "no saved settings: " .. key .. " German")
    end
end

local _, ns = Load({ devLocale = "deDE" }, "enUS")
Check(ns.LOCALE == "deDE" and not ns.ENGLISH_CLIENT, "devLocale loads German on an English client")

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
