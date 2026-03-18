local API = require("api")
local DATA = require("Divination AIO/div_data")
local WISPS = require("Divination AIO/div_wisps")
local Utils = require("Divination AIO/div_utils")

local DivGUI = {}
DivGUI.open = true
DivGUI.started = false
DivGUI.warnings = {}
DivGUI.selectConfigTab = true
DivGUI.selectWarningsTab = false
DivGUI.selectInfoTab = false
DivGUI.uiMode = "presets"
DivGUI.presetSaveName = ""

local cachedWarningLabel = nil
local cachedWarningCount = -1
local titleCache = nil

local DEFAULT_LABEL_COLOR = {0.55, 0.55, 0.58}
local DEFAULT_VALUE_COLOR = {0.78, 0.78, 0.8}

local STATE_COLORS = {
    Siphoning = {0.3, 1.0, 0.4},
    Depositing = {1.0, 0.8, 0.2},
    Idle = {0.6, 0.6, 0.65},
}

function DivGUI.reset()
    DivGUI.open = true
    DivGUI.started = false
    Utils.clearTable(DivGUI.warnings)
    DivGUI.selectConfigTab = true
    DivGUI.selectWarningsTab = false
    DivGUI.selectInfoTab = false
    DivGUI.uiMode = "presets"
    DivGUI.presetSaveName = ""
    titleCache = nil
end

function DivGUI.addWarning(msg)
    DivGUI.warnings[#DivGUI.warnings + 1] = msg
    if #DivGUI.warnings > 50 then
        table.remove(DivGUI.warnings, 1)
    end
end

DivGUI.config = {
    wispIndex = 0,
    conversionMode = 1,
    memoryDowser = false,
}

local cachedFilteredWispKeys, cachedFilteredWispNames
local lastWispFilterTime = 0

local function buildFilteredWispList()
    local now = os.clock()
    if cachedFilteredWispKeys and (now - lastWispFilterTime) < 2 then
        return cachedFilteredWispKeys, cachedFilteredWispNames
    end
    lastWispFilterTime = now
    local divLevel = API.XPLevelTable(API.GetSkillXP("DIVINATION"))
    local keys, names = {}, {}
    for i, key in ipairs(WISPS.ORDERED_KEYS) do
        if WISPS.TYPES[key].level <= divLevel then
            keys[#keys + 1] = key
            names[#names + 1] = WISPS.ORDERED_NAMES[i]
        end
    end
    if #keys == 0 then
        cachedFilteredWispKeys = WISPS.ORDERED_KEYS
        cachedFilteredWispNames = WISPS.ORDERED_NAMES
    else
        cachedFilteredWispKeys = keys
        cachedFilteredWispNames = names
    end
    return cachedFilteredWispKeys, cachedFilteredWispNames
end

local function findKeyIndex(keys, key)
    if not key then return -1 end
    for i, k in ipairs(keys) do
        if k == key then return i - 1 end
    end
    return -1
end

local PRESETS_FILE = (os.getenv("USERPROFILE") or ".") .. "\\MemoryError\\Lua_Scripts\\Divination AIO\\div_presets.json"

local presetsCache = nil
local presetNamesCache = nil

local function loadAllPresets()
    if presetsCache then return presetsCache end
    local file = io.open(PRESETS_FILE, "r")
    if not file then
        presetsCache = {}
        return presetsCache
    end
    local content = file:read("*a")
    file:close()
    if not content or content == "" then
        presetsCache = {}
        return presetsCache
    end
    local ok, data = pcall(API.JsonDecode, content)
    if not ok or type(data) ~= "table" then
        presetsCache = {}
        return presetsCache
    end
    presetsCache = data
    return presetsCache
end

local function invalidatePresetsCache()
    presetsCache = nil
    presetNamesCache = nil
end

local function saveAllPresets()
    local file = io.open(PRESETS_FILE, "w")
    if not file then return false end
    if not presetsCache or not next(presetsCache) then
        file:write("{}")
    else
        local ok, json = pcall(API.JsonEncode, presetsCache)
        if not ok or not json then
            file:close()
            return false
        end
        file:write(json)
    end
    file:close()
    return true
end

local function listPresets()
    if presetNamesCache then return presetNamesCache end
    local presets = loadAllPresets()
    local names = {}
    for name in pairs(presets) do
        names[#names + 1] = name
    end
    table.sort(names)
    presetNamesCache = names
    return names
end

local function savePresetToFile(presetName, cfg)
    local wispKey = cachedFilteredWispKeys and cachedFilteredWispKeys[cfg.wispIndex + 1]
        or WISPS.ORDERED_KEYS[cfg.wispIndex + 1]
    local data = {
        WispType = wispKey,
        ConversionMode = cfg.conversionMode,
        MemoryDowser = cfg.memoryDowser,
    }
    local presets = loadAllPresets()
    presets[presetName] = data
    if not saveAllPresets() then
        return false
    end
    presetNamesCache = nil
    return true
end

local function loadPresetFromFile(presetName)
    local presets = loadAllPresets()
    return presets[presetName]
end

local function deletePreset(presetName)
    local presets = loadAllPresets()
    presets[presetName] = nil
    saveAllPresets()
    invalidatePresetsCache()
end

local function applyConfigData(saved, c)
    if saved.WispType then
        local filteredKeys = cachedFilteredWispKeys or WISPS.ORDERED_KEYS
        local idx = findKeyIndex(filteredKeys, saved.WispType)
        c.wispIndex = idx >= 0 and idx or 0
    end
    c.conversionMode = type(saved.ConversionMode) == "number"
        and math.max(0, math.min(2, saved.ConversionMode)) or 1
    c.memoryDowser = saved.MemoryDowser == true
end

function DivGUI.loadPreset(presetName)
    local saved = loadPresetFromFile(presetName)
    if not saved then return false end
    Utils.clearTable(DivGUI.warnings)
    applyConfigData(saved, DivGUI.config)
    return true
end

function DivGUI.savePreset(presetName)
    return savePresetToFile(presetName, DivGUI.config)
end

function DivGUI.getConfig()
    local c = DivGUI.config
    local filteredKeys = cachedFilteredWispKeys or WISPS.ORDERED_KEYS
    local wispKey = filteredKeys[c.wispIndex + 1]
    return {
        wispType = wispKey,
        conversionMode = c.conversionMode,
        memoryDowser = c.memoryDowser,
    }
end

local function row(lbl, value, labelColor, valueColor)
    local lc = labelColor or DEFAULT_LABEL_COLOR
    local vc = valueColor or DEFAULT_VALUE_COLOR
    ImGui.TableNextRow()
    ImGui.TableNextColumn()
    ImGui.PushStyleColor(ImGuiCol.Text, lc[1], lc[2], lc[3], 1.0)
    ImGui.TextUnformatted(lbl)
    ImGui.PopStyleColor(1)
    ImGui.TableNextColumn()
    ImGui.PushStyleColor(ImGuiCol.Text, vc[1], vc[2], vc[3], 1.0)
    ImGui.TextUnformatted(value)
    ImGui.PopStyleColor(1)
end

local function progressBar(progress, height, text, r, g, b)
    ImGui.PushStyleColor(ImGuiCol.PlotHistogram, r * 0.5, g * 0.5, b * 0.5, 1.0)
    ImGui.PushStyleColor(ImGuiCol.FrameBg, 0.12, 0.12, 0.15, 1.0)
    ImGui.ProgressBar(progress, -1, height, text)
    ImGui.PopStyleColor(2)
end

local function label(text)
    ImGui.PushStyleColor(ImGuiCol.Text, 0.6, 0.62, 0.65, 1.0)
    ImGui.TextUnformatted(text)
    ImGui.PopStyleColor(1)
end

local function drawConfigTab(cfg, gui)
    local presetNames = listPresets()
    if #presetNames == 0 then
        gui.uiMode = "setup"
    end

    if gui.uiMode == "presets" then
        local toDelete = nil
        local rowH, xWidth, rounding = 26, 28, 3
        local listHeight = math.min(#presetNames * 36, 216)

        ImGui.BeginChild("presetList", -1, listHeight, false)
        for i, name in ipairs(presetNames) do
            ImGui.PushStyleColor(ImGuiCol.ChildBg, 0.13, 0.14, 0.16, 1.0)
            ImGui.PushStyleColor(ImGuiCol.Border, 0.25, 0.27, 0.30, 1.0)
            ImGui.PushStyleVar(ImGuiStyleVar.ChildRounding, rounding)
            ImGui.PushStyleVar(ImGuiStyleVar.ChildBorderSize, 1)
            ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 0, 0)
            ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 0, 0)
            ImGui.BeginChild("preset" .. i, -1, rowH, true)

            local availW = ImGui.GetContentRegionAvail() - 6

            ImGui.PushStyleColor(ImGuiCol.Button, 0.0, 0.0, 0.0, 0.0)
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.20, 0.38, 0.28, 0.4)
            ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.18, 0.32, 0.24, 0.6)
            ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 8, 0)
            ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding, rounding)
            if ImGui.Button(name .. "##start" .. i, availW - xWidth, rowH) then
                gui.loadPreset(name)
                gui.started = true
            end
            ImGui.PopStyleVar(2)
            ImGui.PopStyleColor(3)

            ImGui.SameLine()
            ImGui.PushStyleColor(ImGuiCol.Button, 0.0, 0.0, 0.0, 0.0)
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.5, 0.25, 0.25, 1.0)
            ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.4, 0.2, 0.2, 1.0)
            ImGui.PushStyleColor(ImGuiCol.Text, 0.6, 0.6, 0.63, 1.0)
            ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding, rounding)
            if ImGui.Button("x##del" .. i, xWidth, rowH) then
                toDelete = name
            end
            ImGui.PopStyleVar(1)
            ImGui.PopStyleColor(4)

            ImGui.EndChild()
            ImGui.PopStyleVar(4)
            ImGui.PopStyleColor(2)
            ImGui.Spacing()
        end
        ImGui.EndChild()

        if toDelete then deletePreset(toDelete) end

        ImGui.Spacing()

        ImGui.PushStyleColor(ImGuiCol.Button, 0.18, 0.25, 0.35, 0.95)
        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.24, 0.32, 0.45, 1.0)
        ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.16, 0.22, 0.32, 1.0)
        if ImGui.Button("+ New Preset", -1, 30) then
            gui.uiMode = "setup"
            gui.presetSaveName = ""
        end
        ImGui.PopStyleColor(3)

        return
    end

    if #presetNames > 0 then
        ImGui.PushStyleColor(ImGuiCol.Button, 0.22, 0.25, 0.30, 0.9)
        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.30, 0.34, 0.40, 1.0)
        ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.26, 0.30, 0.36, 1.0)
        if ImGui.Button("< Back", 70, 22) then
            gui.uiMode = "presets"
        end
        ImGui.PopStyleColor(3)
        ImGui.Spacing()
    end

    ImGui.PushItemWidth(-1)

    label("Wisp")
    local filteredKeys, filteredNames = buildFilteredWispList()
    local currentKey = filteredKeys[cfg.wispIndex + 1]
    local filteredIdx = 0
    if currentKey then
        for i, k in ipairs(filteredKeys) do
            if k == currentKey then
                filteredIdx = i - 1
                break
            end
        end
    end
    local wispChanged, newWispIdx = ImGui.Combo("##wisp", filteredIdx, filteredNames, 10)
    if wispChanged then
        cfg.wispIndex = newWispIdx
    end

    label("Conversion Mode")
    local modeChanged, newModeIdx = ImGui.Combo("##convmode", cfg.conversionMode, DATA.CONVERSION_MODE_NAMES, 5)
    if modeChanged then
        cfg.conversionMode = newModeIdx
    end

    ImGui.Separator()

    local dowserChanged, dowserVal = ImGui.Checkbox("Memory Dowser##dowser", cfg.memoryDowser)
    if dowserChanged then cfg.memoryDowser = dowserVal end

    ImGui.PopItemWidth()

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    ImGui.PushStyleColor(ImGuiCol.Text, 0.6, 0.65, 0.7, 1.0)
    ImGui.TextUnformatted("Save as preset (optional):")
    ImGui.PopStyleColor(1)

    ImGui.PushItemWidth(-1)
    local nameChanged, newName = ImGui.InputText("##saveName", gui.presetSaveName, 0)
    if nameChanged then
        gui.presetSaveName = newName
    end
    ImGui.PopItemWidth()

    ImGui.Spacing()

    ImGui.PushStyleColor(ImGuiCol.Button, 0.25, 0.45, 0.30, 0.95)
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.30, 0.52, 0.35, 1.0)
    ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.22, 0.40, 0.27, 1.0)

    local buttonLabel = gui.presetSaveName ~= "" and "Save & Start" or "Start"
    if ImGui.Button(buttonLabel .. "##start", -1, 32) then
        if gui.presetSaveName ~= "" then
            local name = gui.presetSaveName:match("^%s*(.-)%s*$")
            if name ~= "" then
                gui.savePreset(name)
            end
        end
        gui.started = true
    end
    ImGui.PopStyleColor(3)
end

local function drawInfoTab(data)
    if ImGui.BeginTable("##info", 2) then
        ImGui.TableSetupColumn("lbl", ImGuiTableColumnFlags.WidthStretch, 0.38)
        ImGui.TableSetupColumn("val", ImGuiTableColumnFlags.WidthStretch, 0.62)

        local stateColor = STATE_COLORS[data.state] or DEFAULT_VALUE_COLOR
        row("State", data.state or "Idle", nil, stateColor)
        row("Target", data.currentTarget or "None")
        row("Conversion", data.conversionMode or "--")
        if data.energyText then
            row("Energy", data.energyText)
        end
        if data.strandsText then
            row("Strands", data.strandsText)
        end
        row("Anti-idle", data.antiIdleText or "0:00")

        ImGui.EndTable()
    end
end

local function drawMetricsTab(data)
    if data.metricsBarMaxLevel then
        progressBar(data.metricsBarProgress, 18, data.metricsBarLabel, 0.45, 0.6, 0.45)
    else
        progressBar(data.metricsBarProgress, 18, data.metricsBarLabel, 0.45, 0.55, 0.65)
    end
end

local function drawWarningsTab(gui)
    if #gui.warnings == 0 then
        ImGui.PushStyleColor(ImGuiCol.Text, 0.5, 0.5, 0.52, 1.0)
        ImGui.TextUnformatted("No warnings.")
        ImGui.PopStyleColor(1)
        return
    end
    for _, warning in ipairs(gui.warnings) do
        ImGui.PushStyleColor(ImGuiCol.Text, 0.85, 0.7, 0.35, 1.0)
        ImGui.TextWrapped(warning)
        ImGui.PopStyleColor(1)
        ImGui.Spacing()
    end

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    ImGui.PushStyleColor(ImGuiCol.Button, 0.35, 0.35, 0.38, 0.9)
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.45, 0.45, 0.48, 1.0)
    ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.5, 0.5, 0.52, 1.0)
    if ImGui.Button("Dismiss##clear", -1, 24) then
        Utils.clearTable(gui.warnings)
    end
    ImGui.PopStyleColor(3)
end

local function drawContent(data, gui)
    local tabBarOpen = ImGui.BeginTabBar("##maintabs", 0)
    if not tabBarOpen then return end

    if not gui.started then
        local configFlags = gui.selectConfigTab and ImGuiTabItemFlags.SetSelected or 0
        gui.selectConfigTab = false
        local configSelected = ImGui.BeginTabItem("Presets###config", nil, configFlags)
        if configSelected then
            ImGui.Spacing()
            local ok, err = pcall(drawConfigTab, gui.config, gui)
            if not ok then
                ImGui.TextColored(1.0, 0.3, 0.3, 1.0, "Config error: " .. tostring(err))
            end
            ImGui.EndTabItem()
        end
    end

    if gui.started then
        local infoFlags = gui.selectInfoTab and ImGuiTabItemFlags.SetSelected or 0
        gui.selectInfoTab = false
        if ImGui.BeginTabItem("Info###info", nil, infoFlags) then
            ImGui.Spacing()
            local ok, err = pcall(drawInfoTab, data)
            if not ok then
                ImGui.TextColored(1.0, 0.3, 0.3, 1.0, "Info error: " .. tostring(err))
            end
            ImGui.EndTabItem()
        end

        if ImGui.BeginTabItem("Metrics###metrics") then
            ImGui.Spacing()
            local ok, err = pcall(drawMetricsTab, data)
            if not ok then
                ImGui.TextColored(1.0, 0.3, 0.3, 1.0, "Metrics error: " .. tostring(err))
            end
            ImGui.EndTabItem()
        end
    end

    if #gui.warnings > 0 then
        if #gui.warnings ~= cachedWarningCount then
            cachedWarningCount = #gui.warnings
            cachedWarningLabel = "Warnings (" .. cachedWarningCount .. ")###warnings"
        end
        local warnFlags = gui.selectWarningsTab and ImGuiTabItemFlags.SetSelected or 0
        local warnSelected = ImGui.BeginTabItem(cachedWarningLabel, nil, warnFlags)
        if warnSelected then gui.selectWarningsTab = false end
        if warnSelected then
            ImGui.Spacing()
            local ok, err = pcall(drawWarningsTab, gui)
            if not ok then
                ImGui.TextColored(1.0, 0.3, 0.3, 1.0, "Warnings error: " .. tostring(err))
            end
            ImGui.EndTabItem()
        end
    end

    ImGui.EndTabBar()
end

function DivGUI.draw(data)
    ImGui.SetNextWindowSize(340, 0, ImGuiCond.Always)
    ImGui.SetNextWindowPos(100, 100, ImGuiCond.FirstUseEver)

    ImGui.PushStyleColor(ImGuiCol.WindowBg, 0.08, 0.08, 0.09, 0.96)
    ImGui.PushStyleColor(ImGuiCol.TitleBg, 0.11, 0.11, 0.12, 1.0)
    ImGui.PushStyleColor(ImGuiCol.TitleBgActive, 0.14, 0.14, 0.15, 1.0)
    ImGui.PushStyleColor(ImGuiCol.Separator, 0.25, 0.25, 0.28, 0.4)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 12, 8)
    ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 6, 5)
    ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding, 2)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, 4)

    if data and data.title then
        titleCache = data.title
    elseif not titleCache then
        titleCache = "Config###Diviner"
    end
    local visible = ImGui.Begin(titleCache, 0)

    if visible then
        drawContent(data, DivGUI)
    end

    ImGui.End()
    ImGui.PopStyleVar(4)
    ImGui.PopStyleColor(4)

    return DivGUI.open
end

return DivGUI
