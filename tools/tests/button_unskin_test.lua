-- Offline test under Lua 5.4 for handing the client's action buttons back (Bar/Buttons.lua Unskin): a small button
-- (pet, stance, possess: SmallActionButtonMixin) gets the client's small art sizes back, a full one its own; a pet bar
-- reused by a bar addon showed 46 x 45 checked boxes off its 30 px buttons (2026-11-15).
-- Run from the addon root: lua tools/tests/button_unskin_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local failed = 0
local function Check(ok, what)
    if not ok then
        failed = failed + 1
        print("FAIL: " .. what)
    end
end

local source = assert(io.open(ROOT .. "/Bar/Buttons.lua")):read("a")
local function Body(pattern, what)
    local body = source:match(pattern)
    Check(body ~= nil, what .. " is found")
    return body or ""
end
local consts = source:match("(local FRAME_W, FRAME_H, SMALL_W, SMALL_H = [^\n]+)")
Check(consts ~= nil, "the art sizes are found")
local mouseover = Body("local function ToMouseover%(tex, _, w, h%)\n(.-)\nend\n", "ToMouseover")
local unskin = Body("local function Unskin%(button%)\n(.-)\nend\n", "Unskin")

local function Tex()
    local t = {}
    t.SetTexCoord = function() end
    function t:SetAtlas(atlas, useSize) self.atlas, self.useSize = atlas, useSize end
    function t:SetSize(w, h) self.w, self.h = w, h end
    t.SetBlendMode = function() end
    t.SetAlpha = function() end
    t.SetDrawLayer = function() end
    t.ClearAllPoints = function() end
    t.SetPoint = function() end
    return t
end
local function Button(small)
    local b = { Highlight = Tex(), Checked = Tex(), Flash = Tex(), Border = Tex(), cooldown = Tex(), icon = Tex() }
    if small then b.SmallActionButtonMixin_OnLoad = function() end end
    return b
end

local env = setmetatable({
    ns = {
        EMPTY = {},
        SetPointOnce = function() end,
        EachState = function(button, states, fn, a1, a2)
            for _, state in ipairs(states) do
                if button[state] then fn(button[state], state, a1, a2) end
            end
        end,
    },
    borders = {}, UnKeyText = function() end, UnfitSlot = function() end,
    COOLDOWNS = { "cooldown" }, COOLDOWN_INSET = 3,
    NORMAL_PUSHED = {}, HIGHLIGHT_CHECKED = { "Highlight", "Checked" }, ToCorner = function() end,
}, { __index = _G })
-- The constants as globals of the environment (the chunk's locals are not seen by the next chunk).
local fw, fh, sw, sh = assert(load((consts or "") .. "\nreturn FRAME_W, FRAME_H, SMALL_W, SMALL_H", "c", "t", env))()
env.FRAME_W, env.FRAME_H, env.SMALL_W, env.SMALL_H = fw, fh, sw, sh
env.ToMouseover = assert(load("local tex, _, w, h = ...\n" .. mouseover, "ToMouseover", "t", env))
local Unskin = assert(load("local button = ...\n" .. unskin, "Unskin", "t", env))

local pet = Button(true)
Unskin(pet)
Check(pet.Checked.w == 31.6 and pet.Checked.h == 30.9, "a small button's checked box is the client's small size (" ..
    tostring(pet.Checked.w) .. ")")
Check(pet.Highlight.w == 31.6, "and its highlight")
Check(pet.Border.w == 31.6 and pet.Border.useSize == false, "and its border")
Check(pet.Flash.w == 31.6 and pet.Flash.useSize == false, "and its flash")

local full = Button(false)
Unskin(full)
Check(full.Checked.w == 46 and full.Checked.h == 45, "a full button's checked box is 46 x 45")
Check(full.Border.useSize == true and full.Flash.useSize == true, "a full button's border and flash take the atlas size")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("button_unskin_test: ok")
