--[[
    Author:     DEAD
    Version:     ??
   
    Script:      Runecrafter
    Description: Correction made by MatheusArcanjjo

]]

local ITEMS = {}

ITEMS.COMMON = {
    995 -- gold coins
}

ITEMS.RUNES = {
    554, -- fire
    555, -- water
    556, -- air
    557 -- earth
}

ITEMS.HERBS = {
    21626, -- fellstalk
    48243, -- arbuck
    219, -- torstol
    217, -- dwarf weed
    2485, -- lantadyme
    215, -- cadantine
    3051, -- snapdragon
    37975, -- bloodweed
    213, -- kwuarm
    14836, -- wergali
    12174, -- spirit weed
    3049, -- toadflax
    207, -- ranarr
    201 -- marrentill
}

ITEMS.BONES = {
    35010, -- reinforced dragon
    3123, -- shaikahan
    4834, -- ourg
    35008, -- hardened dragon
    18832, -- frost dragon
    30209, -- airut
    6812, -- wyvern
    48075, -- dinosaur
    51858, -- dragonkin
    4832, -- raurg
    6729, -- dagannoth
    4830, -- fayrg
    2859, -- wolf
    536, -- dragon
    4812, -- zogre
    530, -- bat
    534, -- baby dragon
    528, -- burnt
    526, -- bones
    3125 -- jogre
}

ITEMS.ASHES = {
    34159, -- searing
    33260, -- tortured
    20268, -- infernal
    20266, -- accursed
    20264 -- impious
}

ITEMS.ARROWS = {
    892 -- rune arrows
}

ITEMS.CHARMS = {
    12158, -- gold,
    12159, -- green
    12160, -- crimson
    12163, -- blue,
    12161 -- abyssal
}

local API = require("api")
local UTILS = require("utils")
local version = "1.3" -- Version updated
print("Run DeadSlayer: " .. version)
local buryBonesEnabled = true                              --Set this to true to bury bones that you pickup
local bonesId = ITEMS.BONES                                --IDS of the bones to bury
local itemIdsToLoot = UTILS.concatenateTables(             --IDS of the items to loot
    ITEMS.COMMON,
    ITEMS.RUNES,
    ITEMS.BONES,
    ITEMS.ARROWS,
    ITEMS.CHARMS)

-- #region User Inputs
-- #endregion

-- #region Imgui Setup
local imguiBackground = API.CreateIG_answer();
imguiBackground.box_name = "imguiBackground";
imguiBackground.box_start = FFPOINT.new(16, 20, 0);
imguiBackground.box_size = FFPOINT.new(300, 116, 0)

local getTargetBtn = API.CreateIG_answer();
getTargetBtn.box_name = "Get";
getTargetBtn.box_start = FFPOINT.new(16, 20, 0);
getTargetBtn.box_size = FFPOINT.new(50, 30, 0);
getTargetBtn.tooltip_text = "Populate mobs list"

local setTargetBtn = API.CreateIG_answer();
setTargetBtn.box_name = "Set";
setTargetBtn.box_start = FFPOINT.new(60, 20, 0);
setTargetBtn.box_size = FFPOINT.new(50, 30, 0);
setTargetBtn.tooltip_text = "The script will kill this mob"

local imguicombo = API.CreateIG_answer()
imguicombo.box_name = "Mobs     "
imguicombo.box_start = FFPOINT.new(100, 20, 0)
imguicombo.stringsArr = {"a", "b"}
imguicombo.tooltip_text = "Available mobs to target"

local imguiCurrentTarget = API.CreateIG_answer();
imguiCurrentTarget.box_name = "Current Target:";
imguiCurrentTarget.box_start = FFPOINT.new(30, 50, 0);

local imguiSlaughter = API.CreateIG_answer();
imguiSlaughter.box_name = "Slaughter";
imguiSlaughter.box_start = FFPOINT.new(18, 60, 0);
imguiSlaughter.box_size = FFPOINT.new(80, 30, 0);
imguiSlaughter.tooltip_text = "Start/Stop slaying"

local imguiTerminate = API.CreateIG_answer();
imguiTerminate.box_name = "Stop Script";
imguiTerminate.box_start = FFPOINT.new(100, 60, 0);
imguiTerminate.box_size = FFPOINT.new(100, 30, 0);
imguiTerminate.tooltip_text = "Exit the script"

local imguiRuntime = API.CreateIG_answer();
imguiRuntime.box_name = "imguiRuntime";
imguiRuntime.box_start = FFPOINT.new(30, 90, 0);

API.DrawComboBox(imguicombo, false)
-- #endregion

-- #region Variables init
local startTime = os.time()
local idleTime = os.time()
local targetPlaceholder = "None. Click Set Mob"
local target = targetPlaceholder
local runSlayer = false
local targetNotFoundCount = 0

local IDS = {
    EXCALIBUR = 14632,
    EXCALIBUR_AUGMENTED = 36619,
    ELVEN_SHARD = 43358
}

local COLORS = {
    BACKGROUND = ImColor.new(10, 13, 29),
    TARGET_UNSET = ImColor.new(189, 185, 167),
    TARGET_SET = ImColor.new(70, 143, 126),
    SLAUGHTER = ImColor.new(84, 166, 102),
    PAUSED = ImColor.new(238, 59, 83),
    RUNTIME = ImColor.new(198, 120, 102)
}

imguiBackground.colour = COLORS.BACKGROUND
imguiCurrentTarget.colour = COLORS.TARGET_UNSET
imguiRuntime.colour = COLORS.SLAUGHTER
-- #endregion

-- #region Util functions
local function log(text)
    print(string.format("%s - %s", os.date("[%H:%M:%S]"), text))
end

local function antiIdleTask()
    local timeDiff = os.difftime(os.time(), idleTime)
    local randomTime = math.random((5 * 60) * 0.6, (5 * 60) * 0.9)

    if timeDiff > randomTime then
        API.PIdle2()
        idleTime = os.time()
    end
end

local function formatElapsedTime(start)
    local currentTime = os.time()
    local elapsedTime = currentTime - start
    local hours = math.floor(elapsedTime / 3600)
    local minutes = math.floor((elapsedTime % 3600) / 60)
    local seconds = elapsedTime % 60
    return string.format("Runtime: %02d:%02d:%02d", hours, minutes, seconds)
end

local function gameStateChecks()
    local gameState = API.GetGameState2()
    if (gameState ~= 3) then
        API.log('Not ingame with state:', gameState)
        API.Write_LoopyLoop(false)
        return
    end
    if targetNotFoundCount > 30 then
        imguiSlaughter.box_name = "Slaughter"
        runSlayer = false;
        API.Write_LoopyLoop(false)
    end
end

local function terminate()
    runSlayer = false
    API.Write_LoopyLoop(false)
end

-- #endregion

-- #region UI render functions
local function populateDropdown()
    log('populateDropdown')
    local allNPCS = API.ReadAllObjectsArray({1},{-1},{})
    local mobs = {}
    if #allNPCS > 0 then
        for _, a in pairs(allNPCS) do
            local distance = API.Math_DistanceF(a.Tile_XYZ, API.PlayerCoordfloat())
            a.Distance = distance;
            if a.Id ~= 0 and a.Life > 1 and distance < 50 then
                table.insert(mobs, a.Name)
            end
        end
        local distinct = UTILS.getDistinctValues(mobs)
        if #distinct > 0 then
            table.sort(distinct)
            imguicombo.stringsArr = distinct
        end
    end
end

local function setMob()
    log('setMob')
    local currentMob = target;
    local selected = imguicombo.stringsArr[imguicombo.int_value + 1]
    if currentMob ~= selected then
        target = selected;
    end
    imguiCurrentTarget.colour = COLORS.TARGET_SET
    setTargetBtn.return_click = false;
end

local function pauseSlayer()
    runSlayer = false
    log("Slayer paused")
    imguiSlaughter.return_click = false
    imguiCurrentTarget.colour = COLORS.PAUSED
    imguiRuntime.colour = COLORS.PAUSED
    imguiSlaughter.box_name = "Slaughter"
end

local function startSlayer()
    log("Slayer started")
    runSlayer = true;
    imguiCurrentTarget.colour = COLORS.SLAUGHTER
    imguiRuntime.colour = COLORS.SLAUGHTER
    imguiSlaughter.box_name = "Pause"
end

local function drawGUI()
    if imguiTerminate.return_click then
        terminate()
    end
    if imguiSlaughter.return_click then
        if not runSlayer then
            startSlayer()
        end
    else
        if runSlayer then
            pauseSlayer()
        end
    end
    if getTargetBtn.return_click then
        populateDropdown()
        getTargetBtn.return_click = false
    end
    if not runSlayer and setTargetBtn.return_click then
        setMob()
    end
    API.DrawSquareFilled(imguiBackground)
    API.DrawBox(setTargetBtn)
    API.DrawBox(getTargetBtn)
    imguiCurrentTarget.string_value = "Current target:" .. target
    imguiRuntime.string_value = formatElapsedTime(startTime) -- os.difftime(os.time(),startTime)
    API.DrawBox(imguiSlaughter)
    API.DrawBox(imguiTerminate)
    API.DrawTextAt(imguiCurrentTarget)
    API.DrawTextAt(imguiRuntime)
end

-- #endregion

-- #region Script functions

--[[
    CORREÇÃO: A função buryBones foi reescrita para usar a nova classe "Inventory".
    - A lógica antiga usava funções como "InvItemFound2" e "DoAction_Inventory2", que não são ideais na nova API.
    - A nova versão verifica de forma iterativa se algum osso da lista "bonesId" existe no inventário.
    - Se um osso é encontrado, a função "Inventory:Use()" é chamada para enterrá-lo, que é a abordagem moderna.
    - O loop continua até que nenhum osso da lista seja encontrado no inventário.
]]
local function buryBones()
    local boneToBury
    repeat
        boneToBury = nil
        -- Encontra o primeiro osso disponível da nossa lista no inventário
        for _, boneId in ipairs(bonesId) do
            if Inventory:Contains(boneId) then
                boneToBury = boneId
                break
            end
        end

        -- Se encontrarmos um osso, o enterramos e esperamos
        if boneToBury then
            if not API.Read_LoopyLoop() or not API.PlayerLoggedIn() then
                break
            end
            log("Burying " .. boneToBury)
            -- Usa Inventory:Use(), que é o equivalente moderno de uma ação genérica de item
            Inventory:Use(boneToBury)
            UTILS.randomSleep(800, 1200) -- Aumentado o sleep para uma ação mais realista
        end
    -- Continua enterrando enquanto encontrarmos ossos
    until not boneToBury
end


local function loot()
    -- CORREÇÃO: "API.InvFull_()" foi substituído por "Inventory:IsFull()", da nova classe de inventário.
    if not Inventory:IsFull() then
        log('looting')
        API.DoAction_Loot_w(itemIdsToLoot, 10, API.PlayerCoordfloat(), 10)
        UTILS.randomSleep(600)
        API.WaitUntilMovingEnds()
    elseif buryBonesEnabled then
        buryBones()
    end
end

local function healthCheck()
    local hp = API.GetHPrecent()
    local prayer = API.GetPrayPrecent()
    local excalCD = API.DeBuffbar_GetIDstatus(IDS.EXCALIBUR, false)
    -- CORREÇÃO: "API.InvItemcount_1" foi substituído por "Inventory:GetItemAmount" para verificar a quantidade de itens.
    local excalFound = Inventory:GetItemAmount(IDS.EXCALIBUR_AUGMENTED)
    local elvenCD = API.DeBuffbar_GetIDstatus(IDS.ELVEN_SHARD, false)
    local elvenFound = Inventory:GetItemAmount(IDS.ELVEN_SHARD)
    local eatFoodAB = API.GetABs_name1("Eat Food")

    if hp < 50 then
        if not excalCD.found and excalFound > 0 then
            log("Using Excalibur")
            -- CORREÇÃO: "API.DoAction_Inventory1" foi substituído por "Inventory:Use" para uma chamada mais limpa e moderna.
            Inventory:Use(IDS.EXCALIBUR_AUGMENTED)
            UTILS.randomSleep(800)
        else
            if eatFoodAB.id ~= 0 and eatFoodAB.enabled then
                log("Eating")
                API.DoAction_Ability_Direct(eatFoodAB, 1, API.OFF_ACT_GeneralInterface_route)
                UTILS.randomSleep(600)
            elseif hp < 20 then
                log("Health critical, unable to heal, running away")
                API.DoAction_Ability("Retreat Teleport", 1, API.OFF_ACT_GeneralInterface_route)
                terminate()
            end
        end
    end

    if prayer < 50 and not elvenCD.found and elvenFound > 0 then
        log("Using Elven Shard")
        -- CORREÇÃO: "API.DoAction_Inventory1" também substituído por "Inventory:Use".
        Inventory:Use(IDS.ELVEN_SHARD)
        UTILS.randomSleep(600)
    end
end

local function useSkills()
end

local function usePrayers()
end

local function hasTarget()
    local interacting = API.ReadLpInteracting()
    if interacting.Id ~= 0 then
        return true
    else
        return false
    end
end

local function getDistinctByProperty(inputTable, property)
    local distinctValues = {}
    local seenValues = {}
  
    for _, value in ipairs(inputTable) do
      local prop = value[property]
      if not seenValues[prop] then
        table.insert(distinctValues, value)
        seenValues[prop] = true
      end
    end
    return distinctValues
  end

  local function filterByHealth(mobs, minHealth)
    local result = {}
    for _, mob in ipairs(mobs) do
        if mob.Life >= minHealth then
            table.insert(result, mob)
        end
    end
    return result
end

local function KillMob(name)
    if name == targetPlaceholder then
        log('No target selected, stopping slayer');
        pauseSlayer()
    end
    if not hasTarget() and not API.CheckAnim(15) then
        loot()
        local attackingMe = API.OthersInteractingWithLpNPC(true, 10)
        if #attackingMe > 0 then
            -- if attackingMe[1].Name == target then
            API.DoAction_NPC__Direct(0x2a, API.OFF_ACT_AttackNPC_route, attackingMe[1])
            UTILS.randomSleep(600)
            targetNotFoundCount = 0
            -- end
        else
            local targets = API.GetAllObjArrayInteract_str({name}, 30, {1})
            if #targets > 0 then
                local alive = filterByHealth(targets,1)
                if #alive > 0 and API.DoAction_NPC__Direct(0x2a, API.OFF_ACT_AttackNPC_route, alive[1]) then
                    targetNotFoundCount = 0
                    UTILS.randomSleep(600)
                    API.WaitUntilMovingEnds()
                end
            else
                log('unable to find target')
                targetNotFoundCount = targetNotFoundCount + 1
                UTILS.randomSleep(600)
            end
        end
    else
        healthCheck()
        useSkills()
        usePrayers()
    end
end
-- #endregion

-- #region Main loop
API.Write_LoopyLoop(true)
populateDropdown()
while (API.Read_LoopyLoop()) do -----------------------------------------------------------------------------------
    API.DoRandomEvents()
    gameStateChecks()
    antiIdleTask()
    drawGUI()
    if runSlayer then
        KillMob(target)
    end
    UTILS.randomSleep(300)
end ----------------------------------------------------------------------------------
-- #endregion