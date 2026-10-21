-- Offline test under Lua 5.4 for the spellbook key over the book's other pages (Spells/BookPages.lua): with a page up
-- it shuts that page; with none up it opens the spells. 0.31.0 reopened the page shown last (a profession, Collections)
-- and players lost their spellbook key, so every button the key's snippet hands on may only shut a page.
-- Run from the addon root: lua tools/tests/book_key_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 122 212

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local failed = 0
local function Check(ok, what)
    if not ok then
        failed = failed + 1
        print("FAIL: " .. what)
    end
end

local function Frame()
    local f = { attrs = {} }
    function f:SetAttribute(k, v) self.attrs[k] = v end
    function f:SetFrameRef() end
    function f:SetScript() end
    function f:HookScript() end
    return f
end

local bind = Frame()
local snippets = {}
ForeverClassicUISpellBookBind = bind
ForeverClassicUISpellBook = { FootPads = { prof = Frame(), coll = Frame() }, BookTabs = { Frame(), Frame(), Frame(), Frame() } }
UIParent = Frame()
InCombatLockdown = function() return false end
CreateFrame = function() return Frame() end
SecureHandlerWrapScript = function(frame, _, _, body) snippets[frame] = (snippets[frame] or "") .. body end
GetTime = function() return 0 end
C_Timer = { After = function() end }

local ns = {
    NewFrame = function() return Frame() end,
    EventFrame = function() end,
    Sched = { NextFrame = function() end, OnVisible = function() end, Attach = function() end },
    OnForever = function() return true end,
    ModuleInForce = function() return true end,
}
assert(loadfile(ROOT .. "/Spells/BookPages.lua"))("ClassicUIForever", ns)
ns.WireBookPages()

local press = snippets[bind]
Check(press ~= nil, "the spellbook key's press is wrapped")
local returned = 0
for n in (press or ""):gmatch('return%s+"Button(%d+)"') do
    returned = returned + 1
    local macro = bind.attrs["macrotext" .. n] or ""
    Check(macro:find("Shut") or macro:find("CloseButton"), "the key's Button" .. n .. " only shuts a page (" .. macro .. ")")
end
Check(returned > 0, "the key shuts a page that is up")
for k, v in pairs(bind.attrs) do
    if type(v) == "string" and k:find("^macrotext") then
        Check(not v:find("MicroButton"), k .. " opens no other page: " .. v)
    end
end

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("book_key_test: all checks passed")
