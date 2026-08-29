local API = require("api")
local Slib = require("slib")
local TravelerConfig = require("Traveler.config")
local TravelerGUI = require("Traveler.gui")

local SCRIPT_NAME = "Traveler"
local MOVE_RETRY_COOLDOWN_SECONDS = 4
local MAX_MOVE_RETRIES = 8
local MOVE_RECOVERY_RADIUS = 4
local ROUTE_ACTION_SETTLE_SECONDS = 5
local ACTION_RETRY_LIMIT = 3
local ACTION_OBJECT_WAIT_SECONDS = 2
local INTERACT_DISTANCE = 50
local DEBUG_SNAPSHOT_INTERVAL_SECONDS = 1

local THEME = {
    dark = { 0.02, 0.08, 0.10 },
    medium = { 0.04, 0.18, 0.20 },
    light = { 0.08, 0.35, 0.35 },
    bright = { 0.10, 0.60, 0.55 },
    glow = { 0.20, 0.95, 0.70 },
    accent = { 0.10, 0.90, 0.30 },
}

local STATE = {
    IDLE = "IDLE",
    TRAVELING = "TRAVELING",
    ARRIVED = "ARRIVED",
    FAILED = "FAILED",
    STOPPED = "STOPPED",
}

local UI = {
    routeName = "",
    routeConfigText = "",
    routeEditorVersion = 0,
    arrivalRadius = 2,
    selectedRouteIndex = 1,
    routeImportMessage = "",
    deleteConfirmIndex = 0,
}

local CONFIG = {
    Routes = {},
    DebugMode = false,
}

local RUNTIME = {
    state = STATE.IDLE,
    activeTarget = nil,
    activeStep = nil,
    activeRoute = nil,
    routeStepIndex = 0,
    routeStepStartedAt = 0,
    routeStepOrigin = nil,
    lastMoveAttemptAt = 0,
    lastDebugSnapshotAt = 0,
    retryCount = 0,
    lastError = "",
}

local LODESTONES = {
    ["al kharid"] = { id = 10, x = 3297, y = 3184, z = 0 },
    ["anachronia"] = { id = 24, x = 5431, y = 2338, z = 0 },
    ["ardougne"] = { id = 11, x = 2634, y = 3348, z = 0 },
    ["ashdale"] = { id = 33, x = 2474, y = 2708, z = 2 },
    ["bandit camp"] = { id = 8, x = 2899, y = 3544, z = 0 },
    ["burthorpe"] = { id = 12, x = 2899, y = 3544, z = 0 },
    ["canifis"] = { id = 26, x = 3517, y = 3515, z = 0 },
    ["catherby"] = { id = 13, x = 2811, y = 3449, z = 0 },
    ["draynor"] = { id = 14, x = 3105, y = 3298, z = 0 },
    ["draynor village"] = { id = 14, x = 3105, y = 3298, z = 0 },
    ["eagles peak"] = { id = 27, x = 2366, y = 3479, z = 0 },
    ["edgeville"] = { id = 15, x = 3067, y = 3505, z = 0 },
    ["falador"] = { id = 16, x = 2967, y = 3403, z = 0 },
    ["fort forinthry"] = { id = 22, x = 3298, y = 3525, z = 0 },
    ["fremennik"] = { id = 28, x = 2712, y = 3677, z = 0 },
    ["fremennik province"] = { id = 28, x = 2712, y = 3677, z = 0 },
    ["karamja"] = { id = 29, x = 2761, y = 3147, z = 0 },
    ["lumbridge"] = { id = 17, x = 3233, y = 3221, z = 0 },
    ["lunar isle"] = { id = 9, x = 2085, y = 3914, z = 0 },
    ["menaphos"] = { id = 23, x = 3216, y = 2716, z = 0 },
    ["ooglog"] = { id = 30, x = 2532, y = 2871, z = 0 },
    ["oo'glog"] = { id = 30, x = 2532, y = 2871, z = 0 },
    ["port sarim"] = { id = 18, x = 3011, y = 3215, z = 0 },
    ["prifddinas"] = { id = 34, x = 2208, y = 3360, z = 1 },
    ["seers village"] = { id = 19, x = 2689, y = 3482, z = 0 },
    ["seers"] = { id = 19, x = 2689, y = 3482, z = 0 },
    ["taverley"] = { id = 20, x = 2878, y = 3442, z = 0 },
    ["tirannwn"] = { id = 31, x = 2254, y = 3149, z = 0 },
    ["um"] = { id = 35, x = 1084, y = 1768, z = 1 },
    ["city of um"] = { id = 35, x = 1084, y = 1768, z = 1 },
    ["varrock"] = { id = 21, x = 3214, y = 3376, z = 0 },
    ["wilderness"] = { id = 32, x = 3143, y = 3635, z = 0 },
    ["yanille"] = { id = 25, x = 2560, y = 3094, z = 0 },
}

local ROUTE_CONSTANTS = {
    GeneralObject0 = function() return API.OFF_ACT_GeneralObject_route0 end,
    GeneralObject1 = function() return API.OFF_ACT_GeneralObject_route1 end,
    InteractNPC = function() return API.OFF_ACT_InteractNPC_route end,
    InteractNPC2 = function() return API.OFF_ACT_InteractNPC_route2 end,
    InteractNPC4 = function() return API.OFF_ACT_InteractNPC_route4 end,
    GeneralInterface = function() return API.OFF_ACT_GeneralInterface_route end,
    GeneralInterfaceRoute2 = function() return API.OFF_ACT_GeneralInterface_route2 end,
    GeneralInterfaceChooseOption = function() return API.OFF_ACT_GeneralInterface_Choose_option end,
}

local ROUTE_CONSTANT_ALIASES = {
    GeneralObject_route0 = "GeneralObject0",
    GeneralObject_route1 = "GeneralObject1",
    InteractNPC_route = "InteractNPC",
    InteractNPC_route2 = "InteractNPC2",
    InteractNPC_route4 = "InteractNPC4",
    GeneralInterface_route = "GeneralInterface",
    GeneralInterface_route2 = "GeneralInterfaceRoute2",
    GeneralInterface_Choose_option = "GeneralInterfaceChooseOption",
}

local function debugLog(message)
    if CONFIG.DebugMode ~= true then
        return
    end
    print(string.format("[%s debug] %s", SCRIPT_NAME, tostring(message or "")))
end

local function refreshRouteEditor()
    UI.routeEditorVersion = (UI.routeEditorVersion or 0) + 1
end

local function loadConfig()
    TravelerConfig.load(CONFIG, RUNTIME)
end

local function saveConfig()
    return TravelerConfig.save(CONFIG, RUNTIME)
end

local function formatCoordinates(x, y, z)
    return string.format("%d, %d, %d", math.floor(tonumber(x) or 0), math.floor(tonumber(y) or 0), math.floor(tonumber(z) or 0))
end

local function parseCoordinates(text)
    local values = {}
    for raw in tostring(text or ""):gmatch("-?%d+") do
        values[#values + 1] = tonumber(raw)
        if #values >= 3 then
            break
        end
    end

    if #values < 3 then
        return nil, "Coordinates must include X, Y, and Z"
    end

    return {
        x = math.floor(values[1]),
        y = math.floor(values[2]),
        z = math.floor(values[3]),
    }
end

local function trim(text)
    return tostring(text or ""):match("^%s*(.-)%s*$")
end

local function parseNumberToken(token)
    token = trim(token)
    if token:match("^0[xX]%x+$") then
        return tonumber(token)
    end
    return tonumber(token)
end

local function normalizeRouteConstantName(name)
    local cleanName = trim(name)
    cleanName = cleanName:gsub("^API%.", "")
    cleanName = cleanName:gsub("^OFF_ACT_", "")
    return ROUTE_CONSTANT_ALIASES[cleanName] or cleanName
end

local function getRouteConstant(name)
    local factory = ROUTE_CONSTANTS[normalizeRouteConstantName(name)]
    if not factory then
        return nil
    end
    return factory()
end

local function parseDoActionStep(payload)
    local parts = {}
    for part in tostring(payload or ""):gmatch("[^:]+") do
        parts[#parts + 1] = trim(part)
    end

    local doActionType = tostring(parts[1] or ""):lower()
    if doActionType == "object" then
        if #parts < 5 then
            return nil, "DoAction:Object:<opcode>:<route>:<id>:<distance>"
        end

        local route = getRouteConstant(parts[3])
        if not route then
            return nil, "Unsupported DoAction route: " .. tostring(parts[3])
        end

        return {
            Type = "doaction",
            type = "doaction",
            DoActionType = "object",
            Opcode = parseNumberToken(parts[2]),
            Route = route,
            RouteName = parts[3],
            Id = parseNumberToken(parts[4]),
            Distance = parseNumberToken(parts[5]) or 50,
        }
    end

    if doActionType == "npc" then
        if #parts < 5 then
            return nil, "DoAction:NPC:<opcode>:<route>:<id>:<distance>"
        end

        local route = getRouteConstant(parts[3])
        if not route then
            return nil, "Unsupported DoAction route: " .. tostring(parts[3])
        end

        return {
            Type = "doaction",
            type = "doaction",
            DoActionType = "npc",
            Opcode = parseNumberToken(parts[2]),
            Route = route,
            RouteName = parts[3],
            Id = parseNumberToken(parts[4]),
            Distance = parseNumberToken(parts[5]) or 50,
        }
    end

    if doActionType == "interface" then
        if #parts < 8 then
            return nil, "DoAction:Interface:<opcode>:<param2>:<param3>:<interfaceId>:<componentId>:<slot>:<route>"
        end

        local route = getRouteConstant(parts[8])
        if not route then
            return nil, "Unsupported DoAction route: " .. tostring(parts[8])
        end

        return {
            Type = "doaction",
            type = "doaction",
            DoActionType = "interface",
            Opcode = parseNumberToken(parts[2]),
            Param2 = parseNumberToken(parts[3]),
            Param3 = parseNumberToken(parts[4]),
            InterfaceId = parseNumberToken(parts[5]),
            ComponentId = parseNumberToken(parts[6]),
            Slot = parseNumberToken(parts[7]),
            Route = route,
            RouteName = parts[8],
        }
    end

    return nil, "Unsupported DoAction type: " .. tostring(parts[1])
end

local function parseApiInteractLine(line)
    local targetType, targetName, actionName = tostring(line or ""):match('^%s*Interact%s*:%s*(Object)%s*%(%s*"([^"]+)"%s*,%s*"([^"]+)"')
    if not targetType then
        targetType, targetName, actionName = tostring(line or ""):match('^%s*Interact%s*:%s*(NPC)%s*%(%s*"([^"]+)"%s*,%s*"([^"]+)"')
    end
    if not targetType then
        return nil
    end

    return {
        Type = "interact",
        type = "interact",
        TargetType = targetType:lower(),
        TargetName = trim(targetName),
        ActionName = trim(actionName),
        Label = "Interact:" .. targetType:lower() .. ":" .. trim(targetName) .. ":" .. trim(actionName),
    }
end

local function parseApiDoActionLine(line)
    local opcode, routeName, id, distance = tostring(line or ""):match("^%s*API%.DoAction_Object1%(%s*([^,]+)%s*,%s*([^,]+)%s*,%s*{%s*([^}]+)%s*}%s*,%s*([^%)]+)%)")
    if opcode then
        routeName = normalizeRouteConstantName(routeName)
        local route = getRouteConstant(routeName)
        if not route then
            return nil, "Unsupported DoAction route: " .. tostring(routeName)
        end

        return {
            Type = "doaction",
            type = "doaction",
            DoActionType = "object",
            Opcode = parseNumberToken(opcode),
            Route = route,
            RouteName = routeName,
            Id = parseNumberToken(id),
            Distance = parseNumberToken(distance) or 50,
            Label = "API.DoAction_Object1(0x34,API.OFF_ACT_GeneralObject_route0,{ 25339 },50)",
        }
    end

    opcode, routeName, id, distance = tostring(line or ""):match("^%s*API%.DoAction_NPC%(%s*([^,]+)%s*,%s*([^,]+)%s*,%s*{%s*([^}]+)%s*}%s*,%s*([^%)]+)%)")
    if opcode then
        routeName = normalizeRouteConstantName(routeName)
        local route = getRouteConstant(routeName)
        if not route then
            return nil, "Unsupported DoAction route: " .. tostring(routeName)
        end

        return {
            Type = "doaction",
            type = "doaction",
            DoActionType = "npc",
            Opcode = parseNumberToken(opcode),
            Route = route,
            RouteName = routeName,
            Id = parseNumberToken(id),
            Distance = parseNumberToken(distance) or 50,
            Label = "API.DoAction_NPC(0x29,API.OFF_ACT_InteractNPC_route4,{ 9710 },50)",
        }
    end

    local param2, param3, opcodeParam, interfaceId, componentId, slot, interfaceRouteName = tostring(line or ""):match("^%s*API%.DoAction_Interface%(%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^,]+)%s*,%s*([^%)]+)%)")
    if param2 then
        interfaceRouteName = normalizeRouteConstantName(interfaceRouteName)
        local route = getRouteConstant(interfaceRouteName)
        if not route then
            return nil, "Unsupported DoAction route: " .. tostring(interfaceRouteName)
        end

        return {
            Type = "doaction",
            type = "doaction",
            DoActionType = "interface",
            Opcode = parseNumberToken(param2),
            Param2 = parseNumberToken(param3),
            Param3 = parseNumberToken(opcodeParam),
            InterfaceId = parseNumberToken(interfaceId),
            ComponentId = parseNumberToken(componentId),
            Slot = parseNumberToken(slot),
            Route = route,
            RouteName = interfaceRouteName,
            Label = "API.DoAction_Interface(0xffffffff,0xffffffff,1,1465,33,-1,API.OFF_ACT_GeneralInterface_route)",
        }
    end

    return nil
end

local function parseRouteAction(line)
    local apiInteractStep = parseApiInteractLine(line)
    if apiInteractStep then
        return apiInteractStep
    end

    local apiDoActionStep, apiDoActionErr = parseApiDoActionLine(line)
    if apiDoActionErr then
        return nil, apiDoActionErr
    end
    if apiDoActionStep then
        return apiDoActionStep
    end

    local actionType, payload = tostring(line or ""):match("^%s*([%a%s]+)%s*:%s*(.-)%s*$")
    if not actionType or not payload or payload == "" then
        return nil
    end

    actionType = trim(actionType):lower()
    payload = trim(payload)

    if actionType == "teleport" then
        return {
            Type = "teleport",
            type = "teleport",
            Name = payload,
            Label = "Teleport:" .. payload,
        }
    end

    if actionType == "lodestone" then
        local key = payload:lower()
        local lodestone = LODESTONES[key]
        if not lodestone then
            return nil, "Unknown lodestone: " .. payload
        end

        return {
            Type = "lodestone",
            type = "lodestone",
            Name = payload,
            LodestoneId = lodestone.id,
            X = lodestone.x,
            Y = lodestone.y,
            Z = lodestone.z,
            Label = "Lodestone:" .. payload,
        }
    end

    if actionType == "interact" then
        local targetType, targetName, actionName = payload:match("^%s*([^:]+)%s*:%s*([^:]+)%s*:%s*(.-)%s*$")
        if not targetType or not targetName or not actionName or trim(actionName) == "" then
            return nil, "Interact step must use Interact:Object:<name>:<action> or Interact:NPC:<name>:<action>"
        end

        targetType = trim(targetType):lower()
        if targetType ~= "object" and targetType ~= "npc" then
            return nil, "Unsupported interact target type: " .. targetType
        end

        return {
            Type = "interact",
            type = "interact",
            TargetType = targetType,
            TargetName = trim(targetName),
            ActionName = trim(actionName),
            Label = "Interact:" .. targetType .. ":" .. trim(targetName) .. ":" .. trim(actionName),
        }
    end

    if actionType == "doaction" then
        return parseDoActionStep(payload)
    end

    return nil
end

local function parseRouteCoordinates(text)
    text = tostring(text or ""):gsub("\\n", "\n")
    local steps = {}
    for line in text:gmatch("[^\r\n]+") do
        local cleanLine = trim(line)
        if cleanLine ~= "" then
            local actionStep = parseApiInteractLine(cleanLine)
            local actionErr = nil
            if not actionStep then
                actionStep, actionErr = parseApiDoActionLine(cleanLine)
            end
            if not actionStep and not actionErr then
                actionStep, actionErr = parseRouteAction(cleanLine)
            end
            if actionErr then
                return nil, actionErr
            end
            if actionStep then
                steps[#steps + 1] = actionStep
            else
                local coords = parseCoordinates(cleanLine)
                if coords then
                    steps[#steps + 1] = {
                        Type = "move",
                        type = "move",
                        X = coords.x,
                        Y = coords.y,
                        Z = coords.z,
                    }
                else
                    return nil, "Invalid route step: " .. cleanLine
                end
            end
        end
    end

    if #steps == 0 then
        return nil, "Route needs at least one step"
    end

    return steps
end

local function routeStepLabel(step, index)
    local stepType = tostring(step.Type or step.type or "move"):lower()
    if stepType == "teleport" then
        return string.format("%d. Teleport: %s", index, tostring(step.Name or ""))
    end
    if stepType == "lodestone" then
        return string.format("%d. Lodestone: %s", index, tostring(step.Name or ""))
    end
    if stepType == "interact" then
        return string.format("%d. Interact %s: %s -> %s", index, tostring(step.TargetType or step.targetType or ""), tostring(step.TargetName or step.targetName or ""), tostring(step.ActionName or step.actionName or ""))
    end
    if stepType == "doaction" then
        return string.format("%d. DoAction %s: id=%s route=%s", index, tostring(step.DoActionType or step.doActionType or ""), tostring(step.Id or step.id or ""), tostring(step.RouteName or step.routeName or ""))
    end
    return string.format("%d. MoveTo: %s", index, formatCoordinates(step.X or step.x, step.Y or step.y, step.Z or step.z))
end

local function syncRouteCoordinateText(route)
    local lines = {}
    if type(route) == "table" then
        local steps = type(route.Steps) == "table" and route.Steps or route.steps
        if type(steps) == "table" then
            for _, step in ipairs(steps) do
                local stepType = tostring(step.Type or step.type or "move"):lower()
                if stepType == "teleport" then
                    lines[#lines + 1] = "Teleport:" .. tostring(step.Name or step.name or "")
                elseif stepType == "lodestone" then
                    lines[#lines + 1] = "Lodestone:" .. tostring(step.Name or step.name or "")
                elseif stepType == "interact" then
                    lines[#lines + 1] = string.format("Interact:%s:%s:%s", tostring(step.TargetType or step.targetType or "Object"), tostring(step.TargetName or step.targetName or ""), tostring(step.ActionName or step.actionName or ""))
                elseif stepType == "doaction" then
                    local actionType = tostring(step.DoActionType or step.doActionType or "Object")
                    if actionType:lower() == "interface" then
                        lines[#lines + 1] = string.format("DoAction:Interface:%s:%s:%s:%s:%s:%s:%s", tostring(step.Opcode or step.opcode), tostring(step.Param2 or step.param2), tostring(step.Param3 or step.param3), tostring(step.InterfaceId or step.interfaceId), tostring(step.ComponentId or step.componentId), tostring(step.Slot or step.slot), tostring(step.RouteName or step.routeName or "GeneralInterface"))
                    else
                        lines[#lines + 1] = string.format("DoAction:%s:%s:%s:%s:%s", actionType, tostring(step.Opcode or step.opcode), tostring(step.RouteName or step.routeName or ""), tostring(step.Id or step.id), tostring(step.Distance or step.distance or 50))
                    end
                else
                    lines[#lines + 1] = formatCoordinates(step.X or step.x, step.Y or step.y, step.Z or step.z)
                end
            end
        end
    end
    UI.routeConfigText = table.concat(lines, "\n")
end

local function clampRadius(value)
    local radius = math.floor(tonumber(value) or 2)
    if radius < 0 then
        return 0
    end
    if radius > 25 then
        return 25
    end
    return radius
end

local function routeLabels()
    local labels = {}
    for _, route in ipairs(CONFIG.Routes) do
        labels[#labels + 1] = tostring(route.Name or "Unnamed")
    end
    if #labels == 0 then
        labels[1] = "No saved routes"
    end
    return labels
end

local function normalizeRouteFromUI()
    local name = tostring(UI.routeName or ""):match("^%s*(.-)%s*$")
    if name == "" then
        return nil, "Route name is required"
    end

    local steps, err = parseRouteCoordinates(UI.routeConfigText)
    if not steps then
        return nil, err
    end

    return {
        Name = name,
        Radius = clampRadius(UI.arrivalRadius),
        Steps = steps,
    }
end

local function saveRouteFromUI()
    local route, err = normalizeRouteFromUI()
    if not route then
        RUNTIME.lastError = err
        return false
    end

    for index, saved in ipairs(CONFIG.Routes) do
        if tostring(saved.Name or "") == route.Name then
            CONFIG.Routes[index] = route
            UI.selectedRouteIndex = index
            return saveConfig()
        end
    end

    CONFIG.Routes[#CONFIG.Routes + 1] = route
    UI.selectedRouteIndex = #CONFIG.Routes
    return saveConfig()
end

local function getRouteStepType(step)
    return tostring(step.Type or step.type or "move"):lower()
end

local function routeStepPasteLine(step)
    local stepType = getRouteStepType(step)
    if stepType == "move" then
        return formatCoordinates(step.X or step.x, step.Y or step.y, step.Z or step.z)
    end
    if stepType == "lodestone" then
        return "Lodestone:" .. tostring(step.Name or step.name or "")
    end
    if stepType == "teleport" then
        return "Teleport:" .. tostring(step.Name or step.name or "")
    end
    if stepType == "interact" then
        return string.format("Interact:%s:%s:%s", tostring(step.TargetType or step.targetType or ""), tostring(step.TargetName or step.targetName or ""), tostring(step.ActionName or step.actionName or ""))
    end
    if stepType == "doaction" then
        local doActionType = tostring(step.DoActionType or step.doActionType or "")
        if doActionType == "interface" then
            return string.format(
                "DoAction:Interface:%s:%s:%s:%s:%s:%s:%s",
                tostring(step.Opcode or step.opcode or ""),
                tostring(step.Param2 or step.param2 or ""),
                tostring(step.Param3 or step.param3 or ""),
                tostring(step.InterfaceId or step.interfaceId or ""),
                tostring(step.ComponentId or step.componentId or ""),
                tostring(step.Slot or step.slot or ""),
                tostring(step.RouteName or step.routeName or "")
            )
        end
        return string.format(
            "DoAction:%s:%s:%s:%s:%s",
            doActionType,
            tostring(step.Opcode or step.opcode or ""),
            tostring(step.RouteName or step.routeName or ""),
            tostring(step.Id or step.objectOrNpcId or ""),
            tostring(step.Distance or step.distance or "")
        )
    end
    return routeStepLabel(step, 0)
end

local function printRouteStepsToConsole(route)
    if type(route) ~= "table" then
        return false
    end

    local routeName = tostring(route.Name or "Unnamed route")
    print("[Traveler] ===== ROUTE STEPS: " .. routeName .. " =====")
    local lines = {}
    local steps = route.Steps or route.steps or {}
    for _, step in ipairs(steps) do
        lines[#lines + 1] = routeStepPasteLine(step)
    end
    print(table.concat(lines, "\\n"))
    print("[Traveler] ===== END ROUTE STEPS =====")
    UI.routeConfigText = table.concat(lines, "\n")
    refreshRouteEditor()
    return true
end

local function writeRouteStepsToFile(route)
    if type(route) ~= "table" then
        return nil
    end

    local steps = type(route.Steps) == "table" and route.Steps or route.steps
    if type(steps) ~= "table" then
        return nil
    end

    local lines = {}
    for _, step in ipairs(steps) do
        lines[#lines + 1] = routeStepPasteLine(step)
    end

    return TravelerConfig.writeRouteExport(table.concat(lines, "\n"), RUNTIME)
end

local function updateSelectedRouteFromUI()
    local index = UI.selectedRouteIndex or 1
    if not CONFIG.Routes[index] then
        RUNTIME.lastError = "No saved route selected"
        return false
    end

    local route, err = normalizeRouteFromUI()
    if not route then
        RUNTIME.lastError = err
        return false
    end

    CONFIG.Routes[index] = route
    UI.selectedRouteIndex = index
    local saved = saveConfig()
    if saved then
        printRouteStepsToConsole(CONFIG.Routes[index])
        local exportPath = writeRouteStepsToFile(CONFIG.Routes[index])
        if exportPath then
            UI.routeImportMessage = "Edited route saved; exported steps to " .. tostring(exportPath)
        else
            UI.routeImportMessage = "Edited route saved; export failed"
        end
    end
    return saved
end

local function loadSelectedRoute()
    local route = CONFIG.Routes[UI.selectedRouteIndex or 1]
    if not route then
        RUNTIME.lastError = "No saved route selected"
        return false
    end

    UI.routeName = tostring(route.Name or "")
    UI.arrivalRadius = clampRadius(route.Radius)
    syncRouteCoordinateText(route)
    refreshRouteEditor()
    RUNTIME.lastError = ""
    return true
end

local function deleteSelectedRoute()
    local index = UI.selectedRouteIndex or 1
    if not CONFIG.Routes[index] then
        RUNTIME.lastError = "No saved route selected"
        return false
    end

    table.remove(CONFIG.Routes, index)
    UI.selectedRouteIndex = math.max(1, math.min(index, #CONFIG.Routes))
    return saveConfig()
end

local function selectedRoute()
    return CONFIG.Routes[UI.selectedRouteIndex or 1]
end

local function getRouteSteps(route)
    if type(route) ~= "table" then
        return {}
    end
    return type(route.Steps) == "table" and route.Steps or route.steps or {}
end

local function lodestoneInterfaceOpen()
    return (#API.ScanForInterfaceTest2Get(true, {{ 1092, 1, -1, -1, 0 }, { 1092, 54, -1, 1, 0 }}) > 0)
        or (API.Compare2874Status and API.Compare2874Status(30, false) == true)
end

local function clearRouteStepRuntime()
    RUNTIME.activeTarget = nil
    RUNTIME.activeStep = nil
    RUNTIME.routeStepStartedAt = 0
    RUNTIME.routeStepOrigin = nil
    RUNTIME.lastMoveAttemptAt = 0
    RUNTIME.retryCount = 0
end

local function startRouteStep()
    if not RUNTIME.activeRoute or type(RUNTIME.activeRoute.steps) ~= "table" then
        clearRouteStepRuntime()
        return false
    end

    local step = RUNTIME.activeRoute.steps[RUNTIME.routeStepIndex]
    if not step then
        clearRouteStepRuntime()
        return false
    end

    clearRouteStepRuntime()
    RUNTIME.activeStep = step
    debugLog(string.format(
        "Starting route step %d/%d type=%s label=%s",
        RUNTIME.routeStepIndex or 0,
        RUNTIME.activeRoute and #RUNTIME.activeRoute.steps or 0,
        getRouteStepType(step),
        tostring(step.name or step.Name or step.targetName or step.TargetName or step.actionName or step.ActionName or "-")
    ))

    if getRouteStepType(step) == "move" then
        RUNTIME.activeTarget = {
            name = string.format("%s step %d", tostring(RUNTIME.activeRoute.name or "Route"), RUNTIME.routeStepIndex),
            x = step.x,
            y = step.y,
            z = step.z,
            radius = RUNTIME.activeRoute.radius or 2,
        }
    end

    RUNTIME.lastMoveAttemptAt = 0
    RUNTIME.retryCount = 0
    return true
end

local function advanceRouteStep()
    if RUNTIME.activeRoute and RUNTIME.routeStepIndex < #RUNTIME.activeRoute.steps then
        debugLog("Route step complete; advancing from step " .. tostring(RUNTIME.routeStepIndex or 0))
        RUNTIME.routeStepIndex = RUNTIME.routeStepIndex + 1
        return startRouteStep()
    end

    RUNTIME.activeTarget = nil
    RUNTIME.activeStep = nil
    RUNTIME.state = STATE.ARRIVED
    RUNTIME.lastError = ""
    debugLog("Route arrived")
    return true
end

local function isMoving()
    return API.ReadPlayerMovin2() == true
end

local function getCurrentPositionLabel()
    local coord = API.PlayerCoord and API.PlayerCoord()
    if not coord then
        return "Current: unavailable"
    end
    return string.format("Current: %d, %d, %d", coord.x or 0, coord.y or 0, coord.z or 0)
end

local function startRoute()
    local route, err = normalizeRouteFromUI()
    if not route then
        RUNTIME.lastError = err
        RUNTIME.state = STATE.FAILED
        return false
    end

    local steps = {}
    for _, step in ipairs(route.Steps) do
        steps[#steps + 1] = {
            Type = step.Type or step.type or "move",
            type = step.Type or step.type or "move",
            name = step.Name,
            id = step.LodestoneId,
            targetType = step.TargetType,
            targetName = step.TargetName,
            actionName = step.ActionName,
            doActionType = step.DoActionType,
            opcode = step.Opcode,
            route = step.Route,
            routeName = step.RouteName,
            objectOrNpcId = step.Id,
            distance = step.Distance,
            param2 = step.Param2,
            param3 = step.Param3,
            interfaceId = step.InterfaceId,
            componentId = step.ComponentId,
            slot = step.Slot,
            x = tonumber(step.X) or 0,
            y = tonumber(step.Y) or 0,
            z = tonumber(step.Z) or 0,
        }
    end

    RUNTIME.activeRoute = {
        name = route.Name,
        steps = steps,
        radius = route.Radius or 2,
    }
    RUNTIME.routeStepIndex = 1
    RUNTIME.lastError = ""
    RUNTIME.state = STATE.TRAVELING
    RUNTIME.lastDebugSnapshotAt = 0
    debugLog("Route started: " .. tostring(RUNTIME.activeRoute.name or "-") .. " steps=" .. tostring(#RUNTIME.activeRoute.steps))

    if not startRouteStep() then
        RUNTIME.state = STATE.FAILED
        RUNTIME.lastError = "Route has no usable steps"
        debugLog("Route failed: " .. RUNTIME.lastError)
        return false
    end

    return true
end

local actionSettled

local function distanceToTarget(target)
    local coord = API.PlayerCoord and API.PlayerCoord()
    if not coord or not target then
        return nil
    end

    local dx = (tonumber(coord.x) or 0) - (tonumber(target.x) or 0)
    local dy = (tonumber(coord.y) or 0) - (tonumber(target.y) or 0)
    local dz = (tonumber(coord.z) or 0) - (tonumber(target.z) or 0)
    return math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
end

local function debugRouteSnapshot()
    if CONFIG.DebugMode ~= true then
        return
    end

    local now = os.time()
    if now - (RUNTIME.lastDebugSnapshotAt or 0) < DEBUG_SNAPSHOT_INTERVAL_SECONDS then
        return
    end
    RUNTIME.lastDebugSnapshotAt = now

    local coord = API.PlayerCoord and API.PlayerCoord()
    local position = coord and string.format("%d,%d,%d", coord.x or 0, coord.y or 0, coord.z or 0) or "unavailable"
    local step = RUNTIME.activeStep
    local stepType = step and getRouteStepType(step) or "-"
    local target = RUNTIME.activeTarget
    local distance = target and distanceToTarget(target) or nil
    local distanceText = distance and string.format("%.2f", distance) or "-"
    local targetText = target and string.format("%d,%d,%d r=%d", target.x or 0, target.y or 0, target.z or 0, target.radius or 2) or "-"
    local lastMoveAge = RUNTIME.lastMoveAttemptAt > 0 and tostring(now - RUNTIME.lastMoveAttemptAt) .. "s" or "-"
    local settleText = tostring(actionSettled())

    debugLog(string.format(
        "Traveler debug: state=%s route=%s routeStepIndex=%d/%d stepType=%s pos=%s target=%s distanceToTarget=%s retryCount=%d lastMoveAge=%s settled=%s lastError=%s",
        tostring(RUNTIME.state),
        tostring(RUNTIME.activeRoute and RUNTIME.activeRoute.name or "-"),
        RUNTIME.routeStepIndex or 0,
        RUNTIME.activeRoute and #RUNTIME.activeRoute.steps or 0,
        stepType,
        position,
        targetText,
        distanceText,
        RUNTIME.retryCount or 0,
        lastMoveAge,
        settleText,
        tostring(RUNTIME.lastError or "")
    ))
end

local function hasArrived(target)
    if Slib:IsPlayerInArea(target.x, target.y, target.z, target.radius or 2) then
        return true
    end

    local distance = distanceToTarget(target)
    return distance ~= nil and distance <= (target.radius or 2)
end

actionSettled = function()
    return not API.ReadPlayerMovin2() and not API.isProcessing() and not API.CheckAnim(50)
end

local function actionRetryLimitReached()
    return RUNTIME.retryCount >= ACTION_RETRY_LIMIT
end

local function recordActionSendFailure(retryMessage, finalMessage)
    if actionRetryLimitReached() then
        RUNTIME.state = STATE.FAILED
        RUNTIME.lastError = finalMessage
        debugLog("Route failed: " .. RUNTIME.lastError)
        return true
    end

    RUNTIME.lastError = retryMessage .. " (" .. tostring(RUNTIME.retryCount) .. "/" .. tostring(ACTION_RETRY_LIMIT) .. ")"
    debugLog(RUNTIME.lastError)
    return false
end

local function waitForRouteObjectIfPossible(step)
    if not step or step.doActionType ~= "object" or not step.objectOrNpcId then
        return true
    end
    if not Slib.WaitForObjectToAppear then
        return true
    end

    local ok, found = pcall(function()
        return Slib:WaitForObjectToAppear(step.objectOrNpcId, step.distance or 50, { 0, 1, 12 }, ACTION_OBJECT_WAIT_SECONDS)
    end)
    if not ok then
        debugLog("DoAction object wait failed: " .. tostring(found))
        return true
    end
    return found == true
end

local function rememberRouteOrigin()
    if RUNTIME.routeStepOrigin then
        return
    end

    local coord = API.PlayerCoord and API.PlayerCoord()
    if coord then
        RUNTIME.routeStepOrigin = {
            x = tonumber(coord.x) or 0,
            y = tonumber(coord.y) or 0,
            z = tonumber(coord.z) or 0,
        }
    end
end

local function tickTeleportStep(step)
    if RUNTIME.routeStepStartedAt > 0 then
        if os.time() - RUNTIME.routeStepStartedAt >= ROUTE_ACTION_SETTLE_SECONDS and actionSettled() then
            advanceRouteStep()
        end
        return
    end

    if RUNTIME.retryCount >= MAX_MOVE_RETRIES then
        RUNTIME.state = STATE.FAILED
        RUNTIME.lastError = "Teleport retry limit reached: " .. tostring(step.name or step.Name or "")
        debugLog("Route failed: " .. RUNTIME.lastError)
        return
    end

    local now = os.time()
    if now - RUNTIME.lastMoveAttemptAt < MOVE_RETRY_COOLDOWN_SECONDS then
        return
    end

    rememberRouteOrigin()
    RUNTIME.lastMoveAttemptAt = now
    RUNTIME.retryCount = RUNTIME.retryCount + 1

    local ok, used = pcall(function()
        return Slib:UseAbilityByName(tostring(step.name or step.Name or ""), true)
    end)
    if ok and used == true then
        RUNTIME.routeStepStartedAt = now
        RUNTIME.lastError = ""
        debugLog("Teleport sent: " .. tostring(step.name or step.Name or ""))
        return
    end

    RUNTIME.state = STATE.FAILED
    RUNTIME.lastError = "Teleport failed: " .. tostring(step.name or step.Name or "")
    debugLog("Route failed: " .. RUNTIME.lastError)
end

local function tickLodestoneStep(step)
    local target = {
        x = tonumber(step.x or step.X) or 0,
        y = tonumber(step.y or step.Y) or 0,
        z = tonumber(step.z or step.Z) or 0,
        radius = 20,
    }

    if hasArrived(target) then
        advanceRouteStep()
        return
    end

    if isMoving() or API.isProcessing() or API.CheckAnim(50) then
        return
    end

    if RUNTIME.retryCount >= MAX_MOVE_RETRIES then
        RUNTIME.state = STATE.FAILED
        RUNTIME.lastError = "Lodestone retry limit reached: " .. tostring(step.name or step.Name or "")
        debugLog("Route failed: " .. RUNTIME.lastError)
        return
    end

    local now = os.time()
    if now - RUNTIME.lastMoveAttemptAt < MOVE_RETRY_COOLDOWN_SECONDS then
        return
    end

    RUNTIME.lastMoveAttemptAt = now
    RUNTIME.retryCount = RUNTIME.retryCount + 1

    local clicked = false
    if lodestoneInterfaceOpen() then
        clicked = API.DoAction_Interface(0xffffffff, 0xffffffff, 1, 1092, tonumber(step.id or step.LodestoneId) or -1, -1, API.OFF_ACT_GeneralInterface_route) == true
    else
        clicked = API.DoAction_Interface(0xffffffff, 0xffffffff, 1, 1465, 33, -1, API.OFF_ACT_GeneralInterface_route) == true
    end

    if not clicked then
        RUNTIME.state = STATE.FAILED
        RUNTIME.lastError = "Lodestone click failed: " .. tostring(step.name or step.Name or "")
        debugLog("Route failed: " .. RUNTIME.lastError)
    else
        debugLog("Lodestone click sent: " .. tostring(step.name or step.Name or ""))
    end
end

local function tickInteractStep(step)
    if RUNTIME.routeStepStartedAt > 0 then
        if os.time() - RUNTIME.routeStepStartedAt >= ROUTE_ACTION_SETTLE_SECONDS and actionSettled() then
            advanceRouteStep()
        end
        return
    end

    if RUNTIME.retryCount >= ACTION_RETRY_LIMIT then
        RUNTIME.state = STATE.FAILED
        RUNTIME.lastError = "Interact retry limit reached: " .. tostring(step.targetName or "")
        debugLog("Route failed: " .. RUNTIME.lastError)
        return
    end

    local now = os.time()
    if now - RUNTIME.lastMoveAttemptAt < MOVE_RETRY_COOLDOWN_SECONDS then
        return
    end

    if not Interact then
        RUNTIME.state = STATE.FAILED
        RUNTIME.lastError = "Interact unavailable"
        debugLog("Route failed: " .. RUNTIME.lastError)
        return
    end

    RUNTIME.lastMoveAttemptAt = now
    RUNTIME.retryCount = RUNTIME.retryCount + 1

    local sent = false
    if step.targetType == "object" then
        sent = Interact:Object(step.targetName, step.actionName, nil, INTERACT_DISTANCE) == true
    elseif step.targetType == "npc" then
        sent = Interact:NPC(step.targetName, step.actionName, nil, INTERACT_DISTANCE) == true
    else
        RUNTIME.state = STATE.FAILED
        RUNTIME.lastError = "Unsupported interact target type: " .. tostring(step.targetType)
        debugLog("Route failed: " .. RUNTIME.lastError)
        return
    end

    if sent then
        RUNTIME.routeStepStartedAt = now
        RUNTIME.lastError = ""
        debugLog("Interact sent: " .. tostring(step.targetType) .. " " .. tostring(step.targetName) .. " / " .. tostring(step.actionName))
        return
    end

    recordActionSendFailure(
        "Interact send failed, retrying: " .. tostring(step.targetName or "") .. " / " .. tostring(step.actionName or ""),
        "Interact retry limit reached: " .. tostring(step.targetName or "") .. " / " .. tostring(step.actionName or "")
    )
end

local function tickDoActionStep(step)
    if RUNTIME.routeStepStartedAt > 0 then
        if os.time() - RUNTIME.routeStepStartedAt >= ROUTE_ACTION_SETTLE_SECONDS and actionSettled() then
            advanceRouteStep()
        end
        return
    end

    if RUNTIME.retryCount >= ACTION_RETRY_LIMIT then
        RUNTIME.state = STATE.FAILED
        RUNTIME.lastError = "DoAction retry limit reached"
        debugLog("Route failed: " .. RUNTIME.lastError)
        return
    end

    local now = os.time()
    if now - RUNTIME.lastMoveAttemptAt < MOVE_RETRY_COOLDOWN_SECONDS then
        return
    end

    RUNTIME.lastMoveAttemptAt = now
    RUNTIME.retryCount = RUNTIME.retryCount + 1

    if not waitForRouteObjectIfPossible(step) then
        recordActionSendFailure(
            "DoAction send failed, retrying: object not visible",
            "DoAction retry limit reached"
        )
        return
    end

    local sent = false
    if step.doActionType == "object" then
        sent = API.DoAction_Object1(step.opcode, step.route, { step.objectOrNpcId }, step.distance or 50) == true
    elseif step.doActionType == "npc" then
        sent = API.DoAction_NPC(step.opcode, step.route, { step.objectOrNpcId }, step.distance or 50) == true
    elseif step.doActionType == "interface" then
        sent = API.DoAction_Interface(step.opcode, step.param2, step.param3, step.interfaceId, step.componentId, step.slot, step.route) == true
    else
        RUNTIME.state = STATE.FAILED
        RUNTIME.lastError = "Unsupported DoAction type: " .. tostring(step.doActionType)
        debugLog("Route failed: " .. RUNTIME.lastError)
        return
    end

    if sent then
        RUNTIME.routeStepStartedAt = now
        RUNTIME.lastError = ""
        debugLog("DoAction sent: " .. tostring(step.doActionType))
        return
    end

    recordActionSendFailure(
        "DoAction send failed, retrying",
        "DoAction retry limit reached"
    )
end

local function recoverFailedMove(activeTarget)
    local distance = distanceToTarget(activeTarget)
    if distance ~= nil and distance <= math.max(activeTarget.radius or 2, MOVE_RECOVERY_RADIUS) then
        RUNTIME.lastError = string.format("Movement recovered near target: %.1f tiles away", distance)
        if RUNTIME.activeRoute then
            advanceRouteStep()
            return true
        end

        RUNTIME.state = STATE.ARRIVED
        return true
    end

    RUNTIME.state = STATE.FAILED
    RUNTIME.lastError = "Slib:MoveTo failed"
    debugLog("Route failed: " .. RUNTIME.lastError)
    return false
end

local function tickMoveStep(activeTarget)
    if hasArrived(activeTarget) then
        if RUNTIME.activeRoute then
            advanceRouteStep()
            return
        end
        RUNTIME.state = STATE.ARRIVED
        RUNTIME.lastError = ""
        return
    end

    if isMoving() then
        return
    end

    local now = os.time()
    if now - RUNTIME.lastMoveAttemptAt < MOVE_RETRY_COOLDOWN_SECONDS then
        return
    end

    if RUNTIME.retryCount >= MAX_MOVE_RETRIES then
        RUNTIME.state = STATE.FAILED
        RUNTIME.lastError = "Movement retry limit reached"
        debugLog("Route failed: " .. RUNTIME.lastError)
        return
    end

    RUNTIME.lastMoveAttemptAt = now
    RUNTIME.retryCount = RUNTIME.retryCount + 1

    local ok, result = pcall(function()
        return Slib:MoveTo(activeTarget.x, activeTarget.y, activeTarget.z)
    end)
    if not ok or result ~= true then
        return recoverFailedMove(activeTarget)
    end
    debugLog("MoveTo sent: " .. tostring(activeTarget.x) .. "," .. tostring(activeTarget.y) .. "," .. tostring(activeTarget.z))
end

local function tickRouteStep()
    if not RUNTIME.activeRoute then
        return false
    end

    local step = RUNTIME.activeStep
    if not step then
        RUNTIME.state = STATE.FAILED
        RUNTIME.lastError = "Route step missing"
        return true
    end

    local stepType = getRouteStepType(step)
    if stepType == "teleport" then
        tickTeleportStep(step)
        return true
    end
    if stepType == "lodestone" then
        tickLodestoneStep(step)
        return true
    end
    if stepType == "interact" then
        tickInteractStep(step)
        return true
    end
    if stepType == "doaction" then
        tickDoActionStep(step)
        return true
    end

    return false
end

local function tickTravel()
    if RUNTIME.state ~= STATE.TRAVELING then
        return
    end
    debugRouteSnapshot()

    if tickRouteStep() then
        return
    end

    if not RUNTIME.activeTarget then
        return
    end

    tickMoveStep(RUNTIME.activeTarget)
end

local function stopTravel()
    RUNTIME.activeTarget = nil
    RUNTIME.activeStep = nil
    RUNTIME.activeRoute = nil
    RUNTIME.routeStepIndex = 0
    RUNTIME.routeStepStartedAt = 0
    RUNTIME.routeStepOrigin = nil
    RUNTIME.state = STATE.STOPPED
end

local function stopScript()
    stopTravel()
    if API.Write_LoopyLoop then
        API.Write_LoopyLoop(false)
    end
end

local function buildGuiContext()
    return {
        UI = UI,
        CONFIG = CONFIG,
        RUNTIME = RUNTIME,
        THEME = THEME,
        routeLabels = routeLabels,
        loadSelectedRoute = loadSelectedRoute,
        selectedRoute = selectedRoute,
        getRouteSteps = getRouteSteps,
        getRouteStepType = getRouteStepType,
        routeStepLabel = routeStepLabel,
        clampRadius = clampRadius,
        parseRouteCoordinates = parseRouteCoordinates,
        saveRouteFromUI = saveRouteFromUI,
        updateSelectedRouteFromUI = updateSelectedRouteFromUI,
        deleteSelectedRoute = deleteSelectedRoute,
        startRoute = startRoute,
        stopScript = stopScript,
        getCurrentPositionLabel = getCurrentPositionLabel,
    }
end

DrawImGui(function()
    TravelerGUI.draw(buildGuiContext())
end)

loadConfig()

while API.Read_LoopyLoop() do
    API.DoRandomEvents()
    tickTravel()
    API.RandomSleep2(100, 50, 25)
end
