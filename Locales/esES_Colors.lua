local _, ns = ...
if ns.LOCALE ~= "esES" and ns.LOCALE ~= "esMX" then return end
local L = ns.L

-- UI/Colors.lua: health and bar colors, unit frame bar textures; beside Locales/esES.lua.
L["UI_HEALTH_GREEN"] = "Verde de salud"
L["UI_BAR_CLASSIC"] = "Clásica"
L["UI_BAR_RAID"] = "Marcos de banda"
L["UI_BAR_SOLID"] = "Sólida"
L["UI_BAR_SKILLS"] = "Barra de habilidad"
L["UI_FAILED_RED"] = "Rojo de fallo"
L["UI_CAST_GOLD"] = "Oro de lanzamiento"
L["UI_DARK_GOLD"] = "Oro oscuro"
L["UI_FOCUS_ORANGE"] = "Naranja de enfoque"
L["UI_ENERGY_YELLOW"] = "Amarillo de energía"
L["UI_MANA_BLUE"] = "Azul de maná"
L["UI_BY_REACTION"] = "Según reacción"
L["UI_BY_REACTION_TIP"] = "Amarillo mientras el enemigo es neutral, rojo cuando es hostil o lucha contigo."
