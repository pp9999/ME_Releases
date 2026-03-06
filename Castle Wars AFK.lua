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
-- (API.PInArea(2480,15,9482,20) sarawaiting 
-- (API.PInArea(2421,15,9522,20) zammy waiting room
-- sara door 83496
-- 83511 sara ladder

local function castlewars()
  API.PIdle2()
  local randomTimeSleep = math.random(33,55)
  local randomTimeSleep2 = math.random(11,23)
    while API.Read_LoopyLoop() do

        antiIdleTask()
        if (API.PInArea(2441,10,3090,10,0)) then
            API.DoAction_Interface(0xc2,0xffffffff,1,985,88,-1,API.OFF_ACT_GeneralInterface_route)
            API.RandomSleep2(randomTimeSleep2)
            API.DoAction_Object1(0x39,API.OFF_ACT_GeneralObject_route0,{ 83642},50)
            API.RandomSleep2(1000)
            API.WaitUntilMovingEnds()
        end
   
        while (API.PInArea(2421,15,9522,20,0) or (API.PInArea(2480,15,9482,20,0))) do 
            API.RandomSleep2(5000)
            if (API.PInArea(2427,10,3076,10) or API.PInArea(2732,10,3131,10,1)) then 
                break
            end
        end
        if ( API.GetFloorLv_2() == 2) then
            API.RandomSleep2(1000)
        else
            API.RandomSleep2(randomTimeSleep)
            API.DoAction_Object1(0x34,API.OFF_ACT_GeneralObject_route0,{ 83511,83622 },50)
            API.RandomSleep2(800)
            API.WaitUntilMovingEnds()
        end

    end
end
castlewars()