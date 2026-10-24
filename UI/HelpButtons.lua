local _, ns = ...

-- Hide help buttons: the game's tutorial "i" on its windows, faded and deaf, since the game shows it again on its own
-- (the map on every restore from maximized, the spellbook on each tab). Windows loading on demand are caught as they
-- load; the game's one-time "Click here for help" tip, aimed at a faded button, goes out with it.

local SPOTS = {
    { "WorldMapFrame", "BorderFrame", "Tutorial" },
    { "EditModeManagerFrame", "Tutorial" },
    { "SettingsPanel", "Container", "SettingsList", "Header", "TutorialButton" },
    { "ProfessionsBookFrame", "MainHelpButton" },
    { "PlayerSpellsFrame", "SpellBookFrame", "HelpPlateButton" },
    { "ProfessionsFrame", "CraftingPage", "TutorialButton" },
    { "PetJournal", "MainHelpButton" },
    { "WardrobeCollectionFrame", "InfoButton" },
    { "TransmogFrame", "HelpPlateButton" },
    { "EncounterJournal", "MonthlyActivitiesFrame", "HelpButton" },
    { "AuctionHouseFrame", "WoWTokenResults", "HelpButton" },
    { "ArchaeologyFrame", "infoButton" },
    { "GarrisonBuildingFrame", "MainHelpButton" },
    { "StableFrame", "MainHelpButton" },
    { "ClickBindingFrame", "TutorialButton" },
    { "IslandsQueueFrame", "HelpButton" },
    { "CommunitiesFrame", "GuildBenefitsFrame", "GuildRewardsTutorialButton" },
}

local faded = setmetatable({}, { __mode = "k" })
local found = {}   -- spot index -> true once its button is faded
local waiter

local function Button(spot)
    local node = _G[spot[1]]
    for i = 2, #spot do
        node = type(node) == "table" and node[spot[i]] or nil
    end
    return type(node) == "table" and node.SetAlpha and node or nil
end

local function Fade(button, hide)
    if (faded[button] or false) == hide then return end
    faded[button] = hide or nil
    button:SetAlpha(hide and 0 or 1)
    button:EnableMouse(not hide)
end

-- Every spot not yet found: windows that load on demand come in one by one.
local function Sweep()
    local left = 0
    for i, spot in ipairs(SPOTS) do
        if not found[i] then
            local button = Button(spot)
            if button then
                found[i] = true
                Fade(button, true)
            else
                left = left + 1
            end
        end
    end
    if left == 0 and waiter then waiter:UnregisterAllEvents() end
end

local function Apply()
    if waiter then waiter:RegisterEvent("ADDON_LOADED") else waiter = ns.EventFrame("ADDON_LOADED", Sweep) end
    Sweep()
    if HelpPlate and HelpPlateTooltip then
        ns.HookMethod(HelpPlate, "ShowTutorialTooltip", function(_, button)
            if faded[button] then HelpPlateTooltip:Hide() end
        end)
    end
end

local function Restore()
    if waiter then waiter:UnregisterAllEvents() end
    wipe(found)
    for button in pairs(faded) do Fade(button, false) end
end

ns.RegisterModule("hideHelpButtons", { apply = Apply, restore = Restore })
