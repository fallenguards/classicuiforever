local _, ns = ...
if ns.LOCALE ~= "esES" then return end
local L = ns.L

-- Our window mover and its edit mode window (UI/), the one bag's reagent slots and the bag bar pick, beside Locales/esES.lua.
L["UI_UNLOCKED_DRAG_THE_MAP_BY"] = "Desbloqueado: arrastra el mapa por su barra de título fuera de combate. Haz clic para bloquearlo."
L["UI_LOCKED_CLICK_TO_DRAG_THE"] = "Bloqueado. Haz clic para arrastrar el mapa a cualquier sitio por su barra de título fuera de combate."
L["UI_UNLOCKED_DRAG_THE_WINDOW_BY"] = "Desbloqueada: arrastra la ventana por su barra de título fuera de combate. Haz clic para bloquearla."
L["UI_LOCKED_CLICK_TO_DRAG_THE_WINDOW"] = "Bloqueada. Haz clic para arrastrar la ventana a cualquier sitio por su barra de título fuera de combate."
L["UI_WITH_QUEST_LOG"] = "Con el registro de misiones"
L["UI_MAP_ONLY"] = "Solo el mapa"
L["UI_CLASSICUI_FOREVER_WINDOWS"] = "Ventanas de ClassicUI Forever"
L["UI_CHECK_THE_WINDOWS_TO_MOVE"] = "Marca las ventanas que quieres mover. Arrastra el recuadro de una ventana para colocarla; haz clic en el recuadro para cambiar su tamaño, hacerla movible en cualquier momento o restablecerla."
L["UI_IF_YOU_EXIT_NOW_YOU"] = "Si sales ahora perderás los cambios sin guardar.\n¿Cómo quieres continuar?"
L["UI_SWITCH_TO_MOVING_THE_CLASSICUI"] = "Pasa a mover las ventanas de ClassicUI Forever (personaje, profesiones, talentos, registro de misiones, social, mapa): elige las que quieres mover y redimensionar."

-- Bag windows: the reagent bag in the one bag (Windows/BagReagent.lua)
L["OPT_reagentBagCombined"] = "Bolsa de componentes en la bolsa única"
L["OPT_reagentBagCombined_TIP"] = "Las casillas de la bolsa de componentes van en la ventana de la bolsa única en vez de en una ventana propia."
L["OPT_reagentBagTint"] = "Teñir casillas de componentes"
L["OPT_reagentBagTint_TIP"] = "Las casillas de la bolsa de componentes en la bolsa única se tiñen de verde para distinguirlas."
L["OPT_reagentSlotsFirst"] = "Casillas de componentes: primero"
L["OPT_reagentSlotsFirst_TIP"] = "Las casillas de la bolsa de componentes van primero en la bolsa única, antes de las de la mochila."
L["OPT_reagentSlotsLast"] = "Casillas de componentes: al final"
L["OPT_reagentSlotsLast_TIP"] = "Las casillas de la bolsa de componentes van al final de la bolsa única, después de las de tu última bolsa."
L["OPT_reagentSlotsPlace_TIP"] = "Dónde van las casillas de la bolsa de componentes en la bolsa única."

-- Options foot: every window back to its own size and spot (UI/WindowLocks.lua)
L["OPTWIN_RESET_WINDOWS"] = "Restablecer ventanas"
L["OPTWIN_PUTS_EVERY_WINDOW_BACK"] = "Devuelve cada ventana a su tamaño y lugar propios, como si nunca se hubiera movido ni cambiado de tamaño. Los bloqueos se quedan como están."
L["OPTWIN_RESET_WINDOWS_CONFIRM"] = "¿Devolver cada ventana a su tamaño y lugar propios?"

-- The bag bar pick (Bar/BandBagsShow.lua) and its fold arrow.
L["OPT_showBags"] = "Barra de bolsas: visible"
L["OPT_hideBagsAlways"] = "Barra de bolsas: oculta"
L["OPT_hideBagsOpen"] = "Barra de bolsas: hasta abrir las bolsas"
L["OPT_hideBagsHover"] = "Barra de bolsas: al pasar el ratón"
L["OPT_bagsBackpackOnly"] = "Barra de bolsas: solo la mochila"
L["BAGS_SHOW_BAGS"] = "Mostrar las bolsas"
L["BAGS_HIDE_BAGS"] = "Ocultar las bolsas"
L["OPT_bagsShow_TIP"] = "Los botones de bolsa visibles, ocultos, visibles solo mientras una ventana de bolsa está abierta, solo mientras el ratón está sobre su sitio, o plegados en la mochila tras una flecha. En la barra clásica, la barra se cierra sobre las bolsas ocultas o plegadas y si no sus huecos se desvanecen con ellas."
