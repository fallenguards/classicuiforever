local _, ns = ...
if ns.LOCALE ~= "frFR" then return end
local L = ns.L

-- Our window mover and its edit mode window (UI/), the one bag's reagent slots and the bag bar pick, beside Locales/frFR.lua.
L["UI_UNLOCKED_DRAG_THE_MAP_BY"] = "Déverrouillée : faites glisser la carte par sa barre de titre, hors combat. Cliquez pour la verrouiller."
L["UI_LOCKED_CLICK_TO_DRAG_THE"] = "Verrouillée. Cliquez pour faire glisser la carte n'importe où par sa barre de titre, hors combat."
L["UI_UNLOCKED_DRAG_THE_WINDOW_BY"] = "Déverrouillée : faites glisser la fenêtre par sa barre de titre, hors combat. Cliquez pour la verrouiller."
L["UI_LOCKED_CLICK_TO_DRAG_THE_WINDOW"] = "Verrouillée. Cliquez pour faire glisser la fenêtre n'importe où par sa barre de titre, hors combat."
L["UI_WITH_QUEST_LOG"] = "Avec le journal de quêtes"
L["UI_MAP_ONLY"] = "Carte seule"
L["UI_CLASSICUI_FOREVER_WINDOWS"] = "Fenêtres ClassicUI Forever"
L["UI_CHECK_THE_WINDOWS_TO_MOVE"] = "Cochez les fenêtres à déplacer. Faites glisser la case d'une fenêtre pour la placer ; cliquez sur la case pour la redimensionner, la rendre déplaçable à tout moment ou la réinitialiser."
L["UI_IF_YOU_EXIT_NOW_YOU"] = "Si vous quittez maintenant, vous perdrez tous les changements non enregistrés.\nQue voulez-vous faire ?"
L["UI_SWITCH_TO_MOVING_THE_CLASSICUI"] = "Passer au déplacement des fenêtres ClassicUI Forever (personnage, métiers, talents, journal de quêtes, social, carte) : choisissez celles à déplacer et à redimensionner."

-- Bag windows: the reagent bag in the one bag (Windows/BagReagent.lua)
L["OPT_reagentBagCombined"] = "Sac de composants dans le sac unique"
L["OPT_reagentBagCombined_TIP"] = "Les emplacements du sac de composants se placent dans la fenêtre du sac unique au lieu d'une fenêtre à part."
L["OPT_reagentBagTint"] = "Teinter les emplacements de composants"
L["OPT_reagentBagTint_TIP"] = "Les emplacements du sac de composants dans le sac unique sont teintés de vert, pour les distinguer."
L["OPT_reagentSlotsFirst"] = "Emplacements de composants : en premier"
L["OPT_reagentSlotsFirst_TIP"] = "Les emplacements du sac de composants viennent en premier dans le sac unique, avant ceux du sac à dos."
L["OPT_reagentSlotsLast"] = "Emplacements de composants : en dernier"
L["OPT_reagentSlotsLast_TIP"] = "Les emplacements du sac de composants viennent en dernier dans le sac unique, après ceux de votre dernier sac."
L["OPT_reagentSlotsPlace_TIP"] = "Où se placent les emplacements du sac de composants dans le sac unique."

-- Options foot: every window back to its own size and spot (UI/WindowLocks.lua)
L["OPTWIN_RESET_WINDOWS"] = "Rétablir fenêtres"
L["OPTWIN_PUTS_EVERY_WINDOW_BACK"] = "Remet chaque fenêtre à sa taille et à sa place d'origine, comme si elle n'avait jamais été déplacée ni redimensionnée. Les verrous restent tels quels."
L["OPTWIN_RESET_WINDOWS_CONFIRM"] = "Remettre chaque fenêtre à sa taille et à sa place d'origine ?"

-- The bag bar pick (Bar/BandBagsShow.lua) and its fold arrow.
L["OPT_showBags"] = "Barre des sacs : affichée"
L["OPT_hideBagsAlways"] = "Barre des sacs : masquée"
L["OPT_hideBagsOpen"] = "Barre des sacs : jusqu'à l'ouverture des sacs"
L["OPT_hideBagsHover"] = "Barre des sacs : au survol"
L["OPT_bagsBackpackOnly"] = "Barre des sacs : sac à dos seul"
L["BAGS_SHOW_BAGS"] = "Afficher les sacs"
L["BAGS_HIDE_BAGS"] = "Masquer les sacs"
L["OPT_bagsShow_TIP"] = "Les boutons de sac affichés, masqués, affichés seulement quand une fenêtre de sac est ouverte, seulement quand la souris survole leur emplacement, ou repliés sur le sac à dos derrière une flèche. Sur la barre classique, la barre se resserre sur les sacs masqués ou repliés et sinon leurs logements s'estompent avec eux."

-- Options/Toggles.lua: where a nameplate's crowd control icons sit
L["OPT_plateCCBeside"] = "Contrôle : après le niveau"
L["OPT_plateCCBeside_TIP"] = "Les icônes d'étourdissement, d'immobilisation et de peur juste après le niveau, à l'écart d'un dragon d'élite."
L["OPT_plateCCAbove"] = "Contrôle : avec les affaiblissements"
L["OPT_plateCCAbove_TIP"] = "Les icônes d'étourdissement, d'immobilisation et de peur au bout de la rangée d'affaiblissements au-dessus du nom."
L["OPT_plateCCLeft"] = "Contrôle : à gauche de la barre"
L["OPT_plateCCLeft_TIP"] = "Les icônes d'étourdissement, d'immobilisation et de peur à gauche de la barre de vie, après un marqueur de raid ; une deuxième s'ajoute à gauche."
L["OPT_plateCC_TIP"] = "Où une barre de nom affiche ses icônes de contrôle."
