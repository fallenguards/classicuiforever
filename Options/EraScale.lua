local _, ns = ...
local L = ns.L

-- Classic Era's interface size: asked for with the classic layout when the interface is at another, offered once on the
-- upgrade, written in the reload press. No toggle of ours: the game's own UI Scale setting changes it any time.

local TITLE = ns.options.TITLE

-- Era's own rule (measured at 1440, 1315, 950 and 720 tall): 768 / window height x Windows scaling, held to 0.9-1.0.
local function EraScale()
    local _, height = GetPhysicalScreenSize()
    if type(height) ~= "number" or height <= 0 then return nil end
    local dpi = GetScreenDPIScale and GetScreenDPIScale() or 1
    if type(dpi) ~= "number" or dpi <= 0 then dpi = 1 end
    return math.min(1, math.max(0.9, 768 / height * dpi))
end

-- The interface drawn at another scale than Era's for this window.
local function SizeOff()
    local target, now = EraScale(), UIParent:GetScale()
    return target ~= nil and type(now) == "number" and math.abs(now - target) > 0.005
end

-- Default toggles: every box at its default, the 36 px bar included (the classic look); a chat line says how to undo
-- it when this turned it on. keys: one page's toggles (nil: every one).
function ns.ResetToggles(keys)
    local small = ns.db.classicBarSize
    for _, entry in ipairs(ns.TOGGLES) do
        if not keys or keys[entry[1]] then ns.db[entry[1]] = ns.DB_DEFAULTS[entry[1]] end
    end
    -- Addon buttons' picks of their own go with Addon buttons'.
    if not keys or keys.showMinimapAddonButtons then ns.db.minimapButtonPicks = nil end
    if keys and not keys.classicBarSize then return end
    ns.db.classicBarSize = true
    if not small then ns.Print(L["OPTWIN_RESET_BAR_SIZE_NOTE"]:format(L["OPT_classicBarSize"], L["GROUP_ACTION_BARS"])) end
end

-- Settings gone with the classic layout kept at Era's size (a reinstall): the 36 px bar that layout was laid for. Both
-- read from the game; the interface size is never written here.
function ns.EraSizeOnFreshInstall()
    if not ns.freshSettings then return end
    ns.freshSettings = nil
    if ns.db.classicBarSize or not ns.ClassicLayoutActive() or EraScale() == nil or SizeOff() then return end
    ns.db.classicBarSize = true
    ns.TogglesChanged({ "classicBarSize" })
end

local function QueueEraScale()
    ns.QueueLayoutJob("eraScale", true)
end

-- After a classic layout click: Era's size asked for when the interface is at another, set as is when it matches;
-- then onDone(sized). Escape leaves the layout job waiting, as Later does.
function ns.AskEraScale(onDone)
    if not SizeOff() then
        QueueEraScale()
        onDone(true)
        return
    end
    if StaticPopup_Show then StaticPopup_Show("FCUI_ERA_SCALE_ASK", UI_SCALE or "UI Scale", nil, onDone) end
end

ns.Popup("FCUI_ERA_SCALE_ASK", {
    text = TITLE .. "\n\n" .. L["ERASCALE_ASK"],
    button1 = L["ERASCALE_SWITCH"],
    button2 = L["ERASCALE_KEEP"],
    OnAccept = function(_, onDone)
        QueueEraScale()
        onDone(true)
    end,
    OnCancel = function(_, onDone, reason)
        if reason == "clicked" then onDone(false) end
    end,
})

-- Before the pins: the 36 px bar laid live, so the pins hold its spots.
function ns.EraScaleBeforePin()
    ns.db.classicBarSize = true
    ns.ApplyAll()
end

-- The size we wrote, still the game's setting (the player has not picked another since).
local function ScaleOurs()
    local ours, now = tonumber(ns.db.eraScale), tonumber(ns.GetCVar("uiScale"))
    return ours ~= nil and now ~= nil and ns.GetCVar("useUiScale") == "1" and math.abs(now - ours) < 0.001
end
ns.EraScaleOurs = ScaleOurs

-- After the pins, last in the press: pins are screen-centre units, which a scale change leaves where they are. The pair
-- from before ours is kept for Toggle none (#181), unless ours already stands.
function ns.EraScaleAfterPin()
    local scale = EraScale()
    if not scale then return end
    local value = string.format("%.4f", scale)
    if not ScaleOurs() then ns.db.eraScaleWas = { ns.GetCVar("useUiScale"), ns.GetCVar("uiScale") } end
    if ns.SetCVar("useUiScale", "1") and ns.SetCVar("uiScale", value) then ns.db.eraScale = value end
end

local function SayScaleBack()
    ns.Print(L["ERASCALE_GIVEN_BACK"]:format(ns.ChatLink("scale", L["WELCOME_HERE"])))
end

-- Toggle none's tick box (#181): the pair from before ours. Era's size set before that pair was kept: the custom size
-- only where ns.SetCVar's record says it was on, else the game's own automatic size.
function ns.EraScaleGiveBack()
    if not ScaleOurs() then return end
    local kept, general = ns.db.eraScaleWas, ns.db.cvarWas or {}
    local use = kept and kept[1] or general.useUiScale or "0"
    local value = kept and kept[2] or general.uiScale
    if use == "1" and value then ns.WriteCVar("uiScale", value) end
    ns.WriteCVar("useUiScale", use)
    general.uiScale, general.useUiScale, ns.db.eraScale, ns.db.eraScaleWas = nil, nil, nil, nil
    SayScaleBack()
    -- The reload Toggle none asks for wipes chat: said again after it.
    if ns.needsReload then ns.db.eraScaleNote = true end
end

-- Default toggles' tick box: Era's size for this screen while the interface stands at another, written on the click.
function ns.EraScaleWanted() return SizeOff() end
function ns.EraScalePercent()
    local scale = EraScale()
    return scale and math.floor(scale * 100 + 0.5)
end
function ns.UseEraScale() ns.EraScaleAfterPin() end

function ns.AnnounceScaleBack()
    if not (ns.db and ns.db.eraScaleNote) then return end
    ns.db.eraScaleNote = nil
    SayScaleBack()
end

-- The game's Graphics page at its UI Scale row, opened by the game's own event (C_SettingsUtil), not in our run.
function ns.OpenUiScaleSettings()
    local panel, open = _G.SettingsPanel, Settings and Settings.OpenToCategory
    if not (panel and open) then return end
    for _, category in ipairs(panel:GetAllCategories() or {}) do
        if category:GetName() == _G.GRAPHICS_LABEL then
            open(category:GetID(), _G.USE_UISCALE)
            return
        end
    end
    open()
end

-- The chat line's link after the size went back: where the size lives, and a way there.
ns.Popup("FCUI_SCALE_HELP", {
    text = TITLE .. "\n\n" .. L["ERASCALE_HELP"],
    button1 = L["ERASCALE_OPEN_SETTINGS"],
    button2 = CLOSE or OKAY,
    OnAccept = function() ns.OpenUiScaleSettings() end,
})
function ns.ShowScaleHelp()
    StaticPopup_Show("FCUI_SCALE_HELP", _G.GRAPHICS_LABEL or "Graphics", _G.USE_UISCALE or "Use UI Scale")
end

-- An install from before 0.17.0, offered Era's size once.
function ns.MarkEraScaleOffer()
    ns.db.eraScaleOffer = true
    ns.db.dbVersion = 7
end

ns.Popup("FCUI_ERA_SCALE_OFFER", {
    text = TITLE .. "\n\n" .. string.format(L["ERASCALE_OFFER"], UI_SCALE or "UI Scale"),
    button1 = L["ERASCALE_SWITCH"],
    button2 = L["OPTWIN_KEEP_MINE"],
    OnAccept = function()
        QueueEraScale()
        ns.ReloadForLayout()
    end,
})

-- Once, at the first world entry after the upgrade, for the game's default scale only (kept when it lands in a fight).
function ns.OfferEraScale()
    if not ns.db or not ns.db.eraScaleOffer or InCombatLockdown() then return end
    ns.db.eraScaleOffer = nil
    if ns.GetCVar("useUiScale") == "1" or not SizeOff() then return end
    if StaticPopup_Show then StaticPopup_Show("FCUI_ERA_SCALE_OFFER") end
end
