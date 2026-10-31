-- Offline test under Lua 5.4 for the plates' aura rings (Units/NamePlateAuras.lua): an aura change tints the rings of
-- the plate it came from, not every plate (#127: every UNIT_AURA on any plate walked all of them).
-- Run from the addon root: lua tools/tests/plate_rings_test.lua (CI runs every tools/tests/*_test.lua).
-- luacheck: std lua54
-- luacheck: ignore 111 112 113 121 122 212

local ROOT = (arg and arg[0] or ""):gsub("[\\/]tools[\\/]tests[\\/][^\\/]*$", "")
if ROOT == (arg and arg[0]) or ROOT == "" then ROOT = "." end

local failed = 0
local function Check(ok, what)
    if not ok then
        failed = failed + 1
        print("FAIL " .. what)
    end
end

local RING = "UI-HUD-CoolDownManager-IconOverlay"

-- A plate with one debuff item wearing the ring.
local function Plate()
    local ring = { atlas = RING, tints = 0 }
    function ring:GetAtlas() return self.atlas end
    local item = { regions = { ring } }
    local list = { children = { item } }
    return { AurasFrame = { DebuffListFrame = list }, ring = ring, item = item, list = list }
end

local plates = { nameplate1 = Plate(), nameplate2 = Plate(), nameplate3 = Plate() }
local onEvent, nextFrame
local walked = {}   -- list -> times its items were walked
local ns = {
    Safe = function(v) return v end,
    BronzeTint = function(region) region.tints = region.tints + 1 end,
    EachRegion = function(frame, fn, a1)
        for _, region in ipairs(frame.regions) do fn(region, a1) end
    end,
    EachChild = function(frame, fn)
        walked[frame] = (walked[frame] or 0) + 1
        for _, child in ipairs(frame.children) do fn(child) end
    end,
    EventFrame = function(_, fn) onEvent = fn end,
    Sched = { NextFrame = function(_, fn) nextFrame = fn end },
    NP = {
        LivePlate = function(unit) return plates[unit] end,
        EachPlate = function(fn)
            for _, unitFrame in pairs(plates) do fn(unitFrame) end
        end,
    },
}

local load_ok, err = pcall(function() assert(loadfile(ROOT .. "/Units/NamePlateAuras.lua", "t", _G))(nil, ns) end)
Check(load_ok, "the ring code loads (" .. tostring(err) .. ")")
if not load_ok then os.exit(1) end

local function Walks(unit) return walked[plates[unit].list] or 0 end

-- One plate's auras change: only its rings are looked at, on the next frame.
onEvent(nil, "UNIT_AURA", "nameplate1")
Check(nextFrame ~= nil, "an aura change asks the next frame")
nextFrame()
Check(plates.nameplate1.ring.tints == 1, "the changed plate's ring is tinted")
Check(Walks("nameplate2") == 0 and Walks("nameplate3") == 0, "the other plates are not walked")

-- Two plates in the same frame: each once.
onEvent(nil, "UNIT_AURA", "nameplate2")
onEvent(nil, "UNIT_AURA", "nameplate3")
onEvent(nil, "UNIT_AURA", "nameplate3")
nextFrame()
Check(Walks("nameplate2") == 1 and Walks("nameplate3") == 1, "two changed plates are walked once each")
Check(Walks("nameplate1") == 1, "the first plate is not walked again")

-- A tinted ring is not tinted again on the plate's next change.
onEvent(nil, "UNIT_AURA", "nameplate1")
nextFrame()
Check(plates.nameplate1.ring.tints == 1, "a tinted ring stays tinted once")

-- Not a plate's unit: nothing asked.
nextFrame = nil
onEvent(nil, "UNIT_AURA", "target")
Check(nextFrame == nil, "a non-plate unit asks nothing")

if failed > 0 then
    print(failed .. " check(s) failed")
    os.exit(1)
end
print("plate_rings_test: ok")
