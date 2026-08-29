local module = {}

function module.register(context)
    local model = assert(context and context.model, "BankstanderererGUI.register requires a model")
    local RUNTIME = assert(context.runtime, "BankstanderererGUI.register requires runtime state")
    local startScript = assert(context.startScript, "BankstanderererGUI.register requires startScript callback")
    local stopScript = assert(context.stopScript, "BankstanderererGUI.register requires stopScript callback")
    local getRuntimeLabel = assert(context.getRuntimeLabel, "BankstanderererGUI.register requires getRuntimeLabel callback")
    local shouldLoadPresetAtStart = assert(context.shouldLoadPresetAtStart, "BankstanderererGUI.register requires shouldLoadPresetAtStart callback")

    local CONFIG = model.CONFIG
    local PROFILES = model.PROFILES
    local Gui = model.Gui
    local THEME = model.THEME
    local ITEM_CLICK_MODE_OPTIONS = model.ITEM_CLICK_MODE_OPTIONS
    local PROFILE_INTERFACE_MODE_OPTIONS = model.PROFILE_INTERFACE_MODE_OPTIONS
    local PROCESSING_CONFIRMATION_OPTIONS = model.PROCESSING_CONFIRMATION_OPTIONS

    local function sectionHeader(text)
        ImGui.PushStyleColor(ImGuiCol.Text, THEME.glow[1], THEME.glow[2], THEME.glow[3], 1.0)
        ImGui.TextWrapped(text)
        ImGui.PopStyleColor(1)
    end

    local function statRow(label, value)
        ImGui.TextWrapped(label)
        ImGui.SameLine()
        ImGui.PushStyleColor(ImGuiCol.Text, THEME.accent[1], THEME.accent[2], THEME.accent[3], 1.0)
        ImGui.TextWrapped(value)
        ImGui.PopStyleColor(1)
    end

    local function helpMarker(id, text)
        ImGui.SameLine()
        ImGui.PushStyleColor(ImGuiCol.Text, THEME.glow[1], THEME.glow[2], THEME.glow[3], 1.0)
        ImGui.Button("?##" .. tostring(id or "help"), 18, 18)
        ImGui.PopStyleColor(1)
        if ImGui.IsItemHovered and ImGui.IsItemHovered() then
            if ImGui.BeginTooltip and ImGui.EndTooltip then
                ImGui.BeginTooltip()
                ImGui.TextWrapped(tostring(text or ""))
                ImGui.EndTooltip()
            elseif ImGui.SetTooltip then
                ImGui.SetTooltip(tostring(text or ""))
            end
        end
    end

    local function beginCard(id, title, width, height)
        ImGui.PushStyleColor(ImGuiCol.ChildBg, THEME.panel[1], THEME.panel[2], THEME.panel[3], 0.96)
        local visible = ImGui.BeginChild(id, width or 0, height or 0, true)
        ImGui.PopStyleColor(1)
        if visible then
            sectionHeader(title)
            ImGui.Separator()
        end
        return visible
    end

    local function endCard()
        ImGui.EndChild()
    end

    local function drawProfileSidebar(childId, includeManagementButtons)
        if beginCard(childId, "Profile Rack", 220, 0) then
            for index, profile in ipairs(PROFILES) do
                local isSelected = (index == CONFIG.selectedProfileIndex)
                if isSelected then
                    ImGui.PushStyleColor(ImGuiCol.Header, THEME.light[1], THEME.light[2], THEME.light[3], 0.85)
                    ImGui.PushStyleColor(ImGuiCol.HeaderHovered, THEME.bright[1], THEME.bright[2], THEME.bright[3], 0.78)
                    ImGui.PushStyleColor(ImGuiCol.HeaderActive, THEME.bright[1], THEME.bright[2], THEME.bright[3], 0.95)
                end
                if ImGui.Selectable(model.getProfileDisplayName(profile, index) .. "##profile_sidebar_" .. tostring(childId) .. "_" .. tostring(index), isSelected) then
                    model.commitDraftProfile(true)
                    CONFIG.selectedProfileIndex = index
                    Gui.draftProfile = nil
                    Gui.draftProfileIndex = 0
                    model.saveConfig()
                end
                if isSelected then
                    ImGui.PopStyleColor(3)
                    ImGui.SetItemDefaultFocus()
                end
            end

            if includeManagementButtons then
                ImGui.Spacing()
                ImGui.Separator()
                if ImGui.Button("Add Profile##bankstandererer_add", -1, 28) then
                    model.commitDraftProfile(true)
                    PROFILES[#PROFILES + 1] = model.ensureProfileDefaults({
                        name = "Profile " .. tostring(#PROFILES + 1),
                        itemName = "",
                        itemId = 0,
                        useOnItemName = "",
                        useOnItemId = 0,
                    })
                    CONFIG.selectedProfileIndex = #PROFILES
                    Gui.draftProfile = model.ensureProfileDefaults(PROFILES[#PROFILES])
                    Gui.draftProfileIndex = CONFIG.selectedProfileIndex
                    model.saveConfig()
                end
                if #PROFILES > 1 and ImGui.Button("Delete Profile##bankstandererer_delete", -1, 28) then
                    table.remove(PROFILES, CONFIG.selectedProfileIndex)
                    CONFIG.selectedProfileIndex = model.clampInteger(CONFIG.selectedProfileIndex, 1, #PROFILES, 1)
                    Gui.draftProfile = model.ensureProfileDefaults(model.getSelectedProfile())
                    Gui.draftProfileIndex = CONFIG.selectedProfileIndex
                    model.saveConfig()
                end
                ImGui.PushStyleColor(ImGuiCol.Button, THEME.bright[1], THEME.bright[2], THEME.bright[3], 0.92)
                ImGui.PushStyleColor(ImGuiCol.ButtonHovered, THEME.glow[1], THEME.glow[2], THEME.glow[3], 1.0)
                ImGui.PushStyleColor(ImGuiCol.ButtonActive, THEME.glow[1], THEME.glow[2], THEME.glow[3], 1.0)
                if ImGui.Button("Save Profile##bankstandererer_save", -1, 28) then
                    model.commitDraftProfile(true)
                end
                ImGui.PopStyleColor(3)
            end
        end
        endCard()
    end

    local function drawConfigTab()
        model.commitDraftProfile(false)
        local selectedProfile, selectedIndex = model.getSelectedProfile()
        drawProfileSidebar("bankstandererer_profile_sidebar", false)
        ImGui.SameLine()

        ImGui.BeginChild("bankstandererer_config_main", 0, 0, false)

        if beginCard("bankstandererer_workbench_card", "Workbench Control", 0, 165) then
            statRow("Selected Profile:", model.getProfileDisplayName(selectedProfile, selectedIndex))
            statRow("Status:", tostring(RUNTIME.status))
            statRow("Current Action:", tostring(RUNTIME.currentAction))
            ImGui.Spacing()
            if not RUNTIME.started then
                ImGui.PushStyleColor(ImGuiCol.Button, THEME.success[1], THEME.success[2], THEME.success[3], 0.95)
                ImGui.PushStyleColor(ImGuiCol.ButtonHovered, THEME.success[1] + 0.08, THEME.success[2] + 0.08, THEME.success[3] + 0.08, 1.0)
                ImGui.PushStyleColor(ImGuiCol.ButtonActive, THEME.success[1], THEME.success[2], THEME.success[3], 1.0)
                if ImGui.Button("Start Script##bankstandererer_start", -1, 34) then
                    startScript()
                end
                ImGui.PopStyleColor(3)
            else
                ImGui.PushStyleColor(ImGuiCol.Button, THEME.danger[1], THEME.danger[2], THEME.danger[3], 0.95)
                ImGui.PushStyleColor(ImGuiCol.ButtonHovered, THEME.danger[1] + 0.08, THEME.danger[2] + 0.08, THEME.danger[3] + 0.08, 1.0)
                ImGui.PushStyleColor(ImGuiCol.ButtonActive, THEME.danger[1], THEME.danger[2], THEME.danger[3], 1.0)
                if ImGui.Button("Stop Script##bankstandererer_stop", -1, 34) then
                    stopScript("stopped_from_gui")
                end
                ImGui.PopStyleColor(3)
            end
        end
        endCard()

        ImGui.Spacing()
        if beginCard("bankstandererer_summary_card", "Loaded Formula", 0, 0) then
            statRow("Item:", model.formatItemLabel(selectedProfile.itemName, selectedProfile.itemId))
            statRow("Click Mode:", tostring(selectedProfile.itemClickMode or ITEM_CLICK_MODE_OPTIONS[1]))
            if tostring(selectedProfile.itemClickMode or ITEM_CLICK_MODE_OPTIONS[1]) == ITEM_CLICK_MODE_OPTIONS[2] then
                statRow("Use On Item:", model.formatItemLabel(selectedProfile.useOnItemName, selectedProfile.useOnItemId))
            end
            statRow("Preset Loading:", shouldLoadPresetAtStart(selectedProfile) and "Load Last Preset" or "Use inventory first")
            statRow("Reload Mode:", model.getReloadBehaviorLabel(selectedProfile))
            statRow("Reload Preset Every Cycle:", model.yesNoLabel(selectedProfile.reloadPresetEveryCycle ~= false))
            statRow("Prompt Detection:", tostring(selectedProfile.interfaceMode or PROFILE_INTERFACE_MODE_OPTIONS[1]))
            statRow("Processing Confirmation:", tostring(selectedProfile.processingConfirmationMode or PROCESSING_CONFIRMATION_OPTIONS[1]))
        end
        endCard()

        ImGui.EndChild()
    end

    local function drawRuntimeTab()
        if beginCard("bankstandererer_runtime_card", "Session Readout", 0, 0) then
            statRow("State:", tostring(RUNTIME.state))
            statRow("Status:", tostring(RUNTIME.status))
            statRow("Action:", tostring(RUNTIME.currentAction))
            statRow("Loops:", tostring(RUNTIME.loopsCompleted))
            statRow("Runtime:", getRuntimeLabel())
            if RUNTIME.stopReason ~= "" then
                statRow("Stop Reason:", tostring(RUNTIME.stopReason))
            end
            if RUNTIME.lastError ~= "" then
                statRow("Last Error:", tostring(RUNTIME.lastError))
            end
        end
        endCard()
    end

    local function drawProfilesTab()
        model.syncDraftToSelection()
        local draft = Gui.draftProfile
        local draftIndex = Gui.draftProfileIndex
        local cardHeights = model.getProfileEditorCardHeights(draft)
        drawProfileSidebar("bankstandererer_profile_editor_sidebar", true)
        ImGui.SameLine()

        ImGui.BeginChild("bankstandererer_profile_editor_main", 0, 0, false)

        if beginCard("bankstandererer_profile_identity_card", "Profile Identity", 0, cardHeights.identity) then
            local changedName, newName = ImGui.InputText("Profile Name##" .. draftIndex, tostring(draft.name or ""))
            if changedName then
                draft.name = newName
            end

            local changedItemName, newItemName = ImGui.InputText("Item Name##" .. draftIndex, tostring(draft.itemName or ""))
            if changedItemName then
                draft.itemName = newItemName
            end

            local changedItemId, newItemId = ImGui.DragInt("Item ID##" .. draftIndex, tonumber(draft.itemId) or 0, 1, 0, 999999)
            if changedItemId then
                draft.itemId = newItemId
            end

            local clickModeIndex = 0
            for index, label in ipairs(ITEM_CLICK_MODE_OPTIONS) do
                if label == draft.itemClickMode then
                    clickModeIndex = index - 1
                    break
                end
            end
            local changedClickMode, newClickMode = ImGui.Combo("Item Click Mode##" .. draftIndex, clickModeIndex, ITEM_CLICK_MODE_OPTIONS)
            if changedClickMode then
                draft.itemClickMode = ITEM_CLICK_MODE_OPTIONS[newClickMode + 1]
            end

            if tostring(draft.itemClickMode or ITEM_CLICK_MODE_OPTIONS[1]) == ITEM_CLICK_MODE_OPTIONS[2] then
                ImGui.Text("Use On Item Name")
                helpMarker("use_on_item_name_" .. draftIndex, "Use this when the first item must be selected and then used on a second inventory item.")
                local changedUseOnItemName, newUseOnItemName = ImGui.InputText("##use_on_item_name_" .. draftIndex, tostring(draft.useOnItemName or ""))
                if changedUseOnItemName then
                    draft.useOnItemName = newUseOnItemName
                end

                ImGui.Text("Use On Item ID")
                local changedUseOnItemId, newUseOnItemId = ImGui.DragInt("##use_on_item_id_" .. draftIndex, tonumber(draft.useOnItemId) or 0, 1, 0, 999999)
                if changedUseOnItemId then
                    draft.useOnItemId = newUseOnItemId
                end
            end
        end
        endCard()

        ImGui.Spacing()
        if beginCard("bankstandererer_cycle_card", "Cycle Flow", 0, cardHeights.cycle) then
            local changedReloadEveryCycle, newReloadEveryCycle = ImGui.Checkbox("Reload Preset Every Cycle##" .. draftIndex, draft.reloadPresetEveryCycle ~= false)
            helpMarker("reload_preset_" .. draftIndex, "Turn this off for stackable inputs like mud runes so the script keeps going until the needed items are gone.")
            if changedReloadEveryCycle then
                draft.reloadPresetEveryCycle = newReloadEveryCycle
            end
        end
        endCard()

        ImGui.Spacing()
        if beginCard("bankstandererer_processing_card", "Prompt & Processing", 0, cardHeights.processing) then
            local modeIndex = 0
            for index, label in ipairs(PROFILE_INTERFACE_MODE_OPTIONS) do
                if label == draft.interfaceMode then
                    modeIndex = index - 1
                    break
                end
            end
            local changedMode, newMode = ImGui.Combo("Prompt Detection##" .. draftIndex, modeIndex, PROFILE_INTERFACE_MODE_OPTIONS)
            helpMarker("prompt_detection_" .. draftIndex, "Do Item/Tool Prompt for simple choose/use windows. Creation / Make-X Window for smithing, crafting, or fletching style make interfaces.")
            if changedMode then
                draft.interfaceMode = PROFILE_INTERFACE_MODE_OPTIONS[newMode + 1]
            end

            if tostring(draft.interfaceMode or PROFILE_INTERFACE_MODE_OPTIONS[1]) == PROFILE_INTERFACE_MODE_OPTIONS[3] then
                local changedCustomStatus, newCustomStatus = ImGui.DragInt("Custom Prompt 2874 Status##" .. draftIndex, tonumber(draft.custom2874Status) or 0, 1, 0, 9999)
                if changedCustomStatus then
                    draft.custom2874Status = newCustomStatus
                end
            end

            if tostring(draft.interfaceMode or PROFILE_INTERFACE_MODE_OPTIONS[1]) == PROFILE_INTERFACE_MODE_OPTIONS[4] then
                local changedCustomInterface, newCustomInterface = ImGui.DragInt("Custom Prompt Interface Size##" .. draftIndex, tonumber(draft.customInterfaceSize) or 0, 1, 0, 9999)
                if changedCustomInterface then
                    draft.customInterfaceSize = newCustomInterface
                end
            end

            local processingModeIndex = 0
            for index, label in ipairs(PROCESSING_CONFIRMATION_OPTIONS) do
                if label == draft.processingConfirmationMode then
                    processingModeIndex = index - 1
                    break
                end
            end
            local changedProcessingMode, newProcessingMode = ImGui.Combo("Processing Confirmation##" .. draftIndex, processingModeIndex, PROCESSING_CONFIRMATION_OPTIONS)
            helpMarker("processing_confirmation_" .. draftIndex, "Use API.isProcessing() for generic workflows. Use a processing interface or 2874 status when the active progress window is the reliable signal.")
            if changedProcessingMode then
                draft.processingConfirmationMode = PROCESSING_CONFIRMATION_OPTIONS[newProcessingMode + 1]
            end

            if tostring(draft.processingConfirmationMode or PROCESSING_CONFIRMATION_OPTIONS[1]) == PROCESSING_CONFIRMATION_OPTIONS[2] then
                local changedProcessingSize, newProcessingSize = ImGui.DragInt("Processing Interface Size##" .. draftIndex, tonumber(draft.processingInterfaceSize) or 0, 1, 0, 9999)
                if changedProcessingSize then
                    draft.processingInterfaceSize = newProcessingSize
                end
            end

            if tostring(draft.processingConfirmationMode or PROCESSING_CONFIRMATION_OPTIONS[1]) == PROCESSING_CONFIRMATION_OPTIONS[3] then
                local changedProcessingStatus, newProcessingStatus = ImGui.DragInt("Processing 2874 Status##" .. draftIndex, tonumber(draft.processing2874Status) or 0, 1, 0, 9999)
                if changedProcessingStatus then
                    draft.processing2874Status = newProcessingStatus
                end
            end

            local changedUseSpace, newUseSpace = ImGui.Checkbox("Use Space To Confirm##" .. draftIndex, draft.useSpaceToConfirm ~= false)
            if changedUseSpace then
                draft.useSpaceToConfirm = newUseSpace
            end
        end
        endCard()

        ImGui.EndChild()
    end

    DrawImGui(function()
        ImGui.SetNextWindowSize(920, 640, ImGuiCond.FirstUseEver)
        ImGui.SetNextWindowPos(90, 80, ImGuiCond.FirstUseEver)

        ImGui.PushStyleColor(ImGuiCol.WindowBg, THEME.dark[1], THEME.dark[2], THEME.dark[3], 0.98)
        ImGui.PushStyleColor(ImGuiCol.TitleBg, THEME.panelAlt[1], THEME.panelAlt[2], THEME.panelAlt[3], 1.0)
        ImGui.PushStyleColor(ImGuiCol.TitleBgActive, THEME.medium[1], THEME.medium[2], THEME.medium[3], 1.0)
        ImGui.PushStyleColor(ImGuiCol.Separator, THEME.border[1], THEME.border[2], THEME.border[3], 0.65)
        ImGui.PushStyleColor(ImGuiCol.Tab, THEME.panelAlt[1], THEME.panelAlt[2], THEME.panelAlt[3], 1.0)
        ImGui.PushStyleColor(ImGuiCol.TabHovered, THEME.light[1], THEME.light[2], THEME.light[3], 1.0)
        ImGui.PushStyleColor(ImGuiCol.TabActive, THEME.bright[1] * 0.72, THEME.bright[2] * 0.72, THEME.bright[3] * 0.72, 1.0)
        ImGui.PushStyleColor(ImGuiCol.FrameBg, THEME.medium[1], THEME.medium[2], THEME.medium[3], 0.88)
        ImGui.PushStyleColor(ImGuiCol.FrameBgHovered, THEME.light[1], THEME.light[2], THEME.light[3], 0.92)
        ImGui.PushStyleColor(ImGuiCol.FrameBgActive, THEME.light[1], THEME.light[2], THEME.light[3], 1.0)
        ImGui.PushStyleColor(ImGuiCol.Button, THEME.medium[1], THEME.medium[2], THEME.medium[3], 0.95)
        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, THEME.light[1], THEME.light[2], THEME.light[3], 1.0)
        ImGui.PushStyleColor(ImGuiCol.ButtonActive, THEME.bright[1], THEME.bright[2], THEME.bright[3], 1.0)
        ImGui.PushStyleColor(ImGuiCol.Header, THEME.panelAlt[1], THEME.panelAlt[2], THEME.panelAlt[3], 0.95)
        ImGui.PushStyleColor(ImGuiCol.HeaderHovered, THEME.light[1], THEME.light[2], THEME.light[3], 1.0)
        ImGui.PushStyleColor(ImGuiCol.HeaderActive, THEME.bright[1], THEME.bright[2], THEME.bright[3], 1.0)
        ImGui.PushStyleColor(ImGuiCol.Text, THEME.accent[1], THEME.accent[2], THEME.accent[3], 1.0)
        ImGui.PushStyleColor(ImGuiCol.Border, THEME.border[1], THEME.border[2], THEME.border[3], 0.55)
        ImGui.PushStyleColor(ImGuiCol.CheckMark, THEME.glow[1], THEME.glow[2], THEME.glow[3], 1.0)
        ImGui.PushStyleColor(ImGuiCol.PopupBg, THEME.panel[1], THEME.panel[2], THEME.panel[3], 0.98)

        ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 16, 14)
        ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 9, 7)
        ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding, 7)
        ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, 10)

        local visible = ImGui.Begin("Bankstandererer###bankstandererer_window", true)
        if visible and ImGui.BeginTabBar("bankstandererer_tabbar", 0) then
            if ImGui.BeginTabItem("Config###bankstandererer_tab_config", nil, 0) then
                drawConfigTab()
                ImGui.EndTabItem()
            end
            if ImGui.BeginTabItem("Runtime###bankstandererer_tab_runtime", nil, 0) then
                drawRuntimeTab()
                ImGui.EndTabItem()
            end
            if ImGui.BeginTabItem("Profiles###bankstandererer_tab_profiles", nil, 0) then
                drawProfilesTab()
                ImGui.EndTabItem()
            end
            ImGui.EndTabBar()
        end

        ImGui.PopStyleVar(4)
        ImGui.PopStyleColor(20)
        ImGui.End()
    end)
end

return module
