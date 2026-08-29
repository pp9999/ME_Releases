local API = require("api")

local module = {}

module.scriptName = "Bankstandererer"
module.configStem = "bankstandererer"
module.configPrefix = "bankstandererer-"
module.runtime = nil

module.PROFILE_INTERFACE_MODE_OPTIONS = {
    "Do Item/Tool Prompt",
    "Creation / Make-X Window",
    "Custom Prompt 2874 Status",
    "Custom Prompt Interface Size",
}

module.ITEM_CLICK_MODE_OPTIONS = {
    "Default Click",
    "Use/Select Item",
}

module.PROCESSING_CONFIRMATION_OPTIONS = {
    "API.isProcessing()",
    "Processing Interface Size",
    "Processing 2874 Status",
}

module.DEFAULT_PROFILE = {
    name = "New Profile",
    itemName = "",
    itemId = 0,
    useOnItemName = "",
    useOnItemId = 0,
    itemClickMode = module.ITEM_CLICK_MODE_OPTIONS[1],
    reloadPresetEveryCycle = true,
    interfaceMode = module.PROFILE_INTERFACE_MODE_OPTIONS[1],
    custom2874Status = 0,
    customInterfaceSize = 0,
    processingConfirmationMode = module.PROCESSING_CONFIRMATION_OPTIONS[1],
    processingInterfaceSize = 0,
    processing2874Status = 0,
    processingStartTimeoutSeconds = 4,
    processingEndTimeoutSeconds = 45,
    useSpaceToConfirm = true,
}

module.STARTER_PROFILES = {
    {
        name = "Ground Mud Runes",
        itemName = "Mud rune",
        itemId = 4698,
        useOnItemName = "",
        useOnItemId = 0,
        itemClickMode = module.ITEM_CLICK_MODE_OPTIONS[1],
        reloadPresetEveryCycle = true,
        interfaceMode = module.PROFILE_INTERFACE_MODE_OPTIONS[2],
        custom2874Status = 0,
        customInterfaceSize = 0,
        processingConfirmationMode = module.PROCESSING_CONFIRMATION_OPTIONS[1],
        processingInterfaceSize = 0,
        processing2874Status = 0,
        processingStartTimeoutSeconds = 4,
        processingEndTimeoutSeconds = 45,
        useSpaceToConfirm = true,
    },
    {
        name = "Ground Miasma Runes",
        itemName = "Miasma Rune",
        itemId = 55340,
        useOnItemName = "",
        useOnItemId = 0,
        itemClickMode = module.ITEM_CLICK_MODE_OPTIONS[1],
        reloadPresetEveryCycle = false,
        interfaceMode = module.PROFILE_INTERFACE_MODE_OPTIONS[1],
        custom2874Status = 0,
        customInterfaceSize = 0,
        processingConfirmationMode = module.PROCESSING_CONFIRMATION_OPTIONS[1],
        processingInterfaceSize = 0,
        processing2874Status = 0,
        processingStartTimeoutSeconds = 4,
        processingEndTimeoutSeconds = 45,
        useSpaceToConfirm = true,
    },
}

module.CONFIG = {
    selectedProfileIndex = 1,
    loopDelayCenter = 220,
    loopDelaySpread = 90,
}

module.PROFILES = {}

module.Gui = {
    open = true,
    draftProfile = nil,
    draftProfileIndex = 0,
    lastFrameTime = 0,
}

module.THEME = {
    dark = { 0.08, 0.06, 0.05 },
    medium = { 0.18, 0.13, 0.10 },
    light = { 0.30, 0.22, 0.16 },
    bright = { 0.86, 0.57, 0.24 },
    glow = { 0.94, 0.79, 0.46 },
    accent = { 0.95, 0.92, 0.88 },
    muted = { 0.70, 0.64, 0.58 },
    panel = { 0.12, 0.09, 0.07 },
    panelAlt = { 0.16, 0.11, 0.08 },
    success = { 0.28, 0.56, 0.34 },
    danger = { 0.70, 0.24, 0.16 },
    border = { 0.42, 0.28, 0.17 },
}

local function copyTable(source)
    local clone = {}
    for key, value in pairs(source or {}) do
        clone[key] = value
    end
    return clone
end

local function getCharacterName()
    if API and type(API.GetLocalPlayerName) == "function" then
        local playerName = API.GetLocalPlayerName()
        if type(playerName) == "string" and playerName ~= "" then
            return playerName
        end
    end
    return "default"
end

local function resolveConfigPath()
    local source = debug.getinfo(1, "S").source or ""
    source = source:gsub("^@", "")
    local dir = source:match("^(.*)[/\\][^/\\]+$")
    local prefix = module.configPrefix or (module.configStem .. "-")
    if not dir then
        return prefix .. "default.config.json"
    end
    return dir .. "\\configs\\" .. prefix .. getCharacterName() .. ".config.json"
end

local CONFIG_PATH = resolveConfigPath()

local function logError(message)
    if module.runtime then
        module.runtime.lastError = tostring(message or "")
    end
    print(string.format("[%s][ERROR] %s", module.scriptName, tostring(message)))
end

function module.configure(options)
    options = options or {}
    if type(options.scriptName) == "string" and options.scriptName ~= "" then
        module.scriptName = options.scriptName
    end
    if type(options.configStem) == "string" and options.configStem ~= "" then
        module.configStem = options.configStem
    end
    module.configPrefix = module.configStem .. "-"
    if type(options.runtime) == "table" then
        module.runtime = options.runtime
    end
    CONFIG_PATH = resolveConfigPath()
end

function module.setRuntime(runtime)
    module.runtime = runtime
end

function module.clampInteger(value, minimum, maximum, fallback)
    local number = math.floor(tonumber(value) or fallback or minimum or 0)
    if number < minimum then
        number = minimum
    end
    if maximum and number > maximum then
        number = maximum
    end
    return number
end

local function hasOption(options, value)
    for _, option in ipairs(options or {}) do
        if option == value then
            return true
        end
    end
    return false
end

local function normalizeLegacyInterfaceMode(mode)
    mode = tostring(mode or "")
    if mode == "Do Item/Tool" then
        return module.PROFILE_INTERFACE_MODE_OPTIONS[1]
    elseif mode == "Creation" then
        return module.PROFILE_INTERFACE_MODE_OPTIONS[2]
    elseif mode == "Custom 2874 Status" then
        return module.PROFILE_INTERFACE_MODE_OPTIONS[3]
    elseif mode == "Custom Interface Size" then
        return module.PROFILE_INTERFACE_MODE_OPTIONS[4]
    end
    return mode
end

function module.ensureProfileDefaults(profile)
    local merged = copyTable(module.DEFAULT_PROFILE)
    for key, value in pairs(profile or {}) do
        merged[key] = value
    end
    merged.itemId = module.clampInteger(merged.itemId, 0, nil, 0)
    merged.useOnItemId = module.clampInteger(merged.useOnItemId, 0, nil, 0)
    merged.custom2874Status = module.clampInteger(merged.custom2874Status, 0, 9999, 0)
    merged.customInterfaceSize = module.clampInteger(merged.customInterfaceSize, 0, 9999, 0)
    merged.processingInterfaceSize = module.clampInteger(merged.processingInterfaceSize, 0, 9999, 0)
    merged.processing2874Status = module.clampInteger(merged.processing2874Status, 0, 9999, 0)
    merged.processingStartTimeoutSeconds = module.clampInteger(merged.processingStartTimeoutSeconds, 1, 120, 4)
    merged.processingEndTimeoutSeconds = module.clampInteger(merged.processingEndTimeoutSeconds, 1, 600, 45)
    merged.reloadPresetEveryCycle = merged.reloadPresetEveryCycle ~= false
    merged.useSpaceToConfirm = merged.useSpaceToConfirm ~= false
    merged.interfaceMode = normalizeLegacyInterfaceMode(merged.interfaceMode)
    if not hasOption(module.ITEM_CLICK_MODE_OPTIONS, merged.itemClickMode) then
        merged.itemClickMode = module.ITEM_CLICK_MODE_OPTIONS[1]
    end
    if not hasOption(module.PROFILE_INTERFACE_MODE_OPTIONS, merged.interfaceMode) then
        merged.interfaceMode = module.PROFILE_INTERFACE_MODE_OPTIONS[1]
    end
    if not hasOption(module.PROCESSING_CONFIRMATION_OPTIONS, merged.processingConfirmationMode) then
        merged.processingConfirmationMode = module.PROCESSING_CONFIRMATION_OPTIONS[1]
    end
    return merged
end

local function resetProfiles(newProfiles)
    for index = #module.PROFILES, 1, -1 do
        table.remove(module.PROFILES, index)
    end
    for _, profile in ipairs(newProfiles or {}) do
        module.PROFILES[#module.PROFILES + 1] = module.ensureProfileDefaults(profile)
    end
    if #module.PROFILES == 0 then
        for _, profile in ipairs(module.STARTER_PROFILES) do
            module.PROFILES[#module.PROFILES + 1] = module.ensureProfileDefaults(profile)
        end
    end
    if #module.PROFILES == 0 then
        module.PROFILES[1] = module.ensureProfileDefaults(module.DEFAULT_PROFILE)
    end
end

local function ensureConfigDefaults()
    module.CONFIG.selectedProfileIndex = module.clampInteger(module.CONFIG.selectedProfileIndex, 1, math.max(1, #module.PROFILES), 1)
    module.CONFIG.loopDelayCenter = module.clampInteger(module.CONFIG.loopDelayCenter, 50, 3000, 220)
    module.CONFIG.loopDelaySpread = module.clampInteger(module.CONFIG.loopDelaySpread, 0, 1000, 90)
end

local function loadConfigFromFile()
    local file = io.open(CONFIG_PATH, "r")
    if not file then
        resetProfiles(module.STARTER_PROFILES)
        ensureConfigDefaults()
        return
    end
    local content = file:read("*a")
    file:close()
    if not content or content == "" then
        resetProfiles(module.STARTER_PROFILES)
        ensureConfigDefaults()
        return
    end

    local ok, data = pcall(API.JsonDecode, content)
    if not ok or type(data) ~= "table" then
        resetProfiles(module.STARTER_PROFILES)
        ensureConfigDefaults()
        return
    end

    module.CONFIG.selectedProfileIndex = data.SelectedProfileIndex or module.CONFIG.selectedProfileIndex
    module.CONFIG.loopDelayCenter = data.LoopDelayCenter or module.CONFIG.loopDelayCenter
    module.CONFIG.loopDelaySpread = data.LoopDelaySpread or module.CONFIG.loopDelaySpread
    resetProfiles(data.Profiles or {})
    ensureConfigDefaults()
end

local function saveConfigToFile()
    ensureConfigDefaults()
    local payload = {
        SelectedProfileIndex = module.CONFIG.selectedProfileIndex,
        LoopDelayCenter = module.CONFIG.loopDelayCenter,
        LoopDelaySpread = module.CONFIG.loopDelaySpread,
        Profiles = module.PROFILES,
    }

    local ok, json = pcall(API.JsonEncode, payload)
    if not ok or not json then
        return false
    end

    local file = io.open(CONFIG_PATH, "w")
    if not file then
        return false
    end
    file:write(json)
    file:close()
    return true
end

function module.loadConfig()
    loadConfigFromFile()
end

function module.saveConfig()
    local saved = saveConfigToFile()
    if not saved then
        logError("Failed to save config")
    end
    return saved
end

function module.getSelectedProfile()
    if #module.PROFILES == 0 then
        resetProfiles(module.STARTER_PROFILES)
    end
    local index = module.clampInteger(module.CONFIG.selectedProfileIndex, 1, #module.PROFILES, 1)
    module.CONFIG.selectedProfileIndex = index
    return module.PROFILES[index], index
end

function module.commitDraftProfile(saveToDisk)
    if not module.Gui.draftProfile then
        return false
    end
    if #module.PROFILES == 0 then
        resetProfiles({ module.DEFAULT_PROFILE })
    end
    local index = module.clampInteger(module.Gui.draftProfileIndex, 1, #module.PROFILES, module.CONFIG.selectedProfileIndex)
    module.PROFILES[index] = module.ensureProfileDefaults(module.Gui.draftProfile)
    module.Gui.draftProfile = module.ensureProfileDefaults(module.PROFILES[index])
    module.Gui.draftProfileIndex = index
    if saveToDisk then
        module.saveConfig()
    end
    return true
end

function module.formatItemLabel(name, itemId)
    local cleanName = tostring(name or "")
    local cleanId = tonumber(itemId) or 0
    if cleanName == "" and cleanId <= 0 then
        return "Not configured"
    end
    return string.format("%s (%d)", cleanName, cleanId)
end

function module.getProfileDisplayName(profile, index)
    local cleanName = tostring(profile and profile.name or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if cleanName == "" then
        cleanName = "Profile " .. tostring(index or "?")
    end
    return string.format("%s (%s)", cleanName, tostring(index or "?"))
end

function module.yesNoLabel(value)
    return value and "Yes" or "No"
end

function module.getReloadBehaviorLabel(profile)
    if profile and profile.reloadPresetEveryCycle == false then
        return "Reuse until empty"
    end
    return "Load each cycle"
end

function module.ensureDraftProfile()
    if not module.Gui.draftProfile then
        local selectedProfile = module.getSelectedProfile()
        module.Gui.draftProfile = module.ensureProfileDefaults(selectedProfile)
        module.Gui.draftProfileIndex = module.CONFIG.selectedProfileIndex
    end
end

function module.syncDraftToSelection()
    module.ensureDraftProfile()
    if module.Gui.draftProfileIndex ~= module.CONFIG.selectedProfileIndex then
        local selectedProfile = module.getSelectedProfile()
        module.Gui.draftProfile = module.ensureProfileDefaults(selectedProfile)
        module.Gui.draftProfileIndex = module.CONFIG.selectedProfileIndex
    end
end

function module.getProfileEditorCardHeights(profile)
    local identityHeight = 128
    if tostring(profile.itemClickMode or module.ITEM_CLICK_MODE_OPTIONS[1]) == module.ITEM_CLICK_MODE_OPTIONS[2] then
        identityHeight = 176
    end

    local cycleHeight = 96
    local processingHeight = 110
    local interfaceMode = tostring(profile.interfaceMode or module.PROFILE_INTERFACE_MODE_OPTIONS[1])
    if interfaceMode == module.PROFILE_INTERFACE_MODE_OPTIONS[3] or interfaceMode == module.PROFILE_INTERFACE_MODE_OPTIONS[4] then
        processingHeight = processingHeight + 30
    end

    local processingMode = tostring(profile.processingConfirmationMode or module.PROCESSING_CONFIRMATION_OPTIONS[1])
    if processingMode == module.PROCESSING_CONFIRMATION_OPTIONS[2] or processingMode == module.PROCESSING_CONFIRMATION_OPTIONS[3] then
        processingHeight = processingHeight + 30
    end

    return {
        actions = 72,
        identity = identityHeight,
        cycle = cycleHeight,
        processing = processingHeight,
    }
end

return module
