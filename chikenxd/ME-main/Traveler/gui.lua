local Gui = {}

local function theme(ctx)
    return ctx.THEME or {
        dark = { 0.02, 0.08, 0.10 },
        medium = { 0.04, 0.18, 0.20 },
        light = { 0.08, 0.35, 0.35 },
        bright = { 0.10, 0.60, 0.55 },
        glow = { 0.20, 0.95, 0.70 },
        accent = { 0.10, 0.90, 0.30 },
    }
end

local function quietText(ctx, text)
    ImGui.PushStyleColor(ImGuiCol.Text, 0.68, 0.78, 0.76, 1.0)
    ImGui.TextWrapped(tostring(text or ""))
    ImGui.PopStyleColor(1)
end

local function statRow(ctx, label, value)
    local t = theme(ctx)
    ImGui.Text(label)
    ImGui.SameLine()
    ImGui.PushStyleColor(ImGuiCol.Text, t.accent[1], t.accent[2], t.accent[3], 1.0)
    ImGui.TextWrapped(tostring(value))
    ImGui.PopStyleColor(1)
end

local function drawRouteStepTable(ctx, route, tableId, maxRows)
    local steps = ctx.getRouteSteps(route)
    if #steps == 0 then
        quietText(ctx, "No route steps saved.")
        return
    end

    if ImGui.BeginTable(tableId, 3) then
        ImGui.TableSetupColumn("#", ImGuiTableColumnFlags.WidthFixed, 34)
        ImGui.TableSetupColumn("Type", ImGuiTableColumnFlags.WidthFixed, 90)
        ImGui.TableSetupColumn("Step", ImGuiTableColumnFlags.WidthStretch, 1.0)
        if ImGui.TableHeadersRow then
            ImGui.TableHeadersRow()
        end

        for index, step in ipairs(steps) do
            if maxRows and index > maxRows then
                ImGui.TableNextRow()
                ImGui.TableNextColumn()
                ImGui.Text("...")
                ImGui.TableNextColumn()
                ImGui.Text("")
                ImGui.TableNextColumn()
                quietText(ctx, tostring(#steps - maxRows) .. " more steps")
                break
            end

            ImGui.TableNextRow()
            ImGui.TableNextColumn()
            ImGui.Text(tostring(index))
            ImGui.TableNextColumn()
            ImGui.Text(tostring(ctx.getRouteStepType(step)))
            ImGui.TableNextColumn()
            ImGui.TextWrapped(ctx.routeStepLabel(step, index):gsub("^%d+%.%s*", ""))
        end

        ImGui.EndTable()
    end
end

local function drawSavedRoutePicker(ctx)
    local t = theme(ctx)
    ImGui.PushStyleColor(ImGuiCol.Text, t.glow[1], t.glow[2], t.glow[3], 1.0)
    ImGui.TextWrapped("Saved Routes")
    ImGui.PopStyleColor(1)

    local routeLabelsList = ctx.routeLabels()
    local changedRouteSelected, newRouteSelected = ImGui.Combo("Saved Routes##traveler_saved_routes", (ctx.UI.selectedRouteIndex or 1) - 1, routeLabelsList, #routeLabelsList)
    if changedRouteSelected then
        ctx.UI.selectedRouteIndex = newRouteSelected + 1
        ctx.UI.deleteConfirmIndex = 0
        ctx.loadSelectedRoute()
    end
end

local function drawSelectedRoutePreview(ctx)
    local t = theme(ctx)
    ImGui.PushStyleColor(ImGuiCol.Text, t.glow[1], t.glow[2], t.glow[3], 1.0)
    ImGui.TextWrapped("Selected Route")
    ImGui.PopStyleColor(1)

    local route = ctx.selectedRoute()
    if not route then
        quietText(ctx, "No saved route selected.")
        return
    end

    local steps = ctx.getRouteSteps(route)
    statRow(ctx, "Name:", tostring(route.Name or "Unnamed"))
    statRow(ctx, "Steps:", tostring(#steps))
    statRow(ctx, "Radius:", tostring(ctx.clampRadius(route.Radius)))
    ImGui.Spacing()
    drawRouteStepTable(ctx, route, "##traveler_selected_route_steps", 10)
end

local function drawRouteTab(ctx)
    local t = theme(ctx)
    drawSavedRoutePicker(ctx)

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    drawSelectedRoutePreview(ctx)

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    ImGui.PushStyleColor(ImGuiCol.Button, t.accent[1], t.accent[2], t.accent[3], 0.92)
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, t.glow[1], t.glow[2], t.glow[3], 0.95)
    ImGui.PushStyleColor(ImGuiCol.ButtonActive, t.glow[1], t.glow[2], t.glow[3], 1.0)
    if ImGui.Button("Start Route##traveler_start_route", -1, 30) then
        ctx.startRoute()
    end
    ImGui.PopStyleColor(3)

    ImGui.Spacing()

    ImGui.PushStyleColor(ImGuiCol.Button, 0.5, 0.15, 0.15, 0.9)
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.6, 0.2, 0.2, 1.0)
    ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.7, 0.25, 0.25, 1.0)
    if ImGui.Button("Stop Script", -1, 28) then
        ctx.stopScript()
    end
    ImGui.PopStyleColor(3)
end

local function drawSyntaxReference(ctx)
    ImGui.Text("Route Syntax")
    ImGui.Spacing()

    if ImGui.BeginTable("##traveler_syntax_table", 3) then
        ImGui.TableSetupColumn("Type", ImGuiTableColumnFlags.WidthFixed, 100)
        ImGui.TableSetupColumn("Syntax", ImGuiTableColumnFlags.WidthStretch, 0.50)
        ImGui.TableSetupColumn("Example", ImGuiTableColumnFlags.WidthStretch, 0.50)
        if ImGui.TableHeadersRow then
            ImGui.TableHeadersRow()
        end

        local rows = {
            { "Move", "x, y, z", "5430, 2404, 0" },
            { "Lodestone", "Lodestone:<name>", "Lodestone:Lumbridge" },
            { "Teleport", "Teleport:<ability>", "Teleport:War's Retreat Teleport" },
            { "Object", "Interact:Object:<name>:<action>", "Interact:Object:Campfire:Warm hands" },
            { "NPC", "Interact:NPC:<name>:<action>", "Interact:NPC:Banker:Bank" },
            { "Object ID", "DoAction:Object:<opcode>:<route>:<id>:<distance>", "DoAction:Object:0x29:GeneralObject0:12345:50" },
            { "NPC ID", "DoAction:NPC:<opcode>:<route>:<id>:<distance>", "DoAction:NPC:0x29:InteractNPC4:9710:50" },
            { "Interface", "DoAction:Interface:<opcode>:<param2>:<param3>:<interfaceId>:<componentId>:<slot>:<route>", "DoAction:Interface:0xffffffff:0xffffffff:1:1465:33:-1:GeneralInterface" },
        }

        for _, row in ipairs(rows) do
            ImGui.TableNextRow()
            ImGui.TableNextColumn()
            ImGui.TextWrapped(row[1])
            ImGui.TableNextColumn()
            quietText(ctx, row[2])
            ImGui.TableNextColumn()
            ImGui.TextWrapped(row[3])
        end

        ImGui.EndTable()
    end
end

local function drawSupportedRouteConstants(ctx)
    ImGui.Text("Supported DoAction routes")
    ImGui.Spacing()

    if ImGui.BeginTable("##traveler_routes_table", 2) then
        ImGui.TableSetupColumn("Group", ImGuiTableColumnFlags.WidthFixed, 120)
        ImGui.TableSetupColumn("Routes", ImGuiTableColumnFlags.WidthStretch, 1.0)
        if ImGui.TableHeadersRow then
            ImGui.TableHeadersRow()
        end

        local rows = {
            { "Object", "GeneralObject0, GeneralObject1" },
            { "NPC", "InteractNPC, InteractNPC2, InteractNPC4" },
            { "Interface", "GeneralInterface, GeneralInterfaceRoute2, GeneralInterfaceChooseOption" },
        }

        for _, row in ipairs(rows) do
            ImGui.TableNextRow()
            ImGui.TableNextColumn()
            ImGui.TextWrapped(row[1])
            ImGui.TableNextColumn()
            quietText(ctx, row[2])
        end

        ImGui.EndTable()
    end
end

local function drawRawCallExamples(ctx)
    ImGui.Text("Raw call examples")
    ImGui.Spacing()

    if ImGui.BeginTable("##traveler_raw_examples_table", 2) then
        ImGui.TableSetupColumn("Call", ImGuiTableColumnFlags.WidthFixed, 100)
        ImGui.TableSetupColumn("Example", ImGuiTableColumnFlags.WidthStretch, 1.0)
        if ImGui.TableHeadersRow then
            ImGui.TableHeadersRow()
        end

        local rows = {
            { "Interact", 'Interact:Object("Bank chest", "Use")' },
            { "Object", "API.DoAction_Object1(0x34,API.OFF_ACT_GeneralObject_route0,{ 25339 },50)" },
            { "NPC", "API.DoAction_NPC(0x29,API.OFF_ACT_InteractNPC_route4,{ 9710 },50)" },
            { "Interface", "API.DoAction_Interface(0xffffffff,0xffffffff,1,1465,33,-1,API.OFF_ACT_GeneralInterface_route)" },
            { "Choice", "API.DoAction_Interface(0xffffffff,0xffffffff,0,720,26,-1,API.OFF_ACT_GeneralInterface_Choose_option)" },
        }

        for _, row in ipairs(rows) do
            ImGui.TableNextRow()
            ImGui.TableNextColumn()
            ImGui.TextWrapped(row[1])
            ImGui.TableNextColumn()
            quietText(ctx, row[2])
        end

        ImGui.EndTable()
    end
end

local function drawBuilderTab(ctx)
    ImGui.Text("Name")
    ImGui.PushItemWidth(-1)
    local changedRouteName, newRouteName = ImGui.InputText("##traveler_route_name", ctx.UI.routeName or "", 128)
    ImGui.PopItemWidth()
    if changedRouteName then
        ctx.UI.routeName = newRouteName
    end

    ImGui.Spacing()
    ImGui.Text("Route Config")
    local routeConfigLabel = "##traveler_route_config_" .. tostring(ctx.UI.routeEditorVersion or 0)
    ImGui.PushItemWidth(-1)
    local changedRouteConfig, newRouteConfig = ImGui.InputTextMultiline(routeConfigLabel, ctx.UI.routeConfigText or "", -1, 130)
    ImGui.PopItemWidth()
    if changedRouteConfig then
        ctx.UI.routeConfigText = newRouteConfig
    end

    ImGui.Spacing()
    ImGui.Text("Arrival Radius")
    ImGui.PushItemWidth(110)
    local changedRadius, newRadius = ImGui.InputInt("##traveler_arrival_radius", ctx.UI.arrivalRadius or 2)
    ImGui.PopItemWidth()
    if changedRadius then
        ctx.UI.arrivalRadius = ctx.clampRadius(newRadius)
    end

    local routeSteps, routeErr = ctx.parseRouteCoordinates(ctx.UI.routeConfigText)
    local routeStepCount = type(routeSteps) == "table" and #routeSteps or 0
    local t = theme(ctx)
    ImGui.PushStyleColor(ImGuiCol.Text, t.accent[1], t.accent[2], t.accent[3], 1.0)
    ImGui.TextWrapped("Parsed route steps: " .. tostring(routeStepCount))
    if ctx.UI.routeImportMessage ~= "" then
        ImGui.TextWrapped(ctx.UI.routeImportMessage)
    end
    if type(routeErr) == "string" and routeErr ~= "" then
        ImGui.TextWrapped(routeErr)
    end
    ImGui.PopStyleColor(1)
    if type(routeSteps) == "table" then
        drawRouteStepTable(ctx, { Steps = routeSteps }, "##traveler_builder_parsed_steps", 8)
    end

    ImGui.Spacing()
    ImGui.Text("Saved Routes")
    local routeLabelsList = ctx.routeLabels()
    ImGui.PushItemWidth(-1)
    local changedRouteSelected, newRouteSelected = ImGui.Combo("##traveler_builder_saved_routes", (ctx.UI.selectedRouteIndex or 1) - 1, routeLabelsList, #routeLabelsList)
    ImGui.PopItemWidth()
    if changedRouteSelected then
        ctx.UI.selectedRouteIndex = newRouteSelected + 1
        ctx.loadSelectedRoute()
    end

    ImGui.Spacing()
    if ImGui.Button("Save Route", 150, 28) then
        ctx.UI.deleteConfirmIndex = 0
        ctx.saveRouteFromUI()
    end
    ImGui.SameLine()
    if ImGui.Button("Update", 150, 28) then
        ctx.UI.deleteConfirmIndex = 0
        ctx.updateSelectedRouteFromUI()
    end
    ImGui.SameLine()
    if ctx.UI.deleteConfirmIndex == (ctx.UI.selectedRouteIndex or 1) and ctx.CONFIG.Routes[ctx.UI.selectedRouteIndex or 1] then
        if ImGui.Button("Confirm Delete##traveler_confirm_delete", 150, 28) then
            ctx.deleteSelectedRoute()
            ctx.UI.deleteConfirmIndex = 0
        end
    else
        if ImGui.Button("Delete Route", 150, 28) then
            local index = ctx.UI.selectedRouteIndex or 1
            ctx.UI.deleteConfirmIndex = index
        end
    end
end

local function drawInformationTab(ctx)
    drawSyntaxReference(ctx)
    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()
    drawSupportedRouteConstants(ctx)
    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()
    drawRawCallExamples(ctx)
end

local function drawRuntimeStatus(ctx)
    ImGui.Text("Runtime")
    statRow(ctx, "State:", tostring(ctx.RUNTIME.state))
    statRow(ctx, "Position:", ctx.getCurrentPositionLabel():gsub("^Current:%s*", ""))
    if ctx.RUNTIME.activeRoute then
        statRow(ctx, "Route:", tostring(ctx.RUNTIME.activeRoute.name or "-"))
        statRow(ctx, "Step:", string.format("Step %d / %d", ctx.RUNTIME.routeStepIndex or 0, #ctx.RUNTIME.activeRoute.steps))
    end
    if ctx.RUNTIME.activeTarget then
        statRow(ctx, "Target:", string.format("%d, %d, %d radius %d", ctx.RUNTIME.activeTarget.x, ctx.RUNTIME.activeTarget.y, ctx.RUNTIME.activeTarget.z, ctx.RUNTIME.activeTarget.radius or 2))
    end
    statRow(ctx, "Retries:", tostring(ctx.RUNTIME.retryCount or 0))
    if ctx.RUNTIME.lastError ~= "" then
        ImGui.PushStyleColor(ImGuiCol.Text, 1.0, 0.55, 0.35, 1.0)
        ImGui.TextWrapped("Last error: " .. tostring(ctx.RUNTIME.lastError))
        ImGui.PopStyleColor(1)
    end
end

function Gui.draw(ctx)
    local t = theme(ctx)
    ImGui.SetNextWindowSize(640, 0, ImGuiCond.FirstUseEver)
    ImGui.SetNextWindowPos(100, 100, ImGuiCond.FirstUseEver)

    ImGui.PushStyleColor(ImGuiCol.WindowBg, t.dark[1], t.dark[2], t.dark[3], 0.97)
    ImGui.PushStyleColor(ImGuiCol.TitleBg, t.medium[1] * 0.6, t.medium[2] * 0.6, t.medium[3] * 0.6, 1.0)
    ImGui.PushStyleColor(ImGuiCol.TitleBgActive, t.medium[1], t.medium[2], t.medium[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.Separator, t.light[1], t.light[2], t.light[3], 0.4)
    ImGui.PushStyleColor(ImGuiCol.Tab, t.medium[1], t.medium[2], t.medium[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.TabHovered, t.light[1], t.light[2], t.light[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.TabActive, t.bright[1], t.bright[2], t.bright[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.FrameBg, 0.05, 0.16, 0.18, 0.98)
    ImGui.PushStyleColor(ImGuiCol.FrameBgHovered, 0.09, 0.28, 0.30, 1.0)
    ImGui.PushStyleColor(ImGuiCol.FrameBgActive, 0.12, 0.38, 0.38, 1.0)
    ImGui.PushStyleColor(ImGuiCol.PopupBg, 0.03, 0.11, 0.13, 0.99)
    ImGui.PushStyleColor(ImGuiCol.Border, 0.12, 0.55, 0.52, 0.80)
    ImGui.PushStyleColor(ImGuiCol.SliderGrab, t.bright[1], t.bright[2], t.bright[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.SliderGrabActive, t.glow[1], t.glow[2], t.glow[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.CheckMark, t.glow[1], t.glow[2], t.glow[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.Header, 0.07, 0.25, 0.27, 0.90)
    ImGui.PushStyleColor(ImGuiCol.HeaderHovered, 0.12, 0.40, 0.40, 1.0)
    ImGui.PushStyleColor(ImGuiCol.HeaderActive, 0.14, 0.52, 0.49, 1.0)
    ImGui.PushStyleColor(ImGuiCol.Text, 1.0, 1.0, 1.0, 1.0)

    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 14, 10)
    ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 6, 4)
    ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding, 4)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, 6)
    ImGui.PushStyleVar(ImGuiStyleVar.TabRounding, 4)

    local visible = ImGui.Begin("Traveler###TravelerGUI", true)
    if visible then
        if ImGui.BeginTabBar("##traveler_tabs", 0) then
            if ImGui.BeginTabItem("Route##traveler_tab_route", nil, 0) then
                drawRouteTab(ctx)
                ImGui.EndTabItem()
            end
            if ImGui.BeginTabItem("Route Builder##traveler_tab_route_builder", nil, 0) then
                drawBuilderTab(ctx)
                ImGui.EndTabItem()
            end
            if ImGui.BeginTabItem("Information##traveler_tab_information", nil, 0) then
                drawInformationTab(ctx)
                ImGui.EndTabItem()
            end
            ImGui.EndTabBar()
        end
    end
    ImGui.PopStyleVar(5)
    ImGui.PopStyleColor(19)
    ImGui.End()
end

Gui.drawRuntimeStatus = drawRuntimeStatus

return Gui
