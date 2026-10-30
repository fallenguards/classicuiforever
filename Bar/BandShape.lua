local _, ns = ...
local B = ns.band

-- On the band, left to right: bar 1's half (512), the micro region (as wide as its row, up to the old art's room), the bag part.
-- Edit mode can take micro or bags off; the band ends at what remains, right gryphon on the last piece.
-- Micro moved: bags close up against bar 1's page arrows; both moved: bar 1 alone.

local ART_W, PAGE_ROOM, PAGE_POST = B.ART_W, B.PAGE_ROOM, B.PAGE_POST
local MICRO_LEAD, MICRO_REGION_MAX, MICRO_END_GAP = B.MICRO_LEAD, B.MICRO_REGION_MAX, B.MICRO_END_GAP
local POST_U, POST_W = B.POST_U, B.POST_W
local ROW_X, ROW_Y = B.ROW_X, B.ROW_Y
-- Era's row start, measured (eram bar: Character at 552 of its 1024 bar); the band lays its row 4 short of this.
local MICRO_X = 556
-- Bar 1 alone: the page room runs 1 px on into dark stone, under the right gryphon's inner edge, which then covers the
-- page number post's dim outer column and meets its bright border.
local ALONE_DARK = 1
-- A micro region standing second has no page arrows: only this margin.
local MICRO_SECOND_LEAD = 8
-- Dropped this close (screen px at UI scale) to a band spot: snaps back there.
local SNAP_PX = 48
B.SNAP_PX = SNAP_PX

-- One-bar mode: the band ends after the twelve main slots, right gryphon beside them; micro menu and bags stay off.
local function OneBar() return ns.db and ns.db.oneBar == true end
B.OneBar = OneBar
-- One bar's page arrows, its option: the game's own small ones on the left gryphon (#207); the band has no room for ours.
function B.ModernPages() return OneBar() and ns.db.modernPageArrows == true end
-- No page arrows on the band: Hide Bar Scrolling, the game's setting for bar 1, or One bar.
function B.NoPages(bar) return OneBar() or B.BarSetting(bar, "HideBarScrolling") == 1 end
-- Bags off the band with their art hidden: the buttons side by side (its option), not a socket apart over nothing.
function B.BagsTight() return ns.db ~= nil and ns.db.hideBagsArt == true and ns.db.bagsTight == true end

-- dbVersion 19: a save with One bar on keeps its band as it was (latency bar, key ring and page arrows on it).
function ns.KeepOneBarLook()
    local function Keep(t)
        if t.oneBar == true and t.oneBarAlone == nil then t.oneBarAlone = false end
    end
    Keep(ns.db)
    for _, shot in pairs(type(ns.db.profiles) == "table" and ns.db.profiles or {}) do
        if type(shot) == "table" then Keep(shot) end
    end
end

-- dbVersion 22: Main bar alone is gone; One bar alone sets its pieces' own options. A band that was alone keeps its
-- look through them; one that kept its pieces keeps its page arrows, now the modern ones on the gryphon.
function ns.OneBarAloneGone()
    local function Move(t)
        if t.oneBar == true and t.oneBarAlone ~= false then
            t.hideLatencyBar, t.keyRingWithBags = true, true
        elseif t.oneBar == true then
            t.modernPageArrows = true
        end
        t.oneBarAlone = nil
    end
    Move(ns.db)
    for _, shot in pairs(type(ns.db.profiles) == "table" and ns.db.profiles or {}) do
        if type(shot) == "table" then Move(shot) end
    end
    ns.db.dbVersion = 22
end

-- Turned on with One bar from 0.31.0 to 0.34.0 and left on when it was turned off: the art, and the pieces with it.
local ONE_BAR_ART = { "hideBagsArt", "hideMicroArt", "keyRingArtHidden" }
local ONE_BAR_LEFT = { "hideBagsArt", "hideMicroArt", "keyRingArtHidden", "bagsTight", "hideLatencyBar", "keyRingWithBags" }

-- t: the account's full values or a profile's differences. Any art still hidden counts: a save had the micro and bag art
-- hidden with the key ring's shown again.
local function LeftOn(t)
    if t.oneBar == true then return false end
    for _, k in ipairs(ONE_BAR_ART) do
        if t[k] == true then return true end
    end
    return false
end

local function EachProfile(fn)
    for _, shot in pairs(type(ns.db.profiles) == "table" and ns.db.profiles or {}) do
        if type(shot) == "table" then fn(shot) end
    end
end

-- dbVersion 23: a save left so is told at each login until the player picks (ns.AnnounceOneBarArt); nothing changes unasked.
function ns.NoteOneBarArt()
    local db = ns.db
    local left = LeftOn(db)
    EachProfile(function(shot) left = left or LeftOn(shot) end)
    if left then db.oneBarArtNote = true end
    db.dbVersion = 23
end

-- Show them: every piece still on goes off in the settings in use (those applied) and in every profile left so.
local function ShowArt()
    local db = ns.db
    db.oneBarArtNote = nil
    EachProfile(function(shot)
        if LeftOn(shot) then
            for _, k in ipairs(ONE_BAR_LEFT) do shot[k] = nil end
        end
    end)
    if not LeftOn(db) then return end
    local changed = {}
    for _, k in ipairs(ONE_BAR_LEFT) do
        if db[k] == true then
            db[k] = false
            changed[#changed + 1] = k
        end
    end
    ns.TogglesChanged(changed)
end

-- The title comes at show: Options loads after this file.
ns.Popup("FCUI_ONE_BAR_ART", {
    text = ns.L["ONE_BAR_ART_ASK"],
    button1 = ns.L["ONE_BAR_ART_SHOW"],
    button2 = ns.L["OPTWIN_KEEP_MINE"],
    OnAccept = ShowArt,
    OnCancel = function(_, _, reason)
        if reason == "clicked" then ns.db.oneBarArtNote = nil end
    end,
})

function ns.ShowOneBarArt() StaticPopup_Show("FCUI_ONE_BAR_ART", ns.options.TITLE) end

-- Every login until they pick; the Addon messages row hushes it.
function ns.AnnounceOneBarArt()
    if not ns.db or not ns.db.oneBarArtNote or ns.db.addonMessages == false then return end
    ns.Print(string.format(ns.L["ONE_BAR_ART_CHAT"], ns.ChatLink("onebar", ns.L["WELCOME_HERE"])))
end

-- The micro menu moves by our handle, not the client's edit mode piece (re-laid constantly while edit mode is open);
-- its spot and size live in saved settings.
-- A broken saved place (a drag that left no anchor, before that was caught) counts as none and is dropped.
local function MicroOut()
    if not ns.db then return false end
    if ns.db.microPos ~= nil and not ns.ValidPlace(ns.db.microPos) then ns.db.microPos = nil end
    return ns.db.microPos ~= nil
end
B.MicroOut = MicroOut

-- Micro menu moves and our Hide Bar Art checks never light edit mode's Save: the first change per edit session
-- snapshots them and lights Save/Revert All (the edit watch); Save settles it, Revert All restores the snapshot.
function ns.MicroTouched()
    if ns.microDirty or not ns.db then return end
    local pos = ns.db.microPos
    ns.microBefore = {
        pos = type(pos) == "table" and { point = pos.point, relPoint = pos.relPoint, x = pos.x, y = pos.y } or nil,
        scale = ns.db.microScale,
        width = ns.db.microWidth,
        bagsFirst = ns.db.bagsFirst,
        microArt = ns.db.hideMicroArt,
        bagsArt = ns.db.hideBagsArt,
    }
    ns.microDirty = true
end

local function MicroUserScale()
    local value = tonumber(ns.db and ns.db.microScale) or 1
    return math.max(0.5, math.min(2, value))
end
B.MicroUserScale = MicroUserScale
-- Menu Width: the row's width in units of its own, the buttons at their size.
function B.MicroUserWidth()
    local value = tonumber(ns.db and ns.db.microWidth) or 1
    return math.max(0.5, math.min(2, value))
end

local shape = { micro = true, bags = true, region = MICRO_REGION_MAX }
B.shape = shape

-- While a group is dragged the band previews the drop: drawn with it when held near its place, without it when away.
B.dragPreview = {}

local function OnBandMicro() return shape.micro and not OneBar() end
local function OnBandBags() return shape.bags and not OneBar() and B.BagsMode() ~= "hidden" end
B.OnBandMicro, B.OnBandBags = OnBandMicro, OnBandBags

-- The latency and key ring section at x (spans: B.TailSpan).
local function Tail(plan, x, afterPost, beforeBags)
    local u0, u1, slot = B.TailSpan(afterPost, beforeBags)
    if not u0 then return x end
    plan.tailStart, plan.tailU0, plan.tailU1, plan.tailSlot = x, u0, u1, slot
    return x + u1 - u0
end

-- The bag part at x, less its first trim columns (trim, or postTrim past the page number slot's post).
local function Bags(plan, x, trim)
    plan.bagsStart, plan.bagTrim = x, trim
    x = x + B.BagPart() - trim
    plan.bagsEnd = x
    return x
end

-- Past bar 1 in snap order, the latency and key ring section between the groups: micro region (its head holds the page
-- arrows) | section | bags, or page arrow room | bags | section | micro region; else on the bar 1 side of what stands.
-- Bar 1 with fewer than 12 icons trims the band from the left by whole slots, like the client's bar.
local function BandPlan(microOn, bagsOn, bagsFirst, region, bar2W, bar2Left)
    local plan = { bagsFirst = (bagsFirst and microOn and bagsOn) and true or false }
    plan.cut = shape.cut or 0
    local x = ART_W / 2 - plan.cut
    -- Bar 1's run and first button, and bar 2's (option): a run of sockets right after bar 1's, or before it with bar 1's
    -- run then starting past the shared wall; the rest of the band after both.
    plan.bar1Start, plan.bar1X, plan.bar2X = 0, ROW_X, nil
    if bar2W and bar2W > 0 then
        plan.bar2W = bar2W
        if bar2Left then
            plan.bar2Start, plan.bar2X = 0, ROW_X
            plan.bar1Start, plan.bar1X, plan.bar1Skip = bar2W + ROW_X, bar2W + ROW_X, ROW_X
        else
            plan.bar2Start, plan.bar2X = x, x
        end
        x = x + bar2W
    end
    plan.base = x
    plan.microFirst = (microOn and not plan.bagsFirst) and true or false
    -- Hide Bar Scrolling: the arrows' room goes and the rest closes up; a first micro region is then drawn as a second one.
    plan.noPages = shape.noPages and true or false
    if plan.microFirst then
        if plan.noPages then
            plan.microStart, plan.microRow = x, x + MICRO_SECOND_LEAD
            x = x + region - MICRO_LEAD + MICRO_SECOND_LEAD
        else
            plan.microStart, plan.microRow = x, x + (MICRO_X - ART_W / 2)
            x = x + region
        end
        plan.microEnd = x
        local before = x
        if not plan.noPages and region - MICRO_END_GAP <= 256 and B.TailSpan(false, bagsOn) then
            -- Era's art (eram bar): the third sheet to its end, the section from there with its own post; its window,
            -- key ring and bags then stand at Era's 773, 790 and 813.
            plan.wholeSheet = true
            x = plan.microStart + 256
            plan.microEnd = x
            x = Tail(plan, x, false, bagsOn)
        else
            -- Past the sheet the floor still ends on its rim (B.MicroRuns): the section's own post closes it, as on Era's.
            x = Tail(plan, x, false, bagsOn)
        end
        -- Last on the band, the section's own post ends it; a micro region standing last leaves room for the end post.
        plan.ownEnd = plan.tailStart ~= nil and not bagsOn
        if bagsOn then
            x = Bags(plan, x, B.Bag().trim)
        elseif x == before then
            x = x + POST_W
        end
    else
        -- What follows the page number slot starts at its post (no dark stone between) under the box's jutting edge
        -- (plan.pageEdge); bags drop their own leading post there, the section keeps its own.
        local paged = not plan.noPages
        if paged then
            x = x + PAGE_POST
            plan.pageEdge = x
        end
        local bag = B.Bag()
        local bagTrim = paged and bag.postTrim or bag.trim
        if bagsOn and microOn then
            x = Bags(plan, x, bagTrim)
            x = Tail(plan, x, true, false)
            plan.microStart = x
            x = x + region - MICRO_LEAD + MICRO_SECOND_LEAD
            plan.microEnd = x
            -- Last on the band: the row (region less lead and end gap) centred on the floor before the end post.
            local row = region - MICRO_LEAD - MICRO_END_GAP
            plan.microRow = plan.microStart + (plan.microEnd - POST_W - plan.microStart - row) / 2
        elseif bagsOn then
            local before = x
            x = Tail(plan, x, false, true)
            x = Bags(plan, x, x == before and bagTrim or bag.trim)
        else
            -- Neither group on the band: the section stays with bar 1, its own post ending the band.
            local before = x
            x = Tail(plan, x, false, false)
            if x ~= before then
                plan.ownEnd = true
            elseif paged then
                -- Bar 1 alone: the page number slot's post, then dark stone under the gryphon.
                plan.ownEnd, plan.pageRoom, plan.pageEdge = true, PAGE_ROOM + ALONE_DARK, nil
                x = plan.base + PAGE_ROOM + ALONE_DARK
            end
        end
    end
    plan.width = x
    return plan
end
B.BandPlan = BandPlan

local function CurrentPlan()
    if not shape.plan then
        shape.plan = BandPlan(OnBandMicro(), OnBandBags(), ns.db and ns.db.bagsFirst, shape.region, shape.bar2W, shape.bar2Left)
    end
    return shape.plan
end
B.CurrentPlan = CurrentPlan

local function ArtWidth() return CurrentPlan().width end
B.ArtWidth = ArtWidth

-- The group whose run the end post closes.
local function EndOwner(plan)
    if plan.bagsEnd == plan.width then return "bags" end
    if plan.microEnd and plan.microEnd + POST_W >= plan.width then return "micro" end
    return "bar"
end

-- The floor's strip u 136 to 176, whole copies stretched to fill: column 136 matches 176 to the stone's own grain (1.8
-- against 0.4 to 1.8 between neighbours), so copies join each other and the sheet unseen. 128 to 208 joined dark to light.
local TILE_U0, SEAM_U = 136, 176
function B.FloorTiles(x, extra)
    local tiles = {}
    if extra <= 0 then return tiles end
    local count = math.max(1, math.floor(extra / (SEAM_U - TILE_U0) + 0.5))
    local w = math.floor(extra / count)
    for i = 1, count do
        local width = i < count and w or extra - w * (count - 1)
        tiles[#tiles + 1] = { x, width, TILE_U0 / 256, SEAM_U / 256 }
        x = x + width
    end
    return tiles
end

-- Era's third sheet ends its floor in a fade to black and a 3 px rim (u 208 on, eram bar): a micro floor of any width
-- ends on that end, its floor from u0 before it; a longer one takes the strip's copies in at u 176. { x, width, u0, u1 }.
local MICRO_END_U = 208
function B.MicroRuns(x, width, u0)
    local runs = {}
    local endW = math.min(width, 256 - MICRO_END_U)
    local floorW = width - endW
    local direct = math.max(0, math.min(floorW, MICRO_END_U - u0))
    local extra = floorW - direct
    if extra > 0 and u0 < SEAM_U then
        runs[1] = { x, SEAM_U - u0, u0 / 256, SEAM_U / 256 }
        local at = x + SEAM_U - u0
        for _, tile in ipairs(B.FloorTiles(at, extra)) do runs[#runs + 1] = tile end
        runs[#runs + 1] = { at + extra, 256 - SEAM_U, SEAM_U / 256, 1 }
        return runs
    end
    if direct > 0 then runs[1] = { x, direct, u0 / 256, (u0 + direct) / 256 } end
    for _, tile in ipairs(B.FloorTiles(x + direct, extra)) do runs[#runs + 1] = tile end
    runs[#runs + 1] = { x + floorW, endW, (256 - endW) / 256, 1 }
    return runs
end

-- The art as runs of the four sheets: { x, width, sheet, u0, u1, owner }; owner (bar, micro, bags, key) is whose Hide Bar
-- Art takes the run.
function B.Segments()
    local plan = CurrentPlan()
    local cut = plan.cut
    local list = {}
    local function Micro(x, width, u0)
        if width <= 0 then return end
        for _, run in ipairs(B.MicroRuns(x, width, u0)) do
            list[#list + 1] = { run[1], run[2], 3, run[3], run[4], "micro" }
        end
    end
    -- A twelve-socket run at x from the sheets' u (bar 1's trim, or past the wall the run before it ends with).
    local function Sockets(x, u)
        if u < 256 then
            list[#list + 1] = { x, 256 - u, 1, u / 256, 1, "bar" }
            list[#list + 1] = { x + 256 - u, 256, 2, 0, 1, "bar" }
        else
            list[#list + 1] = { x, 512 - u, 2, (u - 256) / 256, 1, "bar" }
        end
    end
    if plan.bar2Start and plan.bar2Start < plan.bar1Start then
        -- Bar 2 left of bar 1: its own run trimmed at the left for fewer icons, bar 1's past the shared wall.
        Sockets(0, 512 - ROW_X - plan.bar2W)
        Sockets(plan.bar1Start, cut + plan.bar1Skip)
    else
        Sockets(0, cut)
        if plan.bar2Start then
            -- Bar 2 right of bar 1: the sheets again from past their left wall (bar 1's right wall serves), the second
            -- cut short from its end for fewer icons.
            local second = plan.bar2W - (256 - ROW_X)
            list[#list + 1] = { plan.bar2Start, 256 - ROW_X, 1, ROW_X / 256, 1, "bar" }
            if second > 0 then list[#list + 1] = { plan.bar2Start + 256 - ROW_X, second, 2, 0, second / 256, "bar" } end
        end
    end
    local half = plan.base
    local headless = plan.microFirst and plan.noPages
    if plan.microFirst and not headless then
        local region = plan.microEnd - plan.microStart
        -- Its head through the page number post is bar 1's.
        local head = math.min(region, PAGE_ROOM)
        list[#list + 1] = { half, head, 3, 0, head / 256, "bar" }
        Micro(half + head, region - head, head)
    elseif not plan.microFirst and not plan.noPages then
        local room = plan.pageRoom or (plan.pageEdge and PAGE_POST) or PAGE_ROOM
        list[#list + 1] = { half, room, 3, 0, room / 256, "bar" }
    end
    if plan.bagsStart then
        local bag = B.Bag()
        local x, u0, sheet = plan.bagsStart, 256 - bag.part + plan.bagTrim, bag.sheet
        local s0, s1 = bag.socketU0, bag.socketU1
        local head, unit = s0 - u0, s1 - s0
        local extra = B.BagExtraCells()
        if B.BagsFolded() then
            -- Backpack only: the head, the reagent bag's cell while it stays, then from four cells on (the backpack's
            -- cell and the end).
            local tail, at = s0 + 4 * bag.socket, x + head
            list[#list + 1] = { x, head, sheet, u0 / 256, s0 / 256, "bags" }
            if extra > 0 then
                list[#list + 1] = { at, unit, sheet, s0 / 256, s1 / 256, "bags" }
                at = at + unit
            end
            list[#list + 1] = { at, 256 - tail, sheet, tail / 256, 1, "bags" }
        elseif extra > 0 then
            -- Up to the first socket's far wall, the wall-and-socket unit once per extra cell, then the rest from that wall.
            list[#list + 1] = { x, head, sheet, u0 / 256, s0 / 256, "bags" }
            for i = 1, extra do
                list[#list + 1] = { x + head + (i - 1) * unit, unit, sheet, s0 / 256, s1 / 256, "bags" }
            end
            list[#list + 1] = { x + head + extra * unit, 256 - s0, sheet, s0 / 256, 1, "bags" }
        else
            list[#list + 1] = { x, 256 - u0, sheet, u0 / 256, 1, "bags" }
        end
    end
    if plan.microStart and (not plan.microFirst or headless) then
        -- Standing second: the third sheet from past its page-arrow head.
        Micro(plan.microStart, plan.microEnd - plan.microStart, MICRO_LEAD - MICRO_SECOND_LEAD)
    end
    if plan.tailStart then
        -- The key slot from past the shared post (23) is the key ring's own run, as the bags' sockets are theirs.
        local split = (plan.tailSlot and (B.TailParts())) and 23 or plan.tailU0
        if split > plan.tailU0 then
            list[#list + 1] = { plan.tailStart, split - plan.tailU0, 5, plan.tailU0 / 256, split / 256, "bar" }
        end
        list[#list + 1] = { plan.tailStart + split - plan.tailU0, plan.tailU1 - split, 5, split / 256, plan.tailU1 / 256,
            plan.tailSlot and "key" or "bar" }
    end
    -- Right end: with the bags off, the last run was a cut through a sheet and looked sliced; the moved groups'
    -- end post closes it, over the bag part's same pixels where present. A last piece with its own post needs none.
    if not plan.ownEnd then
        list[#list + 1] = { plan.width - POST_W, POST_W, 4, POST_U / 256, (POST_U + POST_W) / 256, EndOwner(plan) }
    end
    return list
end

-- Bar 1's centred home: its bottom-left from the screen's bottom-centre.
function B.HomeSpot(band)
    return ((ns.db.barOffsetX or 0) - ArtWidth() / 2 + CurrentPlan().bar1X) * band, ((ns.db.barOffsetY or 0) + ROW_Y) * band
end

-- Whether a frame was dropped near a band spot (band px from its bottom-left), measured on screen where scales agree; plus the distance.
function B.NearBandSlot(frame, bandX, bandY, corner)
    local art = B.art
    if not frame or not art then return false end
    local artScale, scale = art:GetEffectiveScale(), frame:GetEffectiveScale()
    local left, bottom = art:GetLeft(), art:GetBottom()
    if not artScale or not scale or not left or not bottom then return false end
    local wantX, wantY = (left + bandX) * artScale, (bottom + bandY) * artScale
    local hasX = corner == "BOTTOMRIGHT" and frame:GetRight() or frame:GetLeft()
    local hasY = frame:GetBottom()
    if not hasX or not hasY then return false end
    local reach = SNAP_PX * UIParent:GetEffectiveScale()
    local dx, dy = math.abs(hasX * scale - wantX), math.abs(hasY * scale - wantY)
    return dx < reach and dy < reach, dx + dy
end

-- Where a held group would land if dropped now: nil = off the band, else whether bags stand first. Judged on screen:
-- on the band when level with it past bar 1's slots; the side is which half of the stretch past bar 1 its centre is over
-- (both groups counted, so the line holds while the preview swaps them). A shown side holds until clearly past the line.
local function DropPlace(which, frame, current)
    local art = B.art
    if OneBar() or not frame or not art then return nil end
    local artScale, scale = art:GetEffectiveScale(), frame:GetEffectiveScale()
    local aL, aR, aB = art:GetLeft(), art:GetRight(), art:GetBottom()
    local fL, fR, fB = frame:GetLeft(), frame:GetRight(), frame:GetBottom()
    if not (artScale and scale and aL and aR and aB and fL and fR and fB) then return nil end
    local unit = UIParent:GetEffectiveScale()
    local reach = SNAP_PX * unit
    local middle = (fL + fR) / 2 * scale
    if math.abs(fB * scale - aB * artScale) > reach then
        return nil
    end
    local barEnd = (aL + CurrentPlan().base) * artScale
    if middle < barEnd - reach or middle > aR * artScale + 2 * reach then
        return nil
    end
    local otherOn
    if which == "micro" then otherOn = shape.bagsReal ~= false else otherOn = shape.microReal ~= false end
    if not otherOn then return false end
    local both = BandPlan(true, true, false, shape.region, shape.bar2W, shape.bar2Left)
    local left = aL
    if not ns.barMoved then left = (aL + aR) / 2 - both.width / 2 end
    local line = (left + (both.base + both.width) / 2) * artScale
    local rel = middle - line
    -- Right half: micro second, so bags first; reversed for the bags.
    if which == "bags" then rel = -rel end
    local margin = 16 * unit
    local answer
    if current == true then answer = rel > -margin
    elseif current == false then answer = rel > margin
    else answer = rel > 0 end
    return answer
end
B.DropPlace = DropPlace

-- Re-lay the preview for a group in hand ("micro" or "bags") when it changes; true when it did.
function B.PreviewDrop(which, frame)
    local preview = B.dragPreview
    local place = DropPlace(which, frame, preview.bagsFirst)
    local near = place ~= nil
    if preview[which] == near and not (near and preview.bagsFirst ~= place) then return false end
    preview[which] = near
    -- Not "near and place or nil": place is false for one order and that idiom turns it into nil (no preview).
    if near then preview.bagsFirst = place else preview.bagsFirst = nil end
    ns.QueueApply()
    return true
end
