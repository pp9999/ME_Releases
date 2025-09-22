local DATA = {}

DATA.BANK = {
    FLETCHING = 125720,

    COOKING = 125734
}
DATA.STATION = {
    FLETCHING = 125718,

    COOKING = 125205,

    FIREMAKING = 92885,

    GLASSMAKING = 94067
}

DATA.LOGS = {
    NORMAL = 1511,
    OAK = 1521,
    WILLOW = 1519,
    MAPLE = 1517,
    YEW = 1515,
    MAGIC = 1513,
    SHAFTS = 52
}

DATA.INK = {
    REGULAR = {
        { id = 55599, amount = 20 },  -- Regular ink
        { id = 227, amount = 1 },  -- Regular ink (unf)
        { id = 592, amount = 1 },  -- Regular ink (unf)
    },
        GREATER = {
        { id = 55600, amount = 20 },  -- Regular ink
        { id = 227, amount = 1 },  -- Regular ink (unf)
        { id = 592, amount = 1 },  -- Regular ink (unf)
    },
        POWERFUL = {
        { id = 55601, amount = 20 },  -- Regular ink
        { id = 227, amount = 1 },  -- Regular ink (unf)
        { id = 592, amount = 1 },  -- Regular ink (unf)
    }
}

DATA.POTIONS = {
    -- Normale potions
    ATTACK_POTION = {{
        id = 91,
        amount = 1
    }, {
        id = 221,
        amount = 1
    }}, -- Guam potion (unf), Eye of newt
    STRENGTH_POTION = {{
        id = 95,
        amount = 1
    }, {
        id = 225,
        amount = 1
    }}, -- Tarromin potion (unf), Limpwurt root
    DEFENCE_POTION = {{
        id = 93,
        amount = 1
    }, {
        id = 948,
        amount = 1
    }}, -- Marrentill potion (unf), Bear fur
    RESTORE_POTION = {{
        id = 97,
        amount = 1
    }, {
        id = 223,
        amount = 1
    }}, -- Harralander potion (unf), Red spiders' eggs
    PRAYER_POTION = {{
        id = 99,
        amount = 1
    }, {
        id = 231,
        amount = 1
    }}, -- Ranarr potion (unf), Snape grass
    RANGING_POTION = {{
        id = 109,
        amount = 1
    }, {
        id = 245,
        amount = 1
    }}, -- Dwarf weed potion (unf), Wine of Zamorak
    MAGIC_POTION = {{
        id = 2483,
        amount = 1
    }, {
        id = 3138,
        amount = 1
    }}, -- Lantadyme potion (unf), Potato cactus
    SARA_BREW = {{
        id = 3002,
        amount = 1
    }, {
        id = 6693,
        amount = 1
    }}, -- Toadflax potion (unf), Crushed nest
    ANTIPOISON = {{
        id = 93,
        amount = 1
    }, {
        id = 235,
        amount = 1
    }}, -- Marrentill potion (unf), Unicorn horn dust
    ANTIFIRE = {{
        id = 2483,
        amount = 1
    }, {
        id = 241,
        amount = 1
    }}, -- Lantadyme potion (unf), Dragon scale dust
    ENERGY_POTION = {{
        id = 97,
        amount = 1
    }, {
        id = 1975,
        amount = 1
    }}, -- Harralander potion (unf), Chocolate dust

    -- Super potions
    SUPER_ATTACK = {{
        id = 101,
        amount = 1
    }, {
        id = 221,
        amount = 1
    }}, -- Irit potion (unf), Eye of newt
    SUPER_STRENGTH = {{
        id = 105,
        amount = 1
    }, {
        id = 225,
        amount = 1
    }}, -- Kwuarm potion (unf), Limpwurt root
    SUPER_DEFENCE = {{
        id = 107,
        amount = 1
    }, {
        id = 239,
        amount = 1
    }}, -- Cadantine potion (unf), White berries
    SUPER_RESTORE = {{
        id = 3004,
        amount = 1
    }, {
        id = 223,
        amount = 1
    }}, -- Snapdragon potion (unf), Red spiders' eggs
    SUPER_ANTIPOISON = {{
        id = 101,
        amount = 1
    }, {
        id = 235,
        amount = 1
    }}, -- Irit potion (unf), Unicorn horn dust
    SUPER_ENERGY = {{
        id = 103,
        amount = 1
    }, {
        id = 2970,
        amount = 1
    }}, -- Avantoe potion (unf), Mort myre fungus
    SUPER_NECROMANCY = {{
        id = 12181,
        amount = 1
    }, {
        id = 37227,
        amount = 1
    }}, -- Spirit weed potion (unf), Congealed blood

    -- Extreme potions
    EXTREME_ATTACK = {{
        id = 261,
        amount = 1
    }, {
        id = 145,
        amount = 1
    }}, -- Clean avantoe, Super attack (3)
    EXTREME_STRENGTH = {{
        id = 267,
        amount = 1
    }, {
        id = 157,
        amount = 1
    }}, -- Clean dwarf weed, Super strength (3)
    EXTREME_DEFENCE = {{
        id = 2481,
        amount = 1
    }, {
        id = 163,
        amount = 1
    }}, -- Clean lantadyme, Super defence (3)
    EXTREME_MAGIC = {{
        id = 3042,
        amount = 1
    }, {
        id = 3138,
        amount = 1
    }}, -- Magic potion (3), Ground mud runes
    EXTREME_RANGING = {{
        id = 169,
        amount = 1
    }, {
        id = 12539,
        amount = 5
    }}, -- super ranging pot (3), grenwall spikes
    EXTREME_NECROMANCY = {{
        id = 55318,
        amount = 1
    }, {
        id = 55697,
        amount = 1
    }}, -- Super necromancy (3), Ground miasma rune

    -- overige
    OVERLOAD = {{
        id = 269,
        amount = 1
    }, {
        id = 15309,
        amount = 1
    }, {
        id = 15313,
        amount = 1
    }, {
        id = 15317,
        amount = 1
    }, {
        id = 15321,
        amount = 1
    }, {
        id = 15325,
        amount = 1
    }, {
        id = 55326,
        amount = 1
    }},
    PRIMAL_EXTRACT = {{
        id = 48966,
        amount = 1
    }, {
        id = 229,
        amount = 1
    }}, -- Primal pulp  , vial
    GUTHIX_REST = {{
        id = 97,
        amount = 1
    }, {
        id = 251,
        amount = 1
    }}, -- Primal pulp  , vial

}

DATA.COMBINATIONPOTS = {
    -- WHEN DOING COMBINATION POTS, MAKE SURE YOU HAVE 1 OF THESE IN INVENTORY , {id=32843,amount=1} =  crystal flask
    AGGROVERLOAD = {{
        id = 15332,
        amount = 1
    }, {
        id = 32843,
        amount = 1
    }, {
        id = 37971,
        amount = 1
    }, {
        id = 48211,
        amount = 1
    }},
    ELDER_OVERLOAD_POTION = {{
        id = 21624,
        amount = 1
    }, {
        id = 33210,
        amount = 1
    }, {
        id = 48962,
        amount = 1
    }, {
        id = 55957,
        amount = 1
    }, {
        id = 32843,
        amount = 1
    }},
    ELDER_OVERLOAD_SALVE = {{
        id = 2434,
        amount = 1
    }, {
        id = 2448,
        amount = 1
    }, {
        id = 2452,
        amount = 1
    }, {
        id = 15304,
        amount = 1
    }, {
        id = 21624,
        amount = 1
    }, {
        id = 21630,
        amount = 1
    }, {
        id = 33222,
        amount = 1
    }, {
        id = 48962,
        amount = 1
    }, {
        id = 49039,
        amount = 1
    }, {
        id = 55958,
        amount = 1
    }, {
        id = 32843,
        amount = 1
    }},
    HOLY_AGGROVERLOAD = {{
        id = 15332,
        amount = 1
    }, {
        id = 21630,
        amount = 1
    }, {
        id = 32843,
        amount = 1
    }, {
        id = 33246,
        amount = 1
    }, {
        id = 37971,
        amount = 1
    }, {
        id = 43997,
        amount = 1
    }, {
        id = 48239,
        amount = 1
    }},
    HOLY_OVERLOAD_POTION = {{
        id = 15332,
        amount = 1
    }, {
        id = 21630,
        amount = 1
    }, {
        id = 32843,
        amount = 1
    }},
    OVERLOAD_SALVE = {{
        id = 2434,
        amount = 1
    }, {
        id = 2448,
        amount = 1
    }, {
        id = 2452,
        amount = 1
    }, {
        id = 15304,
        amount = 1
    }, {
        id = 15332,
        amount = 1
    }, {
        id = 21630,
        amount = 1
    }, {
        id = 32843,
        amount = 1
    }, {
        id = 55954,
        amount = 1
    }},
    SEARING_OVERLOAD_POTION = {{
        id = 15304,
        amount = 1
    }, {
        id = 15332,
        amount = 1
    }, {
        id = 32843,
        amount = 1
    }},
    SUPREME_OVERLOAD_POTION = {{
        id = 2436,
        amount = 1
    }, {
        id = 2440,
        amount = 1
    }, {
        id = 2442,
        amount = 1
    }, {
        id = 32843,
        amount = 1
    }, {
        id = 2444,
        amount = 1
    }, {
        id = 3040,
        amount = 1
    }, {
        id = 15332,
        amount = 1
    }, {
        id = 32843,
        amount = 1
    }, {
        id = 55316,
        amount = 1
    }, {
        id = 55955,
        amount = 1
    }},
    SUPREME_OVERLOAD_SALVE = {{
        id = 2434,
        amount = 1
    }, {
        id = 2448,
        amount = 1
    }, {
        id = 2452,
        amount = 1
    }, {
        id = 15304,
        amount = 1
    }, {
        id = 21630,
        amount = 1
    }, {
        id = 32843,
        amount = 1
    }, {
        id = 33210,
        amount = 1
    }, {
        id = 55956,
        amount = 1
    }}
}

DATA.UNFINISHEDPOTS = {
    GUAM = 249,
    TARROMIN = 253,
    MARRENTIL = 251,
    HARRALANDER = 255,
    RANARR = 257,
    TOADFLAX = 2998,
    SPIRIT_WEED = 12172,
    IRIT = 259,
    WERLGALI = 14854,
    AVANTOE = 261,
    KWUARM = 263,
    BLOODWEED = 37953,
    SNAPDRAGON = 3000,
    CADANTINE = 265,
    LANTADYME = 2481,
    DWARFWEED = 267,
    TORSTOL = 269,
    ARBUCK = 48211,
    FELLSTALK = 21624
}

DATA.SANDSTONE = {
    RED = 23194,
    CRYSTAL = 32847
}

DATA.GLASS = {
    ROBUST = 23193,
    CRYSTAL = 32845
}

DATA.LEATHER = {
    LEATHER = 1741,
    HARDLEATHER = 1743,
    SPIDERSILK = 25547,
    GREEN = 1745,
    BLUE = 2505,
    RED = 2507,
    BLACK = 2509,
    ROYAL = 24374,
    DINO = 48025,
    UNDEAD = 56075
}
DATA.FISH = {
    SHRIMP = 317,
    CRAYFISH = 13435,
    SARDINE = 327,
    HERRING = 345,
    ANCHOVIES = 321,
    MACKEREL = 353,
    TROUT = 335,
    COD = 341,
    PIKE = 349,
    SALMON = 331,
    SLIMY_EEL = 3379,
    RAINBOW_FISH = 10138,
    TUNA = 359,
    KARAMBWAN = 3142,
    CAVE_EEL = 5001,
    LOBSTER = 377,
    BASS = 363,
    SWORDFISH = 371,
    MONKFISH = 7944,
    DESERT_SOLE = 40287,
    CATFISH = 40289,
    BELTFISH = 40291,
    SHARK = 383,
    SEA_TURTLE = 395,
    MANTA_RAY = 389,
    GREAT_WHITE_SHARK = 34727,
    CAVEFISH = 15264,
    ROCKTAIL = 15270,
    TIGER_SHARK = 21520,
    SAILFISH = 42249,
}
DATA.UNCUTGEMS = {
    SAPPHIRE = 1623,
    EMERALD = 1621,
    RUBY = 1619,
    DIAMOND = 1617,
    DRAGONSTONE = 1631,
    OPAL = 1625,
    JADE = 1627,
    TOPAZ = 1629
}

DATA.CUTGEMS = {
    SAPPHIRE = 1607,
    EMERALD = 1605,
    RUBY = 1603,
    DIAMOND = 1601,
    DRAGONSTONE = 1615,
    OPAL = 1609,
    JADE = 1611,
    TOPAZ = 1613,
    ENCHANTED_GEM = 4155
}
DATA.ARROWHEADS = {
    BRONZE = 39,
    IRON = 40,
    STEEL = 41,
    MITHRIL = 42,
    ADAMANT = 43,
    RUNE = 44,
    DRAGON = 11237,
    BROAD = 13278

}
DATA.SHORTBOW = {
    NORMAL = 52,
    OAK = 55,
    WILLOW = 61,
    MAPLE = 63,
    YEW = 68,
    MAGIC = 72
}
DATA.SHIELDBOW = {
    NORMAL = 49,
    OAK = 57,
    WILLOW = 59,
    MAPLE = 65,
    YEW = 67,
    MAGIC = 71
}

DATA.ENERGY = {
    VIBRANT = 29319,
    RADIANT = 29322,
    LUMINOUS = 29323,
    INCANDESCENT = 29324
}

DATA.NECKLACE = {
    EMERALD = 1658,
    RUBY = 1660,
    DIAMOND = 1662,
    DRAGONSTONE = 1664
}

-- Config data and material data resolve
local function clean(s)
    if type(s) ~= "string" then
        return nil
    end
    s = s:gsub("%s+", "_"):upper()
    if s == "" or s == "NONE" then
        return nil
    end
    return s
end

function DATA.resolve(cfg)
    if not cfg then
        pcall(require, "Knetter AIO Skiller.config")
        cfg = rawget(_G, "CONFIG") or {}
    end

    local selectedSkill = clean(cfg.selectedSkill) or "FLETCHING"
    local subSkill = clean(cfg.subSkill)
    local selectedFish = clean(cfg.fishType)
    local selectedLog = clean(cfg.logType)
    local selectedArrow = clean(cfg.arrowheadType)
    local bowMaterial1 = clean(cfg.bowMaterial1)
    local bowMaterial2 = clean(cfg.bowMaterial2)
    local subSkill2 = clean(cfg.subSkill2)
    local uncut = clean(cfg.uncut)
    local selectedSandstone = clean(cfg.selectedSandstone)
    local selectedGlass = clean(cfg.selectedGlass)
    local selectedLeather = clean(cfg.selectedLeather)
    local armorType = clean(cfg.armorType)
    local EnergyType = clean(cfg.EnergyType)
    local necklaceType = clean(cfg.necklaceType)
    local porterType = clean(cfg.porterType)
    local potionType = clean(cfg.potionType)
    local combination = clean(cfg.combination)
    local unfinishedPotions = clean(cfg.unfType)
    local herbloreSubSkill = clean(cfg.herbloreSubSkill)
    local inkType = clean(cfg.inkType)

    local out = {
        selectedSkill = selectedSkill,
        subSkill = subSkill,
        selectedFish = selectedFish and DATA.FISH[selectedFish] or nil,
        selectedLog = selectedLog and DATA.LOGS[selectedLog] or nil,
        selectedArrow = selectedArrow and DATA.ARROWHEADS[selectedArrow] or nil,
        bowMaterial1 = bowMaterial1 and DATA.SHORTBOW[bowMaterial1] or nil,
        bowMaterial2 = bowMaterial2 and DATA.SHIELDBOW[bowMaterial2] or nil,
        subSkill2 = subSkill2,
        uncut = uncut and DATA.UNCUTGEMS[uncut] or nil,
        selectedSandstone = selectedSandstone and DATA.SANDSTONE[selectedSandstone] or nil,
        selectedGlass = selectedGlass and DATA.GLASS[selectedGlass] or nil,
        selectedLeather = selectedLeather and DATA.LEATHER[selectedLeather] or nil,
        armorType = armorType,
        EnergyType = EnergyType and DATA.ENERGY[EnergyType] or nil,
        necklaceType = necklaceType and DATA.NECKLACE[necklaceType] or nil,
        porterType = porterType,
        potionType = potionType and DATA.POTIONS[potionType] or nil,
        combination = combination and DATA.COMBINATIONPOTS[combination] or nil,
        unfinishedPotions = unfinishedPotions and DATA.UNFINISHEDPOTS[unfinishedPotions] or nil,
        herbloreSubSkill = herbloreSubSkill,
        inkType = inkType and DATA.INK[inkType] or nil
    }

    return out
end

return DATA
