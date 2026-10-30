local _, ns = ...
local NP = ns.NP

-- Plate name and level text: Era's name size and font, the player's size offset, text shadows.

ns.PLATE_NAME_MIN, ns.PLATE_NAME_MAX = -6, 6

-- Era's plate name: Friz 10 at the plate's size, no outline, no shadow (Forever's is 17.5, outlined and shadowed).
-- Era draws it from SystemFont_NamePlate's own 9, stretched to that height: about 2% wider and softer than a true 10.
local ERA_NAME_SIZE, ERA_NAME_FONT = 10, 9
-- The client's flags string -> the same without its outline; a handful of strings ever.
local unoutlined = {}
local function Unoutlined(flags)
    flags = flags or ""
    local plain = unoutlined[flags]
    if not plain then
        plain = flags:gsub("THICKOUTLINE", ""):gsub("OUTLINE", ""):gsub("^[,%s]+", ""):gsub("[,%s]+$", "")
            :gsub(",%s*,", ",")
        unoutlined[flags] = plain
    end
    return plain
end

-- The size the client shows (Classic fonts: Era's at the plate's size) plus the player's offset in points. The client's
-- size is read off the name itself (it scales plate fonts on its own): any other than the one we last set is its new one.
function NP.NameSize(name, own)
    local file, size, flags = name:GetFont()
    if not size or ns.IsSecret(size) or ns.IsSecret(flags) then return end
    if not own.nameSet or math.abs(own.nameSet - size) > 0.05 then own.nameBase = size end
    local classic = ns.ClassicFonts()
    local base = classic and ERA_NAME_SIZE * NP.PlateScale() or own.nameBase
    local want = math.max(6, base + (tonumber(ns.db.plateNameSize) or 0))
    local wantFlags = classic and Unoutlined(flags) or flags
    -- The drawn base first, then the height: a later SetFont does not undo a stretch (the client reads back the height).
    local drawn = classic and ERA_NAME_FONT or want
    if math.abs(size - want) > 0.05 or flags ~= wantFlags or own.nameFont ~= drawn then
        -- The plate's own font for its other alphabets: a Cyrillic name keeps its letters (#188).
        local family = ns.FontFamily(_G.SystemFont_NamePlate or GameFontNormal, drawn, wantFlags, file)
        if family then ns.SetFontFamily(name, family) else name:SetFont(file, drawn, wantFlags) end
        name:SetTextHeight(want)
        own.nameFont = drawn
    end
    own.nameSet = want
end

-- Plate text shadows: none in Era's look, a 1 px drop shadow otherwise.
function NP.TextShadow(text)
    local off = ns.ClassicFonts() and 0 or 1
    text:SetShadowColor(0, 0, 0, 1)
    text:SetShadowOffset(off, -off)
end

local function PlateText(unitFrame)
    local own = unitFrame.fcui
    if not own then return end
    if unitFrame.name then
        NP.TextShadow(unitFrame.name)
        NP.NameSize(unitFrame.name, own)
    end
    if own.level then NP.TextShadow(own.level) end
end

-- Name text size (options stepper); applies live.
function ns.SetPlateNameSize(offset)
    offset = math.max(ns.PLATE_NAME_MIN, math.min(ns.PLATE_NAME_MAX, math.floor(tonumber(offset) or 0)))
    ns.db.plateNameSize = offset
    if NP.active then NP.EachPlate(PlateText) end
    return offset
end

-- Classic fonts answers on the plates at once, in a fight too.
ns.OnToggle(function(key)
    if key == "classicFonts" and NP.active then NP.EachPlate(PlateText) end
end)
