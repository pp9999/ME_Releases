local API = require("api")

local Config = {}

local function getScriptDirectory()
    local source = debug.getinfo(1, "S").source or ""
    source = source:gsub("^@", "")
    return source:match("^(.*[/\\])[^/\\]+$") or "Lua_Scripts\\Traveler"
end

local function getLuaScriptsDirectory()
    local dir = getScriptDirectory()
    return dir:gsub("[/\\]Traveler[/\\]?$", "")
end

local function resolveConfigPath()
    return getScriptDirectory() .. "\\traveler.config.json"
end

local function resolveLegacyConfigPath()
    return getLuaScriptsDirectory() .. "\\configs\\traveler.config.json"
end

local function resolveRouteExportPath()
    return getScriptDirectory() .. "\\traveler-last-export.txt"
end

local function readFile(path)
    local file = io.open(path, "r")
    if not file then
        return nil
    end
    local raw = file:read("*a")
    file:close()
    return raw
end

local function writeFile(path, content)
    local file = io.open(path, "w")
    if not file then
        return false
    end
    file:write(content)
    file:close()
    return true
end

local function fileExists(path)
    local file = io.open(path, "r")
    if not file then
        return false
    end
    file:close()
    return true
end

local function migrateLegacyConfig()
    local configPath = resolveConfigPath()
    if fileExists(configPath) then
        return
    end

    local legacyPath = resolveLegacyConfigPath()
    local raw = readFile(legacyPath)
    if not raw or raw == "" then
        return
    end

    writeFile(configPath, raw)
end

function Config.getPath()
    return resolveConfigPath()
end

function Config.getLegacyPath()
    return resolveLegacyConfigPath()
end

function Config.getRouteExportPath()
    return resolveRouteExportPath()
end

function Config.load(targetConfig, runtime)
    targetConfig = targetConfig or {}
    migrateLegacyConfig()

    local raw = readFile(resolveConfigPath())
    if not raw or raw == "" then
        targetConfig.Routes = {}
        targetConfig.DebugMode = targetConfig.DebugMode == true
        return targetConfig
    end

    local ok, data = pcall(API.JsonDecode, raw)
    if ok and type(data) == "table" then
        targetConfig.Routes = type(data.Routes) == "table" and data.Routes or {}
        targetConfig.DebugMode = data.DebugMode == true
    else
        targetConfig.Routes = {}
        targetConfig.DebugMode = false
        if runtime then
            runtime.lastError = "Failed to load traveler config"
        end
    end

    return targetConfig
end

function Config.save(sourceConfig, runtime)
    local ok, json = pcall(API.JsonEncode, sourceConfig or {})
    if not ok or type(json) ~= "string" then
        if runtime then
            runtime.lastError = "Failed to encode traveler config"
        end
        return false
    end

    local path = resolveConfigPath()
    if not writeFile(path, json) then
        if runtime then
            runtime.lastError = "Failed to open traveler config for write: " .. tostring(path)
        end
        return false
    end

    return true
end

function Config.writeRouteExport(content, runtime)
    local path = resolveRouteExportPath()
    if not writeFile(path, content or "") then
        if runtime then
            runtime.lastError = "Failed to export route steps: " .. tostring(path)
        end
        return nil
    end
    return path
end

return Config
