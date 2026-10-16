local _, ns = ...
if ns.LOCALE ~= "deDE" then return end
local L = ns.L

-- Our window mover and its edit mode window (UI/), the one bag's reagent slots and the bag bar pick, beside Locales/deDE.lua.
L["UI_UNLOCKED_DRAG_THE_MAP_BY"] = "Entsperrt: Zieh die Karte außerhalb des Kampfes an ihrer Titelleiste. Klicken zum Sperren."
L["UI_LOCKED_CLICK_TO_DRAG_THE"] = "Gesperrt. Klicken, um die Karte außerhalb des Kampfes an ihrer Titelleiste überallhin zu ziehen."
L["UI_UNLOCKED_DRAG_THE_WINDOW_BY"] = "Entsperrt: Zieh das Fenster außerhalb des Kampfes an seiner Titelleiste. Klicken zum Sperren."
L["UI_LOCKED_CLICK_TO_DRAG_THE_WINDOW"] = "Gesperrt. Klicken, um das Fenster außerhalb des Kampfes an seiner Titelleiste überallhin zu ziehen."
L["UI_WITH_QUEST_LOG"] = "Mit Questlog"
L["UI_MAP_ONLY"] = "Nur Karte"
L["UI_CLASSICUI_FOREVER_WINDOWS"] = "ClassicUI Forever Fenster"
L["UI_CHECK_THE_WINDOWS_TO_MOVE"] = "Markiere die Fenster zum Verschieben. Zieh das Feld eines Fensters, um es zu platzieren; klick das Feld, um seine Größe zu ändern, es jederzeit verschiebbar zu machen oder es zurückzusetzen."
L["UI_IF_YOU_EXIT_NOW_YOU"] = "Wenn du jetzt beendest, gehen alle ungespeicherten Änderungen verloren.\nWie möchtest du fortfahren?"
L["UI_SWITCH_TO_MOVING_THE_CLASSICUI"] = "Zum Verschieben der Fenster von ClassicUI Forever wechseln (Charakter, Berufe, Talente, Questlog, Soziales, Karte): Wähle die aus, die du verschieben und in der Größe ändern willst."

-- Bag windows: the reagent bag in the one bag (Windows/BagReagent.lua)
L["OPT_reagentBagCombined"] = "Reagenzientasche in der einen Tasche"
L["OPT_reagentBagCombined_TIP"] = "Die Plätze der Reagenzientasche stehen im Fenster der einen Tasche statt in einem eigenen Fenster."
L["OPT_reagentBagTint"] = "Reagenzienplätze tönen"
L["OPT_reagentBagTint_TIP"] = "Die Plätze der Reagenzientasche in der einen Tasche sind grün getönt, damit man sie unterscheidet."
L["OPT_reagentSlotsFirst"] = "Reagenzienplätze: zuerst"
L["OPT_reagentSlotsFirst_TIP"] = "Die Plätze der Reagenzientasche kommen in der einen Tasche zuerst, vor denen des Rucksacks."
L["OPT_reagentSlotsLast"] = "Reagenzienplätze: zuletzt"
L["OPT_reagentSlotsLast_TIP"] = "Die Plätze der Reagenzientasche kommen in der einen Tasche zuletzt, nach denen der letzten Tasche."
L["OPT_reagentSlotsPlace_TIP"] = "Wo die Plätze der Reagenzientasche in der einen Tasche stehen."

-- Options foot: every window back to its own size and spot (UI/WindowLocks.lua)
L["OPTWIN_RESET_WINDOWS"] = "Fenster zurücksetzen"
L["OPTWIN_PUTS_EVERY_WINDOW_BACK"] = "Setzt jedes Fenster auf seine eigene Größe und Stelle zurück, als wäre es nie verschoben oder vergrößert worden. Sperren bleiben, wie sie sind."
L["OPTWIN_RESET_WINDOWS_CONFIRM"] = "Jedes Fenster auf seine eigene Größe und Stelle zurücksetzen?"

-- The bag bar pick (Bar/BandBagsShow.lua) and its fold arrow.
L["OPT_showBags"] = "Taschenleiste: angezeigt"
L["OPT_hideBagsAlways"] = "Taschenleiste: ausgeblendet"
L["OPT_hideBagsOpen"] = "Taschenleiste: bis Taschen offen sind"
L["OPT_hideBagsHover"] = "Taschenleiste: beim Überfahren"
L["OPT_bagsBackpackOnly"] = "Taschenleiste: nur Rucksack"
L["BAGS_SHOW_BAGS"] = "Taschen anzeigen"
L["BAGS_HIDE_BAGS"] = "Taschen ausblenden"
L["OPT_bagsShow_TIP"] = "Die Taschentasten angezeigt, ausgeblendet, nur solange ein Taschenfenster offen ist, nur solange die Maus über ihrem Platz ist, oder hinter einem Pfeil auf den Rucksack eingeklappt. Auf der klassischen Leiste rückt die Leiste über ausgeblendeten oder eingeklappten Taschen zusammen, sonst verblassen ihre Fassungen mit ihnen."

-- Options/Toggles.lua: where a nameplate's crowd control icons sit
L["OPT_plateCCBeside"] = "Kontrolleffekte: hinter der Stufe"
L["OPT_plateCCBeside_TIP"] = "Symbole für Betäubung, Bewegungsunfähigkeit und Furcht gleich hinter der Stufe, frei von einem Elitedrachen."
L["OPT_plateCCAbove"] = "Kontrolleffekte: bei den Schwächungen"
L["OPT_plateCCAbove_TIP"] = "Symbole für Betäubung, Bewegungsunfähigkeit und Furcht am Ende der Schwächungsreihe über dem Namen."
L["OPT_plateCCLeft"] = "Kontrolleffekte: links der Leiste"
L["OPT_plateCCLeft_TIP"] = "Symbole für Betäubung, Bewegungsunfähigkeit und Furcht links der Gesundheitsleiste, hinter einer Schlachtzugsmarkierung; ein zweites kommt links dazu."
L["OPT_plateCC_TIP"] = "Wo eine Namensplakette ihre Symbole für Kontrolleffekte zeigt."

-- Options/Toggles.lua: how the player frame's glow meets the druid mana bar
L["OPT_druidManaGlowAround"] = "Leuchten: um die Manaleiste"
L["OPT_druidManaGlowAround_TIP"] = "Das Leuchten des Fensters um den Rand der Manaleiste herumgeführt."
L["OPT_druidManaGlowBehind"] = "Leuchten: hinter der Manaleiste"
L["OPT_druidManaGlowBehind_TIP"] = "Die Manaleiste vor dem Leuchten des Fensters, wie in Wrath."
L["OPT_druidManaGlowOver"] = "Leuchten: über der Manaleiste"
L["OPT_druidManaGlowOver_TIP"] = "Das Leuchten des Fensters quer über den oberen Rand der Manaleiste."
L["OPT_druidManaGlow_TIP"] = "Wie das Bedrohungs- und Kampfleuchten des Fensters auf die Manaleiste trifft."

-- Options/OptionsWindow.lua: the game's settings' ClassicUI Forever entry
L["OPTWIN_SETTINGS_HOME"] = "Oben alle Optionen durchsuchen oder links unter ClassicUI Forever eine Seite wählen."
L["OPT_themeIgnoreElitePlayer"] = "Fenster: Spieler"
L["OPT_themeIgnoreEliteTarget"] = "Fenster: Ziel"
L["OPT_themeIgnoreEliteFocus"] = "Fenster: Fokus"
L["OPT_themeIgnoreEliteFrames_TIP"] = "Die Fenster, deren Drache sein eigenes Gold oder Silber behält; ein nicht markiertes nimmt das Design an."
