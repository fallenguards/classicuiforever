local _, ns = ...
if ns.LOCALE ~= "itIT" then return end
local L = ns.L

-- Our window mover and its edit mode window (UI/), the one bag's reagent slots and the bag bar pick, beside Locales/itIT.lua.
L["UI_UNLOCKED_DRAG_THE_MAP_BY"] = "Sbloccata: trascina la mappa dalla barra del titolo, fuori dal combattimento. Clic per bloccarla."
L["UI_LOCKED_CLICK_TO_DRAG_THE"] = "Bloccata. Clic per trascinare la mappa ovunque dalla barra del titolo, fuori dal combattimento."
L["UI_UNLOCKED_DRAG_THE_WINDOW_BY"] = "Sbloccata: trascina la finestra dalla barra del titolo, fuori dal combattimento. Clic per bloccarla."
L["UI_LOCKED_CLICK_TO_DRAG_THE_WINDOW"] = "Bloccata. Clic per trascinare la finestra ovunque dalla barra del titolo, fuori dal combattimento."
L["UI_WITH_QUEST_LOG"] = "Con il registro delle missioni"
L["UI_MAP_ONLY"] = "Solo la mappa"
L["UI_CLASSICUI_FOREVER_WINDOWS"] = "Finestre di ClassicUI Forever"
L["UI_CHECK_THE_WINDOWS_TO_MOVE"] = "Spunta le finestre da spostare. Trascina il riquadro di una finestra per posizionarla; clic sul riquadro per ridimensionarla, renderla spostabile in qualsiasi momento o ripristinarla."
L["UI_IF_YOU_EXIT_NOW_YOU"] = "Se esci ora perderai tutte le modifiche non salvate.\nCome vuoi procedere?"
L["UI_SWITCH_TO_MOVING_THE_CLASSICUI"] = "Passa allo spostamento delle finestre di ClassicUI Forever (personaggio, professioni, talenti, registro delle missioni, social, mappa): scegli quelle da spostare e ridimensionare."

-- Bag windows: the reagent bag in the one bag (Windows/BagReagent.lua)
L["OPT_reagentBagCombined"] = "Borsa dei reagenti nella borsa unica"
L["OPT_reagentBagCombined_TIP"] = "Le caselle della borsa dei reagenti stanno nella finestra della borsa unica invece che in una finestra propria."
L["OPT_reagentBagTint"] = "Colora le caselle dei reagenti"
L["OPT_reagentBagTint_TIP"] = "Le caselle della borsa dei reagenti nella borsa unica sono colorate di verde, per distinguerle."
L["OPT_reagentSlotsFirst"] = "Caselle dei reagenti: prima"
L["OPT_reagentSlotsFirst_TIP"] = "Le caselle della borsa dei reagenti vengono per prime nella borsa unica, prima di quelle dello zaino."
L["OPT_reagentSlotsLast"] = "Caselle dei reagenti: in fondo"
L["OPT_reagentSlotsLast_TIP"] = "Le caselle della borsa dei reagenti vengono per ultime nella borsa unica, dopo quelle della tua ultima borsa."
L["OPT_reagentSlotsPlace_TIP"] = "Dove stanno le caselle della borsa dei reagenti nella borsa unica."

-- Options foot: every window back to its own size and spot (UI/WindowLocks.lua)
L["OPTWIN_RESET_WINDOWS"] = "Ripristina finestre"
L["OPTWIN_PUTS_EVERY_WINDOW_BACK"] = "Riporta ogni finestra alla sua dimensione e al suo posto, come se non fosse mai stata spostata o ridimensionata. I blocchi restano come sono."
L["OPTWIN_RESET_WINDOWS_CONFIRM"] = "Riportare ogni finestra alla sua dimensione e al suo posto?"

-- The bag bar pick (Bar/BandBagsShow.lua) and its fold arrow.
L["OPT_showBags"] = "Barra delle borse: visibile"
L["OPT_hideBagsAlways"] = "Barra delle borse: nascosta"
L["OPT_hideBagsOpen"] = "Barra delle borse: finché le borse sono aperte"
L["OPT_hideBagsHover"] = "Barra delle borse: al passaggio"
L["OPT_bagsBackpackOnly"] = "Barra delle borse: solo lo zaino"
L["BAGS_SHOW_BAGS"] = "Mostra le borse"
L["BAGS_HIDE_BAGS"] = "Nascondi le borse"
L["OPT_bagsShow_TIP"] = "I pulsanti delle borse visibili, nascosti, visibili solo mentre una finestra delle borse è aperta, solo mentre il mouse è sul loro posto, o ripiegati sullo zaino dietro una freccia. Sulla barra classica la barra si stringe sulle borse nascoste o ripiegate, altrimenti i loro alloggi sbiadiscono con loro."

-- Options/Toggles.lua: where a nameplate's crowd control icons sit
L["OPT_plateCCBeside"] = "Controllo: dopo il livello"
L["OPT_plateCCBeside_TIP"] = "Le icone di stordimento, immobilizzazione e paura subito dopo il livello, lontano da un drago élite."
L["OPT_plateCCAbove"] = "Controllo: con le penalità"
L["OPT_plateCCAbove_TIP"] = "Le icone di stordimento, immobilizzazione e paura in fondo alla fila delle penalità sopra il nome."
L["OPT_plateCCLeft"] = "Controllo: a sinistra della barra"
L["OPT_plateCCLeft_TIP"] = "Le icone di stordimento, immobilizzazione e paura a sinistra della barra della salute, dopo un segno di incursione; una seconda si aggiunge a sinistra."
L["OPT_plateCC_TIP"] = "Dove una targhetta mostra le sue icone di controllo."
