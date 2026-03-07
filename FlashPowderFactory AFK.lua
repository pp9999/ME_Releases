local API = require("api")

local startTime = os.time()
local idleTimeThreshold = math.random(400, 500) -- Random number between 180 (3 minutes) and 300 (5 minutes)
local function antiIdleTask()
    local currentTime = os.time()
    local elapsedTime = os.difftime(currentTime, startTime)
    if elapsedTime >= idleTimeThreshold then
        API.PIdle2()
        -- Reset the timer and generate a new random idle time 
        startTime = os.time()
        idleTimeThreshold = math.random(400, 500)
        print("Reset Timer & Threshhold")
    end
end




-- DO::DoAction_NPC(0x29,3328,{ ids },50)
-- API.DoAction_Interface(0xffffffff,0xffffffff,0,1184,15,-1,API.OFF_ACT_GeneralInterface_Choose_option);

-- south east corner - 7306,4557,0
-- north east corner - 7316,4557,0
-- south west corner - 7272,4532,0
-- north west corner - 7282,4532,0
-- northwest mixing machine 7284,1290 
-- northeast mixing machine 7304,1290
-- southwest mixing machine 7284,1270
-- southeast mixing machine 7304,1270
--southwest charge machine  {7284,1260,0)
-- southwest area spawn DO::DoAction_Object(0xb5,0,{ 64665},10) -- glowing void 
-- south area spawn DO::DoAction_Object(0x29,0,{ 64667 },10) -- energy field
-- DO::DoAction_Object(0x29,0,{ 64668 },10) -- convenient wall 
-- DO::DoAction_Object(0x29,0,{ 64666 },10) -- gear wheels 
-- coords pregame 3038,4967,0
local function checkloading()
    if API.GetFloorLv_2() == 9999 then
       return true
    end
    return false
end

local function FPF_AFK()
    API.PIdle2()

    while API.Read_LoopyLoop() do 
        antiIdleTask()
        if API.PInArea(3038,5,4967,5,0) then
            API.DoAction_NPC(0x29,3328,{ 14706 },10)
            API.RandomSleep2(5000)
            while checkloading() do
                API.RandomSleep2(2000)
                if not checkloading() then
                    break
                end
            end
        end
       
  
        local lpCoords = API.PlayerCoord()
        local northwest_MixingMachine = API.Math_DistanceW(WPOINT.new(lpCoords.x,lpCoords.y,lpCoords.z),WPOINT.new(7284,1290,0))
        local northeast_MixingMachine = API.Math_DistanceW(WPOINT.new(lpCoords.x,lpCoords.y,lpCoords.z),WPOINT.new(7304,1290,0))
        local southwest_MixingMachine = API.Math_DistanceW(WPOINT.new(lpCoords.x,lpCoords.y,lpCoords.z),WPOINT.new(7284,1270,0))
        local southeast_MixingMachine = API.Math_DistanceW(WPOINT.new(lpCoords.x,lpCoords.y,lpCoords.z),WPOINT.new(7304,1270,0))
    
        local northwest_ChargeMachine = API.Math_DistanceW(WPOINT.new(lpCoords.x,lpCoords.y,lpCoords.z),WPOINT.new(7284,1300,0)) -- gears 64666
        local southwest_Chargemachine = API.Math_DistanceW(WPOINT.new(lpCoords.x,lpCoords.y,lpCoords.z),WPOINT.new(7284,1260,0)) -- energy field 64667
        local southeast_ChargeMachine = API.Math_DistanceW(WPOINT.new(lpCoords.x,lpCoords.y,lpCoords.z),WPOINT.new(7304,1260,0)) --inconvenient wall 64688
        local northeast_ChargeMachine = API.Math_DistanceW(WPOINT.new(lpCoords.x,lpCoords.y,lpCoords.z),WPOINT.new(7304,1300,0)) -- inconvenient wall 64688
        local northwest_outlier_ChargeMachine = API.Math_DistanceW(WPOINT.new(lpCoords.x,lpCoords.y,lpCoords.z),WPOINT.new(7274,1290,0)) --energy field 64667
        local northeast_outlier_ChargeMachine = API.Math_DistanceW(WPOINT.new(lpCoords.x,lpCoords.y,lpCoords.z),WPOINT.new(7314,1290,0)) -- inconvenient wall 64667
        local southwest_outlier_ChargeMachine = API.Math_DistanceW(WPOINT.new(lpCoords.x,lpCoords.y,lpCoords.z),WPOINT.new(7274,1270,0)) -- glowing void 64655
        local southeast_outlier_ChargeMachine = API.Math_DistanceW(WPOINT.new(lpCoords.x,lpCoords.y,lpCoords.z),WPOINT.new(7314,1270,0)) -- gear wheel 64666
    
        -- if (northwest_MixingMachine > 6 or northeast_MixingMachine > 6 or southwest_MixingMachine > 6 or southeast_MixingMachine > 6) then
        --     if northwest_ChargeMachine < 4 then
        --         print("north west charge machine  close")
        --         API.DoAction_Object1(0x29,0,{64666},15)
        --         API.RandomSleep2(1800)
        --         API.WaitUntilMovingEnds()
        --         API.RandomSleep2(4000)
        --     elseif southwest_Chargemachine < 4  then
        --         print("south west charge machine close")
        --         API.DoAction_Object1(0x29,0,{64667},15)
        --         API.RandomSleep2(1800)
        --         API.WaitUntilMovingEnds()
        --         API.RandomSleep2(4000)
        --     elseif southeast_ChargeMachine < 4 then
        --         print("south east charge machine close")
        --         API.DoAction_Object1(0x29,0,{64668},15)
        --         API.RandomSleep2(1800)
        --         API.WaitUntilMovingEnds()
        --         API.RandomSleep2(4000)
        --     elseif northeast_ChargeMachine < 4 then 
        --         print("north east charge machine close")
        --         API.DoAction_Object1(0x29,0,{64666},15)
        --         API.RandomSleep2(1800)
        --         API.WaitUntilMovingEnds()
        --         API.RandomSleep2(4000)
        --     elseif northwest_outlier_ChargeMachine < 4 then
        --         print("north west outlier charge machine close")
        --         API.DoAction_Object1(0x29,0,{64667},15)
        --         API.RandomSleep2(1800)
        --         API.WaitUntilMovingEnds()
        --         API.RandomSleep2(4000)
        --     elseif northeast_outlier_ChargeMachine < 4 then
        --         print("north east outlier charge machine close")
        --         API.DoAction_Object1(0x29,0,{64668},15)
        --         API.RandomSleep2(1800)
        --         API.WaitUntilMovingEnds()  
        --         API.RandomSleep2(4000)
        --     elseif southwest_outlier_ChargeMachine < 4 then
        --         print("south west outlier charge machine close")
        --         API.DoAction_Object1(0xb5,0,{64665},15)
        --         API.RandomSleep2(1800)
        --         API.WaitUntilMovingEnds()
        --         API.RandomSleep2(4000)
        --     elseif southeast_outlier_ChargeMachine < 4 then
        --         print("south east outlier charge machine close")
        --         API.DoAction_Object1(0x29,0,{64666},15)
        --         API.RandomSleep2(1800)
        --         API.WaitUntilMovingEnds()
        --         API.RandomSleep2(4000)
        --     end
        -- end
        -- if (northwest_MixingMachine < 6 or northeast_MixingMachine < 6 or southwest_MixingMachine < 6 or southeast_MixingMachine < 6) then
            -- print("mix machine found sleeping")
            local rubbleObj = API.GetAllObjArray1({ 64694 }, 7, 0)
            -- if rubbleobj found interact with it else sleep

            if #rubbleObj > 0 then 
                print("rubble found")
                API.DoAction_Object1(0x38,API.OFF_ACT_GeneralObject_route0,{ rubbleObj[1].Id },7)
                print("interacting with rubble")
                API.RandomSleep2(2000)
                API.WaitUntilMovingandAnimEnds()
                API.RandomSleep2(4000)
            else
                print("no rubble found sleeping")
                API.RandomSleep2(2000)
            end
           
        -- end
    end
end

FPF_AFK()