local _, ns = ...

-- Art setters by TEX key or file, with client/bundled fallback and bronze bookkeeping.

local B = ns.bronze
local BronzeCopy = ns.BronzeCopy

-- Last SetTexture result per key, for /fcui debug.
ns.texStatus = {}
-- texture -> the TEX key it shows
B.artKey = setmetatable({}, { __mode = "k" })

-- A key's client path, our copy's path and whether the theme has its sheet (our copy's path, else false), made on
-- first use.
local builtinOf, bundledOf, bronzeOf = {}, {}, {}
local function Resolve(key)
    local spec, BUNDLED = ns.TEX[key], B.BUNDLED
    local lead = spec:sub(1, 1)
    local builtin, bundled
    if lead == "!" then
        builtin = BUNDLED .. spec:sub(2)
        bundled = builtin
    elseif lead == "=" then
        builtin = "Interface\\" .. spec:sub(2)
        bundled = builtin
    else
        local file, copy = spec:match("^([^|]+)|?(.*)$")
        builtin = "Interface\\" .. file
        bundled = BUNDLED .. (copy ~= "" and copy or file:match("[^\\]+$"))
    end
    builtinOf[key], bundledOf[key] = builtin, bundled
    -- METAL keys never swap, even if the theme has the sheet: the tint handles them.
    bronzeOf[key] = not B.METAL[key] and BronzeCopy(bundled) and bundled or false
end

function ns.TexPaths(key)
    if not builtinOf[key] then Resolve(key) end
    return builtinOf[key], bundledOf[key], bronzeOf[key]
end
local TexPaths = ns.TexPaths

-- texture: the piece it is for, whose part may be left out of the theme.
function ns.TexPath(key, texture)
    local builtin, bundled, bronze = TexPaths(key)
    if bronze and (texture and ns.ThemeFor(texture) or not texture and ns.BronzeOn()) then return BronzeCopy(bronze), bundled end
    -- The client redrew some files under the old names: ours first.
    if B.PREFER[key] or (ns.db and ns.db.textureSource == "bundled") then return bundled, builtin end
    return builtin, bundled
end

-- SetTexture returns false for a missing file; then try the fallback.
local function SetWithFallback(texture, primary, fallback, ...)
    local ok = texture:SetTexture(primary, ...)
    if ok == false and fallback then ok = texture:SetTexture(fallback, ...) end
    return ok
end
B.SetWithFallback = SetWithFallback

-- Tint share per key, a number or by theme. Dark takes the minimap rings near black, as the action button rims.
local SHARE = { slotNormal = 0.9, trackingBorder = { dark = 1.28 }, minimapBorder = { dark = 1.28 } }

-- Falls back to the other copy so a missing file never leaves a blank region; extra args go to SetTexture.
function ns.SetTex(texture, key, ...)
    local primary, fallback = ns.TexPath(key, texture)
    local ok = texture:SetTexture(primary, ...)
    if ok == false then
        ok = texture:SetTexture(fallback, ...)
        ns.texStatus[key] = ok and "fallback" or "missing"
    else
        ns.texStatus[key] = "ok"
    end
    B.artKey[texture] = key
    -- Themed sheets swap with the theme (the old art where the client's is new) and wear its layers.
    local swapped = B.swapped
    if ns.TEX[key] and select(3, TexPaths(key)) then
        swapped[texture] = key
    elseif swapped[texture] then
        swapped[texture] = nil
    end
    if B.METAL[key] and not B.EliteAsDrawn(key, texture) then
        ns.BronzeTint(texture, SHARE[key])
    elseif B.tinted[texture] then
        -- Non-metal art, or a dragon kept as drawn: clear the tint.
        ns.UntintBronze(texture)
    end
    ns.PaintCopy(texture, swapped[texture] ~= nil and ns.ThemeFor(texture) and primary or nil)
    ns.InkChrome(texture, primary)
    return ok ~= false
end

-- A texture showing more of a themed piece's file (a tab's body and rim under its face): in the theme's repaints as the
-- piece is, or in the piece's own color. After its coords are set (the color copy takes its shape).
function ns.ThemeAs(texture, piece)
    local key, share, swap = B.artKey[piece], B.tinted[piece], B.swapped[piece]
    B.swapped[texture] = swap
    if share then
        ns.BronzeTint(texture, share ~= true and share or nil)
    else
        if B.tinted[texture] then ns.UntintBronze(texture) end
        texture:SetVertexColor(piece:GetVertexColor())
        texture:SetDesaturated(piece:IsDesaturated())
    end
    ns.PaintCopy(texture, key and swap ~= nil and ns.ThemeFor(texture) and (ns.TexPath(key, texture)) or nil)
end

-- By file; a themed sheet swaps with the theme and wears its layers.
function ns.SetFile(texture, path, ...)
    if not texture or not path then return end
    B.artKey[texture] = nil
    local copy = BronzeCopy(path)
    B.swapped[texture] = copy and path or nil
    B.swapArgs[texture] = (copy and select("#", ...) > 0) and { ... } or nil
    local onCopy = copy and ns.ThemeLook(nil, texture) == "themed"
    local ok = SetWithFallback(texture, onCopy and copy or path, copy and path, ...)
    ns.PaintCopy(texture, onCopy and copy or nil, ...)
    return ok ~= false
end

-- Out of the theme's file swap, before the texture takes other art again.
function ns.UnswapBronze(texture)
    if texture then
        B.swapped[texture], B.swapArgs[texture] = nil, nil
        ns.PaintCopy(texture, nil)
    end
end

-- Same, for a button state texture.
function ns.SetButtonFile(button, which, path, ...)
    local setter = button and button["Set" .. which .. "Texture"]
    local getter = button and button["Get" .. which .. "Texture"]
    if not setter or not getter then return end
    setter(button, path, ...)
    local tex = getter(button)
    if tex then ns.SetFile(tex, path) end
    return tex
end

function ns.SetButtonTex(button, which, key)
    local setter = button["Set" .. which .. "Texture"]
    local getter = button["Get" .. which .. "Texture"]
    if not setter or not getter then return end
    local tex = getter(button)
    if not tex then
        setter(button, (ns.TexPath(key)))
        tex = getter(button)
    end
    if not tex then return end
    ns.SetTex(tex, key)
    return tex
end

-- Ignore theme for elite frames (or a frame under it) or nameplate dragons turns at once, in a fight too (the options
-- pass waits one out).
ns.OnToggle(function(key)
    if B.ELITE_FRAME_KEYS[key] then key = "themeIgnoreElite" end
    if key ~= "themeIgnoreElite" and key ~= "themeIgnorePlateDragon" then return end
    for texture, art in pairs(B.artKey) do
        if B.AS_DRAWN[art] == key then
            if B.EliteAsDrawn(art, texture) then ns.UntintBronze(texture) else ns.BronzeTint(texture, SHARE[art]) end
        end
    end
end)
