--- 85% MADE BY CAIN
--- 14.9% Help by Dead
--- .1% Copied and Pasted by NecroServices 

local API = require("api")
local player = API.GetLocalPlayerName()
local processingTimeout = 250 
API.SetDrawTrackedSkills(true)
API.SetMaxIdleTime(15) -- 15 minutes
function waitUntil(x, timeout)
    start = os.time()
    while not x() and start + timeout > os.time() do
        API.RandomSleep2(600, 200, 200)
    end
    return start + timeout > os.time()
end
local function waitWhileProcessing(timeout)
    local startTime = os.time()
    while os.time() - startTime < timeout do
        if not isProcessing() then
            return true
        end
      

        API.RandomSleep2(600, 200, 200)
    end
    return false
end

--main loopyyyyloopp
API.Write_LoopyLoop(true)

while(API.Read_LoopyLoop()) do
    API.DoRandomEvents()


         
    if not API.IsPlayerAnimating_(player, 2) then
	API.DoAction_Object1(0x42,API.OFF_ACT_GeneralObject_route0,{ 109429 },50);
	API.RandomSleep2(3600, 200, 400)
	        API.DoAction_Interface(0xffffffff,0xffffffff,0,1370,30,-1,API.OFF_ACT_GeneralInterface_Choose_option)
			API.RandomSleep2(1600, 200, 400)
            if waitUntil(API.isProcessing, 5) then
                waitWhileProcessing(processingTimeout)
            end
        end
    end 
