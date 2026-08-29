local API = require("api")

local SCRIPT_NAME = "Vampenance"
local MAGIC_SKILL = "MAGIC"

local SPELLS = {
    { name = "Vampyrism", vk = 0x31 },
    { name = "Penance", vk = 0x32 },
    { name = "Vampyrism", vk = 0x33 },
    { name = "Penance", vk = 0x34 },
}

local STOP_MODES = { "Level", "Total XP" }

local CONFIG = {
    stopMode = 0,
    targetLevel = 99,
    targetXp = 13034431,
}

local RUNTIME = {
    running = false,
    status = "Configure a target, then press Start.",
    stopIsError = false,
    startXp = 0,
    startedAt = 0,
    vampyrismCasts = 0,
    penanceCasts = 0,
    sequences = 0,
    lastCast = "None",
}

local function currentMagicXp()
    return tonumber(API.GetSkillXP(MAGIC_SKILL)) or 0
end

local function currentMagicLevel()
    local xp = currentMagicXp()
    return tonumber(API.XPLevelTable(xp)) or 0
end

local function targetReached()
    local xp = currentMagicXp()
    if CONFIG.stopMode == 0 then
        if API.XPLevelTable(xp) >= CONFIG.targetLevel then
            return true, "Magic level target reached."
        end
    elseif xp >= CONFIG.targetXp then
        return true, "Magic XP target reached."
    end
    return false, nil
end

local function validateStart()
    local currentXp = currentMagicXp()
    local currentLevel = tonumber(API.XPLevelTable(currentXp)) or 0
    if CONFIG.stopMode == 0 then
        if CONFIG.targetLevel < 1 or CONFIG.targetLevel > 120 then
            return false, "Magic level target must be between 1 and 120."
        end
        if CONFIG.targetLevel <= currentLevel then
            return false, "Magic level target is already reached."
        end
    else
        if CONFIG.targetXp <= currentXp then
            return false, "Magic XP target must be above current total XP."
        end
    end
    return true, nil
end

local function stopRun(reason, isError)
    RUNTIME.running = false
    RUNTIME.status = reason
    RUNTIME.stopIsError = isError == true
    print(string.format("[%s] Stopping: %s", SCRIPT_NAME, reason))
end

local function startRun()
    local ok, reason = validateStart()
    if not ok then
        RUNTIME.running = false
        RUNTIME.status = reason
        RUNTIME.stopIsError = true
        print(string.format("[%s] Cannot start: %s", SCRIPT_NAME, reason))
        return false
    end

    RUNTIME.running = true
    RUNTIME.status = "Casting Vampyrism and Penance."
    RUNTIME.stopIsError = false
    RUNTIME.startXp = currentMagicXp()
    RUNTIME.startedAt = API.ScriptRuntime()
    RUNTIME.vampyrismCasts = 0
    RUNTIME.penanceCasts = 0
    RUNTIME.sequences = 0
    RUNTIME.lastCast = "None"
    return true
end

local function castSequence()
    for _, spell in ipairs(SPELLS) do
        local sent = API.KeyboardPress2(spell.vk, 20, 20)
        if sent == false then
            return false, "API rejected the " .. spell.name .. " keypress."
        end
        if spell.name == "Vampyrism" then
            RUNTIME.vampyrismCasts = RUNTIME.vampyrismCasts + 1
        else
            RUNTIME.penanceCasts = RUNTIME.penanceCasts + 1
        end
        RUNTIME.lastCast = spell.name
        API.RandomSleep2(35, 10, 10)
    end
    RUNTIME.sequences = RUNTIME.sequences + 1
    return true, nil
end

local function runCastingStep()
    local reached, reason = targetReached()
    if reached then
        stopRun(reason, false)
        return
    end

    local ok, castReason = castSequence()
    if not ok then
        stopRun(castReason, true)
    end
end

local THEME = {
    blood = { 0.56, 0.08, 0.12 },
    bloodHover = { 0.72, 0.12, 0.18 },
    gold = { 0.92, 0.66, 0.20 },
    slate = { 0.08, 0.10, 0.14 },
    panel = { 0.13, 0.15, 0.20 },
    success = { 0.32, 0.82, 0.52 },
    danger = { 0.94, 0.30, 0.34 },
    muted = { 0.62, 0.66, 0.74 },
}

local function formatInteger(value)
    local text = tostring(math.floor(tonumber(value) or 0))
    local formatted = text
    while true do
        local changed
        formatted, changed = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
        if changed == 0 then return formatted end
    end
end

local function formatElapsed(seconds)
    local total = math.max(0, math.floor(tonumber(seconds) or 0))
    return string.format("%02d:%02d:%02d",
        math.floor(total / 3600),
        math.floor((total % 3600) / 60),
        total % 60)
end

local function drawGui()
    ImGui.SetNextWindowSize(460, 0, ImGuiCond.FirstUseEver)
    ImGui.SetNextWindowPos(110, 110, ImGuiCond.FirstUseEver)

    ImGui.PushStyleColor(ImGuiCol.WindowBg, THEME.slate[1], THEME.slate[2], THEME.slate[3], 0.98)
    ImGui.PushStyleColor(ImGuiCol.TitleBg, THEME.blood[1], THEME.blood[2], THEME.blood[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.TitleBgActive, THEME.bloodHover[1], THEME.bloodHover[2], THEME.bloodHover[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.FrameBg, THEME.panel[1], THEME.panel[2], THEME.panel[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.Header, THEME.blood[1], THEME.blood[2], THEME.blood[3], 0.9)
    ImGui.PushStyleColor(ImGuiCol.HeaderHovered, THEME.bloodHover[1], THEME.bloodHover[2], THEME.bloodHover[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.Button, THEME.blood[1], THEME.blood[2], THEME.blood[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, THEME.bloodHover[1], THEME.bloodHover[2], THEME.bloodHover[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.Separator, THEME.gold[1], THEME.gold[2], THEME.gold[3], 0.55)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, 7)
    ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding, 4)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 14, 12)
    ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 7, 6)

    local visible = ImGui.Begin("Vampenance###VampenanceGUI", true)
    if visible then
        ImGui.TextColored(THEME.gold[1], THEME.gold[2], THEME.gold[3], 1.0,
            "Rapid Vampyrism + Penance caster")
        ImGui.TextColored(THEME.muted[1], THEME.muted[2], THEME.muted[3], 1.0,
            "Required sequence: 1 - 2 - 3 - 4")
        ImGui.Separator()

        if not RUNTIME.running then
            local changedMode, newMode = ImGui.Combo("Stop at##vampenance_stop_mode",
                CONFIG.stopMode, STOP_MODES, #STOP_MODES)
            if changedMode then CONFIG.stopMode = newMode end

            if CONFIG.stopMode == 0 then
                local changedLevel, newLevel = ImGui.InputInt("Target Magic Level##vampenance_level",
                    CONFIG.targetLevel, 1, 5)
                if changedLevel then CONFIG.targetLevel = math.max(1, math.min(120, newLevel)) end
            else
                local changedXp, newXp = ImGui.InputInt("Target Total Magic XP##vampenance_xp",
                    CONFIG.targetXp, 1000, 10000)
                if changedXp then CONFIG.targetXp = math.max(1, newXp) end
            end

            ImGui.Text(string.format("Current Magic: level %d | %s XP",
                currentMagicLevel(), formatInteger(currentMagicXp())))

            local statusColor = RUNTIME.stopIsError and THEME.danger or THEME.muted
            ImGui.TextColored(statusColor[1], statusColor[2], statusColor[3], 1.0, RUNTIME.status)

            if ImGui.Button("Start##vampenance_start", 420, 44) then
                startRun()
            end
        else
            local elapsed = API.ScriptRuntime() - RUNTIME.startedAt
            ImGui.TextColored(THEME.success[1], THEME.success[2], THEME.success[3], 1.0, "RUNNING")
            ImGui.Text("Status: " .. RUNTIME.status)
            ImGui.Text("Runtime: " .. formatElapsed(elapsed))
            ImGui.Text("Last cast: " .. RUNTIME.lastCast)
            ImGui.Text(string.format("Sequences: %d", RUNTIME.sequences))
            ImGui.Text(string.format("Vampyrism casts: %d", RUNTIME.vampyrismCasts))
            ImGui.Text(string.format("Penance casts: %d", RUNTIME.penanceCasts))
            ImGui.Text("Magic XP gained: " .. formatInteger(currentMagicXp() - RUNTIME.startXp))

            if ImGui.Button("Stop##vampenance_stop", 420, 44) then
                stopRun("Stopped by user.", false)
            end
        end
    end

    ImGui.End()
    ImGui.PopStyleVar(4)
    ImGui.PopStyleColor(9)
end

if type(API.SetDrawLogs) == "function" then API.SetDrawLogs(true) end
if type(API.SetDrawTrackedSkills) == "function" then API.SetDrawTrackedSkills(true) end
if type(DrawImGui) == "function" then DrawImGui(drawGui) end

API.Write_LoopyLoop(true)
print("[Vampenance] Ready.")

while API.Read_LoopyLoop() do
    if type(API.DoRandomEvents) == "function" then API.DoRandomEvents() end
    if RUNTIME.running then
        runCastingStep()
    else
        API.RandomSleep2(100, 30, 30)
    end
end

print("[Vampenance] Script ended.")
