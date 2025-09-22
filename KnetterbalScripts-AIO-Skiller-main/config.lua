


-- Main skill tab
SM:AddTab("Skill")
SM:Dropdown("Skill:", "selectedSkill", {"FLETCHING", "COOKING", "FIREMAKING","CRAFTING", "DIVINATION","HERBLORE","OTHER"}, "FLETCHING")

-- Fletching tab 
SM:AddTab("Fletching")
SM:Dropdown("Sub Skill", "subSkill", {"NONE", "FLETCH", "STRING", "HEADLESS", "ARROWS"}, "NONE")
SM:Dropdown("Log Type", "logType", {"NONE", "NORMAL", "OAK", "WILLOW", "MAPLE", "YEW", "MAGIC"}, "NONE")
SM:Dropdown("Arrowhead Type", "arrowheadType", {"NONE", "BRONZE", "IRON", "STEEL", "MITHRIL", "ADAMANT", "RUNE", "DRAGON", "BROAD"}, "NONE")
SM:Dropdown("unf shortbows", "bowMaterial1", {"NONE", "NORMAL", "OAK", "WILLOW", "MAPLE", "YEW", "MAGIC"}, "NONE")
SM:Dropdown("unf longbows", "bowMaterial2", {"NONE", "NORMAL", "OAK", "WILLOW", "MAPLE", "YEW", "MAGIC"}, "NONE")

-- Cooking tab
SM:AddTab("Cooking")
SM:Dropdown("Fish Type", "fishType", {"NONE", "SHRIMP", "CRAYFISH", "SARDINE", "HERRING", "ANCHOVIES", "MACKEREL", "TROUT", "COD", "PIKE", "SALMON", "SLIMY EEL", "RAINBOW FISH", "TUNA", "KARAMBWAN", "CAVE EEL", "LOBSTER", "BASS", "SWORDFISH", "MONKFISH", "DESERT SOLE", "CATFISH", "BELTFISH", "SHARK", "SEA TURTLE", "MANTA RAY", "GREAT WHITE SHARK", "CAVEFISH", "ROCKTAIL", "TIGER SHARK", "SAILFISH"}, "NONE")

-- Firemaking tab
SM:AddTab("Firemaking")
SM:Dropdown("Log Type", "logType", {"NONE", "NORMAL", "OAK", "WILLOW", "MAPLE", "YEW", "MAGIC"}, "NONE")

-- Crafting tab
SM:AddTab("Crafting")
SM:Dropdown("Sub Skill", "subSkill2", {"NONE", "CUT", "GLASS","FLASKS","ARMOR"}, "NONE")
SM:Dropdown("Sandstone", "selectedSandstone", {"NONE", "RED", "CRYSTAL"}, "NONE")
SM:Dropdown("glass", "selectedGlass", {"NONE", "ROBUST", "CRYSTAL"}, "NONE")
SM:Dropdown("Uncut gem", "uncut", {"NONE", "SAPPHIRE", "EMERALD", "RUBY", "DIAMOND", "DRAGONSTONE", "OPAL", "JADE", "TOPAZ"}, "NONE")
SM:Dropdown("Leather", "selectedLeather", {"NONE", "LEATHER", "HARDLEATHER", "SPIDERSILK", "GREEN", "BLUE", "RED", "BLACK", "ROYAL", "DINO", "UNDEAD"}, "NONE")
SM:Dropdown("Armor type", "armorType", {"NONE", "VAMBRACES", "BOOTS", "CHAPS", "COIF", "BODY", "SHIELD"}, "NONE")

-- Divination tab
SM:AddTab("Divination Porters")
SM:Dropdown("Divination Type for porters", "EnergyType", {"NONE", "VIBRANT", "RADIANT", "LUMINOUS","INCANDESCENT"}, "NONE")
SM:Dropdown("Necklace Type", "necklaceType", {"NONE", "EMERALD", "RUBY", "DIAMOND","DRAGONSTONE"}, "NONE")
SM:Dropdown("Porter Type", "porterType", {"NONE", "IV", "V", "VI","VII"}, "NONE")

SM:AddTab("Herblore")
SM:Dropdown("Herblore Sub Skill", "herbloreSubSkill", {"NONE","POTIONS", "COMBINATION", "UNF"}, "NONE")
SM:Dropdown("Potion Type", "potionType", {"NONE","ATTACK POTION","STRENGTH POTION","DEFENCE POTION","RESTORE POTION","PRAYER POTION","RANGING POTION","MAGIC POTION","SARA BREW","ANTIPOISON","ANTIFIRE","ENERGY POTION","SUPER ATTACK","SUPER STRENGTH","SUPER DEFENCE","SUPER RESTORE","SUPER ANTIPOISON","SUPER ENERGY","SUPER NECROMANCY","EXTREME ATTACK","EXTREME STRENGTH","EXTREME DEFENCE","EXTREME MAGIC","EXTREME RANGING","EXTREME NECROMANCY","OVERLOAD","PRIMAL EXTRACT","GUTHIX REST"}, "NONE")
SM:Dropdown("Combination pots","combination", {"NONE","AGGROVERLOAD","ELDER OVERLOAD POTION"},"NONE")
SM:Dropdown("unfinished potions","unfType", {"NONE","GUAM","TARROMIN","MARRENTIL","HARRALANDER","RANARR","TOADFLAX","SPIRIT WEED","IRIT","WERLGALI","AVANTOE","KWUARM","BLOODWEED","SNAPDRAGON","CADANTINE","LANTADYME","DWARFWEED","TORSTOL","ARBUCK","FELLSTALK"},"NONE")

SM:AddTab("Other")
SM:Dropdown("Ghostly ink", "inkType", {"NONE","REGULAR", "GREATER", "POWERFUL"}, "NONE")


