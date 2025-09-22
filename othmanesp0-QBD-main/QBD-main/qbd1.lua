local API = require("api")
local UTILS = require("utils")
API.Write_fake_mouse_do(false)
local antifire = API.GetABs_name1("Super antifire potion")
local War = API.GetABs_name1("War's Retreat Teleport")
local qbdIds = {15506, 15507, 15454}
local currentPhase = 1
local artefact4 = {
    70785,70786,70787
}
local artefact1 = {70776,70777,70778}
local artefact2 = {70779,70780,70781}
local artefact3 = {70782,70783,70784}
local coffer = {70815, 70816, 70815, 70817}
local buffId = 25830
local completedPhases = {
    [1] = false,
    [2] = false,
    [3] = false,
    [4] = false 
}

local lootState = 0 

local function checkGameState()
    local gs = API.GetGameState2();
    if gs == 1 or gs == 2 then
        print("player not logged in");
        API.Write_LoopyLoop(false)
    end
end

local function getBuff(buffId)
    local buff = API.Buffbar_GetIDstatus(buffId, false)
    remaining = ((buff.found and API.Bbar_ConvToSeconds(buff)) or -1)
    return remaining
end


local function familiarexpiry() 
    if UTILS.getFamiliarDuration() < 5 then
        API.DoAction_Button_FO(7)
        API.RandomSleep2(2000, 500, 500)
    end
end


local function war()    
    if API.GetSummoningPoints_() < 100 or API.GetPray_()< 200 then
        API.DoAction_Object1(0x3d,API.OFF_ACT_GeneralObject_route0,{ 114748 },50);
        API.RandomSleep2(6000, 500, 500)
    end
    familiarexpiry()
    API.DoAction_Object1(0x29,API.OFF_ACT_GeneralObject_route3,{ 114750 },50);
    API.WaitUntilMovingEnds(20, 3);
    API.DoAction_Interface(0xffffffff,0xffffffff,1,662,78,-1,API.OFF_ACT_GeneralInterface_route)
    API.WaitUntilMovingEnds(20, 3);
    API.DoAction_Object1(0x39,API.OFF_ACT_GeneralObject_route0,{ 114771 },50);
    API.WaitUntilMovingEnds(20, 3);
 end

local function instance()    
    API.RandomSleep2(1000, 500, 500)
    if getBuff(30093) <= 60 then
    API.DoAction_Ability_Direct(antifire, 1, API.OFF_ACT_GeneralInterface_route)
    API.RandomSleep2(1000, 500, 500)
    end
    API.DoAction_Interface(0x2e,0xffffffff,1,1430,64,-1,API.OFF_ACT_GeneralInterface_route)
    API.RandomSleep2(1000, 500, 500)
    API.DoAction_Interface(0x2e,0xffffffff,1,1430,220,-1,API.OFF_ACT_GeneralInterface_route)
    API.RandomSleep2(1000, 500, 500)
    API.DoAction_Object1(0x29,API.OFF_ACT_GeneralObject_route0,{ 70812 },50);
    API.RandomSleep2(1500, 500, 500)
    API.DoAction_Interface(0xffffffff,0xffffffff,0,1186,8,-1,API.OFF_ACT_GeneralInterface_Choose_option)
    API.RandomSleep2(1000, 500, 500)
    API.DoAction_Interface(0xffffffff,0xffffffff,0,1188,8,-1,API.OFF_ACT_GeneralInterface_Choose_option)
    API.RandomSleep2(1500, 500, 500)
    API.DoAction_Interface(0x24,0xffffffff,1,1591,60,-1,API.OFF_ACT_GeneralInterface_route)
    API.RandomSleep2(1000, 500, 500)
    
    currentPhase = 1
    completedPhases = {
        [1] = false,
        [2] = false,
        [3] = false,
        [4] = false
    }
    lootState = 0
end


local function healthCheck()
    
    local hp = API.GetHPrecent()
    local eatFoodAB = API.GetABs_name1("Eat Food")
    if hp < 60 then
        print("Eating")
        API.DoAction_Ability_Direct(eatFoodAB, 1, API.OFF_ACT_GeneralInterface_route)
        UTILS.randomSleep(600)
    end
end

local function getArtefact(phase)
    if phase == 1 then return artefact1
    elseif phase == 2 then return artefact2
    elseif phase == 3 then return artefact3
    elseif phase == 4 then return artefact4
    else return nil
    end
end

local function checkBossSpawned()
    local qbd = API.GetAllObjArrayFirst(qbdIds, 25, { 1 })
    return qbd.Id > 0
end

local function findNextPhase()
    for i = 1, 3 do
        if not completedPhases[i] then
            return i
        end
    end
    return 4 
end

local function collectLoot()
    print("Collecting loot, state: " .. lootState)
    healthCheck()
    local maxAttempts = 3  
    local attempts = 0
    local success = false

    while attempts < maxAttempts  do
        success = false
        if lootState == 0 then
            
            print("Attempting first chest...")
            API.DoAction_Object1(0x35, API.OFF_ACT_GeneralObject_route0, {70790}, 50)
            API.WaitUntilMovingEnds(15, 3)
            
            
            local coffers = API.GetAllObjArray1(coffer, 50, {0})
            if #coffers > 0 then
                lootState = 1
                success = true
                print("First chest success")
            end

        elseif lootState == 1 then
            
            print("Attempting coffer...")
            API.DoAction_Object1(0x31, API.OFF_ACT_GeneralObject_route0, coffer, 50)
            API.WaitUntilMovingEnds(15, 3)
            
            API.RandomSleep2(2000, 500, 500)  
            lootState = 2
            success = true 

        elseif lootState == 2 then
            print("Attempting loot interface...")
            API.DoAction_Interface(0x24, 0xffffffff, 1, 168, 27, -1, API.OFF_ACT_GeneralInterface_route)
            API.WaitUntilMovingEnds(15, 3)
                lootState = 3
                success = true
                print("Loot interface success")

        elseif lootState == 3 then
            print("Teleporting...")
            API.DoAction_Ability_Direct(War, 1, API.OFF_ACT_GeneralInterface_route)
            API.WaitUntilMovingEnds(15, 3)
            lootState = 6
            completedPhases[4] = true
            return true 
        end

        if success then
            attempts = 0 
        else
            attempts = attempts + 1
            print("Retrying state "..lootState.." ("..attempts.."/"..maxAttempts..")")
            API.RandomSleep2(1500, 500, 500)
        end
    end

    print("Failed to progress loot state "..lootState)
    return false
end

local function artifacts()    
    healthCheck()
    local maxAttempts = 3  
    local attempts = 0
    local success = false
    local chest = API.GetAllObjArray1({70790}, 100, {0})
    if checkBossSpawned() then
        print("Boss has spawned, returning to combat")
        return true
    end
    
    if completedPhases[1] and completedPhases[2] and completedPhases[3] and not completedPhases[4] then
        local finalArtifactObjs = API.GetAllObjArray1(artefact4, 100, { 0 })
        
        if #finalArtifactObjs > 0 then
            print("Clicking final artifact in phase 4")
            if #chest == 0 then
                API.DoAction_Object_valid1(0x29, API.OFF_ACT_GeneralObject_route0, artefact4, 100, true)
                API.WaitUntilMovingEnds() 
            else 
                completedPhases[currentPhase] = true
            end
        end
    end
    
    if completedPhases[1] and completedPhases[2] and completedPhases[3] and completedPhases[4] then
        print("All phases complete, waiting...")
        API.DoAction_Interface(0x2e,0xffffffff,1,1430,220,-1,API.OFF_ACT_GeneralInterface_route)
        API.WaitUntilMovingEnds(20, 3)
        API.RandomSleep2(4000, 500, 500)
        while not collectLoot() do
            collectLoot()
        end
        return false
    end
    
    currentPhase = findNextPhase()
    print("Current phase: " .. currentPhase)
    
    local artefact = getArtefact(currentPhase)
    
    local artifactObjs = API.GetAllObjArray1(artefact, 100, { 0 })
    if #artifactObjs > 0 then
        print("Clicking artifact in phase " .. currentPhase)
        API.DoAction_Object_valid1(0x29, API.OFF_ACT_GeneralObject_route0, artefact, 100, true)
        API.WaitUntilMovingEnds(15, 3)
        healthCheck()
        API.RandomSleep2(1000, 500, 500)
        
        if checkBossSpawned() then
            print("Boss spawned after clicking artifact in phase " .. currentPhase)
            completedPhases[currentPhase] = true
            currentPhase = findNextPhase()
            print("Moving to phase " .. currentPhase)
            return true
        end
        
        return false
    else
        print("No artifacts found for phase " .. currentPhase)
        API.RandomSleep2(1000, 500, 500)
        return false
    end
end

local function fight()
    API.RandomSleep2(5000, 500, 500)
    
    local maxAttempts = 60
    local attempts = 0
    
    while attempts < maxAttempts  do
        local qbd = API.GetAllObjArrayFirst(qbdIds, 25, { 1 })
        healthCheck()
        if qbd.Id > 0 then
            print("Fighting boss")
            API.DoAction_NPC(0x2a, API.OFF_ACT_AttackNPC_route, qbdIds, 50)
            API.RandomSleep2(1000, 500, 500)
            
            attempts = 0  
        else 
            print("Boss not found")
            
            local bossSpawned = artifacts()
            if bossSpawned then
                print("Boss spawned, continuing fight")
                attempts = 0  
            else
                attempts = attempts + 1
                API.RandomSleep2(1000, 500, 500)
            end
        end
        
        if completedPhases[4] and lootState == 6 then
            print("All phases complete and looting finished, returning to War's Retreat")
            break
        end
    end
    
    if attempts >= maxAttempts then
        print("Max attempts reached, returning to War's Retreat")
        API.DoAction_Ability_Direct(War, 1, API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(5000, 500, 500)
    end
end


while API.Read_LoopyLoop() do
    checkGameState()
    API.DoRandomEvents()
    healthCheck()
    war()
    instance()
    fight()
    API.RandomSleep2(5000, 500, 500)
end

print("Script has terminated")
