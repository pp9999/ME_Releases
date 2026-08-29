--- @module 'SerenStonesGUI'
--- ImGui GUI for Seren Stones using the Necro Rituals shell as layout reference.

local API = require("api")

local SerenGUI = {}

SerenGUI.open = true
SerenGUI.started = false
SerenGUI.stopped = false
SerenGUI.selectConfigTab = true
SerenGUI.selectInfoTab = false

SerenGUI.config = {
    purchaseCrystalsIfNeeded = true,
    targetCrystalCount = 30,
    enableWorldHop = false,
    hopOnNearbyPlayer = false,
    hopIntervalMin = 45,
    hopIntervalMax = 90,
    nearbyRange = 20,
}

local SEREN = {
    dark = { 0.04, 0.08, 0.10 },
    medium = { 0.08, 0.15, 0.18 },
    light = { 0.12, 0.24, 0.28 },
    bright = { 0.42, 0.76, 0.86 },
    glow = { 0.65, 0.92, 0.98 },
    accent = { 0.63, 0.86, 0.71 },
}

local function row(label, value, vr, vg, vb)
    ImGui.TableNextRow()
    ImGui.TableNextColumn()
    ImGui.TextWrapped(label)
    ImGui.TableNextColumn()
    if vr then
        ImGui.PushStyleColor(ImGuiCol.Text, vr, vg, vb, 1.0)
        ImGui.TextWrapped(value)
        ImGui.PopStyleColor(1)
    else
        ImGui.TextWrapped(value)
    end
end

local function sectionHeader(text)
    ImGui.PushStyleColor(ImGuiCol.Text, SEREN.glow[1], SEREN.glow[2], SEREN.glow[3], 1.0)
    ImGui.TextWrapped(text)
    ImGui.PopStyleColor(1)
end

local function flavorText(text)
    ImGui.PushStyleColor(ImGuiCol.Text, 0.62, 0.84, 0.88, 1.0)
    ImGui.TextWrapped(text)
    ImGui.PopStyleColor(1)
end

local function drawConfigTab(cfg, gui, data)
    ImGui.PushItemWidth(250)

    sectionHeader("Crystals")
    flavorText("Choose whether Seren should buy more cleansing crystals or stop when inventory runs out.")
    ImGui.Spacing()

    local changedPurchase, newPurchase = ImGui.Checkbox("Purchase crystals if needed##seren_buy_crystals", cfg.purchaseCrystalsIfNeeded)
    if changedPurchase then
        cfg.purchaseCrystalsIfNeeded = newPurchase
    end

    ImGui.Text("Target Crystal Count")
    local changedTarget, newTarget = ImGui.SliderInt("##seren_target_crystals", cfg.targetCrystalCount, 1, 30)
    if changedTarget then
        cfg.targetCrystalCount = newTarget
    end

    sectionHeader("World Hop")
    flavorText("Configure modern world hopping and nearby-player escape behavior.")
    ImGui.Spacing()

    local changedHop, newHop = ImGui.Checkbox("Enable World Hopping##seren_hop", cfg.enableWorldHop)
    if changedHop then
        cfg.enableWorldHop = newHop
    end

    local changedNearby, newNearby = ImGui.Checkbox("Hop If Player Nearby##seren_hop_near", cfg.hopOnNearbyPlayer)
    if changedNearby then
        cfg.hopOnNearbyPlayer = newNearby
    end

    ImGui.Spacing()

    ImGui.Text("Minimum Minutes")
    local changedMin, newMin = ImGui.SliderInt("##seren_hop_min", cfg.hopIntervalMin, 5, 180)
    if changedMin then
        cfg.hopIntervalMin = newMin
        if cfg.hopIntervalMax < newMin then
            cfg.hopIntervalMax = newMin
        end
    end

    ImGui.Text("Maximum Minutes")
    local changedMax, newMax = ImGui.SliderInt("##seren_hop_max", cfg.hopIntervalMax, 5, 180)
    if changedMax then
        cfg.hopIntervalMax = newMax
        if cfg.hopIntervalMin > newMax then
            cfg.hopIntervalMin = newMax
        end
    end

    ImGui.Text("Nearby Player Range")
    local changedRange, newRange = ImGui.SliderInt("##seren_nearby_range", cfg.nearbyRange, 5, 40)
    if changedRange then
        cfg.nearbyRange = newRange
    end

    ImGui.PopItemWidth()

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    ImGui.PushStyleColor(ImGuiCol.Button, SEREN.bright[1], SEREN.bright[2], SEREN.bright[3], 0.88)
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, SEREN.glow[1], SEREN.glow[2], SEREN.glow[3], 0.96)
    ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.34, 0.86, 0.90, 1.0)
    if ImGui.Button("Start Seren Stones##seren_start", -1, 32) and not (data and data.running == true) then
        gui.started = true
        gui.stopped = false
    end
    ImGui.PopStyleColor(3)

    ImGui.Spacing()

    ImGui.PushStyleColor(ImGuiCol.Button, 0.52, 0.18, 0.16, 0.92)
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.63, 0.23, 0.20, 1.0)
    ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.72, 0.28, 0.24, 1.0)
    if ImGui.Button("Stop Script##seren_stop", -1, 28) then
        gui.stopped = true
    end
    ImGui.PopStyleColor(3)
end

local function drawInfoTab(data)
    sectionHeader("XP")
    if ImGui.BeginTable("##seren_info_xp", 2) then
        ImGui.TableSetupColumn("Label", ImGuiTableColumnFlags.WidthStretch, 0.42)
        ImGui.TableSetupColumn("Value", ImGuiTableColumnFlags.WidthStretch, 0.58)
        row("Status", tostring(data.state or "Idle"), SEREN.glow[1], SEREN.glow[2], SEREN.glow[3])
        row("Session XP", tostring(data.xpTotalText or "0"))
        row("XP/Hr", tostring(data.xpPerHourText or "0"))
        ImGui.EndTable()
    end

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()
    sectionHeader("Crystals")
    if ImGui.BeginTable("##seren_info_crystals", 2) then
        ImGui.TableSetupColumn("Label", ImGuiTableColumnFlags.WidthStretch, 0.42)
        ImGui.TableSetupColumn("Value", ImGuiTableColumnFlags.WidthStretch, 0.58)
        row("Crystals Purchased", tostring(data.crystalsPurchased or 0))
        row("Crystals Used", tostring(data.crystalsUsed or 0))
        ImGui.EndTable()
    end

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()
    sectionHeader("World Hop")
    if ImGui.BeginTable("##seren_info_hop", 2) then
        ImGui.TableSetupColumn("Label", ImGuiTableColumnFlags.WidthStretch, 0.42)
        ImGui.TableSetupColumn("Value", ImGuiTableColumnFlags.WidthStretch, 0.58)
        row("World Hops", tostring(data.worldHops or 0))
        row("Current World", tostring(data.currentWorld or "?"))
        row("Next Hop", tostring(data.nextHopText or "Disabled"))
        ImGui.EndTable()
    end

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()
    sectionHeader("Failsafe")
    if ImGui.BeginTable("##seren_info_failsafe", 2) then
        ImGui.TableSetupColumn("Label", ImGuiTableColumnFlags.WidthStretch, 0.42)
        ImGui.TableSetupColumn("Value", ImGuiTableColumnFlags.WidthStretch, 0.58)
        row("Prayer XP Failsafe", tostring(data.xpFailsafeText or "Ready"))
        ImGui.EndTable()
    end
end

local function drawContent(data, gui)
    local currentState = data.state or "Idle"
    local statusColor = (data.running == true) and { 0.4, 0.8, 0.4 } or { 1.0, 0.82, 0.35 }

    ImGui.PushStyleColor(ImGuiCol.Text, statusColor[1], statusColor[2], statusColor[3], 1.0)
    ImGui.TextWrapped("Status: " .. currentState)
    ImGui.PopStyleColor(1)
    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    if ImGui.BeginTabBar("##seren_tabs", 0) then
        local configFlags = gui.selectConfigTab and ImGuiTabItemFlags.SetSelected or 0
        gui.selectConfigTab = false
        if ImGui.BeginTabItem("Config###seren_config", nil, configFlags) then
            ImGui.Spacing()
            drawConfigTab(gui.config, gui, data)
            ImGui.EndTabItem()
        end

        local infoFlags = gui.selectInfoTab and ImGuiTabItemFlags.SetSelected or 0
        gui.selectInfoTab = false
        if ImGui.BeginTabItem("Info###seren_info", nil, infoFlags) then
            ImGui.Spacing()
            drawInfoTab(data)
            ImGui.EndTabItem()
        end

        ImGui.EndTabBar()
    end
end

function SerenGUI.consumeStartRequest()
    if SerenGUI.started then
        SerenGUI.started = false
        return true
    end
    return false
end

function SerenGUI.consumeStopRequest()
    if SerenGUI.stopped then
        SerenGUI.stopped = false
        return true
    end
    return false
end

function SerenGUI.getConfig()
    return SerenGUI.config
end

function SerenGUI.draw(data)
    data = data or {}

    ImGui.SetNextWindowSize(640, 0, ImGuiCond.Always)
    ImGui.SetNextWindowPos(100, 100, ImGuiCond.FirstUseEver)

    ImGui.PushStyleColor(ImGuiCol.WindowBg, SEREN.dark[1], SEREN.dark[2], SEREN.dark[3], 0.97)
    ImGui.PushStyleColor(ImGuiCol.TitleBg, SEREN.medium[1] * 0.6, SEREN.medium[2] * 0.6, SEREN.medium[3] * 0.6, 1.0)
    ImGui.PushStyleColor(ImGuiCol.TitleBgActive, SEREN.medium[1], SEREN.medium[2], SEREN.medium[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.Separator, SEREN.light[1], SEREN.light[2], SEREN.light[3], 0.4)
    ImGui.PushStyleColor(ImGuiCol.Tab, SEREN.medium[1], SEREN.medium[2], SEREN.medium[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.TabHovered, SEREN.light[1], SEREN.light[2], SEREN.light[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.TabActive, SEREN.bright[1], SEREN.bright[2], SEREN.bright[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.FrameBg, 0.05, 0.16, 0.18, 0.98)
    ImGui.PushStyleColor(ImGuiCol.FrameBgHovered, 0.09, 0.28, 0.30, 1.0)
    ImGui.PushStyleColor(ImGuiCol.FrameBgActive, 0.12, 0.38, 0.38, 1.0)
    ImGui.PushStyleColor(ImGuiCol.PopupBg, 0.03, 0.11, 0.13, 0.99)
    ImGui.PushStyleColor(ImGuiCol.Border, 0.12, 0.55, 0.52, 0.80)
    ImGui.PushStyleColor(ImGuiCol.SliderGrab, SEREN.bright[1], SEREN.bright[2], SEREN.bright[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.SliderGrabActive, SEREN.glow[1], SEREN.glow[2], SEREN.glow[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.CheckMark, SEREN.glow[1], SEREN.glow[2], SEREN.glow[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.Header, 0.07, 0.25, 0.27, 0.90)
    ImGui.PushStyleColor(ImGuiCol.HeaderHovered, 0.12, 0.40, 0.40, 1.0)
    ImGui.PushStyleColor(ImGuiCol.HeaderActive, 0.14, 0.52, 0.49, 1.0)
    ImGui.PushStyleColor(ImGuiCol.Text, 1.0, 1.0, 1.0, 1.0)

    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 14, 10)
    ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 6, 4)
    ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding, 4)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, 6)
    ImGui.PushStyleVar(ImGuiStyleVar.TabRounding, 4)

    local visible = ImGui.Begin("Seren Stones###SerenGUI", true)
    if visible then
        local ok, err = pcall(drawContent, data, SerenGUI)
        if not ok then
            ImGui.TextColored(1.0, 0.3, 0.3, 1.0, "Error: " .. tostring(err))
        end
    end

    ImGui.PopStyleVar(5)
    ImGui.PopStyleColor(19)
    ImGui.End()

    return SerenGUI.open
end

return SerenGUI