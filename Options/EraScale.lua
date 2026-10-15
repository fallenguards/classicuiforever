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

-- Reset toggles: every box at its default and, as the classic layout pairs them, the 36 px bar at Era's interface size.
-- keys: one page's toggles (nil: every one).
function ns.ResetToggles(keys)
    for _, entry in ipairs(ns.TOGGLES) do
        if not keys or keys[entry[1]] then ns.db[entry[1]] = ns.DB_DEFAULTS[entry[1]] end
    end
    if (not keys or keys.classicBarSize) and EraScale() ~= nil and not SizeOff() then ns.db.classicBarSize = true end
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

-- After the pins, last in the press: pins are screen-centre units, which a scale change leaves where they are.
function ns.EraScaleAfterPin()
    local scale = EraScale()
    if not scale then return end
    local value = string.format("%.4f", scale)
    if ns.SetCVar("useUiScale", "1") and ns.SetCVar("uiScale", value) then ns.db.eraScale = value end
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
