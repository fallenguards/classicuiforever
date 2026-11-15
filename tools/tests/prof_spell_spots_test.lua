-- Offline test under Lua 5.4 for the professions book's spells in a fight (Skills/ProfessionsWindow.lua): the client
-- lays a card's spells again as the book shows, fights included, where they are protected; the openers' secure click
-- puts each one kept (spellIJ ref, x, y) back on its spot after the show. The click's own snippet is run here.
-- Run from the addon root: lua tools/tests/prof_spell_spots_test.lua (CI runs every tools/tests/*_test.lua).
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

local source = assert(io.open(ROOT .. "/Skills/ProfessionsWindow.lua")):read("a")
local body = source:match('SecureHandlerWrapScript%(button, "OnClick", sizeWrap, %[%[.-%]%], %[%[(.-)%]%]%)')
Check(body ~= nil, "the openers' click has its after-show snippet")
body = body or ""

local function Button(shown)
    return { shown = shown, IsShown = function(self) return self.shown end,
        SetPoint = function(self, ...) self.point = { ... } end }
end
local buttons = { spell11 = Button(true), spell12 = Button(true), spell21 = Button(true), spell22 = Button(false) }
local attrs = { spell11x = 15, spell11y = 56, spell12x = 15, spell12y = 15, spell21x = 15, spell21y = 46,
    spell22x = 15, spell22y = 15 }
local control = {
    GetFrameRef = function(_, name) return buttons[name] end,
    GetAttribute = function(_, name) return attrs[name] end,
}
local run, err = load(body, "snippet", "t", setmetatable({ control = control }, { __index = _G }))
Check(run ~= nil, "the snippet parses: " .. tostring(err))
if run then
    local ok, runErr = pcall(run)
    Check(ok, "the snippet runs: " .. tostring(runErr))
end

local function At(name, y)
    local p = buttons[name].point
    return p ~= nil and p[1] == "BOTTOMLEFT" and p[2] == "$parent" and p[3] == "BOTTOMLEFT" and p[4] == 15 and p[5] == y
end
Check(At("spell11", 56) and At("spell12", 15), "a two spell card's pair goes back on our spots")
Check(At("spell21", 46), "a one spell card's spell goes back on its spot")
Check(buttons.spell22.point == nil, "a hidden spell is left alone")

-- Kept after every tighten, so the click carries this pass's spots.
Check(source:find("TightenSpells%(%)%s+KeepSpellSpots%(%)") ~= nil, "the spots are kept right after each tighten")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("prof_spell_spots_test: ok")
