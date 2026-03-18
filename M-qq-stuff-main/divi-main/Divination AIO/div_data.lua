local DATA = {}

DATA.IDS = {
    SIPHON_ANIM = 21228,
    MEMORY_DOWSER = 57521,
    RIFT = 87306,
    EMPOWERED_RIFT = 93489,
}

DATA.RIFT_OBJ_TYPE = {
    EMPOWERED = 0,
    NORMAL = 0,
}

DATA.VARBIT_IDS = {
    CONVERSION_MODE = 40524,
    MEMORY_STRANDS = 34807,
    RUN_ENABLED = 2658,
}

DATA.INTERFACES = {
    RIFT_CONFIGURE = { {131, 4, -1, 0}, {131, 7, -1, 0}, {131, 7, 14, 0} },
    CONVERSION_MODE = {
        [0] = {131, 13, -1},
        [1] = {131, 16, -1},
        [2] = {131, 10, -1},
    },
    RUN_TOGGLE = {1465, 14, -1},
}

DATA.EQUIPMENT_CONTAINER = 94

DATA.CONVERSION_MODES = {
    [0] = "Memories -> XP",
    [1] = "Memories + Energy -> XP",
    [2] = "Memories -> Energy",
}

DATA.CONVERSION_MODE_NAMES = {
    "Memories -> XP",
    "Memories + Energy -> XP",
    "Memories -> Energy",
}

return DATA
