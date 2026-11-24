-- Offline test under Lua 5.4 for a game window's width in our window row (UI/Windows.lua BlockSpan, with
-- UI/SkillLineTab.lua ns.SideTabsRight). With our group finder off, the game's LFGParentFrame hangs three large side tabs
-- (Listing, Browsing, Who) off its right edge; the row measured the window's box alone, so a spellbook opened after it
-- stood over them (his snip 17:40). Its width runs out to its shown side tabs; faded or hidden ones take no room.
-- Run from the addon root: lua tools/tests/window_side_tabs_span_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 122 212 431 432

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local failed = 0
local function Check(ok, what)
    print((ok and "PASS " or "FAIL ") .. what)
    if not ok then failed = failed + 1 end
end

local AnyMT = {}
local function Any() return setmetatable({}, AnyMT) end
AnyMT.__index = function(t, k)
    if type(k) ~= "string" then return nil end
    local v = Any()
    rawset(t, k, v)
    return v
end
AnyMT.__call = function() return Any() end
AnyMT.__concat = function() return "" end

local function Read(path)
    local handle = assert(io.open(ROOT .. path, "r"))
    local source = handle:read("a")
    handle:close()
    return source
end

-- The game's side tab mixin (SharedXML): the large tab template's click handler setter marks one.
local SidePanelTabButtonMixin = { SetCustomOnMouseUpHandler = function() end }

-- A frame at left..right (UIParent units, scale 1), shown and opaque unless told.
local function Frame(name, left, right, children)
    local f = { name = name, left = left, right = right, shown = true, alpha = 1, children = children or {} }
    function f:GetName() return self.name end
    function f:GetLeft() return self.left end
    function f:GetRight() return self.right end
    function f:GetEffectiveScale() return 1 end
    function f:IsVisible() return self.shown end
    function f:IsShown() return self.shown end
    function f:GetEffectiveAlpha() return self.alpha end
    function f:GetChildren() return table.unpack(self.children) end
    return f
end
local function SideTab(name, left)
    local tab = Frame(name, left, left + 46)
    tab.Icon = {}
    tab.SetCustomOnMouseUpHandler = SidePanelTabButtonMixin.SetCustomOnMouseUpHandler
    return tab
end

local ns = Any()
rawset(ns, "Safe", function(v, fallback) if v == nil then return fallback end return v end)
rawset(ns, "IsForbidden", function() return false end)
rawset(ns, "EachChild", function(frame, fn) for _, c in ipairs(frame.children) do fn(c) end end)
local UIParent = Frame("UIParent", 0, 1920)
local env = setmetatable({ SidePanelTabButtonMixin = SidePanelTabButtonMixin, UIParent = UIParent,
    UIPanelWindows = { LFGParentFrame = { area = "left" } } }, { __index = function(_, k)
    local real = _G[k]
    if real ~= nil then return real end
    return Any()
end })
rawset(env, "_G", env)   -- the game's _G is its global table
assert(load(Read("/UI/SkillLineTab.lua"), "@UI/SkillLineTab.lua", "t", env))("ClassicUIForever", ns)

-- The row's measuring, as UI/Windows.lua has it (its constants handed in).
local source = Read("/UI/Windows.lua")
local first = source:find("local Plain = ns.Safe", 1, true)
local last = first and source:find("-- The frame's own width when wider", first, true)
Check(first ~= nil and last ~= nil, "the row's measuring is in UI/Windows.lua")
local chunk = "local ns, SIDE_PIECES, BESIDE_WIDTH, FLOATS, BESIDE, LEAVE_OPEN = ...\n"
    .. source:sub(first, last - 1) .. "\nreturn BlockSpan"
local BlockSpan = assert(load(chunk, "@UI/Windows.lua", "t", env))(ns, {}, 352, {}, {}, {})

local listing = SideTab("ListingTab", 354)
local browsing = SideTab("BrowsingTab", 354)
local who = SideTab("WhoListingTab", 354)
local close = Frame("CloseButton", 330, 352)
local finder = Frame("LFGParentFrame", 16, 354, { close, listing, browsing, who })

local left, right = BlockSpan("LFGParentFrame", finder)
Check(left == 16, "the group finder's left edge is its own")
Check(right == 400, "its width runs out to its side tabs (" .. tostring(right) .. ")")

listing.alpha, browsing.alpha, who.alpha = 0, 0, 0
_, right = BlockSpan("LFGParentFrame", finder)
Check(right == 354, "faded side tabs take no room (" .. tostring(right) .. ")")

listing.alpha, browsing.alpha, who.alpha = 1, 1, 1
listing.shown, browsing.shown, who.shown = false, false, false
_, right = BlockSpan("LFGParentFrame", finder)
Check(right == 354, "hidden side tabs take no room (" .. tostring(right) .. ")")

-- A plain child past the edge (not a side tab) is not counted.
local loose = Frame("Loose", 354, 500)
finder.children[#finder.children + 1] = loose
_, right = BlockSpan("LFGParentFrame", finder)
Check(right == 354, "a child that is no side tab is not counted (" .. tostring(right) .. ")")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("window_side_tabs_span_test: ok")
