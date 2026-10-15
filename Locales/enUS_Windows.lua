local _, ns = ...
local L = ns.L

-- Our window mover and its edit mode window (UI/), the one bag's reagent slots and the bag bar pick, beside Locales/enUS.lua.
-- UI/WindowHandles.lua
L["UI_CHARACTER"] = "Character"
L["UI_PROFESSIONS"] = "Professions"
L["UI_TALENTS"] = "Talents"
L["UI_QUEST_LOG"] = "Quest log"
L["UI_QUEST_WATCH"] = "Quest watch"
L["UI_SOCIAL"] = "Social"
L["UI_QUEST_GIVER"] = "Quest giver"
L["UI_GOSSIP"] = "Gossip"
L["UI_WORLD_MAP"] = "World map"
L["UI_CALENDAR"] = "Calendar"
L["UI_MINIMAP"] = "Minimap"
L["UI_SPELLBOOK"] = "Spellbook"
L["UI_ZONE_NAME"] = "Zone name"
L["UI_TRACKING"] = "Tracking"
L["UI_MAIL"] = "Mail"
L["UI_ZOOM_IN"] = "Zoom in"
L["UI_ZOOM_OUT"] = "Zoom out"
L["UI_CLOCK"] = "Clock"
L["UI_DAY_AND_NIGHT"] = "Day and night"
L["UI_COORDINATES"] = "Coordinates"
L["UI_SHOW"] = "Show"
L["UI_GRYPHON_LEFT"] = "Left gryphon"
L["UI_GRYPHON_RIGHT"] = "Right gryphon"
L["UI_MODE"] = "Mode"
L["UI_MAP_LOCK"] = "Map lock"
L["UI_WINDOW_LOCK"] = "Window lock"
L["UI_RESET_POSITION"] = "Reset position"
L["UI_RESET_POSITION_TIP"] = "Back to where the window opens by default."
L["UI_RESIZE"] = "Resize"
L["UI_RESIZE_TIP"] = "Drag to size the window. Right-click: its default size."
L["UI_FADE_WHILE_MOVING"] = "Fade while moving"
L["UI_THE_MAP_DIMS_WHILE_YOU"] = "The map dims while you move. The same setting as in the options (the game's own)."
L["UI_MOVABLE_ANYTIME"] = "Movable anytime"
L["UI_DRAG_THE_WINDOW_BY_ITS"] = "Drag the window by its title bar whenever it is open out of combat, not only here. Off, it stays where it is placed."
L["UI_MOVABLE_ANYTIME_BY_ITS_TITLE"] = "Movable anytime, by its title bar"

-- UI/WindowsEditMode.lua
L["UI_BACK_TO_REGULAR_EDIT_MODE"] = "Back to regular edit mode"
L["UI_THE_HUD_EDIT_MODE_SAVE"] = "The HUD Edit Mode. Save or revert window changes first."
L["UI_WINDOWS"] = "Windows"

-- UI/WindowHandles.lua
L["UI_UNLOCKED_DRAG_THE_MAP_BY"] = "Unlocked: drag the map by its title bar, out of combat. Click to lock it."
L["UI_LOCKED_CLICK_TO_DRAG_THE"] = "Locked. Click to drag the map anywhere by its title bar, out of combat."
L["UI_UNLOCKED_DRAG_THE_WINDOW_BY"] = "Unlocked: drag the window by its title bar, out of combat. Click to lock it."
L["UI_LOCKED_CLICK_TO_DRAG_THE_WINDOW"] = "Locked. Click to drag the window anywhere by its title bar, out of combat."
L["UI_WITH_QUEST_LOG"] = "With quest log"
L["UI_MAP_ONLY"] = "Map only"

-- UI/WindowsEditMode.lua
L["UI_CLASSICUI_FOREVER_WINDOWS"] = "ClassicUI Forever Windows"
L["UI_CHECK_THE_WINDOWS_TO_MOVE"] = "Check the windows to move. Drag a window's box to place it; click the box to size it, make it movable anytime or reset it."
L["UI_IF_YOU_EXIT_NOW_YOU"] = "If you exit now you will lose any unsaved changes.\nHow would you like to proceed?"
L["UI_SWITCH_TO_MOVING_THE_CLASSICUI"] = "Switch to moving the ClassicUI Forever windows (character, professions, talents, quest log, social, map): pick the ones to move and size."

-- Bag windows: the reagent bag in the one bag (Windows/BagReagent.lua)
L["OPT_reagentBagCombined"] = "Reagent bag in the one bag"
L["OPT_reagentBagCombined_TIP"] = "The reagent bag's slots join the one bag window instead of a window of their own."
L["OPT_reagentBagTint"] = "Tint reagent slots"
L["OPT_reagentBagTint_TIP"] = "The reagent bag's slots in the one bag are tinted green, to tell them apart."
L["OPT_reagentSlotsFirst"] = "Reagent slots: first"
L["OPT_reagentSlotsFirst_TIP"] = "The reagent bag's slots come first in the one bag, before the backpack's."
L["OPT_reagentSlotsLast"] = "Reagent slots: last"
L["OPT_reagentSlotsLast_TIP"] = "The reagent bag's slots come last in the one bag, after your last bag's."
L["OPT_reagentSlotsPlace_TIP"] = "Where the reagent bag's slots stand in the one bag."

-- Options foot: every window back to its own size and spot (UI/WindowLocks.lua)
L["OPTWIN_RESET_WINDOWS"] = "Reset windows"
L["OPTWIN_PUTS_EVERY_WINDOW_BACK"] = "Puts every window back to its own size and spot, as if never moved or sized. Locks stay as they are."
L["OPTWIN_RESET_WINDOWS_CONFIRM"] = "Put every window back to its own size and spot?"

-- The bag bar pick (Bar/BandBagsShow.lua) and its fold arrow.
L["OPT_showBags"] = "Bag bar: shown"
L["OPT_hideBagsAlways"] = "Bag bar: hidden"
L["OPT_hideBagsOpen"] = "Bag bar: until bags are open"
L["OPT_hideBagsHover"] = "Bag bar: on hover"
L["OPT_bagsBackpackOnly"] = "Bag bar: backpack only"
L["BAGS_SHOW_BAGS"] = "Show the bags"
L["BAGS_HIDE_BAGS"] = "Hide the bags"
L["OPT_bagsShow_TIP"] = "The bag buttons shown, hidden, shown only while a bag window is open, only while the mouse is over their spot, or folded to the backpack behind an arrow. On the classic bar the bar closes up over hidden or folded bags and their sockets fade with them otherwise."
